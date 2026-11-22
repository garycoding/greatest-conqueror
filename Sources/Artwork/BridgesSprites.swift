// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
import Synchronization

// The bridge (ruled 2026-11-21): one water tile's piece of a straight bridge
// two tiles wide, a lane in each row, its deck rising from each bank toward
// the middle, drawn for each age from the Stone to the Industrial after the
// bridges of that age's period: round logs lashed on piles (Stone), sawn
// planks on braced trestles (Bronze), Roman stone arches (Iron), a fortified
// medieval bridge of pointed cutwaters with a gatehouse on its middle piece
// (Alchemy), and cast-iron arch ribs on stone piers (Industrial).
//
// A piece is drawn for its lane: the far lane draws the far half of the
// bridge, and the near lane, drawn after it, the near half and whatever
// stands across both (the gatehouse). Its key (`BridgePlace.pose`) names the
// deck's height at its two edges, so that the pieces of a row join into one
// rise; everything that repeats along the run divides the tile evenly, and
// what stands on a joint is drawn by both pieces in the same place.

/// The sprites of the bridge: `SpriteSubject.building(.bridge, age)` for every
/// age from `.stone` to `.industrial`, in the poses `BridgePlace.pose(complete:)`
/// gives for every place in `BridgePlace.drawings`, at frame 0. Every other key gives nil, the bridge's own `complete`
/// and `underConstruction` among them. A picture is drawn the first time it is
/// asked for and kept.
public struct BridgeSprites: SpriteSource {
    private let kept = BridgesKept()

    public init() {}

    public func sprite(_ key: SpriteKey) -> SpriteImage? {
        guard let piece = BridgesPiece(key) else { return nil }
        if let known = kept.images.withLock({ $0[piece] }) { return known }
        guard let made = piece.render() else { return nil }
        return kept.images.withLock { images in
            if let first = images[piece] { return first }
            images[piece] = made
            return made
        }
    }
}

/// The pictures drawn so far, safe to share between the threads that ask.
final class BridgesKept: Sendable {
    let images = Mutex<[BridgesPiece: SpriteImage]>([:])
}

/// The ways a bridge is built, one for each age.
enum BridgesLook: Sendable {
    /// Round logs lashed across stringers on piles, with rope rails (Stone).
    case logs
    /// Sawn planks on braced trestles, with wattle rails (Bronze).
    case beams
    /// Roman stone arches under a paved road and parapets (Iron).
    case roman
    /// Flatter arches between pointed cutwaters, refuges in the parapets, and a gatehouse (Alchemy).
    case fortified
    /// Cast-iron arch ribs on stone piers under a road of setts (Industrial).
    case castIron

    /// The height of the walking surface above the water at a bank, in
    /// points: low, so that a person drawn at the tile's ground level reads as
    /// standing on it. The deck rises from it by `BridgePlace.heights`.
    static let deckHeight = 6.0
}

/// One of the batch's pictures: an age's piece in a place, complete or not.
struct BridgesPiece: Hashable, Sendable {
    var age: Age
    var place: BridgePlace
    var complete: Bool

    /// The ages this batch draws.
    static let ages: [Age] = [.stone, .bronze, .iron, .alchemy, .industrial]

    /// Every key of the batch.
    static let keys: [SpriteKey] = ages.flatMap { age in
        BridgePlace.drawings.flatMap { place in
            [true, false].map { SpriteKey(.building(.bridge, age), place.pose(complete: $0)) }
        }
    }

    /// The place each pose names.
    private static let places: [SpritePose: (BridgePlace, Bool)] = {
        var out: [SpritePose: (BridgePlace, Bool)] = [:]
        for place in BridgePlace.drawings {
            out[place.pose(complete: true)] = (place, true)
            out[place.pose(complete: false)] = (place, false)
        }
        return out
    }()

    init(age: Age, place: BridgePlace, complete: Bool) {
        self.age = age; self.place = place; self.complete = complete
    }

    /// The piece a key names, or nil where the key is not this batch's.
    init?(_ key: SpriteKey) {
        guard key.frame == 0, case .building(.bridge, let age) = key.subject, BridgesPiece.ages.contains(age),
              let (place, complete) = BridgesPiece.places[key.pose] else { return nil }
        self.init(age: age, place: place, complete: complete)
    }

    var look: BridgesLook {
        switch age {
        case .stone: .logs
        case .bronze: .beams
        case .iron: .roman
        case .alchemy: .fortified
        case .industrial, .silicon, .ai: .castIron
        }
    }

    /// The part of the picture's plane every piece covers, in points, with the
    /// origin on the water at the centre of the tile, drawn at twice its size
    /// (docs/architecture.md, "Sprites"): room across for the other lane,
    /// over which the near lane's gatehouse stands, and above for the rise,
    /// the rails, the pennant and the gatehouse.
    static let canvas = Canvas(minX: -76, minY: -128, width: 152, height: 166, pixelsPerUnit: 2)

    /// The picture and its team-colour mask, anchored at the centre of the tile.
    func render() -> SpriteImage? {
        render(on: BridgesPiece.canvas)?.sprite(anchor: BridgesPiece.canvas.anchor)
    }

    /// The picture on a canvas of the batch's area at any scale (to look closely).
    func render(on canvas: Canvas) -> Rendered? {
        Raster.render(on: canvas) { svg in
            var painter = BridgesPainter(layer: svg.layer, place: place)
            switch look {
            case .logs: painter.logs(complete: complete)
            case .beams: painter.beams(complete: complete)
            case .roman: painter.roman(complete: complete)
            case .fortified: painter.fortified(complete: complete)
            case .castIron: painter.castIron(complete: complete)
            }
            svg = painter.svg
        }
    }
}
