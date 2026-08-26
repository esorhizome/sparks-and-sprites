extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
const Base := preload("res://scenes/elements/air.gd")
## AIR & WIND — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"zephyr": { "name": "Solar wind", "hint": "golden, streams ×3 faster" },
	"cyclone": { "name": "Water spout", "hint": "open sea: blue, slower, with spray" },
	"smoke_signal": { "name": "Bubble signal", "hint": "underwater — puffs rise fast, pop at the rim" },
	"fog_bank": { "name": "Night fog", "hint": "darker, slower — the press GLOWS instead of parting" },
	"updraft": { "name": "Ember updraft", "hint": "the thermal carries embers, faster and hotter" },
	"vacuum": { "name": "Repulsor", "hint": "the field's sign flipped — everything pushed AWAY" },
	"sonic_boom": { "name": "Quiet ripple", "hint": "violence dialled out — see-through, serene" },
	"windsock": { "name": "Kite tail", "hint": "festival colours, tied to a stiffer breeze" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)
	match b.id:
		"zephyr":
			for w in b.winds:           # the ×3 stream dial
				w.v *= 3.0
		"fog_bank":
			for bl in b.blobs:          # the ÷2 drift dial
				bl.v *= 0.5
		"windsock":
			b.wind = 2.2                # a stiffer resting breeze

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"windsock":
			b.wind = 5.0
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"smoke_signal":
			# dials: drift up 22 → 60 (buoyant) · pop at the top rim
			b.press_v = maxf(0.0, b.press_v - dt * 1.3)
			b.timer -= dt
			if b.timer <= 0.0:
				b.parts.append({ "pos": Vector2(r.size.x / 2.0 + randf_range(-4, 4), -2.0), "r": 3.0, "life": 1.0 })
				b.timer = randf_range(1.8, 2.6)
			if b.queue > 0:
				b.q_timer -= dt
				if b.q_timer <= 0.0:
					b.parts.append({ "pos": Vector2(r.size.x / 2.0 + randf_range(-4, 4), -2.0), "r": 3.0, "life": 1.0 })
					b.queue -= 1
					b.q_timer = 0.22
			for p in b.parts:
				p.pos.y -= 60.0 * dt
				p.pos.x += sin(p.pos.y * 0.2) * 8.0 * dt
				p.r += 3.0 * dt
				p.life -= dt * 0.9
			b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.pos.y > -34.0)
		"vacuum":
			# dial: pull → push (sign flipped), motes recycled at the centre
			b.press_v = maxf(0.0, b.press_v - dt * 1.3)
			var push: float = 12.0 + b.press_v * 260.0
			for m in b.motes:
				var d: Vector2 = m.pos - r.size / 2.0
				var dist := maxf(4.0, d.length())
				m.pos += d / dist * push * dt
				if dist > r.size.x * 0.75:
					var th := randf_range(0, TAU)
					m.pos = r.size / 2.0 + Vector2(cos(th), sin(th)) * randf_range(4.0, 10.0)
			if b.press_v > 0.0:
				b.ring = b.ring + 200.0 * dt   # the ring runs outward too
		"windsock":
			# dial: wind relaxes toward 2.2, not 1.0
			b.press_v = maxf(0.0, b.press_v - dt * 1.3)
			b.wind += (2.2 - b.wind) * dt * 0.8
			var pts: Array = b.pts
			pts[0] = Vector2(r.size.x - 2, 8)
			for i in range(1, pts.size()):
				var target: Vector2 = pts[i - 1] + Vector2(6.0 * b.wind,
					sin(t * (6.0 + b.wind * 2.0) + i * 0.9) * (2.2 + b.wind))
				pts[i] = (pts[i] as Vector2).lerp(target, minf(1.0, dt * 14.0))
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	match b.id:
		"zephyr":
			# dials: breeze blue → solar gold (speed dial in init)
			ElemKit.face(n, r, Color(0.118, 0.094, 0.047, 0.92), Color(1, 0.84, 0.47, 0.5))
			ElemKit.label(n, r, "CORONA", Color(1, 0.94, 0.8))
			for w in b.winds:
				var x: float = r.size.x * w.p
				var dodge: float = exp(-pow((x - r.size.x / 2.0) / (r.size.x * 0.45), 2.0))
				var sign_l: float = 1.0 if w.lane >= 0.0 else -1.0
				var y: float = r.size.y / 2.0 + w.lane * r.size.y * 0.35 + dodge * r.size.y * 0.75 * sign_l
				ElemKit.qcurve(n, o + Vector2(x - 20.0 - pv * 10.0, y + 2), o + Vector2(x - 8, y - 1),
					o + Vector2(x, y), Color(1, 0.86, 0.51, 0.35 + pv * 0.4), 1.4)
		"cyclone":
			# dials: dust twister → water spout, wander ÷2, debris → spray
			ElemKit.face(n, r, Color(0.047, 0.086, 0.125, 0.92), Color(0.55, 0.78, 0.92, 0.5))
			ElemKit.label(n, r, "SPOUT", Color(0.85, 0.93, 0.97))
			var cx := o.x + r.size.x / 2.0 + sin(t * 0.25) * r.size.x * 0.55
			var base_y := o.y + r.size.y + 6.0
			var top_y := o.y - 14.0 - pv * 8.0
			var size_m := 1.0 + pv * 0.8
			for i in 9:
				var k := i / 8.0
				var y := base_y + (top_y - base_y) * k
				var rad := (2.0 + k * 12.0) * size_m
				var a := t * (4.0 - k * 1.5) + i
				ElemKit.ellipse(n, Vector2(cx + sin(t * 1.2 + k * 3.0) * 3.0, y), rad, rad * 0.3,
					Color(0.55, 0.8, 0.94, 0.55 - k * 0.25 + pv * 0.3), 1.4, a, a + 4.0, 10)
			for p in b.parts:
				var y: float = base_y + (top_y - base_y) * p.h
				var rad: float = (2.0 + p.h * 12.0) * size_m
				n.draw_circle(Vector2(cx + cos(p.a) * rad, y + sin(p.a) * rad * 0.3), 1.3,
					Color(0.8, 0.92, 1.0, p.life * 0.85))
		"smoke_signal":
			ElemKit.face(n, r, Color(0.047, 0.09, 0.11, 0.92), Color(0.55, 0.84, 0.88, 0.5))
			ElemKit.label(n, r, "GLUB", Color(0.85, 0.95, 0.96))
			for p in b.parts:
				var edge: float = clampf((p.pos.y + 34.0) / 20.0, 0.0, 1.0)   # thins near the pop line
				ElemKit.ellipse(n, o + p.pos, p.r, p.r, Color(0.71, 0.92, 0.96, 0.6 * p.life * edge), 1.0)
				n.draw_circle(o + p.pos - Vector2(p.r * 0.3, p.r * 0.3), p.r * 0.22, Color(1, 1, 1, 0.5 * p.life))
		"fog_bank":
			# dials: press parts the fog → press LIGHTS it (alpha up, lantern glow)
			ElemKit.face(n, r, Color(0.055, 0.055, 0.086, 0.95), Color(0.47, 0.47, 0.63, 0.5))
			ElemKit.label(n, r, "NIGHT WATCH", Color(0.78, 0.78, 0.88))
			if pv > 0.0:
				ElemKit.glow(n, r.get_center(), 26.0, Color(1, 0.86, 0.55, pv * 0.4), 4)
			for bl in b.blobs:
				var x: float = r.get_center().x + bl.ox * 0.6
				ElemKit.glow(n, Vector2(x, r.get_center().y + bl.oy), bl.r,
					Color(0.55, 0.55, 0.7, 0.14 + pv * 0.1), 3)
		"updraft":
			# dials: leaves → embers, climb faster, warm face
			ElemKit.face(n, r, Color(0.11, 0.07, 0.04, 0.92), Color(1, 0.71, 0.39, 0.5))
			ElemKit.label(n, r, "CHIMNEY", Color(1, 0.9, 0.78))
			for p in b.parts:
				var pos: Vector2 = o + p.pos + Vector2(0, -p.v * 0.1)
				n.draw_rect(Rect2(pos, Vector2(2.2, 2.2)), Color(1, 0.7, 0.31, 0.9))
				n.draw_rect(Rect2(pos + Vector2(0.4, 2.2), Vector2(1.4, 3.0)), Color(1, 0.5, 0.2, 0.35))
		"vacuum":
			ElemKit.face(n, r, Color(0.09, 0.07, 0.11, 0.96), Color(0.82, 0.63, 0.9, 0.5))
			ElemKit.label(n, r, "EXHALE", Color(0.93, 0.86, 0.96))
			for m in b.motes:
				n.draw_rect(Rect2(o + m.pos, Vector2(1.5, 1.5)), Color(0.84, 0.7, 0.9, 0.3 + pv * 0.5))
			if pv > 0.0:
				ElemKit.ellipse(n, r.get_center(), b.ring * 1.4, b.ring * 0.8,
					Color(0.9, 0.78, 0.96, pv * 0.6), 1.5)
		"sonic_boom":
			# dials: speed lines & lean removed · the cone drawn faint and slow
			ElemKit.face(n, r, Color(0.078, 0.086, 0.125, 0.96), Color(0.75, 0.82, 0.92, 0.4))
			ElemKit.label(n, r, "HUSH", Color(0.85, 0.9, 0.95, 0.9))
			if pv > 0.0:
				var k := 1.0 - pv
				for ring in 3:
					var rad := 10.0 + k * 40.0 + ring * 10.0
					ElemKit.ellipse(n, Vector2(o.x + r.size.x + 6, r.get_center().y), rad * 0.5, rad,
						Color(0.86, 0.92, 1.0, pv * 0.25), 1.2, -1.2, 1.2, 14)
		"windsock":
			ElemKit.face(n, r, Color(0.078, 0.094, 0.118, 0.92), Color(0.75, 0.8, 0.88, 0.5))
			ElemKit.label(n, r, "FESTIVAL", Color(0.89, 0.92, 0.96))
			var pts: Array = b.pts
			var cols := [Color(1, 0.45, 0.45), Color(1, 0.78, 0.31), Color(0.47, 0.86, 0.55),
				Color(0.43, 0.7, 1.0), Color(0.8, 0.55, 0.95)]
			for i in range(1, pts.size()):
				n.draw_line(o + pts[i - 1], o + pts[i], cols[(i - 1) % cols.size()], 3.0)
		_:
			Base.draw(n, b, t)
