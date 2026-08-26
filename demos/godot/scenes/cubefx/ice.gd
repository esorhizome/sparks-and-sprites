extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
## ICE — six cube effects, ported from the web codex.

const TITLE := "Ice"
const BLURB := "shards, armor, and ground that freezes over"
const DEFS := [
	{ "id": "shards", "name": "Ice shards", "hint": "frost breath while it waits; press for the shard volley" },
	{ "id": "armor", "name": "Frost armor", "hint": "press to TOGGLE the armor — an ice shell with honest glints" },
	{ "id": "freeze_stomp", "name": "Freeze stomp", "hint": "press: ice crystallises across the floor from its feet" },
	{ "id": "snow_aura", "name": "Snow aura", "hint": "its own private snowfall; press for the flurry" },
	{ "id": "icicle", "name": "Icicle drop", "hint": "press: icicles form where you click, then fall and shatter" },
	{ "id": "wall", "name": "Glacial wall", "hint": "press: a wall of ice rises ahead — then melts, drip by drip" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	match b.id:
		"shards":
			b.breath = 0.0
		"armor":
			b.on = false

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	match b.id:
		"shards":
			for i in 5:
				b.parts.append({ "kind": "shard", "pos": Vector2(c.x + c.face * c.s * 0.5, c.y - c.s * 0.6 + randf_range(-6, 6)),
					"vel": Vector2(c.face * randf_range(160, 220), randf_range(-20, 20)), "rot": 0.0, "life": 1.2 })
		"armor":
			b.on = not b.on
		"freeze_stomp":
			b.parts.append({ "kind": "sheet", "x": c.x, "spread": 4.0, "life": 1.0 })
		"snow_aura":
			b.press_v = 1.4
		"icicle":
			for i in 3:
				b.parts.append({ "kind": "icicle", "pos": Vector2(clampf(pos.x, r.position.x + 8, r.position.x + r.size.x - 8) + (i - 1) * 12.0,
					maxf(pos.y, r.position.y + 12.0)), "form": 0.0, "vy": 0.0 })
		"wall":
			b.parts.append({ "kind": "wall", "x": c.x + c.face * c.s * 1.9, "life": 3.0 })

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	b.press_v = maxf(0.0, b.press_v - dt)
	match b.id:
		"shards":
			b.breath += dt
			if b.breath > 2.4:
				b.breath = 0.0
			for p in b.parts:
				p.pos += p.vel * dt
				p.rot += 6.0 * dt
				p.life -= dt
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"armor":
			c.tint = Color(0.24, 0.35, 0.5) if b.on else null
		"freeze_stomp":
			for p in b.parts:
				p.spread += 110.0 * dt
				p.life -= dt * 0.35
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"snow_aura":
			if randf() < 0.25 + (0.6 if b.press_v > 0.0 else 0.0):
				b.parts.append({ "kind": "flake", "pos": Vector2(c.x + randf_range(-c.s * 1.4, c.s * 1.4), c.y - c.s * 2.0),
					"ph": randf_range(0, 9), "life": 1.0 })
			for p in b.parts:
				p.pos.y += 32.0 * dt
				p.pos.x += sin(t * 2.0 + p.ph) * 10.0 * dt + (c.x - p.pos.x) * dt * 0.4
				p.life -= dt * 0.5
			b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.pos.y < b.G)
		"icicle":
			for p in b.parts:
				if p.kind == "icicle":
					if p.form < 1.0:
						p.form += dt * 2.4
					else:
						p.vy += 500.0 * dt
						p.pos.y += p.vy * dt
					if p.pos.y >= b.G - 6.0:
						for i in 5:
							b.parts.append({ "kind": "bit", "pos": Vector2(p.pos.x, b.G),
								"vel": Vector2(randf_range(-60, 60), randf_range(-90, -20)), "life": 1.0 })
						p.pos.y = 1e9
				else:
					p.pos += p.vel * dt
					p.vel.y += 280.0 * dt
					p.life -= dt * 1.6
			b.parts = b.parts.filter(func(p): return (p.kind == "icicle" and p.pos.y < 1e8) or (p.kind == "bit" and p.life > 0.0))
		"wall":
			var drips := []
			for p in b.parts:
				if p.kind == "wall":
					p.life -= dt * 0.7
					var hgt: float = c.s * 1.6 * minf(1.0, (3.0 - p.life) * 3.0) * minf(1.0, p.life)
					if p.life > 0.0 and randf() < 0.3:
						drips.append({ "kind": "drip", "pos": Vector2(p.x + randf_range(-12, 12), b.G - randf_range(0, hgt)),
							"vel": Vector2.ZERO, "life": 1.0 })
				else:
					p.pos.y += 60.0 * dt
					p.life -= dt * 2.0
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
			b.parts.append_array(drips)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	CubeKit.stage(n, b)
	match b.id:
		"shards":
			CubeKit.draw_cube(n, b)
			if b.breath < 0.6:
				for i in 2:
					CubeKit.glow(n, Vector2(c.x + c.face * (c.s * 0.5 + b.breath * 30.0 + randf_range(0, 6)),
						c.y - c.s * 0.6 + randf_range(-4, 4)), 4.0, Color(0.78, 0.92, 1.0, 0.14), 2)
			for p in b.parts:
				n.draw_set_transform(p.pos, p.rot, Vector2.ONE)
				n.draw_colored_polygon(PackedVector2Array([Vector2(6, 0), Vector2(-4, 2.5), Vector2(-4, -2.5)]),
					Color(0.75, 0.88, 1.0, 0.9))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"armor":
			CubeKit.draw_cube(n, b)
			if b.on:
				n.draw_set_transform(Vector2(c.x, c.y - c.hop), c.lean, Vector2.ONE)
				n.draw_rect(Rect2(-c.s / 2.0 - 3.0, -c.s - 3.0, c.s + 6.0, c.s + 6.0),
					Color(0.78, 0.92, 1.0, 0.8), false, 2.5)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				if randf() < 0.1:
					CubeKit.twinkle(n, Vector2(c.x + randf_range(-c.s, c.s) * 0.5, c.y - randf_range(0, c.s)),
						3.0, Color(1, 1, 1, 0.9))
		"freeze_stomp":
			for p in b.parts:
				var a: float = minf(1.0, p.life * 2.0) * 0.5
				n.draw_rect(Rect2(p.x - p.spread, b.G, p.spread * 2.0, 5.0), Color(0.67, 0.84, 0.98, a * 0.5))
				var x: float = -p.spread
				while x < p.spread:
					n.draw_polyline(PackedVector2Array([
						Vector2(p.x + x, b.G),
						Vector2(p.x + x + 4.0, b.G - randf_range(3, 8) * minf(1.0, p.life * 2.0)),
						Vector2(p.x + x + 8.0, b.G)]), Color(0.82, 0.94, 1.0, a), 1.0)
					x += 14.0
			CubeKit.draw_cube(n, b)
		"snow_aura":
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				n.draw_circle(p.pos, 1.5, Color(0.92, 0.96, 1.0, p.life * 0.8))
		"icicle":
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				if p.kind == "icicle":
					n.draw_colored_polygon(PackedVector2Array([
						p.pos + Vector2(-3, 0), p.pos + Vector2(3, 0), p.pos + Vector2(0, 12.0 * p.form)]),
						Color(0.75, 0.88, 1.0, 0.9 * minf(1.0, p.form)))
				else:
					n.draw_rect(Rect2(p.pos, Vector2(2, 2)), Color(0.82, 0.94, 1.0, p.life))
		"wall":
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				if p.kind != "wall":
					n.draw_rect(Rect2(p.pos, Vector2(1.5, 3)), Color(0.75, 0.88, 0.98, p.life))
					continue
				var up: float = minf(1.0, (3.0 - p.life) * 3.0)
				var melt: float = minf(1.0, p.life)
				var hgt: float = c.s * 1.6 * up * melt
				n.draw_rect(Rect2(p.x - 12.0, b.G - hgt, 24.0, maxf(1.0, hgt)), Color(0.63, 0.8, 0.96, 0.5))
				n.draw_rect(Rect2(p.x - 12.0, b.G - hgt, 24.0, maxf(1.0, hgt)), Color(0.86, 0.94, 1.0, 0.7), false, 1.5)
