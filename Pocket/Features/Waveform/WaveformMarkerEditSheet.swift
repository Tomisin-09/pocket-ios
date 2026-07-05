import SwiftUI

// The marker edit sheet (split from `WaveformEditSheets.swift`, which holds the loop sheet).
// Tapping-and-holding a row in the Markers panel presents this; it edits a local copy and
// writes back on Done so Cancel discards.

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
