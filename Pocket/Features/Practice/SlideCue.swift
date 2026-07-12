import SwiftUI

/// The **slide-teaching cue** (ADR 0083 S8). A shift that walks the hand up (or down) one string is a
/// genuine slide — the *point* of a position-shifting run, drawn in the reference diagrams as an
/// arrow, not a dot. So a `.slide` note can't just blink on at the new fret: this draws a short
/// tapering line with an arrowhead from the fret the finger left to the fret it slides into, along
/// the string row, conveying the *motion* along the string.
///
/// It is deliberately **static** — always drawn, so it teaches the shape at rest and reads as the
/// "slide" articulation badge when the walking highlight is off (Reduce Motion / animate-off, ADR
/// 0065 T5/0077). The renderer brightens it while its target note is the active one, so under motion
/// the travelling highlight and the arrow read together. A single travelling-highlight treatment is
/// the S8 open question; this is the slice-1 answer and is shared with the movable-chord slide slice.
struct SlideCue: Shape {
    /// The centre x of the fret the slide starts from and the fret it lands on, and the string row's y.
    var fromX: CGFloat
    var toX: CGFloat
    var midY: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = CGPoint(x: fromX, y: midY)
        let end = CGPoint(x: toX, y: midY)
        path.move(to: start)
        path.addLine(to: end)
        // A small arrowhead at the destination, pointing in the direction of travel.
        let head: CGFloat = 5
        let direction: CGFloat = toX >= fromX ? -1 : 1   // barbs trail back toward the start
        path.move(to: end)
        path.addLine(to: CGPoint(x: end.x + direction * head, y: end.y - head * 0.7))
        path.move(to: end)
        path.addLine(to: CGPoint(x: end.x + direction * head, y: end.y + head * 0.7))
        return path
    }
}
