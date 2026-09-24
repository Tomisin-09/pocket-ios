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
    // identically whether it arrives here or in a shoot. Deliberately **no loops**: making the first
    // loop is the player's job (ADR 0149's first beat), and a song that arrived pre-looped would
    // answer the question the walkthrough exists to ask. Markers are a different matter — see
    // `signposts`.
    static let title = "Binta"
    static let artist = "Jack Trader"
    static let genre = "Afrobeat"
    static let key = "F# Minor"

    // MARK: - Tempo and downbeat (ADR 0220 D1)

    /// The author's figure; the click holds to the end of the song by ear on device. **Was 104**
    /// until ADR 0220 — wrong from the day 0219 merged, and `ScreenshotSeed` with it.
    static let bpm = 83
    static let preciseBPM = 83.0

    /// Where bar 1, beat 1 lands: **measured, not guessed.** Binta opens on about two seconds of
    /// drums alone, so the kick is the only low-frequency event and its onsets are unambiguous; a
    /// kick-band filter and the full band agree to within 2 ms. Every hit in that window sits the
    /// same ~0.04 beats after its grid position, which is what a correct tempo with a late origin
    /// looks like.
    ///
    /// **Re-measure this if the resource is ever re-encoded** — the figure belongs to the 128 kbps
    /// file ADR 0219 D8 shipped, and calibrate on the drums-only intro: past bar 8 the bass shares
    /// the kick's band, and an earlier pass that measured there read bass notes as kicks.
    static let downbeatSeconds: TimeInterval = 0.027

    static let beatsPerBar = 4
    static let noteValue = 4

    /// Where bar `bar` (1-based) begins, in seconds. The single formula every position below is
    /// derived from, so the markers, the lead-in, the grid lines and the click agree by
    /// construction rather than by three literals happening to match.
    static func barStart(_ bar: Int) -> TimeInterval {
        downbeatSeconds + Double(bar - 1) * Double(beatsPerBar) * 60 / preciseBPM
    }

    // MARK: - Signposts (ADR 0220 D2, D5)

    /// A marker the song arrives with, named by the bar it sits on.
    struct Signpost: Equatable {
        let label: String
        let bar: Int
        var seconds: TimeInterval { StarterTrack.barStart(bar) }
    }

    /// Bars 9–12 are the author's own Chords loop — four bars, sixteen beats — and the best first
    /// loop in the song. Label text follows the app's own auto-names: sentence case, no punctuation.
    static let chordsStart = Signpost(label: "Chords start", bar: 9)
    static let soloStart = Signpost(label: "Solo start", bar: 13)

    /// Written as ordinary `Marker`s at adoption: scenery, not instructions. The player may rename,
    /// drag or delete them, so **the walkthrough reads these constants, never the `Marker`
    /// records** — a renamed marker must not break the script, and a dragged one must not be
    /// re-read as a new instruction (D5).
    static let signposts = [chordsStart, soloStart]

    /// Where the scripted first beat starts playback: two bars before `chordsStart`, so the section
    /// is heard arriving (D3).
    static let leadInBar = 7
    static var leadInSeconds: TimeInterval { barStart(leadInBar) }

    /// The bundled file, or `nil` if it was dropped from the target.
    ///
    /// Optional rather than a force-unwrap: a missing starter track is a degraded first run, not a
    /// reason to take the app down in front of the one player least invested in staying.
    static var bundledURL: URL? {
        Bundle.main.url(forResource: resourceName, withExtension: resourceExtension)
    }
}
