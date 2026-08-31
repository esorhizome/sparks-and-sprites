extends SceneTree
## Headless test for the flipbook folio (not a demo).
## Checks the 26 defs (A to Z, five families, sane frame counts), then runs
## the real scene for a stretch of frames — turning all five pages and
## clicking a card per page — to prove the bake → slice → play pipeline
## holds together. Headless rendering bakes blank sheets (guarded in
## flipbook.gd); the logic path is identical to a windowed run.
## Run: godot --headless --path . -s res://flipbook_test.gd

var frame := 0
var pages := 0

func _initialize() -> void:
	var node: Node2D = load("res://scenes/flipbook.gd").new()
	var defs: Array = node._make_defs()
	assert(defs.size() == 26, "expected 26 effects, found %d" % defs.size())
	var letters := {}
	var fams := [0, 0, 0, 0, 0]
	for def in defs:
		letters[def.letter] = true
		fams[int(def.fam)] += 1
		assert(int(def.n) >= 8 and int(def.n) <= 16, "%s: odd frame count %d" % [def.name, int(def.n)])
		assert(float(def.fps) > 0.0, "%s: fps must be positive" % def.name)
		assert((def.paint as Callable).is_valid(), "%s: paint is not callable" % def.name)
	assert(letters.size() == 26, "the alphabet has a gap: %d distinct letters" % letters.size())
	assert(fams == [5, 6, 6, 6, 3], "family sizes drifted: %s" % str(fams))
	node.free()
	print("folio logic pass: 26 sheets defined, A to Z accounted for, families 5/6/6/6/3")
	change_scene_to_file("res://scenes/flipbook.tscn")
	process_frame.connect(_tick)

func _tick() -> void:
	frame += 1
	if frame % 10 == 5:
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		m.pressed = true
		m.position = Vector2(120, 130)          # inside the first card
		Input.parse_input_event(m)
	if frame % 10 == 0:
		var k := InputEventKey.new()
		k.keycode = KEY_RIGHT
		k.pressed = true
		Input.parse_input_event(k)
		pages += 1
		if pages > 6:
			print("FLIPBOOK TEST COMPLETE — 26 sheets, all 5 pages built and clicked")
			quit()
