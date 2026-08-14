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
| `exercises/freeform-run` | `screen` | `exercises` | seeded library, a freeform exercise, running |  |
| `exercises/library` | `screen` | `exercises` | seeded library, Practice ▸ Exercises, several templates present |  |
| `exercises/practice-settings` | `panel` | `exercises` | seeded library, an exercise run screen, Practice Settings expanded |  |
| `exercises/run-complete` | `screen` | `exercises` | seeded library, an exercise run finished naturally |  |
| `exercises/run-live` | `screen` | `exercises` | seeded library, an exercise run screen, running past the count-in |  |
| `exercises/run-setup` | `screen` | `exercises` | seeded library, Exercises, "Alternate Picking" opened, stopped |  |
| `exercises/staircase` | `band` | `exercises` | seeded library, an exercise run screen, staircase visible |  |
| `exercises/template-picker` | `screen` | `exercises` | New exercise sheet, template picker, guitar selected |  |
| `gestures/loop-controls-popover` | `panel` | `gestures` | seeded library, Little Wing, player idle, Loop controls tapped |  |
| `gestures/row-hold-menu` | `panel` | `gestures` | seeded library, Library screen, row "Binta" held |  |
| `gestures/speed-bar` | `band` | `gestures` | seeded library, Little Wing, player idle |  |
| `gestures/undo-toast` | `band` | `gestures` | seeded library, Library screen, a row swiped left and deleted |  |
| `getting-started/first-run` | `screen` | `getting-started` | fresh install, first launch, step 1 of 4 |  |
| `getting-started/home` | `screen` | `getting-started` | seeded library, Home, evening greeting |  |
| `getting-started/import-picker` | `screen` | `getting-started` | seeded library, Home, + tapped |  |
| `getting-started/loop-active` | `band` | `getting-started` | seeded library, Little Wing, a loop active and repeating |  |
| `looping/ab-forming` | `band` | `looping` | seeded library, Little Wing, playing, loop start dropped, end not set |  |
| `looping/automator` | `screen` | `looping` | seeded library, Little Wing, loop "Verse riff", automator open |  |
| `looping/loop-active` | `band` | `looping` | seeded library, Little Wing, loop "Verse riff" active and repeating |  |
| `looping/loop-edit-practice` | `panel` | `looping` | seeded library, Little Wing, loop "Verse riff" edit sheet, scrolled to Practice |  |
| `looping/multi-select` | `panel` | `looping` | seeded library, Little Wing, Loops panel header held, two loops selected |  |
| `looping/speed-bar` | `band` | `looping` | seeded library, Little Wing, speed reduced below 100% |  |
| `looping/tempo-editor` | `screen` | `looping` | seeded library, Little Wing, tempo editor open |  |
| `routines/block-done` | `screen` | `routines` | seeded library, a routine mid-session, a block just finished |  |
| `routines/editor` | `screen` | `routines` | Practice ▸ Routines ▸ + , three blocks added |  |
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
| `song-player/landscape` | `band` | `looping` | seeded library, Little Wing, landscape, drawer open | iPhone — the simulator does not render this layout honestly |
| `song-player/portrait-idle` | `screen` | `looping` | seeded library, Little Wing, idle, no loop active |  |
| `songs/empty-library` | `screen` | `songs` | fresh install, Song library, no songs |  |
| `songs/filter-menu` | `panel` | `songs` | seeded library, Library screen, filter menu open, two collections ticked |  |
| `songs/import-progress` | `band` | `songs` | seeded library, Library screen, multi-file import in progress |  |
| `songs/library-row` | `detail` | `songs` | seeded library, Library screen, row "Feels" |  |
| `songs/missing-audio` | `panel` | `songs` | seeded library, a song whose file cannot be found, details open |  |
| `songs/song-edit` | `screen` | `songs` | seeded library, song "Little Wing", edit sheet open |  |
| `songs/sort-menu` | `panel` | `songs` | seeded library, Library screen, sort menu open |  |
| `terms/command-tempo-info` | `detail` | `terms` | seeded library, Little Wing, loop "Verse riff" edit sheet, ⓘ tapped on Command tempo |  |
| `terms/info-button` | `glyph` | `terms` | — |  |
| `terms/mastery-info` | `detail` | `terms` | seeded library, Little Wing, loop "Verse riff" edit sheet, ⓘ tapped on Mastery |  |

48 shots across 8 pages.
