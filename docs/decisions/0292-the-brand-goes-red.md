# ADR 0292 — The brand goes red: Blood Moon is the only colouring

- **Status:** Accepted — built (2026-11-08, `pocket-419-blood-moon-brand`), for 1.4.1
- **Date:** 2026-11-08 (`pocket-419-blood-moon-brand`)
- **Amends:** ADR 0081 — its Slice 2 mapping (Practice terracotta, Library teal, Metronome plum,
  mastery tracking Practice) becomes the app's **only** colouring, for everyone. The teal default and
  Slice 2's theme picker are dropped, and the song player's `waveformAccent` is no longer a fixed teal
  (D4). Slice 1's hue assets and the plum Metronome stand. · ADR 0061 — the mark, the wordmark and the App Icon are the **blood moon**
  artwork, not the slate-teal, and each brand imageset is one universal image rather than a light/dark
  pair. The display name, Futura and the internal *Pocket* names stand.
- **Relates to:** 0062 (the contrast rule D2 meets) · 0187 D16 (the Oracle's crimson, chosen to stay
  clear of this terracotta) · 0279 (the App Store frames D6 recolours) · 0023 (the loop palette, whose
  red and orange now sit either side of the bars)

## Context

The app is called Red Moon and its logo was blue. A designer Tomisin spoke to raised it in early November:
a new app gets one glance, and a name and a colour that point different ways cost it that glance. A blue
crescent on black is also the look of sleep and meditation apps.

The first recommendation (2026-11-05) was to change only what people see before they open the app (the
logo, the App Store icon, the site, social posts) and leave the in-app colours alone, because they are
functional: they tell you which space you are in. Mockups of both followed: the site redesigned in black
and one red, and four real 1.4 screens recoloured by ADR 0081's Blood Moon swap. Having seen them,
Tomisin chose to make the in-app change too (2026-11-08): *"Let's make the changes. We'll submit it as a
new build, we can afford to be patient"*, then Blood Moon **for everyone** rather than as a theme to pick.

ADR 0081 had already designed the swap as a role → hue mapping, so every Practice call site reads one
token. What it had not measured was the light-mode text contrast.

## Decisions

**D1. Blood Moon is the colouring, for everyone.** `practice`, `practiceCardWash`, `practiceCircleWash`
and `practiceCTA` read the Terracotta family; `library`, `libraryCardWash` and `libraryCircleWash` read
the Teal family. `mastery` still tracks `practice`, so the progress dots are terracotta. There is no
picker and no stored preference: the teal look is gone, not hidden.

**D2. Light-mode Terracotta darkens from `#C24A2C` to `#B0391B`.** Practice colours small text all over
the app ("All 4 ›", a routine's block count, *Edit goals*). `#C24A2C` on the cream background is
**3.87 : 1**, under AA's 4.5, where the teal it replaces was 4.84. `#B0391B` keeps the hue and chroma in
OKLab and lowers the lightness until it matches the teal exactly: **4.84 : 1** on the background and
3.98 : 1 on a `surfaceStandard` card, both the teal's own figures, so nothing gets harder to read. Dark
is unchanged (`#E07E57`, 7.12 : 1). `TerracottaCTA` is unchanged: the background ink on it is 4.60 : 1
light and 8.79 : 1 dark (the teal's were 4.86 and 6.91). `BrandColorContrastTests` reads the real
colours in both appearances and holds Practice, the Library and the song player (D4) to 4.5. The logo keeps `#C24A2C`: it is
artwork, never text.

**D3. The brand art is the blood moon.** `RedMoonLogo`, `RedMoonMark` and `RedMoonWordmark` are each one
universal SVG cut from the blood-moon lockup, whose two reds read on cream and near-black alike; the blue
pair needed its colours inverted between appearances. The App Icon is the blood-moon mark on the same
opaque `#0F0F0F` at the same 66.8% height. `scripts/derive-brand-svgs.py` now defaults to the blood art,
cuts the icon from it, and removes SVGs a catalog run no longer writes. The blue sources are still named,
so the old pair can be cut to a loose folder for reference.

**D4. The song player goes terracotta too.** The first build kept it teal, as ADR 0081 had it "in
every theme". Tomisin, after running that build on the phone the same evening: *"we need to swap the teal
in song player (waveform and buttons) to terracotta"*. `waveformBar`, `waveformBarPlayed` and
`waveformAccent` now read the `Terracotta` hue itself, and `WaveformBarBase` (a copy of the teal's values)
is deleted, so the two cannot drift. `TealCTA` goes too: with Practice's buttons terracotta, nothing
fills with teal. That takes the bars, the speed slider, the speed bar's repeat and
metronome buttons, the tempo sheet and the song player settings' *Done*. ADR 0081's reason for the fixed
hue still holds: the song's tempo chrome must not read as the metronome's plum; it never needed the teal
for that. **One reader stays teal:** the song card's middle mastery tier draws `library` instead, because
terracotta is a shade from the orange tier below it, and a tier is only worth drawing if it reads apart.

**D5. What does not move.** The Metronome stays plum, the Journal gold, the Toolkit indigo, the Oracle
crimson. The loop palette and Futura are untouched.

**D6. What prints the colour follows it.** The tab PDF's notes lane is `practice`'s light value, so it
becomes `#B0391B`. The App Store frames (0279) caption in Practice's dark value, `#E07E57`, with the
glow to match.

**D7. It ships as 1.4.1 (build 11).** 1.4 (10) finishes its review as submitted. The release prep for
1.4.1 owes: the manual's figures (every screen with Practice, the Library or a song in it), the App Store
screenshots, and the frames rebuilt from them. The website keeps its current look until a later change.

## Consequences

- **Terracotta becomes a button colour.** It fills *Start today's session*, *Pause*, *Resume* and the run
  screens' pill. ADR 0081 kept it to washes and accents because it sits near `danger` red and the orange
  markers, and said to revisit if it ever took an action role; this is that revisit. What holds the line:
  destructive actions keep the system red (`danger`), never a terracotta fill, and the filled buttons
  carry words. Check on a device that *Pause* never reads as a warning.
- **The loop palette's red and orange now sit either side of the bars.** A loop draws as a line in its
  own colour under the waveform and tints its row's play button; with teal bars every loop colour stood
  apart, and now `LoopRed` and `LoopOrange` are neighbours of the chrome. They keep their saturation and
  their lane, which is what tells them apart. If a red or orange loop reads as part of the player on the
  phone, the palette is the thing to retune, not the bars, and that is its own decision: it recolours
  loops people already have.
- The song map's Notes lane is Practice's, so it is terracotta beside the orange marker pins.
- Every screenshot of the app is stale: the manual's figures, the App Store screenshots, the Creative
  Brief's, the site's. The manual's prose names one colour (*the filled red card*); it is updated here.
- The comments that called Practice or the song player teal are updated. The teal hues now belong to
  the Library alone.

## Alternatives considered

- **Brand outside the app only.** The recommendation of 2026-11-05: the in-app accents are functional,
  and nobody outside sees them. Tomisin chose the in-app change after seeing the mockups.
- **ADR 0081's theme picker, Blood Moon or teal by default.** More to build and keep true (a Settings
  row, a stored choice, the manual, UI tests), and it splits the brand: the point is that everyone sees
  the same red. Not ruled out for later as an option of its own.
- **Keep `#C24A2C` in light mode, to match the logo byte for byte.** Fails AA for the small text Practice
  draws everywhere (3.87 : 1).
- **Tint the blue art red in code.** The mark is two-tone; one tint flattens it. The designer's blood-moon
  lockup already existed.
