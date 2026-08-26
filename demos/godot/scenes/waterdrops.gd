extends Node2D
## WATERDROPS — fall, splash, ripple: a particle's DEATH as an event.
## One drop's end spawns two new things: splash droplets (more particles)
## and a ripple ring (an expanding ellipse). That hand-off is the whole
## lesson — Unity calls it Sub Emitters, Niagara calls it event handlers.
## Click to add rain. Esc = menu. Chapter 06.

var drops: Array = []           # untyped: filter() hands back a plain Array
var splashes: Array = []
var ripples: Array = []
var water_y := 0.0
var spawn_timer := 0.0
var rain_boost := 0.0

func _ready() -> void:
	water_y = get_viewport_rect().size.y * 0.72
	var l := Label.new()
	l.text = "Waterdrops: click for a downpour.  Esc = menu.\nOne drop dies → a splash AND a ripple are born. Death as an event — read waterdrops.gd."
	l.position = Vector2(24, 16)
	add_child(l)

func _process(delta: float) -> void:
	var w := get_viewport_rect().size.x
	spawn_timer -= delta
	rain_boost = maxf(0.0, rain_boost - delta * 0.5)
	if spawn_timer <= 0.0:
		drops.append({ "pos": Vector2(randf_range(0, w), -8.0), "vel": randf_range(260, 380) })
		spawn_timer = randf_range(0.08, 0.3) * (1.0 - rain_boost * 0.85)
	for d in drops:
		d.pos.y += d.vel * delta
		if d.pos.y >= water_y:               # the death — and the two births
			for i in 5:
				splashes.append({
					"pos": Vector2(d.pos.x, water_y),
					"vel": Vector2(randf_range(-70, 70), randf_range(-160, -60)),
					"life": 1.0,
				})
			ripples.append({ "pos": Vector2(d.pos.x, water_y), "r": 2.0, "life": 1.0 })
			d.pos.y = -1e6                   # mark spent
	drops = drops.filter(func(d): return d.pos.y > -1e5)
	for s in splashes:
		s.pos += s.vel * delta
		s.vel.y += 340.0 * delta
		s.life -= delta * 1.4
	splashes = splashes.filter(func(s): return s.life > 0.0)
	for r in ripples:
		r.r += 46.0 * delta
		r.life -= delta * 0.8
	ripples = ripples.filter(func(r): return r.life > 0.0)
	queue_redraw()

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(0, water_y, size.x, size.y - water_y), Color(0.10, 0.18, 0.28))
	draw_line(Vector2(0, water_y), Vector2(size.x, water_y), Color(0.55, 0.75, 0.9, 0.6), 1.5)
	for d in drops:                          # a falling streak, not a ball
		draw_line(d.pos - Vector2(0, 10), d.pos, Color(0.62, 0.82, 1.0, 0.8), 2.0)
	for s in splashes:
		draw_circle(s.pos, 2.0, Color(0.75, 0.9, 1.0, s.life))
	for r in ripples:                        # squashed ellipse = water seen at an angle
		var pts := PackedVector2Array()
		for i in 33:
			var th := TAU * i / 32.0
			pts.append(r.pos + Vector2(cos(th) * r.r, sin(th) * r.r * 0.32))
		draw_polyline(pts, Color(0.7, 0.88, 1.0, r.life * 0.8), 1.4)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		rain_boost = 1.0
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
