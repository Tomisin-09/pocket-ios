import SwiftData
import SwiftUI

/// **The app's half of *Save to Red Moon*** (ADR 0264 D9), applied once at the root, which is the one
/// view mounted whenever the app comes back.
///
/// - **Coming to the foreground**, it files what the extension saved (`ShareInboxDrain`), then writes
///   the owner snapshot.
/// - **Going to the background**, it writes the snapshot again. That is the moment that matters: on an
///   iPhone, another app's share sheet is only reachable with Red Moon in the background, so a snapshot
///   written as the app leaves holds every place added, renamed or deleted while it was open.
/// - **When the plan standing or the appearance changes**, it writes the snapshot, since both are drawn
///   by the extension.
///
/// Until StoreKit has answered, nothing is written: the standing isn't known, and the last snapshot is
/// right more often than a guess would be (D6's standings only move forward).
private struct ShareInboxHost: ViewModifier {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PlanStore.self) private var plan: PlanStore?
    @AppStorage(AppSettings.Key.appearance) private var appearance = AppearancePreference.system

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase, initial: true) { _, phase in
                switch phase {
                case .active:
                    drain()
                    writeSnapshot()
                case .background:
                    writeSnapshot()
                default:
                    break
                }
            }
            .onChange(of: standing) { writeSnapshot() }
            .onChange(of: appearance) { writeSnapshot() }
    }

    /// Where the player stands, once StoreKit has said.
    private var standing: PlanStanding? {
        guard let plan, plan.hasResolved else { return nil }
        return PlanStanding(access: plan.access, hasBoughtBefore: plan.hasBoughtBefore)
    }

    private func drain() {
        guard let directory = ShareContainer.directory() else { return }
        // Before StoreKit answers, as a paying player, as the in-app picker reads it: the snapshot the
        // save was picked from was written with the standing known, and a standing never moves back.
        ShareInboxDrain.drain(from: directory, standing: standing ?? .onPlan, in: context)
    }

    private func writeSnapshot() {
        guard let standing, let directory = ShareContainer.directory() else { return }
        try? ShareOwnerSnapshot(context: context, standing: standing, appearance: appearance).write(to: directory)
    }
}

extension View {
    /// Install *Save to Red Moon*'s app half (once, at the root).
    func shareInboxHost() -> some View {
        modifier(ShareInboxHost())
    }
}
