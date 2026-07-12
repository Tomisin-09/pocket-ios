# Changelog

All notable changes to Pocket are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); this project is pre-release.

## [Unreleased]

### Added
- **Seven more scales in the scale library.** The **Scale** picker now offers the five remaining modes of
  the major scale — **Dorian, Phrygian, Lydian, Mixolydian, Locrian** (Ionian and Aeolian already ship as
  *Major* and *Natural Minor*) — plus the two **bebop** scales, **Bebop Major** (the major with a chromatic
  ♯5) and **Bebop Dominant** (Mixolydian with a chromatic ♮7). Every one is a real CAGED box in your chosen
  key and position, correct by construction, with the modes also available as **3 Notes / String** runs.
- **Scales can now span the neck, not just sit in one box.** A scale drill gained a **Layout** choice.
  Pentatonics offer **Extended** — one long diagonal run that links three boxes up the neck with a
  same-string slide into each new box, with the board following the climb and dimming the boxes you're
  not currently on. There are the **two** canonical extended fingerings (the *A shape*, sliding on the A
  and G strings, and the *D shape*, sliding on the D and B strings); both slide by a clean whole-step,
  and **Up and back** retraces the diagonal on the way down. Major and minor scales offer **3 Notes /
  String** — three tones on every string from the low E to the high e, the even,
  alternate-picking-friendly shape that covers the whole neck. Every existing scale stays a single-box
  run exactly as before, and two new starters ship: *A Minor Pentatonic — Extended* and *G Major — 3
  Notes Per String*.
- **Scale and arpeggio positions now read as CAGED shapes.** The Position control in the scale and
  arpeggio editors shows the shape letter you actually recognise — *E / D / C / A / G shape* — instead
  of a bare "Position 1…5".
- **A climbing run now highlights the position you're on.** When a warm-up or picking run climbs the
  neck in several passes, the board keeps the pass you're currently playing at full strength and gently
  fades the other passes back — so your eye locks onto the hand position that matters right now while the
  rest of the run's shape stays visible as context. A single-pass run, and every scale or custom drill,
  looks exactly as before.
- **The fretboard now follows your hand up the neck.** When a warm-up or picking run climbs past a
  comfortable board (about eight frets), the board no longer crams the whole neck into a sliver — while
  the run walks, it shows a hand-width window that *follows* the sounding note. It only ever scrolls
  when the note actually reaches the edge, and when it does it favours showing the frets *coming up* over
  the ones behind — so it shifts rarely (just a couple of times over a whole neck-climb) and stays easy to
  track. A gentler climb that already fits the board, and every short run, stays a full static diagram.
- **Warm-up and picking runs can climb the neck and go diagonal.** A fretboard run (the generative
  warm-up / picking / legato editor) gained a **Movement** section, tucked under a disclosure so a
  plain warm-up is still four taps. Inside: **Shift up after each run** climbs the pattern a few frets
  each pass over a **Passes** count (a chromatic-climb-up-the-neck), **Stagger per string** lands the
  pattern higher or lower on each successive string (a diagonal), and — when a run comes back —
  **Coming back** picks how the descent is fingered: *Retrace* (today's strict path reversal, each
  string 4-3-2-1) or *Restate* (re-state the ascending 1-2-3-4 on each string walking back). A shift
  that walks the hand up one string is drawn as a **slide arrow** on the board — a static teaching cue
  that also reads under Reduce Motion. All controls default off, so every existing run is unchanged.
- **Finishing a loop practice run now asks how it went — and offers to bump it up.** When a loop's
  training run reaches the top and finishes on its own, you land on the same completion screen as an
  exercise: rate how clean it felt (optional), jot a note (optional), and — if you summited above the
  tempo you own — an opt-in **"I own this now — move command up"** toggle, all saved together. Before,
  a finished loop run just dropped you back on the setup screen with nothing recorded.
- **Practice a loop straight from its edit sheet.** Once a loop has a command tempo set, its edit sheet
  (hold a loop on the waveform) shows a **Practice now** button that takes you straight into the loop's
  training run; finishing or backing out returns you to the waveform where you started.
- **Set how long you hold at command tempo.** The command plateau — the flat top of the practice
  staircase where you consolidate at the fastest tempo you own — used to be a fixed length. There's now
  a **Command** control in the Steps panel (on both exercises and loops), so you can make the hold shorter
  or longer: an exercise holds in bars ("≈ 16 bars"), a loop in passes through the region ("≈ 4 passes").
  It appears everywhere the other step controls do — the standalone run screens and inside a routine. (The
  phase is labelled **command** throughout — on the staircase chart, the step control, and the summary —
  rather than the earlier "dwell" jargon.)
- **Repeat a routine block.** In the routine editor, tap a block while editing to set how many times
  it repeats (1–9), so you can say "run this warm-up three times before moving on." A repeated block
  shows a small `×N` badge in the routine, and the estimated length accounts for it. In the player, a
  repeated block runs back-to-back with a **"Rep 2 of 3"** counter on the progress strip; the Done
  screen (mastery + note) appears only after the last rep, and **Skip** jumps past any remaining reps
  to the next block.
- **Set your own target tempo.** The **Reach** — the goal speed above the command tempo you own — used
  to be fixed at an automatic "a little faster." Now you can edit it directly, on both exercises and
  loops: nudge or type the Reach in the run setup (Practice Settings) or the exercise's Tempo section,
  and it sticks. A **Reset to auto** button appears whenever you've set a custom goal, and the caption
  switches from "auto · +X" to "custom goal" so you can tell at a glance. A target always sits above the
  tempo you already own — promoting your command up to (or past) a custom target automatically hands the
  reach back to auto above your new command.
- **Import a whole batch of songs at once.** The library's **+** now lets you pick several audio files in
  one go instead of one at a time. Each file's waveform is decoded off the main thread with an
  "Importing N of M…" progress card, so the app stays responsive, and files that can't be read (empty,
  DRM-protected, unsupported) are skipped without aborting the batch — the good ones still import, and a
  short summary tells you which were skipped. A confirmation alert reports what imported ("Songs added —
  Imported 3 songs"), and importing from the **home screen** also drops you into the song library
  afterwards so you can see what landed; importing from the library stays put.
- **A tighter practice screen — more room for the waveform.** The song header is now a compact
  title / artist stack with the mastery stars beside it, and the empty navigation band above it is gone
  (a compact back button now sits inline with the title), so the whole cockpit rises toward the top of
  the screen; the song length (which duplicated the ruler/minimap) is dropped from the header, and the
  transport bar is a touch shorter. A new **Show minimap** setting (Settings → Transport, default on)
  hides the full-song overview strip under the waveform to give the waveform and loops even more room.
- **Marker labels surface as you play up to them.** As the playhead nears a marker, that marker's
  label floats as a small chip just below its triangle at the top of the waveform — one active label at
  a time (the nearest marker), so you read what a section is without opening the Markers panel. A new
  **Show marker labels** setting (Settings → Transport, default on) turns this off, keeping labels in
  the Markers panel only. When you're zoomed out far enough that marker triangles would overlap, they
  collapse into a single count chip (e.g. "3") instead of smearing together.
- **The Journal's "Add entry" is now a clear full-width button.** The composer's Add-entry control is a
  full-width primary pill, greyed out until you've actually typed something and filled in once there's
  text — so it reads plainly as the button to press rather than a faint list row.
- **Strumming exercises now sound their pattern.** A strumming or Strum & Chords drill's metronome —
  both in the block preview's **Hear the strum** button and **during the actual run** — follows the
  pattern's down / up / accent / mute rhythm (rests stay silent) instead of a plain click, so the audio
  matches the animated lane. The count-in stays a steady pulse so you can still count in. It's a rhythm
  reference, not the chord tone (the metronome click has no pitch). A **Strumming click follows the
  pattern** setting (Settings → Practice, default on) switches the run back to a plain steady
  metronome you strum the rhythm against; the preview's Hear the strum button always plays the pattern.
- **A routine block now finishes on a Done screen — manual advance by default.** When a block
  completes on its own it no longer jumps straight to the next one; it lands on a single Done screen
  with the completion beat, an *optional* mastery tap (pre-filled from the drill), an *optional*
  inline note, and one **Continue / Finish** that commits both in a single action. This collapses the
  old separate two-step reflection sheet. A new **Advance automatically** setting (Settings → Routines,
  default off) restores the old auto-advance; a deliberate Skip always bypasses the gate, and
  songs/rests (no journal) advance without an empty screen. Replaces the previous *Reflect after each
  block* setting.
- **Preview every routine block before you start.** Tapping an **exercise or loop** block in a routine
  (read-only mode) opens a read-only preview so you know exactly what you'll play and how: an exercise
  shows its content (fretboard / strum / chords) + tempo anchors + the training staircase and a short
  **command-tempo metronome preview**; a loop shows its source + speed + staircase and plays a few
  seconds of the **loop's actual audio**. Deeper tuning (nudging the command tempo) stays behind the
  exercise preview's **Details** button, committed through the same setter the run screen uses.
- **The Done screen shows what's up next.** After a block, the Done screen now previews the next
  exercise/loop (skipping past rests) so you know what you're continuing into.
- **Routines play straight through.** Because every block is previewable up front, tapping **Start** now
  runs straight into the first exercise (after the count-in) instead of waiting on a per-block preview.
  Turning *Auto-start blocks* off still makes every block wait for a manual start.

### Changed
- **The loop run's pre-run "promote" button is gone.** Promotion now happens *after* a run you actually
  completed (see the completion screen, above), not as a claim you tap beforehand — matching how
  exercises already work.
- **The home screen now leads with the brand colour.** Practice — the app's most-used space and the big
  "Start today's session" button — wears the brand **teal**, the Metronome moves to **plum**, and the
  Song library takes a warm **terracotta**, for a teal · plum · terracotta home. Mastery dots follow the
  brand teal. (Groundwork for a selectable "Blood Moon" terracotta theme, coming next.)
- **The exercise ⓘ info sheet is now purely for reading.** It's been reordered so the **description**
  comes first, then your **progress** (mastery, last practised), the **feel** (meter/subdivision), and
  the **training-routine shape**, with the template chip moved to the bottom. Tempo is **no longer
  edited here** — you tune the command and reach on the run screen (and, inside a routine, on the block
  itself) — and neither is the drill's **shape**: the finger pattern, scale, chords or strum lane now
  live behind an **Edit shape** button on the run screen (see below), so the info sheet only shows and
  lightly annotates what an exercise is.
- **Edit an exercise's shape right next to the board.** The per-template content editor — the finger
  pattern and reach of a run, the scale or arpeggio and its root, the chord progression, the strum
  lane, or a hand-placed fretboard grid — used to be buried inside the ⓘ info sheet. It's now a
  compact **Edit shape** control in the top-right of the board preview on the exercise run screen,
  opening a focused editor with its own live walk-through. It appears **only in the library**; inside
  a routine an exercise stays tempo-only.
- **The exercise ⓘ info sheet is leaner.** The redundant "Training routine" staircase preview is gone
  (you tune that staircase on the run screen, where it already lives), and the template row is tighter,
  so the sheet reads as description → progress → feel → template.
- **Reopen a recent routine to look before you leap.** Tapping a card in the home screen's **Recent
  routines** rail now opens that routine's **detail screen** (its blocks, with Edit and Start) instead
  of dropping you straight into the player. You can glance at what's in the session or tweak it first;
  the routine library's ▶ still starts a replay directly.
- **The one-shot "Watch" preview only shows when it's actually needed.** On the fretboard editors,
  Watch (a single walk-through of the shape) used to always be present. Now it **hides when
  "Animate exercises" is on** — the board is already walking continuously, so the one-shot is
  redundant — and **shows when animation is off or Reduce Motion is on**, where it's the only way to
  see the shape move. The motion-averse escape hatch stays exactly where it matters.
- **Inside a routine, an exercise no longer looks like the library editor.** Opening an exercise from a
  routine — whether previewing a block before you start or reaching it mid-session — used to show the
  *same* full run editor as the library (promote, Save, the journal, the meter picker, "Start
  training"), which made "the exercise in my routine" hard to tell apart from "the exercise in my
  library." Now the routine surfaces keep only the **Practice Settings** panel — the tempos and step
  granularity you'd actually tune per routine, collapsed by default — and drop the library-only
  affordances (promote, Save, journal, meter). The block preview writes changes straight through; a
  live-session block still runs its full ramp, count-in and staircase and commits any tweak when you hit
  Start. Promoting, saving and journaling still live in the library run screen, the one full editor.
- **The practice transport bar no longer shows a duplicate timecode.** When no loop was active, the
  transport bar's centre displayed the playback time — the same value already shown by the time bubble
  that rides the playhead on the waveform. The redundant readout is gone; the row keeps its height, so
  nothing shifts, and the playhead's time bubble still tracks as before.
- **"Promote" now comes after a run, not before it.** The pre-run "I own X now — promote" button on the
  exercise setup screen is gone. Instead, when a training run **finishes on its own** — you held the
  command tempo and summited the reach — you land on the **same finish screen a routine block uses**: a
  completion beat, an optional "how clean did that feel?" rating and note, and an optional **"Move
  command to {reach}"** toggle. Flip it and tap **Finish** and the drill steps up (saved right away);
  leave it off to keep the tempo where it is. The bumped-to value **defaults to the reach but is
  editable** — a −/+ stepper lets you set a custom command you feel you own (anywhere above your current
  command, up to the max). If there's nothing above your command to move to, there's no toggle — just
  the completion. It's an offer, never a score — the app still never grades how you played. Inside a
  **routine** the same toggle rides that Done screen (which now also has a top-left chevron to leave the
  routine); with auto-advance on (no Done screen) nothing is bumped.
- **One consistent way off the keyboard everywhere.** Every text field that the keyboard's Return key
  can't dismiss — the multiline note fields (finish-screen note, journal composer and editor, exercise
  description, song notes) and the number pads (tempo entry, metronome BPM, the automator's fields, the
  waveform BPM sheet) — now carries the **same checkmark button** in its keyboard bar to close it. The
  couple of fields that previously showed a text "Done" were switched to the checkmark so the affordance
  reads identically across the app.

### Removed
- **The greyed-out "Sound soon" button is gone.** The fretboard editors carried a disabled
  `speaker.slash` "Sound soon" button that advertised an audio preview with no backend — it did
  nothing. It's been removed. A real pitch audition is still planned; the underlying audio boundary is
  kept in place so it can slot in later without touching these editors.

### Fixed
- **The add-song button on the home screen is now a clean solid green.** It used to show a faint pale
  ring/edge (the iOS 26 nav-bar glass sitting behind it); that background is now suppressed so the green
  disc reads flush.
- **A scrub on the waveform lands where you let go, not on the nearest beat.** Dragging the playhead to a
  point *between* beats used to get yanked onto the pulse — with a dense beat grid, the playhead felt
  magnetized and you couldn't land it where you meant. A **scrub** now catches only the sparse landmarks
  (markers and saved-loop edges), dropping the beat grid, so a deliberate scrub between beats stays put
  while still catching a marker or loop edge you were aiming at. A quick **tap** is unchanged — it still
  jumps to the nearest structure, beats included — so "take me to that beat" stays one tap. This is the
  same rule the minimap already used; the two seek surfaces now share it. (ADR 0080)
- **The practice staircase's labels line up with their steps.** The `<n> BPM` signpost is meant to mark
  the command tempo (the wide dwell bar); when the **Dwell** was set to a single interval, the command
  bar was no longer the widest, so the label jumped to the warm-up bar and showed the warm-up tempo.
  It's now pinned to the command step by tempo, whatever the dwell length. The phase captions
  underneath were likewise on an even three-way split, floating off their unequal-width bars; each now
  sits **centred under the bars it names** — "warm-up" over the climb, "dwell" over the command bar, and
  "reach" and "back off" as **two separate captions** over the ascent and the descent (each omitted when
  that phase has no bars). The dwell caption is also shortened from "dwell at command" to just "dwell".
- **A loop's Focus and Type now actually change in its edit sheet.** On the waveform, opening a loop's
  settings and picking a **Focus** (Backburner / Active / Sharpening) or **Type** (Lick / Riff / Chords /
  Passage) did nothing — the dropdown needed several taps to even register and the choice never stuck, so
  those fields felt frozen. They were the only two fields built on an interactive picker inside the row's
  value slot, which is unreliable at the sheet's partial height; both are now a tap that opens a simple
  options sheet and writes the choice immediately.
- **The screen no longer sleeps during a routine session's rest or completion screens.** The
  keep-awake modifier (ADR 0050) was on every block run screen (exercise/loop/song) but not on the
  routine player's between-blocks **rest** countdown or its end-of-session summary. Leaving a block
  re-enables the idle timer, so a long enough rest — or lingering on the finished screen — could let
  the phone lock mid-session. Both phases now hold the screen awake like the run screens do.
- **Count-in now counts a full bar and the exercise starts on the downbeat.** The count-in was
  off by one beat in every meter: it captured its start beat as the pre-start `-1` (the beat before
  the first click), so a one-bar count-in in 4/4 showed only **3·2·1** and engaged on the *last* beat
  of the bar rather than the downbeat — the first note (and the climb) landed a beat early, out of
  step with the click's own downbeat accent. It now anchors to the first *heard* beat, so 4/4 counts
  **4·3·2·1** and the exercise begins on the next downbeat; the engage beat is now a bar downbeat in
  every meter (3/4, 6/8, …), locked in by a unit test on the pure boundary math. This is the deeper
  cause behind the fretboard walk starting on the wrong beat, and it corrects the free-play automator
  count-in too.
- **Scales and arpeggios now always start their walk on the low E, and the board no longer pops in
  after the count-in.** Two related fixes on the live practice fretboard:
  - *Right note.* The generated box always put the lowest-pitched note first in the data (`CAGEDShape`
    sorts ascending) — the bug was in playback. `FretboardView` read the engine's raw absolute beat,
    and a run's length rarely divides evenly into the count-in (unlike a strum pattern, always
    re-gridded to exactly one bar), so the walk could enter mid-shape (sometimes on the high e). It
    now pins its origin to the beat the **count-in clears** (the first musical downbeat), so note 0
    always lands there.
  - *No pop-in.* The board used to be **replaced by the count-in beat dots** and then reappear when
    the music started, so the walk and the whole board arrived at once as an abrupt pop. The fretboard
    surface is now shown **throughout the count-in**, sitting fully plotted but static; only the walk
    begins, one bar in, on that first downbeat.
- **Strum, chord and Strum & Chords surfaces no longer pop in after the count-in either.** The
  follow-up to the fretboard fix above: the three remaining template surfaces were still *replaced by
  the beat dots* during the count-in and cross-dissolved in when it cleared. They now get the fretboard's
  treatment — shown **throughout the count-in**, fully plotted but static (the strum lane un-lit, chord 1
  on "Get ready"), engaging only on the first musical downbeat. Each now anchors its pattern/progression
  to the beat the **count-in clears** rather than to when it appears (the engine's `currentBeat` counts
  *through* the count-in, so `StrummingLaneView` gained the same `originBeat` anchor `ChordChangeView` /
  `StrumChordsView` already used). With nothing swapping mid-count, the `ZStack`/cross-dissolve in
  `ExerciseTemplateSurface` is retired for a plain conditional. Every exercise template now behaves
  identically across the count-in.
  - The creation-time preview (`FretboardDrillPreview`) had the wrong-note issue too in its
    free-running (non-Watch) animation, phased off raw wall-clock time — it now anchors to its own
    appearance instead, and moved to its own file in the split.

### Added
- **A generated session now shows how long it'll actually take, against your chosen length (planner
  review R3).** The review screen carries an **Estimated length** readout with a soft over/under-budget
  hint (e.g. "About right for your 30 min" / "A touch over…") — never a gate, just guidance. The
  estimate is now derived from each exercise's real **ramp staircase** (warm-up → dwell → summit →
  backoff, timed at each plateau's own tempo and meter) instead of a flat 12-minute default, so it
  reflects what a session actually costs; loops (region × repeats) and songs (duration) already did.
  Blocks also gained an additive **`reps`** field (defaults to 1) the estimate accounts for.
- **A goal can now target any skill, not just the ones its template seeded (planner review R2).** The
  goal editor gained an **Add skills** button that opens a searchable, family-grouped picker over the
  whole technique catalog (Picking hand · Fretting & legato · Fretboard knowledge · Scales & improv ·
  Rhythm & timing · Ear & musicianship · Repertoire & creativity). Search matches skill names (case-
  and accent-insensitive); there's no free-text — you can only pick real catalog skills, since an
  unknown skill would schedule nothing. Adding a skill drops it into the goal's trimmable list (and
  reveals the target-song picker if it's a repertoire skill).
- **The home hub was reworked around today's session (planner review R1).** The front door now leads
  with **Start today's session** — a filled primary button that generates a fresh, goal-adaptive
  session (set your goals once; every run adapts). Below it: **Jump back in** (your last song,
  unchanged), a new **Song library** nav strip in its own blue identity (matching the Metronome and
  Practice strips for a blue · teal · plum triad), the Metronome and Practice strips, and a new
  **Recent routines** rail — the last three routines you actually *practised*, each a one-tap exact
  replay. Settings moved to the top-left; adding a song is now a solid green **+** disc in the top-right. The old
  "Your progress" stats strip and the inline song-preview list were dropped. Practice's planner entry
  was also reframed from "Build today's session" to **"Today's session"** so the verb no longer clashes
  with a Quick session.
- **Generated sessions can be named right on the review screen (planner review R1b).** A just-built
  session (goal-driven or Quick) now shows an editable **Name** field inline on its review screen — no
  longer hidden behind the Save button — so the routine you'll keep going back to is easy to name
  before you Save or Start it.
- **Loops can now feed technique goals (V2 planner Slice 4, ADR 0074).** Tag a loop with a skill
  bucket — the loop tag editor offers ✨ **Picking / Legato / Scales / …** suggestions — and the
  planner's technique goals will schedule that loop alongside your exercises, not just when you're
  learning its song. It reuses the existing loop tags (no new setup), it's entirely opt-in (untagged
  loops behave exactly as before, surfacing only via a "learn this song" goal), and it stays coarse:
  a "Picking" loop answers any picking goal. All matching is pure and unit-tested.
- **Build today's session — the practice planner is live (V2 planner Slice 3, ADRs 0014–0016/0015).**
  Practice's "Build today's session" entry is no longer a placeholder: it opens a planner where you
  pick how long you have (**Quick 15 / Focused 30 / Full 60**, default short), keep a short list of
  **goals**, and tap **Generate** to get a ready-to-run session. A **goal editor** starts from one of
  four curated templates ("Play a specific song", "Build speed", "Improvise in a style", "General
  progress"), then lets you name it, set its priority (**Low / Normal / High**), trim its skills, and
  — for a "learn a song" goal — pick the target song; editing adds a **met** toggle and delete. The
  generated session opens as the same **provisional** routine you review before it's kept (Save to
  name-and-keep, or Start to run it now; back out and it's discarded). With no active goals, Generate
  falls back to a due-based Quick session so it always produces something.
- **Goals feed the planner (V2 planner Slice 2, ADR 0073).** The planner's front-half now turns
  what you *want to get better at* into what to practise. A **goal** carries a set of skills (from a
  curated technique taxonomy) and an optional target song; the planner expands your active goals into
  a ranked pool of your own exercises, loops and songs, then lays them out into a session — the same
  ready-to-run routine the Quick session produces. Coarse, honest matching: a "sweep picking" goal
  surfaces all your Picking drills (no per-exercise tagging in V2). A goal weighted harder pulls its
  skills up; a skill whose prerequisites you haven't rated yet is *gently* down-weighted (it still
  appears, just later — the app never refuses to schedule what you asked for); marking a goal met
  drops it from the next session. Four in-house goal templates ("Play a specific song", "Build
  speed", "Improvise in a style", "General progress") seed sensible skill sets. All selection logic
  is pure, unit-tested (the ADR 0015 property list). The goal-editor UI ships in Slice 3 (above).
- **Quick session — the practice planner's first surface (ADR 0072, V2 planner Slice 1).** A new
  ✨ button in the Routines library generates a ready-to-run session from your exercise library and
  opens it as a **provisional** routine you review before it's kept — nothing lands in the library
  until you explicitly **Save** it (with a chance to rename; the default is dated and unique, e.g.
  "8 Jul Quick Session", "… 2" for repeats the same day) or **Start** it. Back out and it's discarded.
  It ranks drills by **dueness** — how long since you practised each,
  softened by how well you've *rated* you own it (you set the rating; the app never scores your
  playing, ADR 0070) — leads with a least-recently-used warm-up, keeps focused blocks short with
  rests between them, and finishes on the most-due drill (the practice-science session shape, ADR
  0014). No goals yet — that's the next slice; this already turns "I have 15 minutes" into a real
  routine. Exercises gain a self-rated **mastery** dot rating and a **last-practised** readout on the
  detail sheet, mirroring loops. The selection ranking and session layout are pure, unit-tested logic.
- **Routine detail screens now have a bottom "Start" button.** Every routine's overview (hand-built
  or generated) carries a pinned Start button that launches the player, so previewing the blocks and
  starting the session are one screen apart — no more launching blind from the library row.
- **Swap the transport's Loop/Marker sides (Settings → Transport).** The big idle Loop and Marker
  buttons flanking the practice transport bar can now be swapped left-to-right from a new **Transport**
  section in Settings. Default is unchanged — Marker on the left, Loop on the right; the toggle only
  moves the idle controls (while a loop is active the compact column and its colour strip keep their
  places). Persisted like the other Settings preferences.
- **Starter routines (ADR 0066 / 0071).** The Routines library ships three curated, in-house starter
  routines — **Morning Warm-up**, **Picking Builder**, **Rhythm & Changes** — seeded once on first
  launch (after the starter exercises they string together) so a new Practice space isn't empty. Each
  is an ordinary routine afterwards: fully editable, fully deletable, and a deleted preset stays
  deleted.
- **Song blocks in routines — audio-only play-along (ADR 0066 / 0071).** A routine can now include a
  **song** you play along to, not just exercises and loops. The picker gains a **Songs** bucket
  (local/iCloud files only — Apple Music can't be time-stretched, ADR 0001), and in the player a song
  block runs a minimal **play-along**: a fixed play-along speed you set (adjustable live, **no ramp** —
  a song is an open jam), play/pause, and −10s/+10s seeks over a live position bar. By default a song
  **loops** and the routine moves on only when you **skip** it; a new **Settings → Routines** toggle
  ("Loop song blocks", default on) lets you instead play it through once and auto-advance. The
  play-along is judgement-free (no scoring, ADR 0070).
- **Routine player & editor polish (ADR 0071 follow-up).** A batch of player/editor refinements:
  - **Auto-start** — in a routine, each block after the first begins on its own; loop blocks get a
    brief **3·2·1 count-in** (visual + haptic) before they start. Exercise blocks skip the visual
    count-in and rely on the metronome's own audible count-in, so you hear a single lead-in rather
    than a doubled one. Auto-start is governed by a new **Settings → Routines** toggle ("Auto-start
    blocks", default on).
  - **Session progress strip + navigator** — a slim per-block bar under the nav bar with **Start /
    Finish** markers and the current block highlighted, flanked by **‹ previous / next ›** chevrons
    (the one place session navigation lives), replacing the cramped "N of M" by the close button.
  - **Numbered blocks** in the routine detail/editor list, so the sequence is clear at a glance.
  - **"Up next"** preview on the rest screen, and a configurable **rest length** (Settings →
    Routines, 5–60s).
  - **End-of-block reflection** — when a block finishes, an optional journal prompt lets you jot a
    note before moving on (skippable; "Reflect after each block" setting, default on), and the
    session ends on a **judgement-free recap** of what you practised (no scores, ADR 0070).
  - **Editing is gated behind Edit** — opening a routine is read-only; the name field, Add/Insert and
    delete/reorder controls appear only after tapping **Edit**, with Save committing and Cancel
    discarding.
  - **Loop runs now collapse their settings** — a loop's tempos/reps/steps sit behind the same
    collapsible **Practice Settings** disclosure an exercise uses, so the run opens on the summary +
    staircase.
- **Practice routines — the auto-advancing player (ADR 0066 slice 3 / ADR 0071).** A ▶ on each
  routine row runs the session full-screen, and each block is the **real run screen** —
  the same fretboard/strum/chord preview, Practice Settings, ramp staircase, promote and journal you
  get running an exercise or loop on its own, now with session **progress** ("2 of 5") and a **Skip**
  control. When a block finishes its command-ramp naturally the session **auto-advances** to the
  next; rests are a short fixed countdown — so a hand-built routine needs no per-block minutes.
  Deliberately **judgement-free (ADR 0070)**: no scoring, no accuracy, no pass/fail — completion is
  the material's length, and the aim is *controlled discomfort, not clean reps* (the ramp pushes at
  and past your command tempo). Orphaned blocks (a deleted unit) are skipped; song blocks — an
  audio-only branded play-along on DRM-free files — are the following slice.
- **Deeper add-unit picker — two levels, like Apple Music.** The routine editor's picker now drills
  a level further: **Exercises** group by their **template** (Strumming, Scales, …) and **Loops**
  group by their **song**, each sub-bucket opening its own unit list — Library → Artists → tracks.
  Recently Added is unchanged.
- **Practice routines — manual authoring (ADR 0066, slice 2).** A **Routines** entry in the
  Practice hub opens a routines library where you build a session by hand: create a routine,
  name it, add **exercise** and **loop** blocks, insert rests between them, and drag to
  reorder. The add-unit picker is structured like the Apple Music **Library** root —
  **buckets** you drill into (Exercises, Loops) over a **Recently Added** shortcut, with
  exercises first (the exercises-first direction). Editing is **sandboxed with an explicit Save**: changes only
  persist when you tap Save; Cancel or leaving discards them, so a half-built or abandoned
  routine never lands. Deleting a routine leaves its referenced units untouched; a unit
  deleted elsewhere shows as a skipped "Unit removed" block rather than breaking the routine.
  Song blocks are intentionally deferred until the player can run them (slice 3). Authoring
  only — the auto-advancing player is the next slice.
- **Practice routines — the session container (ADR 0066, slice 1).** New `Routine` and
  `RoutineItem` SwiftData models: a routine is an ordered list of typed blocks
  (`focused` / `warmup` / `play` / `rest`), each non-rest block **referencing** exactly one
  practice unit — an `Exercise`, `Loop`, or `Song` — via typed optional relationships (the
  ADR 0058 polymorphic pattern). Order is explicit (`RoutineItem.order`), and deleting a
  referenced unit **nullifies** the block's link rather than deleting the routine (the block
  becomes orphaned and a future player will skip it). A pure, SwiftData-free `RoutineBudget`
  layer holds the pacing rules distilled from the planner science (ADR 0014): only `focused`
  work is budgeted, focused blocks cap at 20 min and split beyond it, and rests are proposed
  between adjacent focused blocks. This is the model substrate only — authoring UI and the
  player are later slices. Additive schema (new models + nullify inverses on
  `Exercise`/`Loop`/`Song`); 26 unit tests cover the pure rules and the model, incl. the
  nullify delete rule. *Migration still to be device-verified before merge.*
- **Watch replaces the per-editor Animate toggle.** Every fretboard-family editor (Scales,
  Arpeggios, the generative run editor, the custom-grid editor) had a duplicate **Animate** toggle
  inside its Display menu, alongside the **Watch** one-shot preview button that already covers "see
  it move once" without flipping a global, off-by-default-for-photosensitivity preference. Since
  Watch makes the toggle redundant in every place it appeared, it's gone from all four Display
  menus; the underlying preference is unchanged and still reachable from Settings → Motion →
  "Animate exercises" for anyone who wants the board to walk continuously while editing.
- **Strum & Chords template — a strum groove over a chord progression (ADR 0065).** A new
  **Strum & Chords** template composes an existing `StrumPattern` groove with a `ChordProgression`,
  wrapped in a new `StrumChordSheet` payload. The live surface stacks the chord-changing view over
  the strumming lane, both reading off **one shared beat origin** (the first post-count-in downbeat)
  but wrapping on their own independent cycle lengths — there is no reset that restarts the groove on
  a chord change, so a groove whose length divides evenly into each chord's hold (the shipped
  **"Groove — Pop Changes"** starter: the folk D-DU-UDU pattern under the G·D·Em·C turnaround) simply
  reads as locked, by construction. The create sheet and the exercise detail sheet both offer the
  `StrumPatternEditor` and `ChordProgressionEditor` stacked as one authoring section.
- **Strumming accents and mutes (ADR 0065).** A strum slot now carries an independent **accent**
  flag alongside its direction, and a new **mute** direction ("x" — a percussive chuck) joins
  down/up/rest. The editor's tap-to-cycle gesture now steps **down → up → mute → rest**, and a
  **long-press** flips the accent on whichever direction is showing (a no-op on a rest); both the
  live practice lane and the editor draw an accented stroke heavier and a touch larger, and — after
  on-device testing showed the haptic landed but the weight/scale change alone didn't read at a
  glance — a literal **`>` mark** above the stroke. The payload bumps to **schema v2** — a
  decode-time upgrade reads an older bare-direction blob straight through, so no store migration is
  needed. Ships a seeded **"Strumming — Syncopated Mute"** starter demonstrating both (one-time key
  `practicePresetsSeeded.v7`).
- **Display-menu row added to the remaining fretboard editors.** The generative run editor
  (Warm-up/Picking/Legato/Fingerstyle) and the custom-grid editor now carry the same **Display**
  menu (note-caption mode) and **Watch**/sound-preview controls as the Scales and Arpeggios editors
  — a gap the fretboard-polish slice deliberately left open. The custom-grid editor also gains a
  live `FretboardDrillPreview` above its placement board, so a hand-placed drill can be watched for
  timing before it's saved, not just generated runs.
- **Fretboard polish: inlay markers, CAGED-shape labels, and a one-shot preview (ADR 0065).** The
  fretboard board now draws the standard **position-marker dots** (single at 3·5·7·9…, double at
  12/24) that fall within the visible window, the same orientation cue as the wood inlays on a real
  neck. The Scales and Arpeggios editors now caption the position as **"E shape · 1 of 5 · fret 5"**
  instead of a bare "Position 1" — the CAGED letter is what a player actually recognises the shape as,
  and it resolves the earlier mismatch between our fixed E-shape-first numbering and the classic
  minor-pentatonic box order. A new **Watch** button plays a single walk-through of the shape on tap,
  independent of the global animate preference (and not gated by Reduce Motion, since a deliberate
  one-shot pass is a different thing from sustained flashing) — restoring "watch it before you save"
  for anyone with animation off by default.
- **Chords template — change chords cleanly on the beat (ADR 0065).** A new **Chords** category:
  author a **progression** of chord voicings, each held for a number of beats, and the run screen
  shows the current chord's diagram large with the next chord previewed, swapping on the beat as the
  click runs. Built on a shared **`ChordVoicing`** model — one geometry drawn by a standard vertical
  chord diagram — with an in-house library of open shapes, sevenths, two barre forms, and triads. A
  **triad is just a three-note voicing**, so the earlier "CAGED + triads" idea folds in here rather
  than as its own category. Each diagram shows a **Roman-numeral badge** (I, V, vi, IV …) read against
  a **key** you set on the progression (or inferred from the first chord), major or minor. Which chord
  is active at any moment is pure, unit-tested timing math (`ChordProgression`); the view is a thin
  skin over it, and the progression is **anchored to the first musical downbeat** so the count-in
  never eats the first chord's bar. Ships a seeded **"Pop Changes — G · D · Em · C"** starter
  (one-time key `practicePresetsSeeded.v6`).
- **Exercise content templates — foundation + strumming (ADR 0065).** An exercise renders a
  "what to play" surface over the shared metronome clock, driven by an optional versioned
  `Codable` **`templatePayload`**. The first surface, **strumming**, animates a down/up/rest
  arrow lane with the current slot lit as the click runs; templates with no bespoke surface fall
  back to the beat dots. Which slot is active at a given moment is pure, unit-tested timing math
  (`StrumPattern`); the lane is a thin skin over it.
- **Exercises are created from a template, and the library groups by it (ADR 0068).** Creating
  an exercise now **starts with a template** — Strumming, Scales, Chords, Picking, Legato, … —
  a first-class choice that decides how you build and run the drill and which section it lands
  in. Strumming has its own arrow-pattern editor; the other techniques run as a plain tempo
  drill for now, each a real, section-distinct slot for a future editor. The **template is set
  at creation and can't be changed** after (delete + recreate to change type), so a drill's
  type never drifts. The Exercises library groups into **template sections**, alphabetical; the
  seeded starters ship pre-assigned. (Existing exercises land in the **Basic** section.)
- **Author a strumming pattern in the create flow and the detail sheet (ADR 0065).** Choosing
  the **Strumming** template shows its tap-to-cycle editor right in creation (each slot steps
  down → up → rest, with a quarters / eighths / sixteenths resolution control), seeded with the
  folk pattern; the ⓘ detail sheet edits the same pattern later. A strumming drill always has a
  pattern — there's no "remove," because the template is fixed.
- **A seeded "Strumming — D DU UDU" starter (ADR 0065).** A new curated preset ships the
  folk strum pattern, seeded under a second one-time key (`practicePresetsSeeded.v2`) so
  existing users gain it on the next launch without disturbing (or re-seeding) their v1
  starters.
- **Strumming exercises show their arrow pattern on entry (ADR 0065).** The run screen's setup
  (before you press Start) now previews the down/up/rest lane, so you see the pattern up front
  — the same lane that lights up in time once the drill is running.
- **Fretboard renderer — the shared surface for scales, picking, legato & warm-ups (ADR 0065
  build 2).** Exercises in the fretboard family now run over an **animated fretboard**: the
  drill's notes are plotted on a string × fret grid and the current note lights up as it walks
  the board in time with the click. One renderer serves five templates (Scales, Picking, Legato,
  Fingerstyle, Warm-up); which note is active at a given moment is pure, unit-tested timing math
  (`FretboardDrill`), and a fretboard-template drill with no notes yet still runs on the beat
  dots.
- **Author a fretboard warm-up by its *shape*, not note-by-note (ADR 0065 build 2).** Warm-up,
  Picking, Legato and Fingerstyle now use a **generative editor**: instead of placing every
  note, you declare a **finger pattern** (finger numbers like `1-3-2-4`) anchored to a movable
  **base fret**, choose the **string span** it travels (e.g. low E → high e, or low E → A) and
  whether it goes **up and back** — and the run builds itself across the neck. A **live preview**
  walks the run above the controls so you see it before saving, and the subdivision is tucked
  into an "Advanced" row (default eighths). Creating one of these starts from a real chromatic
  warm-up; the detail sheet edits the same shape later — same immutable-template contract as
  strumming.
- **Scales are a library you pick from, not notes you place (ADR 0065 build 2, Slice 2).** The
  **Scales** template has a scale-library editor: choose a **scale** (minor & major pentatonic,
  major, natural minor, blues), a **root note**, a **position** up the neck, and **1 or 2
  octaves**, and the run generates itself onto the fretboard and walks over the click — with a
  live preview and an up-and-back toggle. The generator lays each run into a four-fret **hand box**,
  so notes-per-string *vary* the way a real CAGED shape does (the A-major E-shape is 2·3·3·3·2·2) —
  which is what keeps the blues and diatonic boxes holding together past the first octave. Every
  scale is now generated from the **five real CAGED boxes** (`CAGEDShape`): a position places its box
  in the chosen key and filters it to the scale's degrees, so all five positions are the shapes the
  method teaches — not a formula that only held at the E position. Minor-family scales reuse the boxes
  via their relative major; the blues note threads in as a chromatic passing tone. The **root notes
  are highlighted** — an amber ring on the fretboard that fills as the run walks over the tonic — in
  both the creation preview and the live practice session. **Note captions** can be toggled (Off /
  Note name / Interval) from a **Display** menu above the board, alongside an **Animate** toggle; both
  are global preferences that also drive the live practice board. The walking highlight is **off by
  default** as a photosensitivity precaution and is forced off under the system Reduce Motion setting —
  when off, the board renders static (all notes plotted, roots and labels shown). The **fretboard
  drill now previews on the practice run screen's setup state** (not just strum patterns) at a gentle
  60 bpm, and the **dark-mode grid** was lightened so the strings and frets are visible. A seeded
  **"A Minor Pentatonic"** starter ships under a fourth one-time key (`practicePresetsSeeded.v4`).
- **Arpeggios are their own template (ADR 0065 build 2, Slice 3).** A new **Arpeggios** category
  generates major, minor, maj7, min7 and dominant-7 arpeggios from the *same* five CAGED boxes as
  scales — a position's box filtered to the chord tones — with the same root highlighting, note
  captions, animation toggle and up-and-back. A seeded **"A Minor 7 Arpeggio"** ships under a fifth
  one-time key (`practicePresetsSeeded.v5`).
- **Animate-exercises toggle in Settings.** A single walking-highlight preference (off by default;
  forced off under Reduce Motion) is surfaced in Settings → Motion, alongside the in-editor control. It
  now governs **every animated exercise template** — the fretboard board and the **strum lane** both
  read it, so with it off the strumming lane no longer walks either and shows the pattern statically.
- **Groundwork for exercise audio.** An `ExerciseAudioEngine` seam (silent by default, injected via
  the environment) and a "Sound soon" preview affordance are in place so a real sound-preview /
  accompaniment backend can slot in later without call-site changes. No audio ships yet.
- **A seeded "Chromatic Warm-up" starter (ADR 0065).** A new curated preset ships a generated
  1-2-3-4-up-every-string-and-back warm-up, seeded under a third one-time key
  (`practicePresetsSeeded.v3`) so existing users gain it on the next launch without disturbing
  their earlier starters.

### Changed
- **The waveform practice screen is a workshop, not a journal (ADR 0067).** The
  read-only journal peek moved off every loop row into the loop's settings sheet as a
  **"View entries"** row (journal *authoring* already lives on the Practice run screen,
  ADR 0058). The freed loop-row control is now a **fine-adjust** button
  (`slider.horizontal.below.rectangle`) that lifts the loop into range-edit in one tap —
  the same deliberate flow as the edit sheet's "Adjust range on waveform."
- **Resizing a loop no longer restarts it from the top (ADR 0067).** Dragging an A/B edge
  and releasing keeps playing from where the playhead is when it still falls inside the
  resized region (it plays out to the new end, then loops); it only restarts from the start
  when the playhead now sits outside the region.

### Fixed
- **Switching a strum pattern's resolution no longer wipes it (ADR 0065).** Toggling the
  strum editor between quarters / eighths / sixteenths re-grids the pattern **by beat position**
  instead of by raw slot index — so refining keeps each stroke on its beat (not crammed into the
  first half of the bar), coarsening keeps the on-beat strokes (not a truncated tail), and
  visiting a coarser resolution and returning no longer deletes the pattern's second half.
- **Audio failures now surface instead of dying silently** (pre-V2 audit). The two audio
  engines' session/start plumbing is deduplicated into a shared `AudioPlumbing` helper that
  **logs** setup failures (was `try?`-swallowed — the backlog's "silent no-sound" robustness
  item). On the practice screen and the loop run screen, a song whose security-scoped
  bookmark no longer resolves (file moved/deleted) or whose file won't read now shows an
  honest **"Couldn't load this song's audio"** notice — the loop run also disables Start —
  instead of a silently dead transport.
- **Stale bookmarks now self-heal** (pre-V2 audit). When an imported song's bookmark
  resolves but reports stale (file moved, iCloud eviction), both practice surfaces re-mint
  it from the live URL and persist — safe by design, since `SongRef` identity excludes the
  bookmark bytes — so the song doesn't quietly drift toward "won't open at all".

### Removed
- **Dead ADR-0043 relics** (pre-V2 audit): `TempoProgressBar` (the metronome-era hairline
  progress track — zero references) and `ExerciseProgress` + `Exercise.progress` (the
  "light progress" readout model, unused by any app code since the ADR 0046 run-screen
  rework dropped the progress chip) plus its test file. Pure-logic doc lists updated.

### Compliance
- **Privacy manifest now declares the System Boot Time required-reason API** (35F9.1). The
  metronome engine reads `CACurrentMediaTime()` for session/tick timing; the manifest previously
  declared only UserDefaults, which would have drawn an ITMS-91053 "missing API declaration"
  warning on upload. Also excluded the local `build-device/` output from SwiftLint so a
  `--strict` run no longer flags generated asset-catalog sources.

### Changed
- **Exercise run setup now groups its tempos + steps under a collapsible "Practice Settings"
  panel** (V1 feedback). The Working / Command / Reach tempos and the Steps granularity are tucked
  behind one disclosure header below the exercise title — collapsed by default, showing a one-line
  tempo summary (e.g. `42→50 · reach 53 BPM`) — so the run screen opens on the summary + routine
  staircase and expands to edit, mirroring how the nested Steps panel already behaves.
- **Practice count-in dots now read in the practice colour** (V1 feedback). The `BeatIndicator`
  is tint-aware: the exercise run screen's count-in beat dots use `PocketColor.practice` (purple)
  instead of the metronome's teal, so the metronome UI no longer leaks into the Practice space. The
  metronome screen keeps its teal via the default.
- **Routine staircase now signposts the command tempo** (V1 feedback). A `<bpm> BPM` label sits just
  above the wide **dwell** bar (found as the longest-held plateau), so the anchor tempo is legible
  straight off the chart. Clamped into a reserved top strip so it never clips on a no-reach routine
  where the command bar is the tallest.
- **Refined the Red Moon brand lockup** (Settings brand mark). Rebalanced the composition so the
  wordmark and star cluster hang under the moon's optical centre of gravity instead of drifting
  toward it — the "Red Moon" wordmark moved left ~20px and the stars ~10px. Removed the baked-in
  off-colour matte rings around the stars, and locked the brand teal to `#7b9ca9` across the stars
  and wordmark in both appearances. The moon illustration and the wordmark's letterforms (including
  the hidden half-note "d") are unchanged. Sourced from the existing raster art; a vector master is
  a future follow-up.
- **Minimap waveform now matches the detail waveform's style** (ADR 0055 follow-up). The
  full-song overview strip draws smoothed, rounded-cap bars (grouped the same way the
  zoomed-out detail waveform is) instead of a spiky point-to-point silhouette, so the two
  waveforms read as one consistent instrument.

### Added
- **Exercises now have a detail sheet** (V1 feedback #2). An ⓘ in the exercise run screen's nav bar
  opens a reference sheet: an editable **description** (a note-to-self about the drill — the first
  UI for the exercise's notes field), its tempo anchors (working / command / reach), meter and
  subdivision, a read-only preview of the training-routine staircase, and a placeholder for the
  **animated fretboard guide** planned for a future release.
- **Settings → Appearance** lets you pin Light or Dark regardless of the device setting, or leave
  it on System (the default, unchanged behaviour) (ADR 0063).
- **The Home header now shows the "Red Moon" wordmark graphic** (with its hidden half-note) instead
  of plain title text, in both appearances.
- **The −/+ step buttons now auto-repeat when held, and accelerate** (V1 feedback #3). Holding a
  tempo, reach/step, or reps stepper bumps the value repeatedly — slowly at first, then faster the
  longer you hold — so a big change no longer means dozens of taps. A single tap still nudges by one.
  Applies everywhere the circular −/+ buttons appear — the **metronome tempo** steppers, plus the
  loop & exercise run setups (via the new shared `StepperButton`).
- **A new exercise's command tempo is now typable** (V1 feedback #3). The New Exercise sheet uses
  the same −/+ + tap-to-type control as the run screen, so you can enter a value directly instead of
  stepping to it.

### Fixed
- **The journal's "Add entry" button now fires on the first tap** while the composer's text field is
  focused. As a default Form-row button it was swallowing the first tap to dismiss the keyboard
  instead of committing the entry, so it read as a dead/static button; it's now an independent
  `.borderless` hit-target.

### Changed
- **A hand-created exercise now defaults its command tempo to 50 BPM** (V1 feedback #3), down from
  90 — a more conservative "fastest you can play it cleanly" starting point. Exercises created from
  the metronome automator still prefill with the discovered breakdown tempo.
- **The waveform transport's Loop and Marker controls are now big circular buttons** flanking the
  transport while idle — **Marker on the far left, Loop on the far right** (V1 feedback #1) — instead
  of a small stacked pair in a left column. The idle Loop button lights up while an A/B span is
  forming. **Once a loop is active the bar reverts to its compact form** (the small stacked
  Loop/Marker column + the loop's ✕ colour strip), so the running loop reads on the Loops panel below
  and the bar steps out of the way. A follow-up to make the idle sides user-swappable from Settings
  is parked in `docs/backlog.md`.
- **Dark Mode is noticeably more vibrant** (ADR 0063). The Metronome/Practice card and circle
  tints on Home, and the "Add a song" green, were still reading as near-invisible on the near-black
  background — the same light/dark blending asymmetry ADR 0062 fixed for Light Mode, just
  undiscovered in the other direction. They're now independently baked per appearance instead of a
  shared low-opacity blend, along with the waveform's beat-grid lines and inactive loop-identity
  lines (waveform + minimap). The Metronome teal and Practice plum accents themselves also moved
  from ~20% to ~50% saturation in both appearances — they read as too dusty for how much visual
  weight they carry (feature cards, the tempo slider, every waveform bar). The tempo/speed slider
  and waveform bars now track the same retuned teal.
- **Loop identity colours are brighter and no longer brand-tuned** (ADR 0063) — a loop's colour
  exists only to tell loops apart, so the six-colour palette moved to plain, maximally-distinct
  hues (red/orange/gold/magenta/violet/blue) instead of the brand's muted register, fixing two
  light-mode swatches that had collapsed into a near-identical muddy brown/olive.
- **A saved loop's edge can no longer be dragged directly on the waveform** (ADR 0063) — resizing a
  loop now only happens via its edit sheet's explicit **"Adjust range on waveform"**, removing an
  accidental second path to the same action. The active loop's boundary is now marked with a bold
  static line across the waveform instead of a grabbable knob.
- **The Settings → About brand mark now blends into the background** (ADR 0063) — its solid
  card-coloured background is keyed out to transparent, so the artwork sits directly on the app
  background with no seam, in either appearance.
- **Mastery dots and stars are now the brand teal instead of amber** (Home's "Mastered" stat, the
  "Jump back in" card, song cards, and the loop mastery picker), plus the waveform's "Set BPM"
  label — both now read as on-brand rather than a leftover UI-kit amber.
- **The app now supports Light Mode** (ADR 0062), following the system Light/Dark setting — every
  screen was previously forced dark regardless of device setting. Every colour token got a proper
  light+dark pair verified against real WCAG contrast (not just the same hex reused), and four new
  "surface" tokens (`surfaceSubtle`/`Standard`/`Emphasis`/`Border`) replace 11 ad-hoc translucent
  fills that had no shared token at all.
- **The app has a name, an icon, and a face: "Red Moon"** (ADR 0061). The home-screen name is now
  **Red Moon**, with a new **app icon** — the crescent moon and its Southern-Cross stars on the
  dark canvas. **Settings → About** shows the full brand mark (moon + "Red Moon" wordmark), whose
  **"d" hides an open half-note**. Internally the app is still Pocket (bundle id unchanged).

### Changed
- **Metronome and Practice's identity colours are retuned to match the brand** (ADR 0062).
  Metronome retires its old bright cyan for the "Red Moon" brand teal; Practice moves from a
  generic indigo to a dusty plum — both now sit in the same muted register as the logo instead of
  reading as unrelated UI-kit colours.
- **App type is now Futura** (ADR 0061), echoing the wordmark — all prose/UI text moves from the
  system sans to Futura via a single `Font.futura` token. Tempo/time **numerals stay monospace**
  (unchanged) so live readouts don't jitter.
- **"Your progress" on the home screen** (ADR 0060). A glanceable card shows four derived measures —
  **Loops**, **Exercises**, **Mastered** (loops at full mastery), and **Notes** (journal entries) —
  computed from what's already there (no new data). Hidden until you have at least one loop or
  exercise, so first launch stays clean.

### Changed
- **A loop's auto-target now climbs toward the song's real tempo, then unlocks overspeed** (ADR
  0059). 100% (the original tempo) is treated as the ultimate goal: while you're below it, the
  auto-target is a milestone that stops at 100% instead of overshooting (so command 96% now reaches
  **100%**, not 102%). Once you own full tempo (command 100%), the ceiling lifts and the target
  climbs past into overspeed (**100% → 106%**). Loops already at full tempo are unchanged.

### Added
- **Practice journal now writes from the run screen, and exercises have a journal too** (ADR 0058).
  Journal notes are authored where you practise: the loop and exercise **run screens** carry an
  inline **Journal** section — a **New entry** button plus your latest few entries, with **See all**
  opening the full journal to add, edit, and delete (an entry / New entry / See all all open it).
  Exercises get their own journal for the first time — an exercise entry snapshots its **command
  tempo in BPM** (a loop entry keeps snapshotting mastery + command-tempo %). The waveform screen's
  loop journal is now **read-only** — a history view of past notes, with a nudge to write new ones
  from Practice. No existing notes are affected.
- **Loop run-setup ramp shape now persists** (ADR 0057 follow-up). The four staircase controls on
  a loop's run screen — warm-up steps, reach steps, back-off steps, and reps per step — now save
  with the loop instead of reseeding to defaults each visit. **Save Changes** appears when any of
  them differ from what's stored, and they round-trip on return. Backed by four dedicated `Loop`
  fields kept separate from the ADR-0013 waveform automator (different ramp semantics).
- **Save run-setup edits without starting a run** (ADR 0057). Tuning an exercise or loop's ramp on
  the run screen (working / command / reach / steps / signature) now shows a **Save Changes** button
  when the setup differs from what's stored — persist your tuning and come back to it later, without
  having to start a training run. Leaving without saving still discards unsaved edits, as before.
- **Undo after editing a loop.** Saving changes in the loop editor (name, mastery, focus, command
  tempo, type, tags, colour) now shows a **"Saved changes · Undo"** snackbar — the same one deletes
  use — that reverts the whole edit in one tap. A Done that changed nothing shows nothing.
- **Field explainers (ⓘ) on the coined practice terms.** The fields a musician can't infer from
  the label now carry a tappable **ⓘ** with a one-line definition: **Mastery**, **Command tempo**,
  **Focus**, and loop **Type** in the loop editor; **Command tempo** on the exercise-create sheet
  (replacing its inline footer); and the derived **Mastery** on the song details sheet (explaining
  it's averaged from the song's loops). Standard vocabulary (Key, Genre, BPM) is left plain.
- **Sort + search in the Practice libraries** (ADR 0056). The **Loops** and **Exercises** lists now
  carry a sort menu (its label spells out the active key with a direction arrow) and a search field,
  matching the song library. Loops sort by **Song · Name · Command tempo · Mastery** (unrated last);
  exercises by **Name · Command tempo · Recently added**. Each library remembers its choice across
  launches.

### Changed
- **Minimap shows the song's shape** (ADR 0055). The full-song overview strip now draws a
  compressed **silhouette** of the waveform (through the same fuller/calmer curve as the main
  waveform) instead of a flat gray bar — so quiet intros read thin and loud sections bulge, and
  you can orient by the song's shape at a glance. Loops, markers, and the playhead are unchanged.
- **Smoother playhead** (ADR 0054). The waveform playhead now glides instead of stepping — it's
  driven by the display's own refresh (a `CADisplayLink`) rather than a fixed ~33 Hz timer that
  ran below the screen's refresh rate and beat against it. Purely a visual/timing fix: snapping,
  loops, and markers are untouched.
- **Faster test loop: split test plans** (ADR 0053). The suite now runs through two
  `.xctestplan`s — a fast, coverage-free **`PocketLogic`** plan (the ~498 unit tests) as the
  default for local pre-push (~123s → ~59s), and a full **`PocketAll`** plan (adds the UI tests
  + coverage) that CI runs with `-testPlan PocketAll`. No test code changed. (Parallel execution
  was benchmarked and dropped — the unit tests are too short for clone overhead to pay off, and it
  broke the UI runner.) Developer-facing only.
- **Exercise run screen drops the session timer.** The running readout is now just the live BPM
  and the beat dots — the wall-clock session time was more clutter than payoff.
- **Waveform reads fuller and less aggressive** (ADR 0049). The envelope now draws through a
  gentle dynamic-range compression curve (quiet/mid passages lift toward a fuller skyline),
  thin bars are grouped into fewer, wider, smoother ones instead of a jittery 1px comb, and the
  bars gained rounded tops over a quieter mirror. This shapes only how the waveform is *drawn* —
  loop edges and markers still snap to the exact underlying peaks, so editing precision is
  unchanged. Zoom in and the full transient detail is still there.

### Added
- **Exercise time signature + count-in on training runs** (ADR 0052). The New Exercise sheet now
  has a **time-signature picker** (4/4, 3/4, 6/8, …), and you can change an **existing** exercise's
  meter from the run-setup nav bar. The run metronome plays a drill in its chosen meter — the click's
  accents and the **count-in** length both follow it. Practice training runs now **count you in**
  before the climb starts (honoring the Settings toggle and 1–2 bar length), the same as the
  metronome's free-play automator.
- **Per-song time signature + a gridlines toggle** (ADR 0051). Set a song's time signature
  (4/4, 3/4, 6/8, …) in the "Set tempo" sheet, so the beat grid's bar lines land in the right
  place instead of always assuming 4/4. A **Grid** toggle on the practice screen's "Loop controls"
  row shows/hides the grid per song — it appears only once a grid exists (tempo + the 1 set). The
  grid marks each **bar line** (kept subtle, behind the waveform); per-beat gridlines were dropped
  as they made zooming feel busy.
- **Settings** (ADR 0050). A gear in the Home toolbar opens a settings screen, grouped into
  **Feel**, **Practice**, and **About**. V1 carries **Haptics** (the light taps that confirm
  gestures), **Count-in** with a configurable **length** (1–2 bars), and **Keep screen awake**
  (stops the phone locking while you play along) — all on by default — plus the app version.
- **Metronome automator: explicit Start/Stop, count-in, and an infinite mode** (ADR 0048).
  The tempo automator no longer climbs the moment you arm it — arming (Off / By Bars / By Time)
  just configures the ramp and previews its staircase; a dedicated **Start** runs it and **Stop**
  halts it (leaving the metronome playing at the tempo you reached). Start **counts you in** one
  bar before the climb engages. A new **No limit** toggle drops the target and ramps to the
  system maximum (300 BPM) for open-ended speed training. A finished ramp now holds at its
  ceiling instead of stopping the metronome. The "Save as exercise" action became a compact
  bookmark icon.

### Fixed
- **Metronome automator no longer lurches on a tempo step** (ADR 0047). Every ramp step used
  to hard re-anchor the click grid to a fresh accented beat 0 mid-bar — audible as a jerky
  transition, worst on the *first* step and inconsistent thereafter. Ramp steps now re-anchor
  **phase-continuously**: the click you're hearing keeps its place, the downbeat stays a
  downbeat, and the new tempo's spacing splices in seamlessly at the next beat. Manual tempo
  changes are unaffected (they still snap to a clean downbeat).

### Changed
- **Metronome screen drops the session timer.** The standalone metronome no longer shows the
  large "SESSION" wall-clock readout — it took a lot of space for little payoff. The timer
  still appears on the Practice exercise-run screen (where elapsed time matters), and the
  lock-screen/Control Center elapsed time is unaffected.
- **Groundwork for a top-level Practice space** (ADR 0046, Phase A). Internal, no behaviour
  change: (1) the metronome-exercise model is renamed `MetronomeExercise → Exercise` as it
  stops being "a saved metronome setup" and becomes a first-class practice unit (existing
  saved exercises are reset — they were early experiments, a deliberate accepted trade for a
  clean model); (2) a training routine is now handed straight to the metronome engine
  (`engine.run(ramp:)`) instead of being routed through the free-play automator's setters, so
  arming the automator and running a training routine are no longer mutually exclusive; (3) the
  metronome's own in-screen exercise UI (save/load presets, the presets library, the
  command-anchored Training Mode) is **removed** — the metronome is now a pure free-play tool
  and all of that lives in the **Practice** space instead; (4) the exercise model stores its
  training-routine recipe **natively** (`ramp*` fields + dwell/backoff) rather than borrowing
  the free-play automator's fields — this field rename is data-preserving
  (`@Attribute(originalName:)`), so no further store reset beyond the one already noted above.
- **Groundwork for command-derived loops in Practice** (ADR 0046, Phase B, slice 1). Internal,
  no behaviour change: a measured song **loop** can now derive the same command-anchored
  progression an exercise has — a warm-up → dwell → reach → back-off `CommandRamp` — but in
  `×`-of-original rather than absolute BPM. `TempoStretch` gains a `×`-unit reach
  (`targetSpeed`), `Loop` gains the `command` / reach / promote accessors mirroring `Exercise`
  (no stored fields added, so the loop's migration discipline is untouched), and a pure
  `LoopCommandRamp` maps a loop's `×` tempos onto the shared `CommandRamp` staircase via
  integer percent-of-original. All unit-tested; no UI yet.
- **Loop training run screen** (ADR 0046, Phase B, slice 2). A new `LoopRunView` — the loop
  counterpart of the exercise run — lets you set a measured loop's warm-up **working** floor and
  owned **command** (as % of original), preview the derived **reach** and the warm-up/reach/back-up
  staircase, and **run** it: the loop's region plays on repeat while a `LoopRunModel` steps the
  time-stretch rate through the command ramp (warm up → dwell → reach → back off) and stops at the
  end. The ramp advances **by loop repetitions** — one pass through the loop is one step ("play it
  through, then bump it up"), with a **Reps per step** control (default 1) and a longer dwell at
  command. The live readout shows the current speed and loop count.
- **Loops are trainable units in Practice** (ADR 0046, Phase B). Practice is now a **hub** with two
  unit libraries: **Exercises** (your command drills) and **Loops** (any song loop you've measured —
  i.e. given a command tempo), each opening its own list. A measured loop shows its song as context
  and its command → reach, and tapping it opens the loop training run. Splitting them into separate
  libraries keeps each list clean and scannable; together they're the multi-source "things you
  train" surface the V2 planner will compose sessions from.

### Added
- **Practice run-screen refinements** (ADR 0046, Phase A). The training run's staircase now
  **lights the step you're on** as the routine climbs, and the dwell-at-command bar is no longer
  permanently highlighted (its length already shows it holds longer). The routine is more
  shapeable: alongside **warm-up steps** you can now add **reach steps** (ease up to the reach
  instead of jumping) and **back-up steps** (ease back down through the back-off instead of
  dropping) — all three tucked behind a collapsible **Steps** section so setup stays uncluttered.
  And every tempo can be **typed** — tap the number for keyboard entry — not just nudged with the
  −/+ buttons.
- **Starter exercises in Practice** (ADR 0046, Phase A). Practice no longer opens empty: six
  curated, in-house technique drills are seeded on first launch — **Spider Walk**, **Alternate
  Picking**, **Chord Changes**, **Scale Runs**, **String Skipping**, and **Legato** — each with a
  sensible starting tempo, a feel (subdivision), and a one-line how-to. They're ordinary exercises:
  edit them, run them, or delete the ones you don't want — and deleted ones stay gone (they're
  seeded once, not restored).
- **"Save as exercise" from the metronome automator** (ADR 0046, Phase A). The automator's job
  is *discovery*: ramp the tempo until your hands break down, and that tempo is your command. A
  **Save as exercise** action on the armed automator now captures the tempo you're at and hands
  it straight into Practice's create flow, prefilled as the new exercise's command — so a free
  ramp session can become a tracked drill in one tap. Creation funnels through a single shared
  path, whether you start in Practice or from here.
- **A top-level Practice space** (ADR 0046, Phase A). Exercises are no longer buried inside the
  metronome — there's now a **Practice** card on the home screen that opens a place of its own:
  a list of **your exercises** (the drills you push faster over time) above a **"Build today's
  session"** entry reserved for the guided planner (coming in a later update). Tap **+** to
  create an exercise, or tap one to open its **training run** — a screen that warms up from your
  working tempo, dwells at command, summits at the reach, then backs off, with a live tempo and
  beat readout while it plays. Each run owns its own engine, so it's independent of the
  metronome. The old in-metronome Training Mode still works for now; a later slice retires it.
- **Training Mode for exercises** (ADR 0045). An exercise has no "real" tempo to reach the way
  a song loop does, so instead of a goal you guess at, it tracks your **command tempo** — the
  fastest you can play it cleanly and repeatably — and sets the **reach** a small step above it
  automatically. Open an exercise's **training run** in **Practice** and one **Start** sets the whole
  routine going (no separate "arm the automator" step): it warms up from a comfortable
  **working** tempo, **dwells at command** for the bulk of the reps, briefly summits at the
  reach, then **backs off below command** so you finish on clean control rather than the edge.
  The first time you open it for an exercise, command starts at its current tempo and working
  at a sensible floor below — and you can choose how many **warm-up steps** to climb through on
  the way up. Your tempos move independently, and what you set is **saved when you press Start**
  (Close discards). When the reach gets comfortable, one tap (**"I own it now"**) promotes it to
  your new command and the reach climbs with you.
- **A home screen** (ADR 0044). The app now opens on a **home hub** instead of straight into
  the library: a time-of-day greeting, a **"Jump back in"** card for the song you last
  practised (with its mastery and when you last touched it — tap to resume right where you
  were), a **Metronome** card, a short preview of **your songs** (with **See all** for the full
  library, search and grouping intact), and **Add a song**. The library is now one tap away
  rather than the front door.
- **Songs resume at the tempo you left them at** (ADR 0044). Practise a whole song at 0.85×,
  leave, and reopening it picks up at 0.85× instead of snapping back to full speed — the
  song-level version of the per-loop speed memory. Loops still open at full speed until you
  arm them, and deactivating a loop now drops you back to the **song's** working tempo.
- **A standalone metronome** (ADR 0043). Open it from the **Metronome card on the home
  screen** for a click that stands on its own — no song needed. Set the tempo by stepper, slider, or
  by **tapping along**, and read the classical tempo marking ("Andante", "Allegro") as you
  dial. Pick a **named time signature** with its feel — 4/4 (pop), 3/4 (waltz), 6/8, **12/8
  (slow blues)**, 2/4, 5/4, 7/8 — and the **flashing dots** show that meter's accent pattern
  (a silent visual mode if you'd rather not hear it). **Pause** to take a breather and
  **resume** where you left off, or **stop** to reset; a **session timer** tracks how long
  you've practised this sitting. Switch on the **tempo automator** to have it climb the BPM
  for you — set the step size, whether it steps every so many **bars** or **seconds**, and
  the ceiling to hold at. Add **subdivisions** — eighths, triplets, or sixteenths — and a
  quieter sub-beat tick fills in under the main click. The click keeps going when the phone
  is **locked**, with **play/pause on the lock screen and Control Center**. The **tempo
  slider now reads perceptually** — its midpoint sits at a typical ~95 BPM and the everyday
  60–120 range fills the centre of the track, so a normal tempo no longer looks slow. The
  metronome is a **free-play tool** — exercises and command-anchored training routines live
  in the **Practice** space (ADR 0046), not here. *(Reached from the **Metronome card on the
  home screen** — ADR 0044.)*
- **The practice screen rotates to landscape** (ADR 0042). Turn the phone sideways on the
  practice screen — handy when it's propped on a stand — and the waveform claims the full
  width for a sharper view and more precise A/B dragging. Your loops and markers tuck into a
  **slide-in drawer** (the ☰ button, top-right) so they're there when you want them and out
  of the way when you don't. Every other screen stays portrait; rotate back and the screen
  returns to portrait on its own.

### Changed
- **Metronome: changing the tempo no longer switches the automator off.** With a tempo
  ramp armed, nudging or sliding the metronome's tempo now **re-bases the ramp on the new
  floor** (it restarts climbing from where you've set it) instead of dropping the automator
  back to "Off" — moving the floor resets the climb, it doesn't tear it down.
- **Tidier transport bar.** The playback controls are a touch smaller and, when a loop is
  armed, the transport now shows just the **loop name** (the time range was redundant with
  the loop row and waveform) — so the bar reads cleaner in both portrait and landscape.
- **Song info moved out of the practice scroll area.** The collapsible "Song info" panel
  at the bottom of the practice screen is gone — its key, mastery, and collections all live
  in the song details sheet (hold the song title to open it), so the practice scroll now
  stays focused on your loops and markers.
- **Loop tags read as tags now.** In a loop's edit sheet, the tags already on the loop show
  as removable chips (tap the ✕ to drop one) in a wrapping cloud, matching the look of the
  suggestion chips below — so your own tags no longer hide as plain text rows. Suggested tags
  from elsewhere in your library stay a quiet, tap-to-add row underneath.
- **One way to make loops — Fine mode is gone** (ADR 0041). The transport's left column
  is now just **Loop** and **Marker** (the separate "Fine" precise-edit mode and its ✓/✗
  confirm bar are retired). Setting, refining, and re-editing a loop all happen through the
  one **Loop** control now. **Hold-drag the waveform** still works as the spatial way to set
  a loop (the start pins at the playhead, the drag sets the end). Creating a loop no longer
  greys out the transport — it stays live so you can play along.
- **Crisper playback when slowed down**. Tuned the time-stretch so picked/struck attacks
  cut through better at reduced speed instead of smearing.

### Fixed
- The **playhead time label** no longer sits over the A/B handles — it's pinned low on the
  waveform, clear of both the handles and the loop brackets.
- **Tapping inside a playing loop now moves the playhead there** instead of restarting the
  loop from its start. Seeking into an active loop resumes from the tapped point and keeps
  looping seamlessly — so you can jump to a spot mid-loop without losing your place.

### Added
- **Make loops by playing along** (ADR 0041). Making a loop now works like the A-B repeat
  on a practice player: **tap Loop to set the start**, play along, **tap again to set the
  end** — it loops that section straight away. The loop just **lives** while you rehearse
  it — no more "save or discard now" prompt. **Nudge the A / B handles** right on the
  waveform to refine the bounds while it keeps looping (they snap to nearby markers and
  loop edges) — no separate mode to enter. When it's worth keeping, hit **Save as loop**;
  if not, **✕** clears it and plays on through.
- **Re-edit a saved loop's range by dragging it** (ADR 0041). An armed loop now shows
  **grab knobs on its edges** — drag one straight on the waveform to change its bounds
  (it lifts into A/B; **Save changes** writes the new range back, **✕** discards). The old
  three-hop "edit sheet → Adjust range → Fine" detour is gone; "Adjust range" now drops
  you straight onto the A/B handles too.
- **Loops remember the speed you practise them at** (ADR 0040). Slow a loop to 0.7× to
  drill it, move to another loop, come back — it **reopens at 0.7×** instead of snapping
  back to full tempo. Each loop carries its own last-practised speed, saved when you leave
  it and restored when you arm it again (a transport skip to a loop restores its speed
  too). The song still opens on the **full song at 1×** — only individual loops carry the
  memory.
- **Loop rows show your progress at a glance** (ADR 0039). A saved loop's row now
  surfaces its **mastery** (dots) and the **command tempo** you own it at (a percent
  badge) right under the name — so the loops list reads as a practice dashboard, not just
  a list of names. These show **only once you've set them**; an untouched loop stays clean
  with just its time range.
- **Loop practice journal** (ADR 0038). Each loop now has its own **journal** — a dated
  log opened from the book icon on the loop row (left of the **A** automator button).
  Every entry **remembers the loop's mastery and command tempo at the moment you wrote
  it**, so the journal stays a true record of your progress even as the loop improves;
  that snapshot is fixed, only the text and kind can be edited later. Tag each entry as a
  🎯 Goal, ⚡️ Breakthrough, 🧗 Struggle, 📝 Note, or 🎬 Session. Entries group under day
  headers, newest first; swipe to delete.
- **Song notes are front and centre** (ADR 0038). A song's free-text **notes** (tuning,
  capo, anything to remember) now show in a **Notes** section right under the title/artist/
  album header when you open a song's details. Tap the **pencil** to edit them right there
  (no full-Edit detour), then **Update** to save — with a quick "Saved" confirmation.

### Changed
- **Mastery, command tempo and focus start "unset"** (ADR 0039). Previously a brand-new
  loop quietly claimed **100% command tempo** and a zero mastery — ratings you never gave.
  Now all three start blank and only show a value once you set one. In the loop edit sheet:
  tap a **Mastery** dot down past the first to clear it back to *Unrated*; **Command tempo**
  shows a **Set** button until you measure it (then a **Clear** to unset); **Focus** is now
  a dropdown with a *Not set* option. A song's overall mastery is the average of its
  **rated** loops only, so one untouched loop no longer drags the summary down.
- **Markers drop instantly now — no naming step** (ADR 0037). Tapping **Mark** drops
  the marker straight away with a standardised name ("Marker 3"), the same way loops
  are created; rename it later by tapping its row. The old "name this marker" pop-up is
  gone, so you can keep listening and signpost a song without stopping to type.
- **Tapping a marker plays from there** (ADR 0037). Selecting a marker in the markers
  list now seeks to it **and starts playback**, so you immediately hear the spot you
  marked instead of having to hit play.
- **Hold a marker row to edit it** (ADR 0037). Marker rows now match loop rows: the
  edit pencil is gone — **tap** a marker to jump to it, **press and hold** to open its
  settings (rename / delete).

### Fixed
- **Loop Type is selectable again.** In the loop edit sheet, the **Type** picker
  (Lick / Riff / Chords / Passage) did nothing when tapped because the sheet opens
  part-height and the picker tried to push a full-screen options list that the
  partial sheet swallowed. It's now an in-place dropdown that works at any height.

### Added
- **Loop tags** (ADR 0034). Editing a loop now has a **Tags** section — add short
  descriptive tags like `solo`, `needs-work`, or `chorus`, with tappable chips suggesting
  tags you've already used on other loops so the same tag is reused instead of re-typed
  (and spacing/capitalisation tidies up automatically). Tags are saved on each loop now;
  filtering across songs by tag arrives later with the session planner.
- **Loop practice details** (ADR 0036). Editing a loop now has a **Practice** section:
  **Mastery** (a 0–5 rating of how cleanly you own it — this is what rolls up into the
  song's mastery), **Focus** (Backburner / Active / Sharpening — how hard you're working
  it right now), **Type** (Lick / Riff / Chords / **Passage** — a longer stretch that
  mixes more than one of those), and **Command tempo** (the fastest tempo you can play it
  at, as a % of the original). Loops you already had keep working and start at sensible
  defaults.

### Changed
- **Clearer library sorting + tidier header** (ADR 0035). The toolbar now spells out
  **what the list is sorted by** (e.g. "↑ Title") instead of a generic icon, and you can
  **flip the order** (ascending ⇄ descending) from the same menu. The collection chips that
  sat across the top have moved into a **filter menu** (the funnel button), so the header is
  cleaner while filtering by collection still works.
- **Hold a song to edit it.** Press and hold a song card in the library for its actions —
  **Edit** opens the metadata sheet, **Delete** removes it. (Swipe still offers a quick
  Delete, and tapping a card still opens it for practice.)
- **Song key is now a picker, not free text** (ADR 0036). The edit sheet's **Key** field is a
  closed list of the 12 keys in major and minor (plus **Unknown**), so keys stay consistent and
  the app can sort and reason about them. Existing typed-in keys are matched automatically —
  `"A minor"`, `"Am"`, `"Bb"` all map to the right key — and shown as a tidy label like
  **A minor**; anything it can't recognise reads as **Unknown**.
- **Song mastery is now derived from your loops** (ADR 0036). What used to be a song's
  manually-set **Proficiency** stars is replaced by **Mastery** — the rounded average of
  the song's loops' mastery — shown on the practice screen, song details, and library
  cards. A song with no loops reads as **Unrated**. The library's **Group by → Proficiency**
  becomes **Group by → Mastery** and gains an **Unrated** section. The song edit sheet drops
  the proficiency star input (mastery is now read-only at the song level) and the
  **Progression** field.
- **Genre tidies up as you type** (ADR 0036). When you edit a song's **Genre**, it's
  trimmed of stray spaces and snapped to a genre you've already used if it matches
  (so `blues` becomes `Blues` if that's how you spelled it elsewhere) — keeping the
  library's **Group by → Genre** from splitting one genre across several near-duplicate
  spellings.

### Removed
- **Song "Progression" field** (ADR 0036) — it was free text standing in for chord
  structure, which is really per-section; the song **Key** covers the song-level summary
  and a future per-loop chord field will cover the rest.

### Changed
- **Redesigned song library** (ADR 0035). The library is now a list of richer **song
  cards** — title, **artist**, a metadata line (key · BPM · loop/marker counts), collection chips,
  proficiency dots, and a colour accent that reflects how polished the song is — with a
  **Group by** control (⬍ in the toolbar) to organise by **Proficiency · Recently Added ·
  Title · Artist · Album · Genre**, plus a **search** field for title/artist. No cover
  art; the data does the talking. The collection filter still sits above the list.

### Added
- **Song genre** (ADR 0035). The song edit sheet gains a **Genre** field (typed in, not
  read from the file). It feeds the upcoming "group by genre" in the library; songs are
  also now stamped with an import date for "Recently Added" grouping.
- **Filter the library by collection** (ADR 0033). The song list gains a row of
  collection chips; tap one (or several) to narrow the library to songs in **all** the
  chosen collections, **All** to clear. An empty result shows a clear "no songs in this
  collection" state with a one-tap reset.
- **Collection suggestions** (ADR 0033). The song edit sheet now offers the collections
  you already use elsewhere in your library as tappable chips — tap one to add it
  (in its canonical spelling) instead of re-typing, so songs converge on the same
  collection names. Collections already on the song aren't re-offered.

### Changed
- **Collections no longer fragment** (ADR 0033). Adding a collection to a song now
  tidies whitespace and de-duplicates case-insensitively, so `Blues`, `blues`, and
  `blues ` are treated as the same collection (the first-seen spelling is kept) instead
  of becoming three. Shared with the upcoming loop **Tags** (ADR 0034).

### Added
- **Choose a loop's colour** (ADR 0031). The loop edit sheet gains a **Colour** row —
  an **Auto** swatch (the automatic colour, as before), the preset palette, and a
  **custom colour wheel** (the trailing rainbow swatch) for any other colour. Pick one
  to pin a loop's colour everywhere it shows (waveform, minimap, transport strip); pick
  Auto to go back to the automatic, all-distinct assignment. A custom colour that's hard
  to see on the dark background shows a low-contrast hint (but is still allowed). A
  manual choice can match another loop's colour — overlap still reads by lane on the
  waveform.
- **Transport playback controls** (ADR 0030). The transport bar gains a
  **rewind · pause · forward** cluster. With a loop active: rewind restarts it
  (double-tap → previous loop), forward jumps to the next loop. With no loop:
  rewind restarts the song; previous/next *song* is coming in a follow-up, so those
  buttons dim for now. Skips keep your play/pause state.
- **Clearer active-loop signal** (ADR 0030). When a loop is armed, a vertical strip
  in the loop's own colour appears on the right of the transport bar with an ✕ to
  deactivate it — so it's obvious at a glance whether you're looping a region or
  playing the whole song. The bar's centre shows the loop name + range when looping,
  or the live playhead time on the full song.
- **No accidental exit while scrubbing** (ADR 0030). Adjusting the playhead near the
  left edge no longer triggers the swipe-back to the library; the edge gesture is
  suppressed only while your finger is on the waveform.

### Changed
- **Transport action buttons are now identity controls** (ADR 0030). Loop / Mark / Fine
  drop their text captions for a glyph in a circle (green repeat / pink triangle / blue
  calipers; the active one's circle fills with its colour), freeing room for the
  playback cluster.
- **Practice opens on the full song** (ADR 0029). Entering a song no longer silently
  arms its first saved loop — playback starts on the whole song at 1.0×, and a loop
  only arms when you tap its row, punch a new one, or run an automator. Leaving the
  screen wipes the transient session state (active loop, speed, click, mode); your
  saved BPM, downbeat, loops, and markers are untouched. Deleting the loop you're
  hearing now plays through the song instead of jumping to another saved region.
- **Minimap snaps to markers & loop edges** — releasing a tap or drag on the full-song
  minimap now catches a nearby **marker** dot or **saved-loop boundary** (light haptic),
  so jumping to a marked spot or a loop edge lands exactly on it. The live scrub still
  tracks your finger un-snapped; only the release catches, and beats are excluded (the
  compressed strip is too dense for the grid).
- **Loop rows are tidier** (ADR 0028). The always-visible **edit pencil** is gone —
  **press and hold a loop** (with a haptic) to open its edit sheet, where you rename,
  adjust the range, or delete it. The "A" automator control stays where it was. The
  loop edit sheet itself dropped its **Speed** and **Repeats** controls — those live
  in the automator now, so the sheet is just Name · Range · Delete.
- **Transport rework** — the practice cockpit is tidier (ADR 0027). The **Click**
  toggle moved off the transport bar to sit next to the **BPM** readout on the speed
  bar, in its own teal colour, so it reads as a tempo tool instead of another play
  button. The **Fine** button's icon changed to a calipers glyph ("drag the edges").
  The transport action bar is now **Loop · Mark · Fine**; the active loop's name/range
  and its ✕ exit stay in the transport's top row (a better loop-exit affordance is still
  on the drawing board).

### Added
- **Hold the song title for details** — press and hold the title/artist at the top of
  the practice screen (with a haptic) to open a **read-first song details** view: a
  descriptive overview of the song's key, tempo, proficiency, progression, length,
  collections, notes, and practice stats. It reads as information, not a form; **Edit**
  in the corner opens the metadata editor when you want to change something. The song
  strip's top-right now shows the **proficiency stars** (above the length) instead of the key.
- **Haptic on the BPM hold** — holding the **BPM** readout to re-open the tempo editor
  now confirms the hold with a haptic, matching the loop-row and title holds.
- **Metronome click** — a new **Click** button on the transport plays a metronome
  over the song, accenting the downbeat. It **rides the song and follows the speed
  control**: at 50% it clicks at 50% of the song's BPM, locked to the slowed track;
  speed it up and the click keeps pace. It's there to play along to and never
  changes the song's saved BPM (that's what the tempo editor is for). Available once
  the song has both a tempo and the 1 set. ADR 0026.
- **Set the 1 by playing along** — placing the downbeat on the waveform now has a
  **Play/Pause** and a **"Tap the 1"** button: play the song and tap the moment you
  feel the downbeat, and it drops the 1 at the playhead (nudged onto the nearest
  transient) and pauses so you can fine-tune or confirm — more intuitive than scrubbing
  to a peak. Dragging the handle still works. After you confirm (or cancel) the 1, you
  now return to the tempo editor instead of being left on the waveform, and the editor
  shows the downbeat you just set.

- **Estimate the tempo & downbeat from the audio** — the tempo editor now has an
  **"Estimate from audio"** button that analyses the track's onsets on-device and
  prefills both the **BPM** and **the 1** (the downbeat), flagged as estimates for
  you to confirm or adjust. The tempo can land on half/double time and the 1 can sit
  a beat off, so neither is trusted blindly (and the speed control never depended on
  it) — rung 2 of ADR 0004's BPM fallback chain. Not available for the built-in demo
  sample (no source file to analyse).
- **Lock-screen play/pause & stop-on-exit** — practice audio now appears on the
  **lock screen and Control Center** (song title, artist, and a working
  play/pause), so you can pause without unlocking. Leaving the practice screen now
  **stops playback** immediately rather than letting it linger. Backgrounding or
  locking the phone *while practising* keeps the audio going. Play/pause only —
  no scrub or skip on the lock screen (the waveform is where you seek). ADR 0025.
- **Set the tempo by ear** — the **"Set BPM"** affordance now opens a tempo editor.
  **Tap** along to the beat and it reads your tempo from the playhead (so tapping
  inside a loop or at a slowed-down speed still finds the song's true tempo), or
  type it in **Manually**. To place **the 1** (the downbeat the beat grid needs),
  drag a handle onto a snare/kick **peak on the waveform** — it snaps to the loudest
  nearby transient (zoom in for finer placement) — or "Mark the 1" at the playhead.
  Tempo is now stored at full precision so the grid doesn't drift across a long
  song. Long-press the BPM readout to re-open the editor and correct it. ADR 0024.
- **Beat grid & snap to the beat** — give a song a **BPM** and a **downbeat** (the
  seconds where bar 1 lands, set on the song's edit sheet next to BPM) and the
  waveform draws a faint **beat grid** — thin lines per beat, brighter on the bar
  starts. Releasing a drawn loop edge, a Fine handle, or a tap-seek then **catches
  the nearest beat** as well as markers and loop edges, so loops start and end on
  the pulse. The grid thins out automatically when you zoom out so it never smears.
  No downbeat set ⇒ no grid (we don't guess where bar 1 is). Assumes 4/4. ADR 0022.
- **Loops and seeks snap to what you can see** — when you release a drawn loop edge,
  drag a Fine handle off a blue dot, or tap to seek, the boundary now **catches a
  nearby marker or saved-loop edge** if you land close to one (a light haptic
  confirms the catch). The catch zone is a constant size on screen at any zoom and
  it's tight enough to assist, not hijack — land clear of a marker and nothing snaps.
  Scrubbing and the minimap stay free. ADR 0021.
- **Draw a loop right on the waveform** — in Navigate mode, **press and hold, then drag**
  to paint a loop region (a haptic confirms when the hold arms). The region **starts at
  the playhead** and grows out to your finger, so the hold-drag punches a loop in where
  playback is (just like the **Loop** button) and the drag sets the other end. Release and
  the region becomes a confirmable loop — auto-named and looping at once on **Y**, like a
  punch. A quick drag still scrubs and a tap still seeks; only a deliberate hold starts a
  selection. ADR 0005 (round 5).

### Changed
- **New blue look** — the waveform **bars are now blue** (anchored on `#2a6796`) on
  the near-black background, so the song reads as its own themed surface. Green is kept
  for the **live state** (playing / the loop you're capturing) and Fine-mode precision
  is cyan, so each still reads apart from the bars. ADR 0023.
- **Clearer loop confirm/discard** — when you capture a loop, the confirm/discard
  pair is now a **green ✓ and a red ✗** (was a blue/red Y/N). ADR 0023.
- **Loops and markers now sit on the borders, off the song** — the saved-loop
  indicators and markers no longer draw over the waveform bars. Markers are **purple
  inverted triangles** along the top edge; each saved loop is a **coloured line** along
  the bottom edge, **stacked into rows when loops overlap**. ADR 0023.
- **Every loop has its own colour** — saved loops are now distinguishable at a glance,
  each drawn in its own hue (the active loop heavier and full-strength, parked loops
  lighter). Overlap is still shown by row position. ADR 0023.
- **The minimap matches the waveform's loop colours** — the loop underlines on the
  full-song minimap now use each loop's **identity hue** (and the active loop's region
  is washed in its own colour), instead of all reading flat orange. A loop is the same
  colour in the overview as in the detail waveform. ADR 0023.
- **Fine-mode handles read clearly** — the precise-edit handles now draw **in front of
  the waveform bars** (they used to be partly hidden behind them) and are a **high-contrast
  cool white** instead of the old cyan, which blended into the blue bars. The "1" downbeat
  handle picks up the same colour. (Flagged for revisiting in a future theme pass.) ADR 0023.
- **The Mark button matches the markers** — the transport "Mark" icon is now an **inverted
  triangle**, the same shape markers take on the waveform (was a map-pin). ADR 0023.
- **Deep zoom now shows real detail, not stretched blocks** — when you pinch in close,
  the waveform **re-reads that slice of the song from the file** and draws it at full
  resolution, so individual note onsets and transients resolve where you're working
  (it used to just stretch the whole-song envelope, so a deep zoom looked chunky). The
  refresh is debounced and cached, and falls back to the stored envelope while it
  computes. ADR 0020.
- **Zoomed waveform now reads like GarageBand** — when you pinch to zoom in, the
  window **holds still** and the **playhead sweeps across it**, paging forward when it
  reaches the edge (it used to pin the playhead to the centre and slide the whole
  waveform underneath, which stuttered and made the playhead look frozen). A **Fit**
  button appears in the corner while zoomed to snap back to the whole song. ADR 0010.
- **Loops are created instantly — no naming step, and they start looping.** Confirming
  a captured region (**Y**) now creates the loop immediately, **auto-named** ("Loop 3"),
  active, **and playing** — it loops straight away without a separate tap on ▶. Rename it
  later from its row. The pop-up naming sheet is gone. Markers still ask for a name
  (a marker *is* its label). ADR 0019.
- **Waveform reads musically** — the per-bar envelope is now **energy-based and
  transient-resistant** instead of peak: each bar takes the median of several short
  RMS sub-windows, so it tracks the sustained level of the music and steps over
  rhythmic spikes (a snare no longer dominates the picture), then normalises to a
  high percentile rather than the single loudest sample. Brick-walled masters that
  used to render as a flat block now show verses dipping and choruses swelling. The
  stored resolution also grew (240 → 512 bars) for finer detail. Songs imported
  before this **re-extract their waveform automatically** the next time you open
  them. ADR 0017.

### Fixed
- **Pinch-to-zoom no longer moves the loop bounds in Fine mode** — when you pinched to
  zoom while adjusting a loop's handles, the first pinch finger grabbed a handle and
  nudged the boundary. The handle now snaps back to where it was grabbed the moment a
  pinch takes over, so zooming and bound-adjustment stay independent.
- **Haptics feel instant** — gesture buzzes (tap-tempo taps, loop catches, confirms)
  no longer lag on the first tap. The Taptic Engine is now kept warm via a cached,
  pre-prepared feedback generator instead of being re-allocated cold on every call,
  and the tempo editor warms it up front when it opens.

### Added
- **Undo a delete** — deleting a loop or marker now shows a **"Deleted X · Undo"**
  toast for a few seconds; tap **Undo** to bring it back exactly as it was (same
  identity, and re-activated if it was the active loop). ADR 0019.
- **See your whole loop & marker library on the waveform** — the detail waveform and
  minimap now draw **all** saved loops and markers, not just the active one. Markers
  hang as **pins from the top**; loops sit as **brackets along the bottom**. When loops
  **overlap or nest**, they **stack into lanes** (the later one drops a row) so overlap
  reads by position — colour stays reserved for state, with the **active loop** drawn
  brighter (plus its usual fill). ADR 0018.
- **Automator — per-loop speed trainer** — each loop row now has an **"A" control**
  (replacing the old speed·repeats text). Set a **start %**, a **target %**, how many
  **steps** to get there, and how many **loops per step** — the loop then ramps its speed
  in even steps as it repeats, plays its passes at the target, and **stops on its own**
  once the ramp's last automated pass has played (then rewinds, ready to run again). It
  climbs *or* descends (target below start = a slow-down trainer), or sits **level** when
  start = target; the per-step change is shown for you ("+5% each"). The setup sheet is a
  visual **ramp** with a climbing / falling / flat graphic and **BPM** equivalents when the
  song's tempo is known; **Set ramp** arms it **and starts the loop playing** from the top,
  a full-width red **Turn off ramp** disarms, and grabbing the speed slider hands control
  back. The stepping is pure, unit-tested math (`AutomatorConfig`); the engine counts loop
  wraps in source frames so the steps stay evenly spaced across speed changes. ADR 0013.
- **Song metadata editing** — **swipe a library row → Edit** to open a metadata sheet
  (`SongEditSheet`): title, artist, **album**, **year**, key, BPM, proficiency
  (tappable stars), and progression; **collection tags** (add / swipe-to-remove); a
  free-form **note**; and read-only **practice stats** — *Loops · Markers · Annotations*
  (annotations = loops + markers). The song record is where we enrich the data that
  drives practice routines. Filename-derived suggestions, a practice **journal**, and
  collections-as-playlists are planned next. ADR 0012.
- **Loading state when opening a song** — the practice screen now dims with a
  **spinner + "Loading song…"** while the audio file opens, instead of looking frozen.
  The file open (and the demo render) moved **off the main actor**, so the UI stays
  responsive on slow/iCloud reads and the overlay also blocks taps on the half-ready
  controls until playback is ready.
- **Song library + file import** — the app now opens to a **library** of your songs
  (`LibraryView`). Import any DRM-free local/iCloud **audio file** (the `+` button, or
  the empty-state button): Pocket takes a **security-scoped bookmark** for durable
  access, **extracts the real waveform** up front (`WaveformExtractor`), and persists it
  as a `Song` you open and practice with its **actual audio**. A first-run **empty
  state** offers Import or a bundled demo, retiring the auto-seeded arpeggio. The title
  defaults to the file name; richer metadata editing is next. ADRs 0011 (Slice 2) & 0001.
- **Persistence (SwiftData)** — loops and markers now **survive relaunches**. The
  domain (`Song` / `Loop` / `Marker`) is SwiftData `@Model`s, replacing the in-memory
  `WaveformMock`; the practice screen binds to a persisted `Song` via the model context.
  A CloudKit-ready foundation for the library, routines, and sync still to come. ADR 0011.
- **Pinch-to-zoom the waveform** — pinch the detail waveform to zoom into a section.
  The view **tracks the playhead**, so you navigate by seeking (tap / scrub / minimap)
  and the waveform follows — no separate pan gesture. The minimap **viewport box
  returns**, now live, showing the visible slice. The zoom + screen↔song-fraction
  mapping is pure, unit-tested math in `WaveformGesture`. ADR 0010.
- **Region looping** — an active loop now actually loops: playback wraps from the
  loop's end back to its start continuously and **seamlessly** — gapless *and*
  click-free, via a pre-rendered loop buffer whose seam is equal-power
  **crossfaded** (`AudioMath.crossfadeGains`) and played on `.loops` (boundary math
  in unit-tested `AudioMath.loopSegment`, wrap math in `AudioMath.loopedPlayhead`).
  A loop just loops (no on/off toggle — the per-loop `repeats` count is reserved for
  the future automator); a small **✕ exit chip** by the loop name returns to
  full-song playback. Decisions in ADRs 0006 & 0008.
- **Loop edit mode is now a distinct, modal state.** While creating or adjusting a
  loop the **transport bar greys out and locks**, and the mode-instructions line is
  replaced by an **edit toolbar**: a ▶︎ **audition** button (loop the captured region
  to hear it before saving — for Tap *and* Fine loops), a state label (**"New loop"**
  / **"Editing loop"**), and a **Y/N** decision (green **Y** = save, red **N** =
  discard — letters instead of ✓/✗ so they can't be mistaken for the loop's name).
  You leave edit mode via Y/N, not by switching modes.
- **Live loop-range preview** — adjusting a loop's bounds in Fine mode auditions the
  new region on handle-release (you hear only the edited loop, not the saved one);
  discarding restores the saved bounds.

### Fixed
- **Pinch-to-zoom no longer jumps the playhead** — finishing a pinch used to fire a
  stray tap-to-seek (and the spread could scrub mid-pinch), because the tap gesture
  only knew a pinch was happening while it was *mid*-pinch. The waveform now latches
  that a pinch occurred for the whole touch and swallows the trailing seek/scrub.

### Changed
- **Naming a new loop or marker is now just a name** — no position/range readout and
  no delete button (Cancel already discards a brand-new one). A dropped marker isn't
  added until you save it. Editing an *existing* loop/marker keeps the full sheet
  (range/position, playback, delete). The transport's **Loop and Mark buttons swapped**
  positions (Loop first).
- **Waveform interaction rationalised** (after pinch-zoom surfaced gesture clashes):
  **tap now seeks everywhere** — Scroll and Tap modes collapse into one *Navigate*
  behaviour (tap = seek · drag = scrub · pinch = zoom). Capturing at the playhead moves
  to **buttons on the transport**: **Mark** (drop a marker), **Loop** (punch in/out), a
  **Fine** toggle (precise handle-editing), and a reserved **Auto** slot for the future
  automator. The **hold-to-drop-marker** gesture is gone (it raced with pinch). The
  **time ruler now follows the zoom**, labelling the visible window. ADR 0005 (round 4).
- **Transport bar slimmed further** — tighter vertical spacing/padding and a smaller
  play control, to reclaim cockpit height. The freed space is reserved for the future
  automator entry (see ADR 0009).
- **Minimap viewport box hidden** until pinch-to-zoom exists — the detail waveform
  always shows the whole song for now, so the box was static and meaningless; it
  returns (live) with zoom. (`song.viewport` data retained.)
- **Practice screen refactored to a view model** (no behaviour change): state and
  the gesture/loop handlers moved out of `WaveformPracticeView` into an
  `@Observable` `WaveformPracticeModel` (+ `…+Actions` extension). The view drops
  from the SwiftLint file-length limit (400 → ~130 lines), making room for the
  next features. Decisions in ADR 0007.
- **Transport bar simplified**: the **"+" quick-capture** and the per-loop
  **repeat/clear controls** are gone — loop creation is owned by the Tap/Fine
  gestures, and an active loop simply loops (the explicit toggle was redundant;
  real region looping lands on a later branch). When a loop is active the
  transport now shows its **name** over its time range.
- **Confirm pill** is smaller and now lives on the **mode-instructions row
  (trailing)** in every mode, instead of floating over the waveform. On a Tap
  second-punch the captured loop **stays highlighted green** while you confirm.
- **Cockpit chrome slimmed**: the speed/tempo bar is more compact (smaller `×`
  readout, tighter spacing) and the minimap is shorter. The **minimap is now
  seekable** — tap or drag anywhere on it to move the playhead (also VoiceOver-
  adjustable), reclaiming vertical space in the pinned cockpit.
- **Loop capture flow refined** (2nd round of on-device feedback): the keyboard-
  free confirm step is now an **icon-only ✓/✗ pill floating over the waveform**
  (the old bar read as if the name were editable there). **Tap mode is now punch
  in/out** — taps mark the loop at the *current playhead* and never move it; only
  dragging scrubs. Discarding the name from a **Fine** selection now **keeps the
  selection** (handles + pill return) so it can be re-adjusted. ADR 0005 updated.
- Renamed the product from "Ore" to **Pocket** (module, targets, bundle id
  `click.decooperations.pocket`, repo `pocket-ios`, all docs). Dropped the
  Yoruba "friend" etymology, which no longer applies to the new name.
- Waveform practice screen restructured into a **fixed practice cockpit**
  (song strip, speed bar, waveform, ruler, minimap, transport) over a
  **scrollable reference area** (loops, markers, song info). Song info is
  demoted to the bottom, collapsed by default. See ADR 0003.
- Temporarily launch the app straight into the waveform practice screen (reverts
  to the home/planner once navigation lands in Phase 3).

### Fixed
- `project.yml` no longer regenerates (overwrites) the hand-maintained
  `Info.plist` — the stray `info:` block was dropping the Apple Music usage
  string, background-audio mode and portrait lock on every `xcodegen generate`.

### Added
- **Waveform gesture engine — UX polish** (from on-device feedback): Scroll mode
  now **drags to scrub** the playhead (tap still jumps, hold still drops a
  marker); Tap mode **plays a preview** from the first tap, filling the loop
  region green, and stops on the second; a live **time bubble** rides the
  playhead in every mode. Loop capture is now a keyboard-free **confirm bar
  (✓/✗)** that opens a native **naming sheet** (no more keyboard hiding the
  field). Loop & marker lists are **unified** — tap a row to use it (activate
  loop / seek to marker), edit via a trailing pencil. An existing loop's range
  can be **adjusted in Fine mode** via "Adjust range" (the reference area dims to
  focus the waveform). Name fields gained a **clear (✕)** button. ADR 0005 updated.
- **Waveform gesture engine** — the three transport modes are now live on the
  waveform: **Scroll** taps to seek and holds 650 ms (amber ring) to drop a
  marker; **Tap** drags to scrub and two taps capture a loop; **Fine** drags two
  blue handles to set loop bounds. Loop capture is named inline as before. The
  pure gesture math (point→fraction, bound ordering + min width, handle
  hit-testing) lives in unit-tested `WaveformGesture`. The transport **+** button
  remains as an accessible quick-capture. Decisions in ADR 0005.
- **Waveform practice screen** (Phase 1 skeleton) — SoundCloud-style mirrored
  waveform, speed/BPM bar, time ruler, minimap, transport bar with Scroll/Tap/
  Fine mode pills, all on the design tokens. Driven by mock data; audio engine,
  gestures and the asymmetric speed scale are later iterations.
- Loops & markers panels with **named, editable** entries: tap a row to edit
  (name/speed/repeats/delete) via a native sheet; activate a loop from its
  trailing play button. ADR 0003 records the interaction decisions.
- **Naming-on-capture** — capturing a loop slides in an inline creation panel
  below the transport (name field + range + Save/Discard, with a Reduce Motion
  fallback). Capture is triggered by a transport **+** button standing in for
  the Tap/Fine waveform gesture until the gesture engine lands.
- **Empty states** for the Loops and Markers panels (with hints that teach the
  real interaction), and an **unknown-tempo** state: `Song.bpm` is now optional
  and the speed bar shows a "Set BPM" affordance when it's absent — the speed
  multiplier works regardless. BPM derivation strategy recorded in ADR 0004.
- **Audio playback engine** (`PracticeAudioEngine`): real play/pause, seek, and
  pitch-preserving speed via `AVAudioUnitTimePitch`, with a live playhead. The
  practice screen's transport, speed bar and playhead are now driven by actual
  audio. A generated arpeggio (`SampleToneGenerator`) is the dev source (real
  file import is a later piece), and the waveform is downsampled from it.
  Pure helpers in `AudioMath` are unit-tested.
- SwiftUI `#Preview`s for the screen and each component (`WaveformPreviews`).
- Project scaffold (Phase 0): repo structure, XcodeGen `project.yml`, SwiftLint
  config, GitHub Actions (lint + build + test on PR; TestFlight on merge),
  Fastlane stubs.
- `SongRef` — source-agnostic song identity (local files + Apple Music), unit-tested.
- `TempoMath` — pure tempo/speed-slider/automator math, unit-tested.
- Design tokens, app entry point, placeholder home screen.
- Governance docs: `AGENTS.md`, `PROJECT.md`, `docs/architecture.md`, ADRs 0001–0002.
- `docs/design-brief.md` — self-contained design brief + working protocol for
  designing the UI with Claude (design system contract, screen inventory,
  per-screen request template, definition-of-done).
- Infrastructure stub for the Phase 4 Claude proxy.