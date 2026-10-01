import SwiftUI

/// **§ Section** open under the strip (ADR 0235 D4): start a section at the lit chip, or rename the one there,
/// from the usual names or the player's own; or take its heading off, which keeps its bar line.
struct TabSectionNamer: View {
    /// Where it acts: a note, or the note count for the next note written.
    let position: Int
    let count: Int
    /// The heading already there, if any.
    let current: String?
    let onSave: (String) -> Void
    let onRemove: () -> Void
    let onCancel: () -> Void

    @State private var typed = ""

    private var heading: String {
        let place = position < count ? "at note \(position + 1)" : "with the next note you write"
        return current == nil ? "Start a section \(place)" : "Rename the section that starts \(place)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(heading)
                .font(.futura(.footnote, weight: .semibold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(TabContent.sectionNames, id: \.self) { name in
                    Button { onSave(name) } label: {
                        Text(name)
                            .font(.futura(.footnote, weight: name == current ? .bold : nil))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityAddTraits(name == current ? .isSelected : [])
                }
            }
            HStack(spacing: 8) {
                TextField("Or type a name", text: $typed)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit(saveTyped)
                    .accessibilityIdentifier("tab.sectionName")
                Button("Save", action: saveTyped)
                    .disabled(typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            HStack {
                if current != nil {
                    Button("Take the heading off", role: .destructive, action: onRemove)
                        .font(.futura(.footnote, weight: .semibold))
                }
                Spacer()
                Button("Cancel", action: onCancel)
                    .font(.futura(.footnote))
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(PocketColor.surfaceSubtle))
        .onAppear { typed = current.map { TabContent.sectionNames.contains($0) ? "" : $0 } ?? "" }
    }

    private func saveTyped() {
        let name = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        onSave(name)
    }
}
