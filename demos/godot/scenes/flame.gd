extends Node2D
## FLAME — a continuous particle stream: rise, shrink, fade, wobble, ADD.
## Fire = five decisions, one property each. The additive blend mode
## (overlaps get brighter, because fire is made of light) is the fifth.
## Esc returns to the menu. Chapter 06 in the book.

func _ready() -> void:
	var size := get_viewport_rect().size
	var p := CPUParticles2D.new()
	p.position = Vector2(size.x / 2.0, size.y * 0.75)
	p.amount = 90                          # a steady population
	p.lifetime = 0.9                       # short lives = tight flame
	p.direction = Vector2(0, -1)           # RISE
	p.spread = 12.0
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 90.0
	p.gravity = Vector2.ZERO               # fire doesn't fall
	# WOBBLE: sideways noise-like sway from turbulence-ish accel
	p.tangential_accel_min = -30.0
	p.tangential_accel_max = 30.0
	# SHRINK as particles age
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	p.scale_amount_min = 4.0
	p.scale_amount_max = 8.0
	# FADE through a colour ramp: pale yellow → deep orange → transparent
	var g := Gradient.new()
	g.add_point(0.5, Color(1.0, 0.6, 0.15, 0.6))
	g.set_color(0, Color(1.0, 0.95, 0.6, 0.8))
	g.set_color(2, Color(0.9, 0.3, 0.05, 0.0))
	p.color_ramp = g
	# ADD: the blend mode that makes overlapping particles glow
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	add_child(p)

	var l := Label.new()
	l.text = "Flame: rise + shrink + fade + wobble + additive blend.  Esc = menu.\nTry: gravity (0, 60) for lazy smoke, or swap the ramp colours for ghost-fire."
	l.position = Vector2(24, 16)
	add_child(l)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
