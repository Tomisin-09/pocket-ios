# ADR 0276 — The practice studio that adds up

- **Status:** Accepted — decided with Tomisin on 2026-10-24. Wording only; nothing in the app's behaviour,
  data or screens changes.
- **Date:** 2026-10-24
- **Amended by:** ADR 0278 (2026-10-26) — **D3**: Help's first question is now *"What is Red Moon?"*,
  after the App Store rename to *Red Moon Practice Studio*. The rest of D3, and the line, stand.
- **Amends:** `docs/positioning.md` (not an ADR) — §0 is new, §6's product-framing line says *studio*, and
  §7's audit becomes a status table.
- **Relates to:** 0001 (the audio is the player's own, which is why *studio* can be said) · 0070 (never
  grades; the reason the word is not *coach*) · 0165 (the manual quotes the app, so a name has to
  change in the app first) · 0167 (references: the "complements your other sources" half is already
  built) · 0256 (one plan: the listing no longer says *free*)
- **Schema:** none.

## Context

Tomisin: the app has changed shape with every feature, and it is hard to say in a sentence what it
is. The repo's position (`docs/positioning.md` §1, §6) was correct and was written for analysts: *the
intersection of a session conductor and an audio engine*. Nobody has that problem. Two phrases
survived the conversation about it. *Practice that adds up* names the benefit: the loop saved
yesterday is a block in today's session, nothing resets when the app closes. *Complements other
learning sources* names the posture: the app holds the thread and never asks the player to move the
lesson here. Tomisin also chose **studio** over **room**: it reads as more thematic, and sits better
with *Red Moon*.

## Decisions

### D1 — The line

> **Red Moon is a practice studio for songs you own. Your practice adds up instead of starting over,
> and it works alongside whatever you already learn from.**

Every surface that describes the app traces back to this. The two ideas are one claim: practice adds
up *because* the app keeps the thread, including the thread back to the lesson.

### D2 — *Practice studio*, always both words

*Studio* alone reads as a recording app, and a DAW is not what this is. *Room* is retired in
descriptions of the app (`FAQEntry`, the manual, the beta guide, the listing copy). Not *coach*,
*tutor* or *teacher*: they promise judgement, which 0070 rules out.

### D3 — Wording only; the questions stay

> **Amended by 0278 (2026-10-26):** after the app was renamed on the App Store to *Red Moon
> Practice Studio*, the first question became *"What is Red Moon?"*. The answer, and the other
> questions, stay as below.

`FAQEntry`'s *"What is Red Moon Practice?"* keeps its question text, because `check-manual.py` C3
pins every cited question and `FAQEntryTests` pins the catalog. Only the answer changed, and
`ManualToolkitShots` matches the opening words of that answer, so its prefix moved with it.

### D4 — Price is not part of the line

ADR 0256 reversed 0237 (free) before the free build shipped. The listing copy still said *free* and
*nothing to buy*; those are corrected, and the file's banner says what is history. The line above names
no price: the storefront shows it, and ADR 0145 D6 forbids hardcoding one in help copy.

## Consequences

- `docs/messaging.md` holds the pitch at each length, the feature → need → benefit table, the SWOT and
  the outreach plan. It is a working document and is expected to change; this ADR is only the line.
- The landing page and story page live in a separate repo that deploys on every push. They are **not**
  changed here and still say *room* wherever they do (`docs/positioning.md` §7).
- Screenshots and the promotional text are untouched. The promotional text is the one editable listing
  field and a candidate for *adds up*; see `docs/messaging.md`.
