# 19 · Worlds from arithmetic — procedural generation

*Fresh-start note (no memory of other chapters required): a **random number generator** ("rng") is a function that hands you a fresh number in 0..1 each time you ask; a **seed** is the starting number you give it, and the same seed always produces the same sequence; **noise** is smooth randomness — static that has been blurred into rolling hills, so neighbouring values are similar; a **grid** is a rectangle of **cells**, each holding one value (rock or air, grass or water); a cell's **neighbourhood** is the four or eight cells touching it; a **tile** is the small picture drawn for one cell; **JSON** is the plain-text way of writing a nest of names and values (`{"gold": 12, "hp": 3}`) that every language can read back. Each is re-mentioned in place.*

---

Every chapter before this one was about the things *in* a world — how a sprite moves, how a flame flickers, how a flat picture looks deep. This chapter is about the world itself. **Procedural generation** is the plain idea that a place can be made by arithmetic while the game runs: a handful of rules, a starting number, and the map draws itself — a different cave each night, a forest with no two trees in the same spot, a dungeon nobody hand-built, and a loot drop that feels fair.

It sounds like magic and it is closer to knitting. Every generator in this chapter is the same loop wearing different clothes: *look at a cell (or a point), look at its neighbours, apply one small rule, move on.* Caves come from "am I mostly surrounded by rock?"; a maze comes from "which unvisited neighbour shall I carve into?"; a tile picks itself from "which of my four sides touch a wall?"; a spread of trees comes from "is anything already within *r* of me?". The randomness only decides *where to start looking*. The rule does the rest, and the rule is usually five lines.

> **A place is a rule, a neighbourhood, and a seed.** Choose what one cell asks of its neighbours, choose how far "neighbour" reaches, and choose the starting number — and the same three choices rebuild the same world on any machine, forever.

▶ *See it all:* **[the world workshop](https://esorhizome.github.io/sparks-and-sprites/worlds.html)** — 13 generators in three families, every one editable in the page, and every one with a **rhyme** (the same generator with two or three dials turned — 26 worlds in all). Each card *grows on screen*: you watch the smoothing passes, the split lines, the collapses, then it rests, then it regrows with the next seed; click a card to regenerate, place a goal, paint a wall, or roll the dice. Every card keeps a `seed` dial and draws from `rng(seed)`, so the same seed makes the same world every time. All 13 (+13 rhymes) are ported to GDScript in the downloadable Godot project ([`demos/godot/scenes/world/`](../demos/godot/scenes/world/), menu key **Z**; right-click a card for its rhyme).

## Random versus noise — and why a place needs both

Two kinds of chance appear in this chapter, and they do different jobs.

**Random** numbers jump: ask an rng twice and the answers have nothing to do with each other — right for a coin flip, a loot drop, a starting position, the first fill of a cave. **Noise** drifts: the value at `x + 1` is near the value at `x`, so a line of noise is a hill and a sheet of it is weather. [Chapter 04](04-backgrounds.md) fed noise into *colour* and got clouds; [chapter 11](11-three-and-babylon.md) pushed a sphere's points outward by it and got a planet. This chapter feeds it into *height and kind* and gets terrain with biomes — and adds **octaves**: layers of noise, each at double the frequency and half the amplitude of the last, summed. One octave is a rolling hill; four are a hill with rocks on it.

The rule of thumb: **random for placing, noise for shaping.**

## The three families — wanted thing → card

| Family | What it makes | Cards |
|---|---|---|
| **Scatter & noise** | things spread across a space — trees, stars, biomes, plants — from points and continuous fields | P·Poisson · T·Terrain · V·Voronoi · L·Lsystem |
| **Rooms, caves & mazes** | walkable interiors on a grid — from a neighbour rule, a halving, a carving, a constraint, or a bitmask | C·Caves · B·Bsp · M·Maze · W·Wfc · A·Autotile |
| **Dice, waves & saves** | the arithmetic *around* a world — fair chance, pacing over time, the world folded into a file, and the seed that reproduces all of it | D·Dice · H·Horde · S·Save · S·Seed |

| I want… | Card |
|---|---|
| trees, rocks, stars, enemies that never clump | **P·Poisson** |
| a side-view ground with water, sand, grass, snow | **T·Terrain** |
| territories, biome patches, shattered glass, stone tiles | **V·Voronoi** |
| a tree, a fern, a coral, a lightning fork | **L·Lsystem** |
| organic caverns, blobs of rock | **C·Caves** |
| a dungeon of rectangular rooms joined by corridors | **B·Bsp** |
| a maze — long and winding, or short and branchy | **M·Maze** |
| a tile map whose tiles obey neighbour rules (shores, walls, roads) | **W·Wfc** |
| walls whose corners and edges pick their own picture | **A·Autotile** |
| loot that feels fair; a rare drop that eventually arrives | **D·Dice** |
| enemies arriving in waves with rests between | **H·Horde** |
| a save file that survives its own old versions | **S·Save** |
| "try seed 4477" — the same world on your friend's machine | **S·Seed** |

## The thirteen, one breath each

| Card | The mechanism in one breath | Reach for it when | Rhyme |
|---|---|---|---|
| **P·Poisson** | **Poisson-disc** (Bridson): keep an *active list*; from one point try ~30 candidates at `r`..`2r`, accept the first with nothing within `r` (a grid of cell size `r/√2` makes that check local), retire the point when none fits | anything that should look *evenly random* — a uniform scatter clumps and leaves holes | *Pinprick* — tiny `r`, hundreds of points: a star field |
| **T·Terrain** | **1-D noise terrain**: sum octaves with `f` doubling and `a` halving; then **biomes by height** — bands for water, sand, grass, rock, snow | a side-scroller's ground, a skyline | *Tundra* — fewer octaves, flatter, a snow palette |
| **V·Voronoi** | **Voronoi regions**: N seed points; each grid cell belongs to its *nearest*; borders where nearest changes. `metric` swaps Euclidean (round) for Manhattan `|dx|+|dy|` (diamond) | territories, biome patches, cracked ground, stained glass | *Vitreous* — Manhattan metric, many seeds, a glass palette |
| **L·Lsystem** | **L-system**: a string rewritten by a rule each pass (`F → F[+F]F[−F]F`), read by a **turtle**: `F` forward, `+ −` turn by `angle`, `[ ]` remember / return. It doubles per pass, so four passes are plenty | plants, corals, veins, lightning — anything that branches | *Lichen* — a different rule and angle: a bushy coral |
| **C·Caves** | **Cellular automata**: fill ~45% rock at random; then, a few passes, *rock if ≥ 5 of 8 neighbours are rock* (out-of-bounds counts as rock, so the border seals); **flood-fill** the largest open region and seal the pockets | organic caverns; `rule` 4 opens them, 6 closes them into tunnels | *Catacombs* — a denser fill and a stricter rule: narrow winding tunnels |
| **B·Bsp** | **Binary space partition**: halve the map, halve the halves, until room-sized; a room in each leaf; corridors between *sibling* leaves up the tree — connected by construction | rectangular dungeons, floor plans, anything that must connect | *Bunker* — more splits, tiny rooms, straight corridors |
| **M·Maze** | **Recursive backtracker**: carve into a random unvisited neighbour, step back when stuck — long corridors, few dead ends. **Prim's**: carve a random wall from a *frontier* — short branchy passages, many. The dead-end count is the personality test | labyrinths: a journey (backtracker) or a thicket (Prim's) | *Meander* — `algo: "prim"`, a bigger grid |
| **W·Wfc** | **Wave function collapse** (tiled): every cell starts as "any tile"; pick the one with fewest options (**lowest entropy**), choose, then **propagate** — strike from each neighbour what the rule table forbids; repeat. No options left = a **contradiction**: restart | tile maps whose neighbour rules must hold *everywhere* — water, shore, grass | *Wetlands* — a rule set that favours water: lakes and reeds |
| **A·Autotile** | **Bitmask autotiling**: sum a wall's wall-neighbours, `N=1, E=2, S=4, W=8`; the sum (0..15) is the tile index, and corners resolve themselves. The 8-bit version (47 tiles) adds diagonals, counted only when *both* adjacent edges are walls | walls, water, roads that must join up — what engines' terrain / rule tiles do for you | *Archipelago* — 8-bit corners, an island palette: sand meets sea |
| **D·Dice** | **Weighted pick**: roll `rng()·total`, walk the table subtracting. **Shuffle bag**: every entry by weight, shuffled, drawn *without replacement* — the rare thing is guaranteed once per bag. **Pity timer**: the rare weight grows per miss | loot, enemy variety, card draws — where random must also feel *fair* | *Drops* — a pity timer that forces a legendary within 20 |
| **H·Horde** | **Spawn director**: a **wave curve** of intensity over time (peaks, then rests), a playhead, *off-screen* spawn points, an interval that shrinks as intensity rises | waves of enemies; the rests are the design | *Hush* — long rests, small peaks: a stealth game's pacing |
| **S·Save** | gather the state into one plain object, `JSON.stringify`, write a slot; on load `JSON.parse`, read `version`, **migrate** — default the fields old saves lack | any game longer than one sitting | *Suspend* — one slot, deleted on load: the roguelike rule |
| **S·Seed** | two panels with the same seed draw identical maps; a third with `seed + 1` differs; the first rng outputs are printed so you can watch determinism happen | always — this card just makes the promise visible | *Sibling* — three consecutive seeds side by side |

## The seed is the whole promise

Everything above is only *reproducible* because of one habit: **never call the built-in random function inside a world.** `Math.random()` (and its cousins) seeds itself from the clock, so no two runs agree. Instead, make your own rng from a seed and draw every world number from it. The workshop uses **mulberry32**, a well-known 32-bit generator small enough to read:

```js
function mulberry32(seed) {                 // seed: any integer
  return function () {                      // returns a fresh 0..1 each call
    seed = (seed + 0x6D2B79F5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rng = mulberry32(4477);   // rng(), rng(), rng() … identical on every machine
```

Same seed, same sequence, same world — which is how procedural games share a place as a number ("try seed 4477", the promise [chapter 01](01-first-words.md)'s glossary made), and how you *debug* randomness: pin the seed and the bug repeats exactly. One refinement pays for itself: derive per-system seeds from the world seed (`terrain = mulberry32(seed + 1)`, `loot = mulberry32(seed + 2)`) so one extra tree call in the forest code does not reshuffle the loot.

In the engines the habit has a name each: Godot's `RandomNumberGenerator` with `.seed = 4477` (then `randf()`, `randi_range()`, `rand_weighted()`), or the global `seed(4477)`; Unity's `Random.InitState(4477)`, or a `System.Random(4477)` per system, since `UnityEngine.Random` is one global stream; Unreal's `FRandomStream Stream(4477)` with `Stream.FRandRange()` — a stream per system is the normal spelling there.

## Saves — the world, folded into a file

A save is the seed plus everything the seed couldn't know: what the player did. Three habits make it survive:

1. **Serialise to plain data** — one object of numbers, strings, lists and nested objects, never live nodes. `JSON.stringify(state)` makes text; `JSON.parse(text)` makes it back.
2. **Version it** — `state.version = 3` in every save, from day one.
3. **Migrate on load** — a `version 2` save opened by `version 3` code gets its missing fields defaulted (`s.keys ??= []`) and its number bumped, in a chain of `if (s.version < n)` steps. Old saves keep working.

| | Where it lives | The call |
|---|---|---|
| **Web** | `localStorage` (a few MB per site; wiped if the player clears site data) | `localStorage.setItem("slot1", JSON.stringify(s))` / `JSON.parse(localStorage.getItem("slot1"))` |
| **Godot** | `user://` — a per-user folder the engine maps to the right place on every OS | `FileAccess.open("user://slot1.json", FileAccess.WRITE).store_string(JSON.stringify(s))`; back with `JSON.parse_string(f.get_as_text())` |
| **Unity** | `PlayerPrefs` for a few values; a file under `Application.persistentDataPath` for a real save | `JsonUtility.ToJson(s)` / `JsonUtility.FromJson<Save>(text)` (mark the class `[Serializable]`) |
| **Unreal** | a `USaveGame` subclass whose `UPROPERTY` fields *are* the save | `UGameplayStatics::SaveGameToSlot(obj, "slot1", 0)` / `LoadGameFromSlot` |

The roguelike variant (the *Suspend* rhyme) is the same code with one rule: a single slot, deleted the moment it is loaded, so quitting is allowed and reloading is not.

## The four accents, per generator

Only the web hand-rolls everything (20–80 lines per card); the engines package most of it, and having written the hand-rolled version once is what makes the packaged one legible.

| Idea | Web (the workshop) | Godot | Unity | Unreal |
|---|---|---|---|---|
| seeded rng | `mulberry32(seed)` | `RandomNumberGenerator.seed`, `seed()` | `Random.InitState`, `System.Random` | `FRandomStream` |
| noise, octaves | `noise2(x, y)` summed by hand | `FastNoiseLite` (`noise_type`, `frequency`, `fractal_octaves`); `get_noise_1d/2d` | `Mathf.PerlinNoise(x, y)` — sum octaves yourself | `FMath::PerlinNoise2D`; Landscape for real terrain |
| Poisson scatter | card P | hand-roll (~40 lines) | hand-roll | **PCG** framework: a sampler node plus a density / distance filter |
| Voronoi | card V | `FastNoiseLite` with `TYPE_CELLULAR` | hand-roll, or a Shader Graph *Voronoi* node for the picture | a material *Voronoi* node for the picture; hand-roll for regions |
| L-systems | card L | no built-in — the card's 30 lines port directly | same | same |
| cellular caves, BSP rooms | cards C, B | hand-roll; `set_cell` on a `TileMapLayer` | hand-roll onto a `Tilemap` | hand-roll; PCG to scatter the result in 3D |
| mazes, paths | card M; [chapter 14](14-procedural-animation.md)'s A·Astar walks them | `AStarGrid2D` for the walking; carving is hand-rolled | `NavMesh` for the walking | NavMesh / Behavior Trees for the walking |
| WFC | card W | community addons | community packages | an experimental *Wave Function Collapse* plugin |
| autotiling | card A's bitmask | `TileMapLayer` **terrain sets** — paint a terrain, the bitmask is done for you | **Rule Tiles** (2D Tilemap Extras) | Paper2D has no autotiler — hand-roll the bitmask, or PCG |
| weighted picks | card D | `RandomNumberGenerator.rand_weighted(weights)`; `Array.shuffle()` | hand-roll; `ScriptableObject` tables | `UDataTable` rows + `FRandomStream` |
| wave curve | card H | a `Curve` resource: `curve.sample(t)` | `AnimationCurve.Evaluate(t)` | `UCurveFloat::GetFloatValue(t)` |
| save / load | `localStorage` + `JSON` | `FileAccess` + `JSON` | `JsonUtility`, `PlayerPrefs` | `USaveGame` |

The grid the caves and rooms land on is also the grid the player collides with — [chapter 18](18-collision-and-contact.md) covers tile-map collision, and the two chapters meet exactly there: a generator writes cells, a `TileMapLayer` (or `Tilemap`) turns cells into walls.

## What usually goes wrong

- **One unseeded call in a seeded world.** A single `Math.random()` (or `randf()` without a set seed) inside the generator, and "seed 4477" stops meaning anything — worse, it usually works nine times out of ten. Search for it; route everything through the one rng.
- **Caves in pieces.** Cellular automata happily grow three caverns with no path between them. Flood-fill from the largest region and fill the rest with rock (card C does this), or dig corridors between region centres.
- **WFC contradictions.** A cell with no legal tile left is normal, not a bug; the fix is a restart with the next seed, or a rule table that is *possible* — if water may only touch sand and sand may only touch water, no map exists. Test the table on a 3×3 first.
- **Autotile indices in the wrong order.** The bitmask is only right if your tile sheet is laid out in the *same* bit order (`N=1, E=2, S=4, W=8`, or whichever you chose). A wall set that looks shuffled is a bit order mismatch, not a drawing error.
- **Saves without a version.** The first update that adds a field turns every existing save into a crash on load. Add `version: 1` today; it costs a line.
- **A director that never rests.** A wave curve with no valleys is a wall of enemies, and players read a wall as unfair. Rests are where the tension is felt; the *Hush* rhyme is the extreme.
- **A world that is technically infinite and actually samey.** See below.

## Feel, restraint, and honesty

- **Generated is not the same as interesting.** A rule makes a thousand valid caves; it does not make a memorable one. The studios that do this well *hand-place the landmarks* — the boss room, the waterfall, the one tree in the clearing — and let the arithmetic fill the space between. Generate the connective tissue; author the moments.
- **Constrain before you randomise.** Poisson over uniform, shuffle bags over raw rolls, BSP over "scatter rooms and hope": every good generator is randomness with a promise attached. The promise is the design.
- **Show the seed.** A number in the corner of the pause menu costs nothing and turns a private cave into a place that can be shared, replayed, and reported when it goes wrong.
- **Make the generation watchable once.** The workshop animates every pass because seeing the rule *act* is how it becomes yours; in a shipped game the same animation, run once at a loading screen, is also the cheapest possible explanation of what the world is.

---

*Quick-reference version: [the worlds cheatsheet](../cheatsheets/worlds.md). The gallery: [the world workshop](https://esorhizome.github.io/sparks-and-sprites/worlds.html) (13 generators + 13 rhymes). Kin chapters: [01 · First words](01-first-words.md) (the seed, the noise), [04 · Backgrounds](04-backgrounds.md) (noise as texture), [14 · Procedural animation](14-procedural-animation.md) (A\* walks these maps), [18 · Collision & contact](18-collision-and-contact.md) (cells become walls). Going deeper, free and legal: [Red Blob Games](https://www.redblobgames.com/) — Amit Patel's interactive articles on noise, hex grids, Poisson scattering and map generation; and [Procedural Content Generation in Games](https://pcgbook.com/), a whole textbook, free online.*
