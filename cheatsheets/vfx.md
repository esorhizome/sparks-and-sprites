# Cheatsheet · VFX

Every effect is one of two mechanisms: **spawn small things with simple rules** (particles) or **bend colour/UVs with a tiny shader**. Full chapter: [06](../chapters/06-vfx-cookbook.md).

| Effect | Mechanism | Godot | Unity | Unreal | Web |
|---|---|---|---|---|---|
| Glow (screen) | bloom: bright pixels leak | WorldEnvironment → Glow, colours > 1.0 | URP Volume Bloom + HDR emission | on by default; emissive > 1 | (skip on low-end) |
| Glow (sprite) | additive blob behind | CanvasItemMaterial → Add | additive material | additive material | `drop-shadow` / `"lighter"` |
| Flame | rising shrink-fade particles, additive | GPUParticles2D | Particle System | Niagara "Fountain" retuned | canvas particles |
| Sparks | burst + gravity + short life | one-shot emitter | Burst emission | Niagara burst | 4-line physics |
| Waterdrops | downward sparks + splash on death | ↑ | ↑ | ↑ | ↑ |
| Halo | additive ring, ±3% scale breath | additive sprite | additive sprite | additive material | radial-gradient + `screen` |
| Metal / chrome | env value bands by normal + travelling additive glint | shader or matcap; 3D: metallic 1 + probe | metallic-smoothness + Reflection Probe | Metallic 1, low Roughness | band lookup per pixel |
| Liquid metal | wobbling silhouette, crisp reflections | same + noise on the rim | same | same | metaballs / sine rim |
| Trail | last-N positions strip, fading | `Line2D` fed points | `TrailRenderer` (no code) | Niagara ribbon | don't-clear-canvas trick |
| Fragmented trail | shed particles by distance moved | `CPUParticles2D` on mover | *Rate over Distance* emission | spawn-per-unit | particles at pointer |
| Afterimage | frozen fading copies | duplicate node, tween alpha | sprite copies | material trick | canvas copies |
| Dissolve | noise vs sliding threshold, discard | shader, 3 lines | Shader Graph: noise→Step→AlphaClip | material: noise→if→OpacityMask | per-pixel canvas |
| Shockwave | ring scales 0→3× while fading | tween | tween | Timeline | tween/`animate` |
| Screen shake | `noise(t) * trauma²`, trauma decays | camera offset | camera offset | camera shake class | transform on wrapper |
| Ambience | 2–8/sec slow drifting particles | GPUParticles2D | Particle System | Niagara | starfield code |

**Live demos:** [sparks](https://esorhizome.github.io/sparks-and-sprites/sparks.html) · [flame](https://esorhizome.github.io/sparks-and-sprites/flame.html) · [glow](https://esorhizome.github.io/sparks-and-sprites/glow-additive.html) · [dissolve](https://esorhizome.github.io/sparks-and-sprites/dissolve.html) · [trails](https://esorhizome.github.io/sparks-and-sprites/trails.html) · [fragmented trails](https://esorhizome.github.io/sparks-and-sprites/trails-fragments.html) · [waterdrops](https://esorhizome.github.io/sparks-and-sprites/waterdrops.html) · [halo](https://esorhizome.github.io/sparks-and-sprites/halo.html) · [chrome & liquid metal](https://esorhizome.github.io/sparks-and-sprites/metal-chrome.html) · [shake](https://esorhizome.github.io/sparks-and-sprites/shake.html) · [starfield](https://esorhizome.github.io/sparks-and-sprites/starfield.html)

**UI feedback** (glowing buttons, cursor trails, responsive cursors) has its own chapter: [12](../chapters/12-cursors-and-living-buttons.md) — demos: [living buttons](https://esorhizome.github.io/sparks-and-sprites/glow-buttons.html) · [responsive cursor](https://esorhizome.github.io/sparks-and-sprites/cursor-sparkle.html)

**Cross-engine authoring:** [Effekseer](https://effekseer.github.io/en/) — free MIT VFX editor with Godot/Unity/Unreal runtimes.
