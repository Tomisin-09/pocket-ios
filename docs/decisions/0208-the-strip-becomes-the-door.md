# ADR 0208 — the strip becomes the door

- **Status:** Accepted
- **Date:** 2026-09-09 (`pocket-309-a-journal-worth-opening`)
- **Amends:** ADR 0196 — **D3's refusal to make the strip tappable is discharged**, on the condition
  D3 itself set. D3 declined it because doing so *"would reopen 0176's placement as a side effect of
  adding a number, and settle by accident a decision that deserves to be taken deliberately"*. This
  is that decision, taken on its own. D4 (nothing logged, nothing drawn) is untouched and becomes
  load-bearing: it is what keeps a fresh install from meeting a door onto an empty screen.
- **Amends:** ADR 0176 — **D2's placement of the Practice log's door** moves from a row on the
  Journal to Home's *This week* strip, and **D3's refusal of a live summary strip on the Journal is
  affirmed rather than reversed** — the strip is on Home, which is not the screen that objection was
  about. D4 (the row hides while searching) goes with the row. The rename, the constraints and
  everything else in 0176 stand.
- **Relates to:** ADR 0117 (the two-tier *promise / payoff* design this finally assembles in one
  place, and the practice log it built), ADR 0197 (Home's six-destination map — why this is not a
  seventh tile), ADR 0144 (the Journal and the log are free forever — the gate this must not
  change), ADR 0070 (nothing here is a grade), ADR 0165 (the manual quotes the app),
  `docs/directions-2026-09.md` §5d item 6, which this closes
- **Schema:** none. No `@Model`, no new persisted key.

## Context

`PracticeLogView` has had exactly **one call site in the entire app** — a row above the Journal's
timeline — since ADR 0176 put it there. Home has had a *This week* strip since ADR 0196: three
numbers over the same seven days, deliberately inert.

They are the two halves of one design. ADR 0117 drafted a two-tier **promise / payoff** shape for
Home — a summary you read at a glance, opening the screen that holds it in full — and had nowhere to
put the payoff. 0176 placed the payoff in the Journal. 0196 built the promise on Home. Neither ADR
could join them, and both said so:

> **0196 D3:** Making the strip a door would reopen 0176's placement as a side effect of adding a
> number, and settle by accident a decision that deserves to be taken deliberately.

> **0196, Consequences:** **Not covered:** … whether the Practice log should be closer than two taps.
> The last one is now the only part of §2 still to argue.

> **`docs/directions-2026-09.md` §5d item 6:** The practice log is still two taps inside the Journal.
> Option A's stat strip is a promise; the payoff screen stays buried.

So this is not an override of ADR 0196. It is the deliberate decision 0196 asked someone to take, and
the last open item of `directions` §5d.

## Decision

### D1 — Home's *This week* strip becomes the way into the Practice log

Tapping the three numbers pushes `PracticeLogView`.

**The promise opens the payoff, and nothing else changes about either.** The strip still shows
minutes, days and notes over the last seven days; the log still shows the same history at three
scales. What is added is the one relationship a player would assume already existed — that the
summary is a summary *of* something they can open.

**A `NavigationLink`, not a flag and a `navigationDestination` on `HomeView`.** `HomeView` binds its
other destinations through `isPresented` for a specific reason recorded in ADR 0090: a just-inserted
`@Model`'s `persistentModelID` flips on the first autosave and pops an item-bound destination.
`PracticeLogView` takes no model, so none of that applies, and a link costs `HomeView` no state.

### D2 — the Journal's row is deleted, not kept

One door, not two.

That is ADR 0176 D2's own rule — *"a row and a menu item a few centimetres apart on the same screen
is redundancy"* — and keeping the Journal row while adding the Home strip would rebuild the exact
duplication 0176 was tidying up, one screen further apart. It would also leave two doors whose
*discoverability* differs: a player who found one would have no reason to look for the other, so the
second is not a second chance, it is a second thing to maintain.

**The band it occupied is the band ADR 0207 D6 spends on the month rail.** So the Journal ends up
with the same number of things above its list as it had before this branch started, not one more.
That is a genuine consequence rather than a coincidence — 0207 and this decision were planned
together, and the row's removal is what paid for the rail.

**What goes with the row:** ADR 0176 D4's *hide while searching* rule, which existed only because a
navigation row sitting above *No matches* claims the screen still has somewhere to go. Home has no
search, so the rule has nothing left to apply to.

### D3 — not a seventh Home tile

ADR 0197 landed a six-destination map, two to a row, a week ago. A seventh breaks the grid and
reopens a layout decision that has not had time to prove itself.

More to the point, a tile would be the *wrong* shape: the six are permanent destinations, learned
once by hue and position, and they are drawn whether or not there is anything behind them. The
practice log is not like that — it is the reading of a number that is already on the screen, and it
should be absent exactly when that number is.

### D4 — the door appears exactly when there is something behind it

ADR 0196 D4 already drew **nothing at all** when `runs.isEmpty` — not three zeroes, not an empty
state. That guard now carries a second job: on a fresh install there is no strip, therefore no door,
therefore no way to reach a payoff screen that would say *Nothing here yet*.

**This is a real behaviour change and it is the intended one.** Until now the Journal's row was
always present, so the practice log could be opened on day one and would explain what would fill it.
That explanation is now unreachable until the first run finishes. The trade is deliberate: a
permanent door onto an empty screen is the wall-of-zeros problem ADR 0117 named and 0176 D3 declined
a strip over, and a player who has never practised cannot read a history of their practising. The
first finished drill draws the strip, and with it the door.

### D5 — an accessibility identifier, so the label can stay the numbers

The strip carries `UITestHooks.practiceLogDoor` and **no accessibility label of its own**.

This is not a testing detail; it is what protects the control. The obvious move is to label the
button *"Practice log"* — it names the destination, it is stable, and it would let the shoot keep the
`app.buttons["Practice log"]` lookup it already had. But a `Button`'s label replaces the
concatenation of its children, so VoiceOver would announce a bare destination name **in place of the
three numbers that are the entire reason the strip exists**. The label is left to concatenate; the
identifier is what the harness aims at. `UITestHooks.takeRowOpen` and `takeAddMoment` are the same
pattern for the same reason.

The header gains a trailing chevron, so the affordance is visible as well as announced.

### D6 — the shoot's gate moves to the navigation bar

⚠ **`HomeSection` uppercases its title, and both screens use it for their first section.** Home's
strip and `PracticeLogView`'s first section both render **`THIS WEEK`** — which is the string
`ManualShotsUITests.testPracticeLog` gated on:

```swift
tap(row, labelled: "Practice log",
    revealing: app.staticTexts["THIS WEEK"], called: "the Practice log screen")
```

Driven from Home, that assertion is **true before the tap**. It is the mistake the same file names
two lines above it — *"an assertion already true of the screen we are leaving"* — and it fails by
passing: a swallowed tap would leave the shoot on Home, the assertion would agree, and
`journal/progress` would come back a clean photograph of the wrong screen.

The gate becomes `app.navigationBars["Practice log"]`, which is the idiom five other shoot steps
already use, is the screen's identity rather than its contents, and is what `capture` itself
resolves. It also stops the gate depending on how far the log has scrolled.

**The slug `journal/progress` does not change.** A shot slug is an id (ADR 0176 D7); what changed is
its *drive state*, which is a harness and `shots.md` edit.

## Consequences

- **`docs/directions-2026-09.md` §5d item 6 is closed**, and it is the last open item of §2.
- **The manual stated the old route in five places**, including `reference/home-and-library.md`,
  which said of the strip in as many words: *"It is a readout only: tapping it does nothing."* A
  sentence that describes a deliberate non-behaviour is exactly the kind that survives the behaviour
  changing, because nothing about it looks stale.
- **The gate is free-side and stays that way.** ADR 0176 declined a Practice hub placement because
  `proGated(.practice)` would have paywalled the log, and ADR 0144 keeps the Journal and the log free
  forever. Home is ungated and `PracticeLogView` carries no `isPro` read at all — checked rather than
  assumed, because that is the failure this move could plausibly have introduced.
- ⚠ **`reference/home` was already knowingly stale** (ADR 0196 recorded the debt and assigned it to
  the tile-grid work). This change gives that figure a chevron it does not have, which does not
  create new debt so much as add to a bill already outstanding.
- **`journal/timeline` needs reshooting for a second reason.** ADR 0207 changed the row treatment;
  this removes the Practice log row above it. One reshoot covers both, which is why it was not done
  between the two.
- **`HomeSection` grew a `chevron` flag** — a `Bool`, not a `@ViewBuilder` accessory slot. One caller
  wants one glyph; a generic slot would be a shape invented for a need that does not exist.
- **A screen with one call site is easy to move and easy to lose.** `PracticeLogView` has now been
  relocated twice (0176, this) and both times the whole cost was in prose and a harness, not in code.
  The thing that made that cheap is that it takes no arguments and owns its own queries.
