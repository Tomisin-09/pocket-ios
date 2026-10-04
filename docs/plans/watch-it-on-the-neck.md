# Watch it on the neck: build plan and handoff (ADR 0254)

A loop's piece, already named on the neck, played back on the neck while the loop's own recording plays.
It gets its own sheet, with five ways in. This file is the plan and the handoff. Read it first if you pick
the work up somewhere other than Tomisin's Mac (the plan's original copy and the session memory live
there).

## Where things stand (2026-10-04)

| Branch | State |
|---|---|
| `pocket-363-hear-out-of-exercises` | **Part A, ADR 0253, done.** Commit `832c5fc`. Verified on the Mac: strict lint, the build, 3,913 unit tests, the UI tests (13/13 on a clean install), ManualExerciseShots 6/6, `check-manual.py`. **No PR yet**: Tomisin hasn't asked for one. |
| `pocket-364-watch-it-on-the-neck` | **Part B, built and verified on the Mac** (see *Verified* below), and on Tomisin's iPhone. Stacked on `pocket-363`, because 363 isn't merged, so it contains 363's commit. C2 and C3 are the WIP commit, C1 and C4–C7 the cloud session's, and two layout fixes and a second UI test came from the Mac's screenshots. It goes to main as one PR with Part A. |

**After 363 squash-merges into main:**
`git fetch && git rebase --onto origin/main pocket-363-hear-out-of-exercises pocket-364-watch-it-on-the-neck`

**ADR number:** 0254 is the next free one. Check `ls docs/decisions | tail -3` before writing it.

**What needs a Mac:** everything iOS. That covers `xcodegen generate`, `xcodebuild`, the simulator tests,
the shoot, screenshots and the device check. Lint and `scripts/check-manual.py` are the only checks
that run anywhere. Write code in the cloud, then verify on the Mac before any PR.

## Decided by Tomisin (2026-10-04)

1. **It's its own sheet**, not a panel in the song player.
2. **The whole lick, plus a light.** Every spot the piece uses is drawn in ink, as a map. The note being
   heard turns solid, glows the way it was played and shows its marks. When the loop stops, the map
   stays.
3. **Five doors:**
   - the loop edit sheet's Practice section;
   - the Loops library row's hold menu;
   - the song map's piece sheet;
   - Train your ear ▸ *Saved on this loop*, as a second bordered button under **Name the notes**;
   - the Journal's piece row, as a link under the loop's caption. That row has no hold menu, by design.
4. **The mockup's defaults stand** (*"I'm happy with the default options"*):
   - the name is **Watch it on the neck**;
   - the controls are **compact**: a play button with a −/+ tempo row, not ear training's 108 pt button;
   - under the neck goes a **read-only chip row** that rings the chip being heard, not the tab;
   - **every door hides** when the piece has nothing on the neck or the song's audio can't play here.
5. **Following.** The board opens centred on the lick and moves only when the heard note leaves the frets
   in view.

The mockup is at https://claude.ai/artifact/Gy8BPuBrSiMhxd9QQFZfz1 (private to Tomisin).

## Written in the cloud session (2026-10-04), not yet built

Read in review only, against the types each file uses; nothing was compiled. Lint-shaped checks done by
hand: every line ≤ 120, every file ≤ 400, and the three type bodies that grew (`LoopEditSheet` 213,
`LoopLibraryView` 207, `SongMapView` 242) under 250. `openPicked()` and a new `watch(_:)` moved from
`SongMapView` into `SongMapView+Actions.swift` to keep it there, which made `openAfterSheet`,
`copyAfterSheet` and `open(_:in:)` internal.

- **C1:** `docs/decisions/0254-watch-it-on-the-neck.md`, as below. No `Amends`: only a `Relates to`.
- **C4:** `PieceNeckView.swift` and `WatchOnNeckSheet.swift`, as designed below, with two additions: the
  chip row shows the joins between chips as Fret & string's strip does, and `WatchOnNeckSheet.title` and
  `.symbol` (`eye`, used nowhere else in the app) are what every door uses.
- **C5:** all five doors, each behind `PieceNeck.canWatch(_ loop:)`. The Journal's rows use
  `canWatch(_:on:)` with the piece they already decoded. Identifiers: `loopEdit.watch`,
  `count.saved.watch`, `journal.piece.watch`. `PieceNeckTests` gains a gate test on uninserted loops.
- **C6:** `-seedWatchPiece` (`UITestHooks.watchPieceArgument`), `NamingPieceSeed.Action.seedFretted`,
  `NamingPieceSeed.placedLabels` (G5, G7 hammered from 5, B5, B8 bent a whole step, B5, G7),
  `NamingPieceSeedTests` extended, and `PocketUITests/WatchOnNeckUITests.swift` (Edit loop route).
- **C7:** CHANGELOG, PROJECT, architecture, design brief, the manual (`reference/practice.md` gains
  the section and figure marker `reference/watch-on-neck`, pending, on the reshoot list;
  `reference/song-player.md`, `songs.md`, `journal-and-practice-log.md`), `shots.md` regenerated.
  `check-manual.py` passes. `gestures.md` needed nothing: the hold-menu table doesn't list items, and no
  `onLongPressGesture` was added.

## What ADR 0254 records (C1)

`docs/decisions/0254-watch-it-on-the-neck.md`:

- **D1 — a viewing sheet, not a `LoopRunMode`.** It has no routine block, no practice-log row, no takes
  and no Journal composer. `LoopModeAccess.allows` stays exhaustive over its three modes, and this never
  appears in routines or the planner.
- **D2 — the gate**, one rule for all five doors: `PieceNeck.canWatch`. The piece must have a note on
  the neck (`hasFrettedLabels`), and its audio must resolve (`LoopModeAccess.Facts(loop).audioResolves`).
- **D3 — only the recording plays.** The rule against playing the answers back as a sequence (0225,
  0227 and 0235, each in its D10 or *What stays out*) stands.
- **D4 — what the neck draws:** the whole lick plus a light, as decision 2 above.
- **D5 — following**, as decision 5 above. Name the notes' never-scroll rule (0227 D2) protects a finger
  that's placing a note. Nothing is placed here, and Name the notes keeps its rule. So this is **not** an
  amendment: cite it under a `Relates to:` field **without** the `ADR` prefix (`0227 D2`), or C16 will
  demand a back edge. `HeardGlows`' doc says the neck never scrolls to follow the glow; reword it to say
  that's Name the notes' rule.
- **D6 — tempo** comes from the sheet's own `ContinuousLoopPlayer`, starting at `loop.ramp.command`,
  in 5% steps. The song player pauses through `onOpenNestedAudio` before the sheet opens.
- **D7 — the screen stays awake** (`keepAwakeDuringPractice`), so you can play along hands-free.
- **Rejected** (the mockup's other options):
  - the 108 pt controls, which on a 375 × 667 phone push the row under the neck below the fold;
  - the tab under the neck, which would mean changing `PieceDrawing`, shared by four places (0234 D8);
  - doors that always show and say "audio unavailable" inside;
  - making it a `LoopRunMode`.

## Done, in the WIP commit on `pocket-364`

**C2 — pure logic**, in `Pocket/Core/Theory/PieceNeck.swift`, with no SwiftUI import:
- `PieceNeck.spots(of:)` gives the map: every placed spot. A bend's landing and a lead-in's start are
  not spots.
- `heardSpots(_:of:)`, `frets(of:in:)` (bend landing and lead-in start included, so following keeps the
  whole glow in view), `span(of:)`, `centre(of:)` and `canWatch(hasFrettedLabels:audioResolves:)`.
- `PieceNeck.words(for:of:openMidi:spelling:)` gives the heard tap in words, as the line over the chips
  and the neck's VoiceOver value. Examples: "G string, fret 5, hammered on from 3", "B string, fret 6,
  bent a whole step", "Gm7, frets 10 to 12", "F, named by ear", "Not named yet".
- `NeckFollow.window(centre:width:)` gives the frets wholly in view, clamped at both ends as a scroll view
  is. `NeckFollow.target(current:heard:width:)` returns a new centre only when the heard frets leave
  that window.
- **Tests** are in `PocketTests/PieceNeckTests.swift`. They cover a chord, a tap named by ear, an unnamed
  tap, a bend, a lead-in, an empty piece, the window's edges and every gate combination. A further test
  holds `NeckFollow`'s 34/30 to `NeckGeometry`. **None of them has been run yet.**

**C3 — shared pieces lifted out.** This is meant as a refactor with no visible change:
- `NeckSpotDot.swift`: the editor's spot drawing, with `SpotStyle` and `NeighbourNumber`.
  `NeckNoteEditor.neckSpot` now wraps it in its button.
- `HeardTapTracker.swift`: the strip's private `HeardChipTracker`, which is still the one leaf that
  reads a clock (ADR 0153).
- `PieceChip.swift`: the chip's face, `.heardRing(_:)`, `PieceChip.rowFade` and
  `NamingStrip.chipText(_:onTheNeck:openMidi:spelling:)`. The naming strip's chip is built from them,
  and its overlays stay in the same order: the dashes on the note just placed, then the ring, then the
  snag.
- `LoopTempoControl`, in `LoopModeSections.swift`, is the −/+ adjuster lifted out of
  `ContinuousLoopControls`. It takes `buttonSize`, `spacing` and `valueWidth`, and its defaults are the
  old look.
- `LoopPlayButton` gains `diameter` (default 30, never touched at under 44 pt).
- `NeckGeometry.namesWidth` (16) and `namesSpacing` (8) are named in `FretNeckBoard`.

**Not yet checked:** none of this has been built in Xcode. If it was pushed, the pre-push hook's
lint and build ran on it, so read the push's outcome below. Name the notes must render exactly as
before; see the verification list.

## Left to do

### C4 — the sheet (design worked out, not written)

**`Pocket/Features/Practice/PieceNeckView.swift`**, the read-only neck:
- `FretNeckBoard(stringNames:, maxFret: PieceLabel.maxFret, scrollTarget: centre, headroom: 16)`. The
  string names are `TabLine.stringNames(openMidi:)`, trimmed.
- **Each cell** is `NeckSpotDot(name:tier:)`:
  - the tier is `.current` if the spot is in `PieceNeck.heardSpots(heard, of:)`, `.other` if it's in
    the lick's spots, and `nil` otherwise;
  - the name is `spelling.name(pitchClass:)` of `openMidi[string] + fret`, as the editor does it.
- **`marks:`** is, only while a tap is heard,
  `NeckMarksLayer(notes: labels[heard]?.frettedNotes ?? [], previous: heard > 0 ? labels[heard - 1]?.frettedNotes ?? [] : [], join: NeckJoin.symbol(into: heard, of: labels), stringCount: openMidi.count, maxFret: PieceLabel.maxFret, headroom: 16)`.
  Guard `labels.indices.contains(heard)`.
- **`beneath:`** is
  `HeardGlows(motions: heard.map { HaloMotion.motions(into: $0, of: labels) } ?? [], token: heard, headroom: 16)`.
- Its inputs are labels, openMidi, spelling, the lick's spots (computed once by the sheet), `heard` and
  `centre`.

**`Pocket/Features/Practice/WatchOnNeckSheet.swift`** has `init(loop:)`.

*State and data:*
- `@State player = ContinuousLoopPlayer(loop: loop)`, set in `init` the way `EarTrainingSheet` does
  it. Its tempo starts at `loop.ramp.command`.
- `@State heard: Int?`, `@State centre: Int?` (starting at `PieceNeck.span(of:).map(PieceNeck.centre)`)
  and `@State boardWidth: Double`.
- Stored lets: `labels` and `seconds` come from `loop.transcription`. `openMidi` and `tuningLabel` come
  from the piece, falling back to `CountTheNotesModel.tunerTuning()`. `spelling` is
  `CountTheNotesModel.spelling(for:)`, and `lick` is `PieceNeck.spots(of:)`.

*Layout:* a `NavigationStack` around a `ScrollView`, holding a `VStack(alignment: .leading, spacing: 16)`
with 16 pt side padding. From top to bottom:
1. `LoopModeIdentityHeader(loop:)`.
2. The tuning line, in footnote secondary.
3. The neck.
4. The order row.
5. The controls.

The title is **Watch it on the neck**, inline, with **Done** as the confirmation action. Detents are
`[.large]`.

*The neck:*
- Read `.onGeometryChange(for: Double.self) { $0.size.width }` and subtract
  `NeckGeometry.namesWidth + namesSpacing` to get `boardWidth`.
- For VoiceOver it is one element: `.accessibilityElement(children: .ignore)`, labelled "The neck".
  Its value is `PieceNeck.words(...)` for the heard tap, or "\(n) on the neck" while stopped. Don't post
  an announcement on every note.
- `.accessibilityIdentifier("watch.neck")`.

*The order row:*
- A head line. On the left is "Note 3 of 11" while playing, or "11 notes" while stopped; the noun is
  "chord" for a chord loop. On the right is the heard tap's `PieceNeck.words`, or "9 on the neck" while
  stopped.
- Under it, a horizontal `ScrollViewReader` of `PieceChip`s built from
  `NamingStrip.chipText(_, onTheNeck: true, ...)`, each with `.heardRing(index == heard)`.
- The row has `.mask(PieceChip.rowFade)`, 18 pt horizontal padding, and scrolls the heard chip to the
  centre. The chips are read only and can't be tapped.
- Each chip's VoiceOver label is "Note 3, G5", plus `.isSelected` while it's heard.

*The controls* are one `HStack(spacing: 12)`:
- `LoopPlayButton(diameter: 52)`, whose action is `LoopTransport.toggle(player, recorder: nil, onStopped: {})`.
  Its id is `watch.play`, and its labels are "Play the loop" and "Stop the loop".
- A status line in caption secondary, filling the space between. Its copy:
  - unavailable: "Audio unavailable — the song file moved or was deleted."
  - loading: "Loading…"
  - playing: "Playing at 75%. Play along with it."
  - idle: "Tap to play the loop. It goes round until you stop it."
- `LoopTempoControl(player:, buttonSize: 28, spacing: 6, valueWidth: 56)`.

*The clock:* only while `player.isPlaying`, render
`HeardTapTracker { player.loopClock().flatMap { NamingStrip.heard($0, taps: seconds) } } report: { heard = $0 }`
as a `.background` of the content.

*Lifecycle:*
- `.onChange(of: player.isPlaying)`: on a stop, set `heard = nil`.
- `.onChange(of: heard)`: follow, if
  `NeckFollow.target(current: centre, heard: PieceNeck.frets(of:in:), width: boardWidth)` is non-nil.
- `.onDisappear { player.stop() }` and `.keepAwakeDuringPractice()`.

### C5 — the five doors

Each door shows only when `PieceNeck.canWatch` holds. A small `extension PieceNeck { static func canWatch(_ loop: Loop) -> Bool }` is the
one place that reads the loop: `loop.transcription?.hasFrettedLabels` and `LoopModeAccess.Facts(loop).audioResolves`.
Use the label **Watch it on the neck** everywhere, in practice teal. The mockup's icon was a neck; pick an
SF Symbol and keep the same one on all five doors.

1. **The loop edit sheet** (`Pocket/Features/Waveform/LoopEditSheet+Fields.swift`):
   - in `practiceSection`, put a `watchButton` after `earTrainingButton`, behind the gate;
   - the button calls `onOpenNestedAudio()`, then sets `showingWatch = true`;
   - put `@State var showingWatch` and `.sheet(isPresented: $showingWatch) { WatchOnNeckSheet(loop: loop) }`
     in `WaveformEditSheets.swift`, beside the `showingEarTraining` ones.
   - The file is 348 lines, and the cap is 400.
2. **The Loops library hold menu** (`Pocket/Features/Practice/LoopLibraryView.swift`, `menuItems(for:)`):
   - add a `PocketRowMenuItem` after the modes and before *Add to routine…*;
   - it sets `@State watching: StableRef<Loop>?`;
   - put `.sheet(item: $watching)` at the body root, next to the `routineRequest` sheet.
   - The file is 337 lines.
3. **The song map** (`SongMapPieceSheet.swift`):
   - add `var onWatch: (() -> Void)?` and a button in `actions`, after the modes and before *Copy to…*;
   - in `SongMapView.swift`, the `onWatch` closure sets `watchAfterSheet = ref.value.uid; viewing = nil`,
     the same pattern as `copyAfterSheet`;
   - `openPicked()` then calls `onOpenNestedAudio()` and sets `watching = StableRef(loop)`;
   - `.sheet(item: $watching)` goes at the root.
   - `SongMapView.swift` is 324 lines.
4. **Saved on this loop** (`SavedPieceSection.swift`):
   - add `var onWatch: (() -> Void)?` (nil hides it);
   - under **Name the notes**, add a second button with the same `.bordered`, `.tint(PocketColor.practice)`
     and subheadline style, id `count.saved.watch`;
   - in `EarTrainingSheet.swift` (`EarTrainingView`), pass `onWatch` only when the gate holds. It calls
     `stopForNaming()`, which finishes any take and stops the loop, then sets `showingWatch = true`;
   - put `.sheet(isPresented: $showingWatch)` at the body root.
5. **The Journal's piece row** (`Pocket/Features/Journal/JournalPieceRow.swift`):
   - add `var onWatch: (() -> Void)? = nil`, and draw a link under `JournalOwnerCaption`, styled like the
     caption: caption font, `PocketColor.journal`, `.isLink`. Its id is `journal.piece.watch`.
   - Wire it at both call sites: `JournalTabView+List.swift` (`case .piece`) and
     `JournalTabView+PiecesBySong.swift`. Both use a `watchAction(for piece: JournalPiece)` in
     `JournalTabView.swift` that returns `nil` unless `PieceNeck.canWatch` holds. When it does, it runs
     `{ player.stop(); watching = StableRef(value: piece.loop) }`. `player` is the feed's take player.
   - Put `.sheet(item: $watching)` at the root. `JournalTabView.swift` is 346 lines.

Present every sheet from a body root, never from a row (memory: on iOS 18 a `.sheet` on a List row
loses its write). Present by `StableRef` uid, never by the model (ADR 0090).

### C6 — seed and UI test

- **Seed.** `NamingPieceSeed` (`Pocket/Core/DevSupport/NamingPieceSeed.swift`) seeds six *unnamed* notes,
  so there's no door. Add a `-seedWatchPiece` argument (`UITestHooks.watchPieceArgument`) that seeds the
  same song with the six taps placed on the neck. For example, G5 G7 B5 B8b10 B5 G7 on standard tuning,
  with `openMidi` and `tuningLabel` stamped.
- `Action` becomes `.seed`, `.seedFretted`, `.remove` and `.none`. Extend `NamingPieceSeedTests` to
  match.
- **UI test** (`PocketUITests/WatchOnNeckUITests.swift`):
  - take the same route as `NameTheNotesUITests.openNameTheNotes` as far as Edit loop, then tap **Watch it
    on the neck**;
  - assert `watch.neck`'s value reads "6 on the neck";
  - tap `watch.play`, wait for "Stop the loop", then assert the neck's value **changes** to a note's
    words.
- **Watch for this:** no UI test plays loop audio yet. This is the first. Run it on the iOS 26 simulator
  and on the **iOS 18.5** one (CI's) before trusting it.
- **CI traps:**
  - tap a toolbar Menu by coordinate;
  - scroll a target until its whole frame is 40 pt clear of the home indicator (`reveal`/`inReach`);
  - never anchor a query on header text, since iOS 18 capitalises it.

### C7 — docs

- `CHANGELOG.md`: a line under [Unreleased] ▸ Added.
- `PROJECT.md`: the new screen.
- `docs/architecture.md`: `PieceNeck`, `PieceNeckView`, `WatchOnNeckSheet` and the lifted pieces.
- `docs/design-brief.md`: the screen inventory.
- **The manual:**
  - `docs/manual/reference/practice.md`: a new subsection, and fix its "launched from its edit sheet"
    lines (about 178–188);
  - `docs/manual/songs.md`: the map's piece sheet;
  - `docs/manual/journal-and-practice-log.md`: the piece row's link;
  - the Train your ear page that describes *Saved on this loop*;
  - `docs/manual/gestures.md`, if the hold menu's count changes.
- Run `python3 scripts/check-manual.py` (stdlib only, so it runs anywhere).
- Add the new figure to the reshoot list. Don't shoot per branch.

## Verification (on the Mac)

1. Run `xcodegen generate` first, because new files were added.
2. `swiftlint --strict` must report 0 violations. Keep every file at 400 lines or fewer.
3. `xcodebuild build -scheme Pocket -destination 'generic/platform=iOS Simulator'` must give no warnings
   in the touched files.
4. Run `xcodebuild test -scheme Pocket -testPlan PocketAll -destination 'platform=iOS Simulator,name=iPhone 17'`
   with output redirected to a file, then grep for `TEST SUCCEEDED|TEST FAILED`. A pipe hides the exit
   code.
   - **Uninstall the app from the simulator first** (`xcrun simctl uninstall <udid> click.decooperations.pocket`).
     The simulator keeps its store, and a store left by a shoot fails nine UI tests whose seeds skip a
     non-empty library.
5. **The C3 refactor must change nothing.** Check `PieceNeckTests`, `NeckMarksTests`, `NeckEditingTests`,
   `NameTheNotesUITests`, `SnagLineUITests` and `GestureHintUITests`.
   - Also run the **manual shoot class that opens Name the notes**. A body was touched, and a green
     PocketAll once missed a segfault.
   - `-only-testing:` with a class that's skipped runs 0 tests and exits 0. List what ran.
6. Make a mutant on `NeckFollow.window`'s edge and confirm the targeted test fails, then revert it. Keep
   mutants on separate lines.
7. Take screenshots of the sheet stopped and mid-play, at 375 pt, in light and dark. A hosted-window
   snapshot catches the glow.
8. Run the new UI test on the iOS 18.5 simulator.
9. Run `scripts/check-manual.py`, C16 included.
10. **Tomisin's device check** that the glow keeps time with the audio, over Bluetooth and at a slow
    tempo. Done, 2026-10-04.

## Verified (on the Mac, 2026-10-04)

- `xcodegen generate`, then `swiftlint --strict`: 0 violations. The simulator build: **BUILD SUCCEEDED**,
  no warnings in any touched file. `scripts/check-manual.py`: passed, C16 included.
- **PocketAll on a clean iPhone 17 (iOS 26.5): TEST SUCCEEDED.** 3,926 unit tests and 50 UI tests, 0 failures,
  each case started once (no retries), all 27 UI suites ran.
- `PieceNeckTests` (11), `NamingPieceSeedTests`, `NeckMarksTests`, `NeckEditingTests`, `HaloMotionTests` and
  `NeckNeighboursTests`: all six requested suites ran, 65 tests, 0 failures.
- **Two mutants** on `NeckFollow.window`, one at a time: rounding the first fret in view down, then the last
  one up. Each failed `testTheBoardsFretsInViewStopAtEitherEnd` and `testItMovesOnlyWhenTheHeardFretsLeaveTheView`
  on the assertion meant for it, then was reverted.
- **`WatchOnNeckUITests`** passes on iOS 26.5 (iPhone 17, and an iPhone SE at 375 points in light and dark) and
  on **iOS 18.5** (iPhone 16). The loop's audio plays on both, and the neck's value changes as it does.
  - The first iOS 18.5 run, on a cold-booted simulator, failed **before the new code**. The hold on the
    loop row landed as a tap and started the loop instead of opening Edit loop. That route is
    `NameTheNotesUITests`' own. On the warm simulator both classes passed.
  - The second test, opening from *Saved on this loop*, was checked against a mutant that made its button
    fire Name the notes as well. It failed on "the tap fired both buttons", then the mutant was reverted.
- **`ManualSongMapShots`** (3/3) shot Name the notes and By ear unchanged by the lifted dot and chip.
- **Screenshots** looked at: the sheet stopped and playing, at 402 points (dark) and at 375 points (light
  and dark). The glow, the hammer-on's curve, the ringed chip and the heard line all show. The controls
  and chips stay above the fold on the SE.
- **Fixed from the screenshots:**
  - *Saved on this loop*: *Watch it on the neck* had a Form row of its own, with a divider at a stray
    inset. It now shares *Name the notes*' row.
  - The Journal's link: as a `Label` it took the List's icon column, which put a gap before its words and
    moved the divider in. It's now an icon and words inline, like the caption above it.
- **Stale figures** for the reshoot: `reference/saved-piece` and `journal/pieces`.
- **New figure** `reference/watch-on-neck`: the row and marker exist, but the shoot method doesn't yet.
- **Device check, done by Tomisin:** *"the timing is good and the doors are accessible."*

## House rules that apply here

- Commit only when asked, and push or open a PR only when asked. After a PR, wait for green CI before
  merging, and don't poll it.
- User-facing copy says Red Moon, never Pocket. Lint enforces this.
- In ADRs, write the back edge in the same commit. C16 reads `Supersedes`/`Amends`/`Amended by` fields,
  and every `ADR NNNN` inside them counts as a claim.
- Use one branch per task. Don't edit in worktrees.
