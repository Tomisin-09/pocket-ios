import SwiftUI
import UIKit

/// **Where the theme is applied** (ADR 0311 D8, ADR 0312), once, at the root, the way the appearance is.
///
/// It reads the player's choice and the plan, and sets the theme the app draws in (`\.moonTheme`):
/// the choice while the plan is on, Blood Moon while it's off (0312 D1). Every themed colour beneath
/// follows (`ThemeColor.swift`), and so do the wordmark and logo, which read the same value.
///
/// It also keeps the **App Icon** in step (0312 D3), whenever the theme the app draws in changes and
/// whenever the app comes back to the foreground, which is the only time iOS lets an app change it.
private struct MoonThemeHost: ViewModifier {
    @Environment(PlanStore.self) private var plan: PlanStore?
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppSettings.Key.moonTheme) private var chosen = MoonTheme.standard

    private var effective: MoonTheme {
        MoonTheme.effective(chosen: chosen, planIsOn: plan.planIsOn, planHasResolved: plan?.hasResolved ?? true)
    }

    func body(content: Content) -> some View {
        content
            .environment(\.moonTheme, effective)
            .onChange(of: effective, initial: true) { _, theme in AppIcon.follow(theme) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { AppIcon.follow(effective) }
            }
    }
}

/// The Home Screen icon, which follows the theme (ADR 0312 D3).
@MainActor
enum AppIcon {
    /// Set the icon `theme` wears, if it isn't already set. iOS confirms each change with an alert of
    /// its own, so this only asks when the icon is actually wrong, and only while the app is in front.
    ///
    /// Not under the UI tests: the system's alert would sit over whatever the test taps next.
    static func follow(_ theme: MoonTheme) {
        guard !UITestRuntime.isActive else { return }
        let application = UIApplication.shared
        guard application.supportsAlternateIcons, application.applicationState == .active,
              application.alternateIconName != theme.alternateIconName else { return }
        application.setAlternateIconName(theme.alternateIconName)
    }
}

extension View {
    /// Apply the player's moon theme and keep the App Icon in step (once, at the root, inside
    /// `.environment(plan)`, which it reads).
    func moonThemeHost() -> some View {
        modifier(MoonThemeHost())
    }
}
