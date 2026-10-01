#if DEBUG
import Foundation
import SwiftData

/// A practice pack to receive, for the UI test of the receive door (ADR 0236 D8): a short generated song,
/// *Pack test* by Jack Trader, with a section marker and a loop, sent by *Tester*.
///
/// Built by the code that builds a real one (`SharedSongBuilder`, `PracticePack.write`) and opened by the
/// host as a tapped file is, so what the test drives from the preview onward is the real path: the unzip,
/// the version check, the preview, the copy in, the waveform and the landing. A UI test can't hand the app
/// a file of its own.
///
/// The tone is `SampleToneGenerator`'s, asset-free, as the seeded take's is.
enum ReceivedPackSeed {

    static let title = "Pack test"
    static let sender = "Tester"

    /// The pack to open at launch, when the launch asks for one.
    @MainActor
    static func packIfAsked(arguments: [String] = CommandLine.arguments) -> URL? {
        guard arguments.contains(UITestHooks.launchArgument),
              arguments.contains(UITestHooks.receivePackArgument) else { return nil }
        let leaf = "uitest-pack.m4a"
        let tone = FileManager.default.temporaryDirectory.appending(path: leaf, directoryHint: .notDirectory)
        try? FileManager.default.removeItem(at: tone)
        guard (try? SampleToneGenerator.writeSample(duration: 8, to: tone, settings: TakeRecorder.settings)) != nil
        else { return nil }

        let song = Song(title: title, artist: "Jack Trader", bpm: 120, duration: 8,
                        ref: SongRef(id: "uitest-pack", source: .localFile), audioFileName: leaf)
        let verse = Marker(seconds: 0, label: "Verse")
        verse.startsSection = true
        song.markers = [verse]
        song.loops = [Loop(name: "Riff", start: 0.25, end: 0.5, speed: 0.8, repeats: 4)]
        let payload = SharedSongBuilder.payload(song, senderName: sender, appVersion: "UI test")
        return try? PracticePack.write(payload, audio: [leaf: tone], named: title)
    }

    /// Take any received *Pack test* back out on a UI-test launch that didn't ask for one, so the next
    /// test finds the library it expects. By title, since a received song's id is minted fresh.
    @MainActor
    static func removeLeftovers(from context: ModelContext, arguments: [String] = CommandLine.arguments) {
        guard arguments.contains(UITestHooks.launchArgument),
              !arguments.contains(UITestHooks.receivePackArgument) else { return }
        let received = ((try? context.fetch(FetchDescriptor<Song>())) ?? []).filter { $0.title.hasPrefix(title) }
        guard !received.isEmpty else { return }
        received.forEach(context.delete)
        try? context.save()
    }
}
#endif
