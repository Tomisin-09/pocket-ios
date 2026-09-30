import SwiftData
import SwiftUI

/// What the **Name the notes** sheet is naming (ADR 0225): one pass tapped this visit, or the piece
/// already saved on the loop. `Identifiable` so it drives a `.sheet(item:)` at `EarTrainingView`'s body
/// root.
struct NamingRequest: Identifiable, Equatable {
    enum Source: Equatable {
        case pass(Int)
        case saved
    }

    let source: Source
    let taps: [PieceTranscription.Tap]
    /// The strings a saved piece's frets were placed on, so editing it reads them against the same
    /// strings even if the tuner's tuning has changed since. `nil` means use the tuner's.
    var openMidi: [Int]?
    var tuningLabel: String?
    /// The loop's region in song seconds, so *Missed a note?* never plays past it (ADR 0231).
    var region: ClosedRange<TimeInterval>?

    var id: String {
        switch source {
        case .pass(let number): return "pass-\(number)"
        case .saved: return "saved"
        }
    }
}

/// What the sheet hands back on Done: the taps, named, with any taken out or added (ADR 0231), and the
/// strings any fret was placed on.
struct NamingResult: Equatable {
    let taps: [PieceTranscription.Tap]
    let openMidi: [Int]
    let tuningLabel: String
}

/// The state behind **Count the notes** in Train your ear (ADR 0225). One per ear-training visit, owned
/// by `EarTrainingView` so the section, the pass rows and the naming sheet share it, and so the sheet can
/// sit at the view's body root.
///
/// Nothing here is saved until **Save**. The taps of a visit are scratch paper; a save copies one pass
/// onto the loop as its piece, which the Journal lists under Pieces (ADR 0229).
@MainActor
@Observable
final class CountTheNotesModel {

    let loop: Loop

    private(set) var passes = TapPasses()
    /// The pass the player picked by tapping its row, if any.
    var selectedPassID: Int?
    /// The pass the loop is playing now, while it plays. Set by the live row, which is the only view
    /// that reads the clock every frame (ADR 0153).
    private(set) var livePassID: Int?
    /// What the last Clear removed, until the next tap makes Undo meaningless.
    private(set) var cleared: [TapPasses.Pass]?
    /// The sheet's subject while it's open.
    var naming: NamingRequest?
    /// The strings the most recent naming placed frets on, used when that pass is saved.
    private var namingTuning: (openMidi: [Int], label: String)?
    /// Briefly true after a tap, to flash the pad.
    private(set) var flashToken = 0
    /// Briefly true after a tap on the pad while stopped, to say why nothing counted.
    private(set) var nudgeToken = 0

    init(loop: Loop) { self.loop = loop }

    /// Built on first read, not in `init`: `EarTrainingView` creates one of these per `init`, which runs
    /// on every parent render, and `State` keeps only the first. A whole-song beat grid per render
    /// would be a cost for nothing.
    @ObservationIgnored private var gridCache: CountGrid??

    /// The song's beats around this region, or `nil` when it has no grid to show.
    var grid: CountGrid? {
        if let gridCache { return gridCache }
        let song = loop.song
        let built = CountGrid(tempo: song?.tempoBPM, anchors: song?.downbeatAnchors ?? [],
                              beatsPerBar: song?.beatsPerBar ?? 4, duration: song?.duration ?? 0,
                              regionStart: loop.startSeconds, regionEnd: loop.endSeconds)
        gridCache = .some(built)
        return built
    }

    // MARK: - Reading

    /// The region's start and length in song seconds, for placing dots.
    var regionStart: TimeInterval { loop.startSeconds }
    var regionLength: TimeInterval { loop.regionSeconds }

    /// Where a tap sits across the region, 0…1.
    func fraction(of seconds: TimeInterval) -> Double {
        guard regionLength > 0 else { return 0 }
        return ((seconds - regionStart) / regionLength).clamped(to: 0...1)
    }

    /// The pass that Name the notes, Save and the readout act on: the picked row if it still exists and
    /// isn't the one playing, else the newest finished pass.
    var targetPass: TapPasses.Pass? {
        if let selectedPassID, selectedPassID != livePassID, let picked = passes.pass(id: selectedPassID) {
            return picked
        }
        return passes.passes.last { $0.id != livePassID }
    }

    /// How many taps the live pass has so far.
    var liveCount: Int { livePassID.flatMap { passes.pass(id: $0)?.count } ?? 0 }

    /// The rows to draw under the pad, newest first: finished passes only (the live one has its own row).
    var finishedRows: [TapPasses.Pass] {
        Array(passes.passes.filter { $0.id != livePassID }.suffix(4).reversed())
    }

    /// Whether the song's spelling of accidentals comes from its key or the player's preference.
    var spelling: NoteSpelling { Self.spelling(for: loop) }

    /// The same, for a loop the Journal is showing a piece of (ADR 0229).
    static func spelling(for loop: Loop) -> NoteSpelling {
        loop.song.flatMap { NoteSpelling.forMusicalKey($0.musicalKey) } ?? AppSettings.accidentalPreference
    }

    // MARK: - Tapping

    /// A new run of the loop: its passes number on from the last.
    func loopStarted() { passes.beginRun() }

    func loopStopped() { livePassID = nil }

    /// Called by the live row whenever the pass it's drawing changes.
    func noteLive(runPass: Int?) {
        livePassID = runPass.map { passes.id(forRunPass: $0) }
    }

    /// The tap pad's touch-down. Counts only while the loop plays; otherwise it says why.
    func tap(clock: LoopClockReading?) {
        guard let clock, let instant = TapTally.instant(at: clock) else {
            nudgeToken += 1
            return
        }
        passes.record(instant)
        cleared = nil
        flashToken += 1
    }

    // MARK: - Clear, with undo

    func clear() {
        let removed = passes.clear()
        cleared = removed.isEmpty ? nil : removed
        selectedPassID = nil
    }

    func undoClear() {
        guard let cleared else { return }
        passes.restore(cleared)
        self.cleared = nil
    }

    // MARK: - Naming

    func nameTarget() {
        guard let pass = targetPass else { return }
        naming = NamingRequest(source: .pass(pass.id), taps: pass.taps, region: region)
    }

    func nameSaved() {
        guard let piece = loop.transcription else { return }
        naming = NamingRequest(source: .saved, taps: piece.taps, openMidi: piece.openMidi,
                               tuningLabel: piece.tuningLabel, region: region)
    }

    /// The loop's region, or `nil` for one with no length.
    private var region: ClosedRange<TimeInterval>? {
        loop.endSeconds > loop.startSeconds ? loop.startSeconds...loop.endSeconds : nil
    }

    /// The sheet's Done. A pass keeps its names, and any tap taken out or added, for this visit; the
    /// saved piece is edited in place, which is the only way a saved piece ever changes short of saving
    /// another pass over it. An edit that changed something re-dates it, so the Journal moves it to the
    /// day it changed (ADR 0229).
    func finishNaming(_ request: NamingRequest, result: NamingResult, context: ModelContext) {
        guard !result.taps.isEmpty else { return }
        switch request.source {
        case .pass(let number):
            passes.replaceTaps(result.taps, forPass: number)
            namingTuning = (result.openMidi, result.tuningLabel)
        case .saved:
            guard let before = loop.transcription else { return }
            var piece = before
            piece.taps = result.taps.sorted { $0.seconds < $1.seconds }
            stampTuning(on: &piece, openMidi: result.openMidi, label: result.tuningLabel)
            guard piece != before else { return }
            piece.changedAt = .now
            loop.transcription = piece
            try? context.save()
        }
    }

    // MARK: - Saving

    /// Put the target pass on the loop as its piece, dated now. A piece already there is kept as an
    /// earlier version (ADR 0233 D3), so nothing is lost and nothing needs asking. **No Journal line** (ADR
    /// 0229): the Journal lists the piece in use under Pieces, so a line per save would only pile up copies.
    func save(context: ModelContext) {
        guard let pass = targetPass, !pass.taps.isEmpty else { return }
        var piece = PieceTranscription(taps: pass.taps)
        let tuning = namingTuning ?? Self.tunerTuning()
        stampTuning(on: &piece, openMidi: tuning.openMidi, label: tuning.label)
        piece.changedAt = .now
        loop.pieceVersions.save(piece)
        try? context.save()
        haptic(.success)
    }

    /// Record which strings the frets were placed on, only when there are frets to read against them.
    private func stampTuning(on piece: inout PieceTranscription, openMidi: [Int], label: String) {
        piece.openMidi = piece.hasFrettedLabels ? openMidi : nil
        piece.tuningLabel = piece.hasFrettedLabels ? label : nil
    }

    /// The tuner's instrument and tuning (ADR 0115), the one place a player says what they play.
    static func tunerTuning() -> (openMidi: [Int], label: String) {
        let instrument = AppSettings.tunerInstrument
        let name = UserDefaults.standard.string(forKey: AppSettings.Key.tunerTuning)
            ?? instrument.standardTuning.name
        let tuning = instrument.tuning(named: name)
        return (tuning.engineOpenMidi, "\(instrument.displayName) · \(tuning.name)")
    }
}
