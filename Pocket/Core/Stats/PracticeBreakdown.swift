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

private extension String {
    /// "deleted" → "Deleted", leaving "Slow Bend · deleted" as it is.
    func capitalisingFirstLetter() -> String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
