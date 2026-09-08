extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
## WATER ATTACKS — eight cube effects, ported from the web codex.

const TITLE := "Water attacks"
const BLURB := "hoses, geysers, and shields made of bubbles"
const DEFS := [
	{ "id": "waterhose", "name": "Waterhose", "hint": "it drips politely; press for the arcing jet" },
	{ "id": "bubble_shield", "name": "Bubble shield", "hint": "a shimmering bubble around it; press to pop and reform" },
	{ "id": "splash_stomp", "name": "Splash stomp", "hint": "press: a real jump — gravity lands it, the landing squashes it, rings cross the wet floor" },
	{ "id": "rain_pet", "name": "Rain cloud pet", "hint": "a loyal cloud on a spring tether — it overshoots every turn; press: downpour (it sags)" },
	{ "id": "water_whip", "name": "Water whip", "hint": "a ten-joint chain hangs from its fist; press swings the arm — the crack falls out of the chain" },
	{ "id": "geyser", "name": "Geyser", "hint": "the ground bubbles somewhere; press to erupt it where you click" },
	{ "id": "mist_veil", "name": "Mist veil", "hint": "fog clings to it; press to vanish into the mist a moment" },
	{ "id": "tidal_push", "name": "Tidal push", "hint": "press: a wall of water rolls forward off the stage" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	match b.id:
		"bubble_shield":
			b.up = 1.0
			b.reform = 0.0
		"splash_stomp":
			# the hop is Double jump's integrator: the press injects an upward velocity,
			# gravity integrates it back down, and the floor is a real contact. the
			# landing hands its speed to a squash spring (c.squash, scaled about the
			# feet by the kit) — wide and short on impact, then an under-damped rebound
			# through tall and thin — so the follow-through is the physics settling.
			b.D = { "jump": 195.0,           # launch speed, px/s — the peak is jump²/2g, about 1.4 cube-sides
				"g": 620.0,                  # gravity, px/s² (Double jump's)
				"squashK": 400.0,            # the landing squash's spring stiffness
				"squashDamp": 0.35,          # its damping as a fraction of critical — under 1, so it rebounds into a stretch
				"squashKick": 0.05 }         # squash velocity bought per px/s of landing speed
			b.vy = 0.0
			b.air = false
			b.sqv = 0.0
		"rain_pet":
			# the old cloud lerped toward the hero — a first-order chase that can never
			# overshoot. a loyal pet has momentum: a mass on a spring tether. when the
			# hero turns, the cloud keeps going, gets hauled back, and sails past the
			# other way; that overshoot is the whole character. the same spring in y
			# lets the downpour press sag it under the extra water.
			b.D = { "k": 30.0,               # the tether spring's stiffness — the cloud's own period is 2π/√k ≈ 1.1 s
				"damp": 0.3,                 # damping as a fraction of critical — well under 1: it overshoots at every turn (the joke)
				"sag": 40.0,                 # the downpour press's downward kick, px/s — a heavier cloud sags
				"sagK": 25.0 }               # the height spring that lifts it back once the rain is out
			b.cx = b.cub.x
			b.cv = 0.0
			b.dy = 0.0
			b.dyv = 0.0
		"water_whip":
			# the whip is the stagecraft Grass blade turned upside down: a chain of
			# angles, each joint a damped spring whose rest is the joint below it. the
			# press never touches the chain — it swings the ARM (the root's rest angle)
			# forward and holds it. the joints chase that, each a little late and a
			# little under-damped, so a wave runs out along the whip and the tip arrives
			# last, fastest, and overshoots the arm: that is the crack, and nothing in
			# the code draws it on purpose.
			b.D = { "segs": 10,              # joints in the whip
				"len": 0.32,                 # each segment's length, in cube-sides (ten of them reach 3.2 sides)
				"k": 250.0,                  # the root spring's stiffness — the fist's grip is firm
				"damp": 0.8,                 # the root's damping as a fraction of critical
				"tip": 1.25,                 # each joint's k as a multiple of the one below: lighter water out there rights faster
				"tipdamp": 0.45,             # a joint's damping as a fraction of ITS OWN critical — under 1, so the tip overshoots the arm
				"bend": 1.2,                 # the most a joint can fold past the one below, radians
				"swing": 1.6,                # where the arm swings to, radians from hanging-down toward the front
				"hold": 0.22,                # how long the arm holds there before dropping back, s
				"idle": 0.35 }               # the coiled rest, radians behind straight-down
			var N: int = b.D.segs
			var th := PackedFloat32Array()   # world angles from straight-down toward +x, and their rates
			var om := PackedFloat32Array()
			th.resize(N)
			om.resize(N)
			th.fill(-b.cub.face * float(b.D.idle))
			var chain := PackedVector2Array()   # the joints' positions, fist first — walked each tick, read by draw
			chain.resize(N + 1)
			chain.fill(Vector2(b.cub.x + b.cub.face * b.cub.s * 0.5, b.cub.y - b.cub.s * 0.6))
			b.N = N
			b.th = th
			b.om = om
			b.chain = chain
			b.swing = -1.0
		"geyser":
			b.gx = 0.0
		"mist_veil":
			b.wisps = []
			for i in 6:
				b.wisps.append({ "a": randf_range(0, TAU), "v": randf_range(0.3, 0.7), "r": randf_range(8, 14) })

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"waterhose", "mist_veil":
			b.press_v = 1.1
		"rain_pet":
			b.press_v = 1.1
			b.dyv += float(b.D.sag)          # the downpour's weight: a downward kick on the height spring
		"bubble_shield":
			if b.up >= 1.0:
				b.up = 0.0
				b.reform = 1.4
				for i in 16:
					var th := randf_range(0, TAU)
					b.parts.append({ "pos": Vector2(c.x + cos(th) * c.s, c.y - c.s * 0.5 + sin(th) * c.s),
						"vel": Vector2(cos(th), sin(th)) * randf_range(40, 90), "life": 1.0, "kind": "drop" })
		"splash_stomp":
			if not b.air:
				b.air = true
				b.vy = -float(b.D.jump)
		"water_whip":
			if b.swing < 0.0:
				b.swing = 0.0
		"geyser":
			var r: Rect2 = b.rect
			b.parts.append({ "kind": "geyser", "x": clampf(pos.x, r.position.x + 8, r.position.x + r.size.x - 8), "life": 1.0 })
		"tidal_push":
			b.parts.append({ "kind": "wave", "x": c.x + c.face * c.s * 0.7, "dir": c.face, "life": 1.0 })

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	b.press_v = maxf(0.0, b.press_v - dt * (0.8 if b.id == "mist_veil" else 1.0))
	match b.id:
		"waterhose":
			var hx := Vector2(c.x + c.face * c.s * 0.6, c.y - c.s * 0.5)
			if randf() < 0.06:
				b.parts.append({ "pos": hx, "vel": Vector2(c.face * 10.0, 10.0), "life": 1.0, "kind": "drop" })
			if b.press_v > 0.0:
				for i in 3:
					b.parts.append({ "pos": hx, "vel": Vector2(c.face * randf_range(170, 220), randf_range(-140, -110)),
						"life": 1.6, "kind": "drop" })
			for p in b.parts:
				if p.kind == "drop":
					p.pos += p.vel * dt
					p.vel.y += 300.0 * dt
					p.life -= dt * 0.8
					if p.pos.y >= b.G:
						for i in 2:
							b.parts.append({ "pos": Vector2(p.pos.x, b.G),
								"vel": Vector2(randf_range(-50, 50), randf_range(-90, -30)), "life": 0.6, "kind": "splash" })
						p.life = 0.0
				else:
					p.pos += p.vel * dt
					p.vel.y += 260.0 * dt
					p.life -= dt * 1.6
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"bubble_shield":
			b.reform = maxf(0.0, b.reform - dt)
			if b.reform <= 0.0:
				b.up = minf(1.0, b.up + dt * 1.5)
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += 150.0 * dt
				p.life -= dt * 1.4
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"splash_stomp":
			var D: Dictionary = b.D
			if b.air:
				b.vy += float(D.g) * dt
				c.y += b.vy * dt
				if c.y >= b.G:                    # contact: the landing throws the splash
					c.y = b.G
					b.air = false
					b.sqv += b.vy * float(D.squashKick)   # the impact becomes squash velocity
					b.vy = 0.0
					b.parts.append({ "kind": "ring", "r": 4.0, "life": 1.0 })
					for i in 10:
						b.parts.append({ "kind": "drop", "pos": Vector2(c.x, b.G),
							"vel": Vector2(randf_range(-100, 100), randf_range(-150, -50)), "life": 1.0 })
			var sk: float = D.squashK
			var sd: float = float(D.squashDamp) * 2.0 * sqrt(sk)
			var sub := maxi(1, ceili(dt * 50.0))   # the spring's substep guard: ≤ 0.02 s a step
			var h := dt / float(sub)
			for _s in sub:
				b.sqv += (sk * (0.0 - c.squash) - sd * b.sqv) * h
				c.squash = clampf(c.squash + b.sqv * h, -0.5, 0.5)
			for p in b.parts:
				if p.kind == "ring":
					p.r += 90.0 * dt
					p.life -= dt * 1.4
				else:
					p.pos += p.vel * dt
					p.vel.y += 300.0 * dt
					p.life -= dt * 1.5
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"rain_pet":
			var D: Dictionary = b.D
			var r: Rect2 = b.rect
			var kk: float = D.k
			var dd: float = float(D.damp) * 2.0 * sqrt(kk)
			var sk: float = D.sagK
			var sd: float = 0.5 * 2.0 * sqrt(sk)   # the sag, a touch better damped
			var sub := maxi(1, ceili(dt * 50.0))   # the springs' substep guard
			var h := dt / float(sub)
			for _s in sub:
				b.cv += (kk * (c.x - b.cx) - dd * b.cv) * h     # the tether
				b.cx += b.cv * h
				b.dyv += (sk * (0.0 - b.dy) - sd * b.dyv) * h   # the sag
				b.dy = clampf(b.dy + b.dyv * h, -20.0, 20.0)
			b.cx = clampf(b.cx, r.position.x - 40.0, r.position.x + r.size.x + 40.0)
			if randf() < 0.25 + b.press_v:
				b.parts.append({ "kind": "rain", "pos": Vector2(b.cx + randf_range(-14, 14), c.y - c.s * 2.0 + b.dy) })
			for p in b.parts:
				p.pos.y += 170.0 * dt
				if p.pos.y >= c.y - c.s and p.pos.y < c.y and absf(p.pos.x - c.x) < c.s * 0.5:
					p.pos.y = 1e9
				if p.pos.y >= b.G:
					p.pos.y = 1e9
			b.parts = b.parts.filter(func(p): return p.pos.y < 1e8)
		"water_whip":
			var D: Dictionary = b.D
			var N: int = b.N
			var th: PackedFloat32Array = b.th
			var om: PackedFloat32Array = b.om
			var chain: PackedVector2Array = b.chain
			var L: float = c.s * float(D.len)
			var rest: float = -c.face * float(D.idle)
			if b.swing >= 0.0:
				b.swing += dt
				if b.swing < float(D.hold):
					rest = c.face * float(D.swing)       # the arm, out and held
				elif b.swing > float(D.hold) + 1.2:
					b.swing = -1.0                       # and the chain is left to settle
			var kk: float = D.k
			var damp: float = D.damp
			var tip: float = D.tip
			var tipdamp: float = D.tipdamp
			var bend: float = D.bend
			var sub := maxi(1, ceili(dt * 50.0))   # stiff joints: substeps of ≤ 0.02 s
			var h := dt / float(sub)
			for _s in sub:
				var below := rest
				var kj := kk
				var dj := damp * 2.0 * sqrt(kk)
				for j in N:
					if j > 0:
						kj *= tip                        # quicker with every joint out (lighter water, same bend)
						dj = tipdamp * 2.0 * sqrt(kj)    # a fraction of THIS joint's critical damping
					om[j] += (kj * (below - th[j]) - dj * om[j]) * h
					var a: float = th[j] + om[j] * h
					if j > 0:
						a = clampf(a, below - bend, below + bend)   # water folds, but not back on itself
					th[j] = clampf(a, -3.0, 3.0)
					below = th[j]
			var old_tip: Vector2 = chain[N]
			chain[0] = Vector2(c.x + c.face * c.s * 0.5, c.y - c.s * 0.6)
			for j in N:                                  # walk the chain from the fist
				chain[j + 1] = chain[j] + Vector2(sin(th[j]), cos(th[j])) * L
			var tipv: Vector2 = (chain[N] - old_tip) / maxf(dt, 0.0001)   # the tip's speed, for the spray
			var sp := tipv.length()
			if sp > 150.0 and sp < 5000.0 and randf() < 0.7:   # spray flies off a fast tip at the tip's own speed
				b.parts.append({ "pos": chain[N], "vel": tipv * 0.3 + Vector2(randf_range(-20, 20), randf_range(-30, 10)), "life": 0.6 })
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += 200.0 * dt
				p.life -= dt * 1.8
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"geyser":
			var r: Rect2 = b.rect
			b.gx = r.get_center().x + sin(t * 0.3 + 2.0) * r.size.x * 0.3
			for p in b.parts:
				p.life -= dt * 0.7
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"mist_veil":
			c.alpha = 0.15 if b.press_v > 0.25 else 1.0
			for w in b.wisps:
				w.a += w.v * dt
		"tidal_push":
			for p in b.parts:
				if p.kind == "wave":
					p.x += p.dir * 150.0 * dt
					p.life -= dt * 0.55
				else:
					p.pos += p.vel * dt
					p.vel.y += 160.0 * dt
					p.life -= dt * 1.6
			b.parts = b.parts.filter(func(p): return p.life > 0.0)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	CubeKit.stage(n, b)
	match b.id:
		"waterhose", "splash_stomp":
			if b.id == "splash_stomp":
				n.draw_set_transform(Vector2(c.x, b.G + 3.0), 0.0, Vector2(1.0, 0.25))
				n.draw_circle(Vector2.ZERO, c.s * 1.1, Color(0.35, 0.59, 0.82, 0.2))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				if p.get("kind", "") == "ring":
					CubeKit.ellipse(n, Vector2(c.x, b.G + 2.0), p.r, p.r * 0.25, Color(0.59, 0.82, 0.96, p.life * 0.8), 1.6)
				elif p.kind == "drop":
					n.draw_set_transform(p.pos, 0.0, Vector2(1.0, 1.6))
					n.draw_circle(Vector2.ZERO, 2.0, Color(0.47, 0.75, 0.94, 0.85))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				else:
					n.draw_rect(Rect2(p.pos, Vector2(2, 2)), Color(0.67, 0.86, 0.98, p.life))
		"bubble_shield":
			CubeKit.draw_cube(n, b)
			if b.up > 0.05:
				var rr: float = c.s * 1.25 * b.up
				CubeKit.ellipse(n, Vector2(c.x, c.y - c.s * 0.5), rr, rr * 1.05, Color(0.59, 0.82, 0.96, 0.55 * b.up), 1.5)
				var ha: float = t * 0.8
				CubeKit.ellipse(n, Vector2(c.x, c.y - c.s * 0.5), rr * 0.85, rr * 0.9,
					Color(1, 1, 1, 0.5 * b.up), 1.5, ha, ha + 0.7, 8)
			for p in b.parts:
				n.draw_rect(Rect2(p.pos, Vector2(2, 2)), Color(0.67, 0.86, 0.98, p.life))
		"rain_pet":
			CubeKit.draw_cube(n, b)
			var cy: float = c.y - c.s * 2.1 + b.dy    # the height spring's sag, not a sine bob
			for i in 5:
				n.draw_circle(Vector2(b.cx + (i - 2) * 8.0, cy + sin(i * 2.3) * 2.5), 7.0 + (i % 2) * 2.0,
					Color(0.47, 0.49, 0.61, 0.9))
			for p in b.parts:
				n.draw_line(p.pos - Vector2(0, 5), p.pos, Color(0.59, 0.78, 0.94, 0.6), 1.0)
		"water_whip":
			CubeKit.draw_cube(n, b)
			var chain: PackedVector2Array = b.chain    # the chain as the tick left it, fist to tip
			var busy: bool = b.swing >= 0.0
			n.draw_polyline(chain, Color(0.51, 0.78, 0.96, 0.85 if busy else 0.5), 4.0 if busy else 3.0)
			for p in b.parts:
				n.draw_rect(Rect2(p.pos, Vector2(2, 2)), Color(0.67, 0.86, 0.98, p.life))
		"geyser":
			if randf() < 0.15:
				CubeKit.ellipse(n, Vector2(b.gx + randf_range(-6, 6), b.G - 1.0), randf_range(1.5, 3.0), 1.5,
					Color(0.59, 0.82, 0.96, 0.5), 1.0, PI, TAU, 8)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				var hgt: float = sin(minf(1.0, (1.0 - p.life) * 3.0) * PI * 0.5) * c.s * 2.8 * minf(1.0, p.life * 2.0)
				for i in 8:
					var q := i / 8.0
					n.draw_set_transform(Vector2(p.x + sin(t * 20.0 + i) * 2.0, b.G - hgt * q), 0.0, Vector2(1.0, 1.5))
					n.draw_circle(Vector2.ZERO, 6.0 - q * 2.0, Color(0.55, 0.8, 0.96, 0.55 - q * 0.3))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				CubeKit.glow(n, Vector2(p.x, b.G - hgt), 10.0, Color(0.75, 0.9, 0.98, 0.5), 2)
		"mist_veil":
			CubeKit.draw_cube(n, b)
			for w in b.wisps:
				var pos := Vector2(c.x + cos(w.a) * c.s * (1.0 + b.press_v),
					c.y - c.s * 0.5 + sin(w.a) * c.s * 0.6)
				CubeKit.glow(n, pos, w.r * (1.0 + b.press_v * 1.6), Color(0.7, 0.78, 0.88, 0.10 + b.press_v * 0.14), 2)
		"tidal_push":
			CubeKit.ellipse(n, Vector2(c.x, b.G + 1.0), c.s * (0.8 + sin(t * 2.0) * 0.1), 3.0,
				Color(0.51, 0.75, 0.92, 0.35), 1.5, PI, TAU, 10)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				if p.kind != "wave":
					continue
				var hgt: float = c.s * 1.3 * minf(1.0, p.life * 1.6)
				for k in 4:
					CubeKit.ellipse(n, Vector2(p.x - p.dir * k * 5.0, b.G), 14.0 + k * 4.0,
						maxf(0.5, hgt - k * 5.0), Color(0.47, 0.75, 0.94, (0.6 - k * 0.12) * p.life), 3.0, PI, TAU, 12)
