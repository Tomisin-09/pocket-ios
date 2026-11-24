import SwiftUI

/// **The Red Moon lockup at the top of Settings** (ADR 0316): the moon beside the wordmark on one line, as
/// the site's header sets them, in the player's theme (ADR 0312 D2), so Settings looks like Red Moon's own
/// rather than a system list. One line, so the hub's rows stay where a thumb finds them.
///
/// The art is the theme's own cut of the mark and the wordmark (`derive-brand-svgs.py --themes`), so no
/// colour is applied here and Blood Moon draws the brand exactly.
struct SettingsBrandHeader: View {
    @Environment(\.moonTheme) private var theme

    /// How tall the wordmark's letters stand. The moon stands taller, as it does on the site.
    static let wordmarkHeight: CGFloat = 24
    static let markHeight: CGFloat = 34

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(theme.markImage)
                .resizable()
                .scaledToFit()
                .frame(height: Self.markHeight)
            Image(theme.wordmarkImage)
                .resizable()
                .scaledToFit()
                .frame(height: Self.wordmarkHeight)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Red Moon")
    }
}

#Preview("Cold Moon") {
    NavigationStack {
        Form {
            Section {
                Text("You")
            } header: {
                SettingsBrandHeader()
            }
        }
    }
    .environment(\.moonTheme, .cold)
}
