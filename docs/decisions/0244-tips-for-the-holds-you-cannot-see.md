# ADR 0244 — Tips for the holds you cannot see

- **Status:** Accepted — decided with Tomisin, 2026-10-03. Built on `pocket-356-tags-for-what-you-cannot-see`.
- **Date:** 2026-10-03
- **Relates to:** 0149 and 0220 (the first-song walkthrough, which comes first — D3 — and whose ring the
  tips reuse — D7) · 0145 (help you look up; the tips are its opposite number, and neither replaces the
  other) · 0163 (Settings ▸ Song player, reached from the settings hub and by holding Loop controls, which
  gains the switch — D6) · 0195 (a setting that starts off is found by nobody — D6) · 0238 (the Snags
  panel's own line about its hold, which is why snag rows get no tip — D2) · 0062 (the CTA fill the tip's
  ink is measured against — D7) · 0153 (nothing on the song player's root body may change at display
  rate — D8) · 0117 (the practice log's sitting gap, which is also the break that starts a new opening
  — D5) · 0214 (the review ask's readout in Settings ▸ Developer, which the tips' follows — D10)
- **Schema:** none. Two `UserDefaults` keys: the switch and the retired set.

## Context

The onboarding plan of 2026-09-22 had six slices. Its fourth was Tomisin's request: *"getting them to
understand certain gestures such as long holding the loop row to access the settings… maybe floating info
tags that provide users the info, which they have the option of skipping."* It was planned as ADR 0221,
for the song player only. That number went to phase rows, and the slice was never built.

On 2026-10-03 Tomisin narrowed the onboarding that is left to this one slice, and asked whether the tags
should reach further: the Journal, Train your ear, Fret & string, the metronome, and Practice with its
templates. *"At which point do we draw the line?"*

The app wires up eleven holds of its own (`docs/manual/gestures.md`), and many more if every list row's
menu counts. A tag on each would be a tour, which is the thing ADR 0149 §5 warns a new player against
meeting on day one. A rule was needed for which holds earn a tag, and it had to keep working as features
add holds.

## Decision

| # | Decision |
|---|---|
| **D1** | A hold gets a tip only if all three hold: **hidden** (nothing on screen draws it, and iOS hasn't taught it), **the only way in** (no visible control does the same job), and **its subject is on screen** (there is a row, a disc or a name to hold). It also needs **nothing on screen already saying it**. |
| **D2** | Measured against D1, the line falls at **the song player, and six holds there**: a loop row, the metronome (once a tap toggles the click), the BPM, a marker row, a panel's name (with two or more rows), and the song's name. Nothing anywhere else. |
| **D3** | **The first-song walkthrough comes first.** No tip shows while it is armed, or in the opening of the app that ran it. |
| **D4** | **Using the hold, or closing the tip with ✕, retires it for good.** Using it counts even if the tip never showed: a player who finds a hold unaided is never told about it. |
| **D5** | **One tip per opening of the app** — a launch, or a return after **30 minutes or more** in the background — and it stays that opening's only tip until it is retired. Shown only while the song is loaded and **paused**, with no selection, range edit or downbeat placement under way, and only when its control is **wholly on screen**. |
| **D6** | **Settings ▸ Song player ▸ Show hold tips**, on by default, with **Show the tips again**. |
| **D7** | The walkthrough's **ring** round the control, and a **tip** beside it: a line on the CTA fill with a caret and a ✕. The ring takes no touches, so the hold it asks for lands. |
| **D8** | Drawn by **one layer over the whole screen**, from positions the controls report. It is not drawn by the controls themselves. |
| **D9** | **Not TipKit.** |
| **D10** | **Off under `-uiTesting`** unless `-gestureHints` asks for them. |

### D1 — the test, and why each part is there

- **Hidden.** A list row's hold menu, swipe to delete and pinch to zoom are iOS's own grammar. Holding −/+
  to repeat is too. A tip for any of them tells a player something their phone already taught them.
- **The only way in.** If a visible control does the same job, the tip teaches a shortcut. Shortcuts are
  where a set of tips turns into a tour, because every screen has them.
- **Its subject is on screen.** This is design-brief §3.5's *reveal by relevance* applied literally. The
  loop row's tip waits until there is a loop. The panel's waits until there are two rows to select.
- **Nothing already saying it.** Some holds were found unteachable before this ADR and were given a
  caption where they live. A tip would say the same thing twice.

### D2 — where the line falls

| Where | Hold | Tip? | Why |
|---|---|---|---|
| Song player | Loop row → Edit loop | **Yes** | Hidden, the only way to a loop's name and practice settings |
| Song player | Metronome → tempo editor | **Yes**, once the click works | Before that, a tap opens the editor and the disc carries a + badge |
| Song player | BPM → carry the tempo | **Yes** | Hidden, the only way |
| Song player | Marker row → Edit marker | **Yes** | Hidden, the only way to rename, move or make a section |
| Song player | Panel name → select several | **Yes**, with two or more rows | Hidden, the only way into selection |
| Song player | Song's name → its details | **Yes** | Hidden, the only way from this screen |
| Song player | Loop controls → Song player settings | No | A shortcut: Settings has the same screen |
| Song player | Snags row → a line on a snag | No | The panel already says *Hold a snag to leave a line on it* until a line exists (0238) |
| Song player | Skip buttons → the skip length | No | An iOS button menu, and only a preference |
| Song player | Hold-drag the waveform → draw a loop | No | A shortcut for tapping Loop twice |
| Strumming, Chords & Strum | Slot → accent | No | The editor says *Long-press to accent* under the slots |
| Name the notes (Fret & string, By ear) | Note → snag | No | The strip says *Hold a note to snag it* until there is a snag |
| Routines | Insert rest → place rests | No | Edit mode reorders a rest that was added at the end |
| Routines | Swipe right on a block → Record | No | The block has its own visible Record switch |
| Journal | Row → Pin, Rename, Export, Delete | No | A list row's menu. The one thing only there, Pin, is spelled out by *Pinned only*'s empty state |
| Train your ear | — | No | Nothing hidden |
| Metronome | −/+ → repeat; tap the BPM to type | No | The first is iOS's; the slider and steppers do the second |
| The other eleven templates | — | No | Nothing hidden |

The answer to *where is the line* is therefore not a list of screens. It is D1, applied to each new hold
as it lands. A future hold either passes D1 and joins `GestureHint`, or it gets a caption where it lives,
or it is a shortcut and needs neither.

### D3 — after the walkthrough

A new player's first song visit is the walkthrough's: three beats, two hints and one ceremony (0149, 0220).
A ring for a hold beside all that is the "walkthrough plus a stack of annotations" the original plan
ruled out. The policy reads two facts. One is the walkthrough's own ledger: while it is armed, the next
song opened will run it. The other is a flag for this opening of the app (D5): it ran. While either is
true, the tips are off.

A ledger left armed by a past test run must not hold the tips back for ever. So "armed" only counts where
the walkthrough could run: under `-uiTesting` without `-walkthrough`, it never will.

### D4 — retired for good

Each of the six holds, and its VoiceOver action, calls `AppSettings.retireGestureHint`, whether a tip is
showing or not. The ✕ does the same. There is no "seen" state. A tip that was showing when the player
left the screen without using it or closing it comes back in a later opening. That is still one at a time,
and it stops as soon as either thing happens. Retiring a tip just for having been on screen would retire
tips nobody read.

The retired set is stored as strings, not cases. A name written by a later build that knows a seventh tip
survives a round trip through this one.

### D5 — one at a time, and only at rest

One per **opening of the app**, not per visit to the song player. A player who opens three songs in a
sitting meets one tip, not three. When more than one is possible, the order of `GestureHint`'s cases
decides; the loop row leads, because a loop is what the first session makes.

**An opening is a launch, or a return after 30 minutes or more in the background.** The first build
counted launches, and that was changed the same day. iOS keeps a suspended app for days, so "one per
launch" spaced the tips by however long iOS kept the process, not by the times a player opened the app,
which is what the manual and the changelog promise. Thirty minutes is `PracticeLog.sittingGap`, the
break that already starts a new sitting in the Practice log, so the app has one idea of "came back
later", not two. Only the background counts as away. `.inactive` is Control Centre or the app switcher,
which is a glance, not a break. `PocketApp` reports every change of scene phase to
`GestureHintOpening`, and the pure `GestureHintPolicy.isNewOpening` decides. A new opening clears the
latch and the walkthrough's flag, and because `GestureHintOpening` is observable, a song player left
open across the break redraws with them.

**Never while playing.** The player's hands are on the guitar. A tip arriving mid-take is a distraction
nobody is free to act on. It returns when the song is paused.

**Wholly on screen.** A row scrolled half under the transport bar is not something a player can hold.
The panels' scroll view reports its visible frame, and a row counts only while it sits inside it.

### D6 — the switch

**On by default.** ADR 0195 found on a device that a setting which starts off is found by nobody, and a
tip nobody sees teaches nothing.

It lives in **Settings ▸ Song player**, because every tip is on the song player. Holding Loop controls
reaches the same screen, from where the tips are.

**Show the tips again** brings every retired tip back. It also lets one show in this opening, rather than
waiting for the next: someone who asked to see them should see one.

### D7 — how it looks

The ring is the walkthrough's `HintRing`, unchanged. 0220 settled that the app has one pointer, so the
player learns what it means once. It is drawn in the waveform's teal, as the walkthrough's metronome hint
is. It is never hit-tested.

The tip is a line of Futura on `practiceCTA`, the fill the cream ink is measured against at ≥ 4.5 : 1 in
both appearances (0062). It is also what *Show me* already uses on this screen. A caret joins the tip to
the control. It sits above the control when there is room, because the hand that holds comes from below
and would cover a tip there, and below the control otherwise. It is kept 16 pt from both sides of the
screen. The ✕ is a 32-pt target labelled *Close this tip*. The tip is announced to VoiceOver when it
appears.

The 2026-09-22 plan called for a terracotta pill. That came before 0220 settled the pointer. Terracotta
is the Library's colour, and on the song player it would have read as another space's.

### D8 — one layer, not a tip on each control

A tip drawn as an overlay on a loop row is clipped by the scroll view the row sits in, and covered by the
row below it. The layer avoids both. `.gestureHintTarget` reports a control's bounds through an anchor
preference, only while its tip is still in play, so once every tip is retired the screen reports nothing.
`.gestureHintLayer` resolves those bounds, asks `GestureHintPolicy`, and draws over everything. The cost
is that the layer cannot see a scroll view's edges, which is what `.gestureHintViewport` is for.

The screen's own condition (D5) is handed to the layer as a closure, which the layer reads in its own
body. The song player's condition reads the 1 being placed, which changes on every frame of a drag. A
root body that read it would rebuild the whole screen at display rate, which is the trap 0153 closed.

### D9 — why not TipKit

TipKit (iOS 17) does most of this, and was weighed first.

- **Ordering several tips** — D5's one at a time, in rank order — is `TipGroup`, which is iOS 18. This
  app targets iOS 17.
- **`popoverTip` presents a popover.** A popover takes the first touch outside it to dismiss itself, so
  the hold it describes would not land on the first try. D7 needs a pointer that takes no touches.
- It would bring a second pointer vocabulary onto the one screen that already has the walkthrough's.
- Its rules live in TipKit's own datastore. `GestureHintPolicy` is a pure function, and every rule above
  has a unit test.

### D10 — under test

`-uiTesting` alone keeps the tips off, so none of them sits on the controls the suite drives or in the
figures the manual shoots. `GestureHintUITests` asks for them with `-gestureHints`, which also brings
every tip back at launch, because a simulator keeps its `UserDefaults` between runs. This mirrors
`-walkthrough`.

**On a device**, the state is invisible: which tips are put away, which one this opening has used, and
whether the walkthrough is holding them back. **Settings ▸ Developer ▸ Hold tips** (debug builds only,
like the rest of that screen) shows each, as the review ask's readout does for ADR 0214. Its **Start a
new opening** calls the same `begin()` that a half-hour away does, so stepping through the tips on a
phone takes the real path, not a test-only one. **Reset hold tips** is the `-gestureHints` reset.

## Alternatives considered

- **Tips on every feature Tomisin listed.** Refused by D1, case by case, in D2. Two of the features
  (strumming and Name the notes) looked like a yes at first, until their own captions were found.
- **A tip per screen per opening.** More tips in a sitting is what makes a tour.
- **One per launch.** The first build's rule. iOS decides when a suspended app is ended, so a player
  would have seen a new tip every few days, not each time they opened the app (D5).
- **Retire a tip once shown.** It would retire tips that flashed past during a scroll.
- **Extending the Loop controls popover instead.** That is pull: help someone has to go looking for.
  It stays, with nine rows. The tips are push, and the two do different jobs.

## Consequences

- **Code:** `GestureHint` and `GestureHintPolicy` (pure, `Core/Help`); `AppSettings+GestureHints`;
  `GestureHintLayer.swift` (`GestureHintOpening`, the preference, the layer, `GestureHintPlacement`, the
  tip); a `.gestureHintTarget` on each of the six controls and a `retireGestureHint` in each hold;
  `WaveformPracticeModel.gestureHintsCanShow` and `holdTitle()`; the opening's flag set where the
  walkthrough is taken; `PocketApp` reports the scene phase; a **Hold tips** section in Settings ▸
  Developer (debug only).
- **Tests:** `GestureHintTests` (catalogue, policy, storage, placement, the launch seam, what counts as
  a new opening and what one clears);
  `GestureHintUITests` (the loop row's tip shows; ✕ and the hold each put it away, and nothing replaces
  it that opening; the switch turns them off from Settings and back on from the player's sheet). Run on
  iOS 26.5 and iOS 18.5, light and dark. That a song player already on screen redraws when a new opening
  begins was shown once, by a hosted-window test that failed when `shown` was made unobserved, and was
  not kept.
- **Manual:** `gestures.md` gains *Tips for the holds*; `reference/settings.md` quotes the new ⓘ.
- **Reshoot owed:** Settings ▸ Song player gains a section. No figure shows a tip, and none needs to:
  the shoot runs with them off (D10).
- **Not built from the 2026-09-22 plan:** the dream becoming a goal, the Toolkit's video, and the wider
  rule for showing features when they become relevant. They wait, with nothing decided about them here.
