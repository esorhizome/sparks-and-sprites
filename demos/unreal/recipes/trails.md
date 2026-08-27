# Trails — the trail as short-term memory

A trail is remembered positions, drawn with fading width. Unreal's packaged
version is a **Niagara Ribbon**:

1. Niagara System → new emitter → template **Ribbon** (or add a Ribbon
   Renderer to an empty emitter).
2. Spawn Rate ~60 (each particle is one remembered position).
3. Lifetime **0.6** — the memory span.
4. **Initialize Ribbon**: width ~12, taper to 0 at the tail.
5. Colour: periwinkle `#9BA3F0`, alpha 1 → 0 over life. Additive material.
6. Attach the system to anything that moves (or set its position from the
   cursor each tick) — the ribbon remembers the rest.

The chapter-06 lesson holds: the *only* state a trail needs is where it has
recently been.

## The 2D spelling

Ribbons work under an orthographic camera unchanged — attach the system to
a Paper2D character and the ribbon remembers its path in the sprite plane.
The UMG spelling has no ribbons, so write the memory out (the web demo's
actual lesson): a ring buffer of the cursor's last ~12 screen positions,
redrawn each tick as Images (or one `OnPaint` polyline) with width and
alpha fading by age.
