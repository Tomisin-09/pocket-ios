import Foundation

// MARK: - By goal

extension PracticeBreakdown {

    /// One long-term goal as the grouping by goal needs it (ADR 0298 D2): its name, and what counts
    /// toward it. Built by `GoalAttribution` from the planner's own resolution, so this file never
    /// decides what a skill means.
    struct GoalClaim: Equatable, Sendable {
        let id: UUID
        /// The name as shown everywhere else (`GoalTitle`).
        let title: String
        let isMet: Bool
        /// The goal's target song, or a set's songs (ADR 0299), by `Song.sourceID`. Every run *By song*
        /// counts under one of them counts here, whatever kind of work it was.
        let songSourceIDs: Set<String>
        /// The exercises and loops the planner would schedule for the goal, each with the kind of run
        /// that serves it. A loop claimed to solo over is not served by ear training on it.
        let units: Set<UnitClaim>
        /// When the goal was set. Read only to decide whether a goal with no time is listed: a goal
        /// is not shown at nothing for a stretch of practice that was over before it existed.
        var since: Date?
        /// A set opens onto its songs rather than kinds of work (ADR 0299 D5).
        var isSet = false

        /// Whether a goal with nothing against it in `records` still gets a row: unmet, and set
        /// before some of that practice happened.
        func isListedWithNoTime(during records: [SessionRecord]) -> Bool {
            guard !isMet else { return false }
            guard let since else { return true }
            return records.contains { $0.startedAt >= since }
        }

        /// Whether `record` counts toward this goal.
        func claims(_ record: SessionRecord, names: Names) -> Bool {
            if !songSourceIDs.isEmpty,
               let song = PracticeBreakdown.songSourceID(of: record, names: names), songSourceIDs.contains(song) {
                return true
            }
            guard let uid = record.unitUID else { return false }
            return units.contains(UnitClaim(uid: uid, kind: record.kind))
        }
    }

    /// A unit, and the kind of run on it that serves a goal.
    struct UnitClaim: Hashable, Sendable {
        let uid: UUID
        let kind: PracticeRunKind
    }

    /// The title of the row that holds practice no goal names.
    static let freePlayTitle = "Free play"

    /// **By goal** (ADR 0298): each long-term goal with the time that went toward it, and **Free
    /// play** for the rest, so what you set out to work on can be read against what you played.
    ///
    /// - **Every run lands in exactly one row** (D3), so the rows add up to the period's total. A run
    ///   that two goals claim counts under the higher-ranked one; unmet goals outrank met ones.
    /// - **A goal opens onto the kinds of work** its time went on, as a song does (ADR 0295 D2), and
    ///   **a set onto its songs**, each one at nothing included (ADR 0299 D5).
    ///   **Free play opens onto songs**, because what it answers is *what did the time go on instead*.
    /// - **An unmet goal is listed even with nothing against it** (D4), once any of the practice
    ///   listed happened after it was set. A goal that got no time while you practised is the reading
    ///   this grouping exists for; leaving it out would make the gap something to notice by absence.
    ///   A goal that did not exist yet had nothing to get, and a met goal with no time is finished,
    ///   not waiting: both are left out.
    ///
    /// **Ranked by minutes and nothing else (ADR 0070).** No goal is marked as behind, and nothing
    /// states a target or a share.
    static func goalRows(_ records: [SessionRecord], names: Names) -> [Row] {
        guard !records.isEmpty else { return [] }
        var counted: [UUID: [SessionRecord]] = [:]
        var freePlay: [SessionRecord] = []
        for record in records {
            if let goal = names.goals.first(where: { $0.claims(record, names: names) }) {
                counted[goal.id, default: []].append(record)
            } else {
                freePlay.append(record)
            }
        }

        var ranked: [(row: Row, rank: Int)] = []
        for (rank, goal) in names.goals.enumerated() {
            let mine = counted[goal.id] ?? []
            if mine.isEmpty, !goal.isListedWithNoTime(during: records) { continue }
            let items = goal.isSet ? setItems(mine, goal: goal, names: names) : kindItems(mine, names: names)
            ranked.append((Row(id: "goal:\(goal.id.uuidString)", title: goal.title,
                               detail: goal.isMet ? "Met" : nil, isUnnamed: false,
                               seconds: seconds(mine), items: items), rank))
        }
        if !freePlay.isEmpty {
            let songs = songRows(freePlay, names: names).map { song in
                Item(id: song.id, name: song.title, detail: song.detail, seconds: song.seconds,
                     isUnnamed: song.isUnnamed)
            }
            ranked.append((Row(id: "free-play", title: freePlayTitle, detail: "Practice no goal names",
                               isUnnamed: false, seconds: seconds(freePlay), items: songs),
                           names.goals.count))
        }
        return ranked
            .sorted { lhs, rhs in
                lhs.row.seconds == rhs.row.seconds ? lhs.rank < rhs.rank : lhs.row.seconds > rhs.row.seconds
            }
            .map(\.row)
    }

    /// A set's songs, largest first, then the ones with no time by title (ADR 0299 D5): *which songs
    /// have I left?* A song since deleted from the library is left out unless it has time to show.
    private static func setItems(_ records: [SessionRecord], goal: GoalClaim, names: Names) -> [Item] {
        let played = songRows(records, names: names).map { song in
            Item(id: song.id, name: song.title, detail: song.detail, seconds: song.seconds,
                 isUnnamed: song.isUnnamed)
        }
        let playedIDs = Set(played.map(\.id))
        let idle = goal.songSourceIDs
            .filter { !playedIDs.contains("song:\($0)") }
            .compactMap { sourceID -> Item? in
                guard let title = names.songs[sourceID] else { return nil }
                return Item(id: "song:\(sourceID)", name: title.isEmpty ? "Untitled song" : title,
                            detail: nil, seconds: 0, isUnnamed: false)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return played + idle
    }

    /// The kinds of work `records` were, largest first: the items under a goal.
    private static func kindItems(_ records: [SessionRecord], names: Names) -> [Item] {
        groups(records, names: names).map { group in
            Item(id: "kind:\(group.kind.rawValue)", name: group.kind.groupLabel, detail: nil,
                 seconds: group.seconds, isUnnamed: false)
        }
    }

    private static func seconds(_ records: [SessionRecord]) -> Double {
        records.reduce(0) { $0 + $1.durationSeconds }
    }
}

extension PracticeBreakdown.Grouping {
    /// The groupings the switch offers. *By goal* only once a long-term goal exists: before that,
    /// every minute would sit in one row (the rule ADR 0171 D10 applies to *Build from*).
    static func offered(hasGoals: Bool) -> [Self] {
        hasGoals ? allCases : allCases.filter { $0 != .goal }
    }

    /// The grouping to draw: the stored one, unless it is no longer offered.
    func effective(hasGoals: Bool) -> Self {
        Self.offered(hasGoals: hasGoals).contains(self) ? self : Self.standard
    }
}
