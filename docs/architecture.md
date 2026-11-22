# Architecture

How the code of Greatest Conqueror is divided, and the rules that hold the parts together. What the game must do is in [`requirements.md`](requirements.md); the design decisions are in [`design.md`](design.md).

## Modules

The game is one Swift package. `Package.swift` declares every module, and each module lives in `Sources/<Module>/` with its tests in `Tests/<Module>Tests/`.

| Module | What it holds | Depends on |
|---|---|---|
| `GameCore` | The types every module shares: the vocabulary, the map, orders, the player's view, the catalogue of costs and strengths, the session shared by the map and the panels, the projection, sprite keys, and sample states for tests | nothing |
| `GameSimulation` | The rules: a type conforming to `GameSimulating` | `GameCore` |
| `MapGeneration` | A type conforming to `MapGenerating` | `GameCore` |
| `ComputerPlayer` | A type conforming to `ComputerPlaying` | `GameCore` |
| `Artwork` | The sprites, and a type conforming to `SpriteSource` that supplies them | `GameCore` |
| `MapDrawing` | The SpriteKit scene that draws a `PlayerView` and turns clicks into selections and orders | `GameCore`, `Artwork` |
| `GameInterface` | The SwiftUI views around the map: the resource bar, the selection panel, the small map, the age progress, and the match screens | `GameCore` |
| `GameNetwork` | Setting up, finding and joining a match on the LAN (a later milestone) | `GameCore` |
| `GreatestConqueror` | The app: it owns the simulation, runs the loop, and joins the others | all |

A module uses another only through the types in `GameCore` and the protocols named here, never through its internals.

## Who may change what

`GameCore`, `Package.swift` and `Sources/Artwork/SpriteSource.swift` (the sprite seam) are shared by every module. Whilst modules are being built in parallel, only the coordinating session changes them, each change in its own pull request, after which `develop` is brought into the other branches. An agent that needs a change to either reports it and does not make it.

## The seams

- **`GameSimulating`** (in `GameSimulation`). Created from a `MatchSetup`; takes `Order`s from players; advances one tick at a time with `step()`; reports a `PlayerView` for each player; gives a `checksum()` of its whole state. It is a Codable value, so that encoding it saves a match.
- **`MapGenerating`** (in `MapGeneration`). Turns a `MapRequest` into a `GameMap`. The same request gives the same map.
- **`ComputerPlaying`** (in `ComputerPlayer`). Given its player's `PlayerView` and the `Catalogue`, returns orders. It sees only what its player sees and acts only through orders, as a person does.
- **`SpriteSource`** (in `Artwork`). Given a `SpriteKey`, returns a `SpriteImage` or `nil`. The drawing shows a placeholder shape for `nil`, so neither waits for the other.
- **`PlayerSession`** (in `GameCore`). The state one person's screen shares between the map and the panels: the latest view, the selection, the camera, a building being placed, numbered groups, and the last refusal. The app owns it and passes it to `MapDrawing` and `GameInterface`.
  - `MapDrawing` owns clicks and dragged boxes on the map: it changes the selection, places buildings, and issues orders.
  - `GameInterface` owns the panels: its buttons issue orders and set `placing`; a click on the small map moves the camera; it shows `lastRefusal`.
  - Both issue orders through `PlayerSession.issue`, never to the simulation directly. Orders flow one way: `issue` returns nothing, and a refusal comes back as `GameEvent.refused` in a later view, which `PlayerSession.update` turns into `lastRefusal`. The simulation therefore need not run on the main actor, and a second Mac can send orders across the LAN in the same way.

`Placement` in `GameCore` is the one rule for where things may stand: a tile is blocked by impassable terrain, a building's footprint, or a tree, stone or metal deposit that remains (`SiteKind.blocksTile`); a building may be placed where every tile of its footprint is inside the map, buildable, unblocked and explored. The simulation, the drawing's placement outline and the computer player all use it.

The rules a reader could take two ways are settled in the documentation of `Order` (copper and tin, what scholars do at a building) and of `GameSimulating` (refusals, the checksum).

`Samples` in `GameCore` gives fixed maps and views (`stoneAgeOpening`, `bronzeAgeSkirmish`, `twoPlayerSetup`), so that the drawing, the interface and the computer player can be built and tested before the simulation exists.

## Time

The simulation advances in ticks, `Tick.rate` (20) a second. Every duration in the catalogue is in ticks. The match is held by `MatchHost` (in `GameNetwork`), which the app and the match tests both drive: each tick it gives each computer player its own view four times a second, spread across the ticks, applies the orders, and steps the simulation. The app advances it 20 ticks a second from a timer, times the speed chosen in the Speed menu (1× to 4×, requirement 29), running at most five ticks in one frame after a stall, and hands the person's session a fresh view each frame. `MatchHost` is `Codable`, so a saved match holds the computer players as well as the simulation (requirement 23).

## Determinism

The same setup and the same orders at the same ticks give the same result, in any process. Saving and resuming depend on it, and so do the tests that play whole matches.

- All randomness comes from `SeededGenerator`, held in the state that uses it. `SystemRandomNumberGenerator` and `Double.random` without a generator are not used in `GameSimulation`, `MapGeneration` or `ComputerPlayer`.
- Collections whose order affects an outcome are arrays kept in a fixed order (entities by `EntityID`, sites by `SiteID`). The order of a `Dictionary` or a `Set` differs between processes, so neither is iterated where the order matters; looking a value up is fine.
- Determinism tests compare `checksum()` against a stored value, which a second process would reproduce, and not merely two runs in one process.

## Projection

The map is seen at an angle (requirement 24), as an isometric projection in which a tile is a diamond 64 points wide and 32 high (`Projection.tileWidth`, `Projection.tileHeight`). Map +x runs toward the lower right of the screen and +y toward the lower left; the map's origin is at the top. Things farther down the screen are nearer the viewer and are drawn in front: draw in increasing order of `Projection.depth`. `Projection.screen` and `Projection.map` convert between map positions and screen points at zoom 1.

A building's footprint (`BuildingStats.footprint`) covers tiles from its origin tile toward +x and +y.

## Sprites

- **Keys.** A sprite is named by a `SpriteKey`, whose subject for an entity is chosen by `SpriteSubject.of(_:ownerAge:)` in both the drawing and the artwork: a subject (a person of a kind at an age, a building in an age's style, a site, or a terrain tile), a pose, and a frame. `SpriteKey.required(through:)` lists every picture a milestone needs; it is the artwork's checklist.
- **Poses.** `standing`, `walking`, `working` and `fighting` for people; `complete` and `under-construction` for buildings. Poses are open-ended strings, so that the art style guide can add more; the drawing falls back to `standing` or `complete` where a pose is missing. A pose is a cycle of 12 frames, shown at 12 frames a second ([`art-style.md`](art-style.md#movement)). A site on a water tile is asked for in the pose `afloat` (ruled 2026-11-21: a rock rising from the water, with no shadow on the ground), falling back to `complete`. A site that moves, such as the fish, is drawn as a cycle of 12 frames too; the drawing runs each tile's cycle a number of frames ahead (`SiteNode.frameOffset`), so that neighbouring tiles, and the four tiles of a shoal, do not move in unison.
- **Facing.** A person faces one of eight directions on the screen, chosen from the way it moves (`Facing.of`; ruled 2026-11-21). Five views are drawn (`SpriteView`: side, front-quarter, front, back and back-quarter, each facing right or toward the viewer's right), and the drawing mirrors them for the three facings toward the left. A source that draws views is a `ViewedSpriteSource`; where a view is not drawn, the drawing falls back to the side.
- **Size.** Pictures are drawn at twice their size in points, for Retina displays. A person stands about 48 points tall on a tile 64 points wide; a building covers its footprint's diamonds.
- **Anchor.** `SpriteImage.anchor` is the point of the image placed on the entity's `EntityView.position`: for a person, between its feet; for a building, the centre of its footprint at ground level, which on screen is the centre of the footprint's diamond; for a boat, the middle of its hull on the waterline. It is a fraction of the image with (0, 0) at the bottom left.
- **Team colour.** A sprite has a base image and, where it carries a civilization's colour, a mask: white where the colour goes. The drawing tints the mask with `TeamColour.of(civilization)` and lays it over the base, so that one picture serves every civilization.
- **The batches.** Each batch of artwork supplies its own `SpriteSource`; `GameSprites` asks them in turn, and the drawing shows a placeholder for a key none answers. The drawing measures each building's height from its picture's topmost drawn pixel, for clicks and health bars.
- **The look.** The artwork follows the Cartoon Modern style recorded in `design.md` and [`art-style.md`](art-style.md). It is written as SVG, drawn by macOS, with a grain added by Core Image ([`decisions.md`](decisions.md#verifications-2026-11-18)). The SVG is held in Swift source as string literals, not as package resources, so that the assembled app needs no resource bundle.

## Checks

Whole matches between computer players, run without a screen, live in the `MatchTests` target. `swift build` and `swift test` must pass, and `reuse lint` with them (see [`CONTRIBUTING.md`](CONTRIBUTING.md)). Tests use Swift Testing.
