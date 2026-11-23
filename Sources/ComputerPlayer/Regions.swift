// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// The map's land and water, each divided into regions: the tiles a person on
/// foot, or a vessel, can reach from one another without leaving the land or
/// the water. A person moves diagonally only where both tiles beside the step
/// are open, so the tiles of a region join along their sides.
///
/// It is made from the terrain alone, which never changes in a match, so it
/// is made once and kept outside the player's saved state (`RegionCache`):
/// buildings and the sites that block their tiles are left out, since the one
/// can be passed round and the other is used up.
struct Regions: Sendable {
    let width: Int
    let height: Int
    /// The region of each tile, by `y * width + x`: land regions from 1 up,
    /// water regions from -1 down.
    private let label: [Int32]
    /// The tiles in each land region, by label; index 0 is unused.
    private let landSizes: [Int]
    /// The tiles in each water region, by the label's magnitude; index 0 is unused.
    private let waterSizes: [Int]

    init(terrain: [Terrain], width: Int, height: Int) {
        self.width = width
        self.height = height
        var label = [Int32](repeating: 0, count: width * height)
        var landSizes = [0], waterSizes = [0]
        var stack: [Int] = []
        for start in 0..<(width * height) where label[start] == 0 && start < terrain.count {
            let water = terrain[start].isWater
            let mark: Int32 = water ? -Int32(waterSizes.count) : Int32(landSizes.count)
            var size = 0
            label[start] = mark
            stack.append(start)
            while let here = stack.popLast() {
                size += 1
                let x = here % width, y = here / width
                for (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)] {
                    guard nx >= 0, ny >= 0, nx < width, ny < height else { continue }
                    let next = ny * width + nx
                    guard label[next] == 0, terrain[next].isWater == water else { continue }
                    label[next] = mark
                    stack.append(next)
                }
            }
            if water { waterSizes.append(size) } else { landSizes.append(size) }
        }
        self.label = label
        self.landSizes = landSizes
        self.waterSizes = waterSizes
    }

    func isInside(_ tile: GridPoint) -> Bool { tile.x >= 0 && tile.y >= 0 && tile.x < width && tile.y < height }

    /// The region of a tile; 0 outside the map.
    func region(_ tile: GridPoint) -> Int32 { isInside(tile) ? label[tile.y * width + tile.x] : 0 }

    func region(_ point: MapPosition) -> Int32 { region(point.tile) }

    /// The tiles in a region.
    func size(of region: Int32) -> Int {
        if region > 0 { return Int(region) < landSizes.count ? landSizes[Int(region)] : 0 }
        if region < 0 { return Int(-region) < waterSizes.count ? waterSizes[Int(-region)] : 0 }
        return 0
    }

    /// Whether a tile lies beside a tile of `other`, along a side.
    func borders(_ tile: GridPoint, _ other: Int32) -> Bool {
        for next in [GridPoint(tile.x + 1, tile.y), GridPoint(tile.x - 1, tile.y), GridPoint(tile.x, tile.y + 1),
                     GridPoint(tile.x, tile.y - 1)] where region(next) == other { return true }
        return false
    }

    /// The tile of region `wanted` nearest `point`, within `reach` tiles, that
    /// lies beside region `beside` (any tile of `wanted`, if `beside` is nil)
    /// and meets `test`; nil if there is none. Of two as near, the first in row order.
    func nearest(_ wanted: Int32, beside: Int32? = nil, to point: MapPosition, within reach: Int,
                 where test: (GridPoint) -> Bool = { _ in true }) -> GridPoint? {
        let centre = point.tile
        var best: GridPoint?
        var bestDistance = Double.infinity
        let low = GridPoint(max(0, centre.x - reach), max(0, centre.y - reach))
        let high = GridPoint(min(width - 1, centre.x + reach), min(height - 1, centre.y + reach))
        guard low.x <= high.x, low.y <= high.y else { return nil }
        var y = low.y
        while y <= high.y {
            var x = low.x
            while x <= high.x {
                if label[y * width + x] == wanted {
                    let tile = GridPoint(x, y)
                    let d = tile.centre.distance(to: point)
                    if d < bestDistance && (beside.map { borders(tile, $0) } ?? true) && test(tile) {
                        best = tile
                        bestDistance = d
                    }
                }
                x += 1
            }
            y += 1
        }
        return best
    }
}

/// The regions of the map a player is playing on, made when first needed. It
/// is a cache of what the terrain gives, so it is not saved: a player read
/// from a save makes it again from the first view it is given, and decides
/// exactly as it would have.
struct RegionCache: Codable, Sendable {
    var regions: Regions?

    init() {}

    init(from decoder: any Decoder) throws { regions = nil }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }

    /// The regions of the view's map, made from its terrain if not yet made.
    mutating func regions(for view: PlayerView) -> Regions {
        if let regions, regions.width == view.mapWidth, regions.height == view.mapHeight { return regions }
        let made = Regions(terrain: view.terrain, width: view.mapWidth, height: view.mapHeight)
        regions = made
        return made
    }
}
