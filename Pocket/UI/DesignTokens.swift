import SwiftUI

/// Functional colour system from the product brief. Colour carries meaning —
/// it is never decorative. Keep these definitions as the single source of truth;
/// do not hard-code hex values or `Color.white`/`.black` opacity fills in views.
///
/// Organised by **semantic role** below, not by hue — this is the seam a future
/// swappable `Theme` would slot into (each role becomes a `Theme` property; the
/// current values become the "Blood Moon" theme, which ADR 0292 made the only one, after
/// the teal that ADR 0062's follow-up retuned from blue). Until then `PocketColor` *is* the
/// one theme. Identity
/// (the song's bars) and live state (green) are kept in different hue families so
/// they never read as the same thing (ADR 0023).
///
/// **Light + dark appearance (ADR 0062):** every token below except the four system
/// dynamic colours (`active`/`danger`/`marker`/`pin`, which already adapt on their own)
/// resolves from an Asset Catalog colour set in `Colors.xcassets` (a catalog of its own, which
/// the share extension includes too: a catalog doesn't cross a target, ADR 0264 D10) with
/// separate "Any Appearance" (light) and "Dark" values, tuned so contrast holds up on
/// **both** the cream (`#F0E3D8`) and near-black (`#040404`) canvases — see the ADR for
/// the paired hex table and contrast ratios. The app follows the system appearance by
/// default; `AppearancePreference` (Settings → Appearance) lets the user pin Light or
/// Dark instead, applied once at the `PocketApp` root — no other view forces
/// `.preferredColorScheme`.
///
/// Roles:
/// - background        — app surface (cream / near-black)
/// - ink               — adaptive foreground base (near-black / white); `textPrimary`
///   and the `surfaceSubtle`/`surfaceStandard` fills are `ink` at reduced opacity, so
///   they blend correctly over any backdrop, not just the flat background
/// - waveformBar(Played) — the song's bars; "identity-neutral" chrome
/// - active            — live state: playing, the forming loop, the active region
/// - fine              — Fine-mode precision selection
/// - marker            — active-loop region fill base / selection (amber)
/// - pin               — waveform markers (purple inverted triangles)
/// - confirm / danger  — save ✓ (green) / discard·delete ✗ (red)
/// - loopPalette       — per-loop *identity* hues (see ADR 0023)
enum PocketColor {
    // MARK: Surfaces
    /// App surface — cream in light appearance, near-black in dark (ADR 0061/0062).
    static let background = Color("Background")
    /// Adaptive foreground ink: near-black on the cream surface, white on the dark
    /// surface. The base for `textPrimary` and the translucent surface fills below —
    /// composing `.opacity()` on top of `ink` keeps them correct over *any* backdrop,
    /// mirroring how `Color.white.opacity(...)` worked before dark was the only mode.
    static let ink = Color("Ink")
    /// Subtle fill — hairline dividers, thin strokes (replaces ad-hoc `white.opacity(0.04–0.06)`).
    static let surfaceSubtle = ink.opacity(0.05)
    /// Standard fill — cards, pills, capsules, toggle "off" states (replaces ad-hoc
    /// `white.opacity(0.06–0.10)`).
    static let surfaceStandard = ink.opacity(0.09)
    /// Emphasis fill — a selected/highlighted chip or row, one step up from `standard`.
    static let surfaceEmphasis = ink.opacity(0.18)
    /// Hairline stroke border — capsule/badge outlines (replaces ad-hoc `white.opacity(0.15)`
    /// strokes).
    static let surfaceBorder = ink.opacity(0.15)
    /// Detail-waveform bars — the song's identity anchor, so it reads as themed chrome
    /// and the green live-state + per-loop colours pop against it (ADR 0023). Blue, then the
    /// brand teal (ADR 0062 follow-up, saturation boosted in a second one), and since ADR 0292
    /// the brand **terracotta**: the song player wears the blood moon like Practice does. Read
    /// from the `Terracotta` hue rather than a copy of its values, so the two cannot drift.
    /// Upcoming (ahead of the playhead) brighter; played recedes.
    static let waveformBar = Color("Terracotta").opacity(0.85)
    static let waveformBarPlayed = Color("Terracotta").opacity(0.4)
    /// Full-opacity song accent — the bars' terracotta at full strength, for the song-tempo
    /// chrome that must match them: the practice screen's speed slider and its "Set BPM"
    /// affordance, the speed bar's repeat and metronome buttons, the tempo sheet. A hue, not a
    /// role: deliberately *not* `metronome` (the metronome tool, plum) nor `practice`, even
    /// though it is Practice's colour since ADR 0292 — the song's tempo reads as the song (ADR 0081).
    static let waveformAccent = Color("Terracotta")
    /// Beat-grid downbeat lines (ADR 0022). Baked per appearance rather than
    /// `ink.opacity(_)`, because a shared low opacity reads faintly on dark but nearly
    /// vanishes on cream (ADR 0062 follow-up) — light is boosted so the grid stays
    /// legible without needing a much higher literal opacity that would look heavy
    /// on dark.
    static let gridLine = Color("GridLine")

    // MARK: Text
    static let textPrimary = ink
    static let textSecondary = Color("TextSecondary")

    // MARK: State
    /// Live state — playing, the forming loop, the active region. Green reads as
    /// "live/go" and stays clear of the blue song chrome (ADR 0023). System dynamic
    /// colour — already adapts to light/dark on its own.
    static let active = Color.green
    /// Confirm / save — the green ✓ of the loop-capture toolbar (same family as `active`).
    static let confirm = Color.green
    /// Discard / delete / destructive — the red ✗ of the loop-capture toolbar.
    static let danger = Color.red
    /// In-song metronome click, and the Metronome space's identity colour (ADR 0026 /
    /// 0027). The metronome is the one home feature whose hue never moved: it stayed **plum**
    /// through ADR 0081's re-hue and ADR 0292's Blood Moon swap. Sits clear of every other
    /// functional hue — green (live), terracotta (Practice/brand), teal (songs), orange
    /// (markers), purple (pins), red (danger).
    static let metronome = Color("Plum")
    /// **Practice** — the identity hue of the top-level Practice space (ADR 0046), and the
    /// app's **brand hero**: it wears the blood-moon **terracotta** (ADR 0292, which made ADR
    /// 0081's Blood Moon the only theme), so the most-used space and its "Start today's session"
    /// CTA lead in the colour of the logo and the name. Every one of its ~120 call sites reads
    /// this token, so the whole Practice surface reskins from here. Kept clear of the metronome
    /// plum and every other functional hue.
    static let practice = Color("Terracotta")
    /// Mastery indicator accent — the dots showing how well a loop or song is owned (Home's
    /// "Mastered" stat, `MasteryDots` everywhere mastery is drawn, and the loop mastery picker). **Tracks the brand hero** (`practice`) rather than
    /// its own hue — "mastered" reads as an on-brand positive state — so it is terracotta,
    /// following Practice (ADR 0081, ADR 0292). Never the metronome plum.
    static let mastery = practice

    /// Card/circle **wash** fills for the Metronome and Practice feature cards (Home).
    /// Fully resolved per appearance — *not* `metronome`/`practice` at a shared opacity —
    /// because a shared low opacity doesn't transfer symmetrically: blended at 10–15% it
    /// reads as washed-out grey on cream *and* near-invisible against near-black (the
    /// ADR 0062 follow-up bug). Each hue therefore has an independently baked flat
    /// card/circle wash per appearance, dim enough that the icon glyph on top still clears
    /// ~3:1. Practice draws the **terracotta** washes (brand hero); Metronome the **plum**.
    static let metronomeCardWash = Color("PlumCardWash")
    static let metronomeCircleWash = Color("PlumCircleWash")
    static let practiceCardWash = Color("TerracottaCardWash")
    static let practiceCircleWash = Color("TerracottaCircleWash")

    /// **Library** — the identity hue of the songs place (the home hub's "Song library" nav strip).
    /// The **teal** since ADR 0292, which swapped it with Practice so the brand red could lead;
    /// the home triad is terracotta · plum · teal (Practice / Metronome / songs). Baked flat per
    /// appearance like the washes above — *not* a shared opacity on `library` (ADR 0062 lesson: a
    /// low-opacity blend reads washed-grey on cream and near-invisible on near-black). No
    /// `libraryCTA`: the library strip is never a filled CTA.
    static let library = Color("Teal")
    static let libraryCardWash = Color("TealCardWash")
    static let libraryCircleWash = Color("TealCircleWash")

    /// **Toolkit** — the identity hue of the chords/theory/resources hub (ADR 0096, the fourth home
    /// card). An **indigo/violet** "study / reference" hue, deliberately distinct from the
    /// terracotta · plum · teal home triad so the reference destination reads as its own place (ADR
    /// 0096 D3). Baked flat per appearance like the other card hues — *not* a shared opacity on
    /// `toolkit` (ADR 0062 lesson: a low-opacity blend reads washed-grey on cream and near-invisible on
    /// near-black). No `toolkitCTA`: the hub is reference, never a filled transport CTA.
    static let toolkit = Color("Indigo")
    static let toolkitCardWash = Color("IndigoCardWash")
    static let toolkitCircleWash = Color("IndigoCircleWash")

    /// **Journal** — the identity hue of the read-only practice-history space (the fifth home card,
    /// slotted 4th, between Practice and Toolkit). A warm **gold** "notebook/ink" hue: personal and
    /// reflective, deliberately set apart from the terracotta · plum · teal home triad and the
    /// indigo reference hub, so the journal reads as its own place. Baked flat per appearance like
    /// the other card hues (ADR 0062 lesson — not a shared opacity on `journal`). The gold also tints
    /// the owner-attribution captions inside the space. No `journalCTA`: the journal is history,
    /// never a filled transport CTA.
    static let journal = Color("Gold")
    static let journalCardWash = Color("GoldCardWash")
    static let journalCircleWash = Color("GoldCircleWash")

    /// **Oracle** — the identity hue of the Red Moon Oracle (ADR 0187 D16, the **sixth** home card
    /// and the first in the new *Learn* section). A deep **crimson/wine**.
    ///
    /// **Not ADR 0081's Blood Moon, and the reason is worth keeping.** D16 nominated Blood Moon
    /// (`#c24a2c` / `#e3694a`) as the candidate on the strength of the artwork already existing.
    /// Measured against the palette it turns out to *be* the terracotta family: its light value was
    /// `#C24A2C`, byte-for-byte the Song library's, and its dark value sits a few degrees from
    /// `#E07E57`. Shipping it would have given two home spaces one colour in light mode, which is
    /// precisely what `docs/design-brief.md` §3.1 says the per-space accent families exist to
    /// prevent — the cue that tells you which space you are in.
    ///
    /// Crimson keeps the red the name asks for while reading as wine rather than orange, so it is
    /// distinguishable from the terracotta and clear of the metronome's violet plum. Blood Moon went
    /// on to become the app's **theme** (ADR 0292), which is what it was always for: the terracotta
    /// is Practice's now, and still cannot also be the Oracle's.
    ///
    /// Baked flat per appearance like every other card hue — *not* a shared opacity on `oracle`
    /// (ADR 0062 lesson: a low-opacity blend reads washed-grey on cream and near-invisible on
    /// near-black). No `oracleCTA`: a reading is opened, never transported.
    static let oracle = Color("Crimson")
    static let oracleCardWash = Color("CrimsonCardWash")
    static let oracleCircleWash = Color("CrimsonCircleWash")

    /// Full-opacity **CTA fill** for the Metronome/Practice primary transport buttons
    /// (Start/Pause/Resume; the run screens' big pill) and Home's "Start today's session".
    /// A deepened per-appearance fill (not the base hue at opacity) so the cream
    /// `PocketColor.background` text on top stays ≥4.5:1 (ADR 0062 follow-up;
    /// `BrandColorContrastTests` holds Practice's to it). Practice's CTA is **terracotta**
    /// (brand hero, ADR 0292), Metronome's is **plum**.
    static let metronomeCTA = Color("PlumCTA")
    static let practiceCTA = Color("TerracottaCTA")

    /// "Add a song" wash (Home) — same fix as the card washes above, applied to the
    /// system `active` green: `Color.green.opacity(0.14)` reads as a washed, near-
    /// disabled sage on cream and a near-invisible near-black on dark. Both appearances
    /// are now an independently baked, clearly-green flat colour.
    static let confirmWash = Color("ConfirmWash")

    // MARK: Selection & annotation
    /// Fine precision (selection handles + the downbeat "1" handle) — high-key cool
    /// white on dark, a low-key cool slate on light (ADR 0062), same hue family either
    /// way. Every saturated hue is already reserved (green = live, purple = markers,
    /// the warm palette = loop identity, red = danger), so contrast comes from
    /// luminance, not hue.
    static let fine = Color("Fine")
    /// Reserved amber accent (ADR 0023). Not currently drawn anywhere — the active-loop
    /// region fill it originally named moved to `active` (green) and the mastery accent
    /// that had organically become its main user moved to `mastery` (the brand hero's colour) — kept
    /// defined as the "next" free functional hue rather than deleted outright.
    static let marker = Color.orange
    /// Waveform markers (purple inverted triangles). System dynamic colour.
    static let pin = Color.purple

    // MARK: Neutral fills
    /// Neutral "off" fill — empty mastery dots, the minimap base track.
    static let barDefault = Color("BarDefault")
    static let barPlayed = Color("BarPlayed")

    // MARK: Loop identity
    /// Per-loop identity palette (ADR 0023 — supersedes ADR 0018's colour=state; retuned
    /// in the ADR 0062 follow-up). Each saved loop draws in its own hue (assigned
    /// deterministically by `LoopColors.slot`); overlap is still shown by vertical lane.
    ///
    /// These deliberately are **not** brand-tuned — a loop's job is to be a quick,
    /// unmistakable "sticker" you can tell apart at a glance, not to feel cohesive with
    /// the terracotta/plum brand accents. Each hue is a plain, saturated primary/secondary
    /// (red/orange/gold/magenta/violet/blue) with an independently tuned light+dark pair,
    /// so none of them fade toward a muddy/olive mid-tone the way a brand-consistent
    /// desaturated hue would when deepened for light-appearance contrast. Avoids green
    /// (live state) so a loop never reads as the active wash. It was also chosen clear of the
    /// bars' teal (ADR 0062); since ADR 0292 the bars are terracotta, which sits between
    /// `LoopRed` and `LoopOrange`, so those two lean on their saturation and their lane to
    /// read as a loop rather than as chrome (ADR 0292, Consequences).
    static let loopPalette: [Color] = [
        Color("LoopRed"),
        Color("LoopOrange"),
        Color("LoopGold"),
        Color("LoopMagenta"),
        Color("LoopViolet"),
        Color("LoopBlue")
    ]
}

/// Typography (ADR 0061): **Futura** for all prose/UI text (it echoes the "Red Moon"
/// wordmark), **monospace** for time values and BPM (kept for numeric alignment).
/// Everything routes through these two tokens — do not call `.font(.headline)` etc.
/// directly, so the family is swappable from one place.
extension Font {
    /// Monospace numerals — tempo, BPM, timecodes. Alignment matters, so this stays
    /// system monospaced (Futura has no monospaced face).
    static func pocketMono(_ style: Font.TextStyle) -> Font {
        .system(style, design: .monospaced)
    }

    /// Brand text font (Futura), scaled to a Dynamic Type text style. `weight` picks the
    /// face: Futura ships **Medium** (base) and **Bold** — semibold/bold/heavy/black map
    /// to Futura-Bold, everything else to Futura-Medium. `.headline` defaults to Bold to
    /// preserve its emphasis. Falls back to the system font if Futura is unavailable.
    static func futura(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> Font {
        let bold: Bool
        if let weight { bold = Self.isBold(weight) } else { bold = (style == .headline) }
        return .custom(bold ? "Futura-Bold" : "Futura-Medium",
                       size: Self.uiSize(style), relativeTo: style)
    }

    /// Fixed-size Futura, for the handful of `.system(size:)` call sites that need an
    /// exact point size rather than a text style.
    static func futura(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(Self.isBold(weight) ? "Futura-Bold" : "Futura-Medium", size: size)
    }

    private static func isBold(_ weight: Font.Weight) -> Bool {
        [.semibold, .bold, .heavy, .black].contains(weight)
    }

    /// Default (Large content-size) point sizes per text style — the anchor for
    /// `relativeTo:` Dynamic Type scaling. Table lookup (not a `switch`) to keep the
    /// helper's cyclomatic complexity within SwiftLint's `--strict` limit.
    private static let uiSizes: [Font.TextStyle: CGFloat] = [
        .largeTitle: 34, .title: 28, .title2: 22, .title3: 20,
        .headline: 17, .body: 17, .callout: 16, .subheadline: 15,
        .footnote: 13, .caption: 12, .caption2: 11
    ]

    private static func uiSize(_ style: Font.TextStyle) -> CGFloat {
        uiSizes[style] ?? 17
    }
}
