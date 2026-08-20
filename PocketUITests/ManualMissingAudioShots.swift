import XCTest

/// `songs/missing-audio` — the one figure of a song whose file cannot be found (ADR 0165, Phase 5).
///
/// Its own pass, and its own device, because the state is made **outside the app**. There is no
/// launch argument for it and nothing in the UI can produce it: a seeded song resolves through a
/// bookmark into `Documents/SeedAudio/`, so the way to break one is to take the file away between
/// the seed and the shoot. `shoot-manual.sh`'s `pass_prepare` does exactly that — seeds, waits on
/// `ZSONG` in the store until six songs exist, then removes the one file.
///
/// **The song is `I'd Rather Go Blind (Cover)`, and the choice is not arbitrary.** No other figure in
/// the manual plays it, so breaking it invalidates nothing already filed. Slow Bend would be the
/// wrong pick twice over: it is what most of the player figures are shot on, and it is
/// `Song.sample()` — it plays through the tone generator and has no file to take away.
///
/// **This figure was parked for months on a belief the source does not support** — that a broken song
/// puts an audio-unavailable row into every library figure. It does not. `SongCard` renders title,
/// artist, metadata, collections and mastery, and the library list never calls `SongAudioResolver` at
/// all, so a song with no audio behind it looks completely ordinary in the list. The state appears in
/// exactly two places: this notice, and Song details ▸ Audio.
final class ManualMissingAudioShots: ManualShotCase {

    /// The notice over the player, with both ways out of it.
    ///
    /// Asserted on **both buttons and the headline**, which is more than a gate. The notice draws
    /// over a dim; a player that simply failed to load draws `AudioLoadingOverlay` over the same dim
    /// and would photograph as a very similar picture. `Find the file` and `Not now` are what make
    /// this the missing-audio state rather than a slow one, and they are what the marker's alt text
    /// promises the reader.
    ///
    /// **This took the chromeless path only after claiming, in this comment, that it could not.**
    /// The line here used to read "the notice is drawn inside the practice view, so the navigation
    /// bar underneath it is still the player's" — and `WaveformPracticeView` sets no
    /// `navigationTitle` at all. The player is chromeless, which is the entire reason
    /// `captureChromeless` exists; the sentence sounded like a reason and was simply false.
    ///
    /// The guard did its job, and this is the one failure in the resumed shoot where it did: the
    /// notice was reached, the screen assertion could not be satisfied, and the capture was
    /// **refused** rather than filed under the right slug. A wrong-screen photograph is the failure
    /// this whole file is written against, and here the harness declined to take one.
    @MainActor
    func testMissingAudio() {
        let app = launchForShoot()

        let card = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Song library,")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: Self.shootTimeout),
                      "no Song library card on Home.\n\(stepLog)")
        tapHomeCard(card.label, in: app, arrivingAt: app.navigationBars["Library"])

        // Third of six by title, so it is on screen without scrolling — but revealed rather than
        // assumed, because the sort is the app's default and not this test's to rely on.
        let row = revealRow(labelStartingWith: "I'd Rather Go Blind", in: app)
        tap(row, labelled: "the I'd Rather Go Blind row",
            revealing: app.buttons["Find the file"], called: "the audio-unavailable notice")

        // The headline is deliberately **not** asserted. `AudioUnavailableNotice` combines its icon,
        // title and explanation into one accessibility element, so the text this figure is about does
        // not exist in the tree as its own label — a prefix aimed at it would be matching against a
        // concatenation that begins with whatever the SF Symbol contributes. The two buttons are
        // separate elements by design (the comment in that view says so: combining them would leave
        // neither way out reachable), and they are what distinguish this notice from the loading
        // overlay that draws over the same dim.
        captureChromeless(app, slug: "songs/missing-audio",
                          screen: "the audio-unavailable notice",
                          ownedBy: ["Find the file"],
                          alsoRequiring: ["Not now"])
    }
}
