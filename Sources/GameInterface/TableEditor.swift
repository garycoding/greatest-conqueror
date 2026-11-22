// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
import Observation

/// One file of the tables as the editor holds it: its header and its rows of cells.
public struct EditableTable: Hashable, Sendable {
    public let file: TableFile
    public var header: [String]
    public var rows: [[String]]

    public init(file: TableFile, text: String) throws {
        let table = try CSVTable(file: file.name, text: text)
        self.file = file
        header = table.header
        rows = table.rows.map(\.cells)
    }

    /// The file's text: the header on line 1 and row `k` (from 0) on line
    /// `k + 2`, so that a fault's line names its row. A cell is quoted where
    /// it would otherwise not read back as itself.
    public var text: String {
        ([header] + rows).map { $0.map(Self.written).joined(separator: ",") }.joined(separator: "\n") + "\n"
    }

    static func written(_ cell: String) -> String {
        guard cell.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return cell }
        return "\"" + cell.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

/// The table editor of requirement 27: each file of the tables as a grid of cells.
/// Every edit is read again by the reader the game uses at start-up
/// (`Catalogue(tables:)`), and the first fault it finds is held, with its file,
/// line and column, until it is corrected; only then may the tables be applied.
@MainActor
@Observable
public final class TableEditor {
    /// The tables, in the order of `TableFile.allCases`.
    public private(set) var tables: [EditableTable]
    /// The table shown.
    public var shown: TableFile = .stats
    /// The first fault in the tables as they stand, if any.
    public private(set) var fault: TableError?
    /// The catalogue the tables as they stand describe, when they hold no fault.
    public private(set) var catalogue: Catalogue?
    /// The tables as they were opened or last applied.
    public private(set) var applied: TableTexts

    /// Opens the editor on the tables in use. Throws where they cannot be read
    /// as tables at all, which the tables in use never are.
    public init(texts: TableTexts) throws {
        tables = try TableFile.allCases.map { try EditableTable(file: $0, text: texts[$0]) }
        applied = texts
        check()
        // The texts as the editor writes them, so that nothing reads as changed before an edit.
        applied = self.texts
    }

    /// The tables as they stand, as the files' texts.
    public var texts: TableTexts {
        var texts = applied
        for table in tables { texts[table.file] = table.text }
        return texts
    }

    public func table(_ file: TableFile) -> EditableTable { tables[TableFile.allCases.firstIndex(of: file)!] }

    /// Whether the tables differ from those opened or last applied.
    public var isChanged: Bool { texts != applied }

    /// Whether "Apply" may act: something has changed and no fault remains.
    public var canApply: Bool { isChanged && fault == nil && catalogue != nil }

    /// The cell a fault names, as a row (from 0) and a column (from 0) of its
    /// table; the row is nil where the fault concerns the header, and the
    /// column nil where it concerns the whole row.
    public func faultyCell(in file: TableFile) -> (row: Int?, column: Int?)? {
        guard let fault, fault.file == file.name else { return nil }
        return (fault.line >= 2 ? fault.line - 2 : nil, fault.column >= 1 ? fault.column - 1 : nil)
    }

    /// Changes one cell, and reads the tables again.
    public func set(_ value: String, in file: TableFile, row: Int, column: Int) {
        let t = TableFile.allCases.firstIndex(of: file)!
        guard tables[t].rows.indices.contains(row), tables[t].header.indices.contains(column),
              tables[t].rows[row][column] != value else { return }
        tables[t].rows[row][column] = value
        check()
    }

    /// Puts back the tables as they were opened or last applied.
    public func revert() {
        tables = (try? TableFile.allCases.map { try EditableTable(file: $0, text: applied[$0]) }) ?? tables
        check()
    }

    /// The tables to apply, and the catalogue they describe, when they may be
    /// applied; they then count as applied. `nil` while a fault remains.
    public func apply() -> (texts: TableTexts, catalogue: Catalogue)? {
        guard canApply, let catalogue else { return nil }
        let texts = self.texts
        applied = texts
        return (texts, catalogue)
    }

    private func check() {
        do {
            catalogue = try Catalogue(tables: texts)
            fault = nil
        } catch let found as TableError {
            catalogue = nil
            fault = found
        } catch {
            catalogue = nil
            fault = TableError(file: shown.name, line: 1, column: 0, message: "\(error)")
        }
    }
}
