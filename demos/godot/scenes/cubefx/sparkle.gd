extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
## SPARKLES & CHARMS — eight cube effects, ported from the web codex.

const TITLE := "Sparkles & charms"
const BLURB := "the friendly end of the arsenal"
const DEFS := [
	{ "id": "shower", "name": "Sparkle shower", "hint": "the occasional twinkle; press for a shower from above" },
	{ "id": "pixie", "name": "Pixie trail", "hint": "glitter sheds as it walks — by distance, not by time" },
	{ "id": "star_twirl", "name": "Star twirl", "hint": "one loyal star orbits; press and it spins off five more" },
	{ "id": "glitter", "name": "Glitter burst", "hint": "press: an explosion of glitter right where you click" },
	{ "id": "hearts", "name": "Charm hearts", "hint": "a shy heart now and then; press for a whole ring of them" },
	{ "id": "confetti", "name": "Confetti pop", "hint": "press: confetti with real flutter; idle: one lazy streamer" },
	{ "id": "shooting_star", "name": "Shooting star", "hint": "stars cross the backdrop; press and one dives to salute" },
	{ "id": "wreath", "name": "Twinkle wreath", "hint": "a wreath of twinkles bobs above; press and it flares" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	match b.id:
		"pixie":
			b.last_x = b.cub.x
			b.travelled = 0.0
		"star_twirl":
			b.flung = []
		"shooting_star":
			b.timer = 1.0
			b.dive = null
			b.flash = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"shower":
			for i in 18:
				b.parts.append({ "pos": Vector2(c.x + randf_range(-c.s * 1.6, c.s * 1.6), c.y - c.s * 2.4 - randf_range(0, 20)),
					"vy": randf_range(40, 90), "life": 1.0, "tw": randf_range(4, 9) })
		"pixie", "wreath":
			b.press_v = 1.0
		"star_twirl":
			c.spin = 0.001
			for i in 5:
				var th := randf_range(0, TAU)
				b.flung.append({ "pos": Vector2(c.x, c.y - c.s * 0.5),
					"vel": Vector2(cos(th) * randf_range(60, 140), sin(th) * randf_range(60, 140) - 40.0),
					"rot": randf_range(0, TAU), "life": 1.0 })
		"glitter":
			var r: Rect2 = b.rect
			for i in 24:
				var th := randf_range(0, TAU)
				var v := randf_range(30, 140)
				b.parts.append({ "pos": Vector2(clampf(pos.x, r.position.x, r.position.x + r.size.x),
					minf(pos.y, b.G - 4.0)), "vel": Vector2(cos(th), sin(th)) * v,
					"life": 1.0, "hue": randf(), "tw": randf_range(5, 10) })
		"hearts":
			for i in 8:
				b.parts.append({ "kind": "ring", "a": i / 8.0 * TAU, "r": 6.0, "life": 1.0 })
		"confetti":
			for i in 22:
				b.parts.append({ "pos": Vector2(c.x, c.y - c.s), "vel": Vector2(randf_range(-90, 90), randf_range(-190, -80)),
					"rot": randf_range(0, TAU), "vr": randf_range(-8, 8), "hue": [0.94, 0.12, 0.53, 0.33, 0.75][i % 5],
					"flut": randf_range(3, 7), "life": 1.0 })
		"shooting_star":
			if b.dive == null:
				b.dive = { "pos": b.rect.position + Vector2(-10, 10) }

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	b.press_v = maxf(0.0, b.press_v - dt * (0.8 if b.id == "pixie" else 1.6))
	match b.id:
		"shower":
			if randf() < 0.06:
				b.parts.append({ "pos": Vector2(c.x + randf_range(-c.s, c.s), c.y - randf_range(0, c.s * 1.4)),
					"vy": 8.0, "life": 0.8, "tw": randf_range(4, 9) })
			for p in b.parts:
				p.pos.y += p.vy * dt
				p.life -= dt * 0.9
			b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.pos.y < b.G)
		"pixie":
			b.travelled += absf(c.x - b.last_x)
			b.last_x = c.x
			while b.travelled > 7.0:
				b.travelled -= 7.0
				b.parts.append({ "pos": Vector2(c.x + randf_range(-4, 4), c.y - randf_range(2, c.s * 0.8)),
					"a": randf_range(0, TAU), "life": 1.0, "tw": randf_range(4, 9) })
			for p in b.parts:
				if b.press_v > 0.0:
					p.a += 4.0 * dt
					p.pos = p.pos.lerp(Vector2(c.x + cos(p.a) * c.s * 1.3, c.y - c.s * 0.5 + sin(p.a) * c.s * 0.8), dt * 6.0)
				else:
					p.pos.y -= 6.0 * dt
				p.life -= dt * 0.7
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"star_twirl":
			if c.spin != 0.0:
				c.spin += dt * 14.0
				if c.spin > TAU:
					c.spin = 0.0
			for f in b.flung:
				f.pos += f.vel * dt
				f.vel.y += 120.0 * dt
				f.rot += 6.0 * dt
				f.life -= dt * 1.1
			b.flung = b.flung.filter(func(f): return f.life > 0.0)
		"glitter":
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += 60.0 * dt
				p.vel.x *= pow(0.3, dt)
				p.life -= dt * 0.9
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"hearts":
			if randf() < 0.015:
				b.parts.append({ "kind": "float", "pos": Vector2(c.x + randf_range(-6, 6), c.y - c.s * 1.2), "life": 1.0 })
			for p in b.parts:
				p.life -= dt * 0.8
				if p.kind == "ring":
					p.r += 40.0 * dt
				else:
					p.pos.y -= 24.0 * dt
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"confetti":
			for p in b.parts:
				p.vel.y = minf(p.vel.y + 150.0 * dt, 40.0)
				p.pos += Vector2(p.vel.x + sin(t * p.flut) * 30.0, p.vel.y) * dt
				p.rot += p.vr * dt
				p.vel.x *= pow(0.4, dt)
				p.life -= dt * 0.5
			b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.pos.y < b.G)
		"shooting_star":
			var r: Rect2 = b.rect
			b.timer -= dt
			if b.timer <= 0.0:
				b.parts.append({ "pos": r.position + Vector2(randf_range(-10, r.size.x * 0.6), randf_range(4, r.size.y * 0.25)), "life": 1.0 })
				b.timer = randf_range(1.5, 3.0)
			for p in b.parts:
				p.pos += Vector2(170, 60) * dt
				p.life -= dt * 0.8
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
			if b.dive != null:
				var target := Vector2(c.x, c.y - c.s * 1.3)
				b.dive.pos = b.dive.pos.lerp(target, dt * 4.0) + Vector2(60, 0) * dt
				if b.dive.pos.distance_to(target) < 8.0:
					b.dive = null
					b.flash = 1.0
			b.flash = maxf(0.0, b.flash - dt * 1.4)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	var pv: float = b.press_v
	CubeKit.stage(n, b)
	CubeKit.draw_cube(n, b)
	match b.id:
		"shower", "pixie":
			for p in b.parts:
				CubeKit.twinkle(n, p.pos, 3.0 * p.life,
					Color(0.94, 0.88, 1.0, maxf(0.0, sin(t * p.tw)) * p.life))
		"star_twirl":
			var a: float = t * 1.6
			_star(n, Vector2(c.x + cos(a) * c.s * 1.2, c.y - c.s * 0.5 + sin(a) * c.s * 0.7), 4.0, t * 3.0, 0.9)
			for f in b.flung:
				_star(n, f.pos, 5.0, f.rot, f.life)
		"glitter":
			if randf() < 0.1:
				CubeKit.twinkle(n, Vector2(c.x + randf_range(-c.s * 0.4, c.s * 0.4), c.y - c.s), 2.5, Color(1, 0.96, 1, 0.7))
			for p in b.parts:
				CubeKit.twinkle(n, p.pos, 3.0,
					Color.from_hsv(p.hue, 0.7, 1.0, maxf(0.0, sin(t * p.tw)) * p.life))
		"hearts":
			for p in b.parts:
				if p.kind == "ring":
					_heart(n, Vector2(c.x + cos(p.a) * p.r, c.y - c.s * 0.5 + sin(p.a) * p.r * 0.7), 4.0, p.life)
				else:
					_heart(n, p.pos, 4.5, p.life)
		"confetti":
			var sx: float = c.x + c.s * 0.4
			var pts := PackedVector2Array()
			for i in 7:
				pts.append(Vector2(sx + sin(t * 2.0 + i) * 4.0, c.y - c.s + i * 4.0))
			n.draw_polyline(pts, Color(1, 0.75, 0.47, 0.6), 2.0)
			for p in b.parts:
				n.draw_set_transform(p.pos, p.rot, Vector2.ONE)
				n.draw_rect(Rect2(-2.5, -1.5, 5, 3), Color.from_hsv(p.hue, 0.75, 0.95, p.life))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"shooting_star":
			for p in b.parts:
				n.draw_line(p.pos - Vector2(22, 8), p.pos, Color(1, 0.94, 0.78, p.life * 0.8), 1.5)
			if b.dive != null:
				CubeKit.glow(n, b.dive.pos, 6.0, Color(1, 0.96, 0.82, 0.95), 2)
			if b.flash > 0.0:
				CubeKit.glow(n, Vector2(c.x, c.y - c.s * 0.6), c.s * 1.6, Color(1, 0.96, 0.82, b.flash * 0.6), 3)
		"wreath":
			var cy: float = c.y - c.s * 1.35 + sin(t * 1.8) * 2.0
			for i in 5:
				var a: float = t * 0.8 + i / 5.0 * TAU
				CubeKit.twinkle(n, Vector2(c.x + cos(a) * c.s * 0.45, cy + sin(a) * 3.0),
					2.5 + pv * 4.0, Color(1, 0.92, 0.59, 0.6 + pv * 0.4))
			if pv > 0.0:
				for i in 5:
					var th := -PI / 2.0 + (i - 2) * 0.35
					n.draw_line(Vector2(c.x, cy),
						Vector2(c.x, cy) + Vector2(cos(th), sin(th)) * (14.0 + (1.0 - pv) * 26.0),
						Color(1, 0.92, 0.59, pv * 0.6), 1.6)

static func _star(n: CanvasItem, pos: Vector2, r: float, rot: float, a: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr: float = r if i % 2 == 0 else r * 0.45
		var th: float = rot + i / 10.0 * TAU
		pts.append(pos + Vector2(cos(th), sin(th)) * rr)
	n.draw_colored_polygon(pts, Color(1, 0.9, 0.55, a))

static func _heart(n: CanvasItem, pos: Vector2, s: float, a: float) -> void:
	var col := Color(1, 0.59, 0.75, a)
	n.draw_circle(pos + Vector2(-s * 0.5, 0), s * 0.55, col)
	n.draw_circle(pos + Vector2(s * 0.5, 0), s * 0.55, col)
	n.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-s, s * 0.2), pos + Vector2(0, s * 1.5), pos + Vector2(s, s * 0.2)]), col)
