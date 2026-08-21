extends Node2D
## ADDITIVE GLOW — light that adds up where it overlaps.
## Three soft radial blobs orbit slowly (0.1–0.15 Hz — calm on purpose)
## with blend mode ADD: where two cross, the crossing is brighter than either.
## Esc = menu. Chapter 03 in the book.
## (For engine-level screen glow, add a WorldEnvironment with Glow enabled
## and give sprites colours above 1.0 — that's "bloom". This scene shows the
## cheaper per-sprite trick that works on any renderer, including web.)

var blobs: Array[Sprite2D] = []
var t := 0.0

func _ready() -> void:
	# a dark ground so the light has something to matter against
	var bg := ColorRect.new()
	bg.color = Color("191527")
	bg.size = get_viewport_rect().size
	add_child(bg)

	var tex := _soft_blob_texture(128)
	for colour: Color in [Color(0.48, 0.52, 0.93), Color(0.84, 0.66, 0.47), Color(0.62, 0.75, 0.62)]:
		var s := Sprite2D.new()
		s.texture = tex
		s.modulate = Color(colour.r, colour.g, colour.b, 0.8)
		s.scale = Vector2.ONE * 2.0
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD   # ← the one decision
		s.material = mat
		add_child(s)
		blobs.append(s)

	var l := Label.new()
	l.text = "Additive glow: watch the crossings — brighter than either blob.  Esc = menu.\nTry: change BLEND_MODE_ADD to BLEND_MODE_MIX in glow.gd and feel the light die."
	l.position = Vector2(24, 16)
	add_child(l)

## A soft radial gradient blob, generated in code — the universal glow sprite.
func _soft_blob_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x - center, y - center).length() / center
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))   # squared = softer falloff
	return ImageTexture.create_from_image(img)

func _process(delta: float) -> void:
	t += delta
	var size := get_viewport_rect().size
	var center := size / 2.0
	var radius := minf(size.x, size.y) * 0.22
	var speeds := [0.9, 0.7, 0.5]
	var phases := [0.0, 2.1, 4.2]
	for i in blobs.size():
		blobs[i].position = center + Vector2(
			cos(t * speeds[i] + phases[i]), sin(t * speeds[i] + phases[i])) * radius

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
