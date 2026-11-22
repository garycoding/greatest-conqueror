// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
import Synchronization

// The buildings of the Stone age, in the Stone-age look (docs/art-style.md):
// the town centre, the house, the storage pit and the boat house, each complete
// and under construction, and the boat house seen from behind as well. This
// file holds the batch's source and the drawing kit the buildings share; each
// building is drawn in a file of its own.

/// The sprites of the Stone age's buildings: `SpriteSubject.building(kind,
/// .stone)` for the town centre, the house, the storage pit and the boat house
/// (ruled 2026-11-21), in the poses
/// `complete` and `underConstruction`, at frame 0 (buildings do not move), seen
/// from the side; the boat house also from behind (`SpriteView.back`), so that
/// it can face water on any edge of its footprint (ruled 2026-11-22).
/// Every other key gives nil. A picture is drawn the first time it is asked for
/// and kept, so that a caller that asks on every redraw pays for a look-up.
public struct StoneBuildingSprites: ViewedSpriteSource {
    private let kept = StoneBuildingsKept()

    public init() {}

    /// Only the boat house is drawn in a view other than the side: from behind.
    public func drawsViews(of subject: SpriteSubject) -> Bool { subject == .building(.boatHouse, .stone) }

    public func sprite(_ key: SpriteKey) -> SpriteImage? {
        guard let piece = StoneBuildingsPiece(key) else { return nil }
        if let known = kept.images.withLock({ $0[piece] }) { return known }
        guard let made = piece.render() else { return nil }
        return kept.images.withLock { images in
            if let first = images[piece] { return first }
            images[piece] = made
            return made
        }
    }
}

/// The pictures drawn so far, safe to share between the threads that ask.
final class StoneBuildingsKept: Sendable {
    let images = Mutex<[StoneBuildingsPiece: SpriteImage]>([:])
}

/// One of the batch's pictures: a kind of building, complete or under
/// construction, seen from the side or (the boat house alone) from behind.
struct StoneBuildingsPiece: Hashable, Sendable {
    var kind: BuildingKind
    var complete: Bool
    /// Seen from behind (`SpriteView.back`) rather than from the side.
    var back: Bool

    /// The kinds this batch draws.
    static let kinds: [BuildingKind] = [.townCentre, .house, .storagePit, .boatHouse]

    init(kind: BuildingKind, complete: Bool, back: Bool = false) {
        self.kind = kind
        self.complete = complete
        self.back = back
    }

    /// The piece a key names, or nil where the key is not this batch's.
    init?(_ key: SpriteKey) {
        guard key.frame == 0, case .building(let kind, .stone) = key.subject,
              StoneBuildingsPiece.kinds.contains(kind) else { return nil }
        switch key.pose {
        case .complete: complete = true
        case .underConstruction: complete = false
        default: return nil
        }
        switch key.view {
        case .side: back = false
        case .back where kind == .boatHouse: back = true
        default: return nil
        }
        self.kind = kind
    }

    /// The part of the picture's plane the sprite covers, in points, with the
    /// origin on the ground at the centre of the footprint, drawn at twice its
    /// size (docs/architecture.md, "Sprites"). Both poses and both views of a
    /// kind share it, so that the grain is made once for each kind.
    var canvas: Canvas {
        switch kind {
        case .townCentre: Canvas(minX: -100, minY: -128, width: 200, height: 180, pixelsPerUnit: 2)
        case .storagePit: Canvas(minX: -68, minY: -92, width: 136, height: 128, pixelsPerUnit: 2)
        // The boat house's canvas reaches past the footprint for its dock
        // (ruled 2026-11-22): 16 points to the right and 10 down, as in every age.
        case .boatHouse: Canvas(minX: -68, minY: -108, width: 152, height: 154, pixelsPerUnit: 2)
        default: Canvas(minX: -68, minY: -108, width: 136, height: 144, pixelsPerUnit: 2)
        }
    }

    /// The picture and its team-colour mask, anchored at the centre of the footprint.
    func render() -> SpriteImage? {
        let canvas = self.canvas
        let drawn = Raster.render(on: canvas) { svg in
            var sketch = StoneBuildingsSketch(layer: svg.layer)
            switch kind {
            case .townCentre: sketch.townCentre(complete: complete)
            case .storagePit: sketch.storagePit(complete: complete)
            case .boatHouse: if back { sketch.boatHouseBack(complete: complete) } else { sketch.boatHouse(complete: complete) }
            default: sketch.house(complete: complete)
            }
            svg = sketch.svg
        }
        return drawn?.sprite(anchor: canvas.anchor)
    }
}

/// The colours of the Stone age's buildings: the age's palette (`Ink`), and the
/// few shades derived from it that a building needs for its shaded faces,
/// its hollows and its fire.
enum StoneBuildingsInk {
    /// Trodden ground under a building: the age's ground, darkened and warmed.
    static let earth = "#b5a39b"
    /// Dug earth, and the inner wall of a pit.
    static let earthDark = "#6e5853"
    /// A doorway, or the depth of a pit.
    static let hollow = "#3b2d27"
    /// Thatch is the hide colour; its shaded side and its cut ends are darker.
    static let thatchShade = "#9f6b3d"
    static let thatchDeep = "#86592f"
    /// Straw cut for thatching, before it weathers to the hide colour.
    static let straw = "#d9b47e"
    /// Daub on a wall in shade.
    static let daubShade = "#d9c39d"
    /// The cut end of a log.
    static let woodEnd = "#b98a58"
    /// Every other sapling of a roof of saplings, a little lighter than the wood.
    static let saplingLight = "#9c6a3d"
    /// Stone in shade.
    static let stoneShade = "#978f81"
    /// The fire's flame, around a core in the light colour.
    static let ember = "#d9823f"
}

/// A path that is drawn twice: its colour shifted out of register, then its
/// line in place.
struct StoneBuildingsOutline {
    private enum Step { case move(P), line(P), quad(P, P), close }
    private var steps: [Step] = []

    init() {}

    init(_ points: [P], closed: Bool = true) {
        move(points[0])
        for p in points.dropFirst() { line(p) }
        if closed { close() }
    }

    mutating func move(_ p: P) { steps.append(.move(p)) }
    mutating func line(_ p: P) { steps.append(.line(p)) }
    mutating func lines(_ points: [P]) { for p in points { line(p) } }
    mutating func quad(_ c: P, _ p: P) { steps.append(.quad(c, p)) }
    mutating func close() { steps.append(.close) }

    func data(shifted by: P = P(0, 0)) -> PathData {
        var d = PathData()
        for step in steps {
            switch step {
            case .move(let p): d.move(p + by)
            case .line(let p): d.line(p + by)
            case .quad(let c, let p): d.quad(c + by, p + by)
            case .close: d.close()
            }
        }
        return d
    }
}

/// A building being drawn, in points with y downward and the origin on the
/// ground at the centre of the footprint, so that the origin is the sprite's
/// anchor (docs/architecture.md, "Sprites").
struct StoneBuildingsSketch {
    var svg: SVG

    init(layer: Layer) { svg = SVG(layer: layer) }

    /// How far a colour sits out of register with its line, in points: down and
    /// to the left, as in the reference drawings (docs/art/).
    static let register = P(-1.3, 0.9)
    /// The smaller shift of small parts: poles, stones, pots.
    static let nudge = P(-0.7, 0.5)

    // MARK: Geometry

    /// The point `h` points above the ground at (`x`, `y`) tiles from the centre
    /// of the footprint, in the game's projection (`Projection`).
    static func at(_ x: Double, _ y: Double, _ h: Double = 0) -> P {
        P((x - y) * Projection.tileWidth / 2, (x + y) * Projection.tileHeight / 2 - h)
    }

    static func length(_ p: P) -> Double { (p.x * p.x + p.y * p.y).squareRoot() }

    static func unit(_ p: P) -> P {
        let l = length(p)
        return l > 0 ? p * (1 / l) : P(0, 0)
    }

    /// Points along an ellipse about `c` from `from` to `to` degrees, measured
    /// from the right toward the viewer (90 is the point nearest the viewer).
    static func arc(_ c: P, _ rx: Double, _ ry: Double, from: Double, to: Double) -> [P] {
        let steps = max(2, Int((abs(to - from) / 5).rounded(.up)))
        return (0...steps).map { i in
            let a = (from + (to - from) * Double(i) / Double(steps)) * .pi / 180
            return P(c.x + rx * cos(a), c.y + ry * sin(a))
        }
    }

    /// A rounded lump about `c`, a little irregular: a stone, a heap, a bush.
    /// `turn` varies the irregularity from one lump to the next.
    static func lump(_ c: P, _ rx: Double, _ ry: Double, turn: Int = 0) -> StoneBuildingsOutline {
        let wobble = [1.0, 0.86, 1.05, 0.93, 1.08, 0.88, 0.97]
        let n = wobble.count
        let points = (0..<n).map { i -> P in
            let a = (Double(i) / Double(n) * 360 + Double(turn * 23)) * .pi / 180
            let k = wobble[(i + turn) % n]
            return P(c.x + rx * k * cos(a), c.y + ry * k * sin(a))
        }
        var o = StoneBuildingsOutline()
        o.move((points[n - 1] + points[0]) * 0.5)
        for i in 0..<n { o.quad(points[i], (points[i] + points[(i + 1) % n]) * 0.5) }
        o.close()
        return o
    }

    // MARK: Drawing

    /// A shape: its colour out of register, then its line over it.
    mutating func shape(_ outline: StoneBuildingsOutline, _ fill: Paint, line: Double = 1.2,
                        shift: P = StoneBuildingsSketch.register) {
        svg.path(outline.data(shifted: shift), fill: fill)
        svg.path(outline.data(), stroke: .colour(Ink.line), width: line)
    }

    mutating func shape(_ points: [P], _ fill: Paint, line: Double = 1.2, shift: P = StoneBuildingsSketch.register) {
        shape(StoneBuildingsOutline(points), fill, line: line, shift: shift)
    }

    /// Colour alone, with no line: ground, shade, and paint on a surface.
    mutating func colour(_ outline: StoneBuildingsOutline, _ fill: Paint, shift: P = StoneBuildingsSketch.register,
                         opacity: Double = 1) {
        svg.path(outline.data(shifted: shift), fill: fill, opacity: opacity)
    }

    mutating func colour(_ points: [P], _ fill: Paint, shift: P = StoneBuildingsSketch.register, opacity: Double = 1) {
        colour(StoneBuildingsOutline(points), fill, shift: shift, opacity: opacity)
    }

    /// A line alone.
    mutating func stroke(_ outline: StoneBuildingsOutline, width: Double = 1.2, colour: String = Ink.line,
                         opacity: Double = 1) {
        svg.path(outline.data(), stroke: .colour(colour), width: width, opacity: opacity)
    }

    mutating func stroke(_ points: [P], width: Double = 1.2, colour: String = Ink.line, opacity: Double = 1) {
        svg.line(points, stroke: .colour(colour), width: width, opacity: opacity)
    }

    /// A shadow on the ground: the line's colour, thinly.
    mutating func shadow(_ outline: StoneBuildingsOutline, opacity: Double = 0.16) {
        svg.path(outline.data(), fill: .colour(Ink.line), opacity: opacity)
    }

    /// A timber from `a` to `b`, `width` thick: its colour a little out of
    /// register, then its line.
    mutating func pole(_ a: P, _ b: P, width: Double, colour: String = Ink.wood, line: Double = 1) {
        let n = StoneBuildingsSketch.unit(P(a.y - b.y, b.x - a.x)) * (width / 2)
        shape([a + n, b + n, b - n, a - n], .colour(colour), line: line, shift: StoneBuildingsSketch.nudge)
    }

    /// A row of small scallops through the points, each bulging by `bulge(p)`
    /// at its middle `p`: the courses of thatch, or the ragged ends of straw.
    mutating func scallops(_ points: [P], width: Double = 0.9, colour: String = Ink.line, opacity: Double = 1,
                           bulge: (P) -> P) {
        var d = PathData()
        d.move(points[0])
        for (p, q) in zip(points, points.dropFirst()) {
            let middle = (p + q) * 0.5
            d.quad(middle + bulge(middle) * 2, q)
        }
        svg.path(d, stroke: .colour(colour), width: width, opacity: opacity)
    }

    /// A zigzag through the points, every other one moved by `tooth`: pattern
    /// painted on a wall, a band or a cloth.
    mutating func zigzag(_ points: [P], tooth: P, width: Double = 1, colour: String = Ink.line) {
        var d = PathData()
        for (i, p) in points.enumerated() {
            let q = i % 2 == 1 ? p + tooth : p
            if i == 0 { d.move(q) } else { d.line(q) }
        }
        svg.path(d, stroke: .colour(colour), width: width)
    }

    /// `count + 1` points evenly spaced from `a` to `b`.
    static func points(from a: P, to b: P, count: Int) -> [P] {
        (0...count).map { a + (b - a) * (Double($0) / Double(count)) }
    }

    /// The trodden ground of a footprint `size` tiles square: a flat shape
    /// without a line, a little inside the footprint's diamonds, its corners
    /// rounded and its sides not ruled, so that it reads as ground rather than
    /// as a tile.
    mutating func earth(_ size: Int) {
        let half = Double(size) / 2 - 0.05
        let corners = [StoneBuildingsSketch.at(-half, -half, 0), StoneBuildingsSketch.at(half, -half, 0),
                       StoneBuildingsSketch.at(half, half, 0), StoneBuildingsSketch.at(-half, half, 0)]
        // How far each side bows out (positive) or in, in points.
        let bows = [1.6, -1.1, 1.9, -1.5]
        let round = 0.14
        var o = StoneBuildingsOutline()
        for i in 0..<4 {
            let a = corners[i], b = corners[(i + 1) % 4], next = corners[(i + 2) % 4]
            let start = a + (b - a) * round, end = b + (a - b) * round
            if i == 0 { o.move(start) }
            let outward = StoneBuildingsSketch.unit(P(b.y - a.y, a.x - b.x))
            o.quad((start + end) * 0.5 + outward * (bows[i] * 2), end)
            o.quad(b, b + (next - b) * round)
        }
        o.close()
        colour(o, .colour(StoneBuildingsInk.earth), shift: P(0, 0))
    }

    /// A pole whose foot is at `foot`, `height` points tall, flying a
    /// swallowtail pennant in the team's colour from its top, with a sun on the
    /// cloth in the light colour, as the people's banner has it (Props.swift).
    mutating func pennant(at foot: P, height: Double, size: Double = 1) {
        let top = foot - P(0, height)
        pole(foot, top, width: 2.2, colour: Ink.handle)
        let length = 18 * size, depth = 12 * size
        var cloth = StoneBuildingsOutline()
        let t = top + P(0.6, 1.6)
        cloth.move(t)
        cloth.quad(t + P(length * 0.5, -2.4 * size), t + P(length, 0.6 * size))
        cloth.line(t + P(length * 0.68, depth * 0.5))
        cloth.line(t + P(length, depth))
        cloth.quad(t + P(length * 0.5, depth + 1.8 * size), t + P(0, depth))
        cloth.close()
        colour(cloth, .team, shift: StoneBuildingsSketch.nudge)
        svg.circle(t + P(length * 0.34, depth * 0.47), 2.3 * size, fill: .colour(Ink.light))
        stroke(cloth, width: 1.1)
        // The finial: a stone point.
        shape([top + P(-1.8, 0.6), top + P(0, -3.6), top + P(1.8, 0.6)], .colour(Ink.stone), line: 0.9,
              shift: StoneBuildingsSketch.nudge)
    }

    /// Elements drawn with the origin moved to `origin`.
    mutating func moved(to origin: P, _ content: (inout StoneBuildingsSketch) -> Void) {
        svg.raw("<g transform=\"translate(\(num(origin.x)),\(num(origin.y)))\">")
        content(&self)
        svg.raw("</g>")
    }
}
