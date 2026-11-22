// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Industrial-age boat house (ruled 2026-11-21, plan D7): a boathouse of
// red brick with a slipway. A long shed of brick on a plinth of stone stands
// on a yard of granite setts, its ridge along x under a roof of slate with a
// chimney stack for the boiler of its steam winch. Its gable end faces the
// screen's lower right, opening in a tall arched doorway; out of it runs the
// slipway, a channel of timber sleepers between stone copings with two iron
// rails, down to the footprint's edge, and on the rails a trawler's bow rests
// on its cradle, half hauled out, its chain running back to the winch. A band
// of the owner's colour runs under the eaves of the long wall, edged in the
// light colour, and the owner's pennant flies from the gable's apex; a
// lifebuoy hangs beside the door, and a gas lamp, a bollard, fish boxes and
// barrels stand on the quay. The footprint lies on land and the water may
// lie beside any of its edges, so the slipway reads as the way down to it.
// Under construction: the setts laid, the slipway's sleepers and rails down,
// the walls raised part way in fresh brick with the doorway's arch on its
// centring, scaffolding with the owner's pennant, and bricks, slates and
// timbers to hand. Its footprint is two tiles square: x and y run from -1 to 1.
//
// The boat house faces its water on whichever edge of its footprint touches it
// (ruled 2026-11-22, `FootprintEdge.boatHouseView`). The picture above is the
// side view, its water side toward +x; the back view is the same building
// turned a quarter round, its water side toward -y (the screen's upper right,
// away from the viewer), the shed set back a little toward the landward edge.
// There the slipway, the trawler's bow, the quay's lamp and the pennant on the
// water gable show beyond the shed's far corner, and the viewer sees the
// landward gable, with the winch-house's door and a window over it, and the
// same long wall as before, now on the right, its owner's band under the
// eaves. The drawing mirrors the two views for the other edges.
//
// A short dock runs from the middle of the water edge out over the water,
// beyond the footprint (ruled 2026-11-22, scenery only): a timber pier on
// cast-iron piles, a ring on the water at the foot of each, its deck at the
// yard's height, with bollards and a gas lamp at its end. Under construction
// the piles stand with the decking laid part way out.

/// Which way the boat house stands on its footprint: in the side view its
/// water side faces +x, the screen's lower right; in the back view it is
/// turned a quarter round, its water side facing -y, the screen's upper right.
enum IndustrialBoatHouseTurn {
    case side, back

    /// Where a place given about the side view's footprint lies in this turn:
    /// the back view carries +x to -y and +y to +x.
    func place(_ x: Double, _ y: Double) -> (x: Double, y: Double) {
        switch self {
        case .side: (x, y)
        case .back: (y, -x)
        }
    }

    /// The level rectangle that one given about the side view's footprint covers in this turn.
    func rect(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> (x0: Double, y0: Double, x1: Double, y1: Double) {
        switch self {
        case .side: (x0, y0, x1, y1)
        case .back: (y0, -x1, y1, -x0)
        }
    }
}

/// The boat house's measurements, about the centre of its footprint: distances
/// in tiles along the map's axes, heights in points.
private enum Slip {
    /// The shed: its extent, the yard's height, its eaves and its ridge.
    static let x0 = -0.84, x1 = 0.3, y0 = -0.76, y1 = 0.14
    static let yard = 2.0, eave = 28.0, ridge = 50.0
    /// The middle of the gable end, on which the doorway and the slipway are centred.
    static let ym = (y0 + y1) / 2
    /// The slipway: its half width, and the height it falls to at the footprint's edge.
    static let half = 0.2, foot = 0.4
    /// The rails, either side of the slipway's middle.
    static let gauge = 0.1
    /// Where the trawler's stem stands, along x.
    static let stem = 0.86
    /// The dock beyond the water edge: from the footprint's edge out to
    /// `dockEnd` along x, from `dock0` to `dock1` across, beside the slipway;
    /// its deck from `deck0` up to the yard's height.
    static let dockEnd = 2.08, dock0 = 0.0, dock1 = 0.4, deck0 = 0.9
}

/// The shed in the back view: the side view's shed turned a quarter round, its
/// ridge along y, its water gable at `y0` and its landward gable at `y1`, set
/// back toward the landward edge by `setBack`, so that more of the slipway and
/// the trawler's bow show beyond its far corner. The slipway and the bow keep
/// their places; the slipway's head runs on under the shed.
private enum Behind {
    static let setBack = 0.12
    static let x0 = Slip.y0, x1 = Slip.y1, y0 = -Slip.x1 + setBack, y1 = -Slip.x0 + setBack
    /// The middle of the shed across, under the ridge.
    static let xm = Slip.ym
}

extension IndustrialOldBuildingsPainter {
    /// The boat house, complete or under construction, turned so that its water side faces +x (`side`) or -y (`back`).
    mutating func boatHouse(complete: Bool, turn: IndustrialBoatHouseTurn) {
        // The dock lies beyond the footprint's far edge in the back view, so it is drawn before the yard there, and after it in the side view.
        if turn == .back { dock(complete: complete, turn: turn) }
        cobbles(1, height: Slip.yard)
        if turn == .side { dock(complete: complete, turn: turn) }
        switch (complete, turn) {
        case (true, .side): boatShed()
        case (false, .side): boatShedRising()
        case (true, .back): boatShedFromBehind()
        case (false, .back): boatShedRisingFromBehind()
        }
    }

    /// The screen point of a place given about the side view's footprint, turned by `turn`.
    private func at(_ turn: IndustrialBoatHouseTurn, _ x: Double, _ y: Double, _ h: Double = 0) -> P {
        let p = turn.place(x, y)
        return iso(p.x, p.y, h)
    }

    // MARK: The complete boat house

    private mutating func boatShed() {
        typealias I = IndustrialOldBuildingsInk
        let (x0, y0, x1, y1, h0, e) = (Slip.x0, Slip.y0, Slip.x1, Slip.y1, Slip.yard, Slip.eave)
        let long = (x1 - x0) * 32, end = (y1 - y0) * 32
        // Fish boxes stacked behind the slipway, and the shed's shadow across the yard to the right.
        fishBoxes(0.56, -0.92, on: h0)
        shadow([iso(x1, y0, h0), iso(x1 + 0.34, y0 + 0.14, h0), iso(x1 + 0.34, y1 + 0.1, h0), iso(x1, y1, h0)])
        slipway(rails: true, turn: .side)
        block(x0, y0, x1, y1, h0, e, top: nil, left: .colour(I.brick), right: .colour(I.brickShade))
        // The long wall: plinth, brick, pilasters between tall arched windows, and the owner's band under the eaves.
        wall(.left, from: x0, y1, at: h0) { p in
            p.shape(p.panel(0, 0, long, 2.6), .colour(I.footing), width: 0.6)
            p.brickwork(0, long, 2.6, e - h0)
            for u in [0.0, long / 3, long * 2 / 3, long] {
                p.pilaster(min(max(u, 1.5), long - 1.5), 2.6, 12.4, w: 3)
            }
            for k in 0..<3 {
                p.archedWindow(long * (Double(k) + 0.5) / 3, 3.6, w: 5.2, h: 7.4)
            }
            // The string course and the owner's band over the windows, below the eaves' shadow.
            p.stringCourse(0, long, 12.4, 13.3)
            p.paintedBand(0, long, 14.3, 16.5)
            p.drainpipe(long - 1.2, from: e - h0 - 1)
        }
        // The gable end: the tall doorway open on the slipway, quoins, and the lifebuoy beside it.
        wall(.right, from: x1, y1, at: h0) { p in
            p.shape(p.panel(0, 0, end, 2.6), .colour(I.footingShade), width: 0.6)
            p.brickwork(0, end, 2.6, e - h0)
            p.quoins(at: 0, atStart: true, from: 2.6, to: e - h0, course: 3.2, reach: 3.4)
            p.quoins(at: end, atStart: false, from: 2.6, to: e - h0, course: 3.2, reach: 3.4)
            let door = (Slip.y1 - Slip.ym) * 32
            p.archedDoors(door, 0, w: 15, h: 19.4, open: true)
            p.lifebuoy(at: p.uv(door + 11.4, 11), radius: 2.6)
        }
        // Inside the doorway: the rails running on into the dark, the winch's chain, and the hull.
        doorwayGloom()
        trawlerBow(turn: .side)
        // The roof, its gable over the doorway, an oculus in the gable's brick.
        gableAlongX(x0, y0, x1, y1, eave: e, ridge: Slip.ridge, over: 0.06, gableWall: .colour(I.brickShade)) { p, w, rise in
            p.gableBrickwork(w, rise)
            p.oculus(w / 2, rise * 0.4, radius: 3.4)
        }
        // The winch-house's stack through the roof's far slope, toward the back.
        chimneyStack(-0.66, -0.56, -0.48, -0.38, from: Slip.ridge - 10, to: Slip.ridge + 9, pots: 2)
        pennant(at: iso(x1 + 0.06, Slip.ym, Slip.ridge + 7), height: 14, length: 14)
        // The quay in front: a bollard at the slipway's foot, a lamp, barrels and a coil of rope.
        bollard(at: iso(0.9, Slip.ym + Slip.half + 0.12, h0))
        ropeCoil(at: iso(0.66, 0.3, h0))
        gasLamp(at: iso(0.82, 0.72, h0), height: 22)
        barrel(at: iso(-0.62, 0.5, h0), size: 0.85)
        barrel(at: iso(-0.38, 0.62, h0), size: 0.8)
        fishBoxes(-0.02, 0.5, on: h0)
    }

    /// The slipway: a channel from the doorway to the footprint's edge, its
    /// floor of timber sleepers falling from the yard to `Slip.foot`, between
    /// copings of dressed stone; with `rails`, the two iron rails along it.
    private mutating func slipway(rails: Bool, turn: IndustrialBoatHouseTurn) {
        typealias I = IndustrialOldBuildingsInk
        let (a, b) = (Slip.x1 - 0.02, 1.0)
        let (l, r) = (Slip.ym - Slip.half, Slip.ym + Slip.half)
        func floor(_ x: Double) -> Double { Slip.yard - 1.4 - (Slip.yard - 1.4 - Slip.foot) * (x - a) / (b - a) }
        // The channel's floor, wet and darker toward its foot, and its far inner wall.
        colour([at(turn, a, l, floor(a)), at(turn, b, l, floor(b)), at(turn, b, r, floor(b)), at(turn, a, r, floor(a))], .colour(I.timberDark))
        colour([at(turn, a, l, floor(a)), at(turn, b, l, floor(b)), at(turn, b, l, Slip.yard), at(turn, a, l, Slip.yard)], .colour(I.stoneShade))
        colour([at(turn, 0.7, l, floor(0.7)), at(turn, b, l, floor(b)), at(turn, b, r, floor(b)), at(turn, 0.7, r, floor(0.7))], .colour(I.dark), opacity: 0.25)
        // The sleepers across it.
        var x = a + 0.05
        while x < b - 0.02 {
            let h = floor(x) + 0.5
            shape([at(turn, x - 0.02, l + 0.02, h), at(turn, x + 0.02, l + 0.02, h), at(turn, x + 0.02, r - 0.02, h), at(turn, x - 0.02, r - 0.02, h)],
                  .colour(I.timber), width: 0.4)
            x += 0.075
        }
        if rails {
            for y in [Slip.ym - Slip.gauge, Slip.ym + Slip.gauge] {
                let p0 = at(turn, a, y, floor(a) + 1.4), p1 = at(turn, b, y, floor(b) + 1.4)
                svg.line([p0, p1], stroke: .colour(I.line), width: 1.7)
                svg.line([p0 + P(0, -0.3), p1 + P(0, -0.3)], stroke: .colour(I.ironLight), width: 0.6)
            }
        }
        line([at(turn, a, l, floor(a)), at(turn, b, l, floor(b))], width: 0.7)
        // The copings of dressed stone along both sides, the near one's face toward the viewer.
        for (y, w) in [(l - 0.05, l), (r, r + 0.05)] {
            shape([at(turn, a, y, Slip.yard + 0.6), at(turn, b, y, Slip.yard + 0.6), at(turn, b, w, Slip.yard + 0.6), at(turn, a, w, Slip.yard + 0.6)],
                  .colour(I.stoneTop), width: 0.6)
            for k in 1..<6 {
                let x = a + (b - a) * Double(k) / 6
                line([at(turn, x, y, Slip.yard + 0.6), at(turn, x, w, Slip.yard + 0.6)], width: 0.4, opacity: 0.5)
            }
        }
        shape([at(turn, a, r, floor(a)), at(turn, b, r, floor(b)), at(turn, b, r, Slip.yard + 0.6), at(turn, a, r, Slip.yard + 0.6)], .colour(I.stone),
              width: 0.7)
        // The end of the near coping and of the channel at the footprint's edge, which faces away in the back view.
        if turn == .side {
            shape([at(turn, b, r, Slip.yard + 0.6), at(turn, b, r + 0.05, Slip.yard + 0.6), at(turn, b, r + 0.05, 0), at(turn, b, r, floor(b))],
                  .colour(I.stoneShade), width: 0.6)
        }
        line([at(turn, b, l, floor(b)), at(turn, b, r, floor(b))], width: 0.8)
    }

    /// The dark of the shed seen through the open doorway: the rails running
    /// in, the chain from the winch, and the cradle's far end.
    private mutating func doorwayGloom() {
        typealias I = IndustrialOldBuildingsInk
        let x = Slip.x1
        for y in [Slip.ym - Slip.gauge, Slip.ym + Slip.gauge] {
            svg.line([iso(x, y, Slip.yard + 0.6), iso(x - 0.14, y, Slip.yard + 0.6)], stroke: .colour(I.ironLight), width: 0.6, opacity: 0.6)
        }
        // The winch's drum, faintly, at the back of the shed.
        svg.ellipse(iso(x - 0.02, Slip.ym + 0.02, 10), 2.6, 3.2, fill: .colour(I.iron), opacity: 0.55)
    }

    /// The bow of a trawler resting on its cradle on the rails, half out of the
    /// doorway: its black hull with a light rubbing strake and a green boot
    /// top, its stem raking forward, and the haul chain from the cradle back to the winch.
    private mutating func trawlerBow(turn: IndustrialBoatHouseTurn) {
        typealias I = IndustrialOldBuildingsInk
        let x0 = Slip.x1 - 0.02, ym = Slip.ym
        let keel = Slip.yard + 2.6, sheer = Slip.yard + 13.0, beam = 0.15
        /// The hull's half breadth along x, narrowing to the stem.
        func breadth(_ x: Double, _ k: Double) -> Double {
            let t = min(max((Slip.stem - x) / (Slip.stem - x0), 0), 1)
            return beam * k * pow(t, 0.55)
        }
        let xs = stride(from: x0, through: Slip.stem, by: 0.03).map { $0 } + [Slip.stem]
        // The cradle under it: two timber bearers on the rails, wedged.
        for x in [x0 + 0.08, x0 + 0.22] {
            pole(at(turn, x, ym - Slip.gauge - 0.03, Slip.yard + 1.6), at(turn, x, ym + Slip.gauge + 0.03, Slip.yard + 1.6), width: 2, colour: I.timber)
            pole(at(turn, x, ym + Slip.gauge, Slip.yard + 2), at(turn, x, ym + 0.06, keel + 3), width: 1.4, colour: I.timberLight)
        }
        // The chain hangs from the stem's foot in a curve back to the doorway, link by link.
        let (c0, c1, c2) = (at(turn, Slip.stem - 0.02, ym, keel + 6), at(turn, (Slip.stem + x0) / 2, ym + 0.02, keel - 0.6), at(turn, x0 - 0.02, ym, keel + 1))
        for k in 0...9 {
            let t = Double(k) / 9
            let p = c0 * ((1 - t) * (1 - t)) + c1 * (2 * t * (1 - t)) + c2 * (t * t)
            svg.ellipse(p, k % 2 == 0 ? 1.1 : 0.6, k % 2 == 0 ? 0.6 : 1, fill: .none, stroke: .colour(I.ironDark), width: 0.6)
        }
        // The near side, from the sheer down to the keel, and the far side's top over it.
        let nearSheer = xs.map { at(turn, $0, ym + breadth($0, 1), sheer + 2.2 * pow(($0 - x0) / (Slip.stem - x0), 2)) }
        let nearKeel = xs.map { x -> P in
            let t = (x - x0) / (Slip.stem - x0)
            return at(turn, x, ym + breadth(x, 0.35), keel + 9 * pow(max(t - 0.55, 0) / 0.45, 1.6))
        }
        let farSheer = xs.map { at(turn, $0, ym - breadth($0, 1), sheer + 2.2 * pow(($0 - x0) / (Slip.stem - x0), 2)) }
        shape(farSheer + nearSheer.reversed(), .colour(I.oakLight), width: 0.8)
        // The deck's planking, seen over the near bulwark.
        for k in 1..<4 {
            let f = Double(k) / 4
            let row = xs.map { at(turn, $0, ym - breadth($0, 1) + 2 * breadth($0, 1) * f, sheer + 2.2 * pow(($0 - x0) / (Slip.stem - x0), 2)) }
            line(row, width: 0.3, opacity: 0.5)
        }
        let side = nearSheer + nearKeel.reversed()
        colour(side, .colour(I.sootDark))
        // The boot top of bottle green along the foot of the side, and the light rubbing strake under the sheer.
        let boot = nearKeel.map { $0 + P(0, -0.2) } + nearKeel.reversed().map { $0 + P(0, -3.4) }
        colour(boot, .colour(I.green))
        line(nearSheer.map { $0 + P(0, 2.2) }, width: 1.6)
        svg.line(nearSheer.map { $0 + P(0, 2.2) }, stroke: .colour(I.light), width: 0.9)
        line(side, closed: true, width: 1.1)
        // The hawse pipe near the stem.
        let hawse = at(turn, Slip.stem - 0.07, ym + breadth(Slip.stem - 0.07, 1), sheer - 1.4)
        svg.circle(hawse, 1, fill: .colour(I.dark), stroke: .colour(I.line), width: 0.5)
    }

    /// A round window in a gable drawn with `wall`, centred on (`u`, `v`): glass
    /// in a ring of dressed stone with four keystones, and a glazing cross.
    private mutating func oculus(_ u: Double, _ v: Double, radius r: Double) {
        typealias I = IndustrialOldBuildingsInk
        let c = uv(u, v)
        svg.circle(c + shift, r + 1.4, fill: .colour(I.stoneTop))
        svg.circle(c, r + 1.4, fill: .none, stroke: .colour(I.line), width: 0.6)
        svg.circle(c, r, fill: .colour(I.glass), stroke: .colour(I.line), width: 0.6)
        svg.path("M\(num(c.x - r)),\(num(c.y)) h\(num(2 * r)) M\(num(c.x)),\(num(c.y - r)) v\(num(2 * r))", stroke: .colour(I.light), width: 0.6)
        colour([c + P(-r * 0.7, -r * 0.1), c + P(-r * 0.1, -r * 0.7), c + P(-r * 0.6, -r * 0.6)], .colour(I.glassLight), opacity: 0.8)
    }

    /// A lifebuoy hung on a wall drawn with `wall`, its centre at `c`: a ring of
    /// the light colour quartered in bottle green, on a peg.
    private mutating func lifebuoy(at c: P, radius r: Double) {
        typealias I = IndustrialOldBuildingsInk
        svg.line([c + P(0, -r - 0.6), c + P(0, -r - 1.6)], stroke: .colour(I.line), width: 0.8)
        svg.circle(c + shift * 0.5, r, fill: .none, stroke: .colour(I.light), width: r * 0.7)
        for a in [20.0, 200] {
            svg.path(AlchemyWarriorsKit.arc(c + shift * 0.5, r, from: a, to: a + 50), stroke: .colour(I.green), width: r * 0.7)
        }
        svg.circle(c, r + r * 0.35, fill: .none, stroke: .colour(I.line), width: 0.5)
        svg.circle(c, r - r * 0.35, fill: .none, stroke: .colour(I.line), width: 0.5)
    }

    /// A bollard of cast iron standing at `foot` on the screen: a squat post with a cap, a rope's turn about it.
    private mutating func bollard(at foot: P) {
        typealias I = IndustrialOldBuildingsInk
        svg.ellipse(foot + P(1, 0.6), 3, 1.2, fill: .colour("#000000"), opacity: 0.16)
        shape([foot + P(-2, 0), foot + P(-1.6, -5), foot + P(1.6, -5), foot + P(2, 0)], .colour(I.iron), width: 0.6)
        svg.ellipse(foot + P(0, -5.4), 2.6, 1.1, fill: .colour(I.iron), stroke: .colour(I.line), width: 0.6)
        svg.line([foot + P(-0.6, -4.6), foot + P(-0.8, -0.6)], stroke: .colour(I.ironLight), width: 0.5)
        svg.ellipse(foot + P(0, -2.6), 2.2, 0.8, fill: .none, stroke: .colour(I.straw), width: 1)
    }

    /// A coil of rope lying at `p` on the screen, in flat rings.
    private mutating func ropeCoil(at p: P) {
        typealias I = IndustrialOldBuildingsInk
        svg.ellipse(p + P(0.6, 0.4), 5.4, 2.4, fill: .colour("#000000"), opacity: 0.14)
        for (k, r) in [5.0, 3.8, 2.6].enumerated() {
            svg.ellipse(p + P(0, -Double(k) * 0.9), r, r * 0.42, fill: .colour(I.straw), stroke: .colour(I.line), width: 0.6)
        }
        svg.ellipse(p + P(0, -1.8), 1.2, 0.5, fill: .colour(I.strawShade))
    }

    /// Fish boxes of sawn timber stacked at (x, y) about the side view's
    /// footprint, turned by `turn`, on `h`: two below, one above, their ends
    /// showing; the nearer of the two below drawn second.
    private mutating func fishBoxes(_ x: Double, _ y: Double, on h: Double, turn: IndustrialBoatHouseTurn = .side) {
        let stack = [(0.0, 0.0, 0.0), (0.16, 0.0, 0.0), (0.08, 0.0, 4.0)]
        for (dx, dy, dh) in turn == .side ? stack : [stack[1], stack[0], stack[2]] {
            let r = turn.rect(x + dx, y + dy, x + dx + 0.14, y + dy + 0.2)
            crate(r.x0, r.y0, r.x1, r.y1, from: h + dh, height: 4)
        }
    }

    // MARK: Under construction

    /// The boat house being built: the setts laid and the slipway's sleepers
    /// and rails down; the walls raised part way in fresh brick, the doorway's
    /// opening spanned by its timber centring; scaffolding along the long wall
    /// with the owner's pennant; a ladder; and bricks, slates and timbers to hand.
    private mutating func boatShedRising() {
        typealias I = IndustrialOldBuildingsInk
        let (x0, y0, x1, y1, h0) = (Slip.x0, Slip.y0, Slip.x1, Slip.y1, Slip.yard)
        let top = 15.0
        let long = (x1 - x0) * 32, end = (y1 - y0) * 32
        slates(0.52, -0.94, 0.7, -0.66, from: h0, height: 6)
        shadow([iso(x1, y0, h0), iso(x1 + 0.2, y0 + 0.1, h0), iso(x1 + 0.2, y1 + 0.06, h0), iso(x1, y1, h0)])
        slipway(rails: true, turn: .side)
        shell(x0, y0, x1, y1, from: h0, floor: h0, to: top, thickness: 0.07, lit: .colour(I.rawBrick),
              shade: .colour(I.rawBrickShade), top: .colour(I.brickTop), ground: .colour(I.pavingShade)) { p in
            p.bricks(-0.5, -0.56, -0.24, -0.36, from: h0, height: 5)
            p.basket(at: p.iso(-0.1, -0.4, h0), size: 0.9)
        }
        wall(.left, from: x0, y1, at: h0) { p in
            p.shape(p.panel(0, 0, long, 2.6), .colour(I.rawStone), width: 0.6)
            p.brickwork(0, long, 2.6, top - h0, opacity: 0.4, burnt: false)
            for k in 0..<3 {
                let u = long * (Double(k) + 0.5) / 3
                p.shape(p.panel(u - 2.7, 6.6, u + 2.7, top - h0), .colour(I.dark), width: 0.8)
            }
        }
        wall(.right, from: x1, y1, at: h0) { p in
            p.shape(p.panel(0, 0, end, 2.6), .colour(I.rawStoneShade), width: 0.6)
            p.brickwork(0, end, 2.6, top - h0, opacity: 0.4, burnt: false)
            let door = (Slip.y1 - Slip.ym) * 32
            p.shape(p.panel(door - 7.5, 0, door + 7.5, top - h0), .colour(I.dark), width: 0.9)
            // The centring for the doorway's arch: a half round of boards on two props.
            p.centring(door, top - h0 - 0.4, radius: 7.5)
        }
        scaffold([(x0 + 0.1, y1 + 0.16), (-0.27, y1 + 0.16), (x1 - 0.1, y1 + 0.16)], from: h0, height: 34, levels: [12, 24], boards: 12,
                 inward: (0, -0.13))
        pennant(at: iso(x1 - 0.1, y1 + 0.16, h0 + 34), height: 11, length: 13)
        ladder(foot: iso(x1 + 0.1, 0.0, h0), iso(x1 + 0.1, 0.08, h0), head: iso(x1 + 0.02, 0.0, top + 6), iso(x1 + 0.02, 0.08, top + 6),
               rungs: 5)
        timbers(-0.7, 0.62, length: 0.6, on: h0)
        bricks(0.5, 0.42, 0.74, 0.66, from: h0, height: 6)
        bollard(at: iso(0.9, Slip.ym + Slip.half + 0.12, h0))
        basket(at: iso(0.18, 0.62, h0), size: 0.9)
    }

    /// The timber centring of an arch on a wall drawn with `wall`: a half round
    /// of boards centred on `u` and springing at `v`, on two props.
    private mutating func centring(_ u: Double, _ v: Double, radius r: Double) {
        typealias I = IndustrialOldBuildingsInk
        let arc = [uv(u - r, v)] + (1...12).map { k -> P in
            let a = Double(k) / 12 * .pi
            return uv(u - r * cos(a), v + r * sin(a))
        }
        colour(arc, .colour(I.timberLight))
        var d = PathData()
        d.move(arc[0])
        for p in arc.dropFirst() { d.line(p) }
        d.close()
        svg.path(d, stroke: .colour(I.line), width: 0.7)
        for k in 1..<4 {
            let a = Double(k) / 4 * .pi
            line([uv(u, v), uv(u - r * cos(a), v + r * sin(a))], width: 0.4, opacity: 0.6)
        }
        for s in [-1.0, 1.0] { timber(uv(u + s * (r - 1.4), 0.2), uv(u + s * (r - 1.4), v), width: 1.6, paint: I.timber) }
    }
}

extension IndustrialOldBuildingsPainter {
    // MARK: The back view

    /// The complete boat house turned so that its water side faces -y, away
    /// from the viewer: behind it, the slipway and the trawler's bow running
    /// out to the footprint's far edge, with the bollard, the lamp and the
    /// rope on the quay; then the shed, its long wall on the right with the
    /// owner's band, its landward gable toward the viewer with the
    /// winch-house's door and a window over it.
    private mutating func boatShedFromBehind() {
        typealias I = IndustrialOldBuildingsInk
        let (x0, y0, x1, y1, h0, e) = (Behind.x0, Behind.y0, Behind.x1, Behind.y1, Slip.yard, Slip.eave)
        let long = (y1 - y0) * 32, end = (x1 - x0) * 32
        // Behind the shed, toward the water, drawn first: the fish boxes, the slipway, the bow on its cradle, and the quay.
        fishBoxes(0.56, -0.92, on: h0, turn: .back)
        slipway(rails: true, turn: .back)
        trawlerBow(turn: .back)
        bollard(at: at(.back, 0.9, Slip.ym + Slip.half + 0.12, h0))
        ropeCoil(at: at(.back, 0.66, 0.3, h0))
        gasLamp(at: at(.back, 0.82, 0.72, h0), height: 22)
        // The shed's shadow across the yard to the right, the light being where it was.
        shadow([iso(x1, y0, h0), iso(x1 + 0.34, y0 + 0.14, h0), iso(x1 + 0.34, y1 + 0.1, h0), iso(x1, y1, h0)])
        block(x0, y0, x1, y1, h0, e, top: nil, left: .colour(I.brick), right: .colour(I.brickShade))
        // The long wall, as in the side view: plinth, brick, pilasters between arched windows, and the owner's band.
        wall(.right, from: x1, y1, at: h0) { p in
            p.shape(p.panel(0, 0, long, 2.6), .colour(I.footingShade), width: 0.6)
            p.brickwork(0, long, 2.6, e - h0)
            for u in [0.0, long / 3, long * 2 / 3, long] {
                p.pilaster(min(max(u, 1.5), long - 1.5), 2.6, 12.4, w: 3)
            }
            for k in 0..<3 {
                p.archedWindow(long * (Double(k) + 0.5) / 3, 3.6, w: 5.2, h: 7.4)
            }
            p.stringCourse(0, long, 12.4, 13.3)
            p.paintedBand(0, long, 14.3, 16.5)
            p.drainpipe(long - 1.2, from: e - h0 - 1)
        }
        // The landward gable: quoins, the winch-house's panelled door, and a window of three lights over it.
        wall(.left, from: x0, y1, at: h0) { p in
            p.shape(p.panel(0, 0, end, 2.6), .colour(I.footing), width: 0.6)
            p.brickwork(0, end, 2.6, e - h0)
            p.quoins(at: 0, atStart: true, from: 2.6, to: e - h0, course: 3.2, reach: 3.4)
            p.quoins(at: end, atStart: false, from: 2.6, to: e - h0, course: 3.2, reach: 3.4)
            p.door(end / 2, 2.6, w: 7, h: 12.4)
            p.casement(end / 2 - 6.4, 18.4, w: 12.8, h: 4.6, lights: 3, frame: I.brick)
        }
        gableAlongY(x0, y0, x1, y1, eave: e, ridge: Slip.ridge, over: 0.06, gableWall: .colour(I.brick)) { p, w, rise in
            p.gableBrickwork(w, rise)
            p.oculus(w / 2, rise * 0.4, radius: 3.4)
        }
        let stack = IndustrialBoatHouseTurn.back.rect(-0.66, -0.56, -0.48, -0.38)
        chimneyStack(stack.x0, stack.y0 + Behind.setBack, stack.x1, stack.y1 + Behind.setBack, from: Slip.ridge - 10, to: Slip.ridge + 9,
                     pots: 2)
        // The pennant over the water gable, on a finial at the ridge's far end, as in the side view.
        finial(at: iso(Behind.xm, y0 - 0.06, Slip.ridge), size: 1)
        pennant(at: iso(Behind.xm, y0 - 0.06, Slip.ridge + 7), height: 14, length: 14)
        // In front of the long wall: the fish boxes and the barrels.
        fishBoxes(-0.02, 0.5, on: h0, turn: .back)
        barrel(at: at(.back, -0.38, 0.62, h0), size: 0.8)
        barrel(at: at(.back, -0.62, 0.5, h0), size: 0.85)
    }

    /// The boat house being built, turned so that its water side faces -y:
    /// behind it, the slipway's sleepers and rails down to the far edge, and
    /// slates and bricks to hand; the walls raised part way in fresh brick,
    /// the water doorway's centring standing in the far gable, seen over the
    /// near walls; the landward gable with its door's opening framed;
    /// scaffolding along the long wall with the owner's pennant; a ladder; and
    /// timbers and a basket on the yard.
    private mutating func boatShedRisingFromBehind() {
        typealias I = IndustrialOldBuildingsInk
        let (x0, y0, x1, y1, h0) = (Behind.x0, Behind.y0, Behind.x1, Behind.y1, Slip.yard)
        let top = 15.0, t = 0.07
        let long = (y1 - y0) * 32, end = (x1 - x0) * 32
        let turn = IndustrialBoatHouseTurn.back
        let s = turn.rect(0.52, -0.94, 0.7, -0.66)
        slates(s.x0, s.y0, s.x1, s.y1, from: h0, height: 6)
        slipway(rails: true, turn: turn)
        bollard(at: at(turn, 0.9, Slip.ym + Slip.half + 0.12, h0))
        let b = turn.rect(0.5, 0.42, 0.74, 0.66)
        bricks(b.x0, b.y0, b.x1, b.y1, from: h0, height: 6)
        shadow([iso(x1, y0, h0), iso(x1 + 0.2, y0 + 0.1, h0), iso(x1 + 0.2, y1 + 0.06, h0), iso(x1, y1, h0)])
        shell(x0, y0, x1, y1, from: h0, floor: h0, to: top, thickness: t, lit: .colour(I.rawBrick),
              shade: .colour(I.rawBrickShade), top: .colour(I.brickTop), ground: .colour(I.pavingShade)) { p in
            // The water doorway in the far gable, seen from within, spanned by its centring.
            p.wall(.left, from: x0 + t, y0 + t, at: h0) { q in
                let door = (Behind.xm - x0 - t) * 32
                q.shape(q.panel(door - 7.5, 0, door + 7.5, top - h0), .colour(I.dark), width: 0.9)
                q.centring(door, top - h0 - 0.4, radius: 7.5)
            }
            let k = turn.rect(-0.5, -0.56, -0.24, -0.36)
            p.bricks(k.x0, k.y0, k.x1, k.y1, from: h0, height: 5)
            p.basket(at: p.at(turn, -0.1, -0.4, h0), size: 0.9)
        }
        // The landward gable, its door's opening framed in timber.
        wall(.left, from: x0, y1, at: h0) { p in
            p.shape(p.panel(0, 0, end, 2.6), .colour(I.rawStone), width: 0.6)
            p.brickwork(0, end, 2.6, top - h0, opacity: 0.4, burnt: false)
            let u = end / 2
            p.shape(p.panel(u - 3.6, 2.6, u + 3.6, 12.4), .colour(I.dark), width: 0.8)
            for side in [-1.0, 1.0] { p.timber(p.uv(u + side * 3.6, 2.6), p.uv(u + side * 3.6, 12.4), width: 1.2, paint: I.timberLight) }
            p.timber(p.uv(u - 4.4, 12.6), p.uv(u + 4.4, 12.6), width: 1.4, paint: I.timberLight)
        }
        // The long wall, its three windows' openings.
        wall(.right, from: x1, y1, at: h0) { p in
            p.shape(p.panel(0, 0, long, 2.6), .colour(I.rawStoneShade), width: 0.6)
            p.brickwork(0, long, 2.6, top - h0, opacity: 0.4, burnt: false)
            for k in 0..<3 {
                let u = long * (Double(k) + 0.5) / 3
                p.shape(p.panel(u - 2.7, 6.6, u + 2.7, top - h0), .colour(I.dark), width: 0.8)
            }
        }
        ladder(foot: iso(-0.24, y1 + 0.03, h0), iso(-0.16, y1 + 0.03, h0), head: iso(-0.24, y1 + 0.005, top + 6),
               iso(-0.16, y1 + 0.005, top + 6), rungs: 5)
        scaffold([(x1 + 0.16, y1 - 0.1), (x1 + 0.16, (y0 + y1) / 2), (x1 + 0.16, y0 + 0.1)], from: h0, height: 34, levels: [12, 24], boards: 12,
                 inward: (-0.13, 0))
        pennant(at: iso(x1 + 0.16, y0 + 0.1, h0 + 34), height: 11, length: 13)
        basket(at: at(turn, 0.18, 0.62, h0), size: 0.9)
        // Timbers laid along y on the yard in front of the scaffold.
        for (row, offsets) in [[0.0, 0.09, 0.18], [0.045, 0.135]].enumerated() {
            for dx in offsets { beam(0.62 + dx, 0.1, 0.62 + dx, 0.7, on: h0 + Double(row) * 2.6, size: 2.6) }
        }
    }
}

extension IndustrialOldBuildingsPainter {
    // MARK: The dock

    /// The dock, about the side view's footprint and turned by `turn`: a
    /// timber pier on cast-iron piles out over the water from the middle of the
    /// water edge, each pile ringed on the water; complete, its deck planked to
    /// the end with bollards and a gas lamp there; under construction, the
    /// piles standing and the decking laid part way out.
    private mutating func dock(complete: Bool, turn: IndustrialBoatHouseTurn) {
        typealias I = IndustrialOldBuildingsInk
        let (x0, x1, y0, y1) = (1.0, Slip.dockEnd, Slip.dock0, Slip.dock1)
        let (h0, h1) = (Slip.deck0, Slip.yard)
        /// The depth of a place on the screen once turned: what is drawn later stands nearer.
        func depth(_ x: Double, _ y: Double) -> Double {
            let p = turn.place(x, y)
            return p.x + p.y
        }
        // The piles in pairs across the pier, the rings on the water at their feet, then the piles, the farthest first.
        var piles: [(Double, Double)] = []
        for x in stride(from: x0 + 0.1, through: x1 - 0.05, by: 0.3) { piles += [(x, y0 + 0.04), (x, y1 - 0.04)] }
        piles.append(contentsOf: [(x1 - 0.04, y0 + 0.04), (x1 - 0.04, y1 - 0.04)])
        piles.sort { depth($0.0, $0.1) < depth($1.0, $1.1) }
        for (x, y) in piles {
            let foot = at(turn, x, y, 0)
            svg.ellipse(foot + P(0, 0.2), 3.4, 1.4, fill: .none, stroke: .colour(I.glassLight), width: 0.6, opacity: 0.8)
            svg.ellipse(foot + P(0, 0.1), 2.2, 0.9, fill: .none, stroke: .colour(I.light), width: 0.7, opacity: 0.9)
        }
        // The deck: whole when complete, part way out when building, the piles beyond it standing bare and uncut.
        let reach = complete ? x1 : x0 + (x1 - x0) * 0.55
        for (x, y) in piles {
            let bare = x > reach
            let foot = at(turn, x, y, 0), head = at(turn, x, y, bare ? h1 + 4 : h0)
            svg.line([foot, head - P(0, 0.4)], stroke: .colour(I.line), width: 2.6)
            svg.line([foot, head - P(0, 0.4)], stroke: .colour(I.iron), width: 1.5)
            svg.line([foot + P(-0.3, 0), head + P(-0.3, -0.4)], stroke: .colour(I.ironLight), width: 0.5)
            if bare { svg.ellipse(head - P(0, 0.4), 1.3, 0.6, fill: .colour(I.ironLight), stroke: .colour(I.line), width: 0.4) }
        }
        let deck = turn.rect(x0, y0, reach, y1)
        block(deck.x0, deck.y0, deck.x1, deck.y1, h0, h1, top: .colour(I.timberLight), left: .colour(I.timber), right: .colour(I.timberDark),
              width: 0.8)
        // The planks across the deck, and the gaps between them.
        var x = x0 + 0.07
        while x < reach - 0.03 {
            line([at(turn, x, y0, h1), at(turn, x, y1, h1)], width: 0.35, opacity: 0.55)
            x += 0.07
        }
        if complete {
            // Bollards along the edges and at the end, and the lamp at the end, the farthest first.
            enum Fitting { case bollard, lamp }
            var fittings: [(Double, Double, Fitting)] = [(x0 + 0.3, y0 + 0.07, .bollard), (x1 - 0.1, y0 + 0.07, .bollard),
                                                         (x1 - 0.1, y1 - 0.07, .bollard), (x1 - 0.42, y1 - 0.07, .lamp)]
            fittings.sort { depth($0.0, $0.1) < depth($1.0, $1.1) }
            for (x, y, fitting) in fittings {
                switch fitting {
                case .bollard: bollard(at: at(turn, x, y, h1))
                case .lamp: gasLamp(at: at(turn, x, y, h1), height: 18)
                }
            }
        } else {
            // A plank or two waiting at the deck's end, and the next pair of piles bare beyond it.
            let a = turn.rect(reach - 0.2, y0 + 0.1, reach - 0.04, y1 - 0.1)
            crate(a.x0, a.y0, a.x1, a.y1, from: h1, height: 1.6)
        }
    }
}
