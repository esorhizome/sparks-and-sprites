extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
## HALOS & BLESSINGS — eight cube effects, ported from the web codex.

const TITLE := "Halos & blessings"
const BLURB := "lights that follow, rings that sanctify"
const DEFS := [
	{ "id": "follow_halo", "name": "Following halo", "hint": "the classic: an ellipse of light that follows, a beat behind" },
	{ "id": "wings", "name": "Angel wings", "hint": "wing nubs flutter at its back; press and they unfurl" },
	{ "id": "sanctuary", "name": "Sanctuary ring", "hint": "holy ground travels with it; press to consecrate wider" },
	{ "id": "pillar", "name": "Light pillar", "hint": "a soft light from above; press and the full pillar descends" },
	{ "id": "guardians", "name": "Guardian orbs", "hint": "three lights keep watch; press and they snap into a shield" },
	{ "id": "blessing", "name": "Blessing rain", "hint": "light motes drift down around it; press and they all ascend" },
	{ "id": "radiant", "name": "Radiant burst", "hint": "a warm core glow; press for the cross-flare and ring" },
	{ "id": "spotlight", "name": "Saint's spotlight", "hint": "a beam from above follows it — lagging; press snaps it tight" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	match b.id:
		"follow_halo", "spotlight":
			b.hx = b.cub.x

static func press(b: Dictionary, _pos: Vector2) -> void:
	match b.id:
		_:
			b.press_v = 1.0 if b.id != "blessing" else 1.4

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	var decay := 0.6
	match b.id:
		"follow_halo", "radiant":
			decay = 1.6
		"blessing":
			decay = 1.0
	b.press_v = maxf(0.0, b.press_v - dt * decay)
	match b.id:
		"follow_halo":
			b.hx += (c.x - b.hx) * minf(1.0, dt * 5.0)
		"spotlight":
			b.hx += (c.x - b.hx) * minf(1.0, dt * (2.0 + b.press_v * 12.0))
		"pillar":
			if b.press_v > 0.0 and randf() < 0.5:
				b.parts.append({ "pos": Vector2(c.x + randf_range(-c.s, c.s) * 0.7, b.G), "life": 1.0 })
			for p in b.parts:
				p.pos.y -= 40.0 * dt
				p.life -= dt
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"blessing":
			var r: Rect2 = b.rect
			if randf() < 0.3:
				b.parts.append({ "pos": Vector2(c.x + randf_range(-c.s * 1.8, c.s * 1.8),
					r.position.y + randf_range(0, r.size.y * 0.3)), "life": 1.0 })
			for p in b.parts:
				p.pos.y += (-80.0 if b.press_v > 0.0 else 22.0) * dt
				p.life -= dt * 0.4
			b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.pos.y > b.rect.position.y - 8.0 and p.pos.y < b.G)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	var pv: float = b.press_v
	var gold := Color(1, 0.92, 0.67)
	CubeKit.stage(n, b)
	match b.id:
		"follow_halo":
			CubeKit.draw_cube(n, b)
			var hy: float = c.y - c.s * 1.5 + sin(t * 1.2) * 2.5
			var breath := 1.0 + 0.03 * sin(t * TAU / 3.0)
			for k in 3:
				CubeKit.ellipse(n, Vector2(b.hx, hy),
					(c.s * 0.55 + k * 1.5) * breath * (1.0 + pv * 0.3),
					(c.s * 0.16 + k * 0.8) * breath,
					Color(gold.r, gold.g, gold.b, 0.55 - k * 0.15 + pv * 0.3), 3.0 - k * 0.7)
		"wings":
			var spread: float = 0.25 + sin(t * 6.0) * 0.04 + pv * 1.1
			var bx: float = c.x - c.face * c.s * 0.3
			var by: float = c.y - c.s * 0.7
			for f in 4:
				CubeKit.qcurve(n, Vector2(bx, by),
					Vector2(bx - c.face * (10.0 + f * 8.0) * spread, by - (18.0 - f * 3.0) * spread),
					Vector2(bx - c.face * (20.0 + f * 12.0) * spread, by - (6.0 - f * 4.0) * spread + f * 3.0),
					Color(1, 0.98, 0.9, 0.5 + pv * 0.5), 2.0)
			CubeKit.draw_cube(n, b)
		"sanctuary":
			var rr: float = c.s * (1.1 + pv * 1.3)
			CubeKit.glow(n, Vector2(c.x, b.G), rr, Color(1, 0.94, 0.75, 0.12 + pv * 0.12), 2)
			CubeKit.ellipse(n, Vector2(c.x, b.G + 1.0), rr, rr * 0.24, Color(gold.r, gold.g, gold.b, 0.5 + pv * 0.4), 1.6)
			for i in 6:
				var a: float = t * 0.7 + i / 6.0 * TAU
				n.draw_rect(Rect2(Vector2(c.x + cos(a) * rr - 1.0, b.G + 1.0 + sin(a) * rr * 0.24 - 3.0),
					Vector2(2, 6)), Color(1, 0.94, 0.75, 0.6 + pv * 0.4))
			CubeKit.draw_cube(n, b)
		"pillar":
			var r: Rect2 = b.rect
			var w: float = c.s * (0.5 + pv * 1.1)
			var a2: float = 0.06 + pv * 0.3
			n.draw_colored_polygon(PackedVector2Array([
				Vector2(c.x - w * 0.6, r.position.y), Vector2(c.x + w * 0.6, r.position.y),
				Vector2(c.x + w, b.G), Vector2(c.x - w, b.G)]), Color(1, 0.97, 0.86, a2))
			for p in b.parts:
				CubeKit.glow(n, p.pos, 3.0, Color(1, 0.97, 0.86, p.life * 0.8), 2)
			CubeKit.draw_cube(n, b)
		"guardians":
			CubeKit.draw_cube(n, b)
			var pts := PackedVector2Array()
			for i in 3:
				var pos: Vector2
				if pv > 0.15:
					var th := -PI / 2.0 + i / 3.0 * TAU
					pos = Vector2(c.x + c.face * c.s * 0.9 + cos(th) * c.s * 0.55,
						c.y - c.s * 0.55 + sin(th) * c.s * 0.55)
				else:
					var a: float = t * 1.4 + i / 3.0 * TAU
					pos = Vector2(c.x + cos(a) * c.s * 1.15, c.y - c.s * 0.5 + sin(a) * c.s * 0.65)
				pts.append(pos)
				CubeKit.glow(n, pos, 5.0 + pv * 3.0, Color(1, 0.94, 0.75, 0.9), 2)
			if pv > 0.15:
				n.draw_colored_polygon(pts, Color(1, 0.94, 0.75, pv * 0.22))
		"blessing":
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				CubeKit.glow(n, p.pos, 3.5, Color(1, 0.96, 0.82, p.life * 0.7), 2)
		"radiant":
			CubeKit.draw_cube(n, b)
			CubeKit.glow(n, Vector2(c.x, c.y - c.s * 0.5), c.s * 0.8,
				Color(1, 0.94, 0.78, 0.14 + 0.05 * sin(t * 1.3)), 2)
			if pv > 0.0:
				var L: float = 10.0 + (1.0 - pv) * c.s * 2.4
				var hy2: float = c.y - c.s * 0.5
				n.draw_line(Vector2(c.x - L, hy2), Vector2(c.x + L, hy2), Color(1, 0.96, 0.84, pv * 0.9), 2.0)
				n.draw_line(Vector2(c.x, hy2 - L * 0.8), Vector2(c.x, hy2 + L * 0.8), Color(1, 0.96, 0.84, pv * 0.9), 2.0)
				CubeKit.ellipse(n, Vector2(c.x, hy2), L * 0.8, L * 0.5, Color(1, 0.96, 0.84, pv * 0.9), 1.5)
		"spotlight":
			var r: Rect2 = b.rect
			var w: float = c.s * (1.4 - pv * 0.6)
			n.draw_colored_polygon(PackedVector2Array([
				Vector2(b.hx - 6.0, r.position.y), Vector2(b.hx + 6.0, r.position.y),
				Vector2(b.hx + w, b.G), Vector2(b.hx - w, b.G)]), Color(1, 0.97, 0.88, 0.10 + pv * 0.18))
			n.draw_set_transform(Vector2(b.hx, b.G + 1.0), 0.0, Vector2(1.0, 0.22))
			n.draw_circle(Vector2.ZERO, w, Color(1, 0.97, 0.88, 0.10 + pv * 0.18))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			CubeKit.draw_cube(n, b)
