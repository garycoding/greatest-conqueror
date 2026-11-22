// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
import Testing
@testable import GameSimulation

// Fights happen in the middle of the duel map, out of reach of both town centres.

@Suite struct Combat {
    static let catalogue = Catalogue.standard

    /// The harm a blow from one kind does to another.
    static func harm(_ attacker: EntityKind, _ defender: EntityKind, attackerHas: [Improvement] = [],
                     defenderHas: [Improvement] = []) -> Int {
        var sim = duel()
        sim.players[0].improvements = attackerHas
        sim.players[1].improvements = defenderHas
        func put(_ kind: EntityKind, _ owner: PlayerID, _ x: Int) -> Int {
            let id: EntityID
            switch kind {
            case .unit(let k): id = sim.add(k, owner, Double(x) + 0.5, 18.5)
            case .building(let k): id = sim.add(k, owner, x, 18)
            }
            return sim.index(of: id)!
        }
        let a = put(attacker, me, 16), d = put(defender, them, 18)
        let attack: Attack
        switch attacker {
        case .unit(let k): attack = catalogue.stats(k).attack!
        case .building(let k): attack = catalogue.stats(k).attack!
        }
        return sim.harm(from: a, to: d, attack: attack)
    }

    @Test func aBlowDoesItsDamageLessArmourAndAtLeastOne() {
        #expect(Self.harm(.unit(.clubman), .unit(.clubman)) == 4)
        #expect(Self.harm(.unit(.worker), .unit(.spearman)) == 3 - 1)
        #expect(Self.harm(.unit(.worker), .building(.townCentre)) == 1)
        #expect(Self.harm(.unit(.engineer), .building(.townCentre)) == 1)
        #expect(Self.harm(.building(.watchTower), .unit(.spearman)) == 4 - 1)
    }

    @Test func bonusesMultiplyTheDamageBeforeArmour() {
        #expect(Self.harm(.unit(.spearman), .unit(.chariot)) == 5 * 3 - 1)
        #expect(Self.harm(.unit(.archer), .unit(.spearman)) == 6 - 1)
        #expect(Self.harm(.unit(.clubman), .unit(.slinger)) == 6)
        #expect(Self.harm(.unit(.slinger), .unit(.clubman)) == 3)
    }

    @Test func bronzeWeaponsAndShieldsChangeWarfightersOnly() {
        #expect(Self.harm(.unit(.clubman), .unit(.clubman), attackerHas: [.bronzeWeapons]) == 5)
        #expect(Self.harm(.unit(.worker), .unit(.clubman), attackerHas: [.bronzeWeapons]) == 3)
        #expect(Self.harm(.unit(.clubman), .unit(.clubman), defenderHas: [.shields]) == 3)
        #expect(Self.harm(.unit(.clubman), .unit(.worker), defenderHas: [.shields]) == 4)
        #expect(Self.harm(.unit(.slinger), .unit(.spearman), defenderHas: [.shields]) == 1)
    }

    @Test func meleeClosesInAndRangedStrikesFromItsRange() {
        var sim = duel()
        let clubman = sim.add(.clubman, me, 14.5, 16.5)
        let slinger = sim.add(.slinger, me, 14.5, 20.5)
        let targets = [sim.add(.worker, them, 19.5, 16.5), sim.add(.worker, them, 19.5, 20.5)]
        #expect(sim.apply(.attack(units: [clubman], target: targets[0]), from: me) == .accepted)
        #expect(sim.apply(.attack(units: [slinger], target: targets[1]), from: me) == .accepted)
        do { let reached = sim.run(until: { s in [clubman, slinger].allSatisfy { s.living($0).doing == .fighting } }, limit: 200); #expect(reached) }
        let range = Catalogue.standard.stats(.slinger).attack!.range
        let slingerDistance = sim.living(slinger).position.distance(to: sim.living(targets[1]).position)
        #expect(slingerDistance <= range && slingerDistance > range - 0.5)
        #expect(sim.living(clubman).position.distance(to: sim.living(targets[0]).position) <= 1)
        // Each has struck at least once, and each target has lost whole blows.
        let health = Catalogue.standard.stats(.worker).health
        let lost = targets.map { health - (sim.health($0) ?? 0) }
        #expect(lost[0] >= 4 && lost[0] % 4 == 0)
        #expect(lost[1] >= 3 && lost[1] % 3 == 0)
        #expect(sim.view(for: me).entity(clubman)?.activity == .fighting)
    }

    @Test func townCentresAndTowersShootOpponentsInRange() {
        var sim = duel()
        let intruder = sim.add(.clubman, them, 8.5, 3.5)       // 4 from player 0's town centre
        let mine = sim.add(.clubman, me, 6.5, 3.5)
        let tower = sim.add(.watchTower, me, 20, 20)
        let unfinished = sim.add(.watchTower, me, 26, 12, complete: false)
        let scout = sim.add(.clubman, them, 25.5, 20.5)        // 5 from the tower
        let passer = sim.add(.clubman, them, 26.5, 14.5)       // beside the unfinished tower
        let centre = Catalogue.standard.stats(.townCentre).attack!
        let towerAttack = Catalogue.standard.stats(.watchTower).attack!
        sim.run(centre.interval * 2)
        let health = Catalogue.standard.stats(.clubman).health
        #expect(sim.health(intruder) == health - 2 * (centre.damage - 0))
        #expect(sim.health(mine) == health)
        #expect(sim.health(scout) == health - (centre.interval * 2 / towerAttack.interval) * towerAttack.damage)
        #expect(sim.health(passer) == health)
        #expect(sim.living(tower).complete && !sim.living(unfinished).complete)
    }

    @Test func alliesAndOwnCannotBeAttacked() {
        var sim = Simulation(setup: setup(openMap(width: 40, height: 40, starts: [GridPoint(2, 2), GridPoint(2, 34), GridPoint(34, 34)]),
                                          teams: [0, 0, 1]))
        let clubman = sim.add(.clubman, me, 18.5, 18.5)
        let ally = sim.add(.worker, PlayerID(1), 19.5, 18.5)
        let own = sim.add(.worker, me, 18.5, 19.5)
        let opponent = sim.add(.worker, PlayerID(2), 20.5, 18.5)
        #expect(sim.apply(.attack(units: [clubman], target: ally), from: me) == .refused(.cannotAttack))
        #expect(sim.apply(.attack(units: [clubman], target: own), from: me) == .refused(.cannotAttack))
        let scholar = sim.add(.scholar, me, 18.5, 17.5)
        #expect(sim.apply(.attack(units: [scholar], target: opponent), from: me) == .refused(.notYours))
        #expect(sim.apply(.attack(units: [clubman, scholar], target: opponent), from: me) == .accepted)
        #expect(sim.living(scholar).task == .idle)
        // A tower does not shoot its own side's allies.
        sim.add(.watchTower, PlayerID(1), 22, 22)
        let allyNearTower = sim.add(.worker, me, 24.5, 22.5)
        sim.run(100)
        #expect(sim.health(allyNearTower) == Catalogue.standard.stats(.worker).health)
    }

    @Test func anOpponentOutOfSightCannotBeTargeted() {
        var sim = duel()
        let clubman = sim.add(.clubman, me, 14.5, 16.5)
        let far = sim.add(.worker, them, 24.5, 16.5)
        #expect(sim.apply(.attack(units: [clubman], target: far), from: me) == .refused(.invalidTarget))
        #expect(sim.apply(.attack(units: [clubman], target: EntityID(9_999)), from: me) == .refused(.invalidTarget))
    }

    @Test func idleWarfightersFightBackAndOthersDoNot() {
        var sim = duel()
        let attacker = sim.add(.clubman, them, 16.5, 18.5)
        let defender = sim.add(.clubman, me, 17.5, 18.5)
        let bystander = sim.add(.worker, me, 17.5, 19.0)
        _ = sim.apply(.attack(units: [attacker], target: defender), from: them)
        sim.step()
        #expect(sim.health(defender)! < Catalogue.standard.stats(.clubman).health)
        #expect(sim.living(defender).task == .attack(attacker))
        _ = sim.apply(.attack(units: [attacker], target: bystander), from: them)
        sim.run(40)
        #expect(sim.health(bystander)! < Catalogue.standard.stats(.worker).health)
        #expect(sim.living(bystander).task == .idle)
        #expect(sim.view(for: me).events.contains(.underAttack(defender)))
    }

    @Test func theDestroyedLeaveTheMapAndBothSidesHearOfIt() {
        var sim = duel()
        let clubmen = (0..<4).map { _ in sim.add(.clubman, me, 17.5, 18.5) }
        let house = sim.add(.house, them, 18, 18)
        let worker = sim.add(.worker, them, 16.5, 19.5)
        _ = sim.apply(.attack(units: clubmen, target: worker), from: me)
        do { let reached = sim.run(until: { $0.entity(worker) == nil }, limit: 400); #expect(reached) }
        #expect(sim.view(for: me).events.contains(.destroyed(worker)))
        #expect(sim.view(for: them).events.contains(.destroyed(worker)))
        _ = sim.apply(.attack(units: clubmen, target: house), from: me)
        do { let reached = sim.run(until: { $0.entity(house) == nil }, limit: 4_000); #expect(reached) }
        #expect(sim.open(GridPoint(18, 18)) && sim.open(GridPoint(19, 19)))
        // With the target gone and none in sight, the warfighters stand.
        sim.step()
        #expect(clubmen.allSatisfy { sim.living($0).task == .idle })
    }

    @Test func aWarfighterWhoseTargetFallsTakesTheNearestOpponentInSight() {
        var sim = duel()
        let clubmen = (0..<3).map { _ in sim.add(.clubman, me, 17.5, 18.5) }
        let first = sim.add(.worker, them, 18.5, 18.5)
        let second = sim.add(.worker, them, 20.5, 18.5)
        _ = sim.apply(.attack(units: clubmen, target: first), from: me)
        do { let reached = sim.run(until: { $0.entity(first) == nil }, limit: 400); #expect(reached) }
        sim.step()
        #expect(clubmen.allSatisfy { sim.living($0).task == .attack(second) })
    }
}

@Suite struct Sight {
    @Test func aPlayerSeesWithinItsEntitiesSightAndRemembersWhatItExplored() {
        var sim = duel()
        let worker = sim.add(.worker, me, 20.5, 20.5)
        let sight = Int(Catalogue.standard.stats(.worker).sight)
        var view = sim.view(for: me)
        #expect(view.visibility(at: GridPoint(20 + sight, 20)) == .visible)
        #expect(view.visibility(at: GridPoint(21 + sight, 20)) == .unexplored)
        #expect(view.visibility(at: GridPoint(30, 30)) == .unexplored)
        _ = sim.apply(.move(units: [worker], to: MapPosition(x: 20.5, y: 10.5)), from: me)
        sim.run(300)
        view = sim.view(for: me)
        #expect(view.visibility(at: GridPoint(20 + sight, 20)) == .explored)
        #expect(view.visibility(at: GridPoint(20, 10)) == .visible)
    }

    @Test func alliesShareSightAndViewsShowOthersOnlyWhereVisible() {
        var sim = Simulation(setup: setup(openMap(width: 48, height: 48, starts: [GridPoint(2, 2), GridPoint(2, 42), GridPoint(42, 42)]),
                                          teams: [0, 0, 1]))
        let allyScout = sim.add(.clubman, PlayerID(1), 30.5, 10.5)
        let opponent = sim.add(.worker, PlayerID(2), 32.5, 10.5)
        let hidden = sim.add(.worker, PlayerID(2), 20.5, 30.5)
        var view = sim.view(for: me)
        #expect(view.visibility(at: GridPoint(32, 10)) == .visible)
        #expect(view.entity(allyScout) != nil)
        #expect(view.entity(opponent) != nil)
        #expect(view.entity(hidden) == nil)
        // An ally's people far from anything of player 0's are shown all the same.
        #expect(view.entity(sim.people(PlayerID(1), .worker)[0]) != nil)
        // The opponent sees its own and nothing of the other team's beyond its sight.
        let theirs = sim.view(for: PlayerID(2))
        #expect(theirs.entity(hidden) != nil)
        #expect(theirs.entity(sim.townCentre(me)) == nil)
        #expect(theirs.entity(allyScout) != nil)
        // Out of sight again, the opponent drops out of the view.
        _ = sim.apply(.move(units: [allyScout], to: MapPosition(x: 23.5, y: 30.5)), from: PlayerID(1))
        sim.run(10)
        _ = sim.apply(.move(units: [opponent], to: MapPosition(x: 44.5, y: 4.5)), from: PlayerID(2))
        sim.run(500)
        #expect(sim.living(allyScout).task == .idle && sim.living(opponent).task == .idle)
        view = sim.view(for: me)
        #expect(view.entity(opponent) == nil)
        #expect(view.entity(hidden) != nil)
    }

    @Test func sitesShowOnlyOnExploredTilesAndFromTheirAge() {
        var sim = Simulation(setup: setup(openMap(width: 48, height: 48, starts: [GridPoint(2, 2), GridPoint(8, 2), GridPoint(42, 42)],
                                                  sites: [(.copper, 6, 7), (.tree, 5, 8), (.tree, 30, 30), (.tin, 30, 31)]),
                                          teams: [0, 0, 1]))
        var view = sim.view(for: me)
        #expect(view.sites.map(\.id) == [SiteID(1)])
        sim.players[1].age = .bronze
        #expect(sim.view(for: PlayerID(1)).sites.map(\.id) == [SiteID(0), SiteID(1)])
        #expect(sim.view(for: me).sites.map(\.id) == [SiteID(1)])
        sim.players[0].age = .bronze
        view = sim.view(for: me)
        #expect(view.sites.map(\.id) == [SiteID(0), SiteID(1)])
    }

    @Test func aDepositNotYetRevealedShowsAsAnOutcropThatBlocksPlacement() {
        var sim = Simulation(setup: setup(openMap(width: 48, height: 48, starts: [GridPoint(2, 2), GridPoint(42, 42)],
                                                  sites: [(.copper, 6, 7), (.tree, 5, 8), (.tin, 30, 31)]),
                                          teams: [0, 1]))
        var view = sim.view(for: me)
        #expect(view.outcrops == [GridPoint(6, 7)])
        #expect(!Placement.canPlace(.house, at: GridPoint(5, 6), in: view))
        sim.players[0].age = .bronze
        view = sim.view(for: me)
        #expect(view.outcrops.isEmpty)
        #expect(view.sites.contains { $0.tile == GridPoint(6, 7) && $0.kind == .copper })
    }
}
