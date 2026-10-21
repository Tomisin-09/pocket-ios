import Foundation

/// Where one reference row is filed: the owner's kind and name, and a loop's song. Values only, so the
/// library's rules are tested without a store.
struct ReferencePlace: Equatable, Sendable {
    let kind: ReferencePlaceKind
    let name: String
    /// The song a loop belongs to. `nil` for the other three kinds.
    var parent: String?

    /// *Where it's used*'s second line: the kind, and a loop's song after it.
    var detail: String {
        guard let parent else { return kind.noun }
        return "\(kind.noun) · \(parent)"
    }
}

extension ReferenceLink {
    /// The place this row is filed on, or `nil` when it is kept for later (ADR 0264 D1). At most one
    /// owner is set, so the order of the checks decides nothing.
    var place: ReferencePlace? {
        if let exercise { return ReferencePlace(kind: .exercise, name: Self.placeName(exercise.name)) }
        if let song { return ReferencePlace(kind: .song, name: Self.placeName(song.title)) }
        if let loop {
            return ReferencePlace(kind: .loop, name: Self.placeName(loop.name),
                                  parent: loop.song.map { Self.placeName($0.title) })
        }
        if let routine { return ReferencePlace(kind: .routine, name: Self.placeName(routine.name)) }
        return nil
    }

    /// **Which source this row belongs to** (ADR 0264 D3): its file's name on disk for a file, else its
    /// address. A file attached in a second place is a second row naming the same file
    /// (`ReferenceLinkStore.attach`), so the two group as two rows of one link do. Every file written
    /// before that is named for its own row's uid, so no two of them share a key.
    ///
    /// A row with no address and no file can only be one written by hand or by a newer build; it stands
    /// alone, by its uid, rather than merging with every other such row.
    var sourceKey: String {
        if isAttachment { return "file:\(attachmentFileName)" }
        return urlString.isEmpty ? "row:\(uid.uuidString)" : "link:\(urlString)"
    }

    /// An owner with no name reads as the libraries read it, *Untitled*.
    private static func placeName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }
}

/// **One source in the References library** (ADR 0264 D3): every row that points at the same link, or
/// at the same file. A source used in two places is two rows, one per owner, each with its own note, and
/// the library draws them as one.
///
/// Reads `ReferenceLink` rows and writes nothing, so a test can hand it uninserted models.
struct ReferenceSource: Identifiable {
    /// The link's address as the store normalised it, or the file's name on disk for a file: a file
    /// attached in two places is one file, named by both rows (`ReferenceLink.sourceKey`).
    let id: String
    /// Every row of this source, newest first. Never empty.
    let rows: [ReferenceLink]

    /// The row saved last. Its date is the source's, so the library's order is *newest first*.
    var newest: ReferenceLink { rows[0] }

    /// Filed if any row has an owner. A source kept in one place and also kept for later is filed: it
    /// is in use, and the kept row shows on its screen (D3).
    var isFiled: Bool { rows.contains(where: \.isFiled) }

    var isAttachment: Bool { newest.isAttachment }

    /// Where it's used, newest first: one per filed row.
    var places: [ReferencePlace] { rows.compactMap(\.place) }

    /// Its places with any repeat left out, for a line that names each place once.
    var distinctPlaces: [ReferencePlace] {
        places.reduce(into: []) { kept, place in if !kept.contains(place) { kept.append(place) } }
    }

    /// The rows no owner holds. On a filed source, these are listed under *Kept for later* (D3).
    var keptForLater: [ReferenceLink] { rows.filter { !$0.isFiled } }

    /// What the source screen lists under *What you took from it*: on a source filed nowhere, each row
    /// that has a note, newest first. A filed source's notes sit under their places instead, so this is
    /// empty. A source filed nowhere can hold several rows (the same link on two drills, both deleted,
    /// D2), and with no place to tell them apart, a row with no note has nothing to show.
    var unfiledNotes: [ReferenceLink] { isFiled ? [] : rows.filter { $0.displayNote != nil } }

    /// The newest name the player typed, else what the newest row falls back to: its site, or its kind.
    var displayTitle: String {
        let named = rows.first { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return (named ?? newest).displayTitle
    }

    /// The first half of a row's second line: the site for a link, the kind for a file (D4).
    var origin: String {
        isAttachment ? newest.kind.capitalizedNoun : (newest.displayHost ?? newest.urlString)
    }

    /// The first line of the newest note anyone wrote on it, for the library's row.
    var noteLine: String? {
        rows.lazy.compactMap(\.displayNote).first
            .flatMap { $0.split(whereSeparator: \.isNewline).first.map(String.init) }
    }
}

/// **The References library's rules** (ADR 0264 D3, D4), as functions of the rows. The screen draws
/// what these return and decides nothing itself.
enum ReferenceLibrary {

    /// Every row grouped into sources, newest first, by `ReferenceLink.sourceKey`.
    static func sources(_ links: [ReferenceLink]) -> [ReferenceSource] {
        let grouped = Dictionary(grouping: links, by: \.sourceKey)
        return grouped.map { key, rows in ReferenceSource(id: key, rows: rows.sorted(by: isNewer)) }
            .sorted { lhs, rhs in
                lhs.newest.dateAdded == rhs.newest.dateAdded ? lhs.id < rhs.id
                                                             : lhs.newest.dateAdded > rhs.newest.dateAdded
            }
    }

    /// The source a row belongs to: what the source screen shows, opened from that row.
    static func source(containing uid: UUID, in links: [ReferenceLink]) -> ReferenceSource? {
        guard let anchor = links.first(where: { $0.uid == uid }) else { return nil }
        let key = anchor.sourceKey
        return ReferenceSource(id: key, rows: links.filter { $0.sourceKey == key }.sorted(by: isNewer))
    }

    /// The library's two sections (D4): *Not filed*, then *Everything*, which lists the rest. A source
    /// appears in one of them, never both.
    struct Sections {
        var notFiled: [ReferenceSource] = []
        var everything: [ReferenceSource] = []
        var isEmpty: Bool { notFiled.isEmpty && everything.isEmpty }
    }

    /// The sections, keeping only the sources that match `query`. Newest first in each, as `sources`
    /// hands them over.
    static func sections(_ sources: [ReferenceSource], matching query: String = "") -> Sections {
        let terms = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var sections = Sections()
        for source in sources where terms.isEmpty || matches(source, terms) {
            if source.isFiled {
                sections.everything.append(source)
            } else {
                sections.notFiled.append(source)
            }
        }
        return sections
    }

    /// Whether a search finds this source: in its names, its site or kind, any note on any row, or the
    /// name of any place it's used. Case and accents are ignored, as the other libraries' searches do.
    ///
    /// Built in typed statements, not one `+` chain: four arrays added in one expression is the shape CI's
    /// Xcode 16 timed out type-checking in slice 1 (`referenceAttachmentFileNames`).
    static func matches(_ source: ReferenceSource, _ query: String) -> Bool {
        var haystack: [String] = [source.origin]
        haystack += source.rows.map(\.displayTitle)
        haystack += source.rows.map(\.note)
        haystack += source.places.map(\.name)
        return haystack.contains { $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    /// The Toolkit row's trailing value (D4): *N to file* while anything is unfiled, otherwise how many
    /// sources there are, in the words the other rows the player fills use.
    static func toolkitValue(_ sources: [ReferenceSource]) -> String {
        let unfiled = sources.filter { !$0.isFiled }.count
        if unfiled > 0 { return "\(unfiled) to file" }
        return sources.isEmpty ? "None yet" : "\(sources.count) saved"
    }

    /// The undo toast's second line after an owner is deleted (D2): a delete that keeps something says
    /// what it kept. `nil` when it had none, so the toast reads as it always has.
    static func keptLine(references count: Int, plural: Bool = false) -> String? {
        guard count > 0 else { return nil }
        let whose = plural ? "Their" : "Its"
        return count == 1 ? "\(whose) reference stays in References"
                          : "\(whose) \(count) references stay in References"
    }

    // MARK: - The source screen's delete (D5)

    /// The button: plain while the source is in one place or none, and naming the count once it is in
    /// more, so a tap that empties two drills says so before the dialog does.
    static func deleteButtonTitle(places: Int) -> String {
        switch places {
        case 0, 1: "Delete"
        case 2: "Delete from both places…"
        default: "Delete from all \(places) places…"
        }
    }

    /// The confirmation's message, which names every place the source leaves (D5).
    static func deleteMessage(places: [ReferencePlace]) -> String {
        guard !places.isEmpty else {
            return "It isn't filed anywhere. It goes from References with what you wrote about it, and this "
                + "can't be undone."
        }
        let names = places.map(\.name).formatted(.list(type: .and))
        let notes = places.count == 1 ? "the note you wrote there" : "the note on each"
        return "It comes off \(names), with \(notes). This can't be undone."
    }

    // MARK: - Helpers

    /// Newest first; the uid breaks a tie so the order never changes between reads.
    private static func isNewer(_ lhs: ReferenceLink, _ rhs: ReferenceLink) -> Bool {
        lhs.dateAdded == rhs.dateAdded ? lhs.uid.uuidString < rhs.uid.uuidString : lhs.dateAdded > rhs.dateAdded
    }
}
