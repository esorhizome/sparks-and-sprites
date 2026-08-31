# 01 · First words — the sixteen terms everything else is built from

*These come up constantly. Each one genuinely is just the sentence written here — there is no secret extra meaning that "real programmers" have and you don't. Other chapters re-explain these on the spot whenever they appear, so memorizing this list is optional. It's a reference, not homework.*

---

## Texture
An image after it has been loaded into graphics-card memory. A PNG on disk is a *file*; the moment your engine loads it so it can be drawn, it's a *texture*. Same pixels, new home.

## Sprite
A texture (an image loaded for drawing — see above, and see how quickly that habit starts?) that has been given a position on screen, usually plus size, rotation, and transparency. Texture = the picture. Sprite = the picture, *placed*. Moving a sprite means changing its position numbers. Nothing more mystical than that.

## Material & Shader
A **shader** is a tiny program that runs once per pixel and answers one question: *"what colour is this pixel?"* A **material** is a saved bundle of "use this shader, with these settings." Every glow, dissolve, outline, and tint trick in this book is ultimately a shader answering that one question slightly differently.

## Particle system
A machine that spawns many tiny sprites (placed images — the pattern continues), gives each a starting speed and lifetime, then updates them all every frame. Sparks, rain, smoke, fireflies: all "spawn lots of small things and let simple rules move them."

▶ *See it:* [sparks demo](https://esorhizome.github.io/sparks-and-sprites/sparks.html)

## Tween
Short for "in-be**tween**." You give a start value, an end value, and a duration; the tween fills in every frame between. "Move this from x=0 to x=300 over 0.4 seconds" is one line in every engine in this book.

## Easing
The *shape* of a tween's speed over time. Linear = robotic constant speed. Ease-out = fast start, gentle landing (feels natural). Ease-in-out = gentle at both ends (feels composed). Easing is the single highest-leverage idea in this whole book — it is most of what people mean by "juicy" or "polished" motion. Browse every curve visually at [easings.net](https://easings.net/).

▶ *See it:* [movement personalities demo](https://esorhizome.github.io/sparks-and-sprites/easing-personalities.html)

## Delta time
The time in seconds since the previous frame — usually written `delta` or `dt`. Multiply any per-frame movement by it (`x += speed * delta`) and your motion runs at the same real-world speed on a 30 fps laptop and a 240 fps gaming monitor. Forgetting this is the classic "my game runs fast on my friend's machine" bug.

## Lerp
**L**inear int**erp**olation: `lerp(a, b, t)` returns the value `t` of the way from `a` to `b`, where `t` runs 0→1. `lerp(0, 100, 0.5)` is 50. Works on positions, colours, sizes, volumes — anything numeric. A tween (see four entries up — no need to have retained it) is lerp plus a clock plus an easing curve.

## Alpha
The transparency channel of a colour: 1 (or 255) is solid, 0 is invisible. Fading anything in or out is just tweening its alpha.

## Blend mode
The rule for how a sprite's colours combine with whatever is already drawn behind it. **Normal** covers. **Additive** adds brightness — the universal "this is made of light" mode used for glows, sparks, and flames. **Multiply** darkens — shadows and stains. One dropdown, enormous mood change.

▶ *See it:* [additive glow demo](https://esorhizome.github.io/sparks-and-sprites/glow-additive.html)

## Sprite sheet / atlas
Many small images packed into one big texture, with the engine told "frame 1 is this rectangle, frame 2 is that one." Used for frame-by-frame animation (a run cycle) and for performance. "Flipbook" is the same idea, said by Unreal people — and [chapter 15](15-transparent-flipbooks.md) turns that one word into a whole VFX toolbox.

## UV coordinates
A position *within* a texture, from (0,0) at one corner to (1,1) at the opposite corner. Shaders (per-pixel colour programs) use UVs to ask "which bit of the image am I colouring right now?" Scrolling a background forever is just adding time to its UVs.

▶ *See it:* [infinite scroll demo](https://esorhizome.github.io/sparks-and-sprites/scroll-uv.html)

## Noise
Smooth, organic randomness — like static that has been blurred into rolling hills. Ordinary random numbers jump wildly; noise *drifts*. It powers flame flicker, water wobble, drifting fog, hand-drawn-feeling shake, and alien wandering. Perlin and Simplex are the two famous recipes; every engine ships one.

## Draw call
One instruction from your code to the graphics card: "draw this batch now." Each has overhead, so 5,000 separately-drawn sprites can stutter while 5,000 batched ones (sharing a texture and material) fly. This is why atlases exist and why particle systems are fast.

## Z-order / layers
Who draws on top of whom. Every engine gives you a number or a named layer for this; every "my character is behind the tree, wrongly" bug is this number being wrong.

## Seed
The starting number for a random generator. Same seed → the exact same "random" sequence, forever. This is how procedural worlds can be shared as a number ("try seed 4477"), and how you debug randomness: pin the seed and the bug repeats identically.

---

*Those sixteen words are the actual vocabulary barrier between "reading tutorials is exhausting" and "reading tutorials is fine." You've just crossed it — and every later chapter will quietly re-cross it with you.*
