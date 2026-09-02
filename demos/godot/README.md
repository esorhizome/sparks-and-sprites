# Godot demos

1. Install [Godot 4.x](https://godotengine.org/) (free, ~100 MB, no account).
2. Project manager → **Import** → pick this folder's `project.godot`.
3. Press **F5**. Click a demo on the menu (or press its key); **Esc** returns.

Every scene here is a bare `Node2D` (or `Node3D`) with one script; the script
builds the entire demo in `_ready()`. That's deliberate — it means **the
script is the demo**, with nothing hidden in editor panels. Open any `.gd`
file in `scenes/`, read top to bottom, change a number, press F5 again.

Every demo in [the web gallery](https://esorhizome.github.io/sparks-and-sprites/)
has its Godot twin here:

| Demo | Script | Web twin | Book chapter |
|---|---|---|---|
| Sprite basics | `scenes/sprite_basics.gd` | sprite-basics | 02 |
| Movement personalities | `scenes/personalities.gd` | easing-personalities | 05 |
| Sparks | `scenes/sparks.gd` | sparks | 06 |
| Flame | `scenes/flame.gd` | flame | 06 |
| Parallax | `scenes/parallax.gd` | parallax | 04 |
| Infinite scroll | `scenes/scroll_uv.gd` + `shaders/scroll_uv.gdshader` | scroll-uv | 04 |
| Additive glow | `scenes/glow.gd` | glow-additive | 03 |
| Dissolve | `scenes/dissolve.gd` + `shaders/dissolve.gdshader` | dissolve | 03 |
| Sound blips | `scenes/sound_blips.gd` | sound-blips | 07 |
| Trails | `scenes/trails.gd` | trails | 06 |
| Fragmented trails | `scenes/trails_fragments.gd` | trails-fragments | 06, 12 |
| Waterdrops | `scenes/waterdrops.gd` | waterdrops | 06 |
| Halo | `scenes/halo.gd` | halo | 06 |
| Chrome & liquid metal | `scenes/metal_chrome.gd` | metal-chrome | 06 |
| Living buttons | `scenes/glow_buttons.gd` | glow-buttons | 12 |
| Responsive cursor | `scenes/cursor_sparkle.gd` | cursor-sparkle | 12 |
| Starfield & ambience | `scenes/starfield.gd` | starfield | 06 |
| Screen shake | `scenes/shake.gd` | shake | 06 |
| Planet (3D) | `scenes/planet_3d.gd` | three-planet | 11 |
| Orbit & glow (3D) | `scenes/orbit_glow_3d.gd` | babylon-scene | 11 |
| Elemental buttons (all 104) | `scenes/elemental_buttons.gd` + `scenes/elements/` | elemental-buttons | 12 |
| Cube codex (all 104) | `scenes/cube_vfx.gd` + `scenes/cubefx/` | cube-vfx | 06 |
| Glyph grimoire (all 104) | `scenes/text_fx.gd` + `scenes/textfx/` | text-fx | 13 |
| Locomotion lexicon (all 104 + 104 rhymes) | `scenes/locomotion.gd` + `scenes/motion/` | locomotion | 14 |
| Flipbook folio (all 104) | `scenes/flipbook.gd` | flipbook | 15 |
| Flipbook VFX (Godot-only) | `scenes/flipbook_vfx.gd` + `shaders/rim_glow.gdshader`, `shaders/circuit_flow.gdshader` | — | 15 (also 03, 06, 12) |
| Depth atlas (all 104 + 104 rhymes) | `scenes/depth.gd` + `scenes/depth/` | depth | 16 |
| Depth-fade wireframe (3D, Godot-only) | `scenes/depth_wire_3d.gd` + `shaders/depth_fade.gdshader` | — | 16 |

One demo has no web twin: **Flipbook VFX** is a PNG-sequence loop (frames generated in code — swap in your own) wearing rim glow, a breathing aura, a circuit track, an orbiting mote, click-bursts and a right-click light/dark ground swap, all conducted by tweens, timers and signals. Where the folio (key **G**) is the *breadth* demo — 104 baked sheets, and **clicking any card opens it 3.4× larger in the middle of the window** (the big sprite mirrors the card's frames, so the specials show exactly what the small card is doing) — this one (key **H**) is the *depth* demo: one loop, fully dressed. Long-form companion: [`cheatsheets/godot-flipbook-vfx.md`](../../cheatsheets/godot-flipbook-vfx.md).

## The depth atlas, in full

`scenes/depth.gd` (key **J**) pages through the web atlas's eight families —
skies, distance, rounded forms, facets, light sources, volumes near & far,
waves & ribbons, shadows & focus — one file per family in `scenes/depth/`,
eight cards to a page. Click a card to move its light, camera or weather —
and **drag** where the badge says so (the canvas is an invisible slider:
scrub a sunrise, pan a range, swing a lamp round a ball). **Double-click a
card to open it large** in the middle of the window; the painters draw
relative to their stage size, so the big one is the same code at 2.7×.
One card (X·Xenon, a strobe) is **opt-in**: it shows a
"contains flashing light" notice instead of running, until clicked.
**Right-click a card for its rhyme**: here a rhyme is literally a dials swap — every card keeps its numbers in one dictionary
`D`, and the rhyme is the same painter with two or three values changed.

The port turns on one honest fact: **Godot's `_draw()` has no gradient-fill
call.** `scenes/depth/kit.gd` shows the two spellings the whole atlas is
built from — a linear gradient is `draw_polygon` with one colour per vertex
(the GPU interpolates for free), and a radial gradient is a triangle fan
with a bright centre vertex, drawn in one
`RenderingServer.canvas_item_add_triangle_array` call. Push that centre
vertex toward the light and a disc becomes a lit ball — the same offset
trick as the web page. For nodes, `GradientTexture2D` is the zero-code
route.

**Depth-fade wireframe** (key **K**) is the one 3D scene in the set: a line
mesh (a sphere cage with a knot inside) under three materials on keys
1/2/3 — `shaders/depth_fade.gdshader` fading lines with view-space
distance (live as it turns), a per-vertex colour gradient baked into
`ARRAY_COLOR`, and a flat control. Dropping fix 1 onto an existing
wireframe gallery is one line: `mesh_instance.material_override =
depth_fade_material()` — the mesh never changes.

## The bestiary, in full

`scenes/elemental_buttons.gd` is the **complete port of the web page's 104
elemental buttons** — fourteen element families, one GDScript file per
family in `scenes/elements/`, paged by family in the scene (←/→ turns the
page). Every button keeps the same anatomy as the web original: `init()`
seeds state, `tick()` advances it, `draw()` paints it, `press()` reacts.

**A note on capability, since it's worth saying plainly:** nothing in the
web bestiary is beyond Godot. Everything the HTML canvas does — gradients,
additive light, clipping, trails — has a Godot spelling, and where the
spelling differs, the port says so in place:

- canvas radial gradients → layered translucent circles (`elements/kit.gd`);
- the `lighter` composite blend → the same layering, or a
  `CanvasItemMaterial` with `BLEND_MODE_ADD` per node;
- canvas `clip()` → bounded drawing (or a `SubViewport` when you need it);
- trail-by-not-clearing → an explicit history array, redrawn with fading
  alpha — Godot clears every frame, so the trail's memory is made visible.

Those are translations, not compromises: `_draw()` plus plain arithmetic
covers the entire 104.

## The cube codex, in full

`scenes/cube_vfx.gd` is the same treatment for **character VFX**: the web
page's 104 cube effects (firebursts, waterhoses, sky bolts, following
halos, dash afterimages, hit sparks, capes…), fourteen family files in
`scenes/cubefx/`, paged in one scene. `scenes/cubefx/kit.gd` owns the
protagonist — its patrol, shadow, lean, and eyes — and every effect draws
behind it, calls `draw_cube`, then draws in front: the sandwich is the
whole layering system, exactly as on the web page.

## The glyph grimoire, in full

`scenes/text_fx.gd` is the same treatment for **text animation**: the web
page's 104 text effects (typewriters, scrambles, glows, split-flaps,
waves, long shadows…), fourteen family files in `scenes/textfx/`, paged
in one scene. `scenes/textfx/kit.gd` owns the phrase — its per-letter
layout, its glow, its wrong glyphs — and every effect is a loop over the
layout deciding, per letter, *where, how big, what colour, and whether
yet*. Two Godot-specific translations worth knowing (both noted in the
kit): the fallback font has **one weight**, so "bolder" is spelled as a
growing `draw_string_outline` (fake bold); and canvas `clip()` reveals
become alpha ramps or scale-y reveals, named in place wherever they occur.

## The locomotion lexicon, in full

`scenes/locomotion.gd` is the same treatment for **procedural animation
maths**: the web page's 104 movement styles, A to Z four times (springs,
headings and vehicles, steering brains, crowds and fields, paths and
schedules, IK three ways, verlet bodies, walking gaits, and the clock and
camera themselves — two teaching laps and two genre laps), nine family
files in `scenes/motion/`, paged eight cards at a time in one scene.
`scenes/motion/kit.gd` owns the stage, the ground line, the vector
arrows, the mote protagonist, and the small maths drawer (`smooth`,
`noise`, `rng`). Every card is drawn by its own clipping `Painter` node in
**card-local** space (0,0 at the card's corner, exactly like the web
version's canvas coordinates), so the web and GDScript versions of every
formula match line for line. **Right-click any card for its rhyme** — here
a rhyme is literally `D.merge(rhyme.dials)` over the card's dials
dictionary followed by `init()` again: two or three numbers change and
nothing else, which is the whole lesson. Double-click enlarges a card
(the styles are written relative to `b.w × b.h`, so a bigger card is just
a bigger `b`); the drag cards repeat their press while the button is held;
1 / 2 / 4 set the tempo as extra substeps per frame, so springs and
verlet piles stay stable at ×4.

## The flipbook folio, in full

`scenes/flipbook.gd` is the same treatment for **baked VFX**: the web
page's 104 transparent sprite sheets — the alphabet four times over: two
teaching laps (auras, bursts, poofs, magic circles, lightning, confetti;
then afterimages, meteors, jellies, tornados, omens, Zzz's) and two
**genre laps** (sci-fi beams and glitches, fantasy frost and quills,
arcade jackpots and invaders, cozy axolotls and kettles, goofy waddles
and yolks) — ten families paged in window-sized parts in one scene. The
genre laps' special cards use real runtime machinery: per-frame durations
are passed natively to `SpriteFrames.add_frame`, Tempo's three speeds are
three `AnimatedSprite2D`s sharing one `SpriteFrames` at different
`speed_scale`s, Axolotl's synced sparkles reuse lap two's baked Sparkle
sheet (sheets are assets — sharing them is the point), and Beam, Runner,
Waddle, and Teleport drive `frame` by hand to show the start/loop/end
triple, the two-clip atlas, the ping-pong index, and reversed playback. The port
is deliberately end-to-end Godot: each sheet is drawn ONCE into a
`SubViewport` with `transparent_bg`, captured to an `ImageTexture`, sliced
by `AtlasTexture` regions, stacked into `SpriteFrames`, and played by an
`AnimatedSprite2D` — the exact pipeline you'd feed an artist's PNG
sequence, with `_draw()` standing in for the artist. The filmstrip under
each card is the actual baked texture; the amber cell is the frame being
shown. One translation note: canvas radial gradients become layered
translucent circles (as everywhere in these ports), and additive playback
is a per-sprite `CanvasItemMaterial` with `BLEND_MODE_ADD`. No rhymes on
this one: every card's caption already prints its dials (frames × size,
fps, loop/one-shot, blend), and the chapter's tweaking box says which to
turn.

## The rhymes — 312 more effects, one right-click away

Every button in the bestiary, every card in the codex, and every card in
the grimoire hides a **rhyme**:
a secondary offshoot of the original with **two or three dials turned** —
a palette warmed or frozen, a speed halved, a gravity flipped, a count
doubled. **Right-click any card** to swap original ⇄ rhyme (right-click
again to swap back); the caption turns green and names the moved dials.

The point is pedagogical. Each family file `scenes/elements/<family>.gd`
(or `scenes/cubefx/<family>.gd`, or `scenes/textfx/<family>.gd`) has a
sibling `<family>_r.gd` that:

1. preloads the original as `const Base := preload(...)`;
2. declares `const RHYMES := { id: { name, hint } }` for its family;
3. overrides **only the branches whose dials moved** — every other
   `init/tick/press/draw` path falls through to `Base` via the `match`'s
   `_:` arm.

So `fire.gd` vs `fire_r.gd` is a readable diff of exactly what changed:
Candleflame becomes *Ghost candles* by moving the hue and halving the
flicker; Meteor becomes *Rising lanterns* by flipping one direction sign
and dividing a speed by three. A foundational understanding, tweaked ever
so slightly, gives you a similar-yet-different effect — that's the whole
lesson, and the file layout makes it diffable.

The same rhymes exist on the web pages
([elemental-buttons](https://esorhizome.github.io/sparks-and-sprites/elemental-buttons.html),
[cube-vfx](https://esorhizome.github.io/sparks-and-sprites/cube-vfx.html),
[text-fx](https://esorhizome.github.io/sparks-and-sprites/text-fx.html)) —
there the toggle is the "⇄ its rhyme" link on each card.

## Health checks

None of these is a demo — they're how the project verifies itself:

```
godot --headless --path . -s res://smoke_test.gd     # every scene + injected input
godot --headless --path . -s res://bestiary_test.gd  # all 104 buttons + their 104 rhymes: init/tick/press/draw
godot --headless --path . -s res://codex_test.gd     # all 104 cube effects + their 104 rhymes, same regimen
godot --headless --path . -s res://grimoire_test.gd  # all 104 text effects + their 104 rhymes, same regimen
godot --headless --path . -s res://lexicon_test.gd   # all 104 movement styles + 104 rhymes: tick, press, drag, rhyme, enlarge, A-to-Z ×4 census
godot --headless --path . -s res://motion_family_check.gd -- res://scenes/motion/clocks.gd 14   # one lexicon family, originals + rhymes, two sizes
godot --headless --path . -s res://flipbook_test.gd  # all 104 sheets: defs census (A–Z ×4) + the bake→slice→play pipeline + the specials
```
