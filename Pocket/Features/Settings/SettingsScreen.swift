import SwiftUI

/// Shared chrome for every Settings destination (ADR 0162 D4).
///
/// Nine screens must not each hand-roll the same five modifiers. A sub-screen is then just a `Form`
/// of the sections it owns plus `.settingsScreen(title:)` — which is what stops the hub split from
/// trading one 344-line file for nine small ones that quietly drift apart.
extension View {
    /// The standard Settings-screen presentation: transparent form background over the app
    /// background, capped to a readable column at regular width (ADR 0105), inline title.
    func settingsScreen(title: String) -> some View {
        self
            .scrollContentBackground(.hidden)
            .readableWidth()
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}
