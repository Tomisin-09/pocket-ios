#if DEBUG
import Foundation
import SwiftData

/// A practice pack to receive, for the UI test of the receive door (ADR 0236 D8): a short generated song,
/// *Pack test* by Jack Trader, with a section marker and a loop, sent by *Tester*. Or, under
/// `-receiveRoutinePack`, the routine *Pack routine* with that song (D6): a block on its loop and a block
/// playing the whole song.
///
/// Built by the code that builds a real one (`SharedSongBuilder`, `PracticePack.write`) and opened by the
/// host as a tapped file is, so what the test drives from the preview onward is the real path: the unzip,
/// the version check, the preview, the copy in, the waveform and the landing. A UI test can't hand the app
/// a file of its own.
///
/// The tone is `SampleToneGenerator`'s, asset-free, as the seeded take's is.
enum ReceivedPackSeed {

    static let title = "Pack test"
    static let routineName = "Pack routine"
    static let sender = "Tester"

    /// The pack to open at launch, when the launch asks for one.
    @MainActor
    static func packIfAsked(arguments: [String] = CommandLine.arguments) -> URL? {
        guard arguments.contains(UITestHooks.launchArgument) else { return nil }
        let routine = arguments.contains(UITestHooks.receiveRoutinePackArgument)
        guard routine || arguments.contains(UITestHooks.receivePackArgument) else { return nil }
        let leaf = "uitest-pack.m4a"
        let shooting = arguments.contains(ScreenshotSeed.launchArgument)
        let tone = FileManager.default.temporaryDirectory.appending(path: leaf, directoryHint: .notDirectory)
        try? FileManager.default.removeItem(at: tone)
        guard (try? SampleToneGenerator.writeSample(duration: shooting ? 30 : 8, to: tone,
                                                    settings: TakeRecorder.settings)) != nil
        else { return nil }

        let song = shooting ? shootSong(audio: leaf, routine: routine) : testSong(audio: leaf)
        guard let riff = song.loops.first else { return nil }
        let from = shooting ? shootSender : sender
        let version = shooting ? SupportDiagnostics.currentAppVersion(bundle: Bundle.main) : "UI test"
        guard routine else {
            let payload = SharedSongBuilder.payload(song, senderName: from, appVersion: version)
            return try? PracticePack.write(payload, audio: [leaf: tone], named: song.title)
        }
        let name = shooting ? shootRoutineName : routineName
        let sitting = Routine(name: name)
        sitting.items = [RoutineItem.item(riff, order: 0), RoutineItem.item(song, order: 1)]
        let payload = SharedPracticeBuilder.routine(sitting, appVersion: version, senderName: from,
                                                    songs: [song])
        return try? PracticePack.write(payload, audio: [leaf: tone], named: name)
    }

    // MARK: - What the pack holds

    /// The manual's sender and routine (`-seedScreenshots`): a song a teacher sent, not a test fixture. The
    /// leftover sweep below still matches *Pack test* and *Pack routine* only, so it can never take the
    /// shoot's own Slow Bend for a leftover. The shoot cancels on the preview, so nothing of these lands.
    static let shootSender = "Jack Trader"
    static let shootRoutineName = "Low Road, start to finish"
    /// The routine's song. Not Slow Bend: the shoot's own Slow Bend is the tone-generator demo with no file,
    /// so a routine built on it would send with *Can't go*. Received, this one has its own copy and goes.
    static let shootRoutineSong = "Low Road"

    private static func testSong(audio leaf: String) -> Song {
        let song = Song(title: title, artist: "Jack Trader", bpm: 120, duration: 8,
                        ref: SongRef(id: "uitest-pack", source: .localFile), audioFileName: leaf)
        let verse = Marker(seconds: 0, label: "Verse")
        verse.startsSection = true
        song.markers = [verse]
        let riff = Loop(name: "Riff", start: 0.25, end: 0.5, speed: 0.8, repeats: 4)
        riff.song = song
        if !song.loops.contains(where: { $0 === riff }) { song.loops.append(riff) }
        return song
    }

    /// The demo song as a sent copy: its loops, markers and tempo. Sent alone it keeps its title, and the
    /// shoot's library already holds a Slow Bend, so *Add this song?* shows the copy-name note the manual
    /// describes. In a routine it is *Low Road*, which nothing in the library is called.
    private static func shootSong(audio leaf: String, routine: Bool) -> Song {
        let song = Song.sample()
        if routine { song.title = shootRoutineSong }
        song.audioFileName = leaf
        return song
    }

    /// Take any received *Pack test* and *Pack routine* back out on a UI-test launch that didn't ask for
    /// one, so the next test finds the library it expects. By name, since a received song's id is minted
    /// fresh.
    @MainActor
    static func removeLeftovers(from context: ModelContext, arguments: [String] = CommandLine.arguments) {
        guard arguments.contains(UITestHooks.launchArgument),
              !arguments.contains(UITestHooks.receivePackArgument),
              !arguments.contains(UITestHooks.receiveRoutinePackArgument) else { return }
        let songs = ((try? context.fetch(FetchDescriptor<Song>())) ?? []).filter { $0.title.hasPrefix(title) }
        let routines = ((try? context.fetch(FetchDescriptor<Routine>())) ?? []).filter { $0.name == routineName }
        guard !songs.isEmpty || !routines.isEmpty else { return }
        routines.forEach(context.delete)
        songs.forEach(context.delete)
        try? context.save()
    }
}
#endif
