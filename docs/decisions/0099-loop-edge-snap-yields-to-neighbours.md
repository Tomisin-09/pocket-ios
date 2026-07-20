# 0099 — Loop-edge snap yields near a neighbour; long-press suspends it

- **Status:** Proposed
- **Date:** 2026-07-20 (`pocket-161-loop-snap-neighbours`)

## Context

On-device user testing (2026-07-20, plan-of-attack Note 4) flagged that snap
**fights loop-handle drags when two loops sit close together.** Range-editing a
loop lifts it into the A/B span (ADR 0041, `liftActiveLoopToSpan`); the live edge
drag is raw, but on **release** `endABHandle` catches the nearest candidate within
`snapTolerance` (0.03 · visible span, `WaveformPracticeModel+Snap.swift`). The
candidate set includes **neighbouring loops' edges**.

When the gap between two loops is narrower than the catch radius, the neighbour
edge's snap zone covers the whole gap — releasing anywhere in it yanks your edge
onto the neighbour, slamming the loops flush. You can't leave a deliberate small
gap between two loops. Snap is helping you line up with structure (its ADR 0021
job) but at the cost of fine placement in exactly the case where you're being
deliberate.

Two levers fix this without weakening snap generally: soften the *neighbour-edge*
magnet in tight quarters, and give a manual override for arbitrary precision.

## Decision

Two independent pieces, both scoped to the **loop-edge release snap** (they leave
seek/scrub snapping — ADR 0080 — untouched):

- **1 — Neighbour-edge snap yields in crowded space.** A neighbouring loop's edge
  gets a **reduced catch radius = half the gap** between it and the moving edge,
  capped at the base tolerance:
  `yieldedTolerance(base, gap) = max(0, min(base, gap / 2))`, where `gap` is the
  distance from that edge to the **moving edge's grab origin** (the edited loop's
  stored facing edge). A far edge keeps the full radius (snap still lines loops
  up); a close facing edge shrinks its zone so a dead zone always survives in the
  gap to release into. Markers and beats keep the full radius — the "don't slam
  loops together" softening is loop-vs-loop only. Pure and unit-tested
  (`WaveformGesture.yieldedTolerance` + a per-candidate-tolerance
  `snap(_:to:)` overload).
- **2 — Long-press mid-drag suspends snap for that drag.** Holding the handle
  still for `freeDragHoldDuration` (~400 ms) while dragging turns snapping **off**
  for the rest of that gesture, confirmed with a medium haptic — full free
  placement anywhere, not just tight gaps. Feasible with no gesture conflict
  because the hold-to-select timer (`startHold`) is inert during a range edit
  (`canBeginSelection` is false once a span is live). Stillness is detected the
  cheap way: a `DragGesture.onChanged` only fires on movement, so a timer armed on
  each meaningful move simply fires when the finger stops. Release reads the
  suspended flag and skips the catch.

The yield alone resolves the reported "loops slam together"; the long-press is the
deliberate-precision escape on top — the best-of-both the review asked for.

## Consequences

- Tight gaps between loops become placeable, and a long-press gives arbitrary free
  placement near *any* landmark — while snap stays strong everywhere it earns its
  keep (roomy edits, markers, beats, seek/scrub).
- `WaveformView.onMoveABHandleEnded` widens to `(Handle, _ snapping: Bool)` so the
  gesture can tell the model a drag ended in free mode; a new `onSnapSuspended`
  closure fires the "entered free mode" haptic. `endABHandle` gains a
  `snapping: Bool = true` parameter and, when editing a saved loop, routes through
  the new neighbour-aware `loopEdgeSnapTarget` instead of the flat `snapTarget`.
- Neighbour-yield applies only when **editing a saved loop** (`abEditingLoop != nil`),
  the reported scenario — it has a stable grab origin for the gap. A brand-new span's
  handle drag keeps prior snap behaviour (out of scope).
- Two new gesture constants (`freeDragHoldDuration`, `freeDragStillEpsilon`) and a
  little drag state (`snapSuspended`, a stillness timer). Feel constants are tuned
  on device.

## Out of scope (follow-ups)

- **A visible "snap off" indicator** while free mode is active (beyond the entry
  haptic) — deferred; revisit if the mode is easy to lose track of on device.
- **Neighbour-yield for a brand-new span's drag** — the create path has no stored
  edited loop; left as-is until there's a reported need.
- **Live-drag snap** (catching as you drag, not only on release) — unchanged; this
  ADR only softens the release catch and adds the manual escape.

## Alternatives considered

- **Yield rule only, no escape.** Sufficient for the tight-gap complaint (and was
  the smaller slice), but the long-press adds arbitrary-precision placement the
  reviewer valued; chosen for the clearly better feel.
- **A visible Snap on/off toggle in the range-edit chrome** instead of the
  long-press. Discoverable and conflict-free, but a mode switch rather than a
  per-drag gesture; the long-press keeps hands on the waveform and matches the
  backlog's "drag-past-threshold or long-press" framing.
- **A flat reduced tolerance for all neighbour edges** (not gap-scaled). Simpler,
  but either too weak when loops are very close or needlessly weak when they're
  roomy; the half-gap scaling is the natural "meet in the middle" partition and is
  no harder to test.
- **Drop neighbour loop edges from the candidate set entirely.** Rejected: you
  *do* often want to butt two loops flush, and full-tolerance snap from a roomy
  approach still serves that; only the crowded case needs softening.
