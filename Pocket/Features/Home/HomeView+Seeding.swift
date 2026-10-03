import SwiftUI

/// First-launch **content seeding**, split out of `HomeView` so that view stays within SwiftLint's
/// file/type-length caps — the same reason `HomeView+ProfileMoment` exists.
extension HomeView {
    /// Seed the curated first-run content once, ever (ADR 0046/0112). The app root is the right
    /// place, and each seeder's own `UserDefaults` guard makes this idempotent, so it is safe to run
    /// on every launch and no-ops after the first.
    ///
    /// Routines seed **after** exercises (ADR 0071) so their by-name blocks resolve against the
    /// just-seeded drills. The `Task.yield()` between steps lets each surface paint: chaining them
    /// synchronously delays first render on a cold install — the "freeze" that once looked like a
    /// regression was this.
    ///
    /// **No song is seeded** (ADR 0148). A demo track shipped as a bundled file was the app's only
    /// third-party content — an App Store content-rights declaration, a licence to keep straight,
    /// and 2.6 MB in every download — to hand every player the same song none of them chose. The
    /// library starts empty and fills with music they actually practise.
    func seedFirstRunContent() async {
        // On the launch the intake shows, what the first run seeds is the intake's to decide (ADR 0248),
        // so the drills and the routine wait for its cover to close (`seedAfterIntake`). Every other
        // launch is as before: the seeders' own keys make them no-ops once they've run.
        let waitForTheIntake = !artistIntakeSeen && !UITestRuntime.isActive
        if !waitForTheIntake { PracticePresets.seedIfNeeded(into: context) }
        // Stamp provenance onto drills seeded before the slug existed (ADR 0112). Both
        // backfills run once, then no-op.
        PracticePresets.backfillPresetSlugsIfNeeded(into: context)
        // Move the retired click subdivision into `notesPerBeat` and bind every measured
        // command to its rhythm (ADR 0121), so no later read branches on provenance.
        ExerciseNoteRateBackfill.runIfNeeded(into: context)
        // Date every piece saved before the Journal listed pieces (ADR 0229). Every launch: a piece
        // restored from an older archive arrives undated too. Writes only to an undated piece.
        PieceDateBackfill.run(into: context)
        await Task.yield()
        if !waitForTheIntake { RoutinePresets.seedIfNeeded(into: context) }
        await Task.yield()
        RoutinePresets.backfillPresetSlugsIfNeeded(into: context)
        #if DEBUG
        ScreenshotSeed.seedIfNeeded(into: context)
        // Strictly after the library seed: the seeded journal and take hang off the loops and
        // exercises it creates, and an entry with no owner renders as a different thing (ADR 0143).
        PracticeHistorySeed.seedIfNeeded(into: context)
        // Put in or taken out on every UI-test launch, so the store the next test finds is known.
        NamingPieceSeed.apply(to: context)
        ReceivedPackSeed.removeLeftovers(from: context)
        #endif
        seedingComplete = true
    }

    /// The intake's cover has closed: seed the first run from what it learned (ADR 0248). Someone who
    /// plays guitar or bass, or skipped the question, gets the drills and Morning Routine as every install
    /// did; anyone else starts with an empty Practice library and fills it from the loops they save.
    /// Read from the store rather than `profiles`, which the `@Query` may not have caught up with yet.
    func seedAfterIntake() {
        let leansOnSongs = Profile.existing(in: context)?.plays?.leansOnSongs == true
        PracticePresets.seedFirstRun(leansOnSongs: leansOnSongs, into: context)
        RoutinePresets.seedIfNeeded(into: context)
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
