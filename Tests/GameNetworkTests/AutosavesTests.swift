// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
@testable import GameNetwork
import Testing

private func scratch() -> Autosaves {
    Autosaves(folder: FileManager.default.temporaryDirectory.appendingPathComponent("autosaves-\(UUID().uuidString)"))
}

@Test func theLastThreeSavesOfEachMatchAreKeptNewestFirst() throws {
    let saves = scratch()
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    for k in 0..<5 {
        try saves.write(Data("a\(k)".utf8), match: "Match A", at: start.addingTimeInterval(Double(k) * 120))
    }
    try saves.write(Data("b".utf8), match: "Match B", at: start.addingTimeInterval(30))
    let a = saves.entries().filter { $0.match == "Match A" }
    #expect(a.count == Autosaves.kept)
    #expect(try a.map { String(decoding: try Data(contentsOf: $0.url), as: UTF8.self) } == ["a4", "a3", "a2"])
    #expect(saves.entries().filter { $0.match == "Match B" }.count == 1)
    #expect(saves.entries().first?.match == "Match A")
}

@Test func aNameWithSlashesOrColonsStillMakesOneFile() throws {
    let saves = scratch()
    try saves.write(Data("x".utf8), match: "Sumer: 2/3", at: Date(timeIntervalSince1970: 1_800_000_000))
    #expect(saves.entries().map(\.match) == ["Sumer- 2-3"])
}

@Test func anEmptyOrMissingFolderHasNoSaves() {
    #expect(scratch().entries().isEmpty)
}
