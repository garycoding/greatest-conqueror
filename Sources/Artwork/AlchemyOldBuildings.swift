// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
import Synchronization

/// The buildings of the earlier ages in the look of the Alchemy age, complete
/// and under construction: half-timbering over stone, steep roofs of slate,
/// glazed windows, and gilt finials and weathervanes, in the style of
/// docs/art-style.md. A building takes the look of its owner's age
/// (`SpriteSubject.of`), so these replace the Iron looks once a player
/// reaches the Alchemy age. The castle and the alchemist's workshop are drawn
/// by another batch; every key but this batch's gives nil. The boat house is
/// drawn in the side view and the back view as well (ruled 2026-11-22), so
/// that it faces its water on any edge; every other building in the side
/// view alone.
public struct AlchemyOldBuildingSprites: ViewedSpriteSource {
    private let store = Store()

    public init() {}

    public func drawsViews(of subject: SpriteSubject) -> Bool { subject == .building(.boatHouse, .alchemy) }

    public func sprite(_ key: SpriteKey) -> SpriteImage? {
        guard let subject = AlchemyOldBuildingsArt.subject(of: key) else { return nil }
        if let known = store.made.withLock({ $0[key] }) { return known }
        guard let made = AlchemyOldBuildingsArt.render(subject.kind, complete: subject.complete, view: subject.view) else { return nil }
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
enum AlchemyOldBuildingsArt {
    /// The buildings this batch draws: those of the Stone, Bronze and Iron ages,
    /// the boat house among them (ruled 2026-11-21).
    static let kinds: [BuildingKind] = [.townCentre, .house, .barracks, .tower,
                                        .farm, .stable, .boatHouse]

    /// The building, pose and view a key names, if it is one of this batch's:
    /// a building of an earlier age in the Alchemy age's look, complete or
    /// under construction, at frame 0, in the side view, or the boat house in
    /// the back view.
    static func subject(of key: SpriteKey) -> (kind: BuildingKind, complete: Bool, view: SpriteView)? {
        guard case .building(let kind, .alchemy) = key.subject, key.frame == 0, kinds.contains(kind) else { return nil }
        guard key.view == .side || (kind == .boatHouse && key.view == .back) else { return nil }
        if key.pose == .complete { return (kind, true, key.view) }
        if key.pose == .underConstruction { return (kind, false, key.view) }
        return nil
    }

    /// The canvas of the Iron look of the same building, so that a building
    /// keeps its size and anchor from one age to the next.
    static func canvas(_ kind: BuildingKind) -> Canvas {
        IronNewBuildingsArt.kinds.contains(kind) ? IronNewBuildingsArt.canvas(kind) : IronOldBuildingsArt.canvas(kind)
    }

    /// A building drawn as a sprite: its picture and its team-colour mask,
    /// grained alike. The back view is the boat house's alone, on the side
    /// view's canvas.
    static func render(_ kind: BuildingKind, complete: Bool, view: SpriteView = .side) -> SpriteImage? {
        let canvas = canvas(kind)
        let rendered = Raster.render(on: canvas) { svg in
            var painter = AlchemyOldBuildingsPainter(layer: svg.layer)
            if kind == .boatHouse && view == .back {
                painter.boatHouse(complete: complete, back: true)
            } else {
                painter.building(kind, complete: complete)
            }
            svg = painter.svg
        }
        return rendered?.sprite(anchor: canvas.anchor)
    }
}

extension AlchemyOldBuildingsPainter {
    /// The drawing of a building, complete or under construction.
    mutating func building(_ kind: BuildingKind, complete: Bool) {
        switch kind {
        case .townCentre: townCentre(complete: complete)
        case .house: house(complete: complete)
        case .barracks: barracks(complete: complete)
        case .tower: watchTower(complete: complete)
        case .farm: farm(complete: complete)
        case .stable: stable(complete: complete)
        case .boatHouse: boatHouse(complete: complete)
        // The Alchemy age's own buildings are drawn by their own batch.
        case .castle: break
        // Drawn as stand-ins (`StandIn`) until their own art is made.
        case .cannonFactory, .hospital: break
        }
    }
}
