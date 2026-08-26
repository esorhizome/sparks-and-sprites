extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
const Base := preload("res://scenes/cubefx/motion.gd")
## MOVEMENT — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"afterimages": { "name": "Chromatic ghosts", "hint": "the past selves split red and cyan — one hue per past" },
	"double_jump": { "name": "Triple hop", "hint": "extended by one — three small hops, three rings" },
	"landing_dust": { "name": "Splash landing", "hint": "a wet floor — droplets and a ring instead of dust" },
	"skid": { "name": "Spark skid", "hint": "striking sparks instead of smoke" },
	"speed_lines": { "name": "Slow-mo trail", "hint": "stretched long and faint — bullet-time walking" },
	"teleport": { "name": "Mirror swap", "hint": "always lands at the stage's mirror point — no aiming" },
	"backflip": { "name": "Frontflip", "hint": "the rotation sign flipped — momentum agrees now" },
	"wall_kick": { "name": "Rubber walls", "hint": "the bounce dial cranked — springy chaos" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)
	if b.id == "double_jump":
		b.jumps = 0

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	match b.id:
		"double_jump":
			# dial: two jumps → three smaller ones, a ring for each
			if not b.air:
				b.air = true
				b.jumps = 1
				b.vy = -170.0
				b.parts.append({ "kind": "ring", "pos": Vector2(c.x, c.y), "r": 4.0, "life": 1.0 })
			elif b.jumps < 3:
				b.jumps += 1
				b.vy = -170.0
				b.parts.append({ "kind": "ring", "pos": Vector2(c.x, c.y), "r": 4.0, "life": 1.0 })
		"teleport":
			# dial: no aiming — the blink always lands at the stage's mirror point
			if b.phase == 0:
				b.phase = 1
				b.target = clampf(2.0 * r.get_center().x - c.x, r.position.x + c.s, r.position.x + r.size.x - c.s)
				for i in 14:
					b.parts.append({ "kind": "mote", "pos": Vector2(c.x + randf_range(-c.s * 0.5, c.s * 0.5),
						c.y - randf_range(0, c.s)), "life": 1.0 })
				c.alpha = 0.0
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	match b.id:
		"double_jump":
			if b.air:
				b.vy += 620.0 * dt
				c.y += b.vy * dt
				if c.y >= b.G:
					c.y = b.G
					b.air = false
					b.jumps = 0
					b.vy = 0.0
			for p in b.parts:
				if p.kind == "ring":
					p.r += 110.0 * dt
					p.life -= dt * 2.2
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"landing_dust":
			# dial: the landing splashes — droplets under gravity plus one floor ring
			if b.air:
				b.vy += 640.0 * dt
				c.y += b.vy * dt
				if c.y >= b.G:
					c.y = b.G
					b.air = false
					b.parts.append({ "kind": "ring", "r": 4.0, "life": 1.0, "x": c.x })
					for i in 10:
						b.parts.append({ "kind": "drop", "pos": Vector2(c.x + randf_range(-4, 4), b.G),
							"vel": Vector2(randf_range(30, 80) * (1.0 if i % 2 == 0 else -1.0), randf_range(-140, -60)), "life": 1.0 })
					b.vy = 0.0
			for p in b.parts:
				if p.kind == "ring":
					p.r += 80.0 * dt
					p.life -= dt * 1.6
				else:
					p.pos += p.vel * dt
					p.vel.y += 300.0 * dt
					p.life -= dt * 1.4
					if p.pos.y > b.G:
						p.life = 0.0
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"backflip":
			# dial: spin sign flipped — with the run, not against it
			if b.flip >= 0.0:
				b.flip += dt * 1.6
				var k: float = minf(1.0, b.flip)
				c.y = b.G - sin(k * PI) * c.s * 1.7
				c.spin = c.face * k * TAU
				b.parts.append({ "pos": Vector2(c.x, c.y - c.s * 0.5), "life": 1.0 })
				if b.flip >= 1.0:
					b.flip = -1.0
					c.y = b.G
					c.spin = 0.0
			for p in b.parts:
				p.life -= dt * 2.0
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"wall_kick":
			# dials: every wall pops it upward · speed grows on each bounce
			c.pace = false
			if c.vx == 0.0:
				c.vx = 90.0
			c.face = 1.0 if c.vx > 0.0 else -1.0
			if c.x < r.position.x + c.s * 0.6 or c.x > r.position.x + r.size.x - c.s * 0.6:
				c.vx = -clampf(c.vx * 1.15, -220.0, 220.0)
				c.x = clampf(c.x, r.position.x + c.s * 0.6, r.position.x + r.size.x - c.s * 0.6)
				b.vy = -170.0 - (70.0 if b.boost > 0.0 else 0.0)
				b.boost = 0.0
				for i in 5:
					b.parts.append({ "pos": Vector2(c.x - signf(c.vx) * c.s * 0.5, c.y - randf_range(0, c.s)),
						"vel": Vector2(signf(c.vx) * randf_range(30, 80), randf_range(-40, 10)), "life": 1.0 })
			b.vy += 600.0 * dt
			c.y = minf(b.G, c.y + b.vy * dt)
			if c.y >= b.G:
				b.vy = 0.0
			for p in b.parts:
				p.pos += p.vel * dt
				p.life -= dt * 2.0
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	var pv: float = b.press_v
	match b.id:
		"afterimages":
			CubeKit.stage(n, b)
			# dial: one violet → alternating red / cyan pasts
			var ghosts: Array = b.ghosts
			for i in ghosts.size():
				var g: Dictionary = ghosts[i]
				var col := Color(0.94, 0.31, 0.35, g.life * 0.3) if i % 2 == 0 else Color(0.31, 0.86, 0.94, g.life * 0.3)
				n.draw_set_transform(Vector2(g.x, g.y - g.hop), g.lean, Vector2.ONE)
				n.draw_rect(Rect2(-c.s / 2.0, -c.s, c.s, c.s), col)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			CubeKit.draw_cube(n, b)
		"landing_dust":
			CubeKit.stage(n, b)
			for p in b.parts:
				if p.kind == "ring":
					CubeKit.ellipse(n, Vector2(p.x, b.G + 1.0), p.r, p.r * 0.25, Color(0.59, 0.82, 0.96, p.life * 0.8), 1.6)
				else:
					n.draw_set_transform(p.pos, 0.0, Vector2(1.0, 1.6))
					n.draw_circle(Vector2.ZERO, 1.8, Color(0.47, 0.75, 0.94, p.life * 0.9))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			CubeKit.draw_cube(n, b)
		"skid":
			CubeKit.stage(n, b)
			for p in b.parts:
				n.draw_line(Vector2(p.pos.x, minf(p.pos.y, b.G)),
					Vector2(p.pos.x, minf(p.pos.y, b.G)) - p.vel * 0.03,
					Color(1, 0.71 + 0.29 * p.life, 0.35, p.life), 1.3)
			CubeKit.draw_cube(n, b)
		"speed_lines":
			CubeKit.stage(n, b)
			# dials: length ×3 · alpha ÷2 — bullet-time
			var speed: float = minf(1.0, absf(c.vx) / 60.0) + pv
			for i in 5:
				var y: float = c.y - c.s * (0.15 + i * 0.2)
				var len: float = (18.0 + i * 9.0) * speed * (1.0 + pv * 2.0)
				if len < 2.0:
					continue
				n.draw_line(Vector2(c.x - c.face * c.s * 0.6, y),
					Vector2(c.x - c.face * (c.s * 0.6 + len), y), Color(0.78, 0.8, 0.94, 0.1 + speed * 0.15), 1.5)
			CubeKit.draw_cube(n, b)
		_:
			Base.draw(n, b, t)
