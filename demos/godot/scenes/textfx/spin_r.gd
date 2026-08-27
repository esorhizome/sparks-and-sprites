extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
const Base := preload("res://scenes/textfx/spin.gd")
## SPINS & FLIPS — the rhymes. Dials named per branch; the rest delegates.

const STUCK := 5                          ## the stubborn slot — the second 't' of "just this"

const RHYMES := {
	"split_flap": { "name": "Broken flap", "hint": "the board settles — except one stubborn slot that flips until you press it home" },
	"coin_spin": { "name": "Wobbly coin", "hint": "each landing wobbles like a real dropped coin before it lies flat" },
	"cartwheel": { "name": "Backflip", "hint": "from the other wing, spinning the other way, with a showy overshoot at the end" },
	"revolving_door": { "name": "Saloon door", "hint": "the arrival swings past centre and back, losing a little each pass" },
	"clock_hands": { "name": "Compass rose", "hint": "they never settle upright — all the letters align to one slowly turning angle" },
	"tumble_dry": { "name": "Zero-g", "hint": "no walls, no bounces — the letters wrap around the card until gravity is switched on" },
	"orbit_assembly": { "name": "Comet tail", "hint": "the same orbit, slower, with each letter trailing a tail of fading ghosts" },
}

static func init(b: Dictionary) -> void:
	match b.id:
		"split_flap":
			b.slots = deal_broken()
			b.fixed = false
		"clock_hands":
			b.angles = Base.scatter()
			b.blend = 0.0
		"tumble_dry":
			b.bods = drift_free(b)
			b.settle = 0.0
		"orbit_assembly":
			b.clock = 0.0
			b.hist = []
		_:
			Base.init(b)

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"split_flap":
			b.fixed = true                  # the technician thumps the board
		"clock_hands":
			b.angles = Base.scatter()       # press re-scatters
			b.blend = 0.0
		"orbit_assembly":
			b.clock = 0.0
			b.hist = []
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"split_flap":
			# dials moved: one slot's flip count is infinite until pressed · everyone else lands sooner · no redeal
			for i in TextKit.PHRASE.length():
				if TextKit.PHRASE[i] == " ":
					continue
				var s: Dictionary = b.slots[i]
				if i == STUCK and b.fixed and s.flips > 3:
					s.flips = 3             # the thump takes effect
				if s.flips > 0:
					s.phase += dt * 9.0
					if s.phase >= 1.0:
						s.phase = 0.0
						s.flips -= 1
						s.cur = (s.cur + 1) % TextKit.GLYPHS.length()
		"coin_spin":
			# dial: loop rest 4 s → 5 s (the wobble needs the room)
			b.clock += dt
			if b.clock > TextKit.PHRASE.length() * 0.12 + 5.0:
				b.clock = 0.0
		"revolving_door":
			# dial: loop rest 4.2 s → 5 s (the swings take longer to die)
			b.clock += dt
			if b.clock > TextKit.PHRASE.length() * 0.07 + 5.0:
				b.clock = 0.0
		"clock_hands":
			# dial: the 2 s clock → a slow 0.5/s blend, and no 6 s re-scatter
			b.blend = minf(1.0, b.blend + dt * 0.5)
		"tumble_dry":
			# dials moved: wall bounce → wraparound · drift ×0.6 slower · press lands with one bounce
			var r: Rect2 = b.rect
			b.settle = maxf(0.0, b.settle - dt)
			var L := TextKit.layout(b)
			for l in L:
				var bd: Dictionary = b.bods[l.i]
				if b.settle > 0.0:          # gravity on: fall to the baseline, one soft bounce
					bd.vv += 260.0 * dt
					bd.y += bd.vv * dt
					if bd.y > l.y:
						bd.y = l.y
						bd.vv = -bd.vv * 0.35
					bd.x += (l.cx - bd.x) * minf(1.0, dt * 4.0)
					bd.a += (0.0 - bd.a) * minf(1.0, dt * 4.0)
				else:
					bd.vv = 0.0
					bd.x = r.position.x + fposmod(bd.x - r.position.x + bd.vx * dt, r.size.x)   # the wrap IS the dial
					bd.y = r.position.y + fposmod(bd.y - r.position.y + bd.vy * dt, r.size.y)
					bd.a += bd.va * dt
		"orbit_assembly":
			# dials moved: orbit speed 1.4 → 1.0 · a ghost trail added · landing delayed to 2 s
			b.clock += dt
			if b.clock > 10.0:
				b.clock = 0.0
				b.hist = []
			var r: Rect2 = b.rect
			var L := TextKit.layout(b)
			var p := clampf((b.clock - 2.0) / 2.2, 0.0, 1.0)
			var e := p * p * (3.0 - 2.0 * p)
			var frame := []
			for l in L:
				var base_a: float = float(l.i) / float(l.n) * TAU + b.clock * 1.0
				var rr: float = b.base_size * 2.0 * (1.0 - e)
				var x: float = r.get_center().x * (1.0 - e) + l.cx * e + cos(base_a) * rr
				var y: float = (b.mid - b.base_size * 0.3) * (1.0 - e) + l.y * e + sin(base_a) * rr * 0.5
				frame.append({ "x": x, "y": y, "ch": l.ch, "w": l.w })
			b.hist.append(frame)
			if b.hist.size() > 10:
				b.hist.pop_front()
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	match b.id:
		"coin_spin":
			TextKit.stage(n, b)
			# dials moved: clean settle → decaying wobble after landing · spins 2.5 → 1.5
			var L := TextKit.layout(b)
			for l in L:
				var a: float = b.clock - l.i * 0.12
				if a <= 0.0:
					continue
				var sx: float
				if a < 0.7:                 # the spin, as before but shorter
					var p := a / 0.7
					sx = cos((1.0 - pow(1.0 - p, 2.0)) * 1.5 * PI)
				else:                       # the wobble: rattling toward flat
					var w := a - 0.7
					sx = 1.0 - absf(sin(w * 14.0)) * exp(-w * 2.2) * 0.5
				n.draw_set_transform(Vector2(l.cx, l.y), 0.0, Vector2(maxf(0.05, absf(sx)), 1.0))
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), b.base_size,
					Color(TextKit.INK.r, TextKit.INK.g, TextKit.INK.b, 0.4 + 0.6 * absf(sx)))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"cartwheel":
			TextKit.stage(n, b)
			# dials moved: side left → right · rotation sign flipped · an overshoot roll added at arrival
			var r: Rect2 = b.rect
			var L := TextKit.layout(b)
			for l in L:
				var p: float = clampf((b.clock - (l.n - 1 - l.i) * 0.08) / 0.8, 0.0, 1.0)
				if p <= 0.0:
					continue
				var e := 1.0 - pow(1.0 - p, 3.0)
				var end_x: float = r.position.x + r.size.x + b.base_size
				var x: float = end_x - (end_x - l.cx) * e
				var over := 0.0 if p >= 1.0 else sin(p * PI) * 0.15   # the flourish
				var rot: float = (1.0 - e) * PI * 3.0 + over
				n.draw_set_transform(Vector2(x, l.y - b.base_size * 0.3), rot, Vector2.ONE)
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, b.base_size * 0.3), b.base_size, TextKit.INK)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"revolving_door":
			TextKit.stage(n, b)
			# dials moved: eased landing → decaying oscillation · orbit radius 2.2 → 1.1
			var L := TextKit.layout(b)
			for l in L:
				var a: float = b.clock - l.i * 0.07
				if a <= 0.0:
					continue
				var swing := cos(a * 7.0) * exp(-a * 1.8)   # a damped swing about the resting spot
				var x: float = l.cx + swing * b.base_size * 1.1
				var rot := swing * 0.6
				n.draw_set_transform(Vector2(x, l.y), rot, Vector2.ONE)
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), b.base_size,
					Color(TextKit.INK.r, TextKit.INK.g, TextKit.INK.b, minf(1.0, a * 3.0)))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"clock_hands":
			TextKit.stage(n, b)
			# dial: target upright → a shared, slowly turning tilt
			var L := TextKit.layout(b)
			var shared := sin(t * 0.5) * 0.4                 # the rose, breathing round
			var bl: float = b.blend
			var e := bl * bl * (3.0 - 2.0 * bl)
			for l in L:
				var a: float = b.angles[l.i] * (1.0 - e) + shared * e
				n.draw_set_transform(Vector2(l.cx, l.y - b.base_size * 0.3), a, Vector2.ONE)
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, b.base_size * 0.3), b.base_size, TextKit.INK)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"orbit_assembly":
			TextKit.stage(n, b)
			var hist: Array = b.hist
			if hist.is_empty():
				return
			var p := clampf((b.clock - 2.0) / 2.2, 0.0, 1.0)
			var e := p * p * (3.0 - 2.0 * p)
			var h := 0
			while h < hist.size() - 1:                       # the tail
				var k := float(h) / hist.size()
				for f in hist[h]:
					TextKit.letter(n, f.ch, Vector2(f.x - f.w / 2.0, f.y), b.base_size,
						Color(0.67, 0.71, 1.0, k * 0.18 * (1.0 - e)))
				h += 3
			for f in hist[hist.size() - 1]:
				TextKit.letter(n, f.ch, Vector2(f.x - f.w / 2.0, f.y), b.base_size, TextKit.INK)
		_:
			Base.draw(n, b, t)               # Broken flap and Zero-g render exactly like their bases

## Broken flap: the JS said flips: Infinity for the stuck slot — GDScript ints
## have no Infinity, so 999999 flips (about 30 hours of clacking) stands in.
static func deal_broken() -> Array:
	var out: Array = []
	for i in TextKit.PHRASE.length():
		out.append({ "flips": 999999 if i == STUCK else int(randf_range(2.0, 7.0)), "phase": 0.0,
			"cur": randi() % TextKit.GLYPHS.length() })
	return out

## Zero-g bodies: anywhere on the card, drifting ×0.6 slower, with a fall
## speed `vv` the press's gravity uses.
static func drift_free(b: Dictionary) -> Array:
	var r: Rect2 = b.rect
	var out: Array = []
	for _i in TextKit.PHRASE.length():
		out.append({ "x": r.position.x + randf_range(0.0, r.size.x),
			"y": r.position.y + randf_range(0.0, r.size.y),
			"vx": randf_range(-18.0, 18.0), "vy": randf_range(-18.0, 18.0),
			"a": randf_range(0.0, TAU), "va": randf_range(-2.0, 2.0), "vv": 0.0 })
	return out
