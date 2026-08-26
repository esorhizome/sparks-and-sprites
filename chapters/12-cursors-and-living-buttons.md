# 12 · Responsive cursors & living buttons

*Fresh-start note (no memory of other chapters required): a **particle system** spawns many tiny images and moves them with simple rules; **additive blending** is the colour-mixing rule where overlaps get brighter ("made of light"); a **tween** animates a value from A to B over time; **easing** is the speed-shape of that animation; **pointer events** are the web's unified mouse-pen-finger input events. Each is re-mentioned in place.*

---

Interface feedback — glowing buttons, sparkling cursors, trailing comets — sorts into **three species, by *when* they move**:

| Species | Moves… | Examples |
|---|---|---|
| **Static loop** | always, on its own | a button's plasma glow, a breathing ring, a sheen sweep |
| **Motion-reactive** | when the pointer moves | cursor trails, drag sparkles, elements that lean toward the pointer |
| **Action-reactive** | when the player acts | tap pulses, press-pops, rings that spin when touched |

Everything in this chapter is one of the three, or a stack of them — and the best-feeling interfaces stack all three: alive at rest, responsive in motion, grateful when touched.

## Living buttons (static loops)

A button that glows *before* you touch it is running an animation loop that needs no input at all.

- **The plasma underlay:** two or three coloured, blurred light blobs orbiting slowly **behind** the button face, leaking a little past the edges. The face sits on top of its own light, so the label stays readable. On the web this is a pseudo-element behind the button — an animated `conic-gradient` (or a few moving `radial-gradient`s) under `filter: blur(18px)`:

  ```css
  .fancy::before {           /* the plasma lives BEHIND the face */
    content: ""; position: absolute; inset: -8px; z-index: -1;
    background: conic-gradient(from 0deg, #7b8cff, #ff78c8, #78e6dc, #7b8cff);
    filter: blur(18px);
    animation: churn 6s linear infinite;
  }
  @keyframes churn { to { transform: rotate(1turn); } }
  ```

- **The breath:** ±2–5% scale on a 2–4 second sine wave. (The same "it is alive" number as the halo in [chapter 06](06-vfx-cookbook.md).)
- **The sheen sweep:** a narrow bright band crossing the button every few seconds — the travelling glint from the metal entry of [chapter 06](06-vfx-cookbook.md), deployed on UI. A pause between sweeps matters more than the sweep: constant shimmer reads as noise, a sweep every 4–6 seconds reads as precious.

▶ *See it:* [living buttons demo](https://esorhizome.github.io/sparks-and-sprites/glow-buttons.html) — a plasma-underlay button and a ring button, both editable.

- **Godot:** a `Button` with a child glow (additive sprite or shader) driven by a looping `AnimationPlayer`.
- **Unity:** a UI `Image` with an animated material (or a looping DOTween sequence on scale/colour).
- **Unreal:** a UMG widget whose material animates with Time; Widget Animations for the pulse.

## Action-reactive buttons (the thank-you)

The secret of a good tap response is to **add velocity, not set position**. In the demo above, tapping the ring button does `spinVel += 6`, and per-frame friction (`spinVel *= 0.15^dt`) turns that push into a natural, ease-out spin — no easing curve needed, physics *is* the easing. Stack on top:

- a **luminous pulse**: an expanding, fading additive ring born at the button (two lines — radius up, alpha down);
- a **flare**: a brightness value snapped to 1 on press that decays over ~half a second.

The same three lines welcome a press anywhere: cards, list rows, map pins, save slots.

## The elemental button bestiary

The two species above — the static loop and the thank-you — are a recipe, and recipes want variations. The **[elemental button bestiary](https://esorhizome.github.io/sparks-and-sprites/elemental-buttons.html)** is 104 of them: buttons possessed by fire, lightning, water, mercury, frost, stone, wind, light, sparks, deep space, growing things, dubious green liquids, crystal, and whole compressed weather systems. Every one idles with its own loop and answers a press with its own reaction, every one is ~20–35 lines of canvas code you can open in the page's editor, and every one is built from ingredients this book already taught: particles ([chapter 06](06-vfx-cookbook.md)), additive light, gradients, cracks-as-jagged-lines, trails-by-not-clearing, springs and friction ([chapter 05](05-movement-and-personality.md)). None of it is new machinery — it's the same eight tricks wearing 104 costumes, which is the most encouraging thing a demo page can possibly tell you.

▶ *See it:* [the elemental button bestiary](https://esorhizome.github.io/sparks-and-sprites/elemental-buttons.html) — press *Run all*, or wake buttons one at a time. All 104 are also ported to GDScript in the repo's Godot project ([`demos/godot/scenes/elements/`](../demos/godot/scenes/elements/), one file per element family, paged by family in the `elemental_buttons` scene) — same anatomy, different accent.

## Cursor trails (motion-reactive)

A cursor trail is a particle emitter whose position is the pointer. That's the whole secret — the entire [fragmented trails](https://esorhizome.github.io/sparks-and-sprites/trails-fragments.html) recipe from [chapter 06](06-vfx-cookbook.md) with `emitter = pointer`:

- Spawn fragments **by distance moved**, not by time (Unity calls this *Rate over Distance*; Niagara calls it spawn-per-unit) — the trail appears only while moving, which is exactly the responsive feel you want. Dragging in any direction writes a ribbon of fragments behind your finger.
- The fragment is a costume choice: sparkles, stars, petals, embers, tiny winged things flapping away — same lifecycle (born at the pointer, drift, fade, die), different sprite.
- **Web DOM version:** listen to `pointermove`, spawn small absolutely-positioned elements (animate with `transform` + `opacity` only, then remove them), or draw on a full-screen canvas overlay with `pointer-events: none`. The canvas overlay wins the moment you want dozens of fragments per second.

▶ *See it:* [fragmented trails demo](https://esorhizome.github.io/sparks-and-sprites/trails-fragments.html) — move your pointer over the canvas and the comet is yours.

## Replacing the cursor itself

The many ways to deploy a custom cursor, cheapest first:

1. **A static image** — web: `cursor: url(hand.png) 4 4, auto;` (the two numbers are the hotspot, the pixel that actually points). Godot: `Input.set_custom_mouse_cursor(texture)`. Unity: `Cursor.SetCursor(texture, hotspot, mode)`. Zero code beyond the swap, but no animation, and browsers cap the size (~32–128 px depending on platform).
2. **A living replacement** — hide the real cursor and draw your own thing at the pointer position. Web: `cursor: none` on the play area plus a `position: fixed` element (or canvas drawing) following `pointermove`. Godot: `Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)` + a sprite (and particle emitter) moved to the mouse each frame. Unity: `Cursor.visible = false` + a tracked UI element. Unreal: `SetMouseCursorWidget()` — a full animated UMG widget *as* the cursor.
3. **In-canvas cursors** — on a game canvas you're already redrawing every frame, just draw the cursor **last** so it sits on top.

Two feel-notes worth their weight:

- A hardware (OS-drawn) cursor has zero latency; anything you draw yourself trails it by a frame or two. Fighting that lag looks laggy — **embracing it looks alive**. Let your replacement *chase* the pointer with a little easing (`x += (targetX - x) * 12 * dt`), and the lag becomes personality: a companion, not an arrow.
- Presses deserve an event: a flinch (brief squash), a pop (expanding ring + a small burst of embers), then a spring back to round. All tweens and particles you already know.

▶ *See it:* [responsive cursor demo](https://esorhizome.github.io/sparks-and-sprites/cursor-sparkle.html) — soft circle, sparkle shedding, press-pop.

**Touch screens:** there is no resting cursor on touch — nothing hovers. Pointer events fire all the same on tap and drag, so the same code degrades gracefully: the companion appears under the finger, the trail follows drags, the pop answers taps. Design cursors as **decoration on top of input, never as the only signal** — then touch players lose nothing that matters.

## The kindness checklist

- Wrap decorative loops and trails in `@media (prefers-reduced-motion: no-preference)` — engines: expose a "reduce motion" toggle. The players who need it, really need it.
- **Never hide the cursor without drawing a replacement at least as visible.** A vanished pointer is a bug report, instantly.
- Keep flashing below three flashes per second, always (photosensitivity).
- The **hit target** is not the visual: rings and sparkles may be dainty, the clickable area should stay big and honest.
- Cursor effects run on every pointer move — keep per-move work tiny (spawn a particle, yes; re-layout the page, no).

---

*One taxonomy to keep: alive at rest (loops), responsive in motion (trails), grateful when touched (pulses). Every enchanted interface you've admired is those three, stacked politely.*
