// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
import Synchronization

/// The buildings of the last two ages that Cities of Progress has no drawing
/// for, complete and under construction: the cannon factory, of the age of
/// cannons, in the Alchemy and Industrial looks, and the hospital, of the age
/// of hospitals, in the Industrial look. A building takes the look of its
/// owner's age (`SpriteSubject.of`), so the cannon factory needs both. They are
/// drawn with the kits of the older buildings of those looks
/// (`AlchemyOldBuildingsPainter`, `IndustrialOldBuildingsPainter`), in the
/// style of docs/art-style.md, and each carries the owner's colour in a mask.
/// Every other key gives nil.
public struct LateBuildingSprites: SpriteSource {
    private let store = Store()

    public init() {}

    public func sprite(_ key: SpriteKey) -> SpriteImage? {
        guard let subject = LateBuildingsArt.subject(of: key) else { return nil }
        if let known = store.made.withLock({ $0[key] }) { return known }
        guard let made = LateBuildingsArt.render(subject) else { return nil }
        return store.made.withLock { cache in
            if let first = cache[key] { return first }
            cache[key] = made
            return made
        }
    }
}

/// The sprites drawn so far, so that each is drawn once.
private final class Store: Sendable {
    let made = Mutex<[SpriteKey: SpriteImage]>([:])
}

/// What one of this batch's keys shows: a building in a look, complete or under construction.
struct LateBuildingsSubject: Hashable, Sendable {
    var kind: BuildingKind
    var look: Look
    var complete: Bool
}

/// What this batch draws, on what canvas, and the drawing of it.
enum LateBuildingsArt {
    /// The buildings and looks this batch draws.
    static let drawn: [(kind: BuildingKind, look: Look)] = [(.cannonFactory, .alchemy), (.cannonFactory, .industrial),
                                                            (.hospital, .industrial)]

    /// The subject a key names, if it is one of this batch's: one of its
    /// buildings in one of its looks, complete or under construction, at
    /// frame 0, in the side view.
    static func subject(of key: SpriteKey) -> LateBuildingsSubject? {
        guard key.frame == 0, key.view == .side, case .building(let kind, let look) = key.subject,
              drawn.contains(where: { $0.kind == kind && $0.look == look }) else { return nil }
        if key.pose == .complete { return LateBuildingsSubject(kind: kind, look: look, complete: true) }
        if key.pose == .underConstruction { return LateBuildingsSubject(kind: kind, look: look, complete: false) }
        return nil
    }

    /// The area a building's sprite covers, in points with the origin on the
    /// ground at the centre of its footprint, drawn at two pixels a point, as
    /// the other buildings' (`BronzeBuildingsArt.canvas`): the footprint's
    /// diamond fills the width, with a small margin, and above it there is room
    /// for the building's height. A building keeps its canvas from one look to
    /// the next.
    static func canvas(_ kind: BuildingKind) -> Canvas {
        let footprint = Catalogue.standard.stats(kind).footprint
        let halfWidth = Double(footprint.x + footprint.y) * 16, halfHeight = Double(footprint.x + footprint.y) * 8
        let margin = 4.0
        let top = height(kind)
        return Canvas(minX: -(halfWidth + margin), minY: -top, width: 2 * (halfWidth + margin),
                      height: top + halfHeight + margin, pixelsPerUnit: 2)
    }

    /// How far above the footprint's centre a building's drawing may reach, in
    /// points: the factory's chimney and its smoke, and the hospital's lantern
    /// and flag, above the barracks' 96 and below the town hall's 118.
    static func height(_ kind: BuildingKind) -> Double {
        switch kind {
        case .cannonFactory: 114
        case .hospital: 108
        default: 96
        }
    }

    /// A subject drawn at `pixelsPerUnit` (two for the game): its picture and
    /// its team-colour mask, grained alike.
    static func draw(_ subject: LateBuildingsSubject, pixelsPerUnit: Double = 2) -> Rendered? {
        let canvas = canvas(subject.kind).scaled(to: pixelsPerUnit)
        return Raster.render(on: canvas) { svg in
            switch subject.look {
            case .alchemy:
                var painter = AlchemyOldBuildingsPainter(layer: svg.layer)
                painter.lateBuilding(subject.kind, complete: subject.complete)
                svg = painter.svg
            default:
                var painter = IndustrialOldBuildingsPainter(layer: svg.layer)
                painter.lateBuilding(subject.kind, complete: subject.complete)
                svg = painter.svg
            }
        }
    }

    /// A subject drawn as a sprite.
    static func render(_ subject: LateBuildingsSubject) -> SpriteImage? {
        draw(subject)?.sprite(anchor: canvas(subject.kind).anchor)
    }
}

extension AlchemyOldBuildingsPainter {
    /// The drawing of one of this batch's buildings in the Alchemy look.
    mutating func lateBuilding(_ kind: BuildingKind, complete: Bool) {
        if kind == .cannonFactory { gunFoundry(complete: complete) }
    }
}

extension IndustrialOldBuildingsPainter {
    /// The drawing of one of this batch's buildings in the Industrial look.
    mutating func lateBuilding(_ kind: BuildingKind, complete: Bool) {
        switch kind {
        case .cannonFactory: gunWorks(complete: complete)
        case .hospital: hospital(complete: complete)
        default: break
        }
    }
}

// MARK: Parts both looks share

/// The colours a part shared by both looks is drawn in, from the palette of the look.
struct LateBuildingsMetal: Sendable {
    var body: String, light: String, shade: String, dark: String

    /// The Alchemy age's guns, cast in bronze, in the shades of its gilt.
    static let bronze = LateBuildingsMetal(body: "#b8913f", light: AlchemyOldBuildingsInk.giltLight,
                                           shade: AlchemyOldBuildingsInk.giltShade, dark: "#7a5c26")
    /// The Industrial age's guns, cast in iron.
    static let iron = LateBuildingsMetal(body: IndustrialOldBuildingsInk.iron, light: IndustrialOldBuildingsInk.ironLight,
                                         shade: IndustrialOldBuildingsInk.ironDark, dark: "#242220")
    /// Round shot of either age, of iron.
    static let shot = LateBuildingsMetal(body: "#4a4744", light: "#7c766f", shade: "#33302d", dark: "#242220")
}

/// The fire of a furnace and the smoke of its chimney, alike in both looks:
/// the fire kept to a small glow, mostly its pale heart, so that it is not
/// read as an orange team's colour.
enum LateBuildingsFire {
    static let glow = "#e0913a"
    static let heart = "#f8dc8c"
    static let smoke = "#a39c92"
    static let smokeLight = "#cdc7bc"
    static let smokeDark = "#7d766d"
}

/// What a part shared by both looks needs of a painter: both kits provide it.
protocol LateBuildingsKit {
    var svg: SVG { get set }
    var shift: P { get }
    func iso(_ x: Double, _ y: Double, _ h: Double) -> P
    mutating func colour(_ points: [P], _ paint: Paint, opacity: Double)
    mutating func line(_ points: [P], closed: Bool, width: Double, opacity: Double)
}

extension AlchemyOldBuildingsPainter: LateBuildingsKit {}
extension IndustrialOldBuildingsPainter: LateBuildingsKit {}

extension LateBuildingsKit {
    /// A shape: its colour a little out of register, then its line.
    private mutating func part(_ points: [P], _ paint: Paint, width: Double) {
        colour(points, paint, opacity: 1)
        line(points, closed: true, width: width, opacity: 1)
    }

    /// A gun barrel lying on the screen from its breech at `a` to its muzzle
    /// at `b`, `r` points in radius at the breech: tapering toward the muzzle,
    /// with reinforcing rings, a swell at the muzzle, and the knob of the
    /// cascabel behind the breech, its lit side toward the top.
    mutating func gunBarrel(from a: P, to b: P, radius r: Double, metal m: LateBuildingsMetal) {
        let d = b - a, length = (d.x * d.x + d.y * d.y).squareRoot()
        guard length > 0 else { return }
        let t = d * (1 / length), n = P(-t.y, t.x)
        func at(_ s: Double, _ k: Double) -> P { a + t * (s * length) + n * k }
        let muzzle = r * 0.72
        let outline = [at(0, -r), at(0.92, -muzzle), at(0.94, -muzzle * 1.2), at(1, -muzzle * 1.2), at(1, muzzle * 1.2),
                       at(0.94, muzzle * 1.2), at(0.92, muzzle), at(0, r)]
        // The knob of the cascabel, then the barrel over it.
        svg.circle(a - t * (r * 0.5) + shift, r * 0.5, fill: .colour(m.body))
        svg.circle(a - t * (r * 0.5), r * 0.5, fill: .none, stroke: .colour(IndustrialOldBuildingsInk.line), width: 0.5)
        part(outline, .colour(m.body), width: 0.7)
        // The lit upper side and the shaded lower.
        svg.polygon([at(0.02, -r * 0.8), at(0.9, -muzzle * 0.8), at(0.9, -muzzle * 0.3), at(0.02, -r * 0.3)], fill: .colour(m.light),
                    opacity: 0.8)
        svg.polygon([at(0.02, r * 0.45), at(0.9, muzzle * 0.45), at(0.9, muzzle), at(0.02, r)], fill: .colour(m.shade), opacity: 0.8)
        for s in [0.08, 0.36, 0.62] {
            let k = r + (muzzle - r) * s + 0.35
            part([at(s, -k), at(s + 0.04, -k), at(s + 0.04, k), at(s, k)], .colour(m.shade), width: 0.45)
        }
        // The bore at the muzzle.
        svg.ellipse(at(1, 0), max(0.6, muzzle * 0.3), muzzle * 0.55, fill: .colour(m.dark))
    }

    /// A pyramid of round shot standing at `p` on the screen: `rows` balls in
    /// its lowest row, one fewer in each row above, each `r` points in radius.
    mutating func shotPile(at p: P, rows: Int, radius r: Double, metal m: LateBuildingsMetal = .shot) {
        svg.ellipse(p + P(r * 0.6, r * 0.5), Double(rows) * r * 1.1, r * 0.9, fill: .colour("#000000"), opacity: 0.16)
        for row in 0..<rows {
            let count = rows - row
            for k in 0..<count {
                let c = p + P((Double(k) - Double(count - 1) / 2) * r * 1.9, -r - Double(row) * r * 1.6)
                svg.circle(c + shift * 0.6, r, fill: .colour(m.body))
                svg.circle(c + P(-r * 0.3, -r * 0.3), r * 0.38, fill: .colour(m.light), opacity: 0.8)
                svg.circle(c, r, fill: .none, stroke: .colour(IndustrialOldBuildingsInk.line), width: 0.5)
            }
        }
    }

    /// Smoke rising from a chimney's mouth at `p` on the screen and drifting
    /// to the right: puffs growing and paling as they rise.
    mutating func smoke(at p: P, puffs: Int = 4, size s: Double = 1) {
        typealias F = LateBuildingsFire
        for k in 0..<puffs {
            let f = Double(k)
            let c = p + P((2.6 + f * 4.6) * s, (-3.4 - f * 4.2) * s)
            let rx = (2.8 + f * 1.1) * s, ry = (2.3 + f * 0.8) * s
            let paint = k == 0 ? F.smokeDark : k < puffs - 1 ? F.smoke : F.smokeLight
            svg.ellipse(c + shift * 0.6, rx, ry, fill: .colour(paint), opacity: 0.9 - f * 0.12)
            svg.ellipse(c, rx, ry, fill: .none, stroke: .colour(IndustrialOldBuildingsInk.line), width: 0.5, opacity: 0.6 - f * 0.1)
            svg.ellipse(c + P(-rx * 0.3, -ry * 0.3), rx * 0.4, ry * 0.35, fill: .colour(F.smokeLight), opacity: 0.6)
        }
    }

    /// The glow of a furnace in a dark opening on the screen, its foot
    /// centred on `p`, `w` wide and `h` tall: the heart of the fire low and
    /// pale, its glow round it, and sparks above.
    mutating func furnaceGlow(at p: P, width w: Double, height h: Double) {
        typealias F = LateBuildingsFire
        svg.ellipse(p + P(0, -h * 0.3), w * 0.42, h * 0.32, fill: .colour(F.glow), opacity: 0.85)
        svg.ellipse(p + P(0, -h * 0.24), w * 0.3, h * 0.2, fill: .colour(F.heart))
        for (dx, dy) in [(-0.18, 0.62), (0.12, 0.7), (0.24, 0.56)] {
            svg.circle(p + P(w * dx, -h * dy), 0.5, fill: .colour(F.heart))
        }
    }
}
