import XCTest
@testable import Pocket

/// The Audio section's file line (ADR 0152). Pure, and the one part of the new replace door that
/// can rot silently: it reads the three custody states ADR 0148 left behind — an owned copy, a
/// legacy in-place bookmark, and nothing at all — and a wrong answer here is a player told their
/// audio is fine when it isn't (or missing when it plays).
///
/// The replace *operation* is `SongRelinker`'s, and is covered where it can be: `SongRelinkerTests`
/// pins the length-mismatch rule, `SongFileStoreTests` pins that replacing twice for one `sourceID`
/// overwrites rather than accumulates, and `SongAudioResolverTests` pins that the `sourceID` the
/// loops hang off never moves.
final class SongAudioLabelTests: XCTestCase {

    func testAnOwnedCopyShowsItsFormatAndSize() {
        let label = SongAudioLabel.describe(audioFileName: "ABC-123.mp3",
                                            hasBookmark: false, sizeInBytes: 8_400_000,
                                            copyExists: true)
        XCTAssertTrue(label.hasPrefix("MP3 · "), label)
    }

    func testTheFormatIsUppercasedFromTheLeafExtension() {
        // `SongFileStore.fileName` preserves the source extension precisely because the decoder
        // picks a parser by it, so this is the one honest thing the leaf name still tells us.
        let label = SongAudioLabel.describe(audioFileName: "ABC-123.m4a",
                                            hasBookmark: false, sizeInBytes: 1, copyExists: true)
        XCTAssertTrue(label.hasPrefix("M4A · "), label)
    }

    /// **Amended by ADR 0182.** This used to read "size unreadable means the copy is gone", which
    /// conflated two states and got the important one wrong. The file being *present but unmeasurable*
    /// is this case, and naming the format is still the honest half.
    func testAPresentCopyWhoseFileCannotBeSizedStillNamesItsFormat() {
        XCTAssertEqual(SongAudioLabel.describe(audioFileName: "ABC-123.wav", hasBookmark: false,
                                               sizeInBytes: nil, copyExists: true), "WAV")
    }

    /// The state the old signature could not express, and the one that matters: the song claims a
    /// copy and the copy is gone. `SongAudioResolver` falls through to the bookmark here, so the
    /// label must too — anything else tells a player their audio is fine when the screen won't play.
    func testAClaimedCopyThatIsNotOnDiskReadsAsMissing() {
        XCTAssertEqual(SongAudioLabel.describe(audioFileName: "ABC-123.wav", hasBookmark: false,
                                               sizeInBytes: nil, copyExists: false), "Missing")
    }

    /// Same absent copy, but a legacy bookmark is still on the row — which is exactly what the
    /// resolver will fall back to, so the label reports what will actually play.
    func testAClaimedCopyThatIsNotOnDiskFallsBackToTheBookmark() {
        XCTAssertEqual(SongAudioLabel.describe(audioFileName: "ABC-123.wav", hasBookmark: true,
                                               sizeInBytes: nil, copyExists: false), "Linked file")
    }

    func testAnExtensionlessCopyFallsBackToSizeAlone() {
        // `fileName(for:sourceExtension:)` keeps the bare id when the source had no extension,
        // rather than inventing a format it isn't — so there is no format to print.
        let label = SongAudioLabel.describe(audioFileName: "ABC-123", hasBookmark: false,
                                            sizeInBytes: 2_000_000, copyExists: true)
        XCTAssertFalse(label.contains("·"), label)
        XCTAssertFalse(label.isEmpty)
    }

    func testAnExtensionlessCopyWithNoSizeStillSaysSomething() {
        XCTAssertEqual(SongAudioLabel.describe(audioFileName: "ABC-123", hasBookmark: false,
                                               sizeInBytes: nil, copyExists: true),
                       "In your library")
    }

    func testALegacyBookmarkWithNoCopyReadsAsLinked() {
        // Pre-0148 and not yet adopted (§3): it plays, but the file lives outside our container.
        XCTAssertEqual(SongAudioLabel.describe(audioFileName: nil, hasBookmark: true,
                                               sizeInBytes: nil, copyExists: false), "Linked file")
    }

    func testNoCopyAndNoBookmarkReadsAsMissing() {
        // Nothing left to resolve — the state relink exists to repair.
        XCTAssertEqual(SongAudioLabel.describe(audioFileName: nil, hasBookmark: false,
                                               sizeInBytes: nil, copyExists: false), "Missing")
    }

    func testAnOwnedCopyBeatsALingeringBookmark() {
        // The preference order is the whole point of ADR 0148 — the copy wins even when a bookmark
        // is still on the row (§5 keeps it deliberately). The label must not report the bookmark.
        let label = SongAudioLabel.describe(audioFileName: "ABC-123.mp3", hasBookmark: true,
                                            sizeInBytes: 500_000, copyExists: true)
        XCTAssertFalse(label.contains("Linked"), label)
    }
}
