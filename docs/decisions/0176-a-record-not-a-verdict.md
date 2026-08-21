# ADR 0176 — a record, not a verdict: Progress becomes the Practice log, and comes out of the menu

- **Status:** Accepted
- **Date:** 2026-08-21 (`pocket-279-practice-log-rename`)
- **Amends:** ADR 0117 (practice stats & the Progress screen) — the screen it built keeps its
  content, its constraints and its deferrals, and changes only its name and its door.
- **Relates to:** ADR 0070 (Pocket never grades the player), ADR 0100 (the Journal is the
  read-only, cross-cutting practice-history space), ADR 0126 (toolbar grammar), ADR 0144 (one
  app, one price — the Journal is free forever), ADR 0155 (the Journal's ＋, and the toolbar
  question this reopens), ADR 0165 (the manual quotes the app)
- **Schema:** none. No `@Model` is touched; safe under the post-1.1 freeze.

## Context

Two complaints about the same screen, arriving together.

**The name argues with the content.** ADR 0117 exists to build a stats surface that obeys ADR
0070 — Pocket never grades the player — and it is unusually strict about it: no streaks, no
weekly goal, no days-active denominator, no week-over-week delta, and tempo recorded as "what
was played", never as a score. The screen's own empty state states the principle out loud:

> It's a record of the work, not a mark for it.

And then the screen is called **Progress**, which names a direction. A player who practised
twice this week opens a screen titled *Progress* and reads two bars, and the title has supplied
the verdict the whole design refused to supply. The word is doing the one thing every measure
underneath it is built to avoid.

The manual had already noticed, without anyone deciding it should:

> **Progress** is the same history counted up: minutes, days, and the things you have made.

That sentence reaches for *history* because *progress* does not describe what is on the screen.

**The door is a menu.** ADR 0155 resolved the Journal's toolbar under ADR 0126's grammar —
`ellipsis.circle` then `+`, and three bare trailing items is exactly the shape that grammar
exists to stop. Progress and Sort both folded into the ⋯ menu, and the code says what that
cost:

> Progress is demoted from one tap to two.

That was the right call for Sort, which is a two-state flip that isn't even persisted. It was
the wrong call for a **destination**. ADR 0117 un-deferred this screen on an explicitly stated
retention argument — *"a stats surface nobody can see produces no signal about stats"* — and
then shipped it behind a control that gives no sign a destination is inside it.

## Decision

**1 — The screen is the `Practice log`.** `navigationTitle`, the manual, and the view type
(`PracticeProgressView` → `PracticeLogView`, in `Features/PracticeLog/`).

The name states what the thing is: a log, kept by the app, of practice that happened. It carries
no direction and so cannot report the absence of one. It also makes the user-facing word agree
with `PracticeLog` and `PracticeRun` underneath, which have been the internal names for this
data since 0117 Slice 1 — the app has been calling it a log in code and *progress* on screen for
three weeks.

**2 — It is reached from a row on the Journal, above the timeline, and leaves the ⋯ menu.** The
menu keeps Sort alone. One door, not two: a row and a menu item a few centimetres apart on the
same screen is redundancy, not the two-doors pattern of ADR 0163, which is about reaching one
destination from the *different places you need it*.

**3 — A plain row, not a live summary strip.** The strip — this week's minutes on the Journal,
tapping through — is ADR 0117's deferred two-tier "promise / payoff" design, and it was the
tempting option. It is declined here for two reasons. It puts a permanent number above a
timeline whose entire content is words, competing with the thing the screen is for; and it hands
a fresh install a zero to read before it has read anything else, which is the wall-of-zeros
problem 0117 named and designed around. The row names where the counting lives and says nothing
about how much of it there is.

**4 — The row hides while a search is running.** A search is a question about the timeline, and
a fixed navigation row is not part of the answer — it would sit above `No matches` offering
somewhere else to go.

**5 — It stays on the free side.** The Journal is free forever (ADR 0144), and this row is
inside it. Stated because the obvious alternative — moving the screen to the Practice hub — does
not preserve this; see *Alternatives*.

**6 — "Log" stops being a verb in journal copy.** `JournalSheet`'s empty states said *"Log a
goal, a breakthrough…"*; they now say *"Write down…"*. One word cannot be both the noun for
minutes the app records by itself and the verb for a sentence the player types.

**7 — Shot slugs do not move.** `journal/progress` and `reference/progress` keep their names. A
slug is an **id**: renaming it orphans every already-captured frame that names it, and Phase 5
holds 89 captured markers whose re-shoot costs a device erase per pass. The manual page file is
renamed (`journal-and-progress.md` → `journal-and-practice-log.md`) because a page id is
referenced only from prose that is being edited anyway.

**8 — `PracticeProgress` keeps its name.** The pure summary type in `Core/Stats/` is *not*
renamed, because `PracticeLog` in the same directory is already taken by the windowing layer
beneath it. The screen was renamed; the two pure types under it were not, and the doc comment on
each now says so.

## Consequences

**The shoot gets shorter and less fragile.** `testProgress` → `testPracticeLog`, and the ⋯ hop
comes off the path. That hop was the shoot's *second recurring failure* — the button found, the
event synthesised, and the menu never opening — and it is the same hop that a toolbar `Menu`'s
items are known not to resolve through on CI's older Xcode. Removing a menu from a capture path
removes a documented class of CI-only failure from it. The retry stays: the row is still an
unguarded tap, which is the shape that recurs.

**ADR 0155's toolbar resolution is half reversed, deliberately.** Its reasoning — three bare
trailing items is too many — stands, and the toolbar still carries two. What is reversed is the
conclusion that a destination could live in the overflow at all. The general rule this settles:
**a menu may hold verbs and settings; a place needs a surface.**

**`JournalTabView` gained a file, not lines.** The row lives in
`JournalTabView+PracticeLog.swift`, the same 400-line-cap split as `+Deletion`, which is why
`showingPracticeLog` is not `private`.

**Nothing about the screen's content changed.** This week / This month / All-time, the long-term
goal echo, and every deferral 0117 holds — the year tier, the wrapped card, streaks, the weekly
goal, the `PracticeStatsCard` evolution — are exactly where they were. This ADR moved a name and
a door.

## Alternatives considered

**Rename it `History`.** The first proposal, and the reason this ADR exists. It fails on a
collision the app already has: *history* is the **umbrella** over both halves of this space —
ADR 0100 defines the Journal against the Toolkit as "impersonal *reference* while a journal is
personal *history*", and the manual's own sentence uses it for the timeline and the counted-up
view together. Naming one half *History* takes the word the other half was defined by. *Practice
log* names a half without claiming the whole.

**Move it to the Practice hub.** The other half of the original proposal, and the one that
breaks something real: the Practice destination is Pro-gated at the Home card
(`proGated(.practice)`), so a free player never reaches `PracticeView` at all. Moving the screen
there paywalls a player's own record of their own practice, contradicts ADR 0144's free-forever
promise for this material, and inverts 0117's stated reason for shipping the screen — fewer
people would see it after the move, not more. The discoverability complaint that motivated the
move was real, but its cause was the ⋯ menu, not the Journal, and decision 2 fixes it where it
lives. A *second* door from Practice remains available later; a *replacement* door does not.

**A fourth segment in the scope picker — `All` / `Notes` / `Takes` / `Log`.** The picker is a
filter bound to `JournalTimeline.Scope`. A push wired into it returns from the destination with
the segment still selected and the timeline showing something else — a control that reports a
filter it is not applying. Same shape as the shared-picker trap this repo has already been bitten
by.

**Leave the name and only un-bury it.** Cheaper, and it fixes the complaint that was actually
felt. Declined because the name is the part that will keep costing: every future measure added to
this screen has to be argued against a title that promises a verdict, and that argument was
already had once, in 0117, over whether streaks could live here.

## Related

- `docs/manual/journal-and-practice-log.md` § The practice log — the user-facing account.
- `docs/manual/reference/tools-and-journal.md` § `Practice log`.
- `PocketUITests/ManualShotsUITests.swift` — `testPracticeLog`.
