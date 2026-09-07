# Cheatsheet · Collision & contact

Everything = **ask a cheap question about two shapes — do they overlap, and by how much? — then move one the shortest distance that makes the answer no.** Full chapter: [18](../chapters/18-collision-and-contact.md). Live demos: the `contact` family of [the locomotion lexicon](https://esorhizome.github.io/sparks-and-sprites/locomotion.html) (13 cards, each with a rhyme = 26, all editable; Godot menu key F).

**Two halves, kept apart:** *detection* is the question (geometry, never changes); *response* is what you do with a yes (push, remember, trade velocity, take a heart — design, changes constantly).

## Shape → test → resolve, cheapest first

| Card | Shapes | The test | The resolve |
|---|---|---|---|
| A·Aabb | box vs box | `a.l<b.r ∧ a.r>b.l ∧ a.t<b.b ∧ a.b>b.t` | push along the axis of **least penetration** |
| O·Overlap | circle vs circle · circle vs box | `d² < (r₁+r₂)²` · `p = clamp(c, min, max)`, `|c−p| < r` | along the centre line by `r₁+r₂−d` · along `c−p` by `r−|c−p|` |
| T·Tunnel | fast box vs anything | swept AABB: `entry = max(tx₁, ty₁)`, `exit = min(tx₂, ty₂)`; hit ⇔ `entry ≤ exit ∧ 0 ≤ entry ≤ 1` | move by `v·entry`, stop; the entry axis is the normal |
| X·Xaxis | body vs tilemap | move x, sample corner tiles `⌊x/tile⌋`; **then** y | snap to the tile edge on that axis, zero that velocity |
| O·Oneway | feet vs ledge | `vy > 0 ∧ feetLast ≤ top ∧ feet ≥ top ∧ drop == 0` | land on top; down+jump sets `drop = N` frames |
| O·Oblique | body vs slope | `θ = acos(n̂·up)`; walkable ⇔ `θ ≤ maxAngle` | `v = (v·t̂)·t̂` along the tangent; else slide down it |
| K·Kerb | body vs step | foot ray blocked ∧ knee ray clear | lift `y` to the step's top; both blocked = wall |
| W·Whiskers | body vs world | short rays ↓↓ ← → ↑, hit within `len + tol` | none — `onFloor / onWall / onCeiling` lamps |
| Q·Quadtree | many vs many | spatial hash `key = ⌊x/s⌋ + ⌊y/s⌋·cols`; test the 3×3 neighbourhood | none — a broad phase decides who is asked |
| V·Volume | body vs zone | `in` now vs `wasInside` | `enter ⇔ in ∧ ¬was · stay ⇔ in ∧ was · exit ⇔ ¬in ∧ was` |
| I·Iframes | hitbox vs hurtbox | `frame ∈ active ∧ hitbox ∩ hurtbox ∧ ¬invincible` | a hit; hurtbox off for `iframes` frames |
| E·Elastic | ball vs ball | circles, as O | impulse `j = −(1+e)(v_rel·n)/(1/m₁+1/m₂)`; `v₁ += j·n/m₁`, `v₂ −= j·n/m₂` |
| O·Obb | rotated box vs rotated box | **SAT**: project corners onto each edge normal; a gap on any axis ⇒ apart | along the axis with the smallest overlap |

## The load-bearing snippets

```
// AABB overlap + least-penetration push (a, b have l r t b)
hit = a.l < b.r && a.r > b.l && a.t < b.b && a.b > b.t
px = min(a.r - b.l, b.r - a.l);  py = min(a.b - b.t, b.b - a.t)
if (px < py) a.x += (a.x < b.x ? -px : px)  else  a.y += (a.y < b.y ? -py : py)

// circle vs rect: nearest point on the box
px = clamp(cx, r.l, r.r);  py = clamp(cy, r.t, r.b)
dx = cx - px;  dy = cy - py;  hit = dx*dx + dy*dy < rad*rad
// push: along (dx, dy) normalised, by rad - sqrt(dx*dx + dy*dy)

// swept AABB: time of impact in 0..1 (vx, vy = this frame's move)
tx1 = (b.l - a.r) / vx;  tx2 = (b.r - a.l) / vx;  if (vx < 0) swap(tx1, tx2)   // vx = 0 → ±∞
ty1 = (b.t - a.b) / vy;  ty2 = (b.b - a.t) / vy;  if (vy < 0) swap(ty1, ty2)
entry = max(tx1, ty1);  exit = min(tx2, ty2)
hit = entry <= exit && entry >= 0 && entry <= 1;   move by v * entry;  normal = axis of entry

// tilemap: x, then y
x += vx*dt;  for each corner: if solid(floor(cx/T), floor(cy/T)) { snap x to that tile's edge; vx = 0 }
y += vy*dt;  for each corner: if solid(...)                      { snap y to that tile's edge; vy = 0 }

// one-way platform
land = vy > 0 && feetLast <= top && feet >= top && drop == 0     // down+jump: drop = 8

// spatial hash key, then test only the 3x3 neighbourhood
key = floor(x / s) + floor(y / s) * cols
```

## Whiskers, triggers, i-frames — the three flags

`onFloor = rayDown.hit && rayDown.dist <= len + tol` (two down rays, one per foot) · `enter/stay/exit` from one saved `wasInside` · `invincible = iframes` after a hit, counting down each frame while the hurtbox is off.

## Engine spellings

| Idea | Godot | Unity | Unreal |
|---|---|---|---|
| overlap query | `PhysicsDirectSpaceState2D.intersect_shape`, `Area2D` | `Physics2D.OverlapBox` / `OverlapCircle` | `OverlapMultiByChannel` + `FCollisionShape::MakeBox` |
| a body that slides | `CharacterBody2D.move_and_slide()`; `move_and_collide()` → `KinematicCollision2D` | Kinematic `Rigidbody2D` + `Rigidbody2D.Cast` | `UCharacterMovementComponent` |
| floor / wall / ceiling | `is_on_floor()` / `is_on_wall()` / `is_on_ceiling()`, `RayCast2D`, `ShapeCast2D` | `Physics2D.Raycast` + `LayerMask` | `IsMovingOnGround()`, `LineTraceSingleByChannel` |
| sweep / time of impact | `cast_motion` (safe, unsafe); `RigidBody2D.continuous_cd` | `Physics2D.BoxCast` → `RaycastHit2D.fraction`; *Continuous* detection | `SweepSingleByChannel` → `FHitResult.Time`; *Use CCD* |
| tiles | `TileMapLayer` + a `TileSet` physics layer | `TilemapCollider2D` + `CompositeCollider2D` | Paper2D per-tile collision |
| one-way | `CollisionShape2D.one_way_collision`; the tile's *One Way* flag | `PlatformEffector2D` (*Use One Way*) | hand-rolled: a channel toggled with `SetCollisionResponseToChannel` |
| slope / step | `floor_max_angle` (45° default), `floor_snap_length` / step hand-rolled | 2D hand-rolled; 3D `CharacterController.slopeLimit`, `.stepOffset` | `SetWalkableFloorAngle` (≈44.8°), `MaxStepHeight` |
| trigger events | `Area2D.body_entered` / `body_exited`; stay = `get_overlapping_bodies()` | `Collider2D.isTrigger`, `OnTriggerEnter2D` / `Stay2D` / `Exit2D` | `UBoxComponent.OnComponentBeginOverlap` / `EndOverlap` |
| who touches whom | collision **layer** + **mask**; `CollisionShape2D.disabled` | **Layer Collision Matrix**; disabled `Collider2D` | collision **channels**: Ignore / Overlap / Block |
| bounce | `PhysicsMaterial.bounce` | `PhysicsMaterial2D.bounciness` | *Restitution* on a Physical Material |

Godot's `move_and_slide()` is the swept, x-then-y, slope-aware body in one call; Unreal's `FHitResult.Time` is the swept AABB's `entry`, `ImpactNormal` its axis, `PenetrationDepth` its push. Hand-roll each once (40 lines apiece), then read the APIs fluently.

## What goes wrong

sweep fast things or clamp speed below the thinnest wall · resolve x then y, never both at once · merge tile seams (or round the body's corners) against corner catching · one-way needs *last frame's* feet · give sensors a pixel or two of tolerance · never test everyone against everyone past a few dozen bodies · draw the boxes while tuning — a hitbox smaller than the sprite is generosity.

**Free deep dive:** MDN's [2D collision detection](https://developer.mozilla.org/en-US/docs/Games/Techniques/2D_collision_detection) (boxes, circles, SAT pointers, in JS) · Maddy Thorson's [Celeste and TowerFall physics](https://maddythorson.medium.com/celeste-and-towerfall-physics-d24bd2ae0fc5) (x-then-y, one-way ledges, as shipped). The standard reference, Christer Ericson's *Real-Time Collision Detection*, is a paid book.
