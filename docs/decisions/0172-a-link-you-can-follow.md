# ADR 0172 — a link you can follow, and an order you can fix

- **Status:** Accepted
- **Date:** 2026-08-19 (`pocket-275-reorder-and-walkable-links`)
- **Relates to:** ADR 0065 (the chord-progression content model), ADR 0090 (present model
  sheets by a stable uid), ADR 0103 (search-first chord picker), ADR 0111 (the
  exercise ↔ song edge), ADR 0042 (the practice screen is the one screen that rotates),
  ADR 0136 (`ExerciseRunScreen` is the one router into a run), ADR 0167 (the reference-link
  row, whose tap behaviour this borrows)
- **Not** a schema change. `ChordProgression` is an opaque `Codable` blob in
  `Exercise.templatePayload`, and the ADR 0111 edge already exists in the store.

## Context

Two surfaces described something true and then declined to act on it.

**The chord progression could only be appended to.** `ChordProgressionEditor` (ADR 0065)
offers add, swap, re-beat and delete. Order *is* the model — `ChordProgression.changes` is
played in array order and wraps — but there was no way to change it. A player who builds
G · D · Em · C and then realises the D should have come first has one route: delete the D,
re-open the picker, re-add it, re-set its hold. The information needed to fix it was on
screen the whole time.

**The exercise ↔ song link was a fact, not a route.** ADR 0111 shipped a real many-to-many
edge and both authoring surfaces. A song's details sheet lists *Exercises for this song*;
an exercise's detail sheet lists *Songs*. Both rendered as inert `Text`. The app knew
"Canon in D Part 1 helps you play this song", said so, and then made you close the sheet,
navigate to the other library and find it by name. Every ingredient of the link was
present except the ability to use it.

A third thing surfaced while reading the first: **all four pure editing helpers on
`ChordProgression` silently dropped `keyRoot` and `keyIsMinor`**. Each rebuilt with
`changes:` and `version:` alone, so any edit reset a progression's declared key to
"inferred from the first chord". The shipped `ChordProgression.gMajorPop` sets
`keyRoot: 7`; re-beating one of its chords re-lettered every Roman-numeral badge against
whatever chord happened to be first. No test covered it, and it would have become a fifth
instance the moment a reorder helper was written the same way.

## Decision

### D1 — Reordering is two arrows on the row, not a drag

Each chord row carries a `chevron.up` / `chevron.down` pair, disabled at the ends of the
list and hidden entirely for a one-chord progression (which cannot be ordered at all).

**Why not the drag the routine editor uses.** `ChordProgressionEditor` draws its rows as a
`VStack` + `ForEach` inside a **single** `Form` row, at all four call sites
(`ConfigureExerciseForm+Sections` ×2, `ExerciseShapeSheet` ×2). SwiftUI's `.onMove` — what
`RoutineDetailView`'s blocks use — only reaches a `ForEach` that is a *direct* child of a
`List`. Getting there means emitting the editor's rows into the enclosing `Form`, which
breaks the shared `VStack` that Chords & Strum uses to keep the strum lane and the chord
list in one row without a phantom row between them. A hand-rolled drag inside a `Form`
buys the affordance at the cost of fighting the scroll it sits in, and forfeits every
animation and accessibility behaviour `.onMove` would have provided.

**Why not an edit mode.** Reordering a progression is a *repair* — you notice the D should
have come first — and a repair wants the control already there rather than behind a mode
to enter, leave, and forget you are in. The routine editor's Edit mode earns itself by
also gating Save/Cancel over a sandboxed context; this editor has no such contract.

The cost is honest and worth stating: the row now holds five controls at 390pt. If it
gets tighter, the bin is the control to move to a swipe, not the arrows.

### D2 — The reorder is a pure helper, and identity stays the index

`ChordProgression.movingChange(at:by:)` joins the other four editors, and it is a genuine
move (remove + insert), not a swap, so it stays correct if a caller ever steps by more
than one. A move off either end returns `self` rather than wrapping: the arrows are
disabled there, and wrapping would make a mis-tap on the last row silently rewrite the
start of the progression.

The editor's `ForEach` **keeps index identity**, so a reorder redraws the rows in place
rather than animating one past another. The alternative — a stable id on `ChordChange` —
is a trap: `ChordChange` is `Equatable` inside a `Codable` blob that
`ExerciseShapeSheet.commitChords()` diffs against a *freshly decoded* copy to decide
whether to write at all. A per-decode `UUID` would make that diff always report "changed",
so every Done would write to the store. A missing animation is much the cheaper of the two.

### D3 — Every editor rebuilds through one private `with(changes:)`

The key drop is fixed structurally rather than four times over. All five editors now go
through `ChordProgression.with(changes:)`, which carries `keyRoot`, `keyIsMinor` and
`version` across. Keeping the rebuild in one place is what stops a sixth editor
reintroducing it, and `testEditingHelpersPreserveTheDeclaredKey` covers all five by name.

### D4 — A linked exercise opens its run screen, pushed inside the sheet

Tapping a row in *Exercises for this song* pushes `ExerciseRunScreen` onto the song details
sheet's own `NavigationStack`, so the back chevron returns to the song you came from. This
reuses, exactly, the pattern *Build a routine for this song* already uses two rows below
it. Through `ExerciseRunScreen`, never `ExerciseRunView` — that router is the one place
that decides which run screen a drill gets, so a freeform block still gets its own
(ADR 0136).

### D5 — A linked song opens the player, and the sheet leaves first

The other direction cannot use D4's move. `WaveformPracticeView` calls `.landscapeEnabled()`
— it is the one screen in the app that rotates (ADR 0042) — and takes a keep-awake lease.
Neither survives being run inside a sheet. So the tap **stages** the song, dismisses the
sheet, and the host pushes the player in `onDismiss`: presenting into a dismissing sheet
drops the push, which `ExerciseLibraryView` already knew from its create-then-run flow.

### D6 — The route is offered wherever the screen can actually take it

`ExerciseDetailSheet` takes an optional `onOpenSong`. Where it is `nil` — the default — the
rows draw exactly as they always have, because a row that looks tappable and isn't is
worse than one that never offered.

Two hosts wire it: the **exercise library**, and the **standalone run screen's ⓘ**, the
latter guarded by `canLeaveForSong` (`!isRunning && routineContext == nil`) — the guard
`ExerciseRunView` already uses three times over for affordances of exactly this kind. The
two halves are separate facts: a *running* drill would be stranded rather than ended by a
player that takes the audio session and a wake lease of its own, and a drill *inside a
routine* has no navigation stack of its own to push onto, the back chevron belonging to the
routine player. `RoutineBlockPreview` and `FreeformRunView` pass nothing.

**This reverses the decision this ADR shipped with**, and the correction is worth recording
because the reasoning failed in a specific way. The first cut wired the library alone, on
the grounds that the other three hosts were "mid-practice surfaces". That treated the run
screen as though it were always mid-run. It is not: it is a *setup* screen first — you
arrive, read the drill, set the tempo, and only then start — and the ⓘ is precisely the
control you reach for while reading. Device testing found it immediately, by the most
natural door rather than the one the ADR had in mind, and the inert rows read exactly as
the bug they resembled. The lesson is narrower than "wire everything": the question is not
whether a surface is *about* practice, it is whether the screen is **in a state that can
take the departure** — which is a runtime fact, and so belongs in a runtime guard rather
than in a per-host judgement made at author time.

## Consequences

- **The two directions of the ADR 0111 edge now behave differently on tap** — one pushes
  in place, one dismisses and pushes underneath. That asymmetry is not an oversight; it
  is the rotation and wake-lease difference between the two destinations, and D5/D6 record
  it so a later reader does not "fix" it into symmetry.
- **If the run-screen-inside-a-sheet reading is wrong on device**, the fix is to move D4 to
  D5's shape, not to move D5 to D4's.
- **The stage-then-push dance is one shared value**, `LinkedSongRoute` (`stage` → `promote`
  → `clear`), rather than two copies of two `@State` optionals and an ordering rule. Its
  point is that the rule — nothing pushes until the sheet has *finished* dismissing — is
  unit-testable without a sheet, including the case that matters most in practice: a
  dismissal by Done or a swipe must not navigate anywhere.
- **`RoutineBlockPreview` and `FreeformRunView` still pass `nil`.** If that reads as a bug
  in turn, the fix is the same shape as D6's — find the runtime state that makes leaving
  safe and guard on it — not a fourth per-host judgement.
- **`SongDetailsSheet` split.** The linked-drills section moved to
  `SongDetailsSheet+Links.swift` to stay under the 400-line cap, the same move
  `RoutineDetailView+References.swift` makes. Members it needs dropped `private`, as
  `RoutineDetailView`'s already had.
- **A progression's declared key now survives an edit**, which changes the Roman-numeral
  badges on any existing drill whose key was set and then edited. That is the correction,
  not a regression: those badges were being read against the wrong key.
- **Reordering does not animate.** Recorded in D2 with the reason, so the absence reads as
  a decision rather than an omission.
