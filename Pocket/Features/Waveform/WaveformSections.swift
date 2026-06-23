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
    /// Hold the title/artist block to open the song details sheet (workstream 5).
    /// Defaulted to a no-op for previews and standalone use.
    var onHoldTitle: () -> Void = {}

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
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.4) {
                haptic(.medium)     // confirm the hold landed before the sheet appears
                onHoldTitle()
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Hold to view song details")
            // VoiceOver can't long-press, so surface the same action explicitly.
            .accessibilityAction(named: "Song details", onHoldTitle)
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 2) {
                // Derived song mastery (ADR 0036) — shown only when the song has loops
                // to roll up; an unrated song just shows its length.
                if let mastery = song.mastery {
                    Text(stars(mastery))
                        .font(.subheadline)
                        .foregroundStyle(PocketColor.marker)
                        .accessibilityLabel("Mastery \(mastery) of 5")
                }
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

    /// Derived song mastery as stars, or "Unrated" when the song has no loops (ADR 0036).
    private var masteryText: String { song.mastery.map(stars) ?? "Unrated" }

    private var summary: String {
        "\(song.key) · \(masteryText)"
    }

    var body: some View {
        CollapsiblePanel(title: "Song info", summary: summary, expanded: $expanded) {
            VStack(alignment: .leading, spacing: 10) {
                LabeledRow(label: "Key", value: song.key)
                LabeledRow(label: "Mastery", value: masteryText)
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
    /// In-song metronome click (ADR 0027 — relocated here from the transport bar, where
    /// it sat next to play/loop and read as another transport control). The click is
    /// tempo context, so it lives by the BPM readout. On/off, whether a grid exists to
    /// click against (tempo + downbeat set), and the toggle. Defaulted off/disabled for
    /// previews and standalone use.
    var metronomeOn: Bool = false
    var canUseMetronome: Bool = false
    var onToggleMetronome: () -> Void = {}

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
                    // Long-press to re-open the tempo editor (Tap/Manual) so a wrong
                    // tempo or downbeat can be corrected — the readout otherwise
                    // replaces the "Set BPM" entry point once a tempo is known (ADR 0024).
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(displayedBPM)")
                            .font(.pocketMono(.headline))
                            .foregroundStyle(PocketColor.textPrimary)
                        Text("BPM")
                            .font(.caption2)
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                    .contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 0.4) {
                        haptic(.medium)     // confirm the hold landed before the editor opens
                        onSetBPM()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(displayedBPM) beats per minute")
                    .accessibilityHint("Long press to change the tempo")
                    .accessibilityAction(named: "Change tempo") { onSetBPM() }
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

                // In-song click (ADR 0027). Compact, icon-only — it's a tempo tool, so
                // it rides next to the BPM. Greyed until the song has a grid (tempo + 1).
                MetronomeToggle(isOn: metronomeOn,
                                isEnabled: canUseMetronome || metronomeOn,
                                action: onToggleMetronome)
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

/// In-song metronome click toggle on the speed bar (ADR 0027). Icon-only, in the
/// metronome's own teal so it doesn't read as a transport control; greys out until
/// the song has a beat grid (tempo + downbeat). A 44pt target around a 30pt badge.
private struct MetronomeToggle: View {
    let isOn: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "metronome")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 30, height: 30)
                .background(Circle().fill(isOn ? PocketColor.metronome : Color.white.opacity(0.08)))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel("Metronome click")
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityHint("Plays a click on the beat while the song plays")
    }

    private var foreground: Color {
        if !isEnabled { return PocketColor.textSecondary.opacity(0.4) }
        return isOn ? PocketColor.background : PocketColor.metronome
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

// Section 8 (transport bar) lives in `WaveformTransportBar.swift`.
