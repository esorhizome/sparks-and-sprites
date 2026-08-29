extends SceneTree
## Headless test for the full locomotion lexicon (not a demo).
## Every one of the 26 movement styles: setup → 120 ticks → two presses →
## 120 ticks (long enough for steppers, springs, and verlet piles to reach
## their steady rhythm), then one draw pass per family page inside the
## real scene, with a click per page.
## Run: godot --headless --path . -s res://lexicon_test.gd

const FAMILIES := [
	preload("res://scenes/motion/clocks.gd"),
	preload("res://scenes/motion/springs.gd"),
	preload("res://scenes/motion/steer.gd"),
	preload("res://scenes/motion/chains.gd"),
	preload("res://scenes/motion/bodies.gd"),
]
const Kit := preload("res://scenes/motion/kit.gd")

var page := 0
var frame := 0
var total := 0

func _run_one(script: GDScript, def: Dictionary) -> void:
	var b := { "id": def.id, "name": def.name, "hint": def.hint,
		"rect": Rect2(Vector2(20, 64), Vector2(220, 150)) }
	Kit.setup(b)
	script.init(b)
	var t := 0.0
	for i in 120:
		t += 1.0 / 60.0
		script.tick(b, 1.0 / 60.0, t)
	script.press(b, Vector2(110, 75))           # centre-ish of the stage
	script.press(b, Vector2(34, 130))           # an aimed corner press
	for i in 120:
		t += 1.0 / 60.0
		script.tick(b, 1.0 / 60.0, t)

func _initialize() -> void:
	var letters := {}
	for fam in FAMILIES:
		for def in fam.DEFS:
			_run_one(fam, def)
			total += 1
			letters[(def.name as String).substr(0, 1)] = true
	assert(total == 26, "expected 26 styles, found %d" % total)
	assert(letters.size() == 26, "the alphabet has a gap: %d distinct letters" % letters.size())
	print("lexicon logic pass: %d styles ticked and pressed, A to Z accounted for" % total)
	change_scene_to_file("res://scenes/locomotion.tscn")
	process_frame.connect(_tick)

func _tick() -> void:
	frame += 1
	if frame % 8 == 3:
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		m.pressed = true
		m.position = Vector2(120, 120)
		Input.parse_input_event(m)
	if frame % 8 == 0:
		var k := InputEventKey.new()
		k.keycode = KEY_RIGHT
		k.pressed = true
		Input.parse_input_event(k)
		page += 1
		if page > FAMILIES.size() + 1:
			print("LEXICON TEST COMPLETE — %d styles, all %d pages drawn" % [total, FAMILIES.size()])
			quit()
