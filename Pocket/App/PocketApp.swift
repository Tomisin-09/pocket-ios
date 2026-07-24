import SwiftData
import SwiftUI

@main
struct PocketApp: App {
    // Drives per-screen orientation (ADR 0042) — see OrientationGate.swift.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    // Appearance override (ADR 0062 follow-up) — read at the root so the whole app
    // repaints when it changes, rather than each screen consulting it separately.
    @AppStorage(AppSettings.Key.appearance) private var appearance = AppearancePreference.system

    // The app's single Red Moon Pro entitlement source (ADR 0112) — resolves `isPro` from StoreKit
    // and is read by every paywall gate through the environment. Owned here for the app's lifetime.
    @State private var store = StoreManager()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
                .preferredColorScheme(appearance.colorScheme)
        }
        .modelContainer(for: [Song.self, Loop.self, Marker.self, JournalEntry.self,
                              Exercise.self, Routine.self, RoutineItem.self, Goal.self,
                              Recording.self, SavedChord.self, Profile.self])
    }
}
