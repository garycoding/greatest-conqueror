// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The Bronze age's boat, the reed boat (ruled 2026-11-21): two long bundles of
// reed bound side by side, which merge at either end into a horn, the bow's
// curved up and the stern's raised high and curled back over the boat as the
// marsh boats' are; bound along their length with lashings in the team's
// colour. A boatman stands on a mat laid over the bundles, with a basket for
// the catch before him. He wears a linen tunic with a verdigris hem, the team's
// sash across the chest, and a conical hat of woven reed with a terracotta band
// (the mark of the kind); nose C, the hook.
//
// The hull lives in the dugout's space (`StoneDugout.Space`): x along it
// toward the bow, y downward with the waterline at 0, z toward its right
// (starboard); a view turns that space by its yaw and the water is a plane
// seen at the map's angle. A bundle is drawn as a thick line, which shows the
// same breadth from any side, so that the five views come from one drawing;
// what lies under the water is cut off by the near waterline. The boatman is
// drawn with the figure kit in the same view, standing, his hands on the pole
// or the net, which live in the hull's space.
//
// Standing, the boat rides the water and the boatman leans on his pole,
// planted upright beside the boat, and breathes; walking, he poles on the
// right side: the pole planted ahead, pushed back as the boat goes past it,
// drawn out and swung forward again, while the bow pushes a ripple and a wake
// spreads behind; working, he fishes with a hoop net on a pole: swung out,
// plunged, swept back under the water, lifted dripping with a fish in it, and
// tipped into the basket. Every cycle is periodic in its 12 frames. The origin
// is on the waterline at the middle of the hull; the boat casts no shadow.

enum BronzeReedBoat {
    typealias Space = StoneDugout.Space
    typealias V = StoneDugout.V

    /// Room for the hull and its horns in every view, the pole raised, the hat, and the ring about it.
    static let canvas = Canvas(minX: -82, minY: -112, width: 164, height: 154, pixelsPerUnit: Canvas.person.pixelsPerUnit)

    /// The bundles' half length to where they merge into the horns.
    static let halfLength = 40.0
    /// Where the boatman stands along the hull, and the height of the mat he stands on.
    static let seat = -13.0, deck = -11.0
    static let nose = Nose.hook

    /// Whether the boat has the pose: it has no attack, so no fighting.
    static func drawn(_ pose: SpritePose) -> Bool { pose == .standing || pose == .walking || pose == .working }

    /// A frame of a pose in a view, as a sprite's picture and mask, grained alike, on `canvas` or another scale of it.
    static func render(_ pose: SpritePose, frame: Int, view: SpriteView = .side, canvas: Canvas = BronzeReedBoat.canvas) -> Rendered? {
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

    /// The pole's phase: the push lasts longer than the swing forward.
    static func stroke(_ frame: Int) -> Double {
        let t = turn(frame)
        return t + 0.38 * sin(t)
    }

    /// How far the boat rises on the water in a frame.
    static func bob(_ pose: SpritePose, _ frame: Int) -> Double {
        let t = turn(frame)
        switch pose {
        case .walking: return 0.5 * sin(2 * stroke(frame) + 0.6)
        case .working: return 0.5 * sin(t) + (frame == 4 || frame == 5 ? 0.5 : 0)
        default: return 0.7 * sin(t)
        }
    }

    /// Where the hoop of the net is in each frame of the working pose (x from
    /// the place the boatman stands, y and z in the hull's space): swung out,
    /// plunged, swept back under the water more slowly, lifted with the catch,
    /// swung in over the basket to tip it, and out again; no step between two
    /// frames is much more than twice another's, so that it moves smoothly.
    static let sweep: [V] = [
        V(26, -44, 28), V(29, -22, 31), V(28, -2, 30), V(24, 9, 28), V(16, 13, 27), V(8, 11, 26),
        V(2, 3, 25), V(2, -14, 27), V(8, -30, 22), V(16, -36, 12), V(21, -26, 3), V(24, -38, 16),
    ]

    /// The skeleton's state: the stance, the lean, the breath and the face.
    static func rig(_ pose: SpritePose, _ frame: Int) -> Rig {
        var r = Rig()
        let t = turn(frame)
        r.backLeg = Limb(-12, 6); r.frontLeg = Limb(13, 9)
        switch pose {
        case .walking:
            // Leaning into the push as the pole goes back, upright as it swings forward.
            let s = stroke(frame)
            r.lean = 5 + 8 * sin(s - 0.4)
            r.lift = 0.4 * sin(t)
            r.frontLeg = Limb(13 + 4 * sin(s), 9 + 5 * max(0, sin(s)))
            r.mouth = .firm
        case .working:
            let aim = sweep[frame]
            r.lean = 2 + max(0, aim.y + 20) * 0.25 + aim.x * 0.1
            r.headTilt = 8 * min(max((aim.y + 40) / 40, 0), 1)
            r.eyes = aim.y > -20 ? .down : .open
            r.mouth = frame == 7 || frame == 8 ? .smile : .firm
        default:
            r.lean = 1
            r.lift = 0.8 * sin(t)
            r.eyes = frame == 8 ? .closed : .open
            r.backLeg = Limb(-7, 4); r.frontLeg = Limb(8, 5)
        }
        return r
    }

    // MARK: The hull

    /// The bundles' middle line's height, thickness and spread from the keel's line at `x` along the body.
    static func centre(_ x: Double) -> Double { -4.6 - 3.4 * pow(x / halfLength, 2) }
    static func radius(_ x: Double) -> Double { 7 - 1.4 * pow(x / halfLength, 2) }
    static func spread(_ x: Double) -> Double { 5.4 * (1 - pow(min(abs(x) / halfLength, 1), 4)) }

    /// Stations along the body from the stern to the bow.
    static let stations: [Double] = stride(from: -halfLength, through: halfLength + 0.01, by: 4).map { $0 }

    /// A point of a bundle's middle line, and its radius there.
    struct Knot { var at: V; var r: Double }

    /// One bundle along the body, the right one (`side` 1) or the left (-1).
    static func bundle(_ side: Double) -> [Knot] {
        stations.map { Knot(at: V($0, centre($0), side * spread($0)), r: radius($0)) }
    }

    /// The bow's horn, from where the bundles merge, curving up and a little back.
    static let bow: [Knot] = [(40, -8, 5.6), (43.6, -11.6, 5), (46.6, -16.6, 4.3), (48.6, -22.4, 3.6), (49.3, -28.4, 3),
                              (48.4, -33.4, 2.5), (46.4, -36.6, 2.1)].map { Knot(at: V($0.0, $0.1, 0), r: $0.2) }

    /// The stern's horn, rising higher and curling back over the boat.
    static let stern: [Knot] = [(-40, -8, 5.6), (-43.6, -11.8, 5), (-47, -17.6, 4.4), (-49.6, -24.6, 3.8), (-50.8, -31.6, 3.2),
                                (-50, -38, 2.7), (-47.6, -42.6, 2.3), (-44.4, -44.8, 2), (-41.4, -43.8, 1.7), (-39.8, -41, 1.5)]
        .map { Knot(at: V($0.0, $0.1, 0), r: $0.2) }

    /// The waterline all round: where each bundle's outer side meets the water.
    static func waterline(_ space: Space) -> [P] {
        let xs = stations.filter { abs(centre($0)) < radius($0) - 0.3 }
        func reach(_ x: Double) -> Double { spread(x) + (radius(x) * radius(x) - centre(x) * centre(x)).squareRoot() }
        return xs.map { space.at($0, 0, reach($0)) } + xs.reversed().map { space.at($0, 0, -reach($0)) }
    }

    /// A bundle drawn as a thick line: its outline (from the knot `outlineFrom` on),
    /// its reed, the streaks of the reeds along it, and its light along the top.
    static func tube(_ d: inout Drawing, _ space: Space, _ knots: [Knot], outlineFrom: Int = 0, colour: String = BronzeReedInk.reed) {
        let points = knots.map { space.at($0.at) }
        for i in outlineFrom..<(knots.count - 1) {
            let w = knots[i].r + knots[i + 1].r
            d.svg.line([points[i], points[i + 1]], stroke: .colour(Ink.line), width: w + 1.4)
        }
        for i in 0..<(knots.count - 1) {
            let w = knots[i].r + knots[i + 1].r
            d.svg.line([points[i], points[i + 1]], stroke: .colour(colour), width: w)
        }
        // The streaks of the reeds, and the light along the upper side.
        let radii = knots.map(\.r)
        d.svg.line(offset(points, radii.map { -0.42 * $0 }), stroke: .colour(BronzeReedInk.reedShade), width: 0.6)
        d.svg.line(offset(points, radii.map { 0.12 * $0 }), stroke: .colour(BronzeReedInk.reedShade), width: 0.45, opacity: 0.8)
        d.svg.line(offset(points, radii.map { 0.6 * $0 }), stroke: .colour(BronzeReedInk.reedLit), width: 0.9)
    }

    /// A line on the screen moved upward (to the left of its run where it runs
    /// to the right) by the amounts `by`, point by point.
    static func offset(_ points: [P], _ by: [Double]) -> [P] {
        points.indices.map { i in
            let a = points[max(i - 1, 0)], b = points[min(i + 1, points.count - 1)]
            var u = b - a
            let length = max((u.x * u.x + u.y * u.y).squareRoot(), 1e-6)
            u = u * (1 / length)
            var n = P(u.y, -u.x)
            if n.y > 0 { n = n * -1 }
            return points[i] + n * by[i]
        }
    }

    /// A lashing round a bundle at a knot: a band across the line on the screen, in the team's colour.
    static func lashing(_ d: inout Drawing, _ space: Space, at knot: Knot, toward next: V, width: Double = 2.2) {
        let a = space.at(knot.at), b = space.at(next)
        var u = b - a
        let length = max((u.x * u.x + u.y * u.y).squareRoot(), 1e-6)
        u = u * (1 / length)
        let across = P(-u.y, u.x) * (knot.r + 0.4)
        // Bent a little round the bundle, toward its near side.
        let bend = u * (u.y < 0 ? -0.7 : 0.7)
        let band = [a - across, a + bend, a + across]
        d.svg.line(band, stroke: .colour(Ink.line), width: width + 1.3)
        d.svg.line([a - across * 0.9, a + bend, a + across * 0.9], stroke: .team, width: width)
    }

    // MARK: Drawing

    static func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let space = Space(d.view, rise: bob(pose, frame))
        let water = waterline(space)
        let nearWater = StoneDugout.nearChain(water)

        // The water behind and about the boat.
        let ringCentre = space.at(0, 0, 0)
        let ringWidth = abs(48 * space.c) + abs(12 * space.s) + 6
        let ringDepth = max(0.12, StoneDugout.pitch * (abs(48 * space.s) + abs(12 * space.c) + 3) / ringWidth)
        StoneBoatsWater.ring(&d.svg, at: ringCentre, rx: ringWidth, opacity: 0.55, width: 1.1, arcs: [(190, 350)], depth: ringDepth)
        if pose == .walking { wake(&d, space, frame) }

        let held = Held(pose: pose, frame: frame)
        /// How far a point of the hull's space lies toward the viewer from the boatman.
        func depthFromBoatman(_ v: V) -> Double { space.depth(v.x - seat, v.z) }
        let toolBehind = depthFromBoatman(held.tool == .net ? held.end : held.middle) < -3
        // The bow is nearer than the stern where the view looks at it, and in profile.
        let bowNear = space.s >= 0
        let (farHorn, nearHorn) = bowNear ? (stern, bow) : (bow, stern)

        // Under the water nothing of the hull shows: everything of it is drawn above the near waterline.
        let left = nearWater.first!, right = nearWater.last!
        let above = [P(-300, left.y)] + nearWater + [P(300, right.y), P(300, -300), P(-300, -300)]
        d.svg.raw("<defs><clipPath id=\"reed-boat-afloat\"><polygon points=\"\(StoneDugout.polygon(above))\"/></clipPath></defs>")

        if toolBehind { held.drawTool(&d, space) }
        d.svg.raw("<g clip-path=\"url(#reed-boat-afloat)\">")
        // The far horn, then the far bundle and its lashings, then the near bundle and its.
        tube(&d, space, farHorn)
        for (k, knot) in farHorn.enumerated() where k == 2 || k == 4 { lashing(&d, space, at: knot, toward: farHorn[k + 1].at) }
        let sides = space.c >= 0 ? [-1.0, 1.0] : [1.0, -1.0]
        for side in sides {
            let knots = bundle(side)
            tube(&d, space, knots)
            for k in stride(from: 2, to: knots.count - 2, by: 3) { lashing(&d, space, at: knots[k], toward: knots[k + 1].at) }
        }
        // The shade along the waterline.
        d.svg.polygon(nearWater + nearWater.reversed().map { $0 + P(0, -2.6) }, fill: .colour(BronzeReedInk.reedShade), opacity: 0.6)
        d.svg.raw("</g>")

        // The mat the boatman stands on, and the basket for the catch.
        mat(&d, space)
        let basketAt = V(seat + 17, deck, -2)
        let basketBehind = depthFromBoatman(basketAt) < 0
        if basketBehind { basket(&d, space, at: basketAt, pose: pose, frame: frame) }

        // The boatman, standing on the mat.
        boatman(&d, space, held: held, toolInFront: !toolBehind)
        if !basketBehind { basket(&d, space, at: basketAt, pose: pose, frame: frame) }

        // The near horn, over the boatman where it rises before him, its root bound to the body.
        d.svg.raw("<g clip-path=\"url(#reed-boat-afloat)\">")
        tube(&d, space, nearHorn, outlineFrom: 1)
        for (k, knot) in nearHorn.enumerated() where k == 0 || k == 2 || k == 4 {
            lashing(&d, space, at: knot, toward: nearHorn[k + 1].at, width: k == 0 ? 2.8 : 2.2)
        }
        d.svg.raw("</g>")
        tips(&d, space)

        // The water along the near side, and what the pole or the net stirs.
        var foam = PathData()
        for (i, p) in nearWater.enumerated() {
            if i == 0 { foam.move(p) } else { foam.quad((nearWater[i - 1] + p) * 0.5 + P(0, 1.1), p) }
        }
        d.svg.path(foam, stroke: .colour(BoatInk.foam), width: 1.6)
        StoneBoatsWater.ring(&d.svg, at: ringCentre, rx: ringWidth, opacity: 0.75, width: 1.2, arcs: [(15, 165)], depth: ringDepth)
        held.drawWater(&d, space)
    }

    /// The cut ends of the reeds at the horns' tips, spread a little.
    static func tips(_ d: inout Drawing, _ space: Space) {
        for horn in [bow, stern] {
            let end = horn[horn.count - 1], before = horn[horn.count - 2]
            let a = space.at(end.at), b = space.at(before.at)
            var u = a - b
            u = u * (1 / max((u.x * u.x + u.y * u.y).squareRoot(), 1e-6))
            let n = P(-u.y, u.x)
            var fan = PathData()
            for k in [-1.0, -0.33, 0.33, 1.0] {
                fan.move(a + n * (k * 1.2))
                fan.line(a + u * 3.4 + n * (k * 2.6))
            }
            d.svg.path(fan, stroke: .colour(Ink.line), width: 1.5)
            d.svg.path(fan, stroke: .colour(BronzeReedInk.reedShade), width: 0.6)
        }
    }

    /// The mat of woven reed laid over the bundles where the boatman stands, its weave in terracotta.
    static func mat(_ d: inout Drawing, _ space: Space) {
        let (x0, x1, z) = (seat - 9, seat + 9, 6.2)
        let corners = [V(x0, deck, -z), V(x1, deck, -z), V(x1, deck, z), V(x0, deck, z)].map(space.at)
        d.svg.polygon(corners.map { $0 + P(-0.6, 0.5) }, fill: .colour(BronzeReedInk.light))
        var weave = PathData()
        for k in 1..<6 {
            let x = x0 + (x1 - x0) * Double(k) / 6
            weave.move(space.at(x, deck, -z)); weave.line(space.at(x, deck, z))
        }
        d.svg.path(weave, stroke: .colour(BronzeReedInk.terracotta), width: 0.7)
        d.svg.polygon(corners, fill: .none, stroke: .colour(Ink.line), width: 0.9)
    }

    /// The basket for the catch: woven reed bound with terracotta, tails of fish showing over its rim.
    static func basket(_ d: inout Drawing, _ space: Space, at foot: V, pose: SpritePose, frame: Int) {
        let base = space.at(foot), height = 7.0, r = 4.2
        let top = base - P(0, height)
        let ry = r * StoneDugout.pitch
        var body = PathData()
        body.move(top + P(-r, 0)); body.line(base + P(-r * 0.8, 0))
        body.quad(base + P(0, ry * 1.6), base + P(r * 0.8, 0)); body.line(top + P(r, 0)); body.close()
        d.svg.path(body, fill: .colour(BronzeReedInk.reed), stroke: .colour(Ink.line), width: 0.9)
        for f in [0.35, 0.7] {
            let y = top.y + height * f
            d.svg.path("M\(num(top.x - r * (1 - 0.2 * f))),\(num(y)) q\(num(r * (1 - 0.2 * f))),\(num(ry * 1.4)) \(num(2 * r * (1 - 0.2 * f))),0",
                       stroke: .colour(BronzeReedInk.terracotta), width: 1)
        }
        d.svg.ellipse(top, r, ry, fill: .colour(BronzeReedInk.dark), stroke: .colour(Ink.line), width: 0.9)
        // The fish in it, their tails up.
        for k in 0..<2 {
            let at = top + P(-1.8 + Double(k) * 1.9, -0.2)
            let tail = [at + P(0, 0.6), at + P(-1.1, -2.6), at + P(0, -1.8), at + P(1.1, -2.8)]
            d.svg.polygon(tail, fill: .colour(BronzeReedInk.fish), stroke: .colour(Ink.line), width: 0.6)
        }
    }

    /// An arm from the shoulder to the hand, as the dugout's paddler's are drawn.
    static func arm(_ d: inout Drawing, from shoulder: P, to hand: P) { StoneDugout.arm(&d, from: shoulder, to: hand) }

    /// The wake behind a poled boat: short strokes spreading outward from the
    /// stern on either side, drifting back and fading, and the ripple at the bow.
    static func wake(_ d: inout Drawing, _ space: Space, _ frame: Int) {
        let p = Double(frame) / Double(SpriteKey.framesPerPose)
        for side in [-1.0, 1.0] {
            for k in 0..<3 {
                let age = (p + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                let back = -halfLength * 0.9 - 2 - 16 * age
                let spread = 9 + 11 * age
                let a = space.at(back, 0, side * spread), b = space.at(back - 7, 0, side * (spread + 3.5))
                d.svg.line([a, b], stroke: .colour(BoatInk.foam), width: 1.3 - 0.6 * age, opacity: 0.85 * (1 - age))
            }
        }
        let swell = 0.5 + 0.5 * sin(turn(frame) * 2)
        for side in [-1.0, 1.0] {
            let a = space.at(halfLength * 0.95, 0, side * 2), b = space.at(halfLength * 0.7, 0, side * (13 + 2 * swell))
            d.svg.path("M\(num(a.x)),\(num(a.y)) Q\(num((a.x + b.x) / 2)),\(num((a.y + b.y) / 2 + 1)) \(num(b.x)),\(num(b.y))",
                       stroke: .colour(BoatInk.foam), width: 1.2, opacity: 0.6 + 0.3 * swell)
        }
    }

    // MARK: The boatman

    /// The boatman standing on the mat, and his arms to the pole or the net,
    /// which is drawn between his body and the arms before it where `toolInFront`.
    static func boatman(_ d: inout Drawing, _ space: Space, held: Held, toolInFront: Bool) {
        let origin = space.at(seat, deck, 0) + P(0, d.bob)
        let lean = d.rig.lean * cos(d.yaw * .pi / 180)
        /// A point of the figure, drawn by the kit in this view, where it falls in the picture.
        func placed(_ p: P) -> P { p.rotated(lean, about: Drawing.hips) + origin }
        let shoulders = [false, true].map { right in
            placed(d.project(0.5, -44 - d.rig.lift, right ? Drawing.shoulderSpread : -Drawing.shoulderSpread).point)
        }
        let hands = held.hands.map { space.at($0) }
        let armBehind = [false, true].map { right -> Bool in
            let hand = held.hands[right ? 1 : 0]
            let z = right ? Drawing.shoulderSpread : -Drawing.shoulderSpread
            return (space.depth(0.5, z) + space.depth(hand.x - seat, hand.z)) / 2 < -2.5
        }
        for right in [false, true] where armBehind[right ? 1 : 0] { arm(&d, from: shoulders[right ? 1 : 0], to: hands[right ? 1 : 0]) }
        d.svg.raw("<g transform=\"translate(\(num(origin.x)),\(num(origin.y))) "
                  + "rotate(\(num(lean)) \(num(Drawing.hips.x)) \(num(Drawing.hips.y)))\">")
        d.legs()
        body(&d)
        d.svg.raw("</g>")
        if toolInFront { held.drawTool(&d, space) }
        for right in [false, true] where !armBehind[right ? 1 : 0] { arm(&d, from: shoulders[right ? 1 : 0], to: hands[right ? 1 : 0]) }
    }

    /// The tunic's outline in profile.
    static let tunic = [P(-8.5, -47), P(8.5, -47), P(12.5, -14), P(-13.5, -14)]

    /// The boatman's body and head, in the figure's space: the linen tunic with
    /// its verdigris hem and the team's sash, and the head under the reed hat.
    static func body(_ d: inout Drawing) {
        d.garment(colour: [P(-12, -46), P(9, -48), P(13.4, -12.6), P(-15, -12.2)], outline: tunic, fill: .colour(BronzeReedInk.light)) { d in
            // The hem, dyed verdigris, and the sash from the left shoulder to the right hip.
            d.band([P(-13.6, -19), P(12.4, -19), P(12.9, -14.2), P(-14.1, -14.2)], fill: .colour(BronzeReedInk.verdigris))
            if d.view == .side {
                d.band([P(-8.4, -46), P(-3.2, -47), P(12.2, -23), P(7.6, -21)])
            } else {
                for via in [0.0, 180.0] {
                    for run in BronzePeopleViews.across(d, on: tunic, top: (-45, 270), bottom: (-22, 90), via: via, width: 5) {
                        d.svg.polygon(run.map(d.up), fill: .team)
                    }
                }
            }
        }
        d.head(nose: nose, hair: { d in
            // Dark hair at the nape, under the hat.
            for run in BronzePeopleViews.patch(d.view, from: 105, to: 255, out: 0.2, top: { _ in -63 }, bottom: { _ in -51.5 }) {
                d.svg.polygon(run, fill: .colour(Ink.line))
            }
        }, brow: { d in
            d.svg.path("M1.8,-63.4 q3,-0.8 6,0.2", stroke: .colour(Ink.line), width: 1.4)
        }, over: { d in
            hat(&d)
        })
    }

    /// The conical hat of woven reed, the same from every side: its brim, its
    /// crown rising to a point, the rings of its weave, and its terracotta band.
    static func hat(_ d: inout Drawing) {
        let x = d.view == .side ? 0.5 : 0.0
        let brim = P(x, -64.6), peak = P(x, -81)
        let rx = 17.0, ry = 3.4
        let line = Paint.colour(Ink.line)
        // The brim's underside, then the crown over it.
        d.svg.ellipse(brim + P(-0.6, 0.5), rx, ry, fill: .colour(BronzeReedInk.reedShade))
        d.svg.ellipse(brim, rx, ry, fill: .none, stroke: line, width: 1.2)
        var crown = PathData()
        crown.move(brim + P(-rx * 0.62, -0.4))
        crown.quad(brim + P(-rx * 0.3, -9), peak)
        crown.quad(brim + P(rx * 0.3, -9), brim + P(rx * 0.62, -0.4))
        crown.quad(brim + P(0, ry * 0.9), brim + P(-rx * 0.62, -0.4))
        crown.close()
        d.svg.path(crown, fill: .colour(BronzeReedInk.reed), stroke: line, width: 1.3)
        // The rings of the weave.
        for (f, w) in [(0.32, 0.62), (0.58, 0.4)] {
            let y = brim.y - (brim.y - peak.y) * f
            let half = rx * 0.62 * (1 - f) + 0.6
            d.svg.path("M\(num(x - half)),\(num(y)) q\(num(half)),\(num(1.6 * (1 - f))) \(num(2 * half)),0",
                       stroke: .colour(BronzeReedInk.reedShade), width: w + 0.3)
        }
        // The band round the crown's foot.
        d.svg.path("M\(num(x - rx * 0.6)),\(num(brim.y - 1.4)) q\(num(rx * 0.6)),\(num(2.4)) \(num(rx * 1.2)),0",
                   stroke: line, width: 3)
        d.svg.path("M\(num(x - rx * 0.6)),\(num(brim.y - 1.4)) q\(num(rx * 0.6)),\(num(2.4)) \(num(rx * 1.2)),0",
                   stroke: .colour(BronzeReedInk.terracotta), width: 1.7)
        d.svg.circle(peak, 1, fill: .colour(BronzeReedInk.terracotta), stroke: line, width: 0.6)
    }

    // MARK: What the boatman holds

    /// The pole or the net in a frame of a pose: where it lies in the hull's
    /// space, where the hands hold it, and what it stirs in the water.
    struct Held {
        enum Tool { case pole, net }
        let tool: Tool
        /// The end held up and the end toward the water (the pole's foot, the net's hoop).
        let top: V, end: V
        /// The left (back) hand, then the right (front) hand.
        let hands: [V]
        let pose: SpritePose, frame: Int

        /// The pole's length, and the net's from its butt to the hoop.
        static let poleLength = 90.0, netLength = 56.0

        init(pose: SpritePose, frame: Int) {
            self.pose = pose; self.frame = frame
            let chest = V(seat + 3, deck - 38, 4)
            switch pose {
            case .walking:
                tool = .pole
                let t = stroke(frame)
                // The foot goes round a loop: planted beside the boatman, pushed back along the bottom as the
                // boat goes past it, drawn out behind and swung forward through the air to be planted again.
                let foot = V(seat - 8 + 20 * cos(t), 11 + (sin(t) > 0 ? 15 : 13) * sin(t), 14)
                // The hands high as the pole is planted, low and back at the end of the push.
                let grip = V(seat + 15 + 5 * cos(t), deck - 31 - 6 * cos(t), 11)
                let along = (grip - foot).unit
                end = foot
                top = foot + along * Self.poleLength
                hands = [grip + along * 12, grip]
            case .working:
                tool = .net
                // The hoop goes where the sweep puts it; the handle slides through the hands, which hold it nearest the chest.
                let hoop = BronzeReedBoat.sweep[frame] + V(seat, 0, 0)
                let along = (hoop - chest).unit
                end = hoop
                top = hoop - along * Self.netLength
                let nearest = top + along * max(8, min(Self.netLength - 10, (chest - top).x * along.x + (chest - top).y * along.y
                                                                           + (chest - top).z * along.z))
                hands = [nearest - along * 3, nearest + along * 10]
            default:
                tool = .pole
                let foot = V(seat + 17, 20, 14)
                let grip = V(seat + 15, deck - 31, 11)
                let along = (grip - foot).unit
                end = foot
                top = foot + along * Self.poleLength
                hands = [grip + along * 10, grip]
            }
        }

        /// The middle of what is held, for which way it lies from the boatman.
        var middle: V { (top + end) * 0.5 }

        func drawTool(_ d: inout Drawing, _ space: Space) {
            switch tool {
            case .pole: BronzeReedBoat.shaft(&d, space, from: top, to: end, width: 1.8)
            case .net: BronzeReedBoat.net(&d, space, butt: top, hoop: end, frame: frame)
            }
        }

        /// What the pole or the net stirs in the water in this frame.
        func drawWater(_ d: inout Drawing, _ space: Space) {
            let p = Double(frame) / Double(SpriteKey.framesPerPose)
            switch tool {
            case .pole:
                if end.y > 0, top.y < 0 {
                    let k = -top.y / (end.y - top.y)
                    let entry = top + (end - top) * k
                    StoneBoatsWater.ring(&d.svg, at: space.at(entry), rx: 3.5 + (pose == .walking ? 1.5 : 1.5 * p), opacity: 0.8, width: 1,
                                         depth: 0.42)
                }
                if pose == .walking {
                    // The swirls the pushes leave, falling behind the boat and spreading.
                    for k in 0..<2 {
                        let age = (p + 0.3 + Double(k) / 2).truncatingRemainder(dividingBy: 1)
                        let at = space.at(seat - 4 - 28 * age, 0, 15)
                        StoneBoatsWater.ring(&d.svg, at: at, rx: 3 + 6 * age, opacity: 0.7 * (1 - age), width: 1, depth: 0.42)
                    }
                    // Drops falling from the foot as it swings forward through the air.
                    if end.y < 0 { drops(&d, space, from: end, frame: frame) }
                } else {
                    // Lapping at the hull as it rides the water.
                    StoneBoatsWater.ring(&d.svg, at: space.at(0, 0, 0), rx: abs(48 * space.c) + abs(12 * space.s) + 8 + 6 * p,
                                         opacity: 0.45 * (1 - p), width: 0.9, arcs: [(25, 155)],
                                         depth: max(0.12, StoneDugout.pitch * (abs(48 * space.s) + abs(12 * space.c) + 9)
                                                    / (abs(48 * space.c) + abs(12 * space.s) + 9)))
                }
            case .net:
                // Where the hoop goes in and comes out, a splash; rings spreading from it while it is under.
                let plunge = BronzeReedBoat.sweep[2] + V(seat, 0, 0), out = BronzeReedBoat.sweep[6] + V(seat, 0, 0)
                if frame == 2 || frame == 3 {
                    StoneBoatsWater.splash(&d.svg, at: space.at(plunge.x, 0, plunge.z), t: Double(frame - 2) / 2.2, size: 1.1)
                }
                if frame == 6 || frame == 7 {
                    StoneBoatsWater.splash(&d.svg, at: space.at(out.x, 0, out.z), t: Double(frame - 6) / 2.4, size: 0.9)
                }
                // Rings spreading from where the hoop went in, and following it back under the water.
                for lag in [0.0, 0.18] {
                    let age = (p - 2.0 / 12 - lag + 2).truncatingRemainder(dividingBy: 1)
                    StoneBoatsWater.ring(&d.svg, at: space.at(plunge.x, 0, plunge.z), rx: 3 + 12 * age, opacity: 0.8 * pow(1 - age, 1.4),
                                         width: 1, depth: 0.42)
                }
                if (3...5).contains(frame) {
                    StoneBoatsWater.ring(&d.svg, at: space.at(end.x, 0, end.z), rx: 4, opacity: 0.7, width: 1, depth: 0.42)
                }
                if frame == 7 || frame == 8 { drops(&d, space, from: end + V(0, 9, 0), frame: frame) }
            }
        }

        /// Drops of water falling from a point held over the water.
        private func drops(_ d: inout Drawing, _ space: Space, from v: V, frame: Int) {
            for k in 0..<3 {
                let fall = Double((frame * 5 + k * 7) % 10) / 10
                let at = space.at(v + V(Double(k - 1) * 1.4, 2 + fall * max(1, -v.y - 2), 0))
                d.svg.circle(at, 0.8, fill: .colour(BoatInk.foam), stroke: .colour(Ink.line), width: 0.35, opacity: 1 - fall * 0.6)
            }
        }
    }

    /// Splits a line of the hull's space at the water's surface: the runs above it and those under it.
    static func split(_ points: [V]) -> (above: [[V]], below: [[V]]) {
        var above: [[V]] = [], below: [[V]] = [], run: [V] = []
        var under = (points.first?.y ?? 0) > 0
        for (a, b) in zip(points, points.dropFirst()) {
            if run.isEmpty { run.append(a) }
            if (a.y > 0) != (b.y > 0) {
                let cut = a + (b - a) * (-a.y / (b.y - a.y))
                run.append(cut)
                if under { below.append(run) } else { above.append(run) }
                run = [cut]
                under.toggle()
            }
            run.append(b)
        }
        if run.count > 1 { if under { below.append(run) } else { above.append(run) } }
        return (above, below)
    }

    /// A wooden shaft from `a` to `b` in the hull's space: what lies under the water faint, the rest with its line.
    static func shaft(_ d: inout Drawing, _ space: Space, from a: V, to b: V, width: Double) {
        let parts = split([a, b])
        for run in parts.below { d.svg.line(run.map(space.at), stroke: .colour(BronzeReedInk.handle), width: width + 0.4, opacity: 0.35) }
        for run in parts.above {
            let points = run.map(space.at)
            d.svg.line(points, stroke: .colour(Ink.line), width: width + 1.4)
            d.svg.line(points, stroke: .colour(BronzeReedInk.wood), width: width)
        }
    }

    /// The hoop net: its handle, a hoop of bent cane at its end, and the bag of
    /// net hanging from it; a fish caught in it while it is lifted, and falling
    /// into the basket as it is tipped.
    static func net(_ d: inout Drawing, _ space: Space, butt: V, hoop: V, frame: Int) {
        let along = (hoop - butt).unit
        // The hoop's plane holds the handle's line and the level across it.
        var side = V(-along.z, 0, along.x)
        if side.length < 0.2 { side = V(0, 0, 1) }
        side = side.unit
        let radius = 6.5
        let centre = hoop
        let rim = (0...16).map { i -> V in
            let a = Double(i) / 16 * 2 * .pi
            return centre + along * (radius * cos(a)) + side * (radius * sin(a))
        }
        // The bag hangs from the hoop, pulled back by the water while it is swept.
        let drag = frame >= 3 && frame <= 5 ? V(7, 3, 0) : V(0, 0, 0)
        let bottom = centre + V(0, 9, 0) + drag
        shaft(&d, space, from: butt, to: hoop - along * radius, width: 1.5)
        let line = Paint.colour(Ink.line)
        // The mesh: from the rim down to the bag's bottom, and a ring round its middle.
        var mesh: [[V]] = rim.enumerated().filter { $0.offset % 2 == 0 }.map { [$0.element, bottom] }
        mesh.append(rim.map { ($0 + bottom) * 0.5 })
        for strand in mesh {
            let parts = split(strand)
            for run in parts.below { d.svg.line(run.map(space.at), stroke: .colour(Ink.line), width: 0.5, opacity: 0.3) }
            for run in parts.above { d.svg.line(run.map(space.at), stroke: line, width: 0.55, opacity: 0.9) }
        }
        // The fish: caught as the net comes up, falling into the basket as it is tipped.
        if (6...9).contains(frame) {
            let at = space.at(bottom + V(0, -3, 0))
            fish(&d, at: at, degrees: frame % 2 == 0 ? 25 : -20, faint: frame == 6)
        } else if frame == 10 || frame == 11 {
            let at = space.at(V(seat + 17, deck - (frame == 10 ? 15 : 9), -1))
            fish(&d, at: at, degrees: frame == 10 ? 70 : 85, faint: false)
        }
        let parts = split(rim)
        for run in parts.below { d.svg.line(run.map(space.at), stroke: .colour(BronzeReedInk.handle), width: 1.6, opacity: 0.35) }
        for run in parts.above {
            let points = run.map(space.at)
            d.svg.line(points, stroke: line, width: 2.4)
            d.svg.line(points, stroke: .colour(BronzeReedInk.reedLit), width: 1)
        }
    }

    /// A small silver fish at `at`, turned by `degrees`.
    static func fish(_ d: inout Drawing, at: P, degrees: Double, faint: Bool) {
        let shape = [P(-4.2, 0), P(-1.6, -1.8), P(2.4, -1.2), P(4.2, 0), P(2.4, 1.2), P(-1.6, 1.6), P(-4.2, 0), P(-6, -1.8), P(-6, 1.8)]
        let turned = shape.map { $0.rotated(degrees, about: P(0, 0)) + at }
        d.svg.polygon(Array(turned.prefix(6)), fill: .colour(BronzeReedInk.fish), stroke: .colour(Ink.line), width: 0.7, opacity: faint ? 0.5 : 1)
        d.svg.polygon([turned[6], turned[7], turned[8]], fill: .colour(BronzeReedInk.fish), stroke: .colour(Ink.line), width: 0.6,
                      opacity: faint ? 0.5 : 1)
    }
}

/// The reed boat's colours: shades of the Bronze age's palette (docs/art-style.md, "Palettes").
enum BronzeReedInk {
    static let reed = "#cda85e"
    static let reedShade = "#a9863f"
    static let reedLit = "#e2c47e"
    static let light = BronzePeopleInk.light
    static let terracotta = BronzePeopleInk.terracotta
    static let verdigris = BronzePeopleInk.verdigris
    static let wood = BronzePeopleInk.wood
    static let handle = BronzePeopleInk.handle
    static let dark = "#3d3029"
    /// A fish's silver.
    static let fish = "#c9cfd6"
}
