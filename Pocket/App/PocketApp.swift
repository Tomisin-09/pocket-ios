import SwiftData
import SwiftUI

@main
struct PocketApp: App {
    // Drives per-screen orientation (ADR 0042) — see OrientationGate.swift.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    // Appearance override (ADR 0062 follow-up) — read at the root so the whole app
    // repaints when it changes, rather than each screen consulting it separately.
    @AppStorage(AppSettings.Key.appearance) private var appearance = AppearancePreference.system

    // MetricKit's crash and hang reports (ADR 0183) — read by the Diagnostics screen and, only when
    // the player has opted in, by the support sheet. Owned **here** and nowhere else, because
    // `MXMetricManager` holds its subscribers weakly: a recorder created further down the tree is
    // dropped by the OS the moment that view goes away, silently and with nothing to notice.
    @State private var diagnostics = DiagnosticsRecorder()

    // Per-routine practice reminders (ADR 0186 D4) — owns the pending requests and the stored
    // schedules. Lives here for the app's lifetime, and is read from the environment by the routine
    // screen's reminder row and by Settings ▸ Practice. Its launch sweep (D3) runs from `HomeView`,
    // which is where a `ModelContext` to resolve routines against is; the same sweep clears the
    // retired trial reminder (ADR 0237 D5).
    @State private var practiceReminder = PracticeReminder()

    // The hold tips count openings of the app, not launches (ADR 0244 D5): iOS keeps a suspended app
    // for days, and a return after half an hour away is the player opening it again.
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // The Journal's list filters persist (ADR 0190 D8), and a simulator keeps its `UserDefaults`
        // between runs — so a driven test starts from whatever the last one left behind unless the
        // state is cleared here. See `AppSettings.resetJournalFilters` for the figure it silently
        // corrupted.
        if UITestRuntime.isActive {
            AppSettings.resetJournalFilters()
            // Home's resume-card preference is the same trap on the app's front door (ADR 0193): a
            // test that pins the card to *Routine* leaves it pinned for the next test and the next
            // run, and `reference/home` is shot through that card.
            AppSettings.resetJumpBackInPreference()
            // The tile beside Toolkit is the same trap (ADR 0235 D6): a test that changes it would change
            // it for every test after, and for Home's figures.
            AppSettings.resetHomeTool()
            // The Oracle's cadence is the same trap with a longer fuse (ADR 0187 D15). Its gate is
            // driven by a stored date, so the *second* run of a suite finds the week already spent
            // and the screen showing a persisted reading instead of the button. A test written
            // against that lands on whichever side the last run left — the failure this block
            // exists to stop, and one that reads as a broken gate rather than a dirty simulator.
            OracleReadingLog().clear()
            // The walkthrough's ledger is the same trap again (ADR 0149): a second run finds it
            // spent. Only the test that asks for it gets it back — see `walkthroughArgument`.
            if UITestRuntime.walkthroughIsOpen { AppSettings.resetSongWalkthroughForUITest() }
            // And the hold tips' (ADR 0244): the first run retires the tag it shows.
            if UITestRuntime.gestureHintsAreOpen { AppSettings.resetGestureHints() }
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                // The inbound door for shared routines (ADR 0188 S2) — `.onOpenURL` plus the one
                // preview sheet both doors present. Tap-to-open can arrive on a cold launch with no
                // screen of the app's own on top, which is why it lives at the root at all.
                .practiceReceiveHost()
                .environment(diagnostics)
                .environment(practiceReminder)
                .preferredColorScheme(appearance.colorScheme)
        }
        .modelContainer(for: [Song.self, Loop.self, Marker.self, JournalEntry.self,
                              Exercise.self, Routine.self, RoutineItem.self, Goal.self,
                              LongTermGoal.self, Recording.self, TakeNote.self, SavedChord.self, Profile.self,
                              PracticeRun.self, ReferenceLink.self, LoopSpanChange.self,
                              Snag.self, PracticeFolder.self, CustomSkill.self, SavedProgression.self,
                              WrittenTab.self])
        .onChange(of: scenePhase) { _, phase in GestureHintOpening.current.sceneChanged(to: phase) }
    }
}
