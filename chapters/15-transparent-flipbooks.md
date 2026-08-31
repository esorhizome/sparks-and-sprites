# 15 · Transparent flipbooks — VFX as pre-baked frames

*Fresh-start note (no memory of other chapters required): a **sprite** is an image the engine can place and move; a **texture** is image data living on the graphics card; **alpha** is the per-pixel number that says how see-through that pixel is (0 = invisible, 1 = solid); **UV coordinates** name a position *inside* a texture, from (0,0) to (1,1); **additive blending** means a drawn pixel's colour is ADDED to what's behind it (light on light gets brighter), while normal ("source-over") blending covers what's behind. Each is re-mentioned in place.*

---

Every VFX chapter before this one drew its effects **live** — particle positions computed every frame, glows re-painted every frame. This chapter is about the other half of how real games ship visual effects, and it is older than computers: draw the animation **once**, as a row of pictures, and then flip through them. A **flipbook** (the common word is **sprite sheet**; "flipbook" is the same idea said by Unreal people) is many frames of one animation packed into a single texture — and for VFX specifically, packed with a **transparent background**, so the explosion, smoke puff, or magic circle can be stamped over *any* scene and only the effect's own pixels show.

The playback technology is two lines of arithmetic, and this chapter will not pretend otherwise:

> **A loop shows frame `⌊t · fps⌋ mod N`. A one-shot shows `min(N−1, ⌊(t−t₀) · fps⌋)` — and bakes its last frame empty, so "holding on the end" and "the effect is over" are the same statement.**

Everything else is bake-time craft. That's the trade the technique makes: all the cleverness moves to *before the game runs*, and the runtime cost collapses to "copy a rectangle" — which is why flipbooks power VFX on hardware from a Game Boy to a render farm, and why every engine made this century has first-class machinery for them.

▶ *See it all:* **[the flipbook folio](https://esorhizome.github.io/sparks-and-sprites/flipbook.html)** — 52 VFX baked into transparent sheets, the alphabet twice over, every one editable in the page. Each card bakes its own sheet from code when it wakes (no image files anywhere), and the filmstrip under each card is the *actual baked texture*, checkerboarded so the transparency is visible. The same 52 are fully ported to GDScript ([`demos/godot/scenes/flipbook.gd`](../demos/godot/scenes/flipbook.gd), menu key **G**).

## When to bake, when to draw live

Neither side wins everywhere; this is the honest decision table:

| Bake a flipbook when… | Draw live when… |
|---|---|
| the effect is hand-authored art (a drawn explosion has *opinions* per frame) | the effect must respond to the world (a trail follows the mouse) |
| the same effect plays dozens of times at once (each copy costs one rectangle) | you need endless variation (live noise never repeats) |
| the runtime is tight (mobile, huge particle counts, UI) | the effect scales or rotates freely (baked pixels blur when enlarged) |
| you want engine-portability — the same PNG plays everywhere | parameters change mid-play (a heal that grows with the spell level) |
| the simulation is expensive (bake a fluid sim once, replay forever) | memory is tighter than compute (sheets cost texture RAM) |

And the fusion move that professional VFX leans on constantly: **particles that each play a flipbook** — the particle system does placement, velocity, and count live, while each particle's *look* is a baked smoke-puff animation. Every engine below has a one-checkbox version of this.

## The four platforms

The concepts are identical everywhere: *slice the sheet into frames, choose a frame by time, draw it with its alpha respected.* Only the names change accent.

### Godot — yes, natively (you knew this one)

The full stack, all from code if you want it that way (which this book does):

- **`AnimatedSprite2D` + `SpriteFrames`** is the flipbook player: a `SpriteFrames` resource holds named animations (each a list of textures + fps + loop flag), and the node plays them. `sprite_frames.set_animation_loop("fx", false)` + `play("fx")` is the one-shot spelling; the `animation_finished` signal is where a poof despawns its owner.
- **`AtlasTexture`** slices a sheet without copying pixels: point it at the big texture, give it a `region` rectangle per frame. The folio's Godot port builds all of its `SpriteFrames` this way.
- **`GPUParticles2D` particles can each play the book**: set the particle texture to the sheet and *h_frames/v_frames* on the process material's animation section.
- Importing artist PNGs: drop the sheet in the project, keep *Filter* off for pixel art, and slice in the SpriteFrames editor — or at runtime with `AtlasTexture`, exactly as above.

The folio's Godot port bakes its sheets in a `SubViewport` with `transparent_bg = true` — draw the frames with `_draw()` calls, grab the viewport's texture, slice, play. That's also the recipe for baking *any* procedural animation into a sheet inside Godot.

And Godot gets a **depth demo** to pair with the folio's breadth: [`demos/godot/scenes/flipbook_vfx.gd`](../demos/godot/scenes/flipbook_vfx.gd) (menu key **H**) takes *one* 8-frame loop and dresses it completely — rim-glow shader on the sprite, a breathing aura tween period-locked to the loop, a flowing circuit track, an orbiting mote that z-flips behind and in front, click-bursts, an idle-phase cycle, and a right-click dark/light ground swap that the same white frames survive because `modulate` multiplies. Its long-form companion, [`cheatsheets/godot-flipbook-vfx.md`](../cheatsheets/godot-flipbook-vfx.md), is the full conductor's manual: the four clocks (shader `TIME`, `AnimationPlayer`, `Tween`, `Timer`) and the signals that let any effect loop, cycle, *and* trigger around a playing flipbook.

### Unity — yes, three ways

- **Sprite Mode: Multiple** — import the sheet, slice it in the Sprite Editor (grid slicing takes a cell size), and the frames become individual `Sprite` assets you can drop on an Animation clip. This is the designer-facing flipbook.
- **From code**: one `Texture2D` + `Sprite.Create(tex, rect, pivot, ppu)` per frame + swap `SpriteRenderer.sprite` by index. [`demos/unity/Scripts/FlipbookVfx.cs`](../demos/unity/Scripts/FlipbookVfx.cs) does the whole pipeline — including *baking* the sheet in `Start()` with `SetPixels`, so there's no imported asset at all.
- **Particle System → Texture Sheet Animation module** — the particles-play-the-book fusion: give the module the sheet's grid (e.g. 10 × 1) and every particle animates through it over its life.
- **Shader Graph's Flipbook node** — the UV-offset trick as a graph node, for meshes, UI, and VFX Graph output.
- Blending: light effects (bursts, auras) want an additive material; smoke and paper want the default alpha-blended sprite material. Same rule as everywhere in this book: **light adds, matter covers.**

### Unreal — yes, it literally calls them flipbooks

- **Paper2D** is the 2D route: import the sheet → *Extract Sprites* → select all → *Create Flipbook*. A `PaperFlipbook` asset plays on a `UPaperFlipbookComponent`; `SetLooping(false)` + `PlayFromStart()` is the one-shot spelling.
- **Niagara Sub UV** is the particle route: the Sprite Renderer's *Sub Image Size* names the grid, and *SubImage Index* (usually scaled over Normalized Age) chooses the frame. The material samples the sheet through a *Particle SubUV* sampler.
- **Material SubUV** is the anything route: the engine's `SubUV_Function` turns a *Frame* scalar into the right rectangle's UVs on any surface. [`demos/unreal/Source/SparksAndSprites/SSFlipbookVfx.*`](../demos/unreal/Source/SparksAndSprites/SSFlipbookVfx.cpp) bakes a sheet into a transient `UTexture2D` at runtime and drives that scalar from C++.
- [`demos/unreal/recipes/flipbook-vfx.md`](../demos/unreal/recipes/flipbook-vfx.md) walks all three routes with the folio's exact numbers, 2D spellings included.

### The web — yes, and you've already seen the pieces

- **Canvas**: the nine-argument `drawImage(sheet, sx, sy, sw, sh, dx, dy, dw, dh)` copies one source rectangle to one destination rectangle — that *is* a flipbook player. The folio runs on exactly this call, plus `globalCompositeOperation = "lighter"` for the light-family sheets.
- **CSS `steps()`**: put the sheet as a `background-image`, animate `background-position` with `animation-timing-function: steps(N)` — a flipbook with no JavaScript at all. Loading spinners and pixel-art site mascots run on this.
- **WebGL / three.js / Babylon**: offset the texture's UVs per frame (`texture.offset.x = i / N` with `repeat.x = 1 / N` in three.js) — the same SubUV trick Unreal's materials do. Babylon's `SpriteManager` wraps it with a `cellIndex`.
- **`<img>` alternatives that look similar but aren't flipbooks**: animated GIF (no real alpha — GIF transparency is 1-bit, halos get crusty edges), animated WebP/APNG (real alpha, but no frame-level control from code). For *VFX*, prefer a PNG sheet + canvas: you keep the index line, and with it retriggering, scrubbing, and blend modes.

## Bake-time craft — the five lessons the folio teaches

1. **Seamless loops phase on `i/N`, never `i/(N−1)`.** With N frames of a cycle, frame N *is* frame 0 — computing phase as `i/N` means the wrap lands exactly on the start. Use `i/(N−1)` for loops and the loop "pops" once per lap. (One-shots want `i/(N−1)` — 0 to 1 *inclusive*, so the last frame completes the story.)
2. **One-shots clamp; the last frame is authored empty.** `min(N−1, …)` freezes on the final frame forever, so the final frame must be the effect's absence. No cleanup code anywhere.
3. **Light plays additive, matter plays normal.** A baked glow stamped with additive blending brightens the scene like real light; baked smoke stamped additively becomes a glowing ghost. The sheet doesn't know — the *playback* blend decides, so say it next to the fps.
4. **Coherence comes from seeds.** Random-looking effects (embers, confetti) precompute their particle parameters from a **seeded** random generator, then derive each frame from parameters + phase — the same seed gives the same sheet on every machine, and frames stay coherent. Except—
5. **Electricity re-rolls per frame.** Lightning and crackle *want* a fresh random path each frame (seed = base + frame index). Smooth interpolation reads as jelly; per-frame chaos reads as energy.

Two production notes that save real tears: **premultiplied alpha** — some pipelines store colour already multiplied by alpha (Unreal and most GPU particle paths prefer it; canvas and Godot handle it for you); if your baked glow grows a dark fringe where it fades out, the sheet and the blend mode disagree about premultiplication, and the fix is the exporter's "premultiply" checkbox, not artistic despair. And **padding**: with bilinear filtering, frames bleed into their neighbours at the edges — leave 1–2 transparent pixels of margin per cell (the folio's effects simply stay clear of their cell edges, which is the same medicine).

## The 52 — the alphabet, twice

The folio runs A to Z two full laps, so every letter owns two effects. The second lap needed **no new machinery at all** — the same baker, the same two index lines, the same five families — which is the quiet point of it: once the pipeline exists, another 26 effects is just another 26 ideas.

| Family | First lap | Second lap | The lesson each carries |
|---|---|---|---|
| **Glow & flame** | A·Aura, E·Embers, F·Flame, G·Glint, O·Orbit | A·Afterimage, C·Comet, E·Eclipse, F·Fireflies, W·Wisp | seamless `i/N` loops, offset clocks, backward-sampled tails, Lissajous paths with whole-number frequencies |
| **Hits & slashes** | B·Burst, I·Impact, K·Kapow, N·Nova, T·Trailslash, X·Xslash | I·Iceshard, M·Meteor, P·Pop, Q·Quake, U·Uppercut, X·Xstamp | the clamp index line, empty last frames, baked motion blur, staggered acts, hard cuts, squash on landing |
| **Smoke, dust & water** | D·Dustkick, J·Jet, P·Poof, R·Ripple, U·Updraft, V·Vortex | B·Bubbles, D·Drip, G·Geyser, J·Jelly, L·Leaves, R·Rain, S·Snow, T·Tornado | source-over for matter, particles born as their twins die, squash-and-stretch, tempo as weather |
| **Magic & sparkle** | H·Heal, L·Lightning, M·Magicircle, S·Sparkle, W·Warp, Z·Zap | O·Omen, V·Venom | counter-rotating layers, per-frame chaos, slow one-shots that play a mood instead of a bang |
| **Speech & celebration** | C·Confetti, Q·Question, Y·Yell | H·Hearts, K·Knockstars, N·Notes, Y·Yoyo, Z·Zzz | ballistics baked at bake time, glyphs as frames, piecewise clocks, effects aimed at the player |

Every card's playback line, blend mode, frame count, and fps are printed on the card — the folio is its own cheatsheet.

## Free sheets, if you'd rather not bake

Chapter 08's rules apply unchanged (check the license, credit when asked). Kenney's particle packs and explosion sheets (CC0), OpenGameArt's VFX section (filter by license), and itch.io's free VFX packs are all delivered as exactly what this chapter describes: PNG sheets with transparent backgrounds, usually with the grid size in the filename. Whatever engine you're in, the import recipe above takes them from download to playing in minutes — which is the whole point of a format this old and this universal.
