import SwiftData
import SwiftUI

/// **Send this routine** (ADR 0236 D6, D7): who it's from, whether its songs go with it, what goes and
/// what stays, shown before anything is sent. *Send…*, in the bar, writes the file and opens the share
/// sheet: a `.redmoonpack` with the songs, a `.redmoonpractice` without them.
///
/// Only for a routine with a song or loop block; one without goes straight to the share sheet, as it
/// always has (`RoutineDetailView+Share`). The words are about handing your own work to someone (D1): a
/// lesson to a student, a set to a bandmate. It never says *share*.
struct SendRoutineSheet: View {
    let routine: Routine

    @Query private var profiles: [Profile]
    @Environment(\.dismiss) private var dismiss
    /// *Include the songs*: on by default, since this screen only opens on a routine that plays some.
    @State private var includeSongs = true
    @State private var preparing = false
    @State private var sent = false
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent {
                        Text(senderName ?? "No artist name")
                            .font(.futura(.body))
                            .foregroundStyle(senderName == nil ? PocketColor.textSecondary : PocketColor.textPrimary)
                    } label: {
                        Text("Sent as").font(.futura(.body)).foregroundStyle(PocketColor.textPrimary)
                    }
                    .listRowBackground(PocketColor.background)
                } header: {
                    Text(title)
                } footer: {
                    note(senderName == nil
                         ? "No name is sent. Add an artist name in Settings ▸ You to sign what you send."
                         : "They see this name, and it labels their copy of a song they already have.")
                }

                Section {
                    Toggle(isOn: $includeSongs) {
                        Text("Include the songs").font(.futura(.body)).foregroundStyle(PocketColor.textPrimary)
                    }
                    .listRowBackground(PocketColor.background)
                } footer: {
                    note(switchNote)
                }

                if includeSongs { songsSection }

                Section("Goes with it") {
                    detail("Blocks", "\(routine.items.count)")
                    detail("Exercises", "\(exerciseCount)")
                }

                Section {
                    ForEach(SendSongSheet.staying, id: \.self) { line in
                        Text(line)
                            .font(.futura(.body))
                            .foregroundStyle(PocketColor.textPrimary)
                            .listRowBackground(PocketColor.background)
                    }
                } header: {
                    Text("Stays with you")
                } footer: {
                    note("Send opens the share sheet, for AirDrop, Messages, Mail or Files. They open it in "
                         + "Red Moon.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Send this routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(sent ? "Done" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if preparing {
                        ProgressView()
                    } else {
                        Button("Send…", action: send)
                    }
                }
            }
            .alert("Couldn’t send the routine", isPresented: Binding(get: { failure != nil },
                                                                     set: { if !$0 { failure = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
        }
        .tint(PocketColor.practice)
    }

    // MARK: - The songs

    /// One song the routine plays, and the audio Red Moon keeps for it, when it keeps any.
    private struct PlayedSong: Identifiable {
        let song: Song
        let file: ExportedAudioFile?
        var id: String { song.sourceID }
        var bytes: Int64? { song.audioFileName.flatMap { SongFileStore.fileSize(fileName: $0) } }
    }

    /// Every song a block plays, in the order the sitting reaches them.
    private var played: [PlayedSong] {
        SharedPracticeBuilder.songsPlayed(by: routine).map { PlayedSong(song: $0, file: $0.exportedAudioFile()) }
    }

    /// The songs that can go: the ones Red Moon holds a copy of (ADR 0148, 0236 D3). An Apple Music song,
    /// or one whose file is missing, has nothing to send, and its blocks go as placeholders.
    private var travelling: [PlayedSong] { played.filter { $0.file != nil } }

    @ViewBuilder
    private var songsSection: some View {
        let songs = played
        Section {
            ForEach(songs) { entry in
                LabeledContent {
                    Text(entry.file == nil ? "Can’t go" : entry.bytes.map { StorageUsage.formatted(bytes: $0) } ?? "")
                        .font(.pocketMono(.body))
                        .foregroundStyle(PocketColor.textSecondary)
                } label: {
                    Text(entry.song.title.isEmpty ? "Untitled song" : entry.song.title)
                        .font(.futura(.body))
                        .foregroundStyle(entry.file == nil ? PocketColor.textSecondary : PocketColor.textPrimary)
                }
                .listRowBackground(PocketColor.background)
            }
        } header: {
            Text("Songs")
        } footer: {
            if songs.contains(where: { $0.file == nil }) {
                note("Red Moon doesn’t keep a copy of a song marked Can’t go, so its blocks arrive named, in "
                     + "their place, for them to point at their own.")
            }
        }
    }

    /// What the switch does, in a line: how much the songs add, or what happens to their blocks.
    private var switchNote: String {
        guard includeSongs else {
            return "Its song and loop blocks arrive named, in their place, for them to point at their own songs."
        }
        let going = travelling
        guard !going.isEmpty else {
            return "None of its songs can go: Red Moon doesn’t keep a copy of their audio."
        }
        let total = going.compactMap(\.bytes).reduce(0, +)
        let count = going.count == 1 ? "1 song" : "\(going.count) songs"
        return "Adds \(count), \(StorageUsage.formatted(bytes: total)). Each comes with all its loops and "
            + "markers, ready to practise."
    }

    // MARK: - Rows

    private var title: String {
        let name = routine.name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Practice routine" : name
    }

    /// The artist name as it travels (D7), or `nil`.
    private var senderName: String? { SharedSongBuilder.senderName(profiles.first?.artistName) }

    private var exerciseCount: Int {
        Set(routine.items.compactMap(\.exercise?.uid)).count
    }

    private func detail(_ label: String, _ value: String) -> some View {
        LabeledContent {
            Text(value).font(.pocketMono(.body)).foregroundStyle(PocketColor.textSecondary)
        } label: {
            Text(label).font(.futura(.body)).foregroundStyle(PocketColor.textPrimary)
        }
        .listRowBackground(PocketColor.background)
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.futura(.footnote)).foregroundStyle(PocketColor.textSecondary)
    }

    // MARK: - Sending

    /// Write the file off the main actor, then open the share sheet on it: a pack when songs go (a hard
    /// link per song and a zip), the routine's JSON when none do.
    private func send() {
        let going = includeSongs ? travelling : []
        let payload = SharedPracticeBuilder.routine(
            routine, appVersion: SupportDiagnostics.currentAppVersion(bundle: Bundle.main),
            senderName: senderName, songs: going.map(\.song))
        let audio = Dictionary(going.compactMap { entry in
            entry.song.audioFileName.flatMap { leaf in entry.file.map { (leaf, $0.source) } }
        }, uniquingKeysWith: { first, _ in first })
        let stem = title
        let fileName = SharedPracticeFile.fileName(for: routine.name)
        preparing = true
        Task {
            defer { preparing = false }
            do {
                let url = try await Task.detached {
                    audio.isEmpty
                        ? try ExportStaging.write(try ArchiveCoding.encode(payload), as: fileName)
                        : try PracticePack.write(payload, audio: audio, named: stem)
                }.value
                SharePresenter.present(url)
                sent = true
            } catch {
                failure = error.localizedDescription
            }
        }
    }
}
