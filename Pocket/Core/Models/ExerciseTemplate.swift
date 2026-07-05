import Foundation

/// The **exercise template** an exercise is created from (ADR 0068, revised) — the single
/// user-facing answer to "what kind of drill is this": Strumming, Scales, Chords … A closed,
/// curated set, chosen once at creation and **immutable** thereafter. One choice fixes three
/// things at once: the authoring/detail **UI**, the runtime **renderer** (`ExerciseKind`), and the
/// library **section** the drill groups under. There is no free-text / custom template yet
/// (deferred): a new template is a deliberate, ADR-worthy addition with code behind it, never an
/// open extension point — the closed-set discipline the earlier free-text `category` axis lacked.
///
/// Today only `.strumming` has a bespoke surface; every other template runs on the shared
/// metronome underlay (`renderer == .metronome`) and shows the plain tempo settings until its own
/// editor/renderer ships. It is still a real, section-distinct, template-locked drill in the
/// meantime — the menu is honest about which have a special UI, not padded with duplicates.
///
/// Stored on `Exercise` through a `String` backing field (`templateRaw`), never a raw enum
/// attribute (the SwiftData enum-attribute migration rule, ADR 0036). The `init(storage:)`
/// fallback to `.basic` on an unrecognised value is the forward-compatibility guarantee — an older
/// build opening a newer template runs it as a plain tempo drill rather than failing.
enum ExerciseTemplate: String, CaseIterable, Identifiable, Codable {
    /// A plain click / tempo drill with no technique-specific surface — the flexible catch-all,
    /// and the fallback an unknown stored template decodes to.
    case basic
    /// A down / up / rest arrow lane over the click, authored from a `StrumPattern` (ADR 0065).
    case strumming
    case scales
    case chords
    case picking
    case legato
    case fingerstyle
    case rhythm
    case warmup
    case earTraining
    case theory

    var id: String { rawValue }

    /// Forgiving decode from the persisted raw value — unknown ⇒ `.basic` (forward compatibility,
    /// mirrors the old `ExerciseKind` fallback). Used by `Exercise.template`'s getter.
    init(storage raw: String) { self = ExerciseTemplate(rawValue: raw) ?? .basic }

    /// User-facing name — the create-card title and the library section header.
    var displayName: String {
        switch self {
        case .basic: return "Basic"
        case .strumming: return "Strumming"
        case .scales: return "Scales"
        case .chords: return "Chords"
        case .picking: return "Picking"
        case .legato: return "Legato"
        case .fingerstyle: return "Fingerstyle"
        case .rhythm: return "Rhythm"
        case .warmup: return "Warm-up"
        case .earTraining: return "Ear Training"
        case .theory: return "Theory"
        }
    }

    /// One-line description shown under the name on the create card.
    var blurb: String {
        switch self {
        case .basic: return "A plain tempo drill on the click."
        case .strumming: return "Down / up / rest arrow lane over the click."
        case .scales: return "Run scales in time — push the tempo clean."
        case .chords: return "Change chords cleanly on the beat."
        case .picking: return "Alternate-picking accuracy and speed."
        case .legato: return "Hammer-ons and pull-offs, even and smooth."
        case .fingerstyle: return "Fingerpicking patterns and independence."
        case .rhythm: return "Lock a rhythmic figure to the click."
        case .warmup: return "Loosen up before the real work."
        case .earTraining: return "Train intervals and recognition."
        case .theory: return "Drill fretboard and theory knowledge."
        }
    }

    /// SF Symbol for the create card and section — generic vocabulary, no protected marks.
    var iconName: String {
        switch self {
        case .basic: return "metronome"
        case .strumming: return "guitars"
        case .scales: return "stairs"
        case .chords: return "square.grid.3x3"
        case .picking: return "arrow.up.and.down"
        case .legato: return "wave.3.forward"
        case .fingerstyle: return "hand.point.up.braille"
        case .rhythm: return "waveform.path"
        case .warmup: return "flame"
        case .earTraining: return "ear"
        case .theory: return "book"
        }
    }

    /// The runtime **renderer** this template plays on (ADR 0065). Only Strumming has a bespoke
    /// surface today; every other template falls to the shared metronome underlay until its own
    /// renderer ships — so the run screen keeps working for every template from day one.
    var renderer: ExerciseKind { self == .strumming ? .strumming : .metronome }

    /// Whether the create / detail sheet shows a bespoke authoring editor for this template (vs
    /// only the basic tempo + meter settings). Only Strumming today; grows as renderers land.
    var hasBespokeEditor: Bool { self == .strumming }

    /// The starter content payload a freshly-created exercise of this template begins with — a
    /// folk strum pattern for Strumming (so it's never an empty lane), `nil` for payload-free
    /// templates. Encoded onto the model at creation via `setStrumPattern`.
    var defaultStrumPattern: StrumPattern? { self == .strumming ? .folk : nil }

    /// The templates offered in the create picker, in menu order: the flexible **Basic** catch-all
    /// first (the default, no-fuss drill), then the bespoke Strumming, then the other techniques.
    static let creatable: [ExerciseTemplate] = [
        .basic, .strumming, .scales, .chords, .picking,
        .legato, .fingerstyle, .rhythm, .warmup, .earTraining, .theory
    ]
}
