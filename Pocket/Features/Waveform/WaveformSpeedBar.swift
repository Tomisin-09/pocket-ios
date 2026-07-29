import SwiftUI

// Section 3 of the waveform practice screen (design brief §4.1) — the always-visible speed / BPM
// bar. Split out of `WaveformSections.swift` when the transport redesign (ADR 0124) gave it three
// more jobs and pushed that file past its line budget; shares the same `panelBackground` chrome.
//
// The row, left to right: the **speed readout** (tap for custom numeric entry), the **slider**
// (0.25×–1.5×, `TempoMath`'s axis), the **effective BPM** when the song's tempo is known, then two
// packed circular controls — **repeat the song** and the **metronome click**.
//
// ADR 0124 moved the tempo entry point onto the metronome: the "Set BPM" capsule that used to hold
// the readout's slot is gone, and its place is now REPEAT. Holding the metronome opens the tempo
// editor from any state; while the tempo is *unknown* the metronome also badges itself and takes a
// plain tap, because a fresh import has no grid, no snap and no click until a BPM exists — that
// state must not depend on discovering a hold.

// MARK: - 3. Speed / BPM bar (always visible)

struct SpeedBar: View {
    @Binding var speed: Double
    /// `nil` when the song's tempo is unknown — the BPM readout collapses and the metronome badges.
    let displayedBPM: Int?
    let onSetBPM: () -> Void
    /// Fired when the user grabs the slider (or commits a typed speed), so a running loop automator
    /// can stand down — manual control wins. Defaults to a no-op for previews/standalone use.
    var onUserAdjust: () -> Void = {}
    /// In-song metronome click (ADR 0027 — relocated here from the transport bar, where it sat next
    /// to play/loop and read as another transport control). The click is tempo context, so it lives
    /// by the BPM readout. Defaulted off/disabled for previews and standalone use.
    var metronomeOn: Bool = false
    var canUseMetronome: Bool = false
    var onToggleMetronome: () -> Void = {}
    /// Whole-song repeat (ADR 0124) — playback wraps to the top instead of stopping at the end.
    /// `canRepeat` is false while a loop is armed: that loop is already repeating its own region.
    var repeatsSong: Bool = false
    var canRepeat: Bool = true
    var onToggleRepeat: () -> Void = {}
    /// Compact form (landscape, ADR 0042): drops the preset-pill row to reclaim vertical
    /// space — the slider still covers the full range, presets are a portrait convenience.
    var compact: Bool = false

    /// Custom numeric entry (ADR 0124) — the slider can't land on an exact 0.85× at this width.
    @State private var enteringSpeed = false

    private let presets: [Double] = [0.25, 0.50, 0.75]

    var body: some View {
        VStack(spacing: 6) {
            // Readout + slider share one row to keep this (the heaviest fixed
            // element) compact in the pinned cockpit.
            HStack(spacing: 10) {
                speedReadout

                // NOTE: brief §4.1 wants an asymmetric scale (0.25–1.0 occupies
                // ~54% of the track). That custom track mapping is a later
                // single-axis iteration; a linear slider stands in for now.
                Slider(value: $speed, in: TempoMath.minSpeed...TempoMath.maxSpeed,
                       onEditingChanged: { editing in if editing { onUserAdjust() } })
                    .tint(PocketColor.waveformAccent)
                    .accessibilityLabel("Playback speed")

                if let displayedBPM { bpmReadout(displayedBPM) }

                // Packed so the two circular controls read as one trailing group rather than
                // competing with the readouts for the slider's width.
                HStack(spacing: 0) {
                    RepeatToggle(isOn: repeatsSong, isEnabled: canRepeat, action: onToggleRepeat)
                    MetronomeControl(isOn: metronomeOn,
                                     canClick: canUseMetronome || metronomeOn,
                                     tempoKnown: displayedBPM != nil,
                                     onToggle: onToggleMetronome,
                                     onSetBPM: onSetBPM)
                }
            }

            if !compact {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { value in
                        PresetPill(label: String(format: "%.2f×", value),
                                   isSelected: abs(speed - value) < 0.001) {
                            onUserAdjust()
                            speed = value
                        }
                    }
                    Spacer()
                    PresetPill(label: "Reset", isSelected: abs(speed - 1.0) < 0.001) {
                        onUserAdjust()
                        speed = 1.0
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, compact ? 6 : 8)
        .background(panelBackground)
    }

    /// The live speed multiplier. Tapping opens numeric entry — the slider is ~130 pt wide once the
    /// readouts and controls take their share, which is not enough track to land on an exact value.
    private var speedReadout: some View {
        Button { enteringSpeed = true } label: {
            Text(String(format: "%.2f×", speed))
                .font(.pocketMono(.title3))
                .foregroundStyle(PocketColor.textPrimary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Playback speed \(String(format: "%.2f", speed)) times")
        .accessibilityHint("Opens numeric entry")
        .popover(isPresented: $enteringSpeed) {
            SpeedEntryPopover(speed: $speed, onUserAdjust: onUserAdjust) { enteringSpeed = false }
                .presentationCompactAdaptation(.popover)
        }
    }

    /// Effective BPM (song tempo × speed). Long-press still re-opens the tempo editor — the route
    /// that shipped with ADR 0024 — so a wrong tempo stays correctable where it's displayed.
    private func bpmReadout(_ bpm: Int) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text("\(bpm)")
                .font(.pocketMono(.headline))
                .foregroundStyle(PocketColor.textPrimary)
            Text("BPM")
                .font(.futura(.caption2))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.4) {
            haptic(.medium)     // confirm the hold landed before the editor opens
            onSetBPM()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(bpm) beats per minute")
        .accessibilityHint("Long press to change the tempo")
        .accessibilityAction(named: "Change tempo") { onSetBPM() }
    }
}

// MARK: - Components

/// Whole-song repeat (ADR 0124). `repeat.1` rather than plain `repeat` on purpose: the transport
/// bar's Loop control already owns the bare glyph, and this is the "repeat this one thing" sense.
/// Disabled — not hidden — while a loop is armed, since that loop is already repeating.
private struct RepeatToggle: View {
    let isOn: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "repeat.1")
                .font(.futura(size: 15, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 30, height: 30)
                .background(Circle().fill(isOn ? PocketColor.waveformAccent : PocketColor.surfaceStandard))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel("Repeat the song")
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityHint(isEnabled ? "Plays the song again instead of stopping at the end"
                                     : "Unavailable while a loop is armed — the loop already repeats")
    }

    private var foreground: Color {
        if !isEnabled { return PocketColor.textSecondary.opacity(0.4) }
        return isOn ? PocketColor.background : PocketColor.waveformAccent
    }
}

/// In-song metronome click (ADR 0027) **and** the tempo entry point (ADR 0124). Icon-only, in the
/// song's teal accent (`waveformAccent`, ADR 0081) so it sits with the waveform cockpit rather than
/// reading as a transport control. A 44 pt target around a 30 pt badge.
///
/// Three states, and the button is never dead:
/// • **Grid exists** — tap toggles the click, hold opens the tempo editor.
/// • **Tempo known, no 1 placed** — the click can't run (`beatGrid` is empty), so tap *also* opens
///   the editor, where "Set the 1 on the waveform" lives. The mode line carries its own **Set the 1**
///   prompt for this state; this is the second door, not the announcement.
/// • **Tempo unknown** — a `plus` badge and an accent tint say there's something to add, and tap
///   opens the editor. This is the fresh-import state the ADR insists must stay visible: no grid, no
///   snap, no click until a BPM exists, and no hold to discover.
private struct MetronomeControl: View {
    let isOn: Bool
    /// Whether there's a grid to click against (tempo + the 1), or a click already running.
    let canClick: Bool
    let tempoKnown: Bool
    let onToggle: () -> Void
    let onSetBPM: () -> Void

    /// What the control is for right now — the tap target, the tint and the wording all read off it.
    private enum Mode { case click, needsDownbeat, needsTempo }
    private var mode: Mode {
        guard tempoKnown else { return .needsTempo }
        return canClick ? .click : .needsDownbeat
    }

    var body: some View {
        Image(systemName: "metronome")
            .font(.futura(size: 15, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: 30, height: 30)
            .background(Circle().fill(isOn ? PocketColor.waveformAccent : PocketColor.surfaceStandard))
            .overlay(alignment: .topTrailing) {
                // The fresh-import badge — something to add here, no hold to discover.
                if mode == .needsTempo {
                    Image(systemName: "plus.circle.fill")
                        .font(.futura(size: 11, weight: .bold))
                        .foregroundStyle(PocketColor.waveformAccent)
                        .background(Circle().fill(PocketColor.background))
                        .offset(x: 3, y: -2)
                }
            }
            .frame(width: 44, height: 44)
            // Tap + hold as gestures on a plain shape, **not** a `Button` with a long press bolted
            // on: that pairing fires both on a hold. The loop row (ADR 0041) does the same.
            .contentShape(Rectangle())
            .onTapGesture { mode == .click ? onToggle() : openTempoEditor() }
            .onLongPressGesture(minimumDuration: 0.4) {
                haptic(.medium)     // confirm the hold landed before the editor appears
                onSetBPM()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(mode == .click ? "Metronome click" : "Set tempo")
            .accessibilityValue(mode == .click ? (isOn ? "On" : "Off") : "")
            .accessibilityHint(hint)
            // VoiceOver can't long-press, so surface the hold's action explicitly.
            .accessibilityAction(named: "Change tempo") { onSetBPM() }
    }

    private func openTempoEditor() {
        haptic(.light)
        onSetBPM()
    }

    private var hint: String {
        switch mode {
        case .click: return "Plays a click on the beat while the song plays"
        case .needsDownbeat: return "The 1 isn't placed yet — tap to set it"
        case .needsTempo: return "The song has no tempo yet — tap to set it"
        }
    }

    private var foreground: Color {
        // Greyed while the click can't run, but still live: the grey says "no click yet", the tap
        // offers the missing step. `needsTempo` keeps the accent, since the badge is the invitation.
        if mode == .needsDownbeat { return PocketColor.textSecondary.opacity(0.4) }
        return isOn ? PocketColor.background : PocketColor.waveformAccent
    }
}

/// Type an exact playback speed (ADR 0124). Out-of-range is **named, not clamped**: silently
/// accepting 1.5 for a typed 2 would look like the field ate the keystrokes, so the rejection is
/// spelled out and the value stands until it's valid. Parsing lives in `TempoMath.parse(speedEntry:)`.
private struct SpeedEntryPopover: View {
    @Binding var speed: Double
    let onUserAdjust: () -> Void
    let onDone: () -> Void

    @State private var text = ""
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Playback speed")
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
            HStack(spacing: 6) {
                TextField("1.00", text: $text)
                    .font(.pocketMono(.title3))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(commit)
                    .frame(width: 110)
                Text("×")
                    .font(.pocketMono(.title3))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Text(error ?? rangeHint)
                .font(.futura(.caption))
                .foregroundStyle(error == nil ? PocketColor.textSecondary : PocketColor.danger)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: commit) {
                Text("Set")
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(PocketColor.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(PocketColor.waveformAccent))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(width: 230)
        .onAppear {
            text = String(format: "%.2f", speed)
            focused = true
        }
    }

    private var rangeHint: String {
        String(format: "Between %.2f× and %.2f×", TempoMath.minSpeed, TempoMath.maxSpeed)
    }

    private func commit() {
        switch TempoMath.parse(speedEntry: text) {
        case .valid(let value):
            onUserAdjust()          // a typed speed is manual control too — stand the automator down
            speed = value
            haptic(.light)
            onDone()
        case .notANumber:
            error = "Enter a number, like 0.75"
        case .outOfRange:
            error = rangeHint
        }
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
                    Capsule().fill(isSelected ? PocketColor.active : PocketColor.surfaceStandard)
                )
        }
        .buttonStyle(.plain)
    }
}
