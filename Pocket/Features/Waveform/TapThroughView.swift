import SwiftUI

/// What the tempo sheet needs from the song player to tap through a song and to show a beat map
/// (ADR 0281). Built by `bpmSheet(_:)` from the model, so the sheet never holds the model itself.
struct BeatMapHooks {
    /// The song's beat map, empty when it has none.
    let beatTimes: [TimeInterval]
    /// Whether the song has a 1. Without one, the first tap becomes it.
    let hasDownbeat: Bool
    let duration: TimeInterval
    /// The song's onset envelope, for snapping taps onto hits. Slow (it decodes the file), so the
    /// tap-through screen asks for it as it opens.
    let onsets: () async -> BeatMap.Onsets?
    /// Play the whole song from the top, letting go of an armed loop.
    let playFromStart: () -> Void
    /// Store the taps as the song's beats. `false` when they don't make a map.
    let commit: ([TimeInterval], BeatMap.Onsets?) -> Bool
    /// Drop the map and keep its median as the song's one tempo.
    let useOneTempo: () -> Void
}

/// **Tap through the song** (ADR 0281): play it from the top and tap every beat, and each tap
/// becomes a beat in the song's beat map. The way to give a song that speeds up and slows down a
/// grid that follows it, until Red Moon can find the beats itself (B3).
///
/// Pushed from the tempo sheet's Tap mode. Taps read the playhead, as the sheet's own tap pad does,
/// so a slowed speed still maps the song's real timing.
struct TapThroughView: View {
    let engine: PracticeAudioEngine
    let hooks: BeatMapHooks

    @State private var taps: [TimeInterval] = []
    /// The onset envelope, started as the screen opens so it's usually ready by the time the
    /// player is.
    @State private var onsets: Task<BeatMap.Onsets?, Never>?
    @State private var isSaving = false
    @State private var didNotMap = false

    var body: some View {
        Form {
            Section {
                VStack(spacing: 14) {
                    readout
                    pad
                    TapThroughProgress(engine: engine, duration: hooks.duration)
                    controls
                }
                .padding(.vertical, 4)
            } footer: {
                Text(footer)
            }
            if didNotMap {
                Label("Those taps don't make a beat map yet. Tap at least \(BeatMap.minBeats) beats.",
                      systemImage: "exclamationmark.triangle")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
        .navigationTitle("Tap through the song")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { save() }
                    .disabled(taps.count < BeatMap.minBeats || isSaving)
            }
        }
        .task {
            guard onsets == nil else { return }
            let load = hooks.onsets
            onsets = Task { await load() }
        }
    }

    private var footer: String {
        let start = hooks.hasDownbeat
            ? "Tap every beat to the end of the song. Your 1 stays where it is."
            : "Start on a 1 and tap every beat to the end of the song."
        return start + " Each tap becomes a beat, so the grid follows the band when it speeds up or "
            + "slows down. A tap near a clear hit moves onto it, and a beat you miss is filled in."
    }

    private var readout: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(spacing: 0) {
                Text("\(taps.count)")
                    .font(.pocketMono(.largeTitle))
                    .foregroundStyle(PocketColor.textPrimary)
                    .contentTransition(.numericText())
                Text("Beats")
                    .font(.futura(.caption2))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
            VStack(spacing: 0) {
                Text(TempoMath.bpm(fromTapTimes: taps).map { String(Int($0.rounded())) } ?? "—")
                    .font(.pocketMono(.largeTitle))
                    .foregroundStyle(PocketColor.textPrimary)
                    .contentTransition(.numericText())
                Text("BPM here")
                    .font(.futura(.caption2))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
    }

    private var pad: some View {
        Button { tap() } label: {
            Text(engine.isPlaying ? "Tap" : "Play to start tapping")
                .font(engine.isPlaying ? .pocketMono(.title2) : .futura(.headline))
                .foregroundStyle(PocketColor.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(RoundedRectangle(cornerRadius: 16)
                    .fill(PocketColor.active.opacity(engine.isPlaying ? 0.18 : 0.08)))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(PocketColor.active.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!engine.isPlaying)
        .accessibilityLabel("Tap each beat")
    }

    private var controls: some View {
        HStack {
            Button { engine.togglePlay() } label: {
                Label(engine.isPlaying ? "Pause" : "Play",
                      systemImage: engine.isPlaying ? "pause.fill" : "play.fill")
            }
            Spacer()
            Button {
                taps.removeAll()
                hooks.playFromStart()
            } label: {
                Label("From the start", systemImage: "backward.end.fill")
            }
            Spacer()
            Button("Reset") { taps.removeAll() }
                .foregroundStyle(PocketColor.textSecondary)
                .disabled(taps.isEmpty)
        }
        .buttonStyle(.borderless)
        .font(.futura(.subheadline))
    }

    private func tap() {
        guard engine.isPlaying else { return }
        taps.append(engine.currentTime)
        haptic(.light)
    }

    private func save() {
        isSaving = true
        didNotMap = false
        let captured = taps
        Task {
            let envelope = await onsets?.value
            if !hooks.commit(captured, envelope) { didNotMap = true }
            isSaving = false
        }
    }
}

/// How far through the song the tap-through is. Its own view so the playhead, which moves many
/// times a second, re-renders only this bar and not the pad being tapped.
private struct TapThroughProgress: View {
    let engine: PracticeAudioEngine
    let duration: TimeInterval

    var body: some View {
        VStack(spacing: 4) {
            ProgressView(value: min(engine.currentTime, duration), total: max(duration, 0.001))
                .tint(PocketColor.active)
            HStack {
                Text(timecode(engine.currentTime))
                Spacer()
                Text(timecode(duration))
            }
            .font(.pocketMono(.caption))
            .foregroundStyle(PocketColor.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(timecode(engine.currentTime)) of \(timecode(duration))")
    }
}
