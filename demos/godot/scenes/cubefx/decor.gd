extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
## DECORATIONS — six cube effects, ported from the web codex.

const TITLE := "Decorations"
const BLURB := "butterflies, lanterns, petals — the stage dressed kindly"
const DEFS := [
	{ "id": "butterflies", "name": "Butterflies", "hint": "three companions steer for a spot near the hero, overshooting; wings beat faster the faster they fly; press scatters" },
	{ "id": "lanterns", "name": "Floating lanterns", "hint": "lanterns climb the night; press to release a fresh batch" },
	{ "id": "petals", "name": "Petal fall", "hint": "cherry petals cross the stage; press for a spiral flurry" },
	{ "id": "fireflies", "name": "Fireflies at dusk", "hint": "they gather near whoever stands still; press = one shared flash" },
	{ "id": "cape", "name": "Hero's cape", "hint": "a seven-hinge cape streams back with its speed, lags and swings through when it turns; press: the wind machine" },
	{ "id": "stage_rain", "name": "Stage rain", "hint": "rain over everything, honestly bouncing off the hero" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	var r: Rect2 = b.rect
	match b.id:
		"butterflies":
			# the old flies lerped toward a target plus a sine, and scattered by a
			# negative lerp. now each has a velocity: a steering force toward the
			# spot it fancies (which wanders slowly round the hero), drag, and a
			# random flutter force, so they overshoot the spot and jitter round it
			# the way flies do. the scatter is an impulse away from the hero, after
			# which they simply stop steering until they forgive; the wings beat at
			# a rate that follows the speed the physics gives them.
			b.D = { "k": 6.0,                # the steering force per px of distance to the fancied spot
				"drag": 2.2,                 # air drag per unit speed — with k it is under-damped, so they overshoot
				"flutter": 60.0,             # the random force that keeps them from ever flying straight, px/s²
				"scatter": 140.0,            # the press's outward shove, px/s
				"up": 60.0,                  # and its upward part, px/s
				"flapBase": 8.0,             # wingbeat rate at rest, rad/s
				"flapPer": 0.25,             # extra wingbeat rate per px/s of speed, rad/s
				"wander": 0.8,               # how fast the fancied spot wanders round the hero, rad/s
				"forgive": 0.5 }             # how fast the panic fades, per second
			b.flies = []
			for i in 3:
				b.flies.append({ "pos": r.position + Vector2(randf_range(0, r.size.x), randf_range(14, 50)),
					"vel": Vector2.ZERO, "ph": randf_range(0, 9), "wa": randf_range(0, TAU), "panic": 0.0, "hue": [0.92, 0.12, 0.55][i] })
		"lanterns":
			for i in 4:
				b.parts.append({ "pos": Vector2(randf_range(r.position.x + 14, r.position.x + r.size.x - 14),
					b.G - randf_range(0, 24)), "ph": randf_range(0, 9), "life": 1.0 })
		"petals":
			b.D = {
				"g": 60.0,        # gravity, px/s² — light, because a petal is mostly air
				"drag": 2.7,      # air drag, per second: terminal speed is g/drag ≈ 22 px/s
				"wind": 14.0,     # the breeze the petals ride, px/s, left to right
				"lift": 0.5,      # a tilted petal slips sideways: lateral push per radian of tilt per px/s of fall
				"kt": 12.0,       # the tilt spring: the air rights a petal toward flat (stiffness per unit inertia)
				"kd": 0.6,        # the tilt's damping — low, so the rocking rings for a few swings
				"couple": 0.25,   # sideways motion tips a petal into it (the see-saw's other half), rad/s² per px/s
				"gust": 90.0,     # turbulence: random sideways kicks, px/s² — what keeps the rocking alive
				"swirl": 200.0,   # the press: tangential push round the hero, px/s²
				"pull": 120.0,    # the press: the whirl's inward push, px/s²
				"born": 0.15,     # petals per frame, idle…
				"burst": 0.5 }    # …and extra during the flurry
		"fireflies":
			b.D = {
				"wander": 60.0,   # the wandering push, px/s² — always on, in a direction that random-walks
				"jitter": 4.0,    # how fast that heading wanders, rad/√s
				"attract": 1.0,   # the pull home, sideways: px/s² per px of offset — weak, so home is a neighbourhood, not a point
				"attractY": 1.0,  # the pull home, vertically — the same, unless the air is rising
				"rise": 0.0,      # buoyancy, px/s² upward — none for a firefly
				"drag": 1.5,      # air drag, per second: cruising speed is wander/drag = 40 px/s
				"fire": false }   # home is the hero (false) or a campfire on the floor (true)
			b.flies = []
			for i in 8:
				b.flies.append({ "pos": r.position + Vector2(randf_range(0, r.size.x), randf_range(14, 70)),
					"vel": Vector2.ZERO, "wa": randf_range(0, TAU),
					"ph": randf_range(0, TAU), "sp": randf_range(0.6, 1.3), "wx": randf_range(0, 9) })
		"cape":
			# this is the stagecraft Grass blade, hung from a shoulder instead of
			# planted in the ground: a chain of angles, the root a damped spring
			# toward a rest that the wind decides (the hero's own speed, plus the
			# gust), every joint below chasing the one above on its own quicker,
			# under-damped spring. two things the old lerp-plus-sine could not do
			# now come for free: the hem LAGS the clasp and whips through it when
			# the hero turns (the joints are lighter than the root), and the cape
			# feels the clasp's acceleration — a pendulum in an accelerating frame
			# gets the torque −a·cos θ / L — so a sudden stop throws it forward.
			# the flutter is turbulence: random torque kicks, more in the gust.
			b.D = { "joints": 7,             # segments in the cape
				"len": 0.3,                  # each segment's length, in cube-sides
				"k": 90.0,                   # the root spring's stiffness — the clasp end answers this fast
				"damp": 0.5,                 # the root's damping as a fraction of critical
				"tip": 1.3,                  # each joint's k as a multiple of the one below: lighter cloth toward the hem
				"tipdamp": 0.45,             # a joint's damping as a fraction of ITS OWN critical — under 1, so the hem overshoots
				"bend": 0.9,                 # the most a joint can fold past the one above, radians
				"stream": 0.8,               # how far 40 px/s of travel streams the cape back, radians
				"hang": 0.15,                # the resting lean behind it even standing still, radians
				"inertia": 1.0,              # how much of the clasp's acceleration the cloth feels (0 = weightless)
				"gustLean": 0.9,             # how far the wind machine's gust pushes the rest angle, radians
				"kick": 5.0,                 # the press's impulse on every joint, rad/s
				"turb": 3.0 }                # turbulence: random torque kicks, rad/s² — stronger in the gust
			var J: int = b.D.joints
			var th := PackedFloat32Array()   # world angles from straight-down toward +x, and their rates
			var om := PackedFloat32Array()
			th.resize(J)
			om.resize(J)
			b.th = th
			b.om = om
			b.prev_vx = b.cub.vx
		"stage_rain":
			b.rain = []

static func press(b: Dictionary, _pos: Vector2) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"butterflies":
			for f in b.flies:
				f.panic = 1.0
				var d: Vector2 = f.pos - Vector2(c.x, c.y - c.s * 0.5)
				var dist: float = maxf(1.0, d.length())
				f.vel += d / dist * float(b.D.scatter) + Vector2(0.0, -float(b.D.up))   # shoved away, and up
		"lanterns":
			for i in 3:
				b.parts.append({ "pos": Vector2(c.x + randf_range(-6, 6), c.y - c.s),
					"ph": randf_range(0, 9), "life": 1.0 })
		"cape":
			b.press_v = 1.4                                  # the gust
			var om: PackedFloat32Array = b.om
			var kick: float = b.D.kick
			for j in om.size():
				om[j] += -c.face * kick                      # the wind machine's shove, all along the cloth
		"petals", "fireflies", "stage_rain":
			b.press_v = 1.4

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	b.press_v = maxf(0.0, b.press_v - dt)
	match b.id:
		"butterflies":
			var D: Dictionary = b.D
			var kk: float = D.k
			var drag: float = D.drag
			var flutter: float = D.flutter
			for f in b.flies:
				f.panic = maxf(0.0, f.panic - dt * float(D.forgive))
				f.wa += float(D.wander) * dt
				var target := Vector2(c.x + cos(f.wa) * c.s * 1.6, c.y - c.s * 1.2 + sin(f.wa * 1.6 + f.ph) * 14.0)
				var seek: float = 0.0 if f.panic > 0.0 else kk   # no steering while it panics — just drag and flutter
				f.vel += (seek * (target - f.pos) - drag * f.vel
					+ Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * flutter) * dt
				var sp: float = f.vel.length()
				if sp > 400.0:
					f.vel *= 400.0 / sp
				f.pos += f.vel * dt
				if f.pos.y < r.position.y + 8.0:             # the stage edges: soft bounces
					f.pos.y = r.position.y + 8.0
					f.vel.y = absf(f.vel.y) * 0.5
				if f.pos.y > b.G - 8.0:
					f.pos.y = b.G - 8.0
					f.vel.y = -absf(f.vel.y) * 0.5
				if f.pos.x < r.position.x + 4.0:
					f.pos.x = r.position.x + 4.0
					f.vel.x = absf(f.vel.x) * 0.5
				if f.pos.x > r.position.x + r.size.x - 4.0:
					f.pos.x = r.position.x + r.size.x - 4.0
					f.vel.x = -absf(f.vel.x) * 0.5
				f.ph += (float(D.flapBase) + sp * float(D.flapPer)) * dt   # the wings beat as fast as it flies
		"lanterns":
			for p in b.parts:
				p.pos.y -= 14.0 * dt
				p.pos.x += sin(t * 0.7 + p.ph) * 8.0 * dt
				if p.pos.y < r.position.y + 12.0:
					p.life -= dt
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"petals":
			# a petal falls at terminal speed because drag balances gravity, and it
			# ROCKS because of a two-way coupling: a tilted petal slips sideways
			# through the air (lift · θ · fall speed) and slipping sideways tips it
			# the other way (couple · vx) while the air flattens it (kt) — a lightly
			# damped oscillator, kept ringing by turbulence. the flurry is two
			# forces, one tangential and one inward, bounded by the same drag; when
			# the press dies gravity has the petals again, mid-swing
			var D: Dictionary = b.D
			if randf() < float(D.born) + (float(D.burst) if b.press_v > 0.0 else 0.0):
				b.parts.append({ "pos": Vector2(randf_range(r.position.x - 10, r.position.x + r.size.x), r.position.y),
					"vel": Vector2(float(D.wind), 0.0), "th": randf_range(-0.4, 0.4), "om": 0.0 })   # tilt θ and its rate
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			var ctr := Vector2(c.x, c.y - c.s)             # the whirl's eye: the hero's head
			for p in b.parts:
				var gx: float = randf_range(-1.0, 1.0) * float(D.gust)   # this frame's turbulence
				var pos: Vector2 = p.pos
				var vel: Vector2 = p.vel
				var th: float = p.th
				var om: float = p.om
				for _q in sub:
					var acc := Vector2(-float(D.drag) * (vel.x - float(D.wind)) - float(D.lift) * th * vel.y + gx,   # drag toward the breeze, the tilt's slip, the gust
						float(D.g) - float(D.drag) * vel.y)
					if b.press_v > 0.0:                    # the whirl: tangential + inward, both bounded by the drag
						var d: Vector2 = pos - ctr
						var dl: float = maxf(4.0, d.length())
						acc += Vector2(-d.y, d.x) / dl * float(D.swirl) - d / dl * float(D.pull)
					om += (-float(D.kt) * th - float(D.kd) * om + float(D.couple) * vel.x) * h   # the tilt: righted by the air, tipped by the slip
					th = clampf(th + om * h, -2.0, 2.0)
					vel += acc * h
					pos += vel * h
				p.pos = pos
				p.vel = vel
				p.th = th
				p.om = om
			b.parts = b.parts.filter(func(p): return p.pos.y < b.G and p.pos.x < r.position.x + r.size.x + 14.0 and p.pos.x > r.position.x - 20.0)
		"fireflies":
			# a firefly is a velocity under three forces: a constant-size WANDER whose
			# direction random-walks (so it meanders rather than jitters), a weak
			# spring toward its home spot, and drag. wander against drag sets the
			# cruise; wander against attract sets how far it strays. no lerp: when
			# the hero moves, the homes move, and the flies bank round after them
			var D: Dictionary = b.D
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			var fire: bool = D.fire
			var anchor := Vector2(r.get_center().x, b.G - 4.0) if fire else Vector2(c.x, c.y - c.s)   # home: the hero, or the campfire
			for f in b.flies:
				var home: Vector2 = anchor + Vector2(sin(f.wx * 3.0) * c.s * 2.0, 0.0 if fire else cos(f.wx * 2.0) * c.s)
				var pos: Vector2 = f.pos
				var vel: Vector2 = f.vel
				var wa: float = f.wa
				for _q in sub:
					wa += randf_range(-1.0, 1.0) * float(D.jitter) * sqrt(h)   # the heading random-walks
					vel.x += (cos(wa) * float(D.wander) + (home.x - pos.x) * float(D.attract) - float(D.drag) * vel.x) * h
					vel.y += (sin(wa) * float(D.wander) + (home.y - pos.y) * float(D.attractY) - float(D.rise) - float(D.drag) * vel.y) * h
					pos += vel * h
				if pos.y > b.G - 4.0:                     # the floor: it pulls up
					pos.y = b.G - 4.0
					vel.y = -absf(vel.y) * 0.5
				if float(D.rise) > 0.0 and pos.y < r.position.y + 10.0:   # off the top: born again at the fire
					pos = anchor + Vector2(randf_range(-8, 8), randf_range(-4, 0))
					vel = Vector2.ZERO
				pos.x = clampf(pos.x, r.position.x + 4.0, r.position.x + r.size.x - 4.0)
				f.pos = pos
				f.vel = vel
				f.wa = wa
		"cape":
			var D: Dictionary = b.D
			var J: int = D.joints
			var th: PackedFloat32Array = b.th
			var om: PackedFloat32Array = b.om
			var L: float = c.s * float(D.len)
			var gust: float = b.press_v
			var ax: float = clampf((c.vx - b.prev_vx) / maxf(dt, 0.0001), -2000.0, 2000.0)   # the clasp's acceleration
			b.prev_vx = c.vx
			var rest: float = -c.face * minf(1.4, float(D.hang) + absf(c.vx) / 40.0 * float(D.stream) + gust * float(D.gustLean))   # streamed behind
			var kk: float = D.k
			var damp: float = D.damp
			var tip: float = D.tip
			var tipdamp: float = D.tipdamp
			var bend: float = D.bend
			var inertia: float = D.inertia
			var turb: float = D.turb
			var sub := maxi(1, ceili(dt * 50.0))   # stiff joints: substeps of ≤ 0.02 s
			var h := dt / float(sub)
			for _s in sub:
				var above := rest
				var kj := kk
				var dj := damp * 2.0 * sqrt(kk)
				for j in J:
					if j > 0:
						kj *= tip                            # quicker with every joint down the cloth (lighter, same bend)
						dj = tipdamp * 2.0 * sqrt(kj)        # a fraction of THIS joint's critical damping
					om[j] += (kj * (above - th[j]) - dj * om[j] - inertia * ax / L * cos(th[j])
						+ randf_range(-1.0, 1.0) * turb * (1.0 + gust * 2.0) / sqrt(h)) * h
					var a: float = th[j] + om[j] * h
					if j > 0:
						a = clampf(a, above - bend, above + bend)
					th[j] = clampf(a, -2.6, 2.6)
					above = th[j]
		"stage_rain":
			if randf() < 0.3 + (0.6 if b.press_v > 0.0 else 0.0):
				b.rain.append({ "pos": Vector2(randf_range(r.position.x, r.position.x + r.size.x), r.position.y) })
			for rd in b.rain:
				rd.pos.y += 230.0 * dt
				if rd.pos.y >= c.y - c.s and rd.pos.y < c.y and absf(rd.pos.x - c.x) < c.s * 0.5:
					b.parts.append({ "pos": Vector2(rd.pos.x, c.y - c.s),
						"vel": Vector2(randf_range(-40, 40), randf_range(-70, -30)), "life": 0.5 })
					rd.pos.y = 1e9
				elif rd.pos.y >= b.G:
					if randf() < 0.3:
						b.parts.append({ "pos": Vector2(rd.pos.x, b.G),
							"vel": Vector2(randf_range(-20, 20), randf_range(-40, -15)), "life": 0.4 })
					rd.pos.y = 1e9
			b.rain = b.rain.filter(func(rd): return rd.pos.y < 1e8)
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += 300.0 * dt
				p.life -= dt * 2.0
			b.parts = b.parts.filter(func(p): return p.life > 0.0)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	CubeKit.stage(n, b)
	match b.id:
		"butterflies":
			CubeKit.draw_cube(n, b)
			for f in b.flies:
				var flap: float = sin(f.ph) * 0.8            # the wingbeat phase the tick advanced at its own speed
				for side in [-1.0, 1.0]:
					n.draw_set_transform(f.pos + Vector2(side * 2.4, 0), side * flap, Vector2(1.0, (1.6 + absf(flap)) / 3.0))
					n.draw_circle(Vector2.ZERO, 3.0, Color.from_hsv(f.hue, 0.5, 0.95, 0.9))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"lanterns":
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				CubeKit.glow(n, p.pos, 8.0, Color(1, 0.71, 0.35, minf(1.0, p.life) * 0.5), 2)
				n.draw_rect(Rect2(p.pos - Vector2(2.5, 4.0), Vector2(5, 7)), Color(1, 0.59, 0.27, minf(1.0, p.life) * 0.85))
		"petals":
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				n.draw_set_transform(p.pos, p.th, Vector2(1.0, 0.6))   # the rocking IS the drawn tilt
				n.draw_circle(Vector2.ZERO, 2.6, Color(1, 0.75, 0.82, 0.85))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"fireflies":
			CubeKit.draw_cube(n, b)
			for f in b.flies:
				var blink: float = pow(maxf(0.0, sin(t * f.sp * 2.0 + f.ph)), 3.0)
				blink = maxf(blink, b.press_v)
				if blink > 0.05:
					CubeKit.glow(n, f.pos, 4.0, Color(0.86, 1.0, 0.55, blink * 0.8), 2)
		"cape":
			var J: int = b.D.joints
			var L: float = c.s * float(b.D.len)
			var th: PackedFloat32Array = b.th
			var pt := Vector2(c.x - c.face * c.s * 0.45, c.y - c.s * 0.9 - c.hop)   # the clasp at its shoulder
			var left := PackedVector2Array()              # the cape as a band along its chain, widening to the hem
			var right := PackedVector2Array()
			for j in J:
				var a: float = th[j]
				var nrm := Vector2(cos(a), -sin(a)) * (2.5 + j * 0.6)
				left.append(pt - nrm)
				right.append(pt + nrm)
				pt += Vector2(sin(a), cos(a)) * L
			var hem := Vector2(cos(th[J - 1]), -sin(th[J - 1])) * (2.5 + J * 0.6)
			left.append(pt - hem)
			right.append(pt + hem)
			right.reverse()
			left.append_array(right)
			# the band can fold over itself for a frame mid-whip (the hem lags the
			# clasp through a turn), which fails triangulation — ask the same
			# triangulator first and skip the frame rather than log an error.
			if not Geometry2D.triangulate_polygon(left).is_empty():
				n.draw_colored_polygon(left, Color(0.67, 0.196, 0.27, 0.9))
			CubeKit.draw_cube(n, b)
		"stage_rain":
			CubeKit.draw_cube(n, b)
			for rd in b.rain:
				n.draw_line(rd.pos - Vector2(0, 6), rd.pos, Color(0.59, 0.7, 0.84, 0.5), 1.0)
			for p in b.parts:
				n.draw_rect(Rect2(p.pos, Vector2(1.6, 1.6)), Color(0.7, 0.82, 0.94, p.life))
