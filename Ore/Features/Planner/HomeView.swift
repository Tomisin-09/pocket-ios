import SwiftUI

/// Placeholder home screen. The real home (per the brief) is the practice
/// planner: a time selector, routines, and the music library — built in
/// Phase 3. For now it confirms the app launches and the design tokens load.
struct HomeView: View {
    var body: some View {
        ZStack {
            OreColor.background.ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Ore")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(OreColor.textPrimary)
                Text("Practice scaffold — Phase 0")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(OreColor.active)
            }
        }
    }
}

#Preview {
    HomeView()
}