import SwiftUI

/// Functional colour system from the product brief. Colour carries meaning —
/// it is never decorative. Keep these definitions as the single source of truth;
/// do not hard-code hex values in views.
///
/// Organised by **semantic role** below, not by hue — this is the seam a future
/// swappable `Theme` would slot into (each role becomes a `Theme` property; the
/// current values become the "blue" theme). Until then `PocketColor` *is* the one
/// theme. Identity (blue bars anchored on #2a6796) and live state (green) are kept
/// in different hue families so they never read as the same thing (ADR 0023).
///
/// Roles:
/// - background        — app surface (near-black)
/// - waveformBar(Played) — the song's bars (blue #2a6796); "identity-neutral" chrome
/// - active            — live state: playing, the forming loop, the active region
/// - fine              — Fine-mode precision selection (cyan)
/// - marker            — active-loop region fill base / selection (amber)
/// - pin               — waveform markers (purple inverted triangles)
/// - confirm / danger  — save ✓ (green) / discard·delete ✗ (red)
/// - loopPalette       — per-loop *identity* hues (see ADR 0023)
enum PocketColor {
    /// 0xRRGGBB → Color. Keeps the token table readable.
    private static func hex(_ rgb: UInt32) -> Color {
        Color(red: Double((rgb >> 16) & 0xFF) / 255,
              green: Double((rgb >> 8) & 0xFF) / 255,
              blue: Double(rgb & 0xFF) / 255)
    }

    // MARK: Surfaces
    /// Near-black, not true black (#0F0F0F). Dark-first interface — the blue accents
    /// and per-loop colours read best against black (ADR 0023).
    static let background = hex(0x0F0F0F)
    /// Detail-waveform bars — the blue identity anchor (#2a6796), so the song reads as
    /// themed chrome and the green live-state + per-loop colours pop against it
    /// (ADR 0023). Upcoming (ahead of the playhead) brighter; played recedes.
    static let waveformBar = hex(0x2A6796).opacity(0.85)
    static let waveformBarPlayed = hex(0x2A6796).opacity(0.4)

    // MARK: Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)

    // MARK: State
    /// Live state — playing, the forming loop, the active region. Green reads as
    /// "live/go" and stays clear of the blue song chrome (ADR 0023).
    static let active = Color.green
    /// Confirm / save — the green ✓ of the loop-capture toolbar (same family as `active`).
    static let confirm = Color.green
    /// Discard / delete / destructive — the red ✗ of the loop-capture toolbar.
    static let danger = Color.red
    /// In-song metronome click (ADR 0026 / 0027). A teal that sits clear of every
    /// other functional hue — green (live), the blue bars, orange (markers), purple
    /// (pins), red (danger) — so the click reads as its own thing, not "another play
    /// control." Lives next to the BPM readout on the speed bar (ADR 0027).
    static let metronome = hex(0x35C8C8)
    /// **Practice** — the identity hue of the top-level Practice space (ADR 0046): where
    /// trainable units live and command-anchored runs happen. A soft indigo, kept clear of
    /// the metronome teal (the metronome is the *tool*; Practice is the *content*) and of
    /// every other functional hue — green (live), blue (bars), orange (markers), purple
    /// (pins), red (danger) — so the two spaces read as distinct destinations from Home.
    static let practice = hex(0x8B7CF6)

    // MARK: Selection & annotation
    /// Fine precision (selection handles + the downbeat "1" handle) — a high-key cool
    /// white. The old cyan sat in the same blue family as the bars (`#2a6796`) and blended
    /// in; every saturated hue is already reserved (green = live, purple = markers, the
    /// warm palette = loop identity, red = danger), so contrast comes from luminance, not
    /// hue. TODO: revisit as part of any theme redesign (ADR 0023 follow-up).
    static let fine = hex(0xEAF2FF)
    /// Active-loop region fill base / selection accent.
    static let marker = Color.orange
    /// Waveform markers (purple inverted triangles).
    static let pin = Color.purple

    // MARK: Neutral fills
    /// Neutral "off" fill — empty mastery dots, the minimap base track.
    static let barDefault = Color.white.opacity(0.35)
    static let barPlayed = Color.white.opacity(0.18)

    // MARK: Loop identity
    /// Per-loop identity palette (ADR 0023 — supersedes ADR 0018's colour=state).
    /// Each saved loop draws in its own hue (assigned deterministically by
    /// `LoopColors.slot`); overlap is still shown by vertical lane. Deliberately
    /// avoids the functional hues — blue (bars/fine), purple (markers), and green
    /// (live state) — so a loop never reads as chrome or as the active wash.
    static let loopPalette: [Color] = [
        hex(0xF59E0B),   // amber
        hex(0xFACC15),   // gold
        hex(0xFB7185),   // coral
        hex(0xEC4899),   // magenta
        hex(0xA78BFA),   // violet
        hex(0x14B8A6)    // teal (blue-green; distinct from the green active wash)
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
    /// `relativeTo:` Dynamic Type scaling.
    private static func uiSize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline, .body: return 17
        case .callout: return 16
        case .subheadline: return 15
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        @unknown default: return 17
        }
    }
}
