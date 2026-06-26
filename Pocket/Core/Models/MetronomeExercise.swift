import Foundation
import SwiftData

/// A savable standalone-metronome **preset that is itself a practice exercise** (ADR
/// 0043): "Alternating picking", "Spider" — a named, persistent thing you return to,
/// each with its own working tempo, time signature, accents, subdivision and tempo-ramp
/// recipe. A list of these is the exercise library.
///
/// Deliberately **audio-free** and separate from `Loop`: a `Loop` is bound to an audio
/// file/region, an exercise has no audio source, so overloading `Loop` would leak audio
/// assumptions into a click-only entity. It is a standalone top-level entity in the
/// store (no relationship to `Song`).
///
/// Follows the established model discipline (ADR 0011/0012/0036): a `uid: UUID` business
/// id; **declaration defaults** on every non-optional attribute so SwiftData lightweight
/// migration stays additive (the CoreData 134110 mandatory-attribute rule — `init`-only
/// defaults fail and wipe the store); and any enum stored through a `String` backing
/// field, never as a raw enum attribute (the ADR 0036 enum-attribute rule).
///
/// Tempos are **absolute BPM** (no song to be a fraction of, unlike `Loop.speed`/
/// `commandTempo`). The goal is `targetTempo` and the day-to-day value `currentTempo` —
/// the term "command tempo" stays reserved for `Loop`'s measured achievement and must
/// not be conflated (ADR 0043).
@Model
final class MetronomeExercise {
    /// Stable business id — list diffing / selection / undo, like `Loop`/`Marker`.
    var uid: UUID

    /// The exercise name ("Alternating picking", "Spider"). Empty until named.
    var name: String = ""

    /// The day-to-day **working** tempo (absolute BPM) — where you practise today. The
    /// cross-session "light progress" number, nudged up manually over time (slice 7).
    var currentTempo: Int = 80
    /// The **goal** tempo (absolute BPM) you climb toward. The gap to `currentTempo` is
    /// the progress signal; also the automator's default ceiling.
    var targetTempo: Int = 120

    // Time signature: beats per bar (the click count and downbeat grouping) and the note
    // value (denominator — 4, 8, …). The standalone beat generator (slice 1) needs only
    // `beatsPerBar`; `noteValue` is carried so the signature round-trips and reads right.
    var beatsPerBar: Int = 4
    var noteValue: Int = 4

    /// Which beats accent, as 0-based indices within the bar. Default `[0]` — downbeat
    /// only. A scalar `[Int]` stays CloudKit-clean and migrates additively (declaration
    /// default, the CoreData 134110 rule), like `Loop.tags`.
    var accentBeats: [Int] = [0]

    /// Backing storage for `subdivision` — a plain `String`, **not** the enum (the
    /// SwiftData enum-attribute migration rule; see `Loop.loopTypeRaw`). Empty reads as
    /// `.none`. Declaration default so the column always has a value.
    var subdivisionRaw: String = Subdivision.none.rawValue

    /// How many clicks sound per beat — typed view over `subdivisionRaw`.
    var subdivision: Subdivision {
        get { Subdivision(rawValue: subdivisionRaw) ?? .none }
        set { subdivisionRaw = newValue.rawValue }
    }

    // Automator recipe — the persisted tempo ramp that makes "Spider" a full practice
    // prescription, not just a number. Pure stepping logic arrives in slice 4
    // (`MetronomeAutomator`); these are its stored parameters. Declaration defaults keep
    // migration additive, like `Loop`'s automator fields.
    var automatorEnabled: Bool = false
    /// BPM added at each step.
    var automatorStepBPM: Int = 5
    /// How many intervals between steps (e.g. every 4 *bars* or every 30 *seconds*).
    var automatorIntervalCount: Int = 4
    /// Backing storage for `automatorIntervalUnit` — a plain `String` (enum-attribute
    /// migration rule). Empty/unknown reads as `.bars`.
    var automatorIntervalUnitRaw: String = MetronomeIntervalUnit.bars.rawValue
    /// The ramp ceiling (absolute BPM). `nil` ⇒ defaults to `targetTempo`, so a ramp
    /// climbs toward the same goal the cross-session number tracks (ADR 0043). Optional
    /// with no declaration default, so it migrates additively as "unset → use target".
    var automatorCeiling: Int?

    /// Whether the automator steps every N **bars** or every N **seconds** — typed view
    /// over `automatorIntervalUnitRaw`.
    var automatorIntervalUnit: MetronomeIntervalUnit {
        get { MetronomeIntervalUnit(rawValue: automatorIntervalUnitRaw) ?? .bars }
        set { automatorIntervalUnitRaw = newValue.rawValue }
    }

    /// Open descriptive tags ("warmup", "picking"), routed through the shared `Labels`
    /// canonicaliser at the write site, like `Loop.tags`. Declaration default keeps
    /// migration additive (CoreData 134110 rule).
    var tags: [String] = []

    /// Optional free-text notes about the exercise.
    var notes: String = ""

    /// When the exercise was created — the default library sort key.
    var dateAdded: Date = Date.now

    init(name: String = "",
         currentTempo: Int = 80,
         targetTempo: Int = 120,
         beatsPerBar: Int = 4,
         noteValue: Int = 4,
         accentBeats: [Int] = [0],
         subdivision: Subdivision = .none,
         automatorEnabled: Bool = false,
         automatorStepBPM: Int = 5,
         automatorIntervalCount: Int = 4,
         automatorIntervalUnit: MetronomeIntervalUnit = .bars,
         automatorCeiling: Int? = nil,
         tags: [String] = [],
         notes: String = "",
         dateAdded: Date = .now) {
        self.uid = UUID()
        self.name = name
        self.currentTempo = currentTempo
        self.targetTempo = targetTempo
        self.beatsPerBar = beatsPerBar
        self.noteValue = noteValue
        self.accentBeats = accentBeats
        self.subdivisionRaw = subdivision.rawValue
        self.automatorEnabled = automatorEnabled
        self.automatorStepBPM = automatorStepBPM
        self.automatorIntervalCount = automatorIntervalCount
        self.automatorIntervalUnitRaw = automatorIntervalUnit.rawValue
        self.automatorCeiling = automatorCeiling
        self.tags = tags
        self.notes = notes
        self.dateAdded = dateAdded
    }

    /// The automator's resolved ceiling: its explicit `automatorCeiling` when set, else
    /// the exercise's `targetTempo` (the ADR 0043 default — a ramp climbs to the goal).
    var resolvedAutomatorCeiling: Int { automatorCeiling ?? targetTempo }

    /// The Italian tempo marking for the current working tempo (ADR 0043, slice 1) —
    /// "Andante", "Allegro", … Pure derived from `currentTempo`.
    var tempoMarking: TempoMarking { TempoMarking.marking(forBPM: Double(currentTempo)) }

    /// The "light progress" gap: BPM still to climb from `currentTempo` to `targetTempo`.
    /// Negative (clamped to 0) when the working tempo has reached or passed the goal —
    /// there's no remaining gap to show.
    var tempoGap: Int { max(0, targetTempo - currentTempo) }

    /// The time signature as a display string ("4/4", "6/8").
    var timeSignatureLabel: String { "\(beatsPerBar)/\(noteValue)" }

    /// A one-line recap of the full configuration — shared by the library row and the
    /// save/update confirmation so what you see is exactly what is stored. Reads like
    /// "97 BPM · 4/4 · Ramp to 117 BPM (+5 BPM every 4 bars)"; the ramp clause is dropped
    /// when the automator is off.
    var configurationSummary: String {
        var parts = ["\(currentTempo) BPM", timeSignatureLabel]
        if subdivision != .none { parts.append(subdivision.label.lowercased()) }
        if automatorEnabled {
            let cadence = automatorIntervalUnit.interval(count: automatorIntervalCount)
            parts.append("Ramp to \(resolvedAutomatorCeiling) BPM "
                         + "(+\(automatorStepBPM) BPM every \(cadence))")
        }
        return parts.joined(separator: " · ")
    }
}
