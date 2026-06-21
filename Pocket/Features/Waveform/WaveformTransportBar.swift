import SwiftUI

// Section 8 of the waveform practice screen (design brief §4.1) — the pinned
// transport row + capture action bar. Split out of `WaveformSections.swift` to
// keep each file under the line budget; shares the same `panelBackground` chrome.

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

            // Action bar — capture at the playhead + the precise-edit toggle. Click moved
            // to the speed bar (tempo context, ADR 0027); the `A`utomator slot is per-loop.
            HStack(spacing: 8) {
                ActionButton(icon: "repeat", label: "Loop", tint: PocketColor.active,
                             isActive: isPunchActive, action: onPunch)
                // Inverted triangle to match the markers' shape on the waveform (ADR 0023).
                ActionButton(icon: "arrowtriangle.down.fill", label: "Mark",
                             tint: PocketColor.pin, action: onDropMarker)
                // Calipers — "drag the edges" — for Fine bound-editing (ADR 0027); the old
                // sliders glyph read as generic settings, not edge handles.
                ActionButton(icon: "arrow.left.and.right", label: "Fine", tint: PocketColor.fine,
                             isActive: mode == .fine) { mode = (mode == .fine ? .navigate : .fine) }
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
