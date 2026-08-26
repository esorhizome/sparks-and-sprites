extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
const Base := preload("res://scenes/cubefx/ice.gd")
## ICE — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"shards": { "name": "Fire shards", "hint": "the volley alight — shards curve upward as heat argues with aim" },
	"armor": { "name": "Stone armor", "hint": "granite — dust motes instead of glints" },
	"freeze_stomp": { "name": "Burn stomp", "hint": "scorched — it smoulders as it fades" },
	"snow_aura": { "name": "Ash aura", "hint": "grey flakes that smear, not melt" },
	"icicle": { "name": "Stalactite spear", "hint": "ONE great spear — slower to form, harder to land" },
	"wall": { "name": "Ember wall", "hint": "on fire — it burns DOWN instead of melting" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)
	if b.id == "icicle":
		b.shake = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	match b.id:
		"icicle":
			# dial: three icicles → one slow great spear
			b.parts.append({ "kind": "icicle", "pos": Vector2(clampf(pos.x, r.position.x + 12, r.position.x + r.size.x - 12),
				maxf(pos.y, r.position.y + 12.0)), "form": 0.0, "vy": 0.0 })
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"shards":
			# dial: shards climb — heat argues with aim (vel.y -60/s)
			b.press_v = maxf(0.0, b.press_v - dt)
			b.breath += dt
			if b.breath > 2.4:
				b.breath = 0.0
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y -= 60.0 * dt
				p.rot += 6.0 * dt
				p.life -= dt
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"armor":
			c.tint = Color(0.33, 0.3, 0.27) if b.on else null
		"icicle":
			# dials: form 2.4 → 0.8 (slower) · impact quake instead of bits
			b.shake = maxf(0.0, b.shake - dt * 1.6)
			for p in b.parts:
				if p.kind == "icicle":
					if p.form < 1.0:
						p.form += dt * 0.8
					else:
						p.vy += 620.0 * dt
						p.pos.y += p.vy * dt
					if p.pos.y >= b.G - 6.0:
						b.shake = 1.0
						for i in 8:
							b.parts.append({ "kind": "bit", "pos": Vector2(p.pos.x, b.G),
								"vel": Vector2(randf_range(-80, 80), randf_range(-120, -30)), "life": 1.0 })
						p.pos.y = 1e9
				else:
					p.pos += p.vel * dt
					p.vel.y += 280.0 * dt
					p.life -= dt * 1.6
			b.parts = b.parts.filter(func(p): return (p.kind == "icicle" and p.pos.y < 1e8) or (p.kind == "bit" and p.life > 0.0))
		"wall":
			# dial: melts top-down while shedding embers, not drips
			var embers := []
			for p in b.parts:
				if p.kind == "wall":
					p.life -= dt * 0.7
					var hgt: float = c.s * 1.6 * minf(1.0, (3.0 - p.life) * 3.0) * minf(1.0, p.life)
					if p.life > 0.0 and randf() < 0.4:
						embers.append({ "kind": "drip", "pos": Vector2(p.x + randf_range(-12, 12), b.G - hgt),
							"vel": Vector2(randf_range(-10, 10), randf_range(-40, -15)), "life": 1.0 })
				else:
					p.pos += p.vel * dt
					p.life -= dt * 2.0
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
			b.parts.append_array(embers)
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"shards":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			if b.breath < 0.6:
				for i in 2:
					CubeKit.glow(n, Vector2(c.x + c.face * (c.s * 0.5 + b.breath * 30.0 + randf_range(0, 6)),
						c.y - c.s * 0.6 + randf_range(-4, 4)), 4.0, Color(1, 0.71, 0.35, 0.16), 2)
			for p in b.parts:
				n.draw_set_transform(p.pos, p.rot, Vector2.ONE)
				n.draw_colored_polygon(PackedVector2Array([Vector2(6, 0), Vector2(-4, 2.5), Vector2(-4, -2.5)]),
					Color(1, 0.63, 0.27, 0.9))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				CubeKit.glow(n, p.pos, 4.0, Color(1, 0.55, 0.2, p.life * 0.4), 2)
		"armor":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			if b.on:
				n.draw_set_transform(Vector2(c.x, c.y - c.hop), c.lean, Vector2.ONE)
				n.draw_rect(Rect2(-c.s / 2.0 - 3.0, -c.s - 3.0, c.s + 6.0, c.s + 6.0),
					Color(0.55, 0.51, 0.47, 0.85), false, 3.0)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				if randf() < 0.15:            # dust motes shaken loose
					n.draw_circle(Vector2(c.x + randf_range(-c.s, c.s) * 0.5, c.y - randf_range(0, c.s)),
						1.2, Color(0.63, 0.59, 0.55, 0.7))
		"freeze_stomp":
			CubeKit.stage(n, b)
			for p in b.parts:
				var a: float = minf(1.0, p.life * 2.0) * 0.5
				n.draw_rect(Rect2(p.x - p.spread, b.G, p.spread * 2.0, 5.0), Color(0.24, 0.1, 0.06, a))
				var x: float = -p.spread
				while x < p.spread:
					if randf() < 0.3:          # the smoulder
						CubeKit.glow(n, Vector2(p.x + x + randf_range(0, 8), b.G - 1.0),
							2.5, Color(1, 0.47, 0.16, a * 1.4), 2)
					x += 14.0
			CubeKit.draw_cube(n, b)
		"snow_aura":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				var smear: float = clampf((b.G - p.pos.y) / 10.0, 0.3, 1.0)
				n.draw_set_transform(p.pos, 0.0, Vector2(1.0, smear))
				n.draw_circle(Vector2.ZERO, 1.6, Color(0.55, 0.53, 0.51, p.life * 0.75))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"icicle":
			var sh: float = b.shake * b.shake * 4.0
			n.draw_set_transform(Vector2(randf_range(-sh, sh), randf_range(-sh, sh)), 0.0, Vector2.ONE)
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				if p.kind == "icicle":
					n.draw_colored_polygon(PackedVector2Array([
						p.pos + Vector2(-6, 0), p.pos + Vector2(6, 0), p.pos + Vector2(0, 26.0 * p.form)]),
						Color(0.75, 0.88, 1.0, 0.9 * minf(1.0, p.form)))
				else:
					n.draw_rect(Rect2(p.pos, Vector2(2, 2)), Color(0.82, 0.94, 1.0, p.life))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"wall":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				if p.kind != "wall":
					CubeKit.glow(n, p.pos, 2.5, Color(1, 0.59, 0.24, p.life * 0.9), 2)
					continue
				var up: float = minf(1.0, (3.0 - p.life) * 3.0)
				var melt: float = minf(1.0, p.life)
				var hgt: float = c.s * 1.6 * up * melt
				n.draw_rect(Rect2(p.x - 12.0, b.G - hgt, 24.0, maxf(1.0, hgt)), Color(0.9, 0.35, 0.12, 0.55))
				n.draw_rect(Rect2(p.x - 12.0, b.G - hgt, 24.0, maxf(1.0, hgt)), Color(1, 0.71, 0.35, 0.8), false, 1.5)
				CubeKit.glow(n, Vector2(p.x, b.G - hgt), 8.0, Color(1, 0.63, 0.27, 0.5 * melt), 2)
		_:
			Base.draw(n, b, t)
