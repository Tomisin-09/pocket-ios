import SwiftUI

// Section 8 of the waveform practice screen (design brief §4.1) — the pinned
// transport row. Split out of `WaveformSections.swift` to keep each file under the
// line budget; shares the same `panelBackground` chrome.
//
// Layout (ADR 0030; ADR 0041; V1 feedback #1): two states.
// • **Idle** (no active loop): two large **circular** identity controls flank the centre transport —
//   **Marker on the far left**, **Loop on the far right** — a glyph in a circle. The Loop button
//   lights while an A/B span is forming.
// • **Active** (a saved loop is running): the bar reverts to its **compact** form — **Snag** on the
//   left and the loop's identity-colour ✕ strip on the right — because the running loop now reads
//   on the Loops panel below, so the bar steps back out of the way (feedback #1 round 2).
//
// The armed state used to carry a stacked Loop / Marker column here. Both went in ADR 0200, and
// neither was a trim for space: **Loop disarmed the loop you were working** — `tapAB()` sets
// `activeLoopID = nil` and calls `engine.clearLoop()`, the exact trapdoor ADR 0192 D2 had just
// closed on the skip buttons — and **Marker was doing Snag's job quietly at 27pt**, unlabelled and
// song-scoped. One control replaces two, and the state that has your hands busiest gained the one
// gesture you can make without looking. Idle keeps both big identity circles untouched: that is
// where loops are *created*, and there both controls earn their place.
// The centre cluster is the header over skip · pause · skip; the header reserves a fixed height
// and reads the loop's name when active, else stays empty — the live playhead time renders as the
// `TimeBubble` on the waveform canvas, so the redundant idle timecode was dropped (ADR 0075).
//
// The centre glyphs do **not** change with those states (ADR 0192): they are **−N / +N second
// skips** in circular-arrow glyphs in both, holding either to change the increment. What the armed
// loop changes is the scope — the caller clamps the skip to the loop region rather than the song —
// so one gesture keeps one meaning. Rewind's single-tap "restart" and the loop-to-loop steps are
// given up: moving freely inside what is playing is the thing you do constantly, restarting is a
// tap on the start of the region, and the Loops panel below is where loops are chosen.

// MARK: - 8. Transport bar

struct TransportBar: View {
    let isPlaying: Bool
    let onPlayPause: () -> Void
    /// Seek by a signed number of seconds — the skip buttons, in both states (ADR 0124, ADR 0192).
    /// The caller clamps to whatever is armed. Defaulted to a no-op for previews and standalone use.
    var onSkip: (TimeInterval) -> Void = { _ in }

    let loop: Loop?
    /// The active loop's identity colour, for the right strip. `nil` ⇒ no active loop.
    let loopColor: Color?
    /// Deactivate the active loop (the ✕ on the colour strip).
    let onClearLoop: () -> Void
    /// Mark control — drop a marker at the playhead (idle only).
    let onDropMarker: () -> Void
    /// Snag control — mark the playhead as a place it went wrong (ADR 0200; armed only).
    var onDropSnag: () -> Void = {}
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
    /// How far the skip buttons move, in seconds (ADR 0124). Lives here rather than on the
    /// model because it's a standing habit, not per-song state — the same reasoning as `loopOnLeft`.
    @AppStorage(AppSettings.Key.transportSkipSeconds) private var skipSeconds = Int(TransportSkip.defaultIncrement)

    private var glyphSize: CGFloat { compact ? 24 : 25 }
    /// The armed-state Snag button. Bigger than the 27pt dots it replaces — it is now the only
    /// control in the slot, and it has to be hittable without looking at the screen.
    private var snagDiameter: CGFloat { compact ? 34 : 38 }
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
            SnagControl(diameter: snagDiameter, action: onDropSnag)
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

    /// One row, both states (ADR 0192) — the skip pair either side of play/pause. The armed loop
    /// changes what a skip is clamped to, not what the buttons are.
    private var transportRow: some View {
        HStack(spacing: compact ? 32 : 40) {
            skipButton(forward: false)
            TransportGlyph(icon: isPlaying ? "pause.fill" : "play.fill",
                           label: isPlaying ? "Pause" : "Play", size: glyphSize, action: onPlayPause)
            skipButton(forward: true)
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

/// The **Snag** control (ADR 0200) — the armed transport's left slot.
///
/// Same chrome as `TransportControl` (a glyph in a circle on a faint fill), but the glyph is drawn
/// rather than named: `SnagCatch` exists because every SF Symbol that fits is either a warning
/// sign, a report flag, or a heartbeat. See that type for the argument.
///
/// **Crimson**, the Oracle's hue, because a snag's second life is being read back in a reading —
/// the mark and the thing that reads it look related, which they are. The tone risk is real and was
/// taken deliberately: a red mark on your own playing can read as a grade. What settles it is that
/// the player put it there. ADR 0070 forbids *the app* judging, not the player noticing.
private struct SnagControl: View {
    var diameter: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SnagCatch()
                .stroke(PocketColor.oracle,
                        style: StrokeStyle(lineWidth: diameter * 0.055, lineCap: .round, lineJoin: .round))
                .frame(width: diameter * 0.62, height: diameter * 0.62)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(PocketColor.surfaceStandard))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Snag")
        .accessibilityHint("Mark this spot as one that went wrong")
    }
}

/// A background-free transport glyph (skip / play / pause). No pill behind it. Nothing here dims:
/// every glyph in the row is live in both states now (ADR 0192), so the disabled variant the
/// loop-navigation buttons needed went with them.
private struct TransportGlyph: View {
    let icon: String
    let label: String
    var size: CGFloat = transportGlyphSize
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.futura(size: size, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
