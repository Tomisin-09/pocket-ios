import SwiftUI

// MARK: - Your progressions (ADR 0218 D10)

extension ProgressionPickerSheet {
    var selectedSavedProgression: SavedProgression? {
        guard case .saved(let uid) = source else { return nil }
        return savedProgressions.first { $0.uid == uid }
    }

    /// The player's own progressions above the built-in ones, and the way to write one without leaving
    /// the drill. Insert-only here — editing and deleting live in Toolkit → *My progressions*.
    @ViewBuilder
    var yourProgressionsSection: some View {
        Section {
            ForEach(savedProgressions) { progression in
                let steps = progression.steps
                progressionRow(ProgressionTemplate(id: progression.uid.uuidString, title: progression.name,
                                                   detail: steps.numerals, steps: steps),
                               isSelected: source == .saved(progression.uid),
                               identifier: "progression.saved.\(progression.uid.uuidString)") {
                    select(progression)
                }
            }
            // Presented from the body root (`Route`), not from here: saving inserts a row into this
            // section, and a sheet hung off a row in it loses the selection when the row is rebuilt.
            Button {
                route = .builder
            } label: {
                Label("New progression", systemImage: "plus")
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(PocketColor.practice)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("progression.new")
        } header: {
            Text("Your progressions")
        } footer: {
            Text(savedProgressions.isEmpty
                 ? "Write one once, then use it in any key."
                 : "Edit or delete these in Toolkit, under My progressions.")
        }
    }

    /// Select one of the player's progressions, in the key it was written in — a progression they wrote
    /// in D should open in D. The key row still moves it anywhere.
    func select(_ progression: SavedProgression) {
        source = .saved(progression.uid)
        if let written = progression.payload.tonic { tonic = written }
    }
}
