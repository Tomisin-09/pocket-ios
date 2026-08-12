# ADR 0157 — the walk moves by default

- **Status:** Accepted — built, and confirmed on device 2026-08-12. The high-tempo pass that
  *Consequences* made a precondition of acceptance was run on an iPhone 16 Pro and the walk was
  judged to read correctly; the rate-cap alternative stays unbuilt, as intended.
- **Date:** 2026-08-11
- **Reverses:** the off-by-default half of the `exerciseAnimates` preference. The preference itself, its Settings row, and every reader stay exactly as they are.
- **Relates to:** ADR 0050 (Settings V1 — where the toggle was introduced) · ADR 0065 (Watch supersedes the per-editor Animate toggle; Settings is the one place to turn continuous animation on) · ADR 0131 §3a and ADR 0132 (both of which *cite* the off default as a reason — see *Consequences*)

## Context

A device-testing note, in full: "animate should be default on."

`exerciseAnimates` drives the moving highlight that walks an exercise in time — the notes on the
fretboard, the strokes on the strum lane. It ships **off**. A player who installs Red Moon, builds a
scale drill and runs it sees a static board, and has no particular reason to suspect that the app can
show them the shape moving. The feature is one toggle away and effectively undiscovered.

The off default was chosen as a photosensitivity precaution. That rationale is worth locating
precisely, because it turns out to be less firmly established than its citations imply:

- Its actual home is a **code doc comment**, `AppSettings.swift:158-161` — *"Default **off** as a
  photosensitivity precaution; the views also force it off under the system Reduce Motion setting."*
- ADR 0065 refers to it in passing, as "the persistent, off-by-default-for-photosensitivity
  preference", while deciding something else (removing the duplicate per-editor toggles).
- ADR 0131 attributes it to **ADR 0050**, which does not mention animation at all. ADR 0050 is the
  thin preferences shell that gave the toggle a home; it never decided the default.

So this is the first record in `docs/decisions/` that actually decides the value. It is being written
because reversing a safety-shaped default on a verbal note, with no written trace, is how a
precaution gets lost — and because three other decisions have since been built on top of the old
value and need correcting whichever way this goes.

### Is the precaution real?

Two facts bear on it, and both are already true in the code:

**Reduce Motion already wins, everywhere.** All five rendering readers pair the preference with
`@Environment(\.accessibilityReduceMotion)` and force the walk off when the system flag is set —
`FretboardView`, `FretboardDrillPreview`, `FretboardPlayOnceButton`, `StrummingLaneView`, and the
strum half of `StrumChordsView`. A player with a genuine motion or photosensitivity need who has told
iOS so is unaffected by this ADR. The system setting, not the app default, is the real protection,
and it is the one that generalises past this app.

**The effect is a moving highlight, not a flash.** The WCAG flash thresholds concern luminance
changes over a large area of the visual field — more than roughly a quarter of a 10° field. A small
highlight travelling along a fretboard or a strum lane is a *translation*, not a full-field
luminance transition, so the flash threshold is not the governing test. Colour and brightness on the
board do not change; where the highlight *is* changes.

Neither fact makes the precaution silly. It makes it a conservative default rather than a
requirement, and conservative defaults are exactly the kind that quietly cost a feature its audience.

## Decision

### 1. `exerciseAnimates` defaults to **on**

The walking highlight is what an exercise *is* on the fretboard and strum lane — the shape in time,
rather than the shape. Shipping it static shows new players the less useful half of the feature and
tells them nothing about the other half.

System Reduce Motion continues to force it off at every reader. The Settings toggle stays exactly
where it is, so the preference is one tap away for anyone who wants the board still.

### 2. The default lives in seven places, and all seven change together

This is the whole implementation risk, so it is recorded as part of the decision rather than left to
the build. `@AppStorage(key) private var animates = false` — that trailing `= false` is the value
SwiftUI uses when the key is unset, **not** a mirror of `AppSettings.exerciseAnimates`. Changing the
`AppSettings` accessor alone would flip nothing that renders.

| Site | Role |
|---|---|
| `Pocket/App/AppSettings.swift:161` | the non-View accessor, plus its doc comment |
| `Pocket/Features/Practice/FretboardView.swift:34` | the live run board |
| `Pocket/Features/Practice/FretboardDrillPreview.swift:27` | the editor preview |
| `Pocket/Features/Practice/FretboardPlayOnceButton.swift:15` | Watch |
| `Pocket/Features/Practice/StrummingLaneView.swift:99` | the strum lane |
| `Pocket/Features/Practice/StrumChordsView.swift:34` | the strum half of Strum & Chords |
| `Pocket/Features/Settings/SettingsView.swift:63` | the toggle's own binding |

A test asserting `AppSettings.exerciseAnimates == true` on a clean defaults store would catch a
regression in the first row and none of the other six. The check that matters is visual, on device.

**Built as one site, not seven.** Rather than repeat the flipped literal and rely on care, the build
added `AppSettings.exerciseAnimatesDefault` and pointed all seven at it — matching the house pattern
already used for `ClickTimbre.default` and `AppSettings.tunerReferenceDefault`. The drift this section
warns about is now unrepresentable, and `AppSettingsTests` pins the constant, so the unit test covers
the views after all. The device check below is still the one that matters, for a different reason: it
tests whether the walk *reads* well, not whether the value propagated.

### 3. An existing player's explicit choice is not overridden

`@AppStorage` writes the key on first toggle, so anyone who has *deliberately* turned the walk off
has a stored `false` and keeps it. Only players who never touched the row — for whom the key is
absent — move. This is the correct behaviour and it comes for free; it is written down so nobody
"fixes" it by seeding the key on launch.

## Consequences

- **Three other decisions cite the old default as a reason, and all three must be corrected.** This
  is the substantive consequence, and it is not cosmetic: each one *rejected* an animated design
  partly because animation would be off by default for the players the design was meant to serve.
  That premise is now false.

  | Where | The claim |
  |---|---|
  | ADR 0131 §3a, and its "pulsing tint" alternative | a pulsing carrier "would be disabled by default for exactly the players it is meant to serve" |
  | ADR 0132, "It must not pulse" | same reasoning, for the click-withdrawal marker |
  | `TempoWarningIndicators.swift:46` | restates ADR 0131 §3a |
  | `ClickWithdrawal.swift:86` | restates ADR 0132 |

  All four were amended in the build; none changed its decision.

- **Watch now hides by default, and that is correct.** `FretboardPlayOnceButton.shouldShow` hides the
  one-shot exactly when the board already walks (ADR 0077), so flipping the default hides Watch on a
  fresh install. The rule is unchanged and needed no edit — but this ADR's *Alternatives* section
  argues Watch "has not made the continuous walk discoverable", and the flip resolves that by making
  the continuous walk the thing you meet first. Watch remains for the two cases it was built for: a
  player who turned the walk off, and a Reduce Motion user. Pinned by a new test.

  **All four decisions survive**, on the reasons that remain: Reduce Motion alone still disables an
  animated carrier for the players in question, and — the stronger argument in both cases, which
  never depended on the default — *a pulsing marker would itself be a visual metronome*, which is
  precisely what the click-withdrawal and tempo-warning sections exist to avoid. Static stays
  correct. Only the stated reasoning needs amending, and it needs amending in all four places or the
  next reader will build on a premise that no longer holds.

- **`SettingsInfo.animateExercises` reads correctly either way** — *"A moving highlight walks the
  exercise in time … Always off when your device has Reduce Motion on."* It never stated the default,
  which was a small omission when the default was off and is a smaller one now. Worth rereading in
  the new light, but no change is required.

- **The check that was owed — run, and passed (2026-08-12).** A device run at a **high command
  tempo** on a fretboard drill and on the strum lane, confirming the highlight reads as travel rather
  than flicker when the beat is fast, and that Reduce Motion still forces it off. It gated
  acceptance because the §2 argument about flash thresholds is a reasoned position, not an
  observation, and this is the one place where being wrong would matter. It is now an observation.

- **No migration, no schema change, no CI implication.** A `UserDefaults` default; docs-only until
  the build.

## Alternatives considered

**Leave it off and improve discovery instead** — surface Watch (`FretboardPlayOnceButton`) more
prominently, or mention the toggle in onboarding. Preserves the precaution exactly and costs nothing
in safety. Rejected because it answers a different question: Watch already exists precisely so a
player can see the shape move *once* without turning the preference on (ADR 0065), and it has not
made the continuous walk discoverable. A default is the only thing that reliably shows a feature to
someone who does not know to look for it.

**Default on for the strum lane, off for the fretboard.** The fretboard is the denser surface and
the plausible worst case. Rejected: two defaults for one preference is a preference the player cannot
reason about, and the Settings row would have to describe a split it cannot express in one line.

**Cap the walk's rate rather than its default** — animate, but never faster than some ceiling, so a
200 BPM sixteenth-note drill does not strobe. Genuinely attractive, and the honest response if the
device check in *Consequences* goes badly. Not adopted pre-emptively: it introduces a highlight that
stops tracking the beat it is supposed to be teaching, which is a worse failure than the one it
prevents, and it should only be paid for against an observed problem.

**Retire the preference entirely and rely on Reduce Motion alone.** The logical endpoint of the
§*Is the precaution real?* argument, and it would delete a Settings row. Rejected: some players
simply find the moving highlight distracting without having Reduce Motion on system-wide, and taking
away the opt-out in the same breath as flipping the default would leave them nothing to do about it.
