# 0042 — Selective landscape: practice screen only

- **Status:** Accepted — built (branch `pocket-056`)
- **Date:** 2026-06-25

## Context

Pocket is portrait-only today, locked app-wide in
`Pocket/Resources/Info.plist` (`UISupportedInterfaceOrientations` lists
`UIInterfaceOrientationPortrait` and nothing else). No prior ADR records this —
it's an implicit default, not a deliberate choice.

Landscape is not a feature; it's a layout constraint every screen has to
satisfy. Deciding it late is expensive: build the rest of V1 portrait-only and
bolt landscape on at the end, and every screen's layout assumptions get
revisited under a retrofit tax. But building *full* landscape into screens that
are still churning wastes work too — the transport left column just changed
shape (ADR 0041 retired Fine mode, leaving A/B · Marker), so the practice
screen is only now settling.

The right resolution is to **decide the policy now and implement late**, on the
one screen that earns it.

Only one screen benefits from landscape: the **waveform/practice view**.

- More horizontal pixels = more waveform resolution = more precise A/B span
  dragging and loop-edge handle placement (ADR 0041's core gesture surface).
- Musicians prop a phone on a stand in landscape while playing — the natural
  posture for *this* screen specifically.

Library, journal, song-details, and the creation onboarding flow gain nothing
from extra width. Supporting rotation there is pure cost (every layout doubled,
every screen re-tested) for no payoff.

## Decision

**Selective landscape.** The practice/waveform screen supports landscape; every
other screen stays portrait-locked for V1.

Rejected alternatives:

- **Universal landscape** — most consistent, but a real retrofit tax across
  screens still in flux, for no benefit on the screens that don't need width.
  Heaviest V1 cost.
- **Practice + library** — library gains little from width; the marginal
  consistency isn't worth doubling another screen's layouts.

## Implementation notes (as built)

- Pure SwiftUI (iOS 17) has no first-class per-view orientation lock, so the gate
  is a small app-delegate + app-state mechanism (`OrientationGate.swift`):
  `Info.plist` lists portrait + landscape left/right app-wide; `AppDelegate`
  answers `supportedInterfaceOrientationsFor` from a static mask defaulting to
  `.portrait`; a `.landscapeEnabled()` view modifier widens the mask on appear and
  reverts to `.portrait` on disappear, calling `requestGeometryUpdate` so a revert
  actively rotates the device back. Only `WaveformPracticeView` applies the
  modifier — every other screen stays portrait because the default mask is never
  widened for them.
- The layout branches on `verticalSizeClass == .compact` (landscape on iPhone).
  The cockpit (a header slot, speed bar, status line, waveform, ruler, minimap,
  transport) and the loops/markers reference list were extracted into shared
  `PracticeCockpit` / `PracticeReference` views (`WaveformPracticeLayout.swift`)
  so both orientations compose the same pieces. `PracticeCockpit` is generic over
  its header and takes a `landscape` flag:
  - **Portrait:** header = `SongStrip`; cockpit stacked over the reference list
    (unchanged).
  - **Landscape:** header = a compact back · title · ☰ bar (the system nav bar is
    hidden via `.toolbar(.hidden, for: .navigationBar)`); the cockpit owns the
    **full width**, and the reference list is a **slide-in drawer** from the right
    edge (`drawerOpen` state, scrim + tap-to-dismiss), closed by default so the
    waveform keeps the width. A first attempt used a fixed ~30% side rail but it
    ate too much width and cramped the panels — the drawer replaced it.
  - **Compact tuning (landscape):** cockpit `spacing` tightens to 8; the speed bar
    drops its preset-pill row (`SpeedBar(compact:)`); the transport shrinks its
    glyphs + bar height (`TransportBar(compact:)`); the waveform **flexes** to fill
    the leftover height (`WaveformView(fillsHeight:)`) so the transport always pins
    to the bottom instead of being pushed off-screen.
- **Song-info panel removed.** The build took the opportunity to drop the
  collapsible `SongInfoPanel` from the practice scroll area entirely (both
  orientations) — its key / mastery / collections are a strict subset of the
  song-details sheet (hold the title), so nothing became unreachable. This closes
  the "consolidate `SongInfoPanel` vs `SongDetailsSheet`" UI-polish backlog note.

## Sequencing

Built after the near-term loop-tags cleanup, as planned.
