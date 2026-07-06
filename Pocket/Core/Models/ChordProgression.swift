import Foundation

/// One step of a chord drill: a `ChordVoicing` held for a whole number of `beats` before the next
/// change. "Change chords cleanly on the beat" is the whole point, so duration is measured in beats,
/// not seconds — it rides the shared metronome clock at whatever tempo the exercise runs.
struct ChordChange: Codable, Equatable {
    var voicing: ChordVoicing
    /// How many beats this chord is held before advancing. Clamped to at least 1.
    var beats: Int

    init(_ voicing: ChordVoicing, beats: Int = 4) {
        self.voicing = voicing
        self.beats = max(1, beats)
    }
}

/// A **chord-changing drill's** content (ADR 0065) — an ordered progression of `ChordChange`s laid
/// over the click, carrying its own `version` so the schema can evolve with a decode-time upgrade
/// and **no store migration** (persisted as the opaque `Exercise.templatePayload` blob, never a
/// child `@Model`, mirroring `StrumPattern` / `FretboardContent`).
///
/// Which chord is active at a given moment is **pure timing math** (`activeIndex(atBeat:)`),
/// SwiftUI-free and unit-tested (T5); the live view is only a skin over it.
struct ChordProgression: Codable, Equatable {
    /// The schema version this build writes. Bump when the encoded shape changes, and add a
    /// decode-time upgrade rather than a store migration (T4).
    static let currentVersion = 1

    /// The version the blob was encoded at — for a future decode-time upgrade.
    var version: Int
    /// The progression, in order. One cycle; it **wraps** so the drill loops.
    var changes: [ChordChange]
    /// The key the Roman-numeral badges are read against, as a root pitch class (0 = C … 11 = B), or
    /// `nil` to **infer** it from the first chord's root. Player-settable in the editor.
    var keyRoot: Int?
    /// Whether the key is minor (natural-minor numeral spelling) rather than major.
    var keyIsMinor: Bool

    init(changes: [ChordChange], keyRoot: Int? = nil, keyIsMinor: Bool = false,
         version: Int = ChordProgression.currentVersion) {
        self.version = version
        self.changes = changes
        self.keyRoot = keyRoot
        self.keyIsMinor = keyIsMinor
    }

    // Explicit Codable so a pre-key blob (no `keyRoot` / `keyIsMinor`) still decodes — the fields
    // default to inferred/major rather than failing the whole payload (T4, forward compatibility).
    private enum CodingKeys: String, CodingKey { case version, changes, keyRoot, keyIsMinor }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        changes = try container.decode([ChordChange].self, forKey: .changes)
        keyRoot = try container.decodeIfPresent(Int.self, forKey: .keyRoot)
        keyIsMinor = try container.decodeIfPresent(Bool.self, forKey: .keyIsMinor) ?? false
    }
}

// MARK: - Pure change-timing math (T5 — SwiftUI-free, unit-tested)

extension ChordProgression {
    /// Number of chords in one cycle.
    var changeCount: Int { changes.count }

    /// Length of one cycle in beats — the sum of every chord's hold.
    var lengthInBeats: Int { changes.reduce(0) { $0 + max(1, $1.beats) } }

    /// The beat offset (from the start of the cycle) at which a change begins.
    func beatOffset(ofChange index: Int) -> Int {
        guard changes.indices.contains(index) else { return 0 }
        return changes[..<index].reduce(0) { $0 + max(1, $1.beats) }
    }

    /// Which chord is active at a continuous beat position — beats elapsed since the run's beat
    /// anchor, so the caller can pass `engine.currentBeat` plus a sub-beat fraction.
    ///
    /// The progression **wraps**: position `lengthInBeats` returns to change 0. A negative position
    /// (the count-in, before beat 0) and an empty progression both return `nil`. Pure and total, so
    /// it is exhaustively unit-tested and the view only draws its result.
    func activeIndex(atBeat beatPosition: Double) -> Int? {
        guard changeCount > 0, lengthInBeats > 0, beatPosition >= 0, beatPosition.isFinite else {
            return nil
        }
        let wrapped = beatPosition.truncatingRemainder(dividingBy: Double(lengthInBeats))
        var cumulative = 0
        for (index, change) in changes.enumerated() {
            cumulative += max(1, change.beats)
            if wrapped < Double(cumulative) { return index }
        }
        return changeCount - 1
    }

    /// The chord that follows `index`, wrapping — what the live view previews as "up next".
    func nextIndex(after index: Int) -> Int? {
        guard changeCount > 0 else { return nil }
        return (index + 1) % changeCount
    }

    /// The change at an index, wrapping. Safe for any index.
    func change(at index: Int) -> ChordChange? {
        guard changeCount > 0 else { return nil }
        let wrapped = ((index % changeCount) + changeCount) % changeCount
        return changes[wrapped]
    }

    /// The key root the numerals read against — the set `keyRoot`, or the first chord's root inferred
    /// when unset (an empty progression falls back to C).
    var resolvedKeyRoot: Int {
        keyRoot ?? changes.first?.voicing.rootPitchClass ?? 0
    }

    /// The Roman-numeral label for a voicing in this progression's key, or `nil` for an unrooted
    /// (empty) voicing.
    func numeral(for voicing: ChordVoicing) -> String? {
        guard let root = voicing.rootPitchClass else { return nil }
        return RomanNumeral.label(rootPitchClass: root, keyRoot: resolvedKeyRoot,
                                  keyIsMinor: keyIsMinor, isMinorChord: voicing.isMinorQuality,
                                  isDiminished: voicing.isDiminishedQuality)
    }
}

// MARK: - Editing (pure — the authoring editor is a thin skin over these, T5)

extension ChordProgression {
    /// The progression with `voicing` appended, held for `beats`.
    func appending(_ voicing: ChordVoicing, beats: Int = 4) -> ChordProgression {
        ChordProgression(changes: changes + [ChordChange(voicing, beats: beats)], version: version)
    }

    /// The progression with the change at `index` removed (never below one change).
    func removingChange(at index: Int) -> ChordProgression {
        guard changes.indices.contains(index), changeCount > 1 else { return self }
        var updated = changes
        updated.remove(at: index)
        return ChordProgression(changes: updated, version: version)
    }

    /// The progression with the change at `index` re-voiced to `voicing`, its hold unchanged.
    func replacingVoicing(at index: Int, with voicing: ChordVoicing) -> ChordProgression {
        guard changes.indices.contains(index) else { return self }
        var updated = changes
        updated[index] = ChordChange(voicing, beats: updated[index].beats)
        return ChordProgression(changes: updated, version: version)
    }

    /// The progression with the change at `index` held for `beats` (clamped ≥ 1), its voicing kept.
    func settingBeats(at index: Int, to beats: Int) -> ChordProgression {
        guard changes.indices.contains(index) else { return self }
        var updated = changes
        updated[index] = ChordChange(updated[index].voicing, beats: beats)
        return ChordProgression(changes: updated, version: version)
    }
}
