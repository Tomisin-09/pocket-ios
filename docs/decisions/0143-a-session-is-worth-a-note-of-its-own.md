# 0143 — A session is worth a note of its own

- **Status:** Accepted — built 2026-08-05 (`pocket-232-session-journal`), v2 close-out Slice 4.
- **Date:** 2026-08-05
- **Builds on:** ADR 0038 (the practice journal — dated entries, immutable snapshots), ADR 0058 (one
  owner-aware write path; a journal belongs to a *unit*), ADR 0100 (the Journal space — one
  aggregated, read-only timeline, and the `EntryKind` tag vocabulary), ADR 0142 (a note you can write
  while you play; the owner caption is a link), ADR 0090 (present and route by stable `uid`, never
  `persistentModelID`), ADR 0117 (the practice log, and `PracticeLog.Sitting` deriving sessions),
  ADR 0070 (no performance feedback), ADR 0112 (free runs, Pro authors).
- **Extends:** ADR 0058's single-owner rule — a journal entry now has **three** possible owners, not
  two, and the third is not a unit at all.

## Context

ADR 0142 made the journal reachable from every run surface, and closed by naming what it had left
undone: *"Entries written inside a routine still belong to the block's unit, not to the session… the
compact sheet names the unit it will write to for exactly that reason. Session-level entries are
ADR 0143."*

Device note **N6** is that gap, and it is the ordinary case rather than an edge one. You finish a
routine — six blocks, forty minutes — and the thing you want to write is about the *sitting*:
shoulders tight today, the chord changes only came good in the last five minutes, my hands were cold
until the third block. The app's only answer was to pick one of the six blocks and write it there,
which files a session-level thought under a unit it isn't about, and puts it on a timeline where it
will later read as a lie about that drill.

**N7's header half** is the other end of the same note. Every other entry on the feed leans on
`JournalTimeline.ownerLabel` to say what it is about. A session entry has no unit to name, so unless
it carries its own record of what the sitting consisted of, it is a paragraph with no subject. And
those unit names should lead somewhere, which is exactly the linking `JournalOwnerRoute` shipped in
ADR 0142.

This is the only slice of the v2 close-out that touches the store.

## Decision

- **S1 — A session entry is owned by a routine *sitting*, not by a unit.** `JournalOwner` gains a
  `.session` case carrying a `SessionJournalContext`: the routine's `uid`, its name, and the units
  practised. Everything else about the entry — the timeline, the day grouping, the tag vocabulary,
  the search — is unchanged, because a session note is an ordinary journal entry that happens to be
  about a bigger thing.

- **S2 — It holds loose id copies, never a third SwiftData relationship.** `JournalEntry` gains
  `routineUID`, `routineNameAtEntry` and `practisedUnitsRaw` — all optional, all with **no
  declaration default**, so lightweight migration stays exempt from the CoreData 134110
  mandatory-attribute rule. This follows the rule `PracticeRun` already states in its own words:
  *"deleting an exercise must not delete the minutes you spent on it."* The same is true, and more
  so, of the reflection you wrote about an hour of practice — **it must outlive the routine, and
  every unit in it.** A relationship would cascade the entry away with its owner, which is right for
  a note about a drill and wrong for a note about a Tuesday.

  The price is that a link can go stale, and that is accepted: resolving a ref is allowed to fail, and
  a pill that no longer resolves renders dimmed rather than as a tap that leads nowhere.

- **S3 — What it snapshots is what you practised, because there is no tempo that would be true.**
  Every other entry snapshots a number: an exercise's absolute BPM, a loop's mastery and percent. A
  session spans several units at several tempos, so any single number would be exactly the
  defaulted-semantics lie ADR 0039 removed. `masteryAtEntry`, `commandTempoAtEntry`,
  `commandBpmAtEntry` and `commandNotesPerBeatAtEntry` all stay `nil`, and the snapshot is the unit
  list instead.

  It also does **not** snapshot a duration. `PracticeLog.Sitting` (ADR 0117) already derives session
  minutes from the practice log, and a second stored copy would be a second truth that could disagree
  with the first.

- **S3a — The routine's name is snapshotted, not looked up.** `routineNameAtEntry` is the entry's
  caption. Reading it through `routineUID` would defeat the point: the routine may have been renamed
  or deleted, and ADR 0038's whole discipline is that an entry stays truthful to the moment it was
  written. The snapshot stores the name **raw**, empty included; the fallback wording ("Routine
  session", "this session") belongs to whichever surface is displaying it.

- **S4 — `ownerKind` is the single discriminator, and it is not optional work.** Until now an entry's
  owner was decided by *which relationship is non-nil*, and that test was written out by hand at each
  render site (`if entry.exercise != nil { … } else { /* loop */ }`). That was only ever correct
  while there were exactly two owners. A session entry sets **neither** relationship, so every one of
  them would have silently rendered as a loop entry, complete with an empty mastery row. `JournalEntry`
  now exposes a computed `ownerKind` — `.exercise` / `.loop` / `.session` / `.orphan` — and every
  site switches on it. No new stored column: the fields were already unambiguous, and a stored
  discriminator is one more thing that can disagree with the data it describes.

  Unit relationships win over a `routineUID`, so an entry carrying both can never start reading as a
  session.

- **S5 — The write seam is the session-complete screen, and only that.** The composer sits on
  `RoutinePlayerView`'s summary, which already computed the "you practised" recap this snapshot
  mirrors. It is the `JournalNoteComposer` from ADR 0142 in its `.card` style, tagged 🎬 `.session` —
  a kind that has been in `EntryKind` since ADR 0100 with nothing to own it.

  **The known cost, stated rather than discovered:** bail out of a routine early and there is no
  session entry to write, because the summary is the only screen that knows the session ended. This
  is the same trade ADR 0117's practice-log write seam made, for the same reason — a session that was
  abandoned has no honest end to snapshot. If device use shows people bailing out routinely, the fix
  is a reachable composer on the exit path, not a session entry written speculatively part-way
  through.

- **S6 — Songs and rests are not in the snapshot.** A rest is not practice. A song is: it just has no
  standalone run surface for a pill to open (ADR 0069 slice 4, ADR 0142 J5a), so a song pill could
  only ever be dead text. The **recap card keeps songs** — it says what you did — while the snapshot
  drops them, because it says where you can go. Two lists, deliberately different.

  Repeats are deduped by `uid`, first appearance keeping its place: a routine that opens and closes
  on the same warm-up practised it once as far as a reader is concerned.

- **S7 — The Journal space gains exactly one write verb: delete.** ADR 0100 made that space
  read-only, with writing and editing living in the per-owner `JournalSheet`. A session entry belongs
  to no unit, so **no per-owner sheet can ever reach it** — without this, a session note would be
  permanent. Session rows get swipe-to-delete; unit-owned rows keep their read-only treatment and
  their sheet. No third editing surface: a session note is written in one breath at the end of a
  session, and the thing you want when it comes out wrong is to remove it, not to curate it.

  **Widened 2026-08-05 (ADR 0100 amendment).** The "session rows only" half did not survive contact
  with use: the app's own designer went looking for delete on a *unit-owned* note and was surprised it
  wasn't there. A rule its author forgets while using the app is not a rule a player will hold, and
  the justification above — that a session note has no other way out — explains why session rows
  needed it *first*, not why other rows should be denied it. Delete now reaches every row on the feed,
  takes included. The rest of S7 stands unchanged: still no editing here, and the deletes are the
  deferred, undoable kind (`RowDeletionCoordinator`), which is also what makes removing a take's audio
  file safe to offer.

- **S8 — The links honour the same gates the caption does.** A pill routes through
  `JournalOwnerRoute` on the unit's stable `uid` (ADR 0090), opens the mode a loop qualifies for
  (ADR 0142 J5a), and raises the paywall rather than the run screen for a locked Pro drill (ADR 0142
  J5c). One rule for both, since a caption and a pill make the player the same promise.

## Consequences

- The journal now has an entry that is about *time* rather than about a thing. That is a genuine
  widening of what the timeline is for, and it is the first entry whose meaning depends on data it
  carries itself rather than on an owner it points at.
- Session entries are immortal by construction — nothing cascades them — so the Journal feed will
  accumulate them until they are deleted by hand. With one entry per finished routine that is the
  right order of magnitude, but it is the first row on that feed with no automatic end of life.
- `JournalTabView` now queries the exercise and loop libraries to resolve pills. Two more unfiltered
  fetches on a screen that already had two; the libraries are small and `ExerciseLibraryView` already
  reads them this way, but this is the screen to watch if the feed ever feels slow.
- A session's unit titles join the search index, so searching a drill's name surfaces the sessions you
  played it in, not only its own notes. That is a small feature nobody asked for and the most likely
  reason someone finds an old session entry again.
- `SessionUnitRef` is the project's first hand-rolled JSON payload in a `@Model` column. It is
  deliberately tolerant — a malformed payload decodes to no units rather than throwing — because it
  is read on the feed's render path inside a computed accessor, where a trap would take the whole
  timeline down.

## Alternatives considered

- **A `routine: Routine?` relationship.** Rejected in S2: it cascades. Deleting a routine you have
  outgrown would erase months of reflection written while you used it, which is the exact failure
  `PracticeRun` was designed to avoid.
- **A `Session` @Model with its own identity.** Rejected: this app has no stored session — ADR 0117
  deliberately derives sittings from the log rather than recording them, and `PracticeRunKind`
  refuses a routine case in as many words. A new model would introduce a second, disagreeing notion
  of what a session is, to hold an entry that already has a `uid` and a timestamp of its own.
- **Storing a session duration or block count.** Rejected in S3 — `PracticeLog.Sitting` already
  derives it, and two stored truths drift.
- **Writing the unit list as plain text.** Rejected: it would have satisfied N6 and abandoned N7's
  header half, in a slice whose neighbour had just built the routing it needed.
- **Offering "this session" as an owner in `QuickJournalSheet` mid-routine.** Rejected for now: it
  would let a session note be written before the session has happened, and it puts a
  which-am-I-writing-about choice in front of someone holding a guitar. It is the natural answer if
  S5's early-exit cost turns out to bite.
- **A full edit sheet for session entries.** Rejected in S7 — a third journal editing surface for the
  one owner that has no journal to browse.
