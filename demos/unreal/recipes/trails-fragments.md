# Fragmented trails — spawn by distance moved

The one setting that carries the whole demo: Niagara's
**Spawn Per Unit** module (spawn per distance travelled), instead of Spawn
Rate. Fragments appear only while the emitter MOVES — that's the responsive
feel the web demo teaches.

1. Empty Niagara emitter + sprite renderer (Additive).
2. **Emitter Update → Spawn Per Unit**: ~0.06 spawns/unit.
3. Initialize Particle: Lifetime 0.9, size 2–5, tiny random velocity,
   Gravity Force (0, 0, −40) for the "drop" costume.
4. Scale Color: alpha 1 → 0.
5. Attach to the moving thing (or drive position from the pointer).

Costumes are sprite + colour swaps: ember (orange dot), star (star sprite,
warm yellow), drop (blue, more gravity), sparkle (white cross sprite).
Chapter 12 deploys exactly this as a cursor trail.

## The 2D spelling

**Spawn Per Unit works in any plane** — attach the emitter to a Paper2D
character and fragments shed only while it runs, exactly like the web
demo's cursor. For UMG, spawn pooled Image widgets when the pointer has
moved more than N pixels since the last spawn (that IS spawn-per-unit,
hand-rolled), then let each fall and fade in `NativeTick`.
