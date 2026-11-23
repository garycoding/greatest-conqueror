// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore
import SwiftUI

// MARK: The table editor

/// The tables as editable grids, one for each file, one shown at a time, each column named
/// as in the file (docs/tables.md). A fault is shown with its file, line and
/// column, its cell outlined, and "Apply" waits until it is corrected.
public struct TableEditorView: View {
    let editor: TableEditor
    let onApply: (TableTexts, Catalogue) -> Void
    let onClose: () -> Void
    /// A line under the title: that the match is paused whilst the editor is open.
    var note: String

    public init(editor: TableEditor, note: String = "The match is paused whilst the tables are open.",
                onApply: @escaping (TableTexts, Catalogue) -> Void, onClose: @escaping () -> Void) {
        self.editor = editor; self.note = note; self.onApply = onApply; self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("The tables").font(Typeface.text(22, bold: true))
                Text(note).font(Typeface.text(12)).foregroundStyle(Palette.inkSoft)
                Spacer()
            }
            HStack(spacing: 8) {
                ForEach(TableFile.allCases, id: \.self) { file in
                    let faulty = editor.faultyCell(in: file) != nil
                    Button { editor.shown = file } label: {
                        Text(file.name).font(Typeface.text(13, bold: true))
                            .foregroundStyle(faulty ? Palette.brick : Palette.ink)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .cartoonBox(fill: editor.shown == file ? Palette.ochre.opacity(0.6) : Palette.paper, radius: 14, lineWidth: 1.2)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(file.name)
                }
            }
            TableGrid(editor: editor, table: editor.table(editor.shown))
                .cartoonBox(fill: Palette.paper, radius: 6, lineWidth: 1.2)
            HStack(alignment: .top) {
                if let fault = editor.fault {
                    Text("\(fault.description). Not applied until it is corrected.")
                        .font(Typeface.text(12, bold: true)).foregroundStyle(Palette.brick)
                        .fixedSize(horizontal: false, vertical: true)
                } else if editor.isChanged {
                    Text("The tables read without a fault. Apply saves them and puts them into the match from the next tick.")
                        .font(Typeface.text(12)).foregroundStyle(Palette.ink)
                } else {
                    Text("No changes.").font(Typeface.text(12)).foregroundStyle(Palette.inkSoft)
                }
                Spacer(minLength: 12)
                PillButton(title: "Revert", enabled: editor.isChanged, size: 13) { editor.revert() }
                PillButton(title: "Close", size: 13, action: onClose).keyboardShortcut(.cancelAction)
                PillButton(title: "Apply", fill: Palette.ochre.opacity(0.7), enabled: editor.canApply, size: 13) {
                    if let applied = editor.apply() { onApply(applied.texts, applied.catalogue) }
                }
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(18)
        .background(Palette.paperDeep)
    }
}

/// One table: a header row of column names and a row of cells for each line.
struct TableGrid: View {
    let editor: TableEditor
    let table: EditableTable

    static func width(of column: String) -> CGFloat {
        switch column {
        case "kind", "maker", "unit": 104
        case "age", "from", "to": 74
        default: max(56, CGFloat(column.count) * 7.4 + 10)
        }
    }

    var body: some View {
        let bad = editor.faultyCell(in: table.file)
        ScrollView([.horizontal, .vertical]) {
            Grid(alignment: .leading, horizontalSpacing: 2, verticalSpacing: 2) {
                GridRow {
                    Text("line").font(Typeface.text(10.5)).foregroundStyle(Palette.inkSoft).frame(width: 30)
                    ForEach(Array(table.header.enumerated()), id: \.offset) { c, name in
                        Text(name).font(Typeface.text(10.5, bold: true))
                            .lineLimit(1).frame(width: Self.width(of: name), alignment: .leading)
                            .padding(.horizontal, 2)
                            .overlay { if bad?.row == nil && bad?.column == c { Rectangle().stroke(Palette.brick, lineWidth: 2) } }
                    }
                }
                ForEach(table.rows.indices, id: \.self) { r in
                    GridRow {
                        Text("\(r + 2)").font(Typeface.text(10.5)).foregroundStyle(Palette.inkSoft).frame(width: 30)
                        ForEach(table.header.indices, id: \.self) { c in
                            let faulty = bad?.row == r && (bad?.column == c || bad?.column == nil)
                            TextField("", text: Binding(get: { editor.table(table.file).rows[r][c] },
                                                        set: { editor.set($0, in: table.file, row: r, column: c) }))
                                .textFieldStyle(.plain)
                                .font(Typeface.text(11.5))
                                .frame(width: Self.width(of: table.header[c]))
                                .padding(.horizontal, 2).padding(.vertical, 2)
                                .background(faulty ? Palette.brick.opacity(0.18) : Palette.paper)
                                .overlay { if faulty { Rectangle().stroke(Palette.brick, lineWidth: 2) } }
                                .accessibilityLabel("\(table.header[c]), line \(r + 2)")
                        }
                    }
                }
            }
            .padding(8)
        }
    }
}

// MARK: Settings

/// What the settings offer for the tables, and whether each can act now: the
/// editor during play, for the host alone in a match across the network
/// (requirements 27 and 29); a zip can be saved at any time, and loaded
/// before a match or, in one, by the host (requirement 28).
public struct TableSettingsModel: Hashable, Sendable {
    public enum Place: Hashable, Sendable {
        /// No match in play: the tables loaded take effect at the next start.
        case noMatch
        /// A match on this Mac, or one it hosts across the network.
        case hosting
        /// A match another Mac hosts.
        case joined
    }

    public var place: Place

    public init(place: Place) { self.place = place }

    /// Why the editor cannot be opened now, or nil where it can.
    public var editUnavailable: String? {
        switch place {
        case .noMatch: "The tables are edited during play; start a match first."
        case .hosting: nil
        case .joined: "Only the host may edit the tables during a match across the network."
        }
    }

    public var canEdit: Bool { editUnavailable == nil }

    /// Why a zip cannot be loaded now, or nil where it can.
    public var loadUnavailable: String? {
        place == .joined ? "Only the host may change the tables during a match across the network." : nil
    }

    /// What loading a zip does, in words.
    public var loadEffect: String {
        switch place {
        case .noMatch: "Replaces the tables in the folder; they take effect when the next match starts."
        case .hosting: "Replaces the tables in the folder and puts them into the match from the next tick, as Apply does."
        case .joined: "Only the host may change the tables during a match across the network."
        }
    }
}

/// The game's settings: the tables.
public struct TableSettingsView: View {
    let model: TableSettingsModel
    let folder: String
    let onEdit: () -> Void
    let onSaveZip: () -> Void
    let onLoadZip: () -> Void
    let onShowFolder: () -> Void

    public init(model: TableSettingsModel, folder: String, onEdit: @escaping () -> Void, onSaveZip: @escaping () -> Void,
                onLoadZip: @escaping () -> Void, onShowFolder: @escaping () -> Void) {
        self.model = model; self.folder = folder; self.onEdit = onEdit; self.onSaveZip = onSaveZip
        self.onLoadZip = onLoadZip; self.onShowFolder = onShowFolder
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("The tables").font(Typeface.text(20, bold: true))
            Text("Every number that governs the play is in the tables, kept in \(folder).")
                .font(Typeface.text(12)).fixedSize(horizontal: false, vertical: true)
            item("Edit the tables\u{2026}", enabled: model.canEdit, action: onEdit,
                 detail: model.editUnavailable ?? "Opens the editor and pauses the match until it is closed.")
            item("Save the tables as a zip\u{2026}", enabled: true, action: onSaveZip,
                 detail: "Writes the tables' files into one zip file, wherever you choose.")
            item("Load tables from a zip\u{2026}", enabled: model.loadUnavailable == nil, action: onLoadZip,
                 detail: model.loadEffect)
            item("Show the tables in Finder", enabled: true, action: onShowFolder, detail: "Opens the folder that holds them.")
        }
        .foregroundStyle(Palette.ink)
        .padding(20)
        .frame(width: 460, alignment: .leading)
        .background(Palette.paperDeep)
    }

    private func item(_ title: String, enabled: Bool, action: @escaping () -> Void, detail: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            PillButton(title: title, enabled: enabled, size: 13, action: action).frame(width: 220, alignment: .leading)
            Text(detail).font(Typeface.text(11)).foregroundStyle(enabled ? Palette.ink : Palette.brick)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: The gear

extension View {
    /// The gear in the window's title bar, on every screen (ruled 2026-11-22):
    /// it opens the Settings window, as Command-comma does.
    public func settingsGear() -> some View {
        toolbar {
            ToolbarItem(placement: .primaryAction) {
                SettingsLink { Label("Settings", systemImage: "gearshape") }
                    .help("Settings: the tables, their editor and their zip (\u{2318},)")
            }
        }
    }
}
