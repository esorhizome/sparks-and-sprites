# Flame — one skeleton, four costumes

Start from the **Fountain** template. The skeleton (= fire's five decisions):

| Decision | Module | Value |
|---|---|---|
| RISE | Add Velocity | up, speed 50–90, cone 8° |
| short lives | Initialize Particle | Lifetime **0.9** |
| SHRINK | Scale Sprite Size | curve 1 → 0 over life |
| FADE | Scale Color | pale yellow `(1, .95, .6)` → orange `(1, .6, .15)` → alpha 0 |
| WOBBLE | Curl Noise Force | strength ~30 |
| ADD | Sprite renderer | **Additive** blend |
| no fall | Gravity Force | **deleted** — fire doesn't fall |

Spawn Rate ~90. That's fire. Then the retunes — change ONLY what's listed:

- **Smoke**: Lifetime 2.4 · speed 20–40 · size curve 0.4 → 1 (*grows*) ·
  colour grey `(0.7, 0.7, 0.75)` fading out · blend **Translucent** —
  smoke is not made of light.
- **Fountain**: Gravity Force back **(0, 0, −340)** · speed 220–300 ·
  cone 8° · Lifetime 1.4 · colour pale blue → deep blue.
- **Ember ring**: add **Shape Location** → Torus/Ring radius ~90, surface
  only · speed 10–30 · Lifetime 1.6 · small sizes.

Same lesson as everywhere else in the book: particles are one recipe with
many dials, and each costume is a handful of dial turns.
