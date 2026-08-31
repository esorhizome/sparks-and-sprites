# Flipbook VFX — transparent sprite sheets, the native tongue

A **flipbook** is Unreal's own word for what the rest of the world calls a
sprite sheet: many frames of one animation packed into one texture with a
transparent background, played back by picking which rectangle to show.
Unreal speaks it in three places; knowing which one a job wants is most of
the work. The exact frame maths matches the web folio
(docs/flipbook.html): a loop shows frame `⌊t·fps⌋ mod N`, a one-shot shows
`min(N−1, ⌊(t−t₀)·fps⌋)` with the last frame authored empty.

## Route 1 — Paper2D (the literal flipbook, 2D)

1. Import the sheet PNG (transparent background). In the texture: *Filter*
   **Nearest** for pixel art, *Mip Gen Settings* **NoMipmaps** for UI-scale
   sprites.
2. Right-click the texture → *Sprite Actions* → **Extract Sprites** (grid
   mode: give it the cell size, e.g. 96 × 96).
3. Select all extracted sprites → right-click → **Create Flipbook**. Set
   *Frames Per Second* (the folio's cards run 12–24).
4. Drop the `PaperFlipbook` in the level, or play it from code on a
   `UPaperFlipbookComponent` — `SetLooping(false)` + `PlayFromStart()` is
   the one-shot spelling; `OnFinishedPlaying` is where the poof despawns
   its owner.

## Route 2 — Niagara Sub UV (every particle plays the book, 2D and 3D)

1. Emitter → **Sprite Renderer** → *Sub UV*: set *Sub Image Size* to
   (N, 1) for a one-row sheet.
2. Add **Sub UV Animation** (or drive *SubImage Index* yourself: scale
   0 → N over *Normalized Age*). *Blend* between frames for smoke;
   leave it off for snappy hits.
3. Material: the sheet texture in a **Particle SubUV** sampler (its
   sampler type must be *Linear Color* → *Particle SubUV*), Additive for
   light (bursts, novas), Translucent for matter (poofs, dust).
4. One emitter + one burst of 1 particle = a placed one-shot VFX; spawn
   rate 20 with random SubImage start = a crowd of them.

## Route 3 — material SubUV (the sheet on anything)

`SubUV_Function` (engine content) takes the texture, *Rows/Columns*, and a
*Frame* scalar, and hands back the right rectangle's UVs — put the result
into Emissive (Additive blend, Unlit) and drive *Frame* from a timeline,
a Scalar Parameter, or C++. `Source/.../SSFlipbookVfx.*` is the code side:
it **bakes the sheet itself** into a transient `UTexture2D` at BeginPlay
(no imported asset at all) and steps the *Frame* parameter with the
one-shot index line — the runtime-baked end of the vocabulary.

## The values the folio uses

| Family | frames × fps | blend | note |
|---|---|---|---|
| Glow & flame loops (Aura, Flame…) | 12–16 × 12–16 | Additive | phase on `i/N`, never `i/(N−1)` — the seam vanishes |
| Hits (Burst, Impact, Nova…) | 8–12 × 18–24 | Additive | brief reads as strong; last frame empty |
| Smoke & dust (Poof, Dustkick…) | 10 × 15 | Translucent | matter must not glow — don't use Additive here |
| Magic (Lightning, Zap…) | 10–12 × 18–24 | Additive | re-roll the noise per frame — flicker reads as energy |
| Speech (Confetti, Question…) | 12–14 × 15 | Translucent | paper and ink; a UMG Image can play these too |

## The 2D spelling

Routes 1 is *already* 2D; routes 2 and 3 work under an orthographic camera
unchanged (Niagara and materials read UVs and floats — they don't care
about dimension). In UMG, play a sheet on an Image brush by driving the
brush's material (route 3) or, bluntly, by swapping between N imported
frame textures on a timer — that's the same index line wearing widget
clothes.
