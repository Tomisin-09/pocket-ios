import SwiftUI

/// **Tab**, the other view of the song map (ADR 0232 D10): the same sections as the board, drawn as the
/// song's chart and tab. There is nothing to edit here. To change a bar, re-solve its piece (0225 D10),
/// so tapping a row goes back to the board, to the pieces that drew it.
///
/// A section that repeats an earlier one and has nothing of its own reads as a chart writes it, its
/// heading and *as Verse 1* with no empty rows under it (D8). A loop that repeats to the end of its section
/// is written once and labelled where it repeats (D14).
struct SongTabView: View {
    let tab: SongTab
    /// Tap a section heading: its marker.
    let openMarker: (UUID) -> Void
    /// Tap *as Verse 1*: the section it names.
    let showSection: (TimeInterval) -> Void
    /// Tap a row: the board, at the pieces that drew it.
    let onShowPieces: (SongTab.Row) -> Void

    var body: some View {
        ForEach(tab.sections) { section in
            VStack(alignment: .leading, spacing: 14) {
                SongMapSectionHeading(heading: section.heading, bars: section.bars, start: section.start,
                                      end: section.end, sameAs: section.sameAs, openMarker: openMarker,
                                      showSection: showSection)
                if section.showsRows {
                    ForEach(section.rows) { row in
                        SongTabRowView(row: row, scale: tab.scale)
                            .contentShape(Rectangle())
                            .onTapGesture { onShowPieces(row) }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityHint(row.pieces.isEmpty ? "Shows this stretch on the board"
                                                                  : "Shows the pieces that drew it")
                    }
                }
            }
            .id(SongMapAnchor.section(section.start))
        }
    }
}
