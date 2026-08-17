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

    /// How **Replace audio file…** performs the swap (ADR 0152). `nil` — the library's case — goes
    /// straight through `SongRelinker`. The practice screen passes its own, because it has the file
    /// open and has to stop and reload the engine around the replacement.
    private let replaceAudio: ((URL) async throws -> SongRelinker.Outcome)?

    init(song: Song, replaceAudio: ((URL) async throws -> SongRelinker.Outcome)? = nil) {
        self.song = song
        self.replaceAudio = replaceAudio
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    /// Entitlement + the shared paywall (ADR 0112) — "Build a routine for this song" produces a real
    /// `Routine`, which is Pro. Linking exercises to a song stays free (it's not authoring content).
    @Environment(\.isPro) private var isPro
    @Environment(\.presentPaywall) private var presentPaywall
    /// Every exercise, to offer in the link picker (ADR 0111). Sorted by name, like the library.
    /// Candidates for the "Link exercises" picker. Loaded when *that* picker opens, not when
    /// this sheet does — it was a `@Query` for every `Exercise`, run on the main thread during
    /// presentation, and this sheet is opened by holding the title on the practice screen while
    /// audio plays. Most openings never touch the picker at all.
    @State private var exerciseCandidates: [Exercise] = []
    @State private var showingExercisePicker = false
    @State private var buildingRoutine = false
    @State private var editing = false
    // Inline notes editing: a local draft committed on Update, so the read view only
    // changes when you explicitly save (not keystroke-by-keystroke).
    @State private var editingNotes = false
    @State private var draftComment = ""
    @FocusState private var notesFocused: Bool
    @State private var savedPulse = false
    /// The reference link being added or edited (ADR 0167). Held here rather than in
    /// `ReferencesSection` — a sheet presented from inside this `Form` dismisses *this* sheet
    /// instead of opening. See `ReferenceLinkEditing`.
    @State private var editingReference: ReferenceLinkDraft?

    var body: some View {
        NavigationStack {
            KeyboardFollowingScroll {
                Form {
                    headerSection
                    // Notes sit directly under the title/artist/album box — the song's
                    // free-text standing facts (tuning, capo…), the song-scope half of the
                    // notes/journal feature (ADR 0038). Always shown so they're discoverable.
                    notesSection
                    detailsSection
                    // Which file this song plays, and the way to change it (ADR 0152) — the
                    // relink door that doesn't depend on the audio being broken.
                    SongAudioSection(song: song, replace: replace)
                    if !song.collections.isEmpty { collectionsSection }
                    linkedExercisesSection
                    ReferencesSection(owner: song, accent: PocketColor.library,
                                      editing: $editingReference)
                    statsSection
                }
            }
            .navigationTitle("Song details")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingExercisePicker) {
                LinkPickerSheet(
                    title: "Link exercises",
                    prompt: "Search exercises",
                    emptyCatalog: "No exercises in your library yet.",
                    candidates: exerciseCandidates,
                    label: { $0.name.isEmpty ? "Untitled exercise" : $0.name },
                    subtitle: { $0.template.displayName },
                    isLinked: { isLinked($0) },
                    toggle: { toggleLink($0) },
                    accent: PocketColor.practice)
            }
            // Push (not a modal cover) so RoutineDetailView's provisional state — Save-only, no
            // Cancel button — still has the nav back button to abandon it, matching the planner flow.
            .navigationDestination(isPresented: $buildingRoutine) {
                RoutineDetailView(container: modelContext.container,
                                  generatedSession: SongRoutineBuilder.sessionBlocks(for: song),
                                  defaultName: SongRoutineBuilder.defaultName(for: song))
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
        .referenceLinkEditing($editingReference, owner: song, accent: PocketColor.library)
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
                    .foregroundStyle(PocketColor.textPrimary)
                    .onAppear { notesFocused = true }   // open the keyboard on entry
                    .keyboardDoneButton(tint: PocketColor.library)
                    .scrollsIntoViewWhenFocused("notes", focused: $notesFocused)
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
            Button {
                // Fetched on the tap that asks for the picker, not in the picker's own `.task` —
                // a task would let the sheet draw its "No exercises in your library yet" empty
                // state for a frame before the real list arrived.
                exerciseCandidates = LibraryPools.exercisesByName(in: modelContext)
                showingExercisePicker = true
            } label: {
                Label("Link exercises", systemImage: "plus.circle")
                    .foregroundStyle(PocketColor.practice)
            }
            buildRoutineButton
        } header: {
            Text("Exercises for this song")
        } footer: {
            Text("Exercises that help you play this song — they show on the exercise too. "
                 + "Build a routine strings these together with your saved loops and a full "
                 + "play-through, ready to review and save.")
        }
    }

    private var linkedExercisesByName: [Exercise] {
        song.linkedExercises.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Whether "Build a routine" has anything to work with — a linked exercise or a saved loop
    /// (ADR 0111). Mirrors `SongRoutineBuilder.canBuild` so the button disables when the generated
    /// routine would be a lone play-through.
    private var canBuildRoutine: Bool { SongRoutineBuilder.canBuild(for: song) }

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

}

/// Row builders, derived text and the replace seam — in an extension so they don't count against
/// the view's body-length cap.
extension SongDetailsSheet {

    // MARK: - Row builders

    func detailRow(_ label: String, _ value: String) -> some View {
        DetailLabeledContent(label: label) {
            Text(value).foregroundStyle(PocketColor.textPrimary)
        }
    }

    func statRow(_ label: String, _ value: Int) -> some View {
        DetailLabeledContent(label: label) {
            Text("\(value)").font(.pocketMono(.body)).foregroundStyle(PocketColor.textPrimary)
        }
    }

    // MARK: - Derived text

    /// `Album · Year`, omitting whichever half is unknown (empty when neither is set).
    var albumLine: String {
        [song.album.isEmpty ? nil : song.album, song.year.map(String.init)]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    var tempoText: String {
        song.bpm.map { "\($0) BPM" } ?? "—"
    }

    /// The injected replacer, or the plain one for a caller with no audio engine to quiet first
    /// (ADR 0152).
    func replace(_ url: URL) async throws -> SongRelinker.Outcome {
        if let replaceAudio { return try await replaceAudio(url) }
        return try await SongRelinker.replace(audioAt: url, on: song, in: modelContext)
    }
    /// "Build a routine for this song" (ADR 0111) — a **Pro** action, since it materialises a real
    /// `Routine` (ADR 0112). A free player keeps the row tappable so it can open the paywall; only a
    /// song with nothing linked disables it. In an extension to keep the view under the body cap.
    @ViewBuilder
    var buildRoutineButton: some View {
        Button {
            guard AccessPolicy.canAuthorRoutine(isPro: isPro) else {
                return presentPaywall(.routine(.generate))
            }
            buildingRoutine = true
        } label: {
            Label("Build a routine for this song",
                  systemImage: isPro ? "wand.and.stars" : "lock.fill")
                .foregroundStyle(canBuildRoutine ? PocketColor.practice : PocketColor.textSecondary)
        }
        .disabled(isPro && !canBuildRoutine)
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
