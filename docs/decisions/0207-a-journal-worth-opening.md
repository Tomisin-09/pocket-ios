# ADR 0207 — a journal worth opening

- **Status:** Accepted
- **Date:** 2026-09-09 (`pocket-309-a-journal-worth-opening`)
- **Amends:** ADR 0190 — **D9's rejection of a month grid** is narrowed rather than upheld (D5
  below: a grid *marked by presence* is not the grid D9 refused), and **D7's placement of the owner
  filter** moves from the ⋯ menu to a pinned chip on the new month rail (D6). Everything else in
  0190 stands, including D1, D4 and D8, which this ADR leans on rather than touches.
- **Amends:** ADR 0176 — its refusal of *"a live summary strip above the timeline"* is affirmed and
  distinguished: D4's look-back card sits **inside** the scroll and carries **words, not a number**,
  which is the exact property that objection turned on.
- **Relates to:** ADR 0100 (the space this makes readable, and its read-only rule), ADR 0142 J5 (no
  detail screen — why the note expands in place), ADR 0169 (the exercise mastery the feed has been
  storing and never drawing), ADR 0062 (the leading accent bar `SongCard` established), ADR 0070 /
  `positioning.md` §3 (never grading the player *or their habits* — the constraint every decision
  here is shaped by), ADR 0117 (the practice heatmap this must not be confused with), ADR 0159
  (OR within a facet), ADR 0163 (settings where you use them), ADR 0187 (the quoted-note treatment
  D4 borrows)
- **Schema:** none in this ADR. One new `@AppStorage` key (D4's look-back period), which joins
  `AppSettings.resetJournalFilters()`.

## Context

**Seven ADRs made the journal writable and one made it reviewable; none made it readable.** ADR 0190
gave the feed a pin, an owner filter and a date jump — controls for *finding* an entry. What it did
not touch is what the feed looks like once you have found it, which is the complaint that actually
gets voiced: *it just seems like a long list of text, and nothing about it captures your interest or
gives you a reason to write the next one.*

Five findings, from a pass over `JournalTabView`, `JournalEntryRow` and `JournalTakeRow`.

**1. The space spends none of its own colour.** `PocketColor.journalCardWash` and `journalCircleWash`
exist in `DesignTokens.swift` and are used by Home, the Oracle, the Toolkit and the Metronome. The
Journal uses neither. On a feed row, gold appears on exactly two things — the owner caption and a
take's play glyph — against a `.plain` `List` whose rows sit on `PocketColor.background` with
`padding(.vertical, 2)`. Every other destination in a colour-coded app looks like itself; this one
does not.

**2. `entry.text` has no line limit.** One long session note fills the screen, and a feed whose rows
can each be a page is not a feed.

**3. The row reads in the wrong order.** `KindChip` first, then the time, then the words — at
`.futura(.subheadline)`, the same size as a take's *title*. The thing you opened the screen to read
is the third element and the smallest.

**4. The one differentiator is grey exactly where it matters most.** `KindChip.tint(for:)` returns
`textSecondary` for `.note`, and ADR 0190 D5 already established that `.note` is probably the
plurality — the composer offers the kind rather than requiring it, so an unknown but large share of
entries are `.note` because nobody chose. So the commonest row on the feed leads with a grey pill
whose word is the widest thing on the line.

**5. The app hides its own best material.** `docs/manual/journal-and-practice-log.md` calls the
snapshot *"the point of writing where you played"*; it renders as an 11pt grey mono line at the
bottom of the row. And **exercise `masteryAtEntry` has been captured since ADR 0169 and has never
been drawn on the feed at all** — only the editor's Snapshot section ever showed it.

### The constraint, stated once

Every conventional answer to *make journaling engaging* is already refused here, and this ADR
re-proposes none of them: streaks and consistency scores (ADR 0070, `positioning.md` §3, and
`check-manual.py` C7 fails the build on the word), a writing heatmap (ADR 0190 D9), auto-pinning or
auto-highlighting a "good" entry (ADR 0190 D1), a stats strip above the timeline (ADR 0176), pinned
items floating out of their day (ADR 0190 D4), a journal-entry detail screen (ADR 0142 J5), take
notes and moments on the feed (ADR 0174 §3, ADR 0175 §7), and free-text tags (ADR 0038, ADR 0155).

What is left is typography, silhouette and retrieval — and that is the better answer anyway, because
it is the one `positioning.md` §3 already argues for: the competitor move is *"you are scattered, we
will fix you"*; ours is *"scattered is normal — here is what makes it add up."* **The incentive to
write has to come from the journal being worth reading**, never from the app asking for compliance.

## Decision

### D1 — the kind becomes a rail, and the words take the lead

A 3pt leading `JournalKindRail` tinted by `KindChip.tint(for:)` replaces the leading chip **on the
feed**, and `entry.text` moves to `.futura(.body)` at the top of the row's content.

**The chip's capsule goes; the word stays.**

*This is an amendment, dated 2026-09-09, and the original reasoning is kept because the correction is
the useful part.* The first build dropped the **word** as well as the capsule, arguing it was the
widest thing on the row and the least informative, since the rail carried the kind in colour and a
grey label reading "Note" was noise. On device that was simply wrong, and obviously so: **a colour is
learned, a glyph is guessed, but a word is known.** Seven kinds is more hue than anyone memorises,
and 🎯 against 🧗 at caption size is not a reliable read — the row had stopped *stating* what an
entry was and started asking you to infer it. Legibility is not a tax on a design; it is the design.

So the row draws the emoji **and** the label. What stays dropped is the **capsule**: the rail is
already spending this kind's colour three points to its left, and a filled pill beside it is
accent-on-accent — the class of defect that survives every green build. Plain tinted text carries the
word at a fraction of the width the chip needed.

**`KindChip` itself is untouched** and remains the shared component the composer's `EntryKindChipRow`
and `RoutineBlockDoneView` draw, where the word is the thing being *chosen* rather than *reported*.
`KindChip.tint(for:)` stays the single source of truth for kind colour, now read by the rail and the
label as well as the pill.

**`KindChip` itself is untouched.** It remains the shared component the composer's `EntryKindChipRow`
and `RoutineBlockDoneView` draw, where the word *is* the thing being chosen, and
`KindChip.tint(for:)` remains the single source of truth for kind colour that the rail now also
reads. A second colour table would have been the obvious shortcut and is exactly the drift this
project keeps paying for elsewhere.

**The idiom is borrowed, not invented.** `SongCard` has drawn a leading accent bar tinted by mastery
tier since ADR 0062 (`SongCard.swift:13`). Using the same shape means the feed reads as this app
rather than as a new visual language bolted to one screen.

**Takes take the same rail, in gold.** A take has no `EntryKind`, and gold is the space's own hue.
The Journal's premise is one feed (ADR 0100), so the two row types must draw one silhouette — the
same reasoning ADR 0190 D2 applied to a verb, applied here to shape. A take's title also moves to
`.body`, because on that row the title *is* the content line, and leaving it at `.subheadline` beside
a `.body` note would make takes read as a lesser kind of row.

### D2 — the note clamps to four lines and expands in place

`lineLimit(4)`, toggled by a tap on the text.

**In place, not on a screen of its own.** ADR 0142 J5 refused a journal-entry detail screen —
*"a second place to read one entry… the honest destination is the unit itself"* — and that reasoning
holds, but it does not cover the two owner kinds that have no unit: a session note and a standalone
note have no owner screen to be sent to. Expansion is what serves those without reopening J5.

**A plain gesture, never a `Button`.** Feed rows carry a `contextMenu`, and a `Button` inside one
fires on both the tap and the hold — a trap this project has already hit and written down. The text
takes `contentShape` + `onTapGesture`.

**And it does not take `.isButton` either**, which is the less obvious half. Adding that trait to
make the affordance announceable **retypes the element from `staticText` to `button`**, which
misreports a note as a control to VoiceOver and breaks every automation query that finds a feed row
by its words. The affordance goes on an `accessibilityAction(named:)` instead: the note stays
content, and the action carries the gesture.

### D3 — the snapshot says everything it has stored

The `.exercise` branch gains `masteryAtEntry` beside its BPM label.

**Rendered only when present**, unlike the `.loop` branch's deliberately paired readout. ADR 0169
did not back-fill, so an unconditional `MasteryReadout` would hang an em-dash off every entry written
before that ADR shipped — turning a decision to show more into a year of rows that look broken.

### D4 — month dividers, because a day header never says the year

The first day-section of each month carries a month label. A day header reads *Today*, *Yesterday* or
*26 Aug*; after a year of entries none of them says *which* August, and a long scroll has nothing to
grip. One label, no control, no state — the cheapest structure available.

### D5 — the jump becomes a hand-built month grid, marked by presence

`DatePicker` exposes no per-day decoration hook on iOS 17 or 18, so a grid that can say *this day
holds something* has to be built. It is, and **ADR 0190 D9's rejection of a month grid is narrowed
rather than upheld** — which requires answering both halves of that rejection, because only one of
them is about ADR 0070.

**The ADR 0070 half is thin, and this repo already said so.** `docs/backlog.md` records it plainly:
*"a count is a fact, but a month grid shaded by counts grades a habit… the distinction is real…
**but it is thin enough that building toward it by eye would cross it without anyone deciding to.**"*
That is a caution about drift, not a proof — and the way to honour a caution about drift is to decide
the line explicitly rather than inherit it. **The line is presence, never volume.** *Which* days hold
entries is the navigational fact; *how many* adds nothing to picking a day to read and is the only
part that carries a reading about the player's habits. A day with nine entries and a day with one
look identical.

**The twin-grid half is the strong one, and it survives the change to marking.** `MonthHeatmap` sits
one tap away in the same tab, shaded by *minutes practised*. Two grids that look alike and count
different things is worse than one grid, and marking rather than shading does not by itself fix that.
So the new grid answers it in its own visual language: a **stroked ring**, never a filled cell; **no
opacity ramp**; and **no Less→More key** — the absence of a legend being the clearest available
statement that there is no scale, because nothing is being measured.

**This was checked rather than argued.** Both grids were put on a device and compared by the owner
on 2026-09-09: they read as sufficiently different. That is the evidence this decision rests on —
the objection is about what two pictures look like to a person, and no test can discharge it.

**Only a day that holds something is tappable**, and that is a simplification, not a restriction:
ADR 0190 D9's at-or-before rule now has nowhere to fire from this control, so the sheet drops the
footnote that explained it and the *Jump* confirm button with it. The tap *is* the choice.
`JournalTimeline.jumpTarget` stays — it is pure, tested, free, and D8's look-back card hands it dates
that genuinely need the rule.

### D6 — a month rail, and Show comes out of the menu onto it

Above the feed: a **fixed** *Show* chip, then the months the feed can currently reach, scrolling.

**The chip cannot scroll.** ADR 0190 D8 permits these filters to persist across visits *only* because
the screen states them unopened; a filter chip that can scroll out of view breaks that guarantee
**intermittently**, which is worse than breaking it outright. So the chip sits outside the
`ScrollView` and only the months move.

**This is why Show leaves the ⋯ menu, amending ADR 0190 D7.** D7 put it there and satisfied D8 with
the filled `ellipsis.circle.fill` glyph — a signal that *some* filter is on. A chip that says
*Show: Loop or Session* on its face is strictly more of what D8 asked for. The menu keeps *Sort*,
*Pinned only* and *Jump to…*, and `isFiltered` narrows to `pinnedOnly` accordingly: a glyph must fill
for filters **its own control holds**, or it points at the wrong place.

**The months are derived from `visibleDays`**, not from every stored entry, so the rail inherits every
active filter and can never offer a door to an empty room. And a month that holds nothing is simply
absent — which is the same "shape of what you have written" ADR 0190 S3 already blessed in the
picker's greying, carried onto a control you do not have to open.

**There is no "you are here" highlight.** Marking the month at the top of the feed means tracking
scroll position, which iOS 17 gives no cheap way to do, and an indicator that goes stale the moment
you scroll past a month boundary is a statement about where you are that is wrong most of the time.
The rail is a set of doors, not a position readout.

### D7 — the pinned day header is the jump control

`.listStyle(.plain)` already pins the day header while you scroll, which makes it the one thing on
screen that is both permanently visible and already about *when*. So it opens the jump sheet.

ADR 0176 moved the practice log out of the ⋯ menu on the finding that **a destination reached only
from a menu is one most players never find**. *Jump to…* had precisely that problem, and this is the
same fix costing no new chrome. **The ⋯ item stays**: this door is discoverable, that one is
labelled, and VoiceOver should not have to discover that a header happens to be a button.

### D8 — the journal hands something back, and it picks by date alone

One past entry, quoted, at the top of the feed.

**Why it is allowed to pick at all.** ADR 0190 D1 refused auto-pinning because *"an app that decided
which of your practice mattered would be grading your practice"*, and that binds anything choosing an
entry on the player's behalf. This picks by **date proximity** — the one axis carrying no opinion, and
the axis ADR 0190 D9 already blessed for the jump. `JournalLookback` reads no `kind`, no `isPinned`,
no mastery, no tempo, no length. **Even the tiebreak is a date**: two entries equidistant from the
anniversary are separated by which is more recent, because there is no *better* available to consult.

**A widening ladder, and the heading names the rung.** An exact anniversary is empty on most days, so
the card would almost never appear and the feature would quietly die. The search widens day → week →
month, and says which it found — *"A year ago today"* / *"…this week"* / *"…this month"*. A card that
said *today* about something from three weeks either side would be buying its hit rate with a small
lie.

**Why this is not the strip ADR 0176 refused.** That refusal is specific and it is affirmed here: a
summary strip *"puts a permanent number above a timeline whose entire content is words"* and hands a
fresh install a zero. This carries **words**, which is what the screen is for; it lives **inside the
`List`** and scrolls away rather than sitting above it; and it is **absent entirely** when nothing is
found — never an empty state, never a zero, the rule `HomeStatsStrip` already follows.

**Off / 6 months / 1 year / 2 years**, defaulting to a year, on the ⋯ menu — settings where you use
them (ADR 0163), since it changes what *this* feed shows. A `Picker` is safe in that menu where the
owner facet was not: single-select means the menu closing on the first tap *is* the interaction,
rather than a third of it (ADR 0190 D10).

**It reads the unfiltered journal**, because it is not a feed row. Narrowing to *Pinned only* should
not silently change which year-old note the app offers. It is hidden while searching (a search is a
question, and this is not part of the answer) and under **Takes**, where the player has asked for
recordings and this card only ever quotes writing.

**And it is deterministic** — the same store on the same day gives the same card. A look-back that
reshuffled on every redraw would be a slot machine, and would change the top of the feed under the
reader as they scrolled.

### D9 — the compact composer shows what the note will keep

`QuickJournalSheet` gains a *This note will remember* line above `destinationLine`.

**The wrong composer had it.** `JournalSheet` has previewed the snapshot since ADR 0058; the compact
sheet — the door most notes are actually written through, on every run screen and the metronome — has
only ever said *where* a note lands, never *what it takes with it*. The manual calls that snapshot
*"the point of writing where you played"*, and a composer that never shows it is asking for trust it
could simply demonstrate. This is also the honest answer to *"nothing makes writing feel worth
doing"*: not a reward for writing, but sight of what writing buys.

The wording lives on `JournalOwner.captureSummary` beside `destinationLine`, for the reason ADR 0155
§5 put the sentence there — an owner that records nothing has no honest fragment to assemble, and
`.standalone` returns `nil` so the composer omits the line rather than labelling a value that means
"there isn't one". *"log"* stays out of it (ADR 0176 D6).

## Slices

- **S1 — the row. BUILT** (`pocket-309-a-journal-worth-opening`). The rail, the emoji, the `.body`
  text, the four-line clamp with tap-to-expand, exercise mastery on the snapshot, and the take row's
  matching silhouette.

  Two things worth recording. **The rail had to be greedy, not measured** — a `RoundedRectangle`
  with only its width fixed fills whatever height the row turns out to be, including a note the
  reader has just expanded; anything that computed a height would have to be recomputed on expansion
  and would be wrong for one frame. `SongCard` already relied on this and did not say so.
  And **nothing in the suite matched the chip's label**, which was the risk worth checking before
  removing a string from a screen the manual shoots: the row's identity in every test is its text and
  its accessibility labels, neither of which moved.

  **What the suite did catch was an accessibility regression, and it is the finding worth keeping.**
  The first build made the note's expand affordance announceable with `.accessibilityAddTraits(.isButton)`.
  That trait does not annotate an element — it **retypes** it, `staticText` → `button` — so
  `RowUndoUITests.testUndoRestoresADeletedJournalNote` stopped finding the row it had just written,
  because the feed's rows are located by `app.cells.containing(.staticText, identifier:)`. The test
  failure was the cheap symptom; the expensive one was that every journal note would have announced
  itself to VoiceOver as a control. `accessibilityAction(named:)` gives the same affordance and
  changes no types. **The general rule: a trait that describes what an element *is* must not be used
  to advertise what it can *do*.**

  ⚠ **And the run that found it reported success.** `xcodebuild … ; echo "EXIT=$?"` makes the
  compound command's status the **`echo`'s**, so the harness recorded exit 0 over `** TEST FAILED **`.
  The verdict line is the only thing worth believing — `grep -E "TEST SUCCEEDED|TEST FAILED"` —
  which is the same lesson this repo already wrote down about pipes, arriving through a different
  door.

- **S2 — the dates. BUILT** (same branch). `JournalMonthLayout` and its tests, the month grid, the
  month rail with its pinned Show chip, month dividers, and the day header as the jump control.

  **The empty state's instruction broke, and it is the third time that sentence has broken.** It read
  *"Open ⋯ ▸ Show and choose All"* — true until Show moved to the rail. It had already been rewritten
  once, from *"Set Show back to All"* when the picker rendered inline with no title (ADR 0190 S2).
  Each break is the same failure: **an instruction naming a control that is not drawn**. The rule is
  now cheap to satisfy, because the control it names is finally on the screen the instruction appears
  on. `docs/manual/journal-and-practice-log.md` documented the same dead route and moved with it.

  ⚠ **`Color.clear` is greedy, and it broke the grid at the `.large` detent — visible only on
  device.** Blank cells (the days belonging to a neighbouring month) were `Color.clear`, and a
  `Color` expands in **both** axes, so each blank grew to fill whatever height the sheet offered.
  The effect was not a uniformly stretched grid, which would have been obvious: only the **two weeks
  that contained blanks** moved, flung to the top and bottom of the sheet while the four full weeks
  stayed tightly spaced in the middle. At the `.medium` detent there was no slack to expand into and
  it looked perfect. The fix is a **hidden day label** rather than a spacer — it occupies exactly
  what a day occupies at every Dynamic Type size, because it is one. **The general rule: a blank
  cell in a grid should be the real cell made invisible, never a different view chosen to be empty.**

  **`JournalTabView` had to shed the list to stay under the cap** — `JournalTabView+List.swift` is
  the fifth file that view has spun off. Moving `row` out immediately failed the build on four
  `private` members, which is `private`-is-file-scoped arriving for the fifth time in this feature and
  is worth expecting rather than rediscovering.

- **S3 — the look-back card. BUILT** (same branch). `JournalLookback` and its tests, the card, the
  persisted period, and `QuotedNoteView` extracted from `OracleView` so the Oracle and the Journal
  quote the player identically in their own hues.

- **S4 — what the note will keep. BUILT** (same branch). `JournalOwner.captureSummary`, rendered in
  `QuickJournalSheet`.

  **It moved `bpmLabel` out of a view, and the compiler is what asked.** That formatter was a
  `static` on `JournalSheet`; under Swift 6 a `View` is `@MainActor`, so its statics are too, and the
  first **non-view** caller failed to compile against what is a pure string function. AGENTS.md's
  *pure logic stays pure* usually reads as a style note; here it arrived as a build error. It now
  lives on `LoopProgressFormat` beside `percentLabel`, with a forwarding alias left on `JournalSheet`
  because four call sites and a test comment name it through that type.

  ⚠ **`check-manual.py` C16 failed on a back edge that does not exist.** The new *Amended by* field
  in ADR 0190 argued its case in prose, and that prose named another ADR — so the checker, which
  reads **every** `ADR NNNN` in that field as a declared amendment, recorded a claim that 0190 amends
  an ADR it has nothing to do with. **That header field is a machine-read declaration, not a place to
  argue**; the argument belongs in the body, and any other ADR named in the field has to be named
  without the words "ADR".

## Consequences

- **The manual's prose survives; two of its figures do not.** Nothing this ADR changes contradicts a
  sentence in `docs/manual/journal-and-practice-log.md` — the kind table describes the *composer's*
  chips, which are untouched, and the take row still shows a name, a duration and a time. What moves
  is what the screen looks like, so `journal/timeline` and `journal/take-row` need reshooting. Slugs
  are **ids** and must not be renamed (ADR 0176 D7).
- ⚠ **`journal/take-row` carries a pixel `crop:` and the row's height has changed.** A crop is
  coordinates into a full screenshot, so it does not fail — it silently captures the wrong band of
  the screen and produces a clean, plausible photograph of something else. It has to be re-derived
  from the new shot rather than carried over, and this is the general hazard: **a `crop:` is a
  figure that cannot go stale loudly.** Every shot slug with one is exposed to any layout change on
  its screen, and nothing in the pipeline says so.
- **`KindChip` now has two readers with different needs** — the composer draws the pill, the feed
  reads only `tint(for:)`. That is the intended shape (one colour table, two presentations), but it
  means a future kind added to `EntryKind` has to be checked in both places, and only one of them is
  where the enum's author will be looking.
