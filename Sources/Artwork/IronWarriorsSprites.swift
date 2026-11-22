// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore

/// The warfighters of the Iron age, drawn in the Cartoon Modern style of
/// docs/art-style.md on the jointed figure every age shares (Figure.swift): the
/// swordsman, the horseman and the catapult with its crew of two.
///
/// A warfighter keeps the look of its own age (`SpriteSubject.of(_:ownerAge:)`),
/// so this source supplies `SpriteSubject.unit(kind, .iron)` for those three
/// kinds in the poses standing, walking and fighting, each a cycle of 12 frames
/// (`SpriteKey.frame` 0 to 11). The warfighters never work, and the drawing
/// falls back to standing where a pose is missing, so the working pose is not
/// supplied. Every other key returns nil. The kinds in `viewed` are drawn in
/// all five views (ruled 2026-11-21); the others in the side view alone.
///
/// Each call draws its picture afresh, and the same key always gives the same
/// pixels. Nothing is kept here: the drawing keeps what it is given, by the
/// whole key, its view included.
public struct IronWarriorSprites: ViewedSpriteSource {
    /// The poses this source supplies, each at frame 0.
    public let poses: [SpriteKey]
    private let supplied: Set<SpriteKey>

    public init(catalogue: Catalogue = .standard) {
        poses = SpriteKey.required(through: .iron, catalogue: catalogue).filter { key in
            guard case .unit(let kind, .iron) = key.subject, key.pose != .working else { return false }
            return IronWarriorsLooks.look(kind) != nil
        }
        supplied = Set(poses)
    }

    /// Every key this source supplies: each pose at each of its frames.
    public var keys: [SpriteKey] {
        poses.flatMap { pose in (0..<SpriteKey.framesPerPose).map { SpriteKey(pose.subject, pose.pose, frame: $0) } }
    }

    /// The kinds drawn in all five views so far.
    static let viewed: Set<UnitKind> = [.swordsman, .horseman, .catapult]

    public func drawsViews(of subject: SpriteSubject) -> Bool {
        if case .unit(let kind, .iron) = subject { return Self.viewed.contains(kind) }
        return false
    }

    public func sprite(_ key: SpriteKey) -> SpriteImage? {
        guard (0..<SpriteKey.framesPerPose).contains(key.frame),
              supplied.contains(SpriteKey(key.subject, key.pose, frame: 0)),
              key.view == .side || drawsViews(of: key.subject),
              case .unit(let kind, _) = key.subject,
              let look = IronWarriorsLooks.look(kind) else { return nil }
        let canvas = IronWarriorsLooks.canvas(kind)
        return look.render(key.pose, frame: key.frame, canvas: canvas, view: key.view)?.sprite(anchor: canvas.anchor)
    }
}

/// Which look draws each kind, and on what canvas.
enum IronWarriorsLooks {
    static func look(_ kind: UnitKind) -> (any PersonLook)? {
        switch kind {
        case .swordsman: IronWarriorsSwordsman()
        case .horseman: IronWarriorsHorseman()
        case .catapult: IronWarriorsCatapult()
        default: nil
        }
    }

    static func canvas(_ kind: UnitKind) -> Canvas {
        switch kind {
        case .horseman: IronWarriorsHorseman.canvas
        case .catapult: IronWarriorsCatapult.canvas
        default: .person
        }
    }
}

/// The colours of the Iron age (sea green, iron grey, legion red and the
/// light; docs/art-style.md, "Palettes"), with the shades that cloth, iron,
/// leather and timber need. The line, the skin and the eye are the ones every
/// age shares (`Ink`).
///
/// Legion red is kept to small parts (a crest, a scarf, a plume): Sumer's
/// team colour is almost the same red, and the team's colour must stand out.
enum IronWarriorsInk {
    static let sea = "#6fa39a"
    static let deepSea = "#3f6f68"
    static let darkSea = "#2c514c"
    static let paleSea = "#a9cdc4"
    /// Wrought iron, with its light and its shade.
    static let iron = "#b8b0a0"
    static let ironLight = "#e2dccf"
    static let ironDark = "#7b7468"
    static let legion = "#c8402f"
    static let darkLegion = "#8a2a1f"
    static let light = "#efe0c2"
    static let leather = "#7a4a2a"
    static let darkLeather = "#55321c"
    static let wood = "#8a5a33"
    static let darkWood = "#5c3c22"
    static let paleWood = "#b07f4f"
    static let rope = "#c9b07e"
    /// A thrown stone.
    static let stone = "#cfc6b4"
}

/// Geometry the Iron warriors share.
enum IronWarriorsKit {
    /// A body point (in a figure's own units) for a point of the picture, for a
    /// figure whose origin is at `origin` and which leans by `lean` about its
    /// hips, raised by `bob`: the inverse of where the figure draws it.
    static func local(_ world: P, origin: P, lean: Double, bob: Double) -> P {
        (world - origin - P(0, bob)).rotated(-lean, about: Drawing.hips)
    }

    /// The front shoulder for a rig, where `BronzePeopleKit.reach` starts from.
    static func frontShoulder(_ r: Rig) -> P { P(8, -44 - r.lift) }
    static func backShoulder(_ r: Rig) -> P { P(-7, -44 - r.lift) }

    /// A closed shape whose colour sits out of register with its outline.
    static func shape(_ svg: inout SVG, _ points: [P], fill: Paint, width: Double = 1.3) {
        BronzePeopleProps.shape(&svg, points, fill: fill, width: width)
    }

    /// A short iron sword (a gladius) from the hand along `degrees`: a round
    /// pommel, a ridged grip, a guard, and a broad blade tapering to its point.
    static func gladius(_ svg: inout SVG, at hand: P, degrees: Double, blade: Double = 13) {
        let u = P.direction(degrees), a = P(-u.y, u.x)
        let pommel = hand - u * 3.2
        svg.line([pommel, hand + u * 1.6], stroke: .colour(Ink.line), width: 2.8)
        svg.line([pommel + u * 0.4, hand + u * 1.4], stroke: .colour(IronWarriorsInk.paleWood), width: 1.5)
        svg.circle(pommel, 1.5, fill: .colour(IronWarriorsInk.paleWood), stroke: .colour(Ink.line), width: 0.8)
        let base = hand + u * 2.2
        let tip = base + u * blade
        let edge = [base + a * 1.7, base + u * (blade * 0.7) + a * 1.4, tip, base + u * (blade * 0.7) - a * 1.4, base - a * 1.7]
        shape(&svg, edge, fill: .colour(IronWarriorsInk.ironLight), width: 1)
        svg.line([base + u * 0.8, tip - u * 2], stroke: .colour(IronWarriorsInk.ironDark), width: 0.6)
        // The guard across the hilt.
        svg.line([base - u * 0.4 + a * 2.6, base - u * 0.4 - a * 2.6], stroke: .colour(Ink.line), width: 2.4)
        svg.line([base - u * 0.4 + a * 2.2, base - u * 0.4 - a * 2.2], stroke: .colour(IronWarriorsInk.paleWood), width: 1)
    }

    /// The point of a sword drawn by `gladius` with the same arguments.
    static func gladiusPoint(at hand: P, degrees: Double, blade: Double = 13) -> P {
        hand + P.direction(degrees) * (2.2 + blade)
    }

    /// An iron helmet seen from the side: a bowl with a ridge over the brow, a
    /// flared neck guard, a hinged cheek guard, and a crest of legion red when `crest`.
    static func helmet(_ d: inout Drawing, crest: Crest) {
        if d.view != .side { helmetInView(&d, crest: crest); return }
        // The crest's horsehair, behind the bowl's top.
        switch crest {
        case .none: break
        case .brush:
            BronzePeopleProps.shape(&d.svg, fill: .colour(IronWarriorsInk.legion), width: 1.2) { o in
                var p = PathData()
                p.move(P(-8.6, -70.4) + o)
                p.cubic(P(-9.6, -78.6) + o, P(1.4, -82.8) + o, P(8.4, -74.8) + o)
                p.line(P(5.4, -71.8) + o)
                p.cubic(P(1, -75.6) + o, P(-4.6, -74.6) + o, P(-6, -69.4) + o)
                p.close()
                return p
            }
            var hair = PathData()
            for x in stride(from: -6.4, through: 5.0, by: 2.3) {
                hair.move(P(x, -73.4 - (x < 0 ? 0 : x * 0.2))); hair.line(P(x - 0.8, -77.2 - (x < 0 ? -x * 0.25 : 0)))
            }
            d.svg.path(hair, stroke: .colour(IronWarriorsInk.darkLegion), width: 0.8)
        case .plume:
            BronzePeopleProps.shape(&d.svg, fill: .colour(IronWarriorsInk.legion), width: 1.1) { o in
                var p = PathData()
                p.move(P(-1, -73) + o)
                p.cubic(P(-4, -82) + o, P(-12, -84) + o, P(-17.6, -79.6) + o)
                p.cubic(P(-12.6, -80) + o, P(-8, -77.6) + o, P(-4, -71.6) + o)
                p.close()
                return p
            }
        }
        BronzePeopleProps.shape(&d.svg, fill: .colour(IronWarriorsInk.iron), width: 1.5) { o in
            var p = PathData()
            p.move(P(-13.8, -54.4) + o)
            p.line(P(-11.6, -57.8) + o)
            p.cubic(P(-12.6, -72) + o, P(5.4, -77.6) + o, P(11.6, -64.6) + o)
            p.line(P(12.6, -62.2) + o)
            p.cubic(P(5.6, -64.6) + o, P(-3.4, -63.8) + o, P(-7.6, -59.4) + o)
            p.line(P(-8.8, -55.4) + o)
            p.cubic(P(-10.4, -53.8) + o, P(-12.6, -53.6) + o, P(-13.8, -54.4) + o)
            p.close()
            return p
        }
        // The brow ridge and the light along the bowl.
        d.svg.path("M12,-63.2 C5.6,-65.6 -3,-64.8 -7.6,-60.4", stroke: .colour(IronWarriorsInk.ironDark), width: 1.4)
        d.svg.path("M-7.4,-70.6 C-4.2,-73.4 1.4,-73.8 5.2,-71.6", stroke: .colour(IronWarriorsInk.ironLight), width: 1.2)
        // The neck guard's flare, ribbed.
        d.svg.path("M-12.6,-56.6 l-0.6,1.6 M-10.6,-57.2 l-0.4,1.8", stroke: .colour(IronWarriorsInk.ironDark), width: 0.8)
        // The cheek guard, hinged at the rim, with two rivets.
        BronzePeopleProps.shape(&d.svg, fill: .colour(IronWarriorsInk.iron), width: 1.2) { o in
            var p = PathData()
            p.move(P(-6.4, -60.2) + o)
            p.line(P(-1.6, -60.6) + o)
            p.cubic(P(-1, -57) + o, P(-1.2, -53.4) + o, P(-2.6, -50.4) + o)
            p.cubic(P(-4.2, -50.2) + o, P(-5.8, -51.4) + o, P(-6.4, -53.4) + o)
            p.close()
            return p
        }
        for c in [P(-4, -58.4), P(-4, -53.4)] {
            d.svg.circle(c, 0.6, fill: .colour(IronWarriorsInk.ironDark))
        }
        if crest != .none {
            d.svg.circle(P(-1.2, -74.6), 1.3, fill: .colour(IronWarriorsInk.ironLight), stroke: .colour(Ink.line), width: 0.8)
        }
    }

    enum Crest { case none, brush, plume }

    /// The iron helmet seen from another side. From a quarter it shows much
    /// as in profile, the crest narrowed, the cheek guard over the side of the
    /// head that shows, and from behind no brow ridge. From straight ahead the
    /// bowl sits level over the brow with a cheek guard on each side; from
    /// behind, the neck guard flares across the nape. The crest is seen end on.
    static func helmetInView(_ d: inout Drawing, crest: Crest) {
        let ironPaint = Paint.colour(IronWarriorsInk.iron)
        switch d.view {
        case .frontQuarter, .backQuarter:
            let front = d.view == .frontQuarter
            if crest != .none {
                d.svg.raw("<g transform=\"scale(0.74,1)\">")
                crestInProfile(&d, crest: crest)
                d.svg.raw("</g>")
            }
            BronzePeopleProps.shape(&d.svg, fill: ironPaint, width: 1.5) { o in
                var p = PathData()
                p.move(P(-13.8, -54.4) + o)
                p.line(P(-11.6, -57.8) + o)
                p.cubic(P(-12.6, -72) + o, P(5.4, -77.6) + o, P(11.6, -64.6) + o)
                p.line(P(12.6, -62.2) + o)
                p.cubic(P(5.6, -64.6) + o, P(-3.4, -63.8) + o, P(-7.6, -59.4) + o)
                p.line(P(-8.8, -55.4) + o)
                p.cubic(P(-10.4, -53.8) + o, P(-12.6, -53.6) + o, P(-13.8, -54.4) + o)
                p.close()
                return p
            }
            if front { d.svg.path("M12,-63.2 C5.6,-65.6 -3,-64.8 -7.6,-60.4", stroke: .colour(IronWarriorsInk.ironDark), width: 1.4) }
            d.svg.path("M-7.4,-70.6 C-4.2,-73.4 1.4,-73.8 5.2,-71.6", stroke: .colour(IronWarriorsInk.ironLight), width: 1.2)
            d.svg.path("M-12.6,-56.6 l-0.6,1.6 M-10.6,-57.2 l-0.4,1.8", stroke: .colour(IronWarriorsInk.ironDark), width: 0.8)
            // The cheek guard over the side that shows: by the ear from a front quarter, the far one a sliver at the face's edge.
            let shift = front ? -1.6 : 9.6
            if front {
                IronWarriorsKit.shape(&d.svg, [P(9.4, -62.4), P(11.6, -62.8), P(11.2, -55.6), P(9.8, -53.8)], fill: ironPaint, width: 1)
            }
            BronzePeopleProps.shape(&d.svg, fill: ironPaint, width: 1.2) { o in
                var p = PathData()
                p.move(P(-6.4 + shift, -60.2) + o)
                p.line(P(-1.6 + shift, -60.6) + o)
                p.cubic(P(-1 + shift, -57) + o, P(-1.2 + shift, -53.4) + o, P(-2.6 + shift, -50.4) + o)
                p.cubic(P(-4.2 + shift, -50.2) + o, P(-5.8 + shift, -51.4) + o, P(-6.4 + shift, -53.4) + o)
                p.close()
                return p
            }
            for c in [P(-4 + shift, -58.4), P(-4 + shift, -53.4)] {
                d.svg.circle(c, 0.6, fill: .colour(IronWarriorsInk.ironDark))
            }
            if crest != .none {
                d.svg.circle(P(-0.9, -74.6), 1.3, fill: .colour(IronWarriorsInk.ironLight), stroke: .colour(Ink.line), width: 0.8)
            }
        default:
            let front = d.view == .front
            switch crest {
            case .none: break
            case .brush:
                BronzePeopleProps.shape(&d.svg, fill: .colour(IronWarriorsInk.legion), width: 1.2) { o in
                    var p = PathData()
                    p.move(P(-3, -73) + o)
                    p.cubic(P(-3.6, -79.4) + o, P(-2, -83.6) + o, P(0, -83.8) + o)
                    p.cubic(P(2, -83.6) + o, P(3.6, -79.4) + o, P(3, -73) + o)
                    p.close()
                    return p
                }
                d.svg.path("M-1.4,-75 l-0.2,-6 M0.2,-75 l0,-7 M1.8,-75 l0.2,-6", stroke: .colour(IronWarriorsInk.darkLegion), width: 0.8)
            case .plume:
                // From the front the plume rises behind the bowl; from behind it sweeps toward the viewer and aside.
                BronzePeopleProps.shape(&d.svg, fill: .colour(IronWarriorsInk.legion), width: 1.1) { o in
                    var p = PathData()
                    if front {
                        p.move(P(-1.6, -73) + o)
                        p.cubic(P(-3.4, -79) + o, P(-1.6, -84.4) + o, P(1.4, -85.4) + o)
                        p.cubic(P(2.2, -81) + o, P(1.8, -77) + o, P(1.6, -73) + o)
                    } else {
                        p.move(P(-2.4, -72.6) + o)
                        p.cubic(P(-7.6, -77) + o, P(-6.4, -84) + o, P(-1.4, -85.2) + o)
                        p.cubic(P(3.4, -83.4) + o, P(5.2, -78) + o, P(2.4, -72.4) + o)
                    }
                    p.close()
                    return p
                }
            }
            if !front {
                // The neck guard, flared across the nape and ribbed.
                BronzePeopleProps.shape(&d.svg, fill: ironPaint, width: 1.3) { o in
                    var p = PathData()
                    p.move(P(-14, -53.6) + o)
                    p.cubic(P(-8, -55.6) + o, P(8, -55.6) + o, P(14, -53.6) + o)
                    p.line(P(11.8, -58.8) + o)
                    p.cubic(P(6, -60.4) + o, P(-6, -60.4) + o, P(-11.8, -58.8) + o)
                    p.close()
                    return p
                }
                d.svg.path("M-8,-57.4 l-0.6,2 M-3,-58 l-0.2,2.2 M3,-58 l0.2,2.2 M8,-57.4 l0.6,2", stroke: .colour(IronWarriorsInk.ironDark), width: 0.8)
            }
            BronzePeopleProps.shape(&d.svg, fill: ironPaint, width: 1.5) { o in
                var p = PathData()
                p.move(P(-12.2, front ? -60 : -57.4) + o)
                p.cubic(P(-13, -73) + o, P(13, -73) + o, P(12.2, front ? -60 : -57.4) + o)
                if front {
                    p.cubic(P(7, -63.6) + o, P(-7, -63.6) + o, P(-12.2, -60) + o)
                } else {
                    p.cubic(P(7, -59.6) + o, P(-7, -59.6) + o, P(-12.2, -57.4) + o)
                }
                p.close()
                return p
            }
            d.svg.path("M-6.8,-70.8 C-3,-73.4 3,-73.4 6.8,-70.8", stroke: .colour(IronWarriorsInk.ironLight), width: 1.2)
            if front {
                d.svg.path("M-11.4,-61.4 C-6,-64.4 6,-64.4 11.4,-61.4", stroke: .colour(IronWarriorsInk.ironDark), width: 1.4)
                // A cheek guard hinged at each side of the rim, with two rivets.
                for flip in [1.0, -1.0] {
                    d.svg.raw("<g transform=\"scale(\(num(flip)),1)\">")
                    BronzePeopleProps.shape(&d.svg, fill: ironPaint, width: 1.2) { o in
                        var p = PathData()
                        p.move(P(-12, -60.6) + o)
                        p.line(P(-7.6, -61.8) + o)
                        p.cubic(P(-7, -58) + o, P(-7.2, -54.4) + o, P(-8.4, -51) + o)
                        p.cubic(P(-10, -50.8) + o, P(-11.4, -52.2) + o, P(-12, -54.4) + o)
                        p.close()
                        return p
                    }
                    for c in [P(-9.8, -58.8), P(-9.8, -54)] { d.svg.circle(c, 0.6, fill: .colour(IronWarriorsInk.ironDark)) }
                    d.svg.raw("</g>")
                }
            }
            if crest != .none {
                d.svg.circle(P(0, -72.6), 1.3, fill: .colour(IronWarriorsInk.ironLight), stroke: .colour(Ink.line), width: 0.8)
            }
        }
    }

    /// The crest as the side view draws it, for a view that narrows it.
    private static func crestInProfile(_ d: inout Drawing, crest: Crest) {
        switch crest {
        case .none: break
        case .brush:
            BronzePeopleProps.shape(&d.svg, fill: .colour(IronWarriorsInk.legion), width: 1.2) { o in
                var p = PathData()
                p.move(P(-8.6, -70.4) + o)
                p.cubic(P(-9.6, -78.6) + o, P(1.4, -82.8) + o, P(8.4, -74.8) + o)
                p.line(P(5.4, -71.8) + o)
                p.cubic(P(1, -75.6) + o, P(-4.6, -74.6) + o, P(-6, -69.4) + o)
                p.close()
                return p
            }
            var hair = PathData()
            for x in stride(from: -6.4, through: 5.0, by: 2.3) {
                hair.move(P(x, -73.4 - (x < 0 ? 0 : x * 0.2))); hair.line(P(x - 0.8, -77.2 - (x < 0 ? -x * 0.25 : 0)))
            }
            d.svg.path(hair, stroke: .colour(IronWarriorsInk.darkLegion), width: 0.8)
        case .plume:
            BronzePeopleProps.shape(&d.svg, fill: .colour(IronWarriorsInk.legion), width: 1.1) { o in
                var p = PathData()
                p.move(P(-1, -73) + o)
                p.cubic(P(-4, -82) + o, P(-12, -84) + o, P(-17.6, -79.6) + o)
                p.cubic(P(-12.6, -80) + o, P(-8, -77.6) + o, P(-4, -71.6) + o)
                p.close()
                return p
            }
        }
    }
}

/// How the Iron age's people, their gear and their beasts show in a view other
/// than the side (ruled 2026-11-21: five views drawn), with the figure kit's
/// conventions (FigureViews.swift): the figure's own space has x toward its
/// front, y downward and z toward its right side, and a view turns it by its
/// yaw about the upright axis.
enum IronViews {
    /// The yaw's cosine and sine for a view.
    static func turn(_ view: SpriteView) -> (c: Double, s: Double) {
        let r = view.yaw * .pi / 180
        return (cos(r), sin(r))
    }

    /// A point of the figure's space on the screen, and its depth toward the viewer.
    static func project(_ view: SpriteView, _ p: P, z: Double) -> (point: P, depth: Double) {
        let (c, s) = turn(view)
        return (P(p.x * c - z * s, p.y), p.x * s + z * c)
    }

    /// A point of the figure's space on the screen.
    static func at(_ view: SpriteView, _ p: P, z: Double = 0) -> P { project(view, p, z: z).point }

    /// A run in the figure's upright plane as it shows: its part toward the front foreshortened.
    static func flat(_ view: SpriteView, _ v: P) -> P { P(v.x * turn(view).c, v.y) }

    /// A direction in the figure's upright plane (degrees from straight down,
    /// positive toward the front) as it shows on the screen, and the share of
    /// a length along it that shows.
    static func tool(_ view: SpriteView, _ degrees: Double) -> (degrees: Double, share: Double) {
        let v = flat(view, P.direction(degrees))
        let share = (v.x * v.x + v.y * v.y).squareRoot()
        guard share > 1e-6 else { return (0, 0) }
        return (atan2(v.x, v.y) * 180 / .pi, share)
    }

    /// The centre of the face on the head, as the figure kit draws it: turned
    /// toward the screen's right from a front quarter, toward its left from a back one.
    static func face(_ view: SpriteView) -> Double {
        switch view {
        case .frontQuarter: 4.5
        case .backQuarter: -4.5
        default: 0
        }
    }

    /// Whether the face shows.
    static func seesFace(_ view: SpriteView) -> Bool { view == .front || view == .frontQuarter }

    /// Whether the view looks at the figure from behind.
    static func fromBehind(_ view: SpriteView) -> Bool { view == .back || view == .backQuarter }

    /// A point outside the figure where it falls in the picture: `Drawing.world`
    /// with the lean as the view shows it.
    static func world(_ d: Drawing, _ p: P) -> P {
        p.rotated(d.rig.lean * turn(d.view).c, about: Drawing.hips) + P(0, d.bob)
    }

    /// A leg's knee, foot and toe in this view (before the bob and the lean), as
    /// the figure kit draws them: the right (front) leg or the left (back) one.
    static func leg(_ d: Drawing, front: Bool) -> (knee: P, foot: P, toe: P, depth: Double) {
        let limb = front ? d.rig.frontLeg : d.rig.backLeg
        let hip = P(0.5, -16)
        let knee = hip + P.direction(limb.upper) * Joints.thigh
        let foot = knee + P.direction(limb.upper - limb.bend) * Joints.shin
        let z = front ? Drawing.hipSpread : -Drawing.hipSpread
        let k = d.project(knee.x, knee.y, z)
        return (k.point, d.project(foot.x, foot.y, z).point, d.project(foot.x + 4.5, foot.y + 0.3, z).point, k.depth)
    }

    /// A shape drawn in profile round the body, turned as the kit turns a garment,
    /// and raised by the breath.
    static func around(_ d: Drawing, _ shape: [P]) -> [P] { d.turned(shape).map(d.up) }

    /// The top and bottom edges of a band drawn in profile, as `around` turns it.
    static func edges(_ d: Drawing, _ band: [P]) -> (top: [P], bottom: [P]) {
        let ring = around(d, band)
        let half = ring.count / 2
        return ([ring[ring.count - 1], ring[0]], [ring[half], ring[half - 1]])
    }
}

extension IronViews {
    /// The left and right edges, at the height `y`, of a shape drawn in profile
    /// round the body, as `around` turns it.
    static func span(_ d: Drawing, _ shape: [P], at y: Double) -> (left: Double, right: Double) {
        let ring = around(d, shape)
        let half = ring.count / 2
        func x(_ side: [P]) -> Double {
            guard let first = side.first, let last = side.last else { return 0 }
            if y <= first.y { return first.x }
            if y >= last.y { return last.x }
            for (a, b) in zip(side, side.dropFirst()) where y >= a.y && y <= b.y {
                return b.y == a.y ? a.x : a.x + (b.x - a.x) * (y - a.y) / (b.y - a.y)
            }
            return last.x
        }
        return (x(Array(ring[half...].reversed())), x(Array(ring[..<half])))
    }
}
