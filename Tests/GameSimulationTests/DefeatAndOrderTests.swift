// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
import Testing
@testable import GameSimulation

/// Players 0 and 1 allied against player 2, with town centres at (2, 2), (2, 40) and (40, 20).
func trio(teams: [Int] = [0, 0, 1]) -> Simulation {
    Simulation(setup: setup(openMap(width: 48, height: 48, starts: [GridPoint(2, 2), GridPoint(2, 40), GridPoint(40, 20)]),
                            teams: teams))
}

extension Simulation {
    /// Destroy everything a player owns, as a battle would, and let a tick settle it.
    mutating func destroyAll(_ player: PlayerID) {
        for i in entities.indices where entities[i].alive && entities[i].owner == player { kill(i) }
        step()
    }
}

@Suite struct Defeat {
    @Test func aPersonWhoLosesEverythingWhilstAnAllyLivesIsDefeatedAndReceivesAFounder() {
        var sim = trio()
        sim.destroyAll(me)
        #expect(sim.entities.filter { $0.owner == me }.map(\.unitKind) == [.founder])
        let view = sim.view(for: me)
        #expect(view.players[0].isDefeated)
        #expect(view.population == 0)
        #expect(sim.outcome == nil)
    }

    @Test func aTeamWhosePlayersOwnNothingIsDefeated() {
        var sim = trio()
        sim.destroyAll(me)
        sim.destroyAll(PlayerID(1))
        #expect(sim.outcome == .won(TeamID(1)))
        #expect(sim.players[0].isDefeated && sim.players[1].isDefeated && !sim.players[2].isDefeated)
        #expect(sim.view(for: me).events.contains(.allyDefeated(PlayerID(1))))
        #expect(sim.view(for: PlayerID(1)).events.contains(.allyDefeated(me)))
        #expect(sim.view(for: PlayerID(2)).outcome == .won(TeamID(1)))
    }

    @Test func aPlayerWithoutAnAllyIsDefeatedAtOnce() {
        var sim = duel()
        sim.destroyAll(them)
        #expect(sim.outcome == .won(TeamID(0)))
        #expect(sim.view(for: me).players[1].isDefeated)
    }

    @Test func aTeamWinsWhenEveryOtherTeamIsDefeated() {
        var sim = trio(teams: [0, 1, 2])
        sim.destroyAll(PlayerID(1))
        #expect(sim.outcome == nil && sim.players[1].isDefeated)
        #expect(sim.apply(.advanceAge(at: EntityID(1)), from: PlayerID(1)) == .refused(.notNow))
        sim.destroyAll(PlayerID(2))
        #expect(sim.outcome == .won(TeamID(0)))
    }
}

@Suite struct Pause {
    @Test func aHumanPausesForEveryoneAndEveryOtherOrderIsRefusedMeanwhile() {
        var sim = duel()
        let worker = sim.people(me, .worker)[0]
        #expect(sim.apply(.setPaused(true), from: them) == .refused(.notYours))
        #expect(sim.apply(.setPaused(true), from: me) == .accepted)
        #expect(sim.isPaused && sim.view(for: them).isPaused)
        sim.run(10)
        #expect(sim.tick == 0)
        #expect(sim.apply(.move(units: [worker], to: MapPosition(x: 10, y: 10)), from: me) == .refused(.notNow))
        #expect(sim.apply(.train(at: sim.townCentre(them), unit: .worker), from: them) == .refused(.notNow))
        #expect(sim.apply(.setPaused(true), from: me) == .accepted)
        #expect(sim.apply(.setPaused(false), from: me) == .accepted)
        sim.step()
        #expect(sim.tick == 1)
        #expect(sim.apply(.move(units: [worker], to: MapPosition(x: 10, y: 10)), from: me) == .accepted)
    }

    @Test func afterTheOutcomeEveryOrderButPauseIsRefusedAndTheMatchStands() {
        var sim = duel()
        sim.destroyAll(them)
        let tick = sim.tick
        let worker = sim.people(me, .worker)[0]
        #expect(sim.apply(.move(units: [worker], to: MapPosition(x: 10, y: 10)), from: me) == .refused(.notNow))
        #expect(sim.apply(.advanceAge(at: sim.townCentre(me)), from: me) == .refused(.notNow))
        sim.run(10)
        #expect(sim.tick == tick)
        #expect(sim.apply(.setPaused(true), from: me) == .accepted)
    }
}

@Suite struct Refusals {
    @Test func everyRefusalAppearsInThatPlayersNextView() {
        var sim = duel()
        _ = sim.view(for: me)
        _ = sim.view(for: them)
        #expect(sim.apply(.advanceAge(at: sim.townCentre(them)), from: me) == .refused(.notYours))
        #expect(sim.apply(.train(at: sim.townCentre(them), unit: .worker), from: me) == .refused(.notYours))
        #expect(sim.apply(.stop(units: [EntityID(9_999)]), from: me) == .refused(.notYours))
        #expect(sim.apply(.advanceAge(at: sim.townCentre(me)), from: PlayerID(7)) == .refused(.notYours))
        sim.step()
        #expect(sim.view(for: me).events == [.refused(.notYours), .refused(.notYours), .refused(.notYours)])
        #expect(sim.view(for: them).events.isEmpty)
    }

    @Test func viewsCarryTheEventsSinceThatPlayersLastView() {
        var sim = duel()
        _ = sim.apply(.train(at: sim.townCentre(me), unit: .worker), from: me)
        _ = sim.apply(.advanceAge(at: sim.townCentre(them)), from: me)
        sim.run(Catalogue.standard.production(of: .worker, at: .townCentre)!.time)
        let trained = sim.people(me, .worker).last!
        #expect(sim.view(for: me).events == [.refused(.notYours), .trained(trained, .worker)])
        #expect(sim.view(for: me).events.isEmpty)
        // The opponent's events wait for its own view.
        _ = sim.apply(.advanceAge(at: sim.townCentre(me)), from: them)
        #expect(sim.view(for: me).events.isEmpty)
        #expect(sim.view(for: them).events == [.refused(.notYours)])
    }
}

@Suite struct Dismissal {
    @Test func dismissedPeopleLeaveAtOnceAndFreeTheirPlaces() {
        var sim = duel()
        let workers = sim.people(me, .worker)
        let before = sim.view(for: me).population
        #expect(sim.apply(.dismiss(units: [workers[0]]), from: me) == .accepted)
        sim.step()
        #expect(sim.entity(workers[0]) == nil)
        #expect(sim.view(for: me).population == before - 1)
    }

    @Test func onlyOwnUnitsMayBeDismissed() {
        var sim = duel()
        let theirs = sim.people(them, .worker)[0]
        #expect(sim.apply(.dismiss(units: [theirs]), from: me) == .refused(.notYours))
        #expect(sim.apply(.dismiss(units: [sim.townCentre(me)]), from: me) == .refused(.notYours))
    }
}
