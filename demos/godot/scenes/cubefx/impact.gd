extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
## IMPACTS & HITS — eight cube effects, ported from the web codex.

const TITLE := "Impacts & hits"
const BLURB := "the fighting game's punctuation marks"
const DEFS := [
	{ "id": "hit_spark", "name": "Hit spark", "hint": "it shadowboxes; press for the classic star-flash where you click" },
	{ "id": "combo", "name": "Combo counter", "hint": "press repeatedly — the counter pops bigger with every hit" },
	{ "id": "shockwave", "name": "Shockwave punch", "hint": "press: a lunge and a ring of force rolls out ahead" },
	{ "id": "block", "name": "Block clang", "hint": "press: guard up — the CLANG says the block held" },
	{ "id": "parry", "name": "Parry flash", "hint": "press: the one-frame white flash every fighting game player knows" },
	{ "id": "knockback", "name": "Knockback", "hint": "press: something hits IT — tumble, skid, proud recovery" },
	{ "id": "ground_crack", "name": "Ground crack", "hint": "press: one punch down — the floor remembers it a while" },
	{ "id": "stomp", "name": "Stomp quake", "hint": "press: a stomp sends dust waves rolling both ways" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	match b.id:
		"combo":
			b.combo = 0
			b.cool = 0.0
		"shockwave":
			b.shake = 0.0
		"knockback":
			b.tumble = -1.0
		"stomp":
			b.hop = -1.0

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"hit_spark":
			b.press_v = 1.0
			b.parts.append({ "kind": "star", "pos": Vector2(pos.x, minf(pos.y, b.G - 4.0)),
				"life": 1.0, "rot": randf_range(0, TAU) })
		"combo":
			b.combo += 1
			b.press_v = 1.0
			b.cool = 1.6
		"shockwave":
			b.press_v = 1.0
			b.shake = 0.7
			b.parts.append({ "kind": "ring", "x": c.x + c.face * c.s * 0.9, "dir": c.face, "r": 6.0, "life": 1.0 })
		"block":
			b.press_v = 1.0
			for i in 6:
				var th := randf_range(-1.2, 1.2)
				b.parts.append({ "kind": "shard", "pos": Vector2(c.x + c.face * c.s * 0.8, c.y - c.s * 0.55),
					"vel": Vector2(c.face * cos(th) * randf_range(60, 140), sin(th) * 120.0),
					"rot": randf_range(0, TAU), "life": 1.0 })
		"parry":
			b.press_v = 1.0
		"knockback":
			if b.tumble < 0.0:
				b.tumble = 0.0
				c.pace = false
				c.vx = -c.face * 220.0
				for i in 5:
					b.parts.append({ "kind": "dizzy", "a": randf_range(0, TAU), "life": 1.4 })
		"ground_crack":
			var cx: float = c.x + c.face * c.s * 0.7
			var rays := []
			for i in 5:
				var dir := randf_range(0, TAU)
				var segs := [Vector2(cx, b.G)]
				var px := cx
				for k in 3:
					px += cos(dir) * randf_range(8, 18)
					segs.append(Vector2(px, b.G + absf(sin(dir)) * randf_range(2, 8) * (k + 1) * 0.4))
				rays.append(segs)
			b.parts.append({ "kind": "crack", "rays": rays, "life": 1.0 })
			for i in 8:
				b.parts.append({ "kind": "debris", "pos": Vector2(cx, b.G),
					"vel": Vector2(randf_range(-70, 70), randf_range(-140, -40)), "life": 1.0 })
		"stomp":
			if b.hop < 0.0:
				b.hop = 0.0

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	b.press_v = maxf(0.0, b.press_v - dt * (2.4 if b.id == "parry" else 3.0))
	match b.id:
		"hit_spark":
			if b.press_v > 0.0:
				c.lean = c.face * 0.18 * b.press_v
			elif randf() < 0.02:
				b.press_v = 0.4
			for p in b.parts:
				p.life -= dt * 3.0
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"combo":
			if b.cool > 0.0:
				b.cool -= dt
				if b.cool <= 0.0:
					b.combo = 0
			if b.press_v > 0.0 and b.combo > 0:
				c.lean = c.face * 0.15 * b.press_v
		"shockwave":
			b.shake = maxf(0.0, b.shake - dt * 2.0)
			if b.press_v > 0.0:
				c.lean = c.face * 0.2 * b.press_v
			for p in b.parts:
				p.x += p.dir * 70.0 * dt
				p.r += 100.0 * dt
				p.life -= dt * 1.6
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"block":
			if b.press_v > 0.0:
				c.lean = -c.face * 0.1 * b.press_v
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += 200.0 * dt
				p.rot += 8.0 * dt
				p.life -= dt * 2.0
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"knockback":
			var r: Rect2 = b.rect
			if b.tumble >= 0.0:
				b.tumble += dt
				c.vx *= pow(0.1, dt)
				c.spin = -c.face * minf(1.0, b.tumble * 2.0) * TAU
				c.x = clampf(c.x, r.position.x + c.s, r.position.x + r.size.x - c.s)
				if b.tumble > 1.1:
					b.tumble = -1.0
					c.spin = 0.0
					c.pace = true
			for p in b.parts:
				p.a += 5.0 * dt
				p.life -= dt
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"ground_crack":
			for p in b.parts:
				if p.kind == "crack":
					p.life -= dt * 0.25
				else:
					p.pos += p.vel * dt
					p.vel.y += 300.0 * dt
					p.life -= dt * 1.4
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"stomp":
			if b.hop >= 0.0:
				b.hop += dt * 3.0
				c.y = b.G - sin(minf(1.0, b.hop) * PI) * c.s * 0.7
				if b.hop >= 1.0:
					c.y = b.G
					b.hop = -1.0
					b.parts.append({ "kind": "wave", "x": c.x, "dir": 1.0, "life": 1.0 })
					b.parts.append({ "kind": "wave", "x": c.x, "dir": -1.0, "life": 1.0 })
			for p in b.parts:
				p.x += p.dir * 130.0 * dt
				p.life -= dt * 1.1
			b.parts = b.parts.filter(func(p): return p.life > 0.0)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	var pv: float = b.press_v
	CubeKit.stage(n, b)
	match b.id:
		"hit_spark":
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				var pts := PackedVector2Array()
				for i in 8:
					var rr: float = 16.0 * (1.4 - p.life) if i % 2 == 0 else 5.0
					var th: float = p.rot + i / 8.0 * TAU
					pts.append(p.pos + Vector2(cos(th), sin(th)) * rr)
				n.draw_colored_polygon(pts, Color(1, 0.96, 0.78, p.life))
		"combo":
			CubeKit.draw_cube(n, b)
			if b.combo > 0:
				var scale: float = 1.0 + pv * 0.6 + minf(b.combo, 12) * 0.03
				n.draw_set_transform(Vector2(c.x, c.y - c.s * 1.7), pv * 0.1 - 0.05, Vector2(scale, scale))
				var text := "%d HIT%s" % [b.combo, "S!" if b.combo > 1 else "!"]
				n.draw_string(ThemeDB.fallback_font, Vector2(-40, 0), text,
					HORIZONTAL_ALIGNMENT_CENTER, 80, 13,
					Color.from_hsv((45.0 - minf(b.combo, 12) * 3.0) / 360.0, 0.9, 1.0))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"shockwave":
			var sh: float = b.shake * b.shake * 4.0
			n.draw_set_transform(Vector2(randf_range(-sh, sh), randf_range(-sh, sh)), 0.0, Vector2.ONE)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				CubeKit.ellipse(n, Vector2(p.x, c.y - c.s * 0.5), p.r * 0.5, p.r,
					Color(0.9, 0.88, 1.0, p.life * 0.8), 3.0)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"block":
			CubeKit.draw_cube(n, b)
			if pv > 0.0:
				var gx: float = c.x + c.face * c.s
				n.draw_polyline(PackedVector2Array([
					Vector2(gx - c.face * c.s * 0.2, c.y - c.s * 1.05),
					Vector2(gx, c.y - c.s * 0.5),
					Vector2(gx - c.face * c.s * 0.2, c.y + 2.0)]),
					Color(0.86, 0.88, 0.96, minf(1.0, pv * 1.4)), 3.5)
			for p in b.parts:
				n.draw_set_transform(p.pos, p.rot, Vector2.ONE)
				n.draw_colored_polygon(PackedVector2Array([Vector2(0, -4), Vector2(3, 3), Vector2(-3, 3)]),
					Color(1, 0.94, 0.75, p.life))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"parry":
			CubeKit.draw_cube(n, b)
			if pv > 0.0:
				if pv > 0.6:
					n.draw_rect(b.rect, Color(0.82, 0.88, 1.0, (pv - 0.6) * 1.6))
				var rr: float = (1.0 - pv) * c.s * 1.6 + 6.0
				CubeKit.ellipse(n, Vector2(c.x + c.face * c.s * 0.6, c.y - c.s * 0.55),
					rr, rr * 1.2, Color(0.75, 0.84, 1.0, pv), 2.5)
		"knockback":
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				CubeKit.twinkle(n, Vector2(c.x + cos(p.a) * c.s * 0.7, c.y - c.s * 1.25 + sin(p.a) * 4.0),
					3.0, Color(1, 0.92, 0.59, minf(1.0, p.life)))
		"ground_crack":
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				if p.kind == "crack":
					for segs in p.rays:
						var pts := PackedVector2Array()
						for s in segs:
							pts.append(s)
						n.draw_polyline(pts, Color(0.12, 0.1, 0.19, minf(1.0, p.life * 2.0)), 2.0)
				else:
					n.draw_rect(Rect2(p.pos, Vector2(2.5, 2.5)), Color(0.55, 0.51, 0.67, p.life))
		"stomp":
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				for k in 3:
					n.draw_circle(Vector2(p.x - p.dir * k * 6.0, b.G - 3.0 - k),
						5.0 + k * 2.0, Color(0.63, 0.59, 0.73, p.life * (0.35 - k * 0.09)))
