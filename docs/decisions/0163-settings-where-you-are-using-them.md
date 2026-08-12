# ADR 0163 — settings where you're using them

- **Status:** **Accepted — built 2026-08-12** (branch `pocket-257-settings-where-you-use-them`)
- **Date:** 2026-08-12
- **Answers:** ADR 0162 D9, the question that ADR left open — whether the four song-player toggles
  belong on the waveform screen rather than in Settings. Answered **both**, not *moved*.
- **Relates to:** ADR 0162 (the Settings hub these four live in) · ADR 0124 (the transport bar the
  hold lands on, and the `Button`-plus-hold trap) · ADR 0041 (the Loop control's tap cycle) ·
  ADR 0050 (Settings V1 scope discipline) · ADR 0051 (`Song.showsGridlines`, the per-song precedent
  deliberately left out) · ADR 0090 (present model sheets by stable `uid` — why it doesn't apply
  here) · ADR 0098 (`zoomFollowsPlayhead`) · ADR 0145 (Help & FAQs, the second discovery route)

## Context

ADR 0162 split thirteen flat Settings sections into nine destinations, one of them **Song player**:
four toggles that describe the waveform screen's persistent chrome.

| Row | Key | Default |
|---|---|---|
| Loop control on left | `transportLoopOnLeft` | off ⇒ Marker-left / Loop-right |
| Show minimap | `waveformMinimapVisible` | on |
| Show marker labels | `waveformMarkerLabels` | on |
| Zoom follows playhead | `zoomFollowsPlayhead` | off ⇒ the focal point holds still |

0162 fixed findability *inside* Settings and explicitly declined to touch a second problem, recorded
as its D9 and repeated in `SongPlayerSettingsView`'s own doc comment: **all four change the screen you
are looking at when you want to change them.** Deciding you'd rather see the minimap means leaving the
player, crossing the app, flipping a switch you can no longer see the effect of, and coming back.

The app had already half-solved this once, inconsistently. `zoomFollowsPlayhead` grew a **"Follow"
chip** on the waveform screen (`WaveformSections.swift`) whose comment argues it's "a per-moment
choice … rather than a set-once preference" — while the same key stayed in Settings. So one of the
four was reachable in context and three weren't, for no reason a player could infer.

## Decision

**D1 — Hold *Loop controls* on the status line to open the song-player settings.** No new chrome, no
new row, no new pixels. The transport bar is already at its layout limits in landscape (ADR 0042), and
ADR 0126's rule that nothing on a nav bar may vary in width exists because this app has run out of room
in exactly this way before. A hold is the one gesture that adds a route without adding a control.

**The host is the *Loop controls* affordance, not the transport's Loop button** — the first cut of this
put it on the transport and it was the wrong home twice over. The status line is where the screen
already explains itself (tap ⓘ for the gesture cheatsheet), and it already carries **Follow** and
**Grid** — Follow being one of the very four settings the sheet holds. "The row where I adjust this
screen" is a category a player can already read off the UI; "the loop button, which also has settings
behind it" is not. The transport's Loop button, by contrast, is a three-state cycle
(`.idle → .armed → .set`, ADR 0041) whose whole job is unrelated.

**D2 — The Settings ▸ Song player row stays.** This is the load-bearing half of the decision. A hold
has no affordance; as the *only* route it would make four settings unfindable, which is precisely the
failure ADR 0162 was written three commits earlier to fix. The hold is a shortcut for someone already
on the player; the Settings row is the answer for someone who half-remembers there was a minimap
switch. Rejected alternative: remove the row and call the player self-documenting. It isn't.

**D3 — Both doors present the *same view*, not two copies of it.** `SongPlayerSettingsSheet` wraps
`SongPlayerSettingsView` verbatim in a `NavigationStack` with a Done item and `[.medium, .large]`
detents — the `MeterPickerSheet` shape. Duplicating four labels and four ⓘ strings would guarantee
they drift; sharing the view makes agreement structural rather than a thing to remember.

**D4 — The settings stay global, and nothing per-song joins them.** All four are `@AppStorage`
already, on the stated reasoning that which side you want the Loop button on is a standing habit, not
a property of a song. That is reaffirmed, and it is what makes one sheet correct from any song.
`Song.showsGridlines` (ADR 0051) is genuinely per-song and stays a contextual chip on the waveform —
putting a "Grid" row among four sticky preferences would read as sticky and quietly lie about scope.

**D5 — Idle-only falls out of the layout, with nothing to enforce.** `ModeDescriptionLine` is one of
three mutually exclusive status lines: the downbeat bar replaces it while placing the 1, the A/B strip
replaces it while a span is live. So the host simply **is not on screen** during either of the states a
stray hold could disturb, and no `isPunchActive` guard — or any other condition — is needed.

This is the strongest argument for the host chosen in D1, and it was found the hard way. Putting the
hold on the transport's Loop button required exactly such a guard, and the obvious version of it was
wrong: `loopActive` is `loopColor != nil`, which tracks a **saved** loop, so an A/B span in flight
leaves the big idle button on screen, lit, with its next tap due to set B. A correct implementation
there needed an explicit `isPunchActive` withdrawal; here the question doesn't arise.

**D6 — The hold is gestures on a bare shape, never a `Button` with a long press attached.** The
*Loop controls* affordance stops being a `Button` and becomes the `Label` plus `.contentShape` /
`.onTapGesture` / `.onLongPressGesture(minimumDuration: 0.4)`. This is not a style preference: ADR 0124
recorded that pairing as a live defect — **both** actions fire on a hold — and here that means the
cheatsheet popover opening *behind* the settings sheet. `MetronomeControl` is the working reference and
is copied, including the medium haptic that confirms the hold landed. The tap keeps its popover, so the
ⓘ still means what it always meant.

**D7 — VoiceOver gets the action explicitly.** VoiceOver cannot long-press, so the control carries
`.accessibilityAction(named: "Player settings")` and a hint naming the hold, per `MetronomeControl`.

**D8 — The four defaults become named constants.** Each default previously sat as an inline literal at
**three** sites SwiftUI does not reconcile: the `AppSettings` accessor, the `@AppStorage` in
`SongPlayerSettingsView`, and the `@AppStorage` in whichever waveform view reads it — the last being
what SwiftUI actually uses for an unset key. Tolerable while the toggles had one home; not once two
surfaces claim to show the same switch, because a drifted literal would render two different "off"s
for one key. Follows `exerciseAnimatesDefault` (ADR 0157 §2) and now `AppSettingsTests` pins all four.

**D9 — A plain `Bool` drives the sheet.** ADR 0090's stable-`uid` rule governs sheets presented from a
`@Model`; this one presents global `UserDefaults`, so there is no identity to be promoted underneath
it. `WaveformPracticeModel.showingPlayerSettings` matches `showingSongDetails`.

## Consequences

- The waveform screen now declares **eight** presentations. The `PlayheadWatcher` constraint tightens
  accordingly: `WaveformPracticeView.body` must not read the playhead, or all eight re-evaluate at
  120 Hz. The comment stating the count was updated with it.
- **Discovery rests on two routes:** the Settings row and one Help & FAQs entry (ADR 0145). There is
  no on-screen hint. Accepted — the hold is additive, and someone who never finds it loses nothing.
- The app's hold vocabulary grows to nine sites. Holding *something* on the waveform screen now does
  something in five places (title, loop row, marker row, panel header, *Loop controls*). That is close
  to the ceiling for a gesture with no affordance; the next hold proposed here should be argued
  against a visible control instead.
- **`zoomFollowsPlayhead` is now reachable three ways** — the Follow chip, the sheet, the Settings
  row. All one key, so they cannot disagree, but the chip's justification is weaker now that the
  sheet is a hold away. Left in place deliberately: removing a live control is a separate decision
  with its own habit cost, and no evidence yet says which one players reach for.
- **No UI test covers the hold.** `PocketUITests` has no waveform test and no song-open helper, and a
  fresh install ships with no song (ADR 0112), so the screen is unreachable from a cold launch. The
  `Button`-plus-hold double-fire in D6 is therefore a **device check**, not a CI check — a green build
  proves nothing about it.
- **Two surfaces now hang off one target** — tap gives the cheatsheet popover, hold gives the sheet.
  That is the `MetronomeControl` bargain and it is accepted, but it does mean the ⓘ glyph advertises
  only half of what the target does.

## Alternatives rejected

**A context menu instead of a sheet.** `Toggle`s inside `.contextMenu` work, and the transport's skip
buttons already use that pattern, so it would have been the smaller change. Rejected because a menu
drops the ⓘ explanations — and for `zoomFollowsPlayhead` in particular ("what does the pinch hold
still?") the explanation is the half that makes the setting choosable at all. Same reasoning as
`MeterPickerSheet`'s: a menu drops the context that tells you which option you want.

**The transport's Loop button as the host.** Built first, then moved — see D1 and D5. It needed a
guard that the layout gives the status line for free, and it filed "settings" under a control whose job
is marking loops.

**Move the four onto the waveform screen as chips and delete the Settings screen.** The full reading
of ADR 0162 D9. Rejected per D2 — and four more chips is the row-growth ADR 0125 already had to
manage.

**Make them per-song.** Rejected per D4; it also multiplies the sheet's meaning by however many songs
are in the library, for settings whose whole character is that they stop being decisions once set.
