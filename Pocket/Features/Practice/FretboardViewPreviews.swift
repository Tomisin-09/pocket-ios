import SwiftUI

// The ADR 0083 fretboard-motion previews, split out of `FretboardView.swift` to keep that file
// under the 400-line budget. Each shows `FretboardGrid` at frozen moments of a walk so the
// following-viewport (S5) and pass-focus (S2b) behaviours can be read on the canvas without a clock.

/// The **following viewport** (ADR 0083 S5): a run that climbs fret 1 → 16 up one string, shown at
/// three moments of its walk. At rest the whole climb is a full-neck reference diagram; while it
/// walks, the board holds a comfortable window still until the note reaches the edge, then scrolls the
/// minimum needed — keeping several already-played frets behind the note. Watch it hold, then scroll.
#Preview("Following viewport") {
    let climb = FretboardRun(fingers: [1, 2, 3, 4], baseFret: 1,
                             fromString: 5, toString: 5, roundTrip: false,
                             fretShiftPerPass: 4, passCount: 4).expanded()
    return VStack(alignment: .leading, spacing: 20) {
        Text("At rest — full climb").font(.futura(.caption))
        FretboardGrid(drill: climb, activeIndex: nil)
        Text("Walking, fret 3 — window still holds at the bottom").font(.futura(.caption))
        FretboardGrid(drill: climb, activeIndex: 2)
        Text("Walking, fret 9 — scrolled once; runway ahead, one fret of history behind").font(.futura(.caption))
        FretboardGrid(drill: climb, activeIndex: 8)
    }
    .foregroundStyle(PocketColor.textSecondary)
    .padding()
    .background(PocketColor.background)
    .preferredColorScheme(.dark)
}

/// **Pass focus** (ADR 0083 S2b): a four-pass climbing run shown mid-walk. The pass being played sits
/// at full strength; the other passes fade to a ghost so the eye locks onto the current position while
/// the whole climb's shape stays as context. At rest the board is the full, undimmed reference diagram.
#Preview("Pass focus") {
    // A gentle +1-per-pass climb that stays inside the comfortable window, so the viewport holds
    // static and every pass is on screen at once — pass focus, not scrolling, does the disambiguation.
    let climb = FretboardRun(fingers: [1, 2, 3, 4], baseFret: 1,
                             fromString: 5, toString: 3, roundTrip: false,
                             fretShiftPerPass: 1, passCount: 4).expanded()
    return VStack(alignment: .leading, spacing: 20) {
        Text("At rest — every pass full strength").font(.futura(.caption))
        FretboardGrid(drill: climb, activeIndex: nil)
        Text("Walking pass 1 — later passes ghosted").font(.futura(.caption))
        FretboardGrid(drill: climb, activeIndex: 2)
        Text("Walking pass 3 — focus has moved up the climb").font(.futura(.caption))
        FretboardGrid(drill: climb, activeIndex: climb.noteGroups?.firstIndex(of: 2) ?? 0)
    }
    .foregroundStyle(PocketColor.textSecondary)
    .padding()
    .background(PocketColor.background)
    .preferredColorScheme(.dark)
}
