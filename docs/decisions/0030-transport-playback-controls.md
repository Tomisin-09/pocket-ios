# 0030 — Transport playback controls & active-loop affordance

**Status:** Accepted
**Date:** 2026-06-21
**Supersedes / amends:** builds on ADR 0027 (transport rework), ADR 0023 (loop
identity colour), ADR 0029 (session-state lifecycle).

## Context

The transport bar had a single play/pause button and a text-labelled action row
(Loop / Mark / Fine). Two gaps:

1. **No "a loop is active" signal beyond the chip.** When a loop was armed, the bar
   showed its name + range and an ✕ chip, but the cue was easy to miss — there was
   no strong, persistent indicator that playback was looping a region vs running the
   whole song.
2. **No playback transport.** You could only play/pause and seek on the waveform.
   There was no quick way to restart the current region, or skip between loops.

## Decision

Reorganise the transport bar into three zones (per the design sketch) and add a
rewind · pause · forward cluster.

### Layout

- **Left** — three identity controls, each a **glyph in a circle**, replacing the
  labelled action buttons: Loop (green `repeat`), Mark (pink triangle), Fine (blue
  calipers). Idle is the glyph in its colour on a faint fill; the active control's
  circle fills with its colour (Loop while a punch is armed, Fine in precise-edit).
  VoiceOver labels carry the names the captions used to. (Bare dots, then bare glyphs,
  were tried first — dots read as empty without their glyphs, and bare glyphs felt
  sparse and overflowed the bar height; the compact circle contains them and fits.)
  The header reserves a fixed height with both states at a matched primary font size so
  activating/deactivating a loop cross-fades without the transport row shifting.
- **Centre** — a header over the transport glyphs (background-free, no pill):
  - *Loop active:* the loop name + its time range.
  - *No loop:* the live playhead position.
- **Right** — only when a loop is active: a vertical strip in the loop's **identity
  colour** (ADR 0023, shared via `LoopColor`) carrying the ✕ **deactivator**. The
  strip's presence is the "a loop is armed" signal; it is absent on the full song.

### Playback mapping

Skip targets depend on whether a loop is active. Rewind carries restart + previous;
forward carries next; pause is play/pause. No dead taps (the original sketch left
single-tap forward and double-tap pause inert — rejected for reading as "broken"):

| Button  | Loop active                    | No loop active                         |
|---------|--------------------------------|----------------------------------------|
| Rewind  | 1× restart loop · 2× prev loop | 1× restart song · 2× prev song¹        |
| Pause   | play / pause                   | play / pause                           |
| Forward | 1× next loop                   | 1× next song¹                          |

¹ **Cross-song** (previous/next *song* in the library) is deferred to a follow-up
branch — the practice screen currently opens knowing only one song. Until then the
forward / previous affordances **dim** when no loop is active, rather than no-op
silently. Skips preserve play/pause state (a skip while paused stays paused).

Rewind disambiguates single vs double tap via stacked `onTapGesture(count:)`; the
neighbour lookup is the pure, unit-tested `TransportNav` over loops ordered by start.

### Swipe-back guard

A playhead scrub that starts near the screen's left edge competed with the iOS
interactive pop gesture, yanking the screen back to the library mid-adjust. The
waveform drag fires on touch-down (`minimumDistance: 0`), so the model brackets every
waveform touch (`isScrubbing`) and `SwipeBackGuard` disables the navigation
controller's `interactivePopGestureRecognizer` while a finger is down — cancelling any
edge-pan already tracking. Restored on release, so the back-swipe works normally
otherwise (scoped to scrubbing, not the whole screen).

## Consequences

- The transport bar is the place to restart / skip loops without touching the
  waveform; the active-loop colour strip makes the looping state unmistakable.
- Forward/previous are visibly inert with no loop until cross-song navigation lands.
- ADR 0025 scoped the **lock-screen** transport to play/pause only ("nothing to skip
  to"). That premise will change when cross-song navigation arrives; revisit 0025's
  skip-command scope then. This ADR covers the **in-app** transport only.
