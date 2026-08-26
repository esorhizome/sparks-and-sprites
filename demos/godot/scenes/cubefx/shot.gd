extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
## PROJECTILES — eight cube effects, ported from the web codex.

const TITLE := "Projectiles"
const BLURB := "orbs, beams, boomerangs, and charged shots"
const DEFS := [
	{ "id": "energy_ball", "name": "Energy ball", "hint": "a palm-flicker while it waits; press to throw the classic orb" },
	{ "id": "beam", "name": "Beam blast", "hint": "press: the full-width beam, with charge motes while it idles" },
	{ "id": "homing", "name": "Homing orbs", "hint": "three orbs idle in orbit; press: they spiral out, then chase" },
	{ "id": "boomerang", "name": "Boomerang", "hint": "press: the glaive flies out, hangs, and comes home" },
	{ "id": "laser_sight", "name": "Laser sight", "hint": "a thin aiming line flickers ahead; press for the railgun crack" },
	{ "id": "charge_shot", "name": "Charge shot", "hint": "the orb at its palm GROWS while you wait; press to fire it" },
	{ "id": "spread", "name": "Spread shot", "hint": "press: a five-way fan; idle: one pellet bounces in its hand" },
	{ "id": "orbit_launch", "name": "Orbit launch", "hint": "four shards circle on duty; press launches them one by one" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	match b.id:
		"boomerang":
			b.flight = -1.0
			b.dir = 1.0
		"charge_shot":
			b.charge = 0.15
		"orbit_launch":
			b.shards = []
			for i in 4:
				b.shards.append({ "ph": i / 4.0 * TAU, "state": 0, "x": 0.0, "y": 0.0, "delay": 0.0 })

static func press(b: Dictionary, _pos: Vector2) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"energy_ball":
			c.lean = c.face * 0.15
			b.parts.append({ "kind": "orb", "pos": Vector2(c.x + c.face * c.s * 0.6, c.y - c.s * 0.5),
				"vx": c.face * 200.0, "trail": [] })
		"beam", "laser_sight":
			b.press_v = 0.8 if b.id == "beam" else 1.0
		"homing":
			for i in 3:
				b.parts.append({ "kind": "homer", "pos": Vector2(c.x, c.y - c.s * 0.5),
					"a": i / 3.0 * TAU, "spiral": 0.6, "dir": c.face, "life": 2.0 })
		"boomerang":
			if b.flight < 0.0:
				b.flight = 0.0
				b.dir = c.face
		"charge_shot":
			b.parts.append({ "kind": "shot", "pos": Vector2(c.x + c.face * c.s * 0.6, c.y - c.s * 0.5),
				"vx": c.face * 180.0, "r": 4.0 + b.charge * 12.0 })
			b.charge = 0.15
		"spread":
			for i in range(-2, 3):
				var th := i * 0.22
				b.parts.append({ "kind": "pellet", "pos": Vector2(c.x + c.face * c.s * 0.6, c.y - c.s * 0.55),
					"vel": Vector2(c.face * cos(th) * 190.0, sin(th) * 190.0), "life": 1.4 })
		"orbit_launch":
			var d := 0.0
			for s in b.shards:
				if s.state == 0:
					s.state = 1
					s.delay = d
					d += 0.15

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	b.press_v = maxf(0.0, b.press_v - dt * (1.0 if b.id == "beam" else 3.0))
	match b.id:
		"energy_ball":
			for p in b.parts:
				p.pos.x += p.vx * dt
				p.trail.push_front(Vector2(p.pos.x, p.pos.y))
				if p.trail.size() > 9:
					p.trail.pop_back()
			b.parts = b.parts.filter(func(p): return p.pos.x > r.position.x - 20 and p.pos.x < r.position.x + r.size.x + 20)
		"beam":
			if b.press_v > 0.0:
				c.lean = -c.face * 0.12
		"homing":
			for p in b.parts:
				if p.spiral > 0.0:
					p.spiral -= dt
					p.a += 9.0 * dt
					p.pos += Vector2(cos(p.a) * 90.0, sin(p.a) * 60.0) * dt
				else:
					p.pos.x += p.dir * 220.0 * dt
					p.pos.y += (c.y - c.s * 0.5 - p.pos.y) * dt * 2.0
				p.life -= dt
			b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.pos.x > r.position.x - 20 and p.pos.x < r.position.x + r.size.x + 20)
		"boomerang":
			if b.flight >= 0.0:
				b.flight += dt * 0.9
				if b.flight >= 1.0:
					b.flight = -1.0
		"charge_shot":
			b.charge = minf(1.0, b.charge + dt * 0.18)
			for p in b.parts:
				p.pos.x += p.vx * dt
			b.parts = b.parts.filter(func(p): return p.pos.x > r.position.x - 30 and p.pos.x < r.position.x + r.size.x + 30)
		"spread":
			for p in b.parts:
				p.pos += p.vel * dt
				p.life -= dt
			b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.pos.x > r.position.x - 10 and p.pos.x < r.position.x + r.size.x + 10)
		"orbit_launch":
			for s in b.shards:
				if s.state == 0:
					var a: float = t * 2.0 + s.ph
					s.x = c.x + cos(a) * c.s * 1.05
					s.y = c.y - c.s * 0.5 + sin(a) * c.s * 0.6
				else:
					s.delay -= dt
					if s.delay <= 0.0:
						s.x += c.face * 260.0 * dt
					if s.x < r.position.x - 12 or s.x > r.position.x + r.size.x + 12:
						s.state = 0

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	var pv: float = b.press_v
	CubeKit.stage(n, b)
	CubeKit.draw_cube(n, b)
	match b.id:
		"energy_ball":
			CubeKit.glow(n, Vector2(c.x + c.face * c.s * 0.55, c.y - c.s * 0.45),
				3.0 + sin(t * 9.0) * 1.5, Color(0.59, 0.82, 1.0, 0.7), 2)
			for p in b.parts:
				var trail: Array = p.trail
				for i in trail.size():
					var k := 1.0 - float(i) / maxf(1.0, trail.size())
					CubeKit.glow(n, trail[i], 5.0 + k * 6.0, Color(0.55, 0.8, 1.0, k * 0.4), 2)
				CubeKit.glow(n, p.pos, 9.0, Color(0.82, 0.92, 1.0, 0.95), 2)
		"beam":
			if randf() < 0.2:
				CubeKit.glow(n, Vector2(c.x + c.face * c.s * 0.6 + randf_range(-8, 8),
					c.y - c.s * 0.5 + randf_range(-8, 8)), 2.5, Color(0.7, 0.86, 1.0, 0.7), 2)
			if pv > 0.0:
				var hy: float = c.y - c.s * 0.5
				var x0: float = c.x + c.face * c.s * 0.6
				var thick: float = 8.0 * minf(1.0, pv * 3.0) * (0.7 + sin(t * 30.0) * 0.1)
				var x1: float = r.position.x + r.size.x if c.face > 0 else r.position.x
				n.draw_rect(Rect2(minf(x0, x1), hy - thick, absf(x1 - x0), thick * 2.0),
					Color(0.71, 0.86, 1.0, 0.6))
				CubeKit.glow(n, Vector2(x0, hy), 14.0 + thick, Color(0.86, 0.94, 1.0, 0.9), 3)
		"homing":
			for i in 3:
				var a: float = t * 1.8 + i / 3.0 * TAU
				CubeKit.glow(n, Vector2(c.x + cos(a) * c.s * 0.95, c.y - c.s * 0.5 + sin(a) * c.s * 0.55),
					4.0, Color(1, 0.71, 0.86, 0.8), 2)
			for p in b.parts:
				CubeKit.glow(n, p.pos, 6.0, Color(1, 0.75, 0.88, 0.9), 2)
		"boomerang":
			if b.flight >= 0.0:
				var reach: float = sin(minf(1.0, b.flight) * PI) * c.s * 3.2
				var pos := Vector2(c.x + b.dir * reach,
					c.y - c.s * 0.6 - sin(minf(1.0, b.flight) * TAU) * 8.0)
				n.draw_set_transform(pos, t * 16.0, Vector2.ONE)
				n.draw_polyline(PackedVector2Array([Vector2(-7, 3), Vector2(0, -5), Vector2(7, 3)]),
					Color(0.86, 0.88, 0.96, 0.95), 3.0)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				n.draw_line(Vector2(c.x - c.face * c.s * 0.4 - 4.0, c.y - c.s * 0.3),
					Vector2(c.x - c.face * c.s * 0.4 + 4.0, c.y - c.s * 0.34),
					Color(0.86, 0.88, 0.96, 0.5 + sin(t * 3.0) * 0.3), 2.0)
		"laser_sight":
			var hy: float = c.y - c.s * 0.55
			var x0: float = c.x + c.face * c.s * 0.55
			var x1: float = r.position.x + r.size.x if c.face > 0 else r.position.x
			if pv <= 0.0:
				n.draw_line(Vector2(x0, hy), Vector2(x1, hy),
					Color(1, 0.35, 0.35, 0.25 + sin(t * 7.0) * 0.12), 1.0)
			else:
				n.draw_line(Vector2(x0, hy), Vector2(x1, hy), Color(1, 0.9, 0.9, pv), 1.0 + pv * 5.0)
				CubeKit.glow(n, Vector2(x0, hy), 12.0, Color(1, 0.78, 0.78, pv), 2)
		"charge_shot":
			CubeKit.glow(n, Vector2(c.x + c.face * c.s * 0.6, c.y - c.s * 0.5),
				3.0 + b.charge * 12.0 + sin(t * 10.0) * b.charge * 2.0,
				Color(0.67, 1.0, 0.75, 0.4 + b.charge * 0.5), 3)
			for p in b.parts:
				CubeKit.glow(n, p.pos, p.r, Color(0.75, 1.0, 0.8, 0.9), 2)
		"spread":
			CubeKit.glow(n, Vector2(c.x + c.face * c.s * 0.55, c.y - c.s * 0.45 - absf(sin(t * 5.0)) * 4.0),
				2.5, Color(1, 0.86, 0.59, 0.8), 2)
			for p in b.parts:
				CubeKit.glow(n, p.pos, 4.0, Color(1, 0.88, 0.63, 0.9), 2)
		"orbit_launch":
			for s in b.shards:
				CubeKit.glow(n, Vector2(s.x, s.y), 4.0 if s.state == 0 else 5.0,
					Color(0.78, 0.75, 1.0, 0.85 if s.state == 0 else 0.95), 2)
