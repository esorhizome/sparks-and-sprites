extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
const Base := preload("res://scenes/cubefx/wind.gd")
## WIND — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"tornado": { "name": "Firenado", "hint": "ignited — warm rings and shed embers" },
	"gust": { "name": "Water palm", "hint": "the rings made liquid — droplets shed off every ring" },
	"cyclone_jump": { "name": "Rocket jump", "hint": "powered by fire — exhaust below instead of wind around" },
	"cloak": { "name": "Storm cloak", "hint": "electrified — arcs jump between the streams" },
	"air_slash": { "name": "Flame crescent", "hint": "on fire — they shed embers as they travel" },
	"updraft": { "name": "Downdraft", "hint": "the sign flipped — it slams the feathers DOWN" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)

static func press(b: Dictionary, pos: Vector2) -> void:
	Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	match b.id:
		"tornado":
			# dial: the funnel sheds embers as it travels
			b.press_v = maxf(0.0, b.press_v - dt * 1.4)
			if b.storm > 0.0:
				b.storm -= dt * 0.7
				c.spin += dt * 22.0
				if randf() < 0.5:
					b.parts.append({ "kind": "ember", "pos": Vector2(c.x + randf_range(-c.s, c.s) * 0.6,
						c.y - randf_range(0, c.s * 1.8)), "life": 0.8 })
				if c.x < r.position.x + c.s or c.x > r.position.x + r.size.x - c.s:
					c.vx = -c.vx
				if b.storm <= 0.0:
					c.pace = true
					c.spin = 0.0
					c.vx = 0.0
			for p in b.parts:
				p.pos.y -= 24.0 * dt
				p.life -= dt * 1.4
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"gust":
			# dial: every ring sheds droplets that fall
			b.press_v = maxf(0.0, b.press_v - dt * 1.4)
			for p in b.parts:
				p.delay -= dt
				if p.delay > 0.0:
					continue
				if p.kind == "ring":
					p.x += p.dir * 140.0 * dt
					p.r += 30.0 * dt
					p.life -= dt * 1.6
				else:
					p.pos += p.vel * dt
					p.vel.y += 260.0 * dt
					p.life -= dt * 1.8
			var drops := []
			for p in b.parts:
				if p.kind == "ring" and p.delay <= 0.0 and randf() < 0.5:
					drops.append({ "kind": "drop", "pos": Vector2(p.x, c.y - c.s * 0.55 + randf_range(-p.r, p.r) * 0.5),
						"vel": Vector2(p.dir * 30.0, randf_range(-20, 10)), "delay": 0.0, "life": 0.8 })
			b.parts.append_array(drops)
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"cyclone_jump":
			# dial: side streaks → exhaust below, blasting down
			b.press_v = maxf(0.0, b.press_v - dt * 1.4)
			if b.lift >= 0.0:
				b.lift += dt * 1.1
				c.y = b.G - sin(minf(1.0, b.lift) * PI) * c.s * 2.2
				for i in 2:
					b.parts.append({ "kind": "flame", "pos": Vector2(c.x + randf_range(-4, 4), c.y + 2.0), "life": 0.5 })
				if b.lift >= 1.0:
					b.lift = -1.0
					c.y = b.G
			for p in b.parts:
				p.pos.y += 70.0 * dt
				p.pos.y = minf(p.pos.y, b.G)
				p.life -= dt * 1.8
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"air_slash":
			# dial: crescents shed falling embers
			b.press_v = maxf(0.0, b.press_v - dt * 1.4)
			var embers := []
			for p in b.parts:
				p.delay -= dt
				if p.delay > 0.0:
					continue
				if p.kind == "blade":
					p.pos.x += p.dir * 220.0 * dt
					p.life -= dt * 1.2
					if randf() < 0.5:
						embers.append({ "kind": "ember", "pos": Vector2(p.pos.x - p.dir * 8.0, p.pos.y),
							"dir": p.dir, "delay": 0.0, "life": 0.6 })
				else:
					p.pos.y += 50.0 * dt
					p.life -= dt * 1.8
			b.parts.append_array(embers)
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"updraft":
			# dial: the column pushes DOWN — feathers slam to the floor
			var rr: Rect2 = b.rect
			if randf() < 0.03:
				b.feathers.append({ "pos": Vector2(randf_range(rr.position.x + 10, rr.position.x + rr.size.x - 10),
					rr.position.y - 4.0), "ph": randf_range(0, 9) })
			for f in b.feathers:
				var vy := 14.0
				for p in b.parts:
					if absf(f.pos.x - p.x) < 16.0 and p.life > 0.0:
						vy = 180.0
				f.pos.y += vy * dt
				f.pos.x += sin(t * 2.0 + f.ph) * 12.0 * dt
			b.feathers = b.feathers.filter(func(f): return f.pos.y > rr.position.y - 12.0 and f.pos.y < b.G)
			for p in b.parts:
				p.life -= dt * 0.7
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		_:
			Base.tick(b, dt, t)

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
						Color(1, 0.59 + k * 0.25, 0.24, (0.55 - k * 0.2) * minf(1.0, b.storm * 2.0)), 1.6, a, a + 3.6, 10)
			for p in b.parts:
				CubeKit.glow(n, p.pos, 2.5, Color(1, 0.63, 0.27, p.life * 0.9), 2)
		"gust":
			for p in b.parts:
				if p.delay > 0.0:
					continue
				if p.kind == "ring":
					CubeKit.ellipse(n, Vector2(p.x, c.y - c.s * 0.55), p.r * 0.4, p.r,
						Color(0.51, 0.78, 0.96, p.life * 0.7), 2.0)
				else:
					n.draw_set_transform(p.pos, 0.0, Vector2(1.0, 1.6))
					n.draw_circle(Vector2.ZERO, 1.6, Color(0.63, 0.86, 0.98, p.life * 0.9))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"cyclone_jump":
			for p in b.parts:
				CubeKit.glow(n, p.pos, 4.0 + (1.0 - p.life) * 4.0, Color(1, 0.55 + p.life * 0.3, 0.2, p.life * 0.7), 2)
		"cloak":
			for i in 4:
				var a: float = t * 2.0 + i / 4.0 * TAU
				var rr: float = c.s * (0.95 + pv * 0.7)
				CubeKit.ellipse(n, Vector2(c.x, c.y - c.s * 0.5), rr, rr * 0.55,
					Color(0.63, 0.78, 1.0, 0.35 + pv * 0.45), 1.6 + pv, a, a + 1.2, 8)
			if randf() < 0.25 + pv * 0.5:      # arcs jump between the streams
				var a1: float = t * 2.0 + (randi() % 4) / 4.0 * TAU
				var a2: float = a1 + TAU / 4.0
				var rr2: float = c.s * (0.95 + pv * 0.7)
				var p1 := Vector2(c.x + cos(a1) * rr2, c.y - c.s * 0.5 + sin(a1) * rr2 * 0.55)
				var p2 := Vector2(c.x + cos(a2) * rr2, c.y - c.s * 0.5 + sin(a2) * rr2 * 0.55)
				var pts := PackedVector2Array()
				pts.append(p1)
				for k in range(1, 4):
					pts.append(p1.lerp(p2, k / 4.0) + Vector2(randf_range(-4, 4), randf_range(-4, 4)))
				pts.append(p2)
				n.draw_polyline(pts, Color(0.86, 0.92, 1.0, 0.8), 1.2)
		"air_slash":
			n.draw_line(Vector2(c.x - c.face * c.s * 0.45 - 4.0, c.y - c.s * 0.4),
				Vector2(c.x - c.face * c.s * 0.45 + 4.0, c.y - c.s * 0.44),
				Color(1, 0.78, 0.55, 0.3 + sin(t * 4.0) * 0.15), 1.5)
			for p in b.parts:
				if p.delay > 0.0:
					continue
				if p.kind == "blade":
					var a0: float = -0.9 if p.dir > 0 else PI - 0.9
					CubeKit.ellipse(n, p.pos - Vector2(p.dir * 8.0, 0), 11.0, 11.0,
						Color(1, 0.67, 0.31, p.life * 0.95), 2.5, a0, a0 + 1.8, 10)
				else:
					CubeKit.glow(n, p.pos, 2.2, Color(1, 0.55, 0.2, p.life * 0.9), 2)
		"updraft":
			for f in b.feathers:
				n.draw_set_transform(f.pos, sin(t * 3.0 + f.ph) * 0.5, Vector2(1.0, 0.37))
				n.draw_circle(Vector2.ZERO, 3.5, Color(0.9, 0.92, 0.96, 0.8))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for p in b.parts:
				for i in 3:
					var x: float = p.x + sin(t * 8.0 + i * 2.0) * 6.0
					var y: float = r.position.y + fmod(t * 130.0 + i * 40.0, (b.G - r.position.y) * 0.8)
					n.draw_line(Vector2(x, y), Vector2(x + 2.0, y + 12.0),
						Color(0.78, 0.84, 0.92, minf(1.0, p.life) * 0.4), 1.4)
		_:
			Base.draw(n, b, t)
