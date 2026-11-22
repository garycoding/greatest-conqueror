// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

/// The one rule for where things may stand, so that the simulation, the
/// drawing's placement outline and the computer player agree.
///
/// - A tile is passable when its terrain is passable, no building's footprint
///   covers it, and no site that `blocksTile` remains on it. People do not
///   block one another or buildings.
/// - A building may be placed when every tile of its footprint is inside the
///   map, buildable, free of footprints and blocking sites, and explored by the
///   placing player.
public enum Placement {
    /// The tiles a building covers, from its origin toward +x and +y.
    public static func footprint(_ kind: BuildingKind, at origin: GridPoint, catalogue: Catalogue = .standard) -> [GridPoint] {
        let size = catalogue.stats(kind).footprint
        var tiles: [GridPoint] = []
        for dy in 0..<size.y { for dx in 0..<size.x { tiles.append(GridPoint(origin.x + dx, origin.y + dy)) } }
        return tiles
    }

    /// The origin tile of a building whose footprint is centred on `centre`.
    public static func origin(_ kind: BuildingKind, centre: MapPosition, catalogue: Catalogue = .standard) -> GridPoint {
        let size = catalogue.stats(kind).footprint
        return GridPoint(Int((centre.x - Double(size.x) / 2).rounded()), Int((centre.y - Double(size.y) / 2).rounded()))
    }

    /// The centre of a building's footprint, which is its `EntityView.position`.
    public static func centre(_ kind: BuildingKind, origin: GridPoint, catalogue: Catalogue = .standard) -> MapPosition {
        let size = catalogue.stats(kind).footprint
        return MapPosition(x: Double(origin.x) + Double(size.x) / 2, y: Double(origin.y) + Double(size.y) / 2)
    }

    /// The occupied tiles of a map: building footprints and blocking sites.
    public static func occupied(buildings: [(kind: BuildingKind, origin: GridPoint)], sites: [ResourceSite],
                                catalogue: Catalogue = .standard) -> Set<GridPoint> {
        var out = Set<GridPoint>()
        for b in buildings { for t in footprint(b.kind, at: b.origin, catalogue: catalogue) { out.insert(t) } }
        for s in sites where s.kind.blocksTile && s.remaining > 0 { out.insert(s.tile) }
        return out
    }

    /// Whether a building of `kind` may be placed with its origin at `origin`.
    /// `explored` answers whether the placing player has explored a tile.
    public static func canPlace(_ kind: BuildingKind, at origin: GridPoint, width: Int, height: Int,
                                terrain: [Terrain], occupied: Set<GridPoint>,
                                explored: (GridPoint) -> Bool, catalogue: Catalogue = .standard) -> Bool {
        let tiles = footprint(kind, at: origin, catalogue: catalogue)
        if kind == .boatHouse && !touchesWater(tiles, width: width, height: height, terrain: terrain) { return false }
        return tiles.allSatisfy { t in
            t.x >= 0 && t.y >= 0 && t.x < width && t.y < height
                && terrain[t.y * width + t.x].isBuildable && !occupied.contains(t) && explored(t)
        }
    }

    /// Whether a footprint has a water tile beside one of its edges, as a boat
    /// house's must (ruled 2026-11-21): the boats come and go on that water.
    public static func touchesWater(_ tiles: [GridPoint], width: Int, height: Int, terrain: [Terrain]) -> Bool {
        let inside = Set(tiles)
        for t in tiles {
            for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let n = GridPoint(t.x + dx, t.y + dy)
                guard !inside.contains(n), n.x >= 0, n.y >= 0, n.x < width, n.y < height else { continue }
                if terrain[n.y * width + n.x].isWater { return true }
            }
        }
        return false
    }

    /// The edge of a building's footprint that faces the water most: the one
    /// with most water tiles along it, ties going to +x, +y, −y, −x in that
    /// order (the edges toward the viewer first); +x when no edge touches
    /// water. A boat house is drawn facing it (ruled 2026-11-22). Terrain never
    /// changes in a match, so this is worked out, not stored.
    public static func waterEdge(_ kind: BuildingKind, at origin: GridPoint, width: Int, height: Int, terrain: [Terrain],
                                 catalogue: Catalogue = .standard) -> FootprintEdge {
        let size = catalogue.stats(kind).footprint
        func water(_ tiles: [GridPoint]) -> Int {
            tiles.filter { $0.x >= 0 && $0.y >= 0 && $0.x < width && $0.y < height && terrain[$0.y * width + $0.x].isWater }.count
        }
        let alongX = (0..<size.x).map { origin.x + $0 }, alongY = (0..<size.y).map { origin.y + $0 }
        let counts: [(FootprintEdge, Int)] = [
            (.plusX, water(alongY.map { GridPoint(origin.x + size.x, $0) })),
            (.plusY, water(alongX.map { GridPoint($0, origin.y + size.y) })),
            (.minusY, water(alongX.map { GridPoint($0, origin.y - 1) })),
            (.minusX, water(alongY.map { GridPoint(origin.x - 1, $0) })),
        ]
        var best = counts[0]
        for c in counts.dropFirst() where c.1 > best.1 { best = c }
        return best.0
    }

    /// The same rule as the player sees it: for the drawing's outline and the
    /// computer player. The simulation applies it to its full state. An
    /// outcrop (`PlayerView.outcrops`) is a deposit not yet revealed, and
    /// blocks its tile as the deposit does.
    public static func canPlace(_ kind: BuildingKind, at origin: GridPoint, in view: PlayerView,
                                catalogue: Catalogue = .standard) -> Bool {
        let buildings: [(kind: BuildingKind, origin: GridPoint)] = view.entities.compactMap {
            if case .building(let k) = $0.kind { return (k, $0.tile) } else { return nil }
        }
        var occupied = occupied(buildings: buildings, sites: view.sites, catalogue: catalogue)
        for t in view.outcrops { occupied.insert(t) }
        return canPlace(kind, at: origin, width: view.mapWidth, height: view.mapHeight, terrain: view.terrain,
                        occupied: occupied, explored: { view.visibility(at: $0) != .unexplored }, catalogue: catalogue)
    }
}

/// An edge of a building's footprint, by the map axis it faces.
public enum FootprintEdge: Sendable, Hashable, CaseIterable {
    /// Toward +x: the screen's lower right.
    case plusX
    /// Toward +y: the screen's lower left.
    case plusY
    /// Toward −y: the screen's upper right.
    case minusY
    /// Toward −x: the screen's upper left.
    case minusX

    /// How a boat house is drawn to face this edge (ruled 2026-11-22). Each
    /// age's side view has its water side toward +x and its back view toward
    /// −y; mirroring on the screen swaps +x with +y and −y with −x.
    public var boatHouseView: (view: SpriteView, mirrored: Bool) {
        switch self {
        case .plusX: (.side, false)
        case .plusY: (.side, true)
        case .minusY: (.back, false)
        case .minusX: (.back, true)
        }
    }
}
