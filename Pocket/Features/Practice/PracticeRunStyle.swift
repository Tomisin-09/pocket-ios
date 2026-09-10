import SwiftUI

extension View {
    /// The shared big-pill look for the Practice run screens' primary transport buttons
    /// (`LoopRunView` / `ExerciseRunView`) — a filled, full-width practice-tinted pill.
    var pocketRunButton: some View {
        self
            .font(.futura(.headline))
            .foregroundStyle(PocketColor.background)
            .frame(maxWidth: .infinity)
            // `minHeight`, not `height` (ADR 0213 D6). This is the shared pill behind every primary
            // control on the run screens, and its label is real words — at an accessibility text
            // size a fixed 56 clips them, on the one button the screen exists to offer. Nothing
            // moves at the default sizes, where the text is well inside 56.
            .frame(minHeight: 56)
            .background(RoundedRectangle(cornerRadius: 14).fill(PocketColor.practiceCTA))
    }
}
