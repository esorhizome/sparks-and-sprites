extends SceneTree
## Headless test for the depth atlas (not a demo).
## Checks the 104 defs across the eight family files (every letter exactly
## four pictures, every picture carrying a rhyme with dials that only
## override existing keys), then runs the real scene through every page,
## clicking and right-clicking a card per page so init / press / draw and
## the rhyme swap all execute headlessly.
## Run: godot --headless --path . -s res://depth_test.gd

var frame := 0
var pages := 0

func _initialize() -> void:
	var scene_script: GDScript = load("res://scenes/depth.gd")
	var fams: Array = scene_script.FAMILIES
	var letters := {}
	var names := {}
	var total := 0
	var sizes := []
	for fam in fams:
		var defs: Array = fam.defs()
		sizes.append(defs.size())
		for def in defs:
			total += 1
			letters[def.letter] = letters.get(def.letter, 0) + 1
			assert(not names.has(def.name), "duplicate name %s" % def.name)
			names[def.name] = true
			assert((def.draw as Callable).is_valid(), "%s: draw is not callable" % def.name)
			assert(def.has("dials") and def.dials is Dictionary, "%s: no dials" % def.name)
			assert(def.has("rhyme"), "%s: no rhyme" % def.name)
			var rh: Dictionary = def.rhyme
			assert(not names.has(rh.name), "duplicate rhyme name %s" % rh.name)
			names[rh.name] = true
			for key in (rh.dials as Dictionary).keys():
				assert((def.dials as Dictionary).has(key), "%s ⇄ %s: rhyme dial '%s' is not an original dial" % [def.name, rh.name, key])
	assert(total == 104, "expected 104 pictures, found %d" % total)
	assert(letters.size() == 26, "the alphabet has a gap: %d distinct letters" % letters.size())
	for l in letters:
		assert(letters[l] == 4, "letter %s owns %d pictures, wanted exactly 4" % [l, letters[l]])
	print("atlas logic pass: 104 pictures + 104 rhymes, A to Z four times, families %s" % str(sizes))
	change_scene_to_file("res://scenes/depth.tscn")
	process_frame.connect(_tick)

func _tick() -> void:
	frame += 1
	if frame % 12 == 4:
		_click(Vector2(120, 130), MOUSE_BUTTON_LEFT)      # inside the first card
	if frame % 12 == 7:
		_click(Vector2(352, 130), MOUSE_BUTTON_RIGHT)     # the second card: swap to its rhyme
	if frame % 12 == 9:
		_click(Vector2(352, 130), MOUSE_BUTTON_LEFT)      # press the rhyme too
	if frame % 12 == 10:
		var mm := InputEventMouseMotion.new()             # a drag across the rhyme (button still held)
		mm.position = Vector2(420, 140)
		Input.parse_input_event(mm)
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = Vector2(420, 140)
		Input.parse_input_event(up)
	if frame % 24 == 11:
		var dc := InputEventMouseButton.new()             # double-click: open the big view …
		dc.button_index = MOUSE_BUTTON_LEFT
		dc.pressed = true
		dc.double_click = true
		dc.position = Vector2(584, 130)
		Input.parse_input_event(dc)
	if frame % 24 == 13:
		_click(Vector2(480, 280), MOUSE_BUTTON_LEFT)      # … press inside it …
	if frame % 24 == 15:
		_click(Vector2(480, 280), MOUSE_BUTTON_RIGHT)     # … swap to its rhyme …
	if frame % 24 == 17:
		var k2 := InputEventKey.new()                     # … and close it with Esc
		k2.keycode = KEY_ESCAPE
		k2.pressed = true
		Input.parse_input_event(k2)
	if frame % 12 == 0:
		var k := InputEventKey.new()
		k.keycode = KEY_RIGHT
		k.pressed = true
		Input.parse_input_event(k)
		pages += 1
		if pages > 17:                                    # 16 window pages + wrap slack
			print("DEPTH TEST COMPLETE — all pages built, clicked, and rhymed")
			quit()

func _click(pos: Vector2, button: MouseButton) -> void:
	var m := InputEventMouseButton.new()
	m.button_index = button
	m.pressed = true
	m.position = pos
	Input.parse_input_event(m)
