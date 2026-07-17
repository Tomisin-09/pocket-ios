# 0069 — Practice-take recording (mic-only "audio journal")

- **Status:** Accepted (2026-07-16)
- **Date:** 2026-07-07 (proposed), 2026-07-16 (accepted)

## Build (accepted 2026-07-16)

Sliced post-v1 on its own branch, never riding the paused v1.0 submission:

- **Slice 0 (foundations, this branch `pocket-148`)** — mic permission string +
  `AVAudioApplication.requestRecordPermission` flow; a record-capable session
  config in `AudioPlumbing` (§3); and the **pure route classifier** that drives
  the headphone-clean vs speaker-bleed cue (§2), unit-tested. No model, no
  capture, no UI yet. The session options are the copyright/quality guardrails
  baked in at the substrate: `.playAndRecord` + `.defaultToSpeaker` +
  `.allowBluetoothA2DP` **without** `.allowBluetooth` — output stays high-quality
  A2DP and input falls back to the built-in mic (avoids the Bluetooth
  HFP-collapse; the guitar is in the room, not the earbuds).
- **Slice 1 (model + capture + storage, `pocket-148`)** — `Recording` SwiftData
  model (§5): app-authored AAC file addressed by a relative `fileName`, with a
  **polymorphic owner** (`loop`/`exercise`/`song`, the JournalEntry/ADR-0058
  pattern; `ownerKind` derived, no stored enum) that is **cascade-owned** by its
  owner via an inverse `recordings` array on `Loop`/`Exercise`/`Song`, mirroring
  the sibling `journal` pillar — deleting an owner deletes the take's row, and the
  now-unreferenced file is reaped by the orphan sweep. (A bare unidirectional
  relationship was found to leave the link *dangling* at a deleted model rather
  than clearing — the inverse is required for any delete rule to fire.)
  `RecordingStore` owns the container directory + delete/size and the pure
  orphan-sweep retention logic. `TakeRecorder` captures mic-only to AAC via
  `AVAudioRecorder` (not tapping the playback engine — engines stay unchanged per
  §3). Owner-resolution + orphan logic unit-tested; real capture is device-only.
- **Slice 2 (loop-trainer UI, `pocket-148`)** — recording is a **pre-start arm
  toggle** beside Start training (off by default), not a mid-run button (device
  feedback 2026-07-17). Arming requests mic permission on the setup screen and
  samples the route so the headphone-vs-speaker nudge shows *before* the run; the
  take begins when the run commences (after the count-in) and stops when the run
  does. This also **fixed an audible glitch**: configuring `.playAndRecord` before
  playback starts, rather than flipping the category mid-stream, removes the
  interruption. Same slice: standalone **loop training now gets the visual
  count-in** (respecting the Count-in setting) that exercises already had.
- **Slice 3** — relisten/playback + journal integration.

## Context

The product should let a user **record their practice** — capture their playing,
then relisten and review it — an audio counterpart to the notes/journal pillar.
Full sizing lives in `docs/research/feasibility-practice-recording.md`; this ADR
records the decisions that close off alternatives.

Pocket is deliberately **local-first** and its engine is built on DRM-free local
files because Apple Music streaming audio cannot be tapped (ADR 0001). ADR 0064
then made audio the one thing that never rides a sharing rail — exercises are the
shareable unit; loops and audio are not. A recording feature has to be designed
inside those two walls, not against them.

Two framings of the feature pull in opposite directions:

- **"Record me"** — mic capture of the user's own playing. The user owns their
  performance; no third-party rights attach.
- **"Record my session with the track"** — a mixdown of the mic *and* the app's
  loop playback in one file. This is what users often picture, but it bakes a copy
  of the copyrighted recording into a user file — the exact wall ADR 0001/0064
  exist to keep the product clear of.

A separate question is **isolation**: when recording over a playing loop, can we
capture just the guitar? With mic-only capture the loop couples into the
recording **acoustically, not digitally** — if we record the input node and never
tap the mixer, the loop's samples never enter the file; the only path is speaker →
air → mic. So isolation is a function of the output route, not a DSP feature we
must build (detail and the AEC dead-end are in the research doc).

## Decision

1. **Ship mic-only "practice takes"; do not build the mixdown.** A take captures
   the microphone (the user's playing) only. The app never renders its own loop /
   song playback into a recording file. This keeps every recording free of
   third-party rights and consistent with ADR 0001/0064. The mixdown framing is
   closed here until a rights framework reopens it (same posture 0064 took on loop
   sharing).

2. **Isolation over a loop is solved by route, not by cancellation.** Use
   `AVAudioSession.currentRoute.outputs` to detect the output path and set
   expectations:
   - Headphones / Bluetooth → a **clean take** (the loop is not in the room);
     record with confidence.
   - Built-in speaker → surface a nudge that the backing track in the room will be
     captured, and recommend headphones for an isolated take.

   We explicitly **do not** ship acoustic echo cancellation for this: the built-in
   voice-processing AEC is speech-tuned and degrades instrument tone, and DIY
   cancellation is a research project with imperfect results. Messaging beats a
   fight we can't win at music quality.

3. **Recording uses its own session config, not a global flip.** Recording needs
   `.playAndRecord`; playback/metronome keep `.playback`. Add a separate
   record-capable configuration (with `.defaultToSpeaker` as appropriate) applied
   only while a take is armed, so the shared `AudioPlumbing` path and the
   non-recording behaviour of both engines are unchanged.

4. **Permission and privacy land in the same PR as the feature.** Add a specific
   `NSMicrophoneUsageDescription` (never a vague one — rejection risk) and use the
   iOS 17+ `AVAudioApplication.requestRecordPermission` flow. Update
   `PrivacyInfo.xcprivacy` if a required-reason API is touched. No mic key exists
   or is added before this feature ships (per the standing dev guide).

5. **Recordings are app-authored files with their own model.** Unlike songs
   (security-scoped bookmarks to files in place), takes are files the app owns in
   its container, encoded AAC (not raw PCM — storage). Model them as a SwiftData
   `Recording` entity carrying created-at, duration, and a link to the
   session/song/exercise the take was made against, plus a retention/cleanup story.

6. **Recordings stay local; they never enter the social rail.** Consistent with
   ADR 0064, a take is never shared and never transits the social backend. Whether
   takes ride *personal* CloudKit sync is deferred (audio is heavy; not required
   for the feature to be useful) and is not decided here.

## Consequences

- **The clean core ships without touching the hardest problem** (audio rights):
  mic-only takes, headphone-clean isolation for free, a speaker nudge for honesty.
- **New submission surface** — a mic permission string + privacy manifest review +
  app-container audio files — all inside the `/ready-to-ship` gate, handled in the
  feature PR.
- **A "record with the track" request later is a new ADR against §1**, not a
  drift — same discipline ADR 0001/0064 hold for streaming and loop sharing.
- **Storage grows with use** (AAC keeps it modest); retention UX (delete takes,
  maybe a per-take size hint) is part of the first slice, not an afterthought.
- **Isolation is a UX cue, not an engine feature** — no AEC/DSP burden, and the
  "headphones recommended" framing reinforces existing practice guidance.

## Alternatives considered

- **Mixdown of mic + app playback** — rejected as the default (decision 1): bakes
  copyrighted audio into user files, contradicting ADR 0001/0064. Available in
  principle for local files only, gated behind a future rights decision.
- **Acoustic echo cancellation to isolate on speaker** — rejected (decision 2):
  built-in AEC is voice-tuned and wrecks instrument tone; custom cancellation is
  research-grade and imperfect.
- **Tapping the mixer / output node** — rejected: capturing app output is either
  pointless (song only) or the mixdown case above.
