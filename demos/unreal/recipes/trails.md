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
