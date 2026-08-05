import SwiftData
import SwiftUI

/// The reusable **ear-training core** for a loop (ADR 0104) — the identity header, the continuous
/// play control, the live tempo adjuster, and Journal note capture. Rendered as a `Form` with no
/// navigation chrome of its own, so it drops into two hosts: the standalone `EarTrainingSheet`
/// (from the loop settings sheet) and `EarLoopRunView` (an ear-training block inside a routine).
///
/// Ear training as "the loops, re-surfaced": an away-from-the-guitar exercise — the loop's own audio
/// cycles continuously so the player can **hum or sing it back** and listen again to compare. No
/// stored answer, no verdict (ADR 0070/0094 T2b): the app plays, nothing listens, the player is the
/// judge. Notes save straight to the loop's **Journal** (ADR 0100/0058) tagged 👂 `.ear`.
///
/// The three structural sections live in `LoopModeSections`, shared with `ImproviseView` (ADR 0135),
/// the sibling ramp-less mode: only the copy and the note's `EntryKind` differ between them.
struct EarTrainingView: View {
    let loop: Loop
    /// Owned by the **host**, not by this view (ADR 0141): a routine block has to read what the audio
    /// is doing to end on a region boundary rather than mid-phrase, and it can't reach a `@State`
    /// declared here. The standalone sheet holds one just the same, so the two hosts stay symmetric.
    let player: ContinuousLoopPlayer
    /// Latch for the tool-opened event (ADR 0120) — this view is embedded by both the loop-settings
    /// sheet and a routine's ear block, and `.onAppear` re-fires on a return.
    @State private var reportedOpen = false

    var body: some View {
        KeyboardFollowingScroll {
            Form {
                Section { LoopModeIdentityHeader(loop: loop) }
                introSection
                Section {
                    ContinuousLoopControls(player: player,
                                           playingStatus: "Looping — hum or sing along")
                }
                LoopModeNoteSection(loop: loop, kind: .ear,
                                    header: "Note what you hear",
                                    placeholder: "What did you hear? "
                                        + "(e.g. starts on the b3, descending run)")
            }
        }
        .onAppear {
            guard !reportedOpen else { return }
            reportedOpen = true
            Analytics.send(.toolOpened(tool: .earTraining))
        }
        .onDisappear { player.stop() }
    }

    // MARK: - Intro (hum / sing, away from the guitar)

    private var introSection: some View {
        Section {
            Text("Listen it into your ear, then hum or sing it back — no guitar needed. Play the loop "
                + "again and compare. No score, no right answer. Jot what you hear below.")
                .font(.futura(.footnote))
                .foregroundStyle(PocketColor.textSecondary)
        }
    }
}

/// The **standalone** ear-training host — presented from the loop settings sheet (ADR 0104). Wraps
/// `EarTrainingView` in a navigation container with a Done button; the routine block uses
/// `EarLoopRunView` instead.
struct EarTrainingSheet: View {
    let loop: Loop
    @Environment(\.dismiss) private var dismiss
    @State private var player: ContinuousLoopPlayer

    init(loop: Loop) {
        self.loop = loop
        _player = State(initialValue: ContinuousLoopPlayer(loop: loop))
    }

    var body: some View {
        NavigationStack {
            EarTrainingView(loop: loop, player: player)
                .navigationTitle("Train your ear")
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

/// The **pushed** ear-training host — what the Loops library navigates to (ADR 0138 G4). Same core
/// view, same owned player; it differs from `EarTrainingSheet` only in having no modal chrome, since
/// a pushed screen already has a back button.
struct EarTrainingScreen: View {
    let loop: Loop
    @State private var player: ContinuousLoopPlayer

    init(loop: Loop) {
        self.loop = loop
        _player = State(initialValue: ContinuousLoopPlayer(loop: loop))
    }

    var body: some View {
        EarTrainingView(loop: loop, player: player)
            .navigationTitle(LoopRunMode.ear.label)
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Train your ear") {
    let song = Song.sample()
    let loop = Loop(name: "Verse riff", start: 0.2, end: 0.35, speed: 0.85, repeats: 4)
    loop.song = song
    loop.loopType = .lick
    loop.commandTempo = 0.85
    loop.tags = ["solo", "bends"]
    return EarTrainingSheet(loop: loop).preferredColorScheme(.dark)
}
