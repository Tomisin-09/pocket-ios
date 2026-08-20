import SwiftData
import SwiftUI

/// What is being written, and where it points (ADR 0175). A plain value, not a `@Model` reference —
/// which is the whole reason this sheet is presented by it.
///
/// A **new** moment has no row to present by yet, and reaching for one would mean inserting an empty
/// `TakeNote` just to have something to bind to, then reaping it if the sheet is cancelled. Carrying
/// the draft instead means nothing is written until Save is pressed, and it sidesteps ADR 0090's
/// trap for free: there is no `persistentModelID` here to flip temp→permanent underneath an open
/// editor.
struct TakeMomentDraft: Identifiable, Equatable {
    let id = UUID()
    /// The moment being edited, by its stable `uid` — `nil` for one being written for the first time.
    var noteUID: UUID?
    /// The point in the take this note is about. Captured when the sheet opens and **fixed**: the
    /// playhead may well run on underneath, and a note that re-aims itself while you type is a note
    /// you cannot place.
    var time: TimeInterval
    var text: String
}

/// Writing a note pinned to a point in a take (ADR 0175) — the sibling of `TakeNoteSheet`, which
/// writes the take's one whole-take note.
///
/// **Empty is refused here**, the opposite of `TakeNoteSheet`. Clearing the whole-take note is how
/// you delete it, because there is only ever the one and no row to swipe; a moment is a row in a
/// list, so it has a real delete of its own and emptying the text would be a second, quieter way to
/// do the same thing.
struct TakeMomentSheet: ViewModifier {
    @Binding var draft: TakeMomentDraft?
    let take: Recording
    let context: ModelContext

    func body(content: Content) -> some View {
        content
            .sheet(item: $draft) { item in
                NavigationStack { editor(for: item) }
                    .presentationDetents([.medium, .large])
            }
    }

    /// The moment `item` edits, or `nil` when it is a new one. Resolved by `uid` against the take's
    /// own rows rather than fetched, because the take is right here and its moments are already
    /// loaded.
    private func existing(_ item: TakeMomentDraft) -> TakeNote? {
        guard let uid = item.noteUID else { return nil }
        return take.moments.first { $0.uid == uid }
    }

    private func editor(for item: TakeMomentDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(PocketColor.journal)
                Text("At \(timecode(item.time))")
                    .font(.pocketMono(.subheadline))
                    .foregroundStyle(PocketColor.textPrimary)
            }
            .accessibilityElement(children: .combine)

            TextEditor(text: bindingToText)
                .font(.futura(.body))
                .foregroundStyle(PocketColor.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(PocketColor.surfaceSubtle, in: RoundedRectangle(cornerRadius: 10))

            Text("Kept with the take, on the spot it points at. Like the take's own note, it stays "
                 + "on this screen — it doesn’t appear in the Journal feed.")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)

            if let note = existing(item) {
                Button(role: .destructive) { delete(note) } label: {
                    Label("Delete this note", systemImage: "trash")
                        .font(.futura(.subheadline))
                }
                .buttonStyle(.plain)
                .foregroundStyle(PocketColor.danger)
                .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(item.noteUID == nil ? "Note at \(timecode(item.time))" : "Edit note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { draft = nil }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save(item) }
                    .disabled(item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    /// Edits land back on the presented draft, so the Save button's enablement tracks what is
    /// actually in the field rather than what it held when the sheet opened.
    private var bindingToText: Binding<String> {
        Binding(get: { draft?.text ?? "" }, set: { draft?.text = $0 })
    }

    private func save(_ item: TakeMomentDraft) {
        if let note = existing(item) {
            note.setText(item.text)
        } else {
            take.addMoment(at: item.time, text: item.text)
        }
        try? context.save()
        haptic(.light)
        draft = nil
    }

    private func delete(_ note: TakeNote) {
        // Detach before deleting: the take's `moments` array is what the screen renders from, and a
        // cascade-owned row left in it renders as a deleted model until the next fetch.
        take.moments.removeAll { $0.uid == note.uid }
        context.delete(note)
        try? context.save()
        haptic(.light)
        draft = nil
    }
}

extension View {
    /// Attach the moment editor, driven by a draft the take detail screen sets.
    func takeMomentSheet(_ draft: Binding<TakeMomentDraft?>, take: Recording,
                         context: ModelContext) -> some View {
        modifier(TakeMomentSheet(draft: draft, take: take, context: context))
    }
}
