import Foundation
import SwiftData

/// Points an existing `Song` at a file again (ADR 0148 §6) — for a song whose audio can no longer
/// be found, **and** for one pointed at the wrong file (ADR 0152).
///
/// The case this was written for: a library imported before ADR 0148 and carried through an app
/// reinstall or a restore-from-backup. Every bookmark in it is dead, no copy was ever made, and
/// re-importing would create a *new* song — stranding the loops, markers, takes and practice history
/// attached to the old one. Relink keeps the row and replaces only the audio.
///
/// The second case is the first one's own failure mode: a relink that lands on the wrong file
/// **succeeds**, so the song resolves, the failure notice never appears, and the only door back
/// closes behind the player. Same operation, second entry point — see `SongAudioSection`.
///
/// **The invariant:** `sourceID` never changes (ADR 0148 §4). It is what loops, markers, takes and
/// `PracticeRun` rows are attached to, so a relink that minted a fresh id would repair the sound and
/// silently orphan everything the player had built on top of it.
enum SongRelinker {

    enum RelinkError: Error, LocalizedError {
        case accessDenied
        case unreadable

        var errorDescription: String? {
            switch self {
            case .accessDenied: "Red Moon couldn't open that file."
            case .unreadable: "That file couldn't be read as audio."
            }
        }
    }

    /// Everything the song needs from the new file, gathered off the main actor. `Sendable` so it
    /// can cross a `Task.detached` boundary — which a `Song` and a `ModelContext` cannot, hence the
    /// same `prepare`/`apply` split `SongImporter` uses.
    struct Prepared: Sendable {
        let audioFileName: String
        let bookmark: Data?
        let duration: TimeInterval
        let amplitudes: [Double]
    }

    /// What changed, so the caller can tell the player something true rather than a bare "done".
    struct Outcome {
        let newDuration: TimeInterval
        /// The song's duration before the relink, for the mismatch warning below.
        let previousDuration: TimeInterval

        /// Whether the new file is a materially different length from the one the loops were drawn
        /// against. A re-encode of the same track lands within a second; a *different* track does
        /// not. The relink still succeeds — the loops are the player's work and are not deleted on
        /// a guess — but the caller should say so, because loops beyond the new end won't play.
        var durationChangedMaterially: Bool { abs(newDuration - previousDuration) > 1 }
    }

    /// Read the new file and copy it in: the expensive half, safe to run off the main actor because
    /// it touches no model context. `sourceID` is passed in rather than read from the song for the
    /// same reason — and it is the existing one, which is what keeps the loops attached.
    ///
    /// The waveform is re-extracted rather than reused: a relink can legitimately point at a
    /// different encode, and drawing the old envelope over new audio would put every loop boundary
    /// in the wrong place on screen.
    static func prepare(from url: URL, sourceID: String) throws -> Prepared {
        guard url.startAccessingSecurityScopedResource() else { throw RelinkError.accessDenied }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let extracted = try? WaveformExtractor.extract(from: url) else {
            throw RelinkError.unreadable
        }
        // Copied before anything is written to the model, so a failure here leaves the song exactly
        // as it was rather than half-relinked to a file we don't hold. Keyed on the existing
        // `sourceID`, so this *replaces* the song's old copy instead of accumulating a second file.
        let audioFileName = try SongFileStore.adopt(contentsOf: url, sourceID: sourceID)
        return Prepared(audioFileName: audioFileName, bookmark: try? url.bookmarkData(),
                        duration: extracted.duration, amplitudes: extracted.amplitudes)
    }

    /// Prepare + apply in one call, off the main actor for the decode (ADR 0152).
    ///
    /// The whole relink for a caller that owns no audio engine — the library's Song details sheet,
    /// where replacing the audio is a correction rather than a repair. The practice screen does
    /// **not** use this: it has a file open and must stop and reload around the swap, so it keeps
    /// its own `relinkAudio` wrapper over the same two halves.
    ///
    /// Only `sourceID` crosses the `Task.detached` boundary — a `Song` and a `ModelContext` are
    /// not `Sendable`, which is the reason for the `prepare`/`apply` split in the first place.
    @discardableResult
    @MainActor
    static func replace(audioAt url: URL, on song: Song,
                        in context: ModelContext) async throws -> Outcome {
        let sourceID = song.sourceID
        let prepared = try await Task.detached(priority: .userInitiated) {
            try prepare(from: url, sourceID: sourceID)
        }.value
        return apply(prepared, to: song, in: context)
    }

    /// Write a prepared relink onto the song. Cheap and `@MainActor` — the decode already happened.
    @discardableResult
    @MainActor
    static func apply(_ prepared: Prepared, to song: Song, in context: ModelContext) -> Outcome {
        let previousDuration = song.duration
        song.audioFileName = prepared.audioFileName
        song.bookmark = prepared.bookmark
        song.duration = prepared.duration
        song.amplitudes = prepared.amplitudes
        try? context.save()
        return Outcome(newDuration: prepared.duration, previousDuration: previousDuration)
    }
}
