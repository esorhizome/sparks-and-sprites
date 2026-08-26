extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
const Base := preload("res://scenes/cubefx/impact.gd")
## IMPACTS & HITS — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"hit_spark": { "name": "Ice hit", "hint": "the star-flash frozen — it shatters into hanging shards" },
	"combo": { "name": "Damage numbers", "hint": "the escalation as RPG numbers drifting off the hit" },
	"shockwave": { "name": "Twin shockwave", "hint": "the ring sent BOTH ways — the lunge stays home" },
	"block": { "name": "Iron wall", "hint": "the guard wide and heavy — dust falls where sparks flew" },
	"parry": { "name": "Crimson counter", "hint": "danger red — the freeze lasts longer" },
	"knockback": { "name": "Launcher", "hint": "aimed UP — juggle-state, then the landing" },
	"ground_crack": { "name": "Frost crack", "hint": "veined with GLOWING ice — heals twice as fast" },
	"stomp": { "name": "Ripple stomp", "hint": "on water — rings roll out instead of dust humps" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)
	if b.id == "knockback":
		b.vy = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"hit_spark":
			# dial: the flash leaves hanging shards behind
			b.press_v = 1.0
			var at := Vector2(pos.x, minf(pos.y, b.G - 4.0))
			b.parts.append({ "kind": "star", "pos": at, "life": 1.0, "rot": randf_range(0, TAU) })
			for i in 7:
				var th := randf_range(0, TAU)
				b.parts.append({ "kind": "shard", "pos": at + Vector2(cos(th), sin(th)) * 6.0,
					"vel": Vector2(cos(th), sin(th)) * randf_range(10, 30), "rot": th, "life": 1.5 })
		"combo":
			# dial: each press mints a drifting damage number
			b.combo += 1
			b.press_v = 1.0
			b.cool = 1.6
			b.parts.append({ "kind": "num", "pos": Vector2(c.x + c.face * c.s * 0.9, c.y - c.s * 0.8),
				"val": 40 + b.combo * 17 + randi() % 20, "life": 1.0 })
		"shockwave":
			# dials: rings both ways · lunge and shake deleted
			b.press_v = 1.0
			b.shake = 0.0
			b.parts.append({ "kind": "ring", "x": c.x + c.s * 0.9, "dir": 1.0, "r": 6.0, "life": 1.0 })
			b.parts.append({ "kind": "ring", "x": c.x - c.s * 0.9, "dir": -1.0, "r": 6.0, "life": 1.0 })
		"knockback":
			# dial: the hit sends it UP, not back
			if b.tumble < 0.0:
				b.tumble = 0.0
				c.pace = false
				c.vx = -c.face * 40.0
				b.vy = -260.0
				for i in 5:
					b.parts.append({ "kind": "dizzy", "a": randf_range(0, TAU), "life": 1.4 })
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"hit_spark":
			b.press_v = maxf(0.0, b.press_v - dt * 3.0)
			if b.press_v > 0.0:
				c.lean = c.face * 0.18 * b.press_v
			for p in b.parts:
				if p.kind == "star":
					p.life -= dt * 3.0
				else:
					p.pos += p.vel * dt
					p.vel *= pow(0.15, dt)      # shards hang
					p.life -= dt * 0.8
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"combo":
			b.press_v = maxf(0.0, b.press_v - dt * 3.0)
			if b.cool > 0.0:
				b.cool -= dt
				if b.cool <= 0.0:
					b.combo = 0
			for p in b.parts:
				p.pos += Vector2(10.0, -26.0) * dt
				p.life -= dt * 0.9
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"parry":
			# dial: the freeze decays at half rate
			b.press_v = maxf(0.0, b.press_v - dt * 1.2)
		"knockback":
			var r: Rect2 = b.rect
			if b.tumble >= 0.0:
				b.tumble += dt
				c.vx *= pow(0.1, dt)
				b.vy += 620.0 * dt
				c.y = minf(b.G, c.y + b.vy * dt)
				c.spin = -c.face * minf(1.0, b.tumble * 2.0) * TAU
				c.x = clampf(c.x, r.position.x + c.s, r.position.x + r.size.x - c.s)
				if c.y >= b.G and b.tumble > 0.4:
					b.tumble = -1.0
					b.vy = 0.0
					c.spin = 0.0
					c.pace = true
			for p in b.parts:
				p.a += 5.0 * dt
				p.life -= dt
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"ground_crack":
			# dial: heal 0.25 → 0.5
			for p in b.parts:
				if p.kind == "crack":
					p.life -= dt * 0.5
				else:
					p.pos += p.vel * dt
					p.vel.y += 300.0 * dt
					p.life -= dt * 1.4
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"stomp":
			# dial: dust humps → water rings that widen as they travel
			if b.hop >= 0.0:
				b.hop += dt * 3.0
				c.y = b.G - sin(minf(1.0, b.hop) * PI) * c.s * 0.7
				if b.hop >= 1.0:
					c.y = b.G
					b.hop = -1.0
					b.parts.append({ "kind": "wave", "x": c.x, "dir": 1.0, "life": 1.0 })
					b.parts.append({ "kind": "wave", "x": c.x, "dir": -1.0, "life": 1.0 })
			for p in b.parts:
				p.x += p.dir * 90.0 * dt
				p.life -= dt * 0.8
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	var pv: float = b.press_v
	match b.id:
		"hit_spark":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				if p.kind == "star":
					var pts := PackedVector2Array()
					for i in 8:
						var rr: float = 16.0 * (1.4 - p.life) if i % 2 == 0 else 5.0
						var th: float = p.rot + i / 8.0 * TAU
						pts.append(p.pos + Vector2(cos(th), sin(th)) * rr)
					n.draw_colored_polygon(pts, Color(0.78, 0.92, 1.0, p.life))
				else:
					n.draw_set_transform(p.pos, p.rot, Vector2.ONE)
					n.draw_colored_polygon(PackedVector2Array([Vector2(0, -4), Vector2(2.5, 3), Vector2(-2.5, 3)]),
						Color(0.71, 0.9, 1.0, minf(1.0, p.life) * 0.85))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"combo":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				n.draw_string(ThemeDB.fallback_font, p.pos, str(p.val),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
					Color(1, 0.86, 0.39, minf(1.0, p.life * 1.4)))
			if b.combo > 1:
				n.draw_string(ThemeDB.fallback_font, Vector2(c.x - 40, c.y - c.s * 1.7), "x%d" % b.combo,
					HORIZONTAL_ALIGNMENT_CENTER, 80, 11, Color(0.9, 0.9, 0.96, 0.8))
		"shockwave":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				CubeKit.ellipse(n, Vector2(p.x, c.y - c.s * 0.5), p.r * 0.5, p.r,
					Color(0.9, 0.88, 1.0, p.life * 0.8), 3.0)
		"block":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			if pv > 0.0:
				# dial: the thin guard line → a wide iron slab
				var gx: float = c.x + c.face * c.s * 1.05
				n.draw_rect(Rect2(Vector2(gx - 4.0, c.y - c.s * 1.15), Vector2(8.0, c.s * 1.2)),
					Color(0.45, 0.47, 0.55, minf(1.0, pv * 1.4)))
				n.draw_rect(Rect2(Vector2(gx - 4.0, c.y - c.s * 1.15), Vector2(8.0, c.s * 1.2)),
					Color(0.71, 0.75, 0.84, minf(1.0, pv)), false, 1.5)
			for p in b.parts:              # dust falls where sparks flew
				n.draw_circle(Vector2(p.pos.x, minf(p.pos.y, b.G)), 2.5 * (1.5 - p.life),
					Color(0.59, 0.55, 0.51, p.life * 0.5))
		"parry":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			if pv > 0.0:
				if pv > 0.6:
					n.draw_rect(b.rect, Color(1.0, 0.35, 0.31, (pv - 0.6) * 1.2))
				var rr: float = (1.0 - pv) * c.s * 1.6 + 6.0
				CubeKit.ellipse(n, Vector2(c.x + c.face * c.s * 0.6, c.y - c.s * 0.55),
					rr, rr * 1.2, Color(1, 0.39, 0.35, pv), 2.5)
		"ground_crack":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				if p.kind == "crack":
					for segs in p.rays:
						var pts := PackedVector2Array()
						for s in segs:
							pts.append(s)
						n.draw_polyline(pts, Color(0.63, 0.88, 1.0, minf(1.0, p.life * 2.0)), 2.4)
						n.draw_polyline(pts, Color(0.86, 0.96, 1.0, minf(1.0, p.life)), 1.0)
				else:
					n.draw_rect(Rect2(p.pos, Vector2(2.5, 2.5)), Color(0.71, 0.88, 1.0, p.life))
		"stomp":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				var spread: float = (1.0 - p.life) * 14.0
				CubeKit.ellipse(n, Vector2(p.x, b.G + 1.0), 8.0 + spread, (8.0 + spread) * 0.25,
					Color(0.55, 0.8, 0.96, p.life * 0.7), 1.6)
		_:
			Base.draw(n, b, t)
