import Foundation

/// A named heading a written tab's section starts under (ADR 0235 D4): *Intro*, *Verse*, or the player's
/// own words, starting at a note.
struct TabSection: Codable, Equatable, Hashable, Sendable {
    /// The note it starts at, 0-based. Equal to the note count when it waits for the next note written.
    var start: Int
    var name: String
}

/// What a written tab holds (ADR 0235 D1, D4): its notes in order, and the bar lines and sections **between
/// them**, stored against note positions rather than mixed in with the notes. Joins, neighbours, the slot
/// and undo all keep counting notes, and a hammer-on across a bar line still works.
///
/// - A bar line at `b` sits before note `b`: never before the first note, and at most one past the last,
///   where it waits for the next note written.
/// - A section starts at a note, always on a new bar, so there is never a bar line where a section starts:
///   the heading is the bar.
///
/// Every change goes through `normalised`, so no rule has to be kept by hand. Pure and SwiftUI-free.
struct TabContent: Equatable, Sendable {
    var labels: [PieceLabel?]
    var bars: [Int]
    var sections: [TabSection]

    init(labels: [PieceLabel?] = [], bars: [Int] = [], sections: [TabSection] = []) {
        self.labels = labels
        self.bars = bars
        self.sections = sections
        self = normalised
    }

    var count: Int { labels.count }

    /// The names the section list offers first; any other name can be typed.
    static let sectionNames = ["Intro", "Verse", "Pre-chorus", "Chorus", "Bridge", "Solo", "Outro"]

    /// The rules, applied: names trimmed and empty ones dropped; starts inside `0...count`; where two
    /// sections start on one note the later one wins; bars sorted, once each, never at 0, never past
    /// `count`, never where a section starts; and a join or lead-in that no longer fits dropped, as Name the
    /// notes tidies (`NeckJoin.tidied`).
    var normalised: TabContent {
        var copy = self
        copy.labels = NeckJoin.tidied(labels)
        var byStart: [Int: TabSection] = [:]
        for section in sections {
            let name = section.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, (0...count).contains(section.start) else { continue }
            byStart[section.start] = TabSection(start: section.start, name: name)
        }
        copy.sections = byStart.values.sorted { $0.start < $1.start }
        let starts = Set(byStart.keys)
        copy.bars = Set(bars).filter { $0 >= 1 && $0 <= count && !starts.contains($0) }.sorted()
        return copy
    }

    /// The section a note is in, if any.
    func section(of note: Int) -> TabSection? {
        sections.last { $0.start <= note }
    }

    func section(startingAt position: Int) -> TabSection? {
        sections.first { $0.start == position }
    }

    func hasBar(at position: Int) -> Bool { bars.contains(position) }

    // MARK: - Changes

    /// A note put in at `index`: the bar line or heading at `index` stays with it, so it joins the bar and
    /// section of the note it went in before, and everything after moves along one. The note it went in
    /// before now follows a different note, so its join is dropped.
    func inserting(_ label: PieceLabel?, at index: Int) -> TabContent {
        let index = min(max(index, 0), count)
        var copy = self
        copy.labels.insert(label, at: index)
        copy.shiftAnchors(after: index, by: 1)
        copy.dropJoin(at: index + 1)
        return copy.normalised
    }

    /// The note at `index` taken out: everything after moves back one, a heading on it moves on to the note
    /// after (and goes if that note has its own), and the note after drops its join.
    func removing(at index: Int) -> TabContent {
        guard labels.indices.contains(index) else { return self }
        var copy = self
        copy.labels.remove(at: index)
        copy.shiftAnchors(after: index, by: -1)
        copy.dropJoin(at: index)
        return copy.normalised
    }

    /// Put a bar line before note `position`, or take it away. Refused before the first note, and where a
    /// section starts: the heading is already a bar.
    func togglingBar(at position: Int) -> TabContent {
        guard position > 0, position <= count, section(startingAt: position) == nil else { return self }
        var copy = self
        if let index = copy.bars.firstIndex(of: position) {
            copy.bars.remove(at: index)
        } else {
            copy.bars.append(position)
        }
        return copy.normalised
    }

    /// Start a section at `position`, or rename the one there. `nil` or an empty name takes the heading off,
    /// **keeping a bar line** where it was.
    func settingSection(at position: Int, name: String?) -> TabContent {
        guard (0...count).contains(position) else { return self }
        var copy = self
        copy.sections.removeAll { $0.start == position }
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            if position > 0, section(startingAt: position) != nil { copy.bars.append(position) }
        } else {
            copy.sections.append(TabSection(start: position, name: trimmed))
        }
        return copy.normalised
    }

    // MARK: - Helpers

    private mutating func shiftAnchors(after index: Int, by offset: Int) {
        bars = bars.map { $0 > index ? $0 + offset : $0 }
        sections = sections.map { $0.start > index ? TabSection(start: $0.start + offset, name: $0.name) : $0 }
    }

    private mutating func dropJoin(at index: Int) {
        guard labels.indices.contains(index), case .fretted(let notes, let into) = labels[index], into != nil
        else { return }
        labels[index] = .fretted(notes, into: nil)
    }
}
