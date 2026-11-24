# ADR 0316 — Settings wears the theme: Red Moon's lockup on one line, and the icons in the theme's colour

- **Status:** Accepted on 2026-11-24, for 1.6, and built on `pocket-469-theme-in-sheets`. Tomisin asked
  before 1.6 shipped to *"extend the branding and themes to the settings sheet"*, and chose from four
  versions rendered from the app (`https://claude.ai/artifact/YSSp2Kj5QpdkAxto2zB3K5`, private): as it
  was, a moon header, theme-coloured icons, and both. Their call: **both**. *"I get the argument that the
  colour carries meaning but I think we can make an exception in terms of aesthetics here."* The header
  in the mockup took too much height, so it is the one-line lockup the site's header uses.
- **Date:** 2026-11-24
- **Amends:** ADR 0162 — **D1**: the hub opens with Red Moon's lockup above its first group, and its rows'
  icons are drawn in the theme's Practice colour, not grey. The destinations, the grouping rule, D3 and
  the `Form` stand.
- **Relates to:** 0311 (the moon themes; the colours that carry a meaning stay put, and this adds none)
  · 0312 D2 (the wordmark and logo follow the theme, cut per theme by the script) · 0081 and the design
  brief's §3.1 (colour is functional, never decorative: this is the named exception) · 0292 (Blood Moon,
  the brand) · 0306 (the site, whose header this lockup matches)
- **Schema:** none.

## Context

The themes reached Home, Practice, the song player and, since the fix on the same branch, every sheet.
Settings showed none of it: grey icons on plain rows, the theme visible only as the word on the
Appearance row. It's the screen a player opens to choose a theme, and it looked like a system list.

The design brief's rule is that colour carries meaning. The theme's colour is Practice's, worn by the
mastery dots and the song player's bars. A Settings icon in it means nothing: *Your data* isn't Practice.
That was my argument for the header alone. Tomisin weighed it and chose the look.

## Decision

**D1. Red Moon's lockup heads the hub, on one line.** The moon beside the wordmark, as the site's header
sets them, in the theme's own cut of each (0312 D2): no colour applied in code, so Blood Moon draws the
brand exactly. The moon stands 34 points, the letters 24, so it costs the hub about one row's height and
every row stays where it was found, Developer included on an iPhone 17. It is the first group's section
header (`SettingsBrandHeader`), and VoiceOver reads it as *Red Moon*.

**D2. The hub's row icons wear the theme's Practice colour.** Every `HubRow` on the Settings hub. The
colour travels as an environment value (`hubRowIconColor`) set on the hub's `Form`, so `HubRow` stays grey
everywhere else: the song details sheet's category rows (0258) keep theirs.

**D3. The exception is named, and it is the only one.** Settings' icons wear the theme colour for its
look. They don't mean Practice, and nothing reads them as a sign. No other hub follows from this: a new
place that wants the theme colour for its look needs its own decision. The design brief's §3.1 says so.

## Consequences

- The manual's Settings figure is stale until the 1.6 reshoot, as the Theme and App Icon figures are.
- The icons are drawn in Practice's *text* colour, which `BrandColorContrastTests` holds to 4.5 : 1 on
  the cream in every theme, so they read in light and dark.
- A player on Blood Moon sees terracotta icons: the brand's own colour, now in Settings too.
- **Seen on the phone, 2026-11-24**, with the sheets fix (ADR 0312 D6) in the same build: *"All good on
  the phone."*

## Alternatives

- **The stacked lockup** (the moon above the wordmark, as About shows it). Rendered at 130 points wide it
  took about four rows' height. Rejected by Tomisin for the space.
- **The header alone, grey icons** (my recommendation). Rejected for the look; see D3.
- **Icons alone, no header.** Rejected: the brand is what Settings was missing most.
