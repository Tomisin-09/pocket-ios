import SwiftUI

// Split out of `WaveformCanvas.swift` (file-length budget): the Fine + downbeat
// handle drawing, plus the playhead time bubble. Both handle helpers draw *in front*
// of the bars so the grab targets stay legible.

extension WaveformView {

    /// The A/B span handles (ADR 0041): a vertical bar + a knob badged **A** / **B** at
    /// each span edge, in the active (loop) colour so the whole A/B story shares one hue.
    /// Drawn in front of the bars (like the Fine handles) so the grab targets stay legible.
    func drawABHandles(in context: GraphicsContext, region: BarRegion, atX: (Double) -> CGFloat) {
        guard let abSelection else { return }
        drawABHandle(in: context, region: region, atX: atX(abSelection.start), label: "A")
        drawABHandle(in: context, region: region, atX: atX(abSelection.end), label: "B")
    }

    private func drawABHandle(in context: GraphicsContext, region: BarRegion,
                              atX handleX: CGFloat, label: String) {
        let bar = CGRect(x: handleX - 1.5, y: region.top, width: 3, height: region.height)
        context.fill(Path(bar), with: .color(PocketColor.active))
        let knob = CGRect(x: handleX - 7, y: region.midY - 9, width: 14, height: 18)
        context.fill(Path(roundedRect: knob, cornerRadius: 3), with: .color(PocketColor.active))
        context.draw(Text(label).font(.pocketMono(.caption2)).foregroundStyle(PocketColor.background),
                     at: CGPoint(x: handleX, y: region.midY))
    }

    // Loop lines stack upward from the bottom edge of the loop band. Capped at
    // `maxLanes` so deep nesting can't march up out of the band — anything deeper
    // clamps into the last lane.
    private static let maxLanes = 3
    private static let laneHeight: CGFloat = 7
    private static let bracketPadding: CGFloat = 3

    /// All saved loops as lane-stacked horizontal lines along the bottom border.
    /// Colour encodes loop **identity** (ADR 0023, superseding ADR 0018's
    /// colour-is-state rule); overlap is shown by lane. State is carried by weight
    /// and opacity instead — the active loop is heavier (2.5 pt, full opacity), the
    /// rest dimmed (1.5 pt, 0.8). A near-background halo lifts each line off the
    /// background.
    ///
    /// The dimmed opacity is deliberately high (not the ~0.5 you'd reach for): alpha
    /// blending toward a near-black canvas darkens far more aggressively than the same
    /// blend toward the light appearance's cream canvas (blending toward black multiplies
    /// luminance down; toward a light colour it doesn't), so a "medium" opacity that reads
    /// as a soft tint in light mode reads as a muddy near-black smear in dark mode (ADR
    /// 0062 follow-up — the same asymmetry that motivated the baked wash tokens, here
    /// applied to a live `Canvas` opacity instead of a colour set). The active loop is
    /// drawn last so it stays on top.
    func drawLoopLines(in context: GraphicsContext, size: CGSize,
                       atX: (Double) -> CGFloat) {
        guard !loops.isEmpty else { return }
        let packing = LoopLanes.pack(loops.map {
            LoopLanes.Interval(id: $0.uid, start: $0.start, end: $0.end)
        })

        func line(_ loop: Loop, isActive: Bool) {
            let startX = atX(loop.start)
            let endX = atX(loop.end)
            guard endX > 0, startX < size.width else { return }       // off-screen
            let lane = min(packing.lane(for: loop.uid), Self.maxLanes - 1)
            let baseY = size.height - Self.bracketPadding - CGFloat(lane) * Self.laneHeight

            var path = Path()
            path.move(to: CGPoint(x: max(0, startX), y: baseY))
            path.addLine(to: CGPoint(x: min(size.width, endX), y: baseY))
            let width: CGFloat = isActive ? 2.5 : 1.5
            // Contrast halo behind, then the loop's identity colour. Round caps.
            context.stroke(path, with: .color(PocketColor.background.opacity(0.55)),
                           style: StrokeStyle(lineWidth: width + 1.5, lineCap: .round))
            context.stroke(path, with: .color(loopColor(for: loop).opacity(isActive ? 1.0 : 0.8)),
                           style: StrokeStyle(lineWidth: width, lineCap: .round))
        }

        let activeUID = loop?.uid
        for loop in loops where loop.uid != activeUID { line(loop, isActive: false) }
        if let active = loop, loops.contains(where: { $0.uid == active.uid }) {
            line(active, isActive: true)
        }
    }

    /// All saved markers as purple inverted triangles along the top border, apex pointing
    /// down at the position (ADR 0023 — replaces the stem+dot pin). A near-background halo
    /// keeps the triangle crisp; a short tick drops from the apex to pin the exact spot.
    /// Moved here from `WaveformCanvas.swift` for the file-length budget (ADR 0041 follow-up).
    func drawMarkerTriangles(in context: GraphicsContext, size: CGSize, atX: (Double) -> CGFloat) {
        let halfWidth: CGFloat = 3.5
        let triHeight: CGFloat = 6
        let apexY = Self.markerBand - 3        // apex sits just above the bars
        let topY = apexY - triHeight
        for fraction in markerFractions {
            let pinX = atX(fraction)
            guard pinX > -halfWidth, pinX < size.width + halfWidth else { continue }  // off-screen
            var triangle = Path()
            triangle.move(to: CGPoint(x: pinX - halfWidth, y: topY))
            triangle.addLine(to: CGPoint(x: pinX + halfWidth, y: topY))
            triangle.addLine(to: CGPoint(x: pinX, y: apexY))
            triangle.closeSubpath()
            // Halo outline behind, then the purple fill.
            context.stroke(triangle, with: .color(PocketColor.background.opacity(0.55)),
                           style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
            context.fill(triangle, with: .color(PocketColor.pin))
            // Precision tick from the apex into the bar region.
            var tick = Path()
            tick.move(to: CGPoint(x: pinX, y: apexY))
            tick.addLine(to: CGPoint(x: pinX, y: apexY + 3))
            context.stroke(tick, with: .color(PocketColor.pin.opacity(0.6)), lineWidth: 1)
        }
    }

    /// The draggable "set the 1" handle (ADR 0024): a high-contrast line — the app's
    /// draggable-handle colour (cf. Fine handles) — with a rounded "1" badge at the top
    /// so it reads as the bar-1 downbeat being positioned.
    func drawDownbeatHandle(in context: GraphicsContext, size: CGSize, atX handleX: CGFloat) {
        var stem = Path()
        stem.move(to: CGPoint(x: handleX, y: 0))
        stem.addLine(to: CGPoint(x: handleX, y: size.height))
        context.stroke(stem, with: .color(PocketColor.background.opacity(0.55)), lineWidth: 3.5)
        context.stroke(stem, with: .color(PocketColor.fine), lineWidth: 2)

        let badge = CGRect(x: handleX - 9, y: 0, width: 18, height: 16)
        context.fill(Path(roundedRect: badge, cornerRadius: 4), with: .color(PocketColor.fine))
        context.draw(Text("1").font(.pocketMono(.caption2)).foregroundStyle(PocketColor.background),
                     at: CGPoint(x: handleX, y: badge.midY))
    }
}

/// Small mono time readout pinned above the playhead (brief §3.2 — mono time).
struct TimeBubble: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.pocketMono(.caption2))
            .foregroundStyle(PocketColor.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(PocketColor.background.opacity(0.85))
                    .overlay(Capsule().strokeBorder(PocketColor.surfaceBorder, lineWidth: 1))
            )
    }
}
