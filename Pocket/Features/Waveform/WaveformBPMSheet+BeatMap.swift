import SwiftUI

// MARK: - The beat map in the tempo sheet (ADR 0281)

/// The way into **Tap through the song**, under the tap pad.
struct TapThroughLinkSection: View {
    let engine: PracticeAudioEngine
    let hooks: BeatMapHooks

    var body: some View {
        Section {
            NavigationLink {
                TapThroughView(engine: engine, hooks: hooks)
            } label: {
                Label("Tap through the song", systemImage: "hand.tap")
            }
        } footer: {
            Text("For a song whose tempo moves. Tap every beat, and the grid follows each one.")
        }
    }
}

/// What a song with a beat map follows, at the top of the tempo sheet, with the way back to one
/// tempo. Said here because a tempo set lower down replaces the map (ADR 0281 D4), and the sheet
/// shouldn't let that happen without having said so.
struct BeatMapSummarySection: View {
    let hooks: BeatMapHooks
    let onUseOneTempo: () -> Void

    var body: some View {
        Section {
            LabeledContent("Beats") {
                Text("\(hooks.beatTimes.count)").font(.pocketMono(.body))
            }
            if let range = BeatMap.tempoRange(hooks.beatTimes) {
                Text(rangeText(range))
                    .font(.futura(.subheadline))
            }
            Button("Use one tempo", action: onUseOneTempo)
        } header: {
            Text("The beats")
        } footer: {
            Text("This song's grid follows the beats you tapped. Setting a tempo below replaces "
                 + "them with one steady tempo.")
        }
    }

    private func rangeText(_ range: ClosedRange<Double>) -> String {
        let slowest = Int(range.lowerBound.rounded())
        let fastest = Int(range.upperBound.rounded())
        return slowest == fastest
            ? "The tempo holds at \(slowest) BPM."
            : "The tempo moves between \(slowest) and \(fastest) BPM."
    }
}

extension View {
    /// The tempo sheet (ADR 0024), presented from the song player. A modifier rather than inline
    /// in `WaveformPracticeView`, which is at its size budget, and because the beat-map hooks are
    /// all derived from the model: assembling them at the call site would be seven chances to pass
    /// the wrong one, the reason `carryTempoSheet(_:)` is a modifier too.
    func bpmSheet(_ model: WaveformPracticeModel) -> some View {
        @Bindable var model = model
        return sheet(isPresented: $model.settingBPM) {
            BPMSheet(engine: model.engine, currentBPM: model.song.tempoBPM,
                     currentDownbeat: model.song.downbeatSeconds,
                     currentBeatsPerBar: model.song.beatsPerBar,
                     currentNoteValue: model.song.noteValue,
                     beatMap: BeatMapHooks(
                        beatTimes: model.song.beatTimes,
                        hasDownbeat: model.song.downbeatSeconds != nil,
                        duration: model.duration,
                        onsets: { await model.onsetEnvelope() },
                        playFromStart: model.playWholeSongFromStart,
                        commit: { taps, onsets in model.commitBeatMap(taps: taps, onsets: onsets) },
                        useOneTempo: model.clearBeatMap),
                     click: TempoClickHooks(
                        wasOn: model.metronomeOn,
                        preview: { model.previewClick($0) },
                        end: { model.endClickPreview(keepOn: $0) }),
                     onCommit: { bpm, downbeat, beats, note in
                         model.commitTempo(bpm: bpm, downbeat: downbeat,
                                           beatsPerBar: beats, noteValue: note)
                     },
                     onSetOnWaveform: { bpm in
                         model.commitTempo(bpm: bpm, downbeat: nil)
                         model.beginSetDownbeat(resumeSheet: true)
                     },
                     onEstimate: { await model.estimateTempoFromAudio() })
        }
    }
}
