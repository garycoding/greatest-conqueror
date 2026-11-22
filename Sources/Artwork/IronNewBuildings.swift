// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
import Synchronization

/// The buildings the Iron age brings, complete and under construction (the
/// farm and the stable), drawn in the Iron age's palette in the manner of the
/// Bronze-age buildings (docs/art-style.md). The buildings carry the owner's
/// colour in a mask. Every other key gives nil.
public struct IronNewBuildingSprites: SpriteSource {
    private let store = Store()

    public init() {}

    public func sprite(_ key: SpriteKey) -> SpriteImage? {
        guard let subject = IronNewBuildingsArt.subject(of: key) else { return nil }
        if let known = store.made.withLock({ $0[key] }) { return known }
        guard let made = IronNewBuildingsArt.render(subject) else { return nil }
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

/// What one of this batch's keys shows.
enum IronNewBuildingsSubject: Hashable, Sendable {
    case building(BuildingKind, complete: Bool)
}

/// What this batch draws, on what canvas, and the drawing of it.
enum IronNewBuildingsArt {
    /// The Iron age's new buildings.
    static let kinds: [BuildingKind] = [.farm, .stable]

    /// The buildings whose Iron drawing serves for the Bronze look too: the
    /// farm, which Greatest Conqueror brings in the age of farms, drawn in the
    /// Bronze look, whilst Cities of Progress drew it only from the Iron age
    /// (the art mapping of 2026-11-22: reuse where it fits).
    static let lookAlikes: [BuildingKind] = [.farm]

    /// The subject a key names, if it is one of this batch's: a new building
    /// of the Iron age in the Iron look, or one of `lookAlikes` in the Bronze
    /// look, complete or under construction, at frame 0.
    static func subject(of key: SpriteKey) -> IronNewBuildingsSubject? {
        guard key.frame == 0 else { return nil }
        switch key.subject {
        case .building(let kind, .iron) where kinds.contains(kind),
             .building(let kind, .bronze) where lookAlikes.contains(kind):
            if key.pose == .complete { return .building(kind, complete: true) }
            if key.pose == .underConstruction { return .building(kind, complete: false) }
            return nil
        default:
            return nil
        }
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
        case .farm: 76
        case .stable: 92
        default: 80
        }
    }

    /// A subject drawn as a sprite: its picture and its team-colour mask, grained alike.
    static func render(_ subject: IronNewBuildingsSubject) -> SpriteImage? {
        switch subject {
        case .building(let kind, let complete):
            let canvas = canvas(kind)
            let rendered = Raster.render(on: canvas) { svg in
                var painter = IronNewBuildingsPainter(layer: svg.layer)
                painter.building(kind, complete: complete)
                svg = painter.svg
            }
            return rendered?.sprite(anchor: canvas.anchor)
        }
    }
}

extension IronNewBuildingsPainter {
    /// The drawing of a building, complete or under construction.
    mutating func building(_ kind: BuildingKind, complete: Bool) {
        switch kind {
        case .farm: farm(complete: complete)
        case .stable: stable(complete: complete)
        default: break
        }
    }
}
