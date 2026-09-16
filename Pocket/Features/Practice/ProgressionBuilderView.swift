import SwiftData
import SwiftUI

/// **Write a progression** (ADR 0218 D10) — name it, say what key it's written in, and tap chords in:
/// the key's own chords in one row, any chord in another. Chord **names** lead and numerals follow, so a
/// player who doesn't read numerals taps G, C, D and has written I – IV – V without meeting a Roman
/// numeral first. A skin over `ProgressionDraft`, which does everything the controls ask.
///
/// Pushed from Toolkit → *My progressions* to write or edit one, and presented from *Use a progression*
/// to write one mid-drill (`showsCancel`, since a sheet has no back button).
struct ProgressionBuilderView: View {
    /// The progression being edited, or `nil` to write a new one.
    let progression: SavedProgression?
    var tint: Color = PocketColor.practice
    /// A sheet needs its own way out; a pushed screen has the back button.
    var showsCancel = false
    /// Told which progression was saved — the sheet selects it.
    var onSaved: (SavedProgression) -> Void = { _ in }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.Key.accidentalPreference) private var accidentalRaw = NoteSpelling.default.rawValue

    @State private var draft: ProgressionDraft
    /// The quality the *Any chord* row adds.
    @State private var quality: ChordGrip.Quality = .major
    @State private var confirmingDelete = false

    init(progression: SavedProgression? = nil, tint: Color = PocketColor.practice, showsCancel: Bool = false,
         onSaved: @escaping (SavedProgression) -> Void = { _ in }) {
        self.progression = progression
        self.tint = tint
        self.showsCancel = showsCancel
        self.onSaved = onSaved
        _draft = State(initialValue: progression?.draft ?? ProgressionDraft())
    }

    private var spelling: NoteSpelling { NoteSpelling(rawValue: accidentalRaw) ?? .default }
    private var key: ProgressionKey { draft.key }

    var body: some View {
        Form {
            Section("Name") {
                TextField("e.g. Verse changes", text: $draft.name)
                    .font(.futura(.body))
                    .accessibilityIdentifier("progression.builder.name")
            }
            keySection
            chordsSection
            inKeySection
            anyChordSection
            if progression != nil { deleteSection }
        }
        .navigationTitle(progression == nil ? "New progression" : "Edit progression")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCancel {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!draft.canSave)
                    .accessibilityIdentifier("progression.builder.save")
            }
        }
        .tint(tint)
        .confirmationDialog("Delete this progression?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Drills you've already filled from it keep their chords. This can't be undone.")
        }
    }

    // MARK: - Sections

    private var keySection: some View {
        Section {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<12, id: \.self) { pitch in
                            chip(ProgressionKey(tonic: pitch, isMinor: draft.steps.readsAsMinor)
                                    .label(preference: spelling),
                                 isSelected: pitch == draft.tonic) { draft.setTonic(pitch) }
                                .id(pitch)
                                .accessibilityIdentifier("progression.builder.key.\(pitch)")
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onAppear { proxy.scrollTo(draft.tonic, anchor: .center) }
            }
        } header: {
            Text("Written in")
        } footer: {
            Text("The key only changes how the chords are numbered — you can use the progression in any key.")
        }
    }

    private var chordsSection: some View {
        Section {
            if draft.steps.isEmpty {
                Text("No chords yet — tap one below.")
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            ForEach(Array(draft.steps.enumerated()), id: \.offset) { index, step in
                stepRow(index: index, step: step)
            }
        } header: {
            Text("Chords")
        } footer: {
            if !draft.steps.isEmpty { Text(draft.steps.numerals) }
        }
    }

    private func stepRow(index: Int, step: ProgressionStep) -> some View {
        let name = key.chordName(of: step, preference: spelling)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.futura(.headline, weight: .semibold))
                    .foregroundStyle(PocketColor.textPrimary)
                Text(step.numeral)
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .frame(minWidth: 58, alignment: .leading)
            Spacer(minLength: 4)
            Text(step.bars == 1 ? "1 bar" : "\(step.bars) bars")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
            Stepper("Bars", value: Binding(get: { step.bars }, set: { draft.setBars(at: index, to: $0) }),
                    in: 1...ProgressionDraft.maxBars)
                .labelsHidden()
                .accessibilityLabel("\(name), bars")
            VStack(spacing: 2) {
                nudge(index: index, by: -1, systemImage: "chevron.up", label: "Move \(name) up")
                nudge(index: index, by: 1, systemImage: "chevron.down", label: "Move \(name) down")
            }
            Button(role: .destructive) {
                draft.remove(at: index)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove \(name)")
        }
    }

    private func nudge(index: Int, by offset: Int, systemImage: String, label: String) -> some View {
        Button {
            draft.move(at: index, by: offset)
        } label: {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .frame(width: 26, height: 16)
        }
        .buttonStyle(.borderless)
        .disabled(!draft.steps.indices.contains(index + offset))
        .accessibilityLabel(label)
    }

    private var inKeySection: some View {
        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(Array(ProgressionDraft.inKey.enumerated()), id: \.offset) { _, step in
                    let name = key.chordName(of: step, preference: spelling)
                    Button {
                        draft.append(step)
                        haptic(.light)
                    } label: {
                        paletteLabel(name: name, detail: step.numeral)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Add \(name), \(step.numeral)")
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Chords in the key")
        }
    }

    private var anyChordSection: some View {
        Section {
            Picker("Chord type", selection: $quality) {
                ForEach(ChordGrip.Quality.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(0..<12, id: \.self) { semitones in
                    let step = ProgressionStep(semitones, quality)
                    let name = key.chordName(of: step, preference: spelling)
                    Button {
                        draft.append(step)
                        haptic(.light)
                    } label: {
                        paletteLabel(name: name, detail: step.numeral)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Add \(name), \(step.numeral)")
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Any chord")
        } footer: {
            Text("Choose a chord type, then tap its root.")
        }
    }

    private var deleteSection: some View {
        Section {
            Button("Delete progression", role: .destructive) { confirmingDelete = true }
        }
    }

    // MARK: - Pieces

    private func chip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            haptic(.light)
        } label: {
            Text(label)
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(isSelected ? PocketColor.background : PocketColor.textPrimary)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(Capsule().fill(isSelected ? tint : PocketColor.surfaceStandard))
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Written in \(label)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// A palette button — the chord's name big, its numeral small beneath.
    private func paletteLabel(name: String, detail: String) -> some View {
        VStack(spacing: 1) {
            Text(name)
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(.futura(.caption2))
                .foregroundStyle(PocketColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(PocketColor.surfaceSubtle))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(PocketColor.surfaceBorder, lineWidth: 1))
    }

    // MARK: - Actions

    private func save() {
        guard draft.canSave else { return }
        if let progression {
            progression.update(from: draft)
            onSaved(progression)
        } else {
            let written = SavedProgression(draft)
            modelContext.insert(written)
            onSaved(written)
        }
        dismiss()
    }

    private func delete() {
        guard let progression else { return }
        modelContext.delete(progression)
        dismiss()
    }
}
