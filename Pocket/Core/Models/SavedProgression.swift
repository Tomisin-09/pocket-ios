import Foundation
import SwiftData

/// **A progression the player wrote** (ADR 0218 D10) — saved as steps in a key, so it can be used in any
/// key and moved exactly. Reached from *Your progressions* in the *Use a progression* sheet and managed in
/// Toolkit → *My progressions*, beside My Chords (the ADR 0103 D5 split: insert from the sheet, manage in
/// the Toolkit).
///
/// Built on `SavedChord`'s pattern (ADR 0095): the content lives in an encoded blob (`stepsData`), never a
/// stored custom type, which is what keeps `ChordGrip.Quality` out of the schema
/// (`docs/swiftdata-gotchas.md`); `name` is a primitive column so the list can sort without decoding.
///
/// Model discipline per ADR 0011/0036: a business `uid`, and a declaration default on every other
/// non-optional attribute. A brand-new entity is additive on its own account, so registering it costs
/// no migration (the `PracticeFolder` and `CustomSkill` precedent) — which is why ADR 0189's D1–D3 have
/// nothing to ask of it.
@Model
final class SavedProgression {
    /// Stable business id — list identity and the archive's key (never `persistentModelID`, ADR 0090).
    var uid: UUID

    /// What the player calls it.
    var name: String = ""

    /// When it was written. The list sorts newest first.
    var createdAt: Date = Date.now

    /// A `SavedProgressionPayload` as JSON. Read through `payload`.
    var stepsData: Data = Data()

    init(uid: UUID = UUID(), name: String, createdAt: Date = .now, stepsData: Data) {
        self.uid = uid
        self.name = name
        self.createdAt = createdAt
        self.stepsData = stepsData
    }

    /// Save a draft — its name trimmed, its steps and key encoded.
    convenience init(_ draft: ProgressionDraft) {
        let payload = SavedProgressionPayload(steps: draft.steps, tonic: draft.tonic)
        self.init(name: draft.trimmedName, stepsData: payload.encoded)
    }

    /// The decoded content. A blob this build can't read gives an empty progression rather than a crash;
    /// the list still shows the name, and the row offers nothing to insert.
    var payload: SavedProgressionPayload {
        (try? JSONDecoder().decode(SavedProgressionPayload.self, from: stepsData)) ?? SavedProgressionPayload(steps: [])
    }

    var steps: [ProgressionStep] { payload.steps }

    /// Write an edited draft back in place — name and content together, so they never disagree. Ignores
    /// a draft that can't be saved (the form guards the button; this guards the model).
    func update(from draft: ProgressionDraft) {
        guard draft.canSave else { return }
        name = draft.trimmedName
        stepsData = SavedProgressionPayload(steps: draft.steps, tonic: draft.tonic).encoded
    }

    /// The draft an edit starts from.
    var draft: ProgressionDraft {
        ProgressionDraft(name: name, tonic: payload.tonic ?? ProgressionDraft.defaultTonic, steps: steps)
    }
}

/// What `SavedProgression.stepsData` holds. Versioned for a decode-time upgrade, never a store
/// migration (T4).
struct SavedProgressionPayload: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version: Int = SavedProgressionPayload.currentVersion
    var steps: [ProgressionStep]
    /// The key it was written in — where the sheet opens it. The progression moves to any key either way.
    var tonic: Int?

    init(steps: [ProgressionStep], tonic: Int? = nil) {
        self.steps = steps
        self.tonic = tonic
    }

    private enum CodingKeys: String, CodingKey { case version, steps, tonic }

    /// Every key but `steps` may be missing. A declared default does **not** survive a missing key under
    /// synthesized `Codable` — the whole decode fails — so the tolerance is written out.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? SavedProgressionPayload.currentVersion
        steps = try container.decode([ProgressionStep].self, forKey: .steps)
        tonic = try container.decodeIfPresent(Int.self, forKey: .tonic)
    }

    var encoded: Data { (try? JSONEncoder().encode(self)) ?? Data() }
}

/// The progression being written or edited (ADR 0218 D10) — pure, so everything the builder's controls
/// do is unit-tested and the form is only a skin over it.
struct ProgressionDraft: Equatable, Sendable {
    /// G — the same key *Use a progression* opens on.
    static let defaultTonic = 7
    /// The longest a single chord can be held in the builder.
    static let maxBars = 8

    var name: String = ""
    /// The key the builder reads chords against. Set it through `setTonic(_:)`, which keeps the chords.
    private(set) var tonic: Int = ProgressionDraft.defaultTonic
    var steps: [ProgressionStep] = []

    init(name: String = "", tonic: Int = ProgressionDraft.defaultTonic, steps: [ProgressionStep] = []) {
        self.name = name
        self.tonic = ((tonic % 12) + 12) % 12
        self.steps = steps
    }

    /// Change the key **without moving a chord**. A player who wrote G · C · D against C and then picks G
    /// is correcting the key, not asking for A · D · E — so every step is re-expressed from the new tonic:
    /// the chords stay put and only their numerals change (V · I · II becomes I · IV · V). Moving a
    /// progression is what the *Use a progression* sheet's key does, not this one.
    mutating func setTonic(_ newTonic: Int) {
        let normalized = ((newTonic % 12) + 12) % 12
        steps = steps.map { step in
            ProgressionStep(tonic + step.semitones - normalized, step.quality, bars: step.bars)
        }
        tonic = normalized
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// A name and at least one chord.
    var canSave: Bool { !trimmedName.isEmpty && !steps.isEmpty }

    var key: ProgressionKey { ProgressionKey(tonic: tonic, isMinor: steps.readsAsMinor) }

    /// The chords a key's scale offers without accidentals — I ii iii IV V vi. The diminished vii° is
    /// left out: no movable grip plays it, and every chord the builder offers must fret in every key (D5).
    static let inKey: [ProgressionStep] = [
        ProgressionStep(0), ProgressionStep(2, .minor), ProgressionStep(4, .minor),
        ProgressionStep(5), ProgressionStep(7), ProgressionStep(9, .minor)
    ]

    /// Add a chord at the end.
    mutating func append(_ step: ProgressionStep) {
        steps.append(step)
    }

    mutating func remove(at index: Int) {
        guard steps.indices.contains(index) else { return }
        steps.remove(at: index)
    }

    /// Move a chord `offset` places, as the editor's arrows do. Off either end is a no-op, never a wrap.
    mutating func move(at index: Int, by offset: Int) {
        let destination = index + offset
        guard steps.indices.contains(index), steps.indices.contains(destination) else { return }
        steps.insert(steps.remove(at: index), at: destination)
    }

    /// Hold a chord for `bars`, clamped to 1…`maxBars`.
    mutating func setBars(at index: Int, to bars: Int) {
        guard steps.indices.contains(index) else { return }
        steps[index].bars = min(Self.maxBars, max(1, bars))
    }
}
