import SwiftUI

/// The frets a Triads run is kept between (ADR 0313 D6), shaded on the board behind the strings and the
/// notes and edged in the tint, so the range reads as one place on the neck. `FretboardGrid` draws it from
/// the drill's `shadedFrets`; a run that climbs the neck carries none, and then this draws nothing.
///
/// Columns are laid out as the grid lays them: fret `f` fills column `f - lowestFret` of `span`. An open
/// string sits on the nut, outside every column, so a range from fret 0 shades from the nut.
struct FretRangeShade: View {
    let range: ClosedRange<Int>?
    /// The board's visible window.
    let lowestFret: Int
    let span: Int
    var tint: Color = PocketColor.practice

    var body: some View {
        GeometryReader { geo in
            let column = geo.size.width / CGFloat(max(1, span))
            let low = max(range?.lowerBound ?? .max, lowestFret)
            let high = min(range?.upperBound ?? .min, lowestFret + span - 1)
            if range != nil, high >= low {
                let minX = CGFloat(low - lowestFret) * column
                let maxX = CGFloat(high - lowestFret + 1) * column
                RoundedRectangle(cornerRadius: 6)
                    .fill(tint.opacity(0.14))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(tint.opacity(0.45), lineWidth: 1))
                    .frame(width: maxX - minX, height: geo.size.height)
                    .position(x: (minX + maxX) / 2, y: geo.size.height / 2)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
