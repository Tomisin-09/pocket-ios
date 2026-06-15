import SwiftUI

@main
struct PocketApp: App {
    var body: some Scene {
        WindowGroup {
            // Temporary: launch straight into the P1 waveform practice screen
            // while it's being designed. Reverts to `HomeView()` once the
            // planner/navigation lands (Phase 3).
            WaveformPracticeView()
        }
    }
}
