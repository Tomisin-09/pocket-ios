import SwiftUI
import UIKit

/// **Where the theme is applied** (ADR 0311 D8, ADR 0312), once, at the root, the way the appearance is.
///
/// It reads the player's choice and the plan, and sets the theme the app draws in (`\.moonTheme`):
/// the choice while the plan is on, Blood Moon while it's off (0312 D1). Every themed colour beneath
/// follows (`ThemeColor.swift`), and so do the wordmark and logo, which read the same value.
///
/// It also keeps the **App Icon** in step (0312 D3, ADR 0314): the theme's icon, or the one moon's the
/// player keeps, whenever either changes and whenever the app comes back to the foreground, which is
/// the only time iOS lets an app change it.
private struct MoonThemeHost: ViewModifier {
    @Environment(PlanStore.self) private var plan: PlanStore?
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppSettings.Key.moonTheme) private var chosen = MoonTheme.standard
    @AppStorage(AppSettings.Key.appIcon) private var iconChoice = AppIconChoice.standard

    private var planHasResolved: Bool { plan?.hasResolved ?? true }

    private var effective: MoonTheme {
        MoonTheme.effective(chosen: chosen, planIsOn: plan.planIsOn, planHasResolved: planHasResolved)
    }

    /// The moon whose icon belongs on the Home Screen (ADR 0314 D3).
    private var icon: MoonTheme {
        AppIconChoice.effective(chosen: iconChoice, planIsOn: plan.planIsOn, planHasResolved: planHasResolved)
            .icon(drawnTheme: effective)
    }

    func body(content: Content) -> some View {
        content
            .environment(\.moonTheme, effective)
            // And on the window scene, for what's presented over this (see `MoonThemeScenes`).
            .onChange(of: effective, initial: true) { _, theme in MoonThemeScenes.apply(theme) }
            .onChange(of: icon, initial: true) { _, icon in AppIcon.follow(icon) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { AppIcon.follow(icon) }
            }
    }
}

/// **The theme for everything presented**: sheets, covers, popovers, alerts (ADR 0312 D6, fixed in pocket-469).
///
/// A presented sheet doesn't take `\.moonTheme` from the view that presented it. Its hosting
/// controller reads the value back from its own UIKit traits, and those come from the window scene,
/// not from the root's environment. So with the environment alone, every sheet drew Blood Moon
/// whatever the theme: Name the notes, Watch, the wordmark in a prompt. Setting the trait on the
/// scene gives every window and everything presented in it the same theme as the root.
@MainActor
enum MoonThemeScenes {
    static func apply(_ theme: MoonTheme, to scenes: Set<UIScene> = UIApplication.shared.connectedScenes) {
        for case let scene as UIWindowScene in scenes {
            // Reading an override that was never set is an assertion failure in UIKit, so ask first.
            let overrides = scene.traitOverrides
            if overrides.contains(MoonThemeTrait.self), overrides[MoonThemeTrait.self] == theme { continue }
            scene.traitOverrides[MoonThemeTrait.self] = theme
        }
    }
}

/// The Home Screen icon: the theme's, or one moon's (ADR 0312 D3, ADR 0314).
@MainActor
enum AppIcon {
    /// Set `moon`'s icon, if it isn't already set. iOS confirms each change with an alert of its own,
    /// so this only asks when the icon is actually wrong, and only while the app is in front.
    ///
    /// Not under the UI tests: the system's alert would sit over whatever the test taps next.
    static func follow(_ moon: MoonTheme) {
        guard !UITestRuntime.isActive else { return }
        let application = UIApplication.shared
        guard application.supportsAlternateIcons, application.applicationState == .active,
              application.alternateIconName != moon.alternateIconName else { return }
        application.setAlternateIconName(moon.alternateIconName)
    }
}

extension View {
    /// Apply the player's moon theme and keep the App Icon in step (once, at the root, inside
    /// `.environment(plan)`, which it reads).
    func moonThemeHost() -> some View {
        modifier(MoonThemeHost())
    }
}
