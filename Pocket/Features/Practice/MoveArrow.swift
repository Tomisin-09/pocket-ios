import SwiftUI

/// The **move cue** on a walking board (2026-11-21, replacing the connector trail of 2026-07-28): a small
/// arrowhead in the middle of the gap between the note just played and the one lit now, pointing the
/// way the hand went.
///
/// The trail it replaces was a faint line from one dot to the other. It said the two were connected but
/// not which way, so a run coming back down read the same as one going up, which was the one thing a
/// sequenced run (thirds, fourths, rolling groups) needed it to say. Tomisin, on the phone: *"the lines
/// that indicate movement from one note to the other seem a bit weird"*. A head alone, with no stem, keeps
/// it apart from a slide's full-length arrow along the string (`SlideCue`), which is an instruction rather
/// than a direction.
///
/// It is drawn only where it fits: two dots a string apart with captions on leave no room, and there the
/// lit dot already says where the hand is. The **Display** menu turns it off.
struct MoveArrow: Shape {
    /// The centre of the note just played, and how far its dot reaches.
    var from: CGPoint
    var fromRadius: CGFloat
    /// The centre of the note lit now, and how far its dot reaches.
    var to: CGPoint
    var toRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let head = Self.head(from: from, fromRadius: fromRadius, to: to, toRadius: toRadius) else {
            return path
        }
        path.move(to: head.left)
        path.addLine(to: head.tip)
        path.addLine(to: head.right)
        return path
    }

    /// The three points of the head: its tip, and the ends of its two barbs.
    struct Head: Equatable {
        let tip: CGPoint
        let left: CGPoint
        let right: CGPoint
    }

    /// How deep the head is, along the move. Feel value: big enough to read at a glance on a 12pt dot,
    /// small enough to sit in the gap between two notes a fret apart.
    static let depth: CGFloat = 6
    /// Half the head's width, across the move.
    static let halfWidth: CGFloat = 4.5
    /// The space the head keeps from each dot's edge, so its round caps never touch one.
    static let clearance: CGFloat = 2

    /// Where the head goes for a move from one dot to another, or `nil` when it doesn't fit in the gap
    /// between their edges (or the two are the same place). It is centred in that gap, not between the
    /// centres, since the lit dot is drawn larger than the one left behind.
    static func head(from: CGPoint, fromRadius: CGFloat, to: CGPoint, toRadius: CGFloat) -> Head? {
        let deltaX = to.x - from.x, deltaY = to.y - from.y
        let distance = (deltaX * deltaX + deltaY * deltaY).squareRoot()
        guard distance > 0 else { return nil }
        let gap = distance - fromRadius - toRadius
        guard gap >= depth + 2 * clearance else { return nil }
        // A unit step along the move, and one across it.
        let along = CGPoint(x: deltaX / distance, y: deltaY / distance)
        let across = CGPoint(x: -along.y, y: along.x)
        let middle = fromRadius + gap / 2
        let centre = CGPoint(x: from.x + along.x * middle, y: from.y + along.y * middle)
        let tip = CGPoint(x: centre.x + along.x * depth / 2, y: centre.y + along.y * depth / 2)
        let back = CGPoint(x: centre.x - along.x * depth / 2, y: centre.y - along.y * depth / 2)
        return Head(tip: tip,
                    left: CGPoint(x: back.x + across.x * halfWidth, y: back.y + across.y * halfWidth),
                    right: CGPoint(x: back.x - across.x * halfWidth, y: back.y - across.y * halfWidth))
    }
}
