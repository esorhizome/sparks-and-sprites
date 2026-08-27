extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
## ARRIVALS — eight text effects, ported from the web grimoire.
##
## Canvas note: the JS speaks in canvas coords (0..W, 0..H); here everything
## is absolute inside b.rect — "just off the left edge" is spelled
## b.rect.position.x - BASE, "below the card" is b.rect.end.y + BASE.

const TITLE := "Arrivals"
const BLURB := "letters travelling to their places"
const DEFS := [
	{ "id": "roll_call", "name": "Roll call", "hint": "letters slide in from the left, one after another, and take their places" },
	{ "id": "rain_down", "name": "Rain down", "hint": "letters fall into place from above, staggered like weather" },
	{ "id": "rise_up", "name": "Rise up", "hint": "credits-style: the phrase rises from below and eases to a stop" },
	{ "id": "crossroads", "name": "Crossroads", "hint": "odd letters arrive from the left, even from the right, interleaving" },
	{ "id": "compass", "name": "Compass", "hint": "every letter flies in from its own compass point — press to redraw the winds" },
	{ "id": "tracking", "name": "Tracking", "hint": "cinematic titles: the letters begin far apart and drift together" },
	{ "id": "whoosh", "name": "Whoosh", "hint": "the phrase streaks in fast from the left, speed lines and all" },
	{ "id": "conveyor", "name": "Conveyor", "hint": "letters ride a belt across the card, pause to spell the phrase, then ride on" },
]

static func init(b: Dictionary) -> void:
	b.clock = 0.0                          # the JS keeps `clock` or `age` per effect — one clock serves all
	match b.id:
		"rain_down":
			b.stagger = []                 # per-letter delays, dealt in tick
		"compass":
			b.dirs = []                    # per-letter winds, dealt in tick
		"conveyor":
			b.shift = 0.0                  # the press nudge

static func press(b: Dictionary, _pos: Vector2) -> void:
	match b.id:
		"rain_down":
			b.clock = 0.0
			b.stagger = []
		"compass":
			b.clock = 0.0
			b.dirs = []
		"conveyor":
			b.shift = 0.4                  # nudge the belt
		_:
			b.clock = 0.0

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"roll_call":
			b.clock += dt
			if b.clock > TextKit.PHRASE.length() * 0.1 + 4.0:
				b.clock = 0.0
		"rain_down":
			b.clock += dt
			if b.stagger.is_empty():       # the weather is not a metronome
				for i in TextKit.PHRASE.length():
					b.stagger.append(randf_range(0.0, 0.9))
			if b.clock > 5.0:
				b.clock = 0.0
				b.stagger = []
		"rise_up":
			b.clock += dt
			if b.clock > 6.0:
				b.clock = 0.0
		"crossroads":
			b.clock += dt
			if b.clock > 5.5:
				b.clock = 0.0
		"compass":
			b.clock += dt
			if b.dirs.is_empty():          # each letter is assigned a wind
				for i in TextKit.PHRASE.length():
					b.dirs.append(randf_range(0.0, TAU))
			if b.clock > 5.5:
				b.clock = 0.0
				b.dirs = []
		"tracking":
			b.clock += dt
			if b.clock > 7.0:
				b.clock = 0.0
		"whoosh":
			b.clock += dt
			if b.clock > 4.5:
				b.clock = 0.0
		"conveyor":
			b.shift = maxf(0.0, b.shift - dt)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	TextKit.stage(n, b)
	var r: Rect2 = b.rect
	var base: float = b.base_size
	var ink := TextKit.INK
	match b.id:
		"roll_call":
			for l in TextKit.layout(b):
				var p: float = minf(1.0, maxf(0.0, (b.clock - l.i * 0.1) / 0.55))
				if p <= 0.0:
					continue
				var e := 1.0 - pow(1.0 - p, 3.0)
				var from_x := r.position.x - base            # from just off the left edge
				var x: float = from_x + (l.cx - from_x) * e
				TextKit.letter(n, l.ch, Vector2(x - l.w / 2.0, l.y), base, Color(ink, minf(1.0, p * 2.0)))
		"rain_down":
			if b.stagger.is_empty():
				return                     # the blank frame right after a reset
			for l in TextKit.layout(b):
				var p: float = minf(1.0, maxf(0.0, (b.clock - b.stagger[l.i]) / 0.6))
				if p <= 0.0:
					continue
				var e: float = p * p       # accelerating, like falling things do
				var from_y := r.position.y - r.size.y * 0.4
				var y: float = from_y + (l.y - from_y) * e
				TextKit.letter(n, l.ch, Vector2(l.x, y), base, Color(ink, minf(1.0, p * 3.0)))
		"rise_up":
			var p: float = minf(1.0, b.clock / 1.3)
			var e := 1.0 - pow(1.0 - p, 2.0)
			var dy := (1.0 - e) * r.size.y * 0.55
			var col := Color(ink, minf(1.0, p * 1.6))
			for l in TextKit.layout(b):
				TextKit.letter(n, l.ch, Vector2(l.x, l.y + dy), base, col)
		"crossroads":
			for l in TextKit.layout(b):
				var p: float = minf(1.0, maxf(0.0, (b.clock - l.i * 0.05) / 0.8))
				var e := 1.0 - pow(1.0 - p, 3.0)
				var from_x: float = (r.position.x - base) if l.i % 2 == 0 else (r.end.x + base)
				var x: float = from_x + (l.cx - from_x) * e
				TextKit.letter(n, l.ch, Vector2(x - l.w / 2.0, l.y), base, Color(ink, minf(1.0, p * 2.5)))
		"compass":
			if b.dirs.is_empty():
				return                     # the blank frame right after a reset
			for l in TextKit.layout(b):
				var p: float = minf(1.0, maxf(0.0, (b.clock - l.i * 0.04) / 0.9))
				var e := 1.0 - pow(1.0 - p, 3.0)
				var R := maxf(r.size.x, r.size.y) * 0.6
				var x: float = l.cx + cos(b.dirs[l.i]) * R * (1.0 - e)
				var y: float = l.y + sin(b.dirs[l.i]) * R * (1.0 - e)
				TextKit.letter(n, l.ch, Vector2(x - l.w / 2.0, y), base, Color(ink, minf(1.0, p * 2.0)))
		"tracking":
			var p: float = minf(1.0, b.clock / 2.4)
			var e := 1.0 - pow(1.0 - p, 2.0)
			var spacing := base * 0.55 * (1.0 - e)           # the whole effect is one number
			var sz := base * (0.92 + e * 0.08)
			var col := Color(ink, 0.25 + 0.75 * e)
			for l in TextKit.layout(b, sz, spacing):
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), sz, col, 300.0)   # canvas weight 300 → the kit's thin dial
		"whoosh":
			var p: float = minf(1.0, b.clock / 0.55)
			var e := 1.0 - pow(1.0 - p, 4.0)                 # very fast, very sudden stop
			var dx := (1.0 - e) * -r.size.x * 0.9
			var L := TextKit.layout(b)
			if p < 1.0:                                      # the streaks live only during the travel
				var streak := Color(0.706, 0.784, 1.0, (1.0 - p) * 0.5)
				for l in L:
					if l.ch == " " or l.i % 2 == 1:
						continue
					n.draw_line(Vector2(l.cx + dx - base * 2.2 * (1.0 - e), l.y - base * 0.3),
						Vector2(l.cx + dx, l.y - base * 0.3), streak, 2.0)
			var lean := (1.0 - e) * -0.35                    # it leans back against its own speed
			for l in L:
				# canvas transform(1, 0, lean, 1) is a true x-shear: Transform2D's y column tilted by lean
				n.draw_set_transform_matrix(Transform2D(Vector2(1.0, 0.0), Vector2(lean, 1.0), Vector2(l.cx + dx, l.y)))
				TextKit.letter_weight(n, l.ch, Vector2(-l.w / 2.0, 0.0), base, ink, 600.0)   # canvas weight 600
				n.draw_set_transform_matrix(Transform2D.IDENTITY)
		"conveyor":
			var tt := fmod(t * (2.5 if b.shift > 0.0 else 1.0), 7.0)   # PERIOD 7 — seconds per full crossing
			var ease_out := func(p: float) -> float: return 1.0 - pow(1.0 - p, 3.0)
			var ease_in := func(p: float) -> float: return p * p * p
			# piecewise: enter (0–2), dwell (2–5), leave (5–7)
			var dx: float
			if tt < 2.0:
				dx = (1.0 - ease_out.call(tt / 2.0)) * r.size.x * 0.75
			elif tt < 5.0:
				dx = 0.0
			else:
				dx = -ease_in.call((tt - 5.0) / 2.0) * r.size.x * 0.75
			var col := ink if tt >= 2.0 and tt < 5.0 else Color(ink, 0.75)
			for l in TextKit.layout(b):
				TextKit.letter(n, l.ch, Vector2(l.x + dx, l.y), base, col)
			var x: float = r.position.x + fmod(t * 40.0, 14.0) - 14.0   # the belt itself, rolling dots
			while x < r.end.x:
				n.draw_rect(Rect2(Vector2(x, b.mid + base * 0.45), Vector2(5, 2)), TextKit.DIM)
				x += 14.0
