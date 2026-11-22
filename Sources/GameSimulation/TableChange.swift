// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

// New tables during play (requirement 27): the host's editor replaces the
// catalogue between two ticks, and the match plays by it from the next.

extension Simulation {
    /// Plays by `catalogue` from the next tick. Every rule that reads the
    /// tables reads the new figures from then on. Each unit and building
    /// whose kind's maximum health for its owner's age has changed, those
    /// aboard a ship included, is set to the new maximum (ruled 2026-11-22;
    /// an age upgrade keeps the share instead). The checksum counts the new
    /// tables from here on.
    public mutating func adopt(_ catalogue: Catalogue) {
        guard catalogue != self.catalogue else { return }
        self.catalogue = catalogue
        tables = Tables(catalogue)
        for i in entities.indices where entities[i].alive {
            let age = players[entities[i].owner.rawValue].age
            rescale(&entities[i], at: age)
            if var aboard = entities[i].passengers {
                for k in aboard.indices { rescale(&aboard[k], at: age) }
                entities[i].passengers = aboard
            }
        }
        rebuildCaches()
    }

    private func rescale(_ entity: inout Entity, at age: Age) {
        let health: Int
        if let kind = entity.unitKind {
            health = tables.unit(kind).figures(at: age).health
        } else if let kind = entity.buildingKind {
            health = tables.building(kind).figures(at: age).health
        } else {
            return
        }
        guard health != entity.maxHealth else { return }
        entity.health = health
        entity.maxHealth = health
    }
}
