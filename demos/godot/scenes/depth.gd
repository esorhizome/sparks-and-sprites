extends Node2D
## THE DEPTH ATLAS — 104 illusions of depth on a flat plane (+104 rhymes), in GDScript.
## The full port of the web page (docs/depth.html): eight families, one page
## of eight cards at a time (←/→ turns pages), every card a little stage where
## a 2D picture is made to look round, far, lit, solid, or in focus — with
## gradients, atmospheric perspective, shading, cast shadows and blur, and
## no 3D anywhere. Click a card to move its light, camera or weather.
## RIGHT-CLICK a card to see its RHYME. Esc = menu.
##
## The pictures live in scenes/depth/ — one file per family, ~20 lines per
## card. scenes/depth/kit.gd is the drawing kit, and its header answers the
## question this whole port turns on: Godot's _draw() has no gradient-fill
## call, so a linear gradient is a polygon with a colour per vertex and a
## radial gradient is a triangle fan with a bright centre — one
## RenderingServer call each.
##
## A RHYME here is literally a dials swap: every card keeps its numbers in a
## dictionary D (palette, counts, speeds); the rhyme is the same painter with
## two or three of those values changed, and nothing else. Right-click merges
## the rhyme's dials over the original's and re-runs init(). That IS the
## lesson — understanding one recipe buys the whole neighbourhood.

const FAMILIES := [
	preload("res://scenes/depth/skies.gd"),
	preload("res://scenes/depth/distance.gd"),
	preload("res://scenes/depth/rounded.gd"),
	preload("res://scenes/depth/facets.gd"),
	preload("res://scenes/depth/lights.gd"),
	preload("res://scenes/depth/volumes.gd"),
	preload("res://scenes/depth/waves.gd"),
	preload("res://scenes/depth/shadows.gd"),
]

const COLS := 4
const CELL := Vector2(232, 232)
const STAGE := Vector2(220, 150)
const ORIGIN := Vector2(14, 64)
const PAGE_CAP := 8              # 4 × 2 cards is what a 960×540 window holds

var pagedefs: Array = []         # families split into window-sized parts
var page := 0
var cards: Array = []            # per-card runtime state for the current page
var holder: Node2D


## One card = a clipping Control (so pictures can't spill into their
## neighbours) holding a Node2D painter that draws in card-local space.
class Painter extends Node2D:
	var def: Dictionary
	var b: Dictionary
	func _process(dt: float) -> void:
		b.t += dt
		if def.has("tick"):
			(def.tick as Callable).call(b, dt)
		queue_redraw()
	func _draw() -> void:
		(def.draw as Callable).call(self, b)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("191527"))   # the gallery's night paper
	_make_pages()
	holder = Node2D.new()
	add_child(holder)
	_build_page()

func _make_pages() -> void:
	pagedefs.clear()
	for fi in FAMILIES.size():
		var list: Array = FAMILIES[fi].defs()
		var parts := int(ceil(list.size() / float(PAGE_CAP)))
		for pi in parts:
			pagedefs.append({ "fam": fi, "part": pi, "parts": parts,
				"list": list.slice(pi * PAGE_CAP, mini(list.size(), (pi + 1) * PAGE_CAP)) })

func _fresh_state(def: Dictionary, rhyme: bool) -> Dictionary:
	var D: Dictionary = (def.dials as Dictionary).duplicate(true)
	if rhyme and def.has("rhyme"):
		D.merge((def.rhyme as Dictionary).dials, true)   # the rhyme's dials win
	var b := { "W": STAGE.x, "H": STAGE.y, "t": 0.0, "D": D, "rhyme": rhyme,
		"rng": RandomNumberGenerator.new() }
	(b.rng as RandomNumberGenerator).seed = 7
	if def.has("init"):
		(def.init as Callable).call(b)
	return b

func _build_page() -> void:
	for c in holder.get_children():
		c.queue_free()
	cards.clear()
	var pd: Dictionary = pagedefs[page]
	var list: Array = pd.list
	for i in list.size():
		var def: Dictionary = list[i]
		var cell: Vector2 = ORIGIN + Vector2((i % COLS) * CELL.x, floorf(i / float(COLS)) * CELL.y)
		var clip := Control.new()
		clip.position = cell + Vector2(6, 0)
		clip.size = STAGE
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(clip)
		var p := Painter.new()
		p.def = def
		p.b = _fresh_state(def, false)
		clip.add_child(p)
		cards.append({ "def": def, "painter": p, "rect": Rect2(clip.position, STAGE) })

func _toggle_rhyme(card: Dictionary) -> void:
	var p: Painter = card.painter
	if not (card.def as Dictionary).has("rhyme"):
		return
	p.b = _fresh_state(card.def, not p.b.rhyme)

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	var pd: Dictionary = pagedefs[page]
	var fam: GDScript = FAMILIES[pd.fam]
	var total := 0
	for f in FAMILIES:
		total += f.defs().size()
	var part := (" (%d/%d)" % [pd.part + 1, pd.parts]) if pd.parts > 1 else ""
	draw_string(ThemeDB.fallback_font, Vector2(14, 24),
		"THE DEPTH ATLAS — %d pictures (+%d rhymes) — %s%s · page %d/%d" % [total, total, fam.TITLE, part, page + 1, pagedefs.size()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.66, 0.64, 0.77))
	draw_string(ThemeDB.fallback_font, Vector2(14, 42), fam.BLURB,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.52, 0.5, 0.62))
	draw_string(ThemeDB.fallback_font, Vector2(14, 530),
		"←/→ turn the page · click a card to move its light, camera or weather · RIGHT-CLICK for its rhyme · Esc = menu",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.52, 0.5, 0.62))
	for card in cards:
		var r: Rect2 = card.rect
		var def: Dictionary = card.def
		var p: Painter = card.painter
		var rh: bool = p.b.rhyme
		draw_rect(r, Color(0.35, 0.55, 0.42, 0.6) if rh else Color(0.35, 0.33, 0.47, 0.5), false, 1.0)
		var cname: String = "%s · %s" % [def.letter, def.name]
		var chint: String = def.hint
		var ccol := Color(0.72, 0.7, 0.82)
		if rh:
			var rd: Dictionary = def.rhyme
			cname = "%s · %s ⇄" % [def.letter, rd.name]
			chint = rd.hint
			ccol = Color(0.55, 0.85, 0.65)
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x - 6, r.position.y + r.size.y + 16),
			cname, HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 12, 12, ccol)
		draw_multiline_string(ThemeDB.fallback_font, Vector2(r.position.x - 6, r.position.y + r.size.y + 30),
			chint, HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 12, 9, 3, Color(0.5, 0.48, 0.6))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		for card in cards:
			var r: Rect2 = card.rect
			if r.has_point(event.position):
				if event.button_index == MOUSE_BUTTON_RIGHT:
					_toggle_rhyme(card)
				elif (card.def as Dictionary).has("press"):
					var p: Painter = card.painter
					((card.def as Dictionary).press as Callable).call(p.b, event.position - r.position)
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				RenderingServer.set_default_clear_color(ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color"))
				get_tree().change_scene_to_file("res://scenes/menu.tscn")
			KEY_RIGHT, KEY_PAGEDOWN:
				page = (page + 1) % pagedefs.size()
				_build_page()
			KEY_LEFT, KEY_PAGEUP:
				page = (page - 1 + pagedefs.size()) % pagedefs.size()
				_build_page()
