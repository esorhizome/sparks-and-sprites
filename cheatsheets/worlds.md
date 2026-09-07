# Cheatsheet · Worlds from arithmetic (procedural generation)

Everything = **a place is a rule, a neighbourhood, and a seed.** Full chapter: [19](../chapters/19-worlds-from-arithmetic.md). Live demos: [the world workshop](https://esorhizome.github.io/sparks-and-sprites/worlds.html) (13 generators, each with a rhyme = 26 worlds, all editable; Godot menu key Z, [`scenes/world/`](../demos/godot/scenes/world/)).

**Random** jumps (coin flips, placement, the first fill). **Noise** drifts (hills, weather, biomes). Random for placing, noise for shaping.

## Generator → rule → card

| Card | Generator | The rule in one breath | Rhyme |
|---|---|---|---|
| P | Poisson-disc (Bridson) | from an active point, try ~30 candidates at `r`..`2r`; accept the first with nothing within `r`; grid of cell `r/√2` makes the check local | Pinprick — tiny `r`, a star field |
| T | Noise terrain | `h(x) = Σ noise(x·2ⁱ)/2ⁱ` (octaves); biomes = height bands water→sand→grass→rock→snow | Tundra — fewer octaves, flatter |
| V | Voronoi | each cell belongs to its nearest seed; borders where "nearest" changes; Euclid = round, Manhattan = diamond | Vitreous — Manhattan, many seeds |
| L | L-system | rewrite a string by a rule per pass; turtle reads it: `F` forward, `+ −` turn, `[ ]` push/pop | Lichen — another rule and angle |
| C | Cellular caves | random fill ~45%; ×4: rock if ≥ 5 of 8 neighbours are rock (out-of-bounds = rock); flood-fill, keep the largest region | Catacombs — denser fill, rule 6 |
| B | BSP rooms | split the rect recursively; a room per leaf; corridors between *siblings* up the tree → connected by construction | Bunker — more splits, tiny rooms |
| M | Maze | **backtracker**: carve into a random unvisited neighbour, back up when stuck (long, winding). **Prim's**: carve a random frontier wall (short, branchy). Count dead ends | Meander — `algo: "prim"`, bigger |
| W | WFC (tiled) | pick the cell with fewest options; choose one; remove forbidden tiles from neighbours; repeat; no options left = contradiction → restart | Wetlands — rules favouring water |
| A | Autotile | `index = N·1 + E·2 + S·4 + W·8` picks the tile (16); 8-bit adds diagonals, counted only when both adjacent edges are walls (47) | Archipelago — 8-bit, sand meets sea |
| D | Dice | weighted pick = walk the table subtracting weights; **shuffle bag** = draw without replacement; **pity timer** = rare weight grows per miss | Drops — a legendary within 20 |
| H | Horde | intensity curve over time with rests; spawn interval shrinks with intensity; spawn off-screen | Hush — long rests, small peaks |
| S | Save | state → plain object → JSON; `version` field; migrate old saves on load | Suspend — one slot, deleted on load |
| S | Seed | same seed → same sequence → same world; `seed + 1` → a different one | Sibling — three seeds side by side |

## The load-bearing snippets

```
// mulberry32 — a seeded rng, identical on every machine
function mulberry32(a) { return function () {
  a = (a + 0x6D2B79F5) | 0;
  let t = Math.imul(a ^ (a >>> 15), 1 | a);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
rng = mulberry32(4477);   // never Math.random() inside a world

// one cellular-automaton pass (count out-of-range as rock)
for each cell: next[x][y] = (rockNeighbours8(x, y) >= 5) ? ROCK : OPEN

// Bridson's Poisson step
p = active[random];  try 30×: c = p + polar(r + rng()*r, rng()*2π)
  if inBounds(c) and nothing within r (the 5×5 grid cells around c): accept c, push to active, break
none fit → remove p from active

// 4-bit autotile index
i = (wall(x, y-1) ? 1 : 0) | (wall(x+1, y) ? 2 : 0) | (wall(x, y+1) ? 4 : 0) | (wall(x-1, y) ? 8 : 0)

// shuffle bag (fair random)
bag = []; for each entry: push it `weight` times;  shuffle(bag, rng)
draw = () => (bag.length ? bag : refill()).pop()

// versioned save + migrate
save = { version: 3, ...state };  text = JSON.stringify(save)
s = JSON.parse(text);  if (s.version < 2) s.keys = [];  if (s.version < 3) s.gold ??= 0;  s.version = 3
```

## Engine spellings

| | Godot | Unity | Unreal |
|---|---|---|---|
| seed | `RandomNumberGenerator.seed`, `seed()` | `Random.InitState`, `System.Random(seed)` | `FRandomStream(seed)` |
| noise | `FastNoiseLite` (`fractal_octaves`, `TYPE_CELLULAR` for Voronoi) | `Mathf.PerlinNoise` (sum octaves yourself) | `FMath::PerlinNoise2D`; Landscape |
| tiles | `TileMapLayer` terrain sets = autotiling | Rule Tiles (2D Tilemap Extras) | Paper2D (hand-roll the bitmask); **PCG** framework for scattering |
| walking the map | `AStarGrid2D` | `NavMesh` | NavMesh, Behavior Trees |
| weighted / shuffle | `rand_weighted`, `Array.shuffle()` | hand-roll, `ScriptableObject` tables | `UDataTable` + `FRandomStream` |
| wave curve | `Curve.sample(t)` | `AnimationCurve.Evaluate(t)` | `UCurveFloat::GetFloatValue(t)` |
| save | `FileAccess` on `user://` + `JSON.stringify` / `parse_string` | `JsonUtility` + `persistentDataPath`; `PlayerPrefs` | `USaveGame` + `SaveGameToSlot` / `LoadGameFromSlot` |

Web: `localStorage.setItem(slot, JSON.stringify(s))`. L-systems and WFC are hand-rolled everywhere (30–80 lines each; WFC also has community packages and an experimental Unreal plugin).

## What goes wrong

one unseeded call breaks the seed · caves in pieces → flood-fill the largest region · WFC contradiction → restart with the next seed, and test the rule table on 3×3 · autotile looks shuffled → bit order ≠ sheet order · saves without `version` crash on the first update · a director that never rests reads as unfair · generated ≠ interesting → hand-place the landmarks, show the seed.

**Free deep dives:** [Red Blob Games](https://www.redblobgames.com/) — Amit Patel's interactive articles on noise, hex grids, Poisson scattering and map generation · [Procedural Content Generation in Games](https://pcgbook.com/) — the whole textbook, free online.
