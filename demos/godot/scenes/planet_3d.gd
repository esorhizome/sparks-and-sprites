extends Node3D
## PLANET — the three.js demo's Godot twin: real 3D, still all from code.
## A sphere's vertices are pushed outward by noise (mountains) or left
## alone (sea level), coloured by height, and set slowly spinning under
## one light — the same recipe as the web version, different accent.
## Drag does nothing here on purpose; the planet turns itself. Esc = menu.

var planet: MeshInstance3D
var stars: MultiMeshInstance3D

func _ready() -> void:
	# --- the space around everything ---
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.03, 0.03, 0.07)
	add_child(env)

	# --- the planet: displace a sphere's vertices with noise ---
	var sphere := SphereMesh.new()
	sphere.radius = 1.6
	sphere.height = 3.2
	sphere.radial_segments = 96
	sphere.rings = 48
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors := PackedColorArray()
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.9
	for i in verts.size():
		var n := noise.get_noise_3d(verts[i].x, verts[i].y, verts[i].z)
		var height := maxf(0.0, n) * 0.28              # only mountains rise; seas stay round
		verts[i] += normals[i] * height
		colors.append(Color(0.16, 0.35, 0.55) if height < 0.02
			else Color(0.30, 0.52, 0.30).lerp(Color(0.85, 0.82, 0.75), height * 3.0))
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true              # the height-colour we just painted
	mat.roughness = 0.9
	mesh.surface_set_material(0, mat)
	planet = MeshInstance3D.new()
	planet.mesh = mesh
	add_child(planet)

	# --- a starfield: one tiny mesh, instanced 300 times ---
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var star := BoxMesh.new()
	star.size = Vector3(0.02, 0.02, 0.02)
	var star_mat := StandardMaterial3D.new()
	star_mat.emission_enabled = true
	star_mat.emission = Color(0.9, 0.9, 1.0)
	star.material = star_mat
	mm.mesh = star
	mm.instance_count = 300
	for i in 300:
		var dir := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		mm.set_instance_transform(i, Transform3D(Basis(), dir * randf_range(9.0, 14.0)))
	stars = MultiMeshInstance3D.new()
	stars.multimesh = mm
	add_child(stars)

	# --- light + camera ---
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-30, 40, 0)
	var cam := Camera3D.new()
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.2, 4.6), Vector3.ZERO)

	# --- the caption (2D UI floats above the 3D scene) ---
	var layer := CanvasLayer.new()
	add_child(layer)
	var l := Label.new()
	l.text = "Planet: a noise-displaced sphere, coloured by height.  Esc = menu.\nCompare with the three.js version — same recipe, different accent. Read planet_3d.gd."
	l.position = Vector2(24, 16)
	layer.add_child(l)

func _process(delta: float) -> void:
	planet.rotate_y(delta * 0.25)         # worlds turn slowly
	stars.rotate_y(delta * 0.01)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
