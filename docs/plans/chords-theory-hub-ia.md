# Chords / theory / resources hub — IA & design pass

**Companion to:** ADR 0096 (direction). This is the information-architecture and design pass ADR 0096
parked for, the thing "before it moves to Accepted." It resolves the questions the ADR deferred —
**where the hub attaches, what screens it holds, how build / hear / explore / keep interrelate, empty
states, and what ships first** — and ends with the short list of product decisions the player still has to
ratify to promote ADR 0096 to Accepted.

Status: **draft for ratification** (2026-07-17). Nothing here is scheduled to build yet; this exists so
that when the first slice is scoped it starts from a resolved IA, not a blank page.

---

## 1. What the hub is (one line)

A top-level **reference destination** — *explore / hear / keep* — distinct from the exercise editors,
whose job is *author practice content*. It is the free, deterministic, objective floor (ADR 0093/0094);
the AI "explain / suggest" layer (ADR 0092, "Red Moon Oracle") sits on top of it later, opt-in and paid.

Working name: **"Toolkit"** (see decision D2). Used below as a placeholder.

---

## 2. Where it attaches (resolves ADR 0096 H1 / the "Practice tab vs. its own" question)

The app is **not** a `TabView`. `HomeView` is a `NavigationStack` front door with a vertical stack of
nav **cards** — a deliberate home-hub, planner-free V1 (ADR 0044). Today's card triad:

| Card | Accent | Role |
|---|---|---|
| Song library | terracotta (`PocketColor.library`) | your songs |
| Metronome | plum (`PocketColor.metronome`) | a tool |
| Practice | teal (`PocketColor.practice`) | author + run practice |

**Decision (recommended): the hub is a fourth home card that pushes its own `NavigationStack`
destination.** It slots into the existing card pattern — no tab bar to introduce, no navigation paradigm
change, and it reads as a peer to Practice/Metronome/Library exactly as H1 wants ("a real destination,"
not a Settings-buried list). It needs a **fourth accent hue** distinct from the teal·plum·terracotta triad
(see D3).

Rejected, per ADR 0096:
- **A TabView "Reference" tab** — would re-architect the whole app's navigation for one destination;
  premature and off-pattern.
- **Nested under Practice** — Practice *authors* content; the hub is *reference*. H1 keeps them separate.
- **Buried in Settings** — reference reached for *during* practice shouldn't hide in Settings.

Card copy (draft): title **Toolkit**, subtitle **"Chords, scales & theory reference."** Icon candidate:
`books.vertical` or `pianokeys` (SF Symbol) — design call.

---

## 3. Screen inventory

```
Home
└─ Toolkit (hub landing — a list of sections, each a push)
   ├─ My Chords ......... your saved voicings (ADR 0095)          [substrate exists]
   ├─ Chord identifier .. tap a shape → name it, hear it (0093)   [engine exists; audio is new]
   ├─ Scales & modes .... browse the catalog, hear boxes (0085)   [renderer exists; audio is new]
   ├─ Intervals & ear ... play/compare intervals, self-judged     [direction only (0094)]
   └─ Glossary .......... plain terms sheet (sus4 / tritone / …)  [static content, no deps]
```

The landing is a simple sectioned list (same visual grammar as the home cards, one level down). Each row:
icon + name + one-line "what it's for" + a count or state where it has one (e.g. My Chords → "12 saved").

### 3.1 My Chords
The `SavedChord` library (ADR 0095), **promoted** from the in-context Add-menu section to a full screen.
- Grid/list of saved voicings, each a `ChordDiagramView` + name.
- Tap a chord → detail: large diagram, its identifier reading, **Hear**, **Use in an exercise** (hands the
  voicing to a new or existing chord progression), **Rename**, **Delete**.
- **+ Build a chord** → opens the existing `CustomChordSheet` placer (already emits + saves a voicing).
- Empty state: "Chords you save turn up here. Build one, or save one from any chord exercise." + Build CTA.
- The in-context menu section (ADR 0095) **stays** — this screen is where the library is *managed*; the
  menu is where it's *reused inline*. Both read the same `@Query`.

### 3.2 Chord identifier / voicer
The reverse-lookup tool (ADR 0093) as a **standalone** surface, not bolted to authoring.
- Reuses `ChordBoardEditor` (the tappable board just extracted in pocket-152) + `ChordIdentifierPanel`.
- Tap in a shape → "Looks like …" candidates; **Hear** the voicing; **Save to My Chords**.
- This is the "name a shape, and hear it" of ADR 0094 T2a.

### 3.3 Scales & modes explorer
Reference over the ADR 0085/0091 catalog (12 scales/modes, CAGED boxes, root-anchor labels).
- Pick a scale + root → the box renders (reuse the scale board); **Hear** ascends/descends the box.
- Read-only exploration; "Use in an exercise" hands off to the Scales exercise editor.

### 3.4 Intervals & ear-training
The self-judged call-and-response of ADR 0094 — **on the safe side of the no-grading line (ADR 0070)**.
- Play an interval / two notes; player names it *to themselves*; reveal the answer. **The app never scores
  it** — no right/wrong tally, no streak, no XP. Objective *identity* (a tritone is a tritone) is fine to
  state; *judging the player* is not.
- Lowest-substrate section; ships last.

### 3.5 Glossary
Static in-house reference (ADR 0065 T8) — the clearest-safe feature.
- A searchable list of terms (sus4, tritone, CAGED, inversion, mode, …), each a short plain-language
  definition. No audio, no state, no dependencies. **This is why it's a Slice-1 anchor** (§5).

---

## 4. The four verbs, and how the sections share them

The hub's coherence comes from four verbs that recur across sections rather than living in one screen:

- **Keep** — save a voicing/shape → it lands in **My Chords**. Save happens *anywhere* (the placer, the
  identifier); the hub is where kept things live.
- **Build** — author a voicing (the `CustomChordSheet` placer). Reachable from My Chords and the identifier.
- **Hear** — audition a chord / scale box / interval. **New shared capability** (see D4) — the single
  largest dependency, cutting across 3.2/3.3/3.4.
- **Explore** — browse scales/modes and the glossary; read, don't author.

Cross-links that make it one place rather than five: identifier → **Save to My Chords**; My Chords item →
**Hear** / **Use in an exercise**; scales explorer → **Use in an exercise**. Every "Use in an exercise"
hands a value to the existing authoring surfaces — the hub feeds practice, it doesn't fork it.

---

## 5. Phasing (what promotes ADR 0096 to Accepted, and what follows)

Slices are ordered by *substrate that exists today*, so each is mostly presentation over real types:

- **Slice 1 — the shell + the two zero-dependency tenants.** Home card + accent hue + hub landing;
  **My Chords** promoted to a full screen (SavedChord exists); **Glossary** (static content). No audio, no
  new engine. This alone is a shippable, coherent hub and is what moves ADR 0096 from Proposed → Accepted.
- **Slice 2 — Chord identifier/voicer standalone + Hear-a-chord.** Reuses `ChordBoardEditor` +
  `ChordIdentifierPanel`; introduces the **Hear** capability (D4). Its own ADR if the audio approach is
  non-trivial.
- **Slice 3 — Scales & modes explorer** (+ Hear a box), over the ADR 0085/0091 catalog.
- **Slice 4 — Intervals & ear-training** (self-judged; ADR 0094). Needs its own ADR for the no-grading
  interaction design.
- **Later — AI "explain/suggest" layer** (ADR 0092) over any tenant; opt-in, paid, deferred.

Slice 1 deliberately avoids the audio dependency so the hub can exist before Hear is solved.

---

## 6. Decisions — ratified 2026-07-17 (promoted ADR 0096 → Accepted)

| # | Decision | Ratified |
|---|---|---|
| **D1** | Attach point (fourth card vs. tab vs. nested vs. Settings). | ✅ **Fourth home card → own NavigationStack.** Peer to Practice/Metronome/Song library; no tab bar, not nested under Practice, not in Settings. |
| **D2** | Player-facing name. | ✅ **"Toolkit."** Not "Red Moon Oracle" — that's the paid AI layer (ADR 0092); this is the free floor. |
| **D3** | The fourth accent hue (triad is teal·plum·terracotta). | ✅ **Indigo/violet** — a "study/reference" hue. New `PocketColor` token + light/dark bake (ADR 0062/0081); exact swatch chosen at build. |
| **D4** | *Hear* — needs a pitched-tone source the app lacks (ADR 0001 = file playback + click). Synth vs. sampled? | ✅ **Deferred to Slice 2 with its own ADR.** Slice 1 stays audio-free; synth-vs-sampled decided when Slice 2 is scoped. |
| **D5** | Slice-1 scope. | ✅ **Shell + My Chords + Glossary** — the only two zero-dependency tenants; smallest coherent, audio-free hub. |

ADR 0096 is now **Accepted**. **Slice 1** (§5) is scoped and ready to schedule; D4 gets its own ADR when
Slice 2 is taken up.

### Slice 1 — built (2026-07-17)

Shipped as `Pocket/Features/Toolkit/` + the `Indigo`/`IndigoCardWash`/`IndigoCircleWash` colour sets and
`PocketColor.toolkit`:

- **Home card** — a fourth `HomeNavCard` (the four home strips were refactored onto one shared component)
  pushes `ToolkitView` in the indigo accent.
- **`ToolkitView`** — landing list of sections (My chords with a live "N saved" count; Glossary with its
  term count), one visual level down from the home cards.
- **`MyChordsView`** — the `SavedChord` library as a full grid; `MyChordDetailView` gives each a large
  diagram + Rename/Delete; **+** opens the existing `CustomChordSheet` in "Save" mode (a new
  `confirmTitle` seam) so building here *keeps* rather than *inserts*. The in-context menu
  (`SavedChordsSheet`) stays for inline reuse — both read the same `@Query`.
- **`GlossaryView` + `GlossaryTerm`** — a static, searchable, area-grouped terms sheet; the catalog +
  pure `matches(_:)`/`matching(_:)` search are unit-tested.

Deferred within the sections as planned: *Hear*, the identifier reading, and *Use in an exercise* on the
My Chords detail (Slice 2+ / D4).

---

## 7. Open risks / notes

- **Don't let the hub duplicate authoring.** Every hub affordance either *references* (read/hear) or
  *hands off* to the existing editors via "Use in an exercise." If we find ourselves rebuilding the chord
  progression editor inside the hub, the IA has drifted.
- **The no-grading spine (ADR 0070) is load-bearing for §3.4.** Interval/ear training states objective
  identity and lets the player self-check; it must never tally right/wrong. This is the one section where
  the safe/unsafe line is easy to cross — it ships last and gets its own ADR for exactly that reason.
- **Audio is the gating dependency, not the IA.** Three of five sections want Hear (D4). The IA is designed
  so the hub is useful *without* it (Slice 1), which de-risks the whole direction.
