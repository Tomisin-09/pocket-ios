# Shot manifest

**Generated — do not edit.** Every row here comes from a `<!-- shot: -->` marker in the pages, and
the file is rewritten by:

```sh
./scripts/check-manual.py --write-shots
```

Hand-keeping this list is the failure it exists to prevent: a manifest maintained separately from
the prose drifts from it within one slice, and the shoot then works from the stale copy. `crop` is
filled in at shoot time against the chosen master and is not authored with the prose — see the
marker grammar in [README.md](README.md).


| Shot | Role | Page | State to seed | Needs a device |
|---|---|---|---|---|
| `exercises/configure` | `screen` | `exercises` | New exercise sheet, Warm-up template chosen, top of the configure step |  |
| `exercises/freeform-run` | `screen` | `exercises` | seeded library, a hand-authored freeform exercise, running |  |
| `exercises/library` | `screen` | `exercises` | seeded library, Practice ▸ Exercises, several templates present |  |
| `exercises/practice-settings` | `panel` | `exercises` | seeded library, an exercise run screen, Practice Settings expanded |  |
| `exercises/run-complete` | `screen` | `exercises` | seeded library, an exercise run finished naturally |  |
| `exercises/run-live` | `screen` | `exercises` | seeded library, an exercise run screen, running past the count-in |  |
| `exercises/run-setup` | `screen` | `exercises` | seeded library, Exercises, "Alternate Picking" opened, stopped |  |
| `exercises/staircase` | `band` | `exercises` | seeded library, an exercise run screen, staircase visible |  |
| `exercises/template-picker` | `screen` | `exercises` | New exercise sheet, template picker, guitar selected |  |
| `gestures/carry-tempo` | `panel` | `gestures` | seeded library, Slow Bend, player idle, BPM readout held |  |
| `gestures/loop-controls-popover` | `panel` | `gestures` | seeded library, Slow Bend, player idle, Loop controls tapped |  |
| `gestures/row-hold-menu` | `panel` | `gestures` | seeded library, Library screen, row "Binta" held |  |
| `gestures/speed-bar` | `band` | `gestures` | seeded library, Slow Bend, player idle |  |
| `gestures/undo-toast` | `band` | `gestures` | seeded library, Library screen, a row swiped left and deleted |  |
| `getting-started/first-run` | `screen` | `getting-started` | fresh install, first launch, step 1 of 4 |  |
| `getting-started/home` | `screen` | `getting-started` | seeded library, Home, morning greeting |  |
| `getting-started/import-picker` | `screen` | `getting-started` | seeded library, Home, + tapped |  |
| `getting-started/loop-active` | `band` | `getting-started` | seeded library, Slow Bend, a loop active and repeating |  |
| `journal/month-heatmap` | `panel` | `journal-and-practice-log` | seeded library, Practice log, two or more weeks of history in the current month |  |
| `journal/progress` | `screen` | `journal-and-practice-log` | seeded library, Practice log, several weeks of practice history |  |
| `journal/quick-note` | `screen` | `journal-and-practice-log` | an exercise run screen, quick note tapped |  |
| `journal/quick-note-button` | `glyph` | `journal-and-practice-log` | — |  |
| `journal/record-arm` | `glyph` | `journal-and-practice-log` | — |  |
| `journal/take-detail` | `screen` | `journal-and-practice-log` | seeded library, Journal, a take opened |  |
| `journal/take-moments` | `screen` | `journal-and-practice-log` | seeded library, Journal, a take opened |  |
| `journal/take-row` | `detail` | `journal-and-practice-log` | seeded library, Journal, Takes filter, at least one take |  |
| `journal/take-trim` | `screen` | `journal-and-practice-log` | seeded library, Journal, a take opened, Trim tapped |  |
| `journal/timeline` | `screen` | `journal-and-practice-log` | seeded library, Journal, several notes and one take across two days |  |
| `looping/ab-forming` | `band` | `looping` | seeded library, Slow Bend, playing, loop start dropped, end not set |  |
| `looping/automator` | `screen` | `looping` | seeded library, Slow Bend, loop "Verse riff", automator open |  |
| `looping/loop-active` | `band` | `looping` | seeded library, Slow Bend, loop "Verse riff" active and repeating |  |
| `looping/loop-edit-practice` | `panel` | `looping` | seeded library, Slow Bend, loop "Verse riff" edit sheet, scrolled to Practice |  |
| `looping/multi-select` | `panel` | `looping` | seeded library, Slow Bend, Loops panel header held, two loops selected |  |
| `looping/speed-bar` | `band` | `looping` | seeded library, Slow Bend, speed reduced below 100% |  |
| `looping/tempo-editor` | `screen` | `looping` | seeded library, Slow Bend, tempo editor open |  |
| `metronome/automator` | `panel` | `metronome` | Metronome open, automator armed By Bars |  |
| `metronome/screen` | `screen` | `metronome` | Metronome open, 96 BPM, 4/4, stopped |  |
| `metronome/settings-sheet` | `screen` | `metronome` | Metronome open, meter control tapped, scrolled to the top |  |
| `metronome/tempo-controls` | `band` | `metronome` | Metronome open, 96 BPM |  |
| `privacy/settings` | `panel` | `privacy` | Settings ▸ Privacy |  |
| `reference/exercises-library` | `screen` | `practice` | seeded library, Practice ▸ Exercises, the seeded six present |  |
| `reference/home` | `screen` | `home-and-library` | seeded library, Home, one song recently practised |  |
| `reference/journal` | `screen` | `tools-and-journal` | seeded library, Journal, notes and a take across two days |  |
| `reference/library` | `screen` | `home-and-library` | seeded library, Library, sorted by title |  |
| `reference/library-row-menu` | `detail` | `home-and-library` | seeded library, Library, a row held |  |
| `reference/long-term-goals` | `screen` | `practice` | seeded library, Practice ▸ Long-term goals, two goals ranked |  |
| `reference/loop-automator` | `screen` | `song-player` | seeded library, Slow Bend, automator opened on "Verse riff" |  |
| `reference/loop-edit` | `screen` | `song-player` | seeded library, Slow Bend, loop "Verse riff" held, Edit loop |  |
| `reference/loops-library` | `screen` | `practice` | fresh library with no measured loops, Practice ▸ Loops |  |
| `reference/loops-panel` | `panel` | `song-player` | seeded library, Slow Bend, Loops expanded |  |
| `reference/metronome` | `screen` | `tools-and-journal` | Metronome open, stopped |  |
| `reference/metronome-settings` | `screen` | `tools-and-journal` | Metronome open, meter control tapped, scrolled to the top |  |
| `reference/planner` | `screen` | `practice` | seeded library, Practice ▸ Today, no goals yet |  |
| `reference/player` | `screen` | `song-player` | seeded library, Slow Bend, idle, Loops panel expanded |  |
| `reference/practice-hub` | `screen` | `practice` | seeded library, Practice hub, goals and routines present |  |
| `reference/progress` | `screen` | `tools-and-journal` | seeded library, Practice log, several weeks of history |  |
| `reference/quick-note` | `screen` | `tools-and-journal` | an exercise run screen, quick note tapped |  |
| `reference/routines-library` | `screen` | `practice` | seeded library, Practice ▸ Routines, at least one routine run before |  |
| `reference/settings-hub` | `screen` | `settings` | Settings open |  |
| `reference/settings-privacy` | `panel` | `settings` | Settings ▸ Privacy |  |
| `reference/settings-routines` | `panel` | `settings` | Settings ▸ Routines |  |
| `reference/settings-sound` | `panel` | `settings` | Settings ▸ Sound & feel |  |
| `reference/settings-you` | `screen` | `settings` | Settings ▸ You |  |
| `reference/song-details` | `screen` | `home-and-library` | seeded library, Slow Bend, Details from the row hold menu |  |
| `reference/song-edit` | `screen` | `home-and-library` | seeded library, Slow Bend, Edit from the row hold menu |  |
| `reference/tempo-editor` | `screen` | `song-player` | seeded library, Slow Bend, tempo editor open |  |
| `reference/toolkit` | `screen` | `tools-and-journal` | Toolkit open |  |
| `reference/tuner` | `screen` | `tools-and-journal` | Toolkit ▸ Tuner, microphone allowed |  |
| `references/editor` | `screen` | `references` | seeded library, an exercise detail sheet, Add a link tapped |  |
| `references/section` | `panel` | `references` | seeded library, an exercise detail sheet with two links saved, one of them carrying a note, scrolled to the section |  |
| `routines/block-done` | `screen` | `routines` | seeded library, a routine mid-session, a block just finished |  |
| `routines/block-record` | `detail` | `routines` | seeded library, Practice ▸ Routines ▸ Morning Routine, first block opened |  |
| `routines/editor` | `screen` | `routines` | Practice ▸ Routines ▸ + , three blocks added |  |
| `routines/history` | `detail` | `routines` | seeded history, Practice ▸ Routines ▸ Morning Routine, read-only |  |
| `routines/library` | `screen` | `routines` | seeded library, Practice ▸ Routines, several routines saved |  |
| `routines/player-block` | `screen` | `routines` | seeded library, a routine playing, second block of four |  |
| `routines/repeat-block` | `detail` | `routines` | routine editor, a unit block tapped, repeat set to 3 |  |
| `routines/rest-insert` | `panel` | `routines` | routine editor, Insert rest held |  |
| `routines/session-complete` | `screen` | `routines` | seeded library, a routine played to the end |  |
| `sessions/goal-editor` | `screen` | `sessions` | Today's session, a goal template chosen |  |
| `sessions/goal-templates` | `screen` | `sessions` | Today's session, Add a goal tapped |  |
| `sessions/goals` | `panel` | `sessions` | seeded library, Today's session, goals present |  |
| `sessions/planner` | `screen` | `sessions` | seeded library, Today's session, two active goals |  |
| `sessions/review` | `screen` | `sessions` | seeded library, Today's session, Generate tapped, result showing |  |
| `song-player/landscape` | `band` | `looping` | seeded library, Slow Bend, landscape, drawer open | iPhone — the simulator does not render this layout honestly |
| `song-player/portrait-idle` | `screen` | `looping` | seeded library, Slow Bend, idle, no loop active |  |
| `songs/empty-library` | `screen` | `songs` | fresh install, Song library, no songs |  |
| `songs/filter-menu` | `panel` | `songs` | seeded library, Library screen, filter menu open, two collections ticked |  |
| `songs/import-progress` | `band` | `songs` | seeded library, Library screen, multi-file import in progress |  |
| `songs/library-row` | `detail` | `songs` | seeded library, Library screen, row "Feels" |  |
| `songs/missing-audio` | `panel` | `songs` | seeded library, a song whose file cannot be found, opened for practice |  |
| `songs/song-edit` | `screen` | `songs` | seeded library, song "Slow Bend", edit sheet open |  |
| `songs/sort-menu` | `panel` | `songs` | seeded library, Library screen, sort menu open |  |
| `subscription/paywall` | `panel` | `subscription` | fresh install without Pro, paywall open from a locked Home card | iPhone — cropped above the plan cards on purpose: an image carrying a price outlives
       the sentence that would have carried it, and D6 keeps prices out of this manual |
| `subscription/settings-pro` | `panel` | `subscription` | Settings ▸ Red Moon Pro, subscribed | iPhone — subscribed is an entitlement the shoot cannot grant, and the same sign-in
       prompt as the trial row applies |
| `subscription/trial-row` | `band` | `subscription` | an account inside a running trial, Home | iPhone — a running trial is an entitlement, and no launch argument fakes one. On a
       simulator `AppTransaction.shared` puts up a sign-in prompt that leaves the app untappable, so
       a driven attempt at this figure hangs rather than failing |
| `terms/command-tempo-info` | `detail` | `terms` | seeded library, Slow Bend, loop "Verse riff" edit sheet, ⓘ tapped on Command tempo |  |
| `terms/info-button` | `glyph` | `terms` | — |  |
| `terms/mastery-info` | `detail` | `terms` | seeded library, Slow Bend, loop "Verse riff" edit sheet, ⓘ tapped on Mastery |  |
| `toolkit/faq` | `screen` | `toolkit` | Toolkit ▸ Help & FAQs, one question expanded |  |
| `toolkit/glossary` | `screen` | `toolkit` | Toolkit ▸ Glossary, no search |  |
| `toolkit/hub` | `screen` | `toolkit` | Toolkit open, some saved chords present |  |
| `toolkit/my-chords` | `screen` | `toolkit` | Toolkit ▸ My chords, three or more saved chords |  |
| `toolkit/tune-settings` | `screen` | `toolkit` | Toolkit ▸ Tuner, Tune settings tapped |  |
| `toolkit/tuner` | `screen` | `toolkit` | Toolkit ▸ Tuner, microphone allowed, a string sounding |  |

105 shots across 19 pages.
