import SwiftUI

/// The **post-block Done screen** shown when a routine unit finishes on its own with manual advance
/// on (the default — ADR 0071 R4). It **collapses** the earlier separate two-option reflection sheet
/// into one surface: a completion beat, an *optional* mastery tap, an *optional* inline journal note,
/// and a single primary **Continue / Finish** that commits both in one action (the P3 lesson — no
/// competing "Add entry" button). A deliberate Skip bypasses this gate, and auto-advance skips it
/// entirely; it appears only for units that carry a journal (exercise/loop), never a song/rest.
///
/// No evaluation (ADR 0070): mastery is the player's own self-rating, never a score the app measured.
/// The host commits — this view only gathers `(mastery, note)` and hands them back — so it stays
/// SwiftData-free and independently previewable.
struct RoutineBlockDoneView: View {
    /// The just-finished block's title (the drill name) — the completion line names what you did.
    let title: String
    /// The unit's current self-rated mastery (0–5, `nil` = unrated), pre-filled so a tap *adjusts*
    /// rather than starts from blank.
    let initialMastery: Int?
    /// Whether this is the last block — the primary reads **Finish** (→ end-of-routine summary)
    /// instead of **Continue** (→ next block / rest).
    let isLast: Bool
    /// Commit the optional mastery (unchanged ⇒ pass through) and the optional note, then advance.
    let onContinue: (_ mastery: Int?, _ note: String) -> Void

    @State private var mastery: Int?
    @State private var note = ""
    @FocusState private var noteFocused: Bool

    init(title: String, initialMastery: Int?, isLast: Bool,
         onContinue: @escaping (_ mastery: Int?, _ note: String) -> Void) {
        self.title = title
        self.initialMastery = initialMastery
        self.isLast = isLast
        self.onContinue = onContinue
        _mastery = State(initialValue: initialMastery)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                completionBeat
                masteryTap
                noteField
            }
            .padding(.horizontal, 24)
            .padding(.top, 48)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { continueBar }
        .background(PocketColor.background.ignoresSafeArea())
    }

    // MARK: - Pieces

    private var completionBeat: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(PocketColor.practice)
                .accessibilityHidden(true)
            Text("Nice work")
                .font(.futura(.title2, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
            Text(title)
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var masteryTap: some View {
        VStack(spacing: 10) {
            Text("How cleanly did that feel?")
                .font(.futura(.footnote, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { value in
                    Circle()
                        .fill(value <= (mastery ?? 0) ? PocketColor.mastery : PocketColor.barDefault)
                        .frame(width: 22, height: 22)
                        .onTapGesture {
                            // Tap sets the value; tapping the lowest filled dot walks it down, below
                            // 1 clears to unrated — mirrors the detail-sheet control exactly.
                            mastery = (mastery == value) ? (value == 1 ? nil : value - 1) : value
                            haptic(.light)
                        }
                        .accessibilityLabel("Set mastery to \(value)")
                }
            }
            Text("Optional — the planner resurfaces well-learned drills on its own.")
                .font(.futura(.caption2))
                .foregroundStyle(PocketColor.textSecondary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note (optional)")
                .font(.futura(.footnote, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
            TextField("Jot how it went…", text: $note, axis: .vertical)
                .font(.futura(.body))
                .lineLimit(2...5)
                .focused($noteFocused)
                .padding(12)
                .background(PocketColor.surfaceStandard, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var continueBar: some View {
        Button {
            onContinue(mastery, note)
        } label: {
            Label(isLast ? "Finish" : "Continue",
                  systemImage: isLast ? "flag.checkered" : "arrow.right")
                .pocketRunButton
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(PocketColor.background)
    }
}

#Preview("Block done") {
    RoutineBlockDoneView(title: "Alternate picking · 8ths",
                         initialMastery: 2, isLast: false) { _, _ in }
}
