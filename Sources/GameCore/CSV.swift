// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// Reading the tables (docs/requirements.md, requirement 25): a small reader of
// comma-separated values, and the errors it reports, each naming the file,
// the line and the column.

/// Something wrong in a table: where it is, and what is wrong there.
public struct TableError: Error, Hashable, Sendable, CustomStringConvertible {
    /// The file's name, `stats.csv` for instance.
    public var file: String
    /// From 1; the header is line 1.
    public var line: Int
    /// From 1; 0 where the fault concerns the whole line or the whole file.
    public var column: Int
    public var message: String

    public init(file: String, line: Int, column: Int, message: String) {
        self.file = file; self.line = line; self.column = column; self.message = message
    }

    public var description: String {
        column > 0 ? "\(file), line \(line), column \(column): \(message)" : "\(file), line \(line): \(message)"
    }
}

/// One table read from comma-separated text: a header row naming the columns,
/// then one row of cells for each line that is not blank. A cell may be
/// quoted with double quotes, a doubled quote standing for one; spaces around
/// a cell are dropped.
public struct CSVTable: Sendable {
    public struct Row: Sendable {
        /// The line of the file, from 1.
        public var line: Int
        public var cells: [String]
    }

    public let file: String
    public let header: [String]
    public let rows: [Row]

    public init(file: String, text: String) throws {
        self.file = file
        var lines: [(Int, [String])] = []
        var number = 0
        // A line ends at "\n", "\r\n" (one `Character`) or "\r".
        for raw in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            number += 1
            let line = String(raw)
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            lines.append((number, try CSVTable.cells(of: line, file: file, line: number)))
        }
        guard let first = lines.first else { throw TableError(file: file, line: 1, column: 0, message: "the file is empty") }
        header = first.1
        rows = lines.dropFirst().map { Row(line: $0.0, cells: $0.1) }
        for row in rows where row.cells.count != header.count {
            throw TableError(file: file, line: row.line, column: 0,
                             message: "\(row.cells.count) cells where the header names \(header.count)")
        }
    }

    private static func cells(of line: String, file: String, line number: Int) throws -> [String] {
        var cells: [String] = []
        var cell = ""
        var quoted = false, wasQuoted = false
        let chars = Array(line)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if quoted {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" { cell.append("\""); i += 1 } else { quoted = false }
                } else {
                    cell.append(c)
                }
            } else if c == "\"" && cell.trimmingCharacters(in: .whitespaces).isEmpty && !wasQuoted {
                cell = ""
                quoted = true
                wasQuoted = true
            } else if c == "," {
                cells.append(wasQuoted ? cell : cell.trimmingCharacters(in: .whitespaces))
                cell = ""
                wasQuoted = false
            } else {
                cell.append(c)
            }
            i += 1
        }
        if quoted { throw TableError(file: file, line: number, column: cells.count + 1, message: "a quote is not closed") }
        cells.append(wasQuoted ? cell : cell.trimmingCharacters(in: .whitespaces))
        return cells
    }
}
