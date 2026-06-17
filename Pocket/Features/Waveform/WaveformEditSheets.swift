import SwiftUI

// Edit sheets for loops and markers (brief: native system sheets). Tapping a
// row in the Loops/Markers panels presents these. They take a snapshot of the
// item, edit local copies, and hand the result back via `onSave` / `onDelete`
// so the screen owns the source of truth.

struct LoopEditSheet: View {
    let loop: WaveformMock.Loop
    let onSave: (WaveformMock.Loop) -> Void
    let onDelete: () -> Void
    /// Enter Fine mode on the waveform to adjust this loop's bounds.
    let onAdjustRange: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var speed: Double
    @State private var repeats: Int

    init(loop: WaveformMock.Loop,
         onSave: @escaping (WaveformMock.Loop) -> Void,
         onDelete: @escaping () -> Void,
         onAdjustRange: @escaping () -> Void) {
        self.loop = loop
        self.onSave = onSave
        self.onDelete = onDelete
        self.onAdjustRange = onAdjustRange
        _name = State(initialValue: loop.name)
        _speed = State(initialValue: loop.speed)
        _repeats = State(initialValue: loop.repeats)
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
                Section("Playback") {
                    VStack(alignment: .leading) {
                        LabeledContent("Speed") {
                            Text(String(format: "%.2f×", speed)).font(.pocketMono(.body))
                        }
                        Slider(value: $speed, in: 0.25...2.0, step: 0.05)
                            .tint(PocketColor.active)
                    }
                    Stepper("Repeats: \(repeats)", value: $repeats, in: 1...16)
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
                        var updated = loop
                        updated.name = name
                        updated.speed = speed
                        updated.repeats = repeats
                        onSave(updated)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
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
    let marker: WaveformMock.Marker
    let onSave: (WaveformMock.Marker) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var label: String

    init(marker: WaveformMock.Marker,
         onSave: @escaping (WaveformMock.Marker) -> Void,
         onDelete: @escaping () -> Void) {
        self.marker = marker
        self.onSave = onSave
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
                        var updated = marker
                        updated.label = label
                        onSave(updated)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
