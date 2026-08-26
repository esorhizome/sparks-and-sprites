extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
## ICE & FROST — eight buttons, ported from the web bestiary.

const TITLE := "Ice & frost"
const BLURB := "crystals, snow, auroras, and the patience of glaciers"
const DEFS := [
	{ "id": "frostbite", "name": "Frostbite", "hint": "frost fingers creep in from the border; press to shatter them" },
	{ "id": "snowdrift", "name": "Snowdrift", "hint": "snow settles on the top edge; press to shake it off" },
	{ "id": "ice_cracks", "name": "Ice cracks", "hint": "clear ice, quiet glints; press and cracks race out, then refreeze" },
	{ "id": "glacier", "name": "Glacier", "hint": "the shelf calves small bergs; press for a big one" },
	{ "id": "aurora", "name": "Aurora", "hint": "curtains of light ripple overhead; press to set the sky alight" },
	{ "id": "hailstorm", "name": "Hailstorm", "hint": "hail bounces off the button; press for a violent burst" },
	{ "id": "frozen_core", "name": "Frozen core", "hint": "a cold heart pulses inside; press for a ring of frost spikes" },
	{ "id": "blizzard", "name": "Blizzard", "hint": "sideways snow, shivering caption; press for a whiteout" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	var r: Rect2 = b.rect
	match b.id:
		"frostbite":
			b.fingers = []
			for i in 12:
				var on_top := randf() < 0.5
				var x := randf_range(4, r.size.x - 4)
				var y := 0.0 if on_top else r.size.y
				var dir := 1.0 if on_top else -1.0
				var pts := [Vector2(x, y)]
				for s in 4:
					x += randf_range(-6, 6)
					y += dir * randf_range(3, 7)
					pts.append(Vector2(x, y))
				b.fingers.append({ "pts": pts, "ph": randf_range(0, 5) })
			b.grow = 0.4
		"snowdrift":
			b.flakes = []
			for i in 16:
				b.flakes.append({ "pos": Vector2(randf_range(-8, r.size.x + 8), randf_range(-30, r.size.y)),
					"v": randf_range(10, 24), "ph": randf_range(0, 9) })
			b.pile = []
			for i in 18:
				b.pile.append(0.0)
		"ice_cracks":
			b.cracks = []
			b.freeze = 0.0
		"glacier":
			b.timer = 3.0
		"blizzard":
			b.streaks = []
			for i in 22:
				b.streaks.append(Vector2(randf_range(-10, r.size.x + 10), randf_range(-16, r.size.y + 8)))
			b.white = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"frostbite":
			for f in b.fingers:
				b.parts.append({ "pos": f.pts[2], "vel": Vector2(randf_range(-50, 50), randf_range(-50, 50)), "life": 1.0 })
			b.grow = 0.0
		"snowdrift":
			b.press_v = 1.0
			for i in b.pile.size():
				if b.pile[i] > 0.5:
					b.parts.append({ "pos": Vector2((i + 0.5) * r.size.x / b.pile.size(), -b.pile[i]),
						"vel": Vector2(randf_range(-40, 40), randf_range(-60, -20)), "life": 1.0 })
				b.pile[i] = 0.0
		"ice_cracks":
			var c := Vector2(clampf(pos.x, 4, r.size.x - 4), clampf(pos.y, 4, r.size.y - 4))
			b.cracks = []
			for i in 7:
				var th := randf_range(0, TAU)
				var pts := [c]
				var p := c
				var a := th
				for s in 5:
					a += randf_range(-0.5, 0.5)
					p += Vector2(cos(a) * randf_range(6, 14), sin(a) * randf_range(4, 9))
					pts.append(p)
				b.cracks.append(pts)
			b.freeze = 1.0
		"glacier":
			_calve(b, 3)
		"aurora", "frozen_core":
			b.press_v = 1.0
		"hailstorm":
			b.press_v = 1.0
			for i in 12:
				_hail(b)
		"blizzard":
			b.white = 1.0

static func _calve(b: Dictionary, count: int) -> void:
	var r: Rect2 = b.rect
	for i in count:
		b.parts.append({ "kind": "berg", "pos": Vector2(r.size.x - 4, randf_range(4, r.size.y - 6)),
			"vel": Vector2(randf_range(14, 30), randf_range(4, 14)), "rot": 0.0,
			"vr": randf_range(-1.5, 1.5), "r": randf_range(3, 7), "life": 1.0 })
	for i in 5 * count:
		b.parts.append({ "kind": "splash", "pos": Vector2(r.size.x + randf_range(0, 8), r.size.y - 4),
			"vel": Vector2(randf_range(0, 40), randf_range(-40, -8)), "life": 1.0 })

static func _hail(b: Dictionary) -> void:
	var r: Rect2 = b.rect
	b.parts.append({ "kind": "hail", "pos": Vector2(randf_range(-10, r.size.x + 10), -20.0),
		"vel": Vector2(randf_range(-8, 8), randf_range(80, 140)), "r": randf_range(1.5, 3.0) })

static func tick(b: Dictionary, dt: float, t: float) -> void:
	b.press_v = maxf(0.0, b.press_v - dt * (0.7 if b.id == "aurora" else 2.0))
	var r: Rect2 = b.rect
	match b.id:
		"frostbite":
			b.grow = minf(1.0, b.grow + dt * 0.12)
			for p in b.parts:
				p.pos += p.vel * dt
				p.life -= dt * 1.8
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"snowdrift":
			for f in b.flakes:
				f.pos.y += f.v * dt
				f.pos.x += sin(t + f.ph) * 8.0 * dt
				if f.pos.y > -1.0 and f.pos.y < 6.0 and f.pos.x > 0.0 and f.pos.x < r.size.x:
					var c := int(f.pos.x / r.size.x * b.pile.size())
					if c >= 0 and c < b.pile.size():
						b.pile[c] = minf(9.0, b.pile[c] + 0.8)
					f.pos = Vector2(randf_range(0, r.size.x), randf_range(-30, -4))
				if f.pos.y > r.size.y + 20.0:
					f.pos = Vector2(randf_range(0, r.size.x), randf_range(-30, -4))
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += 120.0 * dt
				p.life -= dt * 1.2
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"ice_cracks":
			b.freeze = maxf(0.0, b.freeze - dt * 0.45)
		"glacier":
			b.timer -= dt
			if b.timer <= 0.0:
				_calve(b, 1)
				b.timer = randf_range(2.5, 5.0)
			for p in b.parts:
				p.pos += p.vel * dt
				if p.kind == "berg":
					p.rot += p.vr * dt
					p.life -= dt * 0.4
				else:
					p.vel.y += 110.0 * dt
					p.life -= dt * 1.6
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"hailstorm":
			if randf() < 0.1:
				_hail(b)
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += 60.0 * dt
				# bounce off the button's top edge
				if p.vel.y > 0.0 and p.pos.y > -p.r and p.pos.y < 6.0 and p.pos.x > 0.0 and p.pos.x < r.size.x:
					p.vel.y = -p.vel.y * randf_range(0.35, 0.55)
					p.vel.x += randf_range(-20, 20)
			b.parts = b.parts.filter(func(p): return p.pos.y < r.size.y + 40.0)
		"blizzard":
			var gust := 0.6 + 0.4 * sin(t * 0.9)
			for i in b.streaks.size():   # Vector2 loop vars are copies — write back by index
				var s: Vector2 = b.streaks[i]
				s.x -= randf_range(90, 190) * gust * dt
				if s.x < -12.0:
					s = Vector2(r.size.x + 12, randf_range(-16, r.size.y + 8))
				b.streaks[i] = s
			b.white = maxf(0.0, b.white - dt * 1.1)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	match b.id:
		"frostbite":
			ElemKit.face(n, r, Color(0.055, 0.086, 0.133, 0.96), Color(0.67, 0.86, 0.98, 0.6))
			ElemKit.label(n, r, "FROST", Color(0.89, 0.95, 1.0))
			for f in b.fingers:
				var pts: Array = f.pts
				var count: int = clampi(1 + int(b.grow * (pts.size() - 1) + sin(t + f.ph) * 0.4), 1, pts.size() - 1)
				for i in range(1, count + 1):
					n.draw_line(o + pts[i - 1], o + pts[i], Color(0.78, 0.92, 1.0, 0.75), 1.0)
					if i > 1:
						n.draw_line(o + pts[i], o + pts[i] + Vector2(randf_range(-3, 3), randf_range(-3, 3)),
							Color(0.78, 0.92, 1.0, 0.4), 1.0)
			for p in b.parts:
				n.draw_rect(Rect2(o + p.pos, Vector2(2, 2)), Color(0.82, 0.94, 1.0, p.life))
		"snowdrift":
			var jx: float = randf_range(-2, 2) * pv
			var rr := Rect2(r.position + Vector2(jx, 0), r.size)
			ElemKit.face(n, rr, Color(0.07, 0.094, 0.15, 0.96), Color(0.75, 0.86, 0.98, 0.55))
			ElemKit.label(n, rr, "SNOW DAY", Color(0.92, 0.96, 1.0))
			var poly := PackedVector2Array()
			poly.append(o + Vector2(jx, 0))
			for i in b.pile.size():
				poly.append(o + Vector2(jx + (i + 0.5) * r.size.x / b.pile.size(), -b.pile[i]))
			poly.append(o + Vector2(jx + r.size.x, 0))
			n.draw_colored_polygon(poly, Color(0.94, 0.97, 1.0, 0.95))
			for f in b.flakes:
				n.draw_circle(o + f.pos, 1.4, Color(0.92, 0.96, 1.0, 0.8))
			for p in b.parts:
				n.draw_rect(Rect2(o + p.pos, Vector2(2, 2)), Color(0.94, 0.97, 1.0, p.life))
		"ice_cracks":
			ElemKit.face(n, r, Color(0.55, 0.75, 0.92, 0.3), Color(0.78, 0.92, 1.0, 0.7))
			ElemKit.label(n, r, "THIN ICE", Color(0.078, 0.157, 0.235, 0.85))
			if randf() < 0.02:
				var g := o + Vector2(randf_range(8, r.size.x - 8), randf_range(6, r.size.y - 6))
				n.draw_line(g + Vector2(-4, 3), g + Vector2(4, -3), Color(1, 1, 1, 0.5), 1.0)
			if b.freeze > 0.0:
				var reveal: float = minf(1.0, (1.0 - b.freeze) * 6.0)
				for pts in b.cracks:
					var cnt: int = clampi(int(ceil(reveal * pts.size())), 2, pts.size())
					for i in range(1, cnt):
						n.draw_line(o + pts[i - 1], o + pts[i], Color(0.92, 0.97, 1.0, b.freeze * 0.95), 1.2)
		"glacier":
			ElemKit.face(n, r, Color(0.73, 0.85, 0.93), Color(0.9, 0.96, 1.0, 0.8))
			n.draw_rect(Rect2(o, Vector2(r.size.x, 8)), Color(0.91, 0.96, 0.99))
			ElemKit.label(n, r, "CALVE", Color(0.078, 0.176, 0.27, 0.85))
			for p in b.parts:
				if p.kind == "berg":
					n.draw_set_transform(o + p.pos, p.rot, Vector2.ONE)
					var poly := PackedVector2Array()
					for k in 5:
						var a := k / 5.0 * TAU
						poly.append(Vector2(cos(a), sin(a)) * p.r)
					n.draw_colored_polygon(poly, Color(0.8, 0.9, 0.97, p.life * 0.95))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				else:
					n.draw_rect(Rect2(o + p.pos, Vector2(1.6, 1.6)), Color(0.86, 0.94, 1.0, p.life))
		"aurora":
			ElemKit.face(n, r, Color(0.063, 0.078, 0.14, 0.95), Color(0.63, 0.9, 0.78, 0.55))
			ElemKit.label(n, r, "BOREALIS", Color(0.85, 0.96, 0.91))
			var hues := [0.42, 0.5, 0.78]
			for c in 3:
				var base_y := o.y - 10.0 - c * 5.0
				var x := 0.0
				while x < r.size.x:
					var sway: float = sin(x * 0.03 + t * (0.6 + c * 0.3) + c * 2) * 8.0
					var hgt: float = 12.0 + sin(x * 0.05 - t * (0.8 + pv * 2.0) + c) * 7.0 + pv * 12.0
					var a: float = maxf(0.0, 0.06 + 0.06 * sin(x * 0.02 + t + c * 3) + pv * 0.1)
					var col := Color.from_hsv(fmod(hues[c] + pv * 0.1 * sin(t * 3.0), 1.0), 0.85, 0.9, a)
					n.draw_line(o + Vector2(x + sway, base_y), o + Vector2(x + sway * 1.4, base_y - hgt), col, 3.0)
					x += 5.0
		"hailstorm":
			ElemKit.face(n, r, Color(0.086, 0.1, 0.157, 0.96 - pv * 0.2), Color(0.75, 0.84, 0.96, 0.5 + pv * 0.5))
			ElemKit.label(n, r, "HAIL", Color(0.9, 0.94, 0.98))
			for p in b.parts:
				n.draw_circle(o + p.pos, p.r, Color(0.88, 0.94, 1.0, 0.9))
		"frozen_core":
			ElemKit.face(n, r, Color(0.078, 0.118, 0.19, 0.75), Color(0.67, 0.84, 0.98, 0.6))
			var pulse := 0.5 + 0.5 * sin(t * 1.4)
			ElemKit.glow(n, r.get_center(), r.size.y * (0.55 + pulse * 0.3) + pv * 12.0,
				Color(0.75, 0.92, 1.0, 0.35 + pulse * 0.25 + pv * 0.4), 4)
			if pv > 0.0:
				for i in 10:
					var th := i / 10.0 * TAU
					var dir := Vector2(cos(th) * 1.5, sin(th) * 0.8)
					n.draw_line(r.get_center() + dir * (14.0 + (1.0 - pv) * 30.0),
						r.get_center() + dir * (24.0 + (1.0 - pv) * 30.0), Color(0.86, 0.96, 1.0, pv), 1.6)
			ElemKit.label(n, r, "CRYO", Color(0.87, 0.95, 1.0))
		"blizzard":
			ElemKit.face(n, r, Color(0.078, 0.094, 0.15, 0.96), Color(0.78, 0.86, 0.96, 0.5))
			var shiver := Rect2(r.position + Vector2(randf_range(-0.8, 0.8), randf_range(-0.8, 0.8)), r.size)
			ElemKit.label(n, shiver, "BRRR", Color(0.94, 0.96, 1.0))
			var gust := 0.6 + 0.4 * sin(t * 0.9)
			for s in b.streaks:
				n.draw_line(o + s, o + s + Vector2(9, -2), Color(0.92, 0.96, 1.0, 0.5 * gust), 1.2)
			if b.white > 0.0:
				ElemKit.face(n, r.grow(4.0), Color(0.94, 0.96, 0.99, minf(0.95, b.white * 1.2)))
