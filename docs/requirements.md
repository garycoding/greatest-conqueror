# Requirements: Greatest Conqueror

Status: draft for review, 2026-11-22.

Greatest Conqueror is a real-time strategy game for macOS, made from Cities of Progress (garycoding/cities-of-progress, develop 6492cca). This document states what the game must do. Where it says "as in Cities of Progress", the behaviour of that game at that commit is meant, as its own requirements document states it.

## Purpose

A real-time strategy game in which players gather food, wood and gold, build a town, advance through five ages, and conquer their opponents, with every number that governs the play kept in tables that can be tuned during the game.

## Terms

- **Player:** one participant in a match, a person or a computer, with a base of its own.
- **Civilization:** what a player plays as; it gives the player a name and a colour.
- **Team:** a group of players who are allies. A team may consist of one player.
- **Unit:** something that moves: a worker, soldier, knight, cannon, fishing boat, navy ship or doctor (ruled 2026-11-22). A founder is not a unit, nor is the Tesla.
- **Kind:** one line of the tables: a unit kind (soldier 2, say), or a building kind.
- **Tier:** one of the successive kinds of soldier, knight or cannon (soldier 1, soldier 2, and so on).
- **Maker:** the building, or the navy ship, at which a unit is made.

## Stated requirements

These come from the person for whom the game is made and are settled (2026-11-21 and 2026-11-22).

### The game

1. The game is called Greatest Conqueror. It is made from Cities of Progress, in a repository of its own, public under AGPL 3.0, with a fresh history.
2. It keeps from Cities of Progress the setup of a match (seats, teams, civilizations, difficulty, "What you see", the starting age and the map size), the maps, the drawing of the map and the animation of movement, play across the LAN, saving and resuming, and the controls.
3. It keeps the Tesla as it is in Cities of Progress: up to five cars a person, summoned with Shift-C beside a town centre, unharmed, with a kill radius that can be turned off and on, car by car, and a laser that burns down an opponent's building.
4. It has none of the following from Cities of Progress: bridges and engineers, scholars and research, merchants and trade, walls, the stock pen, the storage pit, and the resources stone, bronze, iron, gunpowder, oil, electricity and data, with their deposits. The setup has no "Bridges" setting.

### Ages

5. There are five ages, in this order: the age of towns, the age of farms, the age of ships, the age of cannons and the age of hospitals.
6. A player moves to the next age by paying, at a town centre, an amount of food, wood and gold set for that advance; the advance takes a set time.
7. Each age is drawn in the look of an age of Cities of Progress: towns as Stone, farms as Bronze, ships as Iron, cannons as Alchemy and hospitals as Industrial.

### Resources

8. There are three resources: food, wood and gold.
9. Food comes from fruit gathered, deer hunted, farms farmed and fish caught; wood from trees; gold from gold mines on land and in the water.

### Buildings

10. The buildings, by the age in which each can first be built:

| Age | Buildings |
|---|---|
| Towns | Town centre, house |
| Farms | Farm, boathouse, barracks, tower |
| Ships | Stable, castle |
| Cannons | Cannon factory |
| Hospitals | Hospital |

11. Workers build buildings. More workers on one building build it faster: each building needs a set number of man-seconds of work.

### Units

12. Workers gather fruit, hunt deer and farm (food), cut wood (wood), mine gold (gold), build buildings and repair them. An idle worker repairs any damaged building of its player within a set radius, moving to stand beside it.
13. Doctors heal wounded units up to their maximum health. Each doctor adds a set number of health points a second, so more doctors heal a unit faster. An idle doctor heals any wounded unit of its player within a set radius, moving to stand beside it.
14. Fishing boats catch fish (food) and mine gold in the water.
15. Soldiers, knights and cannons attack.
16. Navy ships carry up to 20 troops and attack with guns. Troops are soldiers, knights, cannons, workers and doctors (ruled 2026-11-22). Troops board a navy ship that is at the shore when the player right-clicks the ship with them selected, and land when the player right-clicks the shore with the ship selected. Troops aboard are lost if the ship is destroyed.
17. The units, by the age in which each maker can first make them:

| Age | Unit | Maker |
|---|---|---|
| Towns | Workers | Town centre |
| Farms | Soldiers | Barracks |
| Farms | Fishing boats | Boathouse |
| Ships | Knights | Stable |
| Ships | Navy ships | Boathouse |
| Ships | Soldiers and knights | Castle |
| Cannons | Cannons | Cannon factory |
| Cannons | Cannons | Castle |
| Hospitals | Doctors | Hospital |
| Hospitals | Soldiers, knights and cannons | Navy ship |

18. A navy ship makes units only while it is at the shore, and each unit it makes appears on the shore near it.
19. Soldiers, knights and cannons come in tiers. In each age after the one in which the kind first appears, a better tier becomes available, and every earlier tier can still be made: soldiers 1 to 4 (from the ages of farms, ships, cannons and hospitals), knights 1 to 3 (ships, cannons, hospitals) and cannons 1 and 2 (cannons, hospitals). A unit keeps its tier.
20. Workers, fishing boats and doctors are a single kind each, the same in every age.

### Combat, health and upgrades

21. Every unit and building has a maximum number of health points. Damage reduces them; at zero the unit or building is gone.
22. These attack: soldiers, knights, cannons, navy ships, towers and castles. Towers, castles and navy ships have built-in cannons.
23. Each attacker removes a set number of health points from its target with each hit, and makes a set number of hits a second.
24. Towers, castles and navy ships are a single kind each, upgraded automatically when their player reaches each new age: more health points, more damage and a longer range.

### Tables

25. Every number that governs the play is held in three CSV files, which the game reads when it starts:
    - `stats.csv`, one row for each unit kind and building kind (each tier, and each age's upgrade of towers, castles and navy ships, a row of its own): the cost in food, wood and gold; the maximum health; the damage per hit, the hits a second and the range of an attacker; the man-seconds to build a building; and the rates a second of gathering, healing and repairing, with the radius within which idle workers repair and idle doctors heal.
    - `production.csv`, one row for each maker and unit it makes: the age from which it makes that unit, and the seconds each one takes.
    - `ages.csv`, one row for each advance: its cost in food, wood and gold and its duration in seconds.
26. The files live in a folder the player can open (Application Support/Greatest Conqueror). The game seeds the folder from its built-in defaults the first time it runs.
27. During play, the settings offer an editor of the three tables. Opening it pauses the game; what is changed there is saved to the files and takes effect in the match.
28. The settings can save all the CSV files together as one zip file, anywhere on the disk, and can load any such zip file in their place.
29. In a match across the network, the host's tables are sent to every Mac that joins, and only the host may open the table editor during the match.

### Play

30. A player can pause the match, and resume it, as well as setting its speed. The pause holds for every player in the match.

### Founders, defeat and demolition

These were ruled on 2026-11-22.

31. **Founder.** A person (never a computer player) who has zero workers and zero town centres, while at least one teammate is undefeated, receives a founder beside one of an ally's town centres. The founder cannot be killed and cannot attack; it can build one town centre free of charge. When that town centre is finished, two workers appear beside it and the founder becomes a worker. Pressing F while the player has a founder selects it and scrolls the view to centre it.
32. **Units and defeat.** A unit is something that moves: a worker, soldier, knight, cannon, fishing boat, navy ship or doctor; a founder is not a unit, nor is the Tesla. A player is defeated with no units and no building that can make a unit; a team is defeated when all its members are. A defeated person whose team still lives receives a founder and comes back into the match through it.
33. **Demolition.** Workers can be told to demolish their player's own buildings, to recover resources; more workers demolish faster, as they build and repair faster. A demolished building returns a share of its cost (`demolish_return`, 0.5 by default) after a number of man-seconds (`demolish_seconds`, half its build man-seconds by default), both columns of its row in `stats.csv`.

## Consequences of the stated requirements

These follow from the requirements above; they are stated so that they can be confirmed or corrected.

- Since every number is in the tables, the balance of the game is set by editing them, not by changing the code; a table that is missing a row the game needs, or holds a value it cannot use, is refused with the file, line and column named, and the defaults are used instead.
- A saved match carries the tables it was being played with, so it resumes with them.
- The computer players play by the tables in use, whatever they hold.
- Workers carry what they gather to a town centre, and fishing boats to a boathouse, since no storage building remains.

## Constraint: an original work

The game is an original work in the genre. It does not use the name, artwork, sounds, music, text, campaigns or maps of any published game. The mechanics common to the genre are free to use, and so are the names of historical civilizations.

## Suggested requirements

Each item below is a suggestion, not a ruling, carried over from Cities of Progress unless it says otherwise. Any of them can be struck or changed.

- The civilizations are those of Cities of Progress, and differ in name and colour only.
- Every player begins with a town centre and a few workers.
- Houses raise the limit on the number of units a player may have, up to a fixed maximum; the limit and each house's share are in `stats.csv`.
- A worker's name on the screen follows what it is doing: gatherer, hunter, farmer, lumberjack, miner, builder or repairer.
- The town centre shoots at opponents within range, as towers do.
- A computer player gathers, builds, advances, makes every tier, and uses navy ships, by the same rules and tables as the people, at three levels of difficulty.
- Each unit is drawn in the look of the age in which its kind first appears; each building takes the look of its owner's age. Where Cities of Progress has a fitting drawing it is reused: soldiers 1 to 4 as the spearman, the swordsman, the musketeer and the rifleman; knights 1 and 2 as the horseman and the knight; cannons 1 and 2 as the cannon and the field gun (ruled 2026-11-22). New drawings are made for the doctor, the hospital, the cannon factory, the navy ship, knight 3 and the castle in the looks that lack one.

## Open questions

None at present.
