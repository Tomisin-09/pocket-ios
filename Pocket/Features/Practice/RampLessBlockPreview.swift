import SwiftData
import SwiftUI

/// The **pre-start preview for a block with no ramp** — ear training (ADR 0104) and improvising over
/// a backing track (ADR 0135). One screen for both: they differ in a line of copy and a glyph, which
/// `LoopRunMode` already carries.
///
/// There is no staircase to draw and no tempo to fit, so where an exercise or loop-trainer preview
/// shows a ramp this shows the two things that *are* decidable before you start: what you'll hear
/// (a short audition) and **how long the block runs** (ADR 0141).
struct RampLessBlockPreview: View {
    let loop: Loop
    let mode: LoopRunMode
    /// The block being previewed, for its length. `nil` outside a routine, where there is no block
    /// and therefore no length to state.
    var block: RoutineItem?
    /// A binding onto the block's open-ended opt-out (`RoutineItem.usesAuthoredLength`, ADR 0130
    /// reused per ADR 0141 L4), carrying the editor's save discipline with it.
    var runsOpenEnded: Binding<Bool>?
    /// A binding onto the block's **record** flag (`RoutineItem.recordsTake`, ADR 0180 D1). `nil`
    /// outside a routine, where there is no block to mark.
    var recordsTake: Binding<Bool>?

    @State private var preview: LoopAudioPreviewPlayer

    init(loop: Loop, mode: LoopRunMode, block: RoutineItem? = nil,
         runsOpenEnded: Binding<Bool>? = nil, recordsTake: Binding<Bool>? = nil) {
        self.loop = loop
        self.mode = mode
        self.block = block
        self.runsOpenEnded = runsOpenEnded
        self.recordsTake = recordsTake
        _preview = State(initialValue: LoopAudioPreviewPlayer(loop: loop))
    }

    /// The one-line description of what this block is — the mode's job, in the player's words.
    private var blurb: String {
        switch mode {
        case .ear: "Ear training — hum or sing it back"
        case .improvise: "Improvise — this section on repeat, as a bed to play over"
        case .trainer: "Loop trainer"   // never previewed here; the trainer has its own screen
        }
    }

    private var tint: Color { mode == .ear ? PocketColor.journal : PocketColor.practice }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 4) {
                    Text(loop.name.isEmpty ? "Untitled loop" : loop.name)
                        .font(.futura(.title3, weight: .semibold))
                        .foregroundStyle(PocketColor.textPrimary)
                    if let song = loop.song {
                        Text(song.artist.isEmpty ? "from \(song.title)"
                                                 : "from \(song.title) · \(song.artist)")
                            .font(.futura(.subheadline))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                Label(blurb, systemImage: mode.symbolName)
                    .font(.futura(.footnote))
                    .foregroundStyle(tint)
                    .multilineTextAlignment(.center)

                if preview.isUnavailable {
                    Text("Audio unavailable — the song file couldn't be found.")
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    PreviewAudioButton(isPlaying: preview.isPlaying,
                                       idleTitle: "Hear the loop") { preview.toggle() }
                }

                if let block, let runsOpenEnded {
                    RampLessBlockLengthControl(runsOpenEnded: runsOpenEnded,
                                               minutes: block.resolvedBlockMinutes, tint: tint)
                }
                // Ear and improvise blocks can already be armed from their own screens; this is the
                // same behaviour decided in advance (ADR 0180 D1), so the same switch as every other
                // block gets. `openEnded` softens the copy: a jam ends when you end it, so "ends with
                // the block" would be a promise about a clock that isn't running.
                if let recordsTake {
                    BlockRecordControl(recordsTake: recordsTake, tint: tint,
                                       kind: .rampLess(openEnded: block?.usesAuthoredLength == true))
                }
            }
            .padding(24)
        }
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(loop.name.isEmpty ? mode.label : loop.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { preview.stop() }
    }
}

/// **How long this ramp-less block runs, and the way out of it** (ADR 0141 L4).
///
/// The sibling of `BlockLengthControl`, and deliberately *not* the same control. That one discloses a
/// difference between two real lengths — the session's fit and the unit's authored recipe — and lets
/// you keep yours. A ramp-less block has no authored recipe to keep: the choice here is between a
/// length and **no length at all**, so the toggle says that instead of borrowing copy about a
/// staircase that doesn't exist.
struct RampLessBlockLengthControl: View {
    @Binding var runsOpenEnded: Bool
    /// The block's resolved length, or `nil` when it is already running open-ended.
    let minutes: Int?
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { runsOpenEnded },
                                 set: { runsOpenEnded = $0; haptic(.light) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("No time limit")
                        .font(.futura(.subheadline)).foregroundStyle(PocketColor.textPrimary)
                    Text("run this block until you end it yourself")
                        .font(.futura(.caption2)).foregroundStyle(PocketColor.textSecondary)
                }
            }
            .tint(tint)
            .accessibilityHint("Run this block with no planned length")

            Text(minutes.map {
                "Runs ~\($0) min in this session, then moves on at the end of a loop — "
                + "you can finish sooner with Done."
            } ?? "Runs until you tap Done. The session's length won't count it.")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(PocketColor.textSecondary.opacity(0.08)))
    }
}
