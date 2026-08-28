#!/usr/bin/env python3
"""Cut the manual's figures from their masters (ADR 0165, Phase 5).

A master is a whole 1206×2622 device frame. A *figure* is what a page actually shows: often the
whole frame, but for thirteen of them a `crop:` rect out of one — a glyph in a toolbar, a band
across the middle of a run screen, one row of a library. This turns the first into the second, one
file per marker, named by slug, and writes a manifest beside them.

    ./scripts/build-figures.py                  # build into shots/figures/
    ./scripts/build-figures.py --out DIR        # somewhere else

**Output goes under `shots/`, which is gitignored, and that is deliberate.** ADR 0165: *"binaries
get one home, and it is not this one"* — the rendering site's `public/redmoon/` is that home. What
this script produces is a drop, not a checked-in asset, and putting it anywhere tracked would make
this repo the second home the ADR exists to prevent.

Three things it will not do, each because the alternative is worse:

  * **It never invents a master.** A marker whose image is not on disk is reported and skipped, not
    filled with a placeholder. A placeholder that reaches the site is indistinguishable from a
    figure until somebody looks at it.
  * **It never burns callouts into the raster.** `call:` coordinates are normalised against the
    crop and are carried into the manifest for the site to render as SVG at port time (0165 D7), so
    rewording a callout never costs a re-shoot.
  * **It does not resize.** Roles carry the display width, and the site owns that. Rasterising a
    display size here would bake one page's layout into the binary.
"""

import argparse
import importlib.util
import json
import os
import re
import struct
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MASTER = (1206, 2622)

# Where a filed master might be. Same three the progress count scans, and for the same reason:
# a hand shot lands on the Desktop, a driven one in the repo, and both are equally real.
SOURCE_DIRS = [REPO / "shots" / "filed-partial",
               REPO / "shots" / "filed",
               Path.home() / "Desktop" / "manual-shots"]


def check_manual():
    """`check-manual.py` as a module — it owns the marker parse and keeps owning it.

    Same import as `shoot-progress.py`, for the same reason: a second regex over the same markers
    is a second thing to keep in step, and the one time this repo had two marker parsers they
    disagreed by three figures without either of them being obviously wrong.
    """
    spec = importlib.util.spec_from_file_location(
        "check_manual", REPO / "scripts" / "check-manual.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def markers():
    """Every marker on a published page, with all of its fields and the page it sits on."""
    cm = check_manual()
    found = []
    for path in cm.prose_pages():
        if os.path.abspath(path) == os.path.abspath(cm.SHOTS):
            continue
        page = os.path.splitext(os.path.basename(path))[0]
        for fields, line, _raw in cm.markers_in(cm.read(path)):
            fields = dict(fields)
            fields["page"] = page
            fields["line"] = line
            found.append(fields)
    if not found:
        sys.exit("build-figures: no markers found — is docs/manual/ populated?")
    return sorted(found, key=lambda f: f.get("slug", ""))


def png_size(path):
    """`(width, height)` from the IHDR, or `None` if this is not a readable PNG."""
    try:
        with open(path, "rb") as handle:
            head = handle.read(24)
        if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n":
            return None
        return struct.unpack(">II", head[16:24])
    except OSError:
        return None


def find_master(slug):
    """The filed master for a slug, or `None`. Slash becomes hyphen — the filing convention."""
    stem = slug.replace("/", "-")
    for directory in SOURCE_DIRS:
        candidate = directory / f"{stem}.png"
        if candidate.is_file():
            return candidate
    return None


def crop_to(source, dest, rect):
    """Write `source` cropped to `rect` (x,y,w,h in device pixels) at `dest`.

    `sips` rather than a library, because this repo has no Python image dependency and is not
    acquiring one for a crop — the same reasoning that keeps `check-manual.py` on the stdlib.
    Note the argument order: `sips -c` takes **height then width**, and `--cropOffset` takes
    **top then left**, which is the transpose of the `x,y,w,h` the marker records.
    """
    x, y, w, h = rect
    source_size = png_size(source)

    # **Bounds, before cropping, because the size check downstream cannot catch this.** `sips` given
    # a rect that runs off the frame does not fail and does not clamp — it returns an image of
    # exactly the size asked for, with the overhang padded. So the obvious verification, "is the
    # output w×h", passes on a figure that is part real and part padding, and passes loudest on the
    # rect that is most wrong. Only comparing the rect to the master catches it.
    if source_size and (x + w > source_size[0] or y + h > source_size[1]):
        return (f"rect {x},{y},{w},{h} runs off a {source_size[0]}×{source_size[1]} master "
                f"(needs {x + w}×{y + h}) — sips would pad the overhang and report success")

    dest.write_bytes(source.read_bytes())
    result = subprocess.run(
        ["sips", "-c", str(h), str(w), "--cropOffset", str(y), str(x), str(dest)],
        capture_output=True, text=True, check=False)
    if result.returncode != 0:
        return f"sips failed: {result.stderr.strip().splitlines()[-1:] or result.returncode}"
    got = png_size(dest)
    if got != (w, h):
        return f"cropped to {got}, expected {w}×{h}"
    return None


def parse_rect(text):
    if not re.match(r"^\d+,\d+,\d+,\d+$", text or ""):
        return None
    return tuple(int(n) for n in text.split(","))


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", default=str(REPO / "shots" / "figures"),
                        help="output directory (default: shots/figures/)")
    args = parser.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    for stale in out.iterdir():
        if stale.is_file():
            stale.unlink()

    built, missing, problems, entries = 0, [], [], []

    for fields in markers():
        slug = fields.get("slug", "")
        role = fields.get("role", "")
        rect = parse_rect(fields.get("crop", ""))
        master = find_master(slug)

        if master is None:
            missing.append((slug, fields.get("page", ""), bool(fields.get("device"))))
            continue

        source_size = png_size(master)
        dest = out / f"{slug.replace('/', '-')}.png"

        if rect:
            # A crop is recorded against the master, so a master that is not master-sized makes
            # every rect on it wrong — and silently, since the result is still a valid PNG.
            if source_size != MASTER:
                problems.append(f"{slug}: master is {source_size}, not {MASTER[0]}×{MASTER[1]} — "
                                "its crop rect cannot be trusted")
                continue
            failure = crop_to(master, dest, rect)
            if failure:
                problems.append(f"{slug}: {failure}")
                continue
        else:
            dest.write_bytes(master.read_bytes())

        built += 1
        entries.append({
            "slug": slug,
            "file": dest.name,
            "role": role,
            "page": fields.get("page", ""),
            "alt": fields.get("alt", ""),
            "state": fields.get("state", ""),
            # Carried, never rasterised: the site draws these as SVG over the image (0165 D7).
            "call": fields.get("call", ""),
            "crop": fields.get("crop", ""),
            "device": fields.get("device", ""),
            "size": list(png_size(dest) or ()),
            # Every master comes off a dark-appearance launch. `glyph`, `detail` and `panel` are
            # meant to ship theme-paired through `<picture>` (0165 D7); the light pass has never
            # been run, so the site has one variant to work with and should be told which.
            "theme": "dark",
        })

    manifest = {
        "generated_by": "scripts/build-figures.py",
        "master": list(MASTER),
        "figures": entries,
    }
    (out / "MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n")

    print(f"built {built} figure(s) into {out}")
    cropped = sum(1 for e in entries if e["crop"])
    print(f"  {cropped} cut from a crop rect, {built - cropped} whole frames")

    # A role is a promise about size. `glyph` is one control inline in a sentence, `detail` a small
    # cluster, `band` a horizontal stripe — none of them is a device. Without a `crop:` the figure
    # falls back to the whole master, which is not a smaller version of the right picture but a
    # different one, and it renders at whatever width the role asks for. The driven harness files
    # masters and never measures rects, so this gap is what a purely driven shoot leaves behind.
    # A turned device frame is exempt: it is already wider than it is tall, which is the shape a
    # `band` is asking for, so `song-player/landscape` wants no rect and flagging it would train
    # the reader to skim this list.
    uncropped = [e for e in entries
                 if e["role"] in {"glyph", "detail", "band"} and not e["crop"]
                 and not (len(e["size"]) == 2 and e["size"][0] > e["size"][1])]
    if uncropped:
        print(f"\n⚠️  {len(uncropped)} figure(s) whose role implies a crop but carry no rect — "
              "each will ship as a whole device frame:")
        for entry in sorted(uncropped, key=lambda e: (e["role"], e["slug"])):
            print(f"  {entry['role']:7s} {entry['slug']:32s} {entry['page']}")
        print("  Measure each against its master and write the rect into the marker's `crop:`.")

    if missing:
        print(f"\n{len(missing)} marker(s) with no master on disk:")
        for slug, page, device in sorted(missing):
            print(f"  {slug:34s} {page}{'  (needs a phone)' if device else ''}")

    if problems:
        print(f"\n{len(problems)} problem(s):")
        for line in problems:
            print("  " + line)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
