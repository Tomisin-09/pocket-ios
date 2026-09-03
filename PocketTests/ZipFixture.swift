import Foundation
@testable import Pocket

/// A tiny zip **writer**, for the shapes the real exporter will never produce (ADR 0188 D8).
///
/// `ZipArchiveReaderTests` reads real exports for everything a real export can demonstrate, which is
/// the requirement D8 states. This exists for the complement: a traversal path, an encryption flag, a
/// compression method nobody uses. Those are the cases the reader refuses, and there is no way to ask
/// `ArchiveWriter` for one — so the only alternatives were a hand-built zip here or a checked-in
/// binary fixture whose contents nobody can read in a diff.
///
/// Stored entries only. It is a test double for malformed input, not a second implementation of
/// zipping, and it deliberately cannot do anything the reader is meant to accept on the happy path.
enum ZipFixture {

    /// Build a zip holding `entries`, keyed by path.
    ///
    /// - Parameter generalPurposeFlags: written into both headers verbatim, so a test can set bit 0
    ///   and get a file that claims to be encrypted.
    static func zip(entries: [String: Data], generalPurposeFlags: UInt16 = 0) throws -> Data {
        var output = Data()
        var directory = Data()
        var count: UInt16 = 0

        for (path, payload) in entries.sorted(by: { $0.key < $1.key }) {
            let offset = UInt32(output.count)
            output.append(localHeader(path: path, payload: payload, flags: generalPurposeFlags))
            output.append(payload)
            directory.append(directoryRecord(path: path, payload: payload,
                                             flags: generalPurposeFlags, offset: offset))
            count += 1
        }

        let directoryOffset = UInt32(output.count)
        output.append(directory)
        output.append(little: UInt32(0x0605_4b50))           // end of central directory
        output.append(little: UInt16(0))                     // this disk
        output.append(little: UInt16(0))                     // disk with directory start
        output.append(little: count)
        output.append(little: count)
        output.append(little: UInt32(directory.count))
        output.append(little: directoryOffset)
        output.append(little: UInt16(0))                     // comment length
        return output
    }

    /// The 30-byte local header that sits immediately before an entry's bytes.
    private static func localHeader(path: String, payload: Data, flags: UInt16) -> Data {
        let name = Data(path.utf8)
        var header = Data()
        header.append(little: UInt32(0x0403_4b50))           // local file header signature
        header.append(little: UInt16(20))                    // version needed
        header.append(little: flags)
        header.append(little: UInt16(0))                     // method: stored
        header.append(little: UInt16(0))                     // mod time
        header.append(little: UInt16(0))                     // mod date
        header.append(little: ZipArchiveReader.crc32(payload))
        header.append(little: UInt32(payload.count))         // compressed size
        header.append(little: UInt32(payload.count))         // uncompressed size
        header.append(little: UInt16(name.count))
        header.append(little: UInt16(0))                     // extra length
        header.append(name)
        return header
    }

    /// The 46-byte central-directory record, which is what the reader actually parses.
    private static func directoryRecord(path: String, payload: Data,
                                        flags: UInt16, offset: UInt32) -> Data {
        let name = Data(path.utf8)
        var record = Data()
        record.append(little: UInt32(0x0201_4b50))           // central directory signature
        record.append(little: UInt16(20))                    // version made by
        record.append(little: UInt16(20))                    // version needed
        record.append(little: flags)
        record.append(little: UInt16(0))                     // method: stored
        record.append(little: UInt16(0))                     // mod time
        record.append(little: UInt16(0))                     // mod date
        record.append(little: ZipArchiveReader.crc32(payload))
        record.append(little: UInt32(payload.count))
        record.append(little: UInt32(payload.count))
        record.append(little: UInt16(name.count))
        record.append(little: UInt16(0))                     // extra length
        record.append(little: UInt16(0))                     // comment length
        record.append(little: UInt16(0))                     // disk number start
        record.append(little: UInt16(0))                     // internal attributes
        record.append(little: UInt32(0))                     // external attributes
        record.append(little: offset)
        record.append(name)
        return record
    }
}

private extension Data {
    /// Append a fixed-width integer little-endian, which is how every field in a zip is stored.
    mutating func append<T: FixedWidthInteger>(little value: T) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
