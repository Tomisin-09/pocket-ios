import SwiftData
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
    @Environment(\.modelContext) private var modelContext
    /// Every exercise, to offer in the link picker (ADR 0111). Sorted by name, like the library.
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @State private var showingExercisePicker = false
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
                linkedExercisesSection
                statsSection
            }
            .navigationTitle("Song details")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingExercisePicker) {
                LinkPickerSheet(
                    title: "Link exercises",
                    prompt: "Search exercises",
                    emptyCatalog: "No exercises in your library yet.",
                    candidates: allExercises,
                    label: { $0.name.isEmpty ? "Untitled exercise" : $0.name },
                    subtitle: { $0.template.displayName },
                    isLinked: { isLinked($0) },
                    toggle: { toggleLink($0) },
                    accent: PocketColor.practice)
            }
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
                    .font(.futura(.title3, weight: .semibold))
                    .foregroundStyle(PocketColor.textPrimary)
                if !song.artist.isEmpty {
                    Text(song.artist)
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                if !albumLine.isEmpty {
                    Text(albumLine)
                        .font(.futura(.footnote))
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
            DetailLabeledContent(label: "Mastery", info: PracticeFieldInfo.songMastery) {
                if let mastery = song.mastery {
                    Text(stars(mastery)).foregroundStyle(PocketColor.mastery)
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
                    .keyboardDoneButton(tint: PocketColor.library)
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
                    .font(.futura(.footnote))
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
                        .font(.futura(.caption))
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

    // MARK: - Linked drills (ADR 0111)

    /// The exercises that **serve** this song — the song side of the `Song.linkedExercises` ↔
    /// `Exercise.linkedSongs` edge, and the future home of "Build a practice routine for this song".
    /// Each row unlinks with a swipe; **Link exercises** opens the multi-select picker. Link changes
    /// persist immediately, matching the inline-notes save here (a discrete, intentional edit).
    private var linkedExercisesSection: some View {
        Section {
            if song.linkedExercises.isEmpty {
                Text("No drills linked yet — link the exercises that help you play this song.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            } else {
                ForEach(linkedExercisesByName, id: \.persistentModelID) { exercise in
                    HStack(spacing: 8) {
                        Text(exercise.name.isEmpty ? "Untitled exercise" : exercise.name)
                            .foregroundStyle(PocketColor.textPrimary)
                        Spacer(minLength: 8)
                        Text(exercise.template.displayName)
                            .font(.futura(.caption))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                }
                .onDelete(perform: unlinkExercises)
            }
            Button { showingExercisePicker = true } label: {
                Label("Link exercises", systemImage: "plus.circle")
                    .foregroundStyle(PocketColor.practice)
            }
        } header: {
            Text("Exercises for this song")
        } footer: {
            Text("Exercises that help you play this song. Links show on the exercise too.")
        }
    }

    private var linkedExercisesByName: [Exercise] {
        song.linkedExercises.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func isLinked(_ exercise: Exercise) -> Bool {
        song.linkedExercises.contains { $0.persistentModelID == exercise.persistentModelID }
    }

    /// Toggle a drill's link from the picker — mutating the relationship + `save()` keeps the picker
    /// checkmark and the section behind it in sync.
    private func toggleLink(_ exercise: Exercise) {
        if let index = song.linkedExercises.firstIndex(where: { $0.persistentModelID == exercise.persistentModelID }) {
            song.linkedExercises.remove(at: index)
        } else {
            song.linkedExercises.append(exercise)
        }
        try? modelContext.save()
    }

    private func unlinkExercises(at offsets: IndexSet) {
        let targets = offsets.map { linkedExercisesByName[$0] }
        for exercise in targets {
            song.linkedExercises.removeAll { $0.persistentModelID == exercise.persistentModelID }
        }
        try? modelContext.save()
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
    /// Optional explainer — when set, the label gains a tappable ⓘ (used on the derived Mastery
    /// row, where "why can't I set this?" is the common confusion).
    var info: String?
    @ViewBuilder let value: () -> Value

    var body: some View {
        LabeledContent {
            value()
        } label: {
            if let info {
                FieldInfoLabel(title: label, info: info)
                    .foregroundStyle(PocketColor.textSecondary)
            } else {
                Text(label).foregroundStyle(PocketColor.textSecondary)
            }
        }
    }
}
