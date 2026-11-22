// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// The words the interface uses for things `GameCore` names only by case.
/// They live here, in a namespace of their own, so that no extension of a
/// shared type can collide with another module's.
public enum InterfaceText {
    /// An amount of resources as "50 Food, 10 Wood"; "Free" when it is zero.
    public static func cost(_ amounts: ResourceAmounts) -> String {
        let parts = Resource.allCases.filter { amounts[$0] != 0 }.map { "\(amounts[$0]) \($0.name)" }
        return parts.isEmpty ? "Free" : parts.joined(separator: ", ")
    }

    public static func name(of site: SiteKind) -> String {
        switch site {
        case .tree: "wood"
        case .prey: "prey"
        case .gold: "gold"
        case .fish: "fish"
        }
    }

    /// The name of an entity at the age of its owner. A worker's name follows
    /// its work: gatherer, hunter, farmer, lumberjack, miner, builder or
    /// repairer; idle, walking or demolishing, it is a worker.
    public static func name(of entity: EntityView, at age: Age) -> String {
        guard entity.kind == .unit(.worker) else { return name(of: entity.kind, at: age) }
        if let job = entity.job {
            switch job {
            case .gathering(let site): return workerName(gathering: site)
            case .working(.farm): return "Farmer"
            case .constructing: return "Builder"
            case .repairing: return "Repairer"
            default: return "Worker"
            }
        }
        switch entity.activity {
        case .gathering(let site): return workerName(gathering: site)
        case .carrying(let resource, _): return resource == .wood ? "Lumberjack" : resource == .gold ? "Miner" : "Worker"
        case .constructing: return "Builder"
        default: return "Worker"
        }
    }

    static func workerName(gathering site: SiteKind) -> String {
        switch site {
        case .tree: "Lumberjack"
        case .prey: "Hunter"
        case .gold: "Miner"
        case .fish: "Gatherer"
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
            default: return ("Mining \(name(of: site))", nil)
            }
        case .carrying(let resource, let amount):
            return ("Carrying \(amount) \(resource.name)", nil)
        case .working:
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
        case .advancing(let progress):
            return ("Advancing to the next age", clamp(progress))
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
