extends SceneTree
## Headless test for the full cube codex (not a demo).
## Every one of the 104 effects: setup → 60 ticks → two presses → 60 ticks,
## then one draw pass per family page inside the real scene.
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
const CubeKit := preload("res://scenes/cubefx/kit.gd")

var page := 0
var frame := 0
var total := 0

func _initialize() -> void:
	for fam in FAMILIES:
		for def in fam.DEFS:
			var b := { "id": def.id, "name": def.name, "hint": def.hint,
				"rect": Rect2(Vector2(20, 64), Vector2(176, 128)) }
			CubeKit.setup(b)
			fam.init(b)
			var t := 0.0
			for i in 60:
				t += 1.0 / 60.0
				CubeKit.tick_cube(b, 1.0 / 60.0)
				fam.tick(b, 1.0 / 60.0, t)
			fam.press(b, Vector2(108, 128))          # centre-ish of the stage
			fam.press(b, Vector2(30, 70))            # an aimed corner press
			for i in 60:
				t += 1.0 / 60.0
				CubeKit.tick_cube(b, 1.0 / 60.0)
				fam.tick(b, 1.0 / 60.0, t)
			total += 1
	print("codex logic pass: %d effects ticked and pressed" % total)
	change_scene_to_file("res://scenes/cube_vfx.tscn")
	process_frame.connect(_tick)

func _tick() -> void:
	frame += 1
	if frame % 8 == 0:
		var k := InputEventKey.new()
		k.keycode = KEY_RIGHT
		k.pressed = true
		Input.parse_input_event(k)
		page += 1
		if page > FAMILIES.size() + 1:
			print("CODEX TEST COMPLETE — all %d effects, all %d pages drawn" % [total, FAMILIES.size()])
			quit()
