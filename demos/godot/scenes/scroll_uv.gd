extends Node2D
## INFINITE SCROLL — one generated tile + the one-line UV shader.
## The shader (shaders/scroll_uv.gdshader) slides the texture-reading
## position by time; fract() wraps it so it never ends.
## Two layers at different speeds = instant cheap depth. Esc = menu.
## Chapter 04 in the book.

func _ready() -> void:
	var size := get_viewport_rect().size
	# generate a seamless "cloudy" tile in code (no image files needed)
	_layer(_make_tile(Color(0.61, 0.63, 0.87)), 0.015, size)   # slow = far
	_layer(_make_tile(Color(0.45, 0.38, 0.62)), 0.05, size)    # fast = near

	var l := Label.new()
	l.text = "Infinite scroll: one tile, endless sky. Esc = menu.\nOpen shaders/scroll_uv.gdshader — the whole trick is one line."
	l.position = Vector2(24, 16)
	add_child(l)

func _make_tile(colour: Color) -> ImageTexture:
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4477   # a pinned seed: the same "random" tile every run
	for blob in 30:
		var bx := rng.randf() * s
		var by := rng.randf() * s
		var radius := rng.randf_range(8.0, 22.0)
		# seamless trick: paint each blob 4 times, wrapped around the edges
		for offset: Vector2 in [Vector2.ZERO, Vector2(s, 0), Vector2(0, s), Vector2(s, s)]:
			var cx := fmod(bx + offset.x, float(s) * 2.0) - s / 2.0
			var cy := fmod(by + offset.y, float(s) * 2.0) - s / 2.0
			for y in range(maxi(0, int(cy - radius)), mini(s, int(cy + radius))):
				for x in range(maxi(0, int(cx - radius)), mini(s, int(cx + radius))):
					if Vector2(x - cx, y - cy).length() < radius:
						var prev := img.get_pixel(x, y)
						img.set_pixel(x, y, prev.blend(Color(colour.r, colour.g, colour.b, 0.13)))
	return ImageTexture.create_from_image(img)

func _layer(tex: ImageTexture, speed: float, size: Vector2) -> void:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_TILE
	rect.size = size
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/scroll_uv.gdshader")
	mat.set_shader_parameter("speed", speed)
	rect.material = mat
	add_child(rect)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
