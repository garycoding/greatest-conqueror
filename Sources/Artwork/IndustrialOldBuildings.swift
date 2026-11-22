// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
import Synchronization

/// The buildings of the earlier ages in the look of the Industrial age,
/// complete and under construction (the boat house among them, ruled
/// 2026-11-21): red brick with dressed-stone trim, slate
/// roofs with chimney pots, sash windows, cast-iron columns and railings, and
/// gas lamps, in the style of docs/art-style.md. A building takes the look of
/// its owner's age (`SpriteSubject.of`), so these replace the Alchemy looks
/// once a player reaches the age of hospitals, drawn in the Industrial look.
/// Every key but this batch's gives nil. Each building is drawn
/// in the side view; the boat house is drawn in the back view as well (ruled
/// 2026-11-22), so that it can face whichever edge of its footprint touches
/// water (`FootprintEdge.boatHouseView`).
public struct IndustrialOldBuildingSprites: ViewedSpriteSource {
    private let store = Store()

    public init() {}

    /// Only the boat house is drawn in a view other than the side, and only in the back view.
    public func drawsViews(of subject: SpriteSubject) -> Bool { subject == .building(.boatHouse, .industrial) }

    public func sprite(_ key: SpriteKey) -> SpriteImage? {
        guard let subject = IndustrialOldBuildingsArt.subject(of: key) else { return nil }
        if let known = store.made.withLock({ $0[key] }) { return known }
        guard let made = IndustrialOldBuildingsArt.render(subject.kind, complete: subject.complete, view: key.view) else { return nil }
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

/// What this batch draws, on what canvas, and the drawing of it.
enum IndustrialOldBuildingsArt {
    /// The buildings this batch draws: those of the Stone, Bronze, Iron and Alchemy ages.
    static let kinds: [BuildingKind] = [.townCentre, .house, .barracks, .tower,
                                        .farm, .stable, .castle, .boatHouse]

    /// The buildings drawn with the kit of the larger works (`IndustrialOldBuildingsLatePainter`).
    static let late: [BuildingKind] = [.castle]

    /// The building and pose a key names, if it is one of this batch's: a
    /// building of an earlier age in the Industrial age's look, complete or
    /// under construction, at frame 0, in the side view; or the boat house in
    /// the back view.
    static func subject(of key: SpriteKey) -> (kind: BuildingKind, complete: Bool)? {
        guard case .building(let kind, .industrial) = key.subject, key.frame == 0, kinds.contains(kind) else { return nil }
        guard key.view == .side || (kind == .boatHouse && key.view == .back) else { return nil }
        if key.pose == .complete { return (kind, true) }
        if key.pose == .underConstruction { return (kind, false) }
        return nil
    }

    /// The canvas of the Alchemy look of the same building, so that a
    /// building keeps its size and anchor from one age to the next. The boat
    /// house keeps the canvas of its Stone look.
    static func canvas(_ kind: BuildingKind) -> Canvas {
        if kind == .boatHouse { return boatHouseCanvas }
        return late.contains(kind) ? AlchemyNewBuildingsArt.canvas(kind) : AlchemyOldBuildingsArt.canvas(kind)
    }

    /// The boat house's canvas, the Stone age's (`StoneBuildingsPiece.canvas`),
    /// grown 16 points to the right and 10 down for the dock beyond the
    /// footprint (ruled 2026-11-22), the same in every age.
    static let boatHouseCanvas = Canvas(minX: -68, minY: -108, width: 152, height: 154, pixelsPerUnit: 2)

    /// A building drawn at `pixelsPerUnit` (two for the game) in `view`: its
    /// picture and its mask, grained alike. Only the boat house has a view
    /// other than the side, the back, on the same canvas.
    static func draw(_ kind: BuildingKind, complete: Bool, view: SpriteView = .side, pixelsPerUnit: Double = 2) -> Rendered? {
        guard view == .side || (kind == .boatHouse && view == .back) else { return nil }
        let canvas = canvas(kind).scaled(to: pixelsPerUnit)
        return Raster.render(on: canvas) { svg in
            if view == .back {
                var painter = IndustrialOldBuildingsPainter(layer: svg.layer)
                painter.boatHouse(complete: complete, turn: .back)
                svg = painter.svg
            } else if late.contains(kind) {
                var painter = IndustrialOldBuildingsLatePainter(layer: svg.layer)
                painter.building(kind, complete: complete)
                svg = painter.svg
            } else {
                var painter = IndustrialOldBuildingsPainter(layer: svg.layer)
                painter.building(kind, complete: complete)
                svg = painter.svg
            }
        }
    }

    /// A building drawn as a sprite.
    static func render(_ kind: BuildingKind, complete: Bool, view: SpriteView = .side) -> SpriteImage? {
        draw(kind, complete: complete, view: view)?.sprite(anchor: canvas(kind).anchor)
    }
}

extension IndustrialOldBuildingsPainter {
    /// The drawing of a building, complete or under construction.
    mutating func building(_ kind: BuildingKind, complete: Bool) {
        switch kind {
        case .townCentre: townCentre(complete: complete)
        case .house: house(complete: complete)
        case .barracks: barracks(complete: complete)
        case .tower: watchTower(complete: complete)
        case .farm: farm(complete: complete)
        case .stable: stable(complete: complete)
        case .boatHouse: boatHouse(complete: complete, turn: .side)
        // Drawn with the kit of the larger works, or by another batch.
        case .castle: break
        // Drawn by their own batch (`LateBuildingSprites`).
        case .cannonFactory, .hospital: break
        }
    }
}

extension IndustrialOldBuildingsLatePainter {
    /// The drawing of a building, complete or under construction.
    mutating func building(_ kind: BuildingKind, complete: Bool) {
        switch kind {
        case .castle: castle(complete: complete)
        default: break
        }
    }
}
