import SwiftUI

/// Maps the persisted preference to the `.preferredColorScheme(_:)` argument — `nil`
/// for `.system` so SwiftUI falls through to the device setting instead of pinning one.
extension AppearancePreference {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Functional colour system from the product brief. Colour carries meaning —
/// it is never decorative. Keep these definitions as the single source of truth;
/// do not hard-code hex values or `Color.white`/`.black` opacity fills in views.
///
/// Organised by **semantic role** below, not by hue — this is the seam a future
/// swappable `Theme` would slot into (each role becomes a `Theme` property; the
/// current values become the "teal" theme, retuned from blue in ADR 0062 follow-up
/// to match the brand mark). Until then `PocketColor` *is* the one theme. Identity
/// (the song's bars) and live state (green) are kept in different hue families so
/// they never read as the same thing (ADR 0023).
///
/// **Light + dark appearance (ADR 0062):** every token below except the four system
/// dynamic colours (`active`/`danger`/`marker`/`pin`, which already adapt on their own)
/// resolves from an Asset Catalog colour set under `Assets.xcassets/Colors` with
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
    /// and the green live-state + per-loop colours pop against it (ADR 0023). Retuned
    /// from blue to the brand teal in ADR 0062 follow-up, alongside the speed slider
    /// and the metronome accent, for a more unified brand hue — then boosted in
    /// saturation in a second follow-up (with `metronome`) after the first teal read as
    /// too dusty/muted across both appearances. Upcoming (ahead of the playhead)
    /// brighter; played recedes.
    static let waveformBar = Color("WaveformBarBase").opacity(0.85)
    static let waveformBarPlayed = Color("WaveformBarBase").opacity(0.4)
    /// Full-opacity song accent — the `WaveformBarBase` teal at full strength, for
    /// song-tempo chrome that must match the bars and stay teal in **every** theme: the
    /// practice screen's speed slider and its "Set BPM" affordance. Deliberately *not*
    /// `metronome` (the metronome tool, plum) nor `practice` (the brand hero, which turns
    /// terracotta in Blood Moon) — the song's tempo reads as the song (ADR 0081).
    static let waveformAccent = Color("WaveformBarBase")
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
    /// 0027). The metronome is the one home feature whose hue is **theme-invariant**: it
    /// stays the brand **plum** in both the default and Blood Moon themes (ADR 0081),
    /// having handed its former teal to Practice so the brand's teal now leads via the
    /// most-used space. Sits clear of every other functional hue — green (live), teal
    /// (Practice/brand), terracotta (songs), orange (markers), purple (pins), red (danger).
    static let metronome = Color("Plum")
    /// **Practice** — the identity hue of the top-level Practice space (ADR 0046), and the
    /// app's **brand hero**: it wears the brand **teal** (ADR 0081), so the most-used space
    /// and its "Start today's session" CTA lead in the brand colour. Every one of its ~120
    /// call sites reads this token, so the whole Practice surface reskins from here — which
    /// is also the seam the Blood Moon theme uses to swap it to terracotta (Slice 2). Kept
    /// clear of the metronome plum and every other functional hue.
    static let practice = Color("Teal")
    /// Mastery indicator accent — the dots/stars showing how well a loop or song is
    /// owned (Home's "Mastered" stat, the mastery dots on song cards and the loop
    /// mastery picker, mastery stars). **Tracks the brand hero** (`practice`) rather than
    /// its own hue — "mastered" reads as an on-brand positive state — so it is teal in the
    /// default theme and follows Practice to terracotta in Blood Moon (ADR 0081). Never the
    /// metronome plum.
    static let mastery = practice

    /// Card/circle **wash** fills for the Metronome and Practice feature cards (Home).
    /// Fully resolved per appearance — *not* `metronome`/`practice` at a shared opacity —
    /// because a shared low opacity doesn't transfer symmetrically: blended at 10–15% it
    /// reads as washed-out grey on cream *and* near-invisible against near-black (the
    /// ADR 0062 follow-up bug). Each hue therefore has an independently baked flat
    /// card/circle wash per appearance, dim enough that the icon glyph on top still clears
    /// ~3:1. Practice draws the **teal** washes (brand hero); Metronome the **plum**.
    static let metronomeCardWash = Color("PlumCardWash")
    static let metronomeCircleWash = Color("PlumCircleWash")
    static let practiceCardWash = Color("TealCardWash")
    static let practiceCircleWash = Color("TealCircleWash")

    /// **Library** — the identity hue of the songs place (the home hub's "Song library" nav strip).
    /// Now the warm **terracotta** (ADR 0081), completing a teal · plum · terracotta home triad
    /// (Practice / Metronome / songs) in place of the retired ADR 0023 song-blue. Baked flat per
    /// appearance like the washes above — *not* a shared opacity on `library` (ADR 0062 lesson: a
    /// low-opacity blend reads washed-grey on cream and near-invisible on near-black). In the Blood
    /// Moon theme Library and Practice swap, so this becomes teal (Slice 2). No `libraryCTA`: the
    /// library strip is never a filled CTA.
    static let library = Color("Terracotta")
    static let libraryCardWash = Color("TerracottaCardWash")
    static let libraryCircleWash = Color("TerracottaCircleWash")

    /// Full-opacity **CTA fill** for the Metronome/Practice primary transport buttons
    /// (Start/Pause/Resume; the run screens' big pill) and Home's "Start today's session".
    /// A deepened per-appearance fill (not the base hue at opacity) so the cream
    /// `PocketColor.background` text on top stays ≥4.5:1 (ADR 0062 follow-up). Practice's
    /// CTA is **teal** (brand hero), Metronome's is **plum**.
    static let metronomeCTA = Color("PlumCTA")
    static let practiceCTA = Color("TealCTA")

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
    /// that had organically become its main user moved to `mastery` (brand teal) — kept
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
    /// the teal/plum brand accents. Each hue is a plain, saturated primary/secondary
    /// (red/orange/gold/magenta/violet/blue) with an independently tuned light+dark pair,
    /// so none of them fade toward a muddy/olive mid-tone the way a brand-consistent
    /// desaturated hue would when deepened for light-appearance contrast. Avoids green
    /// (live state) and the brand teal (bars/metronome, ADR 0062) so a loop never reads
    /// as chrome or as the active wash.
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
