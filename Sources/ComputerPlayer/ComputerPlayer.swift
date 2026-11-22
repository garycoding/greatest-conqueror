// SPDX-FileCopyrightText: 2026 Gary Frattarola <garyf@parkviewlab.ai>
// SPDX-License-Identifier: AGPL-3.0-or-later

import GameCore

/// A computer player (requirement 22). It sees only its player's `PlayerView`
/// and acts only through `Order`s, as a person does: by the same rules, and
/// with nothing extra at any level of difficulty.
///
/// It reads every view it is given, so that no event is missed, and acts every
/// so often: every three seconds at `easy`, every second at `standard`, and
/// every two fifths of a second at `hard`. In one action it does the following,
/// in this order of priority, spending only what the view shows it holds and
/// holding back the cost of what it is saving for:
///
/// - **Founding.** If it holds only a founder, it founds a town centre on a
///   placeable site near an ally's town centre, and does nothing else.
/// - **The next age.** It orders `advanceAge` once `ageProgress` reaches 1 and
///   the cost is covered; from 0.6 it holds that cost back.
/// - **Defence.** Where its people or buildings have been struck
///   (`GameEvent.underAttack`), or opponents stand among its buildings, its
///   warfighters attack them, each the opponent it is best placed to beat. A
///   raid of three or more calls an attacking army home.
/// - **Building.** Engineers build a house before the population limit stops
///   training, a town centre if none stands, from the Bronze age a barracks, a
///   stock pen and a watch tower, from the Iron age farms, a stable, a siege
///   workshop and a stone wall, from the Alchemy age an alchemist's workshop
///   and a castle, and a storage pit beside resources gathered
///   far from any building that accepts them. A place is chosen with
///   `Placement.canPlace`, with a tile of open ground around each building.
/// - **Training.** The town centre trains workers, engineers and scholars up to
///   the numbers the difficulty sets; with no engineer, one comes first, so that
///   a house can always be built. From the Bronze age the barracks train a mixed
///   army, leaning toward the kinds that beat the opponents' warfighters it has
///   seen (`Catalogue.bonuses`), more so at `hard`; warfighters of the Stone age
///   are upgraded to the kinds of the Bronze age. Under attack in the Stone age,
///   the town centre trains warfighters enough to answer the intruders.
/// - **Attack.** From the difficulty's earliest attack time (fifteen minutes at
///   `easy`, ten at `standard`, seven at `hard`), with an army large enough (six,
///   nine and ten warfighters, two more after each attack), it attacks the
///   nearest known opponent's building. Where it sees an allied computer player's
///   warfighters attacking a building, it joins them with four. It never attacks
///   an ally, and withdraws when fewer than a third of its army remain.
/// - **Scouting.** When it knows no opponent's building, the fastest warfighter,
///   or failing that a worker once it has six, explores the unexplored ground.
/// - **Work.** Idle workers go to the nearest suitable sites that they can
///   reach, in shares that follow the age and what is being saved for: food,
///   wood and stone, and from the Bronze age copper and tin in pairs, gold, and
///   herding at a stock pen; in the Alchemy age up to three craftsmen make
///   gunpowder at the workshop whilst it runs short and wood allows. Idle
///   scholars study at the town centre; idle
///   engineers finish and repair buildings.
///
/// Its state is Codable, random generator included, so that a saved match
/// resumes with the same decisions; the same seed and the same views give the
/// same orders.
public struct ComputerPlayer: ComputerPlaying {
    public let player: PlayerID
    public let difficulty: Difficulty
    private var generator: SeededGenerator
    private var memory = Memory()

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
        let turn = Turn(view: view, catalogue: catalogue, tuning: tuning, me: me, memory: memory, generator: generator)
        turn.play()
        memory = turn.memory
        generator = turn.generator
        return turn.orders
    }
}
