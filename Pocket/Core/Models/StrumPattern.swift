import Foundation

/// One slot's articulation in a strumming pattern (ADR 0065). A slot is a single, evenly-
/// spaced position on the bar's grid; a strum drill is a short ordered list of these.
/// Generic common-practice vocabulary, authored in-house (T8) — never anyone's protected
/// expression.
enum StrumSlot: String, CaseIterable, Identifiable, Codable {
    /// A downstroke (toward the floor).
    case down
    /// An upstroke (toward the ceiling). Two-letter musical term — the persisted rawValue
    /// stays "up" rather than a padded synonym.
    case up // swiftlint:disable:this identifier_name
    /// A silent slot — the hand keeps time but no strings sound (the "ghost" in D-DU-UDU).
    case rest

    var id: String { rawValue }

    /// Whether a string is actually struck here (vs a rest the strumming hand passes through).
    var isStroke: Bool { self != .rest }

    /// SF Symbol name the lane renderer draws. Direction alone distinguishes down from up;
    /// the rest is a faint dot. Kept on the model so the glyph vocabulary has one source, not
    /// baked into the view (the colour/theme discipline is T10; this is just which symbol).
    var symbolName: String {
        switch self {
        case .down: return "arrow.down"
        case .up: return "arrow.up"
        case .rest: return "circle.fill"
        }
    }

    /// Spoken/label description for accessibility.
    var label: String {
        switch self {
        case .down: return "Down"
        case .up: return "Up"
        case .rest: return "Rest"
        }
    }

    /// The next articulation when a slot is tapped in the editor: **down → up → rest → down**.
    /// Pure, so the editor stays a thin skin that just calls it (T5).
    var next: StrumSlot {
        switch self {
        case .down: return .up
        case .up: return .rest
        case .rest: return .down
        }
    }
}

/// A **strumming template's** content (ADR 0065 T4): a small, self-contained *recipe* of
/// down/up/rest slots laid over the bar, carrying its own `version` so the schema can evolve
/// with a decode-time upgrade and **no store migration** — it is persisted as an opaque
/// `Exercise.templatePayload: Data?` blob, never a child `@Model`, because the payload is
/// never relationally queried.
///
/// The pattern owns its own timing: `slotsPerBeat` fixes the grid resolution (2 = eighths,
/// 3 = triplets, 4 = sixteenths) and `slots` is one cycle's worth of articulations. Which
/// slot is sounding at a given moment is **pure timing math** (`activeSlotIndex(atBeat:)`),
/// SwiftUI-free and unit-tested (T5); the lane view is only a skin over it.
struct StrumPattern: Codable, Equatable {
    /// The schema version this build writes. Bump when the encoded shape changes, and add a
    /// decode-time upgrade rather than a store migration (T4).
    static let currentVersion = 1

    /// The version the blob was encoded at — for a future decode-time upgrade. A blob from a
    /// *newer* build than this one still decodes best-effort; if it can't, `Exercise`'s
    /// accessor returns nil and the run falls back to the metronome renderer (T5).
    var version: Int
    /// Evenly-spaced slots per beat — 1 = one per beat, 2 = eighths, 3 = triplets,
    /// 4 = sixteenths. Clamped to at least 1 so the grid never divides by zero.
    var slotsPerBeat: Int
    /// One cycle of articulations, in order across the bar. A `D-DU-UDU` folk pattern is
    /// eight eighth-note slots; an all-downstrokes drill is one `.down` per beat.
    var slots: [StrumSlot]

    init(slotsPerBeat: Int, slots: [StrumSlot], version: Int = StrumPattern.currentVersion) {
        self.version = version
        self.slotsPerBeat = max(1, slotsPerBeat)
        self.slots = slots
    }
}

// MARK: - Pure slot-timing math (T5 — SwiftUI-free, unit-tested)

extension StrumPattern {
    /// Number of slots in one cycle.
    var slotCount: Int { slots.count }

    /// Length of one cycle in beats — `slotCount / slotsPerBeat`. An eight-slot eighths
    /// pattern is four beats (one 4/4 bar); a four-slot quarters pattern is four beats too.
    var lengthInBeats: Double {
        slotCount > 0 ? Double(slotCount) / Double(max(1, slotsPerBeat)) : 0
    }

    /// The beat offset (from the start of the cycle) at which a slot begins. Lets the lane
    /// lay slots out on a beat grid without duplicating the spacing math.
    func beatOffset(ofSlot index: Int) -> Double {
        Double(index) / Double(max(1, slotsPerBeat))
    }

    /// Which slot is sounding at a continuous beat position — beats elapsed since the run's
    /// beat anchor, so the caller can pass `engine.currentBeat` plus a sub-beat fraction.
    ///
    /// The pattern **wraps**: position `lengthInBeats` returns to slot 0. A negative position
    /// (the count-in, before beat 0) and an empty pattern both return `nil` — nothing lit.
    /// Pure and total, so it is exhaustively unit-tested and the view only draws its result.
    func activeSlotIndex(atBeat beatPosition: Double) -> Int? {
        guard slotCount > 0, beatPosition >= 0, beatPosition.isFinite else { return nil }
        let absoluteSlot = Int((beatPosition * Double(max(1, slotsPerBeat))).rounded(.down))
        return absoluteSlot % slotCount
    }

    /// The articulation at a slot index, wrapping. Safe for any index.
    func slot(at index: Int) -> StrumSlot? {
        guard slotCount > 0 else { return nil }
        let wrapped = ((index % slotCount) + slotCount) % slotCount
        return slots[wrapped]
    }
}

// MARK: - Editing (pure — the authoring editor is a thin skin over these, T5)

extension StrumPattern {
    /// The pattern with the slot at `index` cycled to its next articulation (down → up → rest).
    /// Out-of-range indices return the pattern unchanged.
    func cyclingSlot(at index: Int) -> StrumPattern {
        guard slots.indices.contains(index) else { return self }
        var updated = slots
        updated[index] = updated[index].next
        return StrumPattern(slotsPerBeat: slotsPerBeat, slots: updated, version: version)
    }

    /// The pattern re-gridded to a new resolution over `beatsPerBar` — `beatsPerBar * slotsPerBeat`
    /// slots — remapping existing articulations **by beat position**, not by raw array index.
    ///
    /// Each new slot inherits the old slot that fell on the *same* beat offset; new positions that
    /// land between old slots are rests. This is what lets the editor switch quarters ↔ eighths ↔
    /// sixteenths sanely: refining keeps the strokes *on their beats* (a quarter downstroke stays on
    /// the downbeat instead of being crammed into the first half of the bar), and coarsening keeps
    /// the *on-beat* articulations instead of truncating the tail — so visiting a coarser resolution
    /// and returning no longer wipes the second half of the pattern. Dropping sub-beat strokes when
    /// coarsening is inherent (a coarser grid can't represent them), but it's now a deliberate
    /// downsample, not a bug.
    func resized(slotsPerBeat newSlotsPerBeat: Int, beatsPerBar: Int) -> StrumPattern {
        let perBeat = max(1, newSlotsPerBeat)
        let oldPerBeat = max(1, slotsPerBeat)
        let count = max(1, beatsPerBar) * perBeat
        var resizedSlots = Array(repeating: StrumSlot.rest, count: count)
        for newIndex in 0..<count {
            // The old-grid index sitting on this new slot's beat offset, if one lands exactly there.
            let oldPosition = Double(newIndex) * Double(oldPerBeat) / Double(perBeat)
            let rounded = oldPosition.rounded()
            guard abs(oldPosition - rounded) < 0.0001 else { continue }
            let oldIndex = Int(rounded)
            if slots.indices.contains(oldIndex) { resizedSlots[newIndex] = slots[oldIndex] }
        }
        return StrumPattern(slotsPerBeat: perBeat, slots: resizedSlots, version: version)
    }
}

// MARK: - Curated presets (T8 — common-practice patterns, authored in-house)

extension StrumPattern {
    /// All downstrokes, one per beat — the simplest strumming drill and a natural default.
    static func downstrokes(beatsPerBar: Int = 4) -> StrumPattern {
        StrumPattern(slotsPerBeat: 1, slots: Array(repeating: .down, count: max(1, beatsPerBar)))
    }

    /// The ubiquitous folk **D · D U · U D U** — eight eighth-note slots over a 4/4 bar, with
    /// the "and" of beats 1 and 3 rested (the classic ghost). Common-practice vocabulary (T8).
    static let folk = StrumPattern(
        slotsPerBeat: 2,
        slots: [.down, .rest, .down, .up, .rest, .up, .down, .up])
}
