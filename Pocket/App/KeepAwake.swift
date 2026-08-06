import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Keep the screen awake while a practice/playback surface is on screen (Settings V1, ADR 0050).
/// You play along hands-free, so the idle timer locking the phone mid-session is disruptive.
///
/// **Reference-counted, because the flag it drives is global** (device pass 2026-08-06). This was a
/// plain `onAppear`/`onDisappear` pair writing `UIApplication.isIdleTimerDisabled` directly, which is
/// a single process-wide slot with no notion of who asked. The moment two practice surfaces overlap —
/// which is *every* block change inside a routine — the outgoing screen's `onDisappear` re-enabled the
/// idle timer that the incoming screen's `onAppear` had just disabled, and the phone slept mid-session
/// with the setting still reading "on".
///
/// The lease is the same shape as `AudioSessionClaim` over `AudioPlumbing`, and for the same reason:
/// with a count, "am I still needed" is answered structurally instead of by every call site
/// remembering the order it runs in.
@MainActor
enum KeepAwakeLease {
    private static var holders = 0

    /// How many surfaces are currently asking. Exposed for tests, which assert *deltas* — the count is
    /// process-global across a run, so absolute assertions would make the suite order-dependent.
    static var holderCount: Int { holders }

    /// The whole decision, pure and separately testable: the idle timer is disabled only when someone
    /// is asking **and** the player has left the setting on. Two independent conditions — a surface
    /// holding a claim must not override the setting, and the setting alone must not keep a phone
    /// awake on the Home screen.
    static func shouldDisableIdleTimer(holders: Int, settingOn: Bool) -> Bool {
        holders > 0 && settingOn
    }

    static func retain() {
        holders += 1
        apply()
    }

    static func release() {
        // Floored rather than trusting balance: an unbalanced release would otherwise drive the count
        // negative and permanently defeat every later `retain`.
        holders = max(0, holders - 1)
        apply()
    }

    /// Re-assert after the setting changes, so toggling it in Settings takes effect on the practice
    /// screen behind without waiting for a re-appear.
    static func refresh() { apply() }

    private static func apply() {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled =
            shouldDisableIdleTimer(holders: holders, settingOn: AppSettings.keepScreenAwake)
        #endif
    }
}

/// One surface's claim on the screen staying awake — idempotent in both directions, so a double
/// `onAppear` (SwiftUI does re-fire it) can't inflate the count and a double teardown can't deflate it.
@MainActor
struct KeepAwakeClaim {
    private var held = false

    mutating func take() {
        guard !held else { return }
        held = true
        KeepAwakeLease.retain()
    }

    mutating func give() {
        guard held else { return }
        held = false
        KeepAwakeLease.release()
    }
}

private struct KeepAwakeModifier: ViewModifier {
    /// Read via `@AppStorage` so toggling the setting takes effect live rather than on next appear.
    @AppStorage(AppSettings.Key.keepScreenAwake) private var keepAwake = true
    @State private var claim = KeepAwakeClaim()

    func body(content: Content) -> some View {
        content
            .onAppear { claim.take() }
            // The claim is released, **not** the flag cleared: another practice surface may already be
            // on screen — the next block of a routine, or the host behind this one — and it keeps the
            // screen awake through its own claim. Clearing the flag here is the bug this file exists
            // to fix.
            .onDisappear { claim.give() }
            .onChange(of: keepAwake) { _, _ in KeepAwakeLease.refresh() }
    }
}

extension View {
    /// Hold the screen awake on this practice surface while `keepScreenAwake` is on.
    ///
    /// Safe to nest: a routine host and the block run screen inside it may both apply it, and the
    /// screen stays awake until the last of them leaves.
    func keepAwakeDuringPractice() -> some View { modifier(KeepAwakeModifier()) }
}
