extends Node2D
## HALO — an additive ring with a ±3% breath.
## The ring texture is GENERATED from code (no asset file), put on a
## Sprite2D with additive blending, and scaled on a 3-second sine.
## ±3% is the "it is alive" number from chapter 06 — big enough to feel,
## small enough to ignore. Esc = menu.

var halo: Sprite2D
var t := 0.0

func _ready() -> void:
	var l := Label.new()
	l.text = "Halo: an additive ring breathing at ±3%.  Esc = menu.\nThe ring texture is painted pixel-by-pixel in _ready() — read halo.gd."
	l.position = Vector2(24, 16)
	add_child(l)

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
	halo.position = get_viewport_rect().size / 2.0
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD    # light that adds up
	halo.material = mat
	add_child(halo)

	# a second copy, rotated and slightly larger, to show additive overlap
	var halo2 := halo.duplicate()
	halo2.scale = Vector2(1.25, 1.25)
	halo2.modulate = Color(1, 1, 1, 0.5)
	add_child(halo2)

func _process(delta: float) -> void:
	t += delta
	var breath := 1.0 + 0.03 * sin(t * TAU / 3.0)   # ±3% every 3 seconds
	halo.scale = Vector2(breath, breath)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
