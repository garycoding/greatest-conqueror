// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The catalogue built from the three tables (docs/requirements.md, requirement
// 25): `stats.csv`, `production.csv` and `ages.csv`. The defaults are the
// package's own copies of the files (`Tables/` in this module), which the app
// copies into the player's folder the first time it runs.

/// The three files of the tables.
public enum TableFile: String, CaseIterable, Hashable, Sendable {
    case stats = "stats.csv"
    case production = "production.csv"
    case ages = "ages.csv"

    public var name: String { rawValue }
}

/// The text of the three tables, by file.
public struct TableTexts: Hashable, Sendable {
    public var stats: String
    public var production: String
    public var ages: String

    public init(stats: String, production: String, ages: String) {
        self.stats = stats; self.production = production; self.ages = ages
    }

    public subscript(file: TableFile) -> String {
        get {
            switch file {
            case .stats: stats
            case .production: production
            case .ages: ages
            }
        }
        set {
            switch file {
            case .stats: stats = newValue
            case .production: production = newValue
            case .ages: ages = newValue
            }
        }
    }

    /// The defaults, as the package holds them.
    public static let defaults: TableTexts = {
        func read(_ file: TableFile) -> String {
            guard let url = Bundle.module.url(forResource: file.rawValue, withExtension: nil, subdirectory: "Tables"),
                  let text = try? String(contentsOf: url, encoding: .utf8) else {
                preconditionFailure("the default \(file.rawValue) is missing from the package")
            }
            return text
        }
        return TableTexts(stats: read(.stats), production: read(.production), ages: read(.ages))
    }()
}

extension Catalogue {
    /// The catalogue the tables describe, on the shape of `CatalogueShape`
    /// (the figures the tables do not hold). Throws the first fault found,
    /// naming its file, line and column.
    public init(tables: TableTexts) throws {
        let stats = try CSVTable(file: TableFile.stats.name, text: tables.stats)
        let production = try CSVTable(file: TableFile.production.name, text: tables.production)
        let ages = try CSVTable(file: TableFile.ages.name, text: tables.ages)
        self = try TableReader.catalogue(stats: stats, production: production, ages: ages)
    }
}

/// The columns of each table, by name, in the order the defaults give them;
/// a table may give them in any order.
public enum TableColumns {
    public static let stats = ["kind", "age", "food", "wood", "gold", "health", "damage", "hits_per_second", "range",
                               "build_seconds", "demolish_seconds", "demolish_return", "gather_food", "gather_wood", "gather_gold", "farm_food",
                               "heal_per_second", "repair_per_second", "radius"]
    public static let production = ["maker", "unit", "age", "seconds"]
    public static let ages = ["from", "to", "food", "wood", "gold", "seconds"]
}

/// Reads the cells of a table by column name, with errors that name the cell.
struct CellReader {
    let table: CSVTable
    let index: [String: Int]

    init(_ table: CSVTable, columns: [String]) throws {
        self.table = table
        var index: [String: Int] = [:]
        for (i, name) in table.header.enumerated() {
            if index[name] != nil {
                throw TableError(file: table.file, line: 1, column: i + 1, message: "the column \"\(name)\" is named twice")
            }
            index[name] = i
        }
        for name in columns where index[name] == nil {
            throw TableError(file: table.file, line: 1, column: 0, message: "the column \"\(name)\" is missing")
        }
        for (i, name) in table.header.enumerated() where !columns.contains(name) {
            throw TableError(file: table.file, line: 1, column: i + 1, message: "\"\(name)\" is not a column of this table")
        }
        self.index = index
    }

    func fault(_ row: CSVTable.Row, _ column: String, _ message: String) -> TableError {
        TableError(file: table.file, line: row.line, column: (index[column] ?? -1) + 1, message: message)
    }

    func text(_ row: CSVTable.Row, _ column: String) -> String { row.cells[index[column]!] }

    func isEmpty(_ row: CSVTable.Row, _ column: String) -> Bool { text(row, column).isEmpty }

    /// A whole number of at least zero; an empty cell is `empty`, or a fault where `empty` is nil.
    func count(_ row: CSVTable.Row, _ column: String, empty: Int? = nil) throws -> Int {
        let cell = text(row, column)
        if cell.isEmpty {
            guard let empty else { throw fault(row, column, "\(column) is empty") }
            return empty
        }
        guard let value = Int(cell), value >= 0 else { throw fault(row, column, "\"\(cell)\" is not a whole number of at least 0") }
        return value
    }

    /// A number of at least zero, or nil for an empty cell.
    func number(_ row: CSVTable.Row, _ column: String) throws -> Double? {
        let cell = text(row, column)
        if cell.isEmpty { return nil }
        guard let value = Double(cell), value.isFinite, value >= 0 else {
            throw fault(row, column, "\"\(cell)\" is not a number of at least 0")
        }
        return value
    }

    /// A number greater than zero, or nil for an empty cell.
    func positive(_ row: CSVTable.Row, _ column: String) throws -> Double? {
        guard let value = try number(row, column) else { return nil }
        guard value > 0 else { throw fault(row, column, "\(column) must be greater than 0") }
        return value
    }

    func age(_ row: CSVTable.Row, _ column: String) throws -> Age {
        let cell = text(row, column)
        guard let age = Age.allCases.first(where: { $0.name == cell }) else {
            throw fault(row, column, "\"\(cell)\" is not an age (\(Age.allCases.map(\.name).joined(separator: ", ")))")
        }
        return age
    }

    func resources(_ row: CSVTable.Row) throws -> ResourceAmounts {
        var amounts = ResourceAmounts()
        for resource in Resource.allCases { amounts[resource] = try count(row, resource.machineName, empty: 0) }
        return amounts
    }
}

extension Resource {
    /// The resource's name in the tables' columns.
    public var machineName: String {
        switch self {
        case .food: "food"
        case .wood: "wood"
        case .gold: "gold"
        }
    }
}

extension UnitKind {
    /// The kind's name in the tables: its name in the code, `worker` or `fieldGun`.
    public var machineName: String { "\(self)" }
}

extension BuildingKind {
    /// The kind's name in the tables: its name in the code, `townCentre` or `boatHouse`.
    public var machineName: String { "\(self)" }
}

enum TableReader {
    static func catalogue(stats: CSVTable, production: CSVTable, ages: CSVTable) throws -> Catalogue {
        let shape = CatalogueShape.standard
        let s = try CellReader(stats, columns: TableColumns.stats)
        var units: [UnitKind: UnitStats] = [:], buildings: [BuildingKind: BuildingStats] = [:]
        var unitLines: [UnitKind: Int] = [:], buildingLines: [BuildingKind: Int] = [:]
        for row in stats.rows {
            let name = s.text(row, "kind")
            let age = try s.age(row, "age")
            let cost = try s.resources(row)
            let health = try s.count(row, "health")
            guard health > 0 else { throw s.fault(row, "health", "health must be at least 1") }
            var attack: Attack?
            if !s.isEmpty(row, "damage") || !s.isEmpty(row, "hits_per_second") || !s.isEmpty(row, "range") {
                let damage = try s.count(row, "damage")
                guard let hits = try s.positive(row, "hits_per_second") else {
                    throw s.fault(row, "hits_per_second", "an attacker needs hits_per_second")
                }
                guard let range = try s.number(row, "range") else { throw s.fault(row, "range", "an attacker needs a range") }
                attack = Attack(damage: damage, range: range, interval: max(1, Tick.seconds(1 / hits)))
            }
            if let kind = UnitKind.allCases.first(where: { $0.machineName == name }) {
                if let line = unitLines[kind], let base = units[kind] {
                    // A navy ship's later row is its upgrade in that age.
                    guard kind.isUpgradedWithAge else {
                        throw s.fault(row, "kind", "\(name) has a row already, on line \(line)")
                    }
                    guard age > base.age, !base.levels.contains(where: { $0.age == age }) else {
                        throw s.fault(row, "age", "\(name) has a row for the age of \(age.name) or an earlier one already, on line \(line)")
                    }
                    units[kind]?.levels.append(AgeUpgrade(age: age, health: health, attack: attack))
                    units[kind]?.levels.sort { $0.age < $1.age }
                    continue
                }
                unitLines[kind] = row.line
                for column in ["build_seconds", "demolish_seconds", "demolish_return"] where !s.isEmpty(row, column) {
                    throw s.fault(row, column, "a unit is not built or demolished")
                }
                let unitShape = shape.unit(kind)
                if var a = attack { a.area = unitShape.area; attack = a }
                var gathering = [Double](repeating: 0, count: Resource.allCases.count)
                for resource in Resource.allCases {
                    gathering[resource.rawValue] = try s.number(row, "gather_" + resource.machineName) ?? 0
                }
                units[kind] = UnitStats(kind: kind, age: age, cost: cost, health: health, armour: unitShape.armour,
                                        speed: unitShape.speed, sight: unitShape.sight, attack: attack, trainedAt: [],
                                        population: unitShape.population, gathering: gathering,
                                        farming: try s.number(row, "farm_food") ?? 0,
                                        healing: try s.number(row, "heal_per_second"),
                                        repairing: try s.number(row, "repair_per_second"),
                                        radius: try s.number(row, "radius"))
            } else if let kind = BuildingKind.allCases.first(where: { $0.machineName == name }) {
                if let line = buildingLines[kind], let base = buildings[kind] {
                    // A tower's or a castle's later row is its upgrade in that age.
                    guard kind.isUpgradedWithAge else {
                        throw s.fault(row, "kind", "\(name) has a row already, on line \(line)")
                    }
                    guard age > base.age, !base.levels.contains(where: { $0.age == age }) else {
                        throw s.fault(row, "age", "\(name) has a row for the age of \(age.name) or an earlier one already, on line \(line)")
                    }
                    if var a = attack { a.area = nil; attack = a }
                    buildings[kind]?.levels.append(AgeUpgrade(age: age, health: health, attack: attack))
                    buildings[kind]?.levels.sort { $0.age < $1.age }
                    continue
                }
                buildingLines[kind] = row.line
                guard let seconds = try s.positive(row, "build_seconds") else {
                    throw s.fault(row, "build_seconds", "a building needs build_seconds")
                }
                guard let demolishSeconds = try s.positive(row, "demolish_seconds") else {
                    throw s.fault(row, "demolish_seconds", "a building needs demolish_seconds")
                }
                guard let demolishReturn = try s.number(row, "demolish_return") else {
                    throw s.fault(row, "demolish_return", "a building needs demolish_return")
                }
                guard demolishReturn <= 1 else {
                    throw s.fault(row, "demolish_return", "demolish_return must be at most 1")
                }
                for column in ["gather_food", "gather_wood", "gather_gold", "farm_food", "heal_per_second", "repair_per_second", "radius"]
                where !s.isEmpty(row, column) {
                    throw s.fault(row, column, "a building does not have \(column)")
                }
                let buildingShape = shape.building(kind)
                buildings[kind] = BuildingStats(kind: kind, age: age, cost: cost, buildTime: max(1, Tick.seconds(seconds)),
                                                demolishTime: max(1, Tick.seconds(demolishSeconds)),
                                                demolishReturn: demolishReturn,
                                                health: health, armour: buildingShape.armour,
                                                footprint: buildingShape.footprint, sight: buildingShape.sight,
                                                attack: attack, housing: buildingShape.housing,
                                                accepts: buildingShape.accepts)
            } else {
                throw s.fault(row, "kind", "\"\(name)\" is not a kind of unit or building")
            }
        }
        for kind in UnitKind.allCases where units[kind] == nil {
            throw TableError(file: stats.file, line: stats.rows.last.map { $0.line + 1 } ?? 2, column: 0,
                             message: "the unit \(kind.machineName) has no row")
        }
        for kind in BuildingKind.allCases where buildings[kind] == nil {
            throw TableError(file: stats.file, line: stats.rows.last.map { $0.line + 1 } ?? 2, column: 0,
                             message: "the building \(kind.machineName) has no row")
        }

        let p = try CellReader(production, columns: TableColumns.production)
        var made: [ProductionStats] = []
        for row in production.rows {
            let makerName = p.text(row, "maker")
            let maker: EntityKind
            if let building = BuildingKind.allCases.first(where: { $0.machineName == makerName }) {
                maker = .building(building)
            } else if let unit = UnitKind.allCases.first(where: { $0.machineName == makerName }), unit.isUnit {
                maker = .unit(unit)
            } else {
                throw p.fault(row, "maker", "\"\(makerName)\" is not a kind of building or of unit")
            }
            guard let unit = UnitKind.allCases.first(where: { $0.machineName == p.text(row, "unit") }) else {
                throw p.fault(row, "unit", "\"\(p.text(row, "unit"))\" is not a kind of unit")
            }
            guard unit.isUnit else { throw p.fault(row, "unit", "no maker makes a \(unit.machineName)") }
            if made.contains(where: { $0.maker == maker && $0.unit == unit }) {
                throw p.fault(row, "unit", "\(makerName) makes \(unit.machineName) on an earlier line already")
            }
            let age = try p.age(row, "age")
            guard let seconds = try p.positive(row, "seconds") else { throw p.fault(row, "seconds", "seconds is empty") }
            made.append(ProductionStats(maker: maker, unit: unit, age: age, time: max(1, Tick.seconds(seconds))))
        }
        for item in made {
            units[item.unit]?.trainedAt.append(item.maker)
            switch item.maker {
            case .building(let kind): buildings[kind]?.trains.append(item.unit)
            case .unit(let kind): units[kind]?.trains.append(item.unit)
            }
        }

        let a = try CellReader(ages, columns: TableColumns.ages)
        var advances: [AdvanceStats] = []
        for row in ages.rows {
            let from = try a.age(row, "from"), to = try a.age(row, "to")
            guard to == from.next else { throw a.fault(row, "to", "the age after \(from.name) is \(from.next?.name ?? "none")") }
            if advances.contains(where: { $0.from == from }) {
                throw a.fault(row, "from", "the advance from \(from.name) has a row already")
            }
            guard let seconds = try a.positive(row, "seconds") else { throw a.fault(row, "seconds", "seconds is empty") }
            advances.append(AdvanceStats(from: from, cost: try a.resources(row), time: max(1, Tick.seconds(seconds))))
        }
        for age in Age.allCases.dropLast() where !advances.contains(where: { $0.from == age }) {
            throw TableError(file: ages.file, line: ages.rows.last.map { $0.line + 1 } ?? 2, column: 0,
                             message: "the advance from the age of \(age.name) has no row")
        }
        advances.sort { $0.from < $1.from }

        return Catalogue(units: UnitKind.allCases.map { units[$0]! }, buildings: BuildingKind.allCases.map { buildings[$0]! },
                         production: made, advances: advances, gathering: shape.gathering, bonuses: shape.bonuses,
                         startingResources: shape.startingResources, startingPeople: shape.startingPeople,
                         founderPeople: shape.founderPeople, shipCargo: shape.shipCargo, populationMaximum: shape.populationMaximum, car: shape.car)
    }
}
