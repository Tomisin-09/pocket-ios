import SwiftUI

// The individual sections of the waveform practice screen, top → bottom
// (design brief §4.1). Split out of `WaveformPracticeView` to keep each file
// focused; shared chrome (`CollapsiblePanel`, `panelBackground`) and the
// formatting helpers live alongside the screen.

// MARK: - 1. Song strip

struct SongStrip: View {
    let song: WaveformMock.Song

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.headline)
                    .foregroundStyle(PocketColor.textPrimary)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(PocketColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 2) {
                Text(song.key)
                    .font(.subheadline)
                    .foregroundStyle(PocketColor.textPrimary)
                Text(timecode(song.duration))
                    .font(.pocketMono(.subheadline))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
    }
}

// MARK: - 2. Song info panel (collapsible, open by default)

struct SongInfoPanel: View {
    let song: WaveformMock.Song
    @Binding var expanded: Bool

    private var summary: String {
        "\(song.key) · \(stars(song.proficiency)) · \(song.progression)"
    }

    var body: some View {
        CollapsiblePanel(title: "Song info", summary: summary, expanded: $expanded) {
            VStack(alignment: .leading, spacing: 10) {
                LabeledRow(label: "Key", value: song.key)
                LabeledRow(label: "Proficiency", value: stars(song.proficiency))
                LabeledRow(label: "Progression", value: song.progression)
                HStack(spacing: 8) {
                    ForEach(song.collections, id: \.self) { name in
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(PocketColor.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                    }
                }
                .padding(.top, 2)
            }
        }
    }
}

private struct LabeledRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(PocketColor.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(PocketColor.textPrimary)
        }
    }
}

// MARK: - 3. Speed / BPM bar (always visible)

struct SpeedBar: View {
    @Binding var speed: Double
    /// `nil` when the song's tempo is unknown — shows a "Set BPM" affordance.
    let displayedBPM: Int?
    let onSetBPM: () -> Void

    private let presets: [Double] = [0.25, 0.50, 0.75]

    var body: some View {
        VStack(spacing: 8) {
            // Readout + slider share one row to keep this (the heaviest fixed
            // element) compact in the pinned cockpit.
            HStack(spacing: 14) {
                Text(String(format: "%.2f×", speed))
                    .font(.pocketMono(.title))
                    .foregroundStyle(PocketColor.textPrimary)

                // NOTE: brief §4.1 wants an asymmetric scale (0.25–1.0 occupies
                // ~54% of the track). That custom track mapping is a later
                // single-axis iteration; a linear slider stands in for now.
                Slider(value: $speed, in: 0.25...2.0)
                    .tint(PocketColor.active)
                    .accessibilityLabel("Playback speed")

                if let displayedBPM {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(displayedBPM)")
                            .font(.pocketMono(.headline))
                            .foregroundStyle(PocketColor.textPrimary)
                        Text("BPM")
                            .font(.caption2)
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(displayedBPM) beats per minute")
                } else {
                    // Unknown tempo — speed (×) still works; offer to set it.
                    Button(action: onSetBPM) {
                        Text("Set BPM")
                            .font(.pocketMono(.footnote))
                            .foregroundStyle(PocketColor.marker)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.white.opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Set tempo")
                }
            }

            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { value in
                    PresetPill(label: String(format: "%.2f×", value),
                               isSelected: abs(speed - value) < 0.001) {
                        speed = value
                    }
                }
                Spacer()
                PresetPill(label: "Reset", isSelected: abs(speed - 1.0) < 0.001) {
                    speed = 1.0
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(panelBackground)
    }
}

private struct PresetPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.pocketMono(.caption))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(isSelected ? PocketColor.background : PocketColor.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(isSelected ? PocketColor.active : Color.white.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 4. Mode description line

struct ModeDescriptionLine: View {
    let mode: WaveformPracticeView.InteractionMode
    var body: some View {
        Text(mode.blurb)
            .font(.footnote)
            .foregroundStyle(PocketColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 6. Time ruler

struct TimeRuler: View {
    let duration: TimeInterval
    private let ticks = 5

    var body: some View {
        HStack {
            ForEach(0...ticks, id: \.self) { tick in
                Text(timecode(duration * Double(tick) / Double(ticks)))
                    .font(.pocketMono(.caption2))
                    .foregroundStyle(PocketColor.textSecondary)
                if tick < ticks { Spacer() }
            }
        }
    }
}

// MARK: - 8. Transport bar

struct TransportBar: View {
    @Binding var isPlaying: Bool
    @Binding var repeatOn: Bool
    @Binding var mode: WaveformPracticeView.InteractionMode
    let currentTime: TimeInterval
    let loop: WaveformMock.Loop?
    /// Capture a loop → opens the creation panel. Stands in for the Tap/Fine
    /// gesture capture until the waveform gesture engine exists.
    let onCapture: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Button { isPlaying.toggle() } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundStyle(PocketColor.active)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(isPlaying ? "Pause" : "Play")

                Text(timecode(currentTime))
                    .font(.pocketMono(.body))
                    .foregroundStyle(PocketColor.textPrimary)

                if let loop {
                    Text("\(timecode(loop.startSeconds))–\(timecode(loop.endSeconds))")
                        .font(.pocketMono(.footnote))
                        .foregroundStyle(PocketColor.marker)
                }

                Spacer()

                Button(action: onCapture) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(PocketColor.marker)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Capture loop")

                Button { repeatOn.toggle() } label: {
                    Image(systemName: "repeat")
                        .foregroundStyle(repeatOn ? PocketColor.active : PocketColor.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Repeat loop")

                Button {} label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(PocketColor.danger)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Clear loop")
            }

            HStack(spacing: 8) {
                ForEach(WaveformPracticeView.InteractionMode.allCases) { item in
                    ModePill(label: item.rawValue, isSelected: mode == item) { mode = item }
                }
            }
        }
        .padding(12)
        .background(panelBackground)
    }
}

private struct ModePill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? PocketColor.background : PocketColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? PocketColor.fine : Color.white.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
    }
}
