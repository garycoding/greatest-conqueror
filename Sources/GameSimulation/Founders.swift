// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

// Defeat, founders and the outcome (requirements 7, 26 and 27), settled at the
// end of every tick in which something died.
//
// A player "lives" whilst it owns anything but a founder. A team none of whose
// players lives is defeated: its players are marked defeated and their founders
// removed. Then every player of a team still standing who owns nothing at all
// receives a founder beside an ally's town centre, which a living ally always
// has or, failing one, beside another of that ally's buildings or people. The
// match is won when one team alone is left standing.

extension Simulation {
    mutating func settleTeams() {
        let owned = ownership()
        for t in teams.indices where !teams[t].isDefeated {
            guard !teams[t].members.contains(where: { owned.others[$0] }) else { continue }
            teams[t].isDefeated = true
            for m in teams[t].members {
                players[m].isDefeated = true
                for other in teams[t].members where other != m { record(.allyDefeated(players[m].id), for: other) }
            }
            for i in entities.indices where entities[i].alive && teamOf(entities[i].owner) == t { kill(i) }
        }
        if deathsPending { removeDead() }
        for p in players.indices where !players[p].isDefeated && !owned.others[p] && !owned.founders[p] {
            guard let spot = founderSpot(for: p) else { continue }
            spawnPerson(.founder, owner: players[p].id, at: spot.centre)
        }
        let standing = teams.filter { !$0.isDefeated }
        if standing.count == 1 { outcome = .won(standing[0].id) }
    }

    /// A tile beside the town centre of the first living ally that has one, by
    /// player order and then by id; failing that, beside an ally's first building
    /// or person.
    func founderSpot(for p: Int) -> GridPoint? {
        let allies = teams[players[p].teamIndex].members.filter { $0 != p }
        for kind: BuildingKind? in [.townCentre, nil] {
            for a in allies {
                if let b = entities.firstIndex(where: {
                    $0.alive && $0.owner.rawValue == a && !$0.isPerson && (kind == nil || $0.buildingKind == kind)
                }) {
                    return freeTile(besideBuilding: b, index: 0)
                }
            }
        }
        for a in allies {
            if let person = entities.first(where: { $0.alive && $0.owner.rawValue == a && $0.isPerson && !$0.isFounder }) {
                return freeTile(beside: person.position.tile, size: GridPoint(1, 1), index: 0)
            }
        }
        return nil
    }
}
