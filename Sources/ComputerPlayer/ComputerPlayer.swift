// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// A computer player. It sees only its player's `PlayerView` and acts only
/// through `Order`s, as a person does: by the same rules and the same tables,
/// whatever they hold, and with nothing extra at any level of difficulty.
/// The levels differ in pace and judgement alone (`Tuning`).
///
/// It reads every view it is given, so that no event is missed, and acts every
/// so often: every three seconds at `easy`, every second at `standard`, and
/// every two fifths of a second at `hard`. In one action it does the following,
/// in this order of priority, spending only what the view shows it holds and
/// holding back the cost of what it is saving for:
///
/// - **The next age.** Once the difficulty's time for the age has come, it has
///   the workers and the army the difficulty sets, and it has made the best
///   tier of each line of warfighters its age allows, it holds back the
///   advance's cost (`ages.csv`) and orders `advanceAge` at its town centre.
/// - **Defence.** Where opponents on land stand among its buildings, or have
///   struck its people or buildings, its warfighters attack them, each the
///   opponent it is best placed to beat. A raid of three or more calls an
///   attacking army home. A strike from the water is left to its navy and towers.
/// - **Building.** Builders (workers it sets aside to build and repair) build a
///   house before the population limit stops training, a town centre if none
///   stands, and every building of its age that has a use (`stats.csv`,
///   `production.csv`): one of each maker, more barracks at `hard`, a tower,
///   farms as the food requires, a boathouse by water that holds fish or gold
///   and, once navy ships can be made, one by the largest water near. A place
///   is chosen with `Placement.canPlace`, with a side its workers can walk to,
///   never where it would close a way through.
/// - **Making units.** The town centre makes workers up to the numbers the
///   difficulty sets. Every maker of warfighters (barracks, stable, castle,
///   cannon factory, and a navy ship at the shore from the age the tables
///   give) makes the best tier of each line its age allows, keeping a mix of
///   soldiers, knights and cannons that leans toward the kinds that beat the
///   opponents' warfighters it has seen (`Catalogue.bonuses`), more so at
///   `hard`. A boathouse makes fishing boats and navy ships, and a hospital doctors.
/// - **Attack.** From the difficulty's earliest attack time, with an army large
///   enough, it attacks the nearest known opponent's building, joining an
///   allied computer player's attack with fewer. An opponent it cannot reach
///   on foot is attacked across the water: navy ships carry the troops, with a
///   doctor or two, to the opponent's shore and set them down (`ferry`). It
///   never attacks an ally, gives up a target it comes no nearer, and withdraws
///   when fewer than a third of its army remain.
/// - **Scouting.** When it knows no opponent's building, a warfighter, or a
///   worker, explores its own land, its navy ships explore the water, and once
///   its own land is explored the army is carried to look on other land.
/// - **Navy.** Navy ships not carrying troops fight the opponents' vessels and
///   the units and buildings within their reach of the water.
/// - **Work.** Gathering adds to the stock at once. Workers go to the nearest
///   suitable sites in the shares of food, wood and gold that the plan for the
///   coming age still lacks (`demand`), and busy workers are moved from a
///   resource in surplus to one that is short; boats fish or mine gold in the
///   water by the same shares. Idle builders finish and repair buildings;
///   idle doctors keep with the army. Idle healing and repair are the game's own rules.
///
/// It never orders a founder (ruled 2026-11-22: a computer player never receives one).
///
/// Its state is Codable, random generator included, so that a saved match
/// resumes with the same decisions; the same seed and the same views give the
/// same orders.
public struct ComputerPlayer: ComputerPlaying {
    public let player: PlayerID
    public let difficulty: Difficulty
    private var generator: SeededGenerator
    private var memory = Memory()
    /// The map's regions, made from the first view (`RegionCache`); not saved.
    private var regionCache = RegionCache()

    public init(player: PlayerID, difficulty: Difficulty, seed: UInt64) {
        self.player = player
        self.difficulty = difficulty
        generator = SeededGenerator(seed: seed)
    }

    public mutating func decide(view: PlayerView, catalogue: Catalogue) -> [Order] {
        guard view.player == player, let me = view.me else { return [] }
        memory.observe(view)
        guard view.outcome == nil, !view.isPaused, !me.isDefeated else { return [] }
        let tuning = Tuning.of(difficulty)
        if let last = memory.lastAction, view.tick >= last, view.tick - last < tuning.reaction { return [] }
        memory.lastAction = view.tick
        let regions = regionCache.regions(for: view)
        let turn = Turn(view: view, catalogue: catalogue, tuning: tuning, me: me, memory: memory, generator: generator,
                        regions: regions)
        turn.play()
        memory = turn.memory
        generator = turn.generator
        return turn.orders
    }
}
