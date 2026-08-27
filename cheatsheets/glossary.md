# Cheatsheet · Glossary

One line each. Full versions with examples: [chapter 01](../chapters/01-first-words.md).

| Term | One line |
|---|---|
| Texture | An image loaded into graphics-card memory so it can be drawn |
| Sprite | A texture given a position (plus size/rotation/transparency) on screen |
| Shader | A tiny program answering "what colour is this pixel?" per pixel |
| Material | A saved bundle of "this shader, with these settings" |
| Particle system | Spawns many tiny sprites; simple rules move them (sparks, rain, smoke) |
| Tween | Animates a value from A to B over a duration ("in-between") |
| Easing | The shape of a tween's speed: linear / ease-out / ease-in-out… |
| Delta time (`dt`) | Seconds since last frame; multiply movement by it for speed-consistency |
| Lerp | `lerp(a,b,t)` = the value `t` (0–1) of the way from a to b |
| Alpha | Transparency: 1 solid, 0 invisible |
| Blend mode | How a sprite's colours mix with what's behind: normal / additive / multiply |
| Sprite sheet / atlas | Many frames packed into one texture ("flipbook" in Unreal) |
| UV coordinates | Position *within* a texture, (0,0)–(1,1) |
| Noise | Smooth organic randomness — static blurred into rolling hills |
| Environment map | An image of the surroundings that reflective surfaces look reflections up from |
| Matcap | "Material capture" — shading read from a pre-made image by surface direction |
| Metaball | Blobby shapes that merge where their soft fields overlap past a threshold |
| Draw call | One "draw this batch now" instruction to the GPU; fewer = faster |
| Z-order / layers | Who draws on top of whom |
| Seed | Random generator's start number; same seed = same sequence forever |
| Pitch | How high/low a sound is; 2× speed ≈ one octave up |
| Bus / mixer | Named audio channel grouping sounds ("SFX", "Music") for shared volume |
| Spring | A value pulled toward a target with momentum; stiffness + damping = personality |
| Pointer events | The web's unified mouse + pen + finger input events |
| Hotspot | The one pixel of a cursor image that actually points |
| Glyph | One drawn character — the visual form of a letter |
| Baseline | The invisible line letters sit on (descenders hang below it) |
| Tracking / kerning | The little horizontal gaps between letters (overall / per-pair) |
| Variable font | One font file rendering a whole range of weights (300–700…) from one axis number |
| Caret | The text cursor: the blinking block or bar marking where the next letter lands |
