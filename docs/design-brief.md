# Pocket — Design Brief & Working Guide (for Claude Design)

This document is the single source of truth for designing Pocket's UI with
Claude. It is **self-contained** — you can paste it (or link it) at the start of
a design session even where Claude has no repo access. Keep it updated as the
design system evolves; it is the contract between design intent and the SwiftUI
implementation.

> **How to use this doc:** Read §1–§4 once for context and the design system.
> Then drive each design session with §6 (the working protocol) and §7 (the
> per-screen request template). §8 is the checklist before a design is accepted.

---

## 1. Product in one paragraph

Pocket is a **native iOS** guitar-practice app (Swift / SwiftUI, iOS 17+,
phone-first, portrait). It attaches practice data — loops, markers, notes,
routines — to songs the user already owns, acting as an intelligence layer over
their music library rather than replacing it. The audience is guitarists who
think seriously about practice.

**Ethos: quality over speed.** Every interaction should feel *musical,
unhurried, and intentional* — like a thoughtful collaborator, not a productivity
tool. Animations should feel like a musical phrase, not a form submission.

---

## 2. Hard constraints (design within these)

- **Platform:** iOS native. Design with **native iOS patterns** — SF Symbols,
  system navigation/sheets, Dynamic Type, safe areas, 44pt minimum touch
  targets, standard gestures. Avoid web-isms (hover states, custom scrollbars,
  CSS-only effects) that don't map to SwiftUI.
- **Dark-first, light-supported.** The practice screen is used in low light
  (evening practice, on a stand), so **design dark first** — background is
  near-black `#040404`, not pure black; the blue accents and per-loop colours
  read best against black (ADR 0023). The app also supports a **light**
  appearance (`#F0E3D8` cream, ADR 0062), following the system setting — every
  new colour needs a light *and* dark value verified for contrast, not just a
  dark one.
- **Audio reality:** the waveform/speed/loop engine runs on **DRM-free local &
  iCloud files** only. Apple Music is **browse/metadata only** — do not design a
  waveform or speed control for Apple Music tracks; design their cards to show
  metadata and an "open in Music" affordance instead. (See
  `docs/decisions/0001-audio-source-local-first.md`.)
- **Orientation:** portrait everywhere except the **practice screen**, which also
  supports landscape (ADR 0042) — sideways gives the waveform the full width for precise
  A/B dragging, with loops/markers in a slide-in drawer. All other screens stay portrait.
- **Accessibility is not optional:** legible contrast on dark, Dynamic Type
  support, VoiceOver labels, and "Reduce Motion" alternatives for the musical
  animations.

---

## 3. The design system (the contract)

These map directly to `Pocket/UI/DesignTokens.swift`. **Always reference token
names, never raw hex.** If a design needs a value that isn't a token, name the
new token and note it so it can be added to the code in the same change.

### 3.1 Colour — functional, never decorative

Colour carries meaning and is consistent everywhere:

The brand **teal** leads (ADR 0081): it wears the Practice space — the app's most-used
surface — and its "Start today's session" CTA, so the brand hue carries the home.
**Green** is the live state, **plum** the metronome tool, **terracotta** the songs
place, **indigo/violet** the Toolkit reference hub (ADR 0096 — a "study/reference" tone
clear of the triad), and warm **gold** the Journal space (ADR 0100 — a "notebook/ink"
tone for personal practice history, the fifth home hue); the detail-waveform bars stay
teal. Hue carries meaning, and the per-loop
identity hues are kept out of these families. The table is grouped by **semantic
role** — the seam the swappable theme uses: a theme is a role → hue *mapping*, so the
planned **Blood Moon** theme swaps Practice↔Library to terracotta-led without a second
baked palette (ADR 0081), and `mastery` tracks whichever hue Practice wears.

**Light + dark appearance (ADR 0062), pinnable in Settings (ADR 0063).** The app
follows the system Light/Dark setting by default; **Settings → Appearance** can pin
Light or Dark instead. Every token below resolves from an Asset Catalog colour set
with separate light and dark values — not one hex reused. Colours tuned to glow on
near-black measurably fail contrast on the cream surface (and vice versa), so each
pair was chosen and verified against real WCAG ratios, not assumed.
`textSecondary`/`barDefault`/`barPlayed` are baked as flat contrast-matched pairs (a
shared opacity would land at very different contrast once the base flips); most other
tokens are `ink` (an adaptive near-black/white base) composed with `.opacity()`, so
they stay correct over any backdrop. The wash/CTA/gridline tokens below are also
baked flat rather than a shared opacity, for the same reason but in the *other*
direction — a low-opacity blend that reads as a soft tint on cream reads as
near-invisible on near-black (ADR 0063).

| Token | Dark | Light | Meaning |
|---|---|---|---|
| `background` | `#040404` | `#F0E3D8` | App surface |
| `ink` | white | `#1A1A1A` | Adaptive foreground base for `textPrimary` + surface fills |
| `textPrimary` | white | `#1A1A1A` | Primary text (= `ink`) |
| `textSecondary` | `#9B9B9B` | `#494644` | Secondary/labels |
| `surfaceSubtle` | ink @ 5% | ink @ 5% | Hairline dividers, thin strokes |
| `surfaceStandard` | ink @ 9% | ink @ 9% | Cards, pills, capsules, toggle "off" states |
| `surfaceEmphasis` | ink @ 18% | ink @ 18% | Selected/highlighted chip or row |
| `surfaceBorder` | ink @ 15% | ink @ 15% | Capsule/badge stroke outlines |
| `waveformBar` | `#60A8C7` @ 85% | `#2B6982` @ 85% | Detail-waveform bar, ahead of the playhead (the song) — the brand teal, theme-invariant (ADR 0081) |
| `waveformBarPlayed` | `#60A8C7` @ 40% | `#2B6982` @ 40% | Detail-waveform bar, behind the playhead (recedes) |
| `waveformAccent` | `#60A8C7` | `#2B6982` | Full-opacity song accent — the practice-screen speed slider, the speed bar's repeat + metronome controls (and the metronome's "no tempo yet" badge, ADR 0124), and the custom speed-entry CTA; matches the bars and stays teal in every theme (ADR 0081) |
| `gridLine` | `#202020` | `#968F88` | Beat-grid downbeat lines — baked flat, not `ink.opacity()` (ADR 0062/0063) |
| `active` / `confirm` | green | green | Live state / confirm-save (system dynamic colour) |
| `danger` | red | red | Discard / delete / destructive (system dynamic colour) |
| `metronome` | plum `#9272CA` | `#603B9B` | The metronome **tool** — the one **theme-invariant** home hue (ADR 0081). Accent on the home card and the standalone metronome screen. (Plum values from ADR 0063; handed teal to `practice`.) |
| `metronomeCTA` | `#8D7EA6` | `#593399` | Metronome's primary-button fill — a solid CTA fill needs its own contrast recipe (ADR 0062 follow-up) |
| `metronomeCardWash` / `metronomeCircleWash` | `#2C203E` / `#3E2C56` | `#C2A7CF` / `#D0BAD2` | Home metronome card/icon-circle tint — baked flat per appearance |
| `practice` | teal `#60A8C7` | `#2B6982` | The **Practice** space (ADR 0046) and the app's **brand hero** (ADR 0081) — leads the home + the "Start today's session" CTA; ~120 call sites reskin from this one token |
| `practiceCTA` | `#799BA9` | `#18698B` | Practice's primary-button fill (incl. "Start today's session"), same rationale as `metronomeCTA` |
| `practiceCardWash` / `practiceCircleWash` | `#153A44` / `#1D4E5C` | `#ACCBD3` / `#C2D2D5` | Home/Practice-hub card/icon-circle tint — baked flat per appearance |
| `library` | terracotta `#E07E57` | `#C24A2C` | The **songs place** — the home "Song library" strip (ADR 0081), completing the teal · plum · terracotta home triad; retires the ADR 0023 song-blue |
| `libraryCardWash` / `libraryCircleWash` | `#37241B` / `#4A2C1E` | `#E8C7B6` / `#EFD6C7` | Song-library strip card/icon-circle tint — baked flat per appearance |
| `toolkit` | indigo/violet `#9E8CE6` | `#4B3F94` | The **Toolkit** hub (ADR 0096) — the fourth home card + reference destination. A "study/reference" hue kept clear of the teal · plum · terracotta triad; theme-invariant for now (no Blood Moon swap) |
| `toolkitCardWash` / `toolkitCircleWash` | `#231D48` / `#2D2657` | `#D4CEEC` / `#CEC7E9` | Toolkit strip + hub-section card/icon-circle tint — baked flat per appearance |
| `journal` | gold `#D2A954` | `#9A7521` | The **Journal** space (ADR 0100) — the fifth home card + read-only practice-history destination. A warm "notebook/ink" hue clear of the teal · plum · terracotta triad and the indigo hub; also tints the space's owner-attribution captions. Theme-invariant for now (no Blood Moon swap) |
| `journalCardWash` / `journalCircleWash` | `#2A2211` / `#342A15` | `#F0E7CE` / `#EBDFBE` | Journal strip card/icon-circle tint — baked flat per appearance |
| `confirmWash` | `#13421E` | `#B4DAAF` | "Add a song" tint — baked flat, same rationale (ADR 0063) |
| `fine` | `#EAF2FF` (high-key) | `#1F3651` (low-key) | Fine-mode precision selection — same cool hue, inverted key |
| `mastery` | teal `#60A8C7` | `#2B6982` | Mastery dots/stars (Home, Library, waveform loop picker) — **tracks the brand hero** `practice` (teal by default; follows it to terracotta in Blood Moon, ADR 0081), never the metronome plum |
| `marker` | orange | orange | Reserved (ADR 0023) — not currently drawn anywhere; kept as the next free functional hue |
| `pin` | purple | purple | Waveform markers, single-point (system dynamic colour) |
| `loopPalette` | red/orange/gold/magenta/violet/blue | deepened twins, same hues | Per-loop **identity** colour (ADR 0023); plain non-brand hues since ADR 0063 — a loop's job is to be distinguishable, not brand-consistent |
| `barDefault` | `#5C5C5C` | `#88817A` | Neutral "off" fill — empty mastery dots, minimap base track |
| `barPlayed` | `#313131` | `#C1B6AD` | Neutral track (minimap) |

The detail waveform is tinted the **teal anchor** (the brand hero, ADR 0081) so the
song reads as themed chrome, stays distinct from the neutral **beat
grid** behind it (ADR 0022), and lets the **green** live state and the **per-loop
coloured** annotations pop against it. The capture overlays (forming/punch wash) use
`active` (green) and remain bounded by the playhead. Per-loop colour encodes loop
**identity**, with overlap shown by row position and loop *state* carried by line
weight/opacity (ADR 0023, superseding ADR 0018's colour-is-state rule). The
`loopPalette` deliberately avoids the functional hues — the teal bars, purple
(markers), and green (live state) — so a loop never blends into the chrome or the
active wash. A saved loop's range can only be edited via its edit sheet's explicit
**"Adjust range on waveform"** — a loop's edge is not directly draggable on the
waveform itself (ADR 0063); the active loop's boundary is marked with a bold static
line instead of a grabbable knob.

No gradients **except** the tempo-automator progress bar (to signal progression
from comfortable to target speed).

**The brand mark stays distinct from product chrome.** The "Red Moon" brand mark (app
icon + Settings/About logo, ADR 0061; background keyed transparent in ADR 0063) keeps
its original, dustier slate-teal artwork — the same teal *hue family* as the brand hero
(`practice`) but not a pixel match, so the static mark stays quiet while the UI accent
carries its own visual weight. (The planned **Blood Moon** theme re-tints the wordmark
and this logo terracotta — Slice 2, ADR 0081.) Don't reach for a literal hex directly
in views; go through `PocketColor.practice`/`.metronome`/`.library`, and use the other
tokens for everything else.

### 3.2 Typography

- **Monospace** for *all* time values and BPM (e.g. `1:51`, `0.90×`, `76 BPM`) —
  use the `pocketMono` font helper. This keeps numbers from jittering as they
  change.
- **Futura** for *all* prose/UI text — use the `Font.futura(_:weight:)` helper (ADR
  0061). It echoes the "Red Moon" wordmark. Futura ships **Medium** (base) and
  **Bold**; the helper maps semibold/bold/heavy → Futura-Bold and `.headline` → Bold to
  keep emphasis. Do **not** call `.font(.headline)` / `.system(...)` directly — route
  everything through `futura`/`pocketMono` so the family stays swappable from one place.
- Respect **Dynamic Type** — `futura` is built with `relativeTo:` so styles still scale;
  don't hard-code point sizes where a text style fits.
- **Navigation-bar titles** are Futura too, via a single global `UINavigationBarAppearance`
  (`NavigationBarStyle`, applied once at launch — ADR 0110), since SwiftUI's `.navigationTitle` has no
  native font hook. Only the title font changes; bar backgrounds are untouched. Screens that need a
  custom centre (Home wordmark, Metronome header) still use a `.principal` toolbar item.

### 3.3 Motion

- Interactions feel musical: the amber ring filling on a hold, the loop region
  appearing on the second tap, the creation sheet sliding in from below.
- Timing should feel deliberate. Provide a **Reduce Motion** fallback (e.g.
  cross-fade instead of slide; instant fill instead of radial sweep).

### 3.4 Component conventions

- Collapsible panels use a **chevron** and show a **summary line when collapsed**
  (the user is never left wondering what's hidden). Example collapsed song-info
  header: `G minor · ★★★☆☆ · Groove / lead phrasing`.
- Mode/selection controls are **pills**.
- Numbers that respond to input (BPM, speed) update **live**.
- **Coined-term fields carry a tappable ⓘ** (`FieldInfoLabel`) with a one-line definition in a
  popover — Mastery, Command tempo, Focus, loop Type, derived song Mastery. The test is whether a
  musician can infer the meaning from the label alone: standard vocabulary (Key, Genre, BPM) gets
  none, because an ⓘ there is noise. Copy is centralised in `PracticeFieldInfo`.
- **List rows carry the same affordances everywhere** (`.pocketRowActions`): a long-press menu
  reading *item actions → Favourite → Delete*, a leading favourite swipe, a trailing delete swipe,
  and an Undo toast after every delete. Adopt the modifier rather than hand-rolling a row's actions;
  every parameter is optional, so a list declines what it doesn't own (loops have no Delete — a loop
  belongs to its song) instead of inventing a variation. Tint is the space's accent.

---

## 4. Screens & components

Designed in MVP priority order (matches the build phases). Design the whole
vision if useful, but know that **Phase 1** is what gets built first.

| Priority | Screen / component | Notes |
|---|---|---|
| **P1** | **Waveform practice screen** | The core. See §4.1 — design this first and most carefully. |
| **P1** | Loop creation sheet | Slides in below the transport when a loop is captured. |
| **P1** | Library / file browser | Pick local/iCloud files. **Text-forward song cards** (title, key · BPM · loop/marker counts, collection chips, mastery dots, a mastery-tier colour accent — no artwork) in one list with a **Group by** control: Mastery · Recently Added · Title · Artist · Album · Genre. Collection filter chips above the list. ADR 0035/0036. |
| P2 | Loops panel + Loop active panel | Active panel has speed, repeat, tempo automator, session notes. |
| P2 | Markers panel + Pin Marker popover | Single-point annotations; purple. |
| ~~P2~~ | ~~Song info / Repertoire panel~~ | **Removed (ADR 0042).** Key / mastery / collections now live only in the song-details sheet (hold the title); not duplicated in the practice scroll area. |
| **P1** | **Home hub** | The app's front door (ADR 0044). Header shows the "Red Moon" wordmark graphic (ADR 0063) in place of plain title text. Greeting · "Jump back in" resume card · **Practice card** · Metronome card · Song library strip · **Journal card** (→ the notes+takes practice-history space, ADR 0100, the 4th strip) · **Toolkit card** (→ the chords/theory reference hub, ADR 0096, now 5th/last) · Add a song. **Planner-free for V1** — see §4.2. |
| **P1** | **Practice space** | A top-level destination (ADR 0046), plum `practice` accent. A list of **your exercises** (command → reach) above a live **"Build today's session"** planner entry (V2 planner Slice 3). Tap **+** to create; tap a unit → its **training run** (own engine, `engine.run(ramp:)`): set up working/command/reach + warm-up steps with a routine staircase, then a live BPM/beat/session readout while it plays. |
| **P1** | **Journal space** | A top-level **read-only** practice-history destination (ADR 0100), the fourth home card in the warm-gold `journal` accent — *look back*, distinct from Practice's *author* and Toolkit's *explore*. One newest-first, day-grouped timeline merging journal **notes** and audio **takes** across loops + exercises, with an **All / Notes / Takes** filter, **search** (song / exercise / template / date), a **Newest ↔ Oldest** sort toggle, and gold owner-attribution captions; takes play in place. Authoring stays on the owner (`JournalSheet`). |
| **P1** | **Toolkit hub** | A top-level **reference** destination (ADR 0096), the fifth home card (now after Journal) in the indigo/violet `toolkit` accent — *explore / keep*, distinct from Practice's *author*. A landing list of sections; **Slice 1**: **My chords** (the `SavedChord` library as a full grid; tap → large diagram + rename/delete; **+** builds via the placer in "Save" mode) and a searchable **Glossary** of chord/scale/theory terms. Audio-free by design; *Hear* / identifier / scales / ear-training are Slices 2–4, each its own ADR. |
| **V2** | **Practice planner** | The "Build today's session" path **inside Practice** (ADR 0046 re-homes ADRs 0014–0016; ADR 0015/0072/0073). `PlannerView`: a duration selector (Quick 15 / Focused 30 / Full 60, default short) · a short list of **goals** that steer selection · **Generate** → a provisional `Routine` you review, then Start in the shipped player. `GoalEditorView`: template picker (four in-house `GoalTemplate`s) → name → priority (Low/Normal/High over the stored weight) → skill trim → optional target song → met toggle. No active goals ⇒ Generate falls back to a due-based Quick session. AI decomposition remains deferred (Slice 5). |

### 4.1 Waveform practice screen — layout

Structured as a **fixed practice cockpit over a scrollable reference area** (see
`docs/decisions/0003-practice-screen-layout.md`).

**Fixed (pinned — never scrolls):**

1. Song strip — name, artist, duration, key
2. Speed / BPM bar (always visible)
3. Mode description line — replaced by the **edit toolbar** (▶ audition ·
   "New loop" / "Editing loop" · **Y/N**) while a loop is captured
4. Waveform (detail view) — **SoundCloud-style mirrored bars** (blue): top half
   full opacity, bottom half ~60% reflection. **Pinch to zoom** into a section (the
   view tracks the playhead). The annotation library draws on the **borders**, off
   the bars (ADR 0023): **markers as purple inverted triangles** along the top edge,
   **all saved loops as coloured lines** along the bottom edge. Each loop has its own
   colour (**identity**); overlapping/nested loops **stack into rows (lanes)** so
   overlap reads by position. Loop *state* is carried by weight — the **active loop**
   is heavier/full-strength (plus its translucent fill in its own hue), saved loops
   dimmed. Lanes are capped (deeper nesting clamps into the last lane); the bands sit
   within the fixed frame, so the waveform never changes height. ADR 0023
   (supersedes the colour-is-state rule of ADR 0018).
5. Time ruler — labels the **visible window** (follows the zoom)
6. Minimap (full song, compressed) — a **compressed whole-song silhouette** (the envelope
   through the same display gamma as the detail waveform, ADR 0055) so the strip maps the
   song's shape instead of a flat bar, with the active loop region (amber fill), **all saved
   loops** as thin underlines along the bottom (compressed, ≤2 lanes), fine selection
   (cyan), marker dots (purple), playhead, and the **viewport box** (the zoomed slice)
   when the detail waveform is zoomed. (Minimap not yet updated to per-loop colours /
   the triangle glyph — ADR 0023 deferred it.)
7. Transport bar — three zones (ADR 0030). **Left:** three identity controls, each a
   **glyph in a circle** (no captions) — **Loop** (green `repeat`, punch in/out),
   **Mark** (pink triangle, drop marker), **Fine** (blue calipers, precise-edit toggle);
   the active one's circle fills with its colour. **Centre:** a header (fixed height,
   matched font size so the states cross-fade without the row shifting) over a
   background-free **rewind · pause · forward** cluster — the header is the loop name +
   range when a loop is active, else **empty** (the idle playhead timecode was dropped as
   redundant — the live time already rides the playhead as a `TimeBubble` on the canvas,
   ADR 0075; the fixed height is kept so nothing shifts). Rewind: 1× restart, 2×
   previous loop; forward: next loop (cross-song deferred — forward/prev dim with no
   loop). **Right (loop active only):** a strip in the loop's **identity colour** with an
   ✕ deactivator — the "a loop is armed" signal. Click lives on the speed bar (ADR 0027).
   **Greys out and locks while a loop is being created/edited** — controls move up to the
   edit toolbar (item 3). A left-edge **swipe-back guard** keeps a scrub from popping the
   screen back to the library.

A hairline separates the cockpit from the scroll area below.

**Scrollable (reference):**

8. Loops panel (collapsible) — each loop shows a **name** + time range, with the
   **"A"** automator (speed-ramp) control trailing. Tap a row to activate it; the
   active loop drives the waveform/minimap highlight and the transport loop range.
   **Press and hold** a row (haptic) to open the edit sheet — rename / adjust range /
   colour / delete. The colour row offers Auto (the automatic hue), the palette, and a
   custom colour wheel (low-contrast picks get an advisory hint), pinning a loop's
   colour everywhere it shows (ADR 0031). Speed and repeats live in the automator, not
   the row (ADR 0013 / 0028).
9. Markers panel (collapsible) — name + timecode; tap a row to edit
   (rename / delete).

In **landscape** (practice screen only, ADR 0042) the cockpit takes the full width
— a compact back · title · ☰ top bar replaces the song strip, the speed and transport
bars slim down, and the waveform flexes to fill the height — while the loops/markers
reference (items 8–9 above) becomes a **slide-in drawer** from the right, toggled by
the ☰ button and closed by default. The song-info panel that used to sit at the bottom
of the scroll area was removed (ADR 0042) — its key / mastery / collections live in the
song-details sheet (hold the title).

While a loop is being created or its range adjusted, the cockpit enters **edit
mode**: the transport greys out and locks, and the mode line becomes the edit
toolbar (▶ audition · state label · Y/N). **Y** creates the loop **instantly** — it's
auto-named ("Loop 3") and made active, no naming sheet (or commits a range edit);
rename it later from its row. **N** discards. You leave edit mode via Y/N, not by
switching modes. Deleting a loop or marker raises a **"Deleted X · Undo"** toast at
the bottom of the cockpit (auto-dismiss ~4s) to reverse an accidental delete (ADR 0019).

**Interaction (ADR 0005 rounds 4–5):** one rule for touch — **tap = seek, drag =
scrub, hold-drag = select a loop, pinch = zoom** (the "Navigate" default). A still
**hold (~350 ms) then drag** paints a loop region directly on the waveform (a haptic
confirms the hold armed; release commits it to a confirmable draft) — the on-waveform
way to set a loop's *range*. Capturing **at the playhead** is done with the
**action-bar buttons**:
- **Mark** → drop a marker at the playhead (then name it).
- **Loop** → punch the loop in, then out, at the playhead (green region fills; the
  edit toolbar appears on the out-punch).
- **Fine** → toggle precise editing: two draggable blue handles define the loop
  bounds; the edit toolbar appears.

**Speed bar:** the speed readout (`0.90×`), the slider, the read-only BPM
display (`round(songBPM × speed)`), and the **Click** (metronome) toggle share
**one row** to stay compact in the pinned cockpit; presets 0.25/0.50/0.75 and
reset-to-1.0 sit beneath. The Click rides next to the BPM because it's a tempo
tool, in its own teal so it never reads as a transport control (ADR 0027); it
greys out until the song has a tempo + the 1. The slider
uses an **asymmetric scale** (0.25–1.0 occupies ~54% of the track, so 1.0 sits
slightly left of centre — slow practice deserves more precision) — still to be
implemented; a linear slider stands in for now.

### 4.2 Home hub — layout

The app's front door (ADR 0044), in place of launching straight into the library.
**Dark-first**, a single scrolling column, top → bottom:

1. **Greeting** — a quiet time-of-day lead-in ("Good evening") over a fixed
   **"Ready to practice"** headline. (V2: planner "today's routine" cards slot in
   directly under here — the layout leaves room.)
2. **"Jump back in"** card — the single most-recently-practised song
   (`Song.lastPracticed`), with its **mastery** and a relative **last-practised**
   time. **Hidden on first launch** (no history). Tap → the practice screen, which
   resumes the song at its **last-practiced tempo** (ADR 0044). Neutral chrome.
3. **Metronome card** — the screen's **one accent** (teal, `PocketColor.metronome`).
   Tap → the standalone metronome (full-screen; it owns its own navigation). This is
   the metronome's permanent home — it retires the temporary Library toolbar button
   (ADR 0043).
4. **"Your songs"** — a **vertical list** (not a carousel) reusing the library's
   `SongCard`, ordered by recent practice, the resume song dropped (it already
   headlines above), capped to a short preview. **"See all"** pushes the full
   `LibraryView` (grouped / searchable — unchanged, just no longer the root).
5. **"Add a song"** — opens the file importer (creation reachable from the front door).

**Navigation:** the home hub is the **app root**; Library, the metronome, and the
practice screen are reached from it. Nothing is lost — the full library is one tap
away under "See all".

---

## 5. What to deliver for every screen

A picture alone causes drift. For each screen, the deliverable is:

1. **All states**, not just the happy path:
   - default, **loading**, **empty** (no songs / no loops / no markers),
     **error**, and the **active/playing** state.
   - edge cases: very long song/artist names, a song with **no BPM set**, a loop
     spanning the whole song, 0 vs many loops/markers.
2. **Token references** — annotate which colour/type tokens each element uses.
3. **Measurements** that matter (spacing, touch-target sizes, panel heights).
4. **The implementable artifact** (see §6.4): SwiftUI for this project, or a
   tight annotated spec.

---

## 6. Working protocol — for seamless communication & implementation

This is the part that keeps design and code in lockstep. Follow it every session.

### 6.1 Establish the contract once
The design tokens (§3) are the shared vocabulary. Brief in token names. When a
design introduces a value that has no token, **name it** ("needs a new
`textTertiary` at white @ 40%") so it's added to `DesignTokens.swift` in the same
change — never let a raw hex value live only in a mockup.

### 6.2 Brief one screen at a time, with full context
Don't ask for "the whole app." Use the §7 template per screen. Paste this doc
(or §1–§3) as context first so the ethos and system are in scope. State the
device frame explicitly: **iPhone, portrait, dark**.

### 6.3 Iterate in tight, single-axis loops
- Change **one thing at a time** ("tighten the vertical rhythm in the transport
  bar" — not "make it better").
- Refer to elements by name (the names in §4.1), not by pointing.
- Always give the **why**, tied to the ethos ("the ring fill should feel
  unhurried — ~650ms, ease-out").
- Ask for variants side-by-side when comparing (A/B), then pick and move on.

### 6.4 Ask for an implementable deliverable
Because the target is SwiftUI/iOS, prefer in order:
1. **SwiftUI code** for the screen/component (most seamless — paste straight in,
   then wire to real data). Require it to use the token names from §3 and native
   components.
2. **An annotated spec + mockup** with token references and measurements, if code
   isn't practical for that artifact.

Avoid accepting raw images with no spec — they look done but aren't buildable.

### 6.5 Native-fidelity rules (state these in the brief)
- SF Symbols for icons; system sheets/navigation; respect safe areas.
- Dynamic Type, 44pt touch targets, VoiceOver labels on every control.
- Provide the **Reduce Motion** alternative for any custom animation.
- Don't invent controls where a native one exists (sliders, steppers, sheets).

### 6.6 Capture decisions so they aren't re-litigated
When a design choice is settled (e.g. "speed lives above the waveform, always
visible"), record it — a one-line note in this doc or a short ADR under
`docs/decisions/`. Future sessions read the decision instead of reopening it.

### 6.7 Close the loop in code
When a design is approved: implement behind the tokens, run the pre-push gate
(SwiftLint → build → test, per `AGENTS.md`), then **screenshot it in the iOS
Simulator** and compare against the design. Designs are "done" only when the
running app matches.

---

## 7. Per-screen request template (copy this)

```
SCREEN: <name, e.g. Waveform practice screen — Tap mode, loop captured>
FRAME: iPhone, portrait, dark (#0F0F0F)
CONTEXT: <paste §1–§3 of this doc, or link it>

GOAL: <one sentence on what this screen is for>

CONTENT / ELEMENTS:
- <list every element top→bottom, with the data it shows>

STATES TO COVER:
- default / loading / empty / error / active(playing)
- edge cases: <long titles, no BPM, 0 vs many loops, etc.>

INTERACTIONS:
- <taps, holds with timings, drags, what each produces>

CONSTRAINTS:
- Use tokens from §3 by name; flag any new token needed.
- Native iOS components; SF Symbols; Dynamic Type; 44pt targets; VoiceOver.
- Motion feels musical; include a Reduce Motion fallback.

DELIVERABLE: SwiftUI code using the named tokens  (preferred)
             OR annotated mockup + spec with token refs + measurements

NON-GOALS: <what NOT to design here, to keep scope tight>
```

---

## 8. Definition of done (check before accepting a design)

- [ ] Honours the ethos — musical, unhurried, intentional.
- [ ] Dark-first and legible at `#0F0F0F`; contrast checked.
- [ ] Colour is functional and uses the §3 semantics (green/amber/blue/purple/red).
- [ ] Monospace for every time/BPM value; Dynamic Type elsewhere.
- [ ] All states designed (default/loading/empty/error/active) + edge cases.
- [ ] Native components, SF Symbols, safe areas, 44pt targets.
- [ ] VoiceOver labels and a Reduce Motion fallback specified.
- [ ] Every value maps to a token (or a named new token to add).
- [ ] Delivered as SwiftUI or an annotated, measured spec — not a bare image.
- [ ] (After build) Simulator screenshot matches the design.