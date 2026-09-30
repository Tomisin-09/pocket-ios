import Foundation
import SwiftData

/// **A tab the player wrote on the neck** (ADR 0235 D1, D8), kept in Toolkit ▸ *My tabs*. It belongs to no
/// song and no loop, and nothing plays it.
///
/// Built on `SavedProgression`'s pattern (ADR 0218): the content lives in an encoded blob (`tabData`), never
/// a stored custom type, which keeps `PieceLabel` out of the schema (`docs/swiftdata-gotchas.md`); `title`
/// and `changedAt` are primitive columns so the list sorts and shows without decoding. A business `uid`,
/// and a declaration default on every other non-optional attribute: a new entity is additive, so ADR 0189's
/// criteria have nothing to ask of it.
@Model
final class WrittenTab {
    /// Stable business id: list identity and the archive's key (never `persistentModelID`, ADR 0090).
    var uid: UUID

    /// What the player calls it. Empty until they name it; the list says *Untitled tab*.
    var title: String = ""

    var createdAt: Date = Date.now

    /// When it last changed. The list puts the tab changed last at the top.
    var changedAt: Date = Date.now

    /// A `WrittenTabPayload` as JSON. Read through `payload`.
    var tabData: Data = Data()

    init(uid: UUID = UUID(), title: String = "", createdAt: Date = .now, changedAt: Date = .now,
         tabData: Data = Data()) {
        self.uid = uid
        self.title = title
        self.createdAt = createdAt
        self.changedAt = changedAt
        self.tabData = tabData
    }

    /// The decoded content, or an empty tab for a blob this build can't read at all: the list still shows
    /// the title.
    var payload: WrittenTabPayload {
        WrittenTabPayload.decoded(from: tabData) ?? WrittenTabPayload(content: TabContent())
    }

    /// What the list and the reading view call it.
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? WrittenTab.untitled : trimmed
    }

    static let untitled = "Untitled tab"

    /// Write new content, stamped as changed now.
    func write(_ payload: WrittenTabPayload, at now: Date = .now) {
        tabData = payload.encoded
        changedAt = now
    }
}

/// What `WrittenTab.tabData` holds (ADR 0235 D8): the notes in order, the bar lines and sections between
/// them, and the strings they were placed on. Versioned for a decode-time upgrade, never a store migration.
///
/// A note of a kind this build can't read decodes as `nil`, an unnamed note, rather than losing the tab: the
/// same leniency `PieceTranscription.Tap` has. Every field past `labels` is optional, so an older build
/// reads a newer tab and ignores what it doesn't know.
struct WrittenTabPayload: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version: Int = WrittenTabPayload.currentVersion
    var labels: [PieceLabel?]
    var bars: [Int]?
    var sections: [TabSection]?
    var openMidi: [Int]?
    var tuningLabel: String?

    init(content: TabContent, openMidi: [Int]? = nil, tuningLabel: String? = nil) {
        labels = content.labels
        bars = content.bars.isEmpty ? nil : content.bars
        sections = content.sections.isEmpty ? nil : content.sections
        self.openMidi = openMidi
        self.tuningLabel = tuningLabel
    }

    var content: TabContent {
        TabContent(labels: labels, bars: bars ?? [], sections: sections ?? [])
    }

    /// Ready to draw: its notes, bar lines, sections and strings.
    var notes: PieceNotes {
        PieceNotes(labels: labels, openMidi: openMidi, tuningLabel: tuningLabel, bars: bars ?? [],
                   sections: sections ?? [])
    }

    private enum CodingKeys: String, CodingKey { case version, labels, bars, sections, openMidi, tuningLabel }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
        labels = try container.decode([LenientLabel].self, forKey: .labels).map(\.label)
        bars = try? container.decodeIfPresent([Int].self, forKey: .bars)
        sections = try? container.decodeIfPresent([TabSection].self, forKey: .sections)
        openMidi = try? container.decodeIfPresent([Int].self, forKey: .openMidi)
        tuningLabel = try? container.decodeIfPresent(String.self, forKey: .tuningLabel)
    }

    var encoded: Data { (try? JSONEncoder().encode(self)) ?? Data() }

    static func decoded(from data: Data) -> WrittenTabPayload? {
        try? JSONDecoder().decode(WrittenTabPayload.self, from: data)
    }
}

/// One note of a payload, read leniently: a label this build can't read is an unnamed note.
private struct LenientLabel: Decodable {
    let label: PieceLabel?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        label = container.decodeNil() ? nil : try? container.decode(PieceLabel.self)
    }
}
