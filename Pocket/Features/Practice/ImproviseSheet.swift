import SwiftData
import SwiftUI

/// The reusable **improvise core** for a loop (ADR 0135) — the loop's own audio as a **backing
/// track**, cycling continuously at one live-adjustable tempo, with Journal capture for what came
/// out of the jam. Rendered as a `Form` with no navigation chrome of its own, so it drops into two
/// hosts exactly as `EarTrainingView` does: the standalone `ImproviseSheet` (from the loop settings
/// sheet) and — once ADR 0135 Slice 2 lands — `ImproviseLoopRunView`, an improvise block inside a
/// routine.
///
/// A section of the player's own song, looping with no vocal over it, *is* a backing track. Every
/// mechanism this needs already shipped: the region loops gaplessly (`PracticeAudioEngine` folds a
/// 15 ms equal-power crossfade into the seam), the rate is adjustable live in percent-of-original,
/// and notes capture to the Journal — tagged 🎸 `.improvise` here.
///
/// **No ramp and no rep clock** (B3). This follows a song block's rule, not the loop trainer's: it is
/// an open jam and the app never tells you to stop playing (ADR 0014 R1). **Nothing listens** (B5) —
/// no analysis, no verdict on what was played over it, the same posture ear training holds and for
/// the same reason (ADR 0070 / 0094). Recording a take is the player's own capture, not the app
/// forming an opinion: B5 stands.
///
/// **Takes are on** (ADR 0069 amendment). A jam has no ramp and no logged tempo, so the take *is* the
/// record of what came out — which is why the routine gate the ramped run screens keep is lifted for
/// an improvise block. The play button is a real Start, so the ordinary arm-then-Start grammar drops
/// straight in with no new transport.
struct ImproviseView: View {
    let loop: Loop
    /// Owned by the **host** (ADR 0141) — see `EarTrainingView`. Build it with
    /// `ContinuousLoopPlayer.improvising(over:)` so both hosts seed the tempo the same way.
    let player: ContinuousLoopPlayer
    /// Also owned by the host, for the same reason the player is: this view has three of them, and a
    /// controller declared here would be one per host with none of them in charge of the lifecycle.
    let recorder: RecordingController
    @Environment(\.modelContext) private var modelContext
    /// Latch for the tool-opened event (ADR 0120) — `.onAppear` re-fires on a return from a
    /// pushed screen, and this view has two hosts.
    @State private var reportedOpen = false
    @State private var showingTakes = false

    var body: some View {
        KeyboardFollowingScroll {
            Form {
                Section { LoopModeIdentityHeader(loop: loop) }
                introSection
                Section {
                    ContinuousLoopControls(player: player,
                                           playingStatus: "Looping — play over it",
                                           idleStatus: "Tap to start the backing track",
                                           recorder: recorder,
                                           onStopped: finishTake,
                                           takeCount: loop.recordings.count,
                                           onOpenTakes: openTakes)
                }
                JournalNoteComposer(owner: .loop(loop), kind: .improvise,
                                    header: "Note what you played",
                                    placeholder: "What came out? "
                                        + "(e.g. the b5 works over the turnaround)")
            }
        }
        .onAppear {
            guard !reportedOpen else { return }
            reportedOpen = true
            Analytics.send(.toolOpened(tool: .improvise))
        }
        .onDisappear {
            finishTake()     // before the bed stops — see `ContinuousLoopControls`' stop branch
            player.stop()
        }
        .sheet(isPresented: $showingTakes) {
            TakesSheet(owner: .loop(loop), onDelete: deleteTake)
        }
        // On the shared core, so all three hosts get it once (ADR 0050) — a jam is the longest a
        // player goes without touching the screen, and this one had never asked.
        .keepAwakeDuringPractice()
    }

    /// Finalize an in-flight take against *this loop* when the bed stops or the screen exits, so a
    /// take is never left recording after the audio it was played over has stopped. Idempotent — the
    /// two seams overlap on purpose (stopping the bed, then leaving).
    private func finishTake() {
        recorder.finishIfRecording(owner: .loop(loop), context: modelContext)
    }

    /// Relisten, without leaving the jam. **Stops the bed first**: the takes sheet has its own player,
    /// and a take under the backing track it was played over is two things at once and neither of them
    /// audible. Finalising first keeps the ordering rule the stop branch states.
    private func openTakes() {
        finishTake()
        player.stop()
        showingTakes = true
    }

    private func deleteTake(_ take: Recording) {
        try? RecordingStore.delete(fileName: take.fileName)
        modelContext.delete(take)
        try? modelContext.save()
    }

    // MARK: - Intro (jam over it — no target, no verdict)

    private var introSection: some View {
        Section {
            Text("This section on repeat, as a bed to play over. Solo, comp, try an idea and keep "
                + "the ones that stick — there's no target tempo and nothing to finish. Nothing is "
                + "listening; note anything worth keeping below.")
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
        }
    }
}

/// The **standalone** improvise host — presented from the loop settings sheet (ADR 0135 B2). Wraps
/// `ImproviseView` in a navigation container with a Done button.
///
/// Reached from **every** loop's settings sheet, flagged or not: the flag governs *resurfacing* — the
/// library shelf and the per-row button — not permission to jam over a section you're already
/// looking at (B2/B4).
struct ImproviseSheet: View {
    let loop: Loop
    @Environment(\.dismiss) private var dismiss
    @State private var player: ContinuousLoopPlayer
    @State private var recorder = RecordingController()

    init(loop: Loop) {
        self.loop = loop
        _player = State(initialValue: .improvising(over: loop))
    }

    var body: some View {
        NavigationStack {
            ImproviseView(loop: loop, player: player, recorder: recorder)
                .navigationTitle("Improvise")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .presentationDetents([.large])
    }
}

/// The **pushed** improvise host — what the Loops library navigates to from a flagged row's Improv
/// button (ADR 0135 B8a). The sheet's twin, without the modal chrome.
struct ImproviseScreen: View {
    let loop: Loop
    @State private var player: ContinuousLoopPlayer
    @State private var recorder = RecordingController()

    init(loop: Loop) {
        self.loop = loop
        _player = State(initialValue: .improvising(over: loop))
    }

    var body: some View {
        ImproviseView(loop: loop, player: player, recorder: recorder)
            .navigationTitle(LoopRunMode.improvise.label)
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Improvise") {
    let song = Song.sample()
    let loop = Loop(name: "Outro vamp", start: 0.72, end: 0.88, speed: 1.0, repeats: 4)
    loop.song = song
    loop.loopType = .chords
    loop.isBackingTrack = true
    return ImproviseSheet(loop: loop).preferredColorScheme(.dark)
}
