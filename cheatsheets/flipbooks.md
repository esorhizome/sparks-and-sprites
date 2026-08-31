# Cheatsheet · Transparent flipbooks

Everything = **bake the drawing once, choose a frame with arithmetic, copy a rectangle.** Full chapter: [15](../chapters/15-transparent-flipbooks.md). Live demos: [the flipbook folio](https://esorhizome.github.io/sparks-and-sprites/flipbook.html) (104 sheets — the alphabet four times: two teaching laps, two genre laps — all editable).

## The four index lines (now the entire technology)

```
// loop                              // one-shot (last frame baked EMPTY)
i = floor(t * fps) % N               i = min(N - 1, floor((t - t0) * fps))

// ping-pong (Waddle)                // reversed = arrival (Teleport)
p = floor(t * fps) % (2*N - 2)       i = N - 1 - min(N - 1, floor((t - t0) * fps))
i = p < N ? p : 2*N - 2 - p
```

## The A–Z, first lap, one line each

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

## The A–Z, second lap — same machinery, 26 more ideas

| Card | Effect | The bake in one breath |
|---|---|---|
| A | Afterimage | a dasher laps an ellipse; ghosts = the same path sampled slightly in the past |
| B | Bubbles | risers wobble up on offset clocks; the last 15% of each clock is the pop |
| C | Comet | Afterimage's trick at tempo — a tail is backward sampling along the path |
| D | Drip | form → stretch → fall → splash; the first exercise of every animation course |
| E | Eclipse | the moon crosses on `cos(kl·2π)` — twice per lap, so the loop is seamless; one OPAQUE disc forces source-over |
| F | Fireflies | Lissajous wanderers — whole-number frequencies or the loop tears |
| G | Geyser | column up on eased k, crown spray rains down its own sides |
| H | Hearts | two discs + a triangle, pulsing on a 3× clock inside the rise |
| I | Iceshard | grow → gleam → shatter: three acts staggered inside one clamp index |
| J | Jelly | squash × stretch = 1 — conserve volume and the boing sells itself |
| K | Knockstars | the dizzy halo; the near half of the ellipse draws bigger — free depth |
| L | Leaves | tumble = rotation + a y-scale flip faking the flat side of a 2D leaf |
| M | Meteor | falls 60% of the strip, lands the rest — the impact frame is a hard cut |
| N | Notes | disc + stem + flag on offset rises; what chapter 7's sound looks like |
| O | Omen | an eye opens, stares, closes at 12 fps — slow one-shots read as omens |
| P | Pop | inflate with growing wobble (the tell), then droplets — anticipation, baked |
| Q | Quake | same seed each frame + growing step count = a crack that remembers itself |
| R | Rain | 75% of each clock falls, 25% splashes — one particle, two costumes |
| S | Snow | Rain at 10 fps and half the fall — tempo is weather |
| T | Tornado | five stacked ellipses lagging each other's sway — a funnel from phase alone |
| U | Uppercut | Trailslash turned vertical; re-bake to rotate, never rotate the blit |
| V | Venom | a puddle simmers at 11 fps on purpose — poison should feel too slow |
| W | Wisp | the key-H sibling waves from the web: bob + phase-lagged tail curls |
| X | Xstamp | an X slams down: oversized → squash → settle, dust ring on the land |
| Y | Yoyo | drop / sleep / snap / rest — four acts on one piecewise kl clock |
| Z | Zzz | Z glyphs climb a sleepy sine at 10 fps — the one effect that WANTS low fps |

## The genre laps (3 & 4) — skim, recognise, open, modify

Lap three: **A**·Axolotl (a 2nd sheet TRACKS the swimmer, synced to its turns) · **B**·Beam (start/loop/end, three segments in one strip) · C·Chargeup (Burst reversed = anticipation) · D·Dash (smear frames) · E·Explosion (two sheets as layers: add fire under over smoke) · F·Fireworks (three staggered children) · **G**·Glitch (per-frame `DUR[]` clocks) · H·Hologram (dropout dice + rolling band) · I·Itemget (`|cos|` width = a spinning gem) · J·Jackpot (reels stop on staggered clocks) · K·Kettle (scheduled whistle: a guest in frames 0–1 of 8) · L·Levelup (rising light column + chevrons) · M·Mist (three drift speeds = baked parallax) · N·Neon (a loop hiding its own intro) · O·Oldfilm (age = chaos re-rolled per frame) · P·Pixelate (resolution as an animation dial) · Q·Quicksand (a clip region eats the crate) · **R**·Runner (TWO clips in one atlas, switched at the edges) · S·Shield (flash + a ripple running the rim) · **T**·Tempo (one sheet at 6/12/24 fps side by side) · U·UFO (three clocks on one kl) · V·Vapor (a palette rotating one slot per lap) · **W**·Waddle (the ping-pong index) · X·Xylophone (an `order[]` array is a melody) · Y·Yarn (a paw that exists only in frames 11–13) · Z·Zoom (converging lines + scale = a lens).

Lap four: A·Anticipation (holds = repeated frames, "on threes") · B·Bounceball (the shadow sells the altitude) · C·Cauldron (a simmer with a schedule) · D·Doorway (width IS the swing angle) · E·Enchant (a sequence walking a line) · F·Frostcreep (a crack that remembers itself, grown into frost) · G·Gears (whole tooth-pitches per lap) · H·Heartbeat (a write-head + alpha-per-age trail) · I·Invaders (N=2 conquered Earth) · J·Jump (three identical apex frames = hang time) · K·Kaleido (draw a sixth, get a mandala) · L·Lantern (Embers in paper coats) · M·Mushroom (overshoot gone botanical) · N·Nebula (integer spin ratios 1/2/−1) · O·Odometer (sliding glyphs in clip windows — every score counter) · P·Portalhop (exit scale = 1 − entry scale) · Q·Quill (a reveal played as writing) · R·Retrowave (`horizon + p²` — the square is the depth) · S·Springcoil (`sin·e^−t`, four frames of damping) · **T**·Teleport (one sheet, two directions: reversed = arrive) · U·Umbrella (rain interrupted by geometry) · V·Victory (a finale is a chord of old parts) · W·Wormhole (`p^2.2` growth = flying into it) · X·Xray (the two-frame damage flash) · Y·Yolk (Drip with comedic casting) · Z·Zen (the folio closes at 8 fps, on purpose).

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

**Going deep in Godot:** [godot-flipbook-vfx.md](godot-flipbook-vfx.md) — the long-form conductor's manual for hanging effects *on and around* one playing flipbook (the four clocks: shader `TIME`, `AnimationPlayer`, `Tween`, `Timer`; signals as triggers) — live demo `scenes/flipbook_vfx.gd`, menu key **H**.

**Free sheets:** Kenney particle/explosion packs (CC0) · OpenGameArt VFX (check each license) · itch.io free VFX packs — all arrive as exactly this format.
