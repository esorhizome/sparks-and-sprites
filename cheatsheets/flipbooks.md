# Cheatsheet · Transparent flipbooks

Everything = **bake the drawing once, choose a frame with arithmetic, copy a rectangle.** Full chapter: [15](../chapters/15-transparent-flipbooks.md). Live demos: [the flipbook folio](https://esorhizome.github.io/sparks-and-sprites/flipbook.html) (26 sheets, A–Z, editable).

## The two index lines (the entire technology)

```
// loop                              // one-shot (last frame baked EMPTY)
i = floor(t * fps) % N               i = min(N - 1, floor((t - t0) * fps))
```

## The A–Z, one line each

| Card | Effect | The bake in one breath |
|---|---|---|
| A | Aura | breathing halo; phase `i/N` (never `i/(N−1)`) hides the loop seam |
| B | Burst | 12 rays race out on `k^0.65`, shorten as they die; birth flash < 0.22 |
| C | Confetti | flecks on `v·t + ½g·t²` — ballistics happen once, at bake time |
| D | Dustkick | 6 ground-hugging puffs; **source-over** — dust is matter, not light |
| E | Embers | per-particle clock `(i/N + offset) mod 1` — every path seamless |
| F | Flame | 3 glow layers wobbling on offset sines, shrinking upward |
| G | Glint | one highlight travels a fixed diagonal; brightness `sin(p·π)` |
| H | Heal | Embers recoloured green + tiny plusses — palettes are half of VFX |
| I | Impact | thinning shock ring + shrinking 4-star; 8 frames × 24 fps = 0.33 s |
| J | Jet | additive hot core loop + drifting exhaust puffs, one sheet |
| K | Kapow | comic star scales past 1 and settles (overshoot baked into the curve) |
| L | Lightning | a FRESH jagged path each frame (seed = base + i) — chaos reads as energy |
| M | Magicircle | two rune rings counter-rotate in one sheet; layers cost nothing baked |
| N | Nova | flash shrinks while ring expands — two crossing curves |
| O | Orbit | 3 motes at `kl·2π + j·2π/3`, squashed to an ellipse, baked tails |
| P | Poof | 5 grey blobs swell + rise + thin to nothing; play over any despawn |
| Q | Question | a "?" pops with overshoot — glyphs bake like anything else |
| R | Ripple | 3 flat ellipses on offset phases; the y-squash IS the water surface |
| S | Sparkle | 8 twinkles, each `sin²` blinking on its own phase of one clock |
| T | Trailslash | arc sweeps a→b; ghost arcs behind = free baked motion blur |
| U | Updraft | S-curved wind streaks rising on offset clocks; 16 frames hide the loop |
| V | Vortex | specks spiral inward on `(kl+off) mod 1` — born at the rim as twins die |
| W | Warp | rim wobbles on 2-lobe sine (lobes × laps must divide the loop evenly) |
| X | Xslash | two cuts land 3 frames apart — stagger sub-timelines inside one strip |
| Y | Yell | 3 arc-triplets ripple from the mouth + first-instant speedline ticks |
| Z | Zap | short arcs re-rolled per frame around the body; every 4th frame surges |

## The rules that keep working

- **Loops phase on `i/N`; one-shots on `i/(N−1)`** — swap them and loops pop / one-shots cut early.
- **Last frame of a one-shot = empty.** Holding on the end IS being over; no cleanup code.
- **Light plays additive, matter plays normal.** The sheet doesn't know; the playback blend decides.
- **Seed the randomness** (same seed → same sheet, coherent frames) — except electricity, which re-rolls per frame on purpose.
- **Pad cells 1–2 transparent px** or bilinear filtering bleeds neighbours; dark fringes on fading glows = a premultiplied-alpha disagreement (fix the export flag, not the art).
- Typical numbers: loops 12–16 frames × 12–16 fps; hits 8–12 × 18–24 (brief reads as strong); smoke 10 × 15.

## Engine spellings

| | Import & slice | Play | Particles play the book |
|---|---|---|---|
| **Godot** | `AtlasTexture` regions (or SpriteFrames editor) | `AnimatedSprite2D` + `SpriteFrames`; loop flag off = one-shot; `animation_finished` → despawn | particle anim h/v frames |
| **Unity** | Sprite Mode **Multiple** + Sprite Editor grid | swap `SpriteRenderer.sprite` by index / Animation clip | Texture Sheet Animation module; Shader Graph **Flipbook** node |
| **Unreal** | *Extract Sprites* → *Create Flipbook* (Paper2D) | `UPaperFlipbookComponent`; `SetLooping(false)` + `PlayFromStart()` | Niagara **Sub UV** (SubImage Index over age); material `SubUV_Function` |
| **Web** | just a PNG | 9-arg `drawImage(sheet, i·S, 0, S, S, x, y, w, h)`; `"lighter"` for light | CSS `steps(N)` on `background-position` (no JS at all) |

**Code-baked, no assets:** web [flipbook.js](https://esorhizome.github.io/sparks-and-sprites/flipbook.html) · Godot [`flipbook.gd`](../demos/godot/scenes/flipbook.gd) (SubViewport bake, menu key **G**) · Unity [`FlipbookVfx.cs`](../demos/unity/Scripts/FlipbookVfx.cs) (`SetPixels` bake) · Unreal [`SSFlipbookVfx.*`](../demos/unreal/Source/SparksAndSprites/SSFlipbookVfx.cpp) (transient `UTexture2D` + SubUV) + [recipe](../demos/unreal/recipes/flipbook-vfx.md).

**Free sheets:** Kenney particle/explosion packs (CC0) · OpenGameArt VFX (check each license) · itch.io free VFX packs — all arrive as exactly this format.
