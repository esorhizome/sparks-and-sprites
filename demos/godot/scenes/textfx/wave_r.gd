extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
const Base := preload("res://scenes/textfx/wave.gd")
## WAVES & BOUNCES — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"sine_wave": { "name": "Standing wave", "hint": "the travel removed — fixed nodes and antinodes, physics-classroom style" },
	"stadium_wave": { "name": "The dip", "hint": "the jump turned upside down — each letter ducks in turn instead" },
	"bounce_in": { "name": "Moon bounce", "hint": "gravity quartered, bounces livelier — the same drop on a smaller world" },
	"jelly": { "name": "Set gelatin", "hint": "the resting wobble dies away as the gel sets — the idle pokes fade and the spring damps harder — until a press kicks it twice as hard and loosens it again" },
	"pendulum": { "name": "Metronome", "hint": "one shared rod, so every letter swings in sync — an escapement pushes it at the bottom of each swing to keep it going, and the swing shows in quantized ticks; press to widen the beat" },
	"buoy": { "name": "Storm swell", "hint": "the same buoys in worse weather — the swell ×2.5 and faster with a short chop on top, spray where a crest breaks; press and a breaker hits the whole row at once and the sea stays rough for a while" },
	"skip_rope": { "name": "Double dutch", "hint": "two ropes turned in counter-phase from the same hands — odd letters ride one, even letters the other — each a string the turn has to travel in along; press to hurry the turners" },
	"ripple_press": { "name": "Stone skip", "hint": "one press throws a skipping stone — three splashes in a row, each smaller, each a ring that kicks the letters it reaches, and every letter bobs on after each ring has passed" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)
	match b.id:
		"jelly":
			b.calm = 0.0                   # the gel's set: 0 loose → 1 set
		"pendulum":
			b.mth = 0.12                   # the one shared rod: its angle and angular velocity
			b.mom = 0.0
			b.push_v = 0.0                 # the metronome's push widens the set amplitude, then fades
		"buoy":
			b.spray = []
			b.chop = 0.0                   # the storm's chop: how rough the sea is, fading after a breaker
		"skip_rope":
			b.ry2 = Base.zeros()           # the second rope: its own string of masses
			b.rvy2 = Base.zeros()

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"jelly":
			# dial: a press wakes the jelly — the calm resets with the ripple
			b.waves.append({ "x": pos.x, "age": 0.0 })
			b.calm = 0.0
		"pendulum":
			b.push_v = 1.0                 # dial: the push widens the set amplitude instead of shoving the row
		"buoy":
			# dial: a breaker instead of a wake — every letter kicked at once, unevenly, and the sea roughens
			b.chop = 1.0
			var vy: PackedFloat32Array = b.bvy
			for i in vy.size():
				vy[i] -= b.base_size * randf_range(1.2, 2.2)
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
			# dials moved: the idle pokes fade with `calm` · damping rises as the
			# gel sets (ζ 0.15 → 0.4) · press kick ×2 · a press resets the calm.
			# the same per-letter spring as Jelly, y'' = −k·y − c·y', kicked once
			# by the front as it passes. what SETS is the gel: calm climbs from 0
			# to 1 over four seconds, the random idle pokes shrink to nothing with
			# it, and the damping rises from loose toward stiff, so a set gel rings
			# down in a wobble or two where a fresh one rings on.
			b.calm = minf(1.0, b.calm + dt * 0.25)         # stillness earns itself back
			var r: Rect2 = b.rect
			var s: float = b.base_size
			var L := TextKit.layout(b)
			var y: PackedFloat32Array = b.jy
			var vy: PackedFloat32Array = b.jvy
			var nudge: PackedFloat32Array = b.jnudge
			var k := 120.0                 # stiffness (1/s²); the damping is the dial
			var c: float = 2.0 * (0.15 + b.calm * 0.25) * sqrt(k)   # the gel sets: damping climbs
			var sub := maxi(1, ceili(dt * 50.0))   # ≤ 0.02 s steps: a coarse frame is cut up, not trusted
			var h := dt / float(sub)
			for w in b.waves:              # the front crosses each letter once, and kicks it once — twice as hard
				var was: float = w.age * r.size.x * 0.9
				var now: float = (w.age + dt) * r.size.x * 0.9
				for l in L:
					var d: float = absf(l.cx - w.x)
					if d >= was and d < now:
						vy[l.i] -= s * 6.4 * maxf(0.25, 1.0 - w.age * 0.8)
				w.age += dt
			b.waves = b.waves.filter(func(w): return w.age < 1.2)
			for i in y.size():
				nudge[i] -= dt
				if nudge[i] < 0.0:         # the idle poke, fading as it sets
					vy[i] += randf_range(-0.25, 0.25) * s * (1.0 - b.calm)
					nudge[i] = randf_range(0.6, 1.8)
				for _s in sub:
					vy[i] += (-k * y[i] - c * vy[i]) * h
					y[i] += vy[i] * h
				y[i] = clampf(y[i], -s, s)
		"pendulum":
			# dials moved: per-letter lengths → one shared rod (one θ for the
			# row) · the breath of air → an escapement · the drawn angle quantized
			# to ticks · a press widens the set amplitude instead of shoving.
			# the same pendulum as Pendulum, θ'' = −(g/L)·sin θ − c·θ', but ONE of
			# them, and every letter reads its angle — that is the whole of "in
			# sync". a metronome is a damped pendulum kept alive by an escapement:
			# each time the rod passes the bottom it gets one small push in the
			# direction it is already going, sized to what the swing is short of
			# its set amplitude and capped, so the amplitude settles to the setting
			# instead of being assigned.
			b.push_v = maxf(0.0, b.push_v - dt * 0.5)
			var g := 8.0                   # gravity (letter-heights/s²), the shared rod's length, and damping as a fraction of critical
			var rod := 0.75
			var w0 := sqrt(g / rod)
			var c := 2.0 * 0.06 * w0
			var amp: float = 0.12 + b.push_v * 0.2         # the set amplitude
			var th: float = b.mth
			var om: float = b.mom
			var sub := maxi(1, ceili(dt * 50.0))   # ≤ 0.02 s steps keep the symplectic step honest
			var h := dt / float(sub)
			for _s in sub:
				var was := th
				om += (-w0 * w0 * sin(th) - c * om) * h
				th += om * h
				if (was < 0.0) != (th < 0.0):   # through the bottom: the escapement's push, with the motion, never against it
					var want := w0 * amp   # the speed at the bottom that carries the rod to the set amplitude
					var kick := maxf(0.0, minf(want * 0.5, want - absf(om)))
					om += signf(om) * kick
			b.mth = th
			b.mom = clampf(om, -1.7 * w0, 1.7 * w0)   # never enough to go over the top
		"buoy":
			# dials moved: swell amplitude ×2.5 · swell speed ×1.7 · a second,
			# shorter chop wave added · tilt gain up · spray at the crests.
			# the same springs as Buoy — buoyancy y'' = −k·(y − water) − c·y', and
			# a lazier tilt spring aimed by the vertical speed — but the WATER is
			# worse: a bigger, faster swell with a short chop riding on it. the
			# letters are the same floats, so they lag and overshoot the same way;
			# they just have more to follow. `chop` raises the sea for a few
			# seconds after a breaker. spray is thrown where a letter rides high
			# and rising, and falls under gravity.
			b.chop = maxf(0.0, b.chop - dt * 0.4)
			var r: Rect2 = b.rect
			var s: float = b.base_size
			var L := TextKit.layout(b)
			var y: PackedFloat32Array = b.by
			var vy: PackedFloat32Array = b.bvy
			var tilt: PackedFloat32Array = b.tilt
			var vt: PackedFloat32Array = b.vt
			var rough: float = (1.0 + b.chop * 1.5) * 2.5   # how much sea there is to follow
			var k := 40.0                  # buoyancy stiffness (1/s²) and damping as a fraction of critical
			var c := 2.0 * 0.18 * sqrt(k)
			var kt := 30.0                 # the tilt spring: lazier, calmer
			var ct := 2.0 * 0.4 * sqrt(kt)
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			for l in L:
				var i: int = l.i
				var u: float = (l.cx - r.position.x) / r.size.x
				var water: float = (sin(t * 2.2 - u * 4.0) * 0.05 + sin(t * 4.6 - u * 9.0) * 0.02) * s * rough   # the swell, and the chop on it, both travelling
				for _s in sub:
					vy[i] += (k * (water - y[i]) - c * vy[i]) * h
					y[i] += vy[i] * h
					var aim := clampf(-vy[i] * 0.16 / s, -0.6, 0.6)   # 0.16 s of vertical speed becomes the lean: it leans harder out here
					vt[i] += (kt * (aim - tilt[i]) - ct * vt[i]) * h
					tilt[i] += vt[i] * h
				y[i] = clampf(y[i], -s, s)
				if y[i] < -s * 0.22 and vy[i] < 0.0 and randf() < 0.1:   # a crest breaks: high, and still rising
					b.spray.append({ "x": l.cx + randf_range(-3.0, 3.0), "y": l.y + y[i] - s * 0.5,
						"vx": randf_range(-20.0, 20.0), "vy": randf_range(-40.0, -10.0), "life": 0.7 })
			for sp in b.spray:
				sp.x += sp.vx * dt
				sp.y += sp.vy * dt
				sp.vy += 90.0 * dt
				sp.life -= dt * 1.4
			b.spray = b.spray.filter(func(sp): return sp.life > 0.0)
		"skip_rope":
			# dials moved: one string → two, driven at opposite phase · turn rate
			# ×1.25 · tension ×1.25² (so the first resonance keeps its place just
			# above the turn rate) · the hands' circle 0.12 → 0.1.
			# two of Skip rope's strings, y'' = k·(y₋ + y₊ − 2y) − c·y', each
			# driven at its END masses only, the second rope's hands half a turn
			# behind the first. both middles lag their hands, because the turn
			# still has to travel in. the ropes are turned faster, so they are
			# tightened by the square of that: a string's resonance goes as √k.
			b.speed = maxf(1.0, b.speed - dt * 0.5)
			var k := 148.0                 # tension (letters²/s²) and damping as a fraction of critical
			var c := 2.0 * 0.05 * sqrt(k)
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			var phase: float = b.phase
			for _s in sub:
				phase += 4.0 * b.speed * h   # the hands' turn, integrated: quicker after a press, never a jump
				var hand := sin(phase) * 0.1   # the small circle the hands make
				turn(b.ry, b.rvy, hand, k, c, h)      # the first rope
				turn(b.ry2, b.rvy2, -hand, k, c, h)   # the second, half a turn behind
			b.phase = phase
		"ripple_press":
			# dials moved: one drop → three, spaced and delayed like a skipping
			# stone · rings ×0.7 smaller and slower · each ring's kick scaled by
			# its skip's k · the pond no longer drips on its own.
			# Ripple press's spring under every letter, y'' = −k·y − c·y', and
			# three fronts instead of one: each ring kicks a letter's velocity
			# once as it reaches it — a smaller kick for a smaller splash — and
			# the kicks add to whatever the letter was already doing.
			var r: Rect2 = b.rect
			var s: float = b.base_size
			var L := TextKit.layout(b)
			var y: PackedFloat32Array = b.py
			var vy: PackedFloat32Array = b.pvy
			var k := 90.0                  # stiffness (1/s²) and damping as a fraction of critical
			var c := 2.0 * 0.15 * sqrt(k)
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			for d in b.drops:
				var was: float = d.age * r.size.x * 0.5 * d.k   # negative until the skip lands: nothing is reached
				var now: float = (d.age + dt) * r.size.x * 0.5 * d.k
				if now > 0.0:
					for l in L:            # the ring reaches a letter: one kick, this skip's size
						var dist: float = Vector2(l.cx, l.y - s * 0.3).distance_to(Vector2(d.x, d.y))
						if dist >= was and dist < now:
							vy[l.i] -= s * 2.05 * d.k * maxf(0.0, 1.0 - maxf(0.0, d.age) * 0.8)
				d.age += dt
			b.drops = b.drops.filter(func(d): return d.age < 1.4)
			for i in y.size():
				for _s in sub:
					vy[i] += (-k * y[i] - c * vy[i]) * h
					y[i] += vy[i] * h
				y[i] = clampf(y[i], -s, s)
		_:
			Base.tick(b, dt, t)

## One of Double dutch's ropes, one step: the ends are held at `hand`, the
## middle is pulled by its neighbours. Packed arrays are shared buffers, so
## this integrates the card's state in place.
static func turn(y: PackedFloat32Array, vy: PackedFloat32Array, hand: float, k: float, c: float, h: float) -> void:
	var nn := y.size()
	y[0] = hand
	y[nn - 1] = hand
	vy[0] = 0.0
	vy[nn - 1] = 0.0
	for i in range(1, nn - 1):
		vy[i] += (k * (y[i - 1] + y[i + 1] - 2.0 * y[i]) - c * vy[i]) * h
	for i in range(1, nn - 1):
		y[i] = clampf(y[i] + vy[i] * h, -1.0, 1.0)

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
			# dials moved: press kick ×2 (the squash is read off the same displacement, so it doubles with it) · the physics lives in tick
			var y: PackedFloat32Array = b.jy
			for l in TextKit.layout(b):
				var sc: float = clampf(1.0 - y[l.i] / s * 0.6, 0.6, 1.5)   # lifted = wider, dipped = taller
				n.draw_set_transform(Vector2(l.cx, l.y + y[l.i]), 0.0, Vector2(sc, 2.0 - sc))
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), s, TextKit.INK)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"pendulum":
			TextKit.stage(n, b)
			# dials moved: one shared angle for the row · the drawn angle snapped to the escapement's ticks — the rod underneath is smooth
			var a: float = roundf(b.mth / 0.04) * 0.04
			for l in TextKit.layout(b):
				n.draw_set_transform(Vector2(l.cx, l.y - s * 0.75), a, Vector2.ONE)
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, s * 0.75), s, TextKit.INK)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"buoy":
			TextKit.stage(n, b)
			# dials moved: the bob and lean come from the storm's springs in tick (the spray too)
			var y: PackedFloat32Array = b.by
			var tilt: PackedFloat32Array = b.tilt
			for l in TextKit.layout(b):
				n.draw_set_transform(Vector2(l.cx, l.y + y[l.i]), tilt[l.i], Vector2.ONE)
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), s, TextKit.INK)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for sp in b.spray:
				n.draw_rect(Rect2(Vector2(sp.x, sp.y), Vector2(1.6, 1.6)), Color(0.78, 0.88, 1.0, 0.7))
		"skip_rope":
			TextKit.stage(n, b)
			# dials moved: odd letters ride the second rope, even the first · foreshortening read off the string's own height
			var ya: PackedFloat32Array = b.ry
			var yb: PackedFloat32Array = b.ry2
			for l in TextKit.layout(b):
				var y: float = yb[l.i] if l.i % 2 == 1 else ya[l.i]
				var sy := 1.0 - minf(1.0, absf(y) / 0.34) * 0.12    # foreshortening as it turns
				n.draw_set_transform(Vector2(l.cx, l.y + y * s), 0.0, Vector2(1.0, maxf(0.5, sy)))
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), s, TextKit.INK)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"ripple_press":
			TextKit.stage(n, b)
			# dials moved: rings ×0.7 smaller (speed 0.6 → 0.5) · everything scaled by each skip's k · the bob comes from the spring in tick
			var r: Rect2 = b.rect
			var y: PackedFloat32Array = b.py
			for d in b.drops:
				if d.age < 0.0:            # this skip hasn't landed yet
					continue
				var rr: float = d.age * r.size.x * 0.5 * d.k
				n.draw_arc(Vector2(d.x, d.y), rr, 0.0, TAU, 40,
					Color(0.63, 0.75, 1.0, maxf(0.0, 0.4 - d.age * 0.33) * d.k), 1.5)
			for l in TextKit.layout(b):
				TextKit.letter(n, l.ch, Vector2(l.x, l.y + y[l.i]), s, TextKit.INK)
		_:
			Base.draw(n, b, t)
