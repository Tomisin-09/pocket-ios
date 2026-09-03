import Compression
import Foundation

/// The byte-level half of `ZipArchiveReader` (ADR 0188 D8): finding the central directory, reading
/// its records, raw inflate, and the CRC that says the bytes survived.
///
/// Separated from the reader's surface so the part a caller uses stays readable and the part that
/// parses a 1989 file format stays in one place. Every offset here is from the PKWARE APPNOTE
/// structures; the field names in the comments are that spec's.
extension ZipArchiveReader {

    /// Signatures, as they appear little-endian on disk.
    private enum Signature {
        static let endOfCentralDirectory: UInt32 = 0x0605_4b50
        static let centralDirectoryEntry: UInt32 = 0x0201_4b50
        static let zip64Locator: UInt32 = 0x0706_4b50
    }

    /// Read a little-endian integer at a byte offset, or fail rather than trap.
    ///
    /// **Bounds-checked on every read, deliberately.** This parses a file the app did not write in
    /// this run — a truncated download, a half-copied archive — and an out-of-range subscript on
    /// `Data` is a crash, not an error the door can report. Every field in this file goes through
    /// here for that reason.
    static func integer<T: FixedWidthInteger>(_ data: Data, at offset: Int, _ type: T.Type) throws -> T {
        let width = MemoryLayout<T>.size
        guard offset >= 0, offset + width <= data.count else { throw ZipReadFailure.corrupt }
        var value: T = 0
        let start = data.startIndex + offset
        for index in 0..<width {
            value |= T(data[start + index]) << (8 * index)
        }
        return value
    }

    /// Locate the end-of-central-directory record and read every entry it points at.
    ///
    /// The EOCD sits at the end of the file, after a comment of up to 65,535 bytes, so it is found by
    /// scanning backwards — there is no offset to it. That scan is the only way to open a zip, and it
    /// is why an empty or tiny file reports `.notAZip` rather than something more specific.
    static func readCentralDirectory(_ data: Data) throws -> [ZipEntry] {
        guard let eocd = try locateEndOfCentralDirectory(data) else { throw ZipReadFailure.notAZip }

        // A ZIP64 locator immediately before the EOCD means the real record is the ZIP64 one and the
        // 32-bit fields below are sentinels. D8 scopes this reader out of ZIP64 rather than reading
        // half of it: an archive large enough to need it is one no phone wrote through `.forUploading`.
        if eocd >= 20, try integer(data, at: eocd - 20, UInt32.self) == Signature.zip64Locator {
            throw ZipReadFailure.unsupported("ZIP64")
        }

        guard try integer(data, at: eocd + 4, UInt16.self) == 0,
              try integer(data, at: eocd + 6, UInt16.self) == 0 else {
            throw ZipReadFailure.unsupported("a split or spanned archive")
        }

        let count = Int(try integer(data, at: eocd + 10, UInt16.self))
        let directorySize = Int(try integer(data, at: eocd + 12, UInt32.self))
        let directoryOffset = Int(try integer(data, at: eocd + 16, UInt32.self))
        guard directoryOffset >= 0, directorySize >= 0,
              directoryOffset + directorySize <= data.count else { throw ZipReadFailure.corrupt }
        if count == 0xFFFF || directoryOffset == Int(UInt32.max) { throw ZipReadFailure.unsupported("ZIP64") }

        var entries: [ZipEntry] = []
        entries.reserveCapacity(count)
        var cursor = directoryOffset
        for _ in 0..<count {
            let (entry, next) = try readCentralDirectoryEntry(data, at: cursor)
            if let entry { entries.append(entry) }
            cursor = next
        }
        return entries
    }

    /// Scan backwards for the EOCD signature.
    ///
    /// Bounded by the maximum comment length plus the record itself, so a large file that is not a zip
    /// costs 64KB of scanning rather than a pass over the whole thing.
    private static func locateEndOfCentralDirectory(_ data: Data) throws -> Int? {
        let minimum = 22
        guard data.count >= minimum else { return nil }
        let limit = min(data.count, minimum + 0xFFFF)
        for back in minimum...limit {
            let offset = data.count - back
            if try integer(data, at: offset, UInt32.self) == Signature.endOfCentralDirectory {
                return offset
            }
        }
        return nil
    }

    /// Read one central-directory record.
    ///
    /// - Returns: the entry, and the offset of the next record. The entry is `nil` for a directory,
    ///   which is a real record with no bytes behind it — a restore has nothing to do with one, and
    ///   dropping it here keeps every caller from having to ask.
    private static func readCentralDirectoryEntry(_ data: Data, at offset: Int) throws -> (ZipEntry?, Int) {
        guard try integer(data, at: offset, UInt32.self) == Signature.centralDirectoryEntry else {
            throw ZipReadFailure.corrupt
        }
        let flags = try integer(data, at: offset + 8, UInt16.self)
        // Bit 0 is the encryption flag. An encrypted entry decrypts to nothing useful and there is no
        // password to ask for, so it is named rather than attempted.
        guard flags & 0x0001 == 0 else { throw ZipReadFailure.unsupported("an encrypted archive") }

        let method = try integer(data, at: offset + 10, UInt16.self)
        let crc = try integer(data, at: offset + 16, UInt32.self)
        let compressed = Int(try integer(data, at: offset + 20, UInt32.self))
        let uncompressed = Int(try integer(data, at: offset + 24, UInt32.self))
        let nameLength = Int(try integer(data, at: offset + 28, UInt16.self))
        let extraLength = Int(try integer(data, at: offset + 30, UInt16.self))
        let commentLength = Int(try integer(data, at: offset + 32, UInt16.self))
        let localOffset = Int(try integer(data, at: offset + 42, UInt32.self))

        let nameStart = offset + 46
        guard nameStart + nameLength <= data.count else { throw ZipReadFailure.corrupt }
        let nameData = data.subdata(in: (data.startIndex + nameStart)..<(data.startIndex + nameStart + nameLength))
        guard let name = String(data: nameData, encoding: .utf8) else { throw ZipReadFailure.corrupt }
        let next = nameStart + nameLength + extraLength + commentLength

        // A ZIP64 entry stores 0xFFFFFFFF here and the real value in the extra field. Refused for the
        // same reason as the ZIP64 EOCD, and caught per-entry because a mixed archive is possible.
        if compressed == Int(UInt32.max) || uncompressed == Int(UInt32.max) || localOffset == Int(UInt32.max) {
            throw ZipReadFailure.unsupported("ZIP64")
        }
        guard name.hasSuffix("/") == false else { return (nil, next) }
        guard isSafe(name) else { throw ZipReadFailure.corrupt }

        return (ZipEntry(path: name, uncompressedSize: uncompressed, compressedSize: compressed,
                         method: method, crc32: crc, localHeaderOffset: localOffset), next)
    }

    /// Whether a stored path may be used to name a file on disk.
    ///
    /// **A restore writes take audio and reference pictures out of this zip**, so a path is an
    /// instruction to create a file. An absolute path or a `..` component in a zip is the oldest
    /// directory-traversal trick there is, and the archive door reads files the app did not write in
    /// this installation — which is exactly the case the check exists for, even when the file is the
    /// player's own.
    private static func isSafe(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\\"), !path.contains("\0") else { return false }
        return !path.split(separator: "/").contains("..")
    }

    /// Raw DEFLATE, via `libcompression`.
    ///
    /// `COMPRESSION_ZLIB` is Apple's name for RFC 1951 raw deflate — no zlib header, which is what a
    /// zip entry holds. The destination is sized from the central directory's uncompressed length, so
    /// there is no growing buffer: the caller has already been told how big the answer is, and a
    /// mismatch is checked by `data(for:)` rather than trusted.
    ///
    /// An entry that legitimately decompresses to nothing skips the call: `compression_decode_buffer`
    /// returns 0 for both an empty result and a failure, so an empty destination cannot tell them
    /// apart.
    static func inflate(_ payload: Data, to size: Int) throws -> Data {
        guard size > 0 else { return Data() }
        var output = Data(count: size)
        let written = output.withUnsafeMutableBytes { destination -> Int in
            payload.withUnsafeBytes { source -> Int in
                guard let destinationBase = destination.bindMemory(to: UInt8.self).baseAddress,
                      let sourceBase = source.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(destinationBase, size,
                                                 sourceBase, payload.count,
                                                 nil, COMPRESSION_ZLIB)
            }
        }
        guard written == size else { throw ZipReadFailure.corrupt }
        return output
    }

    /// CRC-32, the one the zip format has carried since the beginning.
    ///
    /// Checked on every entry rather than skipped as belt-and-braces. A corrupt `practice.json` fails
    /// to decode and says so; a corrupt `.m4a` lands silently and is discovered months later when the
    /// take will not play — and a take is the one thing in an archive that cannot be recreated
    /// (ADR 0151). The table is built once per process.
    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc = (crc >> 8) ^ crcTable[Int((crc ^ UInt32(byte)) & 0xFF)]
        }
        return crc ^ 0xFFFF_FFFF
    }

    private static let crcTable: [UInt32] = (0..<256).map { index -> UInt32 in
        var value = UInt32(index)
        for _ in 0..<8 {
            value = (value & 1) == 1 ? (value >> 1) ^ 0xEDB8_8320 : value >> 1
        }
        return value
    }
}
