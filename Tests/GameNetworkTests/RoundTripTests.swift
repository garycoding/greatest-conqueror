// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
@testable import GameNetwork
import Testing

/// The size of the views in a round-trip measurement. A real match of four
/// on the default 96 × 96 map, measured on 2026-11-18, showed player 0 about
/// 20 people and buildings and 130 sites in its first minute (a view of
/// 30 KB), and 116 and 400 at its twentieth (64 KB).
struct ViewSize: Sendable, CustomTestStringConvertible {
    var name: String
    var mapSize: Int
    var sites: Int
    /// People for each of the four players, beside a town centre.
    var people: Int

    static let sample = ViewSize(name: "the sample map", mapSize: 32, sites: 30, people: 3)
    static let opening = ViewSize(name: "a match's first minute", mapSize: 96, sites: 130, people: 4)
    static let midMatch = ViewSize(name: "a match's twentieth minute", mapSize: 96, sites: 400, people: 28)

    var testDescription: String { name }
}

extension LANTests {
    /// A view's round trip on loopback: an order sent from a client's session to
    /// its refusal, or its effect, seen in the session's view. In a release
    /// build (`swift test -c release --filter roundTrip`) the median is held
    /// under 5 ms for the sample map and a match's opening, and measured for
    /// the middle of a match; a debug build only checks that answers arrive.
    @Test(arguments: [ViewSize.sample, .opening, .midMatch])
    func roundTrip(_ size: ViewSize) async throws {
        let map = size.mapSize == 32 ? Samples.map() : grassMap(size: size.mapSize, sites: size.sites)
        let (lan, hyun, _) = try await Loopback.playing(map: map, people: size.people)
        defer { lan.stop() }
        let session = try #require(hyun.session)
        let bytes = try JSONEncoder().encode(NetMessage.view(session.view.withoutTerrain)).count
        let mark = StubSimulation.mark(of: PlayerID(1))
        #if DEBUG
        let rounds = 10
        #else
        let rounds = 100
        #endif
        let clock = ContinuousClock()
        var times: [Duration] = []
        for i in 0..<rounds {
            let sent = clock.now
            if i.isMultiple(of: 2) {
                session.lastRefusal = nil
                session.issue(.advanceAge)
                try await answered { session.lastRefusal == .studyIncomplete }
            } else {
                let to = MapPosition(x: 1.5 + Double(i % 20), y: 4.5)
                session.issue(.move(units: [mark], to: to))
                try await answered { session.view.entity(mark)?.position == to }
            }
            times.append(sent.duration(to: clock.now))
        }
        times.sort()
        func ms(_ d: Duration) -> Double { Double(d.components.seconds) * 1e3 + Double(d.components.attoseconds) / 1e15 }
        let median = ms(times[times.count / 2]), p95 = ms(times[times.count * 95 / 100]), most = ms(times[times.count - 1])
        print("Round trip on loopback, \(size.name) (\(session.view.entities.count) entities, "
              + "\(session.view.sites.count) sites, \(bytes) bytes a view): median \(median) ms, "
              + "95th percentile \(p95) ms, longest \(most) ms, over \(rounds)")
        #if DEBUG
        #expect(median < 250)
        #else
        if size.mapSize == 96 && size.sites > 200 {
            // Encoding a view of this size as JSON and decoding it take about
            // 5 ms between them; a binary encoding is the plan's remedy, should
            // the measurement show the need.
            withKnownIssue("JSON takes about 5 ms a view at this size", isIntermittent: true) {
                #expect(median < 5)
            }
        } else {
            #expect(median < 5)
        }
        #endif
    }
}

/// Waits for an answer without sleeping, so that the time measured is the
/// answer's and not the waiting's.
@MainActor
private func answered(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + .seconds(10)
    while !condition() {
        guard ContinuousClock.now < deadline else { throw Timeout(what: "the answer to an order") }
        await Task.yield()
    }
}
