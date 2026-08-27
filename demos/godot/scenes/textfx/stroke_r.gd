extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
const Base := preload("res://scenes/textfx/stroke.gd")
## STROKES & OUTLINES — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"pen_stroke": { "name": "Eraser", "hint": "written in full, then erased letter by letter from the right — and rewritten" },
	"hollow_solid": { "name": "Drain", "hint": "the glass empties — filled letters drain from the top, leaving outlines" },
	"marching_ants": { "name": "Queen ant", "hint": "the column thins to a single bright runner orbiting each letter" },
	"underline_writer": { "name": "Brackets", "hint": "two lines draw from the outside in, and the letters appear between them" },
	"double_stroke": { "name": "Triple echo", "hint": "three outlines expanding outward in staggered phase, like rings from a bell" },
	"strike_fix": { "name": "Proud correction", "hint": "the line goes UNDER, and the phrase straightens up instead of slumping" },
	"chalk_dust": { "name": "Wet paint", "hint": "the dust becomes drips — paint runs down from the letters in slow threads" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"chalk_dust":
			# dial: clap-of-dust → a fresh coat — 8 drips, straight down
			var L := TextKit.layout(b)
			for i in 8:
				var l: Dictionary = L[randi() % L.size()]
				if l.ch != " ":
					b.parts.append({ "x": l.cx + randf_range(-l.w * 0.3, l.w * 0.3), "y": l.y + 2.0,
						"v": randf_range(4.0, 14.0), "len": 0.0, "life": 1.0 })
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"pen_stroke":
			# dial: cycle 7 → 8 s (writing, then unwriting, takes longer)
			b.age += dt
			if b.age > 8.0:
				b.age = 0.0
		"double_stroke":
			# dial: decay 1.0 → 0.8 (the bell rings longer)
			b.surge = maxf(0.0, b.surge - dt * 0.8)
		"chalk_dust":
			# dials: dust rise/drift → drip straight down · drips slow as they thin
			if randf() < 0.06:
				var L := TextKit.layout(b)
				var l: Dictionary = L[randi() % L.size()]
				if l.ch != " ":
					b.parts.append({ "x": l.cx + randf_range(-l.w * 0.3, l.w * 0.3), "y": l.y + 1.0,
						"v": randf_range(3.0, 9.0), "len": 0.0, "life": 1.0 })
			for d in b.parts:
				d.len += d.v * dt
				d.v *= pow(0.7, dt)            # drips slow as they thin
				d.life -= dt * 0.2
			var r: Rect2 = b.rect
			var bottom: float = r.end.y
			b.parts = b.parts.filter(func(d): return d.life > 0.0 and d.y + d.len < bottom)
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var s: float = b.base_size
	var ink := TextKit.INK
	match b.id:
		"pen_stroke":
			TextKit.stage(n, b)
			# dials: direction reversed (it consumes) · order right-to-left · the
			# fill goes first — the retreating dash is spelled as the outline fading OUT
			var L := TextKit.layout(b)
			for l in L:
				var ri: int = l.n - 1 - l.i    # erase from the right
				var p: float = clampf((b.age - 1.5 - ri * 0.22) / 1.2, 0.0, 1.0)   # p: how erased
				if p >= 1.0:
					continue
				if p <= 0.0:
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), s, Color(ink.r, ink.g, ink.b, 0.9))
				else:                          # partially erased: the outline retreats
					TextKit.letter_outline(n, l.ch, Vector2(l.x, l.y), s, 1,
						Color(ink.r, ink.g, ink.b, (0.9 - p * 0.6) * (1.0 - p)))
		"hollow_solid":
			TextKit.stage(n, b)
			# dials: fill direction reversed (full → empty) · the meniscus falls
			var L := TextKit.layout(b)
			for l in L:
				TextKit.letter_outline(n, l.ch, Vector2(l.x, l.y), s, 1, Color(ink.r, ink.g, ink.b, 0.8))
			var fill: float = 1.0 - clampf((b.age - 0.8) / 2.2, 0.0, 1.0)    # the only changed line
			if fill > 0.0:
				var level: float = b.mid + s * 0.14 - fill * s * 0.95
				for l in L:
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), s, Color(ink.r, ink.g, ink.b, fill))
				if fill < 1.0:
					var l0: Dictionary = L[0]
					var ln: Dictionary = L[L.size() - 1]
					n.draw_rect(Rect2(l0.x, level - 1.0, ln.x + ln.w - l0.x, 1.5), Color(0.71, 0.78, 1.0, 0.5))
		"marching_ants":
			TextKit.stage(n, b)
			# dials: dash 4/4 → ONE bright runner (here a gold mote orbiting each
			# glyph, since the shimmer was the dash) · speed 20 → 12 · soft fill restored
			var L := TextKit.layout(b)
			for l in L:
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), s, Color(ink.r, ink.g, ink.b, 0.25))
			for l in L:
				if l.ch == " ":
					continue
				var a: float = t * 12.0 * b.speed * 0.25 + float(l.i) * 1.3
				var pos := Vector2(l.cx + cos(a) * l.w * 0.6, l.y - s * 0.32 + sin(a) * s * 0.42)
				TextKit.glow(n, pos, 2.5, Color(1.0, 0.9, 0.59, 0.95), 2)
		"underline_writer":
			TextKit.stage(n, b)
			# dials: one line → two (over-line left-in, underline right-in) ·
			# letters reveal outside-in
			var L := TextKit.layout(b)
			var l0: Dictionary = L[0]
			var ln: Dictionary = L[L.size() - 1]
			var x0: float = l0.x
			var x1: float = ln.x + ln.w
			var p: float = minf(1.0, b.age / 1.2)
			var e: float = 1.0 - pow(1.0 - p, 3.0)
			var reach: float = (x1 - x0) / 2.0 * e
			var pen := Color(0.71, 0.78, 1.0, 0.9)
			if reach > 0.5:                    # over-line from the left, underline from the right
				n.draw_line(Vector2(x0, l0.y - s * 0.85), Vector2(x0 + reach * 2.0, l0.y - s * 0.85), pen, 2.0)
				n.draw_line(Vector2(x1, l0.y + 6.0), Vector2(x1 - reach * 2.0, l0.y + 6.0), pen, 2.0)
			for l in L:                        # outermost letters first
				var from_edge: float = minf(l.cx - x0, x1 - l.cx) / (x1 - x0) * 2.0
				var k: float = clampf((e - from_edge) * 3.0 + 0.2, 0.0, 1.0)
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), s, Color(ink.r, ink.g, ink.b, k))
		"double_stroke":
			TextKit.stage(n, b)
			# dials: strokes 2 → 3 · counter-phase breathing → outward travel ·
			# the press strikes the bell
			var L := TextKit.layout(b)
			var strike: float = b.surge
			for e in range(2, -1, -1):         # outermost first
				var ph: float = fmod(t * 0.8 + e / 3.0, 1.0)                 # each echo a third apart
				var w := int(round(1.0 + ph * (5.0 + strike * 6.0)))
				var a: float = (1.0 - ph) * (0.35 + strike * 0.3)
				for l in L:
					TextKit.letter_outline(n, l.ch, Vector2(l.x, l.y), s, maxi(1, w), Color(0.63, 0.75, 1.0, a))
			for l in L:
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), s, Color(ink.r, ink.g, ink.b, 0.95))
		"strike_fix":
			TextKit.stage(n, b)
			# dials: line strike → underline · letters LIFT (weight 600) instead of
			# slump · palette warm · the regret holds a beat longer (1..3, not 1..2)
			var L := TextKit.layout(b)
			var l0: Dictionary = L[0]
			var ln: Dictionary = L[L.size() - 1]
			var x0: float = l0.x - 3.0
			var x1: float = ln.x + ln.w + 3.0
			var line := 0.0
			var ph: float = b.phase
			if ph < 1.0:
				line = 1.0 - pow(1.0 - ph, 3.0)
			elif ph < 3.0:
				line = 1.0
			else:
				line = maxf(0.0, 1.0 - (ph - 3.0))
			for l in L:
				var blessed: bool = l.cx < x0 + (x1 - x0) * line
				if blessed:                    # it stands taller when approved
					TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y - 1.5), s, Color(0.96, 0.91, 0.78), 600.0)
				else:
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), s, ink)
			if line > 0.0:
				n.draw_line(Vector2(x0, l0.y + 6.0), Vector2(x0 + (x1 - x0) * line, l0.y + 6.0),
					Color(0.94, 0.82, 0.51, 0.9), 2.0)
		"chalk_dust":
			TextKit.stage(n, b)
			# dials: dust → drips · grain removed (wet paint is smooth) · palette mint
			var L := TextKit.layout(b)
			for l in L:
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), s, Color(0.62, 0.85, 0.78))
			for d in b.parts:
				if d.len > 0.5:
					n.draw_line(Vector2(d.x, d.y), Vector2(d.x, d.y + d.len), Color(0.62, 0.85, 0.78, 0.7), 2.0)
				n.draw_rect(Rect2(d.x - 1.2, d.y + d.len, 2.4, 2.4), Color(0.62, 0.85, 0.78, 0.8))   # the bead at the tip
		_:
			Base.draw(n, b, t)
