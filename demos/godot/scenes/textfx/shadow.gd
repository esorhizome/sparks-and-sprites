extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
## DEPTH & SHADOW — seven text effects, ported from the web grimoire.

const TITLE := "Depth & shadow"
const BLURB := "long shadows, stacked extrusions, moving lights"
const DEFS := [
	{ "id": "long_shadow", "name": "Long shadow", "hint": "a sun crosses the sky; the letters' long shadows wheel and stretch with it" },
	{ "id": "stack_extrude", "name": "Stack extrude", "hint": "a 3D stack of copies gives the phrase thickness — press to slam it deep" },
	{ "id": "echo_trail", "name": "Echo trail", "hint": "the phrase drifts, and fading echoes of where it was follow behind" },
	{ "id": "spotlight", "name": "Spotlight", "hint": "darkness, and one wandering pool of light — press to call it to your cursor" },
	{ "id": "emboss", "name": "Emboss", "hint": "pressed into the paper — highlight above, shadow below; press to pop it out" },
	{ "id": "underglow", "name": "Underglow", "hint": "footlights: lit from below, shadows thrown up, with a stagey flicker" },
	{ "id": "split_shadow", "name": "Split shadow", "hint": "two coloured lights, two shadows — they circle the phrase in opposite directions" },
]

static func init(b: Dictionary) -> void:
	match b.id:
		"long_shadow":
			b.hurry = 0.0
		"stack_extrude":
			b.slam = 0.0
		"echo_trail":
			b.hist = []                    # a short memory of positions — the trail lesson, for text
			b.dx = 0.0
			b.dy = 0.0
		"spotlight":
			var r: Rect2 = b.rect          # canvas W·0.3 / W·0.7 → fractions of the card rect
			b.lx = r.position.x + r.size.x * 0.3
			b.ly = b.mid
			b.tx = r.position.x + r.size.x * 0.7
			b.ty = b.mid
			b.called = 0.0
		"emboss":
			b.out = 0.0
		"underglow":
			b.dim = 0.0
		"split_shadow":
			b.spin = 1.0

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"long_shadow":
			b.hurry = 2.0                  # time-lapse
		"stack_extrude":
			b.slam = 1.0
		"echo_trail":
			b.hist = []
		"spotlight":
			b.tx = pos.x                   # ABSOLUTE scene coords, straight in
			b.ty = pos.y
			b.called = 2.0
		"emboss":
			b.out = 2.5                    # raised, for a moment
		"underglow":
			b.dim = 1.4                    # someone leaned on the dimmer
		"split_shadow":
			b.spin = 3.5

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"long_shadow":
			b.hurry = maxf(0.0, b.hurry - dt)
		"stack_extrude":
			b.slam = maxf(0.0, b.slam - dt * 1.2)
		"echo_trail":
			b.dx = sin(t * 0.9) * b.base_size * 0.8        # the wander
			b.dy = sin(t * 1.7) * b.base_size * 0.22
			b.hist.append({ "dx": b.dx, "dy": b.dy })
			if b.hist.size() > 14:
				b.hist.pop_front()
		"spotlight":
			b.called = maxf(0.0, b.called - dt)
			if b.called <= 0.0:            # the light wanders on its own
				var r: Rect2 = b.rect
				b.tx = r.get_center().x + sin(t * 0.6) * r.size.x * 0.32
				b.ty = b.mid - b.base_size * 0.3 + sin(t * 1.1) * b.base_size * 0.5
			b.lx += (b.tx - b.lx) * minf(1.0, dt * 3.0)
			b.ly += (b.ty - b.ly) * minf(1.0, dt * 3.0)
		"emboss":
			b.out = maxf(0.0, b.out - dt)
		"underglow":
			b.dim = maxf(0.0, b.dim - dt)
		"split_shadow":
			b.spin = maxf(1.0, b.spin - dt * 1.4)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	TextKit.stage(n, b)
	var r: Rect2 = b.rect
	match b.id:
		"long_shadow":
			var day: float = t * (0.15 + b.hurry * 0.5)
			var sun_a := fmod(day, 1.0) * PI               # sunrise to sunset, left to right
			var sx: float = r.get_center().x - cos(sun_a) * r.size.x * 0.45
			var sy: float = b.mid - b.base_size * 2.2 - sin(sun_a) * b.base_size
			# canvas "lighter" → the glow's own layering, brighter
			TextKit.glow(n, Vector2(sx, sy), b.base_size * 0.9, Color(1, 0.86, 0.55, 0.5))
			var L: Array = TextKit.layout(b)
			var dir_x := cos(sun_a)        # shadows point away from the sun
			var length: float = b.base_size * (0.4 + absf(cos(sun_a)) * 1.4)   # longest at the day's edges
			var steps := 9
			for s in range(steps, 0, -1):  # the long shadow is a stack of offset copies
				var k := float(s) / steps
				var col := Color(0.03, 0.02, 0.06, 0.35 * (1.0 - k) + 0.08)
				for l in L:
					TextKit.letter(n, l.ch, Vector2(l.x + dir_x * length * k, l.y + length * k * 0.35),
						b.base_size, col)
			for l in L:                    # JS layout at weight 700 → the fake-bold dial
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), b.base_size, TextKit.INK, 700.0)
		"stack_extrude":
			var depth: float = 5.0 + sin(t * TAU / 4.0) * 2.0 + b.slam * 8.0   # the breathing thickness
			var L: Array = TextKit.layout(b)
			for d in range(int(round(depth)), 0, -1):
				var k := float(d) / depth
				var col := Color((40.0 + (1.0 - k) * 40.0) / 255.0,
					(35.0 + (1.0 - k) * 35.0) / 255.0, (70.0 + (1.0 - k) * 60.0) / 255.0)
				for l in L:
					TextKit.letter(n, l.ch, Vector2(l.x + d * 0.8, l.y + d * 0.8), b.base_size, col)
			for l in L:
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), b.base_size, TextKit.INK, 700.0)
		"echo_trail":
			var L: Array = TextKit.layout(b)
			var hist: Array = b.hist
			var h := 0
			while h < hist.size() - 1:     # every third memory, dimmer with age
				var k := float(h) / hist.size()
				var e: Dictionary = hist[h]
				for l in L:
					TextKit.letter(n, l.ch, Vector2(l.x + e.dx, l.y + e.dy), b.base_size,
						Color(0.59, 0.63, 1.0, k * 0.16))
				h += 3
			for l in L:
				TextKit.letter(n, l.ch, Vector2(l.x + b.dx, l.y + b.dy), b.base_size, TextKit.INK)
		"spotlight":
			var lx: float = b.lx
			var ly: float = b.ly
			var R: float = b.base_size * 1.9
			var L: Array = TextKit.layout(b)
			for l in L:                    # lit letters emerge; the rest stay night
				var d := Vector2(l.cx - lx, (l.y - b.base_size * 0.3) - ly).length()
				var k := maxf(0.0, 1.0 - d / R)
				if k <= 0.01:
					continue
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size,
					Color(1, 0.98, 0.9, minf(1.0, k * 1.6)))
			# canvas "lighter" → the glow's own layering, brighter
			TextKit.glow(n, Vector2(lx, ly), R, Color(1, 0.96, 0.82, 0.13))
		"emboss":
			var raised := 1.0 if b.out > 0.0 else -1.0     # engraved by default
			var d := 1.4
			# JS weight 700 → plain letters; a fake-bold outline would swallow the 1.4px relief
			var L: Array = TextKit.layout(b)
			for l in L:                    # the letters themselves: paper-dark
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, Color(0.08, 0.06, 0.13, 0.9))
			var light := Color(1, 1, 1, 0.18 + absf(sin(t * 0.7)) * 0.05)
			for l in L:                    # light edge
				TextKit.letter(n, l.ch, Vector2(l.x - d * raised, l.y - d * raised), b.base_size, light)
			for l in L:                    # dark edge
				TextKit.letter(n, l.ch, Vector2(l.x + d * raised, l.y + d * raised), b.base_size,
					Color(0, 0, 0, 0.55))
			for l in L:                    # re-fill the face over the edges
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, Color(0.17, 0.15, 0.26))
		"underglow":
			var lamp_y: float = b.mid + b.base_size * 0.5
			var flick := 0.85 + 0.15 * sin(t * 11.0) * sin(t * 6.3)
			var level: float = flick * (0.25 if b.dim > 0.0 else 1.0)
			for i in 4:                    # the row of footlights — canvas "lighter" → glow layering
				TextKit.glow(n, Vector2(r.position.x + r.size.x * (0.2 + i * 0.2), lamp_y),
					b.base_size * 0.8, Color(1, 0.82, 0.51, 0.18 * level))
			var L: Array = TextKit.layout(b)
			var shadow := Color(0.04, 0.03, 0.08, 0.5 * level)                 # shadow goes UP
			for l in L:
				TextKit.letter(n, l.ch, Vector2(l.x, l.y - b.base_size * 0.14), b.base_size, shadow)
			# the per-letter linear gradient (dark top → warm bottom) → a two-tone
			# approximation: a dark pass a hair high, the warm footlit tone over it
			var dark := Color(0.47, 0.35, 0.24, 0.35 + level * 0.2)
			var warm := Color(1, 0.88, 0.67, 0.5 + level * 0.5)
			for l in L:                    # brighter toward the bottom of each letter
				TextKit.letter(n, l.ch, Vector2(l.x, l.y - b.base_size * 0.06), b.base_size, dark)
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, warm)
		"split_shadow":
			var spin: float = b.spin
			var a1: float = t * 0.8 * spin
			var a2: float = -t * 0.6 * spin + 2.0
			var L: Array = TextKit.layout(b)
			var pink := Color(1, 0.31, 0.43, 0.4)          # shadow from the cyan light
			for l in L:
				TextKit.letter(n, l.ch, Vector2(l.x + cos(a1) * 4.0, l.y + sin(a1) * 3.0),
					b.base_size, pink)
			var cyan := Color(0.31, 0.78, 1.0, 0.4)        # shadow from the red light
			for l in L:
				TextKit.letter(n, l.ch, Vector2(l.x + cos(a2) * 4.0, l.y + sin(a2) * 3.0),
					b.base_size, cyan)
			for l in L:
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, TextKit.INK)
