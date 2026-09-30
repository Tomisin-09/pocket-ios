import Foundation

/// A loop's piece and its earlier versions (ADR 0233): one **in use**, which everything that reads a piece
/// reads, and the rest **kept**, newest first. Saving again, or using an earlier one, never loses the one
/// it takes over from: that goes first among the kept. Only `delete` removes one, and never the one in use.
///
/// Pure and SwiftUI-free (AGENTS.md). `Loop.pieceVersions` reads and writes it on the loop.
struct PieceVersions: Equatable, Sendable {
    var inUse: PieceTranscription?
    /// Newest first: the order they were taken over in.
    var kept: [PieceTranscription]

    /// A new pass saved on the loop (D3): it's in use, and the one it takes over from is kept.
    mutating func save(_ piece: PieceTranscription) {
        guard !piece.taps.isEmpty else { return }
        if let inUse { kept.insert(inUse, at: 0) }
        inUse = piece
    }

    /// Use an earlier version (D4): it's in use, and the one it takes over from is kept, so using that
    /// one again is the way back.
    mutating func use(_ index: Int) {
        guard kept.indices.contains(index) else { return }
        let chosen = kept.remove(at: index)
        if let inUse { kept.insert(inUse, at: 0) }
        inUse = chosen
    }

    /// Delete an earlier version (D4). The one in use can't be deleted: use another one first.
    mutating func delete(_ index: Int) {
        guard kept.indices.contains(index) else { return }
        kept.remove(at: index)
    }
}

// MARK: - On the loop

extension Loop {
    /// The piece's earlier versions (ADR 0233), newest first. Empty when there are none, or when the
    /// list can't be read: the piece in use doesn't depend on it (D2). Setting an empty list removes it.
    var keptTranscriptions: [PieceTranscription] {
        get {
            guard let keptTranscriptionsData else { return [] }
            return (try? JSONDecoder().decode([PieceTranscription].self, from: keptTranscriptionsData)) ?? []
        }
        set {
            let kept = newValue.filter { !$0.taps.isEmpty }
            keptTranscriptionsData = kept.isEmpty ? nil : try? JSONEncoder().encode(kept)
        }
    }

    /// The piece in use and the ones kept, read and written together.
    var pieceVersions: PieceVersions {
        get { PieceVersions(inUse: transcription, kept: keptTranscriptions) }
        set {
            transcription = newValue.inUse
            keptTranscriptions = newValue.kept
        }
    }
}
