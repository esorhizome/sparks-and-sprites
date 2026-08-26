extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
const Base := preload("res://scenes/cubefx/bolt.gd")
## LIGHTNING — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"sky_bolt": { "name": "Twin forks", "hint": "the strike doubled — one bolt each side of the mark" },
	"chain_zap": { "name": "Chain frost", "hint": "in ice — each landing leaves a frost patch" },
	"static_aura": { "name": "Ember static", "hint": "warmed to fire — the nova rolls out slower" },
	"thunder_clap": { "name": "Frost clap", "hint": "exhaled cold — mist ring instead of shock lines" },
	"charge_release": { "name": "Overcharge", "hint": "twice as greedy — a thicker bolt for less patience" },
	"volt_dash": { "name": "Shadow step", "hint": "the lightning dial removed — only fading footprints" },
	"orbit_sparks": { "name": "Orbiting embers", "hint": "warmed — fired embers arc down under gravity" },
	"storm_call": { "name": "Heat lightning", "hint": "the rain removed — silent flashes only" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)
	if b.id == "chain_zap":
		b.patches = []
	if b.id == "volt_dash":
		b.steps = []

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	match b.id:
		"sky_bolt":
			# dial: one bolt → two, straddling the mark
			var x0: float = clampf(pos.x, r.position.x + 16, r.position.x + r.size.x - 16)
			b.parts.append({ "kind": "bolt", "x": x0 - 10.0, "life": 1.0 })
			b.parts.append({ "kind": "bolt", "x": x0 + 10.0, "life": 1.0 })
			b.flash = 1.0
		"volt_dash":
			# dial: footprints instead of a zigzag
			var from: float = c.x
			var to: float = clampf(c.x + c.face * c.s * 3.2, r.position.x + c.s, r.position.x + r.size.x - c.s)
			c.x = to
			for i in 5:
				b.steps.append({ "x": from + (to - from) * i / 4.0, "life": 1.0 })
		"charge_release":
			b.bolt = maxf(0.6, b.charge * 1.4)
			b.charge = 0.0
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"chain_zap":
			# dial: each hop stamps a frost patch that outlives the arc
			b.press_v = maxf(0.0, b.press_v - dt * 1.6)
			if b.chain >= 0.0:
				var before: int = int(b.chain)
				b.chain += dt * 3.0
				if int(b.chain) > before and int(b.chain) <= 3:
					b.patches.append({ "x": c.x + c.face * c.s * (1.4 + before * 1.3),
						"y": b.G - 8.0 - (before % 2) * 14.0, "life": 1.0 })
				if b.chain > 3.5:
					b.chain = -1.0
			for pa in b.patches:
				pa.life -= dt * 0.4
			b.patches = b.patches.filter(func(pa): return pa.life > 0.0)
		"charge_release":
			# dial: gather 0.12 → 0.24 (greedy)
			b.press_v = maxf(0.0, b.press_v - dt * 1.6)
			b.charge = minf(1.0, b.charge + dt * 0.24)
			if randf() < 0.3 + b.charge * 0.5:
				b.orbs.append({ "a": randf_range(0, TAU), "r": c.s * 2.2, "life": 1.0 })
			for o in b.orbs:
				o.r -= 60.0 * dt
				o.a += 3.0 * dt
				o.life -= dt * 0.9
			b.orbs = b.orbs.filter(func(o): return o.life > 0.0 and o.r > 4.0)
			b.bolt = maxf(0.0, b.bolt - dt * 2.5)
		"volt_dash":
			b.press_v = maxf(0.0, b.press_v - dt * 1.6)
			for s in b.steps:
				s.life -= dt * 0.9
			b.steps = b.steps.filter(func(s): return s.life > 0.0)
		"orbit_sparks":
			# dial: fired orbs fall under gravity instead of flying level
			var r: Rect2 = b.rect
			b.press_v = maxf(0.0, b.press_v - dt * 1.6)
			for o in b.orbs:
				if o.fired < 0.0:
					var a: float = t * 2.0 + o.ph
					o.x = c.x + cos(a) * c.s * 1.1
					o.y = c.y - c.s * 0.5 + sin(a) * c.s * 0.6
				else:
					o.fired += dt
					o.x += c.face * 170.0 * dt
					o.y += o.fired * 220.0 * dt
					if o.fired > 1.2 or o.y > b.G or o.x < r.position.x - 10 or o.x > r.position.x + r.size.x + 10:
						o.fired = -1.0
		"storm_call":
			# dial: the rain deleted — flashes only
			b.press_v = maxf(0.0, b.press_v - dt * 1.6)
			b.rain.clear()
			for p in b.parts:
				p.delay -= dt
				if p.delay <= 0.0:
					p.life -= dt * 3.0
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	var pv: float = b.press_v
	match b.id:
		"chain_zap":
			CubeKit.stage(n, b)
			for pa in b.patches:           # frost patches under everything
				CubeKit.ellipse(n, Vector2(pa.x, pa.y + 8.0), 9.0, 3.0, Color(0.71, 0.9, 1.0, pa.life * 0.7), 1.2)
				CubeKit.twinkle(n, Vector2(pa.x, pa.y + 4.0), 3.0 * pa.life, Color(0.86, 0.95, 1.0, pa.life))
			CubeKit.draw_cube(n, b)
			if randf() < 0.3:
				var p0 := Vector2(c.x + randf_range(-c.s, c.s) * 0.5, c.y - randf_range(0, c.s))
				n.draw_line(p0, p0 + Vector2(randf_range(-8, 8), randf_range(-8, 8)), Color(0.7, 0.9, 1.0, 0.7), 1.2)
			if b.chain >= 0.0:
				var hops: int = mini(3, int(b.chain) + 1)
				var px := Vector2(c.x, c.y - c.s * 0.5)
				for i in hops:
					var nx := Vector2(c.x + c.face * c.s * (1.4 + i * 1.3), b.G - 8.0 - (i % 2) * 14.0)
					var a: float = 1.0 - b.chain * 0.25
					var pts := PackedVector2Array()
					pts.append(px)
					for k in range(1, 5):
						pts.append(px.lerp(nx, k / 4.0) + Vector2(randf_range(-4, 4), randf_range(-4, 4)))
					n.draw_polyline(pts, Color(0.63, 0.9, 1.0, maxf(0.0, a)), 1.6)
					CubeKit.glow(n, nx, 7.0, Color(0.71, 0.92, 1.0, maxf(0.0, a)), 2)
					px = nx
		"static_aura":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for i in 3:
				if randf() < 0.4:
					var th := randf_range(0, TAU)
					var p0 := Vector2(c.x + cos(th) * c.s * 0.55, c.y - c.s * 0.5 + sin(th) * c.s * 0.55)
					n.draw_line(p0, p0 + Vector2(randf_range(-6, 6), randf_range(-6, 6)), Color(1, 0.75, 0.39, 0.8), 1.0)
			if pv > 0.0:
				var rr: float = (1.0 - pv) * c.s * 1.8 + 8.0   # the slower roll
				var pts := PackedVector2Array()
				for i in 15:
					var th := i / 14.0 * TAU
					var jr: float = rr + randf_range(-2, 2)
					pts.append(Vector2(c.x + cos(th) * jr, c.y - c.s * 0.5 + sin(th) * jr * 0.7))
				n.draw_polyline(pts, Color(1, 0.78, 0.43, pv), 2.5)
		"thunder_clap":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			if pv > 0.0:
				var k := 1.0 - pv
				CubeKit.glow(n, Vector2(c.x, c.y - c.s * 0.6), 10.0 + k * 20.0, Color(0.86, 0.95, 1.0, pv * 0.8), 3)
				for ring in 3:            # mist rings, no shock lines
					var rr: float = 8.0 + k * c.s * 2.0 + ring * 5.0
					CubeKit.ellipse(n, Vector2(c.x, c.y - c.s * 0.6), rr, rr * 0.6,
						Color(0.82, 0.92, 1.0, pv * (0.4 - ring * 0.1)), 2.0)
		"charge_release":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for o in b.orbs:
				CubeKit.glow(n, Vector2(c.x + cos(o.a) * o.r, c.y - c.s * 0.5 + sin(o.a) * o.r * 0.7),
					3.0, Color(0.75, 0.84, 1.0, o.life * 0.8), 2)
			CubeKit.glow(n, Vector2(c.x, c.y - c.s * 0.5), 6.0 + b.charge * 14.0,
				Color(0.78, 0.88, 1.0, 0.25 + b.charge * 0.5), 3)
			if b.bolt > 0.0:
				var pts := PackedVector2Array()
				var px := Vector2(c.x + c.face * c.s * 0.5, c.y - c.s * 0.5)
				pts.append(px)
				while px.x > r.position.x and px.x < r.position.x + r.size.x:
					px += Vector2(c.face * randf_range(14, 26), randf_range(-8, 8))
					pts.append(px)
				n.draw_polyline(pts, Color(0.88, 0.92, 1.0, minf(1.0, b.bolt * 2.0)), 4.0 + b.bolt * 6.0)
		"volt_dash":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for s in b.steps:              # only the footprints remain
				n.draw_set_transform(Vector2(s.x, b.G + 1.0), 0.0, Vector2(1.0, 0.35))
				n.draw_circle(Vector2.ZERO, 4.0, Color(0.16, 0.13, 0.24, s.life * 0.8))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"orbit_sparks":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for o in b.orbs:
				if o.fired < 0.0:
					CubeKit.glow(n, Vector2(o.x, o.y), 5.0, Color(1, 0.71, 0.35, 0.9), 2)
				else:
					n.draw_line(Vector2(o.x - c.face * 12.0, o.y - o.fired * 30.0), Vector2(o.x, o.y),
						Color(1, 0.63, 0.27, maxf(0.0, 1.0 - o.fired)), 2.0)
		"storm_call":
			CubeKit.stage(n, b)
			if pv > 0.0 and randf() < 0.3:   # silent sheet flashes
				n.draw_rect(r, Color(1, 0.86, 0.63, 0.12))
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				if p.delay <= 0.0 and p.life > 0.0:
					Base._jag_down(n, p.x, r.position.y, b.G, Color(1, 0.86, 0.63, minf(1.0, p.life) * 0.7), 2.0)
		_:
			Base.draw(n, b, t)
