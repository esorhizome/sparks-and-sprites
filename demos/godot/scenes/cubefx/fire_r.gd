extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
const Base := preload("res://scenes/cubefx/fire.gd")
## FIRE ATTACKS — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"fireburst": { "name": "Frostburst", "hint": "cold palette, and the shards HANG in the air" },
	"flamethrower": { "name": "Frost breath", "hint": "the cone at half speed — cold, no hurry" },
	"meteor": { "name": "Comet call", "hint": "iced over — gentler impact, no quake" },
	"flame_aura": { "name": "Spirit aura", "hint": "ghost-green, at half the rise" },
	"ember_dash": { "name": "Frost dash", "hint": "the trail lingers three times longer" },
	"fire_spin": { "name": "Petal spin", "hint": "flame tongues swapped for pink petals" },
	"dragon_breath": { "name": "Smoke breath", "hint": "unlit — grey plumes, recoil at zero" },
	"phoenix_guard": { "name": "Raven guard", "hint": "mourning black — dimmer, slower, loyal still" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)
	if b.id == "phoenix_guard":
		for f in b.feathers:        # the ÷2 orbit dial
			f.v *= 0.5

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"fireburst":
			# dial: launch speed ÷2 — shards meant to hang, not fly
			b.press_v = 1.0
			for i in 22:
				var th := randf_range(0, TAU)
				var v := randf_range(25, 85)
				b.parts.append({ "pos": Vector2(c.x, c.y - c.s * 0.5),
					"vel": Vector2(cos(th) * v, sin(th) * v - 15.0), "life": 1.0, "kind": "ember" })
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	match b.id:
		"fireburst":
			# dials: gravity 160 → 12 (hang) · decay 1.3 → 0.7
			b.press_v = maxf(0.0, b.press_v - dt * 1.6)
			if randf() < 0.25:
				b.parts.append({ "pos": Vector2(c.x + c.face * c.s * 0.55, c.y - c.s * 0.35),
					"vel": Vector2(randf_range(-8, 8), randf_range(-18, -6)), "life": 0.6, "kind": "ember" })
			Base._embers(b, dt, 12.0, 0.7)
		"flamethrower":
			# dials: jet speed ÷2 · rise gentler · decay slower
			b.press_v = maxf(0.0, b.press_v - dt * 1.0)
			if b.press_v > 0.0:
				for i in 3:
					b.parts.append({ "pos": Vector2(c.x + c.face * c.s * 0.6, c.y - c.s * 0.45),
						"vel": Vector2(c.face * randf_range(60, 100), randf_range(-16, 16)),
						"life": randf_range(0.6, 1.1), "kind": "flame" })
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y -= 14.0 * dt
				p.life -= dt * 0.9
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"meteor":
			# dials: no quake shake · impact scatter ÷2
			b.shake = 0.0
			for p in b.parts:
				if p.kind == "meteor":
					p.pos += Vector2(-80, 140) * dt
					if p.pos.y >= b.G - 4.0:
						for i in 12:
							b.parts.append({ "kind": "ember", "pos": Vector2(p.pos.x, b.G),
								"vel": Vector2(randf_range(-50, 50), randf_range(-80, -20)), "life": 1.0 })
						p.life = 0.0
				else:
					p.pos += p.vel * dt
					p.vel.y += 140.0 * dt
					p.life -= dt * 1.2
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"flame_aura":
			# dial: rise 42 → 21
			b.press_v = maxf(0.0, b.press_v - dt * 1.6)
			if randf() < 0.6 + b.press_v:
				b.parts.append({ "pos": Vector2(c.x + randf_range(-c.s * 0.5, c.s * 0.5), c.y - randf_range(0, c.s)),
					"vel": Vector2(0, -21), "life": 1.0, "kind": "flame", "r": randf_range(3, 6) * (1.0 + b.press_v) })
			for p in b.parts:
				p.pos += p.vel * dt
				p.pos.x += sin(p.pos.y * 0.2) * 14.0 * dt
				p.life -= dt * 1.5
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"ember_dash":
			# dial: trail decay 1.6 → 0.5 (it lingers)
			b.press_v = maxf(0.0, b.press_v - dt * 1.6)
			if b.dash > 0.0:
				b.dash -= dt
				for i in 3:
					b.parts.append({ "pos": Vector2(c.x + randf_range(-4, 4), c.y - randf_range(2, c.s * 0.8)),
						"vel": Vector2(0, -8), "life": 1.0, "kind": "ember" })
				if c.x < r.position.x + c.s or c.x > r.position.x + r.size.x - c.s or b.dash <= 0.0:
					b.dash = 0.0
					c.pace = true
					c.x = clampf(c.x, r.position.x + c.s, r.position.x + r.size.x - c.s)
			if randf() < 0.1:
				b.parts.append({ "pos": Vector2(c.x, c.y - 2.0), "vel": Vector2(0, -8), "life": 0.7, "kind": "ember" })
			for p in b.parts:
				p.pos += p.vel * dt
				p.life -= dt * 0.5
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	var pv: float = b.press_v
	match b.id:
		"fireburst":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			if pv > 0.0:
				CubeKit.glow(n, Vector2(c.x, c.y - c.s * 0.5), c.s * (2.5 - pv), Color(0.55, 0.8, 1.0, pv * 0.7))
			for p in b.parts:
				if p.life > 0.0:
					CubeKit.glow(n, p.pos, 4.0 + p.life * 4.0, Color(0.63, 0.84, 1.0, p.life * 0.8), 2)
					CubeKit.twinkle(n, p.pos, 3.0 * p.life, Color(0.86, 0.95, 1.0, p.life * 0.7))
		"flamethrower":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			CubeKit.glow(n, Vector2(c.x + c.face * c.s * 0.6, c.y - c.s * 0.45),
				4.0 + sin(t * 6.0) * 1.5, Color(0.71, 0.88, 1.0, 0.8), 2)
			for p in b.parts:
				CubeKit.glow(n, p.pos, 5.0 + (1.0 - p.life) * 10.0, Color(0.59, 0.8 + p.life * 0.15, 1.0, p.life * 0.5), 2)
		"meteor":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			CubeKit.glow(n, Vector2(c.x, c.y - c.s * 1.6), 6.0, Color(0.63, 0.84, 1.0, 0.2 + 0.15 * sin(t * 3.0)), 2)
			for p in b.parts:
				if p.kind == "meteor":
					CubeKit.glow(n, p.pos, 9.0, Color(0.78, 0.92, 1.0, 0.9), 2)
					n.draw_line(p.pos + Vector2(16, -36), p.pos, Color(0.63, 0.84, 1.0, 0.6), 3.0)
				elif p.life > 0.0:
					CubeKit.glow(n, p.pos, 3.5, Color(0.71, 0.88, 1.0, p.life), 2)
		"flame_aura":
			CubeKit.stage(n, b)
			for p in b.parts:
				if p.life > 0.0:
					CubeKit.glow(n, p.pos, p.r * p.life + 1.0, Color(0.47, 0.94, 0.63, p.life * 0.45), 2)
			CubeKit.draw_cube(n, b)
		"ember_dash":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				if p.life > 0.0:
					CubeKit.twinkle(n, p.pos, 2.0 + p.life * 2.0, Color(0.71, 0.9, 1.0, p.life * 0.8))
		"fire_spin":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			CubeKit.glow(n, Vector2(c.x, c.y - c.s * 0.5), c.s * 0.5, Color(1, 0.71, 0.84, 0.10), 2)
			if b.ring >= 0.0:
				var rr: float = 10.0 + b.ring * c.s * 2.6
				for i in 10:
					var th: float = b.a0 * 0.6 + i / 10.0 * TAU
					var pos := Vector2(c.x + cos(th) * rr, c.y - c.s * 0.4 + sin(th) * rr * 0.4)
					n.draw_set_transform(pos, th, Vector2(1.0, 0.55))
					n.draw_circle(Vector2.ZERO, 3.4 * (1.0 - b.ring * 0.5), Color(1, 0.71, 0.84, 0.85 - b.ring * 0.6))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"dragon_breath":
			CubeKit.stage(n, b)
			c.lean = 0.0             # the recoil dial at zero
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				var v: float = 0.55 + p.life * 0.2
				n.draw_circle(p.pos, 5.0 + (1.0 - p.life) * 12.0, Color(v, v, v + 0.03, p.life * 0.3))
		"phoenix_guard":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for f in b.feathers:
				var pos := Vector2(c.x + cos(f.a) * c.s * 1.1, c.y - c.s * 0.5 + sin(f.a) * c.s * 0.7)
				n.draw_set_transform(pos, f.a, Vector2(1.0, 2.6))
				n.draw_circle(Vector2.ZERO, 2.0, Color(0.24, 0.22, 0.31, 0.75))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if pv > 0.0:
				for k in 4:
					CubeKit.ellipse(n, Vector2(c.x + c.face * c.s * 0.9, c.y - c.s * 0.55),
						c.s * (0.5 + k * 0.16), c.s * (0.9 + k * 0.2),
						Color(0.35, 0.31, 0.47, pv * 0.7), 2.5,
						(-1.4 if c.face > 0 else PI - 1.4), (1.4 if c.face > 0 else PI + 1.4), 12)
		_:
			Base.draw(n, b, t)
