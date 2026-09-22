import Foundation

/// The **starter track** (ADR 0219): one song that ships inside the app so a player who has
/// imported nothing still has something to practise on.
///
/// **This is not `Song.sample()`.** That is a fabricated metadata record ("Slow Bend") with a
/// generated arpeggio behind it (`SampleToneGenerator`), and it exists so previews,
/// `ScreenshotSeed` and roughly twenty manual figures have something stable to point at. It is
/// preview scaffolding, and thirty seconds of synthesised arpeggio cannot carry *"loop the part
/// you want to play"*. The two are easy to conflate and must not be: `Song.sample()` stays exactly
/// where it is, and nothing here replaces it.
///
/// *Binta* is a real eighty-one-second recording, the author's own composition, so nothing in it is
/// licensed from anyone — the point ADR 0148 §7's own 2026-08-09 correction had already conceded
/// before this ADR unparked it.
///
/// **It arrives by tap, never by seeding.** ADR 0011 retired the first-run auto-seed, and ADR 0148
/// §7 objected that "every player receives the same song, which none of them chose". A song the
/// player asked for answers both, so nothing inserts this at launch.
///
/// Foundation-only on purpose: `AccessPolicy` keys the free taste on `sourceID` and must stay pure
/// (AGENTS.md). The insert lives in `SongImporter.importStarterTrack(into:)`, which runs the same
/// `SongFileStore.adopt` + `WaveformExtractor` path every real import runs.
enum StarterTrack {

    /// The frozen `SongRef.id`.
    ///
    /// **Never change this.** Two things key on it and neither migrates cheaply:
    /// `AccessPolicy.canPractiseSong` decides the free taste from it, and `SongFileStore` names the
    /// adopted copy after it — so a renamed id would orphan the file on disk *and* re-lock the song
    /// for every player who already has one. A frozen identifier, exactly like `Exercise.presetSlug`.
    static let sourceID = "starter-binta"

    /// Bundled resource name and extension, split so `bundledURL` and any diagnostic that reports a
    /// missing file name the same thing.
    static let resourceName = "Binta"
    static let resourceExtension = "m4a"

    // Metadata mirrors `ScreenshotSeed`'s entry for this same recording, so the track reads
    // identically whether it arrives here or in a shoot. Deliberately **no loops and no markers**:
    // making the first loop is the player's job (ADR 0149's first beat), and a song that arrived
    // pre-looped would answer the question the walkthrough exists to ask.
    static let title = "Binta"
    static let artist = "Jack Trader"
    static let genre = "Afrobeat"
    static let key = "F# Minor"
    static let bpm = 104

    /// The bundled file, or `nil` if it was dropped from the target.
    ///
    /// Optional rather than a force-unwrap: a missing starter track is a degraded first run, not a
    /// reason to take the app down in front of the one player least invested in staying.
    static var bundledURL: URL? {
        Bundle.main.url(forResource: resourceName, withExtension: resourceExtension)
    }
}
