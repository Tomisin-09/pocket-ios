import SwiftUI

/// A read-first **song details** view, opened by holding the title on the practice
/// screen (workstream 5). It reads as a descriptive overview — title/artist header,
/// the song's musical facts, collections, notes, and practice stats — rather than a
/// form of editable fields. Editing the structured facts is one tap away via **Edit**,
/// which presents the existing `SongEditSheet`; on save the values flow back through
/// the observed `Song`. **Notes are the exception** (ADR 0038): they're editable inline
/// here, behind a deliberate edit affordance — tap the pencil in the Notes header to
/// start, an **Update** button commits the change (with a brief "Saved" confirmation),
/// so quick capture doesn't need the Edit-sheet detour but still feels intentional.
struct SongDetailsSheet: View {
    let song: Song

    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    // Inline notes editing: a local draft committed on Update, so the read view only
    // changes when you explicitly save (not keystroke-by-keystroke).
    @State private var editingNotes = false
    @State private var draftComment = ""
    @FocusState private var notesFocused: Bool
    @State private var savedPulse = false

    var body: some View {
        NavigationStack {
            Form {
                headerSection
                // Notes sit directly under the title/artist/album box — the song's
                // free-text standing facts (tuning, capo…), the song-scope half of the
                // notes/journal feature (ADR 0038). Always shown so they're discoverable.
                notesSection
                detailsSection
                if !song.collections.isEmpty { collectionsSection }
                statsSection
            }
            .navigationTitle("Song details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Edit") { editing = true }
                }
            }
        }
        .presentationDetents([.large])
        // Edit is a nested sheet over the details so dismissing it returns here; the
        // edited values write straight back to the persisted `Song`, which this view
        // observes, so the read view refreshes on save.
        .sheet(isPresented: $editing) {
            SongEditSheet(song: song)
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PocketColor.textPrimary)
                if !song.artist.isEmpty {
                    Text(song.artist)
                        .font(.subheadline)
                        .foregroundStyle(PocketColor.textSecondary)
                }
                if !albumLine.isEmpty {
                    Text(albumLine)
                        .font(.footnote)
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }
    }

    private var detailsSection: some View {
        Section {
            detailRow("Key", song.musicalKey == .unknown ? "—" : song.musicalKey.displayName)
            DetailLabeledContent(label: "Tempo") {
                Text(tempoText).font(.pocketMono(.body)).foregroundStyle(PocketColor.textPrimary)
            }
            DetailLabeledContent(label: "Mastery") {
                if let mastery = song.mastery {
                    Text(stars(mastery)).foregroundStyle(PocketColor.marker)
                } else {
                    Text("Unrated").foregroundStyle(PocketColor.textSecondary)
                }
            }
            DetailLabeledContent(label: "Length") {
                Text(timecode(song.duration)).font(.pocketMono(.body)).foregroundStyle(PocketColor.textPrimary)
            }
        }
    }

    private var collectionsSection: some View {
        Section("Collections") {
            ForEach(song.collections, id: \.self) { tag in
                Text(tag).foregroundStyle(PocketColor.textPrimary)
            }
        }
    }

    private var notesSection: some View {
        Section {
            if editingNotes {
                TextField("Tuning, capo, anything worth remembering…",
                          text: $draftComment, axis: .vertical)
                    .lineLimit(1...8)
                    .focused($notesFocused)
                    .foregroundStyle(PocketColor.textPrimary)
                    .onAppear { notesFocused = true }   // open the keyboard on entry
                HStack {
                    Button("Cancel", role: .cancel) { endNotesEditing() }
                        .foregroundStyle(PocketColor.textSecondary)
                    Spacer()
                    // Disabled until the draft actually differs — the button lighting
                    // up *is* the "you've made changes" cue.
                    Button("Update") { saveNotes() }
                        .fontWeight(.semibold)
                        .disabled(draftComment == song.comment)
                }
            } else if song.comment.isEmpty {
                Text("No notes yet — tap the pencil to add tuning, capo, or anything "
                    + "worth remembering.")
                    .font(.footnote)
                    .foregroundStyle(PocketColor.textSecondary)
            } else {
                Text(song.comment).foregroundStyle(PocketColor.textPrimary)
            }
        } header: {
            HStack {
                Text("Notes")
                Spacer()
                if savedPulse {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(PocketColor.active)
                        .transition(.opacity)
                } else if !editingNotes {
                    Button { startNotesEditing() } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Edit notes")
                }
            }
        }
    }

    // MARK: - Inline notes editing

    private func startNotesEditing() {
        draftComment = song.comment
        savedPulse = false
        withAnimation { editingNotes = true }
    }

    private func endNotesEditing() {
        notesFocused = false
        withAnimation { editingNotes = false }
    }

    private func saveNotes() {
        song.comment = draftComment   // mutating the @Model persists
        endNotesEditing()
        withAnimation { savedPulse = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { savedPulse = false }
        }
    }

    private var statsSection: some View {
        Section("Practice stats") {
            statRow("Loops", song.loops.count)
            statRow("Markers", song.markers.count)
            statRow("Annotations", song.annotationCount)
        }
    }

    // MARK: - Row builders

    private func detailRow(_ label: String, _ value: String) -> some View {
        DetailLabeledContent(label: label) {
            Text(value).foregroundStyle(PocketColor.textPrimary)
        }
    }

    private func statRow(_ label: String, _ value: Int) -> some View {
        DetailLabeledContent(label: label) {
            Text("\(value)").font(.pocketMono(.body)).foregroundStyle(PocketColor.textPrimary)
        }
    }

    // MARK: - Derived text

    /// `Album · Year`, omitting whichever half is unknown (empty when neither is set).
    private var albumLine: String {
        [song.album.isEmpty ? nil : song.album, song.year.map(String.init)]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var tempoText: String {
        song.bpm.map { "\($0) BPM" } ?? "—"
    }
}

/// A details row: a secondary label on the left, the supplied value view trailing.
/// Mirrors the edit sheet's row rhythm so details and edit feel like one place.
private struct DetailLabeledContent<Value: View>: View {
    let label: String
    @ViewBuilder let value: () -> Value

    var body: some View {
        LabeledContent {
            value()
        } label: {
            Text(label).foregroundStyle(PocketColor.textSecondary)
        }
    }
}
