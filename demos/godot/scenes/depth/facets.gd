extends RefCounted
## FACETS & BLOCKS — 13 pictures, ported from the web atlas (docs/depth.js).
## Three flat shades meeting at an edge — that is a cube, and a cube is the
## whole isometric world. No gradient inside a face: the light is ONE
## direction (upper-left, always), so the top is lit, the left is the colour
## itself, the right is dark. Keep that rule across every block in the
## picture and the blocks share a world; draw the far ones first and they
## stack. Each picture is a list of faces and an order.
##
## Each def: letter, name, hint, dials (D), rhyme { name, hint, dials } and
## the callables init(b) / tick(b, dt) / press(b, pos) / draw(n, b). The
## rhyme's dials are merged over D on right-click — nothing else changes.

const K := preload("res://scenes/depth/kit.gd")

const TITLE := "Facets & blocks"
const BLURB := "three flat shades meeting at an edge — a cube from squares, and the whole isometric world"

## A small word pinned to a point (the web's positioned u.label).
static func _tag(n: CanvasItem, txt: String, x: float, y: float, col: Color) -> void:
	n.draw_string(ThemeDB.fallback_font, Vector2(x - 40.0, y), txt, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 9, col)

## Where p falls along the segment a → b, 0..1 — the web's two-stop lin() as a per-vertex number.
static func _along(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001: return 0.0
	return clampf((p - a).dot(ab) / l2, 0.0, 1.0)

## Clip a convex polygon to the half-plane x >= xa (keep = 1) or x <= xa (keep = -1).
static func _clip_x(pts: Array, xa: float, keep: int) -> Array:
	var out: Array = []
	var cnt := pts.size()
	for i in cnt:
		var p: Vector2 = pts[i]
		var q: Vector2 = pts[(i + 1) % cnt]
		var pin := (p.x - xa) * keep >= -0.0001
		var qin := (q.x - xa) * keep >= -0.0001
		if pin: out.append(p)
		if pin != qin:
			var k := (xa - p.x) / (q.x - p.x)
			out.append(p + (q - p) * k)
	return out

## A convex polygon filled with a multi-stop HORIZONTAL gradient from x0 to x1
## (the web's lin() over a triangle). Godot only interpolates per vertex, so the
## polygon is cut into one slab per stop pair — inside a slab the gradient IS linear.
static func _hgrad_poly(n: CanvasItem, pts: Array, x0: float, x1: float, stops: Array) -> void:
	for i in stops.size() - 1:
		var ka: float = stops[i][0]; var kb: float = stops[i + 1][0]
		if kb - ka < 0.0001: continue
		var xa := x0 + (x1 - x0) * ka
		var xb := x0 + (x1 - x0) * kb
		var slab := _clip_x(_clip_x(pts, xa, 1), xb, -1)
		if slab.size() < 3: continue
		var ca: Color = stops[i][1]; var cb: Color = stops[i + 1][1]
		var pv := PackedVector2Array(); var cv := PackedColorArray()
		for p in slab:
			pv.append(p)
			cv.append(ca.lerp(cb, clampf((p.x - xa) / (xb - xa), 0.0, 1.0)))
		K.lin_poly(n, pv, cv)

## Xylophone's long block by hand: (x, y) is its front corner, L along ix, wd along iy.
static func _bar(n: CanvasItem, x: float, y: float, L: float, wd: float, hz: float, s: float, c: Color, k_top: float) -> void:
	var lc := Vector2(x - L * 0.866 * s, y - L * 0.5 * s)
	var rc := Vector2(x + wd * 0.866 * s, y - wd * 0.5 * s)
	var bk := Vector2(lc.x + rc.x - x, lc.y + rc.y - y)
	K.poly(n, PackedVector2Array([Vector2(x, y), lc, Vector2(lc.x, lc.y - hz), Vector2(x, y - hz)]), c)                 # left face: the colour
	K.poly(n, PackedVector2Array([Vector2(x, y), rc, Vector2(rc.x, rc.y - hz), Vector2(x, y - hz)]), K.shade(c, -0.42))  # right end: dark
	K.poly(n, PackedVector2Array([Vector2(x, y - hz), Vector2(lc.x, lc.y - hz), Vector2(bk.x, bk.y - hz), Vector2(rc.x, rc.y - hz)]), K.shade(c, k_top))   # top: lit (or flashing)

## Keep / Ziggurat: a block under THIS picture's sun — mirrored when the sun is on the right.
static func _blk(n: CanvasItem, base: Vector2, s: float, c: Color, h: float, sun_l: bool) -> void:
	K.cube(n, base, s, c, h, null, c if sun_l else K.shade(c, -0.42), K.shade(c, -0.42) if sun_l else c)

static func defs() -> Array:
	var d: Array = []

	# ---- B · Block ---------------------------------------------------------
	d.append({ "letter": "B", "name": "Block",
		"hint": "one cube, three flat shades: top lit, left the colour itself, right dark — an edge is where two shades meet; press moves the light round",
		"dials": { "sky": [Color("1A1830"), Color("2A2848")], "floor": Color("1A1A2E"), "col": Color("6A8FD8"),
			"size": 0.22, "alpha": 1.0, "edge": 0.0,             # size = cube edge as a fraction of W; alpha = face opacity; edge = outline alpha (0 = none)
			"label": "three flat shades = a solid; no gradient inside a face, only at the edges between them" },
		"rhyme": { "name": "Glass block", "hint": "the same cube at half opacity with all twelve edges drawn — you see through it, and the three shades still make it a solid",
			"dials": { "col": Color("BFE6F5"), "alpha": 0.55, "edge": 0.7,
				"label": "half opacity and the edges drawn: see-through, and still a solid — the shades did the work, the outline just agrees" } },
		"init": func(b: Dictionary) -> void:
			b.lights = [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]   # upper-left, upper-right, lower-left, lower-right
			b.li = 0,
		"press": func(b: Dictionary, _pos: Vector2) -> void: b.li = (b.li + 1) % 4,   # walk the light round the four corners
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			K.sky(n, b, D.sky)
			var s: float = b.W * D.size
			var dx := 0.866 * s; var dy := 0.5 * s; var h := s
			var x: float = b.W / 2.0; var y: float = b.H * 0.8
			var L: Vector2 = b.lights[b.li]
			K.ground(n, b, y - dy * 2.4, D.floor)
			var k_top := 0.32 if L.y < 0 else 0.0                                   # light from above: the top is the lit face
			var k_l := (0.0 if L.y < 0 else 0.32) if L.x < 0 else -0.42             # the face toward the light is lit or mid...
			var k_r := (0.0 if L.y < 0 else 0.32) if L.x > 0 else -0.42             # ...the face away from it is dark
			var lp := Vector2(x + L.x * b.W * 0.36, y - h / 2.0 - dy / 2.0 + L.y * b.H * 0.28)   # the light itself, so you can see it move
			K.soft(n, lp, b.W * 0.1, Color("FFF3D0"), 0.7)
			K.shadow(n, Vector2(x - L.x * dx * 0.25, y - dy * 0.35), dx * 1.5, dy * 1.5, 0.5)   # contact shadow, nudged away from the light
			var a: float = D.alpha
			K.cube(n, Vector2(x, y), s, D.col, -1.0, K.alpha(K.shade(D.col, k_top), a), K.alpha(K.shade(D.col, k_l), a), K.alpha(K.shade(D.col, k_r), a))
			if D.edge > 0.0:                                                        # outlines: all twelve edges, the hidden three included
				var ink := K.alpha(K.INK, D.edge)
				var F := Vector2(x, y); var Lc := Vector2(x - dx, y - dy); var Rc := Vector2(x + dx, y - dy); var B := Vector2(x, y - 2.0 * dy)
				var up := Vector2(0, h)
				for e in [[F, Lc], [F, Rc], [Lc, B], [Rc, B]]:
					K.line(n, e[0], e[1], ink); K.line(n, e[0] - up, e[1] - up, ink)
				for v in [F, Lc, Rc, B]: K.line(n, v, v - up, ink)
			var nm := func(k: float) -> String: return "lit" if k > 0.1 else ("dark" if k < -0.1 else "mid")
			var tc := K.alpha(K.INK, 0.85)
			_tag(n, nm.call(k_top), x, y - h - dy + 3.0, tc)
			_tag(n, nm.call(k_l), x - dx / 2.0, y - dy / 2.0 - h / 2.0 + 3.0, tc)
			_tag(n, nm.call(k_r), x + dx / 2.0, y - dy / 2.0 - h / 2.0 + 3.0, tc)
			K.label(n, b, D.label) })

	# ---- G · Gem -----------------------------------------------------------
	d.append({ "letter": "G", "name": "Gem",
		"hint": "a faceted stone: each triangle is one flat shade set by how squarely it faces the light — the stone turns and the shades walk round it; press to nudge it and it spins up, then coasts back down",
		"dials": { "sky": [Color("0E0C1E"), Color("1E1A36")], "col": Color("5AC8E8"), "spin": 0.7,
			"sides": 6, "crown": 0.45, "pav": 1.1,               # crown/pav = the point above / below the rim, in radii
			"kick": 3.0, "drag": 1.2,                            # kick = angular velocity a full-width press adds, rad/s; drag = how fast that nudge coasts down, per second
			"bob": 8.0, "bobdamp": 0.08,                         # bob = the float's spring stiffness; bobdamp = its damping as a fraction of critical (tiny: it keeps bobbing)
			"label": "shade = how squarely the face meets the light — turning changes nothing but that; the turn is a rate a nudge adds to and drag wears down" },
		"rhyme": { "name": "Ruby cut", "hint": "the same stone in red, turning three times as fast — the facets flicker past the light instead of drifting; a nudge still spins it up and coasts down",
			"dials": { "sky": [Color("1A0810"), Color("2E1020")], "col": Color("E0305A"), "spin": 1.4,
				"label": "a red palette and a faster turn — the same triangles; only the dot product with the light moves, and a nudge coasts down the same way" } },
		"init": func(b: Dictionary) -> void:
			# the stone turns at its idle rate (spin) plus whatever a nudge left it:
			# a press adds angular VELOCITY, not an angle, and drag eats a share of
			# it every step, so the stone spins up and coasts back down to its idle
			# turn instead of jumping. the float is a spring around a rest height,
			# damped far under critical, so it bobs for a long while and a press
			# bumps it — nothing here is a sine of the clock.
			b.ang = 0.0; b.angv = 0.0                                                # the turn, and the nudge's leftover rate
			b.bob = 0.0; b.bobv = 0.5,                                               # the float (in radii) and its rate
		"tick": func(b: Dictionary, dt: float) -> void:
			var D: Dictionary = b.D
			var sub := maxi(1, ceili(dt * 50.0))                                     # a coarse frame is cut into substeps of at most 0.02 s: one step at 60 fps
			var h := dt / float(sub)
			var spin: float = D.spin; var drag: float = D.drag
			var bk: float = D.bob; var bd: float = float(D.bobdamp) * 2.0 * sqrt(bk)   # the float's damping, from its fraction of critical
			var ang: float = b.ang; var angv: float = b.angv; var bob: float = b.bob; var bobv: float = b.bobv
			for _s in sub:
				angv -= angv * drag * h; ang += (spin + angv) * h                     # idle rate + the nudge, which drag wears away
				bobv += (-bk * bob - bd * bobv) * h; bob = clampf(bob + bobv * h, -0.3, 0.3)
			b.ang = fposmod(ang, TAU); b.angv = angv; b.bob = bob; b.bobv = bobv,
		"press": func(b: Dictionary, pos: Vector2) -> void: b.angv += (pos.x / b.W - 0.5) * 2.0 * float(b.D.kick); b.bobv -= 0.6,   # a nudge: angular velocity, left or right of centre — and a bump to the float
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			K.sky(n, b, D.sky)
			var LT := Vector3(-0.5, 0.75, 0.45).normalized()                        # the light: upper-left, a little toward us
			var r: float = minf(b.W, b.H) * 0.26
			var cx: float = b.W / 2.0; var cy: float = b.H * 0.46 + float(b.bob) * r * 0.4
			var ang: float = b.ang
			var sides: int = D.sides
			var rim: Array = []
			for i in sides:
				var q := ang + float(i) / sides * TAU
				rim.append(Vector3(cos(q), 0.0, sin(q)))
			var F: Array = []                                                       # rebuild the triangles for this rotation
			for j in sides:
				F.append({ "p": [Vector3(0, D.crown, 0), rim[j], rim[(j + 1) % sides]] })     # crown: rim to the top point
				F.append({ "p": [Vector3(0, -D.pav, 0), rim[(j + 1) % sides], rim[j]] })     # pavilion: rim to the bottom point
			var cz: float = (D.crown - D.pav) / 2.0
			var best: Dictionary = {}
			for f in F:
				var p0: Vector3 = f.p[0]; var p1: Vector3 = f.p[1]; var p2: Vector3 = f.p[2]
				var nrm := (p1 - p0).cross(p2 - p0)
				if nrm.length() > 0.0: nrm = nrm.normalized()
				var g := (p0 + p1 + p2) / 3.0
				if nrm.dot(Vector3(g.x, g.y - cz, g.z)) < 0.0: nrm = -nrm            # the normal must point OUT of the stone
				f.k = nrm.dot(LT)                                                   # −1..1: how squarely this facet faces the light
				f.z = g.z
				if best.is_empty() or f.k > best.k: best = f
			F.sort_custom(func(A, B): return A.z < B.z)                             # far facets first — painter's order
			K.shadow(n, Vector2(cx, cy + r * D.pav * 0.85 + r * 0.2), r * 0.8, r * 0.22, 0.4)
			for q in F:
				var pts := PackedVector2Array()
				for j in 3:
					var v: Vector3 = q.p[j]
					pts.append(Vector2(cx + v.x * r, cy - v.y * r * 0.8 + v.z * r * 0.35))   # tilted: we look down a little
				K.poly(n, pts, K.shade(D.col, q.k * 0.5))
			if best.k > 0.8:                                                        # the facet squarest to the light sparkles
				var gb: Vector3 = (best.p[0] + best.p[1] + best.p[2]) / 3.0
				K.soft(n, Vector2(cx + gb.x * r, cy - gb.y * r * 0.8 + best.z * r * 0.35), r * 0.4, Color.WHITE, (best.k - 0.8) * 3.0)
			K.label(n, b, D.label) })

	# ---- H · Hexprism ------------------------------------------------------
	d.append({ "letter": "H", "name": "Hexprism",
		"hint": "a six-sided column: the hexagon top is the lit shade, each visible side a shade set by which way it faces — press turns it 60°: it swings past, rocks back, and the shades walk round",
		"dials": { "sky": [Color("141226"), Color("26223E")], "floor": Color("1A1A2C"), "cols": [Color("B87A5A")],
			"count": 1, "h": 0.5, "r": 0.16, "every": 2.0,       # count of prisms; h and r as fractions of H and W; every = seconds between idle turns
			"k": 64.0, "zeta": 0.4,                              # k = the turn's spring stiffness for a column of height h (taller = heavier = softer); zeta = damping as a fraction of critical — under 1, so it turns past the detent and rocks back
			"label": "one rule for every side — shade by the way it faces — and the top stays lit whatever the turn; the turn is a spring to a detent, so it overshoots" },
		"rhyme": { "name": "Basalt columns", "hint": "five grey columns of different heights, side by side, all sent round together — the tall ones lag and rock longer, so they settle on their own phases: a rock shelf from one rule",
			"dials": { "cols": [Color("4A4A52"), Color("5A5A62"), Color("3E3E46")], "count": 5, "h": 0.42,
				"label": "five columns, different heights, one light and one detent — the grey rule is still a rule, and each column swings to it at its own pace" } },
		"init": func(b: Dictionary) -> void:
			# a press moves the DETENT — the angle the column wants — on by 60°. the
			# column itself has an angular velocity and a spring toward the detent,
			# damped under critical, so it swings past, rocks back and settles rather
			# than easing in. every column keeps its own angle and rate, and a taller
			# column is a heavier one (a softer spring per height), so the rhyme's
			# five columns share one detent and arrive on their own phases.
			var D: Dictionary = b.D
			var R := K.rng(7)
			var cnt: int = D.count
			var cols: Array = D.cols
			b.prisms = []
			for i in cnt:
				b.prisms.append({ "x": (i + 0.5) / cnt, "h": D.h * ((0.55 + R.randf() * 0.7) if cnt > 1 else 1.0), "c": cols[i % cols.size()] })
			var turn := PackedFloat32Array()              # sized here: a packed array read back from b is a copy
			var om := PackedFloat32Array()
			turn.resize(cnt)
			om.resize(cnt)
			b.turn = turn; b.om = om                                                 # each column's angle and angular velocity
			b.target = 0.0; b.next_at = D.every,                                     # the shared detent
		"tick": func(b: Dictionary, dt: float) -> void:
			var D: Dictionary = b.D
			if b.t > b.next_at: b.target += TAU / 6.0; b.next_at = b.t + D.every      # the idle turn: the detent moves on
			var sub := maxi(1, ceili(dt * 50.0))                                     # a coarse frame is cut into substeps of at most 0.02 s: one step at 60 fps
			var h := dt / float(sub)
			var turn: PackedFloat32Array = b.turn
			var om: PackedFloat32Array = b.om
			var k0: float = D.k; var zeta: float = D.zeta; var h0: float = D.h; var target: float = b.target
			var prisms: Array = b.prisms
			for p in prisms.size():
				var kp := k0 * h0 / float(prisms[p].h)                                # a taller column: more inertia, so a softer spring...
				var dp := zeta * 2.0 * sqrt(kp)                                        # ...and its own critical damping
				for _s in sub:
					om[p] += (kp * (target - turn[p]) - dp * om[p]) * h
					turn[p] += om[p] * h,
		"press": func(b: Dictionary, _pos: Vector2) -> void: b.target += TAU / 6.0; b.next_at += b.D.every,   # one more sixth of a turn: the detent moves, the spring does the rest
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			K.sky(n, b, D.sky)
			var gy: float = b.H * 0.82
			K.ground(n, b, gy - b.H * 0.22, D.floor)
			var cnt: int = D.count
			var turns: PackedFloat32Array = b.turn
			var pidx := 0
			for P in b.prisms:
				var turn: float = turns[pidx]; pidx += 1
				var cx: float = b.W * P.x
				var r: float = b.W * D.r / ((sqrt(cnt) * 0.8) if cnt > 1 else 1.0)
				var h: float = b.H * P.h
				var pc: Color = P.c
				K.shadow(n, Vector2(cx + r * 0.35, gy), r * 1.4, r * 0.6, 0.45)
				var v: Array = []
				for i in 6:
					var q := turn + i * TAU / 6.0
					v.append(Vector2(cx + cos(q) * r, gy + sin(q) * r * 0.5))
				for j in 6:
					var A: Vector2 = v[j]; var B: Vector2 = v[(j + 1) % 6]
					var mid := turn + (j + 0.5) * TAU / 6.0                           # the direction this side faces
					if sin(mid) <= 0.0: continue                                       # it faces away from us
					K.poly(n, PackedVector2Array([A, B, Vector2(B.x, B.y - h), Vector2(A.x, A.y - h)]), K.shade(pc, -0.21 - 0.21 * cos(mid)))   # facing left = the colour, facing right = dark
				var top := PackedVector2Array()
				for k in 6: top.append(Vector2(v[k].x, v[k].y - h))
				K.poly(n, top, K.shade(pc, 0.32))
			K.label(n, b, D.label) })

	# ---- I · Isotile -------------------------------------------------------
	d.append({ "letter": "I", "name": "Isotile", "drag": true,
		"hint": "an isometric floor: diamonds in two alternating colours with a darker line on their right and bottom edges — and a ball whose shadow never leaves the floor; click and it rolls there, a little past, and settles",
		"dials": { "sky": [Color("141226"), Color("221E3A")], "a": Color("6A8ACF"), "b": Color("8AA6DF"), "edge": -0.45, "ball": Color("F58A8A"),
			"n": 8, "speed": 0.6, "glow": 0.0,                   # n tiles a side; glow = a warm torch tint over the floor (0 = none)
			"k": 36.0, "zeta": 0.5,                              # k = the pull toward where the ball is going; zeta = damping as a fraction of critical — under 1, so it rolls a little past and settles back
			"label": "two colours and a dark right-and-bottom edge make a floor; the shadow glues the ball to it — the ball is a spring toward its aim, so it overshoots" },
		"rhyme": { "name": "Dungeon floor", "hint": "the same floor in dark stone under a torch — a warm glow laid over the tiles, the edge lines cut deeper; the ball still rolls past its mark and settles",
			"dials": { "sky": [Color("0A0812"), Color("161222")], "a": Color("3A3640"), "b": Color("4A4650"), "edge": -0.6, "ball": Color("9BE28A"), "glow": 0.35,
				"label": "dark stone under a torch: the warm tint sits on top of the tiles, and the edge lines still say 'floor' — the ball's spring is the same" } },
		"init": func(b: Dictionary) -> void:
			# the ball has a velocity: a spring pulls it toward its aim (a click, or
			# the idle circle) and damping under critical lets it roll a little past
			# and come back — it arrives like a ball, not like a cursor. the shadow is
			# drawn at the ball's grid position on the floor whatever the ball does,
			# which is the lesson.
			b.ball = Vector2(4, 4); b.vel = Vector2.ZERO; b.target = null,           # grid position, grid velocity (cells per second), the clicked aim
		"tick": func(b: Dictionary, dt: float) -> void:
			var D: Dictionary = b.D
			var nn: float = D.n
			var aim := Vector2(nn / 2.0 + 2.6 * cos(b.t * D.speed), nn / 2.0 + 2.6 * sin(b.t * D.speed))   # the idle path: a circle
			var ball: Vector2 = b.ball; var vel: Vector2 = b.vel
			if b.target != null:
				aim = b.target
				if absf(aim.x - ball.x) + absf(aim.y - ball.y) < 0.05 and absf(vel.x) + absf(vel.y) < 0.3: b.target = null   # there, and at rest: back to the idle path
			var k: float = D.k; var damp: float = float(D.zeta) * 2.0 * sqrt(k)     # damping from its fraction of critical
			var sub := maxi(1, ceili(dt * 50.0))                                     # a coarse frame is cut into substeps of at most 0.02 s: one step at 60 fps
			var h := dt / float(sub)
			var lo := Vector2(0.3, 0.3); var hi := Vector2(nn - 0.3, nn - 0.3)     # the floor has an edge
			for _s in sub:
				vel += (k * (aim - ball) - damp * vel) * h
				ball = (ball + vel * h).clamp(lo, hi)
			b.ball = ball; b.vel = vel,
		"press": func(b: Dictionary, pos: Vector2) -> void:                          # click = roll the ball there (screen → iso grid): the aim moves, the spring does the rolling
			var s: float = minf(b.W * 0.065, b.H * 0.1)
			var sx: float = pos.x - b.W / 2.0; var sy: float = pos.y - b.H * 0.12
			var nn: float = b.D.n
			b.target = Vector2(clampf((sx / (0.866 * s) + 2.0 * sy / s) / 2.0, 0.5, nn - 0.5), clampf((2.0 * sy / s - sx / (0.866 * s)) / 2.0, 0.5, nn - 0.5)),
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			K.sky(n, b, D.sky)
			var s: float = minf(b.W * 0.065, b.H * 0.1)
			var o := Vector2(b.W / 2.0, b.H * 0.12)
			var nn: int = D.n
			for iy in nn:
				for ix in nn:
					var c: Color = D.a if (ix + iy) % 2 == 1 else D.b
					var q0 := o + K.iso(ix, iy, 0.0, s); var q1 := o + K.iso(ix + 1, iy, 0.0, s)
					var q2 := o + K.iso(ix + 1, iy + 1, 0.0, s); var q3 := o + K.iso(ix, iy + 1, 0.0, s)
					K.poly(n, PackedVector2Array([q0, q1, q2, q3]), c)
					K.line(n, q1, q2, K.shade(c, D.edge), 1.0)                          # the right edge and the bottom edge, darker:
					K.line(n, q3, q2, K.shade(c, D.edge), 1.0)                          # a tile has a tiny thickness, and it faces the same light
			if D.glow > 0.0: K.soft(n, Vector2(o.x, o.y + s * nn * 0.5), s * nn * 0.75, Color("F5A15A"), D.glow)
			var ball: Vector2 = b.ball
			var g := o + K.iso(ball.x, ball.y, 0.0, s)
			var rb := s * 0.45
			K.shadow(n, g, rb * 1.15, rb * 0.55, 0.5)                                 # the shadow sits ON the floor: that is what keeps the ball on it
			K.sphere(n, Vector2(g.x, g.y - rb), rb, D.ball, -0.5, -0.6, 0.5)
			K.label(n, b, D.label) })

	# ---- K · Keep ----------------------------------------------------------
	d.append({ "letter": "K", "name": "Keep", "drag": true,
		"hint": "a castle tower from stacked blocks: one tall block, small blocks for the battlements, a dark doorway — every face obeys the same light, so it is one building; press a side and the wind turns: the flag falls slack and whips round",
		"dials": { "sky": [Color("2A3A6A"), Color("8AA0C8")], "floor": Color("3A5A3A"), "stone": Color("9A8E86"), "flag": Color("F58A8A"),
			"h": 2.4, "wind": 1.0,                               # h = tower height in widths; wind = the wind asked for: sign = direction, size = strength
			"k": 50.0, "zeta": 0.35, "lag": 2.5, "droop": 0.25, "flap": 0.12,   # k = the flag tip's stiffness; zeta = damping as a fraction of critical (under 1: it whips past); lag = how fast the wind at the flag catches up with the dial, per second; droop = gravity's pull on the tip against a unit wind; flap = the flutter, radians per unit wind
			"label": "one sun for every block — tower, battlements, annex all agree on the dark side, so they are one building; the flag is a spring on a lagging wind" },
		"rhyme": { "name": "Sci-fi silo", "hint": "the same tower in steel blue, half again as tall, with a cyan beacon for a flag — a launch silo from castle parts; the beacon still drops slack and whips round when the wind turns",
			"dials": { "sky": [Color("0A0F2A"), Color("2A3A6A")], "floor": Color("1A2030"), "stone": Color("7A9AB8"), "flag": Color("40F0F0"),
				"h": 3.4, "wind": -1.0,
				"label": "steel blue and taller, the flag a beacon — the light rule did not change, so it is still one building; the same spring on the same lagging wind" } },
		"init": func(b: Dictionary) -> void:
			# the flag is one angle at its tip. the wind the flag feels chases the
			# wind you asked for (a lag, not a switch), and the tip is a spring toward
			# the angle wind and gravity agree on — straight downwind, drooping a
			# little. flip the wind and that rest angle walks through 'hanging
			# straight down' as the lagging wind passes zero, and the under-damped tip
			# whips through the slack after it: a flag turning round, not a flag
			# mirrored. the flutter is a small forcing on the same spring, quicker
			# in more wind.
			b.sun_l = true
			b.w = float(b.D.wind)                                                    # the wind at the flag: it lags the dial
			b.th = atan2(float(b.D.droop), float(b.D.wind)); b.om = 0.0,             # the tip's angle from the pole (0 = streaming right, π/2 = hanging, π = streaming left) and its rate
		"tick": func(b: Dictionary, dt: float) -> void:
			var D: Dictionary = b.D
			var sub := maxi(1, ceili(dt * 50.0))                                     # a coarse frame is cut into substeps of at most 0.02 s: one step at 60 fps
			var h := dt / float(sub)
			var k: float = D.k; var damp: float = float(D.zeta) * 2.0 * sqrt(k)     # damping from its fraction of critical
			var lag: float = D.lag; var droop: float = D.droop; var flap: float = D.flap; var want: float = D.wind
			var w: float = b.w; var th: float = b.th; var om: float = b.om; var t: float = b.t
			for _s in sub:
				w += (want - w) * lag * h                                             # the wind at the flag catches up with the dial
				var rest := atan2(droop, w) + sin(t * 9.0 * absf(w)) * flap * absf(w)   # downwind and a little down (π/2 when the wind is nil), plus the flutter
				om += (k * (rest - th) - damp * om) * h
				th = clampf(th + om * h, -0.8, PI + 0.8)
			b.w = w; b.th = th; b.om = om,
		"press": func(b: Dictionary, pos: Vector2) -> void:                          # click a side = the sun (and the wind) come from there; the flag finds out through the lag
			b.sun_l = pos.x < b.W / 2.0
			b.D.wind = (1.0 if pos.x < b.W / 2.0 else -1.0) * absf(b.D.wind),
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var sun_l: bool = b.sun_l
			K.sky(n, b, D.sky)
			var s: float = minf(b.W * 0.16, b.H * 0.11)
			var dx := 0.866 * s; var dy := 0.5 * s; var h: float = s * D.h
			var x: float = b.W / 2.0; var y: float = b.H * 0.84; var m := s / 5.0
			K.ground(n, b, y - dy * 2.6, D.floor)
			K.soft(n, Vector2(b.W * 0.1 if sun_l else b.W * 0.9, b.H * 0.12), b.W * 0.14, Color("FFF3D0"), 0.8)
			K.shadow(n, Vector2(x + (1.0 if sun_l else -1.0) * dx * 0.9, y - dy * 0.5), dx * 2.4, dy * 1.5, 0.4)
			_blk(n, Vector2(x - dx * 1.3, y - dy * 0.9), s * 0.7, D.stone, s * 0.8, sun_l)   # an annex, behind-left — drawn first
			_blk(n, Vector2(x, y), s, D.stone, h, sun_l)                                    # the tower
			var f1 := 0.36; var f2 := 0.64; var dh := s * 0.55                              # the doorway, on the left face
			K.poly(n, PackedVector2Array([Vector2(x - dx * f1, y - dy * f1), Vector2(x - dx * f2, y - dy * f2),
				Vector2(x - dx * f2, y - dy * f2 - dh), Vector2(x - dx * f1, y - dy * f1 - dh)]), Color("0E0B1A"))
			var o := Vector2(x, y - h - 2.0 * dy)                                           # the top face's back corner: origin for the battlements
			var cells := [[0, 0], [0, 2], [2, 0], [0, 4], [4, 0], [2, 4], [4, 2], [4, 4]]   # rim cells of a 5×5 top, already sorted back → front
			for c in cells: _blk(n, o + K.iso(c[0] + 1, c[1] + 1, 0.0, m), m, D.stone, m * 1.2, sun_l)
			var px := x; var py := y - h - dy; var ph := s * 0.9                              # the flag pole, on the top's centre
			K.line(n, Vector2(px, py), Vector2(px, py - ph), Color("3A3040"), 1.5)
			var th: float = b.th
			K.poly(n, PackedVector2Array([Vector2(px, py - ph), Vector2(px + cos(th) * s * 0.52, py - ph + sin(th) * s * 0.52), Vector2(px, py - ph + s * 0.32)]), D.flag)   # the flag: pole top, the tip at its angle, the pole a little down
			K.label(n, b, D.label) })

	# ---- P · Pyramid -------------------------------------------------------
	d.append({ "letter": "P", "name": "Pyramid", "drag": true,
		"hint": "two triangles, one lit and one dark, plus a shadow stretched along the ground away from the light — press moves the sun and both swap",
		"dials": { "sky": [Color("3A6FD0"), Color("C8DCF0")], "sand": Color("D9A86A"), "col": Color("D9A86A"),
			"size": 0.19, "h": 1.1, "shadowA": 0.42,             # size = one footprint edge in W; h = apex height in edges; shadowA = how dark the shadow
			"label": "the shadow points away from the light, the lit face points toward it — two cues the eye checks against each other" },
		"rhyme": { "name": "Snow pyramid", "hint": "the same pyramid in white on white — a paler shadow, faces that barely differ — a low-contrast world with the same two cues",
			"dials": { "sky": [Color("8AB0E0"), Color("E8F0F8")], "sand": Color("E8F0F8"), "col": Color("DDE8F5"), "shadowA": 0.25,
				"label": "white on white: the shadow is paler and the faces nearly match — less contrast, the same two cues" } },
		"init": func(b: Dictionary) -> void: b.lx = -0.7; b.ly = -0.6,              # the sun: −1..1 across the picture, −1 high … 0.4 low
		"press": func(b: Dictionary, pos: Vector2) -> void:                          # put the sun where you click
			b.lx = clampf((pos.x / b.W - 0.5) * 2.0, -1.0, 1.0); b.ly = clampf((pos.y / b.H - 0.4) * 2.0, -1.0, 0.4),
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var lx: float = b.lx; var ly: float = b.ly
			K.sky(n, b, D.sky)
			var s: float = b.W * D.size
			var dx := 0.866 * s; var dy := 0.5 * s; var h: float = s * D.h
			var x: float = b.W / 2.0; var y: float = b.H * 0.8
			var F := Vector2(x, y); var L := Vector2(x - dx, y - dy); var R := Vector2(x + dx, y - dy)
			var B := Vector2(x, y - 2.0 * dy); var A := Vector2(x, y - dy - h)
			K.ground(n, b, y - dy * 2.6, D.sand)
			var sun := Vector2(b.W / 2.0 + lx * b.W * 0.45, b.H * 0.3 + ly * b.H * 0.25)
			K.soft(n, sun, b.W * 0.16, Color("FFF3D0"), 0.85)
			var v := Vector2(x, y - dy) - sun                                           # from the sun through the pyramid
			var vl := v.length() if v.length() > 0.0 else 1.0
			var ln := h * (1.2 + ly * 0.9)                                              # a low sun throws a long shadow; ground squashes y by half
			var S := Vector2(x + v.x / vl * ln, y - dy + v.y / vl * ln * 0.5)
			var shade := K.mix(D.sand, Color.BLACK, D.shadowA)
			var base := [F, L, B, R]
			for i in 4: K.poly(n, PackedVector2Array([base[i], base[(i + 1) % 4], S]), shade)   # a fan of opaque triangles = the shadow's hull
			K.poly(n, PackedVector2Array(base), shade)
			var kl := lerpf(0.28, -0.42, (lx + 1.0) / 2.0) - ly * 0.06                 # the face toward the sun is lit
			var kr := lerpf(-0.42, 0.28, (lx + 1.0) / 2.0) - ly * 0.06
			K.poly(n, PackedVector2Array([L, F, A]), K.shade(D.col, kl))
			K.poly(n, PackedVector2Array([F, R, A]), K.shade(D.col, kr))
			K.label(n, b, D.label) })

	# ---- Q · Quilt ---------------------------------------------------------
	d.append({ "letter": "Q", "name": "Quilt",
		"hint": "a patchwork of bumps and dents: a bump is a low block; a dent is the SAME three shades with left and right swapped — press to move the ripple",
		"dials": { "sky": [Color("1A1430"), Color("2C2448")], "col": Color("C88AA0"),
			"n": 6, "amp": 0.45, "speed": 1.2, "flat": 0.15,     # amp = bump height in tile widths; speed of the ripple; flat = dead band where a tile stays level
			"label": "swap the shades and the bump becomes a dent — the eye only knows the light comes from the upper-left" },
		"rhyme": { "name": "Circuit board", "hint": "the same patchwork in green, rippling three times as fast with a wide dead band — fewer, sharper bumps read as chips on a board",
			"dials": { "sky": [Color("061A10"), Color("0C2818")], "col": Color("3A9A5A"), "amp": 0.3, "speed": 3.0, "flat": 0.35,
				"label": "green and quick with a wide dead band — the same swapped shades, now reading as chips and sockets" } },
		"init": func(b: Dictionary) -> void: b.org = Vector2(b.D.n / 2.0, b.D.n / 2.0),
		"press": func(b: Dictionary, pos: Vector2) -> void:                          # click = the ripple starts here (screen → iso grid)
			var nn: float = b.D.n
			var s: float = minf(b.W * 0.08, b.H * 0.1)
			var sx: float = pos.x - b.W / 2.0; var sy: float = pos.y - (b.H * 0.5 - s * nn * 0.5 + s * 0.2)
			b.org = Vector2(clampf((sx / (0.866 * s) + 2.0 * sy / s) / 2.0, 0.0, nn), clampf((2.0 * sy / s - sx / (0.866 * s)) / 2.0, 0.0, nn)),
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			K.sky(n, b, D.sky)
			var nn: int = D.n
			var s: float = minf(b.W * 0.08, b.H * 0.1)
			var o := Vector2(b.W / 2.0, b.H * 0.5 - s * nn * 0.5 + s * 0.2)
			var top := K.shade(D.col, 0.32); var mid: Color = D.col; var dark := K.shade(D.col, -0.42)
			var org: Vector2 = b.org
			for sum in 2 * (nn - 1) + 1:                                                # painter's order: back rows (small ix+iy) first
				for ix in nn:
					var iy := sum - ix
					if iy < 0 or iy >= nn: continue
					var dd := Vector2(ix + 0.5 - org.x, iy + 0.5 - org.y).length()
					var z := sin(dd * 1.3 - t * D.speed)                                 # −1..1: the ripple
					var B := o + K.iso(ix, iy, 0.0, s); var Lc := o + K.iso(ix, iy + 1, 0.0, s)
					var Rc := o + K.iso(ix + 1, iy, 0.0, s); var F := o + K.iso(ix + 1, iy + 1, 0.0, s)
					if z > D.flat:
						K.cube(n, F, s, D.col, (z - D.flat) * s * D.amp)                  # a bump: a low block, lit top, mid left, dark right
					elif z < -D.flat:                                                    # a dent: the two back walls, then the sunken floor
						var dp: float = (-z - D.flat) * s * D.amp
						var dn := Vector2(0, dp)
						K.poly(n, PackedVector2Array([B, Lc, Lc + dn, B + dn]), dark)     # the back-left wall faces right → dark
						K.poly(n, PackedVector2Array([B, Rc, Rc + dn, B + dn]), mid)      # the back-right wall faces left → mid
						K.poly(n, PackedVector2Array([B + dn, Lc + dn, F + dn, Rc + dn]), top)
					else:
						K.poly(n, PackedVector2Array([B, Lc, F, Rc]), top)                 # level: just the lit shade
			K.label(n, b, D.label) })

	# ---- S · Stairs --------------------------------------------------------
	d.append({ "letter": "S", "name": "Stairs",
		"hint": "blocks of climbing height drawn left to right: lit tops, mid sides, dark ends — and a ball hopping down step by step under gravity: it lands, squashes, bounces once, and its shadow lands on each step with it",
		"dials": { "sky": [Color("1A1E36"), Color("3A3F60")], "floor": Color("1A1A2C"), "cols": [Color("8A8FA8")], "ball": Color("F5C169"),
			"n": 7, "rise": 0.55, "hop": 0.55, "tempo": 1.6,     # rise (keep ≥ 0.5 so each step hides the last one's end) and hop in step widths; tempo = hops per second, near enough — it sets the gravity, and the bounces add a little
			"bounce": 0.35, "squash": 0.3, "dwell": 0.12, "rest": 1.0,   # bounce = restitution: the share of the landing speed that comes back up; squash = how flat a full landing presses the ball, of its radius; dwell = seconds it sits before the next hop; rest = seconds at the bottom before it starts over
			"label": "seven blocks that agree about the light, drawn back to front — the shadow says which step the ball is over; the ball: gravity, a floor, restitution" },
		"rhyme": { "name": "Candy stairs", "hint": "the same staircase in four pastels with a ball that hops twice as high and faster — it lands harder, so it squashes and bounces more, and the shadow shrinks more, so the bounce reads taller",
			"dials": { "sky": [Color("F5D0E0"), Color("F5E8F0")], "floor": Color("E8C8D8"), "cols": [Color("F5A0B8"), Color("A0D8F5"), Color("F5E0A0"), Color("B8F0B0")],
				"ball": Color("C9A0F5"), "hop": 1.2, "tempo": 2.2,
				"label": "pastel steps, a higher hop — the shadow shrinks more when the ball is higher, so the bounce reads taller; a harder landing, a deeper squash" } },
		"init": func(b: Dictionary) -> void:
			# the ball is a body: gravity pulls it down every step, and a step top is a
			# floor — when it arrives moving down it bounces with restitution (a share
			# of the speed comes back up, most is lost) until the bounce is too small
			# to matter, then it sits a moment and launches the next hop: an upward
			# speed for the hop height it wants, and just enough sideways to land on
			# the next step's middle. gravity is chosen from the tempo so a hop takes
			# about a beat. a landing also kicks a stiff, quick squash spring (a cycle
			# of about 150 ms) that flattens the ball and lets it ring back round.
			var D: Dictionary = b.D
			b.ix = float(D.n) - 1.0 + 0.4; b.vx = 0.0                                # place along the stairs (cells) and its rate
			b.z = float(D.n) * float(D.rise); b.vz = 0.0                              # height (cells) and its rate
			b.air = false; b.wait = 0.0                                              # in flight?; the timer on the ground
			b.sq = 0.0; b.sqv = 0.0,                                                 # the squash and its rate
		"tick": func(b: Dictionary, dt: float) -> void:
			var D: Dictionary = b.D
			var nn: int = D.n; var rise: float = D.rise; var hop: float = D.hop
			var bounce: float = D.bounce; var squash: float = D.squash
			var g := pow((sqrt(2.0 * hop) + sqrt(2.0 * (hop + rise))) * float(D.tempo) * 1.3, 2.0)   # gravity from the tempo: a hop's flight is (√2h + √2(h+r)) / √g, and the 1.3 leaves room for the bounces
			var SQW := 40.0; var SQD := 0.4 * 2.0 * SQW                              # the squash spring's rate (40 rad/s) and damping (0.4 of critical)
			var sub := maxi(1, ceili(dt * 50.0))                                     # a coarse frame is cut into substeps of at most 0.02 s: one step at 60 fps
			var h := dt / float(sub)
			var ix: float = b.ix; var vx: float = b.vx; var z: float = b.z; var vz: float = b.vz
			var air: bool = b.air; var wait: float = b.wait; var sq: float = b.sq; var sqv: float = b.sqv
			for _s in sub:
				if air:
					vz -= g * h; z += vz * h; ix += vx * h
					var under := clampi(int(floorf(ix)), 0, nn - 1); var top := (under + 1) * rise   # the step beneath: its top is the floor here
					if z <= top and vz < 0.0:
						z = top; var vin := -vz
						vz = vin * bounce; vx *= bounce                                    # restitution: a share comes back up, and the run mostly dies
						sqv -= squash * 2.0 * SQW * minf(1.0, vin / sqrt(2.0 * g * (hop + rise)))   # the landing kicks the squash, by how hard it hit (1 = a full hop's landing)
						if vz * vz < 2.0 * g * 0.03:                                     # a bounce under 0.03 cells: it has landed
							vz = 0.0; vx = 0.0; air = false
							wait = float(D.rest) if under == 0 else float(D.dwell)
				else:
					wait -= h
					if wait <= 0.0:
						var on := clampi(int(floorf(ix)), 0, nn - 1)
						if on == 0:                                                       # the bottom: start over at the top
							ix = float(nn) - 1.0 + 0.4; z = float(nn) * rise
						else:
							vz = sqrt(2.0 * g * hop)                                       # up: enough for the hop height
							var T := (vz + sqrt(vz * vz + 2.0 * g * rise)) / g              # how long until it is one step lower
							vx = (float(on) - 1.0 + 0.4 - ix) / T; air = true               # across: enough to land on the next step's middle
				sqv += (-SQW * SQW * sq - SQD * sqv) * h; sq = clampf(sq + sqv * h, -0.45, 0.45)
			b.ix = ix; b.vx = vx; b.z = z; b.vz = vz; b.air = air; b.wait = wait; b.sq = sq; b.sqv = sqv,
		"press": func(b: Dictionary, pos: Vector2) -> void:                          # click = hop now (or start over, from the bottom); click right = a quicker descent
			b.D.tempo = 0.8 + (pos.x / b.W) * 2.0
			if not b.air: b.wait = 0.0,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			K.sky(n, b, D.sky)
			var nn: int = D.n
			var s: float = minf(b.W * 0.11, b.H * 0.14)
			var rise: float = s * D.rise
			var o := Vector2(b.W / 2.0 - (nn - 1) * 0.866 * s / 2.0, b.H * 0.86 - (nn + 1) * 0.5 * s)
			K.ground(n, b, o.y + s * 0.4, D.floor)
			var cols: Array = D.cols
			for i in nn: K.cube(n, o + K.iso(i + 1, 1.0, 0.0, s), s, cols[i % cols.size()], (i + 1) * rise)   # left to right = back to front
			var ix: float = b.ix; var hz: float = b.z; var sq: float = b.sq
			var under := clampi(int(floorf(ix)), 0, nn - 1); var top_z := (under + 1) * float(D.rise); var lift := hz - top_z   # the step beneath the ball, and how far above it we are
			var g := o + K.iso(ix, 0.78, top_z, s)
			var r := s * 0.27
			K.shadow(n, g, r * 1.2 / (1.0 + lift), r * 0.55 / (1.0 + lift), 0.5 / (1.0 + lift))   # higher = a smaller, fainter shadow
			var bp := o + K.iso(ix, 0.78, hz, s)
			n.draw_set_transform(bp, 0.0, Vector2(1.0 - sq, 1.0 + sq))              # the squash, about the contact point: flatter one way, wider the other
			K.sphere(n, Vector2(0.0, -r), r, D.ball, -0.5, -0.6, 0.5)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			K.label(n, b, D.label) })

	# ---- V · Voxels --------------------------------------------------------
	d.append({ "letter": "V", "name": "Voxels",
		"hint": "a little tree of cubes, sorted far to near before drawing — press turns it a quarter: it swings past and rings back, and the same cubes are re-sorted and re-drawn all the way",
		"dials": { "sky": [Color("141226"), Color("26223E")], "floor": Color("1A1A2C"), "n": 5, "every": 3.0,   # n = grid size; every = seconds between idle quarter-turns
			"k": 60.0, "zeta": 0.4,                              # k = the turn's spring stiffness; zeta = damping as a fraction of critical — under 1, so the turn overshoots and rings back
			"vox": [[2, 2, 0, Color("8A5A3A")], [2, 2, 1, Color("8A5A3A")],                 # [ix, iy, iz, colour] — the trunk...
				[1, 1, 2, Color("4A9A5A")], [2, 1, 2, Color("5AAA6A")], [3, 1, 2, Color("4A9A5A")], [1, 2, 2, Color("5AAA6A")], [2, 2, 2, Color("4A9A5A")],
				[3, 2, 2, Color("5AAA6A")], [1, 3, 2, Color("4A9A5A")], [2, 3, 2, Color("5AAA6A")], [3, 3, 2, Color("4A9A5A")],   # ...the canopy...
				[2, 1, 3, Color("6ABA7A")], [1, 2, 3, Color("5AAA6A")], [2, 2, 3, Color("6ABA7A")], [3, 2, 3, Color("5AAA6A")], [2, 3, 3, Color("6ABA7A")],
				[2, 2, 4, Color("7ACA8A")]],                                               # ...and the crown
			"label": "sort by ix+iy, then by height, then just draw — the order IS the depth; a turn is a spring to a detent, and the sort follows it through the overshoot" },
		"rhyme": { "name": "Voxel cactus", "hint": "a different list of cubes — a cactus with two arms and a flower — under a desert sky; the sort, the shades and the swinging turn are untouched",
			"dials": { "sky": [Color("F5C169"), Color("F5E0B0")], "floor": Color("C8945A"),
				"vox": [[2, 2, 0, Color("4A9A5A")], [2, 2, 1, Color("4A9A5A")], [2, 2, 2, Color("5AAA6A")], [2, 2, 3, Color("5AAA6A")],
					[1, 2, 1, Color("4A9A5A")], [0, 2, 1, Color("4A9A5A")], [0, 2, 2, Color("5AAA6A")],
					[3, 2, 2, Color("5AAA6A")], [4, 2, 2, Color("5AAA6A")], [4, 2, 3, Color("6ABA7A")], [2, 2, 4, Color("F58AB8")]],
				"label": "a different list of cubes, the same sort and the same three shades — the data is the dial; the turn still overshoots and rings back" } },
		"init": func(b: Dictionary) -> void:
			# the turn is an angle with an angular velocity: a press (or the idle
			# timer) moves the detent a quarter on, and a spring, damped under
			# critical, swings the tree toward it — past it, and back. every cube's
			# ix/iy is the grid turned by that angle about its centre (at exactly 90°
			# that is the old quarter-turn: (ix, iy) → (n−1−iy, ix)), and the depth
			# sort works off those interpolated ix/iy, so the order re-sorts itself
			# all the way through the swing and the overshoot.
			b.turns = 0; b.turn_at = -9.0                                            # quarter-turns asked for
			b.phi = 0.0; b.omg = 0.0,                                                # the angle the tree is at, and its rate
		"tick": func(b: Dictionary, dt: float) -> void:
			var D: Dictionary = b.D
			if b.t - b.turn_at > D.every: b.turn_at = b.t; b.turns += 1              # an idle quarter-turn now and then
			var k: float = D.k; var damp: float = float(D.zeta) * 2.0 * sqrt(k)     # damping from its fraction of critical
			var tgt := float(b.turns) * TAU / 4.0                                    # the detent
			var sub := maxi(1, ceili(dt * 50.0))                                     # a coarse frame is cut into substeps of at most 0.02 s: one step at 60 fps
			var h := dt / float(sub)
			var phi: float = b.phi; var omg: float = b.omg
			for _s in sub:
				omg += (k * (tgt - phi) - damp * omg) * h; phi += omg * h
			b.phi = phi; b.omg = omg,
		"press": func(b: Dictionary, _pos: Vector2) -> void: b.turn_at = b.t; b.turns += 1,   # one quarter-turn, now: the detent moves, the spring swings to it
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var nn: int = D.n
			K.sky(n, b, D.sky)
			var m: float = minf(b.W * 0.075, b.H * 0.085)
			var o := Vector2(b.W / 2.0, b.H * 0.54)
			K.ground(n, b, o.y - m * 1.5, D.floor)
			var c := (nn - 1) / 2.0; var phi: float = b.phi; var cs := cos(phi); var sn := sin(phi)
			var list: Array = []
			for v in D.vox:
				var dx := float(v[0]) - c; var dy := float(v[1]) - c                 # the cell turned by phi about the grid's centre
				list.append({ "ix": c + dx * cs - dy * sn, "iy": c + dx * sn + dy * cs, "iz": float(v[2]), "c": v[3] })
			list.sort_custom(func(A, B): return (A.ix + A.iy + A.iz * 0.001) < (B.ix + B.iy + B.iz * 0.001))   # far first, then low first
			K.shadow(n, o, m * 2.1, m * 1.05, 0.4)
			for q in list:                                                              # base point = the cell's front corner, centred on the grid
				K.cube(n, o + K.iso(q.ix + 1.0 - nn / 2.0, q.iy + 1.0 - nn / 2.0, q.iz, m), m, q.c)
			K.label(n, b, D.label) })

	# ---- W · Wedge ---------------------------------------------------------
	d.append({ "letter": "W", "name": "Wedge",
		"hint": "a ramp: the slope is one lit face growing lighter toward you, the end is one dark face — a block slides down, faster and faster, rolls out along the floor and stops; its shadow slides with it",
		"dials": { "sky": [Color("1E1C34"), Color("3A3858")], "floor": Color("1A1A2C"), "col": Color("7AA0C8"), "block": Color("F58A8A"),
			"len": 3.0, "h": 1.4, "speed": 0.8,                 # len = ramp length in cells; h = the high end in cells; speed = the clock: gravity and grip scale with speed², so a higher speed is the same slide, quicker
			"g": 9.0, "grip": 12.0, "rest": 0.6,                # g = gravity, cells/s² (at speed 1); grip = the floor's braking at the bottom, cells/s²; rest = seconds it lies at the end before starting over
			"label": "one lit face, one dark face, and a shadow that keeps up — that is a ramp and a thing on it; the thing: g·sin θ down the slope, grip on the floor" },
		"rhyme": { "name": "Skate ramp", "hint": "the same ramp in concrete grey, lower and faster, under a day sky — a skate ramp with a gold block for a board that rolls out and stops on the flat",
			"dials": { "sky": [Color("6FA8E8"), Color("CFE6F5")], "floor": Color("4A4A52"), "col": Color("8A8A92"), "block": Color("F5C169"),
				"h": 1.0, "speed": 0.9,
				"label": "concrete grey, lower, faster — the lit slope and the dark end are the same two faces; a lower ramp, a shorter roll-out" } },
		"init": func(b: Dictionary) -> void:
			# the block has a speed along the slope: gravity's share along the incline
			# (g·sin θ) grows it every step, so it starts slow and arrives fast. at the
			# bottom the speed turns flat (its along-the-floor part survives, the rest
			# is lost in the bump) and the floor's grip takes it off, so the block
			# rolls out past the ramp and stops where its speed ran out. it rests a
			# moment, then goes back to the top for another run.
			b.iy = 0.0; b.v = 0.0                                                    # place along the ramp (cells); speed (cells/s, along the slope, then the floor)
			b.flat = false; b.wait = 0.0,                                             # on the floor yet?; the rest timer
		"tick": func(b: Dictionary, dt: float) -> void:
			var D: Dictionary = b.D
			var ln: float = D.len; var speed: float = D.speed
			var th := atan2(float(D.h), ln)                                          # the slope's angle
			var g := float(D.g) * speed * speed; var grip := float(D.grip) * speed * speed   # gravity and grip on this card's clock
			var mu := 0.45
			var sub := maxi(1, ceili(dt * 50.0))                                     # a coarse frame is cut into substeps of at most 0.02 s: one step at 60 fps
			var h := dt / float(sub)
			var iy: float = b.iy; var v: float = b.v; var flat: bool = b.flat; var wait: float = b.wait
			for _s in sub:
				if wait > 0.0:
					wait -= h
					if wait <= 0.0: iy = 0.0; v = 0.0; flat = false                    # rested: start over at the top
				elif not flat:
					v += g * sin(th) * h; iy += v * cos(th) * h                            # down the incline: only gravity's share along it
					if iy + mu * 0.5 >= ln: flat = true; v *= cos(th)                     # the block's middle passes the bottom edge: onto the floor
				else:
					v = maxf(0.0, v - grip * h); iy = minf(iy + v * h, ln + 3.0)          # the roll-out: grip takes the speed off
					if v == 0.0: wait = D.rest
			b.iy = iy; b.v = v; b.flat = flat; b.wait = wait,
		"press": func(b: Dictionary, pos: Vector2) -> void:                          # click right = a faster clock; click = a shove down the slope, or a fresh run if it is resting
			b.D.speed = 0.3 + (pos.x / b.W) * 0.9
			if b.wait > 0.0:
				b.iy = 0.0; b.v = 0.0; b.flat = false; b.wait = 0.0
			else:
				b.v += float(b.D.g) * 0.2,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			K.sky(n, b, D.sky)
			var ln: float = D.len; var hh: float = D.h
			var s: float = minf(b.W * 0.13, b.H * 0.16)
			var o := Vector2(b.W / 2.0 + s * 0.4, b.H * 0.84 - (ln + 1.0) * 0.5 * s)
			K.ground(n, b, o.y - s * 0.3, D.floor)
			K.poly(n, PackedVector2Array([o + K.iso(1, 0, 0, s), o + K.iso(1, 0, hh, s), o + K.iso(1, ln, 0, s)]), K.shade(D.col, -0.42))   # the end face: vertical, facing right → dark
			var ga := o + K.iso(0.5, 0, hh, s); var gb := o + K.iso(0.5, ln, 0, s)         # the slope's gradient axis: high end → low end
			var c0 := K.shade(D.col, 0.32); var c1 := K.shade(D.col, 0.5)
			var slope := PackedVector2Array([o + K.iso(0, 0, hh, s), o + K.iso(1, 0, hh, s), o + K.iso(1, ln, 0, s), o + K.iso(0, ln, 0, s)])
			var sc := PackedColorArray()
			for pt in slope: sc.append(c0.lerp(c1, _along(pt, ga, gb)))
			K.lin_poly(n, slope, sc)                                                    # the slope: lit, lighter as it nears you
			var mu := 0.45; var iy: float = b.iy; var z := hh * maxf(0.0, 1.0 - (iy + mu * 0.5) / ln)   # the block's place, and the slope's height under its middle — nil once it is on the floor
			var sh := o + K.iso(0.5 + mu * 0.75, iy + mu * 0.5 + 0.15, z - 0.05, s)
			K.shadow(n, sh, s * mu * 1.1, s * mu * 0.55, 0.45)                          # the shadow rides the slope with it
			K.cube(n, o + K.iso(0.5 + mu / 2.0, iy + mu, z, s), s * mu, D.block)
			K.label(n, b, D.label) })

	# ---- X · Xylophone -----------------------------------------------------
	d.append({ "letter": "X", "name": "Xylophone", "drag": true,
		"hint": "eight flat blocks receding toward the back, each drawn a little smaller than the one before — size shrinking with distance is the cue; press a bar and it rings: it dips, springs back and fades, the long front bars slower than the short ones at the back",
		"dials": { "sky": [Color("1A1430"), Color("2C2448")], "floor": Color("1A1A2C"), "hues": [0.0, 30.0, 55.0, 110.0, 180.0, 210.0, 260.0, 300.0],
			"n": 8, "shrink": 0.07, "thick": 0.28, "jitter": 0.0, "beat": 0.45,   # shrink per bar toward the back; thick = bar height; jitter = height wobble; beat = seconds per note
			"ring": 8.0, "decay": 0.06, "kick": 3.0,              # ring = the front bar's rate, radians per second (a shorter bar rings quicker, by 1/length²); decay = damping as a fraction of critical — tiny, so a bar rings for seconds; kick = the mallet: the speed a strike gives a bar, bar sizes per second
			"label": "no perspective maths — each bar is drawn a little smaller than the one in front, and the eye reads distance; each bar is a spring that rings at its own rate" },
		"rhyme": { "name": "Glitch keys", "hint": "the same bars in two neon hues, heights jittering, the tune at three times the beat — struck bars ring over each other; the sizes still shrink to the back, so the depth survives",
			"dials": { "sky": [Color("050510"), Color("101028")], "floor": Color("0A0A18"), "hues": [180.0, 300.0, 180.0, 300.0, 180.0, 300.0, 180.0, 300.0],
				"jitter": 0.35, "beat": 0.18,
				"label": "jittered heights and a frantic beat — the sizes still shrink to the back, so the depth survives the glitch; the bars ring over one another" } },
		"init": func(b: Dictionary) -> void:
			# each bar is a spring: a strike gives it a velocity downward, and a
			# spring with almost no damping brings it back and past, over and over,
			# fading — a bar rings. the rate is the bar's own: a short bar is a stiff
			# bar (k ∝ 1/length²), so the back bars ring quick and die soon, and the
			# long front bar rings low and slow. the top's flash is the ring's
			# energy, so it fades with the sound rather than on a timer.
			b.tune = [0, 2, 4, 7, 4, 2, 1, 3, 5, 3]
			var nn: int = b.D.n
			var yo := PackedFloat32Array()                # sized here: a packed array read back from b is a copy
			var yv := PackedFloat32Array()
			yo.resize(nn)
			yv.resize(nn)
			b.yo = yo; b.yv = yv                                                     # each bar's offset (in bar sizes, down = positive) and its rate
			b.seq = 0; b.next_at = 0.0; b.rows = [],
		"tick": func(b: Dictionary, dt: float) -> void:
			var D: Dictionary = b.D
			var yo: PackedFloat32Array = b.yo
			var yv: PackedFloat32Array = b.yv
			var kick: float = D.kick
			if b.t > b.next_at:                                                         # the tune plays itself: each note is a strike
				yv[b.tune[b.seq % b.tune.size()]] += kick; b.seq += 1; b.next_at = b.t + D.beat
			var ring: float = D.ring; var decay: float = D.decay
			var sub := maxi(1, ceili(dt * 50.0))                                     # a coarse frame is cut into substeps of at most 0.02 s: one step at 60 fps
			var h := dt / float(sub)
			for i in yo.size():
				var L := 4.2 - i * 0.3
				var om := ring * (4.2 / L) * (4.2 / L); var k := om * om; var dp := decay * 2.0 * om   # this bar's rate: stiffer the shorter it is; its damping from the fraction of critical
				for _s in sub:
					yv[i] += (-k * yo[i] - dp * yv[i]) * h
					yo[i] = clampf(yo[i] + yv[i] * h, -1.0, 1.0),
		"press": func(b: Dictionary, pos: Vector2) -> void:                          # click = strike the bar nearest that height: a velocity, and the spring rings it
			var best := 0; var bd := 1e9
			for row in b.rows:
				var dd: float = absf(row[1] - pos.y)
				if dd < bd: bd = dd; best = row[0]
			var yv: PackedFloat32Array = b.yv
			yv[best] += float(b.D.kick),
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			K.sky(n, b, D.sky)
			var nn: int = D.n
			var s: float = minf(b.W * 0.08, b.H * 0.13); var base_y: float = b.H * 0.86
			K.ground(n, b, base_y - s * 4.5, D.floor)
			var hues: Array = D.hues
			var yo: PackedFloat32Array = b.yo
			var yv: PackedFloat32Array = b.yv
			var ring: float = D.ring; var kick: float = D.kick
			b.rows = []
			for i in range(nn - 1, -1, -1):                                             # back bar first
				var sc: float = 1.0 - i * D.shrink; var si := s * sc; var L := 4.2 - i * 0.3; var wd := 0.8
				var off := K.iso(0.0, -i * 1.2, 0.0, s)
				var x: float = b.W / 2.0 - s * 1.5 + (L - wd) * 0.433 * si + off.x; var y := base_y + off.y + yo[i] * si
				var hz: float = si * D.thick * (1.0 + D.jitter * sin(t * 13.0 + i * 5.0))
				var om := ring * (4.2 / L) * (4.2 / L)
				var flash := clampf(sqrt(yo[i] * yo[i] + (yv[i] / om) * (yv[i] / om)) * om / kick, 0.0, 1.0)   # the ring's energy, 1 at a fresh strike
				var c := K.hsl(hues[i % hues.size()], 0.6, 0.55)
				if flash > 0.02: K.soft(n, Vector2(x - L * 0.433 * si, y - L * 0.25 * si - hz), si * 1.4, c, flash * 0.6)
				_bar(n, x, y, L, wd, hz, si, c, 0.32 + 0.45 * flash)
				b.rows.append([i, y - L * 0.25 * si - hz])                                # remember where each bar sits, for clicking
			K.label(n, b, D.label) })

	# ---- Y · Yurt ----------------------------------------------------------
	d.append({ "letter": "Y", "name": "Yurt", "drag": true,
		"hint": "a round tent: the wall is a cylinder (dark → light → dark across), the roof a cone (the same band pinched into a triangle) — press moves the light and both slide",
		"dials": { "sky": [Color("2A3A6A"), Color("B8C8E0")], "floor": Color("5A6A4A"), "wall": Color("D9C8A8"), "roof": Color("A85A4A"), "door": Color("3A2A1A"),
			"roofH": 0.55, "smoke": 6,                           # roofH = cone height in wall widths (low = a dome-ish cap); smoke = how many puffs
			"label": "cylinder and cone are the same horizontal band — dark, light, dark — one in a rectangle, one pinched to a point" },
		"rhyme": { "name": "Igloo dome", "hint": "the same tent in white on blue with a squat roof and almost no smoke — the cone reads as a dome the moment it gets low",
			"dials": { "sky": [Color("1E3A7A"), Color("8AB8E8")], "floor": Color("E8F0F8"), "wall": Color("E8F0F8"), "roof": Color("D8E8F5"), "door": Color("2A3A5A"),
				"roofH": 0.22, "smoke": 2,
				"label": "white on blue with a squat roof — the same band, pinched less, and the cone reads as a dome" } },
		"init": func(b: Dictionary) -> void: b.lx = -0.35,
		"press": func(b: Dictionary, pos: Vector2) -> void: b.lx = clampf((pos.x / b.W - 0.5) * 2.0, -1.0, 1.0),   # the light slides to where you click
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var lx: float = b.lx
			K.sky(n, b, D.sky)
			var w: float = b.W * 0.36; var hgt: float = b.H * 0.26; var cx: float = b.W / 2.0; var gy: float = b.H * 0.84
			K.ground(n, b, gy - b.H * 0.18, D.floor)
			K.shadow(n, Vector2(cx - lx * w * 0.3, gy), w * 0.72, w * 0.16, 0.45)      # the contact shadow leans away from the light
			K.cyl(n, cx, gy, w, hgt, D.wall, lx)
			K.cyl(n, cx, gy - hgt * 0.72, w, hgt * 0.07, K.shade(D.wall, -0.3), lx)   # a decorative band — the same gradient, so the same roundness
			var rw := w * 0.62; var ry := gy - hgt + hgt * 0.04; var top: float = ry - w * D.roofH
			var hi := clampf(0.5 + lx * 0.4, 0.05, 0.95)
			_hgrad_poly(n, [Vector2(cx - rw, ry), Vector2(cx, top), Vector2(cx + rw, ry)], cx - rw, cx + rw,
				[[0.0, K.shade(D.roof, -0.55)], [hi, K.shade(D.roof, 0.3)], [1.0, K.shade(D.roof, -0.7)]])   # the cone: the cylinder's band, in a triangle
			var dw := w * 0.16; var dh := hgt * 0.5; var dx := cx - w * 0.04
			n.draw_rect(Rect2(dx - dw / 2.0, gy - dh, dw, dh), D.door)
			K.dot(n, Vector2(dx, gy - dh), dw / 2.0, D.door)                              # an arched door
			var smoke: int = D.smoke
			for i in smoke:                                                               # smoke: puffs that grow and fade as they rise
				var p := fposmod(t * 0.3 + float(i) / smoke, 1.0)
				var sx := cx + p * w * 0.25 + sin(p * 7.0 + i) * w * 0.05; var sy: float = top - p * b.H * 0.24
				K.soft(n, Vector2(sx, sy), w * 0.03 + p * w * 0.09, Color("E8E5F4"), (1.0 - p) * 0.35)
			K.label(n, b, D.label) })

	# ---- Z · Ziggurat ------------------------------------------------------
	d.append({ "letter": "Z", "name": "Ziggurat",
		"hint": "five blocks, each smaller and centred on the last: the same three shades on every tier and one long ground shadow — press swaps the sun to the other side",
		"dials": { "sky": [Color("F5A15A"), Color("F5D9B0")], "sand": Color("C8945A"), "col": Color("B87A4A"),
			"tiers": 5, "step": 0.17, "h": 0.22, "shadowA": 0.35, "glow": 0.0,   # step = how much each tier shrinks; h = tier height in widths; glow = neon edge alpha (0 = none)
			"label": "five tiers, one sun: every tier is lit on the same side — swap the sun and all five swap together" },
		"rhyme": { "name": "Neon temple", "hint": "the same five tiers at night in violet, every top edge glowing cyan, a deeper shadow — the edges were where the shades met all along",
			"dials": { "sky": [Color("0A0A1E"), Color("1A1035")], "sand": Color("0E0B1A"), "col": Color("5A2A7A"), "shadowA": 0.5, "glow": 0.9,
				"label": "in the dark the shades go quiet and the glowing edges take over — the edges were where the shades met all along" } },
		"init": func(b: Dictionary) -> void: b.sun_l = true,
		"press": func(b: Dictionary, _pos: Vector2) -> void: b.sun_l = not b.sun_l,   # the sun crosses the sky
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var sun_l: bool = b.sun_l
			K.sky(n, b, D.sky)
			var s: float = minf(b.W * 0.34, b.H * 0.42)
			var dx := 0.866 * s; var dy := 0.5 * s; var h: float = s * D.h
			var x: float = b.W / 2.0; var y: float = b.H * 0.84; var dir := 1.0 if sun_l else -1.0
			K.ground(n, b, y - dy * 2.4, D.sand)
			K.soft(n, Vector2(b.W * 0.1 if sun_l else b.W * 0.9, b.H * 0.16), b.W * 0.16, Color("FFF3D0"), 0.9)
			var L := s * 1.5; var vx := dir * L; var vy := L * 0.22                        # the shadow runs away from the sun, a little toward us
			K.poly(n, PackedVector2Array([Vector2(x, y), Vector2(x + dir * dx, y - dy), Vector2(x + dir * dx + vx * 0.7, y - dy + vy * 0.7), Vector2(x + vx, y + vy)]),
				Color(0, 0, 0, D.shadowA))
			var tiers: int = D.tiers
			for k in tiers:
				var sz: float = s * (1.0 - k * D.step); var yk := y - k * h - 0.5 * (s - sz)   # each tier centred on the one below
				_blk(n, Vector2(x, yk), sz, K.mix(D.col, K.shade(D.col, 0.2), float(k) / tiers), h, sun_l)
				if D.glow > 0.0:                                                          # neon: the top's four edges, lit
					var ex := 0.866 * sz; var ey := 0.5 * sz; var ty := yk - h
					var E := [Vector2(x, ty), Vector2(x - ex, ty - ey), Vector2(x, ty - 2.0 * ey), Vector2(x + ex, ty - ey)]
					for e in 4: K.line(n, E[e], E[(e + 1) % 4], K.alpha(Color("40F0F0"), D.glow), 1.5)
			K.label(n, b, D.label) })

	return d
