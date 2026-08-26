extends Node2D
## FLAME — a continuous particle stream: rise, shrink, fade, wobble, ADD.
## Fire = five decisions, one property each. And the SAME skeleton, with a
## few properties retuned, becomes smoke, a fountain, or an ember ring —
## keys 1–4 switch presets, and each preset's comment names exactly what
## changed. That's the whole lesson: particles are one recipe, many dials.
## Esc returns to the menu. Chapter 06 in the book.

const PRESETS := ["flame", "smoke", "fountain", "ember ring"]
var preset := "flame"
var particles: CPUParticles2D
var info: Label

func _ready() -> void:
	info = Label.new()
	info.position = Vector2(24, 16)
	add_child(info)
	_rebuild()

func _rebuild() -> void:
	if particles:
		particles.queue_free()
	var size := get_viewport_rect().size
	var p := CPUParticles2D.new()
	p.position = Vector2(size.x / 2.0, size.y * 0.75)
	# ---- the shared skeleton (fire's five decisions) ----
	p.amount = 90                          # a steady population
	p.lifetime = 0.9                       # short lives = tight flame
	p.direction = Vector2(0, -1)           # RISE
	p.spread = 12.0
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 90.0
	p.gravity = Vector2.ZERO               # fire doesn't fall
	p.tangential_accel_min = -30.0         # WOBBLE: sideways sway
	p.tangential_accel_max = 30.0
	var curve := Curve.new()               # SHRINK as particles age
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	p.scale_amount_min = 4.0
	p.scale_amount_max = 8.0
	var g := Gradient.new()                # FADE: pale yellow → orange → gone
	g.add_point(0.5, Color(1.0, 0.6, 0.15, 0.6))
	g.set_color(0, Color(1.0, 0.95, 0.6, 0.8))
	g.set_color(2, Color(0.9, 0.3, 0.05, 0.0))
	p.color_ramp = g
	var mat := CanvasItemMaterial.new()    # ADD: overlaps get brighter
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	# ---- the retunes: what each preset changes, and nothing else ----
	match preset:
		"smoke":
			# slower, longer-lived, greyer, and it GROWS instead of shrinking
			p.lifetime = 2.4
			p.initial_velocity_min = 20.0
			p.initial_velocity_max = 40.0
			var grow := Curve.new()
			grow.add_point(Vector2(0.0, 0.4))
			grow.add_point(Vector2(1.0, 1.0))
			p.scale_amount_curve = grow
			var sg := Gradient.new()
			sg.set_color(0, Color(0.7, 0.7, 0.75, 0.25))
			sg.set_color(1, Color(0.5, 0.5, 0.55, 0.0))
			p.color_ramp = sg
			p.material = null              # smoke is not made of light — no ADD
		"fountain":
			# gravity back on + a harder launch: water is flame upside-down
			p.gravity = Vector2(0, 340)
			p.initial_velocity_min = 220.0
			p.initial_velocity_max = 300.0
			p.spread = 8.0
			p.lifetime = 1.4
			var wg := Gradient.new()
			wg.set_color(0, Color(0.75, 0.9, 1.0, 0.9))
			wg.set_color(1, Color(0.4, 0.6, 0.9, 0.0))
			p.color_ramp = wg
			p.scale_amount_min = 2.0
			p.scale_amount_max = 4.0
		"ember ring":
			# same fire, but born on a CIRCLE, drifting outward — emission shape
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
			p.emission_sphere_radius = 90.0
			p.direction = Vector2(0, -1)
			p.spread = 60.0
			p.initial_velocity_min = 10.0
			p.initial_velocity_max = 30.0
			p.lifetime = 1.6
			p.scale_amount_min = 1.5
			p.scale_amount_max = 3.0
			p.position = size / 2.0
	particles = p
	add_child(p)
	info.text = "Particles: 1=flame 2=smoke 3=fountain 4=ember ring (now: %s).  Esc = menu.\nOne skeleton, four costumes — read flame.gd to see exactly which dials each preset turns." % preset

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		var idx: int = event.keycode - KEY_1
		if idx >= 0 and idx < PRESETS.size():
			preset = PRESETS[idx]
			_rebuild()
