import SwiftUI

/// First-launch **content seeding**, split out of `HomeView` so that view stays within SwiftLint's
/// file/type-length caps — the same reason `HomeView+ProfileMoment` exists.
extension HomeView {
    /// Seed the curated first-run content once, ever (ADR 0046/0112). The app root is the right
    /// place, and each seeder's own `UserDefaults` guard makes this idempotent, so it is safe to run
    /// on every launch and no-ops after the first.
    ///
    /// Routines seed **after** exercises (ADR 0071) so their by-name blocks resolve against the
    /// just-seeded drills, and the demo song comes last (it decodes off-main). The `Task.yield()`
    /// between steps lets each surface paint: chaining them synchronously delays first render on a
    /// cold install — the "freeze" that once looked like a regression was this.
    func seedFirstRunContent() async {
        PracticePresets.seedIfNeeded(into: context)
        // Stamp provenance onto drills seeded before the slug existed, so the free-taste
        // run allowance recognises them (ADR 0112). Both backfills run once, then no-op.
        PracticePresets.backfillPresetSlugsIfNeeded(into: context)
        // Move the retired click subdivision into `notesPerBeat` and bind every measured
        // command to its rhythm (ADR 0121), so no later read branches on provenance.
        ExerciseNoteRateBackfill.runIfNeeded(into: context)
        await Task.yield()
        RoutinePresets.seedIfNeeded(into: context)
        await Task.yield()
        RoutinePresets.backfillPresetSlugsIfNeeded(into: context)
        await SongPresets.seedIfNeeded(into: context)
        #if DEBUG
        ScreenshotSeed.seedIfNeeded(into: context)
        #endif
        seedingComplete = true
    }

    /// The readiness signal the UI tests wait on (ADR 0146 pass 2).
    ///
    /// Home paints *before* `seedFirstRunContent()` finishes — that gap is the whole reason the tests
    /// used to guess with 20-second timeouts — so this publishes the later moment, when the seeded
    /// content actually exists. A 1×1 transparent element; `.accessibilityElement()` is what puts it
    /// in the tree at all, since a bare `Color` is not one, and without it the identifier would
    /// attach to nothing and every test would wait out the full timeout before failing.
    ///
    /// Only under `-uiTesting`: an invisible element is dead weight for a player using VoiceOver, and
    /// this earns its place only in a test run.
    @ViewBuilder
    var seedingMarker: some View {
        if UITestRuntime.isActive && seedingComplete {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier(UITestHooks.homeSeedingComplete)
        }
    }
}
