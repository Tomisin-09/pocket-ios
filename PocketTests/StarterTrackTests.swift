import XCTest
@testable import Pocket

/// The bundled **starter track** (ADR 0219) — its frozen identity, and the `Song`-level derivation
/// the free taste reads.
///
/// **What is deliberately not tested here: that the audio file is actually in the app bundle.**
/// `PocketTests` is an unhosted unit-test bundle (no `TEST_HOST` in `project.yml`), so `Bundle.main`
/// in this process is the xctest runner and `StarterTrack.bundledURL` is `nil` here for reasons that
/// have nothing to do with whether the resource shipped. A test asserting `nil` would pass on a
/// build that dropped the file and one that kept it, which is worse than no test — it would read as
/// coverage. The resource is checked where it can be: the build copies it into `Pocket.app`, and
/// `SongImporter.prepareStarterTrack` throws `.starterTrackMissing` rather than trapping if it ever
/// goes missing at runtime.
final class StarterTrackTests: XCTestCase {

    /// **The id is frozen.** `SongFileStore` names the adopted copy after it and
    /// `AccessPolicy.canPractiseSong` decides the free taste from it, so changing it would orphan
    /// the file on disk *and* silently re-lock the song for every player who already has one. The
    /// literal is repeated here on purpose: this test exists to make that change fail loudly, and a
    /// test written as `XCTAssertEqual(StarterTrack.sourceID, StarterTrack.sourceID)` would not.
    func testSourceIDIsFrozen() {
        XCTAssertEqual(StarterTrack.sourceID, "starter-binta")
    }

    /// The resource lookup is named in one place, so a rename of the file has exactly one thing to
    /// keep in step.
    func testResourceIsNamedOnce() {
        XCTAssertEqual(StarterTrack.resourceName, "Binta")
        XCTAssertEqual(StarterTrack.resourceExtension, "m4a")
    }

    // MARK: - Song.isStarterTrack

    /// Uninserted `@Model` objects on purpose — inserting into a container inside the XCTest host is
    /// a trap this project has already paid for, and none of these assertions needs persistence.
    private func makeSong(id: String, title: String = "Anything") -> Song {
        Song(title: title, duration: 81,
             ref: SongRef(id: id, source: .localFile, bookmark: nil),
             audioFileName: "\(id).m4a")
    }

    func testTheStarterTrackRecognisesItself() {
        XCTAssertTrue(makeSong(id: StarterTrack.sourceID).isStarterTrack)
    }

    func testAnImportedSongIsNotTheStarterTrack() {
        XCTAssertFalse(makeSong(id: UUID().uuidString).isStarterTrack)
    }

    /// **Renaming the song must not change what it costs.** `Song.title` is user-editable, so
    /// deriving the free taste from the title either lets a player mint a free song by typing
    /// "Binta" over one, or takes the starter track away from someone who renamed it. Both
    /// directions are checked, because the two failures are opposite and a title-keyed
    /// implementation only fails one of them.
    func testEntitlementFollowsTheIDNotTheTitle() {
        let renamedStarter = makeSong(id: StarterTrack.sourceID, title: "My warm-up")
        XCTAssertTrue(renamedStarter.isStarterTrack,
                      "Renaming the starter track must not take it away")

        let impostor = makeSong(id: UUID().uuidString, title: StarterTrack.title)
        XCTAssertFalse(impostor.isStarterTrack,
                       "Calling an imported song Binta must not make it free")
    }

    /// The starter track carries an owned copy and no bookmark, and that combination must still
    /// read as real audio — `hasImportedAudio` is the branch `WaveformPracticeModel.loadAudio`
    /// takes, and the `else` side of it plays the generated arpeggio. Getting this wrong would ship
    /// a starter track that sounds like `SampleToneGenerator`.
    func testTheStarterTrackReadsAsImportedAudioDespiteHavingNoBookmark() {
        let song = makeSong(id: StarterTrack.sourceID)
        XCTAssertNil(song.bookmark)
        XCTAssertNotNil(song.audioFileName)
        XCTAssertTrue(song.hasImportedAudio)
    }

    /// `Song.sample()` is preview scaffolding, not the starter track, and the two must never be
    /// conflated — they have different audio, different provenance and different entitlement.
    func testTheGeneratedSampleIsNotTheStarterTrack() {
        let sample = Song.sample()
        XCTAssertFalse(sample.isStarterTrack)
        XCTAssertNotEqual(sample.sourceID, StarterTrack.sourceID)
        XCTAssertFalse(sample.hasImportedAudio, "The sample still has no file behind it")
    }
}
