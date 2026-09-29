import SwiftUI
import UIKit

/// One row of the song's tab (ADR 0232 D10): bar numbers or times along the top, then a line per lane
/// with something in it. Chord symbols and names sit at their taps, notes on the neck sit on their
/// strings, and an unnamed tap is a slash. A row with nothing in it is an empty bar: a gap (D4).
///
/// Set in the fixed-width font tab is set in, so `SongTabLayout` can space the columns in characters. A
/// row too crowded for the width it has draws wider and scrolls sideways rather than overprinting.
struct SongTabRowView: View {
    let row: SongTab.Row
    let scale: SongMap.Scale

    static let rulerHeight: CGFloat = 16
    static let stringSpacing: CGFloat = 14
    static let wordsHeight: CGFloat = 20
    static let lineSpacing: CGFloat = 10
    static let emptyHeight: CGFloat = 14
    /// The left margin, in characters: room for a string's name.
    static let gutterCharacters: CGFloat = 3

    /// One character of the tab's font. It's fixed-width, so every column's width is its length times this.
    private let characterWidth: CGFloat = {
        let size = UIFont.preferredFont(forTextStyle: .caption1).pointSize
        let font = UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        return ("0" as NSString).size(withAttributes: [.font: font]).width
    }()

    private var gutter: CGFloat { Self.gutterCharacters * characterWidth }

    static func height(of row: SongTab.Row) -> CGFloat {
        let lines = row.lines.map(height(of:))
        let body = lines.isEmpty ? emptyHeight : lines.reduce(0, +) + lineSpacing * CGFloat(lines.count - 1)
        return rulerHeight + lineSpacing + body
    }

    static func height(of line: SongTab.Line) -> CGFloat {
        guard line.isTab else { return wordsHeight }
        return (line.hasWordsAboveTab ? wordsHeight : 0) + stringSpacing * CGFloat(line.strings.count)
    }

    var body: some View {
        GeometryReader { geo in
            let available = max((geo.size.width - gutter) * row.widthFraction / characterWidth, 1)
            let width = SongTabLayout.width(of: row, available: Double(available))
            if CGFloat(width) * characterWidth + gutter > geo.size.width + 1 {
                ScrollView(.horizontal, showsIndicators: false) { drawing(width) }
            } else {
                drawing(width)
            }
        }
        .frame(height: Self.height(of: row))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private func drawing(_ width: Double) -> some View {
        let points = CGFloat(width) * characterWidth
        return VStack(alignment: .leading, spacing: Self.lineSpacing) {
            ruler(points)
            if row.lines.isEmpty {
                HStack(spacing: 0) {
                    Color.clear.frame(width: gutter, height: 1)
                    emptyLine(points)
                }
            }
            ForEach(row.lines) { line in
                HStack(alignment: .top, spacing: 0) {
                    stringNames(line)
                    lineView(line, width: width, points: points)
                }
            }
        }
    }

    // MARK: - Ruler and bar lines

    private func ruler(_ points: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(row.ticks, id: \.time) { tick in
                Text(tick.bar.map(String.init) ?? timecode(tick.time))
                    .font(.pocketMono(.caption2))
                    .foregroundStyle(PocketColor.textSecondary)
                    .fixedSize()
                    .offset(x: x(tick.time, points))
            }
        }
        .frame(width: points, height: Self.rulerHeight, alignment: .topLeading)
        .padding(.leading, gutter)
    }

    /// A bar line at every downbeat and at the row's end, or a faint mark every two seconds.
    private func barLines(_ points: CGFloat, top: CGFloat, height: CGFloat) -> some View {
        let color = scale == .bars ? PocketColor.textSecondary.opacity(0.6) : PocketColor.surfaceBorder
        return ZStack(alignment: .topLeading) {
            ForEach(row.ticks, id: \.time) { tick in
                Rectangle().fill(color).frame(width: 1, height: height).offset(x: x(tick.time, points), y: top)
            }
            Rectangle().fill(color).frame(width: 1, height: height).offset(x: points - 1, y: top)
        }
    }

    private func emptyLine(_ points: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(PocketColor.surfaceBorder).frame(width: points, height: 1)
                .offset(y: Self.emptyHeight / 2)
            barLines(points, top: 0, height: Self.emptyHeight)
        }
        .frame(width: points, height: Self.emptyHeight, alignment: .topLeading)
    }

    // MARK: - Lines

    @ViewBuilder private func stringNames(_ line: SongTab.Line) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if line.hasWordsAboveTab { Color.clear.frame(height: Self.wordsHeight) }
            ForEach(Array(line.strings.enumerated()), id: \.offset) { _, name in
                Text(name)
                    .font(.pocketMono(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                    .frame(height: Self.stringSpacing)
            }
        }
        .frame(width: gutter, alignment: .leading)
    }

    private func lineView(_ line: SongTab.Line, width: Double, points: CGFloat) -> some View {
        let positions = SongTabLayout.spread(line.columns, in: row, width: width)
        let staffTop = line.hasWordsAboveTab ? Self.wordsHeight : 0
        let tint = SongMapStyle.tint(line.layer)
        return ZStack(alignment: .topLeading) {
            if line.isTab {
                ForEach(line.strings.indices, id: \.self) { string in
                    Rectangle().fill(PocketColor.textSecondary.opacity(0.35)).frame(width: points, height: 1)
                        .offset(y: stringY(string, top: staffTop))
                }
                barLines(points, top: stringY(0, top: staffTop),
                         height: Self.stringSpacing * CGFloat(line.strings.count - 1) + 1)
            } else {
                barLines(points, top: 2, height: Self.wordsHeight - 4)
            }
            ForEach(Array(line.repeats.enumerated()), id: \.offset) { _, mark in
                repeatLabel(mark, points: points, tint: tint)
            }
            ForEach(Array(zip(line.columns, positions).enumerated()), id: \.offset) { _, pair in
                mark(pair.0.mark, at: CGFloat(pair.1) * characterWidth, staffTop: staffTop, tint: tint)
            }
        }
        .frame(width: points, height: Self.height(of: line), alignment: .topLeading)
    }

    /// Where a loop repeats (D14): *↻ Verse changes ×4* across the stretch, with a light rule under it for
    /// how far it runs. The count is said once, where the repeats begin; a later row says only what.
    private func repeatLabel(_ mark: SongTab.RepeatMark, points: CGFloat, tint: Color) -> some View {
        let start = x(mark.start, points) + characterWidth * CGFloat(SongTabLayout.lead)
        let width = max(x(mark.end, points) - start - characterWidth / 2, 0)
        let text = mark.continues ? mark.name : "\(mark.name) ×\(mark.passes)"
        return ZStack(alignment: .bottomLeading) {
            Rectangle().fill(tint.opacity(0.35)).frame(width: width, height: 1)
            // The board's symbol, not a ↻ character: the fixed-width font draws that small and low.
            HStack(spacing: 4) {
                Image(systemName: "repeat").font(.caption2.weight(.semibold))
                Text(text).font(.pocketMono(.caption).weight(.semibold))
            }
            .foregroundStyle(tint.opacity(0.8))
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxHeight: .infinity)
            .padding(.trailing, 3)
            // Breaks the bar lines behind the words, top to bottom, as the tab's numbers break its strings.
            .background(PocketColor.background)
            .frame(width: width, height: Self.wordsHeight - 2, alignment: .leading)
        }
        .frame(width: width, height: Self.wordsHeight, alignment: .bottomLeading)
        .offset(x: start)
    }

    @ViewBuilder private func mark(_ mark: SongTab.Mark, at xPos: CGFloat, staffTop: CGFloat,
                                   tint: Color) -> some View {
        switch mark {
        case .name(let name):
            words(name, color: tint).offset(x: xPos)
        case .slash:
            words("/", color: tint.opacity(0.7)).offset(x: xPos)
        case .frets(let cells):
            ForEach(cells, id: \.string) { cell in
                Text(cell.text)
                    .font(.pocketMono(.caption))
                    .foregroundStyle(PocketColor.textPrimary)
                    .fixedSize()
                    // Breaks the string behind the number, as tab on paper does.
                    .background(PocketColor.background)
                    .frame(height: Self.stringSpacing)
                    .offset(x: xPos, y: stringY(cell.string, top: staffTop) - Self.stringSpacing / 2)
            }
        }
    }

    private func words(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.pocketMono(.caption).weight(.semibold))
            .foregroundStyle(color)
            .fixedSize()
            .frame(height: Self.wordsHeight)
    }

    // MARK: - Geometry

    private func stringY(_ string: Int, top: CGFloat) -> CGFloat {
        top + Self.stringSpacing * (CGFloat(string) + 0.5)
    }

    private func x(_ time: TimeInterval, _ points: CGFloat) -> CGFloat {
        CGFloat(row.position(of: time)) * points
    }

    // MARK: - VoiceOver

    /// *Bars 5 to 8. Chords: Gm7, C7. Notes: F, G, unnamed.*
    private var spoken: String {
        let bars = row.ticks.compactMap(\.bar)
        let span = bars.isEmpty
            ? "\(timecode(row.start)) to \(timecode(row.end))"
            : (bars.count == 1 ? "Bar \(bars[0])" : "Bars \(bars[0]) to \(bars[bars.count - 1])")
        guard !row.lines.isEmpty else { return "\(span). Nothing counted here." }
        let lines = row.lines.map { line in
            let taps = line.columns.map { $0.name ?? "unnamed" }
            let repeats = line.repeats.map {
                $0.continues ? "\($0.name) repeating" : "\($0.name) repeats, \($0.passes) times in all"
            }
            return "\(SongMapStyle.name(line.layer)): " + (taps + repeats).joined(separator: ", ")
        }
        return ([span] + lines).joined(separator: ". ")
    }
}
