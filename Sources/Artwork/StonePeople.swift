// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// The people of the Stone look: the hunter (worker), with clothing, hair, a
// tool, a nose and a mark of his own (docs/art-style.md), moving on the shared
// skeleton, and carrying the team's colour as a band.

enum StonePeople {
    /// The kinds drawn in the Stone look, with what each looks like.
    static func person(_ kind: UnitKind) -> (any PersonLook)? {
        switch kind {
        case .worker: Hunter()
        case .spearman, .swordsman, .horseman, .knight, .musketeer, .cannon, .rifleman, .fieldGun, .car, .boat: nil
        }
    }

    /// The nose each kind is drawn with (docs/art-style.md, "Noses").
    static func nose(_ kind: UnitKind) -> Nose? {
        switch kind {
        case .worker: Hunter.nose
        case .spearman, .swordsman, .horseman, .knight, .musketeer, .cannon, .rifleman, .fieldGun, .car, .boat: nil
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
