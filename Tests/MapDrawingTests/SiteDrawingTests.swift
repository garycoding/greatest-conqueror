// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Artwork
import CoreGraphics
import GameCore
import SpriteKit
import Testing
@testable import MapDrawing

/// A site on a water tile shows its `afloat` picture, falling back to
/// `complete`, and a site that moves shows the frame of its cycle for its
/// tile, so that neighbouring tiles of a shoal do not move in unison.
@MainActor
@Suite struct SiteDrawingTests {
    /// A source whose every site picture tells its key by its size in points:
    /// 10 wide and one more for each frame, and 20 high, or 30 afloat.
    /// The fish moves (12 frames of `complete`); stone has an `afloat` picture
    /// at frame 0; copper has none.
    struct SiteSource: SpriteSource {
        func sprite(_ key: SpriteKey) -> SpriteImage? {
            guard case .site(let kind) = key.subject, (0..<SpriteKey.framesPerPose).contains(key.frame) else { return nil }
            switch (kind, key.pose) {
            case (.fish, .complete): break
            case (.stone, .complete), (.stone, .afloat), (.copper, .complete): guard key.frame == 0 else { return nil }
            default: return nil
            }
            let size = CGSize(width: 10 + Double(key.frame), height: key.pose == .afloat ? 30 : 20)
            let image = Placeholders.render(size) { c in
                c.setFillColor(Placeholders.colour(0.5, 0.5, 0.5))
                c.fill(CGRect(origin: .zero, size: size))
            }
            return SpriteImage(base: image, teamMask: nil, anchor: SpriteAnchor(x: 0.5, y: 0.2))
        }
    }

    /// The opening's view with sites laid on chosen tiles, water where `water` says.
    func view(_ sites: [(SiteKind, GridPoint)], water: Set<GridPoint>) -> PlayerView {
        var view = Samples.stoneAgeOpening()
        for tile in water { view.terrain[tile.y * view.mapWidth + tile.x] = .shallowWater }
        view.sites = sites.enumerated().map { i, site in
            ResourceSite(id: SiteID(1_000 + i), kind: site.0, tile: site.1, remaining: 100)
        }
        return view
    }

    func scene(_ view: PlayerView) -> MapScene {
        let (session, _) = makeSession(view)
        return MapScene(session: session, sprites: SiteSource(), size: screenSize)
    }

    func node(_ scene: MapScene, _ index: Int) throws -> SiteNode {
        try #require(scene.siteNodes[SiteID(1_000 + index)])
    }

    @Test func aRockOnWaterShowsItsAfloatPictureAndOnLandItsOwn() throws {
        let scene = scene(view([(.stone, GridPoint(4, 4)), (.stone, GridPoint(6, 4)), (.copper, GridPoint(8, 4))],
                               water: [GridPoint(4, 4), GridPoint(8, 4)]))
        #expect(try node(scene, 0).size == CGSize(width: 10, height: 30), "stone on water")
        #expect(try node(scene, 1).size == CGSize(width: 10, height: 20), "stone on land")
        // Copper has no afloat picture: on water it falls back to its own.
        #expect(try node(scene, 2).size == CGSize(width: 10, height: 20), "copper on water")
    }

    @Test func neighbouringFishShowDifferentFramesAndEachMoves() throws {
        let corner = GridPoint(10, 6)
        let shoal = [corner, GridPoint(11, 6), GridPoint(10, 7), GridPoint(11, 7)]
        let scene = scene(view(shoal.map { (.fish, $0) }, water: Set(shoal)))
        var seen: [[CGFloat]] = []
        for frame in 0..<SpriteKey.framesPerPose {
            scene.step(at: (Double(frame) + 0.5) / SpriteKey.frameRate)
            let widths = try (0..<4).map { try node(scene, $0).size.width }
            #expect(Set(widths).count == 4, "frame \(frame): \(widths)")
            for (i, tile) in shoal.enumerated() {
                let expected = (frame + SiteNode.frameOffset(tile)) % SpriteKey.framesPerPose
                #expect(widths[i] == 10 + CGFloat(expected), "tile \(tile) at frame \(frame)")
            }
            seen.append(widths)
        }
        // Each tile runs through all 12 frames of its cycle.
        for i in 0..<4 { #expect(Set(seen.map { $0[i] }).count == SpriteKey.framesPerPose) }
    }

    @Test func everySquareOfTwoByTwoTakesFourOffsets() {
        for x in -3..<30 {
            for y in -3..<30 {
                let offsets = [GridPoint(x, y), GridPoint(x + 1, y), GridPoint(x, y + 1), GridPoint(x + 1, y + 1)].map(SiteNode.frameOffset)
                #expect(Set(offsets).count == 4, "\(x), \(y)")
                #expect(offsets.allSatisfy { (0..<SpriteKey.framesPerPose).contains($0) })
            }
        }
    }
}
