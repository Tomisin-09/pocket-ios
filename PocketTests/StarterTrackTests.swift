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

    // MARK: - The song knows itself (ADR 0220)

    /// Binta is eighty-one seconds; the grid below is drawn across that span.
    private let duration: TimeInterval = 81

    /// The measured figures, repeated as literals for the same reason `testSourceIDIsFrozen` repeats
    /// its: they were measured off the audio (D1), and a change to either has to be a deliberate
    /// re-measurement rather than an edit that the rest of the suite silently follows.
    func testTempoAndDownbeatAreTheMeasuredFigures() {
        XCTAssertEqual(StarterTrack.bpm, 83, "104 was wrong from the day ADR 0219 merged")
        XCTAssertEqual(StarterTrack.preciseBPM, 83.0)
        XCTAssertEqual(StarterTrack.downbeatSeconds, 0.027, accuracy: 1e-9)
        XCTAssertEqual(StarterTrack.beatsPerBar, 4)
        XCTAssertEqual(StarterTrack.noteValue, 4)
        XCTAssertEqual(StarterTrack.bpm, Int(StarterTrack.preciseBPM.rounded()),
                       "The display tempo must be the precise one rounded, or the readout and the grid disagree")
    }

    /// The positions ADR 0220 publishes in its D2 and D3 tables, to the millisecond. The code
    /// derives them from `barStart`; this checks that derivation lands where the ADR says it does.
    func testSignpostsLandWhereTheADRSays() {
        XCTAssertEqual(StarterTrack.chordsStart.seconds, 23.160, accuracy: 0.001)
        XCTAssertEqual(StarterTrack.soloStart.seconds, 34.726, accuracy: 0.001)
        XCTAssertEqual(StarterTrack.leadInSeconds, 17.376, accuracy: 0.001)
        XCTAssertEqual(StarterTrack.signposts.map(\.label), ["Chords start", "Solo start"])
    }

    /// **The signposts sit on bar lines the grid actually draws**, not beside them (D2). Checked
    /// against `BeatGrid` rather than against `barStart` again, because `barStart` agreeing with
    /// itself proves nothing — the point is that the markers, the loop edges the player's taps will
    /// land on, and the lines on screen are the same instants.
    func testSignpostsSitOnTheGridsBarLines() {
        let barLines = BeatGrid.beats(bpm: StarterTrack.preciseBPM, duration: duration,
                                      downbeat: StarterTrack.downbeatSeconds,
                                      beatsPerBar: StarterTrack.beatsPerBar)
            .filter(\.isDownbeat)
            .map { $0.fraction * duration }
        XCTAssertFalse(barLines.isEmpty, "A grid that draws nothing would pass every check below")

        for seconds in StarterTrack.signposts.map(\.seconds) + [StarterTrack.leadInSeconds] {
            let nearest = barLines.min { abs($0 - seconds) < abs($1 - seconds) } ?? .infinity
            XCTAssertEqual(nearest, seconds, accuracy: 1e-6, "\(seconds)s is off the grid")
        }
    }

    /// The span between the two signposts is the author's own Chords loop — four bars, sixteen
    /// beats. Their hand-made loop, pulled off their phone on 2026-09-24, ran 23.168 → 34.731 s;
    /// with the measured downbeat it sits within 8 ms of bar 9 and 5 ms of bar 13 (D1). If a tempo
    /// or downbeat change drags the signposts off the passage the ADR chose, this is what notices.
    func testTheSignpostsBracketTheAuthorsChordsLoop() {
        XCTAssertEqual(StarterTrack.soloStart.bar - StarterTrack.chordsStart.bar, 4)
        let beats = (StarterTrack.soloStart.seconds - StarterTrack.chordsStart.seconds)
            * StarterTrack.preciseBPM / 60
        XCTAssertEqual(beats, 16, accuracy: 1e-9)

        XCTAssertEqual(StarterTrack.chordsStart.seconds, 23.168, accuracy: 0.010)
        XCTAssertEqual(StarterTrack.soloStart.seconds, 34.731, accuracy: 0.010)
        XCTAssertEqual(StarterTrack.chordsStart.bar - StarterTrack.leadInBar, 2,
                       "The lead-in is two bars, so the section is heard arriving (D3)")
        XCTAssertLessThan(StarterTrack.soloStart.seconds, duration)
    }

    /// Adoption writes everything the song should know, and **still no loop** — the first loop is
    /// the player's to make (ADR 0219 D1, kept by 0220).
    func testSignpostingWritesTheMeasuredValuesAndTwoMarkers() {
        let song = makeSong(id: StarterTrack.sourceID)
        song.showsGridlines = false        // prove the write, not the declaration default

        SongImporter.signpostStarterTrack(song)

        XCTAssertEqual(song.artist, "Jack Trader")
        XCTAssertEqual(song.key, "F# Minor")
        XCTAssertEqual(song.bpm, 83)
        XCTAssertEqual(song.tempoBPM, 83.0)
        XCTAssertEqual(song.downbeatAnchors, [StarterTrack.downbeatSeconds])
        XCTAssertEqual(song.beatsPerBar, 4)
        XCTAssertEqual(song.noteValue, 4)
        XCTAssertTrue(song.showsGridlines)
        XCTAssertEqual(song.markersByTime.map(\.label), ["Chords start", "Solo start"])
        XCTAssertEqual(song.markersByTime.map(\.seconds),
                       [StarterTrack.chordsStart.seconds, StarterTrack.soloStart.seconds])
        XCTAssertTrue(song.loops.isEmpty, "A song that arrived pre-looped answers beat 1 for them")
    }
}
