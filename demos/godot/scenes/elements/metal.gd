extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
## MERCURY & METAL — eight buttons, ported from the web bestiary.

const TITLE := "Mercury & metal"
const BLURB := "beads, chrome, forge-heat, and molten drips"
const DEFS := [
	{ "id": "mercury", "name": "Mercury beads", "hint": "quicksilver beads roam and merge; press to scatter them" },
	{ "id": "quicksilver", "name": "Quicksilver trail", "hint": "a metal drop orbits, beading behind itself; press for speed" },
	{ "id": "chrome_sweep", "name": "Chrome sweep", "hint": "a mirror sheen crosses every few seconds; press for a double flash" },
	{ "id": "molten_drip", "name": "Molten drip", "hint": "gold gathers and drips off the bottom edge; press to pour" },
	{ "id": "forge", "name": "Forge", "hint": "the steel breathes from black to orange heat; press to hammer it" },
	{ "id": "rivet", "name": "Rivet gleam", "hint": "corner rivets glint in turn; press and all four fire" },
	{ "id": "liquid_chrome", "name": "Liquid chrome", "hint": "the mirror surface undulates; press to send it wobbling" },
	{ "id": "magnetite", "name": "Magnetite", "hint": "iron filings comb themselves along a turning field; press to flip the poles" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	var r: Rect2 = b.rect
	match b.id:
		"mercury":
			b.beads = []
			for i in 6:
				b.beads.append({ "pos": Vector2(randf_range(12, r.size.x - 12), randf_range(10, r.size.y - 10)),
					"vel": Vector2(randf_range(-12, 12), randf_range(-8, 8)), "r": randf_range(3.5, 7.0) })
		"quicksilver":
			b.speed = 1.0
			b.a = 0.0
		"chrome_sweep":
			b.sweeps = [{ "p": -0.3, "v": 0.5 }]
			b.timer = 3.0
		"molten_drip":
			b.hangs = []
		"liquid_chrome":
			b.wob = 0.0
			b.wob_v = 0.0
		"magnetite":
			b.filings = []
			for i in 70:
				b.filings.append(Vector2(randf_range(4, r.size.x - 4), randf_range(4, r.size.y - 4)))
			b.flip = 0.0

static func press(b: Dictionary, _pos: Vector2) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"mercury":
			for bd in b.beads:
				bd.vel = Vector2(randf_range(-90, 90), randf_range(-70, 70))
		"quicksilver":
			b.speed = 3.4
		"chrome_sweep":
			b.sweeps.append({ "p": -0.3, "v": 2.2 })
			b.sweeps.append({ "p": 1.3, "v": -2.2 })
		"molten_drip", "rivet", "liquid_chrome":
			b.press_v = 1.0
			if b.id == "liquid_chrome":
				b.wob_v += 8.0
		"forge":
			b.press_v = 1.0
			for i in 16:
				var th := randf_range(-PI, 0.0)
				b.parts.append({ "pos": r.size / 2.0, "vel": Vector2(cos(th), sin(th)) * randf_range(50, 170), "life": 1.0 })
		"magnetite":
			b.flip += PI
			b.press_v = 1.0

static func tick(b: Dictionary, dt: float, t: float) -> void:
	b.press_v = maxf(0.0, b.press_v - dt * (0.8 if b.id == "molten_drip" else 1.8))
	var r: Rect2 = b.rect
	match b.id:
		"mercury":
			for bd in b.beads:
				bd.pos += bd.vel * dt
				bd.vel *= pow(0.5, dt)
				bd.vel += Vector2(randf_range(-6, 6), randf_range(-5, 5)) * dt * 10.0
				bd.pos.x = clampf(bd.pos.x, bd.r, r.size.x - bd.r)
				bd.pos.y = clampf(bd.pos.y, bd.r, r.size.y - bd.r)
		"quicksilver":
			b.speed += (1.0 - b.speed) * dt * 0.9
			b.a += b.speed * 1.8 * dt
			if randf() < 0.5:
				b.parts.append({ "pos": r.size / 2.0 + Vector2(cos(b.a) * r.size.x * 0.55, sin(b.a) * r.size.y * 0.9),
					"r": randf_range(1.5, 3.2), "life": 1.0 })
			for p in b.parts:
				p.life -= dt * 0.8
				p.pos.y += 4.0 * dt
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"chrome_sweep":
			b.timer -= dt
			if b.timer <= 0.0:
				b.sweeps.append({ "p": -0.3, "v": 0.5 })
				b.timer = randf_range(2.5, 4.0)
			for s in b.sweeps:
				s.p += s.v * dt
			b.sweeps = b.sweeps.filter(func(s): return s.p > -0.4 and s.p < 1.4)
		"molten_drip":
			if randf() < (0.5 if b.press_v > 0.0 else 0.03):
				b.hangs.append({ "x": randf_range(8, r.size.x - 8), "s": 0.0 })
			for hd in b.hangs:
				hd.s += dt * (3.0 if b.press_v > 0.0 else 0.8)
				if hd.s > 3.0:
					b.parts.append({ "pos": Vector2(hd.x, r.size.y + hd.s), "vel": Vector2(0, 30), "life": 1.0 })
					hd.s = -99.0
			b.hangs = b.hangs.filter(func(hd): return hd.s > -1.0)
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += 220.0 * dt
				p.life -= dt * 0.6
			b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.pos.y < r.size.y + 60.0)
		"forge":
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += 260.0 * dt
				p.life -= dt * 1.5
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"liquid_chrome":
			b.wob_v += -b.wob * 30.0 * dt
			b.wob_v *= pow(0.25, dt)
			b.wob += b.wob_v * dt

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	match b.id:
		"mercury":
			ElemKit.face(n, r, Color(0.1, 0.11, 0.133, 0.97), Color(0.75, 0.78, 0.84, 0.5))
			ElemKit.label(n, r, "HG", Color(0.88, 0.91, 0.94, 0.9))
			var beads: Array = b.beads
			for i in beads.size():          # necks between close beads
				for j in range(i + 1, beads.size()):
					var a: Dictionary = beads[i]
					var c: Dictionary = beads[j]
					if a.pos.distance_to(c.pos) < (a.r + c.r) * 1.7:
						n.draw_line(o + a.pos, o + c.pos, Color(0.78, 0.82, 0.86, 0.85), minf(a.r, c.r) * 1.1)
			for bd in beads:
				n.draw_circle(o + bd.pos, bd.r, Color(0.73, 0.76, 0.81))
				n.draw_circle(o + bd.pos - Vector2(bd.r * 0.3, bd.r * 0.35), bd.r * 0.35, Color(0.97, 0.98, 1.0))
		"quicksilver":
			ElemKit.face(n, r, Color(0.094, 0.1, 0.125, 0.96), Color(0.75, 0.78, 0.84, 0.5))
			ElemKit.label(n, r, "ORBIT", Color(0.89, 0.92, 0.95, 0.9))
			for p in b.parts:
				var rr: float = maxf(0.4, p.r * p.life)
				n.draw_circle(o + p.pos, rr, Color(0.66, 0.7, 0.76, p.life * 0.85))
				n.draw_circle(o + p.pos - Vector2(rr * 0.3, rr * 0.3), rr * 0.35, Color(0.95, 0.96, 0.98, p.life))
			var hp := o + r.size / 2.0 + Vector2(cos(b.a) * r.size.x * 0.55, sin(b.a) * r.size.y * 0.9)
			n.draw_circle(hp, 6.0, Color(0.46, 0.49, 0.55))
			n.draw_circle(hp - Vector2(2, 2), 2.4, Color(1, 1, 1))
		"chrome_sweep":
			for i in 8:                      # banded steel
				var k := i / 8.0
				var v := 0.14 + 0.13 * absf(sin(k * PI))
				n.draw_rect(Rect2(o.x, o.y + k * r.size.y, r.size.x, r.size.y / 8.0 + 1), Color(v, v + 0.02, v + 0.05))
			for s in b.sweeps:
				var sx: float = o.x + r.size.x * s.p
				n.draw_line(Vector2(sx, o.y), Vector2(sx + 14, o.y + r.size.y), Color(1, 1, 1, 0.45), 8.0)
			ElemKit.ring_face(n, r, Color(0.78, 0.82, 0.88, 0.6))
			ElemKit.label(n, r, "CHROME", Color(0.91, 0.93, 0.96))
		"molten_drip":
			ElemKit.face(n, r, Color(0.157, 0.1, 0.04, 0.96), Color(1, 0.75, 0.35, 0.6))
			ElemKit.label(n, r, "SMELT", Color(1, 0.91, 0.75))
			for hd in b.hangs:
				var y := o.y + r.size.y
				n.draw_set_transform(Vector2(o.x + hd.x, y + hd.s), 0.0, Vector2(1.0, 1.0 + hd.s * 0.4))
				n.draw_circle(Vector2.ZERO, 2.0 + hd.s * 0.5, Color(1, 0.9, 0.55, 0.95))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for p in b.parts:
				n.draw_set_transform(o + p.pos, 0.0, Vector2(1.0, 1.7))
				n.draw_circle(Vector2.ZERO, 2.0, Color(1, 0.78, 0.35, p.life))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"forge":
			var heat := 0.5 + 0.5 * sin(t * 0.7)
			var col := Color(
				minf(1.0, 0.12 + heat * 0.78 + pv * 0.1),
				minf(1.0, 0.063 + heat * 0.35 + pv * 0.47),
				minf(1.0, 0.078 + pv * 0.78))
			ElemKit.face(n, r, col, Color(1, 0.78, 0.55, 0.5))
			ElemKit.label(n, r, "STRIKE", Color(0.16, 0.078, 0.031) if heat > 0.5 or pv > 0.0 else Color(1, 0.85, 0.66))
			for p in b.parts:
				n.draw_line(o + p.pos, o + p.pos - p.vel * 0.03, Color(1, 0.82, 0.47, p.life), 1.4)
		"rivet":
			for i in 4:                      # brushed steel + four rivets
				n.draw_rect(Rect2(o.x, o.y + i * r.size.y / 4.0, r.size.x, r.size.y / 4.0 + 1),
					Color(0.22 + i * 0.015, 0.24 + i * 0.015, 0.27 + i * 0.015))
			ElemKit.ring_face(n, r, Color(0.7, 0.75, 0.8, 0.6))
			ElemKit.label(n, r, "RIVETED", Color(0.9, 0.92, 0.95))
			var rivets := [o + Vector2(10, 9), o + Vector2(r.size.x - 10, 9),
				o + Vector2(r.size.x - 10, r.size.y - 9), o + Vector2(10, r.size.y - 9)]
			var active := int(t * 1.2) % 4
			var phase := fmod(t * 1.2, 1.0)
			for i in rivets.size():
				n.draw_circle(rivets[i], 3.4, Color(0.36, 0.39, 0.43))
				var glint: float = maxf(sin(phase * PI) if i == active else 0.0, pv)
				if glint > 0.02:
					var L := 6.0 + glint * 6.0
					n.draw_line(rivets[i] - Vector2(L, 0), rivets[i] + Vector2(L, 0), Color(1, 1, 1, glint * 0.9), 1.2)
					n.draw_line(rivets[i] - Vector2(0, L), rivets[i] + Vector2(0, L), Color(1, 1, 1, glint * 0.9), 1.2)
		"liquid_chrome":
			var y := 0.0
			while y < r.size.y:              # rolling mirror bands
				var k := y / r.size.y
				var shift: float = sin(k * 6.0 + t * 1.5) * (3.0 + b.wob * 4.0) + sin(k * 13.0 - t * 2.3) * 1.5
				var bright := 0.5 + 0.5 * sin(k * 9.0 + shift * 0.35 + t * 0.7)
				var v := 0.16 + bright * 0.66
				n.draw_rect(Rect2(o.x + shift, o.y + y, r.size.x, 3.2), Color(v, v + 0.02, v + 0.055))
				y += 3.0
			ElemKit.ring_face(n, r, Color(0.86, 0.9, 0.94, 0.7))
			ElemKit.label(n, r, "MELT", Color(0.078, 0.094, 0.118, 0.85))
		"magnetite":
			ElemKit.face(n, r, Color(0.078, 0.078, 0.1, 0.97), Color(0.67, 0.7, 0.76, 0.5))
			var fa: float = t * 0.5 + b.flip
			var pp := r.size / 2.0 + Vector2(cos(fa) * r.size.x * 0.4, sin(fa) * r.size.y * 0.35)
			var qq := r.size / 2.0 - Vector2(cos(fa) * r.size.x * 0.4, sin(fa) * r.size.y * 0.35)
			for f in b.filings:              # each filing aligns to the dipole sum
				var a1: float = (f - pp).angle()
				var a2: float = (qq - f).angle()
				var a := atan2(sin(a1) + sin(a2), cos(a1) + cos(a2))
				var L := 2.6 + pv * 1.4
				n.draw_line(o + f - Vector2(cos(a), sin(a)) * L, o + f + Vector2(cos(a), sin(a)) * L,
					Color(0.78, 0.8, 0.84, 0.5 + pv * 0.4), 1.0)
			ElemKit.label(n, r, "POLARITY", Color(0.87, 0.9, 0.93))
