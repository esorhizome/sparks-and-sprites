extends Node2D
## FLIPBOOK VFX — one white-on-transparent loop, wearing its effects.
## An 8-frame flipbook plays forever in the middle; everything else breathes,
## flows, orbits and bursts AROUND it, each effect on its own clock:
##   · aura breath    — a looping tween, period-locked to the flipbook loop
##   · rim glow       — a shader on the sprite itself (shaders/rim_glow.gdshader)
##   · circuit track  — Line2D dashes flowing on an ellipse (shaders/circuit_flow.gdshader)
##   · orbit mote     — a scripted ellipse that z-flips behind/in front mid-lap
##   · idle cycle     — calm → surge → pulse, a Timer turning the page (keys 1–3 jump)
##   · click burst    — sparks + flame flipbook-particles + ring + glow spike, at once
##   · a living button — hover parallax, press = circuit surge (and it pokes the wisp)
## Click the wisp = burst. Click anywhere = ripple. RIGHT-CLICK swaps the
## dark/light ground — the SAME white frames survive both themes because
## `modulate` multiplies (white art is tintable art). Esc = menu.
## Chapters 03, 06, 12 — long-form companion: cheatsheets/godot-flipbook-vfx.md.
##
## The frames are GENERATED below (~a second of honest math at load) so nothing
## hides in an asset file. To use real art, make _wisp_frames() return your own:
##   return [load("res://art/me_000.png"), load("res://art/me_001.png"), ...]

const FRAME_COUNT := 8
const FPS := 12.0
const LOOP_SECONDS := FRAME_COUNT / FPS   # ≈0.667 s — the beat everything dances to
const CENTER := Vector2(480, 310)
const PHASES := ["calm", "surge", "pulse"]  # the idle cycle (guide §4.3)

# Right-click swaps these. White frames + modulate = one loop, every theme;
# note what ELSE must move with the ground: aura blend, glow hue, particle ink.
const GROUNDS := {
	"dark": {
		"bg": Color(0.098, 0.082, 0.153), "ink": Color(1, 1, 1),
		"body": Color(1, 1, 1), "glow": Color(0.45, 0.9, 1.0),
		"aura": Color(0.45, 0.55, 1.0, 0.55), "additive": true,
	},
	"light": {
		"bg": Color(0.93, 0.905, 0.855), "ink": Color(0.17, 0.14, 0.25),
		"body": Color(0.17, 0.14, 0.25), "glow": Color(1.0, 0.55, 0.2),
		"aura": Color(0.17, 0.13, 0.25, 0.30), "additive": false,
	},
}

var ground := "dark"
var phase := "calm"
var glow_base := 1.1        # rim glow at rest for the current phase
var orbit_speed := 1.6      # radians per second — phases retune it
var flow_speed := 0.6       # circuit dashes in tiles/sec — tweened on surges
var _flow_phase := 0.0      # accumulated BY HAND so speed changes never skip (§4.5)
var _orbit_t := 0.0

var bg: ColorRect
var caption: Label
var wisp: AnimatedSprite2D
var wisp_mat: ShaderMaterial
var aura: Sprite2D
var aura_mat: CanvasItemMaterial
var track: Line2D
var circuit_mat: ShaderMaterial
var mote: Sprite2D
var burst: CPUParticles2D
var flames: CPUParticles2D
var flame_mat: CanvasItemMaterial
var puff: CPUParticles2D
var button: TextureButton
var btn_aura: Sprite2D
var btn_aura_mat: CanvasItemMaterial
var btn_sprite: AnimatedSprite2D
var btn_track: Line2D
var blob_tex: ImageTexture
var ring_tex: ImageTexture
var phase_timer: Timer
var _breathe: Tween
var _spike: Tween
var _flow_tw: Tween

func _ready() -> void:
	blob_tex = _soft_blob_texture(96)
	ring_tex = _ring_texture(96)

	bg = ColorRect.new()
	bg.size = get_viewport_rect().size
	add_child(bg)

	# ── the circuit track: an ellipse of flowing dashes (guide §3.3) ──────────
	# The mote below rides the SAME ellipse, so circuitry and orbit read as one.
	track = Line2D.new()
	var pts := PackedVector2Array()
	for i in 49:  # 48 segments + repeat of the first point = a closed loop
		var a := TAU * float(i % 48) / 48.0
		pts.append(CENTER + Vector2(cos(a) * 150.0, sin(a) * 44.0))
	track.points = pts
	track.width = 7.0
	track.texture = _dash_texture()
	track.texture_mode = Line2D.LINE_TEXTURE_TILE
	# TILE mode needs the sampler to wrap, or every tile past the first clamps
	# to the texture's (transparent) edge and the line shows a single dash:
	track.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	circuit_mat = ShaderMaterial.new()
	circuit_mat.shader = load("res://shaders/circuit_flow.gdshader")
	track.material = circuit_mat
	add_child(track)

	# ── the aura: an additive blob BEHIND the flipbook (guide §3.1) ───────────
	aura = Sprite2D.new()
	aura.texture = blob_tex
	aura.position = CENTER
	aura.scale = Vector2.ONE * 3.4
	aura_mat = CanvasItemMaterial.new()
	add_child(aura)
	aura.material = aura_mat

	# ── the flipbook itself: generated frames → SpriteFrames → play (§1.1) ───
	wisp = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.add_animation(&"idle")
	sf.set_animation_speed(&"idle", FPS)
	sf.set_animation_loop(&"idle", true)
	for tex in _wisp_frames():
		sf.add_frame(&"idle", tex)
	wisp.sprite_frames = sf
	wisp.position = CENTER
	wisp.scale = Vector2.ONE * 2.0
	wisp_mat = ShaderMaterial.new()
	wisp_mat.shader = load("res://shaders/rim_glow.gdshader")
	# seed the uniform once: a tween can't read a "current value" that was
	# never set (the shader's default lives in the shader, not the material)
	wisp_mat.set_shader_parameter("glow_strength", glow_base)
	wisp.material = wisp_mat
	add_child(wisp)
	wisp.play(&"idle")
	# frame-synced FX (§4.2): the signal moves WITH the frames, so these puffs
	# stay on the bob's down-beats even if you change FPS or speed_scale.
	wisp.frame_changed.connect(_on_frame)

	# ── the orbit mote: ellipse + z-flip = fake 3D (guide §3.6) ───────────────
	mote = Sprite2D.new()
	mote.texture = blob_tex
	mote.scale = Vector2.ONE * 0.55
	add_child(mote)

	# ── pooled one-shot emitters (§3.5; pre-made and restart()ed — §6) ────────
	burst = _make_burst()
	add_child(burst)
	flames = _make_flames()
	add_child(flames)
	puff = _make_puff()
	add_child(puff)

	# ── the living button: parallax layers + circuit border (§3.4, §5.2) ──────
	_build_button()

	caption = Label.new()
	caption.position = Vector2(24, 16)
	add_child(caption)

	# ── the idle cycle conductor: a Timer turns the page every 4 s (§4.3) ─────
	phase_timer = Timer.new()
	phase_timer.wait_time = 4.0
	phase_timer.timeout.connect(_advance_phase)
	add_child(phase_timer)
	phase_timer.start()

	_apply_ground()
	_enter_phase("calm")

func _build_button() -> void:
	button = TextureButton.new()
	button.position = Vector2(700, 255)
	button.texture_normal = _button_frame_texture(180, 110)
	# alpha-accurate clicks: the mask is a FILLED rounded rect, so the whole
	# interior is pressable even though only the stroke is visible (§4.4).
	var mask := BitMap.new()
	mask.create_from_image_alpha(_rounded_rect_image(180, 110, true))
	button.texture_click_mask = mask
	add_child(button)

	btn_aura = Sprite2D.new()
	btn_aura.texture = blob_tex
	btn_aura.position = Vector2(90, 55)
	btn_aura.scale = Vector2.ONE * 1.6
	btn_aura_mat = CanvasItemMaterial.new()
	btn_aura.material = btn_aura_mat
	button.add_child(btn_aura)

	btn_sprite = AnimatedSprite2D.new()
	btn_sprite.sprite_frames = wisp.sprite_frames   # SHARED SpriteFrames — cheap, safe
	btn_sprite.position = Vector2(90, 58)
	btn_sprite.scale = Vector2.ONE * 0.8
	btn_sprite.material = wisp_mat.duplicate()      # DUPLICATED material — uniforms are
	button.add_child(btn_sprite)                    # per-character (the §4.5 gotcha, dodged)
	btn_sprite.play(&"idle")

	btn_track = Line2D.new()
	var pts := PackedVector2Array()
	for p in [Vector2(4, 4), Vector2(176, 4), Vector2(176, 106), Vector2(4, 106), Vector2(4, 4)]:
		pts.append(p)   # a plain rectangle border reads fine at this width
	btn_track.points = pts
	btn_track.width = 4.0
	btn_track.texture = _dash_texture()
	btn_track.texture_mode = Line2D.LINE_TEXTURE_TILE
	btn_track.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	btn_track.material = circuit_mat   # SHARED on purpose: one conductor, two wires —
	button.add_child(btn_track)        # press the button and BOTH circuits surge (§4.5)

	button.pressed.connect(_on_button_pressed)
	button.mouse_entered.connect(_lean.bind(true))
	button.mouse_exited.connect(_lean.bind(false))

func _process(delta: float) -> void:
	# circuit flow: integrate the phase ourselves so surges never skip (§4.5)
	_flow_phase += flow_speed * delta
	circuit_mat.set_shader_parameter("flow_phase", _flow_phase)

	# orbit mote: ellipse position + depth cues + the z-flip (§3.6)
	_orbit_t += orbit_speed * delta
	mote.position = CENTER + Vector2(cos(_orbit_t) * 150.0, sin(_orbit_t) * 44.0)
	mote.z_index = 1 if sin(_orbit_t) > 0.0 else -1   # in front ↔ behind the wisp
	var depth := (sin(_orbit_t) + 1.0) * 0.5
	mote.scale = Vector2.ONE * lerp(0.4, 0.7, depth)
	mote.modulate.a = lerp(0.5, 1.0, depth)

	# button hover parallax: layers lean against the pointer (§3.4)
	var rel := (button.get_local_mouse_position() / button.size - Vector2(0.5, 0.5))
	rel = rel.clamp(Vector2(-0.5, -0.5), Vector2(0.5, 0.5))
	btn_aura.position = Vector2(90, 55) - rel * 12.0     # deep layer: opposite, most
	btn_sprite.position = Vector2(90, 58) - rel * 5.0    # middle layer: less

# ─── the idle cycle: programmed movement sets, cycling over time (§4.3) ───────

func _advance_phase() -> void:
	var i := (PHASES.find(phase) + 1) % PHASES.size()
	_enter_phase(PHASES[i])

func _enter_phase(p: String) -> void:
	phase = p
	var flow_rest := 0.6
	match p:
		"calm":
			glow_base = 1.1
			orbit_speed = 1.6
			_start_breathe("calm")
		"surge":
			glow_base = 1.9
			orbit_speed = 3.6
			flow_rest = 2.4
			_start_breathe("surge")
		"pulse":
			glow_base = 1.4
			orbit_speed = 2.4
			_start_breathe("pulse")
	# glow_strength has ONE owner at a time (§4.4): the phase sets its resting
	# level here; pop() may briefly steal it with a spike tween, then it returns.
	if _spike:
		_spike.kill()
	_spike = create_tween()
	_spike.tween_property(wisp_mat, "shader_parameter/glow_strength", glow_base, 0.5)
	_surge_flow(flow_speed, flow_rest)
	_caption()

## The aura breath — a looping tween whose period is built from LOOP_SECONDS,
## so it stays phase-locked to the flipbook however you retune FPS (§4.2).
func _start_breathe(kind: String) -> void:
	if _breathe:
		_breathe.kill()
	aura.scale = Vector2.ONE * 3.4
	_breathe = create_tween().set_loops()
	match kind:
		"calm":    # in over one flipbook loop, out over the next
			_breathe.tween_property(aura, "scale", Vector2.ONE * 3.62, LOOP_SECONDS)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_breathe.tween_property(aura, "scale", Vector2.ONE * 3.4, LOOP_SECONDS)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		"surge":   # shallower and twice as fast — busy hands, short breath
			_breathe.tween_property(aura, "scale", Vector2.ONE * 3.5, LOOP_SECONDS / 2.0)
			_breathe.tween_property(aura, "scale", Vector2.ONE * 3.4, LOOP_SECONDS / 2.0)
		"pulse":   # a heartbeat: two quick beats, then a rest one loop long
			_breathe.tween_property(aura, "scale", Vector2.ONE * 3.8, 0.12)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_breathe.tween_property(aura, "scale", Vector2.ONE * 3.45, 0.18)
			_breathe.tween_property(aura, "scale", Vector2.ONE * 3.72, 0.12)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_breathe.tween_property(aura, "scale", Vector2.ONE * 3.4, 0.25)
			_breathe.tween_interval(LOOP_SECONDS)

# ─── triggers (§4.4): click, press, hover — all roads lead to the same knobs ──

## The burst: four effects fired by one call. Any script could call this —
## the effect never needs to know WHY it fired (a click, a hit, a cutscene).
func pop() -> void:
	burst.restart()
	flames.restart()
	_ripple(CENTER, 2.6)
	if _spike:
		_spike.kill()
	_spike = create_tween()
	_spike.tween_property(wisp_mat, "shader_parameter/glow_strength", glow_base, 0.55)\
		.from(3.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_surge_flow(4.5, 0.6 if phase != "surge" else 2.4)

## Spike the circuit speed, then coast back to rest. flow_speed is a plain
## script variable feeding an accumulator, so this never skips a dash (§4.5).
func _surge_flow(from_speed: float, rest: float) -> void:
	if _flow_tw:
		_flow_tw.kill()
	flow_speed = from_speed
	_flow_tw = create_tween()
	_flow_tw.tween_property(self, "flow_speed", rest, 1.0)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_button_pressed() -> void:
	_surge_flow(5.5, 0.6 if phase != "surge" else 2.4)   # both circuits: shared material
	var t := create_tween()
	t.tween_property(btn_track, "width", 7.0, 0.06)
	t.tween_property(btn_track, "width", 4.0, 0.4)
	pop()   # the button is a REMOTE trigger for the wisp — gameplay code in one line

var _lean_tw: Tween
func _lean(hovering: bool) -> void:
	if _lean_tw:
		_lean_tw.kill()
	_lean_tw = create_tween()
	_lean_tw.tween_property(btn_sprite, "scale", Vector2.ONE * (0.9 if hovering else 0.8), 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## An expanding ring, made fresh per call and freed when done (§3.2).
func _ripple(at: Vector2, size: float) -> void:
	var g: Dictionary = GROUNDS[ground]
	var ring := Sprite2D.new()
	ring.texture = ring_tex
	ring.position = at
	ring.modulate = g.glow if g.additive else g.ink
	var mat := CanvasItemMaterial.new()
	if g.additive:
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ring.material = mat
	add_child(ring)
	var t := create_tween()
	t.tween_property(ring, "scale", Vector2.ONE * size, 0.45)\
		.from(Vector2.ONE * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(ring, "modulate:a", 0.0, 0.45).from(0.85)
	t.tween_callback(ring.queue_free)

# ─── frame-synced FX (§4.2): fired by the flipbook itself, never by a clock ───

func _on_frame() -> void:
	match wisp.frame:
		2, 6:   # the bob's two down-beats — like footfall contact frames
			puff.restart()

# ─── the ground swap (right-click): one loop, every theme ─────────────────────

func _toggle_ground() -> void:
	ground = "light" if ground == "dark" else "dark"
	_apply_ground()
	_caption()

## Everything that must move when the ground flips. The FRAMES never change —
## white art × modulate covers the body; what needs care is the light around
## it: additive blending disappears on bright grounds, so auras become soft
## shadows and glow hues go warm. (Guide §1.3.)
func _apply_ground() -> void:
	var g: Dictionary = GROUNDS[ground]
	bg.color = g.bg
	wisp.modulate = g.body
	wisp_mat.set_shader_parameter("glow_color", g.glow)
	aura.modulate = g.aura
	aura_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD if g.additive \
		else CanvasItemMaterial.BLEND_MODE_MIX
	track.default_color = g.ink
	mote.modulate = g.glow          # _process only touches its alpha
	burst.color = g.body
	flames.color = g.glow
	flame_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD if g.additive \
		else CanvasItemMaterial.BLEND_MODE_MIX
	puff.color = Color(g.ink.r, g.ink.g, g.ink.b, 0.4)
	button.self_modulate = g.ink
	btn_sprite.modulate = g.body
	(btn_sprite.material as ShaderMaterial).set_shader_parameter("glow_color", g.glow)
	btn_aura.modulate = g.aura
	btn_aura_mat.blend_mode = aura_mat.blend_mode
	btn_track.default_color = g.ink
	caption.modulate = g.ink

func _caption() -> void:
	caption.text = ("FLIPBOOK VFX — one 8-frame loop (generated in code), wearing its effects."
		+ "\nClick the wisp = burst · click anywhere = ripple · press the button · right-click = %s ground"
		+ "\n1-3 = idle phase (now: %s, auto-cycles every 4 s) · Esc = menu"
		+ "\nTry: set FPS to 6 — the aura breath stays locked. Long form: cheatsheets/godot-flipbook-vfx.md") \
		% ["light" if ground == "dark" else "dark", phase]

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_ripple(event.position, 1.0)
			# Clicking the wisp itself = the big trigger (§4.4). An Area2D +
			# `input_event` is the scalable spelling; a plain distance test
			# keeps this demo in one visible code path, like sparks.gd.
			if event.position.distance_to(CENTER) < 80.0:
				pop()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_toggle_ground()
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		var idx: int = event.keycode - KEY_1
		if idx >= 0 and idx < PHASES.size():
			_enter_phase(PHASES[idx])   # a trigger interrupting the cycle…
			phase_timer.start()         # …which then resumes from here (§4.3)

# ─── pooled emitters (§3.5) — CPUParticles2D so behaviour is identical on every
# renderer, exactly like sparks.gd; every property maps 1:1 onto GPUParticles2D. ──

func _make_burst() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = CENTER
	p.emitting = false                    # pooled: pre-made, fired with restart() (§6)
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 40
	p.lifetime = 0.7
	p.texture = _spark_dot_texture()
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 160.0
	p.initial_velocity_max = 420.0
	p.gravity = Vector2(0, 560)
	p.damping_min = 30.0
	p.damping_max = 70.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0.1))
	p.scale_amount_curve = curve          # sparks shrink as they die
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	return p

## The fireburst's soul: each particle is a tiny FLIPBOOK — a 4-frame flame
## sheet, played exactly once over its lifetime ("particle flipbook", §3.5).
func _make_flames() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = CENTER
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 12
	p.lifetime = 0.7
	p.texture = _flame_sheet_texture()
	p.direction = Vector2(0, -1)
	p.spread = 60.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 150.0
	p.gravity = Vector2(0, -140)          # flames rise
	p.scale_amount_min = 1.1
	p.scale_amount_max = 1.7
	p.anim_speed_min = 1.0                # 1.0 = the whole sheet, once per lifetime
	p.anim_speed_max = 1.0
	flame_mat = CanvasItemMaterial.new()
	flame_mat.particles_animation = true  # ← the flipbook switch
	flame_mat.particles_anim_h_frames = 4
	flame_mat.particles_anim_v_frames = 1
	flame_mat.particles_anim_loop = false
	p.material = flame_mat
	return p

func _make_puff() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = CENTER + Vector2(0, 46)  # at the tail's tip — the "contact" spot
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 5
	p.lifetime = 0.5
	p.texture = _spark_dot_texture()
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 45.0
	p.gravity = Vector2(0, -30)
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.5))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	return p

# ─── generated textures — no asset files, no magic (sprite_basics' promise) ───

## The 8 wisp frames. Body = two soft ellipses riding a sine (bob + squash);
## tail = a swaying wick at 38% alpha (properly TRANSLUCENT — the ground reads
## through it); eyes = punched alpha-ZERO holes (effects behind peek through).
## To use your own art, replace this whole function with load()s of your PNGs.
func _wisp_frames() -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for f in FRAME_COUNT:
		var t := float(f) / FRAME_COUNT
		var bob := sin(TAU * t)
		var cy := 58.0 + bob * 4.0          # the body rides a sine…
		var sy := 1.0 + 0.07 * bob          # …and squashes against it
		var sx := 1.0 / sy
		var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		for y in 128:
			for x in 128:
				var dh := Vector2((x - 64.0) / (27.0 * sx), (y - (cy - 8.0)) / (24.0 * sy)).length()
				var db := Vector2((x - 64.0) / (21.0 * sx), (y - (cy + 14.0)) / (18.0 * sy)).length()
				var a := clampf((1.0 - minf(dh, db)) * 5.0, 0.0, 1.0) * 0.92
				var ty := y - (cy + 26.0)
				if ty > 0.0 and ty < 34.0:
					var sway := sin(TAU * t * 2.0 + ty * 0.14) * 5.0
					var w := 13.0 - ty * 0.34
					if w > 0.0:
						a = maxf(a, clampf(1.0 - absf(x - 64.0 - sway) / w, 0.0, 1.0) * 0.38)
				if Vector2(x - 54.0, y - (cy - 10.0)).length() < 3.6:
					a = 0.0
				if Vector2(x - 74.0, y - (cy - 10.0)).length() < 3.6:
					a = 0.0
				if a > 0.003:
					img.set_pixel(x, y, Color(1, 1, 1, a))
		frames.append(ImageTexture.create_from_image(img))
	return frames

## Same recipe as glow.gd — the universal soft glow blob.
func _soft_blob_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)

func _ring_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length()
			var a := clampf(1.0 - absf(d - size * 0.4) / 4.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)

func _spark_dot_texture() -> ImageTexture:
	var s := 20
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := s / 2.0
	for y in s:
		for x in s:
			var a := clampf(1.0 - Vector2(x - c, y - c).length() / c, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)

## One tile of the circuit: a dash and a node-dot, made to repeat.
func _dash_texture() -> ImageTexture:
	var img := Image.create(32, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 32:
			var a := 0.0
			if x >= 2 and x <= 15 and y >= 1 and y <= 6:
				a = 0.95 * clampf(minf(x - 1.0, 16.0 - x) / 2.0, 0.0, 1.0)
			var node_d := Vector2(x - 24.0, y - 3.5).length()
			a = maxf(a, clampf(1.0 - node_d / 2.7, 0.0, 1.0))
			if a > 0.003:
				img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

## A 4×1 flame sheet, 32 px per cell: each cell one moment of a flame lick,
## narrowing and dimming — the frames the particle flipbook plays through.
func _flame_sheet_texture() -> ImageTexture:
	var img := Image.create(128, 32, false, Image.FORMAT_RGBA8)
	for x in 128:
		var k := x / 32          # which cell (0..3)
		var lx := x % 32         # x within the cell
		for y in 32:
			var rel := (27.0 - y) / (21.0 - k * 4.0)   # 0 at the base → 1 at the tip
			if rel < 0.0 or rel > 1.0:
				continue
			var w := 8.5 * (1.0 - rel * 0.85) * (0.6 + 0.4 * sin(rel * PI))
			var flick := sin(rel * 9.0 + float(k) * 1.7) * 1.5
			var a := clampf(1.0 - absf(lx - 16.0 - flick) / maxf(w, 0.6), 0.0, 1.0)
			a *= (1.0 - rel * 0.35) * (1.0 - k * 0.18) * 0.9
			if a > 0.003:
				img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

## Rounded-rectangle image: `filled` for the button's CLICK MASK, outline-only
## for what you actually see. (The mask and the look don't have to match!)
func _rounded_rect_image(w: int, h: int, filled: bool) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r := 14.0
	var hx := w / 2.0 - 3.0
	var hy := h / 2.0 - 3.0
	for y in h:
		for x in w:
			var qx := absf(x - w / 2.0) - (hx - r)
			var qy := absf(y - h / 2.0) - (hy - r)
			var sd := Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length() \
				+ minf(maxf(qx, qy), 0.0) - r
			var a := 0.0
			if filled:
				a = 1.0 if sd < 0.0 else 0.0
			else:
				a = clampf(1.8 - absf(sd), 0.0, 1.0) * 0.95
			if a > 0.003:
				img.set_pixel(x, y, Color(1, 1, 1, a))
	return img

func _button_frame_texture(w: int, h: int) -> ImageTexture:
	return ImageTexture.create_from_image(_rounded_rect_image(w, h, false))
