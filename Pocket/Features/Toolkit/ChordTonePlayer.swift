import AVFoundation
import os

/// **SPIKE (ADR 0096 D4 — Hear source, throwaway).** Plays a `ChordVoicing`'s pitches through an
/// `AVAudioUnitSampler`, one MIDI note per sounded string, so we can judge on-device whether a
/// synthesized "Hear" is good enough before committing the D4 decision. Delete once D4 is settled.
///
/// **What this actually proves on iOS:** an unloaded `AVAudioUnitSampler` does *not* give you a GM
/// guitar — that's a macOS thing. On iOS it renders a clean built-in tone (sine-ish with an envelope),
/// which is the true *zero-asset* baseline. To hear a real guitar timbre, drop a redistributable
/// (CC0 / public-domain) SoundFont named `HearGuitar.sf2` into the app bundle and this loader will
/// pick it up and select a nylon-guitar program. So the spike lets you compare both paths:
///   • no asset  → clean built-in tone (ships tiny, zero licensing)
///   • +sf2      → nylon guitar (the upgrade path, ~a few MB)
@MainActor
final class ChordTonePlayer {

    /// Which sound the sampler ended up with — surfaced in the spike UI so the on-device test is honest
    /// about whether you're hearing the zero-asset baseline or a bundled SoundFont.
    enum Source: String { case builtInTone = "Built-in tone (zero assets)", soundFont = "Bundled SoundFont" }

    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private(set) var source: Source = .builtInTone

    /// GM melodic-bank selectors (`kAUSampler_DefaultMelodicBankMSB` / `…DefaultBankLSB`) and the
    /// 0-indexed GM program for Acoustic Guitar (nylon) = 24.
    private let gmMelodicBankMSB: UInt8 = 0x79
    private let gmBankLSB: UInt8 = 0x00
    private let nylonGuitarProgram: UInt8 = 24

    init() {
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        loadSoundFontIfPresent()
    }

    /// Look for a redistributable SoundFont in the bundle and load its nylon-guitar program. Absent one,
    /// leave the sampler on its default built-in tone (still fully playable — just not guitar-like).
    private func loadSoundFontIfPresent() {
        guard let url = Bundle.main.url(forResource: "HearGuitar", withExtension: "sf2") else {
            AudioPlumbing.log.info("HearSpike: no HearGuitar.sf2 — using built-in sampler tone")
            return
        }
        do {
            try sampler.loadSoundBankInstrument(at: url, program: nylonGuitarProgram,
                                                bankMSB: gmMelodicBankMSB, bankLSB: gmBankLSB)
            source = .soundFont
            AudioPlumbing.log.info("HearSpike: loaded HearGuitar.sf2 nylon program")
        } catch {
            AudioPlumbing.log.error("HearSpike: sf2 load failed: \(error.localizedDescription)")
        }
    }

    /// Sound the voicing. `strum` staggers note-ons low-E→high-e like a downstroke; otherwise all
    /// strings speak together (a "block" chord). Notes auto-release after `sustain`.
    func play(_ voicing: ChordVoicing, strum: Bool, sustain: TimeInterval = 1.8) {
        AudioPlumbing.configurePlaybackSession(label: "HearSpike")
        AudioPlumbing.startIfNeeded(engine, label: "HearSpike")

        // `midiNotes` is in string order (high-e first). A downstroke hits the low strings first, so
        // reverse to strum from the bass up.
        let notes = strum ? Array(voicing.midiNotes.reversed()) : voicing.midiNotes
        let stagger: TimeInterval = strum ? 0.035 : 0

        for (index, note) in notes.enumerated() {
            let onset = Double(index) * stagger
            let midi = UInt8(clamping: note)
            DispatchQueue.main.asyncAfter(deadline: .now() + onset) { [weak self] in
                self?.sampler.startNote(midi, withVelocity: 90, onChannel: 0)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + onset + sustain) { [weak self] in
                self?.sampler.stopNote(midi, onChannel: 0)
            }
        }
    }
}
