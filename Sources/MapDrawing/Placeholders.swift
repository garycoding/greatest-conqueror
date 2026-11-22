// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import GameCore

/// A picture drawn by the placeholders: the image (at twice its size in points),
/// its size in points, and the anchor as a fraction of the image with (0, 0) at
/// the bottom left, as `SpriteImage` has it.
struct DrawnImage {
    var image: CGImage
    var size: CGSize
    var anchor: CGPoint
}

/// The pictures shown for every sprite the `SpriteSource` does not supply: a
/// terrain diamond in a colour per terrain; a building as its footprint's
/// diamond with a raised block in the team colour; a person as a small figure in
/// the team colour with a mark per kind; a site as a shape per kind. They are
/// drawn with Core Graphics once and cached by `SpriteCache`.
enum Placeholders {
    static let scale: CGFloat = 2

    // MARK: Drawing helpers

    static func render(_ size: CGSize, _ draw: (CGContext) -> Void) -> CGImage {
        let width = Int((size.width * scale).rounded(.up)), height = Int((size.height * scale).rounded(.up))
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.scaleBy(x: scale, y: scale)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        draw(context)
        return context.makeImage()!
    }

    static func colour(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
        CGColor(srgbRed: r, green: g, blue: b, alpha: a)
    }

    static func team(_ civilization: Civilization) -> TeamColour { TeamColour.of(civilization) }

    /// A team colour made lighter (factor above 1) or darker (below 1).
    static func shade(_ c: TeamColour, _ factor: Double, alpha: Double = 1) -> CGColor {
        func f(_ v: Double) -> Double { min(max(v * factor, 0), 1) }
        return colour(f(c.red), f(c.green), f(c.blue), alpha)
    }

    static let ink = colour(0.12, 0.09, 0.07, 0.9)

    static func polygon(_ context: CGContext, _ points: [CGPoint], fill: CGColor?, stroke: CGColor? = ink, width: CGFloat = 1.2) {
        guard let first = points.first else { return }
        context.beginPath()
        context.move(to: first)
        for point in points.dropFirst() { context.addLine(to: point) }
        context.closePath()
        if let fill { context.setFillColor(fill); context.fillPath() }
        if let stroke {
            context.beginPath()
            context.move(to: first)
            for point in points.dropFirst() { context.addLine(to: point) }
            context.closePath()
            context.setStrokeColor(stroke)
            context.setLineWidth(width)
            context.strokePath()
        }
    }

    static func line(_ context: CGContext, _ a: CGPoint, _ b: CGPoint, _ colour: CGColor, width: CGFloat = 2) {
        context.setStrokeColor(colour)
        context.setLineWidth(width)
        context.beginPath()
        context.move(to: a)
        context.addLine(to: b)
        context.strokePath()
    }

    static func ellipse(_ context: CGContext, _ rect: CGRect, fill: CGColor?, stroke: CGColor? = ink, width: CGFloat = 1.2) {
        if let fill { context.setFillColor(fill); context.fillEllipse(in: rect) }
        if let stroke { context.setStrokeColor(stroke); context.setLineWidth(width); context.strokeEllipse(in: rect) }
    }

    /// The image with a share of black laid over it, for ground explored but not in sight.
    static func darkened(_ image: CGImage, by amount: Double = 0.5) -> CGImage {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.draw(image, in: rect)
        context.setBlendMode(.sourceAtop)
        context.setFillColor(colour(0, 0, 0, amount))
        context.fill(rect)
        return context.makeImage()!
    }

    // MARK: Terrain

    static let terrainSize = CGSize(width: 66, height: 34)

    static func terrainColour(_ terrain: Terrain) -> (Double, Double, Double) {
        switch terrain {
        case .grass: (0.44, 0.66, 0.30)
        case .dirt: (0.60, 0.45, 0.29)
        case .sand: (0.87, 0.79, 0.52)
        case .forest: (0.22, 0.43, 0.22)
        case .shallowWater: (0.38, 0.69, 0.82)
        case .deepWater: (0.12, 0.30, 0.55)
        }
    }

    /// A terrain diamond, a point larger each way than a tile, so that no seam
    /// shows between neighbours. `variant` 0 and 1 differ a little in tone.
    static func terrain(_ terrain: Terrain, variant: Int, dimmed: Bool) -> CGImage {
        let (r, g, b) = terrainColour(terrain)
        let tone = variant % 2 == 0 ? 1.0 : 0.93
        let w = terrainSize.width, h = terrainSize.height
        let image = render(terrainSize) { c in
            let corners = [CGPoint(x: w / 2, y: h), CGPoint(x: w, y: h / 2), CGPoint(x: w / 2, y: 0), CGPoint(x: 0, y: h / 2)]
            polygon(c, corners, fill: colour(r * tone, g * tone, b * tone), stroke: nil)
            // A fine edge, so that the grid of tiles reads.
            let inner = [CGPoint(x: w / 2, y: h - 1), CGPoint(x: w - 2, y: h / 2), CGPoint(x: w / 2, y: 1), CGPoint(x: 2, y: h / 2)]
            polygon(c, inner, fill: nil, stroke: colour(0, 0, 0, 0.13), width: 1)
            let mark = colour(r * 0.78, g * 0.78, b * 0.78, 0.8)
            switch terrain {
            case .grass:
                for (x, y) in [(22.0, 14.0), (40.0, 19.0), (33.0, 9.0)] {
                    line(c, CGPoint(x: x, y: y), CGPoint(x: x - 1, y: y + 3), mark, width: 1)
                    line(c, CGPoint(x: x, y: y), CGPoint(x: x + 2, y: y + 3), mark, width: 1)
                }
            case .dirt, .sand:
                for (x, y) in [(24.0, 17.0), (42.0, 13.0), (31.0, 8.0), (36.0, 22.0)] {
                    ellipse(c, CGRect(x: x, y: y, width: 2, height: 1.4), fill: mark, stroke: nil)
                }
            case .forest:
                for (x, y) in [(24.0, 15.0), (38.0, 20.0), (35.0, 10.0)] {
                    ellipse(c, CGRect(x: x - 3, y: y, width: 6, height: 4), fill: colour(0.15, 0.33, 0.16, 0.9), stroke: nil)
                }
            case .shallowWater, .deepWater:
                let wave = colour(1, 1, 1, terrain == .shallowWater ? 0.55 : 0.3)
                line(c, CGPoint(x: 22, y: 15), CGPoint(x: 29, y: 15), wave, width: 1)
                line(c, CGPoint(x: 36, y: 20), CGPoint(x: 43, y: 20), wave, width: 1)
                line(c, CGPoint(x: 30, y: 9), CGPoint(x: 37, y: 9), wave, width: 1)
            }
        }
        return dimmed ? darkened(image) : image
    }

    // MARK: People

    enum FigurePose { case standing, walking, working, fighting }

    static func figurePose(_ pose: SpritePose) -> FigurePose {
        switch pose.rawValue {
        case "walking": .walking
        case "working": .working
        case "fighting": .fighting
        default: .standing
        }
    }

    static let personCanvas = CGSize(width: 64, height: 64)
    static let personFoot = CGPoint(x: 32, y: 8)

    /// A figure in the team colour, with a mark per kind. Two frames per pose
    /// differ in the legs and in the swing of what the figure holds.
    static func person(_ kind: UnitKind, civilization: Civilization, pose: FigurePose, frame: Int) -> DrawnImage {
        let t = team(civilization)
        let body = shade(t, 1), bodyDark = shade(t, 0.65)
        let skin = colour(0.93, 0.76, 0.58)
        let fx = personFoot.x, fy = personFoot.y
        let swing = frame % 2 == 0 ? 1.0 : -1.0
        let lean = pose == .working ? 3.0 : (pose == .fighting ? 2.0 : 0.0)
        let image = render(personCanvas) { c in
            ellipse(c, CGRect(x: fx - 11, y: fy - 4, width: 22, height: 8), fill: colour(0, 0, 0, 0.25), stroke: nil)
            if kind == .chariot {
                drawChariot(c, team: t, frame: frame, moving: pose == .walking, fighting: pose == .fighting)
                return
            }
            let spread = pose == .walking ? 5.0 * swing : 2.5
            line(c, CGPoint(x: fx - 2, y: fy + 14), CGPoint(x: fx - 3 - spread, y: fy), ink, width: 3)
            line(c, CGPoint(x: fx + 2, y: fy + 14), CGPoint(x: fx + 3 + spread, y: fy), ink, width: 3)
            let bodyBottom = fy + 12, bodyTop = fy + 30
            polygon(c, [CGPoint(x: fx - 8 + lean, y: bodyTop), CGPoint(x: fx + 8 + lean, y: bodyTop),
                        CGPoint(x: fx + 6, y: bodyBottom), CGPoint(x: fx - 6, y: bodyBottom)], fill: body)
            line(c, CGPoint(x: fx - 6, y: bodyBottom + 3), CGPoint(x: fx + 6, y: bodyBottom + 3), bodyDark, width: 2)
            let head = CGPoint(x: fx + lean * 1.3, y: bodyTop + 8)
            ellipse(c, CGRect(x: head.x - 6.5, y: head.y - 6.5, width: 13, height: 13), fill: skin)
            // The hand, where the mark is held.
            let hand = CGPoint(x: fx + 11 + lean, y: fy + 22 + (pose == .fighting ? 6 * swing : (pose == .working ? 4 * swing : 0)))
            line(c, CGPoint(x: fx + 7 + lean, y: bodyTop - 3), hand, skin, width: 3)
            drawMark(c, kind: kind, hand: hand, head: head, fighting: pose == .fighting, swing: swing, team: t)
        }
        return DrawnImage(image: image, size: personCanvas,
                          anchor: CGPoint(x: personFoot.x / personCanvas.width, y: personFoot.y / personCanvas.height))
    }

    private static func drawMark(_ c: CGContext, kind: UnitKind, hand h: CGPoint, head: CGPoint, fighting: Bool, swing: Double, team t: TeamColour) {
        let wood = colour(0.45, 0.30, 0.15)
        let tilt = fighting ? 5 * swing : 0
        switch kind {
        case .worker:
            // A pick: a haft with a crossbar.
            line(c, CGPoint(x: h.x - 3 + tilt, y: h.y - 6), CGPoint(x: h.x + 3, y: h.y + 14), wood, width: 2.5)
            line(c, CGPoint(x: h.x - 4, y: h.y + 12), CGPoint(x: h.x + 10, y: h.y + 15), colour(0.55, 0.55, 0.58), width: 2.5)
        case .scholar:
            // A scroll.
            polygon(c, [CGPoint(x: h.x - 2, y: h.y - 2), CGPoint(x: h.x + 8, y: h.y - 2),
                        CGPoint(x: h.x + 8, y: h.y + 11), CGPoint(x: h.x - 2, y: h.y + 11)], fill: colour(0.96, 0.93, 0.80))
            line(c, CGPoint(x: h.x, y: h.y + 3), CGPoint(x: h.x + 6, y: h.y + 3), ink, width: 1)
            line(c, CGPoint(x: h.x, y: h.y + 7), CGPoint(x: h.x + 6, y: h.y + 7), ink, width: 1)
        case .engineer:
            // A hard hat, and a mallet.
            ellipse(c, CGRect(x: head.x - 7.5, y: head.y + 1, width: 15, height: 9), fill: colour(0.97, 0.80, 0.15))
            line(c, CGPoint(x: head.x - 8.5, y: head.y + 1.5), CGPoint(x: head.x + 8.5, y: head.y + 1.5), colour(0.8, 0.6, 0.1), width: 2)
            line(c, CGPoint(x: h.x, y: h.y - 4), CGPoint(x: h.x + 2, y: h.y + 10), wood, width: 2.5)
            polygon(c, [CGPoint(x: h.x - 3, y: h.y + 9), CGPoint(x: h.x + 7, y: h.y + 9),
                        CGPoint(x: h.x + 7, y: h.y + 15), CGPoint(x: h.x - 3, y: h.y + 15)], fill: colour(0.5, 0.5, 0.52))
        case .merchant:
            // A sack and a coin.
            ellipse(c, CGRect(x: h.x - 4, y: h.y - 4, width: 12, height: 13), fill: colour(0.78, 0.66, 0.42))
            ellipse(c, CGRect(x: h.x - 0.5, y: h.y + 11, width: 6, height: 6), fill: colour(0.98, 0.82, 0.2))
        case .founder:
            // A banner on a pole.
            line(c, CGPoint(x: h.x, y: h.y - 6), CGPoint(x: h.x, y: h.y + 26), wood, width: 2)
            polygon(c, [CGPoint(x: h.x, y: h.y + 26), CGPoint(x: h.x + 14, y: h.y + 21), CGPoint(x: h.x, y: h.y + 16)],
                    fill: colour(0.98, 0.90, 0.55))
        case .clubman:
            line(c, CGPoint(x: h.x - 2 + tilt, y: h.y - 4), CGPoint(x: h.x + 4, y: h.y + 14), wood, width: 3)
            ellipse(c, CGRect(x: h.x + 1, y: h.y + 11, width: 7, height: 8), fill: colour(0.35, 0.22, 0.10))
        case .slinger:
            ellipse(c, CGRect(x: h.x - 1, y: h.y + 4, width: 11, height: 11), fill: nil, stroke: colour(0.55, 0.40, 0.2), width: 1.5)
            ellipse(c, CGRect(x: h.x + 7, y: h.y + 12, width: 4, height: 4), fill: colour(0.5, 0.5, 0.5))
        case .spearman:
            line(c, CGPoint(x: h.x, y: h.y - 14), CGPoint(x: h.x + 3 + tilt, y: h.y + 28), wood, width: 2)
            polygon(c, [CGPoint(x: h.x + 1 + tilt, y: h.y + 26), CGPoint(x: h.x + 5 + tilt, y: h.y + 26),
                        CGPoint(x: h.x + 3 + tilt, y: h.y + 35)], fill: colour(0.7, 0.72, 0.75))
        case .archer:
            c.setStrokeColor(wood)
            c.setLineWidth(2)
            c.beginPath()
            c.addArc(center: CGPoint(x: h.x - 2, y: h.y + 6), radius: 11, startAngle: -1.1, endAngle: 1.1, clockwise: false)
            c.strokePath()
            line(c, CGPoint(x: h.x - 2 + 11 * cos(-1.1), y: h.y + 6 + 11 * sin(-1.1)),
                 CGPoint(x: h.x - 2 + 11 * cos(1.1), y: h.y + 6 + 11 * sin(1.1)), colour(0.9, 0.9, 0.85), width: 1)
        case .chariot, .swordsman, .horseman, .catapult, .knight, .musketeer, .cannon, .rifleman, .fieldGun, .armouredCar, .car, .boat:
            break
        }
    }

    private static func drawChariot(_ c: CGContext, team t: TeamColour, frame: Int, moving: Bool, fighting: Bool) {
        let fx = personFoot.x
        let bob = moving ? (frame % 2 == 0 ? 0.0 : 1.5) : 0.0
        let horse = colour(0.55, 0.38, 0.22)
        // The horse, on the right (the chariot faces right).
        ellipse(c, CGRect(x: fx + 4, y: 20 + bob, width: 22, height: 11), fill: horse)
        polygon(c, [CGPoint(x: fx + 22, y: 28 + bob), CGPoint(x: fx + 30, y: 38 + bob),
                    CGPoint(x: fx + 33, y: 34 + bob), CGPoint(x: fx + 27, y: 26 + bob)], fill: horse)
        for dx in [6.0, 10.0, 20.0, 24.0] {
            line(c, CGPoint(x: fx + dx, y: 22 + bob), CGPoint(x: fx + dx + (moving ? (frame % 2 == 0 ? 2 : -2) : 0), y: 10), ink, width: 2)
        }
        // The car, in the team colour, with a wheel.
        polygon(c, [CGPoint(x: fx - 20, y: 34), CGPoint(x: fx + 4, y: 34), CGPoint(x: fx + 2, y: 20), CGPoint(x: fx - 18, y: 20)],
                fill: shade(t, 1))
        line(c, CGPoint(x: fx + 4, y: 26), CGPoint(x: fx + 10, y: 27 + bob), ink, width: 1.5)
        ellipse(c, CGRect(x: fx - 17, y: 9, width: 14, height: 14), fill: colour(0.55, 0.38, 0.2))
        line(c, CGPoint(x: fx - 10, y: 9), CGPoint(x: fx - 10, y: 23), ink, width: 1)
        line(c, CGPoint(x: fx - 17, y: 16), CGPoint(x: fx - 3, y: 16), ink, width: 1)
        // The rider.
        ellipse(c, CGRect(x: fx - 13, y: 41, width: 10, height: 10), fill: colour(0.93, 0.76, 0.58))
        line(c, CGPoint(x: fx - 8, y: 35), CGPoint(x: fx - 8, y: 41), shade(t, 0.7), width: 5)
        line(c, CGPoint(x: fx - 4, y: 38), CGPoint(x: fx + 14, y: fighting ? 52 : 40), colour(0.45, 0.3, 0.15), width: 1.5)
    }

    // MARK: Buildings

    /// A building as its footprint's diamond with a block raised on it, in the team
    /// colour; the anchor is the centre of the diamond at ground level.
    static func building(_ kind: BuildingKind, civilization: Civilization, constructing: Bool, footprint: GridPoint) -> DrawnImage {
        let t = team(civilization)
        let fx = Double(footprint.x), fy = Double(footprint.y)
        let height = Stature.building(kind) * (constructing ? 0.7 : 1)
        let halfWidth = (fx + fy) * 16, halfHeight = (fx + fy) * 8, pad = 6.0
        let size = CGSize(width: 2 * halfWidth + 2 * pad, height: 2 * halfHeight + height + 34 + 2 * pad)
        let cx = size.width / 2, cy = pad + halfHeight

        func at(_ x: Double, _ y: Double, lift: Double = 0) -> CGPoint {
            let s = Projection.screen(MapPosition(x: x - fx / 2, y: y - fy / 2))
            return CGPoint(x: cx + s.x, y: cy + s.y + lift)
        }
        let inset = kind == .watchTower ? 0.22 : (kind == .palisade ? 0.08 : 0.12)
        let (x0, y0, x1, y1) = (inset, inset, fx - inset, fy - inset)

        let image = render(size) { c in
            // The ground under the footprint.
            let ground = kind == .stockPen ? colour(0.55, 0.66, 0.36) : colour(0.74, 0.66, 0.50)
            polygon(c, [at(0, 0), at(fx, 0), at(fx, fy), at(0, fy)], fill: ground, stroke: colour(0.35, 0.27, 0.18, 0.8))
            if constructing { c.setAlpha(0.62) }
            switch kind {
            case .storagePit:
                polygon(c, [at(0.25, 0.25), at(fx - 0.25, 0.25), at(fx - 0.25, fy - 0.25), at(0.25, fy - 0.25)],
                        fill: colour(0.22, 0.15, 0.10), stroke: shade(t, 0.9), width: 2.5)
                for (sx, sy) in [(0.45, 0.5), (0.55, 0.62), (0.7, 0.45)] {
                    let p = at(fx * sx, fy * sy, lift: 2)
                    ellipse(c, CGRect(x: p.x - 4, y: p.y - 2, width: 8, height: 7), fill: colour(0.75, 0.62, 0.40))
                }
            case .stockPen:
                let rails = [(at(x0, y0), at(x1, y0)), (at(x1, y0), at(x1, y1)), (at(x1, y1), at(x0, y1)), (at(x0, y1), at(x0, y0))]
                // The back rails first, then the front ones, over the animals' ground.
                for (a, b) in rails.prefix(1) + rails.suffix(1) { drawRail(c, a, b, height: height, team: t) }
                for (sx, sy) in [(0.35, 0.40), (0.6, 0.55)] {
                    let p = at(fx * sx, fy * sy)
                    ellipse(c, CGRect(x: p.x - 7, y: p.y, width: 14, height: 8), fill: colour(0.85, 0.82, 0.75))
                    ellipse(c, CGRect(x: p.x + 4, y: p.y + 4, width: 6, height: 6), fill: colour(0.85, 0.82, 0.75))
                }
                for (a, b) in rails.dropFirst().prefix(2) { drawRail(c, a, b, height: height, team: t) }
            default:
                let top = at(x0, y0, lift: height), right = at(x1, y0, lift: height)
                let bottom = at(x1, y1, lift: height), left = at(x0, y1, lift: height)
                let baseRight = at(x1, y0), baseBottom = at(x1, y1), baseLeft = at(x0, y1)
                polygon(c, [left, bottom, baseBottom, baseLeft], fill: shade(t, 0.82))
                polygon(c, [bottom, right, baseRight, baseBottom], fill: shade(t, 0.6))
                if kind == .house {
                    let apex = at(fx / 2, fy / 2, lift: height + 16)
                    polygon(c, [top, right, apex], fill: colour(0.50, 0.37, 0.20))
                    polygon(c, [left, bottom, apex], fill: colour(0.68, 0.52, 0.28))
                    polygon(c, [bottom, right, apex], fill: colour(0.55, 0.40, 0.22))
                } else {
                    polygon(c, [top, right, bottom, left], fill: shade(t, 1.12))
                }
                drawDetail(c, kind: kind, corners: (top, right, bottom, left, baseRight, baseBottom, baseLeft),
                           centre: at(fx / 2, fy / 2, lift: height), height: height, team: t)
            }
            c.setAlpha(1)
            if constructing {
                // The scaffold: a dashed outline of the footprint and braces across the walls.
                c.setLineDash(phase: 0, lengths: [5, 4])
                polygon(c, [at(0, 0), at(fx, 0), at(fx, fy), at(0, fy)], fill: nil, stroke: colour(0.35, 0.2, 0.05), width: 2)
                c.setLineDash(phase: 0, lengths: [])
                if kind != .storagePit {
                    line(c, at(x0, y1), at(x1, y1, lift: height), colour(0.4, 0.27, 0.1, 0.8), width: 1.5)
                    line(c, at(x1, y1), at(x0, y1, lift: height), colour(0.4, 0.27, 0.1, 0.8), width: 1.5)
                    line(c, at(x1, y1), at(x1, y0, lift: height), colour(0.4, 0.27, 0.1, 0.8), width: 1.5)
                }
            }
        }
        return DrawnImage(image: image, size: size, anchor: CGPoint(x: cx / size.width, y: cy / size.height))
    }

    private static func drawRail(_ c: CGContext, _ a: CGPoint, _ b: CGPoint, height: Double, team t: TeamColour) {
        let wood = colour(0.50, 0.35, 0.18)
        let posts = 4
        for i in 0...posts {
            let f = Double(i) / Double(posts)
            let p = CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
            line(c, p, CGPoint(x: p.x, y: p.y + height), wood, width: 2.5)
        }
        line(c, CGPoint(x: a.x, y: a.y + height), CGPoint(x: b.x, y: b.y + height), shade(t, 0.95), width: 3)
        line(c, CGPoint(x: a.x, y: a.y + height * 0.45), CGPoint(x: b.x, y: b.y + height * 0.45), wood, width: 2)
    }

    private static func drawDetail(_ c: CGContext, kind: BuildingKind,
                                   corners: (top: CGPoint, right: CGPoint, bottom: CGPoint, left: CGPoint,
                                             baseRight: CGPoint, baseBottom: CGPoint, baseLeft: CGPoint),
                                   centre: CGPoint, height: Double, team t: TeamColour) {
        func onRightFace(_ u: Double, _ v: Double) -> CGPoint {
            // u along the face from the bottom corner to the right corner, v up it, as fractions.
            let b = corners.baseBottom, r = corners.baseRight
            return CGPoint(x: b.x + (r.x - b.x) * u, y: b.y + (r.y - b.y) * u + height * v)
        }
        func onLeftFace(_ u: Double, _ v: Double) -> CGPoint {
            let b = corners.baseBottom, l = corners.baseLeft
            return CGPoint(x: b.x + (l.x - b.x) * u, y: b.y + (l.y - b.y) * u + height * v)
        }
        let light = colour(1, 1, 0.95, 0.9)
        switch kind {
        case .townCentre:
            // A door on each wall and a banner on the roof.
            polygon(c, [onRightFace(0.38, 0), onRightFace(0.62, 0), onRightFace(0.62, 0.5), onRightFace(0.38, 0.5)],
                    fill: colour(0.2, 0.13, 0.08))
            polygon(c, [onLeftFace(0.38, 0), onLeftFace(0.62, 0), onLeftFace(0.62, 0.5), onLeftFace(0.38, 0.5)],
                    fill: colour(0.2, 0.13, 0.08))
            line(c, centre, CGPoint(x: centre.x, y: centre.y + 26), colour(0.4, 0.3, 0.2), width: 2)
            polygon(c, [CGPoint(x: centre.x, y: centre.y + 26), CGPoint(x: centre.x + 16, y: centre.y + 20),
                        CGPoint(x: centre.x, y: centre.y + 14)], fill: shade(t, 1.25))
        case .house:
            polygon(c, [onRightFace(0.4, 0), onRightFace(0.6, 0), onRightFace(0.6, 0.55), onRightFace(0.4, 0.55)],
                    fill: colour(0.2, 0.13, 0.08))
        case .barracks:
            line(c, onRightFace(0.22, 0.2), onRightFace(0.78, 0.8), light, width: 2.5)
            line(c, onRightFace(0.22, 0.8), onRightFace(0.78, 0.2), light, width: 2.5)
            line(c, onLeftFace(0.22, 0.2), onLeftFace(0.78, 0.8), light, width: 2)
        case .watchTower:
            for corner in [corners.top, corners.right, corners.bottom, corners.left] {
                polygon(c, [CGPoint(x: corner.x - 3, y: corner.y), CGPoint(x: corner.x + 3, y: corner.y),
                            CGPoint(x: corner.x + 3, y: corner.y + 6), CGPoint(x: corner.x - 3, y: corner.y + 6)],
                        fill: shade(t, 0.75))
            }
            polygon(c, [onRightFace(0.4, 0.55), onRightFace(0.6, 0.55), onRightFace(0.6, 0.8), onRightFace(0.4, 0.8)],
                    fill: colour(0.15, 0.1, 0.07))
        case .palisade:
            for i in 1..<5 {
                let u = Double(i) / 5
                line(c, onRightFace(u, 0.05), onRightFace(u, 1), colour(0.2, 0.12, 0.05, 0.7), width: 1)
                line(c, onLeftFace(u, 0.05), onLeftFace(u, 1), colour(0.2, 0.12, 0.05, 0.7), width: 1)
            }
        case .storagePit, .stockPen, .farm, .stable, .siegeWorkshop, .stoneWall, .castle, .alchemistsWorkshop, .factory, .railwayDepot, .oilWell, .bridge, .boatHouse:
            break
        }
    }

    // MARK: Sites

    static let siteCanvas = CGSize(width: 64, height: 64)
    static let siteGround = CGPoint(x: 32, y: 14)

    /// A site as a shape per kind, standing on its tile.
    /// Plain rock on a deposit not yet revealed: darker and lower than a stone
    /// site, so that it is not taken for stone to quarry.
    static func outcrop() -> DrawnImage {
        let gx = siteGround.x, gy = siteGround.y
        let image = render(siteCanvas) { c in
            ellipse(c, CGRect(x: gx - 17, y: gy - 6, width: 34, height: 12), fill: colour(0, 0, 0, 0.22), stroke: nil)
            polygon(c, [CGPoint(x: gx - 18, y: gy), CGPoint(x: gx - 11, y: gy + 9), CGPoint(x: gx + 1, y: gy + 13),
                        CGPoint(x: gx + 13, y: gy + 10), CGPoint(x: gx + 18, y: gy + 2), CGPoint(x: gx + 8, y: gy - 3)],
                    fill: colour(0.42, 0.40, 0.37))
            polygon(c, [CGPoint(x: gx + 1, y: gy + 13), CGPoint(x: gx + 13, y: gy + 10), CGPoint(x: gx + 18, y: gy + 2),
                        CGPoint(x: gx + 3, y: gy + 3)], fill: colour(0, 0, 0, 0.2), stroke: nil)
        }
        return DrawnImage(image: image, size: siteCanvas,
                          anchor: CGPoint(x: siteGround.x / siteCanvas.width, y: siteGround.y / siteCanvas.height))
    }

    static func site(_ kind: SiteKind) -> DrawnImage {
        let gx = siteGround.x, gy = siteGround.y
        let rock = { (c: CGContext, base: CGColor) in
            polygon(c, [CGPoint(x: gx - 17, y: gy), CGPoint(x: gx - 12, y: gy + 16), CGPoint(x: gx - 2, y: gy + 24),
                        CGPoint(x: gx + 11, y: gy + 19), CGPoint(x: gx + 18, y: gy + 4), CGPoint(x: gx + 10, y: gy - 3)], fill: base)
            polygon(c, [CGPoint(x: gx - 2, y: gy + 24), CGPoint(x: gx + 11, y: gy + 19), CGPoint(x: gx + 18, y: gy + 4),
                        CGPoint(x: gx + 2, y: gy + 6)], fill: colour(0, 0, 0, 0.18), stroke: nil)
        }
        let image = render(siteCanvas) { c in
            ellipse(c, CGRect(x: gx - 17, y: gy - 6, width: 34, height: 12), fill: colour(0, 0, 0, 0.22), stroke: nil)
            switch kind {
            case .tree:
                polygon(c, [CGPoint(x: gx - 3, y: gy), CGPoint(x: gx + 3, y: gy), CGPoint(x: gx + 2.5, y: gy + 22), CGPoint(x: gx - 2.5, y: gy + 22)],
                        fill: colour(0.40, 0.27, 0.14))
                ellipse(c, CGRect(x: gx - 19, y: gy + 14, width: 18, height: 18), fill: colour(0.18, 0.46, 0.20))
                ellipse(c, CGRect(x: gx + 1, y: gy + 14, width: 18, height: 18), fill: colour(0.20, 0.50, 0.22))
                ellipse(c, CGRect(x: gx - 13, y: gy + 22, width: 26, height: 26), fill: colour(0.24, 0.57, 0.26))
            case .stone:
                rock(c, colour(0.66, 0.66, 0.64))
            case .copper:
                rock(c, colour(0.55, 0.48, 0.42))
                for (x, y) in [(-8.0, 8.0), (2.0, 14.0), (8.0, 6.0)] {
                    polygon(c, [CGPoint(x: gx + x, y: gy + y), CGPoint(x: gx + x + 4, y: gy + y + 3),
                                CGPoint(x: gx + x + 2, y: gy + y + 8), CGPoint(x: gx + x - 2, y: gy + y + 4)], fill: colour(0.86, 0.47, 0.22))
                }
            case .tin:
                rock(c, colour(0.50, 0.53, 0.58))
                for (x, y) in [(-8.0, 8.0), (2.0, 14.0), (8.0, 6.0)] {
                    polygon(c, [CGPoint(x: gx + x, y: gy + y), CGPoint(x: gx + x + 4, y: gy + y + 3),
                                CGPoint(x: gx + x + 2, y: gy + y + 8), CGPoint(x: gx + x - 2, y: gy + y + 4)], fill: colour(0.78, 0.86, 0.95))
                }
            case .gold:
                rock(c, colour(0.60, 0.52, 0.38))
                for (x, y) in [(-9.0, 7.0), (0.0, 13.0), (8.0, 5.0)] {
                    ellipse(c, CGRect(x: gx + x - 3, y: gy + y, width: 7, height: 6), fill: colour(1, 0.82, 0.18))
                }
            case .iron:
                rock(c, colour(0.30, 0.32, 0.38))
                for (x, y) in [(-8.0, 7.0), (1.0, 12.0)] {
                    line(c, CGPoint(x: gx + x, y: gy + y), CGPoint(x: gx + x + 9, y: gy + y + 4), colour(0.62, 0.30, 0.20), width: 3)
                }
            case .prey:
                let hide = colour(0.64, 0.46, 0.28)
                for dx in [-8.0, -3.0, 6.0, 10.0] {
                    line(c, CGPoint(x: gx + dx, y: gy + 10), CGPoint(x: gx + dx, y: gy), ink, width: 2)
                }
                ellipse(c, CGRect(x: gx - 13, y: gy + 8, width: 28, height: 13), fill: hide)
                polygon(c, [CGPoint(x: gx + 10, y: gy + 17), CGPoint(x: gx + 16, y: gy + 26),
                            CGPoint(x: gx + 20, y: gy + 24), CGPoint(x: gx + 15, y: gy + 14)], fill: hide)
                line(c, CGPoint(x: gx + 17, y: gy + 26), CGPoint(x: gx + 15, y: gy + 33), colour(0.4, 0.28, 0.15), width: 1.5)
                line(c, CGPoint(x: gx + 19, y: gy + 25), CGPoint(x: gx + 21, y: gy + 32), colour(0.4, 0.28, 0.15), width: 1.5)
            case .oilField:
                ellipse(c, CGRect(x: gx - 17, y: gy - 3, width: 34, height: 15), fill: colour(0.06, 0.06, 0.08))
                ellipse(c, CGRect(x: gx - 9, y: gy + 3, width: 10, height: 4), fill: colour(0.3, 0.3, 0.45, 0.8), stroke: nil)
            case .fish:
                // Silver fish leaping from rings on the water.
                for (x, y) in [(-9.0, 6.0), (6.0, 10.0)] {
                    ellipse(c, CGRect(x: gx + x - 6, y: gy + y - 2, width: 12, height: 4), fill: nil, stroke: colour(0.85, 0.92, 0.98))
                    ellipse(c, CGRect(x: gx + x - 3, y: gy + y + 3, width: 7, height: 3.4), fill: colour(0.78, 0.82, 0.86))
                }
            }
        }
        return DrawnImage(image: image, size: siteCanvas,
                          anchor: CGPoint(x: siteGround.x / siteCanvas.width, y: siteGround.y / siteCanvas.height))
    }
}
