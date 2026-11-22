// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The horse of the Bronze look, which the horseman (IronWarriorsHorseman.swift) rides.

/// A horse, drawn from the side facing right: a barrel,
/// an arched neck with a dark mane, a long head with a bridle and a plume of the
/// team's colour, a flowing tail, and four jointed legs whose lower hoof rests
/// on the ground. Its local origin is on the ground under the middle of its body.
struct BronzePeopleSteed {
    struct Pose {
        var fore = Limb(2, 2), hind = Limb(-16, 22)
        var farFore = Limb(2, 2), farHind = Limb(-16, 22)
        /// The body's rise in degrees, nose up, about the hind hip.
        var pitch = 0.0
        var lift = 0.0
        /// The neck's turn in degrees about its base; negative raises the head.
        var neck = 0.0
        var tail = 0.0
        var mane = 0.0
        var blink = false
        var mouthOpen = false
        var earBack = false
    }

    enum Leg { case fore, hind }

    static let foreHip = P(13, -29), hindHip = P(-11.4, -28.8)
    static let farOffset = P(2.4, -0.8)
    static let upper = 14.5, lower = 14.5
    static let neckBase = P(17, -42)

    let origin: P
    let pose: Pose
    let coat: String
    let shade: String
    private(set) var bob = 0.0

    init(at origin: P, pose: Pose, coat: String, shade: String) {
        self.origin = origin; self.pose = pose; self.coat = coat; self.shade = shade
        bob = -(Self.allLegs(self, bob: 0).map { $0.hoof.y }.max() ?? 0) + origin.y
    }

    /// A point of the body, from the horse's local units to the picture.
    func body(_ p: P, bob b: Double? = nil) -> P {
        origin + p.rotated(-pose.pitch, about: Self.hindHip) + P(0, -pose.lift + (b ?? bob))
    }

    /// A point of the neck or head, turned with the neck.
    func head(_ p: P) -> P { body(p.rotated(pose.neck, about: Self.neckBase)) }

    var mouth: P { head(P(37.4, -54.4)) }
    var withers: P { body(P(10.4, -47.2)) }

    /// One leg: its top, joint and hoof in the picture.
    static func leg(_ horse: BronzePeopleSteed, _ kind: Leg, far: Bool, bob: Double) -> (top: P, joint: P, hoof: P) {
        let hip = (kind == .fore ? foreHip : hindHip) + (far ? farOffset : P(0, 0))
        let limb = kind == .fore ? (far ? horse.pose.farFore : horse.pose.fore) : (far ? horse.pose.farHind : horse.pose.hind)
        let top = horse.body(hip, bob: bob)
        let joint = top + P.direction(limb.upper) * upper
        let hoof = joint + P.direction(kind == .fore ? limb.upper - limb.bend : limb.upper + limb.bend) * lower
        return (top, joint, hoof)
    }

    static func allLegs(_ horse: BronzePeopleSteed, bob: Double) -> [(top: P, joint: P, hoof: P)] {
        [leg(horse, .fore, far: false, bob: bob), leg(horse, .hind, far: false, bob: bob),
         leg(horse, .fore, far: true, bob: bob), leg(horse, .hind, far: true, bob: bob)]
    }

    func hoof(_ kind: Leg) -> P { Self.leg(self, kind, far: false, bob: bob).hoof }

    func drawLeg(_ svg: inout SVG, _ kind: Leg, far: Bool) {
        let (top, joint, hoof) = Self.leg(self, kind, far: far, bob: bob)
        let colour = far ? shade : coat
        // The fetlock bends the hoof a little forward of the cannon.
        let u = P.direction(BronzePeopleKit.degrees(from: joint, to: hoof))
        let fetlock = hoof - u * 2.4
        let a = P(-u.y, u.x)
        svg.line([top, joint], stroke: .colour(Ink.line), width: 5)
        svg.line([joint, fetlock], stroke: .colour(Ink.line), width: 3.5)
        svg.line([top, joint], stroke: .colour(colour), width: 3.2)
        svg.line([joint, fetlock], stroke: .colour(colour), width: 1.9)
        svg.circle(joint, 1.4, fill: .colour(colour))
        svg.polygon([fetlock - a * 1.4, fetlock + a * 1.6, hoof + a * 2.6 + u * 0.5, hoof - a * 1.6 + u * 0.5], fill: .colour(Ink.line))
    }

    func draw(_ svg: inout SVG, near: Bool) {
        drawLeg(&svg, .fore, far: true)
        drawLeg(&svg, .hind, far: true)
        let transform = "translate(\(num(origin.x)),\(num(origin.y + bob - pose.lift))) rotate(\(num(-pose.pitch)) \(num(Self.hindHip.x)) \(num(Self.hindHip.y)))"
        svg.raw("<g transform=\"\(transform)\">")
        // The tail, streaming back.
        let flow = pose.tail
        func tail(_ o: P) -> PathData {
            var p = PathData()
            p.move(P(-18.4, -41.4) + o)
            p.cubic(P(-24, -42 + flow * 4) + o, P(-29 - flow * 4, -35 + flow * 6) + o, P(-30 - flow * 8, -22 + flow * 8) + o)
            p.cubic(P(-27, -26 + flow * 6) + o, P(-23, -32 + flow * 3) + o, P(-18.6, -36.6) + o)
            p.close()
            return p
        }
        svg.path(tail(P(-0.6, 0.6)), fill: .colour(Ink.line))
        // The body.
        func barrel(_ o: P) -> PathData {
            var p = PathData()
            p.move(P(-19, -38) + o)
            p.cubic(P(-20.6, -46.4) + o, P(-10, -48.6) + o, P(0, -46.4) + o)
            p.cubic(P(8, -45.4) + o, P(14, -49) + o, P(19.4, -45) + o)
            p.cubic(P(23.4, -41) + o, P(22.4, -32) + o, P(16, -28.4) + o)
            p.cubic(P(8, -25.6) + o, P(-6, -26) + o, P(-13, -28.2) + o)
            p.cubic(P(-18, -29.8) + o, P(-20.4, -33) + o, P(-19, -38) + o)
            p.close()
            return p
        }
        svg.path(barrel(P(-0.8, 0.7)), fill: .colour(coat))
        // A shade along the belly and the haunch.
        svg.path("M-13,-29.6 C-6,-27.6 8,-27.4 15,-30 C10,-28.4 -6,-28.6 -13,-29.6 Z", fill: .colour(shade), opacity: 0.6)
        svg.path("M-16.6,-36 C-15.6,-41 -11,-43 -7.4,-41.6", stroke: .colour(shade), width: 1.2)
        svg.path(barrel(P(0, 0)), stroke: .colour(Ink.line), width: 1.6)
        // The neck and head, turned together about the neck's base.
        svg.raw("<g transform=\"rotate(\(num(pose.neck)) \(num(Self.neckBase.x)) \(num(Self.neckBase.y)))\">")
        func neck(_ o: P) -> PathData {
            var p = PathData()
            p.move(P(9.4, -46.4) + o)
            p.cubic(P(12.6, -56) + o, P(16.4, -64.4) + o, P(21.8, -68) + o)
            p.line(P(26.4, -57) + o)
            p.cubic(P(25, -50) + o, P(23.8, -44) + o, P(21.4, -37.8) + o)
            p.close()
            return p
        }
        svg.path(neck(P(-0.8, 0.7)), fill: .colour(coat))
        svg.path(neck(P(0, 0)), stroke: .colour(Ink.line), width: 1.6)
        // The mane, in tufts along the crest, lifted by the wind of the gallop.
        var mane = PathData()
        let crest: [P] = (0...7).map { i in
            let t = Double(i) / 7
            let a = P(21.8, -68), b = P(16.4, -64.4), c = P(12.6, -56), e = P(9.4, -46.4)
            let m = 1 - t
            return a * (m * m * m) + b * (3 * m * m * t) + c * (3 * m * t * t) + e * (t * t * t)
        }
        mane.move(crest[0])
        for (i, p) in crest.enumerated() {
            let out = P(-0.85, -0.53) * (2.6 + (i % 2 == 0 ? 1.8 : 0.2) + pose.mane * 1.4) + P(-pose.mane * 1.2, 0)
            mane.line(p + out)
        }
        for p in crest.reversed() { mane.line(p) }
        mane.close()
        svg.path(mane, fill: .colour(Ink.line))
        // The plume of the team's colour: three feathers fanned back from a bronze holder at the poll.
        let sway = pose.mane * 6
        for (i, angle) in [-18.0, -40.0, -62.0].enumerated() {
            svg.group(at: P(21.6, -69.2), turned: angle - sway * (0.6 + Double(i) * 0.3)) { svg in
                svg.ellipse(P(-0.5, -6.4), 2.3, 6, fill: .team)
                svg.ellipse(P(0, -7), 2.3, 6, fill: .none, stroke: .colour(Ink.line), width: 0.9)
                svg.path("M0,-1.6 L0,-11.4", stroke: .colour(Ink.line), width: 0.6, opacity: 0.7)
            }
        }
        svg.circle(P(21.6, -69.2), 1.4, fill: .colour(BronzePeopleInk.bronze), stroke: .colour(Ink.line), width: 0.7)
        // The head.
        // The far ear, behind the head.
        svg.path(pose.earBack ? "M21.6,-67.4 L16.6,-70.6 L21,-69.4 Z" : "M21.4,-67.6 L20.2,-73.2 L23.4,-68.8 Z",
                 fill: .colour(shade), stroke: .colour(Ink.line), width: 1)
        func skull(_ o: P) -> PathData {
            var p = PathData()
            p.move(P(21.4, -67.4) + o)
            p.cubic(P(26, -70.2) + o, P(32.4, -66) + o, P(38.6, -60.4) + o)
            p.cubic(P(41.6, -57.8) + o, P(41.4, -54) + o, P(38.4, -53.2) + o)
            if pose.mouthOpen { p.line(P(39.2, -51) + o); p.line(P(35.4, -52.4) + o) }
            p.cubic(P(34.6, -53.4) + o, P(32, -53.2) + o, P(29.4, -54.4) + o)
            p.cubic(P(25.2, -55.2) + o, P(23.4, -58.8) + o, P(23.6, -61.6) + o)
            p.cubic(P(23, -64) + o, P(21.8, -65.6) + o, P(21.4, -67.4) + o)
            p.close()
            return p
        }
        svg.path(skull(P(-0.6, 0.6)), fill: .colour(coat))
        // The cheek's roundness and the line of the nose.
        svg.path("M24.6,-60.4 C25.6,-57.4 28.2,-56 30.4,-56.4", stroke: .colour(shade), width: 1)
        svg.path(skull(P(0, 0)), stroke: .colour(Ink.line), width: 1.5)
        // The near ear, pricked, or laid back when the horse is roused.
        svg.path(pose.earBack ? "M23,-67.2 L18.2,-71 L22.6,-69.4 Z" : "M22.8,-67.6 L23.6,-73.6 L26.2,-68.8 Z",
                 fill: .colour(coat), stroke: .colour(Ink.line), width: 1.1)
        // The bridle: a cheek strap and a noseband, joined by a bronze disc.
        svg.path("M24.4,-66.4 L33.6,-57.8 M36.8,-61.6 L34.6,-55", stroke: .colour(Ink.line), width: 1.1)
        svg.circle(P(33.8, -57.9), 1.4, fill: .colour(BronzePeopleInk.bronze), stroke: .colour(Ink.line), width: 0.6)
        // The forelock.
        svg.path("M22.6,-68 q4,0.6 5.4,4.4 q-2.8,-1.6 -5.4,-2.4 Z", fill: .colour(Ink.line))
        if pose.blink {
            svg.path("M27.4,-63.6 h2.8", stroke: .colour(Ink.line), width: 1)
        } else {
            svg.circle(P(28.8, -63.4), 1.5, fill: .colour(Ink.eyeWhite), stroke: .colour(Ink.line), width: 0.7)
            svg.circle(P(29.2, -63.3), 0.75, fill: .colour(Ink.line))
        }
        svg.circle(P(38.9, -57.2), 0.65, fill: .colour(Ink.line))
        svg.raw("</g>")
        if near {
            // The breast strap, studded with bronze.
            svg.path("M11,-46.6 C16,-44 20,-40.6 21.6,-36.4", stroke: .colour(BronzePeopleInk.leather), width: 2)
            for p in [P(14.4, -44.6), P(18, -41.8), P(20.6, -38.6)] {
                svg.circle(p, 0.8, fill: .colour(BronzePeopleInk.bronzeLight), stroke: .colour(Ink.line), width: 0.4)
            }
        }
        svg.raw("</g>")
        drawLeg(&svg, .fore, far: false)
        drawLeg(&svg, .hind, far: false)
    }
}

extension BronzePeopleSteed {
    /// The horse seen straight from in front (`front`) or behind, its middle at
    /// `x` on the screen: every height taken from its side drawing, so that it
    /// breathes, gallops and rears as it does from the side.
    func drawEndOn(_ svg: inout SVG, at x: Double, front: Bool, near: Bool) {
        let ink = Paint.colour(Ink.line), skin = Paint.colour(coat)
        // Toward the screen's right is the horse's left side from in front, its right from behind.
        let right = front ? -1.0 : 1.0
        func leg(_ kind: Leg, far: Bool) {
            let (top, joint, hoof) = Self.leg(self, kind, far: far, bob: bob)
            let lx = x + (far ? -3.4 : 3.4) * right
            let out = (far ? -1.0 : 1.0) * right * 0.8
            let colour = far ? shade : coat
            let points = [P(lx, top.y), P(lx + out, joint.y), P(lx, hoof.y - 2.4)]
            svg.line(points, stroke: ink, width: kind == .hind && !front ? 5.6 : 4.4)
            svg.line(points, stroke: .colour(colour), width: kind == .hind && !front ? 3.6 : 2.6)
            svg.ellipse(P(lx, hoof.y - 1), 2.2, 1.6, fill: ink)
        }
        let chest = body(P(17, -37)).y, rump = body(P(-16, -37)).y
        let poll = head(P(21.6, -69.2)).y, eye = head(P(28.8, -63.4)).y, muzzle = head(P(38.6, -54.6)).y
        let withersY = withers.y
        if front {
            leg(.hind, far: true); leg(.hind, far: false)
            // The body end on: the chest, with the breast strap across it.
            svg.ellipse(P(x - 0.6, chest + 0.6), 7.4, 10.6, fill: skin)
            svg.ellipse(P(x, chest + 4.6), 5.6, 5, fill: .colour(shade), opacity: 0.5)
            svg.ellipse(P(x, chest), 7.4, 10.6, fill: .none, stroke: ink, width: 1.6)
            leg(.fore, far: true); leg(.fore, far: false)
            var strap = PathData()
            strap.move(P(x - 7, chest - 4)); strap.quad(P(x, chest + 1.6), P(x + 7, chest - 4))
            svg.path(strap, stroke: .colour(BronzePeopleInk.leather), width: 2)
            for dx in [-4.0, 0.0, 4.0] {
                svg.circle(P(x + dx, chest - 1.4 + abs(dx) * -0.4), 0.8, fill: .colour(BronzePeopleInk.bronzeLight), stroke: ink, width: 0.4)
            }
            // The neck, rising from the chest to the head, its mane falling to one side.
            let neck = [P(x - 5, withersY + 3), P(x + 5, withersY + 3), P(x + 3.6, poll + 7), P(x - 3.6, poll + 7)]
            svg.polygon(neck.map { $0 + P(-0.6, 0.6) }, fill: skin)
            svg.polygon(neck, fill: .none, stroke: ink, width: 1.4)
            svg.polygon([P(x + 3.6 * right, poll + 6), P(x + 5.6 * right, poll + 8), P(x + 6 * right, withersY + 2), P(x + 5 * right, withersY + 3)],
                        fill: ink)
            plume(&svg, at: P(x, poll - 1))
            ears(&svg, x: x, poll: poll)
            // The long face, the forehead broad between the eyes and narrowing to the muzzle.
            var face = PathData()
            face.move(P(x - 4.2, poll + 1))
            face.quad(P(x, poll - 1.6), P(x + 4.2, poll + 1))
            face.quad(P(x + 4.6, eye + 1), P(x + 2.8, muzzle - 2))
            face.quad(P(x + 3.2, muzzle + 1.6), P(x, muzzle + 1.8))
            face.quad(P(x - 3.2, muzzle + 1.6), P(x - 2.8, muzzle - 2))
            face.quad(P(x - 4.6, eye + 1), P(x - 4.2, poll + 1))
            face.close()
            svg.path(face, fill: skin, stroke: ink, width: 1.5)
            svg.ellipse(P(x, muzzle - 0.4), 2.6, 1.8, fill: .colour(shade), opacity: 0.7)
            // The forelock, the bridle's straps and discs, the eyes and the nostrils.
            svg.path("M\(num(x - 1.6)),\(num(poll)) q1.6,4.4 3.2,0 q-0.4,3.4 -1.6,5 q-1.2,-1.6 -1.6,-5 Z", fill: ink)
            svg.line([P(x - 3.8, poll + 3), P(x - 2.8, muzzle - 3)], stroke: ink, width: 1.1)
            svg.line([P(x + 3.8, poll + 3), P(x + 2.8, muzzle - 3)], stroke: ink, width: 1.1)
            svg.line([P(x - 3.2, muzzle - 3.4), P(x + 3.2, muzzle - 3.4)], stroke: ink, width: 1.1)
            for dx in [-3.2, 3.2] {
                svg.circle(P(x + dx, muzzle - 3.4), 1.3, fill: .colour(BronzePeopleInk.bronze), stroke: ink, width: 0.6)
            }
            for dx in [-4.2, 4.2] {
                if pose.blink {
                    svg.line([P(x + dx - 1.2, eye), P(x + dx + 1.2, eye)], stroke: ink, width: 1)
                } else {
                    svg.circle(P(x + dx, eye), 1.4, fill: .colour(Ink.eyeWhite), stroke: ink, width: 0.7)
                    svg.circle(P(x + dx * 1.06, eye + 0.1), 0.7, fill: ink)
                }
            }
            for dx in [-1.2, 1.2] { svg.circle(P(x + dx, muzzle), 0.6, fill: ink) }
            if pose.mouthOpen { svg.ellipse(P(x, muzzle + 2.4), 1.6, 0.9, fill: ink) }
        } else {
            // From behind: the poll and ears over the neck, the plume, the mane down the neck's middle.
            let neck = [P(x - 5, withersY + 3), P(x + 5, withersY + 3), P(x + 3.8, poll + 3), P(x - 3.8, poll + 3)]
            svg.polygon(neck.map { $0 + P(-0.6, 0.6) }, fill: skin)
            svg.polygon(neck, fill: .none, stroke: ink, width: 1.4)
            svg.ellipse(P(x, poll + 2.4), 4.6, 4, fill: skin, stroke: ink, width: 1.4)
            ears(&svg, x: x, poll: poll)
            svg.polygon([P(x - 1.8, poll + 1), P(x + 1.8, poll + 1), P(x + 2.6 + pose.mane, withersY + 2), P(x - 2.6 + pose.mane, withersY + 2)],
                         fill: ink)
            plume(&svg, at: P(x, poll - 1))
            leg(.fore, far: true); leg(.fore, far: false)
            // The rump, its two quarters, and the tail falling between the hind legs.
            svg.ellipse(P(x - 0.6, rump + 0.6), 7.8, 10.4, fill: skin)
            svg.ellipse(P(x, rump + 4), 6, 5, fill: .colour(shade), opacity: 0.45)
            svg.ellipse(P(x, rump), 7.8, 10.4, fill: .none, stroke: ink, width: 1.6)
            svg.line([P(x, rump - 6), P(x, rump + 6)], stroke: .colour(shade), width: 1.1)
            leg(.hind, far: true); leg(.hind, far: false)
            let dock = body(P(-18.4, -41.4)).y, tip = body(P(-30 - pose.tail * 8, -22 + pose.tail * 8)).y
            let swing = pose.tail * 3.4
            var tail = PathData()
            tail.move(P(x - 1.6, dock))
            tail.quad(P(x - 3 + swing * 0.5, (dock + tip) / 2), P(x - 1.2 + swing, tip))
            tail.line(P(x + 1.6 + swing, tip - 0.6))
            tail.quad(P(x + 2.8 + swing * 0.5, (dock + tip) / 2), P(x + 1.6, dock))
            tail.close()
            svg.path(tail, fill: ink)
        }
    }

    /// The two ears at the poll: pricked, or laid back when the horse is roused.
    private func ears(_ svg: inout SVG, x: Double, poll: Double) {
        for side in [-1.0, 1.0] {
            let tip = pose.earBack ? P(x + side * 6, poll - 2.2) : P(x + side * 3, poll - 6)
            svg.polygon([P(x + side * 1.2, poll + 0.4), tip, P(x + side * 4, poll + 0.8)], fill: .colour(coat), stroke: .colour(Ink.line), width: 1.1)
        }
    }

    /// The plume of the team's colour: three feathers fanned up from a bronze holder.
    private func plume(_ svg: inout SVG, at c: P) {
        let sway = pose.mane * 6
        for angle in [-160.0, 180.0, 160.0] {
            svg.group(at: c, turned: angle + sway * 0.4) { svg in
                svg.ellipse(P(-0.5, 6.4), 2.3, 6, fill: .team)
                svg.ellipse(P(0, 7), 2.3, 6, fill: .none, stroke: .colour(Ink.line), width: 0.9)
                svg.path("M0,1.6 L0,11.4", stroke: .colour(Ink.line), width: 0.6, opacity: 0.7)
            }
        }
        svg.circle(c, 1.4, fill: .colour(BronzePeopleInk.bronze), stroke: .colour(Ink.line), width: 0.7)
    }
}
