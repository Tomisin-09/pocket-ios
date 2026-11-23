# ADR 0311 — Moon themes: Blood Moon stays the brand, and the colour Practice wears becomes a choice

- **Status:** Accepted on 2026-11-22, for 1.6, and built on `pocket-462-moon-themes-build` with ADR 0312. Tomisin chose it after a workshop that drew eight
  themes on four real screens and measured each against the colours the app already uses: *"Awesome, I'm
  happy with this! Let's write up the ADR"*. D11 lists what is not decided here.
- **Date:** 2026-11-22 (`pocket-461-moon-themes`)
- **Amends:** ADR 0292 — **D1**: there is a picker again, and the teal look returns as Blue Moon. Blood
  Moon stays the default, and D3's art, D6's printed colour and D7's outside-the-app look stand. ADR 0081
  — **Slice 2**: eight themes instead of two, and a theme maps every space, not only Practice and the
  Library; the Metronome's plum still never moves. ADR 0096 — **D3**: the Toolkit is indigo in every theme
  but Cold Moon, where it is jade. ADR 0100 — the Journal's gold stands in every theme but Corn Moon
  (terracotta) and Harvest Moon (crimson). ADR 0187 — **D16**'s crimson, which today shows only as the
  song player's snag ticks, stands in every theme but Pink Moon (teal).
- **Relates to:** 0023 and 0031 (the loop palette and recolouring a loop, both untouched) · 0062 (the
  contrast bar every new family meets) · 0162 (Settings grouped by what you are trying to change) · 0258
  (a row says its value) · 0211 (why the Oracle has no Home tile) · 0308 D7 (the chord colours, fixed) ·
  0061 (the brand art, unchanged)
- **Amended by:** ADR 0312 (2026-11-22) — **D1**: the logo and the App Icon follow the theme on the
  player's own phone; the App Store, the site, social posts and the manual's figures stay Blood Moon.
  **D11**: the themes are part of the plan, Blood Moon free; Silver ships once seen on a phone; the
  Metronome and Toolkit near-pair is settled: the Toolkit goes pink (Tomisin, 2026-11-23). **D5**: the
  Toolkit column is redrawn: pink in Blood, Blue, Jade, Corn and Silver, terracotta in Pink Moon, corn in
  Harvest Moon, jade in Cold Moon; the Library, Metronome, Journal and Oracle columns stand. Everything
  else stands.

## Context

ADR 0292 made Blood Moon the app's only colouring in 1.4.1. It turned down a theme picker as more to build
and as splitting the brand, but left it *"not ruled out for later as an option of its own"*. For 1.6
Tomisin asked whether the app could offer themes: Blood Moon, the original teal look (*Blue Moon*), and
how many more.

**What a theme changes.** The colour Practice wears, and nothing else that carries a meaning. That colour
runs through the whole Practice space (Today's session, the routine and exercise cards, a running
routine's progress bar, tempo staircase and Pause button), fills *Start today's session* and the mastery
dots on Home, and since 0292 D4 colours the song player's waveform and speed bar. Nearly 400 places in the
code read it from the one `practice` token, so swapping it is cheap. Finding a colour that collides with
nothing is the hard part.

**How the candidates were measured.** Each candidate keeps a hue in OKLCH and solves for lightness, so
Practice text on the cream canvas matches Blood Moon's 4.84 : 1 and words on its button clear 4.6 : 1, the
bar `BrandColorContrastTests` holds. Distance between two colours is OKLab ΔE × 100, taking the nearer of
the light and dark values; bigger is easier to tell apart. Blood Moon itself sits 7.9 from the Oracle's
crimson and 4.3 from the orange loop.

**The first pass held every other colour fixed**, and only four candidates fitted. Tomisin then set the
direction this ADR follows: a loop sharing the theme's colour is not a showstopper, because people can
recolour loops (0031); the snag ticks can follow the theme; and the other spaces' colours *"can be updated
to provide contrast with the chosen theme, these don't need to be fixed"*. With that, all eight fit. The
first Silver read as greyscale in dark mode, and Tomisin asked for it brighter: its dark value, `#959BA1`,
sat 1.2 from the app's secondary text grey `#9B9B9B`, so every Practice link read like a caption.

**Three facts the workshop turned up:**
- **The Metronome's plum and the Toolkit's indigo are 3.9 apart**, in Blood Moon as shipped: two violets,
  side by side on Home.
- **The Oracle has no Home tile** (0211). The second tile in *Learn* is the player's own Toolkit tool, My
  tabs until they pick one, drawn in the Toolkit's colours. The Oracle's colour shows only as the snag
  ticks under the waveform, which `WaveformDownbeat` draws in `PocketColor.oracle`.
- **A loop's default colour is derived, not stored.** `LoopColor` takes a palette slot by start order
  (red, orange, gold, magenta, violet, blue); only a recoloured loop stores anything (0031).

## Decisions

**D1. Eight themes, and Blood Moon stays the default and the brand.** Blood Moon, Blue Moon, Jade Moon,
Corn Moon, Silver Moon, Pink Moon, Harvest Moon and Cold Moon. Someone who never opens the picker sees
Blood Moon, and so does every existing install: no stored choice means Blood Moon, so nothing migrates.
Outside the app nothing changes: the logo, the App Icon, the App Store, the site, social posts and the
manual's figures are Blood Moon.

**D2. What a theme changes.** One colour family for Practice (`practice`, `practiceCTA`,
`practiceCardWash`, `practiceCircleWash`); `mastery`, which tracks Practice; the song player's
`waveformBar`, `waveformBarPlayed` and `waveformAccent`, which follow the theme as 0292 D4 has them follow
Blood Moon; and each space's family, by D5. **What leaves the app stays Blood Moon:** the tab PDF's notes
lane (0292 D6) and the App Store frames, because someone else reads them.

**D3. Spaces move, meanings don't.** These look the same in every theme: the live green (`active`,
`confirm`, the add-song button, Reset, Grid), the delete red (`danger`), the selection handles (`fine`),
the marker colours (`pin`, `marker`), the chord colours (0308 D7), the canvas, ink and text colours, the grid
lines, and the loop palette. A theme never takes green or red. **Never reorder the loop palette per
theme** to keep a loop off the bars: default loop colours are derived from that order, so a reorder would
recolour every existing loop the moment someone switched theme.

**D4. Six new colour families, and teal's button comes back.** Light / dark values:

| Family (theme) | Practice text | Button | Card wash | Icon circle |
|---|---|---|---|---|
| Terracotta (Blood) | `#B0391B` / `#E07E57` | `#B23F20` / `#E39872` | `#E8C7B6` / `#37241B` | `#EFD6C7` / `#4A2C1E` |
| Teal (Blue) | `#2B6982` / `#60A8C7` | `#18698B` / `#799BA9` | `#ACCBD3` / `#153A44` | `#C2D2D5` / `#1D4E5C` |
| Jade | `#006F5F` / `#3CAC96` | `#007262` / `#67B9A7` | `#B1D9CF` / `#152F29` | `#C4E4DC` / `#113D35` |
| Corn | `#63660B` / `#9AA044` | `#65690F` / `#A9AF67` | `#CFD2B1` / `#292B17` | `#DCDEC4` / `#353717` |
| Silver | `#5D6269` / `#C5D3E1` | `#60656C` / `#D4DFEB` | `#C9CFD6` / `#262F39` | `#D7DCE1` / `#34414F` |
| Pink | `#9B3F85` / `#D37EBC` | `#9F4188` / `#D697C3` | `#E3C4D9` / `#34232F` | `#ECD3E4` / `#452A3E` |
| Harvest | `#8E5400` / `#D7892A` | `#925700` / `#DB9E5D` | `#E3CAB1` / `#342617` | `#ECD8C4` / `#462F17` |
| Cold | `#2762AA` / `#659DE3` | `#2A65AD` / `#83ADE2` | `#BCD1EC` / `#1E2A39` | `#CDDDF3` / `#23364E` |

Terracotta and teal are the app's own values; teal's button is `TealCTA` as 1.4 shipped it, deleted by
0292 D4 and restored from git. The washes copy the terracotta family's lightness, so an icon on its circle
clears about 4.4 : 1, Blood Moon's own figure. Silver has a trace of blue (OKLCH chroma about 0.02) so it
reads as moonlight, not as grey.

Contrast, light / dark:

| Theme | Practice text on the canvas | Words on the button |
|---|---|---|
| Blood Moon | 4.84 / 7.12 | 4.60 / 8.79 |
| Blue Moon | 4.84 / 7.74 | 4.86 / 6.91 |
| Jade Moon | 4.85 / 7.35 | 4.66 / 8.86 |
| Corn Moon | 4.86 / 7.31 | 4.66 / 8.80 |
| Silver Moon | 4.88 / 13.45 | 4.67 / 15.19 |
| Pink Moon | 4.85 / 7.30 | 4.65 / 8.86 |
| Harvest Moon | 4.88 / 7.32 | 4.65 / 8.85 |
| Cold Moon | 4.89 / 7.31 | 4.68 / 8.83 |

**D5. Each theme has its own space palette, by one rule.** A space keeps its Blood Moon colour unless it
sits within 10 of the theme's colour. A space that moves takes a family the app already has, at least 10
from the theme and checked against every other space on Home. The snag ticks read the Oracle's colour, so
they move with it.

| Theme | Library | Metronome | Journal | Toolkit | Oracle (snag ticks) | Nearest space on Home |
|---|---|---|---|---|---|---|
| Blood Moon | teal | plum | gold | indigo | crimson | Journal, 10.9 |
| Blue Moon | **terracotta** | plum | gold | indigo | crimson | Toolkit, 12.1 |
| Jade Moon | **terracotta** | plum | gold | indigo | crimson | Journal, 17.6 |
| Corn Moon | teal | plum | **terracotta** | indigo | crimson | Journal, 14.5 |
| Silver Moon | **terracotta** | plum | gold | indigo | crimson | Toolkit, 14.0 |
| Pink Moon | teal | plum | gold | indigo | **teal** | Toolkit, 10.2 |
| Harvest Moon | teal | plum | **crimson** | indigo | crimson | Journal, 13.4 |
| Cold Moon | **terracotta** | plum | gold | **jade** | crimson | Metronome, 11.4 |

What forced each move: Blue Moon's Library was its own teal, which is also how 1.4 shipped it. The
Library sat 7.0 from Jade, 6.4 from Silver (in light mode) and 5.9 from Cold; Corn's Journal was 9.3 from
the gold and Harvest's 7.6; Pink's snag ticks were 6.8 from the crimson; Cold's Toolkit was 8.0 from the
indigo. Harvest's Journal and its snag ticks share crimson on different screens. If Jade Moon doesn't ship,
Cold Moon's Toolkit takes pink instead (16.7 from the theme, 12.0 from the Metronome), so jade isn't
needed only for that.

Moving the Journal also moves the journal-note button in a running routine's header, which reads the
Journal's colour; under Corn and Harvest it would otherwise sit beside the theme colour.

**D6. A loop near the theme's colour is accepted.** Loops draw as a line under the waveform and tint their
row's play button, and people can recolour one (0031). By default the nearest loop is a song's second loop
in Blood Moon (orange, 4.3 from the bars) and Harvest Moon (orange 7.0, then gold 7.3, the third), its
fourth in Pink Moon (magenta, 5.9) and its sixth in Cold Moon (blue, 3.6). Neither the bars nor the loops
change for it.

**D7. Choosing a theme: a Theme row on Appearance, opening a screen of previews.**
- **Settings ▸ Appearance** gets a **Theme** row at the top, a `HubRow` whose value is the theme's moon and
  name. *System / Light / Dark* stays one segmented control on Appearance, directly under it, and *Motion*
  and *Note names* follow as now. The Settings hub's Appearance row shows the theme as its value.
- **The Theme screen** is a list of eight cards. Each card draws that theme's own *Start* button and a
  strip of waveform twice, on the cream canvas and on the near-black one side by side, with the theme's
  name and one line. It shows the theme rather than a swatch that names it, and someone on *System* sees
  both appearances in a day. The screen doesn't repeat the Light/Dark control.
- **Tapping a card applies it at once**, and the screen recolours around you, so there is no Save button.
- The lines, as written for the screen: Blood Moon, *"The moon in the Earth's shadow, turned red."* Blue
  Moon, *"A second full moon in one month."* Jade Moon, *"Sea green, cool and clear."* Corn Moon,
  *"September's full moon, in harvest olive."* Silver Moon, *"Moonlight with the colour taken out."* Pink
  Moon, *"April's full moon, named for a spring flower."* Harvest Moon, *"The low orange moon of autumn."*
  Cold Moon, *"December's full moon."*

**D8. A theme is a value the app can read, not only a switch.** The Theme screen draws themes that aren't
active, so each theme is a value carrying its families (for example `Theme.harvest.practice`), and
`PocketColor`'s role tokens read the current one. The choice is one stored setting, read through one
constant, the way `AppearancePreference` is, and applied once at the `PocketApp` root.

**D9. The asset catalog grows by family, not by theme.** Four colour sets for each new family (Jade, Corn,
Silver, Pink, Harvest, Cold), each with a light and a dark value, plus `TealCTA` restored. The spaces that
move reuse terracotta, crimson and teal, plus jade for Cold Moon's Toolkit. This keeps 0081's design: a
theme is a mapping onto shared families, never a second baked palette.

**D10. What holds it.** `BrandColorContrastTests` runs once per theme, in both appearances, holding
Practice text, the button's words and the song player to 4.5 : 1 as it does for Blood Moon now. A second
test checks that every space on Home stays at least 10 from the theme's colour in every theme, so a later
change to one family can't quietly bring two colours together.

**D11. Not decided here:**
- **Free or Pro.**
- **Whether the wordmark and the App Icon follow the theme.** The wordmark can be tinted in code; the icon
  would need an alternate icon per theme. Outside the app the brand stays Blood Moon either way (D1).
- **The Metronome and Toolkit near-pair** (3.9 apart). Only Cold Moon separates them. Fixing it everywhere
  means moving the Toolkit in Blood Moon too, which changes the shipping look, so it is a decision of its
  own.
- **Whether all eight ship in 1.6.** The brighter Silver hasn't been seen on a phone; if it still reads as
  grey, it waits and seven ship.

## Consequences

- **The manual owes a change when this is built.** The Settings page gains the Theme row and screen. The
  manual's figures stay Blood Moon and should say so once. Its prose can no longer name a space's colour:
  `home-and-library.md` calls *Start today's session* *"the filled red card"*, which is true today and
  stops being true for anyone on another theme.
- **The design brief's colour table stays Blood Moon's**, which is the default; §3.1 points here for the
  others.
- **A space's colour is still a cue to where you are**, within the theme someone chose. Switching theme
  means learning a few colours again, which is theirs to choose.
- **Sixteen looks to check, not two.** Eight themes in two appearances. Green tests can't see a colour that
  reads wrong, so each theme gets a pass on a phone before 1.6 ships, Silver's light-grey Pause button
  first, to check it doesn't look disabled.
- **The share extension draws `PocketColor` too** (the catalog is shared with it, 0264 D10). If the stored
  choice isn't somewhere the extension can read, it shows Blood Moon. Settle that when building.
- **Pink, Harvest and Cold put the bars near a default loop colour** (D6). That is accepted.

## Alternatives considered

- **Keep one colouring** (0292 D1). The workshop showed eight themes fit without giving up a meaning, and
  Blood Moon stays the default, so the brand doesn't split.
- **Two themes only, Blood and Blue** (0081 Slice 2). More fit.
- **Hold every other space's colour fixed.** Only four themes fitted, and the wheel's warm half was closed
  to them. Tomisin chose to let spaces move.
- **Keep the song player one colour in every theme**, so a loop never sits near the bars. Rejected for
  D6's reasons; the song player follows the theme, as it follows Blood Moon now.
- **Reorder the loop palette per theme.** It would recolour people's loops (D3).
- **A grid of moons on the Appearance screen.** The cheapest, but a coloured dot names a theme without
  showing it, and you'd have to leave Settings to see what it does.
- **One full-screen preview at a time, with a Use button.** The most vivid, but eight miniature Practice
  screens that go out of date whenever the real one changes.
- **Light/Dark repeated on the Theme screen.** One setting in two places; the split cards show both
  appearances instead.
- **Silver's first values.** Its dark value was the secondary text's grey.

## Build notes (for 1.6)

- `Pocket/UI/DesignTokens.swift`: the role tokens (`practice` and its family, `mastery`, the waveform trio,
  `library`, `metronome`, `journal`, `toolkit`, `oracle` and their washes) read the current theme instead
  of a fixed `Color("…")`.
- `Pocket/App/AppSettings.swift`: the stored key and its one default (Blood Moon), bound everywhere through
  that constant.
- `Pocket/Features/Settings/AppearanceSettingsView.swift`: the Theme row above the segmented control.
  `SettingsView.swift`: the hub row's value. A new Theme screen with the eight cards.
- `Colors.xcassets`: the 24 new colour sets and `TealCTA`.
- Tests per D10. Then `docs/manual/` (Settings, the figures note, the red-card line), `PROJECT.md`,
  `docs/design-brief.md` §3.1 and `CHANGELOG.md`.
