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
/// `FretboardDrill.notes`), so no per-feature note-derivation is built.
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
    private let sequencer: HearSequencer
    private(set) var source: Source = .builtInTone

    /// GM melodic-bank selectors (`kAUSampler_DefaultMelodicBankMSB` / `…DefaultBankLSB`) and the
    /// 0-indexed GM program for Acoustic Guitar (nylon) = 24 — used only if a SoundFont is present.
    private let gmMelodicBankMSB: UInt8 = 0x79
    private let gmBankLSB: UInt8 = 0x00
    private let nylonGuitarProgram: UInt8 = 24

    init() {
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        sequencer = HearSequencer(sampler: sampler)
        loadSoundFontIfPresent()
    }

    // MARK: - Public API (ADR 0097 D4.5)

    /// Sound `notes` **together** as a block chord — every note speaks at once and releases after
    /// `sustain`. This is the v1 chord Hear (ADR 0097 D4.4: block only, strum dropped).
    func sound(_ notes: [Int], velocity: UInt8 = 90, sustain: TimeInterval = 1.8) {
        start()
        sequencer.schedule(notes: notes.map { $0 }, stride: 0, duration: sustain, velocity: velocity)
    }

    /// Sound `notes` **one at a time** as a melodic line — each note onsets `noteDuration + gap` after
    /// the previous and sustains for `noteDuration`. Feeds scale runs, arpeggios, picking runs and
    /// intervals; the caller paces it (`noteDuration + gap`) to match any visual walk it's synced to
    /// (ADR 0097 S3). A `nil` entry is a **rest** — it consumes its time slot (so a custom drill's empty
    /// grid cells keep the line aligned to the walking highlight) but sounds nothing.
    func sequence(_ notes: [Int?], noteDuration: TimeInterval = 0.32, gap: TimeInterval = 0.06,
                  velocity: UInt8 = 90) {
        start()
        sequencer.schedule(notes: notes, stride: noteDuration + gap, duration: noteDuration,
                           velocity: velocity)
    }

    /// Silence any in-flight preview immediately (cancels scheduled note-ons and stops ringing notes).
    func stop() { sequencer.stopAll() }

    // MARK: - Engine start

    /// Bring the session/engine up lazily on first sound. Cheap and idempotent once running; kept on the
    /// main actor (session/engine setup) while note *timing* runs off it, on the sequencer's own queue.
    ///
    /// **Never steals the session from a live take.** The session goes `.playAndRecord` only while a take
    /// is actually recording (ADR 0069 §3); reconfiguring it to `.playback` mid-take would kill the mic
    /// capture. A Hear surface is unreachable during a take today, but the guard keeps the pitch-preview
    /// path from ever contending with recording if one becomes reachable while armed — the tone still
    /// sounds out through the record-capable session, it just doesn't flip the category.
    private func start() {
        if AVAudioSession.sharedInstance().category != .playAndRecord {
            AudioPlumbing.configurePlaybackSession(label: "Hear")
        }
        AudioPlumbing.startIfNeeded(engine, label: "Hear")
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

/// The off-main note scheduler behind `ToneEngine`. All timing runs on a dedicated `userInteractive`
/// **serial queue that does nothing but fire notes**, so the events are immune to main-thread load —
/// the fix for ADR 0097 Slice 3's drift, where the 60fps walking-highlight animation starved the old
/// `DispatchQueue.main` timers and the tone slipped progressively late (worst on the way back).
///
/// Deadlines are **absolute** (`start + index·stride`), so lateness never accumulates. A `generation`
/// counter invalidates a still-ringing preview when a re-tap retriggers, instead of tracking per-note
/// work items. `AVAudioUnitSampler`'s `startNote`/`stopNote` are thread-safe, and every piece of mutable
/// state (`ringing`, `generation`) is confined to `queue`, so the class is safe to treat as `Sendable`.
private final class HearSequencer: @unchecked Sendable {
    private let sampler: AVAudioUnitSampler
    private let queue = DispatchQueue(label: "click.decooperations.pocket.hear.timing",
                                      qos: .userInteractive)
    /// MIDI notes currently sounding — stopped on retrigger/stop so a new preview starts from silence.
    private var ringing: Set<UInt8> = []
    /// Bumped on every schedule/stop; a scheduled note-on/off only fires if its captured generation is
    /// still current, so a re-tap cleanly cancels the previous preview's remaining events.
    private var generation = 0

    init(sampler: AVAudioUnitSampler) { self.sampler = sampler }

    /// Schedule `notes` with a fixed `stride` between successive onsets (0 = block) and a per-note
    /// `duration`. Cancels any prior preview so a re-tap retriggers cleanly. The *what-sounds-when* is
    /// computed purely by `HearPlan` (block vs melodic, rests, absolute deadlines); this method just
    /// dispatches those events against the sampler, silencing the previous note on each onset when the
    /// plan is monophonic so a long run never piles up voices (ADR 0097 S3).
    func schedule(notes: [Int?], stride: TimeInterval, duration: TimeInterval, velocity: UInt8) {
        let events = HearPlan.events(notes: notes, stride: stride, duration: duration)
        let mono = HearPlan.isMonophonic(stride: stride)
        queue.async {
            self.stopRinging()
            self.generation += 1
            let generation = self.generation
            let start = DispatchTime.now()
            for event in events {
                self.queue.asyncAfter(deadline: start + event.onset) {
                    guard generation == self.generation else { return }
                    if mono { self.stopRinging() }   // one voice at a time for a melodic line
                    self.sampler.startNote(event.midi, withVelocity: velocity, onChannel: 0)
                    self.ringing.insert(event.midi)
                }
                self.queue.asyncAfter(deadline: start + event.offset) {
                    guard generation == self.generation else { return }
                    self.sampler.stopNote(event.midi, onChannel: 0)
                    self.ringing.remove(event.midi)
                }
            }
        }
    }

    /// Silence everything and invalidate any still-scheduled events.
    func stopAll() {
        queue.async {
            self.stopRinging()
            self.generation += 1
        }
    }

    private func stopRinging() {
        for midi in ringing { sampler.stopNote(midi, onChannel: 0) }
        ringing.removeAll()
    }
}
