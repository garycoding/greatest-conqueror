// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
import Testing
@testable import ComputerPlayer

/// Asks a player for orders and checks every one of them (`OrderCheck`), so
/// that each test also tests the rules every order must meet.
func decide(_ player: inout ComputerPlayer, _ view: PlayerView, catalogue: Catalogue = .standard,
            sourceLocation: SourceLocation = #_sourceLocation) -> [Order] {
    let orders = player.decide(view: view, catalogue: catalogue)
    let problems = OrderCheck.problems(orders, in: view, catalogue: catalogue)
    #expect(problems.isEmpty, "\(problems)", sourceLocation: sourceLocation)
    return orders
}

/// The rules a person's orders meet, applied to the orders of one decision:
/// the player orders only people and buildings it owns, gives no person two
/// orders, never targets an ally or a car, and never orders what it cannot
/// afford, place, house or has not reached the age for.
enum OrderCheck {
    static func problems(_ orders: [Order], in view: PlayerView, catalogue: Catalogue) -> [String] {
        var problems: [String] = []
        var spent = ResourceAmounts()
        var population = view.population
        var commanded = Set<EntityID>()
        var trainedAt = Set<EntityID>()
        var footprints = Set<GridPoint>()

        func own(_ id: EntityID) -> EntityView? {
            guard let entity = view.entity(id), entity.owner == view.player else { return nil }
            return entity
        }
        func person(_ id: EntityID) -> UnitKind? {
            if case .unit(let kind)? = own(id)?.kind { return kind }
            return nil
        }
        func building(_ id: EntityID) -> (entity: EntityView, kind: BuildingKind)? {
            guard let entity = own(id), case .building(let kind) = entity.kind else { return nil }
            return (entity, kind)
        }
        func isComplete(_ entity: EntityView) -> Bool {
            if case .underConstruction = entity.activity { return false }
            return true
        }
        // As `Simulation.atShore`: an open land tile within one and a half tiles.
        func atShore(_ ship: EntityView) -> Bool {
            let t = ship.position.tile
            for y in (t.y - 2)...(t.y + 2) {
                for x in (t.x - 2)...(t.x + 2) {
                    let tile = GridPoint(x, y)
                    guard tile.x >= 0, tile.y >= 0, tile.x < view.mapWidth, tile.y < view.mapHeight,
                          view.terrain(at: tile).isPassable, tile.centre.distance(to: ship.position) <= 1.5 else { continue }
                    return true
                }
            }
            return false
        }
        func command(_ units: [EntityID], _ what: String, _ allowed: (UnitKind) -> Bool) {
            if units.isEmpty { problems.append("\(what): no one ordered") }
            for id in units {
                guard let kind = person(id) else {
                    problems.append("\(what): \(id) is not a person it owns")
                    continue
                }
                if !allowed(kind) { problems.append("\(what): \(id) is a \(kind)") }
                if !commanded.insert(id).inserted { problems.append("\(what): \(id) is given two orders") }
            }
        }

        for order in orders {
            switch order {
            case .move(let units, let to):
                command(units, "move") { _ in true }
                if to.x < 0 || to.y < 0 || to.x > Double(view.mapWidth) || to.y > Double(view.mapHeight) {
                    problems.append("move: \(to) is off the map")
                }
            case .summonCar:
                problems.append("summonCar: a computer player has no car")
            case .setKillRadius:
                problems.append("setKillRadius: a computer player has no car")
            case .reseed(let farm):
                if building(farm)?.entity.remaining != 0 { problems.append("reseed: \(farm) is not a farm of its own that has run dry") }
            case .gather(let units, let site):
                // Boats gather in the water, workers on land (ruled 2026-11-21).
                let known = view.sites.first { $0.id == site && $0.remaining > 0 }
                let afloat = known.map { view.terrain[$0.tile.y * view.mapWidth + $0.tile.x].isWater } ?? false
                command(units, "gather") { afloat ? $0 == .fishingBoat : $0 == .worker }
                if known == nil {
                    problems.append("gather: site \(site.rawValue) is not a known site with something left")
                }
            case .work(let units, let at):
                guard let place = building(at) else {
                    problems.append("work: \(at) is not a building it owns")
                    command(units, "work") { _ in true }
                    break
                }
                command(units, "work at \(place.kind)") { kind in
                    kind == .worker && (place.kind == .farm || !isComplete(place.entity)
                                        || place.entity.health < place.entity.maxHealth)
                }
            case .construct(let workers, let kind, let at):
                command(workers, "construct") { $0 == .worker }
                let stats = catalogue.stats(kind)
                if stats.age > view.age { problems.append("construct: \(kind) needs the age of \(stats.age.name)") }
                if !Placement.canPlace(kind, at: at, in: view, catalogue: catalogue) {
                    problems.append("construct: \(kind) cannot stand at \(at)")
                }
                for tile in Placement.footprint(kind, at: at, catalogue: catalogue) where !footprints.insert(tile).inserted {
                    problems.append("construct: \(kind) overlaps another building ordered at \(tile)")
                }
                spent = spent + stats.cost
            case .dismiss(let units):
                command(units, "dismiss") { _ in true }
            case .demolish(let workers, let at):
                command(workers, "demolish") { $0 == .worker }
                if building(at) == nil { problems.append("demolish: \(at) is not a building it owns") }
            case .attack(let units, let target):
                command(units, "attack") { catalogue.stats($0).attack != nil }
                guard let struck = view.entity(target) else {
                    problems.append("attack: \(target) is not in sight")
                    break
                }
                if view.isAlly(struck.owner) { problems.append("attack: \(target) belongs to an ally or itself") }
                if struck.kind == .unit(.car) { problems.append("attack: \(target) is a car") }
            case .train(let at, let unit):
                if person(at) == .navyShip, let ship = own(at) {
                    // A navy ship makes units (requirement 17), at the shore only (requirement 18).
                    if catalogue.production(of: unit, at: .unit(.navyShip)).map({ $0.age > view.age }) ?? true {
                        problems.append("train: a navy ship does not make \(unit) in the age of \(view.age.name)")
                    }
                    if !atShore(ship) { problems.append("train: navy ship \(at) is not at the shore") }
                    if !trainedAt.insert(at).inserted { problems.append("train: two orders at \(at)") }
                    spent = spent + catalogue.stats(unit).cost
                    population += catalogue.stats(unit).population
                    if population > view.populationLimit { problems.append("train: \(unit) exceeds the population limit") }
                    break
                }
                guard let place = building(at) else {
                    problems.append("train: \(at) is not a building it owns")
                    break
                }
                if !isComplete(place.entity) { problems.append("train: \(place.kind) is unfinished") }
                if !catalogue.stats(place.kind).trains.contains(unit) { problems.append("train: \(place.kind) does not train \(unit)") }
                if catalogue.stats(unit).age > view.age { problems.append("train: \(unit) needs a later age") }
                if !trainedAt.insert(at).inserted { problems.append("train: two orders at \(at)") }
                spent = spent + catalogue.stats(unit).cost
                population += catalogue.stats(unit).population
                if population > view.populationLimit { problems.append("train: \(unit) exceeds the population limit") }
            case .advanceAge(let at):
                guard let advance = catalogue.advance(from: view.age) else {
                    problems.append("advanceAge: no age follows")
                    break
                }
                if let place = building(at), place.kind == .townCentre, isComplete(place.entity) {} else {
                    problems.append("advanceAge: \(at) is not a complete town centre of its own")
                }
                if view.ageProgress > 0 { problems.append("advanceAge: an advance is under way") }
                spent = spent + advance.cost
            case .board(let units, let ship):
                // Soldiers, knights, cannons, workers and doctors board a navy ship of its own at the shore.
                command(units, "board") { $0.boardsShips }
                if let vessel = own(ship), vessel.kind == .unit(.navyShip) {
                    if !atShore(vessel) { problems.append("board: navy ship \(ship) is not at the shore") }
                    if units.count > catalogue.shipCargo - (vessel.passengers ?? 0) {
                        problems.append("board: more troops than navy ship \(ship) has room for")
                    }
                } else {
                    problems.append("board: \(ship) is not a navy ship it owns")
                }
            case .land(let ships, let at):
                command(ships, "land") { $0 == .navyShip }
                for id in ships where (own(id)?.passengers ?? 0) == 0 { problems.append("land: navy ship \(id) carries no one") }
                let tile = at.tile
                if tile.x < 0 || tile.y < 0 || tile.x >= view.mapWidth || tile.y >= view.mapHeight
                    || !view.terrain(at: tile).isPassable {
                    problems.append("land: \(at) is not on land")
                }
            case .cancelTraining, .setPaused, .stop, .heal, .found:
                problems.append("unexpected order \(order)")
            }
        }
        if !view.resources.covers(spent) { problems.append("spends \(spent) holding only \(view.resources)") }
        return problems
    }
}
