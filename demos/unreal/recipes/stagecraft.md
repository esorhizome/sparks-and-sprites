# The stagecraft almanac — scene-level effects, family by family (2D and 3D)

The almanac (docs/stagecraft.html) is 104 things that happen to the
**screen**, the sprite's **skin**, the **light**, the **impacts**, the
**weather**, the particle **machinery**, the **HUD** and the **sound** —
not to the character. Unreal has a named home for almost every family
(Post Process, materials, lights, Niagara, decals, Water, UMG, MetaSounds
+ Quartz), so this recipe is a map: for each family, the tool, the exact
nodes and values, and where the 2D twin lives. Rhymes are dial changes on
the web page; here they are parameter changes on the same asset.

Two cards flash the screen — **Zap** (lightning) and **Muzzle** (a
one-frame light) — and carry a `warnOf` flashing-light notice on the web
page, as the depth atlas's Xenon does. Keep the notice in your build too:
gate the white frame behind a setting, and never fire it on load.

## Screen — Post Process materials

A **Post Process Volume** (*Infinite Extent (Unbound)* on) → *Rendering
Features* → **Post Process Materials** array. The material: *Material
Domain* = **Post Process**, *Blendable Location* = **After Tonemapping**
(5.4 names it *Scene Color After Tonemapping*; use *Before Tonemapping*
for anything that should feed the tonemapper). Read the frame with
**SceneTexture: PostProcessInput0** (its *UVs* pin is where every
distortion goes), the pixel with **ScreenPosition** (0–1 *ViewportUV*),
the size with **ViewSize** / **SceneTexelSize**.

| Card | Material / setting |
|---|---|
| Iris | a PP material: `Lerp(scene, black, Step(mask, Progress))` where `mask` = distance from centre (iris), a 4×4 Bayer sample (pixel dissolve), `Frac(uv × 8)` checks (checkerboard), `uv.x` (curtain), `VectorToRadialValue` angle + radius (swirl); *Progress* driven from a **Material Parameter Collection** (MPC) via *Set Scalar Parameter Value*. The captured frame: a **Scene Capture Component 2D** to a *Render Target* the frame before |
| Hurt | PP: `Lerp(scene, red, vignette × pulse × (1 − health))`, vignette = `saturate(length(uv − 0.5) × 2 − 0.6)`, pulse = `0.5 + 0.5·Sin(Time × rate)`; `Health` and `Rate` from the MPC. Built-in vignette lives at PP Volume → *Lens* → *Image Effects* → **Vignette Intensity** |
| Crt | `c = uv − 0.5; uv' = uv + c·dot(c, c)·Curve` into the SceneTexture UV pin (0.12); scanlines `1 − Scan × Step(0.5, Frac(ScreenPosition.y × ViewSize.y / 2))` (0.35); mask `Mask × Fmod(floor(px.x), 3)` per channel (0.18); vignette as above |
| Ordered | no Bayer node (**DitherTemporalAA** is a *temporal* dither): a 4×4 (or 8×8) threshold texture, *Filter* Nearest, *sRGB* off, *Mip Gen* NoMipmaps, sampled at `ScreenPosition × ViewSize / 4` with *Wrap*; `Step(threshold, luminance)`; `levels` = quantise first, dither the remainder |
| Quantise | a **Custom** HLSL node looping over a palette array (nearest RGB), or the honest engine route: a **Color Grading LUT** (PP Volume → *Color Grading* → *Misc* → *Color Grading LUT*, a 256×16 neutral LUT PNG re-painted to the palette, texture group *ColorLookupTable*) — palette snapping in zero shader code |
| Cycle | the scene material stores an *index* (a greyscale texture), the palette is a 1×N texture sampled at `Frac(index + Time × Speed)` with *Filter* Nearest — Mark Ferrari's trick is one **Time** node |
| Xsplit | built in: PP Volume → *Lens* → **Chromatic Aberration** → *Intensity*, *Start Offset* (0 = grows from centre, the card's default). Hand version: three SceneTexture reads at `uv ± (uv − 0.5) × Split × {1, 0, −1}` |
| Refract | in the world, not post: a translucent material's **Refraction** input (*Refraction Method* = Pixel Normal Offset) on a quad above the fire, driven by a panned noise normal — heat haze. Shockwave: PP material `uv + normalize(uv − Centre) × Ring(dist − Radius)` with *Centre*/*Radius* in the MPC, Radius on a Timeline |
| Zoomblur | Custom node: `for i in 0..N: c += SceneTextureLookup(uv + (Centre − uv) × i/N × Strength)` ÷ N (N 8–16). *Zoomimpact*: Strength on an exponential decay after a hit |
| Godrays | built in on the **Directional Light** → *Light Shafts*: **Light Shaft Occlusion** (the dark rays) and **Light Shaft Bloom** (*Bloom Scale*, *Bloom Threshold*, *Bloom Tint*) — threshold → radial smear → add, as the card says |
| Kelvin | PP Volume → *Color Grading*: **Temperature** (the literal Kelvin dial, 6500 neutral), *Tint*, *Saturation*, *Contrast*, *Gamma*, *Gain*, *Offset* — each for Global / Shadows / Midtones / Highlights; *Film* → *Slope / Toe / Shoulder*. Posterise: PP material `Floor(scene × Levels) / Levels` |
| Yesteryear | built in (5.0+): PP Volume → *Film Grain* → **Film Grain Intensity**, *Texel Size*, *Film Grain Texture*; gate weave = SceneTexture UV `+ (Rand(Time) − 0.5) × SceneTexelSize`; scratches = a panned thin-line texture multiplied in; exposure flicker = *Gain* from the MPC |
| Mosh | PP materials cannot read the previous frame. Either **SceneTexture: Velocity** to displace blocks (a datamosh *look*), or a Scene Capture 2D writing to a Render Target you sample next frame (ping-pong two RTs) for real frame-hold; tracking bars = `Step(Frac(uv.y − Time × 0.2), 0.05)` shifting `uv.x`; bleed = the Xsplit trick on Y only |

**The 2D equivalent.** Post Process applies to the whole viewport, so a
Paper2D or ortho scene gets all of the above unchanged. For UMG-only
content (a menu, a HUD-drawn minigame, a pixel-art layer that must not
touch the world) the home is the **Retainer Box** widget: it renders its
children to a texture and runs an *Effect Material* (*Material Domain* =
User Interface; the texture parameter is named `Texture` by default,
*Texture Parameter* on the box) — the whole table above works in it, with
*TexCoord* in place of ScreenPosition. Pixel-art scale: *Screen
Percentage* on the PP Volume (or `r.ScreenPercentage 50`) with
`r.Upscale.Quality 0` for a nearest upscale.

## Skin — sprite and surface materials

Paper2D sprites use the engine's sprite materials (`MaskedUnlitSpriteMaterial`,
`TranslucentUnlitSpriteMaterial`, `MaskedLitSpriteMaterial`, …); duplicate
one. Read the sprite with **SpriteTextureSampler** (Paper2D's node — it
binds the sprite's own texture) and the sprite's *Sprite Color* with
**VertexColor**. Per-instance dials go through a **Dynamic Material
Instance** (`Create Dynamic Material Instance` → *Set Scalar / Vector
Parameter Value*).

| Card | Material |
|---|---|
| Frozen | gradient map: `Desaturation(rgb)` → sample a 256×1 ramp (*Clamp*, Nearest) → `Lerp(rgb, ramped, State)`; overlay = a tiled pattern multiplied; sweep = `Step(TexCoord.V, 1 − Progress)` (V grows downward in Paper2D UVs, so the freeze climbs from the feet) — one material, four ramp textures, `state` picks the ramp |
| Flicker | `Lerp(rgb, Tint, TintAlpha × wave)`: poison `0.5 + 0.5·Sin(Time × 2)`, burning `Sin(Time × 12)` + a Niagara ember emitter attached, stunned `Step(0.5, Frac(Time × 10))` (a hard blink); statuses stack as additive emissive terms |
| Jelly | pixel-space, not vertex: `uv + float2(Sin(uv.y × K + Time × W) × Amp, 0)` into the SpriteTextureSampler — a sprite is a 4-vertex quad, so **WorldPositionOffset** would only move corners. If you want true vertex wobble set the sprite's *Render Geometry* to *Diced* (more quads) and use WPO |
| Sway | WPO ∝ height: the engine function **SimpleGrassWind** (*Wind Intensity*, *Wind Weight*, *Wind Speed*) already multiplies by a height mask; or by hand `float3((WorldPosition.Z − PivotZ) × Noise(Time + WorldPosition.X) × Amp, 0, 0)`. Vertices needed → Diced sprite or a subdivided plane |
| Grass | WPO bend away from the hero: MPC `HeroPos` → `dir = normalize(WorldPosition − HeroPos)`, `bend = saturate(1 − dist / R) × heightMask` → `WPO = dir × bend × Amp`. A material cannot spring back (no state): the Blueprint writes a *lagged* position into the MPC (`FInterp To`) so the blades recover over time |
| Xray | **Custom Depth**: on the hero, *Rendering* → **Render CustomDepth Pass**, *CustomDepth Stencil Value* 1 (Project Settings → Rendering → *Custom Depth-Stencil Pass* = Enabled with Stencil); a PP material draws the silhouette colour where `SceneTexture:CustomDepth < SceneTexture:SceneDepth`; the outline variant edge-detects CustomDepth with ±SceneTexelSize taps |
| Wetfloor | a second flipbook component with *Relative Scale* Z = −1 under the floor line, translucent material: opacity `saturate((FloorZ − WorldPosition.Z) / FadeLen) × 0.4`, UV wobble `Sin(WorldPosition.Z × K + Time) × Wobble`. 3D: **Planar Reflection** actor (Project Settings → Rendering → *Support global clip plane for Planar Reflections*) or SSR on a *Roughness* 0 floor |
| Skewshadow | a third copy, tinted black at 0.5 alpha, WPO `X += (WorldPosition.Z − BaseZ) × tan(SunAngle)` and *Relative Scale* Z 0.4 — needs Diced geometry, or shear the *component* by rotating it in the sprite plane and scaling. 3D: a real **Directional Light** — masked sprite materials cast alpha-tested shadows already |
| Pixelperfect | texture: *Apply Paper2D Texture Settings* (Nearest, NoMipmaps, UserInterface2D compression); sprite *Pixels per unit* consistent; ortho camera *Ortho Width* = screen width / zoom; round actor locations to whole units; the rotate-in-steps copy = `Round(yaw / (360 / Steps)) × (360 / Steps)` |
| Nineslice | built in for UMG: any **Image** / **Border** brush → *Draw As* = **Box**, *Margin* (0.25 each) — corners stay crisp. Paper2D sprites have no 9-slice: nine sprites, or a **Widget Component** (*Space* = World) showing the UMG panel in the scene |
| Outline | cel: `Floor(saturate(dot(N, L)) × Bands) / Bands` in an Unlit material (`L` a Vector Parameter) or, for lit scenes, a *Before Tonemapping* PP material quantising `SceneTexture:DiffuseColor × lighting`. Outline: Unreal has no front-face cull, so the inverted hull needs a flipped-normal mesh copy; the standard is the PP **CustomDepth** edge (as Xray). Sprite outline: `max` of the alpha at `TexCoord ± 1 / TextureSize` in four taps, minus the alpha |
| Undersea | 3D: a translucent water plane with **Refraction** (Pixel Normal Offset) from two panned normal maps, and caustics as a **Light Function** material (two panned caustic textures multiplied, thresholded) on the light above the floor. 2D: the same UV distortion applied to a Scene Capture of the floor, caustics as an additive panned texture |
| Hologram | Translucent + Additive: scanlines `0.7 + 0.3·Step(0.5, Frac(WorldPosition.Z × Freq + Time × 2))`, rim = **Fresnel** (*Exponent* 3) in 3D / the alpha-edge tap trick on a sprite, flicker `0.85 + 0.15·Noise(Time × 30)`, a `Hue` shift via **HueShift** function; *Opacity* 0.5 |

## Light — Paper2D has none, and the two fixes

**Paper2D ships no 2D light.** Sprites *are* lit if their material is Lit
(`MaskedLitSpriteMaterial`, normal facing the camera), so the first fix is
**a real 3D light in front of the sprite plane**: a **Point Light** at a
small negative Y, *Attenuation Radius* 400, *Source Radius* 20 for soft
edges, *Cast Shadows* on — walls extruded in Y cast real shadows across the
sprites, which is Umbra and Visibility for free. The second fix, for
overlays that must ignore geometry, is the **darkness quad + additive
holes**: a full-screen translucent black plane (or UMG Image) whose
opacity is `Dark × (1 − RT)`, where `RT` is a **Canvas Render Target 2D**
you paint each frame — *Clear Render Target 2D*, *Begin Draw Canvas to
Render Target*, *Draw Texture* (a soft radial, *Blend Mode* Additive) per
lamp, *End Draw Canvas to Render Target*. That texture is also fog of war.

| Card | Unreal spelling |
|---|---|
| Visibility | 3D: a **Point Light** with *Cast Shadows* — the fan is what shadowing computes. 2D overlay: cast N **Line Trace By Channel** to every wall corner ±0.001 rad, sort by angle, draw the fan into the RT with *Draw Material* (a triangle-fan material) — or feed a **Procedural Mesh Component** the fan as a translucent additive mesh |
| Fogofwar | a low-res RT (one texel per tile) with R = seen, G = visible now; each tick draw a soft disc for G, `max` it into R (a second RT); the ground overlay samples it: `Lerp(black, Lerp(dim, clear, G), R)`; *Filter* Bilinear gives the soft holes; *Foglift* = decay R by `dt / memory` each frame |
| Torch | **Spot Light**: *Inner Cone Angle* 15, *Outer Cone Angle* 30 (the soft edge), *Attenuation Radius*, *Intensity*, an **IES Light Profile** for a real torch shape; jitter = a Timeline on relative rotation ±1.5°; batteries = *Intensity* × charge |
| Umbra | Point Light, *Cast Shadows*, *Source Radius* 15 (soft penumbra), flicker via a **Light Function** material (`0.8 + 0.2·Noise(Time × 8)`) or *Set Intensity* per tick; warm *Light Color* `#FFB070`, *Temperature* 2400 (*Use Temperature*) |
| Night | 3D: a PP Volume whose *Blend Weight* is the time of day (Color Grading *Temperature* 12000, *Gain* 0.25, a blue *Tint*) + the **Sky Light** / **Directional Light** rotation. 2D: the darkness quad tinted `#0A1030`, lamps as additive holes (`cutLight`) |
| Zap | flash = *Gain* on a second PP Volume with *Blend Weight* decaying `exp(−t × 8)` (or the MPC `Flash` into a PP material); bolt = a **Niagara Beam** emitter (the *Beam* template: *Beam Start/End*, *Beam Width*, a *Jitter Position* module for the jag); thunder = `Delay(distance / 340)` → *Play Sound 2D*. **Flashing content — keep the notice** |
| Stealth | built in: **AI Perception Component** with *Senses Config* → **AISense_Sight** (*Sight Radius* 1500, *Lose Sight Radius* 2000, *Peripheral Vision Half Angle* 45) → *On Target Perception Updated*, or the older **Pawn Sensing Component** (*Sight Radius*, *Peripheral Vision Angle*, *On See Pawn*). The meter (fill faster when nearer, drain outside) is yours: `Δ = seen ? (1 − dist / R) × FillRate : −DrainRate` per tick; the cone drawn as a decal or a Niagara sprite |
| Volumetric | **Exponential Height Fog** → **Volumetric Fog** on, then the light's *Volumetric Scattering Intensity* (2–8) — the shafts fall out of the window geometry. 2D: additive translucent quads angled by the sun with a Niagara dust emitter *Local Space* inside |
| Dusk | window material: `Emissive × Step(PerInstanceRandom, Dusk)` on an **Instanced Static Mesh** (or *Hierarchical ISM*) of windows — **PerInstanceRandom** staggers them; `Dusk` from the MPC, 0 → 1 over the evening; headlights = Niagara sprites on a spline |
| Blobshadow | a **Decal Component** under the hero with a radial blob — decals wrap slopes by themselves; scale `1 − 0.6·k`, *Decal* material opacity `0.55·(1 − 0.8·k)` with `k` = height / max from a **Line Trace** down. Paper2D: a blob sprite rotated to `ImpactNormal` and squashed by k |
| Bloom | PP Volume → *Bloom*: *Method* Standard, **Intensity** 0.7, **Threshold** 1.0 — only pixels above 1 bloom, so *selective* bloom is just emissive values: lamps at `colour × 5`, everything else ≤ 1. *Blaze* = Threshold −1 (everything). UMG has no bloom: bake it into the brush |
| Interior | one **Rect Light** (or Point) per room, *Intensity* 0 until a **Trigger Box** overlap starts a Timeline → *Set Intensity*; *Infrared* = the reverse Timeline on end overlap. 2D: room rects painted into the darkness RT |
| Zonelight | a bounded **Post Process Volume** per zone (*Unbound* off, **Blend Radius** 200 for the soft edge) with its own *Color Grading* tint — safe green, danger red — blended by the camera's position; the hero's tint = the zone's colour through the MPC; pulse = *Blend Weight* on a Sine |

## Impact — Niagara, decals, and the damage calls

| Card | Unreal spelling |
|---|---|
| Muzzle | one **Niagara System**, three emitters: flash (sprite, *Sub UV Animation* over a 2-frame sheet, *Lifetime* 0.06, *Local Space*), smoke (5 puffs, *Drag* 2), and a **Light Renderer** (*Radius Scale* 300, one frame) — that renderer is the ground-lighting light. Recoil = a Timeline on the barrel's relative location + a **Camera Shake** (*Legacy Camera Shake*: *Oscillation Duration* 0.1, *Rot Oscillation Pitch Amplitude* 1) via *Client Start Camera Shake*. The `fire()` event = an **Anim Notify** on the fire montage. **Flashing content** |
| Eject | a casing **Static Mesh** with *Simulate Physics*, **Physical Material** *Restitution* 0.4, impulse sideways + random *Angular Velocity*; or Niagara **Mesh Renderer** + **Collision** module (CPU: *Ray Traced*; GPU: *GPU Depth Buffer*) with *Restitution*/*Friction*, and the **Play Audio** module (CPU emitters) on the collision for the tink |
| Tracer | **Line Trace By Channel** → *Impact Point*; a Niagara **Ribbon Renderer** with two particles (muzzle, hit) and *Lifetime* 0.05, or a **Beam** emitter with *Beam End* set from the hit — the tracer fades by *Color* over life |
| Impact | the trace's *Return Physical Material* pin on → `Hit.PhysMaterial` → **Get Surface Type** → *Switch on EPhysicalSurface* (Project Settings → Physics → *Physical Surface* names: SurfaceType1 = Metal, 2 = Stone, 3 = Wood, 4 = Water) → *Spawn System at Location* with the matching Niagara system, rotation = `Make Rot from Z(Impact Normal)` |
| Decals | **Spawn Decal at Location** (material, size, location, rotation, *Life Span*) returns a **Decal Component**; **Set Fade Out** (*Start Delay*, *Duration*, *Destroy Owner After Fade*) is the age fade; the ring buffer = a `TArray<UDecalComponent*>` of N — when full, `DestroyComponent` the oldest. *Fade Screen Size* culls small far decals. Project Settings → Rendering → **DBuffer Decals** on so they work on lit surfaces |
| Marks | stamp by distance: accumulate `|Δlocation|` per tick, stamp a decal every `Stride` (60 units) alternating left/right foot; tyres: one decal per `Stride` with the car's yaw; the age fade is Set Fade Out again. Paper2D: sprites instead of decals, `SortOrder` just above the ground |
| Ink | a decal with a splat atlas (*Sub UV* by a random index), placed at `ImpactPoint − ImpactNormal × 2` (the far side), rotation aligned so *V* points down; drips = a `Drip` scalar (age) growing a second mask via `Step(V, Drip)`; *Inkwell* = a black-on-paper material, *Drip* slow |
| Rubble | 4–8 chunk **Static Mesh Components** with *Simulate Physics* and *Set Life Span* 2 (the fade = a material *Opacity* from the MPC or a per-chunk DMI), or Niagara Mesh Renderer + Collision + *Mesh Rotation Rate*. The heavy real thing: **Chaos Destruction** — *Fracture Mode* → a **Geometry Collection** (Uniform / Voronoi / Clustered fracture) + an **Anchor Field** |
| Kaboom | **Apply Radial Damage** (*Base Damage*, *Origin*, *Damage Radius*, *Damage Type*) — every barrel implements **Event AnyDamage** → *Set Timer by Event* (0.4) → its own explosion + Apply Radial Damage; the chain is the engine's damage routing. Dominoes: a **Radial Force Component** *Fire Impulse* on physics-simulated planks |
| Wick | a **Spline Component** for the rope; the spark is a Niagara system whose location = **Get Location at Distance Along Spline** (`t × Spline Length`) each tick, with a smoke ribbon *Local Space* off; at the end, the Muzzle-style pop. Niagara-only: the **Spline** data interface (*Sample Spline Position by Unit Distance*) inside the emitter |
| Grenade | **Projectile Movement Component** (*Initial Speed*, *Should Bounce*, *Bounciness* 0.3, *Friction* 0.4, *Projectile Gravity Scale* 1); the arc preview = **Predict Projectile Path (Advanced)** (*Launch Velocity*, *Max Sim Time*, *Sim Frequency* 15) → *Out Path Positions* drawn with a **Spline Mesh** chain or a Niagara ribbon; the cook = a timer started on pull, fired wherever the grenade is |
| Aoe | a **Decal Component** with a radial / cone / line material whose `Fill` scalar (0 → 1 over the windup) masks the inner fill (`Step(dist, Fill)` for circles, `VectorToRadialValue` angle for cones, `uv.x` for lines); then *Apply Radial Damage* / a box overlap at 1.0. 2D: the same material on a ground sprite |
| Tell | *Set Vector Parameter Value on Materials* (`Flash` = white, 0.2 s) + an **Anim Montage** windup section (*Montage Jump to Section* "Windup") or, in Paper2D, *Set Flipbook* to a windup flipbook; the lean = *Set Relative Rotation* pitch −15° on a 0.2 s Timeline; the dodge window is the same 0.2 s compared against the player's input timestamp |

## Weather — the Water plugin vs a sine

| Card | Unreal spelling |
|---|---|
| Wavesprings | 2D: a Blueprint array of `height` / `velocity` per column, springs `v += (−k·h) − damp·v`, spread `h[i] ± spread·(h[i±1] − h[i])`, drawn with a **Procedural Mesh Component** (*Update Mesh Section* each frame, a triangle strip) or a Spline Mesh. 3D: the **Water** plugin — *Water Body Lake / River / Ocean / Custom* actors with a **Water Waves** asset (Gerstner, *Num Waves*, *Amplitude*, *Wavelength*) — splashes are Niagara on top, the surface itself does not react |
| Jetsam | Water plugin: a **Buoyancy Component** on the crate (*Pontoons* array: *Center Socket* / *Relative Location*, *Radius*; *Buoyancy Coefficient*, *Buoyancy Damp*) — bobbing from the real wave height. 2D: `y = surfaceHeight(x) − draft`, and push the spring under it by `−mass × push` — buoyancy both ways is two lines |
| Waterline | the foam line = `1 − saturate(DistanceToNearestSurface / FoamWidth)` (the **DistanceToNearestSurface** node reads the mesh distance field — Project Settings → *Generate Mesh Distance Fields*) plus a panned noise; the wet band = a decal/ground material `WetAge` scalar decaying. 2D: a sine-advancing line and a band whose alpha decays `exp(−age / dry)` |
| Puddle | a flat **Decal** or plane with *Roughness* 0.02, *Metallic* 0, *Specular* 1, reflections from SSR or a **Planar Reflection**; rain rings = the Niagara **Decal Renderer** (5.3+) spawning ring decals, or a ripple normal map with `Frac(Time)` scale. *Petrol* = a thin-film rainbow: `Fresnel` → a hue ramp added |
| Lens | PP material: a droplet normal texture (packed as RG) pushes the SceneTexture UVs `uv + normal.xy × 0.02 × DropMask`; drops slide by panning the mask V with a `Heavy` threshold; the wiper = `Step(uv.x, WiperX)` on the mask, WiperX on a Timeline. 2D: the same material in a **Retainer Box** |
| Yeti | a **Canvas Render Target 2D** over the snow area painted with *Draw Material* at each footfall (additive, so repeat steps deepen); the snow material samples it for WPO down (`−RT × Depth`) and a darker tint. Modern route: a **Runtime Virtual Texture** (*Runtime Virtual Texture Volume*, the **Virtual Texture Output** node in the writer material). *Yellowsand*: decay the RT toward 0 each frame with a low-alpha *Draw Texture* of black |
| Quiver | Grass's MPC bend + **SimpleGrassWind**; the rustle = *Play Sound at Location* on **On Component Begin Overlap** of a thin Box Collision around the reeds, one shot per 0.3 s |
| Updraft | a **Box Collision** zone; per tick for each overlapping character: CMC **Add Force** (or *Add Impulse* with *Velocity Change*) along the field × gust; for physics bodies a **Radial Force Component** (*Force Strength*, *Constant Force*) or *Add Force* per body; leaves = Niagara with the **Wind Force** module; the ADSR gust = a **Curve Float** asset read with *Get Float Value*. *Wind Directional Source* only drives cloth, SpeedTree and Niagara — not characters |
| Year | one MPC scalar `Season` 0–4 read everywhere: leaf tint = a 4-stop ramp sampled by `Frac(Season / 4)`, leaf alpha `Step(Season, 2.5)`, snow = `saturate(VertexNormalWS.Z × 4 − 3) × saturate(Season − 2)` on every ground material; falling leaves and snow = Niagara systems whose *Spawn Rate* is bound to a user parameter you set from the same clock |
| Unfurl | growth = a `Grow` scalar (0 → 1) in the plant material: WPO scales vertices toward the root by `saturate(Grow × 3 − TexCoord.V × 2)` and *Opacity Mask* by the same; the L-system fern = Blueprint building **Spline Components** + **Spline Mesh Components** per segment, segments added one per beat |
| Kindle | a `TArray<uint8>` (Blueprint: an array of *Byte* or an Enum) per tile — Grass / Burning / Ash; a *Set Timer by Event* 0.1 s step: burning tiles ignite neighbours with `p × (1 + WindBias × dot(dir, Wind))`, burn `N` steps, become ash. Fire = one Niagara system per burning tile spawned with **Pooling Method** = *Auto Release* (pooling is automatic). 2D: **Paper Tile Map Component** → *Set Tile* (X, Y, Layer, Tile) for the ash and grass tiles |
| Lava | a flow map: the **FlowMaps** material function (a flow texture + `Frac(Time)` two-phase sampling) on a crust texture whose brightness = `1 − age` from a red channel; heat haze = a Refraction quad above; embers = Niagara with *Gravity Force* negative; *Lavatube* = faster *Flow Speed*, thinner crust (a higher threshold) |
| Cloudshadow | **the** Unreal way: a **Light Function** material on the **Directional Light** (*Light Function Material*, *Light Function Scale* 2000) — a panned cloud noise texture, *Panner* speed = wind; the clouds above are the same texture on a sky plane, offset by the sun angle so they line up. 2D: a multiply plane over the ground with the same panned texture |

## Particle mechanics — Niagara

| Card | Niagara spelling |
|---|---|
| Pool | **automatic.** *Spawn System at Location / Attached* have a **Pooling Method** pin — *None*, **Auto Release** (component returns to the pool when the system finishes), *Manual Release* — and particle memory is preallocated per emitter (*Emitter Properties* → **Allocation Mode**: Estimated Automatic / Manual Estimate / Fixed, *Pre Allocation Count*). The "allocations: 0" counter is the `fx.NiagaraComponentPool` stats. *Puddlepool* = a fixed allocation of 8 |
| Disintegrate | spawn one particle per texel over a grid (*Spawn Particles in Grid*), sample the sprite with the **Texture Sample** data interface (*Sample Texture 2D* by the grid UV), **Kill Particles** where alpha < 0.5, colour from the sample; disintegrate = *Add Velocity* + *Drag*; assemble = **Point Attraction Force** toward each particle's home (store `HomePos` at spawn, or use a **Vector Field**); a skeletal source is *Skeletal Mesh Location* instead |
| Hail | the **Collision** module: CPU emitters *Ray Traced* (async traces against the scene) or *Analytical Planes*; GPU emitters *GPU Depth Buffer* / *GPU Distance Fields*; *Restitution* 0.3, *Friction* 0.5, *Kill Particles on Collision* for one-bounce rain; pooling in corners falls out of friction |
| Subemitter | CPU: **Generate Location Event** / **Generate Collision Event** / **Generate Death Event** in the parent, an **Event Handler** (*Receive Location Event*, *Spawn Number*) in the child — the smoke trail on a spark, the burst at its death. GPU emitters cannot send events: use the *Spawn Particles from Other Emitter* module (5.4+; search *Add Module*) or attribute readers. *Sparklers* = the child also generates events (two levels) |
| Vortex | force modules, one per chip: **Point Attraction Force** (*Attraction Strength*, *Radius*), **Vortex Force** (*Vortex Axis*, *Force Amount*), **Wind Force**, **Curl Noise Force** (the turbulence; *Noise Strength*, *Frequency*), **Drag**, **Gravity Force**, **Vector Field Force** (a *Vector Field* asset). *Vacuum* = Point Attraction only, strength 5000 |
| Emitters | the **Shape Location** module: *Shape Primitive* = Sphere / Cylinder / Box-Plane / Torus / Ring-Disc / Cone; a line is Box-Plane with two zero extents; an arc is Ring-Disc with a *Coverage* fraction; a path is the **Spline** data interface (*Sample Spline Position by Unit Distance* with a random 0–1). *Edgeglow* = Ring-Disc, *Ring Radius* 100, *Coverage* 0.5 |
| Zsort | **Sprite Renderer** → **Sort Mode**: *View Depth* (near covers far), *View Distance*, *Custom Ascending / Descending* (by an attribute you set), *None*; *Sort Only When Translucent*. Soft particles = the **DepthFade** node in the sprite material (*Fade Distance* 50) — alpha by distance to whatever is behind |
| Voronoi | 3D: **Chaos** — select the mesh → *Fracture Mode* → **Uniform Voronoi** (*Number of Sites*), *Clustered* or *Radial*; the result is a **Geometry Collection** that shatters on impact (a *Field System* / *Master Field* wakes it). 2D: a **Procedural Mesh** pane cut with **Slice Procedural Mesh** (*Plane Position*, *Plane Normal*, *Create Other Half*) along random lines — a few slices approximate the cells; fling the halves with physics |
| Cracks | a decal with a crack atlas plus a growth mask (`Step(dist from centre, Age × Speed)` reveals outward), or generative: a Blueprint random walk writing branch segments into a **Canvas Render Target 2D** (*Draw Line*, thinning *Thickness*) sampled by the ground/glass material; *Crazing* = *Branches* 12, *Decay* 0.9 |
| Arc | a **Ribbon Renderer** fed one particle per frame at the blade **tip** socket (*Skeletal Mesh Location* → *Sample Socket*), *Ribbon Width* = hilt-to-tip length, *Ribbon Facing Mode* = *Custom* with the facing vector pointing from tip to hilt — the ribbon's width becomes the blade; UV-V gradient for the fade; *Lifetime* 0.15. *Afterburn*: lifetime 0.6, a fire material, *Gravity Force* −200 |
| Keyframes | the **System Overview timeline**: each emitter's *Spawn Burst Instantaneous* has a **Spawn Time** (0, 0.05, 0.1, 0.2) and the timeline lets you drag them — the system *is* the data timeline and one *Spawn System* plays it. Cross-object sequences (a flash + a camera shake + a sound) go in a **Level Sequence** or a Blueprint *Timeline* with event tracks |
| Layers | per emitter: **Local Space** on/off (*Emitter Properties*). A hit spark: *Spawn System at Location*, Local Space off — it stays in the world as the camera pans; a HUD flash lives in UMG (a widget animation), never in the scene; *Spawn System Attached* with Local Space on for muzzle flashes riding the gun. UMG has no Niagara stock; the third-party *Niagara UI Renderer* plugin is the usual bridge |
| Budget | built in: a **Niagara Effect Type** asset assigned to each system (*Effect Type*): **Max Instances**, *Significance Handler* (Distance / Age), **Cull Reaction** (Kill / Kill and Clear / Deactivate / Deactivate Immediate), *Cull Max Distance*, per-platform *Scalability* (*Spawn Count Scale*, *Max System Instances*), *Budget Scaling*. The meter = `stat Niagara` / `fx.Niagara.Scalability`. *Bargain* = Max Instances 4, hero effects on a second Effect Type with no cull |

## HUD — UMG

| Card | UMG spelling |
|---|---|
| Healthbar | two **Progress Bar**s in an **Overlay**: the red one *Set Percent* immediately; the white *ghost* behind it `FInterp To(ghost, health, dt, 6)` after a 0.3 s hold (a widget *Tick* / *NativeTick*); heal = ghost in green running ahead. *Hardcore* = *Fill Image* a tiled segment brush, no ghost |
| Radial | a UI material: `TexCoord − 0.5` → **VectorToRadialValue** (its *Angle* output is 0–1 around the centre) → `Step(angle, Progress)`, ring = `RadialGradientExponential` (*Radius* 0.5, *Density* 20) minus an inner radial; *Progress* set on the Image's **Dynamic Material** each tick; the "ready" pop = a widget animation on *Render Transform* → *Scale*. *Rune* = `1 − angle`, a glowing rim emissive when `Progress ≥ 1` |
| Odometer | a **Text Block** whose value `FInterp To`s (or a Timeline over 0.6 s with an ease-out curve) and **To Text (Integer)** with *Use Grouping* on for the commas; rolling digits = one **Image** per digit with a 0–9 strip material offset by `Frac(value / 10^i) ` in V |
| Xpbar | one Progress Bar; on `xp ≥ threshold`: *Set Percent* 1, *Play Animation* `Flash`, then `xp −= threshold`, `threshold × 1.25`, `Set Percent(xp / threshold)` — loop while it still overflows (*Xpsurge*) |
| Offscreen | **Project World Location to Widget Position** (or *Project World to Screen*); if outside the viewport (*Get Viewport Size* / *Get Viewport Scale*), clamp to the edge rectangle minus a margin, *Set Position* on the arrow's **Canvas Panel Slot**, *Set Render Transform Angle* = `atan2(target − centre)`; the distance = a Text Block child. *Overwatch* = a radar ring: angle only, radius fixed |
| Anchor | built in: a **Widget Component** on the speaker with *Space* = **Screen** keeps the bubble projected every frame; the tail is part of the widget; clamping to the screen = the Offscreen row's clamp applied to a HUD-side copy (*Project World Location to Widget Position* + *Set Position*) |
| Xhair | four **Image** lines in a Canvas Panel whose offsets = `Spread`; `Spread += Bloom` per shot, `FInterp To(Spread, Rest, dt, 8)`; the hit marker = a widget animation (`HitMarker`, 0.1 s, *Play Animation* from start on every hit); shots land at `centre + random in disc(Spread)` |
| Damagearc | a full-screen Image with a UI material: `VectorToRadialValue` angle vs an `Angle` scalar → `smoothstep` arc of width 0.1 × an edge mask; `Angle` = the attacker's yaw relative to the camera (*Find Look at Rotation* − *Get Control Rotation*), opacity decaying over 1 s per DMI. *Deathring* = the whole ring pulsing at health < 0.2 |
| Toast | a **Vertical Box**; *Create Widget* → **Add Child to Vertical Box**; the toast plays `SlideIn` (*Render Transform* translation X 200 → 0, *Render Opacity* 0 → 1) on *Construct*, `SlideOut` on a *Set Timer* (3 s) then **Remove from Parent**; the box re-lays out the stack. *Ticker* = a **Horizontal Box** inside a **Scroll Box** scrolled by *Set Scroll Offset* each tick |
| Minimap | a **Scene Capture Component 2D** looking down (*Projection Type* Orthographic, *Ortho Width* 4000, *Capture Source* Final Color LDR) into a **Render Target**, shown by an Image brush; blips = Images positioned `(world − centre) / OrthoWidth × mapSize`; the sweep = a UI material over the map (`VectorToRadialValue` angle vs `Frac(Time / 3)` with a trailing fade); blip opacity = `1 − (Time − lastSweepTime)`. *Motiontracker* = blips only when `|velocity| > 10` |
| Ghostplacement | a Line Trace to the ground → **Vector Snapped to Grid** (*Grid Size* 100) → a ghost Static Mesh with a translucent DMI; validity from **Box Overlap Actors** at the snapped spot (`Tint` green / red); rotation = *Add Actor Local Rotation* Yaw 90 on press; place = *Spawn Actor from Class* at the snapped transform |
| Jewel | a UI material: `Tier` colour (a Vector Parameter per tier) + a sheen = **LinearGradient** rotated 45° → `Frac(gradient − Time × 0.3)` → a narrow `smoothstep` band added; *Junkloot* = sheen strength 0 on common cards |
| Bossbar | a **Horizontal Box** of N Progress Bars (one per phase, *Fill Type* Right to Left); intro = a widget animation `Intro` setting each bar's *Percent* 0 → 1 staggered; `Shake` = *Render Transform* translation keys ±4 px over 0.2 s; `Break` = translation Y +40 and *Render Opacity* → 0 on the emptied segment, then *Set Visibility* Collapsed |

## Audio — MetaSounds, attenuation, submixes, Quartz

The web cards make sound only after a press; in Unreal keep the same rule
(*Auto Activate* off, start on input). The synth home is a **MetaSound
Source** (with reusable **MetaSound Patches**); the mixer home is **Sound
Submix** + **Submix Effect Presets**; the clock is **Quartz**.

| Card | Unreal spelling |
|---|---|
| Positional | *Spawn Sound at Location / Attached* with a **Sound Attenuation** asset: *Attenuation Function* Natural Sound, *Inner Radius* 400, *Falloff Distance* 3000, **Spatialization** (Panning or Binaural), *Enable Air Absorption* (the distance lowpass), *Enable Occlusion* (a trace → *Occlusion Low Pass Filter Frequency*). Doppler: the Sound Cue **Doppler** node (*Doppler Intensity*) is the built-in; in a MetaSound compute `pitch = 1 + relSpeed / 340` in Blueprint and *Set Float Parameter* `Pitch` |
| Footsteps | an **Anim Notify** on each contact frame (or the stock *Play Sound* notify) → a Line Trace down with *Return Physical Material* → **Get Surface Type** → *Select* the MetaSound / sound array; MetaSound: **Random Get (WaveAsset:Array)** with *No Repeats* 2, *Random Float* pitch 0.9–1.1. Paper2D flipbooks have no notifies: edge-detect *Get Playback Position in Frames* == the contact frame each tick. *Fourlegs* = two notify tracks |
| Natter | a MetaSound Source: a **Trigger** input `Blip`, `Sine` for vowels, `Square` for consonants (a *Bool* input `IsVowel`), **AD Envelope (Audio)** *Attack* 0.005 / *Decay* 0.05, a *Float* input `Voice` → `Map Range` → frequency; the typewriter timer calls **Execute Trigger Parameter** and *Set Float / Bool Parameter* per letter |
| Envelopes | one MetaSound Patch per recipe, all built from the same nodes: explosion = `Noise (Pink)` → **Ladder Filter** with *Cutoff* on an AD Envelope (2000 → 100); jump = `Sine`, frequency on a rising AD (200 → 800 over 0.15 s); hurt = `Square` falling; pickup = **Trigger Repeat** (0.06 s) → *Array Get* semitones → **MIDI To Frequency**; slide whistle = **InterpTo** on frequency; boing = an **LFO** (8 Hz) on pitch with decaying depth. *Eightbit* = every oscillator `Square`, decays halved |
| Engine | a persistent **Audio Component** on a MetaSound Source with a *Float* input `RPM`: `Saw` + `Square` an octave apart at `Map Range(RPM, 0, 1, 40, 220)` Hz through a **Ladder Filter** whose cutoff also follows RPM, gain `0.3 + 0.7·RPM`; *Set Float Parameter* `RPM` each tick from `|velocity| / max`. *Electric* = one `Sine` two octaves up, gain ×0.5 |
| Noisebed | `Noise (Pink)` → **Biquad Filter** (*Type* Low Pass / Band Pass) with *Cutoff* = base + **LFO** (0.1 Hz, ±400) and a second LFO on gain; an *Int* input `Bed` through **Trigger Route** / *Select* picks wind (LP 600), rain (HP 2000 + fine crackle from *Random Float* bursts), surf (LP 400, LFO 0.08 Hz deep), fire (LP 800 + *Trigger Repeat* jittered pops) |
| Quiet | three built-ins: **Audio Volume** → *Ambient Zone Settings* → **Interior LPF** (0.3) / *Exterior Volume* — the behind-a-wall muffle by position; per-sound **Set Low Pass Filter Frequency** (+ *Set Low Pass Filter Enabled*) on any Audio Component; and the bus route — a **Sound Submix** with a **Submix Effect Filter Preset** (*Filter Type* Low Pass, *Filter Frequency* 400) applied via *Set Submix Effect Chain Override* when diving, cleared on surfacing. Pause = **Set Sound Mix Class Override** on a *Sound Mix* (or *Push Sound Mix Modifier*) |
| Yodel | **Audio Volume** → *Reverb Settings* with a **Reverb Effect** asset (*Decay Time* 3.0, *Density*, *Diffusion*, *Late Gain*, *Air Absorption Gain HF*) — the mix rises as you enter, by position; the echo = a **Submix Effect Tap Delay** / **Submix Effect Delay** on the cave submix, or in a MetaSound a **Stereo Delay** node (*Delay Time* 0.4, **Feedback** 0.5, *Wet Level*). *Yawningcave* = Delay Time 0.9, Feedback 0.7 |
| Jukebox | **Quartz**: *Quartz Subsystem* → **Create New Clock** (a *Quartz Clock Settings* with the time signature) → *Set Beats Per Minute* → *Start Clock*; one Audio Component per layer (drums, bass, lead), each **Play Quantized** on the same **Quantization Boundary** (*Bar*, *Count Type* Count Relative) so they start sample-locked; intensity = *Adjust Volume* (fade over 1 s) per layer; horizontal transitions = *Play Quantized* the next song on the next *Bar*; stingers = *Play Quantized* on *Beat*. Or one MetaSound Source with `Wave Player` layers and *Gain* inputs — locked by construction |
| Lookahead | **Quartz is the lookahead scheduler**: commands are queued to the audio-render thread ahead of time and fire on the boundary, not on the game frame. The frame-timed metronome = *Set Timer by Event* → *Play Sound 2D* (jitters with the frame); the scheduled one = *Play Quantized* on *Beat*; the measured error comes back through **Subscribe to Quantization Event** (*Quantization Type* Beat → an event with *Bar*, *Beat*, *Beat Fraction*) compared with *Get Game Time in Seconds*. *Latency* = a longer *Quantization Boundary* (two beats ahead) |
| Quota | a **Sound Concurrency** asset (*Concurrency Set* on the sound or its Sound Class): **Max Count** 4, **Resolution Rule** = *Stop Oldest* / *Stop Quietest* / *Prevent New* / *Stop Farthest Then Oldest* / *Stop Lowest Priority*, *Volume Scale* 0.8 (each newer voice ducks the older ones), *Limit to Owner*. *Quietquota* = Max Count 2, rule *Prevent New* (the "steal newest" reading) |
| Analyser | on the **Sound Submix**: *Start Spectral Analysis* → **Get Magnitude For Frequencies** (an array of Hz → magnitudes) each tick; on a wave, *Enable Baked FFT Analysis* (+ *Frequencies to Analyze*) → the Audio Component's **Get Cooked FFT Data**; envelope = *Start Envelope Following* → *On Audio Single Envelope Value*; the **Audio Synesthesia** plugin adds *Constant Q* / *Loudness* / *Onset* analyzers. Bars = Progress Bars or a material `Bars` texture; the camera pulse = a Camera Shake scaled by the low band |
| Rumble | a **Force Feedback Effect** asset: *Channel Details* per channel (*Affects Left Large* = the low motor, *Left Small* = the high motor, plus Right), each with a **Curve** over *Duration* — the two envelopes the card draws; play with *Client Play Force Feedback* (Player Controller), or **Play Dynamic Force Feedback** (*Intensity*, *Duration*, four *Affects* booleans) for one-off hits; positional = a **Force Feedback Component** with *Force Feedback Attenuation*. Phones: the same call maps to the OS vibrator where the platform supports it. *Rattle* = Small-motor channels only, 0.08 s |

Working order, in either dimension: **the post-process last** — build the
scene, the lights, the impacts and the HUD with nothing on the Post
Process Volume, then add the grade, the grain and the vignette as the
final coat, so every earlier family is judged on its own light.
