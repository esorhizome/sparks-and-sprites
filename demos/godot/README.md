# Godot demos

1. Install [Godot 4.x](https://godotengine.org/) (free, ~100 MB, no account).
2. Project manager → **Import** → pick this folder's `project.godot`.
3. Press **F5**. Number keys open demos; **Esc** returns to the menu.

Every scene here is a bare `Node2D` with one script; the script builds the
entire demo in `_ready()`. That's deliberate — it means **the script is the
demo**, with nothing hidden in editor panels. Open any `.gd` file in
`scenes/`, read top to bottom, change a number, press F5 again.

| Demo | Script | Book chapter |
|---|---|---|
| Sprite basics | `scenes/sprite_basics.gd` | 02 |
| Movement personalities | `scenes/personalities.gd` | 05 |
| Sparks | `scenes/sparks.gd` | 06 |
| Flame | `scenes/flame.gd` | 06 |
| Parallax | `scenes/parallax.gd` | 04 |
| Infinite scroll | `scenes/scroll_uv.gd` + `shaders/scroll_uv.gdshader` | 04 |
| Additive glow | `scenes/glow.gd` | 03 |
| Dissolve | `scenes/dissolve.gd` + `shaders/dissolve.gdshader` | 03 |
| Sound blips | `scenes/sound_blips.gd` | 07 |
