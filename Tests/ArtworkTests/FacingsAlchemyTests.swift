// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// The people and warriors of the Alchemy age in the five views (ruled
/// 2026-11-21): every kind of `AlchemyPeopleSprites` and
/// `AlchemyWarriorSprites` is drawn in every view, in every pose its side view
/// has, at every frame, with the team's colour, and each view is a drawing of
/// its own rather than the side's.
@Suite(.serialized) struct FacingsAlchemyTests {
    private let people = AlchemyPeopleSprites()
    private let warriors = AlchemyWarriorSprites()

    /// The kinds of both sources, and the source that draws each.
    private var kinds: [(UnitKind, any ViewedSpriteSource, [SpriteKey])] {
        let sources: [(any ViewedSpriteSource, [SpriteKey])] = [(people, people.poses), (warriors, warriors.poses)]
        return sources.flatMap { source, poses in
            var seen: [UnitKind] = []
            for key in poses { if case .unit(let kind, _) = key.subject, !seen.contains(kind) { seen.append(kind) } }
            return seen.map { kind in (kind, source, poses.filter { $0.subject == .unit(kind, .alchemy) }) }
        }
    }

    @Test func everyKindIsDrawnInEveryView() {
        #expect(kinds.map(\.0) == [.worker, .soldier3, .knight2, .cannon1])
        for (kind, source, _) in kinds {
            #expect(source.drawsViews(of: .unit(kind, .alchemy)), "\(kind)")
        }
    }

    @Test func everyKeyInEveryViewHasASpriteWithTheTeamsColour() throws {
        for (kind, source, poses) in kinds {
            for pose in poses.map(\.pose) {
                for frame in 0..<SpriteKey.framesPerPose {
                    let side = try #require(source.sprite(SpriteKey(.unit(kind, .alchemy), pose, frame: frame)))
                    for view in SpriteView.allCases where view != .side {
                        let key = SpriteKey(.unit(kind, .alchemy), pose, frame: frame, view: view)
                        let sprite = try #require(source.sprite(key), "\(key)")
                        let mask = try #require(sprite.teamMask, "\(key) has no team colour")
                        #expect(Self.covered(mask), "\(key): the team's colour is hidden")
                        #expect(Self.bytes(sprite.base) != Self.bytes(side.base), "\(key) is the side view")
                    }
                }
            }
        }
    }

    @Test func aViewOfAPoseTheKindLacksHasNoSprite() {
        #expect(warriors.sprite(SpriteKey(.unit(.knight2, .alchemy), .working, view: .front)) == nil)
    }

    /// Whether any pixel of a mask is set.
    static func covered(_ mask: CGImage) -> Bool {
        let data = bytes(mask)
        let step = mask.bitsPerPixel / 8
        return stride(from: 0, to: data.count, by: step).contains { data[$0 + step - 1] > 0 || data[$0] > 0 }
    }

    static func bytes(_ image: CGImage) -> [UInt8] {
        guard let data = image.dataProvider?.data, let pointer = CFDataGetBytePtr(data) else { return [] }
        return Array(UnsafeBufferPointer(start: pointer, count: CFDataGetLength(data)))
    }
}

/// The pictures of the Alchemy people and warriors in their views, written to
/// the directory named by `FACING_RENDERS`; skipped when it is not set: for
/// each kind, a sheet of the eight facings in every pose and through the walk,
/// and the kind walking a circle, one facing after another.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["FACING_RENDERS"] != nil))
struct FacingsAlchemyRenders {
    private let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["FACING_RENDERS"] ?? "/",
                                isDirectory: true)

    @Test(arguments: [UnitKind.worker])
    func thePeople(_ kind: UnitKind) throws {
        try sheet(kind, source: AlchemyPeopleSprites(), width: Canvas.person.width)
        try round(kind, source: AlchemyPeopleSprites(), canvas: .person)
        try closeUp(kind, look: try #require(AlchemyPeopleLooks.look(kind)), canvas: .person)
    }

    @Test(arguments: [UnitKind.knight2, .soldier3, .cannon1])
    func theWarriors(_ kind: UnitKind) throws {
        let width = AlchemyWarriorsLooks.canvas(kind).width
        try sheet(kind, source: AlchemyWarriorSprites(), width: width)
        try round(kind, source: AlchemyWarriorSprites(), canvas: AlchemyWarriorsLooks.canvas(kind))
        try closeUp(kind, look: try #require(AlchemyWarriorsLooks.look(kind)), canvas: AlchemyWarriorsLooks.canvas(kind))
    }

    /// The five views of each pose close up, at frame 0 and at the pose's
    /// middle, at four times game size.
    private func closeUp(_ kind: UnitKind, look: any PersonLook, canvas base: Canvas) throws {
        let canvas = base.scaled(to: 4)
        let poses: [SpritePose] = [.standing, .walking, .working, .fighting].filter { look.rig($0, 0) != nil }
        let views = SpriteView.allCases
        let cell = Int(canvas.width * 4) + 10, rowHeight = Int(canvas.height * 4) + 10
        let rows = poses.flatMap { [($0, 0), ($0, 6)] }
        let width = cell * views.count, height = rowHeight * rows.count
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 256), in: CGRect(x: 0, y: 0, width: width, height: height))
        for (r, (pose, frame)) in rows.enumerated() {
            for (i, view) in views.enumerated() {
                let drawn = try #require(look.render(pose, frame: frame, canvas: canvas, view: view))
                let image = Preview.tinted(base: drawn.base, mask: drawn.mask, colour: .of(.sumer))
                let y = Double(height - (r + 1) * rowHeight) + 30
                Preview.place(image, anchor: canvas.anchor, at: CGPoint(x: Double(i * cell + cell / 2), y: y), in: context)
                Preview.label("\(pose.rawValue) \(frame), \(view.rawValue)", in: context, at: CGPoint(x: Double(i * cell + 12), y: y - 24), size: 18)
            }
        }
        try Preview.writePNG(context.makeImage()!, to: directory.appendingPathComponent("alchemy-\(kind)-close.png"))
    }

    /// The eight facings in the order of a turn.
    private let facings: [Facing] = [.right, .downRight, .down, .downLeft, .left, .upLeft, .up, .upRight]

    /// A sprite placed at `at`, mirrored where its facing is.
    private func place(_ sprite: SpriteImage, facing: Facing, at: CGPoint, in context: CGContext, scale: Double = 1) {
        let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: .of(.sumer))
        context.saveGState()
        context.translateBy(x: at.x, y: at.y)
        context.scaleBy(x: facing.mirrored ? -scale : scale, y: scale)
        Preview.place(image, anchor: sprite.anchor, at: .zero, in: context)
        context.restoreGState()
    }

    /// A sheet in the manner of `FacingRenders.sheet`: the eight facings by
    /// pose at frame 0, then the walk at frames 3, 6 and 9.
    private func sheet(_ kind: UnitKind, source: any SpriteSource, width canvasWidth: Double) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let subject = SpriteSubject.unit(kind, .alchemy)
        let poses: [SpritePose] = [.standing, .walking, .working, .fighting].filter { source.sprite(SpriteKey(subject, $0)) != nil }
        let column = 150 * max(1, canvasWidth / Canvas.person.width), row = 170.0, left = 140.0, top = 110.0
        let width = Int(left + column * Double(facings.count) + 40), height = Int(top + row * Double(poses.count + 3) + 40)
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 128), in: CGRect(x: 0, y: 0, width: width, height: height))
        Preview.label("The Alchemy \(kind) facing eight ways: five views drawn, three mirrored; each pose at frame 0, then the walk at frames 3, 6 and 9",
                      in: context, at: CGPoint(x: 20, y: Double(height) - 40), size: 15)
        for (i, facing) in facings.enumerated() {
            Preview.label("\(facing)", in: context, at: CGPoint(x: left + Double(i) * column + 30, y: Double(height) - 80), size: 14)
        }
        let rows: [(String, SpritePose, Int)] = poses.map { ("\($0.rawValue)", $0, 0) } + [3, 6, 9].map { ("walking \($0)", .walking, $0) }
        for (r, (name, pose, frame)) in rows.enumerated() {
            let ground = Double(height) - top - Double(r) * row - row * 0.85
            Preview.label(name, in: context, at: CGPoint(x: 16, y: ground + 40), size: 14)
            for (i, facing) in facings.enumerated() {
                let sprite = try #require(source.sprite(SpriteKey(subject, pose, frame: frame, view: facing.view)))
                place(sprite, facing: facing, at: CGPoint(x: left + Double(i) * column + column / 2, y: ground), in: context)
            }
        }
        try Preview.writePNG(context.makeImage()!, to: directory.appendingPathComponent("alchemy-\(kind)-facings.png"))
    }

    /// The kind walking a circle, one facing after another, 12 frames to each,
    /// at game size enlarged twice, in the manner of `FacingRenders.round`.
    private func round(_ kind: UnitKind, source: any SpriteSource, canvas: Canvas) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let subject = SpriteSubject.unit(kind, .alchemy)
        let walk: [(Facing, Double, Double)] = [(.right, 1, -1), (.downRight, 1, 0), (.down, 1, 1), (.downLeft, 0, 1),
                                               (.left, -1, 1), (.upLeft, -1, 0), (.up, -1, -1), (.upRight, 0, -1)]
        let wide = canvas.width / Canvas.person.width, tall = canvas.height / Canvas.person.height
        let size = Int(480 * max(1, wide * 0.85, tall)), k = 2.0, stride = wide > 1.5 ? 1.0 : 1.6
        let step = stride / 12
        var path: [(Double, Double)] = []
        var px = 0.0, py = 0.0
        for (_, dx, dy) in walk {
            let length = (dx * dx + dy * dy).squareRoot()
            for _ in 0..<12 { path.append((px, py)); px += dx / length * step; py += dy / length * step }
        }
        let mx = path.map(\.0).reduce(0, +) / Double(path.count), my = path.map(\.1).reduce(0, +) / Double(path.count)
        var frames: [CGImage] = []
        var n = 0
        for (facing, _, _) in walk {
            for frame in 0..<12 {
                let (x, y) = (path[n].0 - mx, path[n].1 - my)
                n += 1
                let context = Raster.bitmap(width: size, height: size)!
                context.draw(Preview.ground(width: size, height: size, tile: 128), in: CGRect(x: 0, y: 0, width: size, height: size))
                let sprite = try #require(source.sprite(SpriteKey(subject, .walking, frame: frame, view: facing.view)))
                let at = CGPoint(x: Double(size) / 2 + (x - y) * 32 * k, y: Double(size) / 2 - 70 * tall - (x + y) * 16 * k)
                place(sprite, facing: facing, at: at, in: context, scale: k)
                Preview.label("\(facing)", in: context, at: CGPoint(x: 12, y: Double(size) - 28), size: 16)
                frames.append(context.makeImage()!)
            }
        }
        try Preview.writeGIF(frames, to: directory.appendingPathComponent("alchemy-\(kind)-round.gif"))
    }
}
