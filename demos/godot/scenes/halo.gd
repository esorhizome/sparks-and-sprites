extends Node2D
## HALO — an additive ring with a ±3% breath.
## The ring texture is GENERATED from code (no asset file), put on a
## Sprite2D with additive blending, and scaled on a 3-second sine.
## ±3% is the "it is alive" number from chapter 06 — big enough to feel,
## small enough to ignore. Key 1 = full ring, key 2 = the thin ellipse
## floating over a head (a halo doing its actual job). Esc = menu.

const MODES := ["ring", "head"]
var mode := "ring"
var halo: Sprite2D
var halo2: Sprite2D
var t := 0.0
var info: Label

func _ready() -> void:
	info = Label.new()
	info.position = Vector2(24, 16)
	add_child(info)

	# paint the ring: alpha peaks at the ring radius, falls off both ways
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var centre := size / 2.0
	var ring_r := size * 0.32
	for y in size:
		for x in size:
			var d := Vector2(x - centre, y - centre).length()
			var fall := absf(d - ring_r) / (size * 0.10)      # distance from the ring line
			var a := clampf(1.0 - fall, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.61, 0.64, 0.94, a * a * 0.9))
	halo = Sprite2D.new()
	halo.texture = ImageTexture.create_from_image(img)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD    # light that adds up
	halo.material = mat
	add_child(halo)

	# a second copy, rotated and slightly larger, to show additive overlap
	halo2 = halo.duplicate()
	halo2.modulate = Color(1, 1, 1, 0.5)
	add_child(halo2)
	_caption()

func _caption() -> void:
	info.text = "Halo: an additive ring breathing at ±3%%.  1 = ring, 2 = over a head (now: %s).  Esc = menu.\nThe ring texture is painted pixel-by-pixel in _ready() — read halo.gd." % mode

func _process(delta: float) -> void:
	t += delta
	var size := get_viewport_rect().size
	var breath := 1.0 + 0.03 * sin(t * TAU / 3.0)   # ±3% every 3 seconds
	if mode == "ring":
		halo.position = size / 2.0
		halo.scale = Vector2(breath, breath)
		halo2.visible = true
		halo2.position = size / 2.0
		halo2.scale = Vector2(1.25, 1.25)
	else:
		# the working halo: squash the SAME texture into a thin ellipse and
		# float it above the head — the y-scale is the entire costume change
		var head := size / 2.0 + Vector2(0, 30)
		var bob := sin(t * 1.2) * 3.0                # the halo hovers, gently
		halo.position = head + Vector2(0, -78 + bob)
		halo.scale = Vector2(0.55 * breath, 0.16 * breath)   # thin ellipse
		halo2.visible = false
	queue_redraw()

func _draw() -> void:
	if mode != "head":
		return
	var size := get_viewport_rect().size
	var head := size / 2.0 + Vector2(0, 30)
	# a silhouette is enough: a head and shoulders in near-black
	var ink := Color(0.09, 0.08, 0.14)
	draw_circle(head, 34.0, ink)                                  # head
	draw_rect(Rect2(head + Vector2(-52, 40), Vector2(104, 70)), ink)   # shoulders
	draw_circle(head + Vector2(-52, 75), 20.0, ink)
	draw_circle(head + Vector2(52, 75), 20.0, ink)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		var idx: int = event.keycode - KEY_1
		if idx >= 0 and idx < MODES.size():
			mode = MODES[idx]
			_caption()
