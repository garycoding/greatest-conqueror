// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The navy ship in the Alchemy look: a galleon, half as long again as the
// Alchemy age's fishing smack. A hull of dark timber with a square transom,
// its gun-deck strake painted in the team's colour between gilt mouldings and
// pierced by seven gun ports a side, their lids open and lined in wine, the
// muzzles run out; two dark wales below and tar along the waterline. A high
// sterncastle of wine-red timber in two tiers, its stern windows framed in
// gilt and a gilt lantern on the taffrail; a forecastle with two bow chasers
// looking out of its forward face; a beakhead with a gilt lion at the stem
// head, and a bowsprit. Three masts: the fore and main square-rigged with a
// course and a topsail each, canvas in the light colour bearing a cross of the
// team's colour, on yards braced for the view; a lateen on the mizzen; the
// team's pennants at the mastheads and its ensign at the stern.
//
// Standing, the galleon lies hove to under its topsails, the courses furled
// on their yards, and rides the water. Walking, every sail is set and full,
// the pennants stream, the bow pushes up a wave and a wake spreads behind.
// Fighting, it fights under topsails, as such ships did: the bow chasers fire
// ahead in turn, starboard then port, each with a flash, running in and out
// again, and their smoke rolls forward and rises. Every cycle is periodic in
// its 12 frames. The origin is on the waterline at the middle of the hull; the
// ship casts no shadow.

enum NavyShipAlchemy {
    typealias Space = StoneDugout.Space
    typealias V = StoneDugout.V
    typealias K = AlchemyPeopleInk
    typealias W = AlchemyWarriorsInk

    /// Room for the hull and the bowsprit in every view, the masts, the chasers' smoke ahead, the wake and the ring.
    static let canvas = Canvas(minX: -124, minY: -166, width: 270, height: 232, pixelsPerUnit: Canvas.person.pixelsPerUnit)

    /// The hull's half length and half beam: about half as long again as the smack's (`AlchemySmack`).
    static let halfLength = 76.0, beam = 16.0
    static let hull = NavyHull(halfLength: halfLength, halfBeam: { x in
        let f = min(abs(x) / halfLength, 1)
        // Fine forward; full aft to a square transom.
        return x >= 0 ? beam * max(0, 1 - pow(f, 2.2)).squareRoot() : beam * max(0, 1 - 0.72 * pow(f, 3)).squareRoot()
    }, gunwale: { x in
        let f = min(abs(x) / halfLength, 1)
        return -(19 + (x >= 0 ? 4 : 2) * f * f)
    })

    /// The gun ports along each side.
    static let ports: [Double] = [-40, -26, -12, 2, 16, 30, 44]
    /// The masts: their places along the hull and their heads.
    static let fore = (x: 42.0, head: -132.0), main = (x: 2.0, head: -150.0), mizzen = (x: -40.0, head: -116.0)
    /// The bow chasers: their height and their places across the forecastle's face, and the frames they fire in.
    static let chaserY = -26.0, chasers: [(z: Double, fires: Int)] = [(3.6, 1), (-3.6, 5)]
    /// The bowsprit, from the forecastle out over the beakhead.
    static let bowspritFoot = V(62, -31, 0), bowspritEnd = V(106, -47, 0)

    // MARK: Drawing

    static func draw(_ svg: inout SVG, _ view: SpriteView, _ pose: SpritePose, _ frame: Int) {
        let h = halfLength
        let space = Space(view, rise: NavyKit.bob(pose, frame, shots: pose == .fighting ? chasers.map(\.fires) : []))
        let rim = hull.rim(space), water = hull.waterline(space)
        let nearRim = StoneDugout.nearChain(rim), nearWater = StoneDugout.nearChain(water)
        let ring = NavyKit.ring(space, halfLength: h, beam: beam)
        let bowAhead = space.depth(h, 0) >= 0

        NavyKit.ringBehind(&svg, ring)
        if pose == .walking { NavyKit.wake(&svg, space, hull: hull, frame: frame, churn: false) }
        if pose == .fighting, !bowAhead { shots(&svg, space, frame) }
        if !bowAhead { head(&svg, space) }

        drawHull(&svg, space, rim: rim, nearRim: nearRim, nearWater: nearWater)

        // What stands on the deck, above the near rail, from the farthest to the nearest.
        NavyKit.clipped(&svg, id: "navy-alchemy-above", NavyHull.above(nearRim)) { svg in
            let parts: [(depth: Double, draw: (inout SVG) -> Void)] = [
                (space.depth(-64, 0), { sterncastle(&$0, space) }),
                (space.depth(57, 0), { forecastle(&$0, space, pose, frame) }),
                (space.depth(mizzen.x, 0), { mizzenMast(&$0, space, pose, frame) }),
                (space.depth(main.x, 0), { squareMast(&$0, space, view, pose, frame, main.x, main.head, course: (-78, 28, 38), top: (-122, 21, 40)) }),
                (space.depth(fore.x, 0), { squareMast(&$0, space, view, pose, frame, fore.x, fore.head, course: (-72, 24, 36), top: (-112, 18, 34)) }),
            ]
            let order = parts.indices.sorted { parts[$0].depth == parts[$1].depth ? $0 < $1 : parts[$0].depth < parts[$1].depth }
            for i in order { parts[i].draw(&svg) }
        }
        rigging(&svg, space)
        for mast in [fore, main] {
            NavyKit.flag(&svg, at: space.at(mast.x, mast.head + 1, 0), length: 16, height: 4.2, streaming: pose == .walking, frame: frame,
                         pennant: true)
        }
        // The ensign on its staff at the stern.
        let staffFoot = V(-h - 1, -48, 0), staffTop = V(-h - 3, -66, 0)
        NavyKit.spar(&svg, space, staffFoot, staffTop, width: 1.2, colour: K.darkWood)
        NavyKit.flag(&svg, at: space.at(staffTop) + P(-0.4, 0.6), length: 17, height: 10, streaming: pose == .walking, frame: frame, edge: K.gilt)
        if bowAhead { head(&svg, space) }

        NavyKit.waterInFront(&svg, nearWater: nearWater, ring)
        if pose == .walking {
            NavyKit.bowWave(&svg, space, hull: hull, stem: h * 0.95, frame: frame)
        } else {
            NavyKit.lapping(&svg, ring, frame: frame)
        }
        if pose == .fighting, bowAhead { shots(&svg, space, frame) }
    }

    /// The hull's side toward the viewer, painted and pierced for its guns, and the deck inside the rail.
    static func drawHull(_ svg: inout SVG, _ space: Space, rim: [P], nearRim: [P], nearWater: [P]) {
        let side = NavyHull.side(nearRim, nearWater)
        svg.polygon(side.map { $0 + P(-0.9, 0.7) }, fill: .colour(K.darkWood))
        NavyKit.clipped(&svg, id: "navy-alchemy-side", side) { svg in
            var seams = PathData()
            for k in stride(from: 10.0, through: 22, by: 2.6) {
                for (i, p) in nearRim.enumerated() { if i == 0 { seams.move(p + P(0, k)) } else { seams.line(p + P(0, k)) } }
            }
            svg.path(seams, stroke: .colour(K.wood), width: 0.6, opacity: 0.8)
            svg.polygon(nearWater + nearWater.reversed().map { $0 + P(0, -3.4) }, fill: .colour(IronBoatInk.tar), opacity: 0.85)
            svg.polygon(NavyHull.band(nearRim, 1.4, 8), fill: .team)
            for k in [10.8, 14.2] {
                svg.line(nearRim.map { $0 + P(0, k) }, stroke: NavyKit.line, width: 2.2)
                svg.line(nearRim.map { $0 + P(0, k) }, stroke: .colour(K.wood), width: 1)
            }
            for k in [1.4, 8.0] {
                svg.line(nearRim.map { $0 + P(0, k) }, stroke: NavyKit.line, width: 1.6)
                svg.line(nearRim.map { $0 + P(0, k) }, stroke: .colour(K.gilt), width: 0.8)
            }
        }
        for s in [-1.0, 1.0] where NavyHull.faces(space, side: s) && abs(space.c) > 0.3 {
            for x in ports { gunPort(&svg, space, x: x, side: s) }
        }
        // The transom, where it faces the viewer: gilt-framed windows over the rudder.
        if space.s < -0.3 { transom(&svg, space) }
        svg.polygon(side, fill: .none, stroke: NavyKit.line, width: 1.5)

        // The deck: planks inside the rail, and a grating amidships.
        svg.polygon(rim, fill: .colour(K.wood))
        NavyKit.clipped(&svg, id: "navy-alchemy-deck", rim) { svg in
            svg.polygon(hull.rim(space, inset: 0.9, lower: 3), fill: .colour(K.paleWood))
            var planks = PathData()
            for k in [-0.6, -0.3, 0.0, 0.3, 0.6] {
                for (i, x) in hull.stations.enumerated() {
                    let p = space.at(x, hull.gunwale(x) + 3, hull.halfBeam(x) * 0.9 * k)
                    if i == 0 { planks.move(p) } else { planks.line(p) }
                }
            }
            svg.path(planks, stroke: .colour(K.wood), width: 0.5, opacity: 0.7)
            let g = hull.gunwale(-20) + 3
            let grating = [V(-28, g, -4.4), V(-14, g, -4.4), V(-14, g, 4.4), V(-28, g, 4.4)].map(space.at)
            svg.polygon(grating, fill: .colour(K.darkWood), stroke: NavyKit.line, width: 0.7)
        }
        svg.polygon(rim, fill: .none, stroke: NavyKit.line, width: 1.1)
        svg.line(nearRim.map { $0 + P(0, 0.6) }, stroke: .colour(K.paleGilt), width: 0.7)
    }

    /// A gun port on one side: the dark opening, its lid raised and lined in wine, and the gun's muzzle run out.
    static func gunPort(_ svg: inout SVG, _ space: Space, x: Double, side: Double) {
        let g = hull.gunwale(x), hb = hull.halfBeam(x)
        func on(_ dx: Double, _ down: Double) -> P { space.at(hull.onSide(x + dx, down: down, side: side)) }
        let opening = [on(-2.2, 2.8), on(2.2, 2.8), on(2.2, 7), on(-2.2, 7)]
        let lid = [on(-2.2, 2.8), on(2.2, 2.8), space.at(V(x + 2.2, g - 0.6, side * (hb + 2.6))), space.at(V(x - 2.2, g - 0.6, side * (hb + 2.6)))]
        NavyKit.shape(&svg, lid, .colour(K.wine), width: 0.6)
        svg.polygon(opening, fill: .colour(K.velvet), stroke: NavyKit.line, width: 0.6)
        NavyKit.barrel(&svg, space, breech: hull.onSide(x, down: 4.9, side: side), muzzle: V(x, g + 4.9, side * (hb + 3.4)), width: 1.9,
                       colour: W.barrel, ring: K.ironDark)
    }

    /// The transom seen from astern: a gilt moulding and stern windows.
    static func transom(_ svg: inout SVG, _ space: Space) {
        let x = -halfLength, hb = hull.halfBeam(x) * 0.8
        for k in [-0.55, 0.0, 0.55] {
            let z = k * hb
            let window = [V(x, -16, z - 1.8), V(x, -16, z + 1.8), V(x, -12, z + 1.8), V(x, -12, z - 1.8)].map(space.at)
            NavyKit.shape(&svg, window, .colour(K.glassShade), width: 0.6)
        }
        svg.line([space.at(x, -9, -hull.halfBeam(x)), space.at(x, -9, hull.halfBeam(x))], stroke: .colour(K.gilt), width: 1)
        // The rudder hung on the sternpost.
        svg.line([space.at(x - 0.5, -12, 0), space.at(x - 1.6, 2, 0)], stroke: NavyKit.line, width: 3.4)
        svg.line([space.at(x - 0.5, -12, 0), space.at(x - 1.6, 2, 0)], stroke: .colour(K.wood), width: 2)
    }

    /// The beakhead: the stem rising to a gilt lion, the head rails, and the bowsprit over it.
    static func head(_ svg: inout SVG, _ space: Space) {
        let h = halfLength
        NavyKit.post(&svg, space, [V(h * 0.9, 0, 0), V(h + 3, -9, 0), V(h + 6, -17, 0), V(h + 9, -22, 0)], width: 3, colour: K.darkWood)
        // The head rails, curving from the bows to the stem head.
        for side in [-1.0, 1.0] {
            NavyKit.post(&svg, space, [V(h - 8, hull.gunwale(h - 8) + 2, side * hull.halfBeam(h - 8) * 0.9), V(h + 2, -18, side * 2.6),
                                       V(h + 8, -21, side * 0.6)], width: 1, colour: K.gilt)
        }
        let lion = space.at(h + 9.6, -23.4, 0)
        svg.circle(lion + P(-0.4, 0.4), 3.2, fill: .colour(K.gilt))
        svg.circle(lion, 3.2, fill: .none, stroke: NavyKit.line, width: 0.8)
        svg.circle(lion + P(0.8, -0.6), 1.5, fill: .colour(K.darkGilt))
        NavyKit.spar(&svg, space, bowspritFoot, bowspritEnd, width: 2.2, colour: K.wood)
    }

    /// The sterncastle: two tiers of wine-red timber, gilt rails and windows, and a lantern on the taffrail.
    static func sterncastle(_ svg: inout SVG, _ space: Space) {
        typealias T = IndustrialTrawler
        let shades = [K.wine, K.paleWine, K.darkWine, K.darkWine]
        func tier(x0: Double, x1: Double, z: Double, bottom: Double, top: Double, windows: Int) {
            for (face, shade) in T.faces(space, x0: x0, x1: x1, z0: -z, z1: z, bottom: bottom, top: top) {
                NavyKit.shape(&svg, T.panel(space, face, 0, 0, 1, 1), .colour(shades[shade]), width: 1)
                let count = shade == 1 || shade == 2 ? 2 : windows
                for k in 0..<count {
                    let w = 0.8 / Double(count), u = 0.1 + Double(k) * w
                    NavyKit.shape(&svg, T.panel(space, face, u + w * 0.15, 0.3, u + w * 0.85, 0.75), .colour(K.gilt), width: 0.6)
                    svg.polygon(T.panel(space, face, u + w * 0.28, 0.38, u + w * 0.72, 0.67), fill: .colour(K.glassShade))
                }
                svg.line([face.at(0, 1), face.at(1, 1)].map(space.at), stroke: .colour(K.gilt), width: 1.2)
            }
            NavyKit.shape(&svg, T.lid(space, x0: x0, x1: x1, z0: -z, z1: z, at: top), .colour(K.paleWood), width: 0.9)
        }
        tier(x0: -76, x1: -50, z: 8.6, bottom: hull.gunwale(-64) + 1, top: -38, windows: 3)
        tier(x0: -76, x1: -62, z: 7.4, bottom: -38, top: -47, windows: 2)
        // The lantern on the taffrail.
        let foot = space.at(-75, -47, 0)
        svg.line([foot, foot + P(0, -4)], stroke: NavyKit.line, width: 1.2)
        NavyKit.shape(&svg, [foot + P(-2, -4), foot + P(2, -4), foot + P(2.6, -9), foot + P(0, -11), foot + P(-2.6, -9)], .colour(K.paleGilt),
                      width: 0.7)
    }

    /// The forecastle: wine-red timber under a gilt rail, its forward face pierced for the bow chasers, run in after each shot.
    static func forecastle(_ svg: inout SVG, _ space: Space, _ pose: SpritePose, _ frame: Int) {
        typealias T = IndustrialTrawler
        let (x0, x1, z) = (48.0, 66.0, 7.8)
        let bottom = hull.gunwale(57) + 1, top = -32.0
        let shades = [K.wine, K.paleWine, K.darkWine, K.darkWine]
        // The chasers behind the forward face, when it turns away from the viewer.
        if space.s <= 0.01 { for chaser in chasers { chaserGun(&svg, space, chaser, pose, frame) } }
        for (face, shade) in T.faces(space, x0: x0, x1: x1, z0: -z, z1: z, bottom: bottom, top: top) {
            NavyKit.shape(&svg, T.panel(space, face, 0, 0, 1, 1), .colour(shades[shade]), width: 1)
            if shade == 1 {
                for u in [0.27, 0.73] { svg.polygon(T.panel(space, face, u - 0.12, 0.38, u + 0.12, 0.82), fill: .colour(K.velvet)) }
            }
            svg.line([face.at(0, 1), face.at(1, 1)].map(space.at), stroke: .colour(K.gilt), width: 1.2)
        }
        NavyKit.shape(&svg, T.lid(space, x0: x0, x1: x1, z0: -z, z1: z, at: top), .colour(K.paleWood), width: 0.9)
        if space.s > 0.01 { for chaser in chasers { chaserGun(&svg, space, chaser, pose, frame) } }
    }

    /// Where a chaser's muzzle is in a frame, run in by its recoil.
    static func chaserMuzzle(_ chaser: (z: Double, fires: Int), _ pose: SpritePose, _ frame: Int) -> V {
        let recoil = pose == .fighting ? NavyKit.recoil(frame, fires: chaser.fires, by: 3) : 0
        return V(71 - recoil, chaserY, chaser.z)
    }

    static func chaserGun(_ svg: inout SVG, _ space: Space, _ chaser: (z: Double, fires: Int), _ pose: SpritePose, _ frame: Int) {
        let muzzle = chaserMuzzle(chaser, pose, frame)
        NavyKit.barrel(&svg, space, breech: muzzle + V(-9, 0, 0), muzzle: muzzle, width: 2.2, colour: W.barrel, ring: K.ironDark)
    }

    /// A mast with a course and a topsail: the courses furled at rest and in a fight, every sail set and full under way.
    static func squareMast(_ svg: inout SVG, _ space: Space, _ view: SpriteView, _ pose: SpritePose, _ frame: Int, _ x: Double, _ head: Double,
                           course: (y: Double, half: Double, drop: Double), top: (y: Double, half: Double, drop: Double)) {
        NavyKit.spar(&svg, space, V(x, hull.gunwale(x) + 3, 0), V(x, head, 0), width: 2.6, colour: K.wood)
        // The top: a round platform where the topmast is stepped.
        let platform = stride(from: 0.0, to: 360, by: 30).map { a in space.at(x + 4 * cos(a * .pi / 180), course.y - 8, 4 * sin(a * .pi / 180)) }
        NavyKit.shape(&svg, platform, .colour(K.wood), width: 0.7)
        svg.circle(space.at(x, head, 0), 1.6, fill: .colour(K.paleGilt), stroke: NavyKit.line, width: 0.6)
        let degrees = NavyKit.brace(view)
        let full = pose == .walking
        let breath = 0.6 * sin(NavyKit.turn(frame) * (full ? 2 : 1))
        func set(_ y: Double, _ half: Double, _ drop: Double, belly: Double) {
            let sail = NavyKit.SquareSail(head: V(x, y, 0), half: half, drop: drop, degrees: degrees, belly: belly)
            NavyKit.squareSail(&svg, space, sail, canvas: K.light, seam: K.shadeLight, yard: K.wood) { svg, sail in
                svg.polygon(sail.outline(space, from: -0.13, to: 0.13), fill: .team)
                svg.polygon(sail.outline(space, t0: 0.4, t1: 0.58), fill: .team)
            }
        }
        if full {
            set(course.y, course.half, course.drop, belly: 8 + breath)
        } else {
            NavyKit.furled(&svg, space, head: V(x, course.y, 0), half: course.half, degrees: degrees, canvas: K.light, yard: K.wood)
        }
        set(top.y, top.half, top.drop, belly: (full ? 6 : pose == .fighting ? 3.6 : 2.4) + breath)
    }

    /// The mizzen with its lateen: the long yard slanting up aft, and the sail beneath it, filling a little under way.
    static func mizzenMast(_ svg: inout SVG, _ space: Space, _ pose: SpritePose, _ frame: Int) {
        let x = mizzen.x
        NavyKit.spar(&svg, space, V(x, hull.gunwale(x) + 3, 0), V(x, mizzen.head, 0), width: 2.2, colour: K.wood)
        let low = V(x + 20, -62, 0), high = V(x - 22, -110, 0), clew = V(x - 20, -50, 0)
        let fill = (pose == .walking ? 5 : 2) + 0.5 * sin(NavyKit.turn(frame))
        func point(_ a: Double, _ b: Double) -> V {
            // a along the yard from the low end, b down toward the clew.
            let top = low + (high - low) * a
            let p = top + (clew - top) * b
            return p + V(0, 0, fill * sin(.pi * a) * sin(.pi * min(b * 1.2, 1)))
        }
        var outline: [V] = []
        for i in 0...8 { outline.append(point(Double(i) / 8, 0)) }
        for i in 1...6 { outline.append(point(1, Double(i) / 6)) }
        for i in 1..<6 { outline.append(point(0, 1 - Double(i) / 6)) }
        let points = outline.map(space.at)
        svg.polygon(points.map { $0 + P(-0.6, 0.5) }, fill: .colour(K.light))
        svg.polygon(points, fill: .none, stroke: NavyKit.line, width: 0.9)
        NavyKit.spar(&svg, space, low + (low - high) * 0.06, high, width: 1.4, colour: K.wood)
        svg.circle(space.at(x, mizzen.head, 0), 1.4, fill: .colour(K.paleGilt), stroke: NavyKit.line, width: 0.6)
    }

    /// The stays between the mastheads and to the bowsprit, and the shrouds from each top to the rails.
    static func rigging(_ svg: inout SVG, _ space: Space) {
        var pairs: [(V, V)] = [
            (V(fore.x, fore.head + 2, 0), bowspritEnd), (V(fore.x, -80, 0), V(halfLength + 6, -20, 0)),
            (V(main.x, main.head + 2, 0), V(fore.x, -86, 0)), (V(mizzen.x, mizzen.head + 2, 0), V(main.x, -92, 0)),
            (V(mizzen.x, mizzen.head + 2, 0), V(-halfLength, -47, 0)),
        ]
        for (x, top) in [(fore.x, -80.0), (main.x, -86.0), (mizzen.x, -78.0)] {
            for side in [-1.0, 1.0] {
                for dx in [-3.0, -7.0] { pairs.append((V(x, top, side * 3.4), V(x + dx, hull.gunwale(x + dx), side * hull.halfBeam(x + dx)))) }
            }
        }
        NavyKit.rigging(&svg, space, pairs)
    }

    /// The chasers' shots: each one's smoke through the cycle, and its flash in the frame it fires and the next.
    static func shots(_ svg: inout SVG, _ space: Space, _ frame: Int) {
        // The farther gun's shot first.
        let order = chasers.sorted { space.depth(0, $0.z) < space.depth(0, $1.z) }
        for chaser in order {
            let age = NavyKit.since(frame, fires: chaser.fires)
            let muzzle = chaserMuzzle(chaser, .fighting, frame)
            NavyKit.smoke(&svg, space, muzzle: muzzle + V(1.5, 0, 0), along: V(1, 0, 0), age: age, scale: 1.4)
            if age < 0.1 {
                NavyKit.flash(&svg, space, muzzle: muzzle + V(1.2, 0, 0), along: V(1, 0, 0), size: age == 0 ? 15 : 8, flash: W.flash, core: W.flashCore)
            }
        }
    }
}
