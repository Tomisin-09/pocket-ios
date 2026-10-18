import SwiftData
import SwiftUI

// The screens behind the exercise ⓘ sheet's rows (ADR 0258), pushed inside its `NavigationStack`.
// References is the shared `ReferencesScreen`. Each raises its presentations from its own `Form`
// (D3), so the pickers that had to live at the sheet's top level now live with the section they serve.
//
// Two kinds of write, as before: the mastery is part of the sheet's local state, committed on Done, so
// Progress takes a binding; songs, folders and skills write straight through, so their screens take the
// exercise.

/// **Exercise ⓘ › Progress**: the mastery you set, when you last practised it, and the tempo it has
/// moved through (ADR 0117). The rating is a binding into the sheet's copy, kept on Done.
struct ExerciseProgressScreen: View {
    @Binding var mastery: Int?
    let lastPracticed: Date?
    let reading: MasteryReading.Display?
    let trajectory: TempoTrajectory.Reading?
    let runCount: Int

    var body: some View {
        Form {
            ExerciseProgressSection(mastery: $mastery, lastPracticed: lastPracticed, reading: reading,
                                    trajectory: trajectory, runCount: runCount)
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// **Exercise ⓘ › Songs** (ADR 0111): the songs this drill is for. A song opens in the player only
/// where the host gave it somewhere to go (`onOpenSong`), and that tap closes the sheet, so the sheet
/// hands in a closure that commits its local edits first.
struct ExerciseSongsScreen: View {
    let exercise: Exercise
    var onOpenSong: ((Song) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Song.title) private var allSongs: [Song]
    @State private var showingSongPicker = false

    var body: some View {
        Form {
            Section {
                if exercise.linkedSongs.isEmpty {
                    Text("Not linked to any songs yet — link the songs this drill helps you play.")
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                } else {
                    // Keyed by `persistentModelID`, as every other `Song` list is — `Song` carries no
                    // `uid` of its own, and ADR 0090's rule is about *presentation* identity, which
                    // this isn't: the tap hands the song to the host through a closure rather than
                    // binding a `.sheet(item:)` to it.
                    ForEach(linkedSongsByTitle, id: \.persistentModelID) { song in
                        linkedSongRow(song)
                    }
                    .onDelete(perform: unlinkSongs)
                }
                Button { showingSongPicker = true } label: {
                    Label("Link songs", systemImage: "plus.circle")
                        .foregroundStyle(PocketColor.practice)
                }
            } footer: {
                Text("The songs this drill is for. Links show on the song too, and later seed a "
                     + "one-tap practice routine for it.")
            }
        }
        .navigationTitle("Songs")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSongPicker) {
            LinkPickerSheet(
                title: "Link songs",
                prompt: "Search songs",
                emptyCatalog: "No songs in your library yet.",
                candidates: allSongs,
                label: { $0.title.isEmpty ? "Untitled song" : $0.title },
                subtitle: { $0.artist.isEmpty ? nil : $0.artist },
                isLinked: { isLinked($0) },
                toggle: { toggleLink($0) },
                accent: PocketColor.practice)
        }
    }

    /// One linked song. Tappable only where the host supplied somewhere for it to go. Where it didn't,
    /// the row draws exactly as it always has, because a row that looks tappable and isn't is worse
    /// than one that never offered.
    @ViewBuilder
    private func linkedSongRow(_ song: Song) -> some View {
        if let onOpenSong {
            Button { onOpenSong(song) } label: {
                linkedSongLabel(song, showsChevron: true)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens this song in the player")
        } else {
            linkedSongLabel(song, showsChevron: false)
        }
    }

    private func linkedSongLabel(_ song: Song, showsChevron: Bool) -> some View {
        HStack(spacing: 8) {
            Text(song.title.isEmpty ? "Untitled song" : song.title)
                .foregroundStyle(PocketColor.textPrimary)
                .multilineTextAlignment(.leading)
            if !song.artist.isEmpty {
                Text(song.artist)
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            if showsChevron {
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.futura(.caption2, weight: .semibold))
                    .foregroundStyle(PocketColor.practice)
                    .accessibilityHidden(true)
            }
        }
    }

    private var linkedSongsByTitle: [Song] {
        exercise.linkedSongs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func isLinked(_ song: Song) -> Bool {
        exercise.linkedSongs.contains { $0.persistentModelID == song.persistentModelID }
    }

    private func toggleLink(_ song: Song) {
        if let index = exercise.linkedSongs.firstIndex(where: { $0.persistentModelID == song.persistentModelID }) {
            exercise.linkedSongs.remove(at: index)
        } else {
            exercise.linkedSongs.append(song)
        }
        try? modelContext.save()
    }

    private func unlinkSongs(at offsets: IndexSet) {
        let targets = offsets.map { linkedSongsByTitle[$0] }
        for song in targets {
            exercise.linkedSongs.removeAll { $0.persistentModelID == song.persistentModelID }
        }
        try? modelContext.save()
    }
}

/// **Exercise ⓘ › Folders** (ADR 0210 D9): where a drill is filed, and the door to changing it. A drill
/// can sit in several folders at once (D1/D2), so this is a list rather than a picker with one answer —
/// and the footer says so, because "folder" borrows the expectation of *move*, which is the one
/// expectation this design does not honour.
struct ExerciseFoldersScreen: View {
    let exercise: Exercise

    @Environment(\.modelContext) private var modelContext
    @State private var filingFolders = false

    var body: some View {
        Form {
            Section {
                if exercise.folders.isEmpty {
                    Text("Not in any folder.")
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                } else {
                    folderChips
                }
                Button { filingFolders = true } label: {
                    Label("Add to folder…", systemImage: "folder.badge.plus")
                        .font(.futura(.subheadline, weight: .semibold))
                        .foregroundStyle(PocketColor.practice)
                }
            } footer: {
                Text("Group drills however you like — by grade, by technique, by student. "
                     + "One drill can sit in as many folders as you want.")
            }
        }
        .navigationTitle("Folders")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $filingFolders) { foldersPicker }
    }

    private var folderChips: some View {
        FlowLayout(spacing: 6) {
            ForEach(exercise.folders, id: \.self) { path in
                Text(FolderPath.leaf(path))
                    .font(.futura(.caption, weight: .semibold))
                    .foregroundStyle(PocketColor.practice)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(PocketColor.practice.opacity(0.16)))
                    // The leaf is what you read; the trail is what tells two *Warm-ups* apart, so it
                    // belongs to the label rather than the chip.
                    .accessibilityLabel(path)
            }
        }
        .padding(.vertical, 2)
    }

    private var foldersPicker: some View {
        FolderPickerSheet(itemName: exercise.name.isEmpty ? "Untitled" : exercise.name,
                          current: exercise.folders,
                          namespace: PracticeFolderStore.namespace(in: modelContext),
                          onAdd: { PracticeFolderStore.file(exercise, into: $0, in: modelContext) },
                          onRemove: { exercise.folders = FolderPath.removing($0, from: exercise.folders) },
                          onCreate: { name in
            guard let created = PracticeFolderStore.createFolder(named: name, at: "",
                                                                 in: modelContext) else { return }
            PracticeFolderStore.file(exercise, into: created, in: modelContext)
        })
    }
}

/// **Exercise ⓘ › Feel & skills**: the meter and rhythm (read-only; changed in Edit shape), which skills
/// the drill works on (ADR 0216 D6) and its template (ADR 0068), each keeping its footer. Works on is the
/// one place a drill's skills change: the type sets a default, the player can narrow it or add to it,
/// and it is the same edit either way (D1). Rows are built in functions rather than inline in a
/// `Section`, because a modifier chain inline in a `Section` builder once segfaulted the routine editor.
struct ExerciseFeelScreen: View {
    let exercise: Exercise

    @Environment(\.modelContext) private var modelContext
    @Query private var customSkills: [CustomSkill]
    @State private var editingSkills = false
    @State private var skillOffered: [String] = []
    @State private var skillKept: Set<String> = []

    private var vocabulary: SkillVocabulary { SkillVocabulary(customSkills) }
    /// A freeform block carries an optional click instead of a rhythm (ADR 0136), on the sheet itself.
    private var isFreeform: Bool { exercise.template == .freeform }

    var body: some View {
        Form {
            if !isFreeform { feelSection }
            worksOnSection
            templateSection
        }
        .navigationTitle("Feel & skills")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editingSkills, onDismiss: commitSkills) {
            SkillPickerSheet(offeredSkillIDs: $skillOffered, keptSkillIDs: $skillKept,
                             defaults: Set(SkillAssociation.defaultSkills(for: exercise.template)),
                             requiresOne: hasTypeDefaults, title: "Works on")
        }
    }

    // MARK: - Feel (read-only)

    private var feelSection: some View {
        Section {
            LabeledContent("Time signature") {
                Text(exercise.timeSignatureLabel).font(.pocketMono(.body))
            }
            if let noteRate = exercise.noteRate {
                LabeledContent("Rhythm") { Text(noteRate.label) }
            }
        } header: {
            Text("Feel")
        } footer: {
            Text("Rhythm is how many notes you play per beat — what the command tempo is measured "
                 + "in. Change it in Edit shape and you'll be asked what should happen to that tempo.")
        }
    }

    // MARK: - Works on

    /// What the drill works on now — its stated skills or its type's, less any id that names nothing
    /// (a skill deleted elsewhere).
    private var workedOnSkills: [String] {
        vocabulary.resolvable(SkillAssociation.effectiveSkills(template: exercise.template,
                                                               stated: exercise.skillIDs))
    }

    /// Absent for a warm-up only: it works on nothing whatever is stored (ADR 0072). Basic and Freeform
    /// show it, empty until they say — they are exactly the drills that need to.
    @ViewBuilder private var worksOnSection: some View {
        if exercise.template != .warmup {
            Section {
                worksOnRows(workedOnSkills)
            } header: {
                Text("Works on")
            } footer: {
                Text(worksOnFooter)
            }
        }
    }

    @ViewBuilder private func worksOnRows(_ skills: [String]) -> some View {
        if skills.isEmpty { emptyWorksOnLine }
        ForEach(skills, id: \.self) { skillID in worksOnRow(skillID) }
        Button(action: beginEditingSkills) {
            Label(skills.isEmpty ? "Add skills" : "Change skills", systemImage: "plus.circle")
        }
        if isSetByPlayer && hasTypeDefaults {
            Button("Use its type’s skills", action: resetSkillsToType)
        }
    }

    private var emptyWorksOnLine: some View {
        Text("Nothing yet. Add a skill, and a goal on it can bring this drill into a session.")
            .font(.futura(.footnote))
            .foregroundStyle(PocketColor.textSecondary)
    }

    private func worksOnRow(_ skillID: String) -> some View {
        let name = vocabulary.name(skillID)
        return HStack(spacing: 8) {
            Text(name).foregroundStyle(PocketColor.textPrimary)
            Spacer(minLength: 8)
            InfoPopoverButton(subject: name, info: vocabulary.explanation(skillID))
        }
    }

    private var hasTypeDefaults: Bool { !SkillAssociation.defaultSkills(for: exercise.template).isEmpty }

    private var isSetByPlayer: Bool {
        SkillAssociation.isSetByPlayer(template: exercise.template, stated: exercise.skillIDs)
    }

    private var worksOnFooter: String {
        let reach = "A goal on any of these skills can bring this drill into a session."
        guard hasTypeDefaults else { return "What this drill is for. \(reach)" }
        if isSetByPlayer { return "Set by you. \(reach)" }
        return "From its type, \(exercise.template.displayName). Change them to narrow it or add more. \(reach)"
    }

    private func beginEditingSkills() {
        let current = workedOnSkills
        skillOffered = current
        skillKept = Set(current)
        editingSkills = true
    }

    /// Store what the picker closed on (D1). Written straight through, like the song links, rather than
    /// held for Done — the picker has a Done of its own.
    private func commitSkills() {
        let stored = SkillAssociation.storedSkills(kept: skillKept, template: exercise.template)
        guard stored != exercise.skillIDs else { return }
        exercise.skillIDs = stored
        try? modelContext.save()
    }

    private func resetSkillsToType() {
        exercise.skillIDs = []
        try? modelContext.save()
        haptic(.light)
    }

    // MARK: - Template (read-only, ADR 0068)

    /// Set at creation and **immutable**: changing it would mean a different renderer and a different
    /// authoring surface (delete and recreate to change type).
    private var templateSection: some View {
        Section {
            HStack(spacing: 8) {
                Text("Template").foregroundStyle(PocketColor.textPrimary)
                Spacer(minLength: 8)
                Label(exercise.template.displayName, systemImage: exercise.template.iconName)
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(PocketColor.practice)
            }
        } footer: {
            Text("The kind of drill, set when it was created. It groups the exercise in your "
                 + "library, decides the skills it works on, and can't be changed.")
        }
    }
}
