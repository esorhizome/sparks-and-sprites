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
var dragging: Dictionary = {}    # the card under a held left button (drag = repeated press)
var big: Dictionary = {}         # the enlarged card, if one is open (double-click)
const BIG := Vector2(600, 409)   # the enlarged stage: STAGE × 2.73, fits under the header
const BIG_POS := Vector2(180, 56)


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
		if not b.pressed:                            # the affordance badge, gone after the first touch
			_badge(def.get("drag", false), b.t)
	## The "click / drag" pill at the card's top-right corner, pulsing.
	func _badge(drag: bool, t: float) -> void:
		var txt := "← drag →" if drag else "click ✦"
		var f := ThemeDB.fallback_font
		var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 12.0
		var a := 0.6 + 0.3 * sin(t * 3.0)
		var pos := Vector2(b.W - w - 6.0, 6.0)
		draw_rect(Rect2(pos, Vector2(w, 16.0)), Color(0.04, 0.03, 0.08, 0.7 * a))
		draw_string(f, pos + Vector2(6.0, 12.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.96, 0.76, 0.41, a))


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

func _fresh_state(def: Dictionary, rhyme: bool, size := STAGE) -> Dictionary:
	var D: Dictionary = (def.dials as Dictionary).duplicate(true)
	if rhyme and def.has("rhyme"):
		D.merge((def.rhyme as Dictionary).dials, true)   # the rhyme's dials win
	var b := { "W": size.x, "H": size.y, "t": 0.0, "D": D, "rhyme": rhyme, "pressed": false,
		"rng": RandomNumberGenerator.new() }
	(b.rng as RandomNumberGenerator).seed = 7
	if def.has("init"):
		(def.init as Callable).call(b)
	return b

func _build_page() -> void:
	_close_big()
	dragging = {}
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
	var was_pressed: bool = p.b.pressed
	p.b = _fresh_state(card.def, not p.b.rhyme, Vector2(p.b.W, p.b.H))
	p.b.pressed = was_pressed

## Double-click: the same picture, 2.7× larger, in the middle of the window.
## The painters draw relative to b.W × b.H, so enlarging is just a bigger b.
func _open_big(card: Dictionary) -> void:
	_close_big()
	var def: Dictionary = card.def
	var src: Painter = card.painter
	var clip := Control.new()
	clip.position = BIG_POS
	clip.size = BIG
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	var p := Painter.new()
	p.def = def
	p.b = _fresh_state(def, src.b.rhyme, BIG)
	p.b.pressed = true                               # no badge on the big one
	clip.add_child(p)
	big = { "def": def, "painter": p, "clip": clip, "rect": Rect2(BIG_POS, BIG) }
	holder.visible = false                           # the small cards hide behind the dim page

func _close_big() -> void:
	if big.is_empty():
		return
	(big.clip as Control).queue_free()
	big = {}
	holder.visible = true

func _press(def: Dictionary, p: Painter, local: Vector2) -> void:
	p.b.pressed = true
	if def.has("press"):
		(def.press as Callable).call(p.b, local)

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
	if big.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(14, 530),
			"←/→ turn the page · click or DRAG a card to move its light, camera or weather · RIGHT-CLICK for its rhyme · DOUBLE-CLICK to enlarge · Esc = menu",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.52, 0.5, 0.62))
	for card in (cards if big.is_empty() else []):   # captions hide with the cards while the big view is up
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
	if not big.is_empty():                           # the enlarged card, over a dimmed page
		draw_rect(Rect2(Vector2.ZERO, Vector2(960, 540)), Color(0.05, 0.04, 0.09, 0.82))
		var br: Rect2 = big.rect
		var bp: Painter = big.painter
		var bd: Dictionary = big.def
		draw_rect(br.grow(2.0), Color(0.55, 0.85, 0.65, 0.8) if bp.b.rhyme else Color(0.66, 0.64, 0.77, 0.8), false, 2.0)
		var bname: String = "%s · %s" % [bd.letter, (bd.rhyme.name if bp.b.rhyme else bd.name)]
		var bhint: String = bd.rhyme.hint if bp.b.rhyme else bd.hint
		draw_string(ThemeDB.fallback_font, Vector2(br.position.x, br.end.y + 22), bname,
			HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 14, Color(0.9, 0.88, 0.97))
		draw_multiline_string(ThemeDB.fallback_font, Vector2(br.position.x - 60, br.end.y + 40), bhint,
			HORIZONTAL_ALIGNMENT_CENTER, br.size.x + 120, 11, 2, Color(0.66, 0.64, 0.77))
		draw_string(ThemeDB.fallback_font, Vector2(14, 530),
			"click or drag inside to move its light, camera or weather · right-click for its rhyme · click outside or Esc to close",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.72, 0.7, 0.82))

func _card_at(pos: Vector2) -> Dictionary:
	for card in cards:
		if (card.rect as Rect2).has_point(pos):
			return card
	return {}

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if not event.pressed:
			dragging = {}
		elif not big.is_empty():                     # the enlarged card takes every click
			var br: Rect2 = big.rect
			if br.has_point(event.position):
				var bp: Painter = big.painter
				if event.button_index == MOUSE_BUTTON_RIGHT:
					bp.b = _fresh_state(big.def, not bp.b.rhyme, BIG)
					bp.b.pressed = true
				else:
					_press(big.def, bp, event.position - br.position)
					dragging = big
			else:
				_close_big()
		else:
			var card := _card_at(event.position)
			if not card.is_empty():
				if event.button_index == MOUSE_BUTTON_RIGHT:
					_toggle_rhyme(card)
				elif event.double_click:
					_open_big(card)
				else:
					_press(card.def, card.painter, event.position - (card.rect as Rect2).position)
					dragging = card
	if event is InputEventMouseMotion and not dragging.is_empty():
		var def: Dictionary = dragging.def         # drag = the press repeated, for cards that
		if def.get("drag", false):                 # declared their press continuous
			var r: Rect2 = dragging.rect
			if r.has_point(event.position):
				_press(def, dragging.painter, event.position - r.position)
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				if not big.is_empty():
					_close_big()
					return
				RenderingServer.set_default_clear_color(ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color"))
				get_tree().change_scene_to_file("res://scenes/menu.tscn")
			KEY_RIGHT, KEY_PAGEDOWN:
				page = (page + 1) % pagedefs.size()
				_build_page()
			KEY_LEFT, KEY_PAGEUP:
				page = (page - 1 + pagedefs.size()) % pagedefs.size()
				_build_page()
