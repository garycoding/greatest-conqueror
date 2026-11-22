// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// MARK: - The chariot

/// A war chariot: two horses under a yoke, drawing a two-wheeled car whose
/// side panel is painted in the team's colour, with plumes of the same colour on
/// the horses' heads. The driver, built on the shared figure, wears a light
/// tunic with the team's sash and a headband whose ends stream behind him; nose
/// E. Standing, the horses breathe and toss their heads; moving, they gallop and
/// the four-spoked wheels turn; fighting, the horses rear and strike with their
/// forefeet whilst the driver swings a bronze sickle-sword (a khopesh). The
/// drawing's origin is on the ground under the axle, where the near wheel meets it.
struct BronzePeopleChariot: PersonLook {
    /// The ground under the axle at the origin; the horses run 110 units ahead.
    static let canvas = Canvas(minX: -32, minY: -108, width: 144, height: 116, pixelsPerUnit: Canvas.person.pixelsPerUnit)

    static let wheelRadius = 14.0
    /// The car's floor, on which the driver stands.
    static let floor = -15.6
    /// Where each horse stands: the near one, and the far one a little behind it and ahead.
    static let nearHorse = P(60, 0), farHorse = P(66.4, -4.4)
    /// The wheels turn this many degrees a frame when moving: under half the
    /// 90 degrees between spokes, so that they never seem to turn backward, and a
    /// whole turn in the 12 frames, so that the cycle repeats without a jump.
    static let turn = 30.0

    // MARK: The driver

    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        switch pose {
        case .standing, .working:
            var r = Moves.standing(frame)
            r.lean = 2
            r.frontArm = BronzePeopleKit.reach(BronzePeopleKit.frontShoulder(r), P(14.4, -40.4 - r.lift))
            r.backArm = BronzePeopleKit.reach(BronzePeopleKit.backShoulder(r), P(6.6, -40 - r.lift))
            r.mouth = .firm
            return r
        case .walking:
            var r = Moves.standing(0)
            let shake = 0.6 * BronzePeopleKit.wave(frame, times: 2)
            r.lean = 9
            r.frontArm = BronzePeopleKit.reach(BronzePeopleKit.frontShoulder(r), P(16, -42.6 + shake))
            r.backArm = BronzePeopleKit.reach(BronzePeopleKit.backShoulder(r), P(7.4, -42 + shake))
            r.mouth = .open
            return r
        case .fighting:
            let (angle, landing) = Moves.blow(frame, ready: 70, raised: 192, struck: 58)
            var r = Moves.standing(0)
            r.frontArm = Limb(angle, -8)
            r.backArm = BronzePeopleKit.reach(BronzePeopleKit.backShoulder(r), P(6.6, -41))
            r.lean = frame < 6 ? -4 : (frame <= 9 ? 8 : 2)
            r.mouth = frame >= 6 && frame <= 8 ? .shout : .firm
            r.eyes = landing ? .wide : .open
            return r
        default:
            return nil
        }
    }

    // MARK: The horses

    /// How the near and far horse stand in a frame of a pose.
    static func horses(_ pose: SpritePose, _ frame: Int) -> (near: BronzePeopleSteed.Pose, far: BronzePeopleSteed.Pose) {
        let t = Double(frame) / 12
        func gallop(_ shift: Double) -> BronzePeopleSteed.Pose {
            var p = BronzePeopleSteed.Pose()
            func fore(_ phase: Double) -> Limb {
                let s = 2 * .pi * (t + shift + phase)
                return Limb(6 + 34 * sin(s), 6 + 84 * pow(max(0, cos(s)), 1.3))
            }
            func hind(_ phase: Double) -> Limb {
                let s = 2 * .pi * (t + shift + phase)
                return Limb(-12 + 30 * sin(s), 18 + 52 * pow(max(0, cos(s)), 1.3))
            }
            p.hind = hind(0); p.farHind = hind(0.1); p.fore = fore(0.42); p.farFore = fore(0.52)
            let s = 2 * .pi * (t + shift)
            p.lift = 2.2 + 1.8 * sin(s + 0.6)
            p.pitch = 3.4 * sin(s + 2.2)
            p.neck = -3 + 5 * sin(s + 1.2)
            p.tail = 0.8 + 0.2 * sin(s * 2)
            p.mane = 1 + 0.5 * sin(s * 2 + 0.4)
            p.mouthOpen = true
            return p
        }
        func stand(_ shift: Double, toss: Bool) -> BronzePeopleSteed.Pose {
            var p = BronzePeopleSteed.Pose()
            let s = 2 * .pi * (t + shift)
            p.lift = 0.4 * sin(s)
            p.neck = toss ? -2 + 7 * pow(max(0, sin(s)), 3) : 1.5 * sin(s)
            p.tail = 0.25 * sin(s * 2)
            p.mane = 0.15 * sin(s)
            p.blink = frame == (toss ? 5 : 9)
            p.earBack = toss && frame >= 3 && frame <= 6
            return p
        }
        func rear(_ shift: Double) -> BronzePeopleSteed.Pose {
            var p = BronzePeopleSteed.Pose()
            let s = 2 * .pi * (t + shift)
            let up = (1 - cos(s)) / 2
            p.pitch = 16 * up
            p.lift = 1.6 * up
            p.neck = -6 * up
            p.hind = Limb(-6 - 10 * up, 30 * up + 18)
            p.farHind = Limb(-4 - 10 * up, 30 * up + 18)
            p.fore = Limb(6 + 64 * up + 14 * up * sin(s * 2), 6 + 110 * up)
            p.farFore = Limb(6 + 58 * up + 14 * up * sin(s * 2 + 1.6), 6 + 104 * up)
            p.tail = 0.5 * up
            p.mane = 0.7 * up
            p.mouthOpen = up > 0.4
            p.earBack = up > 0.5
            return p
        }
        switch pose {
        case .walking: return (gallop(0), gallop(0.06))
        case .fighting: return (rear(0), rear(0.05))
        default: return (stand(0, toss: true), stand(0.35, toss: false))
        }
    }

    // MARK: Drawing

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        if d.view != .side { drawInView(&d, pose, frame); return }
        let (nearPose, farPose) = Self.horses(pose, frame)
        let near = BronzePeopleSteed(at: Self.nearHorse, pose: nearPose, coat: "#a8643a", shade: "#7e4626")
        let far = BronzePeopleSteed(at: Self.farHorse, pose: farPose, coat: "#6f3d22", shade: "#4f2a17")
        // Rolling forward (to the right), the wheels turn clockwise: their angle falls.
        let spin = pose == .walking ? -Double(frame) * Self.turn : (pose == .fighting ? 4 * BronzePeopleKit.wave(frame) : 0)
        let bounce = pose == .walking ? 0.7 * abs(BronzePeopleKit.wave(frame, 0.1, times: 1)) : 0
        // The shadow on the ground, under the car and the team.
        d.svg.ellipse(P(42, 0.2), 62, 4.4, fill: .colour("#000000"), opacity: 0.13)
        Self.wheel(&d.svg, at: P(4.6, -Self.wheelRadius - 3.6), degrees: spin + 20, far: true)
        far.draw(&d.svg, near: false)
        // The pole, from under the car to the yoke on the horses' withers.
        let yoke = near.withers + P(1.4, -0.6)
        var pole = PathData()
        pole.move(P(12, -14.8 - bounce)); pole.quad(P(40, -15 - bounce), yoke)
        d.svg.path(pole, stroke: .colour(Ink.line), width: 3.2)
        d.svg.path(pole, stroke: .colour(BronzePeopleInk.wood), width: 1.8)
        Self.driver(&d, pose, frame, rise: bounce)
        Self.car(&d.svg, rise: bounce)
        near.draw(&d.svg, near: true)
        // The yoke saddle on the near horse's withers.
        d.svg.polygon([yoke + P(-3.4, 2.4), yoke + P(0, -2.4), yoke + P(3.4, 2.4), yoke + P(0, 0.6)], fill: .colour(BronzePeopleInk.bronze),
                      stroke: .colour(Ink.line), width: 1)
        Self.wheel(&d.svg, at: P(0, -Self.wheelRadius), degrees: spin, far: false)
        // The reins, from the driver's hands to each horse's bit.
        let place = Self.place(rise: bounce)
        let front = d.world(d.joints.frontHand) + place, back = d.world(d.joints.backHand) + place
        let slack = pose == .walking ? 0.6 : 4
        let reinHands = pose == .fighting ? [back, back] : [front, back]
        for (hand, bit) in zip(reinHands, [near.mouth, far.mouth]) {
            var rein = PathData()
            rein.move(hand); rein.quad((hand + bit) * 0.5 + P(0, slack), bit)
            d.svg.path(rein, stroke: .colour(Ink.line), width: 0.9)
        }
        // Dust thrown up by the hooves at the gallop, and by the forefeet as they come down.
        if pose == .walking && (frame % 6 == 2 || frame % 6 == 3) {
            BronzePeopleProps.dust(&d.svg, at: near.hoof(.hind) + P(-5, -1), size: frame % 6 == 2 ? 0.8 : 1.1, opacity: 0.5)
        }
        if pose == .fighting && (frame == 0 || frame == 11) {
            for hoof in [near.hoof(.fore), far.hoof(.fore)] { d.burst(at: hoof + P(1, -1), from: 100, to: 170, size: 0.9) }
        }
    }

    /// Where the driver's figure stands, beyond its own lean and bob: on the car's floor.
    static func place(rise: Double) -> P { P(-1, floor - rise) }

    /// The driver, standing on the car's floor: only what shows above its side.
    static func driver(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int, rise: Double) {
        let at = place(rise: rise) + P(0, d.bob)
        d.svg.raw("<g transform=\"translate(\(num(at.x)),\(num(at.y))) rotate(\(num(d.rig.lean)) \(num(Drawing.hips.x)) \(num(Drawing.hips.y)))\">")
        d.arm(front: false)
        d.garment(colour: [P(-11.6, -46), P(8.6, -48), P(12.4, -18), P(-13.4, -17.4)],
                  outline: [P(-8, -47), P(8.4, -47), P(11.4, -19.4), P(-12, -19.4)], fill: .colour(BronzePeopleInk.light)) { d in
            d.band([P(-9.4, -44.4), P(-4.6, -47.6), P(11.8, -26.8), P(10.8, -21.6)])
        }
        let hand = d.joints.frontHand
        if pose == .fighting {
            let degrees = d.rig.frontArm.upper - 4
            khopesh(&d.svg, at: hand, degrees: degrees)
            if frame == 7 { d.swish(around: d.joints.frontShoulder, radius: 25, from: 175, to: 80) }
            if frame == 8 { d.impact(at: hand + P.direction(degrees) * 15, size: 1) }
        }
        d.arm(front: true)
        let flutter = pose == .walking ? 2.6 + BronzePeopleKit.wave(frame, times: 3) : 0.6 * BronzePeopleKit.wave(frame)
        d.head(nose: .line, behind: { d in
            for (dy, length) in [(0.0, 10.0), (1.6, 8.0)] {
                let top = P(-10.8, -62.6 + dy)
                let end = top + P(-length + flutter * 0.4, 3.6 - flutter * 1.3 + dy)
                d.svg.polygon([top + P(0, -1), top + P(0, 1), end + P(0, 0.6), end + P(0, -0.6)],
                              fill: .colour(BronzePeopleInk.verdigris), stroke: .colour(Ink.line), width: 0.8)
            }
        }, hair: { d in
            d.svg.path("M-9.8,-59.6 C-10.8,-70.8 4.2,-72.8 9,-65.4 C3.2,-67.6 -1.8,-64.8 -4,-59.4 C-6,-57.2 -8.2,-57.6 -9.8,-59.6 Z",
                       fill: .colour(Ink.line))
        }, features: { d in
            // A short pointed beard.
            d.svg.path("M2.6,-50 C3.6,-46.4 6,-44.6 8.6,-44.2 C8.8,-46.4 9.4,-48.6 10.6,-50.2 C8,-49.2 5.2,-49.2 2.6,-50 Z", fill: .colour(Ink.line))
        }, brow: { d in
            d.svg.path("M1.8,-63.8 q3.2,-1.6 6.4,-0.6", stroke: .colour(Ink.line), width: 1.4)
        }, over: { d in
            d.svg.path("M-10.8,-61.8 Q-1,-67.8 10.2,-65.6", stroke: .colour(Ink.line), width: 3.4)
            d.svg.path("M-10.8,-61.8 Q-1,-67.8 10.2,-65.6", stroke: .colour(BronzePeopleInk.verdigris), width: 1.8)
        })
        d.svg.raw("</g>")
    }

    /// The car: a floor on the axle and a side panel of the team's colour,
    /// bordered in the light and studded with bronze, rising to a curved front.
    static func car(_ svg: inout SVG, rise: Double) {
        func outline(_ o: P) -> PathData {
            var p = PathData()
            p.move(P(-13, floor) + o)
            p.line(P(14.6, floor) + o)
            p.cubic(P(18.2, -22.6) + o, P(18.4, -35.6) + o, P(12.8, -42.4) + o)
            p.line(P(-6.6, -38.8) + o)
            p.cubic(P(-10.6, -38.4) + o, P(-13.2, -35.6) + o, P(-13, -31.6) + o)
            p.close()
            return p
        }
        let up = P(0, -rise)
        svg.path(outline(up + P(-0.8, 0.7)), fill: .team)
        var border = PathData()
        border.move(P(-10.6, floor - 2.4) + up)
        border.line(P(12.6, floor - 2.4) + up)
        border.cubic(P(15.4, -23.6) + up, P(15.6, -34) + up, P(11.6, -39.6) + up)
        border.line(P(-6.2, -36.4) + up)
        border.cubic(P(-9, -36) + up, P(-10.8, -34) + up, P(-10.6, -31.6) + up)
        border.close()
        svg.path(border, stroke: .colour(BronzePeopleInk.light), width: 1.2)
        // A rosette painted on the panel, in the light.
        let rosette = P(7.4, -30.4) + up
        for i in 0..<8 {
            svg.circle(rosette + P.direction(Double(i) * 45) * 2.6, 1.1, fill: .colour(BronzePeopleInk.light))
        }
        svg.circle(rosette, 1.3, fill: .colour(BronzePeopleInk.gold), stroke: .colour(Ink.line), width: 0.5)
        svg.path(outline(up), stroke: .colour(Ink.line), width: 1.6)
        // The rail, of bent wood capped in bronze, and the studs along it.
        svg.line([P(-12.4, -36.2) + up, P(-6.6, -39.4) + up, P(12.6, -43) + up], stroke: .colour(Ink.line), width: 3)
        svg.line([P(-12.4, -36.2) + up, P(-6.6, -39.4) + up, P(12.6, -43) + up], stroke: .colour(BronzePeopleInk.bronze), width: 1.6)
        for x in stride(from: -4.0, through: 10.0, by: 4.6) {
            svg.circle(P(x, -38.4 - (x + 6.6) * 0.17) + up, 0.8, fill: .colour(BronzePeopleInk.bronzeLight), stroke: .colour(Ink.line), width: 0.4)
        }
        svg.line([P(-13.6, floor) + up, P(15.4, floor) + up], stroke: .colour(Ink.line), width: 2.2)
    }

    /// A spoked wheel centred on `c`, turned by `degrees`: a wooden felloe with a
    /// dark tyre, four spokes, and a bronze hub. The far wheel is darker and is
    /// seen through the gaps of the car.
    static func wheel(_ svg: inout SVG, at c: P, degrees: Double, far: Bool) {
        let r = wheelRadius
        let wood = far ? "#5c3c22" : BronzePeopleInk.wood
        svg.circle(c, r - 1.3, fill: .none, stroke: .colour(wood), width: 2.8)
        svg.circle(c, r, fill: .none, stroke: .colour(Ink.line), width: 2)
        svg.circle(c, r - 2.7, fill: .none, stroke: .colour(Ink.line), width: 0.9)
        for i in 0..<4 {
            let u = P.direction(degrees + Double(i) * 90)
            svg.line([c + u * 2.6, c + u * (r - 2.6)], stroke: .colour(Ink.line), width: 2.6)
            svg.line([c + u * 2.8, c + u * (r - 2.8)], stroke: .colour(wood), width: 1.2)
            svg.circle(c + u * (r - 1.3), 0.7, fill: .colour(far ? BronzePeopleInk.bronzeDark : BronzePeopleInk.bronzeLight))
        }
        svg.circle(c, 3, fill: .colour(far ? BronzePeopleInk.bronzeDark : BronzePeopleInk.bronze), stroke: .colour(Ink.line), width: 1.1)
        svg.circle(c, 1, fill: .colour(Ink.line))
    }

    /// A khopesh: a short grip, a straight neck of bronze and a curved blade,
    /// its edge on the outside of the curve leading the blow.
    static func khopesh(_ svg: inout SVG, at hand: P, degrees: Double) {
        svg.group(at: hand, turned: -degrees) { svg in
            svg.line([P(0, -2.4), P(0, 3.6)], stroke: .colour(BronzePeopleInk.handle), width: 2.4)
            func blade(_ o: P) -> PathData {
                var p = PathData()
                p.move(P(-0.9, 3.4) + o)
                p.line(P(-0.9, 8.4) + o)
                p.cubic(P(-1.4, 14.6) + o, P(-6.6, 18.4) + o, P(-9.2, 14.4) + o)
                p.cubic(P(-6, 15.4) + o, P(-2.8, 13) + o, P(1, 8.6) + o)
                p.line(P(1, 3.4) + o)
                p.close()
                return p
            }
            svg.path(blade(P(0.6, 0.5)), fill: .colour(BronzePeopleInk.bronze))
            svg.path(blade(P(0, 0)), stroke: .colour(Ink.line), width: 1)
            svg.path("M-1.6,9.8 C-2.2,13.8 -5.2,16.4 -7.8,15", stroke: .colour(BronzePeopleInk.bronzeLight), width: 0.7)
        }
    }
}

/// A horse of the chariot's team, drawn from the side facing right: a barrel,
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

// MARK: - The chariot in other views

// The chariot seen from its other four sides (ruled 2026-11-21: eight facings,
// five views drawn), in the manner of the car (CarViews.swift). The chariot is
// taken in its own space: x forward, y down, z toward its near (right) side.
// The car is 22 wide between its side panels, its wheels 30 apart, the driver
// stands in its middle, and the two horses go side by side 22 apart, the near
// one on the right, with the pole between them to the yoke on their withers. A
// view turns that space by its yaw and drops the depth, and the parts are
// drawn from the farthest to the nearest. From a quarter turn the near side of
// the car, its wheels and the horses are their side drawings foreshortened,
// and the car's front (or its open back) is a face of its own; from straight
// ahead or behind the wheels are seen end on beside the car, and the horses
// have drawings of their own: the face, chest and forelegs, or the rump, tail
// and hind legs. The driver is drawn by the figure kit in the view.

extension BronzePeopleChariot {
    /// Half the car's width between its side panels, and half the wheels' track.
    static let carHalf = 11.0, track = 15.0
    /// How far the horses stand ahead, and to each side of the pole.
    static let horseAhead = 62.0, horseApart = 11.0

    /// A frame of a pose drawn in a view other than the side.
    func drawInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let view = d.view
        let yaw = view.yaw * .pi / 180, c = cos(yaw), s = sin(yaw)
        let front = view == .front || view == .frontQuarter
        let endOn = abs(c) < 0.01
        func at(_ x: Double, _ z: Double) -> Double { x * c - z * s }
        let (nearPose, farPose) = Self.horses(pose, frame)
        let near = BronzePeopleSteed(at: P(Self.horseAhead, 0), pose: nearPose, coat: "#a8643a", shade: "#7e4626")
        let far = BronzePeopleSteed(at: P(Self.horseAhead, 0), pose: farPose, coat: "#6f3d22", shade: "#4f2a17")
        let teams: [(BronzePeopleSteed, Double)] = [(far, -Self.horseApart), (near, Self.horseApart)]
        let spin = pose == .walking ? -Double(frame) * Self.turn : (pose == .fighting ? 4 * BronzePeopleKit.wave(frame) : 0)
        let bounce = pose == .walking ? 0.7 * abs(BronzePeopleKit.wave(frame, 0.1, times: 1)) : 0
        let place = P(at(-1, 0), Self.floor - bounce)

        // The shadow, as long as the chariot shows and as wide.
        d.svg.ellipse(P(at(42, 0), 0.2), 62 * abs(c) + 24 * abs(s), 4.4, fill: .colour("#000000"), opacity: 0.13)

        /// The side drawing of a part at depth `z`, foreshortened.
        func side(_ svg: inout SVG, z: Double, _ content: (inout SVG) -> Void) {
            svg.raw("<g transform=\"translate(\(num(-z * s)),0) scale(\(num(abs(c))),1)\">")
            content(&svg)
            svg.raw("</g>")
        }
        func horses(_ svg: inout SVG) {
            // The farther horse first; from straight ahead or behind, where neither is farther, the off horse.
            for (horse, z) in teams.sorted(by: { ($0.1 * c, $0.1) < ($1.1 * c, $1.1) }) {
                if endOn {
                    horse.drawEndOn(&svg, at: -z * s, front: front, near: z > 0)
                } else {
                    side(&svg, z: z) { horse.draw(&$0, near: z > 0) }
                }
            }
        }
        func pole(_ svg: inout SVG) {
            let yoke = near.withers + P(1.4, -0.6)
            if endOn {
                svg.line([P(0, -14.8 - bounce), P(0, yoke.y)], stroke: .colour(Ink.line), width: 3.2)
                svg.line([P(0, -14.8 - bounce), P(0, yoke.y)], stroke: .colour(BronzePeopleInk.wood), width: 1.8)
                // The yoke across both horses' withers.
                let half = Self.horseApart + 6
                svg.line([P(-half, yoke.y + 1), P(0, yoke.y - 0.8), P(half, yoke.y + 1)], stroke: .colour(Ink.line), width: 3.4)
                svg.line([P(-half, yoke.y + 1), P(0, yoke.y - 0.8), P(half, yoke.y + 1)], stroke: .colour(BronzePeopleInk.wood), width: 2)
                for x in [-Self.horseApart, Self.horseApart] {
                    svg.polygon([P(x - 2.8, yoke.y + 2), P(x, yoke.y - 1.8), P(x + 2.8, yoke.y + 2)], fill: .colour(BronzePeopleInk.bronze),
                                stroke: .colour(Ink.line), width: 1)
                }
            } else {
                side(&svg, z: 0) { svg in
                    var pole = PathData()
                    pole.move(P(12, -14.8 - bounce)); pole.quad(P(40, -15 - bounce), yoke)
                    svg.path(pole, stroke: .colour(Ink.line), width: 3.2)
                    svg.path(pole, stroke: .colour(BronzePeopleInk.wood), width: 1.8)
                }
            }
        }
        func wheels(_ svg: inout SVG, near: Bool?) {
            for z in [-Self.track, Self.track] where near == nil || (z > 0) == near! {
                if endOn {
                    Self.wheelEndOn(&svg, at: P(-z * s, -Self.wheelRadius - bounce * 0), outward: -z * s > 0 ? 1 : -1)
                } else {
                    side(&svg, z: z) { Self.wheel(&$0, at: P(0, -Self.wheelRadius), degrees: spin, far: z < 0) }
                }
            }
        }
        func reins(_ svg: inout SVG, _ d: Drawing) {
            let lean = d.rig.lean * c
            func hand(_ front: Bool) -> P {
                d.hand(front: front).rotated(lean, about: Drawing.hips) + P(0, d.bob) + place
            }
            let slack = pose == .walking ? 0.6 : 4
            let hands = pose == .fighting ? [hand(false), hand(false)] : [hand(true), hand(false)]
            for (hand, (horse, z)) in zip(hands, [(near, Self.horseApart), (far, -Self.horseApart)]) {
                let bit = P(at(horse.mouth.x, z), horse.mouth.y)
                var rein = PathData()
                rein.move(hand); rein.quad((hand + bit) * 0.5 + P(0, slack), bit)
                svg.path(rein, stroke: .colour(Ink.line), width: 0.9)
            }
        }

        if front {
            // From in front: the far wheel, the car's far side, the driver, the car's front and near side, the near wheel, the pole and the horses.
            if !endOn {
                wheels(&d.svg, near: false)
                side(&d.svg, z: -Self.carHalf) { Self.car(&$0, rise: bounce) }
            }
            Self.driverInView(&d, pose, frame, at: place)
            if endOn {
                wheels(&d.svg, near: nil)
                Self.carFace(&d.svg, view: view, rise: bounce, inside: false)
            } else {
                side(&d.svg, z: Self.carHalf) { Self.car(&$0, rise: bounce) }
                Self.carFace(&d.svg, view: view, rise: bounce, inside: false)
                wheels(&d.svg, near: true)
            }
            reins(&d.svg, d)
            pole(&d.svg)
            horses(&d.svg)
        } else {
            // From behind: the horses, the pole, the far wheel, the inside of the car, the driver, the car's near side and the near wheel.
            horses(&d.svg)
            pole(&d.svg)
            if endOn {
                wheels(&d.svg, near: nil)
            } else {
                wheels(&d.svg, near: false)
            }
            Self.carFace(&d.svg, view: view, rise: bounce, inside: true)
            if !endOn { side(&d.svg, z: -Self.carHalf) { Self.car(&$0, rise: bounce) } }
            Self.driverInView(&d, pose, frame, at: place)
            reins(&d.svg, d)
            if endOn {
                Self.carBack(&d.svg, rise: bounce)
            } else {
                side(&d.svg, z: Self.carHalf) { Self.car(&$0, rise: bounce) }
                wheels(&d.svg, near: true)
            }
        }

        // Dust thrown up by the hooves at the gallop, and by the forefeet as they come down.
        if pose == .walking && (frame % 6 == 2 || frame % 6 == 3) {
            let hoof = near.hoof(.hind)
            BronzePeopleProps.dust(&d.svg, at: P(at(hoof.x - 5, Self.horseApart), hoof.y - 1), size: frame % 6 == 2 ? 0.8 : 1.1, opacity: 0.5)
        }
        if pose == .fighting && (frame == 0 || frame == 11) {
            for (horse, z) in teams {
                let hoof = horse.hoof(.fore)
                d.burst(at: P(at(hoof.x + 1, z), hoof.y - 1), from: endOn ? 60 : 100, to: endOn ? 300 : 170, size: 0.9)
            }
        }
    }

    /// The driver in the view, standing on the car's floor at `at`: the legs
    /// only where the open back shows them, the sash from shoulder to hip, the
    /// khopesh in the figure's own plane, and his hair, beard and headband.
    static func driverInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int, at place: P) {
        let lean = d.rig.lean * cos(d.yaw * .pi / 180)
        let at = place + P(0, d.bob)
        let back = BronzePeopleViews.seesBack(d.view)
        d.svg.raw("<g transform=\"translate(\(num(at.x)),\(num(at.y))) rotate(\(num(lean)) \(num(Drawing.hips.x)) \(num(Drawing.hips.y)))\">")
        let outline = [P(-8, -47), P(8.4, -47), P(11.4, -19.4), P(-12, -19.4)]
        let bladeBehind = d.armBehind(front: true)
        d.arm(front: false)
        if back { d.legs() }
        if pose == .fighting && bladeBehind { khopeshInView(&d, frame) }
        d.garment(colour: [P(-11.6, -46), P(8.6, -48), P(12.4, -18), P(-13.4, -17.4)],
                  outline: outline, fill: .colour(BronzePeopleInk.light)) { d in
            for via in [0.0, 180.0] {
                for run in BronzePeopleViews.across(d, on: outline, top: (-45, 270), bottom: (-23.4, 90), via: via, width: 5) {
                    d.svg.polygon(run.map(d.up), fill: .team)
                }
            }
        }
        if pose == .fighting && !bladeBehind { khopeshInView(&d, frame) }
        d.arm(front: true)
        let flutter = pose == .walking ? 2.6 + BronzePeopleKit.wave(frame, times: 3) : 0.6 * BronzePeopleKit.wave(frame)
        d.head(nose: .line, behind: { d in
            if d.view == .frontQuarter { headbandEnds(&d, flutter: flutter) }
        }, hair: { d in
            d.svg.path(Hunter.hair(d.view), fill: .colour(Ink.line))
        }, features: { d in
            // A short pointed beard.
            guard d.view == .front || d.view == .frontQuarter else { return }
            let beard = [P(-3, -49.6), P(0, -49), P(3, -49.6), P(1.4, -45.6), P(0, -44), P(-1.4, -45.6)]
            d.svg.polygon(BronzePeopleViews.onFace(d.view, beard.map { $0 + P(d.view == .frontQuarter ? 0.8 : 0, 0) }), fill: .colour(Ink.line))
        }, brow: { d in
            d.svg.path("M1.8,-63.8 q3.2,-1.6 6.4,-0.6", stroke: .colour(Ink.line), width: 1.4)
        }, over: { d in
            let band = Array(BronzePeopleViews.ring(d.view, out: 1.2, headbandEdge).dropFirst(1).dropLast(1))
            d.svg.line(band, stroke: .colour(Ink.line), width: 3.4)
            d.svg.line(band, stroke: .colour(BronzePeopleInk.verdigris), width: 1.8)
            if BronzePeopleViews.seesBack(d.view) { headbandEnds(&d, flutter: flutter) }
        })
        d.svg.raw("</g>")
    }

    /// The headband's line round the head.
    static let headbandEdge = BronzePeopleViews.edge(front: -65.4, side: -63, back: -61.6)

    /// The headband's two ends, streaming behind from the knot at the back of the head.
    static func headbandEnds(_ d: inout Drawing, flutter: Double) {
        let knot = BronzePeopleViews.onHead(d.view, degrees: 180, y: -62, out: 1).point
        let backward = -cos(d.yaw * .pi / 180), spread = d.view == .back ? 1.0 : 0.4
        for (i, (dy, length)) in [(0.0, 10.0), (1.6, 8.0)].enumerated() {
            let side = (Double(i) * 2 - 1) * spread
            let top = knot + P(side, dy)
            let end = top + P(-(length - flutter * 0.4) * backward + side * (3 + flutter), 3.6 - flutter * 1.3 + dy + (1 - abs(backward)) * 4)
            d.svg.polygon([top + P(-0.6, -0.8), top + P(0.6, 0.8), end + P(0.4, 0.5), end + P(-0.4, -0.5)],
                          fill: .colour(BronzePeopleInk.verdigris), stroke: .colour(Ink.line), width: 0.8)
        }
    }

    /// The khopesh at the front hand, turned in the figure's own plane, and where its blow lands.
    static func khopeshInView(_ d: inout Drawing, _ frame: Int) {
        let hand = d.hand(front: true)
        let (degrees, reach) = BronzePeopleViews.onScreen(d.view, d.rig.frontArm.upper - 4)
        khopesh(&d.svg, at: hand, degrees: degrees)
        if frame == 8 { d.impact(at: hand + P.direction(degrees) * (15 * reach), size: 1) }
    }

    /// The car's front: seen from in front, its outside, painted in the team's
    /// colour with a border and a rosette; from behind, its inside, in shade.
    static func carFace(_ svg: inout SVG, view: SpriteView, rise: Double, inside: Bool) {
        let yaw = view.yaw * .pi / 180, c = cos(yaw), s = sin(yaw)
        func at(_ x: Double, _ y: Double, _ z: Double) -> P { P(x * c - z * s, y - rise) }
        // The front's curve, from the floor up to the rail.
        let curve: [P] = (0...8).map { i in
            let t = Double(i) / 8, m = 1 - t
            let a = P(14.6, floor), b = P(18.2, -22.6), e = P(18.4, -35.6), f = P(12.8, -42.4)
            return a * (m * m * m) + b * (3 * m * m * t) + e * (3 * m * t * t) + f * (t * t * t)
        }
        let w = carHalf
        let face = curve.map { at($0.x, $0.y, w) } + curve.reversed().map { at($0.x, $0.y, -w) }
        svg.polygon(face.map { $0 + P(-0.8, 0.7) }, fill: .team)
        if inside {
            svg.polygon(face, fill: .colour("#000000"), opacity: 0.22)
        } else {
            let border = curve.dropFirst().dropLast().map { at($0.x - 1, $0.y, w - 2.2) }
                + curve.dropFirst().dropLast().reversed().map { at($0.x - 1, $0.y, -w + 2.2) }
            svg.polygon(border, fill: .none, stroke: .colour(BronzePeopleInk.light), width: 1.2)
            let rosette = at(17.6, -28.6, 0)
            for i in 0..<8 {
                svg.circle(rosette + P.direction(Double(i) * 45) * 2.6, 1.1, fill: .colour(BronzePeopleInk.light))
            }
            svg.circle(rosette, 1.3, fill: .colour(BronzePeopleInk.gold), stroke: .colour(Ink.line), width: 0.5)
        }
        svg.polygon(face, fill: .none, stroke: .colour(Ink.line), width: 1.6)
        // The rail across the top, of bent wood capped in bronze.
        let rail = [at(12.6, -43, w), at(12.6, -43, -w)]
        svg.line(rail, stroke: .colour(Ink.line), width: 3)
        svg.line(rail, stroke: .colour(BronzePeopleInk.bronze), width: 1.6)
        svg.line([at(15.4, floor, w), at(15.4, floor, -w)], stroke: .colour(Ink.line), width: 2.2)
    }

    /// The car's open back, seen from straight behind: the side panels end on,
    /// their rails sloping down to the back, and the floor across.
    static func carBack(_ svg: inout SVG, rise: Double) {
        let up = P(0, -rise), w = carHalf
        for x in [-w, w] {
            let panel = [P(x - 1.4, floor), P(x + 1.4, floor), P(x + 1.4, -36.2), P(x - 1.4, -36.2)].map { $0 + up }
            svg.polygon(panel.map { $0 + P(-0.6, 0.5) }, fill: .team)
            svg.polygon(panel, fill: .none, stroke: .colour(Ink.line), width: 1.2)
            svg.line([P(x, -36.2) + up, P(x * 0.96, -43) + up], stroke: .colour(Ink.line), width: 3)
            svg.line([P(x, -36.2) + up, P(x * 0.96, -43) + up], stroke: .colour(BronzePeopleInk.bronze), width: 1.6)
        }
        svg.line([P(-w - 2, floor) + up, P(w + 2, floor) + up], stroke: .colour(Ink.line), width: 2.4)
        svg.line([P(-w - 1.6, floor - 0.2) + up, P(w + 1.6, floor - 0.2) + up], stroke: .colour(BronzePeopleInk.wood), width: 1)
    }

    /// A wheel seen end on, centred on `c`: the rim as an upright band, and the hub standing out on the side `outward`.
    static func wheelEndOn(_ svg: inout SVG, at c: P, outward: Double) {
        let r = wheelRadius, half = 2.0
        let rim = [c + P(-half, -r), c + P(half, -r), c + P(half, r), c + P(-half, r)]
        svg.polygon(rim, fill: .colour(BronzePeopleInk.wood), stroke: .colour(Ink.line), width: 1.4)
        svg.line([c + P(0, -r + 1.4), c + P(0, r - 1.4)], stroke: .colour(Ink.line), width: 0.7, opacity: 0.6)
        let hub = [c + P(0, -2.6), c + P(outward * 4.4, -2), c + P(outward * 4.4, 2), c + P(0, 2.6)]
        svg.polygon(hub, fill: .colour(BronzePeopleInk.bronze), stroke: .colour(Ink.line), width: 1)
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
