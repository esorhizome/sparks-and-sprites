# Chrome & liquid metal — a mirror with opinions

Real 3D chrome in Unreal is two numbers and one warning:

- **Metallic 1, Roughness ~0.05** on any StandardMaterial.
- The warning: a mirror with nothing to reflect is BLACK. Give it a sky, a
  ReflectionCapture, or Lumen — most templates place these for you.

The book's 2-D matcap version (the striped fake world) as a material:

```
VertexNormalWS.Z (−1..1) → remap 0..1 → sample a 1-D "band ramp" texture
   (sky / horizon / ground / sky stripes) → Emissive
```

- The band ramp texture: paint sky `#FCFDFF`, horizon-grey, dark ground
  band at 0.5, lighter below — the same stops as the web demo.
- **Liquid**: add `sin(worldPos × 9 + Time × 2.2) × 0.06 × Liquid` to the
  lookup coordinate — the wobble is where you READ, not what you draw.
- **Glint**: `exp(−((lookup − frac(Time × 0.45 / 1.4)) × 9)²)` lerps the
  result toward white — a bright band sweeping down every few seconds.

Chapter 06 has the full metal entry; `demos/godot/scenes/metal_chrome.gd`
is the same lookup written as scanlines.

## The 2D spelling

The matcap-band trick is *born* 2D — the web demo fakes normals from UV
position, and the same works on a sprite: replace `VertexNormalWS.Z` with a
gradient built from `TexCoord.V` (or a painted "fake normal" channel in the
sprite's texture), then the identical band-ramp lookup, wobble, and glint.
Apply to a Paper2D sprite material or a UMG Image brush; the glint sweep is
pure `Time` math either way.
