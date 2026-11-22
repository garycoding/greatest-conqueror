// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

// Defeat and the outcome, settled at the end of every tick in which something died.
//
// A player "lives" whilst it owns anything but cars and boats. A team none of
// whose players lives is defeated: its players are marked defeated and
// whatever they still own (their cars and boats) removed. The match is won when one team alone is left
// standing.

extension Simulation {
    mutating func settleTeams() {
        let owns = ownership()
        for t in teams.indices where !teams[t].isDefeated {
            guard !teams[t].members.contains(where: { owns[$0] }) else { continue }
            teams[t].isDefeated = true
            for m in teams[t].members {
                players[m].isDefeated = true
                for other in teams[t].members where other != m { record(.allyDefeated(players[m].id), for: other) }
            }
            for i in entities.indices where entities[i].alive && teamOf(entities[i].owner) == t { kill(i) }
        }
        if deathsPending { removeDead() }
        let standing = teams.filter { !$0.isDefeated }
        if standing.count == 1 { outcome = .won(standing[0].id) }
    }
}
