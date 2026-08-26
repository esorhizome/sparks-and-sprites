# Godot demos

1. Install [Godot 4.x](https://godotengine.org/) (free, ~100 MB, no account).
2. Project manager → **Import** → pick this folder's `project.godot`.
3. Press **F5**. Click a demo on the menu (or press its key); **Esc** returns.

Every scene here is a bare `Node2D` (or `Node3D`) with one script; the script
builds the entire demo in `_ready()`. That's deliberate — it means **the
script is the demo**, with nothing hidden in editor panels. Open any `.gd`
file in `scenes/`, read top to bottom, change a number, press F5 again.

Every demo in [the web gallery](https://esorhizome.github.io/sparks-and-sprites/)
has its Godot twin here:

| Demo | Script | Web twin | Book chapter |
|---|---|---|---|
| Sprite basics | `scenes/sprite_basics.gd` | sprite-basics | 02 |
| Movement personalities | `scenes/personalities.gd` | easing-personalities | 05 |
| Sparks | `scenes/sparks.gd` | sparks | 06 |
| Flame | `scenes/flame.gd` | flame | 06 |
| Parallax | `scenes/parallax.gd` | parallax | 04 |
| Infinite scroll | `scenes/scroll_uv.gd` + `shaders/scroll_uv.gdshader` | scroll-uv | 04 |
| Additive glow | `scenes/glow.gd` | glow-additive | 03 |
| Dissolve | `scenes/dissolve.gd` + `shaders/dissolve.gdshader` | dissolve | 03 |
| Sound blips | `scenes/sound_blips.gd` | sound-blips | 07 |
| Trails | `scenes/trails.gd` | trails | 06 |
| Fragmented trails | `scenes/trails_fragments.gd` | trails-fragments | 06, 12 |
| Waterdrops | `scenes/waterdrops.gd` | waterdrops | 06 |
| Halo | `scenes/halo.gd` | halo | 06 |
| Chrome & liquid metal | `scenes/metal_chrome.gd` | metal-chrome | 06 |
| Living buttons | `scenes/glow_buttons.gd` | glow-buttons | 12 |
| Responsive cursor | `scenes/cursor_sparkle.gd` | cursor-sparkle | 12 |
| Starfield & ambience | `scenes/starfield.gd` | starfield | 06 |
| Screen shake | `scenes/shake.gd` | shake | 06 |
| Planet (3D) | `scenes/planet_3d.gd` | three-planet | 11 |
| Orbit & glow (3D) | `scenes/orbit_glow_3d.gd` | babylon-scene | 11 |
| Elemental buttons (all 104) | `scenes/elemental_buttons.gd` + `scenes/elements/` | elemental-buttons | 12 |
| Cube codex (all 104) | `scenes/cube_vfx.gd` + `scenes/cubefx/` | cube-vfx | 06 |

## The bestiary, in full

`scenes/elemental_buttons.gd` is the **complete port of the web page's 104
elemental buttons** — fourteen element families, one GDScript file per
family in `scenes/elements/`, paged by family in the scene (←/→ turns the
page). Every button keeps the same anatomy as the web original: `init()`
seeds state, `tick()` advances it, `draw()` paints it, `press()` reacts.

**A note on capability, since it's worth saying plainly:** nothing in the
web bestiary is beyond Godot. Everything the HTML canvas does — gradients,
additive light, clipping, trails — has a Godot spelling, and where the
spelling differs, the port says so in place:

- canvas radial gradients → layered translucent circles (`elements/kit.gd`);
- the `lighter` composite blend → the same layering, or a
  `CanvasItemMaterial` with `BLEND_MODE_ADD` per node;
- canvas `clip()` → bounded drawing (or a `SubViewport` when you need it);
- trail-by-not-clearing → an explicit history array, redrawn with fading
  alpha — Godot clears every frame, so the trail's memory is made visible.

Those are translations, not compromises: `_draw()` plus plain arithmetic
covers the entire 104.

## The cube codex, in full

`scenes/cube_vfx.gd` is the same treatment for **character VFX**: the web
page's 104 cube effects (firebursts, waterhoses, sky bolts, following
halos, dash afterimages, hit sparks, capes…), fourteen family files in
`scenes/cubefx/`, paged in one scene. `scenes/cubefx/kit.gd` owns the
protagonist — its patrol, shadow, lean, and eyes — and every effect draws
behind it, calls `draw_cube`, then draws in front: the sandwich is the
whole layering system, exactly as on the web page.

## Health checks

None of these is a demo — they're how the project verifies itself:

```
godot --headless --path . -s res://smoke_test.gd     # every scene + injected input
godot --headless --path . -s res://bestiary_test.gd  # all 104 buttons: init/tick/press/draw
godot --headless --path . -s res://codex_test.gd     # all 104 cube effects, same regimen
```
