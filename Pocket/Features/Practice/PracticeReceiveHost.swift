import SwiftData
import SwiftUI

/// A decoded file waiting for the player's yes (ADR 0188 D9).
///
/// A wrapper with its own `id` rather than making the payload `Identifiable`: two files can hold
/// byte-identical practice, and `.sheet(item:)` reads identity as "is this the same presentation". A
/// per-arrival id means opening the same file twice presents twice, which is what D1's "produces a
/// second copy, on purpose" implies at the presentation layer too.
private struct PendingReceive: Identifiable {
    let id = UUID()
    let practice: ReceivedPractice
    /// What each received song will be called here (ADR 0236 D5), worked out against the library once,
    /// when the preview opens: the one song of a song share, or a routine's songs in the order it carries
    /// them. Empty for anything else.
    var songTitles: [String] = []
}

/// The app's **inbound door** for `.redmoonpractice` files (ADR 0188 S2, ADR 0209 D4) — both doors,
/// both payload kinds — and for `.redmoonpack`s, which carry songs with their audio (ADR 0236 D8).
///
/// Applied **once** at the app root: one host means one preview sheet for the whole app, and the two
/// doors cannot present different things or write by different rules.
///
/// **Why the root and not the Routines library.** Tap-to-open is the door ADR 0188 D3 spends its
/// length defending, and it can arrive with no screen of the app's own on top — from Messages, Mail,
/// Files or AirDrop, on a cold launch. There is no view further down the tree that is guaranteed to
/// be mounted when the URL lands, so the receiver has to be the one view that always is. The in-app
/// pickers then call the same code through `\.receivePracticeFile` rather than owning a copy of it.
///
/// **It does not care which library the file belongs in.** A drill picked from the Routines screen
/// lands in Exercises and says so; that is a property of the file, not of where it was opened, and
/// making the pickers kind-specific would mean four doors to keep in step instead of one.
private struct PracticeReceiveHost: ViewModifier {
    @Environment(\.modelContext) private var context

    @State private var pending: PendingReceive?
    @State private var failure: String?
    /// What just landed, and where it went, for the confirmation. Door A can land practice while the
    /// player is looking at the Toolkit, so "it worked" has to be said rather than shown.
    @State private var landed: String?
    /// Where the pack on show was unpacked (ADR 0236 D8). Removed when the preview closes without Add;
    /// on Add, the landing takes it over and removes it once the song is in.
    @State private var unpacked: URL?

    func body(content: Content) -> some View {
        content
            // The second door's entry point. `removingSource: false` is the whole reason this is a
            // parameter: a picked URL points at the player's *own* file, wherever they keep it, and
            // deleting it would be the app tidying up somebody else's Files app.
            .environment(\.receivePracticeFile, { url in open(url, removingSource: false) })
            // The first door. A tapped file arrives as a copy the system has already placed in this
            // app's own inbox, so it is ours to remove once read — and nothing ever reads it again.
            .onOpenURL { url in open(url, removingSource: true) }
            #if DEBUG
            // The UI test of the receive door: a pack built at launch, opened as a tapped file would be.
            .task { if let pack = ReceivedPackSeed.packIfAsked() { open(pack, removingSource: true) } }
            #endif
            .sheet(item: $pending, onDismiss: discardUnpacked) { arrival in
                switch arrival.practice {
                case let .routine(received):
                    ReceivedRoutinePreviewSheet(received: received, songTitles: arrival.songTitles) {
                        add(received, songTitles: arrival.songTitles)
                    }
                case let .exercise(received):
                    ReceivedExercisePreviewSheet(received: received) { add(received) }
                case let .song(received):
                    let title = arrival.songTitles.first ?? received.displayTitle
                    ReceivedSongPreviewSheet(received: received, title: title) { add(received, as: title) }
                }
            }
            .alert("Couldn’t open that file", isPresented: presenting($failure)) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
            .alert("Added", isPresented: presenting($landed)) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(landed ?? "")
            }
    }

    /// Read a file and offer what is in it — or say why not.
    private func open(_ url: URL, removingSource: Bool) {
        // Runs whichever way this returns: an inbox copy the app has decided not to act on is dead
        // weight nothing will ever read again.
        defer { if removingSource { try? FileManager.default.removeItem(at: url) } }
        // Bracketed the way the app's four audio importers already bracket a picked URL. Harmless on
        // an inbox copy, which is inside this app's own container and needs no scope.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if url.pathExtension.lowercased() == PracticePack.fileExtension { return openPack(url) }
        guard let data = try? Data(contentsOf: url) else {
            failure = "That file couldn’t be read."
            return
        }
        switch ReceivedPracticeBuilder.evaluate(data: data) {
        case let .success(practice):
            pending = PendingReceive(practice: practice)
        case let .failure(reason):
            failure = reason.message
        }
    }

    /// A pack (ADR 0236 D8): copied into `tmp/` while the file is still in scope, since a picked URL's
    /// scope closes when `open` returns and the zip is read memory-mapped, then read off the main actor:
    /// unpacking a song's audio is megabytes of work.
    private func openPack(_ url: URL) {
        let staging = FileManager.default.temporaryDirectory
            .appending(path: "RedMoonInbox", directoryHint: .isDirectory)
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let copy = staging.appending(path: "received.\(PracticePack.fileExtension)", directoryHint: .notDirectory)
        do {
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: url, to: copy)
        } catch {
            try? FileManager.default.removeItem(at: staging)
            failure = "That file couldn’t be read."
            return
        }
        let songs = staging.appending(path: PracticePack.songsFolder, directoryHint: .isDirectory)
        Task {
            let read = await Task.detached { () -> Result<PracticePack.Contents, ReceiveFailure> in
                do {
                    return .success(try PracticePack.read(copy, into: songs))
                } catch let reason as ReceiveFailure {
                    return .failure(reason)
                } catch {
                    return .failure(.corrupt)
                }
            }.value
            try? FileManager.default.removeItem(at: copy)
            switch read.flatMap({ ReceivedPracticeBuilder.evaluate($0, staging: staging) }) {
            case let .success(practice):
                unpacked = staging
                pending = PendingReceive(practice: practice, songTitles: songTitles(for: practice))
            case let .failure(reason):
                try? FileManager.default.removeItem(at: staging)
                failure = reason.message
            }
        }
    }

    /// Each received song's name here (ADR 0236 D5): its own, or a copy's when the library, or a song
    /// arriving beside it, has that title.
    private func songTitles(for practice: ReceivedPractice) -> [String] {
        let songs: [ReceivedSong] = switch practice {
        case let .song(received): [received]
        case let .routine(received): received.songs
        case .exercise: []
        }
        guard !songs.isEmpty else { return [] }
        let library = ((try? context.fetch(FetchDescriptor<Song>())) ?? []).map(\.title)
        return SongCopyName.titles(for: songs.map(\.record.title), sender: songs[0].senderName, existing: library)
    }

    /// The preview closed without Add: what the pack unpacked is never read again.
    private func discardUnpacked() {
        if let unpacked { try? FileManager.default.removeItem(at: unpacked) }
        unpacked = nil
    }

    /// Write a routine — one of the places in the receiving path that touch the store.
    ///
    /// The graph comes back uninserted and `HydratedRoutine.insert` knows the one order that works,
    /// so this is a hand-off rather than an assembly.
    ///
    /// With songs (ADR 0236 D6), their audio is copied in and read off the main actor first, as a song
    /// sent on its own is, and the routine's blocks are bound to them. **All or nothing**: a song whose
    /// audio can't be read lands nothing, and the copies already made are removed, since a routine
    /// landing with some of what the preview promised would be a different routine.
    private func add(_ received: ReceivedRoutine, songTitles: [String]) {
        guard !received.songs.isEmpty else { return land(received, songs: []) }
        // The landing owns the unpacked folder now, so closing the preview mustn't remove it.
        unpacked = nil
        let audio = received.songs.map(\.audio)
        Task {
            defer {
                if let staging = received.songs.first?.staging { try? FileManager.default.removeItem(at: staging) }
            }
            let prepared = await Task.detached { () -> [SongImporter.Prepared]? in
                var made: [SongImporter.Prepared] = []
                for file in audio {
                    guard let song = try? SongImporter.prepareReceived(from: file) else {
                        for copy in made {
                            if let leaf = copy.audioFileName { try? SongFileStore.delete(fileName: leaf) }
                        }
                        return nil
                    }
                    made.append(song)
                }
                return made
            }.value
            guard let prepared else {
                failure = "One of the routine’s songs couldn’t be read, so nothing was added."
                return
            }
            // Under the names the preview showed (D5); the song's own, should the two lists ever differ.
            let songs = received.songs.enumerated().map { index, song in
                ReceivedSongBuilder.landing(song, prepared: prepared[index],
                                            title: songTitles.indices.contains(index)
                                                ? songTitles[index] : song.displayTitle)
            }
            land(received, songs: songs)
        }
    }

    /// Write the routine's graph, its songs first, and say so.
    private func land(_ received: ReceivedRoutine, songs: [LandedSong]) {
        let landing = ReceivedRoutineBuilder.materialize(received, songs: songs)
        landing.insert(into: context)
        save()
        // Both numbers, because the interesting question about this feature is not how often it is
        // used but how much of a shared routine actually crosses (D4). Two `Int`s — the analytics
        // lint rule forbids a free `String`, and there is nothing here worth naming anyway.
        Analytics.send(.routineReceived(items: landing.items.count,
                                        orphanedBlocks: landing.items.filter(\.isOrphaned).count))
        landed = songs.isEmpty
            ? "“\(received.displayName)” is in your routines."
            : "“\(received.displayName)” is in your routines, and its "
                + (songs.count == 1 ? "song is" : "\(songs.count) songs are") + " in your songs."
        haptic(.medium)
    }

    /// Write a drill (ADR 0209 D4). One row, and the asymmetry with the routine's three is the point
    /// of having the two functions rather than one that branches inside.
    ///
    /// The template is read off the record rather than the fresh model: they agree, and reading the
    /// file's own value keeps the event about **what was sent**. A drill on a template this build
    /// cannot name is still added — its raw value survives into the model for a build that can read
    /// it — but sends no event, because the only template the event could carry would be a guess.
    /// (Until ADR 0237 the receive gate refused such a file outright.)
    private func add(_ received: ReceivedExercise) {
        let landing = ReceivedPracticeBuilder.materialize(received)
        landing.insert(into: context)
        save()
        if let template = received.template { Analytics.send(.exerciseReceived(template: template)) }
        landed = "“\(received.displayName)” is in your exercises."
        haptic(.medium)
    }

    /// Land a received song (ADR 0236 D4): its audio copied in and read like any import, off the main
    /// actor, then the song written with its loops and markers under the name the preview showed.
    private func add(_ received: ReceivedSong, as title: String) {
        // The landing owns the unpacked folder now, so closing the preview mustn't remove it.
        unpacked = nil
        let audio = received.audio
        Task {
            defer { try? FileManager.default.removeItem(at: received.staging) }
            do {
                let prepared = try await Task.detached { try SongImporter.prepareReceived(from: audio) }.value
                context.insert(ReceivedSongBuilder.song(from: received, prepared: prepared, title: title))
                save()
                landed = "“\(title)” is in your songs."
                haptic(.medium)
            } catch {
                failure = "That song’s audio couldn’t be read."
            }
        }
    }

    /// Saved rather than left to autosave: Door A can land practice seconds before the player
    /// switches back to the app that sent it, and a receive that has to survive being backgrounded is
    /// not a good candidate for "the context will get to it".
    private func save() {
        try? context.save()
    }

    /// A `Bool` binding over an optional message, the idiom `LibraryView.importErrorBinding` uses:
    /// the alert clears the message when it is dismissed, so a second failure presents again.
    private func presenting(_ message: Binding<String?>) -> Binding<Bool> {
        Binding(get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } })
    }
}

/// Open a `.redmoonpractice` file, from anywhere in the app (ADR 0188 S2, ADR 0209 D4).
///
/// Defaults to a no-op so a view in an Xcode preview or a test does nothing rather than trapping on
/// a host that isn't there — the reason it is an environment action rather than a shared singleton.
private struct ReceivePracticeFileKey: EnvironmentKey {
    static let defaultValue: @MainActor (URL) -> Void = { _ in }
}

extension EnvironmentValues {
    /// Hand a `.redmoonpractice` file to the app's one receiving door, whatever it holds.
    /// `@MainActor` — it mutates view state.
    var receivePracticeFile: @MainActor (URL) -> Void {
        get { self[ReceivePracticeFileKey.self] }
        set { self[ReceivePracticeFileKey.self] = newValue }
    }
}

extension View {
    /// Install the app-wide receiving door (once, at the root).
    func practiceReceiveHost() -> some View {
        modifier(PracticeReceiveHost())
    }
}
