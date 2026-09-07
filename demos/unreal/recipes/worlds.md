# The world workshop — procedural generation, in PCG, Blueprint and C++

The workshop (docs/worlds.html) is thirteen generators, each with a rhyme
— scatter and noise, rooms, caves and mazes, dice, waves and saves — and
one promise carried over from chapter 1's glossary: **one seed reproduces
the world**. Unreal has a framework for the scatter half (**PCG**, the
Procedural Content Generation plugin, 5.2+), a seeded stream for
everything else (`FRandomStream`), and nothing at all for caves, BSP,
mazes or wave-function collapse — those are Blueprint loops over a
`TArray<uint8>`, which is exactly what the web cards are. Every value
below is the card's value.

## Seeds first (the last card, done first)

- **FRandomStream(Seed)** — `RandRange`, `FRand`, `GetUnitVector`,
  `Reset()` to replay. In Blueprint it is the *Random Stream* struct:
  **Make Random Stream** (*Initial Seed* 4477), then the *… from Stream*
  family — *Random Integer in Range from Stream*, *Random Float from
  Stream*, *Random Unit Vector from Stream*, *Reset Random Stream*, *Set
  Random Stream Seed*. Never mix in plain *Random Integer* — it is the
  unseeded global stream and the world stops reproducing.
- PCG nodes each carry a **Seed** pin (and the graph a *Seed* on the PCG
  Component); a node's effective seed also mixes the component's and the
  actor's position, so *Use Seed* semantics are documented per node.
- **Seed** card: two PCG volumes (or two Blueprint grids) with the same
  seed render identically, a third with `seed + 1` differs; the "first few
  outputs" panel = the first 8 `FRand()` values printed as text. Unreal's
  stream is not mulberry32, so the numbers differ from the web page but
  the lesson (same seed → same list) is the same.

## PCG — the scatter family

Enable *Procedural Content Generation Framework* (Edit → Plugins). Create
a **PCG Graph** asset and put a **PCG Volume** in the level (or a *PCG
Component* on any actor). The graph's *Input* gives you the volume's
surface; the nodes below are its vocabulary (right-click → search by name):

| Card | PCG graph |
|---|---|
| Poisson | **Surface Sampler** (*Points Per Squared Meter*, **Looseness** 1.0 — the packing, *Point Extents* = r/2 — points cannot overlap their extents, which is the min-distance rule) → **Density Filter** (*Lower Bound* 0.3) → **Transform Points** (random scale / yaw, *Absolute* off) → **Static Mesh Spawner** (a *Mesh Entries* list with weights). For a strict grid instead of blue noise, **Points Grid** / **Create Points Grid** (*Cell Size*, *Grid Extents*). The naive side strip = Surface Sampler with *Looseness* 0 and no extents. *Pinprick* = *Points Per Squared Meter* 40, extents 5 |
| Terrain | landscape from noise: **Landscape** mode → *Import from File* a 16-bit heightmap you generated (a Blueprint / Python loop writing `FMath::PerlinNoise2D(FVector2D(x, y) × Freq) × Amp` per octave, amplitude halving — `PerlinNoise2D` returns −1…1, sum octaves 1/1 + 1/2 + 1/4 + 1/8), or a **Landscape Layer Blueprint Brush** (Landscape → *Edit Layers* → *Blueprint Brush*) for live noise. Biomes by height = a landscape material with **Landscape Layer Blend** weights from `WorldPosition.Z` bands (water < 0, sand, grass, rock, snow). Side-view 2D: a **Procedural Mesh** ribbon from the same octave sum, drawn one octave at a time |
| Voronoi | PCG has no Voronoi node; in a material, the **Noise** node with *Function* = **Voronoi** (*Scale*, *Quality*, *Levels*) gives cell IDs for biome tinting; for gameplay regions, a Blueprint grid where each cell stores the index of the nearest seed (Euclidean or `|dx| + |dy|` for *Vitreous*'s Manhattan), painted with a **Canvas Render Target 2D** *Draw Texture* per cell; seeds drift and the grid recomputes on a *Set Timer* (64×40 is instant) |
| Lsystem | a Blueprint: rewrite `Axiom` by `Rule` N times (a `String` loop), then a turtle emitting **Spline Component** points (F = advance by `Step`, +/− = yaw by `Angle`, `[` / `]` push / pop a `TArray<FTransform>` stack), each segment a **Spline Mesh Component** (or **Instanced Static Mesh** cylinders); one iteration per beat via *Set Timer by Event*. PCG alternative (5.3+): **Spline Sampler** on the resulting spline to hang leaves. *Lichen* = `Rule` "F[+F]F[−F][F]", `Angle` 25 |

## Rooms, caves and mazes — Blueprint over a `TArray<uint8>`

A grid is a flat array: `Index = Y × Cols + X`; the cell is a `uint8`
(Blueprint: *Byte*, or an Enum — Rock / Floor / Wall / Door). Two helper
functions carry every card: `Get(X, Y)` (out of bounds = rock) and
`Set(X, Y, V)`. Draw the grid with a **Paper Tile Map** (2D), an
**Instanced Static Mesh** per cell type (3D), or a **Canvas Render Target
2D** for the debug picture; animate a pass per beat with *Set Timer by
Event* (0.4 s).

| Card | Blueprint / C++ |
|---|---|
| Caves | fill: `Get(X, Y) = Stream.FRand() < 0.45` (a `FRandomStream`); pass: for every cell count the 8 neighbours (`Get` handles edges as rock) → new cell = `count ≥ 5`; write into a **second array** and swap (never in place). 4 passes, one per beat. The largest open region = a flood fill (a `TArray<int32>` queue, breadth-first) keeping the biggest, rock-filling the rest. *Catacombs* = fill 0.52, rule 6 |
| Bsp | a recursive function on a `FIntRect` leaf: stop below *Min Size* (8), else split at `Stream.RandRange(0.3, 0.7)` of the longer side (a struct array is the tree; children indices 2i+1 / 2i+2); a room inset 1–2 cells inside each leaf; connect **siblings** by an L-shaped corridor between room centres, then their parents' corridors up the tree. The little tree beside the map = *Draw Line* in the RT per split. *Bunker* = *Min Size* 5, rooms 3×3, corridors straight |
| Maze | cells as walls-bits (`uint8` with N/E/S/W bits 1/2/4/8, all set); **backtracker**: a stack, carve to an unvisited random neighbour (from the stream), pop when stuck — long corridors; **Prim**: a frontier array, pop a random frontier cell, carve to a random visited neighbour — branchy. Dead ends = cells with exactly three wall bits. The `algo` dial is a Blueprint Enum + a *Switch*. Unreal has no maze node; PCG's *Grid* nodes only place, they don't carve |
| Wfc | the simple tiled version: per cell a bitmask of allowed tiles (`uint8`: grass 1, sand 2, water 4 — three tiles fit a byte); rules as an adjacency table (`TMap<uint8, uint8>` allowed-neighbours per tile per side); loop: pick the cell with the fewest set bits > 1 (entropy = `CountBits`), collapse it with the stream (weights for *Wetlands*), propagate to neighbours with a queue until nothing changes; a cell reaching 0 = contradiction → restart with the next seed. Draw the bit count on undecided cells as **Text Render** or RT text. 5.x has an experimental *WaveFunctionCollapse* plugin (a **WFC Model** asset + a Blueprint solve call) — the same algorithm in 3D tiles |
| Autotile | **Paper Tile Maps have no rule tiles.** The bitmask lookup is yours: for each wall cell, `Index = N×1 + E×2 + S×4 + W×8` (4-bit, 16 tiles) or the 8-bit variant with corners masked to 47 tiles; a `TArray<int32>` of 16 (or 47) tile indices maps mask → tile; then **Paper Tile Map Component** → **Set Tile** (X, Y, Layer, a *Paper Tile Info* with *Tile Set* + *Packed Tile Index*) and *Rebuild Collision*. Paint = *Set Tile* on click, re-run the mask on the 8 neighbours only. 3D: the same index picks a wall **Static Mesh** variant in an ISM. *Archipelago* = `bits` 8, sand/sea tile set |

## Dice, waves and saves

| Card | Unreal spelling |
|---|---|
| Dice | weighted pick: prefix sums over `TArray<float> Weights`, `r = Stream.FRandRange(0, Total)`, first index whose prefix ≥ r; the **shuffle bag**: a `TArray<int32>` filled with each entry × its count, shuffled with the stream (Fisher–Yates: `Swap(i, Stream.RandRange(0, i))`), popped from the back, refilled when empty; the **pity timer**: `RareWeight × (1 + Misses / 10)`, reset on a rare. *Data Tables* (`FTableRowBase` rows: Name, Weight, Rarity) hold the loot table; *Get Data Table Row Names* + *Get Data Table Row* read it. *Drops* = hard pity at 20 |
| Horde | the wave curve = a **Curve Float** asset (*Get Float Value* at `Time` — peaks and rests drawn in the curve editor); spawn budget per second = `Intensity × Max`; spawn points = **Target Point** actors off-screen (or *Get Actor Bounds* of the camera frustum → choose outside); enemies walk a **Nav Mesh** (*Nav Mesh Bounds Volume*, *AI Move To* the base). The playhead = the current curve time drawn on a UMG Image. *Hush* = a curve with 20 s rests, peaks at 0.3 |
| Save | **USaveGame**: a Blueprint class from *Save Game* with the state as variables **plus an `int32 Version`**; *Create Save Game Object* → fill → **Save Game to Slot** (*Slot Name* "Slot1", *User Index* 0); **Load Game from Slot** → *Cast* → if `Version < Current` run the migration (default the missing field — a variable added after the save exists loads as its class default, so most migrations are "if Version < 2, set X from Y"), then set `Version = Current`. The JSON panel: *SaveGame* serialises binary, so for the readable text build an `FJsonObject` (`FJsonObjectConverter::UStructToJsonObjectString` in C++, or the *JSON Blueprint Utilities* plugin's *Struct to Json String*) and draw it in a **Multi-Line Editable Text**. Three slots = three slot names; **Does Save Game Exist** for the slot list. *Suspend* = **Delete Game in Slot** right after a successful load |
| Seed | as above: `FRandomStream(Seed)` per panel, `Reset()` to replay the same world; the seed entry = an **Editable Text Box** → *String to Int*. The rule the whole workshop keeps: every generator takes its stream as an input and never calls the global random |

## The 2D spelling

The grid families are 2D already; the 2D *container* is **Paper Tile Map**
(a **Tile Set** from a sprite sheet, *Tile Width/Height* 16, per-tile
collision drawn in the Tile Set editor) written with *Set Tile* /
*Rebuild Collision*, or, for the debug pictures, a **Canvas Render Target
2D** shown on a sprite or a UMG Image. Scatter in 2D: PCG works in any
volume — sample a flat plane and spawn **Paper Sprite Actors** (the
*Spawn Actor* node, an actor class per entry, instead of Static Mesh
Spawner); or skip PCG and loop a stream over `Random Point in Bounding
Box from Stream` with the r-check. Terrain in 2D is the octave sum as a
Procedural Mesh ribbon or a tile column height.

## The 3D sibling

PCG is the 3D home: the Poisson scatter becomes forests, the Voronoi
grid becomes biome regions feeding **Static Mesh Spawner** entries by
attribute (*Attribute Filter* on a `Biome` attribute), the BSP rooms
become **Level Instances** or ISM wall pieces placed by the same
indices, and the noise terrain is a real **Landscape** — the whole
workshop, with the seed on the PCG Component's *Seed* property so the
level rebuilds identically on *Generate*.
