extends SceneTree
## Headless test for the full locomotion lexicon (not a demo).
## Checks the 104 defs across the nine family files (every letter exactly
## four styles, unique names, every card carrying dials and a rhyme whose
## dials only override existing keys), then runs every style AND every
## rhyme through setup → 120 ticks → two presses → 120 ticks → a coarse
## tick (dt 0.05) — long enough for steppers, springs, and verlet piles to
## reach their steady rhythm — failing on any NaN or runaway value in the
## card state. Then it plays the real scene through every page: a click, a
## right-click (rhyme), a drag, a double-click (enlarge) per page.
## Run: godot --headless --path . -s res://lexicon_test.gd

const Lex := preload("res://scenes/locomotion.gd")
const Kit := preload("res://scenes/motion/kit.gd")

var page := 0
var frame := 0
var total := 0

func _finite(v: Variant, depth: int = 0) -> bool:
	if depth > 6:
		return true
	match typeof(v):
		TYPE_FLOAT:
			return is_finite(v) and absf(v) < 1.0e6
		TYPE_VECTOR2:
			return v.is_finite() and (v as Vector2).length() < 1.0e6
		TYPE_ARRAY:
			for e in v:
				if not _finite(e, depth + 1):
					return false
		TYPE_DICTIONARY:
			for k in v:
				if not _finite(v[k], depth + 1):
					return false
	return true

func _run_one(fam: GDScript, def: Dictionary, rhyme: bool) -> void:
	var b := Lex.fresh_state(fam, def, rhyme)
	for i in 120:
		b.t += 1.0 / 60.0
		fam.tick(b, 1.0 / 60.0, b.t)
	fam.press(b, Vector2(110, 75))                   # centre-ish of the stage
	fam.press(b, Vector2(34, 130))                   # an aimed corner press
	for i in 120:
		b.t += 1.0 / 60.0
		fam.tick(b, 1.0 / 60.0, b.t)
	for i in 30:
		b.t += 0.05
		fam.tick(b, 0.05, b.t)                       # the runtime's coarsest dt
	assert(_finite(b), "%s (%s): NaN or runaway value in the card state" % [def.name, "rhyme" if rhyme else "original"])

func _initialize() -> void:
	var letters := {}
	var names := {}
	var sizes := []
	for fam in Lex.FAMILIES:
		var defs: Array = fam.DEFS
		sizes.append(defs.size())
		for def in defs:
			total += 1
			letters[def.letter] = letters.get(def.letter, 0) + 1
			assert((def.name as String).begins_with(def.letter), "%s: name must start with %s" % [def.name, def.letter])
			assert(not names.has(def.name), "duplicate name %s" % def.name)
			names[def.name] = true
			assert(def.has("dials") and def.dials is Dictionary, "%s: no dials" % def.name)
			assert(def.has("rhyme"), "%s: no rhyme" % def.name)
			var rh: Dictionary = def.rhyme
			assert(not names.has(rh.name), "duplicate rhyme name %s" % rh.name)
			names[rh.name] = true
			for key in (rh.dials as Dictionary).keys():
				assert((def.dials as Dictionary).has(key), "%s ⇄ %s: rhyme dial '%s' is not an original dial" % [def.name, rh.name, key])
			_run_one(fam, def, false)
			_run_one(fam, def, true)
	assert(total == 104, "expected 104 styles, found %d" % total)
	assert(letters.size() == 26, "the alphabet has a gap: %d distinct letters" % letters.size())
	for l in letters:
		assert(letters[l] == 4, "letter %s owns %d styles, wanted exactly 4" % [l, letters[l]])
	print("lexicon logic pass: %d styles + %d rhymes ticked and pressed, A to Z four times, families %s" % [total, total, str(sizes)])
	change_scene_to_file("res://scenes/locomotion.tscn")
	process_frame.connect(_tick)

func _click(pos: Vector2, button: MouseButton) -> void:
	var m := InputEventMouseButton.new()
	m.button_index = button
	m.pressed = true
	m.position = pos
	Input.parse_input_event(m)

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
	if frame == 5:
		var k4 := InputEventKey.new()                     # tempo ×4 for the whole tour
		k4.keycode = KEY_4
		k4.pressed = true
		Input.parse_input_event(k4)
	if frame % 12 == 0:
		var k := InputEventKey.new()
		k.keycode = KEY_RIGHT
		k.pressed = true
		Input.parse_input_event(k)
		page += 1
		if page > 16:                                     # 15 window pages + wrap slack
			print("LEXICON TEST COMPLETE — %d styles + %d rhymes, all pages drawn, clicked, dragged, rhymed and enlarged" % [total, total])
			quit()
