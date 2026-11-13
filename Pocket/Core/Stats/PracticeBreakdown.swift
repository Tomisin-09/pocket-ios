import Foundation

/// **What you played** (ADR 0241): a window's runs grouped by kind — exercises, loops, ear training,
/// improvising, play-alongs, the metronome — and inside each kind by the exercise, loop or song they
/// were.
///
/// **By what was played, not by where in the app.** The log holds practice runs and nothing else; it
/// has never seen the song library or the tuner, and it is not going to start timing screens (ADR 0241
/// D3). Time with the metronome is here because it is practice, logged as a run of its own kind by
/// the screen that plays it (ADR 0242) — not because the screen was open. Every row already says its
/// kind and which unit it was, so this is a grouping over data the app writes anyway.
///
/// **Ranked by minutes and nothing else (ADR 0070).** The largest group leads because it is the
/// largest. Nothing here says whether the mix was a good one.
///
/// Pure and SwiftData-free like the rest of `Core/Stats`: the view hands over `[SessionRecord]` and a
/// `Names` lookup built from its queries, so every naming rule — live name first, the logged name for
/// a deleted unit, an honest placeholder when neither exists — is here, where it can be tested.
enum PracticeBreakdown {

    /// The library **as it is now**, keyed the way a log row refers to it. A unit missing from here
    /// has been deleted. Built by the view from its `@Query`s.
    struct Names: Equatable, Sendable {
        var exercises: [UUID: String] = [:]
        var loops: [UUID: LoopName] = [:]
        /// Song titles by `Song.sourceID`.
        var songs: [String: String] = [:]
        /// The song an exercise is **for** (ADR 0111), by `Song.sourceID`. Only an exercise linked to
        /// exactly one song is here: one linked to several has no single song to count under, and
        /// counting it under each would make the songs add up to more than was played (ADR 0295 D3).
        var exerciseSongs: [UUID: String] = [:]
        /// The title of the long-term goal that names a song as its target, by `Song.sourceID`
        /// (ADR 0295 D4). The highest-ranked goal when two name the same song.
        var songGoals: [String: String] = [:]
    }

    /// A live loop as the log needs it: its name, and the song it belongs to by `Song.sourceID`.
    struct LoopName: Equatable, Sendable {
        let name: String
        let songSourceID: String?
    }

    /// One exercise, loop or song inside a group.
    struct Item: Identifiable, Equatable, Sendable {
        let id: String
        let name: String
        /// A second line — the song a loop belongs to, and whether the unit has been deleted.
        let detail: String?
        let seconds: Double
        /// The log cannot say what this was: a play-along logged before ADR 0241 recorded its song, or
        /// a unit deleted before the name was kept. Set in a quieter style, since it is a placeholder.
        let isUnnamed: Bool

        var minutes: Int { PracticeLog.minutes(seconds) }
    }

    /// One kind of practice and everything played under it.
    struct Group: Identifiable, Equatable, Sendable {
        let kind: PracticeRunKind
        let seconds: Double
        /// Largest first. **Empty for the metronome** (ADR 0242): its runs belong to no unit, so the
        /// one row it could hold would say "Metronome" again under a heading that already says it.
        /// A group with no items has nothing to open.
        let items: [Item]

        var id: PracticeRunKind { kind }
        var minutes: Int { PracticeLog.minutes(seconds) }
    }

    /// Group `records` by kind, then by unit, largest first at both levels.
    ///
    /// Ties break on a fixed order — kinds in declaration order, items by name — so a re-render can't
    /// shuffle two equal rows. Seconds are summed and rounded **once** per row, the rule the whole log
    /// follows, so three 40-second runs on one loop read as two minutes, not three.
    static func groups(_ records: [SessionRecord], names: Names) -> [Group] {
        var buckets: [PracticeRunKind: [String: Bucket]] = [:]
        for record in records.sorted(by: { $0.startedAt < $1.startedAt }) {
            let key = itemKey(record)
            var bucket = buckets[record.kind]?[key] ?? Bucket()
            bucket.seconds += record.durationSeconds
            // Oldest first, so the **latest** row's copies win: a loop renamed and then deleted is
            // remembered by the last name it was played under.
            bucket.latest = record
            buckets[record.kind, default: [:]][key] = bucket
        }

        let order = PracticeRunKind.allCases
        return buckets.compactMap { kind, items -> Group? in
            let resolved = items.compactMap { key, bucket -> Item? in
                guard let record = bucket.latest else { return nil }
                let described = describe(record, names: names)
                return Item(id: key, name: described.name, detail: described.detail,
                            seconds: bucket.seconds, isUnnamed: described.isUnnamed)
            }
            .sorted { lhs, rhs in
                lhs.seconds == rhs.seconds ? lhs.name < rhs.name : lhs.seconds > rhs.seconds
            }
            guard !resolved.isEmpty else { return nil }
            return Group(kind: kind, seconds: resolved.reduce(0) { $0 + $1.seconds },
                         items: kind == .metronome ? [] : resolved)
        }
        .sorted { lhs, rhs in
            guard lhs.seconds != rhs.seconds else {
                return (order.firstIndex(of: lhs.kind) ?? 0) < (order.firstIndex(of: rhs.kind) ?? 0)
            }
            return lhs.seconds > rhs.seconds
        }
    }

    // MARK: - Naming

    private struct Bucket {
        var seconds = 0.0
        var latest: SessionRecord?
    }

    private struct Described {
        let name: String
        let detail: String?
        let isUnnamed: Bool
    }

    /// Which row of its group a record belongs to. A unit is its `unitUID`; a play-along is its song,
    /// since a `Song` has no `uid`; and every play-along logged before the song was recorded shares
    /// one row, because the log cannot tell them apart.
    private static func itemKey(_ record: SessionRecord) -> String {
        switch record.kind {
        case .song:
            return record.songSourceID.map { "song:\($0)" } ?? "song:unrecorded"
        case .exercise, .loop, .earLoop, .improvise:
            return record.unitUID.map { "unit:\($0.uuidString)" } ?? "unit:none"
        case .metronome:
            return "metronome"
        case .other:
            return "other"
        }
    }

    /// The live name first, so a rename shows here the moment it is made; the name the row was logged
    /// under for a unit that has since been deleted; and a plain placeholder when the log never knew.
    private static func describe(_ record: SessionRecord, names: Names) -> Described {
        switch record.kind {
        case .exercise:
            if let uid = record.unitUID, let live = names.exercises[uid] {
                return Described(name: live.isEmpty ? "Untitled exercise" : live, detail: nil, isUnnamed: false)
            }
            return deleted(label: record.unitLabel, placeholder: "A deleted exercise", song: nil)

        case .loop, .earLoop, .improvise:
            if let uid = record.unitUID, let live = names.loops[uid] {
                let song = (live.songSourceID ?? record.songSourceID).flatMap { names.songs[$0] }
                return Described(name: live.name.isEmpty ? "Untitled loop" : live.name,
                                 detail: song, isUnnamed: false)
            }
            return deleted(label: record.unitLabel, placeholder: "A deleted loop",
                           song: record.songSourceID.flatMap { names.songs[$0] })

        case .song:
            guard let sourceID = record.songSourceID else {
                return Described(name: "Song not recorded", detail: nil, isUnnamed: true)
            }
            if let live = names.songs[sourceID] {
                return Described(name: live.isEmpty ? "Untitled song" : live, detail: nil, isUnnamed: false)
            }
            return deleted(label: record.unitLabel, placeholder: "A deleted song", song: nil)

        case .metronome:
            return Described(name: record.kind.label, detail: nil, isUnnamed: false)

        case .other:
            return Described(name: "From a newer version of Red Moon", detail: nil, isUnnamed: true)
        }
    }

    /// A unit that is no longer in the library. Named by what it was logged as when the row kept that,
    /// and marked deleted either way so it can't be mistaken for something you can still open.
    private static func deleted(label: String?, placeholder: String, song: String?) -> Described {
        guard let label else {
            return Described(name: placeholder, detail: song, isUnnamed: true)
        }
        return Described(name: label, detail: [song, "deleted"].compactMap { $0 }.joined(separator: " · ")
                                                 .capitalisingFirstLetter(),
                         isUnnamed: false)
    }
}

// MARK: - By song

extension PracticeBreakdown {

    /// How *What you played* is grouped (ADR 0295): by the kind of practice, or by the song it was on.
    /// `String`-raw so the choice is kept in `@AppStorage`, and the key and default live here so the
    /// two lists on the screen cannot spell them differently.
    enum Grouping: String, CaseIterable, Identifiable, Sendable {
        case kind, song

        static let storageKey = "practiceLogGrouping"
        static let standard = Grouping.kind

        var id: String { rawValue }

        /// The segment's title.
        var label: String {
            switch self {
            case .kind: "By kind"
            case .song: "By song"
            }
        }
    }

    /// One row of *What you played* in either grouping, with what opens under it. The list draws
    /// these and nothing else, so a kind and a song are laid out by one piece of code.
    struct Row: Identifiable, Equatable, Sendable {
        let id: String
        let title: String
        /// A second line: the goal a song is the target of, or that the song has been deleted.
        let detail: String?
        /// The log cannot say what this was. Set in a quieter style.
        let isUnnamed: Bool
        let seconds: Double
        /// Largest first. Empty when there is nothing to open.
        let items: [Item]

        var minutes: Int { PracticeLog.minutes(seconds) }
    }

    /// The rows for `grouping`, largest first.
    static func rows(_ records: [SessionRecord], names: Names, grouping: Grouping) -> [Row] {
        switch grouping {
        case .kind:
            groups(records, names: names).map { group in
                Row(id: "kind:\(group.kind.rawValue)", title: group.kind.groupLabel, detail: nil,
                    isUnnamed: false, seconds: group.seconds, items: group.items)
            }
        case .song:
            songRows(records, names: names)
        }
    }

    /// **By song** (ADR 0295): each song with the time spent on it, opening onto the kinds of work
    /// that time went on. Practice on no song keeps the row it has by kind.
    ///
    /// Every run lands in exactly one row, so the rows add up to the period's total, the same as the
    /// grouping by kind. A song's time is its play-alongs, every run on one of its loops (the loop's
    /// song **as it is now**, then the song the run was logged with), and the exercises linked to it
    /// and to no other song.
    ///
    /// **Ranked by minutes and nothing else (ADR 0070).** No song is marked as neglected.
    static func songRows(_ records: [SessionRecord], names: Names) -> [Row] {
        var homes: [SongHome: HomeBucket] = [:]
        for record in records.sorted(by: { $0.startedAt < $1.startedAt }) {
            let home = songHome(record, names: names)
            var bucket = homes[home] ?? HomeBucket()
            bucket.seconds += record.durationSeconds
            // A play-along's label is its song's title; a loop's is the loop's name. Only the first
            // can name a song that has since been deleted. Oldest first, so the latest wins.
            if record.kind == .song, let label = record.unitLabel { bucket.songLabel = label }
            let key = home.opensOntoUnits ? itemKey(record) : "kind:\(record.kind.rawValue)"
            var inner = bucket.items[key] ?? Bucket()
            inner.seconds += record.durationSeconds
            inner.latest = record
            bucket.items[key] = inner
            homes[home] = bucket
        }

        let order = PracticeRunKind.allCases
        return homes.map { home, bucket -> Row in
            let items = bucket.items.compactMap { key, inner -> (item: Item, rank: Int)? in
                guard let record = inner.latest else { return nil }
                let rank = order.firstIndex(of: record.kind) ?? 0
                guard home.opensOntoUnits else {
                    return (Item(id: key, name: record.kind.groupLabel, detail: nil,
                                 seconds: inner.seconds, isUnnamed: false), rank)
                }
                let described = describe(record, names: names)
                return (Item(id: key, name: described.name, detail: described.detail,
                             seconds: inner.seconds, isUnnamed: described.isUnnamed), rank)
            }
            .sorted { lhs, rhs in
                if lhs.item.seconds != rhs.item.seconds { return lhs.item.seconds > rhs.item.seconds }
                if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
                return lhs.item.name < rhs.item.name
            }
            .map(\.item)
            return row(for: home, bucket: bucket, items: items, names: names)
        }
        .sorted { lhs, rhs in
            if lhs.seconds != rhs.seconds { return lhs.seconds > rhs.seconds }
            return lhs.title == rhs.title ? lhs.id < rhs.id : lhs.title < rhs.title
        }
    }

    /// Where a run is counted when the list is by song.
    private enum SongHome: Hashable {
        case song(String)
        /// A loop or play-along whose song the log never knew.
        case unrecordedSong
        /// Exercises that are for no one song. Opens onto the exercises themselves.
        case exercises
        case metronome
        case other

        var opensOntoUnits: Bool { self == .exercises }
    }

    private struct HomeBucket {
        var seconds = 0.0
        var songLabel: String?
        var items: [String: Bucket] = [:]
    }

    private static func songHome(_ record: SessionRecord, names: Names) -> SongHome {
        switch record.kind {
        case .song:
            return record.songSourceID.map(SongHome.song) ?? .unrecordedSong
        case .loop, .earLoop, .improvise:
            let live = record.unitUID.flatMap { names.loops[$0] }
            return (live?.songSourceID ?? record.songSourceID).map(SongHome.song) ?? .unrecordedSong
        case .exercise:
            return record.unitUID.flatMap { names.exerciseSongs[$0] }.map(SongHome.song) ?? .exercises
        case .metronome:
            return .metronome
        case .other:
            return .other
        }
    }

    private static func row(for home: SongHome, bucket: HomeBucket, items: [Item], names: Names) -> Row {
        switch home {
        case .song(let sourceID):
            if let live = names.songs[sourceID] {
                return Row(id: "song:\(sourceID)", title: live.isEmpty ? "Untitled song" : live,
                           detail: names.songGoals[sourceID].map { "Goal · \($0)" },
                           isUnnamed: false, seconds: bucket.seconds, items: items)
            }
            return Row(id: "song:\(sourceID)", title: bucket.songLabel ?? "A deleted song",
                       detail: bucket.songLabel == nil ? nil : "Deleted",
                       isUnnamed: bucket.songLabel == nil, seconds: bucket.seconds, items: items)
        case .unrecordedSong:
            return Row(id: "song:unrecorded", title: "Song not recorded", detail: nil, isUnnamed: true,
                       seconds: bucket.seconds, items: items)
        case .exercises:
            return Row(id: "exercises", title: PracticeRunKind.exercise.groupLabel, detail: nil,
                       isUnnamed: false, seconds: bucket.seconds, items: items)
        case .metronome:
            // Nothing to open, for the reason the grouping by kind gives (ADR 0242).
            return Row(id: "metronome", title: PracticeRunKind.metronome.groupLabel, detail: nil,
                       isUnnamed: false, seconds: bucket.seconds, items: [])
        case .other:
            return Row(id: "other", title: PracticeRunKind.other.groupLabel, detail: nil,
                       isUnnamed: false, seconds: bucket.seconds, items: [])
        }
    }
}

private extension String {
    /// "deleted" → "Deleted", leaving "Slow Bend · deleted" as it is.
    func capitalisingFirstLetter() -> String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
