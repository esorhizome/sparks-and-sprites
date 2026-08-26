# Dissolve — the noise-threshold trick

Per pixel: sample noise; if noise < threshold, the pixel is gone. Raising
the threshold 0→1 eats the surface away in noise-shaped islands.

Material graph (Blend Mode **Masked**):

```
NoiseTexture ──┐
               ├── If/Step( noise < Threshold ) ──→ Opacity Mask
Threshold  ────┘         (scalar parameter)
```

- Four nodes: TextureSample (any blurry noise), ScalarParameter
  `Threshold`, a `Step` (or `If`), into **Opacity Mask**.
- The burning edge: `noise < Threshold + 0.05` → lerp Emissive toward
  orange `(1, 0.6, 0.2)` — a thin glowing rim just ahead of the burn.
- Animate: a Timeline (Blueprint) or `SetScalarParameterValue` from C++
  driving `Threshold` 0 → 1.

Chapter 03 of the book; the same 3-line shader ships in the Godot project
(`demos/godot/shaders/dissolve.gdshader`) for comparison.
