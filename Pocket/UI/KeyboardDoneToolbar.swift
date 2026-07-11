import SwiftUI

extension View {
    /// Adds a single **checkmark** button to the keyboard accessory bar that dismisses whatever field
    /// is being edited. The app's standard "off the keyboard" affordance — a checkmark (not the word
    /// "Done") so every text surface reads the same, and needed wherever the keyboard has no Return-key
    /// escape: multiline note fields (Return inserts a newline) and number pads (no Return key at all).
    ///
    /// Resigns the first responder directly rather than plumbing a `FocusState` binding through every
    /// call site, so it dismisses whichever field is up without the caller having to name it. The action
    /// runs on the main actor (SwiftUI button actions do), so the `UIApplication` hop is concurrency-safe.
    func keyboardDoneButton(tint: Color = PocketColor.practice) -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                    to: nil, from: nil, for: nil)
                } label: {
                    Image(systemName: "checkmark")
                }
                .tint(tint)
                .accessibilityLabel("Dismiss keyboard")
            }
        }
    }
}
