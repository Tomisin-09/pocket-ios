import SwiftData
import SwiftUI

/// **Capture a note without leaving the run** (ADR 0142) — one field, the kind chips, Save.
///
/// The counterpart to `JournalSheet`, not a replacement for it. That sheet is a *browse-and-edit*
/// surface: a composer, the whole history in day sections, push-to-edit, swipe-to-delete, and a
/// snapshot explainer. It is the right thing when you are looking back and the wrong thing when the
/// click is running and you have one sentence to get down before you lose it — and it was reachable
/// only from a stopped, standalone run screen, so during a routine there was nowhere to write at all.
///
/// So: the same write path (`JournalWriter.add`, owner-aware snapshot untouched), the same kind
/// vocabulary (`EntryKindChipRow`), a fraction of the surface, and no history — reading back is what
/// the Journal space is for. **Nothing here touches the transport.** Presenting this over a run leaves
/// the audio exactly as it was; a note written mid-drill costs the drill nothing.
struct QuickJournalSheet: View {
    let owner: JournalOwner
    /// What the note is tagged with before the player picks — `.note` everywhere today, a parameter
    /// so a surface with an obvious tag (a jam, an ear block) can lead with its own.
    var initialKind: EntryKind = .note

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var kind: EntryKind
    @FocusState private var textFocused: Bool

    init(owner: JournalOwner, initialKind: EntryKind = .note) {
        self.owner = owner
        self.initialKind = initialKind
        _kind = State(initialValue: initialKind)
    }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            KeyboardFollowingScroll {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        noteField
                        EntryKindChipRow(selection: $kind, kinds: offeredKinds)
                        destinationLine
                    }
                    .padding(20)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Quick note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
        }
        // Medium by default so the run screen stays half-visible behind it — this is an aside, not a
        // destination — and draggable to large for a longer note.
        .presentationDetents([.medium, .large])
    }

    private var noteField: some View {
        TextField("What just happened?", text: $text, axis: .vertical)
            .font(.futura(.body))
            .lineLimit(3...8)
            .padding(12)
            .background(PocketColor.surfaceStandard, in: RoundedRectangle(cornerRadius: 12))
            // The field grows vertically, so Return inserts a newline — the keyboard needs its own
            // way off (v2 close-out N5).
            .keyboardDoneButton()
            .scrollsIntoViewWhenFocused("quick-note", focused: $textFocused)
            // Opened *to write*, so the caret is already there. `.task` rather than `.onAppear`: the
            // focus has to land after the sheet's presentation transition or it is dropped.
            .task { textFocused = true }
    }

    /// The tags this sheet offers. An **ownerless** note can't honestly carry the three tags that
    /// assert it was written during something (ADR 0155 §6); every other owner gets the full
    /// vocabulary. The four that survive are the four ADR 0100's own composer led with.
    private var offeredKinds: [EntryKind] {
        switch owner {
        // A metronome note shares the narrowing, not by analogy but by the same argument (ADR 0160
        // §7): 👂 Ear, 🎸 Improv and 🎬 Session each assert the note was written during something with
        // a unit behind it, and a click is not that.
        case .standalone, .metronome: [.goal, .breakthrough, .struggle, .note]
        case .loop, .exercise, .session: EntryKind.pickerOrder
        }
    }

    /// Where the note lands. Stated because this sheet can be opened from inside a routine, where the
    /// unit on screen is one of several — "which of these am I writing about" is a real question here
    /// in a way it never is on the per-owner sheet. The whole sentence comes from the owner (ADR 0155
    /// §5): assembling it from fragments here has no honest form for an owner that records nothing.
    private var destinationLine: some View {
        Text(owner.destinationLine)
            .font(.futura(.caption))
            .foregroundStyle(PocketColor.textSecondary)
    }

    private func save() {
        guard JournalWriter.add(to: owner, text: text, kind: kind, into: modelContext) else { return }
        try? modelContext.save()
        haptic(.light)
        dismiss()
    }
}

/// The nav-bar way in, so every run screen opens capture the same way and from the same place.
/// A pencil, not a book: the review bar's 📕 *Journal* pill opens the history, this writes.
struct QuickJournalButton: View {
    /// What the tap does. A closure rather than only a `Binding<Bool>` because the metronome has to
    /// **pin its snapshot at the tap** (ADR 0160 §5) and then present by item — one button, two ways
    /// to open it, rather than a second button that would have to be kept looking identical.
    private let action: () -> Void

    init(isPresented: Binding<Bool>) {
        self.action = { isPresented.wrappedValue = true }
    }

    init(action: @escaping () -> Void) {
        self.action = action
    }

    var body: some View {
        Button {
            action()
            haptic(.light)
        } label: {
            Image(systemName: "square.and.pencil")
        }
        .tint(PocketColor.journal)
        .accessibilityLabel("Write a quick journal note")
    }
}

#Preview("Quick note — exercise") {
    let exercise = Exercise(name: "Alternating picking", currentTempo: 90, commandTempo: 120)
    return Color.black
        .sheet(isPresented: .constant(true)) {
            QuickJournalSheet(owner: .exercise(exercise))
        }
        .preferredColorScheme(.dark)
}
