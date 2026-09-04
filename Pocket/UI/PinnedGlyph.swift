import SwiftUI

/// The mark on a **pinned** journal row (ADR 0190) — a small filled pin, shown only when the row is
/// pinned.
///
/// One view rather than the same `Image` written into `JournalEntryRow` and `JournalTakeRow`, because
/// the Journal space's premise is that notes and takes are one feed (ADR 0100): a mark that drifts to
/// a different size or colour on one of the two rows makes the same fact read as two facts.
///
/// Tinted `PocketColor.journal` — the space's own gold, already used for its owner captions — rather
/// than `textSecondary`, so the one thing on the row the player put there themselves is the one thing
/// that isn't grey. It is **not a control**: pinning is the hold menu's verb, and a tappable pin on a
/// row whose title and caption are already separate tap targets would be a third.
struct PinnedGlyph: View {
    var body: some View {
        Image(systemName: "pin.fill")
            .font(.futura(.caption))
            .foregroundStyle(PocketColor.journal)
            .accessibilityLabel("Pinned")
    }
}

#Preview {
    HStack(spacing: 8) {
        PinnedGlyph()
        Text("Pinned")
            .font(.pocketMono(.caption))
            .foregroundStyle(PocketColor.textSecondary)
    }
    .padding()
    .background(PocketColor.background)
    .preferredColorScheme(.dark)
}
