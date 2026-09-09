import SwiftUI

/// The **kind tag** selector for a journal note (ADR 0100) — the 🎯/⚡️/🧗/📝/🎬 vocabulary as a row of
/// selectable chips, over `EntryKind.pickerOrder`.
///
/// Extracted from `RoutineBlockDoneView` when the mid-run capture sheet (ADR 0142) needed the same
/// row: two copies of a chip vocabulary drift apart one small fix at a time, and this one is a
/// *shared* vocabulary by design — a note tagged 🧗 on the Done screen and one tagged 🧗 mid-run are
/// the same thing on the same timeline.
///
/// Neutral throughout — a label, never a verdict (ADR 0070). Selected reads in the kind's own tint
/// (the shared `KindChip.tint`, so a chip and a rendered entry agree); unselected stays quiet so the
/// row doesn't shout.
struct EntryKindChipRow: View {
    @Binding var selection: EntryKind
    /// The row's own caption, or `nil` where the host already labels the field (the compact sheet).
    var title: String? = "Tag this"
    /// Which tags this surface offers — the whole vocabulary by default.
    ///
    /// Narrowed by exactly one caller (ADR 0155 §6): three of the eight tags **assert the note was
    /// written during something** — 👂 Ear (ear-training on a loop), 🎸 Improv (jamming over a backing
    /// loop), 🎬 Session (a routine sitting just finished) — so offering them on a surface with no
    /// owner lets a player file a session note about no session.
    ///
    /// **The tag is now filtered on** (ADR 0207 D11), which this comment used to say it never was.
    /// The Journal's *Show* sheet has a **Tagged** section over these same values, so a chip tapped
    /// here decides which searches an entry turns up in later — a wrong tag is no longer only a
    /// misleading label. That raises what this parameter is worth rather than changing what it does:
    /// offering 🎬 Session on an ownerless sheet would file entries into a bucket the feed can then
    /// be narrowed to.
    var kinds: [EntryKind] = EntryKind.pickerOrder

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.futura(.footnote, weight: .semibold))
                    .foregroundStyle(PocketColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(kinds) { option in
                        chip(option)
                    }
                }
                .padding(.horizontal, 1)   // keeps selected chips' stroke from clipping at the edges
            }
        }
    }

    private func chip(_ option: EntryKind) -> some View {
        let selected = option == selection
        let tint = KindChip.tint(for: option)
        return Button {
            selection = option
            haptic(.light)
        } label: {
            Text("\(option.emoji)  \(option.label)")
                .font(.futura(.subheadline, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? tint : PocketColor.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(selected ? tint.opacity(0.18) : PocketColor.surfaceStandard))
                .overlay(Capsule().stroke(selected ? tint : PocketColor.surfaceBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

#Preview("Kind chips") {
    @Previewable @State var kind: EntryKind = .breakthrough
    return EntryKindChipRow(selection: $kind)
        .padding()
        .background(PocketColor.background)
        .preferredColorScheme(.dark)
}
