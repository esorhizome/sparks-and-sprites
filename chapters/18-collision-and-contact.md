# 18 · Collision & contact — what touches what

*Fresh-start note (no memory of other chapters required): a **frame** is one drawn picture, ~60 of them a second; **dt** ("delta time") is the fraction of a second since the last frame; a **vector** is an arrow — an x and a y that together mean "this far, that way"; **velocity** is the vector a thing moves by each second; a **bounding box** is the plain rectangle a game uses to stand in for a sprite, because rectangles are cheap to compare and drawings are not; a **normal** is the arrow pointing straight out of a surface; a **raycast** asks "where does this line first hit something?"; a **tilemap** is a level built from a grid of equal squares. Each is re-mentioned in place.*

---

Everything a game does with movement — [chapter 14](14-procedural-animation.md) — moves a point. Nothing there stops a point from wandering through a wall, because a point has no idea walls exist. **Collision detection** is the code that gives it the idea. It is smaller than its reputation: a *question* with a yes/no answer ("do these two shapes overlap?") and, when the answer is yes, one *number and a direction* ("by this much, that way"). Everything a player experiences as solidity — a floor that holds, a ledge that catches, a crate that shoves back — is that question asked many times a frame, and the answer acted on.

It helps to keep the two halves apart in your head, because engines keep them apart in their menus. **Detection** is the question. **Response** is what you do with a yes: push the shapes apart (a wall), do nothing but remember (a trigger zone), swap some velocity (a billiard ball), or take a heart away (a sword). The question is geometry and never changes between games. The response is game design and never stops changing. The whole chapter is one sentence:

> **Ask a cheap question about two shapes — do they overlap, and by how much? — then move one of them the shortest distance that makes the answer no.**

▶ *See it all:* the **`contact` family** of **[the locomotion lexicon](https://esorhizome.github.io/sparks-and-sprites/locomotion.html)** — 13 live cards, every one editable in the page, every one with a **rhyme** (the same demo with two or three dials turned; the `D = {…}` block at the top of each card holds the dials). The cards draw the question as it is asked: the four edge tests lighting green and red, the nearest point on a rectangle, the swept slab, the sampled corner tiles, the two probe rays, the checked pairs of a broad phase. The same 13 (+13 rhymes) are ported to GDScript in the Godot project ([`demos/godot/scenes/motion/`](../demos/godot/scenes/motion/), menu key **F**; right-click a card for its rhyme).

## Shapes, cheapest first

The order below is the order you should reach for them. Each row is a complete collision system for some game; nothing further down is "the real one".

| I want… | Card | The test | The push |
|---|---|---|---|
| two rectangles that don't pass through each other | **A·Aabb** | all four edge tests pass | along the axis of least penetration |
| round things — a ball on a paddle, a coin on a wall | **O·Overlap** | `d < r₁ + r₂`; for a rectangle, the nearest point | along the line between centres, by the overlap |
| a bullet that never skips a thin wall | **T·Tunnel** | a swept box: time of impact `t` in 0..1 | stop at `t`, before the wall |
| a tiled level the body walks in | **X·Xaxis** | sample the corner tiles, one axis at a time | snap to the tile's edge on that axis |
| a ledge you can jump up through | **O·Oneway** | falling, and the feet were above it last frame | land on its top; otherwise ignore it |
| hills you can walk, cliffs you slide off | **O·Oblique** | the ground's angle against a limit | move along the tangent, or slide down it |
| stairs and kerbs, without a jump | **K·Kerb** | a foot ray blocked, a knee ray clear | lift the body to the step's top |
| an honest `onFloor` / `onWall` | **W·Whiskers** | short rays with a tolerance | none — lamps that other code reads |
| hundreds of bodies without a stutter | **Q·Quadtree** | a spatial hash: same or neighbouring cell? | none — it decides who is worth asking |
| zones that notice you | **V·Volume** | inside now vs inside last frame | none — enter / stay / exit events |
| a sword that hits, a hero who survives | **I·Iframes** | active frames ∩ hurtbox ∩ not invincible | a hit; then the hurtbox switches off a while |
| balls that bounce off each other | **E·Elastic** | circles, as O | trade velocity along the normal, scaled by mass and `e` |
| crates that rotate | **O·Obb** | a gap on any edge normal means apart | along the axis with the smallest overlap |

## Boxes and circles — the question in one breath

**A·Aabb.** An **AABB** (axis-aligned bounding box — a rectangle that never rotates) is four numbers: left, right, top, bottom. Two of them overlap only when all four edge tests pass: `a.l < b.r ∧ a.r > b.l ∧ a.t < b.b ∧ a.b > b.t`. One failing test is a gap, and a gap anywhere is a no. To **resolve**, measure how deep the boxes sit on each axis — `px = min(a.r − b.l, b.r − a.l)`, `py = min(a.b − b.t, b.b − a.t)` — and push along the *smaller* one. That rule, **least penetration**, is why a box clipping the corner of a floor slides up onto it instead of sideways off it.

**O·Overlap.** Circles are cheaper still: they touch when the centres are closer than the radii add up to, `d < r₁ + r₂` (compare `d²` against `(r₁ + r₂)²` and you never take a square root). Push apart along the line between centres by `r₁ + r₂ − d`. A circle against a rectangle is one clamp: the nearest point on the box to the circle's centre is `p = clamp(c, box.min, box.max)`, and the circle overlaps if `|c − p| < r`. The push is along `c − p`, by `r − |c − p|`. That single clamp handles corners, edges and faces without a special case each — which is why it is the second thing to learn.

**T·Tunnel.** A fast box moved one whole step at a time can land entirely on the far side of a thin wall, and the overlap test, asked before and after, says no both times: **tunnelling**. The **swept AABB** asks a better question: *at what fraction of this frame's move would the boxes first touch?* Per axis, the time the leading edge reaches the wall's near edge and the time the trailing edge clears its far edge (`tx₁ = (b.l − a.r) ÷ vx`, `tx₂ = (b.r − a.l) ÷ vx`, swapped when the velocity is negative; the same for y). Then `entry = max(tx₁, ty₁)`, `exit = min(tx₂, ty₂)`, and there is a hit exactly when `entry ≤ exit` and `0 ≤ entry ≤ 1`. Move by `velocity × entry` and stop; the axis that supplied `entry` is the one you hit, so it also hands you the normal. Chapter 14's **X·Xmarks** ray is the same idea with a box instead of a line.

**O·Obb.** Once a rectangle rotates it is an **OBB** (oriented bounding box), and the four edge tests stop meaning anything. The **separating axis theorem (SAT)** replaces them: two convex shapes are apart if and only if there is *some* line along which their shadows don't overlap, and for rectangles the only lines worth trying are the edge normals — two per box, four in all. Project each box's corners onto an axis (a dot product each), keep the min and max as an interval, and if the two intervals have a gap on *any* axis, stop: no collision. If every axis overlaps, the axis with the smallest overlap is the push. It is A·Aabb again with the axes chosen by the shapes instead of the screen.

## Ground — tiles, ledges, slopes, kerbs, whiskers

**X·Xaxis.** A tilemap (the kind [chapter 19](19-worlds-from-arithmetic.md) generates) is a grid of squares, so "which tiles am I touching?" is integer division: `col = ⌊x ÷ tileSize⌋`. The rule that makes it work is to **move one axis at a time**: `x += vx·dt`, sample the tiles under the body's corners, and if any is solid, snap x to that tile's edge and zero `vx`; *then* do the same for y. Resolving both axes in one go leaves the code guessing whether a corner hit was a wall or a floor; two passes make a floor a floor. The card labels each step "x pass" / "y pass" and lights the corner tiles it sampled.

**O·Oneway.** A ledge you can jump up through and land on is a platform that is solid from *one side*. Overlap alone can't say which side, so the rule reads the past: land only when `vy > 0` (falling) **and** the feet were at or above the top *last frame* **and** they are at or below it now. Pressing down + jump sets a `dropFrames` counter, and while it counts down the platforms are ignored. Forget the "last frame" clause and a body rising through the ledge snaps to its top mid-jump.

**O·Oblique.** On a slope the ground has a **tangent** (along it) and a **normal** (straight out of it); chapter 14's **N·Normals** built both from the slope. The slope's angle is `θ = acos(n̂ · up)`. Under a **max angle** the ground is walkable and the body's wish is projected onto the tangent, `v = (v · t̂) · t̂`, so it neither burrows nor floats; over it, the body **slides**, accelerating down the tangent under gravity until a gentler stretch and friction stop it. The angle limit is a design dial, and every engine exposes it by name (below).

**K·Kerb.** A kerb is a wall to a body's feet and nothing to its knees. **Step-up** casts two short rays ahead: one at foot height, one at knee height. Foot ray blocked and knee ray clear means "this is a step" — lift the body to the step's top and carry on walking. Both blocked means a wall. The knee height *is* the tallest step the character can climb, and the card's stairs rise until the last riser is refused.

**W·Whiskers.** `is_on_floor()` is not magic; it is a short ray pointing down. **Whiskers** are a bundle of them — two down (one per foot, so a heel over the edge still counts), one left, one right, one up — each with a small **tolerance** added, so a body a pixel above the ground still reads as grounded. The rays set flags (`onFloor`, `onWall`, `onCeiling`), drawn as lamps, and *the lamps decide the verbs*: jump only when the floor lamp is lit, wall-slide only when the wall lamp is. Chapter 14's **N·Ninja** wall-jump is these lamps with a personality; the mantles, ladders and slides of the lexicon's `verbs` family read the same lamps.

## Who to ask, and what to do when nothing pushes back

**Q·Quadtree.** Testing every body against every other is `n(n − 1) ÷ 2` questions a frame — 780 for forty bodies, 4,950 for a hundred, and it grows with the square. The **broad phase** shrinks that before any real test runs. A **spatial hash** drops each body into a grid cell by `key = ⌊x ÷ s⌋ + ⌊y ÷ s⌋ · cols` and asks only the bodies in the same or the eight neighbouring cells; the card draws the checked pairs as lines and counts them against the all-pairs total. A **quadtree** is the same idea with cells that split where bodies crowd. The cell size `s` is the dial: about one body-diameter is the usual sweet spot.

**V·Volume.** A **trigger volume** is a shape that detects and never responds — a doorway, a checkpoint, a lava pool's edge. Overlap gives you "inside now"; one saved flag, `wasInside`, turns it into three events: `enter ⇔ in ∧ ¬was`, `stay ⇔ in ∧ was`, `exit ⇔ ¬in ∧ was`. Almost every gameplay script is written against those three words, and chapter 14's **Z·Zones** state machine is a set of them keyed by radius.

**I·Iframes.** A **hitbox** is the shape that deals damage; a **hurtbox** is the shape that receives it. Neither is the sprite. The hitbox exists only on the swing's **active frames** — the card counts them on a frame strip — and after a hit the defender's hurtbox switches off for a spell of **invincibility frames** (i-frames), drawn as a flicker: `hit ⇔ frame ∈ active ∧ hitbox ∩ hurtbox ∧ ¬invincible`. Both boxes are usually smaller than the sprites they belong to, on purpose. Chapter 14's **H·Hitstop** is what you play the instant the hit lands.

**E·Elastic.** When *both* shapes move and both should feel the hit, the push becomes an exchange. Along the normal between centres, `n`, with relative velocity `v_rel = v₁ − v₂`, the **impulse** is `j = −(1 + e)(v_rel · n) ÷ (1/m₁ + 1/m₂)`, applied as `v₁ += j·n ÷ m₁` and `v₂ −= j·n ÷ m₂`. `e` is **restitution** — 1 a perfect bounce, 0 clay — and mass decides who moves more. Separate the overlap first, then trade the impulse, or the balls stick. This is chapter 14's **N·Newton** cradle laid on a table.

## The four accents, side by side

The web column is the lexicon, hand-rolled. The other three package almost all of it; the names below are where.

| Idea | Web (the lexicon) | Godot | Unity | Unreal |
|---|---|---|---|---|
| "do these boxes overlap?" | A·Aabb's four tests | `PhysicsDirectSpaceState2D.intersect_shape` (or just `Area2D`) | `Physics2D.OverlapBox` | `OverlapMultiByChannel` with `FCollisionShape::MakeBox` |
| a body that moves and slides | X·Xaxis, W·Whiskers | `CharacterBody2D.move_and_slide()` (set `velocity` first); `move_and_collide()` for one step and a `KinematicCollision2D` back | `Rigidbody2D` (Kinematic) + `Rigidbody2D.Cast` / your own `BoxCast` | `UCharacterMovementComponent` |
| on floor / wall / ceiling | W·Whiskers' lamps | `is_on_floor()` / `is_on_wall()` / `is_on_ceiling()`, `RayCast2D`, `ShapeCast2D` | `Physics2D.Raycast` with a `LayerMask`; `IsTouchingLayers` | `IsMovingOnGround()`, `LineTraceSingleByChannel` |
| a sweep / time of impact | T·Tunnel | `PhysicsDirectSpaceState2D.cast_motion` (safe and unsafe fractions); `RigidBody2D.continuous_cd` | `Physics2D.BoxCast` → `RaycastHit2D.fraction`; `Collision Detection: Continuous` | `SweepSingleByChannel` → `FHitResult.Time`; *Use CCD* on the body |
| tiles as walls | X·Xaxis | `TileMapLayer` with a physics layer on its `TileSet` (paint polygons per tile) | `TilemapCollider2D` + `CompositeCollider2D` (merges squares, kills corner snags) | Paper2D tile sets with per-tile collision |
| one-way platforms | O·Oneway | `CollisionShape2D.one_way_collision` (+ margin); the tile's *One Way* flag; drop through by briefly clearing that layer from the body's mask | `PlatformEffector2D` (*Use One Way*, *Surface Arc*); `Physics2D.IgnoreCollision` to drop | no built-in — a platform channel that blocks only from above, toggled with `SetCollisionResponseToChannel` |
| slope limit | O·Oblique's `maxAngle` | `floor_max_angle` (radians, 45° by default), `floor_snap_length`, `get_floor_normal()` | no 2D property — read the hit normal and decide; 3D `CharacterController.slopeLimit` | `SetWalkableFloorAngle` (≈44.8° by default) |
| step-up | K·Kerb | no property — the two-ray recipe, then `move_and_collide` upward | 3D `CharacterController.stepOffset`; 2D hand-rolled | `MaxStepHeight` |
| a trigger with enter / stay / exit | V·Volume | `Area2D.body_entered` / `body_exited`; stay = poll `get_overlapping_bodies()` | `Collider2D.isTrigger` + `OnTriggerEnter2D` / `Stay2D` / `Exit2D` | `UBoxComponent.OnComponentBeginOverlap` / `EndOverlap`; stay = `IsOverlappingActor` |
| who may touch whom | I·Iframes' switch | collision **layer** (what I am) and **mask** (what I look for); `CollisionShape2D.disabled` for i-frames | the **Layer Collision Matrix** (Project Settings → Physics 2D); a disabled `Collider2D` | collision **channels** with Ignore / Overlap / Block per channel; `SetGenerateOverlapEvents` |
| broad phase | Q·Quadtree | the engine's; you set layers and masks | the engine's | the engine's |
| bounce | E·Elastic | `PhysicsMaterial.bounce` on a `RigidBody2D` | `PhysicsMaterial2D.bounciness` | *Restitution* on a Physical Material |
| rotated shapes | O·Obb | any `Shape2D` rotates with its node | any `Collider2D`; `OverlapBox` takes an angle | any component; sweeps take an `FQuat` |

Two spellings deserve a sentence each. Godot's `move_and_slide()` **is** the swept, axis-separated, slope-aware body of this chapter in one call: it sweeps the shape along `velocity`, slides the remainder along whatever it hits, honours `floor_max_angle`, and fills in the three lamps — so a platformer character in Godot is `velocity.y += g·dt; move_and_slide()` plus your input. Unreal's `FHitResult` is the swept AABB's answer in a struct: `Time` is `entry`, `ImpactNormal` is the axis that supplied it, and `bStartPenetrating` with `PenetrationDepth` is the least-penetration push for the frames when a sweep began already inside something.

## What usually goes wrong

- **Tunnelling.** A thin wall, a fast body, a "before and after" overlap test — and the body is on the other side. Sweep the moving thing (T·Tunnel), or clamp its speed to less than the thinnest wall per frame, or in an engine turn on continuous collision. Bullets and falling things are the usual culprits.
- **Corner catching.** A body running along a floor made of separate tiles snags on the seams, because for one frame the least-penetration axis is x. Move one axis at a time with y after x, or merge the tiles into one shape (`CompositeCollider2D`, a single polygon per row in Godot's tile physics), or round the body's corners.
- **Resolving x and y together.** One combined push from one combined overlap makes floors feel like walls at every corner. Two passes (X·Xaxis) is the fix and it costs nothing.
- **Forgetting last frame's position for one-way platforms.** Without `feetLast ≤ top` a rising body snaps to the ledge it was meant to pass through. The rule needs one remembered number.
- **A sensor tolerance of zero.** `onFloor` that demands exact contact flickers off on slopes, at seams and at rest, and the jump button starts failing "randomly". Give the whiskers a pixel or two of grace (W·Whiskers' `tol`), and the coyote and buffer timers of [chapter 17](17-input-and-intent.md) sit on top of that grace, not instead of it.
- **Testing everyone against everyone.** Fine at forty bodies, a slideshow at four hundred. A spatial hash is twenty lines (Q·Quadtree); engines do this for you the moment you use their bodies.
- **The hitbox is the sprite.** A sword's damage box the size of its drawing feels cheap; a hero's hurtbox the size of their hair feels unfair. Draw the boxes on screen while you tune them — every card here does.

## Feel, restraint, and honesty

- **A hitbox smaller than the sprite is generosity, not a bug.** The player is judging the picture; the code is judging a box. When the two disagree, let the disagreement favour the player: hurtboxes a little smaller than the body, ledge grabs a little wider than the hands, floor whiskers a little longer than the feet.
- **Readable beats exact.** One-way platforms, step-up, slope limits, i-frames — none of them is real physics, and every one of them is a promise to the player about what will and won't catch them. Keep the promises consistent across the whole game before making any of them clever.
- **Detection is geometry; response is design.** Keep them in separate functions from the first day. The question "do we overlap, and by how much?" is the same for a wall, a coin and a fireball; only the second half changes, and you will change it a hundred times.
- **Engines package this — write it once by hand anyway.** `move_and_slide`, `BoxCast`, `SweepSingleByChannel` are the thirteen cards of this chapter with better manners and a decade of edge cases. Having written the four edge tests, the nearest-point clamp and the x-then-y walk once, in forty lines each, is what makes those APIs legible — you will know what `floor_max_angle` is *for*, and what `fraction` is a fraction *of*.

---

*Quick-reference version: [the collision cheatsheet](../cheatsheets/collision.md). The gallery: the `contact` family of [the locomotion lexicon](https://esorhizome.github.io/sparks-and-sprites/locomotion.html) (13 cards + 13 rhymes; Godot menu key F). Kin chapters: [14 · Procedural animation](14-procedural-animation.md) (the movement these shapes stop), [17 · Input & intent](17-input-and-intent.md) (the grace timers that sit on top of the floor lamps), [19 · Worlds from arithmetic](19-worlds-from-arithmetic.md) (where the tilemaps come from). Going deeper, free and legal: MDN's [2D collision detection](https://developer.mozilla.org/en-US/docs/Games/Techniques/2D_collision_detection) (boxes and circles, in plain JavaScript) and Maddy Thorson's [Celeste and TowerFall physics](https://maddythorson.medium.com/celeste-and-towerfall-physics-d24bd2ae0fc5) (the x-then-y walk and one-way ledges, as shipped). Christer Ericson's* Real-Time Collision Detection *is the standard reference, and a paid book.*
