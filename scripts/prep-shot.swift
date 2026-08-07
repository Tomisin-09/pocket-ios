// App Store screenshot post-processor.
//
// Two jobs in one pass, because doing them separately is how the alpha channel
// sneaks back in: downscale the simulator's native 1320x2868 capture to the
// 1242x2688 the 6.5" ASC slot demands, and flatten it onto opaque black.
//
// ASC rejects any PNG carrying an alpha channel, and `sips` will not reliably
// drop one -- drawing into a `noneSkipFirst` context is what actually removes it.
// Downscaling (never upscaling) is what keeps the result crisp.
//
// usage: swift scripts/prep-shot.swift <in.png> <out.png>

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let targetWidth = 1242
let targetHeight = 2688

/// Write to stderr and stop. `Data(_:)` rather than `data(using:)!` — the latter is a
/// force unwrap the repo's SwiftLint config rejects, and it is never nil for UTF-8 anyway.
func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(code)
}

guard CommandLine.arguments.count == 3 else {
    fail("usage: prep-shot.swift <in.png> <out.png>", code: 2)
}
let inURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let src = CGImageSourceCreateWithURL(inURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    fail("could not read \(inURL.path)")
}

guard let ctx = CGContext(
    data: nil,
    width: targetWidth,
    height: targetHeight,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    // noneSkipFirst == opaque. This is the line that removes the alpha channel.
    bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
) else {
    fail("could not create context")
}

// Paint the backdrop before the image, so any translucent pixel resolves against
// black rather than against whatever was left in the buffer.
ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
ctx.interpolationQuality = .high
ctx.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

guard let out = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(
        outURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fail("could not create output")
}
CGImageDestinationAddImage(dest, out, nil)
guard CGImageDestinationFinalize(dest) else {
    fail("could not write \(outURL.path)")
}
print("\(inURL.lastPathComponent) -> \(outURL.lastPathComponent)  \(targetWidth)x\(targetHeight) opaque")
