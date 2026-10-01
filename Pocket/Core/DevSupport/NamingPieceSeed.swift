#if DEBUG
import Foundation
import SwiftData

/// A loop with a saved piece, for the one UI test that opens *Name the notes* (ADR 0235, build order 4).
///
/// Nothing drove the sheet before this, so a change to it could only be checked by eye, and ADR 0235
/// moves its neck into a shared editor. The route in needs a song with a loop that has a piece, and the
/// simulator's store is shared by the whole suite, so the seed is **its own song**, found by its own id:
///
/// - under `-uiTesting -seedNamingPiece` it is put in, or put back as it was: six unnamed notes on
///   *Verse riff*, and no snags;
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

    enum Action: Equatable { case seed, remove, none }

    /// What this launch does with the seed. Split out so it's tested: the removal is what keeps the rest
    /// of the suite clean, and nothing else would notice if it stopped.
    static func action(for arguments: [String]) -> Action {
        guard arguments.contains(UITestHooks.launchArgument) else { return .none }
        return arguments.contains(UITestHooks.namingPieceArgument) ? .seed : .remove
    }

    /// The piece it starts from: `noteCount` unnamed notes inside *Verse riff*, on a guitar in standard
    /// tuning whatever the tuner says, so a fret reads the same on every run.
    static func piece(duration: TimeInterval, start: Double, end: Double) -> PieceTranscription {
        let from = start * duration
        let step = (end - start) * duration / Double(noteCount + 1)
        let standard = NamingTuning(instrument: .guitar, tuning: Instrument.guitar.standardTuning)
        var piece = PieceTranscription(taps: (1...noteCount).map { .init(seconds: from + step * Double($0)) },
                                       openMidi: standard.openMidi, tuningLabel: standard.label)
        piece.changedAt = .now
        return piece
    }

    @MainActor
    static func apply(to context: ModelContext, arguments: [String] = CommandLine.arguments) {
        let action = action(for: arguments)
        guard action != .none else { return }
        // In memory, not a `#Predicate`: a handful of songs, and no predicate trap to step in.
        let seeded = ((try? context.fetch(FetchDescriptor<Song>())) ?? []).filter { $0.sourceID == sourceID }
        switch action {
        case .remove:
            seeded.forEach(context.delete)
        case .seed:
            let song = seeded.first ?? insertSong(into: context)
            song.snags.forEach(context.delete)
            song.snags = []
            if let loop = song.loops.first(where: { $0.name == loopName }) {
                loop.transcription = piece(duration: song.duration, start: loop.start, end: loop.end)
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
