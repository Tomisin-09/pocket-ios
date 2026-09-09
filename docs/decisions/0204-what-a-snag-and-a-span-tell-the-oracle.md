# ADR 0204 — what a snag and a span tell the Oracle

- **Status:** Accepted
- **Date:** 2026-09-09 (`pocket-308-snags-read-back`)
- **Amends:** ADR 0187 — D6 gains an eighth rule (R8), and the context gains three fields on
  `Unit` (D1, D2). D6's existing seven rules are unchanged and every one of them still holds over
  the new fields; the output-side guarantees (D7, D8, D11, D12) are untouched.
- **Amends:** ADR 0199 — the span history now has its first reader outside the app (D2). The
  record, the cascade and the `SpanHistory` rules are unchanged.
- **Relates to:** ADR 0200 (the mark), ADR 0203 (the position rule this inherits), ADR 0070 (never
  grading), ADR 0092 (the AI charter), ADR 0121 (why a tempo never travels without its rate)
- **Schema:** none. No model, no new stored field — this reads what 0199 and 0200 already store.
  `OracleContext.currentVersion` also stays at **1**: fields were added, none changed meaning.

## Context

ADR 0199 shipped a recorded span history and said, in as many words, that nothing read it back yet.
ADR 0200 shipped the mark and said the same. Both were built so the data would start accruing before
the surfaces that need it existed — *"a history that only begins on the day its UI ships is a history
nobody has."*

The Oracle context (ADR 0187 D5/D6) is the surface that most wants them, and the one where getting it
wrong is least recoverable, because what crosses a wire cannot be un-crossed. So the question this
ADR answers is not *whether* they travel. It is **what shape they are allowed to take**.

The shape matters because both of them are one careless field away from being a grade. A snag count
per session, charted, is a mistake tally. A span history reduced to *"narrowed 4 times"* is a
diligence score. ADR 0200 already drew that line for the app's own UI — *"counts appear as where the
marks are, never as how many mistakes you made"* — and this is the same line on the way out.

## Decisions

### D1 — a snag crosses as a position inside a loop, never as a count

`OracleContext.Unit` gains `snags: [SnagMark]`, where a mark is `atSeconds` (measured **from the
loop's own start**), `markedOn` and `speed`.

Three things fall out of measuring from the loop's start rather than the song's:

- **It is readable without the song.** D6 R2 keeps titles, artists and file names off the wire, which
  means an absolute `128.2` is an offset into something the model cannot name. `14.0 seconds into a
  20-second loop` is a fact that stands on its own.
- **It says the thing worth saying.** Four marks at 2.1s, 2.3s, 2.4s and 2.6s of a loop is one
  difficult move, described. The same four as absolute song times are four numbers.
- **It keeps the payload and the screen in agreement**, which D3 below turns into a rule.

**Which marks belong to a loop is decided by position, not by `Snag.loopUID`** — the rule ADR 0203 D1
settled for the waveform's fade, and the one `SnagCluster.proposal` has used since ADR 0200. A mark
made under a wider version of this loop, or under the neighbouring one, is still a mark on this
passage; which loop happened to be armed at the tap is an accident of timing. Reading it the other
way would put a *different set of marks* into the payload than the set the player can see lit on
their own canvas — and the first time a reading mentioned a spot the player could not find, the
feature would be over.

**The date travels.** Positions alone cannot separate two very different readings: four marks in one
sitting is a passage fought over once; four marks across three weeks is a passage that keeps coming
back. That is a fact about when taps happened, and D6 R6 excludes *derived judgements*, not dates —
`lastPractisedOn`, `writtenOn` and every `TempoPoint` already carry one.

**The cap admits itself.** Over `maxSnagsPerUnit` (30) the oldest are dropped and `droppedSnags` says
how many. This is the `droppedNotes` rule (D6 R4) and it is here for the same reason: a snag set is a
**map**, so a set trimmed in silence is read as the whole terrain. Contrast `Tempo.points`, which
caps silently — a trajectory is read from its recent end, and dropping its oldest points does not
misdescribe where it is now.

### D2 — a span edit crosses as two widths, never as a verdict

`Unit` gains `spans: [SpanEdit]`: `changedOn`, `fromSeconds`, `toSeconds`, `speed`. Oldest first,
capped at `maxSpanEditsPerUnit` (10) **from the old end**, which is the asymmetry with D1 and is the
difference between the two things — a span history is a trajectory, a snag set is a map.

**`SpanHistory.Kind` does not travel.** The app already knows how to call an edit *narrowed*,
*widened* or *moved*, and it is exactly one adjective away from calling it *good*. D6 R5 keeps derived
values on this side of the wire; `80s → 20s` says everything the word "narrowed" says, and says it as
a measurement rather than as a characterisation. This is the same refusal that leaves
`TempoTrajectory.change` behind.

**Seconds, from each row's own recorded `songDuration`.** `LoopSpanChange` stores the duration at
write time precisely so a span reads back correctly after a relink (ADR 0152), and using the song's
*current* duration would quietly rewrite history the first time a file changed. A row with no
recorded duration cannot be stated in seconds at all and is **left out** — the one lossy case, and it
requires the audio to have been unloaded at the moment of the save. Fractions were the alternative
and are worse: `0.04 of the song` is unreadable without the song, and the song is the thing that does
not travel.

**Full history, not window-scoped**, for both D1 and D2 — the rule `tempo` already follows. A passage
that has given trouble since March did not start giving trouble on Monday, and a window-clipped map
would show a song that appears to have gone wrong only inside the request.

### D3 — D6 gains R8: what a mark may become

D6's seven rules become eight:

> **R8.** A snag crosses as a **position**, never as a count and never as a rate. Nothing derives
> marks-per-run, marks-per-week, or a change in either.

R1–R7 are mechanisms the builder enforces. R8 is partly a constraint on the **prompt** (ADR 0187
D17), because a payload that hands over thirty positions has handed over the ability to count them,
and no field can prevent that. What R8 does is fix which side the line is on and make it reviewable:
the client never sends a count, never sends a delta, and the prompt never asks for one.

That is not a weaker guarantee than it looks. `OracleContext`'s own doc comment already says the
safety of this feature does not rest on the type being thin — it rests on D7's proposal that can only
name units the client sent, D8's clamped minutes, D11's discarded tempo and D12's wholesale prose
rejection. R8 joins those, and the tone guard (`OracleToneGuard`) is where a reading that turned
thirty positions into "you made 30 mistakes" gets stopped.

### D4 — marks and spans are exempt from the free-text budget

Neither type carries a character of player-written text, so neither is charged against
`totalFreeTextBudget` (D6 R4). The alternative — counting them — would mean a heavily marked passage
silently pushing journal entries out of the payload, which trades the player's own words for
arithmetic the app could have sent as a summary. Wrong way round.

### D5 — a snag outside every loop does not travel

The context has no song entity: `Unit` is a drill or a loop, and that is the whole vocabulary. A mark
made with no loop armed, or one sitting outside every loop's current span, therefore has nothing to
hang from and is not sent.

Inventing a song-level bucket for them was considered and declined. It would put a song into a
payload that has carefully never contained one, it would need a name to be legible (which D6 R2
forbids), and the marks it would carry are the least interpretable ones there are — a position in an
unnamed 200-second recording, with no passage around it to be a position *in*.

## Consequences

- The Oracle can, for the first time, be told **where** a passage goes wrong and **how the player has
  been attacking it** — the isolate-slow-re-enter shape that ADR 0199 said would be worth building
  on. It is generated entirely by using the app: no rating, no tagging, no prose.
- `OracleContextBuilder+Units.swift` reaches `loop.song` — the one place in the builder that does. It
  takes the duration and the marks and nothing else, and `UnitSnapshot` still has nowhere to put a
  title, which is the mechanism D6 R2 rests on rather than the care.
- `SpanHistory.Kind` is now `CaseIterable`, so the test that asserts no verdict reaches the payload
  enumerates the vocabulary instead of hard-coding three strings that would silently stop covering a
  fourth.
- `OracleContextTests` reached the type-body limit and the new subject moved to
  `OracleSnagContextTests` — the `LoopWidthFloorTests` split, for the same reason.
- **Not built:** nothing consumes these fields yet. ADR 0187's S2–S5 are Tier 4 "not now"
  (`docs/directions-2026-09.md` §6), and this ADR does not move them — it makes sure that when they
  come, the material is there and is the right shape. The by-product argument ADR 0200 made stands:
  if S2–S5 never ship, the marks still paid for themselves the day they landed.
