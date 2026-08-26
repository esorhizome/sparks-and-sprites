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
const CubeKit := preload("res://scenes/cubefx/kit.gd")

const COLS := 5
const CELL := Vector2(188, 200)
const STAGE := Vector2(176, 128)
const ORIGIN := Vector2(14, 64)

var page := 0
var t := 0.0
var built := {}

func _buttons() -> Array:
	if not built.has(page):
		var fam: GDScript = FAMILIES[page]
		var list := []
		for i in fam.DEFS.size():
			var def: Dictionary = fam.DEFS[i]
			var cell: Vector2 = ORIGIN + Vector2((i % COLS) * CELL.x, floorf(i / float(COLS)) * CELL.y)
			var b := { "id": def.id, "name": def.name, "hint": def.hint,
				"rect": Rect2(cell + Vector2(6, 0), STAGE) }
			CubeKit.setup(b)
			fam.init(b)
			list.append(b)
		built[page] = list
	return built[page]

func _process(delta: float) -> void:
	t += delta
	var fam: GDScript = FAMILIES[page]
	for b in _buttons():
		CubeKit.tick_cube(b, delta)
		fam.tick(b, delta, t)
	queue_redraw()

func _draw() -> void:
	var fam: GDScript = FAMILIES[page]
	var count := 0
	for f in FAMILIES:
		count += f.DEFS.size()
	draw_string(ThemeDB.fallback_font, Vector2(14, 24),
		"THE CUBE CODEX — %d character effects — %s (%d/%d): %s" %
		[count, fam.TITLE, page + 1, FAMILIES.size(), fam.BLURB],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.66, 0.64, 0.77))
	draw_string(ThemeDB.fallback_font, Vector2(14, 42),
		"←/→ turn the page of families · click a card to trigger its move · Esc = menu",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.52, 0.5, 0.62))
	for b in _buttons():
		fam.draw(self, b, t)
		var r: Rect2 = b.rect
		draw_rect(r, Color(0.35, 0.33, 0.47, 0.5), false, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x - 6, r.position.y + r.size.y + 16),
			b.name, HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 12, 12, Color(0.72, 0.7, 0.82))
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x - 6, r.position.y + r.size.y + 31),
			b.hint, HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 12, 9, Color(0.5, 0.48, 0.6))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var fam: GDScript = FAMILIES[page]
		for b in _buttons():
			if (b.rect as Rect2).grow(6.0).has_point(event.position):
				fam.press(b, event.position)
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/menu.tscn")
			KEY_RIGHT, KEY_PAGEDOWN:
				page = (page + 1) % FAMILIES.size()
			KEY_LEFT, KEY_PAGEUP:
				page = (page - 1 + FAMILIES.size()) % FAMILIES.size()
