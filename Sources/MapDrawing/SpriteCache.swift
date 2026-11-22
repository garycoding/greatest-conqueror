// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import Artwork
import CoreGraphics
import GameCore
import SpriteKit

/// A sprite ready for a node: textures, size in points, and the anchor point.
struct ResolvedSprite {
    var texture: SKTexture
    /// White where the team colour goes; `nil` for artwork without a mask and for placeholders.
    var mask: SKTexture?
    var size: CGSize
    var anchor: CGPoint
    var isPlaceholder: Bool
    /// How far the drawing's topmost solid pixel rises above the anchor, in
    /// points; known for the artwork's buildings, for hit-testing and the bars.
    var drawnHeight: Double? = nil
}

/// The height above the anchor of an image's topmost pixel that is more than
/// faintly opaque, in points (the image is at twice the size in points).
func drawnHeight(of image: CGImage, anchorY: Double) -> Double? {
    let width = image.width, height = image.height
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue),
          let data = context.data else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    let alpha = data.bindMemory(to: UInt8.self, capacity: width * height)
    // Row 0 of the bitmap's memory is the image's top row.
    for row in 0..<height {
        for column in 0..<width where alpha[row * width + column] > 40 {
            let fromBottom = Double(height - row)
            return (fromBottom - anchorY * Double(height)) / 2
        }
    }
    return nil
}

/// Turns the `SpriteSource`'s images into textures once, remembers what the
/// source did not supply (so that it is not asked again), and falls back as
/// docs/architecture.md, "Sprites", describes: the same pose at frame 0, then
/// `standing` (people) or `complete` (buildings), then a placeholder.
@MainActor
final class SpriteCache {
    let source: any SpriteSource
    let catalogue: Catalogue

    private enum Entry { case missing, found(ResolvedSprite) }
    private var artwork: [SpriteKey: Entry] = [:]

    private struct PersonKey: Hashable { var kind: UnitKind; var civilization: Civilization; var pose: String; var frame: Int }
    private struct BuildingKey: Hashable { var kind: BuildingKind; var civilization: Civilization; var constructing: Bool }
    private struct TerrainKey: Hashable { var terrain: Terrain; var variant: Int; var dimmed: Bool }
    private struct SiteKey: Hashable { var kind: SiteKind; var afloat: Bool; var frame: Int }
    private var people: [PersonKey: ResolvedSprite] = [:]
    private var buildings: [BuildingKey: ResolvedSprite] = [:]
    private var sites: [SiteKey: ResolvedSprite] = [:]
    private var sitePlaceholders: [SiteKind: ResolvedSprite] = [:]
    private var outcrop: ResolvedSprite?
    private var outcropAfloat: ResolvedSprite?
    private var terrainTextures: [TerrainKey: (texture: SKTexture, size: CGSize)] = [:]
    private var variantCounts: [Terrain: Int] = [:]
    private var footprints: [BuildingKind: GridPoint] = [:]

    init(source: any SpriteSource, catalogue: Catalogue) {
        self.source = source
        self.catalogue = catalogue
    }

    func footprint(_ kind: BuildingKind) -> GridPoint {
        if let known = footprints[kind] { return known }
        let size = catalogue.stats(kind).footprint
        footprints[kind] = size
        return size
    }

    // MARK: Artwork

    private func supplied(_ key: SpriteKey) -> ResolvedSprite? {
        if let entry = artwork[key] {
            if case .found(let sprite) = entry { return sprite }
            return nil
        }
        guard let image = source.sprite(key) else { artwork[key] = .missing; return nil }
        let size = CGSize(width: Double(image.base.width) / 2, height: Double(image.base.height) / 2)
        var sprite = ResolvedSprite(texture: SKTexture(cgImage: image.base),
                                    mask: image.teamMask.map { SKTexture(cgImage: $0) },
                                    size: size, anchor: CGPoint(x: image.anchor.x, y: image.anchor.y), isPlaceholder: false)
        if case .building = key.subject { sprite.drawnHeight = drawnHeight(of: image.base, anchorY: image.anchor.y) }
        artwork[key] = .found(sprite)
        return sprite
    }

    private func suppliedWithFallback(_ subject: SpriteSubject, pose: SpritePose, frame: Int, fallback: SpritePose,
                                      view: SpriteView = .side) -> ResolvedSprite? {
        // A view the artwork does not yet draw falls back to the side (ruled 2026-11-21: five views, drawn batch by batch).
        if view != .side {
            if let found = supplied(SpriteKey(subject, pose, frame: frame, view: view))
                ?? supplied(SpriteKey(subject, pose, frame: 0, view: view)) { return found }
        }
        return supplied(SpriteKey(subject, pose, frame: frame))
            ?? supplied(SpriteKey(subject, pose, frame: 0))
            ?? supplied(SpriteKey(subject, fallback, frame: frame))
            ?? supplied(SpriteKey(subject, fallback, frame: 0))
    }

    // MARK: Entities and sites

    /// The sprite of a person or building: the source's, else a placeholder.
    func sprite(for kind: EntityKind, subject: SpriteSubject, civilization: Civilization,
                pose: SpritePose, frame: Int, view: SpriteView = .side) -> ResolvedSprite {
        switch kind {
        case .unit(let unit):
            if let found = suppliedWithFallback(subject, pose: pose, frame: frame, fallback: .standing, view: view) {
                return found
            }
            let key = PersonKey(kind: unit, civilization: civilization, pose: pose.rawValue, frame: frame % 2)
            if let known = people[key] { return known }
            let drawn = Placeholders.person(unit, civilization: civilization, pose: Placeholders.figurePose(pose), frame: frame)
            let sprite = Self.placeholder(drawn)
            people[key] = sprite
            return sprite
        case .building(let building):
            if let found = suppliedWithFallback(subject, pose: pose, frame: frame, fallback: .complete, view: view) { return found }
            let constructing = pose == .underConstruction
            let key = BuildingKey(kind: building, civilization: civilization, constructing: constructing)
            if let known = buildings[key] { return known }
            let drawn = Placeholders.building(building, civilization: civilization, constructing: constructing,
                                              footprint: footprint(building))
            let sprite = Self.placeholder(drawn)
            buildings[key] = sprite
            return sprite
        }
    }

    /// The sprite of a site at a frame of its animation: `afloat` on a water
    /// tile (ruled 2026-11-21), falling back to `complete`, then to frame 0,
    /// then to a placeholder.
    func sprite(forSite kind: SiteKind, afloat: Bool = false, frame: Int = 0) -> ResolvedSprite {
        let key = SiteKey(kind: kind, afloat: afloat, frame: frame)
        if let known = sites[key] { return known }
        let sprite = suppliedWithFallback(.site(kind), pose: afloat ? .afloat : .complete, frame: frame, fallback: .complete)
            ?? sitePlaceholder(kind)
        sites[key] = sprite
        return sprite
    }

    private func sitePlaceholder(_ kind: SiteKind) -> ResolvedSprite {
        if let known = sitePlaceholders[kind] { return known }
        let sprite = Self.placeholder(Placeholders.site(kind))
        sitePlaceholders[kind] = sprite
        return sprite
    }

    /// The outcrop on land, or rising from the water (falling back to the land picture).
    func spriteForOutcrop(afloat: Bool = false) -> ResolvedSprite {
        if afloat {
            if let known = outcropAfloat { return known }
            let sprite = supplied(SpriteKey(.outcrop, .afloat)) ?? spriteForOutcrop()
            outcropAfloat = sprite
            return sprite
        }
        if let known = outcrop { return known }
        let sprite = supplied(SpriteKey(.outcrop, .complete)) ?? Self.placeholder(Placeholders.outcrop())
        outcrop = sprite
        return sprite
    }

    private static func placeholder(_ drawn: DrawnImage) -> ResolvedSprite {
        ResolvedSprite(texture: SKTexture(cgImage: drawn.image), mask: nil, size: drawn.size, anchor: drawn.anchor, isPlaceholder: true)
    }

    // MARK: Terrain

    /// How many variants of a terrain there are to choose between: those the source
    /// supplies from 0 on, else the placeholder's two.
    func variantCount(_ terrain: Terrain) -> Int {
        if let known = variantCounts[terrain] { return known }
        var count = 0
        while count < 8, supplied(SpriteKey(.terrain(terrain, variant: count), .complete)) != nil { count += 1 }
        let result = max(count, count == 0 ? 2 : 1)
        variantCounts[terrain] = result
        return result
    }

    /// The tile texture of a terrain: the source's, else a placeholder diamond; and
    /// the same darkened, for ground explored but not in sight.
    func terrainTexture(_ terrain: Terrain, variant: Int, dimmed: Bool) -> (texture: SKTexture, size: CGSize) {
        let key = TerrainKey(terrain: terrain, variant: variant, dimmed: dimmed)
        if let known = terrainTextures[key] { return known }
        let made: (SKTexture, CGSize)
        if let found = supplied(SpriteKey(.terrain(terrain, variant: variant), .complete)) {
            let size = found.size
            if dimmed, let image = source.sprite(SpriteKey(.terrain(terrain, variant: variant), .complete))?.base {
                made = (SKTexture(cgImage: Placeholders.darkened(image)), size)
            } else {
                made = (found.texture, size)
            }
        } else {
            made = (SKTexture(cgImage: Placeholders.terrain(terrain, variant: variant, dimmed: dimmed)), Placeholders.terrainSize)
        }
        terrainTextures[key] = made
        return made
    }
}
