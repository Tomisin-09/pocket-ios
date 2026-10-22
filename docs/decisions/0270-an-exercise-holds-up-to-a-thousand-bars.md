# ADR 0270 — An exercise holds up to a thousand bars

- **Status:** Accepted. Built on `pocket-385-longer-exercise-holds`.
- **Date:** 2026-10-22
- **Amends:** ADR 0078 — the dwell's **1…12** range becomes **1…250 intervals** on an exercise,
  which is 1,000 bars. Its storage, its floor of one interval and the four-bar step all stand.
- **Amends:** ADR 0221 D3 — every phase's hold on an exercise ranges over 1…250 intervals, not 1…12.
  It is still one range shared by all four phases, and the defaults stand.
- **Amends:** ADR 0226 D3 — its *"an exercise still 12 intervals"* no longer holds: an exercise's
  ceiling is 250. A loop's 1…32 passes, and the ceiling riding on the shape, both stand.
- **Relates to:** 0129 (a routine block's fit is clamped relative to the authored dwell, not to
  the ceiling) · 0189 (no schema change here, so nothing to weigh).
- **Schema:** none. The ceiling is not stored (0226); every stored hold is at most 12 and sits
  inside the new range.

## Context

Tomisin, on a device, on the run setup of *Isn't She Lovely Tempo* at 100 BPM: *"I just realised
that i can't increase this by more than 48 bars... is there a reason this is capped?"*

There wasn't one. 0078 gave the dwell a range of 1…12 without saying why twelve, at a time when it
was shown as a raw count. 0221 turned the count into **Hold**, shown in bars, kept the range and
shared it with the warm-up, reach and back-off holds. On an exercise, where an interval is four bars,
that made the ceiling 48 bars: under two minutes at 100 BPM, too short to play a song through at
command. 0226 raised the ceiling for loops, where twelve passes of a one-bar lick was too few, and
left the exercise at twelve without weighing it.

Asked what the ceiling should be, the answer was *"around 20 mins"*, across warm-up, reach and back
off as well as command.

## Decision

### D1 — An exercise's holds reach 1,000 bars

`RunShape.exerciseHoldCeiling` goes from 12 to **250 intervals of four bars**, so every hold on an
exercise ranges over 4…1,000 bars. All four phases share it, as 0221 D3 set. The step stays one
interval (four bars), and `StepperButton`'s accelerating hold-repeat takes about eleven seconds to
carry a hold from 4 bars to 1,000.

### D2 — A count of bars, not a length of time

An exercise's tempo runs from 30 to 300 BPM, so twenty minutes is anything from 150 to 1,500 bars.
Three ways to turn it into a ceiling were put to the player:

- **600 bars, fixed** — twenty minutes at 120 BPM in 4/4.
- **Twenty minutes at the tempo** — the ceiling is however many bars fit at that phase's tempo.
- **1,000 bars, fixed** — twenty minutes at any tempo up to 200 BPM in 4/4.

The player chose **1,000 bars**. Below 200 BPM it reaches further than twenty minutes (about 33
minutes at 120 BPM, 66 at 60), which a ceiling is free to do: it bounds the control, it does not set
the practice. The length line under the staircase already states what a run will take as the hold
changes, so the time is never hidden.

A time ceiling was the literal reading, and it was turned down for what it does to the control: it
moves when the tempo moves, so raising command's tempo can leave a hold above it, stuck until walked
down. And the warm-up's rungs each play at their own tempo while sharing one hold, so there is no
single tempo to price it at.

### D3 — A staircase bar has a narrowest and a widest width

`RoutineStairs` drew each bar's width in strict proportion to its hold. Under the old ceiling the
widest command was 12 intervals, so a one-interval rung never fell much below 20 points. At 1,000
bars, a hosted-window render showed a 4-bar warm-up rung about **1 point** wide beside the command,
and the warm-up, reach and back-off captions gone under `minCaptionWidth`. It started well before the
ceiling: at 248 bars the rungs were already about 6 points.

Asked, the player chose a **minimum and a maximum**, kept loose: *"proportional or whatever's
easier. But nothing strict."* So a bar is still as wide as its hold in proportion, but:

- **never narrower than 10 points** (`minBarWidth`), so a short rung stays a step you can see. The
  floor gives way when a row can't spare that much for every bar;
- **never wider than 70% of the row** (`maxBarShare`), so a long hold leaves the other phases room
  for their captions; and never so wide that the others can't all have the floor beside it;
- **a lone bar still fills the row** (a command-only run).

A bar past a bound is pinned there and the rest share what's left in proportion, widest first, so
pinning a long command frees room for the short rungs. A default run (one interval a rung, a dwell
of four) is inside both bounds and draws exactly as before. The old 48-bar command, at 80% of the
row, now stops at 70%. That is the one ordinary case that visibly changes, and the back off's caption,
which used to drop out there, now fits. The same view draws loops' and routine blocks' staircases,
which get the same bounds.

No unit test, at the player's word. It was checked by eye in renders of six shapes: the default,
command alone, the old 48-bar ceiling, 1,000 bars beside short rungs, 248 bars, and the most rungs a
run can draw (7 + 1 + 7 + 7) beside 1,000 bars. The 12-point floor tried first truncated the command
caption in that last case to `comma…`, so the floor is 10.

### D4 — Loops are unchanged

A loop's holds stay at 1…32 passes (0226 D3). Nothing here was asked of them, and a pass is a
different unit: its length is the loop's, not a fixed number of bars.

## Consequences

- One constant and its tests. `RunShape.setHold`'s rule for a hold already above the ceiling still
  guards a loop's folded holds. On an exercise it can now fire only for an imported value above
  1,000 bars, and it handles that the same way.
- A routine block fits its exercise's dwell to the slot within 0.5…2.5× the authored dwell (0129), not
  within the ceiling. An exercise authored with a long hold and dropped into a short slot plays long,
  and `effectiveMinutes` already says so instead of promising the slot.
- `RunLength.duration` states a run of ten minutes or more in whole minutes, so a long run reads
  `≈ 133 min`, not in hours. Left as it is: the number is still right.
- **The hold's value field shows `1000`, not `1,000`.** `PhaseCountRow` interpolated the count into
  a localized `Text`, which grouped it, and `1,000 bars` overflowed the 56-point field even at its
  0.6 minimum scale: it read `1,0… bars`, seen in a hosted-window render. It is now
  `Text(verbatim:)`, which also matches the row's caption (`100 BPM · 1000 bars`). Holds step by
  four, so 1,000 is the only four-digit value.
- *"Record this block"* can now run past an hour. A take is AAC mono in an `.m4a` (0069's
  recorder), well under a megabyte a minute, so nothing is capped.

## Alternatives considered

- **600 bars, or twenty minutes at the tempo** — see D2. The player chose 1,000.
- **Raise command's hold alone** — the player asked for all four phases, and 0221 D3's one shared
  range is simpler to read than a command row that reaches further than the rows beside it.
- **Step by more than four bars at long holds** — the hold-repeat's acceleration already covers the
  distance, and a step that changed size partway through the range would make the count jump.
