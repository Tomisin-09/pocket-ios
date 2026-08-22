# ADR 0178 — a routine you can find

- **Status:** Accepted
- **Date:** 2026-08-22 (`pocket-281-a-routine-you-can-find`)
- **Relates to:** ADR 0035 (the descending flip reverses the whole list, ties included), ADR 0056
  (the sort/search shape the other two practice libraries already use), ADR 0070 (the app never
  grades the player), ADR 0119 (the favourites filter this sits beside), ADR 0127 (the authoring
  gestures the new UI tests finally reach), ADR 0146 (the UI-test discipline these follow), ADR 0173
  (the length and the last-practised date that make two of the four keys possible), ADR 0177 (the
  description the search matches)
- **No schema change.** Two `@AppStorage` keys and a pure comparator; the practice log and the
  length estimate are read, not stored.

## Context

**Routines were the only library in the app with a fixed order and no search.** The toolbar comment
said so outright — *"Routines have a fixed order (newest first), so the menu carries no sort
pickers"* — and so did the manual. Exercises and loops have had both since ADR 0056; songs have had
them longer.

`docs/backlog.md` (Routines, item 3) has held this since 2026-08-16, out of the positioning work
that found routines have less surface than looping does. Two things landed in the six days before
this that changed the cost:

- **ADR 0173** gave a saved routine an estimated length and a last-practised date. Before it, two of
  the four sort keys below did not exist to sort on.
- **ADR 0177** gave a routine a description — which is where the words a player would actually
  search for live, a name being short by function.

So the item was cheap in a way it had not been when it was written, and the two facts it needed were
already on screen.

## Decision

**The Routines library gains search and a four-key sort, both through the machinery the other
libraries already use.**

### D1 — four keys: Recently Added, Name, Last Practised, Length

They are the four questions actually asked when choosing a routine: which is new, what is it called,
when did I last do it, and how long is it.

**Recently Added stays the default, ascending.** It is the order the library had when it had no
choice, so an existing player's list is unchanged until they change it. `RoutineLibrarySortTests`
pins this against the old expression directly, rather than against a remembered ordering.

### D2 — no "times practised" key, deliberately

The tally is on the row already (ADR 0173) and it is a fine thing to *read*. Ranking the library by
it is a different act: the top of that list is the routine you have done most, which is a league
table of the player's own habits and the closest this app would come to grading them (ADR 0070,
design-brief §3.5). A fact beside a name is not a fact used as an ordering.

### D3 — a routine never run sorts **last** ascending, not oldest

`.distantPast` is the obvious stand-in for a missing date and it is wrong: it means "practised
longer ago than anything else", which is a claim about practice that never happened. Absent sorts
after every real date instead — the shape an unrated loop's mastery already uses — so the head of a
Last-Practised list is always something you have actually done.

The descending flip then reverses ties too (ADR 0035), so a never-practised routine leads under
**Descending**. That is the rule being total rather than an exception, and both directions are
pinned.

### D4 — search matches the name **and** the description

Names are short by function, so "lesson", "week 3" and "warm up cold" only ever got written in the
prose ADR 0177 added. Matching names alone would have been a search that misses the searchable half.

**Not the blocks.** Finding "the routine with the pentatonic drill in it" is a real want, but it
means walking every block of every routine on every keystroke, and it makes a query match text that
is nowhere on the row it returns. Left open rather than rejected; if it lands it should show *why* a
routine matched.

### D5 — the sort fields are a projection, and the length comes from the caller

`RoutineSortFields` is a plain value like `LoopSortFields`, so `PracticeLibrarySort` stays
Foundation-only and unit-testable. Both the log-derived dates and `estimatedMinutes` are filled at
the view from `RoutineListFacts` (D7), so nothing in the pure layer touches SwiftData and the
comparator can be tested on plain values.

### D6 — `ordered` takes the derived facts rather than reading them

Two keys need the practice log, and `body` had already reduced it once for the rows (ADR 0173 D6). A
computed property would have rescanned the whole log a second time per redraw — the exact cost 0173
went out of its way to pay only once. It is passed in, and D7 widened the same argument to the
length.

### D7 — the row states its length, trailing and right-aligned

Added on the device pass, from the screen itself: **a sort key whose value the list does not show is
a sort you cannot check.** You order by Length and the list hands back an order with no lengths in
it, so the one fact you sorted on is the one fact you have to open each routine to read. It is ADR
0173 D6's reversal again — the library is the screen you are standing on when you choose — and it
arrived the same way, by looking at the built thing rather than the plan.

**Right-aligned, not appended to the caption.** A right-aligned column of numbers can be *scanned*,
which is exactly what a list sorted by that number is for; inside `8 blocks · 3 rests · ~12 min` it
has to be hunted for on every row. ADR 0173 had already ruled against growing that first caption,
for wrapping reasons that have not changed.

**It stands down for the `PRO` badge.** Both want the trailing slot, and three trailing elements
plus a chevron is a crowded row — but the deciding argument is meaning, not space: how long a
routine takes is not what a free player is weighing up about one they cannot run.

**Nothing is drawn at zero.** An all-rest or all-orphaned routine estimates at 0, and ADR 0173's own
table already settled that `~0 min` is a worse answer than no answer.

The estimate goes through `PracticePlanner.estimatedMinutes(forRoutine:)` — the same call the detail
screen makes — so the sort, the number on the row and the number on the routine's own screen cannot
disagree. All three list-wide derivations (counts, dates, minutes) are computed once per redraw into
one `RoutineListFacts` value: every one is a whole-collection walk, and a row that took them
separately could be handed one redraw's history beside another's lengths.

### D8 — `LibraryOptionsMenu`'s fixed-order overload is deleted

Its doc comment read *"a library with a fixed order (Routines — newest first)"* and Routines was its
only caller. There is now no library without a sort, so the overload goes rather than sitting as
dead code that documents a state the app no longer has.

## The UI tests, and the one route they refuse to take

`PocketUITests` had **no routine file at all** — every other library screen had one — so ADR 0127's
authoring gestures and the detail screen's Cancel/Save contract were device-verified only
(backlog Routines, item 8). `RoutineLibraryUITests` closes most of that, covering what a unit test
structurally cannot: the wiring between a control and the state it should change.

**The sort pickers are deliberately not driven.** They live inside the toolbar `Menu`, and a toolbar
`Menu`'s items do not resolve through `app.buttons[…]` on CI's macOS-15 / Xcode 16 toolchain —
deterministically, and through `-retry-tests-on-failure`. A context menu from `press(forDuration:)`
resolves fine on the same runner, so the two presentations are not interchangeable. A test driving
that menu would pass on every dev machine and fail every CI run, which is worse than no test. The
keys are unit-tested instead and the menu stays a device check until that gap closes.

Four things the writing of these tests cost, all recorded because each produced a *green-looking* or
*wrongly-worded* failure:

1. **A `TextField(axis: .vertical)` is not a `textField` to `app.textFields[…]`.** The query found
   nothing and reported "no Description field in edit mode" — a sentence about the wrong thing. The
   field now carries `UITestHooks.routineDescriptionField` and is matched across every element type.
2. **The typed text accumulated across runs.** The simulator keeps the store, so a run that failed
   before its restore step left its token behind and the next run *appended* — the description read
   `desc264458desc473398desc695656…`, the feature having worked correctly every time, while an
   exact-label assertion could never match. The test sets the field now rather than adding to it.
3. **`tap()` puts the caret where it hits.** Clearing a field that already had text ate the middle
   and left a tail. The caret is placed past the last character first, and the clear asserts it
   worked, so a half-run clear fails where it happened.
4. **A `List` row scrolled out of view is absent from the accessibility tree**, not merely
   off-screen. The list scrolls to keep a focused field above the keyboard, so the assertion after a
   save was reading a screen the target had left. It scrolls back to the top first.

The negative case was proven, not assumed: with `routineMatches` neutralised to `return true`, the
search test fails with *"the search query did not narrow the list"*.

## Rejected

- **Sectioning the list**, the way exercises group by template and loops by song. There is no
  grouping axis a routine carries that a player thinks in — `presetSlug` is provenance, not a
  category — and inventing one to match the neighbours would be a section header nobody asked for.
- **Persisting the search query.** Nothing else in the app does, and a library that opens filtered
  by something you typed last week reads as an empty library.
- **A "times practised" key** — see D2.

## Consequences

- Backlog Routines item 3 closes; item 8 closes for the library and the detail screen's prose, and
  stays open for the authoring gestures behind the toolbar menu.
- `RoutineLibraryView` was at the file-length cap, so row rendering moved to
  `RoutineLibraryView+Row.swift`. The split is along a real seam: what is left decides *which*
  routines are on screen and in what order, and the new file decides what one looks like.
- Every practice library now answers "sort and search" the same way, which is what makes
  `LibrarySortKey` + `LibrarySortPickers` worth having had.
