// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import AppKit
import CoreGraphics
import CoreImage
import Foundation
import GameCore
import ImageIO
import UniformTypeIdentifiers
@testable import Artwork

/// Pictures of the artwork for a person to judge: sprites tinted as the drawing
/// tints them, laid on a patch of Stone-age ground, written as PNG and GIF.
enum Preview {
    static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    /// The picture as the drawing shows it: the base, with the mask tinted in the
    /// team's colour laid over it (SpriteKit multiplies the white mask by the colour).
    static func tinted(base: CGImage, mask: CGImage?, colour: TeamColour) -> CGImage {
        let w = base.width, h = base.height, rect = CGRect(x: 0, y: 0, width: w, height: h)
        let out = Raster.bitmap(width: w, height: h)!
        out.draw(base, in: rect)
        guard let mask, let m = Raster.bitmap(width: w, height: h) else { return out.makeImage()! }
        m.draw(mask, in: rect)
        let o = out.data!.bindMemory(to: UInt8.self, capacity: w * h * 4)
        let k = m.data!.bindMemory(to: UInt8.self, capacity: w * h * 4)
        let tint = [colour.red, colour.green, colour.blue, 1.0]
        for i in stride(from: 0, to: w * h * 4, by: 4) {
            let alpha = Double(k[i + 3]) / 255
            if alpha == 0 { continue }
            for c in 0..<4 {
                let value = Double(k[i + c]) * tint[c] + Double(o[i + c]) * (1 - alpha)
                o[i + c] = UInt8(min(255, max(0, value.rounded())))
            }
        }
        return out.makeImage()!
    }

    /// A patch of the Stone age's ground: dusk lilac, sponged, with the faint
    /// diamonds of the map's tiles, and the grain over all unless `grained` is
    /// false (an animation's ground is left without it, so that the GIF stays small).
    static func ground(width: Int, height: Int, tile: Double, grained: Bool = true) -> CGImage {
        var svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(width)\" height=\"\(height)\" viewBox=\"0 0 \(width) \(height)\">"
        svg += "<rect width=\"\(width)\" height=\"\(height)\" fill=\"#a79aa6\"/>"
        svg += "<g fill=\"none\" stroke=\"#9a8c9a\" stroke-width=\"\(tile / 40)\">"
        let w = tile, h = tile / 2
        var y = -h
        var row = 0
        while y < Double(height) + h {
            var x = (row % 2 == 0) ? 0 : w / 2
            x -= w
            while x < Double(width) + w {
                svg += "<path d=\"M\(x),\(y) l\(w / 2),\(h / 2) l\(-w / 2),\(h / 2) l\(-w / 2),\(-h / 2) Z\"/>"
                x += w
            }
            y += h / 2
            row += 1
        }
        svg += "</g></svg>"
        let canvas = Canvas(minX: 0, minY: 0, width: Double(width), height: Double(height), pixelsPerUnit: 1)
        let context = Raster.draw(svg, on: canvas)!
        // The sponge: soft blotches of a deeper lilac.
        let random = CIFilter(name: "CIRandomGenerator")!.outputImage!
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let blotches = random.transformed(by: CGAffineTransform(scaleX: 9, y: 9)).cropped(to: rect.insetBy(dx: -40, dy: -40))
            .settingAlphaOne(in: rect.insetBy(dx: -40, dy: -40)).applyingGaussianBlur(sigma: 6)
        let matrix = CIFilter(name: "CIColorMatrix")!
        matrix.setValue(blotches, forKey: kCIInputImageKey)
        matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputRVector")
        matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputGVector")
        matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBVector")
        matrix.setValue(CIVector(x: 0, y: 1.6, z: 0, w: 0), forKey: "inputAVector")
        matrix.setValue(CIVector(x: 0x8a / 255.0, y: 0x7c / 255.0, z: 0x8b / 255.0, w: -0.7), forKey: "inputBiasVector")
        let sponge = matrix.outputImage!.applyingFilter("CIColorClamp").cropped(to: rect)
        let ci = CIContext(options: [.useSoftwareRenderer: true, .workingColorSpace: sRGB, .outputColorSpace: sRGB])
        if let image = ci.createCGImage(sponge, from: rect, format: .RGBA8, colorSpace: sRGB) {
            context.draw(image, in: rect)
        }
        if grained, let grain = Grain.image(width: width, height: height) { context.draw(grain, in: rect) }
        return context.makeImage()!
    }

    /// Text in Futura, as the reference sheets have it.
    static func label(_ text: String, in context: CGContext, at point: CGPoint, size: Double, colour: NSColor = NSColor(srgbRed: 0x2a / 255.0, green: 0x24 / 255.0, blue: 0x20 / 255.0, alpha: 1)) {
        let font = NSFont(name: "Futura-Medium", size: size) ?? NSFont.systemFont(ofSize: size)
        let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: colour])
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        string.draw(at: point)
        NSGraphicsContext.restoreGraphicsState()
    }

    /// Draws `image` with its anchor at `point` (in pixels, origin bottom left).
    static func place(_ image: CGImage, anchor: SpriteAnchor, at point: CGPoint, in context: CGContext, scale: Double = 1) {
        let w = Double(image.width) * scale, h = Double(image.height) * scale
        context.draw(image, in: CGRect(x: point.x - anchor.x * w, y: point.y - anchor.y * h, width: w, height: h))
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }

    /// An animated GIF at 12 frames a second: GIF delays are in hundredths, so
    /// they run 8, 8, 9 to make 25 hundredths for every three frames.
    static func writeGIF(_ frames: [CGImage], to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for (i, frame) in frames.enumerated() {
            let delay = i % 3 == 2 ? 0.09 : 0.08
            CGImageDestinationAddImage(destination, frame, [kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: delay, kCGImagePropertyGIFUnclampedDelayTime: delay]] as CFDictionary)
        }
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }
}
