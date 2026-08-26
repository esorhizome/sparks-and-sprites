extends SceneTree
## Headless test for the full elemental bestiary (not a demo).
## Every one of the 104 buttons: init → 60 ticks → two presses → 60 ticks,
## then one draw pass per family page inside a real scene.
## Run: godot --headless --path . -s res://bestiary_test.gd

const FAMILIES := [
	preload("res://scenes/elements/fire.gd"),
	preload("res://scenes/elements/lightning.gd"),
	preload("res://scenes/elements/water.gd"),
	preload("res://scenes/elements/metal.gd"),
	preload("res://scenes/elements/ice.gd"),
	preload("res://scenes/elements/earth.gd"),
	preload("res://scenes/elements/air.gd"),
	preload("res://scenes/elements/light.gd"),
	preload("res://scenes/elements/sparkfx.gd"),
	preload("res://scenes/elements/cosmic.gd"),
	preload("res://scenes/elements/nature.gd"),
	preload("res://scenes/elements/acid.gd"),
	preload("res://scenes/elements/crystal.gd"),
	preload("res://scenes/elements/weather.gd"),
]

var page := 0
var frame := 0
var scene: Node2D
var total := 0

func _initialize() -> void:
	# state/tick/press coverage, off-screen: every button, deterministically
	for fam in FAMILIES:
		for def in fam.DEFS:
			var b := { "id": def.id, "name": def.name, "hint": def.hint,
				"rect": Rect2(Vector2(33, 106), Vector2(150, 62)) }
			fam.init(b)
			var t := 0.0
			for i in 60:
				t += 1.0 / 60.0
				fam.tick(b, 1.0 / 60.0, t)
			fam.press(b, Vector2(75, 31))
			fam.press(b, Vector2(5, 5))
			for i in 60:
				t += 1.0 / 60.0
				fam.tick(b, 1.0 / 60.0, t)
			total += 1
	print("bestiary logic pass: %d buttons ticked and pressed" % total)
	# draw coverage: run the real scene and turn every page
	change_scene_to_file("res://scenes/elemental_buttons.tscn")
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
			print("BESTIARY TEST COMPLETE — all %d buttons, all %d pages drawn" % [total, FAMILIES.size()])
			quit()
