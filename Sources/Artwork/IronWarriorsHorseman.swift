// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// MARK: - The horseman

/// A horseman: a rider on the shared figure, seated on a bay horse drawn as the
/// chariot's horses are (`BronzePeopleSteed`), over a saddle cloth of the
/// team's colour, fringed and patterned in the light, under a leather saddle
/// with horns. The rider wears an iron helmet with a cheek guard and a plume of
/// legion red, a shirt of iron mail over a sea-green tunic, and a sea-green cloak
/// that streams behind him; a heavy moustache; nose F. He carries a spear with
/// a pennant of the team's colour below its blade, and holds the reins in his
/// other hand. Standing, the horse breathes and tosses its head; walking, it
/// trots, the legs moving in diagonal pairs, and the rider rises with the
/// stride; fighting, the horse paws the ground whilst the rider raises the
/// spear overhand and drives it forward over the horse's head. The origin is
/// on the ground at the centre of the horse's hooves.
struct IronWarriorsHorseman: PersonLook {
    static let canvas = Canvas(minX: -56, minY: -146, width: 152, height: 152, pixelsPerUnit: Canvas.person.pixelsPerUnit)

    /// Where the horse stands, in its own units, so that the centre of its hooves is at the origin.
    static let horseOrigin = P(-0.8, 0)
    /// The horse is the chariot's horse drawn larger, so that it stands
    /// rightly to its rider: its withers come to about the height of a man's shoulder.
    static let horseScale = 1.3
    /// The saddle sits back from the withers, so that the rider clears the horse's neck.
    static let seatShift = P(-4.4, 0.3)

    // MARK: The rider

    /// One frame of the overhand strike: the spear hand and the spear's direction.
    static let strike: [(hand: P, degrees: Double)] = [
        (P(13, -40), 150), (P(14.4, -45), 134), (P(15.6, -49), 118), (P(16.6, -51.6), 108), (P(16.4, -53), 102), (P(16, -53.4), 102),
        (P(18.6, -52.6), 92), (P(21.6, -51.6), 86), (P(22.4, -51.2), 85), (P(20, -51.6), 90), (P(17, -47), 112), (P(14.4, -42), 138),
    ]

    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        var r = Moves.standing(pose == .standing ? frame : 0)
        r.backLeg = Limb(-4, 4); r.frontLeg = Limb(34, 50)
        r.mouth = .firm
        switch pose {
        case .standing:
            r.lean = 1
            r.frontArm = BronzePeopleKit.reach(IronWarriorsKit.frontShoulder(r), P(15, -38 - r.lift))
        case .walking:
            r.lean = 4
            r.lift = 0
            r.frontArm = BronzePeopleKit.reach(IronWarriorsKit.frontShoulder(r), P(13.4, -40 + 0.6 * BronzePeopleKit.wave(frame, times: 2)))
        case .fighting:
            let s = Self.strike[frame]
            r.lift = 0
            r.lean = [2, 0, -2, -4, -5, -5, 2, 9, 10, 7, 4, 3][frame]
            r.frontArm = BronzePeopleKit.reach(IronWarriorsKit.frontShoulder(r), s.hand, elbowUp: s.hand.y < -50)
            r.mouth = frame == 7 || frame == 8 ? .shout : .firm
            r.eyes = frame == 8 ? .wide : .open
        default:
            return nil
        }
        r.backArm = BronzePeopleKit.reach(IronWarriorsKit.backShoulder(r), P(9, -33))
        return r
    }

    // MARK: The horse

    static func horse(_ pose: SpritePose, _ frame: Int) -> BronzePeopleSteed.Pose {
        let t = Double(frame) / 12
        var p = BronzePeopleSteed.Pose()
        switch pose {
        case .walking:
            // A trot: the near fore and far hind move together, then the other pair.
            func fore(_ shift: Double) -> Limb {
                let s = 2 * .pi * (t + shift)
                return Limb(5 + 22 * sin(s), 6 + 76 * pow(max(0, cos(s)), 1.4))
            }
            func hind(_ shift: Double) -> Limb {
                let s = 2 * .pi * (t + shift)
                return Limb(-12 + 19 * sin(s), 18 + 46 * pow(max(0, cos(s)), 1.4))
            }
            p.fore = fore(0); p.farHind = hind(0.02)
            p.hind = hind(0.5); p.farFore = fore(0.52)
            let s = 4 * .pi * t
            p.pitch = 1.2 * sin(s + 0.8)
            p.neck = -1.5 + 2.4 * sin(s + 1.4)
            p.tail = 0.45 + 0.2 * sin(s)
            p.mane = 0.5 + 0.35 * sin(s + 0.4)
        case .fighting:
            // The near forefoot paws the ground as the rider strikes, the head up and the ears laid back.
            let up = pow(sin(.pi * t), 2)
            p.fore = Limb(4 + 40 * up, 4 + 86 * up)
            p.farFore = Limb(3 - 2 * up, 3)
            p.hind = Limb(-16 - 3 * up, 22 + 4 * up)
            p.farHind = Limb(-14 - 3 * up, 20 + 4 * up)
            p.pitch = 4 * up
            p.neck = 4 * up
            p.tail = 0.3 * up
            p.mane = 0.5 * up
            p.mouthOpen = up > 0.5
            p.earBack = up > 0.3
        default:
            let s = 2 * .pi * t
            p.lift = 0.4 * sin(s)
            p.neck = -2 + 7 * pow(max(0, sin(s)), 3)
            p.tail = 0.25 * sin(s * 2)
            p.mane = 0.15 * sin(s)
            p.blink = frame == 5
            p.earBack = frame >= 3 && frame <= 6
        }
        return p
    }

    // MARK: Drawing

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        if d.view != .side { drawInView(&d, pose, frame); return }
        let horse = BronzePeopleSteed(at: Self.horseOrigin, pose: Self.horse(pose, frame), coat: "#8e5634", shade: "#5f3820")
        let k = Self.horseScale
        d.svg.ellipse(P(0, 0.2), 38, 4.2, fill: .colour("#000000"), opacity: 0.13)
        d.svg.raw("<g transform=\"scale(\(num(k)))\">")
        horse.draw(&d.svg, near: true)
        Self.saddle(&d.svg, horse)
        d.svg.raw("</g>")
        // The rider rises from the saddle with each stride of the trot.
        let rise = pose == .walking ? 1.1 + 1.1 * sin(4 * .pi * Double(frame) / 12 + 0.6) : 0
        let seat = horse.body(P(-1.6, -48.4) + Self.seatShift) * k + P(0, -rise)
        let at = seat - P(0, -15)
        Self.rider(&d, pose, frame, at: at, bit: horse.mouth * k)
        // Dust kicked up by the hooves as they strike the ground.
        if pose == .walking && frame % 6 == 1 {
            BronzePeopleProps.dust(&d.svg, at: horse.hoof(frame < 6 ? .hind : .fore) * k + P(-5, -1), size: 0.8, opacity: 0.45)
        }
        if pose == .fighting && frame == 11 {
            d.burst(at: horse.hoof(.fore) * k + P(1, -1), from: 100, to: 170, size: 0.9)
        }
    }

    /// The saddle cloth, in the team's colour with a border and a zigzag in the
    /// light and a fringe at its hem, and the leather saddle over it.
    static func saddle(_ svg: inout SVG, _ horse: BronzePeopleSteed) {
        func seatAt(_ p: P) -> P { horse.body(p + seatShift) }
        let cloth = [P(-10.4, -47.4), P(7.4, -48.6), P(9.4, -33.2), P(-11.6, -32.6)].map(seatAt)
        svg.polygon(cloth.map { $0 + P(-0.7, 0.6) }, fill: .team)
        let inner = [P(-8.8, -45.4), P(6.2, -46.4), P(7.6, -35.2), P(-10, -34.8)].map(seatAt)
        svg.polygon(inner, fill: .none, stroke: .colour(IronWarriorsInk.light), width: 1)
        var zig = PathData()
        for i in 0...8 {
            let x = -8.6 + Double(i) * 2
            let p = seatAt(P(x, -37.2 - (i % 2 == 0 ? 0 : 2.2) + x * 0.02))
            if i == 0 { zig.move(p) } else { zig.line(p) }
        }
        svg.path(zig, stroke: .colour(IronWarriorsInk.light), width: 0.9)
        svg.polygon(cloth, fill: .none, stroke: .colour(Ink.line), width: 1.3)
        var fringe = PathData()
        for i in 0..<9 {
            let x = -10.8 + Double(i) * 2.5
            let top = seatAt(P(x, -32.8 + 0.03 * x))
            fringe.move(top); fringe.line(top + P(-0.3, 2.2))
        }
        svg.path(fringe, stroke: .colour(Ink.line), width: 0.9)
        // The saddle, with a horn before and behind the seat.
        let seat = [P(-9.6, -47.6), P(-8.6, -51.6), P(-6.4, -49.6), P(3.4, -50.2), P(5.8, -52.6), P(7, -48.8), P(6.4, -46.4), P(-8.8, -45.6)]
        IronWarriorsKit.shape(&svg, seat.map(seatAt), fill: .colour(IronWarriorsInk.leather), width: 1.2)
        // The girth under the belly.
        svg.line([seatAt(P(3.4, -46.4)), seatAt(P(4.6, -27.6))], stroke: .colour(Ink.line), width: 2.2)
        svg.line([seatAt(P(3.4, -46.4)), seatAt(P(4.6, -27.6))], stroke: .colour(IronWarriorsInk.leather), width: 1)
    }

    /// The rider, his figure's origin at `at`: the cloak, the reins, the near
    /// leg down the horse's side, the mail, the spear and the head.
    static func rider(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int, at: P, bit: P) {
        let lean = d.rig.lean
        func world(_ p: P) -> P { at + p.rotated(lean, about: Drawing.hips) }
        d.svg.raw("<g transform=\"translate(\(num(at.x)),\(num(at.y))) rotate(\(num(lean)) \(num(Drawing.hips.x)) \(num(Drawing.hips.y)))\">")
        // The cloak, streaming back from the shoulders.
        let flutter: Double
        switch pose {
        case .walking: flutter = 1 + 0.5 * BronzePeopleKit.wave(frame, times: 2)
        case .fighting: flutter = 0.4 + 0.3 * BronzePeopleKit.wave(frame)
        default: flutter = 0.15 * BronzePeopleKit.wave(frame)
        }
        let neckBack = d.up(P(-4, -48.4)), shoulderBack = d.up(P(-12, -46)), under = d.up(P(-6.6, -44))
        BronzePeopleProps.shape(&d.svg, fill: .colour(IronWarriorsInk.deepSea), width: 1.3) { o in
            var p = PathData()
            p.move(neckBack + o)
            p.cubic(shoulderBack + o, P(-16 - flutter * 4, -36 + flutter) + o, P(-19 - flutter * 7, -24 - flutter * 3) + o)
            p.line(P(-15 - flutter * 6, -22.6 - flutter * 2.4) + o)
            p.line(P(-12.4 - flutter * 4, -25 - flutter * 1.6) + o)
            p.cubic(P(-11, -32) + o, P(-9.6, -40) + o, under + o)
            p.close()
            return p
        }
        d.arm(front: false)
        // The near leg, down the horse's side, in a leather boot.
        let hip = Joints.frontHip
        let knee = hip + P.direction(34) * Joints.thigh
        let foot = knee + P.direction(34 - 50) * Joints.shin
        d.svg.line([hip, knee, foot], stroke: .colour(Ink.line), width: 3.6)
        d.svg.line([hip, knee, foot], stroke: .colour(IronWarriorsInk.deepSea), width: 1.8)
        let u = P.direction(-16)
        IronWarriorsKit.shape(&d.svg, [foot - u * 5 + P(-1.6, 0), foot - u * 5 + P(1.8, 0), foot + P(5.6, 0.2), foot + P(5.2, 2), foot + P(-1.8, 1.8)],
                              fill: .colour(IronWarriorsInk.leather), width: 1.1)
        // The tunic's skirt over the thigh.
        d.garment(colour: [P(-12.4, -30), P(11.6, -30.4), P(17.4, -17.4), P(6, -14.8), P(-9.4, -19.4)],
                  outline: [P(-11, -29.6), P(11, -29.6), P(16.2, -18.4), P(5.6, -16), P(-8.6, -20.4)], fill: .colour(IronWarriorsInk.deepSea)) { d in
            d.svg.line([P(-8.2, -21.8), P(5.4, -17.4), P(15.2, -19.6)], stroke: .colour(IronWarriorsInk.paleSea), width: 1.2)
        }
        // The mail shirt: rows of iron rings.
        d.garment(colour: [P(-12.2, -46.4), P(9.2, -48.4), P(12.6, -27.4), P(-13.6, -27)],
                  outline: [P(-8.4, -47.2), P(8.8, -47.2), P(12, -28.4), P(-12.8, -28.4)], fill: .colour(IronWarriorsInk.iron)) { d in
            var rings = PathData()
            for row in 0..<6 {
                let y = -44.6 + Double(row) * 3
                let half = 8.6 + Double(row) * 0.6
                var x = -half + Double(row % 2) * 1.3
                while x < half - 0.6 {
                    let p = d.up(P(x, y))
                    rings.move(p); rings.quad(p + P(1.2, 1.6), p + P(2.4, 0))
                    x += 2.6
                }
            }
            d.svg.path(rings, stroke: .colour(IronWarriorsInk.ironDark), width: 0.7)
        }
        d.svg.line([d.up(P(-13, -28.6)), d.up(P(12.2, -28.8))], stroke: .colour(Ink.line), width: 3)
        d.svg.line([d.up(P(-12.6, -28.6)), d.up(P(11.8, -28.8))], stroke: .colour(IronWarriorsInk.leather), width: 1.6)
        // The spear.
        let hand = d.joints.frontHand
        switch pose {
        case .fighting:
            let degrees = strike[frame].degrees
            spear(&d.svg, at: hand, degrees: degrees, ahead: 44, behind: 10, flutter: Double(frame) / 12)
            let tip = hand + P.direction(degrees) * 44
            if frame == 7 {
                d.svg.path("M\(num(tip.x - 26)),\(num(tip.y - 5)) l12,1.2 M\(num(tip.x - 24)),\(num(tip.y + 2.6)) l12,1.2",
                           stroke: .colour(Ink.line), width: 1.1, opacity: 0.6)
            }
            if frame == 8 { d.impact(at: tip + P.direction(degrees) * 1.4, size: 1) }
        case .walking:
            spear(&d.svg, at: hand, degrees: 146 + BronzePeopleKit.wave(frame, times: 2), ahead: 40, behind: 16, flutter: Double(frame) / 6)
        default:
            spear(&d.svg, at: hand, degrees: 176, ahead: 44, behind: 12, flutter: Double(frame) / 12)
        }
        d.arm(front: true)
        d.head(nose: .bulb, hair: { d in
            d.svg.path("M-10.2,-55 C-11.4,-58 -11,-60.6 -9.6,-62.6 L-6.8,-58 Z", fill: .colour(Ink.line))
        }, features: { d in
            // A heavy moustache, drooping at the ends.
            d.svg.path("M3,-53.4 q4.4,-2.4 8.6,-0.6 q0.6,2.4 -0.6,4.4 q-1.4,-2.2 -3.6,-2.2 q-2.4,-0.2 -4.4,-1.6 Z", fill: .colour(Ink.line))
        }, brow: { d in
            d.svg.path("M1.4,-63.6 q3.6,-1.8 7,-0.4", stroke: .colour(Ink.line), width: 1.8)
        }, over: { d in
            IronWarriorsKit.helmet(&d, crest: .plume)
        })
        d.svg.raw("</g>")
        // The reins, from the hand to the bit.
        let reinHand = world(d.joints.backHand)
        var rein = PathData()
        rein.move(reinHand); rein.quad((reinHand + bit) * 0.5 + P(0, pose == .walking ? 1.6 : 3.4), bit)
        d.svg.path(rein, stroke: .colour(Ink.line), width: 0.9)
    }

    /// A spear through `hand`: an iron head `ahead` along `degrees`, a pennant of
    /// the team's colour below it, its butt `behind`.
    static func spear(_ svg: inout SVG, at hand: P, degrees: Double, ahead: Double, behind: Double, flutter: Double) {
        let u = P.direction(degrees), a = P(-u.y, u.x)
        let tip = hand + u * ahead, butt = hand - u * behind
        // The pennant, tied below the head and streaming back from the shaft.
        let tie = tip - u * 13
        let back = P(-1, 0.25)
        func w(_ along: Double) -> Double { 1.2 * sin(2 * .pi * flutter - along * 2.4) * along }
        let flag = [tie, tie - u * 5.6, tie - u * 5.6 + back * 11 + P(0, 1.2 + w(1)), tie - u * 2.8 + back * 7.6 + P(0, w(0.7)),
                    tie + back * 11 + P(0, -0.6 + w(1))]
        svg.polygon(flag.map { $0 + P(-0.6, 0.6) }, fill: .team)
        svg.polygon(flag, fill: .none, stroke: .colour(Ink.line), width: 1)
        svg.line([butt, tip - u * 6], stroke: .colour(Ink.line), width: 2.8)
        svg.line([butt + u * 0.6, tip - u * 6.2], stroke: .colour(IronWarriorsInk.wood), width: 1.5)
        // The iron head, long and narrow.
        let base = tip - u * 9
        IronWarriorsKit.shape(&svg, [base + a * 1.2, base + u * 4 + a * 2.2, tip, base + u * 4 - a * 2.2, base - a * 1.2],
                              fill: .colour(IronWarriorsInk.ironLight), width: 1)
        svg.line([base + u * 1, tip - u * 1.6], stroke: .colour(IronWarriorsInk.ironDark), width: 0.6)
        svg.line([butt, butt - u * 2.2], stroke: .colour(IronWarriorsInk.ironDark), width: 2.2)
    }
}

// MARK: - The horseman in the other views

extension IronWarriorsHorseman {
    /// Half the horse's width across its barrel, and half its length, in its own units.
    static let halfWidth = 10.0, halfLength = 20.5

    /// The share of its length the horse shows in a view: the length
    /// foreshortened, with the width seen across it.
    static func share(_ view: SpriteView) -> Double {
        let (c, s) = IronViews.turn(view)
        let w = halfWidth / halfLength
        return (c * c + w * w * s * s).squareRoot()
    }

    /// The horseman seen from the front, from behind, or from a quarter turn.
    /// From a quarter the horse is its side drawing foreshortened, as the car
    /// is. Seen end on, the horse is drawn anew: from the front its long face
    /// and chest before the rider, from behind its rump and tail after him.
    func drawInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let view = d.view
        let horse = BronzePeopleSteed(at: Self.horseOrigin, pose: Self.horse(pose, frame), coat: "#8e5634", shade: "#5f3820")
        let k = Self.horseScale
        let endOn = view == .front || view == .back
        let share = endOn ? 0 : Self.share(view)
        let rise = pose == .walking ? 1.1 + 1.1 * sin(4 * .pi * Double(frame) / 12 + 0.6) : 0
        let seat = horse.body(P(-1.6, -48.4) + Self.seatShift) * k + P(0, -rise)
        let at = P(seat.x * share, seat.y + 15)
        let face = Self.EndOn(horse: horse)
        let bit: P
        if endOn {
            bit = (view == .front ? face.at(0, -53.4) : face.at(0, -62)) * k
        } else {
            bit = P(horse.mouth.x * share, horse.mouth.y) * k
        }
        d.svg.ellipse(P(0, 0.2), endOn ? 19 : 38 * share + 4, 4.2, fill: .colour("#000000"), opacity: 0.13)
        d.svg.raw("<g transform=\"scale(\(num(k)))\">")
        if endOn {
            face.body(&d.svg, front: view == .front)
        } else {
            d.svg.raw("<g transform=\"scale(\(num(share)),1)\">")
            horse.draw(&d.svg, near: true)
            Self.saddle(&d.svg, horse)
            d.svg.raw("</g>")
        }
        d.svg.raw("</g>")
        Self.riderInView(&d, pose, frame, at: at, bit: bit)
        if endOn {
            d.svg.raw("<g transform=\"scale(\(num(k)))\">")
            face.ahead(&d.svg, front: view == .front)
            d.svg.raw("</g>")
        }
        // Dust kicked up by the hooves as they strike the ground.
        func hoof(_ kind: BronzePeopleSteed.Leg) -> P {
            let h = horse.hoof(kind)
            return endOn ? P(view == .front ? -4.4 : 4.4, h.y) * k : P(h.x * share, h.y) * k
        }
        if pose == .walking && frame % 6 == 1 {
            BronzePeopleProps.dust(&d.svg, at: hoof(frame < 6 ? .hind : .fore) + P(-5 * share, -1), size: 0.8, opacity: 0.45)
        }
        if pose == .fighting && frame == 11 {
            d.burst(at: hoof(.fore) + P(1, -1), from: 100, to: 170, size: 0.9)
        }
    }

    /// The rider in a view other than the side, his figure's origin at `at`.
    static func riderInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int, at: P, bit: P) {
        let view = d.view, behind = IronViews.fromBehind(view)
        let (c, _) = IronViews.turn(view)
        let lean = d.rig.lean * c
        d.svg.raw("<g transform=\"translate(\(num(at.x)),\(num(at.y))) rotate(\(num(lean)) \(num(Drawing.hips.x)) \(num(Drawing.hips.y)))\">")
        let flutter: Double
        switch pose {
        case .walking: flutter = 1 + 0.5 * BronzePeopleKit.wave(frame, times: 2)
        case .fighting: flutter = 0.4 + 0.3 * BronzePeopleKit.wave(frame)
        default: flutter = 0.15 * BronzePeopleKit.wave(frame)
        }
        func cloak(_ d: inout Drawing) {
            let fill = Paint.colour(IronWarriorsInk.deepSea)
            switch d.view {
            case .front, .back:
                // From the front it spreads behind his shoulders; from behind it hangs down his back.
                let spread = d.view == .front ? 1.0 : 0.6
                let neckLeft = d.up(P(-8, -48)), neckRight = d.up(P(8, -48)), shoulderLeft = d.up(P(-11, -44)), shoulderRight = d.up(P(11, -44))
                BronzePeopleProps.shape(&d.svg, fill: fill, width: 1.3) { o in
                    var p = PathData()
                    p.move(neckLeft + o)
                    p.line(neckRight + o)
                    p.cubic(shoulderRight + o, P(12 + spread * 2 + flutter, -34) + o, P(12.6 + spread * 2 + flutter * 1.4, -24 - flutter * 2) + o)
                    p.cubic(P(5, -22.6 - flutter * 2) + o, P(-5, -22.6 - flutter * 2) + o, P(-12.6 - spread * 2 - flutter * 1.4, -24 - flutter * 2) + o)
                    p.cubic(P(-12 - spread * 2 - flutter, -34) + o, shoulderLeft + o, neckLeft + o)
                    p.close()
                    return p
                }
                if d.view == .back {
                    d.svg.path("M-4,-44 q-1.4,9 -2.6,19 M3,-44 q1.4,9 2.6,19", stroke: .colour(IronWarriorsInk.darkSea), width: 1)
                }
            default:
                let neckBack = d.up(P(-4, -48.4)), shoulderBack = d.up(P(-12, -46)), under = d.up(P(-6.6, -44))
                BronzePeopleProps.shape(&d.svg, fill: fill, width: 1.3) { o in
                    var p = PathData()
                    p.move(neckBack + o)
                    p.cubic(shoulderBack + o, P(-16 - flutter * 4, -36 + flutter) + o, P(-19 - flutter * 7, -24 - flutter * 3) + o)
                    p.line(P(-15 - flutter * 6, -22.6 - flutter * 2.4) + o)
                    p.line(P(-12.4 - flutter * 4, -25 - flutter * 1.6) + o)
                    p.cubic(P(-11, -32) + o, P(-9.6, -40) + o, under + o)
                    p.close()
                    return p
                }
            }
        }
        func boot(_ d: inout Drawing, hip: P, knee: P, foot: P, end: Bool) {
            d.svg.line([hip, knee, foot], stroke: .colour(Ink.line), width: 3.6)
            d.svg.line([hip, knee, foot], stroke: .colour(IronWarriorsInk.deepSea), width: 1.8)
            if end {
                IronWarriorsKit.shape(&d.svg, [foot + P(-1.8, -4.8), foot + P(1.8, -4.8), foot + P(2, 1.6), foot + P(-2, 1.6)],
                                      fill: .colour(IronWarriorsInk.leather), width: 1.1)
            } else {
                let u = P.direction(-16)
                IronWarriorsKit.shape(&d.svg, [foot - u * 5 + P(-1.6, 0), foot - u * 5 + P(1.8, 0), foot + P(5.6, 0.2), foot + P(5.2, 2), foot + P(-1.8, 1.8)],
                                      fill: .colour(IronWarriorsInk.leather), width: 1.1)
            }
        }
        func legs(_ d: inout Drawing) {
            if view == .front || view == .back {
                // Astride: down both flanks of the horse.
                for side in [-1.0, 1.0] {
                    boot(&d, hip: P(side * 4.2, -16), knee: P(side * 15.4, -8.4), foot: P(side * 15.8, 3.6), end: true)
                }
            } else {
                // The near leg down the horse's side, foreshortened.
                let hip = Joints.frontHip, knee = hip + P.direction(34) * Joints.thigh
                let foot = knee + P.direction(34 - 50) * Joints.shin
                func f(_ p: P) -> P { P(p.x * c, p.y) }
                boot(&d, hip: f(hip), knee: f(knee), foot: f(foot), end: false)
            }
        }
        let hand = d.hand(front: true)
        let spearBehind = d.armBehind(front: true)
        func spear(_ d: inout Drawing) {
            let (degrees, ahead, behindLength, wave): (Double, Double, Double, Double)
            switch pose {
            case .fighting: (degrees, ahead, behindLength, wave) = (strike[frame].degrees, 44, 10, Double(frame) / 12)
            case .walking: (degrees, ahead, behindLength, wave) = (146 + BronzePeopleKit.wave(frame, times: 2), 40, 16, Double(frame) / 6)
            default: (degrees, ahead, behindLength, wave) = (176, 44, 12, Double(frame) / 12)
            }
            let along = IronViews.tool(view, degrees)
            spearInView(&d.svg, view: view, at: hand, degrees: along.degrees, ahead: ahead * along.share, behind: behindLength * along.share,
                        flutter: wave)
            if pose == .fighting && frame == 8 {
                let tip = hand + P.direction(along.degrees) * (44 * along.share)
                d.impact(at: tip + P.direction(along.degrees) * 1.4, size: 1)
            }
        }
        if !behind { cloak(&d) }
        if spearBehind { spear(&d) }
        d.arm(front: false)
        legs(&d)
        d.garment(colour: [P(-12.4, -30), P(11.6, -30.4), P(17.4, -17.4), P(6, -14.8), P(-9.4, -19.4)],
                  outline: [P(-11, -29.6), P(11, -29.6), P(16.2, -18.4), P(5.6, -16), P(-8.6, -20.4)], fill: .colour(IronWarriorsInk.deepSea)) { d in
            let hem = IronViews.span(d, [P(-11, -29.6), P(11, -29.6), P(16.2, -18.4), P(5.6, -16), P(-8.6, -20.4)], at: -19)
            d.svg.line([P(hem.left + 0.6, -19.4), P(hem.right - 0.6, -19.4)], stroke: .colour(IronWarriorsInk.paleSea), width: 1.2)
        }
        let mail = [P(-8.4, -47.2), P(8.8, -47.2), P(12, -28.4), P(-12.8, -28.4)]
        d.garment(colour: [P(-12.2, -46.4), P(9.2, -48.4), P(12.6, -27.4), P(-13.6, -27)], outline: mail,
                  fill: .colour(IronWarriorsInk.iron)) { d in
            var rings = PathData()
            for row in 0..<6 {
                let y = -44.6 + Double(row) * 3
                let across = IronViews.span(d, mail, at: y)
                var x = across.left + 1 + Double(row % 2) * 1.3
                while x < across.right - 2.4 {
                    let p = d.up(P(x, y))
                    rings.move(p); rings.quad(p + P(1.2, 1.6), p + P(2.4, 0))
                    x += 2.6
                }
            }
            d.svg.path(rings, stroke: .colour(IronWarriorsInk.ironDark), width: 0.7)
        }
        let belt = IronViews.span(d, mail, at: -28.6)
        d.svg.line([d.up(P(belt.left - 0.4, -28.6)), d.up(P(belt.right + 0.4, -28.8))], stroke: .colour(Ink.line), width: 3)
        d.svg.line([d.up(P(belt.left, -28.6)), d.up(P(belt.right, -28.8))], stroke: .colour(IronWarriorsInk.leather), width: 1.6)
        if behind { cloak(&d) }
        if !spearBehind { spear(&d) }
        d.arm(front: true)
        d.head(nose: .bulb, hair: { d in
            if d.view == .frontQuarter {
                d.svg.path("M-10.2,-55 C-11.4,-58 -11,-60.6 -9.6,-62.6 L-6.8,-58 Z", fill: .colour(Ink.line))
            }
        }, features: { d in
            // A heavy moustache, drooping at the ends.
            switch d.view {
            case .front:
                d.svg.path("M-5.6,-52.8 q2.8,-2.4 5.6,-1 q2.8,-1.4 5.6,1 q0.8,2.4 -0.4,4.6 q-1.4,-2.4 -3,-2.4 q-1.4,0 -2.2,-0.6 "
                           + "q-0.8,0.6 -2.2,0.6 q-1.6,0 -3,2.4 q-1.2,-2.2 -0.4,-4.6 Z", fill: .colour(Ink.line))
            case .frontQuarter:
                d.svg.path("M1.2,-53.4 q4.4,-2.4 8.6,-0.6 q0.6,2.4 -0.6,4.4 q-1.4,-2.2 -3.6,-2.2 q-2.4,-0.2 -4.4,-1.6 Z", fill: .colour(Ink.line))
            default:
                break
            }
        }, brow: { d in
            d.svg.path("M1.4,-63.6 q3.6,-1.8 7,-0.4", stroke: .colour(Ink.line), width: 1.8)
        }, over: { d in
            IronWarriorsKit.helmet(&d, crest: .plume)
        })
        d.svg.raw("</g>")
        // The reins, from the hand to the bit.
        let reinHand = at + d.hand(front: false).rotated(lean, about: Drawing.hips)
        var rein = PathData()
        rein.move(reinHand); rein.quad((reinHand + bit) * 0.5 + P(0, pose == .walking ? 1.6 : 3.4), bit)
        d.svg.path(rein, stroke: .colour(Ink.line), width: 0.9)
    }

    /// The spear in a view: as `spear` draws it, its pennant streaming back as
    /// far as the view shows the back, and fluttering aside where it does not.
    static func spearInView(_ svg: inout SVG, view: SpriteView, at hand: P, degrees: Double, ahead: Double, behind: Double, flutter: Double) {
        let (c, _) = IronViews.turn(view)
        let u = P.direction(degrees), a = P(-u.y, u.x)
        let tip = hand + u * ahead, butt = hand - u * behind
        let tie = tip - u * min(13, ahead * 0.3)
        let back = P(-max(abs(c), 0.5), 0.25)
        func w(_ along: Double) -> Double { 1.2 * sin(2 * .pi * flutter - along * 2.4) * along }
        let fly = u * min(5.6, ahead * 0.13)
        let flag = [tie, tie - fly, tie - fly + back * 11 + P(0, 1.2 + w(1)), tie - fly * 0.5 + back * 7.6 + P(0, w(0.7)),
                    tie + back * 11 + P(0, -0.6 + w(1))]
        svg.polygon(flag.map { $0 + P(-0.6, 0.6) }, fill: .team)
        svg.polygon(flag, fill: .none, stroke: .colour(Ink.line), width: 1)
        let head = min(9, ahead * 0.2 + 1.6)
        svg.line([butt, tip - u * min(6, head * 0.66)], stroke: .colour(Ink.line), width: 2.8)
        svg.line([butt + u * 0.6, tip - u * min(6.2, head * 0.7)], stroke: .colour(IronWarriorsInk.wood), width: 1.5)
        let base = tip - u * head
        IronWarriorsKit.shape(&svg, [base + a * 1.2, base + u * (head * 0.44) + a * 2.2, tip, base + u * (head * 0.44) - a * 2.2, base - a * 1.2],
                              fill: .colour(IronWarriorsInk.ironLight), width: 1)
        svg.line([butt, butt - u * 2.2], stroke: .colour(IronWarriorsInk.ironDark), width: 2.2)
    }

    /// The horse seen end on, in its own units: its legs where the side view
    /// moves them, its barrel round, the saddle-cloth down both flanks.
    struct EndOn {
        let horse: BronzePeopleSteed
        static let fore = 4.6, hind = 5.0
        static let coat = "#8e5634", shade = "#5f3820"

        /// How far the head is lowered by the neck's turn.
        var drop: Double { 2.4 + 0.38 * horse.pose.neck }

        /// A point of the horse seen end on: x across, y as in the side view, raised with the body.
        func at(_ x: Double, _ y: Double) -> P { P(x, y - horse.pose.lift + horse.bob) + P(horse.origin.x, horse.origin.y) }

        func leg(_ svg: inout SVG, _ kind: BronzePeopleSteed.Leg, right: Bool, front: Bool) {
            let (top, joint, hoof) = BronzePeopleSteed.leg(horse, kind, far: !right, bob: horse.bob)
            let lift = right ? 0 : BronzePeopleSteed.farOffset.y
            let x = horse.origin.x + (right == front ? -1 : 1) * (kind == .fore ? Self.fore : Self.hind)
            let colour = right == front ? Self.coat : Self.shade
            let t = P(x, top.y - lift), j = P(x + (right == front ? -0.4 : 0.4), joint.y - lift), h = P(x, hoof.y - lift)
            let fetlock = h - P(0, 2.4)
            svg.line([t, j], stroke: .colour(Ink.line), width: 5)
            svg.line([j, fetlock], stroke: .colour(Ink.line), width: 3.5)
            svg.line([t, j], stroke: .colour(colour), width: 3.2)
            svg.line([j, fetlock], stroke: .colour(colour), width: 1.9)
            svg.circle(j, 1.4, fill: .colour(colour))
            svg.polygon([fetlock + P(-1.6, 0), fetlock + P(1.6, 0), h + P(2, 0.5), h + P(-2, 0.5)], fill: .colour(Ink.line))
        }

        /// The far legs, the barrel, the saddle-cloth and saddle; from behind, the neck and head beyond first.
        func body(_ svg: inout SVG, front: Bool) {
            let line = Paint.colour(Ink.line)
            let far: BronzePeopleSteed.Leg = front ? .hind : .fore
            leg(&svg, far, right: true, front: front); leg(&svg, far, right: false, front: front)
            if !front { head(&svg, front: false) }
            let middle = at(0, -37.2)
            svg.ellipse(middle + P(-0.7, 0.7), Self.halfWidthShown, 11, fill: .colour(Self.coat))
            svg.ellipse(middle + P(0, 7.4), 6.4, 2.6, fill: .colour(Self.shade), opacity: 0.6)
            svg.ellipse(middle, Self.halfWidthShown, 11, fill: .none, stroke: line, width: 1.6)
            // The saddle-cloth over the back and down both flanks, bordered in the light and fringed.
            var cloth = PathData()
            cloth.move(at(-12.8, -32.4)); cloth.line(at(-12.8, -40))
            cloth.cubic(at(-12.8, -46.6), at(-7, -49.4), at(0, -49.4))
            cloth.cubic(at(7, -49.4), at(12.8, -46.6), at(12.8, -40))
            cloth.line(at(12.8, -32.4)); cloth.line(at(9.4, -32.4)); cloth.line(at(9.4, -40))
            cloth.cubic(at(9.4, -44), at(5, -46.2), at(0, -46.2))
            cloth.cubic(at(-5, -46.2), at(-9.4, -44), at(-9.4, -40))
            cloth.line(at(-9.4, -32.4)); cloth.close()
            svg.path(cloth, fill: .team)
            for x in [-11.1, 11.1] { svg.line([at(x, -45.4), at(x, -34.6)], stroke: .colour(IronWarriorsInk.light), width: 1) }
            svg.path(cloth, stroke: line, width: 1.3)
            var fringe = PathData()
            for x in [-12.2, -10.2, 10.2, 12.2] { fringe.move(at(x, -32.4)); fringe.line(at(x, -30.2)) }
            svg.path(fringe, stroke: line, width: 0.9)
            // The saddle on top, its horn standing before or behind the seat.
            IronWarriorsKit.shape(&svg, [at(-6.4, -47.4), at(-5.6, -50.2), at(-2, -51), at(-1.4, -53.6), at(1.4, -53.6), at(2, -51),
                                         at(5.6, -50.2), at(6.4, -47.4)], fill: .colour(IronWarriorsInk.leather), width: 1.2)
            let near: BronzePeopleSteed.Leg = front ? .fore : .hind
            leg(&svg, near, right: true, front: front); leg(&svg, near, right: false, front: front)
            if !front { tail(&svg) }
        }

        /// What stands nearest the viewer after the rider: from the front, the neck and the head.
        func ahead(_ svg: inout SVG, front: Bool) {
            if front { head(&svg, front: true) }
        }

        static let halfWidthShown = 12.0

        /// The tail seen from behind, hanging down the middle of the rump.
        func tail(_ svg: inout SVG) {
            let flow = horse.pose.tail
            let root = at(0, -45.6)
            var tail = PathData()
            tail.move(root + P(-2.4, 0))
            tail.cubic(root + P(-4.4, 6), at(-3.6 - flow * 2, -30), at(-2.6 - flow * 3, -20 + flow * 4))
            tail.cubic(at(0, -21 + flow * 4), at(2, -21 + flow * 4), at(2.6 - flow * 3, -20 + flow * 4))
            tail.cubic(at(3.6 - flow * 2, -30), root + P(4.4, 6), root + P(2.4, 0))
            tail.close()
            svg.path(tail, fill: .colour(Ink.line))
        }

        /// The neck and head: from the front the long face, with the plume of
        /// the team's colour fanned behind the ears; from behind, the back of
        /// the head, the mane down the neck and the plume.
        func head(_ svg: inout SVG, front: Bool) {
            let line = Paint.colour(Ink.line)
            func h(_ x: Double, _ y: Double) -> P { at(x, y + drop) }
            let neck = [at(-6, -40), at(6, -40), h(4.4, -62), h(-4.4, -62)]
            svg.polygon(neck.map { $0 + P(-0.7, 0.7) }, fill: .colour(Self.coat))
            svg.polygon(neck, fill: .none, stroke: line, width: 1.5)
            if !front {
                svg.line([h(0, -64), at(0, -44)], stroke: line, width: 3.4)
            }
            // The plume: three feathers fanned from a bronze holder at the poll.
            // From the front they lean away, and show short over the poll.
            let poll = h(0, -69.6)
            let sway = horse.pose.mane * 6
            let length = front ? 3.4 : 5.4
            for angle in [-140.0, 180.0, 140.0] {
                svg.group(at: poll, turned: -(angle + sway)) { svg in
                    svg.ellipse(P(-0.5, length + 1), 2.1, length, fill: .team)
                    svg.ellipse(P(0, length + 0.6), 2.1, length, fill: .none, stroke: line, width: 0.9)
                }
            }
            svg.circle(poll, 1.4, fill: .colour(BronzePeopleInk.bronze), stroke: line, width: 0.7)
            let ear = horse.pose.earBack
            for side in [-1.0, 1.0] {
                let base = h(side * 3.2, -68)
                let tip = ear ? base + P(side * 4.8, -1.8) : base + P(side * 2.2, -5.6)
                svg.polygon([base + P(-side * 1.2, 0.4), tip, base + P(side * 1.6, 0.6)], fill: .colour(Self.coat), stroke: line, width: 1)
            }
            guard front else {
                svg.ellipse(h(0, -64.6) + P(-0.6, 0.6), 5.6, 5.4, fill: .colour(Self.coat))
                svg.ellipse(h(0, -64.6), 5.6, 5.4, fill: .none, stroke: line, width: 1.5)
                return
            }
            func skull(_ o: P) -> PathData {
                var p = PathData()
                p.move(h(-5.2, -66.6) + o)
                p.cubic(h(-6.4, -61.6) + o, h(-5, -56.4) + o, h(-4.2, -53) + o)
                p.cubic(h(-3.6, -50.2) + o, h(3.6, -50.2) + o, h(4.2, -53) + o)
                p.cubic(h(5, -56.4) + o, h(6.4, -61.6) + o, h(5.2, -66.6) + o)
                p.cubic(h(3.4, -69.2) + o, h(-3.4, -69.2) + o, h(-5.2, -66.6) + o)
                p.close()
                return p
            }
            svg.path(skull(P(-0.6, 0.6)), fill: .colour(Self.coat))
            svg.path(skull(P(0, 0)), stroke: line, width: 1.5)
            if horse.pose.mouthOpen { svg.ellipse(h(0, -51), 2, 1.2, fill: line) }
            for x in [-1.8, 1.8] { svg.ellipse(h(x, -53.6), 0.7, 1, fill: line) }
            // The forelock, the bridle's straps and its bronze discs.
            svg.path("M\(num(h(-2.4, -68).x)),\(num(h(0, -68).y)) l1.2,4 l1.2,-2 l1.2,2.6 l1,-4.2 Z", fill: line)
            let strap = "M\(num(h(-5, -65).x)),\(num(h(0, -65).y)) L\(num(h(5, -65).x)),\(num(h(0, -65).y)) "
                + "M\(num(h(-5.4, -63).x)),\(num(h(0, -63).y)) L\(num(h(-4.4, -56.6).x)),\(num(h(0, -56.6).y)) "
                + "L\(num(h(4.4, -56.6).x)),\(num(h(0, -56.6).y)) L\(num(h(5.4, -63).x)),\(num(h(0, -63).y))"
            svg.path(strap, stroke: line, width: 1.1)
            for x in [-4.8, 4.8] { svg.circle(h(x, -58.4), 1.2, fill: .colour(BronzePeopleInk.bronze), stroke: line, width: 0.6) }
            for x in [-5.2, 5.2] {
                let eye = h(x, -62.6)
                if horse.pose.blink {
                    svg.path("M\(num(eye.x - 1.2)),\(num(eye.y)) h2.4", stroke: line, width: 1)
                } else {
                    svg.circle(eye, 1.4, fill: .colour(Ink.eyeWhite), stroke: line, width: 0.7)
                    svg.circle(eye + P(x < 0 ? 0.3 : -0.3, 0.1), 0.7, fill: line)
                }
            }
        }
    }
}
