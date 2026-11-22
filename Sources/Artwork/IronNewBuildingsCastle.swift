// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Iron-age castle, the first of its line (the castle is of the age of
// ships, requirement 10): a fort of the legions in dressed stone, which the
// Alchemy age rebuilds with round towers and the Industrial age refaces in
// brick. Its curtain wall stands on a footing of darker stone, with a
// battlement along its top and the legion's shields hung on its outer faces;
// a square tower stands at each corner (those at the back and the sides under
// pyramid roofs of red tile, a band of the owner's colour under their eaves,
// the one at the front an open platform within merlons), and in the front
// wall the gate opens in two arches closed by doors studded with iron,
// between two square towers, a cloth of the owner's colour hung over it. A
// square tower rises at the back, under a pyramid roof flying the legion's
// standard in the owner's colour, and beside it stands the headquarters: a
// hall of stone with a portico of columns under a pediment of the owner's
// colour, facing the parade ground.
// Its footprint is four tiles square, as in the later ages: x and y run from
// -2 to 2, and the walls stand on the line of ±1.5. It is drawn with the kit
// of the Iron-age looks of the older buildings, whose stone, tile and
// standards it shares.

extension IronOldBuildingsPainter {
    mutating func castle(complete: Bool) {
        typealias I = IronOldBuildingsInk
        // The ground the fort stands on: beaten earth and gravel.
        block(-2, -2, 2, 2, 0, Fort.ground, top: .colour(I.earth), left: .colour(I.earthShade), right: .colour(I.earthShade),
              width: 1)
        fortGravel()
        if complete { fortComplete() } else { fortRising() }
    }

    /// The fort's measures: on the map in tiles, heights in points.
    private enum Fort {
        static let ground = 2.0
        /// The line of the walls' outer faces, and their thickness.
        static let edge = 1.5, thick = 0.2
        static let wallTop = 36.0
        /// A corner tower's half width, and its height to the eaves.
        static let tower = 0.32, towerTop = 54.0
        /// The great tower behind the headquarters.
        static let keep = (x0: -1.08, y0: -1.08, x1: -0.34, y1: -0.34)
        static let keepTop = 82.0
        /// The headquarters' hall beside the great tower, its portico running on toward +y, and its eaves.
        static let hall = (x0: -0.12, y0: -1.2, x1: 0.88, y1: -0.64)
        static let portico = 0.2, hallEaves = 30.0
        /// The gate's block, and its towers' half width and height.
        static let gate = (x0: -0.42, x1: 0.42, y0: 1.24, y1: 1.62)
        static let gateTop = 44.0
        static let gateTower = 0.17, gateTowerTop = 54.0
        /// Where the gate's towers stand along y.
        static let gateTowerY = 1.48
    }

    /// Stones of gravel strewn on the ground, at fixed places.
    private mutating func fortGravel() {
        typealias I = IronOldBuildingsInk
        let places: [(Double, Double)] = [(-1.8, 1.0), (-1.2, 1.8), (0.6, 1.85), (1.8, 0.9), (1.85, -0.6), (-1.85, -0.4), (1.1, 1.8),
                                          (1.8, 1.4), (-0.7, 1.75), (1.75, -1.4), (-1.75, 0.3), (0.2, 1.9)]
        for (k, (x, y)) in places.enumerated() {
            let c = iso(x, y, Fort.ground)
            let s = 0.8 + Double(k % 3) * 0.3
            svg.ellipse(c, 1.6 * s, 0.8 * s, fill: .colour(k % 2 == 0 ? I.earthShade : I.paving))
        }
    }

    // MARK: The fort complete

    private mutating func fortComplete() {
        typealias I = IronOldBuildingsInk
        let g = Fort.ground, e = Fort.edge, t = Fort.thick, s = Fort.tower
        // The road to the gate, paved, and its two lanes.
        let road = level(-0.34, 1.5, 0.34, 2, g)
        colour(road, .colour(I.paving))
        line([road[0], road[3]], width: 0.7); line([road[1], road[2]], width: 0.7)
        var setts = PathData()
        for y in stride(from: 1.62, to: 2, by: 0.09) { setts.move(iso(-0.34, y, g)); setts.line(iso(0.34, y, g)) }
        setts.move(iso(0, 1.62, g)); setts.line(iso(0, 2, g))
        svg.path(setts, stroke: .colour(I.pavingShade), width: 0.6)
        // The parade ground within the walls, paved.
        colour(level(-e + t, -e + t, e - t, e - t, g + 0.2), .colour(I.paving))
        // The walls at the back, seen from within, and the tower where they meet.
        curtain(.backAlongX, from: -e, to: e, height: Fort.wallTop)
        curtain(.backAlongY, from: -e, to: e, height: Fort.wallTop)
        squareTower(-e, -e, half: s, top: Fort.towerTop, roofed: true, pennant: false)
        keep()
        hall()
        // The towers at the sides, then the front walls, the gate, and the tower at the front.
        squareTower(-e, e, half: s, top: Fort.towerTop, roofed: true, pennant: true)
        squareTower(e, -e, half: s, top: Fort.towerTop, roofed: true, pennant: true)
        curtain(.frontAlongX, from: -e + s, to: e - s, height: Fort.wallTop)
        gatehouse()
        curtain(.frontAlongY, from: -e + s, to: e - s, height: Fort.wallTop)
        squareTower(e, e, half: s, top: Fort.towerTop - 6, roofed: false, pennant: false)
    }

    /// Which stretch of the curtain wall: the two at the back, seen from within
    /// the fort, or the two at the front, seen from outside.
    private enum Stretch { case backAlongX, backAlongY, frontAlongX, frontAlongY }

    /// A stretch of the curtain wall from `a` to `b` along its length, to
    /// `height` points: weathered stone with its walkway on top, merlons along
    /// its outer edge and shields on its outer face, when `built` is true;
    /// otherwise fresh stone left rough at the top, being raised.
    private mutating func curtain(_ stretch: Stretch, from a: Double, to b: Double, height: Double, built: Bool = true) {
        typealias I = IronOldBuildingsInk
        let g = Fort.ground, e = Fort.edge, t = Fort.thick
        let walk: Paint = .colour(built ? I.pavingShade : I.rawStoneTop)
        let lit: Paint = .colour(built ? I.stone : I.rawStone), shade: Paint = .colour(built ? I.stoneShade : I.rawStoneShade)
        let rise = height - g, length = (b - a) * 32
        // The battlement at the back stops short of the corner towers.
        let clear = Fort.tower
        switch stretch {
        case .backAlongX:
            block(a, -e, b, -e + t, g, height, top: walk, left: lit, right: shade)
            wall(.left, from: a, -e + t, at: g) { p in
                p.courses(0, length, 0, rise)
                // A door to the stair up to the walkway.
                if built { p.arch(length * 0.3, 0, width: 6, height: 10, .colour(I.dark), line: 0.8) }
            }
            if built { fortMerlons(alongX: true, from: a + clear, to: b - clear, at: -e, depth: 0.08, on: height) }
        case .backAlongY:
            block(-e, a, -e + t, b, g, height, top: walk, left: lit, right: lit)
            wall(.right, from: -e + t, b, at: g) { p in p.courses(0, length, 0, rise) }
            if built { fortMerlons(alongX: false, from: a + clear, to: b - clear, at: -e, depth: 0.08, on: height) }
        case .frontAlongX:
            block(a, e - t, b, e, g, height, top: walk, left: lit, right: shade)
            wall(.left, from: a, e, at: g) { p in
                p.colour(p.panel(0, 0, length, 5), .colour(built ? I.footing : I.rawStoneShade))
                p.line([p.uv(0, 5), p.uv(length, 5)], width: 0.6, opacity: 0.8)
                p.courses(0, length, 5, rise)
                if built {
                    for u in [length * 0.13, length * 0.87] { p.scutum(u, rise - 13, w: 6, h: 9) }
                }
            }
            if built { fortMerlons(alongX: true, from: a, to: b, at: e - 0.08, depth: 0.08, on: height) }
        case .frontAlongY:
            block(e - t, a, e, b, g, height, top: walk, left: lit, right: shade)
            wall(.right, from: e, b, at: g) { p in
                p.colour(p.panel(0, 0, length, 5), .colour(built ? I.footingShade : I.rawStoneShade))
                p.line([p.uv(0, 5), p.uv(length, 5)], width: 0.6, opacity: 0.8)
                p.courses(0, length, 5, rise)
                if built {
                    for u in [length * 0.2, length * 0.5, length * 0.8] { p.scutum(u, rise - 13, w: 6, h: 9) }
                }
            }
            if built { fortMerlons(alongX: false, from: a, to: b, at: e - 0.08, depth: 0.08, on: height) }
        }
    }

    /// A square tower of dressed stone centred on (`cx`, `cy`), `half` tiles
    /// from its centre to each face, to `top` points, on a footing of darker
    /// stone with arched windows: under a pyramid roof of red tile with a band
    /// of the owner's colour below its eaves, flying the owner's pennant when
    /// `pennant` is true, when `roofed`; otherwise an open platform within merlons.
    private mutating func squareTower(_ cx: Double, _ cy: Double, half s: Double, top: Double, roofed: Bool, pennant flies: Bool) {
        typealias I = IronOldBuildingsInk
        let g = Fort.ground, (x0, y0, x1, y1) = (cx - s, cy - s, cx + s, cy + s), w = 2 * s * 32, rise = top - g
        shadow([iso(x1, y0, g), iso(x1 + 0.18, y0 + 0.08, g), iso(x1 + 0.18, y1, g), iso(x1, y1, g)], opacity: 0.12)
        block(x0, y0, x1, y1, g, top, top: roofed ? nil : .colour(I.paving), left: .colour(I.stone), right: .colour(I.stoneShade))
        let small = s < 0.25
        for side in [IronOldBuildingsSide.left, .right] {
            wall(side, from: side == .left ? x0 : x1, y1, at: g) { p in
                p.colour(p.panel(0, 0, w, 5), .colour(side == .left ? I.footing : I.footingShade))
                p.line([p.uv(0, 5), p.uv(w, 5)], width: 0.6, opacity: 0.8)
                p.courses(0, w, 5, rise)
                let window = small ? (width: 3.6, height: 6.4) : (width: 4.6, height: 8.0)
                if small {
                    p.arch(w / 2, rise - 20, width: window.width, height: window.height, .colour(I.dark), line: 0.7)
                } else {
                    for u in [w * 0.3, w * 0.7] {
                        p.arch(u, rise - 20, width: window.width, height: window.height, .colour(I.dark), line: 0.7)
                    }
                    p.grille(w / 2 - 2.2, 18, w: 4.4, h: 5.4)
                }
                if roofed { p.paintedBand(0, w, rise - 9, rise - 6.2) }
            }
        }
        if roofed {
            let peak = hippedRoof(x0, y0, x1, y1, eaves: top, rise: small ? 12 : 17, overhang: 0.05)
            if flies { pennant(at: iso(cx, cy, peak), height: small ? 13 : 15, length: small ? 12 : 14) }
        } else {
            // The merlons round the platform: along the back two sides, then the front two.
            let d = 0.08
            fortMerlons(alongX: true, from: x0, to: x1, at: y0, depth: d, on: top)
            fortMerlons(alongX: false, from: y0 + d, to: y1, at: x0, depth: d, on: top)
            fortMerlons(alongX: false, from: y0 + d, to: y1 - d, at: x1 - d, depth: d, on: top)
            fortMerlons(alongX: true, from: x0, to: x1, at: y1 - d, depth: d, on: top)
        }
    }

    /// The great tower: a square tower of dressed stone on a footing, with a
    /// barred window, arched windows on two storeys above, a band of the
    /// owner's colour under its eaves, and a pyramid roof of red tile from
    /// whose peak the legion's standard flies.
    private mutating func keep() {
        typealias I = IronOldBuildingsInk
        let (x0, y0, x1, y1) = Fort.keep
        let g = Fort.ground, top = Fort.keepTop, w = (x1 - x0) * 32
        shadow([iso(x1, y0, g), iso(x1 + 0.3, y0 + 0.1, g), iso(x1 + 0.3, y1 + 0.1, g), iso(x1, y1, g)], opacity: 0.12)
        block(x0 - 0.04, y0 - 0.04, x1 + 0.04, y1 + 0.04, g, g + 7, top: .colour(I.stoneTop), left: .colour(I.footing),
              right: .colour(I.footingShade), width: 1)
        block(x0, y0, x1, y1, g + 7, top, top: nil, left: .colour(I.stone), right: .colour(I.stoneShade), width: 1.2)
        let rise = top - g - 7
        for side in [IronOldBuildingsSide.left, .right] {
            wall(side, from: side == .left ? x0 : x1, y1, at: g + 7) { p in
                p.courses(0, w, 0, rise)
                p.grille(w / 2 - 2.6, 16, w: 5.2, h: 6.4)
                for u in [w * 0.28, w * 0.72] { p.arch(u, 36, width: 5.2, height: 9.5, .colour(I.dark), line: 0.8) }
                // The top storey: three arched openings in a row.
                for u in [w * 0.22, w * 0.5, w * 0.78] { p.arch(u, rise - 21, width: 4.6, height: 10, .colour(I.dark), line: 0.8) }
                p.line([p.uv(0, rise - 23.5), p.uv(w, rise - 23.5)], width: 0.7)
                p.paintedBand(0, w, rise - 9.4, rise - 6.2)
            }
        }
        let peak = hippedRoof(x0, y0, x1, y1, eaves: top, rise: 20, overhang: 0.07)
        vexillum(at: iso((x0 + x1) / 2, (y0 + y1) / 2, peak), height: 36, width: 16, length: 17)
    }

    /// The headquarters: a hall of dressed stone on a low podium, a door at
    /// its front, its portico of four columns under a gabled roof of red tile
    /// whose pediment carries the owner's colour round a wreath.
    private mutating func hall() {
        typealias I = IronOldBuildingsInk
        let (x0, y0, x1, y1) = Fort.hall
        let g = Fort.ground, base = g + 3, eaves = Fort.hallEaves, front = y1 + Fort.portico, w = (x1 - x0) * 32
        block(x0 - 0.05, y0 - 0.05, x1 + 0.05, front + 0.05, g, base, top: .colour(I.stoneTop), left: .colour(I.footing),
              right: .colour(I.footingShade), width: 1)
        block(x0, y0, x1, y1, base, eaves, top: nil, left: .colour(I.stone), right: .colour(I.stoneShade))
        wall(.left, from: x0, y1, at: base) { p in
            p.courses(0, w, 0, eaves - base)
            p.archedDoor(w / 2, 0, w: 7, h: 13, paint: I.sea)
        }
        wall(.right, from: x1, y1, at: base) { p in
            let d = (y1 - y0) * 32
            p.courses(0, d, 0, eaves - base)
            p.shuttered(d * 0.5 - 2, 11, w: 4, h: 6.4)
        }
        // The portico's columns, then the roof over them.
        let count = 4
        for k in 0..<count {
            let x = x0 + 0.08 + (x1 - x0 - 0.16) * Double(k) / Double(count - 1)
            column(at: iso(x, front - 0.06, base), height: eaves - base, radius: 1.7)
        }
        gabledRoof(x0, y0, x1, front, eaves: eaves, rise: 15)
    }

    /// The gate: a block over two arches closed by doors studded with iron,
    /// with windows over them and a cloth of the owner's colour between, under
    /// a battlement, between two square towers under roofs of tile.
    private mutating func gatehouse() {
        typealias I = IronOldBuildingsInk
        let gate = Fort.gate, g = Fort.ground, top = Fort.gateTop, w = (gate.x1 - gate.x0) * 32, r = Fort.gateTower
        squareTower(gate.x0 - r, Fort.gateTowerY, half: r, top: Fort.gateTowerTop, roofed: true, pennant: true)
        block(gate.x0, gate.y0, gate.x1, gate.y1, g, top, top: .colour(I.pavingShade), left: .colour(I.stone), right: .colour(I.stoneShade))
        wall(.left, from: gate.x0, gate.y1, at: g) { p in
            p.colour(p.panel(0, 0, w, 5), .colour(I.footing))
            p.line([p.uv(0, 5), p.uv(w, 5)], width: 0.6, opacity: 0.8)
            p.courses(0, w, 5, top - g)
            for u in [w * 0.27, w * 0.73] {
                p.archedDoor(u, 0, w: 8.4, h: 15, paint: I.timber)
                p.arch(u, 23, width: 3.8, height: 6.6, .colour(I.dark), line: 0.7)
            }
            p.hanging(w / 2, top: top - g - 4, width: 7, length: 19)
        }
        fortMerlons(alongX: true, from: gate.x0, to: gate.x1, at: gate.y1 - 0.08, depth: 0.08, on: top)
        squareTower(gate.x1 + r, Fort.gateTowerY, half: r, top: Fort.gateTowerTop, roofed: true, pennant: true)
    }

    /// Merlons along the top of a straight wall at `h`, from `a` to `b` along
    /// x (when `alongX`) or y, on the line `at` of the other axis, `depth`
    /// tiles thick toward the wall's inside, drawn from the far end.
    private mutating func fortMerlons(alongX: Bool, from a: Double, to b: Double, at c: Double, depth: Double, on h: Double,
                                      height m: Double = 6, size: Double = 0.13, gap: Double = 0.1) {
        typealias I = IronOldBuildingsInk
        var t = a + gap / 2
        while t + size <= b + 0.001 {
            let (x0, x1) = alongX ? (t, t + size) : (min(c, c + depth), max(c, c + depth))
            let (y0, y1) = alongX ? (min(c, c + depth), max(c, c + depth)) : (t, t + size)
            block(x0, y0, x1, y1, h, h + m, top: .colour(I.stoneTop), left: .colour(I.stone), right: .colour(I.stoneShade), width: 0.75)
            t += size + gap
        }
    }

    // MARK: The fort being built

    /// The fort being built: the curtain walls raised part of their height in
    /// fresh stone and left stepped, the corner towers and the gate's towers
    /// begun, the great tower's lower storeys inside scaffolding flying the
    /// owner's pennant, a treadwheel crane lifting stone onto it, the hall's
    /// podium laid with its columns' drums beside it, timber centring standing
    /// for the gate's arches, the legion's standard planted by the road, and
    /// stone, tile and timber to hand.
    private mutating func fortRising() {
        typealias I = IronOldBuildingsInk
        let g = Fort.ground, e = Fort.edge, t = Fort.thick, s = Fort.tower
        colour(level(-e + t, -e + t, e - t, e - t, g + 0.2), .colour(I.earthShade), opacity: 0.6)
        // The back walls: raised part of their height along part of their length, stepped down beyond.
        curtain(.backAlongX, from: -e, to: 0.2, height: 26, built: false)
        curtain(.backAlongX, from: 0.2, to: e, height: 15, built: false)
        curtain(.backAlongY, from: -e, to: 0.1, height: 26, built: false)
        curtain(.backAlongY, from: 0.1, to: e, height: 12, built: false)
        towerStump(-e, -e, half: s, top: 34)
        scaffold([(-e - s - 0.1, -e + s + 0.1), (-e + s + 0.1, -e + s + 0.1), (-e + s + 0.1, -e - s - 0.1)], from: g, height: 44,
                 levels: [14, 28, 40], boards: 28)
        // The great tower's lower storeys, open at the top, inside scaffolding.
        let (x0, y0, x1, y1) = Fort.keep
        block(x0 - 0.04, y0 - 0.04, x1 + 0.04, y1 + 0.04, g, g + 7, top: .colour(I.rawStoneTop), left: .colour(I.rawStoneShade),
              right: .colour(I.footingShade), width: 1)
        let wallTop = 42.0, w = (x1 - x0) * 32
        shell(x0, y0, x1, y1, from: g + 7, floor: 30, to: wallTop, thickness: 0.1, lit: .colour(I.rawStone),
              shade: .colour(I.rawStoneShade), top: .colour(I.rawStoneTop), ground: .colour(I.earthShade))
        for side in [IronOldBuildingsSide.left, .right] {
            wall(side, from: side == .left ? x0 : x1, y1, at: g + 7) { p in
                p.courses(0, w, 0, wallTop - g - 7)
                p.grille(w / 2 - 2.6, 16, w: 5.2, h: 6.4)
            }
        }
        // The next course begun along the back.
        blocks(x0, y0, x1 - 0.3, y0 + 0.1, from: wallTop, courses: 1)
        scaffold([(x0 - 0.12, y1 + 0.12), (x1 + 0.12, y1 + 0.12), (x1 + 0.12, y0 - 0.12)], from: g, height: 58,
                 levels: [18, 36, 50], boards: 40)
        pennant(at: iso(x1 + 0.12, y1 + 0.12, g + 58), height: 14, length: 15)
        treadwheel(at: (-0.12, 0.12), over: iso((x0 + x1) / 2 + 0.1, (y0 + y1) / 2 + 0.12, 64))
        // The hall's podium, its columns' drums lying beside it, and tiles stacked for its roof.
        let hall = Fort.hall
        block(hall.x0 - 0.05, hall.y0 - 0.05, hall.x1 + 0.05, hall.y1 + Fort.portico + 0.05, g, g + 3,
              top: .colour(I.rawStoneTop), left: .colour(I.rawStone), right: .colour(I.rawStoneShade), width: 1)
        blocks(hall.x0, hall.y0, hall.x1, hall.y0 + 0.12, from: g + 3, courses: 2)
        drum(0.2, 0.45, -0.2, on: g + 0.2, radius: 2.6)
        drum(0.55, 0.8, -0.16, on: g + 0.2, radius: 2.6)
        roofTiles(0.85, 0.2, 1.1, 0.42, from: g + 0.2, height: 6)
        // The side towers and the front walls, a few courses high.
        towerStump(-e, e, half: s, top: 22)
        towerStump(e, -e, half: s, top: 18)
        curtain(.frontAlongX, from: -e + s, to: -0.62, height: 16, built: false)
        curtain(.frontAlongX, from: 0.62, to: e - s, height: 10, built: false)
        // The gate: its two towers begun, and the timber centring for its arches.
        let gate = Fort.gate, r = Fort.gateTower
        towerStump(gate.x0 - r, Fort.gateTowerY, half: r, top: 20)
        centring(gate.x0, gate.x1, at: gate.y1 - 0.06)
        towerStump(gate.x1 + r, Fort.gateTowerY, half: r, top: 14)
        curtain(.frontAlongY, from: -e + s, to: 0.3, height: 14, built: false)
        curtain(.frontAlongY, from: 0.3, to: e - s, height: 8, built: false)
        towerStump(e, e, half: s, top: 10)
        // Materials beside: stone, logs, mortar, tiles, and the standard planted by the road.
        blocks(-1.95, 1.62, -1.68, 1.92, from: g, courses: 2)
        blocks(1.6, -1.95, 1.9, -1.7, from: g, courses: 1)
        logs(0.75, 1.3, 1.82, on: g)
        basket(at: iso(-1.0, 1.75, g), size: 0.9)
        roofTiles(1.7, 0.4, 1.94, 0.7, from: g, height: 5)
        vexillum(at: iso(0.55, 1.78, g), height: 34, width: 13, length: 15)
    }

    /// A square tower's shaft of fresh stone, begun to `top` points, on its footing.
    private mutating func towerStump(_ cx: Double, _ cy: Double, half s: Double, top: Double) {
        typealias I = IronOldBuildingsInk
        let g = Fort.ground, (x0, y0, x1, y1) = (cx - s, cy - s, cx + s, cy + s), w = 2 * s * 32
        block(x0, y0, x1, y1, g, top, top: .colour(I.rawStoneTop), left: .colour(I.rawStone), right: .colour(I.rawStoneShade))
        for side in [IronOldBuildingsSide.left, .right] {
            wall(side, from: side == .left ? x0 : x1, y1, at: g) { p in
                p.colour(p.panel(0, 0, w, min(5, top - g)), .colour(I.rawStoneShade))
                p.courses(0, w, min(5, top - g), top - g)
            }
        }
    }

    /// The timber centring on which the gate's two arches will be turned: for
    /// each, two uprights and a frame bent to the arch, across the gateway at `y`.
    private mutating func centring(_ x0: Double, _ x1: Double, at y: Double) {
        typealias I = IronOldBuildingsInk
        let g = Fort.ground, w = (x1 - x0) * 32
        wall(.left, from: x0, y, at: g) { p in
            for u in [w * 0.27, w * 0.73] {
                let r = 4.2, spring = 10.8
                for a in [u - r, u + r] { p.pole(p.uv(a, 0), p.uv(a, spring), width: 1.6, colour: I.timber) }
                var d = PathData()
                d.move(p.uv(u - r, spring))
                for k in 1...10 {
                    let angle = Double.pi * Double(k) / 10
                    d.line(p.uv(u - r * cos(angle), spring + r * sin(angle)))
                }
                p.svg.path(d, stroke: .colour(I.line), width: 3.2)
                p.svg.path(d, stroke: .colour(I.timberLight), width: 1.9)
                p.pole(p.uv(u - r, spring), p.uv(u + r, spring), width: 1.2, colour: I.timber)
                p.pole(p.uv(u, spring), p.uv(u, spring + r), width: 1.1, colour: I.timber)
            }
        }
    }

    /// A treadwheel crane standing in the court with its foot at (x, y) on the
    /// map: a great wheel of timber on its frame, turned by treading, winding
    /// the rope that runs up a jib of two timbers leaning to `head` on the
    /// screen, from which a block of stone hangs over the work.
    private mutating func treadwheel(at foot: (Double, Double), over head: P) {
        typealias I = IronOldBuildingsInk
        let g = Fort.ground + 0.2, (x, y) = foot
        // The jib: two timbers from the wheel's frame up to the head, stayed back to a stake.
        let a = iso(x - 0.05, y - 0.18, g), b = iso(x + 0.05, y + 0.2, g)
        svg.line([head, iso(x + 0.6, y + 0.05, g)], stroke: .colour(I.line), width: 0.6)
        pole(iso(x + 0.6, y + 0.05, g), iso(x + 0.6, y + 0.05, g + 5), width: 1.2, colour: I.timberDark)
        shearLegs(a, b, head: head, drop: 16)
        // The wheel, in the plane facing +y, a little in front of the jib's feet.
        let radius = 10.5, hub = 12.5
        wall(.left, from: x - 0.33, y + 0.3, at: g) { p in
            let c = p.uv(10.5, hub)
            // The frame that carries the axle.
            for (u0, u1) in [(2.0, 10.5), (19.0, 10.5)] { p.pole(p.uv(u0, 0), p.uv(u1, hub), width: 1.7, colour: I.timber) }
            p.pole(p.uv(1, 0.6), p.uv(20, 0.6), width: 1.6, colour: I.timberDark)
            // The rim, double, with the treads between, and the spokes.
            var spokes = PathData()
            for k in 0..<8 {
                let angle = Double.pi * Double(k) / 4 + 0.2
                spokes.move(c); spokes.line(c + P(cos(angle), sin(angle)) * (radius - 0.6))
            }
            p.svg.path(spokes, stroke: .colour(I.line), width: 1.9)
            p.svg.path(spokes, stroke: .colour(I.timberLight), width: 0.9)
            var treads = PathData()
            for k in 0..<20 {
                let angle = Double.pi * Double(k) / 10
                treads.move(c + P(cos(angle), sin(angle)) * (radius - 2.2))
                treads.line(c + P(cos(angle), sin(angle)) * radius)
            }
            for ring in [radius, radius - 2.2] {
                p.svg.circle(c, ring, fill: .none, stroke: .colour(I.line), width: 2.4)
                p.svg.circle(c, ring, fill: .none, stroke: .colour(I.timberLight), width: 1.3)
            }
            p.svg.path(treads, stroke: .colour(I.line), width: 0.6)
            p.svg.circle(c, 1.6, fill: .colour(I.timberDark), stroke: .colour(I.line), width: 0.6)
        }
        // The rope from the wheel's drum up to the head.
        svg.line([iso(x - 0.33 + 10.5 / 32, y + 0.3, g + hub), head + P(1.6, 0.6)], stroke: .colour(I.line), width: 0.6)
    }
}
