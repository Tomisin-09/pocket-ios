# 0115 — Guitar tuner: live mic pitch detection, free in the Toolkit

- **Status:** Accepted
- **Date:** 2026-07-24 (`pocket-193-guitar-tuner`)
- **Builds on:** ADR 0096 (Toolkit hub — the free, deterministic *reference* destination). ADR 0069 (mic-only recording — established `MicPermission`, `NSMicrophoneUsageDescription`, and the record-capable session). ADR 0097 (synth-first audio — `ToneEngine` for reference tones). ADR 0112 (freemium; free = quality-of-life/reference, Pro = author/curate). ADR 0070 (the app never grades the player). ADR 0001 (audio source: local/DRM-free; Apple Music is never tapped).

## Context

A tuner is table-stakes for a guitar practice app and is the single most-requested missing utility. Every session starts with tuning; today a Pocket user has to leave the app to do it. The Toolkit (ADR 0096) is exactly the right home: a free, deterministic *reference* destination sitting beside My Chords and the Glossary.

Nothing about a tuner conflicts with the project's audio posture. The DRM constraint (ADR 0001) is about *Apple Music streaming* — raw microphone input has always been available and is already exercised by the recording feature (ADR 0069), which shipped `MicPermission`, the `NSMicrophoneUsageDescription` string, and a record-capable `AVAudioSession`. So the permission, the Info.plist string, and the session plumbing all exist.

Two things are genuinely new:

1. **A live input *tap*.** The recorder (ADR 0069, `TakeRecorder`) is built on `AVAudioRecorder` writing to a file — it deliberately never sees live PCM (that decoupling is core to the route-not-DSP recording story). A tuner needs the opposite: `installTap(onBus:)` on `AVAudioEngine.inputNode` to pull live sample buffers continuously. This is the first live mic *tap* in the app.

2. **Pitch estimation.** Turning a buffer of samples into "you're 8 cents flat of A2" — fundamental-frequency detection plus a frequency→note mapping.

The one real design fork is **how pitch is detected**, and secondarily **what the mic session does to any live practice audio**.

### Detection approach

- **Time-domain autocorrelation (chosen).** Correlate the buffer against a lagged copy of itself; the first strong non-zero-lag peak is the period, and its reciprocal is the fundamental. Robust on a single monophonic source with a strong fundamental — exactly a plucked guitar string (~82 Hz low E to ~330 Hz high E open, up to ~1 kHz fretted). Pure `Foundation` math, no third-party dependency, no `Accelerate` requirement, and **unit-testable** against synthesized sine/harmonic inputs.
- **FFT / spectral peak (rejected for v1).** More machinery (windowing, bin interpolation for sub-Hz accuracy at low frequencies where guitar lives), pulls in `Accelerate`, and buys nothing for a monophonic tuner. The low strings are precisely where FFT bin resolution is worst and autocorrelation is strongest.

## Decision

**A live-input guitar tuner in the Toolkit, autocorrelation-based, pure detection core, free.**

1. **A pure `PitchDetector`.** `Foundation`-only. Takes `[Float]` samples + sample rate, returns an optional detected frequency (`nil` when the signal is too quiet or too noisy to trust — a confidence/clarity floor, so the needle holds rather than jitters on silence). No AVFoundation import, so it's unit-tested: fed synthesized tones at known frequencies (including guitar open-string frequencies and detuned offsets) it must return the fundamental within tolerance, reject noise/silence, and behave deterministically.

2. **A pure `TunerReading` mapping.** Frequency → nearest note. Reuses the app's existing note vocabulary: MIDI note numbers as the currency (as `ToneEngine`/`ChordVoicing` do) and **`GuitarScale.noteName(forPitchClass:)` for spelling**, so the tuner names notes identically to the fretboard, chord namer, and scale surfaces. Emits `{ midiNote, noteName, cents }` where `cents ∈ [-50, +50]` is the deviation from equal-tempered A440. "In tune" is `|cents| ≤ 5`. Pure and unit-tested (Hz→note→cents round-trips, boundary at the ±50-cent midpoint between adjacent notes).

3. **Guided-by-tuning is the default; chromatic is a toggle.** A first draft of this ADR chose "chromatic only, no mode picker" because chromatic *detection* technically covers every tuning. That was wrong on the product: for Drop C or Open G a player often doesn't know the target notes, so naming the pitch isn't enough. So the tuner has two modes:
   - **Guided (default).** A selected tuning gives six target notes; the tuner matches the detected pitch to the *nearest target in that tuning*, highlights the string it heard, and shows the direction to reach it ("6th string · tune ↓ to D"). Beginner-legible and unambiguous.
   - **Chromatic (toggle).** Names any of the twelve equal-tempered pitches with no target — for odd/experimental tunings and advanced use. This is the same `TunerReading` mapping from point 2 with the tuning constraint removed.

4. **An instrument axis (guitar + bass) over a curated tuning catalog — pure, not the full hardware-tuner list.** An `Instrument` (guitar, bass) each owns a *restrained* `[Tuning]`, where a `Tuning` is `{ name, [midiNote] }` (string count is just the array length — 6 for guitar, 4 for bass). The curated sets:
   - **Guitar:** Standard `EADGBE`, Drop D, Half-step-down, Full-step-down, Open G, Open D, Open E, DADGAD, Drop C (~9, not Fender's 15+).
   - **Bass:** Standard `EADG` (one octave below the guitar's low four), Drop D, Half-step-down. Bass sits an octave lower, so the detector's usable floor drops to ~31 Hz (low E1) — well inside autocorrelation's strength and the reason it beat FFT (Context): FFT bin resolution is worst exactly here.

   All pure, `Foundation`-only, unit-tested (each tuning's note set + spelling via `GuitarScale.noteName`, and the low-B/low-E boundaries). **Deferred, not designed-out:** *ukulele* (a re-entrant `GCEA` set — non-monotonic string order needs a small UI accommodation) and *custom* (user-defined) tunings both extend this same `Instrument` + `[midiNote]` model cleanly later — see Consequences.

5. **Reference-pitch calibration and a success chime — both free.** `a4Frequency` (already a parameter of the pure core) is exposed as an A432–A446 stepper defaulting to 440; unlike Fender, it is **not** gated behind a paid tier (our Pro line is author-vs-run, ADR 0112, not reference tweaks). A short **success chime** sounds when a string settles in tune (guided mode), with a toggle to silence it. The chime rewards hitting an *objective* pitch target — it is not performance feedback and does not violate ADR 0070.

6. **A `TunerEngine` owns the live tap.** `@MainActor @Observable`, in `Core/Audio`. It owns its **own** small `AVAudioEngine`, installs a tap on `inputNode`, feeds buffers to `PitchDetector` off the main thread, and publishes the latest `TunerReading?` for the UI (smoothed lightly so the needle settles). Like `MetronomeSoundPreviewPlayer` (ADR 0114) it is self-contained and does **not** share nodes with `PracticeAudioEngine` — opening the tuner doesn't disturb, and isn't disturbed by, a live loop/song. It configures a record-capable session on start and tears the tap down on stop / disappear.

7. **Permission reuses `MicPermission`.** Same iOS 17 `AVAudioApplication` flow as recording, same `NSMicrophoneUsageDescription` string — no new Info.plist entry, no new review surface. If denied, the tuner shows a "enable mic in Settings" state rather than a dead meter (dead audio must say why, per `Core/Audio` convention).

8. **A `TunerView` in the Toolkit, with a `TuneSettingsSheet`.** A new **Tuner** section row on the Toolkit landing (beside My Chords / Glossary), pushing onto the ambient home `NavigationStack`. The screen shows the detected note large, a cents needle/meter (flat ← centre → sharp) with an "in tune" state, and the target-string context. A gear opens a **Tune Settings** sheet (Pocket-native, indigo — not a system form) carrying: instrument (Guitar / Bass), mode (Guided / Chromatic), the tuning picker, reference pitch, and the success-sound toggle. Switching instrument resets the tuning to that instrument's Standard. A ▶ sounds the nearest/target note via `ToneEngine` as an ear reference (free reuse). No history, no scoring, no pass/fail — it reports pitch, it does not grade playing (ADR 0070).

9. **Free.** A tuner is a reference utility — the quality-of-life side of the ADR 0112 line, not the author-vs-run Pro lever — so tunings, calibration, and the chime are all free with **no `isPro` gate**. The one seam where a future Pro gate *could* legitimately sit is **custom (user-authored) tunings**, since authoring is what ADR 0112 reserves for Pro; that's deferred, so the question doesn't arise for v1.

## Consequences

- **First live input tap.** `TunerEngine` introduces `installTap` on `inputNode`. It must stop the tap and deactivate its session on view disappear and on app background, so it never holds the mic (or the record session) open behind a user's back — a live-mic indicator staying lit would (rightly) alarm users. Recording (`TakeRecorder`) and the tuner never run their sessions simultaneously by construction (different screens); if that ever changes, session arbitration is revisited then.
- **Session interplay.** The tuner arms a record-capable session on entry and restores playback on exit, mirroring the recording feature's session handling. Because it owns its own engine, it doesn't couple to `PracticeAudioEngine`.
- **New pure modules** (`PitchDetector`, `TunerReading`, `GuitarTuning`) under `Core/Audio` (or `Core/Theory` for the note mapping/tunings), all unit-tested per AGENTS.md — this is exactly the "pure, UI-free logic that breaks silently" the repo requires tests for.
- **New settings.** Instrument, mode, selected tuning, reference pitch, and success-sound-enabled persist via `@AppStorage` on `AppSettings.Key` (mirroring ADR 0114's `clickTimbre`), each with a `resolved…` fallback so a missing key lands on the safe default (Guitar · Guided · Standard · A440 · chime on). Tuning is stored per-instrument (or reset to Standard on instrument change) so a bass tuning never leaks onto guitar. No migration.
- **First live input tap.** (See above.) The mode/tuning work is all downstream of one live signal; it doesn't add audio-graph surface.
- **Build slices:** (1) pure `PitchDetector` + `TunerReading` + `GuitarTuning` with tests; (2) `TunerEngine` live-tap wiring; (3) Toolkit row + `TunerView`; (4) `TuneSettingsSheet` (mode / tuning / reference pitch / chime) + guided-mode targeting. Device verification required (live mic + real strings can't be judged in the simulator or previews).
- **Docs to touch on build:** `CHANGELOG.md`, `PROJECT.md` (new screen + service), `docs/architecture.md` (new audio module + first input tap), `README.md` if the Toolkit inventory is listed.
- **Future, additive (all extend the same `Instrument` + `[midiNote]` model — no rework):** *ukulele* (re-entrant `GCEA` needs a small string-order UI accommodation); *custom* user-authored tunings (the possible Pro seam, per Decision 9); a per-string "step through the tuning" auto-advance; a polyphonic/strum check.
