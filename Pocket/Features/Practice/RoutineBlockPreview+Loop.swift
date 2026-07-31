import SwiftData
import SwiftUI

/// The **loop** block previews (ADR 0071 R4b / ADR 0104 Slice 2) — the standard command-anchored
/// trainer preview and the ear-training one. Split out of `RoutineBlockPreview.swift` to keep each
/// file under the 400-line cap; the exercise preview stays there, and the shared pieces
/// (`PreviewTempoReadout` / `PreviewAudioButton`) stay with it.

/// A **read-only, pre-start preview** of a loop block (ADR 0071 R4b): its source song, the speed
/// anchors + staircase, and a short **audio audition of the loop's actual audio** (the looping region
/// at command speed) — the loop analogue of the exercise preview. Read-only; no engine setup, no run.
struct LoopBlockPreview: View {
    let loop: Loop
    /// Minutes a generated session allotted this block, or `nil` when hand-authored (ADR 0129).
    let plannedMinutes: Int?
    @State private var preview: LoopAudioPreviewPlayer

    init(loop: Loop, plannedMinutes: Int? = nil) {
        self.loop = loop
        self.plannedMinutes = plannedMinutes
        _preview = State(initialValue: LoopAudioPreviewPlayer(loop: loop))
    }

    /// The staircase this block will actually run — the loop's recipe, fitted to its allotted minutes
    /// by stretching the passes at command (ADR 0129 as amended), matching `LoopRunView.routine`.
    private var effectiveRamp: CommandRamp {
        guard let plannedMinutes else { return loop.ramp }
        return LoopEstimate.fitted(loop.ramp, toMinutes: plannedMinutes,
                                   regionSeconds: loop.regionSeconds)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if let song = loop.song {
                    VStack(spacing: 4) {
                        Text(song.title.isEmpty ? "Untitled song" : song.title)
                            .font(.futura(.title3, weight: .semibold))
                            .foregroundStyle(PocketColor.textPrimary)
                        if !song.artist.isEmpty {
                            Text(song.artist)
                                .font(.futura(.subheadline))
                                .foregroundStyle(PocketColor.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }

                PreviewTempoReadout(anchors: "\(effectiveRamp.working)% → \(effectiveRamp.command)%",
                                    reach: "\(effectiveRamp.target)%", unit: "of original")
                RoutineStairs(plateaus: effectiveRamp.plateaus, command: effectiveRamp.command,
                              tint: PocketColor.practice, unit: .percent)
                    .frame(height: 120)
                if preview.isUnavailable {
                    Text("Audio unavailable — the song file couldn't be found.")
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    PreviewAudioButton(isPlaying: preview.isPlaying,
                                       idleTitle: "Hear the loop") { preview.toggle() }
                }
            }
            .padding(24)
        }
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(loop.name.isEmpty ? "Loop" : loop.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { preview.stop() }
    }
}

/// The pre-start preview of an **ear-training** loop block (ADR 0104 Slice 2). Unlike `LoopBlockPreview`
/// there's no ramp/staircase — ear mode plays at a self-chosen tempo with no climb — so it shows the
/// loop + song, an "Ear training" label, and the same real-audio audition, so a player can confirm the
/// block before starting the routine.
struct EarLoopBlockPreview: View {
    let loop: Loop
    @State private var preview: LoopAudioPreviewPlayer

    init(loop: Loop) {
        self.loop = loop
        _preview = State(initialValue: LoopAudioPreviewPlayer(loop: loop))
    }

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

                Label("Ear training — hum or sing it back", systemImage: "ear")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.journal)

                if preview.isUnavailable {
                    Text("Audio unavailable — the song file couldn't be found.")
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    PreviewAudioButton(isPlaying: preview.isPlaying,
                                       idleTitle: "Hear the loop") { preview.toggle() }
                }
            }
            .padding(24)
        }
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(loop.name.isEmpty ? "Ear training" : loop.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { preview.stop() }
    }
}
