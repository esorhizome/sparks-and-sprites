# Unreal demos (C++ templates + editor recipes)

Unreal splits its craft differently from the web, Godot, or Unity: some of
this book's demos are naturally **C++** (camera math, procedural meshes,
audio synthesis), while others are naturally **editor work** (Niagara
emitters, material graphs, UMG animations) — writing those in raw C++ would
teach the wrong lesson. So this folder has both kinds:

- `Source/SparksAndSprites/` — C++ actor/component **templates** for the
  code-natural demos. Drop them into any C++ project's module
  (e.g. `Source/<YourModule>/`), add `"Niagara"` to your module's
  dependencies where noted, and place the actors in a level.
- `recipes/` — step-by-step **editor recipes** for the Niagara/material
  demos, with the exact values used by the web and Godot versions, so the
  three stay comparable side by side.

> **Status: templates.** Written against Unreal 5.x API and kept close to
> the book's chapter text, but not yet part of a committed .uproject —
> that arrives as assets are imported gradually. Every file names the
> intent of each line, so version drift is a local fix.

## The demos

| Demo | Where | Form |
|---|---|---|
| Sprite basics | `recipes/sprite-basics.md` | Paper2D / UMG recipe |
| Movement personalities | `Source/.../SSEasingPersonalities.*` | C++ actor |
| Sparks | `recipes/sparks.md` | Niagara burst recipe |
| Flame (+ smoke/fountain/ember ring) | `recipes/flame.md` | Niagara recipe |
| Parallax | `Source/.../SSParallax.*` | C++ actor |
| Infinite scroll | `Source/.../SSScrollUV.*` | C++ actor + material recipe |
| Additive glow | `recipes/glow-additive.md` | material recipe |
| Dissolve | `recipes/dissolve.md` | material graph recipe |
| Sound blips | `Source/.../SSSoundBlips.*` | C++ actor (procedural audio) |
| Trails | `recipes/trails.md` | Niagara ribbon recipe |
| Fragmented trails | `recipes/trails-fragments.md` | Niagara spawn-per-unit recipe |
| Waterdrops | `recipes/waterdrops.md` | Niagara event-handler recipe |
| Halo | `recipes/halo.md` | material + timeline recipe |
| Chrome & liquid metal | `recipes/metal-chrome.md` | material recipe |
| Living buttons | `recipes/glow-buttons.md` | UMG recipe |
| Responsive cursor | `Source/.../SSCursorCompanion.*` | C++ actor |
| Starfield & ambience | `recipes/starfield.md` | Niagara recipe |
| Screen shake | `Source/.../SSTraumaShake.*` | C++ component |
| Planet (3D) | `Source/.../SSPlanet.*` | C++ actor (ProceduralMesh) |
| Orbit & glow (3D) | `Source/.../SSOrbitGlow.*` | C++ pawn |
| Elemental buttons | `recipes/elemental-buttons.md` | UMG anatomy recipe |
| Cube codex (character VFX) | `Source/.../SSCubeVfx.*` + `recipes/cube-vfx.md` | C++ actor with Niagara effect slots + family map |

The full 104-button bestiary lives on
[the web page](https://esorhizome.github.io/sparks-and-sprites/elemental-buttons.html)
and in the Godot project (`demos/godot/scenes/elements/` — all 104 in
GDScript). The Unreal recipe ports the **anatomy** (idle loop + press
reaction) and shows where each family's mechanism maps onto UMG, Niagara,
or a material.
