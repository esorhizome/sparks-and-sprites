extends Node3D
## DEPTH-FADE WIREFRAME (3D) — gradients on a line mesh, three ways.
## The depth atlas (key J) fakes depth on a flat canvas. This scene is its
## one honest 3D sibling, built for the case the canvas can't cover: you
## already HAVE a wireframe in 3D (a turning lattice, a knot, a fractal cage)
## and it reads flat because every line is the same colour. Three fixes,
## on keys 1 / 2 / 3, all on the same mesh:
##
##   1  DEPTH FADE  — shaders/depth_fade.gdshader as material_override:
##      lines fade toward far_color with view-space distance. The cue
##      updates as the mesh turns, because distance is measured from the
##      camera each frame. This is atmospheric perspective, done properly.
##   2  VERTEX GRADIENT — a colour per vertex, written once into the mesh's
##      ARRAY_COLOR (here: by height, cool below → warm above) and shown by
##      a StandardMaterial3D with vertex_color_use_as_albedo = true. Static
##      — it rides with the shape — so it reads as PAINT, not air. Good for
##      ribbons, spirals, and anything with a natural "along" direction.
##   3  FLAT — one colour, the control. Watch the depth disappear.
##
## Drag with the mouse to turn it; it also turns on its own. Esc = menu.
##
## Dropping this into an existing gallery: the whole of fix 1 is
##     mesh_instance.material_override = depth_fade_material()
## — one line, no mesh changes. Fix 2 needs the mesh built with colours
## (paint_by_height(mesh) below rebuilds a lines mesh with them), and a
## material that reads them (vertex_material()). Chapter 16.

const SHADER := preload("res://shaders/depth_fade.gdshader")

var mesh_i: MeshInstance3D
var mode := 1
var info: Label
var yaw := 0.0
var pitch := 0.3
var dragging := false
var auto := true

func _ready() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 0.4, 4.2), Vector3.ZERO)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("110E1E")
	add_child(env)

	mesh_i = MeshInstance3D.new()
	mesh_i.mesh = paint_by_height(build_cage_and_knot())
	add_child(mesh_i)
	_apply_mode()

	info = Label.new()
	info.position = Vector2(24, 16)
	add_child(info)

## ---------------------------------------------------------------- the three materials

## Fix 1 — the depth-fade shader as a material. Tune near/far to the mesh's
## size: a unit-ish mesh seen from 4 units away spans roughly 3 … 5.
static func depth_fade_material(near_c := Color(0.92, 0.93, 0.98), far_c := Color(0.30, 0.32, 0.60, 0.10),
		near_d := 3.0, far_d := 5.4) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("near_color", near_c)
	m.set_shader_parameter("far_color", far_c)
	m.set_shader_parameter("near_dist", near_d)
	m.set_shader_parameter("far_dist", far_d)
	return m

## Fix 2 — a material that shows the mesh's own per-vertex colours.
static func vertex_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true      # THE flag: read ARRAY_COLOR as the colour
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

## Fix 3 — the control: one flat colour (what a wireframe gallery usually ships).
static func flat_material(c := Color(0.902, 0.933, 0.980)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m

## ---------------------------------------------------------------- the mesh

## Rebuild a PRIMITIVE_LINES mesh with a colour per vertex, graded by height:
## cool at the bottom, warm at the top. Any other rule works the same way —
## by distance from the centre, by index along a ribbon, by angle.
static func paint_by_height(src: ArrayMesh, lo := Color("5A63C8"), hi := Color("F5C169")) -> ArrayMesh:
	var arrays: Array = src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var ymin := INF; var ymax := -INF
	for v in verts:
		ymin = minf(ymin, v.y); ymax = maxf(ymax, v.y)
	var cols := PackedColorArray()
	for v in verts:
		cols.append(lo.lerp(hi, (v.y - ymin) / maxf(ymax - ymin, 0.001)))
	arrays[Mesh.ARRAY_COLOR] = cols
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return out

## A latitude/longitude sphere cage with a (3,2) torus knot threaded inside —
## enough depth range that the three materials read differently.
static func build_cage_and_knot() -> ArrayMesh:
	var segs := PackedVector3Array()
	var mer := 14; var par := 8; var R := 1.25
	for m in mer:                                                  # meridians
		var a := TAU * m / mer
		var prev := Vector3.ZERO
		for p in 25:
			var th := PI * p / 24.0
			var v := Vector3(sin(th) * cos(a), cos(th), sin(th) * sin(a)) * R
			if p > 0: segs.append(prev); segs.append(v)
			prev = v
	for p in range(1, par):                                        # parallels
		var th := PI * p / par
		var prev := Vector3.ZERO
		for m in 41:
			var a := TAU * m / 40.0
			var v := Vector3(sin(th) * cos(a), cos(th), sin(th) * sin(a)) * R
			if m > 0: segs.append(prev); segs.append(v)
			prev = v
	var kp := 3; var kq := 2; var prevk := Vector3.ZERO           # the knot
	for i in 241:
		var t := TAU * i / 240.0
		var rr := 0.62 + 0.28 * cos(kq * t)
		var v := Vector3(rr * cos(kp * t), 0.28 * sin(kq * t) * 1.6, rr * sin(kp * t))
		if i > 0: segs.append(prevk); segs.append(v)
		prevk = v
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = segs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh

## ---------------------------------------------------------------- running it

func _apply_mode() -> void:
	match mode:
		1: mesh_i.material_override = depth_fade_material()
		2: mesh_i.material_override = vertex_material()
		3: mesh_i.material_override = flat_material()

func _process(delta: float) -> void:
	if auto and not dragging:
		yaw += delta * 0.35
	mesh_i.rotation = Vector3(pitch, yaw, 0.0)
	var names := { 1: "1 = DEPTH FADE — shader: view-space distance → colour, live as it turns",
		2: "2 = VERTEX GRADIENT — a colour per vertex, baked into the mesh (paint, not air)",
		3: "3 = FLAT — one colour: the control. The depth is gone." }
	info.text = "Depth-fade wireframe — one line mesh, three materials. Keys 1/2/3 · drag to turn · Esc = menu\n%s\nmaterial_override is the whole trick: the mesh never changes." % names[mode]

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE: get_tree().change_scene_to_file("res://scenes/menu.tscn")
			KEY_1: mode = 1; _apply_mode()
			KEY_2: mode = 2; _apply_mode()
			KEY_3: mode = 3; _apply_mode()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	if event is InputEventMouseMotion and dragging:
		yaw += event.relative.x * 0.01
		pitch = clampf(pitch + event.relative.y * 0.01, -1.4, 1.4)
