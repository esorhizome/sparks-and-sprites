extends RefCounted

const Kit := preload("res://scenes/motion/kit.gd")
## CHAINS & JOINTS — four movement styles, ported from the web lexicon.
## A chain is points that promise to stay a fixed distance apart; inverse
## kinematics is any recipe that places the joints so the end lands on a
## target. Drag-follow (no solving), the Law of Cosines (exact), FABRIK
## (iterative, no trig) — plus quaternions, the 3D rotation maths.

const TITLE := "Chains & joints"
const BLURB := "limbs that reach and trail — inverse kinematics three ways"
const DEFS := [
	{ "id": "tentacle", "name": "T · Tentacle", "hint": "a follow-chain: the head leads, every link keeps its distance — press to point it" },
	{ "id": "ik", "name": "I · Ik", "hint": "two bones, one triangle, the Law of Cosines — press to re-aim and flip the elbow" },
	{ "id": "fabrik", "name": "F · Fabrik", "hint": "IK with no trigonometry: slide joints along lines, twice, done — press to set the target" },
	{ "id": "quaternion", "name": "Q · Quaternion", "hint": "slerp turns a cube the short way; lerping three angles wobbles — press for a new pose" },
]

const CUBE_EDGES := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]

static func _from_euler(e: Vector3) -> Quaternion:
	# build the SAME pose both ways: yaw about Y, pitch about X, roll about Z
	return Quaternion(Vector3.UP, e.x) * Quaternion(Vector3.RIGHT, e.y) * Quaternion(Vector3.BACK, e.z)

static func init(b: Dictionary) -> void:
	match b.id:
		"tentacle":
			b.segs = []
			for i in 18:
				b.segs.append(Vector2(b.w / 2.0 - i * 9.0, b.h / 2.0))
			b.tgt = Vector2(b.w * 0.7, b.h * 0.4)
			b.sticky = 0.0
		"ik":
			b.flip = 1.0
			b.tgt = Vector2.ZERO
			b.sticky = 0.0
		"fabrik":
			b.base = Vector2(b.w / 2.0, b.gy)
			b.pts = []
			for i in 4:
				b.pts.append(b.base - Vector2(0, i * b.h * 0.2))
			b.tgt = Vector2(b.w * 0.7, b.h * 0.3)
			b.sticky = 0.0
		"quaternion":
			b.ea = Vector3.ZERO
			b.eb = Vector3(randf_range(-2.2, 2.2), randf_range(-1.2, 1.2), randf_range(-2.2, 2.2))
			b.qa = Quaternion.IDENTITY
			b.qb = _from_euler(b.eb)
			b.k = 0.0
			b.rest_t = 0.0

static func _retarget(b: Dictionary) -> void:
	var kk: float = smoothstep(0.0, 1.0, minf(1.0, b.k))
	b.qa = (b.qa as Quaternion).slerp(b.qb, kk)          # freeze wherever we are
	b.ea = (b.ea as Vector3).lerp(b.eb, kk)
	b.eb = Vector3(randf_range(-2.4, 2.4), randf_range(-1.3, 1.3), randf_range(-2.4, 2.4))
	b.qb = _from_euler(b.eb)
	b.k = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"tentacle", "fabrik":
			b.tgt = pos
			b.sticky = 3.5
		"ik":
			b.tgt = pos
			b.sticky = 3.5
			b.flip = -b.flip
		"quaternion":
			_retarget(b)
			b.rest_t = 0.0

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"tentacle":
			b.sticky -= dt
			if b.sticky <= 0.0:                          # resume its own errand
				b.tgt = Vector2(b.w / 2.0 + cos(t * 0.6) * b.w * 0.34, b.h / 2.0 + sin(t * 0.9) * b.h * 0.3)
			b.segs[0] += (b.tgt - b.segs[0] as Vector2) * Kit.smooth(3.2, dt)   # the head leads
			for i in range(1, 18):
				var parent: Vector2 = b.segs[i - 1]
				var L := 10.0 - i * 0.28                 # links shorten toward the tail
				var a := (b.segs[i] - parent as Vector2).angle() + sin(t * 3.0 - i * 0.5) * 0.05
				b.segs[i] = parent + Vector2(cos(a), sin(a)) * L   # ← the whole constraint:
		"ik":                                            #   same direction, fixed length
			b.sticky -= dt
			var sh := Vector2(b.w * 0.34, b.h * 0.42)
			if b.sticky <= 0.0:
				b.tgt = sh + Vector2(cos(t * 0.7) * b.w * 0.34, sin(t * 1.1) * b.h * 0.28)
		"fabrik":
			b.sticky -= dt
			if b.sticky <= 0.0:
				b.tgt = b.base + Vector2(cos(t * 0.55) * b.w * 0.4, -b.h * 0.36 + sin(t * 0.85) * b.h * 0.3)
			var L: float = b.h * 0.2
			for it in 6:
				b.pts[3] = b.tgt                         # backward: hand on target...
				for i in [2, 1, 0]:                      # ...joints slide to bone length
					b.pts[i] = (b.pts[i + 1] as Vector2) + (b.pts[i] - b.pts[i + 1] as Vector2).normalized() * L
				b.pts[0] = b.base                        # forward: base back on its anchor
				for i in [1, 2, 3]:
					b.pts[i] = (b.pts[i - 1] as Vector2) + (b.pts[i] - b.pts[i - 1] as Vector2).normalized() * L
		"quaternion":
			if b.k >= 1.0:
				b.rest_t += dt
				if b.rest_t > 1.1:
					b.rest_t = 0.0
					_retarget(b)
			else:
				b.k = minf(1.0, b.k + dt / 1.5)

static func _draw_cube(n: CanvasItem, b: Dictionary, q: Quaternion, size: float, col: Color, lw: float) -> void:
	var c := Vector2(b.w / 2.0, b.h * 0.48)
	var pts := []
	for i in 8:
		var v := Vector3(1 if i & 1 else -1, 1 if i & 2 else -1, 1 if i & 4 else -1)
		var r := q * v                                   # rotate a point: q · v · q⁻¹
		var s := 4.2 / (4.2 + r.z) * size                # a whisper of perspective
		pts.append(c + Vector2(r.x, r.y) * s)
	for e in CUBE_EDGES:
		n.draw_line(pts[e[0]], pts[e[1]], col, lw)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	Kit.stage(n, b)
	match b.id:
		"tentacle":
			for i in range(17, -1, -1):
				var r: float = maxf(1.6, 8.5 - i * 0.42)
				var col := Kit.MOVER if i == 0 else Color(0.541, 0.851, 0.961, 0.8 - i * 0.038)
				Kit.dot(n, b.segs[i], r, col)
			var head: Vector2 = b.segs[0]
			var hd := (b.tgt - head as Vector2).angle()  # the eye watches the target
			Kit.dot(n, head + Vector2(cos(hd), sin(hd)) * 3.4, 2.0, Kit.NIGHT)
			Kit.dot(n, b.tgt, 3.0, Kit.TARGET)
			Kit.label(n, b, "each link: parent + (cos a, sin a) · length", Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"ik":
			var sh := Vector2(b.w * 0.34, b.h * 0.42)
			var a: float = b.h * 0.3
			var bo: float = b.h * 0.26
			var to: Vector2 = b.tgt - sh
			var reach := clampf(to.length(), absf(a - bo) + 2.0, a + bo - 2.0)   # stay solvable
			var base := to.angle()
			var cos_a := clampf((a * a + reach * reach - bo * bo) / (2.0 * a * reach), -1.0, 1.0)
			var ang: float = base + acos(cos_a) * b.flip # ← the Law of Cosines
			var elbow := sh + Vector2(cos(ang), sin(ang)) * a
			var hand := sh + Vector2(cos(base), sin(base)) * reach
			Kit.ring(n, sh, a + bo, Color(0.91, 0.898, 0.957, 0.08))   # the reach envelope
			n.draw_dashed_line(sh, hand, Kit.DIM, 1.0, 7.0)            # the triangle's third side
			n.draw_polyline(PackedVector2Array([sh, elbow, hand]), Kit.BONE, 6.0)
			Kit.dot(n, sh, 5.0, Kit.MOVER)
			Kit.dot(n, elbow, 4.5, Kit.BONE)
			Kit.dot(n, hand, 4.0, Kit.TARGET)
			Kit.label(n, b, "a", (sh + elbow) / 2.0 - Vector2(10, 0), Color(0.788, 0.769, 0.894, 0.8))
			Kit.label(n, b, "b", (elbow + hand) / 2.0 + Vector2(8, 0), Color(0.788, 0.769, 0.894, 0.8))
			Kit.label(n, b, "d", (sh + hand) / 2.0 + Vector2(6, 12), Kit.DIM)
			Kit.label(n, b, "cos A = (a² + d² − b²) / 2ad", Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"fabrik":
			Kit.ground(n, b)
			Kit.ring(n, b.base, b.h * 0.6, Color(0.91, 0.898, 0.957, 0.08))   # the reach circle
			for i in 3:
				n.draw_line(b.pts[i], b.pts[i + 1], Kit.BONE, 7.0 - i * 1.5)
			for i in 4:
				Kit.dot(n, b.pts[i], 4.5 - i * 0.5, Kit.MOVER if i == 0 else Kit.BONE)
			Kit.dot(n, b.tgt, 3.5, Kit.TARGET)
			Kit.label(n, b, "backward pass, forward pass — no angles", Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"quaternion":
			var kk: float = smoothstep(0.0, 1.0, b.k)
			var ge: Vector3 = (b.ea as Vector3).lerp(b.eb, kk)         # the naive route
			_draw_cube(n, b, _from_euler(ge), b.h * 0.16, Color(0.91, 0.898, 0.957, 0.2), 1.0)
			_draw_cube(n, b, (b.qa as Quaternion).slerp(b.qb, kk), b.h * 0.16, Kit.MOVER, 1.5)
			Kit.label(n, b, "bright: slerp(q1, q2)   faint: lerping yaw/pitch/roll", Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
