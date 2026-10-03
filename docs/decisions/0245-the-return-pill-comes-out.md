# ADR 0245 — The return pill comes out

- **Status:** Accepted — decided with Tomisin, 2026-10-03. Built on `pocket-357-retire-the-return-pill`.
- **Date:** 2026-10-03
- **Supersedes:** ADR 0201 D4 and ADR 0202 D4 — the return pill and the rule behind it. Everything
  else in both stands: the span history and widen back (0201 D1–D3, D5), the snag ticks, the Snags
  panel and the three-row history (0202 D1–D3, D5).
- **Relates to:** 0149 (the first-song walkthrough, whose speed beat still reads `speedIsUserDriven` —
  D3) · 0124 (the one speed axis, and the Reset and preset pills that remain the way back)
- **Schema:** none. The pill was never stored.

## Context

ADR 0201 added a pill beside the speed readout that offered the speed you had just dropped from, and
ADR 0202 fixed it so a drag could raise it at all and made it go back one step at a time.

On device, 2026-10-03, at 0.71×, the pill looked like this: **`↶ 1.0…`**. The speed bar's row already
holds the readout, the slider, the BPM, Repeat and the metronome. At phone width there is no room for a
sixth item, so the pill truncated the one number it exists to show. And because the slider is the only
flexible item in that row, **the slider got narrower whenever the pill appeared**, and wider again when
it went.

Tomisin circled it and judged it less useful than expected. That follows from what was already on the
bar. Most drops start from full speed, and **Reset** undoes those.
The presets cover 0.25×, 0.50× and 0.75×, and tapping the readout takes an exact value. The only case
the pill handled alone was going back to a speed below 1.0 that is not a preset, for example 0.85×
after dropping to 0.70×. That case is real, but it does not justify a control that changes the
slider's width.

## Decision

| # | Decision |
|---|---|
| **D1** | **The return pill is removed**, along with `TempoReturn`, `TempoReturnTests`, `speedBeforeDrop`, `speedAtGestureStart` and `returnToSpeedBeforeDrop`. Nothing takes its place in the row. |
| **D2** | **The ways back are the ones the bar already had:** `Reset`, the preset pills, and numeric entry on the readout. |
| **D3** | **`speedIsUserDriven` stays.** ADR 0201 added it for the pill, but the first-song walkthrough's speed beat (0149) now reads it, so that only the player's own change counts and not the speed the app sets when a loop arms. |

### Rejected

- **Moving the pill to the preset row, beside `Reset`.** That row has room, so it would fit. But two
  "go back" controls side by side read as two resets, and the feature was judged not worth its space
  anywhere.
- **Making it a hold on `Reset`.** A hidden gesture for a rare case. ADR 0244's rule would then need a
  tip for it, which costs more than the feature saves.

## Consequences

- When you drop to a speed below 1.0 that is not a preset, getting back takes the readout's numeric
  entry or the slider. ADR 0201 wanted to fix that absence, and it is back, but only for the case
  that was rare.
- The speed bar's row no longer changes width during a session.
- The manual's song-player reference loses its *return pill* bullet. A figure showing the bar at a
  reduced speed belongs on the reshoot list.
