# Cheatsheet · Stagecraft (scene-level effects)

Everything = **draw the scene, then decide which pixels, which layer, which event, or which voice gets changed — by how much, on what clock.** Prose home: [chapter 06](../chapters/06-vfx-cookbook.md)'s section *The stagecraft almanac*, with tie-ins in [03](../chapters/03-combining-vfx-with-sprites.md), [07](../chapters/07-sound-effects.md), [12](../chapters/12-cursors-and-living-buttons.md) and [16](../chapters/16-depth-without-a-third-dimension.md). Live demos: [the stagecraft almanac](https://esorhizome.github.io/sparks-and-sprites/stagecraft.html) (104 effects A–Z ×4, each with a rhyme = 208, all editable). Godot: [`../demos/godot/scenes/stage/`](../demos/godot/scenes/stage/) (menu key **L**; right-click = rhyme) + [`../demos/godot/shaders/stage/`](../demos/godot/shaders/stage/).

Every card is a **living loop** plus a **press reaction**; its numbers sit in a `D = { … }` block at the top, and the **rhyme** is that block with two or three dials moved. Two cards flash the whole frame — **Z·Zap** (lightning) and **M·Muzzle** (gunfire) — and are **opt-in**: a static notice until you click.

## The eight families, 13 cards each — mechanism in one breath

**Screen & post-process** (a *shader* = a program run once per pixel; here it is a plain loop over the frame's bytes)
I·Iris — capture the frame, grow a mask over it (iris / pixel dissolve / checkerboard / curtain / slide / swirl) · H·Hurt — red edges whose alpha follows health, pulsing faster as health falls · C·Crt — sample from `uv + uv·|uv|²·curve`, darken odd rows, an RGB stripe mask · O·Ordered — a 4×4 Bayer threshold per pixel turns brightness into on/off (the Game Boy look) · Q·Quantise — snap every pixel to the nearest of N palette colours · C·Cycle — indexed colours; shift the palette each frame and the still image flows · X·Xsplit — read R, G, B from offsets that grow toward the edges · R·Refract — push sample coordinates by a distortion field (heat noise, an expanding ring, water) · Z·Zoomblur — average N samples along the line to a centre · G·Godrays — keep the bright pixels, smear them radially from the sun, add back · K·Kelvin — per-channel curves: contrast, saturation, warmth; posterise = fewer levels · Y·Yesteryear — per-frame noise + wandering scratches + ±1 px gate weave + exposure flicker · M·Mosh — rows of the previous frame displaced, a rolling tracking bar, a chroma offset, a frame hold

**Sprite & material shaders** (the hero's own skin)
F·Frozen — a gradient map (brightness → a 4-stop palette) + an overlay + a sweep from the feet up; `state` = frozen / petrified / gilded / ghost · F·Flicker — one tint per status, its alpha riding its own wave; statuses stack · J·Jelly — the sprite in horizontal strips, each shifted by `sin(y·k + t·w)·amp` · S·Sway — shear proportional to height above the base, driven by `noise(t + x)` · G·Grass — every blade a chain of angle springs: the root bends away from the nearest body and springs back, each joint above chases the one below under-damped, so the tip lags and whips through (Godot: `joints`, `tip`, `tipdamp`) · X·Xray — hero, then wall, then hero ∩ wall as a flat fill or a dilated outline (`source-in` on the wall's mask) · W·Wetfloor — the sprite flipped under the ground line, faded by a gradient mask, wobbled by a sine · S·Skewshadow — the sprite redrawn sheared and squashed toward the ground, darkened; the sun's angle is the shear · P·Pixelperfect — integer scale + whole-pixel pivot stays crisp; fractional melts; rotate in steps · N·Nineslice — nine regions: corners fixed, edges stretch one way, centre both · O·Outline — lighting quantised into bands + a larger darker copy drawn behind · U·Undersea — what's behind the water shifted by scrolling noise strips; caustics = two noise fields multiplied, thresholded · H·Hologram — scanlines + a bright rim + flicker + a hue shift on a see-through sprite

**Lighting & visibility**
V·Visibility — a ray to every wall corner (±ε), sort by angle, fill the fan · F·Fogofwar — a grid of unseen / seen / visible under a dark layer with soft holes; seen stays dim · T·Torch — a feathered wedge erased from a darkness layer; hand jitter; a battery that dims it · U·Umbra — a flickering point light *plus* its visibility polygon; shadows breathe · N·Night — a multiply layer tinted blue with additive holes for lamps; drag = time of day · Z·Zap — a white layer whose alpha decays exponentially, a jagged bolt, thunder N seconds later (**opt-in**) · S·Stealth — a meter that fills inside a guard's view cone, faster when closer, drains outside · V·Volumetric — translucent quads from every gap, angled by the sun, dust inside · D·Dusk — windows switch on on staggered timers as the sky darkens; headlights on the far road · B·Blobshadow — a ground raycast under the hero; the blob tilts to the surface and shrinks with height · B·Bloom — emitters to their own layer, blurred by a few offset draws, added back; only *they* glow · I·Interior — each room's light wakes with a tween when entered · Z·Zonelight — a tint per zone (safe / danger); the hero's tint follows

**Weapons, impacts & decals**
M·Muzzle — one `fire()` event: a two-frame flash + a one-frame light + smoke + recoil (**opt-in**) · E·Eject — small bodies flung sideways that bounce with restitution and spin, and tink · T·Tracer — a fading line from muzzle to the ray's hit point, alive 2–3 frames · I·Impact — the hit normal + a material lookup → sparks (metal), dust (stone), chips (wood), a ring (water) · D·Decals — N stamps in a ring buffer under everything; the oldest fades as new ones arrive · M·Marks — stamps by distance moved, fading with age: footprints, tyre tracks · I·Ink — a blob on the far side of the hit normal, with drips that grow · R·Rubble — 4–8 fragments, spin, gravity, one bounce, fade · K·Kaboom — an explosion's radius lights its neighbours after a delay; dominoes as a timed queue · W·Wick — a spark travelling a Bézier fuse, trailing smoke; the timer you can see · G·Grenade — fuse on pull, an arc preview while held, bounces, then the flash · A·Aoe — a circle / cone / line that fills over the windup, then the hit · T·Tell — the enemy flashes white and leans back 0.2 s before every attack

**Water, weather & nature**
W·Wavesprings — a row of springs pulled to rest and toward their neighbours; a kick becomes a travelling wave · J·Jetsam — bodies rise by how deep they sit and push the springs under them · W·Waterline — a foam line on a slow sine; a wet band behind it dries · P·Puddle — the flipped sprite clipped to an ellipse; rain rings on top · L·Lens — drops on the camera bead, merge, run when heavy; a wiper · Y·Yeti — each step deepens a height field; a path walked twice is darker · Q·Quiver — reeds on angle springs lean on wind noise and part around the walker · U·Updraft — regions with a force; a gust is an attack / sustain / release envelope · Y·Year — one clock drives leaf colour, the fall, the snow, the buds · U·Unfurl — a seed → sprout → bloom timeline beside an L-system fern grown from a rule string · K·Kindle — cells ignite neighbours with a wind-tilted probability, burn, leave ash · L·Lava — a flow down the slope; a crust that darkens with age; heat-haze strips above · C·Cloudshadow — a scrolling noise mask multiplied over the ground, clouds drawn from the same field

**Particle mechanics**
P·Pool — N particles made once and reused through a free list; allocations: 0 · D·Disintegrate — one particle per opaque pixel of the sprite; disintegrate / teleport / assemble · H·Hail — particles that bounce off the ground and tiles (restitution, friction) and pool in corners · S·Subemitter — a particle that emits particles; a death that spawns a burst · V·Vortex — a `forces` list per emitter: attractor, vortex, wind, turbulence · E·Emitters — emit from a point, line, ring, rect, arc, or along a path · Z·Zsort — sort by `z` each frame; soften where a puff meets the floor · V·Voronoi — cells by nearest seed, then fling the pieces · C·Cracks — a branching random walk from the impact, branches thinning · A·Arc — a ribbon between the blade's last N hilt and tip positions · K·Keyframes — a timeline as data `[{at, do}, …]` and one runner · L·Layers — world-space scrolls with the camera; screen-space does not · B·Budget — count actives; drop low-priority effects when over budget

**UI & HUD feedback**
H·Healthbar — the red bar snaps; a white ghost lags and drains over 0.5 s · R·Radial — a conic fill counting down on an icon; a pop when ready · O·Odometer — a score that tweens to its target with easing, digits rolling · X·Xpbar — fill, flash, level up, carry the remainder into the next bar · O·Offscreen — clamp the target to the view's edge and point an arrow at it · A·Anchor — project a world point to the screen each frame; the bubble's tail stays on the speaker · X·Xhair — a flash on hit; a spread that grows with fire rate and shrinks at rest · D·Damagearc — a red arc on the screen edge toward the attacker, fading · T·Toast — slide in, stack, slide out on timers · M·Minimap — a scaled world plus a sweeping wedge that reveals blips · G·Ghostplacement — a grid-snapped ghost, green or red by an overlap test · J·Jewel — a border sheen and a colour by rarity tier · B·Bossbar — segments that fill on the intro, shake on hit, break off per phase

**SFX & audio** (every card draws its mechanism and sounds *only after its first press*)
P·Positional — pan by x, gain by distance, pitch by relative speed (Doppler) · F·Footsteps — the surface under the foot picks the recipe; the foot-plant event fires it · N·Natter — a blip per typed letter, pitched by character; vowels sine, consonants square · E·Envelopes — recipes: explosion = noise → falling lowpass; jump = rising sweep; hurt = falling square; pickup = arpeggio · E·Engine — an oscillator whose pitch and volume follow speed · N·Noisebed — filtered noise with slow LFOs on cutoff and gain: wind, rain, surf, fire · Q·Quiet — the lowpass cutoff drops underwater, paused, or behind a wall · Y·Yodel — a feedback delay whose mix rises inside caves · J·Jukebox — layers fade in by intensity; transitions wait for the bar; stingers land on the beat · L·Lookahead — book notes slightly ahead on the audio clock, never on a frame timer · Q·Quota — cap instances per sound; steal the oldest or quietest · A·Analyser — the spectrum feeds bar heights, a glow, a camera pulse · R·Rumble — two motors (low / high) with intensity envelopes over time

## Wanted → card

| Wanted | Card(s) |
|---|---|
| the whole-frame CRT look | **Crt** (+ Yesteryear for grain, Kelvin for the grade) |
| a Game Boy / 1-bit palette | **Ordered** (dither), **Quantise** (palette snap) |
| a screen wipe / transition | **Iris** (`kind` dial: iris, dissolve, checker, curtain, slide, swirl) |
| a frozen / stoned / gilded enemy | **Frozen** (`state` dial) · status tints → **Flicker** |
| grass that parts as you walk | **Grass**, **Quiver** |
| 2D shadows from walls | **Visibility**, **Umbra** · a sprite's shadow → **Skewshadow**, **Blobshadow** |
| fog of war | **Fogofwar** · a flashlight → **Torch** · a stealth cone → **Stealth** |
| a muzzle flash / shells / tracers | **Muzzle** (opt-in), **Eject**, **Tracer** |
| footprints, tyre marks | **Marks**, **Yeti** |
| a splat, bullet holes, scorch | **Ink**, **Decals**, **Impact** |
| water you can splash | **Wavesprings** (+ **Jetsam** to float on it) · reflections → **Wetfloor**, **Puddle**, **Undersea** |
| rain on the camera | **Lens** |
| a sword trail | **Arc** (live ribbon) |
| an effect timeline | **Keyframes** |
| a health bar that shows the hit | **Healthbar** (ghost chunk) · low health → **Hurt**, **Damagearc** |
| a boss bar | **Bossbar** · cooldowns → **Radial** · XP → **Xpbar** |
| footsteps by surface | **Footsteps** |
| a lowpass underwater | **Quiet** · echo in caves → **Yodel** |
| adaptive music | **Jukebox** (+ **Lookahead** for the clock) |
| haptics | **Rumble** |
| lightning | **Zap** (opt-in) · day → night → **Night**, **Dusk** |
| particles that do not allocate | **Pool** · too many → **Budget** · a particle that emits → **Subemitter** |
| "my hit spark scrolls twice" | **Layers** (world- vs screen-space) |

## The load-bearing snippets

```js
// the pixel pass — a shader as a plain loop (Crt, Ordered, Quantise, Xsplit, Refract, Zoomblur, Godrays, Kelvin)
pix(D.scale, (px, w, h) => {                 // px = RGBA bytes of the frame, shrunk to `scale`
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const i = (y * w + x) * 4;               // this pixel's red byte; +1 green, +2 blue, +3 alpha
    px[i] = …; px[i + 1] = …; px[i + 2] = …; // decide the colour from position, neighbours, time
  }
});                                          // the kit stretches the small buffer back over the canvas

// 4×4 Bayer matrix (Ordered): on = brightness > B[y & 3][x & 3] / 16
const B = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]];

// the visibility polygon (Visibility, Umbra) — the steps
// 1. for every wall corner: three rays, at angle − ε, angle, angle + ε   (the ±ε rays slip past the corner)
// 2. for each ray: intersect every wall segment, keep the NEAREST hit
// 3. sort the hits by angle;  4. fill the fan from the light through them in order — that is the lit region

// the decal ring buffer (Decals, Marks): N slots, the oldest overwritten
buf[head] = { x, y, angle, born: t };  head = (head + 1) % N;   // age = t − born → alpha

// the ghost-health lag (Healthbar): red snaps, white waits, then drains
hp = target;
if (t - hitAt > D.hold) ghost = Math.max(hp, ghost - D.drain * dt);

// the WebAudio lookahead scheduler (Lookahead, Jukebox): book everything due in the next window, every frame
while (nextBeat < ac.currentTime + D.window) {       // window ≈ 0.1 s; frame jitter no longer matters
  tone(freq, nextBeat);  nextBeat += 60 / D.bpm;      // the note starts on the AUDIO clock, not on this frame
}
```

## The four accents, per family

| Family | Web (canvas) | Godot 4 | Unity 6 (URP) | Unreal 5 |
|---|---|---|---|---|
| Screen | `pix()`: `getImageData` → loop → `putImageData` at 0.25–0.5 scale | `BackBufferCopy` + a `canvas_item` shader with `uniform sampler2D screen : hint_screen_texture`; `shaders/stage/*.gdshader` | Volume overrides (Bloom, Chromatic Aberration, Film Grain, Lens Distortion, Color Adjustments) for the built-ins; a *Full Screen Pass Renderer Feature* + Fullscreen Shader Graph for the rest | `PostProcessVolume` settings for the built-ins; a material with *Material Domain = Post Process* for the rest |
| Skin | strips / `source-atop` / a second flipped `drawImage` | a `canvas_item` shader on the `Sprite2D` (`modulate` for tints); `NinePatchRect` | Shader Graph *Sprite Lit / Unlit*; `SpriteRenderer.color`; *Sliced* draw mode; *Pixel Perfect Camera* | material domain *Surface* on a Paper2D sprite or a UMG *Image*; a *Material Parameter Collection* for states |
| Light | a multiply darkness layer, `destination-out` holes, `visPoly()` | `CanvasModulate` (the night), `PointLight2D` + `LightOccluder2D` with shadows on, `Light2D` blend modes | 2D Light (*Point / Freeform / Global*) + *Shadow Caster 2D*; light blend styles | no 2D light system: multiply / additive quads as materials, or real 3D lights on flat sprites |
| Impact | one-shot particle bursts; a ring buffer of stamps | one-shot `GPUParticles2D`, `RayCast2D` for the tracer, `Sprite2D` stamps; a material lookup dictionary | Particle System *Bursts*, `Physics2D.Raycast`, `PhysicsMaterial2D` bounciness | Niagara bursts, `LineTraceSingleByChannel`, *Physical Material → Surface Type* lookup, `DecalComponent` (3D) |
| Weather | springs in an array, noise masks, height fields | `FastNoiseLite` for masks; a `Line2D` surface over a spring array; `GPUParticles2D` collision | `Mathf.PerlinNoise`; `LineRenderer` for the surface; Particle *Collision* module | the material *Noise* node; Niagara *Grid2D* / simulation stages for surfaces |
| Particles | pool arrays, `sort()` by z, a `forces` list | `GPUParticles2D` `sub_emitter`, `ParticleProcessMaterial` turbulence + collision (the 2D SDF from `LightOccluder2D`s), `z_index` from z | *Sub Emitters*, *Force Field*, *Shape* module, *Soft Particles*, `emission.rateOverDistance` | Niagara *Events & Event Handlers*, sub-emitters, *Vortex / Point Attraction / Curl Noise* forces, *Shape Location*, *Depth Fade* |
| HUD | `Tween`-style lerps; project world → screen with the camera offset | `TextureProgressBar` (radial fill modes), `Tween`, `get_global_transform_with_canvas()` for anchors | UGUI `Image.fillAmount` (Radial 360) or UI Toolkit; `Camera.WorldToScreenPoint` | UMG `ProgressBar` percent + a radial material; *Project World to Screen*; Widget Animations |
| Audio | `StereoPannerNode`, `BiquadFilterNode` (lowpass), `DelayNode` + feedback gain, `AnalyserNode`, `ac.currentTime` scheduling, `navigator.vibrate`, `gamepad.vibrationActuator` | `AudioStreamPlayer2D` (pan + attenuation), `AudioEffectLowPassFilter` / `Reverb` / `Delay` on `AudioServer` buses, `max_polyphony`, `AudioStreamInteractive` / `AudioStreamSynchronized` for layers, `Input.start_joy_vibration`, `Input.vibrate_handheld` | `AudioSource.spatialBlend` / `dopplerLevel`, `AudioLowPassFilter`, `AudioReverbZone`, `AudioMixer` snapshots (`TransitionTo`), `PlayScheduled(AudioSettings.dspTime + …)`, `Gamepad.SetMotorSpeeds(low, high)` | *Sound Attenuation* (spatial + LPF by distance), *Submix* effects (reverb), *Sound Class* modifiers, MetaSounds + the *Quartz* clock for sample-accurate music, *Sound Concurrency* (max count + steal rule), *Force Feedback Effect* assets |

## What goes wrong

run the pixel pass at full size (10× the cost — use `scale` 0.25–0.5) · a Bayer matrix compared against unnormalised bytes (divide by 16, compare against 0–1 brightness) · rays cast only *at* corners (the ±ε rays are what let light slip past) · decals that never expire (the ring buffer *is* the memory cap) · a health bar with no ghost (the hit becomes invisible) · music on `setTimeout` (drifts and stutters — schedule on the audio clock) · sound before the first click (blocked on the web by design) · a lightning card in *Run all* (flashing light is opt-in; keep the notice static).
