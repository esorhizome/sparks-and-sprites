extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
## WAVES & BOUNCES — eight text effects, ported from the web grimoire.

const TITLE := "Waves & bounces"
const BLURB := "the baseline as a trampoline"
const DEFS := [
	{ "id": "sine_wave", "name": "Sine wave", "hint": "the letters ride a rolling sine — press to steepen the sea" },
	{ "id": "stadium_wave", "name": "Stadium wave", "hint": "one letter jumps, then the next — the crowd goes around forever" },
	{ "id": "bounce_in", "name": "Bounce-in", "hint": "letters drop from above and bounce twice before settling" },
	{ "id": "jelly", "name": "Jelly", "hint": "hovers with a wobble — press somewhere and a ripple runs through from there" },
	{ "id": "pendulum", "name": "Pendulum", "hint": "each letter hangs from its top corner and swings — never quite in step" },
	{ "id": "buoy", "name": "Buoy", "hint": "the letters float on unseen water — bobbing, tilting, drifting a little" },
	{ "id": "skip_rope", "name": "Skip rope", "hint": "the whole line is a turning rope — the middle swings widest" },
	{ "id": "ripple_press", "name": "Ripple press", "hint": "still water — press anywhere and rings of motion radiate through the letters" },
]

static func init(b: Dictionary) -> void:
	match b.id:
		"sine_wave":
			b.amp = 1.0
		"stadium_wave":
			b.extra = 0.0
		"bounce_in":
			b.clock = 0.0
		"jelly":
			b.waves = []
		"pendulum":
			b.push_v = 0.0
		"buoy":
			b.chop = 0.0
		"skip_rope":
			b.speed = 1.0
		"ripple_press":
			b.drops = []

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"sine_wave":
			b.amp = 2.6
		"stadium_wave":
			b.extra = 1.0                  # everyone jumps at once
		"bounce_in":
			b.clock = 0.0
		"jelly":
			b.waves.append({ "x": pos.x, "age": 0.0 })
		"pendulum":
			b.push_v = 1.0
		"buoy":
			b.chop = 1.0                   # a boat went past
		"skip_rope":
			b.speed = 2.2
		"ripple_press":
			b.drops.append({ "x": pos.x, "y": pos.y, "age": 0.0 })

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"sine_wave":
			b.amp = maxf(1.0, b.amp - dt * 1.1)
		"stadium_wave":
			b.extra = maxf(0.0, b.extra - dt * 1.8)
		"bounce_in":
			b.clock += dt
			if b.clock > TextKit.PHRASE.length() * 0.09 + 4.0:
				b.clock = 0.0
		"jelly":
			for w in b.waves:
				w.age += dt
			b.waves = b.waves.filter(func(w): return w.age < 1.2)
		"pendulum":
			b.push_v = maxf(0.0, b.push_v - dt * 0.5)
		"buoy":
			b.chop = maxf(0.0, b.chop - dt * 0.4)
		"skip_rope":
			b.speed = maxf(1.0, b.speed - dt * 0.8)
		"ripple_press":
			for d in b.drops:
				d.age += dt
			b.drops = b.drops.filter(func(d): return d.age < 1.4)
			if b.drops.is_empty() and int(floor(t)) % 5 == 4 and fmod(t, 1.0) < dt:
				var r: Rect2 = b.rect      # the pond drips on its own when ignored
				b.drops.append({ "x": r.position.x + r.size.x * (0.3 + 0.4 * randf()),
					"y": b.mid - b.base_size, "age": 0.0 })

## Bounce-in's drop, simulated cheaply: three parabolic hops under gravity
## `g` with restitution `e`, everything in phrase-heights. `a` is seconds
## since this letter's drop began.
static func bounce_y(a: float) -> float:
	if a < 0.0:
		return -1.4                        # still waiting upstairs
	var g := 9.0                           # gravity and restitution, in phrase-heights
	var e := 0.45
	var v := 0.0
	var y := -1.4
	var tt := a
	for _hop in 4:
		var t_impact := (sqrt(v * v + 2.0 * g * -y) - v) / g
		if tt < t_impact:
			return y + v * tt + 0.5 * g * tt * tt
		tt -= t_impact
		v = -(v + g * t_impact) * e
		y = 0.0
		if absf(v) < 0.3:
			return 0.0
	return 0.0

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	TextKit.stage(n, b)
	var L := TextKit.layout(b)
	var s: float = b.base_size
	match b.id:
		"sine_wave":
			for l in L:
				var y: float = sin(t * 2.4 - l.i * 0.65) * s * 0.16 * b.amp
				var tilt: float = cos(t * 2.4 - l.i * 0.65) * 0.12 * b.amp   # letters lean into the slope
				n.draw_set_transform(Vector2(l.cx, l.y + y), tilt, Vector2.ONE)
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), s, TextKit.INK)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"stadium_wave":
			for l in L:
				var phase := fmod(t * 1.1 - l.i * 0.09, 1.0)                 # each letter's turn comes around
				var jump: float = sin(phase / 0.22 * PI) if phase < 0.22 else 0.0
				var k: float = maxf(jump, b.extra)
				var squash := 1.0 - k * 0.18                                 # they crouch as they land
				n.draw_set_transform(Vector2(l.cx, l.y - k * s * 0.5), 0.0,
					Vector2(1.0 + k * 0.1, squash + k * 0.35))
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), s, TextKit.INK)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"bounce_in":
			for l in L:
				var y: float = bounce_y(b.clock - l.i * 0.09)
				if y <= -1.39:
					continue
				var near := absf(y) < 0.02                                   # squash only at the floor
				n.draw_set_transform(Vector2(l.cx, l.y + y * s * 1.2), 0.0,
					Vector2(1.12, 0.88) if near else Vector2.ONE)
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), s, TextKit.INK)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"jelly":
			var r: Rect2 = b.rect
			for l in L:
				var y: float = sin(t * 3.0 + l.i * 1.7) * s * 0.03           # the resting wobble
				var sc := 1.0
				for w in b.waves:              # every live ripple pushes as it passes
					var d: float = absf(l.cx - w.x)
					var front: float = w.age * r.size.x * 0.9
					var k: float = exp(-pow((d - front) / (s * 1.2), 2)) * maxf(0.0, 1.0 - w.age * 1.2)
					y -= k * s * 0.35
					sc += k * 0.2
				n.draw_set_transform(Vector2(l.cx, l.y + y), 0.0, Vector2(sc, 2.0 - sc))   # bulge one way, squeeze the other
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), s, TextKit.INK)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"pendulum":
			for l in L:
				# period drifts with index — neighbours slowly fall out of phase, like real pendulums
				var a: float = sin(t * (2.0 + l.i * 0.13)) * (0.12 + b.push_v * 0.35)
				n.draw_set_transform(Vector2(l.cx, l.y - s * 0.75), a, Vector2.ONE)   # the pivot, above the letter
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, s * 0.75), s, TextKit.INK)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"buoy":
			for l in L:
				var k: float = 1.0 + b.chop * 2.0
				var y: float = (sin(t * 1.3 + l.i * 0.9) * 0.5 + sin(t * 2.7 + l.i * 2.3) * 0.3) * s * 0.12 * k
				var tilt: float = sin(t * 1.1 + l.i * 1.4) * 0.09 * k
				n.draw_set_transform(Vector2(l.cx, l.y + y), tilt, Vector2.ONE)
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), s, TextKit.INK)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"skip_rope":
			for l in L:
				var arc: float = sin(float(l.i) / (l.n - 1) * PI)            # pinned at both ends
				var y: float = sin(t * 3.2 * b.speed) * arc * s * 0.42
				var sx := 1.0 - absf(sin(t * 3.2 * b.speed)) * arc * 0.12    # foreshortening as it turns
				n.draw_set_transform(Vector2(l.cx, l.y + y), 0.0, Vector2(1.0, maxf(0.5, sx)))
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), s, TextKit.INK)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"ripple_press":
			var r: Rect2 = b.rect
			for d in b.drops:                  # the visible rings, for honesty
				var rr: float = d.age * r.size.x * 0.6
				n.draw_arc(Vector2(d.x, d.y), rr, 0.0, TAU, 40,
					Color(0.63, 0.75, 1.0, maxf(0.0, 0.4 - d.age * 0.33)), 1.5)
			for l in L:
				var y := 0.0
				for d in b.drops:
					var dist: float = Vector2(l.cx, l.y - s * 0.3).distance_to(Vector2(d.x, d.y))
					var front: float = d.age * r.size.x * 0.6
					y -= exp(-pow((dist - front) / (s * 0.9), 2)) * maxf(0.0, 1.0 - d.age * 0.8) * s * 0.3
				TextKit.letter(n, l.ch, Vector2(l.x, l.y + y), s, TextKit.INK)
