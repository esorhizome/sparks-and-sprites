extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
## DARK & VOID — six cube effects, ported from the web codex.

const TITLE := "Dark & void"
const BLURB := "clones, veils, and hands from below"
const DEFS := [
	{ "id": "clone", "name": "Shadow clone", "hint": "a dark twin mimics it, a beat late; press sends the twin ahead" },
	{ "id": "grasp", "name": "Void grasp", "hint": "its shadow writhes; press and a dark hand rises where you click" },
	{ "id": "dark_aura", "name": "Dark aura", "hint": "purple smoke coils off it; press for the eruption" },
	{ "id": "vanish", "name": "Smoke vanish", "hint": "press: a poof of smoke — and no cube until it clears" },
	{ "id": "black_hole", "name": "Black hole", "hint": "press: a void opens ahead — motes fall in on 1/d², fastest at the lip" },
	{ "id": "veil", "name": "Night veil", "hint": "the dark closes in — light survives only near the hero" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	match b.id:
		"clone":
			b.history = []
			b.attack = -1.0
			b.ax = 0.0
		"vanish":
			b.gone = 0.0
		"grasp":
			b.D = {
				"k": 60.0,        # the wrist's rise: spring stiffness toward its target height (per unit mass)
				"damp": 0.4,      # its damping as a fraction of critical — under 1, so the rise overshoots and settles
				"reach": 1.1,     # the target height, in cube-sides
				"hold": 1.0,      # seconds the hand stays up before it is called back down
				"curl": 0.9,      # how far each finger joint curls, radians, once the hand is up
				"kj": 90.0,       # the knuckle joint's spring
				"tip": 1.5,       # the tip joint's stiffness as a multiple of the knuckle's — lighter, so quicker
				"jdamp": 0.32,    # the joints' damping as a fraction of their own critical — low: they whip
				"inertia": 0.02,  # how hard the wrist's motion flings the fingers back, rad/s² per px/s
				"dirn": -1.0,     # the hand grows this way: −1 up out of the floor, +1 down from the sky
				"col": Color(0.118, 0.07, 0.196),   # the hand's colour
				"glow": 0.0 }     # a glow at the wrist, alpha — none for a void
		"black_hole":
			b.hole = null
			b.D = {
				"Gm": 480000.0,   # the pull's strength, px³/s² — a = Gm/d², so 300 px/s² at 40 px out (negative would push)
				"dmin": 6.0,      # the 1/d² is capped below this radius, px — no infinite kick at the centre
				"tang": 0.6,      # a mote's sideways start, as a fraction of the circular-orbit speed there — under 1, so it spirals in, not round
				"drag": 0.4,      # a whisper of drag, per second — the void's medium
				"vmax": 700.0,    # a speed cap, px/s, for the coarsest frames
				"lip": 8.0,       # motes closer than this are swallowed, px
				"streak": 0.03,   # the tail drawn behind a mote is this many seconds of its velocity
				"born": 2.0 }     # motes are born within this many cube-sides of the hole

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	match b.id:
		"clone":
			if b.attack < 0.0:
				b.attack = 0.0
				b.ax = c.x
		"grasp":
			var fj := PackedFloat32Array()    # per finger: θ knuckle, its rate, θ tip, its rate
			fj.resize(20)
			b.parts.append({ "kind": "hand", "x": clampf(pos.x, r.position.x + 10, r.position.x + r.size.x - 10),
				"age": 0.0, "up": 0.0, "vup": 0.0, "fj": fj })
		"dark_aura", "veil":
			b.press_v = 1.0
		"vanish":
			b.gone = 1.0
			c.alpha = 0.0
			for i in 10:
				b.parts.append({ "pos": Vector2(c.x + randf_range(-c.s * 0.5, c.s * 0.5), c.y - randf_range(0, c.s)),
					"vel": Vector2(randf_range(-40, 40), randf_range(-50, -10)), "r": randf_range(5, 9), "life": 1.0 })
		"black_hole":
			if b.hole == null:
				b.hole = { "pos": Vector2(c.x + c.face * c.s * 2.4, c.y - c.s * 0.7), "life": 2.0 }

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	b.press_v = maxf(0.0, b.press_v - dt * (0.5 if b.id == "veil" else 1.2))
	match b.id:
		"clone":
			b.history.append({ "x": c.x, "hop": c.hop, "lean": c.lean })
			if b.history.size() > 30:
				b.history.pop_front()
			if b.attack >= 0.0:
				b.attack += dt * 1.4
				b.ax += c.face * 260.0 * dt
				if b.attack >= 1.0:
					b.attack = -1.0
		"grasp":
			# the wrist is one spring: it rises toward reach, overshoots because the
			# damping is under critical, and is called back when hold runs out. every
			# finger is a CHAIN of two joints, each a spring toward its curl — asked
			# for only once the hand is up (grip = clamp(rise)), so the fingers come
			# up straight and close a beat after the wrist arrives. a moving wrist
			# also flings them: inertia · wrist speed is a torque away from the motion
			var D: Dictionary = b.D
			var sub := maxi(1, ceili(dt * 50.0))   # the tip joint is stiff: substep coarse frames
			var h := dt / float(sub)
			var k: float = D.k
			var damp: float = float(D.damp) * 2.0 * sqrt(k)
			var kj1: float = D.kj
			var kj2: float = kj1 * float(D.tip)
			var dj1: float = float(D.jdamp) * 2.0 * sqrt(kj1)
			var dj2: float = float(D.jdamp) * 2.0 * sqrt(kj2)
			var curl: float = D.curl
			for p in b.parts:
				p.age += dt
				var target: float = 1.0 if p.age < float(D.hold) else 0.0   # up, then called home
				var fj: PackedFloat32Array = p.fj
				var up: float = p.up
				var vup: float = p.vup
				for _q in sub:
					vup += (k * (target - up) - damp * vup) * h
					up += vup * h
					var grip: float = clampf(up, 0.0, 1.0)   # the fingers curl only once the hand is up
					for f in 5:
						var i := f * 4
						var out: float = -1.0 if f < 2 else 1.0   # which way is "outward" for this finger
						var fling: float = float(D.inertia) * vup * out   # a rising wrist drags the fingertips back, i.e. outward
						fj[i + 1] += (kj1 * (-out * curl * grip - fj[i]) - dj1 * fj[i + 1] + fling) * h         # the knuckle: toward its curl
						fj[i] = clampf(fj[i] + fj[i + 1] * h, -2.2, 2.2)
						fj[i + 3] += (kj2 * (-out * curl * 1.2 * grip - fj[i + 2]) - dj2 * fj[i + 3] + fling) * h   # the tip: further, relative to the knuckle
						fj[i + 2] = clampf(fj[i + 2] + fj[i + 3] * h, -2.4, 2.4)
				p.up = up
				p.vup = vup
			b.parts = b.parts.filter(func(p): return p.age < 4.0 and not (p.age > float(D.hold) and p.up < 0.02 and absf(p.vup) < 0.05))
		"dark_aura":
			if randf() < 0.4 + b.press_v:
				b.parts.append({ "pos": Vector2(c.x + randf_range(-c.s * 0.6, c.s * 0.6), c.y - randf_range(0, c.s)),
					"r": randf_range(3, 6) * (1.0 + b.press_v), "life": 1.0 })
			for p in b.parts:
				p.pos.y -= (26.0 + b.press_v * 60.0) * dt
				p.pos.x += sin(p.pos.y * 0.15) * 10.0 * dt
				p.r += 4.0 * dt
				p.life -= dt
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"vanish":
			if b.gone > 0.0:
				b.gone -= dt * 0.8
				if b.gone <= 0.0:
					c.alpha = 1.0
					for i in 8:
						b.parts.append({ "pos": Vector2(c.x + randf_range(-c.s * 0.4, c.s * 0.4), c.y - randf_range(0, c.s)),
							"vel": Vector2(randf_range(-25, 25), randf_range(-30, -8)), "r": randf_range(4, 7), "life": 0.8 })
			elif randf() < 0.04:
				b.parts.append({ "pos": Vector2(c.x - c.face * c.s * 0.4, c.y - 4.0),
					"vel": Vector2(0, -12), "r": 3.0, "life": 0.7 })
			for p in b.parts:
				p.pos += p.vel * dt
				p.r += 6.0 * dt
				p.life -= dt * 1.1
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"black_hole":
			# gravity, honestly: a mote's acceleration is Gm/d² toward the hole,
			# capped at dmin. born with a sideways drift smaller than the circular
			# speed at its radius (tang < 1) it spirals, and because 1/d² grows as
			# it closes it moves SLOWEST far out and fastest at the lip — the
			# reverse of an ease-in. a negative Gm is the same law, pushing
			if b.hole != null:
				var D: Dictionary = b.D
				var hole: Dictionary = b.hole
				var gm: float = D.Gm
				if randf() < 0.5:
					var off := Vector2(randf_range(-c.s, c.s) * float(D.born), randf_range(-c.s, c.s) * float(D.born) * 0.5)
					var d0: float = maxf(float(D.dmin), off.length())
					var vc: float = sqrt(absf(gm) / d0) * float(D.tang)   # sideways: a fraction of the circular speed at this radius
					b.parts.append({ "pos": hole.pos + off, "vel": Vector2(-off.y, off.x) / d0 * vc, "life": 1.0 })
				c.lean = signf(hole.pos.x - c.x) * 0.12 * signf(gm)   # even the hero leans in — or away
				var sub := maxi(1, ceili(dt * 50.0))   # 1/d² is stiff near the lip: substep coarse frames
				var h := dt / float(sub)
				for p in b.parts:
					var pos: Vector2 = p.pos
					var vel: Vector2 = p.vel
					for _q in sub:
						var to: Vector2 = hole.pos - pos
						var d: float = maxf(0.001, to.length())
						var dc: float = maxf(d, float(D.dmin))
						vel += (to / d * (gm / (dc * dc)) - vel * float(D.drag)) * h   # the pull, capped, and a whisper of drag
						vel = vel.limit_length(float(D.vmax))
						pos += vel * h
						if (hole.pos - pos).length() < float(D.lip):   # swallowed
							p.life = 0.0
							break
					p.pos = pos
					p.vel = vel
					p.life -= dt * (0.6 if gm > 0.0 else 1.3)
				b.parts = b.parts.filter(func(p): return p.life > 0.0)
				hole.life -= dt
				if hole.life <= 0.0:
					b.hole = null
					b.parts = []

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	var pv: float = b.press_v
	CubeKit.stage(n, b)
	match b.id:
		"clone":
			var cx: float
			var chop: float
			var clean: float
			var alpha := 0.55
			if b.attack >= 0.0:
				cx = b.ax
				chop = 0.0
				clean = c.face * 0.2
				alpha = maxf(0.0, 1.0 - b.attack) * 0.8
			elif not b.history.is_empty():
				var past: Dictionary = b.history[0]
				cx = past.x
				chop = past.hop
				clean = past.lean
			else:
				cx = c.x
				chop = 0.0
				clean = 0.0
			n.draw_set_transform(Vector2(cx, c.y - chop), clean, Vector2.ONE)
			n.draw_rect(Rect2(-c.s / 2.0, -c.s, c.s, c.s), Color(0.094, 0.07, 0.157, alpha))
			n.draw_rect(Rect2(-c.s * 0.15, -c.s * 0.66, 2.5, 4.0), Color(0.7, 0.47, 1.0, alpha))
			n.draw_rect(Rect2(c.s * 0.1, -c.s * 0.66, 2.5, 4.0), Color(0.7, 0.47, 1.0, alpha))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			CubeKit.draw_cube(n, b)
		"grasp":
			n.draw_set_transform(Vector2(c.x + sin(t * 3.0) * 3.0, b.G + 2.0), 0.0,
				Vector2(1.0 + sin(t * 2.3) * 0.2, 0.3 + sin(t * 3.7) * 0.1))
			n.draw_circle(Vector2.ZERO, c.s * 0.6, Color(0.04, 0.024, 0.078, 0.55))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			CubeKit.draw_cube(n, b)
			var D: Dictionary = b.D
			var dirn: float = D.dirn
			var base: float = b.G if dirn < 0.0 else b.rect.position.y - 2.0
			var l1: float = c.s * 0.3
			var l2: float = c.s * 0.22
			for p in b.parts:
				var rise: float = maxf(0.0, p.up)
				var wrist := Vector2(p.x, base + dirn * c.s * float(D.reach) * rise)
				var col: Color = D.col
				col.a = minf(1.0, rise * 2.0)
				n.draw_line(Vector2(p.x, base), wrist, col, 5.0)
				var fj: PackedFloat32Array = p.fj
				for f in 5:                       # five grasping fingers: the chain, walked
					var i := f * 4
					var a1: float = (f - 2) * 0.35 + fj[i]     # fan angle + knuckle…
					var a2: float = a1 + fj[i + 2]             # …then + tip
					var p1: Vector2 = wrist + Vector2(sin(a1), dirn * cos(a1)) * l1
					var p2: Vector2 = p1 + Vector2(sin(a2), dirn * cos(a2)) * l2
					n.draw_polyline(PackedVector2Array([wrist, p1, p2]), col, 2.5)
				if float(D.glow) > 0.0:
					CubeKit.glow(n, wrist, 8.0, Color(col.r, col.g, col.b, minf(1.0, rise) * float(D.glow)), 2)
		"dark_aura":
			for p in b.parts:
				n.draw_circle(p.pos, p.r, Color(0.27, 0.118, 0.43, p.life * 0.35))
			CubeKit.draw_cube(n, b)
		"vanish":
			for p in b.parts:
				n.draw_circle(p.pos, p.r, Color(0.24, 0.22, 0.31, p.life * 0.5))
			CubeKit.draw_cube(n, b)
		"black_hole":
			CubeKit.draw_cube(n, b)
			if b.hole != null:
				var hole: Dictionary = b.hole
				var streak: float = b.D.streak
				for p in b.parts:                 # a streak along the velocity: the speed made visible
					n.draw_line(p.pos, p.pos - p.vel * streak, Color(0.67, 0.55, 0.86, p.life * 0.7), 1.5)
				n.draw_set_transform(hole.pos, 0.0, Vector2(1.0, 0.7))
				n.draw_circle(Vector2.ZERO, 9.0, Color(0.02, 0.012, 0.031))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				CubeKit.ellipse(n, hole.pos, 11.0, 7.5, Color(0.75, 0.59, 1.0, 0.7), 1.5)
		"veil":
			CubeKit.draw_cube(n, b)
			var r: Rect2 = b.rect
			var reach: float = c.s * (2.0 + pv * 1.8 + sin(t * 1.2) * 0.15)
			var ctr := Vector2(c.x, c.y - c.s * 0.5)
			# darkness as ring segments closing in around the light
			for i in 10:
				var k := i / 9.0
				var rr: float = reach + k * r.size.x * 0.5
				CubeKit.ellipse(n, ctr, rr, rr * 0.8, Color(0.02, 0.012, 0.039, 0.55 * k), 9.0, 0, TAU, 26)
