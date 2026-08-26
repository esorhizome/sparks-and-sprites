extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
## LIGHTNING — eight buttons, ported from the web bestiary.

const TITLE := "Lightning"
const BLURB := "charge, arc, and the crack of discharge"
const DEFS := [
	{ "id": "static_charge", "name": "Static charge", "hint": "tiny crackles bite the edges; press for a bolt across the face" },
	{ "id": "tesla_ring", "name": "Tesla ring", "hint": "an arc dances between button and outer ring; press fires them all" },
	{ "id": "storm_cloud", "name": "Storm cloud", "hint": "a cloud broods overhead; press and it strikes the button" },
	{ "id": "circuit", "name": "Circuit trace", "hint": "pulses travel etched copper paths; press to send them all at once" },
	{ "id": "plasma_globe", "name": "Plasma globe", "hint": "filaments wander from the core; press and they chase your finger" },
	{ "id": "neon", "name": "Neon flicker", "hint": "a buzzing neon tube border; press to steady it for a moment" },
	{ "id": "emp", "name": "EMP", "hint": "shockwave rings pulse outward; press for the big one" },
	{ "id": "vandegraaff", "name": "Van de Graaff", "hint": "charged hairs wave off the top edge; press to discharge" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	var r: Rect2 = b.rect
	match b.id:
		"circuit":
			b.paths = []
			for p in 4:
				var pts := [Vector2(0, randf_range(6, r.size.y - 6))]
				var x := 0.0
				while x < r.size.x - 12.0:
					x += randf_range(16, 34)
					pts.append(Vector2(minf(x, r.size.x), pts[-1].y))
					if randf() < 0.7 and x < r.size.x - 12.0:
						pts.append(Vector2(minf(x, r.size.x), randf_range(6, r.size.y - 6)))
				var seg := [0.0]
				var total := 0.0
				for i in range(1, pts.size()):
					total += absf(pts[i].x - pts[i - 1].x) + absf(pts[i].y - pts[i - 1].y)
					seg.append(total)
				b.paths.append({ "pts": pts, "seg": seg, "len": total, "d": randf_range(0, total), "v": randf_range(30, 60) })
		"plasma_globe":
			b.fils = []
			for i in 6:
				b.fils.append({ "a": randf_range(0, TAU), "va": randf_range(-0.8, 0.8) })
			b.target = Vector2.ZERO
			b.hold = 0.0
		"neon":
			b.dropout = 0.0
			b.steady = 0.0
		"emp":
			b.timer = 1.0
		"vandegraaff":
			b.hairs = []
			var x := 8.0
			while x < r.size.x - 6.0:
				b.hairs.append({ "x": x, "len": randf_range(10, 20), "ph": randf_range(0, 9) })
				x += 9.0

static func press(b: Dictionary, pos: Vector2) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"static_charge":
			b.press_v = 1.0
			var pts := [Vector2(-4, r.size.y / 2.0)]
			var x := 0.0
			while x < r.size.x:
				x += randf_range(10, 20)
				pts.append(Vector2(x, r.size.y / 2.0 + randf_range(-14, 14)))
			b.bolt = { "pts": pts, "life": 1.0 }
		"tesla_ring", "storm_cloud", "neon", "vandegraaff":
			b.press_v = 1.0
			if b.id == "neon":
				b.steady = 2.0
				b.dropout = 0.0
		"circuit":
			b.press_v = 1.0
			for p in b.paths:
				p.d = 0.0
		"plasma_globe":
			b.target = pos
			b.hold = 0.9
		"emp":
			b.parts.append({ "kind": "ring", "r": 6.0, "v": 120.0, "life": 1.0, "big": true })
			for i in 10:
				var th := randf_range(0, TAU)
				b.parts.append({ "kind": "spark", "pos": r.size / 2.0,
					"vel": Vector2(cos(th), sin(th)) * randf_range(60, 150), "life": 1.0 })

static func tick(b: Dictionary, dt: float, t: float) -> void:
	b.press_v = maxf(0.0, b.press_v - dt * (2.5 if b.id == "vandegraaff" else 1.8))
	match b.id:
		"static_charge":
			if b.has("bolt") and b.bolt != null:
				b.bolt.life -= dt * 3.0
				if b.bolt.life <= 0.0:
					b.bolt = null
		"circuit":
			for p in b.paths:
				p.d += p.v * (1.0 + b.press_v * 3.0) * dt
				if p.d > p.len:
					p.d = 0.0
		"plasma_globe":
			b.hold = maxf(0.0, b.hold - dt)
			for f in b.fils:
				f.a += f.va * dt
		"neon":
			b.steady = maxf(0.0, b.steady - dt)
			if b.steady <= 0.0 and b.dropout <= 0.0 and randf() < 0.02:
				b.dropout = randf_range(0.04, 0.16)
			b.dropout = maxf(0.0, b.dropout - dt)
		"emp":
			b.timer -= dt
			if b.timer <= 0.0:
				b.parts.append({ "kind": "ring", "r": 6.0, "v": 60.0, "life": 1.0, "big": false })
				b.timer = 2.5
			for p in b.parts:
				if p.kind == "ring":
					p.r += p.v * dt
					p.life -= dt * (0.7 if p.big else 1.0)
				else:
					p.pos += p.vel * dt
					p.life -= dt * 1.8
			b.parts = b.parts.filter(func(p): return p.life > 0.0)

static func _path_point(p: Dictionary, d: float) -> Vector2:
	var pts: Array = p.pts
	var seg: Array = p.seg
	for i in range(1, pts.size()):
		if d <= seg[i]:
			var k: float = (d - seg[i - 1]) / maxf(0.000001, seg[i] - seg[i - 1])
			return pts[i - 1].lerp(pts[i], k)
	return pts[-1]

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	match b.id:
		"static_charge":
			ElemKit.face(n, r, Color(0.063, 0.07, 0.133, 0.95), Color(0.55, 0.67, 1.0, 0.4 + pv * 0.6))
			ElemKit.label(n, r, "CHARGE", Color(0.84, 0.88, 1.0))
			if randf() < 0.25:
				var side := randf() < 0.5
				var p := o + Vector2(randf_range(0, r.size.x), 0.0 if side else r.size.y)
				for k in 3:
					var q := p + Vector2(randf_range(-6, 6), randf_range(-6, 6))
					n.draw_line(p, q, Color(0.7, 0.82, 1.0, 0.9), 1.0)
					p = q
			if b.has("bolt") and b.bolt != null:
				var pts: Array = b.bolt.pts
				for i in range(pts.size() - 1):
					n.draw_line(o + pts[i] + Vector2(randf_range(-1, 1), 0), o + pts[i + 1],
						Color(0.86, 0.92, 1.0, b.bolt.life), 2.5)
		"tesla_ring":
			ElemKit.ellipse(n, r.get_center(), r.size.x * 0.68, r.size.y * 0.95, Color(0.47, 0.59, 0.9, 0.35), 1.0)
			ElemKit.face(n, r, Color(0.055, 0.063, 0.118, 0.95), Color(0.59, 0.7, 1.0, 0.6))
			ElemKit.label(n, r, "TESLA", Color(0.86, 0.9, 1.0))
			_tesla_arc(n, b, t * 1.6, 0.8)
			if randf() < 0.05:
				_tesla_arc(n, b, randf_range(0, TAU), 0.6)
			if pv > 0.0:
				for i in 8:
					_tesla_arc(n, b, i / 8.0 * TAU + t, pv)
		"storm_cloud":
			var cy := o.y - 16.0 + sin(t * 0.8) * 2.0
			var hit := pv > 0.55
			ElemKit.face(n, r, Color(0.47, 0.51, 0.7, 0.95) if hit else Color(0.078, 0.078, 0.14, 0.95),
				Color(0.59, 0.67, 1.0, 0.4 + pv * 0.6))
			ElemKit.label(n, r, "STORM", Color(0.06, 0.07, 0.16) if hit else Color(0.85, 0.87, 1.0))
			if randf() < 0.01:
				ElemKit.glow(n, Vector2(r.get_center().x + randf_range(-14, 14), cy), 14.0, Color(0.75, 0.78, 1.0, 0.45), 3)
			for i in 5:
				n.draw_circle(Vector2(r.get_center().x + (i - 2) * 13.0, cy + sin(i * 2.7) * 3.0),
					10.0 + (i % 2) * 3.0, Color(0.35, 0.37, 0.47))
			if hit:
				var p := Vector2(r.get_center().x, cy + 8.0)
				while p.y < o.y:
					var q := p + Vector2(randf_range(-8, 8), randf_range(5, 10))
					n.draw_line(p, q, Color(0.9, 0.94, 1.0, pv), 2.5)
					p = q
		"circuit":
			ElemKit.face(n, r, Color(0.055, 0.1, 0.086), Color(0.35, 0.86, 0.67, 0.4 + pv * 0.6))
			for p in b.paths:
				var pts: Array = p.pts
				var poly := PackedVector2Array()
				for q in pts:
					poly.append(o + q)
				n.draw_polyline(poly, Color(0.27, 0.63, 0.47, 0.35 + pv * 0.4), 1.0)
				var pos: Vector2 = o + _path_point(p, p.d)
				n.draw_rect(Rect2(pos - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.55, 1.0, 0.78, 0.9))
			ElemKit.label(n, r, "BOOT", Color(0.78, 0.96, 0.89))
		"plasma_globe":
			ElemKit.face(n, r, Color(0.078, 0.04, 0.118, 0.95), Color(0.86, 0.55, 1.0, 0.5))
			ElemKit.glow(n, r.get_center(), 14.0, Color(1, 0.75, 1.0, 0.7), 3)
			var chasing: bool = b.hold > 0.0
			for f in b.fils:
				var e: Vector2
				if chasing:
					e = o + b.target + Vector2(randf_range(-4, 4), randf_range(-4, 4))
				else:
					e = r.get_center() + Vector2(cos(f.a) * r.size.x * 0.48, sin(f.a) * r.size.y * 0.5)
				var p := r.get_center()
				for k in range(1, 6):
					var u := k / 5.0
					var q: Vector2 = r.get_center().lerp(e, u) + Vector2(randf_range(-4, 4), randf_range(-4, 4)) * sin(u * PI)
					n.draw_line(p, q, Color(0.92, 0.67, 1.0, 0.95 if chasing else 0.55), 1.2)
					p = q
			ElemKit.label(n, r, "PLASMA", Color(0.95, 0.85, 1.0))
		"neon":
			var buzz: float = 1.0 if b.steady > 0.0 else 0.82 + sin(t * 120.0) * 0.06
			var on: float = buzz if b.dropout <= 0.0 else 0.08
			ElemKit.ring_face(n, r.grow(2.0), Color(1, 0.31, 0.7, on * 0.25), 7)
			ElemKit.ring_face(n, r, Color(1, 0.67, 0.86, on), 2)
			ElemKit.label(n, r, "OPEN", Color(1, 0.75, 0.9, on))
		"emp":
			ElemKit.face(n, r, Color(0.047, 0.078, 0.1, 0.95), Color(0.47, 0.9, 1.0, 0.5))
			ElemKit.label(n, r, "PULSE", Color(0.81, 0.96, 1.0))
			for p in b.parts:
				if p.kind == "ring":
					var pts := PackedVector2Array()
					for i in 13:
						var th := i / 12.0 * TAU
						var j := sin(t * 40.0 + i * 7.0) * 2.0
						pts.append(r.get_center() + Vector2(cos(th) * (p.r + j) * 1.4, sin(th) * (p.r + j) * 0.75))
					n.draw_polyline(pts, Color(0.55, 0.92, 1.0, p.life * (0.95 if p.big else 0.5)), 2.5 if p.big else 1.2)
				else:
					n.draw_rect(Rect2(o + p.pos, Vector2(2, 2)), Color(0.7, 0.94, 1.0, p.life))
		"vandegraaff":
			ElemKit.face(n, r, Color(0.094, 0.078, 0.125, 0.95), Color(0.78, 0.75, 1.0, 0.5))
			ElemKit.label(n, r, "HAIR-RAISER", Color(0.89, 0.87, 1.0))
			for hair in b.hairs:
				var sway: float = randf_range(-10, 10) if pv > 0.0 else sin(t * 2.0 + hair.ph) * 5.0
				var base := o + Vector2(hair.x, 1.0)
				ElemKit.qcurve(n, base, base + Vector2(sway * 0.5, -hair.len * 0.6),
					base + Vector2(sway, -hair.len * (1.5 if pv > 0.0 else 1.0)),
					Color(0.82, 0.78, 1.0, 0.9 if pv > 0.0 else 0.45), 1.0)
				if pv > 0.0 and randf() < 0.2:
					n.draw_rect(Rect2(base + Vector2(sway - 1, -hair.len - randf_range(0, 8)), Vector2(2, 2)),
						Color(1, 1, 1, pv))

static func _tesla_arc(n: CanvasItem, b: Dictionary, theta: float, bright: float) -> void:
	var r: Rect2 = b.rect
	var c := r.get_center()
	var p0 := c + Vector2(cos(theta) * r.size.x * 0.48, sin(theta) * r.size.y * 0.52)
	var p1 := c + Vector2(cos(theta) * r.size.x * 0.68, sin(theta) * r.size.y * 0.95)
	var p := p0
	for i in range(1, 5):
		var k := i / 4.0
		var q := p0.lerp(p1, k) + Vector2(randf_range(-3, 3), randf_range(-3, 3))
		n.draw_line(p, q, Color(0.67, 0.78, 1.0, bright), 1.4)
		p = q
