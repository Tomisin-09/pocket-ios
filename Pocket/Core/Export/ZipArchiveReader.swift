import Compression
import Foundation

/// Why a zip could not be read (ADR 0188 D8).
///
/// Three cases rather than one, because they are three different sentences to a player: a file that
/// is not a zip at all, a zip this reader deliberately does not implement, and a zip that says it is
/// one thing and contains another. Only the middle one is a limitation rather than a fault, and it
/// carries the reason so the copy can say which limit was hit.
enum ZipReadFailure: Error, Equatable {

    /// No end-of-central-directory record. Not a zip, or truncated past recognition.
    case notAZip

    /// Well-formed, and outside the subset D8 scopes this reader to: encryption, spanning, ZIP64, or
    /// a compression method other than stored and deflate.
    case unsupported(String)

    /// The structure contradicts itself — an offset off the end, a local header that is not one, a
    /// length that does not match what came out.
    case corrupt
}

/// One file inside a zip, located but not yet read.
///
/// Split from its bytes on purpose: an archive's `takes/` directory can be hundreds of megabytes, so
/// the reader lists what is there cheaply and the caller decides what to pull into memory.
struct ZipEntry: Equatable {

    /// The path as stored, with `/` separators, relative to the zip's root.
    let path: String

    /// The size this entry will be once decompressed. From the central directory, and checked against
    /// what actually comes out.
    let uncompressedSize: Int

    // Where and how the bytes are stored. Internal rather than private only because the parser that
    // fills them in lives in `ZipArchiveReader+Parsing.swift`; nothing outside this pair should read
    // them, and `data(for:)` is the only intended way to turn an entry into bytes.
    let compressedSize: Int
    let method: UInt16
    let crc32: UInt32
    let localHeaderOffset: Int
}

/// A minimal zip reader, scoped to archives this app produced (ADR 0188 D8).
///
/// `NSFileCoordinator` gives zipping **out** and has no read side, and Foundation has no public unzip
/// on iOS. The two ways forward were a third-party package or a reader of our own, and D8 refuses the
/// package for the reason ADR 0120 already gives: Aptabase is this project's one pinned dependency,
/// and `ArchiveWriter` declined the same trade on the way out.
///
/// **What that scoping means concretely.** Stored (method 0) and deflate (method 8) entries, no
/// encryption, no spanning, no ZIP64. Everything outside that is refused by name rather than
/// mis-parsed. `libcompression`'s `COMPRESSION_ZLIB` is raw DEFLATE per RFC 1951 — which is exactly
/// what a zip entry holds, with no zlib wrapper to strip.
///
/// **The consequence D8 insists is written down: the export's zip method is part of the file format.**
/// ADR 0181 D5 chose `NSFileCoordinator`'s `.forUploading`; changing it is no longer an
/// implementation detail. `ZipArchiveReaderTests` therefore reads an archive **the current exporter
/// wrote**, not a checked-in fixture, so the day that choice changes is the day a test fails.
///
/// **Memory.** The zip is memory-mapped and entries are inflated one at a time, so peak cost is one
/// entry rather than the whole archive. `practice.json` and a single take are each small; the sum of
/// every take is not, and never has to be resident.
///
/// `nonisolated` throughout and free of SwiftData and SwiftUI: reading a large archive must not
/// happen on the main actor.
struct ZipArchiveReader {

    /// Every file in the zip, in central-directory order. Directory entries are dropped — they carry
    /// no bytes and a restore has no use for them.
    let entries: [ZipEntry]

    private let data: Data

    /// Map a zip off disk and read its central directory.
    ///
    /// `.mappedIfSafe` rather than a plain read: an archive is as large as the library it came from,
    /// and pulling all of it into memory to reach a directory at the end of it would be the one
    /// allocation this design exists to avoid.
    init(contentsOf url: URL) throws {
        try self.init(data: try Data(contentsOf: url, options: .mappedIfSafe))
    }

    init(data: Data) throws {
        self.data = data
        self.entries = try Self.readCentralDirectory(data)
    }

    /// The first entry whose path ends in `suffix`, ignoring the archive's root folder.
    ///
    /// A zip written by `.forUploading` nests everything under one folder named for the export date
    /// (`red-moon-practice-2026-09-03/`), so nothing inside is at a path a caller can hard-code. Every
    /// lookup here is by suffix for that reason.
    func entry(endingIn suffix: String) -> ZipEntry? {
        entries.first { $0.path == suffix || $0.path.hasSuffix("/" + suffix) }
    }

    /// Every entry inside a directory named `name`, keyed by leaf.
    ///
    /// `takes/` and `references/` are both flat directories keyed by file name, and that name is the
    /// join back to `practice.json`. Returning a dictionary makes the join a lookup rather than a
    /// scan per record.
    func entries(inDirectoryNamed name: String) -> [String: ZipEntry] {
        var found: [String: ZipEntry] = [:]
        for entry in entries {
            let parts = entry.path.split(separator: "/")
            guard parts.count >= 2, parts[parts.count - 2] == name else { continue }
            found[String(parts[parts.count - 1])] = entry
        }
        return found
    }

    /// Pull one entry's bytes out.
    ///
    /// The local header is re-read rather than trusted from the central directory: the two records
    /// carry the name and extra-field lengths independently, and it is the **local** pair that says
    /// where the data actually starts. Using the central directory's lengths is the classic way to
    /// read a zip that works on every file you tested and fails on someone's.
    func data(for entry: ZipEntry) throws -> Data {
        let header = entry.localHeaderOffset
        guard try Self.integer(data, at: header, UInt32.self) == 0x0403_4b50 else { throw ZipReadFailure.corrupt }
        let nameLength = Int(try Self.integer(data, at: header + 26, UInt16.self))
        let extraLength = Int(try Self.integer(data, at: header + 28, UInt16.self))
        let start = header + 30 + nameLength + extraLength
        let end = start + entry.compressedSize
        guard start >= 0, end <= data.count, start <= end else { throw ZipReadFailure.corrupt }

        let payload = data.subdata(in: (data.startIndex + start)..<(data.startIndex + end))
        let output: Data
        switch entry.method {
        case 0:
            output = payload
        case 8:
            output = try Self.inflate(payload, to: entry.uncompressedSize)
        default:
            throw ZipReadFailure.unsupported("compression method \(entry.method)")
        }

        guard output.count == entry.uncompressedSize else { throw ZipReadFailure.corrupt }
        guard Self.crc32(output) == entry.crc32 else { throw ZipReadFailure.corrupt }
        return output
    }
}
