// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Bronze-age barracks: a long hall of mud brick behind stepped merlons,
// entered by a gateway between two towers. Round shields in the owner's colour
// hang along its wall, and the owner's standard flies over a yard with a rack
// of spears and a post to practise on. Its footprint is three tiles square: x
// and y run from -1.5 to 1.5.

extension BronzeBuildingsPainter {
    mutating func barracks(complete: Bool) {
        typealias I = BronzeBuildingsInk
        block(-1.5, -1.5, 1.5, 1.5, 0, 2, top: .colour(I.earth), left: .colour(I.earthShade), right: .colour(I.earthShade),
              width: 1)
        if complete { hall() } else { hallRising() }
    }

    private static let hallBox = (x0: -1.38, y0: -1.38, x1: 1.02, y1: 0.12)
    private static let towers: [(x0: Double, x1: Double)] = [(-0.64, -0.36), (0.14, 0.42)]
    private static let towerFront = 0.28

    private mutating func hall() {
        typealias I = BronzeBuildingsInk
        let (x0, y0, x1, y1) = Self.hallBox
        let h0 = 2.0, h1 = 31.0, roof = 28.0, t = 0.06
        let leftLength = (x1 - x0) * 32, rightLength = (y1 - y0) * 32
        shadow([iso(x1, y0, h0), iso(x1 + 0.26, y0 + 0.16, h0), iso(x1 + 0.26, y1 + 0.1, h0), iso(x1, y1, h0)])
        shell(x0, y0, x1, y1, from: h0, floor: roof, to: h1, thickness: t, lit: .colour(I.sand), shade: .colour(I.sandShade),
              top: .colour(I.sandTop), ground: .colour(I.earth)) { p in
            // The merlons along the back of the roof, seen from inside.
            p.wall(.left, from: x0 + t, y0 + t, at: h1) { q in q.merlons(0, (x1 - x0 - 2 * t) * 32, on: 0, .colour(I.sand)) }
            p.wall(.right, from: x0 + t, y1 - t, at: h1) { q in
                q.merlons(0, (y1 - y0 - 2 * t) * 32, on: 0, .colour(I.sandShade))
            }
            // The house over the stair to the roof, and a jar of water by it.
            let (s0, s1) = (x0 + t + 0.06, x0 + t + 0.42)
            p.block(s0, s0, s1, s1, roof, roof + 9, top: .colour(I.sandTop), left: .colour(I.sand), right: .colour(I.sandShade),
                    width: 1)
            p.wall(.left, from: s0, s1, at: roof) { q in
                q.shape(q.panel(4.4, 0, 9.6, 6.6), .colour(I.dark), width: 0.8)
                q.shape(q.panel(3.6, 6.6, 10.4, 7.8), .colour(I.timber), width: 0.6)
            }
            p.jar(at: p.iso(s1 + 0.12, s0 + 0.1, roof), size: 0.9, paint: I.clay)
        }
        wall(.left, from: x0, y1, at: h0) { p in
            p.courses(0, leftLength, 0, h1 - h0 - 4.6, opacity: 0.35)
            p.frieze(leftLength, h1 - h0)
            // The gateway between the towers, its doors of timber studded with bronze.
            let g0 = (Self.towers[0].x1 - x0) * 32, g1 = (Self.towers[1].x0 - x0) * 32
            p.arch((g0 + g1) / 2, 0, width: g1 - g0 - 1, height: 19, .colour(I.dark), line: 1.1)
            p.shape(p.panel(g0 + 1.4, 0, g1 - 1.4, 13.4), .colour(I.timber), width: 0.9)
            p.line([p.uv((g0 + g1) / 2, 0.3), p.uv((g0 + g1) / 2, 13.1)], width: 0.7)
            for v in [3.4, 7, 10.6] {
                for u in stride(from: g0 + 3.2, to: g1 - 2.4, by: 2.4) {
                    p.svg.circle(p.uv(u, v), 0.45, fill: .colour(I.bronzeLight))
                }
            }
            for u in [5.4, 12.2] { p.shield(at: p.uv(u, 14.5), radius: 3.1) }
            for u in [leftLength - 17.6, leftLength - 10.4, leftLength - 3.6] { p.shield(at: p.uv(u, 14.5), radius: 3.1) }
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.courses(0, rightLength, 0, h1 - h0 - 4.6, opacity: 0.35)
            p.frieze(rightLength, h1 - h0)
            for u in stride(from: 7.0, to: rightLength - 4, by: 9) {
                p.shape(p.panel(u, 11, u + 1.8, 19), .colour(I.dark), width: 0.7)
            }
        }
        wall(.left, from: x0, y1, at: h1) { p in p.merlons(0, leftLength, on: 0, .colour(I.sand)) }
        wall(.right, from: x1, y1, at: h1) { p in p.merlons(0, rightLength, on: 0, .colour(I.sandShade)) }
        // The towers either side of the gateway, standing out from the wall.
        for tower in Self.towers { gateTower(tower.x0, y1, tower.x1, Self.towerFront, from: h0) }
        rackOfSpears(-1.12, 0.92)
        practicePost(at: iso(0.66, 1.0, h0))
        standard(at: iso(1.2, 0.78, h0))
    }

    /// The band under a wall's merlons drawn with `wall`, `height` points up:
    /// a course of fired brick with a light zigzag.
    private mutating func frieze(_ length: Double, _ height: Double) {
        typealias I = BronzeBuildingsInk
        colour(panel(0, height - 4.2, length, height - 0.6), .colour(I.terracotta))
        line([uv(0, height - 4.2), uv(length, height - 4.2)], width: 0.7)
        line([uv(0, height - 0.6), uv(length, height - 0.6)], width: 0.6)
        var points: [P] = []
        var u = 1.0, up = false
        while u <= length - 0.5 {
            points.append(uv(u, up ? height - 1.4 : height - 3.4))
            u += 1.8
            up.toggle()
        }
        svg.line(points, stroke: .colour(I.light), width: 0.7)
    }

    /// A tower from (x0, y0) to (x1, y1) on the map, standing out from the hall's wall.
    private mutating func gateTower(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, from h0: Double) {
        typealias I = BronzeBuildingsInk
        let h1 = 38.0, t = 0.05
        shell(x0, y0, x1, y1, from: h0, floor: h1 - 3, to: h1, thickness: t, lit: .colour(I.sand),
              shade: .colour(I.sandShade), top: .colour(I.sandTop), ground: .colour(I.earth), width: 1.1)
        wall(.left, from: x0, y1, at: h0) { p in
            let w = (x1 - x0) * 32
            p.courses(0, w, 0, h1 - h0 - 4.6, opacity: 0.35)
            p.frieze(w, h1 - h0)
            p.shape(p.panel(w / 2 - 0.9, 18, w / 2 + 0.9, 25), .colour(I.dark), width: 0.7)
            p.merlons(0, w, on: h1 - h0, .colour(I.sand))
        }
        wall(.right, from: x1, y1, at: h0) { p in
            let w = (y1 - y0) * 32
            p.courses(0, w, 0, h1 - h0 - 4.6, opacity: 0.35)
            p.frieze(w, h1 - h0)
            p.merlons(0, w, on: h1 - h0, .colour(I.sandShade))
        }
    }

    /// A rack of spears with bronze heads, its foot at (x, y), along x.
    private mutating func rackOfSpears(_ x: Double, _ y: Double) {
        typealias I = BronzeBuildingsInk
        let h0 = 2.0, length = 0.5
        pole(iso(x, y, h0), iso(x, y, h0 + 12), width: 1.3)
        // The spears stand nearly upright behind the bar, their heads above it.
        for i in 0..<5 {
            let along = x + length * (0.12 + Double(i) * 0.19)
            let foot = iso(along, y - 0.06, h0), head = iso(along + 0.015, y - 0.1, h0 + 27)
            svg.line([foot, head], stroke: .colour(I.line), width: 1.5)
            svg.line([foot, head], stroke: .colour(I.timberLight), width: 0.7)
            shape([head, head + P(1.3, 3.6), head + P(0, 6.4), head + P(-1.3, 3.6)], .colour(I.bronzeLight), width: 0.6)
        }
        pole(iso(x + length, y, h0), iso(x + length, y, h0 + 12), width: 1.3)
        pole(iso(x - 0.04, y, h0 + 10), iso(x + length + 0.04, y, h0 + 10), width: 1.2)
    }

    /// A post with a crosspiece, bound with straw, for practice with the spear.
    private mutating func practicePost(at p: P) {
        typealias I = BronzeBuildingsInk
        svg.ellipse(p + P(0, 0.4), 5, 1.6, fill: .colour("#000000"), opacity: 0.14)
        pole(p, p - P(0, 22), width: 1.6)
        pole(p - P(5.6, 16.6), p - P(-5.6, 16.6), width: 1.2)
        let body = [p - P(3.6, 21), p - P(-3.6, 21), p - P(-2.8, 8), p - P(2.8, 8)]
        shape(body, .colour(I.reed), width: 0.8)
        line([p - P(3.2, 16.4), p - P(-3.2, 16.4)], width: 0.6)
        line([p - P(3, 12.2), p - P(-3, 12.2)], width: 0.6)
        svg.circle(p - P(0, 24.4), 3, fill: .colour(I.reed), stroke: .colour(I.line), width: 0.8)
    }

    /// The owner's standard: a tall pole with a crossbar and a banner hanging from it.
    private mutating func standard(at p: P) {
        typealias I = BronzeBuildingsInk
        let top = p - P(0, 56)
        svg.ellipse(p + P(0, 0.4), 4, 1.4, fill: .colour("#000000"), opacity: 0.14)
        svg.line([p, top], stroke: .colour(I.timberDark), width: 1.9)
        let bar = top + P(0, 4)
        // The banner, its foot cut in three tongues, a sun on it.
        let w = 14.0, l = 21.0
        let cloth = [bar + P(-w / 2, 0), bar + P(w / 2, 0), bar + P(w / 2, l), bar + P(w / 4, l - 3), bar + P(0, l),
                     bar + P(-w / 4, l - 3), bar + P(-w / 2, l)]
        shape(cloth, .team, width: 1)
        svg.circle(bar + P(0, 8.4), 3.1, fill: .colour(I.light), stroke: .colour(I.line), width: 0.6)
        for i in 0..<8 {
            let a = Double(i) * .pi / 4
            line([bar + P(0, 8.4) + P(cos(a), sin(a)) * 4.2, bar + P(0, 8.4) + P(cos(a), sin(a)) * 5.6], width: 0.6)
        }
        pole(bar + P(-w / 2 - 2, 0), bar + P(w / 2 + 2, 0), width: 1.2, colour: I.timberDark)
        shape([top + P(-1.6, 0.6), top + P(0, -3.6), top + P(1.6, 0.6)], .colour(I.bronzeLight), width: 0.7)
    }

    /// The barracks being built: the hall's walls of bare brick half raised,
    /// the towers begun, scaffolding along the hall, and brick and timber to hand.
    private mutating func hallRising() {
        typealias I = BronzeBuildingsInk
        let (x0, y0, x1, y1) = Self.hallBox
        let h0 = 2.0, top = 16.0
        let leftLength = (x1 - x0) * 32, rightLength = (y1 - y0) * 32
        logs(-1.3, -0.4, -1.45, on: h0, radius: 1.5)
        shadow([iso(x1, y0, h0), iso(x1 + 0.16, y0 + 0.1, h0), iso(x1 + 0.16, y1 + 0.06, h0), iso(x1, y1, h0)])
        shell(x0, y0, x1, y1, from: h0, floor: h0, to: top, thickness: 0.1, lit: .colour(I.rawBrick),
              shade: .colour(I.rawBrickShade), top: .colour(I.rawBrickTop), ground: .colour(I.earth)) { p in
            p.bricks(-0.9, -0.9, -0.6, -0.6, from: h0, courses: 3)
            p.basket(at: p.iso(-0.2, -0.6, h0), size: 0.9)
        }
        wall(.left, from: x0, y1, at: h0) { p in
            p.courses(0, leftLength, 0, top - h0)
            let g0 = (Self.towers[0].x1 - x0) * 32, g1 = (Self.towers[1].x0 - x0) * 32
            p.shape(p.panel(g0 + 0.5, 0, g1 - 0.5, top - h0), .colour(I.dark), width: 1)
        }
        wall(.right, from: x1, y1, at: h0) { p in p.courses(0, rightLength, 0, top - h0) }
        bricks(x0, y0, x0 + 0.1, y0 + 0.9, from: top, courses: 2)
        bricks(x0 + 0.1, y0, 0.2, y0 + 0.1, from: top, courses: 2)
        for tower in Self.towers {
            block(tower.x0, y1, tower.x1, Self.towerFront, h0, 10, top: .colour(I.rawBrickTop), left: .colour(I.rawBrick),
                  right: .colour(I.rawBrickShade), width: 1)
            wall(.left, from: tower.x0, Self.towerFront, at: h0) { p in p.courses(0, (tower.x1 - tower.x0) * 32, 0, 8) }
        }
        scaffold([(x1 + 0.14, 0.05), (x1 + 0.14, -0.6), (x1 + 0.14, -1.25)], from: h0, height: 28, levels: [10, 20], boards: 10)
        scaffold([(-1.3, 0.5), (-0.8, 0.5)], from: h0, height: 26, levels: [10, 20], boards: 10)
        pennant(at: iso(x1 + 0.14, 0.05, h0 + 28), height: 12)
        bricks(0.55, 0.62, 0.85, 0.92, from: h0, courses: 4)
        bricks(0.95, 0.75, 1.2, 1.05, from: h0, courses: 2)
        logs(-0.2, 0.6, 1.2, on: h0, radius: 1.6)
        ladder(foot: iso(0.5, 0.5, h0), iso(0.68, 0.5, h0), head: iso(0.5, y1 + 0.02, top + 3), iso(0.68, y1 + 0.02, top + 3),
               rungs: 5)
    }
}
