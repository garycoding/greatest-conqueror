// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

// MARK: - The cavalryman (knight 3)

/// Knight 3: a cuirassier of the nineteenth century, the third of the knights
/// after the Iron horseman (`IronWarriorsHorseman`) and the Alchemy knight
/// (`AlchemyWarriorsKnight`), seated on the same horse (`BronzePeopleSteed`,
/// standing and moving as theirs does), here a grey charger, dappled on the
/// quarters, under a shabraque of the team's colour bordered in the light with
/// a pointed rear corner, a black saddle studded with brass and a soot
/// greatcoat rolled behind the cantle. Where the knight wore full plate, the
/// cavalryman keeps only its breast: a steel cuirass edged in brass over a
/// bottle-green tunic with brick cuffs, soot breeches and black jackboots with
/// steel spurs, white gauntlets; a steel helmet with a brass comb and peak, a
/// mane of horsehair of the team's colour falling from the comb, and brass
/// chin scales; a waxed moustache turned up at the ends; nose E. He carries a
/// sabre with a steel bowl guard and a slightly curved blade, its scabbard of
/// steel at his left hip. Standing, the horse breathes and he holds the sabre
/// at the carry, upright against his shoulder; walking, he charges at the
/// trot with the sword arm straight and the point lowered at the foe;
/// fighting, the horse paws the ground whilst he whirls the sabre back over
/// his head and cuts down past the horse's shoulder. The origin is on the
/// ground at the centre of the horse's hooves.
struct IndustrialNewPeopleCavalryman: PersonLook {
    /// The canvas and the horse's place are the knight's, whom he follows (`AlchemyWarriorsKnight`).
    static let canvas = AlchemyWarriorsKnight.canvas
    static let horseOrigin = AlchemyWarriorsKnight.horseOrigin
    static let horseScale = AlchemyWarriorsKnight.horseScale
    static let seatShift = AlchemyWarriorsKnight.seatShift

    /// The sabre's blade, from the guard to the point.
    static let blade = 24.0

    // MARK: The rider

    /// One frame of the cut: the hand and the blade's direction. He raises the
    /// sabre (0 to 2), whirls it back over his head (3 and 4), cuts down
    /// forward past the horse's shoulder (5 to 8, landing on 8) and recovers.
    static let cut: [(hand: P, degrees: Double)] = [
        (P(14, -39), 150), (P(12.4, -47), 172), (P(9, -53), 196), (P(6.4, -55.6), 222), (P(7.6, -56.4), 214), (P(13.6, -55), 172),
        (P(18.4, -50.4), 128), (P(21, -43), 76), (P(20.4, -38.4), 46), (P(18.4, -38.6), 62), (P(16.8, -40.4), 96), (P(15, -40), 128),
    ]

    /// The sabre at the carry, and at the charge: the hand and the blade's direction.
    static let carry = (hand: P(13.4, -35.6), degrees: 174.0)
    static let charge = (hand: P(21.8, -42.6), degrees: 84.0)

    func rig(_ pose: SpritePose, _ frame: Int) -> Rig? {
        var r = Moves.standing(pose == .standing ? frame : 0)
        r.backLeg = Limb(-4, 4); r.frontLeg = Limb(34, 50)
        r.mouth = .firm
        switch pose {
        case .standing:
            r.lean = 0
            r.frontArm = BronzePeopleKit.reach(IronWarriorsKit.frontShoulder(r), Self.carry.hand + P(0, -r.lift))
        case .walking:
            r.lean = 7
            r.lift = 0
            r.frontArm = BronzePeopleKit.reach(IronWarriorsKit.frontShoulder(r), Self.charge.hand + P(0, 0.5 * BronzePeopleKit.wave(frame, times: 2)))
            r.mouth = .shout
        case .fighting:
            let s = Self.cut[frame]
            r.lift = 0
            r.lean = [2, 0, -3, -5, -6, -4, 2, 8, 10, 7, 4, 3][frame]
            r.frontArm = BronzePeopleKit.reach(IronWarriorsKit.frontShoulder(r), s.hand, elbowUp: s.hand.y < -50)
            r.eyes = frame == 8 ? .wide : .open
            r.mouth = frame == 7 || frame == 8 ? .shout : .firm
        default:
            return nil
        }
        r.backArm = BronzePeopleKit.reach(IronWarriorsKit.backShoulder(r), P(9, -33))
        return r
    }

    /// The sabre's hand and direction for a frame of a pose, in the rider's own units.
    static func sabre(_ pose: SpritePose, _ frame: Int, hand: P) -> Double {
        switch pose {
        case .fighting: cut[frame].degrees
        case .walking: charge.degrees + 1.4 * BronzePeopleKit.wave(frame, 0.1, times: 2)
        default: carry.degrees
        }
    }

    static func horse(_ pose: SpritePose, _ frame: Int, far: Bool = false) -> BronzePeopleSteed {
        BronzePeopleSteed(at: horseOrigin, pose: IronWarriorsHorseman.horse(pose, frame), coat: far ? IndustrialNewPeopleInk.greyShade : IndustrialNewPeopleInk.grey,
                          shade: IndustrialNewPeopleInk.greyShade)
    }

    /// How far the cloth and the plume stream back.
    static func flutter(_ pose: SpritePose, _ frame: Int) -> Double {
        switch pose {
        case .walking: 1 + 0.6 * BronzePeopleKit.wave(frame, times: 2)
        case .fighting: 0.3 * sin(.pi * Double(frame) / 12)
        default: 0.1 * BronzePeopleKit.wave(frame)
        }
    }

    // MARK: Drawing

    func draw(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        if d.view != .side { drawInView(&d, pose, frame); return }
        let horse = Self.horse(pose, frame)
        let k = Self.horseScale
        let flutter = Self.flutter(pose, frame)
        d.svg.ellipse(P(0, 0.2), 38, 4.2, fill: .colour("#000000"), opacity: 0.13)
        d.svg.raw("<g transform=\"scale(\(num(k)))\">")
        horse.draw(&d.svg, near: true)
        Self.dapples(&d.svg, horse)
        Self.shabraque(&d.svg, horse, flutter: flutter)
        Self.saddle(&d.svg, horse)
        d.svg.raw("</g>")
        // The rider rises from the saddle with each stride of the trot.
        let rise = pose == .walking ? 1.1 + 1.1 * sin(4 * .pi * Double(frame) / 12 + 0.6) : 0
        let seat = horse.body(P(-1.6, -48.4) + Self.seatShift) * k + P(0, -rise)
        Self.rider(&d, pose, frame, at: seat - P(0, -15), bit: horse.mouth * k, flutter: flutter)
        if pose == .walking && frame % 6 == 1 {
            BronzePeopleProps.dust(&d.svg, at: horse.hoof(frame < 6 ? .hind : .fore) * k + P(-5, -1), size: 0.8, opacity: 0.45)
        }
        if pose == .fighting && frame == 11 {
            d.burst(at: horse.hoof(.fore) * k + P(1, -1), from: 100, to: 170, size: 0.9)
        }
    }

    /// The grey's dapples: rounds of a paler grey on the quarters and the shoulder.
    static func dapples(_ svg: inout SVG, _ horse: BronzePeopleSteed) {
        for (p, r) in [(P(-17.4, -38.6), 1.8), (P(-14, -33.4), 1.5), (P(-19.6, -33), 1.3), (P(-10.6, -29.4), 1.2), (P(15.4, -32.6), 1.4),
                       (P(18.6, -36.6), 1.2), (P(12.6, -29), 1.1)] {
            svg.circle(horse.body(p), r, fill: .colour(IndustrialNewPeopleInk.dapple), opacity: 0.85)
        }
    }

    /// The shabraque's outline in the horse's own units: from behind the
    /// withers along the back to the loins, down to a point behind, and along
    /// its lower edge to the front, which falls straight from the withers.
    static func shabraqueOutline(_ flutter: Double) -> [P] {
        let blow = P(-flutter * 1.2, -flutter * 0.3)
        return [P(10.6, -47.4), P(-14.6, -47.6), P(-17.2, -43) + blow * 0.4, P(-21.4, -29.6) + blow, P(-13.4, -31.6) + blow * 0.8,
                P(9.6, -31.4) + blow * 0.3, P(12, -39.6)]
    }

    /// The shabraque of the team's colour over the horse's side, its border
    /// in the light and a light star in its rear corner; blown back by `flutter`.
    static func shabraque(_ svg: inout SVG, _ horse: BronzePeopleSteed, flutter: Double, star: Bool = true) {
        let outline = shabraqueOutline(flutter).map { horse.body($0) }
        svg.polygon(outline.map { $0 + P(-0.7, 0.6) }, fill: .team)
        // The border, a little inside the edge.
        let inner = shabraqueOutline(flutter)
        let centre = P(-3, -40)
        let border = inner.map { horse.body($0 + (centre - $0) * 0.13) }
        svg.polygon(border, fill: .none, stroke: .colour(IndustrialWarriorsInk.light), width: 1.2)
        // The star in the rear corner.
        if star {
            let centre = horse.body(P(-13.6, -35.4) + P(-flutter * 0.8, 0))
            var points: [P] = []
            for i in 0..<10 { points.append(centre + P.direction(Double(i) * 36 + 180) * (i % 2 == 0 ? 2.6 : 1.1)) }
            svg.polygon(points, fill: .colour(IndustrialWarriorsInk.light))
        }
        // The fold where the rider's leg presses the cloth.
        svg.line([horse.body(P(-2, -46)), horse.body(P(-1, -33))], stroke: .colour(Ink.line), width: 0.9, opacity: 0.25)
        svg.polygon(outline, fill: .none, stroke: .colour(Ink.line), width: 1.3)
    }

    /// The saddle of black leather, studded with brass, and the greatcoat rolled behind its cantle.
    static func saddle(_ svg: inout SVG, _ horse: BronzePeopleSteed) {
        func at(_ p: P) -> P { horse.body(p + seatShift) }
        // The rolled greatcoat, strapped behind the cantle.
        let roll = [P(-17.4, -50.6), P(-10.6, -51.4), P(-10, -47.4), P(-17, -46.6)].map(at)
        BronzePeopleProps.shape(&svg, roll, fill: .colour(IndustrialWarriorsInk.soot), width: 1.1)
        svg.line([at(P(-14.4, -51.2)), at(P(-14.2, -46.8))], stroke: .colour(IndustrialWarriorsInk.darkLeather), width: 1.2)
        svg.path("M\(num(at(P(-17, -48.6)).x)),\(num(at(P(-17, -48.6)).y)) q3,-1 6.6,-0.6", stroke: .colour(IndustrialWarriorsInk.darkSoot), width: 0.7)
        let seat = [P(-10.6, -47.6), P(-10.8, -53.4), P(-8.4, -53.6), P(-6.4, -50), P(3.4, -50.2), P(5.6, -53.4), P(7.6, -52.8), P(7.2, -48.4),
                    P(6.4, -46.4), P(-9.2, -45.6)]
        BronzePeopleProps.shape(&svg, seat.map(at), fill: .colour(IndustrialPeopleInk.black), width: 1.2)
        for p in [P(-9.6, -50.6), P(6.2, -50.2)] {
            svg.circle(at(p), 0.7, fill: .colour(IndustrialWarriorsInk.brass))
        }
    }

    /// The rider, his figure's origin at `at`: the rein arm, the scabbard,
    /// the near leg in its boot and stirrup, the tunic and the cuirass, the
    /// head under its helmet, the sabre and the sword arm; then the reins.
    static func rider(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int, at: P, bit: P, flutter: Double) {
        let lean = d.rig.lean
        func world(_ p: P) -> P { at + p.rotated(lean, about: Drawing.hips) }
        d.svg.raw("<g transform=\"translate(\(num(at.x)),\(num(at.y))) rotate(\(num(lean)) \(num(Drawing.hips.x)) \(num(Drawing.hips.y)))\">")
        let j = d.joints
        // The rein arm, behind the body.
        arm(&d, [j.backShoulder, j.backElbow, j.backHand], near: false)
        // The empty scabbard, hanging back from the belt.
        scabbard(&d.svg, mouth: d.up(P(-5, -27.4)), degrees: -50, length: 1)
        // The near leg: the breeches, the jackboot, the stirrup and the spur.
        leg(&d.svg, hip: Joints.frontHip, knee: j.frontKnee, foot: j.frontFoot, run: 1, near: true)
        // The tunic's skirt over the thigh, the tunic and the cuirass over it.
        let blow = flutter * 0.8
        let skirt = [P(-11.6, -30.4), P(11.2, -30.6), P(14.8 - blow, -22.6), P(-8.6 - blow, -22.4)]
        d.garment(colour: skirt.map { $0 + P(-0.7, 0.6) }, outline: skirt, fill: .colour(IndustrialWarriorsInk.green), width: 1.4)
        let tunic = [P(-9, -47.4), P(9.2, -47.4), P(12, -29), P(-12.6, -29)]
        d.garment(colour: tunic.map { $0 + P(-0.7, 0.6) }, outline: tunic, fill: .colour(IndustrialWarriorsInk.green), width: 1.6)
        cuirass(&d)
        head(&d)
        let hand = j.frontHand
        let degrees = sabre(pose, frame, hand: hand)
        if pose == .fighting && frame == 7 { d.swish(around: j.frontShoulder, radius: 26, from: 200, to: 80) }
        sabre(&d.svg, at: hand, degrees: degrees)
        if pose == .fighting && frame == 8 { d.impact(at: hand + P.direction(degrees) * (blade + 4), size: 1) }
        arm(&d, [j.frontShoulder, j.frontElbow, hand], near: true)
        epaulette(&d.svg, at: j.frontShoulder)
        d.svg.raw("</g>")
        // The reins, from the gauntlet to the bit.
        let reinHand = world(j.backHand)
        var rein = PathData()
        rein.move(reinHand); rein.quad((reinHand + bit) * 0.5 + P(0, pose == .walking ? 1.6 : 3.4), bit)
        d.svg.path(rein, stroke: .colour(Ink.line), width: 0.9)
    }

    // MARK: The dress

    /// An arm in a bottle-green sleeve with a brick cuff, ending in a white gauntlet.
    static func arm(_ d: inout Drawing, _ points: [P], near: Bool) {
        IndustrialWarriorsKit.sleeve(&d, points, colour: near ? IndustrialWarriorsInk.green : IndustrialWarriorsInk.darkGreen,
                                     cuff: near ? IndustrialWarriorsInk.brick : IndustrialWarriorsInk.darkBrick, hand: false)
        gauntlet(&d.svg, at: points[2], degrees: BronzePeopleKit.degrees(from: points[1], to: points[2]))
    }

    /// A white gauntlet closed on a grip at `hand`, its cuff flaring back along `degrees`.
    static func gauntlet(_ svg: inout SVG, at hand: P, degrees: Double) {
        let u = P.direction(degrees), a = P(-u.y, u.x)
        let cuff = [hand - u * 1.2 + a * 1.9, hand - u * 4 + a * 2.7, hand - u * 4 - a * 2.7, hand - u * 1.2 - a * 1.9]
        BronzePeopleProps.shape(&svg, cuff, fill: .colour(IndustrialWarriorsInk.linen), width: 0.8)
        svg.circle(hand + P(-0.4, 0.4), 2, fill: .colour(IndustrialWarriorsInk.linen))
        svg.circle(hand, 2, fill: .none, stroke: .colour(Ink.line), width: 1)
    }

    /// A brass epaulette of scales over the shoulder.
    static func epaulette(_ svg: inout SVG, at s: P) {
        BronzePeopleProps.shape(&svg, [s + P(-3.8, -1.6), s + P(3.6, -2), s + P(4.4, 1.2), s + P(-3.4, 1.6)], fill: .colour(IndustrialWarriorsInk.brass),
                                width: 0.9)
        svg.path("M\(num(s.x - 2.6)),\(num(s.y + 0.2)) l2,0.9 l2,-0.9", stroke: .colour(IndustrialWarriorsInk.darkBrass), width: 0.6)
    }

    /// The cuirass: a breastplate of steel from the collar to the waist,
    /// edged in brass, with rivets along its edge, the shoulder strap of
    /// brass scales, and the light on its curve.
    static func cuirass(_ d: inout Drawing) {
        let plate = [P(-8.4, -46.6), P(4.6, -47.6), P(8.8, -45.2), P(11.6, -36.4), P(11, -29.6), P(-10.8, -29.4), P(-10.2, -38)]
        d.garment(colour: plate.map { $0 + P(-0.7, 0.6) }, outline: plate, fill: .colour(IndustrialWarriorsInk.steelLight), pattern: { d in
            d.svg.line([P(-10.4, -30.8), P(11, -31)].map(d.up), stroke: .colour(IndustrialWarriorsInk.brass), width: 1.1)
            d.svg.path("M\(num(4.6)),\(num(d.up(P(0, -44.6)).y)) C8.6,\(num(d.up(P(0, -41)).y)) 9.6,\(num(d.up(P(0, -37)).y)) 9.4,\(num(d.up(P(0, -33.6)).y))",
                       stroke: .colour(IndustrialWarriorsInk.linen), width: 1.2)
            d.svg.path("M-7,\(num(d.up(P(0, -40)).y)) C-6,\(num(d.up(P(0, -36)).y)) -4,\(num(d.up(P(0, -33.4)).y)) 0,\(num(d.up(P(0, -32.4)).y))",
                       stroke: .colour(IndustrialWarriorsInk.steel), width: 0.9)
            for p in [P(-8.6, -32.4), P(-3.2, -32.4), P(2.4, -32.4), P(7.8, -32.6)] {
                d.svg.circle(d.up(p), 0.6, fill: .colour(IndustrialWarriorsInk.brass), stroke: .colour(Ink.line), width: 0.3)
            }
        }, width: 1.4)
        // The collar of the tunic showing above the plate.
        d.svg.polygon([P(-5.6, -49.6), P(6.8, -49.4), P(6.4, -46.8), P(-5.4, -47)].map(d.up), fill: .colour(IndustrialWarriorsInk.brick),
                      stroke: .colour(Ink.line), width: 0.8)
    }

    /// A leg in soot breeches to the knee and a black jackboot from there to
    /// the foot, its top flaring over the knee, in its stirrup, with a steel
    /// spur at the heel; `run` is how much of the foot's length the view shows.
    static func leg(_ svg: inout SVG, hip: P, knee: P, foot: P, run: Double, near: Bool) {
        let cloth = near ? IndustrialWarriorsInk.soot : IndustrialWarriorsInk.darkSoot
        let u = P.direction(BronzePeopleKit.degrees(from: knee, to: foot)), a = P(-u.y, u.x)
        // The stirrup leather.
        svg.line([knee + P(-3, -4), foot + P(0.4, 1.6)], stroke: .colour(Ink.line), width: 1.6)
        svg.line([knee + P(-3, -4), foot + P(0.4, 1.6)], stroke: .colour(IndustrialWarriorsInk.leather), width: 0.7)
        svg.line([hip, knee], stroke: .colour(Ink.line), width: 6)
        svg.line([hip, knee], stroke: .colour(cloth), width: 4.4)
        // The jackboot, its flared top over the knee.
        let top = knee - u * 2.6
        BronzePeopleProps.shape(&svg, [top + a * 3.4, foot - u * 1 + a * 2.2, foot - u * 1 - a * 2.2, top - a * 3.2], fill: .colour(IndustrialPeopleInk.black),
                                width: 1, shift: P(-0.4, 0.3))
        svg.line([top + a * 3.4, top - a * 3.2], stroke: .colour(IndustrialPeopleInk.blackSheen), width: 0.8)
        let toe = max(run, 0.25)
        BronzePeopleProps.shape(&svg, [foot + P(-2.4, -1.6), foot + P(2, -1.6), foot + P(2 + 4 * toe, 0.2), foot + P(1.6 + 4 * toe, 1.8), foot + P(-2.4, 1.8)],
                                fill: .colour(IndustrialPeopleInk.black), width: 1, shift: P(-0.4, 0.3))
        // The stirrup's tread, and the spur.
        svg.line([foot + P(-1, 2.8), foot + P(2.6 + 3 * toe, 2.8)], stroke: .colour(IndustrialWarriorsInk.steelDark), width: 1.4)
        // The spur points back from the heel, as far as the view shows the foot's length.
        let back = max(abs(run), 0.15)
        svg.line([foot + P(-2.2 * back, 0.8), foot + P(-5 * back, 1.2)], stroke: .colour(IndustrialWarriorsInk.steelLight), width: 0.9)
        svg.circle(foot + P(-5.4 * back, 1.2), 0.9, fill: .colour(IndustrialWarriorsInk.steelLight), stroke: .colour(Ink.line), width: 0.4)
    }

    /// The steel scabbard from `mouth` along `degrees`, shown `length` of its
    /// length (shorter where it points toward the viewer), with its brass locket.
    static func scabbard(_ svg: inout SVG, mouth: P, degrees: Double, length k: Double) {
        let u = P.direction(degrees) * max(k, 0.3), a = P(-P.direction(degrees).y, P.direction(degrees).x)
        let tip = mouth + u * 23
        BronzePeopleProps.shape(&svg, [mouth + a * 1.3, tip + a * 0.9 - u * 0.06, tip, tip - a * 0.9 - u * 0.06, mouth - a * 1.3],
                                fill: .colour(IndustrialWarriorsInk.steel), width: 1)
        svg.line([mouth + u * 1 + a * 1.4, mouth + u * 1 - a * 1.4], stroke: .colour(IndustrialWarriorsInk.brass), width: 1.4)
        svg.line([mouth + u * 4 + a * 0.4, tip - u * 2 + a * 0.3], stroke: .colour(IndustrialWarriorsInk.steelLight), width: 0.5)
    }

    /// The sabre from the hand along `degrees`: the grip in black leather
    /// bound with wire, the steel bowl guard over the knuckles, and the blade,
    /// curved a little toward its back, with a fuller.
    static func sabre(_ svg: inout SVG, at hand: P, degrees: Double) {
        let u = P.direction(degrees), a = P(-u.y, u.x)
        let pommel = hand - u * 3.6
        svg.line([pommel, hand + u * 1.6], stroke: .colour(Ink.line), width: 2.6)
        svg.line([pommel + u * 0.5, hand + u * 1.4], stroke: .colour(IndustrialPeopleInk.black), width: 1.3)
        let base = hand + u * 2.4
        // The blade: its edge on the side `-a`, its back bowed toward `a`.
        func along(_ t: Double, _ side: Double) -> P {
            let bow = 2.2 * t * t / (blade * blade) * blade * 0.18
            return base + u * t + a * (bow + side)
        }
        var edge: [P] = []
        for i in 0...6 { edge.append(along(blade * Double(i) / 6 * 0.94, -1.1 + 0.5 * Double(i) / 6)) }
        var back: [P] = []
        for i in 0...6 { back.append(along(blade * Double(6 - i) / 6 * 0.9, 0.9 - 0.3 * Double(6 - i) / 6)) }
        BronzePeopleProps.shape(&svg, edge + [along(blade, 0.4)] + back, fill: .colour(IndustrialWarriorsInk.steelLight), width: 0.9)
        svg.line((1...5).map { along(blade * Double($0) / 6 * 0.8, 0.2) }, stroke: .colour(IndustrialWarriorsInk.steel), width: 0.5)
        // The bowl guard: from the blade's root round the knuckles to the pommel.
        var bowl = PathData()
        bowl.move(base - a * 1.6); bowl.cubic(base - a * 5.4, pommel - a * 5.4, pommel - a * 0.6)
        bowl.line(pommel); bowl.cubic(pommel - a * 3.6, base - a * 3.4, base + a * 0.8); bowl.close()
        svg.path(bowl, fill: .colour(IndustrialWarriorsInk.steel), stroke: .colour(Ink.line), width: 0.9)
        svg.circle(pommel, 1.2, fill: .colour(IndustrialWarriorsInk.steel), stroke: .colour(Ink.line), width: 0.6)
    }

    /// The point of the sabre drawn by `sabre` with the same arguments.
    static func point(at hand: P, degrees: Double) -> P { hand + P.direction(degrees) * (2.4 + blade) }

    // MARK: The head

    /// The head: a waxed moustache, nose E, and the helmet with its mane.
    static func head(_ d: inout Drawing) {
        let hair = Paint.colour(IndustrialWarriorsInk.hair)
        d.head(nose: .line, behind: { d in
            mane(&d.svg, d)
        }, hair: { d in
            d.svg.path("M-11,-61.6 C-11.6,-58 -11.2,-55 -9.8,-52.6 L-8.4,-55.6 C-8.6,-58.6 -8.4,-61 -7.6,-62.6 Z", fill: hair)
        }, features: { d in
            // The moustache, its waxed ends turned up.
            d.svg.path("M4.4,-54.2 q3.8,-1.6 7.4,0.2 q2.2,-0.6 3,-3.2 q0.4,3.2 -2.4,4.8 q-3.4,0.8 -5.2,-0.2 q-1.4,1 -3.8,0.2 Z",
                       fill: hair, stroke: .colour(Ink.line), width: 0.5)
        }, brow: { d in
            d.svg.path("M1.8,-63.4 q3.4,-1.2 6.8,0.2", stroke: .colour(Ink.line), width: 1.6)
        }, over: { d in
            helmet(&d.svg)
        })
    }

    /// The mane of horsehair of the team's colour, falling from the comb down the back of the helmet.
    static func mane(_ svg: inout SVG, _ d: Drawing) {
        let sway = 0.8 * sin(d.phase * 4 * .pi)
        BronzePeopleProps.shape(&svg, fill: .team, width: 1.1) { o in
            var p = PathData()
            p.move(P(-1, -75.4) + o)
            p.cubic(P(-9, -76) + o, P(-14.6 + sway, -68) + o, P(-16 + sway, -54.6) + o)
            p.line(P(-13 + sway, -55.8) + o)
            p.cubic(P(-12, -64) + o, P(-8.6, -70) + o, P(-2.6, -72) + o)
            p.close()
            return p
        }
        svg.path("M-5,-74 C-10,-71.6 -12.6,-65 -13.6 ,-58", stroke: .colour(Ink.line), width: 0.6, opacity: 0.5)
    }

    /// The helmet: a steel skull over the head, a brass peak at the brow, the
    /// brass comb from the brow over the crown, and the brass chin scales.
    static func helmet(_ svg: inout SVG) {
        let ink = Paint.colour(Ink.line)
        BronzePeopleProps.shape(&svg, fill: .colour(IndustrialWarriorsInk.steelLight), width: 1.5) { o in
            var p = PathData()
            p.move(P(-11.2, -59.6) + o)
            p.cubic(P(-12.4, -66) + o, P(-7, -71.6) + o, P(0, -71.8) + o)
            p.cubic(P(6.6, -71.6) + o, P(10.8, -67.4) + o, P(11.2, -62.6) + o)
            p.line(P(-11, -60.6) + o)
            p.close()
            return p
        }
        svg.path("M-8.6,-63.6 C-7.6,-67.6 -3.6,-70 1,-70.2", stroke: .colour(IndustrialWarriorsInk.linen), width: 1.2)
        // The peak, edged in brass.
        svg.path("M8.8,-63.2 L15.4,-61.4 L14.6,-60.4 L8.4,-61.4 Z", fill: .colour(IndustrialWarriorsInk.brass), stroke: ink, width: 0.9)
        // The comb over the crown.
        svg.path("M9.4,-66.6 C6.4,-76.4 -3.6,-78.6 -8.6,-71.6", stroke: ink, width: 3.4)
        svg.path("M9.4,-66.6 C6.4,-76.4 -3.6,-78.6 -8.6,-71.6", stroke: .colour(IndustrialWarriorsInk.brass), width: 1.8)
        // The band at the rim, and the chin scales to the jaw.
        svg.path("M-11,-60.6 L11.2,-62.6", stroke: .colour(IndustrialWarriorsInk.brass), width: 1)
        svg.path("M-4.2,-60.8 C-3.4,-56 -0.6,-51.6 3.4,-49.4", stroke: ink, width: 2.2)
        svg.path("M-4.2,-60.8 C-3.4,-56 -0.6,-51.6 3.4,-49.4", stroke: .colour(IndustrialWarriorsInk.brass), width: 1.2)
        svg.circle(P(-4.2, -60.6), 1.3, fill: .colour(IndustrialWarriorsInk.brass), stroke: ink, width: 0.6)
    }
}

// MARK: - The cavalryman in the other views

extension IndustrialNewPeopleCavalryman {
    /// A frame of a pose seen from a view other than the side, as the knight
    /// is drawn (`AlchemyWarriorsKnight.drawInView`): from a quarter the horse
    /// is its side drawing shortened, its far side beyond it; from the front or
    /// behind it shows its whole width, the shabraque hanging at both sides.
    func drawInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int) {
        let view = d.view
        let (c, s) = AlchemyViews.turn(view)
        let gait = IronWarriorsHorseman.horse(pose, frame)
        let horse = Self.horse(pose, frame)
        let k = Self.horseScale
        let flutter = Self.flutter(pose, frame)
        d.svg.ellipse(P(0, 0.2), abs(38 * c) + abs(14 * s) + 2, 4.2, fill: .colour("#000000"), opacity: 0.13)
        let rise = pose == .walking ? 1.1 + 1.1 * sin(4 * .pi * Double(frame) / 12 + 0.6) : 0
        let seatPoint = horse.body(P(-1.6, -48.4) + Self.seatShift)
        let at = P(seatPoint.x * k * c, seatPoint.y * k - rise) - P(0, -15)
        let mouth = P(horse.mouth.x * c, horse.mouth.y) * k
        let w = AlchemyWarriorsKnight.horseHalf
        if abs(c) > 0.01 {
            var far = gait
            far.fore = gait.farFore; far.hind = gait.farHind
            let farHorse = BronzePeopleSteed(at: Self.horseOrigin, pose: far, coat: IndustrialNewPeopleInk.greyShade, shade: IndustrialNewPeopleInk.greyShade)
            d.svg.raw("<g transform=\"scale(\(num(k)))\">")
            d.svg.raw("<g transform=\"translate(\(num(w * s)),0) scale(\(num(c)),1)\">")
            d.svg.raw("<clipPath id=\"cavalry-far-side\"><rect x=\"-23.6\" y=\"-49\" width=\"50\" height=\"52\"/></clipPath>")
            d.svg.raw("<g clip-path=\"url(#cavalry-far-side)\">")
            farHorse.draw(&d.svg, near: false)
            Self.shabraque(&d.svg, farHorse, flutter: flutter, star: false)
            d.svg.raw("</g></g></g>")
            Self.riderLeg(&d, at: at, side: -1)
            var near = gait
            near.farFore = near.fore; near.farHind = near.hind
            let nearHorse = BronzePeopleSteed(at: Self.horseOrigin, pose: near, coat: IndustrialNewPeopleInk.grey, shade: IndustrialNewPeopleInk.greyShade)
            d.svg.raw("<g transform=\"scale(\(num(k)))\">")
            d.svg.raw("<g transform=\"translate(\(num(-w * s)),0) scale(\(num(c)),1)\">")
            nearHorse.draw(&d.svg, near: true)
            Self.dapples(&d.svg, nearHorse)
            Self.shabraque(&d.svg, nearHorse, flutter: flutter)
            Self.saddle(&d.svg, nearHorse)
            d.svg.raw("</g></g>")
            Self.riderInView(&d, pose, frame, at: at, bit: mouth, flutter: flutter)
        } else {
            let front = view == .front
            d.svg.raw("<g transform=\"scale(\(num(k)))\">")
            AlchemyWarriorsKnight.legsEndOn(&d.svg, horse, front ? .hind : .fore, near: false)
            if !front { Self.headEndOn(&d.svg, horse, front: false) }
            AlchemyWarriorsKnight.bodyEndOn(&d.svg, horse, front: front)
            AlchemyWarriorsKnight.legsEndOn(&d.svg, horse, front ? .fore : .hind, near: true)
            Self.clothEnd(&d.svg, horse, front: front, flutter: flutter)
            if !front { AlchemyWarriorsKnight.tailEndOn(&d.svg, horse) }
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
            BronzePeopleProps.dust(&d.svg, at: P(hoof.x * c - w * s, hoof.y) * k + P(-5 * c, -1), size: 0.8, opacity: 0.45)
        }
        if pose == .fighting && frame == 11 {
            let hoof = horse.hoof(.fore)
            d.burst(at: P(hoof.x * c - w * s, hoof.y) * k + P(1, -1), from: 100, to: 170, size: 0.9)
        }
    }

    /// The shabraque seen from the front or behind: hanging at both sides of
    /// the barrel from the back, its border in the light; from behind, its
    /// pointed corners; and the saddle and the rolled greatcoat across the back.
    static func clothEnd(_ svg: inout SVG, _ horse: BronzePeopleSteed, front: Bool, flutter: Double) {
        let ink = Paint.colour(Ink.line)
        let w = AlchemyWarriorsKnight.horseHalf
        let top = horse.body(P(0, -47.6)).y, bottom = horse.body(P(0, -31.4)).y
        let point = horse.body(P(0, -29.6)).y + flutter * 0.3
        for side in [-1.0, 1.0] {
            let inner = side * (w - 1.2), outer = side * (w + 1.8)
            var cloth: [P] = [P(inner, top - 0.6), P(outer, top + 1.4)]
            if front {
                cloth += [P(outer, bottom), P(inner, bottom - 0.4)]
            } else {
                cloth += [P(outer + side * 0.4, point), P(inner, bottom - 3)]
            }
            svg.polygon(cloth.map { $0 + P(-0.5, 0.5) }, fill: .team)
            svg.line([P(outer - side * 0.9, top + 2.6), P(outer - side * 0.9, (front ? bottom : point) - 1.4)], stroke: .colour(IndustrialWarriorsInk.light),
                     width: 1)
            svg.polygon(cloth, fill: .none, stroke: ink, width: 1.2)
        }
        // The saddle across the back, and the rolled greatcoat behind it, seen end on.
        let seat = horse.body(P(-1.6, -50) + seatShift).y
        if !front {
            BronzePeopleProps.shape(&svg, [P(-6.4, seat - 1.4), P(6.4, seat - 1.4), P(6.8, seat + 2.4), P(-6.8, seat + 2.4)],
                                    fill: .colour(IndustrialWarriorsInk.soot), width: 1)
            svg.line([P(-2.4, seat - 1.2), P(-2.4, seat + 2.2)], stroke: .colour(IndustrialWarriorsInk.darkLeather), width: 1)
            svg.line([P(2.4, seat - 1.2), P(2.4, seat + 2.2)], stroke: .colour(IndustrialWarriorsInk.darkLeather), width: 1)
        }
    }

    /// The head and neck seen from the front, the long grey face toward the
    /// viewer under its bridle; or from behind, only the poll and the ears beyond the body.
    static func headEndOn(_ svg: inout SVG, _ horse: BronzePeopleSteed, front: Bool) {
        let ink = Paint.colour(Ink.line)
        let poll = horse.head(P(22, -68)).y, eye = horse.head(P(28.8, -63.4)).y, muzzle = horse.head(P(39, -54)).y
        let withers = horse.body(P(12, -46)).y
        // The plume of the team's colour at the poll, as the horse wears it from the side.
        let sway = horse.pose.mane * 6
        // Seen from the front, the feathers fan out to the sides, clear of the rider's face behind.
        let angles: [Double] = front ? [-62, 62] : [-24, 0, 24]
        for (i, angle) in angles.enumerated() {
            svg.group(at: P(0, poll - 1), turned: angle + (i == 1 && !front ? 0 : sway * 0.3)) { svg in
                svg.ellipse(P(-0.5, -6.4), 2.3, 6, fill: .team)
                svg.ellipse(P(0, -7), 2.3, 6, fill: .none, stroke: ink, width: 0.9)
            }
        }
        let back = horse.pose.earBack
        for x in [-1.0, 1.0] {
            let tip = back ? P(x * 7, poll - 2.4) : P(x * 3.4, poll - 6)
            svg.polygon([P(x * 1.6, poll + 1), tip, P(x * 4.4, poll + 1.4)], fill: .colour(horse.coat), stroke: ink, width: 1)
        }
        if !front {
            svg.polygon([P(-2, poll + 1), P(2, poll + 1), P(2.6, withers), P(-2.6, withers)], fill: .colour(Ink.line))
            return
        }
        svg.polygon([P(-4.6, poll + 4), P(4.6, poll + 4), P(6.4, withers + 2), P(-6.4, withers + 2)], fill: .colour(horse.coat), stroke: ink, width: 1.4)
        var face = PathData()
        face.move(P(-4.8, poll + 1))
        face.cubic(P(-6.2, eye), P(-4.4, muzzle - 6), P(-3.8, muzzle - 2))
        face.cubic(P(-3.6, muzzle + 1.6), P(3.6, muzzle + 1.6), P(3.8, muzzle - 2))
        face.cubic(P(4.4, muzzle - 6), P(6.2, eye), P(4.8, poll + 1))
        face.cubic(P(2.4, poll - 1), P(-2.4, poll - 1), P(-4.8, poll + 1))
        face.close()
        svg.path(face, fill: .colour(horse.coat), stroke: ink, width: 1.5)
        // The paler muzzle, the eyes, the forelock.
        svg.ellipse(P(0, muzzle - 2.4), 3.2, 2.4, fill: .colour(IndustrialNewPeopleInk.dapple))
        for x in [-1.0, 1.0] {
            let c = P(x * 4.4, eye)
            if horse.pose.blink {
                svg.line([c + P(-1.1, 0), c + P(1.1, 0)], stroke: ink, width: 0.9)
            } else {
                svg.circle(c, 1.3, fill: .colour(Ink.eyeWhite), stroke: ink, width: 0.6)
                svg.circle(c + P(x * 0.3, 0.1), 0.65, fill: ink)
            }
        }
        svg.path("M-2,\(num(poll + 0.6)) q2,3 4,0 q-1,-2.4 -2,-2 q-1,-0.4 -2,2 Z", fill: ink)
        for x in [-1.6, 1.6] { svg.ellipse(P(x, muzzle - 1), 0.8, 0.5, fill: ink) }
        if horse.pose.mouthOpen { svg.ellipse(P(0, muzzle + 1.4), 2, 0.9, fill: ink) }
        // The bridle: the browband in brass, the cheek straps and the noseband, the bit's rings.
        svg.line([P(-4.4, poll + 3), P(4.4, poll + 3)], stroke: .colour(IndustrialWarriorsInk.brass), width: 1)
        svg.path("M-4.4,\(num(poll + 3)) L-3.6,\(num(muzzle - 2)) M4.4,\(num(poll + 3)) L3.6,\(num(muzzle - 2)) M-3.9,\(num(muzzle - 5)) L3.9,\(num(muzzle - 5))",
                 stroke: ink, width: 1)
        for x in [-4.2, 4.2] {
            svg.circle(P(x, muzzle - 1.4), 1, fill: .none, stroke: .colour(IndustrialWarriorsInk.steelLight), width: 0.7)
        }
    }

    /// One of the rider's legs in this view, on the horse's right side (`side`
    /// 1) or its left (-1), the foot in its stirrup.
    static func riderLeg(_ d: inout Drawing, at: P, side: Double) {
        let view = d.view
        let lean = AlchemyViews.lean(d)
        let j = d.joints
        func place(_ p: P, _ z: Double) -> P {
            at + AlchemyViews.project(view, p.x - 3.5, p.y, z).point.rotated(lean, about: Drawing.hips)
        }
        let hip = place(Joints.frontHip, side * Drawing.hipSpread)
        let knee = place(j.frontKnee, side * AlchemyWarriorsKnight.straddle), foot = place(j.frontFoot, side * (AlchemyWarriorsKnight.straddle + 0.6))
        leg(&d.svg, hip: hip, knee: knee, foot: foot, run: AlchemyViews.turn(view).c, near: side > 0)
    }

    /// The rider in this view: his rein arm, his legs about the horse, the
    /// tunic and the cuirass, the helmet, the sabre and the sword arm; the reins to the bit.
    static func riderInView(_ d: inout Drawing, _ pose: SpritePose, _ frame: Int, at: P, bit: P, flutter: Double) {
        let view = d.view
        let lean = AlchemyViews.lean(d)
        let quarter = abs(AlchemyViews.turn(view).c) > 0.01
        func world(_ p: P) -> P { at + p.rotated(lean, about: Drawing.hips) }
        if !quarter { riderLeg(&d, at: at, side: -1) }
        riderLeg(&d, at: at, side: 1)
        d.svg.raw("<g transform=\"translate(\(num(at.x)),\(num(at.y))) rotate(\(num(lean)) \(num(Drawing.hips.x)) \(num(Drawing.hips.y)))\">")
        func sleeve(_ d: inout Drawing, _ limb: AlchemyViews.Limb) {
            arm(&d, limb.points, near: limb.right)
            if limb.right || !quarter { epaulette(&d.svg, at: limb.root) }
        }
        func weapon(_ d: inout Drawing) {
            let hand = d.hand(front: true)
            let (degrees, k) = AlchemyViews.along(view, sabre(pose, frame, hand: hand))
            AlchemyViews.foreshortened(&d.svg, at: hand, degrees: degrees, by: max(k, 0.2)) { svg in
                sabre(&svg, at: hand, degrees: degrees)
            }
            if pose == .fighting && frame == 8 {
                d.impact(at: hand + P.direction(degrees) * ((2.4 + blade) * max(k, 0.2) + 1.6), size: 1)
            }
            if pose == .walking && k < 0.4 && (view == .front || view == .frontQuarter) {
                // The sabre's point, toward the viewer.
                d.svg.circle(hand + P.direction(degrees) * ((2.4 + blade) * max(k, 0.2)), 1.3, fill: .colour(IndustrialWarriorsInk.steelLight),
                             stroke: .colour(Ink.line), width: 0.7)
            }
        }
        let weaponBehind = d.armBehind(front: true)
        for limb in AlchemyViews.arms(d, behind: true) {
            if limb.right { weapon(&d) }
            sleeve(&d, limb)
        }
        // The scabbard at his left hip.
        let coat = [P(-9, -47.4), P(9.2, -47.4), P(12, -29), P(-12.6, -29)]
        let (mouth, mouthDepth) = AlchemyViews.around(view, -27.4, angle: 100, on: coat, side: -1)
        let (down, dk) = AlchemyViews.along(view, -50)
        if mouthDepth < -2 { scabbard(&d.svg, mouth: mouth, degrees: down, length: dk) }
        let blow = flutter * 0.8
        let skirt = [P(-11.6, -30.4), P(11.2, -30.6), P(14.8 - blow, -22.6), P(-8.6 - blow, -22.4)]
        d.garment(colour: skirt.map { $0 + P(-0.7, 0.6) }, outline: skirt, fill: .colour(IndustrialWarriorsInk.green), width: 1.4)
        d.garment(colour: coat.map { $0 + P(-0.7, 0.6) }, outline: coat, fill: .colour(IndustrialWarriorsInk.green), width: 1.6)
        cuirassInView(&d)
        if mouthDepth >= -2 { scabbard(&d.svg, mouth: mouth, degrees: down, length: dk) }
        headInView(&d)
        for limb in AlchemyViews.arms(d, behind: false) {
            if limb.right && !weaponBehind { weapon(&d) }
            sleeve(&d, limb)
        }
        d.svg.raw("</g>")
        let reinHand = world(d.hand(front: false))
        var rein = PathData()
        rein.move(reinHand); rein.quad((reinHand + bit) * 0.5 + P(0, pose == .walking ? 1.6 : 3.4), bit)
        d.svg.path(rein, stroke: .colour(Ink.line), width: 0.9)
    }

    /// The cuirass turned by the view: the breastplate from the front, the
    /// backplate from behind, edged in brass with its rivets where they face
    /// the viewer, and the brick collar above it.
    static func cuirassInView(_ d: inout Drawing) {
        let plate = [P(-8.4, -46.6), P(4.6, -47.6), P(8.8, -45.2), P(11.6, -36.4), P(11, -29.6), P(-10.8, -29.4), P(-10.2, -38)]
        d.garment(colour: plate.map { $0 + P(-0.7, 0.6) }, outline: plate, fill: .colour(IndustrialWarriorsInk.steelLight), width: 1.4)
        let ink = Paint.colour(Ink.line)
        let lift = d.rig.lift
        let seen = IndustrialViews.seesFront(d)
        let rim = (-12...12).compactMap { i -> P? in
            seen ? IndustrialViews.front(d, -31 - lift * 0.2, Double(i) * 0.8, half: 11) : IndustrialViews.back(d, -31 - lift * 0.2, Double(i) * 0.8, half: 11)
        }
        if rim.count > 1 { d.svg.line(rim, stroke: .colour(IndustrialWarriorsInk.brass), width: 1.1) }
        for z in [-7.2, -2.4, 2.4, 7.2] {
            let p = seen ? IndustrialViews.front(d, -32.4 - lift * 0.2, z, half: 11) : IndustrialViews.back(d, -32.4 - lift * 0.2, z, half: 11)
            if let p { d.svg.circle(p, 0.6, fill: .colour(IndustrialWarriorsInk.brass), stroke: ink, width: 0.3) }
        }
        // The plate's ridge and its light, down the middle.
        if let top = seen ? IndustrialViews.front(d, -45 - lift, 0, half: 11) : IndustrialViews.back(d, -45 - lift, 0, half: 11),
           let bottom = seen ? IndustrialViews.front(d, -34 - lift * 0.4, 0, half: 11) : IndustrialViews.back(d, -34 - lift * 0.4, 0, half: 11) {
            d.svg.line([top + P(1.6, 0), bottom + P(1.6, 0)], stroke: .colour(IndustrialWarriorsInk.linen), width: 1.2)
            d.svg.line([top, bottom], stroke: .colour(IndustrialWarriorsInk.steel), width: 0.6)
        }
        d.svg.polygon([P(-5.8, -49.6 - lift), P(5.8, -49.6 - lift), P(5.6, -47 - lift), P(-5.6, -47 - lift)], fill: .colour(IndustrialWarriorsInk.brick),
                      stroke: ink, width: 0.8)
    }

    /// The head in this view: the hair at the nape, the waxed moustache where
    /// the face shows, and the helmet with its mane falling behind.
    static func headInView(_ d: inout Drawing) {
        let hair = Paint.colour(IndustrialWarriorsInk.hair)
        let maneBehind = IndustrialViews.seesFront(d)
        d.head(nose: .line, behind: { d in
            if maneBehind { maneInView(&d) }
        }, hair: { d in
            // Cropped hair under the helmet's rim.
            switch d.view {
            case .back: d.svg.path(IndustrialViews.backHair(d, rim: -60), fill: hair)
            case .backQuarter: d.svg.path(IndustrialViews.backHair(d, rim: -60, right: 5.4), fill: hair)
            default: IndustrialWarriorsViews.shortHair(&d, colour: hair)
            }
        }, features: { d in
            guard IndustrialViews.seesFront(d) else { return }
            let half = [P(0, -54.2), P(2.4, -54.8), P(4.8, -54), P(6.6, -55.2), P(7.6, -57.4), P(7.6, -54.6), P(5.4, -52.4), P(2.4, -52.6), P(0, -52)]
            d.svg.polygon(IndustrialViews.symmetric(d, half), fill: hair, stroke: .colour(Ink.line), width: 0.5)
        }, brow: { d in
            d.svg.path("M1.8,-63.4 q3.4,-1.2 6.8,0.2", stroke: .colour(Ink.line), width: 1.6)
        }, over: { d in
            helmetInView(&d)
            if !maneBehind { maneInView(&d) }
        })
    }

    /// The mane of horsehair seen from this side: falling from the comb's top
    /// down the back of the helmet, aside from a quarter, straight down from behind.
    static func maneInView(_ d: inout Drawing) {
        let view = d.view
        let (c, _) = AlchemyViews.turn(view)
        let sway = 0.8 * sin(d.phase * 4 * .pi)
        let root = P(-1 * c, -75.4)
        let end = AlchemyViews.project(view, -15, -55, 0).point + P(sway, 0)
        let spread = abs(end.x - root.x) < 6 ? 4.6 : 2.2
        BronzePeopleProps.shape(&d.svg, fill: .team, width: 1.1) { o in
            var p = PathData()
            p.move(root + P(-spread * 0.5, 0) + o)
            p.cubic(root + P(-spread * 1.4, 3) + o, end + P(-spread, -8) + o, end + P(-spread * 0.6, 0) + o)
            p.line(end + P(spread * 0.6, 0) + o)
            p.cubic(end + P(spread, -8) + o, root + P(spread * 1.4, 3) + o, root + P(spread * 0.5, 0) + o)
            p.close()
            return p
        }
    }

    /// The helmet in this view: the steel skull, the brass comb over the
    /// crown, the brass band at the rim, the peak where the brow shows, and
    /// the chin scales from both sides to the jaw.
    static func helmetInView(_ d: inout Drawing) {
        let view = d.view
        let (c, _) = AlchemyViews.turn(view)
        let ink = Paint.colour(Ink.line)
        let skull = AlchemyViews.dome(view, radius: 11.2, front: -62.6, back: -60, top: -71.8, crest: 0)
        BronzePeopleProps.shape(&d.svg, skull, fill: .colour(IndustrialWarriorsInk.steelLight), width: 1.5)
        d.svg.line(AlchemyViews.rim(view, radius: 11, front: -62.4, back: -60.4, steps: 8), stroke: .colour(IndustrialWarriorsInk.brass), width: 1)
        d.svg.path("M\(num(-7.4 + 2 * c)),-63.4 C\(num(-6.4 + 2 * c)),-67 \(num(-3 + 2 * c)),-69.4 \(num(1.6 + 2 * c)),-69.6",
                   stroke: .colour(IndustrialWarriorsInk.linen), width: 1.2)
        // The comb, from the brow over the crown to the back.
        let combFront = AlchemyViews.onRim(view, radius: 9.6, front: -66.6, back: -66.6, phi: 0)
        let combBack = AlchemyViews.onRim(view, radius: 8.6, front: -71.6, back: -71.6, phi: .pi)
        let combTop = P(0.6 * c, -78)
        let comb = "M\(num(combBack.point.x)),\(num(combBack.point.y)) Q\(num(combTop.x)),\(num(combTop.y)) \(num(combFront.point.x)),\(num(combFront.point.y))"
        d.svg.path(comb, stroke: ink, width: 3.4)
        d.svg.path(comb, stroke: .colour(IndustrialWarriorsInk.brass), width: 1.8)
        // The peak.
        if IndustrialViews.seesFront(d), let peak = IndustrialViews.peak(d, rim: -62.4, reach: 5.4, drop: 1.8, half: 9) {
            d.svg.path(peak, fill: .colour(IndustrialWarriorsInk.brass), stroke: ink, width: 0.9)
        }
        // The chin scales, from the rosettes at the sides down to the jaw.
        for phi in [Double.pi / 2, -Double.pi / 2] {
            let rosette = AlchemyViews.onRim(view, radius: 10.6, front: -60.8, back: -60.8, phi: phi)
            guard rosette.depth > -2 else { continue }
            let chin = P(rosette.point.x * 0.55 + (IndustrialViews.seesFront(d) ? 2.6 * c : 0), -49.6)
            d.svg.line([rosette.point, chin], stroke: ink, width: 2.2)
            d.svg.line([rosette.point, chin], stroke: .colour(IndustrialWarriorsInk.brass), width: 1.2)
            d.svg.circle(rosette.point, 1.3, fill: .colour(IndustrialWarriorsInk.brass), stroke: ink, width: 0.6)
        }
    }
}
