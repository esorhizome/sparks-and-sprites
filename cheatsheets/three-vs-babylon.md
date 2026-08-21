# Cheatsheet · Node.js vs three.js vs Babylon.js

Full chapter: [11](../chapters/11-three-and-babylon.md). Live demos: [three planet](https://esorhizome.github.io/sparks-and-sprites/three-planet.html) · [Babylon scene](https://esorhizome.github.io/sparks-and-sprites/babylon-scene.html).

## The three names

| | Node.js | three.js | Babylon.js |
|---|---|---|---|
| Is a… | JavaScript **runtime** (a place to run JS) | 3D **library** | 3D **engine** (library + batteries) |
| Runs | on your machine, no window | in the browser | in the browser |
| Player sees it? | never | everything | everything |
| Needed for the other two? | **No** — CDN link suffices | — | — |
| License / cost | MIT, free | MIT, free | Apache-2.0, free |

**Dependencies, truthfully:** browser + editor + any local server = complete. Node/npm/Vite join later for convenience (installs, hot reload, bundling), changing zero lines of drawing code.

## Choosing

- **three.js** — lean core, vast ecosystem, the showcase champion. Learn from [threejs.org/examples](https://threejs.org/examples/) (free, all sources linked); [Three.js Journey](https://threejs-journey.com/) course is *paid* (≈ $95 one-time, optional).
- **Babylon.js** — physics, GUI, audio, glow, live Inspector all built in; fastest route to a playable game. Learn in the [Playground](https://playground.babylonjs.com/) (free).
- Skills transfer ~80% either direction. Both load glTF models (Kenney / Quaternius / Poly Haven are CC0).

## Modes of use

| Mode | How | Typical use |
|---|---|---|
| Full 3D | perspective camera + meshes + lights | flight, space, exploration games |
| Pure 2D | **orthographic** camera (no perspective shrink) + quads/sprites | GPU-fast 2D, shader effects on sprites |
| Billboards | `THREE.Sprite` / `billboardMode` — 2D images in 3D, always facing camera | health bars, smoke, retro-shooter enemies |
| HUD | HTML over the canvas (easiest) · overlay scene · Babylon GUI | score, menus |
| Canvas-as-texture | `CanvasTexture` / `DynamicTexture` — 2D canvas drawn onto 3D surface | live scoreboards, this book's ch. 02–06 tricks in 3D |
| 2.5D | 3D models, movement locked to a plane, fixed camera | fighter games, platformers |
| Render target | render a scene into a texture, use anywhere | mirrors, minimaps, portals, pixel-art 3D |
| CSS3D | real DOM elements positioned in 3D (three.js `CSS3DRenderer`) | web-art, galleries |

## Genre recipes (3D twist + this book's chapters)

- **Flight:** chase-camera lerp (ch 05) + noise terrain (ch 04) + fog
- **Fighter:** 2.5D + hit-flash/shake/sparks (ch 06)
- **Space:** starfield (ch 04) + additive trails + bloom (ch 06)
- **Planet:** noise-displaced sphere + fresnel rim glow (= ch 06's halo, wrapped around a sphere)
