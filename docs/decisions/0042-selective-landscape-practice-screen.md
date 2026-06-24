# 0042 — Selective landscape: practice screen only

- **Status:** Accepted
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

## Implementation notes (for the build branch, not yet done)

- Pure SwiftUI (iOS 17) has no first-class per-view orientation lock. The
  established approach: list the allowed orientations app-wide in `Info.plist`
  (add landscape left/right), then **restrict per-screen** by driving
  `application(_:supportedInterfaceOrientationsFor:)` from app state (e.g. an
  observable that the practice screen sets on appear / clears on disappear), or
  via a small `UIViewControllerRepresentable` orientation gate. Do **not** widen
  `Info.plist` without the per-screen restriction in place, or every screen
  becomes rotatable.
- The practice screen's landscape layout is its own design pass: the waveform
  should claim the new width, and the transport row repositions — not a
  free-reflow of the portrait layout.

## Sequencing

V1 polish item, **not** before the near-term loop-tags cleanup (backlog). Pick
up as its own `pocket-0XX` branch once the practice screen has gone quiet — the
decision is recorded here so the build can start whenever that happens.
