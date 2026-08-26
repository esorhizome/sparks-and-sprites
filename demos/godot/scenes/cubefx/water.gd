extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
## WATER ATTACKS — eight cube effects, ported from the web codex.

const TITLE := "Water attacks"
const BLURB := "hoses, geysers, and shields made of bubbles"
const DEFS := [
	{ "id": "waterhose", "name": "Waterhose", "hint": "it drips politely; press for the arcing jet" },
	{ "id": "bubble_shield", "name": "Bubble shield", "hint": "a shimmering bubble around it; press to pop and reform" },
	{ "id": "splash_stomp", "name": "Splash stomp", "hint": "press: a hop, a landing, and rings across the wet floor" },
	{ "id": "rain_pet", "name": "Rain cloud pet", "hint": "a loyal cloud follows overhead, drizzling; press: downpour" },
	{ "id": "water_whip", "name": "Water whip", "hint": "press: a sinuous lash of water snaps forward" },
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
			b.jump = -1.0
		"rain_pet":
			b.cx = b.cub.x
		"water_whip":
			b.lash = -1.0
		"geyser":
			b.gx = 0.0
		"mist_veil":
			b.wisps = []
			for i in 6:
				b.wisps.append({ "a": randf_range(0, TAU), "v": randf_range(0.3, 0.7), "r": randf_range(8, 14) })

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"waterhose", "rain_pet", "mist_veil":
			b.press_v = 1.1
		"bubble_shield":
			if b.up >= 1.0:
				b.up = 0.0
				b.reform = 1.4
				for i in 16:
					var th := randf_range(0, TAU)
					b.parts.append({ "pos": Vector2(c.x + cos(th) * c.s, c.y - c.s * 0.5 + sin(th) * c.s),
						"vel": Vector2(cos(th), sin(th)) * randf_range(40, 90), "life": 1.0, "kind": "drop" })
		"splash_stomp":
			if b.jump < 0.0:
				b.jump = 0.0
		"water_whip":
			if b.lash < 0.0:
				b.lash = 0.0
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
			if b.jump >= 0.0:
				b.jump += dt * 2.4
				c.y = b.G - sin(minf(1.0, b.jump) * PI) * c.s * 1.4
				if b.jump >= 1.0:
					c.y = b.G
					b.jump = -1.0
					b.parts.append({ "kind": "ring", "r": 4.0, "life": 1.0 })
					for i in 10:
						b.parts.append({ "kind": "drop", "pos": Vector2(c.x, b.G),
							"vel": Vector2(randf_range(-100, 100), randf_range(-150, -50)), "life": 1.0 })
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
			b.cx += (c.x - b.cx) * minf(1.0, dt * 3.0)
			if randf() < 0.25 + b.press_v:
				b.parts.append({ "kind": "rain", "pos": Vector2(b.cx + randf_range(-14, 14), c.y - c.s * 2.0) })
			for p in b.parts:
				p.pos.y += 170.0 * dt
				if p.pos.y >= c.y - c.s and p.pos.y < c.y and absf(p.pos.x - c.x) < c.s * 0.5:
					p.pos.y = 1e9
				if p.pos.y >= b.G:
					p.pos.y = 1e9
			b.parts = b.parts.filter(func(p): return p.pos.y < 1e8)
		"water_whip":
			if b.lash >= 0.0:
				b.lash += dt * 2.2
				if b.lash >= 1.0:
					b.lash = -1.0
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
			var cy: float = c.y - c.s * 2.1 + sin(t * 1.3) * 2.0
			for i in 5:
				n.draw_circle(Vector2(b.cx + (i - 2) * 8.0, cy + sin(i * 2.3) * 2.5), 7.0 + (i % 2) * 2.0,
					Color(0.47, 0.49, 0.61, 0.9))
			for p in b.parts:
				n.draw_line(p.pos - Vector2(0, 5), p.pos, Color(0.59, 0.78, 0.94, 0.6), 1.0)
		"water_whip":
			CubeKit.draw_cube(n, b)
			var hx := Vector2(c.x + c.face * c.s * 0.5, c.y - c.s * 0.6)
			if b.lash >= 0.0:
				var reach: float = sin(minf(1.0, b.lash) * PI) * c.s * 3.2
				var pts := PackedVector2Array()
				pts.append(hx)
				for i in range(1, 11):
					var q := i / 10.0
					pts.append(hx + Vector2(c.face * reach * q, sin(q * 6.0 - b.lash * 10.0) * 8.0 * (1.0 - q * 0.4)))
				n.draw_polyline(pts, Color(0.51, 0.78, 0.96, 0.85), 4.0)
			else:
				CubeKit.qcurve(n, hx, hx + Vector2(c.face * 8.0, 10.0 + sin(t * 2.0) * 2.0),
					hx + Vector2(c.face * 3.0, 18.0), Color(0.51, 0.78, 0.96, 0.5), 3.0)
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
