// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import GameCore
import Testing
@testable import MapDrawing

@Suite struct GeometryTests {
    static let centres = [(0.0, 0.0), (10.0, 10.0), (31.5, 2.25), (16.3, 24.7)]
    static let zooms = [0.5, 1.0, 1.37, 2.0]

    @Test func cameraCentreIsDrawnAtTheMiddleOfTheView() {
        for (x, y) in Self.centres { for zoom in Self.zooms {
            let g = geometry(x, y, zoom: zoom)
            let p = g.scenePoint(for: MapPosition(x: x, y: y))
            #expect(abs(p.x - 720) < 1e-9 && abs(p.y - 450) < 1e-9)
        } }
    }

    @Test func mapToScreenAndBackAtSeveralZoomsAndCameras() {
        let positions = [MapPosition(x: 0, y: 0), MapPosition(x: 9.5, y: 9.5), MapPosition(x: 31.9, y: 0.1), MapPosition(x: 12.25, y: 20.75)]
        for (x, y) in Self.centres { for zoom in Self.zooms { for position in positions {
            let g = geometry(x, y, zoom: zoom)
            let back = g.mapPosition(for: g.scenePoint(for: position))
            #expect(abs(back.x - position.x) < 1e-9 && abs(back.y - position.y) < 1e-9)
        } } }
    }

    @Test func screenToMapAndBackAtSeveralZoomsAndCameras() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 720, y: 450), CGPoint(x: 1440, y: 900), CGPoint(x: 333.5, y: 777.25)]
        for (x, y) in Self.centres { for zoom in Self.zooms { for point in points {
            let g = geometry(x, y, zoom: zoom)
            let back = g.scenePoint(for: g.mapPosition(for: point))
            #expect(abs(back.x - point.x) < 1e-9 && abs(back.y - point.y) < 1e-9)
        } } }
    }

    @Test func aTileIsADiamondOfTheProjectionsSize() {
        for zoom in Self.zooms {
            let g = geometry(10, 10, zoom: zoom)
            let right = g.scenePoint(for: MapPosition(x: 11, y: 10)), down = g.scenePoint(for: MapPosition(x: 10, y: 11))
            #expect(abs(right.x - 720 - 32 * zoom) < 1e-9 && abs(right.y - 450 + 16 * zoom) < 1e-9)
            #expect(abs(down.x - 720 + 32 * zoom) < 1e-9 && abs(down.y - 450 + 16 * zoom) < 1e-9)
        }
    }

    @Test func panningShiftsWhatIsDrawnByTheDelta() {
        let g = geometry(10, 10, zoom: 1.5)
        let position = MapPosition(x: 12, y: 8)
        let before = g.scenePoint(for: position)
        let moved = MapGeometry(camera: g.panned(contentBy: CGVector(dx: 30, dy: -12), mapWidth: 32, mapHeight: 32), viewSize: g.viewSize)
        let after = moved.scenePoint(for: position)
        #expect(abs(after.x - before.x - 30) < 1e-9 && abs(after.y - before.y + 12) < 1e-9)
    }

    @Test func panningStaysOverTheMap() {
        let g = geometry(1, 1)
        let camera = g.panned(contentBy: CGVector(dx: 100_000, dy: 100_000), mapWidth: 32, mapHeight: 32)
        #expect(camera.centre.x >= 0 && camera.centre.x <= 32 && camera.centre.y >= 0 && camera.centre.y <= 32)
    }

    @Test func zoomingKeepsTheMapUnderThePointerAndStaysWithinLimits() {
        let g = geometry(14, 12, zoom: 1)
        let anchor = CGPoint(x: 1000, y: 300)
        let under = g.mapPosition(for: anchor)
        let zoomed = MapGeometry(camera: g.zoomed(by: 1.6, about: anchor, mapWidth: 32, mapHeight: 32), viewSize: g.viewSize)
        let after = zoomed.mapPosition(for: anchor)
        #expect(abs(after.x - under.x) < 1e-9 && abs(after.y - under.y) < 1e-9)
        #expect(abs(zoomed.camera.zoom - 1.6) < 1e-12)

        #expect(g.zoomed(by: 100, about: anchor, mapWidth: 32, mapHeight: 32).zoom == Camera.maximumZoom)
        #expect(g.zoomed(by: 0.001, about: anchor, mapWidth: 32, mapHeight: 32).zoom == Camera.minimumZoom)
    }

    @MainActor @Test func edgesScrollTowardTheEdge() {
        let size = screenSize
        #expect(MapScene.edgeDirection(of: CGPoint(x: 2, y: 450), in: size) == CGVector(dx: -1, dy: 0))
        #expect(MapScene.edgeDirection(of: CGPoint(x: 1439, y: 899), in: size) == CGVector(dx: 1, dy: 1))
        #expect(MapScene.edgeDirection(of: CGPoint(x: 720, y: 1), in: size) == CGVector(dx: 0, dy: -1))
        #expect(MapScene.edgeDirection(of: CGPoint(x: 720, y: 450), in: size) == CGVector(dx: 0, dy: 0))
    }
}
