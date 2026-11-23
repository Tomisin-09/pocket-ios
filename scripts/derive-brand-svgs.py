#!/usr/bin/env python3
"""Derive the app's brand imagesets from the Pixelmator Pro logo lockup.

The designer ships **one** file per appearance — a full lockup (crescent + stars + "Red Moon"
wordmark) on a 3424² canvas. The app needs three assets at three different croppings:

    RedMoonLogo      the whole lockup            (Settings footer)
    RedMoonMark      crescent + stars, no text   (artist-name prompt)
    RedMoonWordmark  the text alone              (Home nav title)

Rather than hand-cropping three files per appearance in an editor and re-doing it on every logo
revision, this script derives them: it keeps the chosen `<path>` elements and rewrites the viewBox
to their exact bounding box (true cubic-bezier extrema, not the control-point hull, so the crop is
tight rather than merely close).

…and the **App Icon**, which is the same crescent-and-stars mark in the blood-moon colouring,
composited on an opaque near-black square. That one can't be vector: App Store icons must be a flat
1024² PNG with no alpha channel, so it is rasterised here rather than left to the asset catalog.

…and the **Now Playing artwork** (`DefaultArtwork`), the square the lock screen, Control Center and
the Dynamic Island show beside whatever Red Moon is playing (ADR 0303). Imported songs carry no cover
art, so it is the app's mark, and it is the App Icon's own render: the same pixels, written twice.
It used to be a hand-made PNG, which is how it stayed the July crescent through the vector art
(ADR 0126) and then stayed blue through the blood moon (ADR 0292). Cut here, it can't fall behind
the icon again.

    ./scripts/derive-brand-svgs.py                     # the blood moon art, into the asset catalog
    ./scripts/derive-brand-svgs.py --app-icon          # …and re-render the App Icon + Now Playing art
    ./scripts/derive-brand-svgs.py --variants light dark --out /tmp/blue  # the retired blue pair
    ./scripts/derive-brand-svgs.py --out /tmp/preview  # loose files, catalog untouched
    ./scripts/derive-brand-svgs.py --themes --app-icon # …and every moon theme's art and icon

**The moon themes (ADR 0311, 0312).** The wordmark, the logo, the mark and the App Icon follow the
theme the player picks, so `--themes` cuts each one again for the seven themes that aren't Blood
Moon: `RedMoonWordmarkHarvest`, `AppIconHarvest` and so on. They are the blood art **recoloured,
never redrawn**: its two reds are swapped for two tones computed here, in OKLCH, from the theme's own
Practice colour as `Colors.xcassets` holds it. Each tone keeps the blood red's lightness and moves to
the theme's hue, with its chroma scaled by how colourful that theme's Practice colour is next to
terracotta's. So Blood Moon itself comes out of the same sum unchanged (it is checked below), and a
catalog colour that moves takes the art with it on the next run.

**The brand is the blood moon (ADR 0292).** One lockup serves both appearances: its two reds read
on cream and on near-black alike, so each imageset holds a single universal SVG rather than the
light/dark pair the blue art needed (its colours inverted between appearances). The blue sources
are still named below, so the old pair can be cut again for reference; a catalog run removes the
SVGs it no longer writes, so a switch never leaves the previous art behind.

Source files live outside the repo (they're 300 KB Pixelmator documents alongside the SVGs);
point `--source` at wherever the current revision sits.

There used to be a fourth output, the raster "Red Moon PRO" wordmark for the paywall header,
cropped by its alpha channel. It went with the paywall (ADR 0237); git history has the code.
"""
import argparse
import json
import math
import os
import re
import shutil
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

# App Icon composition. The mark in its **blood-moon** colouring (ADR 0292; the blue dark-background
# colouring before it) on an opaque near-black square: `#0F0F0F` and a mark occupying 66.8% of the canvas height are both measured off the
# icon this replaced, so the swap is like-for-like on the home screen rather than a resize too.
APP_ICON_SIZE = 1024
APP_ICON_BACKGROUND = "#0F0F0F"
APP_ICON_MARK_HEIGHT_FRACTION = 0.668
APP_ICON_VARIANT = "blood"

# The moon themes (ADR 0311 D1, D4) other than Blood Moon → the asset-name suffix their art takes and
# the colour family their Practice wears. The suffix is `MoonTheme.assetSuffix` in Swift; the family
# is read from `Colors.xcassets`, so the art follows the catalog rather than a copy of its values.
THEMES = {
    "Blue": "Teal",
    "Jade": "Jade",
    "Corn": "Corn",
    "Silver": "Silver",
    "Pink": "Pink",
    "Harvest": "Harvest",
    "Cold": "Cold",
}
BLOOD_FAMILY = "Terracotta"
# The blood lockup's two reds, as the designer drew them: the crescent and wordmark, and the inner
# highlight. A theme's art is these two, recoloured.
BLOOD_TONES = ("#c24a2c", "#e3694a")

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

    The App Icon must have **no alpha channel** (App Store requirement); `alpha` is kept for any
    future raster asset that needs one.
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


def _srgb_to_linear(channel):
    channel /= 255
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


def _linear_to_srgb(channel):
    return 12.92 * channel if channel <= 0.0031308 else 1.055 * channel ** (1 / 2.4) - 0.055


def oklch(hex_colour):
    """`#rrggbb` → (L, C, h°) in OKLCH."""
    red, green, blue = (_srgb_to_linear(int(hex_colour.lstrip("#")[i:i + 2], 16)) for i in (0, 2, 4))
    lms = [0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue,
           0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue,
           0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue]
    lms = [v ** (1 / 3) if v >= 0 else -((-v) ** (1 / 3)) for v in lms]
    lightness = 0.2104542553 * lms[0] + 0.7936177850 * lms[1] - 0.0040720468 * lms[2]
    a_axis = 1.9779984951 * lms[0] - 2.4285922050 * lms[1] + 0.4505937099 * lms[2]
    b_axis = 0.0259040371 * lms[0] + 0.7827717662 * lms[1] - 0.8086757660 * lms[2]
    return lightness, math.hypot(a_axis, b_axis), math.degrees(math.atan2(b_axis, a_axis)) % 360


def _oklch_to_linear(lightness, chroma, hue):
    a_axis, b_axis = chroma * math.cos(math.radians(hue)), chroma * math.sin(math.radians(hue))
    lms = [lightness + 0.3963377774 * a_axis + 0.2158037573 * b_axis,
           lightness - 0.1055613458 * a_axis - 0.0638541728 * b_axis,
           lightness - 0.0894841775 * a_axis - 1.2914855480 * b_axis]
    lms = [v ** 3 for v in lms]
    return (4.0767416621 * lms[0] - 3.3077115913 * lms[1] + 0.2309699292 * lms[2],
            -1.2684380046 * lms[0] + 2.6097574011 * lms[1] - 0.3413193965 * lms[2],
            -0.0041960863 * lms[0] - 0.7034186147 * lms[1] + 1.7076147010 * lms[2])


def oklch_hex(lightness, chroma, hue):
    """OKLCH → `#RRGGBB`, giving up chroma (never lightness or hue) until it fits sRGB."""
    def fits(c):
        return all(-1e-4 <= v <= 1 + 1e-4 for v in _oklch_to_linear(lightness, c, hue))
    if not fits(chroma):
        low, high = 0.0, chroma
        for _ in range(40):
            mid = (low + high) / 2
            low, high = (mid, high) if fits(mid) else (low, mid)
        chroma = low
    channels = (_linear_to_srgb(min(1.0, max(0.0, v))) * 255
                for v in _oklch_to_linear(lightness, chroma, hue))
    return "#" + "".join(f"{max(0, min(255, round(v))):02X}" for v in channels)


def catalog_light_value(repo, family):
    """The light (Any Appearance) value of `family`'s base colour set, as `#RRGGBB`."""
    path = os.path.join(repo, "Pocket/Resources/Colors.xcassets", f"{family}.colorset", "Contents.json")
    with open(path, encoding="utf-8") as handle:
        colours = json.load(handle)["colors"]
    light = next(c for c in colours if "appearances" not in c)["color"]["components"]
    return "#" + "".join(light[k][2:].upper() for k in ("red", "green", "blue"))


def theme_tones(repo, family):
    """The two tones a theme's art wears in place of `BLOOD_TONES` (see the docstring)."""
    _, blood_chroma, blood_hue = oklch(catalog_light_value(repo, BLOOD_FAMILY))
    _, chroma, hue = oklch(catalog_light_value(repo, family))
    scale, turn = chroma / blood_chroma, hue - blood_hue
    tones = []
    for tone in BLOOD_TONES:
        tone_lightness, tone_chroma, tone_hue = oklch(tone)
        tones.append(oklch_hex(tone_lightness, tone_chroma * scale, (tone_hue + turn) % 360))
    return tuple(tones)


def recolour(svg, tones):
    """`svg` with the blood lockup's two reds swapped for `tones`, failing if either is missing."""
    for blood, tone in zip(BLOOD_TONES, tones):
        pattern = re.compile(re.escape(f'fill="{blood}"'), re.IGNORECASE)
        if not pattern.search(svg):
            raise SystemExit(f"the source lockup no longer fills with {blood}: recolouring would "
                             "leave the theme's art red")
        svg = pattern.sub(f'fill="{tone}"', svg)
    return svg


def contents_json(entries, vector=True):
    """An imageset Contents.json for `entries` — (filename, appearance-or-None) pairs.

    `preserves-vector-representation` is what makes the SVG scale instead of being flattened to a
    single raster at import: these are drawn from 22 pt (the Home wordmark) to 160 pt (Settings).
    A raster imageset passes `vector=False` rather than claiming a vector representation it hasn't
    got.
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
    parser.add_argument("--variants", nargs="+", default=["blood"],
                        choices=sorted(VARIANT_FILES), help="appearances to derive")
    parser.add_argument("--out", default=None,
                        help="write loose SVGs here instead of updating the asset catalog")
    parser.add_argument("--app-icon", action="store_true",
                        help="also re-render AppIcon/icon-1024.png and the Now Playing artwork "
                             "(DefaultArtwork/artwork-1024.png) from the brand mark")
    parser.add_argument("--themes", action="store_true",
                        help="also cut each moon theme's recoloured art (and, with --app-icon, its "
                             "alternate App Icon) into the catalog (ADR 0312)")
    args = parser.parse_args()
    if args.themes and args.out:
        raise SystemExit("--themes writes the catalog's theme imagesets; it doesn't take --out")
    if args.themes and APP_ICON_VARIANT not in args.variants:
        args.variants = list(args.variants) + [APP_ICON_VARIANT]
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
        if not args.out:
            # The catalog holds exactly what this run writes: Contents.json is rewritten below, and
            # an SVG left from a previous variant set would sit in the bundle unreferenced.
            for stale in os.listdir(target):
                if stale.endswith(".svg"):
                    os.remove(os.path.join(target, stale))
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
        # The Now Playing artwork is the icon's render, copied rather than drawn again, so the two
        # can't differ by so much as a renderer's rounding.
        artwork = os.path.join(args.out or os.path.join(catalog, "DefaultArtwork.imageset"),
                               "artwork-1024.png")
        shutil.copyfile(icon, artwork)
        print(f"  {os.path.relpath(artwork)}  (the App Icon's render)")

    if args.themes:
        # Blood Moon run through the same sum must come back as its own two reds, or the rule that
        # cuts the other seven isn't the rule the brand was drawn with.
        if tuple(t.lower() for t in theme_tones(repo, BLOOD_FAMILY)) != BLOOD_TONES:
            raise SystemExit(f"Blood Moon's tones came out {theme_tones(repo, BLOOD_FAMILY)}, "
                             f"not {BLOOD_TONES}: the recolouring rule has drifted")
        blood = sources[APP_ICON_VARIANT]
        for suffix, family in THEMES.items():
            tones = theme_tones(repo, family)
            themed = recolour(blood, tones)
            print(f"  {suffix}: {tones[0]} · {tones[1]} (from {family})")
            for asset, (path_ids, imageset) in ASSETS.items():
                target = os.path.join(catalog, f"{imageset}{suffix}.imageset")
                if os.path.isdir(target):
                    shutil.rmtree(target)
                os.makedirs(target)
                filename = f"{asset}-{suffix.lower()}.svg"
                with open(os.path.join(target, filename), "w", encoding="utf-8") as handle:
                    handle.write(crop(themed, path_ids))
                with open(os.path.join(target, "Contents.json"), "w", encoding="utf-8") as handle:
                    handle.write(contents_json([(filename, None)]))
            if args.app_icon:
                target = os.path.join(catalog, f"AppIcon{suffix}.appiconset")
                os.makedirs(target, exist_ok=True)
                build_app_icon(themed, os.path.join(target, "icon-1024.png"))
                shutil.copyfile(os.path.join(catalog, "AppIcon.appiconset", "Contents.json"),
                                os.path.join(target, "Contents.json"))

    return 0


if __name__ == "__main__":
    sys.exit(main())
