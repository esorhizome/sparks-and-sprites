extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
## WIND — six cube effects, ported from the web codex.

const TITLE := "Wind"
const BLURB := "gusts, crescents, and one personal tornado"
const DEFS := [
	{ "id": "tornado", "name": "Tornado spin", "hint": "press: it spins itself into a travelling funnel" },
	{ "id": "gust", "name": "Gust palm", "hint": "press: rings of pushed air roll forward" },
	{ "id": "cyclone_jump", "name": "Cyclone jump", "hint": "press: flung up spinning — the spin decays, the lift with it, gravity sets it down" },
	{ "id": "cloak", "name": "Wind cloak", "hint": "two cloth strips trail its every step, swinging through when it turns; press throws them forward" },
	{ "id": "air_slash", "name": "Air slash", "hint": "press: crescent blades of wind fly forward" },
	{ "id": "updraft", "name": "Updraft column", "hint": "feathers fall against drag, rocking; press: a column of lift where you click, strongest at its centre" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	match b.id:
		"tornado":
			b.storm = 0.0
		"cyclone_jump":
			# the old jump was a sine 2.2 sides tall. now the press injects a kick and
			# a spin; the spin is an angular velocity that decays (air drag on a
			# cyclone), the LIFT is proportional to it, and the height is integrated:
			# lift beats gravity at first, so it keeps climbing after the kick, then
			# the spin dies, gravity wins, and the same integrator sets it down — the
			# floor is a contact, and the impact speed becomes a squash the spring
			# resolves. the streaks are shed at a rate that follows the spin.
			b.D = { "jump": 120.0,           # the launch kick, px/s
				"g": 620.0,                  # gravity, px/s²
				"lift": 700.0,               # the cyclone's lift while it spins at full rate, px/s² — more than gravity, so it climbs
				"spin": 20.0,                # angular velocity at launch, rad/s
				"spinDecay": 2.5,            # the spin's decay rate, per second — the lift fades with it, and gravity wins
				"squashK": 400.0,            # the landing squash's spring stiffness
				"squashDamp": 0.35,          # its damping as a fraction of critical — under 1, so it rebounds into a stretch
				"squashKick": 0.05 }         # squash velocity bought per px/s of landing speed
			b.vy = 0.0
			b.omega = 0.0
			b.air = false
			b.sqv = 0.0
		"cloak":
			# the old cloak was four ellipse arcs on the clock. now it is cloth: two
			# short Grass chains hung from the shoulders. the root's rest angle
			# streams back with the hero's velocity (air drag), every joint chases
			# the one above on its own under-damped spring, and each joint also feels
			# the shoulder's ACCELERATION — a pendulum in an accelerating frame gets
			# the torque −a·cos θ / L — so when the hero turns, the strips fly across
			# and the hem lags and whips through. the deflect is an impulse, forward.
			b.D = { "joints": 4,             # segments per strip
				"len": 0.32,                 # each segment's length, in cube-sides
				"k": 120.0,                  # the root spring's stiffness — thin cloth answers quickly
				"damp": 0.45,                # the root's damping as a fraction of critical
				"tip": 1.3,                  # each joint's k as a multiple of the one below
				"tipdamp": 0.35,             # a joint's damping as a fraction of ITS OWN critical — the hem overshoots
				"bend": 1.0,                 # the most a joint can fold past the one below, radians
				"stream": 0.8,               # how far 40 px/s of travel streams the strips back, radians
				"inertia": 1.0,              # how much of the shoulder's acceleration the cloth feels (0 = weightless)
				"flare": 7.0 }               # the deflect press's forward impulse on every joint, rad/s
			var J: int = b.D.joints
			var th := PackedFloat32Array()   # strip-major: [side * J + j], world angles from straight-down toward +x
			var om := PackedFloat32Array()
			th.resize(2 * J)
			om.resize(2 * J)
			b.th = th
			b.om = om
			b.prev_vx = b.cub.vx
		"updraft":
			# the old feather fell at 26 px/s, flipped to −110 the instant it entered
			# a column, and swayed on a sine. now it has velocities and forces: it
			# falls until drag balances gravity (a terminal speed, reached on a curve),
			# a rocking angle on a spring is coupled to its side-slip both ways — tilt
			# makes it glide, gliding tilts it back — and random torque kicks stand in
			# for the vortices a real feather sheds. the column is a lift force that
			# ramps with distance from its centre, so entering it is a curve too.
			b.D = { "g": 52.0,               # gravity on a feather, px/s²
				"drag": 2.0,                 # vertical drag per unit speed — the terminal speed is g/drag = 26 px/s
				"sideDrag": 1.6,             # the same for sideways motion
				"slip": 120.0,               # how hard a tilted feather glides sideways, px/s² per radian
				"rockK": 30.0,               # the rocking spring — a feather's centre of lift is above its weight, so it rights itself
				"rockDamp": 1.0,             # its damping as a fraction of critical
				"couple": 0.15,              # how much side-slip tilts the feather back (the glide's own lift), rad/s² per px/s
				"turb": 4.0,                 # vortex-shedding kicks, rad/s² — the rocking is real, its timing random
				"lift": 220.0,               # the column's lift at its centre, px/s² — well past gravity, so feathers rise
				"radius": 16.0 }             # the column's half-width, px — the lift ramps to nothing at its edge
			b.feathers = []

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	match b.id:
		"tornado":
			if b.storm <= 0.0:
				b.storm = 1.0
				c.pace = false
				c.vx = c.face * 160.0
		"gust":
			for i in 3:
				b.parts.append({ "kind": "ring", "x": c.x + c.face * c.s * 0.7, "dir": c.face,
					"r": 5.0 + i * 3.0, "delay": i * 0.08, "life": 1.0 })
		"cyclone_jump":
			if not b.air:
				b.air = true
				b.vy = -float(b.D.jump)
				b.omega = c.face * float(b.D.spin)
		"cloak":
			b.press_v = 1.0
			var om: PackedFloat32Array = b.om
			var flare: float = b.D.flare
			for i in om.size():
				om[i] += c.face * flare                  # thrown forward, all at once
		"air_slash":
			for i in 2:
				b.parts.append({ "kind": "blade", "pos": Vector2(c.x + c.face * c.s * 0.6, c.y - c.s * 0.55 + i * 8.0 - 4.0),
					"dir": c.face, "delay": i * 0.1, "life": 1.0 })
		"updraft":
			b.parts.append({ "kind": "column", "x": clampf(pos.x, r.position.x + 10, r.position.x + r.size.x - 10), "life": 1.6 })

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	b.press_v = maxf(0.0, b.press_v - dt * 1.4)
	match b.id:
		"tornado":
			if b.storm > 0.0:
				b.storm -= dt * 0.7
				c.spin += dt * 22.0
				if c.x < r.position.x + c.s or c.x > r.position.x + r.size.x - c.s:
					c.vx = -c.vx
				if b.storm <= 0.0:
					c.pace = true
					c.spin = 0.0
					c.vx = 0.0
		"gust", "air_slash":
			for p in b.parts:
				p.delay -= dt
				if p.delay > 0.0:
					continue
				if p.kind == "ring":
					p.x += p.dir * 190.0 * dt
					p.r += 30.0 * dt
					p.life -= dt * 1.6
				else:
					p.pos.x += p.dir * 260.0 * dt
					p.life -= dt * 1.2
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"cyclone_jump":
			var D: Dictionary = b.D
			if b.air:
				var spin_frac: float = absf(b.omega) / float(D.spin)
				b.vy += (float(D.g) - float(D.lift) * spin_frac) * dt
				c.y = maxf(r.position.y - c.s * 3.0, c.y + b.vy * dt)
				b.omega -= b.omega * minf(1.0, float(D.spinDecay) * dt)
				c.spin += b.omega * dt
				for i in 2:                              # the corkscrew written in streaks, shed as fast as it spins
					if randf() < spin_frac:
						var a: float = c.spin * 3.0 + i * PI
						b.parts.append({ "kind": "streak", "pos": Vector2(c.x + cos(a) * c.s * 0.8, c.y - randf_range(0, c.s)), "life": 0.5 })
				if c.y >= b.G:                           # set down: the floor stops the spin, and the impact becomes squash velocity
					c.y = b.G
					b.air = false
					c.spin = 0.0
					b.omega = 0.0
					b.sqv += b.vy * float(D.squashKick)
					b.vy = 0.0
			var sk: float = D.squashK
			var sd: float = float(D.squashDamp) * 2.0 * sqrt(sk)
			var sub := maxi(1, ceili(dt * 50.0))   # the spring's substep guard
			var h := dt / float(sub)
			for _s in sub:
				b.sqv += (sk * (0.0 - c.squash) - sd * b.sqv) * h
				c.squash = clampf(c.squash + b.sqv * h, -0.5, 0.5)
			for p in b.parts:
				p.pos.y -= 30.0 * dt
				p.life -= dt * 1.8
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"cloak":
			var D: Dictionary = b.D
			var J: int = D.joints
			var th: PackedFloat32Array = b.th
			var om: PackedFloat32Array = b.om
			var L: float = c.s * float(D.len)
			var ax: float = clampf((c.vx - b.prev_vx) / maxf(dt, 0.0001), -2000.0, 2000.0)   # the shoulder's acceleration
			b.prev_vx = c.vx
			var kk: float = D.k
			var damp: float = D.damp
			var tip: float = D.tip
			var tipdamp: float = D.tipdamp
			var bend: float = D.bend
			var stream: float = D.stream
			var inertia: float = D.inertia
			var sub := maxi(1, ceili(dt * 50.0))   # stiff joints: substeps of ≤ 0.02 s
			var h := dt / float(sub)
			for side in 2:
				var rest: float = clampf(-c.vx / 40.0 * stream, -1.3, 1.3) + (side * 2 - 1) * 0.15   # streamed back, hung a little outward
				for _s in sub:
					var below := rest
					var kj := kk
					var dj := damp * 2.0 * sqrt(kk)
					for j in J:
						var i := side * J + j
						if j > 0:
							kj *= tip
							dj = tipdamp * 2.0 * sqrt(kj)
						om[i] += (kj * (below - th[i]) - dj * om[i] - inertia * ax / L * cos(th[i])) * h
						var a: float = th[i] + om[i] * h
						if j > 0:
							a = clampf(a, below - bend, below + bend)
						th[i] = clampf(a, -2.5, 2.5)
						below = th[i]
		"updraft":
			var D: Dictionary = b.D
			if randf() < 0.03:                           # a feather, falling as feathers do
				b.feathers.append({ "pos": Vector2(randf_range(r.position.x + 10, r.position.x + r.size.x - 10),
					r.position.y - 4.0), "vel": Vector2.ZERO, "phi": randf_range(-0.4, 0.4), "om": 0.0 })
			var g: float = D.g
			var drag: float = D.drag
			var side_drag: float = D.sideDrag
			var slip: float = D.slip
			var rock_k: float = D.rockK
			var rock_d: float = float(D.rockDamp) * 2.0 * sqrt(rock_k)
			var couple: float = D.couple
			var turb: float = D.turb
			var lift_max: float = D.lift
			var radius: float = D.radius
			var sub := maxi(1, ceili(dt * 50.0))   # the rocking spring's substep guard
			var h := dt / float(sub)
			for f in b.feathers:
				var lift := 0.0
				for p in b.parts:                        # the column argues with gravity, harder near its centre
					var q: float = absf(f.pos.x - p.x) / radius
					if q < 1.0 and p.life > 0.0:
						var l: float = lift_max * (1.0 - q * q)
						if absf(l) > absf(lift):
							lift = l                         # the strongest column wins, whichever sign it has
				for _s in sub:
					f.vel.y += (g - lift - drag * f.vel.y) * h
					f.vel.x += (slip * f.phi - side_drag * f.vel.x) * h
					f.om += (-rock_k * f.phi - rock_d * f.om + couple * f.vel.x + randf_range(-1.0, 1.0) * turb / sqrt(h)) * h
					f.phi = clampf(f.phi + f.om * h, -1.4, 1.4)
					f.pos += f.vel * h
			b.feathers = b.feathers.filter(func(f): return f.pos.y > r.position.y - 12.0 and f.pos.y < b.G and f.pos.x > r.position.x - 20.0 and f.pos.x < r.position.x + r.size.x + 20.0)
			for p in b.parts:
				p.life -= dt * 0.7
			b.parts = b.parts.filter(func(p): return p.life > 0.0)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	var pv: float = b.press_v
	CubeKit.stage(n, b)
	CubeKit.draw_cube(n, b)
	match b.id:
		"tornado":
			if b.storm > 0.0:
				for i in 8:
					var k := i / 7.0
					var y: float = c.y - k * c.s * 1.9
					var rr: float = (c.s * 0.4 + k * c.s * 0.8)
					var a: float = t * 12.0 + i
					CubeKit.ellipse(n, Vector2(c.x + sin(t * 4.0 + k * 5.0) * 2.0, y), rr, rr * 0.3,
						Color(0.75, 0.8, 0.88, (0.5 - k * 0.2) * minf(1.0, b.storm * 2.0)), 1.6, a, a + 3.6, 10)
			elif randf() < 0.1:
				var y2: float = randf_range(b.G - r.size.y * 0.5, b.G - 6.0)
				var x2: float = randf_range(r.position.x, r.position.x + r.size.x * 0.7)
				n.draw_line(Vector2(x2, y2), Vector2(x2 + 24.0, y2 - 2.0), Color(0.7, 0.76, 0.86, 0.25), 1.0)
		"gust":
			if absf(c.vx) > 15.0 and randf() < 0.3:
				n.draw_line(Vector2(c.x - c.face * c.s * 0.5, c.y - randf_range(4, c.s * 0.8)),
					Vector2(c.x - c.face * (c.s * 0.5 + 10.0), c.y - randf_range(4, c.s * 0.8)),
					Color(0.75, 0.8, 0.88, 0.3), 1.0)
			for p in b.parts:
				if p.delay <= 0.0:
					CubeKit.ellipse(n, Vector2(p.x, c.y - c.s * 0.55), p.r * 0.4, p.r,
						Color(0.8, 0.85, 0.92, p.life * 0.6), 2.0)
		"cyclone_jump":
			for p in b.parts:
				n.draw_line(p.pos - Vector2(5, 0), p.pos + Vector2(5, -2), Color(0.78, 0.84, 0.92, p.life), 1.4)
		"cloak":
			var J: int = b.D.joints
			var L: float = c.s * float(b.D.len)
			var th: PackedFloat32Array = b.th
			for side in 2:                               # each strip: a band along its chain
				var pt := Vector2(c.x + (side * 2 - 1) * c.s * 0.42, c.y - c.s * 0.92 - c.hop)
				var left := PackedVector2Array()
				var right := PackedVector2Array()
				for j in J:
					var a: float = th[side * J + j]
					var nrm := Vector2(cos(a), -sin(a)) * 2.2    # the segment's normal, half a strip wide
					left.append(pt - nrm)
					right.append(pt + nrm)
					pt += Vector2(sin(a), cos(a)) * L
				left.append(pt)
				right.reverse()
				left.append_array(right)
				if not Geometry2D.triangulate_polygon(left).is_empty():   # a strip can fold on itself for a frame mid-whip
					n.draw_colored_polygon(left, Color(0.76, 0.82, 0.91, 0.45 + pv * 0.4))
		"air_slash":
			n.draw_line(Vector2(c.x - c.face * c.s * 0.45 - 4.0, c.y - c.s * 0.4),
				Vector2(c.x - c.face * c.s * 0.45 + 4.0, c.y - c.s * 0.44),
				Color(0.82, 0.88, 0.94, 0.3 + sin(t * 4.0) * 0.15), 1.5)
			for p in b.parts:
				if p.delay <= 0.0:
					var a0: float = -0.9 if p.dir > 0 else PI - 0.9
					CubeKit.ellipse(n, p.pos - Vector2(p.dir * 8.0, 0), 11.0, 11.0,
						Color(0.84, 0.89, 0.96, p.life * 0.9), 2.5, a0, a0 + 1.8, 10)
		"updraft":
			for f in b.feathers:
				n.draw_set_transform(f.pos, f.phi, Vector2(1.0, 0.37))   # the rocking angle the spring gave it
				n.draw_circle(Vector2.ZERO, 3.5, Color(0.9, 0.92, 0.96, 0.8))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for p in b.parts:
				for i in 3:
					var x: float = p.x + sin(t * 8.0 + i * 2.0) * 6.0
					var y: float = b.G - fmod(t * 130.0 + i * 40.0, (b.G - r.position.y) * 0.8)
					n.draw_line(Vector2(x, y), Vector2(x + 2.0, y - 12.0),
						Color(0.78, 0.84, 0.92, minf(1.0, p.life) * 0.4), 1.4)
