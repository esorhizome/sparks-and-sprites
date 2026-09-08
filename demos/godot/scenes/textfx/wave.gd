extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
## WAVES & BOUNCES — eight text effects, ported from the web grimoire.

const TITLE := "Waves & bounces"
const BLURB := "the baseline as a trampoline"
const DEFS := [
	{ "id": "sine_wave", "name": "Sine wave", "hint": "the letters ride a rolling sine — press to steepen the sea" },
	{ "id": "stadium_wave", "name": "Stadium wave", "hint": "one letter jumps, then the next — the crowd goes around forever" },
	{ "id": "bounce_in", "name": "Bounce-in", "hint": "letters drop from above and bounce twice before settling" },
	{ "id": "jelly", "name": "Jelly", "hint": "hovers with a wobble — press somewhere and a ripple runs through from there, and every letter it passes keeps jiggling until its spring settles" },
	{ "id": "pendulum", "name": "Pendulum", "hint": "each letter hangs from its top corner and swings on its own length — press to shove them all, then watch the row drift out of step" },
	{ "id": "buoy", "name": "Buoy", "hint": "the letters float on unseen water — each a buoy on its own spring, bobbing and leaning with the swell; press and a boat's wake runs through and rings down" },
	{ "id": "skip_rope", "name": "Skip rope", "hint": "the whole line is a rope turned from both ends — the turn runs in from the hands and the middle swings widest; press to hurry the turners past the rope's resonance, and the middle swings against them until the turn slows" },
	{ "id": "ripple_press", "name": "Ripple press", "hint": "still water — press anywhere and a ring runs out through the letters, each one bobbing on after it has passed" },
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
			b.jy = zeros()                 # per letter: the spring's displacement and velocity, and the poke timer
			b.jvy = zeros()
			b.jnudge = spread(0.2, 1.5)
		"pendulum":
			# per letter: angle, angular velocity, hanging length, and the breath-of-air timer
			var th := zeros()
			var len := zeros()
			for i in TextKit.PHRASE.length():
				var ch: String = TextKit.PHRASE[i]
				var com := 0.42 if "bdfhklt".contains(ch) else (0.15 if "gjpqy".contains(ch) else 0.3)   # the weight's height above the baseline
				len[i] = 0.75 - com        # the pivot sits 0.75 above the baseline
				th[i] = float((i * 7) % 5 - 2) * 0.06   # a small, uneven start
			b.th = th
			b.om = zeros()
			b.len = len
			b.nudge = spread(1.0, 3.0)
		"buoy":
			b.by = zeros()                 # per letter: bob displacement and velocity, tilt and tilt velocity
			b.bvy = zeros()
			b.tilt = zeros()
			b.vt = zeros()
			b.wakes = []
		"skip_rope":
			b.speed = 1.0
			b.phase = 0.0
			b.ry = zeros()                 # the string: one mass per letter, y in letter-heights
			b.rvy = zeros()
		"ripple_press":
			b.drops = []
			b.py = zeros()
			b.pvy = zeros()

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
			var om: PackedFloat32Array = b.om
			for i in om.size():            # one shove for the whole row: velocity, never the angle
				om[i] += 3.5
		"buoy":
			var r: Rect2 = b.rect          # a boat went past, from the left
			b.wakes.append({ "x": r.position.x - b.base_size })
		"skip_rope":
			b.speed = 1.6                  # hurry the turners
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
			# every letter is a mass on an under-damped spring, y'' = −k·y − c·y'.
			# the ripple is a FRONT that runs outward from the press at a fixed
			# speed, and when it crosses a letter it does one thing only: it kicks
			# that letter's velocity. the spring does the rest — the letter dips,
			# overshoots, and rings down over a second or two instead of going
			# still the instant the front has passed. the resting wobble is a
			# small random poke now and then, ringing on the same spring.
			var r: Rect2 = b.rect
			var s: float = b.base_size
			var L := TextKit.layout(b)
			var y: PackedFloat32Array = b.jy
			var vy: PackedFloat32Array = b.jvy
			var nudge: PackedFloat32Array = b.jnudge
			var k := 120.0                 # stiffness (1/s²) and damping as a fraction of critical (2√k)
			var c := 2.0 * 0.15 * sqrt(k)
			var sub := maxi(1, ceili(dt * 50.0))   # ≤ 0.02 s steps: a coarse frame is cut up, not trusted
			var h := dt / float(sub)
			for w in b.waves:              # the front crosses each letter once, and kicks it once
				var was: float = w.age * r.size.x * 0.9
				var now: float = (w.age + dt) * r.size.x * 0.9
				for l in L:
					var d: float = absf(l.cx - w.x)
					if d >= was and d < now:
						vy[l.i] -= s * 3.2 * maxf(0.25, 1.0 - w.age * 0.8)   # weaker the further it has run
				w.age += dt
			b.waves = b.waves.filter(func(w): return w.age < 1.2)
			for i in y.size():
				nudge[i] -= dt
				if nudge[i] < 0.0:         # the resting wobble: a poke, then the spring
					vy[i] += randf_range(-0.25, 0.25) * s
					nudge[i] = randf_range(0.6, 1.8)
				for _s in sub:
					vy[i] += (-k * y[i] - c * vy[i]) * h
					y[i] += vy[i] * h
				y[i] = clampf(y[i], -s, s)
		"pendulum":
			# a real pendulum, integrated: θ'' = −(g/L)·sin θ − c·θ'. every letter
			# hangs from the same pivot height, but its weight sits at a different
			# depth — 'j' hangs below the line, 't' and 'h' reach above it — so each
			# has its own length L and its own period (∝ √L), and neighbours fall
			# out of step on their own, honestly. gravity is in letter-heights per
			# s², so a big card swings at the same tempo as a small one. a press is
			# a shove (angular velocity, never the angle), and a breath of air every
			# few seconds keeps the row from ever going quite still.
			var th: PackedFloat32Array = b.th
			var om: PackedFloat32Array = b.om
			var len: PackedFloat32Array = b.len
			var nudge: PackedFloat32Array = b.nudge
			var g := 8.0                   # gravity (letter-heights/s²) and damping as a fraction of critical
			var zeta := 0.03
			var sub := maxi(1, ceili(dt * 50.0))   # ≤ 0.02 s steps keep the symplectic step honest
			var h := dt / float(sub)
			for i in th.size():
				var w0 := sqrt(g / len[i])
				var c := 2.0 * zeta * w0
				nudge[i] -= dt
				if nudge[i] < 0.0:         # the breath of air
					om[i] += randf_range(-0.5, 0.5)
					nudge[i] = randf_range(1.5, 3.5)
				for _s in sub:
					om[i] += (-w0 * w0 * sin(th[i]) - c * om[i]) * h
					th[i] += om[i] * h
				om[i] = clampf(om[i], -1.7 * w0, 1.7 * w0)   # never enough to go over the top: it hangs, it doesn't spin
		"buoy":
			# buoyancy is a spring: push a float below its waterline and the water
			# it displaces pushes back in proportion, y'' = −k·(y − water) − c·y'.
			# the water is a slow, low swell travelling along the phrase; the letter
			# never sits on it exactly — it lags and overshoots, because the damping
			# is well under critical. the tilt is its own lazier spring aimed by the
			# vertical speed (a buoy leans back as it rises), so the lean lags the
			# bob. a press is a boat going past: a wake front runs left to right
			# and kicks each letter as it reaches it, and the spring rings that down.
			var r: Rect2 = b.rect
			var s: float = b.base_size
			var L := TextKit.layout(b)
			var y: PackedFloat32Array = b.by
			var vy: PackedFloat32Array = b.bvy
			var tilt: PackedFloat32Array = b.tilt
			var vt: PackedFloat32Array = b.vt
			var k := 40.0                  # buoyancy stiffness (1/s²) and damping as a fraction of critical
			var c := 2.0 * 0.18 * sqrt(k)
			var kt := 30.0                 # the tilt spring: lazier, calmer
			var ct := 2.0 * 0.4 * sqrt(kt)
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			for w in b.wakes:              # the wake front: one kick per letter as it arrives
				var was: float = w.x
				var now: float = w.x + dt * r.size.x * 1.2
				for l in L:
					if l.cx >= was and l.cx < now:
						vy[l.i] -= s * 1.8
				w.x = now
			b.wakes = b.wakes.filter(func(w): return w.x < r.end.x + s)
			for l in L:
				var i: int = l.i
				var water: float = sin(t * 1.3 - (l.cx - r.position.x) / r.size.x * 4.0) * s * 0.05   # the swell: the water's own slow rise and fall, travelling
				for _s in sub:
					vy[i] += (k * (water - y[i]) - c * vy[i]) * h
					y[i] += vy[i] * h
					var aim := clampf(-vy[i] * 0.12 / s, -0.4, 0.4)   # 0.12 s of vertical speed becomes the lean
					vt[i] += (kt * (aim - tilt[i]) - ct * vt[i]) * h
					tilt[i] += vt[i] * h
				y[i] = clampf(y[i], -s, s)
		"skip_rope":
			# the rope is a string of masses, one per letter, each pulled toward
			# the average of its two neighbours by the tension:
			# y'' = k·(y₋ + y₊ − 2y) − c·y'. the turners drive only the two END
			# masses round a small circle; the middle is never told where to be.
			# it swings widest because the turn rate sits just under the string's
			# first resonance, and it LAGS the hands because the turn has to
			# travel in along the rope at √k letters per second. a press hurries
			# the turners — the phase is integrated, so the hands never jump — past
			# that resonance, where the middle swings AGAINST the hands; as the
			# turn slows back through it the middle swells, then settles.
			b.speed = maxf(1.0, b.speed - dt * 0.5)
			var y: PackedFloat32Array = b.ry
			var vy: PackedFloat32Array = b.rvy
			var nn := y.size()
			var k := 95.0                  # tension (letters²/s²) and damping as a fraction of critical
			var c := 2.0 * 0.05 * sqrt(k)
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			var phase: float = b.phase
			for _s in sub:
				phase += 3.2 * b.speed * h   # the hands' turn, integrated: quicker after a press, never a jump
				var hand := sin(phase) * 0.12   # the small circle the hands make
				y[0] = hand
				y[nn - 1] = hand
				vy[0] = 0.0
				vy[nn - 1] = 0.0
				for i in range(1, nn - 1):
					vy[i] += (k * (y[i - 1] + y[i + 1] - 2.0 * y[i]) - c * vy[i]) * h
				for i in range(1, nn - 1):
					y[i] = clampf(y[i] + vy[i] * h, -1.0, 1.0)
			b.phase = phase
		"ripple_press":
			# the ring is a FRONT, and a letter is a float on an under-damped
			# spring, y'' = −k·y − c·y'. the front does exactly one thing when it
			# reaches a letter: it kicks the letter's velocity, harder for a young
			# ring than a spent one. the letter then bobs on its own spring and
			# rings down over a second, the way a float keeps bobbing after the
			# ripple is long gone.
			var r: Rect2 = b.rect
			var s: float = b.base_size
			var L := TextKit.layout(b)
			var y: PackedFloat32Array = b.py
			var vy: PackedFloat32Array = b.pvy
			var k := 90.0                  # stiffness (1/s²) and damping as a fraction of critical
			var c := 2.0 * 0.15 * sqrt(k)
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			for d in b.drops:              # the ring reaches a letter: one kick
				var was: float = d.age * r.size.x * 0.6
				var now: float = (d.age + dt) * r.size.x * 0.6
				for l in L:
					var dist: float = Vector2(l.cx, l.y - s * 0.3).distance_to(Vector2(d.x, d.y))
					if dist >= was and dist < now:
						vy[l.i] -= s * 2.8 * maxf(0.0, 1.0 - d.age * 0.8)
				d.age += dt
			b.drops = b.drops.filter(func(d): return d.age < 1.4)
			for i in y.size():
				for _s in sub:
					vy[i] += (-k * y[i] - c * vy[i]) * h
					y[i] += vy[i] * h
				y[i] = clampf(y[i], -s, s)
			if b.drops.is_empty() and int(floor(t)) % 5 == 4 and fmod(t, 1.0) < dt:
				b.drops.append({ "x": r.position.x + r.size.x * (0.3 + 0.4 * randf()),   # the pond drips on its own when ignored
					"y": b.mid - b.base_size, "age": 0.0 })

## One float per letter, zeroed — the per-letter spring state of the wave
## cards lives in these (a packed array read back from b is the same buffer,
## so tick can integrate in place).
static func zeros() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(TextKit.PHRASE.length())
	return out

static func spread(lo: float, hi: float) -> PackedFloat32Array:
	var out := zeros()
	for i in out.size():
		out[i] = randf_range(lo, hi)
	return out

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
			var y: PackedFloat32Array = b.jy
			for l in L:
				var sc: float = clampf(1.0 - y[l.i] / s * 0.6, 0.6, 1.5)   # lifted = wider, dipped = taller
				n.draw_set_transform(Vector2(l.cx, l.y + y[l.i]), 0.0, Vector2(sc, 2.0 - sc))   # bulge one way, squeeze the other
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), s, TextKit.INK)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"pendulum":
			var th: PackedFloat32Array = b.th
			for l in L:
				n.draw_set_transform(Vector2(l.cx, l.y - s * 0.75), th[l.i], Vector2.ONE)   # the pivot, above the letter
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, s * 0.75), s, TextKit.INK)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"buoy":
			var y: PackedFloat32Array = b.by
			var tilt: PackedFloat32Array = b.tilt
			for l in L:
				n.draw_set_transform(Vector2(l.cx, l.y + y[l.i]), tilt[l.i], Vector2.ONE)
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), s, TextKit.INK)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"skip_rope":
			var y: PackedFloat32Array = b.ry
			for l in L:
				var sy := 1.0 - minf(1.0, absf(y[l.i]) / 0.42) * 0.12    # foreshortening as it turns
				n.draw_set_transform(Vector2(l.cx, l.y + y[l.i] * s), 0.0, Vector2(1.0, maxf(0.5, sy)))
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), s, TextKit.INK)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"ripple_press":
			var r: Rect2 = b.rect
			var y: PackedFloat32Array = b.py
			for d in b.drops:                  # the visible rings, for honesty
				var rr: float = d.age * r.size.x * 0.6
				n.draw_arc(Vector2(d.x, d.y), rr, 0.0, TAU, 40,
					Color(0.63, 0.75, 1.0, maxf(0.0, 0.4 - d.age * 0.33)), 1.5)
			for l in L:
				TextKit.letter(n, l.ch, Vector2(l.x, l.y + y[l.i]), s, TextKit.INK)
