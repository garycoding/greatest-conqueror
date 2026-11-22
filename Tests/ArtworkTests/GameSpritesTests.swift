// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

@testable import Artwork
import GameCore
import CoreGraphics
import Foundation
import Testing

/// The combined source draws every key the Industrial age needs, and each key of
/// the Iron, Alchemy and Industrial ages from the batch approved for it rather than from an
/// earlier batch or a placeholder.
@Test func everyKeyThroughTheIndustrialAgeComesFromItsApprovedBatch() {
    let all = GameSprites()
    let approved: [Age: [any SpriteSource]] = [
        .iron: [IronOldBuildingSprites(), IronNewBuildingSprites(), IronBoatSprites(), IronPeopleSprites(), IronWarriorSprites(), BridgeSprites()],
        .alchemy: [AlchemyOldBuildingSprites(), AlchemyNewBuildingSprites(), AlchemyPeopleSprites(), AlchemyWarriorSprites(), BridgeSprites(),
                   AlchemyBoatSprites()],
        .industrial: [IndustrialOldBuildingSprites(), IndustrialNewBuildingSprites(), IndustrialPeopleSprites(),
                      IndustrialWarriorSprites(), BridgeSprites(), IndustrialBoatSprites()],
    ]
    var missing: [SpriteKey] = []
    var wrong: [SpriteKey] = []
    // A warfighter at work is drawn standing (`SpriteCache`), so its working pose need not be drawn.
    let keys = SpriteKey.required(through: .industrial).filter { key in
        if case .unit(let kind, _) = key.subject, kind.isWarfighter, key.pose == .working { return false }
        return true
    }
    for key in keys {
        guard let image = all.sprite(key) else { missing.append(key); continue }
        let age: Age? = {
            switch key.subject {
            case .unit(_, let age), .building(_, let age): return age
            case .site(let kind): return kind == .iron ? .iron : kind == .oilField ? .industrial : nil
            default: return nil
            }
        }()
        guard let age, let batches = approved[age] else { continue }
        if let own = batches.lazy.compactMap({ $0.sprite(key) }).first, !sameImage(own, image) { wrong.append(key) }
    }
    #expect(missing.isEmpty, "\(missing.prefix(5))")
    #expect(wrong.isEmpty, "\(wrong.prefix(5))")
}

private func sameImage(_ a: SpriteImage, _ b: SpriteImage) -> Bool {
    a.base.width == b.base.width && a.base.height == b.base.height && a.anchor == b.anchor
        && (a.base.dataProvider?.data as Data?) == (b.base.dataProvider?.data as Data?)
}
