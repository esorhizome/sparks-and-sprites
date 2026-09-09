extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
const Base := preload("res://scenes/elements/air.gd")
## AIR & WIND — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"zephyr": { "name": "Solar wind", "hint": "golden, streams ×3 faster" },
	"cyclone": { "name": "Water spout", "hint": "open sea: blue, with spray — spin 6 → 4, the amble spring ÷4" },
	"smoke_signal": { "name": "Bubble signal", "hint": "underwater — puffs rise fast, pop at the rim" },
	"fog_bank": { "name": "Night fog", "hint": "darker, drift ÷2 — the press GLOWS instead of parting (gust → 0)" },
	"updraft": { "name": "Ember updraft", "hint": "embers: lift ×1.6, no glide (a speck can't tilt), turbulence ×2" },
	"vacuum": { "name": "Repulsor", "hint": "the field's sign flipped (G → −G) — everything pushed AWAY" },
	"sonic_boom": { "name": "Quiet ripple", "hint": "violence dialled out — see-through, serene" },
	"windsock": { "name": "Kite tail", "hint": "festival colours, root spring ×1.9, the wind resting at 2.2" },
}

## Turn dials the original already has — a rhyme never invents a key.
static func _turn(b: Dictionary, dials: Dictionary) -> void:
	for k in dials:
		assert(b.D.has(k), "rhyme dial %s.%s is not a dial of the original" % [b.id, k])
		b.D[k] = dials[k]

static func init(b: Dictionary) -> void:
	Base.init(b)
	match b.id:
		"zephyr":
			for w in b.winds:           # the ×3 stream dial
				w.v *= 3.0
		"cyclone":                      # dials: a slower spin, an amble at half the pace with longer pauses
			_turn(b, { "spin": 4.0, "kw": 1.0, "retarget": 5.0 })
		"fog_bank":                     # dials: drift ÷2 · the gust switched off — the press only lights it
			_turn(b, { "drift": 0.5, "gust": 0.0 })
		"vacuum":                       # dial: the pull's sign flipped — a push of the same strength
			_turn(b, { "G": -20000.0 })
		"updraft":
			b.lift = 224.0              # ×1.6: a chimney pushes harder
			b.glide = 0.0               # a speck can't tilt, so no glide and no coupling…
			b.couple = 0.0
			b.gust = 440.0              # …but twice the turbulence
		"windsock":
			b.k = 130.0                 # a stiffer root spring
			b.wind_rest = 2.2           # a steadier breeze
			b.wind = 2.2
			(b.th as PackedFloat32Array).fill(atan(float(b.droop) / 2.2))

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
			# dial: pull → push (G's sign, turned in init); motes reborn at the CENTRE once flung clear
			b.press_v = maxf(0.0, b.press_v - dt * 1.3)
			var push: float = float(b.D.G) * (1.0 + b.press_v * float(b.D.slam))
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / sub
			for m in b.motes:
				for _s in sub:
					var dist := Base._mote_step(b, m, h, push)
					if dist > r.size.x * 0.75:
						var th := randf_range(0, TAU)
						m.pos = r.size / 2.0 + Vector2(cos(th), sin(th)) * randf_range(4.0, 10.0)
						m.vel = Vector2.ZERO
						break
			if b.press_v > 0.0:
				b.ring = b.ring + 200.0 * dt   # the ring runs outward too
		_:
			Base.tick(b, dt, t)         # windsock and updraft: the dials moved in init, the same chain and loop run

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
			# dials: dust twister → water spout, debris → spray (spin and amble dials in init)
			ElemKit.face(n, r, Color(0.047, 0.086, 0.125, 0.92), Color(0.55, 0.78, 0.92, 0.5))
			ElemKit.label(n, r, "SPOUT", Color(0.85, 0.93, 0.97))
			var cx0 := o.x + r.size.x / 2.0
			var X: PackedFloat32Array = b.X
			var ang: PackedFloat32Array = b.ang
			var N := X.size()
			var base_y := o.y + r.size.y + 6.0
			var top_y := o.y - 14.0 - pv * 8.0
			var size_m := 1.0 + pv * 0.8
			for i in N:
				var k := i / float(N - 1)
				var y := base_y + (top_y - base_y) * k
				var rad := (2.0 + k * 12.0) * size_m
				var a: float = ang[i]
				ElemKit.ellipse(n, Vector2(cx0 + X[i], y), rad, rad * 0.3,
					Color(0.55, 0.8, 0.94, 0.55 - k * 0.25 + pv * 0.3), 1.4, a, a + 4.0, 10)
			for p in b.parts:
				var y: float = base_y + (top_y - base_y) * p.h
				var rad: float = (2.0 + p.h * 12.0) * size_m
				var cx: float = cx0 + X[mini(N - 1, roundi(p.h * (N - 1)))]
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
				var x: float = r.get_center().x + bl.x * 0.6
				ElemKit.glow(n, Vector2(x, r.get_center().y + bl.oy), bl.r,
					Color(0.55, 0.55, 0.7, 0.14 + pv * 0.1), 3)
		"updraft":
			# dials: leaves → embers, climb faster, warm face
			ElemKit.face(n, r, Color(0.11, 0.07, 0.04, 0.92), Color(1, 0.71, 0.39, 0.5))
			ElemKit.label(n, r, "CHIMNEY", Color(1, 0.9, 0.78))
			for p in b.parts:
				var pos: Vector2 = o + p.pos
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
			var pts: PackedVector2Array = b.pts
			var cols := [Color(1, 0.45, 0.45), Color(1, 0.78, 0.31), Color(0.47, 0.86, 0.55),
				Color(0.43, 0.7, 1.0), Color(0.8, 0.55, 0.95)]
			for i in range(1, pts.size()):
				n.draw_line(o + pts[i - 1], o + pts[i], cols[(i - 1) % cols.size()], 3.0)
		_:
			Base.draw(n, b, t)
