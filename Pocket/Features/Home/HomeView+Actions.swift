import SwiftUI

// The hub's own action controls — the add-song toolbar button and the "Start today's session" CTA —
// split out of `HomeView.swift` so it stays under the 400-line ceiling (and the type within
// SwiftLint's `type_body_length`). The presentational cards live in `HomeCards.swift`.

extension HomeView {
    /// Solid green disc with a bold dark plus — mirrors the app's dark-content-on-filled-colour
    /// convention (e.g. the teal CTA). Its enclosing `ToolbarItem` drops the iOS 26 shared glass
    /// background so the disc reads as a flat fill.
    var addSongButton: some View {
        Button { importing = true } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(PocketColor.background)
                .frame(width: 34, height: 34)
                .background(Circle().fill(PocketColor.active))
        }
        .accessibilityLabel("Add a song")
    }

    /// The **primary** home action (planner, ADR 0046/0015): a filled teal CTA that pushes
    /// `PlannerView`, where goals (set once) drive a freshly-generated, goal-adaptive session each
    /// run. In its own extension so `HomeView`'s body stays within `type_body_length`.
    var startTodaySessionCard: some View {
        NavigationLink { PlannerView() } label: { startTodaySessionLabel }
        .buttonStyle(.plain)
        .accessibilityLabel("Start today's session")
        .accessibilityHint("A fresh session generated from your goals and practice history")
    }

    var startTodaySessionLabel: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.futura(.title2))
                .foregroundStyle(PocketColor.background)
            VStack(alignment: .leading, spacing: 2) {
                Text("Start today's session")
                    .font(.futura(.headline))
                    .foregroundStyle(PocketColor.background)
                Text("A fresh session from your goals and history")
                    .font(.futura(.subheadline))
                    .foregroundStyle(PocketColor.background.opacity(0.85))
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.futura(.footnote, weight: .semibold))
                .foregroundStyle(PocketColor.background.opacity(0.85))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(PocketColor.practiceCTA))
    }
}
