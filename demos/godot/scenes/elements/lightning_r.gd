extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
const Base := preload("res://scenes/elements/lightning.gd")
## LIGHTNING — the rhymes. Dials named per branch; everything else delegates.

const RHYMES := {
	"static_charge": { "name": "Static dust", "hint": "gold motes, bolt becomes a shimmer" },
	"tesla_ring": { "name": "Halo arcs", "hint": "warmed to gold, slowed to a waltz" },
	"storm_cloud": { "name": "Snow cloud", "hint": "the strike dial swapped for a flurry — recoil kick 60 → 12" },
	"circuit": { "name": "Ink trace", "hint": "wet ink on pale paper, pulses ÷2" },
	"plasma_globe": { "name": "Sun globe", "hint": "amber filaments, wander ×2, spring looser (wider swings)" },
	"neon": { "name": "Steady cyan", "hint": "hue rotated, hum ÷4, dropouts rare" },
	"emp": { "name": "Pond rings", "hint": "jitter dialled to zero, water palette" },
	"vandegraaff": { "name": "Seagrass", "hint": "rooted to the BOTTOM edge, green, spring ÷3, charge → a slow current, press = a surge" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)
	if b.id == "storm_cloud":
		b.flakes = []
		_turn(b, { "kick": 12.0 })        # dial: a flurry's release is a nudge, not a bolt's recoil
	if b.id == "circuit":
		for p in b.paths:                  # the ÷2 pulse dial lives here
			p.v *= 0.5
	if b.id == "plasma_globe":
		b.damp = 0.2                       # looser than the plasma, so the flares swing wider
		for f in b.fils:                   # the ×2 wander dial
			f.va *= 2.0
	if b.id == "vandegraaff":
		b.k = 14.0                         # soft: it's grass in water
		b.damp = 0.3
		b.flop = 0.0                       # no charge to stand up from, no flop to fall to…
		b.spread = 0.0
		b.charge_rate = 0.0
		b.crackle = 0.0
		b.lean = 0.45                      # …just a slow current leaning the strands
		for hair in b.hairs:
			hair.th0 = 0.0
			hair.th1 = 0.0

## Turn dials the original already has — a rhyme never invents a key.
static func _turn(b: Dictionary, dials: Dictionary) -> void:
	for k in dials:
		assert(b.D.has(k), "rhyme dial %s.%s is not a dial of the original" % [b.id, k])
		b.D[k] = dials[k]

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"vandegraaff":
			# dial: discharge → a passing surge: angular velocity in, no teleport
			for hair in b.hairs:
				hair.om0 += 5.0 * (0.6 + 0.4 * sin(hair.x * 0.1))
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"storm_cloud":
			# dial: bolt → snowfall burst (the cloud's spring is the original's)
			Base._cloud_spring(b, dt)
			b.press_v = maxf(0.0, b.press_v - dt * 1.2)
			if b.press_v > 0.0 or randf() < 0.06:
				b.flakes.append({ "pos": Vector2(b.rect.size.x / 2.0 + randf_range(-30, 30), -12.0),
					"ph": randf_range(0, 9) })
			for f in b.flakes:
				f.pos.y += 40.0 * dt
				f.pos.x += sin(t * 2.0 + f.ph) * 10.0 * dt
			b.flakes = b.flakes.filter(func(f): return f.pos.y < b.rect.size.y + 10.0)
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	match b.id:
		"static_charge":
			# dials: palette blue→gold · crackle ÷2 · bolt → shimmer dots
			ElemKit.face(n, r, Color(0.1, 0.086, 0.047, 0.92), Color(1, 0.86, 0.55, 0.4 + pv * 0.6))
			ElemKit.label(n, r, "GILDED", Color(1, 0.94, 0.78))
			if randf() < 0.12:
				n.draw_rect(Rect2(o + Vector2(randf_range(0, r.size.x),
					0.0 if randf() < 0.5 else r.size.y) + Vector2(randf_range(-3, 3), randf_range(-3, 3)),
					Vector2(2, 2)), Color(1, 0.9, 0.63, 0.9))
			if b.has("bolt") and b.bolt != null:
				var x := 0.0
				while x < r.size.x:
					if randf() < 0.7:
						n.draw_rect(Rect2(o + Vector2(x, r.size.y / 2.0 + randf_range(-10, 10)), Vector2(2, 2)),
							Color(1, 0.94, 0.75, b.bolt.life))
					x += 6.0
		"tesla_ring":
			# dials: dancer speed 1.6→0.5 · palette blue→gold
			ElemKit.ellipse(n, r.get_center(), r.size.x * 0.68, r.size.y * 0.95, Color(0.9, 0.78, 0.51, 0.35), 1.0)
			ElemKit.face(n, r, Color(0.094, 0.078, 0.047, 0.95), Color(1, 0.88, 0.63, 0.6))
			ElemKit.label(n, r, "GLORIOLE", Color(1, 0.95, 0.83))
			_gold_arc(n, b, t * 0.5, 0.8)
			if randf() < 0.03:
				_gold_arc(n, b, randf_range(0, TAU), 0.6)
			if pv > 0.0:
				for i in 8:
					_gold_arc(n, b, i / 8.0 * TAU + t, pv)
		"storm_cloud":
			var cy: float = o.y - float(b.D.rest) + float(b.cy)
			ElemKit.face(n, r, Color(0.07, 0.078, 0.125, 0.95), Color(0.78, 0.84, 0.96, 0.4 + pv * 0.5))
			if b.flicker > 0.0:
				ElemKit.glow(n, Vector2(r.get_center().x + randf_range(-14, 14), cy), 14.0,
					Color(0.86, 0.9, 0.98, float(b.flicker) * 0.5), 3)
			ElemKit.label(n, r, "FLURRY", Color(0.9, 0.93, 0.98))
			for i in 5:
				n.draw_circle(Vector2(r.get_center().x + (i - 2) * 13.0, cy + sin(i * 2.7) * 3.0),
					10.0 + (i % 2) * 3.0, Color(0.47, 0.5, 0.59))
			for f in b.flakes:
				n.draw_circle(o + Vector2(r.size.x / 2.0, 0) + f.pos - Vector2(r.size.x / 2.0, 0), 1.4,
					Color(0.92, 0.95, 1.0, 0.85))
		"circuit":
			# dials: copper-on-dark → ink-on-paper · pulse handled by Base tick
			ElemKit.face(n, r, Color(0.85, 0.82, 0.77), Color(0.35, 0.31, 0.24, 0.5 + pv * 0.5))
			for p in b.paths:
				var poly := PackedVector2Array()
				for q in p.pts:
					poly.append(o + q)
				n.draw_polyline(poly, Color(0.16, 0.13, 0.11, 0.5 + pv * 0.3), 1.2)
				var pos: Vector2 = o + Base._path_point(p, p.d)
				n.draw_rect(Rect2(pos - Vector2(2, 2), Vector2(4, 4)), Color(0.08, 0.063, 0.047, 0.95))
			ElemKit.label(n, r, "MANUSCRIPT", Color(0.2, 0.165, 0.125, 0.85))
		"plasma_globe":
			ElemKit.face(n, r, Color(0.118, 0.07, 0.031, 0.92), Color(1, 0.78, 0.43, 0.5))
			ElemKit.glow(n, r.get_center(), 14.0, Color(1, 0.92, 0.71, 0.7), 3)
			var chasing: bool = b.hold > 0.0
			for f in b.fils:
				var e: Vector2 = o + f.pos + Vector2(randf_range(-3, 3), randf_range(-3, 3))
				var p := r.get_center()
				for k in range(1, 6):
					var q: Vector2 = r.get_center().lerp(e, k / 5.0) + Vector2(randf_range(-4, 4), randf_range(-4, 4)) * sin(k / 5.0 * PI)
					n.draw_line(p, q, Color(1, 0.84, 0.55, 0.95 if chasing else 0.55), 1.2)
					p = q
			ElemKit.label(n, r, "HELIOS", Color(1, 0.94, 0.82))
		"neon":
			# dials: hue pink→cyan · buzz 120→30 (Base decides dropouts; we redraw)
			var buzz: float = 1.0 if b.steady > 0.0 else 0.86 + sin(t * 30.0) * 0.05
			var on: float = buzz if b.dropout <= 0.0 else 0.08
			ElemKit.ring_face(n, r.grow(2.0), Color(0.31, 0.86, 1.0, on * 0.25), 7)
			ElemKit.ring_face(n, r, Color(0.71, 0.94, 1.0, on), 2)
			ElemKit.label(n, r, "ALL NIGHT", Color(0.75, 0.94, 1.0, on))
		"emp":
			ElemKit.face(n, r, Color(0.04, 0.078, 0.11, 0.92), Color(0.47, 0.78, 0.92, 0.5))
			ElemKit.label(n, r, "STILLNESS", Color(0.81, 0.92, 0.96))
			for p in b.parts:
				if p.kind == "ring":
					ElemKit.ellipse(n, r.get_center(), p.r * 1.4, p.r * 0.75,
						Color(0.59, 0.84, 0.94, p.life * (0.95 if p.big else 0.5)), 2.0 if p.big else 1.0)
				else:
					n.draw_rect(Rect2(o + p.pos, Vector2(2, 2)), Color(0.7, 0.88, 0.96, p.life))
		"vandegraaff":
			# dials: root edge top→bottom (the chain walks DOWN) · palette→kelp · the spring dials in init
			ElemKit.face(n, r, Color(0.047, 0.086, 0.078, 0.92), Color(0.47, 0.78, 0.63, 0.5))
			ElemKit.label(n, r, "KELP", Color(0.82, 0.93, 0.87))
			for hair in b.hairs:
				var seg: float = hair.len / 2.0
				var base := o + Vector2(hair.x, r.size.y - 1.0)
				var joint: Vector2 = base + Vector2(sin(hair.th0), cos(hair.th0)) * seg
				var tip: Vector2 = joint + Vector2(sin(hair.th1), cos(hair.th1)) * seg
				ElemKit.qcurve(n, base, joint, tip,
					Color(0.55, 0.86, 0.67, 0.45 + minf(0.3, absf(hair.om0) * 0.06)), 1.0)
		_:
			Base.draw(n, b, t)

static func _gold_arc(n: CanvasItem, b: Dictionary, theta: float, bright: float) -> void:
	var r: Rect2 = b.rect
	var c := r.get_center()
	var p := c + Vector2(cos(theta) * r.size.x * 0.48, sin(theta) * r.size.y * 0.52)
	var p1 := c + Vector2(cos(theta) * r.size.x * 0.68, sin(theta) * r.size.y * 0.95)
	for i in range(1, 5):
		var q: Vector2 = p.lerp(p1, 0.25) + Vector2(randf_range(-1.2, 1.2), randf_range(-1.2, 1.2))
		n.draw_line(p, q, Color(1, 0.88, 0.63, bright), 1.4)
		p = q
