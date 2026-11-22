// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
import Testing
@testable import GameSimulation

// Fights happen in the middle of the duel map, out of reach of both town centres.

@Suite struct Combat {
    static let catalogue = Catalogue.standard

    /// The harm a blow from one kind does to another.
    static func harm(_ attacker: EntityKind, _ defender: EntityKind) -> Int {
        var sim = duel()
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
        #expect(Self.harm(.unit(.soldier1), .unit(.soldier1)) == 5 - 1)
        #expect(Self.harm(.unit(.worker), .unit(.soldier1)) == 3 - 1)
        #expect(Self.harm(.unit(.worker), .building(.townCentre)) == 1)
        #expect(Self.harm(.building(.tower), .unit(.soldier1)) == 4 - 1)
    }

    @Test func bonusesMultiplyTheDamageBeforeArmour() {
        #expect(Self.harm(.unit(.soldier1), .unit(.knight1)) == 5 * 3 - 1)
        #expect(Self.harm(.unit(.knight1), .unit(.soldier1)) == 7 - 1)
        #expect(Self.harm(.unit(.soldier2), .unit(.soldier1)) == Int((7 * 1.5).rounded()) - 1)
        #expect(Self.harm(.unit(.soldier3), .unit(.knight2)) == 12 * 2 - 3)
        #expect(Self.harm(.unit(.soldier1), .unit(.knight2)) == Int((5 * 2.5).rounded()) - 3)
        #expect(Self.harm(.unit(.knight2), .unit(.soldier2)) == Int((10 * 1.5).rounded()) - 2)
    }

    @Test func aCannonsShotHarmsOpponentsAroundTheTargetAndNoAlly() {
        var sim = Simulation(setup: setup(openMap(starts: [GridPoint(2, 2), GridPoint(34, 34), GridPoint(2, 34)]),
                                          teams: [0, 1, 0]))
        let ally = PlayerID(2)
        let cannon = sim.add(.cannon1, me, 10.5, 18.5)
        let target = sim.add(.soldier2, them, 18.5, 18.5)
        let beside = sim.add(.soldier2, them, 19.5, 18.5)
        let far = sim.add(.soldier2, them, 22.5, 18.5)
        let friend = sim.add(.soldier2, ally, 18.5, 19.5)
        let attack = Catalogue.standard.stats(.cannon1).attack!
        sim.strike(from: sim.index(of: cannon)!, at: sim.index(of: target)!, attack: attack)
        let full = Catalogue.standard.stats(.soldier2).health
        #expect(sim.living(target).health < full)
        #expect(sim.living(beside).health < full)
        #expect(sim.living(far).health == full)
        #expect(sim.living(friend).health == full)
    }

    @Test func meleeClosesInAndRangedStrikesFromItsRange() {
        var sim = duel()
        let spearman = sim.add(.soldier1, me, 14.5, 16.5)
        let musketeer = sim.add(.soldier3, me, 12.5, 20.5)
        let targets = [sim.add(.worker, them, 19.5, 16.5), sim.add(.worker, them, 19.5, 20.5)]
        #expect(sim.apply(.attack(units: [spearman], target: targets[0]), from: me) == .accepted)
        #expect(sim.apply(.attack(units: [musketeer], target: targets[1]), from: me) == .accepted)
        do { let reached = sim.run(until: { s in [spearman, musketeer].allSatisfy { s.living($0).doing == .fighting } }, limit: 200); #expect(reached) }
        let range = Catalogue.standard.stats(.soldier3).attack!.range
        let musketeerDistance = sim.living(musketeer).position.distance(to: sim.living(targets[1]).position)
        #expect(musketeerDistance <= range && musketeerDistance > range - 0.5)
        #expect(sim.living(spearman).position.distance(to: sim.living(targets[0]).position) <= 1)
        // Each has struck at least once, and each target has lost whole blows.
        let health = Catalogue.standard.stats(.worker).health
        let lost = targets.map { health - (sim.health($0) ?? 0) }
        #expect(lost[0] >= 5 && lost[0] % 5 == 0)
        #expect(lost[1] >= 12 && lost[1] % 12 == 0)
        #expect(sim.view(for: me).entity(spearman)?.activity == .fighting)
    }

    @Test func townCentresAndTowersShootOpponentsInRange() {
        var sim = duel()
        let intruder = sim.add(.soldier1, them, 8.5, 3.5)      // 4 from player 0's town centre
        let mine = sim.add(.soldier1, me, 6.5, 3.5)
        let tower = sim.add(.tower, me, 20, 20)
        let unfinished = sim.add(.tower, me, 26, 12, complete: false)
        let scout = sim.add(.soldier1, them, 25.5, 20.5)       // 5 from the tower
        let passer = sim.add(.soldier1, them, 26.5, 14.5)      // beside the unfinished tower
        let centre = Catalogue.standard.stats(.townCentre).attack!
        let towerAttack = Catalogue.standard.stats(.tower).attack!
        sim.run(centre.interval * 2)
        let health = Catalogue.standard.stats(.soldier1).health, armour = Catalogue.standard.stats(.soldier1).armour
        #expect(sim.health(intruder) == health - 2 * (centre.damage - armour))
        #expect(sim.health(mine) == health)
        #expect(sim.health(scout) == health - (centre.interval * 2 / towerAttack.interval) * (towerAttack.damage - armour))
        #expect(sim.health(passer) == health)
        #expect(sim.living(tower).complete && !sim.living(unfinished).complete)
    }

    @Test func alliesAndOwnCannotBeAttacked() {
        var sim = Simulation(setup: setup(openMap(width: 40, height: 40, starts: [GridPoint(2, 2), GridPoint(2, 34), GridPoint(34, 34)]),
                                          teams: [0, 0, 1]))
        let spearman = sim.add(.soldier1, me, 18.5, 18.5)
        let ally = sim.add(.worker, PlayerID(1), 19.5, 18.5)
        let own = sim.add(.worker, me, 18.5, 19.5)
        let opponent = sim.add(.worker, PlayerID(2), 20.5, 18.5)
        #expect(sim.apply(.attack(units: [spearman], target: ally), from: me) == .refused(.cannotAttack))
        #expect(sim.apply(.attack(units: [spearman], target: own), from: me) == .refused(.cannotAttack))
        // A boat has no attack.
        let boat = sim.add(.fishingBoat, me, 18.5, 17.5)
        #expect(sim.apply(.attack(units: [boat], target: opponent), from: me) == .refused(.notYours))
        #expect(sim.apply(.attack(units: [spearman, boat], target: opponent), from: me) == .accepted)
        #expect(sim.living(boat).task == .idle)
        // A tower does not shoot its own side's allies.
        sim.add(.tower, PlayerID(1), 22, 22)
        let allyNearTower = sim.add(.worker, me, 24.5, 22.5)
        sim.run(100)
        #expect(sim.health(allyNearTower) == Catalogue.standard.stats(.worker).health)
    }

    @Test func anOpponentOutOfSightCannotBeTargeted() {
        var sim = duel()
        let spearman = sim.add(.soldier1, me, 14.5, 16.5)
        let far = sim.add(.worker, them, 24.5, 16.5)
        #expect(sim.apply(.attack(units: [spearman], target: far), from: me) == .refused(.invalidTarget))
        #expect(sim.apply(.attack(units: [spearman], target: EntityID(9_999)), from: me) == .refused(.invalidTarget))
    }

    @Test func idleWarfightersFightBackAndOthersDoNot() {
        var sim = duel()
        let attacker = sim.add(.soldier1, them, 16.5, 18.5)
        let defender = sim.add(.soldier1, me, 17.5, 18.5)
        let bystander = sim.add(.worker, me, 17.5, 19.0)
        _ = sim.apply(.attack(units: [attacker], target: defender), from: them)
        sim.step()
        #expect(sim.health(defender)! < Catalogue.standard.stats(.soldier1).health)
        #expect(sim.living(defender).task == .attack(attacker))
        _ = sim.apply(.attack(units: [attacker], target: bystander), from: them)
        sim.run(40)
        #expect(sim.health(bystander)! < Catalogue.standard.stats(.worker).health)
        #expect(sim.living(bystander).task == .idle)
        #expect(sim.view(for: me).events.contains(.underAttack(defender)))
    }

    @Test func theDestroyedLeaveTheMapAndBothSidesHearOfIt() {
        var sim = duel()
        let spearmen = (0..<4).map { _ in sim.add(.soldier1, me, 17.5, 18.5) }
        let house = sim.add(.house, them, 18, 18)
        let worker = sim.add(.worker, them, 16.5, 19.5)
        _ = sim.apply(.attack(units: spearmen, target: worker), from: me)
        do { let reached = sim.run(until: { $0.entity(worker) == nil }, limit: 400); #expect(reached) }
        #expect(sim.view(for: me).events.contains(.destroyed(worker)))
        #expect(sim.view(for: them).events.contains(.destroyed(worker)))
        _ = sim.apply(.attack(units: spearmen, target: house), from: me)
        do { let reached = sim.run(until: { $0.entity(house) == nil }, limit: 4_000); #expect(reached) }
        #expect(sim.open(GridPoint(18, 18)) && sim.open(GridPoint(19, 19)))
        // With the target gone and none in sight, the warfighters stand.
        sim.step()
        #expect(spearmen.allSatisfy { sim.living($0).task == .idle })
    }

    @Test func aWarfighterWhoseTargetFallsTakesTheNearestOpponentInSight() {
        var sim = duel()
        let spearmen = (0..<3).map { _ in sim.add(.soldier1, me, 17.5, 18.5) }
        let first = sim.add(.worker, them, 18.5, 18.5)
        let second = sim.add(.worker, them, 20.5, 18.5)
        _ = sim.apply(.attack(units: spearmen, target: first), from: me)
        do { let reached = sim.run(until: { $0.entity(first) == nil }, limit: 400); #expect(reached) }
        sim.step()
        #expect(spearmen.allSatisfy { sim.living($0).task == .attack(second) })
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
        let allyScout = sim.add(.soldier1, PlayerID(1), 30.5, 10.5)
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

    @Test func sitesShowOnlyOnExploredTilesAndNoneIsHidden() {
        var sim = Simulation(setup: setup(openMap(width: 48, height: 48, starts: [GridPoint(2, 2), GridPoint(8, 2), GridPoint(42, 42)],
                                                  sites: [(.gold, 6, 7), (.tree, 5, 8), (.tree, 30, 30), (.gold, 30, 31)]),
                                          teams: [0, 0, 1]))
        // Gold is seen from the age of towns, and no rock hides what lies beneath it.
        var view = sim.view(for: me)
        #expect(view.sites.map(\.id) == [SiteID(0), SiteID(1)])
        #expect(view.outcrops.isEmpty)
        #expect(!Placement.canPlace(.house, at: GridPoint(5, 6), in: view))
        sim.exploreAll(me)
        view = sim.view(for: me)
        #expect(view.sites.map(\.id) == [SiteID(0), SiteID(1), SiteID(2), SiteID(3)])
    }
}
