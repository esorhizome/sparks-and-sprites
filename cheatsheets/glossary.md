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
| Seed | Random generator's start number; same seed = same sequence = same world on every machine; `seed + 1` differs (workshop S·Seed) |
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
| Time scale | A multiplier on dt; slow motion is a smaller dt per frame, not more frames (lexicon T·Timescale) |
| Hitstop | Freezing dt to 0 for ~80–120 ms on an impact, so the hit registers (lexicon H·Hitstop) |
| Substep | Running the simulation several times per drawn frame with a smaller dt, for stability and framerate independence |
| Dead zone (camera) | A box inside which the camera does not move; look-ahead shifts it in the direction of travel (lexicon C·Camera) |
| A* | Grid pathfinding: expand the cheapest open cell by `f = g + h` until the goal is reached (lexicon A·Astar) |
| Bézier / Catmull-Rom | Curves from control points: Bézier uses handles (three lerps deep); Catmull-Rom passes through its points |
| Arc-length parametrisation | Re-indexing a curve by distance travelled so motion along it has constant speed |
| Bicycle model | Car steering: `heading += v / wheelbase · tan(steer) · dt` (lexicon V·Vehicle) |
| Differential drive | Tank steering from two track speeds: `v = (vL + vR)/2`, `ω = (vR − vL)/width` (lexicon T·Tank) |
| Dead reckoning | Guessing a remote object's position by extrapolating its last known velocity (lexicon L·Lag) |
| Rubber-banding | A predicted position yanked back to the authoritative one — or race AI that speeds up the trailing racer (lexicon R·Rubberband, K·Kart) |
| Minimum jerk | The smoothest reach: `10k³ − 15k⁴ + 6k⁵`, zero jerk at both ends — why hands look human (lexicon Y·Yank) |
| Soft body | A ring of verlet points held by neighbour springs and an area term, so it wobbles (lexicon J·Jelly) |
| Tripod gait | Six legs stepping in two alternating groups of three (lexicon S·Spider) |
| Aim assist | Reticle friction inside a target's radius plus a pull toward the nearest target (lexicon X·Xhair) |
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
| Gradient | A smooth change of colour across a distance; *linear* along a line, *radial* outward from a centre |
| Colour stop | One (position 0–1, colour) pair on a gradient; the gradient interpolates between stops |
| Depth cue | A flat pattern the eye reads as space: paler = far, shaded = round, shadow = grounded |
| Atmospheric perspective | Far things mixed toward the colour of the air (paler, bluer, lower contrast) — `mix(colour, air, depth)` |
| Terminator | The line on a lit ball where light turns to shadow; where it sits tells you the light's direction |
| Rim light | A bright edge on the side *away* from the viewer's light — a second light behind the subject |
| Specular highlight | The small hot spot where a surface mirrors the light source directly |
| Contact shadow | The tight dark patch where a thing touches the ground; it shrinks and fades as the thing lifts |
| Painter's algorithm | Draw far things first, near things last — overlap does the depth ordering for free |
| Isometric | A 2:1 grid view with no perspective: `x = (ix − iy)·0.866, y = (ix + iy)·0.5 − iz` |
| Depth of field / bokeh | Only one distance is sharp; the rest blurs — the discs of blurred lights are the bokeh |
| Vignette | Darkening toward the edges of the frame; pulls the eye to the centre |
| Vertex colour | A colour stored on each mesh vertex; the GPU interpolates between them (a gradient for free) |
| Depth fade | Mixing a surface toward a far colour by its distance from the camera — fog, per material |
| Coyote time | A grace timer after leaving a ledge (~100 ms) during which a jump still counts; zero it when you jump (lexicon C·Coyote) |
| Jump buffer | A press made just before landing, stored with its time and fired on touchdown if younger than ~100 ms (lexicon J·Jumpbuffer) |
| Variable jump | Hold to keep rising; release while still rising cuts `vy` (×0.3–0.5) or raises fall gravity (lexicon V·Variable) |
| Dead zone (stick) | Ignore a stick under ~0.2 — tested on the vector's length, then rescaled `(len − dz) ÷ (1 − dz)` (lexicon D·Deadzone) |
| Input normalisation | `if len > 1, v /= len` — otherwise a diagonal runs √2 ≈ 41% faster than a straight line (lexicon N·Normalize) |
| Tap / hold / double-tap | One button, three verbs by timing windows: tap < 200 ms, hold > 250 ms, second tap within 250 ms (lexicon M·Multitap) |
| Charge input | Holding fills a power meter by dt; release launches in proportion; a sweet spot near full, and overcharge backfires (lexicon C·Charge) |
| Fling | Release velocity read from a history buffer: `(last − first) ÷ (t_last − t_first)` over the newest ~100 ms (lexicon F·Fling) |
| Swipe | A finger's total delta bucketed into 4 or 8 directions — only if it went far enough, fast enough (lexicon S·Swipe) |
| Motion input (quarter-circle) | Recent stick directions in a ring buffer, matched against ↓ ↘ → inside a short window; then the button fires (lexicon Q·Quartercircle) |
| Virtual joystick | An on-screen stick whose origin is wherever the finger landed: `v = clamp(finger − origin, radius) ÷ radius` (lexicon V·Virtualstick) |
| Mouse-look sensitivity | Yaw and pitch grow by the pointer's delta × a multiplier; pitch clamped to ±85–89°; acceleration off by default (lexicon M·Mouselook) |
| AABB | Axis-aligned bounding box: an unrotated rectangle; two overlap when `a.l<b.r ∧ a.r>b.l ∧ a.t<b.b ∧ a.b>b.t` (lexicon A·Aabb) |
| Least penetration | Resolve an overlap by pushing along whichever axis overlaps least — the shortest way out, never both axes at once (lexicon A·Aabb) |
| Swept AABB / time of impact | Slide the box through its whole step; the first touch is a `t` in 0..1 — go that far, stop (lexicon T·Tunnel) |
| Tilemap collision | Move x and snap out of any solid tile a corner touches, *then* y — one axis at a time (lexicon X·Xaxis) |
| One-way platform | Land only when falling and last frame's feet were above the top; down+jump ignores it for N frames (lexicon O·Oneway) |
| Walkable angle | The steepest slope you can stand on (~45°): `θ = acos(n̂·up)`; steeper, and the body slides down the tangent (lexicon O·Oblique) |
| Step-up | Foot ray blocked and knee ray clear → lift the body onto the kerb; both blocked means a wall (lexicon K·Kerb) |
| Sensor / whisker rays | Short rays down, sideways and up that light `onFloor / onWall / onCeiling` — they report, never push (lexicon W·Whiskers) |
| Broad phase / spatial hash / quadtree | The cheap sift deciding which pairs deserve the real test: bin bodies by grid cell, test only the 3×3 around (lexicon Q·Quadtree) |
| Trigger volume | A zone that reports, never pushes; enter / stay / exit come from comparing `inside` now with last frame's (lexicon V·Volume) |
| Hitbox / hurtbox | The attack's box, alive only on its active frames / the victim's box that can be hit (lexicon I·Iframes) |
| I-frames | Invincibility frames: the hurtbox switches off for a moment after a hit, so one blow costs one heart (lexicon I·Iframes) |
| SAT / OBB | Separating axis theorem for oriented (rotated) boxes: project corners onto each edge normal; a gap anywhere = apart (lexicon O·Obb) |
| Context steering | Score every direction on an interest map and a danger map, then pick the best — smooth, never twitchy (lexicon J·Judge) |
| Flow field | One flood from the goal writes a distance into every cell; a thousand units each walk downhill (lexicon F·Flowfield) |
| Dijkstra map | The same distance grid read both ways: downhill hunts, uphill flees; several goals come free (lexicon D·Dijkstra) |
| Influence map | Each unit paints its threat onto a grid with falloff; the AI reads the sum before it moves (lexicon I·Influence) |
| Behaviour tree (selector / sequence) | Yes/no nodes ticked top-down each frame: a *selector* tries children until one succeeds, a *sequence* until one fails (lexicon N·Nodes) |
| Utility AI | Score every possible action with a response curve of its inputs, take the highest; personality is the curve shapes (lexicon U·Utility) |
| CCD (cyclic coordinate descent) | The third IK: rotate each joint from the tip toward the target, repeat until close; joint limits come free (lexicon R·Robotarm) |
| Cloth constraints | A verlet lattice held by *structural* (neighbour), *shear* (diagonal) and *bend* (every-other) distance constraints, pinned at the top (lexicon C·Cloth) |
| Torque | An off-centre push spins a body: `τ = r × F`, where the lever arm `r` runs from the pivot (lexicon T·Torque) |
| Breakable constraint | A distance constraint that snaps once stretched past a limit — rope links, a bridge plank, a chain (lexicon Y·Yield) |
| Cellular automaton | A grid where each cell applies one neighbour rule per step: sand falls, water levels, caves grow (lexicon S·Sand, workshop C·Caves) |
| Ring buffer | A fixed-size list that overwrites its oldest slot — the memory behind rewinds, flings, decals and trains (lexicon R·Rewind) |
| Fixed timestep / interpolation alpha | Simulate at a steady rate whatever the framerate; draw the last two states blended by `α = accumulator ÷ step` (lexicon X·Xtrapolate) |
| Energy scheduler | Turn order where each actor banks its speed every tick and acts when full — the fast monster acts twice (lexicon I·Initiative) |
| Beat clock | Time counted in beats, `beat = t·bpm/60`; a press is judged by its distance to the nearest beat (lexicon K·Kickdrum) |
| Unscaled time | A clock that keeps ticking while the game's dt is zero — menus, pause effects and music live on it (lexicon P·Pause) |
| Spring arm | A camera held at arm's length on a spring, shortened when a wall gets in the way (lexicon Z·Zenith; Unreal `SpringArmComponent`) |
| Post-process / screen pass | An effect run over the finished frame, not one sprite: read every pixel, change it, write it back (almanac `pix()`, 0.25–0.5 scale) |
| Bayer / ordered dither | A 4×4 threshold matrix per pixel turns brightness into on/off with a crosshatch pattern — the Game Boy look (almanac O·Ordered) |
| Palette quantise | Snap every pixel to the nearest of N chosen colours — a limited palette from any image (almanac Q·Quantise) |
| Palette cycling | Indexed colours shifted one slot per frame, so a still picture appears to flow — waterfalls, lava, fire (almanac C·Cycle) |
| Chromatic aberration | Read red, green and blue from slightly different offsets, growing toward the edges — colour fringes like a cheap lens (almanac X·Xsplit) |
| Gradient map | Each pixel's brightness looks up a colour on a ramp — frozen, petrified or gilded from one sprite (almanac F·Frozen) |
| 9-slice | An image cut into nine regions: corners stay fixed, edges stretch one way, centre both — panels at any size (almanac N·Nineslice) |
| Visibility polygon | Rays to every wall corner (±ε), nearest hits sorted by angle, filled as a fan — the lit region (almanac V·Visibility) |
| Fog of war | A grid of unseen / seen / visible cells under a dark layer; seen stays dim, visible is clear (almanac F·Fogofwar) |
| Decal | A stamp on the world after the fact (bullet hole, splat, footprint), in a ring buffer so the oldest fades (almanac D·Decals) |
| Telegraph | A warning before the attack (white flash, lean back, filling circle) so the hit is fair (almanac T·Tell, A·Aoe) |
| Sub-emitter | A particle that emits particles — a firework's death spawns the burst, a spark trails smoke (almanac S·Subemitter) |
| Object pool | N objects made once and reused through a free list, so effects allocate nothing mid-game (almanac P·Pool) |
| Ghost bar | The health bar's white lagging chunk: red snaps down, white waits ~0.5 s, then drains — the hit stays visible (almanac H·Healthbar) |
| Lookahead scheduler | Every frame, book each note due in the next ~0.1 s on the audio clock — never a frame timer (almanac L·Lookahead) |
| Voice limiting | Cap how many copies of one sound play at once; steal the oldest or quietest (almanac Q·Quota; Godot `max_polyphony`) |
| Haptics | Controller rumble: two motors (low / high) driven by intensity envelopes over time; `gamepad.vibrationActuator` on the web (almanac R·Rumble) |
| Procedural generation | Making places from rules at runtime instead of by hand — a rule, a neighbourhood and a seed (chapter 19, the workshop) |
| Poisson-disc | Scattering where no two points lie within `r`: try ~30 candidates around an active point, keep the first that fits (workshop P·Poisson) |
| Voronoi | Every cell belongs to its nearest seed point; borders appear where "nearest" changes — territories, cracked glass (workshop V·Voronoi) |
| L-system | A string rewritten by a rule each pass, drawn by a turtle: `F` forward, `+ −` turn, `[ ]` branch (workshop L·Lsystem) |
| BSP | Binary space partition: halve the map, halve the halves until room-sized; a room per leaf, corridors between siblings (workshop B·Bsp) |
| Wave function collapse | Every cell starts as "any tile"; collapse the one with fewest options (lowest entropy), strike forbidden tiles from neighbours, repeat (workshop W·Wfc) |
| Autotile bitmask | Sum a wall's wall-neighbours `N=1, E=2, S=4, W=8`; the sum picks the tile (16); 8-bit adds diagonals (47) (workshop A·Autotile) |
| Shuffle bag | Every entry in by weight, shuffled, drawn without replacement — the rare thing is guaranteed once per bag (workshop D·Dice) |
| Pity timer | A rare drop's weight grows with every miss and resets on a hit, so it eventually arrives (workshop D·Dice) |
| Spawn director | A wave curve of intensity over time, rests included, setting how often enemies arrive off-screen (workshop H·Horde) |
| Save migration | A `version` field in every save; on load, default the fields older versions lack and bump the number (workshop S·Save) |
