#if DEBUG
import Foundation
import SwiftData

/// A loop with a saved piece, for the UI tests that open *Name the notes* (ADR 0235, build order 4) and
/// *Watch it on the neck* (ADR 0254).
///
/// Nothing drove the sheet before this, so a change to it could only be checked by eye, and ADR 0235
/// moves its neck into a shared editor. The route in needs a song with a loop that has a piece, and the
/// simulator's store is shared by the whole suite, so the seed is **its own song**, found by its own id:
///
/// - under `-uiTesting -seedNamingPiece` it is put in, or put back as it was: six unnamed notes on
///   *Verse riff*, no snags, and no notes in its loops' Journals (the snag line test writes one, ADR 0238);
/// - under `-uiTesting -seedWatchPiece` the same, with the six placed on the neck, since *Watch it on the
///   neck* has no door for a piece with nothing on it;
/// - under `-uiTesting` alone it is **taken out**. The *Start here* card shows only in an empty library,
///   and two tests start from it, so a song left behind by a naming run that failed halfway would fail
///   them too. Every other test's launch cleans up, whatever the last run did.
///
/// A copy of the demo song, so its audio is the generated arpeggio and needs no file.
enum NamingPieceSeed {

    static let sourceID = "uitest-naming"
    static let title = "Naming test"
    static let loopName = "Verse riff"
    static let noteCount = 6

    enum Action: Equatable { case seed, seedFretted, remove, none }

    /// What this launch does with the seed. Split out so it's tested: the removal is what keeps the rest
    /// of the suite clean, and nothing else would notice if it stopped.
    static func action(for arguments: [String]) -> Action {
        guard arguments.contains(UITestHooks.launchArgument) else { return .none }
        if arguments.contains(UITestHooks.watchPieceArgument) { return .seedFretted }
        return arguments.contains(UITestHooks.namingPieceArgument) ? .seed : .remove
    }

    /// The six notes on the neck, for *Watch it on the neck*: G5, hammered on to G7, B5, B8 bent a whole
    /// step, B5, G7. Strings highest-first, so the G is 2 and the B is 1.
    static let placedLabels: [PieceLabel] = [
        .fretted(string: 2, fret: 5),
        .fretted([FrettedNote(string: 2, fret: 7)], into: .legato),
        .fretted(string: 1, fret: 5),
        .fretted([FrettedNote(string: 1, fret: 8, bend: 2)], into: nil),
        .fretted(string: 1, fret: 5),
        .fretted(string: 2, fret: 7)
    ]

    /// The piece it starts from: `noteCount` notes inside *Verse riff*, unnamed or placed on the neck
    /// (`placedLabels`), on a guitar in standard tuning whatever the tuner says, so a fret reads the same on
    /// every run.
    static func piece(duration: TimeInterval, start: Double, end: Double, placed: Bool = false) -> PieceTranscription {
        let from = start * duration
        let step = (end - start) * duration / Double(noteCount + 1)
        let standard = NamingTuning(instrument: .guitar, tuning: Instrument.guitar.standardTuning)
        let taps = (1...noteCount).map { note in
            PieceTranscription.Tap(seconds: from + step * Double(note), label: placed ? placedLabels[note - 1] : nil)
        }
        var piece = PieceTranscription(taps: taps, openMidi: standard.openMidi, tuningLabel: standard.label)
        piece.changedAt = .now
        return piece
    }

    @MainActor
    static func apply(to context: ModelContext, arguments: [String] = CommandLine.arguments) {
        let action = action(for: arguments)
        guard action != .none else { return }
        // In memory, not a `#Predicate`: a handful of songs, and no predicate trap to step in.
        let seeded = ((try? context.fetch(FetchDescriptor<Song>())) ?? []).filter { $0.sourceID == sourceID }
        // A loop's notes outlive it (ADR 0151), so they go first or a removed song leaves them in the Journal.
        for song in seeded {
            for loop in song.loops {
                loop.journal.forEach(context.delete)
                loop.journal = []
            }
        }
        switch action {
        case .remove:
            seeded.forEach(context.delete)
        case .seed, .seedFretted:
            let song = seeded.first ?? insertSong(into: context)
            song.snags.forEach(context.delete)
            song.snags = []
            if let loop = song.loops.first(where: { $0.name == loopName }) {
                loop.transcription = piece(duration: song.duration, start: loop.start, end: loop.end,
                                           placed: action == .seedFretted)
            }
        case .none:
            return
        }
        try? context.save()
    }

    @MainActor
    private static func insertSong(into context: ModelContext) -> Song {
        let song = Song.sample()
        song.title = title
        song.sourceID = sourceID
        context.insert(song)
        return song
    }
}
#endif
