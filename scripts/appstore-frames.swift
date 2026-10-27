#!/usr/bin/env swift
// Caption App Store screenshots (ADR 0279).
//
//     swift scripts/appstore-frames.swift <frames.json> <out-dir>
//
// `frames.json` is a list of `{ "source": "<capture.png>", "verb": "WORK IT OUT",
// "headline": "Loop the bar you can't play.", "name": "01-work-it-out" }`, with each `source`
// relative to the manifest. Each frame is drawn natively at three iPhone sizes, rather than one
// resized into another (their aspect ratios differ, so a resize would stretch): 1206×2622 (6.3") into
// `<out>/6.3/`, 1320×2868 (6.9") into `<out>/6.9/` and 1242×2688 (6.5") into `<out>/6.5/`. **6.3" is
// the one App Store Connect requires**: its slot, *iPhone with Dynamic Island (medium display)*, takes
// only 1206×2622 or 1179×2556, and rejected both other sizes on 2026-10-27.
//
// The look is the app's: the near-black background (`#040404`), the brand teal (`#60A8C7`) for the
// verb, white Futura for the headline. The capture sits below, whole, with the phone's rounded
// corners. Frames are written with **no alpha channel**, which App Store Connect requires. A
// non-breaking space in a headline keeps two words on one line.
//
// Nothing here knows what a frame says: the captions live in the manifest, so wording changes
// without touching code. The storyboard itself is in `docs/app-store-listing-copy.md`.

import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Frame: Decodable {
    let source: String
    let verb: String
    let headline: String
    let name: String
}

struct Canvas {
    let folder: String
    let width: Int
    let height: Int
}

let canvases = [
    Canvas(folder: "6.3", width: 1206, height: 2622),
    Canvas(folder: "6.9", width: 1320, height: 2868),
    Canvas(folder: "6.5", width: 1242, height: 2688)
]
let background = NSColor(srgbRed: 4 / 255, green: 4 / 255, blue: 4 / 255, alpha: 1)
let teal = NSColor(srgbRed: 0x60 / 255, green: 0xA8 / 255, blue: 0xC7 / 255, alpha: 1)

func font(_ name: String, _ size: CGFloat) -> NSFont {
    guard let found = NSFont(name: name, size: size) else {
        FileHandle.standardError.write(Data("missing font \(name)\n".utf8))
        exit(1)
    }
    return found
}

/// An sRGB bitmap with no alpha, flipped so y runs down the frame the way the layout reads.
func makeContext(_ canvas: Canvas) -> CGContext? {
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(data: nil, width: canvas.width, height: canvas.height, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
    context.translateBy(x: 0, y: CGFloat(canvas.height))
    context.scaleBy(x: 1, y: -1)
    return context
}

/// The near-black ground, with a faint teal glow behind the caption.
func drawBackground(_ size: NSSize) {
    background.setFill()
    NSRect(origin: .zero, size: size).fill()
    let centre = NSPoint(x: size.width / 2, y: size.height * 0.04)
    NSGradient(colors: [teal.withAlphaComponent(0.22), background.withAlphaComponent(0)])?
        .draw(fromCenter: centre, radius: 0, toCenter: centre, radius: size.width * 0.9, options: [])
}

/// The verb and the headline, centred. Returns where the capture can start.
func drawCaption(_ frame: Frame, in size: NSSize) -> CGFloat {
    let margin = size.width * 0.08
    let textWidth = size.width - margin * 2
    let centred = NSMutableParagraphStyle()
    centred.alignment = .center
    centred.lineBreakMode = .byWordWrapping

    let verb = NSAttributedString(string: frame.verb, attributes: [
        .font: font("Futura-Medium", size.width * 0.034), .foregroundColor: teal,
        .kern: size.width * 0.0045, .paragraphStyle: centred
    ])
    let headline = NSAttributedString(string: frame.headline, attributes: [
        .font: font("Futura-Bold", size.width * 0.062), .foregroundColor: NSColor.white,
        .paragraphStyle: centred
    ])

    var cursor = size.height * 0.055
    for (text, gap) in [(verb, size.height * 0.012), (headline, size.height * 0.035)] {
        let box = text.boundingRect(with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
                                    options: [.usesLineFragmentOrigin])
        text.draw(with: NSRect(x: margin, y: cursor, width: textWidth, height: ceil(box.height)),
                  options: [.usesLineFragmentOrigin])
        cursor += ceil(box.height) + gap
    }
    return cursor
}

/// The capture, whole: as wide as 80% of the frame allows, or as tall as the space left does.
func drawCapture(_ capture: NSImage, from top: CGFloat, in size: NSSize) {
    let source = capture.size
    let scale = min(size.width * 0.80 / source.width, (size.height * 0.965 - top) / source.height)
    let shot = NSRect(x: (size.width - source.width * scale) / 2, y: top,
                      width: source.width * scale, height: source.height * scale)
    let corner = shot.width * 0.115
    let outline = NSBezierPath(roundedRect: shot, xRadius: corner, yRadius: corner)
    NSGraphicsContext.saveGraphicsState()
    outline.addClip()
    capture.draw(in: shot, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
    NSGraphicsContext.restoreGraphicsState()
    NSColor(white: 1, alpha: 0.14).setStroke()
    outline.lineWidth = max(2, size.width * 0.0018)
    outline.stroke()
}

func render(_ frame: Frame, capture: NSImage, on canvas: Canvas) -> CGImage? {
    guard let context = makeContext(canvas) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    let size = NSSize(width: canvas.width, height: canvas.height)
    drawBackground(size)
    drawCapture(capture, from: drawCaption(frame, in: size), in: size)
    NSGraphicsContext.restoreGraphicsState()
    return context.makeImage()
}

func writePNG(_ image: CGImage, to url: URL) -> Bool {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString,
                                                            1, nil) else { return false }
    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination)
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    print("usage: swift scripts/appstore-frames.swift <frames.json> <out-dir>")
    exit(2)
}
let manifest = URL(fileURLWithPath: arguments[1])
let outDir = URL(fileURLWithPath: arguments[2])
guard let data = try? Data(contentsOf: manifest),
      let frames = try? JSONDecoder().decode([Frame].self, from: data), !frames.isEmpty else {
    print("couldn't read any frames from \(manifest.path)")
    exit(1)
}

var failed = false
for frame in frames {
    let sourceURL = URL(fileURLWithPath: frame.source, relativeTo: manifest.deletingLastPathComponent())
    guard let capture = NSImage(contentsOf: sourceURL) else {
        print("❌ \(frame.name): can't read \(sourceURL.path)")
        failed = true
        continue
    }
    for canvas in canvases {
        let folder = outDir.appendingPathComponent(canvas.folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let target = folder.appendingPathComponent(frame.name + ".png")
        guard let image = render(frame, capture: capture, on: canvas), writePNG(image, to: target) else {
            print("❌ \(frame.name) at \(canvas.folder)\": couldn't render")
            failed = true
            continue
        }
        print("✅ \(canvas.folder)/\(frame.name).png  \(canvas.width)×\(canvas.height)")
    }
}
exit(failed ? 1 : 0)
