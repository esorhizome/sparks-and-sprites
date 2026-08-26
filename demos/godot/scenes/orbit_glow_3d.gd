extends Node3D
## ORBIT & GLOW — the Babylon demo's Godot twin: drag to orbit, an emissive
## shape that blooms, and 2D UI over a 3D scene. Babylon ships an
## ArcRotateCamera; Godot asks for six honest lines of drag math instead —
## written out below, so you can see there is no magic in either engine.
## Drag with the mouse. Esc = menu.

var rig_yaw: Node3D                     # rotates left-right…
var rig_pitch: Node3D                   # …carries a child that tilts up-down
var knot: MeshInstance3D
var dragging := false

func _ready() -> void:
	# --- environment: dark space + GLOW (this is Babylon's glowLayer) ---
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.04, 0.03, 0.08)
	env.environment.glow_enabled = true
	env.environment.glow_intensity = 1.2
	env.environment.glow_bloom = 0.2
	add_child(env)

	# --- the glowing centrepiece: a torus with an emissive material ---
	var torus := TorusMesh.new()
	torus.inner_radius = 0.7
	torus.outer_radius = 1.4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.1, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.61, 0.64, 0.94)
	mat.emission_energy_multiplier = 2.0
	torus.material = mat
	knot = MeshInstance3D.new()
	knot.mesh = torus
	add_child(knot)

	# --- the orbit rig: yaw node → pitch node → camera on a stick ---
	rig_yaw = Node3D.new()
	add_child(rig_yaw)
	rig_pitch = Node3D.new()
	rig_yaw.add_child(rig_pitch)
	var cam := Camera3D.new()
	rig_pitch.add_child(cam)
	cam.position = Vector3(0, 0, 5.0)     # the stick's length = orbit radius
	rig_pitch.rotation.x = -0.35

	var light := DirectionalLight3D.new()
	add_child(light)
	light.rotation_degrees = Vector3(-45, 30, 0)

	# --- 2D GUI over the 3D scene (Babylon's AdvancedDynamicTexture) ---
	var layer := CanvasLayer.new()
	add_child(layer)
	var l := Label.new()
	l.text = "Orbit & glow: drag to orbit the camera.  Esc = menu.\nYaw node → pitch node → camera on a stick; emissive material + environment glow. Read orbit_glow_3d.gd."
	l.position = Vector2(24, 16)
	layer.add_child(l)

func _process(delta: float) -> void:
	knot.rotate_y(delta * 0.4)            # alive even before you touch it
	knot.rotate_x(delta * 0.13)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	if event is InputEventMouseMotion and dragging:
		rig_yaw.rotation.y -= event.relative.x * 0.008          # the whole orbit camera:
		rig_pitch.rotation.x = clampf(                           # two rotations and a clamp
			rig_pitch.rotation.x - event.relative.y * 0.008, -1.2, 0.3)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
