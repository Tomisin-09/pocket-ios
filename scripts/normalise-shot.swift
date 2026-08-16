#!/usr/bin/env swift
//
// Make a hand-shot device figure match the driven set (ADR 0165, Phase 5).
//
// Three of the manual's ninety-six figures cannot be driven — landscape, the tuner with a string
// actually sounding, and the Red Moon Pro settings screen with a real subscription behind it. Those
// come off a phone, and a phone's status bar carries the time it happened to be, a battery level, a
// silent-mode bell and, for anything using the microphone, the orange recording dot. The driven
// figures carry a faked 09:41 with clean indicators. Side by side in one manual they do not read as
// one set, and the reader notices the seam long before they could say what it was.
//
// This copies the status-bar band from a driven capture onto a device capture. Both are 1206×2622,
// which is the whole reason the master geometry was chosen that way — the band lines up because it
// is the same band.
//
//   ./scripts/normalise-shot.swift <donor.png> <target.png> <out.png> [bandHeight]
//
// `donor` is any driven capture (its top strip is the one being borrowed). `bandHeight` defaults to
// 147pt·scale, the top safe-area inset on this geometry, which is tall enough to take the Dynamic
// Island with it — the island is where a live-microphone pill sits, and the tuner shot has one.
//
// ⚠️ This is retouching. It is standard for product documentation, and Apple requires it for App
// Store screenshots, but be clear about what it removes: the mic dot on a tuner shot is *truthful* —
// the tuner really is listening. What is being asserted by erasing it is that the manual's figures
// show the app, not the phone it happened to run on.
//
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The top safe-area band on 1206×2622, in pixels. Covers the status bar and the Dynamic Island.
let defaultBandHeight = 147

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("normalise-shot: \(message)\n".utf8))
    exit(1)
}

func loadImage(_ path: String) -> CGImage {
    guard let url = URL(string: "file://" + (path as NSString).expandingTildeInPath),
          let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { fail("could not read an image at \(path)") }
    return image
}

let arguments = CommandLine.arguments
guard arguments.count >= 4 else {
    fail("usage: normalise-shot.swift <donor.png> <target.png> <out.png> [bandHeight]")
}

let donor = loadImage(arguments[1])
let target = loadImage(arguments[2])
let outPath = arguments[3]
let bandHeight = arguments.count > 4 ? (Int(arguments[4]) ?? defaultBandHeight) : defaultBandHeight

// Same geometry or the band does not line up — and a band that does not line up is worse than no
// band at all, because it looks deliberate.
guard donor.width == target.width, donor.height == target.height else {
    fail("""
        geometry mismatch — donor is \(donor.width)×\(donor.height), \
        target is \(target.width)×\(target.height). Both must be the master geometry.
        """)
}
guard bandHeight > 0, bandHeight < target.height else {
    fail("bandHeight \(bandHeight) is not inside a \(target.height)px image")
}

guard let colorSpace = target.colorSpace,
      let context = CGContext(data: nil,
                              width: target.width,
                              height: target.height,
                              bitsPerComponent: 8,
                              bytesPerRow: 0,
                              space: colorSpace,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else { fail("could not create a drawing context") }

// The target first, whole; then the donor's band over the top of it. CoreGraphics' origin is
// bottom-left, so the *top* band of the image is the highest y — hence the height subtraction
// rather than a y of zero, which is the easy way to composite the wrong end of the picture.
context.draw(target, in: CGRect(x: 0, y: 0, width: target.width, height: target.height))

guard let band = donor.cropping(to: CGRect(x: 0, y: 0, width: donor.width, height: bandHeight))
else { fail("could not crop the donor band") }

context.draw(band, in: CGRect(x: 0,
                              y: target.height - bandHeight,
                              width: target.width,
                              height: bandHeight))

guard let output = context.makeImage() else { fail("could not render the composite") }

let outURL = URL(fileURLWithPath: (outPath as NSString).expandingTildeInPath)
guard let destination = CGImageDestinationCreateWithURL(
    outURL as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fail("could not open \(outPath) for writing") }

CGImageDestinationAddImage(destination, output, nil)
guard CGImageDestinationFinalize(destination) else { fail("could not write \(outPath)") }

print("✅ \(outPath) — \(output.width)×\(output.height), top \(bandHeight)px from \(arguments[1])")
