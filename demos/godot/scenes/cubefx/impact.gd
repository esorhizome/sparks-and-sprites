extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
## IMPACTS & HITS — eight cube effects, ported from the web codex.

const TITLE := "Impacts & hits"
const BLURB := "the fighting game's punctuation marks"
const DEFS := [
	{ "id": "hit_spark", "name": "Hit spark", "hint": "it shadowboxes; press for the classic star-flash where you click" },
	{ "id": "combo", "name": "Combo counter", "hint": "press repeatedly — the counter pops bigger with every hit" },
	{ "id": "shockwave", "name": "Shockwave punch", "hint": "press: a lunge and a ring of force rolls out ahead" },
	{ "id": "block", "name": "Block clang", "hint": "press: guard up — the CLANG says the block held" },
	{ "id": "parry", "name": "Parry flash", "hint": "press: the one-frame white flash every fighting game player knows" },
	{ "id": "knockback", "name": "Knockback", "hint": "press: something hits IT — flung, one bounce, a skid, a squash, a wobbling recovery" },
	{ "id": "ground_crack", "name": "Ground crack", "hint": "press: one punch down — the floor remembers it a while" },
	{ "id": "stomp", "name": "Stomp quake", "hint": "press: a short ballistic hop — the landing squashes it and sends dust waves both ways" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	match b.id:
		"combo":
			b.combo = 0
			b.cool = 0.0
		"shockwave":
			b.shake = 0.0
		"knockback":
			b.hit = false         # struck, and not yet recovered
			b.air = false         # off its feet
			b.vy = 0.0            # vertical speed, px/s (down is +)
			b.om = 0.0            # angular speed, rad/s
			b.sq = 0.0            # the squash: the body's aspect, + wide, − tall
			b.sqv = 0.0
			b.age = 0.0
			b.land_v = 0.0        # this tick's landing speed, if it met the floor (px/s)
			b.D = {
				"vx": 220.0,      # the hit: speed away from where it was looking, px/s
				"vy": 180.0,      # the hit: upward speed, px/s — it leaves its feet
				"spin": 14.0,     # the hit: angular speed, rad/s — set once by the blow, then only ever damped
				"g": 620.0,       # gravity, px/s²
				"bounce": 0.35,   # restitution: the fraction of the landing speed that comes back up
				"skid": 0.1,      # ground friction: the fraction of horizontal speed left after one second on the floor
				"airSpin": 0.6,   # the fraction of spin left after a second in the air (nothing up there to stop it)
				"floorSpin": 0.02,   # …and after a second on the floor (the floor stops it)
				"kUp": 80.0,      # the recovery: a spring that rights it to the nearest upright, rad/s² per radian
				"kSq": 400.0,     # the landing squash: a stiff, under-damped spring on the body's aspect
				"sqHit": 0.03 }   # squash injected per px/s of landing speed
		"stomp":
			# Double jump's integrator again: the press injects an upward velocity,
			# gravity brings it back, and the floor is a contact — the waves leave at
			# the moment of contact because that is when the floor is hit, not at the
			# end of a timer. the impact speed becomes a squash the spring resolves.
			b.D = { "jump": 140.0,           # launch speed, px/s — a stomp is a short hop: peak jump²/2g ≈ 0.7 cube-sides
				"g": 620.0,                  # gravity, px/s²
				"squashK": 400.0,            # the landing squash's spring stiffness
				"squashDamp": 0.35,          # its damping as a fraction of critical — under 1, so it rebounds into a stretch
				"squashKick": 0.06,          # squash velocity bought per px/s of landing speed — a stomp lands heavy
				"wave": 130.0 }              # the dust waves' speed, px/s
			b.vy = 0.0
			b.air = false
			b.sqv = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"hit_spark":
			b.press_v = 1.0
			b.parts.append({ "kind": "star", "pos": Vector2(pos.x, minf(pos.y, b.G - 4.0)),
				"life": 1.0, "rot": randf_range(0, TAU) })
		"combo":
			b.combo += 1
			b.press_v = 1.0
			b.cool = 1.6
		"shockwave":
			b.press_v = 1.0
			b.shake = 0.7
			b.parts.append({ "kind": "ring", "x": c.x + c.face * c.s * 0.9, "dir": c.face, "r": 6.0, "life": 1.0 })
		"block":
			b.press_v = 1.0
			for i in 6:
				var th := randf_range(-1.2, 1.2)
				b.parts.append({ "kind": "shard", "pos": Vector2(c.x + c.face * c.s * 0.8, c.y - c.s * 0.55),
					"vel": Vector2(c.face * cos(th) * randf_range(60, 140), sin(th) * 120.0),
					"rot": randf_range(0, TAU), "life": 1.0 })
		"parry":
			b.press_v = 1.0
		"knockback":
			if not b.hit:
				var D: Dictionary = b.D
				b.hit = true
				b.air = true
				b.age = 0.0
				c.pace = false
				c.vx = -c.face * float(D.vx)      # knocked the way it wasn't looking…
				b.vy = -float(D.vy)               # …and up, and over
				b.om = -c.face * float(D.spin)
				for i in 5:
					b.parts.append({ "kind": "dizzy", "a": randf_range(0, TAU), "life": 1.4 })
		"ground_crack":
			var cx: float = c.x + c.face * c.s * 0.7
			var rays := []
			for i in 5:
				var dir := randf_range(0, TAU)
				var segs := [Vector2(cx, b.G)]
				var px := cx
				for k in 3:
					px += cos(dir) * randf_range(8, 18)
					segs.append(Vector2(px, b.G + absf(sin(dir)) * randf_range(2, 8) * (k + 1) * 0.4))
				rays.append(segs)
			b.parts.append({ "kind": "crack", "rays": rays, "life": 1.0 })
			for i in 8:
				b.parts.append({ "kind": "debris", "pos": Vector2(cx, b.G),
					"vel": Vector2(randf_range(-70, 70), randf_range(-140, -40)), "life": 1.0 })
		"stomp":
			if not b.air:
				b.air = true
				b.vy = -float(b.D.jump)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	b.press_v = maxf(0.0, b.press_v - dt * (2.4 if b.id == "parry" else 3.0))
	match b.id:
		"hit_spark":
			if b.press_v > 0.0:
				c.lean = c.face * 0.18 * b.press_v
			elif randf() < 0.02:
				b.press_v = 0.4
			for p in b.parts:
				p.life -= dt * 3.0
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"combo":
			if b.cool > 0.0:
				b.cool -= dt
				if b.cool <= 0.0:
					b.combo = 0
			if b.press_v > 0.0 and b.combo > 0:
				c.lean = c.face * 0.15 * b.press_v
		"shockwave":
			b.shake = maxf(0.0, b.shake - dt * 2.0)
			if b.press_v > 0.0:
				c.lean = c.face * 0.2 * b.press_v
			for p in b.parts:
				p.x += p.dir * 70.0 * dt
				p.r += 100.0 * dt
				p.life -= dt * 1.6
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"block":
			if b.press_v > 0.0:
				c.lean = -c.face * 0.1 * b.press_v
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += 200.0 * dt
				p.rot += 8.0 * dt
				p.life -= dt * 2.0
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"knockback":
			# the hit sets two velocities — one linear, one angular — never a
			# position. in the air the cube is ballistic and keeps most of its spin;
			# meeting the floor fast it BOUNCES (restitution), the spin halves, and
			# the impact speed goes into a squash spring drawn as a scale about its
			# feet. on the floor the skid is friction, and a righting spring pulls
			# the spin to the nearest full turn — under-damped: a wobble, not a snap
			var r: Rect2 = b.rect
			var D: Dictionary = b.D
			b.land_v = 0.0
			if b.hit:
				var sub := maxi(1, ceili(dt * 50.0))   # the squash spring is stiff: substep coarse frames
				var h := dt / float(sub)
				var d_up: float = 0.4 * 2.0 * sqrt(float(D.kUp))
				var d_sq: float = 0.3 * 2.0 * sqrt(float(D.kSq))
				b.age += dt
				for _q in sub:
					if b.air:                         # ballistic, spinning freely
						b.vy += float(D.g) * h
						c.y += b.vy * h
						b.om *= pow(float(D.airSpin), h)
						c.spin += b.om * h
						if c.y >= b.G:                # the floor
							c.y = b.G
							b.land_v = b.vy
							b.sqv += b.vy * float(D.sqHit)   # the landing: impact speed into the squash spring
							if b.vy > 90.0:           # fast enough to bounce
								b.vy = -b.vy * float(D.bounce)
								b.om *= 0.5
							else:
								b.vy = 0.0
								b.air = false
					else:                             # on the floor: friction, and a spring to the nearest way up
						c.vx *= pow(float(D.skid), h)
						b.om *= pow(float(D.floorSpin), h)
						var upright: float = roundf(c.spin / TAU) * TAU
						b.om += (float(D.kUp) * (upright - c.spin) - d_up * b.om) * h
						c.spin += b.om * h
					b.sqv += (-float(D.kSq) * b.sq - d_sq * b.sqv) * h   # the squash rings and settles
					b.sq = clampf(b.sq + b.sqv * h, -0.5, 0.5)
				c.x = clampf(c.x, r.position.x + c.s, r.position.x + r.size.x - c.s)
				var off: float = c.spin - roundf(c.spin / TAU) * TAU
				if b.age > 3.0 or (not b.air and absf(c.vx) < 4.0 and absf(b.om) < 0.3 and absf(off) < 0.03):
					b.hit = false                     # the proud recovery
					c.spin = 0.0
					c.vx = 0.0
					c.y = b.G
					c.pace = true
			for p in b.parts:
				p.a += 5.0 * dt
				p.life -= dt
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"ground_crack":
			for p in b.parts:
				if p.kind == "crack":
					p.life -= dt * 0.25
				else:
					p.pos += p.vel * dt
					p.vel.y += 300.0 * dt
					p.life -= dt * 1.4
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"stomp":
			var D: Dictionary = b.D
			if b.air:
				b.vy += float(D.g) * dt
				c.y += b.vy * dt
				if c.y >= b.G:                    # contact: the stomp lands
					c.y = b.G
					b.air = false
					b.sqv += b.vy * float(D.squashKick)
					b.vy = 0.0
					b.parts.append({ "kind": "wave", "x": c.x, "dir": 1.0, "life": 1.0 })
					b.parts.append({ "kind": "wave", "x": c.x, "dir": -1.0, "life": 1.0 })
			var sk: float = D.squashK
			var sd: float = float(D.squashDamp) * 2.0 * sqrt(sk)
			var sub := maxi(1, ceili(dt * 50.0))   # the spring's substep guard
			var h := dt / float(sub)
			for _s in sub:
				b.sqv += (sk * (0.0 - c.squash) - sd * b.sqv) * h
				c.squash = clampf(c.squash + b.sqv * h, -0.5, 0.5)
			for p in b.parts:                     # each wave: a travelling dust hump
				p.x += p.dir * float(D.wave) * dt
				p.life -= dt * 1.1
			b.parts = b.parts.filter(func(p): return p.life > 0.0)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	var pv: float = b.press_v
	CubeKit.stage(n, b)
	match b.id:
		"hit_spark":
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				var pts := PackedVector2Array()
				for i in 8:
					var rr: float = 16.0 * (1.4 - p.life) if i % 2 == 0 else 5.0
					var th: float = p.rot + i / 8.0 * TAU
					pts.append(p.pos + Vector2(cos(th), sin(th)) * rr)
				n.draw_colored_polygon(pts, Color(1, 0.96, 0.78, p.life))
		"combo":
			CubeKit.draw_cube(n, b)
			if b.combo > 0:
				var scale: float = 1.0 + pv * 0.6 + minf(b.combo, 12) * 0.03
				n.draw_set_transform(Vector2(c.x, c.y - c.s * 1.7), pv * 0.1 - 0.05, Vector2(scale, scale))
				var text := "%d HIT%s" % [b.combo, "S!" if b.combo > 1 else "!"]
				n.draw_string(ThemeDB.fallback_font, Vector2(-40, 0), text,
					HORIZONTAL_ALIGNMENT_CENTER, 80, 13,
					Color.from_hsv((45.0 - minf(b.combo, 12) * 3.0) / 360.0, 0.9, 1.0))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"shockwave":
			var sh: float = b.shake * b.shake * 4.0
			n.draw_set_transform(Vector2(randf_range(-sh, sh), randf_range(-sh, sh)), 0.0, Vector2.ONE)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				CubeKit.ellipse(n, Vector2(p.x, c.y - c.s * 0.5), p.r * 0.5, p.r,
					Color(0.9, 0.88, 1.0, p.life * 0.8), 3.0)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"block":
			CubeKit.draw_cube(n, b)
			if pv > 0.0:
				var gx: float = c.x + c.face * c.s
				n.draw_polyline(PackedVector2Array([
					Vector2(gx - c.face * c.s * 0.2, c.y - c.s * 1.05),
					Vector2(gx, c.y - c.s * 0.5),
					Vector2(gx - c.face * c.s * 0.2, c.y + 2.0)]),
					Color(0.86, 0.88, 0.96, minf(1.0, pv * 1.4)), 3.5)
			for p in b.parts:
				n.draw_set_transform(p.pos, p.rot, Vector2.ONE)
				n.draw_colored_polygon(PackedVector2Array([Vector2(0, -4), Vector2(3, 3), Vector2(-3, 3)]),
					Color(1, 0.94, 0.75, p.life))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"parry":
			CubeKit.draw_cube(n, b)
			if pv > 0.0:
				if pv > 0.6:
					n.draw_rect(b.rect, Color(0.82, 0.88, 1.0, (pv - 0.6) * 1.6))
				var rr: float = (1.0 - pv) * c.s * 1.6 + 6.0
				CubeKit.ellipse(n, Vector2(c.x + c.face * c.s * 0.6, c.y - c.s * 0.55),
					rr, rr * 1.2, Color(0.75, 0.84, 1.0, pv), 2.5)
		"knockback":
			_draw_cube_squashed(n, b, b.sq)
			for p in b.parts:
				CubeKit.twinkle(n, Vector2(c.x + cos(p.a) * c.s * 0.7, c.y - c.s * 1.25 + sin(p.a) * 4.0),
					3.0, Color(1, 0.92, 0.59, minf(1.0, p.life)))
		"ground_crack":
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				if p.kind == "crack":
					for segs in p.rays:
						var pts := PackedVector2Array()
						for s in segs:
							pts.append(s)
						n.draw_polyline(pts, Color(0.12, 0.1, 0.19, minf(1.0, p.life * 2.0)), 2.0)
				else:
					n.draw_rect(Rect2(p.pos, Vector2(2.5, 2.5)), Color(0.55, 0.51, 0.67, p.life))
		"stomp":
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				for k in 3:
					n.draw_circle(Vector2(p.x - p.dir * k * 6.0, b.G - 3.0 - k),
						5.0 + k * 2.0, Color(0.63, 0.59, 0.73, p.life * (0.35 - k * 0.09)))

## The kit's draw_cube has no scale — the landing squash is the same shadow,
## body, and eyes under a (1 + q, 1 − q) transform about the feet.
static func _draw_cube_squashed(n: CanvasItem, b: Dictionary, q: float) -> void:
	var c: Dictionary = b.cub
	if absf(q) < 0.005:
		CubeKit.draw_cube(n, b)
		return
	if c.alpha <= 0.01:
		return
	var s: float = c.s
	n.draw_set_transform(Vector2(c.x, b.G + 2.0), 0.0, Vector2(1.0 + q, 0.28))
	n.draw_circle(Vector2.ZERO, s * 0.5, Color(0, 0, 0, 0.35 * c.alpha))
	n.draw_set_transform(Vector2(c.x, c.y - c.hop), c.lean + c.spin, Vector2(1.0 + q, 1.0 - q))
	var body: Color = c.tint if c.tint != null else Color(0.29, 0.263, 0.44)
	body.a *= c.alpha
	n.draw_rect(Rect2(-s / 2.0, -s, s, s), body)
	n.draw_rect(Rect2(-s / 2.0, -s, s, s), Color(0.75, 0.73, 0.88, 0.7 * c.alpha), false, 1.5)
	var ex: float = c.face * s * 0.13
	n.draw_rect(Rect2(ex - s * 0.17 - 1.2, -s * 0.68, 2.4, 4.0), Color(0.94, 0.93, 1.0, c.alpha))
	n.draw_rect(Rect2(ex + s * 0.17 - 1.2, -s * 0.68, 2.4, 4.0), Color(0.94, 0.93, 1.0, c.alpha))
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
