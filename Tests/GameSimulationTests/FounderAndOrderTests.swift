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

@Suite struct Founders {
    @Test func aPlayerWhoLosesEverythingWhilstAnAllyLivesReceivesAFounderBesideTheAllysTownCentre() {
        var sim = trio()
        sim.destroyAll(me)
        let founders = sim.people(me, .founder)
        #expect(founders.count == 1)
        let allyCentre = Goal.tiles(GridPoint(2, 40), GridPoint(3, 3), reach: 0)
        #expect(allyCentre.distance(to: sim.living(founders[0]).position) <= 1.5)
        let view = sim.view(for: me)
        #expect(view.players[0].isFounding && !view.players[0].isDefeated)
        #expect(view.population == 0)
        #expect(sim.outcome == nil)
        sim.run(20)
        #expect(sim.people(me, .founder) == founders)
    }

    @Test func aFounderCannotAttackAndCannotBeHarmed() {
        var sim = trio()
        sim.destroyAll(me)
        let founder = sim.people(me, .founder)[0]
        let f = sim.index(of: founder)!
        sim.entities[f].position = MapPosition(x: 38.5, y: 21.5)     // beside player 2's town centre
        sim.restamp(f)
        let opponent = sim.add(.worker, PlayerID(2), 37.5, 21.5)
        #expect(sim.apply(.attack(units: [founder], target: opponent), from: me) == .refused(.cannotAttack))
        #expect(sim.apply(.attack(units: [opponent], target: founder), from: PlayerID(2)) == .refused(.cannotAttack))
        #expect(sim.apply(.gather(units: [founder], site: SiteID(0)), from: me) == .refused(.notYours))
        sim.run(200)
        #expect(sim.health(founder) == Catalogue.standard.stats(.founder).health)
    }

    @Test func foundingBuildsAFreeTownCentreWithTwoWorkersAndTheFounderBecomesAnEngineer() {
        var sim = trio()
        sim.destroyAll(me)
        let founder = sim.people(me, .founder)[0]
        let held = sim.resources(me)
        #expect(sim.apply(.found(founder: founder, at: GridPoint(2, 40)), from: me) == .refused(.placementBlocked))
        #expect(sim.apply(.found(founder: founder, at: GridPoint(30, 4)), from: me) == .refused(.placementBlocked))
        let allyWorker = sim.people(PlayerID(1), .worker)[0]
        #expect(sim.apply(.found(founder: allyWorker, at: GridPoint(8, 36)), from: PlayerID(1)) == .refused(.notYours))
        #expect(sim.apply(.found(founder: founder, at: GridPoint(8, 36)), from: me) == .accepted)
        #expect(sim.resources(me) == held)
        #expect(sim.living(founder).unitKind == .engineer)
        #expect(sim.living(founder).task == .idle)
        let centre = sim.buildings(me, .townCentre)
        #expect(centre.count == 1)
        #expect(sim.living(centre[0]).origin == GridPoint(8, 36) && sim.living(centre[0]).complete)
        #expect(sim.people(me, .worker).count == 2 && Catalogue.standard.founderPeople == 2)
        #expect(sim.people(me, .engineer) == [founder])
        // Only one town centre: there is no founder left to found another.
        #expect(sim.apply(.found(founder: founder, at: GridPoint(14, 36)), from: me) == .refused(.notYours))
        let view = sim.view(for: me)
        #expect(view.events.contains(.constructed(centre[0], .townCentre)))
        #expect(!view.players[0].isFounding)
        #expect(view.populationLimit == Catalogue.standard.stats(.townCentre).housing)
        sim.step()
        #expect(sim.people(me, .founder).isEmpty)
    }

    @Test func theFounderReappearsWheneverThePlayerAgainOwnsNothing() {
        var sim = trio()
        sim.destroyAll(me)
        _ = sim.apply(.found(founder: sim.people(me, .founder)[0], at: GridPoint(8, 36)), from: me)
        sim.destroyAll(me)
        #expect(sim.people(me, .founder).count == 1)
        #expect(sim.outcome == nil)
    }

    @Test func aTeamWhosePlayersOwnOnlyFoundersIsDefeated() {
        var sim = trio()
        sim.destroyAll(me)
        sim.destroyAll(PlayerID(1))
        #expect(sim.outcome == .won(TeamID(1)))
        #expect(sim.players[0].isDefeated && sim.players[1].isDefeated && !sim.players[2].isDefeated)
        #expect(sim.people(me, .founder).isEmpty && sim.people(PlayerID(1), .founder).isEmpty)
        #expect(sim.view(for: me).events.contains(.allyDefeated(PlayerID(1))))
        #expect(sim.view(for: PlayerID(1)).events.contains(.allyDefeated(me)))
        #expect(sim.view(for: PlayerID(2)).outcome == .won(TeamID(1)))
    }

    @Test func aPlayerWithoutAnAllyIsDefeatedAtOnce() {
        var sim = duel()
        sim.destroyAll(them)
        #expect(sim.outcome == .won(TeamID(0)))
        #expect(sim.people(them, .founder).isEmpty)
        #expect(sim.view(for: me).players[1].isDefeated)
    }

    @Test func aTeamWinsWhenEveryOtherTeamIsDefeated() {
        var sim = trio(teams: [0, 1, 2])
        sim.destroyAll(PlayerID(1))
        #expect(sim.outcome == nil && sim.players[1].isDefeated)
        #expect(sim.apply(.advanceAge, from: PlayerID(1)) == .refused(.notNow))
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
        #expect(sim.apply(.advanceAge, from: me) == .refused(.notNow))
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
        #expect(sim.apply(.advanceAge, from: me) == .refused(.studyIncomplete))
        #expect(sim.apply(.train(at: sim.townCentre(them), unit: .worker), from: me) == .refused(.notYours))
        #expect(sim.apply(.stop(units: [EntityID(9_999)]), from: me) == .refused(.notYours))
        #expect(sim.apply(.advanceAge, from: PlayerID(7)) == .refused(.notYours))
        sim.step()
        #expect(sim.view(for: me).events == [.refused(.studyIncomplete), .refused(.notYours), .refused(.notYours)])
        #expect(sim.view(for: them).events.isEmpty)
    }

    @Test func viewsCarryTheEventsSinceThatPlayersLastView() {
        var sim = duel()
        _ = sim.apply(.train(at: sim.townCentre(me), unit: .worker), from: me)
        _ = sim.apply(.advanceAge, from: me)
        sim.run(Catalogue.standard.stats(.worker).trainTime)
        let trained = sim.people(me, .worker).last!
        #expect(sim.view(for: me).events == [.refused(.studyIncomplete), .trained(trained, .worker)])
        #expect(sim.view(for: me).events.isEmpty)
        // The opponent's events wait for its own view.
        _ = sim.apply(.advanceAge, from: them)
        #expect(sim.view(for: me).events.isEmpty)
        #expect(sim.view(for: them).events == [.refused(.studyIncomplete)])
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

    @Test func onlyOwnPeopleAndNoFounderMayBeDismissed() {
        var sim = duel()
        let theirs = sim.people(them, .worker)[0]
        #expect(sim.apply(.dismiss(units: [theirs]), from: me) == .refused(.notYours))
        #expect(sim.apply(.dismiss(units: [sim.townCentre(me)]), from: me) == .refused(.notYours))
        let founder = sim.add(.founder, me, 6.5, 6.5)
        #expect(sim.apply(.dismiss(units: [founder]), from: me) == .refused(.invalidTarget))
        #expect(sim.entity(founder) != nil)
    }
}
