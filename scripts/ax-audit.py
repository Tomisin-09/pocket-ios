#!/usr/bin/env python3
"""Read the shoot's accessibility dumps and report what VoiceOver would meet (ADR 0213).

The shoot drives every screen the manual documents. With `POCKET_SHOOT_AX=1` it attaches the
accessibility tree beside each figure, and `file-shots.py` files those as `<slug>.ax`. This reads
them and applies four rules.

    POCKET_SHOOT_AX=1 POCKET_SHOT_OUT=shots-ax ./scripts/shoot-manual.sh
    ./scripts/ax-audit.py shots-ax/filed-partial

**What it can prove is absence, and only absence.** XCUITest exposes no accessibility traits, so
`elementType` stands in for "is this a button", and it exposes nothing whatever about VoiceOver's
focus order, its swipe order, or how a label sounds when spoken. A clean report here means no
control is *unnamed*; it does not mean the screen is usable, and it never replaces the device pass.
Said plainly because the failure mode of every checker in this repo is being read as more than it
is — `check-manual.py` C9 knows a string is in the source, not that it is on screen.

Reports; does not gate. The shoot is unreachable from `PocketAll` by design (`check-manual.py` C14),
so there is no CI run to fail — and a rule with judgement in it (A3's 44pt, A4's duplicates) earns
a reader, not a red build.
"""

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

# Apple's minimum comfortable target, from the HIG and from `docs/design-brief.md`'s own checklist.
MIN_TARGET = 44.0

# `slider.horizontal.below.rectangle`, `folder.badge.plus` — an SF Symbol name that reached a label.
# Anchored and dot-bearing on purpose: a real label has spaces or capitals, and the one-word labels
# this app does use ("Save", "Edit", "Bass") carry neither a dot nor a leading lowercase run.
SYMBOL_NAME = re.compile(r"^[a-z0-9]+(\.[a-z0-9]+)+$")

# The types a rule will speak about. An unnamed `.other` is a SwiftUI container and says nothing;
# an unnamed `.button` is a control nobody can hear.
CONTROL_TYPES = {"button", "image", "switch", "slider", "textField", "secureTextField", "link"}
NAMEABLE = CONTROL_TYPES - {"image"}

# Types that, when labelled, speak for everything drawn inside them.
SPEAKS_FOR_ITS_CONTENTS = {"button", "cell", "switch", "link", "menuItem"}


def contained(inner, outer):
    """Is `inner`'s frame inside `outer`'s, and smaller than it?"""
    i, o = inner.get("frame", {}), outer.get("frame", {})
    if not all(k in i and k in o for k in ("x", "y", "w", "h")):
        return False
    if i["w"] * i["h"] >= o["w"] * o["h"]:
        return False
    return (i["x"] >= o["x"] and i["y"] >= o["y"]
            and i["x"] + i["w"] <= o["x"] + o["w"]
            and i["y"] + i["h"] <= o["y"] + o["h"])


# What a labelled control is allowed to speak for: **decoration it draws, and nothing else.**
#
# A same-type exception was tried here — a `switch` inside a labelled `switch` is the same control
# exposed twice — and it had to go. It brought the layering bug straight back in a new costume: four
# of the six 32×32 nudge buttons sit, geometrically, inside Home's `JUMP BACK IN` card behind the
# sheet, which is also a button, so a same-type rule silenced them and left two. Two of six reads
# exactly like all of them. A live control is now reported however it is nested; the cost is that a
# second exposure of one control is occasionally listed twice, which is a reader's half-second.
SPOKEN_FOR_TYPES = {"image", "staticText"}


def spoken_for(elements):
    """The elements a labelled control already speaks for — the ones to say nothing about.

    **The noise this removes**: XCUITest's tree exposes the glyph *inside* a button as an element of
    its own, so Home's `Metronome` tile appears twice — once as a button labelled "Metronome", once
    as an image labelled `metronome.fill`. VoiceOver never stops on the second; it focuses the button
    and reads its label. Reporting it sends a reader to label a control that already has one.

    **And the finding it must not remove, which the first version did.** Containment here is geometry,
    not parentage — the dump is flat, and asking XCUITest for a parent is a query per element on a
    walk already several hundred long. Geometry and parentage disagree exactly where screens *layer*:
    the metronome is presented over Home, Home's cards are still in the tree and still in the window,
    and two of the automator's three unlabelled number fields happen to fall inside the rectangle of
    `JUMP BACK IN, …`. Purely geometric suppression therefore hid two real defects and reported the
    third — the worst possible outcome, because a report showing one of three reads as complete.

    So containment alone is not enough to silence something. The inner element must also be the kind
    of thing a control legitimately speaks for — **decoration**, and only that. A live control is
    reported however it is nested: a text field inside a card is still a text field nobody can hear.
    """
    speakers = [e for e in elements
                if e["type"] in SPEAKS_FOR_ITS_CONTENTS and (e.get("label") or "").strip()]
    return [e["type"] in SPOKEN_FOR_TYPES and any(contained(e, s) for s in speakers)
            for e in elements]


def load(directory):
    """Every `<slug>.ax` in `directory`, parsed, newest-slug-first for stable output."""
    dumps = []
    for path in sorted(directory.glob("*.ax")):
        try:
            dumps.append((path, json.loads(path.read_text(encoding="utf-8"))))
        except json.JSONDecodeError as error:
            print(f"  ⚠️  {path.name}: not JSON ({error}) — the dump was truncated or the "
                  f"attachment is not what this expects")
    return dumps


def described(element):
    """A control's name in a report: its label, else its identifier, else its position."""
    label = element.get("label") or ""
    if label:
        return f"'{label}'"
    identifier = element.get("identifier") or ""
    if identifier:
        return f"(no label, id '{identifier}')"
    frame = element.get("frame", {})
    return f"(no label, at {frame.get('x', 0):.0f},{frame.get('y', 0):.0f})"


def beside(element, elements, slack=40):
    """The nearest labelled text sharing this element's row, or None.

    **This is the adjudication half of A1, and it is not decoration.** `Toggle("Mark as met",
    isOn:)` — which is correct and needs no fix — renders in the tree as an unlabelled `switch`
    with its title as a separate `staticText`, and VoiceOver reads the pair as one. It is
    indistinguishable, in the tree alone, from a genuinely unnamed control. Printing what sits
    beside it turns a finding you would have to open Xcode to judge into one you can judge here.
    """
    row = element.get("frame", {}).get("y", 0)
    near = [e for e in elements
            if e["type"] == "staticText"
            and (e.get("label") or "").strip()
            and abs(e.get("frame", {}).get("y", 0) - row) <= slack]
    if not near:
        return None
    closest = min(near, key=lambda e: abs(e.get("frame", {}).get("y", 0) - row))
    return (closest.get("label") or "").strip()


def rule_a1(elements):
    """A control that can be reached and has nothing to say."""
    for element, covered in zip(elements, spoken_for(elements)):
        if covered or element["type"] not in NAMEABLE or not element.get("inWindow"):
            continue
        if not (element.get("label") or "").strip():
            neighbour = beside(element, elements)
            aside = f" — beside '{neighbour}'" if neighbour else ""
            yield f"{element['type']} with an empty label — {described(element)}{aside}"


def rule_a2(elements):
    """A label VoiceOver will read as an SF Symbol name."""
    for element, covered in zip(elements, spoken_for(elements)):
        if covered:
            continue
        label = (element.get("label") or "").strip()
        if label and SYMBOL_NAME.match(label):
            yield f"{element['type']} labelled '{label}' — that is a symbol name, read aloud as one"


def rule_a3(elements):
    """A target smaller than a fingertip, in **both** axes.

    Narrower than the HIG's rule, deliberately, and the first run is why. Read literally — either
    axis under 44 — it returned 77 findings across three screens, almost all of them decorative
    glyphs and system chrome: a 6×10 disclosure chevron, the `Red Moon` wordmark, a segmented
    control's segments, the navigation bar's Back button. A reader who scrolls past 70 non-defects
    does not reach the six that are real, so the rule that finds everything finds nothing.

    Both axes, and no images: what is left is a control small enough to miss in **both** directions,
    which is the shape of the defect — a 32×32 glyph button. A full-width 330×42 button is not hard
    to hit, and neither is a 218×31 slider. Toolbar and navigation-bar items still appear and are
    still worth a look, since the frame here is the glyph's and the system's own hit area is larger.
    """
    for element, covered in zip(elements, spoken_for(elements)):
        if covered or element["type"] not in NAMEABLE or not element.get("inWindow"):
            continue
        frame = element.get("frame", {})
        width, height = frame.get("w", 0), frame.get("h", 0)
        if 0 < width < MIN_TARGET and 0 < height < MIN_TARGET:
            yield (f"{element['type']} {described(element)} is {width:.0f}×{height:.0f}pt, "
                   f"under {MIN_TARGET:.0f} in both axes")


def rule_a4(elements):
    """Two controls on one screen that say the same thing."""
    seen = defaultdict(int)
    for element, covered in zip(elements, spoken_for(elements)):
        if covered or element["type"] != "button" or not element.get("inWindow"):
            continue
        label = (element.get("label") or "").strip()
        if label:
            seen[label] += 1
    for label, count in sorted(seen.items()):
        if count > 1:
            yield f"{count} buttons all labelled '{label}' — VoiceOver cannot tell them apart"


RULES = [
    ("A1", "a control with no label", rule_a1),
    ("A2", "a symbol name used as a label", rule_a2),
    ("A3", f"a target under {MIN_TARGET:.0f}pt in both axes", rule_a3),
    ("A4", "two controls with one name", rule_a4),
]


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    directory = Path(args[0]) if args else REPO / "shots-ax" / "filed-partial"
    if not directory.is_dir():
        sys.exit(f"no such directory: {directory}\n"
                 f"Run the shoot with POCKET_SHOOT_AX=1 first — see this file's header.")

    dumps = load(directory)
    if not dumps:
        sys.exit(f"no .ax dumps in {directory} — the shoot ran without POCKET_SHOOT_AX=1, or "
                 f"TEST_RUNNER_ was dropped from the variable and the flag never reached the "
                 f"test process (which fails as a clean run of nothing).")

    findings = defaultdict(list)
    truncated = []
    for path, dump in dumps:
        slug = dump.get("slug", path.stem)
        if dump.get("truncated"):
            truncated.append(slug)
        elements = dump.get("elements", [])
        for code, _, rule in RULES:
            for finding in rule(elements):
                findings[code].append((slug, finding))

    total = 0
    for code, title, _ in RULES:
        hits = findings[code]
        total += len(hits)
        mark = "✅" if not hits else "⚠️ "
        print(f"\n{mark} {code}  {title} — {len(hits)}")
        by_slug = defaultdict(list)
        for slug, finding in hits:
            by_slug[slug].append(finding)
        for slug in sorted(by_slug):
            print(f"    {slug}")
            for finding in sorted(set(by_slug[slug])):
                print(f"      · {finding}")

    screens = "screen" if len(dumps) == 1 else "screens"
    print(f"\n{len(dumps)} {screens} read, {total} findings.")
    if truncated:
        # Same reasoning as `diagnosis`'s cap: a partial scan presented as a full one is the defect.
        print(f"⚠️  {len(truncated)} screen(s) hit the element cap and are PARTIAL — a control "
              f"missing from this report may simply be past it: {', '.join(sorted(truncated))}")
    print("Absence only. Focus order, swipe order and how a label sounds are the device pass.")
    print()
    print("Adjudicate every finding against the source before fixing it. The first full-app run "
          "(2026-09-10) returned 120 findings and 5 were defects. The tree XCUITest exposes is not "
          "the set VoiceOver focuses, and it over-reports in three known ways:")
    print("  1. children of `.accessibilityElement(children: .combine)` appear separately, so a "
          "glyph inside an already-labelled row reads as an unlabelled image (A2);")
    print("  2. `Toggle(\"title\", isOn:)` splits into a staticText and an unlabelled switch, "
          "which is correct SwiftUI and needs no fix (A1) — hence the 'beside' note;")
    print("  3. a screen presented over another leaves the one behind in the tree, so its controls "
          "reappear as phantom duplicates (A4) and phantom small targets (A3).")
    print("None of the three can be told from a genuine defect by geometry alone — an earlier "
          "attempt to suppress them by containment hid two real findings. The report is deliberately "
          "noisy in preference to that.")


if __name__ == "__main__":
    main()
