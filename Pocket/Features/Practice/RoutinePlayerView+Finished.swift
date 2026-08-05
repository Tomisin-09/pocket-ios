import SwiftUI

/// The **session-complete screen** — the end of a routine run, and (ADR 0143) the one place a
/// *session* journal entry is written.
///
/// Lives in an extension for two reasons. The plain one is size: `RoutinePlayerView` is against the
/// 400-line cap, and the Done screen already set the precedent (`RoutinePlayerView+Done.swift`). The
/// better one is that this screen has grown a job — it used to only say "you're finished", and now it
/// takes a note about what just happened.
///
/// **Judgement-free throughout (ADR 0070):** the recap says *what* you worked through, never how well,
/// and the composer's prompt asks an open question rather than fishing for a rating.
extension RoutinePlayerView {

    var finishedView: some View {
        // A scroll container, not the bare `VStack` this used to be: the composer's field grows as it
        // wraps, and `KeyboardFollowingScroll` is what keeps it above the keyboard when it does (the
        // shared half of the v2 close-out's N5 fix). Without the wrapper the field's
        // `.scrollsIntoViewWhenFocused` finds no proxy and silently does nothing.
        KeyboardFollowingScroll {
            ScrollView {
                VStack(spacing: 16) {
                    Image(systemName: player.stages.isEmpty ? "questionmark.circle" : "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(PocketColor.practice)
                    Text(player.stages.isEmpty ? "Nothing to play" : "Session complete")
                        .font(.futura(.title3))
                        .foregroundStyle(PocketColor.textPrimary)
                    Text(player.stages.isEmpty
                         ? "This routine has no playable exercises or loops yet."
                         : "Nice work. Find the music in the mistakes.")
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                        .multilineTextAlignment(.center)
                    if !practicedTitles.isEmpty {
                        recap
                        sessionComposer
                    }
                    Button { dismiss() } label: {
                        Label("Done", systemImage: "checkmark").pocketRunButton
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
            }
        }
        .keepAwakeDuringPractice()   // the summary lingers on screen after the last block (ADR 0050)
    }

    /// A judgement-free recap — just *what* you worked through this session, no scores (ADR 0070).
    private var recap: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("You practised")
                .font(.futura(.caption, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
                .textCase(.uppercase)
            ForEach(Array(practicedTitles.enumerated()), id: \.offset) { _, title in
                HStack(spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundStyle(PocketColor.practice)
                    Text(title)
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(PocketColor.practiceCircleWash))
    }

    /// **The session note** (ADR 0143). Until now every journal entry belonged to one unit, so a
    /// thought about the *sitting* — how the hands felt, what the hour was actually like — had to be
    /// filed under one of the blocks it wasn't about. This is where it goes instead.
    ///
    /// Tagged 🎬 `.session`, a kind that has existed in the vocabulary since ADR 0100 with nothing to
    /// own it. Optional, like every composer: leaving it empty and tapping Done writes nothing.
    private var sessionComposer: some View {
        JournalNoteComposer(owner: .session(SessionJournalContext(routine: routine,
                                                                 stages: player.stages)),
                            kind: .session,
                            header: "How did that go?",
                            placeholder: "Anything worth keeping about this session?",
                            style: .card)
    }

    /// The unit blocks (exercises/loops/songs) in this routine, in order — the recap list; rests
    /// omitted. Deliberately **not** the same list the entry snapshots: the recap says what you did,
    /// so it keeps songs; `SessionJournalContext` drops them, because a song has no run screen for a
    /// link to lead to (ADR 0069 / 0142 J5a).
    private var practicedTitles: [String] {
        player.stages.filter { $0.kind != .rest }.map(\.title)
    }
}
