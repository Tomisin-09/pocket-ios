import SwiftUI

/// The **movable-shape authoring sheet** (ADR 0084 slice 2, M2) — "pick a shape, choose a root, and
/// it lands as a chord." A family picker (E-shape / A-shape) and a quality menu select a `ChordGrip`
/// from the curated Tier 1–2 set (M3); a root menu slides it up the neck; a live `ChordDiagramView`
/// shows the generated voicing at its fret with the shape-family label, making the movable-shape idea
/// concrete without a table. Confirming hands the generated `ChordVoicing` back to the caller, which
/// mixes it inline with open shapes (M2).
///
/// **No slide animation.** Unlike a run (ADR 0083 S8), a chord progression never physically slides
/// between chords — you form each barre at its fret — so there is no in-performance motion to teach.
/// The movable idea is a *conceptual* one, carried statically by the shape-family label + the
/// diagram's "n fr." caption ("this E-shape, moved so its root is G, is G7"). M6's shared cue resolves
/// to a label for the chord case; the arrow/animation belongs to runs.
struct MovableChordSheet: View {
    /// Called with the generated voicing when the player confirms.
    let onInsert: (ChordVoicing) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var rootString: ChordGrip.RootString = .eRoot
    @State private var quality: ChordGrip.Quality = .major
    @State private var rootPitchClass: Int = 7   // G — a friendly default that lands mid-neck

    /// Root names in menu order starting at C (pitch class 0 … 11), the way a key is spoken.
    private let rootNames = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]

    /// The qualities the chosen family offers, in curated order (sus2 is A-shape only, M3).
    private var qualities: [ChordGrip.Quality] {
        ChordGrip.curated.filter { $0.rootString == rootString }.map(\.quality)
    }

    /// The grip for the current family + quality (always present — the pickers only offer valid pairs).
    private var grip: ChordGrip? {
        ChordGrip.curated.first { $0.rootString == rootString && $0.quality == quality }
    }
    private var voicing: ChordVoicing? { grip?.voicing(rootPitchClass: rootPitchClass) }

    var body: some View {
        NavigationStack {
            Form {
                shapeSection
                rootSection
                previewSection
            }
            .navigationTitle("Movable shape")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Insert") {
                        if let voicing { onInsert(voicing) }
                        dismiss()
                    }
                    .disabled(voicing == nil)
                }
            }
        }
        .tint(PocketColor.practice)
        .presentationDetents([.medium, .large])
        .hearStopsOnDisappear()
    }

    // MARK: - Shape (family + quality)

    private var shapeSection: some View {
        Section {
            Picker("Shape", selection: $rootString) {
                Text("E-shape").tag(ChordGrip.RootString.eRoot)
                Text("A-shape").tag(ChordGrip.RootString.aRoot)
            }
            .pickerStyle(.segmented)
            .onChange(of: rootString) { _, _ in
                // Keep the quality valid for the new family (sus2 is A-shape only) — fall back to Major,
                // which every family offers.
                if !qualities.contains(quality) { quality = .major }
            }

            Picker("Quality", selection: $quality) {
                ForEach(qualities, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("Shape")
        } footer: {
            Text("A movable barre grip — the same fingering slid along the neck. Pick a root below and "
                + "it becomes that chord.")
                .font(.futura(.footnote))
        }
    }

    // MARK: - Root

    private var rootSection: some View {
        Section("Root") {
            Picker("Root note", selection: $rootPitchClass) {
                ForEach(rootNames.indices, id: \.self) { pitchClass in
                    Text(rootNames[pitchClass]).tag(pitchClass)
                }
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: - Live preview

    @ViewBuilder private var previewSection: some View {
        if let voicing, let grip {
            Section {
                HStack(spacing: 18) {
                    ChordDiagramView(voicing: voicing, tint: PocketColor.practice)
                        .frame(width: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(voicing.name)
                            .font(.futura(.title3, weight: .semibold))
                            .foregroundStyle(PocketColor.textPrimary)
                        Text("\(grip.name) · \(fretCaption(voicing))")
                            .font(.futura(.subheadline))
                            .foregroundStyle(PocketColor.textSecondary)
                        // The reverse-lookup reading (ADR 0093), confirming the movable idea in theory
                        // terms ("this E-shape at G spells G7"). Always shown here as reassurance.
                        ChordIdentityCaption(voicing: voicing)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.clear)

                // Sound the generated shape as you slide it up the neck (ADR 0097 Slice 2) — a block
                // chord through the shared `ToneEngine`, so the movable idea is audible, not just drawn.
                ChordHearButton(voicing: voicing, style: .bordered, tint: PocketColor.practice)
                    .listRowBackground(Color.clear)
            }
        }
    }

    /// "open position" when the grip sits at the nut, otherwise "fret n" — the fret its root lands on.
    private func fretCaption(_ voicing: ChordVoicing) -> String {
        guard let low = voicing.lowestFret else { return "open position" }
        return "fret \(low)"
    }
}

#Preview("Movable chord sheet") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            MovableChordSheet { _ in }
                .preferredColorScheme(.dark)
        }
}
