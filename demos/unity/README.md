# Unity demos (script templates)

Every web/Godot demo, as a self-contained C# `MonoBehaviour`. In the spirit
of the rest of this repo, **each script builds everything it needs from
code** — textures are painted in `Start()`, meshes are generated, particle
systems are configured property by property. No prefabs, no imported assets.

> **Status: templates.** These are written against the Unity 6 API and kept
> deliberately close to the book's chapter text, but they are not yet part
> of a committed Unity project — that arrives as assets are imported
> gradually. Until then, treat each file as a working recipe: create an
> empty scene, add an empty GameObject, attach one script, press Play.
> If an API has drifted in your Unity version, the comments name the
> intent of every line, so the fix is always local.

## Setup

1. Unity Hub → new project (2D template for most, 3D for the last two).
2. Copy `Scripts/` into `Assets/`.
3. Empty GameObject → *Add Component* → the demo you want → Play.
4. Captions render via `OnGUI`, controls are named at the top of each file.

## The demos

| Script | Web twin | What it teaches |
|---|---|---|
| `SpriteBasics.cs` | sprite-basics | code-painted `Texture2D` → `Sprite` → place/move |
| `EasingPersonalities.cs` | easing-personalities | personality = the shape of speed (keys 1–8, L loops) |
| `SparksBurst.cs` | sparks | a one-shot `ParticleSystem` burst, configured in code |
| `Flame.cs` | flame | one particle skeleton, four costumes (keys 1–4) |
| `Parallax.cs` | parallax | three multiplications = depth |
| `ScrollUV.cs` | scroll-uv | `mainTextureOffset` — the one-line infinite scroll |
| `GlowAdditive.cs` | glow-additive | additive blending: light that adds up |
| `Dissolve.shader` + `DissolveDriver.cs` | dissolve | the noise-threshold trick as a ShaderLab shader |
| `SoundBlips.cs` | sound-blips | `OnAudioFilterRead` synthesis (keys 1–3) |
| `Trails.cs` | trails | `TrailRenderer` — the trail as short-term memory |
| `TrailsFragments.cs` | trails-fragments | *Rate over Distance* emission (keys 1–4 for costume) |
| `Waterdrops.cs` | waterdrops | a particle's death as an event (fall → splash + ripple) |
| `Halo.cs` | halo | code-painted ring + additive material + ±3% breath (1/2 = ring/head) |
| `MetalChrome.cs` | metal-chrome | the 1-D environment-map ball, redrawn per frame (click = molten) |
| `GlowButtons.cs` | glow-buttons | the two button species: static loop + velocity thank-you |
| `CursorSparkle.cs` | cursor-sparkle | hidden cursor, eased chase, distance-shed sparkles |
| `Starfield.cs` | starfield | sparks at 1/10 speed (keys 1–4 for preset) |
| `CameraShake.cs` | shake | trauma², smooth noise, fast calm (click / right-click) |
| `Planet3D.cs` | three-planet | displace a sphere's vertices by noise, colour by height |
| `OrbitGlow.cs` | babylon-scene | orbit rig from drag + emissive material (+ enable Bloom) |
| `ElementalButtons.cs` | elemental-buttons | the bestiary's two-species anatomy, with sample elements |
| `CubeVfx2D.cs` | cube-vfx | the codex protagonist in 2D: six equippable effects (keys 1–6) |
| `CubeVfx3D.cs` | cube-vfx | the same anatomy in real 3D: bursts, a halo light, a waterhose |

`ElementalButtons.cs` ports the bestiary's **anatomy** and a handful of
ambassador elements; the full 104 live on
[the web page](https://esorhizome.github.io/sparks-and-sprites/elemental-buttons.html)
and in the Godot project (`demos/godot`, all 104 in `scenes/elements/`).
The extension pattern is documented in the file — every element is one
idle function and one press function.
