import SwiftData
import SwiftUI

/// A read-first **song details** view, opened by holding the title on the practice
/// screen (workstream 5). It reads as a descriptive overview rather than a form of editable
/// fields, in the categories every detail sheet shares (ADR 0258): what you glance at stays on
/// the sheet — the title, a key · tempo · length line, the mastery, **About** (the notes) and
/// **Practise** — and the rest sits behind rows that each say what is behind them: **Progress**,
/// **References**, **Audio file**, **Collections**. Editing the structured facts is one tap away via **Edit**,
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
    /// Pause the practice screen's waveform before the song map opens a piece in ear training (ADR 0232),
    /// which plays the loop itself. A no-op from the library, where nothing else is playing.
    let onOpenNestedAudio: () -> Void
    /// Close this sheet and show the song's waveform, for the song map's *Set the tempo and the 1* (ADR
    /// 0232 D7). The practice screen just closes the sheet; the library closes it and opens the song.
    let onShowWaveform: (() -> Void)?

    init(song: Song, replaceAudio: ((URL) async throws -> SongRelinker.Outcome)? = nil,
         onOpenNestedAudio: @escaping () -> Void = {}, onShowWaveform: (() -> Void)? = nil) {
        self.song = song
        self.replaceAudio = replaceAudio
        self.onOpenNestedAudio = onOpenNestedAudio
        self.onShowWaveform = onShowWaveform
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) var modelContext
    /// Every exercise, to offer in the link picker (ADR 0111). Sorted by name, like the library.
    /// Candidates for the "Link exercises" picker. Loaded when *that* picker opens, not when
    /// this sheet does — it was a `@Query` for every `Exercise`, run on the main thread during
    /// presentation, and this sheet is opened by holding the title on the practice screen while
    /// audio plays. Most openings never touch the picker at all.
    @State var exerciseCandidates: [Exercise] = []
    @State var showingExercisePicker = false
    @State var buildingRoutine = false
    /// The linked drill being opened for a run. The link is a route, not just a label (ADR 0172):
    /// the app already knows this exercise is *for* this song, so reading it here and then making
    /// you go and find it in the exercise library is a fact it declines to act on.
    @State var openingExercise: Exercise?
    /// **Map the song** (ADR 0232 D1), open full screen over this sheet.
    @State var mappingSong = false
    /// The map asked for the waveform: once it has closed, this sheet goes too.
    @State private var showWaveformAfterMap = false
    @State private var editing = false
    // Inline notes editing: a local draft committed on Update, so the read view only
    // changes when you explicitly save (not keystroke-by-keystroke).
    @State private var editingNotes = false
    @State private var draftComment = ""
    @FocusState private var notesFocused: Bool
    @State private var savedPulse = false

    var body: some View {
        NavigationStack {
            KeyboardFollowingScroll {
                Form {
                    headerSection
                    // The notes sit directly under the header — the song's free-text standing
                    // facts (tuning, capo…), the song-scope half of the notes/journal feature
                    // (ADR 0038). Always shown so they're discoverable. Headed **About** (ADR 0258).
                    notesSection
                    practiseSection
                    categoriesSection
                }
            }
            .navigationTitle("Song details")
            .navigationBarTitleDisplayMode(.inline)
            // Full screen, not pushed inside this sheet: the board is wide, and on iPad a sheet is a narrow
            // card (ADR 0232 D1). At the `NavigationStack`, never on the row inside the `Form`.
            .fullScreenCover(isPresented: $mappingSong, onDismiss: {
                guard showWaveformAfterMap else { return }
                showWaveformAfterMap = false
                onShowWaveform?()
            }, content: {
                SongMapView(song: song, onOpenNestedAudio: onOpenNestedAudio,
                            onShowWaveform: onShowWaveform == nil ? nil : {
                                showWaveformAfterMap = true
                                mappingSong = false
                            })
            })
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
                                  defaultName: SongRoutineBuilder.defaultName(for: song),
                                  // A song's routine is a recipe: Start keeps it (ADR 0243 D1).
                                  startsAs: .saved)
            }
            // A linked drill opens its run screen, pushed inside this sheet the same way "Build a
            // routine" is — so the back chevron returns to the song you came from. Bool-bound, not
            // `.navigationDestination(item:)`: a model's `persistentModelID` can flip on a save and
            // item-based presentation reads that as an identity change and pops (ADR 0090).
            // Attached here at the `NavigationStack`, never inside the `Form` — a presentation
            // raised from a row inside this sheet's form dismisses *this* sheet (see
            // `ReferenceLinkEditing`).
            .navigationDestination(isPresented: Binding(get: { openingExercise != nil },
                                                        set: { if !$0 { openingExercise = nil } })) {
                // Through `ExerciseRunScreen`, never `ExerciseRunView` — it is the one place that
                // decides which run screen a drill gets, so a freeform block gets its own (ADR 0136).
                if let exercise = openingExercise { ExerciseRunScreen(exercise: exercise) }
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
                if !factsLine.isEmpty {
                    Text(factsLine)
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.textPrimary)
                        .padding(.top, 6)
                }
                // Nothing to rate until there is a loop, so a song without one says nothing here;
                // Progress still says *Unrated*.
                if !song.loops.isEmpty { masteryLine }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }
    }

    /// The dots, what they're made of and the speed beside them — two axes side by side, never one
    /// number (ADR 0250 D8). Unrated is a word, not five empty dots (ADR 0039).
    private var masteryLine: some View {
        HStack(spacing: 8) {
            if let mastery = song.mastery { MasteryDots(filled: mastery, size: 8) }
            Text(masteryCaption)
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .padding(.top, 2)
    }

    private var notesSection: some View {
        Section {
            if editingNotes {
                TextField("Tuning, capo, anything worth remembering…",
                          text: $draftComment, axis: .vertical)
                    .lineLimit(1...8)
                    .foregroundStyle(PocketColor.textPrimary)
                    .onAppear { notesFocused = true }   // open the keyboard on entry
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
                Text("About")
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
}

/// Row builders, derived text and the replace seam — in an extension so they don't count against
/// the view's body-length cap.
extension SongDetailsSheet {

    // MARK: - Derived text

    /// `Album · Year`, omitting whichever half is unknown (empty when neither is set).
    var albumLine: String {
        [song.album.isEmpty ? nil : song.album, song.year.map(String.init)]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    /// `F# Minor · 83 BPM · 3:24` — whatever of the three is known (`DetailSheetText.facts`).
    var factsLine: String {
        DetailSheetText.facts(key: song.musicalKey == .unknown ? nil : song.musicalKey.displayName,
                              tempo: song.bpm.map { "\($0) BPM" },
                              length: song.duration > 0 ? timecode(song.duration) : nil)
    }

    /// `3 of 4 loops rated · slowest 70%`, or `Unrated` before any loop has a mastery.
    var masteryCaption: String {
        let rating = song.mastery == nil
            ? "Unrated"
            : MasteryRollup.ratedLabel(rated: song.ratedLoopCount, of: song.loops.count)
        return [rating, song.speedReading?.stripLabel].compactMap { $0 }.joined(separator: " · ")
    }

    /// The injected replacer, or the plain one for a caller with no audio engine to quiet first
    /// (ADR 0152).
    func replace(_ url: URL) async throws -> SongRelinker.Outcome {
        if let replaceAudio { return try await replaceAudio(url) }
        return try await SongRelinker.replace(audioAt: url, on: song, in: modelContext)
    }
}
