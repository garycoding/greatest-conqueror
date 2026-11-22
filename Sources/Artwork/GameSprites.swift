// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
import Synchronization

/// All the game's artwork as one source: each approved batch answers the keys
/// it draws, and the first answer wins. The drawing shows its placeholder for a
/// key that no batch answers.
public final class GameSprites: SpriteSource {
    private let batches: [any SpriteSource]
    /// What each key gave, so that a batch that draws on every call (and the
    /// panel's icons, asked for on every redraw) pays once.
    private let cache = Mutex<[SpriteKey: SpriteImage?]>([:])

    public init(catalogue: Catalogue = .standard) {
        batches = [
            CartoonSprites(catalogue: catalogue),
            TerrainSprites(),
            StoneBuildingSprites(),
            StoneBoatSprites(catalogue: catalogue),
            BronzeBuildingSprites(),
            BronzePeopleSprites(catalogue: catalogue),
            BronzeBoatSprites(catalogue: catalogue),
            IronOldBuildingSprites(),
            IronNewBuildingSprites(),
            IronBoatSprites(catalogue: catalogue),
            IronPeopleSprites(catalogue: catalogue),
            IronWarriorSprites(catalogue: catalogue),
            AlchemyOldBuildingSprites(),
            AlchemyNewBuildingSprites(),
            AlchemyPeopleSprites(catalogue: catalogue),
            AlchemyWarriorSprites(catalogue: catalogue),
            AlchemyBoatSprites(catalogue: catalogue),
            IndustrialOldBuildingSprites(),
            IndustrialNewBuildingSprites(),
            IndustrialPeopleSprites(catalogue: catalogue),
            IndustrialWarriorSprites(catalogue: catalogue),
            IndustrialBoatSprites(catalogue: catalogue),
            CarSprites(),
            BridgeSprites(),
        ]
    }

    public func sprite(_ key: SpriteKey) -> SpriteImage? {
        if let known = cache.withLock({ $0[key] }) { return known }
        let found = batches.lazy.filter { batch in
            key.view == .side || (batch as? any ViewedSpriteSource)?.drawsViews(of: key.subject) == true
        }.compactMap { $0.sprite(key) }.first
        cache.withLock { $0[key] = found }
        return found
    }
}
