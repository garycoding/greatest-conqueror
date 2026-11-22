// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// What the navy ship's three looks share (`NavyShipSprites`): the hull, built
// in the dugout's space (`StoneDugout.Space`: x along it toward the bow, y
// downward with the waterline at 0, z toward its starboard side, turned by the
// view's yaw and seen from the map's angle) from a half beam and a sheer; the
// water about it (the ring, the wake, the bow wave and the lapping), drawn as
// the boats draw theirs; the oars of a galley; a gun's barrel, its flash and
// its cloud of powder smoke; square sails on braced yards; and a flag of the
// team's colour.
//
// The ship turns to face its target when it fights (`face` in Combat.swift),
// so its guns fire ahead, over the bow: the flash points along the barrel and
// the smoke rolls forward from the muzzle, rises and thins. A shot's smoke
// lasts the cycle and fades out before the gun fires again, so that every
// fighting cycle comes round to where it began.

/// A hull of the navy ship: its half length, its half beam and its sheer.
struct NavyHull: Sendable {
    typealias Space = StoneDugout.Space
    typealias V = StoneDugout.V

    let halfLength: Double
    /// The half beam at `x`, at the gunwale.
    let halfBeam: @Sendable (Double) -> Double
    /// The height of the gunwale at `x` (negative, above the water).
    let gunwale: @Sendable (Double) -> Double
    /// How far along toward each end the waterline runs, as a share of the half length, and how far in it lies.
    let waterReach: Double, waterInset: Double
    /// Stations along the hull from the stern to the bow, closer toward the ends.
    let stations: [Double]

    init(halfLength: Double, waterReach: Double = 0.9, waterInset: Double = 0.88,
         halfBeam: @escaping @Sendable (Double) -> Double, gunwale: @escaping @Sendable (Double) -> Double) {
        self.halfLength = halfLength; self.halfBeam = halfBeam; self.gunwale = gunwale
        self.waterReach = waterReach; self.waterInset = waterInset
        stations = (0...28).map { i in -halfLength * cos(Double(i) / 28 * .pi) }
    }

    /// The gunwale all round (or a loop inside it, lower): along the starboard side from the stern, back along the port.
    func rim(_ space: Space, inset: Double = 1, lower: Double = 0) -> [P] {
        let right = stations.map { space.at($0, gunwale($0) + lower, halfBeam($0) * inset) }
        var left = Array(stations.reversed().map { space.at($0, gunwale($0) + lower, -halfBeam($0) * inset) })
        // Where an end comes to a point the two sides meet in it; a transom joins them across.
        if halfBeam(stations.last!) < 0.01 { left.removeFirst() }
        if halfBeam(stations.first!) < 0.01 { left.removeLast() }
        return right + left
    }

    /// The waterline all round, short of the ends.
    func waterline(_ space: Space) -> [P] {
        let xs = stations.filter { abs($0) <= halfLength * waterReach }
        let right = xs.map { space.at($0, 0, halfBeam($0) * waterInset) }
        let left = xs.reversed().map { space.at($0, 0, -halfBeam($0) * waterInset) }
        return right + left
    }

    /// Whether the outer side of the hull on `side` (+1 starboard, -1 port), turned a little toward `forward`, faces the viewer.
    static func faces(_ space: Space, side: Double, forward: Double = 0) -> Bool { space.depth(forward, side) > 0.05 }

    /// The side of the hull toward the viewer, from the near gunwale down to the near waterline.
    static func side(_ nearRim: [P], _ nearWater: [P]) -> [P] { nearRim + nearWater.reversed() }

    /// A band along a chain, from `top` to `bottom` below it on the screen.
    static func band(_ chain: [P], _ top: Double, _ bottom: Double) -> [P] {
        chain.map { $0 + P(0, top) } + chain.reversed().map { $0 + P(0, bottom) }
    }

    /// Everything above a chain (the near gunwale), for a clip.
    static func above(_ chain: [P]) -> [P] {
        let left = chain.first!, right = chain.last!
        return [P(-400, left.y)] + chain + [P(400, right.y), P(400, -400), P(-400, -400)]
    }

    /// A point on the outside of the hull on `side` at `x`, `down` below the gunwale.
    func onSide(_ x: Double, down: Double, side: Double) -> V {
        let g = gunwale(x)
        // The side tumbles home a little toward the waterline.
        let k = 1 - 0.1 * min(max(down / max(-g, 1), 0), 1)
        return V(x, g + down, side * halfBeam(x) * k)
    }
}

/// Drawing helpers shared by the navy ship's looks.
enum NavyKit {
    typealias Space = StoneDugout.Space
    typealias V = StoneDugout.V

    static let line = Paint.colour(Ink.line)

    /// A frame's place in its cycle, as an angle, and as a share from 0 up to 1.
    static func turn(_ frame: Int) -> Double { Double(frame) / Double(SpriteKey.framesPerPose) * 2 * .pi }
    static func share(_ frame: Int) -> Double { Double(frame) / Double(SpriteKey.framesPerPose) }

    /// How long ago, as a share of the cycle, a gun that fires at frame `fires` fired.
    static func since(_ frame: Int, fires: Int) -> Double {
        Double((frame - fires + 2 * SpriteKey.framesPerPose) % SpriteKey.framesPerPose) / Double(SpriteKey.framesPerPose)
    }

    /// How far a gun has run in after its shot: back at the shot, and run out again by a third of the cycle.
    static func recoil(_ frame: Int, fires: Int, by distance: Double) -> Double {
        let age = since(frame, fires: fires)
        return age < 1.0 / 3 ? distance * (1 - age * 3) * (age == 0 ? 0.8 : 1) : 0
    }

    /// The bob on the water: riding it at rest, pitching a little faster under way,
    /// and in a fight dipping at each shot as well.
    static func bob(_ pose: SpritePose, _ frame: Int, shots: [Int] = []) -> Double {
        let t = turn(frame)
        switch pose {
        case .walking: return 0.8 * sin(2 * t + 0.4)
        case .fighting:
            var kick = 0.0
            for shot in shots {
                let age = since(frame, fires: shot)
                if age < 0.25 { kick -= 0.9 * (1 - age * 4) }
            }
            return 0.5 * sin(t) + kick
        default: return 0.7 * sin(t)
        }
    }

    /// A shape in its colour a little out of register, with the line over it.
    static func shape(_ svg: inout SVG, _ points: [P], _ fill: Paint, width: Double = 1, opacity: Double = 1) {
        svg.polygon(points.map { $0 + P(-0.6, 0.5) }, fill: fill, opacity: opacity)
        svg.polygon(points, fill: .none, stroke: line, width: width)
    }

    /// Content drawn inside a clip.
    static func clipped(_ svg: inout SVG, id: String, _ points: [P], _ content: (inout SVG) -> Void) {
        svg.raw("<defs><clipPath id=\"\(id)\"><polygon points=\"\(StoneDugout.polygon(points))\"/></clipPath></defs>")
        svg.raw("<g clip-path=\"url(#\(id))\">")
        content(&svg)
        svg.raw("</g>")
    }

    /// A line in the hull's space, inked and coloured.
    static func spar(_ svg: inout SVG, _ space: Space, _ a: V, _ b: V, width: Double, colour: String) {
        let p = [space.at(a), space.at(b)]
        svg.line(p, stroke: line, width: width + 1.3)
        svg.line(p, stroke: .colour(colour), width: width)
    }

    /// Rigging: thin lines between points of the hull's space.
    static func rigging(_ svg: inout SVG, _ space: Space, _ pairs: [(V, V)], width: Double = 0.6) {
        var path = PathData()
        for (a, b) in pairs { path.move(space.at(a)); path.line(space.at(b)) }
        svg.path(path, stroke: line, width: width, opacity: 0.8)
    }

    /// A curved post (a stem, a sternpost) through points of the hull's space.
    static func post(_ svg: inout SVG, _ space: Space, _ points: [V], width: Double, colour: String) {
        let p = points.map(space.at)
        var path = PathData()
        path.move(p[0])
        for i in 1..<p.count { path.quad(p[i - 1] * 0.5 + p[i] * 0.5, p[i]) }
        if p.count > 1 { path.line(p[p.count - 1]) }
        svg.path(path, stroke: line, width: width + 1.5)
        svg.path(path, stroke: .colour(colour), width: width)
    }

    // MARK: The water

    /// The ring's width and depth about a hull.
    static func ring(_ space: Space, halfLength: Double, beam: Double) -> (centre: P, width: Double, depth: Double) {
        let width = abs(halfLength * space.c) + abs(beam * space.s) + 7
        let depth = max(0.12, StoneDugout.pitch * (abs(halfLength * space.s) + abs(beam * space.c) + 4) / width)
        return (space.at(0, 0, 0), width, depth)
    }

    /// The far half of the ring about the hull, drawn before it.
    static func ringBehind(_ svg: inout SVG, _ ring: (centre: P, width: Double, depth: Double)) {
        StoneBoatsWater.ring(&svg, at: ring.centre, rx: ring.width, opacity: 0.55, width: 1.1, arcs: [(190, 350)], depth: ring.depth)
    }

    /// The water along the near side and the near half of the ring, drawn after the hull.
    static func waterInFront(_ svg: inout SVG, nearWater: [P], _ ring: (centre: P, width: Double, depth: Double)) {
        var foam = PathData()
        for (i, p) in nearWater.enumerated() {
            if i == 0 { foam.move(p) } else { foam.quad((nearWater[i - 1] + p) * 0.5 + P(0, 1.1), p) }
        }
        svg.path(foam, stroke: .colour(BoatInk.foam), width: 1.7)
        StoneBoatsWater.ring(&svg, at: ring.centre, rx: ring.width, opacity: 0.75, width: 1.2, arcs: [(15, 165)], depth: ring.depth)
    }

    /// The water lapping at the hull as it rides at rest: a ring spreading and fading through the cycle.
    static func lapping(_ svg: inout SVG, _ ring: (centre: P, width: Double, depth: Double), frame: Int) {
        let age = share(frame)
        StoneBoatsWater.ring(&svg, at: ring.centre, rx: ring.width + 2 + 7 * age, opacity: 0.45 * (1 - age), width: 0.9,
                             arcs: [(25, 155)], depth: ring.depth)
    }

    /// The wake behind a ship under way: strokes spreading outward from the
    /// stern on either side, drifting back and fading, and a churn of foam under the stern.
    static func wake(_ svg: inout SVG, _ space: Space, hull: NavyHull, frame: Int, churn: Bool) {
        let p = share(frame), h = hull.halfLength
        let stern = hull.halfBeam(-h * 0.92)
        for side in [-1.0, 1.0] {
            for k in 0..<4 {
                let age = (p + Double(k) / 4).truncatingRemainder(dividingBy: 1)
                let back = -h - 2 - 26 * age
                let spread = stern * 0.8 + 3 + 15 * age
                let a = space.at(back, 0, side * spread), b = space.at(back - 9, 0, side * (spread + 4.5))
                svg.line([a, b], stroke: .colour(BoatInk.foam), width: 1.6 - 0.7 * age, opacity: 0.9 * (1 - age))
            }
        }
        guard churn else { return }
        for k in 0..<6 {
            let age = (p * 2 + Double(k) / 6).truncatingRemainder(dividingBy: 1)
            let z = 4.2 * sin(Double(k) * 2.4)
            let at = space.at(-h - 2 - 12 * age, 0, z * (1 + age))
            svg.ellipse(at, 1.8 + 1.8 * age, (1.8 + 1.8 * age) * 0.5, fill: .colour(BoatInk.foam), opacity: 0.85 * (1 - age))
        }
    }

    /// The bow wave: a crest of foam at the stem, and waves peeling off along both sides, running aft and spreading.
    static func bowWave(_ svg: inout SVG, _ space: Space, hull: NavyHull, stem: Double, frame: Int) {
        let p = share(frame)
        let swell = 0.5 + 0.5 * sin(turn(frame) * 2)
        let back = stem - 6
        var crest = PathData()
        crest.move(space.at(back, 0, -hull.halfBeam(back) - 1))
        crest.quad(space.at(stem + 4, -3 - swell, 0), space.at(back, 0, hull.halfBeam(back) + 1))
        crest.quad(space.at(stem + 1.5, 0.7, 0), space.at(back, 0, -hull.halfBeam(back) - 1))
        crest.close()
        svg.path(crest, fill: .colour(BoatInk.foam), stroke: line, width: 0.5, opacity: 0.95)
        for side in [-1.0, 1.0] {
            let a = space.at(stem - 2, 0, side * 2), b = space.at(stem - 26, 0, side * (hull.halfBeam(stem - 26) + 3.5 + 2.5 * swell))
            svg.path("M\(num(a.x)),\(num(a.y)) Q\(num((a.x + b.x) / 2)),\(num((a.y + b.y) / 2 - 1.4)) \(num(b.x)),\(num(b.y))",
                     stroke: .colour(BoatInk.foam), width: 2, opacity: 0.8 + 0.2 * swell)
            for k in 0..<3 {
                let age = (p + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                let x = stem - 24 - 56 * age
                let z = side * (hull.halfBeam(x) + 3.5 + 11 * age)
                let s0 = space.at(x, 0, z), s1 = space.at(x - 10, 0, z + side * 3.5)
                svg.line([s0, s1], stroke: .colour(BoatInk.foam), width: 1.5 - 0.6 * age, opacity: 0.85 * (1 - age))
            }
        }
    }

    // MARK: The guns

    /// A gun's barrel from its breech to its muzzle, in the hull's space: iron, with a ring at the muzzle.
    static func barrel(_ svg: inout SVG, _ space: Space, breech: V, muzzle: V, width: Double, colour: String, ring: String) {
        let a = space.at(breech), b = space.at(muzzle)
        svg.line([a, b], stroke: line, width: width + 1.4)
        svg.line([a, b], stroke: .colour(colour), width: width)
        let lip = space.at(muzzle - (muzzle - breech).unit * 1.4)
        svg.line([lip, b], stroke: line, width: width + 2.2)
        svg.line([lip, b], stroke: .colour(ring), width: width + 0.8)
        svg.circle(b, width * 0.42, fill: .colour(Ink.line))
    }

    /// The flash of a shot at the muzzle, pointing along the barrel on the
    /// screen, or round where the barrel points at or away from the viewer.
    static func flash(_ svg: inout SVG, _ space: Space, muzzle: V, along: V, size: Double, flash: String, core: String) {
        let at = space.at(muzzle), ahead = space.at(muzzle + along.unit * 10) - at
        let reach = (ahead.x * ahead.x + ahead.y * ahead.y).squareRoot() / 10
        let heading = atan2(ahead.y, ahead.x)
        var star: [P] = [], centre: [P] = []
        for i in 0..<16 {
            let a = Double(i) / 16 * 2 * .pi
            let forward = max(0, cos(a)) * reach
            let r = i % 2 == 0 ? size * (0.45 + 1.1 * forward) : size * 0.2
            let d = P(cos(a + heading), sin(a + heading))
            star.append(at + d * r + P(cos(heading), sin(heading)) * (size * 0.18 * reach))
            centre.append(at + d * (i % 2 == 0 ? r * 0.5 : size * 0.1))
        }
        svg.polygon(star.map { $0 + P(-0.6, 0.6) }, fill: .colour(flash))
        svg.polygon(star, fill: .none, stroke: line, width: 1)
        svg.polygon(centre, fill: .colour(core))
    }

    /// The cloud of powder smoke a shot leaves, `age` of the cycle after it:
    /// thrown forward from the muzzle along the barrel, rolling on, rising and thinning.
    static func smoke(_ svg: inout SVG, _ space: Space, muzzle: V, along: V, age: Double, scale: Double = 1) {
        guard age < 0.92 else { return }
        let u = along.unit
        let side = V(-u.z, 0, u.x)
        let spread = 1 - pow(1 - min(age * 3, 1), 2)
        let base: [(forward: Double, across: Double, up: Double, r: Double)] = [
            (3, 0, 0, 3.6), (9, 1.6, -1, 5), (16, -1.8, -0.4, 6), (24, 1.2, -2.4, 6.2), (31, -0.8, -1.2, 5.4),
            (13, 0.6, -5, 4.6), (21, -2.4, -6, 4.4), (28, 2.2, -5, 4.2),
        ]
        let origin = space.at(muzzle)
        let puffs: [(P, Double)] = base.map { b in
            let v = muzzle + u * (b.forward * scale * (0.25 + 0.75 * spread) + 6 * age) + side * (b.across * scale * (0.6 + age))
                + V(0, (b.up * scale - 14 * age * (0.4 + b.forward / 40)), 0)
            return (space.at(v) - origin, b.r * scale * (0.55 + 0.6 * spread + 0.25 * age))
        }
        AlchemyWarriorsKit.smoke(&svg, at: origin, puffs: puffs, opacity: 0.95 * pow(1 - age / 0.92, 1.2))
    }

    // MARK: Sails

    /// How the yards are braced in a view, in degrees from square across the
    /// hull toward the bow: chosen in each view so that a square sail never
    /// shows edge-on, as a draughtsman would brace them for the picture.
    static func brace(_ view: SpriteView) -> Double {
        switch view {
        case .side: 45
        case .frontQuarter: -5
        case .front, .back: 0
        case .backQuarter: 5
        }
    }

    /// A square sail hung from a yard at `head` (its middle), `half` wide each
    /// side and `drop` deep, braced by `degrees`, bellying forward by `belly`;
    /// its foot a little narrower than its head. A point on it is given by
    /// `s` across (-1 to 1) and `t` down (0 to 1).
    struct SquareSail {
        let head: V, half: Double, drop: Double, degrees: Double, belly: Double
        var yard: V { let r = degrees * .pi / 180; return V(sin(r), 0, cos(r)) }
        var normal: V { let r = degrees * .pi / 180; return V(cos(r), 0, -sin(r)) }
        func point(_ s: Double, _ t: Double) -> V {
            let width = half * (1 - 0.12 * t)
            let fill = belly * (1 - s * s * 0.7) * sin(.pi * (0.15 + 0.75 * t))
            return head + yard * (s * width) + V(0, drop * t, 0) + normal * fill
        }
        /// The outline: the head, the leech, the foot and the other leech.
        func outline(_ space: Space, from s0: Double = -1, to s1: Double = 1, t0: Double = 0, t1: Double = 1) -> [P] {
            let n = 8
            var v: [V] = []
            for i in 0...n { v.append(point(s0 + (s1 - s0) * Double(i) / Double(n), t0)) }
            for i in 1...n { v.append(point(s1, t0 + (t1 - t0) * Double(i) / Double(n))) }
            for i in 1...n { v.append(point(s1 - (s1 - s0) * Double(i) / Double(n), t1)) }
            for i in 1..<n { v.append(point(s0, t1 - (t1 - t0) * Double(i) / Double(n))) }
            return v.map(space.at)
        }
    }

    /// A sail set: canvas out of register with seams down it, and whatever the
    /// look paints on it (`device`), then the line; the yard over its head.
    static func squareSail(_ svg: inout SVG, _ space: Space, _ sail: SquareSail, canvas: String, seam: String, yard: String,
                           device: (inout SVG, SquareSail) -> Void) {
        let outline = sail.outline(space)
        svg.polygon(outline.map { $0 + P(-0.7, 0.6) }, fill: .colour(canvas))
        var seams = PathData()
        for s in stride(from: -0.75, through: 0.75, by: 0.25) {
            for i in 0...6 {
                let p = space.at(sail.point(s, Double(i) / 6))
                if i == 0 { seams.move(p) } else { seams.line(p) }
            }
        }
        svg.path(seams, stroke: .colour(seam), width: 0.6, opacity: 0.8)
        device(&svg, sail)
        svg.polygon(outline, fill: .none, stroke: line, width: 1)
        spar(&svg, space, sail.head - sail.yard * (sail.half + 2), sail.head + sail.yard * (sail.half + 2), width: 1.6, colour: yard)
    }

    /// A sail furled on its yard: the yard, and the canvas rolled along it, tied with gaskets.
    static func furled(_ svg: inout SVG, _ space: Space, head: V, half: Double, degrees: Double, canvas: String, yard: String) {
        let r = degrees * .pi / 180, u = V(sin(r), 0, cos(r))
        spar(&svg, space, head - u * (half + 2), head + u * (half + 2), width: 1.6, colour: yard)
        let a = space.at(head - u * half + V(0, 1.6, 0)), b = space.at(head + u * half + V(0, 1.6, 0))
        svg.line([a, b], stroke: line, width: 5)
        svg.line([a, b], stroke: .colour(canvas), width: 3.4)
        var gaskets = PathData()
        for k in stride(from: -0.8, through: 0.8, by: 0.4) {
            let p = space.at(head + u * (half * k) + V(0, 1.6, 0))
            gaskets.move(p + P(0, -1.8)); gaskets.line(p + P(0, 1.8))
        }
        svg.path(gaskets, stroke: line, width: 0.6)
    }

    // MARK: The flag

    /// A flag of the team's colour flying from `hoist` (its top at the staff),
    /// `length` long and `height` deep, toward the screen's left (aft, in the side
    /// view): streaming and rippling under way, hanging and stirring otherwise.
    /// A swallow-tailed pennant when `pennant`.
    static func flag(_ svg: inout SVG, at hoist: P, length: Double, height: Double, streaming: Bool, frame: Int, pennant: Bool = false,
                     edge: String = Ink.light) {
        let t = turn(frame)
        let droop = streaming ? 1.0 : height * 0.9
        func at(_ u: Double, _ w: Double) -> P {
            let wave = (streaming ? 1.5 : 0.9) * sin(t * (streaming ? 2 : 1) - u * 0.4) * u / length
            let taper = pennant ? 1 - 0.6 * u / length : 1
            return hoist + P(-u * (streaming ? 1 : 0.8), w * taper + droop * u / length + wave)
        }
        let us = stride(from: 0.0, through: length, by: length / 6).map { $0 }
        let top = us.map { at($0, 0) }, bottom = us.map { at($0, height) }
        let cloth = top + (pennant ? [at(length * 0.75, height * 0.5)] : []) + bottom.reversed()
        svg.polygon(cloth, fill: .none, stroke: .colour(edge), width: 2.2)
        svg.polygon(cloth.map { $0 + P(-0.4, 0.3) }, fill: .team)
        svg.polygon(cloth, fill: .none, stroke: line, width: 0.6)
    }
}

/// One oar of a galley in a frame: its port in the hull's side, the direction
/// it runs outboard, and how square its blade is to the water.
struct NavyOar {
    typealias V = StoneDugout.V
    typealias Space = StoneDugout.Space
    let side: Double
    let port: V, tip: V
    /// From the port toward the blade.
    let along: V
    let square: Double, length: Double, blade: Double

    /// The oar from `port`, swept by `sweep` degrees (positive with the blade
    /// aft) and dipped by `dip` degrees (positive with the blade down).
    init(side: Double, port: V, sweep: Double, dip: Double, square: Double, length: Double, blade: Double) {
        self.side = side; self.port = port; self.square = square; self.length = length; self.blade = blade
        let s = sweep * .pi / 180, p = dip * .pi / 180
        along = V(-sin(s) * cos(p), sin(p), side * cos(s) * cos(p))
        tip = port + along * length
    }

    /// The breadth of the blade: flat on the water when feathered, upright when square.
    var across: V {
        let flat = V(-along.z, 0, along.x).unit
        let upright = V(along.y * flat.z - along.z * flat.y, along.z * flat.x - along.x * flat.z, along.x * flat.y - along.y * flat.x).unit
        return (flat * (1 - square) + upright * square).unit
    }

    /// The oar outboard of its port: the loom and the blade, what lies under the water drawn faintly as if through it.
    func draw(_ svg: inout SVG, _ space: Space, wood: String, dark: String) {
        let neck = port + along * (length - blade)
        let w = across
        let leafShape = [neck + w * 0.6, neck + along * 2.4 + w * 1.9, tip + w * 1.8, tip + along * 0.6, tip - w * 1.8,
                         neck + along * 2.4 - w * 1.9, neck - w * 0.6]
        let shaft = IronCut.split([port, neck], closed: false)
        let leaf = IronCut.split(leafShape, closed: true)
        if shaft.below.count > 1 { svg.line(shaft.below.map(space.at), stroke: .colour(dark), width: 1.6, opacity: 0.35) }
        if leaf.below.count > 2 { svg.polygon(leaf.below.map(space.at), fill: .colour(wood), opacity: 0.35) }
        if shaft.above.count > 1 {
            let points = shaft.above.map(space.at)
            svg.line(points, stroke: .colour(Ink.line), width: 2.4)
            svg.line(points, stroke: .colour(wood), width: 1.2)
        }
        if leaf.above.count > 2 {
            let points = leaf.above.map(space.at)
            svg.polygon(points.map { $0 + P(-0.5, 0.4) }, fill: .colour(wood))
            svg.polygon(points, fill: .none, stroke: .colour(Ink.line), width: 0.8)
        }
    }

    /// Where the blade cuts the water, if it does: a ring and a curl of foam.
    func drawWater(_ svg: inout SVG, _ space: Space) {
        guard tip.y > 0, port.y < 0 else { return }
        let k = -port.y / (tip.y - port.y)
        let entry = port + (tip - port) * k
        StoneBoatsWater.ring(&svg, at: space.at(entry), rx: 3.4, opacity: 0.85, width: 0.9, depth: 0.42)
        let back = space.at(entry + V(-4, 0, 0)), e = space.at(entry)
        svg.path("M\(num(e.x)),\(num(e.y)) Q\(num(back.x)),\(num(back.y - 1.4)) \(num(back.x - 1.6)),\(num(back.y))",
                 stroke: .colour(BoatInk.foam), width: 1, opacity: 0.8)
    }
}
