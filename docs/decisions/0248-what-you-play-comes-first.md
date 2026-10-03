# ADR 0248 — What you play comes first

- **Status:** Accepted — decided with Tomisin, 2026-10-03. Built on `pocket-360-manual-reshoot`.
- **Date:** 2026-10-03
- **Amends:** ADR 0113 — the first-launch intake gains a first card, *What do you play?*, and the
  experience card asks about the answer (*Where are you with the piano?*). The limit 0246 set, "four,
  or five", becomes "five, or six". Every card is still skippable, and so is the whole flow.
- **Amends:** ADR 0116 — the intake now sets the profile's neck. Its D3 says the instrument default
  is "set at intake", and nothing did that until now. A guitar or bass answer writes
  `preferredInstrument`. `Instrument` keeps its two cases, and the wider answer is a separate field
  (D2), so no app-wide mode comes back.
- **Amends:** ADR 0144 — D8's first-run seed (seven exercises since 0247, one routine) now depends
  on the answer. It still goes to guitar, bass or a skipped question. Every other answer gets none (D4).
- **Amends:** ADR 0246 — the goals card is also left out for an answer without a neck (D5). The seed
  that 0246's *Rejected* section raced now waits for the intake (D4).
- **Amends:** ADR 0247 — its seventh drill, like the other six, is seeded only for guitar, bass or a
  skipped question.
- **Relates to:** 0070 (nothing here grades) · 0219 (Binta, the song every player can start on) ·
  0162 (Settings ▸ You, where the answer is changed)
- **Schema:** one optional attribute, `Profile.playsRaw: String?`, a lightweight migration. It is
  carried in the archive as an Optional, so an older archive still decodes.

## Context

Red Moon is built around the guitar: the neck, the drills, chords, tabs, the tuner. But a lot of what
it does has nothing to do with a fretboard. You can loop any song, slow it down without the pitch
dropping, keep the loop and play over it with a click. A singer learning a run, a pianist learning a
voicing and a producer studying an arrangement can all use that.

Tomisin, 2026-10-03, reviewing the reshoot: *"Not everyone that downloads the app plays bass or
guitar … the first question needs to reflect that. We make guitar the first option, bass second,
then piano, singing, producing, then other popular instruments? For options not bass or guitar,
they most likely downloaded the app for the looping and basic metronome features … Maybe we could
factor that in when building their experience?"*

Before this, the first card was *Where are you with the guitar?*, and every new install was seeded
with seven guitar drills and a guitar routine. Those drills were also what Today's session built
from. A pianist's first view of Practice was therefore spider walks.

## Decision

| # | Decision |
|---|---|
| **D1** | **A first card, *What do you play?*** It offers Guitar · Bass · Piano or keys · Singing · Producing · Drums · Ukulele · Violin · Something else, in that order: guitar first, bass second, then the rest. It is a single choice, and it can be skipped like every other card. |
| **D2** | **A new field, not a wider `Instrument`.** The answer is `PlayedInstrument`, stored raw on `Profile.playsRaw`. `Instrument` is the neck an exercise is drawn on (0116), so a piano answer has nothing to map to. `PlayedInstrument.fretboard` is the bridge between the two, and only guitar and bass have one. Ukulele is fretted, but it has no neck here yet (0116 parked it), so it is treated like the rest. |
| **D3** | **The experience card asks about the answer.** It becomes *Where are you with the piano?*, *…with singing?*, *…with producing?*. Two of its options follow the answer: *Know a few chords* becomes *Know a few songs* for a singer, *Know a few lines* for a bassist and *Finished a few tracks* for a producer, and *Been playing a while* becomes *Been singing a while*. Only the words change; the stored answer is the same either way. A skipped first card asks about the guitar, as before. |
| **D4** | **An answer without a neck seeds no guitar drills.** On the launch the intake shows, the drills and Morning Routine are not seeded until the intake is closed. Guitar, bass or no answer gets the first-run set as before. Any other answer gets an empty Practice library, and the seed is marked done so no later launch adds it. Morning Routine is built from those same drills, so it resolves nothing and does not seed either. These players came for songs, loops and the metronome, and Practice fills up from the loops they save. |
| **D5** | **No goals card for an answer without a neck.** This is 0246 D4's own rule: a template is offered only if it gives Today's session something on a new install. A library with no drills gives every template nothing. |
| **D6** | **Settings ▸ You's *Instrument* row becomes *You play*.** It offers the same nine answers, with no "Not set": a profile that never answered shows the neck it has (Guitar or Bass), which is the only question it was ever asked. Choosing Guitar or Bass also sets the neck. Changing the answer later adds and removes nothing in the library. |
| **D7** | **Nothing else changes per answer.** Home, the Toolkit and the song player are the same for everyone. |

### Rejected

- **Hiding the Toolkit's guitar tools for other answers.** The Toolkit also holds the glossary and
  Help, which everyone uses. A hidden tool is harder to find than an unused one. And 0116 Fork 1
  rejected an app-wide instrument mode for this reason: someone who plays two instruments loses
  half the app. Revisit this if non-guitar players turn up and say the tools get in their way.
- **Seeding instrument-agnostic drills instead.** The catalog has none that make sense for a singer
  or a producer. The loops they save are the right first units, and the planner already builds from
  loops.
- **Removing seeded drills after the answer.** Seeding first and deleting afterwards would race the
  seed and need a provenance-checked delete. Waiting is simpler and leaves nothing to undo.
- **Several instruments at once.** That is more honest for a multi-instrumentalist, but the card is
  single-choice like every other, and the only consumer (D4, D5) needs one answer. They can change it
  in Settings.

## Consequences

- A guitarist sees six cards, or five after *Just unwind*. Anyone without a neck sees five, because
  the goals card is left out.
- **The seed no longer races the intake.** 0246 rejected a live offer because Home seeded the
  first-run drills while the intake's cover was still appearing. On the intake's launch, that seed
  now waits for the cover to close.
- An existing install never sees the intake again, so nothing changes for it. Its profile reads as
  the neck it has.
- UI tests run with the intake suppressed, so their seed path is unchanged. The manual's bare pass
  launches without that suppression, and its figures are of the cards, so it never seeds.
- Owed: the first-run figures (`getting-started/first-run`, `getting-started/goals-card`) and
  `reference/settings-you`.
