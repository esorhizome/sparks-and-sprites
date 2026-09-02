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
		"hint": "a faceted stone: each triangle is one flat shade set by how squarely it faces the light — the stone turns and the shades walk round it",
		"dials": { "sky": [Color("0E0C1E"), Color("1E1A36")], "col": Color("5AC8E8"), "spin": 0.7,
			"sides": 6, "crown": 0.45, "pav": 1.1,               # crown/pav = the point above / below the rim, in radii
			"label": "shade = how squarely the face meets the light — turning changes nothing but that, and the stone reads solid" },
		"rhyme": { "name": "Ruby cut", "hint": "the same stone in red, turning three times as fast — the facets flicker past the light instead of drifting",
			"dials": { "sky": [Color("1A0810"), Color("2E1020")], "col": Color("E0305A"), "spin": 1.4,
				"label": "a red palette and a faster turn — the same triangles; only the dot product with the light moves" } },
		"init": func(b: Dictionary) -> void: b.spin = 0.0,
		"press": func(b: Dictionary, pos: Vector2) -> void: b.spin += (pos.x / b.W - 0.5) * 2.0,   # nudge the stone round by hand
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			K.sky(n, b, D.sky)
			var LT := Vector3(-0.5, 0.75, 0.45).normalized()                        # the light: upper-left, a little toward us
			var r: float = minf(b.W, b.H) * 0.26
			var cx: float = b.W / 2.0; var cy: float = b.H * 0.46 + sin(t * 1.3) * r * 0.06
			var ang: float = t * D.spin + b.spin
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
		"hint": "a six-sided column: the hexagon top is the lit shade, each visible side a shade set by which way it faces — press turns it 60° and the shades walk round",
		"dials": { "sky": [Color("141226"), Color("26223E")], "floor": Color("1A1A2C"), "cols": [Color("B87A5A")],
			"count": 1, "h": 0.5, "r": 0.16, "every": 2.0,       # count of prisms; h and r as fractions of H and W; every = seconds between idle turns
			"label": "one rule for every side — shade by the way it faces — and the top stays lit whatever the turn" },
		"rhyme": { "name": "Basalt columns", "hint": "five grey columns of different heights, side by side, all turning together — a rock shelf from one rule",
			"dials": { "cols": [Color("4A4A52"), Color("5A5A62"), Color("3E3E46")], "count": 5, "h": 0.42,
				"label": "five columns, different heights, one light — the grey rule is still a rule, so they stand on one shelf" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(7)
			var cnt: int = D.count
			var cols: Array = D.cols
			b.prisms = []
			for i in cnt:
				b.prisms.append({ "x": (i + 0.5) / cnt, "h": D.h * ((0.55 + R.randf() * 0.7) if cnt > 1 else 1.0), "c": cols[i % cols.size()] })
			b.turn = 0.0; b.target = 0.0; b.next_at = D.every,
		"tick": func(b: Dictionary, dt: float) -> void:
			if b.t > b.next_at: b.target += TAU / 6.0; b.next_at = b.t + b.D.every
			b.turn += (b.target - b.turn) * minf(1.0, dt * 6.0),                    # ease toward the next 60°
		"press": func(b: Dictionary, _pos: Vector2) -> void: b.target += TAU / 6.0; b.next_at += b.D.every,   # one more sixth of a turn
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			K.sky(n, b, D.sky)
			var gy: float = b.H * 0.82
			K.ground(n, b, gy - b.H * 0.22, D.floor)
			var cnt: int = D.count
			var turn: float = b.turn
			for P in b.prisms:
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
		"hint": "an isometric floor: diamonds in two alternating colours with a darker line on their right and bottom edges — and a ball whose shadow never leaves the floor",
		"dials": { "sky": [Color("141226"), Color("221E3A")], "a": Color("6A8ACF"), "b": Color("8AA6DF"), "edge": -0.45, "ball": Color("F58A8A"),
			"n": 8, "speed": 0.6, "glow": 0.0,                   # n tiles a side; glow = a warm torch tint over the floor (0 = none)
			"label": "two colours and a dark right-and-bottom edge make a floor; the shadow glues the ball to it" },
		"rhyme": { "name": "Dungeon floor", "hint": "the same floor in dark stone under a torch — a warm glow laid over the tiles, the edge lines cut deeper",
			"dials": { "sky": [Color("0A0812"), Color("161222")], "a": Color("3A3640"), "b": Color("4A4650"), "edge": -0.6, "ball": Color("9BE28A"), "glow": 0.35,
				"label": "dark stone under a torch: the warm tint sits on top of the tiles, and the edge lines still say 'floor'" } },
		"init": func(b: Dictionary) -> void:
			b.ball = Vector2(4, 4); b.target = null,
		"tick": func(b: Dictionary, dt: float) -> void:
			var D: Dictionary = b.D
			var nn: float = D.n
			var aim := Vector2(nn / 2.0 + 2.6 * cos(b.t * D.speed), nn / 2.0 + 2.6 * sin(b.t * D.speed))   # the idle path: a circle
			if b.target != null:
				aim = b.target
				if absf(aim.x - b.ball.x) + absf(aim.y - b.ball.y) < 0.15: b.target = null
			b.ball += (aim - b.ball) * minf(1.0, dt * 2.5),
		"press": func(b: Dictionary, pos: Vector2) -> void:                          # click = roll the ball there (screen → iso grid)
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
		"hint": "a castle tower from stacked blocks: one tall block, small blocks for the battlements, a dark doorway — every face obeys the same light, so it is one building",
		"dials": { "sky": [Color("2A3A6A"), Color("8AA0C8")], "floor": Color("3A5A3A"), "stone": Color("9A8E86"), "flag": Color("F58A8A"),
			"h": 2.4, "wind": 1.0,                               # h = tower height in widths; wind = flag speed (sign = direction)
			"label": "one sun for every block — tower, battlements, annex all agree on the dark side, so they are one building" },
		"rhyme": { "name": "Sci-fi silo", "hint": "the same tower in steel blue, half again as tall, with a cyan beacon for a flag — a launch silo from castle parts",
			"dials": { "sky": [Color("0A0F2A"), Color("2A3A6A")], "floor": Color("1A2030"), "stone": Color("7A9AB8"), "flag": Color("40F0F0"),
				"h": 3.4, "wind": -1.0,
				"label": "steel blue and taller, the flag a beacon — the light rule did not change, so it is still one building" } },
		"init": func(b: Dictionary) -> void: b.sun_l = true,
		"press": func(b: Dictionary, pos: Vector2) -> void:                          # click a side = the sun (and the wind) come from there
			b.sun_l = pos.x < b.W / 2.0
			b.D.wind = (1.0 if pos.x < b.W / 2.0 else -1.0) * absf(b.D.wind),
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
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
			var dir := 1.0 if D.wind > 0.0 else -1.0
			K.line(n, Vector2(px, py), Vector2(px, py - ph), Color("3A3040"), 1.5)
			var wind: float = absf(D.wind)
			var wave := sin(t * 5.0 * wind) * s * 0.08 + sin(t * 8.3 * wind) * s * 0.04
			K.poly(n, PackedVector2Array([Vector2(px, py - ph), Vector2(px + dir * s * 0.5, py - ph + s * 0.12 + wave), Vector2(px, py - ph + s * 0.32)]), D.flag)
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
		"hint": "blocks of climbing height drawn left to right: lit tops, mid sides, dark ends — and a ball hopping down step by step, its shadow landing on each one",
		"dials": { "sky": [Color("1A1E36"), Color("3A3F60")], "floor": Color("1A1A2C"), "cols": [Color("8A8FA8")], "ball": Color("F5C169"),
			"n": 7, "rise": 0.55, "hop": 0.55, "tempo": 1.6,     # rise (keep ≥ 0.5 so each step hides the last one's end) and hop in step widths; tempo = hops per second
			"label": "seven blocks that agree about the light, drawn back to front — the shadow says which step the ball is over" },
		"rhyme": { "name": "Candy stairs", "hint": "the same staircase in four pastels with a ball that hops twice as high and faster — the shadow shrinks more, so the bounce reads taller",
			"dials": { "sky": [Color("F5D0E0"), Color("F5E8F0")], "floor": Color("E8C8D8"), "cols": [Color("F5A0B8"), Color("A0D8F5"), Color("F5E0A0"), Color("B8F0B0")],
				"ball": Color("C9A0F5"), "hop": 1.2, "tempo": 2.2,
				"label": "pastel steps, a higher hop — the shadow shrinks more when the ball is higher, so the bounce reads taller" } },
		"init": func(b: Dictionary) -> void: b.phase = 0.0,
		"press": func(b: Dictionary, pos: Vector2) -> void:                          # click = back to the top; click right = a quicker descent
			b.phase = -b.t; b.D.tempo = 0.8 + (pos.x / b.W) * 2.0,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			K.sky(n, b, D.sky)
			var nn: int = D.n
			var s: float = minf(b.W * 0.11, b.H * 0.14)
			var rise: float = s * D.rise
			var o := Vector2(b.W / 2.0 - (nn - 1) * 0.866 * s / 2.0, b.H * 0.86 - (nn + 1) * 0.5 * s)
			K.ground(n, b, o.y + s * 0.4, D.floor)
			var cols: Array = D.cols
			for i in nn: K.cube(n, o + K.iso(i + 1, 1.0, 0.0, s), s, cols[i % cols.size()], (i + 1) * rise)   # left to right = back to front
			var k := fposmod((t + b.phase) * D.tempo, float(nn))
			var j := int(floorf(k)); var p := k - j                                     # j hops done so far; p = progress of this hop
			var from := nn - 1 - j; var to := maxi(0, from - 1)                          # hopping from step `from` down to step `to`
			var ix := lerpf(from + 0.4, to + 0.4, p)
			var hz: float = lerpf((from + 1) * rise, (to + 1) * rise, p) / s + 4.0 * p * (1.0 - p) * D.hop
			var under := int(floorf(ix)); var top_z := (under + 1) * rise / s; var lift := hz - top_z   # the step beneath the ball, and how far above it we are
			var g := o + K.iso(ix, 0.78, top_z, s)
			var r := s * 0.27
			K.shadow(n, g, r * 1.2 / (1.0 + lift), r * 0.55 / (1.0 + lift), 0.5 / (1.0 + lift))   # higher = a smaller, fainter shadow
			var bp := o + K.iso(ix, 0.78, hz, s)
			K.sphere(n, Vector2(bp.x, bp.y - r), r, D.ball, -0.5, -0.6, 0.5)
			K.label(n, b, D.label) })

	# ---- V · Voxels --------------------------------------------------------
	d.append({ "letter": "V", "name": "Voxels",
		"hint": "a little tree of cubes, sorted far to near before drawing — press turns it a quarter, and the same cubes are re-sorted and re-drawn",
		"dials": { "sky": [Color("141226"), Color("26223E")], "floor": Color("1A1A2C"), "n": 5, "every": 3.0,   # n = grid size; every = seconds between idle quarter-turns
			"vox": [[2, 2, 0, Color("8A5A3A")], [2, 2, 1, Color("8A5A3A")],                 # [ix, iy, iz, colour] — the trunk...
				[1, 1, 2, Color("4A9A5A")], [2, 1, 2, Color("5AAA6A")], [3, 1, 2, Color("4A9A5A")], [1, 2, 2, Color("5AAA6A")], [2, 2, 2, Color("4A9A5A")],
				[3, 2, 2, Color("5AAA6A")], [1, 3, 2, Color("4A9A5A")], [2, 3, 2, Color("5AAA6A")], [3, 3, 2, Color("4A9A5A")],   # ...the canopy...
				[2, 1, 3, Color("6ABA7A")], [1, 2, 3, Color("5AAA6A")], [2, 2, 3, Color("6ABA7A")], [3, 2, 3, Color("5AAA6A")], [2, 3, 3, Color("6ABA7A")],
				[2, 2, 4, Color("7ACA8A")]],                                               # ...and the crown
			"label": "sort by ix+iy, then by height, then just draw — the order IS the depth; a turn only changes the order" },
		"rhyme": { "name": "Voxel cactus", "hint": "a different list of cubes — a cactus with two arms and a flower — under a desert sky; the sort and the shades are untouched",
			"dials": { "sky": [Color("F5C169"), Color("F5E0B0")], "floor": Color("C8945A"),
				"vox": [[2, 2, 0, Color("4A9A5A")], [2, 2, 1, Color("4A9A5A")], [2, 2, 2, Color("5AAA6A")], [2, 2, 3, Color("5AAA6A")],
					[1, 2, 1, Color("4A9A5A")], [0, 2, 1, Color("4A9A5A")], [0, 2, 2, Color("5AAA6A")],
					[3, 2, 2, Color("5AAA6A")], [4, 2, 2, Color("5AAA6A")], [4, 2, 3, Color("6ABA7A")], [2, 2, 4, Color("F58AB8")]],
				"label": "a different list of cubes, the same sort and the same three shades — the data is the dial" } },
		"init": func(b: Dictionary) -> void: b.turns = 0; b.turn_at = -9.0,
		"tick": func(b: Dictionary, _dt: float) -> void:
			if b.t - b.turn_at > b.D.every: b.turn_at = b.t; b.turns += 1,           # an idle quarter-turn now and then
		"press": func(b: Dictionary, _pos: Vector2) -> void: b.turn_at = b.t; b.turns += 1,   # one quarter-turn, now
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var nn: int = D.n
			var p := K.ease(clampf((t - b.turn_at) * 1.6, 0.0, 1.0))                   # the turn in progress, 0 → 1
			K.sky(n, b, D.sky)
			var m: float = minf(b.W * 0.075, b.H * 0.085)
			var o := Vector2(b.W / 2.0, b.H * 0.54)
			K.ground(n, b, o.y - m * 1.5, D.floor)
			var rot := func(v: Array, k: int) -> Vector2:                               # the grid turned k quarters: (ix, iy) → (n−1−iy, ix)
				var ix: int = v[0]; var iy: int = v[1]
				for i in maxi(k, 0):
					var nx := nn - 1 - iy; iy = ix; ix = nx
				return Vector2(ix, iy)
			var turns: int = b.turns
			var list: Array = []
			for v in D.vox:
				var a: Vector2 = rot.call(v, (turns - 1) % 4); var bb: Vector2 = rot.call(v, turns % 4)   # where it was, where it is going
				list.append({ "ix": lerpf(a.x, bb.x, p), "iy": lerpf(a.y, bb.y, p), "iz": float(v[2]), "c": v[3] })
			list.sort_custom(func(A, B): return (A.ix + A.iy + A.iz * 0.001) < (B.ix + B.iy + B.iz * 0.001))   # far first, then low first
			K.shadow(n, o, m * 2.1, m * 1.05, 0.4)
			for q in list:                                                              # base point = the cell's front corner, centred on the grid
				K.cube(n, o + K.iso(q.ix + 1.0 - nn / 2.0, q.iy + 1.0 - nn / 2.0, q.iz, m), m, q.c)
			K.label(n, b, D.label) })

	# ---- W · Wedge ---------------------------------------------------------
	d.append({ "letter": "W", "name": "Wedge",
		"hint": "a ramp: the slope is one lit face growing lighter toward you, the end is one dark face — a block slides down and its shadow slides with it",
		"dials": { "sky": [Color("1E1C34"), Color("3A3858")], "floor": Color("1A1A2C"), "col": Color("7AA0C8"), "block": Color("F58A8A"),
			"len": 3.0, "h": 1.4, "speed": 0.8,                 # len = ramp length in cells; h = the high end in cells; speed = slides per second
			"label": "one lit face, one dark face, and a shadow that keeps up — that is a ramp and a thing on it" },
		"rhyme": { "name": "Skate ramp", "hint": "the same ramp in concrete grey, lower and faster, under a day sky — a skate ramp with a gold block for a board",
			"dials": { "sky": [Color("6FA8E8"), Color("CFE6F5")], "floor": Color("4A4A52"), "col": Color("8A8A92"), "block": Color("F5C169"),
				"h": 1.0, "speed": 0.9,
				"label": "concrete grey, lower, faster — the lit slope and the dark end are the same two faces" } },
		"init": func(b: Dictionary) -> void: b.slide = 0.0,
		"press": func(b: Dictionary, pos: Vector2) -> void:                          # click = back to the top; click right = a faster slide
			b.D.speed = 0.3 + (pos.x / b.W) * 0.9; b.slide = -b.t * b.D.speed,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
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
			var r := fposmod(t * D.speed + b.slide, 1.25); var q := clampf(r * r, 0.0, 1.0)   # r² = it accelerates; then rests at the bottom a moment
			var mu := 0.45; var iy := q * (ln - mu); var z := hh * (1.0 - (iy + mu * 0.5) / ln)   # the block's place on the slope and the slope's height there
			var sh := o + K.iso(0.5 + mu * 0.75, iy + mu * 0.5 + 0.15, z - 0.05, s)
			K.shadow(n, sh, s * mu * 1.1, s * mu * 0.55, 0.45)                          # the shadow rides the slope with it
			K.cube(n, o + K.iso(0.5 + mu / 2.0, iy + mu, z, s), s * mu, D.block)
			K.label(n, b, D.label) })

	# ---- X · Xylophone -----------------------------------------------------
	d.append({ "letter": "X", "name": "Xylophone", "drag": true,
		"hint": "eight flat blocks receding toward the back, each drawn a little smaller than the one before — size shrinking with distance is the cue; press a bar and its top flashes",
		"dials": { "sky": [Color("1A1430"), Color("2C2448")], "floor": Color("1A1A2C"), "hues": [0.0, 30.0, 55.0, 110.0, 180.0, 210.0, 260.0, 300.0],
			"n": 8, "shrink": 0.07, "thick": 0.28, "jitter": 0.0, "beat": 0.45,   # shrink per bar toward the back; thick = bar height; jitter = height wobble; beat = seconds per note
			"label": "no perspective maths — each bar is drawn a little smaller than the one in front, and the eye reads distance" },
		"rhyme": { "name": "Glitch keys", "hint": "the same bars in two neon hues, heights jittering, the tune at three times the beat — the sizes still shrink to the back, so the depth survives",
			"dials": { "sky": [Color("050510"), Color("101028")], "floor": Color("0A0A18"), "hues": [180.0, 300.0, 180.0, 300.0, 180.0, 300.0, 180.0, 300.0],
				"jitter": 0.35, "beat": 0.18,
				"label": "jittered heights and a frantic beat — the sizes still shrink to the back, so the depth survives the glitch" } },
		"init": func(b: Dictionary) -> void:
			b.tune = [0, 2, 4, 7, 4, 2, 1, 3, 5, 3]
			b.hit = []
			for i in int(b.D.n): b.hit.append(-9.0)
			b.seq = 0; b.next_at = 0.0; b.rows = [],
		"tick": func(b: Dictionary, _dt: float) -> void:
			if b.t > b.next_at:                                                         # the tune plays itself
				b.hit[b.tune[b.seq % b.tune.size()]] = b.t; b.seq += 1; b.next_at = b.t + b.D.beat,
		"press": func(b: Dictionary, pos: Vector2) -> void:                          # click = strike the bar nearest that height
			var best := 0; var bd := 1e9
			for row in b.rows:
				var dd: float = absf(row[1] - pos.y)
				if dd < bd: bd = dd; best = row[0]
			b.hit[best] = b.t,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			K.sky(n, b, D.sky)
			var nn: int = D.n
			var s: float = minf(b.W * 0.08, b.H * 0.13); var base_y: float = b.H * 0.86
			K.ground(n, b, base_y - s * 4.5, D.floor)
			var hues: Array = D.hues
			b.rows = []
			for i in range(nn - 1, -1, -1):                                             # back bar first
				var sc: float = 1.0 - i * D.shrink; var si := s * sc; var L := 4.2 - i * 0.3; var wd := 0.8
				var off := K.iso(0.0, -i * 1.2, 0.0, s)
				var x: float = b.W / 2.0 - s * 1.5 + (L - wd) * 0.433 * si + off.x; var y := base_y + off.y
				var hz: float = si * D.thick * (1.0 + D.jitter * sin(t * 13.0 + i * 5.0))
				var flash := clampf(1.0 - (t - b.hit[i]) * 3.0, 0.0, 1.0)
				var c := K.hsl(hues[i % hues.size()], 0.6, 0.55)
				if flash > 0.0: K.soft(n, Vector2(x - L * 0.433 * si, y - L * 0.25 * si - hz), si * 1.4, c, flash * 0.6)
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
