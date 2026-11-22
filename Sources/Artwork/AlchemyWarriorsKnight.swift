// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// MARK: - The knight

/// A knight: a rider in plate armour on the shared figure, seated on the
/// horseman's horse (`BronzePeopleSteed`, drawn as `IronWarriorsHorseman` draws
/// it and moving with its gaits), here a dark bay destrier barded for war: a
/// steel chanfron over its face and a caparison of the team's colour hanging
/// to its knees, bordered and strewn with rosettes in the light, its hem cut in
/// scallops. The rider wears a closed helm with a pointed visor, a sight slit
/// and a gilt pivot, and a plume of wine and light; a surcoat of the team's
/// colour with a chevron and a sun in the light over plate arms and legs, gilt
/// at their edges; a gorget, layered pauldrons and spurs. Standing, the horse
/// breathes and the knight rests his lance upright, its butt by the stirrup;
/// walking, he charges at the trot with the lance couched under his arm, its
/// point lowered at the foe; fighting, at close quarters, the horse paws the
/// ground whilst he raises his sword and cuts down past the horse's shoulder.
/// The origin is on the ground at the centre of the horse's hooves.
struct AlchemyWarriorsKnight: PersonLook {
    static let canvas = Canvas(minX: -60, minY: -156, width: 162, height: 162, pixelsPerUnit: Canvas.person.pixelsPerUnit)

    /// The horse stands as the horseman's does (`IronWarriorsHorseman`).
    static let horseOrigin = IronWarriorsHorseman.horseOrigin
    static let horseScale = IronWarriorsHorseman.horseScale
    static let seatShift = IronWarriorsHorseman.seatShift

    /// The lance's length, and where along it the hand holds it couched and at rest.
    static let lance = 86.0
    static let couchedBehind = 18.0, restingBehind = 38.0

    // MARK: The rider

    /// One frame of the sword's cut: the hand and the blade's direction.
    static let cut: [(hand: P, degrees: Double)] = [
        (P(14, -40), 120), (P(14, -47), 150), (P(13, -53), 172), (P(12, -57), 188), (P(11.4, -58), 196), (P(12, -57.6), 192),
        (P(17, -53), 150), (P(20.6, -45), 98), (P(21.6, -39.4), 64), (P(19.4, -38.6), 72), (P(17, -39.6), 92), (P(15.2, -40), 108),
    ]

    /// Where the hand holds the couched lance, and the lance's direction in the body's units.
    static let couch = P(14, -35)
    static let couchDegrees = 78.0

    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        var r = Moves.standing(pose == .standing ? frame : 0)
        r.backLeg = Limb(-4, 4); r.frontLeg = Limb(34, 50)
        r.mouth = .hidden
        switch pose {
        case .standing:
            r.lean = 1
            r.frontArm = BronzePeopleKit.reach(IronWarriorsKit.frontShoulder(r), P(15, -38 - r.lift))
        case .walking:
            r.lean = 6
            r.lift = 0
            r.frontArm = BronzePeopleKit.reach(IronWarriorsKit.frontShoulder(r), Self.couch + P(0, 0.5 * BronzePeopleKit.wave(frame, times: 2)))
        case .fighting:
            let s = Self.cut[frame]
            r.lift = 0
            r.lean = [2, 0, -2, -4, -5, -5, 1, 8, 10, 7, 4, 3][frame]
            r.frontArm = BronzePeopleKit.reach(IronWarriorsKit.frontShoulder(r), s.hand, elbowUp: s.hand.y < -50)
            r.eyes = frame == 8 ? .wide : .open
        default:
            return nil
        }
        r.backArm = BronzePeopleKit.reach(IronWarriorsKit.backShoulder(r), P(9, -33))
        return r
    }

    // MARK: Drawing

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        if d.view != .side { drawInView(&d, pose, frame); return }
        let horse = BronzePeopleSteed(at: Self.horseOrigin, pose: IronWarriorsHorseman.horse(pose, frame),
                                      coat: AlchemyWarriorsInk.coat, shade: AlchemyWarriorsInk.coatShade)
        let k = Self.horseScale
        d.svg.ellipse(P(0, 0.2), 38, 4.2, fill: .colour("#000000"), opacity: 0.13)
        d.svg.raw("<g transform=\"scale(\(num(k)))\">")
        horse.draw(&d.svg, near: true)
        let flutter: Double
        switch pose {
        case .walking: flutter = 1 + 0.6 * BronzePeopleKit.wave(frame, times: 2)
        case .fighting: flutter = 0.3 * sin(.pi * Double(frame) / 12)
        default: flutter = 0.1 * BronzePeopleKit.wave(frame)
        }
        Self.caparison(&d.svg, horse, flutter: flutter, frame: frame)
        Self.chanfron(&d.svg, horse)
        Self.saddle(&d.svg, horse)
        d.svg.raw("</g>")
        // The rider rises from the saddle with each stride of the trot.
        let rise = pose == .walking ? 1.1 + 1.1 * sin(4 * .pi * Double(frame) / 12 + 0.6) : 0
        let seat = horse.body(P(-1.6, -48.4) + Self.seatShift) * k + P(0, -rise)
        Self.rider(&d, pose, frame, at: seat - P(0, -15), bit: horse.mouth * k, flutter: flutter)
        // Dust kicked up by the hooves as they strike the ground.
        if pose == .walking && frame % 6 == 1 {
            BronzePeopleProps.dust(&d.svg, at: horse.hoof(frame < 6 ? .hind : .fore) * k + P(-5, -1), size: 0.8, opacity: 0.45)
        }
        if pose == .fighting && frame == 11 {
            d.burst(at: horse.hoof(.fore) * k + P(1, -1), from: 100, to: 170, size: 0.9)
        }
    }

    /// The caparison: a cloth of the team's colour over the horse's body from
    /// the chest to the rump, hanging below the belly to a scalloped hem,
    /// with folds, a border and rosettes in the light. Drawn over the legs'
    /// tops, which it hides, and blown back by `flutter`.
    static func caparison(_ svg: inout SVG, _ horse: BronzePeopleSteed, flutter: Double, frame: Int) {
        func at(_ p: P) -> P { horse.body(p) }
        let blow = P(-flutter * 1.6, -flutter * 0.4)
        let top = [P(-21.6, -41), P(-19.8, -45.8), P(-12, -48.6), P(-2, -47.6), P(6, -47.8), P(12.6, -48.8), P(19.4, -46.6), P(23.6, -41.4)]
        let frontHem = P(24.6, -21.8) + blow, backHem = P(-23.6, -20.4) + blow * 1.4
        let scallops = 9
        func hemPoint(_ i: Int) -> P {
            let t = Double(i) / Double(scallops)
            let ripple = flutter * 0.7 * sin(Double(i) * 1.9 + Double(frame) * 1.05)
            return frontHem + (backHem - frontHem) * t + P(0, ripple)
        }
        func outline(_ o: P) -> PathData {
            var p = PathData()
            p.move(at(top[0]) + o)
            for q in top.dropFirst() { p.line(at(q) + o) }
            p.quad(at(P(25.4, -33) + blow * 0.5) + o, at(frontHem) + o)
            for i in 0..<scallops {
                let a = hemPoint(i), b = hemPoint(i + 1)
                p.quad(at((a + b) * 0.5 + P(0, 3)) + o, at(b) + o)
            }
            p.quad(at(P(-24.4, -32) + blow * 0.7) + o, at(top[0]) + o)
            p.close()
            return p
        }
        svg.path(outline(P(-0.7, 0.6)), fill: .team)
        // The folds, falling from the back to the hem.
        var folds = PathData()
        for (x, i) in [(-15.0, 2), (-5.0, 4), (6.0, 6), (16.0, 8)] {
            let h = hemPoint(scallops - i) + P(0, 1)
            folds.move(at(P(x, -44.6))); folds.quad(at(P(x + 0.6, -32)), at(h + P(0, -0.6)))
        }
        svg.path(folds, stroke: .colour(Ink.line), width: 0.9, opacity: 0.22)
        // The border, in the light, above the hem.
        var border = PathData()
        for i in 0...scallops {
            let p = at(hemPoint(i) + P(0, -2.6))
            if i == 0 { border.move(p) } else { border.line(p) }
        }
        svg.path(border, stroke: .colour(AlchemyWarriorsInk.light), width: 1.2)
        // Rosettes strewn over the cloth.
        let light = Paint.colour(AlchemyWarriorsInk.light)
        for (i, c) in [P(-15, -38.6), P(-4, -39.4), P(7, -39.8), P(17.6, -38.4), P(-9.6, -29.6), P(1.6, -30), P(12.6, -29.8)].enumerated() {
            let centre = at(c + blow * (Double(i % 4) * 0.12))
            for angle in [0.0, 90, 180, 270] {
                svg.circle(centre + P.direction(angle) * 1.3, 0.75, fill: light)
            }
            svg.circle(centre, 0.55, fill: .colour(AlchemyWarriorsInk.teal))
        }
        svg.path(outline(P(0, 0)), stroke: .colour(Ink.line), width: 1.4)
    }

    /// A chanfron: a plate of steel down the horse's face from the poll to the
    /// nose, ridged, with a gilt boss and a cup round the eye.
    static func chanfron(_ svg: inout SVG, _ horse: BronzePeopleSteed) {
        func at(_ p: P) -> P { horse.head(p) }
        let plate = [P(22, -67.8), P(26.4, -69.8), P(32.6, -66.4), P(38.6, -60.8), P(38.2, -58.2), P(33.6, -59.8), P(28.4, -60.8), P(24.4, -62.4), P(22.4, -64.6)]
        AlchemyWarriorsKit.shape(&svg, plate.map(at), fill: .colour(AlchemyWarriorsInk.steel), width: 1.1)
        svg.line([at(P(24.4, -67.6)), at(P(31.8, -64.4)), at(P(37.4, -60.4))], stroke: .colour(AlchemyWarriorsInk.steelLight), width: 0.9)
        svg.line([at(P(23.4, -64.6)), at(P(28.6, -62.2)), at(P(34, -60.6))], stroke: .colour(AlchemyWarriorsInk.steelDark), width: 0.6)
        // The eye's cup, with the eye in it.
        let eye = at(P(28.8, -63.4))
        svg.circle(eye, 2.5, fill: .colour(AlchemyWarriorsInk.steel), stroke: .colour(Ink.line), width: 0.9)
        if horse.pose.blink {
            svg.line([eye + P(-1.3, 0), eye + P(1.3, 0)], stroke: .colour(Ink.line), width: 0.9)
        } else {
            svg.circle(eye, 1.4, fill: .colour(Ink.eyeWhite), stroke: .colour(Ink.line), width: 0.6)
            svg.circle(eye + P(0.4, 0.1), 0.7, fill: .colour(Ink.line))
        }
        // The boss on the brow.
        svg.circle(at(P(33.4, -63.6)), 1.2, fill: .colour(AlchemyWarriorsInk.gilt), stroke: .colour(Ink.line), width: 0.6)
    }

    /// The war saddle: a high cantle behind the seat and a high bow before it,
    /// studded in gilt, on its girth.
    static func saddle(_ svg: inout SVG, _ horse: BronzePeopleSteed) {
        func at(_ p: P) -> P { horse.body(p + seatShift) }
        let seat = [P(-10.6, -47.6), P(-11, -55), P(-8.4, -55.4), P(-6.6, -50.2), P(3.2, -50.4), P(5.2, -54.8), P(7.6, -54), P(7.2, -48.6),
                    P(6.4, -46.4), P(-9.2, -45.6)]
        AlchemyWarriorsKit.shape(&svg, seat.map(at), fill: .colour(AlchemyWarriorsInk.leather), width: 1.2)
        for p in [P(-9.6, -50.6), P(-9.6, -47.4), P(6.2, -50.2), P(5.8, -47.4)] {
            svg.circle(at(p), 0.6, fill: .colour(AlchemyWarriorsInk.gilt))
        }
    }

    /// The rider, his figure's origin at `at`: the rein arm, the scabbard, the
    /// near leg in its stirrup, the surcoat, the lance or the sword, the sword
    /// arm and the helm.
    static func rider(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int, at: P, bit: P, flutter: Double) {
        let lean = d.rig.lean
        func world(_ p: P) -> P { at + p.rotated(lean, about: Drawing.hips) }
        d.svg.raw("<g transform=\"translate(\(num(at.x)),\(num(at.y))) rotate(\(num(lean)) \(num(Drawing.hips.x)) \(num(Drawing.hips.y)))\">")
        let j = d.joints
        // The rein arm, behind the body, in plate a shade darker.
        AlchemyWarriorsKit.arm(&d.svg, shoulder: j.backShoulder, elbow: j.backElbow, hand: j.backHand, shade: AlchemyWarriorsInk.steelDark)
        // The scabbard, hanging back from the belt, with the sword's hilt in it until he draws.
        let mouth = d.up(P(-5, -27.4))
        let down = P.direction(-52)
        AlchemyWarriorsKit.shape(&d.svg, [mouth + P(-1.2, -0.8), mouth + down * 20 + P(-1, -0.6), mouth + down * 21.6, mouth + down * 20 + P(1, 0.6),
                                          mouth + P(1.2, 0.8)], fill: .colour(AlchemyWarriorsInk.darkLeather), width: 1)
        d.svg.line([mouth + down * 18.4 + P(-1.1, -0.8), mouth + down * 18.4 + P(1.1, 0.8)], stroke: .colour(AlchemyWarriorsInk.gilt), width: 1)
        if pose != .fighting {
            let hilt = P.direction(128)
            d.svg.line([mouth + hilt * 1.6 + P(-2.8, 2.6), mouth + hilt * 1.6 + P(2.8, -2.6)], stroke: .colour(Ink.line), width: 2.3)
            d.svg.line([mouth + hilt * 1.6 + P(-2.4, 2.2), mouth + hilt * 1.6 + P(2.4, -2.2)], stroke: .colour(AlchemyWarriorsInk.gilt), width: 1.1)
            d.svg.line([mouth + hilt * 2, mouth + hilt * 6], stroke: .colour(Ink.line), width: 2.4)
            d.svg.line([mouth + hilt * 2.2, mouth + hilt * 5.8], stroke: .colour(AlchemyWarriorsInk.leather), width: 1.1)
            d.svg.circle(mouth + hilt * 7, 1.4, fill: .colour(AlchemyWarriorsInk.gilt), stroke: .colour(Ink.line), width: 0.7)
        }
        // The near leg in plate, its foot in the stirrup, with a spur at the heel.
        let hip = Joints.frontHip, knee = j.frontKnee, foot = j.frontFoot
        d.svg.line([P(1.6, -18), foot + P(0.4, 1.6)], stroke: .colour(Ink.line), width: 1.8)
        d.svg.line([P(1.6, -18), foot + P(0.4, 1.6)], stroke: .colour(AlchemyWarriorsInk.leather), width: 0.8)
        AlchemyWarriorsKit.plate(&d.svg, [hip, knee, foot], width: 4)
        let u = P.direction(BronzePeopleKit.degrees(from: knee, to: foot))
        AlchemyWarriorsKit.shape(&d.svg, [foot - u * 3 + P(-2, 0), foot - u * 3 + P(2.2, 0), foot + P(6.4, 0.6), foot + P(4.6, 2.2), foot + P(-2.2, 2)],
                                 fill: .colour(AlchemyWarriorsInk.steel), width: 1)
        d.svg.line([foot + P(0.6, -0.4), foot + P(1.4, 1.6)], stroke: .colour(AlchemyWarriorsInk.steelDark), width: 0.6)
        d.svg.path("M\(num(foot.x + 1.6)),\(num(foot.y + 3.2)) L\(num(foot.x + 6.4)),\(num(foot.y + 3.2))", stroke: .colour(Ink.line), width: 1.6)
        d.svg.line([foot + P(-2, 1.2), foot + P(-4.6, 1.6)], stroke: .colour(AlchemyWarriorsInk.gilt), width: 1)
        d.svg.circle(foot + P(-5.2, 1.7), 1, fill: .colour(AlchemyWarriorsInk.gilt), stroke: .colour(Ink.line), width: 0.5)
        AlchemyWarriorsKit.joint(&d.svg, at: knee + P(0.6, -0.4), radius: 2.5)
        // The surcoat's skirt over the thigh, its hem dagged, blown back at the charge.
        let blow = flutter * 1.2
        let skirtColour = [P(-12.6, -30.4), P(11.8, -30.8), P(18.6 - blow, -17 - blow * 0.4), P(11.4 - blow, -14.6), P(4.6 - blow, -16.6),
                           P(-2.4 - blow, -16.2), P(-9.8 - blow, -19.2)]
        d.garment(colour: skirtColour.map { $0 + P(-0.7, 0.6) }, outline: skirtColour, fill: .team) { d in
            d.svg.line([P(-9 - blow, -21), P(-2.4 - blow, -18.2), P(4.6 - blow, -18.6), P(11.2 - blow, -16.8), P(17.2 - blow, -18.8)],
                       stroke: .colour(AlchemyWarriorsInk.light), width: 1.1)
            d.svg.line([P(3, -29), P(4 - blow * 0.6, -18.4)], stroke: .colour(Ink.line), width: 0.9, opacity: 0.3)
        }
        // The surcoat over the breastplate, with a chevron and a sun in the light.
        d.garment(colour: [P(-12.6, -46.6), P(9.4, -48.4), P(12.8, -27.6), P(-14, -27.2)],
                  outline: [P(-9, -47.4), P(9.2, -47.4), P(12.2, -28.4), P(-13.2, -28.4)], fill: .team) { d in
            let light = Paint.colour(AlchemyWarriorsInk.light)
            d.svg.line([d.up(P(-7.4, -31.6)), d.up(P(1, -39.4)), d.up(P(9.6, -31.8))], stroke: light, width: 2.1)
            let sun = d.up(P(1, -43.6))
            d.svg.circle(sun, 1.7, fill: light)
            var rays = PathData()
            for angle in stride(from: 0.0, to: 360, by: 45) {
                let v = P.direction(angle)
                rays.move(sun + v * 2.4); rays.line(sun + v * 3.4)
            }
            d.svg.path(rays, stroke: light, width: 0.8)
        }
        // The sword belt, with a gilt buckle.
        d.svg.line([d.up(P(-13.4, -28.6)), d.up(P(12.4, -28.8))], stroke: .colour(Ink.line), width: 3)
        d.svg.line([d.up(P(-13, -28.6)), d.up(P(12, -28.8))], stroke: .colour(AlchemyWarriorsInk.leather), width: 1.6)
        d.svg.path(BronzePeopleProps.rounded(d.up(P(8.4, -28.7)), width: 2.6, height: 2.4, radius: 0.5, degrees: 0, shift: P(0, 0)),
                   fill: .colour(AlchemyWarriorsInk.gilt), stroke: .colour(Ink.line), width: 0.6)
        // The gorget at the neck.
        AlchemyWarriorsKit.shape(&d.svg, [d.up(P(-6.6, -49.6)), d.up(P(7.2, -49.8)), d.up(P(8.6, -46.2)), d.up(P(0.6, -44.8)), d.up(P(-7.2, -46))],
                                 fill: .colour(AlchemyWarriorsInk.steel), width: 1.1)
        d.svg.path("M\(num(-6.4)),\(num(d.up(P(0, -47.6)).y)) Q1,\(num(d.up(P(0, -46.2)).y)) 7.8,\(num(d.up(P(0, -47.8)).y))",
                   stroke: .colour(AlchemyWarriorsInk.gilt), width: 0.8)
        // The helm, then the lance or the sword before it, and the arm that holds them.
        helm(&d, pose, frame, flutter: flutter)
        let hand = j.frontHand
        switch pose {
        case .fighting:
            let degrees = cut[frame].degrees
            if frame == 7 { d.swish(around: j.frontShoulder, radius: 25, from: 190, to: 100) }
            AlchemyWarriorsKit.sword(&d.svg, at: hand, degrees: degrees)
            if frame == 8 { d.impact(at: AlchemyWarriorsKit.swordPoint(at: hand, degrees: degrees) + P.direction(degrees) * 1.6, size: 1) }
        case .walking:
            let bounce = 1.2 * BronzePeopleKit.wave(frame, 0.1, times: 2)
            couchedLance(&d.svg, at: hand, degrees: couchDegrees + bounce, behind: couchedBehind)
        default:
            // At rest, upright, its butt by the stirrup.
            couchedLance(&d.svg, at: hand, degrees: 172, behind: restingBehind)
        }
        AlchemyWarriorsKit.arm(&d.svg, shoulder: j.frontShoulder, elbow: j.frontElbow, hand: hand)
        AlchemyWarriorsKit.pauldron(&d.svg, at: j.frontShoulder)
        d.svg.raw("</g>")
        // The reins, from the gauntlet to the bit.
        let reinHand = world(j.backHand)
        var rein = PathData()
        rein.move(reinHand); rein.quad((reinHand + bit) * 0.5 + P(0, pose == .walking ? 1.6 : 3.4), bit)
        d.svg.path(rein, stroke: .colour(Ink.line), width: 0.9)
    }

    /// The lance through `hand`, `behind` of it behind the hand and the rest
    /// ahead along `degrees`: a shaft swelling at the grip and tapering to the
    /// head, painted with a spiral of teal, a steel vamplate before the hand,
    /// and a leaf-shaped head.
    static func couchedLance(_ svg: inout SVG, at hand: P, degrees: Double, behind: Double) {
        let u = P.direction(degrees), a = P(-u.y, u.x)
        let ahead = lance - behind
        let butt = hand - u * behind, tip = hand + u * ahead
        let neck = tip - u * 8
        let shaft = [butt + a * 1.3, hand + u * 3 + a * 1.9, neck + a * 0.9, neck - a * 0.9, hand + u * 3 - a * 1.9, butt - a * 1.3]
        svg.polygon(shaft.map { $0 + P(-0.5, 0.5) }, fill: .colour(AlchemyWarriorsInk.paleWood))
        // The spiral: slanted bands of teal along the shaft ahead of the hand.
        var along = 8.0
        while along < ahead - 12 {
            let t = (along - 3) / (ahead - 11)
            let w = 1.9 + (0.9 - 1.9) * min(max(t, 0), 1)
            let c = hand + u * along
            svg.polygon([c + a * w - u * 1.4, c + a * w + u * 1.4, c - a * w + u * 3.2, c - a * w + u * 0.4], fill: .colour(AlchemyWarriorsInk.teal))
            along += 6.5
        }
        svg.polygon(shaft, fill: .none, stroke: .colour(Ink.line), width: 1)
        svg.line([butt, butt + u * 2.4], stroke: .colour(AlchemyWarriorsInk.steelDark), width: 2.6)
        // The head.
        AlchemyWarriorsKit.shape(&svg, [neck + a * 0.9, neck + u * 3.6 + a * 2, tip, neck + u * 3.6 - a * 2, neck - a * 0.9],
                                 fill: .colour(AlchemyWarriorsInk.steelLight), width: 0.9)
        svg.line([neck + u * 1, tip - u * 1.6], stroke: .colour(AlchemyWarriorsInk.steelDark), width: 0.5)
        // The vamplate: a cone of steel guarding the hand.
        let rim = hand + u * 1.4, point = hand + u * 6.4
        AlchemyWarriorsKit.shape(&svg, [rim + a * 5, point + a * 1.9, point - a * 1.9, rim - a * 5], fill: .colour(AlchemyWarriorsInk.steel), width: 1)
        svg.line([rim + a * 4.6, rim - a * 4.6], stroke: .colour(AlchemyWarriorsInk.gilt), width: 0.9)
    }

    /// The closed helm, drawn where the head would be and nodding with it: a
    /// rounded skull with a comb, a pointed visor with its sight slit and
    /// breaths, a gilt pivot, the bevor under the chin, and a plume of wine and
    /// light streaming back. The eye glints in the slit.
    static func helm(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int, flutter: Double) {
        d.svg.raw("<g transform=\"translate(0,\(num(d.chest.y))) rotate(\(num(d.rig.headTilt)) 0 -48)\">")
        // The plume, behind the skull.
        let f = flutter
        let wave = 0.8 * BronzePeopleKit.wave(frame, times: pose == .walking ? 2 : 1)
        let feathers: [(String, Double)] = [(AlchemyWarriorsInk.light, 4), (AlchemyWarriorsInk.wine, 0)]
        for (colour, drop) in feathers {
            BronzePeopleProps.shape(&d.svg, fill: .colour(colour), width: 1.1) { o in
                var p = PathData()
                p.move(P(-6.6, -70.4) + o)
                p.cubic(P(-8.4, -79 + drop) + o, P(-15.6, -82.4 + drop + wave) + o, P(-22.6 - f * 3, -77.6 + drop * 1.4 + f * 1.6 + wave) + o)
                p.cubic(P(-19.6 - f * 2, -76.6 + drop * 1.2 + wave) + o, P(-14.4, -75 + drop) + o, P(-9.4, -68.4) + o)
                p.close()
                return p
            }
            var barbs = PathData()
            for i in 1...3 {
                let x = -9.4 - Double(i) * 3.2
                let y = -77.6 + drop * 1.1 + wave * Double(i) / 3 + Double(i) * 0.4
                barbs.move(P(x, y)); barbs.line(P(x - 1.6, y + 1.6))
            }
            d.svg.path(barbs, stroke: .colour(Ink.line), width: 0.6, opacity: 0.6)
        }
        // The skull.
        BronzePeopleProps.shape(&d.svg, fill: .colour(AlchemyWarriorsInk.steel), width: 1.6) { o in
            var p = PathData()
            p.move(P(-10.6, -50.4) + o)
            p.cubic(P(-12.8, -55) + o, P(-12.6, -63) + o, P(-9, -67.4) + o)
            p.cubic(P(-5, -71.6) + o, P(3.4, -72) + o, P(8.2, -67.6) + o)
            p.cubic(P(10.6, -65.4) + o, P(11.6, -63.2) + o, P(12, -61.6) + o)
            p.line(P(16.8, -57.2) + o)
            p.line(P(12.6, -53) + o)
            p.cubic(P(11.8, -50.6) + o, P(10.4, -48.6) + o, P(8.6, -47.4) + o)
            p.line(P(4, -46.4) + o)
            p.cubic(P(-1, -46) + o, P(-7, -47) + o, P(-10.6, -50.4) + o)
            p.close()
            return p
        }
        // The comb along the crown, and the light on the skull.
        BronzePeopleProps.shape(&d.svg, fill: .colour(AlchemyWarriorsInk.steel), width: 1) { o in
            var p = PathData()
            p.move(P(-8.4, -67.6) + o)
            p.cubic(P(-4.8, -73.6) + o, P(3, -74) + o, P(7.4, -68.2) + o)
            p.line(P(6.6, -67.4) + o)
            p.cubic(P(2.8, -71.6) + o, P(-4.2, -71.4) + o, P(-7.4, -66.8) + o)
            p.close()
            return p
        }
        d.svg.path("M-9.2,-61.4 C-8,-65.8 -3.6,-68.6 1.6,-68.8", stroke: .colour(AlchemyWarriorsInk.steelLight), width: 1.4)
        // The visor.
        BronzePeopleProps.shape(&d.svg, fill: .colour(AlchemyWarriorsInk.steel), width: 1.2, shift: P(0, 0)) { o in
            var p = PathData()
            p.move(P(1.2, -65.2) + o)
            p.cubic(P(6, -65.4) + o, P(10, -63.8) + o, P(12, -61.6) + o)
            p.line(P(16.8, -57.2) + o)
            p.line(P(12.6, -53) + o)
            p.cubic(P(8.6, -53.4) + o, P(4, -54.2) + o, P(1.4, -55.6) + o)
            p.cubic(P(-0.4, -58.4) + o, P(-0.2, -62.6) + o, P(1.2, -65.2) + o)
            p.close()
            return p
        }
        d.svg.path("M2.6,-64 C6.6,-64 9.8,-62.4 11.6,-60.6", stroke: .colour(AlchemyWarriorsInk.steelLight), width: 0.9)
        // The sight slit, the eye's glint in it, and the breaths below.
        d.svg.path("M3.8,-60.4 L13.6,-59.2", stroke: .colour(Ink.line), width: 1.8)
        if d.rig.eyes != .closed {
            d.svg.circle(P(7.4, -59.9), d.rig.eyes == .wide ? 0.95 : 0.75, fill: .colour(Ink.eyeWhite))
        }
        for c in [P(9.2, -55.6), P(11.2, -56), P(10.2, -54.2)] {
            d.svg.circle(c, 0.5, fill: .colour(Ink.line))
        }
        // The bevor's edge under the visor, the gilt rim at the neck, and the pivot.
        d.svg.path("M1.4,-55.6 C5,-52.4 8.8,-50.6 11.6,-51.2", stroke: .colour(Ink.line), width: 0.9)
        d.svg.path("M-10,-50.2 C-5.4,-47.6 0.4,-46.8 4.4,-46.8", stroke: .colour(AlchemyWarriorsInk.gilt), width: 1)
        d.svg.circle(P(0.8, -59.6), 1.4, fill: .colour(AlchemyWarriorsInk.gilt), stroke: .colour(Ink.line), width: 0.7)
        // The plume's gilt holder at the back of the crown.
        d.svg.polygon([P(-8.6, -66.4), P(-6.4, -71.2), P(-4.8, -70.4), P(-6.8, -65.8)], fill: .colour(AlchemyWarriorsInk.gilt),
                      stroke: .colour(Ink.line), width: 0.7)
        d.svg.raw("</g>")
    }
}

// MARK: - The knight in the other views

extension AlchemyWarriorsKnight {
    /// Half the destrier's width across its barrel, and across the caparison hanging from it, in the horse's units.
    static let horseHalf = 8.4, clothHalf = 9.6
    /// How far out from his middle the rider's knees and feet go, to clear the horse's sides.
    static let straddle = 13.0

    /// A frame of a pose seen from a view other than the side. From a quarter
    /// the destrier is its side drawing shortened, its far legs beyond it and
    /// its chest or its rump as a face of its own, as the car is drawn; from
    /// the front or behind it shows its whole width, the near legs before the
    /// cloth and the far ones behind. The rider straddles it, drawn on the
    /// figure kit, his lance or sword turning in his own plane.
    func drawInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let view = d.view
        let (c, s) = AlchemyViews.turn(view)
        let gait = IronWarriorsHorseman.horse(pose, frame)
        let horse = BronzePeopleSteed(at: Self.horseOrigin, pose: gait, coat: AlchemyWarriorsInk.coat, shade: AlchemyWarriorsInk.coatShade)
        let k = Self.horseScale
        let flutter: Double
        switch pose {
        case .walking: flutter = 1 + 0.6 * BronzePeopleKit.wave(frame, times: 2)
        case .fighting: flutter = 0.3 * sin(.pi * Double(frame) / 12)
        default: flutter = 0.1 * BronzePeopleKit.wave(frame)
        }
        d.svg.ellipse(P(0, 0.2), abs(38 * c) + abs(14 * s) + 2, 4.2, fill: .colour("#000000"), opacity: 0.13)
        let rise = pose == .walking ? 1.1 + 1.1 * sin(4 * .pi * Double(frame) / 12 + 0.6) : 0
        let seatPoint = horse.body(P(-1.6, -48.4) + Self.seatShift)
        let at = P(seatPoint.x * k * c, seatPoint.y * k - rise) - P(0, -15)
        let mouth = P(horse.mouth.x * c, horse.mouth.y) * k
        let quarter = abs(c) > 0.01
        if quarter {
            // The horse's far side first, its legs and the edge of its body and cloth showing beyond the near side,
            // which gives the body its thickness; then the rider's far leg, and the near side over them.
            let w = Self.horseHalf
            var far = gait
            far.fore = gait.farFore; far.hind = gait.farHind
            let farHorse = BronzePeopleSteed(at: Self.horseOrigin, pose: far, coat: AlchemyWarriorsInk.coatShade, shade: AlchemyWarriorsInk.coatShade)
            d.svg.raw("<g transform=\"scale(\(num(k)))\">")
            d.svg.raw("<g transform=\"translate(\(num(w * s)),0) scale(\(num(c)),1)\">")
            d.svg.raw("<clipPath id=\"knight-far-side\"><rect x=\"-23.6\" y=\"-49\" width=\"50\" height=\"52\"/></clipPath>")
            d.svg.raw("<g clip-path=\"url(#knight-far-side)\">")
            farHorse.draw(&d.svg, near: false)
            Self.caparison(&d.svg, farHorse, flutter: flutter, frame: frame)
            d.svg.raw("</g></g></g>")
            Self.riderLeg(&d, pose, at: at, side: -1)
            d.svg.raw("<g transform=\"scale(\(num(k)))\">")
            var near = gait
            near.farFore = near.fore; near.farHind = near.hind
            let nearHorse = BronzePeopleSteed(at: Self.horseOrigin, pose: near, coat: AlchemyWarriorsInk.coat, shade: AlchemyWarriorsInk.coatShade)
            d.svg.raw("<g transform=\"translate(\(num(-w * s)),0) scale(\(num(c)),1)\">")
            nearHorse.draw(&d.svg, near: true)
            Self.caparison(&d.svg, nearHorse, flutter: flutter, frame: frame)
            Self.chanfron(&d.svg, nearHorse)
            Self.saddle(&d.svg, nearHorse)
            d.svg.raw("</g>")
            d.svg.raw("</g>")
            Self.riderInView(&d, pose, frame, at: at, bit: mouth, flutter: flutter)
        } else {
            let front = view == .front
            d.svg.raw("<g transform=\"scale(\(num(k)))\">")
            // The far pair of legs, and from behind the head beyond the body.
            Self.legsEndOn(&d.svg, horse, front ? .hind : .fore, near: false)
            if !front { Self.headEndOn(&d.svg, horse, front: false) }
            Self.bodyEndOn(&d.svg, horse, front: front)
            Self.legsEndOn(&d.svg, horse, front ? .fore : .hind, near: true)
            Self.clothEnd(&d.svg, horse, view, flutter: flutter, frame: frame)
            if !front { Self.tailEndOn(&d.svg, horse) }
            d.svg.raw("</g>")
            Self.riderInView(&d, pose, frame, at: at, bit: mouth, flutter: flutter)
            if front {
                d.svg.raw("<g transform=\"scale(\(num(k)))\">")
                Self.headEndOn(&d.svg, horse, front: true)
                d.svg.raw("</g>")
            }
        }
        if pose == .walking && frame % 6 == 1 {
            let hoof = horse.hoof(frame < 6 ? .hind : .fore)
            BronzePeopleProps.dust(&d.svg, at: P(hoof.x * c - Self.horseHalf * s, hoof.y) * k + P(-5 * c, -1), size: 0.8, opacity: 0.45)
        }
        if pose == .fighting && frame == 11 {
            let hoof = horse.hoof(.fore)
            d.burst(at: P(hoof.x * c - Self.horseHalf * s, hoof.y) * k + P(1, -1), from: 100, to: 170, size: 0.9)
        }
    }

    /// A pair of legs seen from the front or behind, at both sides of the body:
    /// each in the horse's own plane, so that only its rise and fall show.
    static func legsEndOn(_ svg: inout SVG, _ horse: BronzePeopleSteed, _ kind: BronzePeopleSteed.Leg, near: Bool) {
        let w = horseHalf - 2.6
        for (far, x) in [(false, -w), (true, w)] {
            let (top, joint, hoof) = BronzePeopleSteed.leg(horse, kind, far: far, bob: horse.bob)
            let colour = near ? horse.coat : horse.shade
            let spread = kind == .fore ? 0.4 : 0.8
            let t = P(x, top.y), j = P(x * (1 + spread * 0.05), joint.y), h = P(x * (1 + spread * 0.08), hoof.y)
            svg.line([t, j], stroke: .colour(Ink.line), width: 5.6)
            svg.line([j, h], stroke: .colour(Ink.line), width: 3.8)
            svg.line([t, j], stroke: .colour(colour), width: 3.8)
            svg.line([j, h], stroke: .colour(colour), width: 2.2)
            svg.circle(j, 1.5, fill: .colour(colour))
            // The hoof, seen end on.
            svg.polygon([h + P(-1.6, -2.4), h + P(1.6, -2.4), h + P(2.2, 0.4), h + P(-2.2, 0.4)], fill: .colour(Ink.line))
        }
    }

    /// The barrel seen from the front (the chest) or behind (the rump).
    static func bodyEndOn(_ svg: inout SVG, _ horse: BronzePeopleSteed, front: Bool) {
        let top = horse.body(P(0, -47)).y, bottom = horse.body(P(0, -26.6)).y
        let w = horseHalf + (front ? 0 : 1.2)
        var body = PathData()
        body.move(P(-w, (top + bottom) / 2))
        body.cubic(P(-w, top - 1), P(w, top - 1), P(w, (top + bottom) / 2))
        body.cubic(P(w, bottom + 1.6), P(-w, bottom + 1.6), P(-w, (top + bottom) / 2))
        body.close()
        svg.path(body, fill: .colour(horse.coat), stroke: .colour(Ink.line), width: 1.6)
        if !front {
            // The cleft of the haunches.
            svg.line([P(0, top + 3), P(0, bottom - 2)], stroke: .colour(horse.shade), width: 1.2)
        }
    }

    /// The tail hanging over the caparison, seen from behind.
    static func tailEndOn(_ svg: inout SVG, _ horse: BronzePeopleSteed) {
        let root = horse.body(P(-19, -40)), flow = horse.pose.tail
        BronzePeopleProps.shape(&svg, fill: .colour(Ink.line), width: 0.8) { o in
            var p = PathData()
            p.move(P(-1.6, root.y) + o)
            p.cubic(P(-3.6 - flow * 2, root.y + 8) + o, P(-3 + flow * 3, root.y + 16) + o, P(flow * 4, root.y + 22 - flow * 6) + o)
            p.cubic(P(3 + flow * 3, root.y + 16) + o, P(3.6, root.y + 8) + o, P(1.6, root.y) + o)
            p.close()
            return p
        }
    }

    /// The head and neck seen from the front, the long face toward the viewer
    /// under its chanfron; or from behind, only the poll, the ears and the plume beyond the body.
    static func headEndOn(_ svg: inout SVG, _ horse: BronzePeopleSteed, front: Bool) {
        let ink = Paint.colour(Ink.line)
        let poll = horse.head(P(22, -68)).y, eye = horse.head(P(28.8, -63.4)).y, muzzle = horse.head(P(39, -54)).y
        let withers = horse.body(P(12, -46)).y
        // The plume of the team's colour fanned up from the poll.
        let sway = horse.pose.mane * 6
        for (i, angle) in [-24.0, 0, 24].enumerated() {
            svg.group(at: P(0, poll - 1), turned: angle + (i == 1 ? 0 : sway * 0.3)) { svg in
                svg.ellipse(P(-0.5, -6.4), 2.3, 6, fill: .team)
                svg.ellipse(P(0, -7), 2.3, 6, fill: .none, stroke: ink, width: 0.9)
            }
        }
        // The ears, pricked or laid back.
        let back = horse.pose.earBack
        for x in [-1.0, 1.0] {
            let tip = back ? P(x * 7, poll - 2.4) : P(x * 3.4, poll - 6)
            svg.polygon([P(x * 1.6, poll + 1), tip, P(x * 4.4, poll + 1.4)], fill: .colour(horse.coat), stroke: ink, width: 1)
        }
        if !front {
            svg.polygon([P(-2, poll + 1), P(2, poll + 1), P(2.6, withers), P(-2.6, withers)], fill: .colour(Ink.line))
            return
        }
        // The neck behind the face, the face itself, and the mane's forelock.
        svg.polygon([P(-4.6, poll + 4), P(4.6, poll + 4), P(6.4, withers + 2), P(-6.4, withers + 2)], fill: .colour(horse.coat), stroke: ink, width: 1.4)
        var face = PathData()
        face.move(P(-4.8, poll + 1))
        face.cubic(P(-6.2, eye), P(-4.4, muzzle - 6), P(-3.8, muzzle - 2))
        face.cubic(P(-3.6, muzzle + 1.6), P(3.6, muzzle + 1.6), P(3.8, muzzle - 2))
        face.cubic(P(4.4, muzzle - 6), P(6.2, eye), P(4.8, poll + 1))
        face.cubic(P(2.4, poll - 1), P(-2.4, poll - 1), P(-4.8, poll + 1))
        face.close()
        svg.path(face, fill: .colour(horse.coat), stroke: ink, width: 1.5)
        // The chanfron down the face, with cups round the eyes and a gilt boss.
        let plate = [P(-3.6, poll + 1.4), P(3.6, poll + 1.4), P(2.8, muzzle - 5), P(0, muzzle - 3.4), P(-2.8, muzzle - 5)]
        AlchemyWarriorsKit.shape(&svg, plate, fill: .colour(AlchemyWarriorsInk.steel), width: 1.1)
        svg.line([P(0, poll + 2), P(0, muzzle - 4.4)], stroke: .colour(AlchemyWarriorsInk.steelLight), width: 0.9)
        for x in [-1.0, 1.0] {
            let c = P(x * 5, eye)
            svg.circle(c, 2.3, fill: .colour(AlchemyWarriorsInk.steel), stroke: ink, width: 0.9)
            if horse.pose.blink {
                svg.line([c + P(-1.1, 0), c + P(1.1, 0)], stroke: ink, width: 0.9)
            } else {
                svg.circle(c, 1.3, fill: .colour(Ink.eyeWhite), stroke: ink, width: 0.6)
                svg.circle(c + P(x * 0.3, 0.1), 0.65, fill: ink)
            }
        }
        svg.circle(P(0, eye - 0.4), 1.2, fill: .colour(AlchemyWarriorsInk.gilt), stroke: ink, width: 0.6)
        svg.path("M-2,\(num(poll + 0.6)) q2,3 4,0 q-1,-2.4 -2,-2 q-1,-0.4 -2,2 Z", fill: ink)
        // The nostrils, and the mouth when it opens.
        for x in [-1.6, 1.6] { svg.ellipse(P(x, muzzle - 1), 0.8, 0.5, fill: ink) }
        if horse.pose.mouthOpen { svg.ellipse(P(0, muzzle + 1.4), 2, 0.9, fill: ink) }
        // The cheek straps of the bridle, and the bit's rings.
        svg.path("M-4.4,\(num(poll + 3)) L-3.6,\(num(muzzle - 2)) M4.4,\(num(poll + 3)) L3.6,\(num(muzzle - 2))", stroke: ink, width: 1)
        for x in [-4.2, 4.2] {
            svg.circle(P(x, muzzle - 1.4), 1, fill: .none, stroke: .colour(AlchemyWarriorsInk.gilt), width: 0.7)
        }
    }

    /// The caparison's end toward the viewer: over the chest or the rump, its
    /// scalloped hem, its border and a rosette, for every view but the side.
    static func clothEnd(_ svg: inout SVG, _ horse: BronzePeopleSteed, _ view: SpriteView, flutter: Double, frame: Int) {
        let (c, s) = AlchemyViews.turn(view)
        let front = s > 0
        let endX = front ? 24.2 : -23.2
        let w = clothHalf
        let top = horse.body(P(endX * 0.9, front ? -42.6 : -41.6)).y
        let hem = horse.body(P(endX, front ? -21.8 : -20.4)).y + (front ? 0 : flutter * 0.4)
        func x(_ z: Double) -> Double { endX * c - z * s }
        let scallops = 5
        // Rounded over the chest or the rump, as the barrel is under it.
        var cloth = PathData()
        cloth.move(P(x(w), hem))
        cloth.line(P(x(w), top + 4))
        cloth.cubic(P(x(w * 0.8), top - 4), P(x(-w * 0.8), top - 4), P(x(-w), top + 4))
        cloth.line(P(x(-w), hem))
        for i in 0..<scallops {
            let a = x(mix(w, -w, Double(i) / Double(scallops))), b = x(mix(w, -w, Double(i + 1) / Double(scallops)))
            let ripple = flutter * 0.6 * sin(Double(i) * 1.9 + Double(frame) * 1.05)
            cloth.quad(P((a + b) / 2, hem + 3 + ripple), P(b, hem))
        }
        cloth.close()
        svg.path(cloth, fill: .team)
        var border = PathData()
        border.move(P(x(-w + 0.6), hem - 2.6)); border.line(P(x(w - 0.6), hem - 2.6))
        svg.path(border, stroke: .colour(AlchemyWarriorsInk.light), width: 1.2)
        let light = Paint.colour(AlchemyWarriorsInk.light)
        for (z, y) in [(0.0, (top + hem) / 2 - 2), (-w * 0.55, (top + hem) / 2 + 4), (w * 0.55, (top + hem) / 2 + 4)] {
            let centre = P(x(z), y)
            for angle in [0.0, 90, 180, 270] { svg.circle(centre + P.direction(angle) * 1.3, 0.75, fill: light) }
            svg.circle(centre, 0.55, fill: .colour(AlchemyWarriorsInk.teal))
        }
        svg.path(cloth, stroke: .colour(Ink.line), width: 1.4)
        // The fold where the end meets the side.
        if abs(c) > 0.01 {
            svg.line([P(x(w) + (front ? 0.8 : -0.8), top + 5), P(x(w) + (front ? 0.8 : -0.8), hem - 1)], stroke: .colour(Ink.line), width: 0.9,
                     opacity: 0.35)
        }
    }

    /// One of the rider's legs in plate in this view, on the horse's right
    /// side (`side` 1) or its left (-1), the foot in its stirrup.
    static func riderLeg(_ d: inout Drawing, _ pose: SpritePose, at: P, side: Double) {
        let view = d.view
        let lean = AlchemyViews.lean(d)
        let j = d.joints
        func place(_ p: P, _ z: Double) -> P {
            at + AlchemyViews.project(view, p.x - 3.5, p.y, z).point.rotated(lean, about: Drawing.hips)
        }
        let hip = place(Joints.frontHip, side * Drawing.hipSpread)
        let knee = place(j.frontKnee, side * straddle), foot = place(j.frontFoot, side * (straddle + 0.6))
        AlchemyWarriorsKit.plate(&d.svg, [hip, knee, foot], width: 4, shade: side > 0 ? AlchemyWarriorsInk.steel : AlchemyWarriorsInk.steelDark)
        // The sabaton, its length as the view shows it, the stirrup under it and the spur.
        let run = 5 * AlchemyViews.turn(view).c
        AlchemyWarriorsKit.shape(&d.svg, [foot + P(-2, -1.4), foot + P(2, -1.4), foot + P(max(run, 1.6) + 1, 0.6), foot + P(-2, 2)],
                                 fill: .colour(AlchemyWarriorsInk.steel), width: 1)
        d.svg.line([foot + P(-2.6, 3.2), foot + P(2.6 + max(run, 0), 3.2)], stroke: .colour(Ink.line), width: 1.6)
        d.svg.circle(foot + P(-max(run, 1.4) * 0.8 - 1, 1.6), 1, fill: .colour(AlchemyWarriorsInk.gilt), stroke: .colour(Ink.line), width: 0.5)
        AlchemyWarriorsKit.joint(&d.svg, at: knee, radius: 2.5)
    }

    /// The rider in this view: his rein arm, his legs about the horse, the
    /// surcoat, the helm, the lance or the sword, and the sword arm; the reins to the bit.
    static func riderInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int, at: P, bit: P, flutter: Double) {
        let view = d.view
        let lean = AlchemyViews.lean(d)
        let quarter = abs(AlchemyViews.turn(view).c) > 0.01
        func world(_ p: P) -> P { at + p.rotated(lean, about: Drawing.hips) }
        let front = view == .front || view == .frontQuarter
        // The legs: from the front or behind both show at the horse's sides; from a quarter the far one was drawn beyond the horse.
        if !quarter { riderLeg(&d, pose, at: at, side: -1) }
        riderLeg(&d, pose, at: at, side: 1)
        d.svg.raw("<g transform=\"translate(\(num(at.x)),\(num(at.y))) rotate(\(num(lean)) \(num(Drawing.hips.x)) \(num(Drawing.hips.y)))\">")
        func plateArm(_ d: inout Drawing, _ limb: AlchemyViews.Limb) {
            AlchemyWarriorsKit.arm(&d.svg, shoulder: limb.root, elbow: limb.joint, hand: limb.end,
                                   shade: limb.right ? AlchemyWarriorsInk.steel : AlchemyWarriorsInk.steelDark)
            AlchemyWarriorsKit.pauldron(&d.svg, at: limb.root)
        }
        func weapon(_ d: inout Drawing) {
            let hand = d.hand(front: true)
            switch pose {
            case .fighting:
                let (degrees, k) = AlchemyViews.along(view, cut[frame].degrees)
                AlchemyViews.foreshortened(&d.svg, at: hand, degrees: degrees, by: max(k, 0.25)) { svg in
                    AlchemyWarriorsKit.sword(&svg, at: hand, degrees: degrees)
                }
                if frame == 8 {
                    let point = hand + P.direction(degrees) * ((2.6 + 21) * max(k, 0.25) + 1.6)
                    d.impact(at: point, size: 1)
                }
            case .walking:
                let bounce = 1.2 * BronzePeopleKit.wave(frame, 0.1, times: 2)
                let (degrees, k) = AlchemyViews.along(view, couchDegrees + bounce)
                AlchemyViews.foreshortened(&d.svg, at: hand, degrees: degrees, by: max(k, 0.16)) { svg in
                    couchedLance(&svg, at: hand, degrees: degrees, behind: couchedBehind)
                }
                if k < 0.4 && front {
                    // The lance's point, toward the viewer.
                    let tip = hand + P.direction(degrees) * ((lance - couchedBehind) * max(k, 0.16))
                    d.svg.circle(tip, 1.6, fill: .colour(AlchemyWarriorsInk.steelLight), stroke: .colour(Ink.line), width: 0.8)
                }
            default:
                let (degrees, k) = AlchemyViews.along(view, 172)
                AlchemyViews.foreshortened(&d.svg, at: hand, degrees: degrees, by: max(k, 0.2)) { svg in
                    couchedLance(&svg, at: hand, degrees: degrees, behind: restingBehind)
                }
            }
        }
        let weaponBehind = d.armBehind(front: true)
        for limb in AlchemyViews.arms(d, behind: true) {
            if limb.right { weapon(&d) }
            plateArm(&d, limb)
        }
        // The surcoat's skirt over the thighs, the surcoat, the belt and the gorget.
        let blow = flutter * 1.2
        let skirt = [P(-12.6, -30.4), P(11.8, -30.8), P(18.6 - blow, -17 - blow * 0.4), P(11.4 - blow, -14.6), P(4.6 - blow, -16.6),
                     P(-2.4 - blow, -16.2), P(-9.8 - blow, -19.2)]
        d.garment(colour: skirt.map { $0 + P(-0.7, 0.6) }, outline: skirt, fill: .team) { d in
            let hem = [P(-11.6, -21), P(16, -20), P(16, -18.6), P(-11.6, -19.6)]
            d.band(hem, fill: .colour(AlchemyWarriorsInk.light))
        }
        let coat = [P(-9, -47.4), P(9.2, -47.4), P(12.2, -28.4), P(-13.2, -28.4)]
        d.garment(colour: [P(-12.6, -46.6), P(9.4, -48.4), P(12.8, -27.6), P(-14, -27.2)], outline: coat, fill: .team) { d in
            // The chevron and the sun, on the breast where it faces the viewer.
            guard front else { return }
            let light = Paint.colour(AlchemyWarriorsInk.light)
            func on(_ y: Double, _ angle: Double, _ side: Double) -> P? {
                let (p, depth) = AlchemyViews.around(view, y, angle: angle, on: coat, side: side)
                return depth > 0.5 ? d.up(p) : nil
            }
            if let a = on(-31.6, 60, 1), let b = on(-39.4, 0, 1), let e = on(-31.6, 60, -1) {
                d.svg.line([a, b, e], stroke: light, width: 2.1)
            }
            if let sun = on(-43.6, 0, 1) {
                d.svg.circle(sun, 1.7, fill: light)
                var rays = PathData()
                for angle in stride(from: 0.0, to: 360, by: 45) {
                    let v = P.direction(angle)
                    rays.move(sun + v * 2.4); rays.line(sun + v * 3.4)
                }
                d.svg.path(rays, stroke: light, width: 0.8)
            }
        }
        let belt = [P(-13.4, -29.6), P(12.4, -29.8), P(12.4, -27.8), P(-13.4, -27.6)]
        d.band(belt, fill: .colour(AlchemyWarriorsInk.leather))
        d.svg.polygon(d.turned(belt).map(d.up), fill: .none, stroke: .colour(Ink.line), width: 0.9)
        let gorget = [P(-6.6, -49.8), P(7.2, -49.8), P(8.6, -45.4), P(-7.2, -45.4)]
        AlchemyWarriorsKit.shape(&d.svg, d.turned(gorget).map(d.up), fill: .colour(AlchemyWarriorsInk.steel), width: 1.1)
        // The scabbard at his left hip, the hilt in it until he draws.
        let (mouth, mouthDepth) = AlchemyViews.around(view, -27.4, angle: 100, on: coat, side: -1)
        if mouthDepth > -2 {
            let (down, dk) = AlchemyViews.along(view, -52)
            let u = P.direction(down) * max(dk, 0.3)
            AlchemyWarriorsKit.shape(&d.svg, [mouth + P(-1.2, -0.6), mouth + u * 20 + P(-1, 0), mouth + u * 21.6, mouth + u * 20 + P(1, 0), mouth + P(1.2, 0.6)],
                                     fill: .colour(AlchemyWarriorsInk.darkLeather), width: 1)
            if pose != .fighting {
                d.svg.line([mouth + P(-2.8, 0.4), mouth + P(2.8, -0.4)], stroke: .colour(Ink.line), width: 2.3)
                d.svg.line([mouth + P(-2.4, 0.4), mouth + P(2.4, -0.4)], stroke: .colour(AlchemyWarriorsInk.gilt), width: 1.1)
                d.svg.line([mouth, mouth - u * 5], stroke: .colour(Ink.line), width: 2.4)
                d.svg.circle(mouth - u * 6, 1.4, fill: .colour(AlchemyWarriorsInk.gilt), stroke: .colour(Ink.line), width: 0.7)
            }
        }
        helmInView(&d, pose, frame, flutter: flutter)
        for limb in AlchemyViews.arms(d, behind: false) {
            if limb.right && !weaponBehind { weapon(&d) }
            plateArm(&d, limb)
        }
        d.svg.raw("</g>")
        // The reins, from the gauntlet to the bit.
        let reinHand = world(d.hand(front: false))
        var rein = PathData()
        rein.move(reinHand); rein.quad((reinHand + bit) * 0.5 + P(0, pose == .walking ? 1.6 : 3.4), bit)
        d.svg.path(rein, stroke: .colour(Ink.line), width: 0.9)
    }

    /// The closed helm in this view, nodding with the head: the skull and its
    /// comb, the pointed visor where the face would be, with its sight slit and
    /// breaths, the gilt pivots, and the plume streaming back.
    static func helmInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int, flutter: Double) {
        let view = d.view
        let (c, _) = AlchemyViews.turn(view)
        let ink = Paint.colour(Ink.line)
        let tilt = d.rig.headTilt * c
        d.svg.raw("<g transform=\"translate(0,\(num(d.chest.y))) rotate(\(num(tilt)) 0 -48)\">")
        let wave = 0.8 * BronzePeopleKit.wave(frame, times: pose == .walking ? 2 : 1)
        let f = flutter
        // The plume: from its holder at the back of the crown, streaming back.
        let holder = AlchemyViews.onRim(view, radius: 7.6, front: -69, back: -69, phi: .pi)
        let tip = AlchemyViews.project(view, -22.6 - f * 3, -76 + f * 1.6 + wave, 0)
        func plume(_ d: inout Drawing) {
            for (colour, drop) in [(AlchemyWarriorsInk.light, 4.0), (AlchemyWarriorsInk.wine, 0.0)] {
                let end = tip.point + P(0, drop * 1.4)
                // Seen end on, the plume falls as a tuft; from a quarter it streams aside.
                let spread = abs(end.x - holder.point.x) < 6 ? 5.0 : 2.4
                BronzePeopleProps.shape(&d.svg, fill: .colour(colour), width: 1.1) { o in
                    var p = PathData()
                    p.move(holder.point + P(-spread * 0.5, -1) + o)
                    p.cubic(holder.point + P(-spread, -9 + drop) + o, end + P(-spread, -4) + o, end + o)
                    p.cubic(end + P(spread, -2) + o, holder.point + P(spread, -6 + drop) + o, holder.point + P(spread * 0.5, 1) + o)
                    p.close()
                    return p
                }
            }
        }
        let plumeBehind = holder.depth < 0 && view != .back
        if plumeBehind || view == .front { plume(&d) }
        // The skull, rounded over the head and closing under the chin.
        let skull = AlchemyViews.dome(view, radius: 11.6, front: -50.4, back: -48.6, top: -71.4, crest: -0.6)
        BronzePeopleProps.shape(&d.svg, skull, fill: .colour(AlchemyWarriorsInk.steel), width: 1.6)
        // The comb along the crown.
        let combFront = AlchemyViews.onRim(view, radius: 7.6, front: -68, back: -68, phi: 0)
        let combBack = AlchemyViews.onRim(view, radius: 7.6, front: -68, back: -68, phi: .pi)
        let combTop = P(-0.6 * c, -73.6)
        d.svg.path("M\(num(combBack.point.x)),\(num(combBack.point.y)) Q\(num(combTop.x)),\(num(combTop.y - 2)) \(num(combFront.point.x)),\(num(combFront.point.y))",
                   stroke: ink, width: 3)
        d.svg.path("M\(num(combBack.point.x)),\(num(combBack.point.y)) Q\(num(combTop.x)),\(num(combTop.y - 2)) \(num(combFront.point.x)),\(num(combFront.point.y))",
                   stroke: .colour(AlchemyWarriorsInk.steelLight), width: 1.4)
        // The gilt rim at the neck.
        d.svg.line(AlchemyViews.rim(view, radius: 10.8, front: -48.6, back: -50.2, steps: 8), stroke: .colour(AlchemyWarriorsInk.gilt), width: 1)
        // The visor and its pivots, where the face would be.
        let pivots = [AlchemyViews.onRim(view, radius: 10.6, front: -59.6, back: -59.6, phi: .pi / 2),
                      AlchemyViews.onRim(view, radius: 10.6, front: -59.6, back: -59.6, phi: -.pi / 2)]
        let face: Double? = view == .front ? 0 : (view == .frontQuarter ? 4.5 : nil)
        if let x = face {
            let point = view == .front ? P(x, -57.2) : P(x + 9.6, -57.2)
            let left = view == .front ? -9.6 : x - 7.4, right = view == .front ? 9.6 : x + 5.6
            var visor = PathData()
            visor.move(P(left, -64.6))
            visor.quad(P(x, -66.6), P(right, -64.6))
            visor.line(point + P(view == .front ? 3.4 : 0, -1))
            visor.line(P(right - 1, -53.4))
            visor.quad(P(x, -52), P(left + 0.6, -54.4))
            visor.close()
            d.svg.path(visor, fill: .colour(AlchemyWarriorsInk.steel), stroke: ink, width: 1.2)
            // The point of the visor toward the viewer, its ridge and its light.
            if view == .front {
                d.svg.path("M0,-64 L0,-55 M-2.4,-57.6 L0,-55.4 L2.4,-57.6", stroke: .colour(AlchemyWarriorsInk.steelDark), width: 0.8)
            } else {
                d.svg.path("M\(num(x)),-63.4 C\(num(x + 4)),-62.6 \(num(x + 7.6)),-60 \(num(point.x - 0.6)),-57.6", stroke: .colour(AlchemyWarriorsInk.steelLight), width: 0.9)
            }
            // The sight slit with the eye's glint in it, and the breaths below.
            d.svg.line([P(left + 1.6, -60.4), P(right - 1.2, -60.4)], stroke: ink, width: 1.8)
            if d.rig.eyes != .closed {
                for ex in view == .front ? [-4.3, 4.3] : [x + 1.4] {
                    d.svg.circle(P(ex, -60.4), d.rig.eyes == .wide ? 0.95 : 0.75, fill: .colour(Ink.eyeWhite))
                }
            }
            for bx in view == .front ? [-3.6, -1.8, 1.8, 3.6] : [x + 2.4, x + 4.2, x + 6] {
                d.svg.circle(P(bx, -56), 0.5, fill: ink)
            }
        }
        for pivot in pivots where pivot.depth > -2 {
            d.svg.circle(pivot.point, 1.4, fill: .colour(AlchemyWarriorsInk.gilt), stroke: ink, width: 0.7)
        }
        // The light on the skull.
        d.svg.path("M\(num(-7.4 + 2 * c)),-63.4 C\(num(-6.4 + 2 * c)),-67 \(num(-3 + 2 * c)),-69 \(num(1.6 + 2 * c)),-69.2",
                   stroke: .colour(AlchemyWarriorsInk.steelLight), width: 1.4)
        if !(plumeBehind || view == .front) {
            d.svg.polygon([holder.point + P(-1.4, 2), holder.point + P(1.4, 2), holder.point + P(1, -3), holder.point + P(-1, -3)],
                          fill: .colour(AlchemyWarriorsInk.gilt), stroke: ink, width: 0.7)
            plume(&d)
        }
        d.svg.raw("</g>")
    }
}
