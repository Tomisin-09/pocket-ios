import Foundation

/// Why an archive could not be opened (ADR 0188 S3).
///
/// Deliberately the same shape as `ReceiveFailure`: two doors, one grammar. Each case carries its own
/// sentence because "couldn't read the file" is a lie about an archive that is perfectly well formed
/// and merely newer than this build, and D9's argument is that the player is told what was found
/// *before* anything happens.
///
/// `Error` because it is a `Result`'s failure type, which Swift requires; nothing throws it.
enum RestoreFailure: Error, Equatable {

    /// Not a zip, or a zip with no `practice.json` in it. The picture the player has — "I chose the
    /// wrong file" — and the same sentence serves both, because from the outside they are one mistake.
    case notAnArchive

    /// A zip this reader is scoped out of (D8): encrypted, spanned, ZIP64. Well-formed and refused,
    /// which is a different thing from broken, and carries what was hit.
    case unsupportedArchive(reason: String)

    /// The zip opened and the payload inside it did not parse, or its CRC did not match.
    case corrupt

    /// Written by a newer build (D2). Carries `SchemaVersionGate`'s sentence rather than composing its
    /// own, so both doors refuse in the same words.
    case futureVersion(message: String)

    /// What the player is told.
    var message: String {
        switch self {
        case .notAnArchive:
            return "This doesn’t look like a Red Moon archive."
        case let .unsupportedArchive(reason):
            return "Red Moon can’t open this archive (\(reason))."
        case .corrupt:
            return "This archive is damaged and can’t be read."
        case let .futureVersion(message):
            return message
        }
    }
}

/// An archive that has been opened, checked, and **not yet written anywhere** (ADR 0188 D9).
///
/// Holds the zip open alongside the decoded payload. Take audio and reference pictures are staged
/// straight out of it when the restore runs, so re-opening — and re-verifying every CRC — would be
/// work done twice on the largest files in the file.
struct ReadArchive: Sendable {

    /// The payload of `practice.json`.
    let archive: PracticeArchive

    /// The zip it came out of, still open.
    let zip: ZipArchiveReader

    /// Take audio actually present in `takes/`, by file name.
    ///
    /// Separate from `archive.includesTakeAudio`, which says what the *export* intended. The two can
    /// disagree honestly: `ExportedArchive.takesMissing` records that a take's file was already gone
    /// at export time, and an archive that says it includes audio can still be missing a file whose
    /// row it carries.
    let takeAudio: [String: ZipEntry]

    /// Reference pictures actually present in `references/`, by file name.
    let referenceImages: [String: ZipEntry]
}

/// Opens an exported archive and hands back what is inside it (ADR 0188 S3).
///
/// The read half of the archive door, and pure: Foundation only, no SwiftData, no SwiftUI. Everything
/// that decides whether a file can be opened at all lives here, so it can be tested against real
/// exports rather than through a file picker — which is the same reason `SchemaVersionGate` was split
/// out in S2.
///
/// `nonisolated`, because an archive is as large as the library it came from and inflating one has no
/// business on the main actor.
enum ArchiveRestoreReader {

    /// The payload's name inside the dated export folder.
    static let payloadName = "practice.json"

    /// Open the archive at `url`.
    ///
    /// A `Result` rather than `throws`, matching `ReceivedRoutineBuilder`: every failure here is one
    /// the player is shown as a sentence, and a typed failure keeps the compiler checking that each
    /// one has been given words.
    nonisolated static func read(contentsOf url: URL) -> Result<ReadArchive, RestoreFailure> {
        do {
            return try read(zip: ZipArchiveReader(contentsOf: url))
        } catch let failure as ZipReadFailure {
            return .failure(translate(failure))
        } catch {
            return .failure(.notAnArchive)
        }
    }

    /// Read an already-open zip. Split out so tests can hand one in without a file on disk.
    nonisolated static func read(zip: ZipArchiveReader) -> Result<ReadArchive, RestoreFailure> {
        guard let entry = zip.entry(endingIn: payloadName) else { return .failure(.notAnArchive) }

        let payload: Data
        do {
            payload = try zip.data(for: entry)
        } catch let failure as ZipReadFailure {
            return .failure(translate(failure))
        } catch {
            return .failure(.corrupt)
        }

        // The version is read before the payload is trusted for anything else (D2). A file from the
        // future may well decode — the fields it shares with this build are the fields this build
        // wrote — and decoding it anyway would silently drop whatever is new in it.
        guard let announced = try? ArchiveCoding.decode(SchemaVersionProbe.self, from: payload) else {
            return .failure(.corrupt)
        }
        if case let .refuse(message) = SchemaVersionGate.evaluate(
            fileVersion: announced.schemaVersion,
            currentVersion: PracticeArchive.currentSchemaVersion) {
            return .failure(.futureVersion(message: message))
        }

        guard let archive = try? ArchiveCoding.decode(PracticeArchive.self, from: payload) else {
            return .failure(.corrupt)
        }
        return .success(ReadArchive(archive: archive,
                                    zip: zip,
                                    takeAudio: zip.entries(inDirectoryNamed: "takes"),
                                    referenceImages: zip.entries(inDirectoryNamed: "references")))
    }

    /// Turn a zip-level failure into one the player is shown.
    ///
    /// `.notAZip` becomes `.notAnArchive` rather than keeping its own name: from the player's side
    /// choosing a photo and choosing a corrupt zip are the same mistake, and the sentence has to be
    /// about the archive rather than about the container format.
    private nonisolated static func translate(_ failure: ZipReadFailure) -> RestoreFailure {
        switch failure {
        case .notAZip: return .notAnArchive
        case .unsupported(let reason): return .unsupportedArchive(reason: reason)
        case .corrupt: return .corrupt
        }
    }
}

/// Just enough of `practice.json` to read its version (ADR 0188 D2).
///
/// A separate type rather than decoding the whole archive and checking afterwards, because the whole
/// point of the gate is to refuse a file **before** trusting the rest of its shape. Decoding first
/// would mean a future archive's unknown fields had already been dropped by the time anyone asked
/// whether it should have been read at all.
private struct SchemaVersionProbe: Decodable {
    var schemaVersion: Int
}
