import AVFoundation
import os

/// **Hear** — the app's shared pitched-tone preview (ADR 0097). A small, dedicated `AVAudioEngine`
/// graph over a single `AVAudioUnitSampler` that sounds a set of MIDI notes, either **together** (a
/// block chord) or **spaced out in time** (a scale run, arpeggio or interval). It is a *pitch
/// reference*, not part of the file-playback pipeline — a separate graph, so it does not touch or
/// contradict ADR 0001 (practice audio = DRM-free file playback + synthesized click).
///
/// **One engine, every surface (ADR 0097 D4.5/D4.6).** The primitive is "sound an ordered set of MIDI
/// notes"; a chord is just the *simultaneous* case of the *sequential* one. Callers hand it MIDI the
/// models already expose (`ChordVoicing.midiNotes`, `ScaleRun.sequence`→`CAGEDShape.midi`,
/// `FretboardDrill.notes`), so no per-feature note-derivation is built. v1 wires only block-chord Hear
/// in My Chords; `sequence(_:)` is here from day one so scale/arpeggio/interval preview are thin
/// follow-up slices, not a rewrite.
///
/// **Sound source (ADR 0097 D4.2/D4.3).** On iOS an *unloaded* `AVAudioUnitSampler` renders a clean
/// built-in tone (envelope + sine-ish) — there is no accessible system GM bank on iOS — which is a
/// good, honest pitch reference that ships with **zero assets** and no licensing. If a more
/// guitar-like timbre is wanted later, drop a **redistributable (CC0)** `HearGuitar.sf2` into the
/// bundle and `loadSoundFontIfPresent()` selects a nylon-guitar program over the same code path
/// (deferred, not v1 scope).
///
/// Shared singleton so the whole app drives one engine — building an `AVAudioEngine` per view would
/// churn the audio graph and stack redundant samplers.
@MainActor
final class ToneEngine {

    /// The app-wide instance. Every Hear affordance drives this one engine.
    static let shared = ToneEngine()

    /// Which sound is live — the built-in tone (zero assets) or a bundled SoundFont if one was found.
    enum Source { case builtInTone, soundFont }

    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private(set) var source: Source = .builtInTone

    /// In-flight note-on/off work items, so a re-tap can cancel a still-ringing preview and retrigger
    /// cleanly instead of layering two chords on top of each other.
    private var pending: [DispatchWorkItem] = []
    /// MIDI notes currently sounding — stopped on `reset()` so a retrigger starts from silence.
    private var ringing: Set<UInt8> = []

    /// GM melodic-bank selectors (`kAUSampler_DefaultMelodicBankMSB` / `…DefaultBankLSB`) and the
    /// 0-indexed GM program for Acoustic Guitar (nylon) = 24 — used only if a SoundFont is present.
    private let gmMelodicBankMSB: UInt8 = 0x79
    private let gmBankLSB: UInt8 = 0x00
    private let nylonGuitarProgram: UInt8 = 24

    init() {
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        loadSoundFontIfPresent()
    }

    // MARK: - Public API (ADR 0097 D4.5)

    /// Sound `notes` **together** as a block chord — every note speaks at once and releases after
    /// `sustain`. This is the v1 chord Hear (ADR 0097 D4.4: block only, strum dropped).
    func sound(_ notes: [Int], velocity: UInt8 = 90, sustain: TimeInterval = 1.8) {
        fire(notes: notes, stride: 0, duration: sustain, velocity: velocity)
    }

    /// Sound `notes` **one at a time** as a melodic line — each note onsets `noteDuration + gap` after
    /// the previous and sustains for `noteDuration`. Feeds scale runs, arpeggios and intervals (not
    /// wired in Slice 1, but the reason `ToneEngine` exists rather than a chord-only player).
    func sequence(_ notes: [Int], noteDuration: TimeInterval = 0.32, gap: TimeInterval = 0.06,
                  velocity: UInt8 = 90) {
        fire(notes: notes, stride: noteDuration + gap, duration: noteDuration, velocity: velocity)
    }

    /// Silence any in-flight preview immediately (cancels scheduled note-ons and stops ringing notes).
    func stop() { reset() }

    // MARK: - Scheduling

    /// Schedule `notes` with a fixed `stride` between successive onsets (0 = block) and a per-note
    /// `duration`. Starts the session/engine lazily on first sound, and cancels any prior preview so a
    /// re-tap retriggers cleanly.
    private func fire(notes: [Int], stride: TimeInterval, duration: TimeInterval, velocity: UInt8) {
        guard !notes.isEmpty else { return }
        AudioPlumbing.configurePlaybackSession(label: "Hear")
        AudioPlumbing.startIfNeeded(engine, label: "Hear")
        reset()

        for (index, note) in notes.enumerated() {
            let midi = UInt8(clamping: note)
            let onset = Double(index) * stride

            let noteOn = DispatchWorkItem { [weak self] in
                self?.sampler.startNote(midi, withVelocity: velocity, onChannel: 0)
                self?.ringing.insert(midi)
            }
            let noteOff = DispatchWorkItem { [weak self] in
                self?.sampler.stopNote(midi, onChannel: 0)
                self?.ringing.remove(midi)
            }
            pending.append(noteOn)
            pending.append(noteOff)
            DispatchQueue.main.asyncAfter(deadline: .now() + onset, execute: noteOn)
            DispatchQueue.main.asyncAfter(deadline: .now() + onset + duration, execute: noteOff)
        }
    }

    /// Cancel every scheduled note-on/off and silence anything still sounding.
    private func reset() {
        pending.forEach { $0.cancel() }
        pending.removeAll()
        for midi in ringing { sampler.stopNote(midi, onChannel: 0) }
        ringing.removeAll()
    }

    // MARK: - Sound source

    /// Look for a redistributable SoundFont in the bundle and load its nylon-guitar program (ADR 0097
    /// D4.3). Absent one — the v1 default — leave the sampler on its clean built-in tone.
    private func loadSoundFontIfPresent() {
        guard let url = Bundle.main.url(forResource: "HearGuitar", withExtension: "sf2") else {
            AudioPlumbing.log.info("Hear: no HearGuitar.sf2 — using built-in sampler tone")
            return
        }
        do {
            try sampler.loadSoundBankInstrument(at: url, program: nylonGuitarProgram,
                                                bankMSB: gmMelodicBankMSB, bankLSB: gmBankLSB)
            source = .soundFont
            AudioPlumbing.log.info("Hear: loaded HearGuitar.sf2 nylon program")
        } catch {
            AudioPlumbing.log.error("Hear: sf2 load failed: \(error.localizedDescription)")
        }
    }
}
