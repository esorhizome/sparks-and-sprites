# 03 · Combining images & VFX with sprites

*Fresh-start note (no memory of other chapters required): a **sprite** is an image placed on screen; a **shader** is a tiny program that decides each pixel's colour; **alpha** means transparency (1 = solid, 0 = invisible); a **blend mode** is the rule for how a sprite's colours mix with what's behind it. Each will be re-mentioned where used.*

---

Seven composable tricks. Almost every impressive screenshot is three or four of these stacked.

## 1 · Layering (draw order as a design tool)

A "character" in polished 2D games is usually a *stack*: shadow blob underneath, body, then a glow sprite in additive blend mode (the "made of light" mixing rule) on top.

- **Godot:** child order + `z_index`.
- **Unity:** *Sorting Layers* + *Order in Layer*. *Try it: give the shadow sprite Order −1 and the glow Order +1 — that's the whole system.*
- **Unreal:** translucency sort priority / widget Z-order.
- **Web:** CSS `z-index`, or simply draw order on a canvas.

## 2 · Tint & hit-flash

Multiplying a sprite's colours by a tint colour is free and built-in everywhere: Godot `modulate`, Unity `SpriteRenderer.color`, Unreal *Color and Opacity*, CSS `filter: hue-rotate() / brightness()`.

The classic **hit-flash** (whole sprite goes white for three frames when hurt) needs a one-line shader (per-pixel colour program), because tinting can only darken. The shader logic is: `if flashing, output white but keep the sprite's alpha`. Every engine's shader library has a copy-pasteable version — search "flash".

- **Unity try-it:** Shader Graph → a `Lerp` node between the sprite colour and white, driven by a `_Flash` float you set from code. Two nodes. Tweak the flash duration until it feels like *your* game.
- **Unreal try-it:** the same two nodes in the Material editor (`Lerp` + scalar parameter), set from Blueprint with *Set Scalar Parameter*.

## 3 · Additive sprites (the poor-artist's glow)

Take any soft white blob image, set its blend mode (colour mixing rule) to **additive**, tint it, place it over your sprite: instant lamp-light, aura, or magic.

- **Godot:** CanvasItemMaterial → Blend Mode → Add.
- **Unity:** a material using an additive shader (the built-in *Particles/Additive* works on sprites too).
- **Unreal:** material Blend Mode → Additive.
- **Web:** `mix-blend-mode: screen` (CSS) or `ctx.globalCompositeOperation = "lighter"` (canvas).

▶ *See it:* [additive glow demo](https://esorhizome.github.io/sparks-and-sprites/glow-additive.html) — drag the blobs over each other and watch light add up.

Additive layers are also the entire secret of *animated shine*: hold a sprite still and sweep a narrow additive band across it — a metal glint, a UI sheen, a "brand new item" sparkle. [Chapter 06's metal entry](06-vfx-cookbook.md) turns this into a full recipe.

## 4 · Masks (one image decides where another is visible)

Health-bar fills, portrait frames, spotlight reveals, water only inside the pool.

- **Godot:** `clip_children` on any CanvasItem, or `TextureProgressBar` for bars.
- **Unity:** `SpriteMask` component / UI `Mask`. *Try it: a circle SpriteMask over a landscape sprite is a five-second spotlight.*
- **Unreal:** UMG *Retainer Box*, or opacity masks in materials.
- **Web:** CSS `mask-image` and `clip-path` — genuinely excellent and underused.

## 5 · Outlines

The standard recipe is a shader (per-pixel program) that samples the sprite's alpha (transparency) a few pixels in each direction — "am I next to a solid pixel?" — and paints outline colour where the answer is yes.

- **Godot:** copy-paste versions at [godotshaders.com](https://godotshaders.com/) (search "outline").
- **Unity:** Shader Graph outline tutorials are abundant; the sampling idea is identical.
- **Unreal:** material outline node setups; same idea, node form.
- **Web (zero shader):** for DOM images, stack `filter: drop-shadow()` four times (up/down/left/right) — a convincing fake.

## 6 · Dissolve (the noise-threshold trick)

One idea, endless mileage: compare a **noise** texture (smooth organic randomness, like blurred static) against a sliding threshold, and discard pixels below it. Slide the threshold 0→1 and the sprite burns / teleports / crumbles away. Add a bright edge colour just above the threshold for a hot rim.

```glsl
float n = texture(noise_tex, UV).r;        // UV = position within the texture, 0–1
if (n < threshold) discard;                // gone
if (n < threshold + 0.05) COLOR.rgb = edge_glow_colour;  // hot rim
```

This is the "hello world" of shader confidence — three lines of real logic.

▶ *See it:* [dissolve demo](https://esorhizome.github.io/sparks-and-sprites/dissolve.html) — drag the threshold slider yourself.

- **Unity try-it:** Shader Graph — sample a noise texture, `Step` it against a slider property, feed the result to Alpha Clip. Four nodes; then animate the slider from code and watch your sprite evaporate.
- **Unreal try-it:** identical graph in the Material editor (Noise texture → `if`/`Step` → Opacity Mask), threshold as a scalar parameter driven by a Timeline.

## 7 · Palette swap

One character sprite, many colour schemes: a shader looks up each pixel's colour in a small "palette strip" image and replaces it with the matching entry from another strip. Fighting games have done this since the 1990s. Search any engine's shader library for "palette swap" — it's a solved, copyable problem.

## Bonus · 2D lights on sprites

Godot's `PointLight2D` and Unity's *Light 2D* (URP) make sprites respond to light. Give sprites a **normal map** — a second image encoding which way each pixel "faces" — and flat art gains believable depth. On the web, the honest equivalent is additive/multiply light blobs, which is also exactly how consoles did it for decades.

---

*Stack, tint, add, mask, outline, dissolve, relight. Seven verbs — the entire "how did they make it look like that" toolbox.*
