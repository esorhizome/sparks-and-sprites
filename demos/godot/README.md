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
| Elemental buttons (sampler) | `scenes/elemental_buttons.gd` | elemental-buttons | 12 |

The elemental-buttons scene ports **one button per element family** (14 of
the web page's 104) — enough to show the anatomy in GDScript; the web page
remains the full bestiary.

`smoke_test.gd` is not a demo — it's the project's health check. It cycles
every scene headlessly and injects clicks/keys/drags:

```
godot --headless --path . -s res://smoke_test.gd
```
