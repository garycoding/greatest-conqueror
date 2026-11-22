// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The Iron age's boat, the fishing boat (ruled 2026-11-21): a small boat of
// planks, double-ended, its stem rising at the bow to a curl turned back and
// a lower sternpost aft. Its sheer strake is painted in the team's colour
// with a running wave in the light colour, a sea-green wale under it, an eye
// painted on each side of the bow, and its bottom tarred at the waterline.
// Inside: two thwarts, a coil of net in the bow, and a wicker basket of fish
// in the stern. Two oars work on iron thole pins. One person rows it,
// standing and facing the bow, pushing the oars as the fishermen of the
// Middle Sea did: a tunic of undyed wool with a red collar and the team's
// band across the chest, a sea-green felt cap (the pilos), dark curls and a
// short beard; nose E, the line.
//
// The hull lives in the dugout's space (`StoneDugout.Space`, `StoneDugout.V`):
// x along it toward the bow, y downward with the waterline at 0, z toward its
// right (starboard); a view turns it by its yaw, and a point nearer the
// viewer is drawn lower by the water's pitch. The rower is drawn with the
// figure kit in the same view, standing in the bilge so that only the body
// above the waist shows over the gunwale; the arms reach from the kit's
// shoulders to the hands, which live in the hull's space.
//
// An oar turns on its thole pin: its sweep (fore and aft) and its dip (the
// blade down) place the handle inboard and the blade outboard on either side
// of the pin, so the hands and the blades move opposite each other about it.
// Standing, the oars trail aft with their blades flat on the water, the boat
// rides the water, and the rower rests his hands together and breathes.
// Walking, he rows: the blades go in forward and square, he pushes the
// handles forward and leans into the stroke while the blades sweep aft
// through the water, then presses the handles down to lift the blades,
// feathers them and brings them forward through the air; the bow pushes a
// ripple and a wake spreads behind. Working, the oars trail and he casts a
// net on the right side: he gathers it, swings it back, throws it so that it
// opens into a disc in the air, lands with a ring of splashes, sinks, and is
// hauled back by its line, coming up dripping with a fish in it. Every cycle
// is periodic in its 12 frames. The origin is on the waterline at the middle
// of the hull; the boat casts no shadow.

enum IronFishingBoat {
    typealias Space = StoneDugout.Space
    typealias V = StoneDugout.V

    /// Room for the hull in every view, the oars' reach to either side, the rower and the cast net.
    static let canvas = Canvas(minX: -80, minY: -90, width: 160, height: 136, pixelsPerUnit: Canvas.person.pixelsPerUnit)

    /// The hull's half length and half beam at the gunwale.
    static let halfLength = 44.0, beam = 14.0
    /// Where the rower stands along the hull, and how far below the waterline
    /// his feet are (the figure's hips are below the gunwale).
    static let seat = -6.0, ground = 11.0
    /// Where the thole pins stand along the hull, and the oars' lengths inboard and outboard of them.
    static let tholeX = -1.5, inboard = 13.0, outboard = 40.0, blade = 13.0
    static let nose = Nose.line

    /// Whether the boat has the pose: it has no attack, so no fighting.
    static func drawn(_ pose: SpritePose) -> Bool { pose == .standing || pose == .walking || pose == .working }

    /// A frame of a pose in a view, as a sprite's picture and mask, grained alike, on `canvas` or another scale of it.
    static func render(_ pose: SpritePose, frame: Int, view: SpriteView = .side, canvas: Canvas = IronFishingBoat.canvas) -> Rendered? {
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

    /// The stroke's phase: the drive through the water (0 to π) lasts longer than the recovery through the air.
    static func stroke(_ frame: Int) -> Double {
        let t = turn(frame)
        return t - 0.36 * sin(t)
    }

    /// The oars' sweep in degrees (positive with the blades aft), their dip (positive with the blades down), and how square the blades are, in a frame.
    static func oarAngles(_ pose: SpritePose, _ frame: Int) -> (sweep: Double, dip: Double, square: Double) {
        // At rest the oars trail aft, their blades lying flat on the water and rocking on it.
        guard pose == .walking else { return (52, 22.5 + 0.8 * sin(turn(frame)), 0) }
        let s = stroke(frame)
        let sweep = 2.5 - 27.5 * cos(s)
        let dip = 19 + 12 * sin(s)
        // Square through the drive, feathered flat through the recovery, turning at either end.
        let square = 0.5 + 0.5 * tanh(3 * sin(s + 0.35))
        return (sweep, dip, square)
    }

    /// How far the boat rises on the water in a frame.
    static func bob(_ pose: SpritePose, _ frame: Int) -> Double {
        let t = turn(frame)
        switch pose {
        case .walking: return 0.5 * sin(2 * stroke(frame) + 0.6)
        case .working: return 0.6 * sin(t) + (frame == 4 || frame == 5 ? -0.4 : 0)
        default: return 0.7 * sin(t)
        }
    }

    /// The rower's lean in each frame of the cast: gathering, swinging back, throwing, and hauling.
    static let castLean: [Double] = [2, -2, -7, -10, 6, 16, 12, 8, 10, 6, 4, 0]

    /// The skeleton's state: the breath, the lean of the body and the face.
    static func rig(_ pose: SpritePose, _ frame: Int) -> Rig {
        var r = Rig()
        let t = turn(frame)
        switch pose {
        case .walking:
            let sweep = oarAngles(pose, frame).sweep
            r.lean = 5 + 12 * sin(sweep * .pi / 180) / sin(30 * .pi / 180)
            r.lift = 0.4 * sin(t)
            r.mouth = .firm
        case .working:
            r.lean = castLean[frame]
            r.headTilt = frame >= 7 ? 5 : 0
            r.eyes = frame >= 7 ? .down : (frame == 5 || frame == 6 ? .wide : .open)
            r.mouth = frame == 5 ? .open : .firm
        default:
            r.lean = 1
            r.lift = 0.8 * sin(t)
            r.eyes = frame == 8 ? .closed : .open
            r.mouth = .smile
        }
        return r
    }

    // MARK: The hull

    /// The half beam of the hull at `x`, at the gunwale.
    static func halfBeam(_ x: Double) -> Double {
        let f = min(abs(x) / halfLength, 1)
        return beam * max(0, 1 - pow(f, 2.3)).squareRoot()
    }

    /// The height of the gunwale at `x` (negative, above the water): a sheer rising toward the ends.
    static func gunwale(_ x: Double) -> Double { -(12 + 5 * pow(min(abs(x) / halfLength, 1), 3)) }

    /// Stations along the hull from the stern to the bow, closer toward the ends.
    static let stations: [Double] = (0...20).map { i in -halfLength * cos(Double(i) / 20 * .pi) }

    /// The gunwale all round: along the right side from the stern, back along the left.
    static func rim(_ space: Space, inset: Double = 1, lower: Double = 0) -> [P] {
        let right = stations.map { space.at($0, gunwale($0) + lower, halfBeam($0) * inset) }
        let left = stations.reversed().map { space.at($0, gunwale($0) + lower, -halfBeam($0) * inset) }
        return right + left.dropFirst().dropLast()
    }

    /// The waterline all round, short of the ends.
    static func waterline(_ space: Space) -> [P] {
        let xs = stations.filter { abs($0) < halfLength * 0.9 }
        let right = xs.map { space.at($0, 0, halfBeam($0) * 0.84) }
        let left = xs.reversed().map { space.at($0, 0, -halfBeam($0) * 0.84) }
        return right + left
    }

    /// Whether the outer side of the hull on `side` (+1 the right, -1 the left), turned a little toward `forward`, faces the viewer.
    static func faces(_ space: Space, side: Double, forward: Double = 0) -> Bool { space.depth(forward, side) > 0.05 }

    // MARK: Drawing

    static func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let space = Space(d.view, rise: bob(pose, frame))
        let line = Paint.colour(Ink.line)
        let rim = Self.rim(space), water = waterline(space)
        let hull = StoneDugout.outline(rim + water + [space.at(-halfLength * 0.97, -6, 0), space.at(halfLength * 0.98, -5, 0)])
        let nearRim = StoneDugout.nearChain(rim), nearWater = StoneDugout.nearChain(water)
        let angles = oarAngles(pose, frame)
        let oars = [-1.0, 1.0].map { IronOar(side: $0, sweep: angles.sweep, dip: angles.dip, square: angles.square) }
        let bowAhead = space.depth(halfLength, 0) >= 0

        // The water behind and about the boat.
        let ringCentre = space.at(0, 0, 0)
        let ringWidth = abs(halfLength * space.c) + abs(beam * space.s) + 6
        let ringDepth = max(0.12, StoneDugout.pitch * (abs(halfLength * space.s) + abs(beam * space.c) + 3) / ringWidth)
        StoneBoatsWater.ring(&d.svg, at: ringCentre, rx: ringWidth, opacity: 0.55, width: 1.1, arcs: [(190, 350)], depth: ringDepth)
        if pose == .walking { wake(&d, space, frame) }
        let cast = pose == .working ? IronCast(frame: frame) : nil
        // The net beyond the boat, in the air or the water, before the hull; the net on the near side after the rower.
        let netNear = cast?.near(space) ?? false
        if !netNear { cast?.drawNet(&d, space) }

        // The oars on the far side, outboard of their pins, and whichever end post lies beyond the hull.
        for oar in oars where !faces(space, side: oar.side) { oar.drawOutboard(&d, space) }
        if bowAhead { sternpost(&d, space) } else { stem(&d, space) }

        // The hull: its colour out of register, the hollow and what lies in it, the strakes, and the line over all.
        d.svg.polygon(hull.map { $0 + P(-0.9, 0.7) }, fill: .colour(IronBoatInk.hull))
        let wale = nearRim.map { $0 + P(0, 4.6) } + nearRim.reversed().map { $0 + P(0, 7.4) }
        d.svg.polygon(wale, fill: .colour(IronBoatInk.wale))
        d.svg.polygon(nearWater + nearWater.reversed().map { $0 + P(0, -3.6) }, fill: .colour(IronBoatInk.tar), opacity: 0.8)
        var seams = PathData()
        for k in [9.6, 12.2] {
            let row = nearRim.map { $0 + P(0, k) }
            for (i, p) in row.enumerated() { if i == 0 { seams.move(p) } else { seams.line(p) } }
        }
        d.svg.raw("<defs><clipPath id=\"iron-hull\"><polygon points=\"\(StoneDugout.polygon(hull))\"/></clipPath></defs>")
        d.svg.raw("<g clip-path=\"url(#iron-hull)\">")
        d.svg.path(seams, stroke: .colour(Ink.line), width: 0.5, opacity: 0.6)
        d.svg.raw("</g>")
        d.svg.polygon(rim, fill: .colour(IronBoatInk.inside))
        d.svg.raw("<defs><clipPath id=\"iron-hollow\"><polygon points=\"\(StoneDugout.polygon(rim))\"/></clipPath></defs>")
        d.svg.raw("<g clip-path=\"url(#iron-hollow)\">")
        d.svg.polygon(Self.rim(space, inset: 0.7, lower: 8), fill: .colour(IronBoatInk.bilge))
        ribs(&d, space)
        for x in [17.0, -27.0] { thwart(&d, space, at: x) }
        d.svg.raw("</g>")
        let band = nearRim.map { $0 + P(0, 1.1) } + nearRim.reversed().map { $0 + P(0, 4.6) }
        d.svg.polygon(band, fill: .team)
        var wave = PathData()
        let usable = nearRim.indices.filter { $0 > 1 && $0 < nearRim.count - 2 }
        for (k, i) in usable.enumerated() {
            let p = nearRim[i] + P(0, 2.9)
            if k == 0 { wave.move(p) } else { wave.quad((nearRim[usable[k - 1]] + P(0, 2.9) + p) * 0.5 + P(0, k % 2 == 0 ? 1.4 : -1.4), p) }
        }
        if usable.count > 1 { d.svg.path(wave, stroke: .colour(Ink.light), width: 0.8) }
        d.svg.line(nearRim.map { $0 + P(0, 4.6) }, stroke: line, width: 0.6)
        for side in [-1.0, 1.0] where faces(space, side: side, forward: 0.45) { eye(&d, space, side: side) }
        d.svg.polygon(hull, fill: .none, stroke: line, width: 1.5)
        d.svg.polygon(rim, fill: .none, stroke: line, width: 1.1)
        d.svg.line(nearRim.map { $0 + P(0, 0.8) }, stroke: .colour(IronBoatInk.gunwaleLight), width: 0.7)

        // What stands above the gunwale is clipped to it, so that the near side hides its foot.
        let left = nearRim.first!, right = nearRim.last!
        let above = [P(-200, left.y)] + nearRim + [P(200, right.y), P(200, -200), P(-200, -200)]
        d.svg.raw("<defs><clipPath id=\"iron-above-gunwale\"><polygon points=\"\(StoneDugout.polygon(above))\"/></clipPath></defs>")
        /// How far a point of the hull's space lies toward the viewer from the rower.
        func depthFromRower(_ v: V) -> Double { space.depth(v.x - seat, v.z) }
        // The net in the bow and the basket in the stern, behind or before the rower.
        let gear: [(V, (inout Drawing, Space) -> Void)] = [(V(24, 0, 0), netCoil), (V(-30, 0, 0), basket)]
        func drawGear(_ behind: Bool) {
            for (at, draw) in gear where (depthFromRower(at) < 0) == behind {
                d.svg.raw("<g clip-path=\"url(#iron-above-gunwale)\">")
                draw(&d, space)
                d.svg.raw("</g>")
            }
        }
        drawGear(true)
        for oar in oars { oar.drawPin(&d, space) }

        // The rower and his arms, and the oars inboard, each before or after him as it lies.
        let origin = space.at(seat, 0, 0) + P(0, ground)
        let lean = d.rig.lean * cos(d.yaw * .pi / 180)
        func placed(_ p: P) -> P { p.rotated(lean, about: Drawing.hips) + origin }
        let shoulders = [false, true].map { right in
            placed(d.project(0.5, -44 - d.rig.lift, right ? Drawing.shoulderSpread : -Drawing.shoulderSpread).point)
        }
        let handsV = hands(pose, frame, oars: oars, cast: cast)
        let hands = handsV.map { space.at($0) }
        let armBehind = [false, true].map { right -> Bool in
            let z = right ? Drawing.shoulderSpread : -Drawing.shoulderSpread
            return (space.depth(0.5, z) + depthFromRower(handsV[right ? 1 : 0])) / 2 < -2.5
        }
        let oarBehind = oars.map { depthFromRower(($0.handle + $0.thole) * 0.5) < -2 }
        for (i, oar) in oars.enumerated() where oarBehind[i] {
            if faces(space, side: oar.side) { oar.drawOutboard(&d, space) }
            oar.drawInboard(&d, space)
        }
        let castBehind = cast.map { depthFromRower($0.heldAt) < -3 } ?? false
        if castBehind { cast?.drawHeld(&d, space) }
        for right in [false, true] where armBehind[right ? 1 : 0] { StoneDugout.arm(&d, from: shoulders[right ? 1 : 0], to: hands[right ? 1 : 0]) }
        d.svg.raw("<g clip-path=\"url(#iron-above-gunwale)\"><g transform=\"translate(\(num(origin.x)),\(num(origin.y))) "
                  + "rotate(\(num(lean)) \(num(Drawing.hips.x)) \(num(Drawing.hips.y)))\">")
        rower(&d)
        d.svg.raw("</g></g>")
        for (i, oar) in oars.enumerated() where !oarBehind[i] {
            if faces(space, side: oar.side) { oar.drawOutboard(&d, space) }
            oar.drawInboard(&d, space)
        }
        if !castBehind { cast?.drawHeld(&d, space) }
        for right in [false, true] where !armBehind[right ? 1 : 0] { StoneDugout.arm(&d, from: shoulders[right ? 1 : 0], to: hands[right ? 1 : 0]) }
        drawGear(false)
        if bowAhead { stem(&d, space) } else { sternpost(&d, space) }
        if netNear { cast?.drawNet(&d, space) }

        // The water along the near side, and what the oars or the net stir.
        var foam = PathData()
        for (i, p) in nearWater.enumerated() {
            if i == 0 { foam.move(p) } else { foam.quad((nearWater[i - 1] + p) * 0.5 + P(0, 1.1), p) }
        }
        d.svg.path(foam, stroke: .colour(BoatInk.foam), width: 1.6)
        StoneBoatsWater.ring(&d.svg, at: ringCentre, rx: ringWidth, opacity: 0.75, width: 1.2, arcs: [(15, 165)], depth: ringDepth)
        switch pose {
        case .walking: for oar in oars { oar.drawWater(&d, space, frame: frame) }
        case .working: cast?.drawWater(&d, space)
        default:
            // Lapping at the hull as it rides the water.
            let age = Double(frame) / Double(SpriteKey.framesPerPose)
            StoneBoatsWater.ring(&d.svg, at: ringCentre, rx: ringWidth + 2 + 6 * age, opacity: 0.45 * (1 - age), width: 0.9,
                                 arcs: [(25, 155)], depth: ringDepth)
        }
    }

    /// Where the hands are in the hull's space: the left, then the right.
    static func hands(_ pose: SpritePose, _ frame: Int, oars: [IronOar], cast: IronCast?) -> [V] {
        switch pose {
        case .walking:
            return oars.map { $0.handle + $0.along * 1.6 }
        case .working:
            return cast!.hands
        default:
            // Resting together in front of him, rising with the breath.
            let lift = 0.6 * sin(turn(frame))
            return [V(seat + 7.5, -23 - lift, -2.6), V(seat + 8.5, -22.6 - lift, 2.4)]
        }
    }

    /// The ribs inside the hull, seen on its far side above the bilge.
    static func ribs(_ d: inout Drawing, _ space: Space) {
        var path = PathData()
        for x in stride(from: -halfLength + 9, through: halfLength - 9, by: 7.5) {
            for side in [-1.0, 1.0] {
                path.move(space.at(x, gunwale(x) + 0.6, side * halfBeam(x) * 0.97))
                path.line(space.at(x, gunwale(x) + 8, side * halfBeam(x) * 0.72))
            }
        }
        d.svg.path(path, stroke: .colour(IronBoatInk.rib), width: 1.1, opacity: 0.85)
    }

    /// A thwart across the hull at `x`, a little below the gunwale.
    static func thwart(_ d: inout Drawing, _ space: Space, at x: Double) {
        let y = gunwale(x) + 2.4, w = halfBeam(x) * 1.02
        let top = [space.at(x - 2.2, y, -w), space.at(x + 2.2, y, -w), space.at(x + 2.2, y, w), space.at(x - 2.2, y, w)]
        d.svg.polygon(top, fill: .colour(IronBoatInk.thwart), stroke: .colour(Ink.line), width: 0.8)
    }

    /// The painted eye on one side of the bow: a light almond rimmed in red, with a dark pupil, lying on the planks.
    static func eye(_ d: inout Drawing, _ space: Space, side: Double) {
        let x0 = halfLength * 0.76, y0 = gunwale(x0) + 7.4
        func on(_ dx: Double, _ dy: Double) -> P {
            let x = x0 + dx
            return space.at(x, y0 + dy, side * halfBeam(x) * (1 - 0.06 * (y0 + dy - gunwale(x)) / 8))
        }
        var almond = PathData()
        almond.move(on(-3.4, 0.4))
        almond.quad(on(0, -3.2), on(3.4, -0.4))
        almond.quad(on(0, 2.6), on(-3.4, 0.4))
        almond.close()
        d.svg.path(almond, fill: .colour(Ink.light), stroke: .colour(IronBoatInk.red), width: 0.9)
        d.svg.circle(on(0.4, -0.2), 1.2, fill: .colour(Ink.line))
    }

    /// The stem: from the forefoot up past the gunwale, curling back at its head.
    static func stem(_ d: inout Drawing, _ space: Space) {
        let h = halfLength
        let points = [V(h * 0.97, -4, 0), V(h + 1.6, -13, 0), V(h + 3.4, -22, 0), V(h + 3, -27, 0), V(h + 0.6, -29.4, 0),
                      V(h - 1.6, -28, 0), V(h - 1, -25.6, 0), V(h + 0.8, -25.8, 0)]
        post(&d, space, points)
    }

    /// The sternpost: a lower post rising a little above the gunwale at the stern.
    static func sternpost(_ d: inout Drawing, _ space: Space) {
        let h = halfLength
        post(&d, space, [V(-h * 0.97, -5, 0), V(-h - 1.4, -14, 0), V(-h - 2.4, -20.5, 0), V(-h - 1.4, -22.4, 0)])
    }

    private static func post(_ d: inout Drawing, _ space: Space, _ points: [V]) {
        let p = points.map(space.at)
        var path = PathData()
        path.move(p[0])
        for i in 1..<p.count { path.quad(p[i - 1] * 0.5 + p[i] * 0.5, p[i]) }
        d.svg.path(path, stroke: .colour(Ink.line), width: 3.4)
        d.svg.path(path, stroke: .colour(IronBoatInk.hull), width: 1.9)
    }

    /// The nets coiled in the bow: a heap of hemp, cork floats on it.
    static func netCoil(_ d: inout Drawing, _ space: Space) {
        let c = space.at(24, gunwale(24) + 4, 0)
        d.svg.ellipse(c + P(-0.6, 0.5), 6.6, 3.4, fill: .colour(IronBoatInk.hemp))
        var mesh = PathData()
        for k in [-4.0, -1.5, 1, 3.5] { mesh.move(c + P(k - 1.6, -2.6)); mesh.quad(c + P(k + 0.6, 0), c + P(k - 1, 2.6)) }
        d.svg.path(mesh, stroke: .colour(IronBoatInk.darkHemp), width: 0.6)
        d.svg.ellipse(c, 6.6, 3.4, fill: .none, stroke: .colour(Ink.line), width: 0.8)
        for f in [P(-3.6, -1.6), P(0.6, -2.8), P(3.8, -0.8)] {
            d.svg.ellipse(c + f, 1.2, 0.8, fill: .colour(IronBoatInk.cork), stroke: .colour(Ink.line), width: 0.5)
        }
    }

    /// A wicker basket in the stern, fish tails over its rim.
    static func basket(_ d: inout Drawing, _ space: Space) {
        let foot = space.at(-30, gunwale(-30) + 8.5, 0)
        d.svg.polygon([foot + P(-4.6, -7.4), foot + P(4.6, -7.4), foot + P(3.6, 0), foot + P(-3.6, 0)], fill: .colour(IronBoatInk.wicker),
                      stroke: .colour(Ink.line), width: 0.8)
        var weave = PathData()
        for v in [-2.4, -4.8] { weave.move(foot + P(-4.1, v)); weave.line(foot + P(4.1, v)) }
        d.svg.path(weave, stroke: .colour(IronBoatInk.darkHemp), width: 0.6)
        for (dx, lean) in [(-2.0, -0.6), (0.4, 0.2), (2.4, 0.5)] {
            let base = foot + P(dx, -7.6), tip = base + P(lean * 2.6, -3.4)
            d.svg.polygon([base + P(-0.6, 0), tip + P(-1.4, -0.4), tip + P(0, 0.6), tip + P(1.4, -0.4), base + P(0.6, 0)],
                          fill: .colour(BoatInk.fishBack), stroke: .colour(Ink.line), width: 0.5)
        }
        d.svg.ellipse(foot + P(0, -7.4), 4.6, 1.3, fill: .none, stroke: .colour(Ink.line), width: 0.7)
    }

    /// The wake behind a rowed boat: short strokes spreading outward from the
    /// stern on either side, drifting back and fading, and the ripple at the bow.
    static func wake(_ d: inout Drawing, _ space: Space, _ frame: Int) {
        let p = Double(frame) / Double(SpriteKey.framesPerPose)
        for side in [-1.0, 1.0] {
            for k in 0..<3 {
                let age = (p + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                let back = -halfLength * 0.8 - 2 - 18 * age
                let spread = beam * 0.7 + 12 * age
                let a = space.at(back, 0, side * spread), b = space.at(back - 7, 0, side * (spread + 3.5))
                d.svg.line([a, b], stroke: .colour(BoatInk.foam), width: 1.3 - 0.6 * age, opacity: 0.85 * (1 - age))
            }
        }
        // The ripple the bow pushes ahead of it, swelling with each stroke.
        let swell = 0.5 + 0.5 * sin(stroke(frame))
        for side in [-1.0, 1.0] {
            let a = space.at(halfLength * 0.88, 0, side * 2), b = space.at(halfLength * 0.6, 0, side * (beam + 1 + 2.5 * swell))
            d.svg.path("M\(num(a.x)),\(num(a.y)) Q\(num((a.x + b.x) / 2)),\(num((a.y + b.y) / 2 + 1)) \(num(b.x)),\(num(b.y))",
                       stroke: .colour(BoatInk.foam), width: 1.2, opacity: 0.6 + 0.3 * swell)
        }
    }

    // MARK: The rower

    /// The rower above the waist, in the figure's space: the tunic of undyed
    /// wool with its red collar, flecks, and the team's band across the chest,
    /// and the head with its cap, curls and beard.
    static func rower(_ d: inout Drawing) {
        d.garment(colour: [P(-11.5, -46), P(8.5, -48), P(11.5, -13), P(-13, -13)],
                  outline: [P(-8, -47), P(8, -47), P(10.8, -15), P(-11.8, -15)], fill: .colour(IronBoatInk.wool)) { d in
            var flecks = PathData()
            for (x, y) in [(-5.0, -42.5), (3.0, -43.0), (-8.0, -29.0), (5.5, -28.0), (-1.0, -26.0)] {
                let p = d.onBody(d.up(P(x, y)))
                flecks.move(p); flecks.line(p + P(1.2, 0.4))
            }
            d.svg.path(flecks, stroke: .colour(IronBoatInk.darkWool), width: 0.9)
            d.band([P(-11.6, -38), P(10.4, -39.4), P(10.7, -33.6), P(-12, -32.4)])
            d.band([P(-7.4, -47.6), P(7.4, -47.6), P(8, -44.6), P(-8.2, -44.4)], fill: .colour(IronBoatInk.red))
        }
        d.head(nose: nose, hair: { d in
            IronPeopleFarmer.curls(&d, colour: IronPeopleInk.hair, curl: IronPeopleInk.paleLeather)
        }, features: { d in
            beard(&d)
        }, brow: { d in
            d.svg.path("M1.4,-63.4 q3.4,-1.8 6.8,-0.4", stroke: .colour(Ink.line), width: 1.8)
        }, over: { d in
            pilos(&d)
        })
    }

    /// A short beard along the jaw, seen from the side, the front or a front quarter.
    static func beard(_ d: inout Drawing) {
        let fill = Paint.colour(IronPeopleInk.hair)
        switch d.view {
        case .side:
            d.svg.path("M-6.6,-53.6 C-5.6,-47.6 -1,-45 4.4,-45 C8.6,-45 11.4,-46.8 11.6,-49.6 C10,-48.2 7.6,-48.6 5.2,-49 "
                       + "C2,-49.4 -2.4,-50.4 -6.6,-53.6 Z", fill: fill)
        case .front:
            d.svg.path("M-8.4,-55.4 C-7.8,-48.2 -3.6,-45.2 0,-45.2 C3.6,-45.2 7.8,-48.2 8.4,-55.4 C5.4,-50.6 3,-49.6 0,-49.6 "
                       + "C-3,-49.6 -5.4,-50.6 -8.4,-55.4 Z", fill: fill)
        case .frontQuarter:
            d.svg.path("M-4.6,-55.2 C-3.6,-48.6 0.8,-45.4 5.2,-45.4 C8.8,-45.4 11.4,-47.4 11.8,-50.6 C9.6,-49.6 7.4,-49.6 5.2,-49.8 "
                       + "C1.8,-50.2 -1.4,-51.6 -4.6,-55.2 Z", fill: fill)
        case .back, .backQuarter:
            break
        }
    }

    /// The pilos: a conical cap of sea-green felt, its brim rolled in a darker band.
    static func pilos(_ d: inout Drawing) {
        let ahead = d.view == .front || d.view == .back
        BronzePeopleProps.shape(&d.svg, fill: .colour(IronBoatInk.felt), width: 1.5) { o in
            var p = PathData()
            if ahead {
                p.move(P(-11, -62.6) + o)
                p.cubic(P(-10.6, -70) + o, P(-4.6, -77.4) + o, P(0, -80.6) + o)
                p.cubic(P(4.6, -77.4) + o, P(10.6, -70) + o, P(11, -62.6) + o)
                p.cubic(P(4, -64.8) + o, P(-4, -64.8) + o, P(-11, -62.6) + o)
            } else {
                p.move(P(-10.8, -61.2) + o)
                p.cubic(P(-11, -68.6) + o, P(-6.6, -76.6) + o, P(-2.6, -80.4) + o)
                p.cubic(P(2.4, -77) + o, P(9, -71) + o, P(10.4, -64.4) + o)
                p.cubic(P(4, -66.6) + o, P(-4, -65.4) + o, P(-10.8, -61.2) + o)
            }
            p.close()
            return p
        }
        let brim = ahead ? "M11,-63.2 C4,-65.6 -4,-65.6 -11,-63.2" : "M10.2,-64.8 C4,-67.2 -4,-66 -10.8,-61.8"
        d.svg.path(brim, stroke: .colour(Ink.line), width: 3.4)
        d.svg.path(brim, stroke: .colour(IronBoatInk.feltDark), width: 1.8)
        // The felt's seam up the crown.
        let seam = ahead ? "M0,-65.4 L0,-79" : "M-1,-66 C-1.4,-71 -2,-76 -2.4,-79.4"
        d.svg.path(seam, stroke: .colour(IronBoatInk.feltDark), width: 0.8)
    }
}

// MARK: - The oars

/// One oar on its thole pin in a frame: the pin, the handle and the blade's
/// tip in the hull's space, and how square its blade is to the water.
struct IronOar {
    typealias V = StoneDugout.V
    typealias Space = StoneDugout.Space
    let side: Double
    let thole: V, handle: V, tip: V
    /// From the handle toward the blade.
    let along: V
    let square: Double

    init(side: Double, sweep: Double, dip: Double, square: Double) {
        typealias B = IronFishingBoat
        self.side = side; self.square = square
        let x = B.tholeX
        thole = V(x, B.gunwale(x) - 2.2, side * B.halfBeam(x))
        let s = sweep * .pi / 180, p = dip * .pi / 180
        along = V(-sin(s) * cos(p), sin(p), side * cos(s) * cos(p))
        handle = thole - along * B.inboard
        tip = thole + along * B.outboard
    }

    /// The breadth of the blade: flat on the water when feathered, upright when square.
    var across: V {
        let flat = V(-along.z, 0, along.x).unit
        let upright = V(along.y * flat.z - along.z * flat.y, along.z * flat.x - along.x * flat.z, along.x * flat.y - along.y * flat.x).unit
        return (flat * (1 - square) + upright * square).unit
    }

    /// The iron pin the oar turns on, and the rope grommet that holds the oar to it.
    func drawPin(_ d: inout Drawing, _ space: Space) {
        let foot = thole + V(0, 2.2, 0), top = thole + V(0, -2.4, 0)
        d.svg.line([space.at(foot), space.at(top)], stroke: .colour(Ink.line), width: 2.2)
        d.svg.line([space.at(foot), space.at(top)], stroke: .colour(IronBoatInk.iron), width: 1)
    }

    /// The oar inboard of its pin: the loom and the grip.
    func drawInboard(_ d: inout Drawing, _ space: Space) {
        let a = space.at(handle), b = space.at(thole)
        d.svg.line([a, b], stroke: .colour(Ink.line), width: 3.2)
        d.svg.line([a, b], stroke: .colour(IronBoatInk.oar), width: 1.8)
        d.svg.circle(a, 1.5, fill: .colour(IronBoatInk.oarDark), stroke: .colour(Ink.line), width: 0.8)
    }

    /// The oar outboard of its pin: the shaft and the blade, what lies under the water drawn faintly as if through it.
    func drawOutboard(_ d: inout Drawing, _ space: Space) {
        let neck = thole + along * (IronFishingBoat.outboard - IronFishingBoat.blade)
        let w = across
        let bladeShape = [neck + w * 0.9, neck + along * 3 + w * 2.6, tip + w * 2.4, tip + along * 0.8, tip - w * 2.4,
                          neck + along * 3 - w * 2.6, neck - w * 0.9]
        let shaft = IronCut.split([thole, neck], closed: false)
        let leaf = IronCut.split(bladeShape, closed: true)
        if shaft.below.count > 1 { d.svg.line(shaft.below.map(space.at), stroke: .colour(IronBoatInk.oarDark), width: 2, opacity: 0.35) }
        if leaf.below.count > 2 { d.svg.polygon(leaf.below.map(space.at), fill: .colour(IronBoatInk.oar), opacity: 0.35) }
        if shaft.above.count > 1 {
            let points = shaft.above.map(space.at)
            d.svg.line(points, stroke: .colour(Ink.line), width: 3)
            d.svg.line(points, stroke: .colour(IronBoatInk.oar), width: 1.6)
        }
        if leaf.above.count > 2 {
            let points = leaf.above.map(space.at)
            d.svg.polygon(points.map { $0 + P(-0.6, 0.5) }, fill: .colour(IronBoatInk.oar))
            d.svg.polygon(points, fill: .none, stroke: .colour(Ink.line), width: 1)
        }
    }

    /// What the blade stirs in the water in a frame of rowing: a ring and a
    /// curl of foam where it cuts the surface, and the puddles of the strokes
    /// falling behind the boat.
    func drawWater(_ d: inout Drawing, _ space: Space, frame: Int) {
        if tip.y > 0, thole.y < 0 {
            let k = -thole.y / (tip.y - thole.y)
            let entry = thole + (tip - thole) * k
            StoneBoatsWater.ring(&d.svg, at: space.at(entry), rx: 4.4, opacity: 0.85, width: 1, depth: 0.42)
            let back = space.at(entry + V(-5, 0, 0))
            d.svg.path("M\(num(space.at(entry).x)),\(num(space.at(entry).y)) Q\(num(back.x)),\(num(back.y - 1.6)) \(num(back.x - 2)),\(num(back.y))",
                       stroke: .colour(BoatInk.foam), width: 1.1, opacity: 0.8)
        }
        let p = Double(frame) / Double(SpriteKey.framesPerPose)
        for k in 0..<2 {
            let age = (p + 0.45 + Double(k) / 2).truncatingRemainder(dividingBy: 1)
            let at = space.at(IronFishingBoat.tholeX - 18 - 26 * age, 0, side * 36)
            StoneBoatsWater.ring(&d.svg, at: at, rx: 3 + 5 * age, opacity: 0.7 * (1 - age), width: 1, depth: 0.42)
        }
    }
}

/// Cutting a line or a shape of the hull's space at the water's surface.
enum IronCut {
    typealias V = StoneDugout.V

    /// The part above the water (y at most 0) and the part under it.
    static func split(_ points: [V], closed: Bool) -> (above: [V], below: [V]) {
        var above: [V] = [], below: [V] = []
        let count = closed ? points.count : points.count - 1
        for i in 0..<count {
            let a = points[i], b = points[(i + 1) % points.count]
            if a.y <= 0 { above.append(a) } else { below.append(a) }
            if (a.y <= 0) != (b.y <= 0) {
                let k = -a.y / (b.y - a.y)
                let cut = a + (b - a) * k
                above.append(cut); below.append(cut)
            }
        }
        if !closed, let last = points.last { if last.y <= 0 { above.append(last) } else { below.append(last) } }
        return (above, below)
    }
}

// MARK: - The cast net

/// The net cast on the right side in a frame of the working pose: gathered in
/// the hands, swung back, thrown open, landed, sunk and hauled up again.
struct IronCast {
    typealias V = StoneDugout.V
    typealias Space = StoneDugout.Space
    let frame: Int

    private static let seat = IronFishingBoat.seat

    /// The hands in each frame, the left and then the right.
    static let handFrames: [(V, V)] = [
        (V(seat + 6, -26, 3.5), V(seat + 7, -22, 8)),
        (V(seat + 4, -28, 2), V(seat + 4, -25, 7)),
        (V(seat + 0, -31, 0), V(seat - 1, -29.5, 5)),
        (V(seat - 3, -33, -1), V(seat - 4, -32.5, 3)),
        (V(seat + 5, -33, 6), V(seat + 6, -33, 10)),
        (V(seat + 11, -29, 9), V(seat + 13, -30, 13)),
        (V(seat + 9, -26, 6), V(seat + 11, -27, 11)),
        (V(seat + 8, -24, 5), V(seat + 10, -25, 10)),
        (V(seat + 8, -21, 6), V(seat + 9, -28, 9)),
        (V(seat + 8, -28, 5), V(seat + 9, -21, 9)),
        (V(seat + 8, -21, 6), V(seat + 9, -28, 9)),
        (V(seat + 7, -30, 5), V(seat + 8, -31, 9)),
    ]

    var hands: [V] { let h = Self.handFrames[frame]; return [h.0, h.1] }

    /// Where the gathered net hangs from, in the frames it is held.
    var heldAt: V { hands[1] }

    /// The net in the air or the water: its centre, radius, and how far its middle stands above its rim.
    private var spread: (centre: V, radius: Double, crown: Double)? {
        switch frame {
        case 4: return (V(Self.seat + 14, -36, 16), 6, 2.5)
        case 5: return (V(Self.seat + 19, -32, 26), 11, 3.6)
        case 6: return (V(Self.seat + 23, -19, 35), 16, 4)
        case 7: return (V(Self.seat + 24, 0, 38), 17, 2.4)
        case 8: return (V(Self.seat + 23, 5, 36), 15, 0)
        case 9: return (V(Self.seat + 20, 5, 30), 11, 0)
        case 10: return (V(Self.seat + 15, 4, 23), 6, 0)
        default: return nil
        }
    }

    /// The rim of the spread net: weighted points round its circle, nodding a little as it flies.
    private func rim(_ centre: V, _ radius: Double) -> [V] {
        (0..<14).map { k in
            let a = Double(k) / 14 * 2 * .pi
            return centre + V(radius * cos(a), 0.18 * radius * sin(3 * a + Double(frame)), radius * sin(a))
        }
    }

    /// Whether the net, spread in the air or the water, lies nearer the viewer than the rower.
    func near(_ space: Space) -> Bool {
        guard let (centre, _, _) = spread else { return false }
        return space.depth(centre.x - Self.seat, centre.z) > 0
    }

    /// The net and its line where it lies off the boat: in the air, on the water, or under it.
    func drawNet(_ d: inout Drawing, _ space: Space) {
        guard let (centre, radius, crown) = spread else { return }
        let rim = self.rim(centre, radius).map(space.at)
        let top = space.at(centre + V(0, -crown, 0))
        let under = centre.y > 0
        let opacity = under ? 0.36 : 0.72
        d.svg.polygon(StoneDugout.outline(rim), fill: .colour(IronBoatInk.hemp), opacity: opacity)
        var mesh = PathData()
        for p in rim { mesh.move(top); mesh.line(p) }
        let middle = self.rim(centre, radius * 0.55).map { space.at($0 + V(0, -crown * 0.45, 0)) }
        for (i, p) in middle.enumerated() { if i == 0 { mesh.move(p) } else { mesh.line(p) } }
        mesh.close()
        d.svg.path(mesh, stroke: .colour(under ? IronBoatInk.hemp : IronBoatInk.darkHemp), width: 0.6, opacity: under ? 0.6 : 0.9)
        var edge = PathData()
        for (i, p) in rim.enumerated() { if i == 0 { edge.move(p) } else { edge.line(p) } }
        edge.close()
        d.svg.path(edge, stroke: .colour(under ? IronBoatInk.hemp : Ink.line), width: under ? 0.7 : 0.8, opacity: under ? 0.6 : 1)
        if !under && centre.y < 0 {
            for p in rim { d.svg.circle(p, 0.9, fill: .colour(IronBoatInk.lead), stroke: .colour(Ink.line), width: 0.4) }
        }
        // The hand line from the right hand to the net's crown.
        let hand = space.at(hands[1])
        let entry = centre.y > 0 ? space.at(V(centre.x, 0, centre.z) * 0.7 + hands[1] * 0.3 + V(0, -hands[1].y * 0.3, 0)) : top
        var rope = PathData()
        rope.move(hand)
        rope.quad((hand + entry) * 0.5 + P(0, frame >= 8 ? 1 : 4), entry)
        if centre.y > 0 { rope.line(top) }
        d.svg.path(rope, stroke: .colour(IronBoatInk.darkHemp), width: 0.9)
    }

    /// The net gathered in the hands, or hauled up dripping with a fish in it, in the frames it is held.
    func drawHeld(_ d: inout Drawing, _ space: Space) {
        guard spread == nil || frame == 4 else { return }
        let top = space.at(heldAt) + P(0.6, 0.8)
        if frame == 4 {
            // Leaving the hands: the net's skirt flung open toward the throw.
            let tail = space.at(V(Self.seat + 12, -34, 14))
            d.svg.polygon([top, tail + P(-3, -2), tail + P(3, 2)], fill: .colour(IronBoatInk.hemp), stroke: .colour(Ink.line), width: 0.7,
                          opacity: 0.9)
            return
        }
        let swing: Double = [0, -0.4, -0.9, -1.2, 0, 0, 0, 0, 0, 0, 0, 0.5][frame]
        let length = frame == 11 ? 11.0 : 13.0
        let foot = top + P(swing * 5, length)
        let skirt = [top + P(-1.2, 0), top + P(1.2, 0), foot + P(4.2, 0), foot + P(2, 1.4), foot + P(-2, 1.4), foot + P(-4.2, 0)]
        d.svg.polygon(skirt, fill: .colour(IronBoatInk.hemp), opacity: 0.85)
        var mesh = PathData()
        for k in [-2.6, 0, 2.6] { mesh.move(top); mesh.line(foot + P(k, 1)) }
        mesh.move(top + (foot - top) * 0.5 + P(-2.4, 0)); mesh.line(top + (foot - top) * 0.5 + P(2.4, 0))
        d.svg.path(mesh, stroke: .colour(IronBoatInk.darkHemp), width: 0.6)
        d.svg.polygon(skirt, fill: .none, stroke: .colour(Ink.line), width: 0.8)
        for k in [-3.6, -1.2, 1.2, 3.6] { d.svg.circle(foot + P(k, 0.9), 0.85, fill: .colour(IronBoatInk.lead), stroke: .colour(Ink.line), width: 0.4) }
        if frame == 11 || frame == 0 {
            // The catch, flapping in the mesh.
            let c = top + (foot - top) * 0.62
            let flap = frame == 11 ? 1.0 : -0.6
            var fish = PathData()
            fish.move(c + P(-3.2, 0))
            fish.quad(c + P(0, -1.9), c + P(3, -0.2))
            fish.quad(c + P(0, 1.7), c + P(-3.2, 0))
            fish.close()
            d.svg.path(fish, fill: .colour(BoatInk.fishBack), stroke: .colour(Ink.line), width: 0.5)
            d.svg.polygon([c + P(-3, 0), c + P(-5.2, -1.6 * flap - 0.4), c + P(-5.2, 1.6 * flap + 0.4)], fill: .colour(BoatInk.fishBack),
                          stroke: .colour(Ink.line), width: 0.5)
        }
        if frame == 11 {
            for (k, dx) in [-2.6, 0.4, 3.0].enumerated() {
                d.svg.circle(foot + P(dx, 4 + Double(k % 2) * 3.4), 0.7, fill: .colour(BoatInk.foam), stroke: .colour(Ink.line), width: 0.3)
            }
        }
    }

    /// What the net stirs on the water: the splashes of its weights as it lands, the rings it leaves, and the line's ring as it is hauled.
    func drawWater(_ d: inout Drawing, _ space: Space) {
        let landing = V(Self.seat + 24, 0, 38)
        if frame == 7 || frame == 8 {
            for k in stride(from: 0, to: 14, by: 2) {
                let a = Double(k) / 14 * 2 * .pi
                let at = space.at(landing + V(17 * cos(a), 0, 17 * sin(a)))
                StoneBoatsWater.splash(&d.svg, at: at, t: frame == 7 ? 0.15 : 0.6, size: 0.55)
            }
        }
        let p = Double(frame) / Double(SpriteKey.framesPerPose)
        for lag in [0.0, 0.18] {
            let age = (p - 7.0 / 12 - lag + 2).truncatingRemainder(dividingBy: 1)
            StoneBoatsWater.ring(&d.svg, at: space.at(landing), rx: 17 + 12 * age, opacity: 0.75 * pow(1 - age, 1.6), width: 1, depth: 0.42)
        }
        if frame >= 8 && frame <= 10, let (centre, _, _) = spread {
            let at = space.at(V(centre.x, 0, centre.z) * 0.7 + hands[1] * 0.3 + V(0, -hands[1].y * 0.3, 0))
            StoneBoatsWater.ring(&d.svg, at: at, rx: 3.2, opacity: 0.85, width: 0.9, depth: 0.42)
        }
        if frame == 11 {
            StoneBoatsWater.ring(&d.svg, at: space.at(V(Self.seat + 12, 0, 20)), rx: 6, opacity: 0.7, width: 1, depth: 0.42)
        }
    }
}

/// The colours of the fishing boat and its rower: shades of the Iron age's
/// palette (docs/art-style.md, "Palettes": sea green, iron grey, legion red and the light).
enum IronBoatInk {
    /// The planks of the hull, its sea-green wale, and the tar along its waterline.
    static let hull = IronPeopleInk.wood
    static let wale = IronPeopleInk.sea
    static let tar = "#2f2723"
    static let gunwaleLight = IronPeopleInk.paleTimber
    /// Inside the hull: the planks' inner side, the bilge, the ribs and the thwarts.
    static let inside = IronPeopleInk.handle
    static let bilge = "#3b2d27"
    static let rib = IronPeopleInk.darkTimber
    static let thwart = IronPeopleInk.timber
    /// The oars, and their grips.
    static let oar = IronPeopleInk.paleTimber
    static let oarDark = IronPeopleInk.handle
    static let iron = IronPeopleInk.iron
    static let red = IronPeopleInk.red
    /// The nets: hemp, its shade, the cork floats and the lead weights.
    static let hemp = IronPeopleInk.hemp
    static let darkHemp = IronPeopleInk.darkHemp
    static let cork = IronPeopleInk.paleLeather
    static let lead = IronPeopleInk.ironDark
    static let wicker = IronPeopleInk.straw
    /// The rower's undyed wool, its flecks, and the sea-green felt of his cap.
    static let wool = IronPeopleInk.light
    static let darkWool = IronPeopleInk.darkGrey
    static let felt = IronPeopleInk.darkSea
    static let feltDark = IronPeopleInk.deepSea
}
