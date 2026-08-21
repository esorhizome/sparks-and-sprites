# Cheatsheet · Backgrounds

Five patterns. Full chapter: [04](../chapters/04-backgrounds.md).

| Pattern | Idea | Godot | Unity | Unreal | Web |
|---|---|---|---|---|---|
| Gradient | two colours, done | `ColorRect` / `GradientTexture2D` | camera clear colour | unlit gradient material | `linear-gradient` |
| Parallax | `layer.x = camera.x * factor` | `Parallax2D` (scroll_scale) | 3 lines in `LateUpdate` | same arithmetic | `translateX` fractions |
| Infinite scroll | slide UV offset by time | `UV += vec2(TIME*.03, 0)` | `mainTextureOffset` | *Panner* node | animate `background-position` |
| Noise sky | noise → colour gradient | `NoiseTexture2D` | Shader Graph noise node | material Noise node | full-screen shader / canvas |
| Starfield | N slow dots, wrap at edges | CPUParticles2D or code | Particle System | Niagara | [demo](https://esorhizome.github.io/sparks-and-sprites/starfield.html) |

**Rules of thumb:** far layers 0.1–0.3 × camera, near layers 0.7–0.95 × · gradient + parallax + a pinch of noise ≈ 90% of admired backgrounds · free CC0 HDRI skies: [Poly Haven](https://polyhaven.com/).

**Live demos:** [parallax](https://esorhizome.github.io/sparks-and-sprites/parallax.html) · [scroll-uv](https://esorhizome.github.io/sparks-and-sprites/scroll-uv.html) · [starfield](https://esorhizome.github.io/sparks-and-sprites/starfield.html)
