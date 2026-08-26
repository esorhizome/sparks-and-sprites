extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
## WIND — six cube effects, ported from the web codex.

const TITLE := "Wind"
const BLURB := "gusts, crescents, and one personal tornado"
const DEFS := [
	{ "id": "tornado", "name": "Tornado spin", "hint": "press: it spins itself into a travelling funnel" },
	{ "id": "gust", "name": "Gust palm", "hint": "press: rings of pushed air roll forward" },
	{ "id": "cyclone_jump", "name": "Cyclone jump", "hint": "press: a spiral of wind corkscrews it upward" },
	{ "id": "cloak", "name": "Wind cloak", "hint": "curved streams orbit it always; press flares the deflect" },
	{ "id": "air_slash", "name": "Air slash", "hint": "press: crescent blades of wind fly forward" },
	{ "id": "updraft", "name": "Updraft column", "hint": "press: rising air where you click; idle: drifting down" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	match b.id:
		"tornado":
			b.storm = 0.0
		"cyclone_jump":
			b.lift = -1.0
		"updraft":
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
			if b.lift < 0.0:
				b.lift = 0.0
		"cloak":
			b.press_v = 1.0
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
			if b.lift >= 0.0:
				b.lift += dt * 1.1
				c.y = b.G - sin(minf(1.0, b.lift) * PI) * c.s * 2.2
				for i in 2:
					var a: float = t * 14.0 + i * PI
					b.parts.append({ "kind": "streak", "pos": Vector2(c.x + cos(a) * c.s * 0.8, c.y - randf_range(0, c.s)), "life": 0.5 })
				if b.lift >= 1.0:
					b.lift = -1.0
					c.y = b.G
			for p in b.parts:
				p.pos.y -= 30.0 * dt
				p.life -= dt * 1.8
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"updraft":
			if randf() < 0.03:
				b.feathers.append({ "pos": Vector2(randf_range(r.position.x + 10, r.position.x + r.size.x - 10),
					r.position.y - 4.0), "ph": randf_range(0, 9) })
			for f in b.feathers:
				var vy := 26.0
				for p in b.parts:
					if absf(f.pos.x - p.x) < 16.0 and p.life > 0.0:
						vy = -110.0
				f.pos.y += vy * dt
				f.pos.x += sin(t * 2.0 + f.ph) * 12.0 * dt
			b.feathers = b.feathers.filter(func(f): return f.pos.y > r.position.y - 12.0 and f.pos.y < b.G)
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
			for i in 4:
				var a: float = t * 2.0 + i / 4.0 * TAU
				var rr: float = c.s * (0.95 + pv * 0.7)
				CubeKit.ellipse(n, Vector2(c.x, c.y - c.s * 0.5), rr, rr * 0.55,
					Color(0.76, 0.82, 0.91, 0.35 + pv * 0.45), 1.6 + pv, a, a + 1.2, 8)
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
				n.draw_set_transform(f.pos, sin(t * 3.0 + f.ph) * 0.5, Vector2(1.0, 0.37))
				n.draw_circle(Vector2.ZERO, 3.5, Color(0.9, 0.92, 0.96, 0.8))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for p in b.parts:
				for i in 3:
					var x: float = p.x + sin(t * 8.0 + i * 2.0) * 6.0
					var y: float = b.G - fmod(t * 130.0 + i * 40.0, (b.G - r.position.y) * 0.8)
					n.draw_line(Vector2(x, y), Vector2(x + 2.0, y - 12.0),
						Color(0.78, 0.84, 0.92, minf(1.0, p.life) * 0.4), 1.4)
