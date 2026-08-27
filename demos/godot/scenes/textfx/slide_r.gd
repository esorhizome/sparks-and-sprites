extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
const Base := preload("res://scenes/textfx/slide.gd")
## ARRIVALS — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"roll_call": { "name": "Roll away", "hint": "the arrival plus its departure — it assembles, holds, then slides off stage right" },
	"rain_down": { "name": "Snowfall", "hint": "the same weather, slower and softer — flakes sway as they settle in" },
	"rise_up": { "name": "From the deep", "hint": "the same rise from much further down — slow, and blue until it surfaces" },
	"crossroads": { "name": "Zipper", "hint": "the same interleave rotated ninety degrees — odd from above, even from below" },
	"compass": { "name": "Vortex", "hint": "the winds tamed into one spiral — every letter takes the same corkscrew in" },
	"tracking": { "name": "Compression", "hint": "the spacing dial pushed the other way — letters start overlapped and spread apart" },
	"whoosh": { "name": "Drift in", "hint": "the same journey with the engine off — from the right, slow, no streaks" },
	"conveyor": { "name": "Return belt", "hint": "the belt reversed and impatient — right to left, with half the dwell" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)

static func press(b: Dictionary, pos: Vector2) -> void:
	Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"roll_call":
			# dial: an exit phase added after the dwell — the loop runs longer
			b.clock += dt
			var exit_at := TextKit.PHRASE.length() * 0.1 + 0.55 + 2.0
			if b.clock > exit_at + 1.4:
				b.clock = 0.0
		"rain_down":
			# dials: stagger doubled (0.9 → 1.8) · the storm runs 8s, not 5
			b.clock += dt
			if b.stagger.is_empty():
				for i in TextKit.PHRASE.length():
					b.stagger.append(randf_range(0.0, 1.8))
			if b.clock > 8.0:
				b.clock = 0.0
				b.stagger = []
		"rise_up":
			# dial: duration ×2 — reset at 8s, not 6
			b.clock += dt
			if b.clock > 8.0:
				b.clock = 0.0
		"whoosh":
			# dial: the glide is long — reset at 7s, not 4.5
			b.clock += dt
			if b.clock > 7.0:
				b.clock = 0.0
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var base: float = b.base_size
	var ink := TextKit.INK
	match b.id:
		"roll_call":
			TextKit.stage(n, b)
			# dials moved: an exit phase added after the dwell · exit accelerates instead of easing
			var exit_at := TextKit.PHRASE.length() * 0.1 + 0.55 + 2.0
			for l in TextKit.layout(b):
				var x: float = l.cx
				var alpha := 1.0
				if b.clock < exit_at:      # the borrowed arrival
					var p: float = minf(1.0, maxf(0.0, (b.clock - l.i * 0.1) / 0.55))
					if p <= 0.0:
						continue
					var e := 1.0 - pow(1.0 - p, 3.0)
					var from_x := r.position.x - base
					x = from_x + (l.cx - from_x) * e
					alpha = minf(1.0, p * 2.0)
				else:                      # the new exit — last letters leave first
					var p: float = minf(1.0, maxf(0.0, (b.clock - exit_at - (l.n - 1 - l.i) * 0.06) / 0.6))
					var e := p * p * p
					x = l.cx + e * (r.end.x + base - l.cx)
					alpha = 1.0 - p * 0.6
				TextKit.letter(n, l.ch, Vector2(x - l.w / 2.0, l.y), base, Color(ink, alpha))
		"rain_down":
			TextKit.stage(n, b)
			# dials moved: fall speed ×0.35 (0.6s → 1.7s) · a sideways sway added · stagger doubled
			if b.stagger.is_empty():
				return
			for l in TextKit.layout(b):
				var p: float = minf(1.0, maxf(0.0, (b.clock - b.stagger[l.i]) / 1.7))
				if p <= 0.0:
					continue
				var e: float = p * p * (3.0 - 2.0 * p)       # smooth, not accelerating — snow has no hurry
				var from_y := r.position.y - r.size.y * 0.4
				var y: float = from_y + (l.y - from_y) * e
				var sway := sin((1.0 - p) * 6.0 + l.i) * (1.0 - p) * base * 0.4
				TextKit.letter(n, l.ch, Vector2(l.x + sway, y), base, Color(ink, minf(1.0, p * 3.0)))
		"rise_up":
			TextKit.stage(n, b)
			# dials moved: distance ×1.6 (0.55H → 0.9H) · duration ×2 · a depth tint that clears on arrival
			var p: float = minf(1.0, b.clock / 2.6)
			var e := 1.0 - pow(1.0 - p, 2.0)
			var dy := (1.0 - e) * r.size.y * 0.9
			var col := Color((120.0 + e * 112.0) / 255.0, (160.0 + e * 69.0) / 255.0, 244.0 / 255.0, minf(1.0, p * 1.4))
			for l in TextKit.layout(b):
				TextKit.letter(n, l.ch, Vector2(l.x, l.y + dy), base, col)
		"crossroads":
			TextKit.stage(n, b)
			# dials moved: axis horizontal → vertical · stagger 0.05 → 0.03 (arrivals overlap more tightly)
			for l in TextKit.layout(b):
				var p: float = minf(1.0, maxf(0.0, (b.clock - l.i * 0.03) / 0.8))
				var e := 1.0 - pow(1.0 - p, 3.0)
				var from_y: float = (r.position.y - base) if l.i % 2 == 0 else (r.end.y + base)
				var y: float = from_y + (l.y - from_y) * e
				TextKit.letter(n, l.ch, Vector2(l.x, y), base, Color(ink, minf(1.0, p * 2.5)))
		"compass":
			TextKit.stage(n, b)
			# dials moved: random winds → one shared spiral · rotation added during travel
			# (Base.tick still deals the winds; the spiral ignores them)
			for l in TextKit.layout(b):
				var p: float = minf(1.0, maxf(0.0, (b.clock - l.i * 0.05) / 1.1))
				if p <= 0.0:
					continue
				var e := 1.0 - pow(1.0 - p, 3.0)
				var a: float = (1.0 - e) * PI * 2.5 + l.i    # the corkscrew
				var R := (1.0 - e) * maxf(r.size.x, r.size.y) * 0.5
				var x: float = l.cx + cos(a) * R
				var y: float = l.y + sin(a) * R * 0.6
				n.draw_set_transform(Vector2(x, y), (1.0 - e) * 2.0, Vector2.ONE)
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), base, Color(ink, minf(1.0, p * 2.0)))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"tracking":
			TextKit.stage(n, b)
			# dials moved: spacing wide → negative (overlap) at the start · the fade begins brighter
			var p: float = minf(1.0, b.clock / 2.4)
			var e := 1.0 - pow(1.0 - p, 2.0)
			var spacing := -base * 0.42 * (1.0 - e)          # from a pile-up to clean air
			var col := Color(ink, 0.55 + 0.45 * e)
			for l in TextKit.layout(b, base, spacing):
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), base, col, 300.0)
		"whoosh":
			TextKit.stage(n, b)
			# dials moved: side of travel flipped (left → right) · speed ×0.2 · streaks removed · lean removed
			var p: float = minf(1.0, b.clock / 2.8)
			var e := 1.0 - pow(1.0 - p, 2.0)                 # long, airless glide
			var dx := (1.0 - e) * r.size.x * 0.5
			var col := Color(ink, 0.2 + 0.8 * e)
			for l in TextKit.layout(b):
				TextKit.letter_weight(n, l.ch, Vector2(l.x + dx, l.y), base, col, 300.0)   # canvas weight 300
		"conveyor":
			TextKit.stage(n, b)
			# dials moved: direction flipped · dwell 3s → 1.5s (PERIOD 7 → 5.5) · belt dots run the other way
			var tt := fmod(t * (2.5 if b.shift > 0.0 else 1.0), 5.5)
			var ease_out := func(p: float) -> float: return 1.0 - pow(1.0 - p, 3.0)
			var ease_in := func(p: float) -> float: return p * p * p
			var dx: float
			if tt < 2.0:
				dx = -(1.0 - ease_out.call(tt / 2.0)) * r.size.x * 0.75   # enter from the right… which is the left of before
			elif tt < 3.5:
				dx = 0.0
			else:
				dx = ease_in.call((tt - 3.5) / 2.0) * r.size.x * 0.75
			var col := ink if tt >= 2.0 and tt < 3.5 else Color(ink, 0.75)
			for l in TextKit.layout(b):
				TextKit.letter(n, l.ch, Vector2(l.x + dx, l.y), base, col)
			var x: float = r.position.x + 14.0 - fmod(t * 40.0, 14.0)     # the dots march leftward now
			while x < r.end.x:
				n.draw_rect(Rect2(Vector2(x, b.mid + base * 0.45), Vector2(5, 2)), TextKit.DIM)
				x += 14.0
		_:
			Base.draw(n, b, t)
