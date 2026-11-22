// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Artwork
import CoreGraphics
import GameCore
@testable import MapDrawing

/// Collects the orders a session issues.
@MainActor
final class OrderLog {
    var orders: [Order] = []
}

@MainActor
func makeSession(_ view: PlayerView, camera: Camera = Camera(centre: MapPosition(x: 10, y: 10), zoom: 1),
                 log: OrderLog = OrderLog()) -> (PlayerSession, OrderLog) {
    (PlayerSession(view: view, catalogue: .standard, camera: camera, sink: { [log] in log.orders.append($0) }), log)
}

let screenSize = CGSize(width: 1440, height: 900)

func geometry(_ x: Double, _ y: Double, zoom: Double = 1) -> MapGeometry {
    MapGeometry(camera: Camera(centre: MapPosition(x: x, y: y), zoom: zoom), viewSize: screenSize)
}

/// A view with `count` extra people of the player's, spread over the explored ground.
func crowd(_ count: Int, shift: Double = 0) -> PlayerView {
    var view = Samples.townsAgeOpening()
    let kinds: [UnitKind] = [.worker, .spearman, .boat, .worker, .horseman]
    var next = (view.entities.map(\.id.rawValue).max() ?? 0) + 1
    for i in 0..<count {
        let x = 2.0 + Double((i * 7) % 28) + shift.truncatingRemainder(dividingBy: 1)
        let y = 2.0 + Double((i * 11) % 28) + shift.truncatingRemainder(dividingBy: 1)
        let position = MapPosition(x: x, y: y)
        view.entities.append(EntityView(id: EntityID(next), owner: PlayerID(0), kind: .unit(kinds[i % kinds.count]),
                                        position: position, tile: position.tile, facing: i % 2 == 0 ? .right : .left,
                                        health: 25, maxHealth: 25, activity: i % 3 == 0 ? .idle : .moving))
        next += 1
    }
    return view
}

/// A source that supplies a plain coloured picture for every person, with a team mask.
struct SolidSource: SpriteSource {
    func sprite(_ key: SpriteKey) -> SpriteImage? {
        guard case .unit = key.subject, key.frame == 0 else { return nil }
        let image = Placeholders.render(CGSize(width: 40, height: 80)) { c in
            c.setFillColor(Placeholders.colour(0.2, 0.3, 0.9))
            c.fill(CGRect(x: 0, y: 0, width: 40, height: 80))
        }
        let mask = Placeholders.render(CGSize(width: 40, height: 80)) { c in
            c.setFillColor(Placeholders.colour(1, 1, 1))
            c.fill(CGRect(x: 0, y: 20, width: 40, height: 20))
        }
        return SpriteImage(base: image, teamMask: mask, anchor: SpriteAnchor(x: 0.5, y: 0.1))
    }
}

extension MapScene {
    func mouseDownForTest(at point: CGPoint) { beginDrag(at: point) }
    func mouseDraggedForTest(to point: CGPoint) { continueDrag(to: point) }
    func mouseUpForTest(at point: CGPoint, additive: Bool) { endDrag(at: point, additive: additive) }
}
