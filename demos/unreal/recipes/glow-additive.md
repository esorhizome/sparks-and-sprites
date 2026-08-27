# Additive glow — light that adds up

1. Material: Blend Mode **Additive**, Shading Model **Unlit**.
2. Base/Emissive Color: a soft radial falloff — RadialGradientExponential
   node (or a soft-dot texture) × your colour.
3. Put it on three overlapping sprites/planes (periwinkle, pink, teal) and
   drift them across each other — where they overlap, the colours SUM
   toward white. That summing is what "made of light" means.
4. Screen-wide glow on top: emissive values **above 1** (HDR) bloom
   automatically — bloom is on by default in Unreal.

Chapter 03 of the book; the halo and flame recipes both lean on this.

## The 2D spelling

Identical material, flatter stage: put the additive material on UMG
**Image** brushes (or Paper2D sprites) and drift them across each other —
UMG composites in screen space, so the summing behaves exactly like the
web canvas's `lighter`. HDR emissive still blooms under an ortho camera;
in pure UMG there is no scene bloom, so fake the halo with an oversized
soft-dot brush behind the bright one (the bestiary's plasma underlay
trick).
