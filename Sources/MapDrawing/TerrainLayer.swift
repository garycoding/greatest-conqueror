// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
import SpriteKit

/// The ground: one isometric tile map, laid out as `Projection` has it. Tiles
/// never seen are black; tiles seen but not in sight are darkened. Only the tiles
/// whose visibility changed are set again when a new view arrives.
@MainActor
final class TerrainLayer {
    static let tileSize = CGSize(width: Projection.tileWidth, height: Projection.tileHeight)

    let node: SKTileMapNode
    let width: Int
    let height: Int
    private let cache: SpriteCache
    /// Indexed by terrain, then variant, then 0 (in sight) or 1 (darkened).
    private var groups: [[[SKTileGroup]]] = []
    private let black: SKTileGroup
    private var lastVisibility: [TileVisibility] = []

    init(width: Int, height: Int, cache: SpriteCache) {
        self.width = width
        self.height = height
        self.cache = cache

        var all: [SKTileGroup] = []
        for terrain in Terrain.allCases {
            var byVariant: [[SKTileGroup]] = []
            for variant in 0..<cache.variantCount(terrain) {
                var byLight: [SKTileGroup] = []
                for dimmed in [false, true] {
                    let (texture, size) = cache.terrainTexture(terrain, variant: variant, dimmed: dimmed)
                    let group = SKTileGroup(tileDefinition: SKTileDefinition(texture: texture, size: size))
                    byLight.append(group)
                    all.append(group)
                }
                byVariant.append(byLight)
            }
            groups.append(byVariant)
        }
        let blackTexture = SKTexture(cgImage: Placeholders.render(Placeholders.terrainSize) { c in
            let w = Placeholders.terrainSize.width, h = Placeholders.terrainSize.height
            Placeholders.polygon(c, [CGPoint(x: w / 2, y: h), CGPoint(x: w, y: h / 2), CGPoint(x: w / 2, y: 0), CGPoint(x: 0, y: h / 2)],
                                 fill: Placeholders.colour(0, 0, 0), stroke: nil)
        })
        black = SKTileGroup(tileDefinition: SKTileDefinition(texture: blackTexture, size: Placeholders.terrainSize))
        all.append(black)

        let set = SKTileSet(tileGroups: all, tileSetType: .isometric)
        // Isometric tile maps run column to the lower right and row to the upper
        // right, from the bottom: map x is the column, and map y counts rows from the top.
        node = SKTileMapNode(tileSet: set, columns: width, rows: height, tileSize: Self.tileSize)
        node.zPosition = -10_000
        let first = Projection.screen(GridPoint(0, 0).centre)
        let anchor = node.centerOfTile(atColumn: 0, row: height - 1)
        node.position = CGPoint(x: first.x - anchor.x, y: first.y - anchor.y)
    }

    private func group(for index: Int, terrain: Terrain, visibility: TileVisibility) -> SKTileGroup {
        guard visibility != .unexplored else { return black }
        let variants = groups[terrain.rawValue]
        let x = index % width, y = index / width
        // Mix the high bits down: the low bits of a product of x and y repeat on a
        // small grid, which showed as a 4 by 4 pattern of tiles.
        var h = UInt64(truncatingIfNeeded: x &* 73_856_093) ^ UInt64(truncatingIfNeeded: y &* 19_349_663)
        h = (h ^ (h >> 16)) &* 0x45d9_f3b
        h = (h ^ (h >> 16)) &* 0x45d9_f3b
        h ^= h >> 16
        let variant = Int(h % UInt64(variants.count))
        return variants[variant][visibility == .explored ? 1 : 0]
    }

    func update(with view: PlayerView) {
        guard view.mapWidth == width, view.mapHeight == height else { return }
        let first = lastVisibility.count != view.visibility.count
        if !first, view.visibility == lastVisibility { return }
        for index in 0..<view.visibility.count where first || view.visibility[index] != lastVisibility[index] {
            let x = index % width, y = index / width
            node.setTileGroup(group(for: index, terrain: view.terrain[index], visibility: view.visibility[index]),
                              forColumn: x, row: height - 1 - y)
        }
        lastVisibility = view.visibility
    }
}
