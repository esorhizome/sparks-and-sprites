# 11 · three.js & Babylon.js — 3D (and 2D, and everything between) in the browser

*Fresh-start note: a **texture** is an image loaded for drawing; a **sprite** is a placed image; a **shader** is a tiny per-pixel colour program; a **material** bundles a shader with settings; a **mesh** is a 3D shape (points connected into triangles) wearing a material; **noise** is smooth organic randomness; a **tween** animates a value over time. Everything else this chapter needs, it explains on the spot — including the three confusingly-named JavaScript things in the next section.*

*Checked against three.js r185 and Babylon.js 9.22 (2026). Both are free, open-source, MIT-licensed.*

---

## First: three names, disentangled

The `.js` suffix only means "made of JavaScript." Beyond that, these are three very different things:

| | What it is | Where it runs | What it's for |
|---|---|---|---|
| **Node.js** | A place to *run* JavaScript outside a browser | Your machine, no window, no graphics | Backstage work: servers, build tools, test scripts, multiplayer coordination |
| **three.js** | A 3D drawing **library** | Inside a browser page | Everything the player *sees*: meshes, lights, cameras, shaders |
| **Babylon.js** | A 3D **engine** (library + batteries) | Inside a browser page | Same as three.js, plus built-in physics, GUI, audio, inspector |

A tidy way to hold it: **a three.js or Babylon game runs in front of the player; Node runs everywhere the player isn't looking.** They often appear in one project — Node bundling the code and running the multiplayer server, three.js drawing the spaceship — which is most of why they get confused.

### "Do I need Node.js to use three.js or Babylon.js?"

**No.** This surprises almost everyone. Both libraries are single files a CDN (a public file-hosting network) can hand your page directly:

```html
<!-- Babylon: one script tag, then a global BABYLON object exists -->
<script src="https://cdn.jsdelivr.net/npm/babylonjs@9.22.1/babylon.js"></script>

<!-- three: one import in a module script, nothing else -->
<script type="module">
  import * as THREE from "https://cdn.jsdelivr.net/npm/three@0.185.1/build/three.module.min.js";
</script>
```

A text editor, a browser, and (because module scripts refuse to load from `file://`) any local server — that's the complete dependency list. The [live demos below](https://esorhizome.github.io/sparks-and-sprites/) run on exactly this, hosted as plain files.

### So when *does* Node enter the picture?

When a project grows past one file, three conveniences appear, and all of them happen to run on Node:

- **npm** (Node's package manager) — `npm install three` instead of pasting CDN links, plus easy updates.
- **A dev server with hot reload** — [Vite](https://vitejs.dev/) (free) restarts your page the instant you save. This is the standard three.js workflow.
- **A bundler** — squashes your files + the library into one optimized download for release (Vite again).

None of this changes a line of your drawing code. Node is the *workshop*; three/Babylon are the *work*. Start CDN-only; adopt the workshop when juggling files starts to hurt — you'll feel the moment.

### three.js vs Babylon.js — how to choose

Both are excellent, mature, and free; communities are friendly in both. The honest differences:

- **three.js is a library: lean, minimal, enormous ecosystem.** It gives you scene/camera/mesh/light and stops. Everything else — physics, UI, model loaders beyond glTF — you add from its huge `examples/` folder or third-party packages. The showcase gravity is strong: most of the jaw-dropping web demos on reddit are three.js. Learning: the official [examples gallery](https://threejs.org/examples/) (every demo links its full source — show-while-telling at scale, free) and the famous [Three.js Journey](https://threejs-journey.com/) course (**paid**, ≈ $95 one-time — widely loved, entirely optional).
- **Babylon.js is an engine: batteries included.** Physics, collisions, a full 2D GUI system, audio, animation groups, glow layers, and a genuinely magical in-page **Inspector** (a live editor for your running scene) all ship in the box. Learning: the [Babylon Playground](https://playground.babylonjs.com/) (free) — edit code on the left, scene updates on the right, and every doc page embeds runnable playgrounds.
- **Rule of thumb:** want maximum control and the biggest example ocean → three.js. Want to build a *game* fast with fewer decisions → Babylon. Skills transfer almost entirely: both speak the same scene/mesh/material/light language, so learning either is 80% of learning the other.

---

## The many ways to use them

This is the part that's easy to miss: "3D library" undersells what these tools are for. Here is the actual menu.

### 1 · Full 3D scenes (the reddit-demo mode)

The classic mode: a scene (a container of everything), a camera (the viewpoint), lights, and meshes.

```js
// three.js — a complete lit 3D scene, genuinely this short
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(70, width / height, 0.1, 100);
camera.position.z = 4;
const renderer = new THREE.WebGLRenderer({ canvas });
renderer.setSize(width, height);
const mesh = new THREE.Mesh(
  new THREE.IcosahedronGeometry(1, 1),                     // a shape
  new THREE.MeshStandardMaterial({ color: 0x5a63c8, flatShading: true })
);
scene.add(mesh);
scene.add(new THREE.DirectionalLight(0xffffff, 2));
renderer.setAnimationLoop(() => {
  mesh.rotation.y += 0.005;                                // a tween by hand
  renderer.render(scene, camera);
});
```

▶ *See it live and editable:* [three.js planet demo](https://esorhizome.github.io/sparks-and-sprites/three-planet.html) — a noise-displaced planet with a starfield, ~60 lines.
▶ *And the Babylon flavour:* [Babylon scene demo](https://esorhizome.github.io/sparks-and-sprites/babylon-scene.html) — drag to orbit, with engine-included glow and GUI.

### 2 · Pure 2D (yes, really)

Switch the camera from perspective (far things shrink) to **orthographic** (no shrinking — a flat, technical-drawing view) and a 3D library becomes a GPU-fast 2D engine:

- **three.js:** `OrthographicCamera` + flat quads (or `THREE.Sprite`, which is a placed image that always faces the camera — the word "sprite" means here exactly what it means everywhere in this book).
- **Babylon:** the same orthographic mode — plus its whole **GUI system is natively 2D** already.

Why bother, when Canvas 2D exists? Two reasons: **scale** (thousands of moving sprites stay smooth, because the graphics card does the work — the same reason given in chapter 01's draw-call entry) and **shaders** (chapter 03's dissolve/outline/palette tricks run per-pixel on your 2D art). This is the niche PixiJS lives in full-time; three/Babylon can moonlight there.

### 3 · 2D + 3D combinations — every manifestation

This is where it gets genuinely fun, and everything here is standard practice, not a hack:

- **Billboards** — 2D images living *inside* the 3D world, always turning to face the camera. `THREE.Sprite` / Babylon's `billboardMode`. This is how games do distant trees, smoke puffs, enemy health bars — and it's the entire rendering model of early first-person shooters (3D corridors, 2D monsters). Retro-styled indie games recreate that on purpose.
- **HUD overlay, easiest form** — plain HTML floating above the canvas. Your score counter is a `<div>`; CSS does the styling; the 3D never knows. Underrated and completely legitimate.
- **HUD overlay, engine form** — a second, orthographic scene drawn on top of the 3D one each frame (three.js), or Babylon's built-in `AdvancedDynamicTexture` GUI (buttons, sliders, text — all inside the engine).
- **Canvas-as-texture** — draw with familiar Canvas 2D code (all of chapters 02–06!), then use that canvas *as a texture on a 3D surface*. A live scoreboard on a stadium screen, a hand-drawn map on a 3D table, chapter 06's flame flickering on a 3D monitor. `THREE.CanvasTexture` / Babylon `DynamicTexture`. This is the single most direct bridge between this book's 2D chapters and the 3D world.
- **2.5D** — 3D graphics, 2D gameplay: characters are full 3D models but movement locks to a flat plane, camera fixed side-on. This is the standard construction of modern **fighter games**, and many beloved platformers. All the personality recipes from chapter 05 apply unchanged — a tween doesn't care how many dimensions the artist used.
- **Render targets** — render a 3D scene *into a texture*, then use that texture anywhere: a rear-view mirror in a flight game, a security monitor, a minimap, a magic portal showing another room. Both libraries treat this as routine.
- **Pixel-art 3D** — render the 3D scene deliberately tiny (say 320×180) into a render target, then upscale with chunky pixels (`image-rendering: pixelated`, or nearest-neighbour filtering — chapter 09 №4's crispness trick, aimed the other way). 3D geometry, retro soul.
- **CSS3D** — three.js's `CSS3DRenderer` positions *real DOM elements* (text, buttons, video embeds) in 3D space. Scrolling galleries and portfolio sites love it; it's web-art territory more than game territory.

### 4 · Beyond games entirely

Product viewers (turn the sneaker with your mouse), data visualization in 3D, shader-art backgrounds for websites, scrollytelling articles where the camera flies as you scroll, music visualizers. Same skills, different subjects — and this half of the ecosystem is where a lot of paid web work lives.

---

## How the reddit genres are actually built

The demos you've admired decompose into recipes this book already teaches, plus one 3D twist each:

- **Flight games** — a chase camera that *lerps* toward a point behind the plane (chapter 05's spring, in 3D); terrain displaced by noise (chapter 04's noise skies, applied to geometry); **fog** hiding the draw distance and doubling as atmosphere. Banking the plane into turns is one eased rotation — chapter 05's "human" recipe.
- **Fighter games** — 2.5D construction (above); hit-flash, screen shake, and spark bursts on impact are chapter 06 verbatim.
- **Space games** — a starfield (chapter 04's, as 3D points); engine trails (chapter 06's trails, as ribbon geometry); **bloom** post-processing making engines and lasers bleed light (chapter 06's glow, screen-wide); additive everything.
- **Planet exploration** — a sphere whose vertices are pushed outward by noise (mountains from arithmetic — the planet demo does exactly this); an atmosphere made with a **fresnel** effect — a shader term meaning "stronger at grazing angles," which paints a soft rim of light around the planet's edge. Recognize it? It's chapter 06's halo, grown up and wrapped around a sphere.

The visual wow of these demos is maybe 30% geometry and 70% the vocabulary you already have: noise, easing, additive light, fog, particles. That's not a pep-talk sentence; it's an engineering observation.

---

## A gentle on-ramp (in order)

1. **Open the [three.js planet](https://esorhizome.github.io/sparks-and-sprites/three-planet.html) and [Babylon scene](https://esorhizome.github.io/sparks-and-sprites/babylon-scene.html) demos.** Run, tweak one number, run again — the same loop as every other demo in this book.
2. **Play in the [Babylon Playground](https://playground.babylonjs.com/)** — zero setup, instant feedback, shareable links.
3. **Wander the [three.js examples](https://threejs.org/examples/)** — when one amazes you, read its source; they're all short.
4. **Copy either demo into your own HTML file** (CDN links and all) and grow it. Still no Node.
5. **When one file becomes five,** install Node, run `npm create vite@latest`, and move in. The drawing code comes with you unchanged.

Free 3D models for all of this: the CC0 sources from chapter 08 — Kenney, Quaternius, Poly Haven — all export **glTF**, the format both libraries load natively (three via its `GLTFLoader` addon, Babylon out of the box).

⚠️ **Web-export reality check:** everything in chapter 09 applies here too — these are WebGL pages like any engine export. The memory ceilings (№2) and the "test one browser per engine family" rule hit 3D pages hardest, because textures and meshes are the biggest memory eaters.

---

*Scene, camera, light, mesh, material — five words, and you've read real three.js code today without flinching. The reddit demos didn't get less impressive; they got less mysterious. That trade is the whole point of this book.*
