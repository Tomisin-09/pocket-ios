# 0080 — Free scrub: a seek scrub snaps to landmarks, not the pulse

- **Status:** Accepted
- **Date:** 2026-07-11 (`pocket-130-free-scrub-landmark-snap`)

## Context

ADR 0021 made a released tap-seek/scrub **catch** the structure it lands near —
markers and saved-loop edges — and ADR 0022 folded the **beat grid** into the
same candidate list, so a seek could lock to the pulse too. The live drag stays
raw (it tracks the finger); only the release catches, within a tolerance scaled
to the zoom (`WaveformGesture.snapTolerance · viewport span`).

Device testing surfaced a cost of that generosity. On a **scrub** release the
candidate set includes **every beat**, and at most zooms the grid is dense
relative to the catch radius, so a deliberate scrub to a point *between* beats
gets yanked onto the nearest one. The playhead feels magnetized to the pulse —
you can't land it where you meant to.

The minimap already made the opposite call for exactly this reason:
`seekMinimapSnapping` (ADR 0021 plumbing, `WaveformPracticeModel+Snap.swift`)
**excludes the beat grid** — its own note reads *"on the compressed strip the
beats pack too densely to land cleanly, whereas markers and loop edges are the
sparse landmarks actually drawn there."* The detail waveform's scrub release
never got that treatment. This ADR converges it onto the same geometry.

## Decision

- **Split a tap-seek release from a scrub release.** The gesture layer already
  distinguishes them — `didScrub` in `WaveformCanvasGestures.handleEnded` is set
  once the finger crosses the scrub threshold. A **tap** is "take me to that
  structure"; a **scrub** is "put the playhead exactly here." They should snap to
  different things.
- **Tap-seek → snap to the full candidate set** (markers + loop edges + beats),
  unchanged from ADR 0021/0022.
- **Scrub → snap only to the sparse landmarks** (markers + loop edges),
  **dropping the beat grid.** A deliberate scrub across the pulse lands where the
  finger lifts, but still catches a marker or loop edge it was aimed at. This is
  the *same* candidate set the minimap already uses — the two seek surfaces now
  share one rule.
- **Everything else about the catch is untouched.** The live drag stays raw;
  the release reuses the pure `WaveformGesture.snap`, the zoom-scaled
  `snapTolerance`, and the light catch haptic verbatim. No new geometry.

Implementation is small: `handleEnded` routes a scrub release to a landmark-only
variant (e.g. `seekSnapping(_ fraction:scrubbing:)` choosing between the full and
the beat-excluded candidate lists, mirroring `seekMinimapSnapping`); a plain tap
keeps the full-set path.

## Consequences

- Free scrubbing lands cleanly between beats — the reported "stuck to beats"
  feel goes away — while a **tap** still magnetizes to structure, so quick "jump
  to that marker / loop edge / beat" stays a single tap.
- **Beat snap for *placement* is deliberately not affected.** Loop-edge commit
  (`endDragSelection`), Fine-handle release (`endMoveHandle`), and the downbeat
  set still snap to the pulse — that's where beat snap earns its keep. Only the
  seek *scrub* stops catching beats.
- The detail waveform and the minimap now source seek candidates the same way,
  so the "sparse landmarks vs dense pulse" rule lives in one place instead of two
  divergent handlers.

## Out of scope (follow-ups)

- **Downbeats-only on scrub release** — a middle path between "all beats" and
  "no beats": catch bar starts (the `isDownbeat` subset from `BeatGrid`) but not
  ordinary beats. Rejected for now in favour of matching the minimap exactly;
  revisit if practice shows people want bar starts back on a scrub.
- **A visible snap indicator** (a tick/glow on the caught candidate) — still
  deferred, as in ADR 0021.
- **The scrub detent haptic** (backlog "haptic detents" item 2) — a light tick as
  a live scrub crosses a landmark. Related feel work, but a separate slice; this
  ADR only changes *what a scrub release snaps to*, not the live drag.

## Alternatives considered

- **Leave beats in on scrub release (status quo).** Rejected: it's the exact
  behaviour that made a free scrub un-landable between beats.
- **Drop snapping from a scrub release entirely** (raw landing, no catch).
  Rejected: markers and loop edges are sparse, intentional landmarks you often
  *are* aiming for; keeping those while dropping the dense grid is the point.
- **Downbeats-only** — see Out of scope; a reasonable variant, deferred for
  consistency with the minimap rather than introducing a third candidate set.
- **Tighten the tolerance instead of trimming candidates.** Rejected: a tolerance
  small enough to sit between adjacent beats at a tight zoom would be too small to
  reliably catch a marker or loop edge — it fights the whole purpose of snap. The
  problem is the *density of candidates*, not the radius.
