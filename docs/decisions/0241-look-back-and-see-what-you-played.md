# ADR 0241 — Look back, and see what you played

- **Status:** Accepted. Built on `pocket-353-practice-log-look-back` (2026-10-02); the store upgrade is
  checked on the simulator and on a device. Still owed: the Practice log figures in the reshoot
  (Consequences).
- **Date:** 2026-10-02
- **Amends:** ADR 0117 — *This week* and *This month* were the current week and month and nothing
  else. They now page back through every week and month since the first run (D1, D2), and each gains
  *What you played* (D3, D4). The song row's "no `unitUID`, give `Song` a `uid` if per-song history is
  ever wanted" is answered without a `uid`: a run carries its song's `sourceID` (D5). Everything 0117
  held back stays held back: no streaks, no weekly goal, no days-active denominator, no week-over-week
  delta, no year tier (D7).
- **Relates to:** 0070 (never grades — ranked by minutes, nothing marked) · 0176 (the screen's name,
  unchanged) · 0239 (Red Moon counts nothing, which is half of why D3 does not time screens) · 0181
  (the archive, which carries both new fields without a `schemaVersion` bump) · 0189 (additive optional
  fields stay ordinary work) · 0151 (a log row outlives its unit, which is why D5 keeps a name)
- **Schema:** additive. Two optional `String`s on `PracticeRun` — `songSourceID` and `unitLabel` — with
  no declaration default, so a lightweight migration fills existing rows with `nil` (CoreData 134110
  exempt). Not lossy. Mirrored on `SessionRecord`, so the export carries them.

## Context

Tomisin, on 2026-10-02, with a screenshot of the Practice log taken that afternoon: *"right now users
can only see their progress for the current month but there's no way for them to look back."*

The screenshot showed the problem better than the sentence. It was Friday 2 October. *This week* read
300 minutes over four days; *This month · October* directly beneath it read **0 minutes, 1 day**, with
**Longest day: Friday 2 Oct · 0 minutes**. The week had begun on 28 September, so nearly all of it fell
in September — and September, the month holding most of the player's 11 hours 48 minutes, could no
longer be seen anywhere except folded into the all-time total. Every month opens like that.

The second ask was to tap a day and see *"the features you spent the most time on"* — song library,
practice, metronome — and then the things inside them. The log can't answer that. It holds finished
practice runs: exercise, loop, ear training, improvising and play-along. It has never had a row for
browsing the song library, using the metronome on its own, or tuning. What every row *does* say is
its kind and which unit it was, which answers the question a player is actually asking: what did I
play?

The proposal was walked through as a working mock first (an artifact, accepted the same day), and
this records what was built from it.

## Decisions

### D1 — Every week and every month since you started

Both sections open on the current period, as they always have, and page back one calendar period at a
time to the week or month holding the first run. Nothing before it (an empty page you can keep
scrolling to reads as missing history) and nothing after now.

**Calendar periods, never rolling windows.** *21–27 Sept* is a week the player can name and come back
to. "The last 30 days" is a different set of days every morning, so there is no page to return to, and
it would quietly cure the empty-October problem by hiding where months begin. The fix for the empty
month is one swipe to September, not a window that never starts.

`PracticeLogPages` walks the periods (oldest first, the current one last) and each page is read with
the same `PracticeProgress.week` / `.month` call the current period has always used, handed a date
inside it. No boundary arithmetic is written twice.

A past page says *Nothing logged that week.* where the current one says *Nothing logged this week yet.*
The header names the period: *This week* and *This month · October* for now; *21–27 Sept* and
*September* behind it, with the year when it is not this one.

### D2 — Arrows as well as the swipe, and only the chart pages

Each section header carries ‹ and › and, once you have left the current period, a *This week* / *This
month* button back to it. A swipe can't be seen, so nobody finds it untold, and VoiceOver needs a control
to land on. Week and month page independently.

**Only the chart travels with the swipe.** The figures above it and *What you played* below it follow
the page that settles. A paging scroll view takes the height of what it holds, and those parts vary in
height from one period to the next, so carrying them inside the page would make the whole screen jump
on every swipe. The chart is the same height in every period — which is why **the month grid now always
keeps six rows**, the most any month needs: October fills five, November 2026 six. The grid's *Less →
More* key reads the same for every month, so it sits under the pager, drawn once: inside it, the lazy
strip's neighbouring months each put another copy in the accessibility tree, which the shoot found by
failing on an ambiguous `More`.

A horizontal `ScrollView` with paging rather than a page-style `TabView`: it is lazy, so years of history
cost only the pages on screen, and it sizes to its content instead of needing a fixed height.

### D3 — What you played, by what was played — not by where in the app

Under each period, the period's practice grouped by kind — *Exercises*, *Loops*, *Ear training*,
*Improvising*, *Play-alongs* — and inside each kind by exercise, loop or song, largest first at both
levels. A loop shows its song underneath it, so a song's time is visible through its loops.

**Rejected: time by part of the app** (song library, practice, metronome). The log has no rows for most
of those and was never meant to. Building it would mean timing how long screens are open — screen time,
a usage measure, the kind of counting ADR 0239 removed from the app the same day. "Which parts of the app
get used" was the builder's question; "what did I play" is the player's, and the data already answers it.

**A list with thin bars, not a chart.** A day usually holds one to four runs, too few marks for a chart
to say anything a list doesn't. One scale across both levels: the largest group is full width.

### D4 — A tap narrows the list; it does not open anything

Tapping a practised bar in the week chart or a practised cell in the month grid narrows that section's
*What you played* to the day, and a chip naming the day takes it back to the whole period. Tapping the
same day again does too. Paging away lets the choice go, so a day from one week is never left selected
over another.

Not a sheet: a tap that filters a list already on screen beats raising a second surface with two rows
in it. Groups open in place onto their items, and start closed — five rows keeps the month grid within
reach.

### D5 — A run records its song and its name

Two optional fields on `PracticeRun`, written by every completion seam through `PracticeLogWriter`:

- **`songSourceID`** — the song a run was played from, by `Song.sourceID`: set on a **play-along**, which
  has no `unitUID` because `Song` has no business `uid`, and on every **loop-based** run (loop, ear
  training, improvising). The archive already keys songs this way (`songSourceID` on a routine item or a
  take), so `Song` did not need a `uid` and the store's aggregate root is untouched.
- **`unitLabel`** — the exercise's or loop's name, or the song's title, when the run was logged. A blank
  name is stored as `nil`.

**The live name always wins.** A unit still in the library is listed under its current name, so a rename
shows at once. `unitLabel` is only for the unit that is gone — the log keeps a deleted exercise's minutes
on purpose (ADR 0117, deletion-safe), and without the name they could only be called "a deleted
exercise". A deleted unit that kept its name is listed by it, marked *Deleted*.

**Old rows are honest about what they don't know.** Every play-along logged before this shipped shares
one row, *Song not recorded*, because the log cannot tell them apart; a unit deleted before this shipped
is *A deleted exercise* / *loop* / *song*. Neither field can be backfilled — the information was never
written — so they help only runs logged from this release on. That is why they shipped in the same
change rather than after the screen.

### D6 — Under a minute, and a longest day worth stating

The log keeps any run of a second or more, so a day can count as active on twenty seconds and round to
zero minutes. **Practice that rounds to nothing reads "<1 minute"**, never "0 minutes" beside "1 day" —
in the section figures, over the chart's busiest bar, in the list and to VoiceOver. Nothing at all
still reads "0 minutes", which is true. One rule, `PracticeLog.MinutesFigure`, rounding once from summed
seconds like everything else in the log.

**"Longest day" waits for a second active day.** With one, it names the only day there is and repeats
the figures above it.

### D7 — Still no comparison, and the scale stays the month's own

Paging lets the player put two periods side by side if they choose to. The screen never does it for
them: no week-over-week delta, no "vs last month", no ghost of last week behind this one. ADR 0117's
reason stands — each would make a quiet week read as a verdict.

The grid is still shaded against **its own month's** longest day, never a fixed scale (a fixed number
would be a daily target by the back door, as 0117 said). Paging makes that relativity visible — a
20-minute day in a quiet month shades as dark as two hours in a busy one — so it has to be stated, and
it is: the *Longest day* line above the grid *is* the scale, which is why the key under it was **not**
given a second copy of the same number. The mock had both, and they said one fact twice.

## What stays out

- **Rolling windows** (D1) and **time by part of the app** (D3).
- **The metronome.** Practising with only the metronome writes no row, so it is not in *What you played*.
  Whether open-ended metronome time counts as practice is the prior question, and it is the same one
  that left a looping play-along unlogged — no honest length. **Not decided here.**
- **"68 minutes of this was in Morning Routine."** Runs inside a routine already carry `routineUID`, so
  it is possible; it is not built, because nothing yet says it is wanted.
- **This year, streaks, a weekly goal**, and the rest of 0117's deferred list.

## Consequences

- **A `@Model` change, additive.** Two optional fields, no default, not lossy. In-memory tests cannot see
  a migration, so **a store-upgrade check is owed**: install the previous build with a populated log,
  install this one over it, and confirm the log opens with its history intact and old rows unlabelled.
- **The archive carries both fields** through `SessionRecord`'s synthesised `Codable`. Both are
  `Optional`, so an archive written before them decodes (`decodeIfPresent`) — tested by encoding a real
  archive and deleting the keys. `schemaVersion` does not move (ADR 0181).
- **Verified on the simulator, 2026-10-02.** A store written by `main` (8783f88) with 37 seeded runs,
  then this branch installed over it: the app launched and stayed up, `ZPRACTICERUN` gained
  `ZSONGSOURCEID` and `ZUNITLABEL`, all 37 rows survived with both `NULL`, and the store's first
  transaction predates the upgrade, so it is the same store migrated rather than a new one.
- **Verified on a device, 2026-10-02** (iPhone 16 Pro, iOS 26.6), over the store a real player had been
  writing since 31 July: the app launched and stayed up, the store pulled off the phone has both new
  columns, and all 138 runs — 31 July to 2 October — are present, every one with both fields `NULL`.
  ADR 0036's migration crash was device-only, which is why this one was not left at the simulator.
- **The Practice log screen is longer.** *What you played* sits under both charts, so the month grid no
  longer fits in the first frame with the week chart. The manual's shoot (`testPracticeLog`) asserted
  exactly that fit; it now captures the week and the grid as two frames. **Figures owed in the reshoot.**
- **The seed writes both fields**, so the shoot and previews show named rows.
- **Home's *This week* strip is unchanged.** It shows the current week only, by design (ADR 0208).
