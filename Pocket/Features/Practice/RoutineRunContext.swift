import SwiftUI

/// The **session context** a routine player injects into a per-unit run screen (`ExerciseRunView` /
/// `LoopRunView`) so those screens keep *all* their training aids — fretboard/strum/chord preview,
/// Practice Settings, the ramp staircase, promote, journal — and gain only the routine-specific
/// chrome: a session **progress strip** (with Start / Finish markers), a **Skip** control, an
/// **exit**, an optional **auto-start**, and the natural-completion hook the player advances on.
/// `nil` in standalone use, so a normal run screen is completely unaffected (ADR 0071).
///
/// The closures target the stable `RoutineSessionPlayer`, so it's safe for a run view to wire
/// `onFinished` to its engine once and hold it for the block's lifetime.
struct RoutineRunContext {
    /// 0-based position of this block, and the session's total — drive the progress strip.
    let stageIndex: Int
    let stageCount: Int
    /// Whether this block should begin on its own when it appears (Settings-gated; always false for
    /// the first block, which waits for a deliberate Start).
    let autoStart: Bool
    /// Whether there's a previous block to step back to (disables the ‹ control at the first block).
    let canGoBack: Bool
    /// Step back to the previous block (user-initiated).
    let onBack: () -> Void
    /// Jump to the next block now (user-initiated).
    let onSkip: () -> Void
    /// This block finished on its own (the ramp's last plateau) — advance automatically.
    let onFinished: () -> Void
    /// Leave the whole player.
    let onExit: () -> Void
}

extension View {
    /// Adds the routine session chrome to a run screen — a leading **Close** and, below the nav bar,
    /// the **progress strip** — when a `RoutineRunContext` is present, and nothing at all when
    /// standalone. Keeps the screen's own title (the block name) and its trailing tools intact.
    func routineSessionChrome(_ context: RoutineRunContext?) -> some View {
        toolbar {
            if let context {
                ToolbarItem(placement: .topBarLeading) {
                    Button { context.onExit() } label: {
                        Image(systemName: "xmark")
                    }
                    .tint(PocketColor.textSecondary)
                    .accessibilityLabel("Close player")
                }
            }
        }
        .safeAreaInset(edge: .top) {
            if let context {
                RoutineProgressStrip(index: context.stageIndex, count: context.stageCount,
                                     canGoBack: context.canGoBack,
                                     onBack: context.onBack, onNext: context.onSkip)
            }
        }
    }
}

/// A slim per-block **progress strip + session navigator** for the routine player — one segment per
/// block (past filled, current bright, upcoming faint) with **Start** / **Finish** endcaps, flanked
/// by ‹ **previous** and **next** › chevrons. It replaces the cramped "N of M" beside the close
/// button and is the one place session navigation lives, leaving each block's transport for the drill
/// itself (ADR 0071).
struct RoutineProgressStrip: View {
    let index: Int
    let count: Int
    let canGoBack: Bool
    let onBack: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            navButton(symbol: "chevron.left", label: "Previous block",
                      enabled: canGoBack, action: onBack)
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(0..<max(count, 1), id: \.self) { position in
                        Capsule().fill(color(for: position)).frame(height: 4)
                    }
                }
                HStack {
                    Text("Start")
                    Spacer()
                    Text("Finish")
                }
                .font(.futura(.caption2))
                .foregroundStyle(PocketColor.textSecondary)
            }
            navButton(symbol: "chevron.right", label: "Skip to next block",
                      enabled: true, action: onNext)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(PocketColor.background.opacity(0.95))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Block \(min(index + 1, count)) of \(count)")
    }

    private func navButton(symbol: String, label: String,
                           enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.futura(.body, weight: .semibold))
                .foregroundStyle(enabled ? PocketColor.practice
                                         : PocketColor.textSecondary.opacity(0.35))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    /// Past blocks read as a dim wash, the current one bright, the rest barely there.
    private func color(for position: Int) -> Color {
        if position < index { return PocketColor.practice.opacity(0.45) }
        if position == index { return PocketColor.practice }
        return PocketColor.textSecondary.opacity(0.2)
    }
}

/// A brief **count-in** overlay shown before a routine block starts (ADR 0071) — a `3 · 2 · 1`
/// visual with a haptic tick per count, so an auto-started block never begins mid-stride and even a
/// tapped Start gets a moment to settle. Uniform for exercises and loops (no audio of its own; a
/// drill's own musical count-in, if enabled, still follows). Calls `onComplete` on reaching zero.
struct RoutineCountInOverlay: View {
    var onComplete: () -> Void
    @State private var value = 3

    var body: some View {
        ZStack {
            PocketColor.background.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 8) {
                Text("\(value)")
                    .font(.pocketMono(.largeTitle))
                    .foregroundStyle(PocketColor.practice)
                    .contentTransition(.numericText())
                Text("Get ready")
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
        .task { await countDown() }
    }

    private func countDown() async {
        for count in stride(from: 3, through: 1, by: -1) {
            withAnimation { value = count }
            haptic(.medium)
            try? await Task.sleep(for: .seconds(0.8))
        }
        onComplete()
    }
}
