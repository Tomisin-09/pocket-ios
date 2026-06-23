import SwiftUI

// Edit sheets for loops and markers (brief: native system sheets). Tapping a
// row in the Loops/Markers panels presents these. They take a snapshot of the
// item, edit local copies, and hand the result back via `onSave` / `onDelete`
// so the screen owns the source of truth.

struct LoopEditSheet: View {
    /// The persisted loop — edits apply straight to it on Done (so Cancel discards).
    let loop: Loop
    /// The loop's auto (start-order) colour, for the "Auto" swatch (ADR 0031).
    let autoColor: Color
    let onDelete: () -> Void
    /// Enter Fine mode on the waveform to adjust this loop's bounds.
    let onAdjustRange: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var colorChoice: LoopColorChoice
    // Structured practice fields (ADR 0036 slice 3) — edited as local copies, written
    // back on Done so Cancel discards.
    @State private var mastery: Int
    @State private var focus: Int
    @State private var commandTempo: Double
    @State private var loopType: LoopType

    init(loop: Loop, autoColor: Color,
         onDelete: @escaping () -> Void, onAdjustRange: @escaping () -> Void) {
        self.loop = loop
        self.autoColor = autoColor
        self.onDelete = onDelete
        self.onAdjustRange = onAdjustRange
        _name = State(initialValue: loop.name)
        _colorChoice = State(initialValue: Self.choice(for: loop))
        _mastery = State(initialValue: loop.mastery)
        _focus = State(initialValue: loop.focus)
        _commandTempo = State(initialValue: loop.commandTempo)
        _loopType = State(initialValue: loop.loopType)
    }

    /// Map the loop's stored colour fields to a picker choice (custom wins over palette).
    private static func choice(for loop: Loop) -> LoopColorChoice {
        if let hex = loop.customColorHex { return .custom(hex) }
        if let index = loop.colorIndex { return .palette(index) }
        return .auto
    }

    /// True when the chosen custom colour is low-contrast on the dark background — an
    /// advisory warning only; the colour is still allowed (ADR 0031).
    private var lowContrast: Bool {
        guard case .custom(let hex) = colorChoice, let color = HexColor.color(from: hex) else { return false }
        return !ColorContrast.isLegible(foreground: HexColor.components(of: color),
                                        background: HexColor.components(of: PocketColor.background))
    }

    /// Write the picked choice back to the loop's colour fields (custom and palette are
    /// mutually exclusive; auto clears both).
    private func applyColorChoice() {
        switch colorChoice {
        case .auto:
            loop.colorIndex = nil
            loop.customColorHex = nil
        case .palette(let index):
            loop.colorIndex = index
            loop.customColorHex = nil
        case .custom(let hex):
            loop.customColorHex = hex
            loop.colorIndex = nil
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    ClearableTextField("Loop name", text: $name)
                }
                Section("Range") {
                    LabeledContent("Loop") {
                        Text("\(timecode(loop.startSeconds))–\(timecode(loop.endSeconds))")
                            .font(.pocketMono(.body))
                    }
                    Button {
                        dismiss()
                        onAdjustRange()
                    } label: {
                        Label("Adjust range on waveform", systemImage: "slider.horizontal.below.rectangle")
                    }
                }
                practiceSection
                Section {
                    LoopColorPicker(autoColor: autoColor, choice: $colorChoice)
                } header: {
                    Text("Colour")
                } footer: {
                    if lowContrast {
                        Label("Low contrast on the dark background", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                Section {
                    Button("Delete loop", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit loop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        loop.name = name              // mutating the @Model persists
                        loop.mastery = mastery
                        loop.focus = focus
                        loop.commandTempo = commandTempo
                        loop.loopType = loopType
                        applyColorChoice()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Practice fields (ADR 0036)

    private var practiceSection: some View {
        Section("Practice") {
            masteryRow
            focusRow
            Picker("Type", selection: $loopType) {
                ForEach(LoopType.pickerOrder) { type in
                    Text(type.label).tag(type)
                }
            }
            .foregroundStyle(PocketColor.textSecondary)
            commandTempoRow
        }
    }

    /// Mastery as a 0–5 dot rating. Tap a dot to set that value; tapping the highest
    /// filled dot clears it by one, so you can walk back down to 0 (unrated).
    private var masteryRow: some View {
        LabeledContent("Mastery") {
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { value in
                    Circle()
                        .fill(value <= mastery ? PocketColor.marker : PocketColor.barDefault)
                        .frame(width: 18, height: 18)
                        .onTapGesture { mastery = (mastery == value) ? value - 1 : value }
                        .accessibilityLabel("Set mastery to \(value)")
                }
            }
        }
    }

    /// Practice intent 1–3 as a segmented control. Stored as `Int` per ADR 0036 (the
    /// planner reads the raw value); the labels live here, in the presentation layer.
    private var focusRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Focus").foregroundStyle(PocketColor.textSecondary)
            Picker("Focus", selection: $focus) {
                Text("Backburner").tag(1)
                Text("Active").tag(2)
                Text("Sharpening").tag(3)
            }
            .pickerStyle(.segmented)
        }
    }

    /// Command tempo as a percentage of original (ADR 0036) — the fastest tempo you own
    /// the loop at, distinct from the current practice `speed`.
    private var commandTempoRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Command tempo") {
                Text("\(Int((commandTempo * 100).rounded()))%")
                    .font(.pocketMono(.body))
                    .foregroundStyle(PocketColor.textPrimary)
            }
            Slider(value: $commandTempo, in: 0.25...1.5, step: 0.05)
        }
    }
}

/// Name a freshly-dropped marker. Just a name — its position is the playhead and
/// Cancel discards it (so no position readout, no delete). Editing an *existing*
/// marker uses the fuller `MarkerEditSheet`.
struct MarkerNameSheet: View {
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    ClearableTextField("Name this marker", text: $name)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit { save() }
                }
            }
            .navigationTitle("New marker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
        .presentationDetents([.height(180)])
        .onAppear { nameFocused = true }
    }

    private func save() {
        onSave(name)
        dismiss()
    }
}

struct MarkerEditSheet: View {
    let marker: Marker
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var label: String

    init(marker: Marker, onDelete: @escaping () -> Void) {
        self.marker = marker
        self.onDelete = onDelete
        _label = State(initialValue: marker.label)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    ClearableTextField("Marker name", text: $label)
                }
                Section("Position") {
                    LabeledContent("At") {
                        Text(timecode(marker.seconds)).font(.pocketMono(.body))
                    }
                }
                Section {
                    Button("Delete marker", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit marker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        marker.label = label
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview("Edit loop") {
    let song = Song.sample()
    let loop = Loop(name: "Verse riff", start: 0.2, end: 0.35, speed: 0.85, repeats: 4)
    loop.song = song
    loop.mastery = 3
    loop.focus = 2
    loop.commandTempo = 0.85
    loop.loopType = .riff
    return LoopEditSheet(loop: loop, autoColor: PocketColor.marker,
                         onDelete: {}, onAdjustRange: {})
        .preferredColorScheme(.dark)
}
