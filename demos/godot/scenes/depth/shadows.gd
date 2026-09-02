extends RefCounted
## SHADOWS & FOCUS — 14 pictures, ported from the web atlas (docs/depth.js).
## Two depth cues cost almost nothing. A SHADOW is a dark ellipse on the
## ground: tight and black when the thing touches, smaller-softer-fainter
## as it lifts, long when the sun is low — the shadow tells the eye where
## the floor is and how far above it a thing floats. OVERLAP is free: what
## is drawn last is nearest. And BLUR stands in for the eye itself — what
## is sharp is where you are looking; everything else is far from it.
## Fourteen pictures: cast, contact, ambient, soft, long, mirrored — and
## then the lens: bokeh, tilt-shift, vignette, ink, hard light, x-ray.
##
## Each def: letter, name, hint, dials (D), rhyme { name, hint, dials } and
## the callables init(b) / tick(b, dt) / press(b, pos) / draw(n, b). The
## rhyme's dials are merged over D on right-click — nothing else changes.
##
## Two canvas tricks have no per-call spelling in _draw(), so this file
## spells them by hand:
##   • ctx.clip() to a disc or a half-plane → the clipped shape is built as
##     a polygon (Sutherland–Hodgman against the rect edges, see _clip_half /
##     _rect_disc), or the occluder is simply drawn over the leak afterwards.
##   • globalCompositeOperation "multiply" / "screen" → translucent panes:
##     a darkened pane for multiply (overlaps darken naturally), a lightened
##     one for screen (overlaps brighten). Same lesson, approximate maths.

const K := preload("res://scenes/depth/kit.gd")

const TITLE := "Shadows & focus"
const BLURB := "where the light can't reach, and where the eye can't focus — the two cheapest depth cues there are"

## ---------------------------------------------------------------- helpers
## A small positioned label (the web's u.label with an x, y and alignment).
static func _txt(n: CanvasItem, txt: String, x: float, y: float, col: Color, align := "left") -> void:
	var f := ThemeDB.fallback_font
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var x0 := x if align == "left" else (x - w if align == "right" else x - w / 2.0)
	n.draw_string(f, Vector2(x0 + 0.7, y + 0.7), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.04, 0.03, 0.08, 0.35))
	n.draw_string(f, Vector2(x0, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, col)

## The bottom lesson in the card's own ink when it has one, the kit default otherwise.
static func _bottom(n: CanvasItem, b: Dictionary, D: Dictionary, col: Variant) -> void:
	if col == null:
		K.label(n, b, D.label)
	else:
		K.label(n, b, D.label, col)

## Cut a polygon by one axis-aligned half-plane (ax 0 = x, 1 = y). This is
## ctx.clip(rect) done by hand: keep what is on one side, add the crossing points.
static func _clip_half(pts: PackedVector2Array, ax: int, v: float, keep_below: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	var m := pts.size()
	for i in m:
		var a := pts[i]
		var bq := pts[(i + 1) % m]
		var av: float = a[ax]
		var bv: float = bq[ax]
		var a_in := (av <= v) if keep_below else (av >= v)
		var b_in := (bv <= v) if keep_below else (bv >= v)
		if a_in:
			out.append(a)
		if a_in != b_in:
			out.append(a + (bq - a) * ((v - av) / (bv - av)))
	return out

## rect ∩ disc as a polygon: a 40-gon disc clipped by the rect's four edges.
static func _rect_disc(rc: Rect2, c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for s in 40:
		var ang := TAU * float(s) / 40.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * r)
	pts = _clip_half(pts, 0, rc.position.x, false)
	pts = _clip_half(pts, 0, rc.end.x, true)
	pts = _clip_half(pts, 1, rc.position.y, false)
	pts = _clip_half(pts, 1, rc.end.y, true)
	return pts

## An ellipse as a 32-gon (so it can be clipped like any other polygon).
static func _ellipse_pts(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for s in 32:
		var ang := TAU * float(s) / 32.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts

## The part of segment a→bq that lies inside the disc (c, r), drawn as a line.
static func _seg_disc(n: CanvasItem, a: Vector2, bq: Vector2, c: Vector2, r: float, col: Color, w: float) -> void:
	var d := bq - a
	var f := a - c
	var qa := d.dot(d)
	var qb := 2.0 * f.dot(d)
	var qc := f.dot(f) - r * r
	var disc := qb * qb - 4.0 * qa * qc
	if disc <= 0.0 or qa == 0.0:
		return
	var sq := sqrt(disc)
	var t0 := clampf((-qb - sq) / (2.0 * qa), 0.0, 1.0)
	var t1 := clampf((-qb + sq) / (2.0 * qa), 0.0, 1.0)
	if t1 - t0 < 0.001:
		return
	K.line(n, a + d * t0, a + d * t1, col, w)

## Noir's blind: parallel stripes covering the card, rotated by D.angle about
## the centre (ctx.rotate → draw_set_transform). With cr > 0 every stripe is
## clipped to the disc (cc, cr) — the disc centre is moved INTO the rotated
## frame, since a rotation keeps a circle a circle.
static func _bars(n: CanvasItem, b: Dictionary, D: Dictionary, offset: float, a: float, cc: Vector2, cr: float) -> void:
	var W: float = b.W
	var H: float = b.H
	var gap: float = W * D.gap
	var bk: float = D.bar_k
	var angle: float = D.angle
	var nb := int(ceil((W + H) * 2.0 / gap)) + 2
	var col := K.alpha(D.light, a)
	var centre := Vector2(W / 2.0, H / 2.0)
	var cl := (cc - centre).rotated(-angle)
	n.draw_set_transform(centre, angle, Vector2.ONE)
	for i in range(-nb, nb):
		var rc := Rect2(-W - H, i * gap + offset, (W + H) * 2.0, gap * bk)
		if cr <= 0.0:
			n.draw_rect(rc, col)
		elif rc.end.y >= cl.y - cr and rc.position.y <= cl.y + cr:
			K.poly(n, _rect_disc(rc, cl, cr), col)
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Mirror's object: the thing and its reflection are the same drawing.
static func _mirror_obj(n: CanvasItem, b: Dictionary, D: Dictionary, x: float, FY: float) -> void:
	var W: float = b.W
	var H: float = b.H
	var t: float = b.t
	var s := W * 0.07
	var bob := sin(t * 1.3) * H * 0.02
	K.cube(n, Vector2(x, FY), s, D.block)
	K.sphere(n, Vector2(x, FY - s - s * 0.9 - bob - H * 0.03), s * 0.8, D.ball, -0.5, -0.6, 0.4, null, Color("8AD9F5"))

## Vignette's half-scene: sky, sun, two hill lines and an optional wash, inside [x0, x0 + w].
static func _vig_scene(n: CanvasItem, b: Dictionary, D: Dictionary, x0: float, w: float) -> void:
	var H: float = b.H
	var t: float = b.t
	var sky: Array = D.sky
	K.lin_rect(n, Rect2(x0, 0, w, H), [[0.0, sky[0]], [0.7, sky[1]], [1.0, sky[1]]])
	var sx := x0 + w * 0.5
	var sy := H * 0.3 + sin(t * 0.2) * H * 0.03
	K.soft(n, Vector2(sx, sy), w * 0.35, D.sun, 0.35)     # the glow stays inside the half, so no clip is needed
	K.dot(n, Vector2(sx, sy), w * 0.05, D.sun)
	K.poly(n, PackedVector2Array([Vector2(x0, H * 0.62), Vector2(x0 + w * 0.3, H * 0.5), Vector2(x0 + w * 0.55, H * 0.58),
		Vector2(x0 + w * 0.8, H * 0.48), Vector2(x0 + w, H * 0.56), Vector2(x0 + w, H), Vector2(x0, H)]), D.far)
	K.poly(n, PackedVector2Array([Vector2(x0, H * 0.8), Vector2(x0 + w * 0.25, H * 0.7), Vector2(x0 + w * 0.5, H * 0.78),
		Vector2(x0 + w * 0.75, H * 0.68), Vector2(x0 + w, H * 0.76), Vector2(x0 + w, H), Vector2(x0, H)]), D.hill)
	if D.tint != null:
		n.draw_rect(Rect2(x0, 0, w, H), D.tint)

## Xray's scene: a floor, a ball, a block and a light — the thing the panes sit over.
static func _xray_scene(n: CanvasItem, b: Dictionary, D: Dictionary) -> void:
	var W: float = b.W
	var H: float = b.H
	K.sky(n, b, D.sky)
	K.ground(n, b, H * 0.72, Color("B8B0A0"))
	K.sphere(n, Vector2(W * 0.3, H * 0.6), W * 0.08, Color("9BE28A"), -0.5, -0.6, 0.4)
	K.cube(n, Vector2(W * 0.62, H * 0.72), W * 0.08, Color("C9A0F5"))
	K.dot(n, Vector2(W * 0.8, H * 0.25), W * 0.05, Color("FFF3D0"))

## Xray's panes: three overlapping sheets, each drifting on its own sine.
## Canvas blends them with multiply / screen; _draw has no per-call blend
## mode, so multiply is a DARKENED translucent pane (overlaps darken more)
## and screen a LIGHTENED one (overlaps brighten). With lr > 0 each pane is
## clipped to the lens disc — the canvas ctx.clip(arc) done as geometry.
static func _panes(n: CanvasItem, b: Dictionary, D: Dictionary, a: float, lens: Vector2, lr: float) -> void:
	var W: float = b.W
	var H: float = b.H
	var t: float = b.t
	var panes: Array = D.panes
	var drift: float = D.drift
	var screen: bool = D.blend == "screen"
	var edge := K.alpha(D.ink, a * 0.8)
	for i in panes.size():
		var w := W * 0.42
		var h := H * 0.5
		var x := W * (0.15 + i * 0.18) + sin(t * drift + i * 2.0) * W * 0.06
		var y := H * (0.15 + i * 0.1) + cos(t * drift * 0.7 + i) * H * 0.05
		var col: Color = K.shade(panes[i], 0.3) if screen else K.shade(panes[i], -0.25)
		var rc := Rect2(x, y, w, h)
		if lr <= 0.0:
			n.draw_rect(rc, K.alpha(col, a))
			n.draw_rect(rc, edge, false, 1.0)
		else:
			K.poly(n, _rect_disc(rc, lens, lr), K.alpha(col, a))
			var q := [rc.position, Vector2(rc.end.x, rc.position.y), rc.end, Vector2(rc.position.x, rc.end.y)]
			for k in 4:
				_seg_disc(n, q[k], q[(k + 1) % 4], lens, lr, edge, 1.0)


static func defs() -> Array:
	var d: Array = []

	# ---- C · Contact -------------------------------------------------------
	d.append({ "letter": "C", "name": "Contact",
		"hint": "a ball on the ground with a tight dark shadow — press to lift it: as it floats up the shadow shrinks, softens and fades; height is written on the floor",
		"dials": { "sky": [Color("2A2F4A"), Color("4A5578")], "floor": Color("5A6080"), "ball": Color("F58A8A"),
			"shadow_a": 0.6, "drift": -0.25, "lift": 0.4,          # shadow darkness; drift of the target height per second (negative = sinks back); press lift
			"label": "touching = tight and dark; floating = smaller, softer, fainter — the shadow IS the height" },
		"rhyme": { "name": "Balloon contact", "hint": "the same ball filled with helium: the target height drifts UP instead of down, so it floats — and its shadow is half as dark; press pulls it toward the floor",
			"dials": { "ball": Color("F5C8E0"), "shadow_a": 0.3, "drift": 0.08,
				"label": "flip the sign of one dial and a ball becomes a balloon — the faint shadow says 'light, and high'" } },
		"init": func(b: Dictionary) -> void:
			b.h = 0.0; b.v = 0.0; b.target = 0.0,                   # height (fraction of H), velocity, where the spring wants to be
		"tick": func(b: Dictionary, dt: float) -> void:
			dt = minf(dt, 0.05)
			var drift: float = b.D.drift
			b.target = clampf(b.target + drift * dt, 0.0, 0.5)     # the target sinks (or rises, for a balloon)
			b.v += (b.target - b.h) * 60.0 * dt; b.v -= b.v * 4.0 * dt; b.h += b.v * dt   # a soft spring toward the target
			if b.h < 0.0:                                            # the floor is a floor
				b.h = 0.0; b.v = -b.v * 0.3,
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.target = clampf((b.H * 0.78 - pos.y) / b.H, 0.05, 0.5); b.v += b.D.lift,   # click above the ball = lift it there
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			K.sky(n, b, D.sky)
			var GY: float = b.H * 0.78
			var r: float = b.W * 0.085
			var x: float = b.W * 0.5
			var hp: float = b.h * b.H                                # height in pixels
			K.ground(n, b, GY, D.floor)
			var k := 1.0 / (1.0 + hp / (r * 0.9))                    # 1 on the ground → toward 0 with height
			var sa: float = D.shadow_a
			K.shadow(n, Vector2(x, GY), r * (0.5 + 0.7 * k) + hp * 0.25, r * (0.2 + 0.2 * k) + hp * 0.08, sa * 0.35 * k)   # the soft halo: grows and fades
			K.shadow(n, Vector2(x, GY), r * (0.35 + 0.75 * k), r * (0.14 + 0.22 * k), sa * k)                            # the tight core: shrinks and fades
			K.sphere(n, Vector2(x, GY - r - hp), r, D.ball, -0.4, -0.6, 0.4)
			_txt(n, "height: %.1f radii" % (hp / r), x, GY - r * 2.0 - hp - 8.0, K.alpha(K.INK, 0.7), "center")
			K.label(n, b, D.label) })

	# ---- J · Jump ----------------------------------------------------------
	d.append({ "letter": "J", "name": "Jump", "drag": true,
		"hint": "two balls hop along; only one has a shadow that stays on the ground and shrinks with altitude — cover it and the other ball just wobbles",
		"dials": { "sky": [Color("1E2A3A"), Color("3A5068")], "floor": Color("3A4A3A"), "grass": Color("5A8A4A"), "ball": Color("F5C169"), "ghost": Color("8AD9F5"),
			"hop": 0.24, "hops": 1.1, "speed": 0.2,                # hop height (of H), hops per second, path speed (of W per second)
			"label": "the ball's y says nothing on its own; the gap to its shadow says 'altitude'" },
		"rhyme": { "name": "Pixel jump", "hint": "the same two hoppers in an arcade palette — a navy sky, neon grass — hopping half again as high and half again as often",
			"dials": { "sky": [Color("000020"), Color("20206A")], "floor": Color("1A6A1A"), "grass": Color("40C040"), "ball": Color("FFE040"), "ghost": Color("40E0FF"),
				"hop": 0.38, "hops": 1.6,
				"label": "every platformer since 1985: the shadow disc under the hero is the whole sense of landing" } },
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.D.hop = 0.08 + (1.0 - pos.y / b.H) * 0.32,            # click higher = higher hops
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			K.sky(n, b, D.sky)
			var GY: float = b.H * 0.8
			var r: float = b.W * 0.05
			K.lin_rect(n, Rect2(0, GY, b.W, b.H - GY), [D.grass, D.floor])
			var hops: float = D.hops
			var speed: float = D.speed
			var hop: float = D.hop
			var ph := fmod(t * hops, 1.0)
			var hgt: float = sin(ph * PI) * hop * b.H                # one sine arch per hop
			var x1: float = fmod(t * speed, 1.0) * (b.W + 4.0 * r) - 2.0 * r          # the hero, crossing left → right
			var x2: float = fmod(t * speed + 0.5, 1.0) * (b.W + 4.0 * r) - 2.0 * r    # the ghost, half a lap behind
			var k: float = 1.0 / (1.0 + hgt / (r * 1.2))             # shadow factor: 1 touching → small when high
			K.shadow(n, Vector2(x1, GY), r * (0.4 + 0.9 * k), r * (0.15 + 0.25 * k), 0.55 * k)   # the shadow never leaves the ground
			K.sphere(n, Vector2(x1, GY - r - hgt), r, D.ball, -0.4, -0.6, 0.4)
			K.sphere(n, Vector2(x2, GY - r - hgt), r, D.ghost, -0.4, -0.6, 0.4)     # same arc, no shadow: jumping, or just higher up the wall?
			_txt(n, "which one is jumping?", b.W / 2.0, b.H * 0.14, K.alpha(K.INK, 0.7), "center")
			K.label(n, b, D.label) })

	# ---- L · Longshadow ----------------------------------------------------
	d.append({ "letter": "L", "name": "Longshadow", "drag": true,
		"hint": "a low sun: posts throw long parallelogram shadows across the floor, length = height / tan(elevation) — press moves the sun and the shadows swing",
		"dials": { "sky": [Color("3A2A5A"), Color("F5A15A")], "floor": Color("E8B87A"), "post": Color("4A3A6A"), "sun": Color("FFF3D0"),
			"elev": 0.32, "dir": 1, "tilt": 0.28, "posts": 5, "shadow_a": 0.35, "ink": null,   # sun elevation (radians), side (+1 = sun on the left), lean toward the viewer, count; ink null = the kit's pale text
			"label": "a low sun makes long shadows — their length is the time of day, their direction the compass" },
		"rhyme": { "name": "Noon", "hint": "the same posts under a high sun — elevation 72° instead of 18° — so the shadows are stubs at their feet; a bright, flat midday",
			"dials": { "sky": [Color("3A7AD8"), Color("CFE6F5")], "floor": Color("E8D8B8"), "sun": Color.WHITE, "elev": 1.25, "shadow_a": 0.45, "ink": Color("20183A"),
				"label": "same code, sun moved: short shadows read as noon, and the scene goes flat — length IS the hour" } },
		"init": func(b: Dictionary) -> void:
			var R := K.rng(31)
			var cnt: int = b.D.posts
			b.posts = []
			for j in cnt:
				b.posts.append({ "x": 0.12 + j * 0.76 / (cnt - 1) + (R.randf() - 0.5) * 0.06, "h": 0.16 + R.randf() * 0.2, "w": 0.035 + R.randf() * 0.02 }),
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.D.dir = 1 if pos.x < b.W / 2.0 else -1; b.D.elev = 0.15 + (1.0 - pos.y / b.H) * 1.2,   # click = put the sun there (side by x, height by y)
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W
			var H: float = b.H
			K.sky(n, b, D.sky)
			var HY := H * 0.42
			var GY := H * 0.7
			var elev: float = D.elev
			var dir: int = D.dir
			var tilt: float = D.tilt
			var el := clampf(elev + sin(t * 0.35) * 0.08, 0.12, 1.45)   # the sun drifts a little; never quite on the horizon (tan → 0)
			var stretch := 1.0 / tan(el)                                 # shadow length per unit of height
			var sx := W * 0.1 if dir > 0 else W * 0.9
			var sy := HY - sin(el) * H * 0.4
			K.soft(n, Vector2(sx, sy), W * 0.3, D.sun, 0.5)
			K.dot(n, Vector2(sx, sy), W * 0.035, D.sun)
			K.lin_rect(n, Rect2(0, HY, W, H - HY), [K.shade(D.floor, 0.1), K.shade(D.floor, -0.25)])
			var shadow_col := Color(20.0 / 255.0, 10.0 / 255.0, 40.0 / 255.0, D.shadow_a)
			for p in b.posts:                                            # shadows first — they lie on the floor
				var x0: float = p.x * W
				var w: float = p.w * W
				var L: float = p.h * H * stretch
				var dx := L * dir                                        # the shadow slides away from the sun and leans toward us
				var dy := L * tilt
				K.poly(n, PackedVector2Array([Vector2(x0, GY), Vector2(x0 + w, GY), Vector2(x0 + w + dx, GY + dy), Vector2(x0 + dx, GY + dy)]), shadow_col)
			for p in b.posts:
				var x0: float = p.x * W
				var w: float = p.w * W
				var h: float = p.h * H
				var lit := K.shade(D.post, 0.3)
				var dark := K.shade(D.post, -0.3)
				K.hlin_rect(n, Rect2(x0, GY - h, w, h), [lit, dark] if dir > 0 else [dark, lit])   # lit on the sun's side
			var ink: Color = D.ink if D.ink != null else K.INK
			_txt(n, "elevation %d°: shadow = %.1f× the post's height" % [roundi(el * 57.3), stretch], W / 2.0, H * 0.1, K.alpha(ink, 0.7), "center")
			_bottom(n, b, D, K.alpha(ink, 0.7) if D.ink != null else null) })

	# ---- A · Ambient -------------------------------------------------------
	d.append({ "letter": "A", "name": "Ambient",
		"hint": "ambient occlusion: cubes with no directional light at all — only the crevices and the ground contact darkened by soft blobs — and they still read as solid",
		"dials": { "sky": [Color("DCD8E8"), Color("B8B4CC")], "floor": Color("A8A4BC"), "cube": Color("C8C4DC"),   # near-flat, no sun anywhere
			"face_diff": 0.05, "ao": true, "ao_a": 0.32, "ao_r": 0.85, "ao_col": Color("20183A"),   # how different the faces are (0 = identical), AO on/off, its darkness, reach (× cube size) and colour
			"label": "no sun, no shading — just dark where things meet, and the eye supplies the solid" },
		"rhyme": { "name": "Marshmallow blocks", "hint": "the same cubes in pastel pink and cream with the AO half as dark and half again as wide — squishy, sugar-soft blocks",
			"dials": { "sky": [Color("F8E8F0"), Color("F0D8E8")], "floor": Color("E8C8D8"), "cube": Color("F8E0EA"),
				"ao_a": 0.18, "ao_r": 1.25, "ao_col": Color("8A4A6A"),
				"label": "wider, fainter occlusion reads as a softer material — the AO dial is also a hardness dial" } },
		"init": func(b: Dictionary) -> void:
			b.cells = [[0, 0, 0], [1, 0, 0], [2, 0, 0], [0, 1, 0], [1, 1, 0], [2, 1, 0], [0, 2, 0], [1, 2, 0], [2, 2, 0], [1, 1, 1], [2, 0, 1], [0, 2, 1]]
			b.cells.sort_custom(func(p, q): return (p[0] + p[1] + p[2] * 0.1) < (q[0] + q[1] + q[2] * 0.1)),   # far first, then low first
		"press": func(b: Dictionary, _pos: Vector2) -> void:
			b.D.ao = not b.D.ao,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			K.sky(n, b, D.sky)
			var s: float = b.W * 0.085
			var cx: float = b.W * 0.5
			var cy: float = b.H * 0.7
			K.ground(n, b, b.H * 0.55, D.floor)
			var c: Color = D.cube
			var fd: float = D.face_diff
			var ao_a: float = D.ao_a
			var ao_r: float = D.ao_r
			var ao_col: Color = D.ao_col
			for q in b.cells:
				var lift: float = (0.5 + 0.5 * sin(t * 0.9)) * 0.9 if (q[2] == 1 and q[0] == 1) else 0.0   # the middle top cube hovers a little
				var p := K.iso(q[0] - 1, q[1] - 1, q[2] + lift, s)
				var x := cx + p.x
				var y := cy + p.y
				var a := ao_a / (1.0 + lift * 3.0)                                # AO fades as the cube leaves its neighbours
				if D.ao:                                                         # the crevices: base point, base corners, and the wall it meets
					K.soft(n, Vector2(x, y), s * ao_r, ao_col, a)
					K.soft(n, Vector2(x - s * 0.866, y - s * 0.5), s * ao_r * 0.7, ao_col, a * 0.7)
					K.soft(n, Vector2(x + s * 0.866, y - s * 0.5), s * ao_r * 0.7, ao_col, a * 0.7)
				K.cube(n, Vector2(x, y), s, c, -1.0, K.shade(c, fd), c, K.shade(c, -fd))
			_txt(n, "AO on — press to switch it off" if D.ao else "AO off — press to switch it on", b.W / 2.0, b.H * 0.1, K.alpha(ao_col, 0.6), "center")
			K.label(n, b, D.label, K.alpha(ao_col, 0.7)) })

	# ---- U · Umbra ---------------------------------------------------------
	d.append({ "letter": "U", "name": "Umbra", "drag": true,
		"hint": "an area light: the shadow has a dark core (umbra) and a soft rim (penumbra) that widens the wider and nearer the light — press moves the light",
		"dials": { "sky": [Color("1A1E2E"), Color("2A3048")], "floor": Color("3A4058"), "ball": Color("8AD9F5"), "lamp": Color("FFF3D0"),
			"light_w": 0.3, "light_x": 0.3, "light_y": 0.12, "steps": 9, "shadow_a": 0.6, "glow_k": 1.0,   # light width (of W), position, how many ellipses build the gradient, core darkness, glow radius (× light width)
			"label": "a point light makes a hard edge; a wide one blurs it — the blur is the light's size" },
		"rhyme": { "name": "Spotlight", "hint": "the same lamp shrunk to a point — a fifteenth of the width — so the shadow has no penumbra at all: one hard edge on a theatre floor",
			"dials": { "sky": [Color("1A0A10"), Color("2A1018")], "floor": Color("3A1A22"), "ball": Color("F5C169"), "lamp": Color.WHITE,
				"light_w": 0.02, "steps": 3, "glow_k": 6.0,
				"label": "a tiny light is all umbra: the shadow's edge is as sharp as the ball's — stage lighting in one dial" } },
		"init": func(b: Dictionary) -> void:
			b.lamp = null,                                              # pressed light position (null = the slow sway)
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.lamp = Vector2(pos.x, minf(pos.y, b.H * 0.55)),          # click = hang the lamp there
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W
			var H: float = b.H
			K.sky(n, b, D.sky)
			var GY := H * 0.8
			var r := W * 0.08
			var ox := W * 0.55
			var oy := GY - r                                            # the floor, the ball
			var light_x: float = D.light_x
			var light_y: float = D.light_y
			var LX: float = b.lamp.x if b.lamp != null else W * (light_x + 0.12 * sin(t * 0.5))
			var LY: float = b.lamp.y if b.lamp != null else H * light_y
			var LW: float = W * D.light_w
			K.ground(n, b, GY, D.floor)
			var drop := GY - oy                                         # ball-to-floor
			var rise := maxf(20.0, oy - LY)                             # light-to-ball
			var sx := ox + (ox - LX) * drop / rise                      # where the light-through-the-ball-centre hits the floor
			var pen := LW * drop / rise                                 # penumbra width: a wider or nearer light blurs more
			var core := r * (1.0 + drop / rise)                         # the umbra's half-width
			var steps: int = D.steps
			var sa: float = D.shadow_a
			var col := Color(0.0, 0.0, 10.0 / 255.0, sa / steps * 1.4)
			for i in range(steps - 1, -1, -1):                          # big faint ellipses first, then smaller darker ones on top
				var k := float(i) / (steps - 1)
				var rx := maxf(1.0, core - pen * 0.5 + pen * k)
				var ry := rx * 0.32
				# ctx.clip(floor rect): keep only the half of each ellipse that lies on the floor
				K.poly(n, _clip_half(_ellipse_pts(Vector2(sx, GY + 1.0), rx, ry), 1, GY, false), col)
			var dx := LX - ox
			var dy := LY - oy
			var len := sqrt(dx * dx + dy * dy)
			if len == 0.0: len = 1.0
			K.sphere(n, Vector2(ox, oy), r, D.ball, dx / len, dy / len, 0.4, null, D.lamp)
			var glow_k: float = D.glow_k
			K.soft(n, Vector2(LX, LY), LW * glow_k, D.lamp, 0.25)      # the light itself: a glowing bar
			n.draw_rect(Rect2(LX - LW / 2.0, LY - 3.0, LW, 6.0), D.lamp)
			K.label(n, b, D.label) })

	# ---- O · Occlusion -----------------------------------------------------
	d.append({ "letter": "O", "name": "Occlusion",
		"hint": "five identical flat discs crossing paths: what is drawn last is nearest, and each is scaled by its z — overlap alone sorts them; press reverses the sort",
		"dials": { "sky": [Color("F0ECE4"), Color("D8D2C4")], "disc": Color("E86A5A"), "edge": Color("3A2A2A"), "n": 5, "speed": 0.6, "shape": "disc", "flip": false,
			"ink": Color("3A2A2A"),
			"label": "no shading, no shadow: draw order + size are already a third axis" },
		"rhyme": { "name": "Card shuffle", "hint": "the same five things as playing cards on green felt, shuffling at nearly four times the speed — overlap still says who is on top",
			"dials": { "sky": [Color("1A5A3A"), Color("0E3A26")], "disc": Color("F5F0E8"), "edge": Color("B02030"), "speed": 2.2, "shape": "rect", "ink": Color("F5F0E8"),
				"label": "a card game is a z-sort you can see — the deck is the painter's algorithm made of paper" } },
		"init": func(b: Dictionary) -> void:
			var R := K.rng(17)
			var cnt: int = b.D.n
			b.items = []
			b.order = []
			for j in cnt:
				b.items.append({ "ph": float(j) / cnt * TAU, "ry": 0.28 + R.randf() * 0.14, "sp": 0.7 + R.randf() * 0.6, "x": 0.0, "y": 0.0, "z": 0.0 })
				b.order.append(j),
		"press": func(b: Dictionary, _pos: Vector2) -> void:
			b.D.flip = not b.D.flip,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W
			var H: float = b.H
			K.sky(n, b, D.sky)
			var speed: float = D.speed
			var items: Array = b.items
			for it in items:                                            # an orbit seen from the side: z is the depth along it
				var a: float = t * speed * it.sp + it.ph
				it.z = 0.5 + 0.5 * sin(a)                                # 0 far … 1 near
				it.x = W * 0.5 + cos(a) * W * 0.3
				it.y = H * 0.48 + (it.z - 0.5) * H * it.ry
			var flip: bool = D.flip
			(b.order as Array).sort_custom(func(p, q): return (items[q].z < items[p].z) if flip else (items[p].z < items[q].z))   # painter's order: far first
			var disc: Color = D.disc
			var edge: Color = D.edge
			for o in b.order:
				var it: Dictionary = items[o]
				var r: float = W * (0.05 + it.z * 0.07)                  # near = bigger
				if D.shape == "disc":
					n.draw_circle(Vector2(it.x, it.y), r, disc)
					n.draw_arc(Vector2(it.x, it.y), r, 0.0, TAU, 40, edge, 1.5, true)
				else:
					var rc := Rect2(it.x - r * 0.8, it.y - r * 1.1, r * 1.6, r * 2.2)
					n.draw_rect(rc, disc)
					n.draw_rect(rc, edge, false, 1.5)
			var ink: Color = D.ink
			_txt(n, "sorted near → far: the small ones cover the big ones and depth breaks" if flip else "sorted far → near: the last drawn wins the overlap",
				W / 2.0, H * 0.1, K.alpha(ink, 0.6), "center")
			K.label(n, b, D.label, K.alpha(ink, 0.7)) })

	# ---- G · Ground --------------------------------------------------------
	d.append({ "letter": "G", "name": "Ground", "drag": true,
		"hint": "a perspective floor: rows at horizon + p², columns converging on one vanishing point, fog toward the horizon; a ball rolls away and shrinks — press moves the vanishing point",
		"dials": { "sky": [Color("2A3A5A"), Color("8AA0C8")], "floor": Color("3A4A5A"), "lines": Color("C8D8F0"), "ball": Color("F58A8A"),
			"rows": 12, "cols": 9, "fog_k": 0.9, "speed": 0.3,       # grid density, how much the far floor fades into the air, the ball's speed
			"label": "rows bunch as p², columns meet at one point, colour fades into the air — three cues, one floor" },
		"rhyme": { "name": "Synthwave grid", "hint": "the same floor in hot pink on black with a cyan ball — 16 rows, half the fog, so the grid stays crisp all the way to the horizon",
			"dials": { "sky": [Color("0A0018"), Color("2A0040")], "floor": Color.BLACK, "lines": Color("FF2A9A"), "ball": Color("40E0FF"),
				"rows": 16, "fog_k": 0.5,
				"label": "less fog, more rows: the same p² floor turns from a foggy street into a poster — the maths is the genre's" } },
		"init": func(b: Dictionary) -> void:
			b.vx = b.W * 0.5,
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.vx = pos.x,                                               # click = move the vanishing point
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W
			var H: float = b.H
			var vx: float = b.vx
			K.sky(n, b, D.sky)
			var HY := H * 0.42
			var sky: Array = D.sky
			var air: Color = sky[1]
			var fog_k: float = D.fog_k
			K.lin_rect(n, Rect2(0, HY, W, H - HY), [K.mix(D.floor, air, fog_k), D.floor])   # the floor is a fog gradient
			var rows: int = D.rows
			var cols: int = D.cols
			var lines: Color = D.lines
			for i in range(1, rows + 1):
				var p := float(i) / rows
				var y := HY + p * p * (H - HY)                           # p² bunches the rows toward the horizon
				K.line(n, Vector2(0, y), Vector2(W, y), K.alpha(lines, 0.1 + p * 0.5), 1.0)
			for j in range(0, cols + 1):                                # columns: every one aims at the vanishing point
				var bx := vx + (float(j) / cols - 0.5) * W * 2.4
				# the canvas stroked these with a vertical gradient; a two-colour polyline is the same thing
				n.draw_polyline_colors(PackedVector2Array([Vector2(vx, HY), Vector2(bx, H)]),
					PackedColorArray([K.alpha(lines, 0.0), K.alpha(lines, 0.55)]), 1.0, true)
			var speed: float = D.speed
			var q := 0.5 + 0.5 * sin(t * speed * TAU)                   # the ball rolls away and back: q 0 = horizon, 1 = here
			var by := HY + q * q * (H - HY)
			var bx2 := lerpf(vx, W * 0.62, q)
			var r := W * 0.02 + q * q * W * 0.07                        # size follows the same p² rule
			K.shadow(n, Vector2(bx2, by), r * 1.15, r * 0.35, 0.5 * (0.3 + q * 0.7))   # the shadow pins the ball to a row
			K.sphere(n, Vector2(bx2, by - r), r, K.fog(D.ball, (1.0 - q) * fog_k, air), -0.4, -0.6, 0.35)
			K.label(n, b, D.label) })

	# ---- M · Mirror --------------------------------------------------------
	d.append({ "letter": "M", "name": "Mirror", "drag": true,
		"hint": "a floor reflection: the object drawn again upside-down under the floor line, darker and fading with distance from it, with a faint ripple — press moves the object",
		"dials": { "sky": [Color("1A1030"), Color("3A2A5A")], "floor": Color("141020"), "ball": Color("C9A0F5"), "block": Color("5A7AB8"),
			"ref_a": 0.55, "fade": 0.8, "ripple": 2.0, "ink": null,     # reflection strength, how fast it fades (of the pool depth), ripple amplitude in px
			"label": "a reflection is the picture flipped, dimmed, and faded out — the fade says 'this floor is a surface'" },
		"rhyme": { "name": "Ice reflection", "hint": "the same object over a frozen lake — pale blues, a brighter reflection that dies quicker, a fifth of the ripple: glassy and still",
			"dials": { "sky": [Color("C8DCF0"), Color("E8F0F8")], "floor": Color("A8C8E0"), "ball": Color("5A8AC8"), "block": Color("7AA0C8"),
				"ref_a": 0.75, "fade": 0.45, "ripple": 0.4, "ink": Color("1A2A4A"),
				"label": "a sharper, brighter, shorter reflection reads as ice, not water — three dials say what the floor is made of" } },
		"init": func(b: Dictionary) -> void:
			b.ox = b.W * 0.5,
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.ox = pos.x,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W
			var H: float = b.H
			var ox: float = b.ox
			K.sky(n, b, D.sky)
			var FY := H * 0.64
			var floor_c: Color = D.floor
			var ref_a: float = D.ref_a
			var fade: float = D.fade
			var ripple: float = D.ripple
			K.ground(n, b, FY, floor_c)
			# ctx.translate(ripple, 2·FY) + scale(1, −1): flip about the floor line, sliding a hair sideways
			n.draw_set_transform(Vector2(sin(t * 2.1) * ripple, FY * 2.0), 0.0, Vector2(1.0, -1.0))
			_mirror_obj(n, b, D, ox, FY)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			# globalAlpha = ref_a over a plain floor ≡ the opaque reflection with floor at (1 − ref_a) laid over it
			n.draw_rect(Rect2(0, FY, W, H - FY), K.alpha(floor_c, 1.0 - ref_a))
			# the mask: the reflection dies with distance from the floor (the gradient's end colour continues to the bottom)
			K.lin_rect(n, Rect2(0, FY, W, (H - FY) * fade), [K.alpha(floor_c, 0.25), floor_c])
			n.draw_rect(Rect2(0, FY + (H - FY) * fade, W, (H - FY) * (1.0 - fade)), floor_c)
			for i in 4:                                                 # a few ripple lines
				var y := FY + 6.0 + i * 11.0 + sin(t + i) * 2.0
				K.line(n, Vector2(0, y), Vector2(W, y), K.alpha(D.ball, 0.06 + 0.03 * sin(t * 3.0 + i)), 1.0)
			_mirror_obj(n, b, D, ox, FY)
			_bottom(n, b, D, K.alpha(D.ink, 0.7) if D.ink != null else null) })

	# ---- B · Bokeh ---------------------------------------------------------
	d.append({ "letter": "B", "name": "Bokeh", "drag": true,
		"hint": "depth of field: lights at many depths; the ones on the focus plane are small and sharp, the ones far from it big, soft and dim — the plane slides; press sets it by y",
		"dials": { "sky": [Color("0A0A18"), Color("1A1830")], "hues": [40.0, 200.0, 320.0], "n": 40, "seed": 5,   # palette of the lights, how many
			"blur_k": 4.0, "dim_k": 6.0, "sweep": 0.45,                 # how fast size grows / brightness drops with distance from focus; sweep speed of the plane
			"label": "sharp = where the eye is looking; everything else grows into a soft disc — blur is a distance" },
		"rhyme": { "name": "City bokeh", "hint": "the same lights at night, seventy of them in amber and cyan — street lamps and shop signs — with the focus sweeping half as fast",
			"dials": { "sky": [Color("050510"), Color("0E0E1E")], "hues": [35.0, 195.0], "n": 70, "sweep": 0.12,
				"label": "two hues and more of them: warm near, cool far is the city's own colour temperature — the blur rule is unchanged" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(int(D.seed))
			var hues: Array = D.hues
			b.lights = []
			for j in int(D.n):
				var z := R.randf()                                        # 0 far (high on the card) … 1 near (low)
				b.lights.append({ "z": z, "x": R.randf() * b.W, "y": b.H * (0.12 + (1.0 - z) * 0.62) + (R.randf() - 0.5) * b.H * 0.08,
					"hue": float(hues[j % hues.size()]) + R.randf() * 25.0, "ph": R.randf() * 9.0 })
			b.lights.sort_custom(func(p, q): return p.z < q.z)          # far first
			b.focus = -1.0,
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.focus = clampf(1.0 - (pos.y / b.H - 0.12) / 0.62, 0.0, 1.0),   # click = focus on that row
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W
			var H: float = b.H
			K.sky(n, b, D.sky)
			var sweep: float = D.sweep
			var focus: float = b.focus
			var f := focus if focus >= 0.0 else 0.5 + 0.45 * sin(t * sweep * TAU)   # the focus plane, 0 far … 1 near
			var fy := H * (0.12 + (1.0 - f) * 0.62)
			K.line(n, Vector2(0, fy), Vector2(W, fy), K.alpha(K.INK, 0.12), 1.0)   # where the plane cuts the picture
			var blur_k: float = D.blur_k
			var dim_k: float = D.dim_k
			for L in b.lights:
				var z: float = L.z
				var dd := absf(z - f)                                    # distance from focus
				var tw: float = 0.8 + 0.2 * sin(t * 2.0 + L.ph)
				var r := W * (0.008 + z * 0.012) * (1.0 + dd * blur_k)   # out of focus = bigger…
				var a := tw / (1.0 + dd * dim_k)                         # …and fainter
				var c := K.hsl(L.hue, 0.8, 0.65)
				var p := Vector2(L.x, L.y)
				if dd < 0.06:                                            # sharp: a hard disc with a little glow
					K.dot(n, p, r, K.alpha(c, a))
					K.soft(n, p, r * 2.5, c, a * 0.4)
				else:                                                    # soft: only the glow, wider
					K.soft(n, p, r, c, a)
			_txt(n, "focus " + ("far" if f < 0.33 else ("middle" if f < 0.66 else "near")), W - 8.0, fy - 4.0, K.alpha(K.INK, 0.5), "right")
			K.label(n, b, D.label) })

	# ---- T · Tiltshift -----------------------------------------------------
	d.append({ "letter": "T", "name": "Tiltshift", "drag": true,
		"hint": "a miniature: rows of little cubes, one sharp band across the middle and rows above and below drawn thrice with offsets — the fake blur makes a town look toy-sized",
		"dials": { "sky": [Color("8AB8E8"), Color("D8E8F5")], "floor": Color("7A9A6A"),
			"cols": [Color("F58A8A"), Color("F5C169"), Color("8AD9F5"), Color("C9A0F5"), Color("9BE28A"), Color("F5A15A")],
			"rows": 5, "per_row": 7, "blur": 14.0, "band": 0.5, "ink": null,   # rows of houses, houses per row, max ghost offset (px at 250 wide), where the sharp band sits (0 top … 1 bottom)
			"label": "a real camera can only blur the near and far like this on a tiny scene — so the eye reads 'tiny'" },
		"rhyme": { "name": "Toy town", "hint": "the same miniature in candy colours with seven rows instead of five and a stronger smear — a sweet-shop diorama",
			"dials": { "sky": [Color("F5C8E0"), Color("FFF0F5")], "floor": Color("A8E0C8"),
				"cols": [Color("FF6FA0"), Color("FFD060"), Color("60D0FF"), Color("C080FF"), Color("80F090"), Color("FF9060")],
				"rows": 7, "blur": 20.0, "ink": Color("4A2A4A"),
				"label": "more rows and more smear: the thinner the sharp slice, the smaller the town feels" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(23)
			var cols: Array = D.cols
			b.town = []
			for r in int(D.rows):
				for c in int(D.per_row):
					b.town.append({ "r": r, "c": c, "h": 0.6 + R.randf() * 1.2,
						"col": cols[mini(int(R.randf() * cols.size()), cols.size() - 1)], "dx": (R.randf() - 0.5) * 0.4 }),
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.D.band = clampf((pos.y / b.H - 0.3) / 0.6, 0.0, 1.0),
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W
			var H: float = b.H
			K.sky(n, b, D.sky)
			var HY := H * 0.3
			K.lin_rect(n, Rect2(0, HY, W, H - HY), [K.shade(D.floor, 0.25), K.shade(D.floor, -0.15)])
			var band: float = D.band
			var rows: int = D.rows
			var per_row: int = D.per_row
			var blur_max: float = D.blur
			var bandY := H * (0.3 + band * 0.6)
			for hs in b.town:
				var p: float = (hs.r + 1.0) / rows                       # p: row depth, 1 = nearest
				var y := HY + p * p * (H - HY) * 0.9 + H * 0.03
				var s := W * (0.018 + p * 0.03)
				var x: float = W * ((hs.c + 0.5 + hs.dx) / per_row) * (0.7 + p * 0.4) + W * (0.15 - p * 0.2) + sin(t * 0.3) * 4.0 * p   # near rows spread wider
				var blur := absf(y - bandY) / H * blur_max * (W / 250.0)   # ghost offset grows away from the sharp band
				var passes := 1 if blur < 0.7 else 3
				var col: Color = K.alpha(hs.col, 1.0 if passes == 1 else 0.45)   # globalAlpha, carried on the colour (the kit's shades keep alpha)
				var hh: float = s * hs.h
				for k in passes:                                         # the same house three times = a smear
					K.cube(n, Vector2(x + (k - 1) * blur, y), s, col, hh)
			var ink: Color = D.ink if D.ink != null else K.INK
			K.line(n, Vector2(0, bandY), Vector2(W, bandY), K.alpha(ink, 0.15 if D.ink == null else 0.2), 1.0)
			_txt(n, "sharp band — press to move it", W - 8.0, bandY - 4.0, K.alpha(ink, 0.5), "right")
			_bottom(n, b, D, K.alpha(ink, 0.7) if D.ink != null else null) })

	# ---- V · Vignette ------------------------------------------------------
	d.append({ "letter": "V", "name": "Vignette", "drag": true,
		"hint": "the same view twice: plain on the left, on the right a radial darkening at the rim — the dark edges push the eye to the centre and the centre reads as far",
		"dials": { "sky": [Color("3A5A9A"), Color("D8C8A8")], "hill": Color("4A6A4A"), "far": Color("8A9AB8"), "sun": Color("FFF3D0"), "tint": null,   # tint: an overall colour wash (null = none)
			"inner": 0.35, "dark": 0.8,                                 # where the darkening starts (of the half-radius), how black the rim gets
			"label": "one radial gradient over everything: the rim recedes, the centre comes forward — a lens, not a light" },
		"rhyme": { "name": "Old photo", "hint": "the same two views in sepia with a brown wash and a tighter, blacker rim — the vignette an old lens gave for free",
			"dials": { "sky": [Color("5A4A3A"), Color("D8C8A8")], "hill": Color("6A5A3A"), "far": Color("9A8A6A"), "sun": Color("F5E6C0"),
				"tint": Color(120.0 / 255.0, 80.0 / 255.0, 40.0 / 255.0, 0.25), "inner": 0.2, "dark": 0.92,
				"label": "a wash plus a heavier rim: the same gradient now says 'long ago' as well as 'look here'" } },
		"init": func(b: Dictionary) -> void:
			b.vc = Vector2(0.5, 0.5),                                   # vignette centre, as fractions of the half
		"press": func(b: Dictionary, pos: Vector2) -> void:
			if pos.x > b.W / 2.0:                                       # click on the right half = move the clear spot
				b.vc = Vector2((pos.x - b.W / 2.0) / (b.W / 2.0), pos.y / b.H),
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var W: float = b.W
			var H: float = b.H
			var vc: Vector2 = b.vc
			var hw := W / 2.0
			var inner: float = D.inner
			var dark: float = D.dark
			_vig_scene(n, b, D, hw, hw)                                 # the right half first…
			var cx := hw + vc.x * hw
			var cy := vc.y * H
			var rr := maxf(hw, H) * 0.85
			# the canvas radial keeps its last colour beyond rr, so the fan is drawn at twice the radius with the
			# stops halved; it spills onto the left half, and the plain scene is painted over the spill next
			var clear := Color(10.0 / 255.0, 5.0 / 255.0, 20.0 / 255.0, 0.0)
			var rim := Color(10.0 / 255.0, 5.0 / 255.0, 20.0 / 255.0, dark)
			K.radial(n, Vector2(cx, cy), rr * 2.0, [[0.0, clear], [inner * 0.5, clear], [0.5, rim], [1.0, rim]])
			_vig_scene(n, b, D, 0.0, hw)                                # …then the plain half covers the leak (ctx.clip by occluder)
			K.line(n, Vector2(hw, 0), Vector2(hw, H), K.alpha(K.INK, 0.5), 1.0)
			_txt(n, "plain", 8.0, 14.0, K.alpha(K.INK, 0.6))
			_txt(n, "vignette", W - 8.0, 14.0, K.alpha(K.INK, 0.6), "right")
			K.label(n, b, D.label) })

	# ---- I · Inkwash -------------------------------------------------------
	d.append({ "letter": "I", "name": "Inkwash",
		"hint": "a sumi-e landscape in one ink: five silhouette layers at rising alpha — far faint, near dark — and a few brush strokes; no colour at all, just value as distance",
		"dials": { "paper": Color("F2EDE2"), "ink": Color("1E2230"), "layers": 5, "fill": true,   # paper, the one ink, how many ridges, painted (true) or outlined (false)
			"far_a": 0.12, "near_a": 0.9, "drift": 0.06,                # alpha of the farthest / nearest ridge, parallax speed
			"hues": [Color("1E2230"), Color("2A1A3A"), Color("1A3A2A"), Color("3A1E1A")],   # inks the press cycles through
			"label": "one ink, five alphas — the farthest ridge is mostly paper. That is atmospheric perspective with nothing else" },
		"rhyme": { "name": "Blueprint", "hint": "the same ridges as white outlines on drafting blue — value inverted: the near ridge is the brightest line, the far one nearly vanishes into the paper",
			"dials": { "paper": Color("1A3A8A"), "ink": Color("E8F0FF"), "fill": false, "far_a": 0.2, "near_a": 1.0,
				"hues": [Color("E8F0FF"), Color("8AD9F5"), Color("F5F0C0"), Color("FFB0C0")],
				"label": "swap paper and ink and the rule still holds: far = closer to the paper's value, whichever way is 'light'" } },
		"init": func(b: Dictionary) -> void:
			var R := K.rng(41)
			b.ridges = []
			b.hue = 0
			for j in int(b.D.layers):
				b.ridges.append({ "y": 0.32 + j * 0.11, "amp": 0.05 + R.randf() * 0.05, "f": 1.2 + R.randf() * 2.0, "ph": R.randf() * 9.0 }),
		"press": func(b: Dictionary, _pos: Vector2) -> void:
			var hues: Array = b.D.hues
			b.hue = (b.hue + 1) % hues.size(); b.D.ink = hues[b.hue],   # click = another ink
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W
			var H: float = b.H
			var paper: Color = D.paper
			var ink: Color = D.ink
			var far_a: float = D.far_a
			var near_a: float = D.near_a
			var drift: float = D.drift
			K.sky(n, b, [paper, K.shade(paper, -0.06)])
			var cnt: int = b.ridges.size()
			for j in cnt:
				var g: Dictionary = b.ridges[j]
				var k := float(j) / (cnt - 1)
				var a := lerpf(far_a, near_a, k * k)                     # alpha climbs toward the viewer
				var shift := t * drift * (0.3 + k) * W                   # near ridges slide faster: parallax for free
				var pts := PackedVector2Array([Vector2(0, H)])
				var x := 0.0
				while x <= W:
					pts.append(Vector2(x, H * (g.y + sin((x + shift) / W * g.f * TAU + g.ph) * g.amp + sin((x + shift) * 0.05 + g.ph) * 0.012)))
					x += 5.0
				pts.append(Vector2(W, H))
				if D.fill:
					K.poly(n, pts, K.alpha(ink, a))
				else:
					n.draw_polyline(pts, K.alpha(ink, a), 1.5, true)
			for s in 4:                                                 # reeds: a stroke that thins as it rises
				var bx := W * (0.12 + s * 0.09)
				var sway := sin(t * 1.2 + s) * 4.0
				for seg in 5:
					K.line(n, Vector2(bx + sway * seg / 5.0 * 0.4, H * (0.95 - seg * 0.05)),
						Vector2(bx + sway * (seg + 1) / 5.0 * 0.4 + 2.0, H * (0.9 - seg * 0.05)), K.alpha(ink, 0.85), 3.5 - seg * 0.6)
			K.label(n, b, D.label, K.alpha(ink, 0.65)) })

	# ---- N · Noir ----------------------------------------------------------
	d.append({ "letter": "N", "name": "Noir", "drag": true,
		"hint": "hard light through a blind: bright bars across a dark room and a sphere — the bars shift where they cross the ball, and that shift is its roundness; press moves the light angle",
		"dials": { "room": Color("0C0A14"), "wall": Color("1A1622"), "light": Color("F5E6C0"), "ball": Color("3A3A4A"),
			"angle": -0.55, "gap": 0.09, "bar_k": 0.45, "speed": 0.06, "bend": 0.4,   # bar angle (radians; 0 = horizontal, π/2 = vertical), spacing (of W), lit share of each gap, drift, how far the bars jump on the ball (× radius)
			"label": "stripes that agree are a wall; stripes that jump are a thing in front of it — hard light draws form by breaking pattern" },
		"rhyme": { "name": "Prison bars", "hint": "the same hard light standing up: vertical bars, wider apart and thinner, in a cold blue-grey — the ball still bends them",
			"dials": { "room": Color("0A0E18"), "wall": Color("1A2230"), "light": Color("C8D8F0"), "ball": Color("4A4A5A"),
				"angle": PI / 2.0, "gap": 0.14, "bar_k": 0.3,
				"label": "turn the angle a quarter and the blind becomes a cell — the ball's roundness survives any stripe direction" } },
		"init": func(b: Dictionary) -> void:
			b.angle0 = b.D.angle,                                       # the press swings the light around this resting angle
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.D.angle = b.angle0 + (pos.x / b.W - 0.5) * 1.0,          # click left or right = swing the light half a radian either way
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W
			var H: float = b.H
			var angle: float = D.angle
			var gap: float = D.gap
			var speed: float = D.speed
			var bend: float = D.bend
			K.sky(n, b, [D.room, D.wall])
			var GY := H * 0.78
			var r := W * 0.13
			var ox := W * 0.5
			var oy := GY - r
			var off := fmod(t * speed * W, W * gap)                     # the sun crawls: bars drift across the room
			K.ground(n, b, GY, K.shade(D.wall, -0.3))
			_bars(n, b, D, off, 0.18, Vector2.ZERO, 0.0)                # on the wall and floor: dim, flat
			K.shadow(n, Vector2(ox, GY), r * 1.2, r * 0.3, 0.8)
			K.sphere(n, Vector2(ox, oy), r, D.ball, sin(angle), -0.7, 0.15, Color("08080E"))
			_bars(n, b, D, off + r * bend, 0.5, Vector2(ox, oy), r)      # on the ball: the same bars, brighter, shifted toward the light, cut to the disc
			# and they dim at the ball's edge, where it turns away (the radial is a disc already — no clip needed)
			K.radial(n, Vector2(ox, oy), r, [[0.0, Color(0, 0, 0, 0)], [0.5, Color(0, 0, 0, 0)], [1.0, Color(0, 0, 0, 0.6)]], Vector2(-r * 0.3, -r * 0.4))
			K.label(n, b, D.label) })

	# ---- X · Xray ----------------------------------------------------------
	d.append({ "letter": "X", "name": "Xray", "drag": true,
		"hint": "three translucent panes over a scene: where they overlap they darken more, so the stacking order shows — a lens follows the pointer and shows the panes sharp inside, faint outside",
		"dials": { "sky": [Color("F0ECE4"), Color("D8D2C4")], "panes": [Color("F58A8A"), Color("8AD9F5"), Color("F5C169")], "ink": Color("3A2A2A"),
			"alpha": 0.55, "outside": 0.3, "blend": "multiply", "lens_r": 0.28, "drift": 0.8,   # pane alpha inside the lens, alpha outside, how panes combine, lens radius (of W), pane drift speed
			"label": "where two panes cross the colour multiplies: darker means more layers — depth counted in sheets" },
		"rhyme": { "name": "Stained glass", "hint": "the same three panes in saturated red, blue and gold on a dark ground, blended with screen instead of multiply — overlaps glow instead of darkening",
			"dials": { "sky": [Color("101018"), Color("20202A")], "panes": [Color("E02040"), Color("2060E0"), Color("F0C000")], "ink": Color("F5F0E8"),
				"alpha": 0.8, "outside": 0.5, "blend": "screen",
				"label": "screen adds light where multiply took it away — the overlaps still count the layers, now in brightness" } },
		"init": func(b: Dictionary) -> void:
			b.lens = null,
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.lens = pos,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W
			var H: float = b.H
			var alpha: float = D.alpha
			var outside: float = D.outside
			var lens_r: float = D.lens_r
			_xray_scene(n, b, D)
			_panes(n, b, D, outside, Vector2.ZERO, 0.0)                 # faint everywhere…
			var lx: float = b.lens.x if b.lens != null else W * (0.5 + 0.3 * sin(t * 0.6))
			var ly: float = b.lens.y if b.lens != null else H * (0.5 + 0.2 * cos(t * 0.45))
			var R := W * lens_r
			# …full strength inside the lens. The canvas redraws the scene clipped to the disc, then the panes at
			# `alpha`; here the faint layer stays and a second pane layer is stacked on it, with the alpha that makes
			# faint + extra ≡ full: 1 − (1 − a2)(1 − outside) = alpha
			var a2 := clampf(1.0 - (1.0 - alpha) / maxf(0.001, 1.0 - outside), 0.0, 1.0)
			_panes(n, b, D, a2, Vector2(lx, ly), R)
			n.draw_arc(Vector2(lx, ly), R, 0.0, TAU, 64, K.alpha(D.ink, 0.6), 2.0, true)
			K.label(n, b, D.label, K.alpha(D.ink, 0.7)) })

	return d
