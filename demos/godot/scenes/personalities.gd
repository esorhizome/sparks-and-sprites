extends Node2D
## MOVEMENT PERSONALITIES — one dot, eight souls.
## Personality is not what moves — it's the SHAPE of the speed.
## Keys 1–8 choose a personality, Space replays, Esc returns to the menu.
## Chapter 05 of the book explains every recipe in plain words.

const NAMES := ["human", "superhuman", "alien", "excited",
				"sad", "emotionless", "robot", "stately"]
const DUR := {"human": 2.0, "superhuman": 2.2, "alien": 3.4, "excited": 2.4,
			  "sad": 3.6, "emotionless": 2.4, "robot": 3.0, "stately": 4.2}

var personality := "human"
var t := 0.0
var playing := true
var trail: Array[Vector2] = []

## Each recipe maps u (journey progress 0→1) to a point:
## x = 0→1 across the screen, y = vertical detour.
func pos_for(u: float) -> Vector2:
	match personality:
		"human":        # ease both ends + gentle bob
			var e := 4 * u * u * u if u < 0.5 else 1.0 - pow(-2 * u + 2, 3) / 2.0
			return Vector2(e, sin(u * PI * 2.2) * 0.06)
		"superhuman":   # anticipation pull-back, then t^4 snap
			if u < 0.25: return Vector2(-0.05 * (u / 0.25), 0)
			if u < 0.45:
				var k := (u - 0.25) / 0.2
				return Vector2(-0.05 + 1.05 * k * k * k * k, 0)
			return Vector2(1, 0)
		"alien":        # drift + abrupt reorientation, unsynced sines
			var y := 0.35 * sin(u * TAU) + 0.25 * sin(u * TAU * 1.618 + 2.0)
			if int(floor(u * 5)) % 2 == 1: y = -y * 0.6
			return Vector2(minf(1.0, u + 0.06 * sin(u * 13.0)), y * 0.5)
		"excited":      # springy overshoot with bounces
			var e := 1.0 - pow(2.0, -8.0 * u) * cos(u * 14.0)
			return Vector2(minf(1.06, e), -abs(sin(u * 12.0)) * 0.22 * (1.0 - u))
		"sad":          # hesitate... then droop through a sagging arc
			if u < 0.22: return Vector2(0, 0.05)
			var k := (u - 0.22) / 0.78
			return Vector2(1.0 - pow(1.0 - k, 2.6), 0.05 + sin(k * PI) * 0.28)
		"emotionless":  # pure linear. that's the whole recipe.
			return Vector2(u, 0)
		"robot":        # 7 quantised steps + tiny servo settle
			var steps := 7.0
			var s := floor(u * steps) / steps
			var f := fmod(u * steps, 1.0)
			var settle := sin(f / 0.3 * PI * 3.0) * exp(-f * 10.0) * 0.015 if f < 0.3 else 0.0
			return Vector2(s + settle, 0)
		"stately":      # long sine ease + wide unhurried arc
			var e := -(cos(PI * u) - 1.0) / 2.0
			return Vector2(e, -sin(u * PI) * 0.42)
	return Vector2(u, 0)

func _ready() -> void:
	var l := Label.new()
	l.name = "Hint"
	l.position = Vector2(24, 16)
	add_child(l)
	_restart()

func _restart() -> void:
	t = 0.0
	playing = true
	trail.clear()
	($Hint as Label).text = "Personality: %s   —   1-8 to switch, Space replays, Esc = menu\n%s" \
		% [personality, "  ".join(NAMES)]

func _process(delta: float) -> void:
	if not playing:
		return
	t += delta
	var u: float = minf(1.0, t / DUR[personality])
	trail.append(pos_for(u))
	if trail.size() > 120:
		trail.pop_front()
	if u >= 1.0:
		playing = false
	queue_redraw()

func _draw() -> void:
	var size := get_viewport_rect().size
	var pad := 60.0
	var mid_y := size.y * 0.55
	var amp := size.y * 0.3
	draw_dashed_line(Vector2(pad, mid_y), Vector2(size.x - pad, mid_y),
		Color(0.5, 0.5, 0.5, 0.35), 1.0, 7.0)
	var i := 0
	for p in trail:   # breadcrumb trail — the personality made visible
		var a := 0.05 + 0.1 * float(i) / maxf(1.0, trail.size())
		draw_circle(Vector2(pad + p.x * (size.x - 2 * pad), mid_y + p.y * amp),
			4.0, Color(0.35, 0.39, 0.78, a))
		i += 1
	if not trail.is_empty():
		var p: Vector2 = trail.back()
		draw_circle(Vector2(pad + p.x * (size.x - 2 * pad), mid_y + p.y * amp),
			9.0, Color(0.35, 0.39, 0.78))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		elif event.keycode == KEY_SPACE:
			_restart()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_8:
			personality = NAMES[event.keycode - KEY_1]
			_restart()
