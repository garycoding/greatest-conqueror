// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import AppKit
import GameCore
import SwiftUI
import Testing
@testable import GameInterface

// MARK: The table editor (requirements 27 and 29)

@MainActor
private func column(_ name: String, of file: TableFile, in editor: TableEditor) -> Int {
    editor.table(file).header.firstIndex(of: name)!
}

@MainActor
private func row(_ kind: String, of file: TableFile, in editor: TableEditor) -> Int {
    editor.table(file).rows.firstIndex { $0[0] == kind }!
}

@MainActor
@Test func theEditorShowsEveryTableWithItsColumnsNamedAsInTheFiles() throws {
    let editor = try TableEditor(texts: .defaults)
    #expect(editor.tables.map(\.file) == TableFile.allCases)
    #expect(editor.table(.stats).header == TableColumns.stats)
    #expect(editor.table(.production).header == TableColumns.production)
    #expect(editor.table(.ages).header == TableColumns.ages)
    #expect(editor.fault == nil && !editor.isChanged && !editor.canApply)
    // What it would write reads back as the same tables.
    #expect(try Catalogue(tables: editor.texts) == Catalogue.standard)
}

@MainActor
@Test func theEditorRefusesABadCellAndAppliesAGoodOne() throws {
    let editor = try TableEditor(texts: .defaults)
    let health = column("health", of: .stats, in: editor), worker = row("worker", of: .stats, in: editor)
    editor.set("lots", in: .stats, row: worker, column: health)
    // The fault names its file, line and column, as at start-up, and nothing is applied.
    let fault = try #require(editor.fault)
    #expect(fault.file == "stats.csv" && fault.line == worker + 2 && fault.column == health + 1)
    #expect(fault.description.contains("\"lots\""))
    #expect(editor.faultyCell(in: .stats)?.row == worker && editor.faultyCell(in: .stats)?.column == health)
    #expect(editor.faultyCell(in: .ages) == nil)
    #expect(!editor.canApply && editor.apply() == nil)

    // Corrected, it may be applied, and gives the catalogue the reader makes of it.
    editor.set("40", in: .stats, row: worker, column: health)
    #expect(editor.fault == nil && editor.canApply)
    let (texts, catalogue) = try #require(editor.apply())
    #expect(catalogue.stats(.worker).health == 40)
    #expect(try Catalogue(tables: texts) == catalogue)
    #expect(!editor.isChanged && !editor.canApply)

    // A fault in another table is found too, and Revert puts back what was applied.
    let seconds = column("seconds", of: .ages, in: editor)
    editor.set("-3", in: .ages, row: 0, column: seconds)
    #expect(editor.fault?.file == "ages.csv" && editor.fault?.line == 2 && editor.fault?.column == seconds + 1)
    editor.revert()
    #expect(editor.fault == nil && !editor.isChanged && editor.catalogue == catalogue)
}

@MainActor
@Test func aCellThatHoldsACommaOrAQuoteIsWrittenSoThatItReadsBack() throws {
    let editor = try TableEditor(texts: .defaults)
    editor.set("hut, \"big\"", in: .stats, row: 0, column: 0)
    #expect(editor.fault?.description.contains("hut, \"big\"") == true)
    let back = try EditableTable(file: .stats, text: editor.texts[.stats])
    #expect(back.rows[0][0] == "hut, \"big\"")
}

@Test func onlyTheHostMayEditTheTablesDuringAMatchAcrossTheNetwork() {
    #expect(TableSettingsModel(place: .hosting).canEdit)
    #expect(!TableSettingsModel(place: .joined).canEdit)
    #expect(TableSettingsModel(place: .joined).editUnavailable?.contains("Only the host") == true)
    #expect(TableSettingsModel(place: .joined).loadUnavailable != nil)
    // Before a match there is nothing to edit, but a zip may be loaded for the next.
    #expect(!TableSettingsModel(place: .noMatch).canEdit && TableSettingsModel(place: .noMatch).loadUnavailable == nil)
}

// MARK: The pause (requirement 30)

@Test func thePauseSignSaysWhoPaused() {
    var view = Samples.farmsAgeSkirmish()
    #expect(PauseSignModel(view: view) == nil)
    view.isPaused = true
    #expect(PauseSignModel(view: view)?.byLine == nil)
    view.pausedBy = view.player
    #expect(PauseSignModel(view: view)?.byLine == "Paused by you")
    let other = view.players.first { $0.id != view.player }!
    view.pausedBy = other.id
    #expect(PauseSignModel(view: view)?.byLine == "Paused by \(other.civilization.name)")
    #expect(PauseSignModel(view: view, names: [other.id: "Hyun"])?.byLine == "Paused by Hyun")
}

@Test func theSpeedControlStepsWithinTheSpeeds() {
    let at1 = SpeedControlModel(speed: 1, speeds: [1, 1.5, 2, 3, 4], slower: {}, faster: {})
    #expect(!at1.canGoSlower && at1.canGoFaster && at1.text == "1\u{00D7}")
    let at4 = SpeedControlModel(speed: 4, speeds: [1, 1.5, 2, 3, 4], slower: {}, faster: {})
    #expect(at4.canGoSlower && !at4.canGoFaster)
}

// MARK: Pictures, for showing before merge

/// Renders a view through an offscreen `NSHostingView`, which draws text
/// fields as the app does, to a PNG in `COP_RENDERS` where it is set.
@MainActor
private func renderHosted<V: View>(_ name: String, width: CGFloat, height: CGFloat, _ content: V) -> Bool {
    let host = NSHostingView(rootView: content.frame(width: width, height: height).environment(\.colorScheme, .light))
    host.frame = CGRect(x: 0, y: 0, width: width, height: height)
    let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = host
    host.layoutSubtreeIfNeeded()
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return false }
    host.cacheDisplay(in: host.bounds, to: rep)
    guard rep.pixelsWide >= Int(width) else { return false }
    if let dir = ProcessInfo.processInfo.environment["COP_RENDERS"], let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
    }
    return true
}

/// Renders a view in a titled window, with the gear in its title bar, frame
/// and all, to a PNG in `COP_RENDERS` where it is set.
@MainActor
private func renderWindow<V: View>(_ name: String, width: CGFloat, height: CGFloat, _ content: V) -> Bool {
    let host = NSHostingView(rootView: content.frame(width: width, height: height).settingsGear()
        .environment(\.colorScheme, .light))
    host.sceneBridgingOptions = [.toolbars, .title]
    let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: width, height: height),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
    window.title = "Greatest Conqueror"
    window.appearance = NSAppearance(named: .aqua)
    window.contentView = host
    host.layoutSubtreeIfNeeded()
    guard let frame = window.contentView?.superview else { return false }
    frame.layoutSubtreeIfNeeded()
    guard let rep = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) else { return false }
    frame.cacheDisplay(in: frame.bounds, to: rep)
    if let dir = ProcessInfo.processInfo.environment["COP_RENDERS"], let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
    }
    return rep.pixelsWide >= Int(width)
}

@MainActor
@Test func theNewScreensRender() throws {
    var view = Samples.farmsAgeSkirmish()
    view.isPaused = true
    view.pausedBy = view.players.first { $0.id != view.player }!.id
    let s = session(view)
    let speed = SpeedControlModel(speed: 1.5, speeds: [1, 1.5, 2, 3, 4], slower: {}, faster: {})
    #expect(render("pause-notice", width: 1440, height: 900) {
        GameHUD(session: s, names: [view.pausedBy!: "Hyun"], speed: speed) { EmptyMap() }
    })
    #expect(renderWindow("pause-notice-window", width: 1440, height: 900,
                         GameHUD(session: s, names: [view.pausedBy!: "Hyun"], speed: speed) { EmptyMap() }))

    let editor = try TableEditor(texts: .defaults)
    let health = column("health", of: .stats, in: editor), soldier = row("soldier1", of: .stats, in: editor)
    editor.set("lots", in: .stats, row: soldier, column: health)
    #expect(editor.fault != nil)
    #expect(renderHosted("table-editor-fault", width: 1240, height: 700,
                         TableEditorView(editor: editor, onApply: { _, _ in }, onClose: {})))

    #expect(renderHosted("settings-tables", width: 460, height: 300,
                         TableSettingsView(model: TableSettingsModel(place: .hosting),
                                           folder: "~/Library/Application Support/Greatest Conqueror",
                                           onEdit: {}, onSaveZip: {}, onLoadZip: {}, onShowFolder: {})))
}
