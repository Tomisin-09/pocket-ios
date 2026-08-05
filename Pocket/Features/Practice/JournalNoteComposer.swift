import SwiftData
import SwiftUI

/// **Note capture straight into a unit's Journal** (ADR 0058 / 0100 / 0142), tagged with the
/// surface's own `EntryKind` — 👂 for ear training, 🎸 for a jam, 📝 for a freeform block or a
/// running loop. Owns its own draft and per-session tally, so a host is one line and nothing more.
///
/// Started life as `LoopModeNoteSection`, hard-wired to a `Loop` because ear training and improvise
/// were its only two hosts. It takes a **`JournalOwner`** now (ADR 0142): the same field belongs on
/// any surface with room for it, and a freeform block's owner is an `Exercise`. The write still goes
/// through `JournalWriter`, so the per-owner snapshot logic is untouched — an exercise note carries an
/// absolute BPM, a loop note mastery + percent, and neither can cross.
///
/// Two shapes, one composer:
/// - **`.formSection`** — a `Section` for a `Form` host (`ImproviseView`, `EarTrainingView`).
/// - **`.card`** — a self-contained card for a `ScrollView` host (`FreeformRunView`, the loop
///   trainer's live readout), where there is no `Form` to hang a section on.
///
/// The tally drives a quiet "saved" confirmation and is deliberately **not** a count of anything the
/// player did well (ADR 0070 / 0135 B5): it's a receipt that the write landed.
struct JournalNoteComposer: View {
    /// How the composer renders — see the type's note. The two differ only in chrome; the field, the
    /// button and the write are identical.
    enum Style {
        case formSection
        case card
    }

    let owner: JournalOwner
    let kind: EntryKind
    let header: String
    let placeholder: String
    var style: Style = .formSection

    @Environment(\.modelContext) private var modelContext
    @State private var draftNote = ""
    @State private var savedThisSession = 0
    @FocusState private var noteFocused: Bool

    private var canAdd: Bool {
        !draftNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        switch style {
        case .formSection:
            Section {
                noteField
                saveButton
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            } header: {
                Text(header)
            } footer: {
                Text(footer)
            }
        case .card:
            VStack(alignment: .leading, spacing: 10) {
                Text(header)
                    .font(.futura(.footnote, weight: .semibold))
                    .foregroundStyle(PocketColor.textSecondary)
                noteField
                    .padding(12)
                    .background(PocketColor.surfaceStandard, in: RoundedRectangle(cornerRadius: 12))
                saveButton
                Text(footer)
                    .font(.futura(.caption2))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var noteField: some View {
        TextField(placeholder, text: $draftNote, axis: .vertical)
            .lineLimit(2...5)
            .keyboardDoneButton()
            // Needs a `KeyboardFollowingScroll` around the host's container — every host has one;
            // inert if a new one forgets.
            .scrollsIntoViewWhenFocused("mode-note", focused: $noteFocused)
    }

    private var saveButton: some View {
        Button {
            addNote()
        } label: {
            Text("Save to Journal")
                .font(.futura(.headline))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(canAdd ? PocketColor.background : PocketColor.textSecondary)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(canAdd ? PocketColor.journal : PocketColor.surfaceBorder))
        }
        // `.borderless` so the button is its own hit-target inside the Form row (matches
        // JournalSheet's composer — the default row-wide button swallows the first tap).
        .buttonStyle(.borderless)
        .disabled(!canAdd)
    }

    private var footer: String {
        savedThisSession == 0
            ? "Optional — saves to \(owner.displayName)'s Journal tagged \(kind.emoji), on the same "
                + "timeline as your practice notes."
            : "Saved to Journal \(kind.emoji) · \(savedThisSession) this session"
    }

    /// Write the note through the shared Journal path (ADR 0058), snapshotting the owner's context
    /// like any note. Trims/ignores empty (JournalWriter enforces it too).
    private func addNote() {
        guard JournalWriter.add(to: owner, text: draftNote, kind: kind, into: modelContext)
        else { return }
        try? modelContext.save()
        haptic(.light)
        draftNote = ""
        savedThisSession += 1
    }
}

#Preview("Note composer — card") {
    let exercise = Exercise.commandAnchored(name: "Sight-reading", command: 90, template: .freeform)
    return KeyboardFollowingScroll {
        ScrollView {
            JournalNoteComposer(owner: .exercise(exercise), kind: .note,
                                header: "Note what happened",
                                placeholder: "Anything worth keeping?",
                                style: .card)
                .padding(20)
        }
    }
    .background(PocketColor.background)
    .preferredColorScheme(.dark)
}
