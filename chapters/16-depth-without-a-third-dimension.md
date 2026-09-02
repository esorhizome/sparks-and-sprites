# 16 · Depth without a third dimension — gradients, shading, and the cheap illusion of 3D

*Fresh-start note (no memory of other chapters required): a **gradient** is a smooth change of colour across a distance — from one colour at one end to another at the other; a **linear** gradient changes along a straight line, a **radial** one changes outward from a centre point; **alpha** is the per-pixel number that says how see-through something is (0 invisible, 1 solid); **additive blending** means a drawn colour is ADDED to what's behind it (light on light gets brighter), while normal ("source-over") blending covers what's behind; a **shader** is a tiny program that answers "what colour is this pixel?"; a **mesh** is a 3D shape made of points and the lines or triangles between them. Each is re-mentioned in place.*

---

Everything before this chapter asked *how does it move?* This chapter asks a different question: **how does a flat picture look round, far away, lit, solid, or in focus — on a screen that has no third axis?**

The honest answer is that your eye never had a third axis either. It has two flat retinas and a lifetime of learning which flat patterns *usually* mean depth: things far away are paler and bluer; a ball is bright on the side facing the light and dark on the other; a cube is three flat shades meeting at an edge; a shadow sits under whatever casts it; smoke near you is bigger, darker and faster than smoke far off. Painters have exploited those habits for six hundred years. Games exploit them because they are **almost free**: a gradient costs the same as a flat fill, and a picture that *looks* 3D needs no camera, no mesh, no lighting pass — which matters most exactly where budgets are tightest: 2D games, mobile, and the web.

So this chapter is a catalogue of **depth cues** — the flat patterns the eye reads as space — and every one of them turns out to be a gradient of *something*:

> **Depth is a gradient of some property between "here" and "there."** Choose the property (colour, contrast, brightness, size, speed, blur, darkness), choose the two ends, and the eye supplies the space in between.

▶ *See it all:* **[the depth atlas](https://esorhizome.github.io/sparks-and-sprites/depth.html)** — 104 live pictures, A to Z four times, in eight families (one cue each), every one editable in the page, and every one with a **rhyme** (the same picture with two or three dials turned — 208 pictures in all). It is built to be skimmed like [animate.style](https://animate.style/): recognise the picture you were imagining, open its code, turn its numbers. The Godot project ports all 104 (+104 rhymes) in [`demos/godot/scenes/depth.gd`](../demos/godot/scenes/depth.gd) (menu key **J**), and adds one thing the canvas can't: a real 3D wireframe whose lines fade with distance ([`depth_wire_3d.gd`](../demos/godot/scenes/depth_wire_3d.gd), key **K**).

## Is a "gradient-style graphic" even possible from code?

Yes — and on every platform it is the cheapest picture there is. The whole atlas is drawn with three calls:

```js
// the web — the atlas's entire toolkit, minus the sugar
g = ctx.createLinearGradient(x0, y0, x1, y1);      // a line the colour changes along
g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r); // circles the colour changes across
g.addColorStop(0, "#F5C169"); g.addColorStop(1, "#3A2A5A");   // colour stops: k 0..1 → colour
ctx.fillStyle = g; ctx.fill();                      // then paint any shape with it
```

- **Godot:** for nodes, `GradientTexture2D` (set *Fill* to linear or radial, and `fill_from`/`fill_to` for the direction) on a `Sprite2D`, `TextureRect`, or `ColorRect`; for `_draw()` code there is **no gradient-fill call**, and the port's kit shows the two honest spellings — a **linear gradient is a polygon with one colour per vertex** (`draw_polygon(points, colors)`: the GPU interpolates between corners for free), and a **radial gradient is a fan of triangles** with a bright centre vertex and a dark rim, drawn in one `RenderingServer.canvas_item_add_triangle_array` call. In shaders, `mix(colour_a, colour_b, UV.y)` is a vertical gradient in one line, and `mix(a, b, length(UV - centre) * 2.0)` a radial one.
- **Unity:** a `Gradient` (the curve-like asset with colour and alpha keys) evaluated per pixel into a `Texture2D`; or a Shader Graph *Gradient* node, or simply *Lerp* between two colours by UV. Sprites, UI Images, and particles all take the result.
- **Unreal:** the material editor's **LinearGradient** and **RadialGradientExponential** nodes, feeding *Lerp* between two colours — on a plane in 3D, on a UMG *Image* in 2D. That single graph is also the sky, the fog, and the vignette below.
- **Web CSS, zero JavaScript:** `background: linear-gradient(#1E4FB8, #CFE6F5)` for a sky, `radial-gradient(circle at 35% 30%, #fff, #5A63C8 45%, #14102A)` for a ball. Honestly the best gradient tool on any platform — animate the stops with a CSS animation and a sunrise needs no code at all.

Everything else in this chapter is a *rule for placing* one of those gradients.

## The eight cues — one family each

The atlas runs A to Z four times; the families are uneven on purpose, sized by how much each cue has to teach.

| Family | The cue | Why the eye believes it | The rule, in code |
|---|---|---|---|
| **Skies & horizons** | a vertical gradient | you look through more air sideways than straight up, so the horizon is paler; the colours *are* the time of day | `sky([top, horizon])`; a sunrise is `mix(keyframe[i], keyframe[i+1], f)` between palettes |
| **Distance & atmosphere** | far = paler, bluer, softer, slower | the air between you and a mountain is a translucent blue veil; more distance, more veil | `colour = mix(colour, air, depth)` per layer; sizes shrink; rows bunch as `horizon + p²` |
| **Rounded forms** | a radial gradient with its centre pushed toward the light | a lit ball is bright where it faces the light and dark opposite, with the transition (the *terminator*) between | `createRadialGradient(cx + lx·r·0.5, cy + ly·r·0.5, 0, cx, cy, r)` — **the offset IS the roundness** |
| **Facets & blocks** | three flat shades meeting at an edge | a solid's faces each face a different way, so each catches a different amount of light | top `shade(c, +0.32)`, left `c`, right `shade(c, −0.42)` — a cube from three squares; swap the shades and the bump becomes a dent |
| **Light sources** | a bright core, a falloff, and the light thrown on things | a source is defined less by itself than by what it illuminates | core disc + `soft` radial falloff (additive) + a gradient on the wall/floor that follows the source |
| **Volumes near & far** | size × brightness × speed × softness, all from one depth number | near smoke is big, dark, sharp and fast; far smoke small, pale, soft and slow | every particle has `z`; sort far → near; `size = a + z·b`, `alpha = fog(…, 1 − z)`, `speed ∝ z` |
| **Waves & ribbons** | a surface shaded by which way it faces | the slope facing the light is lighter; a twisting strip shows its back colour when it turns | shade by `cos(slope)`; ribbon width `= |cos(twist)|`, colour flips with the sign; rows recede as `horizon + p²` |
| **Shadows & focus** | where light can't reach; where the eye can't focus | a shadow *places* a thing on the ground and says how high it floats; blur says how far from the focus plane | contact shadow tight + dark; with height `radius ↓, alpha ↓, blur ↑`; overlap = order; blur/alpha = distance from focus |

The last row hides the two cheapest depth cues in the whole book, and they deserve their own sentence: **overlap** (whatever is drawn last is in front — sort by depth, draw far first, the "painter's algorithm") and the **contact shadow** (a dark ellipse under a thing tells the eye exactly where the ground is; shrink and fade it as the thing rises and the eye reads *altitude*). Neither needs a gradient at all.

## The specific pictures you asked for, and where they live

| Wanted | Card | The trick in one breath |
|---|---|---|
| sunrise / sunset | **D·Dawn**, **E·Eventide**, **N·Nightfall** | palettes as keyframes, mixed by a clock; the sun is a disc that climbs while the colours change; sunset is dawn's data reversed |
| wave sequence | **O·Ocean**, **T·Tide**, **W·Wake** | rows of travelling sines whose spacing bunches toward the horizon (`horizon + p²`), amplitude growing toward the viewer, far rows fogged |
| ribbon movement | **R·Ribbon**, **H·Helix**, **L·Loop**, **Z·Zephyr** | short quads along a path; width `|cos(twist)|`; front and back colours flip with the sign; shade by slope |
| mountains | **A·Alps**, **R·Ridgeline**, **V·Valley** | silhouettes layered far → near, each mixed toward the sky colour by depth; parallax by depth on press |
| rounded structures | **O·Orb**, **D·Dome**, **C·Column**, **U·Urn**, **T·Torus** | radial gradients offset toward the light; a cylinder is a horizontal dark → light → dark band; a vase is stacked cylinders |
| suns / stars | **S·Sun**, **E·Eclipse**, **Q·Quasar**, **F·Flare**, **G·Glitter** | limb-darkened disc + additive corona + rays; a star is a glint plus a soft halo, sized by depth |
| squares shaded to resemble cubes | **B·Block**, **I·Isotile**, **V·Voxels**, **S·Stairs**, **Z·Ziggurat** | three flat shades from one light direction, isometric projection `x = (ix − iy)·0.866, y = (ix + iy)·0.5 − iz` |
| smoke, dark → light, near → far | **P·Plume**, **D·Dustcloud**, **V·Vapour**, **I·Incense** | puffs with a depth `z` driving size, darkness, speed and softness together; sorted far → near; normal blending (smoke is matter) |
| flame, dark → light, near → far | **B·Blaze**, **W·Wildfire**, **Y·Yule**, **C·Candle** | three depth planes: back tongues dark and soft, front tongues bright and sharp; additive blending (flame is light) |
| magical sparkles, dark → light, near → far | **G·Glitter**, **F·Fireflies**, **M·Motes** | 4-point glints whose size, halo, brightness and twinkle speed all come from `z`; the far ones are pinpricks |

## The rhymes — where the genres live

Every card has a **rhyme**: the same picture with two or three dials turned, and nothing else — a palette, a count, a speed, a boolean. The rhyme's opening comment names exactly which dials moved. This is where the genre coverage lives: Aurora rhymes with a *glitch aurora* (16 fat strips, three times the speed); Dawn with a *candy dawn* (pastel keyframes, a doubled sun); Twilight with a *cyber twilight* (neon bands over a receding floor grid); Zenith with a *Martian zenith* (butterscotch sky, blue near the sun — the same physics with a different air). The lesson repeats 104 times: **palette is genre; the geometry is shared.** Understanding one recipe buys the whole neighbourhood.

In the Godot port the rhyme is literally a dials swap — every card keeps its numbers in one dictionary `D`, and right-clicking merges the rhyme's dials over it and re-runs the card's setup. Diffing a card's dials against its rhyme's is the whole lesson in eight lines.

## What each cue costs (the budget table)

All of these run on a phone. The order still matters when a hundred of them run at once.

| Cue | Cost | Note |
|---|---|---|
| flat shades (cubes, iso) | ~free | plain polygon fills |
| linear gradient | ~free | one fill; on the GPU it's per-vertex colour interpolation |
| radial gradient | cheap | one fill; a fan of ~28 triangles in Godot |
| depth-sorted particles | cheap | a sort per frame (`array.sort` on 40–200 items is nothing) |
| soft glows (`soft`) | cheap, adds up | each is a radial gradient; 100+ per frame on canvas starts to show on low-end phones |
| fake blur (multi-draw with offsets) | moderate | 3–5× the draws of the thing being blurred; use sparingly, or bake |
| real blur (`ctx.filter = "blur()"`, `CanvasItem` shaders) | expensive | per-pixel; fine for one hero object, not for a field of them |

The design stance that falls out: **depth cues are almost never the bottleneck**. If a scene stutters, count the glows and the blurs first; the gradients are innocent.

## Gradients on a wireframe — the 3D sibling (Godot key K)

Everything above fakes depth on a flat canvas. There is one case where you already *have* the third dimension — a turning 3D wireframe (a lattice, a knot, a fractal cage, a gallery of parametric curves) — and it reads flat anyway, because every line is the same colour. The fix is the same cue as the mountain range, applied properly: **lines fade with distance from the camera.** `demos/godot/scenes/depth_wire_3d.gd` shows three materials on one line mesh:

1. **Depth fade** — [`shaders/depth_fade.gdshader`](../demos/godot/shaders/depth_fade.gdshader), five real lines: transform the vertex to view space (`MODELVIEW_MATRIX * vec4(VERTEX, 1.0)`), take `-z` as the distance, and `mix(near_color, far_color, k)`. Because distance is measured from the camera each frame, the cue updates as the mesh turns — this is atmospheric perspective, done honestly. Applying it to an existing mesh is **one line and no mesh changes**: `mesh_instance.material_override = depth_fade_material()`. If your gallery already swaps a tint material onto `material_override`, this drops into the same slot.
2. **Vertex gradient** — a colour per vertex written once into the mesh's `ARRAY_COLOR` (graded by height, by distance from the centre, by index along a ribbon…), shown by a `StandardMaterial3D` with `vertex_color_use_as_albedo = true`. Static: it rides with the shape, so it reads as *paint*, not air — right for ribbons, spirals, and anything with a natural "along" direction. (If a line material sets that flag to `false`, the colours are silently ignored — that one flag is the usual reason "my vertex colours don't show".)
3. **Flat** — one colour, the control. Switch to it and watch the depth leave.

Unity's equivalent is a shader with `UnityObjectToViewPos(v.vertex).z` feeding a `lerp`; Unreal's is *PixelDepth* (or *CameraDepthFade*, which exists for exactly this) driving a *Lerp* into Emissive. three.js: `LineBasicMaterial` with `vertexColors: true` for the painted version, and `scene.fog = new THREE.Fog(colour, near, far)` for the depth version — fog on a line material is the depth fade with a friendlier name.

## The four platforms, per cue

Where the chapter above says "gradient", each engine spells it thus; the *placing rule* never changes.

- **Godot 2D:** `GradientTexture2D` for nodes; `draw_polygon` with per-vertex colours and the kit's triangle-fan `radial()` for `_draw()`; `CanvasItemMaterial` with `BLEND_MODE_ADD` for the light-family cards (or `draw_*` with a `lighter`-like look by stacking translucent discs); a `PointLight2D` plus a normal map is the *real* version of the rounded-form cue when you'd rather let the engine shade. Sorting by depth: set `z_index` from `z`, or keep one node and sort your own array.
- **Unity 2D:** gradients as `Texture2D` painted from a `Gradient`, or Shader Graph *Lerp*/*Gradient* nodes; *Sorting Layers*/*Order in Layer* for the painter's algorithm; an additive material for lights; `SpriteRenderer.color` mixed toward a fog colour per layer is atmospheric perspective in one line. [`demos/unity/Scripts/DepthAtlas2D.cs`](../demos/unity/Scripts/DepthAtlas2D.cs) paints six ambassador cards from code (sky, fogged ridges, lit ball, cube, depth-sorted smoke, contact shadow).
- **Unreal:** *LinearGradient*, *RadialGradientExponential*, *Lerp*, *Fresnel* (a rim light for free on any mesh), *CameraDepthFade*; in 2D the same material goes on a UMG *Image* or a Paper2D sprite; Niagara's *Sprite Size by Speed* and *Color over Life* do the volume cue natively. [`demos/unreal/recipes/depth-atlas.md`](../demos/unreal/recipes/depth-atlas.md) walks the eight cues with the atlas's exact numbers.
- **Web:** canvas gradients (the atlas); CSS `linear-gradient`/`radial-gradient` for anything that's a box; `filter: blur()` and `box-shadow` for the focus and shadow cues — a `box-shadow` whose offset, blur and alpha grow with "elevation" *is* the contact-shadow rule, which is why every design system ships it.

## A note on flashing light

One card in the atlas, **X·Xenon**, is a strobe — a hard flash every second and a half — and its rhyme, *Camera flash*, fires on every press. Flashing light can trigger seizures in photosensitive people, so that card is **opt-in**: it never starts with *Run all*, it shows a plain notice in its place, and it runs only when you click it, on the web and in the Godot port (the card carries a `warn` field; the runtime does the rest). If you build your own gallery, do the same for anything that flashes faster than about three times a second, and keep the notice itself static — a warning that flashes defeats its purpose.

## What usually goes wrong

- **The light disagrees with itself.** Every sphere lit from the upper-left, one cube lit from the right: the eye rejects the scene as a whole and can't say why. Pick one light direction per scene and derive every shade from it (the atlas's `lx, ly` dials exist for this).
- **Far things are just darker.** Distance is *paler and lower-contrast*, mixed toward the sky — not black. Darkening reads as night, not depth.
- **Smoke drawn additively.** Matter covers; light adds. A smoke puff played with additive blending turns into a glowing ghost. Say the blend mode next to the colour.
- **The shadow doesn't move when the thing does.** A shadow glued to the wrong spot un-grounds the object more than no shadow at all. Recompute it from the object's position and height every frame.
- **Blur everywhere.** Depth of field is a *difference*: one plane sharp, the rest soft. Blur it all and you have a smudge.
- **Vertex colours that don't show (3D).** The material must be told to read them (`vertex_color_use_as_albedo`, `vertexColors: true`); the default is off.

---

*Depth is a gradient of some property between here and there. Choose the property, choose the two ends, and the eye does the rest — for free.*
