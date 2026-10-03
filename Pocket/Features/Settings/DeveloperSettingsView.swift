#if DEBUG
import SwiftData
import SwiftUI

/// **Settings ▸ Developer** — DEBUG-only scaffolding, gathered behind one row (ADR 0162 D8).
///
/// The whole file is inside `#if DEBUG`, so none of this exists in a shipping build. Gathering it
/// here is not only tidiness: on the flat screen these sections were a meaningful share of both
/// the scroll and `SettingsView`'s line count, and none of them belong in a player's field of view
/// even in a TestFlight build.
struct DeveloperSettingsView: View {
    @Environment(\.modelContext) private var context

    /// Re-arms the one-time "you've earned a name" prompt without a data-wiping reinstall.
    @AppStorage(AppSettings.Key.artistNamePromptSeen) private var artistNamePromptSeen = false
    /// Re-arms the first-launch curation intake (ADR 0113 S2).
    @AppStorage(AppSettings.Key.artistIntakeSeen) private var artistIntakeSeen = false
    /// Read on appear and after a reset — nothing observes the record, so nothing else would redraw it.
    @State private var reviewAsk: ReviewPrompt.DebugState?
    @AppStorage(AppSettings.Key.gestureHints) private var gestureHints = AppSettings.gestureHintsDefault
    @AppStorage(AppSettings.Key.gestureHintsRetired) private var gestureHintsRetired = ""

    var body: some View {
        Form {
            // A/B the stretcher-latency correction (ADR 0140 §3).
            DebugAudioSection()

            Section {
                Button("Reset naming prompt", role: .destructive, action: resetNamingPrompt)
                Button("Reset first-launch intake", role: .destructive, action: resetIntake)
            } header: {
                Text("First-run flows")
            } footer: {
                Text("Clears your artist name and re-arms the “you've earned a name” prompt; the "
                     + "second row re-arms the first-launch curation intake.")
            }

            reviewAskSection
            holdTipsSection
        }
        .settingsScreen(title: "Developer")
        .onAppear(perform: refreshReviewAsk)
    }

    /// The review ask's state (ADR 0214), because on a device there is no other way to see it: the
    /// system call returns nothing, and a development build draws the dialog every time it is asked.
    private var reviewAskSection: some View {
        Section {
            LabeledContent("Sittings",
                           value: "\(reviewAsk?.sittings ?? 0) of \(ReviewPromptPlan.sittingsBeforeAsking)")
            LabeledContent("Last ask", value: lastAskText)
            LabeledContent("Next Home return", value: outcomeText)
            Button("Reset review ask", role: .destructive, action: resetReviewAsk)
        } header: {
            Text("Review ask")
        } footer: {
            Text("Never on the launch appearance: open any screen and come back to Home. Reset "
                 + "forgets our record only — iOS keeps its own budget on top of ours, so a "
                 + "TestFlight or App Store build may still show nothing.")
        }
    }

    /// The hold tips' state (ADR 0244), none of which a player can see: which tips are put away, which
    /// one this opening has used, and what is holding them back. *Start a new opening* is the
    /// app's own `begin()`, the one a half-hour away calls, so a test here takes the real path.
    private var holdTipsSection: some View {
        let opening = GestureHintOpening.current
        let retired = GestureHintPolicy.retired(gestureHintsRetired)
        return Section {
            LabeledContent("Held back by", value: holdTipsHeldBack(opening: opening, retired: retired))
            ForEach(GestureHint.allCases) { hint in
                LabeledContent(Self.name(of: hint), value: holdTipState(hint, opening: opening, retired: retired))
            }
            Button("Start a new opening") { opening.begin() }
            Button("Reset hold tips", role: .destructive) {
                AppSettings.resetGestureHints()
                opening.begin()
            }
        } header: {
            Text("Hold tips")
        } footer: {
            Text("An opening is a launch, or a return after \(Int(GestureHintPolicy.openingGap / 60)) "
                 + "minutes or more in the background. Start a new opening does what that break does. "
                 + "Reset also brings every tip back and turns the switch on.")
        }
    }

    private func holdTipsHeldBack(opening: GestureHintOpening, retired: Set<GestureHint>) -> String {
        if !UITestRuntime.gestureHintsAreOpen { return "A UI test without -gestureHints" }
        if !gestureHints { return "Switched off" }
        if GestureHintOpening.walkthroughOutstanding { return "The guide, on the next song" }
        if opening.walkthroughSeen { return "The guide ran this opening" }
        if retired.count == GestureHint.allCases.count { return "All put away" }
        return "Nothing"
    }

    /// "Next opening": this opening has shown its one tip, and this one waits for the next.
    private func holdTipState(_ hint: GestureHint, opening: GestureHintOpening, retired: Set<GestureHint>) -> String {
        if retired.contains(hint) { return "Put away" }
        if opening.shown == hint { return "This opening's tip" }
        return opening.shown == nil ? "Can show" : "Next opening"
    }

    private static func name(of hint: GestureHint) -> String {
        switch hint {
        case .loopRow: "Loop row"
        case .metronome: "Metronome"
        case .bpm: "BPM"
        case .markerRow: "Marker row"
        case .panelHeader: "Panel name"
        case .songTitle: "Song name"
        }
    }

    private var lastAskText: String {
        guard let ask = reviewAsk?.lastAsk else { return "Never" }
        return "\(ask.askedAt.formatted(date: .abbreviated, time: .shortened)) · \(ask.version)"
    }

    private var outcomeText: String {
        switch reviewAsk?.outcome {
        case nil: "—"
        case .ask: "Would ask"
        case .hold(.screenNotSettled): "Holds: screen busy"
        case .hold(.askedUnderThisVersion): "Holds: asked under \(ReviewPrompt.currentVersion)"
        case .hold(.askedTooRecently):
            "Holds: asked < \(Int(ReviewPromptPlan.minimumGapBetweenAsks / 86_400)) days ago"
        case .hold(.tooFewSittings): "Holds: too few sittings"
        }
    }

    /// Clear the artist name and re-arm the one-time naming prompt, so the "you've earned a name"
    /// ceremony can be exercised again on a real install (no reinstall / data loss).
    private func resetNamingPrompt() {
        Profile.setArtistName(nil, in: context)
        artistNamePromptSeen = false
    }

    /// Re-arm the one-time first-launch curation intake. Leaves the stored curation in place (it stays
    /// visible/editable under "You"); this only flips the "seen" gate so Home offers the flow again.
    private func resetIntake() {
        artistIntakeSeen = false
    }

    /// Forget that the app has asked for a review, so the ladder's last rung can be exercised again
    /// (ADR 0214). This clears **our** record only — iOS's own three-per-year budget is invisible to
    /// the process and unaffected, so the system dialog may still show nothing after this. That is
    /// the feature's central fact, not a bug in this button.
    private func resetReviewAsk() {
        ReviewPrompt.resetForTesting()
        refreshReviewAsk()
    }

    /// Every sitting, not Home's short-circuited count: Home stops counting once a fetch says there
    /// are too few runs to matter, and a readout that said "0" there would be a lie about the log.
    private func refreshReviewAsk() {
        let runs = (try? context.fetch(FetchDescriptor<PracticeRun>())) ?? []
        reviewAsk = ReviewPrompt.debugState(sittingCount: PracticeLog.sittings(runs.map(\.record)).count)
    }
}

#Preview {
    NavigationStack { DeveloperSettingsView() }
        .modelContainer(for: [Profile.self, PracticeRun.self], inMemory: true)
}
#endif
