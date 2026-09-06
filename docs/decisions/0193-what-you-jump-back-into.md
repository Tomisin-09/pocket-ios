# ADR 0193 — what you jump back into is a choice, not a guess

- **Status:** Accepted
- **Date:** 2026-09-06 (`pocket-301-resume-and-snapping`)
- **Relates to:** widens the ADR 0044 follow-on home hub's resume card from songs to three kinds;
  places the setting under **ADR 0162 D2**'s Practice destination and gives it **ADR 0163**'s second
  door (the hold, with the Settings row kept). Gated with **ADR 0144 D4**. Reads the fields ADR 0066
  and the planner already write. Picked up from `docs/directions-2026-09.md` §2 / §6 Tier 1 item 2.
- **Schema:** **none.** `Song.lastPracticed`, `Routine.lastPracticed` and `Exercise.lastPracticed`
  all exist and are all written on every run; two of the three were read by nothing on this screen.
  One new `UserDefaults` key, `jumpBackIn`. Nothing about ADR 0189's criteria is engaged.

## Context

Home's **Jump back in** card has always offered *the song you last practised*, and only that. But a
routine stamps `lastPracticed` on every run (ADR 0066 follow-on), an exercise stamps it on every run
too (the planner reads it on two axes), and Home consulted neither. A player whose practice is
mostly routines saw a card offering a song they last opened three weeks ago, sitting above a
*Recent routines* rail that knew better.

So the card was not wrong about songs. It was **narrow about practice**, and the narrowness was
invisible: nothing on the screen said "songs only", so it read as a broken *most recent*.

The cheap fix would be to widen it silently — always the newest of the three. That is right for most
people and wrong for the player whose answer is stable: *I always come back to the same routine.*
Both are one setting apart, and the data for both was already on disk.

## Decisions

### D1 — Four values, and `Loop` is not one of them

`JumpBackInPreference`: **most recent** (the default) · **song** · **routine** · **exercise**.

*Most recent* is what Home did before this ADR *and* what it should have done — the default changes
nothing for an upgrading install and fixes the narrowness for everyone who never opens Settings.

`Loop` is absent because `lastPracticed` does not exist on it. Adding the field to round the set out
would be a schema change made for a card, which is exactly the trade ADR 0189's criteria exist to
refuse. This is recorded here rather than left as an omission somebody re-proposes.

### D2 — The choosing is pure; the looking-up is not

`HomeFeed.resumeKind(preference:songPracticedAt:routinePracticedAt:exercisePracticedAt:)` takes
three dates and returns a `ResumeKind?`. It is pure and unit-tested beside the rest of `HomeFeed`;
`HomeView+Resume` then resolves the winning kind back into a model. Two steps, because the step with
the rules in it is the one that must be testable without a store.

**Ties break song · routine · exercise** — the declaration order, and the same first-maximal rule
`HomeFeed.mostRecentlyPracticed` already uses, so two surfaces reading one instant cannot disagree
about which unit that instant belongs to.

### D3 — A pin with nothing behind it falls back, rather than blanking the card

Pinned to *Routine* having never run one, the card shows the most recent of any kind.

**Rejected: honour the pin absolutely.** It punishes a player for stating a preference before they
own anything of that kind, and it turns Home's most useful card into an empty slot to teach a lesson
nobody asked for. The fallback is also unobservable in the direction that matters: the moment a
routine *is* practised the pin takes over, and never yields again.

The card still hides entirely when **nothing at all** has been practised, exactly as it always has.

### D4 — Two doors, and the eyebrow does not move

The setting is a row in **Settings ▸ Practice**, and a **hold on the card itself**. Both write the
same key, so there is no second copy of the four labels to drift.

- **Not an eleventh hub row.** ADR 0162 settled the hub at nine preference destinations plus two
  state rows; one picker does not earn a screen.
- **Practice is the right one of the nine.** It is the only row there that describes a screen rather
  than a run, and the justification is ADR 0186's for reminders: what Home offers you to resume is
  what you end up practising.
- **The hold is ADR 0163's grammar**, not a replacement for the Settings row. 0163 D2's load-bearing
  half is that the findable route stays.

`JUMP BACK IN` stays fixed as the eyebrow. A card that renamed itself with its contents would read
as three cards sharing a slot; only the body changes shape — a song shows artist and mastery, a
routine its block count (the same figure `RecentRoutineCard` states, so one screen cannot give one
routine two sizes), an exercise its command tempos.

A routine gets **no mastery readout**, and cannot borrow the song card's: `MasteryReadout(nil)`
renders an em dash meaning *unrated*, which for a routine would state something untrue rather than
nothing. ADR 0070 keeps grades off practice, so the absence is permanent and the card is typed for
it (`JumpBackInCard.Trailing`).

### D5 — All three shapes stay gated, and an exercise borrows the Practice gate

Each shape is a *second* door into a surface a section strip already locks (ADR 0144 D4). An
exercise takes `.practice` rather than a gate of its own, because the door it duplicates is the
Practice strip; inventing a fifth `HomeGate` case would split that evidence for no decision it could
inform. The destination is `ExerciseRunScreen`, never `ExerciseRunView` — the one place that decides
which run screen a drill gets (ADR 0136).

A routine lands on `RoutineDetailView`, **not** a one-tap replay. That is the 2026-07-11 device
finding that superseded ADR 0066 from Home, and the rail already goes there.

### D6 — The key is cleared under `-uiTesting`

`AppSettings.resetJumpBackInPreference()` joins `resetJournalFilters()` at launch. A simulator keeps
its `UserDefaults` between runs, so a test that pins the card leaves it pinned for the next test and
the next *run*. On Home that is the expensive version of the trap: `reference/home` is shot through
this card, and a pinned preference returns a clean, plausible photograph of the wrong unit with
nothing in the run to object.

## Consequences

- Home's card now reads the two `lastPracticed` fields it had been ignoring, and adds none.
- **No Home reshoot.** The default is *most recent*, and `PracticeHistorySeed` stamps the newest song
  at `daysAgo: 0` against routines at `1` or more and exercises at none — so the seeded figure
  resolves to the same song it always did. Had the seed's newest been a routine, this would have
  cost a ~6-minute `PocketShootUITests` run.
- `docs/manual/reference/home-and-library.md` and `reference/settings.md` both change in this commit
  or `check-manual.py` fails; the hold joins `gestures.md`'s menu-hold section. The
  `long-press-sites` tripwire is untouched — a `.contextMenu` is not an `onLongPressGesture`, and
  the card is a menu hold, not one of the nine that open a screen.
- `AppSettings.swift` was **exactly** on SwiftLint's 400-line cap, so the accessor could not land in
  it. It lives in `AppSettings+Home.swift`, and ADR 0182's backup preference moved to
  `AppSettings+Storage.swift` to make room — which also unpicked a merged doc comment there, where
  `songsInBackupDefault` had come to sit *inside* the block explaining ADR 0163's four song-player
  defaults, leaving that block documenting a backup setting and those four constants documented by
  nothing. The keys all stay in `AppSettings.Key`.
- **Not covered:** the stat strip and the tile grid of `docs/directions-2026-09.md` §2. Those are the
  Home changes that *do* cost a reshoot, and the doc's own instruction is to batch them onto one
  branch and shoot once. This one does not touch a figure, so it does not have to wait for them.
