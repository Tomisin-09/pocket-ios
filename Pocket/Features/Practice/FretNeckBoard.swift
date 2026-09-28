import SwiftUI

/// The **draw-your-own neck** (ADR 0065), shared since ADR 0227 D3 lifted it out of the scales editor:
/// string letters pinned on the left, then a board of frets 0…`maxFret` that scrolls sideways, so any hand
/// position is reachable without paging a window, with the inlays a real neck marks and a fret-number
/// ruler under it. It draws the grid and nothing else. Each spot is the caller's `cell`, so the exercise
/// editor and Name the notes share one board and keep their own dots.
///
/// When `scrollTarget` changes (and when the board first appears on one), that fret scrolls to the
/// middle, the way selecting a placed note brings it into view.
struct FretNeckBoard<Cell: View>: View {
    /// One name per string, thinnest first, the order the rows are drawn in.
    let stringNames: [String]
    let maxFret: Int
    var scrollTarget: Int?
    @ViewBuilder let cell: (_ string: Int, _ fret: Int) -> Cell

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(spacing: 4) {
                ForEach(stringNames.indices, id: \.self) { row in
                    Text(stringNames[row])
                        .font(.futura(.caption2, weight: .semibold))
                        .foregroundStyle(PocketColor.textSecondary)
                        .frame(height: 30)
                }
                Color.clear.frame(width: 1, height: 26)   // aligns labels against the inlay + number rows
            }
            .frame(width: 16)   // fixed gutter — matches FretboardGrid so the two boards line up
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(stringNames.indices, id: \.self) { row in
                            HStack(spacing: 4) {
                                ForEach(0...maxFret, id: \.self) { fret in
                                    cell(row, fret)
                                }
                            }
                        }
                        inlayRow
                        fretNumbers
                    }
                }
                .onAppear {
                    if let scrollTarget { proxy.scrollTo(scrollTarget, anchor: .center) }
                }
                .onChange(of: scrollTarget) { _, fret in
                    guard let fret else { return }
                    withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(fret, anchor: .center) }
                }
            }
        }
    }

    /// Neck inlays under the board — the same frets a real neck marks, read from `FretboardGrid` so the
    /// authoring board and the practice board can't drift apart. Earns its keep at 24 frets, where
    /// counting fret lines from the nut stops being viable.
    private var inlayRow: some View {
        HStack(spacing: 4) {
            ForEach(0...maxFret, id: \.self) { fret in
                Group {
                    if FretboardGrid.doubleInlayFrets.contains(fret) {
                        HStack(spacing: 3) { inlayDot; inlayDot }
                    } else if FretboardGrid.singleInlayFrets.contains(fret) {
                        inlayDot
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 30, height: 6)
            }
        }
        .accessibilityHidden(true)
    }

    private var inlayDot: some View {
        Circle().fill(PocketColor.gridLine).frame(width: 5, height: 5)
    }

    /// The fret-number ruler under the board — one label per fret across the full neck. Each carries its
    /// fret as a scroll `.id` so the `ScrollViewReader` can bring a fret into view.
    private var fretNumbers: some View {
        HStack(spacing: 4) {
            ForEach(0...maxFret, id: \.self) { fret in
                Text("\(fret)")
                    .font(.futura(.caption2))
                    .foregroundStyle(PocketColor.textSecondary.opacity(0.7))
                    .frame(width: 30)
                    .id(fret)
            }
        }
    }
}
