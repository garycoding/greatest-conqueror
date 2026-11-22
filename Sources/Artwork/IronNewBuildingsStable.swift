// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Iron-age stable: a long range of stalls along the back of its yard, of
// planked timber on a footing of dressed stone, under a roof of red tile. Each
// stall has a door in two leaves, its lower leaf painted in the owner's
// colour, and horses look out over two of them. Hay shows at the loft door in
// the gable; a rick of hay, a stone trough of water and a hitching rail stand
// in the yard, behind a fence of posts and rails whose gate flies the owner's
// pennants. Its footprint is three tiles square: x and y run from -1.5 to 1.5.

extension IronNewBuildingsPainter {
    mutating func stable(complete: Bool) {
        typealias I = IronNewBuildingsInk
        block(-1.5, -1.5, 1.5, 1.5, 0, 1.5, top: .colour(I.earth), left: .colour(I.earthShade), right: .colour(I.earthShade),
              width: 1)
        straw(on: 1.5)
        if complete { stableRange() } else { stableRising() }
    }

    private static let rangeBox = (x0: -1.36, y0: -1.36, x1: 1.36, y1: -0.3)
    private static let footing = 9.0
    private static let eave = 31.0
    /// The middles of the stalls' doors, in points along the front wall, and their width.
    private static let doors: [Double] = (0..<4).map { (Double($0) + 0.5) * (2.72 * 32) / 4 }
    private static let doorWidth = 12.0

    /// Wisps of straw over the yard, at fixed places.
    private mutating func straw(on h: Double) {
        typealias I = IronNewBuildingsInk
        let places: [(Double, Double, Double)] = [
            (-1.1, 0.2, 20), (-0.7, 0.9, -15), (-0.2, 0.0, 10), (0.3, 0.6, 35), (0.9, 0.1, -25), (1.1, 1.0, 5),
            (-1.2, 1.1, 30), (0.2, 1.15, -10), (-0.4, 0.5, 15), (0.6, -0.05, -30),
        ]
        var d = PathData()
        for (x, y, turn) in places {
            let c = iso(x, y, h)
            let u = P.direction(90 + turn) * 2.6
            d.move(c - u); d.line(c + u)
            d.move(c - u + P(0.8, 1)); d.line(c + u * 0.6 + P(0.8, 1))
        }
        svg.path(d, stroke: .colour(I.strawShade), width: 0.8)
    }

    private mutating func stableRange() {
        typealias I = IronNewBuildingsInk
        let (x0, y0, x1, y1) = Self.rangeBox
        let h0 = 1.5, f = Self.footing, eave = Self.eave, ridge = 49.0
        let length = (x1 - x0) * 32, depth = (y1 - y0) * 32
        shadow([iso(x1, y0, h0), iso(x1 + 0.3, y0 + 0.16, h0), iso(x1 + 0.3, y1 + 0.12, h0), iso(x1, y1, h0)])
        ashlar(x0, y0, x1, y1, h0, f, course: 3.75, stone: 8)
        block(x0, y0, x1, y1, f, eave, top: nil, left: .colour(I.timberLight), right: .colour(I.timber), width: 1.1)
        wall(.left, from: x0, y1, at: f) { p in p.planking(length, eave - f, posts: Self.doors.dropFirst().map { $0 - length / 8 }) }
        wall(.right, from: x1, y1, at: f) { p in p.planking(depth, eave - f, posts: [depth / 2]) }
        // The stalls' doors, cut through the footing and the planking.
        wall(.left, from: x0, y1, at: h0) { p in
            for (k, u) in Self.doors.enumerated() { p.stallDoor(at: u, open: k == 1 || k == 3) }
            // A horseshoe of iron over the first door, for luck.
            let u = Self.doors[0]
            let shoe = [p.uv(u - 1.6, 20.4), p.uv(u - 2, 23.6), p.uv(u, 23.8), p.uv(u + 2, 23.6), p.uv(u + 1.6, 20.4)]
            p.line(width: 1.2) { d in
                d.move(shoe[0]); d.quad(shoe[1], shoe[2]); d.quad(shoe[3], shoe[4])
            }
        }
        gabledRoof(x0, y0, x1, y1, eave: eave, ridge: ridge, gableWall: .colour(I.timber)) { p, w, rise in
            // Planks on the gable, and the loft door with hay showing at it.
            for u in stride(from: 3.4, to: w - 1, by: 3.4) {
                let top = rise * (1 - abs(u - w / 2) / (w / 2)) - 0.6
                if top > 0.6 { p.line([p.uv(u, 0.4), p.uv(u, top)], width: 0.45, opacity: 0.7) }
            }
            p.shape(p.panel(w / 2 - 4.4, 1, w / 2 + 4.4, 10), .colour(I.dark), width: 0.8)
            let hay = [p.uv(w / 2 - 4.4, 1), p.uv(w / 2 - 4.4, 5), p.uv(w / 2 - 2, 8), p.uv(w / 2 + 1, 6.4), p.uv(w / 2 + 3.4, 7.6),
                       p.uv(w / 2 + 4.4, 4.4), p.uv(w / 2 + 4.4, 1)]
            p.colour(.colour(I.straw)) { d, o in
                d.move(hay[0] + o)
                d.line(hay[1] + o)
                d.quad(hay[2] + o, hay[3] + o)
                d.quad(hay[4] + o, hay[5] + o)
                d.line(hay[6] + o)
                d.close()
            }
            p.line([p.uv(w / 2 - 3.6, 3.4), p.uv(w / 2 - 2.4, 6.4)], width: 0.45)
            p.line([p.uv(w / 2 + 0.4, 2.6), p.uv(w / 2 + 1.2, 5.6)], width: 0.45)
            p.line([p.uv(w / 2 + 2.6, 2.2), p.uv(w / 2 + 3.4, 4.8)], width: 0.45)
            p.colour(p.panel(w / 2 - 5.4, 10, w / 2 + 5.4, 11.4), .colour(I.timberDark))
            p.line(p.panel(w / 2 - 5.4, 10, w / 2 + 5.4, 11.4), closed: true, width: 0.6)
        }
        // The horses looking out over the open doors.
        for k in [1, 3] {
            let x = x0 + Self.doors[k] / 32
            horseHead(at: iso(x - 0.04, y1 + 0.02, h0 + 9.2), facing: -1)
        }
        pennant(at: iso(x1 + 0.08, (y0 + y1) / 2, ridge - 1), height: 14, length: 15)
        yard()
    }

    /// Planks running up a wall drawn with `wall`, `length` long and `height`
    /// tall, with the uprights of the frame at `posts`.
    private mutating func planking(_ length: Double, _ height: Double, posts: [Double]) {
        typealias I = IronNewBuildingsInk
        var d = PathData()
        for u in stride(from: 3.2, to: length - 1, by: 3.2) { d.move(uv(u, 0.5)); d.line(uv(u, height - 0.5)) }
        svg.path(d, stroke: .colour(I.line), width: 0.45, opacity: 0.55)
        for u in posts {
            colour(panel(u - 1.5, 0, u + 1.5, height), .colour(I.timberDark))
            line([uv(u - 1.5, 0), uv(u - 1.5, height)], width: 0.6)
            line([uv(u + 1.5, 0), uv(u + 1.5, height)], width: 0.6)
        }
        // The wall plate under the eaves.
        colour(panel(0, height - 2.4, length, height), .colour(I.timberDark))
        line([uv(0, height - 2.4), uv(length, height - 2.4)], width: 0.6)
    }

    /// A stall's door at `u` on the front wall: a dark opening with a lintel of
    /// timber, its lower leaf in the owner's colour, braced and hinged with
    /// iron, and its upper leaf folded back when `open`, or shut.
    private mutating func stallDoor(at u: Double, open: Bool) {
        typealias I = IronNewBuildingsInk
        let r = Self.doorWidth / 2, top = 18.0, half = 9.0
        shape(panel(u - r, 0, u + r, top), .colour(I.dark), width: 0.9)
        // The lower leaf.
        shape(panel(u - r + 0.6, 0, u + r - 0.6, half), .team, width: 0.8)
        line([uv(u - r + 1.4, 1.2), uv(u + r - 1.4, half - 1.2)], width: 0.7)
        line([uv(u - r + 0.6, half - 1.4), uv(u + r - 0.6, half - 1.4)], width: 0.6)
        for v in [2.4, half - 2.8] {
            shape(panel(u - r + 0.6, v - 0.5, u - r + 4.2, v + 0.5), .colour(I.iron), width: 0.4)
        }
        if open {
            // The upper leaf folded back against the wall.
            shape(panel(u + r + 0.4, half + 0.6, u + r + 3.4, top - 0.4), .colour(I.timberLight), width: 0.7)
        } else {
            shape(panel(u - r + 0.6, half + 0.4, u + r - 0.6, top - 0.6), .colour(I.timberLight), width: 0.8)
            line([uv(u, half + 0.8), uv(u, top - 1)], width: 0.45, opacity: 0.7)
        }
        shape(panel(u - r - 1.6, top, u + r + 1.6, top + 2.2), .colour(I.timberDark), width: 0.8)
    }

    /// A horse's head and neck reaching out over a stall's door from `q` on
    /// the screen, facing left (-1) or right (1): a chestnut coat with a white
    /// blaze, a dark mane, pricked ears, an eye and a nostril, and a halter.
    private mutating func horseHead(at q: P, facing f: Double) {
        typealias I = IronNewBuildingsInk
        let s = 0.86
        func at(_ x: Double, _ y: Double) -> P { q + P(x * f * s, y * s) }
        // The far ear, then the neck, the head, the near ear.
        shape([at(0.4, -14.4), at(-0.2, -18.6), at(2, -15)], .colour(I.horseShade), width: 0.7)
        func neck(_ o: P) -> PathData {
            var d = PathData()
            d.move(at(-3.6, 1) + o)
            d.quad(at(-4, -8) + o, at(-1.4, -13) + o)
            d.line(at(3.4, -9) + o)
            d.quad(at(3, -3) + o, at(4, 1) + o)
            d.close()
            return d
        }
        colour(.colour(I.horse)) { d, o in d = neck(o) }
        line(width: 0.9) { d in d = neck(P(0, 0)) }
        func head(_ o: P) -> PathData {
            var d = PathData()
            d.move(at(-1.4, -13) + o)
            d.quad(at(1.6, -16.2) + o, at(5, -13.6) + o)
            d.line(at(11.6, -7.2) + o)
            d.quad(at(13, -4.6) + o, at(10.6, -3.6) + o)
            d.quad(at(8, -3) + o, at(6.4, -4.4) + o)
            d.quad(at(3, -5.2) + o, at(1.6, -8.4) + o)
            d.close()
            return d
        }
        colour(.colour(I.horse)) { d, o in d = head(o) }
        // The blaze down the face.
        colour(.colour(I.light)) { d, o in
            d.move(at(3.6, -14) + o)
            d.line(at(5.2, -13.2) + o)
            d.line(at(11, -7) + o)
            d.line(at(10, -6.4) + o)
            d.close()
        }
        line(width: 0.9) { d in d = head(P(0, 0)) }
        // The mane along the neck's crest, and a forelock.
        colour(.colour(I.dark)) { d, o in
            d.move(at(-1.4, -13.4) + o)
            d.quad(at(-4.8, -8.6) + o, at(-4.4, 0.6) + o)
            d.line(at(-6.2, -2.4) + o)
            d.line(at(-5.6, -5.6) + o)
            d.line(at(-6.6, -8) + o)
            d.line(at(-4.6, -11) + o)
            d.line(at(-3.8, -14.4) + o)
            d.close()
        }
        line([at(1.2, -15), at(3.4, -12.6), at(2.2, -12)], width: 0.6)
        shape([at(1.6, -14.6), at(1.8, -19), at(3.8, -15.2)], .colour(I.horse), width: 0.7)
        // The halter of rope, the eye, the nostril and the mouth.
        line([at(2.6, -12.2), at(1.8, -7.8)], width: 0.7)
        line([at(1.8, -9.6), at(9.4, -6.4)], width: 0.7)
        svg.ellipse(at(3.4, -11.4), 1.1 * s, 0.9 * s, fill: .colour(I.light), stroke: .colour(I.line), width: 0.5)
        svg.circle(at(3.7, -11.3), 0.5 * s, fill: .colour(I.line))
        svg.circle(at(11.2, -5.4), 0.5 * s, fill: .colour(I.line))
        line([at(9.6, -3.8), at(11.2, -4)], width: 0.5)
    }

    /// The yard before the range: a stone trough of water, a hitching rail
    /// with a bucket, a rick of hay, and a fence along the two front sides with
    /// a gate flying the owner's pennants.
    private mutating func yard() {
        typealias I = IronNewBuildingsInk
        let h0 = 1.5, e = 1.42
        // The trough, along x.
        let (tx0, ty0, tx1, ty1) = (-1.1, 0.02, -0.45, 0.24)
        ashlar(tx0, ty0, tx1, ty1, h0, 7, course: 2.8, stone: 6, width: 0.9)
        shape(level(tx0 + 0.04, ty0 + 0.04, tx1 - 0.04, ty1 - 0.04, 7), .colour(I.seaGreen), width: 0.7)
        line([iso(tx0 + 0.12, ty0 + 0.1, 7), iso(tx0 + 0.3, ty0 + 0.1, 7)], width: 0.5, opacity: 0.7)
        // The hitching rail, with a bucket by it.
        let (rx0, rx1, ry) = (-0.1, 0.62, 0.32)
        pole(iso(rx0, ry, h0 + 10), iso(rx1, ry, h0 + 10), width: 1.5)
        for x in [rx0, rx1] { pole(iso(x, ry, h0), iso(x, ry, h0 + 11.2), width: 1.8, colour: I.timber) }
        bucket(at: iso(0.22, ry + 0.2, h0))
        hayRick(at: iso(0.9, 0.82, h0))
        // The fence along the two sides at the front, with the gate.
        fence(from: (-e, e), to: (-0.3, e), posts: 4)
        fence(from: (0.3, e), to: (e, e), posts: 4)
        fence(from: (e, -0.2), to: (e, e), posts: 5)
        for x in [-0.3, 0.3] { pole(iso(x, e, h0), iso(x, e, h0 + 16), width: 2.2, colour: I.timber) }
        pole(iso(-0.3, e, h0 + 15), iso(0.3, e, h0 + 15), width: 1.6)
        pennant(at: iso(-0.3, e, h0 + 16), height: 12, length: 14)
        pennant(at: iso(0.3, e, h0 + 16), height: 12, length: 14)
    }

    /// A wooden bucket bound with iron, standing at `p` on the screen.
    private mutating func bucket(at p: P) {
        typealias I = IronNewBuildingsInk
        shape([p + P(-2.6, -5), p + P(2.6, -5), p + P(2.1, 0), p + P(-2.1, 0)], .colour(I.timberLight), width: 0.7)
        svg.ellipse(p + P(0, -5), 2.6, 0.9, fill: .colour(I.seaGreenShade), stroke: .colour(I.line), width: 0.6)
        line([p + P(-2.4, -1.4), p + P(2.4, -1.4)], width: 0.6)
        line([p + P(-2.5, -3.6), p + P(2.5, -3.6)], width: 0.6)
    }

    /// A rick of hay at `p` on the screen: a round stack with a domed top,
    /// lit on the left and shaded on the right, combed down its sides, with
    /// wisps standing from its crown.
    private mutating func hayRick(at p: P) {
        typealias I = IronNewBuildingsInk
        let r = 12.0, h = 8.0
        svg.ellipse(p + P(2, 0.6), r + 3, 4, fill: .colour("#000000"), opacity: 0.15)
        func outline(_ o: P) -> PathData {
            var d = PathData()
            d.move(p + P(-r, 0) + o)
            d.line(p + P(-r + 0.6, -h) + o)
            d.cubic(p + P(-r + 1, -h - 9) + o, p + P(r - 1, -h - 9) + o, p + P(r - 0.6, -h) + o)
            d.line(p + P(r, 0) + o)
            d.quad(p + P(0, 3.4) + o, p + P(-r, 0) + o)
            d.close()
            return d
        }
        colour(.colour(I.straw)) { d, o in d = outline(o) }
        // The shaded side.
        colour(.colour(I.strawShade)) { d, o in
            d.move(p + P(3, 2.4) + o)
            d.line(p + P(3.6, -h - 6) + o)
            d.cubic(p + P(7, -h - 5) + o, p + P(r - 1, -h - 3) + o, p + P(r - 0.6, -h) + o)
            d.line(p + P(r, 0) + o)
            d.quad(p + P(7, 2) + o, p + P(3, 2.4) + o)
            d.close()
        }
        var combing = PathData()
        for k in 0..<7 {
            let x = -r + 2.4 + Double(k) * 3
            combing.move(p + P(x, -h + 2 + Double(k % 2) * 2)); combing.line(p + P(x + 0.4, -2 + Double(k % 3)))
        }
        svg.path(combing, stroke: .colour(I.line), width: 0.45, opacity: 0.6)
        line(width: 0.9) { d in d = outline(P(0, 0)) }
        // Wisps of hay standing from its crown.
        var wisps = PathData()
        for (x, lean) in [(-2.4, -1.2), (-0.6, -0.4), (1.2, 0.6), (2.8, 1.4)] {
            let foot = p + P(x, -h - 6.2 + abs(x) * 0.3)
            wisps.move(foot); wisps.quad(foot + P(lean * 0.4, -1.6), foot + P(lean, -3))
        }
        svg.path(wisps, stroke: .colour(I.strawShade), width: 0.8)
    }

    /// The stable being built: its footing of dressed stone laid, with the
    /// stalls' doorways left in it, the uprights of its frame raised along the
    /// front and the gable end, a plate along the back, scaffolding at the
    /// front, and planks, stone and roof tiles to hand.
    private mutating func stableRising() {
        typealias I = IronNewBuildingsInk
        let (x0, y0, x1, y1) = Self.rangeBox
        let h0 = 1.5, f = Self.footing, eave = Self.eave
        ashlar(x0, y0, x1, y1, h0, f, course: 3.75, stone: 8)
        colour(level(x0 + 0.1, y0 + 0.1, x1 - 0.1, y1 - 0.1, f), .colour(I.earth), opacity: 0.6)
        wall(.left, from: x0, y1, at: h0) { p in
            for u in Self.doors { p.shape(p.panel(u - Self.doorWidth / 2, 0, u + Self.doorWidth / 2, f - h0), .colour(I.dark), width: 0.8) }
        }
        // The frame: the posts along the back and its plate, then those at the front.
        for x in stride(from: x0 + 0.04, through: x1 - 0.03, by: (x1 - x0 - 0.07) / 4) {
            pole(iso(x, y0 + 0.04, f), iso(x, y0 + 0.04, eave), width: 2.2, colour: I.timber)
        }
        pole(iso(x0 + 0.04, y0 + 0.04, eave), iso(x1 - 0.03, y0 + 0.04, eave), width: 2.2, colour: I.timber)
        for y in [(y0 + y1) / 2] { pole(iso(x1 - 0.03, y, f), iso(x1 - 0.03, y, eave), width: 2.2, colour: I.timber) }
        pole(iso(x1 - 0.03, y0 + 0.04, eave), iso(x1 - 0.03, y1 - 0.04, eave), width: 2.2, colour: I.timber)
        for x in [x0 + 0.04, x0 + 0.72, x0 + 1.4] {
            pole(iso(x, y1 - 0.04, f), iso(x, y1 - 0.04, x < x0 + 1 ? eave : 18), width: 2.2, colour: I.timber)
        }
        pole(iso(x1 - 0.03, y1 - 0.04, f), iso(x1 - 0.03, y1 - 0.04, eave), width: 2.2, colour: I.timber)
        pole(iso(x0 + 0.04, y1 - 0.04, eave), iso(x0 + 0.72, y1 - 0.04, eave), width: 2.2, colour: I.timber)
        scaffold([(x0 + 0.2, y1 + 0.2), (x0 + 1.1, y1 + 0.2), (x0 + 2.0, y1 + 0.2)], from: h0, height: 30, levels: [12, 24],
                 boards: 12, inward: (0, -0.16))
        pennant(at: iso(x0 + 0.2, y1 + 0.2, h0 + 30), height: 12)
        roofTiles(0.55, 0.15, 1.05, 0.45, from: h0, courses: 4)
        roofTiles(0.6, 0.55, 1.0, 0.8, from: h0, courses: 2)
        stones(-1.1, 0.25, -0.75, 0.6, from: h0, courses: 2)
        planks(-0.6, 0.4, 0.95, on: h0, count: 3)
        sack(at: iso(1.15, 1.0, h0))
        sack(at: iso(-1.15, 1.05, h0), size: 0.9)
    }
}
