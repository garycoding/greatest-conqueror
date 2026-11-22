// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The town centre of the Stone age: a long hall of timber, wattle and daub
// under a steep roof of thatch ridged with turf, its door in the gable end that
// faces the lower right. The gable and a band along the wall are painted in
// the team's colour, and the team's pennant flies from the gable's peak. A
// totem stands at the hall's left, a fire burns in the yard before it, and
// firewood is stacked by the door. Under construction: the hall's frame of
// posts, beams and rafters, wattle woven along the foot of its walls, and
// timber, thatch and stone piled in the yard.

/// The hall's measurements. Its walls stand on `x0...x1` by `y0...y1`, in
/// tiles from the centre of the footprint (3 by 3); heights are in points.
private enum Hall {
    static let x0 = -1.25, x1 = 0.85, y0 = -1.2, y1 = 0.4
    static let ridgeY = (y0 + y1) / 2
    static let wall = 34.0
    static let ridge = 78.0
    /// How far the roof falls for each tile from the ridge, in points.
    static let fall = 50.0
    /// How far the thatch reaches beyond the walls, in tiles: at the eaves, and at the gables.
    static let eaveReach = 0.16, gableReach = 0.14

    /// The height of the roof's surface at `y`.
    static func roof(_ y: Double) -> Double { ridge - fall * abs(y - ridgeY) }

    /// A point of the long wall that faces the lower left, `u` of the way along it from its left end.
    static func long(_ u: Double, _ h: Double) -> P { StoneBuildingsSketch.at(x0 + (x1 - x0) * u, y1, h) }

    /// A point of the gable wall that faces the lower right, `v` of the way along it from the front corner.
    static func gable(_ v: Double, _ h: Double) -> P { StoneBuildingsSketch.at(x1, y1 + (y0 - y1) * v, h) }
}

private func point(_ x: Double, _ y: Double, _ h: Double = 0) -> P { StoneBuildingsSketch.at(x, y, h) }

extension StoneBuildingsSketch {
    mutating func townCentre(complete: Bool) {
        earth(3)
        if complete {
            hall()
            woodpile(at: point(1.24, -0.98))
            totem(at: point(-1.2, 1.02))
            fire(at: point(0.05, 1.02))
        } else {
            hallFrame()
        }
    }

    private mutating func hall() {
        let ex0 = Hall.x0 - Hall.gableReach, ex1 = Hall.x1 + Hall.gableReach
        let ey0 = Hall.y0 - Hall.eaveReach, ey1 = Hall.y1 + Hall.eaveReach
        let eave = Hall.roof(ey1), wall = Hall.wall
        let long = Hall.long, gable = Hall.gable

        // The roof's shadow on the ground, along the foot of the walls.
        shadow(StoneBuildingsOutline([point(ex0, ey0), point(ex1 + 0.16, ey0), point(ex1 + 0.16, ey1 + 0.14), point(ex0, ey1 + 0.14)]))

        // The long wall: daub between posts, and a band painted in the team's
        // colour with a zigzag on it in the light colour.
        shape([long(0, 0), long(1, 0), long(1, wall), long(0, wall)], .colour(Ink.light))
        let (low, high) = (8.5, 14.0)
        colour([long(0, low), long(1, low), long(1, high), long(0, high)], .team, shift: P(0, 0))
        stroke([long(0, low), long(1, low)], width: 0.9)
        stroke([long(0, high), long(1, high)], width: 0.9)
        zigzag(StoneBuildingsSketch.points(from: long(0, low + 1.3), to: long(1, low + 1.3), count: 28),
               tooth: P(0, -2.9), width: 1.1, colour: Ink.light)
        for u in [0.0, 0.25, 0.5, 0.75] { pole(long(u, -0.6), long(u, wall + 1), width: 3.4) }

        // The gable wall, in shade, painted with a triangle in the team's
        // colour bearing a sun and a zigzag in the light colour.
        let peak = Hall.ridge - 4
        shape([gable(0, 0), gable(1, 0), gable(1, wall), gable(0.5, peak), gable(0, wall)],
              .colour(StoneBuildingsInk.daubShade))
        let panel = [gable(0.13, 33), gable(0.87, 33), gable(0.5, 67)]
        colour(panel, .team, shift: P(0, 0))
        stroke(panel + [panel[0]], width: 1)
        svg.circle(gable(0.5, 48.5), 3.9, fill: .colour(Ink.light))
        zigzag(StoneBuildingsSketch.points(from: gable(0.23, 36.2), to: gable(0.77, 36.2), count: 10), tooth: P(0, -3),
               width: 1.1, colour: Ink.light)
        // The door: dark, framed in timber, a hide hung across part of it.
        shape([gable(0.36, 0), gable(0.64, 0), gable(0.615, 21), gable(0.385, 21)], .colour(StoneBuildingsInk.hollow),
              line: 1.1, shift: StoneBuildingsSketch.nudge)
        var curtain = StoneBuildingsOutline()
        curtain.move(gable(0.385, 21))
        curtain.line(gable(0.5, 21))
        curtain.quad(gable(0.47, 13), gable(0.43, 10.5))
        curtain.quad(gable(0.46, 4), gable(0.475, 0.2))
        curtain.line(gable(0.37, 0.2))
        curtain.close()
        shape(curtain, .colour(Ink.hide), line: 1, shift: StoneBuildingsSketch.nudge)
        stroke([gable(0.39, 11.2), gable(0.445, 10.4)], width: 1.3, colour: Ink.darkHide)
        for (v, h) in [(0.41, 17.0), (0.455, 6.0), (0.47, 18.6)] {
            svg.ellipse(gable(v, h), 1.2, 0.9, fill: .colour(Ink.darkHide))
        }
        pole(gable(0.355, -0.5), gable(0.38, 22.4), width: 2.6)
        pole(gable(0.645, -0.5), gable(0.62, 22.4), width: 2.6)
        pole(gable(0.33, 22), gable(0.67, 22), width: 2.8)
        for v in [0.0, 1.0] { pole(gable(v, -0.6), gable(v, wall + 1), width: 3.6) }

        // The roof: the cut edge of the thatch along the gable, the slope
        // toward the lower left with its courses, and the ragged eaves.
        let r0 = point(ex0, Hall.ridgeY, Hall.ridge), r1 = point(ex1, Hall.ridgeY, Hall.ridge)
        let e0 = point(ex0, ey1, eave), e1 = point(ex1, ey1, eave), e2 = point(ex1, ey0, eave), e3 = point(ex0, ey0, eave)
        let thick = 5.0
        shape([e1, r1, e2, e2 + P(0, thick), r1 + P(0, thick + 1.5), e1 + P(0, thick)],
              .colour(StoneBuildingsInk.thatchDeep))
        shape([r0, r1, e1, e0], .colour(Ink.hide))
        let down = StoneBuildingsSketch.unit(e0 - r0)
        for f in [0.3, 0.53, 0.76] {
            let y = Hall.ridgeY + (ey1 - Hall.ridgeY) * f, h = Hall.roof(y)
            scallops(StoneBuildingsSketch.points(from: point(ex0 + 0.05, y, h), to: point(ex1 - 0.04, y, h), count: 17),
                     width: 0.9, opacity: 0.85) { _ in down * 1.3 }
        }
        let lip = 4.0
        shape([e0, e1, e1 + P(0, lip), e0 + P(0, lip)], .colour(StoneBuildingsInk.thatchDeep), line: 1.1)
        scallops(StoneBuildingsSketch.points(from: e0 + P(0, lip), to: e1 + P(0, lip), count: 21), width: 1) { _ in
            P(0, 0.9)
        }

        // The rafters' ends crossed above the ridge at both gables, the ridge
        // capped with turf, and the pennant on the near gable's peak.
        for (r, edges) in [(r0, [e0, e3]), (r1, [e1, e2])] {
            for e in edges {
                let u = StoneBuildingsSketch.unit(r - e)
                pole(r - u * 4, r + u * 12, width: 3)
            }
        }
        var turf = StoneBuildingsOutline()
        let cap = 7.5
        turf.move(r0 + P(0, -2.4))
        turf.line(r1 + P(0, -2.4))
        turf.line(r1 + down * cap)
        let hem = StoneBuildingsSketch.points(from: r1 + down * cap, to: r0 + down * cap, count: 12)
        for (p, q) in zip(hem, hem.dropFirst()) { turf.quad((p + q) * 0.5 + down * 5, q) }
        turf.close()
        shape(turf, .colour(Ink.moss), line: 1.1)
        for f in stride(from: 0.08, to: 0.95, by: 0.12) {
            let p = r0 + (r1 - r0) * f + down * 2.5
            stroke([p, p + P(0.8, -2.2)], width: 0.9, colour: Ink.darkMoss)
        }
        pennant(at: r1 + P(0, 1), height: 34)
    }

    /// A totem: a post carved with two faces and crowned with a bird whose
    /// spread wings are painted in the team's colour.
    private mutating func totem(at foot: P) {
        moved(to: foot) { s in
            let nudge = StoneBuildingsSketch.nudge
            s.shadow(StoneBuildingsSketch.lump(P(3, 0.6), 9, 3))
            s.shape([P(-5, 0.6), P(5, 0.6), P(5, -50), P(-5, -50)], .colour(Ink.wood), line: 1.2, shift: nudge)
            // The lower face: a heavy brow, round eyes, and a wide mouth with teeth.
            s.shape([P(-6, -16.5), P(6, -16.5), P(6, -19.5), P(-6, -19.5)], .colour(Ink.handle), line: 1, shift: nudge)
            for x in [-2.4, 2.4] {
                s.svg.ellipse(P(x, -13.4), 1.8, 1.5, fill: .colour(Ink.light), stroke: .colour(Ink.line), width: 0.8)
                s.svg.circle(P(x + 0.4, -13.2), 0.8, fill: .colour(Ink.line))
            }
            s.shape([P(-3.6, -8), P(3.6, -8), P(3.2, -4.6), P(-3.2, -4.6)], .colour(StoneBuildingsInk.hollow), line: 0.9,
                    shift: P(0, 0))
            for x in [-1.6, 0.0, 1.6] {
                s.svg.polygon([P(x - 0.6, -8), P(x + 0.6, -8), P(x, -6.6)], fill: .colour(Ink.light))
            }
            // A band painted in moss between the faces.
            s.shape([P(-5, -21.5), P(5, -21.5), P(5, -25), P(-5, -25)], .colour(Ink.moss), line: 1, shift: P(0, 0))
            // The upper face, painted in the light colour, with slanted eyes and a hooked beak.
            s.shape([P(-5, -26.5), P(5, -26.5), P(5, -40), P(-5, -40)], .colour(Ink.light), line: 1, shift: P(0, 0))
            for x in [-2.3, 2.3] {
                s.svg.polygon([P(x - 1.8, -34.6), P(x + 1.8, -35.8), P(x + 1.2, -33.4), P(x - 1.4, -33.2)],
                              fill: .colour(Ink.line))
            }
            var beak = StoneBuildingsOutline()
            beak.move(P(4.4, -32.6))
            beak.quad(P(9.6, -32.4), P(9.4, -28.2))
            beak.quad(P(7.4, -29.6), P(4.4, -29.4))
            beak.close()
            s.shape(beak, .colour(Ink.hide), line: 1, shift: nudge)
            s.zigzag(StoneBuildingsSketch.points(from: P(-4.4, -28.6), to: P(4.4, -28.6), count: 6), tooth: P(0, -1.8),
                     width: 0.8, colour: Ink.darkHide)
            // The wings, spread wide and painted in the team's colour, their
            // feathers' ends cut in a zigzag; a zigzag on them in the light colour.
            var wings = StoneBuildingsOutline()
            wings.move(P(-18, -48.5))
            wings.quad(P(-9, -44.2), P(0, -45.2))
            wings.quad(P(9, -44.2), P(18, -48.5))
            let tips = StoneBuildingsSketch.points(from: P(17, -42.4), to: P(-17, -42.4), count: 8)
            wings.line(P(16.4, -41.6))
            for (i, p) in tips.enumerated() where i > 0 { wings.line(i % 2 == 1 ? p + P(0, -2.6) : p + P(0, 0.6)) }
            wings.close()
            s.colour(wings, .team, shift: nudge)
            s.zigzag(StoneBuildingsSketch.points(from: P(-13, -45.6), to: P(13, -45.6), count: 10), tooth: P(0, -1.8),
                     width: 0.9, colour: Ink.light)
            s.stroke(wings, width: 1.1)
            // The bird's head, its eye, and its beak toward the right.
            s.svg.circle(P(-0.3, -51.4) + nudge, 5.2, fill: .colour(Ink.wood))
            s.svg.circle(P(-0.3, -51.4), 5.2, fill: .none, stroke: .colour(Ink.line), width: 1.1)
            s.shape([P(4.2, -53.6), P(10.4, -51.4), P(4.4, -49.2)], .colour(Ink.stone), line: 1, shift: nudge)
            s.svg.circle(P(1.2, -52.6), 1.5, fill: .colour(Ink.light), stroke: .colour(Ink.line), width: 0.7)
            s.svg.circle(P(1.5, -52.5), 0.7, fill: .colour(Ink.line))
        }
    }

    /// A fire in a ring of stones, two logs burning.
    private mutating func fire(at centre: P) {
        moved(to: centre) { s in
            let nudge = StoneBuildingsSketch.nudge
            s.colour(StoneBuildingsSketch.lump(P(0, 0.3), 12.5, 6.2, turn: 2), .colour(StoneBuildingsInk.earthDark),
                     shift: P(0, 0), opacity: 0.5)
            let stones = stride(from: 10.0, to: 370, by: 40).map { a -> (P, Int) in
                let r = a * .pi / 180
                return (P(10.4 * cos(r), 5.2 * sin(r)), Int(a) / 40)
            }
            for (p, turn) in stones where p.y < 0 {
                s.shape(StoneBuildingsSketch.lump(p, 2.9, 2, turn: turn), .colour(StoneBuildingsInk.stoneShade), line: 0.9,
                        shift: nudge)
            }
            s.pole(P(-7, 1), P(5.5, -2.6), width: 2.6, colour: Ink.handle)
            s.pole(P(-5.5, -2.6), P(7, 1), width: 2.6, colour: Ink.handle)
            var flame = StoneBuildingsOutline()
            flame.move(P(-6.4, -0.4))
            flame.quad(P(-8.4, -6.4), P(-4.8, -11.6))
            flame.quad(P(-3.6, -6.6), P(-1.6, -7.2))
            flame.quad(P(-2.8, -14.4), P(0.6, -19.4))
            flame.quad(P(2, -12.4), P(2.8, -8))
            flame.quad(P(4, -10.2), P(5.6, -13.2))
            flame.quad(P(8.6, -6), P(6.4, -0.4))
            flame.close()
            s.colour(flame, .colour(StoneBuildingsInk.ember), shift: nudge)
            var core = StoneBuildingsOutline()
            core.move(P(-3.4, -0.8))
            core.quad(P(-4.6, -5.4), P(-1.6, -8.8))
            core.quad(P(-0.8, -5.6), P(0.4, -12))
            core.quad(P(2.6, -6.4), P(3.4, -0.8))
            core.close()
            s.colour(core, .colour(Ink.light), shift: P(0, 0))
            s.stroke(flame, width: 1.1)
            for (p, turn) in stones where p.y >= 0 {
                s.shape(StoneBuildingsSketch.lump(p, 3.1, 2.1, turn: turn), .colour(Ink.stone), line: 0.9, shift: nudge)
            }
        }
    }

    /// The hall being built: its frame of posts, beams and rafters, wattle
    /// woven along the foot of its walls and daub begun on it, and the
    /// materials piled in the yard, with the pennant tied to the near gable's
    /// ridge post.
    private mutating func hallFrame() {
        let (x0, x1, y0, y1, ry) = (Hall.x0, Hall.x1, Hall.y0, Hall.y1, Hall.ridgeY)
        let wall = Hall.wall, ridge = Hall.ridge - 4
        let xs = [x0, x0 + (x1 - x0) / 3, x0 + (x1 - x0) * 2 / 3, x1]
        let long = Hall.long, gable = Hall.gable

        timbers(at: point(-1.26, 0.96))
        // The far side: its wall's posts and beam, the far gable's post and
        // beam, the far slope's rafters, and the ridge beam.
        for x in xs { pole(point(x, y0, -0.6), point(x, y0, wall + 1), width: 3.2) }
        pole(point(x0 - 0.08, y0, wall), point(x1 + 0.08, y0, wall), width: 2.8)
        pole(point(x0, ry, -0.6), point(x0, ry, ridge + 1), width: 3.2)
        pole(point(x0, y0 - 0.08, wall), point(x0, y1 + 0.08, wall), width: 2.8)
        for x in xs {
            let foot = point(x, y0 - 0.12, wall - 4), top = point(x, ry, ridge)
            let reach = (x == x0 || x == x1) ? 10.0 : 0
            pole(foot, top + StoneBuildingsSketch.unit(top - foot) * reach, width: 2.4)
        }
        pole(point(x0 - 0.14, ry, ridge), point(x1 + 0.14, ry, ridge), width: 3)

        // The near gable: its ridge post, wattle woven either side of the
        // door's gap and daub begun on it, and its corner post.
        pole(gable(0.5, -0.6), gable(0.5, ridge + 1), width: 3.2)
        for (from, to, high) in [(0.64, 1.0, 21.0), (0.0, 0.36, 9.0)] {
            shape([gable(from, 0), gable(to, 0), gable(to, high), gable(from, high - 1.5)], .colour(Ink.wood), line: 1.1)
            for h in stride(from: 3.0, through: high - 2, by: 3) {
                zigzag(StoneBuildingsSketch.points(from: gable(from + 0.01, h), to: gable(to - 0.01, h), count: 8),
                       tooth: P(0, -1.2), width: 0.8, colour: Ink.handle)
            }
        }
        shape([gable(0.64, 0), gable(1, 0), gable(1, 12), gable(0.82, 13.5), gable(0.64, 10)],
              .colour(StoneBuildingsInk.daubShade), line: 1.1)
        pole(gable(1, -0.6), gable(1, wall + 1), width: 3.4)

        // The near wall: wattle woven between its posts along the foot, daub
        // begun at its left end, and the posts.
        shape([long(0, 0), long(0.68, 0), long(0.68, 15), long(0.34, 18), long(0, 19)], .colour(Ink.wood), line: 1.1)
        for h in stride(from: 3.0, through: 16, by: 3) {
            let end = h < 15 ? 0.67 : 0.4
            zigzag(StoneBuildingsSketch.points(from: long(0.01, h), to: long(end, h), count: Int(end * 26)),
                   tooth: P(0, -1.2), width: 0.8, colour: Ink.handle)
        }
        shape([long(0, 0), long(0.34, 0), long(0.34, 9), long(0.2, 11.5), long(0, 12.5)], .colour(Ink.light), line: 1.1)
        for u in [0.0, 1.0 / 3, 2.0 / 3, 1.0] { pole(long(u, -0.6), long(u, wall + 1), width: 3.4) }
        pole(point(x0 - 0.08, y1, wall), point(x1 + 0.08, y1, wall), width: 2.8)
        pole(point(x1, y0 - 0.08, wall), point(x1, y1 + 0.08, wall), width: 2.8)

        // The near slope's rafters, the end pairs crossed above the ridge.
        for x in xs {
            let foot = point(x, y1 + 0.12, wall - 4), top = point(x, ry, ridge)
            let reach = (x == x0 || x == x1) ? 10.0 : 0
            pole(foot, top + StoneBuildingsSketch.unit(top - foot) * reach, width: 2.4)
        }
        stroke([gable(0.5, ridge - 2.5) + P(-2.6, 0), gable(0.5, ridge - 2.5) + P(2.6, 0)], width: 1.8,
               colour: Ink.darkHide)
        pennant(at: gable(0.5, ridge + 1), height: 26)

        // The materials: sheaves of thatch and stone in the yard, and a
        // ladder against the near wall.
        sheaves(at: point(0.3, 1.2))
        stones(at: point(1.2, 1.0))
        ladder(from: point(0.48, 0.9), to: long(0.84, wall + 2))
    }

    /// Timbers stacked, cut ends toward the viewer's lower left.
    private mutating func timbers(at foot: P) {
        moved(to: foot) { s in
            let away = StoneBuildingsSketch.unit(P(32, -16))
            s.shadow(StoneBuildingsSketch.lump(away * 9 + P(1, 0.5), 17, 5))
            for end in [P(-5.6, -1.4), P(0.4, 1.6), P(-2.6, -6.4)] {
                s.log(end: end, toward: away, length: 20, radius: 3)
            }
        }
    }

    /// A heap of stones gathered for the hearth and the footings.
    private mutating func stones(at foot: P) {
        moved(to: foot) { s in
            s.shadow(StoneBuildingsSketch.lump(P(1.5, 0.5), 13, 4.4))
            let heap: [(P, Double, Double, Int)] = [(P(-6.5, -2), 4, 3, 0), (P(1.5, -2.6), 4.4, 3.2, 2),
                                                    (P(8, -1.6), 3.6, 2.6, 4), (P(-2.6, -6.6), 4, 3, 1),
                                                    (P(4.8, -6.8), 3.6, 2.8, 3), (P(1, -11), 3.6, 2.6, 5),
                                                    (P(-3.4, 1.2), 3.6, 2.4, 6), (P(4.4, 1.4), 3.4, 2.4, 2)]
            for (c, rx, ry, turn) in heap {
                s.shape(StoneBuildingsSketch.lump(c, rx, ry, turn: turn), .colour(Ink.stone), line: 1,
                        shift: StoneBuildingsSketch.nudge)
            }
        }
    }

    /// A ladder of two poles and rungs lashed across them, from `foot` on the
    /// ground to `top` against the frame.
    private mutating func ladder(from foot: P, to top: P) {
        let along = top - foot, across = StoneBuildingsSketch.unit(P(-along.y, along.x)) * 3.4
        for k in stride(from: 0.12, to: 0.95, by: 0.15) {
            let p = foot + along * k
            stroke([p - across, p + across], width: 1.6, colour: Ink.handle)
        }
        pole(foot - across, top - across, width: 2)
        pole(foot + across, top + across, width: 2)
    }
}
