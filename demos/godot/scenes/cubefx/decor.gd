extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
## DECORATIONS — six cube effects, ported from the web codex.

const TITLE := "Decorations"
const BLURB := "butterflies, lanterns, petals — the stage dressed kindly"
const DEFS := [
	{ "id": "butterflies", "name": "Butterflies", "hint": "three companions flutter along; press and they scatter" },
	{ "id": "lanterns", "name": "Floating lanterns", "hint": "lanterns climb the night; press to release a fresh batch" },
	{ "id": "petals", "name": "Petal fall", "hint": "cherry petals cross the stage; press for a spiral flurry" },
	{ "id": "fireflies", "name": "Fireflies at dusk", "hint": "they gather near whoever stands still; press = one shared flash" },
	{ "id": "cape", "name": "Hero's cape", "hint": "a cape streams behind it; press for the wind-machine pose" },
	{ "id": "stage_rain", "name": "Stage rain", "hint": "rain over everything, honestly bouncing off the hero" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	var r: Rect2 = b.rect
	match b.id:
		"butterflies":
			b.flies = []
			for i in 3:
				b.flies.append({ "pos": r.position + Vector2(randf_range(0, r.size.x), randf_range(14, 50)),
					"ph": randf_range(0, 9), "panic": 0.0, "hue": [0.92, 0.12, 0.55][i] })
		"lanterns":
			for i in 4:
				b.parts.append({ "pos": Vector2(randf_range(r.position.x + 14, r.position.x + r.size.x - 14),
					b.G - randf_range(0, 24)), "ph": randf_range(0, 9), "life": 1.0 })
		"fireflies":
			b.flies = []
			for i in 8:
				b.flies.append({ "pos": r.position + Vector2(randf_range(0, r.size.x), randf_range(14, 70)),
					"ph": randf_range(0, TAU), "sp": randf_range(0.6, 1.3), "wx": randf_range(0, 9) })
		"cape":
			b.pts = []
			for i in 9:
				b.pts.append(Vector2(b.cub.x, b.cub.y - b.cub.s))
		"stage_rain":
			b.rain = []

static func press(b: Dictionary, _pos: Vector2) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"butterflies":
			for f in b.flies:
				f.panic = 1.0
		"lanterns":
			for i in 3:
				b.parts.append({ "pos": Vector2(c.x + randf_range(-6, 6), c.y - c.s),
					"ph": randf_range(0, 9), "life": 1.0 })
		"petals", "fireflies", "cape", "stage_rain":
			b.press_v = 1.4

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	b.press_v = maxf(0.0, b.press_v - dt)
	match b.id:
		"butterflies":
			for f in b.flies:
				f.panic = maxf(0.0, f.panic - dt * 0.5)
				var target := Vector2(c.x + sin(t * 0.8 + f.ph * 3.0) * c.s * 1.6,
					c.y - c.s * 1.2 + sin(t * 1.3 + f.ph) * 14.0)
				var chase: float = -3.0 if f.panic > 0.0 else 1.6
				f.pos += (target - f.pos) * dt * chase + Vector2(sin(t * 9.0 + f.ph) * 14.0, -f.panic * 40.0) * dt
				f.pos.x = clampf(f.pos.x, r.position.x + 4, r.position.x + r.size.x - 4)
				f.pos.y = clampf(f.pos.y, r.position.y + 8, b.G - 8)
		"lanterns":
			for p in b.parts:
				p.pos.y -= 14.0 * dt
				p.pos.x += sin(t * 0.7 + p.ph) * 8.0 * dt
				if p.pos.y < r.position.y + 12.0:
					p.life -= dt
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"petals":
			if randf() < 0.15 + (0.5 if b.press_v > 0.0 else 0.0):
				b.parts.append({ "pos": Vector2(randf_range(r.position.x - 10, r.position.x + r.size.x), r.position.y),
					"ph": randf_range(0, 9), "rot": randf_range(0, TAU) })
			for p in b.parts:
				if b.press_v > 0.0:
					var ctr := Vector2(c.x, c.y - c.s)
					var d: Vector2 = p.pos - ctr
					var a: float = d.angle() + dt * 4.0
					p.pos = ctr + Vector2(cos(a), sin(a)) * d.length() * (1.0 - dt * 0.3)
				else:
					p.pos += Vector2(14.0 + sin(t * 2.0 + p.ph) * 10.0, 22.0) * dt
				p.rot += dt * 2.0
			b.parts = b.parts.filter(func(p): return p.pos.y < b.G and p.pos.x < r.position.x + r.size.x + 14.0)
		"fireflies":
			for f in b.flies:
				f.pos.x += (c.x + sin(f.wx * 3.0) * c.s * 2.0 - f.pos.x) * dt * 0.4 + sin(t + f.wx) * 10.0 * dt
				f.pos.y += (c.y - c.s + cos(f.wx * 2.0) * c.s - f.pos.y) * dt * 0.4 + cos(t * 1.3 + f.wx) * 8.0 * dt
		"cape":
			var pts: Array = b.pts
			pts[0] = Vector2(c.x - c.face * c.s * 0.45, c.y - c.s * 0.9 - c.hop)
			var wind: float = 1.0 + b.press_v * 2.4 + minf(1.0, absf(c.vx) / 40.0)
			for i in range(1, pts.size()):
				var target: Vector2 = pts[i - 1] + Vector2(-c.face * 5.0 * wind,
					2.5 + sin(t * (5.0 + wind) + i) * (1.5 + b.press_v * 2.0))
				pts[i] = (pts[i] as Vector2).lerp(target, minf(1.0, dt * 14.0))
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
				var flap: float = sin(t * 16.0 + f.ph) * 0.8
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
				n.draw_set_transform(p.pos, p.rot, Vector2(1.0, 0.6))
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
			var pts: Array = b.pts
			var poly := PackedVector2Array()
			for p in pts:
				poly.append(p)
			for i in range(pts.size() - 1, -1, -1):
				poly.append((pts[i] as Vector2) + Vector2(0, 6.0 + i * 1.2))
			n.draw_colored_polygon(poly, Color(0.67, 0.196, 0.27, 0.9))
			CubeKit.draw_cube(n, b)
		"stage_rain":
			CubeKit.draw_cube(n, b)
			for rd in b.rain:
				n.draw_line(rd.pos - Vector2(0, 6), rd.pos, Color(0.59, 0.7, 0.84, 0.5), 1.0)
			for p in b.parts:
				n.draw_rect(Rect2(p.pos, Vector2(1.6, 1.6)), Color(0.7, 0.82, 0.94, p.life))
