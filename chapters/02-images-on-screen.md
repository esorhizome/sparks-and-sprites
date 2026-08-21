# 02 · Putting images on screen, programmatically

*Fresh-start note: a **texture** is an image loaded into graphics-card memory so it can be drawn; a **sprite** is a texture that has been given a position on screen. That's all the jargon this chapter needs, and it will be re-mentioned as we go.*

---

The universal recipe, in every engine, is the same three steps:

> **load** the file into a texture → **attach** it to a thing that can be drawn → **place** that thing.

Everything below is that recipe wearing different syntax.

▶ *See it live:* [sprite basics demo](https://esorhizome.github.io/sparks-and-sprites/sprite-basics.html) — the demo even *generates* its image from code, so you can see there's no magic hiding in an asset file.

## Godot — `Sprite2D` from code

```gdscript
var s := Sprite2D.new()
s.texture = load("res://art/friend.png")   # load: file → texture
s.position = Vector2(240, 160)             # place
s.modulate = Color(1, 1, 1, 0.8)           # tint & alpha (transparency) in one property
add_child(s)                               # attach to the scene
```

Where it lives:
- `Sprite2D` — a placed image in the 2D world.
- `TextureRect` — the same idea for UI (stretches with layout).
- `AnimatedSprite2D` — sprite-sheet animation (many frames packed in one image) with named animations.
- `Image` + `ImageTexture` — build pixels from scratch in code, then display them.

⚠️ **Watch out:** `load()` reads from the project (`res://`). Loading from a user's disk at runtime is a different function (`Image.load_from_file()`) — and on web exports, arbitrary disk access isn't a thing at all.

🎮 *Direct demo:* open `demos/godot/` in Godot and run the **sprite basics** scene — it builds this exact setup in `_ready()`, with comments.

## Unity — `SpriteRenderer` from code

*Unity doesn't get a bundled demo project (it would bloat the book), but this is complete, pasteable code — drop it in any script's `Start()`, then tweak the numbers as you prefer.*

```csharp
var go = new GameObject("friend");
var sr = go.AddComponent<SpriteRenderer>();          // the "thing that can be drawn"
sr.sprite = Resources.Load<Sprite>("art/friend");    // load (note: no file extension)
go.transform.position = new Vector3(2f, 1f, 0f);     // place (world units, not pixels)
sr.color = new Color(1f, 1f, 1f, 0.8f);              // tint & alpha
```

Why it's the same recipe: `Resources.Load` is the *load* step, `AddComponent<SpriteRenderer>` is the *attach* step, `transform.position` is the *place* step. One difference of accent: Unity positions in metres-ish world units rather than pixels.

Where it lives:
- `SpriteRenderer` — world-space 2D image.
- `UI Image` (on a Canvas) — the UI equivalent.
- `Resources.Load` — simple; `Addressables` — the grown-up loading system for bigger projects.
- `Texture2D.LoadImage(bytes)` — turn raw PNG/JPG bytes into a texture at runtime.

⚠️ **Watch out:** an image file must be marked *Sprite (2D and UI)* in its import settings before `Resources.Load<Sprite>` will find it. This one checkbox causes a remarkable share of all Unity beginner despair.

## Unreal — images via UMG or Paper2D

*Unreal likewise gets explained recipes rather than a bundled project. Both routes below are five-minute experiments in an empty project — try them, tweak, keep whichever feels right.*

Unreal is 3D-first, so "put an image on screen" has two homes:

**UMG (the UI system):**
1. Create a Widget Blueprint → add an **Image** widget.
2. *Set Brush from Texture* (pick your imported texture) — this is the *load + attach* step in one node.
3. *Add to Viewport* — the *place* step (screen-space).

**Paper2D (world sprites):**
- Import PNG → right-click → *Sprite Actions → Create Sprite* → drag into the level, or *Spawn Actor* a `PaperSpriteActor` from Blueprints/C++.

Why it's the same recipe: Unreal just splits *load* between the import step (done once, in the editor) and the brush/sprite assignment (done in code or Blueprint).

⚠️ **Watch out:** Unreal compresses imported textures for 3D by default, which blurs crisp pixel art. On the texture: *Compression → UserInterface2D*, and turn off mipmaps for UI/pixel work.

## Web — the `<img>` element from JavaScript

```js
const img = document.createElement("img"); // the drawable thing
img.src = "art/friend.png";                // load
img.style.position = "absolute";
img.style.left = "240px";                  // place
img.style.top  = "160px";
img.style.opacity = "0.8";                 // alpha (transparency, 0–1)
document.body.append(img);                 // attach
```

DOM images are real page elements: they get accessibility, right-click-save, CSS animation, and layout for free. For dozens of images this is completely fine — whole web-art practices run on nothing else.

## Web — Canvas 2D `drawImage`

A `<canvas>` is a single flat drawing surface you repaint every frame — the closest thing the web has to how game engines actually think.

```js
const ctx = document.querySelector("canvas").getContext("2d");
const img = new Image();
img.src = "art/friend.png";
img.onload = () => {                 // wait for the load step to finish!
  ctx.globalAlpha = 0.8;
  ctx.drawImage(img, 240, 160);      // or (img, x, y, w, h) to scale
};
```

Sprite-sheet frames (many images packed into one) use the 9-argument form of `drawImage`: source rectangle in, destination rectangle out.

⚠️ **Watch out:** the `onload` wait matters. Drawing an image before it finishes loading silently draws *nothing*, with no error. A mysteriously blank canvas? This is the first suspect.

## Web — PixiJS & three.js (when you want an engine's speed)

- [PixiJS](https://pixijs.com/) (free, MIT license) — "sprites, but GPU-fast": thousands of moving images in a browser.
- [three.js](https://threejs.org/) (free, MIT) — full 3D, with a friendly `THREE.Sprite` for billboard images.
- [Phaser](https://phaser.io/) (free, MIT) — a complete game framework in the same family.

```js
// PixiJS v8
const app = new PIXI.Application();
await app.init({ width: 640, height: 360 });
document.body.append(app.canvas);
const tex = await PIXI.Assets.load("art/friend.png"); // load
const s = new PIXI.Sprite(tex);                       // attach
s.position.set(240, 160);                             // place
app.stage.addChild(s);
```

## Generating images from pure code (no file at all)

Every platform lets you build a texture pixel-by-pixel — the foundation of procedural art:

- **Godot:** `Image.create()` → `set_pixel(x, y, color)` in a loop → `ImageTexture.create_from_image()`.
- **Unity:** `new Texture2D(w, h)` → `SetPixel` / `SetPixels32` → `Apply()`. *Try it: a 64×64 texture of `Mathf.PerlinNoise` values is ten lines and instantly satisfying.*
- **Unreal:** `UTexture2D::CreateTransient` + writing the pixel buffer (C++), or draw into a *Render Target* from Blueprints — the friendlier route.
- **Web:** `ctx.createImageData(w, h)` → fill the `data` array (RGBA bytes) → `putImageData`.

💚 "Procedural texture" sounds advanced but is literally two nested loops and a colour decision per pixel. If you can write a times-table loop, you can generate an image. The [sprite basics demo](https://esorhizome.github.io/sparks-and-sprites/sprite-basics.html) does exactly this, in front of you.

---

*Load, attach, place. Four platforms, one recipe — and you now know it in all four accents.*
