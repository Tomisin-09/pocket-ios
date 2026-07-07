# Feasibility — practice-take recording (mic capture) (research, 2026-07-07)

Idea (2026-07-06): let the user **record their practice** — capture their playing
while they practise, then relisten and review it. An "audio journal" that sits
beside the notes/journal pillar.

This doc sizes it, names the one decision that shapes everything, and records the
isolation finding (recording over a loop). The decision itself is ADR 0069.

## The core split — what audio do you capture?

The satisfying-sounding version ("record my session with the backing track") and
the safe-to-ship version ("record *me*") are different features with different
rights tails.

| Capture | Feasible? | Catch |
|---|---|---|
| **Mic only** (the user's guitar + room) | ✅ Clean | With headphones you capture *only* the guitar. With speakers the loop bleeds into the mic acoustically (see isolation, below). |
| **Mic + app playback mixed down** (guitar *and* the loop, in one file) | ⚠️ Local files only | Bakes a copy of the copyrighted recording into a user file — exactly the DRM/rights wall ADR 0001 built the engine around, and the audio ADR 0064 keeps out of any sharing rail. Fine as a private on-device artifact; a landmine the moment it syncs or shares. |
| **App output tap only** (no mic) | ✅ Trivial | Pointless — it just re-records the song. |

**Recommendation: ship mic-only "practice takes".** It's the clean core, it fits
the notes/journal pillar, and it never touches the rights problem. The mixdown
version is explicitly *not* built (see ADR 0069 §Decision).

## Isolation — recording over a loop

Key insight: with mic-only capture the coupling between the app's loop and the
recording is **acoustic, not digital**. If we record the engine's **input node**
(the mic) and never tap the mixer, the loop's samples never enter the recording
signal path. The only way the loop reaches the file is by travelling through the
air from the speaker back into the mic. So isolation is entirely a function of
the output route:

- **Headphones / Bluetooth → isolation is free and perfect.** The loop plays into
  the headphones and never enters the room; the mic hears only the guitar. There
  is nothing to cancel — a clean take of just their playing, by construction. This
  is the ideal case and costs nothing.
- **Built-in speaker → genuine bleed, no practical music-quality fix.** The mic
  picks up guitar **+** loop and you'd need real source separation to split them:
  - *iOS built-in AEC* (`AVAudioInputNode.setVoiceProcessingEnabled(true)`) is the
    one mechanism that fits — it references the *known* playback signal (we are the
    ones playing the loop) and cancels it from the mic. **But it is voice-tuned**:
    it applies AGC and noise suppression optimised for speech and will mangle a
    recorded guitar (pumped levels, eaten pick transients and reverb tails). Right
    mechanism, wrong domain.
  - *DIY adaptive cancellation* (we hold the exact loop buffer, so subtract it) is
    a research-grade DSP project — estimate the room impulse response, track
    variable mic-vs-playback latency, cope with speaker non-linearity and a path
    that shifts as the phone moves. Imperfect results for large effort. Not a
    feature.

  So on speakers you accept the mixed capture — which also re-lands you in ADR
  0001/0064 rights territory, since the loop is now baked into the file.

**Resolution: detect the route, set expectations — don't fight the DSP.**
`AVAudioSession.currentRoute.outputs` tells us headphones/Bluetooth vs built-in
speaker, so the app can *know* which case it is in:

- Headphones detected → treat as a **clean take**; record with confidence.
- Speaker detected → a gentle nudge: "Use headphones for a clean recording of
  just your playing — otherwise the backing track in the room is captured too."

This turns an unsolvable separation problem into a one-line UX cue and keeps the
app honest instead of promising isolation it can't deliver. It also reinforces the
"headphones recommended" framing that already suits practice recording.

## What it touches in today's codebase

- **Audio session.** Both engines share `AudioPlumbing.configurePlaybackSession`
  → `.playback`. Recording needs `.playAndRecord`, which changes routing
  app-wide (output defaults to the earpiece unless `.defaultToSpeaker`; Bluetooth
  / ducking behaviour shifts; the orange mic indicator lights). Add a *separate*
  record-capable session config rather than flipping the shared plumbing globally,
  so the metronome/playback path is unaffected when not recording.
- **Permission.** There is deliberately **no `NSMicrophoneUsageDescription`**
  today (Info.plist comments on why). Recording adds the usage string + the
  iOS 17+ `AVAudioApplication.requestRecordPermission` flow (the `AVAudioSession`
  variant is deprecated). A vague usage string causes rejection; keep it specific.
- **Storage — a new model.** Songs are stored as **security-scoped bookmarks to
  files in place**; the app owns no audio. Recordings are the first app-authored
  audio: files in the container (Application Support), a new SwiftData `Recording`
  entity (link to the session/song/exercise, plus duration/date), AAC encoding
  (uncompressed piles up fast: ~10 MB/min WAV vs ~1 MB/min AAC), and a
  retention/cleanup story.
- **Background.** `UIBackgroundModes: audio` is already present — playback (and
  recording, with care) can continue with the screen off.
- **Simultaneous record + playback + metronome** on one `AVAudioEngine` is
  supported (`installTap` on `inputNode` while the player runs); the graph gets
  more complex and inherits input latency / monitoring concerns.

## Trade-offs / gotchas

- **The audit gate.** New permission + a privacy-manifest entry + app-container
  files all trip `/ready-to-ship` checkpoints. Manageable, but real submission
  surface — the manifest and usage string land in the same PR as the feature.
- **Sync (ADR 0064).** Audio stays local. Recordings do **not** ride the social
  rail; whether they sync personally via CloudKit is a later call (audio is heavy
  and 0064 keeps audio off the shared backend regardless).
- **UX honesty about bleed.** Without the route nudge, speaker recordings sound
  bad and users blame the app.

## Verdict

**Feasible, small-to-medium.** Mic-only takes are a few days of focused work; the
hard part is product/rights discipline (stay mic-only) and the session/permission
plumbing, not the recording tech. Isolation over a loop is *solved for free on
headphones* and *messaged, not fought, on speakers.* Proceed via ADR 0069.
