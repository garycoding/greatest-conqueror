// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The Stone age's boat, the dugout (ruled 2026-11-21): a canoe hollowed from a
// log, its ends raised a little, its hull's outer side painted in the team's
// colour below the gunwale with a zigzag in the light colour, and one person
// kneeling in it. The paddler wears a moss tunic dotted in the light colour
// with the team's band across the chest, and dark hair tied in a topknot with
// a bone pin through it (the mark of the kind); nose B, the button.
//
// The hull lives in its own space: x along it toward the bow, y downward with
// the waterline at 0, z toward its right (starboard), the side a viewer sees
// when it faces right. A view turns that space by its yaw (`SpriteView.yaw`),
// as the car and the figure are turned, and drops the depth; but the water is
// a plane seen at the map's angle, so a point nearer the viewer is drawn
// lower by `pitch` of its depth: the hollow shows over the near gunwale, and
// the waterline and the rings are ellipses. The paddler is drawn with the
// figure kit (`Drawing`) in the same view, kneeling, so that only the body
// above the waist shows over the gunwale; the arms reach from the kit's
// shoulders to the hands on the paddle or the spear, which live in the hull's
// space, so that the hands meet the shaft in every view.
//
// Standing, the boat rides the water and the paddler rests the paddle across
// the gunwales and breathes; walking, the paddler paddles on the right side,
// the blade going in forward, pulling back through the water, and coming out
// and forward through the air, while the bow pushes a ripple and a wake
// spreads behind; working, the paddle is laid across the hull and the paddler
// spears fish (or prods at a rock) on the right side: the spear drawn back,
// thrust into the water with a splash, and drawn up again. Every cycle is
// periodic in its 12 frames. The origin is on the waterline at the middle of
// the hull; the boat casts no shadow.

enum StoneDugout {
    /// Room for the hull in every view, the paddler's raised arms, and the ring about it.
    static let canvas = Canvas(minX: -72, minY: -84, width: 144, height: 124, pixelsPerUnit: Canvas.person.pixelsPerUnit)

    /// The hull's half length, half beam at the gunwale, and the water's pitch.
    static let halfLength = 50.0, beam = 10.5, pitch = 0.42
    /// Where the paddler kneels along the hull, and how far below the figure's
    /// ground the hull's waterline lies (the figure's hips sit on the hull's floor).
    static let seat = -7.0, kneel = 14.0
    static let nose = Nose.button

    /// Whether the boat has the pose: it has no attack, so no fighting.
    static func drawn(_ pose: SpritePose) -> Bool { pose == .standing || pose == .walking || pose == .working }

    /// A frame of a pose in a view, as a sprite's picture and mask, grained alike, on `canvas` or another scale of it.
    static func render(_ pose: SpritePose, frame: Int, view: SpriteView = .side, canvas: Canvas = StoneDugout.canvas) -> Rendered? {
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

    /// The paddle's phase: the pull through the water lasts longer than the
    /// recovery through the air.
    static func stroke(_ frame: Int) -> Double {
        let t = turn(frame)
        return t + 0.42 * sin(t)
    }

    /// How far the boat rises on the water in a frame.
    static func bob(_ pose: SpritePose, _ frame: Int) -> Double {
        let t = turn(frame)
        switch pose {
        case .walking: return 0.5 * sin(2 * stroke(frame) + 0.6)
        case .working: return 0.6 * sin(t) + (frame == 7 || frame == 8 ? 0.6 : 0)
        default: return 0.7 * sin(t)
        }
    }

    /// How far along its axis the spear is thrust in each frame of the working pose:
    /// drawn back, struck, held, and drawn up.
    static let thrust: [Double] = [0, -1.6, -3.2, -4.6, -5.6, -6, 7, 15, 16, 14.5, 9, 3.5]

    /// The skeleton's state: the breath, the lean of the body and the face.
    static func rig(_ pose: SpritePose, _ frame: Int) -> Rig {
        var r = Rig()
        let t = turn(frame)
        switch pose {
        case .walking:
            r.lean = 4 + 6 * cos(stroke(frame))
            r.lift = 0.4 * sin(t)
            r.mouth = .firm
        case .working:
            let d = thrust[frame]
            r.lean = 4 + d * 0.5
            r.headTilt = 6
            r.eyes = .down
            r.mouth = frame >= 6 && frame <= 9 ? .open : .firm
        default:
            r.lean = 2
            r.lift = 0.8 * sin(t)
            r.eyes = frame == 8 ? .closed : .open
        }
        return r
    }

    // MARK: The space of the hull

    /// The hull's space seen in a view, with the boat risen by `rise`.
    struct Space {
        let c: Double, s: Double, rise: Double
        init(_ view: SpriteView, rise: Double) {
            let r = view.yaw * .pi / 180
            c = cos(r); s = sin(r); self.rise = rise
        }
        /// How far a point lies toward the viewer.
        func depth(_ x: Double, _ z: Double) -> Double { x * s + z * c }
        /// A point of the hull's space on the screen.
        func at(_ x: Double, _ y: Double, _ z: Double) -> P { P(x * c - z * s, y - rise + pitch * depth(x, z)) }
        func at(_ p: V) -> P { at(p.x, p.y, p.z) }
    }

    /// A point of the hull's space.
    struct V {
        var x: Double, y: Double, z: Double
        init(_ x: Double, _ y: Double, _ z: Double) { self.x = x; self.y = y; self.z = z }
        static func + (a: V, b: V) -> V { V(a.x + b.x, a.y + b.y, a.z + b.z) }
        static func - (a: V, b: V) -> V { V(a.x - b.x, a.y - b.y, a.z - b.z) }
        static func * (a: V, k: Double) -> V { V(a.x * k, a.y * k, a.z * k) }
        var length: Double { (x * x + y * y + z * z).squareRoot() }
        var unit: V { self * (1 / max(length, 1e-9)) }
    }

    /// The half beam of the hull at `x`, at the gunwale.
    static func halfBeam(_ x: Double) -> Double {
        let f = min(abs(x) / halfLength, 1)
        return beam * max(0, 1 - pow(f, 2.6)).squareRoot()
    }

    /// The height of the gunwale at `x` (negative, above the water): rising toward the ends.
    static func gunwale(_ x: Double) -> Double { -(11 + 5 * pow(min(abs(x) / halfLength, 1), 3)) }

    /// Stations along the hull from the stern to the bow, closer toward the ends.
    static let stations: [Double] = (0...20).map { i in -halfLength * cos(Double(i) / 20 * .pi) }

    /// The gunwale all round: along the right side from the stern, back along the left.
    static func rim(_ space: Space, inset: Double = 1, lower: Double = 0) -> [P] {
        let right = stations.map { space.at($0, gunwale($0) + lower, halfBeam($0) * inset) }
        let left = stations.reversed().map { space.at($0, gunwale($0) + lower, -halfBeam($0) * inset) }
        return right + left.dropFirst().dropLast()
    }

    /// The waterline all round, short of the raised ends.
    static func waterline(_ space: Space) -> [P] {
        let xs = stations.filter { abs($0) < halfLength * 0.9 }
        let right = xs.map { space.at($0, 0, halfBeam($0) * 0.86) }
        let left = xs.reversed().map { space.at($0, 0, -halfBeam($0) * 0.86) }
        return right + left
    }

    /// The convex outline about the points (Andrew's monotone chain), anticlockwise on the screen.
    static func outline(_ points: [P]) -> [P] {
        let sorted = points.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
        func cross(_ o: P, _ a: P, _ b: P) -> Double { (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x) }
        var lower: [P] = [], upper: [P] = []
        for p in sorted {
            while lower.count >= 2, cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 { lower.removeLast() }
            lower.append(p)
        }
        for p in sorted.reversed() {
            while upper.count >= 2, cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 { upper.removeLast() }
            upper.append(p)
        }
        return Array(lower.dropLast() + upper.dropLast())
    }

    /// The nearer of a loop's two chains between its leftmost and rightmost
    /// points (the one lower on the screen), from left to right.
    static func nearChain(_ loop: [P]) -> [P] {
        let left = loop.indices.min { loop[$0].x < loop[$1].x }!, right = loop.indices.max { loop[$0].x < loop[$1].x }!
        func walk(_ from: Int, _ to: Int) -> [P] {
            var out: [P] = [], i = from
            while true {
                out.append(loop[i])
                if i == to { break }
                i = (i + 1) % loop.count
            }
            return out
        }
        let one = walk(left, right), other = Array(walk(right, left).reversed())
        func mean(_ chain: [P]) -> Double { chain.map(\.y).reduce(0, +) / Double(chain.count) }
        return mean(one) >= mean(other) ? one : other
    }

    static func polygon(_ points: [P]) -> String { points.map { "\(num($0.x)),\(num($0.y))" }.joined(separator: " ") }

    // MARK: Drawing

    static func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let space = Space(d.view, rise: bob(pose, frame))
        let line = Paint.colour(Ink.line)
        let rim = Self.rim(space), water = waterline(space)
        let hull = outline(rim + water + [space.at(-halfLength * 0.97, -6, 0), space.at(halfLength * 0.97, -6, 0)])
        let nearRim = nearChain(rim), nearWater = nearChain(water)

        // The water behind and about the boat.
        let ringCentre = space.at(0, 0, 0)
        let ringWidth = abs(halfLength * space.c) + abs(beam * space.s) + 6
        let ringDepth = max(0.12, pitch * (abs(halfLength * space.s) + abs(beam * space.c) + 3) / ringWidth)
        StoneBoatsWater.ring(&d.svg, at: ringCentre, rx: ringWidth, opacity: 0.55, width: 1.1, arcs: [(190, 350)], depth: ringDepth)
        if pose == .walking { wake(&d, space, frame) }

        // The hull: its colour out of register, its hollow, the painted band, and the line over all.
        d.svg.polygon(hull.map { $0 + P(-0.9, 0.7) }, fill: .colour(Ink.wood))
        // The shade along the waterline.
        d.svg.polygon(nearWater + nearWater.reversed().map { $0 + P(0, -3.4) }, fill: .colour(BoatInk.hullShade), opacity: 0.55)
        d.svg.polygon(rim, fill: .colour(BoatInk.hollowWall))
        d.svg.raw("<defs><clipPath id=\"hollow\"><polygon points=\"\(polygon(rim))\"/></clipPath></defs>")
        d.svg.raw("<g clip-path=\"url(#hollow)\">")
        d.svg.polygon(Self.rim(space, inset: 0.66, lower: 7.5), fill: .colour(BoatInk.hollowFloor))
        d.svg.raw("</g>")
        let band = nearRim.map { $0 + P(0, 1.2) } + nearRim.reversed().map { $0 + P(0, 4.6) }
        d.svg.polygon(band, fill: .team)
        var zig = PathData()
        let usable = nearRim.indices.filter { $0 > 1 && $0 < nearRim.count - 2 }
        for (k, i) in usable.enumerated() { let p = nearRim[i] + P(0, k % 2 == 0 ? 2.1 : 3.9); if k == 0 { zig.move(p) } else { zig.line(p) } }
        if usable.count > 1 { d.svg.path(zig, stroke: .colour(Ink.light), width: 0.8) }
        d.svg.polygon(hull, fill: .none, stroke: line, width: 1.5)
        d.svg.polygon(rim, fill: .none, stroke: line, width: 1.1)
        d.svg.line(nearRim.map { $0 + P(0, 0.9) }, stroke: .colour(BoatInk.gunwaleLight), width: 0.7)
        // Marks of the adze along the near side.
        for i in usable where i % 3 == 1 {
            let p = nearRim[i]
            d.svg.line([p + P(-0.6, 5.6), p + P(0.8, 8)], stroke: .colour(BoatInk.hullShade), width: 0.7)
        }

        // The paddler, kneeling: clipped above the near gunwale, so that the hull hides the body below it.
        let left = nearRim.first!, right = nearRim.last!
        let above = [P(-200, left.y)] + nearRim + [P(200, right.y), P(200, -200), P(-200, -200)]
        d.svg.raw("<defs><clipPath id=\"above-gunwale\"><polygon points=\"\(polygon(above))\"/></clipPath></defs>")
        let held = Held(pose: pose, frame: frame)
        let origin = space.at(seat, 0, 0) + P(0, kneel)
        let lean = d.rig.lean * cos(d.yaw * .pi / 180)
        /// A point of the figure, drawn by the kit in this view, where it falls in the picture.
        func placed(_ p: P) -> P { p.rotated(lean, about: Drawing.hips) + origin }
        let shoulders = [false, true].map { right in
            placed(d.project(0.5, -44 - d.rig.lift, right ? Drawing.shoulderSpread : -Drawing.shoulderSpread).point)
        }
        func shoulder(_ right: Bool) -> P { shoulders[right ? 1 : 0] }
        let hands = held.hands.map { space.at($0) }
        /// How far a point of the hull's space lies toward the viewer from the paddler.
        func depthFromPaddler(_ v: V) -> Double { space.depth(v.x - seat, v.z) }
        let armBehind = [false, true].map { right -> Bool in
            let hand = held.hands[right ? 1 : 0]
            let z = right ? Drawing.shoulderSpread : -Drawing.shoulderSpread
            return (space.depth(0.5, z) + depthFromPaddler(hand)) / 2 < -2.5
        }
        let toolBehind = depthFromPaddler(held.middle) < -3

        if toolBehind { held.drawTool(&d, space) }
        for right in [false, true] where armBehind[right ? 1 : 0] { arm(&d, from: shoulder(right), to: hands[right ? 1 : 0]) }
        d.svg.raw("<g clip-path=\"url(#above-gunwale)\"><g transform=\"translate(\(num(origin.x)),\(num(origin.y))) "
                  + "rotate(\(num(lean)) \(num(Drawing.hips.x)) \(num(Drawing.hips.y)))\">")
        paddler(&d)
        d.svg.raw("</g></g>")
        if !toolBehind { held.drawTool(&d, space) }
        for right in [false, true] where !armBehind[right ? 1 : 0] { arm(&d, from: shoulder(right), to: hands[right ? 1 : 0]) }

        // The water along the near side, and what the paddle or the spear stirs.
        var foam = PathData()
        for (i, p) in nearWater.enumerated() {
            if i == 0 { foam.move(p) } else { foam.quad((nearWater[i - 1] + p) * 0.5 + P(0, 1.1), p) }
        }
        d.svg.path(foam, stroke: .colour(BoatInk.foam), width: 1.6)
        StoneBoatsWater.ring(&d.svg, at: ringCentre, rx: ringWidth, opacity: 0.75, width: 1.2, arcs: [(15, 165)], depth: ringDepth)
        held.drawWater(&d, space)
    }

    /// An arm from the shoulder to the hand on the screen, its elbow bent
    /// downward where the hand comes nearer than the arm's length, and the hand.
    static func arm(_ d: inout Drawing, from shoulder: P, to hand: P) {
        let delta = hand - shoulder
        let distance = (delta.x * delta.x + delta.y * delta.y).squareRoot()
        let segment = max(Joints.upperArm, distance / 2 + 0.05)
        let along = distance / 2, out = (segment * segment - along * along).squareRoot()
        let u = delta * (1 / max(distance, 1e-6)), n = P(-u.y, u.x)
        let middle = shoulder + u * along
        let one = middle + n * out, two = middle - n * out
        let elbow = one.y > two.y ? one : two
        d.svg.line([shoulder, elbow, hand], stroke: .colour(Ink.line), width: 1.9)
        d.hand(hand)
    }

    /// The wake behind a paddled boat: short strokes spreading outward from the
    /// stern on either side, drifting back and fading, and the ripple at the bow.
    static func wake(_ d: inout Drawing, _ space: Space, _ frame: Int) {
        let p = Double(frame) / Double(SpriteKey.framesPerPose)
        for side in [-1.0, 1.0] {
            for k in 0..<3 {
                let age = (p + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                let back = -halfLength * 0.8 - 2 - 18 * age
                let spread = beam * 0.8 + 12 * age
                let a = space.at(back, 0, side * spread), b = space.at(back - 7, 0, side * (spread + 3.5))
                d.svg.line([a, b], stroke: .colour(BoatInk.foam), width: 1.3 - 0.6 * age, opacity: 0.85 * (1 - age))
            }
        }
        // The ripple the bow pushes ahead of it, swelling and falling with the strokes.
        let swell = 0.5 + 0.5 * sin(turn(frame) * 2)
        for side in [-1.0, 1.0] {
            let a = space.at(halfLength * 0.86, 0, side * 2), b = space.at(halfLength * 0.62, 0, side * (beam + 2 + 2 * swell))
            d.svg.path("M\(num(a.x)),\(num(a.y)) Q\(num((a.x + b.x) / 2)),\(num((a.y + b.y) / 2 + 1)) \(num(b.x)),\(num(b.y))",
                       stroke: .colour(BoatInk.foam), width: 1.2, opacity: 0.6 + 0.3 * swell)
        }
    }

    // MARK: The paddler

    /// The dark hair seen from each side, and where the topknot sits.
    static func hair(_ view: SpriteView) -> (path: String, knot: P) {
        switch view {
        case .side: ("M-9.6,-59 C-10.4,-71 6,-72.6 9.6,-63.6 C4,-65.4 -2,-64.6 -5,-60.4 C-6.6,-57.6 -8.6,-57 -9.6,-59 Z", P(-3.4, -69.4))
        case .front: ("M-10.6,-58.4 C-12,-71.6 12,-71.6 10.6,-58.4 C8,-64.4 3,-65.6 0,-65 C-3,-65.6 -8,-64.4 -10.6,-58.4 Z", P(0, -70.4))
        case .frontQuarter: ("M-10.6,-56.4 C-12,-72 8.6,-73.6 10.2,-62.6 C5,-66.6 0,-66 -3,-63.4 C-6,-63 -8.6,-61 -10.6,-56.4 Z", P(-2, -70.6))
        case .back: ("M-10.8,-53.6 C-13,-74 13,-74 10.8,-53.6 C7,-56.6 -7,-56.6 -10.8,-53.6 Z", P(0, -70))
        case .backQuarter: ("M-10.8,-53 C-13,-74 11,-75 10.6,-59 C8,-60 4.5,-59.5 2,-57.5 C-2,-58.5 -7,-56 -10.8,-53 Z", P(1.4, -70.4))
        }
    }

    /// The paddler above the waist, in the figure's space: the moss tunic with
    /// its dots and the team's band across the chest, and the head.
    static func paddler(_ d: inout Drawing) {
        d.garment(colour: [P(-11.5, -46), P(8.5, -48), P(11, -15), P(-13, -14)],
                  outline: [P(-8, -47), P(8, -47), P(10.5, -17), P(-11.5, -17)], fill: .colour(Ink.moss)) { d in
            for c in [P(-5, -42), P(3.6, -43), P(-1, -26), P(6, -24), P(-7, -23)] {
                d.svg.circle(d.onBody(d.up(c)), 1.2, fill: .colour(Ink.light))
            }
            d.band([P(-11.5, -38.5), P(10.6, -40), P(10.8, -34.6), P(-12, -33.4)])
        }
        let (path, knot) = hair(d.view)
        d.head(nose: nose, hair: { d in
            d.svg.path(path, fill: .colour(Ink.line))
        }, brow: { d in
            d.svg.path("M1.2,-64.2 l6.6,-1.2", stroke: .colour(Ink.line), width: 1.7)
        }, over: { d in
            // The topknot, and the bone pin through it.
            d.svg.circle(knot, 3.9, fill: .colour(Ink.line))
            d.svg.line([knot + P(-5.6, 1.4), knot + P(5.4, -2)], stroke: .colour(Ink.light), width: 1.4)
            d.svg.circle(knot + P(5.4, -2), 0.9, fill: .colour(Ink.light))
        })
    }

    // MARK: What the paddler holds

    /// The paddle or the spear in a frame of a pose: where it lies in the hull's
    /// space, where the hands hold it, and what it stirs in the water.
    struct Held {
        enum Tool { case paddle, spear }
        let tool: Tool
        /// The end held up (the paddle's grip, the spear's butt) and the end toward the water.
        let top: V, end: V
        /// The left (back) hand, then the right (front) hand.
        let hands: [V]
        let pose: SpritePose, frame: Int
        /// The paddle laid across the gunwales while the spear is in use.
        let stowed: Bool

        init(pose: SpritePose, frame: Int) {
            self.pose = pose; self.frame = frame
            switch pose {
            case .walking:
                tool = .paddle; stowed = false
                let t = stroke(frame)
                let grip = V(seat + 6 + 9 * cos(t - 0.5), -40 + 3 * sin(t), 3.5)
                // The blade's tip goes round a loop: in forward, back deep through the water, out and forward through the air.
                let tip = V(seat + 4 + 20 * cos(t), 3 + 8 * sin(t), 15.5)
                top = grip
                end = grip + (tip - grip).unit * 56
                hands = [grip, grip + (end - grip) * 0.4]
            case .working:
                tool = .spear; stowed = true
                let axis = V(0.47, 0.85, 0.24).unit
                let tip = V(seat + 12, -7, 16) + axis * thrust[frame]
                end = tip
                top = tip - axis * 52
                hands = [top + axis * 7, top + axis * 26]
            default:
                tool = .paddle; stowed = true
                top = V(seat + 11, -13, -16); end = V(seat + 13, -13, 17)
                hands = [V(seat + 9, -13.5, -8.5), V(seat + 10, -13.5, 8.5)]
            }
        }

        /// The middle of what is held, for which way it lies from the paddler.
        var middle: V { (top + end) * 0.5 }

        /// The paddle laid across, or held, or the spear held.
        func drawTool(_ d: inout Drawing, _ space: Space) {
            if stowed && tool == .spear {
                StoneDugout.paddle(&d, space, grip: V(seat + 15, -12.5, -17), tip: V(seat + 17, -12.5, 19), flat: true)
            }
            switch tool {
            case .paddle: StoneDugout.paddle(&d, space, grip: top, tip: end, flat: stowed)
            case .spear: StoneDugout.spear(&d, space, butt: top, tip: end)
            }
        }

        /// What the blade or the spear stirs in the water in this frame.
        func drawWater(_ d: inout Drawing, _ space: Space) {
            let p = Double(frame) / Double(SpriteKey.framesPerPose)
            switch (pose, tool) {
            case (.walking, _):
                // Where the shaft meets the water while the blade pulls, a ring and a curl of foam.
                if end.y > 0, top.y < 0 {
                    let k = -top.y / (end.y - top.y)
                    let entry = top + (end - top) * k
                    StoneBoatsWater.ring(&d.svg, at: space.at(entry), rx: 4.5, opacity: 0.8, width: 1, depth: 0.42)
                }
                // The swirls the strokes leave, falling behind the boat and spreading.
                for k in 0..<2 {
                    let age = (p + 0.5 + Double(k) / 2).truncatingRemainder(dividingBy: 1)
                    let at = space.at(seat - 14 - 26 * age, 0, 16)
                    StoneBoatsWater.ring(&d.svg, at: at, rx: 3 + 6 * age, opacity: 0.7 * (1 - age), width: 1, depth: 0.42)
                }
            case (.working, .spear):
                let strike = V(seat + 12, 0, 16) + V(0.47, 0, 0.24).unit * 4
                let at = space.at(strike)
                if frame >= 6 { StoneBoatsWater.splash(&d.svg, at: at, t: (Double(frame) - 6) / 3.2, size: 1.2) }
                for lag in [0.0, 0.16] {
                    let age = (p - 0.5 - lag + 1).truncatingRemainder(dividingBy: 1)
                    StoneBoatsWater.ring(&d.svg, at: at, rx: 3 + 13 * age, opacity: 0.8 * pow(1 - age, 1.4), width: 1, depth: 0.42)
                }
            default:
                // Lapping at the hull as it rides the water.
                let age = p
                StoneBoatsWater.ring(&d.svg, at: space.at(0, 0, 0), rx: abs(halfLength * space.c) + abs(beam * space.s) + 8 + 6 * age,
                                     opacity: 0.45 * (1 - age), width: 0.9, arcs: [(25, 155)],
                                     depth: max(0.12, pitch * (abs(halfLength * space.s) + abs(beam * space.c) + 9) / (abs(halfLength * space.c) + abs(beam * space.s) + 9)))
            }
        }
    }

    /// A paddle from its grip to its tip: a crossbar at the grip, a shaft, and
    /// a leaf-shaped blade; what lies under the water is seen faintly through it.
    /// Laid `flat`, it lies across the gunwales with its blade flat.
    static func paddle(_ d: inout Drawing, _ space: Space, grip: V, tip: V, flat: Bool) {
        let axis = (tip - grip).unit
        let length = (tip - grip).length
        let neck = grip + axis * (length * 0.62)
        // The blade's breadth: across the boat, turned a little toward its length, so that it shows from the side.
        let across = flat ? V(0.9, 0, 0).unit : V(0.55, 0, 0.84).unit
        let half = 3.6
        let blade: [V] = [neck, neck + axis * (length * 0.1) + across * half, neck + axis * (length * 0.3) + across * (half * 0.9),
                          tip, neck + axis * (length * 0.3) - across * (half * 0.9), neck + axis * (length * 0.1) - across * half]
        let shaft = [grip, neck]
        let crossbar = [grip + across * 2.6, grip - across * 2.6]
        drawInWater(&d, space, blade: blade, shaft: shaft, crossbar: crossbar, prongs: [])
    }

    /// The fish spear: a long shaft with three barbed prongs of bone bound at its tip.
    static func spear(_ d: inout Drawing, _ space: Space, butt: V, tip: V) {
        let axis = (tip - butt).unit
        let across = V(0.5, 0, -0.86)
        let base = tip - axis * 7
        let prongs: [[V]] = [-1.0, 0, 1].map { k in [base, tip + across * (k * 2.6), tip + across * (k * 2.6) + axis * 0.1 - across * (k * 0.6) - V(0, 1.6, 0)] }
        drawInWater(&d, space, blade: [], shaft: [butt, base], crossbar: [], prongs: prongs)
    }

    /// Wood drawn in the hull's space: what lies above the water (y below 0)
    /// at full strength and what lies under it faintly, as if through the water.
    private static func drawInWater(_ d: inout Drawing, _ space: Space, blade: [V], shaft: [V], crossbar: [V], prongs: [[V]]) {
        let line = Paint.colour(Ink.line)
        // Every part is split at the water's surface.
        func split(_ points: [V], closed: Bool) -> (above: [V], below: [V]) {
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
        let shaftParts = split(shaft, closed: false)
        let bladeParts: (above: [V], below: [V]) = blade.isEmpty ? ([], []) : split(blade, closed: true)
        // Under the water, faintly.
        if shaftParts.below.count > 1 {
            d.svg.line(shaftParts.below.map(space.at), stroke: .colour(Ink.handle), width: 2.2, opacity: 0.35)
        }
        if bladeParts.below.count > 2 {
            d.svg.polygon(bladeParts.below.map(space.at), fill: .colour(Ink.wood), opacity: 0.35)
        }
        for prong in prongs {
            let parts = split(prong, closed: false)
            if parts.below.count > 1 { d.svg.line(parts.below.map(space.at), stroke: .colour(Ink.light), width: 1, opacity: 0.4) }
        }
        // Above the water: the shaft, then the blade or the prongs, the line over each.
        if shaftParts.above.count > 1 {
            let points = shaftParts.above.map(space.at)
            d.svg.line(points, stroke: line, width: 3.1)
            d.svg.line(points, stroke: .colour(Ink.handle), width: 1.7)
        }
        if !crossbar.isEmpty {
            let points = crossbar.map(space.at)
            d.svg.line(points, stroke: line, width: 3)
            d.svg.line(points, stroke: .colour(Ink.handle), width: 1.6)
        }
        if bladeParts.above.count > 2 {
            let points = bladeParts.above.map(space.at)
            d.svg.polygon(points.map { $0 + P(-0.6, 0.5) }, fill: .colour(Ink.wood))
            d.svg.polygon(points, fill: .none, stroke: line, width: 1.1)
            // The blade's spine.
            if blade.count > 3, blade[0].y <= 0 {
                let spine = split([blade[0], blade[3]], closed: false).above.map(space.at)
                if spine.count > 1 { d.svg.line(spine, stroke: .colour(Ink.handle), width: 0.8) }
            }
        }
        for prong in prongs {
            let parts = split(prong, closed: false)
            if parts.above.count > 1 {
                let points = parts.above.map(space.at)
                d.svg.line(points, stroke: line, width: 2.1)
                d.svg.line(points, stroke: .colour(Ink.light), width: 0.9)
            }
        }
        if !prongs.isEmpty, let base = prongs.first?.first, base.y <= 0 {
            // The binding of the prongs.
            d.svg.circle(space.at(base), 1.6, fill: .colour(Ink.darkHide), stroke: line, width: 0.6)
        }
    }
}
