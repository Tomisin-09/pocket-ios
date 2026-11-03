import Foundation

/// **The Journal thread** (ADR 0286): which exercise or loop a feed item belongs to, how many items each
/// one has, one unit's items on their own, and the first and latest snapshot the thread's header shows.
///
/// Pure and UI-free like the rest of `JournalTimeline`: it reads model *properties* only, so tests build
/// owners uninserted. Its own file for the 400-line cap, the same reason `JournalOwnerFilter.swift` is.
extension JournalTimeline {

    /// An exercise or a loop, by its stable `uid`: what a thread is about.
    ///
    /// Never `persistentModelID`. The thread is pushed by this value, and a navigation destination keyed
    /// on the model's id pops itself when SwiftData swaps a temporary id for a permanent one (ADR 0090).
    struct UnitRef: Hashable {
        let kind: UnitKind
        let uid: UUID
    }

    /// Which of the two a thread is about. Beside `UnitRef` rather than inside it, for the nesting rule.
    enum UnitKind: Hashable { case exercise, loop }

    /// The unit an item belongs to, or `nil` for one that belongs to none.
    ///
    /// `nil` is right for a session note, a Just me note or take, a metronome note and a song's take,
    /// none of which is about one exercise or loop. It is also what a row whose unit was deleted gets: the
    /// row outlives the unit (ADR 0151), but the link to it is gone, so there is nothing to gather it
    /// with. A piece is always its loop's (ADR 0229).
    static func unit(for item: Item) -> UnitRef? {
        switch item {
        case .note(let entry): unit(loop: entry.loop, exercise: entry.exercise)
        case .take(let take): unit(loop: take.loop, exercise: take.exercise)
        case .piece(let piece): UnitRef(kind: .loop, uid: piece.loop.uid)
        }
    }

    /// Loop first, as `ownerLabel(loop:exercise:song:)` reads it, so the count and the caption beside it
    /// always name the same unit.
    private static func unit(loop: Loop?, exercise: Exercise?) -> UnitRef? {
        if let loop { return UnitRef(kind: .loop, uid: loop.uid) }
        if let exercise { return UnitRef(kind: .exercise, uid: exercise.uid) }
        return nil
    }

    /// The short name a thread goes by: the loop's name, or the exercise's. What the count's accessibility
    /// label, the hold menu's *Show all 6 for …* and the thread's title say.
    static func unitName(for item: Item) -> String? {
        switch item {
        case .note(let entry): unitName(loop: entry.loop, exercise: entry.exercise)
        case .take(let take): unitName(loop: take.loop, exercise: take.exercise)
        case .piece(let piece): unitName(loop: piece.loop, exercise: nil)
        }
    }

    static func unitName(loop: Loop?, exercise: Exercise?) -> String? {
        if let loop { return loop.name.isEmpty ? "Loop" : loop.name }
        if let exercise { return exercise.name.isEmpty ? "Exercise" : exercise.name }
        return nil
    }

    /// How many items each unit has, in **one pass**. The feed asks once per render and looks each row up,
    /// rather than counting the whole journal again for every row it draws.
    static func unitCounts(_ items: [Item]) -> [UnitRef: Int] {
        var counts: [UnitRef: Int] = [:]
        for item in items {
            if let unit = unit(for: item) { counts[unit, default: 0] += 1 }
        }
        return counts
    }

    /// One unit's items, order preserved.
    static func filter(_ items: [Item], unit: UnitRef) -> [Item] {
        items.filter { self.unit(for: $0) == unit }
    }

    // MARK: - First and latest

    /// A note's snapshot, as the thread's header compares it: an exercise's command BPM, with the rhythm
    /// it was measured in when the note kept one (ADR 0121), or a loop's mastery and command-tempo percent.
    enum Reading: Equatable {
        case bpm(Int, notesPerBeat: Int?)
        case loop(mastery: Int?, percent: Int?)
    }

    /// The first and the latest reading in a thread, and the day of the first.
    struct ReadingSpan: Equatable {
        let first: Reading
        let latest: Reading
        let since: Date
    }

    /// What a note snapshotted, or `nil` when it kept nothing to compare. An exercise note written before
    /// its BPM was measured has none, and a loop note with neither mastery nor a measured tempo has none.
    static func reading(of entry: JournalEntry) -> Reading? {
        switch entry.ownerKind {
        case .exercise:
            return entry.commandBpmAtEntry.map { .bpm($0, notesPerBeat: entry.commandNotesPerBeatAtEntry) }
        case .loop:
            let percent = LoopProgressFormat.percent(entry.commandTempoAtEntry)
            guard entry.masteryAtEntry != nil || percent != nil else { return nil }
            return .loop(mastery: entry.masteryAtEntry, percent: percent)
        case .session, .standalone, .metronome, .orphan:
            return nil
        }
    }

    /// The first and latest readings among a thread's notes, by when each was written, or `nil` when there
    /// is nothing to compare.
    ///
    /// Takes and pieces keep no snapshot, so only notes count. Fewer than two readings is nothing to
    /// compare, and so are two that say the same thing: "96 → 96 BPM" states one fact twice.
    static func readingSpan(_ items: [Item]) -> ReadingSpan? {
        let readings = items.compactMap { item -> (date: Date, reading: Reading)? in
            guard case .note(let entry) = item, let reading = reading(of: entry) else { return nil }
            return (entry.createdAt, reading)
        }.sorted { $0.date < $1.date }
        guard let first = readings.first, let latest = readings.last, readings.count >= 2,
              first.reading != latest.reading else { return nil }
        return ReadingSpan(first: first.reading, latest: latest.reading, since: first.date)
    }
}

extension JournalTimeline.ReadingSpan {

    /// The BPM half of the header's line, or `nil` for a loop's. *80 → 96 BPM · 8ths* when the rhythm held,
    /// and both ends in full when it changed, because 80 BPM in sixteenths and 96 in eighths are not the
    /// same speed of playing and one label would hide that.
    var bpmText: String? {
        guard case .bpm(let from, let fromRate) = first, case .bpm(let to, let toRate) = latest else { return nil }
        let latestLabel = LoopProgressFormat.bpmLabel(to, notesPerBeat: toRate)
        if fromRate == toRate { return "\(from) → \(latestLabel)" }
        return "\(LoopProgressFormat.bpmLabel(from, notesPerBeat: fromRate)) → \(latestLabel)"
    }
}
