# VFX Around the Flipbook (Godot 4)

You have a PNG sequence — partially transparent, partially translucent — playing as a loopable flipbook in Godot. This note maps out how to hang effects **on** and **around** it, and how those effects are *clocked*: looping forever on their own, cycling through programmed movement sets over time, or firing on a trigger such as a click.

Written against Godot 4.x. Everything here works in current 4.x releases; the few features tied to a specific minor version are tagged (e.g. "4.3+").

**The short answer to the timing question up front:** yes to all of it. Every effect below can be looped, sequenced, cycled, *and* triggered, because Godot separates the effect (a shader, a particle system, a node being moved) from the clock that drives it. There are four clocks — shader `TIME`, `AnimationPlayer`, `Tween`, and `Timer` — plus a signal system that turns any event (click, hover, animation loop, a specific flipbook frame) into a trigger. Sections 1–3 build the orchestra; section 4 is the conductor's manual.

---

## 1. The base: PNG sequence → loopable flipbook

### 1.1 The canonical path: AnimatedSprite2D

Add an **AnimatedSprite2D** node. In the Inspector, give *Sprite Frames* a **New SpriteFrames**, then click it to open the SpriteFrames panel at the bottom of the editor. Name an animation (`idle`), drag your PNGs in (alphabetical order becomes frame order, so zero-pad: `spark_000.png`, `spark_001.png`, …), set the FPS field, and switch on the **loop** toggle (the ↻ icon). *Autoplay on Load* makes it run the moment the scene starts.

Because each frame is its own texture, `UV` in any shader you attach runs a clean 0–1 across the current frame — no atlas math. Control from code:

```gdscript
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
    sprite.play("idle")           # start the loop
    # sprite.pause() / sprite.stop() / sprite.play_backwards("idle")
    # sprite.speed_scale = 2.0    # tempo for this sprite only
    # sprite.frame = 3            # jump to a frame
```

AnimatedSprite2D also *emits* — and these become VFX triggers in §4.2:

- `frame_changed` — every frame flip
- `animation_looped` — each time the loop wraps
- `animation_finished` — a non-looping animation ended
- `animation_changed` — switched to a different named animation

### 1.2 The alternative: sprite sheet + AnimationPlayer

Pack the sequence into one sheet, put it on a **Sprite2D**, set *Animation → Hframes/Vframes*, and keyframe the `frame` property in an **AnimationPlayer**. More setup — but the AnimationPlayer becomes a single master timeline where the same animation that flips frames can also keyframe glow uniforms, aura scale, and particle emission. Everything stays in lock-step forever (§4.2 comes back to this).

### 1.3 Import notes for translucent art

Semi-transparent pixels blend normally with whatever is drawn *behind* them — so effects placed behind the sprite show through the translucent regions. That's a feature: an additive glow behind a translucent body lights it from within.

A few practicalities:

- **Filtering** — `Nearest` for pixel art, `Linear` for painted frames. Set the project default under *Rendering → Textures → Canvas Textures*, or per node via *CanvasItem → Texture → Filter*.
- **Padding** — leave transparent margin around the silhouette when exporting. On-sprite glow/outline shaders (§3.1) can only draw inside the texture's own rectangle; a tightly cropped PNG clips the halo flat at the edge.
- **White-on-transparent frames are a superpower.** `modulate` *multiplies* the texture color, so pure-white art can be tinted to any hue at runtime — one PNG sequence, every palette, both of a game's dark and light themes. On dark backgrounds white art carries itself; on light backgrounds give it a dark tint, a colored under-glow, or an outline shader so it keeps its silhouette.

---

## 2. Where VFX live: the layer model

In 2D, the scene tree *is* the draw order: children draw after (in front of) their parent, siblings draw top-to-bottom as listed. A character with effects is really a small stack:

```
Protagonist (Node2D)              ← script + orchestration live here
├── Aura (Sprite2D)               ← behind (Show Behind Parent ✓)
├── AnimatedSprite2D              ← the flipbook (its ShaderMaterial = on-sprite FX)
├── OrbitPivot (Node2D)           ← around (children placed at a radius)
│   └── Mote (Sprite2D)
├── Burst (GPUParticles2D)        ← in front (later siblings draw on top)
└── ClickArea (Area2D)            ← input, not visuals (§4.4)
    └── CollisionShape2D
```

An effect can live in five places, and most finished looks combine two or three:

1. **Behind the sprite** — an earlier sibling, a child with `show_behind_parent = true`, or `z_index = -1`. Auras, halos, ground glows, the far half of an orbit.
2. **In front** — later siblings or children. Sparks, flashes, foreground streaks that occasionally cross the face.
3. **On the sprite itself** — a **ShaderMaterial** on the AnimatedSprite2D bends its own pixels: rim glow, wobble, dissolve, circuit overlay. `TEXTURE` inside the shader is always *the current frame*, so the effect tracks the flipbook with zero extra wiring.
4. **Screen-space** — a shader that reads what's already drawn (`hint_screen_texture`) and re-emits it displaced: heat haze, shockwave refraction. It distorts *everything* behind its rectangle, including whatever shows through your translucent pixels.
5. **Project-level** — a **WorldEnvironment** with Glow blooms every sufficiently bright pixel in the viewport (§3.1). One switch, scene-wide consequences.

Three utilities worth knowing early: `top_level = true` makes a child ignore its parent's transform (trails that should hang in the air while the character moves on); **CanvasGroup** renders its children as one merged image so you can fade a sprite-plus-effects stack as a unit without overlaps double-darkening (test it with additive children — they get flattened into the group before compositing); and `z_index` overrides tree order when something must swap between in-front and behind per frame, which is exactly what a fake-3D orbit needs (§3.6).

---

## 3. The effect toolbox

Each effect below runs cheapest-first, and each one names its **timing hook** — the knob §4's clocks will grab.

### 3.1 Glows

**Aura sprite (no shader).** A soft radial blob PNG (or a blurred copy of one frame) on a Sprite2D behind the flipbook: *Show Behind Parent* ✓, then *Material → New CanvasItemMaterial → Blend Mode: Add*. Tint with `modulate`. Additive blending means it brightens what's under it — light, not paint — and it glows straight through the translucent parts of the body above.
*Timing hook:* animate `scale` and `modulate:a` (breathing tween in §4.2).

**Rim / outer glow on the sprite (shader).** Sample the alpha in a small ring around each pixel; where a neighbor is opaque but the pixel isn't, you're on the rim — paint halo there:

```glsl
shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.45, 0.9, 1.0, 1.0);
uniform float glow_size : hint_range(0.0, 16.0) = 4.0;      // in texture pixels
uniform float glow_strength : hint_range(0.0, 4.0) = 1.2;

void fragment() {
    vec4 base = texture(TEXTURE, UV);
    vec2 px = TEXTURE_PIXEL_SIZE * glow_size;
    float dilated = 0.0;
    for (int i = 0; i < 8; i++) {
        float ang = TAU * float(i) / 8.0;
        dilated = max(dilated, texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * px).a);
    }
    float halo = clamp(dilated - base.a, 0.0, 1.0);
    // halo *= 1.0 - step(0.01, base.a);  // uncomment: rim only, no seep into translucent interior
    COLOR = base + glow_color * halo * glow_strength;
}
```

On translucent pixels the halo seeps inward slightly — usually pretty (inner light); the commented line restricts it to the outside rim. If the halo cuts off flat, your PNG is cropped tight — re-export with margin (§1.3).
*Timing hook:* `glow_strength`. Self-looping version, zero scripts: multiply it by `(0.8 + 0.2 * sin(TIME * 2.0))`. Or leave it a plain uniform and drive it from any clock (§4.5).

**True bloom (project-level).** Enable *Project Settings → Rendering → Viewport → HDR 2D*, add a **WorldEnvironment** node, *New Environment*, switch on **Glow** (blend mode *Additive* or *Screen*). Now any pixel brighter than the threshold blooms — and you can *make* pixels brighter than 1.0: output `COLOR.rgb * 2.0` in a shader, or set `modulate = Color(2.0, 1.6, 1.2)` from code. Viewport-wide and costs real GPU on mobile, but it's the glow that reads as photographic.
*Timing hook:* the over-brightness itself — tween a modulate from `Color(3,3,3)` down to white and the bloom flares and settles.

### 3.2 Ripples & pulses

**Expanding ring (node + tween).** A ring texture on a Sprite2D, scaled up while fading out, forever:

```gdscript
func _ready() -> void:
    var t := create_tween().set_loops()
    t.tween_property($Ring, "scale", Vector2(2.6, 2.6), 0.9)\
        .from(Vector2(0.3, 0.3)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    t.parallel().tween_property($Ring, "modulate:a", 0.0, 0.9).from(0.85)
    t.tween_interval(0.4)   # breather between pulses
```

(A particle variant also exists: *emission shape → Ring* on a ParticleProcessMaterial, ring axis `(0, 0, 1)` so the ring lies flat in 2D.)
*Timing hook:* the tween itself — swap `set_loops()` for a plain tween and call it on demand.

**Wobble the sprite's own pixels (shader).** A sine sweep across `UV` — underwater / spirit / hologram flavor. Keep the amplitude tiny:

```glsl
shader_type canvas_item;
uniform float wobble : hint_range(0.0, 1.0) = 0.25;

void fragment() {
    vec2 uv = UV;
    uv.x += sin(uv.y * 24.0 + TIME * 4.0) * 0.012 * wobble;
    COLOR = texture(TEXTURE, uv);
}
```

*Timing hook:* `wobble` — 0 is off, so a tween from 1.0 → 0.0 is a "shudder that settles."

**Screen-space shockwave (refraction).** The heavyweight: bend everything already drawn behind a rectangle. Put a plain white Sprite2D or ColorRect over the blast area with this material, and animate `progress` 0 → 1 when triggered:

```glsl
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float progress : hint_range(0.0, 1.0) = 0.0;   // 0 = invisible, animate to 1
uniform float strength = 0.04;

void fragment() {
    vec2 dir = UV - vec2(0.5);
    float dist = length(dir);
    float band = 0.09;
    float ring = smoothstep(progress - band, progress, dist)
               * (1.0 - smoothstep(progress, progress + band, dist));
    ring *= smoothstep(0.0, 0.03, progress);   // fully inert while progress = 0
    vec2 offset = (dir / max(dist, 0.001)) * ring * strength * (1.0 - progress);
    COLOR = texture(screen_tex, SCREEN_UV - offset);
}
```

Godot snapshots the screen automatically for screen-reading materials; you only need a **BackBufferCopy** node when you want to control the copied region or force a fresh copy between stacked screen-readers.
*Timing hook:* `progress` — a one-shot tween over ~0.4 s. Wiring in §4.4.

### 3.3 Circuitry paths

**Flowing trace (Line2D + scroll shader).** Draw the trace with a **Line2D** — around the character, along a button's border, into the silhouette. Give it a dash/circuit strip texture, *Texture Mode: Tile*, and set the node's *CanvasItem → Texture → Repeat: Enabled*. Then scroll:

```glsl
shader_type canvas_item;
uniform float flow_speed = 0.6;

void fragment() {
    COLOR = texture(TEXTURE, UV - vec2(TIME * flow_speed, 0.0));
}
```

Energy now runs along the wire, forever, for free.
*Timing hook:* `flow_speed` and `modulate` — spike both for a power surge (§5.2). One catch: because the phase is `TIME * flow_speed`, changing speed mid-run jumps the pattern — which conveniently reads as a glitch. §4.5 shows the smooth-speed-change fix.

**Spark riding a path (Path2D + PathFollow2D).** Draw the circuit as a **Path2D**; add a **PathFollow2D** (*Loop* ✓) with a glowing sprite or small particle emitter as its child:

```gdscript
@onready var spark: PathFollow2D = $CircuitPath/Spark

func _process(delta: float) -> void:
    spark.progress += 260.0 * delta   # pixels per second; wraps while Loop is on
```

Several pulses on one trace: multiple PathFollow2Ds offset by `progress_ratio += 1.0 / count`. For eased, non-constant travel, tween `progress_ratio` instead of advancing it in `_process`.
*Timing hook:* `progress` / `progress_ratio` — a number a tween or AnimationPlayer can own outright.

**Circuit crawling on the body (shader overlay).** Mask a scrolling circuit texture by the sprite's own alpha, so traces live only inside the silhouette — very much a cyborg's idle:

```glsl
shader_type canvas_item;

uniform sampler2D circuit_tex : repeat_enable, filter_linear;
uniform float crawl_speed = 0.15;
uniform float energy : hint_range(0.0, 3.0) = 1.0;

void fragment() {
    vec4 base = texture(TEXTURE, UV);
    float trace = texture(circuit_tex, UV + vec2(TIME * crawl_speed, 0.0)).r;
    vec3 glow = vec3(0.3, 1.0, 0.9) * trace * base.a * energy;
    COLOR = base + vec4(glow, 0.0);
}
```

A **NoiseTexture2D** (FastNoiseLite, *Seamless* ✓) works as a lazy circuit source; purpose-drawn circuit art reads far better.
*Timing hook:* `energy` — 0 dormant, 1 idle hum, 3 overload.

### 3.4 Parallax

**Scene parallax.** For backgrounds and midgrounds, **Parallax2D** (4.3+): one node per layer, `scroll_scale` below 1 pushes a layer into the distance, above 1 pulls it closer than the camera plane, and `autoscroll` drifts it with no camera at all. (Pre-4.3 projects use the older ParallaxBackground + ParallaxLayer pair; same idea.)

**Local parallax around a character or button (mouse-reactive).** The "card depth" illusion: layers shift against each other as the pointer moves. Layers sit at `(0, 0)` and get nudged:

```gdscript
extends Control   # button root; FX layers are Sprite2D/Node2D children

@export var depth_px := 10.0

func _process(_delta: float) -> void:
    var rel := (get_local_mouse_position() / size - Vector2(0.5, 0.5))
    rel = rel.clamp(Vector2(-0.5, -0.5), Vector2(0.5, 0.5))
    $DeepAura.position   = -rel * depth_px          # far layer: opposite, most
    $Flipbook.position   = -rel * depth_px * 0.45   # middle
    $NearSparks.position =  rel * depth_px * 0.3    # near layer: leans toward pointer
```

(If a layer's resting position isn't `(0,0)`, record it in `_ready()` and add the nudge to it. On `mouse_exited`, tween the offsets back to rest so the card doesn't freeze mid-lean.) The same trick works on a world character by substituting camera movement for the mouse: nudge aura layers by a fraction of the camera's velocity and the character gains physical depth.
*Timing hook:* none needed — the pointer/camera *is* the clock. That's what makes parallax feel alive.

### 3.5 Fireburst

**The GPUParticles2D one-shot archetype.** One node, mostly Inspector work:

| Property | Value | Why |
|---|---|---|
| Amount | 24–48 | enough to read as a burst |
| Lifetime | 0.5–0.8 s | short = snappy |
| One Shot | ✓ | fire once, then silence |
| Explosiveness | 1.0 | every particle spawns at t = 0 |
| Process Material → Spread | 180° | full circle |
| → Initial Velocity | 250–450 | the pop |
| → Gravity | (0, 600) embers · (0, 0) space | |
| → Damping | 40–80 | sparks decelerating feels physical |
| → Scale → Curve | ramp down | sparks shrink as they die |
| → Color → Ramp | white → orange → transparent | the fire read |
| Node's Material | CanvasItemMaterial, Blend: Add | fire is light, not paint |

Fire it with `$Burst.restart()` — reliable even if the last burst is still mid-air (`one_shot` emitters don't cleanly re-arm from `emitting = true` alone). The `finished` signal (4.2+) fires when the last particle dies — chain cleanup or a follow-up effect there.

**Your PNG sequences as the particles (particle flipbook).** The burst can be made of tiny hand-drawn flipbooks — a 4×2 sheet of a flame lick, say:

- *Texture*: the sprite sheet, on the GPUParticles2D.
- *Node's Material*: CanvasItemMaterial → **Particles Animation** ✓, set *H Frames* / *V Frames*, *Loop* off.
- *Process Material → Animation*: *Speed* min & max = 1.0 → each particle plays the whole sheet exactly once over its lifetime.

Hand-drawn frames, procedurally spawned: the exact bridge between flipbook craft and particle systems.

**Charge & release.** Run a second, *looping* emitter with negative *Radial Accel* (≈ −180) so motes get sucked **into** the body — that's the charge-up. On trigger: stop it, `restart()` the burst, fire the §3.2 shockwave, and spike `modulate` white for ~2 frames. Flash (0.05 s) → burst + shockwave (0.4 s) → afterglow fade (0.5 s) is the classic impact stack, and it's one AnimationPlayer animation or one Tween chain (§4).
*Timing hook:* `restart()`, `emitting`, and the `finished` signal.

### 3.6 Orbit

**Pivot rotation (simplest).** A Node2D pivot centered on the sprite; satellites are children parked at `(radius, 0)`:

```gdscript
extends Node2D   # OrbitPivot
@export var rpm := 24.0

func _process(delta: float) -> void:
    rotation += TAU * (rpm / 60.0) * delta
    $Mote.rotation = -rotation   # keep the satellite's art upright
```

**Pseudo-3D ellipse with a front/back pass.** Flatten the circle and flip depth as the satellite crosses the sprite — the moment `z_index` swaps is what sells the orbit as three-dimensional:

```gdscript
extends Sprite2D   # Mote, sibling of the flipbook
@export var radius := Vector2(90.0, 22.0)   # wide + flat = tilted orbital plane
@export var speed := 2.4                    # radians per second
var t := 0.0

func _process(delta: float) -> void:
    t += speed * delta
    position = Vector2(cos(t) * radius.x, sin(t) * radius.y)
    z_index = 1 if sin(t) > 0.0 else -1     # in front of / behind the flipbook
    var depth := (sin(t) + 1.0) * 0.5
    scale = Vector2.ONE * lerp(0.8, 1.15, depth)
    modulate.a = lerp(0.55, 1.0, depth)
```

**Particle orbits.** *Orbit Velocity* min/max on a ParticleProcessMaterial (in 2D: revolutions per second around the emitter) gives you a swirling halo with zero scripting; combine with slight outward *Radial Accel* for spirals.

**Path orbits.** Any closed Path2D + PathFollow2D (§3.3) — ellipses, figure-eights, heart-shaped orbits; tween `progress_ratio` with easing and the orbit hesitates and rushes.
*Timing hook:* `rpm` / `speed` / `progress_ratio` — and `t` itself if you want to scrub an orbit by hand from a timeline.

### 3.7 The rest of the toy box

**Dissolve / materialize.** Threshold a noise texture against a sliding value; tint the crumbling edge:

```glsl
shader_type canvas_item;

uniform sampler2D noise_tex : repeat_enable;   // NoiseTexture2D, Seamless ✓
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.6, 0.15, 1.0);

void fragment() {
    vec4 base = texture(TEXTURE, UV);
    float n = texture(noise_tex, UV).r;
    base.a *= step(dissolve, n);
    float burning = step(0.0001, dissolve);
    base.rgb = mix(base.rgb, edge_color.rgb,
                   burning * (1.0 - smoothstep(dissolve, dissolve + 0.12, n)));
    COLOR = base;
}
```

Tween `dissolve` 0 → 1 for death/teleport-out; 1 → 0 to materialize.

**Afterimage ghosts.** The flipbook will tell you what it's currently showing — snapshot that frame as a fading copy:

```gdscript
func spawn_ghost() -> void:
    var s := $AnimatedSprite2D
    var ghost := Sprite2D.new()
    ghost.texture = s.sprite_frames.get_frame_texture(s.animation, s.frame)
    ghost.global_transform = s.global_transform
    ghost.modulate = Color(0.6, 0.85, 1.0, 0.5)
    get_tree().current_scene.add_child(ghost)
    var t := ghost.create_tween()
    t.tween_property(ghost, "modulate:a", 0.0, 0.35)
    t.tween_callback(ghost.queue_free)
```

Call it from a repeating Timer while dashing → speed trail that inherits the pose, frame by frame.

**And briefly:** *heat haze* is the §3.2 screen shader with noise instead of a ring; *hologram* is the wobble shader plus horizontal scanline stripes (darken every other band of `UV.y`) plus a cyan tint; *squash & stretch* is a two-step scale tween — `(1.15, 0.85)` on impact, back to `(1, 1)` with `TRANS_BACK` — cheap and enormous; *floating motes* are a looping GPUParticles2D with amount ≈ 6, slow upward drift, slight angular velocity, additive blend.

### 3.8 Text has its own VFX rail

The same study applies to words. **RichTextLabel** (with *BBCode Enabled*) ships animated tags: `[wave amp=40 freq=4]`, `[shake rate=20 level=8]`, `[pulse freq=1.2 color=#ffffff66]`, `[rainbow]`, `[tornado]`, `[fade]`. Custom per-glyph motion is one small resource:

```gdscript
@tool
class_name FlickerFX
extends RichTextEffect

var bbcode = "flicker"

func _process_custom_fx(c: CharFXTransform) -> bool:
    c.offset.y += sin(c.elapsed_time * 8.0 + float(c.relative_index) * 0.7) * 2.0
    c.color.a *= 0.75 + 0.25 * sin(c.elapsed_time * 20.0 + float(c.relative_index))
    return true
```

Add it to the label's *Markup → Custom Effects* array, then write `[flicker]…[/flicker]`. Two more doors: a Label is a CanvasItem, so every on-sprite shader in this section (wobble, dissolve, rim glow) applies to text unchanged; and for title/logo text, hand-drawn letters as individual flipbooks — one AnimatedSprite2D per glyph, each `play()` started a few frames apart — outclass any font effect.

---

## 4. Timing, looping, cycling, triggering

The question was "how/if these can be timed, looped, set to cycle through programmed movements over time, or fired by a trigger." All four — and the craft is picking the right clock for each effect.

### 4.1 The four clocks (plus the trigger fabric)

| Clock | Loops? | Sequences? | Trigger from code? | Visible in editor? | Best at |
|---|---|---|---|---|---|
| Shader `TIME` | endlessly, via `sin`/`fract` | no | indirectly (drive uniforms) | no | ambient self-running FX |
| **AnimationPlayer** | Linear & Ping-Pong | multi-track keyframes + method calls | `play("name")` | yes — a timeline | authored, art-directed sequences |
| **Tween** | `set_loops()` | chained + `parallel()` steps | created on the spot | no | reactive, parameterized, fire-and-forget |
| **Timer** | repeats | no (it schedules) | `start()` → `timeout` | node only | heartbeats, cooldowns, phase changes |

Underneath them runs the **signal fabric**: `pressed`, `mouse_entered`, `input_event`, `frame_changed`, `animation_looped`, `animation_finished`, `finished` (particles), `timeout` — any event can start, stop, or redirect any clock. When named states and transitions outgrow a simple playlist, **AnimationTree** adds a proper state machine with crossfades.

Everything composes. An "idle effect" is just an effect triggered by a clock; a "click effect" is the same effect triggered by a signal. Build the effect once, expose one knob (a uniform, a `progress`, a `restart()`), and let any conductor own it.

### 4.2 Looping cleanly — and in sync with the flipbook

Loops that don't pop at the seam:

- **Shaders**: build motion from `sin`/`cos` of `TIME`, or `fract(TIME / period)` — the value at the end of the period must equal the start.
- **AnimationPlayer**: loop mode lives on the Animation resource — *Linear* (wrap) or *Ping-Pong* (there and back; lovely for breathing).
- **Tween**: `create_tween().set_loops()` forever, or `set_loops(3)`.

Syncing FX to the flipbook's own loop is where it gets musical. The loop period is `frames / fps` (8 frames at 12 fps ≈ 0.667 s); giving a glow tween that duration or an integer multiple keeps them in phase. But two approaches are drift-proof by construction:

**One master timeline.** The §1.2 setup — AnimationPlayer keyframing the sheet's `frame` — can keyframe the aura scale, `glow_strength`, and particle `emitting` *in the same animation*. One timeline, zero drift, and Ping-Pong applies to the whole ensemble.

**React to the flipbook's signals.** Let the frames themselves fire the effects:

```gdscript
func _ready() -> void:
    $AnimatedSprite2D.frame_changed.connect(_on_frame)
    $AnimatedSprite2D.animation_looped.connect(_on_looped)

func _on_frame() -> void:
    match $AnimatedSprite2D.frame:
        2: $FootDust.restart()   # left foot contact frame
        6: $FootDust.restart()   # right foot contact frame

func _on_looped() -> void:
    if randf() < 0.15:
        $FXAnim.play("static_crackle")   # occasional flourish, always loop-aligned
```

Frame-synced effects keep a walk honest — dust exactly on the contact frames, always, even if you later change the FPS or `speed_scale` (the *signal* moves with the frames; a parallel stopwatch wouldn't).

### 4.3 Cycling through programmed movement sets

Three tiers, in order of ceremony:

**The playlist.** Author several *non-looping* AnimationPlayer animations and chain them on `animation_finished` — the cycle is the loop:

```gdscript
var cycle := ["breathe", "circuit_surge", "double_pulse"]
var i := 0

func _ready() -> void:
    $FXAnim.animation_finished.connect(_next)
    $FXAnim.play(cycle[0])

func _next(_finished: StringName) -> void:
    i = (i + 1) % cycle.size()
    $FXAnim.play(cycle[i])
```

(`animation_finished` never fires for a looping animation, so playlist entries must be non-looping.) Swap the increment for `cycle.pick_random()` — or a weighted pick — and the idle stops feeling metronomic.

**Timer-driven phases.** A repeating Timer's `timeout` advances a phase variable; each phase re-targets uniforms and tweens. Right when the effects are code-built rather than authored on a timeline.

**AnimationTree state machine.** Named states (`idle_soft`, `idle_surge`, `alert`, `burst`) with transitions, *auto-advance* for self-running cycles, `travel("alert")` from code, and crossfading between states instead of hard cuts. Worth adopting once triggers must interrupt cycles gracefully and return.

### 4.4 Triggers — onClick, hover, gameplay, schedule

**onClick, UI flavor (buttons).** Control nodes emit the signals directly:

```gdscript
func _ready() -> void:
    $SparkButton.pressed.connect(burst)
    $SparkButton.mouse_entered.connect(_hover_on)
    $SparkButton.mouse_exited.connect(_hover_off)
```

For alpha-accurate clicks — ignoring the transparent corners of the button art — TextureButton takes a click mask built straight from a frame's alpha:

```gdscript
var mask := BitMap.new()
mask.create_from_image_alpha(
    $Flipbook.sprite_frames.get_frame_texture("idle", 0).get_image())
$SparkButton.texture_click_mask = mask
```

One gotcha: a *Control-type* decoration stacked over a button (a TextureRect frame, say) eats clicks unless its *Mouse → Filter* is set to *Ignore*. Node2D children — sprites, particles — never intercept mouse input, so FX layers made of those are safe by default.

**onClick, world flavor (the protagonist).** An AnimatedSprite2D isn't clickable by itself; give it an Area2D + CollisionShape2D sibling:

```gdscript
func _ready() -> void:
    $ClickArea.input_event.connect(_clicked)
    $ClickArea.mouse_entered.connect(_glow_up)     # hover works here too
    $ClickArea.mouse_exited.connect(_glow_down)

func _clicked(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
    if event is InputEventMouseButton and event.pressed \
    and event.button_index == MOUSE_BUTTON_LEFT:
        pop()
```

**Gameplay triggers.** Any script can simply call `pop()` — or, cleaner, gameplay code emits its own signals (`signal damaged`) and the FX layer connects to them. The effect never needs to know *why* it fired.

**Scheduled triggers.** A repeating **Timer** node for periodic pulses; `get_tree().create_timer(2.0).timeout` for one-offs; and §4.3's playlist for "every so often, do the next thing."

**Interrupting gracefully.** `AnimationPlayer.play()` cuts to the new animation immediately (set *blend times* for a crossfade). Tweens must be killed before re-firing, or two of them will fight over the same property:

```gdscript
var _pulse: Tween

func pulse() -> void:
    if _pulse: _pulse.kill()
    _pulse = create_tween()
    # ...build the new pulse...
```

### 4.5 One conductor, any instrument: driving shader uniforms

Uniforms are the bridge between clocks and shaders — this is the single most load-bearing pattern in the whole note:

```gdscript
func set_glow(v: float) -> void:
    ($AnimatedSprite2D.material as ShaderMaterial)\
        .set_shader_parameter("glow_strength", v)

# from a tween — spike on click, settle over half a second:
create_tween().tween_method(set_glow, 3.0, 1.0, 0.5)\
    .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
```

AnimationPlayer can keyframe the very same value — add a property track on `AnimatedSprite2D:material:shader_parameter/glow_strength` — so authored timelines and reactive tweens can share one knob (just not simultaneously).

**The sharing gotcha.** A ShaderMaterial is a *resource*, shared by every node that uses it: set a uniform on one clone and every clone changes. Fixes, in order of convenience — tick *Resource → Local to Scene* on the material; or `material = material.duplicate()` in `_ready()`; or (4.4+) declare `instance uniform float glow_strength;` in the shader so each node stores its own value per instance.

**Smoothly changing a speed.** Anything phased as `TIME * speed` jumps when `speed` changes. When the jump isn't the effect you want, accumulate the phase yourself and pass *it* instead:

```gdscript
var flow_speed := 0.6
var _phase := 0.0

func _process(delta: float) -> void:
    _phase += flow_speed * delta
    $Trace.material.set_shader_parameter("flow_phase", _phase)
```

```glsl
uniform float flow_phase = 0.0;
// in fragment():  COLOR = texture(TEXTURE, UV - vec2(flow_phase, 0.0));
```

Now `flow_speed` can be tweened freely — surge, crawl, reverse — and the pattern never skips.

---

## 5. Two worked recipes

### 5.1 Protagonist: breathing glow + orbiting mote + click-burst

```
Protagonist (Node2D)                 protagonist.gd
├── Aura (Sprite2D)                  show_behind_parent ✓, additive blob (§3.1)
├── AnimatedSprite2D                 flipbook "idle", loop ✓, rim-glow material (§3.1)
├── Mote (Sprite2D)                  pseudo-3D orbit script (§3.6)
├── Burst (GPUParticles2D)           one-shot fireburst (§3.5)
├── Shockwave (Sprite2D)             screen-refraction material (§3.2)
├── FXAnim (AnimationPlayer)         "breathe" (loop ✓) · "shockwave" (loop ✗)
└── ClickArea (Area2D)
    └── CollisionShape2D
```

`breathe` keyframes Aura `scale` + `modulate:a` and the rim shader's `glow_strength`, Ping-Pong, its length matching the flipbook period (§4.2). `shockwave` keyframes the ring's `progress` 0 → 1, a 2-frame white `modulate` flash, and an Aura kick. The script only conducts:

```gdscript
extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var fx: AnimationPlayer = $FXAnim
var _glow: Tween

func _ready() -> void:
    sprite.play("idle")
    fx.play("breathe")
    fx.animation_finished.connect(_back_to_idle)
    $ClickArea.input_event.connect(_clicked)

func _clicked(_v: Node, e: InputEvent, _s: int) -> void:
    if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
        pop()

func pop() -> void:
    $Burst.restart()
    fx.play("shockwave")                       # interrupts "breathe" cleanly
    if _glow: _glow.kill()
    _glow = create_tween()
    _glow.tween_method(_set_glow, 3.0, 1.0, 0.5)\
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _back_to_idle(anim: StringName) -> void:
    if anim == &"shockwave":
        fx.play("breathe")

func _set_glow(v: float) -> void:
    (sprite.material as ShaderMaterial).set_shader_parameter("glow_strength", v)
```

All three conducting styles in ~30 lines: a time-based loop (`breathe`), an event chain (`shockwave` → back to `breathe` via signal), and an input trigger (click → `pop()` → particles + timeline + tween at once).

### 5.2 Button: hover parallax + press circuit-surge

```
SparkButton (TextureButton)          spark_button.gd — faint frame texture + click mask (§4.4)
├── DeepAura (Sprite2D)              additive blob
├── Flipbook (AnimatedSprite2D)      looping button art
├── Trace (Line2D)                   circuit border, flow shader (§3.3, flow_phase variant)
└── Motes (GPUParticles2D)           amount 6, drifting, additive
```

```gdscript
extends TextureButton

@export var depth_px := 10.0
@onready var trace_mat: ShaderMaterial = $Trace.material
var flow_speed := 0.6
var _phase := 0.0

func _ready() -> void:
    pressed.connect(_surge)
    mouse_entered.connect(_lean.bind(true))
    mouse_exited.connect(_lean.bind(false))

func _process(delta: float) -> void:
    # circuit flow (smooth-speed variant from §4.5)
    _phase += flow_speed * delta
    trace_mat.set_shader_parameter("flow_phase", _phase)
    # hover parallax (§3.4)
    var rel := (get_local_mouse_position() / size - Vector2(0.5, 0.5))
    rel = rel.clamp(Vector2(-0.5, -0.5), Vector2(0.5, 0.5))
    $DeepAura.position = -rel * depth_px
    $Motes.position    =  rel * depth_px * 0.4

func _lean(hovering: bool) -> void:
    var t := create_tween()
    t.tween_property($Flipbook, "scale",
        Vector2.ONE * (1.06 if hovering else 1.0), 0.15)\
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _surge() -> void:
    var t := create_tween()
    t.tween_property($Trace, "modulate", Color(2.0, 2.0, 2.0), 0.05)   # >1: blooms under HDR-2D glow
    t.tween_property($Trace, "modulate", Color.WHITE, 0.45)
    t.parallel().tween_method(_set_speed, 4.0, 0.6, 0.5)

func _set_speed(v: float) -> void:
    flow_speed = v
```

Press it: the trace flashes over-bright (bloom flare if §3.1's HDR-2D glow is on), energy races around the border and coasts back to idle, and the whole card leans with the pointer throughout.

---

## 6. Gotchas & performance notes

**Materials are shared** until you make them not-shared (*Local to Scene*, `duplicate()`, or instance uniforms — §4.5). The classic symptom: hovering one button lights up all of them.

**Padding, again.** On-sprite shaders can't paint outside the texture rectangle. Halos clipping flat = re-export frames with transparent margin.

**Edge fringing on translucent art.** Dark or miscolored halos at soft edges usually mean the frames' RGB is garbage in fully-transparent pixels and linear filtering is dragging it in. Export with "bleed"/padded color under the alpha, or explore premultiplied-alpha blending (supported in recent 4.x) if it persists.

**Overdraw is the 2D budget.** Every stacked translucent layer redraws its rectangle; a handful per character is nothing, forty ambient auras are a mobile GPU on its knees. Screen-reading shaders and HDR-2D glow are the two most expensive tools here — wonderful, but count them.

**Sleep when unseen.** A VisibleOnScreenNotifier2D's `screen_exited` → pause the FX AnimationPlayer, set emitters' `emitting = false`; `screen_entered` wakes them.

**Pool one-shots.** Pre-place burst emitters and `restart()` them rather than instancing scenes at click-time; instancing mid-click is how a crisp effect gains three frames of lag.

**`TIME` is global.** Two instances of the same shader idle in identical phase — uncanny in a row of buttons. Add a per-instance phase-offset uniform (randomize it in `_ready()`) to desynchronize.

**Everything has a `speed_scale`** — AnimatedSprite2D, AnimationPlayer, particles. Setting them all to 0.1 is a surprisingly effective way to audit an effect stack frame by frame.

---

## 7. Where this sits, and pointers

Within *sparks-and-sprites*, `cheatsheets/vfx.md` catalogs the cross-engine *what* (glow, trail, dissolve, shockwave, …); this note is the Godot-specific *how*, wrapped around a flipbook, plus the conducting layer. The working companion is `demos/godot/scenes/flipbook_vfx.gd` (press **F** on the demo menu) — one scene wearing most of this note at once, with its two shaders in `demos/godot/shaders/` (`rim_glow`, `circuit_flow`).

Official docs worth keeping open while experimenting:

- 2D particle systems — https://docs.godotengine.org/en/stable/tutorials/2d/particle_systems_2d.html
- CanvasItem shaders — https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html
- Screen-reading shaders — https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html
- Animation (AnimationPlayer, tracks, AnimationTree) — https://docs.godotengine.org/en/stable/tutorials/animation/index.html
- BBCode & RichTextEffect — https://docs.godotengine.org/en/stable/tutorials/ui/bbcode_in_richtextlabel.html
- 2D lights, environment & glow — https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html

