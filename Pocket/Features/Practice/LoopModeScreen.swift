import SwiftUI

/// A loop's **pushed** screen for one mode (ADR 0267): the trainer, ear training or improvise.
///
/// Four doors push a loop in a mode — the Loops library's row menu, a Journal caption (ADR 0142), a
/// piece's hold in Map the song (ADR 0232) and Home's Jump back in — and the first three each had a
/// switch like this one. One view means a new mode, or a change to which host a mode gets, is one edit.
///
/// Every host here gates itself behind the plan (ADR 0256 D3), so a free screen that links in, such as
/// the Journal or Map the song, meets the wall titled for the mode rather than the screen.
struct LoopModeScreen: View {
    let loop: Loop
    let mode: LoopRunMode

    var body: some View {
        switch mode {
        case .trainer: LoopRunView(loop: loop)
        case .ear: EarTrainingScreen(loop: loop)
        case .improvise: ImproviseScreen(loop: loop)
        }
    }
}
