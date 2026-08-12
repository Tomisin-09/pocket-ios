import SwiftUI

/// **Settings ▸ Help & About** (ADR 0162 D2) — version, the help catalog, the way to reach us, and the
/// two legal links, under the wordmark.
///
/// `AboutSection` is unchanged; this is the screen that hosts it. Help & FAQs stays a `NavigationLink`
/// rather than a sheet (ADR 0145 D1) — it pushes onto the same stack and backs out to here, which is
/// still true one level deeper.
struct AboutSettingsView: View {
    var body: some View {
        Form {
            AboutSection()
        }
        .settingsScreen(title: "Help & About")
    }
}

#Preview {
    NavigationStack { AboutSettingsView() }
        .preferredColorScheme(.dark)
}
