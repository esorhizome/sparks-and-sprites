extends SceneTree
## Headless check for ONE depth-atlas family file (not a demo).
## Validates the defs (letters, rhymes, rhyme dials only overriding real
## dials), then builds every card twice — original and rhyme — inside a
## real scene tree so init / tick / draw / press all execute headlessly.
## Run: godot --headless --path . -s res://depth_family_check.gd -- res://scenes/depth/skies.gd

const DepthScene := preload("res://scenes/depth.gd")

var painters: Array = []
var frame := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() >= 1, "pass the family file path after --")
	var fam: GDScript = load(args[0])
	var defs: Array = fam.defs()
	assert(defs.size() >= 12 and defs.size() <= 14, "expected 12–14 pictures, found %d" % defs.size())
	var letters := {}
	var names := {}
	for def in defs:
		letters[def.letter] = letters.get(def.letter, 0) + 1
		assert(not names.has(def.name), "duplicate name %s" % def.name)
		names[def.name] = true
		assert(def.has("hint") and def.hint.length() > 10, "%s: hint missing" % def.name)
		assert((def.draw as Callable).is_valid(), "%s: draw is not callable" % def.name)
		assert(def.has("dials") and def.dials is Dictionary and def.dials.has("label"), "%s: dials need a 'label'" % def.name)
		assert(def.has("rhyme"), "%s: no rhyme" % def.name)
		var rh: Dictionary = def.rhyme
		assert(rh.has("name") and rh.has("hint") and rh.has("dials"), "%s: rhyme incomplete" % def.name)
		for key in (rh.dials as Dictionary).keys():
			assert((def.dials as Dictionary).has(key), "%s ⇄ %s: rhyme dial '%s' is not an original dial" % [def.name, rh.name, key])
	print("%s: %d pictures, letters %s" % [fam.TITLE, defs.size(), str(letters)])
	var root := Node2D.new()
	get_root().add_child(root)
	for def in defs:
		for rhyme in [false, true]:
			var clip := Control.new()
			clip.size = DepthScene.STAGE
			clip.clip_contents = true
			root.add_child(clip)
			var p := DepthScene.Painter.new()
			p.def = def
			p.b = _state(def, rhyme)
			clip.add_child(p)
			painters.append(p)
	process_frame.connect(_tick)

func _state(def: Dictionary, rhyme: bool) -> Dictionary:
	var D: Dictionary = (def.dials as Dictionary).duplicate(true)
	if rhyme:
		D.merge((def.rhyme as Dictionary).dials, true)
	var b := { "W": DepthScene.STAGE.x, "H": DepthScene.STAGE.y, "t": 0.0, "D": D, "rhyme": rhyme,
		"rng": RandomNumberGenerator.new() }
	if def.has("init"):
		(def.init as Callable).call(b)
	return b

func _tick() -> void:
	frame += 1
	if frame == 20 or frame == 45:
		for p in painters:
			if (p.def as Dictionary).has("press"):
				(p.def.press as Callable).call(p.b, Vector2(DepthScene.STAGE.x * (0.3 if frame == 20 else 0.8), DepthScene.STAGE.y * 0.4))
	if frame == 30:
		for p in painters:              # jump ahead in time so slow clocks wrap
			p.b.t += 17.0
	if frame >= 60:
		print("FAMILY CHECK COMPLETE — %d painters (originals + rhymes) drew 60 frames and took two presses" % painters.size())
		quit()
