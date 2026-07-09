# Practice planner — review-refinements build plan (2026-07-09)

Post-testing refinements from a design review of the shipped planner (Slices 1–4,
merged via PRs up to #106). This is **not** greenfield — it tunes what exists. Pairs
with `docs/plans/planner-build-plan.md` (the cold-start plan) and the routine
substrate (ADR 0066).

Next branch: **`pocket-113-...`** (pocket-112 is the latest).

---

## 0. Concept lock — "goals once, sessions adapt"

The review surfaced a naming/framing tangle that resolved to: **the user defines goals
once; every future session adapts from those goals + practice history, with zero
re-entry.** Key realisation: **the engine already does this.** `Goal` is a persistent
`@Model` (with `isMet`); `PracticePlanner.planGoalSession` regenerates fresh each call
from `deriveCandidates(goals, library, now)`. The gap is **UX surfacing**, not
architecture.

**Naming (locked):**
- **Today's Session** — the goal-adaptive session (goals set once, drives every run).
  Keep this name (already `PlannerView`'s nav title). *Not* "Smart Routine" (gimmicky)
  and *not* "Today's Focus" (too narrow).
- **Quick Session** — the goal-less, due-ranked throwaway (`planQuickSession`). Keep.
- **Rename only the button verb:** `PracticeView.swift:67` "Build today's session" —
  reframe to something goal-oriented and non-clashing with Quick (e.g. "Start today's
  session" / "Today's session"). The *object* is right; the *verb* mislead.

---

## Slices (priority order)

### R0 — Keep-awake bug (FAST, ship first)
The screen slept during a chord exercise. `keepAwakeDuringPractice()` (ADR 0050,
`Pocket/App/KeepAwake.swift`, default ON) is applied to `SongPlayAlongView`,
`ExerciseRunView`, `LoopRunView`, `WaveformPracticeView`, `MetronomeView` — but **NOT**
the routine session player (`RoutineSessionPlayer` / `RoutinePlayerView`) nor whatever
chord-exercise surface the reporter hit. Add the modifier to those surfaces; confirm
the chord exercise path. Device-test (previews won't show the idle timer).

### R1 — Home hub, finalised layout (2026-07-09)
Top → bottom (all confirmed):
1. **Toolbar:** Settings moves to **top-left** (was the top-right `gearshape`); a **green
   filled "Add a song"** button (`plus.circle.fill`) goes **top-right** — this replaces
   the full-width bottom `addSongButton`. Keep it clearly green so it still reads as the
   primary create action.
2. **"Ready to practice?"** — add the `?` (`HomeView.swift:99`).
3. **Start today's session** — the primary CTA, in the slot the dropped progress strip
   vacated. (Open question resolved: **yes, on home.**)
4. **Jump back in** — the last *song*, unchanged (`HomeView.swift:229`, no new
   persistence).
5. **Song library strip** — the inline "Your songs" list + its "See all" + bottom
   Add-button **collapse into a single nav strip** matching the Metronome/Practice
   pattern (icon + title + subtitle + chevron → `LibraryView`). **Identity: blue** (the
   ADR 0023 song-surface hue) as a dedicated baked `library` token +
   `libraryCardWash`/`libraryCircleWash` — **bake the assets, no opacity blends** (ADR
   0062 lesson). **Icon: `music.note.list`** (collection); `music.note` (eighth note) the
   cleaner fallback. Note: the song rows' left-bars are **mastery-tier** accents
   (`SongCard.accentColor`), not a song hue — blue is free to mean "the songs place".
6. **Metronome strip** — existing (teal).
7. **Practice strip** — existing (plum).
8. **Recent routines rail** — last 3 routines *practiced*. Needs additive
   **`Routine.lastPracticed: Date?`** written on run (`Routine` has only `dateAdded`;
   `RoutineSession` is an ephemeral cursor, not history). **Design the distinction:** a
   recent routine **replays exactly**; **Today's Session regenerates adaptively** from
   goals + history.

Result: a **blue · teal · plum** three-strip nav triad (songs / tool / content), distinct
hue families; keep the three washes at equal low intensity so they read as a set. The
**"Your progress" strip stays dropped** (`PracticeStatsCard` removed from the hub).

### R1b — Name the generated session (surface, don't rebuild)
Naming **partly exists**: `RoutineDetailView` has a "name this session" rename alert +
`TextField("Routine name")`, but it's **undiscoverable** and wired for the **Quick**
save-provisional path. **Verify/extend it to the Today's Session (goal-driven) flow** and
surface it (a visible name field / rename on the generated-session review card) — so the
enriched routine "they'll keep going back to" can be named. Low effort.

### R2 — Goal ↔ skill ↔ routine clarity + full-catalog skill search (DECIDED: full-catalog)
The user (and users) are confused by the goal/skill/routine relationship.
- **Full-catalog search** (locked): `GoalEditorView` currently offers only the
  template-seeded `offeredSkillIDs`. Add a search/browse over the **whole**
  `TechniqueTaxonomy`, suggestions as a shortcut not a ceiling. **No free-text custom
  skills** — an orphan skill with no matching exercises silently schedules nothing,
  which is *more* confusing. Full canonical catalog only.
- **Make the linkage visible:** on the goal editor, plain-language copy — "Exercises
  tagged with these skills show up in your sessions" — plus a live **"N exercises
  match these skills"** count so the payoff is concrete.
- **Label each session block with the goal it serves** ("for: Build speed") in the
  routine detail / player, closing the loop end-to-end.

### R3 — Session-length accuracy + repeat units
Answers "how do we enforce 15/30/60, and can users repeat units?"
- **Accurate per-exercise estimate:** `PracticePlanner.estimatedMinutes(for: Exercise)`
  is a flat `RoutineBudget.defaultFocusedMinutes` today (the plan doc flags the ramp
  estimate as a later refinement — this is that refinement). Derive from the
  `CommandRamp` staircase: pick a convention (N bars per tempo step) →
  `Σ (bars × beats-per-bar × 60 / BPM_step)` across the ramp. Non-ramp exercises keep a
  default.
- **Repeat units:** `RoutineItem` has **no reps field** today. Add `reps: Int = 1`
  (additive → lightweight migration). Session length =
  `Σ (block_duration × reps) + rests`. Let users set reps per block; the generator uses
  reps to pack toward the budget.
- **Soft target, not a hard cap:** pack toward the preset budget, show a **live "~28
  min" estimate** as it builds; never hard-cut mid-exercise.

### R4 — Routine block preview + audio preview + manual advance — SHIPPED (pocket-116, A+B)
- **Tap a block → preview + edit tempo** (`RoutineDetailView`). Make blocks inspectable. — SHIPPED:
  tapping an exercise block (read-only) opens `ExerciseDetailSheet`, whose `ExerciseTempoSection`
  makes the **command** nudgeable (committed via the run screen's `promoteCommand` setter — no
  divergent write path, ADR 0057).
- **5–10s metronome audio preview** — SHIPPED as a steady command-tempo click (`CommandTempoPreviewPlayer`,
  own engine, ~6s auto-stop) in `ExerciseTempoSection`. Chose a steady command click over a
  time-boxed ramp: predictable length, and a 6s slice of the real ramp wouldn't reach the target
  anyway (the full working→command→reach climb stays on the run screen).
- **Manual advance by default, with an on/off setting.** — SHIPPED: a finished block lands on a Done
  screen unless `routineAutoAdvance` is on; a Skip always bypasses. **Pre-exercise preview (item 15)
  was folded into the existing manual-start behavior and dropped as a distinct surface** (decision
  2026-07-09): with auto-start off (the default) a block already sits on its run screen previewing
  the drill + staircase/content before Start — that *is* the live-routine-scoped pre-exercise preview.
- **Post-exercise completion flow (NEW).** Today `RoutineSessionPlayer` **auto-advances**
  (`RoutineSessionPlayer.swift:28`, via `RoutineRunContext.onFinished`); only the
  whole-routine end shows a summary (`.finished`). With manual advance, a naturally-
  finished exercise shows a **Done screen** (per-block — *not* the end-of-routine
  summary) that is a **single surface**: completion beat + **optional mastery tap** +
  **inline optional journal-note field** + **Continue / Finish**. This **collapses** the
  earlier separate two-option screen — journalling no longer needs a whole new screen
  (user, 2026-07-09).
  - **Feasibility: yes, groundwork exists.** The commit path is already a reusable static
    — `JournalOwner.add(to:text:kind:context:)` builds the entry via the
    `forLoop`/`forExercise` factories and **auto-snapshots the owner's context** (an
    exercise entry snapshots `commandBpmAtEntry`), so Done is the *ideal* snapshot moment.
    Inline journal UI has precedent (`JournalPreviewSection` embeds in a run-screen body).
    Work = a **compact inline composer** (default kind `.note`, one text field) calling
    `JournalOwner.add` for the exercise owner — not the full `JournalSheet`.
  - **Apply the P3 lesson:** one primary **Continue/Finish** commits **both** the mastery
    (if changed) and the note (if non-empty) in a single action — **no competing "Add
    entry" button** (that's exactly the Journal confusion P3 fixes). Keep it minimal: no
    kind picker / snapshot readout here (those stay in the full journal); handle the
    keyboard so Continue stays reachable.
  - **Mastery rating placement.** Self-rated mastery lives in
    `ExerciseDetailSheet`/`ExerciseProgressSection` today; the fast optional tap on the
    Done screen keeps the planner's dueScore (`1 − mastery/5`) learning by default.
    Exercise journal entries carry **no** mastery in their snapshot — mastery writes to
    `Exercise.mastery`, the note writes a `JournalEntry.forExercise`; two commits, one tap.
  - **Edges:** "Continue" advances to the next *block* (may be a rest → next exercise's
    preview); the **last** exercise reads **"Finish"** → end-of-routine summary;
    **routine-only** (`routineContext != nil` — standalone = Done + inline note, no
    "next"); a deliberate **Skip** bypasses the Done gate (natural completion only);
    **auto-advance ON** bypasses the screen.

### R5 — Strumming / chord audio references
During a chord/strumming exercise **preview**. Constraints: Apple Music audio can't be
tapped (DRM, ADR 0001); no grading (ADR 0070); assets must be DRM-free / original
(content-strategy rule). Start with a **synthesized strum pattern** via the metronome
engine (accented down/up pattern — pattern reference, not tone); add recorded original
clips only if pattern-only tests as insufficient.

---

## Separate track — player polish (own branch, NOT the planner)

### P1 — Player layout + transport fold + minimap
The top of the practice screen wastes vertical space — reclaiming it is the highest-value
item here (the biggest offender in the screenshot).

**P1a — Compact header** (`SongStrip`, `WaveformSections.swift:22`). Today it's a
two-column `HStack`: title+artist (left) vs. mastery stars + duration (right). Restack
into a **single left-aligned vertical block — title, artist, proficiency (mastery
stars)** — so the header shrinks and the waveform + loops/markers move **up**. **Remove
the song length** (`timecode(song.duration)`, lines 60–62) from the card entirely (the
"unrated song shows its length" fallback goes with it). `song.duration` stays used for
marker/minimap math — just not displayed here.

**P1b — Fold transport on scroll** (`WaveformTransportBar.swift`), **Setting default
OFF**. The Safari-toolbar move, with guardrails because on a practice tool play/pause is
the one control you must never hunt for mid-take:
- collapse to a **slim pill (play/pause + scrub)**, not a full disappear;
- reappears on scroll-down, and whenever a **loop/marker is activated** (until the next
  swipe-up);
- **tap-anywhere to peek it back**; **respect Reduce Motion**;
- keep the gesture logic **simple — threshold + debounce** (touch directional-scroll
  detection is fiddly).

**P1c — Minimap on/off Setting, default ON** (`WaveformMinimap.swift`). No other notes.

P1b + P1c add two additive `@AppStorage` toggles to the Settings screen (same shape as
`keepScreenAwake`).

### P2 — Marker labels on playhead hover
- Treat "hover" as **playhead proximity**; show **one active label max** (the marker the
  playhead owns), fade in/out. Bunched markers never stack because only the current one
  lights.
- **Zoomed-out overlap → cluster into a count chip** ("3"), expand on tap; individual
  labels only at sufficient zoom (ties into page-mode zoom). Reuse loop lane-stacking
  (ADR 0018) if two labels ever coexist.

### P3 — Journal "Add entry" button
Make it a **full-width primary (filled)** button at the bottom of the New-entry card,
**disabled until there's text**; optionally rename "Done" → "Close" so the two verbs
stop competing.

---

## Coverage map — every review point → slice (audit 2026-07-09)

| # | Review point | Slice |
|---|---|---|
| 1 | Marker labels on playhead hover + clutter mitigation | **P2** |
| 2 | "Ready to practice" → "Ready to practice?" | **R1** |
| 3 | "Your progress" strip — DROPPED (removed from hub) | **R1** |
| 4 | "Your songs" → "Song library" | **R1** |
| 5 | "Jump back in" stays last song (reverted) | **R1** |
| 6 | Last 3 routines practiced (recent-routines rail) | **R1** |
| 7 | Name the generated session | **R1b** |
| 8 | Player: reclaim vertical space, stack song/artist/proficiency | **P1a** |
| 9 | Player: transport fold on scroll (default off) | **P1b** |
| 10 | Player: minimap on/off (default on) | **P1c** |
| 11 | Journal "Add entry" prominence vs "Done" | **P3** |
| 12 | Routine: enter each block → preview + edit tempo | **R4** |
| 13 | Metronome exercises: 5–10s command-tempo audio preview | **R4** |
| 14 | Manual advance (not auto) + on/off setting | **R4** |
| 15 | Pre-exercise preview, setting scoped to live routine | **R4** |
| 16 | Rename "Build today's session" (naming clash) → Today's Session | **R0 concept** |
| 17 | Session-length enforcement + repeating units | **R3** |
| 18 | Choose skills outside suggestions (full-catalog) | **R2** |
| 19 | Make goals ↔ skills ↔ routine clearer | **R2** |
| 20 | Phone sleeps during routine/exercise (chord bug) | **R0** |
| 21 | Strumming audio references in chord preview | **R5** |
| 22 | Remove song length from the header card | **P1a** |
| 23 | Post-exercise Done screen: optional mastery tap + inline note + Continue | **R4** |

Every point is placed. Player layout (8–10) sits in the P-track by design — it touches no
planner logic and can branch in parallel; it was not dropped.

## Suggested tomorrow scope
**Branch `pocket-113`: R0 + R1 core + R1b.** R0 (keep-awake bug) is a real defect. R1
core = the label renames ("Ready to practice?", "Song library"), jump-back-in stays, the
**recent-routines rail** (+ `Routine.lastPracticed`), and surfacing session naming (R1b).
This is where "goals once, sessions adapt" becomes visible; the home layout is now fully
specified above (toolbar move, Start-today's-session CTA, blue Library strip w/ baked
washes + `music.note.list`, recent-routines rail). Then R2 (skills clarity + full-catalog)
next branch, R3 after. Player polish (P1–P3) is an independent parallel branch.

## Docs / ADRs when built
- R2/R3 touch selection + model → update ADR 0015 extension + `PROJECT.md` (reps field),
  `docs/architecture.md`.
- R4 manual-advance + preview settings → note in ADR 0046 lineage or a small ADR.
- R5 audio references → its own ADR (rights + synthesis approach).
- Every slice: `CHANGELOG.md`; move nothing to "done" until device-tested.
