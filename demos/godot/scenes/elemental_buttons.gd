extends Node2D
## THE ELEMENTAL BUTTON BESTIARY — all 104 buttons, in GDScript.
## The full port of the web page: fourteen element families, one page per
## family (←/→ or PgUp/PgDn to turn pages), every button an idle loop plus
## a press reaction. Click any button. Esc = menu. Chapter 12.
##
## The buttons themselves live in scenes/elements/ — one file per family,
## each effect ~25 lines: init() seeds state, tick() advances it, draw()
## paints it, press() is the thank-you. scenes/elements/kit.gd holds the
## shared face/label/glow/curve helpers. Nothing here is beyond _draw() —
## the whole bestiary is plain 2D arithmetic, same as the web canvas.
##
## RIGHT-CLICK a button to hear its RHYME: the same effect with two or
## three dials turned (scenes/elements/*_r.gd). Each rhyme file preloads
## its original as Base and overrides only the branches whose dials moved —
## diffing original against rhyme IS the lesson.

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
## Index-aligned with FAMILIES: the rhyme layer for each family.
const RHYME_FAMILIES := [
	preload("res://scenes/elements/fire_r.gd"),
	preload("res://scenes/elements/lightning_r.gd"),
	preload("res://scenes/elements/water_r.gd"),
	preload("res://scenes/elements/metal_r.gd"),
	preload("res://scenes/elements/ice_r.gd"),
	preload("res://scenes/elements/earth_r.gd"),
	preload("res://scenes/elements/air_r.gd"),
	preload("res://scenes/elements/light_r.gd"),
	preload("res://scenes/elements/sparkfx_r.gd"),
	preload("res://scenes/elements/cosmic_r.gd"),
	preload("res://scenes/elements/nature_r.gd"),
	preload("res://scenes/elements/acid_r.gd"),
	preload("res://scenes/elements/crystal_r.gd"),
	preload("res://scenes/elements/weather_r.gd"),
]

const COLS := 5
const CELL := Vector2(188, 150)
const BTN := Vector2(150, 62)
const ORIGIN := Vector2(14, 84)

var page := 0
var t := 0.0
var built := {}          # page index → its buttons, kept alive across visits

func _ready() -> void:
	pass                  # everything is drawn in _draw(); state builds lazily

func _script_for(b: Dictionary) -> GDScript:
	return RHYME_FAMILIES[page] if b.rhyme else FAMILIES[page]

func _buttons() -> Array:
	if not built.has(page):
		var fam: GDScript = FAMILIES[page]
		var list := []
		for i in fam.DEFS.size():
			var def: Dictionary = fam.DEFS[i]
			var cell: Vector2 = ORIGIN + Vector2((i % COLS) * CELL.x, floorf(i / float(COLS)) * CELL.y)
			var b := {
				"id": def.id, "name": def.name, "hint": def.hint, "rhyme": false,
				"rect": Rect2(cell + (Vector2(CELL.x, CELL.y - 44) - BTN) / 2.0, BTN),
			}
			fam.init(b)
			list.append(b)
		built[page] = list
	return built[page]

## Swap a button between its original and its rhyme: same id, same rect,
## fresh state seeded by whichever file now owns it.
func _toggle_rhyme(list: Array, idx: int) -> void:
	var old: Dictionary = list[idx]
	var b := { "id": old.id, "name": old.name, "hint": old.hint,
		"rhyme": not old.rhyme, "rect": old.rect }
	_script_for(b).init(b)
	list[idx] = b

func _process(delta: float) -> void:
	t += delta
	for b in _buttons():
		_script_for(b).tick(b, delta, t)
	queue_redraw()

func _draw() -> void:
	var fam: GDScript = FAMILIES[page]
	var count := 0
	for f in FAMILIES:
		count += f.DEFS.size()
	draw_string(ThemeDB.fallback_font, Vector2(14, 26),
		"THE ELEMENTAL BUTTON BESTIARY — %d buttons (+%d rhymes) — %s (%d/%d): %s" %
		[count, count, fam.TITLE, page + 1, FAMILIES.size(), fam.BLURB],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.66, 0.64, 0.77))
	draw_string(ThemeDB.fallback_font, Vector2(14, 46),
		"←/→ turn the page · click a button to press it · RIGHT-CLICK to hear its rhyme · Esc = menu",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.52, 0.5, 0.62))
	for b in _buttons():
		_script_for(b).draw(self, b, t)
		var r: Rect2 = b.rect
		var cname: String = b.name
		var chint: String = b.hint
		var ccol := Color(0.72, 0.7, 0.82)
		if b.rhyme:
			var rh: Dictionary = RHYME_FAMILIES[page].RHYMES[b.id]
			cname = "%s ⇄" % rh.name
			chint = rh.hint
			ccol = Color(0.55, 0.85, 0.65)
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x - 16, r.position.y + r.size.y + 18),
			cname, HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 32, 12, ccol)
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x - 16, r.position.y + r.size.y + 33),
			chint, HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 32, 9, Color(0.5, 0.48, 0.6))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var list: Array = _buttons()
		for i in list.size():
			var b: Dictionary = list[i]
			if (b.rect as Rect2).grow(8.0).has_point(event.position):
				if event.button_index == MOUSE_BUTTON_RIGHT:
					_toggle_rhyme(list, i)
				else:
					_script_for(b).press(b, event.position - (b.rect as Rect2).position)
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/menu.tscn")
			KEY_RIGHT, KEY_PAGEDOWN:
				page = (page + 1) % FAMILIES.size()
			KEY_LEFT, KEY_PAGEUP:
				page = (page - 1 + FAMILIES.size()) % FAMILIES.size()
