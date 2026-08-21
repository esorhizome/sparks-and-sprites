extends Node2D
## SPRITE BASICS — load, attach, place.
## We even GENERATE the image from code (two loops, one colour decision per
## pixel) so you can see there is no magic hiding in an asset file.
## Chapter 02 of the book walks through this same recipe on all platforms.

func _ready() -> void:
	# STEP 0 — generate a tiny 16x16 "creature" image in code.
	# (Normally you'd do: var tex := load("res://art/friend.png") — that's it.)
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var in_body := Vector2(x - 8, y - 9).length() < 6.0   # round body
			var in_eye: bool = (x == 6 or x == 10) and y == 8
			if in_eye:
				img.set_pixel(x, y, Color("2B2440"))
			elif in_body:
				img.set_pixel(x, y, Color("5A63C8"))
			# else: leave the pixel transparent
	var tex := ImageTexture.create_from_image(img)   # image → texture (GPU-ready)

	# STEPS 1..3 — load is done (tex). Now attach + place, four ways:
	_place(tex, Vector2(150, 200), 4.0, 1.0)    # plain
	_place(tex, Vector2(340, 160), 8.0, 1.0)    # bigger (scale 8x)
	_place(tex, Vector2(560, 220), 6.0, 0.4)    # half-transparent (alpha 0.4)

	# a little crowd — placement is just numbers in a loop
	for i in 5:
		_place(tex, Vector2(180 + i * 110, 400 + sin(i) * 30), 2.5, 1.0)

	_hint("Sprite basics: one generated 16x16 texture, placed six ways.\nTry: change the eye rows, the body colour, the loop count. Esc = menu.")

func _place(tex: Texture2D, pos: Vector2, scale_by: float, alpha: float) -> void:
	var s := Sprite2D.new()
	s.texture = tex                              # attach the texture
	s.position = pos                             # place
	s.scale = Vector2.ONE * scale_by
	s.modulate = Color(1, 1, 1, alpha)           # tint & alpha in one property
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # crisp pixels
	add_child(s)

func _hint(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.position = Vector2(24, 16)
	add_child(l)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
