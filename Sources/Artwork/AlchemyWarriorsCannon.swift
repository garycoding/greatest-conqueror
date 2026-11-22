// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// MARK: - The cannon

/// A field gun on its two-wheeled carriage, with its crew of two drawn on the
/// shared figure (the crew are part of the unit, trained with it, as the
/// catapult's are; ruled 2026-11-19), drawn as `IronWarriorsCatapult` is.
///
/// The gun: an iron barrel with reinforcing rings, a cascabel, gilt dolphins
/// and a vent, its trunnions under iron capsquares on a carriage whose near
/// cheek, running back to the trail, is painted in the team's colour with a
/// border and lozenges in the light; a wedge under the breech; ten-spoked wheels
/// shod with iron. The gunner, in a deep teal coat and a felt cap, with a full
/// beard and nose F, carries the linstock with its smouldering match; the
/// rammer, facing the gun, in a buff jerkin over linen, a wine stocking cap and
/// a bushy moustache, nose B, carries the sponge and rammer on one staff.
/// Standing, the crew wait by the gun; walking, the gunner pushes at the breech
/// and the rammer hauls on a drag rope, and the wheels turn with their stride;
/// fighting, the rammer stands clear on the gun's far side with a hand over
/// his ear, the gunner touches the match to the vent, the gun fires with a
/// flash and a great cloud of smoke and recoils on its wheels, the rammer
/// strides through the smoke to the muzzle, sponges the bore and rams the
/// charge home, and the gunner levers the trail to run the gun forward again.
/// The origin is on the ground under the gun, near the middle of what stands
/// on the ground.
struct AlchemyWarriorsCannon: PersonLook {
    static let canvas = Canvas(minX: -88, minY: -108, width: 204, height: 114, pixelsPerUnit: Canvas.person.pixelsPerUnit)

    static let wheelRadius = 15.0
    static let axle = P(4, -15)
    /// Where the far wheel is drawn, behind and above the near one.
    static let far = P(3.4, -3.2)
    /// The barrel's breech (the base ring's centre) and direction: a little
    /// elevated toward the muzzle.
    static let breech = P(-16, -31)
    static let bore = 92.2
    static let barrel = 58.0
    /// The wheels turn this many degrees a frame when moving: under half the 36
    /// degrees between spokes, so that they never seem to turn backward, and
    /// five spokes in the 12 frames, so that the cycle repeats without a jump.
    static let turn = 15.0
    /// The ground the gun covers in a frame of the walking pose, and the
    /// crew's stride that matches it.
    static let groundPerFrame = wheelRadius * turn * .pi / 180
    static let pace = 23.6

    /// The crew's places: the gunner behind the breech, the rammer before the muzzle.
    static let gunner = P(-62, 0), walkingGunner = P(-40, 0)
    static let walkingRammer = P(60, 0)

    // MARK: The gun's recoil

    /// How far the gun has run back in a frame of the fight.
    static func recoil(_ pose: SpritePose, _ frame: Int) -> Double {
        guard pose == .fighting else { return 0 }
        return [0, 0, -4, -11, -11, -11, -11, -11, -11, -11, -6, -2][frame]
    }

    static func axes() -> (u: P, a: P) {
        let u = P.direction(bore)
        return (u, P(-u.y, u.x))
    }

    /// A point along the barrel's axis (`t` from the breech) and across it (`s`,
    /// toward its belly), with the gun run back by `dx`.
    static func onBarrel(_ t: Double, _ s: Double, dx: Double) -> P {
        let (u, a) = axes()
        return breech + u * t + a * s + P(dx, 0)
    }

    static func muzzle(dx: Double) -> P { onBarrel(barrel, 0, dx: dx) }
    static func vent(dx: Double) -> P { onBarrel(3.4, -5.4, dx: dx) }

    // MARK: The gunner's linstock

    static let linstock = 50.0
    /// Where the linstock's butt rests when it is planted beside him.
    static let planted = P(-50, 0), plantedDegrees = 172.0

    /// The linstock in a frame: its butt, its direction toward the match, and
    /// where along it his hand holds (nil when it stands planted and he has let go).
    static func linstockPlace(_ pose: SpritePose, _ frame: Int) -> (butt: P, degrees: Double, grip: Double?) {
        switch pose {
        case .fighting:
            func held(head: P, degrees: Double) -> (P, Double, Double?) {
                (head - P.direction(degrees) * linstock, degrees, 20)
            }
            switch frame {
            case 0: return held(head: vent(dx: 0) + P(-2.8, -6.6), degrees: 82)
            case 1: return held(head: vent(dx: 0) + P(-0.2, -2.2), degrees: 84)
            case 2: return held(head: P(-24, -52), degrees: 110)
            case 3: return (P(-50, -4), 168, 33)
            case 9, 10, 11: return (planted, plantedDegrees, nil)
            default: return (planted, plantedDegrees, 33)
            }
        case .walking:
            return (P(0, 0), 194, nil)
        default:
            return (planted, plantedDegrees, 33)
        }
    }

    /// The handspike he levers the trail forward with, from the trail's end to his hand.
    static func handspike(dx: Double) -> (foot: P, top: P) {
        let foot = P(-49.2 + dx, -3.4)
        return (foot, foot + P(12, -32))
    }

    // MARK: The rammer's staff

    /// The staff's length, and where along it from the bore's end his two hands hold.
    static let staff = 46.0
    static let frontGrip = 17.0, backGrip = 27.0

    /// The rammer's place in a frame of the fight, and the staff: in the bore
    /// (`depth` past the muzzle, `sponge` true for the sponge end), or upright.
    struct Service {
        var at: P
        var depth: Double?
        var sponge = true
        var lean = 0.0
        var lunge = false
    }

    static let service: [Service] = [
        Service(at: P(30, 0), lean: -1), Service(at: P(30, 0), lean: -3), Service(at: P(30, 0), lean: -6), Service(at: P(43, 0), lean: 6),
        Service(at: P(56, 0), depth: -2, lean: 3), Service(at: P(56, 0), depth: 12, lean: 14, lunge: true), Service(at: P(56, 0), depth: -2, lean: 3),
        Service(at: P(56, 0), depth: -2, sponge: false, lean: 3), Service(at: P(56, 0), depth: 15, sponge: false, lean: 16, lunge: true),
        Service(at: P(56, 0), depth: -2, sponge: false, lean: 3), Service(at: P(48, 0), lean: 2), Service(at: P(39, 0), lean: 3),
    ]

    /// The staff's end in the bore, and the direction along it out of the muzzle.
    static func staffEnd(_ s: Service, dx: Double) -> P? {
        guard let depth = s.depth else { return nil }
        return muzzle(dx: dx) - axes().u * depth
    }

    // MARK: The crew's rigs

    /// How far a rig's figure is raised so that its lower foot rests on the ground.
    static func bob(_ r: Rig) -> Double {
        let j = Joints(r)
        return -max(j.backFoot.y, j.frontFoot.y)
    }

    /// A point of the picture in a crewman's own units: he stands at `origin`,
    /// facing right, or facing left (drawn mirrored) when `mirrored`.
    static func own(_ p: P, origin: P, mirrored: Bool) -> P {
        mirrored ? P(origin.x - p.x, p.y) : P(p.x - origin.x, p.y)
    }

    /// The arm that puts a crewman's hand at `target`, a point of the picture.
    static func reach(_ r: Rig, front: Bool, origin: P, mirrored: Bool = false, to target: P, elbowUp: Bool = false) -> Limb {
        let local = IronWarriorsKit.local(own(target, origin: origin, mirrored: mirrored), origin: P(0, 0), lean: r.lean, bob: bob(r))
        return BronzePeopleKit.reach(front ? IronWarriorsKit.frontShoulder(r) : IronWarriorsKit.backShoulder(r), local, elbowUp: elbowUp)
    }

    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? { Self.gunnerRig(pose, frame) }

    static func gunnerRig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        var r: Rig
        let origin = pose == .walking ? walkingGunner : gunner
        switch pose {
        case .standing:
            r = Moves.standing(frame)
            r.mouth = .firm
            r.backLeg = Limb(-6, 4); r.frontLeg = Limb(7, 4)
        case .walking:
            r = Moves.walking(frame, stride: pace)
            r.lean = 12
            r.mouth = .firm
            r.frontArm = reach(r, front: true, origin: origin, to: onBarrel(-3.6, -2.6, dx: 0))
            return r
        case .fighting:
            r = Moves.standing(frame >= 4 && frame <= 8 ? frame : 0)
            r.lean = [4, 6, -6, -2, 0, 0, 0, 0, 0, 10, 14, 10][frame]
            r.backLeg = Limb(-10, 5); r.frontLeg = Limb(10, 6)
            if frame >= 9 { r.backLeg = Limb(-20, 8); r.frontLeg = Limb(12, 12) }
            r.mouth = frame == 2 ? .open : (frame >= 9 ? .shout : .firm)
            r.eyes = frame == 2 ? .closed : (frame == 3 ? .wide : r.eyes)
            r.headTilt = frame <= 1 ? 5 : 0
            if frame >= 9 {
                r.frontArm = reach(r, front: true, origin: origin, to: handspike(dx: recoil(pose, frame)).top + P(-1.2, 2.4))
                r.backArm = Limb(-10, -20)
                return r
            }
        default:
            return nil
        }
        let place = linstockPlace(pose, frame)
        let grip = place.butt + P.direction(place.degrees) * (place.grip ?? 33)
        r.frontArm = reach(r, front: true, origin: origin, to: grip, elbowUp: grip.y < -46)
        r.backArm = Limb(-8 + 0.5 * r.lift, -10)
        return r
    }

    static func rammerRig(_ pose: SpritePose, _ frame: Int) -> (rig: Rig, at: P, mirrored: Bool)? {
        var r: Rig
        switch pose {
        case .standing:
            r = Moves.standing((frame + 5) % 12)
            r.eyes = frame == 3 ? .closed : .open
            let at = P(64, 0)
            r.frontArm = reach(r, front: true, origin: at, mirrored: true, to: P(at.x - 9, -34 - r.lift * 0.5))
            r.mouth = .smile
            return (r, at, true)
        case .walking:
            r = Moves.walking(frame, stride: pace)
            r.lean = 11
            // The drag rope over his shoulder, held in the back hand at the chest; the staff at the trail.
            r.backArm = BronzePeopleKit.reach(IronWarriorsKit.backShoulder(r), P(2, -42))
            r.frontArm = BronzePeopleKit.reach(IronWarriorsKit.frontShoulder(r), P(12 + 1.2 * r.sway, -30))
            r.mouth = .firm
            return (r, walkingRammer, false)
        case .fighting:
            let s = service[frame]
            r = Moves.standing(frame == 0 || frame >= 10 ? frame : 0)
            r.lean = s.lean
            if s.lunge {
                r.backLeg = Limb(-20, 6); r.frontLeg = Limb(26, 16)
            } else if s.depth != nil {
                r.backLeg = Limb(-14, 6); r.frontLeg = Limb(14, 8)
            } else if frame == 3 || frame == 10 || frame == 11 {
                // Striding between the gun's side and its muzzle.
                r.backLeg = Limb(-18, 10); r.frontLeg = Limb(16, 24)
            }
            r.mouth = frame == 2 ? .open : (frame == 8 ? .murmur : .firm)
            r.eyes = frame == 1 || frame == 2 ? .closed : (frame == 3 ? .wide : .open)
            let dx = recoil(pose, frame)
            if let end = staffEnd(s, dx: dx) {
                let u = axes().u
                r.frontArm = reach(r, front: true, origin: s.at, mirrored: true, to: end + u * frontGrip)
                r.backArm = reach(r, front: false, origin: s.at, mirrored: true, to: end + u * backGrip)
            } else {
                r.frontArm = reach(r, front: true, origin: s.at, mirrored: true, to: P(s.at.x - 9, -34))
                if frame == 1 || frame == 2 {
                    // A hand over his ear against the report.
                    r.backArm = BronzePeopleKit.reach(IronWarriorsKit.backShoulder(r), P(-4, -55), elbowUp: true)
                }
            }
            return (r, s.at, true)
        default:
            return nil
        }
    }

    // MARK: Drawing

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        if d.view != .side { drawInView(&d, pose, frame); return }
        let layer = d.svg.layer
        let phase = d.phase
        let dx = Self.recoil(pose, frame)
        // The wheels roll with the gun: forward as it moves, back as it recoils.
        let spin = (pose == .walking ? -Double(frame) * Self.turn : 0) - dx / Self.wheelRadius * 180 / .pi
        d.svg.ellipse(P(-6, 0.2), 60, 4.2, fill: .colour("#000000"), opacity: 0.13)
        // The rope the rammer hauls on, behind him.
        let rammer = Self.rammerRig(pose, frame)
        var rammerDrawing: Drawing?
        if let rammer {
            let (r, at, mirrored) = rammer
            var crew = Drawing(layer: layer, rig: r, phase: phase)
            Self.drawRammer(&crew, pose, frame, at: at, mirrored: mirrored)
            rammerDrawing = crew
            if pose == .walking {
                let hand = crew.world(crew.joints.backHand) + at
                var rope = PathData()
                rope.move(P(21, -28)); rope.quad(P(40, -27), hand)
                d.svg.path(rope, stroke: .colour(Ink.line), width: 1.7)
                d.svg.path(rope, stroke: .colour(AlchemyWarriorsInk.paleBuff), width: 0.8)
            }
        }
        // The rammer, beside the gun on its far side or before its muzzle.
        if let crew = rammerDrawing, let at = rammer?.at, let mirrored = rammer?.mirrored {
            d.svg.raw("<g transform=\"translate(\(num(at.x)),0) scale(\(mirrored ? -1 : 1),1)\">")
            d.svg.raw(crew.svg.body)
            d.svg.raw("</g>")
        }
        // The gun.
        d.svg.group(at: P(dx, 0)) { svg in
            Self.wheel(&svg, at: Self.axle + Self.far, degrees: spin + 9, far: true)
            Self.carriage(&svg, frame: frame)
            Self.gun(&svg)
            Self.wheel(&svg, at: Self.axle, degrees: spin, far: false)
        }
        if pose == .fighting {
            if frame == 1 {
                // The priming catches at the vent.
                d.burst(at: Self.vent(dx: 0) + P(0, -1), from: 120, to: 240, size: 0.6)
            }
            if frame == 3 { BronzePeopleProps.dust(&d.svg, at: P(-56, -1), size: 1, opacity: 0.5) }
            if frame == 10 { BronzePeopleProps.dust(&d.svg, at: P(-52, -1), size: 0.8, opacity: 0.4) }
            Self.shot(&d.svg, frame: frame)
        }
        // The crew.
        if let r = Self.gunnerRig(pose, frame) {
            var crew = Drawing(layer: layer, rig: r, phase: phase)
            let origin = pose == .walking ? Self.walkingGunner : Self.gunner
            Self.drawGunner(&crew, pose, frame, at: origin)
            let body = crew.svg.body
            d.svg.group(at: origin) { $0.raw(body) }
        }
        if pose == .fighting && frame == 8 {
            // The charge rammed home: a knock at the muzzle.
            let m = Self.muzzle(dx: dx)
            d.svg.path("M\(num(m.x + 1)),\(num(m.y - 5.4)) l2.4,-2.6 M\(num(m.x + 3.4)),\(num(m.y - 3.6)) l3,-1 "
                       + "M\(num(m.x + 1)),\(num(m.y + 5.4)) l2.4,2.6", stroke: .colour(Ink.line), width: 1)
        }
    }

    // MARK: The gun's parts

    /// The carriage: the far cheek, darker, then the near cheek painted in the
    /// team's colour with a border and lozenges in the light, iron at the
    /// trail's end and over the trunnion, and the wedge under the breech.
    static func carriage(_ svg: inout SVG, frame: Int) {
        let cheek = [P(20.5, -30.6), P(23.4, -26.4), P(19, -18.6), P(2, -17), P(-44, -2.4), P(-49.6, -0.6), P(-51, -3.2), P(-48.6, -6.2),
                     P(-24, -17.4), P(-12, -24.6), P(-7.6, -24.6), P(-6, -28.4), P(10, -29.8)]
        AlchemyWarriorsKit.shape(&svg, cheek.map { $0 + far }, fill: .colour(AlchemyWarriorsInk.darkTeal), width: 1.2)
        // The wedge, between the cheeks under the breech.
        AlchemyWarriorsKit.shape(&svg, [P(-22, -24.4), P(-6.8, -24.4), P(-6.8, -26.6)], fill: .colour(AlchemyWarriorsInk.paleWood), width: 1)
        svg.polygon(cheek.map { $0 + P(-0.7, 0.6) }, fill: .team)
        let light = Paint.colour(AlchemyWarriorsInk.light)
        svg.line([P(18.4, -27.8), P(8.6, -27.2), P(-6.6, -26), P(-10.6, -22.4), P(-46.4, -4.2)], stroke: light, width: 0.8, opacity: 0.85)
        var lozenges = PathData()
        for i in 0..<5 {
            let c = P(-38 + Double(i) * 9.2, -6.8 - Double(i) * 4.3)
            lozenges.move(c + P(0, -1.9)); lozenges.line(c + P(2.3, 0)); lozenges.line(c + P(0, 1.9)); lozenges.line(c + P(-2.3, 0))
            lozenges.close()
        }
        svg.path(lozenges, fill: light)
        svg.polygon(cheek, fill: .none, stroke: .colour(Ink.line), width: 1.5)
        // The iron shoe at the trail's end, and the ring a handspike goes through.
        AlchemyWarriorsKit.shape(&svg, [P(-51, -3.2), P(-49.6, -0.6), P(-44.4, -2.2), P(-45.6, -4.8)], fill: .colour(AlchemyWarriorsInk.barrel), width: 0.9)
        svg.circle(P(-43, -8.8), 1.5, fill: .none, stroke: .colour(Ink.line), width: 1.1)
        // Bolts along the cheek.
        for p in [P(-30, -12.4), P(-14, -20.6), P(14, -23.4), P(16.8, -20.2)] {
            svg.circle(p, 0.7, fill: .colour(AlchemyWarriorsInk.barrel), stroke: .colour(Ink.line), width: 0.4)
        }
    }

    /// The barrel: iron, rings at the base, the reinforce and the muzzle, a
    /// cascabel behind, gilt dolphins over the trunnions, and the vent.
    static func gun(_ svg: inout SVG) {
        func at(_ t: Double, _ s: Double) -> P { onBarrel(t, s, dx: 0) }
        let profile: [(Double, Double)] = [(0, 5.4), (1.4, 5.7), (2.4, 5.2), (14, 4.9), (15, 5.3), (16, 4.7), (27, 4.4), (28, 4.7), (28.8, 4.2),
                                           (51.6, 3.6), (53, 4.3), (55.6, 4.7), (barrel, 4.4)]
        let outline = profile.map { at($0.0, -$0.1) } + profile.reversed().map { at($0.0, $0.1) }
        // The cascabel: a neck and a knob behind the breech.
        svg.line([at(0, 0), at(-3.4, 0)], stroke: .colour(Ink.line), width: 3.4)
        svg.line([at(0, 0), at(-3.2, 0)], stroke: .colour(AlchemyWarriorsInk.barrel), width: 1.8)
        svg.circle(at(-4.6, 0) + P(-0.4, 0.4), 2.2, fill: .colour(AlchemyWarriorsInk.barrel))
        svg.circle(at(-4.6, 0), 2.2, fill: .none, stroke: .colour(Ink.line), width: 1)
        AlchemyWarriorsKit.shape(&svg, outline, fill: .colour(AlchemyWarriorsInk.barrel), width: 1.5)
        // The light along the top, and the shade along the belly.
        svg.line([at(3, -3.8), at(50, -2.6)], stroke: .colour(AlchemyWarriorsInk.barrelLight), width: 1.2)
        svg.line([at(3, 3.6), at(50, 2.4)], stroke: .colour(Ink.line), width: 1, opacity: 0.35)
        // The rings.
        for t in [1.4, 15.0, 28.0, 53.6] {
            let h = profile.first { $0.0 >= t }?.1 ?? 4.4
            svg.line([at(t, -h), at(t, h)], stroke: .colour(Ink.line), width: 0.9)
        }
        // The muzzle's mouth.
        svg.line([at(barrel, -2.4), at(barrel, 2.4)], stroke: .colour(Ink.line), width: 1.8)
        // The dolphins, gilt handles over the trunnions.
        var dolphins = PathData()
        for t in [18.6, 23.4] {
            dolphins.move(at(t - 1.6, -4.6)); dolphins.quad(at(t, -8.6), at(t + 1.6, -4.6))
        }
        svg.path(dolphins, stroke: .colour(Ink.line), width: 2)
        svg.path(dolphins, stroke: .colour(AlchemyWarriorsInk.gilt), width: 1)
        // The vent.
        svg.circle(at(3.4, -5.2), 0.8, fill: .colour(Ink.line))
        // The trunnion under its iron capsquare, on the cheek.
        let trunnion = at(21, 0.6)
        svg.circle(trunnion + P(-0.4, 0.4), 2.6, fill: .colour(AlchemyWarriorsInk.barrel))
        svg.circle(trunnion, 2.6, fill: .none, stroke: .colour(Ink.line), width: 1)
        svg.path("M\(num(trunnion.x - 3.6)),\(num(trunnion.y + 1.6)) Q\(num(trunnion.x)),\(num(trunnion.y - 5)) \(num(trunnion.x + 3.6)),\(num(trunnion.y + 1.6))",
                 stroke: .colour(Ink.line), width: 2.2)
        svg.path("M\(num(trunnion.x - 3.4)),\(num(trunnion.y + 1.4)) Q\(num(trunnion.x)),\(num(trunnion.y - 4.6)) \(num(trunnion.x + 3.4)),\(num(trunnion.y + 1.4))",
                 stroke: .colour(AlchemyWarriorsInk.barrelLight), width: 0.9)
    }

    /// A ten-spoked wheel shod with iron, turned by `degrees`, with an iron hub cap.
    static func wheel(_ svg: inout SVG, at c: P, degrees: Double, far: Bool) {
        let r = wheelRadius
        let wood = far ? AlchemyWarriorsInk.darkWood : AlchemyWarriorsInk.wood
        for i in 0..<10 {
            let u = P.direction(degrees + Double(i) * 36)
            svg.line([c + u * 3, c + u * (r - 3)], stroke: .colour(Ink.line), width: 2.4)
            svg.line([c + u * 3.2, c + u * (r - 3.2)], stroke: .colour(wood), width: 1.1)
        }
        svg.circle(c, r - 2.1, fill: .none, stroke: .colour(wood), width: 3)
        svg.circle(c, r - 0.5, fill: .none, stroke: .colour(far ? AlchemyWarriorsInk.darkTeal : AlchemyWarriorsInk.barrelLight), width: 1.3)
        svg.circle(c, r, fill: .none, stroke: .colour(Ink.line), width: 1.7)
        svg.circle(c, r - 3.7, fill: .none, stroke: .colour(Ink.line), width: 0.8)
        svg.circle(c, 3.4, fill: .colour(far ? AlchemyWarriorsInk.darkWood : AlchemyWarriorsInk.paleWood), stroke: .colour(Ink.line), width: 1)
        svg.circle(c, 1.6, fill: .colour(AlchemyWarriorsInk.barrel), stroke: .colour(Ink.line), width: 0.6)
    }

    // MARK: The shot

    /// The flash at the muzzle and the vent, and the great cloud of smoke that
    /// rolls forward, rises and thins whilst the crew serve the gun.
    static func shot(_ svg: inout SVG, frame: Int) {
        let origin = muzzle(dx: 0) + axes().u * 1.5
        if frame == 2 {
            let at = muzzle(dx: recoil(.fighting, 2))
            var star: [P] = [], core: [P] = []
            for i in 0..<14 {
                let angle = bore + Double(i) * 360 / 14
                let forward = max(0, cos(Double(i) * 360 / 14 * .pi / 180))
                let r = i % 2 == 0 ? 8 + 22 * forward : 3.8
                star.append(at + P.direction(angle) * r + P.direction(bore) * 3)
                core.append(at + P.direction(angle) * (i % 2 == 0 ? r * 0.5 : 1.8) + P.direction(bore) * 3)
            }
            svg.polygon(star.map { $0 + P(-0.6, 0.6) }, fill: .colour(AlchemyWarriorsInk.flash))
            svg.polygon(star, fill: .none, stroke: .colour(Ink.line), width: 1.1)
            svg.polygon(core, fill: .colour(AlchemyWarriorsInk.flashCore))
            let v = vent(dx: recoil(.fighting, 2))
            AlchemyWarriorsKit.smoke(&svg, at: v, puffs: [(P(0, -2.4), 2), (P(-1.4, -5.2), 1.6)], opacity: 0.9)
        }
        let ages: [Int: (spread: Double, rise: Double, size: Double, opacity: Double)] = [
            2: (0.3, 0, 0.75, 0.95), 3: (0.62, 2, 1.2, 0.95), 4: (0.78, 6, 1.35, 0.92), 5: (0.86, 10, 1.42, 0.8),
            6: (0.9, 14, 1.45, 0.62), 7: (0.92, 18, 1.45, 0.45), 8: (0.93, 21, 1.4, 0.3), 9: (0.94, 24, 1.35, 0.16),
        ]
        guard let age = ages[frame] else { return }
        let base: [(P, Double)] = [(P(6, 0), 5), (P(14, -3), 7), (P(24, 0.6), 8), (P(34, -5), 7.4), (P(43, 1), 6.4), (P(22, -10), 6),
                                   (P(33, 4.4), 5.2), (P(48, -5), 5.4), (P(12, -11), 4.6)]
        let puffs = base.map { (p, r) in (P(p.x * age.spread, p.y * (0.7 + age.spread * 0.3) - age.rise * (0.5 + p.x / 50)), r * age.size) }
        AlchemyWarriorsKit.smoke(&svg, at: origin, puffs: puffs, opacity: age.opacity)
        if frame == 3 {
            let v = vent(dx: recoil(.fighting, 3))
            AlchemyWarriorsKit.smoke(&svg, at: v, puffs: [(P(-0.6, -4), 2.4), (P(0.8, -7.6), 1.8)], opacity: 0.7)
        }
    }

    // MARK: The crew's figures

    /// An arm in a sleeve of `colour`, and its hand.
    static func sleeve(_ d: inout Drawing, front: Bool, colour: String) {
        let j = d.joints
        let points = front ? [j.frontShoulder, j.frontElbow, j.frontHand] : [j.backShoulder, j.backElbow, j.backHand]
        let cuffAt = points[2] + (points[1] - points[2]) * (2 / Joints.forearm)
        d.svg.line([points[0], points[1], cuffAt], stroke: .colour(Ink.line), width: 4.4)
        d.svg.line([points[0], points[1], cuffAt], stroke: .colour(colour), width: 2.8)
        d.svg.line([cuffAt, points[2]], stroke: .colour(Ink.line), width: 1.9)
        d.hand(points[2])
    }

    /// Breeches to the knee of `colour`, pale stockings, and shoes.
    static func legs(_ d: inout Drawing, breeches: String) {
        let j = d.joints
        d.svg.group(turned: -d.rig.lean, about: Drawing.hips) { svg in
            for front in [false, true] {
                let hip = front ? Joints.frontHip : Joints.backHip
                let knee = front ? j.frontKnee : j.backKnee, foot = front ? j.frontFoot : j.backFoot
                let u = P.direction(BronzePeopleKit.degrees(from: knee, to: foot))
                svg.line([knee, foot], stroke: .colour(Ink.line), width: 2.8)
                svg.line([knee + u * 1.6, foot - u * 0.6], stroke: .colour(AlchemyWarriorsInk.linen), width: 1.2)
                svg.line([hip, knee, knee + u * 1.6], stroke: .colour(Ink.line), width: 5)
                svg.line([hip, knee, knee + u * 1.6], stroke: .colour(front ? breeches : AlchemyWarriorsInk.darkLeather), width: 3.4)
                BronzePeopleProps.shape(&svg, [foot + P(-1.8, -1.6), foot + P(2.4, -1.4), foot + P(5.4, 0.2), foot + P(5, 1.2), foot + P(-1.6, 1.2)],
                                        fill: .colour(AlchemyWarriorsInk.darkLeather), width: 0.9)
                svg.circle(foot + P(1.2, -1.4), 0.7, fill: .colour(AlchemyWarriorsInk.gilt))
            }
        }
    }

    /// The gunner: a deep teal coat, a felt cap, a full beard, nose F, a powder
    /// horn at his hip, and the linstock or the handspike.
    static func drawGunner(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int, at origin: P) {
        let worldOpen = "<g transform=\"rotate(\(num(-d.rig.lean)) \(num(Drawing.hips.x)) \(num(Drawing.hips.y))) translate(0,\(num(-d.bob)))\">"
        func own(_ p: P) -> P { Self.own(p, origin: origin, mirrored: false) }
        let place = linstockPlace(pose, frame)
        let backHand = d.world(d.joints.backHand)
        d.figure { d in
            // The linstock trails from the back hand whilst he walks.
            if pose == .walking {
                let u = P.direction(place.degrees)
                d.svg.raw(worldOpen)
                staffOfMatch(&d.svg, butt: backHand - u * 14, degrees: place.degrees, frame: frame)
                d.svg.raw("</g>")
            }
            sleeve(&d, front: false, colour: AlchemyWarriorsInk.darkTeal)
            legs(&d, breeches: AlchemyWarriorsInk.buff)
            d.garment(colour: [P(-13, -46.4), P(9.4, -48.4), P(12.4, -30), P(15, -15.4), P(-15.6, -15)],
                      outline: [P(-9.2, -47.4), P(9.2, -47.4), P(11.6, -30), P(13.8, -16.4), P(-14.2, -16.4)], fill: .colour(AlchemyWarriorsInk.teal)) { d in
                d.svg.line([P(-13.8, -18.4), P(13.6, -18.4)], stroke: .colour(AlchemyWarriorsInk.paleTeal), width: 1.1)
                d.svg.line([d.up(P(8.6, -46.8)), d.up(P(10.6, -30)), P(12.6, -17)], stroke: .colour(AlchemyWarriorsInk.darkTeal), width: 1)
                for i in 0..<4 {
                    d.svg.circle(d.up(P(8.8 + Double(i) * 0.4, -43.6 + Double(i) * 3.6)), 0.7, fill: .colour(AlchemyWarriorsInk.gilt),
                                 stroke: .colour(Ink.line), width: 0.4)
                }
            }
            d.svg.line([d.up(P(-13.2, -29.8)), d.up(P(11.8, -30))], stroke: .colour(Ink.line), width: 3)
            d.svg.line([d.up(P(-12.8, -29.8)), d.up(P(11.4, -30))], stroke: .colour(AlchemyWarriorsInk.leather), width: 1.6)
            // The powder horn on its cord.
            let horn = d.up(P(-8.6, -24.6))
            d.svg.line([d.up(P(-6, -30)), horn + P(1.6, -1.6)], stroke: .colour(Ink.line), width: 0.6)
            AlchemyWarriorsKit.shape(&d.svg, [horn + P(-4.6, -1.4), horn + P(2.4, -2.4), horn + P(3, 0), horn + P(-3.6, 1.6), horn + P(-6, 0.6)],
                                     fill: .colour(AlchemyWarriorsInk.light), width: 0.8)
            d.svg.line([horn + P(2.6, -2.2), horn + P(2.9, -0.2)], stroke: .colour(AlchemyWarriorsInk.gilt), width: 0.9)
            // The linstock, planted or in his hand, or the handspike at the trail.
            d.svg.raw(worldOpen)
            if pose == .fighting && frame >= 9 {
                let spike = handspike(dx: recoil(pose, frame))
                d.svg.line([own(spike.foot), own(spike.top)], stroke: .colour(Ink.line), width: 2.8)
                d.svg.line([own(spike.foot), own(spike.top)], stroke: .colour(AlchemyWarriorsInk.paleWood), width: 1.4)
            }
            if pose != .walking {
                staffOfMatch(&d.svg, butt: own(place.butt), degrees: place.degrees, frame: frame)
            }
            d.svg.raw("</g>")
            sleeve(&d, front: true, colour: AlchemyWarriorsInk.teal)
            d.head(nose: .bulb, hair: { d in
                d.svg.path("M-10.6,-56 C-11.6,-59 -11,-61.6 -9.4,-63.4 L-7.2,-58.6 Z", fill: .colour(AlchemyWarriorsInk.hair))
            }, features: { d in
                // A full beard.
                d.svg.path("M-1.6,-52.4 C-0.4,-45.6 4.8,-43.6 9,-45.8 C10.4,-47.4 10.8,-49.4 10.6,-50.8 C7.8,-49.2 4.6,-49.6 2.4,-51.6 Z",
                           fill: .colour(AlchemyWarriorsInk.hair), stroke: .colour(Ink.line), width: 0.5)
            }, brow: { d in
                d.svg.path("M1.6,-63.6 q3.2,-1.4 6.6,-0.4", stroke: .colour(Ink.line), width: 1.7)
            }, over: { d in
                // A felt cap with a turned-up brim.
                BronzePeopleProps.shape(&d.svg, fill: .colour(AlchemyWarriorsInk.leather), width: 1.3) { o in
                    var p = PathData()
                    p.move(P(-10.6, -63) + o)
                    p.cubic(P(-11.4, -74.4) + o, P(5, -77.6) + o, P(9.6, -66) + o)
                    p.cubic(P(3, -67.8) + o, P(-4, -67) + o, P(-10.6, -63) + o)
                    p.close()
                    return p
                }
                BronzePeopleProps.shape(&d.svg, fill: .colour(AlchemyWarriorsInk.darkLeather), width: 1.1) { o in
                    var p = PathData()
                    p.move(P(-12.4, -61.4) + o)
                    p.cubic(P(-5, -66.6) + o, P(4, -67.6) + o, P(11.4, -65.4) + o)
                    p.line(P(10.8, -67.8) + o)
                    p.cubic(P(3.6, -69.6) + o, P(-5.4, -68.4) + o, P(-12, -64) + o)
                    p.close()
                    return p
                }
            })
        }
    }

    /// The linstock: an ash staff with an iron spike at its butt and a forked
    /// head of iron at its top, the slow match wound round it and smouldering.
    static func staffOfMatch(_ svg: inout SVG, butt: P, degrees: Double, frame: Int) {
        let u = P.direction(degrees), a = P(-u.y, u.x)
        let head = butt + u * linstock
        svg.line([butt + u * 2, head - u * 2], stroke: .colour(Ink.line), width: 2.3)
        svg.line([butt + u * 2.3, head - u * 2.3], stroke: .colour(AlchemyWarriorsInk.paleWood), width: 1)
        svg.line([butt, butt + u * 2.4], stroke: .colour(AlchemyWarriorsInk.barrel), width: 1.4)
        // The match wound round the shaft below the head.
        var wound = PathData()
        for i in 0..<4 {
            let c = head - u * (4 + Double(i) * 1.4)
            wound.move(c - a * 1.4); wound.line(c + a * 1.4 + u * 0.7)
        }
        svg.path(wound, stroke: .colour(AlchemyWarriorsInk.paleBuff), width: 0.9)
        // The forked head, and the match's burning end in its jaw.
        var fork = PathData()
        fork.move(head - u * 2); fork.quad(head + a * 2.6, head + a * 1.6 + u * 2.6)
        fork.move(head - u * 2); fork.quad(head - a * 1.8, head - a * 1.2 + u * 2.2)
        svg.path(fork, stroke: .colour(Ink.line), width: 1.7)
        svg.path(fork, stroke: .colour(AlchemyWarriorsInk.barrelLight), width: 0.6)
        var match = PathData()
        match.move(head - u * 3.6 - a * 1.2); match.quad(head - a * 2.6 + u * 1, head + u * 2.4)
        svg.path(match, stroke: .colour(Ink.line), width: 1.1)
        svg.path(match, stroke: .colour(AlchemyWarriorsInk.paleBuff), width: 0.5)
        AlchemyWarriorsMusketeer.ember(&svg, at: head + u * 2.6, frame: frame)
    }

    /// The rammer: a buff jerkin over a linen shirt, a wine stocking cap with a
    /// tassel, a bushy moustache, nose B, and the staff with the sponge at one
    /// end and the rammer's head at the other.
    static func drawRammer(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int, at origin: P, mirrored: Bool) {
        let worldOpen = "<g transform=\"rotate(\(num(-d.rig.lean)) \(num(Drawing.hips.x)) \(num(Drawing.hips.y))) translate(0,\(num(-d.bob)))\">"
        func own(_ p: P) -> P { Self.own(p, origin: origin, mirrored: mirrored) }
        // The front hand in his own units, where the staff is drawn.
        let frontHand = d.world(d.joints.frontHand)
        d.figure { d in
            sleeve(&d, front: false, colour: AlchemyWarriorsInk.paleBuff)
            legs(&d, breeches: AlchemyWarriorsInk.darkTeal)
            // The shirt's skirt, and the jerkin over it.
            d.garment(colour: [P(-12.2, -32), P(11.8, -32.2), P(13.4, -17), P(-14.2, -16.6)],
                      outline: [P(-11.2, -31.6), P(11, -31.6), P(12.4, -18), P(-13, -18)], fill: .colour(AlchemyWarriorsInk.linen))
            d.garment(colour: [P(-12.6, -46.6), P(9.4, -48.4), P(12.2, -26.6), P(-13.8, -26.2)],
                      outline: [P(-8.8, -47.4), P(8.8, -47.4), P(11.4, -27.4), P(-13, -27.4)], fill: .colour(AlchemyWarriorsInk.buff)) { d in
                d.svg.line([d.up(P(6.4, -47)), d.up(P(9.6, -27.8))], stroke: .colour(AlchemyWarriorsInk.darkBuff), width: 1)
                var lacing = PathData()
                for i in 0..<4 {
                    let y = -44 + Double(i) * 4
                    lacing.move(d.up(P(6.6 + Double(i) * 0.5, y))); lacing.line(d.up(P(9.4 + Double(i) * 0.5, y + 1.6)))
                }
                d.svg.path(lacing, stroke: .colour(AlchemyWarriorsInk.darkLeather), width: 0.7)
            }
            AlchemyWarriorsKit.shape(&d.svg, [d.up(P(-5.6, -49)), d.up(P(7.6, -49.2)), d.up(P(6.4, -46.2)), d.up(P(-5, -46))],
                                     fill: .colour(AlchemyWarriorsInk.linen), width: 0.9)
            // The staff.
            d.svg.raw(worldOpen)
            switch pose {
            case .walking:
                let u = P.direction(100 + 2 * BronzePeopleKit.wave(frame))
                spongeStaff(&d.svg, from: frontHand - u * 22, toward: frontHand + u * 24, spongeAtStart: false, sooty: false)
            case .fighting:
                let s = service[frame]
                let dx = recoil(pose, frame)
                if let end = staffEnd(s, dx: dx) {
                    let u = axes().u
                    spongeStaff(&d.svg, from: own(end), toward: own(end + u * staff), spongeAtStart: s.sponge, sooty: frame == 6,
                                hiddenTo: own(muzzle(dx: dx)))
                } else {
                    let foot = P(s.at.x - 9.6, 0)
                    spongeStaff(&d.svg, from: own(foot), toward: own(foot + P(0, -staff)), spongeAtStart: false, sooty: false)
                }
            default:
                let foot = P(origin.x - 9.6, 0)
                spongeStaff(&d.svg, from: own(foot), toward: own(foot + P(0, -staff)), spongeAtStart: false, sooty: false)
            }
            d.svg.raw("</g>")
            sleeve(&d, front: true, colour: AlchemyWarriorsInk.linen)
            d.head(nose: .button, hair: { d in
                d.svg.path("M-10.6,-55 C-11.4,-58 -11,-60.4 -9.8,-62 L-7.6,-57.6 Z", fill: .colour(AlchemyWarriorsInk.hair))
            }, features: { d in
                // A bushy moustache, and stubble along the jaw.
                d.svg.path("M3.6,-53.6 q3.6,-2.4 8.4,-0.6 q0.4,2.6 -1.6,3 q-2.4,-1.4 -4.4,-0.6 q-2,-0.2 -2.4,-1.8 Z",
                           fill: .colour(AlchemyWarriorsInk.hair), stroke: .colour(Ink.line), width: 0.5)
                d.svg.path("M0,-49.6 l0.4,-0.9 M2.2,-48.6 l0.3,-0.9 M4.6,-48.2 l0.2,-0.9", stroke: .colour(Ink.line), width: 0.6, opacity: 0.6)
            }, brow: { d in
                d.svg.path("M1.2,-63.4 q3.4,-2.2 7.4,-0.8", stroke: .colour(Ink.line), width: 2)
            }, over: { d in
                // A stocking cap of wine, flopping back, with a tassel.
                let flop = pose == .walking ? 1.2 * BronzePeopleKit.wave(frame, 0.2) : 0.3 * BronzePeopleKit.wave(frame)
                BronzePeopleProps.shape(&d.svg, fill: .colour(AlchemyWarriorsInk.wine), width: 1.3) { o in
                    var p = PathData()
                    p.move(P(-11, -60.6) + o)
                    p.cubic(P(-12, -71) + o, P(2, -76) + o, P(9.8, -65.4) + o)
                    p.cubic(P(4, -70) + o, P(-6, -72) + o, P(-15.4, -66.4 + flop) + o)
                    p.cubic(P(-14.6, -64) + o, P(-13, -62) + o, P(-11, -60.6) + o)
                    p.close()
                    return p
                }
                d.svg.path("M-11.6,-61.4 C-4.6,-66 3,-67 9.6,-65.4", stroke: .colour(AlchemyWarriorsInk.darkWine), width: 1.6)
                d.svg.circle(P(-16.4, -65 + flop) + P(-0.4, 0.4), 1.8, fill: .colour(AlchemyWarriorsInk.light))
                d.svg.circle(P(-16.4, -65 + flop), 1.8, fill: .none, stroke: .colour(Ink.line), width: 0.8)
            })
        }
    }

    /// The sponge and rammer on one staff, from `from` to `toward`: the sponge,
    /// a woollen cylinder, at one end and the rammer's wooden head at the
    /// other. The part of the staff before `hiddenTo` is inside the bore and not drawn.
    static func spongeStaff(_ svg: inout SVG, from start: P, toward end: P, spongeAtStart: Bool, sooty: Bool, hiddenTo: P? = nil) {
        let length = BronzePeopleKit.length(end - start)
        let u = (end - start) * (1 / length), a = P(-u.y, u.x)
        let visibleFrom = hiddenTo.map { h in max(0, (h.x - start.x) * u.x + (h.y - start.y) * u.y) } ?? 0
        func at(_ t: Double) -> P { start + u * t }
        svg.line([at(max(visibleFrom, 4)), at(length - 4)], stroke: .colour(Ink.line), width: 2.3)
        svg.line([at(max(visibleFrom, 4) + 0.3), at(length - 4.3)], stroke: .colour(AlchemyWarriorsInk.paleWood), width: 1)
        func head(_ t0: Double, _ t1: Double, sponge: Bool) {
            guard t1 > visibleFrom else { return }
            let s = max(t0, visibleFrom)
            let r = sponge ? 2.8 : 2.5
            let corners = [at(s) + a * r, at(t1) + a * r, at(t1) - a * r, at(s) - a * r]
            let fill = sponge ? (sooty ? AlchemyWarriorsInk.hair : AlchemyWarriorsInk.smoke) : AlchemyWarriorsInk.wood
            AlchemyWarriorsKit.shape(&svg, corners, fill: .colour(fill), width: 0.9)
            if sponge {
                var tufts = PathData()
                for i in 0..<3 {
                    let t = s + (t1 - s) * (Double(i) + 0.5) / 3
                    tufts.move(at(t) + a * (r - 0.8)); tufts.line(at(t) - a * (r - 0.8))
                }
                svg.path(tufts, stroke: .colour(Ink.line), width: 0.5, opacity: 0.5)
            }
        }
        if spongeAtStart {
            head(0, 6, sponge: true); head(length - 3.2, length, sponge: false)
        } else {
            head(0, 3.2, sponge: false); head(length - 6, length, sponge: true)
        }
    }
}

// MARK: - The cannon in the other views

extension AlchemyWarriorsCannon {
    /// Where the wheels and the carriage's cheeks stand across the gun, from its middle.
    static let track = 13.0, cheekSpread = 5.0
    /// How far to the gun's right the gunner stands, and to its left the rammer, so that neither hides behind it.
    static let gunnerSide = 28.0, rammerSide = 26.0, rammerAtMuzzle = 10.0

    /// A point of the gun's space where it falls in this view.
    static func place(_ view: SpriteView, _ p: P, z: Double = 0) -> P { AlchemyViews.project(view, p.x, p.y, z).point }

    /// A frame of a pose seen from a view other than the side. From a quarter
    /// the gun is its side drawing shortened, the wheels and the cheeks each in
    /// their own plane across it, as the car is drawn; from the front or
    /// behind it shows its muzzle or its breech and trail between the wheels
    /// seen end on. The crew stand beside it, the gunner to its right and the
    /// rammer to its left (and at its muzzle while he serves it), each drawn on
    /// the figure kit in the view his own facing gives, and the whole is
    /// ordered by depth.
    func drawInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let view = d.view
        let (c, s) = AlchemyViews.turn(view)
        let layer = d.svg.layer, phase = d.phase
        let dx = Self.recoil(pose, frame)
        let spin = (pose == .walking ? -Double(frame) * Self.turn : 0) - dx / Self.wheelRadius * 180 / .pi
        d.svg.ellipse(P(-6 * c, 0.2), abs(60 * c) + abs(Self.track * s) + 6, 4.2, fill: .colour("#000000"), opacity: 0.13)

        // The crew: where each stands, how deep, and his drawing.
        var crew: [(depth: Double, svg: String)] = []
        var rammerHands: (near: P, far: P)?
        if let r = Self.gunnerRig(pose, frame) {
            var g = Drawing(layer: layer, rig: r, phase: phase, view: view)
            let origin = pose == .walking ? Self.walkingGunner : Self.gunner
            let z = pose == .walking ? 18.0 : Self.gunnerSide
            let at = Self.place(view, origin, z: z)
            Self.gunnerInView(&g, pose, frame, origin: origin, at: at, dx: dx)
            crew.append((origin.x * s + z * c, "<g transform=\"translate(\(num(at.x)),0)\">" + g.svg.body + "</g>"))
        }
        if let (r, origin, mirrored) = Self.rammerRig(pose, frame) {
            let own = mirrored ? AlchemyViews.opposite(view) : view
            var m = Drawing(layer: layer, rig: r, phase: phase, view: own)
            let serving = pose == .fighting && Self.service[frame].depth != nil
            let z = -(serving ? Self.rammerAtMuzzle : (pose == .walking ? 20 : Self.rammerSide))
            let at = Self.place(view, origin, z: z)
            Self.rammerInView(&m, pose, frame)
            let flip = mirrored ? -1.0 : 1.0
            func unit(_ p: P) -> P { P(at.x + flip * p.x, p.y) }
            rammerHands = (unit(AlchemyViews.world(m, m.hand(front: true))), unit(AlchemyViews.world(m, m.hand(front: false))))
            var body = "<g transform=\"translate(\(num(at.x)),0) scale(\(num(flip)),1)\">" + m.svg.body + "</g>"
            // The staff, in the gun's own picture: into the bore, upright beside him, or at the trail.
            var staff = SVG(layer: layer)
            if let hands = rammerHands {
                if pose == .fighting, let end = Self.staffEnd(Self.service[frame], dx: dx) {
                    let start = Self.place(view, end), toward = hands.near - start
                    let length = max(BronzePeopleKit.length(toward), 0.01)
                    Self.spongeStaff(&staff, from: start, toward: start + toward * (Self.staff / max(length, Self.staff * 0.55)),
                                     spongeAtStart: Self.service[frame].sponge, sooty: frame == 6, hiddenTo: Self.place(view, Self.muzzle(dx: dx)))
                } else if pose == .walking {
                    let (degrees, k) = AlchemyViews.along(own, 100 + 2 * BronzePeopleKit.wave(frame))
                    // His own direction, mirrored with him into the gun's picture.
                    let u = P.direction(degrees) * max(k, 0.25)
                    let along = P(u.x * flip, u.y)
                    Self.spongeStaff(&staff, from: hands.near - along * 22, toward: hands.near + along * 24, spongeAtStart: false, sooty: false)
                } else {
                    Self.spongeStaff(&staff, from: P(hands.near.x, 0), toward: P(hands.near.x, -Self.staff), spongeAtStart: false, sooty: false)
                }
            }
            body += staff.body
            crew.append((origin.x * s + z * c, body))
        }

        // The gun.
        var gun = SVG(layer: layer)
        if abs(c) > 0.01 {
            Self.gunQuarter(&gun, view, frame: frame, dx: dx, spin: spin)
        } else {
            Self.gunEndOn(&gun, front: s > 0, dx: dx, spin: spin)
        }
        crew.sort { $0.depth < $1.depth }
        for member in crew where member.depth < 0 { d.svg.raw(member.svg) }
        if pose == .walking, let hands = rammerHands {
            // The drag rope from the carriage to the rammer's hand.
            let from = Self.place(view, P(21, -28))
            var rope = PathData()
            rope.move(from); rope.quad((from + hands.far) * 0.5 + P(0, 2), hands.far)
            d.svg.path(rope, stroke: .colour(Ink.line), width: 1.7)
            d.svg.path(rope, stroke: .colour(AlchemyWarriorsInk.paleBuff), width: 0.8)
        }
        d.svg.raw(gun.body)
        if pose == .fighting {
            if frame == 1 { d.burst(at: Self.place(view, Self.vent(dx: 0)) + P(0, -1), from: 120, to: 240, size: 0.6) }
            if frame == 3 { BronzePeopleProps.dust(&d.svg, at: Self.place(view, P(-56, -1)), size: 1, opacity: 0.5) }
            if frame == 10 { BronzePeopleProps.dust(&d.svg, at: Self.place(view, P(-52, -1)), size: 0.8, opacity: 0.4) }
        }
        for member in crew where member.depth >= 0 { d.svg.raw(member.svg) }
        if pose == .fighting {
            Self.shotInView(&d.svg, view, frame: frame)
            if frame == 8 {
                let m = Self.place(view, Self.muzzle(dx: dx))
                d.svg.path("M\(num(m.x + 1)),\(num(m.y - 5.4)) l2.4,-2.6 M\(num(m.x + 3.4)),\(num(m.y - 3.6)) l3,-1 "
                           + "M\(num(m.x + 1)),\(num(m.y + 5.4)) l2.4,2.6", stroke: .colour(Ink.line), width: 1)
            }
        }
    }

    /// The gun from a quarter: the far wheel, the carriage and the barrel, and
    /// the near wheel, each its side drawing shortened in its own plane across the gun.
    static func gunQuarter(_ svg: inout SVG, _ view: SpriteView, frame: Int, dx: Double, spin: Double) {
        let (c, s) = AlchemyViews.turn(view)
        func plane(_ z: Double, _ content: (inout SVG) -> Void) {
            svg.raw("<g transform=\"translate(\(num(dx * c - z * s)),0) scale(\(num(c)),1)\">")
            content(&svg)
            svg.raw("</g>")
        }
        plane(-track) { wheel(&$0, at: axle, degrees: spin + 9, far: true) }
        // The axle-tree across, between the wheels.
        let left = place(view, axle + P(dx, 0), z: -track), right = place(view, axle + P(dx, 0), z: track)
        svg.line([left, right], stroke: .colour(Ink.line), width: 4.2)
        svg.line([left, right], stroke: .colour(AlchemyWarriorsInk.darkWood), width: 2.4)
        plane(cheekSpread) { carriage(&$0, frame: frame) }
        plane(0) { gun(&$0) }
        // The muzzle's mouth or the cascabel's end, toward the viewer.
        if s > 0 {
            let m = place(view, muzzle(dx: dx))
            svg.ellipse(m, 4.4 * s, 4.4, fill: .colour(AlchemyWarriorsInk.barrel), stroke: .colour(Ink.line), width: 1.2)
            svg.ellipse(m, 2.4 * s, 2.4, fill: .colour(Ink.line))
        }
        plane(track) { wheel(&$0, at: axle, degrees: spin, far: false) }
    }

    /// A wheel seen end on, at `x` across: its tyre a tall narrow band, the hub
    /// standing out of it, and the tyre's nails rising and falling as it turns.
    static func wheelEndOn(_ svg: inout SVG, x: Double, dx: Double, spin: Double, near: Bool) {
        let r = wheelRadius, c = P(x, axle.y), half = 2.2
        let ink = Paint.colour(Ink.line)
        svg.polygon([c + P(-half, -r), c + P(half, -r), c + P(half, r), c + P(-half, r)], fill: .colour(near ? AlchemyWarriorsInk.wood : AlchemyWarriorsInk.darkWood),
                    stroke: ink, width: 1.2)
        svg.line([c + P(-half + 0.8, -r + 1.6), c + P(-half + 0.8, r - 1.6)], stroke: .colour(AlchemyWarriorsInk.barrelLight), width: 0.9)
        // The nails on the tyre, where they face the viewer.
        for i in 0..<10 {
            let angle = (spin + Double(i) * 36) * .pi / 180
            guard sin(angle) > 0.2 else { continue }
            svg.circle(c + P(0, -r * cos(angle)), 0.6, fill: .colour(AlchemyWarriorsInk.barrel))
        }
        let hub = c + P(x > 0 ? 3.2 : -3.2, 0)
        svg.polygon([c + P(x > 0 ? half : -half, -3.4), hub + P(0, -2.6), hub + P(0, 2.6), c + P(x > 0 ? half : -half, 3.4)],
                    fill: .colour(near ? AlchemyWarriorsInk.paleWood : AlchemyWarriorsInk.darkWood), stroke: ink, width: 0.9)
        svg.ellipse(hub, 1, 2.6, fill: .colour(AlchemyWarriorsInk.barrel), stroke: ink, width: 0.6)
    }

    /// The gun from the front, its muzzle toward the viewer, or from behind,
    /// its breech and trail: between the wheels seen end on, the carriage's
    /// cheeks painted in the team's colour.
    static func gunEndOn(_ svg: inout SVG, front: Bool, dx: Double, spin: Double) {
        let ink = Paint.colour(Ink.line), team = Paint.team
        let light = Paint.colour(AlchemyWarriorsInk.light)
        // The far wheel's side first: from the front the wheels are both at the sides, drawn first.
        for x in [-track, track] { wheelEndOn(&svg, x: x, dx: dx, spin: spin, near: true) }
        let w = cheekSpread
        if front {
            // The trail falling away behind, the cheeks' fronts, the axle-tree, and the muzzle.
            svg.polygon([P(-w + 1, -22), P(w - 1, -22), P(2.4, -1), P(-2.4, -1)], fill: .colour(AlchemyWarriorsInk.darkTeal), stroke: ink, width: 1)
            svg.line([P(-track, axle.y), P(track, axle.y)], stroke: ink, width: 4.6)
            svg.line([P(-track, axle.y), P(track, axle.y)], stroke: .colour(AlchemyWarriorsInk.darkWood), width: 2.8)
            for x in [-w, w] {
                AlchemyWarriorsKit.shape(&svg, [P(x - 1.6, -31.4), P(x + 1.6, -31.4), P(x + 1.6, -16.6), P(x - 1.6, -16.6)], fill: team, width: 1.1)
                svg.line([P(x, -30), P(x, -18)], stroke: light, width: 0.6, opacity: 0.85)
            }
            let m = muzzle(dx: dx)
            let mouth = P(0, m.y)
            // The dolphins over the barrel, and the barrel's mouth with its rings.
            for x in [-2.6, 2.6] {
                svg.path("M\(num(x - 1.4)),\(num(mouth.y - 4.6)) q\(num(1.4)),-3 2.8,0", stroke: ink, width: 2)
                svg.path("M\(num(x - 1.4)),\(num(mouth.y - 4.6)) q\(num(1.4)),-3 2.8,0", stroke: .colour(AlchemyWarriorsInk.gilt), width: 1)
            }
            svg.circle(mouth, 5.4, fill: .colour(AlchemyWarriorsInk.barrel), stroke: ink, width: 1.3)
            svg.circle(mouth, 4.4, fill: .none, stroke: .colour(AlchemyWarriorsInk.barrelLight), width: 0.8)
            svg.circle(mouth, 2.6, fill: ink)
            svg.path("M\(num(-3.6)),\(num(mouth.y - 2.6)) q2,-1.6 4.4,-1.4", stroke: .colour(AlchemyWarriorsInk.barrelLight), width: 0.8)
        } else {
            // The axle-tree and the cheeks, the breech with its cascabel, and the trail toward the viewer.
            svg.line([P(-track, axle.y), P(track, axle.y)], stroke: ink, width: 4.6)
            svg.line([P(-track, axle.y), P(track, axle.y)], stroke: .colour(AlchemyWarriorsInk.darkWood), width: 2.8)
            let b = breech
            svg.circle(P(0, b.y), 5.6, fill: .colour(AlchemyWarriorsInk.barrel), stroke: ink, width: 1.3)
            svg.circle(P(0, b.y), 4.6, fill: .none, stroke: .colour(AlchemyWarriorsInk.barrelLight), width: 0.8)
            svg.circle(P(0, b.y - 5.2), 0.8, fill: ink)
            // The trail: the cheeks closing from the gun to the shoe on the ground.
            let trail = [P(-w - 1.6, -27), P(w + 1.6, -27), P(w + 1.2, -20), P(3.6, -3.2), P(3, 0), P(-3, 0), P(-3.6, -3.2), P(-w - 1.2, -20)]
            AlchemyWarriorsKit.shape(&svg, trail, fill: team, width: 1.3)
            svg.line([P(-w, -25), P(-2.4, -4)], stroke: light, width: 0.8, opacity: 0.85)
            svg.line([P(w, -25), P(2.4, -4)], stroke: light, width: 0.8, opacity: 0.85)
            var lozenges = PathData()
            for (i, y) in [-21.0, -14, -7.6].enumerated() {
                let r = 1.9 - Double(i) * 0.3
                lozenges.move(P(0, y - r)); lozenges.line(P(r * 1.2, y)); lozenges.line(P(0, y + r)); lozenges.line(P(-r * 1.2, y)); lozenges.close()
            }
            svg.path(lozenges, fill: light)
            AlchemyWarriorsKit.shape(&svg, [P(-3.2, -2.6), P(3.2, -2.6), P(3, 0.2), P(-3, 0.2)], fill: .colour(AlchemyWarriorsInk.barrel), width: 0.9)
            svg.circle(P(0, -8.8), 1.5, fill: .none, stroke: ink, width: 1.1)
            // The cascabel's knob, over the trail.
            svg.line([P(0, b.y), P(0, b.y + 3)], stroke: ink, width: 3)
            svg.circle(P(0, b.y + 3.6), 2.2, fill: .colour(AlchemyWarriorsInk.barrel), stroke: ink, width: 1)
        }
    }

    /// The flash and the great cloud of smoke in this view: the cloud rolls
    /// forward as the view shows it, and is drawn drifting aside where it would roll at the viewer.
    static func shotInView(_ svg: inout SVG, _ view: SpriteView, frame: Int) {
        let (c, _) = AlchemyViews.turn(view)
        let origin = place(view, muzzle(dx: 0) + axes().u * 1.5)
        if frame == 2 {
            let at = place(view, muzzle(dx: recoil(.fighting, 2)))
            let (degrees, k) = AlchemyViews.along(view, bore)
            var star: [P] = [], core: [P] = []
            for i in 0..<14 {
                let angle = degrees + Double(i) * 360 / 14
                let forward = max(0, cos(Double(i) * 360 / 14 * .pi / 180)) * k
                let r = i % 2 == 0 ? 8 + 22 * forward : 3.8
                star.append(at + P.direction(angle) * r + P.direction(degrees) * (3 * k))
                core.append(at + P.direction(angle) * (i % 2 == 0 ? r * 0.5 : 1.8) + P.direction(degrees) * (3 * k))
            }
            svg.polygon(star.map { $0 + P(-0.6, 0.6) }, fill: .colour(AlchemyWarriorsInk.flash))
            svg.polygon(star, fill: .none, stroke: .colour(Ink.line), width: 1.1)
            svg.polygon(core, fill: .colour(AlchemyWarriorsInk.flashCore))
            let v = place(view, vent(dx: recoil(.fighting, 2)))
            AlchemyWarriorsKit.smoke(&svg, at: v, puffs: [(P(0, -2.4), 2), (P(-1.4, -5.2), 1.6)], opacity: 0.9)
        }
        let ages: [Int: (spread: Double, rise: Double, size: Double, opacity: Double)] = [
            2: (0.3, 0, 0.75, 0.95), 3: (0.62, 2, 1.2, 0.95), 4: (0.78, 6, 1.35, 0.92), 5: (0.86, 10, 1.42, 0.8),
            6: (0.9, 14, 1.45, 0.62), 7: (0.92, 18, 1.45, 0.45), 8: (0.93, 21, 1.4, 0.3), 9: (0.94, 24, 1.35, 0.16),
        ]
        guard let age = ages[frame] else { return }
        let base: [(P, Double)] = [(P(6, 0), 5), (P(14, -3), 7), (P(24, 0.6), 8), (P(34, -5), 7.4), (P(43, 1), 6.4), (P(22, -10), 6),
                                   (P(33, 4.4), 5.2), (P(48, -5), 5.4), (P(12, -11), 4.6)]
        // Seen end on, between the crew, it billows and rises over the gun.
        let across = c < 0.3 ? 0.4 : max(c, 0.55)
        let puffs = base.map { p, r in (P((p.x - (c < 0.3 ? 24 : 0)) * age.spread * across, p.y * (0.7 + age.spread * 0.3) - age.rise * (0.5 + p.x / 50)), r * age.size) }
        AlchemyWarriorsKit.smoke(&svg, at: origin + P(0, -(1 - c) * age.spread * 30), puffs: puffs, opacity: age.opacity)
        if frame == 3 {
            let v = place(view, vent(dx: recoil(.fighting, 3)))
            AlchemyWarriorsKit.smoke(&svg, at: v, puffs: [(P(-0.6, -4), 2.4), (P(0.8, -7.6), 1.8)], opacity: 0.7)
        }
    }

    // MARK: The crew in the other views

    /// A crewman's arms in this view, behind the body or before it, each in its sleeve of `colour` (the far one in `far`).
    static func crewArms(_ d: inout Drawing, behind: Bool, colour: String, far: String) {
        for limb in AlchemyViews.arms(d, behind: behind) {
            let points = limb.points
            let forearm = BronzePeopleKit.length(points[2] - points[1])
            let cuffAt = forearm > 2 ? points[2] + (points[1] - points[2]) * (2 / forearm) : points[2]
            d.svg.line([points[0], points[1], cuffAt], stroke: .colour(Ink.line), width: 4.4)
            d.svg.line([points[0], points[1], cuffAt], stroke: .colour(limb.right ? colour : far), width: 2.8)
            d.svg.line([cuffAt, points[2]], stroke: .colour(Ink.line), width: 1.9)
            d.hand(points[2])
        }
    }

    /// A crewman's legs in this view: breeches of `breeches` to the knee, pale stockings and shoes.
    static func crewLegs(_ d: inout Drawing, breeches: String) {
        let legs = AlchemyViews.legs(d)
        d.svg.group(turned: -AlchemyViews.lean(d), about: Drawing.hips) { svg in
            for (i, leg) in legs.enumerated() {
                let near = i == legs.count - 1
                let hip = leg.root, knee = leg.joint, foot = leg.end, toe = leg.toe ?? foot
                let run = BronzePeopleKit.length(foot - knee)
                let u = run > 0.01 ? (foot - knee) * (1 / run) : P(0, 1)
                svg.line([knee, foot], stroke: .colour(Ink.line), width: 2.8)
                svg.line([knee + u * 1.6, foot - u * 0.6], stroke: .colour(AlchemyWarriorsInk.linen), width: 1.2)
                svg.line([hip, knee, knee + u * 1.6], stroke: .colour(Ink.line), width: 5)
                svg.line([hip, knee, knee + u * 1.6], stroke: .colour(near ? breeches : AlchemyWarriorsInk.darkLeather), width: 3.4)
                if abs(toe.x - foot.x) > 1.2 {
                    let dir = toe.x > foot.x ? 1.0 : -1.0
                    BronzePeopleProps.shape(&svg, [foot + P(-1.8 * dir, -1.6), foot + P(2.4 * dir, -1.4), toe + P(0.9 * dir, 0), toe + P(0.5 * dir, 1.2),
                                                   foot + P(-1.6 * dir, 1.2)], fill: .colour(AlchemyWarriorsInk.darkLeather), width: 0.9)
                } else {
                    svg.ellipse(foot + P(0, 0.2), 2.2, 1.5, fill: .colour(AlchemyWarriorsInk.darkLeather), stroke: .colour(Ink.line), width: 0.9)
                }
            }
        }
    }

    /// The gunner in this view: his coat, belt and powder horn, the linstock
    /// or the handspike in his hand, his beard and his felt cap. `at` is where
    /// he stands on the screen; the handspike reaches from his hand to the trail.
    static func gunnerInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int, origin: P, at: P, dx: Double) {
        let view = d.view
        let place = linstockPlace(pose, frame)
        let coat = [P(-9.2, -47.4), P(9.2, -47.4), P(11.6, -30), P(13.8, -16.4), P(-14.2, -16.4)]
        d.figure { d in
            func linstock(_ d: inout Drawing) {
                let hand = AlchemyViews.world(d, d.hand(front: true))
                let (degrees, k) = AlchemyViews.along(view, place.degrees)
                let u = P.direction(degrees) * max(k, 0.25)
                let back = AlchemyViews.world(d, d.hand(front: false))
                AlchemyViews.inPicture(&d) { svg in
                    if pose == .fighting && frame >= 9 {
                        // The handspike from his hand to the trail's end.
                        let foot = AlchemyViews.project(view, -49.2 + dx, -3.4, 0).point - P(at.x, 0)
                        svg.line([foot, hand], stroke: .colour(Ink.line), width: 2.8)
                        svg.line([foot, hand], stroke: .colour(AlchemyWarriorsInk.paleWood), width: 1.4)
                    }
                    if pose == .walking {
                        AlchemyViews.foreshortened(&svg, at: back, degrees: degrees, by: max(k, 0.25)) { svg in
                            staffOfMatch(&svg, butt: back - P.direction(degrees) * 14, degrees: degrees, frame: frame)
                        }
                    } else if place.grip == nil {
                        // Planted beside him, upright, its butt on the ground before his right foot.
                        let butt = AlchemyViews.project(view, planted.x - origin.x - 7.5, 0, Drawing.shoulderSpread).point
                        AlchemyViews.foreshortened(&svg, at: butt, degrees: degrees, by: max(k, 0.25)) { svg in
                            staffOfMatch(&svg, butt: butt, degrees: degrees, frame: frame)
                        }
                    } else {
                        let butt = hand - u * (place.grip ?? 33)
                        AlchemyViews.foreshortened(&svg, at: butt, degrees: degrees, by: max(k, 0.25)) { svg in
                            staffOfMatch(&svg, butt: butt, degrees: degrees, frame: frame)
                        }
                    }
                }
            }
            crewArms(&d, behind: true, colour: AlchemyWarriorsInk.teal, far: AlchemyWarriorsInk.darkTeal)
            if d.armBehind(front: true) { linstock(&d) }
            crewLegs(&d, breeches: AlchemyWarriorsInk.buff)
            d.garment(colour: [P(-13, -46.4), P(9.4, -48.4), P(12.4, -30), P(15, -15.4), P(-15.6, -15)], outline: coat,
                      fill: .colour(AlchemyWarriorsInk.teal)) { d in
                d.band([P(-13.8, -18.9), P(13.6, -18.9), P(13.6, -17.9), P(-13.8, -17.9)], fill: .colour(AlchemyWarriorsInk.paleTeal))
                for i in 0..<4 {
                    let (b, depth) = AlchemyViews.around(view, -43.6 + Double(i) * 3.6, angle: 6, on: coat)
                    if depth > 0.5 {
                        d.svg.circle(d.up(b), 0.7, fill: .colour(AlchemyWarriorsInk.gilt), stroke: .colour(Ink.line), width: 0.4)
                    }
                }
            }
            let belt = [P(-13.2, -30.6), P(11.8, -30.8), P(11.8, -29), P(-13.2, -28.8)]
            d.band(belt, fill: .colour(AlchemyWarriorsInk.leather))
            d.svg.polygon(d.turned(belt).map(d.up), fill: .none, stroke: .colour(Ink.line), width: 0.9)
            // The powder horn on its cord at his left hip.
            let (horn, hornDepth) = AlchemyViews.around(view, -24.6, angle: 120, on: coat, side: -1)
            if hornDepth > -1 {
                AlchemyWarriorsKit.shape(&d.svg, [horn + P(-3, -1.4), horn + P(3, -1.6), horn + P(2.6, 0.4), horn + P(-2, 1.4)],
                                         fill: .colour(AlchemyWarriorsInk.light), width: 0.8)
            }
            if !d.armBehind(front: true) { linstock(&d) }
            crewArms(&d, behind: false, colour: AlchemyWarriorsInk.teal, far: AlchemyWarriorsInk.darkTeal)
            d.head(nose: .bulb, hair: { d in
                switch d.view {
                case .back: d.svg.path("M-10,-57 C-10.6,-53 -8,-50.4 0,-50 C8,-50.4 10.6,-53 10,-57 C5,-55.4 -5,-55.4 -10,-57 Z", fill: .colour(AlchemyWarriorsInk.hair))
                case .backQuarter: d.svg.path("M-10,-57 C-10.6,-53 -8,-50.4 -1,-50 C4,-50.4 6.4,-53 6,-57 C2,-55.6 -5,-55.4 -10,-57 Z", fill: .colour(AlchemyWarriorsInk.hair))
                default: break
                }
            }, features: { d in
                // A full beard round the chin.
                let (left, right, centre): (Double, Double, Double)
                switch d.view {
                case .front: (left, right, centre) = (-8, 8, 0)
                case .frontQuarter: (left, right, centre) = (-4.6, 10.4, 5.4)
                default: return
                }
                d.svg.path("M\(num(left)),-54 C\(num(left)),-47 \(num(centre - 4)),-44 \(num(centre)),-44 C\(num(centre + 4)),-44 \(num(right)),-47 \(num(right)),-54 "
                           + "C\(num(right - 2)),-50.6 \(num(centre + 3)),-49.4 \(num(centre)),-49.6 C\(num(centre - 3)),-49.4 \(num(left + 2)),-50.6 \(num(left)),-54 Z",
                           fill: .colour(AlchemyWarriorsInk.hair), stroke: .colour(Ink.line), width: 0.5)
            }, brow: { d in
                d.svg.path("M1.6,-63.6 q3.2,-1.4 6.6,-0.4", stroke: .colour(Ink.line), width: 1.7)
            }, over: { d in
                // The felt cap with its turned-up brim.
                let cap = AlchemyViews.dome(d.view, radius: 11, front: -66, back: -63, top: -75, crest: -1)
                BronzePeopleProps.shape(&d.svg, cap, fill: .colour(AlchemyWarriorsInk.leather), width: 1.3)
                let upper = AlchemyViews.rim(d.view, radius: 12, front: -68, back: -64.4)
                let lower = AlchemyViews.rim(d.view, radius: 11.8, front: -65.4, back: -61.6)
                BronzePeopleProps.shape(&d.svg, upper + lower.reversed(), fill: .colour(AlchemyWarriorsInk.darkLeather), width: 1.1)
            })
        }
    }

    /// The rammer in this view (his own, the view of his facing): his jerkin
    /// over the shirt, his moustache, and the wine stocking cap with its tassel.
    static func rammerInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let view = d.view
        let jerkin = [P(-8.8, -47.4), P(8.8, -47.4), P(11.4, -27.4), P(-13, -27.4)]
        d.figure { d in
            crewArms(&d, behind: true, colour: AlchemyWarriorsInk.linen, far: AlchemyWarriorsInk.paleBuff)
            crewLegs(&d, breeches: AlchemyWarriorsInk.darkTeal)
            d.garment(colour: [P(-12.2, -32), P(11.8, -32.2), P(13.4, -17), P(-14.2, -16.6)],
                      outline: [P(-11.2, -31.6), P(11, -31.6), P(12.4, -18), P(-13, -18)], fill: .colour(AlchemyWarriorsInk.linen))
            d.garment(colour: [P(-12.6, -46.6), P(9.4, -48.4), P(12.2, -26.6), P(-13.8, -26.2)], outline: jerkin,
                      fill: .colour(AlchemyWarriorsInk.buff)) { d in
                var lacing = PathData()
                for i in 0..<4 {
                    let y = -44 + Double(i) * 4
                    let a = AlchemyViews.around(view, y, angle: 12, on: jerkin), b = AlchemyViews.around(view, y + 1.6, angle: 12, on: jerkin, side: -1)
                    if a.depth > 0.5 && b.depth > 0.5 { lacing.move(d.up(a.point)); lacing.line(d.up(b.point)) }
                }
                d.svg.path(lacing, stroke: .colour(AlchemyWarriorsInk.darkLeather), width: 0.7)
            }
            AlchemyWarriorsKit.shape(&d.svg, d.turned([P(-5.6, -49), P(7.6, -49.2), P(6.4, -46.2), P(-5, -46)]).map(d.up),
                                     fill: .colour(AlchemyWarriorsInk.linen), width: 0.9)
            crewArms(&d, behind: false, colour: AlchemyWarriorsInk.linen, far: AlchemyWarriorsInk.paleBuff)
            let flop = pose == .walking ? 1.2 * BronzePeopleKit.wave(frame, 0.2) : 0.3 * BronzePeopleKit.wave(frame)
            d.head(nose: .button, hair: { d in
                switch d.view {
                case .back: d.svg.path("M-10,-58 C-10.6,-54 -8,-51 0,-50.6 C8,-51 10.6,-54 10,-58 C5,-56.4 -5,-56.4 -10,-58 Z", fill: .colour(AlchemyWarriorsInk.hair))
                case .backQuarter: d.svg.path("M-10,-58 C-10.6,-54 -8,-51 -1,-50.6 C4,-51 6.4,-54 6,-58 C2,-56.4 -5,-56.4 -10,-58 Z", fill: .colour(AlchemyWarriorsInk.hair))
                default: break
                }
            }, features: { d in
                let centre: Double
                switch d.view {
                case .front: centre = 0
                case .frontQuarter: centre = 5.4
                default: return
                }
                // A bushy moustache.
                d.svg.path("M\(num(centre)),-54 C\(num(centre - 3.6)),-55 \(num(centre - 6.4)),-53 \(num(centre - 6)),-50.4 C\(num(centre - 4)),-51.6 "
                           + "\(num(centre - 1.6)),-51.8 \(num(centre)),-51.4 C\(num(centre + 1.6)),-51.8 \(num(centre + 4)),-51.6 \(num(centre + 6)),-50.4 "
                           + "C\(num(centre + 6.4)),-53 \(num(centre + 3.6)),-55 \(num(centre)),-54 Z",
                           fill: .colour(AlchemyWarriorsInk.hair), stroke: .colour(Ink.line), width: 0.5)
            }, brow: { d in
                d.svg.path("M1.2,-63.4 q3.4,-2.2 7.4,-0.8", stroke: .colour(Ink.line), width: 2)
            }, over: { d in
                // The stocking cap of wine, flopping back over his left side, with its tassel.
                let cap = AlchemyViews.dome(d.view, radius: 11.2, front: -65.4, back: -61, top: -74.6, crest: -2)
                BronzePeopleProps.shape(&d.svg, cap, fill: .colour(AlchemyWarriorsInk.wine), width: 1.3)
                d.svg.line(AlchemyViews.rim(d.view, radius: 11.2, front: -65.4, back: -61.4), stroke: .colour(AlchemyWarriorsInk.darkWine), width: 1.6)
                let tassel = AlchemyViews.project(d.view, -15.4, -66 + flop, -4)
                let crown = AlchemyViews.project(d.view, -4, -73, 0).point
                let tip = tassel.point
                BronzePeopleProps.shape(&d.svg, [crown + P(-2, 0), crown + P(2, 0), tip + P(1.2, 0.6), tip + P(-1.2, -0.6)],
                                        fill: .colour(AlchemyWarriorsInk.wine), width: 1.1)
                d.svg.circle(tip + P(-0.4, 0.4), 1.8, fill: .colour(AlchemyWarriorsInk.light))
                d.svg.circle(tip, 1.8, fill: .none, stroke: .colour(Ink.line), width: 0.8)
            })
        }
    }
}
