// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
import Testing

/// Eight facings, five views (ruled 2026-11-21).
@Suite struct Facings {
    @Test func aMovementFacesTheNearestOfEightDirectionsOnTheScreen() {
        // Along the map's axes a person goes diagonally on the screen.
        #expect(Facing.of(dx: 1, dy: 0) == .downRight)
        #expect(Facing.of(dx: 0, dy: 1) == .downLeft)
        #expect(Facing.of(dx: -1, dy: 0) == .upLeft)
        #expect(Facing.of(dx: 0, dy: -1) == .upRight)
        // Along the map's diagonals, straight across or up and down the screen.
        #expect(Facing.of(dx: 1, dy: -1) == .right)
        #expect(Facing.of(dx: -1, dy: 1) == .left)
        #expect(Facing.of(dx: 1, dy: 1) == .down)
        #expect(Facing.of(dx: -1, dy: -1) == .up)
        #expect(Facing.of(dx: 0, dy: 0) == nil)
    }

    @Test func fiveViewsAreDrawnAndThreeMirrored() {
        #expect(Set(Facing.allCases.map(\.view)) == Set(SpriteView.allCases))
        #expect(Facing.allCases.filter(\.mirrored) == [.left, .downLeft, .upLeft])
        for facing in Facing.allCases where facing.mirrored {
            #expect(Facing.allCases.contains { !$0.mirrored && $0.view == facing.view })
        }
        // Saves from before keep their facings.
        #expect(Facing(rawValue: 0) == .right && Facing(rawValue: 1) == .left)
    }

    @Test func aKeySavedBeforeViewsOpensAsTheSideView() throws {
        let key = SpriteKey(.unit(.worker, .stone), .walking, frame: 3)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(key)) as! [String: Any]
        json["view"] = nil
        let reopened = try JSONDecoder().decode(SpriteKey.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(reopened == key && reopened.view == .side)
        #expect(key.seen(.back).view == .back && key.seen(.back) != key)
    }
}
