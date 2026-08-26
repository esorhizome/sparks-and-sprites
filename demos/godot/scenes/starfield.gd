extends Node2D
## STARFIELD & AMBIENCE — sparks at one-tenth speed.
## An ambient field is a particle system with the urgency removed: few
## per second, long lives, tiny sizes, slow drift. Keys switch the costume:
## 1 = stars (twinkle in place), 2 = snow, 3 = motes, 4 = fireflies.
## Esc = menu. Chapter 06 (ambient atmosphere).

const PRESETS := {
	"stars":     { "n": 90, "drift": Vector2(0, 0),    "col": Color(0.86, 0.86, 1.0),  "twinkle": 3.0 },
	"snow":      { "n": 70, "drift": Vector2(4, 22),   "col": Color(0.92, 0.96, 1.0),  "twinkle": 0.0 },
	"motes":     { "n": 40, "drift": Vector2(6, -3),   "col": Color(0.85, 0.8, 0.65),  "twinkle": 0.6 },
	"fireflies": { "n": 22, "drift": Vector2(0, 0),    "col": Color(0.86, 1.0, 0.55),  "twinkle": 1.2 },
}

var preset := "stars"
var field: Array[Dictionary] = []
var t := 0.0
var info: Label

func _ready() -> void:
	info = Label.new()
	info.position = Vector2(24, 16)
	add_child(info)
	_rebuild()

func _rebuild() -> void:
	info.text = "Ambience: 1=stars 2=snow 3=motes 4=fireflies (now: %s).  Esc = menu.\nSame particle skeleton as sparks — with the urgency removed." % preset
	field.clear()
	var size := get_viewport_rect().size
	var p: Dictionary = PRESETS[preset]
	for i in p.n:
		field.append({
			"pos": Vector2(randf_range(0, size.x), randf_range(0, size.y)),
			"ph": randf_range(0, TAU),
			"r": randf_range(0.8, 2.2),
			"wander": randf_range(0.5, 1.5),
		})

func _process(delta: float) -> void:
	t += delta
	var size := get_viewport_rect().size
	var p: Dictionary = PRESETS[preset]
	for s in field:
		s.pos += p.drift * s.wander * delta
		if preset == "fireflies":         # fireflies wander; snow just falls
			s.pos += Vector2(sin(t * s.wander + s.ph), cos(t * 0.7 + s.ph)) * 12.0 * delta
		s.pos.x = fposmod(s.pos.x, size.x)
		s.pos.y = fposmod(s.pos.y, size.y)
	queue_redraw()

func _draw() -> void:
	var p: Dictionary = PRESETS[preset]
	for s in field:
		var a := 0.75
		if p.twinkle > 0.0:
			a = 0.25 + 0.6 * maxf(0.0, sin(t * p.twinkle * s.wander + s.ph))
		var c: Color = p.col
		draw_circle(s.pos, s.r, Color(c.r, c.g, c.b, a))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		var names := PRESETS.keys()
		var idx: int = event.keycode - KEY_1
		if idx >= 0 and idx < names.size():
			preset = names[idx]
			_rebuild()
