import SwiftUI

/// A line on a snag, from a hold on its row in the *Snags* panel (ADR 0238): the waveform's way to write
/// what *Name the notes* writes under its strip (ADR 0234 D7), and the same line, so either place shows
/// what the other wrote. One field and nothing else, because a snag has nothing else to set.
///
/// The words are a note in a loop's Journal, saved on **Save** rather than as you type: the sheet is the
/// whole edit, so **Cancel** can still take it back.
struct SnagLineSheet: View {
    let snag: Snag
    /// The line it has, from any of the song's loops.
    let line: JournalEntry?
    /// Where a new line goes (`SnagLine.home`); `nil` when no loop has the snag. Unused when it has a line,
    /// which stays where it was written.
    let home: Loop?
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: String
    @FocusState private var focused: Bool

    init(snag: Snag, line: JournalEntry?, home: Loop?, onSave: @escaping (String) -> Void) {
        self.snag = snag
        self.line = line
        self.home = home
        self.onSave = onSave
        _draft = State(initialValue: line?.text ?? "")
    }

    /// The loop whose Journal holds the line, or will.
    private var journalLoop: Loop? { line?.loop ?? home }

    var body: some View {
        NavigationStack {
            Form {
                if let loop = journalLoop {
                    Section {
                        TextField("What’s stopping you here?", text: $draft, axis: .vertical)
                            .lineLimit(2...6)
                            .focused($focused)
                            .accessibilityIdentifier("snag.lineField")
                    } footer: {
                        Text(footer(JournalOwner.loop(loop).displayName))
                    }
                } else {
                    // Only when the loop it was made under is gone and none covers it now (`SnagLine.home`).
                    Section {
                        Text("A line is kept in a loop’s Journal, and no loop covers this snag now. "
                             + "Make a loop over \(timecode(snag.seconds)) to leave one.")
                            .font(.futura(.footnote))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                }
            }
            .navigationTitle("Snag at \(timecode(snag.seconds))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if journalLoop != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onSave(draft)
                            dismiss()
                        }
                    }
                }
            }
            .onAppear { if line == nil { focused = true } }
        }
        .presentationDetents([.medium, .large])
    }

    /// Where the words go, and that they outlive the mark: ✕ on a snag has no undo (ADR 0202 D3), so it
    /// has to be plain that removing one doesn't take what was written with it.
    private func footer(_ loopName: String) -> String {
        line == nil
            ? "Saves to \(loopName)’s Journal. It stays there if you remove the snag."
            : "In \(loopName)’s Journal. It stays there if you remove the snag. Clear it to take it out."
    }
}

/// The sheets a hold on a reference-panel row opens: a marker's edit sheet, and a snag's line (ADR 0238).
/// Presented from the waveform's body root like its other sheets, and kept out of that body for its length.
struct PanelRowSheets: ViewModifier {
    @Bindable var model: WaveformPracticeModel

    func body(content: Content) -> some View {
        content
            .sheet(item: $model.editingMarker) { ref in
                let marker = ref.value
                MarkerEditSheet(marker: marker, onDelete: { model.deleteMarker(marker) })
            }
            .sheet(item: $model.editingSnag) { ref in
                let snag = ref.value
                SnagLineSheet(snag: snag, line: model.snagLine(for: snag), home: model.snagLineHome(for: snag),
                              onSave: { model.saveSnagLine($0, for: snag) })
            }
    }
}
