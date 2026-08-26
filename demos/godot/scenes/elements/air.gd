extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
## AIR & WIND — eight buttons, ported from the web bestiary.

const TITLE := "Air & wind"
const BLURB := "gusts, vortices, smoke, and fog with opinions"
const DEFS := [
	{ "id": "zephyr", "name": "Zephyr", "hint": "breeze lines curve around the button; press for a gust" },
	{ "id": "cyclone", "name": "Cyclone", "hint": "a pet tornado wanders beside the button; press to feed it" },
	{ "id": "smoke_signal", "name": "Smoke signal", "hint": "one puff at a time drifts up; press to send three fast" },
	{ "id": "fog_bank", "name": "Fog bank", "hint": "fog drifts across and hides the caption; press to part it" },
	{ "id": "updraft", "name": "Updraft", "hint": "leaves ride a thermal past the button; press for a flurry" },
	{ "id": "vacuum", "name": "Vacuum", "hint": "dust drifts inward forever; press to slam the airlock" },
	{ "id": "sonic_boom", "name": "Sonic boom", "hint": "speed lines shiver behind it; press to break the barrier" },
	{ "id": "windsock", "name": "Windsock", "hint": "a ribbon streams from the corner; press to spike the wind" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	var r: Rect2 = b.rect
	match b.id:
		"zephyr":
			b.winds = []
			for i in 7:
				b.winds.append({ "p": randf(), "lane": randf_range(-1, 1), "v": randf_range(0.2, 0.4) })
		"smoke_signal":
			b.timer = 1.0
			b.queue = 0
			b.q_timer = 0.0
		"fog_bank":
			b.blobs = []
			for i in 6:
				b.blobs.append({ "ox": randf_range(-r.size.x, r.size.x), "oy": randf_range(-10, 10),
					"r": randf_range(12, 22), "v": randf_range(6, 14) })
		"vacuum":
			b.motes = []
			for i in 22:
				b.motes.append({ "pos": Vector2(randf_range(-20, r.size.x + 20), randf_range(-20, r.size.y + 20)) })
			b.ring = 0.0
		"windsock":
			b.pts = []
			for i in 11:
				b.pts.append(r.size + Vector2(-2, -r.size.y + 8))
			b.wind = 1.0

static func press(b: Dictionary, _pos: Vector2) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"zephyr", "fog_bank", "sonic_boom":
			b.press_v = 1.0
		"cyclone":
			b.press_v = 1.0
			for i in 10:
				b.parts.append({ "a": randf_range(0, TAU), "h": randf(), "va": randf_range(3, 7), "life": 1.0 })
		"smoke_signal":
			b.queue = 3
			b.q_timer = 0.0
		"updraft":
			for i in 10:
				_leaf(b, true)
		"vacuum":
			b.press_v = 1.0
			b.ring = b.rect.size.x * 0.6
		"windsock":
			b.wind = 3.5

static func _leaf(b: Dictionary, burst: bool) -> void:
	var r: Rect2 = b.rect
	b.parts.append({ "pos": Vector2(randf_range(-16, r.size.x + 16), r.size.y + 20.0),
		"v": randf_range(26, 50) * (1.8 if burst else 1.0), "ph": randf_range(0, 9),
		"rot": randf_range(0, 6), "vr": randf_range(-4, 4), "green": randf() < 0.5 })

static func tick(b: Dictionary, dt: float, t: float) -> void:
	b.press_v = maxf(0.0, b.press_v - dt * (0.5 if b.id in ["fog_bank", "cyclone"] else 1.3))
	var r: Rect2 = b.rect
	match b.id:
		"zephyr":
			for w in b.winds:
				w.p += w.v * (1.0 + b.press_v * 3.0) * dt
				if w.p > 1.15:
					w.p = -0.15
					w.lane = randf_range(-1, 1)
		"cyclone":
			for p in b.parts:
				p.a += p.va * dt
				p.h += dt * 0.5
				p.life -= dt * 0.7
			b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.h <= 1.0)
		"smoke_signal":
			b.timer -= dt
			if b.timer <= 0.0:
				b.parts.append({ "pos": Vector2(r.size.x / 2.0 + randf_range(-4, 4), -2.0), "r": 4.0, "life": 1.0 })
				b.timer = randf_range(1.8, 2.6)
			if b.queue > 0:
				b.q_timer -= dt
				if b.q_timer <= 0.0:
					b.parts.append({ "pos": Vector2(r.size.x / 2.0 + randf_range(-4, 4), -2.0), "r": 4.0, "life": 1.0 })
					b.queue -= 1
					b.q_timer = 0.22
			for p in b.parts:
				p.pos.y -= 22.0 * dt
				p.pos.x += sin(p.pos.y * 0.15) * 6.0 * dt
				p.r += 7.0 * dt
				p.life -= dt * 0.55
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"fog_bank":
			for bl in b.blobs:
				bl.ox += bl.v * dt
				if bl.ox > r.size.x:
					bl.ox = -r.size.x
		"updraft":
			if randf() < 0.05:
				_leaf(b, false)
			for p in b.parts:
				p.pos.y -= p.v * dt
				p.pos.x += sin(t * 2.0 + p.ph) * 16.0 * dt
				p.rot += p.vr * dt
			b.parts = b.parts.filter(func(p): return p.pos.y > -24.0)
		"vacuum":
			var pull: float = 12.0 + b.press_v * 260.0
			for m in b.motes:
				var d: Vector2 = r.size / 2.0 - m.pos
				var dist := maxf(4.0, d.length())
				m.pos += d / dist * pull * dt
				if dist < 10.0:
					var th := randf_range(0, TAU)
					m.pos = r.size / 2.0 + Vector2(cos(th), sin(th)) * r.size.x * 0.7
			if b.press_v > 0.0:
				b.ring = maxf(0.0, b.ring - 300.0 * dt)
		"windsock":
			b.wind += (1.0 - b.wind) * dt * 0.8
			var pts: Array = b.pts
			pts[0] = Vector2(r.size.x - 2, 8)
			for i in range(1, pts.size()):
				var target: Vector2 = pts[i - 1] + Vector2(6.0 * b.wind,
					sin(t * (6.0 + b.wind * 2.0) + i * 0.9) * (2.2 + b.wind))
				pts[i] = (pts[i] as Vector2).lerp(target, minf(1.0, dt * 14.0))

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	match b.id:
		"zephyr":
			ElemKit.face(n, r, Color(0.078, 0.1, 0.133, 0.92), Color(0.67, 0.82, 0.9, 0.5))
			ElemKit.label(n, r, "BREEZE", Color(0.87, 0.94, 0.97))
			for w in b.winds:
				var x: float = r.size.x * w.p
				var dodge: float = exp(-pow((x - r.size.x / 2.0) / (r.size.x * 0.45), 2.0))
				var sign_l: float = 1.0 if w.lane >= 0.0 else -1.0
				var y: float = r.size.y / 2.0 + w.lane * r.size.y * 0.35 + dodge * r.size.y * 0.75 * sign_l
				ElemKit.qcurve(n, o + Vector2(x - 14.0 - pv * 10.0, y + 2), o + Vector2(x - 6, y - 1),
					o + Vector2(x, y), Color(0.75, 0.88, 0.96, 0.3 + pv * 0.4), 1.2)
		"cyclone":
			ElemKit.face(n, r, Color(0.078, 0.094, 0.125, 0.92), Color(0.7, 0.78, 0.86, 0.5))
			ElemKit.label(n, r, "TWISTER", Color(0.89, 0.92, 0.95))
			var cx := o.x + r.size.x / 2.0 + sin(t * 0.5) * r.size.x * 0.55
			var base_y := o.y + r.size.y + 6.0
			var top_y := o.y - 14.0 - pv * 8.0
			var size_m := 1.0 + pv * 0.8
			for i in 9:
				var k := i / 8.0
				var y := base_y + (top_y - base_y) * k
				var rad := (2.0 + k * 12.0) * size_m
				var a := t * (6.0 - k * 2.0) + i
				ElemKit.ellipse(n, Vector2(cx + sin(t * 2.0 + k * 3.0) * 3.0, y), rad, rad * 0.3,
					Color(0.78, 0.84, 0.9, 0.5 - k * 0.25 + pv * 0.3), 1.4, a, a + 4.0, 10)
			for p in b.parts:
				var y: float = base_y + (top_y - base_y) * p.h
				var rad: float = (2.0 + p.h * 12.0) * size_m
				n.draw_rect(Rect2(Vector2(cx + cos(p.a) * rad, y + sin(p.a) * rad * 0.3), Vector2(2, 2)),
					Color(0.75, 0.71, 0.63, p.life * 0.8))
		"smoke_signal":
			ElemKit.face(n, r, Color(0.094, 0.078, 0.1, 0.92), Color(0.78, 0.75, 0.78, 0.5))
			ElemKit.label(n, r, "SIGNAL", Color(0.91, 0.89, 0.91))
			for p in b.parts:
				n.draw_circle(o + p.pos, p.r, Color(0.78, 0.76, 0.8, 0.3 * p.life))
		"fog_bank":
			ElemKit.face(n, r, Color(0.086, 0.094, 0.125, 0.92), Color(0.75, 0.78, 0.84, 0.5))
			ElemKit.label(n, r, "PEA SOUP", Color(0.89, 0.91, 0.93))
			for bl in b.blobs:
				var push: float = pv * 30.0 * (1.0 if bl.ox >= 0.0 else -1.0)
				var x: float = r.get_center().x + bl.ox * 0.6 + push
				ElemKit.glow(n, Vector2(x, r.get_center().y + bl.oy), bl.r,
					Color(0.82, 0.84, 0.88, 0.16 * (1.0 - pv * 0.8)), 3)
		"updraft":
			ElemKit.face(n, r, Color(0.07, 0.1, 0.078, 0.92), Color(0.67, 0.82, 0.59, 0.5))
			ElemKit.label(n, r, "THERMAL", Color(0.89, 0.94, 0.85))
			for p in b.parts:
				n.draw_set_transform(o + p.pos, p.rot, Vector2(1.0, 0.47))
				n.draw_circle(Vector2.ZERO, 3.4, Color(0.59, 0.75, 0.35, 0.85) if p.green else Color(0.82, 0.63, 0.27, 0.85))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"vacuum":
			ElemKit.face(n, r, Color(0.07, 0.078, 0.11, 0.96), Color(0.63, 0.7, 0.82, 0.5))
			ElemKit.label(n, r, "INHALE", Color(0.86, 0.9, 0.95))
			for m in b.motes:
				n.draw_rect(Rect2(o + m.pos, Vector2(1.5, 1.5)), Color(0.7, 0.76, 0.84, 0.3 + pv * 0.5))
			if pv > 0.0:
				ElemKit.ellipse(n, r.get_center(), b.ring * 1.4, b.ring * 0.8,
					Color(0.75, 0.82, 0.92, pv * 0.6), 1.5)
		"sonic_boom":
			for i in 6:                      # trailing speed lines
				var y := o.y + (i + 0.5) * r.size.y / 6.0
				var len := 10.0 + sin(t * 9.0 + i * 2.0) * 4.0 + pv * 26.0
				n.draw_line(Vector2(o.x - 4, y), Vector2(o.x - 4 - len, y),
					Color(0.7, 0.78, 0.88, 0.25 + pv * 0.5), 1.2)
			var lean := 1.5 + pv * 4.0
			var rr := Rect2(r.position + Vector2(lean, 0), r.size)
			ElemKit.face(n, rr, Color(0.078, 0.086, 0.125, 0.96), Color(0.75, 0.82, 0.92, 0.6))
			ElemKit.label(n, rr, "MACH 1", Color(0.89, 0.93, 0.96))
			if pv > 0.0:                     # the cone: flattened arcs bursting back
				var k := 1.0 - pv
				for ring in 3:
					var rad := 10.0 + k * 70.0 + ring * 12.0
					ElemKit.ellipse(n, Vector2(o.x + r.size.x + 6, r.get_center().y), rad * 0.5, rad,
						Color(0.86, 0.92, 1.0, pv * 0.8), 2.0, -1.2, 1.2, 14)
		"windsock":
			ElemKit.face(n, r, Color(0.078, 0.094, 0.118, 0.92), Color(0.75, 0.8, 0.88, 0.5))
			ElemKit.label(n, r, "GALE", Color(0.89, 0.92, 0.96))
			var poly := PackedVector2Array()
			for p in b.pts:
				poly.append(o + p)
			n.draw_polyline(poly, Color(1, 0.59, 0.35, 0.9), 3.0)
