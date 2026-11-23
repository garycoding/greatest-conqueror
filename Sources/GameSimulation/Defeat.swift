// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

// Units, defeat, founders and the outcome (ruled 2026-11-22), settled at the
// end of every tick in which something died or a founder's town centre was
// finished.
//
// A unit is anything that moves but the car and the founder: a worker,
// doctor, soldier, knight, cannon, fishing boat or navy ship, troops aboard a
// ship included. A player is defeated whilst it has no unit and no complete
// building that can make one (a building with a row in `production.csv`);
// a player who regains either, through a founder, is no longer defeated. A
// team is defeated when every member is: then whatever its players still own
// is removed, and they give no more orders. A defeated player of a team that
// stands keeps what it owns and may still give orders. The match is won when
// one team alone is left standing.
//
// A person (never a computer player) who has no worker and no complete town
// centre, whilst a teammate is undefeated, receives a founder, if it has none,
// beside the first such teammate's town centre (by player order, then by id),
// or failing one beside another of that teammate's buildings or units, as in
// Cities of Progress. The founder builds one town centre, free; when it is
// finished, `Catalogue.founderPeople` workers appear beside it and the
// founder becomes a worker.

extension Simulation {
    /// Marks a person's seat as played by a computer player, or as the
    /// person's again; a seat taken back is looked at for a founder at once.
    public mutating func setPlayedByComputer(_ player: PlayerID, _ computer: Bool) {
        guard let p = players.firstIndex(where: { $0.id == player }), players[p].isHuman else { return }
        players[p].playedByComputer = computer
        if !computer { settlePending = true }
    }

    mutating func settleTeams() {
        settlePending = false
        let held = holdings()
        for p in players.indices {
            let defeated = !held.unitOrMaker[p]
            if defeated && !players[p].isDefeated {
                for other in teams[players[p].teamIndex].members where other != p {
                    record(.allyDefeated(players[p].id), for: other)
                }
            }
            players[p].isDefeated = defeated
        }
        for t in teams.indices where !teams[t].isDefeated {
            guard teams[t].members.allSatisfy({ players[$0].isDefeated }) else { continue }
            teams[t].isDefeated = true
            for i in entities.indices where entities[i].alive && teamOf(entities[i].owner) == t { kill(i) }
        }
        if deathsPending { removeDead() }
        for p in players.indices where players[p].isHuman && !players[p].playedByComputer && !teams[players[p].teamIndex].isDefeated
            && !held.workerOrCentre[p] && !held.founder[p] {
            guard let spot = founderSpot(for: p) else { continue }
            spawnPerson(.founder, owner: players[p].id, at: spot.centre)
        }
        let standing = teams.filter { !$0.isDefeated }
        if standing.count == 1 { outcome = .won(standing[0].id) }
    }

    /// What each player holds that the rules of defeat and of founders ask about.
    func holdings() -> (unitOrMaker: [Bool], workerOrCentre: [Bool], founder: [Bool]) {
        var unitOrMaker = Array(repeating: false, count: players.count)
        var workerOrCentre = unitOrMaker, founder = unitOrMaker
        for e in entities where e.alive {
            let p = e.owner.rawValue
            if let kind = e.unitKind {
                if kind.isUnit { unitOrMaker[p] = true }
                if kind == .worker { workerOrCentre[p] = true }
                if kind == .founder { founder[p] = true }
            } else if let kind = e.buildingKind, e.complete {
                if !tables.building(kind).trains.isEmpty { unitOrMaker[p] = true }
                if kind == .townCentre { workerOrCentre[p] = true }
            }
        }
        return (unitOrMaker, workerOrCentre, founder)
    }

    /// Where a founder appears: beside the town centre of the first undefeated
    /// teammate that has one, by player order and then by id; failing that,
    /// beside such a teammate's first building, or its first unit.
    func founderSpot(for p: Int) -> GridPoint? {
        let allies = teams[players[p].teamIndex].members.filter { $0 != p && !players[$0].isDefeated }
        for kind: BuildingKind? in [.townCentre, nil] {
            for a in allies {
                if let b = entities.firstIndex(where: {
                    $0.alive && $0.owner.rawValue == a && !$0.isPerson && $0.complete && (kind == nil || $0.buildingKind == kind)
                }) {
                    return freeTile(besideBuilding: b, index: entities[b].spawned)
                }
            }
        }
        for a in allies {
            if let person = entities.first(where: { $0.alive && $0.owner.rawValue == a && ($0.unitKind?.isUnit ?? false) && !$0.isAfloat }) {
                return freeTile(beside: person.position.tile, size: GridPoint(1, 1), index: 0)
            }
        }
        return nil
    }

    /// A founder's town centre is finished: the workers appear beside it, and
    /// the founder becomes a worker (ruled 2026-11-22).
    mutating func founded(_ b: Int, by founder: EntityID) {
        let owner = entities[b].owner
        for _ in 0..<catalogue.founderPeople {
            let spot = freeTile(besideBuilding: b, index: entities[b].spawned)
            entities[b].spawned += 1
            let id = spawnPerson(.worker, owner: owner, at: spot.centre)
            record(.trained(id, .worker), for: owner.rawValue)
        }
        if let f = index(of: founder), entities[f].isFounder {
            let worker = tables.unit(.worker)
            stampSight(of: f, by: -1)
            entities[f].kind = .unit(.worker)
            entities[f].health = worker.health
            entities[f].maxHealth = worker.health
            entities[f].sight = worker.sight
            stampSight(of: f, by: 1)
            population[owner.rawValue] += worker.population - tables.unit(.founder).population
            setIdle(f)
        }
        settlePending = true
    }
}
