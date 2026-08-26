extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
## EARTH & NATURE — eight cube effects, ported from the web codex.

const TITLE := "Earth & nature"
const BLURB := "rocks thrown, vines called, flowers left behind"
const DEFS := [
	{ "id": "rock_throw", "name": "Rock throw", "hint": "a pebble orbits, waiting; press to lob the real boulder" },
	{ "id": "vine_snare", "name": "Vine snare", "hint": "press: vines erupt where you click, writhe, and withdraw" },
	{ "id": "leaf_whirl", "name": "Leaf whirl", "hint": "leaves orbit like a green satellite belt; press for the storm" },
	{ "id": "boulder_shield", "name": "Boulder shield", "hint": "press: four rocks rise and orbit as armour for a while" },
	{ "id": "bloom_trail", "name": "Bloom trail", "hint": "flowers open in its footsteps; press for a whole garden" },
	{ "id": "sand_kick", "name": "Sand kick", "hint": "press: a spray of sand, straight at the opponent's eyes" },
	{ "id": "quake_slam", "name": "Quake slam", "hint": "press: fists down — a hump of ground ROLLS away from it" },
	{ "id": "thorn_wall", "name": "Thorn wall", "hint": "press: a fence of thorns rises ahead, holds, and sinks" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	match b.id:
		"leaf_whirl":
			b.leaves = []
			for i in 8:
				b.leaves.append({ "a": randf_range(0, TAU), "r": randf_range(0.9, 1.3),
					"v": randf_range(1.0, 1.8), "burst": 0.0 })
		"boulder_shield":
			b.armour = 0.0
		"bloom_trail":
			b.blooms = []
			b.last_x = b.cub.x
			b.travelled = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	match b.id:
		"rock_throw":
			b.parts.append({ "kind": "rock", "pos": Vector2(c.x + c.face * c.s * 0.5, c.y - c.s),
				"vel": Vector2(c.face * randf_range(120, 160), -170.0), "rot": 0.0, "life": 9.0 })
		"vine_snare":
			b.parts.append({ "kind": "snare", "x": clampf(pos.x, r.position.x + 10, r.position.x + r.size.x - 10), "life": 1.6 })
		"leaf_whirl":
			for l in b.leaves:
				l.burst = 1.0
		"boulder_shield":
			b.armour = 3.0
		"bloom_trail":
			for i in 6:
				b.blooms.append({ "x": clampf(c.x + randf_range(-c.s * 2.4, c.s * 2.4),
					r.position.x + 6, r.position.x + r.size.x - 6), "open": 0.0, "hue": randf_range(0.83, 1.0), "big": true })
		"sand_kick":
			c.lean = -c.face * 0.15
			for i in 20:
				b.parts.append({ "kind": "grain", "pos": Vector2(c.x + c.face * c.s * 0.4, b.G - 2.0),
					"vel": Vector2(c.face * randf_range(70, 180), randf_range(-110, -30)), "life": 1.0 })
		"quake_slam":
			b.parts.append({ "kind": "hump", "x": c.x, "dir": c.face, "life": 1.0 })
		"thorn_wall":
			b.parts.append({ "kind": "wall", "x": c.x + c.face * c.s * 1.8, "life": 2.2 })

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	b.press_v = maxf(0.0, b.press_v - dt * 1.6)
	match b.id:
		"rock_throw":
			for p in b.parts:
				if p.kind == "rock":
					p.pos += p.vel * dt
					p.vel.y += 340.0 * dt
					p.rot += 4.0 * dt
					if p.pos.y >= b.G - 4.0:
						for i in 7:
							b.parts.append({ "kind": "shard", "pos": Vector2(p.pos.x, b.G),
								"vel": Vector2(randf_range(-80, 80), randf_range(-120, -30)), "life": 1.0 })
						p.life = 0.0
				else:
					p.pos += p.vel * dt
					p.vel.y += 300.0 * dt
					p.life -= dt * 1.5
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"vine_snare", "thorn_wall":
			for p in b.parts:
				p.life -= dt * (0.7 if b.id == "vine_snare" else 0.6)
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"leaf_whirl":
			for l in b.leaves:
				l.burst = maxf(0.0, l.burst - dt * 0.7)
				l.a += l.v * (1.0 + l.burst * 3.0) * dt
		"boulder_shield":
			b.armour = maxf(0.0, b.armour - dt)
		"bloom_trail":
			b.travelled += absf(c.x - b.last_x)
			b.last_x = c.x
			while b.travelled > 26.0:
				b.travelled -= 26.0
				b.blooms.append({ "x": c.x, "open": 0.0, "hue": randf_range(0.83, 1.0), "big": false })
			for bl in b.blooms:
				bl.open = minf(1.0, bl.open + dt * (3.0 if bl.big else 1.2))
			while b.blooms.size() > 20:
				b.blooms.pop_front()
		"sand_kick":
			if randf() < 0.08:
				b.parts.append({ "kind": "grain", "pos": Vector2(c.x + randf_range(-c.s * 0.4, c.s * 0.4), c.y - c.s),
					"vel": Vector2(0, 20), "life": 0.8 })
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += 300.0 * dt
				p.pos.y = minf(p.pos.y, b.G)
				p.life -= dt * 1.4
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"quake_slam":
			var r: Rect2 = b.rect
			for p in b.parts:
				p.x += p.dir * 120.0 * dt
				p.life -= dt * 0.8
			b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.x > r.position.x - 20 and p.x < r.position.x + r.size.x + 20)
			# the hero rides its own quake
			var lift := 0.0
			for p in b.parts:
				lift = maxf(lift, maxf(0.0, 10.0 - absf(c.x - p.x) * 0.4) * p.life)
			c.y = b.G - lift

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	CubeKit.stage(n, b)
	match b.id:
		"rock_throw":
			CubeKit.draw_cube(n, b)
			var pa: float = t * 2.4
			n.draw_circle(Vector2(c.x + cos(pa) * c.s * 0.9, c.y - c.s * 0.6 + sin(pa) * c.s * 0.5),
				2.5, Color(0.48, 0.43, 0.37))
			for p in b.parts:
				if p.kind == "rock":
					n.draw_set_transform(p.pos, p.rot, Vector2.ONE)
					n.draw_colored_polygon(PackedVector2Array([
						Vector2(-6, -4), Vector2(5, -6), Vector2(7, 3), Vector2(-2, 6), Vector2(-7, 2)]),
						Color(0.48, 0.43, 0.37))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				else:
					n.draw_rect(Rect2(p.pos, Vector2(2.5, 2.5)), Color(0.48, 0.43, 0.37, p.life))
		"vine_snare":
			CubeKit.draw_cube(n, b)
			n.draw_set_transform(Vector2(c.x + c.s * 0.25, c.y - c.s - c.hop), 0.5 + sin(t * 2.0) * 0.15, Vector2(1.0, 0.45))
			n.draw_circle(Vector2(3, 0), 4.0, Color(0.43, 0.7, 0.43, 0.9))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for p in b.parts:
				var up: float = sin(minf(1.0, (1.6 - p.life) * 2.0) * PI * 0.5) * minf(1.0, p.life * 1.8)
				for v in range(-1, 2):
					var pts := PackedVector2Array()
					pts.append(Vector2(p.x + v * 5.0, b.G))
					for k in range(1, 7):
						var q := k / 6.0
						pts.append(Vector2(p.x + v * 5.0 + sin(q * 5.0 + t * 6.0 + v * 2.0) * 6.0 * q,
							b.G - up * c.s * 1.8 * q))
					n.draw_polyline(pts, Color(0.35, 0.63, 0.35, minf(1.0, p.life)), 3.0)
		"leaf_whirl":
			CubeKit.draw_cube(n, b)
			for l in b.leaves:
				var rr: float = c.s * l.r * (1.0 + l.burst * 1.4)
				n.draw_set_transform(Vector2(c.x + cos(l.a) * rr, c.y - c.s * 0.5 + sin(l.a) * rr * 0.55),
					l.a + t, Vector2(1.0, 0.45))
				n.draw_circle(Vector2.ZERO, 4.0, Color(0.47, 0.73, 0.43, 0.85))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"boulder_shield":
			n.draw_set_transform(Vector2(c.x, b.G + 2.0), 0.0, Vector2(1.0, 0.2))
			n.draw_circle(Vector2.ZERO, c.s * 0.9, Color(0.59, 0.53, 0.47, 0.15))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			CubeKit.draw_cube(n, b)
			if b.armour > 0.0:
				var rise: float = minf(1.0, (3.0 - b.armour) * 3.0)
				for i in 4:
					var a: float = t * 2.2 + i / 4.0 * TAU
					n.draw_set_transform(Vector2(c.x + cos(a) * c.s * 1.15,
						c.y - c.s * 0.5 * rise + sin(a) * c.s * 0.5 + (1.0 - rise) * 10.0), a, Vector2.ONE)
					n.draw_colored_polygon(PackedVector2Array([
						Vector2(-5, -3), Vector2(4, -5), Vector2(6, 3), Vector2(-3, 5)]),
						Color(0.48, 0.43, 0.37, minf(1.0, b.armour)))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"bloom_trail":
			for bl in b.blooms:
				var s: float = (5.0 if bl.big else 3.5) * bl.open
				for p in 5:
					var th: float = p / 5.0 * TAU - PI / 2.0
					n.draw_set_transform(Vector2(bl.x + cos(th) * s * 0.7, b.G - 2.0 + sin(th) * s * 0.4),
						th, Vector2(1.0, 0.55))
					n.draw_circle(Vector2.ZERO, s * 0.5, Color.from_hsv(bl.hue, 0.35, 0.95, 0.9))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				n.draw_circle(Vector2(bl.x, b.G - 2.0), s * 0.3, Color(1, 0.92, 0.59, 0.95))
			CubeKit.draw_cube(n, b)
		"sand_kick":
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				n.draw_rect(Rect2(p.pos, Vector2(1.6, 1.6)), Color(0.82, 0.73, 0.55, p.life * 0.8))
		"quake_slam":
			# repaint the floor with the wave in it
			var r: Rect2 = b.rect
			var pts := PackedVector2Array()
			var x: float = r.position.x
			while x <= r.position.x + r.size.x:
				var y: float = b.G
				for p in b.parts:
					y -= maxf(0.0, 10.0 - absf(x - p.x) * 0.4) * p.life
				pts.append(Vector2(x, y))
				x += 4.0
			n.draw_polyline(pts, Color(0.59, 0.57, 0.75, 0.35), 1.0)
			CubeKit.draw_cube(n, b)
		"thorn_wall":
			CubeKit.draw_cube(n, b)
			for i in range(-1, 2):
				n.draw_line(Vector2(c.x + i * 10.0, b.G),
					Vector2(c.x + i * 10.0 + 2.0, b.G - 4.0 - sin(t * 2.0 + i) * 1.0),
					Color(0.43, 0.59, 0.35, 0.5), 1.5)
			for p in b.parts:
				var up: float = minf(1.0, minf((2.2 - p.life) * 2.4, p.life * 2.0))
				for i in range(-2, 3):
					var hgt: float = (c.s * 1.5 - absf(i) * 6.0) * up
					n.draw_colored_polygon(PackedVector2Array([
						Vector2(p.x + i * 9.0 - 4.0, b.G), Vector2(p.x + i * 9.0, b.G - hgt),
						Vector2(p.x + i * 9.0 + 4.0, b.G)]),
						Color(0.37, 0.55, 0.31, minf(1.0, p.life)))
