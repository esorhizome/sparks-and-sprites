extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
## DARK & VOID — six cube effects, ported from the web codex.

const TITLE := "Dark & void"
const BLURB := "clones, veils, and hands from below"
const DEFS := [
	{ "id": "clone", "name": "Shadow clone", "hint": "a dark twin mimics it, a beat late; press sends the twin ahead" },
	{ "id": "grasp", "name": "Void grasp", "hint": "its shadow writhes; press and a dark hand rises where you click" },
	{ "id": "dark_aura", "name": "Dark aura", "hint": "purple smoke coils off it; press for the eruption" },
	{ "id": "vanish", "name": "Smoke vanish", "hint": "press: a poof of smoke — and no cube until it clears" },
	{ "id": "black_hole", "name": "Black hole", "hint": "press: a void opens ahead — everything leans toward it" },
	{ "id": "veil", "name": "Night veil", "hint": "the dark closes in — light survives only near the hero" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	match b.id:
		"clone":
			b.history = []
			b.attack = -1.0
			b.ax = 0.0
		"vanish":
			b.gone = 0.0
		"black_hole":
			b.hole = null

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	match b.id:
		"clone":
			if b.attack < 0.0:
				b.attack = 0.0
				b.ax = c.x
		"grasp":
			b.parts.append({ "kind": "hand", "x": clampf(pos.x, r.position.x + 10, r.position.x + r.size.x - 10), "life": 1.6 })
		"dark_aura", "veil":
			b.press_v = 1.0
		"vanish":
			b.gone = 1.0
			c.alpha = 0.0
			for i in 10:
				b.parts.append({ "pos": Vector2(c.x + randf_range(-c.s * 0.5, c.s * 0.5), c.y - randf_range(0, c.s)),
					"vel": Vector2(randf_range(-40, 40), randf_range(-50, -10)), "r": randf_range(5, 9), "life": 1.0 })
		"black_hole":
			if b.hole == null:
				b.hole = { "pos": Vector2(c.x + c.face * c.s * 2.4, c.y - c.s * 0.7), "life": 2.0 }

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	b.press_v = maxf(0.0, b.press_v - dt * (0.5 if b.id == "veil" else 1.2))
	match b.id:
		"clone":
			b.history.append({ "x": c.x, "hop": c.hop, "lean": c.lean })
			if b.history.size() > 30:
				b.history.pop_front()
			if b.attack >= 0.0:
				b.attack += dt * 1.4
				b.ax += c.face * 260.0 * dt
				if b.attack >= 1.0:
					b.attack = -1.0
		"grasp":
			for p in b.parts:
				p.life -= dt * 0.7
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"dark_aura":
			if randf() < 0.4 + b.press_v:
				b.parts.append({ "pos": Vector2(c.x + randf_range(-c.s * 0.6, c.s * 0.6), c.y - randf_range(0, c.s)),
					"r": randf_range(3, 6) * (1.0 + b.press_v), "life": 1.0 })
			for p in b.parts:
				p.pos.y -= (26.0 + b.press_v * 60.0) * dt
				p.pos.x += sin(p.pos.y * 0.15) * 10.0 * dt
				p.r += 4.0 * dt
				p.life -= dt
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"vanish":
			if b.gone > 0.0:
				b.gone -= dt * 0.8
				if b.gone <= 0.0:
					c.alpha = 1.0
					for i in 8:
						b.parts.append({ "pos": Vector2(c.x + randf_range(-c.s * 0.4, c.s * 0.4), c.y - randf_range(0, c.s)),
							"vel": Vector2(randf_range(-25, 25), randf_range(-30, -8)), "r": randf_range(4, 7), "life": 0.8 })
			elif randf() < 0.04:
				b.parts.append({ "pos": Vector2(c.x - c.face * c.s * 0.4, c.y - 4.0),
					"vel": Vector2(0, -12), "r": 3.0, "life": 0.7 })
			for p in b.parts:
				p.pos += p.vel * dt
				p.r += 6.0 * dt
				p.life -= dt * 1.1
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"black_hole":
			if b.hole != null:
				var hole: Dictionary = b.hole
				if randf() < 0.5:
					b.parts.append({ "pos": hole.pos + Vector2(randf_range(-c.s * 2, c.s * 2), randf_range(-c.s, c.s)), "life": 1.0 })
				c.lean = signf(hole.pos.x - c.x) * 0.12
				for p in b.parts:
					p.pos = p.pos.lerp(hole.pos, dt * 4.0)
					p.life -= dt * 1.3
				b.parts = b.parts.filter(func(p): return p.life > 0.0)
				hole.life -= dt
				if hole.life <= 0.0:
					b.hole = null
					b.parts = []

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	var pv: float = b.press_v
	CubeKit.stage(n, b)
	match b.id:
		"clone":
			var cx: float
			var chop: float
			var clean: float
			var alpha := 0.55
			if b.attack >= 0.0:
				cx = b.ax
				chop = 0.0
				clean = c.face * 0.2
				alpha = maxf(0.0, 1.0 - b.attack) * 0.8
			elif not b.history.is_empty():
				var past: Dictionary = b.history[0]
				cx = past.x
				chop = past.hop
				clean = past.lean
			else:
				cx = c.x
				chop = 0.0
				clean = 0.0
			n.draw_set_transform(Vector2(cx, c.y - chop), clean, Vector2.ONE)
			n.draw_rect(Rect2(-c.s / 2.0, -c.s, c.s, c.s), Color(0.094, 0.07, 0.157, alpha))
			n.draw_rect(Rect2(-c.s * 0.15, -c.s * 0.66, 2.5, 4.0), Color(0.7, 0.47, 1.0, alpha))
			n.draw_rect(Rect2(c.s * 0.1, -c.s * 0.66, 2.5, 4.0), Color(0.7, 0.47, 1.0, alpha))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			CubeKit.draw_cube(n, b)
		"grasp":
			n.draw_set_transform(Vector2(c.x + sin(t * 3.0) * 3.0, b.G + 2.0), 0.0,
				Vector2(1.0 + sin(t * 2.3) * 0.2, 0.3 + sin(t * 3.7) * 0.1))
			n.draw_circle(Vector2.ZERO, c.s * 0.6, Color(0.04, 0.024, 0.078, 0.55))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				var up: float = sin(minf(1.0, (1.6 - p.life) * 2.0) * PI * 0.5) * minf(1.0, p.life * 2.0)
				var wrist_top := Vector2(p.x, b.G - c.s * 1.1 * up)
				n.draw_line(Vector2(p.x, b.G), wrist_top, Color(0.118, 0.07, 0.196, minf(1.0, p.life * 1.5)), 5.0)
				for f in range(-2, 3):
					CubeKit.qcurve(n, wrist_top,
						Vector2(p.x + f * 5.0, b.G - c.s * 1.4 * up),
						Vector2(p.x + f * 6.0, b.G - c.s * 1.25 * up + sin(t * 6.0 + f) * 2.0),
						Color(0.118, 0.07, 0.196, minf(1.0, p.life * 1.5)), 2.5)
		"dark_aura":
			for p in b.parts:
				n.draw_circle(p.pos, p.r, Color(0.27, 0.118, 0.43, p.life * 0.35))
			CubeKit.draw_cube(n, b)
		"vanish":
			for p in b.parts:
				n.draw_circle(p.pos, p.r, Color(0.24, 0.22, 0.31, p.life * 0.5))
			CubeKit.draw_cube(n, b)
		"black_hole":
			CubeKit.draw_cube(n, b)
			if b.hole != null:
				var hole: Dictionary = b.hole
				for p in b.parts:
					n.draw_rect(Rect2(p.pos, Vector2(1.8, 1.8)), Color(0.67, 0.55, 0.86, p.life * 0.7))
				n.draw_set_transform(hole.pos, 0.0, Vector2(1.0, 0.7))
				n.draw_circle(Vector2.ZERO, 9.0, Color(0.02, 0.012, 0.031))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				CubeKit.ellipse(n, hole.pos, 11.0, 7.5, Color(0.75, 0.59, 1.0, 0.7), 1.5)
		"veil":
			CubeKit.draw_cube(n, b)
			var r: Rect2 = b.rect
			var reach: float = c.s * (2.0 + pv * 1.8 + sin(t * 1.2) * 0.15)
			var ctr := Vector2(c.x, c.y - c.s * 0.5)
			# darkness as ring segments closing in around the light
			for i in 10:
				var k := i / 9.0
				var rr: float = reach + k * r.size.x * 0.5
				CubeKit.ellipse(n, ctr, rr, rr * 0.8, Color(0.02, 0.012, 0.039, 0.55 * k), 9.0, 0, TAU, 26)
