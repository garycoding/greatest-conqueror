// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import AppKit
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import Synchronization

/// The area of figure space a picture covers, and the scale at which it is drawn.
struct Canvas: Hashable, Sendable {
    var minX: Double
    var minY: Double
    var width: Double
    var height: Double
    var pixelsPerUnit: Double

    var pixelWidth: Int { Int((width * pixelsPerUnit).rounded()) }
    var pixelHeight: Int { Int((height * pixelsPerUnit).rounded()) }

    /// The figure's origin (on the ground, between the feet) as a fraction of
    /// the image, with (0, 0) at the bottom left.
    var anchor: SpriteAnchor { SpriteAnchor(x: -minX / width, y: (minY + height) / height) }

    /// The same area at another scale.
    func scaled(to pixelsPerUnit: Double) -> Canvas {
        Canvas(minX: minX, minY: minY, width: width, height: height, pixelsPerUnit: pixelsPerUnit)
    }

    /// Every person of every pose: room for a club or a sling swung overhead and
    /// for a stone thrown forward. A figure stands about 79 units from its feet
    /// to the top of its hair, and the game shows a person about 48 points tall,
    /// so a unit is 5/8 of a point: 1.25 pixels at twice the size in points
    /// (120 by 135 pixels, and a person of about 49 points).
    static let person = Canvas(minX: -36, minY: -102, width: 96, height: 108, pixelsPerUnit: 1.25)
}

/// A sprite's two pictures, before they are wrapped as a `SpriteImage`.
struct Rendered: @unchecked Sendable {
    var base: CGImage
    /// White where the team's colour goes; nil where nothing carries it.
    var mask: CGImage?

    /// The sprite, standing at `anchor`.
    func sprite(anchor: SpriteAnchor) -> SpriteImage {
        SpriteImage(base: base, teamMask: mask, anchor: anchor)
    }
}

/// Draws SVG text with macOS's own renderer and lays the grain over it.
enum Raster {
    static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    /// A picture and its team-colour mask from one drawing routine, which is
    /// run once for each layer (`SVG.layer`), so that every part painted
    /// `.team` is neutral in the picture and white in the mask, and everything
    /// drawn over it hides it in both. Both are grained alike unless `grained`
    /// is false. The mask is nil where nothing is painted `.team`.
    static func render(on canvas: Canvas, grained: Bool = true, _ draw: (inout SVG) -> Void) -> Rendered? {
        var picture = SVG(layer: .base), matte = SVG(layer: .mask)
        draw(&picture)
        draw(&matte)
        guard let base = Raster.draw(picture.document(canvas), on: canvas),
              let mask = Raster.draw(matte.document(canvas), on: canvas) else { return nil }
        let coloured = Raster.matte(mask)
        if grained, let grain = Grain.image(width: canvas.pixelWidth, height: canvas.pixelHeight) {
            Raster.grain(base, with: grain)
            if coloured { Raster.grain(mask, with: grain) }
        }
        guard let baseImage = base.makeImage() else { return nil }
        return Rendered(base: baseImage, mask: coloured ? mask.makeImage() : nil)
    }

    /// A transparent bitmap of the given size, premultiplied RGBA in sRGB.
    static func bitmap(width: Int, height: Int) -> CGContext? {
        CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: sRGB,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }

    /// The SVG document drawn by macOS (`NSImage`) into a new bitmap of the canvas's size.
    static func draw(_ document: String, on canvas: Canvas) -> CGContext? {
        guard let image = NSImage(data: Data(document.utf8)),
              let context = bitmap(width: canvas.pixelWidth, height: canvas.pixelHeight) else { return nil }
        let graphics = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        image.draw(in: NSRect(x: 0, y: 0, width: canvas.pixelWidth, height: canvas.pixelHeight))
        NSGraphicsContext.restoreGraphicsState()
        return context
    }

    /// Turns a drawing of the mask (white for the team's colour, black for
    /// everything else) into the mask itself: white, with the white's share of
    /// each pixel as its alpha, so that the black parts become transparent.
    /// Returns whether any of it is white.
    @discardableResult
    static func matte(_ context: CGContext) -> Bool {
        guard let data = context.data else { return false }
        let bytes = data.bindMemory(to: UInt8.self, capacity: context.bytesPerRow * context.height)
        var any: UInt8 = 0
        for row in 0..<context.height {
            let line = bytes + row * context.bytesPerRow
            var i = 0
            while i < context.width * 4 {
                // Premultiplied red: whiteness times coverage, since every paint is black or white.
                let white = line[i]
                line[i + 1] = white; line[i + 2] = white; line[i + 3] = white
                any |= white
                i += 4
            }
        }
        return any != 0
    }

    /// Lays the grain over what is drawn, only where something is drawn: the
    /// grain darkens each pixel by its alpha and leaves the pixel's own alpha as
    /// it was.
    static func grain(_ context: CGContext, with grain: CGImage) {
        context.saveGState()
        context.setBlendMode(.sourceAtop)
        context.draw(grain, in: CGRect(x: 0, y: 0, width: context.width, height: context.height))
        context.restoreGState()
    }
}

/// The grain of the paper (docs/art-style.md, "The style"): fine dark speckles,
/// some of them clustered, made by Core Image from its random generator. It is
/// made once for a size and laid over every frame in the same place, so that
/// the paper does not shimmer as the figure moves.
enum Grain {
    /// The colour of the speckles, the deep brown of the reference drawings' grain.
    static let colour = (red: 0x3a / 255.0, green: 0x2a / 255.0, blue: 0x1c / 255.0)

    private static let made = Mutex<[Size: Box]>([:])
    private struct Size: Hashable { var width: Int; var height: Int }
    private struct Box: @unchecked Sendable { var image: CGImage }

    /// The grain for a picture of the given pixel size.
    static func image(width: Int, height: Int) -> CGImage? {
        let size = Size(width: width, height: height)
        // Made under the lock, so that two pictures of one size drawn at once
        // share one grain rather than each making its own.
        return made.withLock { made -> CGImage? in
            if let known = made[size] { return known.image }
            guard let image = make(width: width, height: height) else { return nil }
            made[size] = Box(image: image)
            return image
        }
    }

    private static func make(width: Int, height: Int) -> CGImage? {
        guard let random = CIFilter.randomGenerator().outputImage else { return nil }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let margin = rect.insetBy(dx: -8, dy: -8)
        // The generator's noise, made opaque so that only its colour is read.
        let fine = random.cropped(to: margin).settingAlphaOne(in: margin)
        // The same noise spread over two or three pixels and softened: clusters.
        let coarse = random.transformed(by: CGAffineTransform(scaleX: 2.5, y: 2.5)).cropped(to: margin)
            .settingAlphaOne(in: margin).applyingGaussianBlur(sigma: 0.7)
        /// Speckles in the grain's colour wherever the noise rises above
        /// `threshold`, their alpha rising to `strength` at the noise's top.
        func speckles(_ noise: CIImage, threshold: CGFloat, strength: CGFloat) -> CIImage {
            let matrix = CIFilter.colorMatrix()
            matrix.inputImage = noise
            let zero = CIVector(x: 0, y: 0, z: 0, w: 0)
            matrix.rVector = zero; matrix.gVector = zero; matrix.bVector = zero
            matrix.aVector = CIVector(x: 0, y: strength / (1 - threshold), z: 0, w: 0)
            matrix.biasVector = CIVector(x: colour.red, y: colour.green, z: colour.blue,
                                         w: -strength * threshold / (1 - threshold))
            return (matrix.outputImage ?? noise).applyingFilter("CIColorClamp")
        }
        // As strong as the reference drawings' grain: a spread of about 5 in 255
        // on a flat field, with the darkest speckles some 15 below it.
        let grain = speckles(fine, threshold: 0.78, strength: 0.26)
            .composited(over: speckles(coarse, threshold: 0.6, strength: 0.12)).cropped(to: rect)
        let context = CIContext(options: [.useSoftwareRenderer: true, .workingColorSpace: Raster.sRGB,
                                          .outputColorSpace: Raster.sRGB, .cacheIntermediates: false])
        return context.createCGImage(grain, from: rect, format: .RGBA8, colorSpace: Raster.sRGB)
    }
}
