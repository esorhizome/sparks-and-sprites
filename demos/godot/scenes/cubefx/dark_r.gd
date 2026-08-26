extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
const Base := preload("res://scenes/cubefx/dark.gd")
## DARK & VOID — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"clone": { "name": "Golden double", "hint": "triumph gold — a shorter lag, a brighter dash" },
	"grasp": { "name": "Angel hand", "hint": "descending FROM ABOVE in light — direction and palette" },
	"dark_aura": { "name": "Holy smoke", "hint": "white — plumes rise straighter and thin faster" },
	"vanish": { "name": "Flash vanish", "hint": "by LIGHT — an instant flash, then gone" },
	"black_hole": { "name": "Sun spot", "hint": "inverted — it SHINES and pushes away" },
	"veil": { "name": "Dawn veil", "hint": "made of light — the world washes out, not dark" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)
	if b.id == "vanish":
		b.flash = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"vanish":
			# dial: the poof replaced by a flash — no smoke on the way out
			b.gone = 1.0
			b.flash = 1.0
			c.alpha = 0.0
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"clone":
			# dial: history 30 → 14 frames (shorter lag) · dash 260 → 340
			b.press_v = maxf(0.0, b.press_v - dt * 1.2)
			b.history.append({ "x": c.x, "hop": c.hop, "lean": c.lean })
			if b.history.size() > 14:
				b.history.pop_front()
			if b.attack >= 0.0:
				b.attack += dt * 1.4
				b.ax += c.face * 340.0 * dt
				if b.attack >= 1.0:
					b.attack = -1.0
		"dark_aura":
			# dials: rise straighter (sway ÷3) · thin 1.0 → 1.7
			b.press_v = maxf(0.0, b.press_v - dt * 1.2)
			if randf() < 0.4 + b.press_v:
				b.parts.append({ "pos": Vector2(c.x + randf_range(-c.s * 0.6, c.s * 0.6), c.y - randf_range(0, c.s)),
					"r": randf_range(3, 6) * (1.0 + b.press_v), "life": 1.0 })
			for p in b.parts:
				p.pos.y -= (32.0 + b.press_v * 60.0) * dt
				p.pos.x += sin(p.pos.y * 0.15) * 3.0 * dt
				p.r += 4.0 * dt
				p.life -= dt * 1.7
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"vanish":
			# dial: return is also a flash, not smoke
			b.flash = maxf(0.0, b.flash - dt * 2.5)
			if b.gone > 0.0:
				b.gone -= dt * 0.8
				if b.gone <= 0.0:
					c.alpha = 1.0
					b.flash = 1.0
			for p in b.parts:
				p.pos += p.vel * dt
				p.r += 6.0 * dt
				p.life -= dt * 1.1
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"black_hole":
			# dial: pull → push, lean AWAY
			if b.hole != null:
				var hole: Dictionary = b.hole
				if randf() < 0.5:
					b.parts.append({ "pos": hole.pos + Vector2(randf_range(-6, 6), randf_range(-4, 4)), "life": 1.0 })
				c.lean = signf(c.x - hole.pos.x) * 0.12
				for p in b.parts:
					var d: Vector2 = p.pos - hole.pos
					p.pos += d.normalized() * 70.0 * dt
					p.life -= dt * 1.3
				b.parts = b.parts.filter(func(p): return p.life > 0.0)
				hole.life -= dt
				if hole.life <= 0.0:
					b.hole = null
					b.parts = []
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	var pv: float = b.press_v
	match b.id:
		"clone":
			CubeKit.stage(n, b)
			var cx: float
			var chop: float
			var clean: float
			var alpha := 0.65
			if b.attack >= 0.0:
				cx = b.ax
				chop = 0.0
				clean = c.face * 0.2
				alpha = maxf(0.0, 1.0 - b.attack)
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
			n.draw_rect(Rect2(-c.s / 2.0, -c.s, c.s, c.s), Color(0.78, 0.63, 0.24, alpha * 0.8))
			n.draw_rect(Rect2(-c.s / 2.0, -c.s, c.s, c.s), Color(1, 0.9, 0.59, alpha), false, 1.5)
			n.draw_rect(Rect2(-c.s * 0.15, -c.s * 0.66, 2.5, 4.0), Color(1, 0.96, 0.82, alpha))
			n.draw_rect(Rect2(c.s * 0.1, -c.s * 0.66, 2.5, 4.0), Color(1, 0.96, 0.82, alpha))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			CubeKit.draw_cube(n, b)
		"grasp":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			var r: Rect2 = b.rect
			for p in b.parts:
				# dial: the hand reaches DOWN from the sky, in light
				var down: float = sin(minf(1.0, (1.6 - p.life) * 2.0) * PI * 0.5) * minf(1.0, p.life * 2.0)
				var top := r.position.y - 2.0
				var wrist := Vector2(p.x, top + c.s * 1.1 * down)
				n.draw_line(Vector2(p.x, top), wrist, Color(1, 0.96, 0.82, minf(1.0, p.life * 1.2)), 5.0)
				for f in range(-2, 3):
					CubeKit.qcurve(n, wrist,
						Vector2(p.x + f * 5.0, top + c.s * 1.4 * down),
						Vector2(p.x + f * 6.0, top + c.s * 1.25 * down + sin(t * 6.0 + f) * 2.0),
						Color(1, 0.94, 0.75, minf(1.0, p.life * 1.2)), 2.5)
				CubeKit.glow(n, wrist, 8.0, Color(1, 0.96, 0.82, minf(1.0, p.life) * 0.5), 2)
		"dark_aura":
			CubeKit.stage(n, b)
			for p in b.parts:
				n.draw_circle(p.pos, p.r, Color(0.96, 0.95, 0.92, p.life * 0.3))
			CubeKit.draw_cube(n, b)
		"vanish":
			CubeKit.stage(n, b)
			if b.flash > 0.0:
				CubeKit.glow(n, Vector2(c.x, c.y - c.s * 0.5), c.s * (1.0 + (1.0 - b.flash) * 1.2),
					Color(1, 0.98, 0.9, b.flash * 0.9), 3)
			CubeKit.draw_cube(n, b)
		"black_hole":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			if b.hole != null:
				var hole: Dictionary = b.hole
				for p in b.parts:
					n.draw_rect(Rect2(p.pos, Vector2(1.8, 1.8)), Color(1, 0.9, 0.63, p.life * 0.8))
				CubeKit.glow(n, hole.pos, 12.0, Color(1, 0.92, 0.71, 0.9), 3)
				CubeKit.ellipse(n, hole.pos, 11.0, 7.5, Color(1, 0.86, 0.47, 0.8), 1.5)
		"veil":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			var r: Rect2 = b.rect
			var reach: float = c.s * (2.0 + pv * 1.8 + sin(t * 1.2) * 0.15)
			var ctr := Vector2(c.x, c.y - c.s * 0.5)
			for i in 10:
				var k := i / 9.0
				var rr: float = reach + k * r.size.x * 0.5
				CubeKit.ellipse(n, ctr, rr, rr * 0.8, Color(0.98, 0.96, 0.9, 0.5 * k), 9.0, 0, TAU, 26)
		_:
			Base.draw(n, b, t)
