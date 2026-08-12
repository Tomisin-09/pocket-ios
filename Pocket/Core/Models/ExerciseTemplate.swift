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
    case arpeggios
    case chords
    /// A strum groove played over a chord progression, sharing one beat clock (ADR 0065).
    case strumChords
    case picking
    case legato
    case fingerstyle
    case rhythm
    case warmup
    case earTraining
    case theory
    /// **The practice we don't model** (ADR 0136): a duration and the player's own written
    /// instructions. Sight-reading, transcribing, a teacher's assignment, singing while playing —
    /// practice that is real but has no surface here. The closed set stays closed: this is one more
    /// curated case, and the openness is confined to the player's prose inside it, which no code
    /// branches on. Deliberately **not** `.basic`, which is click-first *and* the unknown-template
    /// fallback — "the drill we couldn't parse" and "the drill the player defined" must not be the
    /// same value.
    case freeform

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
        case .arpeggios: return "Arpeggios"
        case .chords: return "Chords"
        case .strumChords: return "Chords & Strum"
        case .picking: return "Picking"
        case .legato: return "Legato"
        case .fingerstyle: return "Fingerstyle"
        case .rhythm: return "Rhythm"
        case .warmup: return "Warm-up"
        case .earTraining: return "Ear Training"
        case .theory: return "Theory"
        case .freeform: return "Your own practice"
        }
    }

    /// One-line description shown under the name on the create card.
    var blurb: String {
        switch self {
        case .basic: return "A plain tempo drill on the click."
        case .strumming: return "Down / up / rest arrow lane over the click."
        case .scales: return "Run scales in time — push the tempo clean."
        case .arpeggios: return "Run chord tones across the neck, in position."
        case .chords: return "Change chords cleanly on the beat."
        case .strumChords: return "Strum a groove while the chords change under it."
        case .picking: return "Alternate-picking accuracy and speed."
        case .legato: return "Hammer-ons and pull-offs, even and smooth."
        case .fingerstyle: return "Fingerpicking patterns and independence."
        case .rhythm: return "Lock a rhythmic figure to the click."
        case .warmup: return "Loosen up before the real work."
        case .earTraining: return "Train intervals and recognition."
        case .theory: return "Drill fretboard and theory knowledge."
        // Names what it is *for*, never what it lacks (F9) — the player is about to put the most
        // personal practice they have into it.
        case .freeform: return "Write your own — anything Pocket doesn't cover."
        }
    }

    /// SF Symbol for the create card and section — generic vocabulary, no protected marks.
    var iconName: String {
        switch self {
        case .basic: return "metronome"
        // `hand.draw` — the strumming *hand*, not a guitar. It used to be `guitars`, which
        // `LoopRunMode.improvise` also uses, so the Add-unit sheet showed Strumming and Improvise
        // wearing the same glyph (device pass 2026-08-05). Improvise keeps `guitars`: jamming over a
        // backing track is the more literal claim on it.
        case .strumming: return "hand.draw"
        case .scales: return "stairs"
        case .arpeggios: return "point.topleft.down.to.point.bottomright.curvepath"
        case .chords: return "square.grid.3x3"
        case .strumChords: return "square.stack"
        case .picking: return "arrow.up.and.down"
        case .legato: return "wave.3.forward"
        case .fingerstyle: return "hand.point.up.braille"
        case .rhythm: return "waveform.path"
        case .warmup: return "flame"
        case .earTraining: return "ear"
        case .theory: return "book"
        case .freeform: return "text.alignleft"
        }
    }

    /// The runtime **renderer** this template plays on (ADR 0065). Strumming has its bespoke arrow
    /// lane; the fretboard family (Scales, Picking, Legato, Fingerstyle, Warm-up) shares the one
    /// animated fretboard surface (build 2 — "build once, reuse many"); everything else still falls
    /// to the shared metronome underlay until its own renderer ships. A fretboard-family exercise
    /// with no drill payload yet still runs on the metronome (the accessor returns nil, T5), so the
    /// run screen keeps working for every template from day one.
    var renderer: ExerciseKind {
        switch self {
        case .strumming: return .strumming
        case .scales, .arpeggios, .picking, .legato, .fingerstyle, .warmup: return .fretboard
        case .chords: return .chords
        case .strumChords: return .strumChords
        // Freeform runs no material at all — no click, no board. Its screen is its own (F3/F4); the
        // renderer is the honest fallback and is never reached.
        case .basic, .rhythm, .earTraining, .theory, .freeform: return .metronome
        }
    }

    /// Which bespoke authoring editor the create / detail sheet shows for this template — or `nil`
    /// for templates that only expose the basic tempo + meter settings. **Template-specific**, not
    /// merely renderer-derived: several templates share the one fretboard *renderer* yet author
    /// differently. Strumming edits a `StrumPattern`; the warm-up-style families (Warm-up, Picking,
    /// Legato, Fingerstyle) declare a `FretboardRun` shape (finger pattern × span); Scales picks a
    /// preprogrammed `ScaleRun` from the scale library (ADR 0065 build 2, Slice 2). `.fretboardGrid`
    /// is the tap-to-place custom drill — retained as the general escape hatch, no template selects it
    /// by default today. Chords authors a `ChordProgression` from the voicing library. Strum & Chords
    /// authors a `StrumChordSheet` — both a `StrumPattern` and a `ChordProgression` together. The host
    /// sheet switches on this.
    enum BespokeEditor { case strumming, run, scale, arpeggio, chords, strumChords, fretboardGrid, freeform }
    var bespokeEditor: BespokeEditor? {
        switch self {
        case .strumming: return .strumming
        case .warmup, .picking, .legato, .fingerstyle: return .run
        case .scales: return .scale
        case .arpeggios: return .arpeggio
        case .chords: return .chords
        case .strumChords: return .strumChords
        // A text field is authoring (F2a) — the first template whose payload is prose rather than
        // musical structure, which is exactly why it needs its own branch instead of falling through
        // to the plain tempo settings it has no use for.
        case .freeform: return .freeform
        case .basic, .rhythm, .earTraining, .theory: return nil
        }
    }

    /// Whether the create / detail sheet shows *any* bespoke authoring editor (vs only the basic
    /// tempo + meter settings) — true for Strumming and the fretboard family; grows as renderers land.
    var hasBespokeEditor: Bool { bespokeEditor != nil }

    /// The starter **strum** pattern a freshly-created exercise begins with — a folk pattern for
    /// Strumming (so its lane is never empty), `nil` otherwise. Encoded at creation via
    /// `setStrumPattern`.
    var defaultStrumPattern: StrumPattern? { bespokeEditor == .strumming ? .folk : nil }

    /// The starter **fretboard content** a freshly-created fretboard-family exercise begins with — a
    /// generated chromatic warm-up for the run families, an A-minor-pentatonic run for Scales, or a
    /// spider-walk canvas for the custom grid. `nil` for non-fretboard templates. Encoded at creation
    /// via `setFretboardContent`.
    var defaultFretboardContent: FretboardContent? {
        switch bespokeEditor {
        case .run: return .run(.chromaticWarmup)
        case .scale: return .scale(.aMinorPentatonic)
        case .arpeggio: return .arpeggio(.aMinorSeventh)
        case .fretboardGrid: return .custom(.spiderWalk)
        case .strumming, .chords, .strumChords, .freeform, .none: return nil
        }
    }

    /// The starter **chord progression** a freshly-created Chords exercise begins with — **empty**, so
    /// the editor opens clean with just "Add chord" rather than a default turnaround the player has to
    /// delete (2026-07-13). `nil` for non-chords templates. Encoded at creation via `setChordProgression`.
    var defaultChordProgression: ChordProgression? {
        bespokeEditor == .chords ? .empty : nil
    }

    /// The starter **strum-chord sheet** a freshly-created Strum & Chords exercise begins with —
    /// **empty** (a rest-only groove over an empty progression, ADR 0086), so both surfaces open blank
    /// and the player builds each from scratch. `nil` for every other template. Encoded at creation via
    /// `setStrumChordSheet`.
    var defaultStrumChordSheet: StrumChordSheet? {
        bespokeEditor == .strumChords ? .empty : nil
    }

    /// **Every** template in canonical menu order — the grouping / section order for *existing*
    /// exercises (e.g. the routine-unit picker), so it includes the retired **Fingerstyle** and
    /// **Rhythm** templates: drills a player already created under those still group under their
    /// section even though the create picker no longer offers them.
    static let displayOrder: [ExerciseTemplate] = [
        .basic, .warmup, .strumming, .picking, .scales, .chords, .strumChords,
        .arpeggios, .legato, .fingerstyle, .rhythm, .earTraining, .theory, .freeform
    ]

    /// The templates offered in the **create** picker, in menu order (ADR 0087, 2026-07-13):
    /// **Basic** first (the default, no-fuss drill), then Warm-up and the techniques. **Fingerstyle**
    /// and **Rhythm** are dropped (fingerstyle out of scope; rhythm already covered by Strumming +
    /// Chords). **Ear Training** and **Theory** are no longer listed here (their "Coming Soon" rows were
    /// removed 2026-07-22): ear training shipped as a loop mode, not an exercise template (ADR 0104), so
    /// a placeholder promising a generic interval trainer would misdescribe the direction. The enum cases
    /// live on for the planner's `SkillFamilyMap`. The full `displayOrder` (above) drives grouping, so
    /// retiring a template from creation never hides drills already made under it.
    ///
    /// **Freeform is last** (ADR 0136): it is the answer to "my practice isn't in this list", so it
    /// reads best after the list it is the escape from — and putting it first would invite it to
    /// become the default for drills that deserve a real surface.
    static let creatable: [ExerciseTemplate] = [
        .basic, .warmup, .strumming, .picking, .scales, .chords, .strumChords,
        .arpeggios, .legato, .freeform
    ]

    /// The templates offered when creating a drill for `instrument` (ADR 0163). Guitar gets the whole
    /// list; **bass drops Strumming and Chords & Strum**, whose content is a down/up strum lane — a
    /// guitar technique, and a lane of arrows over a bass line describes something bassists don't do.
    /// Chords itself stays: bass chords are real (dyads and shells, `BassChordShape`).
    ///
    /// **Authoring-only**, like ADR 0127's rest rule. A drill already saved under a hidden template
    /// still opens, edits, runs and lists exactly as before — including one saved as bass while the
    /// create sheet's instrument control was inert (ADR 0116 S7). Withdrawing a template from the
    /// picker must never reach backwards into a library.
    static func creatable(for instrument: Instrument) -> [ExerciseTemplate] {
        guard instrument == .bass else { return creatable }
        return creatable.filter { $0 != .strumming && $0 != .strumChords }
    }
}
