# Sparks — a one-shot Niagara burst

The same five decisions as the web/Godot/Unity versions, as Niagara modules.

1. **Niagara System** → *New system from template* → **Fountain** (it already
   contains every module we need — we retune, not rebuild).
2. **Emitter Update → Spawn Burst Instantaneous**: Count **48**. Delete
   *Spawn Rate* (a burst, not a stream). Emitter loop: **Once**.
3. **Particle Spawn → Initialize Particle**:
   - Lifetime **1.2**
   - Sprite Size **2–6**
   - Colour `#9BA3F0` (periwinkle)
4. **Add Velocity in Cone**: speed **60–240**, cone angle **40°**, axis up.
5. **Particle Update → Gravity Force**: **(0, 0, −340)** — the fall is what
   makes them sparks.
6. **Scale Color**: alpha curve 1 → 0 over life; drift the colour toward a
   warm ember `(0.84, 0.66, 0.47)` at the end.
7. Renderer: default sprite, **Additive** blend.

Spawn from code / Blueprint at the click position:
`UNiagaraFunctionLibrary::SpawnSystemAtLocation(this, SparksSystem, HitPoint);`

## The 2D spelling

Niagara is dimension-agnostic — the same system works in a Paper2D scene:
zero the cone's X axis (velocity in the Y/Z plane only), set the sprite
renderer's **Sprite Facing** to Custom with the camera's forward, and spawn
at the click's world position under an orthographic camera. For pure UI
(sparks on a button), either the Niagara UI Renderer plugin inside a
widget, or the honest widget version: a pooled panel of small Images whose
positions integrate velocity + gravity in `NativeTick` — the same four
lines of physics the web demo teaches.
