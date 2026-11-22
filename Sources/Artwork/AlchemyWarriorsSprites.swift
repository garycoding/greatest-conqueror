// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

/// The knight, the musketeer and the cannon with its crew of two of the Alchemy age, drawn in the Cartoon
/// Modern style of docs/art-style.md on the jointed figure every age shares
/// (Figure.swift), one age on from the Iron warriors (`IronWarriorSprites`).
///
/// A warfighter keeps the look of its own age (`SpriteSubject.of(_:ownerAge:)`),
/// so this source supplies `SpriteSubject.unit(kind, .alchemy)` for those three
/// kinds in the poses standing, walking and fighting, each a cycle of 12 frames
/// (`SpriteKey.frame` 0 to 11). The warfighters never work, and the drawing
/// falls back to standing where a pose is missing, so the working pose is not
/// supplied. Every other key returns nil. Each kind is drawn in the five views
/// (ruled 2026-11-21; `SpriteKey.view`), the other three facings mirroring them.
///
/// Each call draws its picture afresh, and the same key always gives the same
/// pixels. Nothing is kept here: the drawing keeps what it is given, by the
/// whole key, its view included.
public struct AlchemyWarriorSprites: ViewedSpriteSource {
    /// The poses this source supplies, each at frame 0.
    public let poses: [SpriteKey]
    private let supplied: Set<SpriteKey>

    public init(catalogue: Catalogue = .standard) {
        poses = SpriteKey.required(through: .alchemy, catalogue: catalogue).filter { key in
            guard case .unit(let kind, .alchemy) = key.subject, key.pose != .working else { return false }
            return AlchemyWarriorsLooks.look(kind) != nil
        }
        supplied = Set(poses)
    }

    /// Every key this source supplies: each pose at each of its frames.
    public var keys: [SpriteKey] {
        poses.flatMap { pose in (0..<SpriteKey.framesPerPose).map { SpriteKey(pose.subject, pose.pose, frame: $0) } }
    }

    /// The kinds drawn in all five views.
    static let viewed: Set<UnitKind> = [.knight, .musketeer, .cannon]

    public func drawsViews(of subject: SpriteSubject) -> Bool {
        if case .unit(let kind, .alchemy) = subject { return Self.viewed.contains(kind) }
        return false
    }

    public func sprite(_ key: SpriteKey) -> SpriteImage? {
        guard (0..<SpriteKey.framesPerPose).contains(key.frame),
              supplied.contains(SpriteKey(key.subject, key.pose, frame: 0)),
              key.view == .side || drawsViews(of: key.subject),
              case .unit(let kind, _) = key.subject,
              let look = AlchemyWarriorsLooks.look(kind) else { return nil }
        let canvas = AlchemyWarriorsLooks.canvas(kind)
        return look.render(key.pose, frame: key.frame, canvas: canvas, view: key.view)?.sprite(anchor: canvas.anchor)
    }
}

/// Which look draws each kind, and on what canvas.
enum AlchemyWarriorsLooks {
    static func look(_ kind: UnitKind) -> (any PersonLook)? {
        switch kind {
        case .knight: AlchemyWarriorsKnight()
        case .musketeer: AlchemyWarriorsMusketeer()
        case .cannon: AlchemyWarriorsCannon()
        default: nil
        }
    }

    static func canvas(_ kind: UnitKind) -> Canvas {
        switch kind {
        case .knight: AlchemyWarriorsKnight.canvas
        case .cannon: AlchemyWarriorsCannon.canvas
        default: AlchemyWarriorsMusketeer.canvas
        }
    }
}

/// The colours of the Alchemy age (gilt, deep teal, wine and the light;
/// docs/art-style.md, "Palettes"), with the shades that steel, buff leather,
/// cloth, timber and smoke need. The line, the skin and the eye are the ones
/// every age shares (`Ink`).
///
/// Wine and gilt are kept off the parts next to the team's colour: Rome's red
/// is near the wine, and the team's colour must stand out. Wine goes to the
/// knight's plume and the musketeer's breeches, below the skirt of his coat.
enum AlchemyWarriorsInk {
    static let gilt = "#d6b25e"
    static let darkGilt = "#a8843a"
    static let paleGilt = "#ecd391"
    static let teal = "#2f5a5a"
    static let darkTeal = "#1f3e3e"
    static let paleTeal = "#5e8783"
    static let wine = "#7a3a5a"
    static let darkWine = "#552540"
    static let light = "#efe0c2"
    /// Polished plate, with its light and its shade.
    static let steel = "#c2c4bc"
    static let steelLight = "#e8e7de"
    static let steelDark = "#7f827b"
    /// The buff leather of the musketeer's coat.
    static let buff = "#c49a62"
    static let darkBuff = "#946c3e"
    static let paleBuff = "#dcbd8c"
    static let leather = "#6b4226"
    static let darkLeather = "#472a17"
    static let wood = "#8a5a33"
    static let darkWood = "#5c3c22"
    static let paleWood = "#c7a06a"
    /// The musket's barrel.
    static let barrel = "#5d5a55"
    static let barrelLight = "#8f8b83"
    static let linen = "#f2ead8"
    static let hair = "#4a3020"
    /// Powder smoke, and the flash of the shot.
    static let smoke = "#e6dfd0"
    static let smokeShade = "#c4bbaa"
    static let flash = "#f4cf62"
    static let flashCore = "#fff3c8"
    /// The burning end of the slow match.
    static let ember = "#e0703a"
    /// The knight's destrier: a dark bay.
    static let coat = "#6e4630"
    static let coatShade = "#4a2d1d"
}

/// Geometry the Alchemy warriors share: plate armour and the arming sword.
enum AlchemyWarriorsKit {
    static let ink = Paint.colour(Ink.line)

    /// A closed shape whose colour sits out of register with its outline.
    static func shape(_ svg: inout SVG, _ points: [P], fill: Paint, width: Double = 1.2) {
        BronzePeopleProps.shape(&svg, points, fill: fill, width: width)
    }

    /// A limb in plate through `points`: the dark line, the steel over it, and
    /// a light along its upper edge.
    static func plate(_ svg: inout SVG, _ points: [P], width: Double = 3.6, shade: String = AlchemyWarriorsInk.steel) {
        svg.line(points, stroke: ink, width: width + 1.7)
        svg.line(points, stroke: .colour(shade), width: width)
        let light = points.map { $0 + P(-0.5, -0.7) }
        svg.line(light, stroke: .colour(AlchemyWarriorsInk.steelLight), width: 0.8, opacity: shade == AlchemyWarriorsInk.steel ? 0.9 : 0.4)
    }

    /// A rounded plate over a joint (an elbow's couter, a knee's poleyn), with a gilt rivet.
    static func joint(_ svg: inout SVG, at p: P, radius r: Double, shade: String = AlchemyWarriorsInk.steel) {
        svg.circle(p + P(-0.5, 0.5), r, fill: .colour(shade))
        svg.circle(p, r, fill: .none, stroke: ink, width: 1)
        svg.circle(p + P(0.3, -0.2), 0.65, fill: .colour(AlchemyWarriorsInk.gilt), stroke: ink, width: 0.4)
    }

    /// A gauntlet closed on a grip at `hand`, its cuff flaring back along `degrees`
    /// (the forearm's direction from elbow to hand).
    static func gauntlet(_ svg: inout SVG, at hand: P, degrees: Double, shade: String = AlchemyWarriorsInk.steel) {
        let u = P.direction(degrees), a = P(-u.y, u.x)
        let cuff = [hand - u * 1.2 + a * 2.1, hand - u * 4.4 + a * 2.9, hand - u * 4.4 - a * 2.9, hand - u * 1.2 - a * 2.1]
        shape(&svg, cuff, fill: .colour(shade), width: 0.9)
        svg.line([hand - u * 4.2 + a * 2.7, hand - u * 4.2 - a * 2.7], stroke: .colour(AlchemyWarriorsInk.gilt), width: 0.8)
        svg.circle(hand + P(-0.4, 0.4), 2.1, fill: .colour(shade))
        svg.circle(hand, 2.1, fill: .none, stroke: ink, width: 1)
        // The knuckle plates.
        svg.path("M\(num(hand.x - 1.2)),\(num(hand.y - 1.1)) q1.4,0.9 2.4,-0.1", stroke: ink, width: 0.6, opacity: 0.8)
    }

    /// An arm in plate from its shoulder through its elbow to the gauntlet.
    static func arm(_ svg: inout SVG, shoulder: P, elbow: P, hand: P, shade: String = AlchemyWarriorsInk.steel) {
        plate(&svg, [shoulder, elbow, hand], width: 3.4, shade: shade)
        joint(&svg, at: elbow, radius: 2, shade: shade)
        gauntlet(&svg, at: hand, degrees: BronzePeopleKit.degrees(from: elbow, to: hand), shade: shade)
    }

    /// The layered plates over a shoulder, the lowest edged in gilt.
    static func pauldron(_ svg: inout SVG, at s: P) {
        shape(&svg, [s + P(-4.8, 0.8), s + P(-3.2, -3.4), s + P(2.6, -3.8), s + P(5.2, 0), s + P(4.8, 2.4), s + P(-4.4, 2.6)],
              fill: .colour(AlchemyWarriorsInk.steel), width: 1.1)
        shape(&svg, [s + P(-4, 2.6), s + P(4.6, 2.4), s + P(4.2, 5), s + P(-3.4, 5.2)], fill: .colour(AlchemyWarriorsInk.steel), width: 1)
        svg.line([s + P(-3.4, 4.9), s + P(4, 4.7)], stroke: .colour(AlchemyWarriorsInk.gilt), width: 0.9)
        svg.path("M\(num(s.x - 2.6)),\(num(s.y - 2.2)) q2.6,-1.4 5.2,-0.6", stroke: .colour(AlchemyWarriorsInk.steelLight), width: 0.9)
    }

    /// An arming sword from the hand along `degrees`: a gilt pommel and
    /// cross-guard, a grip bound in leather, and a long steel blade with a fuller.
    static func sword(_ svg: inout SVG, at hand: P, degrees: Double, blade: Double = 21) {
        let u = P.direction(degrees), a = P(-u.y, u.x)
        let pommel = hand - u * 3.8
        svg.line([pommel, hand + u * 1.8], stroke: ink, width: 2.7)
        svg.line([pommel + u * 0.6, hand + u * 1.6], stroke: .colour(AlchemyWarriorsInk.leather), width: 1.3)
        let base = hand + u * 2.6
        let tip = base + u * blade
        shape(&svg, [base + a * 1.4, base + u * (blade - 4.5) + a * 1.1, tip, base + u * (blade - 4.5) - a * 1.1, base - a * 1.4],
              fill: .colour(AlchemyWarriorsInk.steelLight), width: 1)
        svg.line([base + u * 1, base + u * (blade - 6)], stroke: .colour(AlchemyWarriorsInk.steelDark), width: 0.6)
        // The cross-guard, its ends turned toward the blade.
        let guardLeft = base - u * 0.2 + a * 4.4, guardRight = base - u * 0.2 - a * 4.4
        svg.line([guardLeft + u * 1, guardLeft, guardRight, guardRight + u * 1], stroke: ink, width: 2.5)
        svg.line([guardLeft + u * 0.8, guardLeft, guardRight, guardRight + u * 0.8], stroke: .colour(AlchemyWarriorsInk.gilt), width: 1.2)
        svg.circle(pommel, 1.7, fill: .colour(AlchemyWarriorsInk.gilt), stroke: ink, width: 0.8)
    }

    /// The point of a sword drawn by `sword` with the same arguments.
    static func swordPoint(at hand: P, degrees: Double, blade: Double = 21) -> P {
        hand + P.direction(degrees) * (2.6 + blade)
    }

    /// A cloud of powder smoke: puffs given as an offset from `origin` and a
    /// radius, outlined as one shape (every outline first, every fill over
    /// them), with a shade low in each puff.
    static func smoke(_ svg: inout SVG, at origin: P, puffs: [(P, Double)], opacity: Double) {
        guard opacity > 0.01, !puffs.isEmpty else { return }
        svg.raw("<g opacity=\"\(num(opacity))\">")
        for (offset, r) in puffs { svg.circle(origin + offset, r + 0.8, fill: ink) }
        for (offset, r) in puffs { svg.circle(origin + offset, r, fill: .colour(AlchemyWarriorsInk.smoke)) }
        for (offset, r) in puffs where r > 2.4 {
            svg.path(arc(origin + offset, r * 0.62, from: 110, to: 30), stroke: .colour(AlchemyWarriorsInk.smokeShade), width: r * 0.22)
        }
        svg.raw("</g>")
    }

    /// An arc around `c` at radius `r`, from `from` to `to` degrees (the
    /// figure's directions: 0 straight down, 90 toward the front).
    static func arc(_ c: P, _ r: Double, from: Double, to: Double) -> PathData {
        var d = PathData()
        for i in 0...6 {
            let p = c + P.direction(mix(from, to, Double(i) / 6)) * r
            if i == 0 { d.move(p) } else { d.line(p) }
        }
        return d
    }
}
