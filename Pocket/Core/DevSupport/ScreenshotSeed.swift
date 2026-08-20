#if DEBUG
import Foundation
import SwiftData

/// DEBUG-only, opt-in library seed for App Store screenshot shoots.
///
/// Normal launches are untouched: this runs **only** when the app is launched with
/// the `-seedScreenshots` argument (Scheme › Arguments, or `simctl launch … -seedScreenshots`).
/// It builds a small, realistic guitarist's library so the content-dependent shots
/// (loop trainer, library) have real material without fighting the document picker.
///
/// Real audio: drop `.mp3`/`.m4a` files into the app's `Documents/SeedAudio/` folder
/// (copy them in from the Mac via `simctl get_app_container … data`). Each is imported
/// with a genuine extracted waveform + bookmark, so it renders like a real import.
/// The bundled `Song.sample()` ("Slow Bend") is added too — it plays via the tone
/// generator and ships with loops, so it drives the "loop playing" hero shot.
///
/// Idempotent: skips entirely if the library already has songs.
enum ScreenshotSeed {

    /// One loop to attach to a seeded song. `start`/`end` are fractions of duration;
    /// `mastery` is 0–5. Positional init keeps the metadata table compact.
    ///
    /// **Every track is our own, and the three standards are labelled `(Cover)`.** This seed is
    /// `#if DEBUG` and never ships, but its output is photographs and those images are published:
    /// the library figures show every row with its artist. Three real musicians were named here
    /// until 2026-08-20 — which was defensible (a title is not copyrightable, and an app whose
    /// whole premise is your own files may fairly depict a library holding them) but is simply
    /// not worth arguing, so the rows now say what they are: Jack Trader playing covers.
    ///
    /// **These keys are filenames.** `importReal` takes the title from the staged file's name, so
    /// a key here that no master matches gets no metadata at all — the song imports with a blank
    /// artist and no loops, which reads in a figure as a bug in the app rather than a gap in the
    /// seed. Rename the masters in `POCKET_SEED_AUDIO` and these keys in the same commit.
    private struct LoopSpec {
        let name: String
        let start: Double
        let end: Double
        let speed: Double
        let repeats: Int
        let mastery: Int
        init(_ name: String, _ start: Double, _ end: Double,
             _ speed: Double, _ repeats: Int, _ mastery: Int) {
            self.name = name
            self.start = start
            self.end = end
            self.speed = speed
            self.repeats = repeats
            self.mastery = mastery
        }
    }

    /// Metadata applied to a seeded real-file song, keyed by the imported title
    /// (filename without extension). Titles not listed still import with sensible defaults.
    private struct Meta {
        let artist: String
        let genre: String
        let bpm: Int
        let key: String
        let collections: [String]
        let loops: [LoopSpec]
    }

    private static let metadata: [String: Meta] = [
        "Red Moon (Cover)": Meta(
            artist: "Jack Trader", genre: "Neo-Soul", bpm: 92, key: "D Major",
            collections: ["solos", "chill"],
            loops: [
                LoopSpec("Main lick", 0.30, 0.44, 1.0, 4, 3),
                LoopSpec("Outro turnaround", 0.68, 0.79, 0.75, 3, 2)
            ]),
        "I Don't Trust Myself With Loving You (Cover)": Meta(
            artist: "Jack Trader", genre: "Blues", bpm: 80, key: "C# Minor",
            collections: ["blues", "solos"],
            loops: [LoopSpec("Intro riff", 0.05, 0.18, 0.75, 6, 4)]),
        "I'd Rather Go Blind (Cover)": Meta(
            artist: "Jack Trader", genre: "Blues", bpm: 68, key: "C Major",
            collections: ["blues", "needs-work"],
            loops: [LoopSpec("Verse phrasing", 0.22, 0.36, 0.75, 4, 1)]),
        // Jack Trader's two tracks round the library out to five. Without entries here
        // they import with a blank artist, which reads as a bug in the library shot
        // rather than as a real library.
        "Binta": Meta(
            artist: "Jack Trader", genre: "Afrobeat", bpm: 104, key: "F# Minor",
            collections: ["chill"],
            loops: [LoopSpec("Head", 0.12, 0.27, 1.0, 4, 2)]),
        "Feels": Meta(
            artist: "Jack Trader", genre: "Neo-Soul", bpm: 88, key: "A Minor",
            collections: ["chill", "needs-work"],
            loops: [LoopSpec("Chorus lift", 0.34, 0.48, 0.75, 5, 3)])
    ]

    static let launchArgument = "-seedScreenshots"

    /// Whether this launch is a screenshot shoot — App Store or user manual.
    ///
    /// Read by anything that is *correct in a Debug build but false in a photograph of the app*. The
    /// Settings hub's **Developer** row is the case that named this: it is `#if DEBUG` and therefore
    /// present in every build a shoot can drive, but it ships to nobody, and a manual figure carrying
    /// it shows a tenth destination the page beside it does not document. A screenshot is a claim
    /// about the shipping app, so the shoot has to be able to say "not this".
    ///
    /// Deliberately narrow: this is not a general "hide things in Debug" switch. Anything gated on it
    /// must be absent from the release build too, or the figure starts lying in the other direction.
    static var isShooting: Bool {
        CommandLine.arguments.contains(launchArgument)
    }

    /// Seed the library if launched with `-seedScreenshots` and it's currently empty.
    @MainActor
    static func seedIfNeeded(into context: ModelContext) {
        guard CommandLine.arguments.contains(launchArgument) else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<Song>())) ?? 0
        guard existing == 0 else { return }

        // Playable hero: Slow Bend (tone-generator audio + pre-made loops).
        context.insert(Song.sample())

        // Real-file imports with genuine waveforms, in a stable display order.
        for url in seedAudioURLs() {
            importReal(url, into: context)
        }
        try? context.save()
    }

    /// `.mp3`/`.m4a`/`.wav` files staged in `Documents/SeedAudio/`, sorted by name.
    private static func seedAudioURLs() -> [URL] {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return [] }
        let dir = docs.appendingPathComponent("SeedAudio", isDirectory: true)
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil)) ?? []
        let audioExt: Set<String> = ["mp3", "m4a", "wav", "aac", "aif", "aiff"]
        return contents
            .filter { audioExt.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Import one owned file: extract its waveform (the app owns `Documents`, so no
    /// security scope is needed to read it), take a bookmark, and attach metadata + loops.
    @MainActor
    private static func importReal(_ url: URL, into context: ModelContext) {
        let title = url.deletingPathExtension().lastPathComponent
        guard let (duration, amplitudes) = try? WaveformExtractor.extract(from: url),
              let bookmark = try? url.bookmarkData()
        else { return }

        let meta = metadata[title]
        let song = Song(
            title: title, artist: meta?.artist ?? "", genre: meta?.genre ?? "",
            key: meta?.key ?? "", bpm: meta?.bpm,
            collections: meta?.collections ?? [],
            duration: duration, amplitudes: amplitudes, dateAdded: .now,
            ref: .localFile(bookmark: bookmark))

        if let specs = meta?.loops {
            let loops = specs.map { spec -> Loop in
                let loop = Loop(name: spec.name, start: spec.start, end: spec.end,
                                speed: spec.speed, repeats: spec.repeats)
                loop.mastery = spec.mastery
                return loop
            }
            song.loops = loops
            for loop in loops where loop.song == nil { loop.song = song }
        }
        context.insert(song)
    }
}
#endif
