import SwiftData
import SwiftUI

/// **Send this song** (ADR 0236 D4, D7): what goes to another Red Moon, what stays, and who it's from,
/// shown before anything is sent. *Send…*, in the bar, builds the pack and opens the share sheet.
///
/// The words are about handing your own work to someone (D1): a teacher, a bandmate, your other phone.
/// It never says *share this song*.
///
/// Presented from Song details' `NavigationStack`, never from the row inside its `Form`: a presentation
/// raised there is lost (`ReferenceLinkEditing`). The share sheet goes through `SharePresenter` for the
/// same reason.
struct SendSongSheet: View {
    let song: Song

    @Query private var profiles: [Profile]
    @Environment(\.dismiss) private var dismiss
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
                    Text(song.title.isEmpty ? "Untitled song" : song.title)
                } footer: {
                    note(senderName == nil
                         ? "No name is sent. Add an artist name in Settings ▸ You to sign what you send."
                         : "They see this name, and it labels their copy if they already have a song "
                           + "with this title.")
                }

                Section("Goes with it") {
                    detail("The audio file", fileDescription)
                    detail("Loops", "\(song.loops.count)")
                    detail("Markers", "\(song.markers.count)")
                    if let tempo { detail("Tempo and beat grid", tempo) }
                }

                Section {
                    ForEach(Self.staying, id: \.self) { line in
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
            .navigationTitle("Send this song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(sent ? "Done" : "Cancel") { dismiss() }
                }
                // In the bar, as Add is on a receive preview: always in reach, whatever the form's length.
                ToolbarItem(placement: .confirmationAction) {
                    if preparing {
                        ProgressView()
                    } else {
                        Button("Send…", action: send)
                    }
                }
            }
            .alert("Couldn’t send the song", isPresented: Binding(get: { failure != nil },
                                                                  set: { if !$0 { failure = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
        }
        .tint(PocketColor.library)
    }

    /// What D4 keeps with the sender, in the player's words.
    static let staying = [
        "Pieces and tab",
        "Mastery, and the speeds you’ve reached",
        "Takes and journal notes",
        "Your notes, collections and links",
        "When you last practised"
    ]

    /// The artist name as it travels (D7), or `nil`.
    private var senderName: String? { SharedSongBuilder.senderName(profiles.first?.artistName) }

    private var fileDescription: String {
        SongAudioLabel.describe(audioFileName: song.audioFileName, hasBookmark: song.bookmark != nil,
                                sizeInBytes: song.audioFileName.flatMap { SongFileStore.fileSize(fileName: $0) },
                                copyExists: song.exportedAudioFile() != nil)
    }

    private var tempo: String? {
        guard let bpm = song.tempoBPM else { return nil }
        return "\(Int(bpm.rounded())) BPM · \(song.beatsPerBar)/\(song.noteValue)"
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

    /// Build the pack off the main actor (a hard link and a zip), then open the share sheet on it.
    private func send() {
        guard let file = song.exportedAudioFile(), let leaf = song.audioFileName else {
            failure = "Red Moon doesn’t have this song’s audio to send."
            return
        }
        let payload = SharedSongBuilder.payload(song, senderName: senderName,
                                                appVersion: SupportDiagnostics.currentAppVersion(bundle: Bundle.main))
        let stem = song.title.isEmpty ? "Song" : song.title
        let source = file.source
        preparing = true
        Task {
            defer { preparing = false }
            do {
                let pack = try await Task.detached {
                    try PracticePack.write(payload, audio: [leaf: source], named: stem)
                }.value
                SharePresenter.present(pack)
                sent = true
            } catch {
                failure = error.localizedDescription
            }
        }
    }
}
