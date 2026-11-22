// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// MARK: - The alchemist (scholar)

/// An alchemist in a long robe of deep teal with wide sleeves, its hem banded
/// in gilt and worked with the signs of the art (the sun, the moon, fire and
/// water), the team's stole hanging from his neck, and a square cap of wine
/// with a tuft; round spectacles, a pointed grey beard, bushy brows and grey
/// tufts of hair; nose F. He carries a round flask of green tincture by its
/// neck and a book under his arm; at work he holds the flask up to the light
/// and swirls it, the tincture slopping round, and green vapour billows from
/// its mouth and drifts away.
struct AlchemyPeopleAlchemist: PersonLook {
    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        switch pose {
        case .standing:
            var r = Moves.standing(frame)
            r.frontArm = BronzePeopleKit.reach(BronzePeopleKit.frontShoulder(r), P(14.4, -33.6 - r.lift * 0.5))
            r.backArm = BronzePeopleKit.reach(BronzePeopleKit.backShoulder(r), P(-9.6, -31.4 - r.lift * 0.5))
            r.mouth = .smile
            return r
        case .walking:
            var r = Moves.walking(frame, stride: 18, kneeLift: 34, armSwing: 14)
            r.lean = 2
            r.frontArm = BronzePeopleKit.reach(BronzePeopleKit.frontShoulder(r), P(14.6, -33.4 + 0.6 * BronzePeopleKit.wave(frame, times: 2)))
            r.backArm = BronzePeopleKit.reach(BronzePeopleKit.backShoulder(r), P(-9.6, -31.4))
            return r
        case .working:
            return swirl(frame)
        default:
            return nil
        }
    }

    /// The flask's turn in a frame of the swirl, in degrees, and how its tincture slops.
    static func swirlTurn(_ frame: Int) -> Double { 13 * BronzePeopleKit.wave(frame) }
    static func slop(_ frame: Int) -> Double { BronzePeopleKit.wave(frame, -0.12) }

    /// The hand holding the flask up through the swirl: a small round, the flask turning with it.
    static func swirlHand(_ frame: Int) -> P {
        let t = Double(frame) / 12 * 2 * .pi
        return P(19 + 1.2 * sin(t), -53.2 + 0.9 * cos(t))
    }

    func swirl(_ frame: Int) -> Rig {
        var r = Moves.standing(frame)
        r.lean = -2
        r.frontArm = BronzePeopleKit.reach(BronzePeopleKit.frontShoulder(r), Self.swirlHand(frame))
        r.backArm = Limb(-10, -12)
        r.headTilt = -10
        r.eyes = frame == 8 ? .closed : .wide
        r.mouth = [Mouth.murmur, .murmur, .open, .open, .murmur, .smile, .smile, .open, .open, .murmur, .smile, .smile][frame]
        return r
    }

    /// The flask's radius.
    static let flaskSize = 4.6

    /// The flask's bowl when held by its neck at `hand`, turned by `degrees`.
    static func flaskCentre(hand: P, degrees: Double) -> P {
        hand + P(0, flaskSize * 1.7).rotated(degrees, about: P(0, 0))
    }

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        if d.view != .side { drawInView(&d, pose, frame); return }
        let sway = d.rig.sway
        d.figure { d in
            if pose == .working {
                // The book hangs shut in his far hand while he works, half hidden by the robe.
                AlchemyPeopleProps.book(&d.svg, at: d.joints.backHand + P(-1.4, 3.4), degrees: 6, cover: AlchemyPeopleInk.wine)
            }
            d.arm(front: false)
            d.legs()
            Self.robe(&d, sway: sway)
            if pose != .working {
                // The book under his arm.
                AlchemyPeopleProps.book(&d.svg, at: d.up(P(-12.6, -34.4)), degrees: 14, cover: AlchemyPeopleInk.wine)
                d.hand(d.joints.backHand)
            }
            // The flask, held by its neck, or raised on his fingertips while he swirls it.
            let hand = d.joints.frontHand
            let degrees: Double
            switch pose {
            case .working: degrees = Self.swirlTurn(frame)
            case .walking: degrees = 4 * BronzePeopleKit.wave(frame, 0.1, times: 2)
            default: degrees = 1.4 * BronzePeopleKit.wave(frame)
            }
            let centre = pose == .working ? hand + P(0, -Self.flaskSize - 0.6).rotated(degrees, about: P(0, 0))
                : Self.flaskCentre(hand: hand, degrees: degrees)
            let slop = pose == .working ? Self.slop(frame) : (pose == .walking ? 0.5 * BronzePeopleKit.wave(frame, 0, times: 2) : 0)
            Self.sleeve(&d)
            AlchemyPeopleProps.flask(&d.svg, at: centre, degrees: degrees, slop: slop, radius: Self.flaskSize)
            d.hand(hand)
            if pose == .working {
                // Vapour billowing from the mouth: each puff rises, swells, drifts back and thins; a new one follows at half the cycle.
                let mouth = AlchemyPeopleProps.flaskMouth(at: centre, degrees: degrees, radius: Self.flaskSize)
                for k in 0..<2 {
                    let p = (Double(frame) / 12 + Double(k) / 2).truncatingRemainder(dividingBy: 1)
                    let at = mouth + P(0.6 + p * 6 + 1.6 * sin(p * 2 * .pi), -3 - p * 20)
                    AlchemyPeopleProps.vapour(&d.svg, at: at, size: 3.4 + p * 6.4, opacity: 1 - p * 0.75)
                }
                // A wisp just leaving the mouth.
                d.svg.path("M\(num(mouth.x)),\(num(mouth.y - 0.6)) q-1.4,-1.6 0,-3.2", stroke: .colour(AlchemyPeopleInk.vapourShade), width: 1.2)
            }
            d.head(nose: .bulb, hair: { d in
                // Grey tufts sticking out under the cap at the back.
                d.svg.path("M-10.6,-63.6 C-14.6,-62 -15,-58.6 -12.4,-56.4 C-14.2,-55 -13.4,-51.6 -10.6,-51.2 C-9.4,-53.4 -8.6,-56 -8.2,-59 Z",
                           fill: .colour(AlchemyPeopleInk.greyHair), stroke: .colour(Ink.line), width: 0.8)
            }, features: { d in
                // A pointed grey beard from the jaw, and a drooping moustache.
                d.svg.path("M-3.4,-53 C-1.8,-48.6 1.4,-46.6 4.6,-44.6 C6,-43.2 6.6,-41.4 7,-39.4 C8.6,-42 10.2,-45.4 10.6,-49.6 "
                           + "C8.6,-49 6.2,-49 4.2,-49.6 C1.6,-50.4 -1,-51.6 -3.4,-53 Z",
                           fill: .colour(AlchemyPeopleInk.greyHair), stroke: .colour(Ink.line), width: 1)
                d.svg.path("M1.6,-47.6 q2,2 2.8,4.8 M5.2,-47.4 q1.2,2.2 1.4,5", stroke: .colour(Ink.line), width: 0.6, opacity: 0.6)
                d.svg.path("M4,-53 q3.6,-2 7.4,-0.2 q0.2,2.2 -1.2,3.2 q-0.6,-1.8 -2.6,-1.6 q-2.6,0.2 -3.6,-1.4 Z",
                           fill: .colour(AlchemyPeopleInk.greyHair), stroke: .colour(Ink.line), width: 0.8)
            }, brow: { d in
                d.svg.path("M0.4,-65.6 q4,-2.6 8.6,-0.6", stroke: .colour(Ink.line), width: 3)
                d.svg.path("M0.4,-65.6 q4,-2.6 8.6,-0.6", stroke: .colour(AlchemyPeopleInk.greyHair), width: 1.6)
            }, over: { d in
                // Round spectacles: a rim round the eye, the bridge to the nose, the side-piece to the ear.
                d.svg.circle(P(4.8, -59.8), 4.1, fill: .colour("#ffffff"), opacity: 0.18)
                d.svg.circle(P(4.8, -59.8), 4.1, fill: .none, stroke: .colour(Ink.line), width: 1.1)
                d.svg.path("M8.8,-60.4 q1.2,-0.8 2,-0.2", stroke: .colour(Ink.line), width: 1)
                d.svg.line([P(0.7, -60.2), P(-8.4, -59.4)], stroke: .colour(Ink.line), width: 0.8)
                d.svg.path("M2.6,-62 q1,-0.9 2.2,-1", stroke: .colour("#ffffff"), width: 0.8, opacity: 0.8)
                Self.cap(&d)
            })
        }
    }

    /// The robe, long to the ankles, its gilt hem worked with the signs of the
    /// art, and the team's stole hanging over it.
    static func robe(_ d: inout Drawing, sway: Double) {
        let hemBack = P(-16.6 - sway * 1.4, -3.4), hemFront = P(15.4 - sway * 1.4, -3.4)
        func robePath(_ o: P) -> PathData {
            var p = PathData()
            p.move(d.up(P(-8.4, -47)) + o)
            p.line(d.up(P(8.4, -47)) + o)
            p.cubic(d.up(P(10.6, -38)) + o, P(12.6, -20) + o, hemFront + o)
            p.line(hemBack + o)
            p.cubic(P(-13.8, -20) + o, d.up(P(-11, -38)) + o, d.up(P(-8.4, -47)) + o)
            p.close()
            return p
        }
        d.svg.path(robePath(P(-0.8, 0.8)), fill: .colour(AlchemyPeopleInk.teal))
        // The folds falling from the yoke.
        var folds = PathData()
        for (top, bottom) in [(P(-5, -36), P(-8.6, -6)), (P(-0.4, -30), P(-1.4, -6)), (P(9.4, -30), P(10.6, -6))] {
            folds.move(d.up(top)); folds.quad(d.up((top + bottom) * 0.5) + P(-1.2 - sway, 0), bottom + P(-sway, 0))
        }
        d.svg.path(folds, stroke: .colour(AlchemyPeopleInk.darkTeal), width: 1.1)
        // The gilt band at the hem, and the signs worked in it.
        let bandTop = -8.6
        d.svg.polygon([hemBack + P(0.6, 0), hemFront + P(-0.4, 0), P(hemFront.x - 0.9, bandTop), P(hemBack.x + 1.6, bandTop)],
                      fill: .colour(AlchemyPeopleInk.gilt))
        d.svg.line([P(hemBack.x + 1.6, bandTop), P(hemFront.x - 0.9, bandTop)], stroke: .colour(Ink.line), width: 0.8)
        let sign = Paint.colour(AlchemyPeopleInk.darkTeal)
        let y = -6.0, x0 = hemBack.x + 4.4, step = (hemFront.x - hemBack.x - 7.6) / 4
        // The sun: a circle with its point.
        d.svg.circle(P(x0, y), 1.3, fill: .none, stroke: sign, width: 0.6)
        d.svg.circle(P(x0, y), 0.3, fill: sign)
        // The moon: a crescent.
        d.svg.path("M\(num(x0 + step + 0.6)),\(num(y - 1.4)) a1.4,1.4 0 1 0 0,2.8 a1,1 0 1 1 0,-2.8 Z", fill: sign)
        // Fire: a triangle pointing up; water: one pointing down.
        let f = x0 + step * 2, w = x0 + step * 3
        d.svg.polygon([P(f - 1.4, y + 1.1), P(f + 1.4, y + 1.1), P(f, y - 1.4)], fill: .none, stroke: sign, width: 0.6)
        d.svg.polygon([P(w - 1.4, y - 1.1), P(w + 1.4, y - 1.1), P(w, y + 1.4)], fill: .none, stroke: sign, width: 0.6)
        // Mercury: a circle with horns and a cross.
        let m = x0 + step * 4
        d.svg.circle(P(m, y - 0.2), 0.9, fill: .none, stroke: sign, width: 0.6)
        d.svg.path("M\(num(m - 1)),\(num(y - 1.9)) q1,1 2,0 M\(num(m)),\(num(y + 0.7)) l0,1.2", stroke: sign, width: 0.6)
        d.svg.path(robePath(P(0, 0)), stroke: .colour(Ink.line), width: 1.8)
        // The stole: hanging from the neck down the front, in the team's colour, edged in the light and fringed.
        let stole = [P(2.6, -47.4), P(7.4, -47.2), P(9.2 - sway * 0.8, -15.2), P(4.2 - sway * 0.8, -15.6)]
        d.svg.polygon(stole.map { d.up($0) }, fill: .colour(AlchemyPeopleInk.light))
        d.band([P(3.5, -47.2), P(6.5, -47), P(8.2 - sway * 0.8, -15.8), P(5.1 - sway * 0.8, -16)])
        d.svg.polygon(stole.map { d.up($0) }, fill: .none, stroke: .colour(Ink.line), width: 1)
        var fringe = PathData()
        for i in 0..<5 {
            let top = stole[3] + (stole[2] - stole[3]) * (Double(i) / 4)
            fringe.move(top); fringe.line(top + P(-sway * 0.6, 2.2))
        }
        d.svg.path(fringe, stroke: .colour(Ink.line), width: 0.7)
        // The collar of the robe round the neck.
        d.svg.path("M\(num(-8.2)),\(num(-47 - d.rig.lift)) q8.4,3.2 16.6,0", stroke: .colour(Ink.line), width: 1.2)
    }

    /// The wide sleeve of the front arm, from the elbow to the wrist, turned back in the light.
    static func sleeve(_ d: inout Drawing) {
        let elbow = d.joints.frontElbow, hand = d.joints.frontHand
        let along = hand - elbow
        let length = max(BronzePeopleKit.length(along), 0.01)
        let u = along * (1 / length), a = P(-u.y, u.x)
        let wrist = elbow + u * (length - 2.2)
        let shoulder = d.joints.frontShoulder
        // The upper arm in the robe's cloth, then the sleeve widening to the wrist.
        d.svg.line([shoulder, elbow], stroke: .colour(Ink.line), width: 5.4)
        d.svg.line([shoulder, elbow], stroke: .colour(AlchemyPeopleInk.teal), width: 3.4)
        BronzePeopleProps.shape(&d.svg, [elbow + a * 2.4, elbow - a * 2.4, wrist - a * 4.2, wrist + a * 4.2],
                                fill: .colour(AlchemyPeopleInk.teal), width: 1.2)
        d.svg.polygon([wrist - u * 1.6 + a * 4, wrist - u * 1.6 - a * 4, wrist - a * 4.2, wrist + a * 4.2], fill: .colour(AlchemyPeopleInk.paleTeal),
                      stroke: .colour(Ink.line), width: 0.9)
    }

    /// A square cap of wine-coloured wool: stiff sides rising from the brow,
    /// ridges across its top, and a tuft at the middle.
    static func cap(_ d: inout Drawing) {
        BronzePeopleProps.shape(&d.svg, fill: .colour(AlchemyPeopleInk.wine), width: 1.5) { o in
            var p = PathData()
            p.move(P(-11.2, -62) + o)
            p.line(P(-12.4, -72.6) + o)
            p.quad(P(-0.6, -76) + o, P(11, -73) + o)
            p.line(P(10.6, -65.4) + o)
            p.cubic(P(3, -67.6) + o, P(-5, -66.2) + o, P(-11.2, -62) + o)
            p.close()
            return p
        }
        // The ridges, and the tuft.
        d.svg.path("M-4.4,-74.8 l0.6,7.4 M4,-75 l-0.2,7.6", stroke: .colour(AlchemyPeopleInk.darkWine), width: 1.4)
        d.svg.path("M-12.2,-72.6 q11.6,-3.6 23.2,-0.4", stroke: .colour(AlchemyPeopleInk.paleWine), width: 0.9)
        d.svg.circle(P(-0.2, -77.2), 2, fill: .colour(AlchemyPeopleInk.darkWine), stroke: .colour(Ink.line), width: 1)
        d.svg.path("M10.6,-65.4 C3,-67.6 -5,-66.2 -11.2,-62", stroke: .colour(Ink.line), width: 2.6)
        d.svg.path("M10.6,-65.4 C3,-67.6 -5,-66.2 -11.2,-62", stroke: .colour(AlchemyPeopleInk.darkWine), width: 1.2)
    }
}

// MARK: - The alchemist in the other views

extension AlchemyPeopleAlchemist {
    /// The robe's outline in profile, its curves taken as straight steps.
    static func robeShape(sway: Double) -> [P] {
        let hemBack = P(-16.6 - sway * 1.4, -3.4), hemFront = P(15.4 - sway * 1.4, -3.4)
        return [P(-8.4, -47), P(8.4, -47)] + AlchemyViews.cubic(P(8.4, -47), P(10.6, -38), P(12.6, -20), hemFront)
            + [hemBack] + AlchemyViews.cubic(hemBack, P(-13.8, -20), P(-11, -38), P(-8.4, -47)).dropLast()
    }

    /// A frame of a pose seen from a view other than the side: the robe, its
    /// hem and the stole go round him, the flask and the book are held where
    /// the view puts his hands, and his cap, spectacles and beard turn with his head.
    func drawInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let sway = d.rig.sway
        d.figure { d in
            func held(_ d: inout Drawing, right: Bool) {
                let hand = d.hand(front: right)
                if right {
                    let degrees: Double
                    switch pose {
                    case .working: degrees = d.onScreen(Self.swirlTurn(frame))
                    case .walking: degrees = 4 * BronzePeopleKit.wave(frame, 0.1, times: 2)
                    default: degrees = 1.4 * BronzePeopleKit.wave(frame)
                    }
                    let centre = pose == .working ? hand + P(0, -Self.flaskSize - 0.6).rotated(degrees, about: P(0, 0))
                        : Self.flaskCentre(hand: hand, degrees: degrees)
                    let slop = pose == .working ? Self.slop(frame) : (pose == .walking ? 0.5 * BronzePeopleKit.wave(frame, 0, times: 2) : 0)
                    AlchemyPeopleProps.flask(&d.svg, at: centre, degrees: degrees, slop: slop, radius: Self.flaskSize)
                    if pose == .working {
                        let mouth = AlchemyPeopleProps.flaskMouth(at: centre, degrees: degrees, radius: Self.flaskSize)
                        for k in 0..<2 {
                            let p = (Double(frame) / 12 + Double(k) / 2).truncatingRemainder(dividingBy: 1)
                            let at = mouth + P(0.6 + p * 4 + 1.6 * sin(p * 2 * .pi), -3 - p * 20)
                            AlchemyPeopleProps.vapour(&d.svg, at: at, size: 3.4 + p * 6.4, opacity: 1 - p * 0.75)
                        }
                        d.svg.path("M\(num(mouth.x)),\(num(mouth.y - 0.6)) q-1.4,-1.6 0,-3.2", stroke: .colour(AlchemyPeopleInk.vapourShade), width: 1.2)
                    }
                } else {
                    // The book: under his arm, or hanging shut in his hand while he works.
                    let k = max(abs(AlchemyViews.turn(d.view).c), 0.45)
                    let at = pose == .working ? hand + P(-0.6, 3.4) : hand + P(0, -2)
                    AlchemyViews.squeezed(&d.svg, about: at, by: k) { svg in
                        AlchemyPeopleProps.book(&svg, at: at, degrees: pose == .working ? 6 : 14, cover: AlchemyPeopleInk.wine)
                    }
                }
            }
            func arms(_ d: inout Drawing, behind: Bool) {
                for limb in AlchemyViews.arms(d, behind: behind) {
                    if !limb.right { held(&d, right: false) }
                    Self.sleeveInView(&d, limb)
                    if limb.right { held(&d, right: true) }
                    d.hand(limb.end)
                }
            }
            arms(&d, behind: true)
            d.legs()
            Self.robeInView(&d, sway: sway)
            arms(&d, behind: false)
            d.head(nose: .bulb, hair: { d in Self.tuftsInView(&d) }, features: { d in Self.beardInView(&d) }, brow: { d in
                d.svg.path("M0.4,-65.6 q4,-2.6 8.6,-0.6", stroke: .colour(Ink.line), width: 3)
                d.svg.path("M0.4,-65.6 q4,-2.6 8.6,-0.6", stroke: .colour(AlchemyPeopleInk.greyHair), width: 1.6)
            }, over: { d in
                Self.spectaclesInView(&d)
                Self.capInView(&d)
            })
        }
    }

    /// The robe, its gilt hem worked with the signs, and the stole, turned with the view.
    static func robeInView(_ d: inout Drawing, sway: Double) {
        let view = d.view
        let shape = robeShape(sway: sway)
        let line = Paint.colour(Ink.line)
        let seesFront = view == .front || view == .frontQuarter
        d.garment(colour: shape.map { $0 + P(-0.8, 0.8) }, outline: shape, fill: .colour(AlchemyPeopleInk.teal)) { d in
            // The folds falling from the yoke, on both sides of him.
            var folds = PathData()
            for side in [1.0, -1.0] {
                for (top, bottom) in [(P(-5, -36), P(-8.6, -8)), (P(-0.4, -30), P(-1.4, -8)), (P(9.4, -30), P(10.6, -8))] {
                    if let fold = AlchemyViews.worn(d, [top, (top + bottom) * 0.5 + P(-1.2 - sway, 0), bottom + P(-sway, 0)], on: shape, side: side) {
                        folds.move(fold[0]); folds.quad(fold[1], fold[2])
                    }
                }
            }
            d.svg.path(folds, stroke: .colour(AlchemyPeopleInk.darkTeal), width: 1.1)
            // The gilt band at the hem, and the signs worked in it where they face the viewer.
            let hem = [P(-16, -8.6), P(14.6, -8.6), P(15.2 - sway * 1.4, -3.4), P(-16.2 - sway * 1.4, -3.4)]
            d.band(hem, fill: .colour(AlchemyPeopleInk.gilt))
            d.svg.line(Array(d.turned(hem).prefix(1)) + [d.turned(hem).last!], stroke: line, width: 0.8)
            let sign = Paint.colour(AlchemyPeopleInk.darkTeal)
            for (i, x) in [-12.0, -5.0, 2.0, 9.0, 12.6].enumerated() {
                for side in [1.0, -1.0] {
                    let (c, depth) = AlchemyViews.surface(view, P(x, -6), on: shape, side: side)
                    guard depth > 1 else { continue }
                    switch (i + (side < 0 ? 2 : 0)) % 5 {
                    case 0:
                        d.svg.circle(c, 1.3, fill: .none, stroke: sign, width: 0.6); d.svg.circle(c, 0.3, fill: sign)
                    case 1:
                        d.svg.path("M\(num(c.x + 0.6)),\(num(c.y - 1.4)) a1.4,1.4 0 1 0 0,2.8 a1,1 0 1 1 0,-2.8 Z", fill: sign)
                    case 2:
                        d.svg.polygon([c + P(-1.4, 1.1), c + P(1.4, 1.1), c + P(0, -1.4)], fill: .none, stroke: sign, width: 0.6)
                    case 3:
                        d.svg.polygon([c + P(-1.4, -1.1), c + P(1.4, -1.1), c + P(0, 1.4)], fill: .none, stroke: sign, width: 0.6)
                    default:
                        d.svg.circle(c + P(0, -0.2), 0.9, fill: .none, stroke: sign, width: 0.6)
                        d.svg.path("M\(num(c.x - 1)),\(num(c.y - 1.9)) q1,1 2,0 M\(num(c.x)),\(num(c.y + 0.7)) l0,1.2", stroke: sign, width: 0.6)
                    }
                }
            }
        }
        // The stole: round the back of his neck, and hanging down his front on either side.
        if !seesFront {
            let yoke = [P(-8.6, -48.2), P(8.6, -48.2), P(9.2, -44.2), P(-9.2, -44.2)]
            d.svg.polygon(d.turned(yoke).map(d.up), fill: .colour(AlchemyPeopleInk.light))
            d.band([P(-8.6, -47.6), P(8.6, -47.6), P(9, -45), P(-9, -45)])
            d.svg.polygon(d.turned(yoke).map(d.up), fill: .none, stroke: line, width: 1)
        }
        for side in [1.0, -1.0] {
            // Each strip falls straight down his chest, a little to one side of his middle.
            func strip(_ angles: [(Double, Double)]) -> [P]? {
                var points: [P] = []
                for (y, angle) in angles {
                    let (p, depth) = AlchemyViews.around(view, y, angle: angle, on: shape, side: side)
                    guard depth > 0.5 else { return nil }
                    points.append(d.up(p + P(-sway * 0.8 * (y > -30 ? 1 : 0), 0)))
                }
                return points
            }
            guard let outer = strip([(-47.4, 18), (-47.2, 50), (-15.2, 30), (-15.6, 13)]),
                  let inner = strip([(-47.2, 25), (-47, 43), (-15.8, 26), (-16, 17)]) else { continue }
            d.svg.polygon(outer, fill: .colour(AlchemyPeopleInk.light))
            d.svg.polygon(inner, fill: .team)
            d.svg.polygon(outer, fill: .none, stroke: line, width: 1)
            var fringe = PathData()
            for i in 0..<5 {
                let top = outer[3] + (outer[2] - outer[3]) * (Double(i) / 4)
                fringe.move(top); fringe.line(top + P(-sway * 0.6, 2.2))
            }
            d.svg.path(fringe, stroke: line, width: 0.7)
        }
        // The collar round the neck.
        let collar = AlchemyViews.rim(view, radius: 8.4, front: -46.6 - d.rig.lift, back: -47.4 - d.rig.lift, steps: 8)
        d.svg.line(collar, stroke: line, width: 1.2)
    }

    /// A wide sleeve of the robe along an arm in this view: the upper arm in
    /// the robe's cloth, then the sleeve widening to the wrist, turned back in the light.
    static func sleeveInView(_ d: inout Drawing, _ limb: AlchemyViews.Limb) {
        let shoulder = limb.root, elbow = limb.joint, hand = limb.end
        d.svg.line([shoulder, elbow], stroke: .colour(Ink.line), width: 5.4)
        d.svg.line([shoulder, elbow], stroke: .colour(limb.right ? AlchemyPeopleInk.teal : AlchemyPeopleInk.darkTeal), width: 3.4)
        let along = hand - elbow
        let length = BronzePeopleKit.length(along)
        guard length > 2.6 else { return }
        let u = along * (1 / length), a = P(-u.y, u.x)
        let wrist = elbow + u * (length - 2.2)
        BronzePeopleProps.shape(&d.svg, [elbow + a * 2.4, elbow - a * 2.4, wrist - a * 4.2, wrist + a * 4.2],
                                fill: .colour(limb.right ? AlchemyPeopleInk.teal : AlchemyPeopleInk.darkTeal), width: 1.2)
        d.svg.polygon([wrist - u * 1.6 + a * 4, wrist - u * 1.6 - a * 4, wrist - a * 4.2, wrist + a * 4.2], fill: .colour(AlchemyPeopleInk.paleTeal),
                      stroke: .colour(Ink.line), width: 0.9)
    }

    /// The grey tufts sticking out under the cap, as the view shows them.
    static func tuftsInView(_ d: inout Drawing) {
        let grey = Paint.colour(AlchemyPeopleInk.greyHair), line = Paint.colour(Ink.line)
        func tuft(_ d: inout Drawing, at x: Double, out: Double) {
            d.svg.path("M\(num(x)),-63.4 C\(num(x + out * 4)),-62 \(num(x + out * 4.4)),-58.6 \(num(x + out * 1.8)),-56.4 "
                       + "C\(num(x + out * 3.6)),-55 \(num(x + out * 2.8)),-51.6 \(num(x)),-51.2 C\(num(x - out * 1.2)),-53.4 "
                       + "\(num(x - out * 1.6)),-58 \(num(x)),-63.4 Z", fill: grey, stroke: line, width: 0.8)
        }
        switch d.view {
        case .front:
            tuft(&d, at: -10, out: -1); tuft(&d, at: 10, out: 1)
        case .frontQuarter:
            tuft(&d, at: -9.6, out: -1)
        case .back:
            d.svg.path("M-11,-62 C-12.6,-57 -11,-52 -7,-50.4 C-3,-51.6 3,-51.6 7,-50.4 C11,-52 12.6,-57 11,-62 C5,-60 -5,-60 -11,-62 Z",
                       fill: grey, stroke: line, width: 0.8)
        case .backQuarter:
            d.svg.path("M-11,-61.6 C-12.6,-56.6 -11,-52 -7.4,-50.4 C-3,-51.4 2,-51.6 5.6,-50.8 C7.4,-53 7.6,-57 6.6,-61 C1,-59.4 -5,-59.6 -11,-61.6 Z",
                       fill: grey, stroke: line, width: 0.8)
        case .side:
            break
        }
    }

    /// The pointed grey beard and the drooping moustache, seen from the front or a quarter.
    static func beardInView(_ d: inout Drawing) {
        let grey = Paint.colour(AlchemyPeopleInk.greyHair), line = Paint.colour(Ink.line)
        let (left, right, centre): (Double, Double, Double)
        switch d.view {
        case .front: (left, right, centre) = (-7.4, 7.4, 0)
        case .frontQuarter: (left, right, centre) = (-3.6, 10.2, 5.4)
        default: return
        }
        d.svg.path("M\(num(left)),-53 C\(num(left + 1)),-48.4 \(num(centre - 2.4)),-45 \(num(centre)),-39.6 "
                   + "C\(num(centre + 2.4)),-45 \(num(right - 1)),-48.4 \(num(right)),-53 C\(num(right - 3)),-49.4 \(num(centre + 2.6)),-49.2 "
                   + "\(num(centre)),-49.6 C\(num(centre - 2.6)),-49.2 \(num(left + 3)),-49.4 \(num(left)),-53 Z",
                   fill: grey, stroke: line, width: 1)
        d.svg.path("M\(num(centre - 1.6)),-47.6 q0.6,2.4 1.2,4.6 M\(num(centre + 1.6)),-47.6 q-0.6,2.4 -1.2,4.6", stroke: line, width: 0.6, opacity: 0.6)
        // The moustache, drooping either side of the mouth.
        d.svg.path("M\(num(centre)),-53.6 C\(num(centre - 3)),-54.4 \(num(centre - 5.4)),-52.6 \(num(centre - 5)),-49.8 "
                   + "C\(num(centre - 3.6)),-51.2 \(num(centre - 1.6)),-51.8 \(num(centre)),-52 C\(num(centre + 1.6)),-51.8 "
                   + "\(num(centre + 3.6)),-51.2 \(num(centre + 5)),-49.8 C\(num(centre + 5.4)),-52.6 \(num(centre + 3)),-54.4 \(num(centre)),-53.6 Z",
                   fill: grey, stroke: line, width: 0.8)
    }

    /// The round spectacles, rims round both eyes where the face shows, and their side-pieces to the ears.
    static func spectaclesInView(_ d: inout Drawing) {
        let line = Paint.colour(Ink.line)
        let rims: [(P, Double)]
        switch d.view {
        case .front: rims = [(P(-4.3, -59.8), 1), (P(4.3, -59.8), 1)]
        case .frontQuarter: rims = [(P(-1.5, -59.8), 0.72), (P(5.9, -59.8), 1)]
        case .back, .backQuarter:
            // Only the side-pieces show, running back over the ears.
            let x = d.view == .back ? 10.2 : 7.4
            for side in d.view == .back ? [-1.0, 1.0] : [1.0] {
                d.svg.line([P(side * x, -60.2), P(side * (x - 1.4), -59.4)], stroke: line, width: 0.8)
            }
            return
        case .side: return
        }
        for (c, k) in rims {
            d.svg.ellipse(c, 4.1 * k, 4.1, fill: .colour("#ffffff"), opacity: 0.18)
            d.svg.ellipse(c, 4.1 * k, 4.1, fill: .none, stroke: line, width: 1.1)
            d.svg.path("M\(num(c.x - 2.2 * k)),-62 q\(num(k)),-0.9 \(num(2.2 * k)),-1", stroke: .colour("#ffffff"), width: 0.8, opacity: 0.8)
        }
        let (a, b) = (rims[0], rims[1])
        d.svg.path("M\(num(a.0.x + 4.1 * a.1)),-60.4 Q\(num((a.0.x + b.0.x) / 2)),-62 \(num(b.0.x - 4.1 * b.1)),-60.4", stroke: line, width: 1)
        if d.view == .front {
            d.svg.line([P(-8.4, -60.2), P(-10.4, -59.6)], stroke: line, width: 0.8)
            d.svg.line([P(8.4, -60.2), P(10.4, -59.6)], stroke: line, width: 0.8)
        } else {
            d.svg.line([P(a.0.x - 2.9, -60.2), P(-7.6, -59.6)], stroke: line, width: 0.8)
        }
    }

    /// The square cap of wine-coloured wool, its stiff sides, ridges and tuft, as the view shows it.
    static func capInView(_ d: inout Drawing) {
        let view = d.view
        let cap = AlchemyViews.dome(view, radius: 11.8, front: -65.4, back: -62, top: -75.4, crest: -0.6)
        BronzePeopleProps.shape(&d.svg, cap, fill: .colour(AlchemyPeopleInk.wine), width: 1.5)
        // The ridges at its four corners, where they face the viewer.
        var ridges = PathData()
        for phi in [0.25, 0.75, 1.25, 1.75].map({ $0 * .pi }) {
            let low = AlchemyViews.onRim(view, radius: 10.6, front: -66.6, back: -63.4, phi: phi)
            let high = AlchemyViews.onRim(view, radius: 6, front: -74.6, back: -74, phi: phi)
            guard low.depth > 1.5 else { continue }
            ridges.move(low.point); ridges.line(high.point)
        }
        d.svg.path(ridges, stroke: .colour(AlchemyPeopleInk.darkWine), width: 1.4)
        let top = AlchemyViews.rim(view, radius: 10.4, front: -73, back: -73, steps: 8)
        d.svg.line(top, stroke: .colour(AlchemyPeopleInk.paleWine), width: 0.9)
        d.svg.circle(P(-0.2 * AlchemyViews.turn(view).c, -77), 2, fill: .colour(AlchemyPeopleInk.darkWine), stroke: .colour(Ink.line), width: 1)
        // The edge at the brow.
        let rim = AlchemyViews.rim(view, radius: 11.4, front: -65.4, back: -62.2)
        d.svg.line(rim, stroke: .colour(Ink.line), width: 2.6)
        d.svg.line(rim, stroke: .colour(AlchemyPeopleInk.darkWine), width: 1.2)
    }
}
