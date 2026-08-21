# Cheatsheet · Images on screen

The recipe everywhere: **load → attach → place.** Full chapter: [02](../chapters/02-images-on-screen.md).

| Platform | Load | Attach | Place |
|---|---|---|---|
| Godot | `load("res://art/x.png")` | `Sprite2D.new()`, `add_child()` | `.position = Vector2(x, y)` |
| Unity | `Resources.Load<Sprite>("art/x")` | `AddComponent<SpriteRenderer>()` | `.transform.position` |
| Unreal | import → texture asset | UMG `Image` widget / `PaperSpriteActor` | *Add to Viewport* / actor transform |
| Web DOM | `img.src = "art/x.png"` | `document.body.append(img)` | `style.left/top` (absolute) |
| Web canvas | `new Image()` + `onload` | — (immediate mode) | `ctx.drawImage(img, x, y)` |
| PixiJS | `await PIXI.Assets.load(...)` | `new PIXI.Sprite(tex)`, `stage.addChild` | `.position.set(x, y)` |

**Tint & alpha:** Godot `modulate` · Unity `SpriteRenderer.color` · Unreal *Color and Opacity* · CSS `opacity`/`filter` · canvas `ctx.globalAlpha`.

**Generate pixels from code:** Godot `Image.create` + `set_pixel` → `ImageTexture` · Unity `Texture2D.SetPixel` + `Apply()` · Unreal render target (BP) / `CreateTransient` (C++) · Web `createImageData` → `putImageData`.

**Classic gotchas:** Unity sprite import type not set to *Sprite (2D and UI)* · canvas draw before `onload` (silently blank) · Unreal default texture compression blurring pixel art (use *UserInterface2D*).
