import SwiftUI

/// A piece's repeats on the board (ADR 0232 D14), or the part of them in one row: a band lighter than the
/// piece, from its end to its section's end, with *↻ ×4* where it starts. It's a label for what the
/// player said, never copies of the piece, so there are no dots and no line here: those are the piece's.
///
/// Tapping it opens the piece's tab and holding it gives the piece's menu, since it's the same loop.
struct SongMapBandView: View {
    let band: SongMap.Band
    let piece: SongMap.Piece
    let width: CGFloat
    let height: CGFloat
    let modes: [LoopRunMode]
    let repeats: SongMapRepeatToggle?
    let onView: () -> Void
    let onOpen: (LoopRunMode) -> Void

    private var tint: Color { SongMapStyle.tint(piece.layer) }

    var body: some View {
        Button(action: onView) {
            ZStack(alignment: .leading) {
                shape.fill(tint.opacity(0.07))
                    .overlay(shape.stroke(tint.opacity(0.4), lineWidth: 1))
                if width >= 26 {
                    HStack(spacing: 3) {
                        Image(systemName: "repeat")
                        if !band.continuesBefore, width >= 48 { Text("×\(band.passes)") }
                    }
                    .font(.futura(.caption2, weight: .medium))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 6)
                }
            }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            SongMapPieceMenu(modes: modes, repeats: repeats, onView: onView, onOpen: onOpen)
        }
        .accessibilityLabel("\(piece.name), repeating")
        .accessibilityValue("\(band.passes) times in all")
        .accessibilityHint("Opens its tab")
    }

    /// Square on the left, where it carries on from the piece or from the row before; rounded on the
    /// right only where the repeats end.
    private var shape: UnevenRoundedRectangle {
        let after: CGFloat = band.continuesAfter ? 0 : 6
        return UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                      bottomTrailingRadius: after, topTrailingRadius: after)
    }
}
