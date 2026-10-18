# ADR 0258 — Detail sheets share five categories

- **Status:** Accepted — design signed off with Tomisin on 2026-10-18 (the canvas *Practice hub
  revamp*, rows *Song details*, *Edit loop* and *Exercise ⓘ*, and the board *Tap a routine: detail*
  from 2026-10-17). Built on `pocket-369-detail-sheets`, one commit per sheet: song details first.
- **Date:** 2026-10-18
- **Amends:** ADR 0152 §1–§2 — the **Audio** section leaves the sheet for *Song details › Audio
  file*, a screen one tap down. It is still the per-song inspector's door, now a hold and a tap from
  where a wrong track is heard, and its rows and words are unchanged. ADR 0236 D3 and D4 — *Export
  audio file only…* and *Send this song…* move with it. ADR 0250 D9 — the **Mastery** and **Slowest
  loop** rows move to *Song details › Progress*; the sheet's header keeps the dots, what they are made
  of and the slowest speed side by side, so D8 holds on the sheet too.
- **Relates to:** 0162 (the Settings hub, whose D3 row is the row used here) · 0038 (the notes, still
  edited in place) · 0232 (Map the song, still on the sheet) · 0172 (a linked drill is a route, still
  one tap) · 0167 (where you learned it) · 0039 (unrated is not zero) · 0220 D4 (the backing-track
  hint, unchanged) · 0082 and 0135 (Practice now and Improvise, still in the loop sheet's Practise
  section, which was *Practice*) · 0201 (*How it got here*, still under the range it explains) ·
  0216 D6 (Works on, still beside Tags) · 0165 (the manual quotes the app)
- **Schema:** none.

## Context

Song details, Edit loop and the exercise ⓘ sheet were flat scrolls of nine to twelve sections. Each
section was added by the ADR that needed it, in the order the ADRs landed, so the sheets read as a
history of the app rather than as a description of the thing you opened. Song details ran to about
two and a half screens and Edit loop to nearly three; the four ways to play a loop sat in the middle
of its Practice fields. ADR 0162 met the same problem in Settings and answered it with a hub of rows
that each say what is behind them.

## Decision

### D1 — five categories, in one order

**About · Practise · Progress · References · Audio file.** A sheet uses the ones it has and keeps
their order; none is renamed for one sheet. *About* is what the thing is, including the words you
wrote about it. *Practise* is the ways to play it. *Progress* is how it is going. *References* is
where you learned it (0167). *Audio file* is the song's file.

### D2 — glance on the sheet, open the rest

What you glance at stays on the sheet. Everything else sits behind a row with an icon, a title and,
where one fact dominates, that fact (0162 D3) — so the common visit ends without opening anything.
A row pushes a screen inside the sheet's own `NavigationStack`. On a sheet that edits a draft (Edit
loop: Cancel discards, Done keeps), the pushed screens edit the same draft.

### D3 — a pushed screen owns its presentations

Every presentation a pushed screen raises — the file importer, a confirmation dialog, the reference
editor, a picker, the send sheet — hangs off that screen's own `Form`, never off a row or a section
inside it. A presentation raised from inside a form in a sheet fights the presentation that owns the
screen, and loses (`ReferencesSection.editing` records the time it dismissed the sheet instead).

### D4 — what goes where

- **Song details.** On the sheet: the header (title, artist, album · year, then *F# Minor · 83 BPM ·
  3:24*, then the mastery dots with *3 of 4 loops rated · slowest 70%*, which is absent until the
  song has a loop); **About**, the notes (headed *Notes* until now); **Practise**: Map the song, the
  linked drills, Link exercises, Build a routine (the *Exercises for this song* header goes). Behind
  rows: **Progress** (*4 loops*), **References** (*1 link*), **Audio file** (the File row's words, so
  *Missing* shows on the sheet) and **Collections** (their names, and only when there are some). The
  Mastery row's ⓘ becomes the footer on Progress, which has room to say it outright.
- **Edit loop.** **About**: name, Favourite, Type, and a **Range** row (*0:42–0:58*) with Adjust range
  and *How it got here* behind it. **Practise**: Practice now, Train your ear, Watch it on the neck,
  Improvise, and the Backing track switch beside Improvise, whose shelf it puts the loop on.
  **Progress**: Mastery, Command tempo, Focus, and the Journal row. Behind rows: **References**,
  **Works on & tags** (together, because a tag can add a skill) and **Colour**. Delete loop stays
  last. The backing-track hint keeps scrolling to its switch (0220 D4): at half height it is still
  below the fold, and Tomisin chose to leave it there rather than put Practise above About.
- **Exercise ⓘ.** **About**: the description, still edited in place (a freeform drill keeps its
  Instructions and click there instead). Behind rows: **Progress** (the dots), **Songs**,
  **References**, **Folders** and **Feel & skills** (Feel, Works on and Template, each with its
  footer). Rating a drill from here becomes two taps; Tomisin accepted that, since rating is the Done
  screen's job.
- **Routine detail, headers only.** *Description* → **About**, *Blocks* → **Practise**, the unheaded
  length and history → **Progress**, *Where you learned it* → **References**; Reminder unchanged.
  Nothing moves behind a row: the blocks are the screen, and its Edit / Cancel / Save sandbox would
  have to reach into every pushed screen.

## Consequences

- Song details goes from about two and a half screens to about one and a quarter, and the exercise ⓘ
  sheet fits on one (estimated from the canvas layout, not measured on a phone).
- Replace, Send and Export are a tap further away, and so is rating a drill from ⓘ.
- `SettingsHubRow` becomes `HubRow` in `Pocket/UI`, shared by Settings and the sheets.
- The manual's reference lines for these sheets follow the app (C9), and their figures go stale; the
  reshoot list records them rather than reshooting per branch.

## Alternatives considered

- **Collapsible sections.** A collapsed section still shows its header, so twelve sections are still
  twelve rows of headers, and the app already keeps `DisclosureGroup` out of lists.
- **Practise above About on Edit loop**, so the half-height sheet shows the Backing track switch
  without the hint scrolling to it. Rejected: it breaks the shared order for one sheet.
- **A Collections row that shows the names and opens nothing.** Considered, since the names are
  read-only here; the row opens a plain list, as drawn and signed off, which a long list needs.
