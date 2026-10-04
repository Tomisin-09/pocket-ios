import SwiftUI

/// Where things sit on the board, for whatever is drawn over it.
enum NeckGeometry {
    /// A dot's cell is 30 points square, 4 apart, on both axes.
    static let cellSize: CGFloat = 30
    static let pitch: CGFloat = 34
    /// The string names' column down the left, and the space between it and the board: what's left of
    /// the width is the board's, which *Watch it on the neck* follows the heard note within (ADR 0254).
    static let namesWidth: CGFloat = 16
    static let namesSpacing: CGFloat = 8

    /// The middle of a spot in the marks' coordinates: fret across, string down, below the headroom.
    static func center(string: Int, fret: Int, headroom: CGFloat) -> CGPoint {
        CGPoint(x: CGFloat(fret) * pitch + cellSize / 2, y: headroom + CGFloat(string) * pitch + cellSize / 2)
    }
}

/// A fret as a scroll target, typed apart from every other integer id on the board.
private struct FretAnchor: Hashable {
    let fret: Int
}

/// The **draw-your-own neck** (ADR 0065), shared since ADR 0227 D3 lifted it out of the scales editor:
/// string letters pinned on the left, then a board of frets 0…`maxFret` that scrolls sideways, so any hand
/// position is reachable without paging a window, with the inlays a real neck marks and a fret-number
/// ruler under it. It draws the grid and nothing else. Each spot is the caller's `cell`, so the exercise
/// editor and Name the notes share one board and keep their own dots.
///
/// When `scrollTarget` changes (and when the board first appears on one), that fret scrolls to the
/// middle, the way selecting a placed note brings it into view.
///
/// `marks` draws over the dots, in the board's own coordinates (`NeckGeometry.center`), for the playing
/// marks Name the notes shows (ADR 0227 D5). `headroom` is the space above the top string they need.
/// `beneath` draws under them, in the same coordinates, for the glow that moves between spots as a note is
/// heard (ADR 0234 D5): a bend gliding to where it lands can't be drawn behind one dot.
struct FretNeckBoard<Cell: View, Marks: View, Beneath: View>: View {
    /// One name per string, thinnest first, the order the rows are drawn in.
    let stringNames: [String]
    let maxFret: Int
    var scrollTarget: Int?
    var headroom: CGFloat = 0
    @ViewBuilder let cell: (_ string: Int, _ fret: Int) -> Cell
    @ViewBuilder let marks: () -> Marks
    @ViewBuilder let beneath: () -> Beneath

    var body: some View {
        HStack(alignment: .center, spacing: NeckGeometry.namesSpacing) {
            VStack(spacing: 4) {
                ForEach(stringNames.indices, id: \.self) { row in
                    Text(stringNames[row])
                        .font(.futura(.caption2, weight: .semibold))
                        .foregroundStyle(PocketColor.textSecondary)
                        .frame(height: 30)
                }
                Color.clear.frame(width: 1, height: 26)   // aligns labels against the inlay + number rows
            }
            .padding(.top, headroom)
            .frame(width: NeckGeometry.namesWidth)   // fixed gutter — matches FretboardGrid so the two boards line up
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 4) {
                        VStack(spacing: 4) {
                            ForEach(stringNames.indices, id: \.self) { row in
                                HStack(spacing: 4) {
                                    ForEach(0...maxFret, id: \.self) { fret in
                                        cell(row, fret)
                                    }
                                }
                            }
                        }
                        .padding(.top, headroom)
                        .background(alignment: .topLeading) {
                            beneath().allowsHitTesting(false)
                        }
                        .overlay(alignment: .topLeading) {
                            marks().allowsHitTesting(false)
                        }
                        inlayRow
                        fretNumbers
                    }
                }
                .onAppear {
                    if let scrollTarget { proxy.scrollTo(FretAnchor(fret: scrollTarget), anchor: .center) }
                }
                .onChange(of: scrollTarget) { _, fret in
                    guard let fret else { return }
                    withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(FretAnchor(fret: fret), anchor: .center) }
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
    /// fret as a scroll `.id` so the `ScrollViewReader` can bring a fret into view. The id is a
    /// `FretAnchor`, not the bare number: the string rows' `ForEach` ids are small integers too, and
    /// `scrollTo(2)` found the whole G-string row and centred the board instead of fret 2.
    private var fretNumbers: some View {
        HStack(spacing: 4) {
            ForEach(0...maxFret, id: \.self) { fret in
                Text("\(fret)")
                    .font(.futura(.caption2))
                    .foregroundStyle(PocketColor.textSecondary.opacity(0.7))
                    .frame(width: 30)
                    .id(FretAnchor(fret: fret))
            }
        }
    }
}

extension FretNeckBoard where Marks == EmptyView, Beneath == EmptyView {
    /// A board with nothing drawn over or under its dots, as the exercise editor uses it.
    init(stringNames: [String], maxFret: Int, scrollTarget: Int?,
         @ViewBuilder cell: @escaping (_ string: Int, _ fret: Int) -> Cell) {
        self.init(stringNames: stringNames, maxFret: maxFret, scrollTarget: scrollTarget, headroom: 0,
                  cell: cell, marks: { EmptyView() }, beneath: { EmptyView() })
    }
}
