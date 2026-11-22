// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// Collects the orders a session issues.
@MainActor
final class Recorder {
    var orders: [Order] = []
}

@MainActor
func makeSession(_ view: PlayerView, select ids: [EntityID] = [], recorder: Recorder = Recorder()) -> (PlayerSession, Recorder) {
    let session = PlayerSession(view: view, catalogue: .standard, camera: Camera(centre: MapPosition(x: 16, y: 16)),
                                sink: { recorder.orders.append($0) })
    session.selection = ids
    return (session, recorder)
}

extension PlayerView {
    /// The first entity of the given kind that belongs to the player (or, with `owner`, to that player).
    func id(of kind: EntityKind, owner: PlayerID? = nil) -> EntityID {
        entities.first { $0.kind == kind && $0.owner == (owner ?? player) }!.id
    }

    func ids(ofUnits kinds: [UnitKind]) -> [EntityID] {
        entities.filter { e in e.owner == player && kinds.contains { k in e.kind == .unit(k) } }.map(\.id)
    }
}
