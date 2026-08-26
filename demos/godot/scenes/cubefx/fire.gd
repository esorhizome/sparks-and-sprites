extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
## FIRE ATTACKS — eight cube effects, ported from the web codex.

const TITLE := "Fire attacks"
const BLURB := "bursts, breaths, and roads of embers"
const DEFS := [
	{ "id": "fireburst", "name": "Fireburst", "hint": "ember flecks idle at its fists; press for the radial explosion" },
	{ "id": "flamethrower", "name": "Flamethrower", "hint": "a pilot light waits; press for the cone of fire" },
	{ "id": "meteor", "name": "Meteor call", "hint": "press to call a meteor down on the spot you click" },
	{ "id": "flame_aura", "name": "Flame aura", "hint": "the cube smoulders as it strolls; press to flare" },
	{ "id": "ember_dash", "name": "Ember dash", "hint": "press and it dashes, leaving a road of embers" },
	{ "id": "fire_spin", "name": "Fire spin", "hint": "press: a spinning ring of flame blooms outward" },
	{ "id": "dragon_breath", "name": "Dragon breath", "hint": "press: a huge cone of fire, with honest recoil" },
	{ "id": "phoenix_guard", "name": "Phoenix guard", "hint": "feather embers orbit; press and a wing shields the front" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	match b.id:
		"fireburst", "flamethrower", "dragon_breath":
			pass
		"meteor":
			b.shake = 0.0
		"ember_dash":
			b.dash = 0.0
		"fire_spin":
			b.ring = -1.0
			b.a0 = 0.0
		"phoenix_guard":
			b.feathers = []
			for i in 6:
				b.feathers.append({ "a": randf_range(0, TAU), "v": randf_range(0.8, 1.4) })

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"fireburst":
			b.press_v = 1.0
			for i in 22:
				var th := randf_range(0, TAU)
				var v := randf_range(50, 170)
				b.parts.append({ "pos": Vector2(c.x, c.y - c.s * 0.5),
					"vel": Vector2(cos(th) * v, sin(th) * v - 30.0), "life": 1.0, "kind": "ember" })
		"flamethrower":
			b.press_v = 1.2
		"meteor":
			var r: Rect2 = b.rect
			b.parts.append({ "kind": "meteor", "pos": Vector2(clampf(pos.x, r.position.x, r.position.x + r.size.x) + 30.0,
				r.position.y - 10.0), "life": 1.0 })
		"flame_aura", "phoenix_guard":
			b.press_v = 1.0
		"ember_dash":
			if b.dash <= 0.0:
				b.dash = 0.35
				c.pace = false
				c.vx = c.face * 380.0
		"fire_spin":
			b.ring = 0.0
		"dragon_breath":
			b.press_v = 0.9

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	b.press_v = maxf(0.0, b.press_v - dt * (1.0 if b.id in ["flamethrower", "dragon_breath"] else 1.6))
	match b.id:
		"fireburst":
			if randf() < 0.25:
				b.parts.append({ "pos": Vector2(c.x + c.face * c.s * 0.55, c.y - c.s * 0.35),
					"vel": Vector2(randf_range(-8, 8), randf_range(-30, -12)), "life": 0.6, "kind": "ember" })
			_embers(b, dt, 160.0, 1.3)
		"flamethrower":
			if b.press_v > 0.0:
				for i in 3:
					b.parts.append({ "pos": Vector2(c.x + c.face * c.s * 0.6, c.y - c.s * 0.45),
						"vel": Vector2(c.face * randf_range(120, 200), randf_range(-26, 26)), "life": randf_range(0.4, 0.8), "kind": "flame" })
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y -= 26.0 * dt
				p.life -= dt * 1.5
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"meteor":
			b.shake = maxf(0.0, b.shake - dt * 1.6)
			for p in b.parts:
				if p.kind == "meteor":
					p.pos += Vector2(-80, 180) * dt
					if p.pos.y >= b.G - 4.0:
						b.shake = 1.0
						for i in 12:
							b.parts.append({ "kind": "ember", "pos": Vector2(p.pos.x, b.G),
								"vel": Vector2(randf_range(-100, 100), randf_range(-160, -40)), "life": 1.0 })
						p.life = 0.0
				else:
					p.pos += p.vel * dt
					p.vel.y += 300.0 * dt
					p.life -= dt * 1.2
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"flame_aura":
			if randf() < 0.6 + b.press_v:
				b.parts.append({ "pos": Vector2(c.x + randf_range(-c.s * 0.5, c.s * 0.5), c.y - randf_range(0, c.s)),
					"vel": Vector2(0, -42), "life": 1.0, "kind": "flame", "r": randf_range(3, 6) * (1.0 + b.press_v) })
			for p in b.parts:
				p.pos += p.vel * dt
				p.pos.x += sin(p.pos.y * 0.2) * 14.0 * dt
				p.life -= dt * 1.5
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"ember_dash":
			if b.dash > 0.0:
				b.dash -= dt
				for i in 3:
					b.parts.append({ "pos": Vector2(c.x + randf_range(-4, 4), c.y - randf_range(2, c.s * 0.8)),
						"vel": Vector2(0, -20), "life": 1.0, "kind": "ember" })
				if c.x < r.position.x + c.s or c.x > r.position.x + r.size.x - c.s or b.dash <= 0.0:
					b.dash = 0.0
					c.pace = true
					c.x = clampf(c.x, r.position.x + c.s, r.position.x + r.size.x - c.s)
			if randf() < 0.1:
				b.parts.append({ "pos": Vector2(c.x, c.y - 2.0), "vel": Vector2(0, -20), "life": 0.7, "kind": "ember" })
			for p in b.parts:
				p.pos += p.vel * dt
				p.life -= dt * 1.6
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"fire_spin":
			if b.ring >= 0.0:
				b.ring += dt * 1.4
				b.a0 += dt * 14.0
				c.spin = sin(minf(1.0, b.ring) * PI) * 0.5
				if b.ring > 1.0:
					b.ring = -1.0
					c.spin = 0.0
		"dragon_breath":
			if b.press_v > 0.0:
				c.lean = -c.face * 0.12
				for i in 5:
					var spread := randf_range(-0.35, 0.35)
					b.parts.append({ "pos": Vector2(c.x + c.face * c.s * 0.5, c.y - c.s * 0.55),
						"vel": Vector2(c.face * cos(spread) * randf_range(160, 280), sin(spread) * 150.0),
						"life": randf_range(0.5, 0.9), "kind": "flame" })
			for p in b.parts:
				p.pos += p.vel * dt
				p.life -= dt * 1.4
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"phoenix_guard":
			for f in b.feathers:
				f.a += f.v * dt

static func _embers(b: Dictionary, dt: float, grav: float, decay: float) -> void:
	for p in b.parts:
		p.pos += p.vel * dt
		p.vel.y += grav * dt
		p.life -= dt * decay
	b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.pos.y < b.G + 8.0)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	var pv: float = b.press_v
	CubeKit.stage(n, b)
	match b.id:
		"fireburst":
			CubeKit.draw_cube(n, b)
			if pv > 0.0:
				CubeKit.glow(n, Vector2(c.x, c.y - c.s * 0.5), c.s * (2.5 - pv), Color(1, 0.7, 0.31, pv * 0.7))
			for p in b.parts:
				if p.life > 0.0:
					CubeKit.glow(n, p.pos, 4.0 + p.life * 4.0, Color(1, 0.47 + p.life * 0.4, 0.2, p.life * 0.8), 2)
		"flamethrower":
			CubeKit.draw_cube(n, b)
			CubeKit.glow(n, Vector2(c.x + c.face * c.s * 0.6, c.y - c.s * 0.45),
				4.0 + sin(t * 12.0) * 1.5, Color(1, 0.75, 0.35, 0.8), 2)
			for p in b.parts:
				CubeKit.glow(n, p.pos, 5.0 + (1.0 - p.life) * 10.0, Color(1, 0.35 + p.life * 0.55, 0.16, p.life * 0.6), 2)
		"meteor":
			var sh: float = b.shake * b.shake * 5.0
			n.draw_set_transform(Vector2(randf_range(-sh, sh), randf_range(-sh, sh)), 0.0, Vector2.ONE)
			CubeKit.draw_cube(n, b)
			CubeKit.glow(n, Vector2(c.x, c.y - c.s * 1.6), 6.0, Color(1, 0.47, 0.24, 0.2 + 0.15 * sin(t * 3.0)), 2)
			for p in b.parts:
				if p.kind == "meteor":
					CubeKit.glow(n, p.pos, 9.0, Color(1, 0.78, 0.47, 0.9), 2)
					n.draw_line(p.pos + Vector2(16, -36), p.pos, Color(1, 0.55, 0.24, 0.6), 3.0)
				elif p.life > 0.0:
					CubeKit.glow(n, p.pos, 3.5, Color(1, 0.59, 0.27, p.life), 2)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"flame_aura":
			for p in b.parts:
				if p.life > 0.0:
					CubeKit.glow(n, p.pos, p.r * p.life + 1.0, Color(1, 0.39 + p.life * 0.47, 0.18, p.life * 0.55), 2)
			CubeKit.draw_cube(n, b)
		"ember_dash":
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				if p.life > 0.0:
					CubeKit.glow(n, p.pos, 3.0 + p.life * 3.0, Color(1, 0.55, 0.24, p.life * 0.8), 2)
		"fire_spin":
			CubeKit.draw_cube(n, b)
			CubeKit.glow(n, Vector2(c.x, c.y - c.s * 0.5), c.s * 0.5, Color(1, 0.47, 0.2, 0.10), 2)
			if b.ring >= 0.0:
				var rr: float = 10.0 + b.ring * c.s * 2.6
				for i in 10:
					var th: float = b.a0 + i / 10.0 * TAU
					CubeKit.glow(n, Vector2(c.x + cos(th) * rr, c.y - c.s * 0.4 + sin(th) * rr * 0.4),
						7.0 * (1.0 - b.ring * 0.6), Color(1, 0.78 - b.ring * 0.47, 0.27, 0.8 - b.ring * 0.6), 2)
		"dragon_breath":
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				CubeKit.glow(n, p.pos, 6.0 + (1.0 - p.life) * 14.0, Color(1, 0.31 + p.life * 0.63, 0.16, p.life * 0.55), 2)
		"phoenix_guard":
			CubeKit.draw_cube(n, b)
			for f in b.feathers:
				var pos := Vector2(c.x + cos(f.a) * c.s * 1.1, c.y - c.s * 0.5 + sin(f.a) * c.s * 0.7)
				n.draw_set_transform(pos, f.a, Vector2(1.0, 2.6))
				n.draw_circle(Vector2.ZERO, 2.0, Color(1, 0.59, 0.27, 0.6))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if pv > 0.0:
				for k in 4:
					CubeKit.ellipse(n, Vector2(c.x + c.face * c.s * 0.9, c.y - c.s * 0.55),
						c.s * (0.5 + k * 0.16), c.s * (0.9 + k * 0.2),
						Color(1, 0.59 + k * 0.08, 0.31, pv * 0.7), 2.5,
						(-1.4 if c.face > 0 else PI - 1.4), (1.4 if c.face > 0 else PI + 1.4), 12)
