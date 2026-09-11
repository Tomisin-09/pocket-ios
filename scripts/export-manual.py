#!/usr/bin/env python3
"""Copy the user manual into the site checkout that renders it (ADR 0217).

    ./scripts/export-manual.py ~/Documents/laundry-pickup-project
    ./scripts/export-manual.py SITE --figures reviewed.txt    # and publish these figures

The markdown here is the source; the site renders a copy of it at `/redmoon/manual/<slug>`
(ADR 0165 D1). This script is the one thing that writes that copy:

- `content/manual/` is replaced wholesale with the published pages: every page under
  `docs/manual/` except `README.md` (guidance for whoever writes here) and `shots.md` (the shoot's
  manifest).
- `content/manual/index.json` carries the page order and grouping, parsed from the `| Page |`
  tables under *The pages* in `docs/manual/README.md` — the order lives there and nowhere else. A
  page on disk the README does not list, or a listed page with no file, stops the export.
- With `--figures FILE` (one slug per line, `#` comments allowed), `public/redmoon/manual/` is made
  to hold exactly those figures, taken from `shots/figures/` and narrowed to 640px wide. **A figure
  is published by being on that list**, so the list holds only figures somebody has compared against
  the current app. Without `--figures` the directory is left exactly as it is.

It runs `check-manual.py` first and will not export a manual that fails it. It commits nothing and
pushes nothing, in either repo: `uk-site` deploys to production on every push, so going live stays a
deliberate step.
"""

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MANUAL = REPO / "docs" / "manual"
FIGURES = REPO / "shots" / "figures"
UNPUBLISHED = {"README.md", "shots.md"}
# The site's existing screenshot width, and twice the widest role it displays (`screen`, 300px).
FIGURE_WIDTH = 640


def key_for(rel: str) -> str:
    """`looping.md` → `looping`, `reference/README.md` → `reference` — the site's route key."""
    return re.sub(r"(^|/)README$", "", rel.removesuffix(".md"))


def published_pages() -> list[Path]:
    return sorted(p for p in MANUAL.rglob("*.md")
                  if p.relative_to(MANUAL).as_posix() not in UNPUBLISHED)


def plain(cell: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"[`*]", "", cell)).strip()


def read_index() -> list[dict]:
    """Groups and pages, in README order.

    A group is the bold line above a table (`**Start here**`), or the `###` heading when a table
    has none (the reference wing). Only rows of tables headed `| Page |` count, so the shoot tables
    further down the same section, whose rows also open with a backticked slug, are never read.
    """
    groups: list[dict] = []
    in_pages = in_table = False
    heading = group = None
    for line in (MANUAL / "README.md").read_text().splitlines():
        if line.startswith("## "):
            in_pages = line.strip() == "## The pages"
            continue
        if not in_pages:
            continue
        if line.startswith("### "):
            heading, group = line[4:].strip(), None
            continue
        bold = re.fullmatch(r"\*\*(.+)\*\*", line.strip())
        if bold:
            group = bold.group(1)
            continue
        if line.startswith("| Page |"):
            in_table = True
            continue
        if not line.startswith("|"):
            in_table = False
            continue
        row = re.match(r"\|\s*`([^`]+)`\s*\|([^|]*)\|", line)
        if not (in_table and row):
            continue
        slug, goal = row.group(1), plain(row.group(2))
        if f"{slug}.md" in UNPUBLISHED:
            continue
        title = group or heading
        if not groups or groups[-1]["title"] != title:
            groups.append({"title": title, "pages": []})
        groups[-1]["pages"].append({"key": key_for(f"{slug}.md"), "goal": goal})
    return groups


def pixel_width(image: Path) -> int:
    out = subprocess.run(["sips", "-g", "pixelWidth", str(image)],
                         capture_output=True, text=True, check=True).stdout
    return int(re.search(r"pixelWidth: (\d+)", out).group(1))


def publish_figures(site: Path, listing: Path) -> None:
    slugs = [line.split("#")[0].strip() for line in listing.read_text().splitlines()]
    slugs = [s for s in slugs if s]
    out = site / "public" / "redmoon" / "manual"
    missing = [s for s in slugs if not (FIGURES / f"{s.replace('/', '-')}.png").is_file()]
    if missing:
        sys.exit("export-manual: listed but not in shots/figures/ (run build-figures.py): "
                 + ", ".join(missing))
    out.mkdir(parents=True, exist_ok=True)
    wanted = set()
    for slug in slugs:
        name = f"{slug.replace('/', '-')}.png"
        source = FIGURES / name
        # Never widen: a `glyph` crop is a few dozen pixels, and resampling it up to 640 would
        # publish a blur at the size the role was meant to prevent.
        if pixel_width(source) > FIGURE_WIDTH:
            subprocess.run(["sips", "--resampleWidth", str(FIGURE_WIDTH), str(source),
                            "--out", str(out / name)], capture_output=True, check=True)
        else:
            shutil.copyfile(source, out / name)
        wanted.add(name)
    removed = [p.name for p in out.glob("*.png") if p.name not in wanted]
    for name in removed:
        (out / name).unlink()
    print(f"figures: {len(wanted)} published" + (f", {len(removed)} withdrawn: {', '.join(removed)}"
                                                 if removed else ""))


def git(*args: str) -> str:
    return subprocess.run(["git", *args], cwd=REPO, capture_output=True, text=True).stdout.strip()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("site", type=Path, help="the site checkout (laundry-pickup-project)")
    parser.add_argument("--figures", type=Path, help="file listing the reviewed figure slugs")
    args = parser.parse_args()

    site = args.site.expanduser().resolve()
    if not (site / "package.json").is_file() or not (site / "app" / "redmoon").is_dir():
        sys.exit(f"export-manual: {site} is not the site checkout (no package.json + app/redmoon/)")

    check = subprocess.run([sys.executable, str(REPO / "scripts" / "check-manual.py")],
                           cwd=REPO, capture_output=True, text=True)
    if check.returncode != 0:
        sys.stdout.write(check.stdout + check.stderr)
        sys.exit("export-manual: check-manual.py fails — fix the manual before exporting it")

    pages = published_pages()
    groups = read_index()
    listed = [p["key"] for g in groups for p in g["pages"]]
    on_disk = {key_for(p.relative_to(MANUAL).as_posix()) for p in pages}
    if set(listed) != on_disk or len(listed) != len(set(listed)):
        sys.exit("export-manual: docs/manual/README.md's page tables and the files disagree\n"
                 f"  not listed: {sorted(on_disk - set(listed))}\n"
                 f"  no file:    {sorted(set(listed) - on_disk)}\n"
                 f"  listed twice: {sorted({k for k in listed if listed.count(k) > 1})}")

    dest = site / "content" / "manual"
    if dest.exists():
        shutil.rmtree(dest)
    for page in pages:
        target = dest / page.relative_to(MANUAL)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(page, target)

    dirty = bool(git("status", "--porcelain", "--", "docs/manual"))
    index = {
        "generated_by": "pocket-ios scripts/export-manual.py — do not edit; re-export instead",
        "source": {"commit": git("rev-parse", "HEAD"), "uncommitted_changes": dirty},
        "groups": groups,
    }
    (dest / "index.json").write_text(json.dumps(index, indent=2, ensure_ascii=False) + "\n")
    print(f"pages: {len(pages)} copied to {dest.relative_to(site)}/ "
          f"({len(groups)} groups, from {index['source']['commit'][:7]})")
    if dirty:
        print("warning: docs/manual/ has uncommitted changes — the export is ahead of any commit")

    if args.figures:
        publish_figures(site, args.figures)


if __name__ == "__main__":
    main()
