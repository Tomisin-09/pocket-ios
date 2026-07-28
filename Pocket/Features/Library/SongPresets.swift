import AVFoundation
import Foundation
import SwiftData

/// The curated **demo song** seeded once on first launch, so a new install has real audio to loop
/// against before the player has imported anything of their own (ADR 0112 first-run set).
///
/// Mirrors `PracticePresets` / `RoutinePresets`: a one-time `UserDefaults` flag — not an "is the
/// library empty?" check — so **deleted stays deleted** and the demo never reappears.
///
/// **Rights.** Exactly one track ships, *Binta* by Jack Trader, used with the rights holder's
/// permission. This is the app's only bundled third-party content, and it changes the App Store
/// Connect **Content Rights** answer from "no third-party content" — that declaration must be
/// updated before the next submission. Nothing else may be added here without the same clearance
/// (the content strategy: encode the method, never ship someone else's material).
///
/// **Why copy out of the bundle.** A `Song` stores a security-scoped *bookmark* to its file, and the
/// bundle path contains an install UUID that changes on every install and update — a bookmark into
/// the bundle would dangle after the first app update. So the track is copied into `Documents/`
/// (which the app owns, and which is stable across updates) and the bookmark points there.
enum SongPresets {

    /// The bundled resource, and the metadata the seeded `Song` carries.
    enum Demo {
        static let resourceName = "binta-jack-trader"
        static let fileExtension = "m4a"
        static let title = "Binta"
        static let artist = "Jack Trader"
    }

    /// `UserDefaults` key recording that the one-time demo-song seed has run. Versioned like the
    /// other seeders so a future curated track can ship under its own key.
    static let seededDefaultsKey = "songPresetsSeeded.v1"

    /// The folder inside `Documents/` the demo track is copied to. Its own directory so the copy is
    /// distinguishable from the player's imports, and so it can be swept if the demo is ever retired.
    static let demoDirectoryName = "DemoAudio"

    /// Seed the demo song **once, ever**. Safe to call on every launch; a no-op after the first.
    ///
    /// Deliberately **not** `@MainActor`-bound work beyond the insert: the caller does the waveform
    /// extraction off the main actor and hands the result in, because decoding a multi-megabyte file
    /// on the main thread during first launch is exactly the cold-start stall the seeding comments
    /// elsewhere warn about.
    static func seedIfNeeded(into context: ModelContext,
                             defaults: UserDefaults = .standard,
                             extracted: (duration: TimeInterval, amplitudes: [Double]),
                             fileURL: URL) {
        guard !defaults.bool(forKey: seededDefaultsKey) else { return }
        guard let bookmark = try? fileURL.bookmarkData() else { return }
        let song = Song(title: Demo.title, artist: Demo.artist,
                        duration: extracted.duration, amplitudes: extracted.amplitudes,
                        dateAdded: .now,
                        ref: .localFile(bookmark: bookmark))
        context.insert(song)
        try? context.save()
        defaults.set(true, forKey: seededDefaultsKey)
    }

    /// Whether the seed still needs to run — checked before doing any file or decode work, so a
    /// returning player pays nothing for a demo they already have (or deleted).
    static func needsSeeding(defaults: UserDefaults = .standard) -> Bool {
        !defaults.bool(forKey: seededDefaultsKey)
    }

    /// Copy the bundled track into `Documents/DemoAudio/` and return its URL, or `nil` if the
    /// resource is missing (a build that dropped it — degrade quietly, never crash a launch).
    /// Idempotent: an existing copy is reused rather than overwritten.
    static func materialiseBundledTrack() -> URL? {
        guard let source = Bundle.main.url(forResource: Demo.resourceName,
                                           withExtension: Demo.fileExtension)
        else { return nil }
        guard let docs = FileManager.default.urls(for: .documentDirectory,
                                                  in: .userDomainMask).first
        else { return nil }

        let directory = docs.appendingPathComponent(demoDirectoryName, isDirectory: true)
        let destination = directory.appendingPathComponent(source.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path) { return destination }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: source, to: destination)
            return destination
        } catch {
            return nil
        }
    }

    /// The whole first-launch path, off the main actor up to the insert: copy the bundled track out,
    /// decode its waveform, then hand both to `seedIfNeeded`. Returns the pieces the caller needs so
    /// the `ModelContext` work stays on the actor that owns it.
    static func prepare() -> (extracted: (duration: TimeInterval, amplitudes: [Double]), url: URL)? {
        guard let url = materialiseBundledTrack(),
              let extracted = try? WaveformExtractor.extract(from: url)
        else { return nil }
        return (extracted, url)
    }

    /// The one call a launch site makes. Checks the flag **before** touching the filesystem, does the
    /// copy + multi-megabyte decode on a detached background task, and only then hops back to insert
    /// on the context's own actor — so first paint never waits on audio decoding.
    @MainActor
    static func seedIfNeeded(into context: ModelContext, defaults: UserDefaults = .standard) async {
        guard needsSeeding(defaults: defaults) else { return }
        guard let prepared = await Task.detached(priority: .utility, operation: prepare).value
        else { return }
        seedIfNeeded(into: context, defaults: defaults,
                     extracted: prepared.extracted, fileURL: prepared.url)
    }
}
