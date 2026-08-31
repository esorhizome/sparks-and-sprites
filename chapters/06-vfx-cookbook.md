# 06 · The VFX cookbook

*Fresh-start note: a **particle system** spawns many tiny images and moves them with simple rules; **additive blending** is the colour-mixing rule where overlaps get brighter ("made of light"); a **shader** is a per-pixel colour program; **noise** is smooth organic randomness; **alpha** is transparency; a **tween** animates a value over time. Each is re-mentioned in place.*

---

Each effect names its **mechanism** first — because once you know the mechanism, every engine's version is recognisably the same dish.

(Everything in this cookbook is drawn *live*, every frame. The other way to ship a VFX — draw it **once** into a transparent sprite sheet and replay the frames — is [chapter 15](15-transparent-flipbooks.md), with 26 baked examples in [the flipbook folio](https://esorhizome.github.io/sparks-and-sprites/flipbook.html).)

## Glow

Two different tricks share the name:

1. **Bloom** (post-processing): the whole screen's over-bright pixels leak light.
   - Godot: `WorldEnvironment` → Glow on, then give sprites colours above 1.0, e.g. `modulate = Color(2, 1.6, 1)`.
   - Unity (URP): Bloom on the Volume, materials with HDR emission. *Try it: crank one sprite's emission to 3 and watch it alone bloom.*
   - Unreal: bloom is on by default; push emissive past 1 in any material.
2. **Per-sprite glow**: an additive (brightness-adding) soft blob behind the sprite — or on the web, `filter: drop-shadow(0 0 12px gold)`; one line of CSS, honestly great.

▶ *See it:* [additive glow demo](https://esorhizome.github.io/sparks-and-sprites/glow-additive.html)

⚠️ **Web performance:** full-screen bloom is the first thing to disable if a browser build stutters on older phones. The additive-blob version costs nearly nothing.

## Flame

Pick your tier:

1. **Particle flame:** an emitter (particle spawner) pointing up; particles shrink + fade over ~0.7 s; colour ramp yellow→orange→transparent; additive blending; slight sideways noise wobble. Identical in Godot `GPUParticles2D`, Unity's particle system, Unreal Niagara, or ~30 lines of canvas JavaScript.
2. **Shader flame:** scroll noise (smooth randomness) upward through an orange gradient, sharpen with a threshold. Copy-paste versions on [godotshaders.com](https://godotshaders.com/) and (to study, not to lift — see chapter 08 on its non-commercial default license) [Shadertoy](https://www.shadertoy.com/).
3. **Sprite-sheet flame:** hand-animated frames from a free pack — often the most charming option, zero code beyond frame playback.

▶ *See it:* [flame demo](https://esorhizome.github.io/sparks-and-sprites/flame.html)
🎮 *Godot direct demo:* the **flame** scene in `demos/godot/` configures a particle system entirely from code, every property commented.

**Unity try-it:** create a Particle System; set Start Speed ~2 upward, Start Lifetime 0.7, Color over Lifetime yellow→orange→transparent, Size over Lifetime shrinking, and the material to an additive one. That's the entire recipe — now nudge each number and watch the fire change species.
**Unreal try-it:** Niagara → the "Fountain" template already contains every module named above; retune it (velocity up, short lifetime, colour curve, additive material) and you've *made* fire rather than copied it.

## Sparks

**Mechanism:** one burst of 20–60 tiny bright particles, random directions biased away from the impact, strong initial speed, gravity on, short lifetime, additive blending, colour fading white→orange.

```js
// the entire physics of a spark
x += vx * dt;  y += vy * dt;   // dt = seconds since last frame
vy += GRAVITY * dt;
life -= dt;                    // draw at alpha = life / maxLife
```

▶ *See it (that exact code, editable):* [sparks demo](https://esorhizome.github.io/sparks-and-sprites/sparks.html)
🎮 *Godot:* the **sparks** scene — click anywhere to burst.

## Waterdrops

- **Falling drops:** the sparks recipe, pointed downward, blue-white, 1–3 particles at a time; on "death," spawn a tiny 3-frame splash sprite where each lands.
- **Drips** (cave, tap): a single particle on a slow timer — scale up while attached, detach, fall. The *wait* between drips is the effect.
- **Ripples:** an expanding, fading ring — one sprite scaling up while its alpha (transparency) tweens down; two lines. Fancy water gets a screen-space distortion shader instead.
- **Drops on the lens:** a shader offsetting UVs (texture-reading coordinates) under drop-shaped noise — a beloved Shadertoy study genre, searchable as "rain on window."

▶ *See it:* [waterdrops demo](https://esorhizome.github.io/sparks-and-sprites/waterdrops.html) — fall, splash, and ripple, with the "a particle's death is an event" hand-off spelled out.

## Halo

A soft ring texture in additive blending, floating above the subject, with two tiny motions: slow rotation (or none) and a gentle scale "breath" (±3% on a 3-second sine wave). Alpha modulated by slow noise for shimmer. On the web: a CSS `radial-gradient` ring with `mix-blend-mode: screen` and a slow keyframed scale. Same recipe = auras, selection rings, save-point circles; only colour and speed change.

▶ *See it:* [halo demo](https://esorhizome.github.io/sparks-and-sprites/halo.html) — cover the halo with your thumb and watch the subject stop being holy.

## Shiny metal, chrome & liquid metal

**Mechanism:** metal barely has a colour of its own — it shows a bent picture of its **surroundings**. So the entire game is *value bands*: a dark–light–dark pattern of "reflected world" wrapped around the form, with **sharp transitions** (sharp = polished chrome; softened = brushed or satin metal), plus one or two very bright **glints** where the light source itself is reflected. A smooth grey gradient is the classic miss — it reads as plastic, because real reflections have edges (the horizon is an edge).

- **Pixel art:** choose a 4–5 step ramp (deep dark → near-white); lay the bands *across* the form following its curve — a cylinder reads dark-light-dark-light across its width, a sphere gets curved bands — and spend the brightest step only on 1–2 px glints. Gold and copper are the same value pattern with warm hues; only the most intense glint stays near-white.
- **Programmatic 2D:** fake a one-dimensional environment (sky band, bright strip, dark horizon line, ground band) and look it up per pixel by the surface normal — this is what 3D artists call a **matcap** (material capture). Ten lines in a shader or canvas loop.
- **Real 3D:** set metallic to 1 and roughness near 0 — then give it something to reflect (Godot: a sky or `ReflectionProbe`; Unity: Reflection Probes; Unreal: reflection captures; three.js/Babylon: an environment texture). A mirror in an empty world is black — "my metal looks black" almost always means "no environment."
- **The travelling glint (the traditional-animation trick):** don't re-render the object — keep the base still and animate a *separate* narrow bright band in additive blending sweeping along the surface: dim and narrow entering, peak mid-way, dim leaving, 3–5 frames or one tweened sweep. Fast glint = sword edge; slow broad sweep = polished armour. This layer-above-a-held-base idea is how hand-drawn animation has done metal for a century, and it's also the cheapest possible version in any engine.
- **Liquid metal / mercury:** wobble the *silhouette* (metaballs, or a few slow sine waves on the radius) while the reflection lookup stays crisp. The eye reads "liquid metal" precisely because the shape is soft while the reflections stay hard.

▶ *See it:* [chrome & liquid metal demo](https://esorhizome.github.io/sparks-and-sprites/metal-chrome.html) — the band world, the normal lookup, the travelling glint, and a `LIQUID` dial, all in one editable loop.

**Unity try-it:** a sphere + default URP lit material; Metallic 1, Smoothness 0.95, and a Reflection Probe in the room — then drag Smoothness down to 0.4 and watch chrome become brushed steel. That one slider is the whole polished↔satin axis.
**Unreal try-it:** Metallic 1, Roughness 0.05 on any material; then animate a thin additive highlight band across a weapon icon in UMG — the travelling-glint recipe, node form.

## Trails & afterimages

- **Ribbon trail:** record the last N positions; draw a strip through them that fades with age. Godot: `Line2D` fed points each frame. Unity: the `TrailRenderer` component — zero code; *try it: add it to anything that moves and adjust Time + Width curve.* Unreal: Niagara ribbon emitter.
- **Afterimages:** every few frames, spawn a frozen, fading copy of the sprite. Fast fade reads as speed; slow desaturated fade reads as haunting.
- **Fragmented trail:** instead of one continuous ribbon, the moving thing *sheds individual particles* that each live a tiny life — and the fragment can be anything: fire, glowing orbs, waterdrops, stars, sparkles. Same emitter, different costume, different spell. (Unity's *Rate over Distance* emission and Niagara's spawn-per-unit are this idea as a checkbox: fragments appear only while moving.)
- **Canvas one-liner:** don't clear the canvas each frame — paint a translucent background rectangle instead. Everything that moves smears automatically.

▶ *See it:* [trails demo](https://esorhizome.github.io/sparks-and-sprites/trails.html) (the smear family) · [fragmented trails demo](https://esorhizome.github.io/sparks-and-sprites/trails-fragments.html) (the particle family — steer the comet with your pointer, then change what a fragment *is*)

## Shockwave / ripple

- **Sprite tier:** an expanding ring that scales 0→3× while fading over ~0.4 s (a tween — works everywhere, DOM included). 90% of the drama, 5% of the effort.
- **Distortion tier:** a shader that pushes screen UVs radially outward along the ring, bending the world itself. Save it for moments that truly deserve it.

## Screen shake (the kind version)

Keep a **trauma** value 0–1 that decays each frame; camera offset = `noise(time) * trauma²`. Noise (smooth randomness, not random jumps) keeps it smooth; the square makes small hits whisper and big hits roar; decay ends it quickly. Events *add* trauma; they never set it.

▶ *See it:* [screen shake demo](https://esorhizome.github.io/sparks-and-sprites/shake.html)

💚 **Accessibility:** low amplitude, short duration, a "reduce shake" toggle, and low-frequency wobble over high-frequency jitter — fast jitter is genuinely hard on many players. Calm defaults cost nothing.

## Ambient atmosphere (fireflies, motes, snow, petals)

A continuous, low-rate particle emitter (2–8 per second), long lifetimes, tiny sizes, slow noise-driven drift, gentle alpha pulsing. The difference between fireflies, dust, snow, and petals is one texture and one gravity number. Highest perceived-polish-per-effort on this page.

▶ *See it:* [starfield/ambience demo](https://esorhizome.github.io/sparks-and-sprites/starfield.html)

## The cube codex — every recipe, worn by a character

Everything on this page becomes twice as legible when it's attached to somebody. The **[cube codex](https://esorhizome.github.io/sparks-and-sprites/cube-vfx.html)** is 104 of this chapter's recipes worn by one protagonist — a cube with eyes, pacing a little fighting-game stage: firebursts and waterhoses, bolts called from the sky, a halo that follows a beat behind, dash afterimages, hit sparks, capes, butterflies. Fourteen families (decorations, neutral energy, fighting elements), each effect an idle loop plus a press reaction, ~25–40 editable lines. All 104 are also ported to GDScript in the repo's Godot project ([`demos/godot/scenes/cubefx/`](../demos/godot/scenes/cubefx/), one file per family, paged in the `cube_vfx` scene), with Unity 2D + 3D scripts (`CubeVfx2D.cs`, `CubeVfx3D.cs`) and an Unreal actor + recipe map (`SSCubeVfx`, `recipes/cube-vfx.md`) in the engine folders.

▶ *See it:* [the cube codex](https://esorhizome.github.io/sparks-and-sprites/cube-vfx.html) — press *Run all*, or wake one card at a time.

## Effekseer — author once, use in three engines

[Effekseer](https://effekseer.github.io/en/) is a free, open-source (MIT) visual-effects editor with official runtime plugins for Godot, Unity, and Unreal. Design a flame or slash once, export, play it in any of them — and its sample library is excellent dissection material.

---

*Notice the pattern: every effect was "spawn small things with simple rules" or "bend colour/UVs with a tiny shader." There is no third secret category. That's the whole field.*
