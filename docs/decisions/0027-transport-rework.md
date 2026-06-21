# 0027 — Transport rework: Click on the speed bar, calipers Fine icon

- **Status:** Accepted
- **Date:** 2026-06-21

## Context

After the metronome shipped (ADR 0026), the transport action bar carried four
labelled pills — **Loop · Mark · Fine · Click**. Two nits surfaced in use:

1. **Click read as a transport control.** It sat next to Loop in the same green
   (`active`) as Play and Loop, so it looked like "another play button" rather
   than the tempo accompaniment it is. It's conceptually tempo context, not
   playback.
2. **The Fine pill's glyph was generic.** `slider.horizontal.3` reads as settings
   sliders, not "drag the bound handles."

A third idea — moving the active-loop chip + its exit out of the transport and onto
the waveform — was prototyped here too, but **reverted** (see below).

## Decision

- **Click moves to the speed bar, in its own colour.** The metronome toggle is now
  a compact, icon-only button beside the BPM readout — tempo lives there, so the
  click does too. It gets a dedicated `PocketColor.metronome` teal, chosen to sit
  clear of every existing functional hue (green = live, blue = bars/Fine wash,
  orange = markers, purple = pins, red = danger). It greys out until the song has a
  grid (tempo + the 1), exactly as before. No behaviour change — same
  `toggleMetronome`, same gating; only its home and colour move.

- **Fine pill → calipers glyph.** `arrow.left.and.right` ("drag the edges") replaces
  the sliders glyph, matching what Fine mode actually does (drag the two blue handle
  bounds).

The transport action bar is now three pills — **Loop · Mark · Fine** — with Play /
time / the active-loop chip + ✕ exit unchanged in row 1.

## Loop-exit on the waveform — tried and reverted

The same rework moved the active-loop name/range chip off the transport and replaced
its exit with a small ✕ badge pinned to the loop's region on the waveform (rendered
in an overlay above the gesture recogniser so its tap beat seek/scrub). On device it
**didn't feel right** to the user, so it was reverted: the active-loop chip + ✕ stay
in the transport's top row for now. A less real-estate-hungry exit affordance is
still open — back to the drawing board, not foreclosed. The constraints that ruled
out the speed bar (already the densest fixed element) still hold for whatever comes
next.

## Alternatives considered

- **Loop-exit on the speed bar** (an earlier sketch): rejected — the speed bar is
  already the densest fixed element (readout + slider + BPM + now the click), and the
  loop-exit isn't tempo context.
- **Icon-only transport (drop all labels):** deferred. The decluttering win came
  from relocating Click, not from dropping text.

## Consequences

- The Click is where the eye goes for tempo, in a colour that no longer says "play."
  `SpeedBar` gained three metronome params (defaulted, so its component previews opt
  out for free); `TransportBar` is unchanged from before the metronome shipped except
  it no longer holds the Click pill.
- The loop-exit affordance is unchanged from pre-rework — a known design debt to
  revisit.
