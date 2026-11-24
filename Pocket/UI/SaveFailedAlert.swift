import SwiftUI

/// **Couldn’t save** (ADR 0318): what a failed save says where the player has just asked for something
/// to be kept, by tapping Save or Done, stopping a take, or bringing something in.
///
/// The screen that saved stays as it was, so the change is still there to try again. A sheet stays open
/// rather than closing on work that hasn't been kept. *Try again* runs the same save. Run a moment later,
/// so a second failure can present the alert again after the first has finished dismissing. *Cancel*
/// leaves the change where it is: it is still in memory, and the next save that works keeps it.
///
/// Every other save logs a failure and says nothing (`ModelContext.saveOrLog()`, 0318 D2).
extension View {
    func saveFailedAlert(isPresented: Binding<Bool>, retry: @escaping @MainActor () -> Void,
                         onCancel: @escaping @MainActor () -> Void = {}) -> some View {
        alert(SaveFailedAlert.title, isPresented: isPresented) {
            Button("Try again") { Task { @MainActor in retry() } }
            Button("Cancel", role: .cancel) { onCancel() }
        } message: {
            Text(SaveFailedAlert.message)
        }
    }
}

/// The alert's words, in one place for the tests and the manual.
enum SaveFailedAlert {
    static let title = "Couldn’t save"
    static let message = "It’s still here, but it isn’t saved yet. If your iPhone is nearly full, freeing up "
        + "some space should fix it."
}
