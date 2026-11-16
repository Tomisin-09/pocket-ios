#!/usr/bin/env swift
// Draw the App Store's product page header and search-result artwork (iOS 27 and later) from the
// designer's lockup.
//
//     swift scripts/appstore-headers.swift <lockup.svg> <out-dir> [--guides]
//
// Writes `header.png` (3840×1646, 21:9) and `search.png` (3840×2560, 3:2, the largest Apple takes)
// into `<out-dir>`. Both sizes and both safe areas are Apple's, from *Creative assets specifications*
// in App Store Connect Help, read 2026-11-16:
//
//     header   3840×1646, keep critical elements inside 1646×661 at (1097, 493)
//     search   1920×1280 up to 3840×2560, safe area 2168×1030 at (836, 765)
//
// The lockup is centred in that safe area; the ground and the glow run edge to edge, because Apple
// asks for the atmosphere to fill the canvas and only the critical art to stay central. `--guides`
// also writes `*-guides.png` with the safe area outlined, for checking, never for upload.
//
// The look is the screenshots' (`scripts/appstore-frames.swift`): the app's near-black (`#040404`)
// with a faint terracotta (`#E07E57`) glow, so the header, the search art and the ten frames read as
// one set. The lockup's colours are the designer's, untouched.
//
// **The lockup is drawn as vectors, in two halves.** Its shapes go through `NSImage`, which reads SVG
// as `_NSSVGImageRep`, so nothing is resampled however large it lands. Its **live `<text>`** does not:
// the Nov 2026 lockups set "PRACTICE STUDIO" as text (Futura, italic, weight 500), not outlines, and
// AppKit's SVG renderer drops `font-style="italic"`, drawing it upright beside an italic "Red Moon".
// So each `<text>` is cut out of the SVG and set here with Core Text in the face it names, and a face
// that doesn't resolve to what was asked for (family, weight, italic) stops the run rather than
// quietly substituting.
//
// Frames are written with **no alpha channel**: Apple's spec says these images can't include alpha
// channels or transparencies.

import AppKit
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Placement {
    let name: String
    let width: Int
    let height: Int
    let safe: CGRect          // Apple's safe area, in pixels from the top left
}

let placements = [
    Placement(name: "header", width: 3840, height: 1646,
              safe: CGRect(x: 1097, y: 493, width: 1646, height: 661)),
    Placement(name: "search", width: 3840, height: 2560,
              safe: CGRect(x: 836, y: 765, width: 2168, height: 1030))
]

let background = NSColor(srgbRed: 4 / 255, green: 4 / 255, blue: 4 / 255, alpha: 1)
let terracotta = NSColor(srgbRed: 0xE0 / 255, green: 0x7E / 255, blue: 0x57 / 255, alpha: 1)

/// How much of the safe area the lockup may take, so it never touches the boundary.
let fillWidth: CGFloat = 0.88
let fillHeight: CGFloat = 0.80

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

// MARK: - The lockup

/// One `<text>` from the SVG: where its baseline starts, in SVG units, and the line it draws.
struct SVGText {
    let left: CGFloat
    let baseline: CGFloat
    let line: CTLine
    let ink: CGRect           // the glyphs' inked bounds, relative to the baseline origin, y up
}

struct Lockup {
    let shapes: NSImage       // the SVG with its text removed
    let texts: [SVGText]
}

func attribute(_ name: String, in tag: String) -> String? {
    guard let range = tag.range(of: "\\b\(name)=\"([^\"]*)\"", options: .regularExpression) else { return nil }
    let match = String(tag[range])
    return String(match.dropFirst(name.count + 2).dropLast())
}

func colour(_ hex: String) -> NSColor {
    let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard digits.count == 6, let value = UInt32(digits, radix: 16) else { fail("unreadable fill \(hex)") }
    return NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                   blue: CGFloat(value & 0xFF) / 255, alpha: 1)
}

/// The face a `<text>` names, or a stop: a logo set in a substitute font is worse than no logo.
func face(family: String, size: CGFloat, weight: Int, italic: Bool) -> NSFont {
    // CSS weights onto AppKit's: 500 is medium, which is the weight Futura's lockups use.
    let weights: [Int: NSFont.Weight] = [300: .light, 400: .regular, 500: .medium, 600: .semibold, 700: .bold]
    guard let mapped = weights[weight] else { fail("no mapping for font-weight \(weight)") }
    var traits: [NSFontDescriptor.TraitKey: Any] = [.weight: mapped]
    if italic { traits[.symbolic] = NSFontDescriptor.SymbolicTraits.italic.rawValue }
    let descriptor = NSFontDescriptor(fontAttributes: [.family: family, .traits: traits])
    guard let font = NSFont(descriptor: descriptor, size: size), font.familyName == family else {
        fail("font \(family) isn't installed")
    }
    if italic && !font.fontDescriptor.symbolicTraits.contains(.italic) {
        fail("\(family) resolved to \(font.fontName), which isn't italic")
    }
    return font
}

func readLockup(_ url: URL) -> Lockup {
    guard var source = try? String(contentsOf: url, encoding: .utf8) else { fail("can't read \(url.path)") }
    var texts: [SVGText] = []
    let pattern = "<text\\b([^>]*)>([^<]*)</text>"
    while let range = source.range(of: pattern, options: .regularExpression) {
        let element = String(source[range])
        let tag = String(element.prefix { $0 != ">" })
        let content = String(element.drop { $0 != ">" }.dropFirst().prefix { $0 != "<" })
            .replacingOccurrences(of: "&amp;", with: "&")
        guard let left = attribute("x", in: tag).flatMap(Double.init),
              let baseline = attribute("y", in: tag).flatMap(Double.init),
              let family = attribute("font-family", in: tag),
              let size = attribute("font-size", in: tag).flatMap(Double.init) else {
            fail("a <text> without x, y, font-family and font-size: \(tag)")
        }
        let font = face(family: family, size: CGFloat(size),
                        weight: attribute("font-weight", in: tag).flatMap(Int.init) ?? 400,
                        italic: attribute("font-style", in: tag) == "italic")
        let string = NSAttributedString(string: content, attributes: [
            .font: font, .foregroundColor: colour(attribute("fill", in: tag) ?? "#000000")
        ])
        let line = CTLineCreateWithAttributedString(string)
        texts.append(SVGText(left: CGFloat(left), baseline: CGFloat(baseline), line: line,
                             ink: CTLineGetImageBounds(line, nil)))
        source.removeSubrange(range)
    }
    guard let shapes = NSImage(data: Data(source.utf8)) else { fail("can't read the shapes in \(url.path)") }
    return Lockup(shapes: shapes, texts: texts)
}

/// Draw the lockup into the current (flipped, y-down) context, its SVG unit square at `origin`
/// and `scale` pixels per unit.
func draw(_ lockup: Lockup, origin: CGPoint, scale: CGFloat) {
    let canvas = NSRect(x: origin.x, y: origin.y,
                        width: lockup.shapes.size.width * scale, height: lockup.shapes.size.height * scale)
    lockup.shapes.draw(in: canvas, from: .zero, operation: .sourceOver, fraction: 1,
                       respectFlipped: true, hints: nil)
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    for text in lockup.texts {
        context.saveGState()
        // To the baseline, then y up again for Core Text.
        context.translateBy(x: origin.x + text.left * scale, y: origin.y + text.baseline * scale)
        context.scaleBy(x: scale, y: -scale)
        context.textMatrix = .identity
        context.textPosition = .zero
        CTLineDraw(text.line, context)
        context.restoreGState()
    }
}

/// The lockup's inked bounds in the SVG's own units, y down. The designer's canvas is a 3424²
/// square with the lockup somewhere inside it, so the art is measured rather than trusted to fill its
/// viewBox: the shapes are rendered once at `probe` pixels and scanned for alpha (a pixel of margin
/// either way), and each text adds its glyph bounds from Core Text.
func inkedBounds(of lockup: Lockup, probe: Int = 2048) -> CGRect {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: probe, pixelsHigh: probe,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: rep) else { fail("no probe bitmap") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    lockup.shapes.draw(in: NSRect(x: 0, y: 0, width: probe, height: probe))
    NSGraphicsContext.restoreGraphicsState()

    var minX = probe, minY = probe, maxX = -1, maxY = -1
    guard let data = rep.bitmapData else { fail("no probe data") }
    for row in 0..<probe {
        for col in 0..<probe where data[row * rep.bytesPerRow + col * 4 + 3] > 8 {
            minX = min(minX, col); maxX = max(maxX, col)
            minY = min(minY, row); maxY = max(maxY, row)
        }
    }
    let unit = lockup.shapes.size.width / CGFloat(probe)
    var bounds = maxX < 0 ? CGRect.null
        : CGRect(x: CGFloat(minX - 1) * unit, y: CGFloat(minY - 1) * unit,
                 width: CGFloat(maxX - minX + 3) * unit, height: CGFloat(maxY - minY + 3) * unit)
    for text in lockup.texts {
        bounds = bounds.union(CGRect(x: text.left + text.ink.minX, y: text.baseline - text.ink.maxY,
                                     width: text.ink.width, height: text.ink.height))
    }
    guard !bounds.isNull else { fail("the lockup draws nothing") }
    return bounds
}

// MARK: - The artwork

/// An sRGB bitmap with no alpha, flipped so y runs down the canvas the way Apple's offsets read.
func makeContext(_ width: Int, _ height: Int) -> CGContext {
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        fail("no context")
    }
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    return context
}

func render(_ placement: Placement, lockup: Lockup, bounds: CGRect, guides: Bool) -> CGImage {
    let context = makeContext(placement.width, placement.height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    let size = NSSize(width: placement.width, height: placement.height)

    // Ground, then a glow centred on the art: the frames' glow sits behind their caption, this one
    // behind the lockup, at the same strength.
    background.setFill()
    NSRect(origin: .zero, size: size).fill()
    let centre = NSPoint(x: placement.safe.midX, y: placement.safe.midY)
    NSGradient(colors: [terracotta.withAlphaComponent(0.22), background.withAlphaComponent(0)])?
        .draw(fromCenter: centre, radius: 0, toCenter: centre,
              radius: max(placement.safe.width, placement.safe.height) * 1.1, options: [])

    // The lockup, as large as the safe area allows, centred in it.
    let scale = min(placement.safe.width * fillWidth / bounds.width,
                    placement.safe.height * fillHeight / bounds.height)
    let origin = CGPoint(x: placement.safe.midX - (bounds.minX + bounds.width / 2) * scale,
                         y: placement.safe.midY - (bounds.minY + bounds.height / 2) * scale)
    draw(lockup, origin: origin, scale: scale)

    if guides {
        NSColor.systemGreen.setStroke()
        let outline = NSBezierPath(rect: placement.safe)
        outline.lineWidth = 4
        outline.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()
    guard let image = context.makeImage() else { fail("no image for \(placement.name)") }
    return image
}

func write(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString,
                                                            1, nil) else { fail("can't write \(url.path)") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fail("can't finish \(url.path)") }
}

let arguments = CommandLine.arguments.dropFirst().filter { $0 != "--guides" }
let guides = CommandLine.arguments.contains("--guides")
guard arguments.count == 2 else { fail("usage: appstore-headers.swift <lockup.svg> <out-dir> [--guides]") }
let lockup = readLockup(URL(fileURLWithPath: arguments[arguments.startIndex]))
let out = URL(fileURLWithPath: arguments[arguments.startIndex + 1])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

let bounds = inkedBounds(of: lockup)
for placement in placements {
    write(render(placement, lockup: lockup, bounds: bounds, guides: false),
          to: out.appendingPathComponent("\(placement.name).png"))
    if guides {
        write(render(placement, lockup: lockup, bounds: bounds, guides: true),
              to: out.appendingPathComponent("\(placement.name)-guides.png"))
    }
    print("\(placement.name): \(placement.width)×\(placement.height)")
}
