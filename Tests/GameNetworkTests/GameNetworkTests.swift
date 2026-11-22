// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import GameCore
@testable import GameNetwork
import Testing

@Test func aFrameCarriesItsLengthFirstMostSignificantByteFirst() {
    let payload = Data(repeating: 7, count: 0x01_02_03)
    let frame = Framing.frame(payload)
    #expect(frame.count == Framing.headerLength + payload.count)
    #expect(Array(frame.prefix(4)) == [0x00, 0x01, 0x02, 0x03])
    #expect(Framing.length(ofHeader: frame.prefix(4)) == payload.count)
    #expect(frame.dropFirst(4) == payload)
}

@Test func aLobbysNameFitsABonjourServiceName() {
    #expect(HostServer.serviceName(for: "Evening") == "Evening")
    #expect(HostServer.serviceName(for: "") == "Greatest Conqueror")
    let long = String(repeating: "Ä", count: 40)
    let name = HostServer.serviceName(for: long)
    #expect(name.utf8.count <= 63 && long.hasPrefix(name) && name.count == 31)
}
