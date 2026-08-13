#!/usr/bin/env python3
"""Hold `docs/manual/**` to ADR 0165 — the manual quotes the app.

The manual owns *procedure*. Everything else it says has an owner in the app's
compiled catalogs, and where the app already says something the manual quotes it
verbatim or cites it by name. That rule is the whole reason a manual can exist
alongside an in-app FAQ without the two drifting apart, and a rule nothing
enforces is a rule that survives about one release.

ADR 0145 pinned the same idea for `FAQEntry` with an XCTest. **This is a script
and not a test on purpose** (0165 D8): on a docs-only change `scripts/docs-only.sh`
routes CI to ubuntu and gates off every macOS step, so a Swift test would never
run on the very PR that edits the manual. Stdlib only, no dependencies, so it can
run on either runner — precedent: `scripts/derive-brand-svgs.py`.

    ./scripts/check-manual.py            # all checks
    ./scripts/check-manual.py --list     # what each check does, and its state

Checks implemented here (0165's Phase 0b set):

    C1  the 9 shipping Settings destinations are named in reference/settings.md
    C2  the 4 Toolkit sections are named in toolkit.md
    C6  no price and no trial length anywhere in the manual
    C8  count tripwires: a `<!-- key: N -->` comment fails when N stops matching
        the live count in the source

C3/C4/C5 (FAQ citation, no-copied-answers, byte-for-byte quoting) arrive with
Slice A, when there is prose for them to check.

**The rule of thumb, for whoever extends this:** name checks where names exist,
count tripwires where they don't. A check that can name the thing it is guarding
tells you what broke; a count can only tell you that something did — so counts
are the fallback, not the habit.

A check whose target page does not exist yet reports **pending** and does not
fail. That is what lets the machinery land before the prose (0165's Phase 0b)
instead of being retrofitted around pages that were written without a guard.
"""
import argparse
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANUAL = os.path.join(REPO, "docs", "manual")
SOURCE = os.path.join(REPO, "Pocket")

OK, FAIL, PENDING = "ok", "fail", "pending"


# --- reading the app --------------------------------------------------------

# Swift wraps long copy as `"one " +\n"two"`. Every catalog in this app does it
# somewhere, so the joiner is written once here and reused by every check rather
# than re-solved (differently, and wrongly) in each one.
_LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')


def swift_literal_at(text, index):
    """Join the `+`-concatenated string literal starting at `index`.

    Returns (value, end_offset), or (None, index) if no literal starts there.
    """
    match = _LITERAL.match(text, index)
    if not match:
        return None, index
    parts = [match.group(1)]
    end = match.end()
    while True:
        cont = re.match(r"\s*\+\s*", text[end:])
        if not cont:
            break
        nxt = _LITERAL.match(text, end + cont.end())
        if not nxt:
            break
        parts.append(nxt.group(1))
        end = nxt.end()
    return unescape("".join(parts)), end


def unescape(value):
    return (value.replace('\\"', '"').replace("\\n", "\n")
                 .replace("\\t", "\t").replace("\\\\", "\\"))


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def strip_debug(text):
    """Drop `#if DEBUG` regions.

    Load-bearing for C1: `SettingsView` has ten `SettingsHubRow`s and only nine
    of them ship. The tenth is the Developer row (ADR 0162 D8), which no player
    can reach — requiring the manual to name it would be requiring a lie.
    """
    out, depth = [], 0
    for line in text.splitlines(keepends=True):
        stripped = line.strip()
        if stripped.startswith("#if DEBUG"):
            depth += 1
            continue
        if depth and stripped.startswith("#endif"):
            depth -= 1
            continue
        if not depth:
            out.append(line)
    return "".join(out)


def labelled_arguments(text, call, label):
    """Every `label:` string argument of every `call(...)` in `text`.

    The label is matched with a non-word lookbehind because `subtitle:` ends in
    `title:` — an unanchored search of `ToolkitView` returns eight values where
    four are wanted, and half of them are the wrong half.
    """
    found = []
    pattern = re.compile(r"(?<![A-Za-z])" + re.escape(label) + r":\s*")
    for site in re.finditer(re.escape(call) + r"\(", text):
        window = text[site.end():site.end() + 600]
        hit = pattern.search(window)
        if not hit:
            continue
        value, _ = swift_literal_at(window, hit.end())
        if value is not None:
            found.append(value)
    return found


def source_files():
    for base, _dirs, files in os.walk(SOURCE):
        for name in sorted(files):
            if name.endswith(".swift"):
                yield os.path.join(base, name)


# --- reading the manual -----------------------------------------------------

def manual_pages():
    if not os.path.isdir(MANUAL):
        return []
    pages = []
    for base, _dirs, files in os.walk(MANUAL):
        for name in sorted(files):
            if name.endswith(".md"):
                pages.append(os.path.join(base, name))
    return sorted(pages)


def relative(path):
    return os.path.relpath(path, REPO)


def page(*parts):
    return os.path.join(MANUAL, *parts)


# --- the checks -------------------------------------------------------------

def names_appear_in(names, target, owner):
    """Assert every `name` appears somewhere in `target`. The C1/C2 shape."""
    if not os.path.exists(target):
        return PENDING, ["%s not written yet — %d names waiting from %s"
                         % (relative(target), len(names), owner)]
    if not names:
        return FAIL, ["found no names in %s — the parser has drifted from the "
                      "source it reads, which fails silently as a pass" % owner]
    body = read(target)
    missing = [name for name in names if name not in body]
    if missing:
        return FAIL, ["%s does not name: %s" % (relative(target), ", ".join(missing))]
    return OK, ["all %d named in %s" % (len(names), relative(target))]


def check_c1():
    """The nine shipping Settings destinations are named in reference/settings.md."""
    text = strip_debug(read(os.path.join(SOURCE, "Features/Settings/SettingsView.swift")))
    names = labelled_arguments(text, "SettingsHubRow", "title")
    return names_appear_in(names, page("reference", "settings.md"), "SettingsHubRow (ADR 0162)")


def check_c2():
    """The four Toolkit sections are named in toolkit.md."""
    text = strip_debug(read(os.path.join(SOURCE, "Features/Toolkit/ToolkitView.swift")))
    names = labelled_arguments(text, "ToolkitSectionRow", "title")
    return names_appear_in(names, page("toolkit.md"), "ToolkitSectionRow (ADR 0096)")


# The same pattern `FAQEntryTests` uses, deliberately verbatim (0165 D6). There
# are **no exemptions** here: this copy is ported to a public page that outlives
# the build it was written against, so a stale price is worse in the manual than
# in a compiled FAQ — the FAQ is at least read next to the real offer.
MONEY = re.compile(r"\d+[- ]day|£|\$|€")


def check_c6():
    """No price and no trial length anywhere in the manual."""
    problems = []
    for path in manual_pages():
        for number, line in enumerate(read(path).splitlines(), start=1):
            # Every hit on the line, not the first: fixing one and being handed
            # the next on the following run is how a check earns a reputation
            # for being tedious, and a tedious check gets disabled.
            for hit in MONEY.finditer(line):
                problems.append("%s:%d names a price or a period: %r"
                                % (relative(path), number, hit.group(0)))
    if problems:
        return FAIL, problems
    pages = len(manual_pages())
    return OK, ["%d page%s carr%s no number StoreKit owns"
                % (pages, "" if pages == 1 else "s", "ies" if pages == 1 else "y")]


def count_long_press_sites():
    return sum(read(path).count("onLongPressGesture") for path in source_files())


def count_faq_entries():
    text = read(os.path.join(SOURCE, "Core/Help/FAQEntry.swift"))
    return len(re.findall(r"\.init\(question:", text))


def count_loop_controls_rows():
    """Rows in the **Loop controls** popover — the cheatsheet gestures.md is a superset of."""
    text = read(os.path.join(SOURCE, "Features/Waveform/WaveformSections.swift"))
    start = text.index("struct LoopControlsInfo")
    body = text[start:text.index("private func row(", start)]
    return len(re.findall(r"^\s*row\(", body, re.MULTILINE))


# A tripwire is for a fact with no name to check — "there are nine long-press
# sites" is a claim the manual makes in prose, and no grep can tell whether the
# prose still describes the tenth. The comment is a promise; this is the alarm.
TRIPWIRES = {
    "long-press-sites": (count_long_press_sites, "onLongPressGesture under Pocket/"),
    "faq-entries": (count_faq_entries, "FAQEntry.all"),
    "loop-controls-rows": (count_loop_controls_rows, "rows in LoopControlsInfo"),
}

TRIPWIRE = re.compile(r"<!--\s*([a-z-]+):\s*(\d+)\s*-->")


def check_c8():
    """Count tripwires: `<!-- key: N -->` fails when N stops matching the source."""
    problems, confirmed = [], []
    for path in manual_pages():
        for number, line in enumerate(read(path).splitlines(), start=1):
            match = TRIPWIRE.search(line)
            if not match:
                continue
            key, claimed = match.group(1), int(match.group(2))
            if key not in TRIPWIRES:
                continue          # not every HTML comment is a tripwire
            counter, described = TRIPWIRES[key]
            actual = counter()
            where = "%s:%d" % (relative(path), number)
            if actual != claimed:
                problems.append(
                    "%s claims %s: %d, but %s counts %d. The page's prose was "
                    "written against %d — reread it before moving the number."
                    % (where, key, claimed, described, actual, claimed))
            else:
                confirmed.append("%s: %s = %d" % (where, key, actual))
    if problems:
        return FAIL, problems
    if not confirmed:
        return PENDING, ["no tripwires set yet — available: %s"
                         % ", ".join(sorted(TRIPWIRES))]
    return OK, confirmed


CHECKS = [
    ("C1", "Settings destinations are named in the reference", check_c1),
    ("C2", "Toolkit sections are named in toolkit.md", check_c2),
    ("C6", "no price, no trial length", check_c6),
    ("C8", "count tripwires still match the source", check_c8),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--list", action="store_true",
                        help="print each check and its current state, then exit")
    args = parser.parse_args()

    if not os.path.isdir(MANUAL):
        print("check-manual: docs/manual/ does not exist yet — nothing to check.")
        return 0

    failed = False
    for name, description, run in CHECKS:
        state, notes = run()
        mark = {OK: "✅", FAIL: "❌", PENDING: "⏳"}[state]
        print("%s %s  %s" % (mark, name, description))
        for note in notes:
            print("      %s" % note)
        if state == FAIL:
            failed = True
        if args.list:
            continue

    if failed:
        print("\ncheck-manual: FAILED — see ADR 0165 for which owner each fact has.")
        return 1
    print("\ncheck-manual: passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
