import SwiftUI

/// The **chord-progression authoring editor** (ADR 0065): build the sequence of chords the drill
/// changes through and how long each is held. A thin skin over the pure `ChordProgression` editing
/// helpers (append / replace / re-beat / remove, T5) — every control just calls one and writes the
/// result back through the binding, so there's no editing state to keep in sync.
///
/// Each row shows the voicing's diagram, a menu to swap it for any library shape, a stepper for its
/// hold in beats, and a remove control (never below one chord). "Add chord" appends from the same
/// library. Buttons carry `.borderless` so a tap hits only its own control, not every button in the
/// Form row (the sibling-button gotcha, learned on the fretboard editors).
struct ChordProgressionEditor: View {
    @Binding var progression: ChordProgression

    /// Root names in menu order starting at C (pitch class 0 … 11), the way a key is spoken.
    private let rootNames = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            keyPicker
            Divider()
            ForEach(Array(progression.changes.enumerated()), id: \.offset) { index, change in
                changeRow(index: index, change: change)
                if index < progression.changeCount - 1 { Divider() }
            }
            addMenu
        }
        .padding(.vertical, 4)
    }

    /// Sets the key the Roman-numeral badges read against — an Auto option (infer from the first
    /// chord) plus every root, and a major/minor toggle.
    private var keyPicker: some View {
        HStack(spacing: 10) {
            Text("Key").font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
            Spacer(minLength: 0)
            Menu {
                Button("Auto") { progression.keyRoot = nil }
                ForEach(rootNames.indices, id: \.self) { root in
                    Button(rootNames[root]) { progression.keyRoot = root }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(keyRootLabel).font(.futura(.subheadline, weight: .semibold))
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
                .foregroundStyle(PocketColor.practice)
            }
            .buttonStyle(.borderless)
            Picker("", selection: $progression.keyIsMinor) {
                Text("Major").tag(false)
                Text("Minor").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 140)
        }
    }

    private var keyRootLabel: String {
        guard let root = progression.keyRoot else { return "Auto" }
        return rootNames[((root % 12) + 12) % 12]
    }

    private func changeRow(index: Int, change: ChordChange) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ChordDiagramView(voicing: change.voicing, tint: PocketColor.practice,
                             degreeLabel: progression.numeral(for: change.voicing))
                .frame(width: 56)
            VStack(alignment: .leading, spacing: 8) {
                voicingMenu(index: index, current: change.voicing)
                beatsStepper(index: index, change: change)
            }
            Spacer(minLength: 0)
            Button(role: .destructive) {
                progression = progression.removingChange(at: index)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(progression.changeCount <= 1)
        }
    }

    private func voicingMenu(index: Int, current: ChordVoicing) -> some View {
        Menu {
            ForEach(ChordVoicing.library) { voicing in
                Button(voicing.name) {
                    progression = progression.replacingVoicing(at: index, with: voicing)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(current.name).font(.futura(.subheadline, weight: .semibold))
                Image(systemName: "chevron.up.chevron.down").font(.caption2)
            }
            .foregroundStyle(PocketColor.practice)
        }
        .buttonStyle(.borderless)
    }

    private func beatsStepper(index: Int, change: ChordChange) -> some View {
        Stepper(value: Binding(
            get: { change.beats },
            set: { progression = progression.settingBeats(at: index, to: $0) }
        ), in: 1...16) {
            Text(beatsLabel(change.beats))
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
    }

    private var addMenu: some View {
        Menu {
            ForEach(ChordVoicing.library) { voicing in
                Button(voicing.name) { progression = progression.appending(voicing) }
            }
        } label: {
            Label("Add chord", systemImage: "plus.circle.fill")
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.practice)
        }
        .buttonStyle(.borderless)
    }

    /// "4 beats" — or "4 beats · 1 bar" when the hold is a whole number of 4/4 bars, the way players
    /// count changes.
    private func beatsLabel(_ beats: Int) -> String {
        guard beats % 4 == 0 else { return "\(beats) beats" }
        let bars = beats / 4
        return "\(beats) beats · \(bars) bar\(bars == 1 ? "" : "s")"
    }
}

#Preview("Chord progression editor") {
    struct Harness: View {
        @State private var progression = ChordProgression.gMajorPop
        var body: some View {
            Form {
                Section("Chord progression") {
                    ChordProgressionEditor(progression: $progression)
                        .listRowBackground(Color.clear)
                }
            }
            .tint(PocketColor.practice)
        }
    }
    return Harness().preferredColorScheme(.dark)
}
