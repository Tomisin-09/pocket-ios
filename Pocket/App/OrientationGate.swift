import SwiftUI

// Per-screen orientation control (ADR 0042). Pure SwiftUI has no first-class per-view
// orientation lock, so the app is portrait-locked by default and individual screens opt
// into landscape. `Info.plist` lists the allowed orientations app-wide (portrait +
// landscape); this gate narrows them per screen by driving the app delegate's
// `supportedInterfaceOrientationsFor` from app state. Without the gate every screen would
// become rotatable the moment landscape is added to `Info.plist`.

/// App delegate whose sole job is to answer UIKit's orientation query from a mutable mask.
/// Registered via `@UIApplicationDelegateAdaptor` on `PocketApp`.
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// The orientations currently allowed. Defaults to portrait — only a screen that opts
    /// in (via `.landscapeEnabled()`) widens it, and reverts on disappear.
    static var orientationMask: UIInterfaceOrientationMask = .portrait

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        AppDelegate.orientationMask
    }
}

/// Sets the allowed orientation mask and asks the active scene to re-evaluate it, so a
/// revert to `.portrait` actively rotates the device back if it's currently in landscape.
enum OrientationGate {
    // Touches `UIApplication.shared` and the scene's geometry, all main-actor APIs (and
    // `AppDelegate.orientationMask` is main-actor isolated too), so the call must be on the
    // main actor — Swift 6 enforces this. The `.onAppear`/`.onDisappear` callers already are.
    @MainActor
    static func set(_ mask: UIInterfaceOrientationMask) {
        AppDelegate.orientationMask = mask
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
        scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}

private struct LandscapeEnabled: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear { OrientationGate.set([.portrait, .landscape]) }
            .onDisappear { OrientationGate.set(.portrait) }
    }
}

extension View {
    /// Opt this screen into landscape; reverts to portrait-only (rotating back if needed)
    /// when it disappears. ADR 0042: only the practice screen uses this.
    func landscapeEnabled() -> some View {
        modifier(LandscapeEnabled())
    }
}
