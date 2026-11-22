// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// The Roman bridge of the Iron age, after the bridges of Alcántara and
// Rimini: round arches of dressed stone, one to the tile, a ring of voussoirs
// round each with a keystone, piers with cutwaters capped at the springing,
// a road of polygonal paving stones with a line of kerb stones between the
// lanes, and a plain parapet with a coping along each side.

extension BridgesPainter {
    mutating func roman(complete: Bool) {
        typealias I = IronOldBuildingsInk
        let style = BridgesMasonryStyle(stone: I.stone, stoneTop: I.stoneTop, stoneShade: I.stoneShade,
                                        dressed: I.rawStone, paving: "#a7a194", pavingShade: "#8a8478",
                                        kerb: I.footingShade, staff: I.timberDark, pier: 0.1, spring: 1.0, round: true,
                                        refuges: false, parapet: 3.0)
        masonry(style, complete: complete)
    }
}
