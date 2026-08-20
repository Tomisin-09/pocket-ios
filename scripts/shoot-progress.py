#!/usr/bin/env python3
"""What is shot, what is left, and what looks wrong — for a *hand* shoot (ADR 0165, Phase 5).

`check-manual.py`'s C13 measures the shoot by counting `capture()` calls in
`PocketUITests/Manual*.swift`. That was the right metric while the harness drove every
figure and it is the wrong one now: a hand shoot adds no `capture()` calls ever, so C13
sits frozen at its driven count no matter how many images land. The shot list said that
count was "the progress metric", which stopped being true the day the shoot went manual.

This reads the images instead. `docs/manual/shots.md` stays the manifest — it is generated
from the markers, so a figure exists here exactly when a page places it — and a slug counts
as shot when a file named after it exists in one of the scanned directories.

    ./scripts/shoot-progress.py                    # progress, then what to shoot next
    ./scripts/shoot-progress.py --remaining        # just the outstanding slugs, one per line
    ./scripts/shoot-progress.py --verify           # add the checks that catch a bad frame

`--verify` is the half worth running before you believe a session went well, because all
three failures it looks for produce a *file*, and a file is what every other check counts
as success:

  * **Identical images.** Two figures with the same bytes is the signature of a missed tap —
    the screen never changed and the second shot photographed the first state. Pairs the
    shot list explicitly calls "same frame as" are expected, and are parsed from it rather
    than hard-coded here, so the exception list cannot drift from the sheet you shoot by.
  * **Wrong geometry.** Crops are recorded in device pixels against a 1206×2622 master, so
    a frame captured at another size silently invalidates every crop taken against it.
  * **Empty or truncated files.** A `simctl io screenshot` that raced a device reboot.

Exit status is 0 whenever the scan itself worked, including with figures outstanding —
progress is not a pass/fail condition and this must never gate a push.
"""

import argparse
import hashlib
import importlib.util
import re
import struct
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SHOOT_LIST = REPO / "docs" / "manual-shoot-list.md"
MASTER = (1206, 2622)


def check_manual():
    """`check-manual.py` as a module — it owns the marker parse and keeps owning it.

    The first version of this script re-parsed the generated `shots.md` table with its own
    regex, and immediately proved why that is the wrong move: it read 98 of 101 figures
    (the three `subscription/*` rows wrap their device note onto a second line, so a
    row-shaped pattern missed them) and found 1 device figure instead of 4 (a marker with
    a `device:` field renders an empty cell unless the note is long enough to show). Both
    are the same mistake — a second parser for a fact that already has an owner. Importing
    is a little awkward because the filename has a hyphen; that is the whole cost.
    """
    spec = importlib.util.spec_from_file_location("check_manual", REPO / "scripts" / "check-manual.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

DEFAULT_DIRS = [REPO / "shots" / "filed",
                REPO / "shots" / "filed-partial",
                Path.home() / "Desktop" / "manual-shots"]

# The shot list's own note that two figures deliberately share one frame.
SAME_FRAME = re.compile(r"`([a-z0-9/-]+)`[^|]*?[Ss]ame frame as\s*`([a-z0-9/-]+)`")


def figures():
    """Every figure the manual places: [(slug, role, page, needs_device)]."""
    rows = check_manual().shot_rows()
    if not rows:
        sys.exit("no markers found — is docs/manual/ populated?")
    return [(slug, role, page, bool(device)) for slug, role, page, _state, device in rows]


def intentional_pairs(dirs):
    """Every pair of slugs that is *meant* to be one frame, so --verify does not cry wolf.

    There are two ways a shared frame gets declared and both have to be read, which the first
    version of this got wrong by reading only the first:

      * **A hand shot** says so in the shot list — *same frame as `slug`* — because that sheet is
        what a person shoots by.
      * **A driven shot** says so in the harness, `capture(…, alsoServing:)`, and the filed
        `.context` beside the image carries it as an "also serves:" line.

    Reading the `.context` is better than re-reading the Swift: it is what was true of the frame
    actually on disk, so a test edited after the shoot cannot make a stale exception look current.
    """
    pairs = set()
    if SHOOT_LIST.exists():
        pairs |= {frozenset(pair) for pair in SAME_FRAME.findall(
            SHOOT_LIST.read_text(encoding="utf-8"))}
    for directory in dirs:
        if not directory.is_dir():
            continue
        for context in directory.glob("*.context"):
            text = context.read_text(encoding="utf-8", errors="replace")
            primary = ""
            shared = []
            for raw in text.splitlines():
                if raw.startswith("slug:"):
                    primary = raw.split(":", 1)[1].strip()
                elif raw.startswith("also serves:"):
                    shared = [s.strip() for s in raw.split(":", 1)[1].split(",") if s.strip()]
            for other in shared:
                pairs.add(frozenset((primary, other)))
            # Two aliases of one frame are identical to each other, not only to the primary.
            for i, a in enumerate(shared):
                for b in shared[i + 1:]:
                    pairs.add(frozenset((a, b)))
    return pairs


def png_size(path):
    """(width, height) from the IHDR, or None if this is not a readable PNG."""
    try:
        with open(path, "rb") as handle:
            head = handle.read(24)
    except OSError:
        return None
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", head[16:24])


def scan(dirs):
    """{slug: Path} for every figure image found, first directory winning."""
    found = {}
    for directory in dirs:
        if not directory.is_dir():
            continue
        for entry in sorted(directory.iterdir()):
            if entry.suffix.lower() != ".png":
                continue
            found.setdefault(entry.stem, entry)
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--remaining", action="store_true",
                        help="print only the outstanding slugs, one per line")
    parser.add_argument("--verify", action="store_true",
                        help="also check the filed images for the three silent failures")
    parser.add_argument("--dir", action="append", type=Path, dest="dirs",
                        help="directory of filed images (repeatable; defaults to shots/filed, "
                             "shots/filed-partial and ~/Desktop/manual-shots)")
    args = parser.parse_args()

    dirs = args.dirs or DEFAULT_DIRS
    rows = figures()
    on_disk = scan(dirs)

    done, todo, device_todo = [], [], []
    for slug, role, page, needs_device in rows:
        if slug.replace("/", "-") in on_disk:
            done.append(slug)
        elif needs_device:
            device_todo.append(slug)
        else:
            todo.append(slug)

    if args.remaining:
        for slug in todo:
            print(slug)
        return 0

    total = len(rows)
    print(f"{len(done)} of {total} figures shot — {len(todo)} left on the simulator, "
          f"{len(device_todo)} needing a real phone")
    print("scanned: " + ", ".join(str(d) for d in dirs if d.is_dir()))

    if todo:
        by_page = {}
        for slug in todo:
            by_page.setdefault(slug.split("/")[0], []).append(slug)
        print("\nstill to shoot:")
        for page in sorted(by_page):
            print(f"  {page:18} {len(by_page[page]):2}  " + " ".join(
                s.split("/", 1)[1] for s in by_page[page]))
    if device_todo:
        print("\n  needs a phone:   " + " ".join(device_todo))

    if args.verify:
        print()
        problems = verify(on_disk, rows, dirs)
        if problems:
            print("verify — %d thing(s) to look at:" % len(problems))
            for line in problems:
                print("  " + line)
        else:
            print(f"verify — {len(done)} filed image(s): all {MASTER[0]}×{MASTER[1]}, "
                  "no unexpected duplicates, none truncated")
    return 0


def verify(on_disk, rows, dirs):
    """The three failures that still produce a file. Returns a list of complaints."""
    wanted = {slug.replace("/", "-"): slug for slug, _r, _p, _d in rows}
    problems = []
    digests = {}

    for stem, path in sorted(on_disk.items()):
        if stem not in wanted:
            continue
        size = path.stat().st_size
        if size == 0:
            problems.append(f"{wanted[stem]}: file is empty")
            continue
        dims = png_size(path)
        if dims is None:
            problems.append(f"{wanted[stem]}: not a readable PNG ({size} bytes) — truncated?")
            continue
        if dims != MASTER:
            problems.append(f"{wanted[stem]}: {dims[0]}×{dims[1]}, not {MASTER[0]}×{MASTER[1]} "
                            "— recorded crops will not land on this frame")
        digests.setdefault(hashlib.md5(path.read_bytes()).hexdigest(), []).append(wanted[stem])

    expected = intentional_pairs(dirs)
    for slugs in digests.values():
        if len(slugs) < 2:
            continue
        if all(frozenset((a, b)) in expected
               for i, a in enumerate(sorted(slugs)) for b in sorted(slugs)[i + 1:]):
            continue
        problems.append("identical images: " + ", ".join(sorted(slugs))
                        + " — a missed tap photographs the previous state twice, and neither the "
                        "shot list nor the filed .context declares these a shared frame")
    return problems


if __name__ == "__main__":
    sys.exit(main())
