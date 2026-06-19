# 0001 — Practice engine builds on local/iCloud files, not Apple Music

- **Status:** Accepted
- **Date:** 2026-06-15

## Context

The product brief named "a real waveform reading from Apple Music" as the first
and most valuable milestone, with Apple Music as the primary audio source for
waveform rendering, loops, and 0.25×–2.0× speed control.

Apple Music streaming content is DRM-protected. MusicKit plays it through the
system player and exposes **no raw PCM frames**. AVAudioEngine taps on
DRM-protected content are blocked. Waveform generation and time-stretch both
require raw samples, so they are not possible on Apple Music streaming audio
through the standard APIs.

The DJ apps that do show Apple Music waveforms and time-stretch tracks (djay,
Serato, rekordbox) use a **special, selectively-granted Apple entitlement**.
It is not part of the standard MusicKit programme and is unlikely to be granted
quickly to a new indie app, if at all.

## Decision

The practice engine (waveform, loops, speed control) is built on **DRM-free
local and iCloud Drive files**, imported via the Files picker and held by
security-scoped bookmarks. Apple Music is a **browse/metadata layer** only:
discovery, song info, and (later) playlist sync — not an audio-processing source.

The first build milestone is reordered accordingly: local-file playback → speed
control → waveform → scrubbing → loop capture, **not** Apple-Music waveform.

## Consequences

- The data model keys off a source-agnostic `SongRef`, not `MusicItemID`, so
  local files (which have no `MusicItemID`) can own loops and markers.
- A short technical spike on the real developer account should confirm exactly
  what audio access is available before heavy engine work.
- Pursuing the special Apple entitlement remains a later option; if granted, an
  Apple-Music engine source can be added behind the same `SongRef` abstraction
  without reworking the data model.

## Alternatives considered

- **Apply for the DJ/time-stretch entitlement up front** — rejected as the
  primary path: slow, gated, uncertain, and it blocks the entire core while
  waiting.
- **Ship without speed/waveform on Apple Music, deep-link to the Music app** —
  retained as the Apple Music behaviour (browse + play externally), but the
  practice engine still needs DRM-free audio, which is what this ADR provides.

## Addendum (2026-06-19) — reduced-feature Apple Music path via the system player

The original framing ("Apple Music is browse/metadata only") is too absolute.
It correctly rules out Apple Music as a **PCM source** (no raw samples →
no waveform, no independent pitch shift, no own time-stretch), but it overlooks
a second, non-PCM capability that competitors such as Audipo actually use.

**Playback control on DRM tracks works.** `MPMusicPlayerController` (the
application/system music player) plays Apple Music library items inside Apple's
protected pipeline and exposes:

- `currentPlaybackRate` — speed/tempo change
- `currentPlaybackTime` + seeking — A/B points and looping

Apple decodes and time-stretches; the app never sees samples. This enables a
**reduced-feature practice mode** (play, loop, slow down) on Apple Music library
tracks, distinct from the full local-file engine.

**The display boundary, not a usability cliff.** With no PCM there is no real
waveform, but the timeline degrades gracefully to a **beat/bar grid** built from
`duration` + `bpm` (already in the model — see ADR 0004 / 0012): beat ticks,
bar accents, section markers, and loop-region shading, all PCM-free. Same gesture
surface as the waveform; only the backdrop fidelity differs. Live output metering
of the system player is **not** available, so a rolling/live waveform is out too.

**Status: known but deferred.** Not adopted now, for two reasons:

1. `MPMusicPlayerController.currentPlaybackRate` is historically fragile across
   OS versions (broke in iOS 15.4, fixed 15.5; reported broken again in iOS 26.0,
   forcing rate to 0/1.0 with noisy playback). Tempo accuracy and stability are
   not guaranteed.
2. It fragments the feature matrix (full vs reduced engine) before the local-file
   core has shipped.

It fits the existing architecture without rework: an Apple-Music engine source
sits behind the same `SongRef` abstraction, and the timeline already needs a
no-waveform rendering path. Revisit once the local-file engine is solid and the
iOS 26 `currentPlaybackRate` regression is confirmed fixed.

Sources: [MPMediaItem.assetURL is nil for Apple Music](https://developer.apple.com/forums/thread/7791),
[currentPlaybackRate broken in iOS 26.0](https://developer.apple.com/forums/thread/801861).