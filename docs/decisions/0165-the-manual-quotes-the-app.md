# ADR 0165 — the manual quotes the app

- **Status:** **Accepted** — the whole manual is written and on `main`: 19 pages, ~24,000 words,
  96 shot markers. Every check C1–C12 is live and passing; the coverage audit ran at
  the end of the reference wing and found nothing unticked (see
  [docs/manual/README.md](../manual/README.md)). What remains is Phase 5, the images — tracked by
  **C13**, which is pending by design until the shoot finishes (16 of 94 drivable shots captured).
  <br>Drafted 2026-08-13, accepted 2026-08-14. `CHANGELOG.md` still gets no entry until the manual
  **ports** to the site, which is the trigger set in Consequences and is unchanged by this.
- **Date:** 2026-08-13
- **Extends:** ADR 0145 (help is something you look up). Its D5 (*quote, don't restate*) and D6
  (*no numbers*) were written for one compiled catalog; this ADR lifts both out of the FAQ and
  makes them repo-wide rules with a check behind them.
- **Constrained by:** ADR 0070 (never grades — and neither does its manual) · ADR 0144 (one app,
  one price: what is free is what the manual may promise) · ADR 0001 (local-first audio: no
  Apple-Music-as-source claim can appear in it)
- **Relates to:** ADR 0133 (docs-only CI, and the unmergeable-PR trap this must avoid) ·
  ADR 0162 (the nine Settings destinations the reference wing walks) · ADR 0163 (the nine
  long-press sites with no on-screen hint) · ADR 0149 (guidance arrives with the song — parked)

## Context

Red Moon has no user manual. What it has is [docs/beta/user-guide.md](../beta/user-guide.md):
2,300 words written for four closed-beta testers, in a first-person developer voice, and
*deliberately* partial. It is a tutorial — ground rules, prerequisites, a three-step first session
ending on "That's it. That's the app.", a hold-gesture cheatsheet, and eight one-line summaries
under "The rest of it". It never mentions Pro, pricing, the trial, the tuner, the chord hub, the
glossary, recording takes, Progress detail, the Song library, or the missing-file recovery flow.

Meanwhile the app is one `NavigationStack` with no tabs, nine Settings destinations, fourteen
exercise templates, a waveform screen with eight sheets, three loop modes, and **nine
`onLongPressGesture` sites with no on-screen hint** — ADR 0163 says so in as many words, and the
count is nine today, verified. That is a lot of surface a player can only find by accident.

### The real problem is drift, not word count

Once a manual exists there are five sources of user-facing truth:

| Source | Size |
|---|---|
| `FAQEntry.all` — [Pocket/Core/Help/FAQEntry.swift](../../Pocket/Core/Help/FAQEntry.swift) | 18 compiled answers |
| `PracticeFieldInfo` — [Pocket/UI/FieldInfoLabel.swift](../../Pocket/UI/FieldInfoLabel.swift) | 6 canonical definitions |
| `SettingsInfo` — [Pocket/Features/Settings/SettingsInfo.swift](../../Pocket/Features/Settings/SettingsInfo.swift) | 14 per-setting explanations |
| `GlossaryTerm` — [Pocket/Core/Theory/GlossaryTerm.swift](../../Pocket/Core/Theory/GlossaryTerm.swift) | 53 theory terms |
| the marketing site | a separate repo that auto-deploys to production with no staging gate |

ADR 0145 already solved this once, for one of them, with a rule — *quote the app's copy, don't
restate it* — pinned by `FAQEntryTests`. The manual is where that rule either generalises or
quietly dies.

### Why there is room for a manual at all

ADR 0145 D4 keeps FAQ answers **descriptive, never coaching**. That is the gap: nothing in the app
tells you *how to do a thing, step by step*. Procedure is unclaimed territory, and it is the only
territory the manual claims.

## Decision

Red Moon gets a public, task-shaped user manual for v1.2+, whose canonical copy lives in this repo
under `docs/manual/`, reviewed alongside the code it describes. **Every fact in it has exactly one
owner.** Where the app already says something, the manual quotes it verbatim or cites it by name;
it never restates it. A script enforces the half a script can enforce, and it runs on docs-only
pushes, where the test suite does not.

### D1 — canonical in this repo; the site is a rendering target, not an author

The markdown here is the source. The `.co.uk` port renders it at `/redmoon/manual/<slug>`,
mirroring the existing `/redmoon/beta/<slug>`. That is already the beta guide's rule, and it is
what keeps a repo with no staging gate from becoming the fifth writer.

### D2 — Diátaxis split: a goal-shaped spine plus a per-screen reference, one file → one route

**Spine** (goal-shaped): `README.md` · `getting-started` · `songs` · `looping` · `exercises` ·
`routines` · `sessions` · `journal-and-practice-log` · `metronome` · `toolkit` · `subscription` ·
`privacy` · `gestures` · `terms` · `shots` — plus **reference/**: `home-and-library` ·
`song-player` · `practice` · `tools-and-journal` · `settings`. Roughly 20 files, ~13,000 words.

Slug names, no numeric prefixes: ordering lives only in the index's nav table, because a filename
prefix *and* an index is two orderings that will drift. `README.md` rather than `index.md` so
GitHub renders it on folder browse.

### D3 — the manual owns procedure, and nothing else

| Fact class | Owner | Everyone else may… |
|---|---|---|
| Mastery, command tempo, focus, loop type, song mastery | `PracticeFieldInfo` | quote verbatim |
| Per-setting explanations | `SettingsInfo` | quote verbatim |
| Theory vocabulary | `GlossaryTerm` | name the term and point at Toolkit ▸ Glossary. **The manual defines no theory term.** |
| The recurring questions | `FAQEntry.all` | cite the question verbatim, **never reproduce the answer** |
| The shipped 8-row gesture cheatsheet | `LoopControlsInfo` | `gestures.md` is a superset; it may not contradict it |
| **Step-by-step procedure** | **the manual** | — |
| Price, trial length | StoreKit | **nobody hardcodes** (0145 D6, extended) |
| Privacy commitments | [docs/privacy-policy.md](../privacy-policy.md) | summarise and link; never add a commitment the policy doesn't make |

### D4 — quote byte-for-byte

Where the manual carries an app definition it carries the exact string, not a tidied version of it.
`terms.md` reproduces all six `PracticeFieldInfo` strings; `reference/settings.md` reproduces every
`SettingsInfo` string it claims to quote. Editing the copy in Swift is fine and propagates through
the next check run; paraphrasing it in markdown is what fails.

### D5 — cite FAQ questions; never reproduce an answer

An FAQ answer is version-locked to the build that shipped it. A manual page outlives that build.
So a manual page may say *"See Help & FAQs: 'Does slowing a song down change its pitch?'"* and stop
there. This is checked negatively as well as positively: no long sentence and no 12-word shingle
from any `FAQEntry.answer` may appear in `docs/manual/**`. That is what turns "cite, don't copy"
from an aspiration into a build step.

### D6 — no price and no trial length anywhere in `docs/manual/`

0145 D6's regex, reused, with **no exemptions**. This copy gets ported to a public page that
outlives the build it was written against, so a stale number is worse here than in a compiled FAQ,
which is at least read next to the real offer.

### D7 — text-only in this repo; images live in the port, described by markers

Binaries get one home, and it is not this one — the beta guide's rule, inherited. What lives here
is the marker grammar:

```
<!-- shot: song-player/speed-bar | role: band
     | alt: The speed bar at 0.85×, click on, 104 BPM showing
     | crop: 0,412,1320,238
     | call: 1@0.08,0.5 2@0.46,0.5 3@0.88,0.5
     | state: seeded "Red Moon", speed 0.85×, click on -->
```

**An image is sized by what's inside it, not by what kind of thing it is** — a single standard
width gets both extremes wrong at once. Six roles, chosen once: `glyph` (one control, inline in the
sentence) · `detail` (a small cluster, floated) · `panel` (a vertical region, floated) · `band` (a
horizontal stripe, full column) · `screen` (whole device) · `strip` (2–3 states side by side). A
per-image width override is allowed but **requires a `why:`**, so overrides stay rare and argued.

Three consequences of that grammar are load-bearing:

- `crop` is a rect in **device pixels against the master**, so every image is a derived crop and a
  reshoot reproduces it exactly. One master per screen per appearance; nothing is shot twice.
- `call` coordinates are **normalised 0–1 against the crop**, and callouts are rendered as **SVG at
  port time**, never burnt into the raster — so they follow the page theme, and rewording one never
  costs a reshoot. **Callouts are opt-in per figure and are not a default for the reference wing**:
  they earn their place on a figure that is genuinely a map of parts a reader must be able to name.
  A figure needing more than about six is the wrong crop.
- `glyph` images are **decorative** — empty `alt`, with the control's name in bold beside them. The
  sentence must survive images-off and VoiceOver on its own. Empty `alt` is legal for no other role.

`glyph`, `detail` and `panel` ship **theme-paired** through `<picture>` + `prefers-color-scheme`,
because they sit against the page background where a dark crop in a light page reads as a sticker.
`band`, `screen` and `strip` stay dark inside a bordered frame, where the frame makes the theme
deliberate. The doubling lands on the launch, not the labour: `-appearance light` and
`-appearance dark` are two passes over the same walk, one crop list.

### D8 — `check-manual.py` runs in `pre-push.sh` and unconditionally inside `lint-build-test`

Stdlib Python 3, no dependencies (precedent: `scripts/derive-brand-svgs.py`). It parses the Swift
catalogs and asserts against `docs/manual/**`: the nine `SettingsHubRow` titles and the four
`ToolkitSectionRow` titles are named where they should be; quoted strings match byte-for-byte;
no FAQ answer text, price or trial length appears; `streak` and `this year` appear nowhere; and
comment tripwires (`<!-- long-press-sites: 9 -->`, `<!-- faq-entries: 18 -->`,
`<!-- loop-controls-rows: 8 -->`) fail when the count they name moves. **Name checks where names
exist, count tripwires where they don't.**

**C13 extends the same rule to the images.** The prose has twelve checks on it and the markers had
none past their own grammar, so the two halves of a figure — the marker that promises it and the
`capture()` in `PocketUITests/Manual*.swift` that takes it — were held together by hand. C13 parses
both sides and requires them to name the same slugs. It is the one check with a **third verdict**:
a marker nobody has shot yet is `pending`, never `fail`, because eighty of ninety-six are unshot
while Phase 5 runs and a check that red-lights every push until a ten-minute shoot completes is a
check that gets commented out inside a week. What hard-fails is a *ghost* — a `capture()` naming a
slug no marker defines — because that is an image no page can ever show; a driven `device:` marker,
which is the simulator shooting a state it has already admitted it renders dishonestly; and a parse
finding **zero** captures, which would otherwise let the check pass by reading nothing.
Driven-state is deliberately kept **out of `shots.md`**: C12 diffs that file, so recording it there
would make editing a Swift test fail a docs check, coupling the two halves that
`scripts/docs-only.sh` exists to keep apart.

Two callers, one implementation — the `docs-only.sh` pattern from ADR 0133:

1. `scripts/pre-push.sh`, **before** the tier logic, so it runs even under `POCKET_PREPUSH=skip`
   — docs is exactly what it checks.
2. `.github/workflows/ci.yml` as a step inside the **existing `lint-build-test` job with no `if:`
   condition**, placed before the `docs_only != 'true'` gates.

⚠ **Not a new job, and not in `scope`.** `scope` is a `needs:` dependency of `lint-build-test`; a
failing `scope` skips the required check entirely, and a required check that never reports is an
unmergeable PR — ADR 0133's exact trap in a new costume. `lint-build-test` always runs and always
reports (ubuntu when docs-only, macos-15 otherwise), and `python3` is on both.

**A script, not an XCTest,** despite `FAQEntryTests` being the obvious precedent: on a docs-only
change every macOS step is gated off, so a Swift test would never run on the PR that edits the
manual. The script strictly dominates.

### D9 — video maps 1:1 onto how-to pages and introduces no fact the page lacks

One video per spine file, embedded at the top of the ported route, marked in the source with
`<!-- video: looping -->`. **The page's H2 list is the shooting script** — that is what 1:1 buys,
and it is why the spine is goal-titled rather than screen-titled. A video that says something the
page doesn't is a sixth source of truth with no check behind it.

## Consequences

- **The beta guide freezes where it stands, and is trimmed at round close.** It is live and
  instrumented behind a name/email gate with an "It didn't do that" button per step; editing the
  canonical copy mid-round changes the artefact being measured. **The trigger is round close, not a
  date, and it is recorded here rather than in someone's head:** delete §§3–7, replace each with a
  link into the manual, leaving ~900 words of purely tester-facing material. About 60% of the guide
  (ground rules, TestFlight, the week-by-week asks, the starter track) has no home in a public
  manual; the other 40% duplicates it from day one.
- **A new `AGENTS.md` docs-table row**: `docs/manual/` → *"A screen gains or loses a control, a
  control is renamed, a navigation path changes, or what's free vs Pro moves."*
- **Three things stay human, on purpose.** *Truth* — C1 proves the manual mentions all nine Settings
  destinations; only someone with the build open proves it describes them correctly, which is the
  same concession `FAQEntryTests` already makes. *Voice* — product voice, second person, British
  spelling, no first-person "I". *Parked features* — no grep distinguishes "there is no sync" from
  "sync" without pretending to be a parser, and a check that false-fails gets disabled within a
  month, so the parked list lives in `docs/manual/README.md` as a review list. Only `streak` and
  `this year` are automated, because they have no legitimate use.
- **`CHANGELOG.md` gets an entry when the first slice ports**, not now. A draft ADR is not a
  user-visible change.
- **Markers are authored with the prose**, in the writing phases, never retrofitted at shoot time.
  Recording `role`, `crop` and `state` while the page is fresh is what turns the shoot into a
  mechanical batch instead of archaeology — and it is what lets a sentence be composed *around* a
  wrapped image rather than having one dropped beside it afterwards.
- **Scale, honestly:** roughly 60–70 masters yielding 120–150 derived crops for the full manual.
  It ships in slices, and Slice A (`getting-started` · `songs` · `looping` · `gestures` · `terms`)
  is about 27 states. `gestures.md` alone retires the biggest known support cost.
- **The manual is where "we never built that" becomes visible.** A page that cannot be written
  without an apology is a design finding, and the coverage audit at the end of the reference wing
  is the manual's definition of done.
- **The shoot is where "we never seeded that" becomes visible, and it fails silently.** A marker
  naming a populated state (`"two goals ranked"`, `"several routines saved"`) is a claim about the
  *store*, and nothing in D8's checks can test it — C13 only asks whether a `capture()` exists.
  Where the seed is short, the figure comes back a clean photograph of an empty screen, filed under
  a page describing a full one, with a green verdict over it. Found twice in two ADRs: 0173 grew
  `PracticeHistorySeed` for the routine history section before shooting it, and ADR 0171's
  long-term goal list had shipped a screen and a marker with nothing writing a `LongTermGoal` at
  all. **A feature that ships a screen ships its seed**, in `PracticeHistorySeed+Authored`.
- **Three markers need a device the shoot cannot produce, and that is a gap in the harness rather
  than in the pages.** `songs/empty-library`, `reference/loops-library` and
  `getting-started/first-run` each specify a fresh install; `shoot-manual.sh` erases once and then
  seeds six songs with loops attached, so on that device the loops library is never empty and the
  first-run questions never appear. They need a **second unseeded pass** in the same script, which
  does not exist yet. Shooting them from the seeded device instead would satisfy C13 while
  photographing states the pages do not describe — the failure this whole phase is written against,
  arriving through the progress metric.

## Alternatives rejected

- **One 13,000-word file.** Unnavigable, and it forecloses the 1:1 video mapping (D9).
- **Growing `FAQEntry.all` to cover it.** 0145 D4 keeps answers descriptive rather than coaching,
  and the catalog is version-locked to the build. Procedure needs the opposite of both.
- **A manual inside the app.** Ships at Apple's cadence, can't carry screenshots of itself, and
  reopens the coach-marks question ADR 0163 closed.
- **Owning it in the site repo.** Reviewed away from the code it describes, and auto-deploys
  straight to production with no staging gate. That is the drift problem, institutionalised.
- **Screenshots in this repo.** Binaries get one home; the port already has one.
- **One standard image width.** Gets tall and wide images wrong in opposite directions — a device
  shot at column width shoves the prose apart, a crop of the speed bar looks lost at the same width
  — and it blocks the wrapped-inline reading the whole layout is built for.
- **Burning callouts into the raster.** Every rewording costs a reshoot, and the colours cannot
  follow the page theme.
- **Generating the reference wing from source.** SwiftUI labels are not an inventory, and the
  output reads as a symbol dump.
- **An XCTest instead of a script.** It never runs on the PR that edits the manual (D8).
- **A new CI job for the check.** ADR 0133's unmergeable-PR trap (D8).
- **Naming the price or the trial length.** 0144 removed that bug class once already (D6).
