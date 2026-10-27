#!/usr/bin/env python3
"""Turn the listing copy into what App Store Connect's fields take (ADR 0279).

    ./scripts/export-listing.py                      # check every field, write build/app-store-listing/
    ./scripts/export-listing.py --copy description   # ...and put one field on the clipboard

`docs/app-store-listing-copy.md` is the source. Its paste-ready text sits in blockquotes, wrapped and
marked up so it reads well in an editor. App Store Connect's fields are plain text: they render no
markdown, and they keep every line break. Pasting a blockquote as it is puts `>`, `**` and a break
every hundred characters into the listing. This writes each field the way the field wants it:

- the `> ` prefixes go, and a `>` line on its own becomes the blank line between paragraphs;
- the wrapped lines of a paragraph, or of a `•` bullet, join into one line;
- a line that is bold and nothing else is a heading, so it keeps a line of its own;
- `**bold**`, `*italic*` and `` `code` `` marks go, and so does a trailing count like *(166)*.

Each field is the **first** blockquote under its heading. It's checked against App Store Connect's
limit, and the description is checked for the EULA link (Guideline 3.1.2, which rejected 1.1 (3)).
A field it can't find, an empty one, one over its limit, leftover markup or a missing EULA link stops
it with a non-zero exit, so a parse that finds nothing can't pass. It writes only under `build/`
(ignored by git) and commits nothing.
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "docs" / "app-store-listing-copy.md"
OUT = ROOT / "build" / "app-store-listing"

EULA = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"

# (field, the heading it sits under, App Store Connect's limit in characters)
FIELDS = [
    ("subtitle", "## Subtitle", 30),
    ("promotional-text", "## Promotional text", 170),
    ("keywords", "## Keywords", 100),
    ("description", "## Description", 4000),
    ("whats-new", "## What's New in This Version — 1.4", 4000),
    ("review-notes", "## App Review notes", 4000),
]

HEADING = re.compile(r"^\*\*[^*]+\*\*$")
COUNT = re.compile(r"\s*\*\(\d+\)\*\s*$")


def first_blockquote(lines, heading):
    """The first run of `>` lines under `heading`, before the next `## ` heading."""
    # The whole line, or the heading and then a space: `## Descriptions` is not `## Description`.
    starts = [i for i, line in enumerate(lines) if line == heading or line.startswith(heading + " ")]
    if len(starts) != 1:
        return None, "%d headings match %r (want exactly 1)" % (len(starts), heading)
    block = []
    for line in lines[starts[0] + 1:]:
        if line.startswith("## "):
            break
        if line.startswith(">"):
            block.append(line)
        elif block:
            break
    if not block:
        return None, "no blockquote under %r" % heading
    return block, None


def unmark(text):
    text = COUNT.sub("", text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"\1", text)
    text = re.sub(r"\*([^*\n]+)\*", r"\1", text)
    return text.replace("`", "").strip()


def to_field(block):
    paragraphs, current = [], []
    for raw in block:
        text = raw[1:]
        text = text[1:] if text.startswith(" ") else text
        if not text.strip():
            if current:
                paragraphs.append(current)
            current = []
        else:
            current.append(text)
    if current:
        paragraphs.append(current)

    rendered = []
    for paragraph in paragraphs:
        rows = []  # (text, is_heading, is_bullet)
        for line in paragraph:
            stripped = line.strip()
            heading = bool(HEADING.match(COUNT.sub("", stripped)))
            bullet = stripped.startswith("•")
            continuation = line.startswith("  ") and rows and rows[-1][2]
            if rows and not heading and not bullet and not rows[-1][1] and (continuation or not rows[-1][2]):
                text, was_heading, was_bullet = rows[-1]
                rows[-1] = (text + " " + stripped, was_heading, was_bullet)
            else:
                rows.append((stripped, heading, bullet))
        rendered.append("\n".join(unmark(text) for text, _, _ in rows))
    return "\n\n".join(rendered)


def problems_with(field, text, limit):
    found = []
    if not text.strip():
        found.append("is empty")
    if len(text) > limit:
        found.append("is %d characters, over the limit of %d" % (len(text), limit))
    for mark in ("**", "`"):
        if mark in text:
            found.append("still contains %r" % mark)
    if any(line.startswith(">") for line in text.splitlines()):
        found.append("still has a line starting with '>'")
    if field == "keywords" and ", " in text:
        found.append("has a space after a comma (App Store Connect counts it)")
    if field == "description" and EULA not in text:
        found.append("has no EULA link (Guideline 3.1.2, the rejection of 1.1 (3))")
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--copy", metavar="FIELD", choices=[f for f, _, _ in FIELDS],
                        help="put one field on the clipboard: " + ", ".join(f for f, _, _ in FIELDS))
    parser.add_argument("--source", type=Path, default=SOURCE, help=argparse.SUPPRESS)
    parser.add_argument("--out", type=Path, default=OUT, help=argparse.SUPPRESS)
    args = parser.parse_args()

    lines = args.source.read_text(encoding="utf-8").splitlines()
    fields, failed = {}, False
    for field, heading, limit in FIELDS:
        block, error = first_blockquote(lines, heading)
        if error:
            print("❌ %-17s %s" % (field, error))
            failed = True
            continue
        text = to_field(block)
        fields[field] = text
        found = problems_with(field, text, limit)
        mark = "❌" if found else "✅"
        print("%s %-17s %5d / %d" % (mark, field, len(text), limit) + ("  — " + "; ".join(found) if found else ""))
        failed = failed or bool(found)

    if failed:
        print("\nNothing written. Fix the listing copy and run it again.")
        return 1

    args.out.mkdir(parents=True, exist_ok=True)
    for field, text in fields.items():
        (args.out / (field + ".txt")).write_text(text, encoding="utf-8")
    print("\nWritten to %s/" % args.out.relative_to(ROOT) if args.out.is_relative_to(ROOT) else args.out)

    if args.copy:
        subprocess.run(["pbcopy"], input=fields[args.copy].encode("utf-8"), check=True)
        print("📋 %s is on the clipboard. Paste it into App Store Connect." % args.copy)
    return 0


if __name__ == "__main__":
    sys.exit(main())
