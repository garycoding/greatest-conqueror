// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The people of the Stone age: the hunter (worker), the elder (scholar), the
// builder (engineer), the clubman, the slinger and the founder. Each has its
// own clothing, headgear or hair, tool or weapon, nose and mark of its own
// (docs/art-style.md), and moves on the shared skeleton. Warfighters wear the
// team's colour on their clothes; the others carry it as a band, an apron, a
// cloak's trim or a banner.

enum StonePeople {
    /// The kinds drawn in the Stone age, with what each looks like.
    static func person(_ kind: UnitKind) -> (any PersonLook)? {
        switch kind {
        case .worker: Hunter()
        case .scholar: Elder()
        case .engineer: Builder()
        case .clubman: Clubman()
        case .slinger: Slinger()
        case .founder: Founder()
        case .merchant, .spearman, .archer, .chariot, .swordsman, .horseman, .catapult, .knight, .musketeer, .cannon, .rifleman, .fieldGun, .armouredCar, .car, .boat: nil
        }
    }

    /// The nose each kind is drawn with (docs/art-style.md, "Noses"): all five
    /// forms, the founder sharing the hunter's.
    static func nose(_ kind: UnitKind) -> Nose? {
        switch kind {
        case .worker: Hunter.nose
        case .scholar: Elder.nose
        case .engineer: Builder.nose
        case .clubman: Clubman.nose
        case .slinger: Slinger.nose
        case .founder: Founder.nose
        case .merchant, .spearman, .archer, .chariot, .swordsman, .horseman, .catapult, .knight, .musketeer, .cannon, .rifleman, .fieldGun, .armouredCar, .car, .boat: nil
        }
    }
}

// MARK: - The hunter (worker)

/// The approved worker: a hide tunic with dark spots and a zigzag hem, the
/// team's band at the waist, swept black hair, a brow; nose A. A stone axe for
/// work (the approved two-handed chop) and for fighting (a one-handed hack).
struct Hunter: PersonLook {
    static let nose = Nose.curve

    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        switch pose {
        case .standing: Moves.standing(frame)
        case .walking: Moves.walking(frame)
        case .working: chop(frame)
        case .fighting: hack(frame)
        default: nil
        }
    }

    /// The approved chop: raised two-handed over the shoulder, struck, recovered.
    func chopAngle(_ frame: Int) -> Double {
        let p = Moves.phase(frame)
        if p < 0.55 { return 70 + (195 - 70) * ease(p / 0.55) }
        if p < 0.72 { return 195 - (195 - 55) * pow((p - 0.55) / 0.17, 2) }
        return 55 + 15 * ease((p - 0.72) / 0.28)
    }

    func chop(_ frame: Int) -> Rig {
        let angle = chopAngle(frame)
        var r = Rig()
        r.backLeg = Limb(-16, 8); r.frontLeg = Limb(18, 8)
        r.frontArm = Limb(angle, -6); r.backArm = Limb(angle - 4, -2)
        r.lean = Moves.phase(frame) < 0.55 ? -5 : 7
        r.mouth = frame >= 7 && frame <= 9 ? .firm : .smile
        return r
    }

    func hack(_ frame: Int) -> Rig {
        let (angle, landing) = Moves.blow(frame, ready: 64, raised: 172, struck: 44)
        var r = Rig()
        // The elbow bent at the ready, straightening as the axe goes up.
        r.frontArm = Limb(angle, mix(14, -10, min(max((angle - 64) / 108, 0), 1)))
        r.backArm = Limb(36 - (angle - 64) * 0.3, 24)
        r.backLeg = Limb(-16, 6)
        r.frontLeg = frame >= 6 && frame <= 9 ? Limb(24, 14) : Limb(14, 8)
        r.lean = frame < 6 ? -3 : (frame <= 9 ? 9 : 3)
        r.mouth = frame >= 6 && frame <= 8 ? .shout : .firm
        r.eyes = landing ? .wide : .open
        return r
    }

    /// The swept black hair, seen from each side.
    static func hair(_ view: SpriteView) -> String {
        switch view {
        case .side: "M-9,-60 C-10,-72 5,-73 9,-65 C3,-68 -2,-64 -4,-58 C-6,-56 -8,-57 -9,-60 Z"
        case .front: "M-10.4,-59 C-12,-72 11,-73 10.4,-60 C7,-66 2,-66.5 -1,-64 C-4,-66 -8,-64 -10.4,-59 Z"
        case .frontQuarter: "M-10.5,-56 C-12,-72 8,-74 10.2,-63 C5,-67.5 0,-66 -3,-63 C-6,-63 -8.5,-61 -10.5,-56 Z"
        case .back: "M-10.8,-54 C-13,-74 13,-74 10.8,-54 C8,-57.5 4,-58.5 0,-58 C-4,-58.5 -8,-57.5 -10.8,-54 Z"
        case .backQuarter: "M-10.8,-53 C-13,-74 11,-75 10.6,-59 C8,-60 4.5,-59.5 2,-57.5 C-2,-58.5 -7,-56 -10.8,-53 Z"
        }
    }

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        d.figure { d in
            // The far arm in profile; in another view, whichever arm is behind the body.
            d.arm(front: false)
            d.legs()
            d.garment(colour: [P(-12, -46), P(8, -48), P(14, -14), P(-16, -13)],
                      outline: [P(-8, -47), P(8, -47), P(13, -16), P(-14, -16)], fill: .colour(Ink.hide)) { d in
                for (c, rx, ry) in [(P(-6, -36), 2.4, 1.7), (P(4, -28), 2.4, 1.7), (P(-4, -21), 2.0, 1.5), (P(7, -40), 2.0, 1.5)] {
                    d.svg.ellipse(d.up(c), rx, ry, fill: .colour(Ink.darkHide))
                }
                d.band([P(-11, -33), P(12, -34), P(12, -29), P(-12, -28)])
            }
            if d.view == .side {
                d.svg.path("M-14,-16 l3,4 l3,-4 l3,4 l3,-4 l3,4 l3,-4 l3,4 l3,-4", stroke: .colour(Ink.line), width: 1.3)
            } else {
                d.zigzag(from: P(-14.5, -16), to: P(14.5, -16), teeth: 5, depth: 4)
            }
            // The axe: seen from another side, it swings in the figure's own plane.
            switch pose {
            case .working:
                d.axe(at: d.hand(front: true), degrees: d.onScreen(chopAngle(frame) + 4))
                if (frame == 9 || frame == 10) && d.view == .side { d.chips(at: P(33, -34)) }
            case .fighting:
                // The axe in line with the forearm, its blade leading.
                d.axe(at: d.hand(front: true), degrees: d.onScreen(d.rig.frontArm.upper + d.rig.frontArm.bend + 8))
                if frame == 7 && d.view == .side { d.swish(around: d.joints.frontShoulder, radius: 27, from: 150, to: 70) }
            default:
                break
            }
            d.arm(front: true)
            d.head(nose: Hunter.nose, hair: { d in
                d.svg.path(Hunter.hair(d.view), fill: .colour(Ink.line))
            }, brow: { d in
                d.svg.path("M1,-64.5 q4,-2 7,0", stroke: .colour(Ink.line), width: 1.4)
            })
        }
    }
}

// MARK: - The elder (scholar)

/// An old man in a long moss robe patterned with waves, the team's colour as a
/// sash; bald, with white hair at the back, a long white beard and a bushy
/// white brow; nose F. He walks with a stick; at work he hangs it from his
/// other hand, reads a stone tablet, and looks up as a thought arrives.
struct Elder: PersonLook {
    static let nose = Nose.bulb

    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        switch pose {
        case .standing:
            var r = Moves.standing(frame)
            r.lean = 4; r.headTilt = 2; r.mouth = .firm
            r.frontArm = Limb(22 + r.lift, 30)
            return r
        case .walking:
            var r = Moves.walking(frame, stride: 15, kneeLift: 30, armSwing: 12)
            r.lean = 6; r.headTilt = 2; r.mouth = .firm
            r.frontArm = Limb(22 + 8 * sin(Moves.phase(frame) * 2 * .pi), 30)
            return r
        case .working:
            var r = Moves.standing(frame)
            r.lean = 3; r.mouth = .firm
            r.backArm = Limb(-40, 10)
            r.frontArm = Limb(78, 44)
            if frame < 7 {
                // Reading: the head bowed over the tablet, nodding along, murmuring.
                r.headTilt = frame % 3 == 1 ? 9 : 7
                r.eyes = .down
                r.mouth = frame % 2 == 0 ? .murmur : .firm
            } else {
                // The thought arrives: the head comes up, the eye widens, the mouth opens.
                r.headTilt = -3
                r.eyes = frame == 11 ? .open : .wide
                r.mouth = frame == 11 ? .firm : .open
                r.frontArm = Limb(72, 40)
            }
            return r
        default:
            return nil
        }
    }

    /// A walking stick through `hand`, reaching the ground.
    func stick(_ d: inout Drawing, at hand: P, degrees: Double) {
        let below = max(0, -d.bob - hand.y) / cos(degrees * .pi / 180) + 0.6
        d.staff(at: hand, degrees: degrees, above: 2.4, below: below)
    }

    /// The white hair at the back of a bald head, seen from each side.
    static func hair(_ view: SpriteView) -> [String] {
        switch view {
        case .side:
            ["M-10.8,-61.6 C-12.6,-56.4 -10.6,-50.8 -6.4,-48.6 C-6.2,-52.6 -7.4,-56.6 -5.4,-60.6 C-7.6,-60 -9.6,-60.4 -10.8,-61.6 Z"]
        case .front:
            ["M-10.6,-61.8 C-12.6,-57 -11.4,-52 -8.4,-50.4 C-8.8,-53.6 -9.2,-57 -7.8,-60.4 C-8.8,-60.6 -9.8,-61 -10.6,-61.8 Z",
             "M10.6,-61.8 C12.6,-57 11.4,-52 8.4,-50.4 C8.8,-53.6 9.2,-57 7.8,-60.4 C8.8,-60.6 9.8,-61 10.6,-61.8 Z"]
        case .frontQuarter:
            ["M-10.8,-61.6 C-12.6,-56.4 -10.6,-50.8 -6.4,-48.6 C-6.2,-52.6 -7.4,-56.6 -5.4,-60.6 C-7.6,-60 -9.6,-60.4 -10.8,-61.6 Z",
             "M10.4,-61.4 C11.6,-58 11,-55 9.8,-53.4 C9.6,-56 9.2,-58.4 9.4,-60.8 Z"]
        case .back:
            ["M-11,-57.4 Q0,-61.6 11,-57.4 C11.6,-53 8,-48.6 0,-48.2 C-8,-48.6 -11.6,-53 -11,-57.4 Z"]
        case .backQuarter:
            ["M-7.4,-56.6 Q2,-61.6 11.2,-58.4 C11.8,-53 8,-48.6 1.6,-48.2 C-3.4,-48.4 -6.6,-51 -7.4,-56.6 Z"]
        }
    }

    /// The long white beard and moustache, seen from each side but the back:
    /// the beard, its strands, and the moustache.
    static func beard(_ view: SpriteView) -> (beard: String, strands: String, moustache: String)? {
        switch view {
        case .side:
            ("M-2.8,-52.6 C0.8,-49.4 6.6,-48.8 10.8,-52.4 C11.6,-46 8.8,-39.6 3.4,-35.6 C2.8,-40.4 0,-44.4 -2.8,-46.8 Z",
             "M-0.6,-45.8 q2.4,2.6 3.4,6.2 M3.8,-48.2 q2,3 2,6.4",
             "M5.2,-53.8 q2.8,-1.8 6,-0.4 q-1.4,1.8 -3,1.2 q-1.6,0.8 -3,-0.8 Z")
        case .front:
            ("M-7.8,-53.6 C-7.8,-46 -3.2,-40 0,-35.6 C3.2,-40 7.8,-46 7.8,-53.6 C4.6,-50 -4.6,-50 -7.8,-53.6 Z",
             "M-2.6,-47 q0.4,3.4 1.6,6.4 M2.6,-47 q-0.4,3.4 -1.6,6.4",
             "M-5.6,-53 q2.8,-2.2 5.6,-0.8 q2.8,-1.4 5.6,0.8 q-1.6,1.8 -3.2,1 q-1.2,0.8 -2.4,0 q-1.2,0.8 -2.4,0 q-1.6,0.8 -3.2,-1 Z")
        case .frontQuarter:
            ("M-2.6,-53.4 C-2.4,-46 1.8,-40 4.8,-35.6 C8,-40 11.8,-46 11,-53.6 C8,-50 0,-49.8 -2.6,-53.4 Z",
             "M2.6,-47 q0.4,3.4 1.6,6.4 M7.4,-47.4 q-0.4,3.4 -1.6,6.4",
             "M1.2,-53 q2.2,-2 4.4,-0.8 q3,-1.4 6,0.8 q-1.6,1.8 -3.4,1 q-1.2,0.8 -2.6,0 q-1,0.8 -2,0 q-1.4,0.8 -2.4,-1 Z")
        case .backQuarter:
            ("M-10.4,-52.8 C-11.8,-47 -10.2,-41 -7.6,-37.2 C-7.4,-42 -6.6,-46.4 -5,-49.6 C-7.2,-50 -9,-51.2 -10.4,-52.8 Z", "", "")
        case .back:
            nil
        }
    }

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let sway = d.rig.sway
        d.figure { d in
            // The stick in the hand that is not holding the tablet, at work; in
            // another view, drawn before the body where that hand is behind it.
            let atWork = pose == .working
            let stickHand = !atWork
            let stickBehind = d.view == .side ? atWork : d.heldBehind(front: stickHand)
            func drawStick(_ d: inout Drawing) {
                if atWork {
                    stick(&d, at: d.hand(front: false), degrees: d.inView(2))
                } else {
                    // Otherwise he leans on it, planted a little ahead of his feet.
                    stick(&d, at: d.hand(front: true), degrees: d.inView(-4))
                }
            }
            // At work, the stick hangs from the hand behind him.
            if stickBehind && d.view == .side { drawStick(&d) }
            d.arm(front: false)
            if stickBehind && d.view != .side { drawStick(&d) }
            // The tablet, read from behind, is hidden by him where his hand is.
            let tabletBehind = atWork && d.heldBehind(front: true)
            if tabletBehind { tablet(&d) }
            d.legs()
            let hemBack = P(-16 - sway * 1.5, -4), hemFront = P(15 - sway * 1.5, -4)
            let outline = [P(-8, -47), P(8, -47), hemFront, hemBack]
            d.garment(colour: [P(-11.5, -46), P(8, -48), hemFront + P(1.5, 1.5), hemBack + P(-2, 2)],
                      outline: outline, fill: .colour(Ink.moss)) { d in
                // Waves across the robe.
                for y in [-37.0, -27.0, -17.0, -9.0] {
                    let share = (y + 47) / 43
                    let left = -8 + (hemBack.x + 8) * share + 2.2, right = 8 + (hemFront.x - 8) * share - 2.2
                    var path = PathData()
                    path.move(d.up(P(left, y)))
                    var x = left
                    var crest = true
                    while x + 3 <= right {
                        path.quad(d.up(P(x + 1.5, y + (crest ? -1.6 : 1.6))), d.up(P(x + 3, y)))
                        x += 3; crest.toggle()
                    }
                    d.svg.path(path, stroke: .colour(Ink.light), width: 1.1)
                }
                // The sash, from the back shoulder to the front hip; seen from
                // another side, from the left shoulder across to the right hip.
                if d.view == .side {
                    d.band([P(-9.5, -44), P(-4.5, -47.5), P(11.4, -26.5), P(11.8, -21)])
                } else {
                    d.strap(shoulder: P(-5, -46.6), hip: P(9.4, -23), width: 5, fill: .team)
                }
            }
            if d.view == .side {
                d.svg.path("M\(num(hemBack.x)),-4 L\(num(hemFront.x)),-4", stroke: .colour(Ink.line), width: 1.8)
            } else {
                let (left, right) = d.hem(of: outline)
                d.svg.line([left, right], stroke: .colour(Ink.line), width: 1.8)
            }
            // Seen from the front, the tablet is held up before his face, and drawn after it.
            let tabletBefore = atWork && d.seesFront
            if atWork {
                if !tabletBehind && !tabletBefore { tablet(&d) }
                if frame >= 8 && frame <= 10 { d.insight() }
            }
            if !stickBehind { drawStick(&d) }
            d.arm(front: true)
            d.head(nose: Elder.nose, hair: { d in
                // White hair at the back of a bald head.
                for tuft in Elder.hair(d.view) {
                    d.svg.path(tuft, fill: .colour(Ink.light), stroke: .colour(Ink.line), width: 1)
                }
                switch d.view {
                case .side: d.svg.path("M-4,-65.8 q3.4,-1.8 6.6,-0.8", stroke: .colour(Ink.light), width: 1.2)
                case .front, .back: d.svg.path("M-3.4,-66.8 q3.4,-1.6 6.8,0", stroke: .colour(Ink.light), width: 1.2)
                case .frontQuarter: d.svg.path("M-1.6,-66.6 q3.4,-1.8 6.6,-0.6", stroke: .colour(Ink.light), width: 1.2)
                case .backQuarter: d.svg.path("M-5,-66.6 q3.2,-0.8 6.6,0.6", stroke: .colour(Ink.light), width: 1.2)
                }
            }, features: { d in
                // A long white beard and moustache.
                guard let beard = Elder.beard(d.view) else { return }
                d.svg.path(beard.beard, fill: .colour(Ink.light), stroke: .colour(Ink.line), width: 1.2)
                if !beard.strands.isEmpty {
                    d.svg.path(beard.strands, stroke: .colour(Ink.line), width: 0.8, opacity: 0.6)
                }
                if !beard.moustache.isEmpty {
                    d.svg.path(beard.moustache, fill: .colour(Ink.light), stroke: .colour(Ink.line), width: 1)
                }
            }, brow: { d in
                d.svg.path("M0.2,-64 q4.4,-3.8 9,-1.2 q-4.4,-0.2 -9,1.2 Z", fill: .colour(Ink.light), stroke: .colour(Ink.line), width: 1.1)
            })
            if tabletBefore {
                tablet(&d)
                d.hand(d.hand(front: true))
            }
        }
    }

    /// The tablet he reads at work: from the front, its blank back; from
    /// behind, its marks.
    func tablet(_ d: inout Drawing) {
        if d.view == .side {
            d.tablet(at: d.joints.frontHand + P(-0.6, -1.6), degrees: -14)
        } else {
            d.tablet(at: d.hand(front: true) + P(-0.6, -1.6), degrees: -14 * cos(d.yaw * .pi / 180), marked: !d.seesFront)
        }
    }
}

// MARK: - The builder (engineer)

/// A stocky builder in a light tunic striped like woven cloth, a leather cap
/// with a short brim, a bushy moustache; nose B. The team's colour is his
/// apron. A stone mallet: at work he drives a stake; fighting, he swings it.
struct Builder: PersonLook {
    static let nose = Nose.button

    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        switch pose {
        case .standing:
            return Moves.standing(frame)
        case .walking:
            return Moves.walking(frame)
        case .working:
            return work(frame)
        case .fighting:
            let (angle, landing) = Moves.blow(frame, ready: 80, raised: 185, struck: 70)
            var r = Rig()
            r.frontArm = Limb(angle, -6)
            r.backArm = Limb(-30 + (angle - 80) * 0.25, -10)
            r.backLeg = Limb(-18, 6)
            r.frontLeg = frame >= 6 && frame <= 9 ? Limb(22, 12) : Limb(12, 8)
            r.lean = frame < 6 ? -4 : (frame <= 9 ? 10 : 2)
            r.mouth = landing ? .shout : .firm
            r.eyes = landing ? .wide : .open
            return r
        default:
            return nil
        }
    }

    /// Driving a post: the mallet raised over seven frames, brought down onto
    /// the post's top, and rebounding.
    static func workBlow(_ frame: Int) -> (angle: Double, landing: Bool) {
        Moves.blow(frame, ready: 66, raised: 165, struck: 58, raiseFrames: 7)
    }

    func work(_ frame: Int) -> Rig {
        let (angle, landing) = Builder.workBlow(frame)
        var r = Rig()
        r.backLeg = Limb(-12, 6); r.frontLeg = Limb(16, 14)
        r.lean = 10
        r.frontArm = Limb(angle, -4)
        r.backArm = Limb(24, 30)
        r.mouth = .firm
        r.eyes = landing ? .closed : .down
        return r
    }

    /// The mallet's angle at work: the handle a little ahead of the arm.
    static func workMallet(_ rig: Rig) -> Double { rig.frontArm.upper + 18 }

    /// The top of the post he drives: where the mallet's face lands, in the
    /// picture's space, so that the blow always meets it.
    static let postTop: P = {
        let frame = (0..<12).first { workBlow($0).landing } ?? 9
        let rig = Builder().work(frame)
        let d = Drawing(layer: .base, rig: rig, phase: 0)
        let u = P.direction(workMallet(rig)), across = P(-u.y, u.x)
        return d.world(d.joints.frontHand + u * 11.5 + across * 3.6)
    }()

    /// The top of the post seen from each side: where the mallet's face lands
    /// in that view, in the picture's space.
    static let postTops: [SpriteView: P] = Dictionary(uniqueKeysWithValues: SpriteView.allCases.map { view in
        if view == .side { return (view, postTop) }
        let frame = (0..<12).first { workBlow($0).landing } ?? 9
        let rig = Builder().work(frame)
        let d = Drawing(layer: .base, rig: rig, phase: 0, view: view)
        let u = P.direction(d.onScreen(workMallet(rig))), across = P(-u.y, u.x)
        let face = d.hand(front: true) + u * 11.5 + across * 3.6
        return (view, face.rotated(rig.lean * cos(view.yaw * .pi / 180), about: Drawing.hips) + P(0, d.bob))
    })

    /// The post he drives, its top at `top`, standing on the ground.
    func post(_ d: inout Drawing, top: P) {
        d.svg.ellipse(P(top.x, 0), 4.5, 1.3, fill: .colour("#000000"), opacity: 0.13)
        d.svg.polygon([P(top.x - 3.1, top.y + 0.8), P(top.x + 1.7, top.y + 0.6), P(top.x + 1.9, 0.8), P(top.x - 3.3, 1)],
                      fill: .colour(Ink.wood))
        d.svg.polygon([P(top.x - 2.4, top.y), P(top.x + 2.4, top.y), P(top.x + 2.6, 0), P(top.x - 2.6, 0)], fill: .none,
                      stroke: .colour(Ink.line), width: 1.3)
        d.svg.ellipse(top, 2.4, 0.9, fill: .colour(Ink.hide), stroke: .colour(Ink.line), width: 1)
        d.svg.path("M\(num(top.x - 0.8)),\(num(top.y * 0.7)) v4 M\(num(top.x + 1)),\(num(top.y * 0.35)) v3",
                   stroke: .colour(Ink.line), width: 0.9)
    }

    /// The dark hair below the cap, seen from each side.
    static func hair(_ view: SpriteView) -> String {
        switch view {
        case .side, .frontQuarter: "M-9.8,-60 C-10.6,-63 -9.6,-55 -7.6,-52.8 C-7,-55.4 -6.6,-57.8 -5.2,-59.6 Z"
        case .front: "M-10.6,-61 C-11.4,-58 -10.6,-55 -9.2,-53.4 C-9,-56 -8.6,-58.4 -7.6,-60.2 Z "
            + "M10.6,-61 C11.4,-58 10.6,-55 9.2,-53.4 C9,-56 8.6,-58.4 7.6,-60.2 Z"
        case .back: "M-11,-57 C-11.6,-54.6 -10.8,-52.4 -9.4,-51.2 C-9.2,-53.4 -8.8,-55.2 -8,-56.6 Z "
            + "M11,-57 C11.6,-54.6 10.8,-52.4 9.4,-51.2 C9.2,-53.4 8.8,-55.2 8,-56.6 Z"
        case .backQuarter: "M11,-57.4 C11.6,-55 10.8,-52.6 9.4,-51.4 C9.2,-53.6 8.8,-55.4 8,-57 Z"
        }
    }

    /// The bushy moustache, where the view shows it.
    static func moustache(_ view: SpriteView) -> String? {
        switch view {
        case .side: "M4.4,-54 q3.4,-2.6 7.2,-0.6 q-1,2.4 -3.6,1.4 q-2,1.4 -3.6,-0.8 Z"
        case .front: "M-5.8,-53.2 q2.8,-2.4 5.8,-0.8 q3,-1.6 5.8,0.8 q-1,2.4 -3.4,1.4 q-1.2,1 -2.4,0 q-1.2,1 -2.4,0 q-2.4,1 -3.4,-1.4 Z"
        case .frontQuarter: "M0.6,-53.2 q2.4,-2.2 4.8,-0.8 q3.2,-1.6 6.2,0.8 q-1,2.4 -3.6,1.4 q-1.2,1 -2.4,0 q-1,1 -2.2,0 q-2,1 -2.8,-1.4 Z"
        case .backQuarter: "M-10.4,-54.2 q-1.8,1 -0.8,2.8 q1.6,0.2 2.4,-1.2 Z"
        case .back: nil
        }
    }

    /// The leather cap: its colour, its outline, and the seam over the crown.
    static func cap(_ view: SpriteView) -> (colour: String, outline: String, seam: String) {
        switch view {
        case .side:
            ("M-11.2,-58.6 C-12.6,-71 2.6,-73.8 9.4,-65.6 L14.2,-64.8 L13.6,-63 L-11.2,-58.6 Z",
             "M-10.6,-59.4 C-11.4,-70.6 3,-72.8 9.6,-65.2 L14.4,-64.4 L13.8,-62.6 L-10.6,-59.4 Z",
             "M-1.6,-71.2 q1.6,4.4 1.8,9.4")
        case .front:
            // The brim dips toward the viewer over the brow.
            ("M-11.6,-61.4 C-13,-73.6 13,-73.6 11.6,-61.4 Q11.2,-59.6 9.4,-59.8 Q0,-58.4 -9.4,-59.8 Q-11.2,-59.6 -11.6,-61.4 Z",
             "M-11,-62 C-12.4,-73.4 12.4,-73.4 11,-62 Q10.8,-60.2 9,-60.4 Q0,-59 -9,-60.4 Q-10.8,-60.2 -11,-62 Z "
                + "M-10.2,-62.6 Q0,-64.6 10.2,-62.6",
             "M0,-71.4 v8")
        case .frontQuarter:
            ("M-11.6,-59.4 C-13,-72.8 9.4,-75.2 11.8,-63.4 Q14.6,-62.6 13.8,-61 Q6,-58.4 -1.6,-60.2 Q-7,-59 -11.6,-59.4 Z",
             "M-11,-60 C-12.4,-72.4 9.4,-74.6 11.4,-63.6 Q14,-62.8 13.2,-61.4 Q6,-59 -1.2,-60.8 Q-7,-59.6 -11,-60 Z "
                + "M-1.2,-60.8 Q5,-63.8 11.4,-63.6",
             "M1.4,-71.6 q-0.6,4.6 -0.2,8.8")
        case .back:
            ("M-11.8,-56.4 C-13.2,-73.6 13.2,-73.6 11.8,-56.4 Q0,-54.4 -11.8,-56.4 Z",
             "M-11.2,-57 C-12.6,-73.4 12.6,-73.4 11.2,-57 Q0,-55 -11.2,-57 Z",
             "M0,-71.4 v15.4")
        case .backQuarter:
            ("M-12.6,-62.4 L-9.8,-63.6 C-10.6,-74 13.4,-74.6 12,-56.6 Q4,-55.4 -6.4,-58.6 Q-10.6,-60 -12.6,-62.4 Z",
             "M-12,-62.8 L-9.4,-64 C-10,-73.6 12.8,-74 11.4,-57.2 Q4,-56 -6,-59.2 Q-10.2,-60.6 -12,-62.8 Z",
             "M-0.6,-71.8 q1.4,6 1.4,15.6")
        }
    }

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        // The post stands upright on the ground, outside the leaning body: in
        // profile and from behind, beyond him; from the front, before him.
        let postTop = Builder.postTops[d.view]!
        let postBefore = pose == .working && d.seesFront
        if pose == .working && !postBefore { post(&d, top: postTop + P(0, 0.4)) }
        d.figure { d in
            let hand = d.hand(front: true)
            let held = d.heldBehind(front: true)
            func mallet(_ d: inout Drawing) {
                switch pose {
                case .working:
                    d.mallet(at: hand, degrees: d.inView(Builder.workMallet(d.rig)))
                case .fighting:
                    d.mallet(at: hand, degrees: d.inView(d.rig.frontArm.upper + 10))
                    if frame == 7 && d.view == .side { d.swish(around: d.joints.frontShoulder, radius: 25, from: 160, to: 90) }
                default:
                    d.mallet(at: hand, degrees: d.inView(d.rig.frontArm.upper + d.rig.frontArm.bend + 14))
                }
            }
            d.arm(front: false)
            if held { mallet(&d) }
            d.legs()
            // The apron is on his front: from behind, only its ties show.
            let apron = d.view == .side || d.seesFront
            d.garment(colour: [P(-13, -46), P(9, -48), P(15, -14), P(-17, -13)],
                      outline: [P(-9, -47), P(9, -47), P(14, -16), P(-15, -16)], fill: .colour(Ink.light)) { d in
                // Woven stripes.
                if d.view == .side {
                    for x in [-9.0, -4.0, 1.0, 6.0] {
                        d.svg.line([d.up(P(x + 0.4, -44)), P(x * 1.35, -17)], stroke: .colour(Ink.hide), width: 1.6)
                    }
                } else {
                    for x in [-7.5, -2.5, 2.5, 7.5] {
                        d.svg.line([d.up(P(x, -44)), P(x * 1.35, -17)], stroke: .colour(Ink.hide), width: 1.6)
                    }
                }
                // The apron, in the team's colour, from a belt at the waist.
                if apron { d.band([P(1.5, -33), P(13.5, -34), P(16, -11.5), P(3.5, -11)]) }
            }
            if d.view == .side {
                d.svg.polygon([P(2.6, -33.6), P(12.4, -33.6), P(14.6, -12.4), P(4.2, -12.4)], fill: .none,
                              stroke: .colour(Ink.line), width: 1.3)
                d.svg.line([d.up(P(-10.4, -33.4)), d.up(P(12.6, -34.4))], stroke: .colour(Ink.line), width: 2)
                // A fringe at the hem.
                d.svg.path("M-13,-16 v2.6 M-10,-16 v2.6 M-7,-16 v2.6 M-4,-16 v2.6 M-1,-16 v2.6", stroke: .colour(Ink.line), width: 1.1)
            } else {
                // The fringe all round the hem, but where the apron hangs over it.
                let over = apron ? d.turned([P(2.6, -33.6), P(12.4, -33.6), P(14.6, -12.4), P(4.2, -12.4)]) : []
                let (low, high) = (over.map(\.x).min() ?? 0, over.map(\.x).max() ?? 0)
                var fringe = PathData()
                for x in stride(from: -12.0, through: 12.0, by: 3) where !apron || x < low - 0.6 || x > high + 0.6 {
                    fringe.move(P(x, -16)); fringe.line(P(x, -13.4))
                }
                d.svg.path(fringe, stroke: .colour(Ink.line), width: 1.1)
                if apron {
                    d.svg.polygon(over, fill: .none, stroke: .colour(Ink.line), width: 1.3)
                } else {
                    // The apron's ties, knotted at the small of his back.
                    let knot = d.up(P(d.view == .back ? 0 : -3.6, -33.2))
                    d.band([P(-10.6, -34.6), P(10.6, -34.6), P(10.6, -32.2), P(-10.6, -32.2)])
                    d.svg.polygon([knot + P(-0.6, 0.4), knot + P(-2.6, 7), knot + P(-0.4, 6.6)], fill: .team,
                                  stroke: .colour(Ink.line), width: 0.9)
                    d.svg.polygon([knot + P(0.6, 0.4), knot + P(3, 6.4), knot + P(1, 7)], fill: .team,
                                  stroke: .colour(Ink.line), width: 0.9)
                    d.svg.ellipse(knot, 1.6, 1.3, fill: .team, stroke: .colour(Ink.line), width: 0.9)
                }
                let belt = d.up(P(0, -33.9))
                d.svg.line([belt + P(-10.6, 0), belt + P(10.6, 0)], stroke: .colour(Ink.line), width: 1.1)
                d.svg.line([belt + P(-10.6, 1.6), belt + P(10.6, 1.6)], stroke: .colour(Ink.line), width: 1.1)
            }
            if !held { mallet(&d) }
            d.arm(front: true, width: 2.1)
            d.head(nose: Builder.nose, hair: { d in
                d.svg.path(Builder.hair(d.view), fill: .colour(Ink.line))
            }, features: { d in
                // A bushy moustache.
                if let moustache = Builder.moustache(d.view) { d.svg.path(moustache, fill: .colour(Ink.line)) }
            }, brow: { d in
                d.svg.path("M1.6,-64 q3.4,-1.4 6.4,-0.2", stroke: .colour(Ink.line), width: 1.5)
            }, over: { d in
                // A leather cap with a short brim.
                let cap = Builder.cap(d.view)
                d.svg.path(cap.colour, fill: .colour(Ink.hide))
                d.svg.path(cap.outline, stroke: .colour(Ink.line), width: 1.5)
                d.svg.path(cap.seam, stroke: .colour(Ink.darkHide), width: 1)
            })
        }
        if postBefore { post(&d, top: postTop + P(0, 0.4)) }
        // The blow landing on the post, over the mallet's head.
        if pose == .working && Builder.workBlow(frame).landing {
            d.burst(at: postTop + P(0, -1.4), from: 96, to: 264, size: 1.2)
        }
    }
}

// MARK: - The clubman

/// A bare-chested warrior in a kilt of the team's colour with a zigzag hem, a
/// hide strap across his chest, wild spiky hair, a heavy brow and a scar on
/// the cheek; nose C. A heavy wooden club, held upright at the ready and
/// brought down two-handed.
struct Clubman: PersonLook {
    static let nose = Nose.hook

    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        switch pose {
        case .standing, .working:
            var r = Moves.standing(frame)
            r.backLeg = Limb(-7, 4); r.frontLeg = Limb(8, 4)
            r.frontArm = Limb(38 + r.lift, 44)
            r.mouth = .firm
            return r
        case .walking:
            var r = Moves.walking(frame, stride: 26)
            r.frontArm = Limb(38, 44)
            r.mouth = .firm
            return r
        case .fighting:
            let (angle, landing) = Moves.blow(frame, ready: 120, raised: 210, struck: 62)
            var r = Rig()
            r.frontArm = Limb(angle, -6)
            r.backArm = Limb(angle - 8, 2)
            r.backLeg = Limb(-20, 6)
            r.frontLeg = frame >= 6 && frame <= 9 ? Limb(26, 16) : Limb(14, 8)
            r.lean = frame < 6 ? -6 : (frame <= 9 ? 12 : 2)
            r.mouth = frame >= 6 && frame <= 8 ? .shout : .firm
            r.eyes = landing ? .wide : .open
            return r
        default:
            return nil
        }
    }

    /// The wild spiky hair, seen from each side.
    static func hair(_ view: SpriteView) -> String {
        switch view {
        case .side, .frontQuarter:
            "M-10.2,-59 L-13.8,-63.4 L-9.6,-64.8 L-11.2,-69.8 L-5.8,-67.6 L-4.6,-72.8 L-0.6,-68.6 L2.8,-72.4 "
                + "L4.4,-67.4 L9,-68.8 L7.6,-64.6 C3,-66.8 -2,-64.4 -4.4,-59.6 C-6.4,-57.4 -8.8,-57.6 -10.2,-59 Z"
        case .front:
            "M-10.4,-58.4 L-14,-61.8 L-10.8,-64.4 L-12.6,-69.2 L-7.2,-67.8 L-6,-73.2 L-2.2,-69.2 L0.4,-74 L2.8,-69.2 "
                + "L6.8,-72.8 L7.4,-67.6 L12.6,-69 L10.8,-64.4 L14,-61.8 L10.4,-58.4 C8.4,-63 4.4,-64.8 0,-63.8 "
                + "C-4.4,-64.8 -8.4,-63 -10.4,-58.4 Z"
        case .back:
            "M-10.8,-54 L-14.4,-58 L-11.4,-61 L-13.6,-66 L-8.4,-66.4 L-8,-72 L-3.4,-68.8 L0,-74 L3.4,-68.8 L8,-72 "
                + "L8.4,-66.4 L13.6,-66 L11.4,-61 L14.4,-58 L10.8,-54 C7,-57.6 -7,-57.6 -10.8,-54 Z"
        case .backQuarter:
            "M-10.8,-53 L-13.6,-58 L-11.4,-61 L-13,-66.4 L-8,-66.8 L-7,-72.4 L-2.6,-69.2 L1,-74 L4,-69.4 L8.6,-71.6 "
                + "L8.6,-66.6 L13.4,-66 L10.8,-62 L13,-58.6 L10.6,-56.4 C8,-59.6 4.5,-59.5 2,-57.5 C-2,-58.5 -7,-56 -10.8,-53 Z"
        }
    }

    /// The stitched scar across the near cheek, where the view shows it.
    static func scar(_ view: SpriteView) -> String? {
        switch view {
        case .side: "M0.2,-57.6 l3.8,4.8 M1,-55.4 l1.7,-1.3 M2.3,-53.8 l1.7,-1.3"
        case .front: "M-8.4,-57.8 l3.6,4.6 M-7.7,-55.6 l1.6,-1.3 M-6.5,-54 l1.6,-1.3"
        case .frontQuarter: "M4,-57.8 l3.6,4.6 M4.7,-55.6 l1.6,-1.3 M5.9,-54 l1.6,-1.3"
        case .back, .backQuarter: nil
        }
    }

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        d.figure { d in
            let hand = d.hand(front: true)
            let held = d.heldBehind(front: true)
            func club(_ d: inout Drawing) {
                switch pose {
                case .fighting:
                    let angle = d.rig.frontArm.upper
                    d.club(at: hand, degrees: d.inView(angle - 4), length: 20)
                    if frame == 7 && d.view == .side { d.swish(around: d.joints.frontShoulder, radius: 33, from: 175, to: 80) }
                    if frame == 8 { d.impact(at: hand + P.direction(d.inView(angle - 4)) * 24, size: 1.1) }
                default:
                    // Held upright at rest; seen from another side, leaning a
                    // little outward over the shoulder so that it clears the head.
                    let outward = d.view == .side ? 0 : 14 * abs(sin(d.yaw * .pi / 180)) * (hand.x < 0 ? 1 : -1)
                    d.club(at: hand, degrees: d.inView(176) + outward, length: 20)
                }
            }
            d.arm(front: false, width: 2.4)
            if held { club(&d) }
            d.legs()
            // The bare chest.
            d.garment(colour: [P(-11.4, -46), P(9, -48), P(10.6, -28), P(-10.6, -27.4)],
                      outline: [P(-8.4, -47), P(9, -47), P(9.8, -30), P(-9.6, -30)], fill: .colour(Ink.skin)) { d in
                let y = d.up(P(0, -41)).y
                switch d.view {
                case .side:
                    d.svg.path("M\(num(1.6)),\(num(y)) q3.6,1.8 6.8,-0.2", stroke: .colour(Ink.line), width: 1)
                case .front:
                    d.svg.path("M\(num(-7.2)),\(num(y)) q3,1.6 6,0 M\(num(1.2)),\(num(y)) q3,1.6 6,0", stroke: .colour(Ink.line), width: 1)
                case .frontQuarter:
                    d.svg.path("M\(num(-4)),\(num(y)) q2.6,1.4 5.2,0 M\(num(2.8)),\(num(y)) q3.4,1.8 6.6,-0.2",
                               stroke: .colour(Ink.line), width: 1)
                case .back, .backQuarter:
                    // The shoulder blades.
                    d.svg.path("M\(num(-6.4)),\(num(y - 1.6)) q1.4,3 4,3.4 M\(num(6.4)),\(num(y - 1.6)) q-1.4,3 -4,3.4",
                               stroke: .colour(Ink.line), width: 1)
                }
            }
            // The strap across it.
            if d.view == .side {
                d.band([P(-8.6, -46.4), P(-4.4, -47.2), P(10, -31.6), P(6.4, -30.6)], fill: .colour(Ink.darkHide))
            } else {
                d.strap(shoulder: P(-5.4, -46.8), hip: P(8, -31), width: 4.2, fill: .colour(Ink.darkHide))
            }
            // The kilt, in the team's colour.
            d.garment(colour: [P(-12.6, -31), P(11, -32.4), P(14.6, -14), P(-16.4, -13)],
                      outline: [P(-10.2, -31), P(10.4, -31), P(13, -16), P(-14, -16)], fill: .team) { d in
                d.svg.path("M-8,-26.4 l4,-2 l4,2 l4,-2 l4,2", stroke: .colour(Ink.line), width: 1.1)
            }
            if d.view == .side {
                d.svg.path("M-14,-16 l3,4 l3,-4 l3,4 l3,-4 l3,4 l3,-4 l3,4 l3,-4", stroke: .colour(Ink.line), width: 1.3)
                d.svg.line([d.up(P(-10.4, -31.4)), d.up(P(10.6, -31.6))], stroke: .colour(Ink.darkHide), width: 2.4)
            } else {
                d.zigzag(from: P(-14.5, -16), to: P(14.5, -16), teeth: 5, depth: 4)
                d.svg.line([d.up(P(-10, -31.4)), d.up(P(10, -31.4))], stroke: .colour(Ink.darkHide), width: 2.4)
            }
            if !held { club(&d) }
            d.arm(front: true, width: 2.4)
            d.head(nose: Clubman.nose, hair: { d in
                d.svg.path(Clubman.hair(d.view), fill: .colour(Ink.line))
            }, features: { d in
                // A scar across the cheek, stitched.
                if let scar = Clubman.scar(d.view) { d.svg.path(scar, stroke: .colour(Ink.line), width: 0.9) }
            }, brow: { d in
                d.svg.path("M1.2,-65.6 L9,-63", stroke: .colour(Ink.line), width: 2.3)
            })
        }
    }
}

// MARK: - The slinger

/// A young, light warrior in a short tunic of the team's colour with a light
/// zigzag across it, a hide headband whose tails stream behind, a topknot and
/// freckles; nose E. A sling: it hangs from his hand, and in a fight he whirls
/// it and lets the stone fly.
struct Slinger: PersonLook {
    static let nose = Nose.line

    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        switch pose {
        case .standing, .working:
            var r = Moves.standing(frame)
            r.frontArm = Limb(14 + r.lift * 2, -4)
            return r
        case .walking:
            return Moves.walking(frame)
        case .fighting:
            var r = Rig()
            r.backLeg = Limb(-16, 6)
            if frame < 8 {
                // The whirl: the arm raised forward, the sling going round the hand.
                r.frontArm = Limb(100 + 4 * sin(Double(frame) / 8 * 2 * .pi), 8)
                r.frontLeg = Limb(12, 8)
                r.lean = -3
                r.mouth = .firm
            } else {
                // The release, and the follow-through.
                let t = Double(frame - 8) / 3
                r.frontArm = Limb(mix(96, 46, t), -6)
                r.frontLeg = Limb(22, 12)
                r.lean = mix(9, 4, t)
                r.mouth = frame == 8 ? .shout : .firm
                r.eyes = frame == 8 ? .wide : .open
            }
            r.backArm = Limb(-24, -8)
            return r
        default:
            return nil
        }
    }

    /// The headband seen from each side but the side itself.
    static func headband(_ view: SpriteView) -> String {
        switch view {
        case .side: ""
        case .front: "M-11,-62.6 Q0,-67.4 11,-62.6 L10.8,-65 Q0,-69.8 -10.8,-65 Z"
        case .frontQuarter: "M-11.2,-61.8 Q1,-66.6 10.8,-65.4 L10.6,-67.8 Q1,-69.2 -10.8,-64.4 Z"
        case .back: "M-11,-61.4 Q0,-64.6 11,-61.4 L10.8,-63.8 Q0,-67 -10.8,-63.8 Z"
        case .backQuarter: "M-10.8,-65.4 Q-1,-66.6 11.2,-61.8 L10.8,-64.4 Q-1,-69.2 -10.6,-67.8 Z"
        }
    }

    /// The headband's two tails from the knot at `knot`, streaming toward `x`
    /// (-1 to the screen's left, 1 to its right, 0 hanging), as a dark edge with the hide inside.
    static func tails(_ d: inout Drawing, from knot: P, toward x: Double, flutter: Double) {
        let hang = 1 - abs(x)
        var first = PathData(), second = PathData()
        first.move(knot)
        first.quad(knot + P(4.6 * x - 1.6 * hang, 1 + flutter * 0.4 + 3 * hang), knot + P(8.6 * x - 2.4 * hang, 3.4 + flutter + 5 * hang))
        second.move(knot + P(0.2 * x + 0.6 * hang, 0.8))
        second.quad(knot + P(3 * x + 2 * hang, 3.4 - flutter * 0.3 + 2 * hang),
                    knot + P(6 * x + 3 * hang, 6.8 - flutter * 0.6 + 2.6 * hang))
        for path in [first, second] {
            d.svg.path(path, stroke: .colour(Ink.line), width: 2.8)
            d.svg.path(path, stroke: .colour(Ink.hide), width: 1.4)
        }
    }

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        d.figure { d in
            let at = d.hand(front: true)
            let held = d.heldBehind(front: true)
            // The pouch of stones at the back hip, and the stone in flight: in
            // another view, drawn before the body where they are behind it.
            let pouch = d.project(-10, -21, -4)
            let flight = Double(max(frame - 8, 0))
            let stone = d.project(24 + flight * 9, -50 + flight * 1.5, Drawing.shoulderSpread)
            let stoneBehind = d.view != .side && stone.depth < 0
            // Seen from the front or behind, the sling swings a little out of his
            // plane, so that its whirl still shows.
            let squeeze = max(abs(cos(d.yaw * .pi / 180)), 0.35)
            /// The sling's cord as it shows in this view, along `degrees` in the figure's plane.
            func sling(_ d: inout Drawing, degrees: Double, length: Double, loaded: Bool = true) {
                if d.view == .side { d.sling(at: at, degrees: degrees, length: length, loaded: loaded); return }
                let u = P.direction(degrees), shown = P(u.x * squeeze, u.y)
                let onScreen = atan2(shown.x, shown.y) * 180 / .pi
                d.sling(at: at, degrees: onScreen, length: length * (shown.x * shown.x + shown.y * shown.y).squareRoot(),
                        loaded: loaded)
            }
            func slingAndStone(_ d: inout Drawing) {
                switch pose {
                case .fighting:
                    if frame < 8 {
                        let around = Double(frame) / 8 * 360
                        // Round the hand, in the plane of the picture; seen from another
                        // side, in the figure's own plane, the swish only where it shows.
                        sling(&d, degrees: 180 - around, length: 6)
                        if d.view == .side {
                            d.swish(around: at, radius: 6.8, from: 180 - around + 140, to: 180 - around + 20)
                        } else {
                            d.whirl(around: at, radius: 6.8, from: 180 - around + 140, to: 180 - around + 20, squeeze: squeeze)
                        }
                    } else {
                        sling(&d, degrees: mix(70, 20, Double(frame - 8) / 3), length: 9, loaded: false)
                        if !stoneBehind { d.stone(at: d.view == .side ? P(24 + flight * 9, -50 + flight * 1.5) : stone.point) }
                        if frame == 8 { d.impact(at: d.view == .side ? P(22, -50) : d.project(22, -50, Drawing.shoulderSpread).point, size: 0.6) }
                    }
                case .walking:
                    sling(&d, degrees: d.rig.frontArm.upper * 0.4, length: 9)
                default:
                    sling(&d, degrees: 4 * sin(d.phase * 2 * .pi), length: 9)
                }
            }
            d.arm(front: false)
            if held { slingAndStone(&d) }
            if pose == .fighting && frame >= 8 && stoneBehind { d.stone(at: stone.point) }
            d.legs()
            let pouchBehind = d.view == .side || pouch.depth < 0
            func drawPouch(_ d: inout Drawing) {
                d.svg.ellipse(d.view == .side ? P(-12.4, -21) : pouch.point, 2.6, 3, fill: .colour(Ink.hide),
                              stroke: .colour(Ink.line), width: 1.1)
            }
            // A pouch of stones at the back hip.
            if pouchBehind { drawPouch(&d) }
            d.garment(colour: [P(-11, -46), P(7.5, -48), P(12.6, -16), P(-14.6, -15)],
                      outline: [P(-7.6, -47), P(7.6, -47), P(11.6, -18.4), P(-12.6, -18.4)], fill: .team) { d in
                // A light zigzag across the chest.
                d.svg.path("M\(num(-8.4)),\(num(d.up(P(0, -36)).y)) l3,-2.6 l3,2.6 l3,-2.6 l3,2.6 l3,-2.6", stroke: .colour(Ink.light), width: 1.4)
                d.svg.path("M-11.4,-24.6 l3,-2.2 l3,2.2 l3,-2.2 l3,2.2 l3,-2.2 l3,2.2 l3,-2.2", stroke: .colour(Ink.light), width: 1.2)
            }
            d.svg.line([d.up(P(-10.6, -30)), d.up(P(10.2, -30.6))], stroke: .colour(Ink.darkHide), width: 1.8)
            if !pouchBehind { drawPouch(&d) }
            if !held { slingAndStone(&d) }
            d.arm(front: true, width: 1.8)
            let flutter = 2 * sin(d.phase * 4 * .pi) + (pose == .walking ? 1.5 : 0)
            d.head(nose: Slinger.nose, behind: { d in
                // The headband's tails, streaming behind.
                switch d.view {
                case .side, .frontQuarter:
                    d.svg.path("M-10.6,-60.4 q-4.6,\(num(1 + flutter * 0.4)) -8.6,\(num(3.4 + flutter))", stroke: .colour(Ink.line), width: 2.8)
                    d.svg.path("M-10.6,-60.4 q-4.6,\(num(1 + flutter * 0.4)) -8.6,\(num(3.4 + flutter))", stroke: .colour(Ink.hide), width: 1.4)
                    d.svg.path("M-10.4,-59.6 q-3,\(num(2.6 - flutter * 0.3)) -6,\(num(6 - flutter * 0.6))", stroke: .colour(Ink.line), width: 2.8)
                    d.svg.path("M-10.4,-59.6 q-3,\(num(2.6 - flutter * 0.3)) -6,\(num(6 - flutter * 0.6))", stroke: .colour(Ink.hide), width: 1.4)
                case .front:
                    // Behind the head, showing beside it.
                    Slinger.tails(&d, from: P(-5, -60.4), toward: -1, flutter: flutter)
                case .back, .backQuarter:
                    break
                }
            }, hair: { d in
                if d.view == .side {
                    d.svg.path("M-9.4,-59.6 C-10.4,-70.6 4.4,-72.6 9,-65.4 C3.2,-67.6 -2,-64.4 -4.4,-59 C-6.2,-57 -8.4,-57.6 -9.4,-59.6 Z",
                               fill: .colour(Ink.line))
                } else {
                    d.svg.path(Hunter.hair(d.view), fill: .colour(Ink.line))
                }
                // The topknot.
                let knot: P
                switch d.view {
                case .side: knot = P(-4.2, -70.6)
                case .front, .back: knot = P(0, -71.4)
                case .frontQuarter: knot = P(-3.6, -71.2)
                case .backQuarter: knot = P(2.6, -71.4)
                }
                d.svg.circle(knot, 2.9, fill: .colour(Ink.line))
            }, features: { d in
                let freckles: [P]
                switch d.view {
                case .side: freckles = [P(1.4, -55.6), P(3.2, -54.4), P(4.8, -55.8)]
                case .front: freckles = [P(-7.6, -55.6), P(-5.8, -54.4), P(-4.2, -55.8), P(4.2, -55.8), P(5.8, -54.4), P(7.6, -55.6)]
                case .frontQuarter: freckles = [P(4.2, -55.6), P(6, -54.4), P(7.6, -55.8), P(-4.4, -55.6), P(-3, -54.6)]
                case .back, .backQuarter: freckles = []
                }
                for c in freckles { d.svg.circle(c, 0.5, fill: .colour(Ink.darkHide)) }
            }, brow: { _ in }, over: { d in
                if d.view == .side {
                    // The headband, rising toward the front.
                    d.svg.polygon([P(-11, -62.4), P(9, -67.8), P(9.8, -65.4), P(-10.6, -59.8)].map { $0 + P(-0.5, 0.5) }, fill: .colour(Ink.hide))
                    d.svg.polygon([P(-11, -62.4), P(9, -67.8), P(9.8, -65.4), P(-10.6, -59.8)], fill: .none, stroke: .colour(Ink.line), width: 1.2)
                    return
                }
                let band = Slinger.headband(d.view)
                d.svg.raw("<g transform=\"translate(-0.5,0.5)\">")
                d.svg.path(band, fill: .colour(Ink.hide))
                d.svg.raw("</g>")
                d.svg.path(band, stroke: .colour(Ink.line), width: 1.2)
                // Seen from behind, the knot and its tails over the back of the head.
                switch d.view {
                case .back:
                    // Tied to one side, so that the knot is not taken for a face.
                    Slinger.tails(&d, from: P(7.4, -62.2), toward: 0.8, flutter: flutter)
                    d.svg.ellipse(P(7.4, -62.2), 1.7, 1.5, fill: .colour(Ink.hide), stroke: .colour(Ink.line), width: 1)
                case .backQuarter:
                    Slinger.tails(&d, from: P(6.4, -63), toward: 0.6, flutter: flutter)
                    d.svg.ellipse(P(6.4, -63), 1.6, 1.5, fill: .colour(Ink.hide), stroke: .colour(Ink.line), width: 1)
                default:
                    break
                }
            })
        }
    }
}

// MARK: - The founder

/// The one who founds a new town: a long hide cloak trimmed in the team's
/// colour, a light tunic with chevrons, long dark hair under a headdress of
/// antlers (as Stone-age people wore them), and a short dark beard; nose A, as
/// the hunter's, since the two differ most in outline. A pole with a pennant
/// of the team's colour, which streams and ripples.
struct Founder: PersonLook {
    static let nose = Nose.curve

    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        switch pose {
        case .standing, .working:
            var r = Moves.standing(frame)
            r.frontArm = Limb(34 + r.lift, 58)
            r.mouth = .firm
            return r
        case .walking:
            var r = Moves.walking(frame, stride: 22)
            r.frontArm = Limb(34, 58)
            r.mouth = .firm
            return r
        default:
            return nil
        }
    }

    /// The long dark hair, seen from each side.
    static func hair(_ view: SpriteView) -> String {
        switch view {
        case .side:
            "M-9.8,-60.4 C-11,-71 4,-73 9.2,-65.4 C3.4,-67.6 -1.6,-65 -3.6,-61.4 C-5.6,-58 -6.4,-53 -5.4,-48 "
                + "L-11.6,-48.4 C-12.8,-52 -11.8,-57 -9.8,-60.4 Z"
        case .front:
            "M-11.4,-49.6 C-13.4,-60 -12.6,-71.4 0,-71 C12.6,-71.4 13.4,-60 11.4,-49.6 L8.8,-49.6 C9.8,-55.6 9.4,-61.6 6.4,-64.6 "
                + "C3,-66.4 -3,-66.4 -6.4,-64.6 C-9.4,-61.6 -9.8,-55.6 -8.8,-49.6 Z"
        case .frontQuarter:
            "M-10.6,-58.6 C-12,-72 7,-74.4 10.2,-63.4 C5,-67.6 0,-66.4 -3,-63.4 C-4.6,-59.6 -5,-54 -4.4,-48 "
                + "L-12.4,-48.4 C-13.4,-52 -12.6,-55.6 -10.6,-58.6 Z"
        case .back:
            "M-11.6,-47.6 C-13.6,-60 -12.6,-71.6 0,-71.2 C12.6,-71.6 13.6,-60 11.6,-47.6 C6,-46.4 -6,-46.4 -11.6,-47.6 Z"
        case .backQuarter:
            "M-10.8,-53 C-13,-74 11.4,-75.4 11.8,-58 C12.4,-54 12.2,-50.6 11.4,-47.6 C5,-46.6 -1,-47.4 -4.6,-49 "
                + "C-6.6,-51.6 -8.6,-52.6 -10.8,-53 Z"
        }
    }

    /// The short dark beard along the jaw, where the view shows it.
    static func beard(_ view: SpriteView) -> String? {
        switch view {
        case .side: "M-2.4,-50.8 C1.4,-47.8 7,-47.4 10.2,-50.6 C9.8,-47 7.6,-44.4 5,-43.4 C3,-44.6 -0.2,-46.8 -2.4,-50.8 Z"
        case .front: "M-8.6,-53.6 C-7.6,-47.4 -3.4,-43.4 0,-43.2 C3.4,-43.4 7.6,-47.4 8.6,-53.6 C6,-50.6 3,-49 0,-49 "
            + "C-3,-49 -6,-50.6 -8.6,-53.6 Z"
        case .frontQuarter: "M-3.6,-53.4 C-2.6,-47.6 1.6,-43.6 5,-43.4 C8.6,-43.8 11.2,-47.6 11.4,-53.6 C10,-50.6 7.6,-49 5,-49 "
            + "C1.8,-49 -1.4,-50.6 -3.6,-53.4 Z"
        case .backQuarter: "M-10.6,-53.4 C-11.4,-49 -9.6,-45.6 -7.4,-44.6 C-7.4,-47.4 -6.8,-49.8 -5.6,-51.4 Z"
        case .back: nil
        }
    }

    /// The band of the headdress across the brow, seen from each side.
    static func headband(_ view: SpriteView) -> String {
        switch view {
        case .side: "M-11.2,-63 q10,-6.4 21,-4.2"
        case .front: "M-11.4,-63.4 Q0,-68.6 11.4,-63.4"
        case .frontQuarter: "M-11.4,-61.8 Q1,-68.2 10.8,-65.8"
        case .back: "M-11.4,-63 Q0,-67.6 11.4,-63"
        case .backQuarter: "M-10.8,-65.8 Q-1,-68.2 11.4,-61.8"
        }
    }

    /// One antler: from `base` curving through `bend` to `tip`, with two prongs
    /// along it (`prongs`, the lower first) and a hook at the tip.
    static func antler(_ d: inout Drawing, base: P, bend: P, tip: P, prongs: (P, P), hook: P) {
        func along(_ t: Double) -> P { base * ((1 - t) * (1 - t)) + bend * (2 * (1 - t) * t) + tip * (t * t) }
        var antler = PathData()
        antler.move(base); antler.quad(bend, tip)
        for (t, prong) in [(0.38, prongs.0), (0.68, prongs.1)] {
            antler.move(along(t)); antler.line(along(t) + prong)
        }
        antler.move(tip); antler.line(tip + hook)
        d.svg.path(antler, stroke: .colour(Ink.line), width: 3.6)
        d.svg.path(antler, stroke: .colour(Ink.light), width: 1.8)
    }

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let sway = d.rig.sway
        d.figure { d in
            // The cloak, hung from both shoulders down his back: behind him
            // from the front, over him from behind.
            func cloak(_ d: inout Drawing) {
                if d.view == .side {
                    // Its hem swinging back as he walks.
                    let hem = P(-21 - abs(sway) * 2.5, -9)
                    d.svg.polygon([d.up(P(-9, -47.6)), d.up(P(-2, -47)), P(-3, -12), hem + P(1, 1)], fill: .colour(Ink.hide))
                    d.svg.polygon([d.up(P(-9.6, -45.8)), d.up(P(-6.6, -46.4)), hem + P(4.6, 0.4), hem + P(0.6, -0.4)], fill: .team)
                    d.svg.polygon([d.up(P(-7.4, -47.6)), d.up(P(-1.4, -47)), P(-2.4, -12.4), hem], fill: .none,
                                  stroke: .colour(Ink.line), width: 1.6)
                    return
                }
                let back = -8 - abs(sway) * 2.5
                func at(_ x: Double, _ y: Double, _ z: Double) -> P {
                    let p = d.project(x, y, z).point
                    return y < -30 ? d.up(p) : p
                }
                let outline = [at(-5, -47.4, -8.4), at(-5, -47.4, 8.4), at(back, -9, 15), at(back, -9, -15)]
                d.svg.polygon(outline.map { $0 + P(-0.6, 0.6) }, fill: .colour(Ink.hide))
                // The trim of the team's colour down both edges.
                for side in [-1.0, 1.0] {
                    d.svg.polygon([at(-5, -46.6, 8.4 * side), at(-5, -46.6, 5.6 * side), at(back, -9.4, 11.4 * side),
                                   at(back, -9.4, 15 * side)], fill: .team)
                }
                d.svg.polygon(outline, fill: .none, stroke: .colour(Ink.line), width: 1.6)
            }
            let cloakOver = d.view == .back || d.view == .backQuarter
            if !cloakOver { cloak(&d) }
            let hand = d.hand(front: true)
            let held = d.heldBehind(front: true)
            func banner(_ d: inout Drawing) {
                let wave = pose == .walking ? d.phase * 2 : d.phase
                // The cloth streams back; seen from the front or behind, outward from his head.
                let reach: Double
                switch d.view {
                case .side: reach = 1
                case .frontQuarter, .backQuarter: reach = 0.75
                case .front, .back: reach = hand.x < 0 ? 0.6 : -0.6
                }
                d.banner(at: hand, foot: hand.y + 26, top: -86, wave: wave, reach: reach)
            }
            d.arm(front: false)
            if held { banner(&d) }
            d.legs()
            d.garment(colour: [P(-11.6, -46), P(8, -48), P(13.4, -15), P(-14.6, -14)],
                      outline: [P(-8, -47), P(8, -47), P(12.4, -17), P(-13, -17)], fill: .colour(Ink.light)) { d in
                // Chevrons down the front.
                let from: Double?
                switch d.view {
                case .side: from = -1
                case .front: from = -3.4
                case .frontQuarter: from = -1.4
                case .back, .backQuarter: from = nil
                }
                if let from {
                    for y in [-40.0, -33.0, -26.0] {
                        d.svg.path("M\(num(from)),\(num(d.up(P(0, y)).y)) l3.4,2.6 l3.4,-2.6", stroke: .colour(Ink.moss), width: 1.6)
                    }
                }
            }
            d.svg.line([d.up(P(-11, -30.4)), d.up(P(10.6, -31))], stroke: .colour(Ink.darkHide), width: 2.2)
            d.zigzag(from: P(-13, -17), to: P(12.4, -17), teeth: 4, depth: 3)
            if cloakOver { cloak(&d) }
            // The banner, carried upright.
            if !held { banner(&d) }
            d.arm(front: true)
            d.head(nose: Founder.nose, behind: { d in
                // A pair of antlers rising from the crown, the far one behind.
                if d.view == .side {
                    for (base, reach) in [(P(-5.6, -64.8), 9.0), (P(-1.6, -66.2), 7.0)] {
                        let tip = base + P(-reach, -20.5), bend = base + P(2.4, -12.4)
                        Founder.antler(&d, base: base, bend: bend, tip: tip, prongs: (P(4.6, -4.6), P(4.2, -5.2)), hook: P(-2.6, 0.6))
                    }
                    return
                }
                // Seen from another side, one on each side of the crown, turned with the head.
                var antlers: [(depth: Double, draw: (inout Drawing) -> Void)] = []
                for side in [-1.0, 1.0] {
                    let base = d.project(-3.6, -65.6, 4.6 * side), bend = d.project(-1.2, -77.8, 7.4 * side)
                    let tip = d.project(-9.6, -86, 12.6 * side)
                    let prongs = (d.project(4.6, -4.6, -2.2 * side).point, d.project(4.2, -5.2, -2 * side).point)
                    let hook = d.project(-2.6, 0.6, 1.4 * side).point
                    antlers.append((base.depth, { d in
                        Founder.antler(&d, base: base.point, bend: bend.point, tip: tip.point, prongs: prongs, hook: hook)
                    }))
                }
                for antler in antlers.sorted(by: { $0.depth < $1.depth }) { antler.draw(&d) }
            }, hair: { d in
                // Long dark hair to the shoulders.
                d.svg.path(Founder.hair(d.view), fill: .colour(Ink.line))
            }, features: { d in
                // A short dark beard along the jaw.
                if let beard = Founder.beard(d.view) { d.svg.path(beard, fill: .colour(Ink.line)) }
            }, brow: { d in
                d.svg.path("M1,-64.6 l7.4,-0.6", stroke: .colour(Ink.line), width: 1.5)
            }, over: { d in
                let band = Founder.headband(d.view)
                d.svg.path(band, stroke: .colour(Ink.line), width: 3.2)
                d.svg.path(band, stroke: .colour(Ink.hide), width: 1.6)
            })
        }
    }
}

// MARK: - Seen from other sides

extension Drawing {
    /// An angle in the figure's upright plane as it shows in this view; in
    /// profile, the angle exactly as given.
    func inView(_ degrees: Double) -> Double { view == .side ? degrees : onScreen(degrees) }

    /// Whether what a hand holds is hidden behind the body in this view, so
    /// that it is drawn before the body; never in profile.
    func heldBehind(front: Bool) -> Bool { view != .side && armBehind(front: front) }

    /// Whether the view shows the figure's front rather than its back.
    var seesFront: Bool { view == .front || view == .frontQuarter }

    /// A strap or sash worn across the body, seen from the front or the back:
    /// from the left shoulder to the right hip, each given as (z, y) across
    /// the body, `width` across. On the back it runs the same way.
    mutating func strap(shoulder: P, hip: P, width: Double, fill: Paint) {
        let x = seesFront ? 5.0 : -5.0, w = width / 2
        let corners = [P(shoulder.x - w, shoulder.y), P(shoulder.x + w, shoulder.y),
                       P(hip.x + w, hip.y), P(hip.x - w, hip.y)]
        svg.polygon(corners.map { up(project(x, $0.y, $0.x).point) }, fill: fill)
    }

    /// A swung weapon's arc around `centre` in the figure's own plane, as it
    /// shows in this view (the profile's `swish`, foreshortened);
    /// `squeeze` is the share of its width that shows.
    mutating func whirl(around centre: P, radius: Double, from: Double, to: Double, squeeze: Double) {
        func at(_ degrees: Double, _ r: Double) -> P {
            let u = P.direction(degrees)
            return centre + P(u.x * squeeze, u.y) * r
        }
        var outer = PathData(), inner = PathData()
        for i in 0...6 {
            let t = Double(i) / 6
            let a = at(mix(from, to, t), radius), b = at(mix(from, to, 0.35 + 0.65 * t), radius - 3)
            if i == 0 { outer.move(a); inner.move(b) } else { outer.line(a); inner.line(b) }
        }
        svg.path(outer, stroke: .colour(Ink.line), width: 1.1, opacity: 0.6)
        svg.path(inner, stroke: .colour(Ink.line), width: 1, opacity: 0.45)
    }

    /// The lowest edge of a shape drawn in profile around the body, as it shows
    /// in this view: its two lowest corners once turned.
    func hem(of outline: [P]) -> (P, P) {
        let lowest = turned(outline).sorted { $0.y > $1.y }.prefix(2)
        let a = lowest.first!, b = lowest.last!
        return a.x < b.x ? (a, b) : (b, a)
    }
}
