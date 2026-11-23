import Foundation

/// **A moon theme** (ADR 0311): which colour family Practice wears, and where each space goes so none
/// of them sits beside it. Eight of them, and Blood Moon is the default and the brand (D1).
///
/// **A value, not only a switch** (D8). The Theme screen draws themes that aren't the current one, so
/// each case carries its families and anything can ask `MoonTheme.harvest.practice`. What the app draws
/// *in* reads the current theme from the environment (`\.moonTheme`), set once at the `PocketApp` root.
///
/// **Foundation only.** It names colour sets, never colours, so the mapping is a unit test and the
/// values stay in `Colors.xcassets`, the one place they live (D9: a theme is a mapping onto shared
/// families, never a second baked palette).
enum MoonTheme: String, CaseIterable, Sendable {
    case blood
    case blue
    case jade
    case corn
    case silver
    case pink
    case harvest
    case cold

    /// What no stored choice means, and what every existing install keeps (D1): nothing migrates.
    static let standard = MoonTheme.blood

    /// The name the Theme screen and the Settings rows say.
    var name: String {
        switch self {
        case .blood: "Blood Moon"
        case .blue: "Blue Moon"
        case .jade: "Jade Moon"
        case .corn: "Corn Moon"
        case .silver: "Silver Moon"
        case .pink: "Pink Moon"
        case .harvest: "Harvest Moon"
        case .cold: "Cold Moon"
        }
    }

    /// The card's one line (D7), as the ADR wrote it for the screen.
    var line: String {
        switch self {
        case .blood: "The moon in the Earth's shadow, turned red."
        case .blue: "A second full moon in one month."
        case .jade: "Sea green, cool and clear."
        case .corn: "September's full moon, in harvest olive."
        case .silver: "Moonlight with the colour taken out."
        case .pink: "April's full moon, named for a spring flower."
        case .harvest: "The low orange moon of autumn."
        case .cold: "December's full moon."
        }
    }

    /// The family Practice wears (D2, D4), and with it the mastery dots and the song player's bars.
    var practice: ColorFamily {
        switch self {
        case .blood: .terracotta
        case .blue: .teal
        case .jade: .jade
        case .corn: .corn
        case .silver: .silver
        case .pink: .pink
        case .harvest: .harvest
        case .cold: .cold
        }
    }

    /// The songs' place (D5). It moves off teal when the theme is cool enough to sit beside it.
    var library: ColorFamily {
        switch self {
        case .blue, .jade, .silver, .cold: .terracotta
        case .blood, .corn, .pink, .harvest: .teal
        }
    }

    /// The Metronome stays plum in every theme (D5, and ADR 0081): it was the Toolkit that moved to end
    /// their near-pair (ADR 0312 D5).
    var metronome: ColorFamily { .plum }

    /// The Journal (D5), and the journal-note button in a running routine's header, which reads it.
    var journal: ColorFamily {
        switch self {
        case .corn: .terracotta
        case .harvest: .crimson
        default: .gold
        }
    }

    /// The Toolkit (0311 D5, as ADR 0312 D5 settled it). **Pink**, 12.0 from the Metronome's plum, where
    /// the indigo it wore until 1.6 sat 3.9 away. Pink Moon wears pink itself, so its Toolkit is
    /// terracotta; Cold Moon's is jade, as 0311 had it. Harvest Moon's orange leaves no family 10 clear,
    /// so its Toolkit is corn at 8.6, the one near-pair on Home accepted (`MoonThemeTests` holds it).
    var toolkit: ColorFamily {
        switch self {
        case .pink: .terracotta
        case .harvest: .corn
        case .cold: .jade
        default: .pink
        }
    }

    /// The Oracle's colour, which today shows as the snag ticks on the waveform (D5; its Home tile is
    /// hidden, ADR 0211). Pink Moon sits 6.8 from the crimson, so its ticks go teal.
    var oracle: ColorFamily {
        switch self {
        case .pink: .teal
        default: .crimson
        }
    }

    /// The suffix this theme's wordmark, logo, mark and App Icon take in the asset catalog (ADR 0312):
    /// `RedMoonWordmarkHarvest`, `AppIconHarvest`. Empty for Blood Moon, whose art is the brand's own
    /// and keeps its names. `scripts/derive-brand-svgs.py --themes` cuts them, with the same suffixes.
    var assetSuffix: String {
        switch self {
        case .blood: ""
        default: rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }

    /// The brand art in this theme's colours (ADR 0312 D2): the wordmark (Home's title), the whole
    /// lockup (Settings ▸ About) and the mark alone (the artist-name prompt).
    var wordmarkImage: String { "RedMoonWordmark" + assetSuffix }
    var logoImage: String { "RedMoonLogo" + assetSuffix }
    var markImage: String { "RedMoonMark" + assetSuffix }

    /// The alternate App Icon this theme sets on the Home Screen (ADR 0312 D3), or `nil` for the
    /// primary icon, which is Blood Moon's.
    var alternateIconName: String? {
        self == .blood ? nil : "AppIcon" + assetSuffix
    }

    /// The theme a stored value names. Anything unrecognised is Blood Moon, so a value written by a
    /// later version, or a bad one, draws the brand rather than crashing.
    static func resolved(storedValue: String?) -> MoonTheme {
        storedValue.flatMap(MoonTheme.init(rawValue:)) ?? standard
    }

    /// The theme the app draws in (ADR 0312 D1). The themes are part of the plan, so a player whose
    /// plan is off draws Blood Moon. Their choice is kept, and comes back with the plan.
    ///
    /// Until StoreKit has answered, the choice stands: anyone with a stored theme other than Blood Moon
    /// chose it on the plan, so they are far more likely to still have it than not, and flashing the
    /// brand at a paying player on every launch is the worse mistake of the two.
    static func effective(chosen: MoonTheme, planIsOn: Bool, planHasResolved: Bool) -> MoonTheme {
        planIsOn || !planHasResolved ? chosen : standard
    }
}

/// **A colour family** in `Colors.xcassets`: four colour sets that belong together, each with a light
/// and a dark value (ADR 0311 D4, D9). Its text colour, its filled button, its card wash and its icon
/// circle. Themes map roles onto these; nothing else names a colour set for a themed role.
enum ColorFamily: String, CaseIterable, Sendable {
    // The families Practice can wear (D4).
    case terracotta
    case teal
    case jade
    case corn
    case silver
    case pink
    case harvest
    case cold
    // The spaces' own, which no theme wears for Practice. (Indigo, the Toolkit's until 1.6, went when
    // the Toolkit moved to pink, ADR 0312 D5.)
    case plum
    case gold
    case crimson

    private var base: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    /// The family's text and icon colour.
    var text: String { base }
    /// The family's filled button. Only the families a filled button is drawn in have one: every
    /// Practice family, and the Metronome's plum.
    var button: String? {
        switch self {
        case .gold, .crimson: nil
        default: base + "CTA"
        }
    }
    /// The flat card fill behind a Home tile.
    var cardWash: String { base + "CardWash" }
    /// The flat circle behind a Home tile's icon.
    var circleWash: String { base + "CircleWash" }
}

/// **A themed role**: a token in `PocketColor` whose colour set depends on the theme. The dynamic colour
/// behind each token asks the theme for this role's colour set at the moment it is drawn.
///
/// A role is a place (Practice, or a space) and a shade of that place's family. The constants below are
/// the roles `PocketColor` draws; a place that has no filled button (the Library, the Journal, the
/// Toolkit, the Oracle) never asks for one.
struct ThemeRole: Hashable, Sendable {
    enum Place: CaseIterable, Sendable {
        case practice, library, metronome, journal, toolkit, oracle
    }

    enum Shade: CaseIterable, Sendable {
        case text, button, cardWash, circleWash
    }

    let place: Place
    let shade: Shade

    static let practice = ThemeRole(place: .practice, shade: .text)
    static let practiceButton = ThemeRole(place: .practice, shade: .button)
    static let practiceCardWash = ThemeRole(place: .practice, shade: .cardWash)
    static let practiceCircleWash = ThemeRole(place: .practice, shade: .circleWash)
    static let library = ThemeRole(place: .library, shade: .text)
    static let libraryCardWash = ThemeRole(place: .library, shade: .cardWash)
    static let libraryCircleWash = ThemeRole(place: .library, shade: .circleWash)
    static let metronome = ThemeRole(place: .metronome, shade: .text)
    static let metronomeButton = ThemeRole(place: .metronome, shade: .button)
    static let metronomeCardWash = ThemeRole(place: .metronome, shade: .cardWash)
    static let metronomeCircleWash = ThemeRole(place: .metronome, shade: .circleWash)
    static let journal = ThemeRole(place: .journal, shade: .text)
    static let journalCardWash = ThemeRole(place: .journal, shade: .cardWash)
    static let journalCircleWash = ThemeRole(place: .journal, shade: .circleWash)
    static let toolkit = ThemeRole(place: .toolkit, shade: .text)
    static let toolkitCardWash = ThemeRole(place: .toolkit, shade: .cardWash)
    static let toolkitCircleWash = ThemeRole(place: .toolkit, shade: .circleWash)
    static let oracle = ThemeRole(place: .oracle, shade: .text)
    static let oracleCardWash = ThemeRole(place: .oracle, shade: .cardWash)
    static let oracleCircleWash = ThemeRole(place: .oracle, shade: .circleWash)

    /// Every place in every shade, for the tests that check the catalog has what a theme names.
    static let allCases: [ThemeRole] = Place.allCases.flatMap { place in
        Shade.allCases.map { ThemeRole(place: place, shade: $0) }
    }
}

extension MoonTheme {
    /// The family `place` wears in this theme.
    func family(for place: ThemeRole.Place) -> ColorFamily {
        switch place {
        case .practice: practice
        case .library: library
        case .metronome: metronome
        case .journal: journal
        case .toolkit: toolkit
        case .oracle: oracle
        }
    }

    /// The colour set `role` draws from in this theme.
    func colorSet(_ role: ThemeRole) -> String {
        let family = family(for: role.place)
        switch role.shade {
        case .text: return family.text
        // Every Practice family has a button, and so does the Metronome's (`MoonThemeTests` holds
        // both). Falling back to the text colour only keeps this from needing a force-unwrap.
        case .button: return family.button ?? family.text
        case .cardWash: return family.cardWash
        case .circleWash: return family.circleWash
        }
    }
}
