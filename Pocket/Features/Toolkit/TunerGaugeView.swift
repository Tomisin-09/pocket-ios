import SwiftUI

/// The tuner's **arc-needle gauge** (ADR 0115) — the instantly-legible tuner idiom. A fan of tick
/// marks from −50 to +50 cents with a green centre (the in-tune target); the needle pivots from the
/// bottom, pointing straight up at 0 cents and swinging ±`sweep`° toward flat (left) / sharp (right).
///
/// Purely a readout of `cents`; it measures nothing (ADR 0070). Dimmed while idle (no reading) so a
/// centred needle on silence doesn't read as "perfectly in tune".
struct TunerGaugeView: View {
    /// Deviation from the target note, −50…+50 cents (0 when idle).
    let cents: Double
    /// Whether the current reading is inside the in-tune tolerance — greens the needle.
    let isInTune: Bool
    /// Whether a confident reading is present — the needle is dimmed when not.
    let isActive: Bool

    /// Degrees the needle sweeps to each side (±50 cents maps to ±`sweep`°).
    private let sweep: Double = 60

    private var angle: Double { (max(-50, min(50, cents)) / 50) * sweep }

    private var needleColor: Color {
        if !isActive { return PocketColor.textSecondary.opacity(0.35) }
        return isInTune ? PocketColor.active : PocketColor.toolkit
    }

    var body: some View {
        GeometryReader { geometry in
            let radius = min(geometry.size.width / 2, geometry.size.height) - 6
            ZStack(alignment: .bottom) {
                Canvas { context, size in drawTicks(context, size: size) }
                Capsule()
                    .fill(needleColor)
                    .frame(width: 4, height: radius)
                    .rotationEffect(.degrees(angle), anchor: .bottom)
                    .animation(.easeOut(duration: 0.12), value: angle)
                Circle()
                    .fill(PocketColor.textPrimary)
                    .frame(width: 13, height: 13)
                    .offset(y: 6)
            }
        }
        .frame(height: 150)
        .accessibilityElement()
        .accessibilityLabel("Tuning gauge")
        .accessibilityValue(isActive ? "\(Int(cents.rounded())) cents" : "listening")
    }

    /// Draw the tick fan into `context`, pivoting from the bottom-centre. Major ticks every 30°; the
    /// centre tick is green (the in-tune target).
    private func drawTicks(_ context: GraphicsContext, size: CGSize) {
        let pivot = CGPoint(x: size.width / 2, y: size.height)
        let outer = min(size.width / 2, size.height) - 4
        for degrees in stride(from: -sweep, through: sweep, by: 10) {
            let isMajor = Int(degrees) % 30 == 0
            let inner = outer - (isMajor ? 16 : 9)
            let radians = degrees * .pi / 180
            let direction = CGVector(dx: sin(radians), dy: -cos(radians))
            let start = CGPoint(x: pivot.x + direction.dx * outer, y: pivot.y + direction.dy * outer)
            let end = CGPoint(x: pivot.x + direction.dx * inner, y: pivot.y + direction.dy * inner)
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            let color = degrees == 0 ? PocketColor.active : PocketColor.textSecondary.opacity(0.5)
            context.stroke(path, with: .color(color), lineWidth: isMajor ? 2.5 : 1.5)
        }
    }
}

#Preview("Gauge states") {
    VStack(spacing: 30) {
        TunerGaugeView(cents: -32, isInTune: false, isActive: true)
        TunerGaugeView(cents: 0, isInTune: true, isActive: true)
        TunerGaugeView(cents: 0, isInTune: false, isActive: false)
    }
    .padding()
    .background(PocketColor.background)
    .preferredColorScheme(.dark)
}
