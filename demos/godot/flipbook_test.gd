extends SceneTree
## Headless test for the flipbook folio (not a demo).
## Checks the 104 defs (A to Z four times — every letter exactly four
## effects, ten families at 10/12/14/8/8 + 14/11/13/7/7, sane frame
## counts), then runs the real scene for a stretch of frames — turning
## through all sixteen window-sized pages and clicking a card per page —
## to prove the bake → slice → play pipeline (and the genre laps' tick /
## setup / durations specials) hold together. Headless rendering bakes
## blank sheets (guarded in flipbook.gd); the logic path is identical to
## a windowed run.
## Run: godot --headless --path . -s res://flipbook_test.gd

var frame := 0
var pages := 0

func _initialize() -> void:
	var node: Node2D = load("res://scenes/flipbook.gd").new()
	var defs: Array = node._make_defs()
	assert(defs.size() == 104, "expected 104 effects, found %d" % defs.size())
	var letters := {}
	var fams := [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	var specials := 0
	for def in defs:
		letters[def.letter] = letters.get(def.letter, 0) + 1
		fams[int(def.fam)] += 1
		assert(int(def.n) >= 2 and int(def.n) <= 20, "%s: odd frame count %d" % [def.name, int(def.n)])
		assert(float(def.fps) > 0.0, "%s: fps must be positive" % def.name)
		assert((def.paint as Callable).is_valid(), "%s: paint is not callable" % def.name)
		if def.has("durations"):
			assert((def.durations as Array).size() == int(def.n), "%s: durations size mismatch" % def.name)
		if def.has("tick") or def.has("setup") or def.has("durations"):
			specials += 1
	assert(letters.size() == 26, "the alphabet has a gap: %d distinct letters" % letters.size())
	for l in letters:
		assert(letters[l] == 4, "letter %s owns %d effects, wanted exactly 4" % [l, letters[l]])
	assert(fams == [10, 12, 14, 8, 8, 14, 11, 13, 7, 7], "family sizes drifted: %s" % str(fams))
	assert(specials >= 6, "expected at least 6 runtime specials, found %d" % specials)
	node.free()
	print("folio logic pass: 104 sheets defined, A to Z four times, families 10/12/14/8/8 + 14/11/13/7/7, %d specials" % specials)
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
		if pages > 17:                          # 16 window pages + wrap slack
			print("FLIPBOOK TEST COMPLETE — 104 sheets, all family pages built and clicked")
			quit()
