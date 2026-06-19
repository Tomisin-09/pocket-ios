# 0021 — Snap loop bounds & tap-seek to markers and loop edges

- **Status:** Accepted
- **Date:** 2026-06-19 (`pocket-023-snap-to-marker`)

## Context

The substrate slices are now in: the waveform reads musically (ADR 0017),
overlapping loops and markers are all drawn (ADR 0018), the zoomed window holds
still and resolves real detail (ADRs 0010, 0020), and you can long-press-drag a
region right on the surface (ADR 0005 round 5). You can *see* the structure —
markers and saved-loop edges — but placing a new boundary exactly on one still
relies on landing the finger pixel-perfect. The natural next step is to let a
released gesture **catch** the structure it lands near, the way a DAW snaps an
edit to a grid or a clip edge.

This is the last creation-gesture slice of the P1 waveform-UX roadmap. Beat-grid
/ downbeat snap is a deliberately deferred follow-up (it needs a downbeat phase
anchor, not just tempo) — prove plain snap first.

## Decision

- **Snap on *release*, not while dragging.** The live drag tracks the finger
  exactly (ADR 0005 kept `selectionBounds` un-widened for the same reason); the
  catch happens only when the gesture lifts. A mid-drag snap would make the
  region jump under the finger and fight precise placement.
- **The catch math is one pure function.**
  `WaveformGesture.snap(_ fraction:to candidates:tolerance:)` returns the nearest
  candidate within `tolerance`, or `nil` when nothing is close enough (so the
  caller keeps the raw fraction and skips the haptic). Unsorted/duplicate
  candidates are fine; a non-positive tolerance snaps only on an exact hit. Kept
  in the UI-free, unit-tested `WaveformGesture` like the rest of the gesture
  geometry.
- **Candidates = every marker fraction + every saved loop's start and end.** When
  a Fine handle is range-editing an existing loop, that loop is **excluded** from
  the candidates so a handle can't snap to its own (or its sibling) edge.
- **Tolerance is a song fraction scaled by the zoom span**
  (`WaveformGesture.snapTolerance · viewport span`), so the catch zone is a
  constant size on screen at any zoom — the same trick the canvas uses for the
  Fine-handle grab zone. It's tighter than the grab radius (0.03 vs 0.06):
  snapping should assist precise placement, not hijack it.
- **Three release points feed it**, all in `WaveformPracticeModel+Snap.swift`:
  - **Long-press-drag commit** (`endDragSelection`) — snaps *both* edges before
    `loopBounds`. The existing medium commit haptic is the feedback; no extra
    snap buzz.
  - **Fine-handle release** (`endMoveHandle`) — snaps the just-moved edge
    (tracked via `lastFineHandle`), excluding the loop being edited, then
    auditions; `movingHandle` keeps the min-width so a snap can't collapse the
    loop. A light haptic confirms the catch.
  - **Tap-seek release** (`seekSnapping`) — a dedicated handler wired to `onSeek`
    only, so the playhead catches a marker / loop edge on a tap. A light haptic
    confirms.
- **Continuous moves stay un-snapped.** `seekToFraction` (navigate scrub and the
  whole-song minimap) is untouched — snapping a continuous drag or the zoomed-out
  overview would feel jumpy and serve no placement purpose.

## Consequences

- New loop boundaries and the playhead line up cleanly with the markers and loop
  edges you can already see, so loops nest and chain without fiddling.
- The model gains `WaveformPracticeModel+Snap.swift` (helpers + `seekSnapping`)
  and a `lastFineHandle` field; the view rewires `onSeek → seekSnapping` and
  `onMoveHandleEnded → endMoveHandle` (was `previewCapture`, now called from
  inside `endMoveHandle`).
- The snap helpers are `@MainActor` model methods (they read live `loops` /
  `markers` / `viewport`); only the catch arithmetic is pure and unit-tested.

## Out of scope (follow-ups)

- **Beat-grid / downbeat snap** (roadmap item 7) — snap to bar/beat positions,
  needs a downbeat phase anchor on top of the existing tempo.
- A visible snap indicator (a tick or glow on the caught candidate) — the haptic
  is the only feedback for now.
- Snapping in the minimap overview.

## Alternatives considered

- **Snap continuously during the drag** — rejected: the region/handle would jump
  under the finger and undermine precise placement; release-snap keeps the live
  drag exact and only assists at the end.
- **A fixed pixel/seconds tolerance** — rejected: it would feel different at
  every zoom. Scaling a song fraction by the visible span (as the handle grab
  already does) keeps the catch zone constant on screen.
- **Include the edited loop's own edges as candidates** — rejected: a Fine handle
  would snap to itself or its sibling, freezing it; excluding the edited loop
  avoids that.
- **Fold snap into `seekToFraction`** — rejected: that handler is shared by the
  continuous scrub and the minimap, which must stay un-snapped. A separate
  `seekSnapping` wired only to the tap-seek release keeps the boundary clean.
