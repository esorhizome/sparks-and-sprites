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

const COLS := 5
const CELL := Vector2(188, 150)
const BTN := Vector2(150, 62)
const ORIGIN := Vector2(14, 84)

var page := 0
var t := 0.0
var built := {}          # page index → its buttons, kept alive across visits

func _ready() -> void:
	pass                  # everything is drawn in _draw(); state builds lazily

func _buttons() -> Array:
	if not built.has(page):
		var fam: GDScript = FAMILIES[page]
		var list := []
		for i in fam.DEFS.size():
			var def: Dictionary = fam.DEFS[i]
			var cell: Vector2 = ORIGIN + Vector2((i % COLS) * CELL.x, floorf(i / float(COLS)) * CELL.y)
			var b := {
				"id": def.id, "name": def.name, "hint": def.hint,
				"rect": Rect2(cell + (Vector2(CELL.x, CELL.y - 44) - BTN) / 2.0, BTN),
			}
			fam.init(b)
			list.append(b)
		built[page] = list
	return built[page]

func _process(delta: float) -> void:
	t += delta
	var fam: GDScript = FAMILIES[page]
	for b in _buttons():
		fam.tick(b, delta, t)
	queue_redraw()

func _draw() -> void:
	var fam: GDScript = FAMILIES[page]
	var count := 0
	for f in FAMILIES:
		count += f.DEFS.size()
	draw_string(ThemeDB.fallback_font, Vector2(14, 26),
		"THE ELEMENTAL BUTTON BESTIARY — %d buttons — %s (%d/%d): %s" %
		[count, fam.TITLE, page + 1, FAMILIES.size(), fam.BLURB],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.66, 0.64, 0.77))
	draw_string(ThemeDB.fallback_font, Vector2(14, 46),
		"←/→ turn the page of families · click a button to press it · Esc = menu",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.52, 0.5, 0.62))
	for b in _buttons():
		fam.draw(self, b, t)
		var r: Rect2 = b.rect
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x - 16, r.position.y + r.size.y + 18),
			b.name, HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 32, 12, Color(0.72, 0.7, 0.82))
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x - 16, r.position.y + r.size.y + 33),
			b.hint, HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 32, 9, Color(0.5, 0.48, 0.6))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var fam: GDScript = FAMILIES[page]
		for b in _buttons():
			if (b.rect as Rect2).grow(8.0).has_point(event.position):
				fam.press(b, event.position - (b.rect as Rect2).position)
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/menu.tscn")
			KEY_RIGHT, KEY_PAGEDOWN:
				page = (page + 1) % FAMILIES.size()
			KEY_LEFT, KEY_PAGEUP:
				page = (page - 1 + FAMILIES.size()) % FAMILIES.size()
