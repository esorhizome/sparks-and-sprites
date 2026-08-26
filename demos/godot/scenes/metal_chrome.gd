extends Node2D
## CHROME & LIQUID METAL — a mirror with opinions, drawn scanline by scanline.
## Chrome is a lookup: each height on the ball reads a brightness from a
## striped "fake world" ramp (a 1D environment map — the matcap idea).
## LIQUID wobbles that lookup; the travelling glint is a moving bright band.
## Click to toggle rigid ↔ molten. Esc = menu. Chapter 06's metal entry.

var BANDS := [                   # the fake world: sky, horizon, ground, sky
	[0.00, Color(0.988, 0.992, 1.0)],
	[0.42, Color(0.627, 0.675, 0.769)],
	[0.50, Color(0.149, 0.173, 0.235)],
	[0.58, Color(0.376, 0.416, 0.502)],
	[1.00, Color(0.824, 0.863, 0.941)],
]

var t := 0.0
var liquid := 0.5
var info: Label

func _ready() -> void:
	info = Label.new()
	info.position = Vector2(24, 16)
	add_child(info)
	_caption()

func _caption() -> void:
	info.text = "Chrome ball: click to toggle rigid/molten (liquid = %.1f).  Esc = menu.\nEach scanline looks up a brightness in a striped fake world — read metal_chrome.gd." % liquid

func _band_color(k: float) -> Color:
	for i in range(BANDS.size() - 1):
		var a: float = BANDS[i][0]
		var b: float = BANDS[i + 1][0]
		if k <= b:
			return (BANDS[i][1] as Color).lerp(BANDS[i + 1][1], (k - a) / maxf(0.001, b - a))
	return BANDS[-1][1]

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var centre := get_viewport_rect().size / 2.0
	var radius := 130.0
	var rows := 90
	for i in rows:
		var k := float(i) / (rows - 1)                    # 0 = top of ball, 1 = bottom
		var y := centre.y + (k * 2.0 - 1.0) * radius
		var half := sqrt(maxf(0.0, radius * radius - (y - centre.y) * (y - centre.y)))
		# the liquid wobble bends WHERE this scanline samples the fake world
		var wob := sin(k * 9.0 + t * 2.2) * 0.06 * liquid
		var col := _band_color(clampf(k + wob, 0.0, 1.0))
		# the glint: a bright band sweeping down the ball every few seconds
		var glint := exp(-pow((k - fposmod(t * 0.45, 1.4)) * 9.0, 2.0))
		col = col.lerp(Color(1, 1, 1), glint * 0.8)
		draw_line(Vector2(centre.x - half, y), Vector2(centre.x + half, y), col, radius * 2.0 / rows + 1.0)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		liquid = 1.0 if liquid < 0.75 else 0.0
		_caption()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
