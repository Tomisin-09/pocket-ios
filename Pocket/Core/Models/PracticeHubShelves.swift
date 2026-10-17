import Foundation

/// The pure rules behind the **Practice hub's shelves** (ADR 0257): which routines get a card and in
/// what order, what a card's third line says, which exercise categories get a tile, how loops group
/// by song, and which unsaved session the Today's session card offers.
///
/// Foundation-only and generic over the item, so every rule tests with plain values and no model
/// container (AGENTS.md: pure logic stays pure). Each is a rule that breaks silently: a shelf that
/// orders wrongly or shows a stale promise still renders, and still passes a build.
enum PracticeHubShelves {

    // MARK: - Routines (D3)

    /// How many routine cards the shelf shows before **New routine** — the three Home's rail showed.
    static let routineCardLimit = 3

    /// What the routine shelf needs to know about one routine to place it.
    struct RoutinePlacement {
        let isFavorite: Bool
        /// From the practice log, the same date the card prints, so a card's place and its words
        /// cannot disagree.
        let lastPractised: Date?
        let dateAdded: Date
    }

    /// The routines that get a card, in order (D3): **favourites first**, then the most recently
    /// practised, then the newest added. Within favourites the same order holds. Ties break on `id`
    /// so the shelf doesn't reshuffle between redraws.
    ///
    /// The caller passes **saved** routines only (ADR 0243 D2); the unsaved one has its own line on
    /// the Today's session card.
    static func routineShelf<Item, Key: Comparable>(_ items: [Item], limit: Int = routineCardLimit,
                                                    placement: (Item) -> RoutinePlacement,
                                                    id: (Item) -> Key) -> [Item] {
        guard limit > 0 else { return [] }
        return items
            .map { (item: $0, place: placement($0)) }
            .sorted { lhs, rhs in
                if lhs.place.isFavorite != rhs.place.isFavorite { return lhs.place.isFavorite }
                switch (lhs.place.lastPractised, rhs.place.lastPractised) {
                case let (left?, right?) where left != right: return left > right
                case (.some, .none): return true
                case (.none, .some): return false
                default: break
                }
                if lhs.place.dateAdded != rhs.place.dateAdded {
                    return lhs.place.dateAdded > rhs.place.dateAdded
                }
                return id(lhs.item) < id(rhs.item)
            }
            .prefix(limit)
            .map(\.item)
    }

    /// A routine card's third line (D3).
    enum RoutineCardLine: Equatable {
        /// A reminder is on and can be delivered: "Next: Tuesday 18:00".
        case nextReminder(Date)
        /// No deliverable reminder, but it has been practised: "Practised 5 times · yesterday".
        case practised(times: Int, last: Date?)
        /// Neither. The card says nothing rather than "Not yet" (ADR 0173 D6's reason).
        case nothing
    }

    /// The reminder wins, but **only when it can be delivered** (ADR 0186 D7): `.notDelivered` and
    /// `.noDays` fall through to the history, because naming a time nothing will arrive at is the
    /// promise the reminder footer was fixed for breaking.
    static func cardLine(reminder: PracticeReminderPlan.Status, sessions: Int,
                         lastPractised: Date?) -> RoutineCardLine {
        if case .next(let date) = reminder { return .nextReminder(date) }
        guard sessions > 0 else { return .nothing }
        return .practised(times: sessions, last: lastPractised)
    }

    /// "Practised 11 times · 3 days ago", or `nil` when it has never been run. The Routines library's
    /// row and the hub's card both read it, so they describe a routine the same way.
    static func historyLine(sessions: Int, last: Date?) -> String? {
        guard sessions > 0 else { return nil }
        var parts = [sessions == 1 ? "Practised once" : "Practised \(sessions) times"]
        if let last {
            parts.append(last.formatted(.relative(presentation: .named)))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Exercises (D5)

    /// One category tile: a template you have drills in, and how many.
    struct CategoryCount: Equatable {
        let template: ExerciseTemplate
        let count: Int
    }

    /// The category tiles, in the New exercise picker's order, **only for the kinds you have drills
    /// in** (D5). A retired template a drill was made under still gets its tile, where `displayOrder`
    /// keeps it, so no drill becomes unreachable from the hub.
    static func categoryTiles(_ templates: [ExerciseTemplate]) -> [CategoryCount] {
        let counts = Dictionary(templates.map { ($0, 1) }, uniquingKeysWith: +)
        return counts
            .map { CategoryCount(template: $0.key, count: $0.value) }
            .sorted { ExerciseTemplate.menuRank($0.template) < ExerciseTemplate.menuRank($1.template) }
    }

    /// Whether a category screen offers **New** (D5): only for a template the picker still offers.
    /// A Fingerstyle tile exists for the drills made before it was retired, and New there would make
    /// a drill the picker refuses to.
    static func offersNew(_ template: ExerciseTemplate) -> Bool {
        ExerciseTemplate.creatable.contains(template)
    }

    /// The instrument a category screen's **New** creates on (D5): the player's preferred one, unless
    /// the template can't be made for it — a bass player's Strumming or Chords & Strum, which the
    /// picker hides on bass (ADR 0164) — in which case guitar.
    static func newDrillInstrument(for template: ExerciseTemplate, preferred: Instrument) -> Instrument {
        ExerciseTemplate.creatable(for: preferred).contains(template) ? preferred : .guitar
    }

    // MARK: - Loops (D6)

    /// One song tile: the song and how many of its loops the shelf counts.
    struct SongCount<Song> {
        let song: Song
        let count: Int
    }

    /// The loops grouped by song (D6), the song **practised most recently first**, then by title, so
    /// the shelf opens on what you are working on. A loop with no song has no tile; it is still in
    /// the library behind **All**.
    static func songGroups<Loop, Song, Key: Hashable>(
        _ loops: [Loop], song: (Loop) -> Song?, id: (Song) -> Key, title: (Song) -> String,
        lastPractised: (Song) -> Date?
    ) -> [SongCount<Song>] {
        var order: [Key] = []
        var songs: [Key: Song] = [:]
        var counts: [Key: Int] = [:]
        for loop in loops {
            guard let owner = song(loop) else { continue }
            let key = id(owner)
            if songs[key] == nil { order.append(key); songs[key] = owner }
            counts[key, default: 0] += 1
        }
        return order
            .compactMap { key in songs[key].map { SongCount(song: $0, count: counts[key] ?? 0) } }
            .sorted { lhs, rhs in
                switch (lastPractised(lhs.song), lastPractised(rhs.song)) {
                case let (left?, right?) where left != right: return left > right
                case (.some, .none): return true
                case (.none, .some): return false
                default:
                    return title(lhs.song).localizedCaseInsensitiveCompare(title(rhs.song)) == .orderedAscending
                }
            }
    }

    // MARK: - The unsaved session (D2)

    /// The temporary session the Today's session card offers, or `nil`. ADR 0243 D3 keeps it to one,
    /// but a crash between its two writes can leave a stray; the newest is the one the player last
    /// started.
    static func unsavedSession<Item>(_ routines: [Item], isTemporary: (Item) -> Bool,
                                     startedAt: (Item) -> Date) -> Item? {
        routines.filter(isTemporary).max { startedAt($0) < startedAt($1) }
    }

    /// "Not saved yet · ~20 min · yesterday" — what the card says under the session's name.
    static func unsavedCaption(minutes: Int, when: Date) -> String {
        var parts = ["Not saved yet"]
        if minutes > 0 { parts.append("~\(minutes) min") }
        parts.append(when.formatted(.relative(presentation: .named)))
        return parts.joined(separator: " · ")
    }
}
