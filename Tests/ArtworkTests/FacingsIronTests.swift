// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import Foundation
import GameCore
import Testing
@testable import Artwork

/// The Iron age's people and warriors in the five views (ruled 2026-11-21).
@Suite struct FacingsIron {
    /// Every key of a kind drawn in views, in every pose its side view has,
    /// frames 0 to 11, in each of the five views.
    static func keys(_ source: any ViewedSpriteSource, poses: [SpriteKey]) -> [SpriteKey] {
        poses.filter { source.drawsViews(of: $0.subject) }.flatMap { pose in
            SpriteView.allCases.flatMap { view in
                (0..<SpriteKey.framesPerPose).map { SpriteKey(pose.subject, pose.pose, frame: $0, view: view) }
            }
        }
    }

    @Test func everyViewOfThePeopleHasItsTeamColour() {
        let source = IronPeopleSprites()
        for key in Self.keys(source, poses: source.poses) {
            #expect(source.sprite(key)?.teamMask != nil, "\(key)")
        }
    }

    @Test func everyViewOfTheWarriorsHasItsTeamColour() {
        let source = IronWarriorSprites()
        for key in Self.keys(source, poses: source.poses) {
            #expect(source.sprite(key)?.teamMask != nil, "\(key)")
        }
    }

    /// The view reaches the drawing: the front differs from the side.
    @Test func theFrontIsNotTheSide() throws {
        let people = IronPeopleSprites(), warriors = IronWarriorSprites()
        let sources: [(any ViewedSpriteSource, [SpriteKey])] = [(people, people.poses), (warriors, warriors.poses)]
        for (source, poses) in sources {
            for pose in poses where source.drawsViews(of: pose.subject) {
                let side = try #require(source.sprite(pose)), front = try #require(source.sprite(SpriteKey(pose.subject, pose.pose, view: .front)))
                #expect(side.base.dataProvider?.data as Data? != front.base.dataProvider?.data as Data?, "\(pose)")
            }
        }
    }

    /// Every kind of both sources is drawn in views.
    @Test func everyKindIsDrawnInViews() {
        let people = IronPeopleSprites(), warriors = IronWarriorSprites()
        for kind: UnitKind in [.worker, .scholar, .engineer, .merchant] {
            #expect(people.drawsViews(of: .unit(kind, .iron)), "\(kind)")
        }
        for kind: UnitKind in [.swordsman, .horseman, .catapult] {
            #expect(warriors.drawsViews(of: .unit(kind, .iron)), "\(kind)")
        }
        #expect(!people.drawsViews(of: .unit(.worker, .bronze)))
    }
}

/// The pictures of the Iron age's kinds in views, written to the directory
/// named by `FACING_RENDERS`; skipped when it is not set: for each kind a sheet
/// of the eight facings in every pose at frame 0 and through the walk, and the
/// kind walking a circle, at twice game size.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["FACING_RENDERS"] != nil))
struct FacingsIronRenders {
    private let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["FACING_RENDERS"] ?? "/",
                                isDirectory: true)

    static let kinds: [(UnitKind, String)] = [(.worker, "the farmer (worker)"), (.scholar, "the philosopher (scholar)"),
                                              (.engineer, "the siege engineer (engineer)"), (.merchant, "the caravan trader (merchant)"),
                                              (.swordsman, "the swordsman"), (.horseman, "the horseman"), (.catapult, "the catapult")]

    static func canvas(_ kind: UnitKind) -> Canvas {
        IronPeopleLooks.look(kind) != nil ? IronPeopleLooks.canvas(kind) : IronWarriorsLooks.canvas(kind)
    }

    @Test(arguments: kinds.map(\.0)) func sheet(_ kind: UnitKind) throws {
        let title = Self.kinds.first { $0.0 == kind }!.1
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = GameSprites()
        let subject = SpriteSubject.unit(kind, .iron)
        let canvas = Self.canvas(kind)
        let facings: [Facing] = [.right, .downRight, .down, .downLeft, .left, .upLeft, .up, .upRight]
        let poses: [SpritePose] = [.standing, .walking, .working, .fighting].filter {
            source.sprite(SpriteKey(subject, $0)) != nil
        }
        let column = Double(canvas.pixelWidth) + 30, row = Double(canvas.pixelHeight) + 35, left = 140.0, top = 110.0
        let width = Int(left + column * Double(facings.count) + 40), height = Int(top + row * Double(poses.count + 3) + 40)
        let context = Raster.bitmap(width: width, height: height)!
        context.draw(Preview.ground(width: width, height: height, tile: 128), in: CGRect(x: 0, y: 0, width: width, height: height))
        Preview.label("The Iron age's \(title) facing eight ways: five views drawn, three mirrored; each pose at frame 0, then the walk at frames 3, 6 and 9",
                      in: context, at: CGPoint(x: 20, y: Double(height) - 40), size: 15)
        for (i, facing) in facings.enumerated() {
            Preview.label("\(facing)", in: context, at: CGPoint(x: left + Double(i) * column + 30, y: Double(height) - 80), size: 14)
        }
        let rows: [(String, SpritePose, Int)] = poses.map { ("\($0.rawValue)", $0, 0) }
            + [3, 6, 9].map { ("walking \($0)", SpritePose.walking, $0) }
        for (r, (name, pose, frame)) in rows.enumerated() {
            let ground = Double(height) - top - Double(r) * row - row * 0.85
            Preview.label(name, in: context, at: CGPoint(x: 16, y: ground + 40), size: 14)
            for (i, facing) in facings.enumerated() {
                let sprite = try #require(source.sprite(SpriteKey(subject, pose, frame: frame, view: facing.view)))
                let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: .of(.sumer))
                let at = CGPoint(x: left + Double(i) * column + column / 2, y: ground)
                context.saveGState()
                context.translateBy(x: at.x, y: 0)
                if facing.mirrored { context.scaleBy(x: -1, y: 1) }
                Preview.place(image, anchor: sprite.anchor, at: CGPoint(x: 0, y: at.y), in: context)
                context.restoreGState()
            }
        }
        try Preview.writePNG(context.makeImage()!, to: directory.appendingPathComponent("iron-\(kind)-facings.png"))
    }

    /// The kind walking a circle, one facing after another, 12 frames to each, at twice game size.
    @Test(arguments: kinds.map(\.0)) func round(_ kind: UnitKind) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = GameSprites()
        let subject = SpriteSubject.unit(kind, .iron)
        let walk: [(Facing, Double, Double)] = [(.right, 1, -1), (.downRight, 1, 0), (.down, 1, 1), (.downLeft, 0, 1),
                                               (.left, -1, 1), (.upLeft, -1, 0), (.up, -1, -1), (.upRight, 0, -1)]
        let large = Self.canvas(kind).width > 120
        let size = large ? 560 : 360, k = 2.0, stride = large ? 1.2 : 1.6
        var frames: [CGImage] = []
        let step = stride / 12
        var path: [(Double, Double)] = []
        var px = 0.0, py = 0.0
        for (_, dx, dy) in walk {
            let length = (dx * dx + dy * dy).squareRoot()
            for _ in 0..<12 { path.append((px, py)); px += dx / length * step; py += dy / length * step }
        }
        let mx = path.map(\.0).reduce(0, +) / Double(path.count), my = path.map(\.1).reduce(0, +) / Double(path.count)
        var n = 0
        for (facing, _, _) in walk {
            for frame in 0..<12 {
                let (x, y) = (path[n].0 - mx, path[n].1 - my)
                n += 1
                let context = Raster.bitmap(width: size, height: size)!
                context.draw(Preview.ground(width: size, height: size, tile: 128), in: CGRect(x: 0, y: 0, width: size, height: size))
                let sprite = try #require(source.sprite(SpriteKey(subject, .walking, frame: frame, view: facing.view)))
                let image = Preview.tinted(base: sprite.base, mask: sprite.teamMask, colour: .of(.sumer))
                let at = CGPoint(x: Double(size) / 2 + (x - y) * 32 * k, y: Double(size) / 2 - 70 - (x + y) * 16 * k)
                context.saveGState()
                context.translateBy(x: at.x, y: at.y)
                context.scaleBy(x: facing.mirrored ? -k : k, y: k)
                Preview.place(image, anchor: sprite.anchor, at: .zero, in: context)
                context.restoreGState()
                Preview.label("\(facing)", in: context, at: CGPoint(x: 12, y: Double(size) - 28), size: 16)
                frames.append(context.makeImage()!)
            }
        }
        try Preview.writeGIF(frames, to: directory.appendingPathComponent("iron-\(kind)-round.gif"))
    }
}
