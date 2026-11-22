// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// A person's car (`CarSprites`): every key of the batch has a sprite that
/// stands on its anchor and carries a mask, every other key has none, a key
/// always gives the same pixels, and the batch is drawn quickly.
@Suite(.serialized) struct CarTests {
    private let source = CarSprites()

    @Test func theBatchIsTheCarStandingDrivingAndParked() {
        let car = SpriteSubject.unit(.car, .stone)
        #expect(source.poses == [SpriteKey(car, .standing), SpriteKey(car, .walking), SpriteKey(car, .working)])
        #expect(source.keys.count == 3 * SpriteKey.framesPerPose)
    }

    @Test func everyKeyHasASpriteWithAMaskCentredOnTheGroundContact() throws {
        for key in source.keys {
            let sprite = try #require(source.sprite(key), "\(key)")
            let mask = try #require(sprite.teamMask, "\(key) has no team colour")
            #expect(mask.width == sprite.base.width && mask.height == sprite.base.height, "\(key)")
            #expect(CarPixels(mask).hasCoverage, "\(key)")
            #expect(CarPixels(sprite.base).centresContact(at: sprite.anchor), "\(key): the anchor is not at the centre of the ground contact")
        }
    }

    @Test func parkedIsDrawnAsStanding() throws {
        let car = SpriteSubject.unit(.car, .stone)
        for frame in 0..<SpriteKey.framesPerPose {
            let parked = try #require(source.sprite(SpriteKey(car, .working, frame: frame)))
            let standing = try #require(source.sprite(SpriteKey(car, .standing, frame: frame)))
            #expect(CarPixels(parked.base) == CarPixels(standing.base), "frame \(frame)")
        }
    }

    @Test func theWheelsTurnWhenDriving() throws {
        let car = SpriteSubject.unit(.car, .stone)
        let first = try #require(source.sprite(SpriteKey(car, .walking, frame: 0)))
        let next = try #require(source.sprite(SpriteKey(car, .walking, frame: 1)))
        #expect(CarPixels(first.base) != CarPixels(next.base))
    }

    @Test func everyOtherKeyHasNone() {
        let batch = Set(source.keys)
        let poses: [SpritePose] = [.standing, .walking, .working, .fighting, .complete, .underConstruction, "carrying"]
        var others: [SpriteKey] = []
        for kind in UnitKind.allCases {
            for age in Age.allCases {
                for pose in poses {
                    for frame in [-1, 0, 6, 11, 12] { others.append(SpriteKey(.unit(kind, age), pose, frame: frame)) }
                }
            }
        }
        for kind in BuildingKind.allCases {
            for age in Age.allCases { others.append(SpriteKey(.building(kind, age), .complete)) }
        }
        for kind in SiteKind.allCases { others.append(SpriteKey(.site(kind), .complete)) }
        others.append(SpriteKey(.outcrop, .complete))
        for terrain in Terrain.allCases { others.append(SpriteKey(.terrain(terrain, variant: 0), .complete)) }
        let outside = others.filter { !batch.contains($0) }
        #expect(outside.count > 1000)
        for key in outside { #expect(source.sprite(key) == nil, "\(key)") }
        #expect(source.sprite(SpriteKey(.unit(.car, .stone), .fighting, frame: 0)) == nil)
        #expect(source.sprite(SpriteKey(.unit(.car, .industrial), .standing, frame: 0)) == nil)
    }

    @Test func theSameKeyGivesTheSamePixels() throws {
        let again = CarSprites()
        for key in source.keys {
            let first = try #require(source.sprite(key)), second = try #require(again.sprite(key))
            #expect(CarPixels(first.base) == CarPixels(second.base), "\(key)")
            #expect(first.teamMask.map(CarPixels.init) == second.teamMask.map(CarPixels.init), "\(key)")
            #expect(first.anchor == second.anchor, "\(key)")
        }
    }

    @Test func theBatchRendersInUnderTwoSeconds() {
        let fresh = CarSprites()
        let elapsed = ContinuousClock().measure {
            for key in fresh.keys { _ = fresh.sprite(key) }
        }
        #expect(elapsed < .seconds(2), "the batch took \(elapsed)")
    }
}

// MARK: CarPixels

/// An image's pixels as premultiplied RGBA bytes, rows from the top.
private struct CarPixels: Equatable {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    init(_ image: CGImage) {
        width = image.width; height = image.height
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        // `Raster.bitmap` packs its rows, four bytes to a pixel.
        let data = context.data!.bindMemory(to: UInt8.self, capacity: context.bytesPerRow * height)
        bytes = Array(UnsafeBufferPointer(start: data, count: context.bytesPerRow * height))
    }

    var hasCoverage: Bool { stride(from: 3, to: bytes.count, by: 4).contains { bytes[$0] > 128 } }

    /// Whether the pixel is dark and opaque: the line, a tyre.
    func ink(_ x: Int, _ row: Int) -> Bool {
        guard x >= 0, x < width, row >= 0, row < height else { return false }
        let i = (row * width + x) * 4
        return bytes[i + 3] > 200 && bytes[i] < 90 && bytes[i + 1] < 90 && bytes[i + 2] < 90
    }

    /// The anchor as a column and a row from the top.
    func place(_ anchor: SpriteAnchor) -> (x: Int, row: Int) {
        (Int((anchor.x * Double(width)).rounded()), height - Int((anchor.y * Double(height)).rounded()))
    }

    /// The lowest row with ink in it.
    var lowestInk: Int? {
        (0..<height).reversed().first { row in (0..<width).contains { ink($0, row) } }
    }

    /// The wheels meet the ground on the anchor's row, on both sides of its
    /// column, and the anchor is near the middle of what touches the ground.
    func centresContact(at anchor: SpriteAnchor) -> Bool {
        let (x, ground) = place(anchor)
        guard let lowest = lowestInk, abs(lowest - ground) <= 3 else { return false }
        let columns = (max(0, ground - 4)...min(height - 1, ground + 2)).flatMap { row in (0..<width).filter { ink($0, row) } }
        guard let left = columns.min(), let right = columns.max(), left < x - 6, right > x + 6 else { return false }
        return abs(Double(left + right) / 2 - Double(x)) <= Double(right - left) * 0.2
    }
}

/// Renders the car for a person to judge, into the directory named by the
/// environment variable `CAR_RENDERS`, each file's name ending with the
/// environment variable `CAR_RENDERS_SUFFIX` (for example `-v2`) where it is
/// set, so that a round of corrections keeps the earlier renders; skipped when
/// `CAR_RENDERS` is not set.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["CAR_RENDERS"] != nil))
struct CarRenders {
    private let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["CAR_RENDERS"] ?? "/", isDirectory: true)
    private let suffix = ProcessInfo.processInfo.environment["CAR_RENDERS_SUFFIX"] ?? ""

    /// Each pose's 12 frames enlarged in two rows of six, for looking at frame by frame.
    @Test func posesAsStrips() throws {
        let strips = directory.appendingPathComponent("strips")
        try FileManager.default.createDirectory(at: strips, withIntermediateDirectories: true)
        let colour = TeamColour.of(.sumer)
        let large = CarSaloon.canvas.scaled(to: 4)
        for pose in [SpritePose.standing, .walking] {
            let cellW = large.pixelWidth, cellH = large.pixelHeight
            let width = cellW * 3, height = cellH * 4
            let context = Raster.bitmap(width: width, height: height)!
            context.draw(Preview.ground(width: width, height: height, tile: 256, grained: false), in: CGRect(x: 0, y: 0, width: width, height: height))
            for frame in 0..<12 {
                let drawn = try #require(CarSaloon.render(pose, frame: frame, canvas: large))
                let image = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour)
                let x = Double(frame % 3 * cellW), y = Double(height - (frame / 3 + 1) * cellH)
                context.draw(image, in: CGRect(x: x, y: y, width: Double(cellW), height: Double(cellH)))
                Preview.label("\(frame)", in: context, at: CGPoint(x: x + 8, y: y + 8), size: 18)
            }
            try Preview.writePNG(context.makeImage()!, to: strips.appendingPathComponent("car-\(pose.rawValue)\(suffix).png"))
        }
    }

    /// One animated GIF at 12 frames a second: the car standing, then driving
    /// across a patch of ground, in Sumer's colour, drawn large from the same
    /// SVG, and beside it the sprite itself at game size.
    @Test func animation() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sprites = CarSprites()
        let colour = TeamColour.of(.sumer)
        let width = 1440, height = 400, groundLine = 96.0
        let ground = Preview.ground(width: width, height: height, tile: 256, grained: false)
        let scale = 3.6
        let large = CarSaloon.canvas.scaled(to: scale)
        var frames: [CGImage] = []
        for pose in [SpritePose.standing, .walking] {
            let walking = pose == .walking
            let count = walking ? 36 : 24
            for i in 0..<count {
                let frame = i % 12
                let context = Raster.bitmap(width: width, height: height)!
                context.draw(ground, in: CGRect(x: 0, y: 0, width: width, height: height))
                let drawn = try #require(CarSaloon.render(pose, frame: frame, canvas: large))
                let big = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: colour)
                let x = walking ? 260 + Double(i) * CarSaloon.groundPerFrame * scale : 260
                Preview.place(big, anchor: large.anchor, at: CGPoint(x: x, y: groundLine), in: context)
                let sprite = try #require(sprites.sprite(SpriteKey(.unit(.car, .stone), pose, frame: frame)))
                let small = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour)
                let sx = walking ? 1250 + Double(i) * CarSaloon.groundPerFrame * 0.5 : 1250
                Preview.place(small, anchor: sprite.anchor, at: CGPoint(x: sx, y: groundLine), in: context)
                Preview.label("A person's car, in Sumer's colour", in: context, at: CGPoint(x: 28, y: Double(height) - 52), size: 26)
                Preview.label((walking ? "driving: the wheels turn, the body rides its springs" : "standing: parked")
                              + ", 12 frames a second", in: context, at: CGPoint(x: 28, y: 28), size: 22)
                Preview.label("at game size", in: context, at: CGPoint(x: 1200, y: 60), size: 18)
                frames.append(context.makeImage()!)
            }
        }
        try Preview.writeGIF(frames, to: directory.appendingPathComponent("car\(suffix).gif"))
    }

    /// The car at game size, and enlarged twice without smoothing, on each
    /// ground it can drive over, to see that its black shape reads on the darkest.
    @Test func onEveryGround() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let terrain = TerrainSprites(), car = CarSprites()
        let grounds = Terrain.allCases.filter(\.isPassable)
        let cellW = 760, cellH = 220
        let width = cellW, height = cellH * grounds.count
        let context = Raster.bitmap(width: width, height: height)!
        context.interpolationQuality = .none
        let colour = TeamColour.of(.sumer)
        for (row, ground) in grounds.enumerated() {
            let tile = try #require(terrain.sprite(SpriteKey(.terrain(ground, variant: 0), .complete)))
            let bottom = Double(height - (row + 1) * cellH)
            // The tile's diamond is laid edge to edge, enlarged to cover the cell.
            context.saveGState()
            context.clip(to: CGRect(x: 0, y: bottom, width: Double(cellW), height: Double(cellH)))
            context.draw(tile.base, in: CGRect(x: -Double(cellW) * 0.25, y: bottom - Double(cellH) * 0.5, width: Double(cellW) * 1.5, height: Double(cellH) * 2))
            context.restoreGState()
            Preview.label("\(ground)", in: context, at: CGPoint(x: 12, y: bottom + Double(cellH) - 28), size: 18)
            for (n, pose) in [SpritePose.standing, .walking].enumerated() {
                let sprite = try #require(car.sprite(SpriteKey(.unit(.car, .stone), pose, frame: 3)))
                let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour)
                Preview.place(image, anchor: sprite.anchor, at: CGPoint(x: 110 + Double(n) * 170, y: bottom + 40), in: context)
            }
            let sprite = try #require(car.sprite(SpriteKey(.unit(.car, .stone), .standing)))
            let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: colour)
            Preview.place(image, anchor: sprite.anchor, at: CGPoint(x: 560, y: bottom + 30), in: context, scale: 2)
        }
        try Preview.writePNG(context.makeImage()!, to: directory.appendingPathComponent("on-every-ground\(suffix).png"))
    }

    /// The car beside the Industrial armoured car and the Industrial worker
    /// (the factory hand), all at one scale, in the colours of Rome, Angkor and
    /// Shang (Rome's red and Angkor's orange must stay distinct), Tonga's near-black,
    /// and the light colours of Samoa and Greece: drawn large, and as the sprites at game size.
    @Test func contactSheet() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let civilizations: [Civilization] = [.rome, .angkor, .shang, .tonga, .samoa, .greece]
        let scale = 3.0
        let rowHeight = 330, width = 1900
        let height = 90 + rowHeight * civilizations.count
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 256, grained: false), in: CGRect(x: 0, y: 0, width: width, height: height))
        Preview.label("A person's car beside the Industrial armoured car and worker, at one scale, in the colours of Rome, Angkor, Shang, Tonga, Samoa and Greece",
                      in: context, at: CGPoint(x: 24, y: Double(height) - 48), size: 24)
        let armoured = try #require(IndustrialWarriorsLooks.look(.armouredCar))
        let worker = try #require(IndustrialPeopleLooks.look(.worker))
        let car = CarSprites(), warriors = IndustrialWarriorSprites(), people = IndustrialPeopleSprites()
        for (row, civilization) in civilizations.enumerated() {
            let tint = TeamColour.of(civilization)
            let groundY = Double(height - 90 - (row + 1) * rowHeight) + 60
            Preview.label("\(civilization)", in: context, at: CGPoint(x: 24, y: groundY + 230), size: 20)
            let carLarge = CarSaloon.canvas.scaled(to: scale)
            let drawnCar = try #require(CarSaloon.render(.standing, frame: 0, canvas: carLarge))
            Preview.place(Preview.tinted(base: drawnCar.base, mask: drawnCar.mask, colour: tint), anchor: carLarge.anchor,
                          at: CGPoint(x: 230, y: groundY), in: context)
            let armouredLarge = IndustrialWarriorsArmouredCar.canvas.scaled(to: scale)
            let drawnArmoured = try #require(armoured.render(.standing, frame: 0, canvas: armouredLarge))
            Preview.place(Preview.tinted(base: drawnArmoured.base, mask: drawnArmoured.mask, colour: tint), anchor: armouredLarge.anchor,
                          at: CGPoint(x: 640, y: groundY), in: context)
            let workerLarge = Canvas.person.scaled(to: scale)
            let drawnWorker = try #require(worker.render(.standing, frame: 0, canvas: workerLarge))
            Preview.place(Preview.tinted(base: drawnWorker.base, mask: drawnWorker.mask, colour: tint), anchor: workerLarge.anchor,
                          at: CGPoint(x: 930, y: groundY), in: context)
            let small: [(any SpriteSource, SpriteKey, Double)] = [
                (car, SpriteKey(.unit(.car, .stone), .standing), 1150), (car, SpriteKey(.unit(.car, .stone), .walking, frame: 3), 1350),
                (warriors, SpriteKey(.unit(.armouredCar, .industrial), .standing), 1560),
                (people, SpriteKey(.unit(.worker, .industrial), .standing), 1730),
            ]
            for (source, key, x) in small {
                let sprite = try #require(source.sprite(key), "\(key)")
                Preview.place(Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: tint), anchor: sprite.anchor,
                              at: CGPoint(x: x, y: groundY), in: context)
            }
        }
        Preview.label("at game size", in: context, at: CGPoint(x: 1150, y: Double(height) - 84), size: 18)
        try Preview.writePNG(context.makeImage()!, to: directory.appendingPathComponent("contact-sheet\(suffix).png"))
    }
}
