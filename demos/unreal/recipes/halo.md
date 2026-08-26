# Halo — an additive ring with a ±3% breath

1. A ring texture (or a material: RadialGradientExponential twice, big
   minus small = a ring band) on an **Additive, Unlit** material.
2. Put it on a plane / widget / billboard sprite.
3. The breath: a Timeline (or material Time node) scaling the plane
   **±3% on a 3-second sine** — chapter 06's "it is alive" number: big
   enough to feel, small enough to ignore.
4. Head-halo variant: squash the same ring thin (scale Y ≈ 0.16×), park it
   above a character's head, and give it a slow ±bob. The y-scale is the
   entire costume change.

Emissive above 1 (HDR) lets default bloom carry the glow.
