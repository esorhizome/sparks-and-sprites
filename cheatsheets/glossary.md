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
| Procedural animation | Motion computed at runtime from formulas, not played back from keyframes |
| Vector | An x and a y that together mean "this far, that way" — subtract points to get one |
| Polar coordinates | A point named by (angle, radius); `x = cos(θ)·r, y = sin(θ)·r` converts back |
| atan2 | The inverse-trig function that names the angle from here to there (handles all quadrants) |
| Damping ratio (ζ) | A spring's manners: <1 overshoots, =1 critically damped (no overshoot), >1 sluggish |
| Steering | AI motion as `desired velocity − current velocity`, clamped — banks and drifts like an animal |
| Boids | Flocking from three neighbour averages: separation, alignment, cohesion |
| Inverse kinematics (IK) | "The hand must be here — where do the joints go?" (forward kinematics is the easy other way) |
| Law of Cosines | `cos A = (a²+d²−b²)/2ad` — solves the two-bone elbow triangle exactly |
| FABRIK | IK by sliding joints along lines to bone length, backward pass then forward — no trig |
| Quaternion | Rotation stored as axis + twist in four numbers; blends cleanly where angle triples wobble |
| Slerp | Spherical lerp: blends two rotations along the one shortest arc at constant speed |
| Verlet integration | Physics storing position + last position; the difference IS the velocity |
| Distance constraint | Two points promising to stay a fixed length apart; restored by nudging, half each |
| Impulse | A one-off velocity change (a hit, a blast) — a force is the nagging version |
| Raycast | "Where does this line first hit the world?" — nearest intersection wins |
| Surface normal | "Straight up off the surface": the slope turned 90° (cross product, in 3D) |
| Restitution (e) | Bounciness: speed kept per bounce; height kept is e² |
| Gait | Walking as rules: foot homes, step thresholds, arcs, hips over the planted foot |
| Flipbook | Playing a sprite sheet frame by frame: loop = `⌊t·fps⌋ mod N`, one-shot clamps |
| One-shot | Plays once and holds its last frame — which is baked *empty*, so ending needs no cleanup |
| Premultiplied alpha | Colour stored already ×alpha; a mismatch with the blend mode = dark fringes on fading glows |
| SubUV | Unreal's word for reading one cell of a sprite sheet by offsetting UVs |
| steps() | CSS timing function that jumps in N discrete hops — a flipbook player with no JavaScript |
