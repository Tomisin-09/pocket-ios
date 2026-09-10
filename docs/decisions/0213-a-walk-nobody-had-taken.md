# ADR 0213 — a walk nobody had taken

- **Status:** Accepted
- **Date:** 2026-09-10 (`pocket-314-accessibility-walk`)
- **Relates to:** ADR 0208 (D5, the identifier that exists so a label can stay the numbers), ADR
  0192 (why the skip buttons need no custom action), ADR 0184 (a name answering in two registers),
  ADR 0030 (the labelled-glyph transport), ADR 0165 (the manual's shoot, whose harness this rides),
  ADR 0146 (the launch seams that make any of it drivable)
- **Schema:** none.

## Context

`docs/backlog.md` has carried one line since 2026-08-23: *accessibility has never been walked*. It
was right. 166 of 613 files carry an `.accessibility*` modifier, so the coverage is deliberate
rather than accidental — the song player has labels, values, traits and custom actions, and ADR
0184 went as far as giving a string name two registers so VoiceOver could have the long one. What
did not exist was any evidence that anyone had ever **run** VoiceOver against the result, or seen
the app at an accessibility text size, or had any way to find a control that speaks its SF Symbol
name aloud other than by opening files and reading.

The design brief has asserted the standard since the beginning — *"legible contrast on dark,
Dynamic Type support, VoiceOver labels, and 'Reduce Motion' alternatives"* — and had no mechanism
behind it. An assertion with no mechanism is how the manual's figures drifted, how the analytics
vocabulary drifted three times, and how `attachmentFileName` arrived shaped wrong. It is the
repo's own recurring failure, and this is the same fix: give the rule something that can fail.

Two things made this cheap enough to do before a submission rather than after. The shoot already
drives sixty-odd states on a staged device, so the navigation exists and is maintained. And
`ManualShotCase.diagnosis(for:in:)` already walks the accessibility tree — it was simply doing it
on the failure path, for a different question, and throwing away the elements that matter most
here.

## Decisions

### D1 — every control that can be reached carries a label, and the absence is findable

Not "every view". A container has nothing to say and an unnamed one is not a defect. The rule is
about controls: a button, a switch, a slider, a text field. The mechanism is D2; the standard is
that an unnamed reachable control is a bug, not a style preference.

### D2 — the audit is an attachment on the shoot, not a walk of its own

`record(…)` already photographs each state and writes the assertions beside it. It now writes a
third artefact, `<slug>.ax`, holding the accessibility tree as JSON, and `scripts/ax-audit.py`
reads the filed set and reports.

The alternative was a test target that walks the app for accessibility. It was rejected because it
is a **second copy of the navigation** — sixty states' worth of taps that no figure depends on, so
nothing would notice when a sheet moved and the walk started auditing the screen before it. The
shoot's taps are load-bearing: when they break, a figure is wrong and someone sees it. Riding them
means the audit inherits that maintenance for free, and it means the audit covers exactly the
states the manual thought were worth documenting.

The cost of the choice, stated plainly: the audit can only see states the shoot drives. A screen
with no figure has no dump. That is a real gap and the honest place to close it is by giving the
screen a figure.

### D3 — it proves absence, and the device pass is not optional

XCUITest exposes no accessibility **traits**, so `elementType` is the only available proxy for "is
this a button", and it exposes nothing whatever about focus order, swipe order, or how a label
sounds when spoken. So the four rules are all shaped like *absence*: a control with no label, a
label that is an SF Symbol name, a target under 44pt, two controls with one name.

**A clean report therefore means "no absences", never "accessible"**, and the script says so in its
own output rather than leaving a reader to infer it. This is the same discipline as C9, which knows
a string exists in the source and not that it is on screen. VoiceOver on a real device remains a
step, and this ADR does not replace it with a green tick.

### D4 — the audit does not gate CI

`PocketAll` cannot reach `PocketShootUITests` (C14), and that boundary is not being reopened for
this: the shoot needs a device that has been erased, seeded, unlocked and darkened, and CI has
none. Two of the rules also carry judgement — 44pt has legitimate exceptions, and two buttons
sharing a name is sometimes correct — and a rule with judgement in it earns a reader rather than a
red build.

### D5 — a run at an accessibility text size is partial by definition

`POCKET_SHOOT_CONTENT_SIZE` stages `simctl ui … content_size` beside the existing dark-appearance
call, and **forces `PARTIAL=1` whatever it drove**. A complete AX-size run would otherwise satisfy
the existing "only a complete run may write `filed/`" rule and file ninety photographs of oversized
text into the set that gets shipped. That is the same data loss the script already carries a guard
for — *"Seven passes ran; two images survived"* — arriving through the front door. `shots-ax/` is
its own gitignored directory for the same reason: a shared parent is one `POCKET_SHOT_OUT` typo
away from the thing being prevented.

### D6 — a row takes `minHeight`, not `height`

`PracticeRunStyle` set `.frame(height: 56)` on the shared practice-run row, which clips its own
text the moment the reader asks for larger type. `WaveformPanels+Markers` and `+Snags` already used
`minHeight` and are the pattern. The general rule: a fixed height on anything containing text is a
Dynamic Type bug unless something else guarantees the text cannot grow.

Not extended to a sweep of all 34 fixed heights and 39 `lineLimit(1)` sites in this pass. What gets
fixed is what the sweep shows clipping — the rest is logged. Restyling a control nobody has seen
break is how a pass like this turns into a redesign.

### D7 — the flag reaches the test process through `TEST_RUNNER_`, and the script adds it

The UI tests run in a separate runner app; only variables carrying that prefix are forwarded to it.
A plain `POCKET_SHOOT_AX=1` reaches the shell and stops there, and the failure mode is a **silent
no-op**: a full green shoot and an audit of nothing at all. `shoot-manual.sh` therefore adds the
prefix itself rather than documenting it, and `ax-audit.py` names this specific cause when it finds
no dumps.

### D8 — identifiers are not labels, and this pass does not "fix" them

Restated because an audit is exactly when it would be got wrong. ADR 0208 D5 put
`home.practiceLogDoor` on the stat strip *so that the VoiceOver label could stay the three
numbers*. An identifier is a test seam; a label is what a person hears. Ten identifiers in this app
are the former, and none of them is a missing label.

Related: `.accessibilityAddTraits(.isButton)` **retypes** an element, so a `staticText` that becomes
a `button` breaks queries written against the old type. Where a row needs an action, the answer is
`.accessibilityAction(named:)`, not a trait.

## Consequences

The backlog item closes. The design brief's checklist gains a mechanism behind the VoiceOver line,
and the two things that line cannot be reduced to — focus order and how a label sounds — are now
written down as requiring a person, rather than implied to be covered.

The audit is an occasional job, not a routine one: it is off by default so the manual's shoot does
not pay several hundred element queries per figure for it. That is a deliberate trade — it means an
accessibility regression is caught when someone runs the audit, not on the commit that causes it.
Closing that would mean either a CI-reachable walk (D2's rejected copy) or a slower shoot, and
neither is worth it while the audit is the thing establishing the baseline rather than defending
it.

Screens the shoot does not drive are not audited, and the honest fix for that is a figure.
