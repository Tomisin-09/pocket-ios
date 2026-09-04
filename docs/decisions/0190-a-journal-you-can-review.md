# ADR 0190 — a journal you can review

- **Status:** Accepted
- **Date:** 2026-09-04 (`pocket-295-a-journal-you-can-review`)
- **Relates to:** ADR 0100 (the Journal space is read-only for owned entries — this establishes that
  a *review verb* sits inside that rule), ADR 0038 / 0058 / 0143 / 0155 / 0160 / 0175 (the authoring
  half, which is what made the imbalance), ADR 0151 (a note outlives its unit — and what it loses
  when it does), ADR 0119 (favourites, the mark this app already has, and why this is not one),
  ADR 0126 (toolbar grammar — why the new filters go behind the existing glyph), ADR 0117 / 0176
  (the practice log and its heatmap), ADR 0070 (the app never grades the player *or their habits*),
  ADR 0189 (what a schema change must carry — this one carries nothing, and says why),
  ADR 0181 / 0188 (the archive these two new columns have to cross), ADR 0165 (the manual owns
  procedure, so `docs/manual/journal-and-practice-log.md` moves with this)
- **Schema:** **additive only.** Two `Bool = false` columns — `JournalEntry.isPinned` and
  `Recording.isPinned` — plus two optional `Bool?`s in the archive records. Defaulted primitives are
  the migration-exempt shape (CoreData 134110); under ADR 0189 this is ordinary work and needs none
  of that ADR's criteria.

## Context

**Every ADR the journal has is about writing in it.** 0038 gave it entries and immutable snapshots,
0058 gave it a second owner, 0100 gave it a space of its own, 0143 gave it sessions, 0155 gave it
notes about nothing, 0160 gave it the metronome, 0175 gave it moments inside a take. Seven decisions
on authoring, none on **reading back**.

That is a fair split for a young journal and the wrong one for an old one. After a year the two
entries that changed how someone plays are somewhere under a few hundred routine ones, and the
controls that exist to find them are: a three-way segmented picker, a two-state sort, and a search
field.

Four findings, from a pass over `JournalTimeline`, `JournalEntry` and `JournalTabView`.

**1. Nothing on the feed can be marked.** `Exercise.isFavorite`
(`Pocket/Core/Models/Exercise.swift:273`), `Loop.isFavorite` (`Loop.swift:97`) and
`Routine.isFavorite` (`Routine.swift:40`) each let the player say *this one matters* about a **unit**.
No such mark exists about a **record**. The one thing in the app that is explicitly a keepsake — the
note you wrote the day the barre chord came good — is the one thing with no way to keep it.

**2. The scope picker sees one axis of three.** `JournalTimeline.Scope` is `all, notes, takes`
(`JournalTimeline.swift:39-40`) — a filter on the *medium*. Two further axes are in the model and
uncaptured: `JournalEntryOwnerKind` carries six cases (`JournalEntry.swift:8-24`), and `kindRaw` /
`EntryKind` seven more (`EntryKind.swift:11-18`). *"Just my session notes"* is unaskable.

⚠ **One kind is filterable by accident, and it is not precedent.** `ownerLabel` returns the constant
`"Metronome"` for a metronome entry (ADR 0160 §6) and `searchHaystack` folds the owner label in, so
typing `metronome` narrows the feed to exactly one owner kind. That is a side effect of a caption,
not an affordance, and reading it as one would be reading a coincidence as a design.

**3. There is no way to jump to a date — but there is a way to search one.** The timeline is
day-grouped and ordered `newest` or `oldest`, nothing else (`JournalTabView.swift:38`). What the
finding as originally logged missed: `searchHaystack` already appends the item's date in **two**
formats, abbreviated and long, and the search field already advertises it — *"Search by song,
exercise, template or date"*. So `july 2026` works today. What it does is **filter**: it throws away
the days either side, which is the context you were reading toward. Filtering to a date and
navigating to one are different acts, and only one of them exists.

**4. The matcher gate is open.** This work was explicitly blocked on collapsing the four disagreeing
search implementations first, because a scope picker over an inconsistent matcher ships a
uniform-looking control over four different behaviours (`docs/backlog.md`, *A filter on the list
screens*). `TextMatch` discharged that on 2026-09-04 (`4e7d29d`, #288). The next question in that
entry's order — **do filters persist?** — is still open, and this ADR is the first screen that has to
answer it.

**Why this is allowed here at all.** ADR 0100 made the Journal read-only for *owned* entries on
purpose: authoring stays where the snapshot is honest, because filing a note against a unit from a
screen where you are not practising it snapshots where that unit stands *now*. A pin does not touch a
snapshot and makes no claim about the practice — it records the **reader's** relationship to a record
that is already written. Deletion crossed the same line in the 0100 amendment (2026-08-05) for a
narrower reason, and this is a smaller step than that one: nothing is destroyed.

## Decision

### D1 — a pin, and it is a pin, not a favourite

`JournalEntry.isPinned: Bool = false` and `Recording.isPinned: Bool = false`.

**Not `isFavorite`,** even though that is the word this app already uses for *mark this yourself so
it is easy to find later*, and even though reusing it would inherit the star glyph and
`LibraryOptionsMenu`'s "Favourites only" label for free. A favourite is something you want to come
back **to**; the journal's most valuable entries are frequently records of a bad week, and *favourite
struggle* is not a thing anyone will say. **Pin** carries the meaning without the affection: it says
*keep this where I can reach it* and takes no view on whether it was good.

**The player pins; the app never does.** Nothing auto-pins — not a `.breakthrough`, not a long
session, not a personal best. An app that decided which of your practice mattered would be grading
your practice, which is ADR 0070's line, and it would be the version of the line hardest to see
coming.

### D2 — the pin reaches both row types

A take is pinnable on the same terms as a note. The Journal space's whole premise (ADR 0100) is that
notes and takes are **one feed**; a verb that works on one row and not the row beneath it makes the
gesture depend on which kind you happen to be standing on. Both models take the column; nothing about
the two rows differs in this respect.

An **orphan** is pinnable too. A note whose unit was deleted is not a lesser record — ADR 0151 spent
real design on keeping it readable — and it is arguably the one most in need of a mark, since it is
the one no owner screen can reach.

### D3 — the pin lives on the hold menu

`holdMenu(for:)` already exists on both row types and is already the *only* way to delete from this
feed. Pin joins it, above the destructive item.

**Not a swipe.** Takes already spend their leading edge on Rename, so a swipe would either be
asymmetric between the two rows or push Rename into second place; and ADR 0167 phase 1 paid for the
general lesson on this exact class of verb — a swipe-only action with nothing on the row announcing
it is an action most players never find. The fix then was a hold menu. This starts there.

**The row shows the state.** A pinned row carries a small `pin.fill` glyph beside its date. Without
it the menu is the only place the pin is legible, which is the same undiscoverability one level in.

### D4 — pinned is a filter, never a sort

Pinned items do **not** float to the top of the feed. The timeline is day-grouped, and a pinned item
lifted out of its day has to be rendered in a day it did not happen in — or in a band above the first
section, which is a second, competing grouping on one list. The feed stays chronological; *Pinned
only* narrows it. That also keeps the pin honest as a review verb: it changes what you can find, not
what the record says.

### D5 — the owner-kind filter ships; the entry-kind filter does not

Finding 2 names two uncaptured axes. This ships **one**.

**Owner kind ships** because it answers the question that was actually asked — *just my session
notes* — and because it is **derived**, not authored: `ownerKind` is computed from the entry's own
relationships and flags (ADR 0143), so it cannot be mis-set, left at a default, or mean different
things in two entries written a year apart.

**Entry kind waits** because it is the opposite on both counts. `EntryKind.default` is `.note`, and
the composer offers the kind as an option rather than requiring it — so an unknown but probably large
share of entries are `.note` because nobody chose, not because someone chose *neutral observation*. A
filter over that field would look like it partitions the journal and would in fact mostly separate
"the player picked a chip" from "the player didn't". Ship it when there is a reason to believe the
field is populated deliberately; that is a question about data, not design.

### D6 — five kinds are offered, and an orphan is in none of them

The filter offers **Exercise · Loop · Session · Metronome · Just me** (the last being `.standalone`,
named in the player's words rather than the model's). `.orphan` is **not** offered, and this is a
finding rather than a simplification:

**A note that outlives its unit keeps its name and loses its kind.** ADR 0151 preserves
`ownerLabelAtEntry`, so an orphaned note still says *"Slow Bend · Verse riff"*. But `loop` and
`exercise` nullify, and nothing records **which of the two it had been** — `ownerKind` returns
`.orphan` for both. So an orphaned note cannot be filtered to *Loop*, because the app genuinely no
longer knows it was one.

The consequence is stated on the screen, not hidden: an orphan appears only under **All**. Adding an
`ownerKindAtEntry` snapshot beside the label would fix it, is additive, and is **not done here** — it
would only ever help entries written after it shipped, which is not the entries this ADR exists for.
Logged to `docs/backlog.md` rather than built.

### D7 — the filters go behind the existing options glyph, and it fills

The screen already carries `ellipsis.circle` holding Sort (ADR 0126's grammar; ADR 0176 emptied it of
everything else). *Pinned only* and the owner filter join it, in a section under Sort — which is
exactly the shape `LibraryOptionsMenu` established for the three practice libraries: one fixed-width
trailing item holding sort and boolean filters.

The glyph renders **`ellipsis.circle.fill` whenever anything but the defaults is in force**, the same
rule and for the same reason as `LibraryOptionsMenu.isFiltered`: an active filter must be legible
without opening the menu, and the icon must not change width on a nav bar (ADR 0126).

**The segmented All / Notes / Takes control stays where it is**, in content, not in the menu. It is
the medium axis, it is always visible, and it needs no fill-glyph to announce itself. Three axes do
not fit in one segmented control, and the answer is not four segments at compact width.

### D8 — the filters persist, *because* the screen says they are on

This is the backlog's open question, answered for this screen: **sort, scope, pinned-only and the
owner filter all persist** via `@AppStorage`. Today sort keys persist across the app and every
filter — favourites, instrument, backing-only, show-all, journal scope — is transient `@State` that
resets on every visit.

The rule that resolves it, and the one worth carrying to the other screens: **a filter may persist
exactly when the screen shows, unopened, that it is in force.** The segmented control shows itself.
The menu's contents show themselves through the filled glyph (D7). A persisted filter with no visible
active state is how a player opens a screen, sees three rows out of four hundred, and concludes the
app lost their journal.

**The empty state must name the filter that emptied it.** `emptyTitle` / `emptyMessage` currently
branch on `searching` and `scope`; they gain the pinned and owner cases, so the screen says *No
pinned entries* and how to make one, never *Nothing here yet* about a journal with a year in it.

### D9 — jump to a date, and it is not a heatmap

*Jump to…* on the options menu presents a date picker; choosing a day scrolls the list to that day's
section — or the nearest one at or before it, since most days have no entry. `ScrollViewReader` over
the existing `ForEach(sections, id: \.day)`, which is already keyed by day. Nothing is filtered, so
the days either side stay where they are, which is the whole difference between this and the date
search that already works (finding 3).

**`MonthHeatmap` was the obvious candidate and is rejected**, on two grounds:

- **It would mean something different one screen away.** The heatmap is `PracticeProgress.Month` —
  shaded by *minutes practised* (ADR 0117). A journal heatmap would be shaded by *entries written*.
  Two grids that look identical and count different things, one tap apart in the same tab, is worse
  than one grid.
- **Shading a month by how often you wrote is closer to ADR 0070's line than shading it by how often
  you played.** The practice heatmap describes what you did at the instrument. A writing heatmap
  grades your compliance with a habit *the app asked you for*. ADR 0117 held streaks and goals back
  for a reason and this is the same reason.

## Slices

- **S1 — the pin. BUILT** (`pocket-295-a-journal-you-can-review`). Two columns, the hold-menu verb on
  both rows, the row glyph, *Pinned only* in the menu, the filled options glyph, the empty state that
  names it, and the archive round trip. Self-contained and shippable alone.

  One thing S1 turned up that the decision did not predict: **the empty state earned a file.**
  `JournalTabView` crossed the 400-line cap, and the block that had to move was the one that had just
  grown a third meaning — a journal with nothing in it, a search that matched nothing, and a filter
  left on are three different messages, and only the first is good news. It is now
  `JournalTabView+EmptyState.swift`, which is where D8's rule (*name the thing that emptied it*) is
  written down for whoever adds the fourth.
- **S2 — the owner filter and persistence.** `JournalTimeline.OwnerFilter`, the menu section, the
  `@AppStorage` migration of scope / sort / both filters, and the empty-state cases for D6/D8.
- **S3 — jump to a date.** The date picker and the `ScrollViewReader` scroll.

## Consequences

- **`JournalTimeline` grows a second filter and stays pure.** `filter(_:ownerKinds:)` and
  `filter(_:pinnedOnly:)` join the existing scope and query filters, all four composed in `items`.
  They read only model *properties*, so the tests keep building owners uninserted — the property this
  file's doc comment exists to protect.
- **`Scope` and `SortOrder` need `String` raw values** to cross `@AppStorage`. Both gain one; the
  raw strings are their own names, and each default is written **once** as a `static let` that both
  the `@AppStorage` initialiser and the enum read. A duplicated default literal that drifts from its
  accessor is a trap this project has already hit.
- **The archive carries the pins.** `JournalEntryRecord.isPinned: Bool?` and
  `RecordingRecord.isPinned: Bool?` — optional, exactly like `isStandalone`, so an archive written
  before this decodes as `nil` and restores as unpinned. **No `schemaVersion` bump:** the gate exists
  to refuse files from a *newer* app, and an added optional field is not that. `ArchiveBuilder` writes
  them and `ArchiveRestoreWriter` reads them, or a restore silently loses every pin — the failure
  mode being that the library comes back looking complete.
- **A shared routine is unaffected.** `SharedPracticeBuilder` sends no journal entries and no takes,
  so there is no counterpart to its `isFavorite = false` reset. Nothing here travels to a stranger.
- **The manual moves with it** (ADR 0165 D1): `docs/manual/journal-and-practice-log.md` gains the pin, the filters and
  the jump, since all three are procedure. `scripts/check-manual.py` C7 already enforces the no-shame
  rule on that text, and D1's *the player pins, the app never does* is the sentence it will be
  checking.
- **A precedent is set for the other list screens, and not retro-applied.** D8's rule — persist only
  what the screen shows is on — answers the backlog's persistence question for the Journal only.
  Exercises, Loops, Routines and Songs keep their transient filters until someone decides for them;
  `LibraryOptionsMenu` already has the filled glyph that would make it safe.
- **Two things stay unbuilt and are logged, not forgotten:** an entry-kind filter (D5) and
  `ownerKindAtEntry` (D6).
