# ADR 0162 — a setting you can find

- **Status:** **Accepted — built 2026-08-12** (branch `pocket-256-a-setting-you-can-find`)
- **Date:** 2026-08-12
- **Amends:** ADR 0050 (Settings V1). The thin `Form` shell 0050 built is not replaced — it is
  *split along the seam 0050 anticipated*. Its scope discipline (D9) is reaffirmed unchanged.
- **Relates to:** ADR 0114 (metronome timbres — D5/D6 restyle the picker) · ADR 0147 (analytics
  inform-and-object — D7 checks the hub against the objection mechanism the exception is conditional
  on) · ADR 0145 (Help & FAQs, the second door) · ADR 0096 (the Toolkit hub, the pattern this copies)

## Context

Settings is thirteen top-level sections in one flat scroll:

> You · Your sound · Appearance · Feel · Practice · Tempo changes · Metronome sound · Note names ·
> Privacy · Routines · Transport · Motion · Red Moon Pro · *(debug)* · About

It grew one section per ADR, in the order the ADRs landed, and it now has the four failure modes that
implies.

**Related settings are separated; unrelated ones are adjacent.** *Appearance* is third and *Motion* —
a single animation toggle — is twelfth, with nine sections between two halves of the same idea.
*Privacy* sits ninth, splitting the practice-behaviour run (Practice · Tempo changes · Metronome ·
Note names … Routines) down the middle for no reason other than the date ADR 0120 landed.

**Five sections carry one row each.** *Feel*, *Motion*, *Note names*, *Tempo changes* and *Privacy*
each spend a header and a footer on a single control. Most of the scroll's length is chrome.

**Two vocabularies.** *You / Your sound / Feel / Motion* are evocative; *Practice / Routines /
Transport / Privacy / About* are functional. And **Transport** is engineer's jargon that escaped into
the UI — the players this ships to call it the song player, or nothing at all.

**The paying surface is thirteenth.** The trial countdown and the upgrade path sit below the
exercise-animation toggle.

### The code already said so

`SettingsView.swift` is 344 lines against SwiftLint's 400-line ceiling, and three separate files —
`PrivacySection`, `AboutSection`, `NoteSpellingSection` — carry doc comments instructing the next
author *not to add a row to `SettingsView`, because it is at the cap*. Sections have been extracted
into their own files four times now purely to buy back lines. That is not a formatting problem; it is
a flat structure telling us, in the only way it can, that it is out of room.

### 0050 banked the affordance and never spent it

ADR 0050 chose a **push, not a sheet**, in as many words: *"so it can grow sub-screens."* It grew the
sections and never grew the screens. This ADR spends what 0050 saved.

## Decision

### D1 — Settings becomes a hub of destinations, not a scroll of sections

`SettingsView` becomes a short list of `NavigationLink` rows. Each row pushes a screen that owns one
coherent group of settings. This is the shape `ToolkitView` (ADR 0096) already uses and the shape the
platform's own Settings uses, so it costs the player no new idea.

The hub stays a `Form`/`List`, **not** Toolkit's card `ScrollView`: a settings hub is a list of
destinations, and the grouped-list idiom is what carries the section headers, footers and
`readableWidth()` the sub-screens still need.

### D2 — eight destinations, and the rule that placed each setting

```
  You                Tomisin · Guitar   >
  Red Moon Pro       Trial · 5 days     >

  PREFERENCES
  Appearance         System             >
  Sound & feel       Wood block         >
  Practice           Count-in on        >
  Routines           Auto-start on      >
  Song player                           >

  Privacy            Sharing usage      >
  Help & About                          >
```

| Destination | Carries | Was |
|---|---|---|
| **You** | Artist name; instrument, experience, genres, dream, time most days | *You* + *Your sound* |
| **Red Moon Pro** | Trial countdown, Manage / Upgrade, Restore | *Red Moon Pro* (13th) |
| **Appearance** | Light/Dark/System, Animate exercises, Note names | *Appearance* + *Motion* + *Note names* |
| **Sound & feel** | Haptics, metronome timbre picker | *Feel* + *Metronome sound* |
| **Practice** | Count-in + length, Keep screen awake, Strumming click, Tempo-change warning | *Practice* + *Tempo changes* |
| **Routines** | Auto-start, Advance automatically, Rest length, Loop song blocks | *Routines* |
| **Song player** | Loop control on left, Minimap, Marker labels, Zoom follows playhead | *Transport* |
| **Privacy** | Share anonymous usage | *Privacy* |
| **Help & About** | Version, Help & FAQs, Contact Support, Privacy Policy, Terms, wordmark | *About* |

**The grouping rule is "what am I trying to change?", not "which subsystem implements it".** That is
why *Note names* sits under Appearance — accidentals are how a note is *written*, and a player
hunting for them is thinking about what they see, not about `NoteSpelling`. It is why the haptics
toggle sits with the metronome timbre: both are what the app does to your ears and hands. And it is
why *Transport* is renamed **Song player**, which is what it is.

**Two rows are lifted out of PREFERENCES on purpose.** *You* and *Red Moon Pro* are state — who you
are and what you have — rather than preferences, and putting them above the fold fixes the thirteenth
-place problem without a promotional flourish.

### D3 — a hub row states its value where one setting dominates

Each row's trailing text is the answer to the question that sends a player there: `Appearance ·
System`, `Sound & feel · Wood block`, `Privacy · Sharing usage`. That is what makes a hub readable
rather than a game of Twenty Questions — most visits end without opening anything.

**Where no single setting dominates, the row shows nothing.** *Song player* holds four unranked
toggles; picking one to display would be arbitrary and would misreport the screen. An honest blank is
better than a confident summary of a quarter of the truth.

### D4 — one `settingsScreen(title:)` modifier

Nine screens must not each hand-roll `.scrollContentBackground(.hidden)` + `.readableWidth()` +
`.background(PocketColor.background.ignoresSafeArea())` + title + `.inline` display mode. One view
modifier carries the chrome; a sub-screen is then a `Form` of the sections it owns. This is what keeps
the split from trading one 344-line file for nine 60-line files that drift apart.

The extracted `SettingsInfo` copy moves to its own file. The existing `FieldInfoLabel` ⓘ pattern is
kept everywhere it is used today — it is working, and it is the reason the sub-screens need very few
footers.

### D5 — in the metronome picker, one tap chooses *and* plays

Today a timbre row has two affordances at opposite ends: a play triangle on the far left auditions
it, a checkmark on the far right says it is selected. Nothing on screen says which of the two a tap
in the middle will do, and the answer — it selects, silently — is the less useful one.

**Tapping a row selects the timbre and immediately plays it.** One gesture, one obvious meaning,
and you hear what you just chose. This is Apple's own alarm-sound picker, and it is safe here for the
reason it is safe there: choosing is free, instantly reversible, and affects nothing until the
metronome next starts (`ClickVoice.loadTimbre`, unchanged).

*Alternative considered and rejected:* keep the two affordances and only restyle them (D6). It
preserves audition-without-committing, which ADR 0114 valued — but that value was always thin, since
committing costs nothing and undoes with one tap, and it is what buys the ambiguity.

### D6 — the picker uses the metronome accent, not the system tint

The play triangles currently render **system blue** while the selection checkmark renders
`PocketColor.metronome` plum — two accents in one row, one of them the platform default with no
relationship to this app. `.buttonStyle(.borderless)` is taking the tint.

The row is restyled on the tokens that already exist for exactly this: a circular indicator on
`metronomeCircleWash`, and the checkmark in `PocketColor.metronome`.

**Amended during the build — the selected row is not washed.** This originally specified
`metronomeCardWash` on the selected row, so selection would read from the row as a whole rather than
from one small right-aligned glyph. Shipping it and looking at it killed it, for two reasons worth
keeping:

1. **`.listRowBackground` full-bleeds.** A washed row spans edge-to-edge with square corners, visibly
   cutting the inset-grouped card in half. The wash and the card are two different shapes and the
   card loses.
2. **A plum checkmark on a plum wash is invisible.** The selected row — the one row that must show a
   tick — was the only row not showing one. The two halves of D6 were fighting each other.

Selection is instead carried by the **title**: accented and semibold, beside a checkmark that now has
a background to be legible against. Same intent — selection readable from the row, not from a glyph —
without a second shape competing with the card.

The `MetronomeSoundPreviewPlayer` and its 90 BPM audition are unchanged, as is `.onDisappear { stop }`
— an audition must not outlive the screen, and the screen it must not outlive is now *Sound & feel*.

### D7 — Privacy moves one push deeper, and that is still an objection mechanism

This needs saying out loud, because ADR 0147's compliance argument rests on it. Under `.notify`, the
analytics toggle **is** the "simple, free means of objecting" that the UK DUAA 2025 Sch A1 para 5
exception is conditional on; under `.ask` it is the withdrawal control ePrivacy requires.

A control reached by *Settings ▸ Privacy* remains simple and free: it is two taps from anywhere in
the app, it is labelled with the word a player would look for, and the hub row states its current
value (D3) so the state is legible without opening it. Every mainstream iOS app places its privacy
controls exactly here. **Nothing about the mechanism, the key, or the per-event re-read changes** —
`PrivacySection` moves file, not behaviour, and its region-branching footer moves with it intact.

A useful side effect: `ArtistIntakeView` already promises *"Turn it off any time in Settings ▸
Privacy."* That sentence has been aspirational since it was written. It becomes literally true.

### D8 — DEBUG scaffolding goes behind a Developer destination

The three `#if DEBUG` sections (entitlement override, `DebugAudioSection`, the prompt/intake resets)
become one `Developer` row, itself `#if DEBUG`. They are a meaningful share of the current scroll and
of `SettingsView`'s line count, and none of them belong in a shipping player's field of view even in a
TestFlight build.

### D9 — no model, no key, no migration — and 0050's scope discipline stands

This is **pure information architecture**. Every setting keeps its `AppSettings.Key`, its default, and
its readers; `AppSettingsTests` is untouched; there is no schema change, no `@Model` edit and no
migration. A player updating sees their settings exactly as they left them, in different places.

Two things this deliberately does **not** do:

- **It does not relitigate what belongs in Settings.** Minimap, marker labels and zoom-follows-playhead
  are arguably contextual waveform controls that 0050 D9 would have kept off this screen. They may
  well be, but that is a question about *where a setting lives in the app*, and this ADR is about
  *where it lives within Settings*. They go under Song player, and the question stays open.
- **It does not add a setting.** Not one row is new. Reorganising and extending at the same time is
  how you lose the ability to say what broke.

## Consequences

- **Settings becomes scannable.** Nine rows with their values on them, in place of thirteen sections
  and roughly four screens of scrolling. The common visit — *what is my count-in set to* — ends
  without scrolling at all.
- **The 400-line ceiling stops being a design constraint.** Three files can drop the "add no row here"
  warnings, and the next preference goes where it belongs instead of where there is room. This is the
  single largest maintenance win and the reason to do it before the beta rather than after.
- **Everything is one tap deeper.** That is the trade, and it is the correct one at thirteen sections
  — but it is a real cost for the two or three settings a player toggles often. The D3 trailing values
  are what pays it back, and if a specific setting proves to be toggled constantly, the answer is a
  contextual control next to the feature (0050 D9), not a flat settings screen.
- **The copy pass is part of the work, not a follow-up.** Strings that say "in Settings" can now name
  the destination — `AnalyticsConsentSheet`'s "You can change this any time in Settings" becomes
  "…in Settings ▸ Privacy". The Contact Support path in the FAQ answer (ADR 0145) needs the same
  check, since it names a route that is about to gain a level.
- **No UI test churn.** `PocketUITests` contains no reference to Settings today — verified, not
  assumed. A single new UI test asserting the hub's rows exist and push is cheap insurance and the
  right time to add it is now, while the screen is being rewritten.
- **The metronome picker loses audition-without-commitment** (D5). If that turns out to matter on the
  device pass, D6's restyle is the fallback and it is a small change away.
- **The hub is a place to put things.** The beta will produce settings — it always does. There is now
  an obvious answer to "where does this go" that is not "the bottom".
- **Two defects were caught only by looking at it**, both invisible to the build and the test suite:
  the row wash above, and the `guitars` symbol on the Practice row, which collapses into an illegible
  tangle of strings at row size (now `timer`). Neither is the kind of thing a green test run has any
  opinion about.
