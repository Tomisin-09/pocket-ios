import SwiftUI

/// The snag glyph (ADR 0200) — a line running along that catches on one point.
///
/// **Why not an SF Symbol.** The obvious candidates all say the wrong thing. `exclamationmark`
/// is a warning sign pointed at the player's own playing, which is the app taking a view and the
/// line ADR 0070 exists to hold. `flag` carries a report-this connotation from every other app,
/// and its filled triangle sits next to the Marker glyph it replaces in the armed transport.
/// `waveform.path.ecg` is visually right and semantically medical.
///
/// So the glyph is drawn: it depicts *what happened* — the run of notes, and the one place it
/// snagged — rather than passing judgement on it. That is the same distinction that makes "snag"
/// a better word than "mistake": a snag is a catch in the fabric, not a failure.
///
/// Drawn on a 24-unit grid and scaled, so it lines up with the SF Symbols either side of it in
/// the transport row.
struct SnagCatch: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = Swift.min(rect.width, rect.height) / 24
        let originX = rect.midX - 12 * scale
        let originY = rect.midY - 12 * scale
        func point(_ pointX: CGFloat, _ pointY: CGFloat) -> CGPoint {
            CGPoint(x: originX + pointX * scale, y: originY + pointY * scale)
        }

        var path = Path()
        path.move(to: point(2, 16))
        path.addLine(to: point(7, 16))
        path.addCurve(to: point(12, 8), control1: point(9.6, 16), control2: point(9.4, 8))
        path.addCurve(to: point(17, 16), control1: point(14.6, 8), control2: point(14.4, 16))
        path.addLine(to: point(22, 16))
        return path
    }
}
