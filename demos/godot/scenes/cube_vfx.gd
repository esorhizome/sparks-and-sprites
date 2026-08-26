extends Node2D
## THE CUBE CODEX — one protagonist, 104 effects, in GDScript.
## The full port of the web page (docs/cube-vfx.html): fourteen effect
## families, one page per family (←/→ turns pages), every card a little
## stage where the cube patrols and one effect attaches to it, launches
## from it, or happens to it. Click a card to trigger its press reaction —
## some effects aim at where you click. Esc = menu.
##
## The effects live in scenes/cubefx/ — one file per family, each effect
## ~25 lines of init/tick/press/draw. scenes/cubefx/kit.gd owns the cube:
## its patrol, its shadow, its earnest eyes.
##
## RIGHT-CLICK a card to hear its RHYME: the same move with two or three
## dials turned (scenes/cubefx/*_r.gd). Each rhyme file preloads its
## original as Base and overrides only the branches whose dials moved —
## diffing original against rhyme IS the lesson.

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
## Index-aligned with FAMILIES: the rhyme layer for each family.
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

const COLS := 5
const CELL := Vector2(188, 200)
const STAGE := Vector2(176, 128)
const ORIGIN := Vector2(14, 64)

var page := 0
var t := 0.0
var built := {}

func _script_for(b: Dictionary) -> GDScript:
	return RHYME_FAMILIES[page] if b.rhyme else FAMILIES[page]

func _buttons() -> Array:
	if not built.has(page):
		var fam: GDScript = FAMILIES[page]
		var list := []
		for i in fam.DEFS.size():
			var def: Dictionary = fam.DEFS[i]
			var cell: Vector2 = ORIGIN + Vector2((i % COLS) * CELL.x, floorf(i / float(COLS)) * CELL.y)
			var b := { "id": def.id, "name": def.name, "hint": def.hint, "rhyme": false,
				"rect": Rect2(cell + Vector2(6, 0), STAGE) }
			CubeKit.setup(b)
			fam.init(b)
			list.append(b)
		built[page] = list
	return built[page]

## Swap a card between its original and its rhyme: same id, same stage,
## a freshly seeded cube and state owned by whichever file has it now.
func _toggle_rhyme(list: Array, idx: int) -> void:
	var old: Dictionary = list[idx]
	var b := { "id": old.id, "name": old.name, "hint": old.hint,
		"rhyme": not old.rhyme, "rect": old.rect }
	CubeKit.setup(b)
	_script_for(b).init(b)
	list[idx] = b

func _process(delta: float) -> void:
	t += delta
	for b in _buttons():
		CubeKit.tick_cube(b, delta)
		_script_for(b).tick(b, delta, t)
	queue_redraw()

func _draw() -> void:
	var fam: GDScript = FAMILIES[page]
	var count := 0
	for f in FAMILIES:
		count += f.DEFS.size()
	draw_string(ThemeDB.fallback_font, Vector2(14, 24),
		"THE CUBE CODEX — %d character effects (+%d rhymes) — %s (%d/%d): %s" %
		[count, count, fam.TITLE, page + 1, FAMILIES.size(), fam.BLURB],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.66, 0.64, 0.77))
	draw_string(ThemeDB.fallback_font, Vector2(14, 42),
		"←/→ turn the page · click a card to trigger its move · RIGHT-CLICK to hear its rhyme · Esc = menu",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.52, 0.5, 0.62))
	for b in _buttons():
		_script_for(b).draw(self, b, t)
		var r: Rect2 = b.rect
		draw_rect(r, Color(0.35, 0.33, 0.47, 0.5) if not b.rhyme else Color(0.35, 0.55, 0.42, 0.6), false, 1.0)
		var cname: String = b.name
		var chint: String = b.hint
		var ccol := Color(0.72, 0.7, 0.82)
		if b.rhyme:
			var rh: Dictionary = RHYME_FAMILIES[page].RHYMES[b.id]
			cname = "%s ⇄" % rh.name
			chint = rh.hint
			ccol = Color(0.55, 0.85, 0.65)
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x - 6, r.position.y + r.size.y + 16),
			cname, HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 12, 12, ccol)
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x - 6, r.position.y + r.size.y + 31),
			chint, HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 12, 9, Color(0.5, 0.48, 0.6))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var list: Array = _buttons()
		for i in list.size():
			var b: Dictionary = list[i]
			if (b.rect as Rect2).grow(6.0).has_point(event.position):
				if event.button_index == MOUSE_BUTTON_RIGHT:
					_toggle_rhyme(list, i)
				else:
					_script_for(b).press(b, event.position)
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/menu.tscn")
			KEY_RIGHT, KEY_PAGEDOWN:
				page = (page + 1) % FAMILIES.size()
			KEY_LEFT, KEY_PAGEUP:
				page = (page - 1 + FAMILIES.size()) % FAMILIES.size()
