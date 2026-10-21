import Foundation

/// Pure, UI-free logic for the V1 **home hub** (ADR 0044 follow-on): the time-of-day
/// greeting bucket and the "recently practised" selection/ordering the screen shows. Kept
/// free of SwiftUI/SwiftData (it works over a `practicedAt` closure, not `Song` directly) so
/// the rules are unit-testable without a model container — the AGENTS.md "pure logic stays
/// pure" rule.
enum HomeFeed {

    /// Which part of the day it is, from a 24-hour clock hour. Drives the greeting line; the
    /// headline copy ("Ready to practice") is fixed, this only varies the lead-in.
    enum TimeOfDay {
        case morning, afternoon, evening, night

        /// 5–11 morning · 12–16 afternoon · 17–21 evening · else night. Hours outside 0...23
        /// fold via `((hour % 24) + 24) % 24` so a stray value still buckets sanely.
        static func at(hour: Int) -> TimeOfDay {
            switch ((hour % 24) + 24) % 24 {
            case 5..<12: return .morning
            case 12..<17: return .afternoon
            case 17..<22: return .evening
            default: return .night
            }
        }

        /// The lead-in greeting shown above the headline, name-free.
        var greeting: String {
            switch self {
            case .morning: return "Good morning"
            case .afternoon: return "Good afternoon"
            case .evening: return "Good evening"
            case .night: return "Late session"
            }
        }

        /// The lead-in greeting, personalised with the artist name when there is one (ADR 0113).
        /// A `nil`/blank name is first-class — it falls straight back to the name-free `greeting`,
        /// so an un-named profile reads exactly as before. Named copy stays in the Red Moon
        /// register: quiet, no exclamation marks, night reads "Late one, {name}". The name is
        /// trimmed; an all-whitespace name counts as unset.
        func greeting(name: String?) -> String {
            let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let trimmed, !trimmed.isEmpty else { return greeting }
            switch self {
            case .morning: return "Morning, \(trimmed)"
            case .afternoon: return "Afternoon, \(trimmed)"
            case .evening: return "Evening, \(trimmed)"
            case .night: return "Late one, \(trimmed)"
            }
        }
    }

    /// The single most-recently-practised item — the "Jump back in" subject — or `nil` when
    /// nothing has been practised yet (every `practicedAt` is `nil`). Generic over the item so
    /// it tests with plain values.
    static func mostRecentlyPracticed<Item>(_ items: [Item],
                                            practicedAt: (Item) -> Date?) -> Item? {
        items
            .compactMap { item in practicedAt(item).map { (item, $0) } }
            .max { $0.1 < $1.1 }?
            .0
    }

    /// Items ordered for the home "Your songs" list: most-recently-practised first, then the
    /// never-practised ones, each group broken by a `title` key for a stable, predictable order
    /// (case-insensitive). Total and deterministic so the list doesn't reshuffle between renders.
    static func orderedForHome<Item>(_ items: [Item],
                                     practicedAt: (Item) -> Date?,
                                     title: (Item) -> String) -> [Item] {
        items.sorted { lhs, rhs in
            switch (practicedAt(lhs), practicedAt(rhs)) {
            case let (left?, right?):
                if left != right { return left > right }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }
            return title(lhs).localizedCaseInsensitiveCompare(title(rhs)) == .orderedAscending
        }
    }

    /// Whether Home should draw the **Start here** card (ADR 0219) — the door to the bundled
    /// starter track.
    ///
    /// The rule is "this player owns no song of their own", expressed as a count so it stays pure:
    /// with the starter track already adopted that means exactly one song, without it, none. Once a
    /// real import lands the card retires and `resumeCard` takes the slot, which is the right
    /// hand-off — the starter track exists to be outgrown.
    ///
    /// The question is only ever "is this library empty". ADR 0219 D6 said so while the song was
    /// also a free taste, and it is still the card's whole reason now that every song is free to play
    /// (ADR 0237 D4, ADR 0256 D2).
    static func shouldOfferStarterTrack(totalSongs: Int, hasStarterTrack: Bool) -> Bool {
        hasStarterTrack ? totalSongs == 1 : totalSongs == 0
    }
}

/// Which kind of unit Home's **Jump back in** card offers (ADR 0193) — the player's stated
/// preference, not a record of what happened. `RawRepresentable` with a `String` raw value so it
/// works directly with `@AppStorage`.
///
/// **`Loop` joined in ADR 0267, still without a column.** `lastPracticed` exists on `Song`, `Routine`
/// and `Exercise` and nowhere else, and 0193 D1 refused to add one to `Loop` for a card. A loop's
/// date comes from the practice log instead (`loopResumeCandidates`), which already records every
/// loop run with its mode. One value covers all three modes: they are ways to practise a loop, not
/// three kinds of thing, and the card says which one it reopens.
enum JumpBackInPreference: String, CaseIterable, Identifiable {
    /// Whatever was touched last, of any kind — the default, and exactly what Home did before this
    /// setting existed.
    case mostRecent
    case song
    case routine
    case exercise
    case loop

    static let `default` = JumpBackInPreference.mostRecent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mostRecent: return "Most recent"
        case .song: return "Song"
        case .routine: return "Routine"
        case .exercise: return "Exercise"
        case .loop: return "Loop"
        }
    }

    /// The kind this preference pins the card to, or `nil` for `mostRecent`, which pins nothing.
    var pinnedKind: HomeFeed.ResumeKind? {
        switch self {
        case .mostRecent: return nil
        case .song: return .song
        case .routine: return .routine
        case .exercise: return .exercise
        case .loop: return .loop
        }
    }
}

extension HomeFeed {

    /// Which kind of unit the "Jump back in" card ends up carrying. `loop` is declared last, so it
    /// loses every tie (ADR 0267).
    enum ResumeKind: String, CaseIterable {
        case song, routine, exercise, loop
    }

    /// The kind the card should show, from the player's preference and the newest `lastPracticed`
    /// of each kind — or `nil` when nothing anywhere has been practised, which is the case where the
    /// card hides (as it always has on a fresh install).
    ///
    /// **A pinned preference that has nothing to show falls back to the most recent of any kind**
    /// rather than hiding the card. The alternative — honour the pin absolutely, blank the card —
    /// punishes a player for stating a preference before they own anything of that kind, and it is
    /// unobservable in the direction that matters: the moment a routine *is* practised, the pin
    /// takes over and never yields again.
    ///
    /// Ties break **song · routine · exercise · loop**, the declaration order, matching
    /// `mostRecentlyPracticed`'s first-maximal rule so two surfaces reading the same instant can't
    /// disagree about which unit that instant belongs to.
    static func resumeKind(preference: JumpBackInPreference,
                           songPracticedAt: Date?,
                           routinePracticedAt: Date?,
                           exercisePracticedAt: Date?,
                           loopPracticedAt: Date?) -> ResumeKind? {
        let practiced: [(kind: ResumeKind, date: Date?)] = [
            (.song, songPracticedAt), (.routine, routinePracticedAt), (.exercise, exercisePracticedAt),
            (.loop, loopPracticedAt)
        ]
        if let pinned = preference.pinnedKind,
           practiced.contains(where: { $0.kind == pinned && $0.date != nil }) {
            return pinned
        }
        return practiced
            .compactMap { entry in entry.date.map { (entry.kind, $0) } }
            .max { $0.1 < $1.1 }?
            .0
    }
}

// MARK: - A loop to jump back into (ADR 0267)

extension HomeFeed {

    /// A loop the player ran on its own, the mode they ran it in, and when. Read off the practice
    /// log, because `Loop` stores no date of its own (ADR 0193 D1).
    struct LoopResume: Equatable {
        let loopUID: UUID
        let mode: LoopRunMode
        let startedAt: Date
    }

    /// How many of the newest loop-mode runs Home reads to find one (`HomeView.recentLoopRuns`).
    ///
    /// A bound rather than the whole log, which Home refuses to query. Rows inside a routine, and
    /// rows on loops deleted since, are skipped after the fetch; if every one of the newest fifty is
    /// one of those, Home has no loop to offer and the card falls back as a pin with nothing behind it
    /// does (ADR 0193 D3). That takes fifty loop blocks in routines since the last loop run on its own.
    static let recentLoopRunLimit = 50

    /// The loops the card could offer, newest first, **one per loop** (its newest run).
    ///
    /// The planner reads loop recency off the same log (`PracticeLog.lastPracticedByUnit`, ADR 0137
    /// D2a), and this differs from it twice, both on purpose:
    /// - **It keeps the mode.** The planner asks *when did you last work on this material*; the card
    ///   has to know *which screen to reopen*, so an ear-training run reopens ear training.
    /// - **It drops runs inside a routine** (`routineUID != nil`). Those are the routine's: counting
    ///   them would put a routine's own loop block on the card in place of the routine just played.
    ///
    /// Rows that aren't a loop mode, and rows with no `unitUID`, are not loop runs and are skipped.
    /// The caller still has to find each loop and check it can open in some mode; a candidate is a
    /// row, not a promise that the loop survives.
    static func loopResumeCandidates(_ records: [SessionRecord]) -> [LoopResume] {
        var newest: [UUID: LoopResume] = [:]
        for record in records where record.routineUID == nil {
            guard let loopUID = record.unitUID, let mode = record.kind.loopRunMode else { continue }
            if let seen = newest[loopUID], seen.startedAt >= record.startedAt { continue }
            newest[loopUID] = LoopResume(loopUID: loopUID, mode: mode, startedAt: record.startedAt)
        }
        return newest.values.sorted { lhs, rhs in
            lhs.startedAt != rhs.startedAt ? lhs.startedAt > rhs.startedAt
                : lhs.loopUID.uuidString < rhs.loopUID.uuidString
        }
    }
}
