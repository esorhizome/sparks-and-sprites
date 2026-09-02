# Cheatsheet · Depth without a third dimension

Everything = **depth is a gradient of some property between "here" and "there."** Full chapter: [16](../chapters/16-depth-without-a-third-dimension.md). Live demos: [the depth atlas](https://esorhizome.github.io/sparks-and-sprites/depth.html) (104 pictures A–Z ×4, each with a rhyme = 208, all editable).

## The three gradient calls (everything below is a rule for placing one)

```js
ctx.createLinearGradient(x0, y0, x1, y1)              // colour changes along a line
ctx.createRadialGradient(cx+ox, cy+oy, 0, cx, cy, r)  // …across circles; ox,oy pushes the centre → a lit ball
g.addColorStop(k, colour)                             // k 0..1
```

| Platform | Node / zero-code | Code |
|---|---|---|
| Godot | `GradientTexture2D` (fill linear/radial, `fill_from`/`fill_to`) | `draw_polygon(pts, colors)` = linear (colour per vertex); triangle fan = radial; shader `mix(a, b, UV.y)` |
| Unity | Shader Graph *Gradient* / *Lerp* by UV | `Gradient.Evaluate(k)` → `Texture2D.SetPixels` |
| Unreal | *LinearGradient*, *RadialGradientExponential* → *Lerp* (3D plane or UMG Image) | same nodes; *CameraDepthFade* for distance |
| Web | CSS `linear-gradient` / `radial-gradient` | canvas, above |

## The eight cues, one line each

| Family | Cue | The rule |
|---|---|---|
| Skies | vertical gradient = time & air | `sky([zenith, horizon])`; sunrise = `mix(key[i], key[i+1], f)` between palettes |
| Distance | far = paler, bluer, softer, slower | `mix(colour, air, depth)`; sizes shrink; rows at `horizon + p²`; parallax ∝ depth |
| Rounded | radial gradient, centre toward the light | offset `= (lx, ly) · r · 0.5`; **the offset IS the roundness**; rim = a second radial from the far side |
| Facets | three flat shades | top `+0.32`, left `0`, right `−0.42` from one light; iso: `x=(ix−iy)·0.866, y=(ix+iy)·0.5−iz`; swap shades → a dent |
| Lights | core + falloff + thrown light | disc, `soft()` falloff (additive), a gradient on the wall that follows the source |
| Volumes | one `z` drives size × alpha × speed × softness | sort far → near; light adds, matter covers |
| Waves & ribbons | shade by slope; width by twist | shade ∝ `cos(slope)`; ribbon width `|cos θ|`, back colour when `cos θ < 0`; draw the back half first |
| Shadows & focus | where light can't reach; where the eye can't focus | contact shadow tight+dark; height → smaller, softer, fainter; overlap = order; blur = distance from focus |

## The A–Z, the four laps

**Skies (12):** A·Aurora · B·Bluehour · D·Dawn · E·Eventide · G·Goldenhour · H·Haze · N·Nebula · N·Nightfall · O·Overcast · R·Rainbow · T·Twilight · Z·Zenith
**Distance (13):** A·Alps · C·Canyon · D·Dunes · F·Fjord · I·Icebergs · K·Knoll · M·Mesa · P·Pines · Q·Quay · R·Ridgeline · S·Skyline · V·Valley · W·Woodland
**Rounded (13):** C·Column · D·Dome · E·Egg · E·Eyeball · J·Jupiter · L·Lozenge · O·Orb · P·Pearl · Q·Quicksilver · T·Torus · U·Urn · Y·Yolk · Z·Zeppelin
**Facets (13):** B·Block · G·Gem · H·Hexprism · I·Isotile · K·Keep · P·Pyramid · Q·Quilt · S·Stairs · V·Voxels · W·Wedge · X·Xylophone · Y·Yurt · Z·Ziggurat
**Lights (13):** C·Candle · E·Eclipse · F·Flare · H·Hearth · K·Kiln · L·Lantern · M·Moonphases · N·Neon · Q·Quasar · R·Rimlight · S·Sun · U·Ultraviolet · X·Xenon
**Volumes (13):** A·Ash · B·Blaze · D·Dustcloud · F·Fireflies · G·Glitter · I·Incense · J·Jellyfish · M·Motes · P·Plume · S·Steam · V·Vapour · W·Wildfire · Y·Yule
**Waves & ribbons (13):** F·Flag · H·Helix · J·Jetstream · K·Kite · L·Loop · O·Ocean · R·Ribbon · T·Tide · U·Undertow · W·Wake · X·Xebec · Y·Yacht · Z·Zephyr
**Shadows & focus (14):** A·Ambient · B·Bokeh · C·Contact · G·Ground · I·Inkwash · J·Jump · L·Longshadow · M·Mirror · N·Noir · O·Occlusion · T·Tiltshift · U·Umbra · V·Vignette · X·Xray

Every card's ⇄ button shows its **rhyme** — the same picture with 2–3 dials turned (palette · count · speed) — and that's where the genres live: glitch auroras, candy dawns, cyber twilights, Martian skies, neon temples, synthwave grids.

## Wanted → card

sunrise/sunset → Dawn, Eventide, Nightfall · wave sequence → Ocean, Tide, Wake · ribbon movement → Ribbon, Helix, Loop, Zephyr · mountains → Alps, Ridgeline, Valley · rounded structures → Orb, Dome, Column, Urn, Torus · suns/stars → Sun, Eclipse, Quasar, Flare, Glitter · squares → cubes → Block, Isotile, Voxels, Stairs, Ziggurat · smoke near→far → Plume, Dustcloud, Vapour · flame near→far → Blaze, Wildfire, Yule · sparkles near→far → Glitter, Fireflies, Motes

## Gradients on a 3D wireframe (Godot key K)

```gdscript
mesh_instance.material_override = depth_fade_material()   # lines fade with view-space distance — one line, no mesh changes
# shaders/depth_fade.gdshader: d = -(MODELVIEW_MATRIX * vec4(VERTEX,1)).z;  mix(near_color, far_color, k)
# painted instead: ARRAY_COLOR per vertex + StandardMaterial3D.vertex_color_use_as_albedo = true
```
Unity: `UnityObjectToViewPos(v).z` → `lerp` · Unreal: *CameraDepthFade* → *Lerp* · three.js: `scene.fog` on a line material / `vertexColors: true`.

## What goes wrong

one light per scene (every shade derived from it) · far = paler + lower contrast, never darker · smoke normal, flame additive · recompute the shadow from position + height every frame · blur is a *difference*, not a coat · vertex colours need the material's flag on.
