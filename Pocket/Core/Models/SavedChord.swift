import Foundation
import SwiftData

/// A **user-saved custom chord** (ADR 0095) — a bespoke voicing the player built in the custom placer
/// and chose to keep, so it can be re-inserted into any progression instead of rebuilt each time.
///
/// The voicing itself is stored as an **encoded `Data` blob** (`voicingData`), never as a stored
/// `ChordVoicing` attribute — the same "payload as a blob, not a child `@Model`" pattern the template
/// payloads use (`Exercise.templatePayload`, `StrumPattern`, `FretboardContent`), which sidesteps the
/// SwiftData custom-type / enum-attribute migration footgun (`docs/swiftdata-gotchas.md`). `name` is a
/// separate primitive column purely so the "My chords" list can sort/query without decoding every blob.
///
/// A brand-new model: adding it to the schema is **additive** (a new table; existing models untouched,
/// no data migration). No relationships — a saved chord is a standalone library entry, not owned by any
/// exercise (that's the whole point — it outlives the progression it was born in).
@Model
final class SavedChord {
    /// Stable business id — list diffing / stable identity, like `Loop`/`Recording` (the SwiftData
    /// `persistentModelID` is unstable before insert).
    var uid: UUID

    /// The chord's display name — the queryable/sortable column for the "My chords" list. Kept in step
    /// with the encoded voicing's own `name` at write time.
    var name: String

    /// When it was saved — newest-first ordering where wanted.
    var createdAt: Date

    /// The `ChordVoicing` as JSON. Decoded through `voicing`; encoded once at construction.
    var voicingData: Data

    init(uid: UUID = UUID(), name: String, createdAt: Date = Date(), voicingData: Data) {
        self.uid = uid
        self.name = name
        self.createdAt = createdAt
        self.voicingData = voicingData
    }

    /// Save an authored voicing — encodes it to the blob and mirrors its name into the column.
    convenience init(_ voicing: ChordVoicing) {
        let data = (try? JSONEncoder().encode(voicing)) ?? Data()
        self.init(name: voicing.name, voicingData: data)
    }

    /// The decoded voicing. Falls back to a name-only muted shape if the blob can't be read (it always
    /// can for anything this app wrote) so call sites never deal with an optional.
    var voicing: ChordVoicing {
        (try? JSONDecoder().decode(ChordVoicing.self, from: voicingData))
            ?? ChordVoicing(name, frets: Array(repeating: nil, count: ChordVoicing.stringCount))
    }
}

extension SavedChord {
    /// Whether an equivalent voicing (same name **and** geometry) is already in a set of saved voicings —
    /// the pure dedupe rule the Save action uses so tapping Save twice doesn't stack identical entries.
    /// Pure and SwiftUI/SwiftData-free so it's unit-tested (`ChordVoicing` is `Equatable`).
    static func isAlreadySaved(_ voicing: ChordVoicing, among existing: [ChordVoicing]) -> Bool {
        existing.contains(voicing)
    }
}
