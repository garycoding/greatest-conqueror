// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The Alchemy age's boat, the fishing smack (ruled 2026-11-21): a decked
// sailing boat with a straight stem, a transom stern and a bowsprit, rigged
// with one mast, a gaff mainsail and a jib. Its hull is tarred oak with a
// strake of the team's colour under a pale gunwale, its bulwarks teal within;
// the mainsail is of the team's colour charged with the alchemist's sun, the
// jib of undyed canvas, and the team's pennant streams from the masthead. One
// fisherman sails her from the stern, a weathered man in a teal gansey knitted
// in diamonds across the chest, the team's neckerchief at his throat, a wine
// stocking cap, and a grey chin-curtain beard; nose A, the small curve.
//
// The hull lives in its own space, as the dugout's does (`StoneDugout`): x
// along it toward the bow, y downward with the waterline at 0, z toward its
// right (starboard). The boat heels and pitches a little in that space, a view
// turns it by its yaw (`SpriteView.yaw`), and the water is a plane seen at the
// map's angle, so that a point nearer the viewer is drawn lower by `pitch` of
// its depth. The fisherman is drawn with the figure kit (`Drawing`) in the
// same view, seated, so that only his body above the waist shows over the
// gunwale; his arms reach from the kit's shoulders to hands that live in the
// hull's space, on the tiller, the sheet or the net.
//
// Standing, the smack lies hove to: the sail slack, the boom swinging gently,
// the leech fluttering, the fisherman's hand on the tiller as he breathes and
// blinks. Walking, she sails with the wind on her starboard side: the sail
// full and breathing, the boom out to port, the hull heeled to port and
// pitching gently, the pennant streaming, a bow wave curling and a wake
// spreading behind. Working, the sail is slack again and the fisherman hauls a
// net over the starboard side, hand over hand, the corks of its head-rope and
// a fish coming up out of the water, water dripping and rings spreading where
// it comes out. Every cycle is periodic in its 12 frames. The origin is on the
// waterline at the middle of the hull; the boat casts no shadow.

enum AlchemySmack {
    /// Room for the hull and the bowsprit in every view, the mast and its pennant, the wake and the ring.
    static let canvas = Canvas(minX: -98, minY: -138, width: 196, height: 176, pixelsPerUnit: Canvas.person.pixelsPerUnit)

    /// The hull's half length, its half beam at the widest, and the water's pitch.
    static let halfLength = 54.0, beam = 15.5, pitch = 0.42
    /// Where the fisherman sits along the hull and across it (toward starboard,
    /// the weather side), and how far below the figure's ground the waterline
    /// lies (his hips sit on the after thwart).
    static let seat = -36.0, side = 6.0, kneel = 15.0
    /// The mast's place along the hull, its head, and the bowsprit's end.
    static let mastX = 12.0, masthead = -124.0
    static var bowsprit: V { V(halfLength + 22, -18.5, 0) }
    static let nose = Nose.curve

    typealias V = StoneDugout.V

    /// Whether the boat has the pose: it has no attack, so no fighting.
    static func drawn(_ pose: SpritePose) -> Bool { pose == .standing || pose == .walking || pose == .working }

    /// A frame of a pose in a view, as a sprite's picture and mask, grained alike, on `canvas` or another scale of it.
    static func render(_ pose: SpritePose, frame: Int, view: SpriteView = .side, canvas: Canvas = AlchemySmack.canvas) -> Rendered? {
        guard drawn(pose) else { return nil }
        let rig = rig(pose, frame)
        return Raster.render(on: canvas) { svg in
            var d = Drawing(layer: svg.layer, rig: rig, phase: Double(frame) / 12, view: view)
            draw(&d, pose, frame)
            svg = d.svg
        }
    }

    // MARK: Motion

    /// A frame's place in its cycle, as an angle.
    static func turn(_ frame: Int) -> Double { Double(frame) / Double(SpriteKey.framesPerPose) * 2 * .pi }

    /// A smooth step from 0 to 1.
    static func ease(_ x: Double) -> Double { (1 - cos(min(max(x, 0), 1) * .pi)) / 2 }

    /// How far the boat rises on the water in a frame.
    static func bob(_ pose: SpritePose, _ frame: Int) -> Double {
        let t = turn(frame)
        switch pose {
        case .walking: return 0.6 * sin(t) + 0.25 * sin(2 * t + 0.7)
        case .working: return 0.5 * sin(t) + 0.3 * sin(2 * t)
        default: return 0.7 * sin(t)
        }
    }

    /// How far the boat heels to port (radians), and how far its bow rises.
    static func motion(_ pose: SpritePose, _ frame: Int) -> (heel: Double, trim: Double) {
        let t = turn(frame)
        switch pose {
        case .walking: return (0.075 + 0.014 * sin(t + 0.8), 0.016 * sin(t))
        // Hauling over the starboard side, she leans toward him with each pull.
        case .working: return (-0.03 - 0.014 * sin(2 * t), 0.008 * sin(t))
        default: return (0.022 * sin(t + 0.5), 0.01 * sin(t))
        }
    }

    /// The sails' trim in a frame: the boom's angle out to port (degrees), how
    /// full the mainsail is, how much its leech flutters and at what phase, and
    /// how far the jib's clew stands out and how full the jib is.
    struct Trim {
        var boom: Double, belly: Double, flutter: Double, phase: Double, jibOut: Double, jibBelly: Double
    }

    static func trim(_ pose: SpritePose, _ frame: Int) -> Trim {
        let t = turn(frame)
        switch pose {
        case .walking:
            return Trim(boom: 17 + 1.2 * sin(t), belly: 6 + 0.7 * sin(t + 1.4), flutter: 0.35, phase: 2 * t, jibOut: 9, jibBelly: 2.6 + 0.4 * sin(t + 1.4))
        case .working:
            return Trim(boom: 7 + 2.5 * sin(t), belly: 1.6, flutter: 1.8, phase: 2 * t, jibOut: 3, jibBelly: 0.8 + 0.6 * sin(2 * t))
        default:
            return Trim(boom: 13 + 4 * sin(t), belly: 2.4 + 0.8 * sin(t + 1), flutter: 1.2, phase: 2 * t, jibOut: 5, jibBelly: 1.3)
        }
    }

    /// How far the fisherman's net has come in: a hand's share of its stroke,
    /// from 0 (reaching) to 1 (pulled in), over the half cycle `u` (0 to 1).
    static func haul(_ u: Double) -> Double { u < 0.6 ? ease(u / 0.6) : 1 - ease((u - 0.6) / 0.4) }

    /// The right hand's stroke in a frame of the working pose: two pulls to the cycle.
    static func pull(_ frame: Int) -> Double { haul((Double(frame) / 6).truncatingRemainder(dividingBy: 1)) }

    /// The skeleton's state: the breath, the lean of the body and the face.
    static func rig(_ pose: SpritePose, _ frame: Int) -> Rig {
        var r = Rig()
        let t = turn(frame)
        switch pose {
        case .walking:
            r.lean = 3 + sin(t)
            r.lift = 0.4 * sin(t)
            r.headTilt = -5
            r.mouth = .firm
        case .working:
            let p = pull(frame)
            r.lean = 22 - 7 * p
            r.headTilt = 6
            r.eyes = .down
            r.mouth = p > 0.55 && p < 0.95 ? .open : .firm
        default:
            r.lean = 2
            r.lift = 0.8 * sin(t)
            r.eyes = frame == 8 ? .closed : .open
        }
        return r
    }

    // MARK: The space of the hull

    /// The hull's space seen in a view, the boat risen by `rise`, heeled to
    /// port by `heel` and its bow raised by `trim` (radians).
    struct Space {
        let c: Double, s: Double, rise: Double
        private let ch: Double, sh: Double, ct: Double, st: Double
        init(_ view: SpriteView, rise: Double, heel: Double = 0, trim: Double = 0) {
            let r = view.yaw * .pi / 180
            c = cos(r); s = sin(r); self.rise = rise
            ch = cos(heel); sh = sin(heel); ct = cos(trim); st = sin(trim)
        }
        /// A point of the boat moved by its heel and its trim.
        func moved(_ v: V) -> V {
            let y1 = v.y * ch - v.z * sh, z1 = v.y * sh + v.z * ch
            return V(v.x * ct + y1 * st, y1 * ct - v.x * st, z1)
        }
        /// How far a point lies toward the viewer.
        func depth(_ v: V) -> Double { let m = moved(v); return m.x * s + m.z * c }
        func depth(_ x: Double, _ z: Double) -> Double { depth(V(x, 0, z)) }
        /// A point of the hull's space on the screen.
        func at(_ v: V) -> P {
            let m = moved(v)
            return P(m.x * c - m.z * s, m.y - rise + pitch * (m.x * s + m.z * c))
        }
        func at(_ x: Double, _ y: Double, _ z: Double) -> P { at(V(x, y, z)) }
    }

    /// The half beam of the hull at `x`, at the gunwale: full forward to a
    /// fine bow, and narrowing aft to the transom.
    static func halfBeam(_ x: Double) -> Double {
        if x >= 0 { return beam * max(0, 1 - pow(min(x / halfLength, 1), 2.4)).squareRoot() }
        return beam * (1 - 0.42 * pow(min(-x / halfLength, 1), 2.2))
    }

    /// The height of the gunwale at `x` (negative, above the water): the sheer, rising most toward the bow.
    static func gunwale(_ x: Double) -> Double {
        let f = min(abs(x) / halfLength, 1)
        return x >= 0 ? -(13 + 5.5 * f * f) : -(13 + 2.8 * f * f)
    }

    /// Stations along the hull from the transom to the stem, closer toward the ends.
    static let stations: [Double] = (0...22).map { i in -halfLength * cos(Double(i) / 22 * .pi) }

    /// The gunwale all round: along the right side from the transom, back
    /// along the left, and across the transom.
    static func rim(_ space: Space, inset: Double = 1, lower: Double = 0) -> [P] {
        let right = stations.map { space.at($0, gunwale($0) + lower, halfBeam($0) * inset) }
        let left = stations.reversed().map { space.at($0, gunwale($0) + lower, -halfBeam($0) * inset) }
        return right + left.dropFirst()
    }

    /// The waterline all round.
    static func waterline(_ space: Space) -> [P] {
        let xs = stations.filter { $0 < halfLength * 0.94 }
        let right = xs.map { space.at($0, 0, halfBeam($0) * 0.9) }
        let left = xs.reversed().map { space.at($0, 0, -halfBeam($0) * 0.9) }
        return right + left
    }

    static func polygon(_ points: [P]) -> String { points.map { "\(num($0.x)),\(num($0.y))" }.joined(separator: " ") }

    // MARK: Drawing

    static func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let (heel, trimAngle) = motion(pose, frame)
        let space = Space(d.view, rise: bob(pose, frame), heel: heel, trim: trimAngle)
        let sails = trim(pose, frame)
        let rim = Self.rim(space), water = waterline(space)
        let hull = StoneDugout.outline(rim + water + [space.at(halfLength * 0.99, -5, 0)])
        let nearRim = StoneDugout.nearChain(rim), nearWater = StoneDugout.nearChain(water)

        // The water behind and about the boat.
        let ringCentre = space.at(0, 0, 0)
        let ringWidth = abs(halfLength * space.c) + abs(beam * space.s) + 7
        let ringDepth = max(0.12, pitch * (abs(halfLength * space.s) + abs(beam * space.c) + 3) / ringWidth)
        StoneBoatsWater.ring(&d.svg, at: ringCentre, rx: ringWidth, opacity: 0.55, width: 1.1, arcs: [(190, 350)], depth: ringDepth)
        if pose == .walking { wake(&d, space, frame) }

        let sternNear = space.depth(-halfLength, 0) > space.depth(0, 0)
        if !sternNear { rudder(&d, space) }
        drawHull(&d, space, hull: hull, rim: rim, nearRim: nearRim, nearWater: nearWater, pose: pose, frame: frame)
        if sternNear { rudder(&d, space) }

        // The rig and the fisherman, the farther first.
        let boomRad = sails.boom * .pi / 180
        let rigDepth = space.depth(mastX - 10 * cos(boomRad), -10 * sin(boomRad))
        let personDepth = space.depth(seat, side)
        if rigDepth < personDepth {
            drawRig(&d, space, sails, frame)
            fisherman(&d, space, nearRim: nearRim, pose: pose, frame: frame, sails: sails)
        } else {
            fisherman(&d, space, nearRim: nearRim, pose: pose, frame: frame, sails: sails)
            drawRig(&d, space, sails, frame)
        }

        // The water along the near side, and what the boat stirs.
        var foam = PathData()
        for (i, p) in nearWater.enumerated() {
            if i == 0 { foam.move(p) } else { foam.quad((nearWater[i - 1] + p) * 0.5 + P(0, 1.1), p) }
        }
        d.svg.path(foam, stroke: .colour(BoatInk.foam), width: 1.6)
        StoneBoatsWater.ring(&d.svg, at: ringCentre, rx: ringWidth, opacity: 0.75, width: 1.2, arcs: [(15, 165)], depth: ringDepth)
        switch pose {
        case .walking: bowWave(&d, space, frame)
        case .working: netWater(&d, space, frame)
        default:
            // Lapping at the hull as she rides the water.
            let age = Double(frame) / 12
            StoneBoatsWater.ring(&d.svg, at: ringCentre, rx: ringWidth + 2 + 6 * age, opacity: 0.45 * (1 - age), width: 0.9,
                                 arcs: [(25, 155)], depth: ringDepth)
        }
    }

    // MARK: The hull

    static func drawHull(_ d: inout Drawing, _ space: Space, hull: [P], rim: [P], nearRim: [P], nearWater: [P],
                         pose: SpritePose, frame: Int) {
        let line = Paint.colour(Ink.line)
        // The hull's colour out of register, and the shade along the waterline.
        d.svg.polygon(hull.map { $0 + P(-0.9, 0.7) }, fill: .colour(SmackInk.hull))
        d.svg.polygon(nearWater + nearWater.reversed().map { $0 + P(0, -3.6) }, fill: .colour(SmackInk.hullShade), opacity: 0.6)
        // Within the gunwale: the bulwarks' teal, and the deck below them.
        d.svg.polygon(rim, fill: .colour(SmackInk.bulwark))
        d.svg.raw("<defs><clipPath id=\"smack-deck\"><polygon points=\"\(polygon(rim))\"/></clipPath></defs>")
        d.svg.raw("<g clip-path=\"url(#smack-deck)\">")
        let deck = Self.rim(space, inset: 0.8, lower: 3.8)
        d.svg.polygon(deck, fill: .colour(SmackInk.deck))
        var seams = PathData()
        for k in [-0.5, 0.0, 0.5] {
            for (i, x) in stations.enumerated() where i > 0 && i < stations.count - 1 {
                let p = space.at(x, gunwale(x) + 3.8, k * halfBeam(x) * 0.8)
                if i == 1 { seams.move(p) } else { seams.line(p) }
            }
        }
        d.svg.path(seams, stroke: .colour(SmackInk.deckSeam), width: 0.5, opacity: 0.7)
        hold(&d, space, pose: pose, frame: frame)
        d.svg.raw("</g>")
        // The strake of the team's colour under the gunwale, a light line under it, and the planking below.
        let band = nearRim.map { $0 + P(0, 1.3) } + nearRim.reversed().map { $0 + P(0, 5.2) }
        d.svg.polygon(band, fill: .team)
        d.svg.line(nearRim.map { $0 + P(0, 5.9) }, stroke: .colour(SmackInk.light), width: 1)
        for drop in [8.8, 11.6] {
            let usable = nearRim.indices.filter { i in
                let p = nearRim[i] + P(0, drop)
                return p.y < (nearWater.min { abs($0.x - p.x) < abs($1.x - p.x) }?.y ?? 0) - 1.4
            }
            if usable.count > 1 {
                d.svg.line(usable.map { nearRim[$0] + P(0, drop) }, stroke: .colour(SmackInk.hullShade), width: 0.6)
            }
        }
        d.svg.polygon(hull, fill: .none, stroke: line, width: 1.5)
        d.svg.polygon(rim, fill: .none, stroke: line, width: 1.1)
        d.svg.line(nearRim.map { $0 + P(0, 0.8) }, stroke: .colour(SmackInk.gunwaleCap), width: 0.8)
        d.svg.line(nearRim.map { $0 + P(0, 1.3) }, stroke: line, width: 0.5)
    }

    /// The hatch of the fish hold amidships, its coaming, and the catch in it.
    static func hold(_ d: inout Drawing, _ space: Space, pose: SpritePose, frame: Int) {
        let y = gunwale(-10) + 3.8
        let corners = [V(-19, y, -5.4), V(-3, y, -5.4), V(-3, y, 5.4), V(-19, y, 5.4)]
        let raised = corners.map { $0 + V(0, -1.6, 0) }
        // The coaming's sides, then the dark of the hold within it.
        d.svg.polygon(StoneDugout.outline((corners + raised).map(space.at)), fill: .colour(SmackInk.coaming),
                      stroke: .colour(Ink.line), width: 0.7)
        d.svg.polygon(raised.map(space.at), fill: .colour(SmackInk.holdDark), stroke: .colour(Ink.line), width: 0.7)
        // The catch, silver in the dark.
        let count = pose == .working ? 4 : 2
        for k in 0..<count {
            let at = space.at(-15 + Double(k) * 3.2, y - 1.8, -2.4 + Double(k % 2) * 3)
            d.svg.ellipse(at, 1.5, 0.6, fill: .colour(BoatInk.fishBelly), stroke: .colour(Ink.line), width: 0.4)
        }
    }

    /// The rudder hung on the transom: its blade down into the water, faint below it.
    static func rudder(_ d: inout Drawing, _ space: Space) {
        let x = -halfLength - 0.6
        let above = [V(x, -16.2, 0), V(x - 2.4, -16.2, 0), V(x - 6.6, 0, 0), V(x, 0, 0)].map(space.at)
        let below = [V(x, 0, 0), V(x - 6.6, 0, 0), V(x - 7.4, 6, 0), V(x, 7, 0)].map(space.at)
        d.svg.polygon(below, fill: .colour(SmackInk.hull), opacity: 0.3)
        d.svg.polygon(above.map { $0 + P(-0.5, 0.4) }, fill: .colour(SmackInk.hull))
        d.svg.polygon(above, fill: .none, stroke: .colour(Ink.line), width: 0.9)
    }

    // MARK: The rig

    /// The mainsail's corners and its surface: a quadrilateral between the
    /// mast, the boom and the gaff, bellied to leeward and fluttering at the leech.
    struct Sail {
        let tack: V, clew: V, throat: V, peak: V, normal: V
        let belly: Double, flutter: Double, phase: Double

        func point(_ s: Double, _ t: Double) -> V {
            let foot = tack + (clew - tack) * s, head = throat + (peak - throat) * s
            let base = foot + (head - foot) * t
            let bulge = belly * sin(.pi * s) * (0.4 + 0.6 * sin(.pi * t))
            let wave = flutter * s * s * sin(2 * .pi * 1.5 * t - phase)
            return base + normal * (bulge + wave)
        }

        /// The outline: the foot, the leech, the head along the gaff, and the luff down the mast.
        var outline: [V] {
            let n = 10
            let steps = (0...n).map { Double($0) / Double(n) }
            return steps.map { point($0, 0) } + steps.dropFirst().map { point(1, $0) }
                + steps.reversed().dropFirst().map { point($0, 1) } + steps.reversed().dropFirst().dropLast().map { point(0, $0) }
        }
    }

    static func mainsail(_ sails: Trim) -> Sail {
        let a = sails.boom * .pi / 180, g = a + 0.12, rake = 34.0 * .pi / 180
        let along = V(-cos(a), 0, -sin(a))
        let tack = V(mastX, -30, 0), throat = V(mastX, -100, 0)
        let gaff = V(-cos(g) * cos(rake), -sin(rake), -sin(g) * cos(rake))
        return Sail(tack: tack, clew: tack + along * 29 + V(0, -3, 0), throat: throat, peak: throat + gaff * 30,
                    normal: V(sin(a), 0, -cos(a)), belly: sails.belly, flutter: sails.flutter, phase: sails.phase)
    }

    /// The mast and its stays, the boom and the gaff, the mainsail and the jib,
    /// the bowsprit and the pennant: the farther of the two sails first.
    static func drawRig(_ d: inout Drawing, _ space: Space, _ sails: Trim, _ frame: Int) {
        let main = mainsail(sails)
        let forestay = (V(mastX, -114, 0), bowsprit)
        // The jib's head and tack on the forestay, its clew out to port.
        let jibHead = forestay.0 + (forestay.1 - forestay.0) * 0.1, jibTack = forestay.0 + (forestay.1 - forestay.0) * 0.9
        let jibClew = V(mastX + 17, -25, -sails.jibOut * 1.2)
        let mastDepth = space.depth(mastX, 0)
        let mainDepth = space.depth(main.point(0.5, 0.5))
        let jibDepth = space.depth((jibHead + jibTack + jibClew) * (1.0 / 3))

        // The shrouds on the far side.
        for z in [-1.0, 1.0] where space.depth(mastX - 3, z * halfBeam(mastX - 3)) < mastDepth { shroud(&d, space, z) }
        spar(&d, space, V(halfLength - 3, gunwale(halfLength - 3) + 1.5, 0), bowsprit, width: 2.3)
        var order: [(Double, Int)] = [(mainDepth, 0), (jibDepth, 1), (mastDepth, 2)]
        order.sort { $0.0 < $1.0 }
        for (_, part) in order {
            switch part {
            case 0: sail(&d, space, main)
            case 1: jib(&d, space, head: jibHead, tack: jibTack, clew: jibClew, belly: sails.jibBelly, frame: frame)
            default:
                spar(&d, space, V(mastX, gunwale(mastX) + 1, 0), V(mastX, masthead, 0), width: 2.6)
                d.svg.circle(space.at(mastX, masthead - 1, 0), 1.5, fill: .colour(SmackInk.spar), stroke: .colour(Ink.line), width: 0.6)
            }
        }
        d.svg.line([space.at(forestay.0), space.at(forestay.1)], stroke: .colour(Ink.line), width: 0.6)
        for z in [-1.0, 1.0] where space.depth(mastX - 3, z * halfBeam(mastX - 3)) >= mastDepth { shroud(&d, space, z) }
        pennant(&d, space, sails, frame)
    }

    /// A shroud from the mast's head down to the gunwale on one side.
    static func shroud(_ d: inout Drawing, _ space: Space, _ z: Double) {
        let foot = V(mastX - 3, gunwale(mastX - 3), z * halfBeam(mastX - 3))
        d.svg.line([space.at(mastX, -106, 0), space.at(foot)], stroke: .colour(Ink.line), width: 0.6)
    }

    /// A spar of pale wood from `a` to `b`, `width` thick, outlined.
    static func spar(_ d: inout Drawing, _ space: Space, _ a: V, _ b: V, width: Double) {
        let points = [space.at(a), space.at(b)]
        d.svg.line(points, stroke: .colour(Ink.line), width: width + 1.3)
        d.svg.line(points, stroke: .colour(SmackInk.spar), width: width)
    }

    /// The mainsail: the team's colour, its cloths' seams and a row of reef
    /// points in the light colour, the sun charged on it, the boom and the gaff.
    static func sail(_ d: inout Drawing, _ space: Space, _ sail: Sail) {
        let outline = sail.outline.map(space.at)
        d.svg.polygon(outline.map { $0 + P(-0.8, 0.6) }, fill: .team)
        var seams = PathData()
        for s in [0.2, 0.4, 0.6, 0.8] {
            seams.move(space.at(sail.point(s, 0.02)))
            for t in stride(from: 0.2, through: 0.98, by: 0.16) { seams.line(space.at(sail.point(s, t))) }
        }
        d.svg.path(seams, stroke: .colour(SmackInk.light), width: 0.5, opacity: 0.45)
        var reef = PathData()
        for s in stride(from: 0.1, through: 0.9, by: 0.115) {
            reef.move(space.at(sail.point(s, 0.17))); reef.line(space.at(sail.point(s, 0.13)))
        }
        d.svg.path(reef, stroke: .colour(SmackInk.light), width: 0.7, opacity: 0.85)
        sun(&d, space, sail, at: (0.48, 0.58), radius: 0.13)
        d.svg.polygon(outline, fill: .none, stroke: .colour(Ink.line), width: 1.1)
        spar(&d, space, sail.tack + (sail.tack - sail.clew) * 0.04, sail.clew + (sail.clew - sail.tack) * 0.08, width: 1.9)
        spar(&d, space, sail.throat, sail.peak + (sail.peak - sail.throat) * 0.05, width: 1.6)
    }

    /// The alchemist's sun on the sail in the light colour, drawn on its
    /// surface so that it turns and bellies with it: a ring round a point, and rays.
    static func sun(_ d: inout Drawing, _ space: Space, _ sail: Sail, at centre: (Double, Double), radius r: Double) {
        // The sail is about twice as tall as it is long, so the ring is half as deep in t as in s.
        let (s0, t0) = centre, k = 0.5
        func at(_ a: Double, _ f: Double) -> P { space.at(sail.point(s0 + r * f * cos(a), t0 + r * k * f * sin(a))) }
        let ring = (0...16).map { at(Double($0) / 16 * 2 * .pi, 1) }
        let wide = abs(at(0, 1).x - at(.pi, 1).x)
        guard wide > 1.6 else { return }
        d.svg.line(ring, stroke: .colour(SmackInk.light), width: 1)
        d.svg.polygon((0..<8).map { at(Double($0) / 8 * 2 * .pi, 0.3) }, fill: .colour(SmackInk.light))
        var rays = PathData()
        for j in 0..<8 {
            let a = Double(j) / 8 * 2 * .pi
            rays.move(at(a, 1.4)); rays.line(at(a, 1.85))
        }
        d.svg.path(rays, stroke: .colour(SmackInk.light), width: 0.8)
    }

    /// The jib of undyed canvas between the forestay and its clew, bellied to leeward.
    static func jib(_ d: inout Drawing, _ space: Space, head: V, tack: V, clew: V, belly: Double, frame: Int) {
        let normal = V(0.2, 0, -1).unit
        func point(_ s: Double, _ t: Double) -> V {
            let foot = tack + (clew - tack) * s
            let base = foot + (head - foot) * t
            return base + normal * (belly * sin(.pi * s) * sin(.pi * (0.15 + 0.85 * (1 - t))) * (1 - t * 0.6))
        }
        let n = 8
        let steps = (0...n).map { Double($0) / Double(n) }
        let leech = steps.dropFirst().map { t in point(1 - t, t) }
        let outline = steps.map { point($0, 0) } + leech + steps.reversed().dropFirst().map { t in point(0, t) }
        let points = outline.map(space.at)
        d.svg.polygon(points.map { $0 + P(-0.8, 0.6) }, fill: .colour(SmackInk.canvas))
        // Its shaded half, toward the leech.
        let shade = steps.map { point(0.55 + 0.45 * $0, 0) } + leech + [point(0.45, 0.55)]
        d.svg.polygon(shade.map(space.at), fill: .colour(SmackInk.canvasShade), opacity: 0.8)
        var seams = PathData()
        for s in [0.35, 0.7] {
            seams.move(space.at(point(s, 0))); seams.line(space.at(point(s * 0.5, 0.5))); seams.line(space.at(head))
        }
        d.svg.path(seams, stroke: .colour(SmackInk.canvasSeam), width: 0.5, opacity: 0.7)
        d.svg.polygon(points, fill: .none, stroke: .colour(Ink.line), width: 1)
        // The sheet from the clew to the deck.
        d.svg.line([space.at(clew), space.at(mastX + 3, gunwale(mastX + 3), -halfBeam(mastX + 3) * 0.7)], stroke: .colour(Ink.line), width: 0.5)
    }

    /// The team's swallow-tailed pennant at the masthead, streaming to leeward and rippling.
    static func pennant(_ d: inout Drawing, _ space: Space, _ sails: Trim, _ frame: Int) {
        let a = (sails.boom + 18) * .pi / 180
        let w = V(-cos(a), 0, -sin(a)), across = V(-w.z, 0, w.x)
        let base = V(mastX, masthead + 1.2, 0)
        let n = 6, length = 16.0
        var top: [V] = [], bottom: [V] = []
        for k in 0...n {
            let f = Double(k) / Double(n)
            let ripple = across * (1.5 * f * sin(2 * .pi * (f * 0.9 - 2 * Double(frame) / 12)))
            let sag = V(0, 1.2 * f * f + 0.5 * f * sin(2 * .pi * (f - Double(frame) / 6)), 0)
            let half = 1.8 * (1 - 0.45 * f)
            let along = base + w * (length * f) + ripple + sag
            top.append(along + V(0, -half, 0)); bottom.append(along + V(0, half, 0))
        }
        let fork = base + w * (length * 0.8) + across * (1.5 * 0.8 * sin(2 * .pi * (0.72 - 2 * Double(frame) / 12)))
            + V(0, 1.2 * 0.64 + 0.4 * sin(2 * .pi * (0.8 - Double(frame) / 6)), 0)
        let cloth = (top + [fork] + bottom.reversed()).map(space.at)
        d.svg.polygon(cloth.map { $0 + P(-0.5, 0.4) }, fill: .team)
        d.svg.polygon(cloth, fill: .none, stroke: .colour(Ink.line), width: 0.7)
    }

    // MARK: The fisherman

    /// The fisherman, seated aft: the tiller and the sheet, or the net, in his
    /// hands. His body is clipped above the near gunwale.
    static func fisherman(_ d: inout Drawing, _ space: Space, nearRim: [P], pose: SpritePose, frame: Int, sails: Trim) {
        let left = nearRim.first!, right = nearRim.last!
        let above = [P(-300, left.y)] + nearRim + [P(300, right.y), P(300, -300), P(-300, -300)]
        d.svg.raw("<defs><clipPath id=\"smack-above-gunwale\"><polygon points=\"\(polygon(above))\"/></clipPath></defs>")
        let origin = space.at(seat, 0, side) + P(0, kneel)
        let lean = d.rig.lean * cos(d.yaw * .pi / 180)
        func placed(_ p: P) -> P { p.rotated(lean, about: Drawing.hips) + origin }
        let shoulders = [false, true].map { right in
            placed(d.project(0.5, -44 - d.rig.lift, right ? Drawing.shoulderSpread : -Drawing.shoulderSpread).point)
        }
        let hands = Self.hands(pose, frame)
        let heldPoints = hands.map { $0.map(space.at) }
        /// Whether an arm lies behind the body: its hand and shoulder farther than the body's middle.
        let armBehind = [false, true].map { right -> Bool in
            guard let hand = hands[right ? 1 : 0] else { return true }
            let z = (right ? Drawing.shoulderSpread : -Drawing.shoulderSpread) + side
            return (space.depth(seat + 0.5, z) + space.depth(hand)) / 2 < space.depth(seat, side) - 2.5
        }
        tiller(&d, space, pose: pose, frame: frame)
        if pose != .working { sheet(&d, space, sails, hand: hands[1]) }
        for r in [false, true] where armBehind[r ? 1 : 0] {
            if let hand = heldPoints[r ? 1 : 0] { arm(&d, from: shoulders[r ? 1 : 0], to: hand) }
        }
        d.svg.raw("<g clip-path=\"url(#smack-above-gunwale)\"><g transform=\"translate(\(num(origin.x)),\(num(origin.y))) "
                  + "rotate(\(num(lean)) \(num(Drawing.hips.x)) \(num(Drawing.hips.y)))\">")
        body(&d)
        d.svg.raw("</g></g>")
        if pose == .working { net(&d, space, frame, hands: hands) }
        for r in [false, true] where !armBehind[r ? 1 : 0] {
            if let hand = heldPoints[r ? 1 : 0] { arm(&d, from: shoulders[r ? 1 : 0], to: hand) }
        }
    }

    /// Where the tiller's end lies in a frame: swung a little as he steers, or lashed amidships while he hauls.
    static func tillerEnd(_ pose: SpritePose, _ frame: Int) -> V {
        let t = turn(frame)
        switch pose {
        case .walking: return V(seat + 9, -21.5, side - 6 + 1.6 * sin(t + 0.4))
        case .working: return V(seat + 7, -20.5, 0)
        default: return V(seat + 9, -21.5, side - 6 + 0.6 * sin(t))
        }
    }

    /// The left (back) hand and the right (front) hand in the hull's space, or nil where a hand holds nothing.
    static func hands(_ pose: SpritePose, _ frame: Int) -> [V?] {
        let t = turn(frame)
        switch pose {
        case .working:
            // The right hand reaches out over the gunwale and pulls the net up and in; the left takes it in.
            let p = pull(frame), q = haul((Double(frame) / 6 + 0.5).truncatingRemainder(dividingBy: 1))
            let reach = V(seat + 15, -17, halfBeam(seat + 15) + 0.6), pulled = V(seat + 10, -31, side + 6)
            let taken = V(seat + 9, -23, side + 1), fed = V(seat + 7, -17, side + 2)
            return [taken + (fed - taken) * q, reach + (pulled - reach) * p]
        case .walking:
            return [tillerEnd(pose, frame), V(seat + 8 + 1.4 * sin(t), gunwale(seat + 8) - 2 + 0.8 * cos(t), halfBeam(seat + 8) - 2.2)]
        default:
            return [tillerEnd(pose, frame), V(seat + 7, gunwale(seat + 7) - 1, halfBeam(seat + 7) - 1.6)]
        }
    }

    /// The tiller from the rudder's head over the transom to its end.
    static func tiller(_ d: inout Drawing, _ space: Space, pose: SpritePose, frame: Int) {
        let head = V(-halfLength - 0.6, -16.2, 0), end = tillerEnd(pose, frame)
        spar(&d, space, head, end, width: 1.5)
        if pose == .working {
            // Lashed to the quarters while he hauls.
            for z in [-1.0, 1.0] {
                d.svg.line([space.at(end), space.at(seat + 5, gunwale(seat + 5), z * halfBeam(seat + 5) * 0.95)],
                           stroke: .colour(Ink.line), width: 0.5)
            }
        }
    }

    /// The mainsheet from the boom's end down to its block on the transom and up to his hand.
    static func sheet(_ d: inout Drawing, _ space: Space, _ sails: Trim, hand: V?) {
        let main = mainsail(sails)
        let block = V(-halfLength + 4, gunwale(-halfLength + 4) - 0.6, 0)
        var points = [space.at(main.clew + (main.clew - main.tack) * 0.04), space.at(block)]
        if let hand { points.append(space.at(hand)) }
        d.svg.line(points, stroke: .colour(Ink.line), width: 0.6)
        d.svg.circle(space.at(block), 0.9, fill: .colour(SmackInk.spar), stroke: .colour(Ink.line), width: 0.4)
    }

    /// An arm in its knitted sleeve from the shoulder to the hand on the screen,
    /// its elbow bent downward where the hand comes nearer than the arm's length.
    static func arm(_ d: inout Drawing, from shoulder: P, to hand: P) {
        let delta = hand - shoulder
        let distance = (delta.x * delta.x + delta.y * delta.y).squareRoot()
        let segment = max(Joints.upperArm, distance / 2 + 0.05)
        let along = distance / 2, out = (segment * segment - along * along).squareRoot()
        let u = delta * (1 / max(distance, 1e-6)), n = P(-u.y, u.x)
        let middle = shoulder + u * along
        let one = middle + n * out, two = middle - n * out
        let elbow = one.y > two.y ? one : two
        let cuff = elbow + (hand - elbow) * 0.78
        d.svg.line([shoulder, elbow, cuff], stroke: .colour(Ink.line), width: 4)
        d.svg.line([shoulder, elbow, cuff], stroke: .colour(SmackInk.gansey), width: 2.4)
        d.svg.line([cuff, hand], stroke: .colour(Ink.line), width: 1.9)
        d.hand(hand)
    }

    /// The fisherman above the waist, in the figure's space: the gansey with
    /// its diamonds, the team's neckerchief, and the head with its beard and cap.
    static func body(_ d: inout Drawing) {
        let gansey = [P(-11, -46), P(8.5, -47.6), P(10.6, -15), P(-12.6, -14)]
        d.garment(colour: gansey.map { $0 + P(-0.7, 0.6) }, outline: [P(-8, -47), P(8, -47), P(10.5, -17), P(-11.5, -17)],
                  fill: .colour(SmackInk.gansey)) { d in
            // The knitted diamonds across the chest, and the ribbing at the waist.
            for y in [-38.6, -33.2] {
                var zig = PathData()
                for i in 0...8 {
                    let p = d.onBody(d.up(P(-9.6 + Double(i) * 2.4, y + (i % 2 == 0 ? 0 : -2.4))))
                    if i == 0 { zig.move(p) } else { zig.line(p) }
                }
                d.svg.path(zig, stroke: .colour(SmackInk.ganseyPattern), width: 0.8)
            }
            for x in stride(from: -9.0, through: 8, by: 2.4) {
                d.svg.line([d.onBody(d.up(P(x, -20.4))), d.onBody(d.up(P(x + 0.2, -17.4)))], stroke: .colour(SmackInk.ganseyDark), width: 0.6)
            }
            // The neckerchief, knotted at the throat.
            d.band([P(-9.4, -47.2), P(8, -48.6), P(8.8, -43.8), P(-10, -42.8)])
        }
        d.head(nose: nose, hair: { d in
            hair(&d)
        }, features: { d in
            beard(&d)
        }, brow: { d in
            d.svg.path("M1.4,-64.4 q3.4,-1.6 6.6,-0.6", stroke: .colour(SmackInk.greyHair), width: 2.2)
            d.svg.path("M1.4,-64.4 q3.4,-1.6 6.6,-0.6", stroke: .colour(Ink.line), width: 0.6)
        }, over: { d in
            cap(&d)
        })
    }

    /// The grey hair showing under the cap at the nape and over the ears.
    static func hair(_ d: inout Drawing) {
        let hair = Paint.colour(SmackInk.greyHair)
        switch d.view {
        case .side: d.svg.path("M-10.4,-62 C-11.4,-57 -10,-53.4 -6.6,-52.4 C-6,-55.6 -6.2,-59 -5.4,-62 Z", fill: hair)
        case .front:
            for k in [-1.0, 1.0] {
                d.svg.path("M\(num(k * 10)),-62 C\(num(k * 10.8)),-59 \(num(k * 10.4)),-56.4 \(num(k * 9.2)),-55 L\(num(k * 7.6)),-61.6 Z", fill: hair)
            }
        case .frontQuarter: d.svg.path("M-10.8,-61.6 C-12,-57 -11,-53 -7.8,-51.6 C-7.4,-55 -6.6,-58.6 -5.4,-61.8 Z", fill: hair)
        case .back:
            d.svg.path("M-10.6,-61 C-11.2,-56 -9.6,-52 -6,-51 C-2,-50.4 2,-50.4 6,-51 C9.6,-52 11.2,-56 10.6,-61 C6,-59 -6,-59 -10.6,-61 Z", fill: hair)
        case .backQuarter:
            d.svg.path("M-10.6,-60.6 C-11.4,-56 -10,-52 -6.6,-51 C-2,-50.4 3,-50.6 6,-51.8 C7.6,-54 7.8,-57 7.4,-60 C3,-58.6 -5,-58.6 -10.6,-60.6 Z", fill: hair)
        }
    }

    /// The grey chin-curtain beard along his jaw, under the mouth, as the view shows it.
    static func beard(_ d: inout Drawing) {
        let hair = Paint.colour(SmackInk.greyHair), line = Paint.colour(Ink.line)
        let path: String
        switch d.view {
        case .side:
            path = "M-5.6,-56.6 C-5.4,-50 -1,-45.4 5,-45.4 C8.6,-45.4 10.8,-47 11.4,-49.6 C8.4,-48.4 4.6,-48.6 2.2,-50.2 "
                + "C0,-51.6 -2.6,-54 -5.6,-56.6 Z"
        case .front:
            path = "M-9.8,-57 C-9.8,-49.6 -5,-45.2 0,-45.2 C5,-45.2 9.8,-49.6 9.8,-57 C8,-52 4.4,-48.8 0,-48.8 C-4.4,-48.8 -8,-52 -9.8,-57 Z"
        case .frontQuarter:
            path = "M-7.2,-57.6 C-7.4,-50 -2.6,-45.2 3.4,-45.2 C8,-45.2 11.2,-48.4 11.6,-53 C9.4,-50.4 6.6,-48.8 3.6,-48.8 "
                + "C-0.6,-48.8 -4.6,-52 -7.2,-57.6 Z"
        case .back:
            path = "M-10.4,-56 C-10.6,-52 -9.2,-49.6 -7.6,-48.6 L-8.6,-55.4 Z M10.4,-56 C10.6,-52 9.2,-49.6 7.6,-48.6 L8.6,-55.4 Z"
        case .backQuarter:
            path = "M7.6,-57 C8.4,-52.6 8,-49.4 6,-47.6 C5.6,-50.4 5.8,-53.6 6.2,-56.6 Z"
        }
        d.svg.path(path, fill: hair, stroke: line, width: 0.8)
    }

    /// The wine stocking cap, rolled at its brim, its crown folded over toward the back with a bobble.
    static func cap(_ d: inout Drawing) {
        let view = d.view
        let cap = AlchemyViews.dome(view, radius: 11.4, front: -64.6, back: -61.6, top: -76, crest: -2.6)
        BronzePeopleProps.shape(&d.svg, cap, fill: .colour(SmackInk.cap), width: 1.5)
        // The crown's fold, and its bobble, toward the back of the head.
        let tip = AlchemyViews.project(view, -8.6, -74, 0)
        d.svg.circle(tip.point, 2.1, fill: .colour(SmackInk.capLight), stroke: .colour(Ink.line), width: 0.8)
        var band = PathData()
        let rim = AlchemyViews.rim(view, radius: 11.4, front: -64.4, back: -61.8)
        band.move(rim[0])
        for p in rim.dropFirst() { band.line(p) }
        d.svg.path(band, stroke: .colour(Ink.line), width: 3.8)
        d.svg.path(band, stroke: .colour(SmackInk.capLight), width: 2.2)
    }

    // MARK: The net

    /// Where the net comes out of the water, and where it comes over the gunwale.
    static var netFromWater: V { V(seat + 38, 0, halfBeam(seat + 34) + 13) }
    static var netAtGunwale: V { V(seat + 15, gunwale(seat + 15) + 0.4, halfBeam(seat + 15) + 0.4) }

    /// The net being hauled: its mesh hanging from the head-rope between the
    /// water and the gunwale, faint below the water; its corks and a fish coming
    /// up along it; the rope through his hands and the heap of net on the deck.
    static func net(_ d: inout Drawing, _ space: Space, _ frame: Int, hands: [V?]) {
        let w = netFromWater, g = netAtGunwale
        let line = Paint.colour(Ink.line)
        func head(_ q: Double) -> V { w + (g - w) * q + V(0, -5 * sin(.pi * q), 0) }
        func foot(_ q: Double) -> V { head(q) + V(0, 4 + 9 * (1 - q), 1 + 2 * (1 - q)) }
        // The heap of net on the deck behind the gunwale, behind the rope.
        let heap = V(seat + 6, gunwale(seat + 6) + 2.4, side + 4)
        let hc = space.at(heap)
        d.svg.ellipse(hc + P(-0.6, 0.4), 4.6, 2.2, fill: .colour(SmackInk.netDark))
        d.svg.ellipse(hc, 4.6, 2.2, fill: .none, stroke: line, width: 0.7)
        for k in 0..<3 { d.svg.circle(hc + P(-2.6 + Double(k) * 2.4, -0.6 + Double(k % 2) * 0.8), 0.8, fill: .colour(SmackInk.cork)) }
        // The mesh, under the water faint, above it plain.
        let n = 8
        var under = PathData(), over = PathData()
        func segment(_ a: V, _ b: V) {
            let mid = (a + b) * 0.5
            if mid.y > 0 { under.move(space.at(a)); under.line(space.at(b)) } else { over.move(space.at(a)); over.line(space.at(b)) }
        }
        let rows = 4
        for i in 0..<n {
            let q0 = Double(i) / Double(n), q1 = Double(i + 1) / Double(n)
            for r in 0...rows {
                let f = Double(r) / Double(rows)
                let a = head(q0) + (foot(q0) - head(q0)) * f, b = head(q1) + (foot(q1) - head(q1)) * f
                segment(a, b)
            }
        }
        for i in 0...n {
            let q = Double(i) / Double(n)
            for r in 0..<rows {
                let f0 = Double(r) / Double(rows), f1 = Double(r + 1) / Double(rows)
                segment(head(q) + (foot(q) - head(q)) * f0, head(q) + (foot(q) - head(q)) * f1)
            }
        }
        d.svg.path(under, stroke: .colour(SmackInk.mesh), width: 0.7, opacity: 0.4)
        d.svg.path(over, stroke: .colour(Ink.line), width: 1.5, opacity: 0.5)
        d.svg.path(over, stroke: .colour(SmackInk.mesh), width: 0.8)
        // The fish caught in the mesh, coming up with it and flapping.
        for k in 0..<2 {
            let fq = (Double(frame) / 6 + Double(k) / 2).truncatingRemainder(dividingBy: 1)
            // It reaches the gunwale on its last frame, where it passes into the boat, and fades over two frames at either end.
            let along = min(1, fq * 1.2)
            let fishAt = head(along) + (foot(along) - head(along)) * (0.4 + 0.2 * Double(k)) * (1 - along)
            let shown = min(1, fq / 0.3) * min(1, (1 - fq) / 0.34)
            guard shown > 0.02 else { continue }
            let p = space.at(fishAt)
            let flap = 30 * sin(turn(frame) * 4 + Double(k) * 2)
            d.svg.group(at: p, turned: -60 + flap) { svg in
                let body = [P(-5.4, 0), P(-2, -2.2), P(3.4, -1.5), P(5.4, 0), P(3.4, 1.5), P(-2, 2.2)]
                let alpha = fishAt.y > 0 ? 0.4 * shown : shown
                svg.polygon(body, fill: .colour(BoatInk.fishBelly), stroke: line, width: 0.6, opacity: alpha)
                svg.polygon([P(-4.8, 0), P(-8, -2.4), P(-8, 2.4)], fill: .colour(BoatInk.fishBack), stroke: line, width: 0.5, opacity: alpha)
                svg.line([P(-2, -1.8), P(3.2, -1.3)], stroke: .colour(BoatInk.fishBack), width: 1.1, opacity: alpha)
                svg.circle(P(3.6, -0.3), 0.5, fill: line, opacity: alpha)
            }
        }
        // The head-rope with its corks coming up along it, the rope through his hands, and down to the heap.
        let ropePoints = (0...n).map { space.at(head(Double($0) / Double(n))) }
        var rope = ropePoints
        if let right = hands[1] { rope.append(space.at(right)) }
        if let left = hands[0] { rope.append(space.at(left)) }
        rope.append(hc + P(1, -0.6))
        d.svg.line(rope, stroke: line, width: 1.4)
        d.svg.line(rope, stroke: .colour(SmackInk.rope), width: 0.6)
        for k in 0..<4 {
            let q = ((Double(k) + Double(frame) * 2 / 3) / 4).truncatingRemainder(dividingBy: 1)
            // Faded over two frames at either end, so that none appears or vanishes at once.
            let fade = min(1, q / 0.3) * min(1, (1 - q) / 0.34)
            guard fade > 0.02 else { continue }
            let at = head(q)
            d.svg.ellipse(space.at(at), 2, 1.4, fill: .colour(SmackInk.cork), stroke: line, width: 0.6,
                          opacity: at.y > 0 ? 0.4 * fade : fade)
        }
    }

    /// The water about the net: rings where it comes out, and drops falling from it.
    static func netWater(_ d: inout Drawing, _ space: Space, _ frame: Int) {
        let p = Double(frame) / 12
        let at = space.at(netFromWater)
        for lag in [0.0, 0.33, 0.66] {
            let age = (p * 2 + lag).truncatingRemainder(dividingBy: 1)
            StoneBoatsWater.ring(&d.svg, at: at, rx: 3 + 9 * age, opacity: 0.8 * pow(1 - age, 1.3), width: 1, depth: 0.42)
        }
        // Drops running off the mesh back into the water.
        for (k, q) in [0.3, 0.55, 0.8].enumerated() {
            let from = netFromWater + (netAtGunwale - netFromWater) * q
            let fall = ((p * 3 + Double(k) / 3)).truncatingRemainder(dividingBy: 1)
            let drop = from + V(0, -from.y * fall + 3 * fall, 0)
            guard drop.y < 0 else { continue }
            d.svg.circle(space.at(drop), 0.7, fill: .colour(BoatInk.foam), stroke: .colour(Ink.line), width: 0.3, opacity: 1 - fall * 0.6)
        }
    }

    // MARK: Under sail

    /// The wake behind the smack under sail: short strokes spreading outward
    /// from the transom on either side, drifting back and fading.
    static func wake(_ d: inout Drawing, _ space: Space, _ frame: Int) {
        let p = Double(frame) / Double(SpriteKey.framesPerPose)
        for side in [-1.0, 1.0] {
            for k in 0..<3 {
                let age = (p + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                let back = -halfLength - 2 - 16 * age
                let spread = halfBeam(-halfLength) + 2 + 10 * age
                let a = space.at(back, 0, side * spread), b = space.at(back - 6, 0, side * (spread + 3))
                d.svg.line([a, b], stroke: .colour(BoatInk.foam), width: 1.3 - 0.6 * age, opacity: 0.8 * (1 - age))
            }
        }
        // The swirl the rudder leaves, spreading behind.
        let age = (p * 2).truncatingRemainder(dividingBy: 1)
        StoneBoatsWater.ring(&d.svg, at: space.at(-halfLength - 6 - 10 * age, 0, 0), rx: 3 + 5 * age, opacity: 0.7 * (1 - age),
                             width: 1, depth: 0.42)
    }

    /// The bow wave: foam curling back from the stem on either side, swelling
    /// and falling as she pitches, and spray thrown up now and then.
    static func bowWave(_ d: inout Drawing, _ space: Space, _ frame: Int) {
        let swell = 0.5 + 0.5 * sin(turn(frame) + 0.6)
        for side in [-1.0, 1.0] {
            let a = space.at(halfLength * 0.94, 0, side * 1.5)
            let m = space.at(halfLength * 0.72, -1.2 - 0.8 * swell, side * (halfBeam(halfLength * 0.72) + 2.6))
            let b = space.at(halfLength * 0.4, 0, side * (halfBeam(halfLength * 0.4) + 5 + 2 * swell))
            d.svg.path("M\(num(a.x)),\(num(a.y)) Q\(num(m.x)),\(num(m.y)) \(num(b.x)),\(num(b.y))",
                       stroke: .colour(BoatInk.foam), width: 1.6, opacity: 0.7 + 0.25 * swell)
        }
        let t = (Double(frame) / 6).truncatingRemainder(dividingBy: 1)
        StoneBoatsWater.splash(&d.svg, at: space.at(halfLength * 0.86, 0, halfBeam(halfLength * 0.86) + 1.4), t: t * 1.6, size: 0.7)
    }
}

/// The smack's colours: shades of the Alchemy age's palette (docs/art-style.md,
/// "Palettes"), kept from beside the team's colour where it is gilt or wine.
enum SmackInk {
    static let light = AlchemyPeopleInk.light
    /// The tarred oak of the hull, its shade, and the pale cap of the gunwale.
    static let hull = "#4d3424"
    static let hullShade = "#36251a"
    static let gunwaleCap = AlchemyPeopleInk.paleWood
    /// The bulwarks painted teal within, the deck, its seams, the hatch's coaming and the hold.
    static let bulwark = AlchemyPeopleInk.teal
    static let deck = "#b98d5a"
    static let deckSeam = AlchemyPeopleInk.wood
    static let coaming = AlchemyPeopleInk.wood
    static let holdDark = "#2a221d"
    /// The spars, oiled pine.
    static let spar = "#c0915a"
    /// The jib's undyed canvas, its shaded half, and its seams.
    static let canvas = AlchemyPeopleInk.light
    static let canvasShade = AlchemyPeopleInk.shadeLight
    static let canvasSeam = "#a8946e"
    /// The fisherman's teal gansey, its knitted pattern and ribbing; his wine cap and its rolled brim; his grey hair.
    static let gansey = AlchemyPeopleInk.teal
    static let ganseyPattern = AlchemyPeopleInk.paleTeal
    static let ganseyDark = AlchemyPeopleInk.darkTeal
    static let cap = AlchemyPeopleInk.wine
    static let capLight = AlchemyPeopleInk.paleWine
    static let greyHair = AlchemyPeopleInk.greyHair
    /// The net, its corks, and the rope.
    static let netDark = "#4a3a2c"
    static let mesh = "#c8a66e"
    static let cork = AlchemyOldBuildingsInk.clay
    static let rope = AlchemyOldBuildingsInk.straw
}
