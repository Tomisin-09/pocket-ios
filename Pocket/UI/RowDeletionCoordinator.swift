import SwiftUI

/// One row's pending deletion: what to remove, what to call it in the toast, and the closure
/// that actually performs the delete once the undo window closes.
///
/// `id` identifies the row for the **pending-deletion filter** a list applies while the toast is
/// up. Use the model's business `uid` where it has one (`Exercise`, `Loop`, `Routine`) and its
/// `persistentModelID` where it doesn't (`Song`) — `AnyHashable` so either works, and so the
/// coordinator can be unit-tested with plain `UUID`s rather than inserted `@Model`s (inserting one
/// in the XCTest host traps; see `docs/swiftdata-gotchas.md`).
struct PocketRowDelete {
    let id: AnyHashable
    /// The item's display name — "Deleted Spider".
    let name: String
    /// The real delete, deferred until the undo window closes.
    let perform: () -> Void
}

/// **Deferred, undoable row deletion** for list screens (Slice 3, the list-uniformity pass).
///
/// The waveform's loop/marker deletes take the opposite route (ADR 0019): delete straight away and
/// rebuild from a snapshot on Undo. That works there because a loop is a handful of scalars with
/// one owner. It does **not** generalise to the libraries — restoring an `Exercise` would have to
/// rebuild its routine-block links, song links, journal and takes, all of which the real delete
/// nullifies or cascades away. So the libraries defer instead: the row is hidden from the list, the
/// toast runs, and `context.delete` only happens when the window closes. Undo is then genuinely
/// free — nothing was ever destroyed.
///
/// The window closes on whichever comes first: the timer expiring, a **second** delete (only the
/// latest is undoable, matching the waveform), leaving the screen, or the app leaving the
/// foreground. Nothing is ever lost by a missed commit — the worst case is a deletion that didn't
/// happen, which the user can repeat.
@MainActor
@Observable
final class RowDeletionCoordinator {
    /// The live toast, if any. `id` changes per presentation so a replacement re-animates.
    struct Toast: Identifiable {
        let id = UUID()
        let message: String
    }

    private(set) var toast: Toast?
    /// Rows hidden from their list while their delete is pending.
    private(set) var pending: Set<AnyHashable> = []

    /// How long the undo window stays open — four seconds for a player, **stretched under
    /// `-uiTesting`** (the launch flag `StoreManager` and the profile moment already read).
    ///
    /// The UI test that covers this pins the *wiring* — Undo restores the row on the same screen —
    /// not the toast's lifetime. But XCUITest works in whole seconds: a query, a hit-point
    /// resolution and a tap are each hundreds of milliseconds, and a loaded CI runner stretches
    /// them further, so the harness can spend a four-second wall-clock budget before it reaches the
    /// button it just saw. That is what turned a working feature into a red `main` (CI run
    /// 30441349304: `undo.waitForExistence` passed, then `undo.tap()` found no matches). Giving the
    /// harness room removes a race that was never the thing under test. The **real** duration is
    /// covered by `RowDeletionCoordinatorTests`, which runs without the flag and waits it out.
    static var window: Duration {
        UITestRuntime.isActive ? .seconds(120) : .seconds(4)
    }

    private var commits: [AnyHashable: () -> Void] = [:]
    private var expiry: Task<Void, Never>?

    /// Hide the row, show the Undo toast, and schedule the real delete. A second request commits
    /// the first — the latest delete is the one you can undo.
    func request(_ deletion: PocketRowDelete) {
        commitPending()
        pending.insert(deletion.id)
        commits[deletion.id] = deletion.perform
        withAnimation(.easeOut(duration: 0.2)) { toast = Toast(message: "Deleted \(deletion.name)") }
        expiry = Task { [weak self] in
            try? await Task.sleep(for: Self.window)
            guard !Task.isCancelled else { return }
            self?.commitPending()
        }
    }

    /// Whether this row is awaiting deletion, and so should be filtered out of its list.
    func isPending(_ id: AnyHashable) -> Bool { pending.contains(id) }

    /// Tapped Undo — the row comes back and nothing is deleted.
    func undo() {
        expiry?.cancel()
        expiry = nil
        commits.removeAll()
        pending.removeAll()
        withAnimation(.easeOut(duration: 0.2)) { toast = nil }
    }

    /// Close the window now and perform every pending delete — the timer expiring, a second
    /// delete, leaving the screen, or backgrounding. Idempotent.
    func commitPending() {
        expiry?.cancel()
        expiry = nil
        let due = Array(commits.values)
        commits.removeAll()
        pending.removeAll()
        withAnimation(.easeOut(duration: 0.2)) { toast = nil }
        for commit in due { commit() }
    }
}

// MARK: - Environment plumbing

/// The row-delete seam a `.pocketRowActions` row talks to, as closures rather than the coordinator
/// itself so the environment has a **safe default** (the `PaywallTrigger` pattern): a row outside a
/// `.pocketRowUndoHost()` — an Xcode preview, a test — deletes immediately with no toast, exactly
/// as the lists behaved before this slice, instead of trapping on a missing `@Observable`.
struct RowDeletionSeam {
    var request: @MainActor (PocketRowDelete) -> Void
    var isPending: @MainActor (AnyHashable) -> Bool
}

private struct RowDeletionKey: EnvironmentKey {
    // `@MainActor`-isolated so the function types are `Sendable` as a static default; rows only
    // ever call these from the main-actor view context anyway.
    static let defaultValue = RowDeletionSeam(request: { $0.perform() }, isPending: { _ in false })
}

extension EnvironmentValues {
    /// Deferred row deletion + the pending-row filter. Defaults to an immediate, un-undoable
    /// delete when no `.pocketRowUndoHost()` is installed above.
    var rowDeletion: RowDeletionSeam {
        get { self[RowDeletionKey.self] }
        set { self[RowDeletionKey.self] = newValue }
    }
}

extension View {
    /// Install the undo toast + deferred-delete seam for a list screen, backed by a coordinator the
    /// **screen itself owns** (`@State private var rowDeletion = RowDeletionCoordinator()`).
    ///
    /// The screen owns it rather than the modifier because the screen has to read `isPending`
    /// **itself**, to filter pending rows out of its list, empty state and filter menus. A modifier
    /// applied inside `body` publishes its environment to that view's *descendants* only — the
    /// screen's own `@Environment` resolves from its parent — so a modifier-owned coordinator left
    /// every filter reading the default no-op seam and nothing ever came back on Undo. Passing the
    /// coordinator in keeps one instance visible to both halves; the environment seam it publishes
    /// is what the **rows** (true descendants) talk to.
    func pocketRowUndoHost(_ coordinator: RowDeletionCoordinator) -> some View {
        modifier(PocketRowUndoHost(coordinator: coordinator))
    }
}

/// Publishes the screen's coordinator as a row-facing seam and renders its toast.
private struct PocketRowUndoHost: ViewModifier {
    let coordinator: RowDeletionCoordinator
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .environment(\.rowDeletion,
                          RowDeletionSeam(request: { coordinator.request($0) },
                                          isPending: { coordinator.isPending($0) }))
            .overlay(alignment: .bottom) {
                if let toast = coordinator.toast {
                    UndoToastView(message: toast.message) {
                        coordinator.undo()
                        haptic(.light)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            // Leaving the screen (or the foreground) closes the window: a delete the user walked
            // away from is a delete they meant.
            .onDisappear { coordinator.commitPending() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { coordinator.commitPending() }
            }
    }
}
