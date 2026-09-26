# ADR 0223 — one way off the keyboard, and the meter leaves the bar

- **Status:** Accepted. Built on `pocket-333-keyboard-and-meter`.
- **Date:** 2026-09-26
- **Amends:** ADR 0052 — the exercise meter control it put in the run-setup nav bar moves onto the
  staircase's length line. What the control does — local edit state, committed on Start, shown only
  while stopped and outside a routine — is unchanged.
- **Relates to:** ADR 0043 (the standalone metronome), ADR 0077 (in a routine an exercise's meter is
  fixed), ADR 0126 (nothing on a nav bar may vary in width), ADR 0167 (the Link field that shipped
  with no way off the keyboard), ADR 0213 (the accessibility pass that measured the automator's
  32pt targets), ADR 0221 D10 (the length line).
- **Schema:** none.

## Context

Reviewing the build before the manual reshoot turned up three things on one screen.

**1. There was no way off the keyboard — anywhere.** On a device on iOS 26.6 the metronome's tempo
could be typed and never left: it is a number pad, which has no Return key, and the checkmark that
should float above it was not there. The same was true on every screen. The app's checkmark was a
SwiftUI `ToolbarItemGroup(placement: .keyboard)`, attached at fifteen call sites — thirteen through
`keyboardDoneButton()`, two hand-rolled. On the iOS 26.5 simulator it drew; on the device it did not,
and nothing in the app differs between the two. SwiftUI's keyboard toolbar has a history of failing
like this: in sheets on iOS 17, on real devices only on iOS 16, missing from the accessibility tree on
26.1. The simulator run that looked for the device bug found a second one: with the metronome's
automator on, **four** checkmarks drew side by side — one for the screen, one per number field.

**2. The metronome's title sat off centre.** The trailing side of the bar held the journal pencil and
the meter (`4/4 ⌄`); the leading side held one back button. Measured on a 402pt phone, a centred
"Metronome" would have ended about 2pt short of the trailing pair — too little room — so iOS placed it
against the back button instead. On a 375pt phone the two would overlap.

**3. The automator's controls were too small to hit.** ADR 0213's pass measured the six −/+ nudges at
32×32 and the save-as-exercise bookmark at 36×36, under the 44pt minimum.

## Decision

### D1 — The keyboard's checkmark is one app-wide accessory, not a toolbar each screen attaches

`KeyboardDismissAccessory`, installed once at launch the way `NavigationBarStyle` is. It listens for
the keyboard's frame notifications and floats a checkmark just above the keyboard's trailing edge, in
a button-sized window of its own that never becomes key. It depends on nothing SwiftUI's toolbar
bridging does, so the failure above cannot reach it.

- **Every text input gets it**, except a search field (Search and Cancel end it) and a field inside
  an alert (the alert's buttons do). The old contract was opt-in, which is how ADR 0167's Link field
  went without one; a global accessory has nothing to forget.
- **One button, whatever the screen holds.** Stacking is impossible by construction.
- `keyboardDoneButton()` and both hand-rolled copies are **deleted**, not kept alongside. On an OS
  where SwiftUI's toolbar does draw, keeping them would put two checkmarks on screen.
- It is glass on iOS 26, to sit with the keyboard the way the system's own floating button does, and
  a material disc before that. Its colour is the app's ink, not the host screen's tint — a global
  accessory does not know which feature it is over, and the per-screen tints are not missed.

Its accessibility label stays **Dismiss keyboard**, which the UI tests already tap by.

### D2 — The meter is a control in the screen, not text in the nav bar

- **Metronome:** the meter control moves from the bar's trailing edge to a chip under the beat dots.
  Same label, same sheet. The bar keeps the back button and the pencil, one either side, and the title
  centres. Under the dots it also sits with what it changes: pick 3/4 and the row above becomes three
  dots.
- **Exercise run screen** (amending ADR 0052): the meter moves from the run-setup bar to a chip that
  closes the staircase's length line — `≈ 1 min 5 s · 16 bars · 4/4 ⌄`. The meter decides how long
  a bar is, so it sits beside the bar count it governs. The bar keeps ⓘ, and the pencil where ADR 0221
  D7 shows it.

A mockup put the exercise chip at the top of Practice Settings instead; rejected because the panel is
collapsed by default, which would put the meter a tap deeper than it has ever been.

### D3 — The metronome's transport steps aside while you type

While the keyboard is up the pinned Start/Pause button is hidden. Without that, the field being typed
into ended up squeezed against Start, half hidden, and the checkmark floated over Start's trailing
edge. Nothing about a click is lost: dismissing the keyboard brings the transport back, and the click
keeps running meanwhile.

### D4 — The automator's targets are 44pt, drawn as before

The nudges are still drawn at 32 and the bookmark at 36, inside a 44pt touch frame. Drawing them at 44
would crowd the numbers they flank.

## Consequences

- The manual's metronome and exercise figures change: `metronome/screen`, `metronome/tempo-controls`,
  `reference/metronome`, and every exercise run-setup figure that shows the bar. They are folded into
  the reshoot already owed, not shot per slice.
- `docs/manual/metronome.md`, `exercises.md` and the two reference pages describe the meter where it
  now is.
- `KeyboardDismissUITests` counts the checkmarks rather than finding one: a check that one exists
  passed with four.
- **Verified on the device, iOS 26.6, 2026-09-26** — the only place the failure showed, since the
  local simulator is 26.5. On the phone: a ✓ above the metronome's number pad that commits the typed
  tempo, one ✓ (not four) with the automator on, a ✓ above the Journal note sheet's keyboard, the
  metronome title centred, and both meter chips opening their sheets.
