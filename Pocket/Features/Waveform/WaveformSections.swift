import SwiftUI

// The individual sections of the waveform practice screen, top → bottom
// (design brief §4.1). Split out of `WaveformPracticeView` to keep each file
// focused; shared chrome (`CollapsiblePanel`, `panelBackground`) lives alongside
// the screen.

// MARK: - Formatting helpers

/// `M:SS` monospace timecode (brief §3.2 — mono for all time values).
func timecode(_ seconds: TimeInterval) -> String {
    let total = Int(seconds.rounded())
    return String(format: "%d:%02d", total / 60, total % 60)
}

func stars(_ filled: Int) -> String {
    String(repeating: "★", count: filled) + String(repeating: "☆", count: max(0, 5 - filled))
}

// MARK: - 1. Song strip

struct SongStrip: View {
    let song: Song

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
    let song: Song
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
    /// Fired when the user grabs the slider, so a running loop automator can stand down
    /// (manual control wins). Defaults to a no-op for previews/standalone use.
    var onUserAdjust: () -> Void = {}

    private let presets: [Double] = [0.25, 0.50, 0.75]

    var body: some View {
        VStack(spacing: 6) {
            // Readout + slider share one row to keep this (the heaviest fixed
            // element) compact in the pinned cockpit.
            HStack(spacing: 12) {
                Text(String(format: "%.2f×", speed))
                    .font(.pocketMono(.title3))
                    .foregroundStyle(PocketColor.textPrimary)

                // NOTE: brief §4.1 wants an asymmetric scale (0.25–1.0 occupies
                // ~54% of the track). That custom track mapping is a later
                // single-axis iteration; a linear slider stands in for now.
                Slider(value: $speed, in: 0.25...2.0,
                       onEditingChanged: { editing in if editing { onUserAdjust() } })
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
        .padding(.vertical, 8)
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
    /// The visible window in seconds — the whole song, or the zoomed slice when
    /// pinch-zoomed, so the axis labels match what's on screen.
    let start: TimeInterval
    let end: TimeInterval
    private let ticks = 5

    var body: some View {
        HStack {
            ForEach(0...ticks, id: \.self) { tick in
                Text(timecode(start + (end - start) * Double(tick) / Double(ticks)))
                    .font(.pocketMono(.caption2))
                    .foregroundStyle(PocketColor.textSecondary)
                if tick < ticks { Spacer() }
            }
        }
    }
}

// MARK: - 8. Transport bar

struct TransportBar: View {
    let isPlaying: Bool
    let onPlayPause: () -> Void
    @Binding var mode: WaveformPracticeView.InteractionMode
    let currentTime: TimeInterval
    let loop: Loop?
    /// Exit the active loop (stop looping, play on through the song).
    let onClearLoop: () -> Void
    /// Action bar: drop a marker at the playhead.
    let onDropMarker: () -> Void
    /// Action bar: punch the loop in / out at the playhead (a toggle).
    let onPunch: () -> Void
    /// True between the in- and out-punch, so the Loop button reads "armed".
    let isPunchActive: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button(action: onPlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(PocketColor.active)
                        .frame(width: 44, height: 34)
                }
                .accessibilityLabel(isPlaying ? "Pause" : "Play")

                Text(timecode(currentTime))
                    .font(.pocketMono(.body))
                    .foregroundStyle(PocketColor.textPrimary)

                Spacer()

                // Active loop — name (primary) over its range, with an exit chip.
                // The loop just loops; the ✕ is the way out (back to full song).
                if let loop {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(loop.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(PocketColor.active)
                            .lineLimit(1)
                        Text("\(timecode(loop.startSeconds))–\(timecode(loop.endSeconds))")
                            .font(.pocketMono(.caption2))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Looping \(loop.name)")

                    Button(action: onClearLoop) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PocketColor.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Exit loop")
                }
            }

            // Action bar — capture at the playhead + the precise-edit toggle.
            // (`A`utomator slot reserved, ADR 0009.)
            HStack(spacing: 8) {
                ActionButton(icon: "repeat", label: "Loop", tint: PocketColor.active,
                             isActive: isPunchActive, action: onPunch)
                ActionButton(icon: "mappin", label: "Mark", tint: PocketColor.pin, action: onDropMarker)
                ActionButton(icon: "slider.horizontal.3", label: "Fine", tint: PocketColor.fine,
                             isActive: mode == .fine) { mode = (mode == .fine ? .navigate : .fine) }
                ActionButton(icon: "metronome", label: "Auto", tint: PocketColor.textSecondary,
                             isEnabled: false, action: {})
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(panelBackground)
    }
}

/// One capsule button on the transport action bar (icon over a small label).
private struct ActionButton: View {
    let icon: String
    let label: String
    var tint: Color = PocketColor.textPrimary
    var isActive: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                Text(label).font(.caption2)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Capsule().fill(isActive ? tint : Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }

    private var foreground: Color {
        if !isEnabled { return PocketColor.textSecondary.opacity(0.4) }
        return isActive ? PocketColor.background : tint
    }
}
