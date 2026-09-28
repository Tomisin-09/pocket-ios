import SwiftUI

// The marker edit sheet (split from `WaveformEditSheets.swift`, which holds the loop sheet).
// Tapping-and-holding a row in the Markers panel presents this, and so does tapping a section heading
// or a pin on the song map (ADR 0232 D6). It edits a local copy and writes back on Done so Cancel
// discards.

struct MarkerEditSheet: View {
    let marker: Marker
    /// `nil` hides **Delete marker**: the song map opens this sheet too, and deleting is the waveform's,
    /// where it can be undone.
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var label: String
    @State private var startsSection: Bool

    init(marker: Marker, onDelete: (() -> Void)?) {
        self.marker = marker
        self.onDelete = onDelete
        _label = State(initialValue: marker.label)
        _startsSection = State(initialValue: marker.startsSection)
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
                    Toggle("Starts a section", isOn: $startsSection)
                } footer: {
                    Text("Sections head the rows of Map the song, in Song details. Other markers stay as pins.")
                }
                if let onDelete {
                    Section {
                        Button("Delete marker", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
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
                        marker.startsSection = startsSection
                        dismiss()
                    }
                }
            }
        }
        // Large as well since **Starts a section** (ADR 0232): at medium, Delete sat under the fold.
        .presentationDetents([.medium, .large])
    }
}
