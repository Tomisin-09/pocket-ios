# ADR 0201 — reading the span history back, and a way back from a drop

- **Status:** Accepted
- **Date:** 2026-09-09 (`pocket-307-span-history-and-return`)
- **Relates to:** ADR 0199 (which records the spans this reads back), ADR 0200 (the snag offer,
  whose transient-bar slot this deliberately does **not** compete for), ADR 0041 (the A/B span both
  audition paths land in), ADR 0089 (the arming speed, which is why the return pill has to tell a
  drag from a write), ADR 0124 (the one speed axis)
- **Schema:** none. No model, no new stored field — the return offer is deliberately screen-lived.

## Context

ADR 0199 started recording how a loop's span got where it is, and said plainly that **nothing read
it back yet**. This is that half.

It arrives with a constraint that shaped every decision below: **the practice cockpit has no room.**
The status line already holds *Loop controls*, *Follow* and *Grid*; the transport is full; ADR 0200
has just taken the one transient slot for the snag offer. Any surface that claims permanent space
here has to evict something that is already earning it.

There is also a second, smaller absence worth fixing in the same pass. **Dropping the speed works;
coming back never has.** Before this ADR the codebase contained no `previousSpeed`, `restoreSpeed`
or `revertTempo` of any kind. A drop was a one-way cost — paid by hand, undone by hand — which is a
good part of why players are reluctant to take one. The motor-learning material asks them to slow
down; the app charged them for it.

## Decisions

### D1 — the history has no cockpit surface at all

It reads in **`LoopEditSheet`**, in a *How it got here* section directly under *Range*, because that
is the same subject: where this loop sits, and how it came to sit there.

The sheet costs the screen nothing and is already reachable — every loop row has carried a 0.4s hold
that opens it since long before this. So the history lands beside the rest of a loop's practice
state, with room to breathe, and the cockpit is untouched.

**Rejected: a resume card at the top of the practice screen.** It was drawn, and it was the weakest
thing in the design: permanent space claimed for facts that read better somewhere you open on
purpose.

The section is **absent entirely** until there is a history to show, rather than present-and-empty.

### D2 — widen back one rung, not all the way

`SpanHistory.widenTarget` walks the history **newest first** and offers the first span that was
genuinely wider than where the loop sits now.

A loop narrowed in three steps should widen back to the size it was working at yesterday — not leap
to the whole lick it started as. **Isolating is a ladder, and coming back down it a rung at a time
is the point.** Reaching for the widest recorded span would skip the rungs.

Spans that are the same width or narrower are skipped, which quietly handles the `.moved` case: a
span that slid along the song is in the history but is not somewhere to widen *to*. A loop with
nothing wider behind it gets no offer at all, rather than one that returns its own bounds.

### D3 — widening auditions; it never writes

`startWidenEdit` lifts the loop into an **A/B span** (ADR 0041) at the older bounds and plays it —
the same contract `startRangeEdit` has, and identical to ADR 0200's tighten path.

Isolating is only half the behaviour; **putting it back is where you find out whether it stuck**, and
that is a thing to hear rather than a number to accept. Save commits it through `saveABSpan`, so the
widening is recorded by ADR 0199 like any other edit — no second write site. ✕ discards it.

### D4 — the return pill is screen-lived, and only the player's hand arms it

A pill beside the speed readout offers the speed a drop started from.

**Not persisted.** It lives as long as the screen does, like the A/B span. A stored one would offer
to return you to a tempo you left last week, which is a much weaker claim than *"you were just at
0.90×"*.

**Only player-driven changes count.** `speed` is also written by the app — arming a loop sets it from
the loop's command-anchored speed (ADR 0089) — and being offered a "return" to the *previous loop's*
tempo would be nonsense. So arming stands the offer down and marks subsequent writes as not
user-driven; touching a speed control marks them as user-driven again.

The rule itself is pure (`TempoReturn`) and has three parts worth stating:

- **The first drop wins.** Dragging 1.0 → 0.9 → 0.72 is one gesture and one intent; the speed worth
  returning to is where the drag started, not a value it passed through.
- **A nudge is not a drop** (`minimumDrop`, 0.05). A pill after a slider wobble is noise, and noise
  beside the tempo readout is worse than nothing.
- **Getting back by hand clears it.** Once the speed is at or above what was remembered, the offer
  has been taken and the pill has nothing left to say.

### D5 — the widen offer never raises itself

Unlike ADR 0200's snag bar, widening is reached only from the sheet. Two self-raising bars competing
for one status-line slot would need a priority rule, and the second one would be the one that fires
when you are least expecting it. A loop sitting narrow is not news; it is a choice the player made.

## Consequences

- Narrowing is now legible: a loop can say it went from `1:44–2:18` to `1:52–2:08` to `1:58–2:04`,
  each row carrying **the span and the speed together**, because the narrowing and the slowing are
  one behaviour rather than two facts.
- Dropping the speed stopped being one-way.
- **`WaveformPracticeModel.swift` is now at exactly 400 lines**, the SwiftLint cap. The next stored
  property added to it forces a split.
- ⚠️ **`WaveformPracticeView`'s loop-edit sheet had to move out of its `.sheet` closure.** Adding one
  callback tipped the body past the Swift type-checker's time limit — *"unable to type-check this
  expression in reasonable time"* — and explicitly typing the closure parameters was not enough. It
  is now a named `@ViewBuilder` in a `private extension` (an extension, because lifting it into the
  struct body pushed that past SwiftLint's type-body cap). The next callback added there will not
  re-cross either line.
- **`LoopEditSheet` has an explicit `init`**, so a new property is not enough on its own — the
  parameter has to be threaded through it. The compiler said *"extra argument 'onWiden' in call"*,
  which reads like a call-site mistake and is not.
- **Not built:** any history surface outside the sheet — no journal entry, no export column, nothing
  on the Loops panel row, and no chart of spans over time.
