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
/// orders, never targets an ally or a founder, and never orders what it cannot
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
            case .exchange(let units, _, _):
                command(units, "exchange") { $0 == .merchant }
            case .carry(let units, _, _):
                command(units, "carry") { $0 == .merchant }
            case .summonCar:
                problems.append("summonCar: a computer player has no car")
            case .setKillRadius:
                problems.append("setKillRadius: a computer player has no car")
            case .buildBridge:
                problems.append("buildBridge: a computer player does not build bridges")
            case .reseed(let farm):
                if building(farm)?.entity.remaining != 0 { problems.append("reseed: \(farm) is not a farm of its own that has run dry") }
            case .gather(let units, let site):
                // Boats gather in the water, workers on land (ruled 2026-11-21).
                let known = view.sites.first { $0.id == site && $0.remaining > 0 }
                let afloat = known.map { view.terrain[$0.tile.y * view.mapWidth + $0.tile.x].isWater } ?? false
                command(units, "gather") { afloat ? $0 == .boat : $0 == .worker }
                if known == nil {
                    problems.append("gather: site \(site.rawValue) is not a known site with something left")
                }
            case .work(let units, let at):
                guard let place = building(at) else {
                    problems.append("work: \(at) is not a building it owns")
                    command(units, "work") { _ in true }
                    break
                }
                let researching: Bool = { if case .researching = place.entity.activity { return true }; return false }()
                command(units, "work at \(place.kind)") { kind in
                    switch kind {
                    case .worker: [.stockPen, .farm, .alchemistsWorkshop].contains(place.kind) && isComplete(place.entity)
                    case .engineer: true
                    case .scholar: place.kind == .townCentre || researching
                    default: false
                    }
                }
            case .construct(let engineers, let kind, let at):
                command(engineers, "construct") { $0 == .engineer }
                let stats = catalogue.stats(kind)
                if stats.age > view.age { problems.append("construct: \(kind) needs the \(stats.age.name) age") }
                if !Placement.canPlace(kind, at: at, in: view, catalogue: catalogue) {
                    problems.append("construct: \(kind) cannot stand at \(at)")
                }
                for tile in Placement.footprint(kind, at: at, catalogue: catalogue) where !footprints.insert(tile).inserted {
                    problems.append("construct: \(kind) overlaps another building ordered at \(tile)")
                }
                spent = spent + stats.cost
            case .dismiss(let units):
                command(units, "dismiss") { $0 != .founder }
            case .demolish(let engineers, let at):
                command(engineers, "demolish") { $0 == .engineer }
                if building(at) == nil { problems.append("demolish: \(at) is not a building it owns") }
            case .attack(let units, let target):
                command(units, "attack") { $0 != .founder && catalogue.stats($0).attack != nil }
                guard let struck = view.entity(target) else {
                    problems.append("attack: \(target) is not in sight")
                    break
                }
                if view.isAlly(struck.owner) { problems.append("attack: \(target) belongs to an ally or itself") }
                if struck.kind == .unit(.founder) { problems.append("attack: \(target) is a founder") }
            case .train(let at, let unit):
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
            case .upgrade(let units, let to, let at):
                command(units, "upgrade") { catalogue.upgrade(from: $0)?.to == to }
                if let place = building(at) {
                    if !isComplete(place.entity) || !catalogue.stats(place.kind).trains.contains(to) {
                        problems.append("upgrade: \(place.kind) cannot upgrade to \(to)")
                    }
                } else {
                    problems.append("upgrade: \(at) is not a building it owns")
                }
                if catalogue.stats(to).age > view.age { problems.append("upgrade: \(to) needs a later age") }
                for id in units {
                    if let kind = person(id), let step = catalogue.upgrade(from: kind) { spent = spent + step.cost }
                }
            case .advanceAge:
                guard let advance = catalogue.advance(from: view.age) else {
                    problems.append("advanceAge: no age follows")
                    break
                }
                if view.ageProgress < 1 { problems.append("advanceAge: study is incomplete") }
                spent = spent + advance.cost
            case .found(let founder, let at):
                command([founder], "found") { $0 == .founder }
                if !Placement.canPlace(.townCentre, at: at, in: view, catalogue: catalogue) {
                    problems.append("found: a town centre cannot stand at \(at)")
                }
            case .research(let at, let improvement):
                guard let place = building(at), isComplete(place.entity),
                      catalogue.stats(place.kind).researches.contains(improvement) else {
                    problems.append("research: \(improvement) cannot be researched at \(at)")
                    break
                }
                if catalogue.stats(improvement).age > view.age { problems.append("research: \(improvement) is of a later age") }
                if view.improvements.contains(improvement) { problems.append("research: \(improvement) is known") }
                if case .researching = place.entity.activity { problems.append("research: \(at) is already researching") }
                spent = spent + catalogue.stats(improvement).cost
            case .cancelTraining, .setPaused, .stop:
                problems.append("unexpected order \(order)")
            }
        }
        if !view.resources.covers(spent) { problems.append("spends \(spent) holding only \(view.resources)") }
        return problems
    }
}
