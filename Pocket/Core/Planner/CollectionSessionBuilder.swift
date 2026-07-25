import Foundation

/// How a collection session's blocks are arranged — the **taste dial** (ADR 0118). Generation
/// draws the same deduped pool of drills/passages/play-throughs whatever the mode; the mode only
/// governs their order, so the player picks a disciplined arc or a shuffled set on demand.
///
/// Pure and SwiftData-/SwiftUI-free; the randomised modes take a **seed** so the builder stays a
/// deterministic function (AGENTS.md — "pure logic stays pure") that the UI can reshuffle by
/// passing a fresh seed.
enum OrderMode: String, CaseIterable, Identifiable {
    /// The ADR-0111 arc scaled up: deduped drills → passages → play-throughs. Deterministic.
    case structured
    /// Grouped like `.structured`, but shuffled *within* each group (drills among drills, etc.).
    case mixed
    /// Fully randomised order across every block — drills, passages and play-throughs interleaved.
    case shuffled

    var id: String { rawValue }

    /// Short label for the picker.
    var displayName: String {
        switch self {
        case .structured: return "Structured"
        case .mixed: return "Mixed"
        case .shuffled: return "Shuffled"
        }
    }

    /// One-line explanation shown under the picker.
    var detail: String {
        switch self {
        case .structured: return "Drills, then passages, then play-throughs."
        case .mixed: return "Same grouping, shuffled within each group."
        case .shuffled: return "Everything in a random order."
        }
    }
}

/// Builds a **provisional practice session for a whole song Collection** (ADR 0118) — the
/// collection-wide sibling of `SongRoutineBuilder` (ADR 0111). A collection is a `[String]` label
/// axis on `Song` (ADR 0033), not an entity, so this fans out across every song carrying the label,
/// pools their linked exercises / loops / play-throughs, **de-duplicates shared units by `uid`**
/// (a drill linked to three songs warms the set up once), **sizes** the result to a `SessionLength`
/// budget, and **arranges** it by a player-chosen `OrderMode`.
///
/// Emits planner `SessionBlock`s and nothing else, so the existing review-then-Save flow is reused
/// wholesale: `RoutineDetailView(generatedSession:)` materialises them into a sandbox and they
/// persist only on **Save** — Cancel/back leaves no orphan (the ADR-0111 seam). Pure and
/// SwiftData-**reading**-only (no mutation, no context), so it's unit-tested per AGENTS.md; never
/// grades the player (ADR 0070) — it schedules effort drawn from what the player linked.
enum CollectionSessionBuilder {

    /// Per-block practice budget for the generated focused blocks (minutes) — the routine model's
    /// default, so the number reads consistently with `SongRoutineBuilder`. ≤ `maxFocusedMinutes`,
    /// so a focus block never needs splitting.
    static let focusedMinutes = RoutineBudget.defaultFocusedMinutes

    /// The ceiling on the **whole** collection session (minutes) per preset — the total of focus work
    /// **plus** its rests **plus** the play-throughs must fit within this, so "Quick" really is a
    /// ≤10-minute sitting, "Focused" ≤30, and "Full" the hour. This is deliberately the *total*, not a
    /// focused budget: `SessionLength.minutes` is the V2 planner's focused allotment (warm-up/play sit
    /// outside it, ADR 0014 R1), but a collection session is a lighter, self-contained thing, so the
    /// number the player picks is a hard cap on the entire session — which is exactly what the Length
    /// tab's "~N min" estimate reads (ADR 0118).
    static func totalCap(for length: SessionLength) -> Int {
        switch length {
        case .quick: return 10
        case .focused: return 30
        case .full: return 60
        }
    }

    /// The smallest a **trimmed** focus block is allowed to be — below this the remaining budget is
    /// left for a play-through rather than spent on a stub of a drill. Keeps a tight Quick session from
    /// ending on a 1-minute fragment.
    static let minFocusMinutes = 4

    /// Play-throughs may fill at most this share of the session's total cap, so the focus work — the
    /// point of a practice sitting — always keeps the majority. Half leaves a real block of focus even
    /// on a Quick session with a song to finish on.
    static func playMinutesCap(for length: SessionLength) -> Int { totalCap(for: length) / 2 }

    /// The songs carrying the collection label (ADR 0033 `allOf` match), sorted by title for a
    /// deterministic pool before any ordering is applied.
    static func matchingSongs(_ collection: String, in songs: [Song]) -> [Song] {
        songs
            .filter { Labels.matches($0.collections, allOf: [collection]) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// Whether a *meaningful* session can be built: at least one linked exercise **or** one loop
    /// exists across the collection's songs. With neither, the session would be lone play-throughs
    /// (i.e. just playing the songs), so the entry point disables rather than generate an
    /// empty-feeling session — mirrors `SongRoutineBuilder.canBuild` (ADR 0111).
    static func canBuild(for collection: String, in songs: [Song]) -> Bool {
        matchingSongs(collection, in: songs).contains { !$0.linkedExercises.isEmpty || !$0.loops.isEmpty }
    }

    /// A count of the practice items a collection offers the builder — its **deduped** exercises +
    /// loops (the focus pool that fills the session) and the number of songs (the play-through pool).
    /// Surfaced on the configurator so the player sees what the session draws from *before* building,
    /// and understands that a thinly-linked collection yields a thinner session (ADR 0118).
    struct CollectionPool: Equatable {
        var exercises: Int
        var loops: Int
        var songs: Int

        /// Focus items (exercises + loops) — the drills/passages that actually fill the session.
        var focusItems: Int { exercises + loops }
    }

    /// The `CollectionPool` tally for `collection` — exercises and loops deduped by `uid` across the
    /// collection's songs (matching `sessionBlocks`' pool), and the song count.
    static func pool(for collection: String, in songs: [Song]) -> CollectionPool {
        let matches = matchingSongs(collection, in: songs)
        var exercises = Set<UUID>()
        var loops = Set<UUID>()
        for song in matches {
            song.linkedExercises.forEach { exercises.insert($0.uid) }
            song.loops.forEach { loops.insert($0.uid) }
        }
        return CollectionPool(exercises: exercises.count, loops: loops.count, songs: matches.count)
    }

    /// A friendly default name for the generated session — de-duplicated later by the review
    /// screen's `QuickSessionNaming`, so a repeat build won't collide.
    static func defaultName(for collection: String) -> String {
        collection.isEmpty ? "Collection session" : "\(collection) session"
    }

    /// A rough **total** length (minutes) a `length` preset yields over this collection — the sum of
    /// the generated blocks' minutes: focus work **plus** the rests between it **plus** the capped
    /// play-throughs. Always within `totalCap(for:)` (Quick ≤10, Focused ≤30, Full ≤60), since the
    /// generator budgets the whole session to that ceiling — so it's exactly what the configurator's
    /// Length tabs read as "~N min", a real sitting rather than a bare label.
    ///
    /// Estimated against the deterministic `.structured` arrangement — the worst case for rests, so
    /// the figure is the **upper bound** across order modes and the Length and Order dials stay
    /// independent (a Mixed/Shuffled build only comes in shorter). The review screen still shows the
    /// real length of what's actually built. Returns 0 when nothing can be built (an empty
    /// collection), so a caller can suppress the suffix.
    static func estimatedMinutes(for collection: String, in songs: [Song], length: SessionLength) -> Int {
        sessionBlocks(for: collection, in: songs, length: length, order: .structured, seed: 0)
            .reduce(0) { $0 + $1.minutes }
    }

    /// Cap on trailing play-through blocks, scaled to the session length so a Quick sitting isn't
    /// swallowed by play-throughs and a Full one still ends on a run or two (ADR 0118).
    static func playThroughCap(for length: SessionLength) -> Int {
        switch length {
        case .quick: return 1
        case .focused: return 2
        case .full: return 3
        }
    }

    /// The provisional session blocks for `collection` — deduped, sized to `length`, arranged by
    /// `order`, seeded for deterministic reshuffles. Focus blocks (exercises + loops) fill up to the
    /// focused-minute budget under the 60-minute ceiling (ADR 0014 R7); rests thread between
    /// directly-adjacent focus blocks (R3); capped play-throughs book-end the session (structured /
    /// mixed) or fold into the shuffle (shuffled). Unit refs match what `PracticePlanner.materialise`
    /// resolves against — exercises/loops by `uid`, songs by `PlannerID.uid(from:)` on `sourceID`.
    static func sessionBlocks(for collection: String,
                              in songs: [Song],
                              length: SessionLength,
                              order: OrderMode,
                              seed: UInt64) -> [SessionBlock] {
        let matches = matchingSongs(collection, in: songs)
        var generator = SeededGenerator(seed: seed)
        let cap = totalCap(for: length)

        // Play-throughs are the fixed-size finishers (a block ≈ a song's length), so budget them
        // first — bounded to `playMinutesCap` — then hand what's left of the total cap to the focus
        // work, which fills flexibly. Sizing this way keeps the *whole* session within `cap`.
        let playBlocks = playThroughBlocks(from: matches, order: order, length: length, using: &generator)
        let playUsed = playBlocks.reduce(0) { $0 + $1.minutes }
        let focusBudget = max(0, cap - playUsed)

        let focusUnits = orderedFocusUnits(from: matches, order: order, using: &generator)
        // `budgetFilled` charges a rest before every focus block after the first, so the focus work
        // *and its rests* fit within `focusBudget` at the worst case (all focus blocks adjacent, i.e.
        // the structured arc). Any order with fewer adjacencies only comes in shorter, so the cap
        // holds for every mode.
        let focusBlocks = budgetFilled(focusUnits, focusBudget: focusBudget)

        switch order {
        case .structured, .mixed:
            // Disciplined arc: focus blocks (rest-punctuated) lead, play-throughs trail as book-ends.
            return interleaveFocusRests(focusBlocks) + playBlocks
        case .shuffled:
            // One randomised run: fold play-throughs in with the focus blocks, then rest-punctuate
            // only where two focus blocks land adjacent.
            let combined = (focusBlocks + playBlocks).shuffled(using: &generator)
            return interleaveFocusRests(combined)
        }
    }

    // MARK: - Stages (internal, each independently testable)

    /// A focus candidate before budgeting: its planner ref, whether it's an exercise (for grouping)
    /// and a stable sort key (the unit's name) for deterministic ordering.
    struct FocusUnit: Equatable {
        var ref: PlannerUnitRef
        var isExercise: Bool
        var sortKey: String
    }

    /// The deduped focus pool across the collection, arranged per `order`.
    ///
    /// - `.structured`: exercises (by name) then loops (by name) — the ADR-0111 arc scaled up.
    /// - `.mixed`: same group order, shuffled within each group.
    /// - `.shuffled`: exercises then loops shuffled together into one run (final all-block shuffle
    ///   happens later once play-throughs join).
    static func orderedFocusUnits(from songs: [Song],
                                  order: OrderMode,
                                  using generator: inout SeededGenerator) -> [FocusUnit] {
        var exercises: [FocusUnit] = []
        var loops: [FocusUnit] = []
        var seen = Set<UUID>()

        for song in songs {
            for exercise in song.linkedExercises where seen.insert(exercise.uid).inserted {
                exercises.append(FocusUnit(ref: PlannerUnitRef(exercise.uid, .exercise),
                                           isExercise: true, sortKey: exercise.name))
            }
            for loop in song.loops where seen.insert(loop.uid).inserted {
                loops.append(FocusUnit(ref: PlannerUnitRef(loop.uid, .loop),
                                       isExercise: false, sortKey: loop.name))
            }
        }

        switch order {
        case .structured:
            return byName(exercises) + byName(loops)
        case .mixed:
            return exercises.shuffled(using: &generator) + loops.shuffled(using: &generator)
        case .shuffled:
            return (exercises + loops).shuffled(using: &generator)
        }
    }

    /// Greedily lay ordered focus units into `.focus` blocks, each `focusedMinutes`, so the focus work
    /// **and the rests that will punctuate it** fit within `focusBudget`. Each block after the first
    /// charges a `defaultRestMinutes` rest against the budget up front, so the assembled arc (which
    /// interleaves those rests) never overruns — even in the worst case where every focus block is
    /// adjacent. The final block is trimmed to what's left, but a would-be block below `minFocusMinutes`
    /// is dropped so the session doesn't end on a stub. The output is a real sitting, not an inventory.
    static func budgetFilled(_ units: [FocusUnit], focusBudget: Int) -> [SessionBlock] {
        var blocks: [SessionBlock] = []
        var used = 0
        for unit in units {
            let restCost = blocks.isEmpty ? 0 : RoutineBudget.defaultRestMinutes
            let available = focusBudget - used - restCost
            guard available >= minFocusMinutes else { break }
            let take = min(focusedMinutes, available)
            blocks.append(.focus(unit.ref, minutes: take, microRestEvery: nil))
            used += restCost + take
        }
        return blocks
    }

    /// Up to `playThroughCap` `.play` book-ends — one per song (its length rounded up, ≥ 1) — whose
    /// **total minutes** also stay within `playMinutesCap`, so play-throughs never crowd out the focus
    /// work in a tight session. Structured takes the first songs by title; mixed / shuffled pick a
    /// seeded subset so the set varies. A candidate that would overrun the play budget is skipped (a
    /// later, shorter one may still fit). Empty when the collection has no songs.
    static func playThroughBlocks(from songs: [Song],
                                  order: OrderMode,
                                  length: SessionLength,
                                  using generator: inout SeededGenerator) -> [SessionBlock] {
        guard !songs.isEmpty else { return [] }
        let countCap = playThroughCap(for: length)
        let minutesCap = playMinutesCap(for: length)
        let picked: [Song]
        switch order {
        case .structured:
            picked = Array(songs.prefix(countCap))
        case .mixed, .shuffled:
            picked = Array(songs.shuffled(using: &generator).prefix(countCap))
        }

        var blocks: [SessionBlock] = []
        var used = 0
        for song in picked {
            let take = playMinutes(for: song)
            guard used + take <= minutesCap else { continue }
            blocks.append(.play(PlannerUnitRef(PlannerID.uid(from: song.sourceID), .song), minutes: take))
            used += take
        }
        return blocks
    }

    /// Thread a rest between every pair of directly-adjacent `.focus` blocks (ADR 0014 R3) — a break
    /// resets attention between deliberate work. A play-through or the session edge already separates
    /// blocks elsewhere, so no rest is added there. Pure: returns a new sequence.
    static func interleaveFocusRests(_ blocks: [SessionBlock]) -> [SessionBlock] {
        var result: [SessionBlock] = []
        for (index, block) in blocks.enumerated() {
            if index > 0, isFocus(result.last), isFocus(block) {
                result.append(.rest(minutes: RoutineBudget.defaultRestMinutes))
            }
            result.append(block)
        }
        return result
    }

    // MARK: - Helpers

    private static func byName(_ units: [FocusUnit]) -> [FocusUnit] {
        units.sorted {
            let cmp = $0.sortKey.localizedCaseInsensitiveCompare($1.sortKey)
            if cmp != .orderedSame { return cmp == .orderedAscending }
            return $0.ref.uid.uuidString < $1.ref.uid.uuidString
        }
    }

    private static func isFocus(_ block: SessionBlock?) -> Bool {
        if case .focus = block { return true }
        return false
    }

    /// The play-through block's minutes — the song's length rounded up, at least 1 (matches
    /// `SongRoutineBuilder`).
    private static func playMinutes(for song: Song) -> Int {
        max(1, Int((song.duration / 60).rounded(.up)))
    }
}

/// A small seedable PRNG (SplitMix64) so `CollectionSessionBuilder`'s shuffled modes are pure and
/// deterministic for a given seed — the UI passes a fresh seed per build to reshuffle, and tests pin
/// the seed to assert order. Not cryptographic; ordering a practice session needs no more than this.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mix = state
        mix = (mix ^ (mix >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mix = (mix ^ (mix >> 27)) &* 0x94D0_49BB_1331_11EB
        return mix ^ (mix >> 31)
    }
}
