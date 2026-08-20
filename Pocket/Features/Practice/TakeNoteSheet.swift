import SwiftData
import SwiftUI

/// Writing a take's **note** (ADR 0174) — what the playing was like, what to change next time.
///
/// A sheet rather than an alert, which is where this parts company with its sibling
/// `RenameTakeAlert`: a name is a few words and an alert field holds them, but a note is a paragraph
/// and an alert has nowhere to put one. The `StableRef` discipline is the same and for the same
/// reason — presenting a `@Model` by `persistentModelID` self-dismisses the moment the id flips
/// temp→permanent on first save (ADR 0090), which would tear the editor down mid-sentence.
///
/// **Clearing is allowed**, unlike renaming. A blank name is a mistake, because a name is how you
/// tell one take from another; a note you no longer want is a note you should be able to delete.
struct TakeNoteSheet: ViewModifier {
    @Binding var take: StableRef<Recording>?
    let context: ModelContext

    @State private var draft = ""

    func body(content: Content) -> some View {
        content
            .sheet(item: $take) { ref in
                NavigationStack {
                    editor(for: ref)
                }
                .presentationDetents([.medium, .large])
            }
    }

    private func editor(for ref: StableRef<Recording>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $draft)
                .font(.futura(.body))
                .foregroundStyle(PocketColor.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(PocketColor.surfaceSubtle, in: RoundedRectangle(cornerRadius: 10))
            Text("Kept with the take. It stays on this screen — a take's note doesn’t appear in the Journal feed.")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(ref.value.hasNote ? "Edit note" : "Add a note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { take = nil }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    // `setNote` trims and stores `nil` for an empty result, so a cleared editor
                    // removes the note rather than leaving whitespace that renders as a blank block.
                    ref.value.setNote(draft)
                    try? context.save()
                    haptic(.light)
                    take = nil
                }
            }
        }
        // Seed from the take being edited, not from the last one edited.
        .onAppear { draft = ref.value.note ?? "" }
    }
}

extension View {
    /// Attach the shared take-note editor, driven by a `StableRef` the detail screen sets.
    func takeNoteSheet(_ take: Binding<StableRef<Recording>?>, context: ModelContext) -> some View {
        modifier(TakeNoteSheet(take: take, context: context))
    }
}
