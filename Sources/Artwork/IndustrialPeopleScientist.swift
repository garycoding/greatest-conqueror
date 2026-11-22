// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// MARK: - The scientist (scholar)

/// A scientist in a long laboratory coat of undyed drill to the knee, open at
/// the chest on a waistcoat of the team's colour, a winged collar and a bow tie
/// of the team's colour, bottle-green trousers; bald on the crown with ginger tufts and mutton-chop
/// whiskers, oval spectacles; nose B. He carries a conical flask by its neck
/// and his notebook under his arm; at work the flask simmers on a tripod over a
/// spirit lamp, and he writes his observations in the notebook, looking up
/// at the flask as its bubbles rise and its steam curls away.
struct IndustrialPeopleScientist: PersonLook {
    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        switch pose {
        case .standing:
            var r = Moves.standing(frame)
            r.frontArm = BronzePeopleKit.reach(BronzePeopleKit.frontShoulder(r), P(14.6, -34 - r.lift * 0.5))
            r.backArm = BronzePeopleKit.reach(BronzePeopleKit.backShoulder(r), P(-9.6, -31.4 - r.lift * 0.5))
            r.headTilt = 3
            return r
        case .walking:
            var r = Moves.walking(frame, stride: 19, kneeLift: 36, armSwing: 14)
            r.lean = 2
            r.frontArm = BronzePeopleKit.reach(BronzePeopleKit.frontShoulder(r), P(14.6, -33.6 + 0.6 * IndustrialPeopleKit.wave(frame, times: 2)))
            r.backArm = BronzePeopleKit.reach(BronzePeopleKit.backShoulder(r), P(-9.6, -31.4))
            return r
        case .working:
            return writing(frame)
        default:
            return nil
        }
    }

    // MARK: Writing

    /// The open notebook in the picture, held up in the far hand, and its turn.
    static let notebookAt = P(9.4, -35.4)
    static let notebookDegrees = -14.0
    /// The pencil's slope from the hand to its point.
    static let pencilDegrees = -34.0
    static let pencilLength = 6.4

    /// The frames on which he looks up at the flask rather than at his writing.
    static let looking: Set<Int> = [8, 9, 10]

    /// Where the pencil's point is in a frame, in the picture: along a line of
    /// the near page in small strokes, and lifted while he looks up.
    static func pencilPoint(_ frame: Int) -> P {
        let along: [Double] = [0.6, 1.2, 1.8, 2.3, 2.9, 3.4, 3.9, 4.3, 4.4, 4.2, 3.2, 1.6]
        let rise: [Double] = [0, 0.5, 0, 0.5, 0, 0.5, 0, 0.4, 1.6, 2, 1.8, 0.8]
        let local = P(1.4 + along[frame], -2.4 - rise[frame])
        return notebookAt + local.rotated(notebookDegrees, about: P(0, 0))
    }

    func writing(_ frame: Int) -> Rig {
        var r = Moves.standing(frame)
        r.lean = 5
        r.backArm = IndustrialPeopleKit.reach(front: false, r, to: Self.notebookAt + P(-2.6, 1.6))
        let hand = Self.pencilPoint(frame) - P.direction(Self.pencilDegrees) * Self.pencilLength
        r.frontArm = IndustrialPeopleKit.reach(front: true, r, to: hand)
        let up = Self.looking.contains(frame)
        r.headTilt = up ? -3 : 10
        r.eyes = frame == 11 ? .closed : (up ? .wide : .down)
        r.mouth = up ? .murmur : .firm
        return r
    }

    /// The tripod's place on the ground, the height of its ring, and the flask's height.
    static let tripodX = 30.0, ringHeight = 15.0, flaskHeight = 12.0

    // MARK: Drawing

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        if d.view != .side { drawInView(&d, pose, frame); return }
        let sway = d.rig.sway
        if pose == .working {
            IndustrialPeopleProps.burner(&d.svg, x: Self.tripodX, height: Self.ringHeight, flicker: IndustrialPeopleKit.wave(frame, 0, times: 2))
            IndustrialPeopleProps.conicalFlask(&d.svg, base: P(Self.tripodX, -Self.ringHeight - 0.8), height: Self.flaskHeight,
                                               boil: Double(frame) / 12)
            // Steam curling from the neck: each puff rises, swells, drifts back and thins; a new one follows at half the cycle.
            let mouth = P(Self.tripodX, -Self.ringHeight - 0.8 - Self.flaskHeight)
            for k in 0..<2 {
                let p = (Double(frame) / 12 + Double(k) / 2).truncatingRemainder(dividingBy: 1)
                let at = mouth + P(-p * 5 + 1.4 * sin(p * 2 * .pi), -3 - p * 17)
                Self.steam(&d.svg, at: at, size: 2.6 + p * 4.6, opacity: 1 - p * 0.8)
            }
        }
        d.figure { d in
            if pose != .working { IndustrialPeopleKit.arm(&d, front: false, fill: .colour(IndustrialPeopleInk.shadeLight), width: 4.4) }
            IndustrialPeopleKit.trousers(&d, colour: IndustrialPeopleInk.green, shade: IndustrialPeopleInk.darkGreen)
            Self.coat(&d, sway: sway)
            let hand = d.joints.frontHand
            switch pose {
            case .working:
                // The notebook open in the far hand before him, and the pencil in the near.
                IndustrialPeopleKit.arm(&d, front: false, fill: .colour(IndustrialPeopleInk.shadeLight), width: 4.4)
                IndustrialPeopleProps.notebook(&d.svg, at: IndustrialPeopleKit.body(Self.notebookAt, d.rig),
                                               degrees: Self.notebookDegrees - d.rig.lean, written: 0.72)
                d.hand(d.joints.backHand + P(-0.4, -0.4))
                IndustrialPeopleKit.arm(&d, front: true, fill: .colour(IndustrialPeopleInk.light), width: 4.4, cuff: IndustrialPeopleInk.shadeLight)
                IndustrialPeopleProps.pencil(&d.svg, at: hand, degrees: AlchemyPeopleKit.bodyDegrees(Self.pencilDegrees, d.rig), length: Self.pencilLength)
                d.hand(hand)
            default:
                // The notebook under his arm, and the flask held by its neck.
                IndustrialPeopleProps.shutNotebook(&d.svg, at: d.up(P(-12.4, -33.8)), degrees: 12)
                d.hand(d.joints.backHand)
                let swing = pose == .walking ? 4 * IndustrialPeopleKit.wave(frame, 0.15, times: 2) : 1.2 * IndustrialPeopleKit.wave(frame)
                d.svg.group(turned: swing, about: hand) { svg in
                    IndustrialPeopleProps.conicalFlask(&svg, base: hand + P(0, Self.flaskHeight - 1.6), height: Self.flaskHeight, boil: nil)
                }
                IndustrialPeopleKit.arm(&d, front: true, fill: .colour(IndustrialPeopleInk.light), width: 4.4, cuff: IndustrialPeopleInk.shadeLight)
            }
            d.head(nose: .button, behind: { d in
                // Ginger tufts standing out behind the ear.
                d.svg.path("M-10.2,-61.6 C-13.6,-61.4 -14.2,-58.6 -12.4,-57.4 C-13.8,-56 -13.2,-53.4 -10.8,-53.4 C-10,-55.6 -9.6,-58.6 -10.2,-61.6 Z",
                           fill: .colour(IndustrialPeopleInk.gingerHair), stroke: .colour(Ink.line), width: 0.9)
            }, hair: { d in
                // The fringe of hair round the back of the head, under a bald crown.
                d.svg.path("M-10.6,-62.6 C-11.6,-58.6 -11,-54.6 -9,-51.6 L-7.2,-52.6 C-8.6,-55.6 -8.8,-59 -8,-62 Z",
                           fill: .colour(IndustrialPeopleInk.gingerHair))
                // The shine on the crown.
                d.svg.path("M-4.6,-65.8 q2.6,-1.8 5.6,-1.4", stroke: .colour("#ffffff"), width: 1, opacity: 0.6)
            }, features: { d in
                // Mutton-chop whiskers, down the cheek to the jaw, the chin shaven.
                // Mutton-chop whiskers: a narrow band down from the ear, widening along the jaw; the chin shaven.
                d.svg.path("M-6.6,-59.8 C-6.6,-56.4 -5.6,-53 -3.4,-50.6 C-1.8,-49.2 0.6,-49 1.8,-50.4 C0,-51.4 -1.6,-53.2 -3,-55.4 "
                           + "C-3.6,-56.8 -4,-58.4 -4.2,-60 Z",
                           fill: .colour(IndustrialPeopleInk.gingerHair), stroke: .colour(Ink.line), width: 0.9)
                d.svg.path("M-5,-56 q0.4,1.8 1.4,3", stroke: .colour(IndustrialPeopleInk.darkBrick), width: 0.6, opacity: 0.8)
            }, brow: { d in
                d.svg.path("M1.4,-64.8 q3.6,-2.4 7.6,-0.6", stroke: .colour(IndustrialPeopleInk.gingerHair), width: 1.8)
            }, over: { d in
                // Oval spectacles of steel wire, the bridge to the nose and the side-piece to the ear.
                d.svg.ellipse(P(5, -59.8), 3.8, 3.2, fill: .colour("#ffffff"), opacity: 0.2)
                d.svg.ellipse(P(5, -59.8), 3.8, 3.2, fill: .none, stroke: .colour(Ink.line), width: 1)
                d.svg.path("M8.8,-60.4 q1.2,-0.8 2.2,-0.4", stroke: .colour(Ink.line), width: 0.9)
                d.svg.line([P(1.2, -60.2), P(-8.4, -59.6)], stroke: .colour(Ink.line), width: 0.8)
                d.svg.path("M2.8,-61.8 q1,-0.8 2.2,-0.9", stroke: .colour("#ffffff"), width: 0.8, opacity: 0.8)
            })
        }
    }

    /// The laboratory coat to the knee, open at the chest on the waistcoat,
    /// with the collar and the bow tie, a pocket with pencils in it.
    static func coat(_ d: inout Drawing, sway: Double) {
        let hemBack = P(-15.4 - sway * 1.4, -8.6), hemFront = P(14.6 - sway * 1.4, -8.6)
        func coatPath(_ o: P) -> PathData {
            var p = PathData()
            p.move(d.up(P(-9.2, -47.6)) + o)
            p.line(d.up(P(9.2, -47.6)) + o)
            p.cubic(d.up(P(11, -38)) + o, P(12.4, -24) + o, hemFront + o)
            p.line(hemBack + o)
            p.cubic(P(-13.6, -24) + o, d.up(P(-11.4, -38)) + o, d.up(P(-9.2, -47.6)) + o)
            p.close()
            return p
        }
        d.svg.path(coatPath(P(-0.8, 0.8)), fill: .colour(IndustrialPeopleInk.light))
        // The shade down the back, where the drill folds, and the folds below the waist.
        d.svg.polygon([P(-11.6, -40), P(-8.2, -40), P(-9.8, -9), hemBack + P(0.8, -0.4)].map(d.up), fill: .colour(IndustrialPeopleInk.shadeLight))
        var folds = PathData()
        for (top, bottom) in [(P(-3, -24), P(-4.6, -9)), (P(9.4, -24), P(10.6, -9))] {
            folds.move(top); folds.quad((top + bottom) * 0.5 + P(-1 - sway, 0), bottom + P(-sway, 0))
        }
        d.svg.path(folds, stroke: .colour(IndustrialPeopleInk.shadeLight), width: 1.1)
        // The waistcoat in the team's colour in the opening, its buttons, and the shirt's front above it.
        d.svg.polygon([P(0.4, -47.2), P(9.4, -47.2), P(11.2, -27), P(2.4, -26.4)].map(d.up), fill: .colour(Ink.eyeWhite))
        d.band([P(1, -43.4), P(10.2, -43.8), P(11.4, -24.4), P(2.4, -23.8)])
        var buttons = PathData()
        for i in 0..<4 { let y = -40.6 + Double(i) * 3.8; buttons.move(d.up(P(7.6 + Double(i) * 0.2, y))); buttons.line(d.up(P(7.8 + Double(i) * 0.2, y + 0.2))) }
        d.svg.path(buttons, stroke: .colour(Ink.line), width: 1.5)
        d.svg.line([d.up(P(1, -43.4)), d.up(P(10.2, -43.8))], stroke: .colour(Ink.line), width: 0.8)
        // The lapels of the coat over the edges of the opening.
        d.svg.polygon([P(-1, -47.4), P(2.6, -47.4), P(2.4, -42), P(1.6, -24), P(-0.4, -24)].map(d.up), fill: .colour(IndustrialPeopleInk.light),
                      stroke: .colour(Ink.line), width: 0.9)
        d.svg.line([d.up(P(2.4, -42)), d.up(P(0.6, -40.4))], stroke: .colour(Ink.line), width: 0.7)
        // The breast pocket with two pencils in it, and a hip pocket.
        d.svg.line([d.up(P(-5.6, -40.8)), d.up(P(-5.4, -44.6))], stroke: .colour(Ink.line), width: 1.7)
        d.svg.line([d.up(P(-5.6, -40.8)), d.up(P(-5.4, -44.6))], stroke: .colour(IndustrialPeopleInk.green), width: 0.8)
        d.svg.line([d.up(P(-3.8, -40.8)), d.up(P(-3.2, -43.8))], stroke: .colour(Ink.line), width: 1.7)
        d.svg.line([d.up(P(-3.8, -40.8)), d.up(P(-3.2, -43.8))], stroke: .colour(IndustrialPeopleInk.brick), width: 0.8)
        d.svg.polygon([P(-7.6, -41.6), P(-1.6, -41.6), P(-1.8, -37.4), P(-7.4, -37.4)].map(d.up), fill: .colour(IndustrialPeopleInk.light),
                      stroke: .colour(Ink.line), width: 0.8)
        d.svg.line([P(-9.4, -19.4), P(-2.8, -19.6)], stroke: .colour(Ink.line), width: 0.8)
        d.svg.path(coatPath(P(0, 0)), stroke: .colour(Ink.line), width: 1.8)
        // The coat's buttons below the opening.
        for y in [-20.6, -15.4] { d.svg.circle(P(2.6, y), 0.7, fill: .colour(IndustrialPeopleInk.paleSoot), stroke: .colour(Ink.line), width: 0.5) }
        d.svg.line([P(1.6, -24), P(1.6, -8.8)], stroke: .colour(Ink.line), width: 0.8)
        // The winged collar and the black bow tie.
        let lift = d.rig.lift
        d.svg.polygon([P(1.4, -48.6 - lift), P(9.2, -48.8 - lift), P(8.6, -46.2 - lift), P(2.4, -46 - lift)], fill: .colour(Ink.eyeWhite),
                      stroke: .colour(Ink.line), width: 0.8)
        let knot = P(6.2, -45.4 - lift)
        d.svg.polygon([knot + P(-3, -1.6), knot + P(-0.6, -0.3), knot + P(-0.6, 0.5), knot + P(-3, 1.8)], fill: .team,
                      stroke: .colour(Ink.line), width: 0.7)
        d.svg.polygon([knot + P(3, -1.6), knot + P(0.6, -0.3), knot + P(0.6, 0.5), knot + P(3, 1.8)], fill: .team,
                      stroke: .colour(Ink.line), width: 0.7)
        d.svg.circle(knot, 0.9, fill: .team, stroke: .colour(Ink.line), width: 0.6)
    }

    /// A puff of steam: round billows about `c`, `size` across, one outline round them all, thinning to `opacity`.
    static func steam(_ svg: inout SVG, at c: P, size: Double, opacity: Double) {
        let billows: [(P, Double)] = [(P(0, 0), 0.5), (P(-0.42, 0.22), 0.36), (P(0.44, 0.18), 0.38), (P(-0.12, -0.42), 0.34)]
        svg.raw("<g opacity=\"\(num(opacity))\">")
        for (offset, r) in billows {
            svg.circle(c + offset * size, r * size, fill: .colour(Ink.line), stroke: .colour(Ink.line), width: 1.3)
        }
        for (offset, r) in billows {
            svg.circle(c + offset * size + P(-0.3, 0.3), r * size, fill: .colour(IndustrialPeopleInk.steam))
        }
        svg.path("M\(num(c.x - size * 0.3)),\(num(c.y + size * 0.32)) q\(num(size * 0.3)),\(num(size * 0.18)) \(num(size * 0.6)),0",
                 stroke: .colour(IndustrialPeopleInk.shadeLight), width: 0.8)
        svg.raw("</g>")
    }
}

// MARK: - The scientist in the other views

extension IndustrialPeopleScientist {
    /// A frame in a view other than the side: the same dress and the same
    /// work, the burner and the flask standing beside him.
    func drawInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let sway = d.rig.sway
        var ground = SVG(layer: d.svg.layer)
        let tripod = IndustrialPoint(22, 0, IndustrialViews.aside(d) * 0.9)
        let nearer = IndustrialViews.depth(d, tripod) > 0
        if pose == .working {
            let foot = IndustrialViews.world(d, IndustrialViews.screen(d, tripod))
            let bob = d.bob
            IndustrialViews.placed(&ground, d, pivot: P(Self.tripodX, 0), to: P(foot.x, foot.y - bob), least: 1) { svg in
                IndustrialPeopleProps.burner(&svg, x: Self.tripodX, height: Self.ringHeight, flicker: IndustrialPeopleKit.wave(frame, 0, times: 2))
                IndustrialPeopleProps.conicalFlask(&svg, base: P(Self.tripodX, -Self.ringHeight - 0.8), height: Self.flaskHeight, boil: Double(frame) / 12)
                let mouth = P(Self.tripodX, -Self.ringHeight - 0.8 - Self.flaskHeight)
                for k in 0..<2 {
                    let p = (Double(frame) / 12 + Double(k) / 2).truncatingRemainder(dividingBy: 1)
                    Self.steam(&svg, at: mouth + P(-p * 5 + 1.4 * sin(p * 2 * .pi), -3 - p * 17), size: 2.6 + p * 4.6, opacity: 1 - p * 0.8)
                }
            }
            if !nearer { d.svg.raw(ground.body) }
        }
        d.figure { d in
            let farArm: IndustrialViews.Arm, nearArm: IndustrialViews.Arm
            var notebook: IndustrialPoint?
            var pencil: (hand: IndustrialPoint, point: IndustrialPoint)?
            if pose == .working {
                // The notebook open before his chest in the far hand, the pencil writing on it.
                let at = IndustrialPeopleKit.body(Self.notebookAt, d.rig)
                let book = IndustrialPoint(at.x - 1, at.y, -1.6)
                let local = Self.pencilPoint(frame) - Self.notebookAt
                let point = book + IndustrialPoint(0.6, local.y, -local.x * 0.8 + 1)
                let hand = point - IndustrialViews.vector(Self.pencilDegrees) * Self.pencilLength
                farArm = IndustrialViews.reach(d, front: false, to: book + IndustrialPoint(-0.6, 1.6, -3))
                nearArm = IndustrialViews.reach(d, front: true, to: hand)
                notebook = book
                pencil = (nearArm.held, point)
            } else {
                farArm = IndustrialViews.arm(d, front: false)
                nearArm = IndustrialViews.arm(d, front: true)
            }
            func drawArm(_ d: inout Drawing, _ a: IndustrialViews.Arm, front: Bool) {
                if front {
                    IndustrialPeopleKit.arm(&d, shoulder: a.shoulder, elbow: a.elbow, hand: a.hand, fill: .colour(IndustrialPeopleInk.light), width: 4.4,
                                            cuff: IndustrialPeopleInk.shadeLight)
                } else {
                    IndustrialPeopleKit.arm(&d, shoulder: a.shoulder, elbow: a.elbow, hand: a.hand, fill: .colour(IndustrialPeopleInk.shadeLight), width: 4.4)
                }
            }
            func drawBook(_ d: inout Drawing) {
                guard let book = notebook else { return }
                let c = IndustrialViews.screen(d, book)
                if IndustrialViews.seesFront(d) {
                    // The covers' backs toward us, open in a shallow V.
                    let k = d.view == .front ? 1 : 0.8
                    d.svg.polygon([c + P(-7 * k, -4), c + P(0, -3), c + P(7 * k, -4), c + P(7.4 * k, 1.4), c + P(0, 2.4), c + P(-7.4 * k, 1.4)],
                                  fill: .colour(IndustrialPeopleInk.black), stroke: .colour(Ink.line), width: 0.9)
                    d.svg.line([c + P(0, -3), c + P(0, 2.4)], stroke: .colour(IndustrialPeopleInk.blackSheen), width: 0.7)
                } else {
                    IndustrialPeopleProps.notebook(&d.svg, at: c, degrees: 0, written: 0.72)
                }
            }
            func drawPencil(_ d: inout Drawing) {
                guard let pencil else { return }
                IndustrialViews.prop(&d, at: IndustrialViews.screen(d, pencil.hand), degrees: Self.pencilDegrees) { svg, at, degrees in
                    IndustrialPeopleProps.pencil(&svg, at: at, degrees: degrees, length: Self.pencilLength)
                }
            }
            let front = IndustrialViews.seesFront(d)
            if !front { drawBook(&d); drawPencil(&d) }
            for (isFront, a) in [(false, farArm), (true, nearArm)] where a.behind {
                drawArm(&d, a, front: isFront)
                if pose == .working && !isFront { d.hand(a.hand) }
            }
            IndustrialViews.trousers(&d, colour: IndustrialPeopleInk.green, shade: IndustrialPeopleInk.darkGreen)
            Self.coatInView(&d, sway: sway)
            if pose != .working {
                // The notebook under his far arm, and the flask held by its neck in the near hand.
                let under = IndustrialPoint(-1.4, -33.8 - d.rig.lift * 0.6, -10.6)
                let bookBehind = IndustrialViews.depth(d, under) < -3
                if !bookBehind {
                    IndustrialPeopleProps.shutNotebook(&d.svg, at: IndustrialViews.screen(d, under), degrees: d.view == .front || d.view == .back ? 0 : 8,
                                                       width: d.view == .front || d.view == .back ? 3.4 : 7.6)
                }
            }
            if front { drawBook(&d) }
            for (isFront, a) in [(false, farArm), (true, nearArm)] where !a.behind {
                drawArm(&d, a, front: isFront)
                if pose == .working && !isFront { d.hand(a.hand + P(-0.4, -0.4)) }
            }
            if pose != .working {
                let hand = nearArm.hand
                let swing = pose == .walking ? 4 * IndustrialPeopleKit.wave(frame, 0.15, times: 2) : 1.2 * IndustrialPeopleKit.wave(frame)
                d.svg.group(turned: swing * IndustrialViews.ahead(d), about: hand) { svg in
                    IndustrialPeopleProps.conicalFlask(&svg, base: hand + P(0, Self.flaskHeight - 1.6), height: Self.flaskHeight, boil: nil)
                }
                d.hand(hand)
            }
            if front { drawPencil(&d); if let pencil { d.hand(IndustrialViews.screen(d, pencil.hand)) } }
            Self.headInView(&d)
        }
        if nearer { d.svg.raw(ground.body) }
    }

    /// The laboratory coat to the knee in a view other than the side: open at
    /// the chest on the waistcoat, the shirt, the winged collar and the bow tie
    /// from the front; from behind, the coat's back and the bow tie's band
    /// round the neck above the collar.
    static func coatInView(_ d: inout Drawing, sway: Double) {
        let ink = Paint.colour(Ink.line), lift = d.rig.lift
        let hemBack = P(-15.4 - sway * 1.4, -8.6), hemFront = P(14.6 - sway * 1.4, -8.6)
        let coat = d.turned([d.up(P(-9.2, -47.6)), d.up(P(9.2, -47.6)), d.up(P(11, -38)), P(12.4, -24), hemFront, hemBack, P(-13.6, -24), d.up(P(-11.4, -38))])
        d.svg.polygon(coat.map { $0 + P(-0.8, 0.8) }, fill: .colour(IndustrialPeopleInk.light))
        func at(_ x: Double, _ y: Double, _ z: Double) -> P { IndustrialViews.screen(d, IndustrialPoint(x, y, z)) }
        if IndustrialViews.seesFront(d) {
            // The shirt's front, the waistcoat of the team's colour in the opening, and its buttons.
            d.svg.polygon([at(9, -47.2 - lift, -4.4), at(9, -47.2 - lift, 4.4), at(10, -40, 4.6), at(10, -40, -4.6)], fill: .colour(Ink.eyeWhite))
            let vest = [at(9.6, -43.4 - lift, -4.8), at(9.6, -43.4 - lift, 4.8), at(10.8, -24.2, 3.4), at(10.8, -24.2, -3.4)]
            d.svg.polygon(vest, fill: .team)
            d.svg.line([vest[0], vest[1]], stroke: ink, width: 0.8)
            var buttons = PathData()
            for i in 0..<4 {
                let p = at(10.2, -40.6 + Double(i) * 3.8, 0)
                buttons.move(p); buttons.line(p + P(0.2, 0.2))
            }
            d.svg.path(buttons, stroke: ink, width: 1.5)
            // The lapels over the opening's edges.
            for z in [-1.0, 1.0] {
                d.svg.polygon([at(9, -47.4 - lift, 4.6 * z), at(9, -47.4 - lift, 6.6 * z), at(10.4, -40, 5.6 * z), at(10.8, -24, 3.4 * z), at(10.8, -24, 2 * z)],
                              fill: .colour(IndustrialPeopleInk.light), stroke: ink, width: 0.9)
            }
            // The breast pocket with two pencils in it, and the coat's buttons below the opening.
            for (z, colour) in [(-6.2, IndustrialPeopleInk.green), (-4.4, IndustrialPeopleInk.brick)] {
                let foot = at(8.6, -40.8, z)
                d.svg.line([foot, foot + P(0.3, -3.6)], stroke: ink, width: 1.7)
                d.svg.line([foot, foot + P(0.3, -3.6)], stroke: .colour(colour), width: 0.8)
            }
            d.svg.polygon([at(8.4, -41.6, -7.8), at(8.8, -41.6, -2.8), at(8.8, -37.4, -2.8), at(8.4, -37.4, -7.8)], fill: .colour(IndustrialPeopleInk.light),
                          stroke: ink, width: 0.8)
            d.svg.line([at(11, -24, 0), at(13 - sway * 1.4, -8.8, 0)], stroke: ink, width: 0.8)
            for y in [-20.6, -15.4] { d.svg.circle(at(11.4, y, 0.8), 0.7, fill: .colour(IndustrialPeopleInk.paleSoot), stroke: ink, width: 0.5) }
        } else {
            // The seam down the back and the vent below the waist.
            if let top = IndustrialViews.back(d, -46 - lift, 0), let waist = IndustrialViews.back(d, -24, 0) {
                d.svg.line([top, waist], stroke: .colour(IndustrialPeopleInk.shadeLight), width: 1.1)
                d.svg.line([waist, waist + P(-sway, 15)], stroke: ink, width: 0.8)
                d.svg.line([waist + P(-5, 0), waist + P(5, 0)], stroke: .colour(IndustrialPeopleInk.shadeLight), width: 1.4)
            }
        }
        d.svg.polygon(coat, fill: .none, stroke: ink, width: 1.8)
        // The winged collar round the neck, and the bow tie at the throat or its band at the nape.
        d.svg.polygon([P(-5.6, -49 - lift), P(5.6, -49 - lift), P(5.4, -46.2 - lift), P(-5.4, -46.2 - lift)], fill: .colour(Ink.eyeWhite), stroke: ink, width: 0.8)
        if IndustrialViews.seesFront(d), let knot = IndustrialViews.front(d, -45.6 - lift, 0, half: 6.4) {
            d.svg.polygon([knot + P(-3, -1.6), knot + P(-0.6, -0.3), knot + P(-0.6, 0.5), knot + P(-3, 1.8)], fill: .team, stroke: ink, width: 0.7)
            d.svg.polygon([knot + P(3, -1.6), knot + P(0.6, -0.3), knot + P(0.6, 0.5), knot + P(3, 1.8)], fill: .team, stroke: ink, width: 0.7)
            d.svg.circle(knot, 0.9, fill: .team, stroke: ink, width: 0.6)
        }
    }

    /// The head in a view other than the side: the bald crown and its shine,
    /// the ginger fringe round the back with tufts over the ears, the
    /// mutton-chop whiskers and the spectacles where the face shows.
    static func headInView(_ d: inout Drawing) {
        let ginger = Paint.colour(IndustrialPeopleInk.gingerHair), ink = Paint.colour(Ink.line)
        d.head(nose: .button, behind: { d in
            // The tufts standing out over the ears.
            let tuft = "C-13.6,-61.4 -14.2,-58.6 -12.4,-57.4 C-13.8,-56 -13.2,-53.4 -10.8,-53.4"
            switch d.view {
            case .front, .back:
                d.svg.path("M-10.2,-61.6 \(tuft) Z", fill: ginger, stroke: ink, width: 0.9)
                d.svg.raw("<g transform=\"scale(-1,1)\">")
                d.svg.path("M-10.2,-61.6 \(tuft) Z", fill: ginger, stroke: ink, width: 0.9)
                d.svg.raw("</g>")
            case .frontQuarter:
                d.svg.path("M-9.6,-61.6 C-13.4,-61.4 -14,-58.6 -12.2,-57.4 C-13.6,-56 -13,-53.4 -10.6,-53.4 Z", fill: ginger, stroke: ink, width: 0.9)
            case .backQuarter:
                d.svg.path("M9.6,-61.6 C13.4,-61.4 14,-58.6 12.2,-57.4 C13.6,-56 13,-53.4 10.6,-53.4 Z", fill: ginger, stroke: ink, width: 0.9)
            case .side:
                break
            }
        }, hair: { d in
            switch d.view {
            case .front:
                for s in [-1.0, 1.0] { d.svg.polygon([P(10.2 * s, -62.6), P(8.4 * s, -62.6), P(8.6 * s, -56), P(10.4 * s, -55.4)], fill: ginger) }
            case .frontQuarter:
                d.svg.path("M-10.8,-62.6 C-11.8,-58.6 -11.2,-54.6 -9.2,-51.6 L-7.6,-52.6 C-8.8,-55.6 -9,-59 -8.4,-62 Z", fill: ginger)
            case .back:
                d.svg.path("M-10.8,-63 C-11.6,-57.6 -10.4,-53 -8,-50.6 C-3,-49.4 3,-49.4 8,-50.6 C10.4,-53 11.6,-57.6 10.8,-63 C5,-60.6 -5,-60.6 -10.8,-63 Z",
                           fill: ginger)
            case .backQuarter:
                d.svg.path("M-11,-63 C-11.8,-57.6 -10.6,-53 -8.4,-50.8 C-3.6,-49.4 1.6,-49.6 5.8,-51 C7,-55 7.4,-59 7,-62.6 C1,-60.4 -5,-60.6 -11,-63 Z",
                           fill: ginger)
            case .side:
                break
            }
            // The shine on the crown.
            d.svg.path("M-3.6,-66.4 q2.6,-1.6 5.6,-1.2", stroke: .colour("#ffffff"), width: 1, opacity: 0.6)
        }, features: { d in
            guard IndustrialViews.seesFront(d) else { return }
            let (c, far) = IndustrialViews.face(d)
            // Mutton-chop whiskers down each cheek, widening along the jaw; the chin shaven.
            for s in [-1.0, 1.0] {
                let k = s > 0 ? far : 1
                let x0 = c + s * 8.6 * k, x1 = c + s * 3.2 * k
                d.svg.path("M\(num(x0)),-59.6 C\(num(x0 + s * 0.6 * k)),-55 \(num(x0 - s * 0.4 * k)),-51.6 \(num(x1)),-49.4 "
                           + "C\(num(x1 + s * 1.6 * k)),-50.6 \(num(x0 - s * 2.4 * k)),-52.6 \(num(x0 - s * 2.2 * k)),-59.4 Z",
                           fill: ginger, stroke: ink, width: 0.9)
            }
        }, brow: { d in
            d.svg.path("M1.4,-64.8 q3.6,-2.4 7.6,-0.6", stroke: ginger, width: 1.8)
        }, over: { d in
            guard IndustrialViews.seesFront(d) else {
                // The bow tie's band round the nape, above the coat's collar.
                let w = d.view == .back ? 5.6 : 4.8, c = d.view == .back ? 0 : -1.6
                d.svg.polygon([P(c - w, -49.8), P(c + w, -49.8), P(c + w - 0.3, -47.8), P(c - w + 0.3, -47.8)], fill: .team,
                              stroke: ink, width: 0.7)
                return
            }
            // Oval spectacles of steel wire over both eyes, the bridge between them.
            let eyes: [(P, Double)] = d.view == .front ? [(P(-4.3, -60), 1), (P(4.3, -60), 1)] : [(P(-0.7, -60), 0.72), (P(6.7, -60), 1)]
            for (e, k) in eyes {
                d.svg.ellipse(e, 3.6 * k, 3.1, fill: .colour("#ffffff"), opacity: 0.2)
                d.svg.ellipse(e, 3.6 * k, 3.1, fill: .none, stroke: ink, width: 1)
            }
            d.svg.line([eyes[0].0 + P(3.6 * eyes[0].1, -0.4), eyes[1].0 + P(-3.6, -0.4)], stroke: ink, width: 0.9)
            if d.view == .frontQuarter { d.svg.line([P(-4.4, -60.2), P(-8.6, -59.6)], stroke: ink, width: 0.8) }
        })
    }
}
