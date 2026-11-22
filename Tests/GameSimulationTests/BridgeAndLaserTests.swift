// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
import Testing
@testable import GameSimulation

/// A river three tiles wide down the whole map, at x = 10, 11 and 12.
private let river = (0..<40).flatMap { y in (10...12).map { GridPoint($0, y) } }

/// Bridges (ruled 2026-11-21).
@Suite struct Bridges {
    @Test func theLineMustBeStraightFromLandToLandOverWaterOnly() {
        var terrain = Array(repeating: Terrain.grass, count: 40 * 40)
        for t in river { terrain[t.y * 40 + t.x] = .deepWater }
        let line = { (a: GridPoint, b: GridPoint) in Placement.bridgeWater(from: a, to: b, width: 40, height: 40, terrain: terrain) }
        #expect(line(GridPoint(9, 20), GridPoint(13, 20)) == [GridPoint(10, 20), GridPoint(11, 20), GridPoint(12, 20)])
        #expect(line(GridPoint(13, 20), GridPoint(9, 20)) == [GridPoint(12, 20), GridPoint(11, 20), GridPoint(10, 20)])
        #expect(line(GridPoint(9, 20), GridPoint(13, 24)) == nil)        // not straight
        #expect(line(GridPoint(9, 20), GridPoint(12, 20)) == nil)        // ends in water
        #expect(line(GridPoint(8, 20), GridPoint(13, 20)) == nil)        // land between
        #expect(line(GridPoint(4, 20), GridPoint(5, 20)) == nil)         // no water
    }

    @Test func aBridgeIsTwoRowsOfTheSameLength() {
        var terrain = Array(repeating: Terrain.grass, count: 40 * 40)
        for t in river { terrain[t.y * 40 + t.x] = .deepWater }
        terrain[21 * 40 + 13] = .deepWater      // the river a tile wider beside the second row
        let rows = { (a: GridPoint, b: GridPoint) in Placement.bridgeRows(from: a, to: b, width: 40, height: 40, terrain: terrain) }
        #expect(rows(GridPoint(9, 18), GridPoint(13, 18)) == [[GridPoint(10, 18), GridPoint(11, 18), GridPoint(12, 18)],
                                                              [GridPoint(10, 19), GridPoint(11, 19), GridPoint(12, 19)]])
        #expect(rows(GridPoint(9, 20), GridPoint(13, 20)) == nil)       // the second row ends in water
        #expect(Placement.bridgeEnds(from: GridPoint(9, 18), to: GridPoint(13, 18))
                == [GridPoint(9, 18), GridPoint(13, 18), GridPoint(9, 19), GridPoint(13, 19)])
    }

    @Test func theDeckRisesFromEachBankToAHeightItKeeps() {
        let six = (0...6).map { BridgePlace(run: .alongX, lane: 0, index: 0, count: 6).height(at: $0) }
        #expect(six == [0, 4, 8, 12, 8, 4, 0])
        let ten = (0...10).map { BridgePlace(run: .alongY, lane: 1, index: 0, count: 10).height(at: $0) }
        #expect(ten == [0, 4, 8, 12, 12, 12, 12, 12, 8, 4, 0])
        #expect(BridgePlace(run: .alongX, lane: 0, index: 2, count: 5).middle)
        #expect(BridgePlace(run: .alongX, lane: 0, index: 2, count: 5).heights == (back: 8, front: 8))
        // Every drawing a bridge may need is listed once.
        let poses = BridgePlace.drawings.map { $0.pose(complete: true) }
        #expect(Set(poses).count == poses.count)
        #expect(poses.contains(BridgePlace(run: .alongY, lane: 1, index: 7, count: 16).pose(complete: true)))
    }

    @Test func engineersBuildFromTheNearBankAndAnyoneCrosses() {
        var sim = duel(water: river)
        sim.exploreAll(me)
        sim.give(me, [.wood: 100])
        let engineer = sim.add(.engineer, me, 8.5, 20.5)
        let walker = sim.add(.worker, me, 7.5, 21.5)
        let wood = sim.resources(me)[.wood]
        #expect(sim.apply(.buildBridge(engineers: [walker], from: GridPoint(9, 20), to: GridPoint(13, 20)), from: me)
                == .refused(.notYours))
        #expect(sim.apply(.buildBridge(engineers: [engineer], from: GridPoint(9, 20), to: GridPoint(13, 20)), from: me)
                == .accepted)
        #expect(sim.resources(me)[.wood] == wood - 6 * 10)
        let pieces = sim.buildings(me, .bridge)
        #expect(pieces.count == 6)
        #expect(pieces.allSatisfy { sim.living($0).bridgePlace?.run == .alongX })
        // Two rows, the second toward the screen's foot, each piece knowing its place along its row.
        let places = Set(pieces.map { sim.living($0).position.tile })
        #expect(places == Set([10, 11, 12].flatMap { [GridPoint($0, 20), GridPoint($0, 21)] }))
        #expect(pieces.allSatisfy { id in
            let e = sim.living(id), place = e.bridgePlace!
            return place.count == 3 && place.index == e.position.tile.x - 10 && place.lane == e.position.tile.y - 20
        })
        // A piece already there blocks a second bridge over it.
        #expect(sim.apply(.buildBridge(engineers: [engineer], from: GridPoint(9, 20), to: GridPoint(13, 20)), from: me)
                == .refused(.placementBlocked))
        let built = sim.run(until: { s in s.buildings(me, .bridge).allSatisfy { s.living($0).complete } }, limit: 60 * Tick.rate)
        #expect(built, "the bridge was not finished")
        // A worker walks across.
        #expect(sim.apply(.move(units: [walker], to: MapPosition(x: 16.5, y: 20.5)), from: me) == .accepted)
        let crossed = sim.run(until: { $0.living(walker).position.x > 15 }, limit: 30 * Tick.rate)
        #expect(crossed, "the worker did not cross")
        // The bridge keeps nobody in the match, and an opponent may destroy it.
        #expect(sim.ownership().others[0])
        #expect(sim.canStrike(them, sim.index(of: pieces[1])!))
    }

    @Test func whoeverStandsOnAPieceThatFallsGoesToOpenGround() {
        var sim = duel(water: river)
        let added = sim.add(.bridge, me, 11, 20)
        let piece = sim.index(of: added)!
        #expect(!sim.blocked[sim.tileIndex(GridPoint(11, 20))])
        let worker = sim.add(.worker, me, 11.5, 20.5)
        sim.kill(piece)
        #expect(sim.blocked[sim.tileIndex(GridPoint(11, 20))])
        let t = sim.living(worker).position.tile
        #expect(!sim.blocked[sim.tileIndex(t)])
    }

    @Test func aMatchMaySayNoBridges() {
        var match = setup(openMap(starts: [GridPoint(2, 2), GridPoint(34, 34)], water: river), teams: [0, 1])
        match.noBridges = true
        var sim = Simulation(setup: match)
        sim.exploreAll(me)
        sim.give(me, [.wood: 100])
        let engineer = sim.add(.engineer, me, 8.5, 20.5)
        #expect(sim.apply(.buildBridge(engineers: [engineer], from: GridPoint(9, 20), to: GridPoint(13, 20)), from: me)
                == .refused(.invalidTarget))
        #expect(!sim.view(for: me).bridges)
        var open = duel()
        #expect(open.view(for: me).bridges)
    }

    @Test func aMatchSavedBeforeBridgesGainsThem() throws {
        let sim = duel()
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(sim)) as! [String: Any]
        var catalogue = json["catalogue"] as! [String: Any]
        catalogue["buildings"] = (catalogue["buildings"] as! [[String: Any]]).filter { ($0["kind"] as? Int) != BuildingKind.bridge.rawValue }
        var car = catalogue["car"] as! [String: Any]
        car["laserRange"] = nil
        car["laserTime"] = nil
        catalogue["car"] = car
        json["catalogue"] = catalogue
        let reopened = try JSONDecoder().decode(Simulation.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(reopened.catalogue.stats(.bridge) == Catalogue.standard.stats(.bridge))
        #expect(reopened.catalogue.car == Catalogue.standard.car)
    }
}

/// The car's laser (ruled 2026-11-21).
@Suite struct Laser {
    @Test func itBurnsAnyOpponentsBuildingDownInAboutFourSeconds() {
        var sim = duel()
        sim.exploreAll(me)
        #expect(sim.apply(.summonCar, from: me) == .accepted)
        let car = sim.people(me, .car)[0]
        let at = sim.living(car).position.tile
        let barracks = sim.add(.barracks, them, at.x + 6, at.y)
        let castle = sim.add(.castle, them, at.x, at.y + 6)
        #expect(sim.apply(.attack(units: [car], target: barracks), from: me) == .accepted)
        sim.step()
        let view = sim.view(for: me)
        #expect(view.entities.first { $0.id == car }?.laserTarget == sim.living(barracks).position)
        let time = Catalogue.standard.car!.laserTime
        let barracksGone = sim.run(until: { $0.entity(barracks) == nil }, limit: time + Tick.rate / 2)
        #expect(barracksGone)
        #expect(sim.apply(.attack(units: [car], target: castle), from: me) == .accepted)
        let castleGone = sim.run(until: { $0.entity(castle) == nil }, limit: time + Tick.rate / 2)
        #expect(castleGone)
        #expect(sim.living(car).task == .idle)
    }

    @Test func itDrivesWithinEightTilesFirst() {
        var sim = duel()
        sim.exploreAll(me)
        #expect(sim.apply(.summonCar, from: me) == .accepted)
        let car = sim.people(me, .car)[0]
        let house = sim.add(.house, them, 24, 6)
        _ = sim.add(.worker, me, 23.5, 10.5)     // someone of the player's in sight of it
        #expect(sim.apply(.attack(units: [car], target: house), from: me) == .accepted)
        var nearest = Double.infinity
        let gone = sim.run(until: { s in
            if s.living(car).doing == .fighting { nearest = min(nearest, s.living(car).position.distance(to: s.living(house).position)) }
            return s.entity(house) == nil
        }, limit: 30 * Tick.rate)
        #expect(gone)
        #expect(nearest <= Catalogue.standard.car!.laserRange + 1.5)
    }

    @Test func notOwnOrAlliedBuildingsNorPeople() {
        var sim = duel()
        sim.exploreAll(me)
        #expect(sim.apply(.summonCar, from: me) == .accepted)
        let car = sim.people(me, .car)[0]
        let at = sim.living(car).position
        #expect(sim.apply(.attack(units: [car], target: sim.townCentre(me)), from: me) == .refused(.cannotAttack))
        let clubman = sim.add(.clubman, them, at.x + 15, at.y)
        #expect(sim.apply(.attack(units: [car], target: clubman), from: me) == .refused(.cannotAttack))
    }
}
