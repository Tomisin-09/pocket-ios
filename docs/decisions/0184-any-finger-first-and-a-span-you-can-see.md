# ADR 0184 — any finger first, and a span you can see

- **Status:** Accepted
- **Date:** 2026-08-26 (`pocket-275-finger-pattern-and-across`)
- **Relates to:** ADR 0065 build 2 (generative fretboard authoring — this is the editor that ADR
  created), ADR 0083 (position-shifting runs, whose `ReturnStyle` captions this corrects), ADR 0107
  (the generate-or-draw split, which decides which half of the editor the new gate applies to),
  ADR 0116 (multi-instrument — the strip answers for a four-string bass without an instrument branch
  of its own), ADR 0136 F9 / the Chords gate (the empty-content refusal this copies), ADR 0165 (the
  manual quotes the app)
- **Schema:** none. `FretboardRun.fingers` already accepted any `[Int]` including `[]`; nothing about
  the encoded payload changes, and every stored run decodes byte-identically.

## Context

Two problems in the same editor, reported together from a device on 2026-08-24: *"you can't start
with any other finger than the 1st, meaning you can't do like a G♯-G-F♯-F pattern to start with"*,
and *"I feel like the UI for the Across option could be better."*

The first is a real defect, and a total one. `FretboardRunEditor` offered exactly two mutations of
the finger pattern — append a finger, and backspace the last one — and the backspace was guarded at
`count <= 1`. `fingers[0]` was therefore unreachable, and since every run-family exercise seeds from
`FretboardRun.chromaticWarmup` (`[1, 2, 3, 4]`), **every generated run in the app began on the index
finger**. A descending 4-3-2-1 could only be typed as 1-4-3-2-1.

Nothing but that guard stood in the way. The model has always been indifferent: `ascendingGroups`
already guarded `fingers.isEmpty`, `FretboardDrillPreview.activeIndex` already returned `nil` for an
empty drill, and the editor already had a `"Tap a finger below"` empty state authored — a state that
until now could never appear on screen. The bug was five lines of UI, defended by an assumption no
other layer shared.

The second problem is design, and it has a specific shape. **Across** was two `.menu` Pickers with a
static `→` between them, in an editor otherwise built entirely from `EditorStepper` — the only
pickers in the file. It gave neither end a visible tap target, drew both in the same accent so start
and finish were told apart only by reading "low E" against "high e", and the arrow never changed even
when the run travelled the other way. Above all it could not show how much of the neck the run
crosses, while the board that answers exactly that question sat directly above it.

## Decision

**The finger pattern clears to empty and can be reversed in one tap; Across becomes the strings
themselves.**

### D1 — the backspace clears to empty, and empty is a legal editing state

`removeLastFinger` now guards `isEmpty` instead of `count > 1`. That single change makes every
pattern authorable, because the first finger is reachable the moment the pattern can be emptied.

Empty is not a valid *run* — it expands to a drill with no notes — but it is a valid step on the way
to one, and the alternative — a special "edit the first chip" affordance — buys the same capability
at the price of a whole new interaction. The editor is where a half-finished thought is allowed to exist; the save is where
it isn't.

### D2 — Create and Done refuse an empty pattern

`ConfigureExerciseForm.canCreate` gains a `.run` case and `ExerciseShapeSheet` gains `canCommit`,
both reading `!run.fingers.isEmpty`. This is the gate Chords, Strum & Chords and freeform blocks
already use for the same reason — content that has nothing in it has nothing to practise through.

Both are scoped to **generate** mode. In draw mode (ADR 0107) the run isn't the payload, so its
finger pattern is irrelevant and must not block a perfectly good hand-drawn drill.

Done is *disabled* rather than silently declining to write. Swipe-to-dismiss is still available and
discards the edit, as it always has — `ExerciseShapeSheet` has never had a Cancel.

### D3 — ⇄ Reverse, because descending is the case that was impossible

Retyping 1-2-3-4 as 4-3-2-1 is four backspaces and four taps. The button is one. It is the specific
motion the defect blocked, so it gets the specific affordance rather than being left to the general
one.

### D4 — the `Coming back` captions read the run's own fingers

`ReturnStyle.caption` hard-coded *"each string 4-3-2-1 coming down"* and *"each string 1-2-3-4"*.
Those were only ever the chromatic default's reading, and they were true of every run solely because
a pattern could not start on any other finger. It is now a function of `fingers`, and names no
fingers at all when the pattern is empty. A caption that confidently states the wrong fingers is
worse than one that states none.

### D5 — Across is a strip of the strings, not a pair of pickers

Six cells (four on bass), low E on the left — left-to-right on the strip is bottom-to-top on the
board above it. The travelled span fills with the tint, a dot marks the start and a chevron the
finish, so **direction and width are the picture**; the caption underneath (`low E → high e · 6
strings`) confirms rather than carries it.

Two steppers and a restructured pair of menus were both built and compared side by side — as live
Xcode previews and as a published comparison page — before this was chosen. See *Rejected*.

### D6 — a tap moves the nearer end; a tap on an end collapses the span

The nearer-end rule needs no handle to grab and has a property worth stating: **it can never cross
the ends over each other**, because a tap beyond the far end would have that end as its nearest and
would move it instead. Direction therefore only ever changes deliberately, through Reverse.

Tapping a string that is *already* an end collapses the span onto it. This exists because the two
menus it replaced could express a single-string run and a plain range strip cannot — without it, D5
would have quietly removed a capability while improving the control. A tap beside a collapsed span
opens it again, so the collapse is not a trap.

A tie — a tap exactly midway between the two ends — moves the start. It sits strictly between them,
so either answer is correct and this one is deterministic.

### D7 — the tap rule is pure, and lives in `Core`

`StringSpanEdit.apply` is a free function over three `Int`s in `Pocket/Core/Models/StringSpan.swift`,
SwiftUI-free and unit-tested — including both invariants above as exhaustive sweeps over all 216
combinations. It is the one part of the strip that cannot be verified by looking at it, which is
precisely AGENTS.md's test rule.

`NeckStringName` moves there with it and replaces the editor's private `stringLabel`. It answers in
two registers — `short` for a strip cell where six names share a row, `full` for VoiceOver and the
caption — and the only place the short form isn't just the note letter is the pair it exists to keep
apart: lowercase `e` for the high E, uppercase `E` for the low.

### D8 — "Starts on fret" keeps its name

The label means *where finger 1 sits*, which has also been where the run starts only because the
first finger played was always finger 1. After D1 the two diverge: 4-3-2-1 anchored at fret 1 starts
on fret 4 while the field reads 1.

Renaming it to "First finger on fret" was drafted, compared, and **declined** (owner's call, on the
comparison page). The anchor's meaning has not changed, the finger chips already read their real
frets to VoiceOver (`"Finger 4, fret 4"`), and the label has been on screen long enough that the cost
of relearning it outweighs a looseness that only appears in descending patterns. This is recorded so
the next person to notice the mismatch finds the decision rather than re-opening it.

## Rejected

- **Two steppers for Across.** The most consistent option — `EditorStepper` is what every other row
  in the editor uses — and free to build. Rejected because crossing the neck becomes six taps per
  end where the menus took two, the row grows from one line to three, and it still states the span's
  size in words rather than showing it. Consistency was not worth those three.
- **Restructured menus** (From/To captions, filled tap targets, a ⇄). The smallest honest
  improvement, and it fixes the ambiguity. Rejected because it leaves the row as the only pickers in
  a stepper-built editor and, decisively, still cannot show the span — the one thing no arrangement
  of two menus can do.
- **Tap a chip to edit it, drag to reorder.** The most capable answer to D1. Rejected on risk: chip
  reordering is precisely the interaction that proved unreachable in the chord editor
  (`.onMove`, ADR 0172), and D1 + D3 deliver the reported capability without it.
- **A two-handle drag strip.** Rejected for D6's reason — a 6-cell strip on a phone gives handles
  too little room, and dragging cannot express a single-string span.

## Consequences

- Every generated run in the app can now start on any finger. No stored run changes: `fingers` was
  always a free `[Int]` and no encoded blob is touched.
- `FretboardRunEditor` loses its `stringMenu`, `stringLabel` and `stringOrder` and drops to 310
  lines. `ExerciseShapeSheet` gains `canCommit` and sits at **exactly 400 lines — the lint cap**. The
  next line added to that file breaks the build; it wants splitting before it does.
- The strip answers for bass through `Instrument.stringCount` alone, so ADR 0116's four-string neck
  needed no branch here.
- `docs/manual/exercises.md` describes this editor as *"a finger pattern, where on the neck it
  starts, how far across it travels"* — all still true, so `check-manual.py` needed no matching edit.
  It passes unchanged.
- Two new test files' worth of coverage: `StringSpanTests` (11) and six additions to
  `FretboardRunTests`, which now pin the model's indifference to finger order so a future tidy-up
  cannot quietly reintroduce the ascending assumption.
