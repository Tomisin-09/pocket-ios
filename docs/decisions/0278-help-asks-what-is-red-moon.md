# ADR 0278 — The store name is Red Moon Practice Studio, and Help asks "What is Red Moon?"

- **Status:** Accepted. Tomisin renamed the app in App Store Connect for 1.4, and chose the question
  on 2026-10-26. Built on `pocket-390-release-1-4`.
- **Date:** 2026-10-26
- **Amends:** ADR 0276 — **D3**: Help's first question changes from *"What is Red Moon Practice?"*
  to *"What is Red Moon?"*. Its answer and the other questions stand.
- **Relates to:** 0276 D2 (*practice studio*, always both words) · 0277 (the subscription group shows
  the store name) · 0165 (the manual's citations, held by `check-manual.py` C3)
- **Schema:** none.

## Context

After 0276, Tomisin renamed the app on the App Store from *Red Moon Practice* to *Red Moon Practice
Studio* (24 of 30 characters). The home screen already said *Red Moon*. Help's first question still
named the old store name. 0276 D3 had kept the question's text, because nothing else had changed
yet.

## Decisions

### D1 — On the App Store, it's *Red Moon Practice Studio*

- The name is set in App Store Connect, not in the repo. On the home screen it stays *Red Moon*
  (`CFBundleDisplayName`), and the code keeps *Pocket*.
- The subscription group *Red Moon* shows this name beside it in Settings ▸ Subscriptions (0277).

### D2 — Help asks *"What is Red Moon?"*

- *Red Moon* is the name on the home screen, and the name 0276's line opens with (*"Red Moon is a
  practice studio…"*). The question reads the same whichever store name a player came through, and
  it won't need changing if the store name moves again.
- The answer doesn't change.
- The manual's citation and `ManualToolkitShots`' query move with it.

### D3 — What still says *Red Moon Practice*

- **The support email's subject and summary line.** Only Tomisin reads them, and
  `SupportRequestTests` pins them.
- **The manual's title and its own prose** (`docs/manual/README.md`, `getting-started.md`). These
  aren't changed here.
- **The site's privacy section**, under the anchor `#red-moon-practice`. Settings ▸ About links to
  that anchor (`AboutSection.swift`), and the 1.1 checklist suggests App Store Connect's Privacy
  Policy URL does too. If the heading is renamed, the anchor's id has to stay, or the in-app link
  stops landing.

## Consequences

- **Code:** one question string, and the shoot test's query. No unit test pins the question.
  `ManualToolkitShots` isn't run here, because the shoot target is outside CI and reshoots are held.
- **Docs:** the manual's citation (C3 checks it), the audit row in `docs/positioning.md`, and the
  CHANGELOG entry.

## Alternatives rejected

- ***"What is Red Moon Practice Studio?"*** It ties the question to a store name that has already
  changed once.
- **Leaving it.** It names the app by a name the store no longer uses.
