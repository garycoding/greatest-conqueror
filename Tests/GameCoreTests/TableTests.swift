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
        #expect(catalogue.stats(.soldier1).attack == Attack(damage: 5, range: 1, interval: Tick.seconds(1.5)))
        #expect(catalogue.stats(.soldier3).attack?.interval == Tick.seconds(3))
        #expect(catalogue.stats(.knight1).attack?.interval == Tick.seconds(1.4))
        #expect(catalogue.stats(.cannon1).attack?.area == 1.5)
        #expect(catalogue.stats(.townCentre).buildTime == Tick.seconds(120))
        #expect(catalogue.stats(.worker).gathers(.wood) == 0.6 && catalogue.stats(.worker).farming == 0.9)
        #expect(catalogue.stats(.fishingBoat).gathers(.food) == 0.7 && catalogue.stats(.fishingBoat).gathers(.wood) == 0)
        #expect(catalogue.advance(from: .farms)?.cost == ResourceAmounts([.food: 500, .gold: 250]))
        #expect(catalogue.advance(from: .cannons)?.time == Tick.seconds(250))
        // Repair, healing and the radius of the idle search (requirements 12 and 13).
        #expect(catalogue.stats(.worker).repairing == 5 && catalogue.stats(.worker).radius == 6)
        #expect(catalogue.stats(.doctor).healing == 3 && catalogue.stats(.doctor).radius == 6)
        #expect(catalogue.stats(.doctor).attack == nil)
        // The ages of the buildings (requirement 10).
        #expect([BuildingKind.boatHouse, .barracks, .tower, .farm].allSatisfy { catalogue.stats($0).age == .farms })
        #expect([BuildingKind.stable, .castle].allSatisfy { catalogue.stats($0).age == .ships })
        #expect(catalogue.stats(.cannonFactory).age == .cannons && catalogue.stats(.hospital).age == .hospitals)
        // The makers of requirement 17, the navy ship among them.
        #expect(catalogue.production(of: .cannon1, at: .cannonFactory)?.age == .cannons)
        #expect(catalogue.production(of: .cannon1, at: .castle)?.age == .cannons)
        #expect(catalogue.production(of: .navyShip, at: .boatHouse)?.age == .ships)
        #expect(catalogue.production(of: .doctor, at: .hospital)?.age == .hospitals)
        #expect(catalogue.production(of: .knight3, at: .unit(.navyShip))?.age == .hospitals)
        // Every later age's upgrade of the tower, the castle and the navy ship (requirement 24).
        #expect(catalogue.stats(.tower).levels.map(\.age) == [.ships, .cannons, .hospitals])
        #expect(catalogue.stats(.castle).levels.map(\.age) == [.cannons, .hospitals])
        #expect(catalogue.stats(.navyShip).levels.map(\.age) == [.cannons, .hospitals])
        #expect(catalogue.stats(.navyShip).figures(at: .hospitals).health == 700)
        #expect(catalogue.stats(.navyShip).figures(at: .ships).attack?.range == 7)
    }

    @Test func theTiersOfEachAgeAndEveryEarlierTierAreMade() {
        let c = Catalogue.standard
        func made(at maker: BuildingKind, by age: Age) -> Set<UnitKind> {
            Set(c.made(by: .building(maker)).filter { $0.age <= age }.map(\.unit))
        }
        #expect(made(at: .barracks, by: .farms) == [.soldier1])
        #expect(made(at: .barracks, by: .hospitals) == [.soldier1, .soldier2, .soldier3, .soldier4])
        #expect(made(at: .stable, by: .hospitals) == [.knight1, .knight2, .knight3])
        #expect(made(at: .castle, by: .ships) == [.soldier1, .soldier2, .knight1])
        #expect(made(at: .cannonFactory, by: .hospitals) == [.cannon1, .cannon2])
        #expect(c.made(by: .unit(.navyShip)).allSatisfy { $0.unit.isWarfighter && $0.age == .hospitals })
        #expect(c.made(by: .unit(.navyShip)).count == 9)
    }

    @Test func everyKindAndEveryAdvanceHasItsRows() throws {
        let catalogue = Catalogue.standard
        #expect(catalogue.units.map(\.kind) == UnitKind.allCases)
        #expect(catalogue.buildings.map(\.kind) == BuildingKind.allCases)
        #expect(catalogue.advances.map(\.from) == Array(Age.allCases.dropLast()))
        // Every unit has a maker (the car and the founder are not units); every
        // maker, a building or the navy ship, lists what it makes.
        for kind in UnitKind.allCases {
            #expect(catalogue.stats(kind).trainedAt.isEmpty != kind.isUnit, "\(kind)")
        }
        for item in catalogue.production {
            switch item.maker {
            case .building(let kind): #expect(catalogue.stats(kind).trains.contains(item.unit))
            case .unit(let kind): #expect(catalogue.stats(kind).trains.contains(item.unit))
            }
            #expect(catalogue.stats(item.unit).trainedAt.contains(item.maker))
            #expect(item.age >= catalogue.stats(item.unit).age, "\(item.maker) makes \(item.unit) before its age")
        }
        // Each file names its columns in the order the documentation gives them.
        for (file, columns) in [(TableFile.stats, TableColumns.stats), (.production, TableColumns.production), (.ages, TableColumns.ages)] {
            #expect(try CSVTable(file: file.name, text: TableTexts.defaults[file]).header == columns, "\(file.name)")
        }
    }

    @Test func aBadCellIsReportedWithItsFileLineAndColumn() {
        // Soldier 1 is the fifth line of stats.csv; health is its sixth column.
        let health = fault(defaults(.stats, replacing: "soldier1,farms,60,0,20,55,", with: "soldier1,farms,60,0,20,lots,"))
        #expect(health == TableError(file: "stats.csv", line: 5, column: 6,
                                     message: "\"lots\" is not a whole number of at least 0"))
        #expect(health?.description == "stats.csv, line 5, column 6: \"lots\" is not a whole number of at least 0")
        // An age that is not one, in production.csv's third column.
        let age = fault(defaults(.production, replacing: "barracks,soldier1,farms,14", with: "barracks,soldier1,bronze,14"))
        #expect(age?.file == "production.csv" && age?.line == 5 && age?.column == 3)
        // A maker that makes nothing: the founder.
        let maker = fault(defaults(.production, replacing: "hospital,doctor,", with: "founder,doctor,"))
        #expect(maker?.file == "production.csv" && maker?.column == 1)
        // A negative duration in ages.csv's sixth column.
        let seconds = fault(defaults(.ages, replacing: "towns,farms,300,100,0,90", with: "towns,farms,300,100,0,-90"))
        #expect(seconds?.file == "ages.csv" && seconds?.line == 2 && seconds?.column == 6)
        // A kind the game does not have.
        let kind = fault(defaults(.stats, replacing: "house,towns", with: "hut,towns"))
        #expect(kind?.file == "stats.csv" && kind?.column == 1 && kind?.message.contains("hut") == true)
    }

    @Test func aMissingRowOrColumnIsAFault() {
        let row = fault(defaults(.stats, replacing: "farm,farms,0,60,0,150,,,,20,10,0.5,,,,,,,\n", with: ""))
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

    @Test func demolitionIsReadFromItsColumnsAndChecked() throws {
        let farm = try Catalogue(tables: defaults(.stats, replacing: "farm,farms,0,60,0,150,,,,20,10,0.5,",
                                                  with: "farm,farms,0,60,0,150,,,,20,4,0.25,")).stats(.farm)
        #expect(farm.demolishTime == Tick.seconds(4) && farm.demolishReturn == 0.25)
        #expect(ResourceAmounts([.wood: 60, .gold: 3]).share(0.25) == ResourceAmounts([.wood: 15]))
        let tooMuch = fault(defaults(.stats, replacing: "farm,farms,0,60,0,150,,,,20,10,0.5,", with: "farm,farms,0,60,0,150,,,,20,10,1.5,"))
        #expect(tooMuch?.file == "stats.csv" && tooMuch?.line == 27 && tooMuch?.column == 12)
        let missing = fault(defaults(.stats, replacing: "farm,farms,0,60,0,150,,,,20,10,0.5,", with: "farm,farms,0,60,0,150,,,,20,,0.5,"))
        #expect(missing?.column == 11 && missing?.message == "a building needs demolish_seconds")
        let unit = fault(defaults(.stats, replacing: "worker,towns,50,0,0,25,3,0.6667,1,,,,", with: "worker,towns,50,0,0,25,3,0.6667,1,,5,,"))
        #expect(unit?.line == 2 && unit?.column == 11)
    }

    @Test func aTowersOrAShipsLaterRowIsItsUpgradeAndAHousesIsAFault() throws {
        let catalogue = Catalogue.standard
        let tower = catalogue.stats(.tower)
        #expect(tower.age == .farms && tower.health == 400)
        #expect(tower.levels[0] == AgeUpgrade(age: .ships, health: 550, attack: Attack(damage: 5, range: 7.5, interval: Tick.seconds(2))))
        #expect(tower.figures(at: .farms) == AgeFigures(health: 400, attack: tower.attack))
        #expect(tower.figures(at: .hospitals).health == 850)
        let ship = catalogue.stats(.navyShip)
        #expect(ship.age == .ships && ship.health == 400 && ship.levels.count == 2)
        var texts = TableTexts.defaults
        texts.stats += "tower,ships,0,100,0,600,6,0.5,8,40,,,,,,,,,\n"
        #expect(fault(texts)?.message.contains("tower has a row for the age of ships") == true)
        texts = TableTexts.defaults
        texts.stats += "house,farms,0,30,0,300,,,,20,10,0.5,,,,,,,\n"
        #expect(fault(texts)?.message == "house has a row already, on line 20")
        texts = TableTexts.defaults
        texts.stats += "doctor,hospitals,50,0,30,40,,,,,,,,,,,3,,6\n"
        #expect(fault(texts)?.message == "doctor has a row already, on line 3")
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
        #expect(NetMessage.protocolVersion == 4)
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
