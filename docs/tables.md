# The tables

Every figure that requirement 25 names is read from three CSV files when the game starts. Their defaults are in `Sources/GameCore/Tables/`, and the app copies each into `~/Library/Application Support/Greatest Conqueror/` the first time it runs, or whenever one is missing there; File > Show the tables in Finder opens that folder. The game reads the folder's files at every start. A file that is missing, cannot be read or holds a fault leaves all three defaults in use, and the fault is shown once, as the app opens, with its file, line and column.

Each file begins with a header row naming its columns; the columns may come in any order, and each must be present once. A cell may be quoted with double quotes, a doubled quote standing for one. Kinds and ages are named as in the code: `worker`, `fieldGun`, `townCentre`, `boatHouse`; `towns`, `farms`, `ships`, `cannons`, `hospitals`. An empty cost cell is 0.

## stats.csv

One row for each unit kind and each building kind. A tower's or a castle's later rows, each of a later age, are its upgrades in those ages (requirement 24): they are read and kept for the rule that applies them, which is still to be written.

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
| `gather_food`, `gather_wood`, `gather_gold` | For a worker or a boat, what it takes from a site a second: food from deer or fish, wood from trees, gold from gold mines. |
| `farm_food` | For a worker, the food a second it earns at a farm. |
| `heal_per_second`, `repair_per_second`, `radius` | The rates of healing and repair, and the radius within which an idle unit looks for that work; empty until the rules that use them are written. |

## production.csv

One row for each maker and each unit it makes: `maker`, `unit`, the `age` from which it makes the unit, and the `seconds` each one takes. A building makes only the units listed for it.

## ages.csv

One row for each advance: `from` and `to` (the next age), its cost in `food`, `wood` and `gold`, and its duration in `seconds` at a town centre.

## What the code still holds

The figures requirement 25 does not name stay in `CatalogueShape` (`Sources/GameCore/CatalogueShape.swift`): each kind's speed, sight, armour, population places and footprint, a building's housing and the resources it accepts, the radius of a cannon's shot, the damage bonuses between kinds, a worker's load, what each kind of site holds, a farm's yield and the cost of reseeding it, the start of a match, the population maximum, and the car.

## In a match

The tables are part of the match: the host's travel to every joining Mac in the message that starts the match (`MatchStart.catalogue`), a saved match keeps the tables it was played with, and the match's checksum counts every figure of them.
