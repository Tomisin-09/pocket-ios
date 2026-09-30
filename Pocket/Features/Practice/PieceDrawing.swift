import SwiftUI
import UIKit

/// A piece drawn for reading (ADR 0234 D8), the one view *Saved on this loop*, **Versions**, the Journal's
/// Pieces rows and the map's piece sheet all use, so they can't drift apart again. A line saying what it
/// is ("98 notes · Guitar · Standard · 6 unnamed"), then its tab in rows that fit the width, each saying
/// which notes it holds, with what the strings can't say above them: a name given by ear, a chord, `·` for
/// an unnamed note, `(5)` for a run of them (`PieceStaff`). A piece with nothing on the neck is its names,
/// in fours. It replaces the line of names that ran to a wall on a long piece and the one line of tab that
/// ran off the side.
///
/// Drawn from the piece every time, never kept as text (**edit pieces, never the picture**).
struct PieceDrawing: View {
    let piece: PieceTranscription
    let spelling: NoteSpelling
    /// Folded to its line until *See the notes* is tapped: the Journal's Pieces rows, so the feed stays a
    /// feed (ADR 0234 D8, after the second design round).
    var folds = false
    /// *Copy tab* on a hold: the map's piece sheet, where the tab could be selected as text before.
    var copyable = false

    @State private var isOpen = false
    @State private var width: CGFloat = 0

    private static let stringSpacing: CGFloat = 14
    private static let aboveHeight: CGFloat = 16
    private static let gap = 2
    private static let gutterCharacters: CGFloat = 2
    private static let barWidth: CGFloat = 1

    /// One character of the tab's font; it's fixed-width, so a column's width is its length times this.
    private let characterWidth: CGFloat = {
        let size = UIFont.preferredFont(forTextStyle: .caption1).pointSize
        let font = UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        return ("0" as NSString).size(withAttributes: [.font: font]).width
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            metaLine
            if folds && !isOpen {
                toggle("See the \(noun)s")
            } else {
                drawing
                if folds { toggle("Hide the \(noun)s") }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var noun: String {
        let named = piece.labels.compactMap { $0 }
        return !named.isEmpty && named.allSatisfy(\.isChord) ? "chord" : "note"
    }

    private var metaLine: some View {
        let parts = PieceStaff.meta(of: piece).components(separatedBy: " · ")
        let rest = parts.dropFirst().map { " · " + $0 }.joined()
        let count = Text(parts.first ?? "").fontWeight(.semibold).foregroundStyle(PocketColor.textPrimary)
        return Text("\(count)\(rest)")
            .font(.futura(.subheadline))
            .foregroundStyle(PocketColor.textSecondary)
            // The names in full, for VoiceOver: the drawing below is read as a whole, not note by note.
            .accessibilityLabel(piece.summary(spelling: spelling) ?? PieceStaff.meta(of: piece))
    }

    private func toggle(_ title: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isOpen.toggle() }
        } label: {
            Text("\(title) \(Image(systemName: isOpen ? "chevron.up" : "chevron.down"))")
                .font(.futura(.footnote, weight: .semibold))
        }
        .buttonStyle(.borderless)
        .tint(PocketColor.practice)
        .accessibilityIdentifier("piece.toggle")
    }

    @ViewBuilder private var drawing: some View {
        if piece.hasFrettedLabels {
            if copyable, let tab = TabLine.render(piece.labels, openMidi: piece.openMidi ?? []) {
                staff.contextMenu {
                    Button("Copy tab", systemImage: "doc.on.doc") { UIPasteboard.general.string = tab }
                }
            } else {
                staff
            }
        } else {
            groups
        }
    }

    // MARK: - Tab rows

    private var staff: some View {
        let strings = TabLine.stringNames(openMidi: piece.openMidi ?? [])
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let columns = PieceStaff.columns(of: piece, spelling: spelling)
        // A row is the gutter, a bar each side, and each column with the gap after it, so the gap is paid
        // once more than `rows` counts it.
        let room = width - Self.gutterCharacters * characterWidth - 2 * Self.barWidth
        let rows = PieceStaff.rows(columns, fitting: max(Int(room / characterWidth) - Self.gap, 6), gap: Self.gap)
        return VStack(alignment: .leading, spacing: 0) {
            // Measured on an empty line that takes the width it's offered, never on the rows: a flexible
            // frame reports a wider child's width, and the rows are laid out from what's measured, so
            // measuring them would feed back.
            Color.clear
                .frame(height: 0)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            VStack(alignment: .leading, spacing: 12) {
                if width > 0 {
                    ForEach(rows.indices, id: \.self) { index in
                        // Every row but the last is spread to the width, as a tab book sets them, so the
                        // bars line up down the page.
                        let natural = CGFloat(rows[index].columns.map { $0.width + Self.gap }.reduce(0, +))
                            * characterWidth
                        let spread = index < rows.count - 1 && natural > 0 ? min(room / natural, 1.5) : 1
                        row(rows[index], strings: strings, spread: max(spread, 1))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tab, \(rows.count) row\(rows.count == 1 ? "" : "s")")
        .accessibilityIdentifier("piece.tab")
    }

    private func row(_ row: PieceStaff.Row, strings: [String], spread: CGFloat) -> some View {
        let hasAbove = row.columns.contains { $0.above != nil }
        let notes = row.notes
        return VStack(alignment: .leading, spacing: 2) {
            Text(notes.count == 1 ? "Note \(notes.lowerBound)" : "Notes \(notes.lowerBound)–\(notes.upperBound)")
                .font(.futura(.caption2))
                .monospacedDigit()
                .foregroundStyle(PocketColor.textSecondary)
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    if hasAbove { Color.clear.frame(height: Self.aboveHeight) }
                    ForEach(strings.indices, id: \.self) { string in
                        Text(strings[string])
                            .font(.pocketMono(.caption2))
                            .foregroundStyle(PocketColor.textSecondary)
                            .frame(height: Self.stringSpacing)
                    }
                }
                .frame(width: Self.gutterCharacters * characterWidth, alignment: .leading)
                bar(strings: strings.count, hasAbove: hasAbove)
                ForEach(row.columns, id: \.note) { column in
                    columnView(column, strings: strings.count, hasAbove: hasAbove, spread: spread)
                }
                bar(strings: strings.count, hasAbove: hasAbove)
            }
        }
    }

    private func columnView(_ column: PieceStaff.Column, strings: Int, hasAbove: Bool,
                            spread: CGFloat) -> some View {
        VStack(spacing: 0) {
            if hasAbove {
                Text(column.above ?? "")
                    .font(.pocketMono(.caption).weight(.semibold))
                    .foregroundStyle(column.isQuiet ? PocketColor.textSecondary : KindChip.tint(for: .transcribed))
                    .lineLimit(1)
                    .fixedSize()
                    .frame(height: Self.aboveHeight)
            }
            ForEach(0..<strings, id: \.self) { string in
                HStack(spacing: 0) {
                    stringLine
                    if let cell = column.cells.first(where: { $0.string == string }) {
                        Text(cell.text)
                            .font(.pocketMono(.caption))
                            .foregroundStyle(PocketColor.textPrimary)
                            .fixedSize()
                            .padding(.horizontal, 1)
                        stringLine
                    }
                }
                .frame(height: Self.stringSpacing)
            }
        }
        .frame(width: CGFloat(column.width + Self.gap) * characterWidth * spread)
    }

    private var stringLine: some View {
        Rectangle().fill(PocketColor.textSecondary.opacity(0.35)).frame(height: 1)
    }

    /// A bar line from the top string to the bottom one, at each end of a row.
    private func bar(strings: Int, hasAbove: Bool) -> some View {
        Rectangle()
            .fill(PocketColor.textSecondary.opacity(0.6))
            .frame(width: Self.barWidth, height: Self.stringSpacing * CGFloat(max(strings - 1, 0)))
            .padding(.top, (hasAbove ? Self.aboveHeight : 0) + Self.stringSpacing / 2)
    }

    // MARK: - Names, in fours

    private var groups: some View {
        let groups = PieceStaff.groups(of: piece, spelling: spelling)
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 152), spacing: 8, alignment: .leading)],
                         alignment: .leading, spacing: 8) {
            ForEach(groups.indices, id: \.self) { index in
                HStack(spacing: 4) {
                    ForEach(groups[index], id: \.note) { cell in
                        VStack(spacing: 0) {
                            Text(cell.name ?? "–")
                                .font(.futura(.subheadline, weight: cell.name == nil ? .regular : .semibold))
                                .foregroundStyle(cell.name == nil ? PocketColor.textSecondary : PocketColor.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text("\(cell.note + 1)")
                                .font(.futura(.caption2))
                                .monospacedDigit()
                                .foregroundStyle(PocketColor.textSecondary)
                        }
                        .frame(minWidth: 32)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(PocketColor.surfaceSubtle))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(piece.summary(spelling: spelling) ?? "")
        .accessibilityIdentifier("piece.names")
    }
}
