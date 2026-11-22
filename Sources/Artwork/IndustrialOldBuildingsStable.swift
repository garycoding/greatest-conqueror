// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Industrial-age stable: the Alchemy age's range of stalls rebuilt in
// red brick on a plinth of dressed stone, under a roof of slate with a
// louvred ventilator on its ridge and an iron weathervane. Each stall opens
// under a round arch dressed in stone, with a door in two leaves, its lower
// leaf painted in the owner's colour, and horses look out over two of them;
// a band of the owner's colour runs under the eaves, and hay shows at the
// loft door in the gable, under a round window. A stone trough of water, an
// iron hitching rail and a rick of hay stand in the yard, behind a fence of
// oak whose gate flies the owner's pennants. Its footprint is three tiles
// square: x and y run from -1.5 to 1.5.

extension IndustrialOldBuildingsPainter {
    mutating func stable(complete: Bool) {
        typealias I = IndustrialOldBuildingsInk
        block(-1.5, -1.5, 1.5, 1.5, 0, 1.5, top: .colour(I.earth), left: .colour(I.earthShade), right: .colour(I.earthShade),
              width: 1)
        strawWisps([(-1.1, 0.2, 20), (-0.7, 0.9, -15), (-0.2, 0.0, 10), (0.3, 0.6, 35), (0.9, 0.1, -25), (1.1, 1.0, 5),
                    (-1.2, 1.1, 30), (0.2, 1.15, -10), (-0.4, 0.5, 15), (0.6, -0.05, -30)], on: 1.5)
        if complete { stableRange() } else { stableRising() }
    }

    private static let rangeBox = (x0: -1.36, y0: -1.36, x1: 1.36, y1: -0.3)
    private static let rangeEave = 37.0
    /// The middles of the stalls' doors, in points along the front wall, and their width.
    private static let stalls: [Double] = (0..<4).map { (Double($0) + 0.5) * (2.72 * 32) / 4 }
    private static let stallWidth = 12.0

    /// The plinth of dressed stone along the range, from `h0` to `h1`.
    private mutating func rangeFootingStone(_ h0: Double, _ h1: Double) {
        typealias I = IndustrialOldBuildingsInk
        let (x0, y0, x1, y1) = Self.rangeBox
        block(x0, y0, x1, y1, h0, h1, top: .colour(I.stoneTop), left: .colour(I.stone), right: .colour(I.stoneShade))
        wall(.left, from: x0, y1, at: h0) { p in p.courses(0, (x1 - x0) * 32, 0, h1 - h0, course: 2.6, brick: 9) }
        wall(.right, from: x1, y1, at: h0) { p in p.courses(0, (y1 - y0) * 32, 0, h1 - h0, course: 2.6, brick: 9) }
    }

    private mutating func stableRange() {
        typealias I = IndustrialOldBuildingsInk
        let (x0, y0, x1, y1) = Self.rangeBox
        let h0 = 1.5, f = 5.5, eave = Self.rangeEave, ridge = 51.0
        let length = (x1 - x0) * 32, depth = (y1 - y0) * 32
        shadow([iso(x1, y0, h0), iso(x1 + 0.3, y0 + 0.16, h0), iso(x1 + 0.3, y1 + 0.12, h0), iso(x1, y1, h0)])
        rangeFootingStone(h0, f)
        block(x0, y0, x1, y1, f, eave, top: nil, left: .colour(I.brick), right: .colour(I.brickShade), width: 1.1)
        wall(.left, from: x0, y1, at: f) { p in
            p.brickwork(0, length, 0, eave - f)
            p.quoins(at: 0, atStart: true, from: 0, to: eave - f, course: 3.2, reach: 3.4)
            p.quoins(at: length, atStart: false, from: 0, to: eave - f, course: 3.2, reach: 3.4)
            for k in 0..<(Self.stalls.count - 1) {
                let u = (Self.stalls[k] + Self.stalls[k + 1]) / 2
                p.pilaster(u, 0, eave - f - 3.4, w: 2.6)
            }
            p.paintedBand(0, length, eave - f - 3, eave - f - 1.4)
        }
        wall(.right, from: x1, y1, at: f) { p in
            p.brickwork(0, depth, 0, eave - f)
            p.quoins(at: 0, atStart: true, from: 0, to: eave - f, course: 3.2, reach: 3.4)
            p.archedWindow(depth / 2 - 8, 4, w: 6, h: 10)
            p.archedWindow(depth / 2 + 8, 4, w: 6, h: 10)
            p.paintedBand(0, depth, eave - f - 3, eave - f - 1.4)
        }
        wall(.left, from: x0, y1, at: h0) { p in
            for (k, u) in Self.stalls.enumerated() { p.stallDoor(at: u, open: k == 1 || k == 3) }
            let u = Self.stalls[0]
            let shoe = [p.uv(u - 1.6, 20.4), p.uv(u - 2, 23.6), p.uv(u, 23.8), p.uv(u + 2, 23.6), p.uv(u + 1.6, 20.4)]
            p.line(width: 1.2) { d in
                d.move(shoe[0]); d.quad(shoe[1], shoe[2]); d.quad(shoe[3], shoe[4])
            }
        }
        gableAlongX(x0, y0, x1, y1, eave: eave, ridge: ridge, over: 0.08, gableWall: .colour(I.brickShade)) { p, w, rise in
            p.gableBrickwork(w, rise)
            p.svg.circle(p.uv(w / 2, rise * 0.68), 2.6, fill: .colour(I.stoneTop), stroke: .colour(I.line), width: 0.5)
            p.svg.circle(p.uv(w / 2, rise * 0.68), 1.6, fill: .colour(I.glass), stroke: .colour(I.line), width: 0.4)
            p.shape(p.panel(w / 2 - 4.4, 1.6, w / 2 + 4.4, 10.6), .colour(I.dark), width: 0.8)
            func at(_ u: Double, _ v: Double) -> P { P(u, -v) }
            let hay = [at(w / 2 - 4.4, 1.6), at(w / 2 - 4.4, 5.4), at(w / 2 - 2, 8.4), at(w / 2 + 1, 6.8), at(w / 2 + 3.4, 8),
                       at(w / 2 + 4.4, 4.8), at(w / 2 + 4.4, 1.6)]
            p.colour(.colour(I.straw)) { d, o in
                d.move(hay[0] + o); d.line(hay[1] + o); d.quad(hay[2] + o, hay[3] + o); d.quad(hay[4] + o, hay[5] + o)
                d.line(hay[6] + o); d.close()
            }
            p.line([p.uv(w / 2 - 3.6, 3.8), p.uv(w / 2 - 2.4, 6.8)], width: 0.45)
            p.line([p.uv(w / 2 + 0.4, 3), p.uv(w / 2 + 1.2, 6)], width: 0.45)
            p.shape(p.panel(w / 2 - 5.4, 10.6, w / 2 + 5.4, 12), .colour(I.stoneTop), width: 0.6)
            p.shape(p.panel(w / 2 - 5.4, 0.4, w / 2 + 5.4, 1.6), .colour(I.stoneTop), width: 0.5)
        }
        cupola(at: (0.45, (y0 + y1) / 2), on: ridge - 3)
        for k in [1, 3] {
            let x = x0 + Self.stalls[k] / 32
            horseHead(at: iso(x - 0.04, y1 + 0.02, h0 + 9.2), facing: -1)
        }
        stableYard()
    }

    /// A louvred ventilator astride the ridge at (x, y), its foot at `h`: a
    /// little box of painted board with louvres, under a pyramid of slate and
    /// an iron weathervane.
    private mutating func cupola(at place: (Double, Double), on h: Double) {
        typealias I = IndustrialOldBuildingsInk
        let (x, y) = place, s = 0.12, top = h + 10
        block(x - s, y - s, x + s, y + s, h, top, top: nil, left: .colour(I.light), right: .colour(I.plasterShade), width: 0.9)
        for side in [IndustrialOldBuildingsSide.left, .right] {
            wall(side, from: side == .left ? x - s : x + s, y + s, at: h) { p in
                for v in stride(from: 3.4, to: 9.0, by: 1.6) { p.line([p.uv(1, v), p.uv(2 * s * 32 - 1, v - 0.8)], width: 0.6) }
            }
        }
        let peak = hippedRoof(x - s, y - s, x + s, y + s, eaves: top, rise: 7, overhang: 0.03, finials: false)
        weathervane(at: iso(x, y, peak), height: 9)
    }

    /// A stall's door at `u` on the front wall: a dark opening under a round
    /// arch dressed in stone, its lower leaf in the owner's colour, braced and
    /// hinged with iron, and its upper leaf folded back when `open`, or shut.
    private mutating func stallDoor(at u: Double, open: Bool) {
        typealias I = IndustrialOldBuildingsInk
        let r = Self.stallWidth / 2, top = 18.0, half = 9.0
        arch(u, 0, width: 2 * r + 3.2, height: top + r + 1.6, .colour(I.stoneTop), line: 0.7)
        arch(u, 0, width: 2 * r, height: top + r, .colour(I.dark), line: 0.9)
        shape(panel(u - 0.9, top + r - 0.4, u + 0.9, top + r + 2.1), .colour(I.stoneTop), width: 0.45)
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
        shape(panel(u - r, top - 0.2, u + r, top + 0.8), .colour(I.timberDark), width: 0.6)
    }

    /// The yard before the range: a stone trough of water, a hitching rail
    /// with a bucket, a rick of hay, and a fence along the two front sides with
    /// a gate flying the owner's pennants.
    private mutating func stableYard() {
        typealias I = IndustrialOldBuildingsInk
        let h0 = 1.5, e = 1.42
        // The trough, along x.
        let (tx0, ty0, tx1, ty1) = (-1.1, 0.02, -0.45, 0.24)
        block(tx0, ty0, tx1, ty1, h0, 7, top: .colour(I.stoneTop), left: .colour(I.stone), right: .colour(I.stoneShade), width: 0.9)
        shape(level(tx0 + 0.04, ty0 + 0.04, tx1 - 0.04, ty1 - 0.04, 7), .colour(I.glass), width: 0.7)
        line([iso(tx0 + 0.12, ty0 + 0.1, 7), iso(tx0 + 0.3, ty0 + 0.1, 7)], width: 0.5, opacity: 0.7)
        // The hitching rail of iron, with a bucket by it.
        let (rx0, rx1, ry) = (-0.1, 0.62, 0.32)
        pole(iso(rx0, ry, h0 + 10), iso(rx1, ry, h0 + 10), width: 1.3, colour: I.iron)
        for x in [rx0, rx1] {
            pole(iso(x, ry, h0), iso(x, ry, h0 + 11.2), width: 1.8, colour: I.iron)
            svg.circle(iso(x, ry, h0 + 12.2), 1.1, fill: .colour(I.iron), stroke: .colour(I.line), width: 0.4)
        }
        bucket(at: iso(0.22, ry + 0.2, h0))
        hayRick(at: iso(0.9, 0.82, h0))
        // The fence along the two sides at the front, with the gate.
        railFence(from: (-e, e), to: (-0.3, e), posts: 4)
        railFence(from: (0.3, e), to: (e, e), posts: 4)
        railFence(from: (e, -0.2), to: (e, e), posts: 5)
        for x in [-0.3, 0.3] { pole(iso(x, e, h0), iso(x, e, h0 + 16), width: 2.2, colour: I.oak) }
        pole(iso(-0.3, e, h0 + 15), iso(0.3, e, h0 + 15), width: 1.6)
        pennant(at: iso(-0.3, e, h0 + 16), height: 12, length: 14)
        pennant(at: iso(0.3, e, h0 + 16), height: 12, length: 14)
    }

    /// A wooden bucket bound with iron, standing at `p` on the screen.
    private mutating func bucket(at p: P) {
        typealias I = IndustrialOldBuildingsInk
        shape([p + P(-2.6, -5), p + P(2.6, -5), p + P(2.1, 0), p + P(-2.1, 0)], .colour(I.timberLight), width: 0.7)
        svg.ellipse(p + P(0, -5), 2.6, 0.9, fill: .colour(I.glassDark), stroke: .colour(I.line), width: 0.6)
        line([p + P(-2.4, -1.4), p + P(2.4, -1.4)], width: 0.6)
        line([p + P(-2.5, -3.6), p + P(2.5, -3.6)], width: 0.6)
    }

    /// A rick of hay at `p` on the screen: a round stack with a domed top,
    /// lit on the left and shaded on the right, combed down its sides, with
    /// wisps standing from its crown.
    private mutating func hayRick(at p: P) {
        typealias I = IndustrialOldBuildingsInk
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

    /// The stable being built: its plinth of stone laid with the stalls'
    /// doorways left in it, the brick walls raised to the springing of their
    /// arches with timber centring set for the first, scaffolding with the
    /// owner's pennant, and slates, bricks and sacks to hand.
    private mutating func stableRising() {
        typealias I = IndustrialOldBuildingsInk
        let (x0, y0, x1, y1) = Self.rangeBox
        let h0 = 1.5, f = 5.5, top = 19.0
        let length = (x1 - x0) * 32, depth = (y1 - y0) * 32
        rangeFootingStone(h0, f)
        shell(x0, y0, x1, y1, from: f, floor: f, to: top, thickness: 0.07, lit: .colour(I.rawBrick), shade: .colour(I.rawBrickShade),
              top: .colour(I.brickTop), ground: .colour(I.earth)) { p in
            p.bricks(-0.6, -1.2, -0.3, -0.95, from: f, height: 4)
        }
        wall(.left, from: x0, y1, at: f) { p in
            p.brickwork(0, length, 0, top - f, opacity: 0.4, burnt: false)
        }
        wall(.left, from: x0, y1, at: h0) { p in
            for u in Self.stalls {
                p.shape(p.panel(u - Self.stallWidth / 2, 0, u + Self.stallWidth / 2, top - h0), .colour(I.dark), width: 0.8)
            }
            // The centring for the first arch.
            let u = Self.stalls[0], r = Self.stallWidth / 2
            let (c0, c1, c2) = (p.uv(u - r, top - h0), p.uv(u, top - h0 + r * 1.9), p.uv(u + r, top - h0))
            p.line(width: 1.4) { d in d.move(c0); d.quad(c1, c2) }
            p.timber(p.uv(u - r + 0.8, top - h0), p.uv(u - r + 0.8, 2), width: 1, paint: I.timberLight)
            p.timber(p.uv(u + r - 0.8, top - h0), p.uv(u + r - 0.8, 2), width: 1, paint: I.timberLight)
        }
        wall(.right, from: x1, y1, at: f) { p in
            p.brickwork(0, depth, 0, top - f, opacity: 0.4, burnt: false)
            p.shape(p.panel(depth / 2 - 11, 4, depth / 2 - 5, top - f), .colour(I.dark), width: 0.8)
            p.shape(p.panel(depth / 2 + 5, 4, depth / 2 + 11, top - f), .colour(I.dark), width: 0.8)
        }
        scaffold([(x0 + 0.2, y1 + 0.2), (x0 + 1.1, y1 + 0.2), (x0 + 2.0, y1 + 0.2)], from: h0, height: 32, levels: [12, 24],
                 boards: 12, inward: (0, -0.16))
        pennant(at: iso(x0 + 0.2, y1 + 0.2, h0 + 32), height: 12, length: 13)
        slates(0.55, 0.15, 1.05, 0.45, from: h0, height: 7)
        slates(0.6, 0.55, 1.0, 0.8, from: h0, height: 4)
        bricks(-1.1, 0.25, -0.75, 0.6, from: h0, height: 6)
        timbers(-0.6, 0.85, length: 1.0, on: h0)
        sack(at: iso(1.15, 1.0, h0))
        sack(at: iso(-1.15, 1.05, h0), size: 0.9)
    }
}
