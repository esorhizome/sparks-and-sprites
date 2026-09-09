extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
## LIGHTNING — eight buttons, ported from the web bestiary.

const TITLE := "Lightning"
const BLURB := "charge, arc, and the crack of discharge"
const DEFS := [
	{ "id": "static_charge", "name": "Static charge", "hint": "tiny crackles bite the edges; press for a bolt across the face" },
	{ "id": "tesla_ring", "name": "Tesla ring", "hint": "an arc dances between button and outer ring; press fires them all" },
	{ "id": "storm_cloud", "name": "Storm cloud", "hint": "a cloud broods overhead, bobbing on a spring only its own mutters nudge; press and it strikes the button — and recoils from the bolt" },
	{ "id": "circuit", "name": "Circuit trace", "hint": "pulses travel etched copper paths; press to send them all at once" },
	{ "id": "plasma_globe", "name": "Plasma globe", "hint": "filaments wander the rim, each tip a sprung point; press and they swing to your finger, overshoot, and settle" },
	{ "id": "neon", "name": "Neon flicker", "hint": "a buzzing neon tube border; press to steady it for a moment" },
	{ "id": "emp", "name": "EMP", "hint": "shockwave rings pulse outward; press for the big one" },
	{ "id": "vandegraaff", "name": "Van de Graaff", "hint": "hairs stand up as the dome charges, two-hinge spring chains; press to discharge — they drop, swing, and rise again" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	var r: Rect2 = b.rect
	match b.id:
		"storm_cloud":
			b.D = { "k": 30.0,          # the cloud's vertical spring, 1/s² (ω ≈ 5.5 rad/s: a 1.1 s bob)
				"zeta": 0.15,           # damping as a fraction of critical — well under 1, so it rings a few times
				"kick": 60.0,           # the bolt's recoil, px/s upward, injected the instant it fires
				"mutter": 8.0,          # a mutter's nudge, px/s either way — the idle bob comes from these, not a clock
				"rest": 16.0 }          # the cloud's resting height above the button, px
			# the cloud is one mass on a vertical spring. nothing moves it but kicks: a
			# mutter gives a small random nudge, the bolt a big upward one (the recoil),
			# and the under-damped spring does the rest — it rises, falls back through
			# the rest height, and settles in a couple of swings. no sine anywhere.
			b.cy = 0.0                  # displacement from rest, px (down is +)
			b.cvy = 0.0                 # and its velocity, px/s
			b.flicker = 0.0             # the mutter's glow, fading
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
			# each filament's tip is a POINT with velocity on a damped spring toward
			# its target — a wandering spot on the rim, or the finger while held. it
			# never jumps: it accelerates, overshoots (under-damped), and rings down
			b.k = 90.0                     # the spring pulling each tip toward its target
			b.damp = 0.3                   # as a fraction of critical (2√k): under 1, so the tip overshoots the finger
			b.wander = 0.8                 # how fast the idle targets drift round the rim, radians/s (±)
			b.fils = []
			for i in 6:
				var a := randf_range(0, TAU)
				b.fils.append({ "a": a, "va": randf_range(-b.wander, b.wander),
					"pos": r.size / 2.0 + Vector2(cos(a) * r.size.x * 0.48, sin(a) * r.size.y * 0.5), "vel": Vector2.ZERO })
			b.target = Vector2.ZERO
			b.hold = 0.0
		"neon":
			b.dropout = 0.0
			b.steady = 0.0
		"emp":
			b.timer = 1.0
		"vandegraaff":
			# each hair is a CHAIN of two angles from vertical on a damped spring. the
			# root's REST is where the charge says: flopped sideways with none,
			# standing (spread from its neighbours — like charges repel) at full.
			# the tip chases the root, quicker and less damped. charging moves the
			# rest slowly; the discharge drops it at once and the hairs fall
			# through their own springs, overshoot, and swing
			b.k = 45.0                     # the root hinge's stiffness
			b.damp = 0.35                  # its damping as a fraction of critical (2√k): under 1, so a dropped hair swings
			b.tip = 1.6                    # the tip hinge's k as a multiple of the root's (lighter, so quicker)
			b.tipdamp = 0.3                # the tip hinge's damping as a fraction of ITS OWN critical
			b.flop = 1.25                  # where a limp hair lies, radians from vertical
			b.spread = 0.3                 # where a fully charged hair stands, radians
			b.charge_rate = 0.45           # how fast the dome charges back up, per second
			b.crackle = 6.0                # random torque on a charged hair, rad/s² — the static's fizz
			b.lean = 0.0                   # a current's lean on the rest, radians (the seagrass rhyme's dial)
			b.charge = 0.0
			b.hairs = []
			var x := 8.0
			while x < r.size.x - 6.0:
				var side := (-1.0 if x < r.size.x / 2.0 else 1.0) * randf_range(0.6, 1.4)   # which way it leans, and how much
				b.hairs.append({ "x": x, "len": randf_range(10, 20), "side": side,
					"th0": b.flop * side, "om0": 0.0, "th1": b.flop * side, "om1": 0.0 })
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
			if b.id == "storm_cloud":
				b.cvy -= float(b.D.kick)   # the recoil: the bolt throws the cloud upward
			if b.id == "vandegraaff":
				b.charge = 0.0             # the discharge: the rest drops, the hairs follow by spring
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
		"storm_cloud":
			_cloud_spring(b, dt)
		"circuit":
			for p in b.paths:
				p.d += p.v * (1.0 + b.press_v * 3.0) * dt
				if p.d > p.len:
					p.d = 0.0
		"plasma_globe":
			b.hold = maxf(0.0, b.hold - dt)
			_plasma_step(b, dt)
		"vandegraaff":
			b.charge = minf(1.0, b.charge + float(b.charge_rate) * dt)
			_hair_step(b, dt, t)
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

## The storm cloud's spring, shared with its rhyme: symplectic Euler in ≤ 0.02 s
## steps (a coarse frame would otherwise make the ringing grow), plus the
## mutters — each one a random nudge to the velocity and a brief glow.
static func _cloud_spring(b: Dictionary, dt: float) -> void:
	var D: Dictionary = b.D
	var k: float = D.k
	var damp: float = float(D.zeta) * 2.0 * sqrt(k)
	var cy: float = b.cy
	var cvy: float = b.cvy
	var sub := maxi(1, ceili(dt * 50.0))
	var h := dt / sub
	for _s in sub:
		cvy += (-k * cy - damp * cvy) * h
		cy += cvy * h
	if randf() < 0.01:                  # the cloud mutters to itself, and shifts
		b.flicker = 0.5
		cvy += randf_range(-float(D.mutter), float(D.mutter))
	b.cy = clampf(cy, -60.0, 60.0)
	b.cvy = cvy
	b.flicker = maxf(0.0, float(b.flicker) - dt * 2.0)

## The filaments' sprung tips: each chases its target (the rim spot, or the
## finger while held) on a damped spring — the rhyme calls this with its dials.
static func _plasma_step(b: Dictionary, dt: float) -> void:
	var r: Rect2 = b.rect
	var k: float = b.k
	var d: float = b.damp * 2.0 * sqrt(k)
	var chasing: bool = b.hold > 0.0
	var sub := maxi(1, ceili(dt * 50.0))
	var h := dt / float(sub)
	for f in b.fils:
		f.a += f.va * dt
		var target: Vector2 = b.target if chasing else r.size / 2.0 + Vector2(cos(f.a) * r.size.x * 0.48, sin(f.a) * r.size.y * 0.5)
		for _s in sub:
			f.vel += (k * (target - f.pos) - d * f.vel) * h
			f.pos += f.vel * h

## The hair chain: root rest from charge (and any current's lean), tip chasing
## the root. Shared with the seagrass rhyme, whose dials zero the charge.
static func _hair_step(b: Dictionary, dt: float, t: float) -> void:
	var k: float = b.k
	var d0: float = b.damp * 2.0 * sqrt(k)
	var k1: float = k * float(b.tip)
	var d1: float = b.tipdamp * 2.0 * sqrt(k1)
	var flop: float = b.flop
	var spread: float = b.spread
	var charge: float = b.charge
	var crackle: float = b.crackle
	var lean: float = b.lean
	var sub := maxi(1, ceili(dt * 50.0))   # substep: √k·h must stay under 2
	var h := dt / float(sub)
	for hair in b.hairs:
		var rest: float = hair.side * (flop - charge * (flop - spread)) + sin(t * 0.6 + hair.x * 0.04) * lean
		hair.om0 += randf_range(-1, 1) * crackle * charge * dt      # the crackle: a little random torque while charged
		for _s in sub:
			hair.om0 += (k * (rest - hair.th0) - d0 * hair.om0) * h
			hair.th0 = clampf(hair.th0 + hair.om0 * h, -1.6, 1.6)
			hair.om1 += (k1 * (hair.th0 - hair.th1) - d1 * hair.om1) * h   # the tip chases the root
			hair.th1 = clampf(hair.th1 + hair.om1 * h, -1.6, 1.6)

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
			var cy: float = o.y - float(b.D.rest) + float(b.cy)   # wherever the spring has carried it
			var hit := pv > 0.55
			ElemKit.face(n, r, Color(0.47, 0.51, 0.7, 0.95) if hit else Color(0.078, 0.078, 0.14, 0.95),
				Color(0.59, 0.67, 1.0, 0.4 + pv * 0.6))
			ElemKit.label(n, r, "STORM", Color(0.06, 0.07, 0.16) if hit else Color(0.85, 0.87, 1.0))
			if b.flicker > 0.0:
				ElemKit.glow(n, Vector2(r.get_center().x + randf_range(-14, 14), cy), 14.0,
					Color(0.75, 0.78, 1.0, float(b.flicker) * 0.9), 3)
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
				var e: Vector2 = o + f.pos + Vector2(randf_range(-3, 3), randf_range(-3, 3))   # the sprung tip, with its jitter
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
			var charge: float = b.charge
			ElemKit.face(n, r, Color(0.094, 0.078, 0.125, 0.95), Color(0.78, 0.75, 1.0, 0.3 + charge * 0.3))
			ElemKit.label(n, r, "HAIR-RAISER", Color(0.89, 0.87, 1.0))
			for hair in b.hairs:
				var seg: float = hair.len / 2.0                  # walk the chain: base → joint → tip
				var base := o + Vector2(hair.x, 1.0)
				var joint: Vector2 = base + Vector2(sin(hair.th0), -cos(hair.th0)) * seg
				var tip: Vector2 = joint + Vector2(sin(hair.th1), -cos(hair.th1)) * seg
				ElemKit.qcurve(n, base, joint, tip, Color(0.82, 0.78, 1.0, 0.35 + charge * 0.3 + pv * 0.3), 1.0)
				if pv > 0.0 and randf() < 0.2:                   # sparks off the tips as the charge leaves
					n.draw_rect(Rect2(tip + Vector2(randf_range(-4, 2), -randf_range(1, 7)), Vector2(2, 2)),
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
