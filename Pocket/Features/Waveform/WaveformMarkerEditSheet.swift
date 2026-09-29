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
    @State private var sameAs: UUID?

    init(marker: Marker, onDelete: (() -> Void)?) {
        self.marker = marker
        self.onDelete = onDelete
        _label = State(initialValue: marker.label)
        _startsSection = State(initialValue: marker.startsSection)
        _sameAs = State(initialValue: marker.sameAsUID)
    }

    /// The sections this one can repeat (ADR 0232 D8): only earlier ones, so a chain can't loop back.
    private var earlierSections: [Marker] {
        (marker.song?.markers ?? [])
            .filter { $0.startsSection && $0.uid != marker.uid && $0.seconds < marker.seconds - 0.01 }
            .sorted { $0.seconds < $1.seconds }
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
                    if startsSection, !earlierSections.isEmpty { sameAsPicker }
                } footer: {
                    Text(startsSection && !earlierSections.isEmpty
                         ? "Sections head the rows of Map the song, in Song details. Same as writes this section "
                           + "as a repeat of an earlier one, the way a chart does."
                         : "Sections head the rows of Map the song, in Song details. Other markers stay as pins.")
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
                        // Only a section repeats one; a marker that stops starting one lets go of it.
                        marker.sameAsUID = startsSection ? sameAs : nil
                        dismiss()
                    }
                }
            }
        }
        // Large as well since **Starts a section** (ADR 0232): at medium, Delete sat under the fold.
        .presentationDetents([.medium, .large])
    }

    /// *Verse 2, as Verse 1* (ADR 0232 D8): the player's word that this section repeats an earlier one.
    private var sameAsPicker: some View {
        // A section named before it moved, or stopped starting one, reads as None rather than a blank.
        let selection = Binding<UUID?>(get: { earlierSections.contains { $0.uid == sameAs } ? sameAs : nil },
                                       set: { sameAs = $0 })
        return Picker("Same as", selection: selection) {
            Text("None").tag(UUID?.none)
            ForEach(earlierSections, id: \.uid) { section in
                Text("\(section.label.isEmpty ? "Section" : section.label) · \(timecode(section.seconds))")
                    .tag(UUID?.some(section.uid))
            }
        }
    }
}
