import Foundation

/// **How the References library lays out its sources** (ADR 0275), chosen from its ⋯ menu and kept.
///
/// - **Newest:** ADR 0264 D4's two sections, *Not filed* then *Everything*. The default, so a library
///   opens as it always has.
/// - **Site:** a section per site a link points at, A to Z, then one per kind of file, since a file has
///   no site. A source not filed sits with the rest of its site, and its row says so.
/// - **Where it's used:** *Not filed*, then exercises, routines, songs and loops, in *Show everything*'s
///   order. A source on a drill and on a song is under both.
///
/// Newest first inside every section. The raw value is what `@AppStorage` keeps
/// (`AppSettings.Key.referencesGrouping`).
enum ReferenceGrouping: String, CaseIterable, Identifiable {
    case newest, site, place

    var id: String { rawValue }

    /// What the menu calls it.
    var label: String {
        switch self {
        case .newest: "Newest"
        case .site: "Site"
        case .place: "Where it's used"
        }
    }

    /// Whether its sections fold, as every other library's groups do (`CollapsibleLibrarySection`).
    /// *Newest*'s two sections are D4's and stay as drawn: folding *Not filed* would hide the list the
    /// Toolkit row counts.
    var collapses: Bool { self != .newest }

    /// Whether a row starts its second line with its site or kind. Not under *Site*, where the heading
    /// already says it: the same word on every row of a section says one fact twice.
    var rowShowsOrigin: Bool { self != .site }

    /// Whether a row filed nowhere says so. Only under *Site*: the other two give *Not filed* a section
    /// of its own.
    var rowMarksNotFiled: Bool { self == .site }
}

/// One section of the library: its heading, and its sources newest first.
struct ReferenceGroup: Identifiable {
    let title: String
    let sources: [ReferenceSource]
    /// Whether the heading shows how many it holds. Every section that folds does; under *Newest* only
    /// *Not filed* does, as D4 drew it.
    let showsCount: Bool

    var id: String { title }
}

extension ReferenceLibrary {

    static let notFiledTitle = "Not filed"
    static let everythingTitle = "Everything"
    /// A link with no site to read, which only a row written by hand or by a newer build can be.
    static let otherTitle = "Other"

    /// The library's sections under `grouping`, keeping only the sources that match `query`, with no
    /// empty section. Sources keep the order they arrive in, newest first, inside each section.
    static func groups(_ sources: [ReferenceSource], by grouping: ReferenceGrouping,
                       matching query: String = "") -> [ReferenceGroup] {
        let terms = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let found = terms.isEmpty ? sources : sources.filter { matches($0, terms) }
        let groups: [ReferenceGroup]
        switch grouping {
        case .newest: groups = newestGroups(found)
        case .site: groups = siteGroups(found)
        case .place: groups = placeGroups(found)
        }
        return groups.filter { !$0.sources.isEmpty }
    }

    private static func newestGroups(_ sources: [ReferenceSource]) -> [ReferenceGroup] {
        let split = sections(sources)
        return [ReferenceGroup(title: notFiledTitle, sources: split.notFiled, showsCount: true),
                ReferenceGroup(title: everythingTitle, sources: split.everything, showsCount: false)]
    }

    /// Where a source sits under *Site*, in the order the sections run: sites, then files, then other.
    private enum SiteKey: Comparable, Hashable {
        case site(String)
        case file(ReferenceLinkKind)
        case other

        var title: String {
            switch self {
            case .site(let host): host
            case .file(let kind): kind.pluralTitle
            case .other: ReferenceLibrary.otherTitle
            }
        }

        /// Sites A to Z, then the kinds of file in the order the app lists them.
        static func < (lhs: SiteKey, rhs: SiteKey) -> Bool {
            switch (lhs, rhs) {
            case let (.site(left), .site(right)): left.localizedStandardCompare(right) == .orderedAscending
            case let (.file(left), .file(right)): rank(left) < rank(right)
            default: lhs.band < rhs.band
            }
        }

        private var band: Int {
            switch self {
            case .site: 0
            case .file: 1
            case .other: 2
            }
        }

        private static func rank(_ kind: ReferenceLinkKind) -> Int {
            ReferenceLinkKind.attachmentKinds.firstIndex(of: kind) ?? ReferenceLinkKind.attachmentKinds.count
        }
    }

    private static func siteKey(of source: ReferenceSource) -> SiteKey {
        if source.isAttachment { return .file(source.newest.kind) }
        return source.newest.displayHost.map(SiteKey.site) ?? .other
    }

    /// One section per site, and per kind of file. `Dictionary(grouping:)` keeps each section's sources
    /// in the order they came, which is newest first.
    private static func siteGroups(_ sources: [ReferenceSource]) -> [ReferenceGroup] {
        let bySite = Dictionary(grouping: sources, by: siteKey(of:))
        return bySite.keys.sorted().map { key in
            ReferenceGroup(title: key.title, sources: bySite[key] ?? [], showsCount: true)
        }
    }

    /// *Not filed*, then one section per kind of place. A source is under every kind it's used on, and
    /// under *Not filed* only when it's used nowhere (D3: a filed source's kept row is on its screen).
    private static func placeGroups(_ sources: [ReferenceSource]) -> [ReferenceGroup] {
        let notFiled = ReferenceGroup(title: notFiledTitle, sources: sources.filter { !$0.isFiled },
                                      showsCount: true)
        let byKind = ReferencePlaceKind.pickerOrder.map { kind in
            ReferenceGroup(title: kind.plural,
                           sources: sources.filter { source in source.places.contains { $0.kind == kind } },
                           showsCount: true)
        }
        return [notFiled] + byKind
    }
}
