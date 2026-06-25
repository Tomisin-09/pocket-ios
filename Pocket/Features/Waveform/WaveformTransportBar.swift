import SwiftUI

// Section 8 of the waveform practice screen (design brief §4.1) — the pinned
// transport row. Split out of `WaveformSections.swift` to keep each file under the
// line budget; shares the same `panelBackground` chrome.
//
// Layout (ADR 0030; ADR 0041): a left column of two identity controls (Loop / Marker —
// a glyph in a circle that fills with the control's colour when active), a centre
// cluster (header over rewind · pause · forward), and — only while a loop is active —
// a right strip in the loop's identity colour carrying the ✕ deactivator. The header
// reserves a fixed height and reads the loop's name + range when active, else the live
// playhead time, at a matched font size so the two states cross-fade smoothly and the
// transport row never shifts; the colour strip slides in/out as a loop is (de)activated.

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

    let currentTime: TimeInterval
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

    private var glyphSize: CGFloat { compact ? 24 : 26 }

    var body: some View {
        HStack(spacing: 12) {
            controls
            VStack(spacing: compact ? 2 : 5) {
                header
                transportRow
            }
            .frame(maxWidth: .infinity)
            if let loopColor {
                LoopColorStrip(color: loopColor, onDeactivate: onClearLoop)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(height: compact ? 52 : 64)  // definite bar height so the colour strip reliably fills it
        .padding(.horizontal, 12)
        .padding(.vertical, compact ? 3 : 5)
        .background(panelBackground)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: loop?.uid)
    }

    // MARK: Left — identity controls (glyph in a circle)

    private var controls: some View {
        VStack(spacing: 0) {
            TransportControl(icon: "repeat", color: PocketColor.active,
                             isActive: isPunchActive, label: "Loop", action: onPunch)
            Spacer(minLength: 0)
            // Equilateral triangle, rotated to point down — matches the inverted marker
            // glyph on the waveform (the arrowtriangle variant read as elongated).
            TransportControl(icon: "triangle.fill", rotation: 180, color: PocketColor.pin,
                             label: "Marker", action: onDropMarker)
        }
    }

    // MARK: Centre — header + transport

    @ViewBuilder private var header: some View {
        Group {
            if let loop {
                // Just the loop name — the range lives in the loop row / waveform, and
                // dropping it here keeps the header one line so the transport breathes.
                Text(loop.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(PocketColor.textPrimary)
                    .lineLimit(1)
                    .accessibilityLabel("Looping \(loop.name)")
            } else {
                Text(timecode(currentTime))
                    .font(.pocketMono(.body))
                    .foregroundStyle(PocketColor.textPrimary)
                    .accessibilityLabel("Playback position \(timecode(currentTime))")
            }
        }
        .frame(height: 22)        // single-line header height, matched across both states
        .transition(.opacity)
    }

    private var transportRow: some View {
        HStack(spacing: compact ? 32 : 40) {
            RewindButton(onRestart: onRestart, onPrevious: onPrevious,
                         hasPrevious: hasPrevious, size: glyphSize)
            TransportGlyph(icon: isPlaying ? "pause.fill" : "play.fill",
                           label: isPlaying ? "Pause" : "Play", size: glyphSize, action: onPlayPause)
            TransportGlyph(icon: "forward.fill", label: "Next loop",
                           isEnabled: hasNext, size: glyphSize, action: onNext)
        }
    }
}

// MARK: - Components

private let transportGlyphSize: CGFloat = 31
private let controlDiameter: CGFloat = 27

/// One identity control in the left column — a glyph in a circle. Idle: the glyph in
/// its colour on a faint fill. Active: the circle fills with the colour, glyph flips
/// dark (Loop while a span is in play).
private struct TransportControl: View {
    let icon: String
    var rotation: Double = 0
    let color: Color
    var isActive: Bool = false
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .rotationEffect(.degrees(rotation))
                .foregroundStyle(isActive ? PocketColor.background : color)
                .frame(width: controlDiameter, height: controlDiameter)
                .background(Circle().fill(isActive ? color : Color.white.opacity(0.10)))
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
                .font(.system(size: size, weight: .semibold))
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
            .font(.system(size: size, weight: .semibold))
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
                .frame(width: 46)
                .frame(maxHeight: .infinity)
                .overlay(
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(PocketColor.background)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Deactivate loop")
    }
}
