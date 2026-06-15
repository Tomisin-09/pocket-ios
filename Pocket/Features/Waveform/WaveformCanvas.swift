import SwiftUI

// The custom-drawn parts of the waveform practice screen (brief §4.1, items 5
// and 7). Kept separate from the declarative layout sections because this is
// imperative Canvas drawing — a different category of code.

// MARK: - 5. Waveform — SoundCloud-style mirrored bars

struct WaveformView: View {
    let amplitudes: [Double]
    let playheadFraction: Double
    let loop: WaveformMock.Loop?

    var body: some View {
        Canvas { context, size in
            guard !amplitudes.isEmpty else { return }
            let count = amplitudes.count
            let barSpacing: CGFloat = 1
            let barWidth = max(1, (size.width - CGFloat(count - 1) * barSpacing) / CGFloat(count))
            let midY = size.height / 2
            let playheadX = size.width * playheadFraction

            // Loop region (amber while paused — green is reserved for playing).
            if let loop {
                let startX = size.width * loop.start
                let endX = size.width * loop.end
                let rect = CGRect(x: startX, y: 0, width: endX - startX, height: size.height)
                context.fill(Path(rect), with: .color(PocketColor.marker.opacity(0.14)))
            }

            for (index, amp) in amplitudes.enumerated() {
                let barX = CGFloat(index) * (barWidth + barSpacing)
                let played = barX <= playheadX
                let color = played ? PocketColor.barPlayed : PocketColor.barDefault
                let topHeight = CGFloat(amp) * midY
                let top = CGRect(x: barX, y: midY - topHeight, width: barWidth, height: topHeight)
                // Reflection at ~60% — brief §4.1.
                let bottom = CGRect(x: barX, y: midY, width: barWidth, height: topHeight * 0.6)
                context.fill(Path(top), with: .color(color))
                context.fill(Path(bottom), with: .color(color.opacity(0.6)))
            }

            // Playhead.
            var line = Path()
            line.move(to: CGPoint(x: playheadX, y: 0))
            line.addLine(to: CGPoint(x: playheadX, y: size.height))
            context.stroke(line, with: .color(PocketColor.textPrimary.opacity(0.8)), lineWidth: 1.5)
        }
        .frame(height: 140)
        .accessibilityHidden(true)
    }
}

// MARK: - 7. Minimap (full song, compressed)

struct Minimap: View {
    let song: WaveformMock.Song
    let activeLoop: WaveformMock.Loop?
    let markers: [WaveformMock.Marker]
    /// Live playhead position (0...1), driven by the audio engine.
    let playheadFraction: Double

    var body: some View {
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

            // Marker dots (purple).
            for marker in markers {
                let markerX = size.width * (marker.seconds / song.duration)
                let dot = CGRect(x: markerX - 2, y: size.height / 2 - 2, width: 4, height: 4)
                context.fill(Path(ellipseIn: dot), with: .color(PocketColor.pin))
            }

            // Viewport indicator (the slice the detail waveform is showing).
            let viewportRect = CGRect(x: size.width * song.viewport.start, y: 0,
                                      width: size.width * (song.viewport.end - song.viewport.start),
                                      height: size.height)
            context.stroke(Path(roundedRect: viewportRect, cornerRadius: 3),
                           with: .color(PocketColor.textPrimary.opacity(0.5)), lineWidth: 1)

            // Playhead.
            let playheadX = size.width * playheadFraction
            var line = Path()
            line.move(to: CGPoint(x: playheadX, y: 0))
            line.addLine(to: CGPoint(x: playheadX, y: size.height))
            context.stroke(line, with: .color(PocketColor.textPrimary.opacity(0.8)), lineWidth: 1)
        }
        .frame(height: 36)
        .accessibilityHidden(true)
    }
}
