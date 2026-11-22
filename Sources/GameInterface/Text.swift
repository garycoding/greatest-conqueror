// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// The words the interface uses for things `GameCore` names only by case.
/// They live here, in a namespace of their own, so that no extension of a
/// shared type can collide with another module's.
public enum InterfaceText {
    public static func name(of improvement: Improvement) -> String {
        switch improvement {
        case .betterTools: "Better tools"
        case .bronzeWeapons: "Bronze weapons"
        case .shields: "Shields"
        case .ironTools: "Iron tools"
        case .ironWeapons: "Iron weapons"
        case .mail: "Mail"
        case .plough: "Plough"
        case .betterPowder: "Better powder"
        case .plateArmour: "Plate armour"
        case .guilds: "Guilds"
        case .banking: "Banking"
        case .machineTools: "Machine tools"
        case .rifling: "Rifling"
        case .steelPlate: "Steel plate"
        case .refining: "Refining"
        }
    }

    /// What an improvement does, for a tooltip.
    public static func effect(of improvement: Improvement) -> String {
        switch improvement {
        case .betterTools: "Workers gather faster."
        case .bronzeWeapons: "Warfighters strike harder."
        case .shields: "Warfighters take less harm."
        case .ironTools: "Workers gather faster still."
        case .ironWeapons: "Warfighters strike harder still."
        case .mail: "Warfighters take less harm still."
        case .plough: "Farms yield more."
        case .betterPowder: "Warfighters strike harder again."
        case .plateArmour: "Warfighters take much less harm."
        case .guilds: "Workers gather faster and workshops make more gunpowder."
        case .banking: "Merchants' exchanges give more."
        case .machineTools: "Workers gather faster and workshops make more gunpowder."
        case .rifling: "Warfighters strike much harder."
        case .steelPlate: "Warfighters take less harm again."
        case .refining: "Oil wells pump more."
        }
    }

    /// An amount of resources as "50 Food, 10 Wood"; "Free" when it is zero.
    public static func cost(_ amounts: ResourceAmounts) -> String {
        let parts = Resource.allCases.filter { amounts[$0] != 0 }.map { "\(amounts[$0]) \($0.name)" }
        return parts.isEmpty ? "Free" : parts.joined(separator: ", ")
    }

    public static func name(of site: SiteKind) -> String {
        switch site {
        case .tree: "wood"
        case .prey: "prey"
        case .stone: "stone"
        case .copper: "copper"
        case .tin: "tin"
        case .gold: "gold"
        case .iron: "iron"
        case .oilField: "oil"
        case .fish: "fish"
        }
    }

    /// The name of an entity's kind at the age of its owner.
    public static func name(of kind: EntityKind, at age: Age) -> String {
        switch kind {
        case .unit(let unit): unit.stageName(at: age)
        case .building(let building): building.name
        }
    }

    /// What an entity is doing, in words, and its progress from 0 to 1 where it has one.
    public static func describe(_ activity: Activity, of kind: EntityKind, age: Age) -> (text: String, progress: Double?) {
        switch activity {
        case .idle:
            return ("Idle", nil)
        case .moving:
            return ("Walking", nil)
        case .gathering(let site):
            switch site {
            case .prey: return ("Hunting", nil)
            case .tree: return ("Felling trees", nil)
            case .oilField: return ("Pumping oil", nil)
            default: return ("Mining \(name(of: site))", nil)
            }
        case .carrying(let resource, let amount):
            return ("Carrying \(amount) \(resource.name)", nil)
        case .working:
            if case .unit(let unit) = kind {
                switch unit {
                case .worker: return ("Tending a stock pen", nil)
                case .scholar: return ("Studying", nil)
                case .engineer: return ("Repairing", nil)
                default: break
                }
            }
            return ("Working", nil)
        case .constructing:
            return ("Building", nil)
        case .fighting:
            return ("Fighting", nil)
        case .underConstruction(let progress):
            return ("Under construction", clamp(progress))
        case .training(let unit, let progress, let queued):
            let more = queued > 1 ? ", \(queued) queued" : ""
            return ("Training \(unit.stageName(at: age))\(more)", clamp(progress))
        case .researching(let improvement, let progress):
            return ("Researching \(name(of: improvement))", clamp(progress))
        }
    }

    public static func name(of difficulty: Difficulty) -> String {
        switch difficulty {
        case .easy: "Easy"
        case .standard: "Standard"
        case .hard: "Hard"
        }
    }

    /// The civilization of a seat whose person has not chosen yet.
    public static let choosing = "choosing\u{2026}"

    /// A speed as "2×" or "1.5×".
    public static func speed(_ speed: Double) -> String {
        let rounded = (speed * 100).rounded() / 100
        let digits = rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
        return "\(digits)\u{00D7}"
    }

    /// Names as "Ana", "Ana and Ben", or "Ana, Ben and Cy".
    public static func list(_ names: [String]) -> String {
        guard let last = names.last else { return "" }
        if names.count == 1 { return last }
        return names.dropLast().joined(separator: ", ") + " and " + last
    }

    static func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
}
