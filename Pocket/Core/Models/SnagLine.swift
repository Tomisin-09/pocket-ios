import Foundation

/// Where a snag's **line** lives (ADR 0238). A line is a note in a loop's Journal tied to its snag by
/// `JournalEntry.snagUID` (ADR 0234 D7), and it can now be written from the waveform's *Snags* panel as
/// well as from *Name the notes*. Both read the same line, so it's found across **all** the song's loops,
/// not only the one on screen: a snag is a point on the song (ADR 0200 D6), and the loop a line was
/// written in is an accident of where the player was standing at the time.
///
/// Pure and SwiftUI-free (AGENTS.md).
enum SnagLine {

    /// A loop's span, as the rule reads it.
    struct Span: Equatable {
        let uid: UUID
        let start: TimeInterval
        let end: TimeInterval
    }

    /// The loop a **new** line goes to: the one the snag was made under while it's still there (the loop
    /// its *Snags* row names, ADR 0203 D2), else the tightest loop whose span holds it now (the positional
    /// rule, ADR 0203 D1), the earlier of two the same length. `nil` when no loop has it, because a line
    /// needs a Journal and a song has none of its own.
    static func home(madeUnder: UUID?, at seconds: TimeInterval, among spans: [Span]) -> UUID? {
        if let madeUnder, spans.contains(where: { $0.uid == madeUnder }) { return madeUnder }
        return spans
            .filter { $0.start <= seconds && seconds <= $0.end }
            .min { ($0.end - $0.start, $0.start) < ($1.end - $1.start, $1.start) }?
            .uid
    }

    /// The kind of a **new** line. A stumble's is a 🧗 Struggle, which is what a snag made while playing is.
    /// One on a note snagged while naming is 👂 Ear, as *Name the notes* writes it, so its Journal caption
    /// still opens that note (ADR 0228). Never 🧩: the map reads a 🧩 note as the loop solved (ADR 0234 D7).
    static func kind(markedWhileNaming: Bool?) -> EntryKind {
        markedWhileNaming == true ? .ear : .struggle
    }

    /// Each snag's line by the snag's `uid`: the latest of `entries` tied to it, if there's more than one.
    static func lines(in entries: [JournalEntry]) -> [UUID: JournalEntry] {
        var lines: [UUID: JournalEntry] = [:]
        for entry in entries {
            guard let snag = entry.snagUID else { continue }
            if let held = lines[snag], held.createdAt >= entry.createdAt { continue }
            lines[snag] = entry
        }
        return lines
    }
}
