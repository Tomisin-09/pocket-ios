import SwiftData
import SwiftUI

/// A decoded file waiting for the player's yes (ADR 0188 D9).
///
/// A wrapper with its own `id` rather than making `ReceivedRoutine` `Identifiable`: two files can
/// hold byte-identical routines, and `.sheet(item:)` reads identity as "is this the same
/// presentation". A per-arrival id means opening the same file twice presents twice, which is what
/// D1's "produces a second copy, on purpose" implies at the presentation layer too.
private struct PendingReceive: Identifiable {
    let id = UUID()
    let routine: ReceivedRoutine
}

/// The app's **inbound door** for `.redmoonpractice` files (ADR 0188 S2) — both of them.
///
/// Applied **once** at the app root, styled directly on `PaywallHost`, and for the same reason: one
/// host means one preview sheet for the whole app, and the two doors cannot present different
/// things or write by different rules.
///
/// **Why the root and not the Routines library.** Tap-to-open is the door D3 spends its length
/// defending, and it can arrive with no screen of the app's own on top — from Messages, Mail, Files
/// or AirDrop, on a cold launch. There is no view further down the tree that is guaranteed to be
/// mounted when the URL lands, so the receiver has to be the one view that always is. The in-app
/// picker then calls the same code through `\.receiveRoutineFile` rather than owning a second copy
/// of it.
///
/// This is the app's **first** inbound-URL path: there was no `.onOpenURL` anywhere before this
/// slice, and `AppDelegate` handles no URLs.
private struct RoutineReceiveHost: ViewModifier {
    @Environment(\.modelContext) private var context
    /// Receiving mints a routine, which is authoring — Pro, with no free-tier escape (ADR 0112).
    @Environment(\.isPro) private var isPro
    @Environment(\.presentPaywall) private var presentPaywall

    @State private var pending: PendingReceive?
    @State private var failure: String?
    /// The name of the routine that just landed, for the confirmation. Door A can land a routine
    /// while the player is looking at the Toolkit, so "it worked" has to be said rather than shown.
    @State private var landed: String?

    func body(content: Content) -> some View {
        content
            // The second door's entry point. `removingSource: false` is the whole reason this is a
            // parameter: a picked URL points at the player's *own* file, wherever they keep it, and
            // deleting it would be the app tidying up somebody else's Files app.
            .environment(\.receiveRoutineFile, { url in open(url, removingSource: false) })
            // The first door. A tapped file arrives as a copy the system has already placed in this
            // app's own inbox, so it is ours to remove once read — and nothing ever reads it again.
            .onOpenURL { url in open(url, removingSource: true) }
            .sheet(item: $pending) { arrival in
                ReceivedRoutinePreviewSheet(received: arrival.routine) { add(arrival.routine) }
            }
            .alert("Couldn’t open that file", isPresented: presenting($failure)) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
            .alert("Added", isPresented: presenting($landed)) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("“\(landed ?? "")” is in your routines.")
            }
    }

    /// Read a file and offer what is in it — or say why not.
    ///
    /// **The gate comes before the read**, and before the preview. A free player's problem is not the
    /// file, so they get the offer rather than a report about JSON; and tap-to-open has no "before"
    /// moment of its own to gate at — no button was pressed — which is why the check has to live
    /// here as well as in front of the picker.
    private func open(_ url: URL, removingSource: Bool) {
        // Runs whichever way this returns, the paywall included: an inbox copy the app has decided
        // not to act on is dead weight nothing will ever read again.
        defer { if removingSource { try? FileManager.default.removeItem(at: url) } }
        guard AccessPolicy.canAuthorRoutine(isPro: isPro) else {
            return presentPaywall(.routine(.receive))
        }
        // Bracketed the way the app's four audio importers already bracket a picked URL. Harmless on
        // an inbox copy, which is inside this app's own container and needs no scope.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            failure = "That file couldn’t be read."
            return
        }
        switch ReceivedRoutineBuilder.evaluate(data: data) {
        case let .success(received): pending = PendingReceive(routine: received)
        case let .failure(reason): failure = reason.message
        }
    }

    /// Write it — the only place in the receiving path that touches the store.
    ///
    /// The graph comes back uninserted and `HydratedRoutine.insert` knows the one order that works,
    /// so this is a hand-off rather than an assembly.
    private func add(_ received: ReceivedRoutine) {
        let landing = ReceivedRoutineBuilder.materialize(received)
        landing.insert(into: context)
        // Saved rather than left to autosave: Door A can land a routine seconds before the player
        // switches back to the app that sent it, and a receive that has to survive being backgrounded
        // is not a good candidate for "the context will get to it".
        try? context.save()
        // Both numbers, because the interesting question about this feature is not how often it is
        // used but how much of a shared routine actually crosses (D4). Two `Int`s — the analytics
        // lint rule forbids a free `String`, and there is nothing here worth naming anyway.
        Analytics.send(.routineReceived(items: landing.items.count,
                                        orphanedBlocks: landing.items.filter(\.isOrphaned).count))
        landed = received.displayName
        haptic(.medium)
    }

    /// A `Bool` binding over an optional message, the idiom `LibraryView.importErrorBinding` uses:
    /// the alert clears the message when it is dismissed, so a second failure presents again.
    private func presenting(_ message: Binding<String?>) -> Binding<Bool> {
        Binding(get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } })
    }
}

/// Open a `.redmoonpractice` file, from anywhere in the app (ADR 0188 S2).
///
/// Defaults to a no-op so a view in an Xcode preview or a test does nothing rather than trapping on
/// a host that isn't there — the same preview-safe shape `\.presentPaywall` has, and the reason both
/// are environment actions rather than a shared singleton.
private struct ReceiveRoutineFileKey: EnvironmentKey {
    static let defaultValue: @MainActor (URL) -> Void = { _ in }
}

extension EnvironmentValues {
    /// Hand a `.redmoonpractice` file to the app's one receiving door. `@MainActor` — it mutates
    /// view state, like `presentPaywall`.
    var receiveRoutineFile: @MainActor (URL) -> Void {
        get { self[ReceiveRoutineFileKey.self] }
        set { self[ReceiveRoutineFileKey.self] = newValue }
    }
}

extension View {
    /// Install the app-wide receiving door (once, at the root, **inside** the paywall host's
    /// environment — it reads `\.isPro` and `\.presentPaywall`).
    func routineReceiveHost() -> some View {
        modifier(RoutineReceiveHost())
    }
}
