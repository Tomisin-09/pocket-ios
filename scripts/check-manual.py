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
    C7  `streak` and `this year` appear on no published page
    C8  count tripwires: a `<!-- key: N -->` comment fails when N stops matching
        the live count in the source
    C9  inside reference/**, every backticked token is a real Swift string literal
    C13 every `capture()` in the shoot harness names a marker that exists, and no
        `device:` shot is driven; shots still unshot report pending, not fail

C3/C4/C5 (FAQ citation, no-copied-answers, byte-for-byte quoting) arrive with
Slice A, when there is prose for them to check; C9 arrives with the reference
wing, whose backticks are the only ones that promise to be on screen.

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
UITESTS = os.path.join(REPO, "PocketUITests")

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
    # `\u{201C}` is not decoration: `PracticeFieldInfo.songMastery` spells its
    # curly quotes that way, and a manual page quoting the *rendered* string is
    # correct while a checker comparing the *escaped* one reports drift that
    # isn't there. Decoding here keeps C5 comparing like with like.
    value = re.sub(r"\\u\{([0-9A-Fa-f]+)\}",
                   lambda hit: chr(int(hit.group(1), 16)), value)
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


def prose_pages():
    """The published pages — `manual_pages()` minus `README.md`.

    A word-ban check must not read the document where the ban is written down.
    `README.md` has no route (it is authoring guidance, not a manual page) and its
    parked list names `streak` and "this year" on purpose, so C7 reading it would
    fail on the sentence that tells you not to write them.

    C6 deliberately still uses `manual_pages()`: a stale price is wrong in the
    README too, and nothing there needs to name one.
    """
    return [p for p in manual_pages() if os.path.basename(p) != "README.md"]


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


def faq_entries():
    """`(question, answer)` for every entry in the catalog, in source order.

    The search for `answer:` is bounded by the **next entry**, not by a fixed
    window: the mastery/command-tempo entry carries five lines of comment between
    its question and its answer, and a 200-character window silently dropped it —
    an under-count that reads exactly like a pass.
    """
    text = read(os.path.join(SOURCE, "Core/Help/FAQEntry.swift"))
    sites = [site for site in re.finditer(r"\.init\(question:\s*", text)]
    entries = []
    for index, site in enumerate(sites):
        question, end = swift_literal_at(text, site.end())
        if question is None:
            continue
        stop = sites[index + 1].start() if index + 1 < len(sites) else len(text)
        hit = re.compile(r"(?<![A-Za-z])answer:\s*").search(text, end, stop)
        if not hit:
            continue
        answer, _ = swift_literal_at(text, hit.end())
        if answer is not None:
            entries.append((question, answer))
    return entries


# `**See Help & FAQs:** "…"` — the one sanctioned way to point at an answer (0165 D5).
CITATION = re.compile(r'See Help & FAQs:\*{0,2}\s*[“"]([^”"]+)[”"]')


def check_c3():
    """Every FAQ citation names a question that is really in the catalog."""
    entries = faq_entries()
    if not entries:
        return FAIL, ["parsed no FAQ entries — the parser has drifted from "
                      "FAQEntry.swift, which fails silently as a pass"]
    questions = {question for question, _ in entries}
    problems, cited = [], 0
    for path in prose_pages():
        for number, line in enumerate(read(path).splitlines(), start=1):
            for hit in CITATION.finditer(line):
                cited += 1
                if hit.group(1) not in questions:
                    problems.append(
                        "%s:%d cites a question that is not in FAQEntry.all: %r"
                        % (relative(path), number, hit.group(1)))
    if problems:
        return FAIL, problems
    if not cited:
        return PENDING, ["no FAQ citations written yet (%d questions available)"
                         % len(questions)]
    return OK, ["%d citation%s resolve to a live question"
                % (cited, "" if cited == 1 else "s")]


def shingles(text, size=12):
    """Every `size`-word run in `text`, lowercased — the C4 copy detector."""
    words = re.findall(r"[a-z0-9']+", text.lower())
    return {" ".join(words[i:i + size]) for i in range(len(words) - size + 1)}


def check_c4():
    """No FAQ answer is reproduced in the manual — cite it, don't copy it.

    Two nets, because one alone leaks: a whole sentence catches a lifted line
    even when it is reworded around the edges, and a 12-word shingle catches the
    half-sentence that a sentence match would slide past.
    """
    entries = faq_entries()
    if not entries:
        return FAIL, ["parsed no FAQ entries — see C3"]
    sentences, shingled = {}, {}
    for question, answer in entries:
        # Only the parts of an answer the FAQ actually *wrote*. Where an answer
        # interpolates `\(PracticeFieldInfo.…)` it is already quoting the catalog
        # that C5 obliges `terms.md` to quote too, so matching across an
        # interpolation would set C4 and C5 against each other — the manual would
        # be required to reproduce a string and forbidden from reproducing it.
        for span in re.split(r"\\\([^)]*\)", answer):
            for sentence in re.split(r"(?<=[.!?])\s+", span):
                cleaned = sentence.strip()
                if len(cleaned) >= 60:
                    sentences[cleaned] = question
            for shingle in shingles(span):
                shingled[shingle] = question

    problems = []
    for path in prose_pages():
        body = read(path)
        for sentence, question in sentences.items():
            if sentence in body:
                problems.append("%s copies a sentence from the answer to %r — "
                                "cite the question instead" % (relative(path), question))
        overlap = shingles(body) & set(shingled)
        for shingle in sorted(overlap)[:5]:
            problems.append("%s repeats 12 words of the answer to %r: %r"
                            % (relative(path), shingled[shingle], shingle))
    if problems:
        return FAIL, problems
    pages = len(prose_pages())
    if not pages:
        return PENDING, ["no published pages written yet"]
    return OK, ["%d page%s reproduce%s no answer from %d entries"
                % (pages, "" if pages == 1 else "s",
                   "s" if pages == 1 else "", len(entries))]


def swift_constants(path, container):
    """`{name: value}` for the `static let name = "…"` members of one enum."""
    text = read(os.path.join(SOURCE, path))
    start = text.index(container)
    found = {}
    for site in re.finditer(r"static let (\w+)\s*=\s*", text[start:]):
        value, _ = swift_literal_at(text[start:], site.end())
        if value is not None:
            found[site.group(1)] = value
    return found


def check_c5():
    """`terms.md` quotes all six `PracticeFieldInfo` strings byte-for-byte.

    The direct analogue of `testMasteryAnswerQuotesTheInAppExplanations`: the
    ⓘ popover is the definition, and a page that paraphrases it is a page that
    drifts the moment the popover is reworded.
    """
    definitions = swift_constants("UI/FieldInfoLabel.swift", "enum PracticeFieldInfo")
    target = page("terms.md")
    if not os.path.exists(target):
        return PENDING, ["docs/manual/terms.md not written yet — %d definitions "
                         "waiting from PracticeFieldInfo" % len(definitions)]
    if not definitions:
        return FAIL, ["parsed no definitions from PracticeFieldInfo — the parser "
                      "has drifted, which fails silently as a pass"]
    body = read(target)
    missing = [name for name, value in definitions.items() if value not in body]
    if missing:
        return FAIL, ["docs/manual/terms.md does not quote %s byte-for-byte. Copy "
                      "the string from PracticeFieldInfo rather than retyping it."
                      % ", ".join(sorted(missing))]
    notes = ["all %d PracticeFieldInfo definitions quoted verbatim" % len(definitions)]

    # `gestures.md` reproduces the in-app Loop controls cheatsheet in full, so the same
    # rule applies to it. This is a **name** check and the `loop-controls-rows` tripwire is
    # a **count** one, and they catch opposite failures: reword a row and this fails while
    # the count still passes; add a ninth row and the count fails while this still passes.
    cheatsheet = page("gestures.md")
    if os.path.exists(cheatsheet):
        rows = loop_controls_rows()
        if not rows:
            return FAIL, ["parsed no rows from LoopControlsInfo — the parser has drifted"]
        text = read(cheatsheet)
        stale = [key for key, detail in rows if key not in text or detail not in text]
        if stale:
            return FAIL, ["docs/manual/gestures.md does not quote the Loop controls "
                          "row(s) %s byte-for-byte" % ", ".join(repr(s) for s in stale)]
        notes.append("all %d Loop controls rows quoted verbatim" % len(rows))

    # `reference/settings.md` walks all nine destinations, so between them it meets every
    # `SettingsInfo` explanation — which makes "quote the ones you claim to" and "quote all
    # of them" the same requirement, and the second is the one a script can state without
    # guessing what a claim looks like. C1 proves the page *names* the destinations; this
    # proves it reproduces the copy inside them rather than describing it.
    reference = page("reference", "settings.md")
    if os.path.exists(reference):
        explanations = swift_constants("Features/Settings/SettingsInfo.swift", "enum SettingsInfo")
        if not explanations:
            return FAIL, ["parsed no explanations from SettingsInfo — the parser has drifted"]
        body = read(reference)
        missing = [name for name, value in explanations.items() if value not in body]
        if missing:
            return FAIL, ["docs/manual/reference/settings.md does not quote %s byte-for-byte. "
                          "Copy the string from SettingsInfo rather than retyping it."
                          % ", ".join(sorted(missing))]
        notes.append("all %d SettingsInfo explanations quoted verbatim" % len(explanations))
    return OK, notes


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


# Progress has no streak and no year range, and the plan's parked list says so in
# as many words. Unlike "there is no sync", these two have **no legitimate use** in
# a manual page — which is exactly what makes them checkable where the rest of the
# parked list stays a human review item.
PARKED_WORDS = re.compile(r"streak|this year", re.IGNORECASE)


def check_c7():
    """`streak` and `this year` appear on no published page."""
    problems = []
    for path in prose_pages():
        for number, line in enumerate(read(path).splitlines(), start=1):
            for hit in PARKED_WORDS.finditer(line):
                problems.append(
                    "%s:%d says %r — Progress has neither (see the parked list in "
                    "docs/manual/README.md)" % (relative(path), number, hit.group(0)))
    if problems:
        return FAIL, problems
    pages = len(prose_pages())
    if not pages:
        return PENDING, ["no published pages written yet"]
    return OK, ["%d page%s free of both" % (pages, "" if pages == 1 else "s")]


def count_long_press_sites():
    return sum(read(path).count("onLongPressGesture") for path in source_files())


def count_faq_entries():
    text = read(os.path.join(SOURCE, "Core/Help/FAQEntry.swift"))
    return len(re.findall(r"\.init\(question:", text))


def loop_controls_rows():
    """`(key, detail)` for each row of the in-app Loop controls cheatsheet."""
    text = read(os.path.join(SOURCE, "Features/Waveform/WaveformSections.swift"))
    start = text.index("struct LoopControlsInfo")
    body = text[start:text.index("private func row(", start)]
    rows = []
    for site in re.finditer(r"row\(", body):
        key, end = swift_literal_at(body, site.end())
        if key is None:
            continue
        gap = re.match(r"\s*,\s*", body[end:])
        if not gap:
            continue
        detail, _ = swift_literal_at(body, end + gap.end())
        if detail is not None:
            rows.append((key, detail))
    return rows


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


def strip_comments(text):
    """Drop `//` and `/* */` comments, leaving string literals intact.

    Load-bearing for C9, and the reason it is a state machine rather than a regex.
    This codebase documents itself heavily and quotes its own UI copy while doing
    it — `"Nice work"`, `"Start ramp"`, whole footers reproduced in a doc comment
    explaining why they were reworded. Harvesting those as shipping literals would
    make C9 pass on strings that are only ever *described* on screen, which is the
    one failure a check like this must not have. Skipping `//` blindly is equally
    wrong in the other direction: `"https://…"` would lose its tail and the URL
    literals would stop matching themselves.
    """
    out = []
    index, length = 0, len(text)
    while index < length:
        char = text[index]
        if char == '"':
            out.append(char)
            index += 1
            while index < length:
                out.append(text[index])
                if text[index] == "\\" and index + 1 < length:
                    out.append(text[index + 1])
                    index += 2
                    continue
                if text[index] == '"':
                    index += 1
                    break
                index += 1
            continue
        if text.startswith("//", index):
            while index < length and text[index] != "\n":
                index += 1
            continue
        if text.startswith("/*", index):
            index = text.find("*/", index)
            index = length if index < 0 else index + 2
            continue
        out.append(char)
        index += 1
    return "".join(out)


def source_literals():
    """Every string literal that survives into the build, unescaped.

    Interpolated literals are split on their `\\(…)` segments, so a label written
    as `"Trial ends in \\(days) days"` contributes `Trial ends in ` and ` days`
    rather than one string nothing could ever match. That is why C9's escape hatch
    exists: a control whose whole name is assembled at runtime has no literal to
    find, and saying so in a comment is more honest than loosening the check for
    everybody.
    """
    found = set()
    for path in source_files():
        text = strip_comments(read(path))
        for hit in _LITERAL.finditer(text):
            value = unescape(hit.group(1))
            found.add(value)
            for part in re.split(r"\\\([^)]*\)", value):
                if part:
                    found.add(part)
    return found


# `<!-- not-in-source: "Set the 1" — built by interpolation -->` — the escape hatch,
# file-scoped, and required to carry a reason after the string. A hatch you can open
# without saying why is just a disabled check with extra steps.
NOT_IN_SOURCE = re.compile(r'<!--\s*not-in-source:\s*"([^"]+)"\s*(?:—|--)\s*(\S[^>]*?)\s*-->')

# Backticked tokens in `reference/**`. Fenced blocks are skipped by the caller.
BACKTICKED = re.compile(r"`([^`\n]+)`")


def reference_pages():
    return [p for p in prose_pages()
            if os.path.basename(os.path.dirname(p)) == "reference"]


def check_c9():
    """In `reference/**`, a backticked token is a claim that the string is on screen.

    The reference wing's whole job is to name controls, so its backticks carry a
    stronger promise than the spine's: **this is the exact text of a thing you can
    look at**. That is checkable, and it is the check that keeps a per-screen
    inventory from quietly describing a build two releases old.

    Deliberately scoped to `reference/**` and no wider. The spine's pages backtick
    file paths, slugs and settings keys as ordinary prose typography, and holding
    those to the same rule would mean allowlisting half of `README.md`.

    `reference/README.md` is out of scope too, and not by accident: `prose_pages()`
    drops every `README.md` by basename, which is what lets the wing's index
    backtick `scripts/check-manual.py` while stating the rule that would forbid it.
    An index of links makes no claim about what is on screen.
    """
    pages = reference_pages()
    if not pages:
        return PENDING, ["the reference wing is not written yet"]
    literals = source_literals()
    if not literals:
        return FAIL, ["harvested no string literals from Pocket/ — the parser has "
                      "drifted, which fails silently as a pass"]

    problems, checked = [], 0
    for path in pages:
        body = read(path)
        exempt = {hit.group(1) for hit in NOT_IN_SOURCE.finditer(body)}
        unused = set(exempt)
        # A fenced block is code, not a control name — `swift`, `./scripts/…` and
        # the marker grammar all live in one, and none of them is on screen.
        prose = re.sub(r"```.*?```", "", body, flags=re.DOTALL)
        for number, line in enumerate(prose.splitlines(), start=1):
            for hit in BACKTICKED.finditer(line):
                token = hit.group(1).strip()
                if not token:
                    continue
                checked += 1
                if token in exempt:
                    unused.discard(token)
                    continue
                if token not in literals:
                    problems.append(
                        "%s:%d backticks %r, which is not a string literal under "
                        "Pocket/. Either it is not what the screen says, or it is "
                        "assembled at runtime — in which case add "
                        "<!-- not-in-source: %r — why --> to this page."
                        % (relative(path), number, token, token))
        for stale in sorted(unused):
            problems.append("%s exempts %r, which it never backticks — drop the "
                            "not-in-source comment" % (relative(path), stale))
    if problems:
        return FAIL, problems
    return OK, ["%d backticked control name%s found in the source"
                % (checked, "" if checked == 1 else "s")]


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


# --- the shot markers ------------------------------------------------------

ROLES = {"glyph", "detail", "panel", "band", "screen", "strip"}

MARKER = re.compile(r"<!--\s*shot:\s*(.*?)-->", re.DOTALL)
CALLOUT = re.compile(r"\d+@[\d.]+,[\d.]+")
ORDERED_ITEM = re.compile(r"^\s*\d+\.\s+\S")


def markers_in(body):
    """`(fields, line_number, raw)` for every shot marker in `body`."""
    found = []
    for hit in MARKER.finditer(body):
        fields, raw = {}, hit.group(1)
        parts = [p.strip() for p in raw.split("|")]
        if parts:
            fields["slug"] = parts[0].strip()
        for part in parts[1:]:
            if ":" not in part:
                continue
            key, value = part.split(":", 1)
            fields[key.strip()] = value.strip()
        line = body[:hit.start()].count("\n") + 1
        found.append((fields, line, raw))
    return found


def check_c10():
    """Every `<!-- shot: -->` marker parses and obeys the role grammar (0165 D7).

    Deliberately **not** checking that the slug matches the page it sits on. A
    slug names the shot, not the page: the same crop of the player legitimately
    appears in `looping.md` and again in `gestures.md`, and requiring a match
    would force one of them to invent a second name for one image.
    """
    problems, total = [], 0
    for path in prose_pages():
        # `shots.md` is generated *from* the markers and describes the grammar in
        # prose. Parsing it finds the syntax quoted in its own preamble and reports
        # it as a malformed marker — the manifest failing the check it exists to
        # summarise.
        if os.path.abspath(path) == os.path.abspath(SHOTS):
            continue
        body = read(path)
        lines = body.splitlines()
        for fields, line, _raw in markers_in(body):
            total += 1
            where = "%s:%d" % (relative(path), line)
            slug = fields.get("slug", "")
            if not re.match(r"^[a-z0-9-]+/[a-z0-9-]+$", slug):
                problems.append("%s has slug %r — expected `group/name`" % (where, slug))
            role = fields.get("role")
            if role not in ROLES:
                problems.append("%s has role %r — expected one of %s"
                                % (where, role, ", ".join(sorted(ROLES))))
            # `alt` is empty only for `glyph`, where the control's name carries
            # the meaning in bold text beside it and the image is decoration.
            alt = fields.get("alt", None)
            if alt is None:
                problems.append("%s has no alt field" % where)
            elif role == "glyph" and alt:
                problems.append("%s is a glyph with alt text %r — glyphs are "
                                "decorative and take empty alt" % (where, alt))
            elif role != "glyph" and not alt:
                problems.append("%s has empty alt but role %r" % (where, role))
            if "crop" in fields and not re.match(r"^\d+,\d+,\d+,\d+$", fields["crop"]):
                problems.append("%s has crop %r — expected `x,y,w,h` in device pixels"
                                % (where, fields["crop"]))
            if "w" in fields and "why" not in fields:
                problems.append("%s overrides width without a why: field" % where)
            if "call" in fields:
                dots = len(CALLOUT.findall(fields["call"]))
                if dots > 6:
                    problems.append("%s has %d callouts — over six means the crop "
                                    "is wrong, not the callouts" % (where, dots))
                items = 0
                for text in lines[line:]:
                    if ORDERED_ITEM.match(text):
                        items += 1
                    elif items:
                        break
                if items != dots:
                    problems.append("%s places %d callouts but the list beneath has "
                                    "%d items" % (where, dots, items))
    if problems:
        return FAIL, problems
    if not total:
        return PENDING, ["no shot markers written yet"]
    return OK, ["%d marker%s parse" % (total, "" if total == 1 else "s")]


# Floats collapse to full-width blocks on a narrow viewport, so position is not a
# stable fact about where an image ended up (0165 D7).
POSITIONAL = re.compile(
    r"\b(shown (above|below)|the (image|figure|screenshot) (above|below)"
    r"|to the (right|left)|pictured (above|below))\b", re.IGNORECASE)


def check_c11():
    """No page refers to an image by its position."""
    problems = []
    for path in prose_pages():
        for number, line in enumerate(read(path).splitlines(), start=1):
            for hit in POSITIONAL.finditer(line):
                problems.append("%s:%d refers to an image by position: %r"
                                % (relative(path), number, hit.group(0)))
    if problems:
        return FAIL, problems
    pages = len(prose_pages())
    if not pages:
        return PENDING, ["no published pages written yet"]
    return OK, ["%d page%s name%s no position"
                % (pages, "" if pages == 1 else "s", "s" if pages == 1 else "")]


SHOTS = page("shots.md")

SHOTS_PREAMBLE = """# Shot manifest

**Generated — do not edit.** Every row here comes from a `<!-- shot: -->` marker in the pages, and
the file is rewritten by:

```sh
./scripts/check-manual.py --write-shots
```

Hand-keeping this list is the failure it exists to prevent: a manifest maintained separately from
the prose drifts from it within one slice, and the shoot then works from the stale copy. `crop` is
filled in at shoot time against the chosen master and is not authored with the prose — see the
marker grammar in [README.md](README.md).
"""


def shot_rows():
    """Every marker across the published pages, as `(slug, role, page, state, device)`."""
    rows = []
    for path in prose_pages():
        if os.path.abspath(path) == os.path.abspath(SHOTS):
            continue
        for fields, _line, _raw in markers_in(read(path)):
            rows.append((fields.get("slug", ""), fields.get("role", ""),
                         os.path.splitext(os.path.basename(path))[0],
                         fields.get("state", ""), fields.get("device", "")))
    return sorted(rows)


def render_shots():
    lines = [SHOTS_PREAMBLE, "", "| Shot | Role | Page | State to seed | Needs a device |",
             "|---|---|---|---|---|"]
    for slug, role, source, state, device in shot_rows():
        lines.append("| `%s` | `%s` | `%s` | %s | %s |"
                     % (slug, role, source, state or "—", device or ""))
    lines.append("")
    lines.append("%d shot%s across %d page%s."
                 % (len(shot_rows()), "" if len(shot_rows()) == 1 else "s",
                    len(prose_pages()) - 1, "" if len(prose_pages()) == 2 else "s"))
    return "\n".join(lines) + "\n"


def check_c12():
    """`shots.md` is regenerated from the markers, not hand-kept."""
    if not shot_rows():
        return PENDING, ["no markers to build a manifest from yet"]
    wanted = render_shots()
    if not os.path.exists(SHOTS):
        return FAIL, ["docs/manual/shots.md is missing — run "
                      "./scripts/check-manual.py --write-shots"]
    if read(SHOTS) != wanted:
        return FAIL, ["docs/manual/shots.md is out of date with the markers — run "
                      "./scripts/check-manual.py --write-shots"]
    return OK, ["%d shots listed, matching the markers" % len(shot_rows())]


CAPTURE = re.compile(r'capture\(\s*\w+\s*,\s*slug:\s*"([^"]+)"')


def captured_slugs():
    """`slug -> [file, …]` for every shot the harness actually photographs."""
    found = {}
    if not os.path.isdir(UITESTS):
        return found
    for name in sorted(os.listdir(UITESTS)):
        if not (name.startswith("Manual") and name.endswith(".swift")):
            continue
        for hit in CAPTURE.finditer(read(os.path.join(UITESTS, name))):
            found.setdefault(hit.group(1), []).append(name)
    return found


def check_c13():
    """Markers and the shoot harness name the same shots.

    The prose has twelve checks on it and the images had none, so the two halves of
    a figure — the marker that promises it and the `capture()` that takes it — were
    held together by hand. A slug renamed in the prose left the harness shooting a
    file nobody references, and every other check stayed green; the only reason the
    gap was ever visible was someone counting both sides by hand.

    **Undriven shots are `pending`, not `fail`.** Eighty of ninety-six are unshot
    while Phase 5 runs, and a check that red-lights every push until a six-minute
    shoot completes is a check that gets commented out in a week. What hard-fails is
    a *ghost*: a `capture()` naming a slug no marker defines. That is always a defect
    and never a to-do, because it means an image is being produced that no page can
    ever show.

    A `device:` marker is the simulator's own admission that it cannot render the
    state honestly (landscape is the known one), so driving one is a failure too —
    it would produce a clean, wrong picture, which is the failure `ManualShotCase` is
    written against.

    Deliberately **not** recorded in `shots.md`. That file is generated and diffed by
    C12, so putting driven-state in it would make editing a Swift test fail a docs
    check — coupling the two things `scripts/docs-only.sh` exists to keep apart.
    """
    rows = shot_rows()
    if not rows:
        return PENDING, ["no markers to drive yet"]
    captured = captured_slugs()
    if not captured:
        return FAIL, ["found no capture() calls under PocketUITests/Manual*.swift — the "
                      "parser has drifted from the harness, which fails silently as a pass"]

    slugs = {slug for slug, _role, _page, _state, _device in rows}
    hand = {slug for slug, _role, _page, _state, device in rows if device}

    problems = []
    for slug in sorted(set(captured) - slugs):
        problems.append("%s captures %r, which no marker defines — renamed in the prose, "
                        "or misspelt in the harness"
                        % ("/".join(sorted(set(captured[slug]))), slug))
    for slug in sorted(set(captured) & hand):
        problems.append("%r is marked `device:` and the simulator cannot shoot it honestly, "
                        "but %s captures it"
                        % (slug, "/".join(sorted(set(captured[slug])))))
    if problems:
        return FAIL, problems

    drivable = slugs - hand
    undriven = sorted(drivable - set(captured))
    if undriven:
        preview = ", ".join(undriven[:4]) + ("…" if len(undriven) > 4 else "")
        return PENDING, ["%d of %d drivable shots not captured yet (%d hand-shot on device): %s"
                         % (len(undriven), len(drivable), len(hand), preview)]
    return OK, ["all %d drivable shots captured (%d hand-shot on device)"
                % (len(drivable), len(hand))]


CHECKS = [
    ("C1", "Settings destinations are named in the reference", check_c1),
    ("C2", "Toolkit sections are named in toolkit.md", check_c2),
    ("C3", "FAQ citations resolve to real questions", check_c3),
    ("C4", "no FAQ answer is copied into the manual", check_c4),
    ("C5", "terms.md quotes PracticeFieldInfo verbatim", check_c5),
    ("C6", "no price, no trial length", check_c6),
    ("C7", "no streak, no 'this year'", check_c7),
    ("C9", "reference backticks name real on-screen strings", check_c9),
    ("C10", "shot markers parse and obey the role grammar", check_c10),
    ("C11", "no image referred to by position", check_c11),
    ("C12", "shots.md matches the markers", check_c12),
    ("C13", "markers and the shoot harness name the same shots", check_c13),
    ("C8", "count tripwires still match the source", check_c8),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--list", action="store_true",
                        help="print each check and its current state, then exit")
    parser.add_argument("--write-shots", action="store_true",
                        help="regenerate docs/manual/shots.md from the page markers")
    args = parser.parse_args()

    if not os.path.isdir(MANUAL):
        print("check-manual: docs/manual/ does not exist yet — nothing to check.")
        return 0

    if args.write_shots:
        with open(SHOTS, "w", encoding="utf-8") as handle:
            handle.write(render_shots())
        print("check-manual: wrote %s (%d shots)." % (relative(SHOTS), len(shot_rows())))
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
