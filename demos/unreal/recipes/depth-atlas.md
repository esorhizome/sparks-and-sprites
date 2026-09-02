# Depth atlas — the illusion of depth on a flat plane, in the material editor

The web atlas (docs/depth.html) shows 104 ways a **2D** picture is made to
look round, far, lit, solid, or in focus — gradients, atmospheric
perspective, three-shade cubes, depth-sorted smoke, contact shadows, blur.
Unreal is unusual here: it has *real* depth everywhere, so most of these
cues are one node each, and the interesting question is which node. The
placing rules are the atlas's; the numbers below are the atlas's numbers.

## The gradient itself (everything else is a rule for placing one)

Material → *Unlit*, *Translucent* (or *Additive* for the light family):

- **LinearGradient** — outputs UGradient and VGradient (0 → 1 across the
  UVs). Feed VGradient into a **Lerp(A = horizon colour, B = zenith
  colour)** → Emissive. That is a sky. Put the material on a plane in 3D
  or on a **UMG Image** in 2D: the graph is identical.
- **RadialGradientExponential** — *Radius* 0.5, *Density* 2–4, and the
  *CenterPosition* pin is **the offset that turns a disc into a lit ball**:
  push it toward the light (e.g. (0.35, 0.3) for upper-left) and Lerp from
  the highlight colour to the shadow colour. Add a second, inverted radial
  from the opposite side at low alpha for a rim light.
- Multi-stop gradients: chain Lerps with **SmoothStep** ranges on the
  gradient value, or sample a 1×N **Curve Atlas** by it (the honest
  "colour ramp" — this is how Niagara's *Color over Life* works too).

## The eight cues → nodes

| Family | The cue | Unreal spelling |
|---|---|---|
| Skies | vertical gradient = time of day | LinearGradient.V → Lerp between two **Vector Parameters**; drive them from a Blueprint timeline for sunrise (Dawn's keyframes: night `#05051A/#1A1030` → violet `#2A1E5A/#C2507A` → morning `#5A7FD0/#F5A15A` → day `#6FA8E8/#CFE6F5`) |
| Distance | far = mixed toward the air | **CameraDepthFade** (or *PixelDepth* ÷ far distance) → Lerp(object colour, air colour) — atmospheric perspective per material; in 2D, a per-layer *Tint* parameter mixed toward the air by hand (`0.2, 0.4, 0.6, 0.8`) |
| Rounded | radial gradient offset toward the light | RadialGradientExponential with *CenterPosition* off-centre → Lerp(light, dark); **Fresnel** gives a rim for free on any real mesh |
| Facets | three flat shades | three planes or one sprite atlas with tints `×1.32` (top), `×1.0` (left), `×0.58` (right) of one base colour; in 3D just let a directional light do it |
| Lights | core + falloff + thrown light | RadialGradientExponential (Density 4–8) into Emissive, **Additive** blend; the "thrown light" is a second, wide, faint radial on the wall material — or, in 3D, an actual PointLight |
| Volumes | one z drives size × alpha × speed | Niagara: *Sprite Size* and *Color* both driven from a per-particle **Depth** attribute (random 0–1 at spawn); *Sort Mode* = View Depth so near puffs cover far ones; smoke Translucent, flame Additive |
| Waves & ribbons | shade by slope; width by twist | Niagara **Ribbon Renderer** with a *Twist* curve; shading from the ribbon's normal against a fixed light vector (dot → Lerp) — or a scrolling **Sine** on a plane's WorldPositionOffset with `ddx` for the slope |
| Shadows & focus | where light can't reach / the eye can't focus | contact shadow = a **decal** or a flat plane with a radial alpha whose *scale* and *opacity* are bound to height (`scale = 1 − 0.6·k`, `opacity = 0.55·(1 − 0.8·k)`); focus = the post-process **Depth of Field** (Cinematic) — set *Focal Distance* to the hero plane |

## The values the atlas uses

| Card | Numbers worth copying |
|---|---|
| Orb | highlight offset `0.55 · r` toward the light; stops: `+35%` lighter at 0, base at 0.35, `−35%` at 0.8, `−75%` at 1 |
| Block | top `+32%`, left base, right `−42%` — one light from the upper left, for every solid in the scene |
| Alps | five layers; layer i mixed `(1 − i/5) · 0.85` toward the air; near layers drift more |
| Plume | 26 puffs; size `0.03 + 0.07·z`, darkness `lerp(air, soot, z)`, rise speed `0.05 + 0.12·z`; sorted by z |
| Contact | with height k: radius `× (1.1 − 0.6k)`, alpha `× (1 − 0.8k)`, blur up |
| Sky | zenith `#1E4FB8` → horizon `#CFE6F5`; the eye reads that one gradient as "outdoors" |

## The 2D spelling

Everything above works on a **UMG Image** (the material's *Material
Domain* = User Interface) or a **Paper2D** sprite material with no changes
to the graph — LinearGradient and RadialGradientExponential read the
widget's UVs exactly as they read a plane's. Two things differ: UMG has no
post-process, so depth of field becomes a *blur* material (the *Blur*
widget, or a stack of offset copies at low opacity, exactly as the atlas's
Tiltshift card does), and there is no real light, so the "thrown light"
radial must be drawn on the wall widget itself — which is what the web and
Godot versions do anyway. Sorting is *ZOrder* on the widget, `SortOrder`
on Paper2D sprites: far first.

## The 3D sibling

The one cue the flat atlas can't draw is a real wireframe fading with
distance (the Godot project's key K). In Unreal it is **CameraDepthFade**
(Fade Length = far − near, Fade Offset = near) into a Lerp(near colour,
far colour) on an Unlit material applied to the line mesh — atmospheric
perspective in two nodes, updating as the mesh turns.
