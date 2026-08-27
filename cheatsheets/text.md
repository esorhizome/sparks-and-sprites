# Text animation — one page

*Full story: [chapter 13](../chapters/13-text-that-moves.md). Gallery: [the glyph grimoire](https://esorhizome.github.io/sparks-and-sprites/text-fx.html) (104 effects + 104 rhymes, editable). Godot port: `demos/godot/scenes/textfx/` (menu key **D**, right-click a card for its rhyme).*

## The one sentence

Split the phrase into letters, then decide — **per letter, per frame** — four things: **where** it is, **how big**, **what colour**, and **whether it exists yet**.

## The layout pass (do this first, always)

Measure each character; hand out `{ ch, i, x, cx, w, y }` (left edge, centre, width, shared baseline). Every effect is then a loop over that list. Measure, never hard-code — and transform letters about their **centres** (`cx`), not their corners.

## The two-part anatomy (same as buttons & character VFX)

- **living loop** — moves with nobody touching it (flicker, wave, retype-and-rest)
- **press reaction** — one function: replay the arrival, trigger the flourish, aim at the click

## Family → mechanism

| Family | Mechanism (the whole secret) |
|---|---|
| Weight & width | animate font weight 300–700 (variable font; or a fattening stroke); size joins in late |
| Glow & neon | radial gradient behind the text; radius + alpha + flicker = the personality |
| Typewriters | one integer `shown`, a timer, a blinking caret; mood = cadence variance |
| Fades & pulses | per-letter alpha from a sine / stagger / shuffled order |
| Grow & shrink | scale about the phrase centre; envelope = sine (breath), exp (beat), spring (physics) |
| Scrambles | show a WRONG glyph in the RIGHT slot; resolve an index left→right (churn at ~20 fps, slower than frames) |
| Waves & bounces | `y += sin(t − i·phase)`; lean each letter into the slope; squash only at the floor |
| Arrivals | travel from origin → layout slot; arrivals ease OUT, departures ease IN |
| Spins & flips | scale-x = cos(angle) fakes a Y-spin; scale-y = \|cos\| + glyph swap at edge-on = split-flap |
| Ink & colour | colour = f(time, index): hue walks, gleam sweeps, CMY plates drift off register |
| Shakes & glitches | trauma² for quakes; stacked sines for organic jitter; random per frame for electric |
| Strokes & outlines | dash tricks on stroked text: dash length = progress × path (write-on), dash offset (ants) |
| Dust & particles | particles with letter slots as targets; arrival count → letter alpha |
| Depth & shadow | N offset dark copies = extrusion/long shadow; tie offset to a moving light |

## Numbers that keep working

- Typewriter cadence **0.10–0.15 s**/letter; rest **3–4 s** before retyping
- Breathing anything: **±3%** on a **3 s** sine (chapter 06's halo number)
- Pulse floor **0.08** alpha (never truly gone); pulse period **3.5–8 s**
- Churn wrong-glyphs at **0.05 s** steps — readable, not strobing
- Stagger per letter **0.04–0.15 s**; arrival travel **0.5–0.9 s**, ease-out cubic
- Shake by **trauma²**, decay fast; per-letter jitter ≤ **1.5 px** or it's unreadable

## The rhyme rule

Every effect's neighbour is **2–3 dials away** (palette, speed, direction, count). Crescendo→Diminuendo reverses one variable; Matrix rain→Blossom rain flips a fall and warms a palette. Invent #105 by turning a dial nobody turned.

## Feel rules

1. Text's first job is **being read** — perpetual motion for decoration only; arrivals for UI/body text, and they *finish*.
2. Honour reduce-motion: arrivals complete instantly, loops hold steady, presses stay.
3. The **gaps** make it precious: sweeps with pauses, rare failures, long rests.

## Engine spellings (per-letter primitive)

- **Web**: `measureText` + `fillText` per char; weights via variable fonts; dash tricks via `strokeText` + `setLineDash`
- **Godot**: `draw_string`/`draw_char` per char in `_draw()`; UI text: `Label.visible_characters`, RichTextLabel custom BBCode; one weight only → fake bold = `draw_string_outline`
- **Unity**: one TextMesh per letter (code-only), or TMP `textInfo` vertices; `maxVisibleCharacters` = free typewriter
- **Unreal 2D (UMG)**: one TextBlock per letter in a HorizontalBox, animate Render Transform; `SetText(Left(n))`; real font outline settings
- **Unreal 3D**: one `UTextRenderComponent` per letter (`SSTextFx`); ortho camera = 2D look; emissive material + bloom = glow
