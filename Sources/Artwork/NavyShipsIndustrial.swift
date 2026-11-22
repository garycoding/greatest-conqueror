// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The navy ship in the Industrial look: an ironclad under steam, half as long
// again as the Industrial age's steam trawler and painted as it is, so that
// the two read as one age. A low black iron hull with a ram bow, a bottle-green
// boot top along the water, a ribbon of the team's colour under the rail, a
// row of portholes and the plating's seams; a deck of planks. Forward, a
// turret of soot-grey iron, banded in the team's colour, with two long guns
// trained ahead; behind it a conning bridge of the light colour and the
// foremast with its fighting top and the team's pennant; amidships a central
// battery of the light colour, a gun looking out of each side, and on it two
// funnels of soot grey with black tops and a band of the team's colour
// between rims of the light colour; aft a deckhouse, the mainmast, and the
// team's ensign on its staff at the stern.
//
// Standing, the ironclad lies at rest, riding the water, a thin wisp rising
// from each funnel. Walking, it goes under steam: smoke pours from the funnels
// and streams aft, the bow pushes up a wave, the screw churns the water at the
// stern and a wake spreads behind, and the flags stream. Fighting, it lies
// with its bow on the target and the turret's two guns fire together, with a
// flash at each muzzle; they run in and out again, and the smoke rolls
// forward and rises whilst the funnels smoke. Every cycle is periodic in its
// 12 frames. The origin is on the waterline at the middle of the hull; the
// ship casts no shadow.

enum NavyShipIndustrial {
    typealias Space = StoneDugout.Space
    typealias V = StoneDugout.V
    typealias K = IndustrialPeopleInk
    typealias I = IndustrialOldBuildingsInk

    /// Room for the hull in every view, the masts, the funnels' smoke, the guns' smoke ahead, the wake and the ring.
    static let canvas = Canvas(minX: -126, minY: -136, width: 268, height: 198, pixelsPerUnit: Canvas.person.pixelsPerUnit)

    /// The hull's half length and half beam: half as long again as the trawler's (`IndustrialTrawler`).
    static let halfLength = 78.0, beam = 15.0
    static let hull = NavyHull(halfLength: halfLength, waterReach: 0.92, halfBeam: { x in
        let f = min(abs(x) / halfLength, 1)
        return beam * max(0, 1 - pow(f, x >= 0 ? 2.2 : 3.2)).squareRoot()
    }, gunwale: { x in
        let f = min(abs(x) / halfLength, 1)
        return -(12 + (x >= 0 ? 6 : 1.5) * f * f)
    })

    /// The deck's height at `x`, a little below the rail.
    static func deck(_ x: Double) -> Double { hull.gunwale(x) + 2 }

    /// The turret: its centre along the hull, its radius and its top; the guns' height, spread and length; and the frame they fire in.
    static let turretX = 46.0, turretRadius = 8.5, turretTop = -24.0
    static let gunY = -20.0, gunSpread = 2.6, fires = 1
    /// The funnels, their radius, and their tops.
    static let funnels: [Double] = [-4, -22], funnelRadius = 4.4, funnelTop = -64.0
    /// The masts.
    static let foremast = (x: 12.0, head: -100.0), mainmast = (x: -48.0, head: -82.0)

    // MARK: Drawing

    static func draw(_ svg: inout SVG, _ view: SpriteView, _ pose: SpritePose, _ frame: Int) {
        let h = halfLength
        let space = Space(view, rise: NavyKit.bob(pose, frame, shots: pose == .fighting ? [fires] : []))
        let rim = hull.rim(space), water = hull.waterline(space)
        let nearRim = StoneDugout.nearChain(rim), nearWater = StoneDugout.nearChain(water)
        let ring = NavyKit.ring(space, halfLength: h, beam: beam)
        let bowAhead = space.depth(h, 0) >= 0
        let recoil = pose == .fighting ? NavyKit.recoil(frame, fires: fires, by: 4) : 0

        NavyKit.ringBehind(&svg, ring)
        if pose == .walking { NavyKit.wake(&svg, space, hull: hull, frame: frame, churn: true) }
        if pose == .fighting, !bowAhead { shot(&svg, space, frame, recoil: recoil) }
        if !bowAhead { ram(&svg, space) }

        drawHull(&svg, space, rim: rim, nearRim: nearRim, nearWater: nearWater)

        NavyKit.clipped(&svg, id: "navy-industrial-above", NavyHull.above(nearRim)) { svg in
            let parts: [(depth: Double, draw: (inout SVG) -> Void)] = [
                (space.depth(-47, 0), { deckhouse(&$0, space) }),
                (space.depth(mainmast.x, 0), { mast(&$0, space, mainmast.x, head: mainmast.head, top: nil) }),
                (space.depth(-13, 0), { battery(&$0, space) }),
                (space.depth(funnels[1], 0), { funnel(&$0, space, at: funnels[1]) }),
                (space.depth(funnels[0], 0), { funnel(&$0, space, at: funnels[0]) }),
                (space.depth(foremast.x, 0), { mast(&$0, space, foremast.x, head: foremast.head, top: -74) }),
                (space.depth(25, 0), { bridge(&$0, space) }),
                (space.depth(turretX, 0), { turret(&$0, space, recoil: recoil) }),
            ]
            let order = parts.indices.sorted { parts[$0].depth == parts[$1].depth ? $0 < $1 : parts[$0].depth < parts[$1].depth }
            for i in order { parts[i].draw(&svg) }
        }
        NavyKit.rigging(&svg, space, [
            (V(foremast.x, foremast.head + 2, 0), V(h + 0.5, hull.gunwale(h), 0)), (V(foremast.x, foremast.head + 2, 0), V(mainmast.x, mainmast.head + 2, 0)),
            (V(mainmast.x, mainmast.head + 2, 0), V(-h + 1, deck(-h), 0)),
        ])
        NavyKit.flag(&svg, at: space.at(foremast.x, foremast.head + 1, 0), length: 16, height: 4.2, streaming: pose == .walking, frame: frame,
                     pennant: true)
        let staffFoot = V(-h + 2, deck(-h + 2), 0), staffTop = V(-h + 1, -34, 0)
        NavyKit.spar(&svg, space, staffFoot, staffTop, width: 1.1, colour: K.wood)
        NavyKit.flag(&svg, at: space.at(staffTop) + P(-0.4, 0.6), length: 15, height: 9, streaming: pose == .walking, frame: frame)
        if bowAhead { ram(&svg, space) }

        NavyKit.waterInFront(&svg, nearWater: nearWater, ring)
        if pose == .walking {
            NavyKit.bowWave(&svg, space, hull: hull, stem: h * 0.98, frame: frame)
        } else {
            NavyKit.lapping(&svg, ring, frame: frame)
        }
        smoke(&svg, space, pose, frame)
        if pose == .fighting, bowAhead { shot(&svg, space, frame, recoil: recoil) }
    }

    /// The black hull's side toward the viewer, its boot top, ribbon, seams and portholes, and the deck inside the rail.
    static func drawHull(_ svg: inout SVG, _ space: Space, rim: [P], nearRim: [P], nearWater: [P]) {
        let side = NavyHull.side(nearRim, nearWater)
        svg.polygon(side.map { $0 + P(-0.9, 0.7) }, fill: .colour(K.black))
        NavyKit.clipped(&svg, id: "navy-industrial-side", side) { svg in
            svg.polygon(nearWater + nearWater.reversed().map { $0 + P(0, -3.4) }, fill: .colour(I.green))
            svg.line(nearWater.map { $0 + P(0, -3.4) }, stroke: NavyKit.line, width: 0.6)
            var seams = PathData()
            let usable = nearRim.indices.filter { $0 > 2 && $0 < nearRim.count - 3 }
            for i in usable where i % 3 == 0 {
                let top = nearRim[i] + P(0, 4), foot = nearWater.min { abs($0.x - top.x) < abs($1.x - top.x) } ?? top
                if foot.y - top.y > 5 { seams.move(top); seams.line(foot + P(0, -3.6)) }
            }
            for (i, p) in nearRim.enumerated() { if i == 0 { seams.move(p + P(0, 8.6)) } else { seams.line(p + P(0, 8.6)) } }
            svg.path(seams, stroke: .colour(K.blackSheen), width: 0.5, opacity: 0.9)
            svg.polygon(NavyHull.band(nearRim, 1.6, 3.8), fill: .team)
        }
        for s in [-1.0, 1.0] where NavyHull.faces(space, side: s) && abs(space.c) > 0.3 {
            for x in stride(from: -60.0, through: 60, by: 10) {
                svg.ellipse(space.at(hull.onSide(x, down: 6.4, side: s)), 1.1 * abs(space.c) + 0.3, 1.1, fill: .colour(I.glassDark),
                            stroke: .colour(K.brass), width: 0.5)
            }
        }
        svg.polygon(side, fill: .none, stroke: NavyKit.line, width: 1.5)
        svg.polygon(rim, fill: .colour(K.shadeLight))
        NavyKit.clipped(&svg, id: "navy-industrial-deck", rim) { svg in
            svg.polygon(hull.rim(space, inset: 0.92, lower: 2), fill: .colour(K.paleWood))
            var planks = PathData()
            for k in [-0.6, -0.3, 0.0, 0.3, 0.6] {
                for (i, x) in hull.stations.enumerated() {
                    let p = space.at(x, deck(x), hull.halfBeam(x) * 0.92 * k)
                    if i == 0 { planks.move(p) } else { planks.line(p) }
                }
            }
            svg.path(planks, stroke: .colour(K.wood), width: 0.5, opacity: 0.6)
        }
        svg.polygon(rim, fill: .none, stroke: NavyKit.line, width: 1.1)
        svg.line(nearRim.map { $0 + P(0, 0.7) }, stroke: .colour(K.light), width: 0.8)
    }

    /// The ram: the stem raking forward from the rail to a point at the waterline.
    static func ram(_ svg: inout SVG, _ space: Space) {
        let h = halfLength
        let tip = V(h + 9, 0.8, 0)
        let points = [V(h * 0.9, hull.gunwale(h * 0.9), -1.6), V(h * 0.9, hull.gunwale(h * 0.9), 1.6), V(h + 0.6, hull.gunwale(h), 0),
                      V(h * 0.86, 2.4, -2.4), V(h * 0.86, 2.4, 2.4), tip]
        NavyKit.shape(&svg, StoneDugout.outline(points.map(space.at)), .colour(K.black), width: 1.2)
        svg.line([space.at(h + 0.6, hull.gunwale(h), 0), space.at(tip)], stroke: .colour(K.blackSheen), width: 0.8)
    }

    // MARK: On deck

    /// A box on the deck in the light colour, with portholes or windows along its sides, and a soot-grey top.
    static func box(_ svg: inout SVG, _ space: Space, x0: Double, x1: Double, z: Double, bottom: Double, top: Double, windows: Bool) {
        typealias T = IndustrialTrawler
        let shades = [K.light, K.light, K.shadeLight, K.shadeLight]
        for (face, shade) in T.faces(space, x0: x0, x1: x1, z0: -z, z1: z, bottom: bottom, top: top) {
            NavyKit.shape(&svg, T.panel(space, face, 0, 0, 1, 1), .colour(shades[shade]), width: 1)
            let long = shade == 0 || shade == 3
            let count = long ? max(2, Int((x1 - x0) / 7)) : 2
            for k in 0..<count {
                let w = 0.84 / Double(count), u = 0.08 + Double(k) * w + w / 2
                if windows {
                    svg.polygon(T.panel(space, face, u - w * 0.3, 0.55, u + w * 0.3, 0.85), fill: .colour(I.glass), stroke: NavyKit.line, width: 0.5)
                } else {
                    svg.circle(space.at(face.at(u, 0.6)), 0.9, fill: .colour(I.glassDark), stroke: .colour(K.brass), width: 0.4)
                }
            }
        }
        NavyKit.shape(&svg, T.lid(space, x0: x0, x1: x1, z0: -z, z1: z, at: top), .colour(K.paleSoot), width: 0.9)
    }

    static func deckhouse(_ svg: inout SVG, _ space: Space) {
        box(&svg, space, x0: -56, x1: -40, z: 6, bottom: deck(-48), top: -21, windows: false)
    }

    /// The central battery, a gun looking out of each side.
    static func battery(_ svg: inout SVG, _ space: Space) {
        let z = 10.0
        for side in [-1.0, 1.0] where !NavyHull.faces(space, side: side) { sideGuns(&svg, space, side: side, z: z) }
        box(&svg, space, x0: -36, x1: 10, z: z, bottom: deck(-13), top: -25, windows: false)
        for side in [-1.0, 1.0] where NavyHull.faces(space, side: side) { sideGuns(&svg, space, side: side, z: z) }
    }

    static func sideGuns(_ svg: inout SVG, _ space: Space, side: Double, z: Double) {
        for x in [-26.0, 0] {
            NavyKit.barrel(&svg, space, breech: V(x, -19, side * (z - 1)), muzzle: V(x, -19, side * (z + 7)), width: 2, colour: K.iron, ring: K.ironDark)
        }
    }

    /// The conning bridge: a deckhouse of the light colour with windows all round, its wings out to either side.
    static func bridge(_ svg: inout SVG, _ space: Space) {
        box(&svg, space, x0: 19, x1: 31, z: 6, bottom: deck(25), top: -36, windows: true)
        let wing = [V(22, -36.4, -12), V(28, -36.4, -12), V(28, -36.4, 12), V(22, -36.4, 12)].map(space.at)
        NavyKit.shape(&svg, wing, .colour(K.paleWood), width: 0.8)
    }

    /// A mast, with a fighting top (a round iron platform) where `top` is given, and a yard near its head.
    static func mast(_ svg: inout SVG, _ space: Space, _ x: Double, head: Double, top: Double?) {
        NavyKit.spar(&svg, space, V(x, deck(x), 0), V(x, head, 0), width: 2.2, colour: K.paleWood)
        let yard = head + 10
        NavyKit.spar(&svg, space, V(x, yard, -9), V(x, yard, 9), width: 1.2, colour: K.paleWood)
        if let top {
            let ring = stride(from: 0.0, to: 360, by: 30).map { a in V(x + 4.4 * cos(a * .pi / 180), top, 4.4 * sin(a * .pi / 180)) }
            let wall = ring.map { space.at($0) } + ring.reversed().map { space.at($0 + V(0, -4, 0)) }
            NavyKit.shape(&svg, StoneDugout.outline(wall), .colour(K.soot), width: 0.8)
            svg.polygon(StoneDugout.outline(ring.map { space.at($0 + V(0, -4, 0)) }), fill: .colour(K.darkSoot), stroke: NavyKit.line, width: 0.6)
        }
        svg.circle(space.at(x, head, 0), 1.4, fill: .colour(K.paleWood), stroke: NavyKit.line, width: 0.6)
    }

    /// A funnel on the battery: a cylinder of soot grey, a black top, and a band of the team's colour between two rims of the light colour.
    static func funnel(_ svg: inout SVG, _ space: Space, at x: Double) {
        let base = -25.0, r = funnelRadius
        func on(_ y: Double, _ a: Double) -> P { space.at(x + r * cos(a * .pi / 180), y, r * 1.1 * sin(a * .pi / 180)) }
        func near(_ y: Double) -> [P] {
            let facing = atan2(space.c, space.s) * 180 / .pi
            return stride(from: facing + 90, through: facing - 90, by: -15).map { on(y, $0) }.sorted { $0.x < $1.x }
        }
        func band(_ y0: Double, _ y1: Double, _ fill: Paint) { svg.polygon(near(y0) + near(y1).reversed(), fill: fill) }
        let body = near(base) + near(funnelTop).reversed()
        svg.polygon(body.map { $0 + P(-0.6, 0.5) }, fill: .colour(K.soot))
        let low = near(base), high = near(funnelTop)
        svg.polygon([low[low.count - 3], low.last!, high.last!, high[high.count - 3]], fill: .colour(K.darkSoot), opacity: 0.7)
        band(-44, -45.6, .colour(K.light))
        band(-45.6, -52.4, .team)
        band(-52.4, -54, .colour(K.light))
        band(-59, funnelTop, .colour(K.coal))
        for y in [-44.0, -45.6, -52.4, -54, -59] { svg.line(near(y), stroke: NavyKit.line, width: 0.6) }
        svg.polygon(body, fill: .none, stroke: NavyKit.line, width: 1.1)
        let mouth = stride(from: 0.0, to: 360, by: 20).map { on(funnelTop, $0) }
        svg.polygon(mouth, fill: .colour(K.coal), stroke: NavyKit.line, width: 0.9)
    }

    /// The turret: a drum of soot-grey iron banded in the team's colour, a lighter top with a hatch, and the two guns trained ahead.
    static func turret(_ svg: inout SVG, _ space: Space, recoil: Double) {
        let x = turretX, r = turretRadius, bottom = deck(x), top = turretTop
        func on(_ y: Double, _ a: Double) -> P { space.at(x + r * cos(a * .pi / 180), y, r * sin(a * .pi / 180)) }
        func near(_ y: Double) -> [P] {
            let facing = atan2(space.c, space.s) * 180 / .pi
            return stride(from: facing + 90, through: facing - 90, by: -10).map { on(y, $0) }.sorted { $0.x < $1.x }
        }
        // The guns behind the drum when it turns them away from the viewer.
        if space.s <= 0.01 { guns(&svg, space, recoil: recoil) }
        let body = near(bottom) + near(top).reversed()
        svg.polygon(body.map { $0 + P(-0.6, 0.5) }, fill: .colour(K.soot))
        let low = near(bottom), high = near(top)
        svg.polygon([low[low.count - 4], low.last!, high.last!, high[high.count - 4]], fill: .colour(K.darkSoot), opacity: 0.7)
        svg.polygon(near(top + 5.6) + near(top + 2.6).reversed(), fill: .team)
        for y in [top + 5.6, top + 2.6] { svg.line(near(y), stroke: NavyKit.line, width: 0.6) }
        svg.polygon(body, fill: .none, stroke: NavyKit.line, width: 1.1)
        let lid = stride(from: 0.0, to: 360, by: 15).map { on(top, $0) }
        NavyKit.shape(&svg, lid, .colour(K.paleSoot), width: 1)
        let hatch = stride(from: 0.0, to: 360, by: 30).map { a in space.at(x - 3 + 2.2 * cos(a * .pi / 180), top - 0.6, 2.2 * sin(a * .pi / 180)) }
        svg.polygon(hatch, fill: .colour(K.darkSoot), stroke: NavyKit.line, width: 0.6)
        if space.s > 0.01 { guns(&svg, space, recoil: recoil) }
    }

    /// Where a turret gun's muzzle is, `side` of the middle, run in by `recoil`.
    static func muzzle(_ side: Double, recoil: Double) -> V { V(turretX + 30 - recoil, gunY - 0.4, side * gunSpread) }

    static func guns(_ svg: inout SVG, _ space: Space, recoil: Double) {
        for side in [-1.0, 1.0].sorted(by: { space.depth(0, $0) < space.depth(0, $1) }) {
            let tip = muzzle(side, recoil: recoil)
            NavyKit.barrel(&svg, space, breech: V(turretX + 5, gunY, side * gunSpread), muzzle: tip, width: 2.4, colour: K.iron, ring: K.ironDark)
        }
    }

    /// The turret's shot: a flash at each muzzle in the frame they fire and the next, and the smoke through the cycle.
    static func shot(_ svg: inout SVG, _ space: Space, _ frame: Int, recoil: Double) {
        let age = NavyKit.since(frame, fires: fires)
        NavyKit.smoke(&svg, space, muzzle: muzzle(0, recoil: recoil) + V(1.5, 0, 0), along: V(1, 0, 0), age: age, scale: 1.2)
        guard age < 0.1 else { return }
        for side in [-1.0, 1.0].sorted(by: { space.depth(0, $0) < space.depth(0, $1) }) {
            NavyKit.flash(&svg, space, muzzle: muzzle(side, recoil: recoil) + V(1.2, 0, 0), along: V(1, 0, 0), size: age == 0 ? 13 : 7,
                          flash: AlchemyWarriorsInk.flash, core: AlchemyWarriorsInk.flashCore)
        }
    }

    /// The smoke from the funnels, as the trawler's (`IndustrialTrawler.smoke`): puffs leaving each mouth,
    /// growing and fading as they rise; under steam they stream aft, thick, and at rest a thin wisp rises nearly straight.
    static func smoke(_ svg: inout SVG, _ space: Space, _ pose: SpritePose, _ frame: Int) {
        let p = NavyKit.share(frame)
        let (count, aft, rise, size, grow, strength): (Int, Double, Double, Double, Double, Double) = switch pose {
        case .walking: (8, 50, 22, 3.8, 8, 1)
        case .fighting: (5, 16, 28, 2.8, 5, 0.85)
        default: (4, 6, 30, 2.4, 3.8, 0.8)
        }
        var puffs: [(age: Double, at: P, r: Double)] = []
        for (n, x) in funnels.enumerated() {
            for k in 0..<count {
                let age = (p + Double(k) / Double(count) + Double(n) * 0.37).truncatingRemainder(dividingBy: 1)
                let curl = 1.6 * sin(age * 7 + Double(k + n))
                let at = space.at(x - aft * age * (0.6 + 0.4 * age), funnelTop - 2 - rise * age * (1.2 - 0.3 * age), curl)
                puffs.append((age, at, size + grow * age))
            }
        }
        for puff in puffs.sorted(by: { $0.age > $1.age }) {
            let fade = strength * pow(1 - puff.age, 1.1) * min(1, puff.age * 6 + 0.25)
            IndustrialTrawler.billow(&svg, at: puff.at, radius: puff.r, opacity: fade, young: puff.age < 0.3)
        }
    }
}
