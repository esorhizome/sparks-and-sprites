extends RefCounted

const Kit := preload("res://scenes/motion/kit.gd")
## BODIES & GROUND — five movement styles, ported from the web lexicon.
## Verlet integration stores no velocity at all — just where each point is
## and where it was last frame; the difference IS the velocity. Distance
## constraints make ragdolls and crates; rays and normals tell bodies where
## the world is; Gait spends everything the other cards earned.

const TITLE := "Bodies & ground"
const BLURB := "verlet, impulses, rays, normals — and the walk that uses it all"
const DEFS := [
	{ "id": "ragdoll", "name": "R · Ragdoll", "hint": "verlet points + distance promises = a body — press to shove it" },
	{ "id": "knock", "name": "K · Knock", "hint": "impulses: a shockwave edits velocities once, then physics gossips — press anywhere" },
	{ "id": "xmarks", "name": "X · Xmarks", "hint": "raycasting: where does this line first hit the world? — press to aim the beam" },
	{ "id": "normals", "name": "N · Normals", "hint": "the slope, turned 90°: a walker that hugs its terrain — press to turn it around" },
	{ "id": "gait", "name": "G · Gait", "hint": "the walk that uses it all: homes, thresholds, arcs, and a shifting body — press to send it somewhere" },
]

static func _pt(x: float, y: float) -> Dictionary:
	return { "p": Vector2(x, y), "pp": Vector2(x, y) }

static func _box(cx: float, cy: float, s: float) -> Dictionary:
	var p := [_pt(cx - s, cy - s), _pt(cx + s, cy - s), _pt(cx + s, cy + s), _pt(cx - s, cy + s)]
	var c := []
	for pair in [[0, 1], [1, 2], [2, 3], [3, 0], [0, 2], [1, 3]]:   # edges + the two
		var rest: float = (p[pair[0]].p - p[pair[1]].p as Vector2).length()   # diagonals =
		c.append([pair[0], pair[1], rest])                                    # the rigidity
	return { "p": p, "c": c }

static func _terra(b: Dictionary, x: float) -> float:
	return b.h * 0.62 - sin(x * 0.021) * b.h * 0.1 - sin(x * 0.043 + 1.3) * b.h * 0.055 \
		- sin(x * 0.011 + 4.0) * b.h * 0.07

static func _slope(b: Dictionary, x: float) -> float:    # the derivative, by hand
	return -cos(x * 0.021) * b.h * 0.1 * 0.021 - cos(x * 0.043 + 1.3) * b.h * 0.055 * 0.043 \
		- cos(x * 0.011 + 4.0) * b.h * 0.07 * 0.011

static func _walls(b: Dictionary) -> Array:
	return [
		[Vector2(8, 8), Vector2(b.w - 8, 8)], [Vector2(b.w - 8, 8), Vector2(b.w - 8, b.h - 8)],
		[Vector2(b.w - 8, b.h - 8), Vector2(8, b.h - 8)], [Vector2(8, b.h - 8), Vector2(8, 8)],
		[Vector2(b.w * 0.28, b.h * 0.3), Vector2(b.w * 0.44, b.h * 0.52)],
		[Vector2(b.w * 0.62, b.h * 0.24), Vector2(b.w * 0.78, b.h * 0.3)],
		[Vector2(b.w * 0.6, b.h * 0.7), Vector2(b.w * 0.85, b.h * 0.62)],
	]

## One denominator test per wall: does the beam cross it, and how far along?
static func _cast(b: Dictionary, from: Vector2, dir: Vector2) -> Dictionary:
	var best := {}
	for s in _walls(b):
		var sv: Vector2 = s[1] - s[0]
		var den := dir.x * sv.y - dir.y * sv.x           # parallel beams never land
		if absf(den) < 1e-9:
			continue
		var tt: float = ((s[0].x - from.x) * sv.y - (s[0].y - from.y) * sv.x) / den   # along the ray
		var ss: float = ((s[0].x - from.x) * dir.y - (s[0].y - from.y) * dir.x) / den # along the wall
		if tt > 0.5 and ss >= 0.0 and ss <= 1.0 and (best.is_empty() or tt < best.t):
			var nrm := Vector2(-sv.y, sv.x).normalized() # the wall, turned 90°
			if nrm.dot(dir) > 0.0:
				nrm = -nrm                               # face the beam
			best = { "t": tt, "p": from + dir * tt, "n": nrm }
	return best

static func init(b: Dictionary) -> void:
	match b.id:
		"ragdoll":
			var u: float = b.h * 0.062
			var cx: float = b.w / 2.0
			var y0: float = b.h * 0.2
			b.P = {
				"head": _pt(cx, y0), "chest": _pt(cx, y0 + u), "hip": _pt(cx, y0 + u * 2.3),
				"elbL": _pt(cx - u, y0 + u * 0.6), "handL": _pt(cx - u * 2, y0 + u * 1.2),
				"elbR": _pt(cx + u, y0 + u * 0.6), "handR": _pt(cx + u * 2, y0 + u * 1.2),
				"kneeL": _pt(cx - u * 0.5, y0 + u * 3.4), "footL": _pt(cx - u * 0.6, y0 + u * 4.5),
				"kneeR": _pt(cx + u * 0.5, y0 + u * 3.4), "footR": _pt(cx + u * 0.6, y0 + u * 4.5),
			}
			b.C = [                                      # eleven promises
				["head", "chest", u], ["chest", "hip", u * 1.3], ["head", "hip", u * 2.2],
				["chest", "elbL", u], ["elbL", "handL", u], ["chest", "elbR", u], ["elbR", "handR", u],
				["hip", "kneeL", u * 1.1], ["kneeL", "footL", u * 1.1],
				["hip", "kneeR", u * 1.1], ["kneeR", "footR", u * 1.1],
			]
		"knock":
			b.boxes = [_box(b.w * 0.25, b.gy - 14, 13), _box(b.w * 0.52, b.gy - 18, 17), _box(b.w * 0.78, b.gy - 11, 10)]
			b.rings = []
			b.gust_t = 2.5
		"xmarks":
			b.aim = 0.0
			b.want = 0.0
			b.sticky = 0.0
		"normals":
			b.wx = b.w * 0.2
			b.dir = 1.0
		"gait":
			b.bx = b.w * 0.3
			b.vx = 0.0
			b.tx = b.w * 0.7
			b.auto_t = 0.0
			b.feet = [Vector2(b.w * 0.3 - 12, b.gy), Vector2(b.w * 0.3 + 12, b.gy)]
			b.stepping = -1
			b.from = 0.0
			b.to = 0.0
			b.k = 0.0
			b.dur = 0.3

static func _shock(b: Dictionary, at: Vector2, power: float) -> void:
	b.rings.append({ "p": at, "r": 4.0, "a": 1.0 })
	for bx in b.boxes:
		for p in bx.p:
			var d: Vector2 = p.p - at
			var l := d.length() + 30.0
			p.pp -= d / l * (power / l)                  # the impulse: rewrite the past
			p.pp.y += power / l * 0.5                    # plus a hop (up = smaller y)

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"ragdoll":
			for key in b.P:                              # an impulse, verlet-style: to
				var p: Dictionary = b.P[key]             # change a velocity, you edit
				var d: Vector2 = p.p - pos               # the PAST position
				var l := d.length() + 20.0
				p.pp -= d / l * (300.0 / l)
		"knock":
			_shock(b, pos, 380.0)
		"xmarks":
			b.want = (pos - Vector2(b.w * 0.24, b.h * 0.68)).angle()
			b.sticky = 3.0
		"normals":
			b.dir = -b.dir
		"gait":
			b.tx = clampf(pos.x, b.w * 0.08, b.w * 0.92)
			b.auto_t = -8.0

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"ragdoll":
			var G: float = b.h * 2.6
			var anchor := Vector2(b.w / 2.0 + sin(t * 0.55) * b.w * 0.26, b.h * 0.12)   # the trolley
			for key in b.P:
				var p: Dictionary = b.P[key]
				var v: Vector2 = (p.p - p.pp) * 0.99
				p.pp = p.p
				p.p += v + Vector2(0, G * dt * dt)
			for it in 8:
				for c in b.C:
					var pa: Dictionary = b.P[c[0]]
					var pb: Dictionary = b.P[c[1]]
					var d: Vector2 = pb.p - pa.p
					var l := maxf(d.length(), 0.001)
					var adjust: float = (l - c[2]) / l / 2.0   # half the error to each end
					pa.p += d * adjust
					pb.p -= d * adjust
				b.P.handR.p = anchor                     # the pin wins every round
				for key in b.P:
					var p: Dictionary = b.P[key]
					if p.p.y > b.gy - 2.0:               # floor + friction
						p.p.y = b.gy - 2.0
						p.p.x -= (p.p.x - p.pp.x) * 0.4
					p.p.y = maxf(p.p.y, 4.0)
					p.p.x = clampf(p.p.x, 4.0, b.w - 4.0)
			b.anchor = anchor
		"knock":
			b.gust_t -= dt
			if b.gust_t <= 0.0:
				b.gust_t = randf_range(3.5, 5.5)
				_shock(b, Vector2(randf_range(0, b.w), b.gy - randf_range(0, 30)), 210.0)
			var G: float = b.h * 2.4
			for bx in b.boxes:
				for p in bx.p:
					var v: Vector2 = (p.p - p.pp) * 0.99
					p.pp = p.p
					p.p += v + Vector2(0, G * dt * dt)
				for it in 8:
					for c in bx.c:
						var pa: Dictionary = bx.p[c[0]]
						var pb: Dictionary = bx.p[c[1]]
						var d: Vector2 = pb.p - pa.p
						var l := maxf(d.length(), 0.001)
						var adjust: float = (l - c[2]) / l / 2.0
						pa.p += d * adjust
						pb.p -= d * adjust
					for p in bx.p:
						if p.p.y > b.gy - 1.0:
							p.p.y = b.gy - 1.0
							p.p.x -= (p.p.x - p.pp.x) * 0.55
						p.p.y = maxf(p.p.y, 4.0)
						p.p.x = clampf(p.p.x, 4.0, b.w - 4.0)
			for i in range(b.rings.size() - 1, -1, -1):
				var r: Dictionary = b.rings[i]
				r.r += 260.0 * dt
				r.a -= 2.2 * dt
				if r.a <= 0.0:
					b.rings.remove_at(i)
		"xmarks":
			b.sticky -= dt
			if b.sticky <= 0.0:
				b.want = t * 0.6                         # the idle sweep
			b.aim += wrapf(b.want - b.aim, -PI, PI) * minf(1.0, 8.0 * dt)
		"normals":
			b.wx += b.dir * 52.0 * dt
			if b.wx > b.w * 0.94:
				b.dir = -1.0
			if b.wx < b.w * 0.06:
				b.dir = 1.0
		"gait":
			b.auto_t += dt
			if b.auto_t > 5.0:
				b.auto_t = 0.0
				b.tx = b.w * 0.1 + randf() * b.w * 0.8
			var maxv: float = b.w * 0.36
			var want := clampf((b.tx - b.bx) * 2.0, -maxv, maxv)
			b.vx += (want - b.vx) * minf(1.0, 5.0 * dt)
			b.bx += b.vx * dt
			for i in 2:
				var home: float = b.bx + (13.0 if i == 1 else -13.0) + b.vx * 0.22   # led by velocity
				if b.stepping < 0 and absf(home - b.feet[i].x) > b.w * 0.1:
					b.stepping = i                       # step past the threshold —
					b.from = b.feet[i].x                 # but only one foot at a time
					b.k = 0.0
					b.to = home + b.vx * 0.1             # land a little ahead again
					b.dur = clampf(0.34 - absf(b.vx) / maxv * 0.16, 0.15, 0.34)   # stride timing
			if b.stepping >= 0:
				b.k += dt / b.dur
				var kk := clampf(b.k, 0.0, 1.0)
				var i: int = b.stepping
				var f: Vector2 = b.feet[i]
				f.x = b.from + (b.to - b.from) * smoothstep(0.0, 1.0, kk)
				f.y = b.gy - sin(kk * PI) * (8.0 + absf(b.vx) * 0.05)   # the parabolic arc
				if b.k >= 1.0:
					f.y = b.gy
					b.stepping = -1
				b.feet[i] = f

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	Kit.stage(n, b)
	var origin: Vector2 = (b.rect as Rect2).position
	match b.id:
		"ragdoll":
			Kit.ground(n, b)
			if b.has("anchor"):
				n.draw_line(Vector2(b.anchor.x, 0), b.anchor, Color(0.91, 0.898, 0.957, 0.25), 1.0)
			for c in b.C:
				n.draw_line(b.P[c[0]].p, b.P[c[1]].p, Kit.BONE, 3.0)
			Kit.dot(n, b.P.head.p, 6.5, Kit.MOVER)
			Kit.label(n, b, "position − last position IS the velocity", Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"knock":
			Kit.ground(n, b)
			for bx in b.boxes:
				var poly := PackedVector2Array([bx.p[0].p, bx.p[1].p, bx.p[2].p, bx.p[3].p])
				n.draw_colored_polygon(poly, Color(0.541, 0.851, 0.961, 0.14))
				n.draw_polyline(PackedVector2Array([bx.p[0].p, bx.p[1].p, bx.p[2].p, bx.p[3].p, bx.p[0].p]), Kit.BONE, 1.5)
			for r in b.rings:
				Kit.ring(n, r.p, r.r, Color(0.961, 0.541, 0.541, r.a * 0.8), 2.0)
			Kit.label(n, b, "impulse ∝ 1/distance — then constraints gossip", Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"xmarks":
			for s in _walls(b):
				n.draw_line(s[0], s[1], Kit.BONE, 2.0)
			var from := Vector2(b.w * 0.24, b.h * 0.68)
			var dir := Vector2(cos(b.aim), sin(b.aim))
			var hit := _cast(b, from, dir)
			if not hit.is_empty():
				n.draw_line(from, hit.p, Kit.HOT, 2.0)
				var refl: Vector2 = dir - 2.0 * dir.dot(hit.n) * hit.n   # v − 2(v·n)n
				var hit2 := _cast(b, hit.p + refl, refl)
				n.draw_line(hit.p, hit2.p if not hit2.is_empty() else hit.p + refl * 400.0,
					Color(0.961, 0.541, 0.541, 0.35), 2.0)
				Kit.arrow(n, hit.p, hit.p + hit.n * 22.0, Kit.GOOD)
				n.draw_line(hit.p + Vector2(-5, -5), hit.p + Vector2(5, 5), Kit.INK, 2.0)   # X marks
				n.draw_line(hit.p + Vector2(-5, 5), hit.p + Vector2(5, -5), Kit.INK, 2.0)   # the spot
			Kit.dot(n, from, 6.0, Kit.HOT)
			Kit.label(n, b, "nearest hit · green normal · faint bounce", Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"normals":
			var pts := PackedVector2Array()              # the hill itself
			var x := 0.0
			while x <= b.w:
				pts.append(Vector2(x, _terra(b, x)))
				x += 4.0
			n.draw_polyline(pts, Color(0.788, 0.769, 0.894, 0.55), 1.5)
			var fill := pts.duplicate()
			fill.append(Vector2(b.w, b.h))
			fill.append(Vector2(0, b.h))
			n.draw_colored_polygon(fill, Color(0.59, 0.57, 0.75, 0.13))
			var y := _terra(b, b.wx)
			var m := _slope(b, b.wx)
			var tl := sqrt(1.0 + m * m)
			var tang := Vector2(1.0, m) / tl             # unit tangent (1, m)
			var nrm := Vector2(m, -1.0) / tl             # turned 90°: (m, −1) — up
			Kit.arrow(n, Vector2(b.wx, y), Vector2(b.wx, y) + tang * 26.0 * b.dir, Kit.DIM)
			Kit.arrow(n, Vector2(b.wx, y), Vector2(b.wx, y) + nrm * 30.0, Kit.GOOD)
			Kit.mote(n, b, Vector2(b.wx, y) + nrm * 9.0, (tang * b.dir).angle())
			Kit.label(n, b, "tangent (1, m) · normal (m, −1) · m = the derivative", Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"gait":
			Kit.ground(n, b)
			var thigh: float = b.h * 0.17
			var planted: int = -1 if b.stepping < 0 else 1 - b.stepping
			var shift: float = 0.0 if planted < 0 else ((b.feet[planted] as Vector2).x - b.bx) * 0.35
			var hip_x: float = b.bx + shift              # weight over the standing foot
			var bob: float = 0.0 if b.stepping < 0 else sin(clampf(b.k, 0.0, 1.0) * PI) * 3.0
			var body_y: float = b.gy - b.h * 0.27 - bob
			var lean := clampf(b.vx * 0.0035, -0.3, 0.3)
			for i in 2:                                  # two-bone IK, straight from card I
				var hip := Vector2(hip_x + (5.0 if i == 1 else -5.0), body_y + 8.0)
				var f: Vector2 = b.feet[i]
				var to := f - hip
				var d := clampf(to.length(), 4.0, thigh * 2.0 - 2.0)
				var base := to.angle()
				var cos_a := clampf(d / (2.0 * thigh), -1.0, 1.0)   # equal bones simplify
				var knee_side: float = -1.0 if b.vx >= 0.0 else 1.0
				var a := base + acos(cos_a) * knee_side
				var knee := hip + Vector2(cos(a), sin(a)) * thigh
				n.draw_polyline(PackedVector2Array([hip, knee, f]), Kit.BONE, 3.5)
				Kit.dot(n, f + Vector2(0, -1.5), 3.0, Kit.BONE)
			n.draw_set_transform(origin + Vector2(hip_x, body_y), lean, Vector2.ONE)
			n.draw_circle(Vector2.ZERO, 12.0, Kit.MOVER)
			n.draw_circle(Vector2(4.5 if b.vx >= 0.0 else -4.5, -3.5), 2.4, Kit.NIGHT)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.ring(n, Vector2(b.tx, b.gy - 4.0), 5.0, Kit.TARGET, 1.5)
			Kit.label(n, b, "step past threshold · sin(k·π) arc · hips shift", Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
