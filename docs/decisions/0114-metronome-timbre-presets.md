# 0114 — Metronome timbre presets: synthesized, hybrid-ready, and free

- **Status:** Accepted
- **Date:** 2026-07-24 (`pocket-192-metronome-sound-presets`)
- **Builds on:** ADR 0043 (standalone metronome + the three click levels — accent / beat / subdivision). ADR 0026 (`ClickVoice` shared by the in-song click and the standalone tool). ADR 0050 (Settings V1 — `@AppStorage` on an `AppSettings.Key`). ADR 0112 (freemium; free = quality-of-life, Pro = author/curate). ADR 0070 (a preview is an audition, never a graded backing track).

## Context

The metronome has shipped since ADR 0043 with a single voice: a synthesized sine "tick." A late
pre-v2 polish request is to let players choose the click sound — click, wood block, rim, beep — and
**hear each one before selecting**, the way any hardware metronome or drum-machine offers voices.

The one real design fork was **how the alternate sounds are produced.** Today the click is fully
synthesized PCM: `ClickVoice` built three sine bursts (`makeClick`) differing only by frequency and
amplitude. A preset is therefore really "which set of three buffers `makeClick` produces."

Two ways to supply them:

- **Synthesized** — parameterize the existing PCM synthesis. Zero bundle assets, no sample-licensing
  diligence, no file-format handling, and it stays true to the project's synth-first audio identity
  (`ToneEngine`, ADR 0097). A synthesized snare won't sound *recorded*, but for a metronome the attack
  transient and character matter far more than realism.
- **Sample files** — bundle short royalty-free recordings. More authentic acoustic percussion, but adds
  assets, licensing diligence, format handling, and breaks the "generate, don't store" pattern the
  project keeps reaching for.

## Decision

**Synthesized presets, structured hybrid-ready, all free.**

1. **A pure `ClickTimbre` catalog.** `enum ClickTimbre { click, woodBlock, rim, beep }`, `String`-raw
   (so it drops straight into `@AppStorage`). Each case renders mono `[Float]` samples for a given
   `ClickLevel` via a small per-level recipe (frequency, amplitude, duration, exponential decay,
   waveform, and a noise-mix for the rim's transient attack). The synthesis is **pure** — `Foundation`
   only, no AVFoundation — so it's unit-tested (frame counts, amplitude bounds, determinism) and stays
   off the audio classes. Noise is a deterministic xorshift so a voice renders identically every time.

2. **The default `.click` is byte-for-byte the old sound.** Its recipe reproduces the exact
   `makeClick` formula (sine, 25 ms, `exp(-90·t)`, same per-level frequency/amplitude), so every
   existing install hears no change. A regression test pins this.

3. **Hybrid-ready by construction.** The abstraction is "a timbre supplies samples for a level." A
   future case can load a bundled recording instead of synthesizing **without touching `ClickVoice`**.
   No sample assets ship now; the seam is what this ADR buys.

4. **`ClickVoice` owns the buffers; the choice reaches it at playback start.** `ClickVoice.loadTimbre`
   rebuilds its three buffers (cheap — three ≤50 ms buffers) and is called by **both** hosting engines
   (`StandaloneMetronomeEngine.start`, `PracticeAudioEngine.armMetronome`) passing
   `AppSettings.clickTimbre`. Routing the choice through one point at start keeps the in-song click and
   the standalone tool in lockstep, and a Settings change takes effect on the next play with no
   cross-object observation.

5. **Audition at a fixed 90 BPM.** A dedicated `MetronomeSoundPreviewPlayer` owns its *own* tiny
   `AVAudioEngine` + `ClickVoice`, so an audition never disturbs a live session. It plays a
   **self-terminating** two bars (first beat accented, so you hear the accent→beat relationship) then
   auto-stops; switching presets or leaving Settings stops it. It's an audition — nothing is measured
   (ADR 0070).

6. **All timbres are free.** Sound choice is quality-of-life, not the author-vs-run lever ADR 0112
   draws the Pro line on. No `isPro` gate.

## Consequences

- New `AppSettings.Key.clickTimbre` (+ pure `resolvedClickTimbre` fallback to `.click`, mirroring
  `resolvedAppearance`). No migration — a missing key resolves to the unchanged default.
- `ClickLevel` moved from nested in `ClickVoice` to top-level (it now names the pure synthesis);
  `ClickVoice.ClickLevel` references updated. No behaviour change.
- A new **Metronome sound** section in Settings: one row per preset with an inline ▶ audition and a
  selected check. Split into `MetronomeSoundSection` to keep `SettingsView` under the length cap.
- If a future voice wants a real recorded sample, add a case that returns loaded samples — the rest of
  the pipeline is untouched.
