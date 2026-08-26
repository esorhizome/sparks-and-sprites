extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
## WATER — ten buttons, ported from the web bestiary.

const TITLE := "Water"
const BLURB := "bubbles, ripples, rain, and everything that sloshes"
const DEFS := [
	{ "id": "bubble_tank", "name": "Bubble tank", "hint": "bubbles wobble upward inside; press to pop them all" },
	{ "id": "fizz", "name": "Fizz", "hint": "champagne streams of micro-bubbles; press to overflow with foam" },
	{ "id": "ripple_pool", "name": "Ripple pool", "hint": "the face is still water; press to drop a stone in" },
	{ "id": "rain_glass", "name": "Rain on glass", "hint": "droplets bead and run; press to sweep the wiper" },
	{ "id": "waterline", "name": "Waterline", "hint": "half-full of sloshing liquid; press to slosh it hard" },
	{ "id": "whirlpool", "name": "Whirlpool", "hint": "a slow spiral current; press to tighten the drain" },
	{ "id": "spring_tide", "name": "Spring tide", "hint": "waves lap below; press and one crashes right over" },
	{ "id": "deep_sea", "name": "Deep sea", "hint": "marine snow drifts past a jellyfish; press for a biolume flash" },
	{ "id": "waterfall", "name": "Waterfall", "hint": "a sheet of water pours down the face; press to splash the base" },
	{ "id": "squirt", "name": "Squirt", "hint": "a drip forms at the corner; press to fire the water jet" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	var r: Rect2 = b.rect
	match b.id:
		"bubble_tank":
			for i in 9:
				b.parts.append({ "kind": "bub", "pos": Vector2(randf_range(8, r.size.x - 8), randf_range(8, r.size.y - 4)),
					"r": randf_range(2, 6), "ph": randf_range(0, 9) })
		"fizz":
			b.jets = [r.size.x * 0.18, r.size.x * 0.39, r.size.x * 0.6, r.size.x * 0.81]
		"waterline":
			b.tilt = 0.0
			b.tilt_v = 0.0
		"whirlpool":
			b.motes = []
			for i in 22:
				b.motes.append({ "a": randf_range(0, TAU), "r": randf_range(10, r.size.x * 0.6),
					"v": randf_range(0.5, 1.2), "prev": Vector2.ZERO })
			b.spin = 1.0
		"deep_sea":
			b.snow = []
			for i in 16:
				b.snow.append({ "pos": Vector2(randf_range(0, r.size.x), randf_range(0, r.size.y)), "v": randf_range(3, 9) })
		"rain_glass":
			for i in 14:
				b.parts.append({ "kind": "drop", "pos": Vector2(randf_range(4, r.size.x - 4), randf_range(4, r.size.y - 4)),
					"r": randf_range(1, 3), "run": 0.0 })
			b.wiper = -1.0
		"squirt":
			b.drip = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"bubble_tank":
			for p in b.parts.duplicate():
				if p.kind == "bub":
					b.parts.append({ "kind": "pop", "pos": p.pos, "r": p.r, "life": 1.0 })
			b.parts = b.parts.filter(func(p): return p.kind != "bub")
		"fizz":
			for i in 22:
				b.parts.append({ "kind": "foam", "pos": Vector2(randf_range(0, r.size.x), randf_range(-2, 4)),
					"vel": Vector2(randf_range(-24, 24), randf_range(-50, -10)), "r": randf_range(2, 4.5), "life": 1.0 })
		"ripple_pool":
			b.parts.append({ "kind": "ring", "pos": Vector2(clampf(pos.x, 4, r.size.x - 4), clampf(pos.y, 4, r.size.y - 4)),
				"r": 2.0, "life": 1.0, "big": true })
		"rain_glass":
			b.wiper = 0.0
		"waterline":
			b.tilt_v += randf_range(1.2, 2.0) * (-1.0 if randf() < 0.5 else 1.0)
		"whirlpool":
			b.spin = 3.2
		"spring_tide":
			b.press_v = 1.0
			for i in 12:
				b.parts.append({ "kind": "foam", "pos": Vector2(randf_range(0, r.size.x), randf_range(-6, 10)),
					"vel": Vector2(randf_range(-30, 30), randf_range(-70, -20)), "r": 1.8, "life": 1.0 })
		"deep_sea":
			b.press_v = 1.0
		"waterfall":
			for i in 14:
				b.parts.append({ "kind": "splash", "pos": Vector2(randf_range(0, r.size.x), r.size.y),
					"vel": Vector2(randf_range(-50, 50), randf_range(-90, -30)), "life": 1.0 })
		"squirt":
			for i in 16:
				b.parts.append({ "kind": "jet", "pos": Vector2(4, r.size.y - 4),
					"vel": Vector2(randf_range(120, 190), randf_range(-160, -110)), "life": 1.0 })
			b.drip = 0.0

static func tick(b: Dictionary, dt: float, t: float) -> void:
	b.press_v = maxf(0.0, b.press_v - dt * (0.7 if b.id == "spring_tide" else 1.2))
	var r: Rect2 = b.rect
	match b.id:
		"bubble_tank":
			var bubs := 0
			for p in b.parts:
				if p.kind == "bub":
					bubs += 1
					p.pos.y -= (8.0 + p.r * 2.0) * dt
					if p.pos.y < p.r + 2.0:
						p.kind = "pop"
						p.life = 1.0
				else:
					p.life -= dt * 3.0
					p.r += 14.0 * dt
			if bubs < 9 and randf() < 0.15:
				b.parts.append({ "kind": "bub", "pos": Vector2(randf_range(8, r.size.x - 8), r.size.y - 4.0),
					"r": randf_range(2, 6), "ph": randf_range(0, 9) })
			b.parts = b.parts.filter(func(p): return p.kind == "bub" or p.life > 0.0)
		"fizz":
			for jx in b.jets:
				if randf() < 0.7:
					b.parts.append({ "kind": "fizz", "pos": Vector2(jx + randf_range(-2, 2), r.size.y - 3.0), "life": 1.0 })
			for p in b.parts:
				if p.kind == "fizz":
					p.pos.y -= 55.0 * dt
					p.pos.x += sin(p.pos.y * 0.4) * 6.0 * dt
					p.life -= dt * 0.8
				else:
					p.pos += p.vel * dt
					p.vel.y += 30.0 * dt
					p.life -= dt * 0.9
			b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.pos.y > -6.0)
		"ripple_pool":
			if randf() < 0.012:
				b.parts.append({ "kind": "ring", "pos": Vector2(randf_range(10, r.size.x - 10), randf_range(8, r.size.y - 8)),
					"r": 1.0, "life": 0.6, "big": false })
			for p in b.parts:
				p.r += (40.0 if p.big else 16.0) * dt
				p.life -= dt * (0.8 if p.big else 0.5)
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"rain_glass":
			if b.parts.size() < 18 and randf() < 0.2:
				b.parts.append({ "kind": "drop", "pos": Vector2(randf_range(4, r.size.x - 4), randf_range(4, r.size.y - 4)),
					"r": randf_range(1, 3), "run": 0.0 })
			for p in b.parts:
				if p.run <= 0.0 and randf() < 0.005:
					p.run = randf_range(0.5, 1.2)
				if p.run > 0.0:
					p.run -= dt
					p.pos.y += 30.0 * dt
					p.pos.x += sin(p.pos.y * 0.5) * 4.0 * dt
			if b.wiper >= 0.0:
				b.wiper += dt * 2.2
				var wx: float = r.size.x * (b.wiper / 1.1)
				b.parts = b.parts.filter(func(p): return absf(p.pos.x - wx) > 10.0)
				if b.wiper > 1.2:
					b.wiper = -1.0
			b.parts = b.parts.filter(func(p): return p.pos.y < r.size.y + 4.0)
		"waterline":
			b.tilt_v += -b.tilt * 26.0 * dt
			b.tilt_v *= pow(0.3, dt)
			b.tilt += b.tilt_v * dt
		"whirlpool":
			b.spin += (1.0 - b.spin) * dt * 0.8
			for m in b.motes:
				m.prev = Vector2(cos(m.a) * m.r, sin(m.a) * m.r * 0.55)
				m.a += m.v * b.spin * dt
				m.r -= 3.5 * b.spin * dt
				if m.r < 6.0:
					m.r = r.size.x * randf_range(0.5, 0.65)
					m.a = randf_range(0, TAU)
					m.prev = Vector2(cos(m.a) * m.r, sin(m.a) * m.r * 0.55)
		"spring_tide", "waterfall", "squirt", "fizz2":
			pass
	# shared free-flying particle integration for the throwers
	if b.id in ["spring_tide", "waterfall", "squirt"]:
		for p in b.parts:
			p.pos += p.vel * dt
			p.vel.y += (90.0 if b.id == "spring_tide" else 180.0) * dt
			p.life -= dt * (1.1 if b.id == "spring_tide" else 1.2)
		b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.pos.y < r.size.y + 40.0)
	if b.id == "waterfall" and randf() < 0.8:
		b.parts.append({ "kind": "streak", "pos": Vector2(randf_range(3, r.size.x - 3), -4.0),
			"vel": Vector2(0, randf_range(90, 150)), "life": 0.9 })
	if b.id == "squirt":
		b.drip += dt * 0.8
		if b.drip > 2.6:
			b.parts.append({ "kind": "jet", "pos": Vector2(4, r.size.y - 2), "vel": Vector2(randf_range(-5, 5), 30), "life": 1.4 })
			b.drip = 0.0
	if b.id == "deep_sea":
		for s in b.snow:
			s.pos.y += s.v * dt
			s.pos.x += sin(t + s.pos.y * 0.05) * 2.0 * dt
			if s.pos.y > r.size.y:
				s.pos = Vector2(randf_range(0, r.size.x), -2.0)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	match b.id:
		"bubble_tank":
			ElemKit.face(n, r, Color(0.04, 0.1, 0.157, 0.96), Color(0.43, 0.75, 0.9, 0.5))
			for p in b.parts:
				var pos: Vector2 = o + p.pos + Vector2(sin(t * 2.0 + p.get("ph", 0.0)) * 3.0, 0)
				if p.kind == "bub":
					ElemKit.ellipse(n, pos, p.r, p.r, Color(0.67, 0.86, 0.98, 0.7), 1.0, 0, TAU, 14)
					n.draw_rect(Rect2(pos - Vector2(p.r * 0.4, p.r * 0.4), Vector2(1, 1)), Color(1, 1, 1, 0.8))
				else:
					for k in 4:
						ElemKit.ellipse(n, o + p.pos, p.r, p.r, Color(0.86, 0.96, 1.0, p.life), 1.0,
							k * 1.7, k * 1.7 + 0.9, 6)
			ElemKit.label(n, r, "AQUARIUM", Color(0.81, 0.94, 1.0))
		"fizz":
			ElemKit.face(n, r, Color(0.157, 0.118, 0.04, 0.92), Color(1, 0.86, 0.55, 0.5))
			for p in b.parts:
				if p.kind == "fizz":
					if p.pos.y > 2.0:
						n.draw_rect(Rect2(o + p.pos, Vector2(1.5, 1.5)), Color(1, 0.94, 0.75, 0.6 * p.life))
				else:
					n.draw_circle(o + p.pos, p.r, Color(1, 0.98, 0.92, 0.7 * p.life))
			ElemKit.label(n, r, "CHEERS", Color(1, 0.95, 0.81))
		"ripple_pool":
			ElemKit.face(n, r, Color(0.063, 0.18, 0.27), Color(0.55, 0.78, 0.9, 0.5))
			for p in b.parts:
				for k in 2:
					var rr := maxf(0.5, p.r - k * 6.0)
					ElemKit.ellipse(n, o + p.pos, rr, rr * 0.45, Color(0.75, 0.9, 0.98, p.life * 0.8),
						1.8 if p.big else 1.0)
			var wob: float = sin(t * 20.0) * 1.5 if b.parts.any(func(p): return p.big) else 0.0
			var lr := Rect2(r.position + Vector2(0, wob), r.size)
			ElemKit.label(n, lr, "POND", Color(0.85, 0.94, 0.99))
		"rain_glass":
			ElemKit.face(n, r, Color(0.063, 0.1, 0.15, 0.96), Color(0.59, 0.75, 0.86, 0.5))
			ElemKit.label(n, r, "DRIZZLE", Color(0.82, 0.9, 0.96, 0.85))
			for p in b.parts:
				var pos: Vector2 = o + p.pos
				if p.run > 0.0:
					n.draw_line(pos - Vector2(0, 6), pos, Color(0.63, 0.78, 0.9, 0.25), p.r)
				n.draw_circle(pos, p.r, Color(0.75, 0.86, 0.96, 0.6))
			if b.wiper >= 0.0:
				var wx: float = o.x + r.size.x * (b.wiper / 1.1)
				n.draw_line(Vector2(wx, o.y + r.size.y), Vector2(wx - 6, o.y), Color(0.78, 0.82, 0.88, 0.9), 3.0)
		"waterline":
			ElemKit.face(n, r, Color(0.055, 0.078, 0.118, 0.96), Color(0.47, 0.78, 0.86, 0.55))
			var lv := r.size.y * 0.45
			var poly := PackedVector2Array()
			poly.append(o + Vector2(0, r.size.y - 2))
			var x := 0.0
			while x <= r.size.x:
				var k := (x - r.size.x / 2.0) / r.size.x
				var y: float = lv + k * b.tilt * 60.0 + sin(x * 0.11 + t * 3.0) * 1.5 + sin(x * 0.23 - t * 5.0) * 0.8
				poly.append(o + Vector2(x, clampf(y, 4, r.size.y - 2)))
				x += 4.0
			poly.append(o + Vector2(r.size.x, r.size.y - 2))
			n.draw_colored_polygon(poly, Color(0.2, 0.6, 0.8, 0.75))
			ElemKit.label(n, r, "SLOSH", Color(0.87, 0.96, 1.0))
		"whirlpool":
			ElemKit.face(n, r, Color(0.04, 0.086, 0.133, 0.9), Color(0.51, 0.78, 0.9, 0.55))
			for m in b.motes:
				var cur := r.get_center() + Vector2(cos(m.a) * m.r, sin(m.a) * m.r * 0.55)
				n.draw_line(r.get_center() + m.prev, cur, Color(0.55, 0.82, 0.92, 0.6), 1.4)
			ElemKit.label(n, r, "DRAIN", Color(0.84, 0.93, 0.98))
		"spring_tide":
			ElemKit.face(n, r, Color(0.078, 0.07, 0.133, 0.92), Color(0.55, 0.78, 0.92, 0.5))
			ElemKit.label(n, r, "TIDE", Color(0.85, 0.94, 0.99))
			var base: float = r.size.y * 1.02 - sin(t * 0.5) * 4.0
			var lift: float = pv * (r.size.y + 16.0)
			for layer in 2:
				var poly := PackedVector2Array()
				poly.append(o + Vector2(-4, r.size.y + 8))
				var x := -4.0
				while x <= r.size.x + 4.0:
					poly.append(o + Vector2(x, base - lift - layer * 5.0 + sin(x * 0.05 + t * (2.0 + layer)) * 4.0))
					x += 5.0
				poly.append(o + Vector2(r.size.x + 4, r.size.y + 8))
				n.draw_colored_polygon(poly, Color(0.16, 0.47, 0.7, 0.45) if layer == 0 else Color(0.31, 0.7, 0.9, 0.5))
			for p in b.parts:
				n.draw_circle(o + p.pos, p.r, Color(0.92, 0.98, 1.0, 0.8 * p.life))
		"deep_sea":
			ElemKit.face(n, r, Color(0.031, 0.063, 0.118, 0.97), Color(0.47, 0.78, 1.0, 0.4 + pv * 0.6))
			for s in b.snow:
				n.draw_rect(Rect2(o + s.pos, Vector2(1.2, 1.2)), Color(0.7, 0.78, 0.86, 0.25 + pv * 0.5))
			var jx := o.x + r.size.x * 0.5 + sin(t * 0.4) * r.size.x * 0.3
			var jy := o.y + r.size.y * 0.3 + sin(t * 0.9) * 6.0
			ElemKit.glow(n, Vector2(jx, jy), 12.0 + pv * 8.0, Color(0.55, 0.9, 1.0, 0.5 + pv * 0.5), 3)
			for k in range(-2, 3):
				ElemKit.qcurve(n, Vector2(jx + k * 3, jy + 5),
					Vector2(jx + k * 5 + sin(t * 3.0 + k) * 4.0, jy + 13),
					Vector2(jx + k * 6 + sin(t * 2.0 + k * 2) * 6.0, jy + 20),
					Color(0.55, 0.86, 1.0, 0.35 + pv * 0.5), 1.0)
			ElemKit.label(n, r, "ABYSS", Color(0.78, 0.92, 1.0, 0.8 + pv * 0.2))
		"waterfall":
			ElemKit.face(n, r, Color(0.055, 0.094, 0.133, 0.96), Color(0.59, 0.82, 0.92, 0.5))
			for p in b.parts:
				var pos: Vector2 = o + p.pos
				if p.kind == "streak":
					if p.pos.y > 0 and p.pos.y < r.size.y:
						n.draw_line(pos - Vector2(0, 12), pos, Color(0.67, 0.86, 0.96, 0.5), 1.2)
				else:
					n.draw_rect(Rect2(pos, Vector2(1.8, 1.8)), Color(0.82, 0.94, 1.0, p.life))
			ElemKit.ellipse(n, Vector2(r.get_center().x, o.y + r.size.y + 4),
				r.size.x * 0.5 + sin(t * 2.0) * 4.0, 5.0, Color(0.63, 0.84, 0.94, 0.25), 1.0)
			ElemKit.label(n, r, "FALLS", Color(0.87, 0.95, 1.0))
		"squirt":
			ElemKit.face(n, r, Color(0.063, 0.086, 0.133, 0.96), Color(0.51, 0.78, 0.92, 0.5))
			ElemKit.label(n, r, "SQUIRT", Color(0.85, 0.94, 1.0))
			var dp := o + Vector2(4, r.size.y - 2 + b.drip)
			n.draw_set_transform(dp, 0.0, Vector2(1.0, 1.0 + b.drip * 0.4))
			n.draw_circle(Vector2.ZERO, 2.0 + b.drip * 0.8, Color(0.59, 0.82, 0.94, 0.85))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for p in b.parts:
				n.draw_circle(o + p.pos, 1.8, Color(0.67, 0.88, 0.98, minf(1.0, p.life)))
