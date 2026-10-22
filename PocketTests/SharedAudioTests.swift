import UniformTypeIdentifiers
import XCTest
@testable import Pocket

/// **An audio file shared from another app lands as a song** (ADR 0273). What counts as audio decides
/// whether the receive door reads a file as a song or as a practice file, and the declaration in the
/// built app is what puts Red Moon in the share sheet at all. No UI test can drive another app's share
/// sheet, so both are pinned here.
final class SharedAudioTests: XCTestCase {

    // MARK: - D1: what counts as audio

    func testTheCommonAudioFilesAreAudio() {
        for ext in ["m4a", "mp3", "wav", "aif", "aiff", "caf", "flac", "M4A"] {
            XCTAssertTrue(SharedAudio.isAudio(fileExtension: ext), ext)
        }
    }

    /// The other files the same door opens must still reach their own readers.
    func testRedMoonsOwnFilesAreNotAudio() {
        XCTAssertFalse(SharedAudio.isAudio(fileExtension: PracticePack.fileExtension))
        XCTAssertFalse(SharedAudio.isAudio(fileExtension: "redmoonpractice"))
    }

    func testOtherFilesAreNotAudio() {
        for ext in ["pdf", "txt", "zip", "mp4", "mov", "jpg", ""] {
            XCTAssertFalse(SharedAudio.isAudio(fileExtension: ext), ext)
        }
    }

    /// A file the system has no record of yet is judged by its extension: the voice memo's name, as
    /// the share sheet showed it.
    func testAFileURLIsJudgedByItsName() {
        let memo = FileManager.default.temporaryDirectory.appending(path: "AUDIO-2026-10-11-04-53-45.m4a")
        XCTAssertTrue(SharedAudio.isAudio(memo))
        XCTAssertFalse(SharedAudio.isAudio(memo.deletingPathExtension().appendingPathExtension("redmoonpack")))
    }

    /// The song's title is the file's name, as **+** gives it (ADR 0148).
    func testTheSongIsTitledByItsFileName() {
        let memo = URL(filePath: "/tmp/RedMoonInbox/x/AUDIO-2026-10-11-04-53-45.m4a")
        XCTAssertEqual(SongImporter.title(for: memo), "AUDIO-2026-10-11-04-53-45")
    }

    func testTheLandingNamesTheSong() {
        XCTAssertEqual(SharedAudio.landed(title: "Lesson riff"), "“Lesson riff” is in your songs.")
    }

    // MARK: - D1: the declaration

    /// The app is a handler for every audio type, at `Alternate` rank, so it's offered and never the
    /// default. Read out of the built app: the plist is hand-maintained, and a dropped entry would
    /// take Red Moon out of every share sheet with nothing else noticing.
    func testTheAppDeclaresItselfAnAlternateHandlerForAudio() throws {
        let types = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "CFBundleDocumentTypes") as? [[String: Any]])
        let declared = [SharedAudio.declaredType.identifier]
        let audio = try XCTUnwrap(types.first { ($0["LSItemContentTypes"] as? [String]) == declared },
                                  "no CFBundleDocumentTypes entry for public.audio")
        XCTAssertEqual(audio["LSHandlerRank"] as? String, "Alternate")
        XCTAssertEqual(audio["CFBundleTypeRole"] as? String, "Viewer")
    }

    /// Red Moon's own two types are still its own.
    func testRedMoonStillOwnsItsOwnTypes() throws {
        let types = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "CFBundleDocumentTypes") as? [[String: Any]])
        let owned = types.filter { ($0["LSHandlerRank"] as? String) == "Owner" }
            .flatMap { $0["LSItemContentTypes"] as? [String] ?? [] }
        XCTAssertEqual(Set(owned), ["click.decooperations.pocket.practice", "click.decooperations.pocket.pack"])
    }
}
