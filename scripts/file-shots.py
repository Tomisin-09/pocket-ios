#!/usr/bin/env python3
"""File an exported shoot into slug-named images (ADR 0165, Phase 5).

`xcrun xcresulttool export attachments` writes every attachment under a **UUID** filename and
records the real one in `manifest.json`. That is unusable as a shoot output: the manual has
ninety-six figures, and the step that catches the failure mode this harness exists for — opening
each image and confirming it shows the screen it claims — cannot be done against a directory of
UUIDs. The first eleven figures were filed by hand and that folder still holds four nobody can name.

So this reads the manifest and renames each attachment to its slug:

    shots/export/764352B2-….png   →   shots/filed/metronome-screen.png
    shots/export/930D4E9B-….txt   →   shots/filed/metronome-screen.context

**What counts as a figure is decided by `docs/manual/shots.md`, not by the shape of the filename.**
XCTest attaches its own diagnostics to a run — screen recordings, UI snapshots, a "Debug description"
per failed query — and files *some* of them under the same `<name>_<retry>_<uuid>` convention it
gives the ones a test adds. Filtering on that pattern therefore lets a screen recording through into
the manual's image directory, which is what the first version of this script did. Matching against
the manual's own manifest instead also catches the opposite error: a `capture` call whose slug is not
a marker in any page, i.e. a figure nothing will ever place.

    ./scripts/file-shots.py shots/export shots/filed
"""

import json
import re
import shutil
import sys
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SHOTS_MD = REPO / "docs" / "manual" / "shots.md"

# `| `journal/take-row` | `detail` | …` — the first backticked cell of a manifest row.
SLUG_ROW = re.compile(r"^\|\s*`([a-z0-9/-]+)`\s*\|")


def known_slugs():
    """Every slug the manual actually places, as it appears in an attachment name."""
    if not SHOTS_MD.exists():
        sys.exit(f"no {SHOTS_MD} — run ./scripts/check-manual.py --write-shots first")
    slugs = {m.group(1).replace("/", "-")
             for m in map(SLUG_ROW.match, SHOTS_MD.read_text().splitlines()) if m}
    if not slugs:
        sys.exit(f"no shot rows parsed out of {SHOTS_MD} — has its table format changed?")
    return slugs


def parse(name):
    """('metronome-screen_0_ABC.png') -> ('metronome-screen', 0, '.png'); None if not that shape.

    The retry index is kept because it matters on its own account: a re-run attempt writes a second
    image under the same slug, and silently keeping whichever landed last is how a figure from a
    failed first attempt ends up in the manual.
    """
    suffix = "".join(Path(name).suffixes[-1:])
    stem = name[: -len(suffix)] if suffix else name
    parts = stem.split("_")
    if len(parts) >= 3 and parts[-2].isdigit():
        return "_".join(parts[:-2]), int(parts[-2]), suffix
    return None


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    export, filed = Path(sys.argv[1]), Path(sys.argv[2])

    manifest = export / "manifest.json"
    if not manifest.exists():
        sys.exit(f"no manifest.json in {export} — was this directory written by "
                 f"`xcresulttool export attachments`?")

    slugs = known_slugs()
    filed.mkdir(parents=True, exist_ok=True)
    for stale in filed.iterdir():
        if stale.is_file():
            stale.unlink()

    # slug -> [(attempt, source, suffix)], so a slug shot more than once is visible rather than
    # resolved by whichever the loop happened to reach last.
    found = defaultdict(list)
    unplaced = set()
    for test in json.loads(manifest.read_text()):
        for att in test.get("attachments", []):
            parsed = parse(att.get("suggestedHumanReadableName") or "")
            if parsed is None:
                continue
            slug, attempt, suffix = parsed
            if slug not in slugs:
                # Only worth reporting for images: XCTest's text diagnostics land here in bulk.
                if suffix == ".png":
                    unplaced.add(slug)
                continue
            found[slug].append((attempt, export / att["exportedFileName"], suffix))

    images = retries = 0
    for slug, entries in sorted(found.items()):
        attempts = {a for a, _, _ in entries}
        if len(attempts) > 1:
            retries += 1
            print(f"  ⚠️  {slug}: shot {len(attempts)}× (retries {sorted(attempts)}) — "
                  f"filing the last attempt only")
        best = max(attempts)
        for attempt, source, suffix in entries:
            if attempt == best and source.exists():
                shutil.copy2(source, filed / f"{slug}{suffix}")
                images += int(suffix == ".png")

    # One frame legitimately serves several markers — `capture(…, alsoServing:)` — and until now
    # only the primary got a file. The shared slugs were recorded in an "also serves:" line inside
    # the `.context` text and nowhere else, so a fully green shoot left ten markers with no image
    # while every check agreed it had succeeded: C13 counts the `capture()` call, which covers all
    # of them, and nothing counted files. Each marker places an image on its own page, so each
    # needs one on disk.
    #
    # Copied rather than symlinked: these are uploaded to the site repo, where a link would arrive
    # as a dangling file, and a figure is small.
    aliases = 0
    for context in sorted(filed.glob("*.context")):
        primary = context.with_suffix(".png")
        if not primary.exists():
            continue
        for raw in context.read_text(encoding="utf-8").splitlines():
            if not raw.startswith("also serves:"):
                continue
            for shared in raw.split(":", 1)[1].split(","):
                name = shared.strip().replace("/", "-")
                if not name:
                    continue
                if name not in slugs:
                    print(f"  ⚠️  '{shared.strip()}' is served by {context.stem} but is not a "
                          f"marker in any page")
                    continue
                shutil.copy2(primary, filed / f"{name}.png")
                shutil.copy2(context, filed / f"{name}.context")
                aliases += 1
                images += 1

    print(f"\n  {images} image(s) filed into {filed}  ({len(slugs) - len(found) - aliases} of "
          f"{len(slugs)} manual slugs still unshot)")
    if aliases:
        print(f"  {aliases} of those are shared frames, copied from the figure that shot them.")
    for slug in sorted(unplaced):
        print(f"  ⚠️  '{slug}' was captured but is not a marker in any page — check the slug "
              f"in the test against docs/manual/shots.md")
    if retries:
        print(f"  {retries} slug(s) were shot more than once — a retried run is not a clean run.")

    # A shoot with no images is a shoot that failed in a way the exit code did not show.
    if images == 0:
        sys.exit("❌ no images filed — treat as a failed shoot, not an empty one")


if __name__ == "__main__":
    main()
