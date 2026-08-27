# 13 · Text that moves

*Fresh-start note (no memory of other chapters required): a **glyph** is one drawn character; a **baseline** is the invisible line letters sit on; **kerning/tracking** are the little horizontal gaps between letters; a **tween** animates a value from A to B over time; **easing** is the speed-shape of that animation; a **particle system** spawns many tiny images and moves them with simple rules; **additive blending** is the colour-mixing rule where overlaps get brighter ("made of light"). Each is re-mentioned in place.*

---

Text is the one kind of image every project already has — and the one most projects never animate beyond "appear". This chapter is the encyclopaedia entry for **programmatic text animation**: making a phrase arrive, breathe, glow, scramble, wobble, and misbehave, from code, in all four of the book's accents.

The good news arrives early: **text animation is not a new discipline.** Every effect in this chapter is built from machinery earlier chapters already taught — tweens and easing ([chapter 05](05-movement-and-personality.md)), particles, glow, trails, shake ([chapter 06](06-vfx-cookbook.md)), additive light ([chapter 03](03-combining-vfx-with-sprites.md)). The only genuinely new idea is small enough to fit in one sentence:

> **Split the phrase into letters, and decide — per letter, per frame — four things: where it is, how big it is, what colour it is, and whether it exists yet.**

That sentence is most of text animation. Everything else is costume.

## The universal anatomy

Every effect in this chapter (and all 104 in [the glyph grimoire](https://esorhizome.github.io/sparks-and-sprites/text-fx.html), this chapter's demo gallery) has the same two-part shape as the button bestiary and the cube codex before it:

- a **living loop** — the effect keeps moving with nobody touching it (the glow flickers, the wave rolls, the typewriter types and rests and retypes);
- a **press reaction** — one function that replays the arrival, triggers the flourish, or aims at the click.

And every effect begins with the same first move, the **layout pass**:

```js
// the heart of the whole chapter, in web spelling:
function layout(size) {
  ctx.font = size + "px monospace";
  let x = (W - measureWidth(PHRASE, size)) / 2;   // centre the phrase
  return PHRASE.split("").map((ch, i) => {
    const w = ctx.measureText(ch).width;
    const entry = { ch, i, x, cx: x + w / 2, w, y: BASELINE };
    x += w;
    return entry;
  });
}
```

Measure each character, hand out its slot (`x`, its centre `cx`, its width `w`, the shared baseline `y`), and return the list. From then on **an effect is a loop over that list**. A typewriter draws only letters with `i < shown`. A wave adds `sin(t - i·0.65) · amp` to each `y`. A rainbow sets each letter's hue from `t + i·36`. A scramble draws a *wrong* character in the right slot. Four dials — position, size, colour, existence — and the phrase does anything you like.

Two habits keep the whole chapter honest:

- **Measure, never hard-code.** If every position comes from the layout pass, the same effect works for any phrase, any font size, any canvas — change the string and nothing breaks.
- **Transform about the letter's centre.** To scale or rotate one letter, translate to `(cx, y)`, transform, then draw the glyph offset by `-w/2`. Rotating about a letter's corner looks broken; rotating about its centre looks like typography.

▶ *See it all:* **[the glyph grimoire](https://esorhizome.github.io/sparks-and-sprites/text-fx.html)** — one phrase ("just this"), 104 effects, every one editable in the page. Press *Run all*, or wake one card at a time. The same 104 are fully ported to GDScript in the downloadable Godot project ([`demos/godot/scenes/textfx/`](../demos/godot/scenes/textfx/), menu key **D**).

## The fourteen families

What follows is the encyclopaedia proper: each family's mechanism in plain words, its main dials, and where it leans on earlier chapters. Every named effect is a live card in the grimoire.

### 1 · Weight & width — thin, then bold, then bolder

The least-used dial in beginners' text animation, and the most typographic: animate the **font weight** itself. On the web this is nearly free — variable fonts render real weights from 300 to 700, so *Crescendo* steps a phrase thin → bold → bolder → **bolder-and-slightly-larger** by walking one number up and letting the last quarter also grow the size (and past the font's maximum, a stroked outline of the same colour fattens the glyphs further). *Breathing weight* puts the same number on a sine. *Weight wave* moves a bold "spotlight" through the line — weight as a function of distance-to-the-wave.

- **Dials:** weight (300–700), size, an extra stroke width, horizontal scale (condensed ↔ expanded — *Stretch*).
- **Engine notes:** Godot's fallback font has one weight, so the port spells "bolder" as a growing outline (`draw_string_outline`) — fake bold, the same trick bitmap-font games use, and the honest translation is noted in the file. Unity: swap font assets or scale; TMP has font-weight support per typeface. Unreal 2D (UMG): `FSlateFontInfo` typeface swaps across a variable-font family; 3D: outline material parameter on TextRender.

### 2 · Glow & neon — soft light, hard light, storefront light

Chapter 06's glow, worn by letters. Three sizes of the same trick — *Candleglow* (a soft warm halo with a wick-flicker), *Halo lift* (a moderate cool glow on the ±3% three-second breath), *Supernova* (a glow so big the letters nearly drown, with press-triggered rings) — establish the rule: **the glow is a radial gradient behind the text, and its radius/alpha are the whole personality.** *Neon sign* adds the storefront grammar: stroke + fill in saturated pink, and every so often one letter *buzzes out* — imperfection is what sells neon.

- **Dials:** radius, alpha, palette temperature, flicker speed, failure rate.
- **Engine notes:** web: layered radial gradients under `globalCompositeOperation = "lighter"` (or `shadowBlur` for lazy glow). Godot: layered translucent circles (the kit's `glow`). Unity: additive sprites behind TextMesh, or emission + bloom. Unreal 2D: a blurred duplicate TextBlock or soft-glow brush; 3D: emissive text material — HDR emissive blooms by default.

### 3 · Typewriters — letter by letter, in all the typist's moods

The most-requested text effect in games, and secretly a **one-integer effect**: `shown` counts how many letters exist, a timer increments it, and the caret blinks after the last one. Everything else is mood. *Hesitant typist* randomizes the delays and pauses before words. *Backspace & correct* occasionally types a wrong glyph, notices, and fixes it — three states instead of one. *Dialogue box* is the RPG dialect: a bordered box, a fill-rate in characters per second, a blinking ▼ when done, and — crucially — **press to fast-forward**, because every player everywhere presses.

- **Dials:** cadence (seconds per letter), cadence *variance* (the mood), rest length, caret style.
- **Engine notes:** trivially portable — the reveal is `substr` (one label) or per-letter visibility (split letters). Godot: a `Label` with `visible_characters`, or the grimoire's per-letter draw. Unity: TMP's `maxVisibleCharacters` exists precisely for this. Unreal 2D: `SetText(Phrase.Left(Shown))`; 3D: per-letter `SetVisibility` (see `SSTextFx`).

### 4 · Fades & pulses — breath as opacity

Opacity is the cheapest dial and the most forgiving. *Firefly pulse* is the requested dim-to-visible pulse: one alpha, one slow sine, squared to make the dark linger. *Fade in order* and *Fade lottery* stagger per-letter alphas by index or by shuffled rank. *Fluorescent* is the character actor: erratic stutters, then steady — a timeline, not a curve.

- **Dials:** period, floor (never fully dark?), stagger, order.
- **Engine notes:** everywhere trivial — per-letter colour alpha. The one trap: in engines with real lighting (Unreal TextRender), opaque text materials don't fade; use the translucent text material.

### 5 · Grow & shrink — text that swells, pops, and exhales

Scale, always **about the phrase's centre** (or the letter's). *Heartbeat* is the requested expand-and-shrink: a lub-dub envelope (`exp(-beat·14)` twice) scaling the whole phrase, letter centres spreading with the swell. *Pop-in* gives each letter its own overshoot birth. *Rubber band* is chapter 05's spring verbatim: press yanks scale-y, stiffness and damping bring it home, and width compensates (`1/√sy`) so the "volume" feels conserved.

- **Dials:** amplitude, the envelope's shape (sine = breath, exp = beat, spring = physics), per-letter vs whole-phrase.
- **Engine notes:** all engines scale transforms natively; the only craft is the pivot (baseline-anchored growth reads as "rising", centre-anchored as "swelling").

### 6 · Scrambles & decodes — wrong letters on their way to right ones

The requested `a1h7 8u3d → "just this"` family. The insight: **show a wrong glyph in the right slot** — layout stays fixed, only `ch` lies. *Decoder* churns random glyphs at ~20 fps (slower than the frame rate, so the churn is readable) and advances a `fixed` index left to right. *Slot machine* is the requested glitch-scrolldown: each column is a vertical strip of glyphs scrolling past a window, braking left to right onto the target — the reel's `offset` eases to zero and the strip clips to the letter's cell. *Jumble home* scatters the correct letters at wrong positions and eases them to correct placement (the layout pass provides "home"). *Matrix rain*, *Cipher wheel* (Caesar-stepping to the target), *Number station* — same lie, different alibis.

- **Dials:** churn rate, resolve order and cadence, glyph pool, what the wrong letters look like (colour-coding the unresolved ones teaches the eye where to wait).
- **Engine notes:** any engine that can set a one-character string per slot can do all eight. Godot: `TextKit.scramble()` per letter. Unity: `TextMesh.text` per letter object. Unreal 2D: `SetText` per TextBlock on a churn timer; 3D: `SSTextFx`'s Decoder mode.

### 7 · Waves & bounces — the baseline as a trampoline

Chapter 05's motion vocabulary applied per letter. *Sine wave* offsets each `y` by `sin(t − i·phase)` and — the detail that sells it — **leans each letter into the slope** (`rotate(cos(...)·0.12)`). *Stadium wave* passes a jump (with squash-and-stretch) down the line. *Bounce-in* drops letters with real restitution (three parabolic hops, squash at the floor only). *Jelly* and *Ripple press* aim the wave at the click point — distance-to-front as the displacement.

- **Dials:** amplitude, wavelength (the per-index phase step), travel speed, squash amount.
- **Engine notes:** pure transform math — identical in every engine. The lean matters more than the height; a wave without rotation reads as a spreadsheet.

### 8 · Arrivals — letters travelling to their places

Slide-ins, with the layout pass as the destination. *Roll call* (from the left, staggered, ease-out cubic), *Rain down* (from above with weather-like random stagger), *Compass* (each letter from its own random direction), *Tracking* (the cinematic one: no travel at all — just letter-spacing closing from wide to normal while alpha rises), *Whoosh* (fast, with speed-line streaks and a backward lean during travel).

- **Dials:** origin, stagger, easing (arrival = ease-out; departure = ease-in — things leave accelerating), travel extras (streaks, rotation, blur).
- **Engine notes:** transforms again. Unreal 2D note: per-letter arrivals are why the UMG route wants one TextBlock per letter — a single text block can only arrive whole.

### 9 · Spins & flips — split-flaps, coins, revolving doors

Rotation, plus the 2D trick for 3D turns: **scale-x = cos(angle)** reads as a letter spinning about its vertical axis (*Coin spin* — clamp at 0.05 so it never quite vanishes); **scale-y = |cos|** with a glyph swap at the edge-on frame is a **split-flap board** (*Split-flap*: each slot flips through glyphs until the right one clacks in — the airport-departures version of the slot machine). In real 3D (Unity/Unreal), these become honest rotations at last.

- **Dials:** spin count, axis, settle style (clean ease vs the *Wobbly coin* rattle), flip cadence.
- **Engine notes:** web/Godot: the cos-scale illusion. Unity 3D / Unreal TextRender: `Rotation.Yaw` — real, and it catches light.

### 10 · Ink & colour — rainbows, metals, fires, and misprints

Colour as a function of `(time, index)`. *Rainbow ride* is `hue = t·60 + i·36`. *Gold sheen* sweeps a specular gleam (a Gaussian of distance-to-sweep brightening the metal — chapter 06's glint on letters). *Fire ink* gives each letter a vertical gradient that flickers. *Misprint* is the print-shop lesson: three copies (cyan/magenta/yellow) drawn additively at drifting offsets — in register they sum to white; out of register, the plates show.

- **Dials:** palette, the function's speed and per-index step, gradient direction, offset.
- **Engine notes:** per-letter colour everywhere; per-letter *gradients* are canvas/material territory (Godot's port notes its two-stop approximation in place; Unreal wants a material reading `TexCoord.V`).

### 11 · Shakes & glitches — jitter, corruption, and the settle after

Chapter 06's shake rules, at letter scale. *Earthquake* is trauma² on the whole phrase (shake amount = trauma squared, smooth decay, bold while clenched). *Cold shiver* keeps a 0.5 px ambient tremble with occasional travelling shivers. *RGB split* tears colour channels apart in bursts. *Corruption* swaps letters for blocks and wrong glyphs one frame at a time. *Nervous* is jitter with no randomness at all — stacked sines, which look anxious rather than broken.

- **Dials:** amplitude, smoothness (random per frame = electric; smoothed = organic), what corrupts (position/colour/glyph), decay speed.
- **Engine notes:** the getImageData slice tricks (*Scanline slice*) are canvas-specific; the ports re-spell them as per-letter jolts and say so — a good example of translating the *effect*, not the API.

### 12 · Strokes & outlines — hollow letters, and the pen still writing

Text as line-art. *Pen stroke* writes letters on using a dash trick: a dash as long as `progress × pathLength` with an enormous gap, applied to stroked text, crawls along each glyph's outline like a pen. *Marching ants* animates the dash offset instead. *Hollow to solid* strokes the outlines and then **clips** the fill to a rising level — ink filling a glass. *Strike & fix* draws a strikethrough that thinks better of itself and retracts.

- **Dials:** stroke width, dash pattern, fill level, line positions (under/over/through).
- **Engine notes:** the dash-along-glyph trick is canvas's gift (`setLineDash` on `strokeText`); Godot spells outlines with `draw_string_outline` and re-times the reveal as an outline alpha ramp (noted in the port); Unreal 2D has real font outline settings (`FFontOutlineSettings`) to animate.

### 13 · Dust & particles — letters assembled from, and lost to, sparks

Chapter 06's particles, with letters as sources and targets. *Star assembly* streams motes from the edges to the letter slots; letters fade in as their motes arrive (arrival count → alpha). *Dust burst* explodes the phrase into grains that remember home and reform. *Snow fill* lets weather accumulate on the letters. *Confetti pop* is the celebration preset: a burst, a hop of the phrase, gravity, done.

- **Dials:** particle count per letter, who remembers home, gravity sign, what the grain looks like.
- **Engine notes:** particles-with-targets is the one family where engines beat canvas: Niagara's Point Attraction, Unity's per-particle forces. The grimoire's arrays-of-dictionaries version is deliberately the readable one.

### 14 · Depth & shadow — long shadows, stacked extrusions, moving lights

The 2D spelling of 3D. *Long shadow* stacks nine offset dark copies away from a travelling sun — the shadow wheels and stretches as the sun crosses. *Stack extrude* breathes a 3D thickness (N copies stepping down-right, darker with depth). *Spotlight* hides the phrase in darkness and reveals letters within a wandering pool of light. *Emboss* is two offset copies (light above, dark below — swap to pop it out).

- **Dials:** offset direction and length (tie them to a light's position and everything feels physical), copy count, darkness ramp.
- **Engine notes:** in real 3D this family becomes literal — `SSTextFx`'s StackExtrude trails real components in camera depth, and the spotlight is an actual `UPointLightComponent`. The 2D stacks are the fake; knowing both spellings is the lesson.

## The rhymes — 104 more, two dials away

Every one of the 104 effects hides a **rhyme**: the same effect with two or three dials turned — a palette, a speed, a direction, a count — and *nothing else*. The Crescendo walked downward is the *Diminuendo*; the Typewriter with weight behind it is the *Heavy typewriter*; the Matrix rain warmed and flipped upward is *Blossom rain*. On the web page, click **⇄ its rhyme** on any card and the rhyme's opening comment names exactly which dials moved; in the Godot project, **right-click** any card — each family file has a sibling `*_r.gd` that overrides *only the branches whose dials moved*, so diffing the pair is the whole lesson in file form.

The point is bigger than doubling the catalogue. It's the book's core claim made checkable: **once a recipe is understood, its neighbours are nearly free.** If you can read Fireburst→Frostburst in the codex and Decoder→Encoder here, you can invent effect #105 by turning a dial nobody turned yet.

## Feel, restraint, and reading

Three notes that outrank any individual effect:

- **Text's first job is being read.** Continuous effects (waves, rainbows, jitter) fight reading; arrival effects (typewriters, fades, slides) *finish* and then get out of the way. Decorative phrases can afford perpetual motion; body text and UI labels want arrivals only.
- **Respect `prefers-reduced-motion`** (and its engine-side equivalents — a settings toggle). Arrival effects can complete instantly; glows can hold steady; the phrase must never be *unreadable* because a preference was set. The bestiary's rule holds here: keep the press reactions (the user asked for those), tame the idle loops.
- **The rest is rhythm.** The typewriter that rests 3.5 seconds before retyping, the sheen that sweeps every few seconds *with a pause between*, the neon that fails rarely — the gaps are what make the motion precious. Constant motion is wallpaper.

## The four accents, side by side

How each platform spells "one letter at a time":

| Platform | The per-letter primitive | Where the grimoire's port lives |
|---|---|---|
| **Web canvas** | `ctx.measureText` + `fillText` per char (the kit's `layout()`) | [text-fx.html](https://esorhizome.github.io/sparks-and-sprites/text-fx.html) — all 104 + rhymes, editable |
| **Godot** | `Font.get_string_size` + `draw_string`/`draw_char` per char in `_draw()`; or `Label.visible_characters` / `RichTextLabel` custom BBCode effects for UI text | [`demos/godot/scenes/textfx/`](../demos/godot/scenes/textfx/) — all 104 + rhymes, menu key **D**; `kit.gd` is the layout pass |
| **Unity** | one `TextMesh` per letter (fully code-creatable), or TMP's `textInfo` mesh vertices for production UI | [`TextFx2D.cs`](../demos/unity/Scripts/TextFx2D.cs) (8 equippable effects), [`TextFx3D.cs`](../demos/unity/Scripts/TextFx3D.cs) (depth, real rotation, a following light) |
| **Unreal — 2D** | one `UTextBlock` per letter in a HorizontalBox, animated via Render Transform; `RichTextBlock` decorators; `SetText(Left(n))` reveals | [`recipes/text-fx.md`](../demos/unreal/recipes/text-fx.md) — every family's UMG spelling |
| **Unreal — 3D** | one `UTextRenderComponent` per letter (flat quads in the world; ortho camera = the "2D look") | [`SSTextFx.h/.cpp`](../demos/unreal/Source/SparksAndSprites/SSTextFx.h) — seven modes, BlueprintCallable press |

The deep sameness, one last time: every port begins by measuring the phrase and handing out slots, and every effect is a loop over letters deciding *where, how big, what colour, whether yet*. The accents differ; the sentence doesn't.

---

*Quick-reference version: [the text cheatsheet](../cheatsheets/text.md). The gallery: [the glyph grimoire](https://esorhizome.github.io/sparks-and-sprites/text-fx.html).*
