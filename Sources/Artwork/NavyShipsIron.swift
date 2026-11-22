// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The navy ship in the Iron look: a war galley of the Middle Sea, half as long
// again as the Iron age's fishing boat and built as it is, so that the two read
// as one age. A long, low hull of tarred planks, its top strake painted in the
// team's colour with a running wave in the light colour, a sea-green wale
// pierced by the row of oar ports under it, and an eye painted on each side of
// the bow; an iron ram at the waterline, a low stem curling forward over it,
// and the stern rising in a tall curl (the aplustre). A row of round shields of
// the team's colour, each with a light rim and an iron boss, hangs along the
// near rail. Nine oars a side; a mast amidships with a square sail of undyed
// linen striped in the team's colour on a braced yard, and the team's pennant
// at the masthead; a steering oar on each quarter; a small deckhouse aft under
// a sea-green awning; and on a timber platform in the bow, its one gun, an
// iron barrel pointing ahead over the stem.
//
// Standing, the galley rides at anchor, its sail furled on the yard and its
// oars trailing aft with their blades flat on the water. Walking, it is rowed: the
// oars dip, sweep aft through the water and come forward through the air
// together, the sail is set and full, the pennant streams, the bow pushes a
// ripple and a wake spreads behind. Fighting, the sail is furled and the oars
// pull short, easy strokes to hold the bow on the target; the bow gun fires ahead with a flash,
// runs in and out again, and its smoke rolls forward and rises. Every cycle is
// periodic in its 12 frames. The origin is on the waterline at the middle of
// the hull; the ship casts no shadow.

enum NavyShipIron {
    typealias Space = StoneDugout.Space
    typealias V = StoneDugout.V
    typealias K = IronPeopleInk

    /// Room for the hull in every view, the oars' reach, the mast, the gun's smoke ahead, the wake and the ring.
    static let canvas = Canvas(minX: -118, minY: -128, width: 238, height: 180, pixelsPerUnit: Canvas.person.pixelsPerUnit)

    /// The hull's half length and half beam at the gunwale: half as long again as the fishing boat's (`IronFishingBoat`).
    static let halfLength = 66.0, beam = 12.0
    static let hull = NavyHull(halfLength: halfLength, halfBeam: { x in
        let f = min(abs(x) / halfLength, 1)
        return beam * max(0, 1 - pow(f, x >= 0 ? 2.2 : 2.6)).squareRoot()
    }, gunwale: { x in
        let f = min(abs(x) / halfLength, 1)
        return -(11 + (x >= 0 ? 4 : 6) * pow(f, 3))
    })

    /// Where the oars come through the side, and their length outboard and their blades'.
    static let oarStations: [Double] = stride(from: -42.0, through: 38, by: 10).map { $0 }
    static let oarDrop = 6.2, oarLength = 36.0, oarBlade = 12.0
    /// The mast's place along the hull, its head, and the yard's height and half length.
    static let mastX = 4.0, masthead = -104.0, yardY = -95.0, yardHalf = 30.0
    /// The gun: its breech and muzzle when run out, and the frame it fires in.
    static let breech = V(46, -20, 0), muzzle = V(64, -20.4, 0), fires = 1

    // MARK: Motion

    /// The stroke's phase: the drive through the water lasts longer than the recovery through the air.
    static func stroke(_ frame: Int) -> Double {
        let t = NavyKit.turn(frame)
        return t - 0.36 * sin(t)
    }

    /// The oars' sweep in degrees (positive with the blades aft), their dip (positive with the blades down), and how square the blades are.
    static func oarAngles(_ pose: SpritePose, _ frame: Int) -> (sweep: Double, dip: Double, square: Double) {
        let t = NavyKit.turn(frame)
        switch pose {
        case .walking:
            let s = stroke(frame)
            return (2 - 24 * cos(s), 9 + 10 * sin(s), 0.5 + 0.5 * tanh(3 * sin(s + 0.35)))
        case .fighting:
            // Short, easy strokes, holding the bow on the target.
            let s = stroke(frame)
            return (4 - 12 * cos(s), 7 + 6 * sin(s), 0.5 + 0.5 * tanh(3 * sin(s + 0.35)))
        default:
            // Resting, trailing aft with the blades flat on the water and rocking on it.
            return (40, 11 + 0.8 * sin(t), 0)
        }
    }

    static func oars(_ pose: SpritePose, _ frame: Int) -> [NavyOar] {
        let a = oarAngles(pose, frame)
        return [-1.0, 1.0].flatMap { side in
            oarStations.map { x in
                NavyOar(side: side, port: hull.onSide(x, down: oarDrop, side: side), sweep: a.sweep, dip: a.dip, square: a.square,
                        length: oarLength, blade: oarBlade)
            }
        }
    }

    // MARK: Drawing

    static func draw(_ svg: inout SVG, _ view: SpriteView, _ pose: SpritePose, _ frame: Int) {
        let h = halfLength
        let space = Space(view, rise: NavyKit.bob(pose, frame, shots: pose == .fighting ? [fires] : []))
        let rim = hull.rim(space), water = hull.waterline(space)
        let nearRim = StoneDugout.nearChain(rim), nearWater = StoneDugout.nearChain(water)
        let ring = NavyKit.ring(space, halfLength: h, beam: beam)
        let bowAhead = space.depth(h, 0) >= 0
        let oars = oars(pose, frame)
        let recoil = pose == .fighting ? NavyKit.recoil(frame, fires: fires, by: 4) : 0
        let shotMuzzle = muzzle + V(-recoil, 0, 0)

        // The water behind and about the ship, and the smoke where it lies beyond the hull.
        NavyKit.ringBehind(&svg, ring)
        if pose == .walking { NavyKit.wake(&svg, space, hull: hull, frame: frame, churn: false) }
        if pose == .fighting, !bowAhead { shot(&svg, space, frame, muzzle: shotMuzzle) }

        // What lies beyond the hull: the far oars, the far steering oar, and the end post beyond it.
        for oar in oars where !NavyHull.faces(space, side: oar.side) { oar.draw(&svg, space, wood: K.paleTimber, dark: K.handle) }
        for side in [-1.0, 1.0] where !NavyHull.faces(space, side: side) { steeringOar(&svg, space, side: side) }
        if bowAhead { aplustre(&svg, space) } else { bow(&svg, space) }

        // The hull: the side toward the viewer and the deck inside the rail.
        drawHull(&svg, space, rim: rim, nearRim: nearRim, nearWater: nearWater)

        // What stands on the deck, above the near rail, from the farthest to the nearest.
        NavyKit.clipped(&svg, id: "navy-iron-above", NavyHull.above(nearRim)) { svg in
            let parts: [(depth: Double, draw: (inout SVG) -> Void)] = [
                (space.depth(-41, 0), { deckhouse(&$0, space) }),
                (space.depth(mastX, 0), { mast(&$0, space, view, pose, frame) }),
                (space.depth(54, 0), { gun(&$0, space, recoil: recoil) }),
            ]
            let order = parts.indices.sorted { parts[$0].depth == parts[$1].depth ? $0 < $1 : parts[$0].depth < parts[$1].depth }
            for i in order { parts[i].draw(&svg) }
        }
        rigging(&svg, space, view, pose)
        NavyKit.flag(&svg, at: space.at(mastX, masthead + 1, 0), length: 17, height: 4.6, streaming: pose == .walking, frame: frame,
                     pennant: true)

        // The near side's shields, oars and steering oar, and the nearer end post.
        shields(&svg, space)
        for oar in oars where NavyHull.faces(space, side: oar.side) { oar.draw(&svg, space, wood: K.paleTimber, dark: K.handle) }
        for side in [-1.0, 1.0] where NavyHull.faces(space, side: side) { steeringOar(&svg, space, side: side) }
        if bowAhead { bow(&svg, space) } else { aplustre(&svg, space) }

        // The water along the near side, and what the oars stir.
        NavyKit.waterInFront(&svg, nearWater: nearWater, ring)
        switch pose {
        case .walking:
            for oar in oars { oar.drawWater(&svg, space) }
            NavyKit.bowWave(&svg, space, hull: hull, stem: h * 0.95, frame: frame)
        default:
            NavyKit.lapping(&svg, ring, frame: frame)
            for oar in oars { oar.drawWater(&svg, space) }
        }
        if pose == .fighting, bowAhead { shot(&svg, space, frame, muzzle: shotMuzzle) }
    }

    /// The hull's side toward the viewer, painted, and the deck inside the rail.
    static func drawHull(_ svg: inout SVG, _ space: Space, rim: [P], nearRim: [P], nearWater: [P]) {
        let side = NavyHull.side(nearRim, nearWater)
        svg.polygon(side.map { $0 + P(-0.9, 0.7) }, fill: .colour(IronBoatInk.hull))
        NavyKit.clipped(&svg, id: "navy-iron-side", side) { svg in
            svg.polygon(NavyHull.band(nearRim, 4.4, 8.6), fill: .colour(IronBoatInk.wale))
            svg.polygon(nearWater + nearWater.reversed().map { $0 + P(0, -3.4) }, fill: .colour(IronBoatInk.tar), opacity: 0.8)
            var seams = PathData()
            for k in [10.8, 13.4, 16] {
                for (i, p) in nearRim.enumerated() { if i == 0 { seams.move(p + P(0, k)) } else { seams.line(p + P(0, k)) } }
            }
            svg.path(seams, stroke: .colour(Ink.line), width: 0.5, opacity: 0.55)
            svg.polygon(NavyHull.band(nearRim, 1.2, 4.4), fill: .team)
            var wave = PathData()
            let usable = nearRim.indices.filter { $0 > 1 && $0 < nearRim.count - 2 }
            for (k, i) in usable.enumerated() {
                let p = nearRim[i] + P(0, 2.8)
                if k == 0 { wave.move(p) } else { wave.quad((nearRim[usable[k - 1]] + P(0, 2.8) + p) * 0.5 + P(0, k % 2 == 0 ? 1.3 : -1.3), p) }
            }
            if usable.count > 1 { svg.path(wave, stroke: .colour(Ink.light), width: 0.8) }
            svg.line(nearRim.map { $0 + P(0, 4.4) }, stroke: NavyKit.line, width: 0.6)
            svg.line(nearRim.map { $0 + P(0, 8.6) }, stroke: NavyKit.line, width: 0.6)
        }
        // The oar ports along the near side, and the eyes at the bow.
        for s in [-1.0, 1.0] where NavyHull.faces(space, side: s) && abs(space.c) > 0.3 {
            for x in oarStations {
                svg.ellipse(space.at(hull.onSide(x, down: oarDrop, side: s)), 1.2 * abs(space.c) + 0.3, 1.1, fill: .colour(IronBoatInk.tar))
            }
        }
        for s in [-1.0, 1.0] where NavyHull.faces(space, side: s, forward: 0.45) { eye(&svg, space, side: s) }
        svg.polygon(side, fill: .none, stroke: NavyKit.line, width: 1.5)

        // The deck: planks inside the rail, and the hatch down to the rowers.
        svg.polygon(rim, fill: .colour(IronBoatInk.inside))
        NavyKit.clipped(&svg, id: "navy-iron-deck", rim) { svg in
            svg.polygon(hull.rim(space, inset: 0.86, lower: 2.2), fill: .colour(K.timber))
            var planks = PathData()
            for k in [-0.5, 0.0, 0.5] {
                for (i, x) in hull.stations.enumerated() {
                    let p = space.at(x, hull.gunwale(x) + 2.2, hull.halfBeam(x) * 0.86 * k)
                    if i == 0 { planks.move(p) } else { planks.line(p) }
                }
            }
            svg.path(planks, stroke: .colour(K.darkTimber), width: 0.5, opacity: 0.7)
            let g = hull.gunwale(-16) + 2.2
            let hatch = [V(-22, g, -3.6), V(-10, g, -3.6), V(-10, g, 3.6), V(-22, g, 3.6)].map(space.at)
            svg.polygon(hatch, fill: .colour(IronBoatInk.bilge), stroke: NavyKit.line, width: 0.7)
        }
        svg.polygon(rim, fill: .none, stroke: NavyKit.line, width: 1.1)
        svg.line(nearRim.map { $0 + P(0, 0.7) }, stroke: .colour(IronBoatInk.gunwaleLight), width: 0.7)
    }

    /// The painted eye on one side of the bow: a light almond rimmed in red, with a dark pupil.
    static func eye(_ svg: inout SVG, _ space: Space, side: Double) {
        let x0 = halfLength * 0.8
        func on(_ dx: Double, _ dy: Double) -> P { space.at(hull.onSide(x0 + dx, down: 7.4 + dy, side: side)) }
        var almond = PathData()
        almond.move(on(-4, 0.4))
        almond.quad(on(0, -3.4), on(4, -0.4))
        almond.quad(on(0, 2.8), on(-4, 0.4))
        almond.close()
        svg.path(almond, fill: .colour(Ink.light), stroke: .colour(K.red), width: 0.9)
        svg.circle(on(0.5, -0.2), 1.3, fill: .colour(Ink.line))
    }

    /// The bow: the iron ram at the waterline, with its three fins, and the low stem curling forward over it.
    static func bow(_ svg: inout SVG, _ space: Space) {
        let h = halfLength
        let tip = V(h + 13, -1.2, 0)
        let corners = [V(h * 0.86, -5.4, -2.8), V(h * 0.86, -5.4, 2.8), V(h * 0.86, 1.6, -2.8), V(h * 0.86, 1.6, 2.8), tip]
        let outline = StoneDugout.outline(corners.map(space.at))
        NavyKit.shape(&svg, outline, .colour(K.grey), width: 1.1)
        var fins = PathData()
        for y in [-3.8, -1.8, 0.2] {
            fins.move(space.at(V(h * 0.9, y, 0))); fins.line(space.at(tip + V(-1.5, 0.3 * (y + 1.8), 0)))
        }
        svg.path(fins, stroke: .colour(K.darkGrey), width: 0.8)
        NavyKit.post(&svg, space, [V(h * 0.86, -3, 0), V(h + 2.5, -10, 0), V(h + 4, -14.5, 0), V(h + 6.5, -16.6, 0), V(h + 8.2, -15, 0),
                                   V(h + 6.8, -13.6, 0)], width: 2.4, colour: IronBoatInk.hull)
    }

    /// The aplustre: the stern rising and curling forward over the deck.
    static func aplustre(_ svg: inout SVG, _ space: Space) {
        let h = halfLength
        NavyKit.post(&svg, space, [V(-h * 0.94, -5, 0), V(-h - 4, -16, 0), V(-h - 6, -28, 0), V(-h - 4, -38, 0), V(-h + 0.5, -43, 0),
                                   V(-h + 4, -41, 0), V(-h + 3, -37.6, 0), V(-h + 0.6, -38.6, 0)], width: 3.2, colour: IronBoatInk.hull)
        // A band of the team's colour about its foot, and a light one above it.
        let a = space.at(-h - 4.6, -19, 0), b = space.at(-h - 5.6, -23, 0)
        svg.line([a, b], stroke: .team, width: 3)
        let c = space.at(-h - 5.8, -24.4, 0), d = space.at(-h - 6, -26, 0)
        svg.line([c, d], stroke: .colour(Ink.light), width: 3)
    }

    /// A steering oar on one quarter: its loom slanting aft into the water and its broad blade, faint under the surface.
    static func steeringOar(_ svg: inout SVG, _ space: Space, side: Double) {
        let x = -54.0
        let top = V(x + 2, hull.gunwale(x) - 3, side * (hull.halfBeam(x) + 0.4))
        let foot = V(x - 12, 7, side * (hull.halfBeam(x) + 4.5))
        let along = (foot - top).unit
        let neck = top + (foot - top) * 0.55
        let blade = [neck + V(1.2, 0, 0), neck + along * 2 + V(2.8, 0, 0), foot + V(2.6, 0, 0), foot + V(-2.6, 0, 0),
                     neck + along * 2 + V(-2.8, 0, 0), neck + V(-1.2, 0, 0)]
        let shaft = IronCut.split([top, neck], closed: false), leaf = IronCut.split(blade, closed: true)
        if leaf.below.count > 2 { svg.polygon(leaf.below.map(space.at), fill: .colour(K.paleTimber), opacity: 0.35) }
        if shaft.above.count > 1 {
            svg.line(shaft.above.map(space.at), stroke: NavyKit.line, width: 3)
            svg.line(shaft.above.map(space.at), stroke: .colour(K.timber), width: 1.6)
        }
        if leaf.above.count > 2 { NavyKit.shape(&svg, leaf.above.map(space.at), .colour(K.paleTimber), width: 0.8) }
    }

    /// The round shields along the near rail: the team's colour, a light rim and an iron boss.
    static func shields(_ svg: inout SVG, _ space: Space) {
        guard abs(space.c) > 0.3 else { return }
        let side = space.c > 0 ? 1.0 : -1.0
        let rx = 3.5 * abs(space.c) + 0.5
        for x in stride(from: -37.0, through: 43, by: 10) {
            let at = space.at(x, hull.gunwale(x) - 0.4, side * (hull.halfBeam(x) + 0.6))
            svg.ellipse(at + P(-0.5, 0.4), rx, 3.5, fill: .team)
            svg.ellipse(at, rx - 0.7, 2.8, fill: .none, stroke: .colour(Ink.light), width: 0.9)
            svg.ellipse(at, rx, 3.5, fill: .none, stroke: NavyKit.line, width: 0.9)
            svg.circle(at, 1, fill: .colour(K.iron), stroke: NavyKit.line, width: 0.5)
        }
    }

    /// The mast, and its sail: furled on the yard at rest and in a fight, set and full under way.
    static func mast(_ svg: inout SVG, _ space: Space, _ view: SpriteView, _ pose: SpritePose, _ frame: Int) {
        NavyKit.spar(&svg, space, V(mastX, hull.gunwale(mastX) + 2, 0), V(mastX, masthead, 0), width: 2.2, colour: K.timber)
        svg.circle(space.at(mastX, masthead, 0), 1.6, fill: .colour(K.paleTimber), stroke: NavyKit.line, width: 0.6)
        let degrees = NavyKit.brace(view)
        let head = V(mastX, yardY, 0)
        guard pose == .walking else {
            NavyKit.furled(&svg, space, head: head, half: yardHalf, degrees: degrees, canvas: Ink.light, yard: K.timber)
            return
        }
        let belly = 7 + 0.8 * sin(2 * NavyKit.turn(frame))
        let sail = NavyKit.SquareSail(head: head, half: yardHalf, drop: 40, degrees: degrees, belly: belly)
        NavyKit.squareSail(&svg, space, sail, canvas: Ink.light, seam: K.paleGrey, yard: K.timber) { svg, sail in
            for s in [-0.5, 0.0, 0.5] { svg.polygon(sail.outline(space, from: s - 0.11, to: s + 0.11), fill: .team) }
        }
    }

    /// The forestay and backstay, the shrouds, and the sheets when the sail is set.
    static func rigging(_ svg: inout SVG, _ space: Space, _ view: SpriteView, _ pose: SpritePose) {
        let h = halfLength, head = V(mastX, masthead + 2, 0)
        var pairs: [(V, V)] = [(head, V(h + 6, -15.5, 0)), (head, V(-h - 3, -37, 0))]
        for side in [-1.0, 1.0] { pairs.append((V(mastX, masthead + 8, 0), V(mastX - 4, hull.gunwale(mastX - 4), side * hull.halfBeam(mastX - 4)))) }
        if pose == .walking {
            let sail = NavyKit.SquareSail(head: V(mastX, yardY, 0), half: yardHalf, drop: 40, degrees: NavyKit.brace(view), belly: 7)
            for s in [-1.0, 1.0] {
                let clew = sail.point(s, 1)
                let x = mastX - 22
                pairs.append((clew, V(x, hull.gunwale(x), (clew.z >= 0 ? 1 : -1) * hull.halfBeam(x))))
            }
        }
        NavyKit.rigging(&svg, space, pairs)
    }

    /// The deckhouse aft: low planked walls under a sea-green awning.
    static func deckhouse(_ svg: inout SVG, _ space: Space) {
        typealias T = IndustrialTrawler
        let (x0, x1) = (-50.0, -33.0)
        let z = hull.halfBeam(-46) * 0.62
        let bottom = hull.gunwale(-41) + 2, top = -26.0
        let shades = [K.wood, K.paleTimber, K.handle, K.handle]
        for (face, shade) in T.faces(space, x0: x0, x1: x1, z0: -z, z1: z, bottom: bottom, top: top) {
            NavyKit.shape(&svg, T.panel(space, face, 0, 0, 1, 1), .colour(shades[shade]), width: 0.9)
            if shade == 0 || shade == 3 {
                NavyKit.shape(&svg, T.panel(space, face, 0.4, 0.05, 0.6, 0.7), .colour(IronBoatInk.bilge), width: 0.6)
            }
        }
        // The awning, its edge scalloped and striped in the light colour.
        let roof = T.lid(space, x0: x0 - 2, x1: x1 + 2, z0: -z - 1.4, z1: z + 1.4, at: top - 1)
        NavyKit.shape(&svg, roof, .colour(K.sea), width: 0.9)
        var stripes = PathData()
        for u in [0.25, 0.5, 0.75] {
            let x = x0 - 2 + (x1 - x0 + 4) * u
            stripes.move(space.at(x, top - 1, -z - 1.4)); stripes.line(space.at(x, top - 1, z + 1.4))
        }
        svg.path(stripes, stroke: .colour(Ink.light), width: 1.1)
    }

    /// The bow gun: an iron barrel on a timber platform, run in after its shot by `recoil`.
    static func gun(_ svg: inout SVG, _ space: Space, recoil: Double) {
        typealias T = IndustrialTrawler
        let bottom = hull.gunwale(54) + 2, top = -16.5
        let shades = [K.timber, K.paleTimber, K.darkTimber, K.darkTimber]
        for (face, shade) in T.faces(space, x0: 46, x1: 60, z0: -3.6, z1: 3.6, bottom: bottom, top: top) {
            NavyKit.shape(&svg, T.panel(space, face, 0, 0, 1, 1), .colour(shades[shade]), width: 0.9)
        }
        NavyKit.shape(&svg, T.lid(space, x0: 46, x1: 60, z0: -3.6, z1: 3.6, at: top), .colour(K.paleTimber), width: 0.9)
        // The cheeks holding the trunnions, and the barrel between them.
        let back = V(-recoil, 0, 0)
        for z in [-2.4, 2.4] {
            NavyKit.shape(&svg, [V(50, top, z), V(56, top, z), V(55, -19.6, z), V(51, -19.6, z)].map { space.at($0 + back * 0.3) },
                          .colour(K.darkTimber), width: 0.7)
        }
        NavyKit.barrel(&svg, space, breech: breech + back, muzzle: muzzle + back, width: 3.2, colour: K.iron, ring: K.ironDark)
        svg.circle(space.at(breech + back + V(-1.2, 0, 0)), 1.5, fill: .colour(K.ironDark), stroke: NavyKit.line, width: 0.6)
    }

    /// The shot from the bow gun: the flash at the muzzle in the frame it fires and the next, and the smoke through the cycle.
    static func shot(_ svg: inout SVG, _ space: Space, _ frame: Int, muzzle: V) {
        let age = NavyKit.since(frame, fires: fires)
        let along = muzzle - breech
        NavyKit.smoke(&svg, space, muzzle: muzzle + along.unit * 1.5, along: along, age: age, scale: 1.15)
        if age < 0.1 {
            NavyKit.flash(&svg, space, muzzle: muzzle + along.unit * 1.2, along: along, size: age == 0 ? 15 : 8,
                          flash: AlchemyWarriorsInk.flash, core: AlchemyWarriorsInk.flashCore)
        }
    }
}
