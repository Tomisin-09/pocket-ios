import SwiftUI

// Section 8 of the waveform practice screen (design brief §4.1) — the pinned
// transport row. Split out of `WaveformSections.swift` to keep each file under the
// line budget; shares the same `panelBackground` chrome.
//
// Layout (ADR 0030; ADR 0041; V1 feedback #1): two states.
// • **Idle** (no active loop): two large **circular** identity controls flank the centre transport —
//   **Marker on the far left**, **Loop on the far right** — a glyph in a circle. The Loop button
//   lights while an A/B span is forming.
// • **Active** (a saved loop is running): the bar reverts to its **compact** form — a small stacked
//   Loop / Marker column on the left and the loop's identity-colour ✕ strip on the right — because
//   the running loop now reads on the Loops panel below, so the bar steps back out of the way
//   (feedback #1 round 2).
// The centre cluster is the header over rewind · pause · forward; the header reserves a fixed height
// and reads the loop's name when active, else stays empty — the live playhead time renders as the
// `TimeBubble` on the waveform canvas, so the redundant idle timecode was dropped (ADR 0075).
//
// The centre glyphs themselves change with the same two states (ADR 0124):
// • **Idle** — **−N / +N second skips** in circular-arrow glyphs, holding either to change the
//   increment. Rewind's single-tap "restart" is deliberately given up: moving freely inside the
//   waveform is the thing you do constantly, and restarting is a tap on the start of the wave.
// • **Active** — unchanged: rewind restarts the loop (double-tap → previous), forward → next loop.

// MARK: - 8. Transport bar

struct TransportBar: View {
    let isPlaying: Bool
    let onPlayPause: () -> Void
    /// Rewind single tap — restart the loop / song.
    let onRestart: () -> Void
    /// Rewind double tap — previous loop.
    let onPrevious: () -> Void
    /// Forward single tap — next loop.
    let onNext: () -> Void
    /// Whether previous / next have a target right now (else the affordance dims).
    let hasPrevious: Bool
    let hasNext: Bool
    /// Seek by a signed number of seconds — the idle skip buttons (ADR 0124). The caller clamps to
    /// the song. Defaulted to a no-op for previews and standalone use.
    var onSkip: (TimeInterval) -> Void = { _ in }

    let loop: Loop?
    /// The active loop's identity colour, for the right strip. `nil` ⇒ no active loop.
    let loopColor: Color?
    /// Deactivate the active loop (the ✕ on the colour strip).
    let onClearLoop: () -> Void
    /// Mark control — drop a marker at the playhead.
    let onDropMarker: () -> Void
    /// Loop control — advance the play-along loop cycle at the playhead (set start · set
    /// end · clear); internally the A/B span (ADR 0041).
    let onPunch: () -> Void
    /// True while a loop span is in play, so the control reads "armed" (ADR 0041).
    let isPunchActive: Bool
    /// Compact form (landscape, ADR 0042): smaller glyphs + a shorter bar so the
    /// transport always clears the bottom edge where vertical room is scarce.
    var compact: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Which side the big idle Loop button sits on (the Marker takes the other). Default off ⇒
    /// Marker-left / Loop-right, the shipped arrangement; on ⇒ swapped, a user preference set in
    /// Settings. Applies to the **idle** flanking controls only — while a loop is active the compact
    /// column + colour strip keep their sides (the strip must stay where the loop identity reads).
    @AppStorage(AppSettings.Key.transportLoopOnLeft)
    private var loopOnLeft = AppSettings.transportLoopOnLeftDefault
    /// How far the idle skip buttons move, in seconds (ADR 0124). Lives here rather than on the
    /// model because it's a standing habit, not per-song state — the same reasoning as `loopOnLeft`.
    @AppStorage(AppSettings.Key.transportSkipSeconds) private var skipSeconds = Int(TransportSkip.defaultIncrement)

    private var glyphSize: CGFloat { compact ? 24 : 25 }
    /// The big flanking identity circles (idle only) — sized to "take up space" (feedback #1),
    /// trimmed a little in the shorter landscape bar so they still clear the edges.
    private var identityDiameter: CGFloat { compact ? 42 : 46 }
    /// Whether a saved loop is active — the transport reverts to its compact form (feedback #1
    /// round 2): the big idle buttons are for browsing/creating; once a loop is running the Loops
    /// panel below carries it, so the bar goes back to the small stacked column + ✕ strip.
    private var loopActive: Bool { loopColor != nil }

    var body: some View {
        HStack(spacing: 12) {
            leftControls
            VStack(spacing: compact ? 2 : 5) {
                header
                transportRow
            }
            .frame(maxWidth: .infinity)
            rightControls
        }
        .frame(height: compact ? 52 : 56)  // definite bar height so the colour strip reliably fills it
        .padding(.horizontal, 12)
        .padding(.vertical, compact ? 3 : 4)
        .background(panelBackground)
        // `loop?.uid` is nil when idle and changes on activate/deactivate *and* loop-switch, so the
        // idle⇄compact morph and a colour/name change between loops both animate.
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: loop?.uid)
    }

    // MARK: Flanking identity controls

    /// Idle: a big circular identity button on each side — **Marker** and **Loop**, their sides set
    /// by `loopOnLeft` (default Marker-left / Loop-right). Active: the left reverts to the compact
    /// stacked **Loop / Marker** column, so the running loop reads on the Loops panel below and the
    /// bar stays out of the way (feedback #1 round 2); the swap preference applies to idle only.
    @ViewBuilder private var leftControls: some View {
        if loopActive {
            VStack(spacing: 0) {
                TransportControl(icon: "repeat", color: PocketColor.active, isActive: isPunchActive,
                                 label: "Loop", diameter: compactControlDiameter,
                                 glyphSize: compactControlGlyph, action: onPunch)
                Spacer(minLength: 0)
                TransportControl(icon: "triangle.fill", rotation: 180, color: PocketColor.pin,
                                 label: "Marker", diameter: compactControlDiameter,
                                 glyphSize: compactControlGlyph, action: onDropMarker)
            }
            .transition(.opacity)
        } else if loopOnLeft {
            idleLoopButton
        } else {
            idleMarkerButton
        }
    }

    /// Right slot: the ✕ colour strip once a saved loop is active — it stays on the right so the loop
    /// identity reads there regardless of the swap — else the big idle control on this side (Loop by
    /// default, Marker when swapped). Mutually exclusive; they share the slot.
    @ViewBuilder private var rightControls: some View {
        if let loopColor {
            LoopColorStrip(color: loopColor, onDeactivate: onClearLoop)
                .transition(.move(edge: .trailing).combined(with: .opacity))
        } else if loopOnLeft {
            idleMarkerButton
        } else {
            idleLoopButton
        }
    }

    /// The big idle **Marker** identity circle — an equilateral triangle rotated to point down,
    /// matching the waveform's marker glyph.
    private var idleMarkerButton: some View {
        TransportControl(icon: "triangle.fill", rotation: 180, color: PocketColor.pin,
                         label: "Marker", diameter: identityDiameter, action: onDropMarker)
            .transition(.opacity)
    }

    /// The big idle **Loop** identity circle, lit while an A/B span is forming (ADR 0041).
    private var idleLoopButton: some View {
        TransportControl(icon: "repeat", color: PocketColor.active, isActive: isPunchActive,
                         label: "Loop", diameter: identityDiameter, action: onPunch)
            .transition(.opacity)
    }

    // MARK: Centre — header + transport

    @ViewBuilder private var header: some View {
        Group {
            if let loop {
                // Just the loop name — the range lives in the loop row / waveform, and
                // dropping it here keeps the header one line so the transport breathes.
                Text(loop.name)
                    .font(.futura(.body, weight: .medium))
                    .foregroundStyle(PocketColor.textPrimary)
                    .lineLimit(1)
                    .accessibilityLabel("Looping \(loop.name)")
            }
            // Idle: no timecode — the live playhead time already renders as the `TimeBubble` on the
            // waveform canvas, so the redundant readout was dropped (ADR 0075). The fixed height below
            // keeps the empty header from shifting the transport row.
        }
        .frame(height: 22)        // single-line header height, matched across both states
        .transition(.opacity)
    }

    private var transportRow: some View {
        HStack(spacing: compact ? 32 : 40) {
            if loopActive {
                RewindButton(onRestart: onRestart, onPrevious: onPrevious,
                             hasPrevious: hasPrevious, size: glyphSize)
            } else {
                skipButton(forward: false)
            }
            TransportGlyph(icon: isPlaying ? "pause.fill" : "play.fill",
                           label: isPlaying ? "Pause" : "Play", size: glyphSize, action: onPlayPause)
            if loopActive {
                TransportGlyph(icon: "forward.fill", label: "Next loop",
                               isEnabled: hasNext, size: glyphSize, action: onNext)
            } else {
                skipButton(forward: true)
            }
        }
    }

    /// A timed skip (ADR 0124). The glyph *is* the amount (`gobackward.10`), so nothing needs
    /// captioning; a context menu on the same button re-picks the increment for both sides at once.
    private func skipButton(forward: Bool) -> some View {
        let increment = TransportSkip.resolved(seconds: skipSeconds)
        let label = TransportSkip.label(increment: increment)
        return TransportGlyph(icon: TransportSkip.symbol(increment: increment, forward: forward),
                              label: forward ? "Forward \(label)" : "Back \(label)",
                              size: glyphSize) {
            onSkip(forward ? increment : -increment)
        }
        .contextMenu { skipMenu }
        .transition(.opacity)
    }

    @ViewBuilder private var skipMenu: some View {
        ForEach(TransportSkip.increments, id: \.self) { increment in
            Button {
                skipSeconds = Int(increment)
                haptic(.light)
            } label: {
                // A checkmark on the current choice; the others carry no glyph, so the menu reads
                // as a picker rather than five identical commands.
                if Int(increment) == skipSeconds {
                    Label(TransportSkip.label(increment: increment), systemImage: "checkmark")
                } else {
                    Text(TransportSkip.label(increment: increment))
                }
            }
        }
    }
}

// MARK: - Components

private let transportGlyphSize: CGFloat = 28
/// The compact stacked column shown once a loop is active — the original small identity dots.
private let compactControlDiameter: CGFloat = 27
private let compactControlGlyph: CGFloat = 15

/// An identity control — a glyph in a circle. Idle it's a big flanking button; active it's a small
/// stacked dot. Idle fill: the glyph in its colour on a faint fill. Active fill (Loop while an A/B
/// span is in play): the circle fills with the colour, glyph flips dark. `glyphSize` defaults to a
/// slightly-trimmed fraction of the diameter (feedback #1: keep the big circles, ease the glyph).
private struct TransportControl: View {
    let icon: String
    var rotation: Double = 0
    let color: Color
    var isActive: Bool = false
    let label: String
    var diameter: CGFloat = 52
    var glyphSize: CGFloat?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.futura(size: glyphSize ?? diameter * 0.36, weight: .semibold))
                .rotationEffect(.degrees(rotation))
                .foregroundStyle(isActive ? PocketColor.background : color)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(isActive ? color : PocketColor.surfaceStandard))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}

/// A background-free transport glyph (pause / forward / play). No pill behind it.
private struct TransportGlyph: View {
    let icon: String
    let label: String
    var isEnabled: Bool = true
    var size: CGFloat = transportGlyphSize
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.futura(size: size, weight: .semibold))
                .foregroundStyle(isEnabled ? PocketColor.textPrimary : PocketColor.textSecondary.opacity(0.35))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }
}

/// The rewind glyph: single tap restarts (loop / song); double tap skips to the
/// previous loop. The `count: 2` tap is registered before `count: 1` so SwiftUI
/// disambiguates them; VoiceOver reaches "previous" via a custom action (its own
/// double-tap is the activation gesture, so it maps to the single action).
private struct RewindButton: View {
    let onRestart: () -> Void
    let onPrevious: () -> Void
    let hasPrevious: Bool
    var size: CGFloat = transportGlyphSize

    var body: some View {
        Image(systemName: "backward.fill")
            .font(.futura(size: size, weight: .semibold))
            .foregroundStyle(PocketColor.textPrimary)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { if hasPrevious { onPrevious() } }
            .onTapGesture(count: 1) { onRestart() }
            .accessibilityLabel("Restart")
            .accessibilityAction(named: "Previous loop") { if hasPrevious { onPrevious() } }
    }
}

/// The active loop's identity-colour strip with the ✕ deactivator (ADR 0030) — the
/// "a loop is armed" signal. Stretches to the bar's full height (a bare shape would
/// otherwise collapse to its ~10pt default and hide behind the ✕). Absent when no
/// loop is active.
private struct LoopColorStrip: View {
    let color: Color
    let onDeactivate: () -> Void

    var body: some View {
        Button(action: onDeactivate) {
            RoundedRectangle(cornerRadius: 12)
                .fill(color)
                .frame(width: 52)   // matches the Loop circle it replaces, so the swap holds width
                .frame(maxHeight: .infinity)
                .overlay(
                    Image(systemName: "xmark.circle.fill")
                        .font(.futura(.title2))
                        .foregroundStyle(PocketColor.background)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Deactivate loop")
    }
}
