// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import Testing
@testable import GameCore

/// The tables as one zip file (requirement 28).
@Suite struct TableZipTests {
    private func scratch(_ name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("zip-test-\(UUID().uuidString)-\(name)")
    }

    @Test func aZipRoundTrips() throws {
        var texts = TableTexts.defaults
        texts.ages = texts.ages.replacingOccurrences(of: "towns,farms,300,100,0,90", with: "towns,farms,310,100,0,95")
        let zip = scratch("tables.zip")
        defer { try? FileManager.default.removeItem(at: zip) }
        try TableZip.write(texts, to: zip)
        #expect(FileManager.default.fileExists(atPath: zip.path))
        let back = try TableZip.read(from: zip)
        #expect(back == texts)
        #expect(try Catalogue(tables: back).advance(from: .towns)?.cost[.food] == 310)
        // Written again over the same file, it is replaced.
        try TableZip.write(.defaults, to: zip)
        #expect(try TableZip.read(from: zip) == .defaults)
    }

    @Test func aZipOfAFolderIsReadAndAZipWithoutAFileIsRefused() throws {
        // A zip the Finder makes of a folder holds the files one folder down.
        let folder = scratch("Tables")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        for file in TableFile.allCases {
            try TableTexts.defaults[file].write(to: folder.appendingPathComponent(file.name), atomically: true, encoding: .utf8)
        }
        let zip = scratch("folder.zip")
        defer { try? FileManager.default.removeItem(at: zip) }
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", folder.path, zip.path]
        try ditto.run(); ditto.waitUntilExit()
        #expect(try TableZip.read(from: zip) == .defaults)

        try FileManager.default.removeItem(at: folder.appendingPathComponent(TableFile.ages.name))
        try FileManager.default.removeItem(at: zip)
        let short = Process()
        short.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        short.arguments = ["-c", "-k", folder.path, zip.path]
        try short.run(); short.waitUntilExit()
        #expect(throws: TableZip.Problem("The zip holds no ages.csv.")) { try TableZip.read(from: zip) }
        // Something that is not a zip at all.
        let text = scratch("not.zip")
        try "not a zip".write(to: text, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: text) }
        #expect(throws: TableZip.Problem.self) { try TableZip.read(from: text) }
    }

    @Test func theFolderIsWrittenWithEveryFile() throws {
        let folder = TableFolder(folder: scratch("folder"))
        defer { try? FileManager.default.removeItem(at: folder.folder) }
        var texts = TableTexts.defaults
        texts.stats += "\n"
        try folder.write(texts)
        for file in TableFile.allCases { #expect(try String(contentsOf: folder.url(file), encoding: .utf8) == texts[file]) }
        #expect(folder.load().texts == texts && folder.load().problem == nil)
    }
}
