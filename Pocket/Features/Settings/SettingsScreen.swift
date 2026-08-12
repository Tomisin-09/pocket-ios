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

/// One row of the Settings hub (ADR 0162 D1): an icon, a title, and — where a single setting
/// dominates the destination — that setting's current value.
///
/// **The value is optional on purpose (D3).** A row like *Song player* holds four unranked toggles;
/// electing one of them to display would be arbitrary and would misreport the screen. A blank
/// trailing slot is more honest than a confident summary of a quarter of the truth.
struct SettingsHubRow: View {
    let icon: String
    let title: String
    var value: String?

    var body: some View {
        LabeledContent {
            if let value {
                Text(value)
                    .foregroundStyle(PocketColor.textSecondary)
                    .lineLimit(1)
            }
        } label: {
            Label {
                Text(title).foregroundStyle(PocketColor.textPrimary)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
    }
}
