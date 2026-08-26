extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
## MOVEMENT — eight cube effects, ported from the web codex.

const TITLE := "Movement"
const BLURB := "dashes, jumps, and the dust they kick"
const DEFS := [
	{ "id": "afterimages", "name": "Afterimages", "hint": "its past selves trail behind; press for a dash of ghosts" },
	{ "id": "double_jump", "name": "Double jump", "hint": "press once to jump — again mid-air for the ring-boost" },
	{ "id": "landing_dust", "name": "Landing dust", "hint": "press: a leap — the landing kicks the honest dust" },
	{ "id": "skid", "name": "Skid smoke", "hint": "watch its turns — every U-turn skids; press for a burnout" },
	{ "id": "speed_lines", "name": "Speed lines", "hint": "lines stream behind it as it moves; press: sonic sprint" },
	{ "id": "teleport", "name": "Teleport blink", "hint": "press: it implodes into motes and reappears where you clicked" },
	{ "id": "backflip", "name": "Backflip", "hint": "press: a full backflip with a ribbon of trail" },
	{ "id": "wall_kick", "name": "Wall kick", "hint": "it runs wall to wall, kicking off each; press: super wall-jump" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	match b.id:
		"afterimages":
			b.ghosts = []
			b.timer = 0.0
			b.dash = 0.0
		"double_jump":
			b.vy = 0.0
			b.air = false
			b.can_double = false
		"landing_dust":
			b.vy = 0.0
			b.air = false
		"skid":
			b.last_face = 1.0
		"teleport":
			b.phase = 0
			b.target = 0.0
			b.flash = 0.0
		"backflip":
			b.flip = -1.0
		"wall_kick":
			b.vy = 0.0
			b.boost = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	match b.id:
		"afterimages":
			if b.dash <= 0.0:
				b.dash = 0.3
				c.pace = false
				c.vx = c.face * 420.0
		"double_jump":
			if not b.air:
				b.air = true
				b.can_double = true
				b.vy = -230.0
			elif b.can_double:
				b.can_double = false
				b.vy = -230.0
				b.parts.append({ "kind": "ring", "pos": Vector2(c.x, c.y), "r": 4.0, "life": 1.0 })
		"landing_dust":
			if not b.air:
				b.air = true
				b.vy = -300.0
		"skid":
			b.press_v = 0.8
		"speed_lines":
			b.press_v = 1.0
		"teleport":
			if b.phase == 0:
				b.phase = 1
				b.target = clampf(pos.x, r.position.x + c.s, r.position.x + r.size.x - c.s)
				for i in 14:
					b.parts.append({ "kind": "mote", "pos": Vector2(c.x + randf_range(-c.s * 0.5, c.s * 0.5),
						c.y - randf_range(0, c.s)), "life": 1.0 })
				c.alpha = 0.0
		"backflip":
			if b.flip < 0.0:
				b.flip = 0.0
		"wall_kick":
			b.boost = 1.0

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	match b.id:
		"afterimages":
			if b.dash > 0.0:
				b.dash -= dt
				if c.x < r.position.x + c.s or c.x > r.position.x + r.size.x - c.s or b.dash <= 0.0:
					b.dash = 0.0
					c.pace = true
					c.x = clampf(c.x, r.position.x + c.s, r.position.x + r.size.x - c.s)
			b.timer -= dt
			if b.timer <= 0.0:
				b.ghosts.append({ "x": c.x, "y": c.y, "hop": c.hop, "lean": c.lean, "life": 1.0 })
				b.timer = 0.02 if b.dash > 0.0 else 0.12
			for g in b.ghosts:
				g.life -= dt * (2.0 if b.dash > 0.0 else 1.4)
			b.ghosts = b.ghosts.filter(func(g): return g.life > 0.0)
		"double_jump", "landing_dust":
			if b.air:
				b.vy += (620.0 if b.id == "double_jump" else 640.0) * dt
				c.y += b.vy * dt
				if c.y >= b.G:
					c.y = b.G
					b.air = false
					if b.id == "landing_dust":
						for i in 10:
							b.parts.append({ "kind": "dust", "pos": Vector2(c.x + randf_range(-4, 4), b.G),
								"vel": Vector2(randf_range(30, 90) * (1.0 if i % 2 == 0 else -1.0), randf_range(-60, -10)), "life": 1.0 })
					b.vy = 0.0
			elif b.id == "landing_dust" and absf(c.vx) > 20.0 and randf() < 0.1:
				b.parts.append({ "kind": "dust", "pos": Vector2(c.x - c.face * c.s * 0.4, b.G),
					"vel": Vector2(-c.face * randf_range(10, 30), randf_range(-20, -5)), "life": 0.5 })
			for p in b.parts:
				if p.kind == "ring":
					p.r += 110.0 * dt
					p.life -= dt * 2.2
				else:
					p.pos += p.vel * dt
					p.vel.y += 60.0 * dt
					p.vel.x *= pow(0.2, dt)
					p.life -= dt * 1.6
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"skid":
			if c.face != b.last_face:
				b.last_face = c.face
				for i in 6:
					b.parts.append({ "pos": Vector2(c.x - c.face * c.s * 0.3, b.G),
						"vel": Vector2(-c.face * randf_range(20, 60), randf_range(-30, -8)), "life": 1.0 })
			if b.press_v > 0.0:
				b.press_v -= dt
				b.parts.append({ "pos": Vector2(c.x + randf_range(-6, 6), b.G),
					"vel": Vector2(randf_range(-40, 40), randf_range(-40, -10)), "life": 1.0 })
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.x *= pow(0.3, dt)
				p.life -= dt * 1.2
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"speed_lines":
			b.press_v = maxf(0.0, b.press_v - dt * 1.4)
		"teleport":
			b.flash = maxf(0.0, b.flash - dt * 2.0)
			if b.phase == 1:
				var arrived := 0
				for p in b.parts:
					p.pos.x += (b.target - p.pos.x) * dt * 6.0
					p.pos.y += (c.y - c.s * 0.5 - p.pos.y) * dt * 6.0
					if absf(p.pos.x - b.target) < 6.0:
						arrived += 1
				if arrived > 10:
					b.phase = 0
					b.parts = []
					c.x = b.target
					c.alpha = 1.0
					b.flash = 1.0
		"backflip":
			if b.flip >= 0.0:
				b.flip += dt * 1.6
				var k: float = minf(1.0, b.flip)
				c.y = b.G - sin(k * PI) * c.s * 1.7
				c.spin = -c.face * k * TAU
				b.parts.append({ "pos": Vector2(c.x, c.y - c.s * 0.5), "life": 1.0 })
				if b.flip >= 1.0:
					b.flip = -1.0
					c.y = b.G
					c.spin = 0.0
			for p in b.parts:
				p.life -= dt * 2.0
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"wall_kick":
			c.pace = false
			if c.vx == 0.0:
				c.vx = 70.0
			c.face = 1.0 if c.vx > 0.0 else -1.0
			if c.x < r.position.x + c.s * 0.6 or c.x > r.position.x + r.size.x - c.s * 0.6:
				c.vx = -c.vx
				c.x = clampf(c.x, r.position.x + c.s * 0.6, r.position.x + r.size.x - c.s * 0.6)
				for i in 5:
					b.parts.append({ "pos": Vector2(c.x - signf(c.vx) * c.s * 0.5, c.y - randf_range(0, c.s)),
						"vel": Vector2(signf(c.vx) * randf_range(30, 80), randf_range(-40, 10)), "life": 1.0 })
				if b.boost > 0.0:
					b.vy = -240.0
					b.boost = 0.0
			b.vy += 600.0 * dt
			c.y = minf(b.G, c.y + b.vy * dt)
			if c.y >= b.G:
				b.vy = 0.0
			for p in b.parts:
				p.pos += p.vel * dt
				p.life -= dt * 2.0
			b.parts = b.parts.filter(func(p): return p.life > 0.0)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	var pv: float = b.press_v
	CubeKit.stage(n, b)
	match b.id:
		"afterimages":
			for g in b.ghosts:
				n.draw_set_transform(Vector2(g.x, g.y - g.hop), g.lean, Vector2.ONE)
				n.draw_rect(Rect2(-c.s / 2.0, -c.s, c.s, c.s), Color(0.42, 0.39, 0.66, g.life * 0.3))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			CubeKit.draw_cube(n, b)
		"double_jump":
			for p in b.parts:
				if p.kind == "ring":
					CubeKit.ellipse(n, p.pos, p.r, p.r * 0.3, Color(0.78, 0.82, 1.0, p.life * 0.8), 2.0)
			CubeKit.draw_cube(n, b)
		"landing_dust", "skid":
			for p in b.parts:
				var pos: Vector2 = p.pos if p.has("pos") else Vector2.ZERO
				n.draw_circle(Vector2(pos.x, minf(pos.y, b.G)), 3.5 * (1.5 - p.life),
					Color(0.63, 0.59, 0.71, p.life * 0.45))
			CubeKit.draw_cube(n, b)
		"speed_lines":
			var speed: float = minf(1.0, absf(c.vx) / 60.0) + pv
			for i in 5:
				var y: float = c.y - c.s * (0.15 + i * 0.2)
				var len: float = (6.0 + i * 3.0) * speed * (1.0 + pv * 2.0)
				if len < 2.0:
					continue
				n.draw_line(Vector2(c.x - c.face * c.s * 0.6, y),
					Vector2(c.x - c.face * (c.s * 0.6 + len), y), Color(0.78, 0.8, 0.94, 0.2 + speed * 0.3), 1.5)
			CubeKit.draw_cube(n, b)
		"teleport":
			for p in b.parts:
				CubeKit.glow(n, p.pos, 4.0, Color(0.75, 0.71, 1.0, 0.8), 2)
			if b.flash > 0.0:
				CubeKit.glow(n, Vector2(c.x, c.y - c.s * 0.5), c.s * 1.6, Color(0.75, 0.71, 1.0, b.flash * 0.5), 3)
			if randf() < 0.06:
				CubeKit.glow(n, Vector2(c.x + randf_range(-c.s, c.s) * 0.5, c.y - randf_range(0, c.s)),
					3.0, Color(0.75, 0.71, 1.0, 0.5), 2)
			CubeKit.draw_cube(n, b)
		"backflip":
			for p in b.parts:
				CubeKit.glow(n, p.pos, 5.0, Color(0.7, 0.78, 1.0, p.life * 0.4), 2)
			CubeKit.draw_cube(n, b)
		"wall_kick":
			var r: Rect2 = b.rect
			n.draw_rect(Rect2(r.position.x, b.G - c.s * 2.4, 4, c.s * 2.4), Color(0.47, 0.45, 0.63, 0.4))
			n.draw_rect(Rect2(r.position.x + r.size.x - 4, b.G - c.s * 2.4, 4, c.s * 2.4), Color(0.47, 0.45, 0.63, 0.4))
			for p in b.parts:
				n.draw_rect(Rect2(p.pos, Vector2(2, 2)), Color(1, 0.86, 0.59, p.life))
			CubeKit.draw_cube(n, b)
