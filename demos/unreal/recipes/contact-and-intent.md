# Contact & intent — input grace and collision, in Enhanced Input and the CharacterMovementComponent

The lexicon's laps five to eight add two families that are not about how a
body *looks* when it moves but about what happens **before** (the code
between the hand and the body: coyote time, buffers, dead zones, gesture
parsers) and **at the edge** (what touches what: boxes, sweeps, one-way
ledges, slopes, sensors, hitboxes). All 26 cards live on
[the web page](https://esorhizome.github.io/sparks-and-sprites/locomotion.html)
and in Godot (`demos/godot/scenes/locomotion/`). Unreal ships more of this
than any other engine in the book — the recipe's job is mostly to say
**which of it is built in, which is a checkbox, and which you still write**.

Two assets carry the input half: an **Input Mapping Context** (IMC — key →
action, with per-mapping *Modifiers* and *Triggers*) and **Input Actions**
(IA — *Value Type* Digital (bool) / Axis1D / Axis2D / Axis3D). The
Blueprint event for an action fires with an **ETriggerEvent** — *Started*,
*Ongoing*, *Triggered*, *Canceled*, *Completed* — and exposes *Action Value*,
*Elapsed Seconds* and *Triggered Seconds*. Those three pins do half this
family for free.

## Input & intent — what is built in

**Modifiers** (on a mapping or on the action; they run in list order):

| Modifier | Properties | What it is on the web page |
|---|---|---|
| **Dead Zone** | *Lower Threshold* 0.2, *Upper Threshold* 1.0, *Type* = **Radial** (2D magnitude, rescaled `(len − lower)/(upper − lower)`), Axial (per axis — the "jump at the edge" discontinuity), Unscaled Radial (5.4+, no rescale) | Deadzone's third treatment. Radial also clamps the vector to length 1 — so a WASD pair mapped to one Axis2D comes out **normalised** (Normalize's lesson) |
| **Negate** | X / Y / Z booleans | flip an axis (S = −W) |
| **Swizzle Input Axis Values** | *Order* YXZ, ZYX… | route a 1D key onto the Y of an Axis2D (W → YXZ) |
| **Scalar** | *Scalar* vector | sensitivity (Mouselook) |
| **Smooth** | none | Mouselook's smoothing (frame-rate independent averaging) |
| **Response Curve – Exponential** | *Curve Exponent* | Mouselook's `accel` dial: 1 = linear, 2 = fine near centre |
| **Response Curve – User Defined** | a *Curve Float* per axis | any hand-drawn response |
| **Scale By Delta Time** | none | turn a held axis into "per second" |

There is no stock **8-way snap** modifier: subclass **Input Modifier** in
Blueprint (right-click Content → Blueprint Class → *Input Modifier*),
override *Modify Raw*, and round `atan2(y, x)` to 45°. Same door for any
custom treatment — `UInputModifier` and `UInputTrigger` are both
Blueprintable.

**Triggers** (an action fires when *any* Explicit trigger passes and every
Implicit one — e.g. Chorded — passes too):

| Trigger | Properties | Card |
|---|---|---|
| **Down** (default) / **Pressed** / **Released** | *Actuation Threshold* 0.5 | plain buttons |
| **Tap** | *Tap Release Time Threshold* 0.2 | Multitap's tap (< `tapMax`) |
| **Hold** | *Hold Time Threshold* 0.5, *Is One Shot* | Multitap's hold (> `holdMin`); with One Shot off it emits *Ongoing* every frame with *Elapsed Seconds* — Charge's fill |
| **Hold And Release** | *Hold Time Threshold* | Charge's release (fires *Triggered* on release if held long enough) |
| **Pulse** | *Trigger On Start*, *Interval* 1.0, *Trigger Limit* 0 | auto-fire while held |
| **Chorded Action** | *Chord Action* (another IA that must be held) | Shift+X style; also "down+jump = drop through" (Oneway) |
| **Combo** (5.3+) | *Combo Actions* list, each with *Time To Press Key*; *Cancel Actions* | Quartercircle's ↓↘→+P, declared instead of parsed — if your version lacks it, the ring buffer below |

Two things Enhanced Input does **not** do: a **double tap** (Multitap's
dash) — use *Combo* with the same action twice, or a timestamp in the
character — and any pointer gesture (Fling, Swipe). The legacy gesture
keys (`Gesture_Flick`, `Gesture_Pinch`, `Gesture_Rotate`; Project Settings →
Input → *Enable Gesture Recognizer*) exist for touch but are coarse; roll
Swipe and Fling from *Input Touch* / *Mouse XY 2D-Axis* deltas.

## The character half — coyote, buffer, variable height

`ACharacter` + `UCharacterMovementComponent` (CMC) give you, out of the box:

- **Variable jump height** = `JumpMaxHoldTime` (Character → *Jump Max Hold
  Time*, e.g. 0.35): while *Jump* is held (up to that long) the CMC keeps
  `Velocity.Z` at `JumpZVelocity`; call **Stop Jumping** on *Completed*.
  Note the model: it *sustains the launch speed*, it does not cut on
  release. For the web page's `cut` version, on release do
  `if (Velocity.Z > 0) Velocity.Z *= cut` on the CMC's *Velocity*, and for
  the `fallG` version set **Gravity Scale** to 2.5 once `Velocity.Z < 0`
  (reset on *Landed*). **Notify Jump Apex** (`bNotifyApex` → event *On
  Reached Jump Apex*) is the clean hook for the swap.
- **Multi-jump** = `JumpMaxCount` (2 = double jump); `JumpCurrentCount`
  reads back.
- Events: **On Landed**, **On Jumped**, **On Movement Mode Changed**
  (Walking ↔ Falling), `IsFalling`, `IsMovingOnGround`.

**Not built in** — two timers in the character Blueprint:

| Card | Build it |
|---|---|
| Coyote | on *On Movement Mode Changed* (Prev = Walking, New = Falling, and *not* because of a jump — check `JumpCurrentCount == 0`): store `LeftGroundTime = Get Game Time in Seconds`. On jump *Started* while `IsFalling`: if `Now − LeftGroundTime < 0.12` → **Launch Character** (0, 0, `JumpZVelocity`), *Z Override* = true, then `JumpCurrentCount = 1`. In C++, cleaner: override `CanJumpInternal_Implementation` to also return true inside the window, and plain `Jump()` works |
| Jumpbuffer | on jump *Started* while `IsFalling` (and past coyote): `PressedTime = Now`. On **On Landed**: if `Now − PressedTime < 0.1` → *Jump*. Free half-version: `bPressedJump` stays true while the key is held, so a *held* key already re-jumps on touchdown; only a *tap* needs the timer. The amber pip = a UMG image whose opacity is `1 − age/buffer` |
| Accelerate | CMC: **Max Acceleration** 2048 (`accel`), **Braking Deceleration Walking** 2048 (`brake`), **Ground Friction** 8, **Use Separate Braking Friction** + **Braking Friction** (the honest brake dial), **Air Control** 0.35 (`airAccel` as a fraction of ground), *Air Control Boost Multiplier / Velocity Threshold*, **Falling Lateral Friction** |
| Charge | *Hold* trigger, One Shot off: *Ongoing* gives *Elapsed Seconds* → fill = `elapsed / max`; *Completed* = release → launch ∝ fill; if `elapsed > max` before release → the stumble (a montage / a flipbook) |
| Multitap | *Tap* and *Hold* triggers on the **same** action; read which fired from the event's *Input Action* + *Triggered Seconds*; double tap: `Now − LastTapTime < dblGap` |
| Virtualstick | built in: Project Settings → Input → Mobile → **Default Touch Interface** = `DefaultVirtualJoysticks` (a *Touch Interface* asset: *Center*, *Visual Size*, *Interaction Size*, *Input Scale*, *Time Until Deactive*) — the floating-origin variant is the `LeftVirtualJoystickOnly` asset's *Preventing Recenter* toggles |
| Mouselook | IMC: `Mouse XY 2D-Axis` → IA_Look (Axis2D, Negate Y) → **Add Controller Yaw Input** / **Add Controller Pitch Input**; pitch clamp = *Player Camera Manager* → **View Pitch Min / Max** (−80 / 80); sensitivity = Scalar; curve = Response Curve – Exponential; smoothing = Smooth |
| Fling | keep a ring of the last 6 (position, time) pairs each *Ongoing* frame; on release, velocity = `(newest − oldest) / Δt`; hand it to a **Projectile Movement Component** (*Initial Speed* from the vector, *Should Bounce*, *Bounciness* 0.5) |
| Swipe | on touch end: `delta = end − start`; accept if `|delta| > minDist` and `Δt < maxTime`; bucket `round(atan2 / 90°)` (4-way) or 45° (8-way) |
| Quartercircle | *Combo* trigger (above), or a `TArray<uint8>` ring of the last 8 direction buckets (from the stick angle, sampled on change) matched against `{2, 3, 6}` within `window` seconds of the punch *Started* |

## Collision & contact — what is built in

The broad phase (Quadtree) is **done for you** — Chaos keeps a BVH; you
never write a spatial hash. What you tune instead is what gets *tested*:

- **Collision Enabled**: No Collision / Query Only / Physics Only / Query
  and Physics. Sensors are *Query Only*.
- **Object Type** + a **response per channel**: Ignore / Overlap / Block.
  Custom channels: Project Settings → Engine → Collision → *New Object
  Channel* / *New Trace Channel* (18 free). The presets (*OverlapAllDynamic*,
  *Trigger*, *Pawn*, *BlockAll*, *Custom*) are just saved response tables.
- **Generate Overlap Events** must be on *both* components for begin/end
  overlaps to fire; **Simulation Generates Hit Events** for physics hits.

| Card | Unreal spelling |
|---|---|
| Aabb | `FBox` (Get Actor Bounds → *Origin*/*Box Extent*); `FBox::Intersect(Other)` is the four-edge test, `FBox::Overlap` returns the intersection box (its thinnest axis = least penetration). Any two **Box Collision** components with *Block* on each other do the resolve for you |
| Overlap | circle–circle: **Sphere Collision** overlaps; circle–rect: `FBox::GetClosestPointTo(Point)` then `Distance ≤ r` — exactly the clamped-point line the card draws. `FMath::SphereAABBIntersection` is the one-liner |
| Tunnel | three answers: kinematic moves **sweep** — `Set Actor Location` / `Add Actor World Offset` with *Sweep* = true return an `FHitResult` whose **Time** is the card's `t ∈ 0..1`; physics bodies tick **Use CCD** (Body Instance → Collision); projectiles use **Projectile Movement Component**, which sweeps every step and fires *On Projectile Stop* / *On Projectile Bounce* |
| Xaxis | the CMC resolves per axis internally (`SafeMoveUpdatedComponent` + `SlideAlongSurface`). For your own 2D mover, `MoveComponent` twice (X then Z) with sweep, or two **Box Trace By Channel** calls (`SweepSingleByChannel(Hit, Start, End, Rot, ECC_WorldStatic, FCollisionShape::MakeBox(HalfExtent), Params)` in C++). **Paper Tile Map** collision is generated per tile from the Tile Set's per-tile collision shapes (*Tile Set editor → Collision*), thickness = *Collision Thickness* |
| Oneway | **no built-in.** Per-pawn trick: the capsule's **Move Ignore Actors** — `IgnoreActorWhenMoving(Platform, true)` while `Velocity.Z > 0` or the feet (capsule bottom = location.Z − half height) are below the platform's top; clear it once the feet are above; drop-through = ignore for `dropFrames` (a timer) on down+jump (*Chorded Action*). Single-player shortcut: the platform's **Set Collision Response To Channel** (Pawn → Ignore/Block) per frame — it is per component, so one player only. Tile maps have no per-tile response: give each ledge its own thin **Box Collision** |
| Oblique | CMC **Walkable Floor Angle** (`SetWalkableFloorAngle`, default 44.765°) — the `maxAngle` dial; steeper floors are not walkable and the character slides (the CMC projects velocity along the floor tangent; *Maintain Horizontal Ground Velocity* is the "same speed uphill" toggle). The normal: `CurrentFloor.HitResult.ImpactNormal` |
| Kerb | CMC **Max Step Height** (45) — the knee probe is inside `StepUp`; *Perch Radius Threshold* / *Ledge Check Threshold* / *Can Walk Off Ledges* tune the edge cases |
| Whiskers | floor: `IsMovingOnGround` / `CurrentFloor` (**Find Floor** result: *Walkable Floor*, *Floor Dist*). No wall or ceiling flags: two **Line Trace By Channel** from the capsule centre ± (radius + tolerance) sideways and one up, or read `ImpactNormal` in **On Component Hit** (|Z| < 0.1 → wall, Z < −0.9 → ceiling). Wall-slide only when the wall lamp is lit |
| Quadtree | built in (Chaos broad phase). Lesson that survives: put sensors on their own object channel so the narrow phase tests fewer pairs; `Sphere Overlap Actors` with an *Object Types* filter is the "neighbours in adjacent cells" query |
| Volume | **Box / Sphere Collision** (Query Only, *Generate Overlap Events*, *Overlap* the pawn channel) → **On Component Begin Overlap** / **On Component End Overlap**; there is no *stay* event — poll `IsOverlappingComponent` on Tick, or keep a set between begin and end. Sector = a sphere plus a dot-product test on begin. `ATriggerBox` / `ATriggerSphere` are the same thing as placed actors |
| Iframes | two more components on the character: **Hitbox** (Box Collision, object channel `Hitbox`, *No Collision* by default) and **Hurtbox** (Box Collision, channel `Hurtbox`, Overlap only `Hitbox`, Ignore everything else). Active frames: an **Anim Notify State** on the swing montage flips the hitbox to *Query Only* in *Notify Begin* and back in *Notify End*; Paper2D flipbooks have no notifies — compare **Get Playback Position In Frames** to the active range each tick. I-frames: `SetCollisionEnabled(NoCollision)` on the hurtbox for `iframes` seconds + the flicker (`SetVisibility` toggled on a 0.05 s timer, or a `Flash` scalar in the sprite material) |
| Elastic | **Simulate Physics** on a Sphere Collision, a **Physical Material** with *Restitution* `e` (0.98 for Eightball), *Friction*, *Restitution Combine Mode* = Max; **Mass in Kg** override; **Linear Damping** 0.05. The normal and the exchanged velocities are the engine's; draw them from *On Component Hit*'s *Normal Impulse* |
| Obb | rotate a **Box Collision** and overlap it — the SAT is inside Chaos. In code, `FOrientedBox` (Math/OrientedBox.h) holds axes + extents; the axis projections the card draws are `FVector::DotProduct(corner, axis)` over the 4 (2D) or 15 (3D) candidate axes |

## All 26, one line each

| Card | Unreal spelling |
|---|---|
| Coyote | not built in — `LeftGroundTime` on *On Movement Mode Changed*, *Launch Character* inside the window (C++: `CanJumpInternal_Implementation`) |
| Jumpbuffer | not built in — `PressedTime` on *Started* while falling, *Jump* on *On Landed* if inside `buffer`; a held key already re-jumps (`bPressedJump`) |
| Variable | `JumpMaxHoldTime` + *Stop Jumping* (sustain model); the cut = `Velocity.Z *= cut`, the heavy fall = *Gravity Scale* after *On Reached Jump Apex* |
| Deadzone | **Dead Zone** modifier, *Type* Radial, *Lower* 0.35 / *Upper* 1.0; 8-way snap = a Blueprint *Input Modifier* |
| Normalize | Radial Dead Zone clamps to length 1; the CMC also clamps input to 1 in `ScaleInputAcceleration` — a hand-rolled Pawn does neither |
| Accelerate | CMC *Max Acceleration*, *Braking Deceleration Walking*, *Ground Friction*, *Braking Friction*, *Air Control* |
| Multitap | **Tap** + **Hold** triggers on one action; double tap = **Combo** (5.3+) or a timestamp |
| Charge | **Hold** (One Shot off) → *Elapsed Seconds* on *Ongoing*; *Completed* = release; over `max` = the stumble |
| Fling | a 6-entry (position, time) ring from *Ongoing*; release velocity → **Projectile Movement Component** |
| Swipe | touch delta bucketed by `atan2`, gated by `minDist` / `maxTime`; legacy `Gesture_Flick` exists but is coarse |
| Quartercircle | **Combo** trigger (↓, ↘, →, punch with *Time To Press Key*), or a `TArray<uint8>` direction ring |
| Virtualstick | **Touch Interface** asset (`DefaultVirtualJoysticks`) — Project Settings → Input → Mobile |
| Mouselook | `Mouse XY 2D-Axis` → *Add Controller Yaw/Pitch Input*; **Scalar**, **Response Curve – Exponential**, **Smooth**; *View Pitch Min/Max* |
| Aabb | `FBox::Intersect` / `FBox::Overlap`; two blocking **Box Collision**s resolve themselves |
| Overlap | **Sphere Collision**; `FBox::GetClosestPointTo` + distance for circle–rect |
| Tunnel | sweeps (*Set Actor Location* with *Sweep* → `Hit.Time`), **Use CCD** on physics bodies, Projectile Movement sweeps by default |
| Xaxis | two swept moves (X, then Z) / **Box Trace By Channel**; Paper Tile Map collision from the Tile Set's per-tile shapes |
| Oneway | not built in — **Move Ignore Actors** (`IgnoreActorWhenMoving`) by feet-vs-top and velocity; drop-through = ignore for `dropFrames` |
| Oblique | CMC **Walkable Floor Angle** (`SetWalkableFloorAngle`); steeper slides; normal from `CurrentFloor.HitResult` |
| Kerb | CMC **Max Step Height**; *Perch Radius Threshold* for the edge cases |
| Whiskers | floor from `IsMovingOnGround` / *Find Floor*; wall + ceiling from two side traces and one up, or *On Component Hit* normals |
| Quadtree | built in (Chaos broad phase); channels and *Object Types* filters are what you tune |
| Volume | **Box / Sphere Collision**, Query Only, *Generate Overlap Events* → *On Component Begin / End Overlap*; stay = poll |
| Iframes | separate **Hitbox** / **Hurtbox** Box Collisions on their own object channels; **Anim Notify State** flips *Collision Enabled*; i-frames = *No Collision* + flicker |
| Elastic | *Simulate Physics* + **Physical Material** *Restitution* `e`, *Mass in Kg*; the impulse from *On Component Hit* |
| Obb | a rotated **Box Collision** (SAT inside Chaos); `FOrientedBox` in code |

## The 2D spelling

The 2D character is **Paper Character** (`APaperCharacter`: the same
capsule and CMC, a *Paper Flipbook Component* instead of a skeletal mesh —
the *2D Side Scroller* template). Two settings make the third dimension
go away: CMC → *Planar Movement* → **Constrain to Plane** with *Plane
Constraint Axis Setting* = **Y**, and on any physics body (Elastic's
balls, Fling's projectile) Body Instance → Constraints → *Mode* = **YZ
Plane**. After that every row above reads the same; "feet" is capsule
bottom in Z, "sideways" is X. Input is dimension-blind — Enhanced Input
does not know what it drives. UMG-side gestures (Swipe, Fling on a
widget) use the widget's *On Touch Started / Moved / Ended* and *On Mouse
Button Down / Move / Up* overrides with **Get Screen Space Position**.

## The 3D sibling

Everything above is already 3D; the only rows that widen are Whiskers
(eight whiskers instead of four — add the two diagonals) and Obb (fifteen
separating axes). Deadzone and Mouselook are where 3D games live: the
Radial dead zone on the move stick, Exponential response on the look
stick, and *View Pitch Min/Max* keeping the camera off the ceiling.
