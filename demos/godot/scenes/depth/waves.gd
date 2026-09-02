extends RefCounted
## WAVES & RIBBONS — 13 pictures, ported from the web atlas (docs/depth.js).
## A moving surface looks solid the moment its SHADE follows its SLOPE. The
## slope of a sine is its cosine — so shade each strip by cos and the side
## facing the light goes pale, the side facing away goes dark, and a flat
## wiggle becomes a fold. A ribbon adds one rule: its apparent width is
## |cos(twist)|, and when cos turns negative you are looking at the BACK,
## so the colour flips. Rows of sea recede the way every horizon does —
## spacing bunches toward the horizon (horizon + p²), far rows lose their
## amplitude and mix toward the air.
##
## Each def: letter, name, hint, dials (D), rhyme { name, hint, dials } and
## the callables init(b) / tick(b, dt) / press(b, pos) / draw(n, b). The
## rhyme's dials are merged over D on right-click — nothing else changes.
##
## The canvas page fills wavy paths with `lin` gradients; Godot has no such
## call, so the helpers below spell it out: a wave is filled column by column,
## every column cut at each gradient stop, all in ONE triangle array — and a
## convex shape (a sail, a hull) is cut at each stop and coloured per vertex.

const K := preload("res://scenes/depth/kit.gd")

const TITLE := "Waves & ribbons"
const BLURB := "a surface shaded by which way it faces — travelling sines, twisting strips, rows of sea receding"

## ---------------------------------------------------------------- helpers
## Colour of a normalised stop list at k — flat beyond the ends, as canvas does.
static func _grad_at(st: Array, k: float) -> Color:
	if k <= float(st[0][0]):
		return st[0][1] as Color
	for i in st.size() - 1:
		var k0: float = st[i][0]
		var k1: float = st[i + 1][0]
		if k <= k1:
			return K.mix(st[i][1], st[i + 1][1], 0.0 if k1 - k0 < 1e-6 else (k - k0) / (k1 - k0))
	return st[st.size() - 1][1] as Color

## Keep the part of a convex polygon on one side of the line axis = v (0 = x, 1 = y).
static func _clip(pts: PackedVector2Array, axis: int, v: float, keep_below: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cnt := pts.size()
	for i in cnt:
		var a := pts[i]
		var bp := pts[(i + 1) % cnt]
		var va := a[axis]
		var vb := bp[axis]
		var ina := (va <= v) if keep_below else (va >= v)
		var inb := (vb <= v) if keep_below else (vb >= v)
		if ina:
			out.append(a)
		if ina != inb:
			out.append(a + (bp - a) * ((v - va) / (vb - va)))
	# drop repeated corners so the triangulator never sees a zero-length edge
	var clean := PackedVector2Array()
	for p in out:
		if clean.size() == 0 or clean[clean.size() - 1].distance_to(p) > 1e-4:
			clean.append(p)
	if clean.size() > 1 and clean[0].distance_to(clean[clean.size() - 1]) <= 1e-4:
		clean.remove_at(clean.size() - 1)
	return clean

static func _area(pts: PackedVector2Array) -> float:
	var a := 0.0
	for i in pts.size():
		var p := pts[i]
		var q := pts[(i + 1) % pts.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5

## A convex polygon filled with a gradient along one axis (0 = across x, 1 = down y)
## running from g0 to g1 — the canvas `lin` fill. The shape is cut at every interior
## stop, so inside each piece the colour is affine and a per-vertex gradient is exact.
static func _grad_poly(n: CanvasItem, pts: PackedVector2Array, axis: int, g0: float, g1: float, stops: Array) -> void:
	var st: Array = K._stops(stops)
	var span := g1 - g0
	if absf(span) < 1e-6 or pts.size() < 3:
		return
	var pieces: Array = [pts]
	for i in range(1, st.size() - 1):
		var v: float = g0 + span * float(st[i][0])
		var next: Array = []
		for pc in pieces:
			var lo := _clip(pc, axis, v, true)
			var hi := _clip(pc, axis, v, false)
			if lo.size() >= 3: next.append(lo)
			if hi.size() >= 3: next.append(hi)
		pieces = next
	for pc in pieces:
		var piece: PackedVector2Array = pc
		if _area(piece) < 0.01:
			continue
		var cols := PackedColorArray()
		for p in piece:
			cols.append(_grad_at(st, (p[axis] - g0) / span))
		K.lin_poly(n, piece, cols)

## The strip between two sampled curves (tops / bots at xs), filled with a vertical
## gradient from y = g0 down to y = g1: column by column, each column cut at every
## stop, all as ONE triangle array — the canvas `lin` fill under a wavy path.
static func _wave_fill(n: CanvasItem, xs: PackedFloat32Array, tops: PackedFloat32Array, bots: PackedFloat32Array,
		g0: float, g1: float, stops: Array) -> void:
	var st: Array = K._stops(stops)
	var span := g1 - g0
	if absf(span) < 1e-6:
		return
	var bounds := PackedFloat32Array([-1e6])
	for s in st:
		bounds.append(g0 + span * float(s[0]))
	bounds.append(1e6)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for j in xs.size() - 1:
		for bi in bounds.size() - 1:
			var ya := bounds[bi]
			var yb := bounds[bi + 1]
			var t0 := clampf(tops[j], ya, yb)
			var t1 := clampf(tops[j + 1], ya, yb)
			var b0 := clampf(bots[j], ya, yb)
			var b1 := clampf(bots[j + 1], ya, yb)
			if b0 <= t0 and b1 <= t1:
				continue
			var base := pts.size()
			for v in [Vector2(xs[j], t0), Vector2(xs[j + 1], t1), Vector2(xs[j + 1], b1), Vector2(xs[j], b0)]:
				var vv: Vector2 = v
				pts.append(vv)
				cols.append(_grad_at(st, (vv.y - g0) / span))
			idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	if idx.size() > 0:
		RenderingServer.canvas_item_add_triangle_array(n.get_canvas_item(), idx, pts, cols)

## The same strip in one flat colour (a wavy path filled, no gradient).
static func _columns(n: CanvasItem, xs: PackedFloat32Array, tops: PackedFloat32Array, bots: PackedFloat32Array, col: Color) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for j in xs.size() - 1:
		var base := pts.size()
		pts.append(Vector2(xs[j], tops[j])); pts.append(Vector2(xs[j + 1], tops[j + 1]))
		pts.append(Vector2(xs[j + 1], bots[j + 1])); pts.append(Vector2(xs[j], bots[j]))
		for q in 4: cols.append(col)
		idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	if idx.size() > 0:
		RenderingServer.canvas_item_add_triangle_array(n.get_canvas_item(), idx, pts, cols)

## A stroked ellipse (the canvas ctx.ellipse + stroke) as a closed polyline.
static func _ellipse_line(n: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for s in 33:
		var ang := TAU * float(s) / 32.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	n.draw_polyline(pts, col, w, true)

## A point on a quadratic Bézier (canvas quadraticCurveTo), k in 0..1.
static func _qbez(p0: Vector2, pc: Vector2, p1: Vector2, k: float) -> Vector2:
	return p0.lerp(pc, k).lerp(pc.lerp(p1, k), k)

## One row of receding sea, shared by Wake / Xebec / Yacht: y = horizon + p² (rows
## bunch toward the horizon), far rows fogged toward the air, a crest → trough
## gradient under a travelling sine. tsign scales the time term. Returns the row's y.
static func _sea_row(n: CanvasItem, b: Dictionary, HY: float, i: int, rows: int, sea: Color, air: Color, tsign: float) -> float:
	var W: float = b.W
	var H: float = b.H
	var t: float = b.t
	var p := float(i + 1) / rows
	var y := HY + p * p * (H - HY) * 0.9
	var amp := 1.0 + p * p * 5.0
	var wl := W * (0.15 + p * 0.35)
	var c := K.fog(sea, (1.0 - p) * 0.8, air)
	var xs := PackedFloat32Array()
	var tops := PackedFloat32Array()
	var bots := PackedFloat32Array()
	var x := 0.0
	while x <= W + 6.0:
		xs.append(x)
		tops.append(y + sin(x / wl * TAU + tsign * t * (0.5 + p) + i) * amp)
		bots.append(H)
		x += 6.0
	_wave_fill(n, xs, tops, bots, y - amp, y + amp * 3.0, [K.shade(c, 0.25), c, K.shade(c, -0.3)])
	return y

## Tide: the front edge of row r at column x — a slow sine riding a fast one.
static func _edge_at(b: Dictionary, x: float, r: int, reach: float, t: float) -> float:
	var W: float = b.W
	var H: float = b.H
	return reach + sin(x / W * TAU * 1.5 - t * 1.2 + r * 1.1) * H * 0.03

## Xebec: a lateen sail — yard slanting low-forward to high-aft, the leech bowed out.
## Drawn in the ship's local space; sail_c / hull_c carry the ship's alpha already.
static func _lateen(n: CanvasItem, mx: float, size: float, s: float, sail_c: Color, hull_c: Color, belly: float, t: float) -> void:
	var ax := mx - size * 0.45
	var ay := -size * 1.05
	var fx := mx + size * 0.45
	var fy := -size * 0.35
	var cx := mx - size * 0.4
	var cy := -size * 0.12
	var breathe := belly * (0.7 + 0.3 * sin(t * 1.6))                     # the sail fills and slackens
	var ctrl := Vector2((fx + cx) / 2.0 + size * 0.25 * breathe, (fy + cy) / 2.0 + size * 0.1)
	var pts := PackedVector2Array([Vector2(ax, ay), Vector2(fx, fy)])
	for i in range(1, 8):
		pts.append(_qbez(Vector2(fx, fy), ctrl, Vector2(cx, cy), i / 8.0))
	pts.append(Vector2(cx, cy))
	# dark at the yard, light on the belly: a sideways gradient makes the triangle curve
	_grad_poly(n, pts, 0, ax, fx, [[0.0, K.shade(sail_c, -0.35)], [0.45 + breathe * 0.15, K.shade(sail_c, -0.05)], [1.0, K.shade(sail_c, 0.15)]])
	K.line(n, Vector2(ax, ay), Vector2(fx, fy), K.shade(hull_c, -0.3), 1.5)   # the yard
	K.line(n, Vector2(mx, -6.0 * s), Vector2(mx, -size), K.shade(hull_c, -0.3), 1.5)   # the mast

## Yacht: one boat at (x, y); z 0 far … 1 near sets its size and fog. The heel is
## one rotate, the tack a mirror — both live in the transform, not the points.
static func _yacht(n: CanvasItem, b: Dictionary, x: float, y: float, z: float) -> void:
	var D: Dictionary = b.D
	var air: Color = D.air
	var dir: float = b.dir
	var lean: float = b.lean
	var W: float = b.W
	var s := W * 0.0045 * (0.3 + z * 0.7)
	var hull := K.fog(D.hull, (1.0 - z) * 0.6, air)
	var sail := K.fog(D.sail, (1.0 - z) * 0.6, air)
	n.draw_set_transform(Vector2(x, y), lean * dir, Vector2(dir, 1.0))   # mirror + lean: the wind's side
	K.poly(n, PackedVector2Array([Vector2(-24 * s, -5 * s), Vector2(26 * s, -6 * s), Vector2(20 * s, 6 * s), Vector2(-20 * s, 6 * s)]), hull)
	K.poly(n, PackedVector2Array([Vector2(-23 * s, 1 * s), Vector2(24 * s, 1 * s), Vector2(20 * s, 6 * s), Vector2(-20 * s, 6 * s)]),
		K.fog(D.trim, (1.0 - z) * 0.6, air))                                # the stripe at the waterline
	K.line(n, Vector2(0, -5 * s), Vector2(0, -70 * s), Color(0, 0, 0, 0.5), 1.0)
	var msail := PackedVector2Array([Vector2(0, -68 * s), Vector2(0, -8 * s), Vector2(-32 * s, -8 * s)])
	for i in range(1, 8):                                                  # the leech bows outward: the belly
		msail.append(_qbez(Vector2(-32 * s, -8 * s), Vector2(-28 * s, -40 * s), Vector2(0, -68 * s), i / 8.0))
	# dark at the mast, light where the belly faces the light
	_grad_poly(n, msail, 0, 0.0, -32.0 * s, [[0.0, K.shade(sail, -0.3)], [0.55, K.shade(sail, -0.08)], [1.0, sail]])
	_grad_poly(n, PackedVector2Array([Vector2(1 * s, -56 * s), Vector2(26 * s, -7 * s), Vector2(0, -16 * s)]), 0, 0.0, 26.0 * s,
		[K.shade(sail, -0.2), sail])                                       # the jib
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Zephyr: the ribbon's path, y(x) — the leaves ride the same function.
static func _path_y(b: Dictionary, p: Dictionary, x: float, t: float) -> float:
	var W: float = b.W
	var H: float = b.H
	var py: float = p.y
	var amp: float = p.amp
	var f: float = p.f
	var sp: float = p.sp
	return H * (py + amp * sin(x / W * f * TAU - t * 1.5 * sp))


static func defs() -> Array:
	var d: Array = []

	# ---- F · Flag ----------------------------------------------------------
	d.append({ "letter": "F", "name": "Flag",
		"hint": "a flag is vertical strips lifted by a travelling sine that grows toward the free end — shade each strip by its slope (cos) and the wiggle becomes folds",
		"dials": { "sky": [Color("6FA8E8"), Color("CFE6F5")], "cloth": Color("D8302A"), "band": Color("F5F0E0"), "pole": Color("8A8A96"),
			"strips": 40, "wind": 1.0, "waves": 1.6, "shade_by": 0.45,        # shade_by: how hard the slope shades the cloth
			"label": "shade = cos(phase) × distance from the pole — the slope of the sine says which way each strip faces" },
		"rhyme": { "name": "Pirate flag", "hint": "the same strips in black under a storm sky, a stiffer wind and more ripples — the folds now read from the white band alone",
			"dials": { "sky": [Color("2A2A3A"), Color("6A6A7A")], "cloth": Color("111118"), "band": Color("E8E5F4"), "pole": Color("5A5A66"),
				"wind": 1.9, "waves": 2.2,
				"label": "black cloth barely shades — the band carries the folds; more waves, faster: a gale is two dials" } },
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.wind = 0.3 + (pos.x / b.W) * 2.0,   # click right = more wind
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			K.sky(n, b, D.sky)
			var px: float = b.W * 0.18
			var top: float = b.H * 0.16
			var fw: float = b.W * 0.58
			var fh: float = b.H * 0.34
			var GY: float = b.H * 0.86
			K.ground(n, b, GY, Color("3A5A3A"))
			K.shadow(n, Vector2(px + fw * 0.35, GY + 2.0), fw * 0.45, 5.0, 0.3)   # the flag's shadow on the grass
			K.cyl(n, px - 3.0, GY, 6.0, GY - top + 14.0, D.pole, -0.3)
			K.sphere(n, Vector2(px - 3.0, top - 16.0), 5.0, Color("E8C060"), -0.5, -0.5)
			var strips: int = D.strips
			var wind: float = D.wind
			var waves: float = D.waves
			var shade_by: float = D.shade_by
			var sw := fw / strips
			for i in strips:
				var k := float(i) / strips
				var ph := k * TAU * waves - t * wind * 4.0
				var amp := fh * 0.2 * k * wind                                # pinned at the pole, loose at the free end
				var y := top + sin(ph) * amp
				var slope := cos(ph) * k * wind                               # d/dx of the sine — which way this strip faces
				var fold := clampf(1.0 - k * 3.0, 0.0, 1.0) * 0.25            # the cloth shades itself where it bunches at the pole
				var lit := clampf(slope * shade_by - fold, -0.45, 0.45)
				n.draw_rect(Rect2(px + i * sw, y, sw + 1.0, fh * (1.0 - k * 0.08)), K.shade(D.cloth, lit))   # the free end hangs a little shorter
				n.draw_rect(Rect2(px + i * sw, y + fh * 0.38, sw + 1.0, fh * 0.2), K.shade(D.band, lit))     # a stripe rides the same folds
			K.label(n, b, D.label) })

	# ---- H · Helix ---------------------------------------------------------
	d.append({ "letter": "H", "name": "Helix",
		"hint": "a ribbon coiled round a rod: slice by slice x = sin θ, width = |cos θ|, back colour when cos < 0 — draw the far half, the rod, then the near half",
		"dials": { "sky": [Color("0E1230"), Color("1A1E4A")], "front": Color("5AF0AA"), "back": Color("1E6A4A"), "rod": Color("8A8A96"),
			"ribbons": 1, "turns": 3, "slices": 96, "radius": 0.2, "speed": 0.8,
			"label": "painter's order: the far half, then the rod, then the near half — occlusion is the depth" },
		"rhyme": { "name": "Double helix", "hint": "the same slices with a second ribbon half a turn behind, in rose, the rod painted the colour of the dark — a strand of DNA",
			"dials": { "sky": [Color("0A0818"), Color("1A1030")], "front": Color("F05A8A"), "back": Color("7A2A4A"), "rod": Color("1A1030"),
				"ribbons": 2, "turns": 2,
				"label": "count 1 → 2: the second ribbon is the same loop with θ + π — the two never touch, because they can't" } },
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.speed = (pos.x / b.W - 0.5) * 3.0,   # click left of centre = spin the other way
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			K.sky(n, b, D.sky)
			var cx: float = b.W / 2.0
			var top: float = b.H * 0.1
			var hgt: float = b.H * 0.72
			var R: float = b.W * D.radius
			var slices: int = D.slices
			var sh := hgt / slices
			var W2 := R * 0.9                                                 # the ribbon's true width
			K.ground(n, b, top + hgt + 4.0, Color("0A0C20"))
			K.shadow(n, Vector2(cx, top + hgt + 10.0), R * 1.4, R * 0.3, 0.45)
			var ribbons: int = D.ribbons
			var turns: float = D.turns
			var speed: float = D.speed
			for pss in 2:                                                     # pass 0 = the far half, pass 1 = the near half
				if pss == 1:
					K.cyl(n, cx, top + hgt + 2.0, R * 0.16, hgt + 8.0, D.rod, -0.4)   # the rod goes between them
				for r in ribbons:
					for i in slices:
						var th := (float(i) / slices) * turns * TAU + t * speed + r * PI   # extra ribbons: half a turn apart
						var c := cos(th)                                          # c > 0 = toward you, c < 0 = away
						if (c >= 0.0) != (pss == 1):
							continue
						var x := cx + sin(th) * R
						var w := absf(c) * W2 + 1.0                               # apparent width: |cos θ|
						var lit := -sin(th) * 0.2 + absf(c) * 0.15 - 0.1          # pale on the left (the light side), dim edge-on
						n.draw_rect(Rect2(x - w / 2.0, top + i * sh, w, sh + 0.8), K.shade(D.front if c >= 0.0 else D.back, lit))
			K.label(n, b, D.label) })

	# ---- J · Jetstream -----------------------------------------------------
	d.append({ "letter": "J", "name": "Jetstream",
		"hint": "four ribbons of wind crossing the sky at different depths — each a band of parallel sines under a soft alpha gradient; far ones paler, thinner, slower",
		"dials": { "sky": [Color("2A4A8F"), Color("7FA8D8"), Color("D9E3F0")], "ink": Color.WHITE, "streams": 4, "lines": 5, "speed": 1.0, "alpha": 0.45,
			"label": "one number z sets alpha, width, amplitude and speed — a far stream is less of everything" },
		"rhyme": { "name": "Aurora streams", "hint": "the same four bands in green over a night sky — alpha up, speed down — and the wind becomes the northern lights",
			"dials": { "sky": [Color("05051A"), Color("0E1230"), Color("1A2040")], "ink": Color("5AF0AA"), "speed": 0.4, "alpha": 0.7,
				"label": "the same bands, one hue and more alpha — light in the air is wind you can see" } },
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.speed = 0.3 + (pos.x / b.W) * 2.2,   # click right = a stronger wind aloft
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var sky: Array = D.sky
			K.sky(n, b, [[0.0, sky[0]], [0.6, sky[1]], [1.0, sky[2]]])
			var streams: int = D.streams
			var lines: int = D.lines
			var speed: float = D.speed
			var alpha_d: float = D.alpha
			var ink: Color = D.ink
			for s in streams:
				var z := float(s + 1) / streams                                # 0 = far, 1 = near; near streams painted last
				var y0: float = b.H * (0.12 + s * 0.19)
				var band: float = b.H * (0.025 + z * 0.09)
				var amp: float = b.H * (0.02 + z * 0.05)
				var wl: float = b.W * (0.4 + z * 0.4)
				var ph := t * (0.25 + z * 0.9) * speed * 2.0 + s * 2.0
				var a := alpha_d * (0.35 + z * 0.65)                           # far = fainter
				var xs := PackedFloat32Array()
				var tops := PackedFloat32Array()
				var bots := PackedFloat32Array()
				var x := -8.0
				while x <= b.W + 8.0:
					xs.append(x)
					tops.append(y0 - band / 2.0 + sin(x / wl * TAU - ph) * amp)
					bots.append(y0 + band / 2.0 + sin(x / wl * TAU - ph + 0.3) * amp)
					x += 8.0
				_wave_fill(n, xs, tops, bots, y0 - band / 2.0 - amp, y0 + band / 2.0 + amp,
					[[0.0, K.alpha(ink, 0.0)], [0.5, K.alpha(ink, a * 0.5)], [1.0, K.alpha(ink, 0.0)]])
				var lw := 0.4 + z * 1.2                                        # far = thinner
				for l in lines:
					var q := (l + 0.5) / lines
					var pts := PackedVector2Array()
					var x3 := -8.0
					while x3 <= b.W + 8.0:
						pts.append(Vector2(x3, y0 + (q - 0.5) * band + sin(x3 / wl * TAU - ph + q * 0.3) * amp))
						x3 += 8.0
					n.draw_polyline(pts, K.alpha(ink, a * sin(q * PI)), lw, true)   # dense in the middle of the band, soft at its edges
			K.label(n, b, D.label) })

	# ---- K · Kite ----------------------------------------------------------
	d.append({ "letter": "K", "name": "Kite",
		"hint": "a diamond of two triangles, lit and dark either side of the spar, bobbing on a sine — its tail is a chain, each link following the last, twisting as it trails",
		"dials": { "sky": [Color("3A7FD0"), Color("B8D8F5")], "kite": Color("F5A15A"), "tail": Color("F05A8A"), "tail_back": Color("F5E0B0"),
			"links": 26, "link": 0.022, "bob": 1.0, "wind": 1.0,              # link: one chain segment, as a share of H
			"label": "two flat shades meeting at the spar make a fold; the tail is a chain — each link follows the one before" },
		"rhyme": { "name": "Dragon kite", "hint": "the same diamond in red with a gold-and-crimson tail almost twice as long, over a festival dusk — the chain just has more links",
			"dials": { "sky": [Color("3A2A6A"), Color("F5A15A")], "kite": Color("D82A2A"), "tail": Color("F5C169"), "tail_back": Color("B81A1A"),
				"links": 44, "link": 0.02,
				"label": "a longer chain is the same rule run more times — the tail's whip is emergent, not drawn" } },
		"init": func(b: Dictionary) -> void:
			var links: int = b.D.links
			b.tail = []
			for i in links + 1:
				b.tail.append(Vector2(b.W * 0.6 - i * 4.0, b.H * 0.5 + i * 4.0))
			b.gust_at = -9.0,
		"tick": func(b: Dictionary, dt: float) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var links: int = D.links
			var ga: float = b.gust_at
			var bob: float = D.bob
			var wind: float = D.wind
			var gust := exp(-(t - ga) * 2.0)
			var kx: float = b.W * (0.6 + 0.07 * sin(t * 0.7) + gust * 0.1)
			var ky: float = b.H * (0.36 + 0.07 * sin(t * 1.3 * bob) - gust * 0.12)
			var kh: float = b.H * 0.1
			var tail: Array = b.tail
			tail[0] = Vector2(kx, ky + kh * 1.2)                              # the tail: a chain. wind and gravity move each link,
			var L: float = b.H * D.link                                        # then the link before it pulls it back to length
			var step := minf(dt, 0.05)
			for i in range(1, links + 1):
				var p: Vector2 = tail[i]
				var q: Vector2 = tail[i - 1]
				p.y += 60.0 * step
				p.x += (30.0 + 40.0 * sin(t * 3.0 + i * 0.4)) * step * wind
				var dv := p - q
				tail[i] = q + dv / (dv.length() + 1e-6) * L,
		"press": func(b: Dictionary, _pos: Vector2) -> void: b.gust_at = b.t,   # click = a gust lifts the kite
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			K.sky(n, b, D.sky)
			K.ground(n, b, b.H * 0.9, Color("4A7A4A"))
			var ga: float = b.gust_at
			var bob: float = D.bob
			var gust := exp(-(t - ga) * 2.0)                                  # a click's gust fades in half a second
			var kx: float = b.W * (0.6 + 0.07 * sin(t * 0.7) + gust * 0.1)
			var ky: float = b.H * (0.36 + 0.07 * sin(t * 1.3 * bob) - gust * 0.12)
			var lean := sin(t * 0.7) * 0.3
			var kw: float = b.W * 0.07
			var kh: float = b.H * 0.1
			K.line(n, Vector2(b.W * 0.08, b.H * 0.9), Vector2(kx - kw * 0.3, ky + kh * 0.4), Color(0, 0, 0, 0.35), 1.0)   # the string
			var tail: Array = b.tail
			var links: int = D.links
			for j in links:                                                   # the tail twists: width by |cos|, colour by its sign
				var a: Vector2 = tail[j]
				var bb: Vector2 = tail[j + 1]
				var c := cos(j * 0.45 - t * 4.0)
				var hw := (absf(c) * 3.5 + 0.5) * (1.0 - float(j) / links * 0.5)
				var e := bb - a
				var nrm := Vector2(-e.y, e.x) / (e.length() + 1e-6) * hw
				K.poly(n, PackedVector2Array([a + nrm, bb + nrm, bb - nrm, a - nrm]), D.tail if c >= 0.0 else D.tail_back)
			K.poly(n, PackedVector2Array([Vector2(kx, ky - kh), Vector2(kx - kw, ky), Vector2(kx, ky + kh * 1.2)]), K.shade(D.kite, 0.22 + lean))    # the lit half
			K.poly(n, PackedVector2Array([Vector2(kx, ky - kh), Vector2(kx + kw, ky), Vector2(kx, ky + kh * 1.2)]), K.shade(D.kite, -0.35 + lean))   # the shadowed half
			K.line(n, Vector2(kx, ky - kh), Vector2(kx, ky + kh * 1.2), Color(0, 0, 0, 0.4), 1.0)   # the spar: the fold line
			K.label(n, b, D.label) })

	# ---- L · Loop ----------------------------------------------------------
	d.append({ "letter": "L", "name": "Loop",
		"hint": "a ribbon tied in a loop-de-loop: quads round a circle, width = |cos| of the angle from the bottom, colour flipping to the back at the top — a car rides the inside",
		"dials": { "sky": [Color("6FA8E8"), Color("CFE6F5")], "front": Color("F5C169"), "back": Color("8A5A2A"), "car": Color("D82A2A"),
			"segs": 72, "width": 0.11, "car_speed": 1.2, "radius": 0.3,
			"label": "the |cos| rule bent into a circle — front at the bottom, back at the top, edge-on at the sides" },
		"rhyme": { "name": "Roller coaster", "hint": "the same loop as a red rail under a carnival night, the car in gold running two and a half times faster",
			"dials": { "sky": [Color("1A1030"), Color("3A2A6A")], "front": Color("D82A2A"), "back": Color("5A0A0A"), "car": Color("F5C169"),
				"car_speed": 3.0,
				"label": "speed is a dial: at 3.0 the eye stops seeing a ribbon and starts seeing a ride" } },
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.car_speed = (pos.x / b.W - 0.5) * 5.0,   # click left of centre = the car runs backwards
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			K.sky(n, b, D.sky)
			var cx: float = b.W / 2.0
			var R: float = b.H * D.radius
			var cy: float = b.H * 0.5
			var GY := cy + R
			var w: float = b.H * D.width
			K.ground(n, b, GY + 6.0, Color("3A5A3A"))
			K.shadow(n, Vector2(cx, GY + 8.0), R * 1.2, R * 0.2, 0.35)
			K.lin_rect(n, Rect2(0, GY - w / 2.0, b.W, w), [K.shade(D.front, 0.25), D.front, K.shade(D.front, -0.3)])   # the flat run: full width, front colour
			var segs: int = D.segs
			for i in segs:
				var a0 := (float(i) / segs) * TAU                              # angle measured from the bottom
				var a1 := (float(i + 1) / segs) * TAU
				var am := (a0 + a1) / 2.0
				var c := cos(am)
				var hw := absf(c) * w / 2.0 + 0.6                              # apparent width: |cos| — edge-on at the sides
				var lit := (-sin(am) - c) * 0.18                              # pale where the surface faces up-left
				var s0 := sin(a0); var c0 := cos(a0); var s1 := sin(a1); var c1 := cos(a1)
				K.poly(n, PackedVector2Array([Vector2(cx + s0 * (R - hw), cy + c0 * (R - hw)), Vector2(cx + s1 * (R - hw), cy + c1 * (R - hw)),
					Vector2(cx + s1 * (R + hw), cy + c1 * (R + hw)), Vector2(cx + s0 * (R + hw), cy + c0 * (R + hw))]),
					K.shade(D.front if c >= 0.0 else D.back, clampf(lit, -0.4, 0.4)))   # cos < 0 (the top half) shows the back
			var ca: float = t * D.car_speed
			var cr := w * 0.35
			var cw := absf(cos(ca)) * w / 2.0 + 0.6                            # the car hugs the inside of the track
			K.sphere(n, Vector2(cx + sin(ca) * (R - cw - cr), cy + cos(ca) * (R - cw - cr)), cr, D.car, -0.5, -0.5, 0.5)
			K.label(n, b, D.label) })

	# ---- O · Ocean ---------------------------------------------------------
	d.append({ "letter": "O", "name": "Ocean",
		"hint": "seven rows of travelling sines from horizon to foreground — spacing bunches toward the horizon, far rows fog into the sky, crests pale, troughs dark",
		"dials": { "sky": [Color("8FB8E0"), Color("D9E8F5")], "sea": Color("1E5A8F"), "air": Color("C8DCEE"), "foam": Color("F0F6FF"),
			"rows": 7, "wind": 1.0, "horizon": 0.38, "step": 4,                # step: px between points along each crest
			"label": "rows bunch toward the horizon (horizon + p²) and fade into the air; only a crest tip reaches the foam" },
		"rhyme": { "name": "Lava sea", "hint": "the same seven rows in orange under a black sky, a slow wind — the air is smoke, so far rows go dark, and the foam stop glows",
			"dials": { "sky": [Color("0A0404"), Color("3A1008")], "sea": Color("C84A10"), "air": Color("2A0E0A"), "foam": Color("FFE080"),
				"wind": 0.35,
				"label": "fog toward a DARK air and distance goes black instead of pale — the air's colour is the whole mood" } },
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.wind = 0.3 + (pos.x / b.W) * 1.9,   # click right = more wind
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			K.sky(n, b, D.sky)
			var HY: float = b.H * D.horizon
			var sea: Color = D.sea
			var air: Color = D.air
			var foam: Color = D.foam
			n.draw_rect(Rect2(0, HY, b.W, b.H - HY), K.fog(sea, 0.85, air))    # the far sea is nearly air
			var rows: int = D.rows
			var wind: float = D.wind
			var step: float = D.step
			for i in rows:
				var p := float(i + 1) / rows                                   # 0 = at the horizon, 1 = at your feet
				var y: float = HY + p * p * (b.H - HY) * 0.92                  # horizon + p²: rows bunch toward the horizon
				var amp := (1.5 + p * p * 14.0) * wind                         # near waves: taller, longer, faster
				var wl: float = b.W * (0.12 + p * 0.4)
				var ph := t * (0.4 + p * 1.2) * wind * 2.0 + i * 1.7
				var c := K.fog(sea, (1.0 - p) * 0.8, air)                      # far rows mix toward the air
				var xs := PackedFloat32Array()
				var tops := PackedFloat32Array()
				var bots := PackedFloat32Array()
				var x := 0.0
				while x <= b.W + step:
					xs.append(x)
					tops.append(y + sin(x / wl * TAU + ph) * amp)
					bots.append(b.H)
					x += step
				# only a crest tip reaches the foam stop
				_wave_fill(n, xs, tops, bots, y - amp, y + amp * 3.0, [[0.0, foam], [0.08, K.shade(c, 0.3)], [0.4, c], [1.0, K.shade(c, -0.35)]])
			K.label(n, b, D.label) })

	# ---- R · Ribbon --------------------------------------------------------
	d.append({ "letter": "R", "name": "Ribbon",
		"hint": "a long strip drawn as short quads along a moving sine — its width is |cos(twist)|, and when cos goes negative the BACK colour shows",
		"dials": { "sky": [Color("1A1030"), Color("2A1E4A")], "front": Color("F05A8A"), "back": Color("F5C169"),   # the two faces of the strip
			"width": 0.1, "segs": 64, "twists": 2.5, "speed": 1.0, "step": 0,   # step > 0 snaps time to 1/step s (jerky)
			"label": "width = |cos(twist)|; cos < 0 shows the back colour; the shade follows the slope" },
		"rhyme": { "name": "Glitch tape", "hint": "the same quads in magenta and cyan on black, faster, with time snapped to ninths of a second — the smoothness was a dial",
			"dials": { "sky": [Color("050508"), Color("0A0A12")], "front": Color("FF00C8"), "back": Color("00E5FF"), "speed": 1.6, "step": 9,
				"label": "floor(t × 9) / 9: quantise the clock and the same ribbon stutters — glitch is a time dial" } },
		"init": func(b: Dictionary) -> void: b.flick_at = -9.0,
		"press": func(b: Dictionary, _pos: Vector2) -> void: b.flick_at = b.t,   # click = flick the ribbon
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var stp: int = D.step
			var tt: float = floorf(t * stp) / stp if stp > 0 else t
			K.sky(n, b, D.sky)
			var w: float = b.H * D.width
			var N: int = D.segs
			var speed: float = D.speed
			var twists: float = D.twists
			var fa: float = b.flick_at
			var px := PackedFloat32Array()
			var py := PackedFloat32Array()
			var tw := PackedFloat32Array()
			for i in N + 1:
				var k := float(i) / N
				px.append(b.W * (-0.04 + k * 1.08))
				py.append(b.H * (0.48 + 0.2 * sin(k * TAU * 1.2 - tt * speed * 1.4) + 0.06 * sin(k * TAU * 2.7 + tt * speed * 0.9)))
				var flick := 2.4 * exp(-pow((k - (tt - fa) * 0.7) * 7.0, 2.0))   # a pulse of extra twist running head → tail
				tw.append(k * TAU * twists - tt * speed * 2.0 + flick)
			for j in N:
				var c := cos((tw[j] + tw[j + 1]) / 2.0)                        # the twist, seen edge-on at cos = 0
				var hw := absf(c) * w / 2.0 + 0.6                              # apparent half-width: |cos|
				var dx := px[j + 1] - px[j]
				var dy := py[j + 1] - py[j]
				var ln := sqrt(dx * dx + dy * dy) + 1e-6
				var lit := ((dx - dy) / ln - 0.7) * 0.5                        # slope → shade: pale where it faces up-left
				K.poly(n, PackedVector2Array([Vector2(px[j], py[j] - hw), Vector2(px[j + 1], py[j + 1] - hw),
					Vector2(px[j + 1], py[j + 1] + hw), Vector2(px[j], py[j] + hw)]),
					K.shade(D.front if c >= 0.0 else D.back, clampf(lit, -0.4, 0.4)))   # the sign of cos picks the face
			K.label(n, b, D.label) })

	# ---- T · Tide ----------------------------------------------------------
	d.append({ "letter": "T", "name": "Tide",
		"hint": "waves lapping a beach: three rows whose front edge advances and retreats on a slow sine — the sand stays dark where the last wave reached, and dries",
		"dials": { "sky": [Color("8FB8E0"), Color("D9E8F5")], "sea": Color("1E6A9A"), "shallow": Color("7AC8D8"), "sand": Color("E0C890"), "wet": Color("7A5A30"), "foam": Color.WHITE,
			"rows": 3, "tide": 0.5, "dry": 6.0, "cols": 48, "moon": false,     # dry: seconds for wet sand to fade back
			"label": "the edge is a slow sine over a fast one; the sand remembers the last reach and dries — time as a gradient" },
		"rhyme": { "name": "Moon tide", "hint": "the same beach at night under a moon — half the tide's speed, the wet sand drying twice as slowly, silver water on grey sand",
			"dials": { "sky": [Color("05051A"), Color("1A2040")], "sea": Color("101E4A"), "shallow": Color("3A5A8A"), "sand": Color("5A5A6A"), "wet": Color("1A1A2A"), "foam": Color("E8E5F4"),
				"tide": 0.25, "dry": 12.0, "moon": true,
				"label": "halve the tide's speed and double the drying and the beach keeps a longer memory — pace is a dial" } },
		"init": func(b: Dictionary) -> void:
			var cols: int = b.D.cols
			b.wet = []
			b.wet_t = []
			for c in cols:
				b.wet.append(0.0)
				b.wet_t.append(-99.0)
			b.surge_at = -99.0,
		"press": func(b: Dictionary, _pos: Vector2) -> void: b.surge_at = b.t,   # click = one big wave
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			K.sky(n, b, D.sky)
			var HY: float = b.H * 0.3
			if D.moon:
				K.dot(n, Vector2(b.W * 0.75, b.H * 0.12), b.W * 0.035, Color("F0EEFF"))
			K.lin_rect(n, Rect2(0, HY, b.W, b.H - HY), [K.shade(D.sand, 0.1), K.shade(D.sand, -0.2)])
			var sa: float = b.surge_at
			var tide: float = D.tide
			var dry: float = D.dry
			var reach: float = b.H * (0.5 + 0.22 * sin(t * tide) + 0.15 * exp(-(t - sa) * 1.5))   # the front's base: in, out, and a click's surge
			var cols: int = D.cols
			var rows: int = D.rows
			var cw: float = b.W / cols
			var wet: Array = b.wet
			var wet_t: Array = b.wet_t
			for i in cols:                                                    # wet sand: each column remembers the last reach, and when
				var edge := _edge_at(b, (i + 0.5) * cw, rows - 1, reach, t)
				if edge >= wet[i]:
					wet[i] = edge
					wet_t[i] = t
				var wt: float = wet_t[i]
				var wi: float = wet[i]
				var dark := clampf(1.0 - (t - wt) / dry, 0.0, 1.0) * 0.55      # dries over D.dry seconds
				if wi > HY:
					n.draw_rect(Rect2(i * cw, HY, cw + 1.0, wi - HY), K.alpha(D.wet, dark))
			for r in rows:
				var p := float(r + 1) / rows
				var base := HY + (reach - HY) * (0.45 + 0.55 * p)              # the last row's edge is the reach itself
				var xs := PackedFloat32Array()
				var tops := PackedFloat32Array()
				var bots := PackedFloat32Array()
				var line := PackedVector2Array()
				var x := 0.0
				while x <= b.W + 6.0:
					var ey := _edge_at(b, x, r, base, t)
					xs.append(x); tops.append(HY); bots.append(ey)
					line.append(Vector2(x, ey))
					x += 6.0
				_columns(n, xs, tops, bots, K.alpha(K.mix(D.sea, D.shallow, p), 1.0 if r == 0 else 0.55))   # thin water lets the wet sand through
				n.draw_polyline(line, K.alpha(D.foam, 0.3 + p * 0.5), 1.0 + p, true)   # the foam line
			K.label(n, b, D.label) })

	# ---- U · Undertow ------------------------------------------------------
	d.append({ "letter": "U", "name": "Undertow",
		"hint": "under the surface: caustic stripes wobbling in the light, seaweed ribbons swaying at three depths — far ones paler, slower — and bubbles rising faster the nearer they are",
		"dials": { "water": [Color("1A6A9A"), Color("052040")], "air": Color("2A6A9A"), "weed": Color("2A8A4A"), "light": Color("B8F0FF"), "bubble": Color("E8F8FF"),
			"depths": 3, "weeds": 4, "bubbles": 22, "sway": 1.0, "glow": false,
			"label": "far weed is paler and slower, near bubbles bigger and faster — three dials, one z" },
		"rhyme": { "name": "Deep sea", "hint": "the same water gone near-black, the weed a dim teal, half the current — and every bubble carries its own glow",
			"dials": { "water": [Color("031020"), Color("000306")], "air": Color("0A1A2A"), "weed": Color("1A3A3A"), "light": Color("3A8AA0"), "bubble": Color("8AF0FF"),
				"sway": 0.5, "glow": true,
				"label": "take the light away and each bubble becomes a light source — glow is one soft() per dot" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(7)
			b.weeds = []
			b.bubbles = []
			var depths: int = D.depths
			var weeds: int = D.weeds
			for dd in depths:                                                 # far layer first: painter's order for free
				for w in weeds:
					b.weeds.append({ "x": R.randf() * b.W, "z": (dd + 0.5) / depths, "h": 0.28 + R.randf() * 0.3, "ph": R.randf() * 9.0 })
			for bl in int(D.bubbles):
				b.bubbles.append({ "x": R.randf() * b.W, "y": R.randf(), "z": R.randf(), "ph": R.randf() * 9.0 }),
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.sway = 0.2 + (pos.x / b.W) * 2.5,   # click right = a stronger current
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			K.sky(n, b, D.water)
			var light: Color = D.light
			var air: Color = D.air
			var bubble: Color = D.bubble
			K.soft(n, Vector2(b.W * 0.5, -b.H * 0.2), b.H * 0.8, light, 0.25)   # the surface, lit from above
			for i in 7:                                                       # caustics: bright stripes that wobble
				var pts := PackedVector2Array()
				var x := 0.0
				while x <= b.W:
					pts.append(Vector2(x, b.H * (0.04 + i * 0.05) + sin(x * 0.04 + t * 1.5 + i) * 3.0 + sin(x * 0.011 - t * 0.9 + i * 2) * 5.0))
					x += 8.0
				n.draw_polyline(pts, K.alpha(light, 0.35 * (1.0 - i / 7.0)), 1.5, true)
			var GY: float = b.H * 0.9
			K.lin_rect(n, Rect2(0, GY, b.W, b.H - GY), [K.fog(Color("4A3A2A"), 0.5, air), Color("2A1A10")])
			var sway: float = D.sway
			for s in b.weeds:                                                 # seaweed: a ribbon of quads, shaded by its lean
				var z: float = s.z
				var sx: float = s.x
				var sph: float = s.ph
				var nn := 9
				var hgt: float = b.H * s.h * (0.5 + z * 0.6)
				var base: float = GY - (1.0 - z) * b.H * 0.05
				var c := K.fog(D.weed, (1.0 - z) * 0.75, air)
				var px := sx
				var py := base
				var sp := (0.6 + z * 0.8) * sway
				for k in nn:
					var q := float(k + 1) / nn
					var ang := q * 3.0 + t * sp + sph
					var nx := sx + sin(ang) * q * q * hgt * 0.35                  # the tip sways most
					var ny := base - q * hgt
					var hw := (1.0 - q * 0.7) * (2.0 + z * 5.0)
					K.poly(n, PackedVector2Array([Vector2(px - hw, py), Vector2(nx - hw, ny), Vector2(nx + hw, ny), Vector2(px + hw, py)]),
						K.shade(c, cos(ang) * 0.25 * q))                         # cos = the slope: pale when leaning into the light
					px = nx
					py = ny
			for o in b.bubbles:
				var zz: float = o.z
				var oy: float = o.y
				var ox: float = o.x
				var oph: float = o.ph
				var yy: float = fposmod(oy - t * (0.04 + zz * 0.12), 1.0) * b.H   # near bubbles rise faster
				var xx := ox + sin(t * 2.0 + oph) * (2.0 + zz * 4.0)
				var r := 1.0 + zz * 3.0
				if D.glow:
					K.soft(n, Vector2(xx, yy), r * 4.0, bubble, 0.4)
				n.draw_arc(Vector2(xx, yy), r, 0.0, TAU, 16, K.alpha(bubble, 0.25 + zz * 0.5), 0.8, true)
				K.dot(n, Vector2(xx - r * 0.35, yy - r * 0.35), r * 0.3, K.alpha(bubble, 0.4 + zz * 0.5))   # one bright spot: a sphere in two marks
			K.label(n, b, D.label) })

	# ---- W · Wake ----------------------------------------------------------
	d.append({ "letter": "W", "name": "Wake",
		"hint": "a boat crossing rows of receding sea, trailing a V of ripples — rings left at its past positions, growing and fading with age, squashed flat by perspective",
		"dials": { "sky": [Color("6FA8E8"), Color("CFE6F5")], "sea": Color("1E5A8F"), "air": Color("C8DCEE"), "hull": Color("2A1E1A"), "sail": Color("F5F0E0"),
			"rows": 6, "rings": 14, "speed": 1.0, "spread": 0.45,             # spread: ring radius per unit distance behind — the V's angle
			"label": "each ring was dropped where the boat was, then grew and faded — the V is their envelope, squashed flat" },
		"rhyme": { "name": "Speedboat", "hint": "the same rings behind a white hull with no sail, two and a half times faster and a wider V — spread is the boat's speed made visible",
			"dials": { "hull": Color("F0F0F5"), "sail": Color(0, 0, 0, 0), "speed": 2.4, "spread": 0.8,
				"label": "a wider spread is a faster boat: the rings grow the same, the boat just gets further away from them" } },
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.speed = 0.3 + (pos.x / b.W) * 2.0,   # click right = faster boat
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			K.sky(n, b, D.sky)
			var HY: float = b.H * 0.32                                        # the horizon, and the boat's row
			var BY: float = b.H * 0.62
			var sea: Color = D.sea
			var air: Color = D.air
			n.draw_rect(Rect2(0, HY, b.W, b.H - HY), K.fog(sea, 0.85, air))
			var rows: int = D.rows
			for i in rows:                                                    # the sea recedes: rows bunch toward the horizon
				_sea_row(n, b, HY, i, rows, sea, air, 1.0)
			var s: float = b.W * 0.004
			var speed: float = D.speed
			var spread: float = D.spread
			var bx: float = fposmod(t * speed * b.W * 0.18, b.W * 1.5) - b.W * 0.25   # the boat crosses left → right
			var by := BY + sin(t * 2.0) * 2.0
			var L: float = b.W * 0.45                                         # how far back the wake reaches
			var rings: int = D.rings
			for k in range(rings, 0, -1):                                     # oldest rings first
				var age := float(k) / rings
				var rx := age * L * spread                                     # each ring was left where the boat was, and has grown since
				_ellipse_line(n, Vector2(bx - age * L, by), rx, rx * 0.3, K.alpha(Color.WHITE, (1.0 - age) * 0.55), 1.0 + (1.0 - age) * 1.2)   # squashed: we see the water at a low angle
			# the V's arms fade with distance — a gradient stroke, spelled as 12 segments of stepped alpha
			for arm in [-1.0, 1.0]:
				var armf: float = arm
				var stern := Vector2(bx, by)
				var tip := Vector2(bx - L, by + armf * L * spread * 0.3)
				for sg in 12:
					var k0 := float(sg) / 12.0
					var k1 := float(sg + 1) / 12.0
					K.line(n, stern.lerp(tip, k0), stern.lerp(tip, k1), K.alpha(Color.WHITE, 0.6 * (1.0 - (k0 + k1) / 2.0)), 1.0)
			K.soft(n, Vector2(bx - 16 * s, by), 8 * s, Color.WHITE, 0.6)     # foam at the stern
			K.poly(n, PackedVector2Array([Vector2(bx - 18 * s, by - 5 * s), Vector2(bx + 20 * s, by - 5 * s), Vector2(bx + 14 * s, by + 5 * s), Vector2(bx - 13 * s, by + 5 * s)]), D.hull)
			K.line(n, Vector2(bx, by - 5 * s), Vector2(bx, by - 40 * s), D.hull, 1.0)
			var sail: Color = D.sail                                          # the sail bellies: light → dark across it
			_grad_poly(n, PackedVector2Array([Vector2(bx + s, by - 38 * s), Vector2(bx + s, by - 7 * s), Vector2(bx + 22 * s, by - 7 * s)]),
				0, bx, bx + 22 * s, [K.shade(sail, 0.1), sail, K.shade(sail, -0.3)])
			K.label(n, b, D.label) })

	# ---- X · Xebec ---------------------------------------------------------
	d.append({ "letter": "X", "name": "Xebec",
		"hint": "a ship with lateen sails: each triangle filled dark → light across its width reads as a bellied curve — the sails breathe, the hull rocks, the sea recedes behind",
		"dials": { "sky": [Color("F5C169"), Color("F5E1B0"), Color("8FB8E0")], "sea": Color("2A5A8A"), "air": Color("E8D8B8"), "hull": Color("4A2A1A"), "sail": Color("F0E6D0"),
			"rows": 6, "belly": 1.0, "alpha": 1.0,                             # alpha: how solid the ship is
			"label": "a triangle with a sideways gradient is a curved sail; far rows, then the ship, then the near row" },
		"rhyme": { "name": "Ghost ship", "hint": "the same ship in grey under a night sky, drawn at half alpha so the sea shows through the hull — translucency is the whole haunting",
			"dials": { "sky": [Color("3A4A6A"), Color("1A2040"), Color("05051A")], "sea": Color("0A1A2A"), "air": Color("2A3A5A"), "hull": Color("3A4A5A"), "sail": Color("A8C8D8"),
				"alpha": 0.55,
				"label": "globalAlpha 0.55: the far rows show through the hull, so the ship reads as less THERE — alpha is presence" } },
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.belly = 0.3 + (pos.x / b.W) * 1.5,   # click right = a stiffer wind fills the sails
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var sky: Array = D.sky
			K.sky(n, b, [[0.0, sky[2]], [0.6, sky[1]], [1.0, sky[0]]])
			var HY: float = b.H * 0.45
			var s: float = b.W * 0.0045
			var sx: float = b.W * 0.5
			var sy: float = b.H * 0.66 + sin(t * 0.9) * 2.0
			K.soft(n, Vector2(b.W * 0.7, HY), b.W * 0.3, sky[0], 0.5)         # a low sun behind the ship
			var sea: Color = D.sea
			var air: Color = D.air
			n.draw_rect(Rect2(0, HY, b.W, b.H - HY), K.fog(sea, 0.85, air))
			var rows: int = D.rows
			for i in rows - 1:                                                # far rows first
				_sea_row(n, b, HY, i, rows, sea, air, -1.0)
			# the canvas globalAlpha has no _draw() spelling — the alpha is multiplied into every colour of the ship
			var al: float = D.alpha
			var hull := K.alpha(D.hull, al)
			var sail := K.alpha(D.sail, al)
			var belly: float = D.belly
			n.draw_set_transform(Vector2(sx, sy), sin(t * 0.9) * 0.05, Vector2.ONE)   # the hull rocks
			_lateen(n, -2 * s, 58 * s, s, sail, hull, belly, t)
			_lateen(n, 28 * s, 42 * s, s, sail, hull, belly, t)
			_grad_poly(n, PackedVector2Array([Vector2(-40 * s, -6 * s), Vector2(44 * s, -9 * s), Vector2(36 * s, 6 * s), Vector2(-34 * s, 6 * s)]),
				1, -8 * s, 6 * s, [K.shade(hull, 0.2), K.shade(hull, -0.4)])   # dark at the waterline
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_sea_row(n, b, HY, rows - 1, rows, sea, air, -1.0)               # the nearest row in front of the hull
			K.label(n, b, D.label) })

	# ---- Y · Yacht ---------------------------------------------------------
	d.append({ "letter": "Y", "name": "Yacht",
		"hint": "a yacht heeling in the wind: one tall triangle shaded across its width as a curved sail, the whole boat rotated by the heel — rows of sea behind and in front",
		"dials": { "sky": [Color("3A7FD0"), Color("B8D8F5")], "sea": Color("1E5A8F"), "air": Color("C8DCEE"), "hull": Color("F5F0E0"), "sail": Color.WHITE, "trim": Color("D82A2A"),
			"rows": 6, "boats": 1, "heel": 0.22, "speed": 1.0,                 # heel: radians of lean
			"label": "a triangle with a gradient across it is a sail; the heel is one rotate — rows behind, boat, rows in front" },
		"rhyme": { "name": "Regatta", "hint": "three of the same yacht, each on its own row — the far ones smaller and paler by the row they sit on — leaning harder, sailing faster",
			"dials": { "boats": 3, "heel": 0.3, "speed": 1.6,
				"label": "count 1 → 3: each boat is drawn right after its row, so the near sea covers the far hulls — order is depth" } },
		"init": func(b: Dictionary) -> void:
			b.dir = 1.0
			b.lean = b.D.heel,
		"tick": func(b: Dictionary, dt: float) -> void:
			var heel: float = b.D.heel
			var dir: float = b.dir
			var lean: float = b.lean
			b.lean = lean + (heel * dir - lean) * minf(1.0, dt * 3.0),        # the heel eases over to the wind's side
		"press": func(b: Dictionary, _pos: Vector2) -> void: b.dir = -b.dir,   # click = the wind changes sides; the yacht tacks
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			K.sky(n, b, D.sky)
			var HY: float = b.H * 0.4
			var sea: Color = D.sea
			var air: Color = D.air
			n.draw_rect(Rect2(0, HY, b.W, b.H - HY), K.fog(sea, 0.85, air))
			var rows: int = D.rows
			var boats: int = D.boats
			var speed: float = D.speed
			for i in rows:                                                    # rows far → near, each boat painted right after its row
				var p := float(i + 1) / rows
				var y := _sea_row(n, b, HY, i, rows, sea, air, -speed)
				for bt in boats:
					var row_of: int = rows - 2 if boats == 1 else int(round(1.0 + (float(bt) / (boats - 1)) * (rows - 3)))
					if row_of == i:
						_yacht(n, b, b.W * (0.5 + (bt - (boats - 1) / 2.0) * 0.3), y - 2.0 + sin(t * 1.4 * speed + bt) * 2.0, p)
			K.label(n, b, D.label) })

	# ---- Z · Zephyr --------------------------------------------------------
	d.append({ "letter": "Z", "name": "Zephyr",
		"hint": "the wind made visible: three translucent ribbons streaming across on long sine paths, twisting (width by |cos|) and fading toward their tails — leaves ride the same paths",
		"dials": { "sky": [Color("8FB8E0"), Color("E8F0F8")], "ribbon": Color.WHITE, "back": Color("B8D8F5"), "leaf": Color("7AB85A"),
			"ribbons": 3, "leaves": 6, "speed": 1.0, "len": 0.8, "segs": 40,   # len: ribbon length as a share of W
			"label": "the ribbon is the wind: alpha fades toward the tail, |cos| twists it, the leaves ride the same y(x)" },
		"rhyme": { "name": "Autumn gale", "hint": "the same wind in a warm dusk, nearly twice as fast, carrying three times the leaves in rust and orange — the ribbons barely change, the load does",
			"dials": { "sky": [Color("C88A4A"), Color("F5D9B0")], "ribbon": Color("FFF3E0"), "back": Color("E8B888"), "leaf": Color("D8602A"),
				"leaves": 18, "speed": 1.8,
				"label": "more leaves on the same y(x) and the wind reads as stronger — the passengers sell the ribbon" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(17)
			b.paths = []
			b.leaves = []
			var ribbons: int = D.ribbons
			for i in ribbons:
				b.paths.append({ "y": 0.22 + i * 0.24, "amp": 0.05 + R.randf() * 0.05, "f": 1.0 + R.randf() * 1.2, "off": R.randf() * 4.0, "sp": 0.8 + R.randf() * 0.4 })
			for l in int(D.leaves):
				b.leaves.append({ "p": l % ribbons, "s": 0.1 + R.randf() * 0.6, "spin": R.randf() * 9.0 }),
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.speed = 0.3 + (pos.x / b.W) * 2.5,   # click right = a stronger wind
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			K.sky(n, b, D.sky)
			K.ground(n, b, b.H * 0.9, Color("5A8A5A"))
			var ln: float = b.W * D.len
			var w: float = b.H * 0.05
			var segs: int = D.segs
			var speed: float = D.speed
			var ribbon: Color = D.ribbon
			var back: Color = D.back
			var leaf: Color = D.leaf
			var paths: Array = b.paths
			for i in paths.size():
				var p: Dictionary = paths[i]
				var off: float = p.off
				var sp: float = p.sp
				var head: float = fposmod(t * speed * b.W * 0.35 * sp + off * b.W, b.W + ln)   # the head crosses, then wraps
				for j in segs:
					var s0 := float(j) / segs
					var s1 := float(j + 1) / segs
					var x0 := head - s0 * ln
					var x1 := head - s1 * ln
					if x0 < 0.0 or x1 > b.W:
						continue
					var c := cos(s0 * TAU * 1.5 + t * 3.0 + i)                    # twist: width by |cos|, colour by its sign
					var hw := absf(c) * w / 2.0 + 0.4
					var y0 := _path_y(b, p, x0, t)
					var y1 := _path_y(b, p, x1, t)
					K.poly(n, PackedVector2Array([Vector2(x0, y0 - hw), Vector2(x1, y1 - hw), Vector2(x1, y1 + hw), Vector2(x0, y0 + hw)]),
						K.alpha(ribbon if c >= 0.0 else back, (1.0 - s0) * 0.6))   # fading toward the tail
				for o in b.leaves:
					if int(o.p) != i:
						continue
					var os: float = o.s
					var spin: float = o.spin
					var lx := head - os * ln
					var ly := _path_y(b, p, lx, t)
					if lx < 0.0 or lx > b.W:
						continue
					n.draw_set_transform(Vector2(lx, ly), t * 3.0 + spin, Vector2.ONE)
					K.ellipse(n, Vector2.ZERO, b.W * 0.014, b.W * 0.007, leaf)
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			K.label(n, b, D.label) })

	return d
