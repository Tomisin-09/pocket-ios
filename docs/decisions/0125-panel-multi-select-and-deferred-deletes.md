# ADR 0125 — The practice screen's lists multi-select; the loop row carries its identity colour; deletes there are deferred

- **Status:** Accepted
- **Date:** 2026-07-29
- **Amends:** **ADR 0019** (the loop/marker undo toast now defers the delete instead of rebuilding a
  snapshot), **ADR 0023** (the loop's identity colour, until now drawn only on the waveform, minimap
  and transport strip, is now carried by the loop **row**) and **ADR 0028** (the row hold opens the
  edit sheet — unchanged when browsing, re-pointed at the selection while selecting). Extends
  **ADR 0034/0036/0039** (loop type · focus · tags) with a bulk editor and **ADR 0119** (favourites)
  with a bulk star. Applies the deferred-delete pattern Slice 3 settled on for the practice
  libraries to the waveform's own lists.
- **Number note:** 0120 is still reserved for the analytics/privacy ADR (`docs/backlog.md` Slice 8).

## Context

Slice 6 of the device-testing plan. On the practice screen the loops and markers panels are
strictly one-at-a-time: to delete four markers you hold each row, wait for its sheet, tap Delete,
dismiss, repeat — four times, with a four-second undo window opening and closing between each. The
same is true of the practice categories: a player who has just worked out that three of their loops
are all "chorus, needs-work, sharpening" has to set that six times over.

The device notes asked for a specific shape: **hold the panel header to enter a selection mode**,
where the play button becomes an empty circle, tapping a row selects it with standard Apple
selection UI and a haptic, and the per-row Automator and edit controls hide so they can't be caught
by accident. The play buttons take the loop's identity colour. The chevron's slot becomes an edit
button for the loop practice categories.

That last point left an open question the triage explicitly deferred to this ADR: **if the chevron's
position becomes a categories button, where does collapse go?**

Two further things had to be settled before building, since the note describes the *gesture* and not
the *consequences*: what a selection can actually do, and whether the identity colour appears only
while selecting or all the time.

## Decision

### 1. Selection mode is a mode-scoped swap of the panel header, so collapse never moves

Holding a panel header (0.4 s, with a haptic) replaces that header — and only while the mode is
live — with a selection bar: a select-all circle, the count, the bulk actions, and **Done**. The
chevron's slot is reassigned *inside that bar*. Browse mode is byte-for-byte what it was: the
chevron sits where it always sat and still collapses the panel.

**The bar is pinned above the scrolling list, not carried inside the panel** (device pass,
2026-07-29). Built into the panel header it scrolled away with it, so selecting a row near the
bottom of a long list meant scrolling back up to reach Delete — the bar has to be where it was when
the mode opened. Pinning it also means the selecting panel shows no header of its own; the pinned
bar names the list, so nothing is lost. Entering the mode **expands** the panel, since the chevron
that would have opened it has just stood down.

Rejected: making the categories button permanent and moving the chevron to a leading position, or
dropping the chevron and leaving collapse as an undocumented "tap the header row". Both spend a
permanently visible affordance — the open/closed indicator, or the chevron's familiar position — to
buy a control that is used rarely, and both change the panel's browse grammar for every user in
order to serve the selecting one. The mode-scoped swap makes the whole slice additive: nothing a
player already knows moves.

Only **one panel selects at a time**; beginning a selection in one ends the other. Two live
selection bars would put two Delete buttons on screen with no way to tell which list they belonged
to, and no bulk action spans both kinds.

The way *in* is the header hold, not a row hold: a row's hold already opens its edit sheet (ADR
0028) and that is the gesture people use to rename a loop. So the mode opens with **nothing**
selected, and the select-all control is the row circle one level up — "the circle for all of them" —
which is why there is no separate "Select All" / "Deselect All" text button. The circle's own
filled/empty state says which way a tap will go.

### 2. A selection can delete, favourite, and set practice categories — not colour

- **Delete** — the whole selection under a **single** undo toast. One action, one undo.
- **Favourite** (ADR 0119) — adds the star unless *every* selected loop already has it, in which
  case it removes it. A mixed selection therefore never silently unstars anything.
- **Practice categories** — type · focus · tags (ADR 0036/0034), in the chevron's old slot.

**Colour was considered and rejected.** The identity colour is *identity*: ADR 0023 derives it from
start-order so each loop reads as its own hue wherever it is drawn. A bulk colour is the one edit
that makes rows less distinguishable rather than more, and it collides head-on with decision 3.

Markers get **delete only**. A marker is a label and a time; there is nothing else to set across
several at once.

The categories sheet is a **partial** editor and every control reflects that. Each field opens on
what the selection already agrees on, shows **Multiple** when it does not, and stays *unchanged*
until touched — so applying writes only what was actually set. This is why `LoopBulkEdit` carries a
three-state `FieldEdit` rather than optionals: `focus` is *already* `Int?` on the model, where `nil`
means "never triaged" (ADR 0039) — a real value — so "leave it alone" needs a third state above
"some value" and "nil". Tags **add and remove**; they never replace. A selection's loops usually
carry their own descriptive tags, and a field that overwrote them would destroy work silently.
Removal only offers tags that **every** selected loop has, so "Remove" can't appear to do nothing.

### 3. The loop row carries its identity colour all the time — hue is identity, saturation is state

The row's play glyph is drawn in the loop's ADR 0023 colour permanently, **muted (55%) unless that
loop is the armed one**, and it becomes the selection circle in that same hue while selecting,
filling when chosen. A song's loops finally read as the same set of hues in the list as on the
waveform and the minimap above them.

The obvious objection is that green already means "armed" on this row, and a coloured glyph competes
with it. Muting resolves it: **hue carries identity, saturation carries state**, and they no longer
contest the same channel. The consequence is that **the green leading bar stays green** — it becomes
the sole "this is the one playing" marker, and tinting it to the loop's hue as well would leave
nothing saying which loop is live.

Rejected: showing the colour only in selection mode. It would have been safer, but it wastes the
information on the 99% of the time the list is being browsed, which is exactly when "which of these
five is the one I coloured red on the waveform?" is asked.

### 4. Deletes on this screen are now **deferred**, not delete-then-restore

ADR 0019's toast snapshotted a loop's scalars and rebuilt it on Undo. That worked for a loop's
*numbers* and quietly lost everything hanging off it: `Loop` cascade-owns its journal entries (ADR
0038) and its recorded takes (ADR 0069), and nullifies the routine blocks that reference it (ADR
0066). An undone delete came back with an empty journal, and bulk delete would have multiplied that
loss by the size of the selection.

So the delete now **hides the row and destroys the object only when the undo window closes** — on
expiry, on a second delete superseding it, or on leaving the screen. This is the trade Slice 3
settled on for the practice libraries, for the same reason: nothing can be lost by a missed commit,
and the worst case is a delete that didn't happen.

The Slice 3 lesson that every list must filter its own pending rows applies here with one important
simplification: on this screen there is exactly **one** reader. `WaveformPracticeModel.loops` and
`.markers` are what the panels, the waveform lanes and the minimap all read, so filtering the
pending `uid`s there makes a pending delete disappear from every surface at once.

Selections are keyed by `uid`, never `persistentModelID`: a freshly punched loop's persistent id
flips on its first autosave (ADR 0090), which would silently drop it out of a selection made seconds
earlier.

## Consequences

- Selection state is **session-only**, wiped on exit with the other transient practice knobs (ADR
  0029).
- The bulk-categories sheet is presented by a `Bool` and reads `selectedLoops` on demand, not by
  `item:` binding to a model — the ADR 0090 self-dismissal trap.
- Single-row delete now goes through the same deferred path, so its undo *gains* the journal, takes
  and routine links it used to drop. That is a straight improvement to existing behaviour, but it is
  a behaviour change: a loop deleted and undone is now the same object, not a rebuilt copy.
- A loop hidden by a pending delete is still present in *other* screens' queries (the Loops library
  reads every song's loops) until the window closes. You cannot be on two screens at once, and the
  object genuinely is not deleted yet, so the list is honest rather than stale.
- The selection rules (`PanelSelection`) and the partial edit (`LoopBulkEdit` / `LoopSelectionSummary`)
  are pure and unit-tested; the wiring between them and SwiftData is not, and is what device testing
  has to cover.
- The panel header is **not a `Button`**. A button fires its action on the release of a *long* press
  as well, so holding an already-open panel entered the mode **and collapsed it** (device pass,
  2026-07-29). It's a plain shape with separate tap and long-press gestures — the loop row's idiom,
  and the same trap Slice 5 hit on the metronome.
- The loop edit sheet gains a **Favourite** toggle. Giving the selection a bulk star left the single
  loop you already have open as the one place the pin couldn't be set; `LoopEditSnapshot` carries it
  so save-undo covers it too.
- **Device-verified in both appearances (2026-07-29), including the risk this ADR flagged:** the
  muted glyph at 55% reads clearly in **light** appearance — where the loop palette had only ever
  been tuned for waveform lanes on near-black — and the armed loop is unambiguous against the muted
  ones. The hue-is-identity / saturation-is-state split holds; no palette change is owed.
