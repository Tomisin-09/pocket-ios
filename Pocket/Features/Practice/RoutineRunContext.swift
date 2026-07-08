import SwiftUI

/// The **session context** a routine player injects into a per-unit run screen (`ExerciseRunView` /
/// `LoopRunView`) so those screens keep *all* their training aids — fretboard/strum/chord preview,
/// Practice Settings, the ramp staircase, promote, journal — and gain only the routine-specific
/// chrome: session **progress**, a **Skip** control, an **exit**, and the natural-completion hook the
/// player advances on. `nil` in standalone use, so a normal run screen is completely unaffected
/// (ADR 0071).
///
/// The closures target the stable `RoutineSessionPlayer`, so it's safe for a run view to wire
/// `onFinished` to its engine once and hold it for the block's lifetime.
struct RoutineRunContext {
    /// "2 of 5" — where this block sits in the session.
    let progressLabel: String
    /// Jump to the next block now (user-initiated).
    let onSkip: () -> Void
    /// This block finished on its own (the ramp's last plateau) — advance automatically.
    let onFinished: () -> Void
    /// Leave the whole player.
    let onExit: () -> Void
}

extension View {
    /// Adds the routine session chrome to a run screen — a leading **Close** + **progress** — when a
    /// `RoutineRunContext` is present, and nothing at all when standalone. Keeps the screen's own
    /// title (the block name) and its trailing tools intact.
    func routineSessionChrome(_ context: RoutineRunContext?) -> some View {
        toolbar {
            if let context {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button { context.onExit() } label: {
                        Image(systemName: "xmark")
                    }
                    .tint(PocketColor.textSecondary)
                    .accessibilityLabel("Close player")
                    Text(context.progressLabel)
                        .font(.pocketMono(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
        }
    }
}

/// The **Skip** control a run screen shows in its transport while playing inside a routine — advances
/// to the next block. An outlined circle, distinct from the filled Start/Pause pill and the washed
/// Stop, so "skip the session forward" never reads as "stop this drill".
struct RoutineSkipButton: View {
    let context: RoutineRunContext

    var body: some View {
        Button { context.onSkip() } label: {
            Image(systemName: "forward.fill")
                .font(.futura(.title3))
                .foregroundStyle(PocketColor.practice)
                .frame(width: 56, height: 56)
                .background(Circle().stroke(PocketColor.practice, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Skip to next block")
    }
}
