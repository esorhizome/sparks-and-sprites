extends SceneTree
## Headless test for the full cube codex (not a demo).
## Every one of the 104 effects, in BOTH voices — original and rhyme:
## setup → 60 ticks → two presses → 60 ticks, then one draw pass per family
## page inside the real scene, with a right-click (rhyme toggle) per page.
## Run: godot --headless --path . -s res://codex_test.gd

const FAMILIES := [
	preload("res://scenes/cubefx/fire.gd"),
	preload("res://scenes/cubefx/water.gd"),
	preload("res://scenes/cubefx/bolt.gd"),
	preload("res://scenes/cubefx/sparkle.gd"),
	preload("res://scenes/cubefx/halo.gd"),
	preload("res://scenes/cubefx/aura.gd"),
	preload("res://scenes/cubefx/motion.gd"),
	preload("res://scenes/cubefx/impact.gd"),
	preload("res://scenes/cubefx/earth.gd"),
	preload("res://scenes/cubefx/shot.gd"),
	preload("res://scenes/cubefx/ice.gd"),
	preload("res://scenes/cubefx/wind.gd"),
	preload("res://scenes/cubefx/dark.gd"),
	preload("res://scenes/cubefx/decor.gd"),
]
const RHYME_FAMILIES := [
	preload("res://scenes/cubefx/fire_r.gd"),
	preload("res://scenes/cubefx/water_r.gd"),
	preload("res://scenes/cubefx/bolt_r.gd"),
	preload("res://scenes/cubefx/sparkle_r.gd"),
	preload("res://scenes/cubefx/halo_r.gd"),
	preload("res://scenes/cubefx/aura_r.gd"),
	preload("res://scenes/cubefx/motion_r.gd"),
	preload("res://scenes/cubefx/impact_r.gd"),
	preload("res://scenes/cubefx/earth_r.gd"),
	preload("res://scenes/cubefx/shot_r.gd"),
	preload("res://scenes/cubefx/ice_r.gd"),
	preload("res://scenes/cubefx/wind_r.gd"),
	preload("res://scenes/cubefx/dark_r.gd"),
	preload("res://scenes/cubefx/decor_r.gd"),
]
const CubeKit := preload("res://scenes/cubefx/kit.gd")

var page := 0
var frame := 0
var total := 0
var rhymed := 0

func _run_one(script: GDScript, def: Dictionary) -> void:
	var b := { "id": def.id, "name": def.name, "hint": def.hint,
		"rect": Rect2(Vector2(20, 64), Vector2(176, 128)) }
	CubeKit.setup(b)
	script.init(b)
	var t := 0.0
	for i in 60:
		t += 1.0 / 60.0
		CubeKit.tick_cube(b, 1.0 / 60.0)
		script.tick(b, 1.0 / 60.0, t)
	script.press(b, Vector2(108, 128))          # centre-ish of the stage
	script.press(b, Vector2(30, 70))            # an aimed corner press
	for i in 60:
		t += 1.0 / 60.0
		CubeKit.tick_cube(b, 1.0 / 60.0)
		script.tick(b, 1.0 / 60.0, t)

func _initialize() -> void:
	for fi in FAMILIES.size():
		var fam: GDScript = FAMILIES[fi]
		var rfam: GDScript = RHYME_FAMILIES[fi]
		for def in fam.DEFS:
			_run_one(fam, def)
			total += 1
			assert(rfam.RHYMES.has(def.id), "missing rhyme for %s" % def.id)
			_run_one(rfam, def)
			rhymed += 1
	print("codex logic pass: %d effects + %d rhymes ticked and pressed" % [total, rhymed])
	change_scene_to_file("res://scenes/cube_vfx.tscn")
	process_frame.connect(_tick)

func _tick() -> void:
	frame += 1
	if frame % 8 == 3:
		# right-click the first card: toggles it to its rhyme for the draw pass
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_RIGHT
		m.pressed = true
		m.position = Vector2(100, 120)
		Input.parse_input_event(m)
	if frame % 8 == 0:
		var k := InputEventKey.new()
		k.keycode = KEY_RIGHT
		k.pressed = true
		Input.parse_input_event(k)
		page += 1
		if page > FAMILIES.size() + 1:
			print("CODEX TEST COMPLETE — %d effects + %d rhymes, all %d pages drawn" % [total, rhymed, FAMILIES.size()])
			quit()
