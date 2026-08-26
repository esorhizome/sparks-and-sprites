# The elemental button bestiary — the anatomy, in Unreal

Every one of the 104 elemental buttons (web page + full GDScript port in
`demos/godot/scenes/elements/`) has the same two-part anatomy:

- an **idle loop** — runs on its own, forever (alive at rest)
- a **press reaction** — fires once per click (grateful when touched)

In UMG that maps to:

| Anatomy | UMG spelling |
|---|---|
| idle loop | a material on the button's background Image, animated by `Time` — or a looping Widget Animation |
| press reaction | the OnClicked handler: play a one-shot Widget Animation, spawn a Niagara burst, add velocity to a spin float |

Family mechanisms → Unreal tools:

- **Fire / light / plasma glows** → additive materials with `Time`-driven
  radial blobs; HDR emissive for bloom.
- **Lightning bolts / cracks** → a jagged-line texture flipbook, or a
  material with a noise-displaced line; flash = a one-shot animation.
- **Particles** (sparks, bubbles, rain, snow, embers, leaves) → small
  Niagara systems parented to the widget's world-space anchor (or a
  retainer-box material for pure screen-space).
- **Liquid fills / waterlines** → a material: `step(uv.y, level + sin wave)`.
- **Shakes / squashes** → Render Transform driven by trauma² (see
  `SSTraumaShake` for the rule set).
- **Facets / iridescence** → per-pixel materials (hue from two beating
  sine waves — the opal recipe).

Port one button per family first (the Godot sampler order is a good tour:
candleflame, static charge, bubble tank, chrome sweep, frozen core, fault
line, smoke signal, breath, flint, galaxy, swarm, acid bath, facet glint,
monsoon) — after those fourteen, the remaining ninety are dial turns.
