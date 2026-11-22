// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// Navy ships, as far as a match needs them to end (requirement 16): an
/// opponent's fishing boat is a unit and keeps its player in the match, and
/// only a navy ship reaches it. Once an opponent's vessel is in sight and no
/// opponent's warfighter is, a boathouse makes a navy ship, and each idle navy
/// ship attacks the nearest opponent's vessel in sight, or else sails to where
/// opponents were last seen, or to ground not seen. A vessel on water no navy
/// ship of its reaches is shot from the shore instead: a tower goes up beside
/// it. Its full use is a later step's.
extension Turn {
    /// The navy ships a computer player keeps once it has an opponent's vessel to sink.
    static let navyWanted = 1

    /// A complete boathouse makes a navy ship, one at a time, while an
    /// opponent's vessel is in sight and no opponent's warfighter is.
    func trainNavy() {
        guard !enemyVessels.isEmpty, !enemyUnits.contains(where: { Turn.unitKind($0)?.isWarfighter ?? false }), navy.count + training[UnitKind.navyShip.rawValue] < Self.navyWanted,
              let made = catalogue.production(of: .navyShip, at: .boatHouse), made.age <= view.age else { return }
        let stats = catalogue.stats(.navyShip)
        for house in completeBuildings(.boatHouse) where isFree(house) && queueLength(house) == 0 {
            guard projectedPopulation + stats.population <= view.populationLimit, canPay(stats.cost, urgent: true) else { return }
            train(.navyShip, at: house)
            return
        }
    }

    /// Each idle navy ship attacks the nearest opponent's vessel in sight, or goes looking.
    func sendNavy() {
        for ship in navy where isFree(ship) && ship.activity == .idle {
            if let target = Turn.nearest(enemyVessels, to: ship.position) {
                give(.attack(units: [ship.id], target: target.id), to: [ship.id])
            } else if let place = huntingGround(from: ship.position) {
                give(.move(units: [ship.id], to: clamped(place)), to: [ship.id])
            }
        }
    }

    /// While an opponent's vessel is in sight and no opponent's warfighter is,
    /// a tower goes up on the shore beside the nearest one that no tower of its reaches.
    func guardTheShore() {
        guard !enemyVessels.isEmpty, !enemyUnits.contains(where: { Turn.unitKind($0)?.isWarfighter ?? false }),
              memory.plans.allSatisfy({ $0.kind != .tower }), !buildings.contains(where: {
                  $0.kind == .building(.tower) && !Turn.isComplete($0) }) else { return }
        let reach = (catalogue.stats(.tower).figures(at: view.age).attack?.range ?? 0) - 1
        let towers = completeBuildings(.tower)
        let open = enemyVessels.filter { vessel in !towers.contains { $0.position.distance(to: vessel.position) <= reach } }
        guard let target = Turn.nearest(open, to: base) else { return }
        construct(.tower, near: target.position, rings: 0...Int(max(1, reach - 1)), builders: 2, urgent: true)
    }
}
