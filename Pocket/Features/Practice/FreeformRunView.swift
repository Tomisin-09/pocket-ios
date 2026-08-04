import SwiftData
import SwiftUI

/// A run on a **freeform block** (ADR 0136) — the practice Pocket doesn't model: sight-reading,
/// transcribing, a piece worked by hand, a teacher's assignment. The screen is the player's own
/// instructions and a clock, and nothing else. There is no click, no board, no ramp and no tempo
/// (F3), because most of what belongs in one has no BPM at all.
///
/// **Ear training's shape, plus the screen ear training omits** (F4). Like `EarLoopRunView` there is
/// no transport and no natural end, so the clock starts on **appearance** and an explicit **Done** is
/// a genuine completion rather than a hand-stop — the player deciding they're finished *is* the end
/// of the run. Unlike an ear block it does show `RoutineBlockDoneView`, because a freeform block has
/// a self-rating and that rating is the entire tracking payoff: it is what `DueScore` reads to bring
/// the block back round (F5) and what ADR 0134's command offer leans on. That screen is reached the
/// ordinary way — a freeform block's stage kind is `.exercise`, which is not ramp-less, so
/// `RoutinePlayerView` gates it in without a special case.
///
/// Nothing here grades the playing (F8 / ADR 0070). The app holds the block; the player fills it.
struct FreeformRunView: View {
    let exercise: Exercise
    /// Routine-session chrome (progress, Skip, auto-advance) when a block in a routine; `nil`
    /// standalone. A freeform block is a real library unit (F6), so both hosts are real.
    var routineContext: RoutineRunContext?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// When this block began (ADR 0117). No Start to hang it on, so it starts on appearance — the
    /// same clock `EarLoopRunView` keeps.
    @State private var startedAt: Date?
    /// The practice journal sheet (ADR 0058) — a freeform block has a journal like any other exercise.
    @State private var showingJournal = false
    /// The detail sheet, which is also where the instructions are edited after creation.
    @State private var showingDetail = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                instructions
                elapsedReadout
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(PocketColor.background)
        .navigationTitle(exercise.name.isEmpty ? "Your own practice" : exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .routineSessionChrome(routineContext)
        .safeAreaInset(edge: .bottom) { doneButton }
        .toolbar { toolbarItems }
        .onAppear { if startedAt == nil { startedAt = .now } }
        // A freeform block takes a planned length like any other ramp-less block (ADR 0141). No audio
        // means no phrase to protect, so it finishes at the planned moment rather than waiting for a
        // cycle to come round; open-ended outside a routine, as everywhere else.
        .rampLessBlockLength(plannedMinutes: routineContext?.plannedMinutes,
                             cycleSeconds: { 0 },
                             isPlaying: { false },
                             onFinish: finish)
        .sheet(isPresented: $showingJournal) {
            JournalSheet(owner: .exercise(exercise))
        }
        .sheet(isPresented: $showingDetail) {
            ExerciseDetailSheet(exercise: exercise)
        }
    }

    // MARK: - Content

    /// The player's own words, given the whole screen. Deliberately plain and generously sized: this
    /// is something to *read while practising*, at arm's length, not a caption.
    private var instructions: some View {
        Text(exercise.notes.isEmpty ? "No instructions on this block yet." : exercise.notes)
            .font(.futura(.title3))
            .foregroundStyle(exercise.notes.isEmpty
                             ? PocketColor.textSecondary : PocketColor.textPrimary)
            .lineSpacing(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(exercise.notes.isEmpty
                                ? "No instructions on this block yet"
                                : "Instructions: \(exercise.notes)")
    }

    /// Elapsed time, and nothing more. No target, no progress bar, no "you're behind" — the block has
    /// no length the app is entitled to hold the player to, and in a routine the planned length is
    /// already reported by the ramp-less chrome above.
    private var elapsedReadout: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(elapsedLabel(at: context.date))
                .font(.pocketMono(.callout))
                .foregroundStyle(PocketColor.textSecondary)
                .monospacedDigit()
                .accessibilityLabel("\(elapsedLabel(at: context.date)) on this block")
        }
    }

    private func elapsedLabel(at now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(startedAt ?? now)))
        return String(format: "%d:%02d elapsed", seconds / 60, seconds % 60)
    }

    // MARK: - Chrome

    /// The completion action as a **bottom pill**, unlike an ear block's quiet nav-bar Done. This
    /// screen has no other bottom action competing with it, and Done here leads somewhere — the
    /// rating screen — so it is a real call to action rather than a way out.
    private var doneButton: some View {
        Button {
            haptic(.light)
            finish()
        } label: {
            Text(finishLabel)
                .font(.futura(.body, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(PocketColor.practice)
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .accessibilityLabel("Done with this block")
    }

    private var finishLabel: String {
        guard let routineContext else { return "Done" }
        return routineContext.stageIndex >= routineContext.stageCount - 1 ? "Finish" : "Done"
    }

    @ToolbarContentBuilder private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { showingDetail = true } label: {
                    Label("Edit instructions", systemImage: "square.and.pencil")
                }
                Button { showingJournal = true } label: {
                    Label("Journal", systemImage: "text.book.closed")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .tint(PocketColor.practice)
            .accessibilityLabel("Block options")
        }
    }

    // MARK: - Completion

    /// The one completion seam — the Done button and the block running its planned length both land
    /// here, so a block that timed out logs and advances exactly like one finished by hand.
    private func finish() {
        logCompletedRun()   // before advancing — advancing tears this screen down
        exercise.markPracticed()
        try? modelContext.save()
        if let routineContext {
            routineContext.onFinished()
        } else {
            dismiss()
        }
    }

    /// Log the block as a completed unit-run (ADR 0117). **Done is a genuine completion here**, not a
    /// hand-stop: a freeform block has no ramp to run its course, so the player deciding they're
    /// finished *is* the end of the run (F4). Skip and exit bypass this and log nothing.
    ///
    /// Logged as `.exercise` with **no new kind** (F4a) — it *is* an exercise, the log names the unit,
    /// and there is no tempo trajectory to protect from muddying (the reason `.earLoop` earned its own
    /// case). `tempoBPM` is `nil`, which `PracticeRun` already documents as the honest value when the
    /// drill states none (ADR 0121).
    private func logCompletedRun() {
        guard let startedAt else { return }
        self.startedAt = nil
        PracticeLogWriter.log(kind: .exercise,
                              startedAt: startedAt,
                              unitUID: exercise.uid,
                              routineUID: routineContext?.routineUID,
                              tempoBPM: nil,
                              into: modelContext)
    }
}

#Preview("Freeform block") {
    let exercise = Exercise.commandAnchored(
        name: "Sight-reading",
        command: 90,
        template: .freeform,
        notes: "Two pages from the Berklee book, first time through only. Don't stop to fix "
             + "anything — keep the pulse and take the mistakes.")
    return NavigationStack {
        FreeformRunView(exercise: exercise)
    }
    .preferredColorScheme(.dark)
}
