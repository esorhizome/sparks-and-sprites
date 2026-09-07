extends Node2D
## THE STAGECRAFT ALMANAC — 104 scene & screen effects (+104 rhymes), A to Z
## four times, in GDScript. The full port of the web page
## (docs/stagecraft.html): one small scene — a sky, hills, a ground, a lamp,
## a crate, a tree and a code-drawn hero sprite — and 104 things that happen
## TO it: the screen bent after the fact, the sprite's skin, light and what
## it cannot reach, weapons and the marks they leave, water and weather,
## particle machinery, the HUD, and the sound half.
##
## Eight families, one page of eight cards at a time (←/→ turns pages).
## Click a card to fire, poke, aim or scrub it — DRAG the cards that say so.
## RIGHT-CLICK a card to see its RHYME. DOUBLE-CLICK to enlarge. 1 / 2 / 4
## set the tempo. Esc = menu. Two cards flash the whole frame (lightning,
## muzzle fire) and are OPT-IN: they show a notice until clicked.
##
## The effects live in scenes/stage/ — one file per family, each card an
## init/press/tick/draw quartet over a card dictionary; scenes/stage/kit.gd
## owns the scene, the hero, the props, the glow and a small synthesizer.
##
## THE ONE HONEST DIFFERENCE from the web page: what the browser does with a
## pixel loop over an ImageData, Godot does with a canvas_item SHADER. A
## card may name one ("shader": "res://shaders/stage/crt.gdshader"); the
## runner then lays a ColorRect with that ShaderMaterial over the card (the
## whole card, or the rect the card names in b.shader_rect), reading the
## screen through hint_screen_texture, and pushes the card's b.uniforms
## dictionary into it every frame. The arithmetic in each .gdshader is the
## same arithmetic as the web card's loop.
##
## A RHYME here is literally a dials swap: every card keeps its numbers in
## its def's "dials" dictionary (b.D at runtime); the rhyme is the same code
## with two or three of those values changed, and nothing else. Right-click
## merges the rhyme's dials over the original's and re-runs init(). That IS
## the lesson — understanding one recipe buys the whole neighbourhood.

const FAMILIES := [
	preload("res://scenes/stage/screen.gd"),
	preload("res://scenes/stage/skin.gd"),
	preload("res://scenes/stage/light.gd"),
	preload("res://scenes/stage/impact.gd"),
	preload("res://scenes/stage/weather.gd"),
	preload("res://scenes/stage/particles.gd"),
	preload("res://scenes/stage/hud.gd"),
	preload("res://scenes/stage/audio.gd"),
]
const Kit := preload("res://scenes/stage/kit.gd")

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
	var post: ColorRect = null                       # the card's shader pass, if it names one
	func _process(dt: float) -> void:
		if not b.armed:                              # an opt-in card waits, still, for a click
			queue_redraw()
			return
		for k in tempo:                              # tempo = extra substeps, not a bigger dt
			b.t += dt
			fam.tick(b, dt, b.t)
		_sync_post()
		queue_redraw()
	func _draw() -> void:
		if not b.armed:
			_warning(b.warn)
			return
		fam.draw(self, b, b.t)
		if not b.pressed:                            # the affordance badge, gone after the first touch
			_badge(b.drag, b.t)
	## The opt-in notice: static (nothing here may flash) and honest.
	func _warning(text: String) -> void:
		var f := ThemeDB.fallback_font
		draw_rect(Rect2(0, 0, b.w, b.h), Color("191527"))
		draw_rect(Rect2(6, 6, b.w - 12, b.h - 12), Color("F5C169"), false, 2.0)
		draw_string(f, Vector2(0, b.h * 0.42), "⚠ " + text, HORIZONTAL_ALIGNMENT_CENTER, b.w, 13, Color("F5C169"))
		draw_string(f, Vector2(0, b.h * 0.6), "this card does not start on its own", HORIZONTAL_ALIGNMENT_CENTER, b.w, 10, Color(0.91, 0.9, 0.96, 0.85))
		draw_string(f, Vector2(0, b.h * 0.72), "click to show it (you can look away first)", HORIZONTAL_ALIGNMENT_CENTER, b.w, 10, Color(0.91, 0.9, 0.96, 0.85))
	## The shader pass: a ColorRect over the card (or over b.shader_rect),
	## reading what the painter drew through hint_screen_texture. Built once
	## the card is armed; its uniforms follow b.uniforms every frame.
	func _sync_post() -> void:
		if not b.has("shader"):
			return
		if post == null or not is_instance_valid(post):
			var sh: Shader = load(b.shader)
			if sh == null:
				return
			post = ColorRect.new()
			post.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var mat := ShaderMaterial.new()
			mat.shader = sh
			post.material = mat
			get_parent().add_child(post)             # a sibling AFTER the painter: it draws on top
		var r: Rect2 = b.get("shader_rect", Rect2(Vector2.ZERO, Vector2(b.w, b.h)))
		post.position = r.position
		post.size = r.size
		post.visible = b.get("shader_on", true)
		var mat2 := post.material as ShaderMaterial
		var uni: Dictionary = b.get("uniforms", {})
		for key in uni:
			mat2.set_shader_parameter(key, uni[key])
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
		"pressed": false, "drag": def.get("drag", false),
		"armed": not def.has("warn"), "warn": def.get("warn", ""),
		"uniforms": {} }
	if def.has("shader"):
		b.shader = def.shader
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
	var was_armed: bool = p.b.armed
	p.b = fresh_state(card.fam, card.def, not p.b.rhyme, (p.b.rect as Rect2).size)
	p.b.pressed = was_pressed
	p.b.armed = was_armed

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
	p.b.armed = src.b.armed                          # but the opt-in notice stays until clicked
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
	if not p.b.armed:                                # the first click on an opt-in card only arms it
		p.b.armed = true
		return
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
		"THE STAGECRAFT ALMANAC — %d scene & screen effects (+%d rhymes) — %s%s · page %d/%d · tempo ×%d" %
		[total, total, fam.TITLE, part, page + 1, pagedefs.size(), tempo],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.66, 0.64, 0.77))
	draw_string(ThemeDB.fallback_font, Vector2(14, 42), fam.BLURB,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.52, 0.5, 0.62))
	if big.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(14, 530),
			"←/→ page · click a card to fire, poke or scrub it (DRAG the ones that say so) · RIGHT-CLICK = rhyme · DOUBLE-CLICK = enlarge · 1/2/4 tempo · Esc = menu",
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
					var armed: bool = bp.b.armed
					bp.b = fresh_state(big.fam, big.def, not bp.b.rhyme, BIG)
					bp.b.pressed = true
					bp.b.armed = armed
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
