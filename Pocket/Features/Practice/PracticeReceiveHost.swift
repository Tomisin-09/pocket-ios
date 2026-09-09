import SwiftData
import SwiftUI

/// A decoded file waiting for the player's yes (ADR 0188 D9).
///
/// A wrapper with its own `id` rather than making the payload `Identifiable`: two files can hold
/// byte-identical practice, and `.sheet(item:)` reads identity as "is this the same presentation". A
/// per-arrival id means opening the same file twice presents twice, which is what D1's "produces a
/// second copy, on purpose" implies at the presentation layer too.
private struct PendingReceive: Identifiable {
    let id = UUID()
    let practice: ReceivedPractice
}

/// The app's **inbound door** for `.redmoonpractice` files (ADR 0188 S2, ADR 0209 D4) — both doors,
/// both payload kinds.
///
/// Applied **once** at the app root, styled directly on `PaywallHost`, and for the same reason: one
/// host means one preview sheet for the whole app, and the two doors cannot present different
/// things or write by different rules.
///
/// **Why the root and not the Routines library.** Tap-to-open is the door ADR 0188 D3 spends its
/// length defending, and it can arrive with no screen of the app's own on top — from Messages, Mail,
/// Files or AirDrop, on a cold launch. There is no view further down the tree that is guaranteed to
/// be mounted when the URL lands, so the receiver has to be the one view that always is. The in-app
/// pickers then call the same code through `\.receivePracticeFile` rather than owning a copy of it.
///
/// **It does not care which library the file belongs in.** A drill picked from the Routines screen
/// lands in Exercises and says so; that is a property of the file, not of where it was opened, and
/// making the pickers kind-specific would mean four doors to keep in step instead of one.
private struct PracticeReceiveHost: ViewModifier {
    @Environment(\.modelContext) private var context
    /// Receiving mints a routine or a drill, which is authoring — Pro (ADR 0112, ADR 0144).
    @Environment(\.isPro) private var isPro
    @Environment(\.presentPaywall) private var presentPaywall

    @State private var pending: PendingReceive?
    @State private var failure: String?
    /// What just landed, and where it went, for the confirmation. Door A can land practice while the
    /// player is looking at the Toolkit, so "it worked" has to be said rather than shown.
    @State private var landed: String?

    func body(content: Content) -> some View {
        content
            // The second door's entry point. `removingSource: false` is the whole reason this is a
            // parameter: a picked URL points at the player's *own* file, wherever they keep it, and
            // deleting it would be the app tidying up somebody else's Files app.
            .environment(\.receivePracticeFile, { url in open(url, removingSource: false) })
            // The first door. A tapped file arrives as a copy the system has already placed in this
            // app's own inbox, so it is ours to remove once read — and nothing ever reads it again.
            .onOpenURL { url in open(url, removingSource: true) }
            .sheet(item: $pending) { arrival in
                switch arrival.practice {
                case let .routine(received):
                    ReceivedRoutinePreviewSheet(received: received) { add(received) }
                case let .exercise(received):
                    ReceivedExercisePreviewSheet(received: received) { add(received) }
                }
            }
            .alert("Couldn’t open that file", isPresented: presenting($failure)) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
            .alert("Added", isPresented: presenting($landed)) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(landed ?? "")
            }
    }

    /// Read a file and offer what is in it — or say why not.
    ///
    /// **The gate moved behind the read in ADR 0209, and the move is deliberate.** ADR 0188 checked
    /// Pro *before* opening the file, on the grounds that a free player's problem is not the file, so
    /// they should get the offer rather than a report about JSON. That worked while a routine was the
    /// only thing a file could hold and the answer was "Pro, always". An exercise's gate depends on
    /// its **template**, which is a fact about the file — so the file has to be read to know which
    /// question to ask. What changes for a free player is only the *failing* cases: a corrupt or
    /// future-version file now reports itself instead of presenting a paywall for a file that was
    /// never going to open, which is the more honest of the two. A valid file still walls exactly as
    /// it did.
    private func open(_ url: URL, removingSource: Bool) {
        // Runs whichever way this returns, the paywall included: an inbox copy the app has decided
        // not to act on is dead weight nothing will ever read again.
        defer { if removingSource { try? FileManager.default.removeItem(at: url) } }
        // Bracketed the way the app's four audio importers already bracket a picked URL. Harmless on
        // an inbox copy, which is inside this app's own container and needs no scope.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            failure = "That file couldn’t be read."
            return
        }
        switch ReceivedPracticeBuilder.evaluate(data: data) {
        case let .success(practice):
            guard allowed(practice) else { return }
            pending = PendingReceive(practice: practice)
        case let .failure(reason):
            failure = reason.message
        }
    }

    /// May this player take what the file holds? Presents the paywall and returns `false` when not.
    ///
    /// The gate has to live here as well as in front of each picker, because tap-to-open has no
    /// "before" moment of its own to gate at — no button was pressed.
    ///
    /// An exercise whose template this build does not recognise is refused for a free player rather
    /// than waved through: an unreadable tier is not a free tier, and the trigger carries `nil`,
    /// which is a true statement about what was reached for.
    private func allowed(_ practice: ReceivedPractice) -> Bool {
        switch practice {
        case .routine:
            guard AccessPolicy.canAuthorRoutine(isPro: isPro) else {
                presentPaywall(.routine(.receive))
                return false
            }
        case let .exercise(received):
            let template = received.template
            guard let template, AccessPolicy.canAuthor(template, isPro: isPro) else {
                presentPaywall(.receivedExercise(template))
                return false
            }
        }
        return true
    }

    /// Write a routine — one of the two places in the receiving path that touch the store.
    ///
    /// The graph comes back uninserted and `HydratedRoutine.insert` knows the one order that works,
    /// so this is a hand-off rather than an assembly.
    private func add(_ received: ReceivedRoutine) {
        let landing = ReceivedRoutineBuilder.materialize(received)
        landing.insert(into: context)
        save()
        // Both numbers, because the interesting question about this feature is not how often it is
        // used but how much of a shared routine actually crosses (D4). Two `Int`s — the analytics
        // lint rule forbids a free `String`, and there is nothing here worth naming anyway.
        Analytics.send(.routineReceived(items: landing.items.count,
                                        orphanedBlocks: landing.items.filter(\.isOrphaned).count))
        landed = "“\(received.displayName)” is in your routines."
        haptic(.medium)
    }

    /// Write a drill (ADR 0209 D4). One row, and the asymmetry with the routine's three is the point
    /// of having the two functions rather than one that branches inside.
    ///
    /// The template is read off the record rather than the fresh model: they agree, and reading the
    /// file's own value keeps the event about **what was sent**. `allowed(_:)` has already refused a
    /// template this build cannot name, so the fallback is unreachable and merely total.
    private func add(_ received: ReceivedExercise) {
        let landing = ReceivedPracticeBuilder.materialize(received)
        landing.insert(into: context)
        save()
        Analytics.send(.exerciseReceived(template: received.template ?? .basic))
        landed = "“\(received.displayName)” is in your exercises."
        haptic(.medium)
    }

    /// Saved rather than left to autosave: Door A can land practice seconds before the player
    /// switches back to the app that sent it, and a receive that has to survive being backgrounded is
    /// not a good candidate for "the context will get to it".
    private func save() {
        try? context.save()
    }

    /// A `Bool` binding over an optional message, the idiom `LibraryView.importErrorBinding` uses:
    /// the alert clears the message when it is dismissed, so a second failure presents again.
    private func presenting(_ message: Binding<String?>) -> Binding<Bool> {
        Binding(get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } })
    }
}

/// Open a `.redmoonpractice` file, from anywhere in the app (ADR 0188 S2, ADR 0209 D4).
///
/// Defaults to a no-op so a view in an Xcode preview or a test does nothing rather than trapping on
/// a host that isn't there — the same preview-safe shape `\.presentPaywall` has, and the reason both
/// are environment actions rather than a shared singleton.
private struct ReceivePracticeFileKey: EnvironmentKey {
    static let defaultValue: @MainActor (URL) -> Void = { _ in }
}

extension EnvironmentValues {
    /// Hand a `.redmoonpractice` file to the app's one receiving door, whatever it holds.
    /// `@MainActor` — it mutates view state, like `presentPaywall`.
    var receivePracticeFile: @MainActor (URL) -> Void {
        get { self[ReceivePracticeFileKey.self] }
        set { self[ReceivePracticeFileKey.self] = newValue }
    }
}

extension View {
    /// Install the app-wide receiving door (once, at the root, **inside** the paywall host's
    /// environment — it reads `\.isPro` and `\.presentPaywall`).
    func practiceReceiveHost() -> some View {
        modifier(PracticeReceiveHost())
    }
}
