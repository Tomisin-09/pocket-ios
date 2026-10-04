import SwiftUI

/// The **hammer-on / pull-off cue** on the walking board (ADR 0251). A Legato drill's joins are drawn the
/// way Name the notes draws them (ADR 0227 D5, `NeckMarksLayer`): a curve under the string from the fret
/// the finger left to the fret it lands on, with *h* or *p* in a ring at the bottom of the curve. The
/// letters are `JoinDirection.symbol(for: .legato)`, so the board and the tab spell a join the same way.
///
/// Drawn as the walk trail, like a slide seam (2026-07-28): only on the step being played, when "hammer
/// this one" is the instruction that applies. The board stays clean at rest, and the joins still read
/// per note in the accessibility summary.
struct LegatoCue: View {
    let technique: FretTechnique
    /// The centre x of the fret the finger leaves and the fret it lands on.
    let fromX: CGFloat
    let toX: CGFloat
    /// The string row's y.
    let stringY: CGFloat
    var tint: Color = PocketColor.practice

    /// Where the curve leaves the string: just under the line, so the dots at each end cover its ends.
    private static let drop: CGFloat = 4
    /// How far below the string the curve's lowest point sits — small enough that the bottom string's
    /// ring stays clear of the fret numbers under the board. At 12 a join across two frets (6→8) put its
    /// ring on the "7" beneath it, since the middle of an even span lands on a fret's column.
    private static let depth: CGFloat = 10
    private static let ring: CGFloat = 10

    /// The letter for a join, or `nil` for a technique that isn't one. `nonisolated` so a plain test can
    /// read it on CI's Swift 6, where a View's statics are main-actor.
    nonisolated static func letter(for technique: FretTechnique) -> String? {
        switch technique {
        case .hammerOn: JoinDirection.upward.symbol(for: .legato)
        case .pullOff: JoinDirection.downward.symbol(for: .legato)
        case .pick, .slide: nil
        }
    }

    var body: some View {
        if let letter = Self.letter(for: technique) {
            ZStack {
                Arc(fromX: fromX, toX: toX, stringY: stringY, drop: Self.drop, depth: Self.depth)
                    .stroke(tint.opacity(0.95), style: StrokeStyle(lineWidth: 1.75, lineCap: .round))
                Text(letter)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(tint)
                    .frame(width: Self.ring, height: Self.ring)
                    .background(Circle().fill(PocketColor.background))
                    .overlay(Circle().stroke(tint, lineWidth: 1))
                    .position(x: (fromX + toX) / 2, y: stringY + Self.depth)
            }
        }
    }

    /// The curve itself: a quadratic from just under the string at each fret, through `depth` below it
    /// halfway between.
    private struct Arc: Shape {
        let fromX: CGFloat
        let toX: CGFloat
        let stringY: CGFloat
        let drop: CGFloat
        let depth: CGFloat

        func path(in rect: CGRect) -> Path {
            var path = Path()
            let top = stringY + drop
            path.move(to: CGPoint(x: fromX, y: top))
            // A quadratic's lowest point is halfway to its control, so the control sits twice as far down.
            path.addQuadCurve(to: CGPoint(x: toX, y: top),
                              control: CGPoint(x: (fromX + toX) / 2, y: top + 2 * (depth - drop)))
            return path
        }
    }
}
