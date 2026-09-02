# 14 · Procedural animation & the maths of movement

*Fresh-start note (no memory of other chapters required): a **frame** is one drawn picture, ~60 of them a second; **dt** ("delta time") is the fraction of a second since the last frame; a **vector** is an arrow — an x and a y that together mean "this far, that way"; a **tween** animates a value from A to B over time; **easing** is the speed-shape of that animation; **keyframes** are hand-placed poses an artist sets at specific times. Each is re-mentioned in place.*

---

**Procedural animation** is animation computed while the game runs, instead of played back from hand-made keyframes. A keyframed jump looks identical every time; a procedural jump is a formula, so it can be higher this time, interrupted mid-air, aimed at a moving platform — and it costs no artist hours, which is why solo developers love it beyond reason. This chapter is the encyclopaedia entry for the *maths* underneath it: every named technique in plain words, and where each one shows up when you move a character or program an enemy.

The good news arrives early, and it is one sentence long:

> **Decide what the thing wants (a target, a height, a heading), measure the gap between wanting and having, and close a fraction of that gap every frame.**

That sentence is most of procedural animation. The rest of the chapter is a tour of the different ways to "close the gap" — each way with its own personality, cost, and name-brand jargon.

▶ *See it all:* **[the locomotion lexicon](https://esorhizome.github.io/sparks-and-sprites/locomotion.html)** — 104 movement styles, A to Z four times, every one editable in the page, and every one with a **rhyme** (the same motion with two or three dials turned — 208 styles in all). Laps one and two teach the machinery; laps three and four are **genre laps** (sci-fi, adventure, action, fantasy, arcade, cozy, minimalist, glitchy, goofy) built to be skimmed like [animate.style](https://animate.style/): recognise the motion you were imagining, open its code, turn its numbers. Press *Run all*, or wake one card at a time; most cards aim at where you click. The same 104 (+104 rhymes) are fully ported to GDScript in the downloadable Godot project ([`demos/godot/scenes/motion/`](../demos/godot/scenes/motion/), menu key **F**; right-click a card for its rhyme).

## The nine kinds of memory

Every movement style in existence stores a different amount of state between frames, and that's the honest way to sort them. The first lap of the lexicon (its original 26) is shown in the last column; the other three laps are mapped in the next section.

| Family | What it remembers | The feel | First-lap cards |
|---|---|---|---|
| **Clocks & circles** | nothing — position is a formula of time | hypnotic, perfectly repeating, undriftable | H · O · E · U · P |
| **Slopes & springs** | a velocity | weighty, breathing, interruptible | L · D · J · B |
| **Headings & vehicles** | an angle, and how fast it may change | banking, turning circles, momentum with a nose | Y |
| **Brains & steering** | a velocity plus an intention | alive, fallible, animal | A · C · W · Z |
| **Crowds & fields** | one rule per body, or one formula per point in space | weather, flocks, formations | M · V · S |
| **Paths, grids & schedules** | a route, and a distance along it | deliberate, on rails, on time | — (lap 2 onward) |
| **Chains & joints** | a list of joint positions | limbed, reaching, grounded | T · I · F · Q |
| **Bodies & ground** | position *and last position* per point | honest physics, comedy, consequence | R · K · X · N · G |
| **Time & cameras** | the clock's own speed, and where the window is | slow motion, hitstop, lag, a camera that breathes | — (lap 2 onward) |

A character can use several at once: the lexicon's walker (**G · Gait**) steers its body with a spring, places its feet with thresholds, flies each step along a parabola, and bends its knees with two-bone IK — four families in one creature.

## The four laps

Lap two adds the concepts the first lap left out — no new families were needed for most of it, which is the quiet point: once the kit exists, another 26 styles is another 26 ideas. Laps three and four are the genre laps: real machinery, but *recognisable as a game thing*, and every caption names the teaching card it borrows from.

| Family | Lap 2 (teaching) | Laps 3–4 (genre) — and what each borrows |
|---|---|---|
| **Clocks & circles** | J·Jitter (white noise vs smooth noise vs sines), N·Nest (nested coordinate frames), X·Xfade (blending two motions) | B·Bullethell (Orbit's polar emit), U·Ufo (Hover + the alien of ch. 05), O·Orrery (Orbit + Nest, Kepler speed), M·Mirror (Eight + Nest, kaleidoscope), I·Idle (Hover, layered), Y·Yacht (Undulate + Normals: tilt = the wave's slope) |
| **Slopes & springs** | D·Dash (burst + exponential decay), E·Ease (five easing curves vs a spring), I·Inertia (friction, three surfaces), W·Weight (mass: `ω = √(k/m)`), Y·Yank (minimum-jerk reach) | U·Umbrella (Weight: terminal velocity from `v²` drag), Q·Quicksand (Inertia + Knock), S·Slime (Bounce + Jump: squash & stretch from velocity), C·Cat (Jump: anticipation then one aimed parabola) |
| **Headings & vehicles** | L·Lookat (smoothed aim inside a cone), U·Upright (an angular spring), V·Vehicle (the bicycle model), M·Motor (rolling: `ω = v ÷ r`) | A·Asteroids (Yaw + Inertia), D·Drone (Damp, tilt = acceleration), T·Tank (Vehicle + Lookat: differential drive), H·Homing (Yaw + Chase, proximity fuse), R·Rocket (Jump: thrust vs shrinking mass), X·Xhair (Arrive + Magnet: aim assist), L·Leaf (Pendulum + Jitter: lift across the face) |
| **Brains & steering** | F·Flee (seek and pursuit times −1), O·Obstacle (whisker avoidance), Z·Zones (a state machine by radius) | G·Ghost (Arrive + Lookat: moves only unseen), T·Tractorbeam (Magnet + Arrive), F·Firefly (Wander + Arrive), B·Butterfly (Jitter + Arrive), Z·Zombies (Arrive + separation), V·Volley (Chase + Jump: solve the landing point) |
| **Crowds & fields** | — | W·Whirlpool (Vectorfield + Magnet), H·Herd (Swarm + Magnet), X·Xing (Obstacle + Arrive: predictive avoidance), I·Invaders (Zigzag: a formation on a beat), C·Conveyor (Vectorfield + Platform) |
| **Paths, grids & schedules** | A·Astar (pathfinding on a grid), B·Bezier (three lerps deep), P·Path (Catmull-Rom, arc-length speed), K·Keyframe (keyframes vs a spring), E·Elevator (a trapezoidal velocity profile) | K·Kart (Arrive + Path: rubber-band AI), F·Frog (Jump + Platform + Nest), G·Grid (Lerp: lane movement, buffered turns), P·Platform (Hover + Zigzag + Jump: inherited velocity), J·Juggle (Jump + Orbit: a schedule of throws) |
| **Chains & joints** | Q·Queue (leader following from a history buffer) | O·Octopus (Tentacle + Undulate + Dash), V·Vine (Tentacle: a chain that grows toward light), D·Dragon (Tentacle + Wander + Undulate), E·Echo (Queue: motion echo), W·Worm (Undulate + Gait: anchor swapping), S·Spider (Gait + Ik: six legs, tripod gait), M·Mech (Gait + Lookat: heavy strides, thump) |
| **Bodies & ground** | G·Grapple (raycast + rope constraint + release), R·Rope (verlet, dragged) | N·Ninja (Jump: wall-jump and wall-slide), J·Jelly (Ragdoll + Knock: a soft body), A·Avalanche (Normals + Motor), K·Kite (Rope + Pendulum: lift), N·Newton (Pendulum + Knock: the cradle), P·Pinball (Xmarks + Knock: flippers and bumpers), Y·Yoyo (Rope + Bounce + Motor) |
| **Time & cameras** | C·Camera (dead zone + look-ahead), H·Hitstop, S·Substep (framerate independence), T·Timescale | L·Lag (snap vs interpolate vs dead-reckon), Q·Quantize (space and time snapped), Z·Zap (a telegraphed teleport), R·Rubberband (client prediction yanked back) |

## Three questions, answered on camera

*(These came up while planning the laps, and each got a card instead of a paragraph.)*

**Is slower motion just more frames?** No — and **T·Timescale** shows it: the same bouncing scene three times at 0.25×, 1×, 2×, with a frame counter under each ticking at the *same* rate. Slow motion is a smaller `dt` handed to the same code, not more drawings; the frames are drawn as often as ever, they just describe less time each. (Animators' "more drawings = slower" is the flipbook world's spelling of the same thing — a baked sheet has no `dt`, so its only dial *is* the drawing count: chapter 15's **T·Tempo**.) The code consequence is in **S·Substep**: anything written as `x += (target − x) · 0.1` per frame changes speed with the framerate, while `1 − exp(−k·dt)` and fixed-step substeps do not — and **H·Hitstop** is the trick of setting `dt = 0` for eighty milliseconds on impact. In engines the global version is one property: Godot `Engine.time_scale`, Unity `Time.timeScale`, Unreal `SetGlobalTimeDilation`; the local versions (a slow-mo bubble, a frozen pair) are `dt × scale` on just those objects.

**Can one thing track another?** Yes, trivially — a position is a variable, and **Q·Queue**, **C·Camera**, **X·Xhair**, and **T·Tractorbeam** are four ways to read one: from the past (a history buffer), smoothed with a dead zone, with friction and magnetism, and as a force. Chapter 15's **A·Axolotl** does it for sprite sheets.

**Can 2D fake perspective?** Yes — that question grew into [chapter 16](16-depth-without-a-third-dimension.md) and [the depth atlas](https://esorhizome.github.io/sparks-and-sprites/depth.html). In the lexicon, **O·Orrery**, **N·Nest**, and **M·Mirror** show the coordinate-space half of the trick: a point described relative to a moving frame, projected onto the page.

## Moving a character — the escalating menu

Six ways to move a player or NPC, cheapest first. Each is a fine place to stop; none is "the real one".

1. **Direct formulas** (clocks & circles). `y = sin(t)` hovers a pickup; polar coordinates (`x = cos(θ)·r, y = sin(θ)·r`) orbit a shield; two sines at different speeds trace a figure-eight boss path (a **Lissajous curve**); a **phase offset** per segment turns one sine into a swimming snake. Nothing is stored, so nothing can drift or crash — these run for a year unattended.
2. **Interpolated following** (the lerp family). Move a fixed step per frame (`move_toward` — robotic, exact), or cover a fraction of the remaining distance (`lerp` smoothing — fast start, feather landing). Write the fraction as `1 − exp(−k·dt)` and it behaves identically at any framerate.
3. **Spring-damper motion.** The equation `acceleration = ω²·(target − x) − 2·ζ·ω·velocity` is a genuine **second-order differential equation**, and games solve it the honest way: add acceleration to velocity, velocity to position, every frame (that adding-up is all "integration" means). ω sets speed; **ζ (the damping ratio)** sets manners — under 1 overshoots and rings, **exactly 1 is critically damped** (fastest possible arrival, zero overshoot — what cameras want), over 1 is sluggish. One equation, every personality between jelly and butler.
4. **Kinematic physics.** Real gravity, designer's numbers: pick the jump height `h` first and launch with `v₀ = √(2·g·h)` — the parabola is then guaranteed to peak exactly there. Games also cheat gravity heavier on the way down (~1.5–2×) because floaty rises with snappy falls *feel* correct even though a physics teacher would object. Restitution (`speed × e` per bounce, so `e²` of the height survives) does bouncing.
5. **Steering** — see the enemies section below; players' AI companions use the same brains.
6. **Constraint physics** (verlet + IK) — see the limbs section. Full ragdolls, climbing hands, foot placement.

## Programming an enemy or obstacle — the brains shelf

Obstacles are motion with a schedule; enemies are motion with an opinion. In escalating cunning:

- **Oscillators** (clocks again): a platform on a sine, a crusher on a cosine with a pause written in, a saw on a figure-eight. Predictability is the *point* — the player learns the rhythm and beats it.
- **Waypoint patrol** (Z · Zigzag): a list of points and a schedule between them. The one craft decision: **easing**. A guard that eases into corners and pauses reads as careful; the same path at constant speed reads as machinery. Same route, different menace.
- **Seek / Arrive** (A): steer toward the target, but scale desired speed down inside a slow radius so arrival is a real stop, not a dart hitting a board. `steering = desired velocity − current velocity` (clamped) is the single most load-bearing subtraction in game AI.
- **Pursuit** (C · Chase): aim where the prey *will* be — `prey position + prey velocity × time-to-reach`. One multiply-add turns a trailing dog into a goalkeeper. (Flee is seek times −1; evade is pursuit times −1.)
- **Wander** (W): the classic Reynolds rig — a circle held out in front, a target jittering along its rim, steering aimed at the target. All the randomness gets smoothed through the circle's geometry, so the motion is aimless but never twitchy.
- **Fields** (M · Magnet, V · Vectorfield): give every point in space an opinion. Inverse-square attraction/repulsion (`force = k ÷ distance²` — gravity's and charge's law) makes magnets, gravity wells, and shove-away auras; a formula `angle(x, y, t)` makes wind, currents, and bullet-hell weather that units simply ride.
- **Flocking** (S · Swarm): three averages over neighbours — push apart when crowded (*separation*), match nearby headings (*alignment*), drift toward the local centre (*cohesion*). Nobody leads; the crowd emerges. Twenty-six lines for a hundred birds.
- **The design note that outranks all of it:** enemies should *telegraph* — the maths above makes motion readable; readable motion is fair. If a heat-seeker uses a turn-rate limit (Y · Yaw), the player can dodge inside its turning circle, and that's not a bug, it's the counterplay.

## Limbs — chains, IK, and why nobody stores angles

A **chain** is points that promise to stay a fixed distance apart. **Inverse kinematics (IK)** is any recipe that answers: *the hand must be here — where do the joints go?* (Forward kinematics is the easy direction: given the angles, where's the hand?) Three recipes cover essentially all of games:

- **Drag-follow** (T · Tentacle): no solving at all. Move the head; walk down the chain placing each link at bone-length from its parent, along the line between them — each placement is one `atan2` and one polar-to-Cartesian conversion. Tails, tentacles, snakes, caterpillars.
- **Two-bone exact** (I · Ik): shoulder, elbow, hand form a triangle with known sides *a* (upper), *b* (forearm), *d* (shoulder→target), and the **Law of Cosines** hands over the shoulder angle: `cos A = (a² + d² − b²) / 2ad`. The `±` on that angle is the **elbow flip** — same hand position, joint bent the other way. Arms, legs, turret linkages; this is also what the lexicon's walker uses for knees.
- **FABRIK** (F): *Forward And Backward Reaching IK.* Pin the hand to the target and drag the chain toward the base (backward pass); re-pin the base and drag back out (forward pass); repeat a few times. Every step is "slide this joint along the line to its neighbour at bone length" — **iterative line-segment positioning and point projection, no trigonometric calls at all**, which is why it's fast, stable, and works for any number of bones. Out-of-reach targets just straighten the chain.

And the 3D rotation footnote every engine will eventually force on you: storing rotation as three angles (yaw, pitch, roll) invites wobbling blends and gimbal lock; a **quaternion** is four numbers naming an axis and a twist, and **Slerp** (spherical lerp) blends two of them along the one shortest arc at constant speed (**Q** shows slerp against naive angle-lerping, side by side). You almost never build quaternions by hand — every engine constructs and slerps them for you — but knowing *why* they exist turns the API from runes into tools.

## Bodies — verlet, impulses, and knowing where the ground is

- **Verlet integration** (R · Ragdoll): store each point's position and *last* position; the difference is the velocity, no velocity variable anywhere. Move by `next = current + (current − previous) + gravity·dt²`. Its superpower: after **distance constraints** shove points around (restore each stick's resting length, half from each end, ~8 rounds), velocity stays consistent automatically. Eleven points and eleven promises make a ragdoll; four points and six promises (four edges, two diagonals — the diagonals are the rigidity) make a crate.
- **Impulses** (K · Knock): a *force* nags every frame; an **impulse** changes velocity once — explosions, hits, knockback. In verlet you apply one by editing the previous position (rewriting the past is legal here). Scale by `1/distance` from the blast and the whole pile reacts proportionally.
- **Raycasts** (X · Xmarks): "where does this line first hit the world?" — in 3D it's the **ray-plane intersection**; in 2D the wall is a line segment and one denominator test per wall answers how far along the ray it lands. Keep the *nearest* hit. Every laser sight, bullet, line-of-sight check, and ground probe is this question asked politely.
- **Normals** (N): the ground's **surface normal** is "straight up off the surface" — the slope direction turned 90°. In 2D, if the terrain's **derivative** (slope) is *m*, the tangent is `(1, m)` and the normal is `(m, −1)` normalized; in 3D the 90° turn is done with the **cross product** of two surface directions. Align a character's up-axis to the normal and wheels, feet, and boss turrets hug their hills. The reflection law bullets and bank shots share: `v′ = v − 2(v·n)n`.

## Gait — walking, the graduation exercise

Procedural walking (**G**) is where the whole chapter meets itself, and it decomposes into five small rules — none clever alone:

1. Each foot owns a **home position** under its hip, *pushed ahead by velocity* (so feet lead the motion instead of dragging).
2. A foot steps only when its home has drifted past a **distance threshold** from where it's planted — and only if the other foot is down (the stance rule that makes it a walk, not a slide).
3. The step flies a **parabolic arc** — `lift = sin(k·π)` over the step's progress — to a landing spot predicted a little ahead.
4. Step *duration* shrinks as speed grows, so **step frequency rises with velocity** on its own; nobody schedules footsteps.
5. The **body is carried by the feet**, not the reverse: height bobs with the step, the torso leans into acceleration, and the hips shift over the planted foot — **centre-of-gravity balancing**, one lerp.

Knees are the two-bone IK from card I. Every studio-grade system — dogs, spiders, mechs — is these five rules with more legs and better manners.

## The vocabulary, decoded

The jargon you'll meet in tutorials and talks, translated once, with the card that shows it moving:

| The phrase you'll hear | What it actually is | See it |
|---|---|---|
| vector math | subtracting points to get "toward", dividing by length for direction, multiplying to pick a speed | A, C, S |
| ray-plane intersection | "where does this line hit that surface?" — one denominator test | X |
| cosine wave trajectories | position as `cos`/`sin` of time; two of them = Lissajous knots | E, H, U |
| foot placement / body offset | homes under hips; the body carried by, and offset from, the feet | G |
| polar coordinates / polar-to-Cartesian | (angle, radius) instead of (x, y); convert with `x = cos(θ)·r, y = sin(θ)·r` | O, T |
| vector angles / forward & inverse trig movement | `atan2` names the angle to a point (inverse); `cos/sin` turn an angle into motion (forward) | Y, O |
| quaternions, Slerp/Lerp curves | axis-plus-twist rotation storage; blending along the shortest arc | Q, L |
| coordinate space transformations | describing a point relative to a moving frame (the moon orbits the mote orbiting the sun) | O, Q |
| geometric constraint solving | "keep these promises about distances" solved by nudging, not by algebra | F, R, T |
| second-order differential equations | acceleration depends on position — springs, pendulums; solved by frame-by-frame adding | D, P |
| spring-damper harmonic motion / critically damped curves | `a = ω²(target−x) − 2ζω·v`; ζ = 1 is the no-overshoot sweet spot | D |
| calculus for velocity/acceleration | velocity is position's derivative; integration is adding it back up each frame | E, J, B |
| verlet integration | position minus last position IS the velocity | R, K |
| distance constraint solvers | restore each stick's length, half from each end, several rounds | R, K, F |
| dynamic impulse forces | one-off velocity edits — hits, blasts, knockback | K, R |
| centre-of-mass balancing | shift the hips over the planted foot | G |
| cross products for surface normals | the 90° turn that makes "up off the ground" from two slopes | N |
| target interpolation | lerp/ease/spring toward where you want to be | L, D, A |
| stance-phase stride timing | one foot down while the other flies; durations from speed | G |
| iterative line-segment positioning / point projection | FABRIK's only move: slide a joint along a line to bone length | F |
| two-joint trigonometric IK / Law of Cosines | the elbow triangle solved exactly | I, G |
| parabolic step curves | `sin(k·π)` lift over the step; quadratic arcs generally | G, J |
| foot-step distance thresholding | step only when the home drifts too far | G |
| velocity-based step frequency | faster walk → shorter step duration, automatically | G |
| relative local-space vector offsets | homes and handles defined relative to the body, not the world | G, W |
| dynamic centre-of-gravity shifts | the lean into acceleration, the bob over the stride | G |

## The four accents, side by side

The maths is engine-agnostic; only the spelling changes accent:

| Idea | Web (the lexicon) | Godot | Unity | Unreal |
|---|---|---|---|---|
| angle to a point | `Math.atan2(dy, dx)` | `atan2(dy, dx)` / `Vector2.angle_to_point` | `Mathf.Atan2` | `FMath::Atan2` |
| framerate-proof lerp | `1 − exp(−k·dt)` | same trick, or `move_toward` | `Mathf.MoveTowards`, `Vector3.SmoothDamp` (a packaged critically-damped spring) | `FMath::VInterpTo` / `FInterpTo` |
| shortest-arc angle blend | `wrapAngle` helper | `lerp_angle` (built in) | `Mathf.LerpAngle` | `FMath::FixedTurn` |
| quaternion blend | the 20-line `slerp` in card Q | `Quaternion.slerp` / `Basis.slerp` | `Quaternion.Slerp` | `FQuat::Slerp` |
| raycast | card X's denominator test | `PhysicsRayQueryParameters2D` + `intersect_ray` | `Physics.Raycast` | `LineTraceSingleByChannel` |
| ground normal | derivative → `(m, −1)` | `RayCast2D.get_collision_normal` | `RaycastHit.normal` | `FHitResult.ImpactNormal` |
| spring-damper | five lines in card D | same five lines (or `spring` in some addons) | `SmoothDamp`, or the five lines | `FMath::CriticallyDampedSmoothing`, spring arms |
| verlet + constraints | cards R and K | same code in `_physics_process`; or hand bodies to the physics engine (`RigidBody2D`) | same, or `Rigidbody` + joints | same, or full physics assets |
| pathfinding | card A·Astar's grid | `AStarGrid2D`, or `NavigationAgent2D` on a navmesh | `NavMeshAgent` | `AIController::MoveTo` on a NavMesh |
| a following camera | card C·Camera | `Camera2D` drag margins + `position_smoothing` | Cinemachine (dead zone, look-ahead built in) | `SpringArmComponent`, camera lag settings |
| time scale / hitstop | cards T and H | `Engine.time_scale`; per-object `dt × scale` | `Time.timeScale` | `SetGlobalTimeDilation`, `CustomTimeDilation` |
| splines | cards B and P | `Curve2D` + `PathFollow2D` (arc-length for free) | `Splines` package | `SplineComponent` |

Note the pattern in the last three rows: engines *package* the fancier maths (raycasts, springs, ragdolls) so you rarely hand-roll it in production — but the hand-rolled versions in the lexicon are 20–80 lines each, and having written one once is what makes the engine's version legible.

## Feel, restraint, and honesty

- **Interruptibility is the whole reason.** The moment a player can steer a jump or cancel a dash, keyframes struggle and formulas shine. If a motion never needs to react, a keyframed clip is fine — use the cheap tool.
- **Springs before easings for things that follow.** An easing needs a start, an end, and a duration — awkward when the target moves. A spring only needs the target *right now*, and reacts mid-flight for free.
- **Respect reduced-motion preferences** (a settings toggle, or the browser's `prefers-reduced-motion`): oscillators can shrink their amplitudes, screen-space consequences (shakes, bounces) can complete instantly. The *simulation* can stay; the garnish should calm down.
- **Readable beats realistic.** The doubled falling gravity, the too-early brake of Arrive, the telegraphed patrol pause — all "wrong" physics, all better games.

---

*Quick-reference version: [the movement-maths cheatsheet](../cheatsheets/procedural-animation.md). The gallery: [the locomotion lexicon](https://esorhizome.github.io/sparks-and-sprites/locomotion.html) (104 styles + 104 rhymes). Kin chapters: [05 · Movement & personality](05-movement-and-personality.md) (easing as character), [06 · The VFX cookbook](06-vfx-cookbook.md) (particles and shake). Going deeper, free and legal: [The Nature of Code](https://natureofcode.com/) — a whole free book on steering, springs, and flocking, in friendly JavaScript.*
