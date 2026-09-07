# 17 · Input & intent — the code between the hand and the character

*Fresh-start note (no memory of other chapters required): a **frame** is one drawn picture, ~60 of them a second; **dt** ("delta time") is the fraction of a second since the last frame; a **vector** is an arrow — an x and a y that together mean "this far, that way"; to **normalize** a vector is to keep its direction and set its length to exactly 1; an **axis** is one number a stick or a key pair reports, from −1 to 1; a **press** is the single frame a button goes down and a **release** the single frame it comes up (every frame between is "held"); **pointer events** are the web's unified mouse-pen-finger input events. Each is re-mentioned in place.*

---

Every input a game receives is a fact with a timestamp. *The A button went down at 12.417 seconds. The left stick reads (0.03, 0.01). The finger has moved 14 pixels right since the last frame.* Facts are cheap and exact, and on their own they make terrible games. The player who pressed jump three frames after running off a ledge did not intend to fall. The stick reading (0.03, 0.01) is not a request to creep north-east; it is a thumb resting on plastic. The tap-tap was a dash, not two small hops.

**Input handling** is the code that turns those facts into a guess about what the player *meant* — and the guess always has a clock in it. A jump is honoured *for a while* after the ledge. A press is remembered *for a while* before landing. Two taps count as one gesture *if* they land close enough together. The movement maths of [chapter 14](14-procedural-animation.md) decides what the body does; the collision rules of [chapter 18](18-collision-and-contact.md) decide what it may touch; this chapter is the thin layer in front of both, deciding what the body was *asked* to do. It is small — most of these mechanisms are five to fifteen lines — and it is where "the controls feel bad" almost always lives.

> **A press is a fact; intent is a guess the game makes about the fact, on a clock. Write the guess down as numbers — a window in seconds, a radius, a threshold — and the feel becomes something you can tune.**

▶ *See it all:* the **Input & intent** family of **[the locomotion lexicon](https://esorhizome.github.io/sparks-and-sprites/locomotion.html)** — thirteen live cards, every one editable in the page, and every one with a **rhyme** (the same card with two or three dials turned). Each card keeps its numbers in one `D = {…}` block at the top, so the whole lesson is *change a number, watch the guess change*. The same thirteen (+13 rhymes) are ported to GDScript in the downloadable Godot project ([`demos/godot/scenes/motion/`](../demos/godot/scenes/motion/), menu key **F**; right-click a card for its rhyme).

## Thirteen guesses, five kinds

Every mechanism here is guessing one of five things. Sorting them this way tells you which one you need before you know its name.

| What the code is guessing | The trick | Cards |
|---|---|---|
| "you meant to jump" — **forgiveness in time** | timers that widen the legal moment on both sides of the event | C·Coyote · J·Jumpbuffer · V·Variable |
| "you meant *this* direction, *this* fast" — **shaping in space** | dead zones, normalizing, separate speed-up and slow-down rates | D·Deadzone · N·Normalize · A·Accelerate |
| "which verb was that press?" — **reading one button's rhythm** | timing windows: tap, hold, double, charge | M·Multitap · C·Charge |
| "what shape did the pointer draw?" — **reading a path** | a history buffer of recent positions, matched against a pattern | F·Fling · S·Swipe · Q·Quartercircle |
| "a finger or a mouse pretending to be a stick" | an origin, a delta, a clamp | V·Virtualstick · M·Mouselook |

## The thirteen, one breath each

| Card | The mechanism | The dials | The rhyme |
|---|---|---|---|
| **C·Coyote** | the mote runs off a ledge; a **grace timer** starts the instant the ground is lost (`grace = coyote − (t − tLeft)`, a shrinking bar); a jump inside the window gets a green flash, outside it a red X | `coyote`, `g` | *Cliffhanger* — half a second of grace, floatier gravity: the cartoon platformer |
| **J·Jumpbuffer** | the mirror image: a press up to `buffer` seconds *before* touchdown waits as an amber pip and fires the frame the feet land; older presses expire visibly | `buffer` | *Jittery* — 40 ms and a fast fall: strict arcade |
| **V·Variable** | **variable jump height**: hold to keep rising; release multiplies the upward velocity by `cut` (or swaps in a heavier `fallG`); three ghosts with hold times 0.05 / 0.15 / 0.35 s draw their apex lines | `cut`, `fallG` | *Vault* — cut 0.3, fall gravity ×2.5: snappy, Celeste-style |
| **D·Deadzone** | a jittering stick drawn raw, then hard-cut (watch the jump at the edge), then **rescaled radially**, `(len − dz) ÷ (1 − dz)`, so the slowest walk stays slow; optional 8-way snap | `dz` | *Dial* — dz 0.35 with cardinal snap: a d-pad from an analogue stick |
| **N·Normalize** | two motes race diagonally: one adds x and y (`√2 ≈ 1.41`× faster, its arrow drawn longer), one **normalizes**; a lap timer shows the cheat | speed, ways | *Nimble* — 4-way, faster: the classic top-down |
| **A·Accelerate** | speed approaches its target through separate `accel` and `brake` rates, and a smaller `airAccel` off the ground; a speed-vs-time strip draws the ramps | `accel`, `brake`, `airAccel` | *Asphalt* — brake ≫ accel, no air control: a heavy runner |
| **M·Multitap** | one button, three verbs by timing: tap (< `tapMax`) hops, hold (> `holdMin`) charges, two taps within `dblGap` dash; a timeline paints the windows as bands | `tapMax`, `holdMin`, `dblGap` | *Marathon* — hold 0.5 s, double gap 0.4 s: forgiving |
| **C·Charge** | holding fills a bar with a **sweet-spot** band near the top; past `max` it **overcharges** and the mote stumbles; release launches with distance ∝ power | fill rate, `max` | *Cannonball* — slow fill, huge range, brutal overcharge |
| **F·Fling** | drag the mote and let go: release velocity comes from the **last N pointer positions with their timestamps** (a history buffer, averaged); then gravity and bounces | history, gravity, drag | *Feather* — light gravity, strong drag: a paper plane |
| **S·Swipe** | the pointer's delta bucketed into 4 or 8 **directions**, accepted only if it covered `minDist` inside `maxTime`; a compass rose lights the wedge, the mote hops a tile | `minDist`, `maxTime`, ways | *Slidepuzzle* — 4-way, big minDist, slides to the wall |
| **Q·Quartercircle** | a **motion-input parser**: a ring buffer of recent directions matched against ↓ ↘ → plus a press inside `window` seconds; matched arrows light green, a projectile fires | `window`, pattern | *Qcb* — the mirrored ↓ ↙ ←, tighter window |
| **V·Virtualstick** | a **virtual joystick** appears where the finger lands; `vector = finger − origin`, clamped to `radius`; the mote drives by it | `radius`, speed | *Vespa* — a floating stick whose origin follows the thumb at the rim |
| **M·Mouselook** | **mouse-look**: yaw and pitch from the pointer's *delta*, pitch clamped, an `accel` curve (1 = linear); a reticle over posts that yaw scrolls and pitch shifts | sensitivity, `accel`, clamp | *Mecha* — slow, hard clamp, heavy smoothing |

The first two cards are one idea facing opposite ways. **Coyote time** (after the cartoon coyote who keeps running past the cliff until he looks down) forgives a press that came *late*; a **jump buffer** forgives one that came *early*. Together they turn "press jump on the exact frame the feet touch" — which no human can do on purpose — into "press jump around the time you land", which everyone can.

## Edges, levels, and the clock

**Edge versus level.** *Is the button down?* is a level — true every held frame. *Did it go down this frame?* is an edge — true once. Jumping needs the edge (or a held key jumps every frame); charging needs the level. Every engine offers both (`is_action_just_pressed` vs `is_action_pressed`; `WasPressedThisFrame()` vs `IsPressed()`; Enhanced Input's *Started* vs *Triggered*); on the web you build the edge from `keydown`/`keyup`, ignoring `event.repeat` — otherwise the operating system's key repeat hands you a fresh "press" every thirty milliseconds.

**Seconds, not frames.** Every window is a timer, and a timer counts *seconds* down by `dt` — the fraction of a second since the last frame — never frames down by one. A six-frame grace tuned at 60 Hz is 42 ms on a 144 Hz monitor. `coyoteLeft −= dt; if (pressed && coyoteLeft > 0) jump()` is the whole card, framerate-proof.

## The numbers that usually feel right

Starting points, not laws. Every one is a dial in the cards; turn it and feel the difference.

| Guess | Usual value | Why there |
|---|---|---|
| coyote time | 80–120 ms (5–7 frames at 60 Hz) | cancels eye-to-thumb latency; past ~150 ms players notice. Celeste keeps 0.1 s |
| jump buffer | 80–150 ms | the same window as coyote is a fine default |
| variable jump | on release, `vy *= 0.3…0.5` if still rising; or fall gravity ×1.5–2.5 | the cut gives control; the heavier fall gives weight |
| dead zone | 0.15–0.25 of the stick's radius, **rescaled** | old sticks drift ~0.1. Unity's *Stick Deadzone* defaults to 0.125; Godot's per-action default is 0.5 — lower it |
| diagonal speed | normalize when length > 1 | `√2 = 1.414`: an unnormalized diagonal is 41% faster |
| tap / hold / double | tap < ~200 ms; hold > ~250–300 ms; second tap within ~250–300 ms | under 200 ms people can't tell; over 300 ms a hold feels like waiting |
| charge | 0.3–1.2 s to full; sweet spot the top 15–25%; overcharge 20–30% past | a decision, not a chore |
| fling history | the last 3–5 samples, or ~100 ms; discard older | one frame's delta is noise; a long average lags the hand |
| swipe | `minDist` 20–40 px (~5% of the short screen side); `maxTime` 250–400 ms | shorter is a tap; slower is a drag |
| motion input | 10–20 frames (~170–330 ms) for ↓ ↘ → | fighting games at the tight end; casual games open it wide |
| mouse-look | pitch clamp ±85–89°; `accel = 1` (linear) by default | acceleration breaks aim memory — an option, never the default |

## The four accents, side by side

The guesses are engine-agnostic; only the spelling changes accent. Where an engine packages a mechanism, the package is listed; the hand-rolled version is still the card's five lines.

| Idea | Web (the lexicon) | Godot | Unity (Input System) | Unreal (Enhanced Input) |
|---|---|---|---|---|
| press (edge) vs held (level) | `keydown` minus `event.repeat`, `keyup` | `Input.is_action_just_pressed` / `is_action_pressed`; actions live in **`InputMap`** (Project Settings → Input Map) | `WasPressedThisFrame()` / `IsPressed()` on an Input Action | triggers *Started* / *Triggered* / *Completed* |
| coyote & buffer | two floats in the frame loop | two floats in `_physics_process`; `is_on_floor()` refills coyote | two floats in `FixedUpdate`, press cached in `Update` | hand-rolled around `CanJump()`; `ACharacter::JumpMaxCount` for extra jumps |
| variable jump | `if (released && vy < 0) vy *= cut` | same, in `_physics_process` | same, in `FixedUpdate` | built in: **`ACharacter::JumpMaxHoldTime`** — hold to keep receiving the movement component's `JumpZVelocity`; `StopJumping()` on release |
| dead zone | `navigator.getGamepads()[i].axes` — raw; you rescale | **`Input.get_vector("left", "right", "up", "down")`** — radial, rescaled, clamped to 1; dead zone per action in the Input Map, or as the fifth argument | *Stick Deadzone* processor (min/max); *Axis Deadzone* for triggers | **Dead Zone** modifier, type *Radial* (not *Axial*) |
| normalize / clamp | `if (len > 1) v /= len` | `get_vector` already clamps; `Vector2.limit_length(1)` | *Normalize Vector 2* processor, or `Vector2.ClampMagnitude(v, 1)` | `GetClampedToMaxSize(1)`; *Swizzle Input Axis Values* + *Negate* turn W/S into the y axis |
| accelerate / brake | `v = move_toward(v, target, rate·dt)` | `move_toward` is built in, on `CharacterBody2D.velocity.x` | `Mathf.MoveTowards`, or forces on `Rigidbody2D` | `UCharacterMovementComponent`: `MaxAcceleration`, `BrakingDecelerationWalking`, `BrakingFrictionFactor`, `AirControl` |
| tap / hold / double / charge | `event.timeStamp` | timers; `InputEvent.is_echo()` skips key repeat | **Interactions**: *Tap*, *SlowTap*, *Hold*, *MultiTap* | **Triggers**: *Tap*, *Hold*, *Pulse*, *Chorded Action* |
| touch drag: fling & swipe | pointer events; `setPointerCapture`; `getCoalescedEvents()` for every sample between frames; `touch-action: none` | **`InputEventScreenTouch`** (pressed/released) + **`InputEventScreenDrag`** (`relative`, and a `velocity` already computed) | `EnhancedTouch.Touch`: `delta`, `startScreenPosition`, `startTime` | `InputTouch` *Pressed* / *Moved* / *Released* on the player controller |
| motion input (↓ ↘ →) | a ring buffer of direction codes | the same buffer | the same buffer | the **Combo** trigger — actions in order, each with a time limit |
| virtual stick | `pointerdown` sets the origin; track by `pointerId` | one stick per touch `index`; `TouchScreenButton` for buttons | the **On-Screen Stick** component | a *Touch Interface* asset (Project Settings → Input) |
| mouse-look | `requestPointerLock()`, then `movementX` / `movementY` | `Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)` + `InputEventMouseMotion.relative` | `Cursor.lockState = CursorLockMode.Locked`; a *Look* action bound to `Mouse/delta` | `AddControllerYawInput` / `AddControllerPitchInput`; pitch clamp in `PlayerCameraManager` |

Pointers themselves — hover, cursors, a mouse that rests versus a finger that doesn't — are [chapter 12](12-cursors-and-living-buttons.md)'s subject; this chapter borrows only its rule: on the web, pointer events for everything, so mouse, pen and touch arrive through one door.

## What usually goes wrong

- **Timers that count frames.** `coyoteFrames−−` was fine on the one machine it was written on. Count seconds, subtract `dt`.
- **A press read on one clock and consumed on another.** The press is noticed in `_process` / `Update` but the body moves in `_physics_process` / `FixedUpdate`: the physics tick doesn't run that frame and the jump is gone, or it runs twice and jumps twice. Store the press with its time and let the physics tick spend it — that is a jump buffer, so you were writing one anyway. (Godot 4 tracks `is_action_just_pressed` per loop, which removes the vanishing half; mixing `_input` callbacks with polling is the remaining trap.)
- **Mouse code on a touch screen.** `mousedown` arrives late or never on touch; a swipe scrolls the page instead of moving the mote. Pointer events plus `touch-action: none`. In Godot, *Emulate Touch From Mouse* / *Emulate Mouse From Touch* (Project Settings → Input Devices → Pointing) are on deliberately or not at all — half-on gives every event twice. Track fingers by `pointerId` / `index`: a second finger is a second control, not a new origin for the first.
- **Dead zones applied per axis.** Each axis clipped separately makes a square hole: push nearly straight up and the small x component snaps to zero, so diagonals feel notchy. Test the vector's *length*, then rescale — a hard cut-off at 0.2 makes the slowest possible walk 20% speed, with a visible jump at the edge (D·Deadzone's middle panel).
- **The 41% diagonal.** Normalize when the length is over 1; players find the fast diagonal in the first minute.
- **Free double jumps and double fires.** If coyote only refills on the floor, the 100 ms *after* a jump still counts as grace — zero it the moment you jump. Consume the buffered press when you use it, and clear it when it expires.
- **Mouse acceleration on by default.** The same wrist movement lands the reticle in different places, and aim memory never forms. Linear by default; a curve as an option.

## Feel, restraint, and honesty

- **Forgiveness windows are kindness, not cheating.** The eye-to-thumb round trip is 100–200 ms and the display adds a frame or three; a 100 ms coyote window gives the player nothing they didn't earn — it cancels the latency between what they saw and when their thumb arrived. The game the player *perceives* is the one where they pressed jump on the ledge; the timer makes the code agree.
- **Tell the player what the game decided.** A buffered jump that fires on landing should look like a jump *from* the landing (dust, squash, sound). A refused press should read as refused — Coyote's red X is a design, not a debug aid. A silent guess feels like a bug even when it is right.
- **Keep the guesses in one place, as numbers.** The cards' `D = {…}` block is the pattern: every window, radius and threshold in one dictionary. That is also where accessibility lives — longer windows, hold-to-toggle, a wider dead zone for a tremor — each a number changed, not a system rebuilt. The rhymes prove it: Coyote and *Cliffhanger* differ by two numbers, and one is a hard platformer and the other a cartoon.
- **Respect the device.** A stick has no tap position; a finger has no hover and covers what it touches; a mouse has no "how hard". Swipe thresholds in millimetres, not pixels; a virtual stick where the thumb lands, not where the artist drew it.
- **Restraint.** Every window is a moment where the game does something the player didn't literally do. Keep them short, few, and visible. The best input layer is the one nobody notices, because the character simply did what they meant.

---

*Quick-reference version: [the input cheatsheet](../cheatsheets/input.md). The gallery: [the locomotion lexicon](https://esorhizome.github.io/sparks-and-sprites/locomotion.html), family **Input & intent**. Kin chapters: [14 · Procedural animation](14-procedural-animation.md) (what the body does with the intent), [18 · Collision & contact](18-collision-and-contact.md) (what it may touch), [12 · Cursors & living buttons](12-cursors-and-living-buttons.md) (pointers, hover, touch). Going deeper, free and legal: Maddy Thorson's ["Celeste and TowerFall Physics"](https://medium.com/@MattThorson/celeste-and-towerfall-physics-d24bd2ae0fc5) — coyote time, buffers and corner correction, from the person who tuned them.*
