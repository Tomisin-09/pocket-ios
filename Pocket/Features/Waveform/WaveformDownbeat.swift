import SwiftUI

// Split out of `WaveformCanvas.swift` (file-length budget): the Fine + downbeat
// handle drawing, plus the playhead time bubble. Both handle helpers draw *in front*
// of the bars so the grab targets stay legible.

extension WaveformView {

    /// The two Fine-mode selection handles (ADR 0023): a thin vertical bar plus a rounded
    /// knob at each selection edge, in the high-contrast `fine` colour. Drawn after the
    /// bars so they read in front instead of being occluded.
    func drawFineHandles(in context: GraphicsContext, region: BarRegion, atX: (Double) -> CGFloat) {
        guard let fineSelection else { return }
        for handleX in [atX(fineSelection.start), atX(fineSelection.end)] {
            let bar = CGRect(x: handleX - 1.5, y: region.top, width: 3, height: region.height)
            context.fill(Path(bar), with: .color(PocketColor.fine))
            let knob = CGRect(x: handleX - 5, y: region.midY - 9, width: 10, height: 18)
            context.fill(Path(roundedRect: knob, cornerRadius: 3), with: .color(PocketColor.fine))
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
