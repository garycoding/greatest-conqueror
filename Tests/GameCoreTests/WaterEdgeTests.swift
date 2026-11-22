// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
import Testing

/// The boat house faces its water (ruled 2026-11-22: on all four edges).
@Suite struct WaterEdgeTests {
    /// A field of grass 12 × 12 with water on the tiles given.
    private func field(water: [GridPoint]) -> [Terrain] {
        var terrain = Array(repeating: Terrain.grass, count: 144)
        for t in water { terrain[t.y * 12 + t.x] = .shallowWater }
        return terrain
    }

    private func edge(_ water: [GridPoint]) -> FootprintEdge {
        Placement.waterEdge(.boatHouse, at: GridPoint(5, 5), width: 12, height: 12, terrain: field(water: water))
    }

    @Test func eachEdgeIsFoundByItsWater() {
        // The footprint covers (5, 5) to (6, 6).
        #expect(edge([GridPoint(7, 5), GridPoint(7, 6)]) == .plusX)
        #expect(edge([GridPoint(5, 7), GridPoint(6, 7)]) == .plusY)
        #expect(edge([GridPoint(5, 4), GridPoint(6, 4)]) == .minusY)
        #expect(edge([GridPoint(4, 5), GridPoint(4, 6)]) == .minusX)
    }

    @Test func theEdgeWithMoreWaterWins() {
        #expect(edge([GridPoint(7, 5), GridPoint(4, 5), GridPoint(4, 6)]) == .minusX)
        #expect(edge([GridPoint(5, 4), GridPoint(6, 4), GridPoint(5, 7)]) == .minusY)
    }

    @Test func tiesGoToTheEdgesTowardTheViewerFirst() {
        #expect(edge([GridPoint(7, 5), GridPoint(5, 7)]) == .plusX)
        #expect(edge([GridPoint(5, 7), GridPoint(5, 4)]) == .plusY)
        #expect(edge([GridPoint(5, 4), GridPoint(4, 5)]) == .minusY)
        // Corners touch no edge; with no water, the side view as drawn.
        #expect(edge([GridPoint(7, 7), GridPoint(4, 4)]) == .plusX)
    }

    @Test func atTheMapsEdgeTheTilesBeyondAreNotWater() {
        let terrain = field(water: [GridPoint(0, 1)])
        #expect(Placement.waterEdge(.boatHouse, at: GridPoint(0, 2), width: 12, height: 12, terrain: terrain) == .minusY)
        #expect(Placement.waterEdge(.boatHouse, at: GridPoint(10, 10), width: 12, height: 12, terrain: terrain) == .plusX)
    }

    @Test func eachEdgeHasItsViewAndMirror() {
        #expect(FootprintEdge.plusX.boatHouseView == (.side, false))
        #expect(FootprintEdge.plusY.boatHouseView == (.side, true))
        #expect(FootprintEdge.minusY.boatHouseView == (.back, false))
        #expect(FootprintEdge.minusX.boatHouseView == (.back, true))
    }
}
