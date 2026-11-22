// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import Testing
@testable import GameCore

/// The default tables with one line's text replaced.
private func defaults(_ file: TableFile, replacing old: String, with new: String) -> TableTexts {
    var texts = TableTexts.defaults
    precondition(texts[file].contains(old), "\(old) is not in the default \(file.name)")
    texts[file] = texts[file].replacingOccurrences(of: old, with: new)
    return texts
}

/// The fault the tables give, if any.
private func fault(_ texts: TableTexts) -> TableError? {
    do {
        _ = try Catalogue(tables: texts)
        return nil
    } catch let error as TableError {
        return error
    } catch {
        Issue.record("not a table's fault: \(error)")
        return nil
    }
}

@Suite struct Tables {
    @Test func theDefaultsLoadAndAreTheStandardCatalogue() throws {
        let catalogue = try Catalogue(tables: .defaults)
        #expect(catalogue == Catalogue.standard)
        // A few figures, as the tables give them and as the simulation reads them.
        #expect(catalogue.stats(.worker).cost == ResourceAmounts([.food: 50]))
        #expect(catalogue.production(of: .worker, at: .townCentre)?.time == Tick.seconds(12))
        #expect(catalogue.stats(.spearman).attack == Attack(damage: 5, range: 1, interval: Tick.seconds(1.5)))
        #expect(catalogue.stats(.musketeer).attack?.interval == Tick.seconds(3))
        #expect(catalogue.stats(.horseman).attack?.interval == Tick.seconds(1.4))
        #expect(catalogue.stats(.cannon).attack?.area == 1.5)
        #expect(catalogue.stats(.townCentre).buildTime == Tick.seconds(120))
        #expect(catalogue.stats(.worker).gathers(.wood) == 0.6 && catalogue.stats(.worker).farming == 0.9)
        #expect(catalogue.stats(.boat).gathers(.food) == 0.7 && catalogue.stats(.boat).gathers(.wood) == 0)
        #expect(catalogue.advance(from: .farms)?.cost == ResourceAmounts([.food: 500, .gold: 250]))
        #expect(catalogue.advance(from: .cannons)?.time == Tick.seconds(250))
    }

    @Test func everyKindAndEveryAdvanceHasItsRows() throws {
        let catalogue = Catalogue.standard
        #expect(catalogue.units.map(\.kind) == UnitKind.allCases)
        #expect(catalogue.buildings.map(\.kind) == BuildingKind.allCases)
        #expect(catalogue.advances.map(\.from) == Array(Age.allCases.dropLast()))
        // Every unit but the car, which is summoned, has a maker; every maker is a building that makes it.
        for kind in UnitKind.allCases where kind != .car {
            #expect(!catalogue.stats(kind).trainedAt.isEmpty, "\(kind) has no maker")
        }
        for item in catalogue.production {
            #expect(catalogue.stats(item.maker).trains.contains(item.unit))
            #expect(item.age >= catalogue.stats(item.unit).age, "\(item.maker) makes \(item.unit) before its age")
        }
        // Each file names its columns in the order the documentation gives them.
        for (file, columns) in [(TableFile.stats, TableColumns.stats), (.production, TableColumns.production), (.ages, TableColumns.ages)] {
            #expect(try CSVTable(file: file.name, text: TableTexts.defaults[file]).header == columns, "\(file.name)")
        }
    }

    @Test func aBadCellIsReportedWithItsFileLineAndColumn() {
        // The spearman is the fifth line of stats.csv; health is its sixth column.
        let health = fault(defaults(.stats, replacing: "spearman,farms,60,0,20,55,", with: "spearman,farms,60,0,20,lots,"))
        #expect(health == TableError(file: "stats.csv", line: 5, column: 6,
                                     message: "\"lots\" is not a whole number of at least 0"))
        #expect(health?.description == "stats.csv, line 5, column 6: \"lots\" is not a whole number of at least 0")
        // An age that is not one, in production.csv's third column.
        let age = fault(defaults(.production, replacing: "barracks,spearman,farms,14", with: "barracks,spearman,bronze,14"))
        #expect(age?.file == "production.csv" && age?.line == 4 && age?.column == 3)
        // A negative duration in ages.csv's sixth column.
        let seconds = fault(defaults(.ages, replacing: "towns,farms,300,100,0,90", with: "towns,farms,300,100,0,-90"))
        #expect(seconds?.file == "ages.csv" && seconds?.line == 2 && seconds?.column == 6)
        // A kind the game does not have.
        let kind = fault(defaults(.stats, replacing: "house,towns", with: "hut,towns"))
        #expect(kind?.file == "stats.csv" && kind?.column == 1 && kind?.message.contains("hut") == true)
    }

    @Test func aMissingRowOrColumnIsAFault() {
        let row = fault(defaults(.stats, replacing: "farm,farms,0,60,0,150,,,,20,,,,,,,\n", with: ""))
        #expect(row?.file == "stats.csv" && row?.message == "the building farm has no row")
        let advance = fault(defaults(.ages, replacing: "ships,cannons,800,0,400,200\n", with: ""))
        #expect(advance?.file == "ages.csv" && advance?.message == "the advance from the age of ships has no row")
        let column = fault(defaults(.production, replacing: "maker,unit,age,seconds", with: "maker,unit,age,time"))
        #expect(column?.file == "production.csv" && column?.line == 1)
        let cells = fault(defaults(.production, replacing: "townCentre,worker,towns,12", with: "townCentre,worker,towns"))
        #expect(cells?.line == 2 && cells?.message == "3 cells where the header names 4")
        let empty = fault(TableTexts(stats: "", production: TableTexts.defaults.production, ages: TableTexts.defaults.ages))
        #expect(empty?.file == "stats.csv" && empty?.message == "the file is empty")
    }

    @Test func aTowersLaterRowIsItsUpgradeAndAHousesIsAFault() throws {
        var texts = TableTexts.defaults
        texts.stats += "watchTower,ships,0,100,0,600,6,0.5,8,40,,,,,,,\n"
        let tower = try Catalogue(tables: texts).stats(.watchTower)
        #expect(tower.age == .farms && tower.health == 400)
        #expect(tower.levels == [BuildingLevel(age: .ships, health: 600, attack: Attack(damage: 6, range: 8, interval: Tick.seconds(2)))])
        texts.stats += "house,farms,0,30,0,300,,,,20,,,,,,,\n"
        let house = fault(texts)
        #expect(house?.message == "house has a row already, on line 14")
    }

    @Test func cellsMayBeQuotedAndSpacedAndLinesEndInReturns() throws {
        let table = try CSVTable(file: "t.csv", text: "a, b ,\"c, d\"\r\n1,\" 2 \",\"say \"\"x\"\"\"\r\n\r\n")
        #expect(table.header == ["a", "b", "c, d"])
        #expect(table.rows.map(\.cells) == [["1", " 2 ", "say \"x\""]])
        #expect(table.rows.map(\.line) == [2])
        #expect(throws: TableError.self) { try CSVTable(file: "t.csv", text: "a\n\"open") }
    }

    @Test func theCatalogueTravelsWithTheSetupMessage() throws {
        var tuned = Catalogue.standard
        tuned.units[0].cost = ResourceAmounts([.food: 35])
        let start = MatchStart(player: PlayerID(1), mapWidth: 2, mapHeight: 1, terrain: [.grass, .grass], catalogue: tuned, speed: 1)
        let back = try JSONDecoder().decode(NetMessage.self, from: JSONEncoder().encode(NetMessage.start(start)))
        guard case .start(let received) = back else { Issue.record("not a start"); return }
        #expect(received.catalogue == tuned && received.catalogue != Catalogue.standard)
        #expect(NetMessage.protocolVersion == 2)
    }
}

@Suite struct Folder {
    private func temporary() -> TableFolder {
        TableFolder(folder: FileManager.default.temporaryDirectory.appendingPathComponent("tables-\(UUID().uuidString)"))
    }

    @Test func theFolderIsSeededOnceAndThenReadAsThePlayerLeftIt() throws {
        let folder = temporary()
        defer { try? FileManager.default.removeItem(at: folder.folder) }
        #expect(try folder.seed() == TableFile.allCases)
        #expect(try folder.seed().isEmpty)
        let first = folder.load()
        #expect(first.problem == nil && first.catalogue == Catalogue.standard)
        // The player makes workers cheaper; the next start plays by it.
        let stats = try String(contentsOf: folder.url(.stats), encoding: .utf8)
        try stats.replacingOccurrences(of: "worker,towns,50,", with: "worker,towns,40,")
            .write(to: folder.url(.stats), atomically: true, encoding: .utf8)
        let tuned = folder.load()
        #expect(tuned.problem == nil && tuned.catalogue.stats(.worker).cost == ResourceAmounts([.food: 40]))
        // A file taken away is seeded again from the defaults.
        try FileManager.default.removeItem(at: folder.url(.ages))
        #expect(folder.load().problem == nil)
        #expect(FileManager.default.fileExists(atPath: folder.url(.ages).path))
    }

    @Test func aFaultLeavesTheDefaultsInUseAndSaysWhere() throws {
        let folder = temporary()
        defer { try? FileManager.default.removeItem(at: folder.folder) }
        try folder.seed()
        try "from,to,food,wood,gold,seconds\ntowns,farms,300,100,0,soon\n".write(to: folder.url(.ages), atomically: true, encoding: .utf8)
        let loaded = folder.load()
        #expect(loaded.catalogue == Catalogue.standard)
        #expect(loaded.problem?.contains("ages.csv, line 2, column 6") == true, "\(loaded.problem ?? "")")
    }
}
