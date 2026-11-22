// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The house of the Stone age: a round hut of wattle and daub, with a band
// painted in the team's colour, under a tall cone of thatch tied at its top,
// where the team's pennant flies. A hide stretched to dry stands at one side
// and a stack of firewood at the other. Under construction: a ring of stakes,
// part of the wattle woven between them, the rafters of the cone tied at the
// top with the pennant on them, and thatch and stakes piled beside.

/// The hut's measurements, about the centre of its footprint (2 by 2): radii
/// in tiles, heights in points.
private enum Hut {
    static let wall = 0.7, wallHeight = 27.0
    static let eave = 0.83, eaveHeight = 23.5
    static let apex = 66.0

    /// A circle of `radius` tiles about the footprint's centre, `height` points
    /// up, as the projection draws it: its centre and its two radii.
    static func ring(_ radius: Double, _ height: Double) -> (c: P, rx: Double, ry: Double) {
        (P(0, -height), radius * Projection.tileWidth / 2 * 2.squareRoot(), radius * Projection.tileHeight / 2 * 2.squareRoot())
    }

    /// Points along that circle from `from` to `to` degrees (90 is nearest the viewer).
    static func arc(_ radius: Double, _ height: Double, from: Double, to: Double) -> [P] {
        let r = ring(radius, height)
        return StoneBuildingsSketch.arc(r.c, r.rx, r.ry, from: from, to: to)
    }

    /// The point of that circle at `degrees`.
    static func on(_ radius: Double, _ height: Double, _ degrees: Double) -> P {
        arc(radius, height, from: degrees, to: degrees)[0]
    }

    /// Where the cone's sides meet the eaves, in degrees: the eaves are seen
    /// from `-tangent` round the front to `180 + tangent`.
    static let tangent: Double = {
        let r = ring(eave, eaveHeight)
        return asin(-r.ry / (apex - eaveHeight)) * 180 / .pi
    }()
}

extension StoneBuildingsSketch {
    mutating func house(complete: Bool) {
        earth(2)
        if complete {
            hut()
        } else {
            hutFrame()
        }
    }

    private mutating func hut() {
        func at(_ x: Double, _ y: Double) -> P { StoneBuildingsSketch.at(x, y) }
        // The roof's shadow on the ground, to the right of the wall.
        let shade = Hut.ring(Hut.eave + 0.04, 0)
        shadow(StoneBuildingsSketch.lump(shade.c + P(5, 1.5), shade.rx, shade.ry))

        hideFrame(at: at(-0.8, 0.86))
        woodpile(at: at(0.74, -0.62))

        // The wall: daub, its right side in shade.
        let w = Hut.wallHeight
        shape(Hut.arc(Hut.wall, 0, from: 0, to: 180) + Hut.arc(Hut.wall, w, from: 180, to: 360), .colour(Ink.light))
        colour(Hut.arc(Hut.wall, 0, from: -2, to: 44) + Hut.arc(Hut.wall, w, from: 44, to: -2),
               .colour(StoneBuildingsInk.daubShade))
        // The painted band, and a zigzag on it in the light colour.
        let (low, high) = (7.5, 12.5)
        colour(Hut.arc(Hut.wall, low, from: 0, to: 180) + Hut.arc(Hut.wall, high, from: 180, to: 0), .team,
               shift: P(0, 0))
        stroke(Hut.arc(Hut.wall, low, from: 0, to: 180), width: 0.9)
        stroke(Hut.arc(Hut.wall, high, from: 0, to: 180), width: 0.9)
        zigzag(stride(from: 4.0, through: 176, by: 8).map { Hut.on(Hut.wall, low + 1.2, $0) }, tooth: P(0, -2.6),
               width: 1.1, colour: Ink.light)
        // The outline again over the band, where it meets the wall's sides.
        stroke(Hut.arc(Hut.wall, 0, from: 0, to: 180), width: 1.2)

        // The door, a little to the left of the front, framed in timber.
        let (left, right, tall) = (124.0, 94.0, 15.0)
        shape(Hut.arc(Hut.wall, 0, from: right, to: left) + Hut.arc(Hut.wall, tall - 1, from: left, to: (left + right) / 2)
                + [Hut.on(Hut.wall, tall + 1, (left + right) / 2)]
                + Hut.arc(Hut.wall, tall - 1, from: (left + right) / 2, to: right),
              .colour(StoneBuildingsInk.hollow), line: 1.1, shift: StoneBuildingsSketch.nudge)
        pole(Hut.on(Hut.wall, -0.5, left + 1.5), Hut.on(Hut.wall, tall + 1.5, left + 1.5), width: 2.4)
        pole(Hut.on(Hut.wall, -0.5, right - 1.5), Hut.on(Hut.wall, tall + 1.5, right - 1.5), width: 2.4)

        cone()
        pot(at: at(0.82, 0.34))
    }

    /// The cone of thatch: its shaded side, its courses, the ragged edge of its
    /// eaves, and the tuft at its top with the pennant.
    private mutating func cone() {
        let apex = P(0, -Hut.apex)
        let t = Hut.tangent
        let eaves = Hut.arc(Hut.eave, Hut.eaveHeight, from: 180 - t, to: t)
        // The thickness of the thatch under the eaves, its straw ends ragged.
        let lip = 3.4
        shape(eaves + eaves.reversed().map { $0 + P(0, lip) }, .colour(StoneBuildingsInk.thatchDeep), line: 1.1)
        // The cone, and its side in shade.
        shape([apex] + eaves, .colour(Ink.hide))
        colour([apex] + Hut.arc(Hut.eave, Hut.eaveHeight, from: 38, to: t), .colour(StoneBuildingsInk.thatchShade))
        stroke([apex] + eaves + [apex], width: 1.2)
        // The courses of thatch: rows of scallops round the cone.
        for f in [0.3, 0.53, 0.76] {
            let row = Hut.arc(Hut.eave * f, Hut.apex - (Hut.apex - Hut.eaveHeight) * f, from: 180 - t + 4, to: t - 4)
            let every = stride(from: 0, to: row.count, by: 2).map { row[$0] } + [row[row.count - 1]]
            scallops(every, width: 0.9, opacity: 0.85) { StoneBuildingsSketch.unit($0 - apex) * 1.3 }
        }
        // The straw ends along the eaves' edge.
        let edge = stride(from: 0, to: eaves.count, by: 2).map { eaves[$0] + P(0, lip) } + [eaves[eaves.count - 1] + P(0, lip)]
        scallops(edge, width: 1) { _ in P(0, 0.9) }
        // The tuft of thatch at the top, bound, and the pennant above it.
        pennant(at: apex + P(0, 2), height: 30)
        var tuft = StoneBuildingsOutline()
        tuft.move(apex + P(-2.6, 2.5))
        tuft.quad(apex + P(-3, -3), apex + P(-5.4, -7))
        tuft.quad(apex + P(0, -9.6), apex + P(5.4, -7))
        tuft.quad(apex + P(3, -3), apex + P(2.6, 2.5))
        tuft.close()
        shape(tuft, .colour(StoneBuildingsInk.thatchShade), line: 1.1, shift: StoneBuildingsSketch.nudge)
        stroke([apex + P(-2.8, -1), apex + P(2.8, -1)], width: 1.7, colour: Ink.darkHide)
    }

    /// The hut being built: a ring of stakes with wattle woven round part of it,
    /// a ring beam on them, and the rafters of the cone tied at the top.
    private mutating func hutFrame() {
        func at(_ x: Double, _ y: Double) -> P { StoneBuildingsSketch.at(x, y) }
        let w = Hut.wallHeight, apex = P(0, -Hut.apex + 6)
        let stakes = stride(from: 8.0, to: 368, by: 360.0 / 14)
        func stake(_ degrees: Double) {
            pole(Hut.on(Hut.wall, -0.5, degrees), Hut.on(Hut.wall, w + 2, degrees), width: 2.6)
        }
        // The far side first: its stakes, the wattle woven round them (seen
        // from inside), the ring beam, and the rafters behind the apex.
        for d in stakes where sin(d * .pi / 180) < 0 { stake(d) }
        let woven = 14.0
        shape(Hut.arc(Hut.wall, 0, from: 180, to: 360) + Hut.arc(Hut.wall, woven, from: 360, to: 180),
              .colour(Ink.wood), line: 1.1)
        for h in stride(from: 3.5, through: woven - 2, by: 3.5) {
            stroke(Hut.arc(Hut.wall, h, from: 184, to: 356), width: 0.8, colour: Ink.handle)
        }
        stroke(Hut.arc(Hut.wall, w, from: 180, to: 360), width: 2.4, colour: Ink.wood)
        stroke(Hut.arc(Hut.wall, w, from: 180, to: 360), width: 0.8)
        let rafters = stride(from: 22.5, to: 382, by: 45.0)
        for d in rafters where sin(d * .pi / 180) < 0 {
            pole(Hut.on(Hut.wall + 0.06, w - 2, d), apex + StoneBuildingsSketch.unit(apex - Hut.on(Hut.wall, w, d)) * 7, width: 2.2)
        }
        // The near side: the stakes, wattle begun at the left, the ring beam
        // and the rafters in front.
        for d in stakes where sin(d * .pi / 180) >= 0 { stake(d) }
        shape(Hut.arc(Hut.wall, 0, from: 118, to: 182) + Hut.arc(Hut.wall, 9, from: 182, to: 118), .colour(Ink.wood),
              line: 1.1)
        for h in [3.0, 6.0] { stroke(Hut.arc(Hut.wall, h, from: 121, to: 179), width: 0.8, colour: Ink.handle) }
        stroke(Hut.arc(Hut.wall, w, from: 0, to: 180), width: 2.4, colour: Ink.wood)
        stroke(Hut.arc(Hut.wall, w, from: 0, to: 180), width: 0.8)
        for d in rafters where sin(d * .pi / 180) >= 0 {
            pole(Hut.on(Hut.wall + 0.06, w - 2, d), apex + StoneBuildingsSketch.unit(apex - Hut.on(Hut.wall, w, d)) * 7, width: 2.2)
        }
        // The binding at the top, where the pennant is tied.
        stroke([apex + P(-3.4, 1.5), apex + P(3.4, 1.5)], width: 1.8, colour: Ink.darkHide)
        pennant(at: apex + P(0, 2), height: 28)

        // The materials: sheaves of thatch, and stakes ready for the wall.
        sheaves(at: at(-0.72, 0.62))
        stakePile(at: at(0.66, -0.64))
    }

    // MARK: About the house

    /// A hide stretched on a frame of poles to dry, laced to it at the corners.
    private mutating func hideFrame(at foot: P) {
        moved(to: foot) { s in
            let along = P(14, 7), up = P(0, -21)
            s.shadow(StoneBuildingsSketch.lump(along * 0.5 + P(2, 1), 11, 3.4))
            let corners = [P(0, 0) + up * 0.12, along + up * 0.12, along + up, up]
            // The poles: two uprights, and bars across the top and near the foot.
            s.pole(P(0, 1), up + P(0, -2.5), width: 2.2)
            s.pole(along + P(0, 1), along + up + P(0, -2.5), width: 2.2)
            s.pole(corners[3] + P(-1.5, -0.75), corners[2] + P(1.5, 0.75), width: 2)
            s.pole(corners[0] + P(-1.5, -0.75), corners[1] + P(1.5, 0.75), width: 2)
            // The hide, and its lacing.
            var hide = StoneBuildingsOutline()
            let inset = [P(2.4, -4.6), P(7, -2.4), P(11.8, -0.4), P(11.4, -9), P(12, -16.8), P(7.4, -18.4),
                         P(2.6, -20.4), P(3.2, -12.6)]
            hide.move(inset[0])
            for i in 1...inset.count {
                let p = inset[i % inset.count], q = inset[(i + inset.count - 1) % inset.count]
                hide.quad((p + q) * 0.5 + StoneBuildingsSketch.unit(P(p.y - q.y, q.x - p.x)) * -1.3, p)
            }
            hide.close()
            s.shape(hide, .colour(Ink.hide), line: 1, shift: StoneBuildingsSketch.nudge)
            for spot in [P(5.6, -9.4), P(8.8, -5.6), P(8, -13.6)] {
                s.svg.ellipse(spot, 1.3, 0.9, fill: .colour(Ink.darkHide))
            }
            for (a, b) in [(P(2.4, -4.6), P(0, -3.6)), (P(11.8, -0.4), along + up * 0.12),
                           (P(12, -16.8), along + up + P(0, 2)), (P(2.6, -20.4), up + P(0, 1.2))] {
                s.stroke([a, b], width: 0.8)
            }
        }
    }

    /// A clay pot with a zigzag round its shoulder.
    private mutating func pot(at foot: P) {
        moved(to: foot) { s in
            s.shadow(StoneBuildingsSketch.lump(P(1.5, 0.2), 6, 2.2))
            var body = StoneBuildingsOutline()
            body.move(P(-2.6, 0))
            body.quad(P(-6.6, -3.4), P(-4.6, -7.6))
            body.quad(P(-3.2, -9.4), P(-2.6, -10.6))
            body.line(P(2.6, -10.6))
            body.quad(P(3.2, -9.4), P(4.6, -7.6))
            body.quad(P(6.6, -3.4), P(2.6, 0))
            body.close()
            s.shape(body, .colour(Ink.hide), line: 1.1, shift: StoneBuildingsSketch.nudge)
            s.svg.ellipse(P(0, -10.6), 2.6, 0.9, fill: .colour(StoneBuildingsInk.hollow))
            s.zigzag(StoneBuildingsSketch.points(from: P(-4.6, -6.6), to: P(4.6, -6.6), count: 6), tooth: P(0, 1.6),
                     width: 0.8)
        }
    }

    /// Firewood stacked in two rows, the cut ends toward the viewer.
    mutating func woodpile(at foot: P) {
        moved(to: foot) { s in
            // Along the logs, away from the viewer; their cut ends face the lower left.
            let away = StoneBuildingsSketch.unit(P(32, -16))
            s.shadow(StoneBuildingsSketch.lump(away * 5 + P(1, 0.5), 14, 4.6))
            for (end, r) in [(P(-8.6, -2.4), 2.8), (P(-3, -2.4), 2.8), (P(2.6, -2.4), 2.8), (P(-5.8, -7.4), 2.8),
                             (P(-0.2, -7.4), 2.8), (P(-3, -12.4), 2.7)] {
                s.log(end: end, toward: away, length: 12, radius: r)
            }
        }
    }

    /// A log lying with its cut end at `end`, its length running `length`
    /// points along `toward` (a unit vector on the screen).
    mutating func log(end c: P, toward dir: P, length: Double, radius r: Double) {
        let n = P(-dir.y, dir.x) * r, far = c + dir * length
        var body = StoneBuildingsOutline()
        body.move(c + n)
        body.line(far + n)
        body.quad(far + dir * (r * 1.4), far - n)
        body.line(c - n)
        body.close()
        shape(body, .colour(Ink.wood), line: 1, shift: StoneBuildingsSketch.nudge)
        svg.ellipse(c + StoneBuildingsSketch.nudge, r * 0.9, r, fill: .colour(StoneBuildingsInk.woodEnd))
        svg.ellipse(c, r * 0.9, r, fill: .none, stroke: .colour(Ink.line), width: 1)
        svg.ellipse(c, r * 0.36, r * 0.4, fill: .none, stroke: .colour(Ink.line), width: 0.7)
    }

    /// Sheaves of thatching straw, bound, lying in a heap.
    mutating func sheaves(at foot: P) {
        moved(to: foot) { s in
            s.shadow(StoneBuildingsSketch.lump(P(2, 0.5), 15, 4.4))
            let along = StoneBuildingsSketch.unit(P(32, 16))
            for (c, turn) in [(P(-8, -3), 0), (P(1, -2), 1), (P(-4, -8), 2)] {
                s.sheaf(at: c, along: along, length: 16, thick: 3.4, turn: turn)
            }
        }
    }

    /// One sheaf of straw lying along `along`, bound in two places.
    mutating func sheaf(at c: P, along: P, length: Double, thick: Double, turn: Int) {
        let n = P(-along.y, along.x) * thick
        let a = c - along * (length / 2), b = c + along * (length / 2)
        var body = StoneBuildingsOutline()
        body.move(a + n * 0.8)
        body.quad(c + n * 1.15, b + n)
        body.quad(b + along * 1.6, b - n)
        body.quad(c - n * 1.15, a - n * 0.8)
        body.quad(a - along * 1.2, a + n * 0.8)
        body.close()
        shape(body, .colour(StoneBuildingsInk.straw), line: 1, shift: StoneBuildingsSketch.nudge)
        // The straw: fine lines along the sheaf, and its cut ends fanned at the far end.
        for k in [-0.6, -0.2, 0.2, 0.6] {
            stroke([a + along * 1.5 + n * (k * 0.8), b - along * (turn == 1 ? 1.5 : 1) + n * k], width: 0.55,
                   colour: StoneBuildingsInk.thatchShade)
        }
        // The bindings.
        for f in [0.3, 0.7] {
            let p = a + (b - a) * f
            stroke([p + n * 1.05, p - n * 1.05], width: 1.4, colour: Ink.darkHide)
        }
    }

    /// Stakes cut for the wall, piled crosswise.
    private mutating func stakePile(at foot: P) {
        moved(to: foot) { s in
            s.shadow(StoneBuildingsSketch.lump(P(1, 0.5), 14, 4))
            let along = StoneBuildingsSketch.unit(P(32, -16)), across = StoneBuildingsSketch.unit(P(32, 16))
            for (c, d, k) in [(P(-6, -1), along, 0.0), (P(-3, 0.8), along, 1.0), (P(0, -1.6), across, 0.0),
                              (P(-4, -3.6), across, 1.0), (P(-2, -5.4), along, 0.0)] {
                let length = 18.0 - k * 2
                s.pole(c - d * (length / 2), c + d * (length / 2), width: 2.2)
            }
        }
    }
}
