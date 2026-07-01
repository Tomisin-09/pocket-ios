import SwiftUI

// MARK: - 7. Minimap (full song, compressed)

/// The full-song overview strip (brief §4.1, item 7): a compressed track with the
/// saved loops drawn in their **identity colours** (matching the detail waveform,
/// ADR 0023), the active loop's region washed in its own hue, the Fine selection
/// (blue), marker dots (purple), the live playhead, and — when the detail waveform
/// is zoomed — a **viewport box** showing which slice is on screen. Tap or drag
/// anywhere to move the playhead.
struct Minimap: View {
    let song: Song
    let activeLoop: Loop?
    /// The whole-song envelope (0…1), drawn as a compressed silhouette so the strip
    /// reads as a *map* of the song's shape, not a featureless bar. Empty while the
    /// waveform is still extracting → falls back to a flat track.
    let samples: [Double]
    let markers: [Marker]
    /// Fine-mode selection mirrored from the detail waveform (blue).
    let fineSelection: (start: Double, end: Double)?
    /// Live playhead position (0...1), driven by the audio engine.
    let playheadFraction: Double
    /// The detail waveform's zoom window — drawn as the viewport box when zoomed in.
    let viewport: (start: Double, end: Double)
    /// Tap or drag anywhere on the minimap to move the playhead. Fired continuously
    /// (un-snapped) so the scrub tracks the finger.
    let onSeek: (Double) -> Void
    /// Drag *release* — lets the caller snap the final position to a nearby marker.
    let onSeekEnded: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            canvas
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            onSeek(WaveformGesture.fraction(atX: value.location.x, width: geo.size.width))
                        }
                        .onEnded { value in
                            onSeekEnded(WaveformGesture.fraction(atX: value.location.x, width: geo.size.width))
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

    /// The identity colour for a loop (ADR 0023) — shared via `LoopColor`, the same
    /// hue the detail waveform and transport strip use, so a loop reads as one colour
    /// everywhere.
    private func loopColor(for loop: Loop) -> Color { LoopColor.color(for: loop, among: song.loopsByStart) }

    /// The active-loop region wash plus every saved loop's identity-coloured underline
    /// (ADR 0023). Colour encodes loop **identity** (matching the detail waveform); state
    /// is carried by weight + opacity — the active loop heavier (2 pt, full) and drawn
    /// last, the rest dimmed (1.5 pt, 0.55). Overlaps stack into at most two lanes;
    /// deeper nesting clamps into the last lane.
    private func drawLoops(in context: GraphicsContext, size: CGSize) {
        // Active loop region — washed in its own identity colour, the prominent one.
        if let loop = activeLoop {
            let startX = size.width * loop.start
            let rect = CGRect(x: startX, y: 0, width: size.width * (loop.end - loop.start), height: size.height)
            context.fill(Path(roundedRect: rect, cornerRadius: 2),
                         with: .color(loopColor(for: loop).opacity(0.5)))
        }

        let allLoops = song.loopsByStart
        guard !allLoops.isEmpty else { return }
        let packing = LoopLanes.pack(allLoops.map {
            LoopLanes.Interval(id: $0.uid, start: $0.start, end: $0.end)
        })
        let maxLanes = 2
        func underline(_ loop: Loop, isActive: Bool) {
            let lane = min(packing.lane(for: loop.uid), maxLanes - 1)
            let lineY = size.height - 1.5 - CGFloat(lane) * 3
            var line = Path()
            line.move(to: CGPoint(x: size.width * loop.start, y: lineY))
            line.addLine(to: CGPoint(x: size.width * loop.end, y: lineY))
            context.stroke(line, with: .color(loopColor(for: loop).opacity(isActive ? 1.0 : 0.55)),
                           lineWidth: isActive ? 2 : 1.5)
        }
        let activeUID = activeLoop?.uid
        for loop in allLoops where loop.uid != activeUID { underline(loop, isActive: false) }
        if let active = activeLoop, allLoops.contains(where: { $0.uid == active.uid }) {
            underline(active, isActive: true)   // drawn last → stays on top
        }
    }

    /// The compressed whole-song silhouette that replaces the old flat base track: a
    /// mirrored envelope through the same display gamma the detail waveform uses
    /// (`WaveformAmplitude`, ADR 0049), so the strip reads as a fuller, calmer *map* of
    /// the song's shape. Falls back to a flat pill until the envelope is extracted.
    private func drawTrack(in context: GraphicsContext, size: CGSize) {
        guard samples.count > 1 else {
            let base = CGRect(x: 0, y: size.height * 0.35, width: size.width, height: size.height * 0.3)
            context.fill(Path(roundedRect: base, cornerRadius: 2), with: .color(PocketColor.barPlayed))
            return
        }
        let midY = size.height / 2
        let maxHalf = size.height * 0.44          // leaves a hair of padding top/bottom
        let lastIndex = Double(samples.count - 1)
        func point(_ index: Int, mirrored: Bool) -> CGPoint {
            let xPos = size.width * CGFloat(Double(index) / lastIndex)
            let height = CGFloat(WaveformAmplitude.display(samples[index])) * maxHalf
            return CGPoint(x: xPos, y: mirrored ? midY + height : midY - height)
        }
        var path = Path()
        path.move(to: CGPoint(x: 0, y: midY))
        for index in samples.indices { path.addLine(to: point(index, mirrored: false)) }        // top contour
        for index in samples.indices.reversed() { path.addLine(to: point(index, mirrored: true)) } // bottom mirror
        path.closeSubpath()
        context.fill(path, with: .color(PocketColor.barPlayed))
    }

    private var canvas: some View {
        Canvas { context, size in
            // Whole-song silhouette (was a flat base track).
            drawTrack(in: context, size: size)

            // Active loop region wash + every saved loop's identity-coloured underline.
            // Kept in an instance method (like `WaveformCanvas.drawLoopLines`) so the
            // main-actor `loopColor(for:)` isn't called straight from the Canvas closure.
            drawLoops(in: context, size: size)

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
