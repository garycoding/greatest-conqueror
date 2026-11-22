// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// The automatic saves of matches: every two minutes of play and when the app
/// quits, the last three of each match kept (ruling of 2026-11-18).
public struct Autosaves: Sendable {
    /// Seconds of play between two automatic saves.
    public static let interval: TimeInterval = 120
    /// How many automatic saves of one match are kept.
    public static let kept = 3

    public let folder: URL

    /// `~/Library/Application Support/Greatest Conqueror/Autosaves`, or another folder (for tests).
    public init(folder: URL? = nil) {
        self.folder = folder ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Greatest Conqueror", isDirectory: true)
            .appendingPathComponent("Autosaves", isDirectory: true)
    }

    /// One automatic save on disk.
    public struct Entry: Hashable, Sendable {
        public var url: URL
        public var match: String
        public var date: Date
    }

    /// Writes `data` as the newest automatic save of `match`, and removes that
    /// match's older ones beyond `kept`.
    @discardableResult
    public func write(_ data: Data, match: String, at date: Date = Date()) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("\(Self.safe(match)) \(Self.stamp(date)).json")
        try data.write(to: url, options: .atomic)
        for old in entries().filter({ $0.match == Self.safe(match) }).dropFirst(Self.kept) {
            try? FileManager.default.removeItem(at: old.url)
        }
        return url
    }

    /// Every automatic save, newest first.
    public func entries() -> [Entry] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return urls.compactMap { url -> Entry? in
            guard url.pathExtension == "json" else { return nil }
            let name = url.deletingPathExtension().lastPathComponent
            guard name.count > Self.stampLength + 1 else { return nil }
            let stampText = String(name.suffix(Self.stampLength))
            guard let date = Self.formatter.date(from: stampText) else { return nil }
            return Entry(url: url, match: String(name.dropLast(Self.stampLength + 1)), date: date)
        }
        .sorted { ($0.date, $0.url.path) > ($1.date, $1.url.path) }
    }

    /// A match's name as it can stand in a file name.
    static func safe(_ match: String) -> String {
        String(match.map { "/:".contains($0) ? "-" : $0 })
    }

    private static let stampLength = 19
    private static func stamp(_ date: Date) -> String { formatter.string(from: date) }
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return f
    }()
}
