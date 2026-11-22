# The tables

Every figure that requirement 25 names is read from four CSV files, the tables, when the game starts. Their defaults are in `Sources/GameCore/Tables/`, and the app copies each into `~/Library/Application Support/Greatest Conqueror/` the first time it runs, or whenever one is missing there; File > Show the tables in Finder opens that folder. The game reads the folder's files at every start. A file that is missing, cannot be read or holds a fault leaves every default in use, and the fault is shown once, as the app opens, with its file, line and column.

Each file begins with a header row naming its columns; the columns may come in any order, and each must be present once. A cell may be quoted with double quotes, a doubled quote standing for one. Kinds and ages are named as in the code: `worker`, `doctor`, `fishingBoat`, `soldier1` to `soldier4`, `knight1` to `knight3`, `cannon1` and `cannon2`, `navyShip`, `car`, `founder`; `townCentre`, `house`, `farm`, `boatHouse`, `barracks`, `tower`, `stable`, `castle`, `cannonFactory`, `hospital`; `towns`, `farms`, `ships`, `cannons`, `hospitals`. An empty cost cell is 0.

## stats.csv

One row for each unit kind and each building kind, the car and the founder included, though neither is a unit (ruled 2026-11-22). A tower's, a castle's or a navy ship's later rows, each of a later age, are its upgrades in those ages (requirement 24): only `health`, `damage`, `hits_per_second` and `range` are read from them. When a player reaches an age, each of its towers, castles and navy ships takes that age's row: its maximum health becomes the row's, its health keeps the same share of the maximum, rounded to the nearest point, and it strikes with the row's attack; one made later begins with the row's figures.

| Column | Meaning |
|---|---|
| `kind` | The kind. |
| `age` | The age in which the kind first appears: from which a building can be built, and whose look a warfighter keeps. |
| `food`, `wood`, `gold` | The cost. |
| `health` | The maximum health points. |
| `damage`, `hits_per_second`, `range` | An attacker's harm per blow, blows a second and reach in tiles; empty for a kind that does not attack. |
| `build_seconds` | For a building, the seconds of one worker's work to build it; more workers build it sooner. |
| `demolish_seconds` | For a building, the seconds of one worker's work to demolish it; more workers demolish it sooner. By default half of `build_seconds`. |
| `demolish_return` | For a building, the share of its cost, from 0 to 1, that demolishing it returns, rounded down. By default 0.5. |
| `gather_food`, `gather_wood`, `gather_gold` | For a worker or a boat, what it takes from a site a second, added at once to its player's resources: food from fruit bushes, deer or fish, wood from trees, gold from gold mines. |
| `farm_food` | For a worker, the food a second it earns at a farm. |
| `heal_per_second` | For a doctor, the health points a second it restores to a wounded unit of its player; several doctors add up. |
| `repair_per_second` | For a worker, the health points a second it restores to a damaged building of its player; several workers add up. |
| `radius` | For a doctor or a worker, the radius in tiles within which, idle, it looks for a unit to heal or a building to repair, and goes to stand beside it. |

## production.csv

One row for each maker and each unit it makes: `maker`, `unit`, the `age` from which it makes the unit, and the `seconds` each one takes. A maker is a building or a unit kind; in the defaults the one unit that makes units is the navy ship, which makes them only whilst at the shore, each appearing on the shore beside it (requirement 18). A maker makes only the units listed for it; the car and the founder are made by none.

## ages.csv

One row for each advance: `from` and `to` (the next age), its cost in `food`, `wood` and `gold`, and its duration in `seconds` at a town centre.

## resources.csv

Ruled 2026-11-22. One row for each figure of the resources, with the columns `name` and `value`; every row is required, each value a whole number of at least 0.

| Name | Meaning | Default |
|---|---|---|
| `tree_holds`, `deer_holds`, `gold_holds`, `fish_holds`, `bush_holds` | What one site of the kind holds when the map is made, in its resource: wood, food, gold, food, food. | 100, 150, 400, 200, 150 |
| `farm_yield` | The food a farm yields before it runs dry and must be reseeded. | 300 |
| `farm_reseed_wood` | The wood reseeding a farm costs. | 60 |
| `start_food`, `start_wood`, `start_gold` | The stock each player begins a match with. | 200, 250, 0 |

## During play

The settings (the gear in the window's title bar, or Command-comma) hold the tables (requirements 27 and 28):

- **Edit the tables…** opens the editor, during play only: each file as a grid, its columns named as above, one file shown at a time. Opening it pauses the match, unless it was paused already, and closing it resumes it. Every edit is read again by the reader the game uses at start-up, and the first fault is shown with its file, line and column, its cell outlined; until it is corrected nothing can be applied. Apply saves every file to the folder and puts the new tables into the match from the next tick; each unit and building whose kind's maximum health has changed is set to the new maximum (ruled 2026-11-22). New matches on this Mac are played by them too.
- **Save the tables as a zip…** writes every file of the tables into one zip file, wherever the player chooses.
- **Load tables from a zip…** reads such a file, the files at its top or in one folder inside it, with the same reader. Before a match it replaces the folder's files, and the next match is played by them; in a match it acts as an Apply from the editor.

In a match across the network only the host may open the editor or load a zip (requirement 29). The host's new tables go to every Mac in the match (`NetMessage.tables`), which plays and draws by them, and the match's checksum counts them from the tick they take effect.

## What the code still holds

The figures requirement 25 does not name stay in `CatalogueShape` (`Sources/GameCore/CatalogueShape.swift`): each kind's speed, sight, armour, population places and footprint, a building's housing, the radius of a cannon's shot, the damage bonuses between kinds, the workers a match begins with (three), the workers who come with a founder's town centre (two), the troops a navy ship carries (twenty), the population maximum, and the car.

## In a match

The tables are part of the match: the host's travel to every joining Mac in the message that starts the match (`MatchStart.catalogue`), and those the host applies during play in `NetMessage.tables`; a saved match keeps the tables it was played with, and the match's checksum counts every figure of them.
