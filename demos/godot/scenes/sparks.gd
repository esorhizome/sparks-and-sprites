extends Node2D
## SPARKS — a one-shot particle burst, configured ENTIRELY in code.
## Every line below maps one-to-one to a field in the CPUParticles2D
## inspector panel — the panel is just a form that fills in these values.
## The particle's SHAPE is just a texture: keys 1–4 switch dot / square /
## star / streak, all painted in code. Click anywhere to burst.
## Esc returns to the menu. Chapter 06 in the book.

const SHAPES := ["dot", "square", "star", "streak"]
var shape := "dot"
var textures := {}
var info: Label

func _ready() -> void:
	for s in SHAPES:
		textures[s] = _make_texture(s)
	info = Label.new()
	info.position = Vector2(24, 16)
	add_child(info)
	_caption()
	_burst(get_viewport_rect().size / 2.0)   # one free burst to start

func _caption() -> void:
	info.text = "Sparks: click anywhere to burst.  1=dot 2=square 3=star 4=streak (now: %s).  Esc = menu.\nEvery property here is set from code — read sparks.gd." % shape

## The particle shape is nothing but a small texture, painted here.
func _make_texture(kind: String) -> ImageTexture:
	var s := 24
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := s / 2.0
	for y in s:
		for x in s:
			var a := 0.0
			match kind:
				"dot":      # soft falloff from the centre
					a = clampf(1.0 - Vector2(x - c, y - c).length() / c, 0.0, 1.0)
					a *= a
				"square":   # hard-edged pixel chunk
					a = 1.0 if absf(x - c) < c * 0.55 and absf(y - c) < c * 0.55 else 0.0
				"star":     # four points: bright along the axes, dark diagonals
					var dx := absf(x - c); var dy := absf(y - c)
					a = clampf(1.0 - (minf(dx, dy) * 3.0 + maxf(dx, dy)) / c, 0.0, 1.0)
				"streak":   # a horizontal sliver — reads as motion when flying
					a = clampf(1.0 - absf(y - c) / 2.5, 0.0, 1.0) * clampf(1.0 - absf(x - c) / c, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

func _burst(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.texture = textures[shape]       # ← the shape decision, one property
	p.one_shot = true                 # a burst, not a stream
	p.amount = 48                     # how many sparks
	p.lifetime = 1.2                  # seconds each spark lives
	p.explosiveness = 1.0             # 1.0 = all at once (that's what "burst" means)
	p.direction = Vector2(0, -1)      # aim up...
	p.spread = 80.0                   # ...within an 80-degree cone
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 240.0
	p.gravity = Vector2(0, 340)       # the fall that makes them sparks
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	# colour ramp: bright periwinkle fading to warm ember, then transparent
	var g := Gradient.new()
	g.set_color(0, Color("9BA3F0"))
	g.set_color(1, Color(0.84, 0.66, 0.47, 0.0))
	p.color_ramp = g
	add_child(p)
	p.emitting = true
	# tidy up after the burst is over (lifetime + a little margin)
	get_tree().create_timer(p.lifetime + 0.2).timeout.connect(p.queue_free)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_burst(event.position)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		var idx: int = event.keycode - KEY_1
		if idx >= 0 and idx < SHAPES.size():
			shape = SHAPES[idx]
			_caption()
			_burst(get_viewport_rect().size / 2.0)   # show the new shape at once
