extends Node2D
## RESPONSIVE CURSOR — hide the real cursor, draw a companion that CHASES it.
## The chase lag is deliberate: fighting draw-latency looks laggy, easing
## into it looks alive. Sparkles shed by distance moved; press = pop.
## Esc = menu (the OS cursor comes back automatically). Chapter 12.

var companion := Vector2.ZERO
var last_mouse := Vector2.ZERO
var travelled := 0.0
var squish := 0.0
var sparkles: Array = []        # untyped: filter() hands back a plain Array
var rings: Array = []

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN   # rule: never hide without a replacement
	companion = get_viewport_rect().size / 2.0
	last_mouse = companion
	var l := Label.new()
	l.text = "Responsive cursor: move, then click.  Esc = menu.\nThe circle CHASES the pointer (x += (target - x) * 12 * dt) — the lag is the personality."
	l.position = Vector2(24, 16)
	add_child(l)

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # hand the cursor back politely

func _process(delta: float) -> void:
	var mouse := get_global_mouse_position()
	companion += (mouse - companion) * minf(1.0, 12.0 * delta)   # the chase
	travelled += mouse.distance_to(last_mouse)
	last_mouse = mouse
	while travelled > 14.0:               # shed sparkles by distance, not time
		travelled -= 14.0
		sparkles.append({
			"pos": companion + Vector2(randf_range(-6, 6), randf_range(-6, 6)),
			"vel": Vector2(randf_range(-20, 20), randf_range(-40, -6)),
			"life": 1.0,
		})
	for s in sparkles:
		s.pos += s.vel * delta
		s.life -= delta * 1.6
	sparkles = sparkles.filter(func(s): return s.life > 0.0)
	for r in rings:
		r.r += 160.0 * delta
		r.a -= 2.2 * delta
	rings = rings.filter(func(r): return r.a > 0.0)
	squish = maxf(0.0, squish - delta * 3.0)
	queue_redraw()

func _draw() -> void:
	for s in sparkles:
		var l: float = 3.5 * s.life
		var c := Color(0.95, 0.9, 1.0, s.life)
		draw_line(s.pos - Vector2(l, 0), s.pos + Vector2(l, 0), c, 1.2)
		draw_line(s.pos - Vector2(0, l), s.pos + Vector2(0, l), c, 1.2)
	for r in rings:
		draw_arc(r.pos, r.r, 0, TAU, 40, Color(0.8, 0.85, 1.0, r.a), 2.5)
	# the companion: a soft circle that flinches (squashes) on press
	draw_set_transform(companion, 0.0, Vector2(1.0 + squish * 0.45, 1.0 - squish * 0.45))
	for ring in 4:
		var k := 1.0 - ring / 4.0
		draw_circle(Vector2.ZERO, 7 + ring * 5, Color(0.61, 0.64, 0.94, 0.22 * k))
	draw_circle(Vector2.ZERO, 5.0, Color(0.9, 0.9, 1.0, 0.95))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		squish = 1.0
		rings.append({ "pos": companion, "r": 8.0, "a": 0.9 })
		for i in 14:
			sparkles.append({
				"pos": companion,
				"vel": Vector2(randf_range(-90, 90), randf_range(-90, 90)),
				"life": 1.0,
			})
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
