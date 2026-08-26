extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
## AURAS & ENERGY — eight cube effects, ported from the web codex.

const TITLE := "Auras & energy"
const BLURB := "power-ups, shields, and anime tension"
const DEFS := [
	{ "id": "powerup", "name": "Power-up aura", "hint": "energy flames rise around it; press for the super surge" },
	{ "id": "ki", "name": "Ki charge", "hint": "wisps spiral inward while it gathers; press to release the burst" },
	{ "id": "shield", "name": "Energy shield", "hint": "a faceted bubble shimmers; press and an impact ripples across it" },
	{ "id": "focus", "name": "Focus lines", "hint": "press: the world's speed lines converge on the hero" },
	{ "id": "battle_glow", "name": "Battle glow", "hint": "a heartbeat of light; press startles it into a red flare" },
	{ "id": "overdrive", "name": "Overdrive", "hint": "press to TOGGLE overdrive — blue flames until you say otherwise" },
	{ "id": "inner_light", "name": "Inner light", "hint": "cracks of light run through the cube; press and they flare" },
	{ "id": "tension", "name": "Tension sparks", "hint": "one tick of static now and then; press for the full crackle" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	match b.id:
		"ki":
			b.wisps = []
		"shield":
			b.hit_a = 0.0
		"overdrive":
			b.on = false
		"inner_light":
			b.cracks = []
			for i in 4:
				var pts := [Vector2(randf_range(-0.4, 0.4), -randf_range(0, 0.9))]
				for k in 3:
					pts.append(pts[k] + Vector2(randf_range(-0.25, 0.25), randf_range(-0.25, 0.25)))
				b.cracks.append(pts)

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"powerup":
			b.press_v = 1.6
		"ki":
			b.press_v = 1.0
			for i in 14:
				var th := randf_range(0, TAU)
				b.parts.append({ "pos": Vector2(c.x, c.y - c.s * 0.5),
					"vel": Vector2(cos(th) * randf_range(60, 160), sin(th) * randf_range(40, 120)), "life": 1.0 })
			b.wisps = []
		"shield":
			b.press_v = 1.0
			b.hit_a = (pos - Vector2(c.x, c.y - c.s * 0.5)).angle()
		"focus", "battle_glow", "inner_light":
			b.press_v = 1.0
		"overdrive":
			b.on = not b.on
		"tension":
			b.press_v = 1.4

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	b.press_v = maxf(0.0, b.press_v - dt * (0.4 if b.id == "battle_glow" else (1.0 if b.id in ["powerup", "tension"] else 1.6)))
	match b.id:
		"powerup":
			if randf() < 0.6 + (0.4 if b.press_v > 0.0 else 0.0):
				b.parts.append({ "pos": Vector2(c.x + randf_range(-c.s * 0.7, c.s * 0.7), c.y), "life": 1.0 })
			for p in b.parts:
				p.pos.y -= (70.0 + (90.0 if b.press_v > 0.0 else 0.0)) * dt
				p.pos.x += (c.x - p.pos.x) * dt * 2.0
				p.life -= dt * 1.4
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
			c.tint = Color(0.42, 0.37, 0.66) if b.press_v > 0.0 else null
		"ki":
			if randf() < 0.4:
				b.wisps.append({ "a": randf_range(0, TAU), "r": c.s * 2.0, "life": 1.0 })
			for w in b.wisps:
				w.r -= 45.0 * dt
				w.a += 2.2 * dt
				w.life -= dt * 0.8
			b.wisps = b.wisps.filter(func(w): return w.life > 0.0 and w.r > 3.0)
			for p in b.parts:
				p.pos += p.vel * dt
				p.life -= dt * 1.6
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"overdrive":
			if b.on and randf() < 0.8:
				b.parts.append({ "pos": Vector2(c.x + randf_range(-c.s * 0.6, c.s * 0.6), c.y - randf_range(0, c.s)), "life": 1.0 })
			for p in b.parts:
				p.pos.y -= 90.0 * dt
				p.life -= dt * 1.8
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
			c.tint = Color(0.22, 0.33, 0.62) if b.on else null

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	var pv: float = b.press_v
	CubeKit.stage(n, b)
	match b.id:
		"powerup":
			for p in b.parts:
				var col := Color(1, 0.9, 0.47, p.life * 0.6) if pv > 0.0 else Color(0.55, 0.67, 1.0, p.life * 0.5)
				CubeKit.glow(n, p.pos, 5.0 + p.life * 5.0, col, 2)
			CubeKit.draw_cube(n, b)
		"ki":
			CubeKit.draw_cube(n, b)
			for w in b.wisps:
				CubeKit.glow(n, Vector2(c.x + cos(w.a) * w.r, c.y - c.s * 0.5 + sin(w.a) * w.r * 0.7),
					3.0, Color(0.63, 0.86, 1.0, w.life * 0.7), 2)
			for p in b.parts:
				CubeKit.glow(n, p.pos, 4.0, Color(0.75, 0.92, 1.0, p.life * 0.8), 2)
		"shield":
			CubeKit.draw_cube(n, b)
			var rr: float = c.s * 1.3
			for i in 12:
				var th := i / 12.0 * TAU
				var a: float = 0.12 + maxf(0.0, sin(t * 2.0 + i * 1.7)) * 0.25
				if pv > 0.0:
					var d: float = absf(fposmod(th - b.hit_a + PI * 3.0, TAU) - PI)
					a += maxf(0.0, pv - d * 0.35) * 0.7
				CubeKit.ellipse(n, Vector2(c.x, c.y - c.s * 0.5), rr, rr * 1.05,
					Color(0.55, 0.9, 0.82, minf(1.0, a)), 2.5, th, th + 0.42, 6)
		"focus":
			CubeKit.draw_cube(n, b)
			if pv > 0.0:
				var r: Rect2 = b.rect
				var ctr := Vector2(c.x, c.y - c.s * 0.5)
				for i in 16:
					var th := i / 16.0 * TAU + pv * 0.5
					var r_out: float = r.size.x
					var r_in: float = c.s * (2.0 + pv * 2.0)
					n.draw_line(ctr + Vector2(cos(th), sin(th)) * r_out,
						ctr + Vector2(cos(th), sin(th)) * r_in, Color(0.9, 0.89, 0.96, pv * 0.6), 1.5)
		"battle_glow":
			var cyc: float = fmod(t * (1.0 + pv * 1.5), 1.3)
			var beat: float = exp(-pow((cyc - 0.12) * 12.0, 2.0)) + exp(-pow((cyc - 0.36) * 12.0, 2.0)) * 0.6
			var col := Color(1, 0.43, 0.43, 0.15 + beat * 0.4) if pv > 0.0 else Color(0.59, 0.67, 1.0, 0.10 + beat * 0.3)
			CubeKit.glow(n, Vector2(c.x, c.y - c.s * 0.5), c.s * (1.0 + beat * 0.5), col, 3)
			CubeKit.draw_cube(n, b)
		"overdrive":
			for p in b.parts:
				CubeKit.glow(n, p.pos, 4.0 + p.life * 5.0, Color(0.43, 0.7, 1.0, p.life * 0.6), 2)
			CubeKit.draw_cube(n, b)
		"inner_light":
			CubeKit.draw_cube(n, b)
			n.draw_set_transform(Vector2(c.x, c.y - c.hop), c.lean, Vector2.ONE)
			for pts in b.cracks:
				var a: float = clampf(0.35 + 0.25 * sin(t * 2.0 + pts[0].x * 9.0) + pv * 0.6, 0.0, 1.0)
				var poly := PackedVector2Array()
				for p in pts:
					poly.append(Vector2(p.x * c.s, clampf(p.y * c.s, -c.s, 0.0)))
				n.draw_polyline(poly, Color(1, 0.86, 0.55, a), 1.2 + pv * 1.5)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"tension":
			CubeKit.draw_cube(n, b)
			var chance: float = 0.04 + (0.8 if pv > 0.0 else 0.0)
			for i in (4 if pv > 0.0 else 1):
				if randf() < chance:
					var px: float = c.x + randf_range(-c.s, c.s) * 1.2
					var py: float = c.y - c.s * 0.5 + randf_range(-c.s, c.s) * 0.8
					var pts := PackedVector2Array()
					pts.append(Vector2(px, py))
					for k in 3:
						px += randf_range(-10, 10)
						py += randf_range(-8, 8)
						pts.append(Vector2(px, py))
					n.draw_polyline(pts, Color(0.86, 0.9, 1.0, 0.9), 1.2)
