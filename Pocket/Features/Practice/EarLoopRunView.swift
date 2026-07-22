import SwiftUI

/// An **ear-training loop block** inside a routine (ADR 0104 Slice 2). The routine counterpart of
/// `LoopRunView` for a loop whose block mode is `.ear`: it embeds the shared `EarTrainingView`
/// (continuous playback + hum/sing + note capture) and adds only the routine chrome — the session
/// **progress strip**, **skip**, **exit** (via `routineSessionChrome`) — plus a bottom **Done**
/// button that advances to the next block.
///
/// **Manual advance, no completion screen.** Ear internalisation has no ramp or natural end, so unlike
/// exercise/loop blocks it never shows a `RoutineBlockDoneView` (mastery/promote) — the player decides
/// when they've internalised it and taps Done (`RoutinePlayerView.finishedBlock` skips the Done screen
/// for `.earLoop`). Standalone ear training uses `EarTrainingSheet` instead; this exists only for the
/// routine player, so `routineContext` is expected to be present.
struct EarLoopRunView: View {
    let loop: Loop
    var routineContext: RoutineRunContext?

    var body: some View {
        EarTrainingView(loop: loop)
            .navigationTitle(loop.name.isEmpty ? "Train your ear" : loop.name)
            .navigationBarTitleDisplayMode(.inline)
            .routineSessionChrome(routineContext)
            .toolbar { doneButton }
    }

    /// The completion action as a **nav-bar button**, not a bottom pill — an ear block has nothing to
    /// grade, so advancing is a quiet "Done" (or "Finish" on the last block), never a big call-to-action
    /// that reads like something's wrong. It leaves the screen's own **Save to Journal** as the only
    /// bottom action. The progress strip's › also advances (skip); this is the deliberate "I'm done".
    @ToolbarContentBuilder private var doneButton: some ToolbarContent {
        if let context = routineContext {
            ToolbarItem(placement: .topBarTrailing) {
                Button(context.stageIndex >= context.stageCount - 1 ? "Finish" : "Done") {
                    haptic(.light)
                    context.onFinished()
                }
                .font(.futura(.body, weight: .semibold))
                .tint(PocketColor.practice)
                .accessibilityLabel("Done with this ear-training block")
            }
        }
    }
}

#Preview("Ear loop block") {
    let song = Song.sample()
    let loop = Loop(name: "Verse riff", start: 0.2, end: 0.35, speed: 0.85, repeats: 4)
    loop.song = song
    loop.commandTempo = 0.85
    return NavigationStack {
        EarLoopRunView(loop: loop,
                       routineContext: RoutineRunContext(
                        stageIndex: 1, stageCount: 4, autoStart: false, canGoBack: true,
                        onBack: {}, onSkip: {}, onFinished: {}, onExit: {}))
    }
    .preferredColorScheme(.dark)
}
