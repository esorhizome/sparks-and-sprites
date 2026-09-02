# 04 · Backgrounds, programmatically

*Fresh-start note: a **texture** is an image loaded for drawing; **UV coordinates** are positions within a texture from (0,0) to (1,1); **noise** is smooth organic randomness (blurred static); a **tween** animates a value from A to B over time. All re-mentioned in place below.*

---

## 1 · Flat colour & gradients (never skip this option)

A well-chosen two-colour vertical gradient is a legitimate *finished* background — much of the most-loved indie art direction is exactly this.

- **Godot:** a `ColorRect`, or a `GradientTexture2D` on any sprite.
- **Unity:** camera clear colour, or a UI image with a gradient sprite. *Try it: tween (animate over time) the camera's `backgroundColor` between a dawn and a dusk colour — a living sky in four lines.*
- **Unreal:** a post-process tint, or an unlit gradient material on a backdrop plane.
- **Web:** `background: linear-gradient(…)` — arguably the best gradient tool on any platform.

▶ *When the gradient IS the picture* — a sunrise on a clock, a dusk with stars arriving, a mountain range dissolving into the air, cloud bands, a receding sea — that is [chapter 16](16-depth-without-a-third-dimension.md) and [the depth atlas](https://esorhizome.github.io/sparks-and-sprites/depth.html) (its *Skies* and *Distance* families are this section grown up: 25 editable backdrops, each with a rhyme).

## 2 · Parallax scrolling

Far layers move slower than near layers as the camera pans; the brain reads depth instantly.

```text
# the whole idea, engine-neutral
far_layer.x  = camera.x * 0.2
mid_layer.x  = camera.x * 0.5
near_layer.x = camera.x * 0.9
```

- **Godot:** the `Parallax2D` node — one per layer, set `scroll_scale` (0.2 mountains, 0.6 trees).
- **Unity:** literally the three lines above in `LateUpdate()`, one factor per layer.
- **Unreal (2D):** same arithmetic on sprite layers, driven from the camera position.
- **Web:** layered elements whose `transform: translateX()` is a fraction of scroll position.

▶ *See it:* [parallax demo](https://esorhizome.github.io/sparks-and-sprites/parallax.html) — move your pointer and feel the depth appear.
🎮 *Godot direct demo:* the **parallax** scene in `demos/godot/` builds three layers from generated textures, in code.

## 3 · Infinite scroll (the UV trick)

Make a texture repeat, then slide its UV offset (the "which part of the image am I reading" coordinates) by time: an endlessly scrolling sky, sea, or starfield from one seamless tile.

- **Godot shader:** `UV += vec2(TIME * 0.03, 0.0);` (texture import set to *Repeat*).
- **Unity:** `material.mainTextureOffset += new Vector2(speed * Time.deltaTime, 0);` — one line in `Update()`. *Try different speeds per layer for cheap parallax-by-scroll.*
- **Unreal:** a *Panner* node in the material editor — it exists precisely for this.
- **Web (CSS, zero code):** animate `background-position` on a repeating background image.

▶ *See it:* [infinite scroll demo](https://esorhizome.github.io/sparks-and-sprites/scroll-uv.html)

## 4 · Procedural backgrounds from noise

Feed noise (smooth randomness) into colour and you get clouds, nebulae, fog banks, water caustics — infinite, seamless, no image files.

- **Godot:** `NoiseTexture2D` — a live noise image you can animate and recolour.
- **Unity / Unreal:** noise nodes ship in both shader graphs. *Try it: noise → colour gradient → done; three nodes to a nebula.*
- **Web:** a fragment shader on a full-screen surface, or a pre-rendered noise canvas.
- **Learn gently:** [The Book of Shaders](https://thebookofshaders.com/) — free, interactive, kind.

## 5 · Starfields & drifting ambience

Spawn N tiny dots at random positions; drift them slowly; wrap them at the edges. That's a starfield, dust motes, snow, or fireflies depending on speed, size, and colour — calm by construction.

▶ *See it:* [starfield demo](https://esorhizome.github.io/sparks-and-sprites/starfield.html) — the same code as sparks, at one-tenth speed, no gravity.

## 6 · Skies in 3D (skybox / sky material)

- **Godot:** `WorldEnvironment` → Sky → `ProceduralSkyMaterial` — adjustable at runtime, so a day/night cycle is just tweening its colours.
- **Unity:** Skybox material in Lighting settings.
- **Unreal:** the built-in *SkyAtmosphere* system.
- Free photographic HDRI skies: [Poly Haven](https://polyhaven.com/) — CC0, meaning free for anything, credit not required.

---

*Gradient + parallax + a pinch of noise covers ninety percent of the backgrounds you've ever admired.*
