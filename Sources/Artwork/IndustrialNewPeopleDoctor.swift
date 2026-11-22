// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// MARK: - The doctor

/// A doctor of the nineteenth century: a frock coat of the team's colour to
/// the knee, its sleeves ending in the light cuffs of his shirt, open at the
/// chest on a soot waistcoat, a white collar and a black cravat; soot trousers
/// with a pale stripe and black boots; a stethoscope round his neck; a black
/// top hat with a soot band; grey mutton-chop whiskers and a grey brow; nose C.
/// He carries a Gladstone bag of brown leather with a brass frame and clasp.
/// Standing, he breathes and blinks, the bag in his hand; walking, the bag
/// swings with his stride; working, he heals: standing over the open bag, the
/// patient before him, he winds a roll of bandage round the patient's wound,
/// its loose end swinging below it, and motes of the light rise where the
/// bandage goes on. He does not attack, so he has no fighting pose.
struct IndustrialNewPeopleDoctor: PersonLook {
    /// The bag's length, end to end, and its depth from side to side.
    static let bagLength = 11.0, bagDepth = 5.6
    /// Where the open bag stands on the ground whilst he heals: its middle, in the picture.
    static let bagAt = 17.0

    // MARK: Healing

    /// One frame of the healing, in the picture: the lean, and where the near
    /// hand holds the roll. He stands over the open bag with the patient
    /// before him and winds the roll round in his near hand, once in the
    /// cycle, down, forward, up and back; his far hand rests at his side.
    struct Step {
        var lean: Double
        var near: P
        /// The turn of the winding, in radians.
        var turn: Double
    }

    /// Where the near hand winds the roll round, and how far.
    static let winding = P(18.4, -39.6), across = 3.2, deep = 3.6

    static func step(_ frame: Int) -> Step {
        let t = 2 * Double.pi * Double(frame) / 12
        return Step(lean: 6 + 1.6 * sin(t), near: winding + P(-across * cos(t), deep * sin(t)), turn: t)
    }

    /// The legs whilst he heals: a short stance toward the patient.
    static let stanceBack = Limb(-9, 6), stanceFront = Limb(11, 8)

    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        switch pose {
        case .standing:
            var r = Moves.standing(frame)
            // The near arm hangs straight with the bag's weight.
            r.frontArm = Limb(3 + 0.3 * r.lift, -3)
            r.mouth = .firm
            return r
        case .walking:
            var r = Moves.walking(frame, stride: 21, kneeLift: 40, armSwing: 22)
            // The bag damps the near arm's swing.
            r.frontArm = Limb(r.frontArm.upper * 0.35 + 2, -4)
            r.mouth = .firm
            return r
        case .working:
            return Self.healing(frame)
        default:
            return nil
        }
    }

    static func healing(_ frame: Int) -> Rig {
        let s = step(frame)
        var r = Rig()
        r.backLeg = stanceBack; r.frontLeg = stanceFront
        r.lean = s.lean
        r.frontArm = IndustrialPeopleKit.reach(front: true, r, to: s.near)
        r.backArm = Limb(-2 - 2 * sin(s.turn), -14)
        r.eyes = frame == 8 ? .closed : .down
        r.headTilt = 5
        r.mouth = .firm
        return r
    }

    /// Motes of the light rising from where the bandage goes on: their places
    /// in the picture, their size and their opacity. Each rises through the
    /// whole cycle, a third of a cycle after the one before, so that the cycle joins.
    static func motes(_ frame: Int) -> [(P, Double, Double)] {
        (0..<3).map { i in
            let t = Double((frame + 4 * i) % 12) / 12
            let p = winding + P(across + 2.4 + Double(i - 1) * 2.6 + 0.9 * sin(t * 2 * .pi + Double(i)), -4 - 16 * t)
            return (p, 2.5 - 0.6 * t, 0.15 + 0.85 * sin(.pi * t))
        }
    }

    // MARK: Drawing

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        if d.view != .side { drawInView(&d, pose, frame); return }
        let sway = pose == .walking ? d.rig.sway : 0
        if pose == .working {
            Self.bag(&d.svg, top: P(Self.bagAt, -8.6), length: Self.bagLength, open: true)
        }
        let step = pose == .working ? Self.step(frame) : nil
        d.figure { d in
            IndustrialPeopleKit.arm(&d, front: false, fill: .team, width: 4, cuff: IndustrialPeopleInk.light)
            IndustrialPeopleKit.trousers(&d, colour: IndustrialPeopleInk.soot, shade: IndustrialPeopleInk.darkSoot, stripe: IndustrialPeopleInk.paleSoot)
            Self.coat(&d, sway: sway)
            switch pose {
            case .standing, .walking:
                let swing = pose == .walking ? -2 * d.rig.sway : 0
                Self.bag(&d.svg, top: d.joints.frontHand + P(swing * 0.3, 3.2), length: Self.bagLength, open: false, swing: swing)
            default:
                if let s = step {
                    Self.bandage(&d.svg, roll: d.joints.frontHand, turn: s.turn)
                    Self.roll(&d.svg, at: d.joints.frontHand)
                }
            }
            IndustrialPeopleKit.arm(&d, front: true, fill: .team, width: 4.2, cuff: IndustrialPeopleInk.light)
            Self.head(&d)
        }
        if pose == .working { Self.drawMotes(&d.svg, frame) }
    }

    static func drawMotes(_ svg: inout SVG, _ frame: Int) {
        for (p, size, opacity) in motes(frame) { mote(&svg, at: p, size: size, opacity: opacity) }
    }

    // MARK: The dress

    /// The frock coat's outline: fitted at the waist, its skirts flaring to the knee and swinging with the stride.
    static func coatOutline(_ sway: Double) -> [P] {
        let s = sway * 1.4
        return [P(-9.6, -47.6), P(9.4, -47.6), P(10.2, -37), P(8.8, -27.6), P(14 - s, -9.4), P(-13.8 - s, -9.8), P(-9.8, -27.6), P(-10.4, -37)]
    }

    /// The frock coat of the team's colour, its skirts to the knee swinging
    /// with the stride; the soot waistcoat, the white collar and the black
    /// cravat in its opening; its buttons, and the stethoscope over it.
    static func coat(_ d: inout Drawing, sway: Double) {
        let s = sway * 1.4
        let outline = coatOutline(sway)
        d.garment(colour: outline.map { $0 + P(-0.7, 0.6) }, outline: outline, fill: .team) { d in
            // The waist seam, and the skirt's fold.
            d.svg.line([P(-11.2, -27.4), P(10, -27.4)], stroke: .colour(Ink.line), width: 0.8, opacity: 0.5)
            d.svg.line([P(2, -26.6), P(2.6 - s, -11)], stroke: .colour(Ink.line), width: 0.8, opacity: 0.3)
        }
        // The soot collar round the neck, the waistcoat in the opening, the lapel faced in soot, and the buttons.
        d.svg.polygon([P(-7, -49.4), P(4.6, -49.2), P(4.2, -46.6), P(-7.4, -46.8)].map(d.up), fill: .colour(IndustrialPeopleInk.darkSoot),
                      stroke: .colour(Ink.line), width: 0.8)
        d.svg.polygon([P(4.4, -47.4), P(9.4, -47.4), P(10.4, -37.4), P(8.4, -36.2)].map(d.up), fill: .colour(IndustrialPeopleInk.soot),
                      stroke: .colour(Ink.line), width: 0.8)
        d.svg.polygon([P(3, -47.8), P(4.8, -47.8), P(8.8, -36.4), P(7.4, -35.4)].map(d.up), fill: .colour(IndustrialPeopleInk.darkSoot),
                      stroke: .colour(Ink.line), width: 0.8)
        for y in [-33.0, -29.6] { d.svg.circle(d.up(P(10, y)), 0.7, fill: .colour(IndustrialPeopleInk.darkSoot), stroke: .colour(Ink.line), width: 0.4) }
        // The collar and the cravat at the throat.
        d.svg.polygon([P(4.6, -49), P(9.4, -48.6), P(9.2, -46.4), P(5.6, -46.6)].map(d.up), fill: .colour(IndustrialPeopleInk.light),
                      stroke: .colour(Ink.line), width: 0.7)
        d.svg.circle(d.up(P(8.4, -46.2)), 1.3, fill: .colour(IndustrialPeopleInk.black), stroke: .colour(Ink.line), width: 0.5)
        d.svg.polygon([P(7.8, -45.8), P(9.4, -45.6), P(9.8, -42.4), P(8.2, -42.8)].map(d.up), fill: .colour(IndustrialPeopleInk.black))
        // The stethoscope: its tube round the back of the neck and down the chest to the bell.
        var tube = PathData()
        tube.move(d.up(P(1.6, -48.6))); tube.quad(d.up(P(4, -42)), d.up(P(6.6, -38.4)))
        d.svg.path(tube, stroke: .colour(Ink.line), width: 1.5)
        d.svg.path(tube, stroke: .colour(IndustrialPeopleInk.blackSheen), width: 0.6)
        d.svg.circle(d.up(P(7, -37.6)), 1.3, fill: .colour(IndustrialPeopleInk.ironLight), stroke: .colour(Ink.line), width: 0.6)
    }

    /// The head: grey mutton-chop whiskers and grey hair at the nape, a grey
    /// brow, nose C, and the top hat.
    static func head(_ d: inout Drawing) {
        let grey = Paint.colour(IndustrialPeopleInk.greyHair)
        d.head(nose: .hook, hair: { d in
            d.svg.path("M-11.4,-61.6 C-12.8,-57 -11.8,-52.6 -8.6,-50.8 C-9.2,-53 -8.8,-55 -7.8,-56.6 C-9,-58 -9,-60 -8,-62 Z", fill: grey)
            // The whiskers, down the cheek to the jaw.
            d.svg.path("M-6.6,-63 C-6.2,-58.4 -4.8,-53.6 -1.4,-50.4 C0.4,-49.6 1.8,-50.4 1.6,-52.2 C-0.4,-54.4 -2.4,-58.4 -3.2,-62.8 Z", fill: grey)
        }, features: { d in
            d.svg.path("M-1.4,-50.4 C0.4,-49.6 1.8,-50.4 1.6,-52.2", stroke: .colour(Ink.line), width: 0.6, opacity: 0.6)
        }, brow: { d in
            d.svg.path("M1.4,-63.8 q3.6,-1.8 7.6,0", stroke: grey, width: 2.2)
            d.svg.path("M1.4,-63.8 q3.6,-1.8 7.6,0", stroke: .colour(Ink.line), width: 0.5, opacity: 0.7)
        }, over: { d in
            topHat(&d.svg, sheen: -4.6)
        })
    }

    /// The top hat, a cylinder that shows the same outline from every side:
    /// its crown of black, the soot band at its foot, the curled brim, and a
    /// sheen down the crown at `sheen` across it.
    static func topHat(_ svg: inout SVG, sheen: Double, centre: Double = 0.4) {
        let c = centre
        BronzePeopleProps.shape(&svg, [P(c - 8.4, -65.2), P(c - 8.9, -78.6), P(c + 8.9, -78.6), P(c + 8.4, -65.2)],
                                fill: .colour(IndustrialPeopleInk.black), width: 1.3)
        svg.polygon([P(c - 8.4, -65.4), P(c - 8.6, -68.4), P(c + 8.6, -68.4), P(c + 8.4, -65.4)], fill: .colour(IndustrialPeopleInk.soot))
        svg.line([P(c - 8.6, -68.4), P(c + 8.6, -68.4)], stroke: .colour(Ink.line), width: 0.6)
        svg.line([P(c + sheen, -77.4), P(c + sheen * 0.96, -69.6)], stroke: .colour(IndustrialPeopleInk.blackSheen), width: 1.4)
        BronzePeopleProps.shape(&svg, [P(c - 13.2, -63.4), P(c - 9.6, -65.6), P(c + 9.6, -65.6), P(c + 13.2, -63.4), P(c + 12.6, -62.8),
                                       P(c + 9.2, -64.2), P(c - 9.2, -64.2), P(c - 12.6, -62.8)],
                                fill: .colour(IndustrialPeopleInk.black), width: 1)
    }

    // MARK: The props

    /// The Gladstone bag of brown leather, `length` long as it shows, its
    /// top's middle at `top`: a brass frame along the top with a clasp, a
    /// strap round it, the handle arched over the frame; open, its mouth
    /// gapes on a medicine bottle and a roll of bandage. `swing` tips it.
    static func bag(_ svg: inout SVG, top: P, length: Double, open: Bool, swing: Double = 0) {
        let h = length / 2, ink = Paint.colour(Ink.line)
        svg.group(turned: swing, about: top + P(0, -3.2)) { svg in
            if open {
                // The mouth, and what shows in it.
                svg.ellipse(top + P(0, -0.2), h - 0.6, 2, fill: ink)
                svg.polygon([top + P(1.2, -4.4), top + P(3.4, -4.4), top + P(3.4, 0), top + P(1.2, 0)], fill: .colour(IndustrialNewPeopleInk.bottle),
                            stroke: ink, width: 0.6)
                svg.polygon([top + P(1.6, -5.8), top + P(3, -5.8), top + P(3, -4.4), top + P(1.6, -4.4)], fill: .colour(IndustrialPeopleInk.paleWood))
                svg.circle(top + P(-2.4, -0.8), 1.8, fill: .colour(IndustrialNewPeopleInk.linen), stroke: ink, width: 0.6)
                svg.circle(top + P(-2.4, -0.8), 0.6, fill: .colour(IndustrialNewPeopleInk.linenShade))
            }
            let body = [top + P(-h + 0.8, 0), top + P(h - 0.8, 0), top + P(h + 0.6, 6.8), top + P(h - 0.4, 8.4), top + P(-h + 0.4, 8.4),
                        top + P(-h - 0.6, 6.8)]
            BronzePeopleProps.shape(&svg, body, fill: .colour(IndustrialPeopleInk.leather), width: 1)
            // The strap round the bag, and the stitched seam at its foot.
            for x in [-h * 0.45, h * 0.45] {
                svg.line([top + P(x, 0.4), top + P(x * 1.06, 8.2)], stroke: .colour(IndustrialPeopleInk.darkLeather), width: 1.1)
            }
            svg.line([top + P(-h + 0.6, 6.6), top + P(h - 0.4, 6.6)], stroke: .colour(IndustrialPeopleInk.paleLeather), width: 0.5, opacity: 0.8)
            // The brass frame and the clasp.
            if open {
                svg.line([top + P(-h + 0.6, 0.2), top + P(0, -1.8), top + P(h - 0.6, 0.2)], stroke: .colour(IndustrialPeopleInk.brass), width: 1)
            } else {
                svg.line([top + P(-h + 0.8, 0.2), top + P(h - 0.8, 0.2)], stroke: ink, width: 2)
                svg.line([top + P(-h + 0.9, 0.2), top + P(h - 0.9, 0.2)], stroke: .colour(IndustrialPeopleInk.brass), width: 1)
                svg.polygon([top + P(-0.9, -0.4), top + P(0.9, -0.4), top + P(0.9, 1.8), top + P(-0.9, 1.8)], fill: .colour(IndustrialPeopleInk.brass),
                            stroke: ink, width: 0.5)
                // The handle.
                var handle = PathData()
                handle.move(top + P(-2.6, 0)); handle.cubic(top + P(-2.6, -3.6), top + P(2.6, -3.6), top + P(2.6, 0))
                svg.path(handle, stroke: ink, width: 2)
                svg.path(handle, stroke: .colour(IndustrialPeopleInk.darkLeather), width: 1)
            }
        }
    }

    /// The roll of bandage in the hand.
    static func roll(_ svg: inout SVG, at hand: P) {
        svg.circle(hand + P(0.6, -1.4), 2.2, fill: .colour(IndustrialNewPeopleInk.linen), stroke: .colour(Ink.line), width: 0.8)
        svg.path("M\(num(hand.x + 0.6)),\(num(hand.y - 1.4)) m-0.9,0 a0.9,0.9 0 1 1 1.8,0", stroke: .colour(IndustrialNewPeopleInk.linenShade), width: 0.6)
    }

    /// The bandage's loose end, unrolled from the roll in the hand and
    /// hanging below it, swinging as the roll goes round (`turn`, in radians).
    static func bandage(_ svg: inout SVG, roll a: P, turn: Double) {
        let b = a + P(1.4 + 2.4 * sin(turn + 1.2), 10.4 - 1.2 * cos(turn))
        var strip = PathData()
        strip.move(a + P(0.6, -0.4)); strip.quad(a + P(2.4 + 1.6 * cos(turn), 5), b)
        svg.path(strip, stroke: .colour(Ink.line), width: 3.2)
        svg.path(strip, stroke: .colour(IndustrialNewPeopleInk.linen), width: 2)
    }

    /// A mote of the light: a small star of four points.
    static func mote(_ svg: inout SVG, at c: P, size r: Double, opacity: Double) {
        var points: [P] = []
        for i in 0..<8 {
            let radius = i % 2 == 0 ? r : r * 0.36
            points.append(c + P.direction(Double(i) * 45) * radius)
        }
        svg.polygon(points, fill: .colour(IndustrialPeopleInk.light), stroke: .colour(Ink.line), width: 0.7, opacity: opacity)
    }
}

// MARK: - The doctor in the other views

extension IndustrialNewPeopleDoctor {
    /// A point of the picture as the side view has it (`world`, `z` across
    /// the figure) in the figure's space for this view: where its screen place,
    /// once the figure leans and bobs, is the point's own place in the picture,
    /// so that a hand drawn there reaches a thing standing on the ground.
    static func inFigure(_ d: Drawing, _ world: P, z: Double) -> IndustrialPoint {
        let r = d.yaw * .pi / 180, c = cos(r), s = sin(r)
        let local = AlchemyViews.body(d, P(world.x * c - z * s, world.y))
        let depth = world.x * s + z * c
        return IndustrialPoint(local.x * c + depth * s, local.y, -local.x * s + depth * c)
    }

    /// A point of the picture as the side view has it, `z` across, where it falls in this view.
    static func picture(_ d: Drawing, _ world: P, z: Double) -> (point: P, depth: Double) {
        let p = d.project(world.x, world.y, z)
        return (p.point, p.depth)
    }

    /// The bag's length as it shows in this view.
    static func bagShown(_ d: Drawing) -> Double {
        let r = d.yaw * .pi / 180
        return bagLength * abs(cos(r)) + bagDepth * abs(sin(r))
    }

    /// A frame in a view other than the side: the same dress, the bag in hand
    /// or open on the ground, and the healing toward the patient before him.
    func drawInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let sway = pose == .walking ? d.rig.sway : 0
        let shown = Self.bagShown(d)
        var ground = SVG(layer: d.svg.layer)
        var bagNearer = false
        if pose == .working {
            let at = Self.picture(d, P(Self.bagAt, -8.6), z: Drawing.shoulderSpread)
            bagNearer = at.depth > 0
            Self.bag(&ground, top: at.point, length: shown, open: true)
            if !bagNearer { d.svg.raw(ground.body) }
        }
        let step = pose == .working ? Self.step(frame) : nil
        d.figure { d in
            let far: IndustrialViews.Arm, near: IndustrialViews.Arm
            if let s = step {
                near = IndustrialViews.reach(d, front: true, to: Self.inFigure(d, s.near, z: Drawing.shoulderSpread - 2))
                far = IndustrialViews.arm(d, front: false)
            } else {
                near = IndustrialViews.arm(d, front: true); far = IndustrialViews.arm(d, front: false)
            }
            func drawArm(_ d: inout Drawing, _ a: IndustrialViews.Arm, front: Bool) {
                if front {
                    switch pose {
                    case .standing, .walking:
                        let swing = pose == .walking ? -2 * d.rig.sway * IndustrialViews.ahead(d) : 0
                        Self.bag(&d.svg, top: a.hand + P(swing * 0.3, 3.2), length: shown, open: false, swing: swing)
                    default:
                        Self.bandage(&d.svg, roll: a.hand, turn: step?.turn ?? 0)
                        Self.roll(&d.svg, at: a.hand)
                    }
                }
                IndustrialPeopleKit.arm(&d, shoulder: a.shoulder, elbow: a.elbow, hand: a.hand, fill: .team, width: front ? 4.2 : 4,
                                        cuff: IndustrialPeopleInk.light)
            }
            for (front, a) in [(false, far), (true, near)] where a.behind { drawArm(&d, a, front: front) }
            IndustrialViews.trousers(&d, colour: IndustrialPeopleInk.soot, shade: IndustrialPeopleInk.darkSoot, stripe: IndustrialPeopleInk.paleSoot)
            Self.coatInView(&d, sway: sway)
            for (front, a) in [(false, far), (true, near)] where !a.behind { drawArm(&d, a, front: front) }
            Self.headInView(&d)
        }
        if bagNearer { d.svg.raw(ground.body) }
        if pose == .working {
            // The motes rise before or behind him with the bandage.
            let r = d.yaw * .pi / 180
            for (p, size, opacity) in Self.motes(frame) {
                Self.mote(&d.svg, at: P(p.x * cos(r) - (Drawing.shoulderSpread - 2) * sin(r), p.y), size: size, opacity: opacity)
            }
        }
    }

    /// The frock coat turned by the view: its buttons, the opening on the
    /// waistcoat with the collar and cravat, and the stethoscope where the
    /// front shows; the seam and the vent of the skirts behind.
    static func coatInView(_ d: inout Drawing, sway: Double) {
        let ink = Paint.colour(Ink.line)
        let s = sway * 1.4
        let outline = coatOutline(sway)
        d.garment(colour: outline.map { $0 + P(-0.7, 0.6) }, outline: outline, fill: .team)
        let lift = d.rig.lift
        // The soot collar round the neck.
        d.svg.polygon([P(-6.6, -49.6 - lift), P(6.6, -49.6 - lift), P(6.2, -46.6 - lift), P(-6.2, -46.6 - lift)], fill: .colour(IndustrialPeopleInk.darkSoot),
                      stroke: ink, width: 0.8)
        if IndustrialViews.seesFront(d) {
            // The opening: the waistcoat in a V from the collar to the chest.
            if let l = IndustrialViews.front(d, -47.4 - lift, -4.4), let r = IndustrialViews.front(d, -47.4 - lift, 4.4),
               let v = IndustrialViews.front(d, -36.4 - lift * 0.7, 0) {
                d.svg.polygon([l + P(-1.6, 0), r + P(1.6, 0), v + P(0, 1.6)], fill: .colour(IndustrialPeopleInk.darkSoot), stroke: ink, width: 0.9)
                d.svg.polygon([l, r, v], fill: .colour(IndustrialPeopleInk.soot), stroke: ink, width: 0.7)
                if let cl = IndustrialViews.front(d, -48.8 - lift, -3.4), let cr = IndustrialViews.front(d, -48.8 - lift, 3.4),
                   let cb = IndustrialViews.front(d, -46 - lift, 0) {
                    d.svg.polygon([cl, cr, cb], fill: .colour(IndustrialPeopleInk.light), stroke: ink, width: 0.6)
                    d.svg.circle(cb + P(0, 0.2), 1.3, fill: .colour(IndustrialPeopleInk.black), stroke: ink, width: 0.5)
                    d.svg.polygon([cb + P(-0.8, 0.6), cb + P(0.8, 0.6), cb + P(0.6, 4), cb + P(-0.6, 4)], fill: .colour(IndustrialPeopleInk.black))
                }
            }
            for y in [-33.0, -29.6] {
                if let b = IndustrialViews.front(d, y - lift * 0.4, 0.6) { d.svg.circle(b, 0.7, fill: .colour(IndustrialPeopleInk.darkSoot), stroke: ink, width: 0.4) }
            }
            // The stethoscope round the neck, its two tubes meeting at the bell on the chest.
            if let bell = IndustrialViews.front(d, -37.6 - lift * 0.8, 3) {
                for z in [-5.0, 5.0] {
                    if let top = IndustrialViews.front(d, -48.4 - lift, z) {
                        var tube = PathData()
                        tube.move(top); tube.quad(P((top.x + bell.x) / 2, bell.y - 2), bell)
                        d.svg.path(tube, stroke: ink, width: 1.4)
                    }
                }
                d.svg.circle(bell, 1.3, fill: .colour(IndustrialPeopleInk.ironLight), stroke: ink, width: 0.6)
            }
        } else {
            // The tube behind the neck, the seam at the waist and the vent between the skirts.
            d.svg.path("M-5.6,\(num(-48.6 - lift)) q5.6,2.4 11.2,0", stroke: ink, width: 1.4)
            if let seam = IndustrialViews.back(d, -27.4, 0), let hem = IndustrialViews.back(d, -10, 0) {
                d.svg.line([seam, hem], stroke: ink, width: 0.9, opacity: 0.6)
                for x in [-2.2, 2.2] { d.svg.circle(seam + P(x, -0.2), 0.7, fill: .colour(IndustrialPeopleInk.darkSoot), stroke: ink, width: 0.4) }
            }
        }
    }

    /// The head in a view other than the side: the mutton-chop whiskers and
    /// the hair at the nape, the brow, and the top hat.
    static func headInView(_ d: inout Drawing) {
        let grey = Paint.colour(IndustrialPeopleInk.greyHair)
        d.head(nose: .hook, hair: { d in
            switch d.view {
            case .front:
                for s in [-1.0, 1.0] {
                    d.svg.polygon([P(9.8 * s, -63), P(7 * s, -63), P(6.2 * s, -55), P(4.4 * s, -50.4), P(7.4 * s, -50), P(10.4 * s, -55)], fill: grey)
                }
            case .frontQuarter:
                d.svg.path("M-11.2,-61.4 C-12.4,-57 -11.6,-53 -9.4,-51.4 L-9.6,-60.6 Z", fill: grey)
                d.svg.polygon([P(-5.6, -63), P(-3, -63), P(-2.2, -55), P(-0.6, -50.6), P(-3.8, -50.2), P(-6, -55.4)], fill: grey)
                d.svg.polygon([P(9.4, -62.6), P(10.6, -60), P(10.2, -54), P(8.6, -55.6)], fill: grey)
            case .back:
                d.svg.path(IndustrialViews.backHair(d, rim: -63.4), fill: grey)
            case .backQuarter:
                d.svg.path(IndustrialViews.backHair(d, rim: -63.4, right: 5.4), fill: grey)
                d.svg.polygon([P(7.6, -62.6), P(10.2, -62), P(9.6, -53.6), P(6.8, -54.8)], fill: grey)
            case .side:
                break
            }
        }, brow: { d in
            d.svg.path("M1.4,-63.8 q3.6,-1.8 7.6,0", stroke: grey, width: 2.2)
            d.svg.path("M1.4,-63.8 q3.6,-1.8 7.6,0", stroke: .colour(Ink.line), width: 0.5, opacity: 0.7)
        }, over: { d in
            topHat(&d.svg, sheen: -4.6 + 4.4 * (1 - IndustrialViews.ahead(d)), centre: 0)
        })
    }
}
