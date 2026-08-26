extends Node2D
## FRAGMENTED TRAILS — a comet of pieces, spawned BY DISTANCE MOVED.
## The web demo's whole secret: fragments are born only while the pointer
## travels (Unity calls this Rate over Distance; Niagara, spawn-per-unit).
## Keys 1–4 change the fragment costume: ember, star, drop, sparkle.
## Move the mouse. Esc = menu. Chapter 06 (and chapter 12, as a cursor trail).

const SPAWN_EVERY := 9.0        # pixels of travel per fragment
const STYLES := ["ember", "star", "drop", "sparkle"]

var style := "ember"
var last_pos := Vector2.ZERO
var travelled := 0.0
var frags: Array = []           # untyped: filter() hands back a plain Array
var info: Label

func _ready() -> void:
	info = Label.new()
	info.position = Vector2(24, 16)
	add_child(info)
	_caption()
	last_pos = get_global_mouse_position()

func _caption() -> void:
	info.text = "Fragmented trails: move the mouse. 1=ember 2=star 3=drop 4=sparkle.  Esc = menu.\nFragments spawn per pixel MOVED, not per second — that's the responsive feel."

func _process(delta: float) -> void:
	var pos := get_global_mouse_position()
	travelled += pos.distance_to(last_pos)
	while travelled > SPAWN_EVERY:          # one fragment per step of travel
		travelled -= SPAWN_EVERY
		frags.append({
			"pos": pos + Vector2(randf_range(-3, 3), randf_range(-3, 3)),
			"vel": Vector2(randf_range(-14, 14), randf_range(-30, 6)),
			"life": 1.0,
			"spin": randf_range(-4.0, 4.0),
			"rot": randf_range(0.0, TAU),
		})
	last_pos = pos
	for f in frags:                          # the shared lifecycle: drift, fade, die
		f.pos += f.vel * delta
		f.vel.y += (60.0 if style == "drop" else 8.0) * delta
		f.rot += f.spin * delta
		f.life -= delta * 1.1
	frags = frags.filter(func(f): return f.life > 0.0)
	queue_redraw()

func _draw() -> void:
	for f in frags:                          # same skeleton, four costumes
		var a: float = f.life
		match style:
			"ember":
				draw_circle(f.pos, 2.0 + 3.0 * a, Color(1.0, 0.55 + 0.35 * a, 0.25, a))
			"star":
				var pts := PackedVector2Array()
				for i in 10:                 # 5-point star: outer/inner radii alternate
					var r := 6.0 * a if i % 2 == 0 else 2.6 * a
					var th: float = f.rot + TAU * i / 10.0
					pts.append(f.pos + Vector2(cos(th), sin(th)) * r)
				if a > 0.05:
					draw_colored_polygon(pts, Color(1.0, 0.9, 0.5, a))
			"drop":
				draw_circle(f.pos, 2.4, Color(0.55, 0.8, 1.0, a * 0.9))
			"sparkle":
				var l := 4.0 * a
				var c := Color(0.95, 0.9, 1.0, a)
				draw_line(f.pos - Vector2(l, 0), f.pos + Vector2(l, 0), c, 1.2)
				draw_line(f.pos - Vector2(0, l), f.pos + Vector2(0, l), c, 1.2)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		var idx: int = event.keycode - KEY_1
		if idx >= 0 and idx < STYLES.size():
			style = STYLES[idx]
			_caption()
