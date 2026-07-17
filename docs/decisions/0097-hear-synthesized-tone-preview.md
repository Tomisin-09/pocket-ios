# 0097 — *Hear*: a synthesized pitched-tone preview, shared across chords/scales/intervals

- **Status:** **Accepted (2026-07-17)** — resolves ADR 0096 **D4** (the deferred "Hear" sound-source
  decision). On-device spike done (`ChordTonePlayer` + `HearSpikeView`, throwaway); the player judged the
  built-in tone good enough as a pitch reference.
- **Date:** 2026-07-17
- **Resolves:** ADR 0096 D4 ("*Hear* is deferred to Slice 2 with its own ADR"). **Builds on:** ADR 0001
  (audio-source reality), ADR 0093 (chord-naming engine), ADR 0085/0091 (scale/mode catalog + CAGED
  boxes), ADR 0092 (AI layer sits *on top of* this free, deterministic floor).

## Decision

- **D4.1 — Synthesize; do not ship a sample library.** *Hear* is real-time synthesis via
  `AVAudioUnitSampler`, driven one MIDI note per sounded string/degree. No third-party sample content is
  embedded or downloaded.
- **D4.2 — v1 sound = the built-in sampler tone (zero assets).** On iOS an *unloaded*
  `AVAudioUnitSampler` renders a clean built-in tone (envelope + sine-ish), **not** a GM guitar — there is
  no accessible system GM bank on iOS (this corrected a macOS-shaped assumption during the spike). That
  clean tone is a good, honest **pitch reference** for a theory tool, ships tiny, and carries zero
  licensing. It is what v1 uses.
- **D4.3 — Guitar timbre is a documented upgrade path, not v1 scope.** If a more guitar-like tone is
  wanted later, bundle a **redistributable (CC0 / public-domain) SoundFont** (`.sf2`) and select a
  nylon-guitar program — same code path, swap the bank (~a few MB, optionally on-demand). Not decided for
  v1; explicitly available.
- **D4.4 — Chords sound as a *block* (v1).** All sounded notes speak together. A strummed stagger was
  prototyped and dropped: too subtle to justify at chord scale. (The stagger code is retained conceptually
  because it *is* the sequencer — see D4.6.)
- **D4.5 — One shared `ToneEngine` (Core/Audio), not per-feature audio.** The spike's chord-only player is
  promoted to a small shared service with two methods over the same `AVAudioUnitSampler` primitive:
  - `sound(notes:)` — a block chord.
  - `sequence(notes:, noteDuration:, gap:)` — a melodic line (scale run, arpeggio, interval, fretboard run).
- **D4.6 — The pure note-ordering already exists; only timing is new.** *Hear* reads MIDI arrays the
  models already expose, so no per-feature note-derivation is built:
  | Surface | Ordered MIDI source | Playback |
  |---|---|---|
  | Chords (My Chords, identifier, custom placer) | `ChordVoicing.midiNotes` | block |
  | Scale patterns / CAGED boxes | `ScaleRun.sequence` → `CAGEDShape.midi(_:)` | sequence (asc/desc) |
  | Arpeggios | a chord's own `midiNotes` | sequence (chord, one note at a time) |
  | Fretboard / picking runs | `FretboardDrill.notes` → `CAGEDShape.midi(_:)` | sequence |
  | Intervals / ear-training (future) | two MIDI notes | sequence or block |
  | Glossary "Hear" affordance | term → interval/chord notes | either |
  `CAGEDShape.midi(_:)` and `ChordVoicing.midiNotes` share the *same* `openMidi` table, so scale and chord
  audio agree by construction.

## Context

ADR 0096 shipped the Toolkit hub audio-free and deferred *Hear* to its own ADR (D4). The app had no
pitched-tone source: ADR 0001 established that practice audio is DRM-free **file** playback plus a
synthesized metronome click, and that Apple Music streaming audio cannot be tapped. *Hear* is a **new,
separate lightweight `AVAudioEngine` graph** — a pitch preview, not part of the file-playback pipeline —
so it does not touch or contradict ADR 0001.

Two sourcing ideas were considered and rejected before the spike (see Alternatives). The spike
(`ChordTonePlayer` + `HearSpikeView`, reached from a temporary Toolkit row) was built to answer one
question on-device: **is a synthesized tone good enough?** The player confirmed it is, for the reference
role, and chose block-only for v1.

The larger realisation: *Hear* is not a chord feature. Its primitive is "sound a set of MIDI notes," and a
chord is just the *simultaneous* case of the *sequential* one. Because the ordered-MIDI data already
exists on the scale/run/chord models, a single sequence-capable `ToneEngine` unlocks chord preview,
scale-box preview, arpeggios, fretboard runs, and interval/ear-training playback from one substrate.

## Consequences

- **v1 Hear = chords, block-only**, on the built-in tone — the smallest honest slice. But `ToneEngine` is
  **sequence-capable from day one**, so scale/arpeggio/interval preview are thin follow-up slices, not a
  rewrite.
- **No licensing surface in v1.** Nothing is redistributed; the guitar-SoundFont path (D4.3) is the only
  place a license question could ever enter, and it's deferred and gated on a *redistributable* asset.
- **The audio work is a multi-surface effort, not one screen.** Sequencing this against submission is a
  scheduling call recorded in `docs/backlog.md`, not here.
- **Spike is throwaway.** `ChordTonePlayer` / `HearSpikeView` and the temporary Toolkit row are the seed
  for `ToneEngine`; they are removed when the real service lands.

## Alternatives considered

- **Bundle a Kontakt sample library (e.g. Pettinhouse).** Rejected — **Kontakt is a Native Instruments
  engine that cannot run inside an iOS app**; only the raw WAVs would be usable, and "free to use in your
  music" generally does not grant redistribution *as a playable instrument in a shipped product*. Same
  rights posture as ADR 0065 T8 / the guitargearfinder content stance: encode methods, don't ship others'
  assets.
- **Render notes/chords in GarageBand and embed them.** Rejected on two counts: (1) Apple's GarageBand /
  Logic sound content is licensed for use *in musical productions*, not for repackaging as an instrument
  inside an app — App Store risk; (2) arbitrary voicings (movable/custom chords, ADR 0084) and full scale
  boxes are effectively infinite, so pre-rendering can't cover the space — you'd need per-note samples
  mapped into a sampler, i.e. a SoundFont, at which point GarageBand was just a risky way to author one.
- **Ship a guitar SoundFont in v1.** Deferred, not rejected (D4.3). The built-in tone clears the bar for a
  pitch-reference tool; adding weight/licensing scope before it's shown necessary is premature.
- **Per-feature audio (chord player, scale player, …).** Rejected — three copies of the same
  `AVAudioUnitSampler` wiring. One `ToneEngine` with block + sequence covers every surface (D4.5/D4.6).
