extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
const Base := preload("res://scenes/textfx/wave.gd")
## WAVES & BOUNCES — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"sine_wave": { "name": "Standing wave", "hint": "the travel removed — fixed nodes and antinodes, physics-classroom style" },
	"stadium_wave": { "name": "The dip", "hint": "the jump turned upside down — each letter ducks in turn instead" },
	"bounce_in": { "name": "Moon bounce", "hint": "gravity quartered, bounces livelier — the same drop on a smaller world" },
	"jelly": { "name": "Set gelatin", "hint": "the resting wobble dies away to stillness — until a press jiggles it twice as hard" },
	"pendulum": { "name": "Metronome", "hint": "all the pendulums lock into sync, and the swing ticks in quantized beats" },
	"buoy": { "name": "Storm swell", "hint": "the same sea in worse weather — bigger, faster, with spray at the crests" },
	"skip_rope": { "name": "Double dutch", "hint": "two ropes in counter-phase — odd letters ride one, even letters the other" },
	"ripple_press": { "name": "Stone skip", "hint": "one press throws a skipping stone — three splashes in a row, each smaller" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)
	match b.id:
		"jelly":
			b.calm = 0.0
		"buoy":
			b.spray = []

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"jelly":
			# dial: a press wakes the jelly — the calm resets with the ripple
			b.waves.append({ "x": pos.x, "age": 0.0 })
			b.calm = 0.0
		"ripple_press":
			# dial: one drop → three, spaced and delayed like a skipping stone
			var r: Rect2 = b.rect
			for sk in 3:                   # each skip lands further along, later, smaller
				b.drops.append({ "x": pos.x + sk * r.size.x * 0.22, "y": b.mid - b.base_size * 0.5,
					"age": -sk * 0.35, "k": 1.0 - sk * 0.3 })
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"bounce_in":
			# dial: stagger widened 0.09 → 0.18 · the dwell doubled — slow worlds take longer
			b.clock += dt
			if b.clock > TextKit.PHRASE.length() * 0.18 + 8.0:
				b.clock = 0.0
		"jelly":
			# dial: idle wobble decays to zero — stillness earns itself back
			b.calm = minf(1.0, b.calm + dt * 0.25)
			for w in b.waves:
				w.age += dt
			b.waves = b.waves.filter(func(w): return w.age < 1.2)
		"buoy":
			# dial: spray flecks spawn where a crest breaks, then fall under gravity
			b.chop = maxf(0.0, b.chop - dt * 0.4)
			var s: float = b.base_size
			for l in TextKit.layout(b):
				var k: float = (1.0 + b.chop * 1.5) * 2.5
				var y: float = (sin(t * 2.2 + l.i * 0.9) * 0.5 + sin(t * 4.6 + l.i * 2.3) * 0.3) * s * 0.12 * k
				if y < -s * 0.22 and randf() < 0.1:                          # a crest breaks
					b.spray.append({ "x": l.cx + randf_range(-3.0, 3.0), "y": l.y + y - s * 0.5,
						"vx": randf_range(-20.0, 20.0), "vy": randf_range(-40.0, -10.0), "life": 0.7 })
			for sp in b.spray:
				sp.x += sp.vx * dt
				sp.y += sp.vy * dt
				sp.vy += 90.0 * dt
				sp.life -= dt * 1.4
			b.spray = b.spray.filter(func(sp): return sp.life > 0.0)
		"ripple_press":
			# dial: the pond no longer drips on its own — the stone is the only source
			for d in b.drops:
				d.age += dt
			b.drops = b.drops.filter(func(d): return d.age < 1.4)
		_:
			Base.tick(b, dt, t)

## Moon bounce's drop — Base.bounce_y with gravity 9 → 2.2, restitution
## 0.45 → 0.6, one extra hop, and a lower settling threshold.
static func moon_bounce_y(a: float) -> float:
	if a < 0.0:
		return -1.4
	var g := 2.2
	var e := 0.6
	var v := 0.0
	var y := -1.4
	var tt := a
	for _hop in 5:
		var t_impact := (sqrt(v * v + 2.0 * g * -y) - v) / g
		if tt < t_impact:
			return y + v * tt + 0.5 * g * tt * tt
		tt -= t_impact
		v = -(v + g * t_impact) * e
		y = 0.0
		if absf(v) < 0.2:
			return 0.0
	return 0.0

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var s: float = b.base_size
	match b.id:
		"sine_wave":
			TextKit.stage(n, b)
			# dials moved: phase travel removed (position sets amplitude, not phase) · amp ×1.4
			for l in TextKit.layout(b):
				var envelope: float = sin(float(l.i) / (l.n - 1) * PI * 2.0)   # two nodes across the phrase
				var y: float = sin(t * 3.0) * envelope * s * 0.22 * b.amp
				TextKit.letter(n, l.ch, Vector2(l.x, l.y + y), s, TextKit.INK)
		"stadium_wave":
			TextKit.stage(n, b)
			# dials moved: direction up → down · the squash happens at the top, not the floor
			for l in TextKit.layout(b):
				var phase := fmod(t * 1.1 - l.i * 0.09, 1.0)
				var duck: float = sin(phase / 0.22 * PI) if phase < 0.22 else 0.0
				var k: float = maxf(duck, b.extra)
				n.draw_set_transform(Vector2(l.cx, l.y + k * s * 0.3), 0.0,
					Vector2(1.0 + k * 0.15, 1.0 - k * 0.3))                  # flattening as it ducks
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), s, TextKit.INK)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"bounce_in":
			TextKit.stage(n, b)
			# dials moved: gravity and stagger in moon_bounce_y and tick · squash softened
			for l in TextKit.layout(b):
				var y: float = moon_bounce_y(b.clock - l.i * 0.18)
				if y <= -1.39:
					continue
				n.draw_set_transform(Vector2(l.cx, l.y + y * s * 1.2), 0.0,
					Vector2(1.06, 0.94) if absf(y) < 0.02 else Vector2.ONE)  # gentler squash: the landings are soft up here
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), s, TextKit.INK)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"jelly":
			TextKit.stage(n, b)
			# dials moved: press ripple amplitude ×2 (dip 0.35 → 0.7, bulge 0.2 → 0.4) · wobble × (1 − calm)
			var r: Rect2 = b.rect
			for l in TextKit.layout(b):
				var y: float = sin(t * 3.0 + l.i * 1.7) * s * 0.03 * (1.0 - b.calm)
				var sc := 1.0
				for w in b.waves:
					var d: float = absf(l.cx - w.x)
					var front: float = w.age * r.size.x * 0.9
					var k: float = exp(-pow((d - front) / (s * 1.2), 2)) * maxf(0.0, 1.0 - w.age * 1.2)
					y -= k * s * 0.7
					sc += k * 0.4
				n.draw_set_transform(Vector2(l.cx, l.y + y), 0.0, Vector2(sc, 2.0 - sc))
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), s, TextKit.INK)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"pendulum":
			TextKit.stage(n, b)
			# dials moved: per-letter drift removed (one shared period) · motion quantized to ticks
			var beat := roundf(sin(t * 3.2) * 2.0) / 2.0     # −1, −0.5, 0, 0.5, 1: the escapement
			var a: float = beat * (0.12 + b.push_v * 0.2)
			for l in TextKit.layout(b):
				n.draw_set_transform(Vector2(l.cx, l.y - s * 0.75), a, Vector2.ONE)
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, s * 0.75), s, TextKit.INK)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"buoy":
			TextKit.stage(n, b)
			# dials moved: amplitude ×2.5 · speed ×1.7 (the spray itself lives in tick)
			for l in TextKit.layout(b):
				var k: float = (1.0 + b.chop * 1.5) * 2.5
				var y: float = (sin(t * 2.2 + l.i * 0.9) * 0.5 + sin(t * 4.6 + l.i * 2.3) * 0.3) * s * 0.12 * k
				var tilt: float = sin(t * 1.9 + l.i * 1.4) * 0.14 * (1.0 + b.chop)
				n.draw_set_transform(Vector2(l.cx, l.y + y), tilt, Vector2.ONE)
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), s, TextKit.INK)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for sp in b.spray:
				n.draw_rect(Rect2(Vector2(sp.x, sp.y), Vector2(1.6, 1.6)), Color(0.78, 0.88, 1.0, 0.7))
		"skip_rope":
			TextKit.stage(n, b)
			# dials moved: a second rope added at opposite phase · turn rate ×1.25
			for l in TextKit.layout(b):
				var arc: float = sin(float(l.i) / (l.n - 1) * PI)
				var phase: float = t * 4.0 * b.speed + (PI if l.i % 2 == 1 else 0.0)   # the second rope
				var y: float = sin(phase) * arc * s * 0.34
				n.draw_set_transform(Vector2(l.cx, l.y + y), 0.0,
					Vector2(1.0, maxf(0.5, 1.0 - absf(sin(phase)) * arc * 0.12)))
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), s, TextKit.INK)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"ripple_press":
			TextKit.stage(n, b)
			# dials moved: rings ×0.7 smaller (speed 0.6 → 0.5, dip 0.3 → 0.22) · everything scaled by each skip's k
			var r: Rect2 = b.rect
			for d in b.drops:
				if d.age < 0.0:            # this skip hasn't landed yet
					continue
				var rr: float = d.age * r.size.x * 0.5 * d.k
				n.draw_arc(Vector2(d.x, d.y), rr, 0.0, TAU, 40,
					Color(0.63, 0.75, 1.0, maxf(0.0, 0.4 - d.age * 0.33) * d.k), 1.5)
			for l in TextKit.layout(b):
				var y := 0.0
				for d in b.drops:
					if d.age < 0.0:
						continue
					var dist: float = Vector2(l.cx, l.y - s * 0.3).distance_to(Vector2(d.x, d.y))
					var front: float = d.age * r.size.x * 0.5 * d.k
					y -= exp(-pow((dist - front) / (s * 0.9), 2)) * maxf(0.0, 1.0 - d.age * 0.8) * s * 0.22 * d.k
				TextKit.letter(n, l.ch, Vector2(l.x, l.y + y), s, TextKit.INK)
		_:
			Base.draw(n, b, t)
