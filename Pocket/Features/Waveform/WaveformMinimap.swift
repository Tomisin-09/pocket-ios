import SwiftUI

// MARK: - 7. Minimap (full song, compressed)

/// The full-song overview strip (brief §4.1, item 7): a compressed track with the
/// active loop (amber), Fine selection (blue), marker dots (purple), the live
/// playhead, and — when the detail waveform is zoomed — a **viewport box** showing
/// which slice is on screen. Tap or drag anywhere to move the playhead.
struct Minimap: View {
    let song: WaveformMock.Song
    let activeLoop: WaveformMock.Loop?
    let markers: [WaveformMock.Marker]
    /// Fine-mode selection mirrored from the detail waveform (blue).
    let fineSelection: (start: Double, end: Double)?
    /// Live playhead position (0...1), driven by the audio engine.
    let playheadFraction: Double
    /// The detail waveform's zoom window — drawn as the viewport box when zoomed in.
    let viewport: (start: Double, end: Double)
    /// Tap or drag anywhere on the minimap to move the playhead.
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            canvas
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { value in
                        onSeek(WaveformGesture.fraction(atX: value.location.x, width: geo.size.width))
                    }
                )
        }
        .frame(height: 28)
        .accessibilityElement()
        .accessibilityLabel("Song position")
        .accessibilityValue("\(Int((playheadFraction * 100).rounded()))%")
        .accessibilityHint("Adjust to move the playhead")
        .accessibilityAdjustableAction { direction in
            let step = 0.05
            switch direction {
            case .increment: onSeek(min(1, playheadFraction + step))
            case .decrement: onSeek(max(0, playheadFraction - step))
            @unknown default: break
            }
        }
    }

    private var canvas: some View {
        Canvas { context, size in
            // Base track.
            let base = CGRect(x: 0, y: size.height * 0.35, width: size.width, height: size.height * 0.3)
            context.fill(Path(roundedRect: base, cornerRadius: 2),
                         with: .color(PocketColor.barPlayed))

            // Loop region (amber).
            if let loop = activeLoop {
                let startX = size.width * loop.start
                let rect = CGRect(x: startX, y: 0, width: size.width * (loop.end - loop.start), height: size.height)
                context.fill(Path(roundedRect: rect, cornerRadius: 2),
                             with: .color(PocketColor.marker.opacity(0.5)))
            }

            // Fine selection (blue) — brief §4.1 minimap.
            if let fineSelection {
                let startX = size.width * fineSelection.start
                let rect = CGRect(x: startX, y: 0,
                                  width: size.width * (fineSelection.end - fineSelection.start),
                                  height: size.height)
                context.fill(Path(roundedRect: rect, cornerRadius: 2),
                             with: .color(PocketColor.fine.opacity(0.5)))
            }

            // Marker dots (purple).
            for marker in markers {
                let markerX = size.width * (marker.seconds / song.duration)
                let dot = CGRect(x: markerX - 2, y: size.height / 2 - 2, width: 4, height: 4)
                context.fill(Path(ellipseIn: dot), with: .color(PocketColor.pin))
            }

            // Viewport box — the slice the detail waveform is zoomed into. Only
            // drawn when actually zoomed (a full-song box would be the whole width).
            if viewport.end - viewport.start < 0.999 {
                let startX = size.width * viewport.start
                let rect = CGRect(x: startX, y: 0,
                                  width: size.width * (viewport.end - viewport.start), height: size.height)
                context.stroke(Path(roundedRect: rect, cornerRadius: 3),
                               with: .color(PocketColor.textPrimary.opacity(0.5)), lineWidth: 1)
            }

            // Playhead.
            let playheadX = size.width * playheadFraction
            var line = Path()
            line.move(to: CGPoint(x: playheadX, y: 0))
            line.addLine(to: CGPoint(x: playheadX, y: size.height))
            context.stroke(line, with: .color(PocketColor.textPrimary.opacity(0.8)), lineWidth: 1)
        }
    }
}
