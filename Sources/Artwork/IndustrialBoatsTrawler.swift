// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The Industrial age's boat, the steam trawler (ruled 2026-11-21, plan D7): a
// small steel trawler with a black hull, a bottle-green boot top and a light
// rubbing strake; a deck of planks inside high bulwarks; a wheelhouse of
// varnished timber with its windows high under a light roof; a tall funnel of
// soot grey with a black top and a band of the team's colour between two rims
// of the light colour; a foremast with the team's pennant at its head and a
// mizzen aft; a steam winch forward of the wheelhouse; and the trawl's iron
// gallows on the starboard side, an otter board hung from the forward one. One
// crewman stands at the winch: a fisherman's jersey of soot grey ribbed across
// the yoke, a neckerchief of the team's colour, a knitted cap of bottle green
// with its brim turned up, and a ginger beard under the chin; nose C, the hook.
//
// The hull lives in the dugout's space (`StoneDugout.Space`): x along it
// toward the bow, y downward with the waterline at 0, z toward its starboard
// side, turned by the view's yaw and seen from the map's angle, so that the
// deck shows over the near bulwark and the waterline and the rings are
// ellipses. Everything on deck is placed in that space and drawn from the
// farthest to the nearest in each view, above the near bulwark. The crewman is
// drawn with the figure kit (`Drawing`) at `figure` of a person's size, so that
// the boat stays about a tile long; his arms reach from the kit's shoulders to
// the winch's lever, which lives in the hull's space, so that the hands meet it
// in every view.
//
// Standing, the trawler rides the water, a thin wisp rising from its funnel,
// and the crewman rests his hands on the lever and breathes; walking, it goes
// under steam: smoke pours from the funnel and streams aft, the bow pushes up
// a wave that runs along the hull and spreads, the screw churns the water at
// the stern and a wake spreads behind, the pennant streams, and the crewman
// sways with the boat; working, the trawler lies stopped and the crewman
// pumps the winch's lever: the drums turn, the warp runs in from the water over
// the gallows' block (dripping, with rings where it leaves the water), and the
// winch puffs steam with each stroke. Every cycle is periodic in its 12 frames.
// The origin is on the waterline at the middle of the hull; the boat casts no
// shadow.

enum IndustrialTrawler {
    typealias Space = StoneDugout.Space
    typealias V = StoneDugout.V

    /// Room for the hull in every view, the masts, the smoke streaming aft, the wake and the ring about it.
    static let canvas = Canvas(minX: -92, minY: -146, width: 184, height: 188, pixelsPerUnit: Canvas.person.pixelsPerUnit)

    /// The hull's half length, its half beam amidships, and the bulwarks' height above the deck.
    static let halfLength = 52.0, beam = 12.5, bulwark = 6.0
    /// The crewman's size against a person's, and where he stands along the deck.
    static let figure = 0.5, stand = -2.0
    static let nose = Nose.hook

    /// Whether the boat has the pose: it has no attack, so no fighting.
    static func drawn(_ pose: SpritePose) -> Bool { pose == .standing || pose == .walking || pose == .working }

    /// A frame of a pose in a view, as a sprite's picture and mask, grained alike, on `canvas` or another scale of it.
    static func render(_ pose: SpritePose, frame: Int, view: SpriteView = .side, canvas: Canvas = IndustrialTrawler.canvas) -> Rendered? {
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

    /// A frame's place in its cycle, from 0 up to 1.
    static func share(_ frame: Int) -> Double { Double(frame) / Double(SpriteKey.framesPerPose) }

    /// How far the boat rises on the water in a frame.
    static func bob(_ pose: SpritePose, _ frame: Int) -> Double {
        let t = turn(frame)
        switch pose {
        case .walking: return 0.7 * sin(2 * t)
        case .working: return 0.4 * sin(t)
        default: return 0.6 * sin(t)
        }
    }

    /// The winch's lever in a frame: its angle from upright, toward the bow; pumped while working.
    static func lever(_ pose: SpritePose, _ frame: Int) -> Double {
        pose == .working ? 22 * sin(turn(frame)) : -6
    }

    /// The skeleton's state: the breath, the lean of the body and the face.
    static func rig(_ pose: SpritePose, _ frame: Int) -> Rig {
        var r = Rig()
        let t = turn(frame)
        switch pose {
        case .walking:
            r.lean = 3 + 2.5 * sin(2 * t + 0.8)
            r.lift = 0.4 * sin(t)
            r.mouth = .firm
        case .working:
            r.lean = 6 + 10 * sin(t)
            r.headTilt = 4
            r.eyes = .down
            r.mouth = frame >= 2 && frame <= 4 ? .open : .firm
        default:
            r.lean = 2
            r.lift = 0.8 * sin(t)
            r.eyes = frame == 8 ? .closed : .open
        }
        return r
    }

    // MARK: The hull

    /// The hull's half breadth at `x`, at the bulwarks: fine at the bow, full at the stern.
    static func halfBeam(_ x: Double) -> Double {
        let f = min(abs(x) / halfLength, 1)
        return beam * max(0, 1 - pow(f, x >= 0 ? 2.3 : 4)).squareRoot()
    }

    /// The height of the bulwarks' top at `x` (negative, above the water): rising toward the bow.
    static func gunwale(_ x: Double) -> Double {
        let f = min(abs(x) / halfLength, 1)
        return -(13 + (x >= 0 ? 9 * f * f : 2.5 * f * f))
    }

    /// The deck's height at `x`.
    static func deck(_ x: Double) -> Double { gunwale(x) + bulwark }

    /// Stations along the hull from the stern to the bow, closer toward the ends.
    static let stations: [Double] = (0...24).map { i in -halfLength * cos(Double(i) / 24 * .pi) }

    /// The bulwarks' top all round (or a loop inside it, lower): along the starboard side from the stern, back along the port.
    static func rim(_ space: Space, inset: Double = 1, lower: Double = 0) -> [P] {
        let right = stations.map { space.at($0, gunwale($0) + lower, halfBeam($0) * inset) }
        let left = stations.reversed().map { space.at($0, gunwale($0) + lower, -halfBeam($0) * inset) }
        return right + left.dropFirst().dropLast()
    }

    /// The waterline all round, short of the stem's rake.
    static func waterline(_ space: Space) -> [P] {
        let xs = stations.filter { $0 < halfLength * 0.9 && $0 > -halfLength * 0.96 }
        let right = xs.map { space.at($0, 0, halfBeam($0) * 0.9) }
        let left = xs.reversed().map { space.at($0, 0, -halfBeam($0) * 0.9) }
        return right + left
    }

    // MARK: Drawing

    static func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        typealias I = IndustrialOldBuildingsInk
        let space = Space(d.view, rise: bob(pose, frame))
        let line = Paint.colour(Ink.line)
        let rim = Self.rim(space), water = waterline(space)
        let hull = StoneDugout.outline(rim + water + [space.at(halfLength * 0.9, 0, 0), space.at(-halfLength * 0.96, -2, 0)])
        let nearRim = StoneDugout.nearChain(rim), nearWater = StoneDugout.nearChain(water)

        // The water behind and about the boat.
        let ringCentre = space.at(0, 0, 0)
        let ringWidth = abs(halfLength * space.c) + abs(beam * space.s) + 7
        let ringDepth = max(0.12, StoneDugout.pitch * (abs(halfLength * space.s) + abs(beam * space.c) + 4) / ringWidth)
        StoneBoatsWater.ring(&d.svg, at: ringCentre, rx: ringWidth, opacity: 0.55, width: 1.1, arcs: [(190, 350)], depth: ringDepth)
        if pose == .walking { wake(&d, space, frame) }

        // The hull: its black side out of register, the boot top along the water, the bulwarks' inside and the deck.
        d.svg.polygon(hull.map { $0 + P(-0.9, 0.7) }, fill: .colour(IndustrialPeopleInk.black))
        d.svg.polygon(nearWater + nearWater.reversed().map { $0 + P(0, -2.8) }, fill: .colour(I.green))
        d.svg.polygon(rim, fill: .colour(IndustrialPeopleInk.shadeLight))
        d.svg.raw("<defs><clipPath id=\"trawler-deck\"><polygon points=\"\(StoneDugout.polygon(rim))\"/></clipPath></defs>")
        d.svg.raw("<g clip-path=\"url(#trawler-deck)\">")
        let deckLoop = Self.rim(space, inset: 0.92, lower: bulwark)
        d.svg.polygon(deckLoop, fill: .colour(IndustrialPeopleInk.paleWood))
        for k in [-0.6, -0.2, 0.2, 0.6] {
            let seam = stations.filter { abs($0) < halfLength * 0.9 }.map { space.at($0, deck($0), halfBeam($0) * k * 0.92) }
            d.svg.line(seam, stroke: .colour(IndustrialPeopleInk.wood), width: 0.5, opacity: 0.6)
        }
        d.svg.raw("</g>")
        // The hull's plating seams and portholes along the near side, under the rubbing strake.
        let usable = nearRim.indices.filter { $0 > 2 && $0 < nearRim.count - 3 }
        for i in usable where i % 4 == 2 {
            let top = nearRim[i] + P(0, 3), foot = nearWater.min { abs($0.x - top.x) < abs($1.x - top.x) } ?? top
            if foot.y - top.y > 4 { d.svg.line([top, foot + P(0, -3)], stroke: .colour(IndustrialPeopleInk.blackSheen), width: 0.5, opacity: 0.8) }
        }
        d.svg.polygon(hull, fill: .none, stroke: line, width: 1.5)
        d.svg.polygon(rim, fill: .none, stroke: line, width: 1.1)
        d.svg.line(nearRim.map { $0 + P(0, 2.6) }, stroke: .colour(Ink.line), width: 1.7)
        d.svg.line(nearRim.map { $0 + P(0, 2.6) }, stroke: .colour(IndustrialPeopleInk.light), width: 0.9)
        portholes(&d, space)

        // Everything on deck, above the near bulwark, from the farthest to the nearest.
        let left = nearRim.first!, right = nearRim.last!
        let above = [P(-400, left.y)] + nearRim + [P(400, right.y), P(400, -400), P(-400, -400)]
        d.svg.raw("<defs><clipPath id=\"trawler-above\"><polygon points=\"\(StoneDugout.polygon(above))\"/></clipPath></defs>")
        d.svg.raw("<g clip-path=\"url(#trawler-above)\">")
        let parts: [(depth: Double, draw: (inout Drawing) -> Void)] = [
            (space.depth(-15, 0), { wheelhouse(&$0, space) }),
            (space.depth(-33, 0), { funnel(&$0, space) }),
            (space.depth(28, 0), { foremast(&$0, space, pose, frame) }),
            (space.depth(-44, 0), { mizzen(&$0, space) }),
            (space.depth(10.5, 0), { winch(&$0, space, pose, frame) }),
            (space.depth(stand, 0), { crewman(&$0, space, pose, frame) }),
            (space.depth(18, halfBeam(18)), { gallows(&$0, space, at: 18, pose: pose, frame: frame, board: pose != .working) }),
            (space.depth(-26, halfBeam(-26)), { gallows(&$0, space, at: -26, pose: pose, frame: frame, board: true) }),
        ]
        // Parts at the same depth keep the order listed (from the side, the masts, the winch and the crewman all stand on the middle line).
        let order = parts.indices.sorted { parts[$0].depth == parts[$1].depth ? $0 < $1 : parts[$0].depth < parts[$1].depth }
        for i in order { parts[i].draw(&d) }
        d.svg.raw("</g>")
        stays(&d, space)

        // The water along the near side, what the bow, the screw or the warp stirs, and the smoke over all.
        var foam = PathData()
        for (i, p) in nearWater.enumerated() {
            if i == 0 { foam.move(p) } else { foam.quad((nearWater[i - 1] + p) * 0.5 + P(0, 1.1), p) }
        }
        d.svg.path(foam, stroke: .colour(BoatInk.foam), width: 1.6)
        StoneBoatsWater.ring(&d.svg, at: ringCentre, rx: ringWidth, opacity: 0.75, width: 1.2, arcs: [(15, 165)], depth: ringDepth)
        switch pose {
        case .walking: bowWave(&d, space, frame)
        case .working: warp(&d, space, frame)
        default:
            // Lapping at the hull as it rides the water.
            let age = share(frame)
            StoneBoatsWater.ring(&d.svg, at: ringCentre, rx: ringWidth + 2 + 6 * age, opacity: 0.45 * (1 - age), width: 0.9,
                                 arcs: [(25, 155)], depth: ringDepth)
        }
        smoke(&d, space, pose, frame)
        if pose == .working { winchSteam(&d, space, frame) }
    }

    // MARK: Boxes in the hull's space

    /// A face of a box in the hull's space: a corner and its two edges, so that
    /// a point on it is given as fractions along them.
    struct Face {
        let corner: V, along: V, up: V
        func at(_ u: Double, _ v: Double) -> V { corner + along * u + up * v }
    }

    /// The faces of a box from (x0, z0) to (x1, z1), from `bottom` up to `top`
    /// (both negative), that turn toward the viewer, each with its shade: 0 for
    /// the side facing starboard, 1 for the front, 2 for the back, 3 for port.
    static func faces(_ space: Space, x0: Double, x1: Double, z0: Double, z1: Double, bottom: Double, top: Double) -> [(Face, Int)] {
        let h = top - bottom
        var out: [(Face, Int)] = []
        // The face toward the bow (+x) shows when the view looks on it, and so on round.
        if space.s > 0.01 { out.append((Face(corner: V(x1, bottom, z1), along: V(0, 0, z0 - z1), up: V(0, h, 0)), 1)) }
        if space.s < -0.01 { out.append((Face(corner: V(x0, bottom, z0), along: V(0, 0, z1 - z0), up: V(0, h, 0)), 2)) }
        if space.c > 0.01 { out.append((Face(corner: V(x0, bottom, z1), along: V(x1 - x0, 0, 0), up: V(0, h, 0)), 0)) }
        if space.c < -0.01 { out.append((Face(corner: V(x1, bottom, z0), along: V(x0 - x1, 0, 0), up: V(0, h, 0)), 3)) }
        return out
    }

    /// A quadrilateral on a face, from (u0, v0) to (u1, v1) in fractions of it, on the screen.
    static func panel(_ space: Space, _ f: Face, _ u0: Double, _ v0: Double, _ u1: Double, _ v1: Double) -> [P] {
        [f.at(u0, v0), f.at(u1, v0), f.at(u1, v1), f.at(u0, v1)].map(space.at)
    }

    /// A box's top, at `top`, on the screen.
    static func lid(_ space: Space, x0: Double, x1: Double, z0: Double, z1: Double, at top: Double) -> [P] {
        [V(x0, top, z0), V(x1, top, z0), V(x1, top, z1), V(x0, top, z1)].map(space.at)
    }

    /// A shape in its colour a little out of register, with the line over it.
    static func shape(_ d: inout Drawing, _ points: [P], _ fill: Paint, width: Double = 1, opacity: Double = 1) {
        d.svg.polygon(points.map { $0 + P(-0.6, 0.5) }, fill: fill, opacity: opacity)
        d.svg.polygon(points, fill: .none, stroke: .colour(Ink.line), width: width)
    }

    // MARK: The wheelhouse

    /// The wheelhouse: varnished timber on a deckhouse, its windows high on
    /// every side in frames of the light colour, a door on each side, and a
    /// light roof overhanging it.
    static func wheelhouse(_ d: inout Drawing, _ space: Space) {
        typealias K = IndustrialPeopleInk
        typealias I = IndustrialOldBuildingsInk
        let (x0, x1, z0, z1) = (-24.0, -6.0, -7.4, 7.4)
        let bottom = deck(-15) + 1, top = -50.0
        let shades = [K.wood, K.paleWood, K.darkWood, K.darkWood]
        for (face, shade) in faces(space, x0: x0, x1: x1, z0: z0, z1: z1, bottom: bottom, top: top) {
            shape(&d, panel(space, face, 0, 0, 1, 1), .colour(shades[shade]), width: 1.1)
            // The planking's seams, the windows high up, and a door on the sides.
            for v in stride(from: 0.12, to: 0.6, by: 0.12) {
                d.svg.line([space.at(face.at(0.02, v)), space.at(face.at(0.98, v))], stroke: .colour(Ink.line), width: 0.4, opacity: 0.35)
            }
            let count = shade == 0 || shade == 3 ? 3 : 2
            for k in 0..<count {
                let w = 0.86 / Double(count), u = 0.07 + Double(k) * w
                shape(&d, panel(space, face, u, 0.66, u + w - 0.06, 0.92), .colour(K.light), width: 0.6)
                d.svg.polygon(panel(space, face, u + 0.035, 0.69, u + w - 0.095, 0.89), fill: .colour(I.glass))
                d.svg.polygon([face.at(u + 0.035, 0.69), face.at(u + 0.035 + (w - 0.13) * 0.5, 0.89), face.at(u + 0.035, 0.89)].map(space.at),
                              fill: .colour(I.glassLight), opacity: 0.7)
            }
            if shade == 0 || shade == 3 {
                shape(&d, panel(space, face, 0.72, 0.02, 0.92, 0.56), .colour(K.darkWood), width: 0.7)
                d.svg.circle(space.at(face.at(0.75, 0.3)), 0.6, fill: .colour(K.brass))
            }
        }
        // The roof, overhanging, its edge in the light colour.
        let roof = lid(space, x0: x0 - 1.4, x1: x1 + 1.6, z0: z0 - 1, z1: z1 + 1, at: top - 1.6)
        for (face, _) in faces(space, x0: x0 - 1.4, x1: x1 + 1.6, z0: z0 - 1, z1: z1 + 1, bottom: top, top: top - 1.6) {
            shape(&d, panel(space, face, 0, 0, 1, 1), .colour(K.shadeLight), width: 0.7)
        }
        shape(&d, roof, .colour(K.light), width: 0.9)
        // A brass whistle and a lamp on the roof.
        let whistle = space.at(-12, top - 1.6, 2)
        d.svg.line([whistle, whistle + P(0, -4)], stroke: .colour(Ink.line), width: 1.4)
        d.svg.polygon([whistle + P(-1, -3.6), whistle + P(1, -3.6), whistle + P(0.8, -6.4), whistle + P(-0.8, -6.4)], fill: .colour(K.brass),
                      stroke: .colour(Ink.line), width: 0.5)
    }

    // MARK: The funnel

    /// The funnel: a tall cylinder raked aft, soot grey with a black top and a
    /// band of the team's colour between two rims of the light colour, its
    /// mouth dark, and a steam pipe up its after side.
    static func funnel(_ d: inout Drawing, _ space: Space) {
        typealias K = IndustrialPeopleInk
        let base = V(-31, deck(-31) + 1, 0), top = V(-35, -74, 0), r = 4.6
        /// A point on the funnel's side at height `y`, `a` degrees round from the bow.
        func on(_ y: Double, _ a: Double) -> P {
            let t = (y - base.y) / (top.y - base.y)
            let c = base + (top - base) * t
            return space.at(c.x + r * cos(a * .pi / 180), y, r * sin(a * .pi / 180))
        }
        /// The half round of the side nearer the viewer, at `y`, from its left edge to its right on the screen.
        func near(_ y: Double) -> [P] {
            let facing = atan2(space.c, space.s) * 180 / .pi
            return stride(from: facing + 90, through: facing - 90, by: -15).map { on(y, $0) }.sorted { $0.x < $1.x }
        }
        func band(_ y0: Double, _ y1: Double, _ fill: Paint) {
            d.svg.polygon(near(y0) + near(y1).reversed(), fill: fill)
        }
        let body = near(base.y) + near(top.y).reversed()
        d.svg.polygon(body.map { $0 + P(-0.6, 0.5) }, fill: .colour(K.soot))
        // The shade down its far side, the light down its near edge.
        let lit = near(base.y), high = near(top.y)
        d.svg.polygon([lit[lit.count - 3], lit.last!, high.last!, high[high.count - 3]], fill: .colour(K.darkSoot), opacity: 0.7)
        d.svg.line([lit[2], high[2]], stroke: .colour(K.paleSoot), width: 1)
        band(-53, -54.6, .colour(K.light))
        band(-54.6, -61.4, .team)
        band(-61.4, -63, .colour(K.light))
        band(-68, top.y, .colour(K.coal))
        for y in [-53.0, -54.6, -61.4, -63, -68] { d.svg.line(near(y), stroke: .colour(Ink.line), width: 0.6) }
        d.svg.polygon(body, fill: .none, stroke: .colour(Ink.line), width: 1.1)
        // The mouth, and its lip.
        let mouth = stride(from: 0.0, to: 360, by: 20).map { on(top.y, $0) }
        d.svg.polygon(mouth, fill: .colour(K.coal), stroke: .colour(Ink.line), width: 0.9)
        let centre = space.at(top)
        d.svg.polygon(mouth.map { centre + ($0 - centre) * 0.68 + P(0, 0.4) }, fill: .colour(IndustrialPeopleInk.black), opacity: 0.8)
        // The steam pipe up its after side, ending in a short flared mouth above the top.
        let pipeFoot = space.at(base.x - r - 1, base.y, 0), pipeTop = space.at(top.x - r - 1.2, top.y - 2, 0)
        d.svg.line([pipeFoot, pipeTop], stroke: .colour(Ink.line), width: 1.8)
        d.svg.line([pipeFoot, pipeTop], stroke: .colour(K.paleBrass), width: 0.7)
    }

    // MARK: The masts

    /// The foremast with a crosstree near its head and the team's pennant at it,
    /// streaming aft under steam and stirring when the boat lies still.
    static func foremast(_ d: inout Drawing, _ space: Space, _ pose: SpritePose, _ frame: Int) {
        let foot = V(28, deck(28), 0), head = V(27, -86, 0)
        mast(&d, space, foot: foot, head: head, width: 1.8)
        let tree = V(27.2, -70, 0)
        d.svg.line([space.at(tree + V(0, 0, -4)), space.at(tree + V(0, 0, 4))], stroke: .colour(Ink.line), width: 1.6)
        d.svg.line([space.at(tree + V(0, 0, -4)), space.at(tree + V(0, 0, 4))], stroke: .colour(IndustrialPeopleInk.paleWood), width: 0.6)
        pennant(&d, space, at: head, pose: pose, frame: frame)
    }

    /// The mizzen near the stern, bare.
    static func mizzen(_ d: inout Drawing, _ space: Space) {
        mast(&d, space, foot: V(-44, deck(-44), 0), head: V(-45, -64, 0), width: 1.5)
    }

    static func mast(_ d: inout Drawing, _ space: Space, foot: V, head: V, width: Double) {
        let a = space.at(foot), b = space.at(head)
        d.svg.line([a, b], stroke: .colour(Ink.line), width: width + 1.2)
        d.svg.line([a, b], stroke: .colour(IndustrialPeopleInk.wood), width: width)
        d.svg.line([a + P(-0.3, 0), b + P(-0.3, 0)], stroke: .colour(IndustrialPeopleInk.paleWood), width: width * 0.3)
        d.svg.circle(b, width * 0.75, fill: .colour(IndustrialPeopleInk.paleWood), stroke: .colour(Ink.line), width: 0.5)
    }

    /// The stays: from the foremast's head to the stem and over the funnel to the mizzen's head.
    static func stays(_ d: inout Drawing, _ space: Space) {
        let fore = space.at(27, -84, 0), mizzen = space.at(-45, -62, 0), stem = space.at(halfLength, gunwale(halfLength), 0)
        for (a, b) in [(fore, stem), (fore, mizzen), (mizzen, space.at(-halfLength * 0.96, gunwale(-halfLength), 0))] {
            d.svg.line([a, b], stroke: .colour(Ink.line), width: 0.6, opacity: 0.8)
        }
    }

    /// A swallow-tailed pennant of the team's colour edged in the light colour,
    /// flying aft from the masthead: it streams and ripples under steam, and
    /// hangs and stirs otherwise.
    static func pennant(_ d: inout Drawing, _ space: Space, at head: V, pose: SpritePose, frame: Int) {
        let t = turn(frame)
        let streaming = pose == .walking
        let length = streaming ? 15.0 : 11.0
        let droop = streaming ? 1.0 : 4.0
        /// A point along the pennant, `u` from the mast toward its tails, `w` across it.
        func at(_ u: Double, _ w: Double) -> P {
            let wave = (streaming ? 1.3 : 0.8) * sin(t * (streaming ? 2 : 1) - u * 0.45) * u / length
            let base = space.at(head.x - u, head.y + 1.5 + w + droop * u / length + wave, 0)
            return base
        }
        let us = stride(from: 0.0, through: length, by: length / 6).map { $0 }
        let top = us.map { at($0, 0) }, bottom = us.map { at($0, 5 - 2 * $0 / length) }
        let tailNotch = at(length * 0.78, 2.2)
        let cloth = top + [tailNotch] + bottom.reversed()
        d.svg.polygon(cloth, fill: .none, stroke: .colour(IndustrialPeopleInk.light), width: 2.4)
        d.svg.polygon(cloth.map { $0 + P(-0.4, 0.3) }, fill: .team)
        d.svg.polygon(cloth, fill: .none, stroke: .colour(Ink.line), width: 0.6)
    }

    // MARK: The winch

    /// The drums' centre, their radius, and how far across the deck they run.
    static let drum = V(10.5, deck(10.5) - 5, 0), drumRadius = 3.2, drumHalf = 5.0
    /// The warping end on the starboard side of the winch, where the warp is wound.
    static let warpingEnd = V(10.5, deck(10.5) - 5, 7.6)
    /// The lever's pivot and its length.
    static let pivot = V(4.6, deck(4.6) - 3, 0), leverLength = 13.0

    /// The lever's grip in a frame.
    static func grip(_ pose: SpritePose, _ frame: Int) -> V {
        let a = lever(pose, frame) * .pi / 180
        return pivot + V(sin(a) * leverLength, -cos(a) * leverLength, 0)
    }

    /// The steam winch: two iron side frames, the drum between them wound
    /// with warp, a warping end outboard on the starboard side, its spokes
    /// turning while the warp is hauled, and the lever.
    static func winch(_ d: inout Drawing, _ space: Space, _ pose: SpritePose, _ frame: Int) {
        typealias K = IndustrialPeopleInk
        let spin = pose == .working ? share(frame) * 360 / 3 : 0
        /// A disc across the deck (its axis along z) at `z`, as points on the screen.
        func disc(_ c: V, _ r: Double, _ z: Double) -> [P] {
            stride(from: 0.0, to: 360, by: 20).map { a in space.at(c.x + r * cos(a * .pi / 180), c.y + r * sin(a * .pi / 180), z) }
        }
        /// A drum from `z0` to `z1`: its two ends and the barrel between, the warp wound round it.
        func barrel(_ c: V, _ r: Double, _ z0: Double, _ z1: Double, fill: String, wound: Bool) {
            let near = space.depth(0, z1) > space.depth(0, z0) ? z1 : z0, far = near == z1 ? z0 : z1
            let ends = disc(c, r, far) + disc(c, r, near)
            let body = StoneDugout.outline(ends)
            shape(&d, body, .colour(fill), width: 0.8)
            if wound {
                for k in 1..<5 {
                    let z = z0 + (z1 - z0) * Double(k) / 5
                    d.svg.polygon(disc(c, r, z), fill: .none, stroke: .colour(K.paleWood), width: 0.5, opacity: 0.8)
                }
            }
            let face = disc(c, r, near)
            d.svg.polygon(face, fill: .colour(K.ironDark), stroke: .colour(Ink.line), width: 0.7)
            // The spokes on the nearer end, turning.
            for k in 0..<3 {
                let a = (spin + Double(k) * 120) * .pi / 180
                d.svg.line([space.at(c.x, c.y, near), space.at(c.x + r * 0.85 * cos(a), c.y + r * 0.85 * sin(a), near)],
                           stroke: .colour(K.ironLight), width: 0.7)
            }
            d.svg.circle(space.at(c.x, c.y, near), 0.7, fill: .colour(K.ironLight))
        }
        // The side frames.
        for z in [-drumHalf - 0.6, drumHalf + 0.6] {
            let frame = [V(7.5, deck(7.5), z), V(13.5, deck(13.5), z), V(12.1, drum.y - 4, z), V(8.9, drum.y - 4, z)].map(space.at)
            shape(&d, frame, .colour(K.iron), width: 0.8)
        }
        barrel(drum, drumRadius, -drumHalf, drumHalf, fill: K.wood, wound: true)
        barrel(warpingEnd, 2.2, drumHalf + 0.8, drumHalf + 3.6, fill: K.iron, wound: false)
        // The steam cylinder's exhaust pipe at the back of the winch.
        let pipe = V(13.4, deck(13.4), -3.6)
        d.svg.line([space.at(pipe), space.at(pipe + V(0, -11, 0))], stroke: .colour(Ink.line), width: 1.7)
        d.svg.line([space.at(pipe), space.at(pipe + V(0, -11, 0))], stroke: .colour(K.iron), width: 0.8)
        // The lever, from its pivot at the frame to the grip.
        let g = grip(pose, frame)
        d.svg.line([space.at(pivot), space.at(g)], stroke: .colour(Ink.line), width: 2)
        d.svg.line([space.at(pivot), space.at(g)], stroke: .colour(K.ironLight), width: 0.8)
        d.svg.line([space.at(g + V(0, 0, -2)), space.at(g + V(0, 0, 2))], stroke: .colour(Ink.line), width: 1.8)
        d.svg.circle(space.at(pivot), 1, fill: .colour(K.iron), stroke: .colour(Ink.line), width: 0.5)
    }

    /// Puffs of steam from the winch's exhaust with each stroke of the lever, rising and fading.
    static func winchSteam(_ d: inout Drawing, _ space: Space, _ frame: Int) {
        let p = share(frame)
        for k in 0..<2 {
            let age = (p + Double(k) / 2).truncatingRemainder(dividingBy: 1)
            let at = space.at(13.4 - 3 * age, deck(13.4) - 12 - 12 * age, -3.6)
            IndustrialWarriorsKit.smoke(&d.svg, at: at, puffs: [(P(0, 0), 1.4 + 3 * age), (P(1.6 + 2 * age, 0.6), 1 + 2 * age)],
                                        opacity: 0.9 * pow(1 - age, 1.3), colour: IndustrialPeopleInk.steam)
        }
    }

    // MARK: The gallows and the warp

    /// The top of the gallows at `x`, where its block hangs, outboard of the bulwark.
    static func block(_ x: Double) -> V { V(x + 1, gunwale(x) - 12, halfBeam(x) + 2.4) }

    /// The trawl's gallows on the starboard side at `x`: an arch of iron on the
    /// bulwark, bent outboard, with its block; with `board`, the otter board
    /// hung from it against the hull.
    static func gallows(_ d: inout Drawing, _ space: Space, at x: Double, pose: SpritePose, frame: Int, board: Bool) {
        typealias K = IndustrialPeopleInk
        let z = halfBeam(x) - 0.4, rail = gunwale(x)
        let top = block(x)
        let legs = [V(x - 2.4, rail, z), V(x + 3.6, rail, z)]
        let bend = [V(x - 2.4, rail - 9, z + 0.6), V(x + 3.6, rail - 10, z + 0.6)]
        for (a, b) in zip(legs, bend) {
            let path = [space.at(a), space.at(b), space.at(top)]
            d.svg.line(path, stroke: .colour(Ink.line), width: 2.4)
            d.svg.line(path, stroke: .colour(K.iron), width: 1.2)
        }
        d.svg.circle(space.at(top + V(0, 1.4, 0)), 1.3, fill: .colour(K.ironDark), stroke: .colour(Ink.line), width: 0.6)
        guard board else { return }
        // The otter board: a heavy rectangle of planks bound in iron, hung by a chain, its foot on the rail.
        let sway = 0.4 * sin(turn(frame) + x)
        let hang = top + V(0, 2.6, 0.4)
        let b0 = V(x - 4 + sway, rail - 1.6, z + 2), b1 = V(x + 5 + sway, rail - 1.2, z + 2.2)
        let face = [b0, b1, b1 + V(0, -7.4, 0.2), b0 + V(0, -7.4, 0.2)].map(space.at)
        d.svg.line([space.at(hang), space.at((b0 + b1) * 0.5 + V(0, -7.4, 0.2))], stroke: .colour(Ink.line), width: 0.8)
        shape(&d, face, .colour(K.paleWood), width: 0.9)
        for f in [0.33, 0.66] {
            d.svg.line([face[0] + (face[3] - face[0]) * f, face[1] + (face[2] - face[1]) * f], stroke: .colour(K.darkWood), width: 0.5)
        }
        d.svg.line([face[0] + (face[1] - face[0]) * 0.1, face[3] + (face[2] - face[3]) * 0.1], stroke: .colour(K.ironDark), width: 1.1)
        d.svg.line([face[0] + (face[1] - face[0]) * 0.9, face[3] + (face[2] - face[3]) * 0.9], stroke: .colour(K.ironDark), width: 1.1)
    }

    /// The warp hauled in while working: from the water out on the starboard
    /// side up to the forward gallows' block and in to the winch's warping end,
    /// the marks along it running inboard, water dripping from it, and rings
    /// spreading where it leaves the water.
    static func warp(_ d: inout Drawing, _ space: Space, _ frame: Int) {
        let p = share(frame)
        let entry = V(30, 0, halfBeam(18) + 14), top = block(18) + V(0, 1.4, 0), end = warpingEnd + V(0, 0, 1.6)
        let path = [entry, top, end]
        let screen = path.map(space.at)
        d.svg.line(screen, stroke: .colour(Ink.line), width: 1.5)
        d.svg.line(screen, stroke: .colour(IndustrialPeopleInk.paleSoot), width: 0.6)
        // Marks along the warp, running from the water toward the block.
        for k in 0..<4 {
            let f = (p + Double(k) / 4).truncatingRemainder(dividingBy: 1)
            let at = entry + (top - entry) * f
            d.svg.circle(space.at(at), 0.75, fill: .colour(IndustrialPeopleInk.light), stroke: .colour(Ink.line), width: 0.3)
        }
        // Drops falling from the warp as it rises, and the rings where it leaves the water.
        for k in 0..<3 {
            let age = (p * 2 + Double(k) / 3).truncatingRemainder(dividingBy: 1)
            let from = entry + (top - entry) * (0.35 + 0.2 * Double(k))
            let at = space.at(from) + P(0, (space.at(entry).y - space.at(from).y) * age * age)
            d.svg.circle(at, 0.7, fill: .colour(BoatInk.foam), stroke: .colour(Ink.line), width: 0.3, opacity: 1 - age * 0.6)
        }
        let at = space.at(entry)
        for lag in [0.0, 0.33, 0.66] {
            let age = (p * 2 + lag).truncatingRemainder(dividingBy: 1)
            StoneBoatsWater.ring(&d.svg, at: at, rx: 2.5 + 9 * age, opacity: 0.85 * pow(1 - age, 1.3), width: 1, depth: 0.42)
        }
        StoneBoatsWater.splash(&d.svg, at: at, t: (p * 2).truncatingRemainder(dividingBy: 1), size: 0.7)
    }

    // MARK: The portholes

    /// Two portholes along the near side, under the wheelhouse, ringed in brass.
    static func portholes(_ d: inout Drawing, _ space: Space) {
        let side = space.c >= 0 ? 1.0 : -1.0
        guard abs(space.c) > 0.3 else { return }
        for x in [-20.0, -10] {
            let at = space.at(x, gunwale(x) + 6.6, side * halfBeam(x) * 0.98)
            d.svg.ellipse(at, 1.4 * abs(space.c) + 0.3, 1.4, fill: .colour(IndustrialOldBuildingsInk.glassDark), stroke: .colour(IndustrialPeopleInk.brass),
                          width: 0.7)
        }
    }

    // MARK: The water

    /// The wake behind a trawler under steam: the screw's churn at the stern,
    /// and strokes spreading outward from it on either side, drifting back and fading.
    static func wake(_ d: inout Drawing, _ space: Space, _ frame: Int) {
        let p = share(frame)
        for side in [-1.0, 1.0] {
            for k in 0..<3 {
                let age = (p + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                let back = -halfLength - 3 - 16 * age
                let spread = 4 + 12 * age
                let a = space.at(back, 0, side * spread), b = space.at(back - 7, 0, side * (spread + 4))
                d.svg.line([a, b], stroke: .colour(BoatInk.foam), width: 1.4 - 0.6 * age, opacity: 0.9 * (1 - age))
            }
        }
        // The churn: bubbles of foam welling up behind the stern and falling back.
        for k in 0..<5 {
            let age = (p * 2 + Double(k) / 5).truncatingRemainder(dividingBy: 1)
            let z = 3.6 * sin(Double(k) * 2.4)
            let at = space.at(-halfLength - 2 - 10 * age, 0, z * (1 + age))
            d.svg.ellipse(at, 1.6 + 1.6 * age, (1.6 + 1.6 * age) * 0.5, fill: .colour(BoatInk.foam), opacity: 0.85 * (1 - age))
        }
    }

    /// The bow wave: a crest of foam at the stem, and waves peeling off along
    /// both sides, running aft and spreading.
    static func bowWave(_ d: inout Drawing, _ space: Space, _ frame: Int) {
        let p = share(frame)
        let swell = 0.5 + 0.5 * sin(turn(frame) * 2)
        let stem = halfLength * 0.9
        // The crest at the stem.
        var crest = PathData()
        crest.move(space.at(stem - 4, 0, -halfBeam(stem - 4) - 1))
        crest.quad(space.at(stem + 3, -2.6 - swell, 0), space.at(stem - 4, 0, halfBeam(stem - 4) + 1))
        crest.quad(space.at(stem + 1, 0.6, 0), space.at(stem - 4, 0, -halfBeam(stem - 4) - 1))
        d.svg.path(crest, fill: .colour(BoatInk.foam), stroke: .colour(Ink.line), width: 0.5, opacity: 0.95)
        for side in [-1.0, 1.0] {
            // The wave curling back from the bow, swelling and falling with the pitch.
            let a = space.at(stem - 2, 0, side * 2), b = space.at(stem - 20, 0, side * (halfBeam(stem - 20) + 3 + 2 * swell))
            d.svg.path("M\(num(a.x)),\(num(a.y)) Q\(num((a.x + b.x) / 2)),\(num((a.y + b.y) / 2 - 1.4)) \(num(b.x)),\(num(b.y))",
                       stroke: .colour(BoatInk.foam), width: 1.8, opacity: 0.8 + 0.2 * swell)
            // The waves running aft along the side and spreading.
            for k in 0..<3 {
                let age = (p + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                let x = stem - 18 - 40 * age
                let z = side * (halfBeam(x) + 3 + 9 * age)
                let s0 = space.at(x, 0, z), s1 = space.at(x - 8, 0, z + side * 3)
                d.svg.line([s0, s1], stroke: .colour(BoatInk.foam), width: 1.4 - 0.6 * age, opacity: 0.85 * (1 - age))
            }
        }
    }

    /// The smoke from the funnel: puffs leaving its mouth, growing and fading
    /// as they rise; under steam they stream aft, thick, and lying still a thin
    /// wisp rises nearly straight. Each puff's age runs round the cycle, so
    /// that the plume is the same at frame 0 as after frame 11.
    static func smoke(_ d: inout Drawing, _ space: Space, _ pose: SpritePose, _ frame: Int) {
        let p = share(frame)
        let mouth = V(-35, -76, 0)
        let (count, aft, rise, size, grow, strength): (Int, Double, Double, Double, Double, Double) = switch pose {
        case .walking: (8, 46, 22, 3.6, 7.6, 1)
        case .working: (5, 14, 30, 2.4, 4.6, 0.8)
        default: (4, 6, 32, 2.2, 3.6, 0.8)
        }
        var puffs: [(age: Double, at: P, r: Double)] = []
        for k in 0..<count {
            let age = (p + Double(k) / Double(count)).truncatingRemainder(dividingBy: 1)
            let curl = 1.6 * sin(age * 7 + Double(k))
            let at = space.at(mouth.x - aft * age * (0.6 + 0.4 * age), mouth.y - rise * age * (1.2 - 0.3 * age), curl)
            puffs.append((age, at, size + grow * age))
        }
        for puff in puffs.sorted(by: { $0.age > $1.age }) {
            let fade = strength * pow(1 - puff.age, 1.1) * min(1, puff.age * 6 + 0.25)
            billow(&d.svg, at: puff.at, radius: puff.r, opacity: fade, young: puff.age < 0.3)
        }
    }

    /// A puff of coal smoke: three rounds run together, soot grey (darker while
    /// `young`, near the funnel), lit on their upper left, the line loose and faint about them.
    static func billow(_ svg: inout SVG, at c: P, radius r: Double, opacity: Double, young: Bool) {
        guard opacity > 0.01 else { return }
        let rounds = [(P(0, 0), r), (P(r * 0.75, r * 0.25), r * 0.72), (P(-r * 0.55, r * 0.35), r * 0.6)]
        svg.raw("<g opacity=\"\(num(opacity))\">")
        for (o, q) in rounds { svg.circle(c + o, q + 0.7, fill: .colour(Ink.line), opacity: 0.45) }
        for (o, q) in rounds { svg.circle(c + o, q, fill: .colour(young ? IndustrialOldBuildingsInk.smokeDark : IndustrialOldBuildingsInk.smoke)) }
        for (o, q) in rounds { svg.circle(c + o + P(-q * 0.3, -q * 0.3), q * 0.5, fill: .colour(IndustrialOldBuildingsInk.smokeLight), opacity: 0.6) }
        svg.raw("</g>")
    }

    // MARK: The crewman

    /// The crewman at the winch, at `figure` of a person's size, standing on the
    /// deck: clipped by the near bulwark (with what lies above it), his arms
    /// reaching to the lever's grip.
    static func crewman(_ d: inout Drawing, _ space: Space, _ pose: SpritePose, _ frame: Int) {
        let origin = space.at(stand, deck(stand), 0)
        let lean = d.rig.lean * cos(d.yaw * .pi / 180)
        let k = figure
        /// A point of the figure, drawn by the kit in this view, where it falls in the picture.
        func placed(_ p: P) -> P { p.rotated(lean, about: Drawing.hips) * k + origin }
        let shoulders = [false, true].map { right in
            placed(d.project(0.5, -44 - d.rig.lift, right ? Drawing.shoulderSpread : -Drawing.shoulderSpread).point)
        }
        let g = grip(pose, frame)
        let hands = [g + V(0, 0, -1.8), g + V(0, 0, 1.8)].map(space.at)
        let armBehind = [false, true].map { right -> Bool in
            let z = right ? Drawing.shoulderSpread : -Drawing.shoulderSpread
            return space.depth(0.5 * k, z * k) + space.depth(g.x - stand, right ? 1.8 : -1.8) < -4
        }
        for right in [false, true] where armBehind[right ? 1 : 0] { arm(&d, from: shoulders[right ? 1 : 0], to: hands[right ? 1 : 0]) }
        d.svg.raw("<g transform=\"translate(\(num(origin.x)),\(num(origin.y))) scale(\(num(k))) "
                  + "rotate(\(num(lean)) \(num(Drawing.hips.x)) \(num(Drawing.hips.y)))\">")
        body(&d)
        d.svg.raw("</g>")
        for right in [false, true] where !armBehind[right ? 1 : 0] { arm(&d, from: shoulders[right ? 1 : 0], to: hands[right ? 1 : 0]) }
    }

    /// A sleeve of the jersey from the shoulder to the hand on the screen, its
    /// elbow bent downward where the hand comes nearer than the arm's length, and the hand.
    static func arm(_ d: inout Drawing, from shoulder: P, to hand: P) {
        let k = figure
        let delta = hand - shoulder
        let distance = (delta.x * delta.x + delta.y * delta.y).squareRoot()
        let segment = max(Joints.upperArm * k, distance / 2 + 0.05)
        let along = distance / 2, out = (segment * segment - along * along).squareRoot()
        let u = delta * (1 / max(distance, 1e-6)), n = P(-u.y, u.x)
        let middle = shoulder + u * along
        let one = middle + n * out, two = middle - n * out
        let elbow = one.y > two.y ? one : two
        d.svg.line([shoulder, elbow, hand], stroke: .colour(Ink.line), width: 4.6 * k)
        d.svg.line([shoulder, elbow, hand], stroke: .colour(IndustrialPeopleInk.soot), width: 3 * k)
        // The jersey's cuff, and the hand.
        let cuff = hand + (elbow - hand) * (1.6 / max(1, ((elbow - hand).x * (elbow - hand).x + (elbow - hand).y * (elbow - hand).y).squareRoot()))
        d.svg.line([cuff, hand + (cuff - hand) * 0.4], stroke: .colour(IndustrialPeopleInk.paleSoot), width: 2.6 * k)
        d.svg.circle(hand, 1.7 * k, fill: .colour(Ink.skin), stroke: .colour(Ink.line), width: 0.7)
    }

    /// The crewman in the figure's space: trousers and sea boots (mostly hidden
    /// by the bulwark), the ribbed jersey with the team's neckerchief, and the head.
    static func body(_ d: inout Drawing) {
        typealias K = IndustrialPeopleInk
        IndustrialViews.trousers(&d, colour: K.darkSoot, shade: K.coal)
        d.garment(colour: [P(-11.6, -47), P(9.4, -48), P(11.6, -16.4), P(-12.6, -15.6)],
                  outline: [P(-9, -47.4), P(8.6, -47.4), P(11, -17), P(-12, -16.4)], fill: .colour(K.soot)) { d in
            // The ribs knitted across the yoke, and the welt at the hem.
            for y in [-42.6, -39.4] { d.band([P(-11, y), P(10, y - 0.4), P(10.2, y + 1), P(-11.2, y + 1.4)], fill: .colour(K.paleSoot)) }
            d.band([P(-12.2, -19.4), P(11.2, -19.8), P(11.6, -16.6), P(-12.6, -16)], fill: .colour(K.darkSoot))
        }
        // The neckerchief of the team's colour, knotted at the throat.
        d.band([P(-6.4, -48.6), P(7, -48.6), P(7.2, -45.4), P(-6.6, -45.4)])
        if d.view == .side || IndustrialViews.seesFront(d) {
            let knot = d.view == .side ? P(7.4, -45.6) : P(IndustrialViews.face(d).x * 0.5, -45.4)
            d.svg.polygon([knot + P(-1, 0), knot + P(1.2, 0), knot + P(1.8, 4.2), knot + P(-0.6, 3.6)], fill: .team,
                          stroke: .colour(Ink.line), width: 0.7)
            d.svg.circle(knot, 1.3, fill: .team, stroke: .colour(Ink.line), width: 0.7)
        }
        let ginger = Paint.colour(K.gingerHair), ink = Paint.colour(Ink.line)
        d.head(nose: nose, behind: { _ in }, hair: { d in
            switch d.view {
            case .side:
                d.svg.path("M-11.2,-62 C-12.8,-57 -11.6,-52.4 -7.8,-50.6 C-8.6,-52.6 -8.2,-54.6 -7.2,-56 C-8.8,-57 -8.8,-59.2 -7.6,-61 Z", fill: ginger)
            case .front:
                for s in [-1.0, 1.0] {
                    d.svg.polygon([P(9.8 * s, -63), P(7.6 * s, -63), P(8 * s, -57), P(9.6 * s, -55.6), P(10.6 * s, -58)], fill: ginger)
                }
            case .frontQuarter:
                d.svg.path("M-11.2,-61.6 C-12.4,-57 -11.6,-53 -9.4,-51.4 L-9.6,-61 Z", fill: ginger)
            case .back:
                d.svg.path(IndustrialViews.backHair(d, rim: -64), fill: ginger)
            case .backQuarter:
                d.svg.path(IndustrialViews.backHair(d, rim: -64, right: 5.4), fill: ginger)
            }
        }, features: { d in
            // The beard under the chin, from ear to ear, clear of the mouth.
            switch d.view {
            case .side:
                d.svg.path("M-7,-57 C-6.4,-50.4 -3,-46.4 2.4,-45.6 C6.4,-45 10,-46.4 11.6,-48.8 C9,-48.6 6.6,-48.4 4.6,-49 "
                           + "C1.6,-49.6 -1.6,-51.8 -3.2,-56.4 Z", fill: ginger, stroke: ink, width: 0.8)
            case .front, .frontQuarter:
                let half = [P(0, -45.2), P(4.2, -45.8), P(7.6, -48), P(9.6, -52), P(10.2, -56.6), P(8.6, -56), P(7.4, -52.4), P(4.8, -49.4),
                            P(2, -48.6), P(0, -48.4)]
                d.svg.polygon(IndustrialViews.symmetric(d, half), fill: ginger, stroke: ink, width: 0.8)
            case .back, .backQuarter:
                break
            }
        }, brow: { d in
            d.svg.path("M1.4,-62.6 q3.4,-1.8 7,-0.6", stroke: ginger, width: 1.8)
        }, over: { d in
            cap(&d)
        })
    }

    /// The knitted cap of bottle green: its crown, and the brim turned up round it with its ribs.
    static func cap(_ d: inout Drawing) {
        typealias K = IndustrialPeopleInk
        let view = d
        let rim = -64.6
        BronzePeopleProps.shape(&d.svg, fill: .colour(K.green), width: 1.4) { o in
            IndustrialViews.crown(view, rim: rim, top: -75, half: 11.6, forward: 0.6, flare: 1.2, offset: o)
        }
        BronzePeopleProps.shape(&d.svg, fill: .colour(K.darkGreen), width: 1.1) { o in
            IndustrialViews.capBand(view, rim: rim + 0.6, height: 3.8, half: 11.8, forward: 0.6, offset: o)
        }
        var ribs = PathData()
        for x in stride(from: -9.6, through: 9.6, by: 2.4) {
            let c = 0.6 * IndustrialViews.ahead(d)
            ribs.move(P(c + x, rim - 0.2)); ribs.line(P(c + x, rim - 3))
        }
        d.svg.path(ribs, stroke: .colour(K.green), width: 0.6)
    }
}
