// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import AppKit
import GameInterface
import SwiftUI

/// The app: one window, which shows the new-match screen until a match starts
/// and then the match.
@main
struct GreatestConquerorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var game = GameController()

    var body: some Scene {
        WindowGroup("Greatest Conqueror") {
            RootView(game: game)
                .frame(minWidth: 1100, minHeight: 720)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Match") { game.endMatch() }
                    .keyboardShortcut("n")
                Button("Open Match…") { game.open() }
                    .keyboardShortcut("o")
                Menu("Open Autosave") {
                    ForEach(game.recentAutosaves.prefix(12), id: \.url) { entry in
                        Button("\(entry.match), \(entry.date.formatted(date: .omitted, time: .shortened))") {
                            game.openAutosave(entry)
                        }
                    }
                    if game.recentAutosaves.isEmpty { Text("No automatic saves yet") }
                }
            }
            CommandMenu("Speed") {
                Picker("Speed", selection: $game.speed) {
                    ForEach(Match.speeds, id: \.self) { speed in
                        Text(speed == 1 ? "Normal (1×)" : "\(speed.formatted())×").tag(speed)
                    }
                }
                .pickerStyle(.inline)
                Divider()
                Button("Faster") { game.changeSpeed(by: 1) }
                    .keyboardShortcut("=")
                Button("Slower") { game.changeSpeed(by: -1) }
                    .keyboardShortcut("-")
                Button("Normal Speed") { game.speed = 1 }
                    .keyboardShortcut("0")
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save Match…") { game.save() }
                    .keyboardShortcut("s")
                    .disabled(game.match == nil)
                Divider()
                // The tables the game reads when it starts (requirement 26).
                Button("Show the tables in Finder") { game.showTables() }
            }
        }
        // The settings (requirements 27 and 28): the editor during play, and the tables as a zip.
        Settings {
            TableSettingsView(model: game.tableSettings, folder: game.tableFolder.folder.path,
                              onEdit: { game.openTableEditor() }, onSaveZip: { game.saveTablesAsZip() },
                              onLoadZip: { game.loadTablesFromZip() }, onShowFolder: { game.showTables() })
        }
    }
}

/// Makes the app a regular one, with a Dock icon and a menu bar, when it is run
/// straight from the package (`swift run`) as well as from its bundle.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Saves the match and tells any others in it that this Mac is leaving;
    /// returns whether there were others to tell.
    @MainActor static var beforeQuitting: (() -> Bool)?

    /// The app quits half a second after telling the others in a match across
    /// the LAN, so that the notice leaves this Mac first.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard Self.beforeQuitting?() == true else { return .terminateNow }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
