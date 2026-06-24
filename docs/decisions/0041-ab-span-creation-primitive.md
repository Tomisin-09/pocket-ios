# 0041 — A/B span as the loop-creation primitive

- **Status:** Accepted
- **Date:** 2026-06-24

## Context

Today every way of making a loop funnels into the same place: a `CaptureDraft`
behind a forced commit gate. Punch a region in Tap mode (ADR 0003), hold-drag a
selection (ADR 0005), or drag the blue **Fine** handles — all three raise the
`EditToolbar` (▶ audition · "New loop" · ✗/✓) and **lock the transport** until you
either save (✓) or discard (✗). Loops are created instantly on ✓, auto-named, no
naming step (ADR 0019).

Two problems with that gate:

- **You can't live with a rough region.** A musician's natural move is "set a
  rough A–B, loop it, feel it, nudge the ends while it plays." The commit gate
  forbids that — you must decide *now*, and the transport is frozen while you do.
- **Range-editing an existing loop is three hops.** Row → edit sheet → "Adjust
  range" → Fine mode → drag → ✓. Refining bounds should be direct.

Musicians already have a mental model for this: the **A-B repeat** button on every
practice player — set A, set B, it loops the span, you adjust by feel. Pocket's
"Loop" punch is mechanically that gesture, but bolted to a draft-and-confirm flow
instead of a living span.

This is the priority of the V1 creation experience (backlog, "Loop experience"):
make A/B *the* creation primitive, dissolve the three-hop range edit, and unify
markers / A-B / loops into one story.

## Decision

The ephemeral **A/B span** becomes the single working region and the front door to
creating loops. The commit-gate draft is replaced by a living span.

1. **Set by playing along (primary).** While the song plays, the Loop control
   drops **A** at the playhead on the first tap and **B** on the second; the engine
   then loops **A↔B** immediately. No ✗/✓. Eyes-off, by feel — mechanically the old
   punch, reframed to produce a span rather than a draft.

2. **The span lives — no gate.** Once A↔B is set it just loops, **ephemerally**:
   not persisted, not in the loops list, no auto-name. The transport stays **live**
   (you set B by ear while playing, and keep playing after). You can audition,
   rehearse, and adjust the span indefinitely.

3. **Adjust in place, fine-style, no mode hop.** A and B render as draggable
   handles on the waveform; drag either edge to refine, snapping to nearby markers
   and saved-loop edges on release (ADR 0021). This absorbs the separate **Fine**
   *mode* — refinement is always available on the live span, not a place you go.

4. **Promote with "Save as loop."** A persistent action turns the span into a
   saved `Loop`, auto-named and activated, preserving ADR 0019's no-naming-step
   rule. **✕** clears the span and plays on through the song.

5. **Range-edit = lift into A/B.** "Adjust range" on a saved loop loads its bounds
   into the A/B span; dragging A/B then **Save** writes back to that same loop
   instead of creating a new one. Three hops collapse to drag-and-save.

6. **Unified mental model.** A single point is a **marker**; an **A↔B span** is the
   ephemeral rehearsal/creation region; a **saved span** is a **loop**. The instant
   marker drop (ADR 0037) stays as-is — A/B is the *span* surface. No forced
   marker→loop bridge (backlog #1 stays parked); the unification is the mental model
   and the shared set gesture, not a new conversion action.

7. **Ephemeral, wiped on exit.** The span is transient session state (ADR 0029):
   cleared when you leave the screen, never persisted. A sitting starts fresh.

Spatial **hold-drag-select** (ADR 0005) is kept as a secondary way to paint the
same A/B span directly, for eyes-on precise placement. It stays **playhead-anchored**
(A pins to the playhead, the drag sets B) — i.e. the spatial equivalent of the
play-along set, producing the same living, adjustable span rather than a draft.

## Alternatives considered

- **Add A/B alongside the existing commit-gate flow** (keep punch/Fine/✗-✓ intact,
  bolt on a separate A/B feature). Rejected: two parallel creation paradigms, and it
  delivers neither the three-hop dissolution nor the unified story — the whole point.
- **Keep the ✗/✓ commit gate.** Rejected: the gate is precisely what blocks "live
  with a rough loop and refine it by feel," which is the musician-natural flow.
- **Spatial drag as the primary set gesture.** Rejected *as primary*: play-along is
  more intuitive and works eyes-off; spatial drag is kept as the secondary path.
- **Persist the last A/B span per song.** Rejected — consistent with ADR 0029, a
  practice sitting starts fresh; a stale span is more confusing than helpful.

## Consequences

- **User-facing name: "Loop".** The control and the feature are surfaced as **Loop**
  (the repeat-arrows glyph) — the thing you create is a loop, and it sits right above the
  Loops list. "A/B span" is the **internal** model name only (`ABSpan`, `abSpan`). The two
  endpoint handles keep the compact **A / B** labels as start/end markers. (Earlier builds
  labelled the control "A|B"; reverted — the borrowed hardware jargon needed explaining.)
- The `EditToolbar` ✗/✓ strip is replaced by an **A/B strip**: ▶ audition · a label
  (span times, or "Set B…" while A is placed) · **Save as loop** · **✕**. Creation
  no longer greys/locks the transport; only downbeat placement still locks (ADR
  0024, which keeps its own `DownbeatBar`).
- `CaptureDraft` evolves into the A/B span model (start/end + optional `editingLoop`
  for the range-edit write-back); `pendingStart` becomes the "A placed, awaiting B"
  forming state.
- The separate **Fine** mode/pill is retired; `InteractionMode` reduces toward
  navigate-only, since handles are always live on a span. The transport's left
  column becomes **A/B** (set) + **Marker**.
- A new **pure state machine** drives the A/B tap cycle (idle → A placed → A↔B set →
  …) and span ordering; unit-tested per AGENTS.md, kept free of SwiftUI/AVFoundation.
- Automator (ramp), journal, last-practiced-speed and the loop colour identity all
  continue to key off the **saved** loop — the ephemeral span carries none of them
  until "Save as loop" promotes it.
- **Seeking inside an active loop repositions within it** rather than restarting at the
  loop start. Tapping inside a living/playing loop is now a common gesture, so the engine
  schedules the loop buffer's tail `[offset, seam)` once and then loops the whole region —
  seamless because the tail meets frame 0 at the already-crossfaded seam. (Previously
  `PracticeAudioEngine.seek` always restarted a loop at its start; that limitation, fine
  when seeks-into-loops were rare, became a visible bug with this flow.)
- Delivered in slices: (1) pure A/B state machine + tests; (2) play-along set +
  living span + ✕, replacing the punch draft; (3) Save-as-loop promotion; (4)
  in-place A/B handle adjustment, retiring Fine mode; (5) range-edit lift-into-A/B;
  (6) chrome/copy cleanup + secondary hold-drag wiring.
