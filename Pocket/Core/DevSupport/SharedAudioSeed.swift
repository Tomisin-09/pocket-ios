#if DEBUG
import Foundation
import SwiftData

/// An audio file shared from another app, for the UI test of the receive door (ADR 0273): a short tone
/// called *Shared tone.m4a*, opened by the host as a shared file is. Everything from there is the real
/// path: the copy, the decode, the song, and the waveform it opens on. A UI test can't drive another
/// app's share sheet (ADR 0264 D10.6), so this is as close as one gets.
///
/// The tone is `SampleToneGenerator`'s, asset-free, as `ReceivedPackSeed`'s is.
enum SharedAudioSeed {

    /// The song's title, which is the file's name without its extension.
    static let title = "Shared tone"

    /// The file to open at launch, when the launch asks for one.
    @MainActor
    static func fileIfAsked(arguments: [String] = CommandLine.arguments) -> URL? {
        guard arguments.contains(UITestHooks.launchArgument),
              arguments.contains(UITestHooks.receiveSharedAudioArgument) else { return nil }
        return writeTone()
    }

    /// Whether the return-from-background file has been handed over yet: once per launch.
    @MainActor private static var handedOverOnReturn = false

    /// The file to open on the app's first return from the background, under
    /// `-receiveSharedAudioOnReturn`: what a share from another app looks like, arriving over whichever
    /// screen the test left open (ADR 0273 D3).
    @MainActor
    static func fileOnReturnIfAsked(arguments: [String] = CommandLine.arguments) -> URL? {
        guard arguments.contains(UITestHooks.launchArgument),
              arguments.contains(UITestHooks.receiveSharedAudioOnReturnArgument),
              !handedOverOnReturn else { return nil }
        handedOverOnReturn = true
        return writeTone()
    }

    @MainActor
    private static func writeTone() -> URL? {
        let file = FileManager.default.temporaryDirectory.appending(path: "\(title).m4a", directoryHint: .notDirectory)
        try? FileManager.default.removeItem(at: file)
        guard (try? SampleToneGenerator.writeSample(duration: 8, to: file, settings: TakeRecorder.settings)) != nil
        else { return nil }
        return file
    }

    /// Take any *Shared tone* back out on a UI-test launch that didn't ask for one, so the next test finds
    /// the library it expects. By name, since an imported song's id is minted fresh.
    @MainActor
    static func removeLeftovers(from context: ModelContext, arguments: [String] = CommandLine.arguments) {
        guard arguments.contains(UITestHooks.launchArgument),
              !arguments.contains(UITestHooks.receiveSharedAudioArgument),
              !arguments.contains(UITestHooks.receiveSharedAudioOnReturnArgument) else { return }
        let songs = ((try? context.fetch(FetchDescriptor<Song>())) ?? []).filter { $0.title.hasPrefix(title) }
        guard !songs.isEmpty else { return }
        songs.forEach(context.delete)
        try? context.save()
    }
}
#endif
