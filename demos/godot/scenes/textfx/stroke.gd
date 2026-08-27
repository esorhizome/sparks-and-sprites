extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
## STROKES & OUTLINES — seven text effects, ported from the web grimoire.
## Godot has no strokeText and no line dashes, so every dash trick from the
## canvas version is re-spelled with TextKit.letter_outline and alpha —
## noted branch by branch where the translation happens.

const TITLE := "Strokes & outlines"
const BLURB := "hollow letters, and the pen still writing"
const DEFS := [
	{ "id": "pen_stroke", "name": "Pen stroke", "hint": "the letters write themselves on — a dash crawling along each glyph's path" },
	{ "id": "hollow_solid", "name": "Hollow to solid", "hint": "outlines first; then the ink rises inside them like a filling glass" },
	{ "id": "marching_ants", "name": "Marching ants", "hint": "a dashed outline crawls around every letter, single file, forever" },
	{ "id": "underline_writer", "name": "Underline writer", "hint": "the underline draws itself first; the letters fade in above it, riding its wake" },
	{ "id": "double_stroke", "name": "Double stroke", "hint": "an inner line and an outer line, breathing in opposite phase" },
	{ "id": "strike_fix", "name": "Strike & fix", "hint": "a line strikes the phrase out; thinks better of it; retracts" },
	{ "id": "chalk_dust", "name": "Chalk dust", "hint": "chalk letters with a rough, restless edge — dust drifts off them as they stand" },
]

static func init(b: Dictionary) -> void:
	b.age = 0.0
	b.speed = 1.0
	b.surge = 0.0
	b.phase = 0.0
	b.slam = 0.0
	b.parts = []

static func press(b: Dictionary, _pos: Vector2) -> void:
	match b.id:
		"marching_ants":
			b.speed = 4.0                     # the ants hurry when startled
		"double_stroke":
			b.surge = 1.0
		"strike_fix":
			b.phase = 0.0
		"chalk_dust":                         # clap the erasers
			b.slam = 1.0
			var L := TextKit.layout(b)
			for i in 20:
				var l: Dictionary = L[randi() % L.size()]
				b.parts.append({ "pos": Vector2(l.cx + randf_range(-6.0, 6.0), l.y - randf_range(0.0, b.base_size * 0.6)),
					"vel": Vector2(randf_range(-20.0, 20.0), randf_range(-10.0, 26.0)), "life": 1.0 })
		_:
			b.age = 0.0

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"pen_stroke", "hollow_solid":
			b.age += dt
			if b.age > 7.0:
				b.age = 0.0
		"underline_writer":
			b.age += dt
			if b.age > 6.5:
				b.age = 0.0
		"marching_ants":
			b.speed = maxf(1.0, b.speed - dt * 1.5)
		"double_stroke":
			b.surge = maxf(0.0, b.surge - dt)
		"strike_fix":
			b.phase += dt * 0.8
			if b.phase > 4.2:
				b.phase = 0.0
		"chalk_dust":
			b.slam = maxf(0.0, b.slam - dt)
			if randf() < 0.25:                # ambient dust
				var L := TextKit.layout(b)
				var l: Dictionary = L[randi() % L.size()]
				b.parts.append({ "pos": Vector2(l.cx + randf_range(-4.0, 4.0), l.y + randf_range(-b.base_size * 0.4, 2.0)),
					"vel": Vector2(randf_range(-4.0, 4.0), randf_range(4.0, 14.0)), "life": 0.8 })
			for m in b.parts:
				m.pos += m.vel * dt
				m.vel.y += 8.0 * dt
				m.life -= dt * 0.9
			b.parts = b.parts.filter(func(m): return m.life > 0.0)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	TextKit.stage(n, b)
	var s: float = b.base_size
	var ink := TextKit.INK
	var L := TextKit.layout(b)
	match b.id:
		"pen_stroke":
			# no dash-along-glyph in Godot: the crawl becomes the OUTLINE fading
			# in per letter — same 0.22 s stagger, same 1.4 s write — and finished
			# letters get their fill, as on the web.
			for l in L:
				var p: float = clampf((b.age - l.i * 0.22) / 1.4, 0.0, 1.0)
				if p <= 0.0:
					continue
				TextKit.letter_outline(n, l.ch, Vector2(l.x, l.y), s, 1, Color(ink.r, ink.g, ink.b, p))
				if p >= 1.0:                   # finished letters get their fill
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), s, Color(ink.r, ink.g, ink.b, 0.9))
		"hollow_solid":
			# canvas clip-below-the-line → a fill whose alpha follows the level,
			# with the meniscus line drawn where the ink stands (the rise reads
			# in alpha here, not in geometry).
			for l in L:
				TextKit.letter_outline(n, l.ch, Vector2(l.x, l.y), s, 1, Color(ink.r, ink.g, ink.b, 0.8))
			var fill: float = clampf((b.age - 0.8) / 2.2, 0.0, 1.0)          # the rising level
			if fill > 0.0:
				var level: float = b.mid + s * 0.14 - fill * s * 0.95
				for l in L:
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), s, Color(ink.r, ink.g, ink.b, fill))
				if fill < 1.0:                 # the meniscus
					var l0: Dictionary = L[0]
					var ln: Dictionary = L[L.size() - 1]
					n.draw_rect(Rect2(l0.x, level - 1.0, ln.x + ln.w - l0.x, 1.5), Color(0.71, 0.78, 1.0, 0.5))
		"marching_ants":
			# the crawling dash → an alpha shimmer running letter to letter,
			# keyed to (t * speed + letter index); the whisper of fill stays.
			for l in L:
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), s, Color(ink.r, ink.g, ink.b, 0.14))
			for l in L:
				var a: float = 0.9 * (0.35 + 0.65 * (0.5 + 0.5 * sin(t * 20.0 * b.speed + float(l.i) * 2.1)))
				TextKit.letter_outline(n, l.ch, Vector2(l.x, l.y), s, 1, Color(ink.r, ink.g, ink.b, a))
		"underline_writer":
			var l0: Dictionary = L[0]
			var ln: Dictionary = L[L.size() - 1]
			var x0: float = l0.x
			var x1: float = ln.x + ln.w
			var p: float = minf(1.0, b.age / 1.2)
			var e: float = 1.0 - pow(1.0 - p, 3.0)
			var tip: float = x0 + (x1 - x0) * e
			if tip > x0 + 0.5:                 # the pen line
				n.draw_line(Vector2(x0, l0.y + 6.0), Vector2(tip, l0.y + 6.0), Color(0.71, 0.78, 1.0, 0.9), 2.0)
			for l in L:                        # letters appear where the pen has already passed
				var k: float = clampf((tip - l.cx) / (s * 1.5) + 0.5, 0.0, 1.0)
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), s, Color(ink.r, ink.g, ink.b, k))
		"double_stroke":
			var k: float = 0.5 + 0.5 * sin(t * TAU / 3.0)
			var outer_w := int(round(3.5 + (1.0 - k) * 2.5 + b.surge * 3.0))
			for l in L:                        # outer breathes out
				TextKit.letter_outline(n, l.ch, Vector2(l.x, l.y), s, outer_w,
					Color(0.47, 0.59, 1.0, 0.35 + (1.0 - k) * 0.4 + b.surge * 0.25))
			for l in L:                        # inner breathes in
				TextKit.letter_outline(n, l.ch, Vector2(l.x, l.y), s, 1, Color(ink.r, ink.g, ink.b, 0.5 + k * 0.5))
		"strike_fix":
			var l0: Dictionary = L[0]
			var ln: Dictionary = L[L.size() - 1]
			var x0: float = l0.x - 3.0
			var x1: float = ln.x + ln.w + 3.0
			var strike := 0.0                  # 0..1 strike, 1..2 regret, 2..3 retract, then rest
			var ph: float = b.phase
			if ph < 1.0:
				strike = 1.0 - pow(1.0 - ph, 3.0)
			elif ph < 2.0:
				strike = 1.0
			elif ph < 3.0:
				strike = 1.0 - (ph - 2.0)
			for l in L:                        # struck letters slump a little
				var covered: bool = l.cx < x0 + (x1 - x0) * strike
				TextKit.letter(n, l.ch, Vector2(l.x, l.y + (1.5 if covered else 0.0)), s,
					Color(ink.r, ink.g, ink.b, 0.45) if covered else ink)
			if strike > 0.0:
				n.draw_line(Vector2(x0, l0.y - s * 0.26),
					Vector2(x0 + (x1 - x0) * strike, l0.y - s * 0.26 + sin(strike * 9.0) * 1.5),
					Color(0.9, 0.59, 0.59, 0.9), 2.0)
		"chalk_dust":
			# the quantized dash offset (chalk doesn't glide) → a quantized outline
			# alpha flicker: the grain re-rolls at floor(t*8), stepped, never smooth.
			var q: float = floorf(t * 8.0)
			for l in L:
				var a: float = 0.85 * (0.7 + 0.3 * sin(q * 1.7 + float(l.i) * 2.3))
				TextKit.letter_outline(n, l.ch, Vector2(l.x, l.y), s, 1, Color(0.94, 0.93, 0.91, a))
			for m in b.parts:
				n.draw_rect(Rect2(m.pos.x, m.pos.y, 1.5, 1.5), Color(0.94, 0.93, 0.91, 0.5))
