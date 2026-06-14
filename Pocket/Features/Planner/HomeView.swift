import SwiftUI

/// Placeholder home screen. The real home (per the brief) is the practice
/// planner: a time selector, routines, and the music library — built in
/// Phase 3. For now it confirms the app launches and the design tokens load.
struct HomeView: View {
    var body: some View {
        ZStack {
            PocketColor.background.ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Pocket")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(PocketColor.textPrimary)
                Text("Practice scaffold — Phase 0")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(PocketColor.active)
            }
        }
    }
}

#Preview {
    HomeView()
}