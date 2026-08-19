# The manual shoot list

Everything still to photograph for `docs/manual/`, in the order it is quickest to shoot, with what
each figure has to show. Derived from the `<!-- shot: -->` markers in the pages — those stay the
source of truth, and `docs/manual/shots.md` stays the generated index. This file is the working
sheet you hold while shooting.

**68 of 101 figures remain** — 66 shootable in the eight sessions below, plus two that are blocked
on a decision. 33 are already filed from driven runs and must not be re-shot: they came off a
specific device state, and re-shooting one by hand puts a different library in it.

---

## Set the device up first

```sh
POCKET_SHOOT_PREPARE=1 ./scripts/shoot-manual.sh
```

That erases the iPhone 17 simulator, builds and installs, stages the seed audio, forces dark
appearance and a 09:41 status bar, and launches the app seeded and **unlocked** — then stops and
hands it to you. It is the same device, under the same launch arguments, as the 33 driven figures.

The `-uiTesting` argument in that launch is load-bearing and is not about tests. It unlocks Pro —
without it, Practice, Routines and the song library all meet a paywall, which is most of this list.
It also switches animations off, so a capture cannot land mid-transition, and it holds the undo
toast open for 120 seconds instead of 4.

**Shoot the simulator, not hardware.** A real phone puts your own library, your own practice
history and a live status bar into every frame, and none of the three can be overridden on hardware.
Six figures genuinely need a phone; they are listed at the bottom and marked **DEVICE**.

If the app is closed or you need to start over without re-erasing:

```sh
xcrun simctl launch "iPhone 17" click.decooperations.pocket \
    -uiTesting -seedScreenshots -seedHistory -shotHour 9
```

Re-erasing (`POCKET_SHOOT_PREPARE=1` again) is the only way to undo state you have changed — the
seeds refuse to run twice, so a second launch never restores what a session consumed.

## Taking and filing a shot

```sh
mkdir -p ~/Desktop/manual-shots
xcrun simctl io "iPhone 17" screenshot ~/Desktop/manual-shots/routines-library.png
```

⌘S in the Simulator saves the same pixels to the Desktop; either is fine.

| Rule | Why |
|---|---|
| **One file per slug, `/` becomes `-`** — `routines/library` → `routines-library.png` | What `file-shots.py` produces, so hand-shot and driven files sit together |
| **Always shoot the full 1206×2622 frame. Never crop by hand.** | `role:` is what the figure *is*, not what to capture. Crops are recorded in the marker afterwards, in device pixels against the full master — so a re-crop never needs a re-shoot |
| **Never resize the Simulator window** | A resized window changes the capture resolution and the recorded crops stop landing |
| **Dark appearance, 09:41 status bar** | Set by the prepare step. If you reboot the device by hand, set them again or the frame will not match its neighbours |
| **Two figures may share one frame** — noted in the table as *same frame as …* | File the identical image under both names. Elsewhere two identical images means a missed tap; here it is deliberate and the table says so |

Upload the folder when you are done. Nothing needs renaming beyond the slug convention.

---

## 1 · Song library — 13 figures

Home ▸ **Song library**. Shoot the destructive one last.

| Slug | Role | How to get there | What must be in the frame |
|---|---|---|---|
| `getting-started/first-run` | screen | **Its own launch** — see below the table | *Where are you with the guitar?*, four choices, first of four dots |
| `getting-started/import-picker` | screen | Home ▸ **+** | The system file picker open over Home |
| `reference/library` | screen | Song library, sort set to **Title** | Lettered sections; each row with title, artist, loop and collection chips |
| `songs/library-row` | detail | Same screen | The **Feels** row — title, artist, loop count, collection chips, five-dot mastery |
| `songs/sort-menu` | panel | Tap the sort control | Mastery, Recently Added, Title, Artist, Album, Genre + ascending/descending |
| `songs/filter-menu` | panel | Tap the filter control, tick **blues** and **chill** | Several collections listed, exactly two ticked |
| `reference/library-row-menu` | detail | Hold the **Binta** row | The menu: Details, Edit, Delete |
| `gestures/row-hold-menu` | panel | *Same frame as `reference/library-row-menu`* | — |
| `reference/song-details` | screen | Hold **Little Wing** ▸ **Details** | Title, artist, notes, key, tempo, mastery, length |
| `reference/song-edit` | screen | Hold **Little Wing** ▸ **Edit** — top of the sheet | Title, artist, album, genre, year, BPM, downbeat, major/minor |
| `songs/song-edit` | screen | Same sheet, **scrolled to Collections** | The Collections section with its chips |
| `songs/import-progress` | band | Home ▸ **+** ▸ select several files at once | The progress indicator over the library. Transient — have the shot command ready |
| `gestures/undo-toast` | band | **Shoot last.** Swipe any row left to delete | The undo toast offering **Undo**. It stays up for 120s under this launch, so there is no rush — then tap Undo |

`getting-started/first-run` is the one figure here that needs a different launch: `-uiTesting`
suppresses the intake, so terminate and relaunch without it, shoot the intake, then **Skip** it.

```sh
xcrun simctl terminate "iPhone 17" click.decooperations.pocket
xcrun simctl launch "iPhone 17" click.decooperations.pocket -seedScreenshots -seedHistory -shotHour 9
```

Relaunch with `-uiTesting` afterwards, or the rest of the list meets a paywall.

## 2 · Song player — 20 figures

Open **Little Wing**. Most of the manual's mass is here.

| Slug | Role | How to get there | What must be in the frame |
|---|---|---|---|
| `song-player/portrait-idle` | screen | Player open, idle, no loop active | Song strip, speed bar, status line, waveform, timeline, transport |
| `gestures/speed-bar` | band | Same screen, speed at 100% | Speed control, metronome button, BPM readout |
| `looping/speed-bar` | band | Reduce speed **below 100%** | The same bar with the reduced effective BPM |
| `gestures/carry-tempo` | panel | **Hold** the BPM readout | The *Carry this tempo* sheet — *To the metronome*, *Into a new exercise*, headed with the tempo |
| `gestures/loop-controls-popover` | panel | Tap **Loop controls** | The popover, all nine rows from *Make a loop* to *Follow* |
| `reference/player` | screen | Loops panel expanded | The whole player with the panel open |
| `reference/loops-panel` | panel | Same state | Each loop row: name, range, mastery, play control |
| `looping/multi-select` | panel | **Hold** the Loops panel header, select two loops | Selection mode with two selected and the selection bar |
| `reference/loop-edit` | screen | Hold **Verse riff** ▸ **Edit loop** — top of sheet | Name, Favourite, Range, and the Practice section beginning |
| `looping/loop-edit-practice` | panel | Same sheet, **scrolled to Practice** | Type, Mastery, Focus, Command tempo |
| `terms/mastery-info` | detail | In that sheet, tap **ⓘ** on *Mastery* | The row with its popover open, definition visible |
| `terms/command-tempo-info` | detail | Tap **ⓘ** on *Command tempo* | The row with its popover open |
| `terms/info-button` | glyph | *Same frame as either info shot* | Just needs an ⓘ in the frame; the crop is taken later |
| `reference/loop-automator` | screen | Hold **Verse riff** ▸ automator | Start, Target, Steps, Loops per step, above the preview |
| `looping/automator` | screen | *Same frame as `reference/loop-automator`* — check both alt lines match what you shot | — |
| `reference/tempo-editor` | screen | Open the tempo editor | Tap / Manual segments, tap pad, *Estimate from audio* |
| `looping/tempo-editor` | screen | *Same frame as `reference/tempo-editor`* | — |
| `looping/ab-forming` | band | Play, drop the **A** point, do not set **B** | The A/B strip prompting for B |
| `looping/loop-active` | band | Activate **Verse riff**, let it repeat | Transport in active form, loop name above the controls |
| `getting-started/loop-active` | band | *Same frame as `looping/loop-active`* | Must also show the loop span drawn across the waveform — check before filing |

## 3 · Exercises — 12 figures

Practice ▸ **Exercises**. `run-complete` writes practice history, so shoot it after everything else
on this screen.

| Slug | Role | How to get there | What must be in the frame |
|---|---|---|---|
| `exercises/library` | screen | Practice ▸ Exercises | Collapsible template sections, each row with its command tempos |
| `exercises/run-setup` | screen | Open **Alternate Picking**, stopped | Collapsed Practice Settings summary, the start control |
| `exercises/practice-settings` | panel | Expand **Practice Settings** | Working, Command, Reach, the Back off toggle |
| `exercises/staircase` | band | Same screen, staircase visible | Warm-up steps, the wide command plateau labelled **90 BPM** |
| `exercises/run-live` | screen | Start, wait past the count-in | Live BPM, phase caption, animated fretboard |
| `journal/quick-note` | screen | From the run screen, tap **quick note** | *What just happened?* field, kind chips, line status |
| `reference/quick-note` | screen | *Same frame as `journal/quick-note`* | — |
| `journal/quick-note-button` | glyph | *Any frame with the run screen's toolbar* | The quick-note button in shot |
| `journal/record-arm` | glyph | *Same* | The record-arm button in shot |
| `exercises/run-complete` | screen | Let a run finish **naturally** | Mastery rating, note field, the command-tempo offer |
| `exercises/template-picker` | screen | Exercises ▸ **+** | Guitar / Bass control at the top, the template list |
| `exercises/configure` | screen | Choose **Warm-up** ▸ configure step | Name field and the fretboard run editor |

## 4 · Routines — 6 figures

Practice ▸ **Routines**. Playing one writes history; shoot the editor figures first.

| Slug | Role | How to get there | What must be in the frame |
|---|---|---|---|
| `routines/editor` | screen | Routines ▸ **+**, add three blocks | Name field, numbered blocks, estimated length, Add and Insert rest rows |
| `routines/repeat-block` | detail | In that editor, tap a unit block, set repeat to **3** | The repeat sheet showing ×3 and its stepper |
| `routines/rest-insert` | panel | **Hold** *Insert rest* | The gaps between blocks, tappable, under *Tap where a rest goes* |
| `routines/player-block` | screen | Play **Morning Routine**, reach the **second** block | Progress strip marked Start/Finish, the block's own run screen beneath |
| `routines/block-done` | screen | Let that block finish | *Nice work*, five mastery dots, note field with tag chips, **Up next** card |
| `routines/session-complete` | screen | Play the routine to the end | The recap of what you practised, and **Done** |

## 5 · Today's session — 6 figures, and the order is load-bearing

`reference/planner` needs **no goals yet**. Once you add one you cannot get back without re-erasing,
so shoot these strictly top to bottom.

| # | Slug | Role | How to get there | What must be in the frame |
|---|---|---|---|---|
| 1 | `reference/planner` | screen | Practice ▸ **Today**, before touching anything | Length presets, the away-from-your-instrument toggle, Generate — and **no goals** |
| 2 | `sessions/goal-templates` | screen | **Add a goal** | The ten starting points and the *Something else* row |
| 3 | `sessions/goal-editor` | screen | Choose any template | Name field, Low / Normal / High priority, the skills list |
| 4 | `sessions/goals` | panel | Save it, add a second | The *This session* section: two goals, each with skill count, target song, priority |
| 5 | `sessions/planner` | screen | Same screen, whole view | Length control, toggle, both goals, Generate |
| 6 | `sessions/review` | screen | **Generate today's session** | Dated name, the blocks, estimated length, **Save** in the toolbar |

## 6 · Toolkit — 1 figure

The Tuner itself needs a microphone and is on the phone list, but its settings sheet does not.

| Slug | Role | How to get there | What must be in the frame |
|---|---|---|---|
| `toolkit/tune-settings` | screen | Home ▸ **Toolkit** ▸ **Tuner** ▸ **Tune settings** | Instrument, Mode, Tuning, Reference pitch, Success chime |

## 7 · A second pass on an unseeded device — 2 figures

These two need a device with **nothing on it**, which is the opposite of every figure above. Erase
and install without the seed flags. (`getting-started/first-run` used to be on this list and is
not — the intake is suppressed by `-uiTesting`, not by the seed flags, so it can be shot on the
seeded device in session 1.)

```sh
xcrun simctl erase "iPhone 17" && xcrun simctl boot "iPhone 17"
xcrun simctl ui "iPhone 17" appearance dark
xcrun simctl status_bar "iPhone 17" override --time "09:41" --dataNetwork wifi --wifiMode active \
    --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl install "iPhone 17" build-sim/Build/Products/Debug-iphonesimulator/Pocket.app
xcrun simctl launch "iPhone 17" click.decooperations.pocket
```

| Slug | Role | What must be in the frame |
|---|---|---|
| `songs/empty-library` | screen | *No songs yet*, **Import a song**, **Try the demo** |
| `reference/loops-library` | screen | Practice ▸ Loops, empty, explaining that measured loops appear once set on a song |

Do this pass **after** the seeded one — it destroys the seeded device.

## 8 · On a real phone — 6 figures, marked DEVICE

| Slug | Role | Why hardware |
|---|---|---|
| `song-player/landscape` | band | Landscape, drawer open — the simulator does not render it honestly |
| `toolkit/tuner` | screen | Needs a microphone hearing a real string sounding |
| `reference/tuner` | screen | Same — tuner listening, note disc, cents gauge, string circles |
| `subscription/paywall` | panel | A fresh install without Pro. **Crop above the plan cards** — no price may appear in this manual |
| `subscription/trial-row` | band | An account inside a running trial |
| `subscription/settings-pro` | panel | A subscribed account, Settings ▸ Red Moon Pro |

The subscription three need a real entitlement: no launch argument fakes one, and on a simulator
`AppTransaction.shared` raises a sign-in prompt that leaves the app untappable.

---

## Two that are blocked, and need a decision first

| Slug | Blocked on |
|---|---|
| `songs/missing-audio` | Nothing in the library has a broken file. Seeding one permanently would put an audio-unavailable row into **every** library figure above. The alternatives are to delete a staged audio file from the app container mid-session and shoot the state, or to shoot it by hand on a phone |
| `exercises/freeform-run` | A fresh install seeds six drills and none is a *Your own practice* block. Author one by hand before shooting it — note that doing so adds a drill to the Exercises library, so shoot `exercises/library` **before** you create it |

## Already filed — do not re-shoot

The 33 driven figures cover Home, the Journal, Progress, Settings, the Metronome, the Toolkit, the
references section, the Practice hub, `reference/exercises-library`, `reference/routines-library`,
`routines/library`, `routines/history` and `reference/long-term-goals`. Note that
`reference/exercises-library` is done and **`exercises/library` is not** — they are two figures of
the same screen on two different pages, and only the reference one has been shot.

`./scripts/check-manual.py --list` prints exactly which remain at any moment. That count is the
progress metric; this file is a working sheet and will drift the moment a page gains a marker.
