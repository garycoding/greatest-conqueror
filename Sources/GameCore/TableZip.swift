// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// The tables' files as one zip file (requirement 28), made and read by the
/// system's own `ditto`, so that the game needs nothing more. A zip is
/// written with every file of the tables at its top; one is read wherever in
/// it the files lie, so that a zip the Finder made of a folder is read too.
public enum TableZip {
    /// Why a zip could not be made or read, in words for the player.
    public struct Problem: Error, Hashable, Sendable, CustomStringConvertible {
        public var message: String
        public init(_ message: String) { self.message = message }
        public var description: String { message }
    }

    /// Writes the files of the tables into a zip file at `url`, replacing any file there.
    public static func write(_ texts: TableTexts, to url: URL) throws {
        let folder = try scratchFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        for file in TableFile.allCases {
            try texts[file].write(to: folder.appendingPathComponent(file.name), atomically: true, encoding: .utf8)
        }
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        try ditto(["-c", "-k", folder.path, url.path])
    }

    /// Reads the files of the tables from a zip file; each must be there. It
    /// does not check them: the caller reads them with `Catalogue(tables:)`,
    /// as at start-up.
    public static func read(from url: URL) throws -> TableTexts {
        let folder = try scratchFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try ditto(["-x", "-k", url.path, folder.path])
        var found: [TableFile: URL] = [:]
        let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)
        while let item = walker?.nextObject() as? URL {
            // The Finder's zips carry a shadow folder of resource forks, which holds no tables.
            if item.lastPathComponent == "__MACOSX" { walker?.skipDescendants(); continue }
            guard let file = TableFile(rawValue: item.lastPathComponent) else { continue }
            if found[file] != nil { throw Problem("The zip holds more than one \(file.name).") }
            found[file] = item
        }
        var texts = TableTexts.defaults
        for file in TableFile.allCases {
            guard let item = found[file] else { throw Problem("The zip holds no \(file.name).") }
            do {
                texts[file] = try String(contentsOf: item, encoding: .utf8)
            } catch {
                throw Problem("\(file.name) in the zip could not be read as text.")
            }
        }
        return texts
    }

    private static func scratchFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("tables-zip-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private static func ditto(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        let errors = Pipe()
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let said = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw Problem(said.isEmpty ? "The zip could not be made or read." : "The zip could not be made or read: \(said)")
        }
    }
}
