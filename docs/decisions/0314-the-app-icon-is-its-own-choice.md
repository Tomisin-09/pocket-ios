# ADR 0314 — The App Icon is its own choice: it matches the theme, or keeps one moon

- **Status:** Accepted on 2026-11-23, for 1.6, and built on `pocket-468-app-icon-picker`. Tomisin asked
  the day the themes merged *"to set the icon change as optional or even to provide the option of
  changing the icon only"*, and settled the two open calls: *"An icon on its own would be part of the
  plan. The default would be to match the theme."* It is the last 1.6 item.
- **Date:** 2026-11-23
- **Amends:** ADR 0312 — **D3**: the App Icon follows the theme only while the player's icon choice is
  *Matches theme*, which is the default; a player on the plan can keep one moon's icon whatever the
  theme (D2, D3 here). Its Alternatives line, which rejected an icon in a different colour from the app,
  rejected it for a lapse; on the plan it is now the player's to choose. The lapse rule stands. ADR 0311
  — **D7**: the App Icon row sits directly under the Theme row, so *System / Light / Dark* is one control
  in the same group under both, no longer directly under Theme (D1 here). ADR 0263 — **D2**: the themes'
  exception to the free line covers their icons too, under a door of their own (D3 here). The rule
  stands.
- **Relates to:** 0258 (a row says its value) · 0256 D3 (locked, not hidden; a purchase arrives where
  you were going) · 0303 (the Now Playing artwork, still Blood Moon's) · 0126 (the brand art is cut by a
  script)
- **Schema:** none. One stored setting, `appIcon`, beside `moonTheme`.

## Context

ADR 0312 D3 tied the Home Screen icon to the theme: change the theme and iOS changes the icon, with an
alert of its own. Seen on a phone, that is two choices made as one. A player can want the colours and not
the icon (the icon is how they find the app on a Home Screen arranged around it), or want a moon's icon
without recolouring the app.

1.6 hasn't shipped, so no player has the 0312 behaviour yet, and the default can be anything. Tomisin
chose to keep it: the icon matches the theme unless the player says otherwise.

## Decisions

**D1. An App Icon row on Appearance, directly under Theme.** A `HubRow` titled *App Icon* whose value
is the icon on the Home Screen, drawn small, and its name: *Matches theme*, or the moon's (*Pink Moon*).
It sits under Theme because the two are chosen together and one can follow the other. *System / Light /
Dark* stays in the same group, under both, with its footnote.

**D2. The choice: *Matches theme*, or one of the eight moons.** `AppIconChoice` (pure, Foundation-only,
beside `MoonTheme`) is `.matchesTheme` or `.moon(theme)`, stored as one string under
`AppSettings.Key.appIcon`: `matchesTheme`, or the moon's `rawValue`. Nothing stored, or a value this
version doesn't know, is *Matches theme*. One choice answers both asks:
- **An icon that stays put:** keep Blood Moon's (or any moon's) icon, and the theme can change under it.
- **An icon on its own:** leave the app in Blood Moon and keep Pink Moon's icon.

Choosing Blood Moon's icon is not the same as *Matches theme* under Blood Moon: the first stays when the
theme changes, the second goes with it.

**D3. A moon's icon is part of the plan, as its theme is.** Blood Moon's icon and *Matches theme* are
free; the other seven moons' icons need the plan.
- **The App Icon screen is open to everyone**, its tiles drawn as they are, and a locked tile carries the
  lock and reads *Needs the plan* to VoiceOver (0256 D3).
- **A locked tile opens the wall in a sheet**, through a door of its own, `PlanDoor.appIcon`, titled
  *App Icon*, the name of the screen it was tapped on. Its two lines: *"The moon icons are part of the
  plan."* and *"Blood Moon's icon is Red Moon's own, and it's free for good. The other seven come with the
  plan, along with their themes, drills, routines, Today's session and the loop trainer."* A purchase
  keeps the icon that was tapped and closes the sheet. A returning player still reads *"Everything you
  made is still here."*
- **A lapse shows Blood Moon's icon and keeps the choice**, as 0312 D1 does for the theme:
  `AppIconChoice.effective` gives way to Blood Moon's icon while the plan is off, and the choice stands
  until StoreKit has answered. *Matches theme* needs no rule of its own: it follows the theme the app
  draws in, which is already Blood Moon after a lapse. So a lapse takes both back to Blood Moon, and
  nothing paid for outlives the plan.
- The general wall's sentence is unchanged: *"It brings the moon themes too."* covers their icons.

**D4. The App Icon screen.** *Matches theme* first, as a card drawing the icon the current theme wears,
with the line *"Changes with the theme. Now Harvest Moon."* Under it, *"Or keep one icon, whatever the
theme"*, and the eight moons' icons as tiles in the Theme screen's order, each in the rounded square iOS
cuts, with the moon's name under it. The current choice is ringed and marked selected. **A tap applies
at once**, as on the Theme screen: there is no Save, and iOS's alert follows the tap that explains it.
- **The tiles are the icons' own renders.** An app icon set isn't reliably drawable by name, so
  `derive-brand-svgs.py --app-icon` (and `--themes --app-icon`) scales each rendered icon down to 256²
  with `sips` into an imageset of its own (`IconTile`, `IconTileHarvest` …, `MoonTheme.iconTileImage`).
  The same pixels, never drawn again, so a tile can't show a different icon from the one it sets, and
  the screen holds eight small images, not eight 1024² ones.

**D5. What doesn't change.** The icon is still set only while the app is in front, only when it's wrong,
and never under the UI tests (0312 D3), now from the choice rather than the theme. The primary icon, the
App Store's and the Now Playing artwork stay Blood Moon's. A UI-test launch clears the choice with the
theme, so the suite and the manual's figures match.

## Consequences

- **What the plan covers grows by the icons**, which the App Store description, the site and its FAQ
  already owe a line about for the themes (0312's Consequences). The line can name both at once.
- **The manual's Appearance section** gains the row (done in this change); its figure, like the Theme
  screen's, is shot with 1.6's reshoot.
- **A player can now see two alerts' worth of change from one visit**: a theme that the icon matches, then
  an icon kept. Each follows its own tap, so each explains itself.
- **Change the art and the tiles are cut with it**: the script writes the tile wherever it writes an icon.
  `AppIconChoiceTests` checks that each moon has a square tile, not that it matches its icon.

## Alternatives considered

- **A switch, "Icon follows theme".** It covers only the first ask, and the second would still need a
  picker, so one picker with *Matches theme* in it does both with one control.
- **Icons free.** Rejected by Tomisin: an icon on its own is part of the plan, as the themes are, and
  keeping the two on one side of the line keeps the line simple to state.
- **Reuse the Theme door.** Its wall is titled *Theme* and talks about colours; a door's title is the
  name the player tapped, and on this screen that is *App Icon*.
- **Draw the tiles from the app icon sets by name.** It works for some icon sets on some iOS versions and
  not others; a tile that comes up blank is worse than one more imageset per moon.
