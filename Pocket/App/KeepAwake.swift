import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Keep the screen awake while a practice/playback surface is on screen (Settings V1, ADR 0050).
/// You play along hands-free, so the idle timer locking the phone mid-session is disruptive.
/// Self-contained: it reads the setting via `@AppStorage` (so toggling it takes effect live),
/// disables the idle timer on appear / when switched on, and — critically — **always** restores
/// it on disappear so the setting never leaks past the practice screens.
private struct KeepAwakeModifier: ViewModifier {
    @AppStorage(AppSettings.Key.keepScreenAwake) private var keepAwake = true

    func body(content: Content) -> some View {
        content
            .onAppear { apply(keepAwake) }
            .onChange(of: keepAwake) { _, enabled in apply(enabled) }
            .onDisappear { apply(false) }
    }

    @MainActor private func apply(_ disableIdleTimer: Bool) {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = disableIdleTimer
        #endif
    }
}

extension View {
    /// Hold the screen awake on this practice surface while `keepScreenAwake` is on.
    func keepAwakeDuringPractice() -> some View { modifier(KeepAwakeModifier()) }
}
