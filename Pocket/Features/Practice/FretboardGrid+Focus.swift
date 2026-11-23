import SwiftUI

// Where `FretboardGrid` points the eye beyond the lit note: the pass being played (ADR 0083 S2b) and where
// the fingers just were (ADR 0313 D8). Out of the view's file for its length.

extension FretboardGrid {
    /// How faint an **off-pass** note fades to while a multi-pass run walks (ADR 0083 S2b — "pass
    /// focus"): the current pass reads as the focus, the rest stays visible as context. Feel value.
    static let offPassGhostOpacity: Double = 0.2

    /// Whether the drill is a genuine multi-pass run — the gate for pass focus. A single-pass run tags
    /// one uniform group, and every non-run drill has no groups at all, so neither ever dims.
    var isMultiPass: Bool {
        guard let groups = drill.noteGroups else { return false }
        return Set(groups).count > 1
    }

    /// The opacity for a position under **pass focus** (ADR 0083 S2b): while a multi-pass run walks,
    /// notes outside the active note's pass drop to a ghost so the eye locks onto the position being
    /// played; the active pass, a single-pass run, and the static board (no `activeIndex`) render fully.
    ///
    /// Takes **every** slot that plays this position and keeps it lit if *any* of them belongs to the
    /// active pass — a position the run revisits across passes is genuinely part of the pass being
    /// played, so ghosting it because one of its other slots sits elsewhere would fade a note under the
    /// hand right now.
    func passFocusOpacity(noteIndices: [Int]) -> Double {
        guard isMultiPass, let activeIndex, let groups = drill.noteGroups,
              groups.indices.contains(activeIndex)
        else { return 1 }
        let activeGroup = groups[activeIndex]
        let sharesPass = noteIndices.contains { groups.indices.contains($0) && groups[$0] == activeGroup }
        return sharesPass ? 1 : Self.offPassGhostOpacity
    }
}

/// **Where a finger just was** (ADR 0313 D8): a dashed ring around a note of the shape before, drawn while
/// the next chord plays, so the nearest move can be seen. Grey, as the mockup draws it, because it's the
/// chord that has gone: the colour belongs to the one under the hand. Draws nothing when not shown, so it
/// can sit behind every dot.
struct JustLeftRing: View {
    let isShown: Bool
    /// The dot it rings, which it clears by a few points.
    let dotDiameter: CGFloat

    /// How far the ring sits outside its dot, so it reads as a ring around the grey dot, not its edge.
    static let clearance: CGFloat = 7

    var body: some View {
        if isShown {
            Circle()
                .strokeBorder(PocketColor.textPrimary.opacity(0.55),
                              style: StrokeStyle(lineWidth: 1.3, dash: [2.5, 2.5]))
                .frame(width: dotDiameter + Self.clearance, height: dotDiameter + Self.clearance)
                .allowsHitTesting(false)
        }
    }
}
