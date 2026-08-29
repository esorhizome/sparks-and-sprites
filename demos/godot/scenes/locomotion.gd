extends Node2D
## THE LOCOMOTION LEXICON — 26 movement styles, A to Z, in GDScript.
## The full port of the web page (docs/locomotion.html): the maths of
## procedural animation, one card per letter — sines and polar coordinates,
## springs and damping ratios, steering brains, joint chains, verlet
## bodies, raycasts — ending with G · Gait, a two-legged walker that
## spends everything the other twenty-five cards earn.
##
## One page per family (←/→ turns pages). Click a card to poke it — most
## cards aim at where you click. Esc = menu.
##
## The styles live in scenes/motion/ — one file per family, each style an
## init/press/tick/draw quartet over a card dictionary. scenes/motion/kit.gd
## owns the stage, the ground, the arrows, and the mote protagonist.
## All demo maths is CARD-LOCAL (0,0 at the card's corner), exactly like
## the web version — a draw transform adds the offset.

const FAMILIES := [
	preload("res://scenes/motion/clocks.gd"),
	preload("res://scenes/motion/springs.gd"),
	preload("res://scenes/motion/steer.gd"),
	preload("res://scenes/motion/chains.gd"),
	preload("res://scenes/motion/bodies.gd"),
]
const Kit := preload("res://scenes/motion/kit.gd")

const COLS := 4
const CELL := Vector2(232, 216)
const STAGE := Vector2(220, 150)
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
			Kit.setup(b)
			fam.init(b)
			list.append(b)
		built[page] = list
	return built[page]

func _process(delta: float) -> void:
	t += delta
	for b in _buttons():
		FAMILIES[page].tick(b, delta, t)
	queue_redraw()

func _draw() -> void:
	var fam: GDScript = FAMILIES[page]
	var count := 0
	for f in FAMILIES:
		count += f.DEFS.size()
	draw_string(ThemeDB.fallback_font, Vector2(14, 24),
		"THE LOCOMOTION LEXICON — %d movement styles, A to Z — %s (%d/%d): %s" %
		[count, fam.TITLE, page + 1, FAMILIES.size(), fam.BLURB],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.66, 0.64, 0.77))
	draw_string(ThemeDB.fallback_font, Vector2(14, 42),
		"←/→ turn the page · click a card to poke it (most aim at your click) · Esc = menu",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.52, 0.5, 0.62))
	for b in _buttons():
		var r: Rect2 = b.rect
		draw_set_transform(r.position, 0.0, Vector2.ONE)   # demo maths is card-local
		FAMILIES[page].draw(self, b, t)
		draw_set_transform_matrix(Transform2D())
		draw_rect(r, Color(0.35, 0.33, 0.47, 0.5), false, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x - 6, r.position.y + r.size.y + 16),
			b.name, HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 12, 12, Color(0.72, 0.7, 0.82))
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x - 6, r.position.y + r.size.y + 31),
			b.hint, HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 12, 9, Color(0.5, 0.48, 0.6))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for b in _buttons():
			if (b.rect as Rect2).grow(6.0).has_point(event.position):
				FAMILIES[page].press(b, event.position - (b.rect as Rect2).position)
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/menu.tscn")
			KEY_RIGHT, KEY_PAGEDOWN:
				page = (page + 1) % FAMILIES.size()
			KEY_LEFT, KEY_PAGEUP:
				page = (page - 1 + FAMILIES.size()) % FAMILIES.size()
