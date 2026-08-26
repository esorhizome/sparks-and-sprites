extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
const Base := preload("res://scenes/cubefx/shot.gd")
## PROJECTILES — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"energy_ball": { "name": "Shadow ball", "hint": "in negative — a dark core wearing a violet rim" },
	"beam": { "name": "Ice beam", "hint": "crusted cold — slower flicker, frost where it passed" },
	"homing": { "name": "Homing embers", "hint": "on fire, and one orb lighter" },
	"boomerang": { "name": "Twin glaives", "hint": "the out-and-back flown by two blades in mirrored phase" },
	"laser_sight": { "name": "Green scope", "hint": "green, blinking slower — the shot hums, not cracks" },
	"charge_shot": { "name": "Instant volley", "hint": "patience deleted — three small ones, right now" },
	"spread": { "name": "Tight burst", "hint": "the fan squeezed narrow and doubled" },
	"orbit_launch": { "name": "Orbit recall", "hint": "every shard boomerangs back to its post" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)
	if b.id == "beam":
		b.frost = []

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"homing":
			# dial: three homers → two
			for i in 2:
				b.parts.append({ "kind": "homer", "pos": Vector2(c.x, c.y - c.s * 0.5),
					"a": i * PI, "spiral": 0.6, "dir": c.face, "life": 2.0 })
		"charge_shot":
			# dial: the charge deleted — three pellets immediately
			for i in 3:
				b.parts.append({ "kind": "shot", "pos": Vector2(c.x + c.face * c.s * 0.6, c.y - c.s * 0.5),
					"vx": c.face * (150.0 + i * 40.0), "r": 3.0 })
			b.charge = 0.15
		"spread":
			# dials: spread 0.22 → 0.09 · five pellets → ten
			for i in range(-2, 3):
				for wave in 2:
					var th := i * 0.09
					b.parts.append({ "kind": "pellet", "pos": Vector2(c.x + c.face * c.s * 0.6, c.y - c.s * 0.55),
						"vel": Vector2(c.face * cos(th) * (190.0 - wave * 50.0), sin(th) * (190.0 - wave * 50.0)),
						"life": 1.4 })
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	match b.id:
		"beam":
			# dial: the beam leaves frost patches along the floor while firing
			b.press_v = maxf(0.0, b.press_v - dt * 1.0)
			if b.press_v > 0.0:
				c.lean = -c.face * 0.12
				if randf() < 0.4:
					b.frost.append({ "x": clampf(c.x + c.face * randf_range(c.s, r.size.x * 0.6),
						r.position.x + 4, r.position.x + r.size.x - 4), "life": 1.0 })
			for f in b.frost:
				f.life -= dt * 0.3
			b.frost = b.frost.filter(func(f): return f.life > 0.0)
		"orbit_launch":
			# dial: launched shards decelerate, turn, and fly home
			for s in b.shards:
				if s.state == 0:
					var a: float = t * 2.0 + s.ph
					s.x = c.x + cos(a) * c.s * 1.05
					s.y = c.y - c.s * 0.5 + sin(a) * c.s * 0.6
				elif s.state == 1:
					s.delay -= dt
					if s.delay <= 0.0:
						s.x += c.face * 260.0 * dt
					if s.x < r.position.x + 8 or s.x > r.position.x + r.size.x - 8:
						s.state = 2
				else:
					var a2: float = t * 2.0 + s.ph
					var home := Vector2(c.x + cos(a2) * c.s * 1.05, c.y - c.s * 0.5 + sin(a2) * c.s * 0.6)
					s.x += (home.x - s.x) * minf(1.0, dt * 5.0)
					s.y += (home.y - s.y) * minf(1.0, dt * 5.0)
					if absf(s.x - home.x) < 4.0:
						s.state = 0
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	var pv: float = b.press_v
	match b.id:
		"energy_ball":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			CubeKit.glow(n, Vector2(c.x + c.face * c.s * 0.55, c.y - c.s * 0.45),
				3.0 + sin(t * 9.0) * 1.5, Color(0.55, 0.31, 0.78, 0.7), 2)
			for p in b.parts:
				var trail: Array = p.trail
				for i in trail.size():
					var k := 1.0 - float(i) / maxf(1.0, trail.size())
					CubeKit.glow(n, trail[i], 5.0 + k * 6.0, Color(0.39, 0.24, 0.59, k * 0.4), 2)
				CubeKit.ellipse(n, p.pos, 9.0, 9.0, Color(0.71, 0.47, 1.0, 0.95), 2.0, 0, TAU, 14)
				n.draw_circle(p.pos, 6.5, Color(0.05, 0.03, 0.1, 0.95))
		"beam":
			CubeKit.stage(n, b)
			for f in b.frost:              # the frost the beam left
				CubeKit.twinkle(n, Vector2(f.x, b.G - 2.0), 3.0 * f.life, Color(0.78, 0.92, 1.0, f.life * 0.8))
			CubeKit.draw_cube(n, b)
			if randf() < 0.2:
				CubeKit.glow(n, Vector2(c.x + c.face * c.s * 0.6 + randf_range(-8, 8),
					c.y - c.s * 0.5 + randf_range(-8, 8)), 2.5, Color(0.78, 0.92, 1.0, 0.7), 2)
			if pv > 0.0:
				var hy: float = c.y - c.s * 0.5
				var x0: float = c.x + c.face * c.s * 0.6
				var thick: float = 8.0 * minf(1.0, pv * 3.0) * (0.8 + sin(t * 8.0) * 0.06)
				var x1: float = r.position.x + r.size.x if c.face > 0 else r.position.x
				n.draw_rect(Rect2(minf(x0, x1), hy - thick, absf(x1 - x0), thick * 2.0),
					Color(0.75, 0.92, 1.0, 0.55))
				n.draw_rect(Rect2(minf(x0, x1), hy - thick * 0.3, absf(x1 - x0), thick * 0.6),
					Color(0.95, 0.98, 1.0, 0.8))
				CubeKit.glow(n, Vector2(x0, hy), 14.0 + thick, Color(0.86, 0.95, 1.0, 0.9), 3)
		"homing":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for i in 2:
				var a: float = t * 1.8 + i * PI
				CubeKit.glow(n, Vector2(c.x + cos(a) * c.s * 0.95, c.y - c.s * 0.5 + sin(a) * c.s * 0.55),
					4.0, Color(1, 0.63, 0.27, 0.85), 2)
			for p in b.parts:
				CubeKit.glow(n, p.pos, 6.0, Color(1, 0.55, 0.2, 0.9), 2)
				n.draw_line(p.pos, p.pos - Vector2(p.dir * 8.0, -3.0), Color(1, 0.43, 0.16, 0.5), 1.5)
		"boomerang":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			if b.flight >= 0.0:
				for g in 2:                # mirrored phase: one out while one returns
					var k: float = fmod(minf(1.0, b.flight) + g * 0.5, 1.0)
					var reach: float = sin(k * PI) * c.s * 3.2
					var pos := Vector2(c.x + b.dir * reach,
						c.y - c.s * 0.6 - sin(k * TAU) * 8.0)
					n.draw_set_transform(pos, t * 16.0 + g * PI, Vector2.ONE)
					n.draw_polyline(PackedVector2Array([Vector2(-7, 3), Vector2(0, -5), Vector2(7, 3)]),
						Color(0.86, 0.88, 0.96, 0.95) if g == 0 else Color(1, 0.84, 0.55, 0.95), 3.0)
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				n.draw_line(Vector2(c.x - c.face * c.s * 0.4 - 4.0, c.y - c.s * 0.3),
					Vector2(c.x - c.face * c.s * 0.4 + 4.0, c.y - c.s * 0.34),
					Color(0.86, 0.88, 0.96, 0.5 + sin(t * 3.0) * 0.3), 2.0)
		"laser_sight":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			var hy: float = c.y - c.s * 0.55
			var x0: float = c.x + c.face * c.s * 0.55
			var x1: float = r.position.x + r.size.x if c.face > 0 else r.position.x
			if pv <= 0.0:
				n.draw_line(Vector2(x0, hy), Vector2(x1, hy),
					Color(0.39, 1.0, 0.47, 0.25 + sin(t * 2.5) * 0.12), 1.0)
			else:
				n.draw_line(Vector2(x0, hy), Vector2(x1, hy), Color(0.75, 1.0, 0.78, pv * 0.8), 1.0 + pv * 3.0)
				CubeKit.glow(n, Vector2(x0, hy), 10.0, Color(0.63, 1.0, 0.67, pv * 0.8), 2)
		"charge_shot":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			CubeKit.glow(n, Vector2(c.x + c.face * c.s * 0.6, c.y - c.s * 0.5),
				3.0, Color(0.67, 1.0, 0.75, 0.5), 2)
			for p in b.parts:
				CubeKit.glow(n, p.pos, p.r + 1.0, Color(0.75, 1.0, 0.8, 0.9), 2)
		"orbit_launch":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for s in b.shards:
				var col := Color(0.78, 0.75, 1.0, 0.85)
				if s.state == 1:
					col = Color(0.9, 0.88, 1.0, 0.95)
				elif s.state == 2:
					col = Color(0.63, 0.94, 0.86, 0.95)   # homeward: teal tell
				CubeKit.glow(n, Vector2(s.x, s.y), 4.0 if s.state == 0 else 5.0, col, 2)
		_:
			Base.draw(n, b, t)
