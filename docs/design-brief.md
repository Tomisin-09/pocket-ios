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
  a stand). Background is **near-black `#0F0F0F`**, not pure black. Design dark
  first; a light theme is not a V1 requirement.
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

| Token | Value | Meaning |
|---|---|---|
| `background` | `#0F0F0F` | App background (near-black) |
| `textPrimary` | white | Primary text |
| `textSecondary` | white @ 60% | Secondary/labels |
| `active` | green | Playing / active loop |
| `marker` | amber/orange | Loop markers & selection |
| `fine` | blue | Fine-mode precision selection |
| `pin` | purple | Waveform markers (single-point) |
| `danger` | red | Delete / destructive |
| `barDefault` | white @ 35% | Waveform bar, default |
| `barPlayed` | white @ 18% | Waveform bar, before playhead |

No gradients **except** the tempo-automator progress bar (green → amber, to
signal progression from comfortable to target speed).

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
4. Waveform (detail view) — **SoundCloud-style mirrored bars**: top half full
   opacity, bottom half ~60% reflection. **Pinch to zoom** into a section (the view
   tracks the playhead).
5. Time ruler
6. Minimap (full song, compressed) — loop regions (amber), fine selection (blue),
   marker dots (purple), playhead, and the **viewport box** (the zoomed slice) when
   the detail waveform is zoomed.
7. Transport bar — play/pause · time · loop info (name + range + ✕ exit chip) ·
   mode pills (Scroll/Tap/Fine). **Greys out and locks while a loop is being
   created/edited** — controls move up to the edit toolbar (item 3).

A hairline separates the cockpit from the scroll area below.

**Scrollable (reference):**

8. Loops panel (collapsible) — each loop shows a **name** + time range · speed ·
   repeats. Tap a row to edit (name / speed / repeats / delete); tap the
   trailing **play button** to activate it. The active loop drives the
   waveform/minimap highlight and the transport loop range.
9. Markers panel (collapsible) — name + timecode; tap a row to edit
   (rename / delete).
10. Song info panel (collapsible, **collapsed by default**) — demoted here from
    the top; key, proficiency, progression, collections.

While a loop is being created or its range adjusted, the cockpit enters **edit
mode**: the transport greys out and locks, and the mode line becomes the edit
toolbar (▶ audition · state label · Y/N). **Y** opens the naming sheet for a new
loop (or commits a range edit); **N** discards. You leave edit mode via Y/N, not by
switching modes.

**Three interaction modes** (pills in the transport bar):
- **Scroll** (default): tap to set playhead; **hold 650ms** → amber ring fills
  radially around the playhead → Pin Marker popover.
- **Tap:** drag to scrub; short tap sets loop start, second tap closes the loop
  (green region fills, edit toolbar appears).
- **Fine:** two draggable blue handles define loop bounds; edit toolbar appears
  on entering the mode.

**Speed bar:** the speed readout (`0.90×`), the slider, and the read-only BPM
display (`round(songBPM × speed)`) share **one row** to stay compact in the
pinned cockpit; presets 0.25/0.50/0.75 and reset-to-1.0 sit beneath. The slider
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