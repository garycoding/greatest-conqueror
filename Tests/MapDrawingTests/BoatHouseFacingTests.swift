// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Artwork
import CoreGraphics
import GameCore
import SpriteKit
import Testing
@testable import MapDrawing

/// A source that draws a boat house in the side and back views, each a
/// different size, so that the drawing's choice of view can be read.
private struct BoatHouseViews: SpriteSource {
    func sprite(_ key: SpriteKey) -> SpriteImage? {
        guard case .building(.boatHouse, _) = key.subject, key.frame == 0 else { return nil }
        let width = key.view == .back ? 60 : 40
        let image = Placeholders.render(CGSize(width: width, height: 30)) { c in
            c.setFillColor(Placeholders.colour(0.5, 0.4, 0.3))
            c.fill(CGRect(x: 0, y: 0, width: width, height: 30))
        }
        return SpriteImage(base: image, teamMask: nil, anchor: SpriteAnchor(x: 0.5, y: 0.3))
    }
}

extension PlayerView {
    /// Adds a complete building of the viewer's with its footprint's origin at `origin`.
    fileprivate mutating func addBoatHouse(at origin: GridPoint) -> EntityID {
        let id = EntityID((entities.map(\.id.rawValue).max() ?? 0) + 1)
        let health = Catalogue.standard.stats(.boatHouse).health
        entities.append(EntityView(id: id, owner: player, kind: .building(.boatHouse),
                                   position: Placement.centre(.boatHouse, origin: origin), tile: origin, facing: .right,
                                   health: health, maxHealth: health, activity: .idle))
        return id
    }
}

/// The boat house faces its water (ruled 2026-11-22, all four edges): the side
/// view toward +x, mirrored toward +y; the back view toward −y, mirrored toward −x.
@MainActor
@Suite struct BoatHouseFacingTests {
    @Test func eachBoatHouseIsDrawnFacingItsWater() throws {
        var view = Samples.stoneAgeOpening()
        let w = view.mapWidth
        // Four boat houses, each with water along one edge only.
        let places: [(GridPoint, [GridPoint], width: CGFloat, xScale: CGFloat)] = [
            (GridPoint(20, 4), [GridPoint(22, 4), GridPoint(22, 5)], 40, 1),     // +x: the side view
            (GridPoint(26, 4), [GridPoint(26, 6), GridPoint(27, 6)], 40, -1),    // +y: the side view mirrored
            (GridPoint(20, 12), [GridPoint(20, 11), GridPoint(21, 11)], 60, 1),  // −y: the back view
            (GridPoint(26, 12), [GridPoint(25, 12), GridPoint(25, 13)], 60, -1), // −x: the back view mirrored
        ]
        var ids: [EntityID] = []
        for (origin, water, _, _) in places {
            for t in water { view.terrain[t.y * w + t.x] = .shallowWater }
            ids.append(view.addBoatHouse(at: origin))
        }
        let (session, _) = makeSession(view)
        let scene = MapScene(session: session, sprites: BoatHouseViews(), size: screenSize)
        for (id, place) in zip(ids, places) {
            let node = try #require(scene.entityNodes[id])
            #expect(node.body.size.width == place.width, "\(place.0)")
            #expect(node.body.xScale == place.xScale, "\(place.0)")
        }
    }

    @Test func aBoatHouseWithNoBackViewFallsBackToTheSide() throws {
        var view = Samples.stoneAgeOpening()
        let w = view.mapWidth
        for t in [GridPoint(20, 11), GridPoint(21, 11)] { view.terrain[t.y * w + t.x] = .shallowWater }
        let id = view.addBoatHouse(at: GridPoint(20, 12))
        struct SideOnly: SpriteSource {
            func sprite(_ key: SpriteKey) -> SpriteImage? { key.view == .side ? BoatHouseViews().sprite(key) : nil }
        }
        let (session, _) = makeSession(view)
        let scene = MapScene(session: session, sprites: SideOnly(), size: screenSize)
        #expect(try #require(scene.entityNodes[id]).body.size.width == 40)
    }
}
