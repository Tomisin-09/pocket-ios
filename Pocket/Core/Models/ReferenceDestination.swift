import Foundation

/// **A place a reference can go** (ADR 0264 D5, D8): an exercise, a routine, a song or a loop, as the
/// owner picker lists it. Values only, so the picker's rules are tested without a store, and so the
/// share extension (slice 4), which can't open the store, can be handed the same rows from D9's owner
/// snapshot: a key, a kind, a name, a parent, and when it was last practised.
struct ReferenceDestination: Identifiable, Equatable, Codable, Sendable {
    /// The kind and the owner's own key, so two kinds can't collide: a uid, or a song's `sourceID`,
    /// since `Song` has no uid (`PracticeRun.songSourceID` keys a song the same way).
    let id: String
    let kind: ReferencePlaceKind
    let name: String
    /// A loop's song, or a song's artist. `nil` for an exercise, a routine, or a song with no artist.
    var parent: String?
    /// When it was last practised, or `nil` if it never has been. A loop keeps no date of its own and
    /// takes its song's, as the routine editor's *Recently Added* does.
    var lastPracticed: Date?

    /// The row's second line, in *Where it's used*'s grammar (`ReferencePlace.detail`): *Exercise*,
    /// *Song · Jack Trader*, *Loop · Slow Bend*.
    var detail: String {
        guard let parent, !parent.isEmpty else { return kind.noun }
        return "\(kind.noun) · \(parent)"
    }

    static func key(_ kind: ReferencePlaceKind, _ ownerKey: String) -> String { "\(kind.rawValue):\(ownerKey)" }
}

/// **The owner picker's rules** (ADR 0264 D5, D6, D8): which places are offered, which carry a lock,
/// which can't take this source, and in what order. *Attach to…* draws what these return, and the
/// share extension will draw the same.
enum ReferenceDestinationPicker {

    /// One place as the picker draws it.
    struct Row: Identifiable, Equatable, Sendable {
        let destination: ReferenceDestination
        /// Lapsed: it takes the reference, and opens again with the plan (D6).
        let isLocked: Bool
        /// Why this source can't go here, or `nil` when it can.
        var unavailable: String?

        var id: String { destination.id }
        var isPickable: Bool { unavailable == nil }

        /// The second line: the place's detail, then why it is locked or can't be picked.
        var detail: String {
            if let unavailable { return "\(destination.detail) · \(unavailable)" }
            if isLocked { return "\(destination.detail) · \(ReferenceAttachRules.lockedCaption)" }
            return destination.detail
        }
    }

    /// How many places *Recent* lists before *Show everything*.
    static let recentLimit = 5

    /// Why a place can't be picked.
    static let alreadyHere = "already here"
    static let full = "has \(ReferenceAttachmentStore.maxPerOwner) files"

    /// Every place the player may pick from (D6): what isn't offered is left out, and what's offered
    /// with a lock says so. `alreadyOn` are the places the source is filed on, and `full` the places
    /// that hold as many files as they may (`ReferenceAttachmentStore.maxPerOwner`), which matters only
    /// to a file.
    static func rows(_ destinations: [ReferenceDestination], for standing: PlanStanding,
                     alreadyOn: Set<String> = [], full: Set<String> = []) -> [Row] {
        destinations.compactMap { destination in
            let offer = ReferenceAttachRules.offer(destination.kind, for: standing)
            guard offer != .hidden else { return nil }
            var row = Row(destination: destination, isLocked: offer == .locked)
            if alreadyOn.contains(destination.id) {
                row.unavailable = alreadyHere
            } else if full.contains(destination.id) {
                row.unavailable = Self.full
            }
            return row
        }
    }

    /// *Recent*: the places practised most recently, newest first. A place never practised isn't
    /// recent, so a new install's picker opens on everything instead.
    static func recent(_ rows: [Row]) -> [Row] {
        Array(rows.filter { $0.destination.lastPracticed != nil }.sorted(by: isMoreRecent).prefix(recentLimit))
    }

    /// One kind's places, for *Show everything*.
    struct Group: Identifiable, Equatable, Sendable {
        let kind: ReferencePlaceKind
        let rows: [Row]
        var id: ReferencePlaceKind { kind }
        var title: String { kind.plural }
    }

    /// *Show everything*: the places by kind, exercises and routines first, as the Practice hub leads
    /// with them, each kind by name. A loop sorts under its song first. Empty kinds are left out.
    static func groups(_ rows: [Row]) -> [Group] {
        ReferencePlaceKind.pickerOrder.compactMap { kind in
            let members = rows.filter { $0.destination.kind == kind }.sorted(by: isAlphabetical)
            return members.isEmpty ? nil : Group(kind: kind, rows: members)
        }
    }

    /// A search: the places whose name or parent holds `query`, case and accents ignored, as the
    /// other libraries' searches are. Practised first, most recently first, then by name.
    static func matching(_ rows: [Row], _ query: String) -> [Row] {
        let terms = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !terms.isEmpty else { return rows }
        let found = rows.filter { row in
            let haystack: [String] = [row.destination.name, row.destination.parent ?? ""]
            return haystack.contains { $0.range(of: terms, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
        return found.sorted(by: isMoreRecent)
    }

    /// The search field's prompt, naming only what it can find (D6).
    static func searchPrompt(for standing: PlanStanding) -> String {
        standing == .neverBought ? "Search songs and loops" : "Search songs, loops, exercises…"
    }

    /// The row under *Recent* that opens every place.
    static func everythingTitle(for standing: PlanStanding) -> String {
        standing == .neverBought ? "Show all songs and loops" : "Show everything"
    }

    // MARK: - Order

    /// Most recently practised first; never practised last; then by name.
    private static func isMoreRecent(_ lhs: Row, _ rhs: Row) -> Bool {
        switch (lhs.destination.lastPracticed, rhs.destination.lastPracticed) {
        case let (left?, right?) where left != right: left > right
        case (.some, nil): true
        case (nil, .some): false
        default: isAlphabetical(lhs, rhs)
        }
    }

    /// By kind, then a loop's song, then name, then key, so the order never changes between reads.
    private static func isAlphabetical(_ lhs: Row, _ rhs: Row) -> Bool {
        let left = lhs.destination
        let right = rhs.destination
        if left.kind != right.kind { return left.kind.pickerRank < right.kind.pickerRank }
        if left.kind == .loop, left.parent != right.parent {
            return (left.parent ?? "").localizedStandardCompare(right.parent ?? "") == .orderedAscending
        }
        let byName = left.name.localizedStandardCompare(right.name)
        return byName == .orderedSame ? left.id < right.id : byName == .orderedAscending
    }
}

extension ReferencePlaceKind {
    /// The order *Show everything* lists the kinds in.
    static let pickerOrder: [ReferencePlaceKind] = [.exercise, .routine, .song, .loop]

    fileprivate var pickerRank: Int { Self.pickerOrder.firstIndex(of: self) ?? Self.pickerOrder.count }

    /// A section of *Show everything*.
    var plural: String {
        switch self {
        case .exercise: "Exercises"
        case .song: "Songs"
        case .loop: "Loops"
        case .routine: "Routines"
        }
    }
}
