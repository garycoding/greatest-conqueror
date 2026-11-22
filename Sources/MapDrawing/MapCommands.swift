// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// What a click, a box or a right-click means, as pure functions of the view, so
/// that they are tested without a scene. Orders are returned, never issued here.
public enum MapCommands {
    /// The selection after a click on `hit` (`nil` for empty ground). With `additive`
    /// (shift) the entity is added to the selection, or removed if already in it,
    /// and a click on empty ground changes nothing.
    public static func selection(afterClickOn hit: EntityID?, current: [EntityID], additive: Bool) -> [EntityID] {
        guard let hit else { return additive ? current : [] }
        if !additive { return [hit] }
        if let index = current.firstIndex(of: hit) {
            var out = current
            out.remove(at: index)
            return out
        }
        return current + [hit]
    }

    /// The selection after a double-click on `hit`: the player's own people of
    /// the same kind and the same job (`EntityView.job`) among `onScreen`, the
    /// player's people in the current window (ruled 2026-11-20). A double-click
    /// on anything else selects as a single click does.
    public static func selection(afterDoubleClickOn hit: EntityID?, onScreen: [EntityID], view: PlayerView) -> [EntityID] {
        guard let hit, let clicked = view.entity(hit), clicked.owner == view.player, case .unit = clicked.kind else {
            return hit.map { [$0] } ?? []
        }
        let alike = onScreen.filter { id in
            guard let e = view.entity(id) else { return false }
            return e.owner == view.player && e.kind == clicked.kind && e.job == clicked.job
        }
        return alike.contains(hit) ? alike : [hit] + alike
    }

    /// The selection after a box that holds `boxed` (the player's own people).
    /// With `additive` they are added to the selection; otherwise they replace it.
    public static func selection(afterBoxHolding boxed: [EntityID], current: [EntityID], additive: Bool) -> [EntityID] {
        guard additive else { return boxed }
        return current + boxed.filter { !current.contains($0) }
    }

    /// The order a right-click gives to the player's selected people, or `nil` if
    /// none of the selection is a person of the player's.
    ///
    /// - Ground: move; but navy ships carrying troops, right-clicked onto
    ///   land, land them there (requirement 16). A site: workers gather there,
    ///   or fishing boats if it is in the water (others move to it). An own
    ///   building that is unfinished or damaged, or a complete farm: workers
    ///   (or a founder, at the town centre it founded) work there. An own navy
    ///   ship: troops board it (requirement 16). An own wounded unit: doctors
    ///   heal it (requirement 13). Another of the player's or an ally's: move
    ///   to it. An opponent: attack.
    public static func contextualOrder(on target: MapTarget, view: PlayerView, selection: [EntityID],
                                       catalogue: Catalogue = .standard) -> Order? {
        let people = selection.compactMap { view.entity($0) }.filter {
            if case .unit = $0.kind { return $0.owner == view.player } else { return false }
        }
        guard !people.isEmpty else { return nil }
        func ids(_ matching: (UnitKind) -> Bool) -> [EntityID] {
            people.filter { if case .unit(let k) = $0.kind { return matching(k) } else { return false } }.map(\.id)
        }
        let everyone = people.map(\.id)

        switch target {
        case .ground(let position):
            let tile = position.tile
            let onLand = tile.x >= 0 && tile.y >= 0 && tile.x < view.mapWidth && tile.y < view.mapHeight
                && view.terrain[tile.y * view.mapWidth + tile.x].isPassable
            let loaded = people.filter { $0.kind == .unit(.navyShip) && ($0.passengers ?? 0) > 0 }.map(\.id)
            if onLand && !loaded.isEmpty { return .land(ships: loaded, at: position) }
            return .move(units: everyone, to: position)
        case .site(let site):
            // A site in the water is gathered by boats, one on land by workers (ruled 2026-11-21).
            let afloat = view.terrain.indices.contains(site.tile.y * view.mapWidth + site.tile.x)
                && view.terrain[site.tile.y * view.mapWidth + site.tile.x].isWater
            let gatherers = ids { afloat ? $0 == .fishingBoat : $0 == .worker }
            return gatherers.isEmpty ? .move(units: everyone, to: site.tile.centre) : .gather(units: gatherers, site: site.id)
        case .entity(let entity):
            if entity.owner == view.player, entity.kind == .unit(.navyShip) {
                let troops = ids(\.isWarfighter)
                if !troops.isEmpty { return .board(units: troops, ship: entity.id) }
            }
            if entity.owner == view.player, case .unit(let kind) = entity.kind, kind.isUnit, !kind.isAfloat,
               entity.health < entity.maxHealth {
                let doctors = ids { catalogue.stats($0).healing ?? 0 > 0 }.filter { $0 != entity.id }
                if !doctors.isEmpty { return .heal(doctors: doctors, target: entity.id) }
            }
            if entity.owner == view.player, case .building(let kind) = entity.kind {
                var unfinished = false
                if case .underConstruction = entity.activity { unfinished = true }
                let workers = ids { $0 == .worker || (unfinished && $0 == .founder) }
                if (unfinished || entity.health < entity.maxHealth || kind == .farm), !workers.isEmpty {
                    return .work(units: workers, at: entity.id)
                }
                return .move(units: everyone, to: entity.position)
            }
            if view.isAlly(entity.owner) { return .move(units: everyone, to: entity.position) }
            return .attack(units: everyone, target: entity.id)
        }
    }
}
