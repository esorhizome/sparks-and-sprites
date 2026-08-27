extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
const Base := preload("res://scenes/textfx/shadow.gd")
## DEPTH & SHADOW — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"long_shadow": { "name": "Moon shadow", "hint": "the same sky at night — a cool moon, a slower arc, and longer shadows" },
	"stack_extrude": { "name": "Staircase", "hint": "the smooth extrusion quantized — chunky steps down and to the right, twice as deep" },
	"echo_trail": { "name": "Premonition", "hint": "the memory runs the wrong way — the ghosts arrive BEFORE the phrase does" },
	"spotlight": { "name": "Searchlights", "hint": "two beams instead of one — a letter needs BOTH to be truly seen" },
	"emboss": { "name": "Deep engrave", "hint": "cut twice as deep, the face darker — and the press planes it flush instead of raising it" },
	"underglow": { "name": "Chandelier", "hint": "the light moved overhead and set swinging — the shadows swing the other way" },
	"split_shadow": { "name": "Eclipse", "hint": "the two shadows drawn together — they align behind the phrase, darken, and part" },
}

static func init(b: Dictionary) -> void:
	match b.id:
		"spotlight":
			# dial: one light with a home → two starting cold at canvas 0 (the rect's left edge)
			var r: Rect2 = b.rect
			b.cx1 = r.position.x
			b.cx2 = r.position.x
			b.tx = r.position.x
			b.called = 0.0
		"underglow":
			# dial: dimmer timer → swing energy
			b.push = 0.0
		"split_shadow":
			# dial: spin (floored at 1) → hurry (dies away entirely)
			b.hurry = 0.0
		_:
			Base.init(b)

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"echo_trail":
			pass                           # dial: the future can't be cleared
		"spotlight":
			b.tx = pos.x                   # dial: press summons BOTH beams (only x matters now)
			b.called = 2.0
		"underglow":
			b.push = 1.0                   # set it swinging harder
		"split_shadow":
			b.hurry = 2.0
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"echo_trail":
			pass                           # dial: no memory kept — the ghosts are computed, not remembered
		"spotlight":
			# dial: lights 1 → 2, crossing paths
			var r: Rect2 = b.rect
			b.called = maxf(0.0, b.called - dt)
			var a1: float = b.tx if b.called > 0.0 else r.get_center().x + sin(t * 0.7) * r.size.x * 0.34
			var a2: float = b.tx if b.called > 0.0 else r.get_center().x + sin(t * 0.47 + 2.1) * r.size.x * 0.34
			b.cx1 += (a1 - b.cx1) * minf(1.0, dt * 3.0)
			b.cx2 += (a2 - b.cx2) * minf(1.0, dt * 3.0)
		"underglow":
			# dial: the push fades slowly — a pendulum, not a dimmer
			b.push = maxf(0.0, b.push - dt * 0.3)
		"split_shadow":
			# dial: decay 1.4 with a floor of 1 → plain decay to rest
			b.hurry = maxf(0.0, b.hurry - dt)
		_:
			Base.tick(b, dt, t)

## The Premonition's crystal ball: the drift is predictable, so it can be asked
## about any moment — including ones that haven't happened yet.
static func _drift_at(b: Dictionary, tt: float) -> Vector2:
	return Vector2(sin(tt * 0.9) * b.base_size * 0.8, sin(tt * 1.7) * b.base_size * 0.22)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	match b.id:
		"long_shadow":
			TextKit.stage(n, b)
			# dials: palette sun → moon · arc speed ×0.4 · shadow length ×1.5
			var r: Rect2 = b.rect
			var night: float = t * (0.06 + b.hurry * 0.2)
			var moon_a := fmod(night, 1.0) * PI
			var mx: float = r.get_center().x - cos(moon_a) * r.size.x * 0.45
			var my: float = b.mid - b.base_size * 2.2 - sin(moon_a) * b.base_size
			TextKit.glow(n, Vector2(mx, my), b.base_size * 0.7, Color(0.78, 0.84, 1.0, 0.45))
			var L: Array = TextKit.layout(b)
			var dir_x := cos(moon_a)
			var length: float = b.base_size * (0.6 + absf(cos(moon_a)) * 2.1)
			var steps := 9
			for s in range(steps, 0, -1):
				var k := float(s) / steps
				var col := Color(0.02, 0.02, 0.08, 0.4 * (1.0 - k) + 0.1)
				for l in L:
					TextKit.letter(n, l.ch, Vector2(l.x + dir_x * length * k, l.y + length * k * 0.35),
						b.base_size, col)
			for l in L:                    # moonlit ink
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), b.base_size, Color(0.79, 0.83, 0.95), 700.0)
		"stack_extrude":
			TextKit.stage(n, b)
			# dials: offset per copy 0.8px → 3px hard steps · depth ×2 · the breath removed (stairs hold still)
			var depth := int(round(8.0 + b.slam * 6.0))
			var L: Array = TextKit.layout(b)
			for d in range(depth, 0, -1):
				var k := float(d) / depth
				var v := 30.0 + (1.0 - k) * 50.0
				var col := Color(v / 255.0, v * 0.9 / 255.0, v * 1.5 / 255.0)
				for l in L:
					TextKit.letter(n, l.ch, Vector2(l.x + d * 3.0, l.y + d * 3.0), b.base_size, col)
			for l in L:
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), b.base_size, TextKit.INK, 700.0)
		"echo_trail":
			TextKit.stage(n, b)
			# dials: history → future (the ghosts lead) · tint warmed
			var L: Array = TextKit.layout(b)
			for f in range(4, 0, -1):      # where it WILL be, faint and expectant
				var d := _drift_at(b, t + f * 0.12)
				var col := Color(1, 0.78, 0.59, 0.16 - f * 0.03)
				for l in L:
					TextKit.letter(n, l.ch, Vector2(l.x + d.x, l.y + d.y), b.base_size, col)
			var now := _drift_at(b, t)
			for l in L:
				TextKit.letter(n, l.ch, Vector2(l.x + now.x, l.y + now.y), b.base_size, TextKit.INK)
		"spotlight":
			TextKit.stage(n, b)
			# dials: full brightness needs the OVERLAP · glows tinted cool and warm
			var cx1: float = b.cx1
			var cx2: float = b.cx2
			var R: float = b.base_size * 2.1
			var cy: float = b.mid - b.base_size * 0.3
			var L: Array = TextKit.layout(b)
			for l in L:
				var k1 := maxf(0.0, 1.0 - absf(float(l.cx) - cx1) / R)
				var k2 := maxf(0.0, 1.0 - absf(float(l.cx) - cx2) / R)
				var k := maxf(k1, k2) * 0.35 + minf(k1, k2) * 0.65   # the overlap is what counts
				if k <= 0.01:
					continue
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size,
					Color(1, 0.98, 0.9, minf(1.0, k * 1.8)))
			TextKit.glow(n, Vector2(cx1, cy), R, Color(0.78, 0.9, 1.0, 0.10))
			TextKit.glow(n, Vector2(cx2, cy), R, Color(1, 0.92, 0.78, 0.10))
		"emboss":
			TextKit.stage(n, b)
			# dials: depth ×2 · face darkened · press → flat (b.out now means "planed flush")
			var d := 0.0 if b.out > 0.0 else 2.8
			var L: Array = TextKit.layout(b)
			for l in L:
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, Color(0.05, 0.04, 0.1, 0.95))
			if d > 0.0:
				for l in L:                # light edge
					TextKit.letter(n, l.ch, Vector2(l.x + d, l.y + d), b.base_size, Color(1, 1, 1, 0.16))
				for l in L:                # dark edge
					TextKit.letter(n, l.ch, Vector2(l.x - d, l.y - d), b.base_size, Color(0, 0, 0, 0.7))
				for l in L:
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, Color(0.12, 0.1, 0.2))
			else:
				for l in L:                # planed flush: just barely there
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, Color(0.31, 0.29, 0.43))
		"underglow":
			TextKit.stage(n, b)
			# dials: light below → above, on a swinging chain · shadows swing the other way
			var r: Rect2 = b.rect
			var push: float = b.push
			var swing := sin(t * 1.7) * (0.3 + push * 0.7)
			var lx: float = r.get_center().x + swing * r.size.x * 0.25
			var ly: float = b.mid - b.base_size * 2.4
			n.draw_line(Vector2(r.get_center().x, r.position.y), Vector2(lx, ly),
				Color(0.59, 0.57, 0.75, 0.4), 1.0)         # the chain
			TextKit.glow(n, Vector2(lx, ly), b.base_size * 1.1, Color(1, 0.88, 0.63, 0.5))
			var L: Array = TextKit.layout(b)
			var shadow_dx: float = -swing * b.base_size * 0.5        # shadows lean away from the lamp
			for l in L:
				TextKit.letter(n, l.ch, Vector2(l.x + shadow_dx, l.y + b.base_size * 0.12),
					b.base_size, Color(0.04, 0.03, 0.08, 0.5))
			for l in L:
				var k := maxf(0.0, 1.0 - absf(float(l.cx) - lx) / (r.size.x * 0.5))
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, Color(1, 0.94, 0.82, 0.4 + k * 0.6))
		"split_shadow":
			TextKit.stage(n, b)
			# dials: independent orbits → one coupled orbit that periodically aligns · a darkening at totality
			var hurry: float = b.hurry
			var ph: float = t * (0.5 + hurry * 0.8)
			var sep := absf(sin(ph))       # 0 at totality
			var a := ph * 1.3
			var totality := 1.0 - sep
			var L: Array = TextKit.layout(b)
			var pink := Color(1, 0.31, 0.43, 0.35 + totality * 0.2)
			for l in L:
				TextKit.letter(n, l.ch, Vector2(l.x + cos(a) * 5.0 * sep, l.y + sin(a) * 4.0 * sep),
					b.base_size, pink)
			var cyan := Color(0.31, 0.78, 1.0, 0.35 + totality * 0.2)
			for l in L:
				TextKit.letter(n, l.ch, Vector2(l.x - cos(a) * 5.0 * sep, l.y - sin(a) * 4.0 * sep),
					b.base_size, cyan)
			var ink := roundf(232.0 - totality * 120.0)    # the phrase dims at totality
			var col := Color(ink / 255.0, ink * 0.98 / 255.0, ink * 1.05 / 255.0)
			for l in L:
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, col)
		_:
			Base.draw(n, b, t)
