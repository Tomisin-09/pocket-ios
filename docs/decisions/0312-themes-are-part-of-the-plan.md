# ADR 0312 — The moon themes are part of the plan, and the logo and the App Icon follow them

- **Status:** Accepted on 2026-11-22, and built with ADR 0311 on `pocket-462-moon-themes-build`. Tomisin
  settled three of 0311's four open questions the same evening: *"Pro only, wordmark and App icon follow
  the theme, … and silver ships once it's seen on the phone."* The fourth, the Metronome and Toolkit
  near-pair, they asked for options on; D5 lists them, not decided here.
- **Date:** 2026-11-22
- **Amends:** ADR 0311 — **D1**: the logo and the App Icon no longer stay Blood Moon whatever the theme;
  they follow it on the player's own phone (D2, D3 here). The App Store, the site, social posts and the
  manual's figures stay Blood Moon, as D1 says. **D11**: free or Pro, the wordmark and icon, and Silver
  are decided (D1 to D4 here); the near-pair stays open (D5). ADR 0263 — **D2**: the themes are behind
  the plan though they neither play, keep nor practise, an exception recorded as one, the way D2 records
  the Practice log's (D1 here). **D4**: the wall's sentence gains a line naming the themes.
- **Relates to:** 0256 (the one plan, its doors and its wall, D2 and D3) · 0081 (the Metronome's plum
  never moves, which D5 keeps) · 0292 (the blood art the themes recolour) · 0258 (a row says its value)

## Context

ADR 0311 decided eight moon themes for 1.6 and left four questions for later. Building it turned them
into code questions: a theme behind the plan needs a door, a wall and a rule for a lapse; a wordmark that
follows needs art in eight colourings; an icon that follows needs alternate icons and iOS's rules for
changing one.

Two facts shaped the answers:

1. **The brand art is generated, never hand-drawn** (`scripts/derive-brand-svgs.py`, since ADR 0126). The
   blood lockup uses exactly two reds, `#c24a2c` and `#e3694a`, so a theme's art can be the same paths
   with two colours swapped.
2. **iOS lets an app change its icon only while it's in front, and confirms every change with an alert of
   its own** ("You have changed the icon for Red Moon"). There is no silent change and no change from the
   background.

## Decisions

**D1. The themes are part of the plan; Blood Moon is free.** A new door, `PlanDoor.theme`, titled
*Theme*.
- **The Theme screen is open to everyone.** Its cards are what the plan would bring, so a free player sees
  all eight, drawn as they are (0256 D3: locked, not hidden). Every card but Blood Moon carries the lock
  and reads *Needs the plan* to VoiceOver.
- **Tapping a locked card opens the wall in a sheet**, titled *Theme*, with its own two lines: *"The moon
  themes are part of the plan."* and *"Blood Moon is Red Moon's own colour, and it's free for good. The
  other seven moons come with the plan, along with drills, routines, Today's session and the loop
  trainer."* A purchase there applies the theme that was tapped and closes the sheet, so the player
  arrives where they were going. A returning player still reads *"Everything you made is still here."*
- **A lapse draws Blood Moon and keeps the choice.** The app draws `MoonTheme.effective`: the choice while
  the plan is on, Blood Moon while it's off. The stored choice isn't touched, so it comes back with the
  plan. Until StoreKit has answered, the choice stands: anyone with a theme other than Blood Moon chose it
  on the plan, and flashing the brand at a paying player on every launch is the worse mistake.
- **Why it's an exception to 0263 D2.** A theme neither plays, keeps nor practises; it changes how the app
  looks. Tomisin's call, recorded as an exception so it isn't read as a precedent for moving a keeping
  feature behind the plan. The general wall gains one line, *"It brings the moon themes too."*, and the
  FAQ's *What's free, and what is the plan for?* names them.

**D2. The wordmark, the logo and the mark follow the theme.** Home's title, Settings ▸ About's lockup and
the artist-name prompt's mark read `\.moonTheme` and draw that theme's art (`RedMoonWordmarkHarvest`
and so on; Blood Moon keeps its own names). The art is the blood lockup **recoloured, never redrawn**:
`derive-brand-svgs.py --themes` computes each theme's two tones in OKLCH from the theme's Practice colour
as the catalog holds it. Each tone keeps the blood red's lightness, takes the theme's hue, and scales its
chroma by how colourful that theme's Practice colour is next to terracotta's. Run through the same sum,
Blood Moon comes back as its own two reds exactly, and the script fails if it ever doesn't.

| Theme | Crescent and wordmark | Highlight | On cream | On near-black | On the icon's `#0F0F0F` |
|---|---|---|---|---|---|
| Blood Moon | `#C24A2C` | `#E3694A` | 3.87 | 4.21 | 3.93 |
| Blue Moon | `#427F99` | `#609CB7` | 3.53 | 4.62 | 4.32 |
| Jade Moon | `#2C8777` | `#4EA594` | 3.45 | 4.72 | 4.42 |
| Corn Moon | `#787C2A` | `#949A4A` | 3.54 | 4.60 | 4.30 |
| Silver Moon | `#72777E` | `#8E939B` | 3.58 | 4.55 | 4.25 |
| Pink Moon | `#AC4E94` | `#CC6CB2` | 3.91 | 4.17 | 3.90 |
| Harvest Moon | `#A26721` | `#C18442` | 3.71 | 4.39 | 4.11 |
| Cold Moon | `#3D77C1` | `#5B95E1` | 3.62 | 4.50 | 4.21 |

Every tone clears 3 : 1, the bar for a graphic, on all three grounds, as the blood art does. One universal
image per theme, as Blood Moon has, rather than a light/dark pair.

**D3. The App Icon follows the theme.** Seven alternate icons (`AppIconBlue` … `AppIconCold`), cut by the
same script on the same `#0F0F0F` square at the same size as the primary, listed in `project.yml`'s
`ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` so the build writes them into the Info.plist. The primary
icon is Blood Moon's, and so is the App Store's.
- **When it changes:** whenever the theme the app draws in changes, and whenever the app comes back to the
  front, if the icon on the Home Screen isn't the one the theme wears. So iOS's alert follows a tap on a
  card, which explains it.
- **After a lapse** the app draws Blood Moon (D1), so the next time it's open the icon goes back too, with
  iOS's alert. That is the one alert a player didn't ask for, and the honest alternative (a paid icon that
  outlives the plan) is worse.
- **Not under the UI tests**, where the system's alert would sit over whatever the next step taps.
- **Not decided here:** whether the Now Playing artwork (`DefaultArtwork`, the icon's own render, ADR 0303)
  follows. It stays Blood Moon: it is set outside any view, and nobody has asked.

**D4. Silver Moon ships once it has been seen on a phone.** The brighter dark value (`#C5D3E1`) is built.
Its art is grey by design (the table above), which is also the look to check: if the wordmark or the
Pause button reads as disabled on the phone, Silver waits and seven ship.

**D5. The Metronome and Toolkit near-pair: options, not decided.** They sit 3.9 apart in every theme but
Cold Moon (OKLab ΔE × 100, the nearer of light and dark, as 0311 measures). On Home they are in different
sections (Practice, and Learn), with different icons. The Metronome's plum never moves (0081), so every
option moves the Toolkit:

| Option | What changes | Nearest pair on Home |
|---|---|---|
| **A. Leave it** | Nothing. As built. | Metronome–Toolkit 3.9, in seven themes |
| **B. The Toolkit goes pink** | Pink in Blood, Blue, Jade, Corn and Silver; terracotta in Pink Moon; jade in Cold Moon, as built. **Changes Blood Moon's shipping look**: the Toolkit and My tabs tiles go from indigo to pink | 12.0 (Toolkit–Metronome) in five themes, 10.9 in Pink Moon; **Harvest Moon can't clear 10**: its best is corn, 8.6 from the theme |
| C. Retune the indigo bluer | A new indigo, 24° bluer | 9.1 from the plum but 8.5 from the Library's teal: it trades one near-pair for another |
| D. Move the Toolkit to jade | Jade everywhere but Jade Moon | 7.0 from the Library's teal in five themes: worse |

My recommendation is **B**, with Harvest Moon's Toolkit on corn (8.6, a near-pair accepted the way 0311
D6 accepts a loop near the bars). It is the only option that clears 10 in most themes. If Blood Moon's
look shouldn't change in 1.6, **A** costs nothing and can be revisited. Either is one line per theme in
`MoonTheme.toolkit`; `MoonThemeTests.testNoHomeSpaceSitsBesideTheTheme` would then hold the new pairs too.

**D6. How a theme reaches every colour.** The themed tokens in `PocketColor` (Practice and its family,
mastery, the song player's bars and accent, each space and its washes) are dynamic colours that ask the
current theme for their colour set when drawn. The theme travels as an environment value that is also a
UIKit trait (`UITraitBridgedEnvironmentKey`), set once at the root by `MoonThemeHost`, so a change redraws
every themed colour beneath it, including views whose bodies never read it, and UIKit's own controls,
while keeping every screen's state. None of the ~600 call sites changed. The share extension draws in the
app's theme too: the owner snapshot carries it, and a snapshot written before themes still decodes, as
Blood Moon.

## Consequences

- **What the plan covers has grown, and three places outside the repo say what it covers:** the App Store
  description, the site, and its FAQ. Each owes a line before 1.6 ships; the site's is its own PR on the
  `site` branch (ADR 0306). In the repo the wall, the FAQ and the manual are done; the manual says only
  that a locked card needs the plan, per its rule.
- **Sixteen looks still need a phone**, as 0311's Consequences say, plus the eight icons on a real Home
  Screen and Silver's grey art (D4).
- **The art is part of the build now**: change a Practice colour in the catalog and the art should be cut
  again (`./scripts/derive-brand-svgs.py --themes --app-icon`). `MoonThemeTests` checks that every theme's
  art and icon exist, not that they match the catalog's current values.
- **A UI-test launch resets the theme**, like the other stored choices that leak between tests, so the
  suite and the manual's figures are Blood Moon.

## Alternatives considered

- **Themes free.** 0311 left it open. Tomisin chose the plan.
- **Hide the locked themes.** Rejected for 0256 D3's reason: a free player should see what the plan
  brings, and a card drawn in its theme says it better than a sentence.
- **Keep a lapsed player's theme, or their icon.** Rejected: a paid look that outlives the plan is the
  thing the plan's doors exist to prevent, and keeping only the icon would leave the app and its icon in
  different colours.
- **Tint the wordmark in code.** It works for the wordmark alone (one colour), not for the two-tone mark
  and lockup, and it would leave the icon as the one piece of art made differently. Recolouring the
  lockup once, in the script that already cuts it, keeps one way of making the art.
