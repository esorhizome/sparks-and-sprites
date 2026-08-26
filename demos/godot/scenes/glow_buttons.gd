extends Node2D
## LIVING BUTTONS — the two species from chapter 12, as one scene.
## Button A runs a STATIC LOOP: plasma blobs orbit behind the face.
## Button B is TAP-REACTIVE: a press adds spin VELOCITY (never position);
## per-frame friction turns that push into a free ease-out.
## Click both buttons. Esc = menu.

var t := 0.0
var energy := 0.0                       # button A's press flare
var spin := 0.0
var spin_vel := 0.0
var pulses: Array = []          # untyped: filter() hands back a plain Array
var rect_a := Rect2()
var centre_b := Vector2()
const RADIUS_B := 60.0

func _ready() -> void:
	var size := get_viewport_rect().size
	rect_a = Rect2(size.x / 2.0 - 110, size.y * 0.22, 220, 64)
	centre_b = Vector2(size.x / 2.0, size.y * 0.68)
	var l := Label.new()
	l.text = "Living buttons: click both.  Esc = menu.\nTop = static loop (plasma behind the face).  Bottom = tap adds VELOCITY, friction is the easing."
	l.position = Vector2(24, 16)
	add_child(l)

func _process(delta: float) -> void:
	t += delta
	energy = maxf(0.0, energy - delta * 2.0)
	spin += spin_vel * delta
	spin_vel *= pow(0.15, delta)          # friction → built-in ease-out
	for p in pulses:
		p.r += 90.0 * delta
		p.a -= 1.4 * delta
	pulses = pulses.filter(func(p): return p.a > 0.0)
	queue_redraw()

func _draw() -> void:
	# ---- button A: plasma underlay (three blobs, three speeds) ----
	var mid := rect_a.get_center()
	var cols := [Color(0.47, 0.55, 1.0), Color(1.0, 0.47, 0.78), Color(0.47, 0.9, 0.86)]
	for i in 3:
		var bx := mid.x + cos(t * 0.7 + i * 2.1) * rect_a.size.x * 0.32
		var by := mid.y + sin(t * 1.1 + i * 2.1) * rect_a.size.y * 0.55
		var base: Color = cols[i]
		for ring in 5:                    # layered fading circles ≈ a blurred blob
			var k := 1.0 - ring / 5.0
			draw_circle(Vector2(bx, by), 14 + ring * 12,
				Color(base.r, base.g, base.b, 0.10 * k * (1.0 + energy * 1.5)))
	var face := StyleBoxFlat.new()        # the face sits on its own light
	face.bg_color = Color(0.07, 0.055, 0.125, 0.84)
	face.set_corner_radius_all(14)
	face.border_color = Color(0.75, 0.78, 1.0, 0.45 + energy * 0.55)
	face.set_border_width_all(2)
	draw_style_box(face, rect_a)
	draw_string(ThemeDB.fallback_font, Vector2(rect_a.position.x, mid.y + 6), "P L A Y",
		HORIZONTAL_ALIGNMENT_CENTER, rect_a.size.x, 18, Color(0.93, 0.92, 1.0))

	# ---- button B: rings that thank you for tapping ----
	var idle := [0.15, -0.1, 0.06]
	for i in 3:
		var rad := RADIUS_B - i * 17.0
		var a0: float = t * idle[i] + spin * (1.0 if i % 2 == 0 else -1.0)
		for k in 3:                       # gaps make rotation visible
			draw_arc(centre_b, rad, a0 + k * 2.1, a0 + k * 2.1 + 1.6,
				16, Color(0.59, 0.86, 0.82, 0.85), 6.0)
	for p in pulses:                      # the luminous thank-you
		draw_arc(centre_b, p.r, 0, TAU, 40, Color(0.78, 1.0, 0.96, p.a), 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(centre_b.x - 60, centre_b.y + 5), "TAP",
		HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(0.85, 0.95, 0.93))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if rect_a.has_point(event.position):
			energy = 1.0                  # flare, then cool off
		if event.position.distance_to(centre_b) < RADIUS_B + 14:
			spin_vel += 6.0               # a push, not a teleport
			pulses.append({ "r": RADIUS_B, "a": 0.8 })
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
