// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// The folder where the player keeps the tables (requirement 26):
/// `~/Library/Application Support/Greatest Conqueror`, beside the automatic
/// saves. The app seeds it from the defaults the first time it runs, a file at
/// a time, and reads the tables from it at every start.
public struct TableFolder: Sendable {
    public let folder: URL

    /// The player's folder, or another (for tests).
    public init(folder: URL? = nil) {
        self.folder = folder ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Greatest Conqueror", isDirectory: true)
    }

    public func url(_ file: TableFile) -> URL { folder.appendingPathComponent(file.name) }

    /// Writes the default of each file the folder lacks, leaving the others as
    /// the player left them. Returns the files written.
    @discardableResult
    public func seed(with defaults: TableTexts = .defaults) throws -> [TableFile] {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var written: [TableFile] = []
        for file in TableFile.allCases where !FileManager.default.fileExists(atPath: url(file).path) {
            try defaults[file].write(to: url(file), atomically: true, encoding: .utf8)
            written.append(file)
        }
        return written
    }

    /// What loading the tables gave: the catalogue to play by, and, where the
    /// folder's tables could not be used, why, in words for the player.
    public struct Loaded: Sendable {
        public var catalogue: Catalogue
        /// The texts the catalogue was read from: the folder's, or the defaults where those could not be used.
        public var texts: TableTexts
        public var problem: String?
    }

    /// Writes every file of the tables into the folder, replacing its files (the
    /// editor's Apply, and a zip loaded; requirements 27 and 28).
    public func write(_ texts: TableTexts) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for file in TableFile.allCases { try texts[file].write(to: url(file), atomically: true, encoding: .utf8) }
    }

    /// Seeds the folder and reads its tables. A file that is missing, cannot be
    /// read or holds a fault leaves the default tables in use, every file of them, and
    /// the fault is reported with its file, line and column.
    public func load(defaults: TableTexts = .defaults) -> Loaded {
        func fallback(_ why: String) -> Loaded {
            let catalogue = (try? Catalogue(tables: defaults)) ?? .standard
            return Loaded(catalogue: catalogue, texts: defaults,
                          problem: "The tables in \(folder.path) could not be used, so the game plays by its own: \(why)")
        }
        do {
            try seed(with: defaults)
        } catch {
            return fallback("the folder could not be written (\(error.localizedDescription)).")
        }
        var texts = defaults
        for file in TableFile.allCases {
            do {
                texts[file] = try String(contentsOf: url(file), encoding: .utf8)
            } catch {
                return fallback("\(file.name) could not be read (\(error.localizedDescription)).")
            }
        }
        do {
            return Loaded(catalogue: try Catalogue(tables: texts), texts: texts, problem: nil)
        } catch let fault as TableError {
            return fallback("\(fault).")
        } catch {
            return fallback("\(error).")
        }
    }
}
