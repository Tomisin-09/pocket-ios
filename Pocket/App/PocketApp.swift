import SwiftData
import SwiftUI

@main
struct PocketApp: App {
    // Drives per-screen orientation (ADR 0042) — see OrientationGate.swift.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: [Song.self, Loop.self, Marker.self, JournalEntry.self,
                              MetronomeExercise.self])
    }
}
