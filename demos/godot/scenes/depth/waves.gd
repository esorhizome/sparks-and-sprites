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

## The base y of sea row i (horizon + p²), exactly as _sea_row lays it out.
static func _row_y(b: Dictionary, HY: float, i: int, rows: int) -> float:
	var H: float = b.H
	var p := float(i + 1) / rows
	return HY + p * p * (H - HY) * 0.9

## The water of sea row i at column x — the same sine _sea_row draws — as
## (height below the row's base, slope dy/dx): what a hull sitting there feels.
## Wake / Xebec / Yacht spring their hulls toward this instead of a clock.
static func _sea_at(b: Dictionary, i: int, rows: int, x: float, tsign: float) -> Vector2:
	var W: float = b.W
	var t: float = b.t
	var p := float(i + 1) / rows
	var amp := 1.0 + p * p * 5.0
	var wl := W * (0.15 + p * 0.35)
	var ph := x / wl * TAU + tsign * t * (0.5 + p) + i
	return Vector2(sin(ph) * amp, cos(ph) * amp * TAU / wl)

## Tide: the front edge of row r at column x — a slow sine riding a fast one.
static func _edge_at(b: Dictionary, x: float, r: int, reach: float, t: float) -> float:
	var W: float = b.W
	var H: float = b.H
	return reach + sin(x / W * TAU * 1.5 - t * 1.2 + r * 1.1) * H * 0.03

## Xebec: a lateen sail — yard slanting low-forward to high-aft, the leech bowed out.
## Drawn in the ship's local space; sail_c / hull_c carry the ship's alpha already.
## breathe is the sprung belly (the card's tick chases the hull's roll with it).
static func _lateen(n: CanvasItem, mx: float, size: float, s: float, sail_c: Color, hull_c: Color, breathe: float) -> void:
	var ax := mx - size * 0.45
	var ay := -size * 1.05
	var fx := mx + size * 0.45
	var fy := -size * 0.35
	var cx := mx - size * 0.4
	var cy := -size * 0.12
	var ctrl := Vector2((fx + cx) / 2.0 + size * 0.25 * breathe, (fy + cy) / 2.0 + size * 0.1)
	var pts := PackedVector2Array([Vector2(ax, ay), Vector2(fx, fy)])
	for i in range(1, 8):
		pts.append(_qbez(Vector2(fx, fy), ctrl, Vector2(cx, cy), i / 8.0))
	pts.append(Vector2(cx, cy))
	# dark at the yard, light on the belly: a sideways gradient makes the triangle curve
	_grad_poly(n, pts, 0, ax, fx, [[0.0, K.shade(sail_c, -0.35)], [clampf(0.45 + breathe * 0.15, 0.01, 0.99), K.shade(sail_c, -0.05)], [1.0, K.shade(sail_c, 0.15)]])
	K.line(n, Vector2(ax, ay), Vector2(fx, fy), K.shade(hull_c, -0.3), 1.5)   # the yard
	K.line(n, Vector2(mx, -6.0 * s), Vector2(mx, -size), K.shade(hull_c, -0.3), 1.5)   # the mast

## Yacht: one boat at (x, y); z 0 far … 1 near sets its size and fog. The heel th
## is one rotate (this boat's sprung angle), the tack a mirror — both live in the
## transform, not the points.
static func _yacht(n: CanvasItem, b: Dictionary, x: float, y: float, z: float, th: float) -> void:
	var D: Dictionary = b.D
	var air: Color = D.air
	var dir: float = b.dir
	var W: float = b.W
	var s := W * 0.0045 * (0.3 + z * 0.7)
	var hull := K.fog(D.hull, (1.0 - z) * 0.6, air)
	var sail := K.fog(D.sail, (1.0 - z) * 0.6, air)
	n.draw_set_transform(Vector2(x, y), th, Vector2(dir, 1.0))          # the sprung heel, and a mirror for the wind's side
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
	d.append({ "letter": "F", "name": "Flag", "drag": true,
		"hint": "a flag is vertical strips sewn to the pole and pulled by their neighbours: the pole's vortices shove the first strip, the cloth carries the wave out and the free end swings furthest — shade each strip by its slope and the ripple becomes folds; a gust takes a second to reach the free end",
		"dials": { "sky": [Color("6FA8E8"), Color("CFE6F5")], "cloth": Color("D8302A"), "band": Color("F5F0E0"), "pole": Color("8A8A96"),
			"strips": 16,               # strips of cloth: the first is sewn to the pole and never moves
			"wind": 1.0,                # the wind a press asks for — the cloth feels a wind that CHASES this, it never jumps
			"waves": 1.6,               # waves along the flag at wind 1: sets the cloth's tension, k = (strips · f / waves)²
			"shade_by": 0.45,           # how hard the slope shades the cloth
			"damp": 0.6,                # each strip's damping, per second — low, so a gust rings down the cloth for a while
			"light": 1.1,               # each strip's stiffness-per-mass over the one before: the hoist is the heaviest band, so the wave GROWS toward the free end
			"drive": 0.04,              # the pole's vortex shove on the first strip, as a fraction of the flag's height per unit wind
			"flutter": 1.5,             # how fast the shedding oscillator grows to full swing (its van der pol gain)
			"label": "wind chases the press · pole vortices shove strip 1 · yᵢ'' = k(yᵢ₋₁ − 2yᵢ + yᵢ₊₁)/mᵢ − damp·yᵢ' · shade = slope" },
		"rhyme": { "name": "Pirate flag", "hint": "the same strips in black under a storm sky, a stiffer wind and more ripples — the folds now read from the white band alone",
			"dials": { "sky": [Color("2A2A3A"), Color("6A6A7A")], "cloth": Color("111118"), "band": Color("E8E5F4"), "pole": Color("5A5A66"),
				"wind": 1.9, "waves": 2.2,
				"label": "black cloth barely shades — the band carries the folds; more waves, a harder wind: a gale is two dials, the cloth still has to catch up" } },
		"init": func(b: Dictionary) -> void:
			# the cloth is a STRING of strips: each one pulled toward both its
			# neighbours by the cloth's tension (a wave equation), the first strip sewn
			# to the pole, the last with nothing beyond it — so a wave reaching the free
			# end has nothing to pull back and swings double. what sets it going is the
			# pole: air shedding off a rod pulses at a rate proportional to the wind
			# (strouhal), modelled as a self-excited oscillator that grows from any nudge
			# and saturates, shoving the first strip. the wind itself is a spring
			# chasing the pressed value, so a gust arrives late, and later still at the
			# free end: watch the ripple run out along the flag after a click.
			var nn := maxi(4, int(b.D.strips))
			var y := PackedFloat32Array()                 # each strip's lift as a fraction of the flag's height; strip 0 is the pole (sized here: a packed array read back from b is a copy)
			var v := PackedFloat32Array()                 # and its velocity
			y.resize(nn)
			v.resize(nn)
			b.n = nn
			b.y = y
			b.v = v
			b.wv = 0.0                                    # the wind the cloth feels: a spring chasing D.wind
			b.wvv = 0.0
			b.fx = 0.5                                    # the shedding oscillator, nudged off zero so it starts
			b.fv = 0.0,
		"tick": func(b: Dictionary, dt: float) -> void:
			var D: Dictionary = b.D
			var nn: int = b.n
			var y: PackedFloat32Array = b.y
			var v: PackedFloat32Array = b.v
			var wind: float = D.wind
			var waves: float = D.waves
			var damp: float = D.damp
			var light: float = D.light
			var drive: float = D.drive
			var flutter: float = D.flutter
			var wv: float = b.wv
			var wvv: float = b.wvv
			var fx: float = b.fx
			var fv: float = b.fv
			# the string's top mode rings at 2√k, and a symplectic step holds only while
			# √k·h < 1 — so a coarse frame is cut into substeps of at most 1/60 s
			var sub := maxi(1, ceili(dt * 60.0))
			var h := dt / float(sub)
			var kw := 6.0                                 # the wind's own spring — it settles on a press in about a second
			for _s in sub:
				wvv += (kw * (wind - wv) - 0.9 * 2.0 * sqrt(kw) * wvv) * h   # the wind eases toward the pressed value, just under critical
				wv += wvv * h
				var om := 4.0 * maxf(0.05, wv)                                # the shedding rate follows the wind
				fv += (-om * om * fx + flutter * om * (1.0 - fx * fx) * fv) * h   # van der pol: negative damping below |x| = 1, positive above — it settles at |x| ≈ 2
				fx += fv * h
				var kk := pow(float(nn) * om / TAU / waves, 2.0)              # tension so that `waves` fit along the flag at this wind
				var inv := 1.0                                                # 1 / this strip's mass
				for i in range(1, nn):
					inv *= light
					var f := kk * (y[i - 1] - y[i])                           # pulled toward the strip before …
					if i + 1 < nn:
						f += kk * (y[i + 1] - y[i])                           # … and the one after; the free end has none, and swings double
					if i == 1:
						f += fx * drive * wv * kk                             # the pole's vortex street shoves the first free strip
					v[i] += (f * inv - damp * v[i]) * h
				for i in range(1, nn):
					y[i] = clampf(y[i] + v[i] * h, -0.5, 0.5)
			b.wv = wv
			b.wvv = wvv
			b.fx = fx
			b.fv = fv
			b.y = y
			b.v = v,
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.wind = 0.3 + (pos.x / b.W) * 2.0,   # click right = more wind — the cloth's wind catches up over a second
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
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
			var nn: int = b.n
			var y: PackedFloat32Array = b.y
			var shade_by: float = D.shade_by
			var sw := fw / float(nn - 1)
			for j in nn - 1:                                                  # a quad per strip: its top edge runs from this lift to the next
				var kk := float(j) / float(nn - 1)
				var x0 := px + j * sw
				var x1 := x0 + sw + 0.5
				var y0 := top + y[j] * fh
				var y1 := top + y[j + 1] * fh
				var h0 := fh * (1.0 - kk * 0.08)                              # the free end hangs a little shorter
				var h1 := fh * (1.0 - float(j + 1) / float(nn - 1) * 0.08)
				var slope := (y1 - y0) / sw                                   # dy/dx across the strip — which way it faces
				var fold := clampf(1.0 - kk * 3.0, 0.0, 1.0) * 0.25           # the cloth shades itself where it bunches at the pole
				var lit := clampf(slope * 2.0 * shade_by - fold, -0.45, 0.45)
				K.poly(n, PackedVector2Array([Vector2(x0, y0), Vector2(x1, y1), Vector2(x1, y1 + h1), Vector2(x0, y0 + h0)]), K.shade(D.cloth, lit))
				K.poly(n, PackedVector2Array([Vector2(x0, y0 + h0 * 0.38), Vector2(x1, y1 + h1 * 0.38), Vector2(x1, y1 + h1 * 0.58), Vector2(x0, y0 + h0 * 0.58)]),
					K.shade(D.band, lit))                                     # a stripe rides the same folds
			K.label(n, b, D.label) })

	# ---- H · Helix ---------------------------------------------------------
	d.append({ "letter": "H", "name": "Helix", "drag": true,
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
	d.append({ "letter": "J", "name": "Jetstream", "drag": true,
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
		"hint": "a diamond of two triangles, lit and dark either side of the spar, held on a spring toward a slowly wandering point in the wind — click for a gust: it kicks the kite up and downwind, and the spring brings it back with an overshoot; its tail is a chain, each link following the last, twisting as it trails",
		"dials": { "sky": [Color("3A7FD0"), Color("B8D8F5")], "kite": Color("F5A15A"), "tail": Color("F05A8A"), "tail_back": Color("F5E0B0"),
			"links": 26, "link": 0.022, "bob": 1.0, "wind": 1.0,              # link: one chain segment, as a share of H
			"k": 20, "damp": 0.3,                                             # the body's position spring toward its wind-held point: stiffness, and damping as a fraction of critical (2√k) — under 1, so a gust overshoots
			"gust": 0.8,                                                      # a click's kick, in screens per second: up by gust·H, downwind by half that
			"label": "two flat shades meeting at the spar make a fold; the body is a spring on the wind, the tail a chain — each link follows the one before" },
		"rhyme": { "name": "Dragon kite", "hint": "the same diamond in red with a gold-and-crimson tail almost twice as long, over a festival dusk — the chain just has more links",
			"dials": { "sky": [Color("3A2A6A"), Color("F5A15A")], "kite": Color("D82A2A"), "tail": Color("F5C169"), "tail_back": Color("B81A1A"),
				"links": 44, "link": 0.02,
				"label": "a longer chain is the same rule run more times — the tail's whip is emergent, not drawn" } },
		"init": func(b: Dictionary) -> void:
			var links: int = b.D.links
			b.tail = []
			for i in links + 1:
				b.tail.append(Vector2(b.W * 0.6 - i * 4.0, b.H * 0.5 + i * 4.0))
			b.kx = b.W * 0.6                                                  # the body, and its velocity
			b.ky = b.H * 0.36
			b.vx = 0.0
			b.vy = 0.0
			b.lean = 0.0,
		"tick": func(b: Dictionary, dt: float) -> void:
			# the kite is a point on a spring. its REST wanders slowly — two slow sines
			# per axis stand in for the wind's drift — and the kite chases it, always
			# a little behind, always overshooting a touch. a gust is not a position:
			# it is velocity added to the kite, which then flies up and past the rest
			# and is pulled back, ringing down over a couple of seconds. the tail is a
			# constrained chain hung from the sprung body, so its whip is the body's
			# real motion run through the links.
			var D: Dictionary = b.D
			var t: float = b.t
			var links: int = D.links
			var bob: float = D.bob
			var wind: float = D.wind
			var k: float = D.k
			var damp: float = D.damp * 2.0 * sqrt(k)                          # a fraction of critical
			var rx: float = b.W * (0.6 + 0.05 * sin(t * 0.7) + 0.03 * sin(t * 1.9 + 1.0))   # the wind-held point drifts
			var ry: float = b.H * (0.36 + 0.05 * sin(t * 1.3 * bob) + 0.03 * sin(t * 0.53 + 2.0))
			# symplectic euler is stable while √k·h < 2 — a coarse frame is cut into substeps of at most 0.02 s
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			var kx: float = b.kx
			var ky: float = b.ky
			var vx: float = b.vx
			var vy: float = b.vy
			for _s in sub:
				vx += (k * (rx - kx) - damp * vx) * h
				kx += vx * h
				vy += (k * (ry - ky) - damp * vy) * h
				ky += vy * h
			kx = clampf(kx, b.W * 0.1, b.W * 0.95)
			ky = clampf(ky, b.H * 0.05, b.H * 0.8)
			b.kx = kx
			b.ky = ky
			b.vx = vx
			b.vy = vy
			b.lean = clampf(vx / (b.W * 0.6), -0.35, 0.35)                    # the kite banks with its sideways speed: the fold's shading shifts
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
		"press": func(b: Dictionary, _pos: Vector2) -> void:                  # click = a gust: velocity, not a place — the spring does the rest
			var gust: float = b.D.gust
			b.vy -= b.H * gust
			b.vx += b.W * gust * 0.5,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			K.sky(n, b, D.sky)
			K.ground(n, b, b.H * 0.9, Color("4A7A4A"))
			var kx: float = b.kx                                              # the sprung body
			var ky: float = b.ky
			var lean: float = b.lean
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
	d.append({ "letter": "L", "name": "Loop", "drag": true,
		"hint": "a ribbon tied in a loop-de-loop: quads round a circle, width = |cos| of the angle from the bottom, colour flipping to the back at the top — a car rides the inside, fast through the bottom and slow over the crown, its speed traded for height",
		"dials": { "sky": [Color("6FA8E8"), Color("CFE6F5")], "front": Color("F5C169"), "back": Color("8A5A2A"), "car": Color("D82A2A"),
			"segs": 72, "width": 0.11, "radius": 0.3,
			"car_speed": 1.2,                                                 # the car's angular speed at the bottom of the loop, rad/s — negative runs it backwards
			"gravity": 0.3,                                                   # the pull that trades speed for height, in (rad/s)² per loop radius: at the crown v² = car_speed² − 4·gravity
			"min_speed": 0.25,                                                # the car never quite stalls at the crown — a chain lift, rad/s
			"label": "the |cos| rule bent into a circle — front at the bottom, back at the top, edge-on at the sides; the car's speed is √(v₀² − 2g·h)" },
		"rhyme": { "name": "Roller coaster", "hint": "the same loop as a red rail under a carnival night, the car in gold running two and a half times faster",
			"dials": { "sky": [Color("1A1030"), Color("3A2A6A")], "front": Color("D82A2A"), "back": Color("5A0A0A"), "car": Color("F5C169"),
				"car_speed": 3.0,
				"label": "speed is a dial: at 3.0 the eye stops seeing a ribbon and starts seeing a ride — and a car that fast barely slows at the crown" } },
		"init": func(b: Dictionary) -> void:
			b.ca = 0.0,                                                       # the car's angle from the bottom
		"tick": func(b: Dictionary, dt: float) -> void:
			# the car's speed is not a dial, it is ENERGY: v² = v₀² − 2·g·h, with h the
			# height above the bottom of the loop (1 − cos of the angle, in radii). so
			# it is fastest through the bottom, slows climbing, crawls over the crown
			# and comes down faster again — and the angle is integrated with that
			# speed each frame rather than read off the clock. a floor keeps it from
			# stalling when the press sets a bottom speed too low to make the top.
			var D: Dictionary = b.D
			var cs: float = D.car_speed
			var g: float = D.gravity
			var vmin: float = D.min_speed
			var ca: float = b.ca
			var dir := -1.0 if cs < 0.0 else 1.0
			var w2 := cs * cs - 2.0 * g * (1.0 - cos(ca))                      # v² from the energy left at this height
			ca += dir * sqrt(maxf(w2, vmin * vmin)) * minf(dt, 0.05)
			b.ca = fposmod(ca, TAU),                                           # keep the angle in one turn
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.car_speed = (pos.x / b.W - 0.5) * 5.0,   # click left of centre = the car runs backwards; near the centre it barely makes the crown
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
			var ca: float = b.ca                                              # integrated by tick from the car's energy
			var cr := w * 0.35
			var cw := absf(cos(ca)) * w / 2.0 + 0.6                            # the car hugs the inside of the track
			K.sphere(n, Vector2(cx + sin(ca) * (R - cw - cr), cy + cos(ca) * (R - cw - cr)), cr, D.car, -0.5, -0.5, 0.5)
			K.label(n, b, D.label) })

	# ---- O · Ocean ---------------------------------------------------------
	d.append({ "letter": "O", "name": "Ocean", "drag": true,
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
		"hint": "a long strip drawn as short quads along a moving sine — its width is |cos(twist)|, and when cos goes negative the BACK colour shows; click to flick the head, and the extra twist runs down the strip as a real wave, reflects off the tail and rings down",
		"dials": { "sky": [Color("1A1030"), Color("2A1E4A")], "front": Color("F05A8A"), "back": Color("F5C169"),   # the two faces of the strip
			"width": 0.1, "segs": 64, "twists": 2.5, "speed": 1.0, "step": 0,   # step > 0 snaps the shown clock to 1/step s (jerky)
			"k": 2500.0,                # the torsion coupling between neighbouring segments: sets how fast a twist travels (√k segments per second)
			"damp": 2.0,                # each segment's damping, per second — a flick rings for a couple of seconds
			"ret": 40.0,                # the strip's own stiffness, pulling every segment back to its steady twist
			"flick": 160.0,             # the angular velocity a click gives the head, radians per second
			"label": "width = |cos(twist)|; cos < 0 shows the back · twist: ψₙ'' = k(ψₙ₋₁ − 2ψₙ + ψₙ₊₁) − ret·ψₙ − damp·ψₙ' · click: ψ₀' += flick" },
		"rhyme": { "name": "Glitch tape", "hint": "the same quads in magenta and cyan on black, faster, with time snapped to ninths of a second — the smoothness was a dial",
			"dials": { "sky": [Color("050508"), Color("0A0A12")], "front": Color("FF00C8"), "back": Color("00E5FF"), "speed": 1.6, "step": 9,
				"label": "floor(t × 9) / 9: the twist wave runs on smoothly underneath, the picture only refreshes nine times a second — glitch is a time dial" } },
		"init": func(b: Dictionary) -> void:
			# the steady twist is a spin along the strip that the clock winds on. on
			# top of it every node carries its OWN extra twist, and the nodes are a
			# torsion chain: each pulled toward both its neighbours (a wave equation),
			# and weakly back to zero by the strip's own stiffness. a click does not
			# draw a bump — it gives the head an angular VELOCITY, and the twist it
			# makes travels down the strip at √k nodes a second, doubles as it reflects
			# off the free tail, and rings down as the damping eats it.
			var nn := maxi(4, int(b.D.segs))
			var ps := PackedFloat32Array()                # each node's extra twist over the steady spin (sized here: a packed array read back from b is a copy)
			var om := PackedFloat32Array()                # and its angular velocity
			var shown := PackedFloat32Array()             # the twist the picture shows: the live one, or a snapshot when the clock is stepped
			ps.resize(nn + 1)
			om.resize(nn + 1)
			shown.resize(nn + 1)
			b.n = nn
			b.ps = ps
			b.om = om
			b.shown = shown
			b.snap_at = -1.0,
		"tick": func(b: Dictionary, dt: float) -> void:
			var D: Dictionary = b.D
			var nn: int = b.n
			var ps: PackedFloat32Array = b.ps
			var om: PackedFloat32Array = b.om
			var kk: float = D.k
			var damp: float = D.damp
			var ret: float = D.ret
			# the chain's top mode rings at 2√k, and a symplectic step holds only while
			# √k·h < 1 — so a coarse frame is cut into substeps of at most 1/60 s
			var sub := maxi(1, ceili(dt * 60.0))
			var h := dt / float(sub)
			for _s in sub:
				for i in nn + 1:
					var f := -ret * ps[i]                                     # the strip's own stiffness: back toward the steady twist
					if i > 0:
						f += kk * (ps[i - 1] - ps[i])                         # pulled toward the node before …
					if i < nn:
						f += kk * (ps[i + 1] - ps[i])                         # … and after; the tail has none, and swings double
					om[i] += (f - damp * om[i]) * h
				for i in nn + 1:
					ps[i] = clampf(ps[i] + om[i] * h, -6.0, 6.0)
			b.ps = ps
			b.om = om
			var stp: int = D.step
			if stp > 0:                                   # a stepped clock: the picture only refreshes 1/step s, the physics runs on
				var tt := floorf(b.t * stp) / stp
				if tt != float(b.snap_at):
					b.snap_at = tt
					var shown: PackedFloat32Array = b.shown
					for i in nn + 1:
						shown[i] = ps[i]
					b.shown = shown,
		"press": func(b: Dictionary, _pos: Vector2) -> void:
			var om: PackedFloat32Array = b.om
			om[0] += float(b.D.flick)                     # click = flick the head: a kick of angular velocity, never a jump in twist
			b.om = om,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var stp: int = D.step
			var tt: float = floorf(t * stp) / stp if stp > 0 else t
			K.sky(n, b, D.sky)
			var w: float = b.H * D.width
			var N: int = b.n
			var speed: float = D.speed
			var twists: float = D.twists
			var live: PackedFloat32Array = b.shown if stp > 0 else b.ps
			var px := PackedFloat32Array()
			var py := PackedFloat32Array()
			var tw := PackedFloat32Array()
			for i in N + 1:
				var k := float(i) / N
				px.append(b.W * (-0.04 + k * 1.08))
				py.append(b.H * (0.48 + 0.2 * sin(k * TAU * 1.2 - tt * speed * 1.4) + 0.06 * sin(k * TAU * 2.7 + tt * speed * 0.9)))
				tw.append(k * TAU * twists - tt * speed * 2.0 + live[i])     # the steady spin plus this node's own extra twist
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
	d.append({ "letter": "U", "name": "Undertow", "drag": true,
		"hint": "under the surface: caustic stripes wobbling in the light, seaweed at three depths — far ones paler, slower — each weed a chain of springs the current bends from the root, so the tips lag and whip through — and bubbles rising faster the nearer they are",
		"dials": { "water": [Color("1A6A9A"), Color("052040")], "air": Color("2A6A9A"), "weed": Color("2A8A4A"), "light": Color("B8F0FF"), "bubble": Color("E8F8FF"),
			"depths": 3, "weeds": 4, "bubbles": 22, "glow": false,
			"sway": 1.0,                # the current's strength: scales the lean the root's rest is bent to (a press moves this, never the weed)
			"k": 40.0,                  # the root spring's stiffness (per inertia): a weed rights itself in about a second
			"damp": 6.0,                # its damping (2√k = 12.6 would be critical): well under, so the root overshoots
			"tip": 1.25,                # each segment's k as a multiple of the one below — lighter up the weed, so the same bend rights it faster
			"tipdamp": 0.6,             # a segment's damping as a fraction of ITS OWN critical: under 1, so the tip overshoots the root and whips through
			"lean": 0.45,               # radians the current asks of the root at sway 1
			"label": "root: θ'' = k·(current − θ) − damp·θ' · segment j: kⱼ = tip·kⱼ₋₁ chasing θⱼ₋₁ · far weed paler and slower, near bubbles bigger and faster" },
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
				b.bubbles.append({ "x": R.randf() * b.W, "y": R.randf(), "z": R.randf(), "ph": R.randf() * 9.0 })
			# a weed is a CHAIN of angles from vertical, one per segment — the stagecraft
			# Grass, under water. the root is a damped spring toward a rest the CURRENT
			# sets: two slow sines, slower for the far weeds, scaled by sway. every
			# segment above is the same spring again, its rest the angle of the segment
			# below, quicker (k · tip: a lighter segment, same bend) and less damped
			# (tipdamp of its own critical) — so when the current turns, the root goes
			# first, the tip follows late and whips through when the current comes back.
			# a press moves the rest; the weed has to get there by itself.
			var th := PackedFloat32Array()                # segment angles from vertical, weed-major, 9 per weed (sized here: a packed array read back from b is a copy)
			var om := PackedFloat32Array()                # and their angular velocities
			th.resize(b.weeds.size() * 9)
			om.resize(b.weeds.size() * 9)
			b.th = th
			b.om = om,
		"tick": func(b: Dictionary, dt: float) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var th: PackedFloat32Array = b.th
			var om: PackedFloat32Array = b.om
			var kk: float = D.k
			var damp: float = D.damp
			var tip: float = D.tip
			var tipdamp: float = D.tipdamp
			var lean: float = D.lean
			var sway: float = D.sway
			var weeds: Array = b.weeds
			# the segments up a weed are stiffer than the root (k · tip each), and a
			# symplectic step holds only while √k·h < 2 — so a coarse frame is cut into
			# substeps of at most 0.02 s; at 60 fps that is one step
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			for j in weeds.size():
				var s: Dictionary = weeds[j]
				var z: float = s.z
				var sph: float = s.ph
				var sp := 0.6 + z * 0.8                                       # far weed: a slower current
				var rest := lean * sway * (0.6 * sin(t * sp * 0.9 + sph) + 0.4 * sin(t * sp * 0.37 + sph * 2.0))
				for _s in sub:
					var below := rest                                         # the root chases the current; each segment chases the one below
					var kj := kk
					var dj := damp
					for g in 9:
						var i := j * 9 + g
						om[i] += (kj * (below - th[i]) - dj * om[i]) * h
						th[i] = clampf(th[i] + om[i] * h, -1.4, 1.4)
						below = th[i]
						kj *= tip                                             # the next segment up: quicker …
						dj = tipdamp * 2.0 * sqrt(kj)                         # … and a fraction of ITS critical
			b.th = th
			b.om = om,
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.sway = 0.2 + (pos.x / b.W) * 2.5,   # click right = a stronger current — the rest moves, the weed catches up
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
			var th: PackedFloat32Array = b.th
			var weeds: Array = b.weeds
			for j in weeds.size():                                            # seaweed: walk the chain, a quad per segment, shaded by its lean
				var s: Dictionary = weeds[j]
				var z: float = s.z
				var sx: float = s.x
				var hgt: float = b.H * s.h * (0.5 + z * 0.6)
				var base: float = GY - (1.0 - z) * b.H * 0.05
				var seg := hgt / 9.0
				var c := K.fog(D.weed, (1.0 - z) * 0.75, air)
				var px := sx
				var py := base
				for k in 9:
					var q := float(k + 1) / 9.0
					var a: float = th[j * 9 + k]
					var nx := px + sin(a) * seg
					var ny := py - cos(a) * seg
					var hw := (1.0 - q * 0.7) * (2.0 + z * 5.0)
					K.poly(n, PackedVector2Array([Vector2(px - hw, py), Vector2(nx - hw, ny), Vector2(nx + hw, ny), Vector2(px + hw, py)]),
						K.shade(c, sin(a) * 0.3))                                # the lean is the slope: pale when leaning into the light
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
	d.append({ "letter": "W", "name": "Wake", "drag": true,
		"hint": "a boat crossing rows of receding sea, trailing a V of ripples — every ring is dropped where the stern was and grows from there, older ones wider and fainter, squashed flat by perspective; the hull rides the swell on a spring, pitching with its heave — click right = faster boat, and the rings already dropped stay put",
		"dials": { "sky": [Color("6FA8E8"), Color("CFE6F5")], "sea": Color("1E5A8F"), "air": Color("C8DCEE"), "hull": Color("2A1E1A"), "sail": Color("F5F0E0"),
			"rows": 6,
			"rings": 32,                                                      # how many rings are kept alive — the oldest is recycled when a new one drops
			"speed": 1.0,                                                     # the boat's speed: 1 = 0.18 screens per second
			"spread": 0.45,                                                   # how fast a ring grows, as a share of the boat's speed at speed 1 — the V's half-angle is atan(spread / speed)
			"drop": 0.08,                                                     # seconds between rings
			"life": 2.4,                                                      # seconds a ring lives, growing and fading the whole time
			"k": 36.0, "damp": 0.35,                                          # the hull's heave spring toward the water under it: stiffness, and damping as a fraction of critical (2√k)
			"pitch_k": 25.0, "pitch_damp": 0.3,                               # the pitch spring, whose rest is the heave velocity × pitch_gain — the bow lifts as the hull rises
			"pitch_gain": 0.004,                                              # radians of pitch per px/s of heave
			"label": "each ring is a stored (x, y, born): it grows at one rate while the boat runs on — the V is their envelope, angle = ring growth ÷ boat speed" },
		"rhyme": { "name": "Speedboat", "hint": "the same rings behind a white hull with no sail, two and a half times faster, the rings growing nearly twice as fast — bigger rings, but a tighter V, because the V's angle is growth over speed; click to change speed and the rings already dropped stay put",
			"dials": { "hull": Color("F0F0F5"), "sail": Color(0, 0, 0, 0), "speed": 2.4, "spread": 0.8,
				"label": "the V's angle is ring growth over boat speed: 0.8 / 2.4 — bigger rings, tighter V; a press leaves the old rings behind" } },
		"init": func(b: Dictionary) -> void:
			var cap: int = maxi(1, int(b.D.rings))
			var rx := PackedFloat32Array()                # sized here: a packed array read back from b is a copy
			var ry := PackedFloat32Array()
			var rborn := PackedFloat32Array()
			rx.resize(cap)
			ry.resize(cap)
			rborn.resize(cap)
			b.rx = rx                                     # the ring buffer: where each ring was dropped, and when
			b.ry = ry
			b.rborn = rborn
			b.rhead = 0
			b.rcount = 0
			b.since = 0.0                                 # seconds since the last ring dropped
			b.bx = -b.W * 0.25                            # the boat enters from the left
			b.by = b.H * 0.62                             # the hull's height and heave velocity
			b.vy = 0.0
			b.pitch = 0.0                                 # the hull's pitch and its rate
			b.pv = 0.0,
		"tick": func(b: Dictionary, dt: float) -> void:
			# the wake is a MEMORY: every `drop` seconds the stern leaves a ring on the
			# water, and from then on the ring is on its own — radius and alpha come from
			# its age, nothing else. the boat never looks back to draw them, so when it
			# wraps to the left edge, or a press changes its speed, the rings already
			# dropped stay exactly where they were. the V is only their envelope: the
			# tangent through the stern, whose slope is ring growth over boat speed.
			# the hull is a damped spring toward the water height under it (the same
			# sine the boat's sea row draws), and the pitch is a second spring whose
			# rest is the heave velocity — so the bow lifts as the hull rises and the
			# hull overshoots each crest a little, because both are under-damped.
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W
			var H: float = b.H
			var rows: int = D.rows
			var v: float = float(D.speed) * W * 0.18                          # px/s: the boat
			var bx: float = b.bx + v * dt
			if bx > W * 1.25:                                                 # the boat wraps; the rings it dropped do not
				bx -= W * 1.5
			b.bx = bx
			var BY := H * 0.62
			var ri := maxi(0, rows - 3)                                       # the boat's sea row
			var water: float = BY + _sea_at(b, ri, rows, bx, 1.0).x           # the water under the hull, this frame
			var k: float = D.k
			var damp: float = float(D.damp) * 2.0 * sqrt(k)                   # a fraction of critical
			var pk: float = D.pitch_k
			var pdamp: float = float(D.pitch_damp) * 2.0 * sqrt(pk)
			var gain: float = D.pitch_gain
			# symplectic euler is stable while √k·h < 2 — a coarse frame is cut into substeps of at most 0.02 s
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			var by: float = b.by
			var vy: float = b.vy
			var pitch: float = b.pitch
			var pv: float = b.pv
			for _s in sub:
				vy += (k * (water - by) - damp * vy) * h                      # heave: chase the water
				by += vy * h
				var prest := clampf(vy * gain, -0.3, 0.3)                     # pitch: chase the heave velocity — rising = bow up
				pv += (pk * (prest - pitch) - pdamp * pv) * h
				pitch = clampf(pitch + pv * h, -0.5, 0.5)
			b.by = clampf(by, BY - H * 0.2, BY + H * 0.2)
			b.vy = vy
			b.pitch = pitch
			b.pv = pv
			var rx: PackedFloat32Array = b.rx
			var ry: PackedFloat32Array = b.ry
			var rborn: PackedFloat32Array = b.rborn
			var cap := rx.size()
			var s := W * 0.004
			var since: float = b.since + dt
			var drop: float = maxf(0.01, D.drop)
			while since >= drop:                                              # drop a ring where the stern is now (it is `since` seconds old already)
				since -= drop
				var hd: int = b.rhead
				rx[hd] = bx - 16.0 * s
				ry[hd] = water
				rborn[hd] = t - since
				b.rhead = (hd + 1) % cap
				b.rcount = mini(int(b.rcount) + 1, cap)
			b.since = since,
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.speed = 0.3 + (pos.x / b.W) * 2.0,   # click right = faster boat — the rings already dropped stay where they are
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			K.sky(n, b, D.sky)
			var HY: float = b.H * 0.32                                        # the horizon; the boat's row is at 0.62
			var sea: Color = D.sea
			var air: Color = D.air
			n.draw_rect(Rect2(0, HY, b.W, b.H - HY), K.fog(sea, 0.85, air))
			var rows: int = D.rows
			for i in rows:                                                    # the sea recedes: rows bunch toward the horizon
				_sea_row(n, b, HY, i, rows, sea, air, 1.0)
			var s: float = b.W * 0.004
			var v: float = float(D.speed) * b.W * 0.18                        # px/s: the boat, and a ring's radius
			var grow: float = float(D.spread) * b.W * 0.18
			var life: float = D.life
			var bx: float = b.bx
			var by: float = b.by
			var rx: PackedFloat32Array = b.rx
			var ry: PackedFloat32Array = b.ry
			var rborn: PackedFloat32Array = b.rborn
			var cap := rx.size()
			var cnt: int = b.rcount
			var hd: int = b.rhead
			for j in cnt:                                                     # oldest rings first
				var idx := (hd - cnt + j + cap) % cap
				var age := t - rborn[idx]
				if age < 0.0 or age > life:
					continue
				var r := grow * age                                           # each ring has grown since it was dropped, and faded
				var fade := 1.0 - age / life
				_ellipse_line(n, Vector2(rx[idx], ry[idx]), r, r * 0.3, K.alpha(Color.WHITE, fade * 0.55), 1.0 + fade * 1.2)   # squashed: we see the water at a low angle
			# the envelope: where the oldest living ring is, and how wide it has grown (squashed) —
			# the V's arms fade with distance, a gradient stroke spelled as 12 segments of stepped alpha
			var L := v * life
			var A := grow * life * 0.3
			for arm in [-1.0, 1.0]:
				var armf: float = arm
				var stern := Vector2(bx, by)
				var tip := Vector2(bx - L, by + armf * A)
				for sg in 12:
					var k0 := float(sg) / 12.0
					var k1 := float(sg + 1) / 12.0
					K.line(n, stern.lerp(tip, k0), stern.lerp(tip, k1), K.alpha(Color.WHITE, 0.6 * (1.0 - (k0 + k1) / 2.0)), 1.0)
			n.draw_set_transform(Vector2(bx, by), b.pitch, Vector2.ONE)       # the hull: heaved and pitched by the springs
			K.soft(n, Vector2(-16 * s, 0.0), 8 * s, Color.WHITE, 0.6)        # foam at the stern
			K.poly(n, PackedVector2Array([Vector2(-18 * s, -5 * s), Vector2(20 * s, -5 * s), Vector2(14 * s, 5 * s), Vector2(-13 * s, 5 * s)]), D.hull)
			K.line(n, Vector2(0.0, -5 * s), Vector2(0.0, -40 * s), D.hull, 1.0)
			var sail: Color = D.sail                                          # the sail bellies: light → dark across it
			_grad_poly(n, PackedVector2Array([Vector2(s, -38 * s), Vector2(s, -7 * s), Vector2(22 * s, -7 * s)]),
				0, 0.0, 22 * s, [K.shade(sail, 0.1), sail, K.shade(sail, -0.3)])
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			K.label(n, b, D.label) })

	# ---- X · Xebec ---------------------------------------------------------
	d.append({ "letter": "X", "name": "Xebec", "drag": true,
		"hint": "a ship with lateen sails: each triangle filled dark → light across its width reads as a bellied curve — the hull rides the swell under it on a spring, rolls to the water's slope on another, and the sails fill and slacken on a third that chases the roll and overshoots; the sea recedes behind — click right = a stiffer wind",
		"dials": { "sky": [Color("F5C169"), Color("F5E1B0"), Color("8FB8E0")], "sea": Color("2A5A8A"), "air": Color("E8D8B8"), "hull": Color("4A2A1A"), "sail": Color("F0E6D0"),
			"rows": 6,
			"belly": 1.0,                                                     # the belly the wind asks for — the sails' spring chases it
			"alpha": 1.0,                                                     # how solid the ship is
			"k": 16.0, "damp": 0.4,                                           # the hull's heave spring toward the water under it: stiffness, and damping as a fraction of critical (2√k)
			"roll_k": 12.0, "roll_damp": 0.35,                                # the roll spring — its rest is the water's slope under the hull × roll_gain
			"roll_gain": 0.35,                                                # radians of roll per unit of slope (dy/dx)
			"sail_k": 25.0, "sail_damp": 0.25,                                # the sails' belly spring, chasing the hull's roll — less damped, so the rig lags and overshoots at the top of each roll
			"sail_gain": 3.0,                                                 # how much a radian of roll swells (or slackens) the belly
			"label": "a sideways gradient bends a triangle into a sail; hull chases the swell, roll chases its slope, the rig chases the roll — three springs" },
		"rhyme": { "name": "Ghost ship", "hint": "the same ship in grey under a night sky, drawn at half alpha so the sea shows through the hull — translucency is the whole haunting",
			"dials": { "sky": [Color("3A4A6A"), Color("1A2040"), Color("05051A")], "sea": Color("0A1A2A"), "air": Color("2A3A5A"), "hull": Color("3A4A5A"), "sail": Color("A8C8D8"),
				"alpha": 0.55,
				"label": "globalAlpha 0.55: the far rows show through the hull, so the ship reads as less THERE — alpha is presence" } },
		"init": func(b: Dictionary) -> void:
			b.sy = b.H * 0.66                             # the hull's height and heave velocity
			b.vy = 0.0
			b.roll = 0.0                                  # the hull's roll and its rate
			b.rv = 0.0
			b.bel = float(b.D.belly) * 0.85               # the sails' belly and its rate
			b.bv = 0.0,
		"tick": func(b: Dictionary, dt: float) -> void:
			# three springs, each chasing the one before. the hull chases the water
			# height under it — the same sine its sea row draws — and overshoots each
			# crest a little (damp < 1). the roll chases the water's SLOPE there, so
			# the ship leans down the face of each swell and rights itself past
			# vertical. the sails chase the roll on a looser spring: they fill as the
			# hull rolls toward the wind, lag behind it, and swell past the rest at
			# the top of the roll — the rig is the last thing to settle. a press moves
			# the belly's target; the sails take their own time getting there.
			var D: Dictionary = b.D
			var H: float = b.H
			var rows: int = D.rows
			var SY := H * 0.66
			var wave := _sea_at(b, maxi(0, rows - 3), rows, b.W * 0.5, -1.0)   # the water under the hull: its height, and its slope
			var water := SY + wave.x
			var slope := wave.y
			var k: float = D.k
			var damp: float = float(D.damp) * 2.0 * sqrt(k)                   # each damping is a fraction of its own critical
			var rk: float = D.roll_k
			var rdamp: float = float(D.roll_damp) * 2.0 * sqrt(rk)
			var rgain: float = D.roll_gain
			var sk: float = D.sail_k
			var sdamp: float = float(D.sail_damp) * 2.0 * sqrt(sk)
			var sgain: float = D.sail_gain
			var belly: float = D.belly
			# symplectic euler is stable while √k·h < 2 — a coarse frame is cut into substeps of at most 0.02 s
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			var sy: float = b.sy
			var vy: float = b.vy
			var roll: float = b.roll
			var rv: float = b.rv
			var bel: float = b.bel
			var bv: float = b.bv
			for _s in sub:
				vy += (k * (water - sy) - damp * vy) * h                      # heave: chase the water height
				sy += vy * h
				var rrest := clampf(slope * rgain, -0.4, 0.4)                 # roll: chase the water's slope
				rv += (rk * (rrest - roll) - rdamp * rv) * h
				roll = clampf(roll + rv * h, -0.6, 0.6)
				var brest := belly * (0.85 + sgain * roll)                    # belly: chase the roll, on the loosest spring
				bv += (sk * (brest - bel) - sdamp * bv) * h
				bel = clampf(bel + bv * h, 0.05, 3.0)
			b.sy = clampf(sy, SY - H * 0.2, SY + H * 0.2)
			b.vy = vy
			b.roll = roll
			b.rv = rv
			b.bel = bel
			b.bv = bv,
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.belly = 0.3 + (pos.x / b.W) * 1.5,   # click right = a stiffer wind — it moves the belly's target, and the sails' spring follows
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var sky: Array = D.sky
			K.sky(n, b, [[0.0, sky[2]], [0.6, sky[1]], [1.0, sky[0]]])
			var HY: float = b.H * 0.45
			var s: float = b.W * 0.0045
			var sx: float = b.W * 0.5
			var sy: float = b.sy                                              # the sprung hull
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
			var bel: float = b.bel
			n.draw_set_transform(Vector2(sx, sy), b.roll, Vector2.ONE)        # the hull: heaved and rolled by its springs
			_lateen(n, -2 * s, 58 * s, s, sail, hull, bel)
			_lateen(n, 28 * s, 42 * s, s, sail, hull, bel)
			_grad_poly(n, PackedVector2Array([Vector2(-40 * s, -6 * s), Vector2(44 * s, -9 * s), Vector2(36 * s, 6 * s), Vector2(-34 * s, 6 * s)]),
				1, -8 * s, 6 * s, [K.shade(hull, 0.2), K.shade(hull, -0.4)])   # dark at the waterline
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_sea_row(n, b, HY, rows - 1, rows, sea, air, -1.0)               # the nearest row in front of the hull
			K.label(n, b, D.label) })

	# ---- Y · Yacht ---------------------------------------------------------
	d.append({ "letter": "Y", "name": "Yacht",
		"hint": "a yacht heeling in the wind: one tall triangle shaded across its width as a curved sail, the whole boat rotated by the heel — the heel is an under-damped spring, so a tack swings past upright and settles back, and the hull rides its row's swell on another; rows of sea behind and in front — click = tack",
		"dials": { "sky": [Color("3A7FD0"), Color("B8D8F5")], "sea": Color("1E5A8F"), "air": Color("C8DCEE"), "hull": Color("F5F0E0"), "sail": Color.WHITE, "trim": Color("D82A2A"),
			"rows": 6, "boats": 1,
			"heel": 0.22,                                                     # radians of lean the wind asks for
			"speed": 1.0,
			"k": 16.0, "damp": 0.35,                                          # the heel spring: ω = √k ≈ 4 rad/s, and damping as a fraction of critical (2√k) — under 1, so a tack overshoots
			"slope_gain": 0.25,                                               # radians of extra heel per unit of the water's slope under the hull — the swell rocks the boat
			"bob_k": 30.0, "bob_damp": 0.4,                                   # the hull's heave spring toward the water under it
			"label": "a triangle with a gradient across it is a sail; the heel is one rotate on a spring — a tack swings past and settles; rows behind, boat, rows in front" },
		"rhyme": { "name": "Regatta", "hint": "three of the same yacht, each on its own row — the far ones smaller and paler by the row they sit on — leaning harder, sailing faster",
			"dials": { "boats": 3, "heel": 0.3, "speed": 1.6,
				"label": "count 1 → 3: each boat is drawn right after its row, so the near sea covers the far hulls — and each tacks on its own spring" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var rows: int = D.rows
			var boats: int = maxi(1, int(D.boats))
			var HY: float = b.H * 0.4
			b.dir = 1.0
			b.n = boats
			var row_of := PackedInt32Array()              # which row each boat sits on, and where — fixed for the card's life
			var bx := PackedFloat32Array()
			var th := PackedFloat32Array()                # sized here: a packed array read back from b is a copy
			var om := PackedFloat32Array()
			var by := PackedFloat32Array()
			var vy := PackedFloat32Array()
			for bt in boats:
				var r: int = rows - 2 if boats == 1 else int(round(1.0 + (float(bt) / (boats - 1)) * (rows - 3)))
				row_of.append(r)
				bx.append(b.W * (0.5 + (bt - (boats - 1) / 2.0) * 0.3))
				th.append(float(D.heel))
				om.append(0.0)
				by.append(_row_y(b, HY, r, rows) - 2.0)
				vy.append(0.0)
			b.row_of = row_of
			b.bx = bx
			b.th = th                                     # each boat's heel and its rate
			b.om = om
			b.by = by                                     # each boat's height and heave velocity
			b.vy = vy,
		"tick": func(b: Dictionary, dt: float) -> void:
			# the heel is a damped spring toward heel·dir plus the slope of the water
			# under the hull. a tack flips the TARGET, never the angle: the boat swings
			# through upright, overshoots the new side by a third (ζ ≈ 0.35), and
			# settles in about two seconds — the follow-through is what sells the
			# weight of the boat. the hull's height is a second spring chasing the
			# water under it, so it lifts a beat after each crest. every boat keeps
			# its own state, so in a fleet no two are at the same point of the swing.
			var D: Dictionary = b.D
			var H: float = b.H
			var rows: int = D.rows
			var speed: float = D.speed
			var heel: float = D.heel
			var dir: float = b.dir
			var k: float = D.k
			var damp: float = float(D.damp) * 2.0 * sqrt(k)                   # a fraction of critical
			var sgain: float = D.slope_gain
			var bk: float = D.bob_k
			var bdamp: float = float(D.bob_damp) * 2.0 * sqrt(bk)
			var HY := H * 0.4
			var nn: int = b.n
			var row_of: PackedInt32Array = b.row_of
			var bx: PackedFloat32Array = b.bx
			var th: PackedFloat32Array = b.th
			var om: PackedFloat32Array = b.om
			var by: PackedFloat32Array = b.by
			var vy: PackedFloat32Array = b.vy
			# symplectic euler is stable while √k·h < 2 — a coarse frame is cut into substeps of at most 0.02 s
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			for i in nn:
				var r: int = row_of[i]
				var base := _row_y(b, HY, r, rows) - 2.0
				var wave := _sea_at(b, r, rows, bx[i], -speed)                # the water under this hull: height and slope
				var water := base + wave.x
				var rest := heel * dir + clampf(wave.y * sgain, -0.3, 0.3)    # the wind's side, plus the swell's tilt
				for _s in sub:
					om[i] += (k * (rest - th[i]) - damp * om[i]) * h
					th[i] = clampf(th[i] + om[i] * h, -1.2, 1.2)
					vy[i] += (bk * (water - by[i]) - bdamp * vy[i]) * h
					by[i] += vy[i] * h
				by[i] = clampf(by[i], base - H * 0.15, base + H * 0.15),
		"press": func(b: Dictionary, _pos: Vector2) -> void: b.dir = -b.dir,   # click = the wind changes sides; the target flips, the spring does the tack
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			K.sky(n, b, D.sky)
			var HY: float = b.H * 0.4
			var sea: Color = D.sea
			var air: Color = D.air
			n.draw_rect(Rect2(0, HY, b.W, b.H - HY), K.fog(sea, 0.85, air))
			var rows: int = D.rows
			var speed: float = D.speed
			var nn: int = b.n
			var row_of: PackedInt32Array = b.row_of
			var bx: PackedFloat32Array = b.bx
			var th: PackedFloat32Array = b.th
			var by: PackedFloat32Array = b.by
			for i in rows:                                                    # rows far → near, each boat painted right after its row
				var p := float(i + 1) / rows
				_sea_row(n, b, HY, i, rows, sea, air, -speed)
				for bt in nn:
					if row_of[bt] == i:
						_yacht(n, b, bx[bt], by[bt], p, th[bt])
			K.label(n, b, D.label) })

	# ---- Z · Zephyr --------------------------------------------------------
	d.append({ "letter": "Z", "name": "Zephyr", "drag": true,
		"hint": "the wind made visible: three translucent ribbons streaming across on long sine paths, twisting (width by |cos|) and fading toward their tails — leaves chase the same paths on a spring, so they lag each crest, overshoot it, and spin as fast as they are thrown",
		"dials": { "sky": [Color("8FB8E0"), Color("E8F0F8")], "ribbon": Color.WHITE, "back": Color("B8D8F5"), "leaf": Color("7AB85A"),
			"ribbons": 3, "leaves": 6, "speed": 1.0, "len": 0.8, "segs": 40,   # len: ribbon length as a share of W
			"k": 40.0,                  # a leaf's spring toward the ribbon's height at its x: light, so it takes ~0.2 s to answer
			"damp": 5.0,                # its damping (2√k = 12.6 would be critical): well under, so a leaf overshoots every crest
			"spin": 8.0,                # radians of spin per screen-width of travel — the leaf turns as fast as it is thrown
			"label": "the ribbon is the wind: alpha fades to the tail, |cos| twists it · leaf: y'' = k·(ribbon(x) − y) − damp·y' · spin' ∝ |vx| + |vy|" },
		"rhyme": { "name": "Autumn gale", "hint": "the same wind in a warm dusk, nearly twice as fast, carrying three times the leaves in rust and orange — the ribbons barely change, the load does",
			"dials": { "sky": [Color("C88A4A"), Color("F5D9B0")], "ribbon": Color("FFF3E0"), "back": Color("E8B888"), "leaf": Color("D8602A"),
				"leaves": 18, "speed": 1.8,
				"label": "more leaves chasing the same y(x), faster, and the wind reads as stronger — they fall further behind each crest, and spin harder" } },
		"init": func(b: Dictionary) -> void:
			# the ribbon is the wind's path, y(x). a leaf is not ON it: it is carried
			# along in x at the wind's speed, and in y it is a damped spring chasing
			# the ribbon's height at its x — so it lags every crest and overshoots it,
			# more the faster the wind (a press moves the wind; the leaf catches up).
			# its spin is integrated from how fast it is being thrown, sideways and
			# up-down, not read off the clock: a leaf at rest in still air would stop.
			var D: Dictionary = b.D
			var R := K.rng(17)
			b.paths = []
			b.leaves = []
			var ribbons: int = D.ribbons
			for i in ribbons:
				b.paths.append({ "y": 0.22 + i * 0.24, "amp": 0.05 + R.randf() * 0.05, "f": 1.0 + R.randf() * 1.2, "off": R.randf() * 4.0, "sp": 0.8 + R.randf() * 0.4 })
			for l in int(D.leaves):                                          # y, vy, rot: the leaf's state; px: its last x, to spot a wrap
				b.leaves.append({ "p": l % ribbons, "s": 0.1 + R.randf() * 0.6, "spin": R.randf() * 9.0, "y": -1.0, "vy": 0.0, "rot": 0.0, "px": -1.0e9 }),
		"tick": func(b: Dictionary, dt: float) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W
			var H: float = b.H
			var ln: float = W * D.len
			var speed: float = D.speed
			var kk: float = D.k
			var damp: float = D.damp
			var spin: float = D.spin
			var paths: Array = b.paths
			var sub := maxi(1, ceili(dt * 50.0))        # substeps of at most 0.02 s keep the leaf springs stable on a coarse frame
			var h := dt / float(sub)
			for o in b.leaves:
				var p: Dictionary = paths[int(o.p)]
				var off: float = p.off
				var sp: float = p.sp
				var head: float = fposmod(t * speed * W * 0.35 * sp + off * W, W + ln)
				var os: float = o.s
				var lx := head - os * ln
				var target := _path_y(b, p, lx, t)
				var vx := speed * W * 0.35 * sp                                # how fast the wind carries it
				var oy: float = o.y
				var vy: float = o.vy
				var rot: float = o.rot
				var last_x: float = o.px
				if last_x < -1.0e8 or lx < last_x - W * 0.5:                  # the ribbon wrapped (or this is the first frame): a fresh leaf, starting on the path
					oy = target
					vy = 0.0
				o.px = lx
				for _s in sub:
					vy += (kk * (target - oy) - damp * vy) * h                # chase the ribbon's height, under-damped
					oy = clampf(oy + vy * h, -H, H * 2.0)
					rot += (absf(vx) + absf(vy) * 2.0) / W * spin * h         # spin from how fast it is thrown, not from the clock
				o.y = oy
				o.vy = vy
				o.rot = rot,
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.speed = 0.3 + (pos.x / b.W) * 2.5,   # click right = a stronger wind — the leaves fall behind, then catch up
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
					var ly: float = o.y                                       # where the leaf's spring has got to, not the ribbon's y
					var rot: float = o.rot
					if lx < 0.0 or lx > b.W:
						continue
					n.draw_set_transform(Vector2(lx, ly), rot + spin, Vector2.ONE)
					K.ellipse(n, Vector2.ZERO, b.W * 0.014, b.W * 0.007, leaf)
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			K.label(n, b, D.label) })

	return d
