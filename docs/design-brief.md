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
- **Dark-first.** The practice screen is used in low light (evening practice, on
  a stand). Background is **near-black `#0F0F0F`**, not pure black — the blue
  accents and per-loop colours read best against black. Design dark first; a light
  theme is not a V1 requirement. (ADR 0023.)
- **Audio reality:** the waveform/speed/loop engine runs on **DRM-free local &
  iCloud files** only. Apple Music is **browse/metadata only** — do not design a
  waveform or speed control for Apple Music tracks; design their cards to show
  metadata and an "open in Music" affordance instead. (See
  `docs/decisions/0001-audio-source-local-first.md`.)
- **Orientation:** portrait only for V1.
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

Blue identity (the song's bars, anchored on `#2a6796`) with **green** as the live
state, on a near-black background (ADR 0023). Hue carries meaning: blue = the song,
green = live/go, and the per-loop identity hues are kept out of both families. The
table is grouped by **semantic role** — the seam a future swappable theme slots into.

| Token | Value | Meaning |
|---|---|---|
| `background` | `#0F0F0F` | App background (near-black) |
| `waveformBar` | `#2a6796` @ 85% | Detail-waveform bar, ahead of the playhead (the song) |
| `waveformBarPlayed` | `#2a6796` @ 40% | Detail-waveform bar, behind the playhead (recedes) |
| `textPrimary` | white | Primary text |
| `textSecondary` | white @ 60% | Secondary/labels |
| `active` | green | Live state — playing, the forming loop, the active region |
| `confirm` | green | Confirm / save (the loop-capture ✓) |
| `danger` | red | Discard / delete / destructive (the loop-capture ✗) |
| `fine` | cyan `#56C6D9` | Fine-mode precision selection |
| `marker` | amber/orange | Active-loop region fill base / selection |
| `pin` | purple | Waveform markers (single-point) |
| `loopPalette` | amber, gold, coral, magenta, violet, teal | Per-loop **identity** colour (ADR 0023) |
| `barDefault` | white @ 35% | Neutral "off" fill — empty proficiency dots, minimap base track |
| `barPlayed` | white @ 18% | Neutral track (minimap) |

The detail waveform is tinted the **blue anchor** so the song reads as themed chrome,
stays distinct from the neutral (white) **beat grid** behind it (ADR 0022), and lets
the **green** live state and the **per-loop coloured** annotations pop against it. The
capture overlays (forming/punch wash) use `active` (green) and remain bounded by the
playhead. Per-loop colour encodes loop **identity**, with overlap shown by row
position and loop *state* carried by line weight/opacity (ADR 0023, superseding ADR
0018's colour-is-state rule). The `loopPalette` deliberately avoids the functional
hues — blue (bars/fine), purple (markers), and green (live state) — so a loop never
blends into the chrome or the active wash.

No gradients **except** the tempo-automator progress bar (to signal progression
from comfortable to target speed).

### 3.2 Typography

- **Monospace** for *all* time values and BPM (e.g. `1:51`, `0.90×`, `76 BPM`) —
  use the `pocketMono` font helper. This keeps numbers from jittering as they
  change.
- **System sans** (`-apple-system` / `.system`) for everything else.
- Respect **Dynamic Type** — don't hard-code point sizes where a text style fits.

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

---

## 4. Screens & components

Designed in MVP priority order (matches the build phases). Design the whole
vision if useful, but know that **Phase 1** is what gets built first.

| Priority | Screen / component | Notes |
|---|---|---|
| **P1** | **Waveform practice screen** | The core. See §4.1 — design this first and most carefully. |
| **P1** | Loop creation sheet | Slides in below the transport when a loop is captured. |
| **P1** | Library / file browser | Pick local/iCloud files; song cards with a blue badge ("4 loops", "2 markers"). |
| P2 | Loops panel + Loop active panel | Active panel has speed, repeat, tempo automator, session notes. |
| P2 | Markers panel + Pin Marker popover | Single-point annotations; purple. |
| P2 | Song info / Repertoire panel | Collapsible, bottom of the practice screen (scrollable), collapsed by default; key, proficiency, progression, collections. |
| P3 | Home / Practice planner | The home screen *is* the planner: time selector, routine cards, session blocks. |

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
6. Minimap (full song, compressed) — the active loop region (amber fill), **all saved
   loops** as thin underlines along the bottom (compressed, ≤2 lanes), fine selection
   (cyan), marker dots (purple), playhead, and the **viewport box** (the zoomed slice)
   when the detail waveform is zoomed. (Minimap not yet updated to per-loop colours /
   the triangle glyph — ADR 0023 deferred it.)
7. Transport bar — row 1: play/pause · time · loop info (name + range + ✕ exit chip).
   Row 2: the **action bar** — **Loop** (punch in/out), **Mark** (drop marker),
   **Fine** (precise-edit toggle, calipers glyph). Click moved to the speed bar
   (ADR 0027). **Greys out and locks while a loop is being created/edited** — controls
   move up to the edit toolbar (item 3). *(A less real-estate-hungry loop-exit
   affordance is still being explored; the ✕ chip stands for now.)*

A hairline separates the cockpit from the scroll area below.

**Scrollable (reference):**

8. Loops panel (collapsible) — each loop shows a **name** + time range, with the
   **"A"** automator (speed-ramp) control trailing. Tap a row to activate it; the
   active loop drives the waveform/minimap highlight and the transport loop range.
   **Press and hold** a row (haptic) to open the edit sheet — rename / adjust range /
   delete. Speed and repeats live in the automator, not the row (ADR 0013 / 0028).
9. Markers panel (collapsible) — name + timecode; tap a row to edit
   (rename / delete).
10. Song info panel (collapsible, **collapsed by default**) — demoted here from
    the top; key, proficiency, progression, collections.

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