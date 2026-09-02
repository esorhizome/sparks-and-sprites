extends Node2D
## THE LOCOMOTION LEXICON — 104 movement styles (+104 rhymes), A to Z four
## times, in GDScript. The full port of the web page (docs/locomotion.html):
## the maths of procedural animation, one card per letter — sines and polar
## coordinates, springs and damping ratios, headings and vehicles, steering
## brains, crowds and fields, paths and schedules, joint chains, verlet
## bodies, and the clock and the camera themselves. Laps one and two teach
## machinery; laps three and four are GENRE laps (sci-fi, adventure, action,
## fantasy, arcade, cozy, minimalist, glitchy, goofy).
##
## Nine families, one page of eight cards at a time (←/→ turns pages). Click
## a card to poke it — most cards aim at where you click; DRAG the cards that
## say so. RIGHT-CLICK a card to see its RHYME. DOUBLE-CLICK to enlarge.
## 1 / 2 / 4 set the tempo (a time-lapse for skimming — extra substeps, so
## the springs stay stable). Esc = menu.
##
## The styles live in scenes/motion/ — one file per family, each style an
## init/press/tick/draw quartet over a card dictionary. scenes/motion/kit.gd
## owns the stage, the ground, the arrows, and the mote protagonist.
##
## A RHYME here is literally a dials swap: every card keeps its numbers in
## its def's "dials" dictionary (b.D at runtime); the rhyme is the same code
## with two or three of those values changed, and nothing else. Right-click
## merges the rhyme's dials over the original's and re-runs init(). That IS
## the lesson — understanding one recipe buys the whole neighbourhood.

const FAMILIES := [
	preload("res://scenes/motion/clocks.gd"),
	preload("res://scenes/motion/springs.gd"),
	preload("res://scenes/motion/headings.gd"),
	preload("res://scenes/motion/steer.gd"),
	preload("res://scenes/motion/crowds.gd"),
	preload("res://scenes/motion/paths.gd"),
	preload("res://scenes/motion/chains.gd"),
	preload("res://scenes/motion/bodies.gd"),
	preload("res://scenes/motion/time.gd"),
]
const Kit := preload("res://scenes/motion/kit.gd")

const COLS := 4
const CELL := Vector2(232, 232)
const STAGE := Vector2(220, 150)
const ORIGIN := Vector2(14, 64)
const PAGE_CAP := 8              # 4 × 2 cards is what a 960×540 window holds
const BIG := Vector2(600, 409)   # the enlarged stage: STAGE × 2.73, fits under the header
const BIG_POS := Vector2(180, 56)

var pagedefs: Array = []         # families split into window-sized parts
var page := 0
var cards: Array = []            # per-card runtime state for the current page
var holder: Node2D
var dragging: Dictionary = {}    # the card under a held left button (drag = repeated press)
var big: Dictionary = {}         # the enlarged card, if one is open (double-click)
var tempo := 1                   # substeps per frame: 1, 2 or 4


## One card = a clipping Control (so motion can't spill into its neighbours)
## holding a Node2D painter that draws in card-local space. The painter
## owns the card dictionary b; the family script owns the maths.
class Painter extends Node2D:
	var fam: GDScript
	var b: Dictionary
	var tempo := 1
	func _process(dt: float) -> void:
		for k in tempo:                              # tempo = extra substeps, not a bigger dt
			b.t += dt
			fam.tick(b, dt, b.t)
		queue_redraw()
	func _draw() -> void:
		fam.draw(self, b, b.t)
		if not b.pressed:                            # the affordance badge, gone after the first touch
			_badge(b.drag, b.t)
	## The "click / drag" pill at the card's top-right corner, pulsing.
	func _badge(drag: bool, t: float) -> void:
		var txt := "← drag →" if drag else "click ✦"
		var f := ThemeDB.fallback_font
		var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 12.0
		var a := 0.6 + 0.3 * sin(t * 3.0)
		var pos := Vector2(b.w - w - 6.0, 6.0)
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
		var list: Array = FAMILIES[fi].DEFS
		var parts := int(ceil(list.size() / float(PAGE_CAP)))
		for pi in parts:
			pagedefs.append({ "fam": fi, "part": pi, "parts": parts,
				"list": list.slice(pi * PAGE_CAP, mini(list.size(), (pi + 1) * PAGE_CAP)) })

## A fresh card dictionary: the def's dials (plus the rhyme's, merged over
## them, when rhyme is true), the stage geometry, and the family's init().
static func fresh_state(fam: GDScript, def: Dictionary, rhyme: bool, size := STAGE) -> Dictionary:
	var D: Dictionary = (def.dials as Dictionary).duplicate(true)
	if rhyme and def.has("rhyme"):
		D.merge((def.rhyme as Dictionary).dials, true)   # the rhyme's dials win
	var b := { "id": def.id, "letter": def.letter, "name": def.name, "hint": def.hint,
		"rect": Rect2(Vector2.ZERO, size), "D": D, "rhyme": rhyme, "t": 0.0,
		"pressed": false, "drag": def.get("drag", false) }
	Kit.setup(b)
	fam.init(b)
	return b

func _build_page() -> void:
	_close_big()
	dragging = {}
	for c in holder.get_children():
		c.queue_free()
	cards.clear()
	var pd: Dictionary = pagedefs[page]
	var fam: GDScript = FAMILIES[pd.fam]
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
		p.fam = fam
		p.tempo = tempo
		p.b = fresh_state(fam, def, false)
		clip.add_child(p)
		cards.append({ "def": def, "fam": fam, "painter": p, "rect": Rect2(clip.position, STAGE) })

func _toggle_rhyme(card: Dictionary) -> void:
	var p: Painter = card.painter
	if not (card.def as Dictionary).has("rhyme"):
		return
	var was_pressed: bool = p.b.pressed
	p.b = fresh_state(card.fam, card.def, not p.b.rhyme, (p.b.rect as Rect2).size)
	p.b.pressed = was_pressed

## Double-click: the same motion, 2.7× larger, in the middle of the window.
## Every style is written relative to b.w × b.h, so enlarging is a bigger b.
func _open_big(card: Dictionary) -> void:
	_close_big()
	var src: Painter = card.painter
	var clip := Control.new()
	clip.position = BIG_POS
	clip.size = BIG
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	var p := Painter.new()
	p.fam = card.fam
	p.tempo = tempo
	p.b = fresh_state(card.fam, card.def, src.b.rhyme, BIG)
	p.b.pressed = true                               # no badge on the big one
	clip.add_child(p)
	big = { "def": card.def, "fam": card.fam, "painter": p, "clip": clip, "rect": Rect2(BIG_POS, BIG) }
	holder.visible = false                           # the small cards hide behind the dim page

func _close_big() -> void:
	if big.is_empty():
		return
	(big.clip as Control).queue_free()
	big = {}
	holder.visible = true

func _press(card: Dictionary, local: Vector2) -> void:
	var p: Painter = card.painter
	p.b.pressed = true
	(card.fam as GDScript).press(p.b, local)

func _set_tempo(k: int) -> void:
	tempo = k
	for card in cards:
		(card.painter as Painter).tempo = k
	if not big.is_empty():
		(big.painter as Painter).tempo = k

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	var pd: Dictionary = pagedefs[page]
	var fam: GDScript = FAMILIES[pd.fam]
	var total := 0
	for f in FAMILIES:
		total += f.DEFS.size()
	var part := (" (%d/%d)" % [pd.part + 1, pd.parts]) if pd.parts > 1 else ""
	draw_string(ThemeDB.fallback_font, Vector2(14, 24),
		"THE LOCOMOTION LEXICON — %d movement styles (+%d rhymes) — %s%s · page %d/%d · tempo ×%d" %
		[total, total, fam.TITLE, part, page + 1, pagedefs.size(), tempo],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.66, 0.64, 0.77))
	draw_string(ThemeDB.fallback_font, Vector2(14, 42), fam.BLURB,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.52, 0.5, 0.62))
	if big.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(14, 530),
			"←/→ page · click a card to poke it (DRAG the ones that say so) · RIGHT-CLICK = rhyme · DOUBLE-CLICK = enlarge · 1/2/4 tempo · Esc = menu",
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
			"click or drag inside to poke it · right-click for its rhyme · click outside or Esc to close",
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
					bp.b = fresh_state(big.fam, big.def, not bp.b.rhyme, BIG)
					bp.b.pressed = true
				else:
					_press(big, event.position - br.position)
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
					_press(card, event.position - (card.rect as Rect2).position)
					dragging = card
	if event is InputEventMouseMotion and not dragging.is_empty():
		var def: Dictionary = dragging.def         # drag = the press repeated, for cards that
		if def.get("drag", false):                 # declared their press continuous
			var r: Rect2 = dragging.rect
			if r.has_point(event.position):
				_press(dragging, event.position - r.position)
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
			KEY_1:
				_set_tempo(1)
			KEY_2:
				_set_tempo(2)
			KEY_4:
				_set_tempo(4)
