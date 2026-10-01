import Foundation

/// A tab as fixed-width lines, for the file it leaves in (ADR 0236 D9): plain text, or a PDF drawn from
/// the same lines.
///
/// Built from the layouts the screens already draw, so the file reads like the screen: a written tab
/// (ADR 0235) from `PieceStaff.systems` (sections, whole bars on a row, bar lines), and a song's tab
/// (ADR 0232 D10) from `SongTab`, its columns spaced by `SongTabLayout.spread`. **Order only** (0235 D9):
/// nothing here has a length, so a written tab's notes are evenly spaced and a song's sit where they play.
///
/// Pure and SwiftUI-free (AGENTS.md).
struct TabDocument: Equatable, Sendable {

    /// What a line is, so a PDF can set it apart. Plain text ignores it.
    enum Kind: Equatable, Sendable {
        /// Bar numbers, or times, over a song's row.
        case ruler
        /// Chord symbols, in the chords lane's colour on a PDF.
        case chords
        /// Names by ear, slashes, repeat counts, or what a written tab says above its strings.
        case names
        /// One string of tab, or a row's bar lines over nothing.
        case strings
    }

    struct Line: Equatable, Sendable {
        let kind: Kind
        let text: String
    }

    /// Lines printed together: one row of tab, under its section's heading when it's the section's first.
    struct Block: Equatable, Sendable {
        var heading: String?
        var lines: [Line]
    }

    /// Where a document comes from. Small and `Sendable`, so a share item can carry it and lay it out only
    /// once a destination is picked.
    enum Source: Equatable, Sendable {
        case written(title: String, notes: PieceNotes, spelling: NoteSpelling)
        case song(title: String, artist: String, tab: SongTab)

        var title: String {
            switch self {
            case .written(let title, _, _), .song(let title, _, _): title
            }
        }
    }

    var title: String
    var subtitle: String?
    var blocks: [Block]
    var footer: String

    /// Characters a row is laid out in, after the string names. A text file is read at about this width,
    /// and an A4 page fits it at 10 pt.
    static let width = 64

    /// Between two columns of a written tab, as `PieceDrawing` spaces them.
    static let gap = 2

    /// The document as plain text, a blank line between rows.
    var text: String {
        var out = [title]
        if let subtitle { out.append(subtitle) }
        for block in blocks {
            out.append("")
            if let heading = block.heading { out.append(heading) }
            out += block.lines.map(\.text)
        }
        out += ["", footer]
        return out.joined(separator: "\n") + "\n"
    }

    init(title: String, subtitle: String?, blocks: [Block], footer: String) {
        self.title = title
        self.subtitle = subtitle
        self.blocks = blocks
        self.footer = footer
    }

    init(_ source: Source, width: Int = TabDocument.width) {
        switch source {
        case let .written(title, notes, spelling):
            self = Self.written(title: title, notes: notes, spelling: spelling, width: width)
        case let .song(title, artist, tab):
            self = Self.song(title: title, artist: artist, tab: tab, width: width)
        }
    }

    // MARK: - A written tab

    /// A tab from My tabs: its title, what it holds (*30 notes · Guitar · Standard*), then each section's
    /// rows under its heading.
    static func written(title: String, notes: PieceNotes, spelling: NoteSpelling,
                        width: Int = TabDocument.width) -> TabDocument {
        var blocks: [Block] = []
        if notes.hasFrettedLabels {
            let strings = TabLine.stringNames(openMidi: notes.openMidi ?? [])
            for system in PieceStaff.systems(of: notes, spelling: spelling, fitting: width, gap: gap) {
                for (index, row) in system.rows.enumerated() {
                    blocks.append(Block(heading: index == 0 ? system.heading : nil,
                                        lines: lines(of: row, strings: strings)))
                }
            }
        } else if !notes.labels.isEmpty {
            // Nothing on the neck: its names in fours, numbered, as `PieceDrawing` shows them.
            let groups = PieceStaff.groups(of: notes, spelling: spelling).map { group in
                group.map { "\($0.note + 1) \($0.name ?? "–")" }.joined(separator: "   ")
            }
            blocks.append(Block(heading: nil, lines: groups.map { Line(kind: .names, text: $0) }))
        }
        return TabDocument(title: named(title, or: "Untitled tab"), subtitle: PieceStaff.meta(of: notes),
                           blocks: blocks,
                           footer: "Written in Red Moon. The notes are in order; how long each lasts isn't written.")
    }

    /// One row of a written tab: what it says above the strings, if anything, then a line per string,
    /// a column's cell padded to its width and `--` between columns, as `TabLine` writes it.
    private static func lines(of row: PieceStaff.Row, strings: [String]) -> [Line] {
        let lead = String(repeating: " ", count: (strings.first?.count ?? 1) + 2)
        var out: [Line] = []
        if row.columns.contains(where: { $0.above != nil }) {
            let words = row.columns.map { pad($0.isBar ? "" : $0.above ?? "", to: $0.width, with: " ") }
            out.append(Line(kind: .names, text: trimmedEnd(lead + words.joined(separator: "  "))))
        }
        for (string, name) in strings.enumerated() {
            let cells = row.columns.map { column -> String in
                if column.isBar { return "|" }
                return pad(column.cells.first { $0.string == string }?.text ?? "", to: column.width, with: "-")
            }
            out.append(Line(kind: .strings, text: name + "|-" + cells.joined(separator: "--") + "-|"))
        }
        return out
    }

    // MARK: - A song's tab

    /// A song's tab from Map the song: its title and artist, then each section under its heading and bar
    /// range, a row at a time, the way the Tab view draws it.
    static func song(title: String, artist: String, tab: SongTab, width: Int = TabDocument.width) -> TabDocument {
        // One gutter for the whole song, so bar numbers stay in their columns from a row with strings to one
        // without.
        let gutter = tab.sections.flatMap(\.rows).flatMap(\.lines).flatMap(\.strings).map(\.count).max() ?? 0
        var blocks: [Block] = []
        for section in tab.sections {
            let heading = heading(of: section)
            guard section.showsRows, !section.rows.isEmpty else {
                if let heading { blocks.append(Block(heading: heading, lines: [])) }
                continue
            }
            for (index, row) in section.rows.enumerated() {
                blocks.append(Block(heading: index == 0 ? heading : nil,
                                    lines: lines(of: row, width: width, gutter: gutter)))
            }
        }
        let byLine = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        return TabDocument(title: named(title, or: "Untitled song"), subtitle: byLine.isEmpty ? nil : byLine,
                           blocks: blocks,
                           footer: "Mapped in Red Moon. The notes are in order, placed where they play; "
                               + "how long each lasts isn't written.")
    }

    /// *Chorus · Bars 9–16*, *Verse 2 (as Verse 1) · Bars 17–24*, or *Start · 0:00–0:12*. `nil` for a
    /// song with no sections, which the Tab view draws without a heading.
    static func heading(of section: SongTab.Section) -> String? {
        var name: String
        switch section.heading {
        case .none: return nil
        case .start: name = "Start"
        case .marker(_, let label): name = label.isEmpty ? "Section" : label
        }
        if let sameAs = section.sameAs { name += " (as \(sameAs.label.isEmpty ? "Section" : sameAs.label))" }
        let range: String
        if let bars = section.bars {
            range = bars.count == 1 ? "Bar \(bars.lowerBound)" : "Bars \(bars.lowerBound)–\(bars.upperBound)"
        } else {
            range = "\(clock(section.start))–\(clock(section.end))"
        }
        return "\(name) · \(range)"
    }

    /// One row of a song's tab: a ruler of bar numbers, then each lane, a tab lane as its strings with
    /// anything it says in words on a line above them. Columns sit where `SongTabLayout.spread` puts them,
    /// rounded down, which keeps the gap it leaves between them.
    private static func lines(of row: SongTab.Row, width: Int, gutter: Int) -> [Line] {
        let span = SongTabLayout.width(of: row, available: Double(width) * row.widthFraction)
        let size = max(Int(span.rounded(.up)), 1)
        let lead = String(repeating: " ", count: gutter + 1)
        func place(_ time: TimeInterval) -> Int { min(max(Int(row.position(of: time) * span), 0), size - 1) }
        let barLines = row.ticks.map { place($0.time) }.filter { $0 > 0 }

        var ruler = [Character](repeating: " ", count: size)
        for tick in row.ticks {
            write(tick.bar.map(String.init) ?? clock(tick.time), into: &ruler, at: place(tick.time))
        }
        var out = [Line(kind: .ruler, text: trimmedEnd(lead + String(ruler)))]

        if row.lines.isEmpty {
            // A gap: the bars, with nothing in them.
            var empty = [Character](repeating: " ", count: size)
            for bar in barLines { empty[bar] = "|" }
            out.append(Line(kind: .strings, text: String(repeating: " ", count: gutter) + "|" + String(empty) + "|"))
        }
        for line in row.lines {
            let places = SongTabLayout.spread(line.columns, in: row, width: span).map { max(Int($0), 0) }
            let words = zip(line.columns, places).filter { !$0.0.mark.isFrets }
            if !words.isEmpty || !line.isTab {
                var text = [Character](repeating: " ", count: size)
                for (column, position) in words { write(self.text(of: column.mark), into: &text, at: position) }
                out.append(Line(kind: line.layer == .chords ? .chords : .names, text: trimmedEnd(lead + String(text))))
            }
            for (string, name) in line.strings.enumerated() {
                var staff = [Character](repeating: "-", count: size)
                for bar in barLines { staff[bar] = "|" }
                for (column, position) in zip(line.columns, places) {
                    guard case .frets(let cells) = column.mark,
                          let cell = cells.first(where: { $0.string == string }) else { continue }
                    write(cell.text, into: &staff, at: position)
                }
                out.append(Line(kind: .strings, text: pad(name, to: gutter, with: " ") + "|" + String(staff) + "|"))
            }
        }
        return out
    }

    /// What a mark writes in words. Frets are written on the strings, not here.
    private static func text(of mark: SongTab.Mark) -> String {
        switch mark {
        case .name(let name): name
        case .slash: "/"
        case .repeats(let passes): "↻×\(passes)"
        case .frets: ""
        }
    }

    // MARK: - Characters

    private static func named(_ title: String, or fallback: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func pad(_ text: String, to width: Int, with filler: Character) -> String {
        text.count >= width ? text : text + String(repeating: filler, count: width - text.count)
    }

    /// Write `text` over `buffer` from `index`, growing it when the text runs past its end.
    private static func write(_ text: String, into buffer: inout [Character], at index: Int) {
        for (offset, character) in text.enumerated() {
            let position = index + offset
            if position >= buffer.count {
                buffer.append(contentsOf: repeatElement(" ", count: position - buffer.count + 1))
            }
            buffer[position] = character
        }
    }

    private static func trimmedEnd(_ text: String) -> String {
        String(text.reversed().drop { $0 == " " }.reversed())
    }

    /// *1:05*: a time on the ruler or in a heading, for a song with no beat grid.
    static func clock(_ seconds: TimeInterval) -> String {
        let whole = max(Int(seconds.rounded(.down)), 0)
        return "\(whole / 60):" + String(format: "%02d", whole % 60)
    }
}
