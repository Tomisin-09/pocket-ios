# 0003 — Practice screen: fixed cockpit + scrollable reference; named, editable loops

- **Status:** Accepted
- **Date:** 2026-06-15

## Context

The waveform practice screen (design brief §4.1) was first built as a single
top-to-bottom `ScrollView`. In use, the controls you touch constantly while
practising — speed, waveform, transport — scrolled off-screen, and the
song-info panel (reference material) pushed the waveform below the fold. The
brief's original §4.1 order placed song info at position 2, open by default,
at the top.

Separately, the Loops/Markers panels were read-only rows showing only a time
range, with no way to name, edit, or choose which loop is active.

## Decision

**Layout — a fixed "cockpit" over a scrollable "reference":**

- **Pinned (never scrolls):** song strip, speed bar, mode line, waveform, time
  ruler, minimap, transport bar.
- **Scrollable:** Loops panel, Markers panel, then **Song info** — demoted to
  the bottom and **collapsed by default** (its summary line stays visible).
- A hairline (white @ 8%) marks the boundary between the two regions.

**Loops & markers:**

- Loops carry an editable **name** alongside the kept time range · speed ·
  repeats. Markers keep their editable label.
- Tapping a row opens a **native detail/edit sheet** (loop: name, speed,
  repeats, delete; marker: name, delete).
- A loop is **activated** by a trailing **play button** on its row; tapping the
  active loop's button toggles play. The active loop shows a green accent and
  drives the waveform/minimap highlight and the transport's loop range.

**Speed bar** is slimmed (readout + slider on one row, compact presets) because
it is the heaviest pinned element.

## Consequences

- This **supersedes the §4.1 ordering** (song info no longer top/open). The
  design brief's screen layout section should be reconciled to match.
- The pinned block has a fixed vertical budget. On the smallest supported
  devices or at large Dynamic Type sizes it can crowd out the scroll area;
  slimming the speed bar is the first mitigation, and further trimming may be
  needed. This is the known risk to watch.
- Loops/markers are now stateful (mutable name/speed/repeats, an active-loop
  selection). The current screen drives this from mock data; persistence and a
  real audio engine arrive in later phases.

## Alternatives considered

- **Single scroll for everything** (original) — rejected: the practice controls
  scroll away and the waveform is pushed below the fold.
- **Tap row to activate, ⋯ menu to edit** — rejected in favour of a play button
  for activation + tap-to-edit, so activating and editing never share one tap.
- **Keep song info pinned at top** (per original §4.1) — rejected: it is
  glanced-at reference, not a constantly-used control, so it earns a scroll slot
  rather than fixed real estate.
