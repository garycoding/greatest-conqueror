// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
import Synchronization

/// The buildings the Alchemy age brings, complete and under construction (the
/// castle and the alchemist's workshop), drawn in the Alchemy age's palette in
/// the manner of the Iron-age buildings (docs/art-style.md). Each carries the
/// owner's colour in a mask. Every other key gives nil.
public struct AlchemyNewBuildingSprites: SpriteSource {
    private let store = Store()

    public init() {}

    public func sprite(_ key: SpriteKey) -> SpriteImage? {
        guard let subject = AlchemyNewBuildingsArt.subject(of: key) else { return nil }
        if let known = store.made.withLock({ $0[key] }) { return known }
        guard let made = AlchemyNewBuildingsArt.render(subject) else { return nil }
        return store.made.withLock { cache in
            if let known = cache[key] { return known }
            cache[key] = made
            return made
        }
    }
}

/// The sprites drawn so far, so that each is drawn once.
private final class Store: Sendable {
    let made = Mutex<[SpriteKey: SpriteImage]>([:])
}

/// What one of this batch's keys shows: a building, complete or under construction.
struct AlchemyNewBuildingsSubject: Hashable, Sendable {
    var kind: BuildingKind
    var complete: Bool
}

/// What this batch draws, on what canvas, and the drawing of it.
enum AlchemyNewBuildingsArt {
    /// The Alchemy age's new buildings.
    static let kinds: [BuildingKind] = [.castle, .alchemistsWorkshop]

    /// The subject a key names, if it is one of this batch's: a new building
    /// of the Alchemy age in the Alchemy age's look, complete or under
    /// construction, at frame 0.
    static func subject(of key: SpriteKey) -> AlchemyNewBuildingsSubject? {
        guard key.frame == 0, case .building(let kind, .alchemy) = key.subject, kinds.contains(kind) else { return nil }
        if key.pose == .complete { return AlchemyNewBuildingsSubject(kind: kind, complete: true) }
        if key.pose == .underConstruction { return AlchemyNewBuildingsSubject(kind: kind, complete: false) }
        return nil
    }

    /// The area a building's sprite covers, in points with the origin on the
    /// ground at the centre of its footprint, drawn at two pixels a point. The
    /// footprint's diamond fills the width, with a small margin; above it
    /// there is room for the building's height.
    static func canvas(_ kind: BuildingKind) -> Canvas {
        let footprint = Catalogue.standard.stats(kind).footprint
        let halfWidth = Double(footprint.x + footprint.y) * 16, halfHeight = Double(footprint.x + footprint.y) * 8
        let margin = 4.0
        let top = height(kind)
        return Canvas(minX: -(halfWidth + margin), minY: -top, width: 2 * (halfWidth + margin),
                      height: top + halfHeight + margin, pixelsPerUnit: 2)
    }

    /// How far above the footprint's centre a building's drawing may reach, in points.
    static func height(_ kind: BuildingKind) -> Double {
        switch kind {
        case .castle: 182
        case .alchemistsWorkshop: 172
        default: 80
        }
    }

    /// A subject drawn as a sprite: its picture and its team-colour mask, grained alike.
    static func render(_ subject: AlchemyNewBuildingsSubject) -> SpriteImage? {
        let canvas = canvas(subject.kind)
        let rendered = Raster.render(on: canvas) { svg in
            var painter = AlchemyNewBuildingsPainter(layer: svg.layer)
            painter.building(subject.kind, complete: subject.complete)
            svg = painter.svg
        }
        return rendered?.sprite(anchor: canvas.anchor)
    }
}

extension AlchemyNewBuildingsPainter {
    /// The drawing of a building, complete or under construction.
    mutating func building(_ kind: BuildingKind, complete: Bool) {
        switch kind {
        case .castle: castle(complete: complete)
        case .alchemistsWorkshop: workshop(complete: complete)
        default: break
        }
    }
}
