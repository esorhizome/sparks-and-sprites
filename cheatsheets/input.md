# Cheatsheet · Input & intent

Everything = **a press is a fact; intent is a guess about it, on a clock.** Full chapter: [17](../chapters/17-input-and-intent.md). Live demos: [the locomotion lexicon](https://esorhizome.github.io/sparks-and-sprites/locomotion.html), family **Input & intent** (13 cards, each with a rhyme, all editable; Godot menu key F, right-click for the rhyme).

## The thirteen, one line each

| Card | Guess | The mechanism in one breath |
|---|---|---|
| C·Coyote | "you meant to jump" (late) | grace timer starts when ground is lost; `jump if coyoteLeft > 0`; zero it when you jump |
| J·Jumpbuffer | "you meant to jump" (early) | store the press with its time; fire on landing if younger than `buffer`; consume it |
| V·Variable | "how high?" | hold = keep rising; release while rising → `vy *= cut` (or fall gravity ×`fallG`) |
| D·Deadzone | "is the stick resting?" | test the vector's **length**, not each axis; **rescale** `(len − dz) ÷ (1 − dz)`; optional 8-way snap |
| N·Normalize | "how fast diagonally?" | `if (len > 1) v /= len` — else diagonals run `√2 ≈ 1.41`× (41%) faster |
| A·Accelerate | "how quickly to obey?" | `v = move_toward(v, want, rate·dt)`; `rate = accel` toward, `brake` away, `airAccel` off the ground |
| M·Multitap | "which verb was that press?" | tap `< tapMax` · hold `> holdMin` · two taps within `dblGap`; judged on release or when a window closes |
| C·Charge | "how much?" | hold fills `power` by `dt`; sweet spot near full; past `max` it backfires; release launches ∝ power |
| F·Fling | "how fast was the hand?" | release velocity = average of the last N `(pos, time)` samples (~100 ms); discard older ones |
| S·Swipe | "which way did the finger flick?" | total delta bucketed into 4/8 directions, only if `dist ≥ minDist` and `time ≤ maxTime` |
| Q·Quartercircle | "did they draw ↓ ↘ →?" | ring buffer of direction codes; match the pattern in order inside `window` s, then the press fires |
| V·Virtualstick | "where is the stick?" | origin = where the finger landed; `v = clamp(finger − origin, radius) ÷ radius` |
| M·Mouselook | "where are they looking?" | yaw/pitch += pointer **delta** × sensitivity (× `|delta|^(accel−1)`); clamp pitch ±85–89° |

## The numbers that usually feel right

coyote **80–120 ms** · buffer **80–150 ms** · jump cut `vy *= 0.3–0.5` or fall gravity ×1.5–2.5 · dead zone **0.15–0.25 radial, rescaled** · tap < 200 ms · hold > 250–300 ms · double gap < 250–300 ms · charge 0.3–1.2 s to full · fling = last 3–5 samples · swipe ≥ 20–40 px in ≤ 250–400 ms · motion input 10–20 frames · virtual stick radius 40–70 px · mouse-look linear (`accel = 1`) by default.

## The load-bearing snippets

```
// edges vs levels — jump wants the edge, charge wants the level
pressed = down && !wasDown;  released = !down && wasDown;  wasDown = down

// coyote + buffer — seconds, counted down by dt, never frames
coyote = onFloor ? COYOTE : coyote - dt
buffer = pressed ? BUFFER : buffer - dt
if (buffer > 0 && coyote > 0) { vy = -sqrt(2*g*h); coyote = 0; buffer = 0 }

// variable jump — cut the rise on release
if (released && vy < 0) vy *= CUT              // or: g = rising && held ? g : g * FALL_G

// radial dead zone, rescaled (never per axis)
len = |v|;  v = len < DZ ? 0 : v/len * min(1, (len - DZ) / (1 - DZ))

// normalize the diagonal
if (len > 1) v /= len

// tap / hold / double — one button, three verbs
on press:   if (now - lastUp < DBL_GAP) dash();  tDown = now
while held: if (now - tDown > HOLD_MIN) charging = true
on release: if (!charging && now - tDown < TAP_MAX) hop();  lastUp = now;  charging = false

// fling — velocity from a history buffer
hist.push({x, y, t}); drop samples with t < now - 0.1
v = (hist.last - hist.first) / (hist.last.t - hist.first.t)   // guard the zero
```

## Engine spellings

| Idea | Godot | Unity (Input System) | Unreal (Enhanced Input) | Web |
|---|---|---|---|---|
| edge / level | `Input.is_action_just_pressed` / `is_action_pressed` | `WasPressedThisFrame()` / `IsPressed()` | *Started* / *Triggered* / *Completed* | `keydown` (skip `event.repeat`) / `keyup` |
| actions | `InputMap` (Project Settings → Input Map) | Input Action assets | Input Actions + Mapping Contexts | your own key map on `KeyboardEvent.code` |
| dead zone + normalize | `Input.get_vector("l","r","u","d")` — radial, rescaled, clamped; dead zone per action | *Stick Deadzone*, *Normalize Vector 2* processors | *Dead Zone* (Radial), *Swizzle*, *Negate* modifiers | `navigator.getGamepads()` — raw, you rescale |
| variable jump | `vy *= cut` in `_physics_process` | same in `FixedUpdate` | `ACharacter::JumpMaxHoldTime` + `JumpZVelocity`; `StopJumping()` | `vy *= cut` |
| accelerate / brake | `move_toward` on `velocity.x` | `Mathf.MoveTowards` | `MaxAcceleration`, `BrakingDecelerationWalking`, `AirControl` on the movement component | `move_toward` by hand |
| tap / hold / double | timers; `is_echo()` skips key repeat | *Tap*, *Hold*, *MultiTap*, *SlowTap* interactions | *Tap*, *Hold*, *Pulse*, *Chorded Action*, *Combo* triggers | `event.timeStamp` |
| touch drag / fling | `InputEventScreenDrag` (`relative`, `velocity`), one per finger `index` | `EnhancedTouch.Touch` (`delta`, `startScreenPosition`) | `InputTouch` events | pointer events + `setPointerCapture`, `getCoalescedEvents()`, `touch-action: none` |
| virtual stick | screen touch + drag events; `TouchScreenButton` | *On-Screen Stick* | *Touch Interface* asset | `pointerdown` sets the origin; track `pointerId` |
| mouse-look | `MOUSE_MODE_CAPTURED` + `InputEventMouseMotion.relative` | `CursorLockMode.Locked` + `Mouse/delta` | `AddControllerYawInput` / `PitchInput`; `ViewPitchMin/Max` | `requestPointerLock()` + `movementX/Y` |

## What goes wrong

count seconds not frames · store the press, let the physics tick consume it · pointer events + `touch-action: none` (never mouse events for touch) · one control per `pointerId`/`index` · dead zone on the vector's length, then rescale · normalize the diagonal · zero coyote when you jump · consume the buffer · key repeat is a hold, not taps · mouse acceleration off by default.

## Feel

Forgiveness windows cancel latency; they are kindness, not cheating. Show what the game decided (dust on a buffered landing, a red X on a refused press). Keep every window and threshold as a number in one place — that is where accessibility options come from.

**Free deep dive:** Maddy Thorson, ["Celeste and TowerFall Physics"](https://medium.com/@MattThorson/celeste-and-towerfall-physics-d24bd2ae0fc5) — coyote time, buffering and corner correction by the person who tuned them; Celeste's `Player.cs` is public on GitHub with every window as a named constant.
