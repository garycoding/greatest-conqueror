// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The boat house of the Stone age seen from behind (ruled 2026-11-22): the
// same shelter as the side view (StoneBuildingsBoatHouse.swift), its plan
// turned a quarter so that the open end, the landing stage and the dock face
// −y, the screen's upper right, running away from the viewer toward the water. The
// long side with the painted front board faces the lower right, in shade; the
// landward end faces the viewer: a gable wall of daub with a low doorway hung
// with a hide, a log for a step, paddles leaning by the door, and a pot and a
// coil of rope set against the wall. The pennant flies from the gable over the
// water. Under construction: the same frame turned, the landward wall's posts
// standing with wattle woven at their foot, and the stage's piles beyond.

/// The plan of the boat house laid as the back view lays it.
private let turn = StoneBoatHouseTurn.back

private func spot(_ x: Double, _ y: Double, _ h: Double = 0) -> P { turn(x, y, h) }

/// The roof's height over the plan's `y`, at the surface of the thatch.
private func roofHeight(_ y: Double) -> Double {
    StoneBoatShed.ridge - (StoneBoatShed.ridge - StoneBoatShed.eave) * abs(y - StoneBoatShed.ridgeY) / StoneBoatShed.eaveReach
}

extension StoneBuildingsSketch {
    mutating func boatHouseBack(complete: Bool) {
        earth(2)
        // Reeds at the corner where the water edge meets the right, and at the left.
        reeds(at: StoneBuildingsSketch.at(0.86, -0.84), turn: 1)
        reeds(at: StoneBuildingsSketch.at(-0.82, 0.86), turn: 0)
        if complete {
            backShed()
            fishRack(at: spot(-0.42, 0.84))
        } else {
            backShedFrame()
        }
    }

    // MARK: The complete boat house, from behind

    private mutating func backShed() {
        let s = StoneBoatShed.self
        let (x0, x1, y0, y1, deck) = (s.x0, s.x1, s.y0, s.y1, s.deck)
        // The roof's shadow on the ground, to the right, and the shade under the deck.
        shadow(StoneBuildingsOutline([spot(x1 + 0.1, y0 - 0.06), spot(x1 + 0.1, y1 + 0.24), spot(x0 - 0.08, y1 + 0.24),
                                      spot(x0 - 0.08, y0 + 0.1)]), opacity: 0.18)
        backStage()
        // The piles behind, in the shade under the deck.
        for (x, y) in [(x1, y0), (x1, -0.06), (-0.2, y0)] { boatHousePile(x, y, top: deck, colour: Ink.handle, turn: turn) }
        // The deck's top: poles laid across it, side by side.
        shape([spot(x0, y0, deck), spot(x1, y0, deck), spot(x1, y1, deck), spot(x0, y1, deck)], .colour(StoneBuildingsInk.woodEnd),
              line: 1)
        for x in stride(from: x0 + 0.1, to: x1, by: 0.1) {
            stroke([spot(x, y0 + 0.02, deck), spot(x, y1 - 0.02, deck)], width: 0.6, colour: Ink.wood)
        }
        // The inside of the shed, dark under the far slope, seen past the open long side.
        let inside = roofHeight(y0) - 3.2
        colour([spot(x0, y0, deck), spot(x1, y0, deck), spot(x1, y0, inside), spot(x1, s.ridgeY, s.ridge - 3),
                spot(x0, s.ridgeY, s.ridge - 3), spot(x0, y0, inside)], .colour(StoneBuildingsInk.hollow), shift: P(0, 0))
        // The far posts, the open end's tie beam, a paddle in the far corner,
        // and the canoe resting on the deck, its bow toward the open end.
        for x in [x1, -0.2, x0 + 0.04] {
            pole(spot(x, y0 + 0.04, deck), spot(x, y0 + 0.04, s.eave + 3), width: 2.4, colour: Ink.handle)
        }
        pole(spot(x1, y0 - 0.08, s.eave), spot(x1, y1 + 0.1, s.eave), width: 2.2, colour: Ink.handle)
        paddleLeaning(at: spot(x1 - 0.06, y0 + 0.1, deck))
        restingCanoe(from: -0.62, to: 0.62, y: -0.08, h: deck + 0.5, turn: turn)
        // The near posts along the open long side, under the eaves.
        for x in [x1, -0.2] { pole(spot(x, y1 - 0.04, deck - 0.5), spot(x, y1 - 0.04, s.eave + 1.5), width: 2.6) }
        backDeckEdges()
        landwardWall()
        backRoof()
        // The piles in front of the deck's faces, the farthest first.
        for (x, y) in [(x1, y1), (x0, y0), (-0.2, y1), (x0, -0.06), (x0, y1)] {
            boatHousePile(x, y, top: deck, colour: Ink.wood, turn: turn)
        }
        landwardStores()
    }

    /// The landing stage, running from the open end of the shed away from the
    /// viewer to the footprint's edge, with the mooring post at its end, and
    /// the dock beyond it, its far end clear of the building.
    private mutating func backStage() {
        stoneDock(complete: true, turn: turn)
        let s = StoneBoatShed.self
        let (sx0, sx1, sy0, sy1, h) = (s.x1 - 0.02, s.stageX1, s.stageY0, s.stageY1, s.stage)
        shadow(StoneBuildingsOutline([spot(sx0, sy0), spot(sx1 + 0.02, sy0), spot(sx1 + 0.02, sy1 + 0.1), spot(sx0, sy1 + 0.1)]),
               opacity: 0.14)
        for (x, y) in [(sx1 - 0.03, sy0 + 0.02), (0.68, sy0 + 0.02)] {
            pole(spot(x, y, -1), spot(x, y, h), width: 2.6, colour: Ink.handle)
        }
        // The stringers, then the poles across them, the farthest first.
        pole(spot(sx0, sy0 + 0.03, h - 1.2), spot(sx1, sy0 + 0.03, h - 1.2), width: 2, colour: Ink.handle)
        pole(spot(sx0, sy1 - 0.03, h - 1.2), spot(sx1, sy1 - 0.03, h - 1.2), width: 2, colour: Ink.handle)
        for x in stride(from: sx0 + 0.03, through: sx1 - 0.02, by: 0.072).reversed() {
            pole(spot(x, sy0 - 0.02, h), spot(x, sy1 + 0.02, h), width: 2.4, colour: Ink.wood, line: 0.8)
        }
        for (x, y) in [(sx1 - 0.03, sy1 - 0.02), (0.68, sy1 - 0.02)] {
            pole(spot(x, y, -1), spot(x, y, h - 1), width: 2.6, colour: Ink.wood)
        }
        mooringPost(at: spot(sx1 - 0.03, sy1 + 0.02))
    }

    /// The deck's two faces toward the viewer: the long one painted in the
    /// team's colour with a zigzag, now toward the lower right and in shade,
    /// and the landward end in the light, the ends of its poles along it.
    private mutating func backDeckEdges() {
        let s = StoneBoatShed.self
        let (x0, x1, y0, y1, h) = (s.x0, s.x1, s.y0, s.y1, s.deck)
        let low = h - 4.4
        let front = [spot(x0, y1, low), spot(x1, y1, low), spot(x1, y1, h), spot(x0, y1, h)]
        colour(front, .team, shift: StoneBuildingsSketch.nudge)
        zigzag(StoneBuildingsSketch.points(from: spot(x0 + 0.04, y1, low + 1.1), to: spot(x1 - 0.04, y1, low + 1.1), count: 14),
               tooth: P(0, -2.2), width: 1, colour: Ink.light)
        colour(front, .colour(Ink.line), shift: P(0, 0), opacity: 0.16)
        stroke(StoneBuildingsOutline(front), width: 1.1)
        shape([spot(x0, y0, low), spot(x0, y1, low), spot(x0, y1, h), spot(x0, y0, h)], .colour(Ink.wood), line: 1.1,
              shift: StoneBuildingsSketch.nudge)
        for y in stride(from: y0 + 0.08, to: y1, by: 0.1) {
            svg.ellipse(spot(x0, y, h - 1.4), 1.3, 1.1, fill: .colour(StoneBuildingsInk.woodEnd), stroke: .colour(Ink.line), width: 0.6)
        }
    }

    /// A point of the landward wall, `y` along the plan and `h` up.
    private static func wall(_ y: Double, _ h: Double) -> P { spot(StoneBoatShed.x0 + 0.02, y, h) }

    /// The landward end, toward the viewer and in the light: a gable wall of
    /// daub on the deck, its corner posts, a band of ochre under the gable, and
    /// a low doorway framed in timber with a hide hung across part of it.
    private mutating func landwardWall() {
        let s = StoneBoatShed.self
        let (y0, y1, deck, ry) = (s.y0, s.y1, s.deck, s.ridgeY)
        let w = StoneBuildingsSketch.wall
        let top0 = roofHeight(y0) - 3.2, top1 = roofHeight(y1) - 3.2, peak = s.ridge - 4
        shape([w(y0, deck), w(y1, deck), w(y1, top1), w(ry, peak), w(y0, top0)], .colour(Ink.light))
        // The daub smoothed over wattle: faint courses, and the ochre band.
        for h in stride(from: deck + 4, to: top0 - 1, by: 4) {
            stroke([w(y0 + 0.05, h), w(y1 - 0.05, h)], width: 0.6, colour: StoneBuildingsInk.daubShade)
        }
        let (bandLow, bandHigh) = (top0 + 1.5, top0 + 5.5)
        let bandFrom = y0 + (ry - y0) * (bandLow - top0) / (peak - top0)
        let bandTo = y1 - (y1 - ry) * (bandLow - top1) / (peak - top1)
        let bandFromHigh = y0 + (ry - y0) * (bandHigh - top0) / (peak - top0)
        let bandToHigh = y1 - (y1 - ry) * (bandHigh - top1) / (peak - top1)
        colour([w(bandFrom, bandLow), w(bandTo, bandLow), w(bandToHigh, bandHigh), w(bandFromHigh, bandHigh)],
               .colour(StoneBuildingsInk.ember), shift: P(0, 0), opacity: 0.85)
        zigzag(StoneBuildingsSketch.points(from: w(bandFrom + 0.04, bandLow + 0.8), to: w(bandTo - 0.04, bandLow + 0.8), count: 12),
               tooth: P(0, -2.4), width: 0.9, colour: Ink.line)
        // The doorway: dark, a hide across part of it, its frame and lintel.
        let (d0, d1, dh) = (-0.2, 0.08, deck + 17)
        shape([w(d0, deck), w(d1, deck), w(d1 - 0.01, dh), w(d0 + 0.01, dh)], .colour(StoneBuildingsInk.hollow), line: 1.1,
              shift: StoneBuildingsSketch.nudge)
        var curtain = StoneBuildingsOutline()
        curtain.move(w(d0 + 0.01, dh))
        curtain.line(w(d0 + 0.15, dh))
        curtain.quad(w(d0 + 0.11, deck + 10), w(d0 + 0.07, deck + 8))
        curtain.quad(w(d0 + 0.1, deck + 3), w(d0 + 0.12, deck + 0.2))
        curtain.line(w(d0 + 0.01, deck + 0.2))
        curtain.close()
        shape(curtain, .colour(Ink.hide), line: 1, shift: StoneBuildingsSketch.nudge)
        stroke([w(d0 + 0.02, deck + 9), w(d0 + 0.075, deck + 8.2)], width: 1.3, colour: Ink.darkHide)
        for (y, h) in [(d0 + 0.04, deck + 14.0), (d0 + 0.09, deck + 5.0), (d0 + 0.11, deck + 15.4)] {
            svg.ellipse(w(y, h), 1.1, 0.8, fill: .colour(Ink.darkHide))
        }
        pole(w(d0 - 0.015, deck - 0.5), w(d0 + 0.005, dh + 1.2), width: 2.4)
        pole(w(d1 + 0.015, deck - 0.5), w(d1 - 0.005, dh + 1.2), width: 2.4)
        pole(w(d0 - 0.04, dh + 0.6), w(d1 + 0.04, dh + 0.6), width: 2.6)
        // The corner posts, and the post under the ridge.
        for y in [y0 + 0.03, y1 - 0.03] { pole(w(y, deck - 0.5), w(y, (y < ry ? top0 : top1) + 1.5), width: 2.6) }
        pole(w(ry, dh + 1.6), w(ry, peak + 1), width: 2.4)
    }

    /// The ridged roof of thatch from behind: the slope toward the lower right
    /// in shade, the landward gable's edge in the light, the courses, the eaves'
    /// ragged ends, the bound roll along the ridge, and the pennant on the
    /// gable over the water.
    private mutating func backRoof() {
        let s = StoneBoatShed.self
        let (rx0, rx1, ry, reach) = (s.roofX0, s.roofX1, s.ridgeY, s.eaveReach)
        let near = ry + reach, far = ry - reach
        let lip = 3.2
        // The thickness of the thatch along the near eaves.
        shape([spot(rx0, near, s.eave), spot(rx1, near, s.eave), spot(rx1, near, s.eave - lip), spot(rx0, near, s.eave - lip)],
              .colour(StoneBuildingsInk.thatchDeep), line: 1.1)
        // The near slope, in shade, and its courses.
        let slope = [spot(rx0, near, s.eave), spot(rx1, near, s.eave), spot(rx1, ry, s.ridge), spot(rx0, ry, s.ridge)]
        shape(slope, .colour(Ink.hide))
        colour(slope, .colour(StoneBuildingsInk.thatchShade), shift: P(0, 0), opacity: 0.4)
        // It darkens a little more toward the far end, away from the light.
        colour([spot(rx1 - 0.3, near, s.eave), spot(rx1, near, s.eave), spot(rx1, ry, s.ridge), spot(rx1 - 0.3, ry, s.ridge)],
               .colour(StoneBuildingsInk.thatchShade), shift: P(0, 0), opacity: 0.4)
        for f in [0.22, 0.44, 0.66, 0.86] {
            let y = ry + reach * f, h = s.ridge - (s.ridge - s.eave) * f
            let row = StoneBuildingsSketch.points(from: spot(rx0 + 0.04, y, h), to: spot(rx1 - 0.04, y, h), count: 13)
            scallops(row, width: 0.9, opacity: 0.85) { _ in P(0.25, 1.1) }
        }
        stroke(StoneBuildingsOutline(slope), width: 1.2)
        // The straw ends along the eaves.
        let edge = StoneBuildingsSketch.points(from: spot(rx0, near, s.eave - lip), to: spot(rx1, near, s.eave - lip), count: 15)
        scallops(edge, width: 1) { _ in P(0, 0.9) }
        // The roll of thatch bound along the ridge.
        let roll = [spot(rx0 - 0.03, ry, s.ridge + 2.2), spot(rx1 + 0.03, ry, s.ridge + 2.2), spot(rx1 + 0.03, ry, s.ridge - 1.4),
                    spot(rx0 - 0.03, ry, s.ridge - 1.4)]
        shape(roll, .colour(StoneBuildingsInk.thatchShade), line: 1.1, shift: StoneBuildingsSketch.nudge)
        for x in stride(from: rx0 + 0.12, to: rx1, by: 0.26) {
            stroke([spot(x, ry, s.ridge + 2.2), spot(x, ry, s.ridge - 1.4)], width: 1.5, colour: Ink.darkHide)
        }
        // The landward gable's edge: the cut thatch, lit, over the wall.
        let barge = [spot(rx0, near, s.eave), spot(rx0, ry, s.ridge), spot(rx0, far, s.eave)]
        shape(barge + [spot(rx0, far, s.eave - lip), spot(rx0 - 0.03, ry, s.ridge - lip), spot(rx0, near, s.eave - lip)],
              .colour(StoneBuildingsInk.straw), line: 1.1)
        for v in [0.25, 0.5, 0.75] {
            for (a, b) in [(near, ry), (far, ry)] {
                let y = a + (b - a) * v, h = s.eave + (s.ridge - s.eave) * v
                stroke([spot(rx0, y, h - 0.4), spot(rx0, y, h - lip + 0.4)], width: 0.7, colour: StoneBuildingsInk.thatchShade)
            }
        }
        // Crossed poles over the gable's peak at the water end, the pennant tied to them.
        let peak = spot(rx1, ry, s.ridge)
        pole(peak + P(-1, 2), peak + P(-6, -9), width: 2, colour: Ink.wood)
        pole(peak + P(1, 2), peak + P(6, -9), width: 2, colour: Ink.wood)
        pennant(at: peak + P(0, 1), height: 26)
    }

    /// What stands at the landward door: a log for a step, two paddles leaning
    /// on the wall, a pot, and a coil of rope.
    private mutating func landwardStores() {
        let s = StoneBoatShed.self
        let ground = { (y: Double) in spot(s.x0 - 0.1, y) }
        log(end: ground(0.1) + P(0, -3), toward: StoneBuildingsSketch.unit(spot(0, -1) - spot(0, 0)), length: 9, radius: 3)
        paddleLeaning(at: ground(0.26))
        paddleLeaning(at: ground(0.34) + P(1.5, 0.5))
        boatHousePot(at: ground(-0.36))
        ropeCoil(at: ground(-0.5) + P(-1, -1))
    }

    /// A clay pot with a zigzag round its shoulder, a lid of bark on it.
    private mutating func boatHousePot(at foot: P) {
        moved(to: foot) { s in
            s.shadow(StoneBuildingsSketch.lump(P(1.5, 0.2), 5.5, 2))
            var body = StoneBuildingsOutline()
            body.move(P(-2.4, 0))
            body.quad(P(-6, -3.2), P(-4.2, -7))
            body.quad(P(-3, -8.6), P(-2.4, -9.6))
            body.line(P(2.4, -9.6))
            body.quad(P(3, -8.6), P(4.2, -7))
            body.quad(P(6, -3.2), P(2.4, 0))
            body.close()
            s.shape(body, .colour(Ink.hide), line: 1.1, shift: StoneBuildingsSketch.nudge)
            s.svg.ellipse(P(0, -9.8), 3, 1.1, fill: .colour(Ink.handle), stroke: .colour(Ink.line), width: 0.8)
            s.zigzag(StoneBuildingsSketch.points(from: P(-4.2, -6), to: P(4.2, -6), count: 6), tooth: P(0, 1.5), width: 0.8)
        }
    }

    /// A coil of rope of twisted grass, lying on the ground.
    private mutating func ropeCoil(at foot: P) {
        moved(to: foot) { s in
            s.shadow(StoneBuildingsSketch.lump(P(0.5, 0.6), 6, 2))
            for k in 0..<3 {
                let r = 4.8 - Double(k) * 1.3
                s.svg.ellipse(P(0, -Double(k) * 1.2), r, r * 0.45, fill: .colour(StoneBuildingsInk.straw), stroke: .colour(Ink.line),
                              width: 0.8)
            }
            s.svg.ellipse(P(0, -2.6), 1.4, 0.6, fill: .colour(StoneBuildingsInk.hollow))
            s.stroke([P(3.6, -0.4), P(6.4, 0.8), P(8.6, 0.2)], width: 1.1, colour: StoneBuildingsInk.straw)
        }
    }

    // MARK: Under construction, from behind

    /// The boat house being built, from behind: the stage's piles beyond it,
    /// the piles and the landward half of the deck, the rafters tied to the
    /// ridge pole, the landward wall's posts with wattle woven at their foot,
    /// sheaves of thatch, and a log being hollowed.
    private mutating func backShedFrame() {
        let s = StoneBoatShed.self
        let (x0, x1, y0, y1, deck) = (s.x0, s.x1, s.y0, s.y1, s.deck)
        let (rx0, rx1, ry, reach) = (s.roofX0 + 0.04, s.roofX1 - 0.04, s.ridgeY, s.eaveReach - 0.08)
        shadow(StoneBuildingsOutline([spot(x1 + 0.08, y0), spot(x1 + 0.08, y1 + 0.16), spot(x0, y1 + 0.16), spot(x0, y0 + 0.1)]),
               opacity: 0.12)
        // The dock begun, and the stage's piles, set, with no deck on them yet, the farthest first.
        stoneDock(complete: false, turn: turn)
        for (x, y) in [(s.stageX1 - 0.03, s.stageY0 + 0.02), (0.68, s.stageY0 + 0.02), (s.stageX1 - 0.03, s.stageY1 - 0.02),
                       (0.68, s.stageY1 - 0.02)] {
            pole(spot(x, y, -1), spot(x, y, s.stage), width: 2.6, colour: Ink.wood)
        }
        for (x, y) in [(x1, y0), (-0.2, y0)] { boatHousePile(x, y, top: deck, colour: Ink.handle, turn: turn) }
        // The bearers, the farthest first, and the deck's poles laid over the landward half.
        for x in [x1, -0.2, x0] { pole(spot(x, y0, deck - 1), spot(x, y1, deck - 1), width: 2.4, colour: Ink.handle) }
        shape([spot(x0, y0, deck), spot(-0.14, y0, deck), spot(-0.14, y1, deck), spot(x0, y1, deck)], .colour(StoneBuildingsInk.woodEnd),
              line: 1)
        for x in stride(from: x0 + 0.1, to: -0.14, by: 0.1) {
            stroke([spot(x, y0 + 0.02, deck), spot(x, y1 - 0.02, deck)], width: 0.6, colour: Ink.wood)
        }
        // The rafters in pairs, crossed over the ridge pole, the far ones first.
        let pairs = stride(from: rx0, through: rx1 + 0.001, by: (rx1 - rx0) / 3).map { $0 }.reversed()
        for x in pairs { pole(spot(x, ry - reach, deck), spot(x, ry, s.ridge + 3), width: 2.2, colour: Ink.handle) }
        pole(spot(rx0 - 0.05, ry, s.ridge), spot(rx1 + 0.05, ry, s.ridge), width: 2.6)
        pennant(at: spot(rx1, ry, s.ridge + 3), height: 22)
        for x in pairs {
            pole(spot(x, ry + reach, deck), spot(x, ry, s.ridge + 3), width: 2.2)
            stroke([spot(x, ry, s.ridge) + P(-2, 1), spot(x, ry, s.ridge) + P(2, -1)], width: 1.6, colour: Ink.darkHide)
        }
        // The front board, already painted, in shade.
        let low = deck - 4.4
        let front = [spot(x0, y1, low), spot(x1, y1, low), spot(x1, y1, deck), spot(x0, y1, deck)]
        colour(front, .team, shift: StoneBuildingsSketch.nudge)
        colour(front, .colour(Ink.line), shift: P(0, 0), opacity: 0.16)
        stroke(StoneBuildingsOutline(front), width: 1.1)
        // The landward wall begun: wattle woven at the foot either side of the
        // door's gap, the door's posts, and the corner posts.
        let w = StoneBuildingsSketch.wall
        for (from, to, high) in [(y0 + 0.04, -0.21, deck + 11.0), (0.09, y1 - 0.04, deck + 7.0)] {
            shape([w(from, deck), w(to, deck), w(to, high), w(from, high - 1.5)], .colour(Ink.wood), line: 1.1)
            for h in stride(from: deck + 3, through: high - 2, by: 3) {
                zigzag(StoneBuildingsSketch.points(from: w(from + 0.01, h), to: w(to - 0.01, h), count: 6),
                       tooth: P(0, -1.2), width: 0.8, colour: Ink.handle)
            }
        }
        for y in [-0.215, 0.095] { pole(w(y, deck - 0.5), w(y, deck + 18), width: 2.4) }
        for y in [y0 + 0.03, y1 - 0.03] { pole(w(y, deck - 0.5), w(y, roofHeight(y) - 2), width: 2.6) }
        for (x, y) in [(x1, y1), (x0, y0), (-0.2, y1), (x0, y1)] { boatHousePile(x, y, top: deck, colour: Ink.wood, turn: turn) }
        // The log on the ground beside the long side, clear of the stage's piles.
        logBeingHollowed(at: spot(0.02, 0.74))
        sheaves(at: spot(-0.62, 0.84))
    }
}
