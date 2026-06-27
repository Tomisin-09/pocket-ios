# Changelog

All notable changes to Pocket are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); this project is pre-release.

## [Unreleased]

### Changed
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
  end.
- **Loops are trainable units in Practice** (ADR 0046, Phase B, slice 3). The Practice "Your units"
  list now aggregates **both** kinds of unit: your exercises *and* any song loop you've measured (a
  loop with a command tempo), each shown with its song as context and its command → reach. Tapping
  a loop opens the loop training run. This is the multi-source "things you train" surface the V2
  planner will compose sessions from — one place, two altitudes.

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