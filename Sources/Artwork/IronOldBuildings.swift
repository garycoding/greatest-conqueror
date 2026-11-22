// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
import Synchronization

/// The buildings of the Stone and Bronze ages in the look of the Iron age,
/// complete and under construction: dressed stone, lime plaster, red tile
/// roofs, columns, and iron fittings and grilles, in the style of
/// docs/art-style.md. A building takes the look of its owner's age
/// (`SpriteSubject.of`), so these replace the Bronze looks once a player
/// reaches the Iron age. The Iron age's own buildings are drawn by another
/// batch; every key but this batch's gives nil. The boat house alone is drawn
/// in two views (ruled 2026-11-22): the side, its water side toward +x, and
/// the back, its water side toward −y; every other key is the side's.
public struct IronOldBuildingSprites: ViewedSpriteSource {
    private let store = Store()

    public init() {}

    public func sprite(_ key: SpriteKey) -> SpriteImage? {
        guard let subject = IronOldBuildingsArt.subject(of: key) else { return nil }
        if let known = store.made.withLock({ $0[key] }) { return known }
        guard let made = IronOldBuildingsArt.render(subject.kind, complete: subject.complete, view: subject.view) else { return nil }
        return store.made.withLock { made_ in
            if let first = made_[key] { return first }
            made_[key] = made
            return made
        }
    }

    /// The boat house is drawn in the back view as well as the side; nothing else is.
    public func drawsViews(of subject: SpriteSubject) -> Bool { subject == .building(.boatHouse, .iron) }
}

/// The sprites drawn so far, so that each is drawn once.
private final class Store: Sendable {
    let made = Mutex<[SpriteKey: SpriteImage]>([:])
}

/// What this batch draws, on what canvas, and the drawing of it.
enum IronOldBuildingsArt {
    /// The buildings this batch draws: those of the Stone and Bronze ages, the boat house among them.
    static let kinds: [BuildingKind] = [.townCentre, .house, .barracks, .watchTower, .boatHouse]

    /// The building, pose and view a key names, if it is one of this batch's:
    /// a building of the Stone or Bronze age in the Iron age's look, complete
    /// or under construction, at frame 0, in the side view, or the boat house
    /// in the back view.
    static func subject(of key: SpriteKey) -> (kind: BuildingKind, complete: Bool, view: SpriteView)? {
        guard case .building(let kind, .iron) = key.subject, key.frame == 0, kinds.contains(kind) else { return nil }
        guard key.view == .side || (kind == .boatHouse && key.view == .back) else { return nil }
        if key.pose == .complete { return (kind, true, key.view) }
        if key.pose == .underConstruction { return (kind, false, key.view) }
        return nil
    }

    /// The canvas of the Bronze look of the same building, so that a building
    /// keeps its size and anchor from one age to the next.
    static func canvas(_ kind: BuildingKind) -> Canvas { BronzeBuildingsArt.canvas(kind) }

    /// A building drawn as a sprite, in the side view or (the boat house) the
    /// back: its picture and its team-colour mask, grained alike.
    static func render(_ kind: BuildingKind, complete: Bool, view: SpriteView = .side) -> SpriteImage? {
        let canvas = canvas(kind)
        let rendered = Raster.render(on: canvas) { svg in
            var painter = IronOldBuildingsPainter(layer: svg.layer)
            painter.building(kind, complete: complete, view: view)
            svg = painter.svg
        }
        return rendered?.sprite(anchor: canvas.anchor)
    }
}

extension IronOldBuildingsPainter {
    /// The drawing of a building, complete or under construction; `view` is
    /// read for the boat house alone, which is drawn in the side and back views.
    mutating func building(_ kind: BuildingKind, complete: Bool, view: SpriteView = .side) {
        switch kind {
        case .townCentre: townCentre(complete: complete)
        case .house: house(complete: complete)
        case .barracks: barracks(complete: complete)
        case .watchTower: watchTower(complete: complete)
        case .boatHouse: boatHouse(complete: complete, view: view)
        // The Iron age's own buildings are drawn by their own batch.
        case .farm, .stable, .castle: break
        }
    }
}
