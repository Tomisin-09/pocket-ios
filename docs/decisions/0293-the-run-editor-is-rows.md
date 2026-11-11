# ADR 0293 — The picking-run editor is rows: Up and back joins Movement, Rhythm is a row

- **Status:** Accepted — built (2026-11-11, `pocket-420-run-editor-rows`), for 1.4.1
- **Date:** 2026-11-11 (`pocket-420-run-editor-rows`)
- **Amends:** ADR 0065 — build 2 demoted the run editor's subdivision to an "Advanced" disclosure. The
  warm-up / picking / legato editor has no Advanced now: Rhythm is a plain row (D3). The scale and
  arpeggio editors keep theirs. · ADR 0083 — its "Movement" disclosure sat beside Advanced, with
  up-and-back on the primary face. Up and back now opens Movement, with Coming back directly under it
  (D2), and Movement's contents are rows of the form rather than the inside of a `DisclosureGroup` (D1).
  The shift and stagger controls, their ranges and the neck-fit cap stand.
- **Relates to:** 0258 (rows that say their value, which Movement's summary now does, D4) · 0061 (Futura
  for UI text, which the stepper values now use, D5)

## Context

Tomisin, on device (2026-11-11), about the Warm-up, Picking and Legato templates: opening **Advanced**
or **Movement** felt laggy, *"like the screen regenerates"*. The values on the right of those rows
("Off", "Eighths") were too small. **Up and back** belonged in Movement, and Advanced should just be
Rhythm.

The code agreed on each point:

- **The whole editor was one Form row.** `FretboardRunEditor` was a single `VStack` placed in a `Section`
  (`ConfigureExerciseForm.runSection`, `ExerciseShapeSheet.runSection`). That row also held the preview,
  a `TimelineView(.animation)` that redraws every frame. Expanding either `DisclosureGroup` changed that
  one row's height, so the list re-measured and animated a very tall cell while its contents kept
  redrawing. This is the likely cause of the "regenerates" look. It was not profiled; the device check
  was the test, and it passed (Consequences).
- **The summaries were caption-size.** `EditorDisclosure` set its summary in `.futura(.caption)`, the
  smallest text on the editor, beside a semibold subheadline label.
- **Up and back and its follow-on were in different groups.** The toggle sat under Advanced, while
  **Coming back** (Retrace / Restate), which only appears once Up and back is on, sat under Movement. So
  turning a switch on in one group made a control appear in another.
- **Advanced held one menu once Up and back left it,** and its collapsed summary already printed the
  menu's value, so opening it showed "Eighths" twice.

A screenshot raised four more, which went into the same mockup and were approved with it (*"Let's do
it"*): the editor's own caption repeated the section footer under it; the compact stepper drew "Off" in
monospace, where it reads as "0ff", making three faces for values on one screen; and the finger
pattern's reverse and delete buttons were grey while the Across reverse beside them was terracotta.

## Decisions

**D1. The editor is several Form rows.** Its body is a `Group`, so the `Section` gets a row per control:
the preview (Watch · Display over the board), the finger pattern, Starts on fret, Across, the Movement
header, Movement's rows when open, and Rhythm. Opening Movement **inserts rows**; the row holding the
board is never resized. Each row carries `.listRowBackground(Color.clear)` and a hidden separator, so the
editor still reads as one surface. The call sites are unchanged.

**D2. Up and back opens Movement, and Coming back sits directly under it.** Movement's rows, in order:
**Up and back**, **Coming back** (only while it's on), **Shift up after each run**, **Passes** (only
while shifting), **Stagger per string**. A row that exists only because the one above it is on is inset
behind a 2 pt hairline in the tint (`editorDependentRow`), so the dependency is visible without a label.

**D3. Rhythm is a plain row, and the run editor has no Advanced.** With Up and back gone it held one
dropdown: two taps for one value. The dropdown is now a row of its own under Movement, and it says its
value.

**D4. Movement's collapsed row leads with the path.** It reads *Up and back* or *One way*, then only what
differs from the defaults: *restate*, *↑2/run × 3*, *diag +1*, two spelled out and the rest counted
(`EditorSummary.line`). The old empty read, *Off*, would now sit on a row whose run still goes up and
back. The scale editor's Advanced summary leaves *Up and back* out as noise; there it sits beside
settings that say more, while here the path is what the row is about.
`FretboardRun.movementSummaryParts` is the pure function; `MovementSummaryTests` holds it.

**D5. Values on the right are Futura at the label's size.** The disclosure summaries go from caption to
subheadline (`EditorDisclosure` and the new `EditorDisclosureHeader`). `EditorStepper`'s compact value
goes from `pocketMono` to Futura, since the design brief keeps monospace for times and BPM, not fret
counts. `RhythmRow` wraps its `Picker` in a `Menu` with a Futura label, because a `.menu` picker draws
its own label in the system face. All three pieces are shared, so the **Scales and Arpeggios** editors
get the larger summaries and the Futura values and Rhythm label too; their layout is unchanged.

**D6. One caption, and the actions take the tint.** The editor's own closing caption is removed; the
section footer says the same thing. The finger pattern's reverse and delete buttons are `.borderless`
in the tint, like the Across reverse and the stepper chevrons, and dim when disabled.

## Consequences

- **The lag fix held on the device.** D1 removes the one-tall-row resize that best explains the look
  Tomisin described. Nothing here measured it, since a mock or a simulator can't show how it feels, so it
  went to the phone: on an iPhone 16 Pro (iOS 26.6, 2026-11-11) Tomisin found Movement "much smoother".
  That is a judgement by feel, not a profile. If a stutter comes back, the next suspect is the preview's
  per-frame redraw itself.
- **The Scales and Arpeggios editors are still one row each,** with their Advanced as a
  `DisclosureGroup`, so they likely stutter the same way. Splitting them is the same move as D1 and isn't
  done here.
- **`exercises/configure` is stale** (the finger pattern's buttons are terracotta now), as is any figure
  showing a stepper or a Rhythm value. It goes on the reshoot list rather than being shot per branch.
- The manual's prose stands: it says you set *"whether it moves"*, which Movement still covers, and it
  names neither Advanced nor Up and back.

## Alternatives considered

- **Keep `DisclosureGroup` and let the List lay its contents out as rows.** A `DisclosureGroup` placed
  directly in a List does that, but it takes the List's own outline styling (its chevron, its indent)
  rather than the editor's. A header row plus explicit rows behind an `if` draws exactly what the
  editor asks for and is plain to read.
- **Rename Advanced to Rhythm and keep the disclosure.** That's what was first asked for. It would leave a
  disclosure opening onto a single dropdown that it also summarises: the double "Eighths" again.
- **A small board docked under the title once the full preview scrolls away.** It was in the mockup, so
  the board stays in view while you adjust Movement. It needs scroll-position tracking, which on the
  iOS 17 floor means measuring geometry by hand, and it is a separate change. **Not decided here.**
