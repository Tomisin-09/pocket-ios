import SwiftUI

/// **One spot on the neck**, drawn: its note name in a dot, styled by where it sits from the note in hand
/// (ADR 0227 D3, 0234 D4). Lifted out of `NeckNoteEditor` for ADR 0254, so *Watch it on the neck* draws the
/// same dots the editor does: the editor wraps each in the button that places a note, and the viewer draws
/// them bare. **A faint name is a map, not a hint:** an empty spot reads the same whatever was heard.
struct NeckSpotDot: View {
    /// The note the spot sounds, spelled for the key (ADR 0123).
    let name: String
    /// Where a placed note sits from the note in hand; `nil` for an empty spot.
    let tier: NeckNeighbours.Tier?
    /// The note number a neighbour carries, 1-based, so the line reads in order where it crosses itself.
    var number: Int?
    /// In a shape, the note bend and vibrato go on.
    var isRinged = false
    /// Faded, while *Into it* waits for a start this spot can't be.
    var isDimmed = false
    @Environment(\.neckAccent) private var accent

    var body: some View {
        let style = SpotStyle(tier, accent: accent)
        Text(name)
            .font(.futura(size: tier == .current ? 10 : 9, weight: tier == nil ? .regular : .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(style.ink)
            .frame(width: 24, height: 24)
            .background(Circle().fill(style.fill))
            .overlay(Circle().inset(by: style.ringWidth / 2).stroke(style.ring, lineWidth: style.ringWidth))
            .overlay(Circle().inset(by: -3.5).stroke(isRinged ? accent : .clear, lineWidth: 1.5))
            .overlay(alignment: .topTrailing) {
                if let number, style.numbered { NeighbourNumber(note: number) }
            }
            .opacity(isDimmed ? 0.3 : 1)
            .frame(width: NeckGeometry.cellSize, height: NeckGeometry.cellSize)
            .contentShape(Rectangle())
    }
}

/// How a spot is drawn for its tier. The note being named is solid; the three before are **filled** and
/// the three after **ringed**, both fading with distance, so they differ in shape as well as colour and
/// read with colour filters on; any other placed note is in ink (0227 D3); an empty spot is faint.
private struct SpotStyle {
    let fill: Color
    let ink: Color
    let ring: Color
    let ringWidth: CGFloat
    /// Neighbours carry their note number, so the line reads in order where it crosses itself.
    let numbered: Bool

    private static let fades: [Double] = [0.64, 0.38, 0.2]
    private static let rings: [Double] = [0.95, 0.6, 0.32]

    init(_ tier: NeckNeighbours.Tier?, accent: Color) {
        switch tier {
        case .current?:
            self.init(fill: accent, ink: PocketColor.background, ring: .clear, ringWidth: 1,
                      numbered: false)
        case .before(let steps)?:
            let fade = Self.fades[min(max(steps, 1), 3) - 1]
            self.init(fill: accent.opacity(fade),
                      ink: steps == 1 ? PocketColor.background : PocketColor.textPrimary,
                      ring: .clear, ringWidth: 1, numbered: true)
        case .after(let steps)?:
            self.init(fill: .clear, ink: accent,
                      ring: accent.opacity(Self.rings[min(max(steps, 1), 3) - 1]), ringWidth: 2,
                      numbered: true)
        case .other?:
            self.init(fill: PocketColor.textPrimary.opacity(0.18), ink: PocketColor.textPrimary, ring: .clear,
                      ringWidth: 1, numbered: false)
        case nil:
            self.init(fill: PocketColor.surfaceSubtle.opacity(0.5), ink: PocketColor.textSecondary.opacity(0.55),
                      ring: PocketColor.surfaceBorder, ringWidth: 1, numbered: false)
        }
    }

    private init(fill: Color, ink: Color, ring: Color, ringWidth: CGFloat, numbered: Bool) {
        self.fill = fill
        self.ink = ink
        self.ring = ring
        self.ringWidth = ringWidth
        self.numbered = numbered
    }
}

/// A neighbour's note number, tucked on its top right corner.
private struct NeighbourNumber: View {
    let note: Int
    @Environment(\.neckAccent) private var accent

    var body: some View {
        Text("\(note)")
            .font(.futura(size: 8, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(accent)
            .padding(.horizontal, 3)
            .frame(minWidth: 14, minHeight: 13)
            .background(Capsule().fill(PocketColor.background))
            .overlay(Capsule().stroke(accent, lineWidth: 1))
            .offset(x: 6, y: -5)
            .accessibilityHidden(true)
    }
}
