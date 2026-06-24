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

    /// Grabbable edge handles on the **active loop** (ADR 0041): a knob in the loop's
    /// identity colour at each edge, signalling you can drag it to range-edit (the drag
    /// lifts it into the A/B span). Shown only when the loop is the sole live selection —
    /// no A/B span, forming region, or downbeat placement competing for the edges.
    func drawLoopEditHandles(in context: GraphicsContext, region: BarRegion,
                             atX: (Double) -> CGFloat, loop: Loop, color: Color) {
        guard abSelection == nil, tapSelection == nil,
              formingStart == nil, downbeatDraft == nil else { return }
        for edgeX in [atX(loop.start), atX(loop.end)] {
            let knob = CGRect(x: edgeX - 5, y: region.midY - 8, width: 10, height: 16)
            context.fill(Path(roundedRect: knob, cornerRadius: 3),
                         with: .color(PocketColor.background.opacity(0.5)))   // contrast halo
            context.fill(Path(roundedRect: knob.insetBy(dx: 1, dy: 1), cornerRadius: 2.5),
                         with: .color(color))
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
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
            )
    }
}
