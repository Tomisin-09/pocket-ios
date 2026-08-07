#!/usr/bin/env python3
"""Derive the app's brand imagesets from the Pixelmator Pro logo lockup.

The designer ships **one** file per appearance — a full lockup (crescent + stars + "Red Moon"
wordmark) on a 3424² canvas. The app needs three assets at three different croppings:

    RedMoonLogo      the whole lockup            (Settings footer)
    RedMoonMark      crescent + stars, no text   (paywall header, artist-name prompt)
    RedMoonWordmark  the text alone              (Home nav title)

Rather than hand-cropping three files per appearance in an editor and re-doing it on every logo
revision, this script derives them: it keeps the chosen `<path>` elements and rewrites the viewBox
to their exact bounding box (true cubic-bezier extrema, not the control-point hull, so the crop is
tight rather than merely close).

…and the **App Icon**, which is the same crescent-and-stars mark in its dark-background colouring,
composited on an opaque near-black square. That one can't be vector: App Store icons must be a flat
1024² PNG with no alpha channel, so it is rasterised here rather than left to the asset catalog.

…and the **Pro wordmark** — "Red Moon PRO", the paywall header's lockup. That one is the odd one
out: the designer ships it as a *raster* export rather than a lockup SVG, so there are no path ids
to crop by. It is cropped by its **alpha channel** instead — tight to the ink, then area-resampled
down to a sane intrinsic size — which is the same idea reached through a different door, and keeps
it re-runnable rather than something hand-trimmed in an editor on every logo revision.

    ./scripts/derive-brand-svgs.py                     # light + dark, into the asset catalog
    ./scripts/derive-brand-svgs.py --app-icon          # …and re-render AppIcon/icon-1024.png
    ./scripts/derive-brand-svgs.py --pro-wordmark      # …and re-crop RedMoonProWordmark
    ./scripts/derive-brand-svgs.py --variants blood    # the Blood Moon theme's artwork
    ./scripts/derive-brand-svgs.py --out /tmp/preview  # loose files, catalog untouched

`--variants blood` is the seam for the parked Blood Moon theme (see `docs/backlog.md`): the
artwork already exists, it just has no consumer yet, so it is deliberately **not** in the catalog.
Adding it is this one command plus the imageset entries.

Source files live outside the repo (they're 300 KB Pixelmator documents alongside the SVGs);
point `--source` at wherever the current revision sits. The Pro wordmark PNGs sit in their own
folder (`--pro-source`) because they arrived as a loose pair, not as a versioned lockup set.
"""
import argparse
import json
import os
import re
import struct
import subprocess
import sys
import tempfile
import zlib

DEFAULT_SOURCE = os.path.expanduser("~/Documents/Red Moon Simplified Logo v5 files")

# Appearance → the source lockup's filename, relative to `--source`.
VARIANT_FILES = {
    "light": "Light Backgrounds/red_moon_logo_transparent_for_light_backgrounds.svg",
    "dark": "Dark Backgrounds/red_moon_logo_transparent_for_dark_backgrounds.svg",
    "blood": "Blood Moon/red_moon_logo_transparent_for_blood_moon.svg",
}

# Asset → (the lockup paths it keeps, its imageset). The ids are the designer's layer names.
ASSETS = {
    "logo": (["Oval", "Oval-copy", "Star", "Red-Moon"], "RedMoonLogo"),
    "mark": (["Oval", "Oval-copy", "Star"], "RedMoonMark"),
    "wordmark": (["Red-Moon"], "RedMoonWordmark"),
}

# The longest side of each emitted SVG, in points. The assets are always drawn `.resizable()`, so
# this only sets the intrinsic size — big enough that a catalog fallback raster is still crisp,
# small enough to be a sane default if one is ever drawn unsized.
INTRINSIC_MAX_POINTS = 512.0

# App Icon composition. The mark in its **dark-background** colouring on an opaque near-black
# square: `#0F0F0F` and a mark occupying 66.8% of the canvas height are both measured off the
# icon this replaced, so the swap is like-for-like on the home screen rather than a resize too.
APP_ICON_SIZE = 1024
APP_ICON_BACKGROUND = "#0F0F0F"
APP_ICON_MARK_HEIGHT_FRACTION = 0.668
APP_ICON_VARIANT = "dark"

# The Pro wordmark. Raster in, raster out — see the module docstring for why this one can't be
# derived from path ids like the rest.
PRO_WORDMARK_SOURCE = os.path.expanduser("~/Documents")
PRO_WORDMARK_FILES = {
    "light": "red_moon_logo_pro_wordmark_for_light_backgrounds.png",
    "dark": "red_moon_logo_pro_wordmark_for_dark_backgrounds.png",
}
PRO_WORDMARK_IMAGESET = "RedMoonProWordmark"

# Alpha at or below this is background, not ink. The export is anti-aliased, so an exactly-zero
# test would keep a halo of near-invisible pixels and crop several points wider than the glyphs.
PRO_WORDMARK_ALPHA_FLOOR = 8

# Longest side of the emitted PNG, in pixels. The asset is single-scale (like DefaultArtwork), so
# this is also its intrinsic size in points — irrelevant in practice, because the paywall draws it
# `.resizable()` inside an explicit frame. It is set by the *rendered* size instead: ~300 pt wide
# at @3x is 900 px, and 1024 clears that with room to spare while keeping the file small.
PRO_WORDMARK_MAX_PIXELS = 1024


def parse_path(data):
    """Split an absolute-coordinate path into ('P'|'L'|'C', points) segments.

    Pixelmator Pro emits only absolute M/L/C/Z, which is all this handles — anything else raises
    rather than silently mis-measuring the bounding box.
    """
    tokens = re.findall(r'[A-Za-z]|-?\d*\.?\d+(?:[eE][-+]?\d+)?', data)
    cur = start = (0.0, 0.0)
    segs = []
    cmd = None
    idx = 0
    while idx < len(tokens):
        if re.match(r'[A-Za-z]', tokens[idx]):
            cmd = tokens[idx]
            idx += 1
            if cmd in 'Zz':
                segs.append(('L', [cur, start]))
                cur = start
                continue
        if cmd is None or cmd.upper() not in ('M', 'L', 'C'):
            raise ValueError(f"unsupported path command {cmd!r} — expected absolute M/L/C/Z")
        need = {'M': 2, 'L': 2, 'C': 6}[cmd.upper()]
        nums = [float(tokens[idx + i]) for i in range(need)]
        idx += need
        if cmd == 'M':
            cur = start = (nums[0], nums[1])
            segs.append(('P', [cur]))
        elif cmd == 'L':
            nxt = (nums[0], nums[1])
            segs.append(('L', [cur, nxt]))
            cur = nxt
        else:
            pts = [cur, (nums[0], nums[1]), (nums[2], nums[3]), (nums[4], nums[5])]
            segs.append(('C', pts))
            cur = pts[3]
    return segs


def cubic_extrema(pt0, pt1, pt2, pt3):
    """Parameters in [0, 1] where a cubic's derivative vanishes, per axis, plus the endpoints."""
    params = [0.0, 1.0]
    for axis in (0, 1):
        cua = -pt0[axis] + 3 * pt1[axis] - 3 * pt2[axis] + pt3[axis]
        cub = 2 * (pt0[axis] - 2 * pt1[axis] + pt2[axis])
        cuc = -pt0[axis] + pt1[axis]
        if abs(cua) < 1e-12:
            if abs(cub) > 1e-12:
                params.append(-cuc / cub)
        else:
            disc = cub * cub - 4 * cua * cuc
            if disc >= 0:
                root = disc ** 0.5
                params += [(-cub + root) / (2 * cua), (-cub - root) / (2 * cua)]
    return [t for t in params if 0.0 <= t <= 1.0]


def cubic_at(pts, param):
    """The point on a cubic at `param`."""
    pt0, pt1, pt2, pt3 = pts
    inv = 1 - param
    return tuple(inv ** 3 * pt0[i] + 3 * inv ** 2 * param * pt1[i]
                 + 3 * inv * param ** 2 * pt2[i] + param ** 3 * pt3[i] for i in (0, 1))


def bounding_box(path_data):
    """The exact bounding box of a list of path `d` strings."""
    xs, ys = [], []
    for data in path_data:
        for kind, pts in parse_path(data):
            samples = pts if kind in ('P', 'L') else [cubic_at(pts, t) for t in cubic_extrema(*pts)]
            for x, y in samples:
                xs.append(x)
                ys.append(y)
    return min(xs), min(ys), max(xs), max(ys)


def crop(source_svg, path_ids):
    """Return an SVG holding only `path_ids`, viewBox cropped tight to them."""
    blocks = {}
    order = []
    for match in re.finditer(r'<path id="([^"]+)"[^>]*/>', source_svg):
        blocks[match.group(1)] = match.group(0)
        order.append(match.group(1))
    missing = [i for i in path_ids if i not in blocks]
    if missing:
        raise SystemExit(f"source is missing path id(s) {missing} — layer names changed?")
    keep = [i for i in order if i in path_ids]
    left, top, right, bottom = bounding_box(
        [re.search(r'\sd="([^"]+)"', blocks[i]).group(1) for i in keep])
    width, height = right - left, bottom - top
    scale = INTRINSIC_MAX_POINTS / max(width, height)
    body = "\n        ".join(blocks[i] for i in keep)
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<!-- Generated by scripts/derive-brand-svgs.py from the Pixelmator Pro lockup.\n'
        '     Do not hand-edit: re-run the script against a new logo revision instead. -->\n'
        f'<svg width="{width * scale:.2f}" height="{height * scale:.2f}"'
        f' viewBox="{left:.4f} {top:.4f} {width:.4f} {height:.4f}"'
        ' xmlns="http://www.w3.org/2000/svg">\n'
        '    <g>\n'
        f'        {body}\n'
        '    </g>\n'
        '</svg>\n'
    )


def compose_app_icon_svg(source_svg, path_ids):
    """Return a square SVG: the mark centred on an opaque background, ready to rasterise."""
    blocks = {m.group(1): m.group(0)
              for m in re.finditer(r'<path id="([^"]+)"[^>]*/>', source_svg)}
    keep = [i for i in path_ids if i in blocks]
    if len(keep) != len(path_ids):
        raise SystemExit(f"source is missing path id(s) {set(path_ids) - set(keep)}")
    left, top, right, bottom = bounding_box(
        [re.search(r'\sd="([^"]+)"', blocks[i]).group(1) for i in keep])
    scale = APP_ICON_SIZE * APP_ICON_MARK_HEIGHT_FRACTION / (bottom - top)
    off_x = APP_ICON_SIZE / 2 - scale * (left + right) / 2
    off_y = APP_ICON_SIZE / 2 - scale * (top + bottom) / 2
    body = "\n            ".join(blocks[i] for i in keep)
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg width="{APP_ICON_SIZE}" height="{APP_ICON_SIZE}"'
        f' viewBox="0 0 {APP_ICON_SIZE} {APP_ICON_SIZE}" xmlns="http://www.w3.org/2000/svg">\n'
        f'    <rect x="0" y="0" width="{APP_ICON_SIZE}" height="{APP_ICON_SIZE}"'
        f' fill="{APP_ICON_BACKGROUND}"/>\n'
        f'    <g transform="translate({off_x:.4f} {off_y:.4f}) scale({scale:.6f})">\n'
        f'            {body}\n'
        '    </g>\n'
        '</svg>\n'
    )


def read_png(path):
    """Decode an 8-bit RGB/RGBA PNG to (width, height, bytes-per-pixel, unfiltered rows)."""
    data = open(path, 'rb').read()
    pos, idat, header = 8, b'', None
    while pos < len(data):
        length, kind = struct.unpack('>I4s', data[pos:pos + 8])
        payload = data[pos + 8:pos + 8 + length]
        if kind == b'IHDR':
            header = struct.unpack('>IIBBBBB', payload)
        elif kind == b'IDAT':
            idat += payload
        pos += 12 + length
    width, height, depth, colour = header[0], header[1], header[2], header[3]
    if depth != 8 or colour not in (2, 6):
        raise SystemExit(f"unexpected PNG format from the renderer (depth {depth}, type {colour})")
    bpp = 3 if colour == 2 else 4
    stride = width * bpp
    raw = zlib.decompress(idat)
    rows, prev, idx = [], bytearray(stride), 0
    for _ in range(height):
        kind = raw[idx]
        line = bytearray(raw[idx + 1:idx + 1 + stride])
        idx += 1 + stride
        for pos in range(stride):
            left = line[pos - bpp] if pos >= bpp else 0
            up = prev[pos]
            upleft = prev[pos - bpp] if pos >= bpp else 0
            if kind == 1:
                line[pos] = (line[pos] + left) & 255
            elif kind == 2:
                line[pos] = (line[pos] + up) & 255
            elif kind == 3:
                line[pos] = (line[pos] + (left + up) // 2) & 255
            elif kind == 4:
                est = left + up - upleft
                dl, du, dul = abs(est - left), abs(est - up), abs(est - upleft)
                nearest = left if (dl <= du and dl <= dul) else (up if du <= dul else upleft)
                line[pos] = (line[pos] + nearest) & 255
        prev = line
        rows.append(bytes(line))
    return width, height, bpp, rows


def write_png(path, width, height, rows, alpha=False):
    """Write 8-bit rows as a PNG — RGB by default, RGBA when `alpha`.

    The App Icon must have **no alpha channel** (App Store requirement), the Pro wordmark must
    keep one (it sits on the paywall's own background), hence the switch.
    """
    def chunk(kind, payload):
        return (struct.pack('>I', len(payload)) + kind + payload
                + struct.pack('>I', zlib.crc32(kind + payload) & 0xffffffff))

    body = b''.join(b'\x00' + row for row in rows)      # filter type 0 on every scanline
    with open(path, 'wb') as handle:
        handle.write(b'\x89PNG\r\n\x1a\n'
                     + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8,
                                                  6 if alpha else 2, 0, 0, 0))
                     + chunk(b'IDAT', zlib.compress(body, 9))
                     + chunk(b'IEND', b''))


def build_app_icon(source_svg, destination):
    """Rasterise the composed icon and write it as an opaque RGB PNG.

    Rendering goes through QuickLook (`qlmanage`), which is why there's no ImageMagick/librsvg
    dependency to install — but it hands back RGBA. The composed SVG's background rect covers the
    whole canvas, so every pixel is already fully opaque; this asserts that before dropping the
    channel, rather than trusting it, because a partly-transparent icon is an App Store rejection
    and the renderer is the part of this pipeline we don't control.
    """
    with tempfile.TemporaryDirectory() as work:
        svg_path = os.path.join(work, "app-icon.svg")
        with open(svg_path, "w", encoding="utf-8") as handle:
            handle.write(compose_app_icon_svg(source_svg, ASSETS["mark"][0]))
        subprocess.run(["qlmanage", "-t", "-s", str(APP_ICON_SIZE), "-o", work, svg_path],
                       check=True, capture_output=True)
        rendered = os.path.join(work, "app-icon.svg.png")
        if not os.path.exists(rendered):
            raise SystemExit("qlmanage produced no thumbnail — can it read the composed SVG?")
        width, height, bpp, rows = read_png(rendered)

    if (width, height) != (APP_ICON_SIZE, APP_ICON_SIZE):
        raise SystemExit(f"renderer returned {width}×{height}, expected {APP_ICON_SIZE}²")
    if bpp == 4:
        opaque = all(row[x * 4 + 3] == 255 for row in rows for x in range(0, width, 8))
        if not opaque:
            raise SystemExit("rendered icon has transparent pixels — the background rect didn't "
                             "cover the canvas; App Store icons must be fully opaque")
        rows = [bytes(b for x in range(width) for b in row[x * 4:x * 4 + 3]) for row in rows]
    write_png(destination, width, height, rows)
    print(f"  {os.path.relpath(destination)}  {width}×{height}, no alpha")


def alpha_bounds(width, rows):
    """The tightest (left, top, right, bottom) box holding every pixel with real ink in it."""
    left, top, right, bottom = width, len(rows), -1, -1
    for y, row in enumerate(rows):
        inked = [x for x in range(width) if row[x * 4 + 3] > PRO_WORDMARK_ALPHA_FLOOR]
        if not inked:
            continue
        left, right = min(left, inked[0]), max(right, inked[-1])
        top, bottom = min(top, y), y
    if right < 0:
        raise SystemExit("source PNG is entirely transparent — is it the right export?")
    return left, top, right, bottom


def resample_rgba(rows, box, target_width, target_height):
    """Area-average `box` of `rows` down to the target size, returning RGBA rows.

    Averaging happens on **premultiplied** colour. Straight averaging would pull the transparent
    pixels' RGB (which the exporter leaves at black) into every edge sample and ring the glyphs
    with a dark fringe — invisible against white, obvious against the paywall's cream.
    """
    left, top, right, bottom = box
    src_w, src_h = right - left + 1, bottom - top + 1
    out = []
    for ty in range(target_height):
        y0, y1 = top + ty * src_h // target_height, top + (ty + 1) * src_h // target_height
        line = bytearray(target_width * 4)
        for tx in range(target_width):
            x0, x1 = left + tx * src_w // target_width, left + (tx + 1) * src_w // target_width
            acc_a = acc_r = acc_g = acc_b = count = 0
            for y in range(y0, max(y1, y0 + 1)):
                row = rows[y]
                for x in range(x0, max(x1, x0 + 1)):
                    alpha = row[x * 4 + 3]
                    acc_a += alpha
                    acc_r += row[x * 4] * alpha
                    acc_g += row[x * 4 + 1] * alpha
                    acc_b += row[x * 4 + 2] * alpha
                    count += 1
            out_a = acc_a // count
            base = tx * 4
            if acc_a:
                line[base] = min(255, acc_r // acc_a)
                line[base + 1] = min(255, acc_g // acc_a)
                line[base + 2] = min(255, acc_b // acc_a)
            line[base + 3] = out_a
        out.append(bytes(line))
    return out


def build_pro_wordmark(source_folder, target, variants):
    """Crop each Pro-wordmark export to its ink and write the imageset."""
    entries = []
    os.makedirs(target, exist_ok=True)
    for variant in variants:
        if variant not in PRO_WORDMARK_FILES:
            continue
        path = os.path.join(source_folder, PRO_WORDMARK_FILES[variant])
        if not os.path.exists(path):
            raise SystemExit(f"no Pro wordmark export at {path}\n"
                             "pass --pro-source pointing at the folder holding the pair")
        width, _, bpp, rows = read_png(path)
        if bpp != 4:
            raise SystemExit(f"{path} has no alpha channel — the crop has nothing to measure")
        box = alpha_bounds(width, rows)
        src_w, src_h = box[2] - box[0] + 1, box[3] - box[1] + 1
        scale = min(1.0, PRO_WORDMARK_MAX_PIXELS / max(src_w, src_h))
        out_w, out_h = max(1, round(src_w * scale)), max(1, round(src_h * scale))
        filename = f"pro-wordmark-{variant}.png"
        write_png(os.path.join(target, filename), out_w, out_h,
                  resample_rgba(rows, box, out_w, out_h), alpha=True)
        entries.append((filename, "dark" if variant == "dark" else None))
        print(f"  {PRO_WORDMARK_IMAGESET}/{filename}  {src_w}×{src_h} → {out_w}×{out_h}")
    return entries


def contents_json(entries, vector=True):
    """An imageset Contents.json for `entries` — (filename, appearance-or-None) pairs.

    `preserves-vector-representation` is what makes the SVG scale instead of being flattened to a
    single raster at import: these are drawn from 22 pt (the Home wordmark) to 160 pt (Settings).
    It is meaningless on the raster Pro wordmark, so that one passes `vector=False` rather than
    claiming a vector representation it hasn't got.
    """
    images = []
    for filename, appearance in entries:
        image = {"filename": filename, "idiom": "universal"}
        if appearance:
            image["appearances"] = [{"appearance": "luminosity", "value": appearance}]
        images.append(image)
    body = {"images": images, "info": {"author": "xcode", "version": 1}}
    if vector:
        body["properties"] = {"preserves-vector-representation": True}
    return json.dumps(body, indent=2) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--source", default=DEFAULT_SOURCE,
                        help="folder holding the Pixelmator lockup SVGs")
    parser.add_argument("--variants", nargs="+", default=["light", "dark"],
                        choices=sorted(VARIANT_FILES), help="appearances to derive")
    parser.add_argument("--out", default=None,
                        help="write loose SVGs here instead of updating the asset catalog")
    parser.add_argument("--app-icon", action="store_true",
                        help="also re-render AppIcon/icon-1024.png from the dark mark")
    parser.add_argument("--pro-wordmark", action="store_true",
                        help=f"also re-crop {PRO_WORDMARK_IMAGESET} from the Pro wordmark PNGs")
    parser.add_argument("--pro-source", default=PRO_WORDMARK_SOURCE,
                        help="folder holding the Pro wordmark PNG exports")
    args = parser.parse_args()
    if args.app_icon and APP_ICON_VARIANT not in args.variants:
        args.variants = list(args.variants) + [APP_ICON_VARIANT]

    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    catalog = os.path.join(repo, "Pocket/Resources/Assets.xcassets")

    sources = {}
    for variant in args.variants:
        path = os.path.join(args.source, VARIANT_FILES[variant])
        if not os.path.exists(path):
            raise SystemExit(f"no source lockup at {path}\n"
                             "pass --source pointing at the current logo revision")
        with open(path, encoding="utf-8") as handle:
            sources[variant] = handle.read()

    for asset, (path_ids, imageset) in ASSETS.items():
        entries = []
        target = args.out or os.path.join(catalog, f"{imageset}.imageset")
        os.makedirs(target, exist_ok=True)
        for variant in args.variants:
            filename = f"{asset}-{variant}.svg"
            with open(os.path.join(target, filename), "w", encoding="utf-8") as handle:
                handle.write(crop(sources[variant], path_ids))
            entries.append((filename, "dark" if variant == "dark" else None))
            print(f"  {imageset}/{filename}")
        if not args.out:
            with open(os.path.join(target, "Contents.json"), "w", encoding="utf-8") as handle:
                handle.write(contents_json(entries))

    if args.app_icon:
        icon = os.path.join(args.out or os.path.join(catalog, "AppIcon.appiconset"),
                            "icon-1024.png")
        os.makedirs(os.path.dirname(icon), exist_ok=True)
        build_app_icon(sources[APP_ICON_VARIANT], icon)

    if args.pro_wordmark:
        target = args.out or os.path.join(catalog, f"{PRO_WORDMARK_IMAGESET}.imageset")
        entries = build_pro_wordmark(args.pro_source, target, args.variants)
        if not args.out:
            with open(os.path.join(target, "Contents.json"), "w", encoding="utf-8") as handle:
                handle.write(contents_json(entries, vector=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
