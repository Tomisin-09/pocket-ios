import SwiftUI

extension View {
    /// The shared big-pill look for the Practice run screens' primary transport buttons
    /// (`LoopRunView` / `ExerciseRunView`) — a filled, full-width practice-tinted pill.
    var pocketRunButton: some View {
        self
            .font(.futura(.headline))
            .foregroundStyle(PocketColor.background)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(RoundedRectangle(cornerRadius: 14).fill(PocketColor.practice))
    }
}
