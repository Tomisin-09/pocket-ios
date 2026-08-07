# ADR 0145 — help is something you look up, not something we walk you through

- **Status:** Accepted
- **Date:** 2026-08-06 (`pocket-239-help-and-faqs`)
- **Depends on:** ADR 0144 (the free/Pro answers are only writable once the tier line is settled) and
  ADR 0147 (the "Your data" answers describe analytics as 0147 leaves it, not as 0120 left it)
- **Extends:** ADR 0096 (the Toolkit hub this becomes the fourth tenant of)
- **Constrained by:** ADR 0070 (help never grades the player) and ADR 0001 (why streaming audio can't
  be a source)

## Context

`docs/backlog.md` Note 13 has carried an in-app FAQ since the onboarding triage, and puts it *ahead*
of coach-marks as the cheapest high-value start. Two things make now the moment.

The first is that **the app has no support contact anywhere in it.** Settings ▸ About carried a
Privacy Policy link and a Terms of Use link and nothing else. `support@decooperations.co.uk` existed
only on `docs/site/support.html` — the page Apple requires as the Support URL, which a player reaches
through the App Store listing rather than through the app. A player who hits something broken while
offline, or who simply doesn't think to leave the app, had no route to us at all.

The second is that ADR 0144 just changed what the honest answer to *"what's free and what's Pro?"*
is, and ADR 0147 just changed the honest answer to *"is analytics on?"*. Help written a week earlier
would already have been wrong in two places. Writing it now, against both, is the cheap moment.

The pattern is already proven in this repo: the **Glossary** (ADR 0096 Slice 1) is a static,
searchable, pure value-type catalog rendered by a thin Toolkit screen. Help is the same animal.

## Decision

| # | Decision |
|---|---|
| **D1** | Help is a **Toolkit tenant** — one `FAQView`, pushed via `NavigationLink`, in the Glossary/Tuner idiom. **Settings ▸ About links to the same screen** rather than owning a second one; both push onto the Home stack. Not a sheet, not a modal tour. |
| **D2** | Content is a **compiled Swift catalog** (`FAQEntry.all`), pure, `Foundation`-only and unit-tested, cloning `GlossaryTerm`. |
| **D3** | Sections group by area and stay visible; **each question expands its answer in place**. A non-empty search force-expands every match. |
| **D4** | Answers describe *what the app does*. They never coach, grade or score the player (ADR 0070), and every word is ours. |
| **D5** | Where explanatory copy already exists in the app, the FAQ **quotes it** rather than restating it, so the two surfaces cannot drift. |
| **D6** | **No price and no trial length may be hardcoded in help copy.** Pricing answers point at the paywall and Settings ▸ Red Moon Pro. |
| **D7** | The support address appears **both** as a `mailto:` row in Settings **and** as plain selectable text inside an answer. The second is required, not a nicety. |

### D1 — one screen, two doors

`FAQView` is a fourth `ToolkitSectionRow` next to My chords, Tuner and Glossary, and the same view is
pushed from Settings ▸ About. Settings is *pushed* onto the Home stack (not presented as a sheet), so
a plain `NavigationLink` works from both places with no extra plumbing, and backing out of help
returns you to wherever you asked for it.

Putting help in the Toolkit rather than in Settings is the load-bearing half. The Toolkit is **free
forever** (ADR 0144 D2) and contains no entitlement gates at all, so help is readable by someone who
has not subscribed, whose trial has lapsed, or who is deciding. Help behind a paywall is help that
arrives after the question.

### D3 — expanding rows, and why searching opens them

A glossary definition is one line and can always be visible. An FAQ answer is a paragraph, and
sixteen of them stacked open is a wall rather than a list you can scan — so questions collapse and
open on tap, borrowing the interaction grammar of `CollapsibleLibrarySection` (light haptic, 0.2s
ease, rotating chevron) without reusing the component itself. That component folds whole *sections*
and carries a `LibrarySectionExpansion` persistence payload; help should open closed every time.

Search matches inside answers, not just questions — which is the whole point, since the words a
player searches for ("Spotify", "iCloud", "sync") often appear only in a body. That makes
force-expanding matches while searching mandatory rather than a flourish: returning a list of closed
questions to someone who searched a word that isn't in any of them is a dead end that looks like a
bug.

### D5 — quoting, not restating

The mastery-vs-command-tempo entry is mandated by `docs/backlog.md` and is the clearest case: those
two fields already have explanatory copy in `PracticeFieldInfo`, shown in the ⓘ popover on every
screen that has the fields. The FAQ interpolates those strings rather than paraphrasing them. Both
are plain `String`s in the same module, so a `Foundation`-only catalog can quote them and stay pure,
and `FAQEntryTests` asserts both substrings survive. Editing the copy in `FieldInfoLabel.swift` is
fine and propagates; paraphrasing it in the FAQ is what the test forbids.

The same instinct governs the broken-audio answer: `AudioUnavailableNotice` and `LoopRunView` already
say, honestly, that the file may have moved and to re-import it. The FAQ matches their wording and
answers it *before* you are staring at a dead transport — it does not invent a second explanation for
a case the app already handles well.

### D6 — no numbers

ADR 0144 removed a whole bug class by deriving the trial length from
`product.subscription?.introductoryOffer?.period` instead of hardcoding "14-day" in the paywall.
Help copy is the obvious place to reintroduce it, and a stale number in an FAQ is worse than one in
a paywall — the paywall is at least read next to the real offer. So the pricing answers name neither
a price nor a period, and a test asserts no answer matches a currency symbol or an `N-day` pattern.

### D7 — the `mailto:` that does nothing

Settings ▸ About gains a **Contact Support** row that opens a `mailto:` with the app version already
in the subject line — free triage signal for one `URLComponents`.

⚠ **A `mailto:` silently does nothing on a device with no Mail account configured.** No error, no
sheet, no feedback. A player in exactly that state is a plausible fraction of anyone trying to report
a bug, and for them the row is a dead tap. So the address is *also* plain, selectable text inside the
"How do I get help or report a bug?" answer, which is readable and copyable with no mail client at
all. `FAQEntryTests` pins that it stays there.

## Consequences

- The Toolkit hub gains a fourth tenant and stops being describable as "the two zero-dependency
  Slice-1 sections". Its doc comment is updated to say so.
- `SettingsView` was **at 396 lines** against SwiftLint's 400-line ceiling, so the About section moved
  to its own `AboutSection.swift` — the same treatment `PrivacySection` and `NoteSpellingSection`
  already have. Nothing about its behaviour changed in the move; the extraction is what buys the room
  for two new rows.
- `docs/site/support.html` said data lives "in your own private iCloud storage". **There is no
  cross-device sync**: `Pocket.entitlements` is deliberately empty and `PocketApp.swift` configures no
  CloudKit database. That claim was wrong on the page Apple requires as the Support URL, and it is
  corrected here alongside the in-app answer.
- Help copy now has a standing maintenance cost: it is a set of factual claims about the app, and the
  catalog test guards structure, not truth. **Read the answers against the shipped app** whenever a
  surface they describe changes.

## Alternatives rejected

- **Remote markdown, updatable without a release** — Note 13's own suggestion, and the reason D2 says
  "compiled". Doing it properly means hosting, caching, an offline fallback and a failure state, for
  content that changes about as often as the app ships. A compiled catalog is version-locked to the
  build it describes, which for factual claims about the app is a feature. Revisit when the answers
  start changing faster than the binary.
- **Coach-marks first** — Note 13 lists them as item (1). They are a bigger build (a tour engine, or a
  hand-rolled overlay per flow), they interrupt rather than answer, and they help exactly once. Help
  you can look up serves the same player later, and the player who skipped the tour. Coach-marks and
  the guided "art of creating loops" flow stay open behind this.
- **A separate help page inside Settings** — two help surfaces to keep in sync, and the wrong one is
  free. Rejected in favour of D1's single screen with two doors.
- **A support form or in-app ticket system** — an account, a backend and a moderation surface for an
  app that deliberately has none of those (ADR 0113). An email address is the whole feature.
