# Cheatsheet · Procedural animation & movement maths

Everything = **want − have, closed a little each frame.** Full chapter: [14](../chapters/14-procedural-animation.md). Live demos: [the locomotion lexicon](https://esorhizome.github.io/sparks-and-sprites/locomotion.html) (104 styles A–Z ×4, each with a rhyme = 208, all editable; Godot menu key F).

## The first lap, one line each

| Card | Style | The maths in one breath |
|---|---|---|
| A | Arrive | seek, but desired speed × `min(1, dist/slowRadius)` — brakes before the stop |
| B | Bounce | integrate gravity; at floor `v = −v·e` (restitution); heights shrink by `e²` |
| C | Chase | pursue `prey + preyVel · timeToReach` — one multiply-add of foresight |
| D | Damp | `a = ω²(target−x) − 2ζω·v` · ζ<1 rings, **ζ=1 critical**, ζ>1 sluggish |
| E | Eight | Lissajous: `x = cos(a·t), y = sin(b·t)` — whole-number knots |
| F | Fabrik | IK by sliding joints along lines, backward then forward — zero trig |
| G | Gait | foot homes + step threshold + `sin(kπ)` arcs + hips over planted foot |
| H | Hover | `y = rest + sin(t·2π/period)·amp`; tilt = the cos (derivative) |
| I | Ik | two bones: `cos A = (a² + d² − b²)/2ad` (Law of Cosines); ± = elbow flip |
| J | Jump | pick height first: `v₀ = √(2gh)`; fall gravity ×1.7 for feel |
| K | Knock | impulse = one velocity edit, scaled `1/distance`; verlet: edit the *past* position |
| L | Lerp | constant `move_toward` vs fraction-of-gap `1 − exp(−k·dt)` vs spring |
| M | Magnet | `force = k ÷ d²` (inverse-square), softened; drag so things settle |
| N | Normals | slope m → tangent `(1, m)`, normal `(m, −1)`; 3D uses the cross product |
| O | Orbit | polar→Cartesian: `x = cos(θ)·r, y = sin(θ)·r`; nest frames for moons |
| P | Pendulum | `α = −(g/L)·sin θ` — integrate twice a frame; `sin θ ≈ θ` only when small |
| Q | Quaternion | axis + twist in 4 numbers; **Slerp** = shortest arc, constant speed |
| R | Ragdoll | verlet points + distance constraints (half the error to each end, ×8 rounds) |
| S | Swarm | boids: separation + alignment + cohesion — three neighbour averages |
| T | Tentacle | drag-follow chain: each link at bone length from its parent, per frame |
| U | Undulate | one sine, per-segment **phase offset** `sin(t·f − i·φ)` = a travelling wave |
| V | Vectorfield | a formula `angle(x, y, t)`; riders take the local direction as law |
| W | Wander | jittered target on a circle held ahead — randomness smoothed by geometry |
| X | Xmarks | ray vs segment: one denominator test; keep nearest hit; reflect `v − 2(v·n)n` |
| Y | Yaw | heading += clamped `wrapAngle(atan2 − heading)`; turn radius = speed/turnRate |
| Z | Zigzag | waypoints + easing + corner pauses — the schedule *is* the menace |

## The other three laps — wanted motion → card

**Lap 2 (teaching):** A·Astar · B·Bezier · C·Camera · D·Dash · E·Ease · F·Flee · G·Grapple · H·Hitstop · I·Inertia · J·Jitter · K·Keyframe · L·Lookat · M·Motor · N·Nest · O·Obstacle · P·Path · Q·Queue · R·Rope · S·Substep · T·Timescale · U·Upright · V·Vehicle · W·Weight · X·Xfade · Y·Yank · Z·Zones
**Lap 3 (genre):** A·Asteroids · B·Bullethell · C·Cat · D·Drone · E·Elevator · F·Firefly · G·Ghost · H·Homing · I·Invaders · J·Jelly · K·Kart · L·Lag · M·Mech · N·Ninja · O·Octopus · P·Platform · Q·Quantize · R·Rocket · S·Slime · T·Tractorbeam · U·Ufo · V·Vine · W·Whirlpool · X·Xhair · Y·Yacht · Z·Zap
**Lap 4 (genre):** A·Avalanche · B·Butterfly · C·Conveyor · D·Dragon · E·Echo · F·Frog · G·Grid · H·Herd · I·Idle · J·Juggle · K·Kite · L·Leaf · M·Mirror · N·Newton · O·Orrery · P·Pinball · Q·Quicksand · R·Rubberband · S·Spider · T·Tank · U·Umbrella · V·Volley · W·Worm · X·Xing · Y·Yoyo · Z·Zombies

| I want… | Card | The maths in one breath |
|---|---|---|
| a dash / dodge | D·Dash | burst velocity, `v *= exp(−k·dt)`; afterimages; cancel = a new press |
| a camera that feels good | C·Camera | critically damped follow + look-ahead along velocity + a dead zone |
| slow motion / bullet time | T·Timescale, H·Hitstop | `dt × scale` — not more frames; hitstop = `dt = 0` for ~80 ms |
| the same speed at any fps | S·Substep | `1 − exp(−k·dt)`, or a fixed step with substeps |
| a homing missile | H·Homing | Yaw's turn limit + Chase's lead + a proximity fuse |
| a car / a tank | V·Vehicle, T·Tank | `heading += v/L·tan(steer)·dt` / `ω = (vR − vL) ÷ width` |
| enemies that patrol, notice, chase | Z·Zones | a state machine keyed on distance radii |
| a path through walls | A·Astar | open set, closed set, `f = g + h`; walk the cells |
| a smooth curve through points | P·Path, B·Bezier | Catmull-Rom (through) / Bézier (handles); arc-length for constant speed |
| a rope, a kite, a yo-yo | R·Rope, K·Kite, Y·Yoyo | verlet points + distance constraints ×8; lift ∝ wind·sin(attack) |
| a soft body / jelly | J·Jelly | a ring of verlet points, neighbour springs, an area (pressure) term |
| many legs | S·Spider | Gait's rules per leg, alternating tripods, body = mean of feet |
| a crowd that never collides | X·Xing | time-to-closest-approach; sidestep if under threshold |
| aim assist | X·Xhair | friction inside a target's radius + a pull toward the nearest |
| network lag / rubber-banding | L·Lag, R·Rubberband | interpolate a packet behind, or extrapolate; snap or lerp to the server |
| a Frogger / Pac-Man / Invaders | F·Frog, G·Grid, I·Invaders | grid hops with an arc; lane movement with buffered turns; a formation on a beat |

## The four load-bearing snippets

```
// framerate-proof smoothing (any language)
k = 1 - exp(-rate * dt);  x += (target - x) * k

// the spring-damper (ζ = 1 → critically damped)
v += (w*w*(target - x) - 2*z*w*v) * dt;  x += v * dt

// verlet step (velocity = position - last position)
vel = pos - old;  old = pos;  pos += vel + gravity*dt*dt

// two-bone IK
d = clamp(dist, |a-b|, a+b);  base = atan2(dy, dx)
shoulder = base ± acos((a*a + d*d - b*b) / (2*a*d))
```

```
// a following camera: dead zone, look-ahead, critically damped
want = mote + vel*lookAhead;  if (|want - cam| > deadZone) cam spring→ want (ζ = 1)

// framerate-independent OR framerate-dependent — the whole difference
x += (target - x) * 0.1               // wrong: 10 fps and 60 fps disagree
x += (target - x) * (1 - exp(-k*dt))  // right: identical curves
```

## Enemy brains, cheapest first

sine platform → waypoints + easing → seek/arrive → pursuit (lead the target) → wander rig → force/flow fields → boids. Telegraph everything; turn-rate limits give players counterplay.

## Engine spellings

Godot `atan2 · lerp_angle · move_toward · Quaternion.slerp · intersect_ray` · Unity `Mathf.Atan2 · LerpAngle · SmoothDamp · Quaternion.Slerp · Physics.Raycast` · Unreal `FMath::Atan2 · FInterpTo/VInterpTo · FQuat::Slerp · LineTraceSingleByChannel`. Engines package springs/raycasts/ragdolls — hand-roll once (the lexicon's versions are 20–80 lines), then read the API fluently.

**Free deep dive:** [The Nature of Code](https://natureofcode.com/) — steering, springs, flocking, in friendly JS.
