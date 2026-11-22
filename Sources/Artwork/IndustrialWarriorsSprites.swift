// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

/// The rifleman, the field gun with its crew of two and the armoured car of
/// the Industrial age, drawn in the Cartoon Modern style of docs/art-style.md
/// on the jointed figure every age shares (Figure.swift), one age on from the
/// Alchemy warriors (`AlchemyWarriorSprites`).
///
/// A warfighter keeps the look of its own age (`SpriteSubject.of(_:ownerAge:)`),
/// so this source supplies `SpriteSubject.unit(kind, .industrial)` for those
/// three kinds in the poses standing, walking and fighting, each a cycle of 12
/// frames (`SpriteKey.frame` 0 to 11). The warfighters never work, and the
/// drawing falls back to standing where a pose is missing, so the working pose
/// is not supplied. Every other key returns nil.
///
/// Each kind it has finished is drawn in all five views (ruled 2026-11-21),
/// the key's view passed to the drawing (`viewed`); for the rest it answers
/// the side alone.
///
/// Each call draws its picture afresh, and the same key always gives the same
/// pixels. Nothing is kept here: the drawing keeps what it is given.
public struct IndustrialWarriorSprites: ViewedSpriteSource {
    /// The poses this source supplies, each at frame 0.
    public let poses: [SpriteKey]
    private let supplied: Set<SpriteKey>

    public init(catalogue: Catalogue = .standard) {
        poses = SpriteKey.required(through: .industrial, catalogue: catalogue).filter { key in
            guard case .unit(let kind, .industrial) = key.subject, key.pose != .working else { return false }
            return IndustrialWarriorsLooks.look(kind) != nil
        }
        supplied = Set(poses)
    }

    /// Every key this source supplies: each pose at each of its frames.
    public var keys: [SpriteKey] {
        poses.flatMap { pose in (0..<SpriteKey.framesPerPose).map { SpriteKey(pose.subject, pose.pose, frame: $0) } }
    }

    /// The kinds drawn in all five views so far.
    static let viewed: Set<UnitKind> = [.rifleman, .fieldGun, .armouredCar]

    public func drawsViews(of subject: SpriteSubject) -> Bool {
        if case .unit(let kind, .industrial) = subject { return Self.viewed.contains(kind) }
        return false
    }

    public func sprite(_ key: SpriteKey) -> SpriteImage? {
        guard (0..<SpriteKey.framesPerPose).contains(key.frame),
              supplied.contains(SpriteKey(key.subject, key.pose, frame: 0)),
              key.view == .side || drawsViews(of: key.subject),
              case .unit(let kind, _) = key.subject,
              let look = IndustrialWarriorsLooks.look(kind) else { return nil }
        let canvas = IndustrialWarriorsLooks.canvas(kind)
        return look.render(key.pose, frame: key.frame, canvas: canvas, view: key.view)?.sprite(anchor: canvas.anchor)
    }
}

/// Which look draws each kind, and on what canvas.
enum IndustrialWarriorsLooks {
    static func look(_ kind: UnitKind) -> (any PersonLook)? {
        switch kind {
        case .rifleman: IndustrialWarriorsRifleman()
        case .fieldGun: IndustrialWarriorsFieldGun()
        case .armouredCar: IndustrialWarriorsArmouredCar()
        default: nil
        }
    }

    static func canvas(_ kind: UnitKind) -> Canvas {
        switch kind {
        case .fieldGun: IndustrialWarriorsFieldGun.canvas
        case .armouredCar: IndustrialWarriorsArmouredCar.canvas
        default: IndustrialWarriorsRifleman.canvas
        }
    }
}

/// The colours of the Industrial age (brick, bottle green, soot and the light;
/// docs/art-style.md, "Palettes"), with the shades that webbing, brass, gun
/// steel, rubber and smoke need. The line, the skin and the eye are the ones
/// every age shares (`Ink`).
///
/// Brick is near Rome's red and Angkor's orange, and bottle green is a dark
/// cousin of Olmec's olive, so neither touches a part in the team's colour:
/// the cap band sits on a soot cap between piping of the light, the shield's
/// panel and the car's roundel are bordered in the light on grey steel.
enum IndustrialWarriorsInk {
    static let brick = "#c2683c"
    static let darkBrick = "#8f4626"
    static let paleBrick = "#d98a62"
    /// Bottle green, which replaced the palette's navy (ruled 2026-11-19):
    /// the navy was almost Shang's colour.
    static let green = "#2f5a46"
    static let darkGreen = "#1f3f31"
    static let paleGreen = "#5d8572"
    static let soot = "#6b6258"
    static let darkSoot = "#4a433c"
    static let paleSoot = "#948a7e"
    static let light = "#efe0c2"
    /// The webbing of belts, straps and pouches.
    static let buff = "#c49a62"
    static let darkBuff = "#946c3e"
    static let paleBuff = "#dcbd8c"
    static let leather = "#6b4226"
    static let darkLeather = "#3e2a1c"
    static let brass = "#d0a54a"
    static let darkBrass = "#9c7630"
    /// Gun steel, blued and grey.
    static let steel = "#7c8084"
    static let steelLight = "#b3b6b4"
    static let steelDark = "#4b4e50"
    /// The grey of the gun's shield and the car's armour.
    static let plate = "#8b8a80"
    static let plateLight = "#b2ae9f"
    static let plateDark = "#5e5d55"
    static let wood = "#8a5a33"
    static let darkWood = "#5c3c22"
    static let paleWood = "#c7a06a"
    static let canvas = "#d8cba8"
    static let rubber = "#3a332d"
    static let linen = "#f2ead8"
    static let hair = "#4a3020"
    static let greyHair = "#8a8077"
    /// Powder smoke, and the flash of the shot.
    static let smoke = "#e6dfd0"
    static let smokeShade = "#c4bbaa"
    static let exhaust = "#b5ada0"
    static let flash = "#f4cf62"
    static let flashCore = "#fff3c8"
}

/// Geometry the Industrial warriors share: the uniform, smoke and flash, and
/// the spoked wheel.
enum IndustrialWarriorsKit {
    static let ink = Paint.colour(Ink.line)

    /// A closed shape whose colour sits out of register with its outline.
    static func shape(_ svg: inout SVG, _ points: [P], fill: Paint, width: Double = 1.2) {
        BronzePeopleProps.shape(&svg, points, fill: fill, width: width)
    }

    /// The opening of a group that places things in the picture's units inside
    /// a figure that leans and bobs (as the Alchemy warriors place their weapons).
    static func worldOpen(_ d: Drawing) -> String {
        "<g transform=\"rotate(\(num(-d.rig.lean)) \(num(Drawing.hips.x)) \(num(Drawing.hips.y))) translate(0,\(num(-d.bob)))\">"
    }

    /// How far a rig's figure is raised so that its lower foot rests on the ground.
    static func bob(_ r: Rig) -> Double {
        let j = Joints(r)
        return -max(j.backFoot.y, j.frontFoot.y)
    }

    /// The arm that puts a figure's hand at `target`, a point of the picture,
    /// for a figure standing at `origin`, facing right, or facing left (drawn
    /// mirrored) when `mirrored`.
    static func reach(_ r: Rig, front: Bool, origin: P = P(0, 0), mirrored: Bool = false, to target: P, elbowUp: Bool = false) -> Limb {
        let own = mirrored ? P(origin.x - target.x, target.y) : P(target.x - origin.x, target.y)
        let local = IronWarriorsKit.local(own, origin: P(0, 0), lean: r.lean, bob: bob(r))
        return BronzePeopleKit.reach(front ? IronWarriorsKit.frontShoulder(r) : IronWarriorsKit.backShoulder(r), local, elbowUp: elbowUp)
    }

    // MARK: The uniform

    /// An arm in a sleeve of `colour` with a cuff of `cuff`, and its hand
    /// unless `hand` is false.
    static func sleeve(_ d: inout Drawing, front: Bool, colour: String, cuff: String, hand: Bool = true) {
        let j = d.joints
        let points = front ? [j.frontShoulder, j.frontElbow, j.frontHand] : [j.backShoulder, j.backElbow, j.backHand]
        sleeve(&d, points, colour: colour, cuff: cuff, hand: hand)
    }

    /// The same sleeve through the shoulder, elbow and hand given on the screen, as an arm in another view has them.
    static func sleeve(_ d: inout Drawing, _ points: [P], colour: String, cuff: String, hand: Bool = true) {
        let cuffAt = points[2] + (points[1] - points[2]) * (2.2 / Joints.forearm)
        d.svg.line([points[0], points[1], cuffAt], stroke: .colour(Ink.line), width: 4.6)
        d.svg.line([points[0], points[1], cuffAt], stroke: .colour(colour), width: 3)
        d.svg.line([cuffAt, points[2]], stroke: .colour(Ink.line), width: 1.9)
        let along = P.direction(BronzePeopleKit.degrees(from: points[1], to: points[2])), across = P(-along.y, along.x)
        shape(&d.svg, [cuffAt + across * 2.4 - along * 1.4, cuffAt + across * 2.2 + along * 0.6, cuffAt - across * 2.2 + along * 0.6,
                       cuffAt - across * 2.4 - along * 1.4], fill: .colour(cuff), width: 0.8)
        if hand { d.hand(points[2]) }
    }

    /// Trousers of `colour` to the knee, puttees of soot wound below it, and boots.
    static func legs(_ d: inout Drawing, trousers: String, darkTrousers: String) {
        let j = d.joints
        d.svg.group(turned: -d.rig.lean, about: Drawing.hips) { svg in
            for front in [false, true] {
                let hip = front ? Joints.frontHip : Joints.backHip
                let knee = front ? j.frontKnee : j.backKnee, foot = front ? j.frontFoot : j.backFoot
                let u = P.direction(BronzePeopleKit.degrees(from: knee, to: foot)), a = P(-u.y, u.x)
                // The trousers, full over the thigh and bloused over the puttees' tops.
                svg.line([hip, knee, knee + u * 1.8], stroke: .colour(Ink.line), width: 5.4)
                svg.line([hip, knee, knee + u * 1.8], stroke: .colour(front ? trousers : darkTrousers), width: 3.8)
                // The puttees, wound from the ankle to below the knee.
                let top = knee + u * 1.6, ankle = foot - u * 1.4
                svg.line([top, ankle], stroke: .colour(Ink.line), width: 3.9)
                svg.line([top + u * 0.3, ankle], stroke: .colour(front ? IndustrialWarriorsInk.soot : IndustrialWarriorsInk.darkSoot), width: 2.4)
                var wraps = PathData()
                let length = BronzePeopleKit.length(ankle - top)
                var t = 1.6
                while t < length - 0.6 {
                    let c = top + u * t
                    wraps.move(c + a * 1.2); wraps.line(c - a * 1.2 + u * 1.1)
                    t += 2.2
                }
                svg.path(wraps, stroke: .colour(Ink.line), width: 0.5, opacity: 0.55)
                // The boot.
                BronzePeopleProps.shape(&svg, [foot + P(-1.8, -2.2), foot + P(2, -2), foot + P(5.6, -0.2), foot + P(5.4, 1.2), foot + P(-1.8, 1.2)],
                                        fill: .colour(IndustrialWarriorsInk.darkLeather), width: 0.9)
                svg.line([foot + P(-1.6, 1), foot + P(5.2, 1)], stroke: .colour(Ink.line), width: 0.8)
            }
        }
    }

    /// The tunic of `colour`: single-breasted with brass buttons, a stand
    /// collar of `collar`, shoulder straps and a skirt to the thigh; the
    /// buttons' column bends with `swing` (the walk's sway, or 0).
    static func tunic(_ d: inout Drawing, colour: String, dark: String, pale: String, collar: String, swing: Double) {
        d.garment(colour: [P(-12.6, -46.4), P(9.6, -48.2), P(12, -36), P(11.2, -27.6), P(13.6 + swing * 0.5, -13.2),
                           P(-14.2 + swing * 0.5, -12.8), P(-12.8, -28)],
                  outline: [P(-9.2, -47.4), P(9.2, -47.4), P(11.4, -36.4), P(10.6, -28.2), P(12.6 + swing * 0.5, -14.2),
                            P(-13.2 + swing * 0.5, -14.2), P(-12.2, -28.6)], fill: .colour(colour)) { d in
            // The front's edge, the side seam, the pleat of the skirt and the hem's shade.
            d.svg.line([d.up(P(8.4, -46.8)), d.up(P(10.2, -30)), P(11.8 + swing * 0.5, -14.6)], stroke: .colour(dark), width: 1)
            d.svg.line([P(-3.4, -26.8), P(-4.4 + swing * 0.4, -14.8)], stroke: .colour(dark), width: 0.8)
            d.svg.line([P(-12.8 + swing * 0.5, -15.6), P(12.2 + swing * 0.5, -15.6)], stroke: .colour(pale), width: 0.9)
            for i in 0..<5 {
                let y = -44.6 + Double(i) * 3.6
                d.svg.circle(d.up(P(8.2 + Double(i) * 0.45, y)), 0.75, fill: .colour(IndustrialWarriorsInk.brass), stroke: .colour(Ink.line), width: 0.4)
            }
            // A breast pocket with its flap.
            d.svg.polygon([P(0.6, -42.4), P(6.2, -42.6), P(6.2, -40.6), P(3.4, -39.8), P(0.6, -40.6)].map(d.up), fill: .colour(dark))
        }
        // The stand collar.
        shape(&d.svg, [d.up(P(-6.4, -49.6)), d.up(P(8.6, -49.8)), d.up(P(9.4, -46.4)), d.up(P(-6.8, -46.2))], fill: .colour(collar), width: 0.9)
        // The shoulder strap over the near shoulder.
        shape(&d.svg, [d.up(P(2.4, -47.6)), d.up(P(9.4, -47.6)), d.up(P(9.6, -45.6)), d.up(P(2.6, -45.6))], fill: .colour(pale), width: 0.7)
        d.svg.circle(d.up(P(3.4, -46.6)), 0.55, fill: .colour(IndustrialWarriorsInk.brass))
    }

    /// The waist belt of buff webbing with its brass buckle.
    static func belt(_ d: inout Drawing) {
        let points = [P(-13, -31), P(11.6, -31.2), P(11.4, -27.6), P(-13.2, -27.4)].map(d.up)
        shape(&d.svg, points, fill: .colour(IndustrialWarriorsInk.buff), width: 1)
        d.svg.line([d.up(P(-12.6, -29.3)), d.up(P(11, -29.4))], stroke: .colour(IndustrialWarriorsInk.darkBuff), width: 0.5, opacity: 0.7)
        let buckle = d.up(P(9.6, -29.4))
        d.svg.polygon([buckle + P(-1.6, -1.6), buckle + P(1.4, -1.6), buckle + P(1.4, 1.6), buckle + P(-1.6, 1.6)],
                      fill: .colour(IndustrialWarriorsInk.brass), stroke: .colour(Ink.line), width: 0.6)
    }

    /// A small box pouch of buff webbing, its flap fastened by a brass stud, centred on `c`.
    static func pouch(_ svg: inout SVG, at c: P, width w: Double = 5, height h: Double = 4.6) {
        shape(&svg, [c + P(-w / 2, -h / 2), c + P(w / 2, -h / 2), c + P(w / 2, h / 2), c + P(-w / 2, h / 2)], fill: .colour(IndustrialWarriorsInk.buff), width: 0.8)
        svg.polygon([c + P(-w / 2, -h / 2), c + P(w / 2, -h / 2), c + P(w / 2, -h / 2 + 2), c + P(0, -h / 2 + 2.6), c + P(-w / 2, -h / 2 + 2)],
                    fill: .colour(IndustrialWarriorsInk.darkBuff), stroke: .colour(Ink.line), width: 0.5)
        svg.circle(c + P(0, -h / 2 + 2.1), 0.5, fill: .colour(IndustrialWarriorsInk.brass))
    }

    /// A peaked cap: a soot crown, a band between piping of the light in the
    /// team's colour (or `band`), a black leather peak, and a
    /// brass badge. Drawn over the head (`Drawing.head`'s `over`).
    static func peakedCap(_ svg: inout SVG, band: Paint = .team, badge: Bool = true) {
        // The crown, a little wider at its top and tilted back.
        BronzePeopleProps.shape(&svg, fill: .colour(IndustrialWarriorsInk.soot), width: 1.3) { o in
            var p = PathData()
            p.move(P(-10.4, -65.6) + o)
            p.line(P(-11.8, -73.6) + o)
            p.cubic(P(-6, -76.6) + o, P(5, -76.8) + o, P(10.6, -73.8) + o)
            p.line(P(9.6, -66) + o)
            p.cubic(P(3, -64.8) + o, P(-4, -64.8) + o, P(-10.4, -65.6) + o)
            p.close()
            return p
        }
        svg.path("M-9.4,-73.6 C-4,-75.4 4,-75.4 8.6,-73.6", stroke: .colour(IndustrialWarriorsInk.paleSoot), width: 0.9)
        // The band, with piping of the light above and below it.
        BronzePeopleProps.shape(&svg, fill: band, width: 0.9, shift: P(-0.4, 0.3)) { o in
            var p = PathData()
            p.move(P(-10.6, -66.2) + o)
            p.cubic(P(-4, -65.2) + o, P(3, -65.2) + o, P(9.8, -66.4) + o)
            p.line(P(10.1, -70) + o)
            p.cubic(P(3, -68.8) + o, P(-4, -68.8) + o, P(-11.1, -69.8) + o)
            p.close()
            return p
        }
        svg.path("M-11.1,-70.4 C-4,-69.4 3,-69.4 10.1,-70.6", stroke: .colour(IndustrialWarriorsInk.light), width: 0.7)
        if badge {
            svg.ellipse(P(7.2, -70.9), 1.5, 1.7, fill: .colour(IndustrialWarriorsInk.brass), stroke: .colour(Ink.line), width: 0.6)
        }
        // The peak, black leather, jutting forward and down.
        BronzePeopleProps.shape(&svg, fill: .colour(IndustrialWarriorsInk.darkLeather), width: 1.1) { o in
            var p = PathData()
            p.move(P(4, -66.6) + o)
            p.cubic(P(9, -66.6) + o, P(14, -65.4) + o, P(17, -62.8) + o)
            p.cubic(P(13, -62.6) + o, P(8, -63.6) + o, P(4, -64.6) + o)
            p.close()
            return p
        }
        svg.path("M6,-65.6 C10,-65.4 13.4,-64.6 15.6,-63.2", stroke: .colour(IndustrialWarriorsInk.paleSoot), width: 0.5, opacity: 0.8)
    }

    // MARK: Smoke and the flash

    /// A cloud of smoke: puffs given as an offset from `origin` and a radius,
    /// outlined as one shape (every outline first, every fill over them), with
    /// a shade low in each puff.
    static func smoke(_ svg: inout SVG, at origin: P, puffs: [(P, Double)], opacity: Double, colour: String = IndustrialWarriorsInk.smoke) {
        guard opacity > 0.01, !puffs.isEmpty else { return }
        svg.raw("<g opacity=\"\(num(opacity))\">")
        for (offset, r) in puffs { svg.circle(origin + offset, r + 0.8, fill: ink) }
        for (offset, r) in puffs { svg.circle(origin + offset, r, fill: .colour(colour)) }
        for (offset, r) in puffs where r > 2.4 {
            svg.path(AlchemyWarriorsKit.arc(origin + offset, r * 0.62, from: 110, to: 30), stroke: .colour(IndustrialWarriorsInk.smokeShade), width: r * 0.22)
        }
        svg.raw("</g>")
    }

    /// A muzzle flash: a star stretched along `degrees`, `length` long ahead
    /// and `girth` to the sides, with a pale core; `seed` turns the points so
    /// that flash after flash differs.
    static func flash(_ svg: inout SVG, at origin: P, degrees: Double, length: Double, girth: Double, points: Int = 12, seed: Double = 0) {
        var star: [P] = [], core: [P] = []
        for i in 0..<points {
            let step = 360 / Double(points)
            let angle = degrees + Double(i) * step + seed
            let forward = max(0, cos((Double(i) * step + seed) * .pi / 180))
            let r = i % 2 == 0 ? girth + length * forward * forward : girth * 0.45
            star.append(origin + P.direction(angle) * r)
            core.append(origin + P.direction(angle) * (i % 2 == 0 ? r * 0.5 : girth * 0.2))
        }
        svg.polygon(star.map { $0 + P(-0.5, 0.5) }, fill: .colour(IndustrialWarriorsInk.flash))
        svg.polygon(star, fill: .none, stroke: ink, width: 0.9)
        svg.polygon(core, fill: .colour(IndustrialWarriorsInk.flashCore))
    }

    /// A spent brass case tumbling through the air at `p`, turned by `degrees`.
    static func spentCase(_ svg: inout SVG, at p: P, degrees: Double, length: Double = 3.2, width: Double = 1.3) {
        svg.group(at: p, turned: degrees) { svg in
            svg.polygon([P(-length / 2, -width / 2), P(length / 2, -width * 0.4), P(length / 2, width * 0.4), P(-length / 2, width / 2)],
                        fill: .colour(IndustrialWarriorsInk.brass), stroke: .colour(Ink.line), width: 0.5)
        }
    }

    // MARK: Wheels

    /// A spoked wheel of radius `r` with a rubber or iron tyre, turned by
    /// `degrees`: `spokes` spokes of `spoke` between a felloe and a hub, and a
    /// brass hub cap. The far wheel is drawn darker.
    static func wheel(_ svg: inout SVG, at c: P, radius r: Double, degrees: Double, spokes: Int, spoke: String, felloe: String, tyre: String,
                      tyreWidth: Double, far: Bool) {
        let step = 360 / Double(spokes)
        // The tyre.
        svg.circle(c, r - tyreWidth / 2, fill: .none, stroke: .colour(Ink.line), width: tyreWidth + 1.4)
        svg.circle(c, r - tyreWidth / 2, fill: .none, stroke: .colour(tyre), width: tyreWidth)
        let rim = r - tyreWidth
        for i in 0..<spokes {
            let u = P.direction(degrees + Double(i) * step)
            svg.line([c + u * 2.6, c + u * (rim - 1.4)], stroke: .colour(Ink.line), width: 2.3)
            svg.line([c + u * 2.8, c + u * (rim - 1.6)], stroke: .colour(spoke), width: 1.1)
        }
        // The felloe.
        svg.circle(c, rim - 1, fill: .none, stroke: .colour(felloe), width: 2.2)
        svg.circle(c, rim - 2.3, fill: .none, stroke: .colour(Ink.line), width: 0.7)
        svg.circle(c, rim, fill: .none, stroke: .colour(Ink.line), width: 0.8)
        // The light on the tyre's upper edge, which shows the wheel is round.
        if !far {
            svg.path(AlchemyWarriorsKit.arc(c, r - tyreWidth / 2, from: 150, to: 205), stroke: .colour(IndustrialWarriorsInk.paleSoot), width: 0.8, opacity: 0.8)
        }
        // The hub, a bolt at each spoke's root turning with the wheel (so that
        // the bolts close their cycle whenever the spokes do), and the cap.
        svg.circle(c, 3.4, fill: .colour(far ? IndustrialWarriorsInk.darkSoot : felloe), stroke: ink, width: 1)
        for i in 0..<spokes {
            let u = P.direction(degrees + Double(i) * step)
            svg.circle(c + u * 2.4, 0.36, fill: ink)
        }
        svg.circle(c, 1.5, fill: .colour(far ? IndustrialWarriorsInk.darkBrass : IndustrialWarriorsInk.brass), stroke: ink, width: 0.6)
    }
}

// MARK: - The uniform in the other views

/// The uniform the Industrial warriors share, seen from the four sides other
/// than the profile (ruled 2026-11-21), on the joints `IndustrialViews` finds.
enum IndustrialWarriorsViews {
    static let ink = Paint.colour(Ink.line)

    /// Trousers to the knee, puttees below it and boots, on the turned legs.
    static func legs(_ d: inout Drawing, trousers: String, darkTrousers: String) {
        let legs = IndustrialViews.legs(d)
        let quarter = d.view == .frontQuarter || d.view == .backQuarter
        d.svg.group(turned: -IndustrialViews.lean(d), about: Drawing.hips) { svg in
            for (i, leg) in legs.enumerated() {
                let far = i == 0 && quarter
                let shin = leg.foot - leg.knee, length = max(BronzePeopleKit.length(shin), 0.01), u = shin * (1 / length)
                svg.line([leg.hip, leg.knee, leg.knee + u * 1.8], stroke: .colour(Ink.line), width: 5.4)
                svg.line([leg.hip, leg.knee, leg.knee + u * 1.8], stroke: .colour(far ? darkTrousers : trousers), width: 3.8)
                let top = leg.knee + u * 1.6, ankle = leg.foot - u * min(1.4, length * 0.3)
                if BronzePeopleKit.length(ankle - top) > 0.5 {
                    svg.line([top, ankle], stroke: .colour(Ink.line), width: 3.9)
                    svg.line([top + u * 0.3, ankle], stroke: .colour(far ? IndustrialWarriorsInk.darkSoot : IndustrialWarriorsInk.soot), width: 2.4)
                    var wraps = PathData()
                    let a = P(1, 0)
                    var t = 1.6
                    while t < BronzePeopleKit.length(ankle - top) - 0.6 {
                        let c = top + u * t
                        wraps.move(c + a * 1.2); wraps.line(c - a * 1.2 + u * 1.1)
                        t += 2.2
                    }
                    svg.path(wraps, stroke: .colour(Ink.line), width: 0.5, opacity: 0.55)
                }
                IndustrialViews.boot(&svg, ankle: ankle, foot: leg.foot, toe: leg.toe, colour: IndustrialWarriorsInk.darkLeather, sheen: IndustrialWarriorsInk.leather)
            }
        }
    }

    /// The tunic: its colour and outline turned by the view, the brass buttons
    /// down the front, two breast pockets, the stand collar and the shoulder straps.
    static func tunic(_ d: inout Drawing, colour: String, dark: String, pale: String, collar: String, swing: Double) {
        let lift = d.rig.lift
        d.garment(colour: [P(-12.6, -46.4), P(9.6, -48.2), P(12, -36), P(11.2, -27.6), P(13.6 + swing * 0.5, -13.2),
                           P(-14.2 + swing * 0.5, -12.8), P(-12.8, -28)],
                  outline: [P(-9.2, -47.4), P(9.2, -47.4), P(11.4, -36.4), P(10.6, -28.2), P(12.6 + swing * 0.5, -14.2),
                            P(-13.2 + swing * 0.5, -14.2), P(-12.2, -28.6)], fill: .colour(colour)) { d in
            let hem = d.turned([P(-13.2, -15.6), P(12.6, -15.6), P(12.6, -15), P(-13.2, -15)])
            d.svg.line([P(hem.map(\.x).min()! + 0.6, -15.6), P(hem.map(\.x).max()! - 0.6, -15.6)], stroke: .colour(pale), width: 0.9)
            if IndustrialViews.seesFront(d) {
                for i in 0..<5 {
                    if let b = IndustrialViews.front(d, -44.6 + Double(i) * 3.6 - lift, 0) {
                        d.svg.circle(b, 0.75, fill: .colour(IndustrialWarriorsInk.brass), stroke: .colour(Ink.line), width: 0.4)
                    }
                }
                for z in [-4.8, 4.8] {
                    guard let c = IndustrialViews.front(d, -41.4 - lift, z) else { continue }
                    d.svg.polygon([c + P(-2.2, -1), c + P(2.2, -1), c + P(2.2, 1), c + P(0, 1.6), c + P(-2.2, 1)], fill: .colour(dark))
                }
                if let top = IndustrialViews.front(d, -30, 0), let bottom = IndustrialViews.front(d, -15, 0) {
                    d.svg.line([top, P(bottom.x + swing * 0.4, bottom.y)], stroke: .colour(dark), width: 0.8)
                }
            } else if let top = IndustrialViews.back(d, -46 - lift, 0), let waist = IndustrialViews.back(d, -28, 0) {
                // The seam down the back and the pleat of the skirt.
                d.svg.line([top, waist, P(waist.x + swing * 0.4, -15)], stroke: .colour(dark), width: 0.8)
            }
        }
        // The stand collar round the neck.
        IndustrialWarriorsKit.shape(&d.svg, [P(-6.4, -49.8 - lift), P(6.4, -49.8 - lift), P(6.8, -46.4 - lift), P(-6.8, -46.4 - lift)],
                                    fill: .colour(collar), width: 0.9)
        // The shoulder straps, each with its button, where the shoulders show.
        for z in [-1.0, 1.0] {
            let inner = IndustrialViews.screen(d, IndustrialPoint(0, -47.4 - lift, z * 3.4))
            let outer = IndustrialViews.screen(d, IndustrialPoint(0, -47 - lift, z * 9.4))
            guard abs(outer.x - inner.x) > 2 else { continue }
            IndustrialWarriorsKit.shape(&d.svg, [inner + P(0, -1), outer + P(0, -1), outer + P(0, 1), inner + P(0, 1)], fill: .colour(pale), width: 0.7)
            d.svg.circle(inner + (outer - inner) * 0.15, 0.55, fill: .colour(IndustrialWarriorsInk.brass))
        }
    }

    /// The waist belt of buff webbing, turned by the view, its brass buckle at the front.
    static func belt(_ d: inout Drawing) {
        let band = d.turned([P(-13, -31), P(11.6, -31.2), P(11.4, -27.6), P(-13.2, -27.4)]).map(d.up)
        IndustrialWarriorsKit.shape(&d.svg, band, fill: .colour(IndustrialWarriorsInk.buff), width: 1)
        if let buckle = IndustrialViews.front(d, -29.4 - d.rig.lift * 0.4, 0) {
            d.svg.polygon([buckle + P(-1.6, -1.6), buckle + P(1.4, -1.6), buckle + P(1.4, 1.6), buckle + P(-1.6, 1.6)],
                          fill: .colour(IndustrialWarriorsInk.brass), stroke: .colour(Ink.line), width: 0.6)
        }
    }

    /// A peaked cap seen from this side: the soot crown a little wider at
    /// its top, the band of `band` between piping of the light, the brass badge
    /// on its front and the black leather peak (drawn in the head's `over`; the
    /// peak behind the head from behind is drawn by `capPeakBehind`).
    static func peakedCap(_ d: inout Drawing, band: Paint = .team, badge: Bool = true) {
        let view = d
        BronzePeopleProps.shape(&d.svg, fill: .colour(IndustrialWarriorsInk.soot), width: 1.3) { o in
            var p = PathData()
            p.move(P(-10.6, -65.6) + o); p.line(P(-12, -73.6) + o)
            p.cubic(P(-6, -76.8) + o, P(6, -76.8) + o, P(12, -73.6) + o)
            p.line(P(10.6, -65.6) + o)
            p.cubic(P(4, -64.8) + o, P(-4, -64.8) + o, P(-10.6, -65.6) + o)
            p.close()
            return p
        }
        d.svg.path("M-9.6,-73.8 C-4,-75.6 4,-75.6 9.6,-73.8", stroke: .colour(IndustrialWarriorsInk.paleSoot), width: 0.9)
        BronzePeopleProps.shape(&d.svg, fill: band, width: 0.9, shift: P(-0.4, 0.3)) { o in
            IndustrialViews.capBand(view, rim: -65.8, height: 3.8, half: 10.8, offset: o)
        }
        d.svg.path("M-11.1,-69.8 C-4,-68.8 4,-68.8 11.1,-69.8", stroke: .colour(IndustrialWarriorsInk.light), width: 0.7)
        if badge, let b = IndustrialViews.capFront(d, y: -71, half: 11.4) {
            d.svg.ellipse(b, 1.5, 1.7, fill: .colour(IndustrialWarriorsInk.brass), stroke: .colour(Ink.line), width: 0.6)
        }
        if IndustrialViews.seesFront(d), let p = IndustrialViews.peak(d, rim: -65.4, reach: 10, drop: 3, half: 9.6) {
            d.svg.path(p, fill: .colour(IndustrialWarriorsInk.darkLeather), stroke: .colour(Ink.line), width: 1.1)
        }
    }

    /// The peak seen behind the head from a back quarter (in the head's `behind`).
    static func capPeakBehind(_ d: inout Drawing) {
        if !IndustrialViews.seesFront(d), let p = IndustrialViews.peak(d, rim: -65.4, reach: 10, drop: 3, half: 9.6) {
            d.svg.path(p, fill: .colour(IndustrialWarriorsInk.darkLeather), stroke: .colour(Ink.line), width: 1.1)
        }
    }
}
