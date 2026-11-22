// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Alchemy-age castle, the strongest building in the game: a curtain wall
// of dressed stone with a battlement along its top, a round tower at each
// corner (those at the back and the sides under cones of slate, the one at
// the front crowned with merlons), and in the front wall a gatehouse between
// two round towers, its arch closed by a portcullis of iron half raised. A
// square keep rises behind, its crown on corbels with a turret at its front
// corner, flying the great banner of the owner's colour; a long banner of the
// owner's colour hangs on the keep, another over the gate, and pennants fly
// from the side towers and the gate. Its footprint is four tiles square: x and
// y run from -2 to 2, and the walls stand on the line of ±1.5.

extension AlchemyNewBuildingsPainter {
    mutating func castle(complete: Bool) {
        typealias I = AlchemyNewBuildingsInk
        // The ground the castle stands on: beaten earth and gravel.
        block(-2, -2, 2, 2, 0, Castle.ground, top: .colour(I.earth), left: .colour(I.earthShade), right: .colour(I.earthShade),
              width: 1)
        gravel()
        if complete { castleComplete() } else { castleRising() }
    }

    /// The castle's measures: on the map in tiles, heights in points.
    private enum Castle {
        static let ground = 2.0
        /// The line of the walls' outer faces, and their thickness.
        static let edge = 1.5, thick = 0.2
        static let wallTop = 42.0
        static let tower = 0.4, towerTop = 60.0
        static let keep = (x0: -1.05, y0: -1.05, x1: 0.1, y1: 0.1)
        static let keepTop = 98.0
        static let gate = (x0: -0.42, x1: 0.42, y0: 1.22, y1: 1.62)
        static let gateTop = 54.0
        static let gateTower = 0.2, gateTowerTop = 60.0
        /// How far the gate's towers stand out beyond the gate's block, along the wall.
        static let gateTowerOut = 0.08
    }

    /// Stones of gravel strewn on the ground, at fixed places.
    private mutating func gravel() {
        typealias I = AlchemyNewBuildingsInk
        let places: [(Double, Double)] = [(-1.8, 1.0), (-1.2, 1.8), (0.6, 1.85), (1.8, 0.9), (1.85, -0.6), (-1.85, -0.4), (1.1, 1.8),
                                          (1.8, 1.4), (-0.7, 1.75), (1.75, -1.4), (-1.75, 0.3), (0.2, 1.9)]
        for (k, (x, y)) in places.enumerated() {
            let c = iso(x, y, Castle.ground)
            let s = 0.8 + Double(k % 3) * 0.3
            svg.ellipse(c, 1.6 * s, 0.8 * s, fill: .colour(k % 2 == 0 ? I.earthShade : I.paving))
        }
    }

    // MARK: The castle complete

    private mutating func castleComplete() {
        typealias I = AlchemyNewBuildingsInk
        let g = Castle.ground, e = Castle.edge, t = Castle.thick, top = Castle.wallTop, r = Castle.tower
        // The road to the gate, paved.
        let road = level(-0.24, 1.5, 0.24, 2, g)
        colour(road, .colour(I.paving))
        line([road[0], road[3]], width: 0.7); line([road[1], road[2]], width: 0.7)
        var setts = PathData()
        for y in stride(from: 1.6, to: 2, by: 0.1) { setts.move(iso(-0.24, y, g)); setts.line(iso(0.24, y, g)) }
        svg.path(setts, stroke: .colour(I.pavingShade), width: 0.6)
        // The courtyard within the walls, paved.
        colour(level(-e + t, -e + t, e - t, e - t, g + 0.2), .colour(I.paving))
        // The walls at the back, seen from within, and the tower where they meet.
        curtain(.backAlongX, from: -e, to: e, height: top)
        curtain(.backAlongY, from: -e, to: e, height: top)
        cornerTower(-e, -e, roof: true, pennant: false)
        well(0.75, -0.75)
        keep()
        // The towers at the sides, then the front walls, the gatehouse, and the tower at the front.
        cornerTower(-e, e, roof: true, pennant: true)
        cornerTower(e, -e, roof: true, pennant: true)
        curtain(.frontAlongX, from: -e + r * 0.9, to: e - r * 0.9, height: top)
        gatehouse()
        curtain(.frontAlongY, from: -e + r * 0.9, to: e - r * 0.9, height: top)
        cornerTower(e, e, roof: false, pennant: false)
    }

    /// Which stretch of the curtain wall: the two at the back, seen from within
    /// the courtyard, or the two at the front, seen from outside.
    private enum Stretch { case backAlongX, backAlongY, frontAlongX, frontAlongY }

    /// A stretch of the curtain wall from `a` to `b` along its length, to
    /// `height` points, its walkway on top and its merlons along its outer
    /// edge, when `battlement` is true; otherwise left rough at the top, being built.
    private mutating func curtain(_ stretch: Stretch, from a: Double, to b: Double, height: Double, battlement: Bool = true,
                                  fresh: Bool = false) {
        typealias I = AlchemyNewBuildingsInk
        let g = Castle.ground, e = Castle.edge, t = Castle.thick
        let walk: Paint = .colour(battlement ? I.pavingShade : (fresh ? I.rawStoneTop : I.stoneTop))
        let lit: Paint = .colour(fresh ? I.rawStone : I.stone), shade: Paint = .colour(fresh ? I.rawStoneShade : I.stoneShade)
        let rise = height - g, length = (b - a) * 32
        switch stretch {
        case .backAlongX:
            block(a, -e, b, -e + t, g, height, top: walk, left: lit, right: shade)
            wall(.left, from: a, -e + t, at: g) { p in
                p.courses(0, length, 0, rise, brick: 9.5)
                // A door to the stair in the wall, and its steps.
                if battlement { p.arch(length * 0.32, 0, width: 6, height: 10, .colour(I.dark), line: 0.8) }
            }
            if battlement { merlons(alongX: true, from: a + 0.35, to: b - 0.35, at: -e, depth: 0.08, on: height) }
        case .backAlongY:
            block(-e, a, -e + t, b, g, height, top: walk, left: lit, right: .colour(fresh ? I.rawStone : I.stone))
            wall(.right, from: -e + t, b, at: g) { p in p.courses(0, length, 0, rise, brick: 9.5) }
            if battlement { merlons(alongX: false, from: a + 0.35, to: b - 0.35, at: -e, depth: 0.08, on: height) }
        case .frontAlongX:
            block(a, e - t, b, e, g, height, top: walk, left: lit, right: shade)
            wall(.left, from: a, e, at: g) { p in
                // A battered footing, then the courses.
                p.colour(p.panel(0, 0, length, 5), .colour(fresh ? I.rawStoneShade : I.stoneShade))
                p.line([p.uv(0, 5), p.uv(length, 5)], width: 0.6, opacity: 0.8)
                p.courses(0, length, 5, rise, brick: 9.5)
                if battlement {
                    for u in [length * 0.14, length * 0.86] { p.slit(u, rise - 18) }
                }
            }
            if battlement { merlons(alongX: true, from: a, to: b, at: e - 0.08, depth: 0.08, on: height) }
        case .frontAlongY:
            block(e - t, a, e, b, g, height, top: walk, left: lit, right: shade)
            wall(.right, from: e, b, at: g) { p in
                p.colour(p.panel(0, 0, length, 5), .colour(fresh ? I.rawStoneShade : I.stoneDark))
                p.line([p.uv(0, 5), p.uv(length, 5)], width: 0.6, opacity: 0.8)
                p.courses(0, length, 5, rise, brick: 9.5)
                if battlement {
                    for u in [length * 0.2, length * 0.5, length * 0.8] { p.slit(u, rise - 18) }
                }
            }
            if battlement { merlons(alongX: false, from: a, to: b, at: e - 0.08, depth: 0.08, on: height) }
        }
    }

    /// A round tower at a corner of the walls, its crown of merlons on
    /// corbels, under a cone of slate when `roof` is true, flying the owner's
    /// pennant from the cone's point when `pennant` is true.
    private mutating func cornerTower(_ cx: Double, _ cy: Double, roof: Bool, pennant flies: Bool) {
        let r = Castle.tower, g = Castle.ground, top = roof ? Castle.towerTop : Castle.towerTop - 6
        roundShaft(cx, cy, r, g, top)
        for (a, v) in [(110.0, 22.0), (60.0, 38.0), (5.0, 26.0)] { roundSlit(cx, cy, r, at: a, g + v) }
        roundBattlement(cx, cy, r, at: top, merlons: 12) { p in
            guard roof else { return }
            let apex = p.cone(cx, cy, r + 0.02, at: top + 4, rise: 38)
            if flies { p.pennant(at: apex - P(0, 6), height: 12, length: 15) }
        }
    }

    /// The well in the courtyard: a round curb of stone under a frame and its windlass.
    private mutating func well(_ x: Double, _ y: Double) {
        typealias I = AlchemyNewBuildingsInk
        let g = Castle.ground + 0.2, r = 0.16
        cylinder(x, y, r, g, g + 7, lit: I.stoneTop, mid: I.stone, shade: I.stoneShade, top: .colour(I.stoneTop), course: 3.5, brick: 5)
        svg.ellipse(iso(x, y, g + 7), r * 30, r * 15, fill: .colour(I.dark))
        for dy in [-0.14, 0.14] { pole(iso(x, y + dy, g + 7), iso(x, y + dy, g + 19), width: 1.2, colour: I.timberDark) }
        pole(iso(x, y - 0.17, g + 17), iso(x, y + 0.17, g + 17), width: 2.2, colour: I.timberLight)
        line([iso(x, y, g + 17), iso(x, y, g + 10)], width: 0.6)
    }

    /// The keep: a square tower of dressed stone on a footing, with arched
    /// windows, a long banner hung on its right face, a crown of merlons on a
    /// corbel table, a turret at its front corner, and the great banner flown
    /// from its roof.
    private mutating func keep() {
        typealias I = AlchemyNewBuildingsInk
        let (x0, y0, x1, y1) = Castle.keep
        let g = Castle.ground, top = Castle.keepTop, w = (x1 - x0) * 32
        shadow([iso(x1, y0, g), iso(x1 + 0.3, y0 + 0.1, g), iso(x1 + 0.3, y1 + 0.1, g), iso(x1, y1, g)], opacity: 0.12)
        block(x0 - 0.04, y0 - 0.04, x1 + 0.04, y1 + 0.04, g, g + 8, top: .colour(I.stoneTop), left: .colour(I.stoneShade),
              right: .colour(I.stoneDark), width: 1)
        block(x0, y0, x1, y1, g + 8, top - 8, top: nil, left: .colour(I.stone), right: .colour(I.stoneShade), width: 1.2)
        let rise = top - 8 - (g + 8)
        wall(.left, from: x0, y1, at: g + 8) { p in
            p.courses(0, w, 0, rise, brick: 9.5)
            for u in [w * 0.3, w * 0.7] {
                for v in [32.0, 58.0] { p.window(u, v, width: 6, height: 11, shutters: v > 50) }
            }
            p.slit(w * 0.5, 14, height: 8)
        }
        wall(.right, from: x1, y1, at: g + 8) { p in
            p.courses(0, w, 0, rise, brick: 9.5)
            p.window(w * 0.25, 58, width: 6, height: 11, shutters: false)
            p.slit(w * 0.25, 30, height: 8)
            p.slit(w * 0.78, 30, height: 8)
            p.hanging(w * 0.62, top: rise - 1, width: 11, length: 34)
        }
        // The corbel table, and the crown standing out on it.
        let o = 0.05, c0 = top - 8, (a0, b0, a1, b1) = (x0 - o, y0 - o, x1 + o, y1 + o)
        for side in [AlchemyNewBuildingsSide.left, .right] {
            wall(side, from: side == .left ? x0 : x1, y1, at: c0 - 6) { p in
                for u in stride(from: 2.4, to: w - 1, by: 4.4) {
                    p.shape([p.uv(u - 1.1, 6), p.uv(u + 1.1, 6), p.uv(u + 1.1, 2.2), p.uv(u, 0.6), p.uv(u - 1.1, 2.2)],
                            .colour(side == .left ? I.stoneTop : I.stone), width: 0.5)
                }
            }
        }
        block(a0, b0, a1, b1, c0, top, top: .colour(I.pavingShade), left: .colour(I.stoneTop), right: .colour(I.stone), width: 1.1)
        // The merlons along the back, seen from within; the great banner; the merlons along the front.
        merlons(alongX: true, from: a0, to: a1, at: b0, depth: 0.07, on: top, height: 7, size: 0.12, gap: 0.1)
        merlons(alongX: false, from: b0 + 0.07, to: b1, at: a0, depth: 0.07, on: top, height: 7, size: 0.12, gap: 0.1)
        banner(at: iso((x0 + x1) / 2 - 0.1, (y0 + y1) / 2 - 0.1, top), height: 54, width: 24, length: 16)
        merlons(alongX: false, from: b0 + 0.04, to: b1 - 0.07, at: a1 - 0.07, depth: 0.07, on: top, height: 7, size: 0.12, gap: 0.1)
        merlons(alongX: true, from: a0, to: a1, at: b1 - 0.07, depth: 0.07, on: top, height: 7, size: 0.12, gap: 0.1)
        // The turret at the front corner, on its corbelled foot, under a cone of slate.
        let tr = 0.17, (tx, ty) = (x1 + 0.02, y1 + 0.02), foot = top - 18
        colour(arc(tx, ty, tr, from: -45, to: 135, at: foot) + [iso(tx, ty, foot - 12)], .colour(I.stone))
        colour(arc(tx, ty, tr, from: -45, to: 30, at: foot) + [iso(tx, ty, foot - 12)], .colour(I.stoneShade))
        line(arc(tx, ty, tr, from: -45, to: 135, at: foot) + [iso(tx, ty, foot - 12)], closed: true, width: 0.9)
        for k in 1...3 {
            let f = Double(k) / 4
            line(arc(tx, ty, tr * (1 - f), from: -45, to: 135, at: foot - 12 * f), width: 0.5, opacity: 0.6)
        }
        cylinder(tx, ty, tr, foot, top + 10, lit: I.stoneTop, mid: I.stone, shade: I.stoneShade, course: 4.4, brick: 6)
        roundSlit(tx, ty, tr, at: 45, foot + 12, height: 7)
        cone(tx, ty, tr + 0.04, at: top + 10, rise: 26)
    }

    /// An arched window on a wall drawn with `wall`: its foot at (`u`, `v`),
    /// with leaded glass, and its shutters of teal folded open when `shutters` is true.
    mutating func window(_ u: Double, _ v: Double, width w: Double, height h: Double, shutters: Bool) {
        typealias I = AlchemyNewBuildingsInk
        if shutters {
            for (a, b) in [(u - w / 2 - w * 0.48, u - w / 2), (u + w / 2, u + w / 2 + w * 0.48)] {
                shape(panel(a, v, b, v + h - w / 2), .colour(I.teal), width: 0.6)
                line([uv(a + 0.4, v + (h - w / 2) * 0.5), uv(b - 0.4, v + (h - w / 2) * 0.5)], width: 0.4, opacity: 0.8)
            }
        }
        voussoirs(u, v, width: w, height: h, depth: 1.6, count: 5)
        arch(u, v, width: w, height: h, .colour(I.tealDark), line: 0.8)
        // The leading of the glass.
        var lead = PathData()
        lead.move(uv(u, v + 0.3)); lead.line(uv(u, v + h - 0.3))
        lead.move(uv(u - w / 2 + 0.3, v + h * 0.45)); lead.line(uv(u + w / 2 - 0.3, v + h * 0.45))
        svg.path(lead, stroke: .colour(I.tealLit), width: 0.5)
        shape(panel(u - w / 2 - 1, v - 1.2, u + w / 2 + 1, v), .colour(I.stoneTop), width: 0.55)
    }

    /// The gatehouse in the front wall: a block over the gate's arch and its
    /// portcullis between two round towers, a banner of the owner's colour
    /// hung over the arch, and pennants on the towers.
    private mutating func gatehouse() {
        typealias I = AlchemyNewBuildingsInk
        let gate = Castle.gate, g = Castle.ground, top = Castle.gateTop, w = (gate.x1 - gate.x0) * 32
        block(gate.x0, gate.y0, gate.x1, gate.y1, g, top, top: .colour(I.pavingShade), left: .colour(I.stone), right: .colour(I.stoneShade))
        wall(.left, from: gate.x0, gate.y1, at: g) { p in
            p.courses(0, w, 0, top - g, brick: 9.5)
            // The arch, its passage dark, and the portcullis half raised in it.
            p.voussoirs(w / 2, 0, width: 13, height: 19, depth: 2.4, count: 9)
            p.arch(w / 2, 0, width: 13, height: 19, .colour(I.dark), line: 1)
            p.portcullis(w / 2, raisedTo: 7, width: 13, height: 19)
            p.hanging(w / 2, top: top - g - 3, width: 10, length: 22)
        }
        merlons(alongX: true, from: gate.x0, to: gate.x1, at: gate.y1 - 0.08, depth: 0.08, on: top, height: 6, size: 0.12, gap: 0.1)
        for x in [gate.x0 - Castle.gateTowerOut, gate.x1 + Castle.gateTowerOut] {
            let cy = gate.y1 - 0.02, r = Castle.gateTower, h = Castle.gateTowerTop
            roundShaft(x, cy, r, g, h)
            roundSlit(x, cy, r, at: 45, g + 26)
            roundBattlement(x, cy, r, at: h, out: 0.04, merlons: 8) { p in
                p.pennant(at: p.iso(x, cy, h + 2), height: 26, length: 14)
            }
        }
    }

    /// A portcullis of iron in an arch drawn with `arch` centred on `u`: its
    /// grid fills the arch down to `raisedTo` points above the ground, its
    /// foot a row of spikes.
    mutating func portcullis(_ u: Double, raisedTo v0: Double, width: Double, height: Double) {
        typealias I = AlchemyNewBuildingsInk
        let r = width / 2, spring = height - r
        var bars = PathData(), shades = PathData()
        // Upright bars, each cut off by the arch above.
        for k in 0...5 {
            let x = -r + 0.8 + (width - 1.6) * Double(k) / 5
            let topV = spring + (r * r - x * x > 0 ? (r * r - x * x).squareRoot() : 0) - 0.5
            bars.move(uv(u + x, v0 - 2.2)); bars.line(uv(u + x, topV))
            shades.move(uv(u + x + 0.5, v0 - 1.6)); shades.line(uv(u + x + 0.5, topV))
        }
        // Rails across.
        var v = v0 + 0.3
        while v < height - 0.8 {
            let x = v > spring ? (r * r - (v - spring) * (v - spring)).squareRoot() - 0.5 : r - 0.5
            if x > 0.5 { bars.move(uv(u - x, v)); bars.line(uv(u + x, v)) }
            v += 3.1
        }
        svg.path(shades, stroke: .colour(I.line), width: 0.6, opacity: 0.8)
        svg.path(bars, stroke: .colour(I.line), width: 1.7)
        svg.path(bars, stroke: .colour(I.ironLight), width: 0.9)
        // The light of the courtyard beyond, under the raised grid.
        colour(panel(u - r + 0.6, 0.2, u + r - 0.6, v0 - 3), .colour(I.paving), opacity: 0.55)
    }

    // MARK: The castle being built

    /// The castle being built: the curtain walls raised part of their height
    /// and left stepped, the corner towers and the gate's towers begun, the
    /// keep's lower storeys inside scaffolding flying the owner's pennant, and
    /// stone, timber and mortar to hand.
    private mutating func castleRising() {
        typealias I = AlchemyNewBuildingsInk
        let g = Castle.ground, e = Castle.edge, t = Castle.thick, r = Castle.tower
        colour(level(-e + t, -e + t, e - t, e - t, g + 0.2), .colour(I.earthShade), opacity: 0.6)
        // The back walls: raised to their walkway along part of their length, stepped down beyond.
        curtain(.backAlongX, from: -e, to: 0.2, height: 30, battlement: false, fresh: true)
        curtain(.backAlongX, from: 0.2, to: e, height: 18, battlement: false, fresh: true)
        curtain(.backAlongY, from: -e, to: 0.1, height: 30, battlement: false, fresh: true)
        curtain(.backAlongY, from: 0.1, to: e, height: 14, battlement: false, fresh: true)
        roundShaft(-e, -e, r, g, 40, fresh: true)
        scaffold([(-e - 0.1, -e + 0.5), (-e + 0.5, -e + 0.5), (-e + 0.5, -e - 0.1)], from: g, height: 50, levels: [16, 32, 46],
                 boards: 32, inward: (-0.1, -0.1))
        stones(0.85, -1.2, 1.15, -0.98, from: g, courses: 2)
        // The keep's lower storeys, inside scaffolding.
        let (x0, y0, x1, y1) = Castle.keep
        block(x0 - 0.04, y0 - 0.04, x1 + 0.04, y1 + 0.04, g, g + 8, top: .colour(I.rawStoneTop), left: .colour(I.rawStoneShade),
              right: .colour(I.stoneShade), width: 1)
        ashlar(x0, y0, x1, y1, g + 8, 44, course: 4.4, stone: 9.5, fresh: true)
        hollow(level(x0 + 0.16, y0 + 0.16, x1 - 0.16, y1 - 0.16, 44), depth: 14)
        // The next courses begun along the back, and the first floor's beams laid across.
        ashlar(x0, y0, x1 - 0.3, y0 + 0.16, 44, 52.8, course: 4.4, stone: 9.5, fresh: true)
        ashlar(x0, y0 + 0.16, x0 + 0.16, y1 - 0.4, 44, 48.4, course: 4.4, stone: 9.5, fresh: true)
        for x in [x0 + 0.35, x0 + 0.65] { beam(x, y0 + 0.1, x, y1 - 0.1, on: 44, size: 2.4) }
        scaffold([(x0 - 0.15, y1 + 0.15), (x1 + 0.15, y1 + 0.15)], from: g, height: 66, levels: [22, 44, 60], boards: 44,
                 inward: (0, -0.12))
        scaffold([(x1 + 0.15, y1 + 0.15), (x1 + 0.15, y0 - 0.15)], from: g, height: 66, levels: [22, 44, 60], boards: 44,
                 inward: (-0.12, 0))
        pennant(at: iso(x1 + 0.15, y1 + 0.15, g + 66), height: 14, length: 16)
        hoist(at: (0.95, -0.45))
        // The side towers and the front walls, a few courses high.
        roundShaft(-e, e, r, g, 26, fresh: true)
        roundShaft(e, -e, r, g, 20, fresh: true)
        curtain(.frontAlongX, from: -e + r * 0.9, to: -0.5, height: 18, battlement: false, fresh: true)
        curtain(.frontAlongX, from: 0.5, to: e - r * 0.9, height: 12, battlement: false, fresh: true)
        // The gate: its two towers begun, and the timber centring for its arch.
        let gate = Castle.gate
        for x in [gate.x0 - Castle.gateTowerOut, gate.x1 + Castle.gateTowerOut] { roundShaft(x, gate.y1 - 0.02, Castle.gateTower, g, 22, fresh: true) }
        centring(gate.x0 + 0.06, gate.x1 - 0.06, at: gate.y1 - 0.05)
        curtain(.frontAlongY, from: -e + r * 0.9, to: 0.3, height: 16, battlement: false, fresh: true)
        curtain(.frontAlongY, from: 0.3, to: e - r * 0.9, height: 8, battlement: false, fresh: true)
        roundShaft(e, e, r, g, 12, fresh: true)
        // Materials beside: stone, beams, mortar, and a second pennant on a pole set in the work.
        stones(-1.95, 1.75, -1.65, 1.95, from: g, courses: 2)
        stones(1.6, -1.95, 1.9, -1.7, from: g, courses: 1)
        planks(0.75, 1.3, 1.82, on: g, count: 3)
        mortar(-1.0, 1.7, on: g)
        stones(1.75, 0.45, 1.95, 0.75, from: g, courses: 1)
        pennant(at: iso(e, -e, 20), height: 22, length: 14)
    }

    /// Shear legs standing in the courtyard with their foot at (x, y) on the
    /// map, leaning over the keep, stayed back to a stake, lifting a block of
    /// stone on a rope from a windlass between their feet.
    private mutating func hoist(at foot: (Double, Double)) {
        typealias I = AlchemyNewBuildingsInk
        let g = Castle.ground, (x, y) = foot
        let apex = iso(x - 0.3, y - 0.05, 72), load = iso(x - 0.3, y - 0.05, 40)
        let feet = [(x, y - 0.3), (x, y + 0.3)]
        svg.line([apex, iso(x + 0.55, y, g)], stroke: .colour(I.line), width: 0.6)
        pole(iso(x + 0.55, y, g), iso(x + 0.55, y, g + 5), width: 1.2, colour: I.timberDark)
        pole(iso(feet[0].0, feet[0].1, g), apex, width: 2.2, colour: I.timber)
        // The windlass between the legs, and the rope over the pulley to the load.
        let drum = (iso(x, y - 0.22, g + 7), iso(x, y + 0.22, g + 7))
        pole(drum.0, drum.1, width: 3.2, colour: I.timberLight)
        line([drum.1, drum.1 + P(2.4, 4), drum.1 + P(4.6, 3)], width: 1.1)
        svg.line([drum.0 + (drum.1 - drum.0) * 0.5, apex], stroke: .colour(I.line), width: 0.6)
        svg.circle(apex + P(0, 2.4), 1.8, fill: .colour(I.timberDark), stroke: .colour(I.line), width: 0.6)
        svg.line([apex + P(0, 2.4), load], stroke: .colour(I.line), width: 0.7)
        line([load, load + P(0, 2.4), load + P(1.6, 3.2), load + P(2.2, 1.6)], width: 1)
        svg.line([load + P(0, 2.4), load + P(-4, 6)], stroke: .colour(I.line), width: 0.6)
        svg.line([load + P(0, 2.4), load + P(4, 6)], stroke: .colour(I.line), width: 0.6)
        stones(x - 0.4, y - 0.15, x - 0.2, y + 0.05, from: 40 - 9.6, courses: 1)
        pole(iso(feet[1].0, feet[1].1, g), apex, width: 2.2, colour: I.timber)
    }

    /// The timber centring on which the gate's arch will be turned: two
    /// uprights and a frame bent to the arch, across the gateway at `y`.
    private mutating func centring(_ x0: Double, _ x1: Double, at y: Double) {
        typealias I = AlchemyNewBuildingsInk
        let g = Castle.ground
        for x in [x0, x1] { pole(iso(x, y, g), iso(x, y, g + 12), width: 1.8, colour: I.timber) }
        wall(.left, from: x0, y, at: g) { p in
            let w = (x1 - x0) * 32, r = w / 2
            var d = PathData()
            d.move(p.uv(0, 12))
            for k in 1...10 {
                let a = Double.pi * Double(k) / 10
                d.line(p.uv(r - r * cos(a), 12 + r * sin(a) * 0.9))
            }
            p.svg.path(d, stroke: .colour(I.line), width: 3.4)
            p.svg.path(d, stroke: .colour(I.timberLight), width: 2)
            p.pole(p.uv(0, 12), p.uv(w, 12), width: 1.4, colour: I.timber)
            p.pole(p.uv(r, 12), p.uv(r, 12 + r * 0.9), width: 1.2, colour: I.timber)
        }
    }
}
