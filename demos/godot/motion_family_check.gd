extends SceneTree
## Headless check for ONE locomotion-lexicon family file (not a demo).
## Validates the DEFS (letters, names, hints, dials, rhymes whose dials only
## override real dials), then builds every card twice — original and rhyme
## — inside a real scene tree so init / tick / press / draw all execute
## headlessly, at the card size and at the enlarged size. Any NaN or
## runaway value in a card's dictionary after the run fails the check.
## Run: godot --headless --path . -s res://motion_family_check.gd -- res://scenes/motion/clocks.gd [expected-count]

const Lex := preload("res://scenes/locomotion.gd")

var painters: Array = []
var frame := 0
var title := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() >= 1, "pass the family file path after --")
	var fam: GDScript = load(args[0])
	var defs: Array = fam.DEFS
	title = fam.TITLE
	if args.size() >= 2:
		assert(defs.size() == int(args[1]), "expected %s cards, found %d" % [args[1], defs.size()])
	var letters := {}
	var names := {}
	var ids := {}
	for def in defs:
		assert(def.has("id") and not ids.has(def.id), "duplicate or missing id in %s" % str(def))
		ids[def.id] = true
		assert(def.has("letter") and (def.letter as String).length() == 1, "%s: letter missing" % def.id)
		assert(def.has("name") and (def.name as String).begins_with(def.letter), "%s: name must start with its letter" % def.id)
		letters[def.letter] = letters.get(def.letter, 0) + 1
		assert(not names.has(def.name), "duplicate name %s" % def.name)
		names[def.name] = true
		assert(def.has("hint") and (def.hint as String).length() > 20, "%s: hint missing" % def.name)
		assert(def.has("dials") and def.dials is Dictionary, "%s: no dials" % def.name)
		assert(def.has("rhyme"), "%s: no rhyme" % def.name)
		var rh: Dictionary = def.rhyme
		assert(rh.has("name") and rh.has("hint") and rh.has("dials"), "%s: rhyme incomplete" % def.name)
		assert((rh.name as String).begins_with(def.letter), "%s: rhyme name must start with %s" % [rh.name, def.letter])
		assert(not names.has(rh.name), "duplicate rhyme name %s" % rh.name)
		names[rh.name] = true
		var moved := 0
		for key in (rh.dials as Dictionary).keys():
			assert((def.dials as Dictionary).has(key), "%s ⇄ %s: rhyme dial '%s' is not an original dial" % [def.name, rh.name, key])
			if key != "label":
				moved += 1
		assert(moved >= 1, "%s ⇄ %s: a rhyme must move a dial besides label" % [def.name, rh.name])
	print("%s: %d cards, letters %s" % [title, defs.size(), str(letters)])
	var root := Node2D.new()
	get_root().add_child(root)
	for def in defs:
		for rhyme in [false, true]:
			for size in [Lex.STAGE, Lex.BIG]:
				var clip := Control.new()
				clip.size = size
				clip.clip_contents = true
				root.add_child(clip)
				var p := Lex.Painter.new()
				p.fam = fam
				p.b = Lex.fresh_state(fam, def, rhyme, size)
				clip.add_child(p)
				painters.append(p)
	process_frame.connect(_tick)

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

func _tick() -> void:
	frame += 1
	if frame == 20 or frame == 45 or frame == 70:
		for p in painters:
			var s: Vector2 = (p.b.rect as Rect2).size
			var spots := [Vector2(0.5, 0.45), Vector2(0.15, 0.8), Vector2(0.9, 0.2)]
			var k: Vector2 = spots[(frame / 25) % 3]
			p.fam.press(p.b, Vector2(s.x * k.x, s.y * k.y))
	if frame == 30:
		for p in painters:              # jump ahead in time so slow clocks and schedules wrap
			p.b.t += 40.0
	if frame >= 90:
		for p in painters:
			if not _finite(p.b):
				push_error("%s (%s): a NaN or runaway value is in the card state after %d frames" % [p.b.name, "rhyme" if p.b.rhyme else "original", frame])
				quit(1)
				return
		print("FAMILY CHECK COMPLETE — %s: %d painters (originals + rhymes, two sizes) drew %d frames and took three presses" % [title, painters.size(), frame])
		quit()
