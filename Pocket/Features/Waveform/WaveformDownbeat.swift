import SwiftUI

// Split out of `WaveformCanvas.swift` (file-length budget): the downbeat-handle
// drawing for "set the 1" (ADR 0024), plus the playhead time bubble. Both are small
// Canvas/overlay pieces that don't need to sit in the main draw routine.

extension WaveformView {

    /// The draggable "set the 1" handle (ADR 0024): a bright cyan line — the app's
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
