extends RefCounted
## ROUNDED FORMS — 13 pictures, ported from the web atlas (docs/depth.js).
## A disc becomes a ball the moment its radial gradient stops being centred:
## push the bright inner point toward the light and the eye supplies the
## third axis for free. Everything here is that one move — a ball, a
## squeezed ball (egg, airship), a ball cut in half (dome), a stack of
## horizontal bands (column, urn), a ball wearing stripes (planet), a ball
## made of mirror (quicksilver). Every card has a light direction you can
## move, and watches where the highlight, the core shadow, the rim light
## and the contact shadow go when you do.
##
## The web page leans on ctx.clip() to cut gradients to a shape. _draw()
## has no clip, so this file adds two honest spellings of the same thing:
##   • _grad_convex — a gradient inside a convex outline, as rows of
##     vertices coloured by the gradient's own formula (_rad_at solves the
##     canvas two-circle gradient exactly at each vertex), stitched into one
##     triangle array. Used for the dome, the planet's dark overlay, the
##     mirror's rim, the pearl's tints and the fried egg's white.
##   • flat shapes clipped to a disc go through Geometry2D.intersect_polygons.
## Where the clipped-away part is simply hidden under something opaque
## (the capsule's caps under its body) we just draw in that order.

const K := preload("res://scenes/depth/kit.gd")

const TITLE := "Rounded forms"
const BLURB := "one radial gradient with its centre pushed toward the light — that offset IS the roundness"

## ---------------------------------------------------------------- local helpers
## Normalise stops to [[k, Color], …] (the kit's rule: pairs, or evenly spaced colours).
static func _stops(stops: Array) -> Array:
	var out := []
	var cnt := stops.size()
	for i in cnt:
		var s = stops[i]
		if s is Array: out.append([clampf(float(s[0]), 0.0, 1.0), s[1] as Color])
		else: out.append([0.0 if cnt == 1 else float(i) / (cnt - 1), s as Color])
	if out.size() == 1: out.append([1.0, out[0][1]])
	return out

## The colour of a stop list at k — flat before the first stop and after the last, like canvas.
static func _stop_col(st: Array, k: float) -> Color:
	if k <= st[0][0]: return st[0][1]
	for i in st.size() - 1:
		var k1: float = st[i + 1][0]
		if k <= k1:
			var k0: float = st[i][0]
			var f := 0.0 if k1 - k0 < 1e-6 else (k - k0) / (k1 - k0)
			return (st[i][1] as Color).lerp(st[i + 1][1], f)
	return st[st.size() - 1][1]

## The colour a canvas radial gradient has at p: inner point c + off (radius 0),
## outer circle (c, r). Ring k is centred c + off·(1−k) with radius r·k, so
## solving |p − c − off·(1−k)| = r·k for k is the whole formula.
static func _rad_at(p: Vector2, c: Vector2, r: float, off: Vector2, st: Array) -> Color:
	var q := p - c - off
	var a := off.length_squared() - r * r          # negative while the inner point stays inside
	var k: float
	if absf(a) < 1e-6: k = q.length() / r
	else:
		var bq := q.dot(off)
		k = (-bq - sqrt(maxf(bq * bq - a * q.length_squared(), 0.0))) / a
	return _stop_col(st, clampf(k, 0.0, 1.0))

## K.sphere's gradient, evaluated at a point — for a ball drawn inside a clip shape.
static func _sphere_at(p: Vector2, c: Vector2, r: float, col: Color, lx: float, ly: float, spec: float, dark: Variant = null) -> Color:
	var dk: Color = dark if dark != null else K.shade(col, -0.75)
	return _rad_at(p, c, r * 1.02, Vector2(lx, ly) * r * 0.55,
		[[0.0, K.shade(col, spec)], [0.35, col], [0.8, K.shade(col, -0.35)], [1.0, dk]])

## Where a horizontal line at y crosses a convex polygon: Vector2(left, right).
static func _poly_span(shape: PackedVector2Array, y: float) -> Vector2:
	var lo := INF
	var hi := -INF
	var cnt := shape.size()
	for i in cnt:
		var a := shape[i]
		var b2 := shape[(i + 1) % cnt]
		if absf(a.y - y) < 1e-6:
			lo = minf(lo, a.x); hi = maxf(hi, a.x)
		elif (a.y < y and b2.y > y) or (b2.y < y and a.y > y):
			var x := a.x + (y - a.y) * (b2.x - a.x) / (b2.y - a.y)
			lo = minf(lo, x); hi = maxf(hi, x)
	return Vector2(lo, hi)

## Triangles between two rows of vertex indices, both sorted by x — a merge walk.
static func _stitch(idx: PackedInt32Array, pts: PackedVector2Array, ra: PackedInt32Array, rb: PackedInt32Array) -> void:
	var m := ra.size() - 1
	var nn := rb.size() - 1
	var i := 0
	var j := 0
	while i < m or j < nn:
		if j >= nn or (i < m and pts[ra[i + 1]].x <= pts[rb[j + 1]].x):
			idx.append(ra[i]); idx.append(ra[i + 1]); idx.append(rb[j]); i += 1
		else:
			idx.append(ra[i]); idx.append(rb[j]); idx.append(rb[j + 1]); j += 1

## A gradient inside a CONVEX outline — the canvas clip() we don't have. Rows
## of vertices `step` apart, each cut to the shape's width at that height,
## each vertex coloured by col_at(point), all stitched into ONE triangle array.
static func _grad_convex(n: CanvasItem, shape: PackedVector2Array, step: float, col_at: Callable) -> void:
	var y0 := INF
	var y1 := -INF
	for p in shape:
		y0 = minf(y0, p.y); y1 = maxf(y1, p.y)
	if y1 - y0 < 0.01: return
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var prev := PackedInt32Array()
	var rows := int(ceil((y1 - y0) / step))
	for j in rows + 1:
		var y := minf(y0 + j * step, y1)
		var span := _poly_span(shape, y)
		if span.x > span.y: continue
		var row := PackedInt32Array()
		var x := span.x
		var gx := floorf(span.x / step + 1.0) * step      # the first grid column inside the span
		while true:
			row.append(pts.size())
			pts.append(Vector2(x, y))
			cols.append(col_at.call(Vector2(x, y)))
			if x >= span.y: break
			x = minf(gx, span.y); gx += step
		if prev.size() > 0: _stitch(idx, pts, prev, row)
		prev = row
	if idx.size() >= 3:
		RenderingServer.canvas_item_add_triangle_array(n.get_canvas_item(), idx, pts, cols)

## A polygon whose colour runs from c0 at y0 to c1 at y1 — exact for any outline,
## because a linear ramp stays linear across every triangle.
static func _lin_y_poly(n: CanvasItem, pts: PackedVector2Array, y0: float, c0: Color, y1: float, c1: Color) -> void:
	if pts.size() < 3: return
	var cols := PackedColorArray()
	for p in pts:
		cols.append(c0.lerp(c1, clampf((p.y - y0) / (y1 - y0), 0.0, 1.0)))
	n.draw_polygon(pts, cols)

## Points on an ellipse arc, a0 → a1 (a full disc when a1 − a0 = TAU).
static func _arc(c: Vector2, rx: float, ry: float, a0: float, a1: float, segs: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var full := absf(a1 - a0 - TAU) < 1e-6
	var cnt := segs if full else segs + 1
	for i in cnt:
		var ang := a0 + (a1 - a0) * float(i) / segs
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts

static func _disc(c: Vector2, r: float, segs := 48) -> PackedVector2Array:
	return _arc(c, r, r, 0.0, TAU, segs)

static func _rect_pts(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])

## A small centred caption anywhere (the kit's label only knows bottom-centre).
static func _cap(n: CanvasItem, x: float, y: float, txt: String) -> void:
	var f := ThemeDB.fallback_font
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	n.draw_string(f, Vector2(x - w / 2.0 + 0.7, y + 0.7), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.04, 0.03, 0.08, 0.55))
	n.draw_string(f, Vector2(x - w / 2.0, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.91, 0.9, 0.96, 0.75))

## The urn's lathe profile: k = 0 at the lip … 1 at the foot → half-width as a share of wmax.
static func _prof(k: float) -> float:
	if k < 0.05: return 0.44                                            # the lip
	if k < 0.2: return 0.3 + (k - 0.05) * 0.4                           # the neck, widening
	if k < 0.86: return 0.36 + 0.64 * sin((k - 0.2) / 0.66 * PI)        # the belly: half a sine
	if k < 0.94: return 0.3                                             # the stem
	return 0.46                                                         # the foot

static func defs() -> Array:
	var d: Array = []

	# ---- O · Orb -----------------------------------------------------------
	d.append({ "letter": "O", "name": "Orb",
		"hint": "one big ball: a radial gradient with its inner point pushed toward the light — that offset IS the roundness; the contact shadow leans the other way",
		"dials": { "bg": [Color("1C1A32"), Color("0B0A16")], "ball": Color("5A8FE8"), "rim": Color("8AD9F5"), "spec": 0.5,
			"lx": -0.55, "ly": -0.6, "shadowA": 0.55,
			"label": "highlight toward the light, core shadow opposite, rim light on the far edge — the offset is the roundness" },
		"rhyme": { "name": "Matte orb", "hint": "the same ball with the highlight turned off and no rim light — chalk instead of plastic; a minimalist print",
			"dials": { "bg": [Color("ECEAF0"), Color("C8C6D0")], "ball": Color("D8D6DE"), "rim": null, "spec": 0.0, "shadowA": 0.7,
				"label": "spec 0, no rim: with no highlight the core shadow does all the work — value alone makes a ball" } },
		"init": func(b: Dictionary) -> void:
			b.cx = b.W * 0.5; b.cy = b.H * 0.46; b.r = minf(b.W, b.H) * 0.27; b.GY = b.cy + b.r * 1.12,
		"press": func(b: Dictionary, pos: Vector2) -> void:                # click = put the light there
			b.D.lx = clampf((pos.x - b.cx) / (b.r * 1.7), -1.0, 1.0); b.D.ly = clampf((pos.y - b.cy) / (b.r * 1.7), -1.0, 1.0),
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var cx: float = b.cx; var cy: float = b.cy; var r: float = b.r
			K.sky(n, b, D.bg)
			K.ground(n, b, b.GY, Color("0A0916"))
			K.shadow(n, Vector2(cx - D.lx * r * 0.6, b.GY), r * 1.1, r * 0.26, D.shadowA)     # the contact shadow leans AWAY from the light
			K.sphere(n, Vector2(cx, cy), r, D.ball, D.lx, D.ly, D.spec, null, D.rim)         # one radial gradient, inner point offset by lx, ly
			var px: float = cx + D.lx * r * 1.7; var py: float = cy + D.ly * r * 1.7        # the light itself: a tiny dot, so you can see the pairing
			K.soft(n, Vector2(px, py), r * 0.25, Color("FFF3D0"), 0.7); K.dot(n, Vector2(px, py), 2.5, Color("FFF9E8"))
			K.label(n, b, D.label) })

	# ---- C · Column --------------------------------------------------------
	d.append({ "letter": "C", "name": "Column",
		"hint": "three pillars: a horizontal gradient dark → light → dark is the entire cylinder — plus a paler ellipse on top so the lid reads as flat",
		"dials": { "bg": [Color("2A2444"), Color("151226")], "stone": Color("B8A88C"), "cols": 3, "capLight": 0.45, "lx": -0.3,
			"label": "a cylinder is one horizontal gradient: bright where it faces the lamp, dark where it turns away" },
		"rhyme": { "name": "Marble columns", "hint": "the same pillars in pale marble, five instead of three, with softer lids — a colonnade",
			"dials": { "bg": [Color("D8DCE8"), Color("8A90A8")], "stone": Color("E8E4DC"), "cols": 5, "capLight": 0.3,
				"label": "paler stone, five pillars: the bright stripe sits on the same side of every one — one light, many cylinders" } },
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.lx = clampf((pos.x / b.W - 0.5) * 2.0, -1.0, 1.0),   # click where the light is
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			K.sky(n, b, D.bg)
			var cols: int = D.cols
			var GY: float = b.H * 0.8; var h: float = b.H * 0.5; var w: float = b.W / (cols * 2.4)
			K.ground(n, b, GY, Color("0E0C1A"))
			for i in cols:
				var x: float = b.W * (i + 0.5) / cols
				K.shadow(n, Vector2(x - D.lx * w * 1.2, GY), w * 1.3, w * 0.32, 0.5)          # each pillar's contact shadow, leaning away from the light
				K.cyl(n, x, GY, w, h, D.stone, D.lx)                                          # dark → light → dark; the darkest stripe is the terminator
				K.ellipse(n, Vector2(x, GY - h), w / 2.0, w * 0.18, K.shade(D.stone, D.capLight))   # the lid faces up, so it catches the most light
				K.poly(n, _arc(Vector2(x, GY), w / 2.0, w * 0.18, 0.0, PI, 16), K.shade(D.stone, -0.5))   # the base ring, curving into shadow
			K.label(n, b, D.label) })

	# ---- D · Dome ----------------------------------------------------------
	d.append({ "letter": "D", "name": "Dome",
		"hint": "a hemisphere on a plinth: half a shaded ball above a clip line, a short cylinder it sits on, and a cast shadow that says how tall it is",
		"dials": { "bg": [Color("3A4A6A"), Color("1A1E30")], "dome": Color("C8B8A0"), "base": Color("6A6A78"), "slit": null,   # slit: x of a dark slot (share of r), or null
			"lx": -0.6, "ly": -0.5,
			"label": "half a sphere is still a sphere: the highlight, terminator and cast shadow all agree on one light" },
		"rhyme": { "name": "Observatory", "hint": "the same dome at night, steel-blue, with one dark slot cut into it — the slot is the only flat thing in the picture",
			"dials": { "bg": [Color("05061A"), Color("141838")], "dome": Color("8A93A8"), "base": Color("3A3E50"), "slit": 0.15,
				"label": "a night palette and one dark slot: the slot is flat, so it reads as a cut INTO the round" } },
		"init": func(b: Dictionary) -> void:
			b.cx = b.W * 0.5; b.r = minf(b.W, b.H) * 0.3; b.by = b.H * 0.66                  # by: the line the dome stands on
			var c := Vector2(b.cx, b.by)
			var shape := _arc(c, b.r, b.r, PI, TAU, 40)                                    # the ball's top half…
			shape.append_array(_arc(c, b.r, b.r * 0.22, 0.0, PI, 24))                       # …and its lower rim, curving toward us
			b.shape = shape,
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.D.lx = clampf((pos.x - b.cx) / (b.r * 1.6), -1.0, 1.0); b.D.ly = clampf((pos.y - (b.by - b.r * 0.4)) / (b.r * 1.6), -1.0, 1.0),
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var cx: float = b.cx; var r: float = b.r; var by: float = b.by
			K.sky(n, b, D.bg)
			K.ground(n, b, b.H * 0.72, Color("14121F"))
			K.shadow(n, Vector2(cx - D.lx * r * 1.1, by + r * 0.16), r * 1.3, r * 0.32, 0.5)   # the cast shadow: it leans away, and it is as long as the dome is tall
			K.cyl(n, cx, by + r * 0.16, r * 2.6, r * 0.16, D.base, D.lx)                     # the plinth is a very short cylinder
			K.ellipse(n, Vector2(cx, by), r * 1.3, r * 0.3, K.shade(D.base, 0.3))            # its lid, lit from above
			var c := Vector2(cx, by)
			var dome: Color = D.dome; var lx: float = D.lx; var ly: float = D.ly
			_grad_convex(n, b.shape, 4.0, func(p: Vector2) -> Color: return _sphere_at(p, c, r, dome, lx, ly, 0.4))   # the ball, cut at the clip line
			if D.slit != null:
				var s: float = D.slit
				K.poly(n, PackedVector2Array([Vector2(cx + s * r - r * 0.05, by), Vector2(cx + s * r + r * 0.05, by),
					Vector2(cx + s * r * 0.3 + r * 0.03, by - r * 0.99), Vector2(cx + s * r * 0.3 - r * 0.03, by - r * 0.99)]), Color("08080F"))
			K.label(n, b, D.label) })

	# ---- E · Egg -----------------------------------------------------------
	d.append({ "letter": "E", "name": "Egg",
		"hint": "an egg is a ball under ctx.scale(0.76, 1): the same offset gradient, squeezed — a warm shadow side, a soft ground shadow, and a slow rock",
		"dials": { "bg": [Color("EAD8C0"), Color("C8A888")], "shell": Color("F2E4CC"), "dark": Color("8A5A3A"), "spec": 0.4,   # dark: warm, because the ground bounces light into it
			"squeeze": 0.76, "rock": 1.3, "lx": -0.5, "ly": -0.6,                                                          # squeeze: width ÷ height; rock: how fast it sways
			"label": "the shadow side is warm, not black — bounced light fills it; the highlight stays with the lamp, not the egg" },
		"rhyme": { "name": "Dragon egg", "hint": "the same egg in dark red lacquer with a hotter highlight, narrower and slower — a fantasy prop",
			"dials": { "bg": [Color("2A0A10"), Color("0C0406")], "shell": Color("7A1424"), "dark": Color("200408"), "spec": 0.9,
				"squeeze": 0.72, "rock": 0.6,
				"label": "a darker shell with a hotter highlight reads as lacquer — spec is the material dial" } },
		"init": func(b: Dictionary) -> void:
			b.cx = b.W * 0.5; b.cy = b.H * 0.47; b.r = minf(b.W, b.H) * 0.3; b.GY = b.cy + b.r * 1.02,
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.D.lx = clampf((pos.x - b.cx) / (b.r * 1.6), -1.0, 1.0); b.D.ly = clampf((pos.y - b.cy) / (b.r * 1.6), -1.0, 1.0),
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var cx: float = b.cx; var cy: float = b.cy; var r: float = b.r
			K.sky(n, b, D.bg)
			K.ground(n, b, b.GY, Color("8A6A50"))
			var a: float = sin(t * D.rock) * 0.12                                            # the sway, in radians
			var llx: float = D.lx * cos(a) + D.ly * sin(a)                                    # the light, seen from the egg's own tilted frame
			var lly: float = -D.lx * sin(a) + D.ly * cos(a)
			K.shadow(n, Vector2(cx - D.lx * r * 0.5 + a * r * 2.0, b.GY), r * 0.9, r * 0.2, 0.4)
			n.draw_set_transform(Vector2(cx, cy), a, Vector2(D.squeeze, 1.0))
			K.sphere(n, Vector2.ZERO, r, D.shell, llx, lly, D.spec, D.dark)                  # one ball, squeezed: the gradient squeezes with it
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			K.label(n, b, D.label) })

	# ---- E · Eyeball -------------------------------------------------------
	d.append({ "letter": "E", "name": "Eyeball",
		"hint": "a white ball with an iris disc that slides to look at you — the pupil moves, the highlight stays put on the light's side, and that difference sells the roundness",
		"dials": { "bg": [Color("2A1E3A"), Color("120C1E")], "white": Color("F2EEF0"), "hue": 200.0, "asp": 1.0,   # asp: pupil width ÷ height — 1 is round, 0.25 a cat's slit
			"lx": -0.5, "ly": -0.55, "follow": 6.0,                                                            # follow: how quickly the eye catches up
			"label": "the iris slides, the highlight doesn't — a highlight is the lamp's reflection, so it stays on the lamp's side" },
		"rhyme": { "name": "Cat eye", "hint": "the same eye in yellow-green with a slit pupil (an ellipse squeezed to a quarter width) that snaps to the pointer",
			"dials": { "bg": [Color("1A1A0E"), Color("0A0A06")], "white": Color("E8E0C8"), "hue": 85.0, "asp": 0.25, "follow": 12.0,
				"label": "the pupil is an ellipse dial: asp 0.25 makes a slit, and the slit slides under a highlight that never moves" } },
		"init": func(b: Dictionary) -> void:
			b.cx = b.W * 0.5; b.cy = b.H * 0.47; b.r = minf(b.W, b.H) * 0.3
			b.tx = 0.25; b.ty = 0.1; b.px = 0.25; b.py = 0.1,                                  # where it wants to look, and where the pupil actually is (it lags)
		"tick": func(b: Dictionary, dt: float) -> void:
			var k: float = minf(1.0, dt * b.D.follow)
			b.px += (b.tx - b.px) * k; b.py += (b.ty - b.py) * k,
		"press": func(b: Dictionary, pos: Vector2) -> void:                                   # click = look there
			b.tx = clampf((pos.x - b.cx) / b.r, -1.0, 1.0); b.ty = clampf((pos.y - b.cy) / b.r, -1.0, 1.0),
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var cx: float = b.cx; var cy: float = b.cy; var r: float = b.r
			K.sky(n, b, D.bg)
			K.ground(n, b, cy + r * 1.1, Color("0C0A16"))
			K.shadow(n, Vector2(cx - D.lx * r * 0.6, cy + r * 1.1), r * 1.05, r * 0.25, 0.5)
			K.sphere(n, Vector2(cx, cy), r, D.white, D.lx, D.ly, 0.15, Color("8A7A8A"))
			var px: float = b.px; var py: float = b.py
			var dist := sqrt(px * px + py * py); var sq := 1.0 - 0.35 * dist; var ang := atan2(py, px)   # the iris foreshortens as it turns toward the edge
			var ir := r * 0.42
			var xf := Transform2D(0.0, Vector2(cx + px * r * 0.5, cy + py * r * 0.5)) * Transform2D(ang, Vector2.ZERO) \
				* Transform2D(0.0, Vector2(sq, 1.0), 0.0, Vector2.ZERO) * Transform2D(-ang, Vector2.ZERO)   # squeeze along the look direction only
			n.draw_set_transform_matrix(xf)
			K.radial(n, Vector2.ZERO, ir, [[0.0, K.hsl(D.hue, 0.6, 0.55)], [0.7, K.hsl(D.hue, 0.7, 0.35)], [1.0, K.hsl(D.hue, 0.5, 0.12)]])   # the iris: a centred radial — flat, painted ON the ball
			K.ellipse(n, Vector2.ZERO, ir * 0.42 * D.asp, ir * 0.42, Color("08060C"))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			K.soft(n, Vector2(cx + D.lx * r * 0.5, cy + D.ly * r * 0.5), r * 0.16, Color.WHITE, 0.95)   # the highlight belongs to the light, not to the eye
			K.label(n, b, D.label) })

	# ---- J · Jupiter -------------------------------------------------------
	d.append({ "letter": "J", "name": "Jupiter",
		"hint": "a banded planet: flat wobbly stripes clipped to a disc, then one radial gradient — clear in the middle, dark at the rim, offset toward the sun — lays the roundness on top",
		"dials": { "bg": [Color("050510"), Color("0B0A18")],
			"bands": [Color("D9B48A"), Color("A8734A"), Color("E8D2B0"), Color("B8865A"), Color("F0E0C8"), Color("8A5A3A"), Color("D9B48A"), Color("C29060"), Color("E8D2B0")],
			"spot": Color("C05A3A"), "night": Color("050510"), "speed": 0.25, "lx": -0.6, "ly": -0.3,   # speed: how fast the bands slide
			"label": "the stripes are flat; the dark overlay is the whole sphere — the terminator is where it fades to night" },
		"rhyme": { "name": "Candy planet", "hint": "the same striped planet in pastels with a pink spot, bands sliding twice as fast — cozy sci-fi",
			"dials": { "bg": [Color("1A1030"), Color("2A1E4A")],
				"bands": [Color("F5C0D8"), Color("B8E8F5"), Color("FFF0B8"), Color("C8F5C8"), Color("F5D0F5"), Color("B8D8F5"), Color("FFD8C0"), Color("D8F5E8"), Color("F5C0D8")],
				"spot": Color("FF7AA8"), "night": Color("1A1030"), "speed": 0.6,
				"label": "pastel stripes, same dark overlay — the roundness lives in the overlay, not in the colours" } },
		"init": func(b: Dictionary) -> void:
			b.cx = b.W * 0.5; b.cy = b.H * 0.48; b.r = minf(b.W, b.H) * 0.36
			b.disc = _disc(Vector2(b.cx, b.cy), b.r, 64)
			var R := K.rng(7)
			b.stars = []
			for s in 40: b.stars.append(Vector3(R.randf() * b.W, R.randf() * b.H, 0.3 + R.randf() * 1.0)),
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.D.lx = clampf((pos.x - b.cx) / (b.r * 1.6), -1.0, 1.0); b.D.ly = clampf((pos.y - b.cy) / (b.r * 1.6), -1.0, 1.0),
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var cx: float = b.cx; var cy: float = b.cy; var r: float = b.r
			K.sky(n, b, D.bg)
			for s in b.stars: K.dot(n, Vector2(s.x, s.y), s.z, K.alpha(K.INK, 0.6))
			var disc: PackedVector2Array = b.disc
			var bands: Array = D.bands
			var nb := bands.size(); var bh := (2.0 * r) / nb
			for i in nb:                                                                      # each band: a strip with a wobbly top, painted top → bottom
				var top := cy - r + i * bh
				var sp: float = D.speed * (1.0 + (i % 3) * 0.7) * (1.0 if i % 2 == 1 else -1.0)   # neighbours slide at different speeds and directions
				var strip := PackedVector2Array([Vector2(cx - r, cy + r)])
				var x := cx - r
				while x <= cx + r + 8.0:
					strip.append(Vector2(x, top + sin(x / r * 3.0 + t * sp) * bh * 0.25 + sin(x / r * 7.0 - t * sp * 1.7) * bh * 0.1))
					x += 8.0
				strip.append(Vector2(cx + r + 8.0, cy + r))
				for piece in Geometry2D.intersect_polygons(strip, disc): K.poly(n, piece, bands[i])   # the clip: strip ∩ disc
			var sx: float = cx + fmod(t * D.speed * 0.3 * r, 2.6 * r) - 1.3 * r                 # the great spot, crossing and wrapping
			for piece in Geometry2D.intersect_polygons(_arc(Vector2(sx, cy + r * 0.3), r * 0.22, r * 0.12, 0.0, TAU, 24), disc):
				K.poly(n, piece, D.spot)
			var c := Vector2(cx, cy); var off := Vector2(D.lx, D.ly) * r * 0.5
			var st := _stops([[0.0, Color(1.0, 0.94, 0.86, 0.18)], [0.45, Color(0, 0, 0, 0)], [0.8, Color(5 / 255.0, 5 / 255.0, 16 / 255.0, 0.55)], [1.0, K.alpha(D.night, 0.98)]])
			_grad_convex(n, disc, 4.0, func(p: Vector2) -> Color: return _rad_at(p, c, r * 1.02, off, st))   # the roundness: one overlay, clear in the middle, dark at the rim, shifted toward the sun
			K.label(n, b, D.label) })

	# ---- L · Lozenge -------------------------------------------------------
	d.append({ "letter": "L", "name": "Lozenge",
		"hint": "a capsule: a cylinder between two half-balls, all shaded from ONE light — it turns slowly, but the highlight stays on the light's side",
		"dials": { "bg": [Color("1E2A3A"), Color("0C1018")], "pill": Color("E86A8A"), "spin": 0.3, "len": 1.8,   # len: the body's length in radii; spin: turns per second-ish
			"lx": -0.5, "ly": -0.6,
			"label": "three shapes, one light: the caps' highlight and the body's bright stripe meet because they agree on lx, ly" },
		"rhyme": { "name": "Pixel pill", "hint": "the same capsule in arcade green, shorter and spinning four times as fast — a power-up",
			"dials": { "bg": [Color("0A0A14"), Color("101020")], "pill": Color("3AF06A"), "spin": 1.2, "len": 1.2,
				"label": "arcade green, a shorter body, four times the spin — the highlight still refuses to turn with the pill" } },
		"init": func(b: Dictionary) -> void:
			b.cx = b.W * 0.5; b.cy = b.H * 0.45; b.r = minf(b.W, b.H) * 0.15; b.GY = b.H * 0.82,
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.D.lx = clampf((pos.x - b.cx) / (b.r * 3.0), -1.0, 1.0); b.D.ly = clampf((pos.y - b.cy) / (b.r * 3.0), -1.0, 1.0),
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var cx: float = b.cx; var cy: float = b.cy; var r: float = b.r
			K.sky(n, b, D.bg)
			K.ground(n, b, b.GY, Color("08090F"))
			var a: float = t * D.spin; var L: float = r * D.len; var ca := cos(a); var sa := sin(a)
			var llx: float = D.lx * ca + D.ly * sa                                             # the light, seen from the pill's own turning frame
			var lly: float = -D.lx * sa + D.ly * ca
			K.shadow(n, Vector2(cx - D.lx * r * 0.8, b.GY), L * absf(ca) * 0.5 + r * 1.2, r * 0.35, 0.45)   # the shadow is as long as the pill looks
			n.draw_set_transform(Vector2(cx, cy), a, Vector2.ONE)
			K.sphere(n, Vector2(-L / 2.0, 0.0), r, D.pill, llx, lly)                          # the caps: two balls; the body drawn next hides their inner halves
			K.sphere(n, Vector2(L / 2.0, 0.0), r, D.pill, llx, lly)                           # (the web clips each to its outer half — same picture)
			var hi := clampf(0.5 + lly * 0.28, 0.05, 0.95)                                     # the body's bright stripe, lined up with the caps' highlight
			K.lin_rect(n, Rect2(-L / 2.0, -r, L, 2.0 * r),
				[[0.0, K.shade(D.pill, -0.55)], [hi, K.shade(D.pill, 0.35)], [clampf(hi + 0.3, 0.0, 1.0), D.pill], [1.0, K.shade(D.pill, -0.75)]])   # a cylinder lying down, so its gradient runs across
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			K.label(n, b, D.label) })

	# ---- P · Pearl ---------------------------------------------------------
	d.append({ "letter": "P", "name": "Pearl",
		"hint": "a small ball with a wide soft highlight, a rim light from behind, and two hues bleeding across the highlight — nacre is a sphere plus a colour shift",
		"dials": { "bg": [Color("2A1A2E"), Color("0E0812")], "pearl": Color("E8E0E6"), "rim": Color("F5C0E0"), "dark": Color("8A7A90"),   # rim: the back-light leaking round the edge
			"hueA": 320.0, "hueB": 190.0, "cushion": Color("3A1A34"), "lx": -0.45, "ly": -0.55,                                        # hueA, hueB: the two tints either side of the highlight
			"label": "rim light: a little light round the back edge lifts the ball off what's behind it — wide highlight = soft surface" },
		"rhyme": { "name": "Black pearl", "hint": "the same pearl in near-black on a leather cushion, with a cyan rim and violet-green tints — a pirate's prize",
			"dials": { "bg": [Color("1A1410"), Color("080604")], "pearl": Color("2A2A38"), "rim": Color("8AD9F5"), "dark": Color("08080E"),
				"hueA": 260.0, "hueB": 160.0, "cushion": Color("4A2A18"),
				"label": "a dark pearl is mostly rim light and colour shift — take the base colour away and the edge still says round" } },
		"init": func(b: Dictionary) -> void:
			b.cx = b.W * 0.5; b.cy = b.H * 0.5; b.r = minf(b.W, b.H) * 0.2; b.GY = b.cy + b.r * 0.85
			b.disc = _disc(Vector2(b.cx, b.cy), b.r, 48)
			var yc: float = b.GY + b.r * 0.5                                                   # the cushion: an ellipse mound on a rect, cut to the card
			var mound := PackedVector2Array([Vector2(0, b.H)])
			for i in 25:
				var x: float = b.W * i / 24.0
				mound.append(Vector2(x, yc - b.r * 1.6 * sqrt(maxf(0.0, 1.0 - pow((x - b.cx) / (b.W * 0.7), 2.0)))))
			mound.append(Vector2(b.W, b.H))
			b.mound = mound,
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.D.lx = clampf((pos.x - b.cx) / (b.r * 2.5), -1.0, 1.0); b.D.ly = clampf((pos.y - b.cy) / (b.r * 2.5), -1.0, 1.0),
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var cx: float = b.cx; var cy: float = b.cy; var r: float = b.r
			K.sky(n, b, D.bg)
			var mc := Vector2(cx, b.GY + r * 0.5); var moff := Vector2(D.lx * b.W * 0.2, -r)
			var mst := _stops([[0.0, K.shade(D.cushion, 0.25)], [0.5, D.cushion], [1.0, K.shade(D.cushion, -0.6)]])
			var mr: float = b.W * 0.7
			_grad_convex(n, b.mound, 6.0, func(p: Vector2) -> Color: return _rad_at(p, mc, mr, moff, mst))   # the cushion: a soft mound, lit from the same side
			K.shadow(n, Vector2(cx - D.lx * r * 0.4, b.GY), r * 1.1, r * 0.3, 0.6)             # the dent it sits in — a contact shadow, tight and dark
			K.sphere(n, Vector2(cx, cy), r, D.pearl, D.lx, D.ly, 0.55, D.dark, D.rim)
			var hx: float = cx + D.lx * r * 0.5; var hy: float = cy + D.ly * r * 0.5
			var disc: PackedVector2Array = b.disc
			var glows := [[Vector2(hx - r * 0.2, hy + r * 0.15), r * 0.6, K.hsl(D.hueA, 0.8, 0.7), 0.35],   # two hues, one each side of the highlight
				[Vector2(hx + r * 0.25, hy - r * 0.1), r * 0.6, K.hsl(D.hueB, 0.8, 0.7), 0.35],
				[Vector2(hx, hy), r * 0.4, Color.WHITE, 0.7]]                                   # the highlight itself: wide and soft, because nacre is not glass
			for g in glows:                                                                    # each glow cut to the ball (the web's clip)
				var gc: Vector2 = g[0]; var gr: float = g[1]
				var gst := _stops([[0.0, K.alpha(g[2], g[3])], [1.0, K.alpha(g[2], 0.0)]])
				for piece in Geometry2D.intersect_polygons(disc, _disc(gc, gr, 32)):
					_grad_convex(n, piece, 3.0, func(p: Vector2) -> Color: return _rad_at(p, gc, gr, Vector2.ZERO, gst))
			K.label(n, b, D.label) })

	# ---- Q · Quicksilver ---------------------------------------------------
	d.append({ "letter": "Q", "name": "Quicksilver",
		"hint": "mirror ball beside matte ball: the matte one is a smooth radial; the mirror one is a sky band over a dark ground band, clipped to the disc, plus one sharp white dot",
		"dials": { "bg": [Color("2E3444"), Color("141824")], "matte": Color("7A8494"), "skyHi": Color("DCE8F5"), "skyLo": Color("8AA0C0"),   # what the mirror reflects: a sky…
			"groundHi": Color("5A4A3A"), "groundLo": Color("141010"), "lx": -0.5, "ly": -0.55,                                          # …over a ground
			"label": "same ball, two materials: a wide highlight says rough, a pinpoint highlight and a horizon say mirror" },
		"rhyme": { "name": "Gold ball", "hint": "the same two balls in gold: the mirror reflects a warm sky and a bronze ground, the matte one is brass",
			"dials": { "bg": [Color("3A2A18"), Color("141008")], "matte": Color("C89A3A"), "skyHi": Color("FFF0C0"), "skyLo": Color("D8A040"),
				"groundHi": Color("6A3A10"), "groundLo": Color("1A0C04"),
				"label": "tint the reflected sky and ground and the mirror turns to gold — a metal is whatever it reflects, warmed" } },
		"init": func(b: Dictionary) -> void:
			b.r = minf(b.W, b.H) * 0.2; b.cy = b.H * 0.47; b.ax = b.W * 0.28; b.bx = b.W * 0.72; b.GY = b.cy + b.r * 1.15
			b.disc = _disc(Vector2(b.bx, b.cy), b.r, 48),
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.D.lx = clampf((pos.x - b.W / 2.0) / (b.W * 0.5), -1.0, 1.0); b.D.ly = clampf((pos.y - b.cy) / (b.r * 2.0), -1.0, 1.0),
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var r: float = b.r; var cy: float = b.cy; var ax: float = b.ax; var bx: float = b.bx
			K.sky(n, b, D.bg)
			K.ground(n, b, b.GY, Color("0C0D14"))
			K.shadow(n, Vector2(ax - D.lx * r * 0.6, b.GY), r * 1.05, r * 0.25, 0.5)
			K.shadow(n, Vector2(bx - D.lx * r * 0.6, b.GY), r * 1.05, r * 0.25, 0.5)
			K.sphere(n, Vector2(ax, cy), r, D.matte, D.lx, D.ly, 0.4)                          # matte: the light spreads over the surface
			var disc: PackedVector2Array = b.disc
			var hz := cy + r * 0.12                                                            # the reflected horizon, a little below centre
			for piece in Geometry2D.intersect_polygons(_rect_pts(Rect2(bx - r, cy - r, 2.0 * r, hz - (cy - r))), disc):
				_lin_y_poly(n, piece, cy - r, D.skyLo, hz, D.skyHi)                           # the sky, reflected: dark overhead, pale at the horizon
			for piece in Geometry2D.intersect_polygons(_rect_pts(Rect2(bx - r, hz, 2.0 * r, cy + r - hz)), disc):
				_lin_y_poly(n, piece, hz, D.groundHi, cy + r, D.groundLo)                     # the ground, reflected: warm near the horizon, black below
			var c := Vector2(bx, cy); var off := Vector2(D.lx, D.ly) * r * 0.3
			var st := _stops([[0.6, Color(0, 0, 0, 0)], [1.0, Color(0, 0, 0, 0.55)]])
			_grad_convex(n, disc, 4.0, func(p: Vector2) -> Color: return _rad_at(p, c, r * 1.02, off, st))   # the rim darkens as the mirror curves away
			K.dot(n, Vector2(bx + D.lx * r * 0.55, cy + D.ly * r * 0.55), r * 0.09, Color.WHITE)   # mirror: the light itself, tiny and sharp
			_cap(n, ax, cy - r - 8.0, "matte"); _cap(n, bx, cy - r - 8.0, "mirror")
			K.label(n, b, D.label) })

	# ---- T · Torus ---------------------------------------------------------
	d.append({ "letter": "T", "name": "Torus",
		"hint": "a ring shaded as a donut: one radial gradient whose stops peak at the tube's middle radius, pushed toward the light — plus a dark wash across the far half",
		"dials": { "bg": [Color("1A2230"), Color("0A0E16")], "tube": Color("E8A040"), "dark": Color("3A2010"), "fat": 0.42,   # fat: tube radius ÷ ring radius; dark: both edges of the tube
			"spin": 0.4, "sprinkles": 0,                                                                                    # spin: how fast the light circles; sprinkles: 0 for a plain ring
			"label": "on the lit side the crown sits toward the outside, on the far side toward the hole — the offset does that for free" },
		"rhyme": { "name": "Doughnut", "hint": "the same ring with pink icing, brown edges, a fatter tube and 28 sprinkles — goofy and edible",
			"dials": { "bg": [Color("F5E6D8"), Color("D8C0A8")], "tube": Color("F58AB8"), "dark": Color("8A5A30"), "fat": 0.5,
				"spin": 0.25, "sprinkles": 28,
				"label": "pink crown, brown edges, 28 sprinkles: each sprinkle is a flat dash, so only the shading says the ring is fat" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			b.cx = b.W * 0.5; b.cy = b.H * 0.46; b.Ro = minf(b.W, b.H) * 0.34
			b.a = b.Ro * D.fat / (1.0 + D.fat); b.Rc = b.Ro - b.a; b.Ri = b.Rc - b.a               # tube radius, the tube's centre radius, the hole's radius
			var R := K.rng(5)
			b.sp = []
			for j in int(D.sprinkles):
				var an := R.randf() * TAU; var rr: float = b.Rc + (R.randf() - 0.5) * b.a * 1.3
				b.sp.append([Vector2(b.cx + cos(an) * rr, b.cy + sin(an) * rr), R.randf() * TAU, K.hsl(R.randf() * 360.0, 0.85, 0.6)])
			b.phase = 0.0
			b.hole = _disc(Vector2(b.cx, b.cy), b.Ri, 48),
		"press": func(b: Dictionary, pos: Vector2) -> void:                                   # click = put the light on that side
			b.phase = atan2(pos.y - b.cy, pos.x - b.cx) - b.t * b.D.spin,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var cx: float = b.cx; var cy: float = b.cy; var Ro: float = b.Ro; var a: float = b.a; var Rc: float = b.Rc; var Ri: float = b.Ri
			K.sky(n, b, D.bg)
			var GY := cy + Ro * 1.1
			K.ground(n, b, GY, Color("07080E"))
			var ang: float = t * D.spin + b.phase                                              # the light circles slowly; the ring itself never moves
			var lx := cos(ang) * 0.7; var ly := sin(ang) * 0.7
			K.shadow(n, Vector2(cx - lx * Ro * 0.4, GY), Ro * 1.1, Ro * 0.22, 0.5)
			var c := Vector2(cx, cy)
			K.radial(n, c, Ro, [[Ri / Ro, D.dark], [(Rc - a * 0.35) / Ro, K.shade(D.tube, 0.4)], [Rc / Ro, D.tube],
				[(Rc + a * 0.6) / Ro, K.shade(D.tube, -0.3)], [1.0, D.dark]], Vector2(lx, ly) * a * 0.9)   # dark at the hole, bright at the tube's crown, dark at the outer edge
			var u := Vector2(cos(ang), sin(ang)); var p1 := c + u * Ro                        # the far half turns away from the light: one linear wash
			var wst := _stops([[0.0, Color(0, 0, 0, 0)], [0.5, Color(0, 0, 0, 0.08)], [1.0, Color(0, 0, 0, 0.55)]])
			_grad_convex(n, _disc(c, Ro, 48), 4.0, func(p: Vector2) -> Color: return _stop_col(wst, clampf(-(p - p1).dot(u) / (2.0 * Ro), 0.0, 1.0)))
			var bg: Array = D.bg
			_lin_y_poly(n, b.hole, 0.0, bg[0], b.H, bg[1])                                      # the hole: the sky again — the ring's inner edge is where it starts
			for s in b.sp:
				n.draw_set_transform(s[0], s[1], Vector2.ONE)
				n.draw_rect(Rect2(-a * 0.14, -a * 0.05, a * 0.28, a * 0.1), s[2])
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			K.label(n, b, D.label) })

	# ---- U · Urn -----------------------------------------------------------
	d.append({ "letter": "U", "name": "Urn",
		"hint": "a vase from a lathe: 40 thin slices, each as wide as a profile function says, each a horizontal dark → light → dark cylinder gradient — round things from stacked rings",
		"dials": { "bg": [Color("3A3048"), Color("16121E")], "clay": Color("B86A48"), "band": Color("4A2A24"), "slices": 40,   # band: a painted stripe round the belly
			"lx": -0.35, "ly": -0.5,
			"label": "every slice is the Column trick; stack them at different widths and the highlight runs down the vase in one line" },
		"rhyme": { "name": "Sci-fi canister", "hint": "the same lathe profile in steel with a neon band and 24 fat slices — the rings now show, on purpose",
			"dials": { "bg": [Color("0A1420"), Color("04080E")], "clay": Color("6A7A8A"), "band": Color("40F0F0"), "slices": 24,
				"label": "steel grey, a neon band, 24 fatter slices — the same lathe, now visibly a stack of rings" } },
		"init": func(b: Dictionary) -> void:
			b.cx = b.W * 0.5; b.top = b.H * 0.12; b.bot = b.H * 0.8; b.Hh = b.bot - b.top
			b.wmax = minf(b.W * 0.2, b.Hh * 0.36),                                             # the belly's half-width
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.D.lx = clampf((pos.x - b.cx) / (b.W * 0.4), -1.0, 1.0); b.D.ly = clampf((pos.y - (b.top + b.bot) / 2.0) / (b.Hh * 0.6), -1.0, 1.0),
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var cx: float = b.cx; var top: float = b.top; var bot: float = b.bot; var wmax: float = b.wmax
			K.sky(n, b, D.bg)
			K.ground(n, b, bot, Color("0E0B14"))
			K.shadow(n, Vector2(cx - D.lx * wmax * 0.8, bot), wmax * 1.4, wmax * 0.3, 0.5)
			var slices: int = D.slices
			var sh: float = b.Hh / slices
			for i in slices:
				var k := (i + 0.5) / slices; var w := _prof(k) * wmax * 2.0
				var base: Color = D.band if (i > slices * 0.5 and i < slices * 0.58) else D.clay
				var c := K.shade(base, -D.ly * (0.5 - k) * 0.4)                                  # slices nearer a high light are a little brighter
				K.cyl(n, cx, top + (i + 1) * sh + 0.6, w, sh + 0.6, c, D.lx)                     # one short cylinder per slice; the widths draw the vase
			K.ellipse(n, Vector2(cx, top), _prof(0.0) * wmax * 0.85, sh * 1.2, K.shade(D.clay, -0.65))   # the mouth: we look down into the dark inside
			K.label(n, b, D.label) })

	# ---- Y · Yolk ----------------------------------------------------------
	d.append({ "letter": "Y", "name": "Yolk",
		"hint": "a fried egg: the white is a radial gradient that fades to nothing at its edge (that IS the translucency), the yolk a squashed ball with a hot highlight — tap it and it wobbles",
		"dials": { "pan": [Color("3A3236"), Color("1A1618")], "white": Color("FFFBF2"), "yolk": Color("F5A623"), "yolkDark": Color("B85A10"), "spec": 0.7,   # spec: wet things are hot
			"size": 1.0, "speckles": 0, "lx": -0.5, "ly": -0.6,                                                                              # size: the whole egg; speckles: dots on the white
			"label": "glossy = a tight hot highlight, matte = a wide one; the white's soft edge is the cheapest translucency there is" },
		"rhyme": { "name": "Quail yolk", "hint": "the same fried egg at two-thirds size with 30 speckles on the white and a deeper orange yolk — a smaller breakfast",
			"dials": { "pan": [Color("4A4238"), Color("1E1A14")], "yolk": Color("E88A10"), "spec": 0.8, "size": 0.62, "speckles": 30,
				"label": "smaller, speckled: the speckles are flat dots on the white, and the yolk's highlight is still what says ball" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			b.cx = b.W * 0.5; b.cy = b.H * 0.5; b.rw = minf(b.W, b.H) * 0.36 * D.size; b.ry = b.rw * 0.42   # rw: the white's radius; ry: the yolk's
			var R := K.rng(9)
			b.spk = []
			for j in int(D.speckles):
				var an := R.randf() * TAU; var dd := 0.55 + R.randf() * 0.4
				b.spk.append(Vector3(b.cx + cos(an) * b.rw * 1.15 * dd, b.cy + sin(an) * b.rw * 0.8 * dd, 0.6 + R.randf() * 1.2))
			var outline := PackedVector2Array()                                                # the white's wobbly edge, in its own squashed frame
			for i in 24:
				var an := i / 24.0 * TAU
				var rr: float = b.rw * (0.9 + 0.1 * sin(an * 3.0 + 1.0) + 0.05 * sin(an * 5.0))
				outline.append(Vector2(cos(an) * rr, sin(an) * rr))
			b.outline = outline
			b.jig = 0.0; b.vel = 0.0,                                                            # the spring: how squashed the yolk is, and how fast that's changing
		"tick": func(b: Dictionary, dt: float) -> void:
			b.vel += (-b.jig * 90.0 - b.vel * 5.0) * dt                                        # stiffness 90, damping 5
			b.jig = clampf(b.jig + b.vel * dt, -0.45, 0.45),
		"press": func(b: Dictionary, _pos: Vector2) -> void: b.vel += 2.5,                     # a poke; the spring takes it from here
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var cx: float = b.cx; var cy: float = b.cy; var rw: float = b.rw; var ry: float = b.ry
			K.radial(n, Vector2(cx, cy), b.W * 0.7, D.pan)                                     # the pan, lit from the middle (the disc covers the card)
			n.draw_set_transform(Vector2(cx, cy), 0.0, Vector2(1.25, 0.9))
			var wst := _stops([[0.0, D.white], [0.7, D.white], [0.88, K.alpha(D.white, 0.8)], [1.0, K.alpha(D.white, 0.0)]])
			_grad_convex(n, b.outline, 5.0, func(p: Vector2) -> Color: return _rad_at(p, Vector2.ZERO, rw, Vector2.ZERO, wst))   # the white thins to nothing at its edge
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for s in b.spk: K.dot(n, Vector2(s.x, s.y), s.z, Color("6A4A3A"))
			K.shadow(n, Vector2(cx - D.lx * ry * 0.3, cy + ry * 0.55), ry * 1.1, ry * 0.4, 0.25)   # the yolk's contact shadow on the white
			var jig: float = b.jig
			n.draw_set_transform(Vector2(cx, cy + ry * 0.1), 0.0, Vector2(1.0 + jig, 0.78 - jig))   # squash one way, stretch the other: volume looks kept
			K.sphere(n, Vector2.ZERO, ry, D.yolk, D.lx, D.ly, D.spec, D.yolkDark)              # the yolk: a ball, flattened
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			K.label(n, b, D.label) })

	# ---- Z · Zeppelin ------------------------------------------------------
	d.append({ "letter": "Z", "name": "Zeppelin",
		"hint": "an airship is a ball under ctx.scale(2.4, 1): one stretched radial gradient, a gondola, two fins — all lit from one side — and a faint shadow on the cloud floor far below",
		"dials": { "sky": [Color("6FA8E8"), Color("CFE6F5")], "hull": Color("D8D0C0"), "hullDark": Color("4A5060"), "gondola": Color("3A3038"),   # hullDark: cool, because the sky lights it
			"stretch": 2.4, "speed": 0.6, "lx": -0.5, "ly": -0.6,                                                                       # stretch: length ÷ height; speed: the drift
			"label": "one light for everything: hull, fins and gondola agree, and the shadow is faint because the floor is far" },
		"rhyme": { "name": "Steampunk zeppelin", "hint": "the same airship in brass under a sepia sky, longer and drifting at half speed — Victorian sci-fi",
			"dials": { "sky": [Color("A88A5A"), Color("E8D8B8")], "hull": Color("B8863A"), "hullDark": Color("3A2810"), "gondola": Color("4A3018"),
				"stretch": 2.8, "speed": 0.25,
				"label": "brass and sepia, a longer hull, half the drift — the stretched gradient stretches as far as you like" } },
		"init": func(b: Dictionary) -> void:
			b.r = minf(b.W, b.H) * 0.11; b.cy = b.H * 0.4; b.GY = b.H * 0.78
			var R := K.rng(6)
			b.puffs = []
			for j in 12: b.puffs.append(Vector3(R.randf() * b.W, b.GY + R.randf() * (b.H - b.GY) * 0.6, b.W * (0.06 + R.randf() * 0.08))),
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.D.lx = clampf((pos.x - b.W / 2.0) / (b.W * 0.5), -1.0, 1.0); b.D.ly = clampf((pos.y - b.cy) / (b.r * 3.0), -1.0, 1.0),
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var r: float = b.r; var cy: float = b.cy; var GY: float = b.GY
			K.sky(n, b, D.sky)
			var f0 := Color("F5F7FA").lerp(Color("B8C8DC"), 10.0 / (b.H - GY + 10.0))          # the web's ramp starts 10px above the floor; this is its colour AT the floor
			K.lin_rect(n, Rect2(0, GY, b.W, b.H - GY), [f0, Color("B8C8DC")])                  # the cloud floor
			for pf in b.puffs: K.soft(n, Vector2(pf.x, pf.y), pf.z, Color.WHITE, 0.7)
			var span: float = b.W + r * D.stretch * 2.6
			var bx: float = fmod(t * D.speed * 40.0, span) - r * D.stretch * 1.3                 # drifts across, then wraps
			var by := cy + sin(t * 0.7) * r * 0.25
			K.shadow(n, Vector2(bx - D.lx * r * 0.5, GY + 6.0), r * D.stretch * 0.9, r * 0.28, 0.18)   # far below: faint and soft, like the clouds it lands on
			var tail: float = bx - r * D.stretch * 0.75
			K.poly(n, PackedVector2Array([Vector2(tail, by - r * 0.4), Vector2(tail - r * 0.9, by - r * 1.3), Vector2(tail - r * 0.55, by)]), K.shade(D.hull, 0.1))    # the top fin faces the light…
			K.poly(n, PackedVector2Array([Vector2(tail, by + r * 0.4), Vector2(tail - r * 0.9, by + r * 1.3), Vector2(tail - r * 0.55, by)]), K.shade(D.hull, -0.5))   # …the bottom fin doesn't
			n.draw_set_transform(Vector2(bx, by), 0.0, Vector2(D.stretch, 1.0))
			K.sphere(n, Vector2.ZERO, r, D.hull, D.lx, D.ly, 0.3, D.hullDark)                  # the hull: one ball, stretched — the gradient stretches with it
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			n.draw_rect(Rect2(bx - r * 0.5, by + r * 0.85, r, r * 0.35), D.gondola)             # the gondola hangs under the belly
			K.label(n, b, D.label, Color(20 / 255.0, 24 / 255.0, 40 / 255.0, 0.75)) })         # dark ink: the floor is pale

	return d
