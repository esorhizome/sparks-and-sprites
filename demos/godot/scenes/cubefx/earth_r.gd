extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
const Base := preload("res://scenes/cubefx/earth.gd")
## EARTH & NATURE — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"rock_throw": { "name": "Snowball throw", "hint": "it splats instead of shattering, and leaves a mark" },
	"vine_snare": { "name": "Chain snare", "hint": "cold iron — links, not leaves, and no sway" },
	"leaf_whirl": { "name": "Stone belt", "hint": "pebbles — heavier, lower, slower" },
	"boulder_shield": { "name": "Leaf shield", "hint": "foliage — lighter, higher, briefer" },
	"bloom_trail": { "name": "Frost trail", "hint": "six-point frost stars instead of flowers" },
	"sand_kick": { "name": "Snow kick", "hint": "winter — the powder hangs in the air longer" },
	"quake_slam": { "name": "Wave slam", "hint": "a rolling hump of water — taller, softer, spray" },
	"thorn_wall": { "name": "Ice fence", "hint": "glass-blue — it melts down instead of sinking" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)
	if b.id == "leaf_whirl":
		for l in b.leaves:          # heavier, lower, slower
			l.v *= 0.5
	if b.id == "rock_throw":
		b.marks = []

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"boulder_shield":
			b.armour = 1.8          # briefer
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"rock_throw":
			# dial: the impact SPLATS — no shards, a lingering mark
			b.press_v = maxf(0.0, b.press_v - dt * 1.6)
			for p in b.parts:
				if p.kind == "rock":
					p.pos += p.vel * dt
					p.vel.y += 340.0 * dt
					p.rot += 4.0 * dt
					if p.pos.y >= b.G - 4.0:
						b.marks.append({ "x": p.pos.x, "life": 1.0 })
						for i in 4:
							b.parts.append({ "kind": "shard", "pos": Vector2(p.pos.x, b.G),
								"vel": Vector2(randf_range(-40, 40), randf_range(-60, -15)), "life": 0.6 })
						p.life = 0.0
				else:
					p.pos += p.vel * dt
					p.vel.y += 300.0 * dt
					p.life -= dt * 1.5
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
			for m in b.marks:
				m.life -= dt * 0.15
			b.marks = b.marks.filter(func(m): return m.life > 0.0)
		"sand_kick":
			# dial: gravity 300 → 60, decay 1.4 → 0.7 — powder hangs
			b.press_v = maxf(0.0, b.press_v - dt * 1.6)
			if randf() < 0.08:
				b.parts.append({ "kind": "grain", "pos": Vector2(c.x + randf_range(-c.s * 0.4, c.s * 0.4), c.y - c.s),
					"vel": Vector2(0, 12), "life": 0.8 })
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += 60.0 * dt
				p.pos.y = minf(p.pos.y, b.G)
				p.life -= dt * 0.7
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"quake_slam":
			# dials: hump speed ÷2 · lift ×1.6 (taller, softer)
			b.press_v = maxf(0.0, b.press_v - dt * 1.6)
			var r: Rect2 = b.rect
			for p in b.parts:
				p.x += p.dir * 70.0 * dt
				p.life -= dt * 0.6
			b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.x > r.position.x - 20 and p.x < r.position.x + r.size.x + 20)
			var lift := 0.0
			for p in b.parts:
				lift = maxf(lift, maxf(0.0, 16.0 - absf(c.x - p.x) * 0.4) * p.life)
			c.y = b.G - lift
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"rock_throw":
			CubeKit.stage(n, b)
			for m in b.marks:              # the splat marks, under everything
				n.draw_set_transform(Vector2(m.x, b.G + 1.0), 0.0, Vector2(1.0, 0.3))
				n.draw_circle(Vector2.ZERO, 7.0, Color(0.94, 0.96, 1.0, m.life * 0.6))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			CubeKit.draw_cube(n, b)
			var pa: float = t * 2.4
			n.draw_circle(Vector2(c.x + cos(pa) * c.s * 0.9, c.y - c.s * 0.6 + sin(pa) * c.s * 0.5),
				2.5, Color(0.94, 0.96, 1.0))
			for p in b.parts:
				if p.kind == "rock":
					n.draw_circle(p.pos, 5.0, Color(0.94, 0.96, 1.0))
					n.draw_circle(p.pos - Vector2(1.5, 1.5), 1.6, Color(1, 1, 1))
				else:
					n.draw_rect(Rect2(p.pos, Vector2(2.2, 2.2)), Color(0.92, 0.95, 1.0, p.life))
		"vine_snare":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				# dial: sinuous vines → straight chain links, no sway
				var up: float = sin(minf(1.0, (1.6 - p.life) * 2.0) * PI * 0.5) * minf(1.0, p.life * 1.8)
				for v in range(-1, 2):
					var top := Vector2(p.x + v * 6.0, b.G - up * c.s * 1.8)
					var k := 0
					var y: float = b.G
					while y > top.y:
						CubeKit.ellipse(n, Vector2(p.x + v * 6.0 + (1.5 if k % 2 == 0 else -1.5), y),
							2.2, 3.2, Color(0.55, 0.59, 0.67, minf(1.0, p.life)), 1.2, 0, TAU, 8)
						y -= 6.0
						k += 1
		"leaf_whirl":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for l in b.leaves:
				var rr: float = c.s * l.r * (0.85 + l.burst * 1.0)
				var pos := Vector2(c.x + cos(l.a) * rr, c.y - c.s * 0.25 + sin(l.a) * rr * 0.4)
				n.draw_set_transform(pos, l.a, Vector2.ONE)
				n.draw_colored_polygon(PackedVector2Array([
					Vector2(-3, -2), Vector2(2.5, -3), Vector2(3.5, 2), Vector2(-2, 3)]),
					Color(0.48, 0.45, 0.42, 0.9))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"boulder_shield":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			if b.armour > 0.0:
				var rise: float = minf(1.0, (1.8 - b.armour) * 3.0)
				for i in 4:
					var a: float = t * 2.8 + i / 4.0 * TAU
					n.draw_set_transform(Vector2(c.x + cos(a) * c.s * 1.15,
						c.y - c.s * 0.85 * rise + sin(a) * c.s * 0.5 + (1.0 - rise) * 10.0), a + t, Vector2(1.0, 0.5))
					n.draw_circle(Vector2.ZERO, 4.2, Color(0.47, 0.73, 0.43, minf(1.0, b.armour * 1.4) * 0.9))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"bloom_trail":
			CubeKit.stage(n, b)
			for bl in b.blooms:
				var s: float = (5.0 if bl.big else 3.5) * bl.open
				for p in 6:                # six-point frost stars
					var th: float = p / 6.0 * TAU
					n.draw_line(Vector2(bl.x, b.G - 2.0),
						Vector2(bl.x + cos(th) * s * 1.2, b.G - 2.0 + sin(th) * s * 0.7),
						Color(0.78, 0.92, 1.0, 0.85), 1.0)
				n.draw_circle(Vector2(bl.x, b.G - 2.0), s * 0.25, Color(0.94, 0.98, 1.0, 0.95))
			CubeKit.draw_cube(n, b)
		"sand_kick":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				n.draw_circle(p.pos, 1.6, Color(0.94, 0.96, 1.0, p.life * 0.8))
		"quake_slam":
			# repaint the floor as a water line with the taller hump in it
			var r: Rect2 = b.rect
			CubeKit.stage(n, b)
			var pts := PackedVector2Array()
			var x: float = r.position.x
			while x <= r.position.x + r.size.x:
				var y: float = b.G
				for p in b.parts:
					y -= maxf(0.0, 16.0 - absf(x - p.x) * 0.4) * p.life
				pts.append(Vector2(x, y))
				x += 4.0
			n.draw_polyline(pts, Color(0.55, 0.8, 0.96, 0.6), 1.6)
			for p in b.parts:              # spray off the crest
				if randf() < 0.4:
					n.draw_circle(Vector2(p.x + randf_range(-4, 4), b.G - 16.0 * p.life - randf_range(0, 6)),
						1.2, Color(0.78, 0.92, 1.0, p.life * 0.8))
			CubeKit.draw_cube(n, b)
		"thorn_wall":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				# dial: thorns → ice pickets that MELT down (height decays with life)
				var up: float = minf(1.0, (2.2 - p.life) * 2.4) * minf(1.0, p.life * 1.2)
				for i in range(-2, 3):
					var hgt: float = (c.s * 1.5 - absf(i) * 6.0) * up
					n.draw_colored_polygon(PackedVector2Array([
						Vector2(p.x + i * 9.0 - 4.0, b.G), Vector2(p.x + i * 9.0, b.G - hgt),
						Vector2(p.x + i * 9.0 + 4.0, b.G)]),
						Color(0.71, 0.88, 1.0, minf(1.0, p.life) * 0.8))
					if hgt > 4.0:
						n.draw_circle(Vector2(p.x + i * 9.0, b.G - 1.0), 1.4,   # the melt drip
							Color(0.86, 0.95, 1.0, minf(1.0, p.life)))
		_:
			Base.draw(n, b, t)
