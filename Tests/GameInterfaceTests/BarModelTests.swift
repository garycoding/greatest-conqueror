// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import CoreGraphics
import GameCore
import Testing
@testable import GameInterface

// MARK: Resource bar

@Test func theResourceBarShowsTheResourcesOfTheAgesReached() {
    let stone = ResourceBarModel(view: Samples.stoneAgeOpening())
    #expect(stone.ageName == "Stone")
    #expect(stone.items.map(\.resource) == [.food, .wood, .stone])
    #expect(stone.items.map(\.amount) == [180, 140, 50])
    #expect(stone.populationText == "5 of 5" && stone.isPopulationFull)
    #expect(stone.civilizationName == "Sumer")
    let bronze = ResourceBarModel(view: Samples.bronzeAgeSkirmish())
    #expect(bronze.ageName == "Bronze")
    #expect(bronze.items.map(\.resource) == [.food, .wood, .stone, .bronze, .gold])
    #expect(bronze.items.map(\.amount) == [420, 310, 120, 85, 60])
    #expect(bronze.populationText == "15 of 15")
}

@Test func thePopulationIsNotFullWithRoom() {
    var view = Samples.stoneAgeOpening()
    view.populationLimit = 10
    #expect(!ResourceBarModel(view: view).isPopulationFull)
}

// MARK: Age progress

@Test func studyInProgressShowsNoAdvanceButton() {
    let m = AgeProgressModel(view: Samples.stoneAgeOpening(), catalogue: .standard)
    #expect(m.nextAge == .bronze)
    #expect(m.progress == 0.15 && m.percentText == "15%")
    #expect(!m.showsAdvance)
    #expect(m.caption == "Study toward the Bronze age")
    #expect(m.advanceOffer?.unavailable?.refusal == .studyIncomplete)
}

@Test func completedStudyShowsAdvanceWithItsCost() {
    var view = Samples.stoneAgeOpening()
    view.ageProgress = 1
    view.resources = ResourceAmounts([.food: 400, .wood: 150])
    let m = AgeProgressModel(view: view, catalogue: .standard)
    #expect(m.showsAdvance)
    #expect(m.advanceOffer?.cost == ResourceAmounts([.food: 300, .wood: 100]))
    #expect(m.advanceOffer?.isAvailable == true)
    #expect(m.advanceOffer?.order == .advanceAge)
    #expect(m.caption == "Study of the Bronze age complete")
}

@Test func completedStudyWithTooLittleStillShowsAdvanceAndSaysWhatIsShort() {
    var view = Samples.stoneAgeOpening()
    view.ageProgress = 1   // 180 food, 140 wood held
    let m = AgeProgressModel(view: view, catalogue: .standard)
    #expect(m.showsAdvance)
    #expect(m.advanceOffer?.unavailable?.refusal == .notEnough(ResourceAmounts([.food: 120])))
    #expect(m.advanceOffer?.unavailable?.explanation == "Short of 120 Food")
}

@Test func theCatalogueHasNoStepFromIndustrialYet() {
    var view = Samples.bronzeAgeSkirmish()
    view.age = .industrial
    let m = AgeProgressModel(view: view, catalogue: .standard)
    #expect(m.advanceOffer == nil && !m.showsAdvance)
    #expect(m.caption == "The Silicon age is not yet part of the game")
}

@Test func progressIsHeldWithinZeroAndOne() {
    var view = Samples.stoneAgeOpening()
    view.ageProgress = 1.4
    #expect(AgeProgressModel(view: view, catalogue: .standard).progress == 1)
}

// MARK: Pause

@Test func pauseTurnsBothWays() {
    var view = Samples.stoneAgeOpening()
    #expect(PauseModel(view: view).order == .setPaused(true) && PauseModel(view: view).title == "Pause")
    view.isPaused = true
    #expect(PauseModel(view: view).order == .setPaused(false) && PauseModel(view: view).title == "Resume")
}

@MainActor
@Test func thePauseButtonIssuesTheOrderThroughTheSession() {
    let (session, recorder) = makeSession(Samples.stoneAgeOpening())
    session.issue(PauseModel(view: session.view).order)
    #expect(recorder.orders == [.setPaused(true)])
}

// MARK: Match over

@Test func theTeamThatWonSeesVictory() {
    var view = Samples.stoneAgeOpening()
    view.outcome = .won(TeamID(0))
    let m = MatchOverModel(view: view)
    #expect(m?.isVictory == true && m?.title == "Victory")
}

@Test func anotherTeamsWinIsADefeat() {
    var view = Samples.stoneAgeOpening()
    view.outcome = .won(TeamID(1))
    let m = MatchOverModel(view: view)
    #expect(m?.isVictory == false && m?.title == "Defeat")
    #expect(m?.message == "Egypt won the match.")
}

@Test func noOutcomeNoScreen() {
    #expect(MatchOverModel(view: Samples.stoneAgeOpening()) == nil)
}

// MARK: Refusal banner

@MainActor
@Test func theBannerClearsTheRefusalAfterItsTime() async {
    let (session, _) = makeSession(Samples.stoneAgeOpening())
    session.lastRefusal = .populationLimit
    await RefusalBanner.expire(session, after: 0.05, matching: .populationLimit)
    #expect(session.lastRefusal == nil)
}

@MainActor
@Test func theBannerLeavesANewerRefusalAlone() async {
    let (session, _) = makeSession(Samples.stoneAgeOpening())
    session.lastRefusal = .populationLimit
    let waiting = Task { await RefusalBanner.expire(session, after: 0.05, matching: .populationLimit) }
    session.lastRefusal = .notNow
    await waiting.value
    #expect(session.lastRefusal == .notNow)
}

// MARK: Small map

private let square = CGSize(width: 300, height: 150)

@Test func theSmallMapFitsTheMapInItsRectangle() {
    let g = MiniMapGeometry(mapWidth: 32, mapHeight: 32, size: square)
    // The map's top corner is at the top, the bottom corner at the bottom, in the middle.
    let top = g.point(for: MapPosition(x: 0, y: 0)), bottom = g.point(for: MapPosition(x: 32, y: 32))
    #expect(abs(top.x - 150) < 1e-6 && abs(top.y) < 1e-6)
    #expect(abs(bottom.x - 150) < 1e-6 && abs(bottom.y - 150) < 1e-6)
    let right = g.point(for: MapPosition(x: 32, y: 0)), left = g.point(for: MapPosition(x: 0, y: 32))
    #expect(abs(right.x - 300) < 1e-6 && abs(left.x) < 1e-6 && abs(right.y - 75) < 1e-6)
}

@Test func aPointOnTheSmallMapGivesBackTheMapPosition() {
    for (w, h) in [(32, 32), (96, 96), (40, 24)] {
        let g = MiniMapGeometry(mapWidth: w, mapHeight: h, size: square)
        for p in [MapPosition(x: 3.25, y: 7.5), MapPosition(x: Double(w) / 2, y: Double(h) / 2), MapPosition(x: Double(w) - 1, y: 2)] {
            let back = g.position(at: g.point(for: p))
            #expect(abs(back.x - p.x) < 1e-6 && abs(back.y - p.y) < 1e-6, "\(w)x\(h) \(p)")
        }
    }
}

@Test func theCentreOfTheSmallMapIsTheCentreOfTheMap() {
    let g = MiniMapGeometry(mapWidth: 32, mapHeight: 32, size: square)
    let p = g.position(at: CGPoint(x: 150, y: 75))
    #expect(abs(p.x - 16) < 1e-6 && abs(p.y - 16) < 1e-6)
}

@Test func aClickOutsideTheDiamondIsHeldWithinTheMap() {
    let g = MiniMapGeometry(mapWidth: 32, mapHeight: 32, size: square)
    for point in [CGPoint(x: 0, y: 0), CGPoint(x: 300, y: 150), CGPoint(x: -50, y: 400)] {
        let p = g.position(at: point)
        #expect(p.x >= 0 && p.x <= 32 && p.y >= 0 && p.y <= 32)
    }
}

@MainActor
@Test func aClickOnTheSmallMapSetsTheCamerasCentre() {
    let (session, recorder) = makeSession(Samples.stoneAgeOpening())
    let g = MiniMapGeometry(mapWidth: session.view.mapWidth, mapHeight: session.view.mapHeight, size: square)
    // The point where the map position (9.5, 9.5), the town centre, lies.
    let click = g.point(for: MapPosition(x: 9.5, y: 9.5))
    MiniMapControl.point(click, geometry: g, session: session)
    #expect(abs(session.camera.centre.x - 9.5) < 1e-6 && abs(session.camera.centre.y - 9.5) < 1e-6)
    // A different spot: toward the lake in the south-east.
    MiniMapControl.point(g.point(for: MapPosition(x: 25, y: 25)), geometry: g, session: session)
    #expect(abs(session.camera.centre.x - 25) < 1e-6 && abs(session.camera.centre.y - 25) < 1e-6)
    #expect(session.camera.zoom == 1)
    #expect(recorder.orders.isEmpty)   // moving the view gives no order
}

@Test func theCameraOutlineSitsAroundItsCentreAndShrinksWithZoom() {
    let g = MiniMapGeometry(mapWidth: 32, mapHeight: 32, size: square)
    let viewport = CGSize(width: 1000, height: 600)
    let near = g.cameraRect(Camera(centre: MapPosition(x: 16, y: 16), zoom: 1), viewport: viewport)
    #expect(abs(near.midX - 150) < 1e-6 && abs(near.midY - 75) < 1e-6)
    #expect(abs(near.width - 1000 * g.scale) < 1e-6)
    let closer = g.cameraRect(Camera(centre: MapPosition(x: 16, y: 16), zoom: 2), viewport: viewport)
    #expect(abs(closer.width - near.width / 2) < 1e-6)
}

@Test func theRasterBlacksOutWhatIsUnexploredAndDullsWhatIsOutOfSight() {
    let view = Samples.stoneAgeOpening()
    #expect(MiniMapRaster.image(for: view)?.width == 32)
    #expect(MiniMapRaster.rgba(for: view, x: 31, y: 31) == [0, 0, 0, 255])               // far corner, unexplored
    let near = MiniMapRaster.rgba(for: view, x: 9, y: 9)                                // visible grass
    #expect(near == [161, 186, 117, 255])
    var explored = view
    explored.visibility[9 * 32 + 9] = .explored
    #expect(MiniMapRaster.rgba(for: explored, x: 9, y: 9)[0] < near[0])
}

@Test func theSmallMapMarksOwnAndAlliesAndOnlyOpponentsInSight() {
    var view = Samples.bronzeAgeSkirmish()
    #expect(MiniMapRaster.marked(view).count == view.entities.count)
    // Hide the opponents' tiles: their entities drop out, ours stay.
    for e in view.entities where e.owner != view.player {
        view.visibility[e.position.tile.y * view.mapWidth + e.position.tile.x] = .explored
    }
    let marked = MiniMapRaster.marked(view)
    #expect(marked.allSatisfy { $0.owner == view.player })
    #expect(marked.count == view.entities.filter { $0.owner == view.player }.count)
}
