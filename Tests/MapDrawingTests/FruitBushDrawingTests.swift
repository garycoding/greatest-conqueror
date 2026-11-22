// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Artwork
import CoreGraphics
import GameCore
import SpriteKit
import Testing
@testable import MapDrawing

/// The fruit bush, drawn in each look, shows the look of the age of the player
/// who sees it, and changes when that player advances; the other sites keep
/// their one picture.
@MainActor
@Suite struct FruitBushDrawingTests {
    /// A source whose bush tells its look by its width in points (10 for the
    /// Stone look, 11 for the Bronze, and so on) and whose tree is 40 wide.
    struct LookSource: SpriteSource {
        func sprite(_ key: SpriteKey) -> SpriteImage? {
            let width: Double
            switch key.subject {
            case .site(.fruit):
                guard let look = Look.allCases.first(where: { key.pose == .complete(in: $0) }) else { return nil }
                width = 10 + Double(look.rawValue)
            case .site(.tree):
                guard key.pose == .complete else { return nil }
                width = 40
            default: return nil
            }
            let size = CGSize(width: width, height: 20)
            let image = Placeholders.render(size) { c in
                c.setFillColor(Placeholders.colour(0.5, 0.5, 0.5))
                c.fill(CGRect(origin: .zero, size: size))
            }
            return SpriteImage(base: image, teamMask: nil, anchor: SpriteAnchor(x: 0.5, y: 0.2))
        }
    }

    func view(age: Age) -> PlayerView {
        var view = Samples.townsAgeOpening()
        view.age = age
        view.sites = [ResourceSite(id: SiteID(2_000), kind: .fruit, tile: GridPoint(5, 5), remaining: 100),
                      ResourceSite(id: SiteID(2_001), kind: .tree, tile: GridPoint(7, 5), remaining: 100)]
        return view
    }

    @Test func theBushShowsTheLookOfTheViewersAge() throws {
        for age in Age.allCases {
            let (session, _) = makeSession(view(age: age))
            let scene = MapScene(session: session, sprites: LookSource(), size: screenSize)
            let bush = try #require(scene.siteNodes[SiteID(2_000)])
            #expect(bush.size.width == 10 + CGFloat(age.look.rawValue), "\(age)")
            #expect(try #require(scene.siteNodes[SiteID(2_001)]).size.width == 40, "the tree in \(age)")
        }
    }

    @Test func theBushChangesWhenTheViewerAdvances() throws {
        let (session, _) = makeSession(view(age: .towns))
        let scene = MapScene(session: session, sprites: LookSource(), size: screenSize)
        #expect(try #require(scene.siteNodes[SiteID(2_000)]).size.width == 10)
        session.update(view(age: .ships))
        scene.refresh()
        #expect(try #require(scene.siteNodes[SiteID(2_000)]).size.width == 10 + CGFloat(Look.iron.rawValue))
    }
}
