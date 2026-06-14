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