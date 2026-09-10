# ADR 0211 — a door that waits for the voice

- **Status:** Accepted — built (2026-09-10, `pocket-312-close-the-oracle-door`)
- **Date:** 2026-09-10 (`pocket-312-close-the-oracle-door`)
- **Amends:** ADR 0187 — the Red Moon Oracle's **door on Home closes** while its register is
  unsettled (D1). Everything S0, S1 and S1a built stays exactly where it is: `OracleView`,
  `OracleCoordinator`, `LocalOracle`, all four guards, the cadence, the reading log and nine test
  files are untouched, and every decision 0187 records still holds. Only the way in is gone, and
  0187 D2's *the Oracle is pull, nothing notifies* is what makes that a small change rather than a
  removal — a feature nothing announces is a feature whose absence announces nothing either.
- **Amends:** ADR 0197 — the map is **five reachable destinations, not six** (D3). The three
  sections, the two-to-a-row grammar and §1's rule that a destination's accessibility label is the
  UI-test contract are all unchanged; the sixth tile is still drawn, hidden, and still sets the
  Learn row's height.
- **Relates to:** ADR 0070 (no performance feedback — the line the Oracle walks, and the reason a
  teaching corpus cannot supply the missing register), ADR 0092 §A2 (the deterministic local
  fallback, which is why the shelved feature is *complete* rather than half-wired), ADR 0102 (the
  Learn section, which stays), ADR 0165 (the manual quotes the app — so the manual loses the tile
  in the same change), ADR 0144 D2 (the Toolkit's freedom, undisturbed).
- **Schema:** none. Nothing is read, written or migrated that was not before.

---

## Context

The Red Moon Oracle works. In a Release build it draws a reading end to end with **no network at
all** — `OracleEndpoint` resolves to `nil` in Release by design (0187 S0), so `LocalOracle` writes
the reading on the device, which is what ADR 0092 §A2 required of it from the start. The safety
envelope is complete: D12's tone guard throws away any reading containing a verdict, D13 answers
distress with fixed copy rather than generated prose, D23's focus guard is in, and D15's gate
always states the date the next reading opens. Every one of those is unit-tested.

What it does not have is a **voice**. The prose S1a produces was rejected on reading it:

> The week of 29 Aug to 5 Sep. You worked on Bend study, Chorus turnaround and Chromatic warm-up.
> Chorus turnaround: 4 runs at 34 seconds, then on 31 Aug you took it to 6 seconds, and 9 runs
> since.

Every sentence in that passes D12, D22 and D23. It is accurate, it grades nobody, and it reads like
an engineer describing a data structure. **The guards say what may not be said; none of them says
how it should sound** — so no test catches this, and tuning it by ear is exactly what produced it.
`docs/backlog.md` parks the register as research with a deliverable (a register spec in
`docs/research/`, whose sentences become fixtures) and an explicit instruction not to attempt
another pass by ear.

Meanwhile `CHANGELOG.md` `[Unreleased]` holds six hundred lines of finished work — folders, the
journal redesign, snags and span history, export and restore, takes and moments, reference links,
long-term goals, routine sharing, the Home tile grid. All of it is waiting behind one feature that
is not late, not broken and not nearly done: it is *finished in the half that can be built and
unstarted in the half that has to be researched*.

An ADR rather than a revert, because the alternative was live and reasonable — the tile could have
been dimmed and captioned — and because the rule this settles will come up again.

## Decision

### D1 — the door closes; nothing else moves

The Oracle's tile is not reachable on Home in a build a player holds. No file in `Core/Oracle/` or
`Features/Oracle/` is edited, deleted or commented out. `git` is not the archive here — the
**compiler and the test suite** are, and a shelved feature that still compiles under Swift 6 strict
concurrency and still has nine passing test files is a feature that comes back in an afternoon.
One that was deleted "because it's in the history" comes back as a rewrite.

The rule, stated generally: **a feature whose mechanism is finished and whose voice is not does not
get a placeholder — it gets its door removed, and its code stays where the tests still run.**

### D2 — no *Coming soon*, dimmed or otherwise

The tile is not greyed, captioned, badged or made to open an explainer.

Two reasons, and the second is the one that would still hold if the first did not. A dimmed tile
that does not navigate is a **non-functional control in a shipped binary**, which is what App Store
Guideline 2.1 names, and this app has an approval to protect. And *soon* is a claim: the register
question has no scope, no estimate and a research deliverable in front of it, so the honest version
of that caption is a sentence nobody would want on their home screen. An absent door claims nothing
and disappoints nobody.

Refused in the same breath: shipping the reading as it stands. The Oracle carries **the brand's own
name**, and the first thing it would ever say to a player is prose we did not want to read.

### D3 — the empty half is the real tile, hidden

`learnRow` draws `toolkitTile` and then `oracleTile.hidden()`. Toolkit keeps the exact size every
other destination has, and the gap on the right is where the Oracle returns.

- **Never `Color.clear` as the filler.** A clear view is greedy in both axes: as a blank grid cell
  it stretches the rows that hold it, and only at the size where there is slack to take — a defect
  that shows up in one configuration and not the one you are looking at. `.hidden()` on the real
  view keeps the frame and removes it from the accessibility tree, which is both halves of what is
  wanted here.
- **The row's height does not change when the door reopens**, because `.hidden()` keeps the frame
  and the hidden tile goes on feeding `HomeTile`'s equal-height row. **Measured rather than
  reasoned:** Home was captured with and without `-oracleDoor` and the pixels decoded — the Learn
  row is **311px tall at y=2085 in both**, on an iPhone 17 at default Dynamic Type. Reopening the
  door therefore moves nothing but the tile appearing.

  The measurement also corrected a claim this codebase had been repeating: `HomeView+Map` and
  `HomeCards` both said the row's height came from `Red Moon Oracle` **wrapping to two lines**. It
  does not wrap at tile width — a wrapped title would make the Learn row taller than the 311px
  `Practice` row, and the two are identical. The equal-height row still earns its place at larger
  Dynamic Type; the wrapping was simply never checked. Both comments now say what was measured.

A full-width Toolkit tile was considered and refused: it gives the Toolkit more visual weight than
Practice, which is the brand hero, and it breaks the two-to-a-row grammar ADR 0197 established for
the sake of one release.

### D4 — the screen stays reachable to the harness, behind **two** arguments

`OracleUITests` is kept, not deleted, and opens the tile with `-oracleDoor`
(`UITestHooks.oracleDoorArgument`), which is only honoured when `-uiTesting` is present as well —
the same rule `-shotHour` follows, for the same reason: a stray argument must not surface a shelved
feature on a build a player is holding.

**The second argument is load-bearing, and this is the trap it avoids.** The manual's shoot runs
under `-uiTesting` too. A door gated on the test flag alone would therefore put the Oracle's tile
back into `reference/home` and `getting-started/home` — figures showing a destination no released
build has. That defect lives entirely in the pixels, where `check-manual.py` cannot see it and
every assertion in the suite still passes. `OracleDoorArgumentTests` pins it by asserting against
the shoot's own literal argument list.

### D5 — the closed door is asserted, not assumed

`PocketLaunchUITests.testTheOracleIsNotReachableWithoutItsDoor` fails if the tile is reachable on
an ordinary launch. The list of spoken map labels in the same file loses its Oracle line — on
purpose, and with the reason written beside it, because a hidden view is out of the accessibility
tree and VoiceOver now reaches five destinations.

An absence is the easiest thing in a codebase to lose by accident: the condition is read in exactly
one place, and a refactor that drops it looks like a simplification. The negative test is what makes
that a failure rather than a surprise in a shipped build. It gates on the Learn section rendering
first, so a failure distinguishes *the door reopened* from *Home never drew*.

### D6 — what reopens it

The backlog item is the specification, and its deliverable is the acceptance test: a register spec
in `docs/research/` whose sentences become fixtures the existing guards run against. When a reading
drawn by `LocalOracle` reads like something a person would say, `learnRow` loses its condition and
`PocketLaunchUITests` loses D5's test. Nothing else has to be rebuilt.

Two constraints any such pass inherits, both already established and neither reopened here:
`Profile`'s `ArtistExperience` and `MusicGenre` are collected at intake and **deliberately unread**
(0187 D6 R3 — the way to keep a field from crossing is to not read it), so varying register by level
or genre is itself an ADR-level decision whose R3-preserving shape is *a structural payload with the
client picking the words*; and teachers grade while ADR 0070 forbids it, so a corpus of real
teaching talk is mostly unusable as-is.

### D7 — the release does not claim the feature

The two Oracle entries stay in `CHANGELOG.md` `[Unreleased]` when the version is cut, rather than
travelling into the released section. Release notes describing a screen nobody can open is the same
mistake as the placeholder tile, made in prose.

## Consequences

- Home is five reachable tiles in three sections; the Learn row is deliberately asymmetric. This is
  a judgement no build or test makes — it needs eyes, in both appearances.
- **No figure goes stale, and this was checked rather than assumed.** The change was planned on the
  assumption that Home's figures photograph the tile grid and would need a shoot. They do not:
  `reference/home` is the only capture of Home (it also serves `getting-started/home` via
  `alsoServing`), it is a single unscrolled screen, and it **cuts off inside `Your stuff`** — the
  Learn row has never been in it. Every `toolkit/*` shot is of the Toolkit's own screens, reached by
  scrolling Home rather than photographing it. Nothing above the Learn row moved, so the existing
  figures remain correct. A shoot pass was planned, priced at roughly twelve minutes and a machine
  to itself, and was not needed — **look at the image before booking the shoot.**
- `docs/manual/reference/home-and-library.md` loses the Oracle from the Learn section and drops
  from six destinations to five. `check-manual.py` C9 enforces the backticked names against real
  string literals, so this cannot be forgotten quietly.
- `README.md` and `docs/architecture.md` keep their Oracle sections — the module is still here and
  still accurate — and each gains a line saying nothing on Home reaches it.
- The binary still contains the whole feature. That is intended, and it costs nothing a player can
  observe: no network, no schema, no launch work, and `OracleReadingLog` is only read from a screen
  that is no longer presented.
- ADR 0187's status line is now *shipped but unreachable*, which is a state that ages badly if it is
  only recorded here. It is written into 0187's own header in this same change.

## Alternatives considered

- **Dim the tile and caption it *Coming soon*.** Refused by D2 — a dead control in a shipped build,
  and a promise with no scope behind it. It was the cheaper option: `HomeTile` already has a
  `caption:` slot and no figure would have needed reshooting.
- **Ship the reading as it is.** Refused by D2. The mechanism is sound and the voice is not, and the
  feature speaks under the brand's own name.
- **Delete the Oracle and recover it from git.** Refused by D1. History preserves text, not the
  guarantee that it builds; the tests are what preserve that, and they only run against code in the
  tree.
- **Put another destination in the empty slot** — a folders door was the obvious candidate. Refused:
  ADR 0210 D3 makes a folders door a third screen (folders are one namespace across two libraries,
  so a folder tapped on Home must open exercises, routines, or a combined view that no slice of 0210
  builds), and a gap is not a reason to build a screen.
