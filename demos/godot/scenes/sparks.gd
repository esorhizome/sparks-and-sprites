extends Node2D
## SPARKS — a one-shot particle burst, configured ENTIRELY in code.
## Every line below maps one-to-one to a field in the CPUParticles2D
## inspector panel — the panel is just a form that fills in these values.
## Click anywhere to burst. Esc returns to the menu. Chapter 06 in the book.

func _ready() -> void:
	var l := Label.new()
	l.text = "Sparks: click anywhere to burst.  Esc = menu.\nEvery property here is set from code — read sparks.gd."
	l.position = Vector2(24, 16)
	add_child(l)
	_burst(get_viewport_rect().size / 2.0)   # one free burst to start

func _burst(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true                 # a burst, not a stream
	p.amount = 48                     # how many sparks
	p.lifetime = 1.2                  # seconds each spark lives
	p.explosiveness = 1.0             # 1.0 = all at once (that's what "burst" means)
	p.direction = Vector2(0, -1)      # aim up...
	p.spread = 80.0                   # ...within an 80-degree cone
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 240.0
	p.gravity = Vector2(0, 340)       # the fall that makes them sparks
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
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
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
