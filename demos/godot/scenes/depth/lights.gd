extends RefCounted
## LIGHT SOURCES — 13 pictures, ported from the web atlas (docs/depth.js, fam5).
## A light source is four things drawn in order: a hot core, a radial falloff
## around it, the light it THROWS onto whatever is nearby (a gradient on the
## wall or floor that follows the source), and — usually — additive blending,
## so overlapping glows brighten instead of covering each other.
##
## The web page draws its light with globalCompositeOperation = "lighter".
## Godot's _draw() has no per-call blend mode, so every "lighter" pass here is
## approximated with translucent K.soft glows layered normally — two stacked
## where the web relied on addition for a hot core. The falloff shapes and
## the numbers are the web's; only the arithmetic of the overlap differs.
##
## Each def: letter, name, hint, dials (D), rhyme { name, hint, dials } and
## the callables init(b) / tick(b, dt) / press(b, pos) / draw(n, b). The
## rhyme's dials are merged over D on right-click — nothing else changes.

const K := preload("res://scenes/depth/kit.gd")

const TITLE := "Light sources"
const BLURB := "suns, stars, flames, tubes — a bright core, a falloff, and the light it throws on things"

## The colour of a [[k, Color], …] gradient at k.
static func _grad_at(stops: Array, k: float) -> Color:
	k = clampf(k, 0.0, 1.0)
	var last := stops.size() - 1
	if k <= float(stops[0][0]):
		return stops[0][1]
	for i in last:
		var k1: float = stops[i + 1][0]
		if k <= k1:
			var k0: float = stops[i][0]
			var f := 0.0 if k1 - k0 < 0.0001 else (k - k0) / (k1 - k0)
			return (stops[i][1] as Color).lerp(stops[i + 1][1], f)
	return stops[last][1]

static func _corners(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])

## The canvas idiom "radial fillStyle, then fill THIS shape" — a radial
## gradient that stops at a polygon's edge instead of spilling past it.
## Works for a convex outline that contains (or touches) the centre: the
## outline is pulled in toward c once per stop, each ring coloured by its true
## distance, and the whole thing is one triangle array like K.radial.
static func rad_poly(n: CanvasItem, outline: PackedVector2Array, c: Vector2, r: float, stops: Array) -> void:
	r = maxf(r, 0.5)
	var edge := PackedVector2Array()                       # densify so the inner rings can be round
	var m := outline.size()
	for i in m:
		var a := outline[i]
		var bp := outline[(i + 1) % m]
		var steps := maxi(1, int(ceil(a.distance_to(bp) / 4.0)))
		for s in steps:
			edge.append(a.lerp(bp, float(s) / steps))
	var cnt := edge.size()
	var rn := stops.size()                                 # rings: one per stop after the first, plus the outline
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	pts.append(c)
	cols.append(stops[0][1])
	for j in rn:
		var is_outline := j == rn - 1
		for p in edge:
			var d := p.distance_to(c)
			if is_outline:
				pts.append(p)
				cols.append(_grad_at(stops, d / r))
			else:
				var kk := minf(float(stops[j + 1][0]), d / r)   # the ring sits at k·r, or on the edge if that is nearer
				var q := c if d < 0.001 else c + (p - c) * (kk * r / d)
				pts.append(q)
				cols.append(_grad_at(stops, kk))
	for s in cnt:
		idx.append(0); idx.append(1 + s); idx.append(1 + (s + 1) % cnt)
	for j in range(1, rn):
		var a := 1 + (j - 1) * cnt
		var bb := 1 + j * cnt
		for s in cnt:
			var s1 := (s + 1) % cnt
			idx.append(a + s); idx.append(bb + s); idx.append(bb + s1)
			idx.append(a + s); idx.append(bb + s1); idx.append(a + s1)
	RenderingServer.canvas_item_add_triangle_array(n.get_canvas_item(), idx, pts, cols)

static func defs() -> Array:
	var d: Array = []

	# ---- S · Sun -----------------------------------------------------------
	d.append({ "letter": "S", "name": "Sun",
		"hint": "a disc with limb darkening, a corona of stacked glows added together, slow faint rays — and a wide soft that brightens the sky around it",
		"dials": { "sky": [Color("0B1030"), Color("2A4F9A")], "core": Color("FFFBE8"), "disc": Color("FFD070"), "limb": Color("F08A30"), "corona": Color("FFC060"),
			"size": 0.13, "layers": 4, "rays": 12, "spin": 0.08, "fade": 0.05,
			"label": "core → falloff → thrown light: the disc is one radial, the corona four more, added" },
		"rhyme": { "name": "Red giant", "hint": "the same sun swollen and cooled — a crimson palette, a disc almost twice as wide, six corona layers, a slower spin",
			"dials": { "sky": [Color("0A0508"), Color("3A0A14")], "core": Color("FFE0B0"), "disc": Color("FF6A3A"), "limb": Color("8A1A10"), "corona": Color("FF5A3A"),
				"size": 0.22, "layers": 6, "spin": 0.03, "fade": 0.04,
				"label": "a star's age is three hex codes and a radius — the limb darkening is the same ramp, redder" } },
		"init": func(b: Dictionary) -> void:
			b.sx = b.W * 0.5; b.sy = b.H * 0.45,
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.sx = pos.x; b.sy = pos.y,                           # click = put the sun there
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W
			K.sky(n, b, D.sky)
			var r: float = W * D.size
			var sun := Vector2(b.sx, b.sy)
			K.soft(n, sun, W * 0.8, D.corona, 0.22)                # the thrown light: the air near the sun is paler
			var layers: int = D.layers
			var fade: float = D.fade
			for i in layers:                                       # corona: each layer wider and fainter ("lighter" on the web — stacked softs here)
				K.soft(n, sun, r * (1.4 + i * 0.7) * (1.0 + 0.03 * sin(t * 1.3 + i)), D.corona, 0.28 - i * fade)
			var rays: int = D.rays
			for j in rays:                                         # rays: thin triangles fading outward, on a slow rotation
				var ang: float = t * D.spin + TAU * (j + 1) / rays
				var ln := r * (2.2 + 0.6 * sin(t * 0.7 + j * 2.1))
				var base := K.alpha(D.corona, 0.22 * (1.0 - 0.9 * r / ln))
				n.draw_set_transform(sun, ang, Vector2.ONE)
				K.lin_poly(n, PackedVector2Array([Vector2(r * 0.9, -r * 0.08), Vector2(ln, 0), Vector2(r * 0.9, r * 0.08)]),
					PackedColorArray([base, K.alpha(D.corona, 0.0), base]))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			K.radial(n, sun, r, [[0.0, D.core], [0.55, D.disc], [1.0, D.limb]])   # limb darkening: bright centre, dim edge
			K.label(n, b, D.label) })

	# ---- C · Candle --------------------------------------------------------
	d.append({ "letter": "C", "name": "Candle",
		"hint": "a flame is two glows and a bright tip, wobbling; the wall is lit by a radial that flickers with it, the wax a cylinder lit from the flame side",
		"dials": { "wall": Color("1A1424"), "flame": Color("FFB040"), "tip": Color("FFF6D8"), "blue": Color("5A8AFF"), "wax": Color("E8DCC0"),
			"wobble": 1.0, "reach": 0.55, "count": 1, "floor": Color("100C18"),
			"label": "three soft radials added = a flame; a fourth on the wall, following it = the light it throws" },
		"rhyme": { "name": "Birthday candles", "hint": "the same flame three times over in pastel — pink wax, a cream wall, each flame wobbling on its own phase",
			"dials": { "wall": Color("3A2A44"), "flame": Color("FFC070"), "blue": Color("8AB0FF"), "wax": Color("F5B8D0"),
				"reach": 0.4, "count": 3, "floor": Color("2A1E30"),
				"label": "three sources = three overlapping falloffs; additive, they sum into one warm wall" } },
		"init": func(b: Dictionary) -> void:
			b.cx = b.W * 0.5; b.top = b.H * 0.5,
		"press": func(b: Dictionary, pos: Vector2) -> void:         # click = move the candle, taller or shorter
			b.cx = pos.x; b.top = clampf(pos.y, b.H * 0.3, b.H * 0.7),
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			var fl: float = H * 0.8
			var top: float = b.top
			n.draw_rect(Rect2(0, 0, W, H), D.wall)
			K.ground(n, b, fl, D.floor)
			var count: int = D.count
			var wobble: float = D.wobble
			var reach: float = D.reach
			for i in count:
				var x0: float = b.cx + (i - (count - 1) / 2.0) * W * 0.16
				var ph := i * 2.3
				var w := sin(t * 9.0 * wobble + ph) * 0.6 + sin(t * 23.0 * wobble + ph) * 0.4   # two sines that disagree = wobble
				var fx := x0 + w * W * 0.012
				var fy := top - H * 0.07
				var flick := 0.85 + 0.15 * sin(t * 13.0 * wobble + ph)
				K.soft(n, Vector2(fx, fy), W * reach * flick, D.flame, 0.5 / count)   # the thrown light on the wall, breathing with the flame
				K.soft(n, Vector2(fx, fl), W * 0.25, D.flame, 0.25 * flick)          # and a pool on the table
				K.cyl(n, x0, fl, W * 0.08, fl - top, D.wax, w * 0.5)                  # the wax: lit from whichever side the flame leans
				K.line(n, Vector2(x0, top), Vector2(x0, fy + H * 0.03), Color("3A2A20"), 1.5)   # the wick
				# the flame: three glows the web adds together — stacked translucent here
				K.soft(n, Vector2(fx, fy + H * 0.03), W * 0.02, D.blue, 0.6)          # the blue base
				K.soft(n, Vector2(fx, fy), W * 0.05 * flick, D.flame, 0.7)            # the body glow
				K.soft(n, Vector2(fx + w * 2.0, fy - H * 0.025), W * 0.02, D.tip, 0.9) # the hot tip
			K.label(n, b, D.label) })

	# ---- E · Eclipse -------------------------------------------------------
	d.append({ "letter": "E", "name": "Eclipse",
		"hint": "a dark disc over a bright corona: streaky glows and thin radial lines, added, breathing slowly — the sky darkens as totality nears (press x scrubs)",
		"dials": { "sky": Color("2A4F9A"), "dark": Color("05050F"), "corona": Color("FFF4E0"), "moon": Color("0A0A12"),
			"size": 0.14, "moon_size": 1.02, "streaks": 28, "breath": 0.4,
			"label": "the corona was always there — the source has to be covered before its falloff can be seen" },
		"rhyme": { "name": "Ring of fire", "hint": "the same eclipse, annular — the moon a touch too small, so a thin bright ring survives, with a bigger orange corona and more streaks",
			"dials": { "corona": Color("FFB060"), "moon_size": 0.9, "streaks": 40,
				"label": "one radius dial: a moon at 0.9 of the sun leaves a ring of core showing round the dark" } },
		"init": func(b: Dictionary) -> void:
			b.k = 0.85                                             # 0 = full sun, 1 = totality
			var R := K.rng(7)
			b.st = []
			for j in int(b.D.streaks):
				b.st.append({ "a": R.randf() * TAU, "len": 1.4 + R.randf() * 1.6, "ph": R.randf() * 9.0 }),
		"press": func(b: Dictionary, pos: Vector2) -> void: b.k = pos.x / b.W,   # click = scrub toward totality by x
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			var k: float = b.k
			K.sky(n, b, [K.mix(D.sky, D.dark, k), K.mix(K.shade(D.sky, 0.3), K.shade(D.dark, 0.1), k)])   # the day drains out
			var r: float = W * D.size
			var c := Vector2(W * 0.5, H * 0.45)
			var br: float = 1.0 + 0.06 * sin(t * D.breath * TAU)
			# the corona only shows once the disc is dark — two glows the web adds, stacked here
			K.soft(n, c, r * 3.2 * br, D.corona, 0.18 * k)
			K.soft(n, c, r * 1.8 * br, D.corona, 0.35 * k)
			for s in b.st:                                          # streaks: thin lines from the rim outward
				var a: float = 0.25 * k * (0.6 + 0.4 * sin(t * 0.8 + s.ph))
				var dir := Vector2(cos(s.a), sin(s.a))
				K.line(n, c + dir * r * 1.02, c + dir * r * s.len * br, K.alpha(D.corona, a), 1.0)
			K.dot(n, c, r, Color("FFF0C0"))                          # the sun's disc
			K.dot(n, c + Vector2((1.0 - k) * r * 2.2, -(1.0 - k) * r * 0.4), r * D.moon_size, D.moon)   # the moon slides across it
			K.label(n, b, D.label) })

	# ---- F · Flare ---------------------------------------------------------
	d.append({ "letter": "F", "name": "Flare",
		"hint": "a lens flare: soft discs and rings strung along the line from the sun through the canvas centre, sizes and hues varying, plus one horizontal streak",
		"dials": { "sky": [Color("1A2A5A"), Color("6A9AD0")], "sun": Color("FFF8E0"), "hues": [40.0, 200.0, 300.0, 160.0], "ghosts": 7,
			"streak": Color("9AC8FF"), "streak_len": 0.9, "hex": false, "hill": Color("0E1428"),
			"label": "every ghost sits at centre + (centre − sun) × k — move the sun and the whole chain re-aims" },
		"rhyme": { "name": "Anime flare", "hint": "the same chain of ghosts, twelve of them, hexagonal and pink — the sun a hot pastel, the streak lilac",
			"dials": { "sky": [Color("2A1A4A"), Color("C86AA8")], "sun": Color("FFF0F8"), "hues": [330.0, 300.0, 350.0, 280.0], "ghosts": 12,
				"streak": Color("E8B0FF"), "hex": true, "hill": Color("1A0E28"),
				"label": "hard hexagons instead of soft discs: the ghosts now say 'lens' — the geometry is the same" } },
		"init": func(b: Dictionary) -> void:
			b.sx = b.W * 0.3; b.sy = b.H * 0.3
			var R := K.rng(4)
			var hues: Array = b.D.hues
			b.gh = []
			for j in int(b.D.ghosts):
				b.gh.append({ "k": -0.6 + R.randf() * 2.4, "r": 0.02 + R.randf() * 0.07, "ring": R.randf() < 0.4,
					"hue": float(hues[j % hues.size()]) + R.randf() * 20.0 }),
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.sx = pos.x; b.sy = pos.y,                           # click = move the sun; the chain follows
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var W: float = b.W; var H: float = b.H
			K.sky(n, b, D.sky)
			K.poly(n, PackedVector2Array([Vector2(0, H * 0.82), Vector2(W * 0.3, H * 0.7), Vector2(W * 0.55, H * 0.78),
				Vector2(W * 0.8, H * 0.66), Vector2(W, H * 0.74), Vector2(W, H), Vector2(0, H)]), D.hill)
			var sun := Vector2(b.sx, b.sy)
			var cx := W / 2.0; var cy := H / 2.0
			K.soft(n, sun, W * 0.6, D.sun, 0.35)                     # the thrown light: haze around the sun
			K.soft(n, sun, W * 0.08, D.sun, 1.0)                     # the core (additive on the web)
			n.draw_set_transform(sun, 0.0, Vector2(1.0, 0.05))       # the anamorphic streak: a glow squashed flat
			K.soft(n, Vector2.ZERO, W * D.streak_len, D.streak, 0.6)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for g in b.gh:                                           # ghosts: mirrored through the centre by factor k
				var p := Vector2(cx + (cx - sun.x) * g.k, cy + (cy - sun.y) * g.k)
				var r: float = W * g.r
				var col := K.hsl(g.hue, 0.8, 0.65)
				if g.ring:
					n.draw_arc(p, r, 0.0, TAU, 40, K.alpha(col, 0.35), r * 0.25, true)
				elif D.hex:
					var pts := PackedVector2Array()
					for h in 6: pts.append(p + Vector2(cos(h * TAU / 6.0), sin(h * TAU / 6.0)) * r)
					K.poly(n, pts, K.alpha(col, 0.3))
				else:
					K.soft(n, p, r, col, 0.45)
			K.label(n, b, D.label) })

	# ---- H · Hearth --------------------------------------------------------
	d.append({ "letter": "H", "name": "Hearth",
		"hint": "a dark room lit by one warm radial centred on the fire; the fire is stacked glows, the light flickers, two blocks throw long soft shadows away from it",
		"dials": { "sky": [Color("0A0810"), Color("0A0810")], "mantle": Color("2A1C1A"), "warm": Color("FF9A40"), "hot": Color("FFE0A0"),
			"flicker": 1.0, "reach": 0.9, "floor": Color("0E0A12"),      # mantle: null = no fireplace (outdoors)
			"label": "one radial lights wall and floor at once; shadows point away from it and fade with length" },
		"rhyme": { "name": "Campfire night", "hint": "the same fire outdoors — a night-sky palette, no fireplace, the two blocks now logs — and the same long shadows across the grass",
			"dials": { "sky": [Color("05051A"), Color("1A2040")], "mantle": null, "reach": 0.7, "floor": Color("0A1410"),
				"label": "take the walls away and the light still tells the room's shape — by what it reaches" } },
		"init": func(b: Dictionary) -> void: b.fx = b.W * 0.5,
		"press": func(b: Dictionary, pos: Vector2) -> void: b.fx = pos.x,   # click = move the fire along the floor
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			var fx: float = b.fx
			var fy: float = H * 0.72
			var flicker: float = D.flicker
			K.sky(n, b, D.sky)
			K.ground(n, b, fy, D.floor)
			var f := 0.8 + 0.2 * (sin(t * 7.0 * flicker) * 0.5 + sin(t * 17.0 * flicker) * 0.3 + sin(t * 31.0 * flicker) * 0.2)   # amplitude noise
			K.soft(n, Vector2(fx, fy), W * D.reach * f, D.warm, 0.55)   # the thrown light: one radial over wall AND floor
			if D.mantle != null:                                     # the fireplace: a dark opening in a lit surround
				var mantle: Color = D.mantle
				rad_poly(n, _corners(Rect2(fx - W * 0.15, fy - H * 0.26, W * 0.3, H * 0.26)), Vector2(fx, fy - H * 0.08), W * 0.22,
					[[0.0, K.shade(mantle, 0.5)], [1.0, mantle]])
				n.draw_rect(Rect2(fx - W * 0.1, fy - H * 0.18, W * 0.2, H * 0.18), Color("05040A"))
			# the fire: three glows the web adds — stacked translucent here
			K.soft(n, Vector2(fx, fy - H * 0.03), W * 0.09 * f, D.warm, 0.8)
			K.soft(n, Vector2(fx, fy - H * 0.06), W * 0.05 * f, D.hot, 0.8)
			K.soft(n, Vector2(fx, fy - H * 0.01), W * 0.05, Color("FF5020"), 0.6)
			for blk in [[0.2, 0.05], [0.78, 0.06]]:                  # two furniture blocks: x, half-width
				var bx: float = W * blk[0]; var bw: float = W * blk[1]
				var dir := 1.0 if bx > fx else -1.0
				var ln := W * 0.3 * f
				# a long shadow, fading with distance: alpha 0.6 at the block, 0 at the far end
				var quad := PackedVector2Array([Vector2(bx - bw, fy), Vector2(bx + bw, fy), Vector2(bx + bw + dir * ln, fy + H * 0.07), Vector2(bx - bw + dir * ln, fy + H * 0.07)])
				var cols := PackedColorArray()
				for q in quad: cols.append(Color(0, 0, 0, 0.6 * (1.0 - clampf((q.x - bx) * dir / ln, 0.0, 1.0))))
				K.lin_poly(n, quad, cols)
				var lit := K.mix(Color("3A2A2A"), D.warm, 0.5 * f)
				var dark := Color("120C10")
				K.hlin_rect(n, Rect2(bx - bw, fy - H * 0.1, bw * 2.0, H * 0.1), [lit, dark] if dir > 0.0 else [dark, lit])   # the face toward the fire is lit
			K.label(n, b, D.label) })

	# ---- K · Kiln ----------------------------------------------------------
	d.append({ "letter": "K", "name": "Kiln",
		"hint": "a chamber glowing from within: a hot radial inside a dark box, breathing; embers drifting out; a wedge of glow spilling onto the floor",
		"dials": { "bg": [Color("0C0A10"), Color("100D14")], "brick": Color("3A2A28"), "hot": Color("FFD070"), "heat": Color("FF6A20"),
			"period": 3.0, "embers": 24, "drift": 1.0, "floor": Color("0A080E"), "deep": Color("3A0A00"), "deepest": Color("200400"),   # period: seconds per breath
			"label": "light from inside a box: the core is hidden, so the falloff and the spill do all the telling" },
		"rhyme": { "name": "Iron forge", "hint": "the same chamber running hotter — blue-white heat, a breath every 1.2 s instead of 3, forty sparks instead of two dozen embers",
			"dials": { "bg": [Color("08090E"), Color("0C0E14")], "brick": Color("2A2C34"), "hot": Color("E8F4FF"), "heat": Color("5A9AFF"),
				"period": 1.2, "embers": 40, "drift": 1.4, "floor": Color("08080C"), "deep": Color("0A1A3A"), "deepest": Color("040A20"),
				"label": "hotter reads as bluer and faster — temperature is a hue dial and a period dial" } },
		"init": func(b: Dictionary) -> void:
			b.kx = b.W * 0.5
			var R := K.rng(5)
			b.em = []
			for j in int(b.D.embers):
				b.em.append({ "ph": R.randf(), "spd": 0.12 + R.randf() * 0.12, "dx": (R.randf() - 0.5) * b.W * 0.2, "s": 0.6 + R.randf() * 1.2 }),
		"press": func(b: Dictionary, pos: Vector2) -> void: b.kx = pos.x,   # click = slide the kiln along the floor
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			var kx: float = b.kx
			var fy: float = H * 0.75
			K.sky(n, b, D.bg)
			K.ground(n, b, fy, D.floor)
			var br: float = 0.7 + 0.3 * (0.5 + 0.5 * sin(t * TAU / D.period))   # the heat breathes
			# the box, lit near its mouth: a radial that stops at the box's edge
			rad_poly(n, _corners(Rect2(kx - W * 0.18, fy - H * 0.42, W * 0.36, H * 0.42)), Vector2(kx, fy - H * 0.1), W * 0.3,
				[[0.0, K.mix(D.brick, D.heat, 0.45 * br)], [1.0, D.brick]])
			# the interior: a hot radial filling an arched opening
			var aw := W * 0.07; var ah := H * 0.12
			var arch := PackedVector2Array([Vector2(kx - aw, fy), Vector2(kx - aw, fy - ah)])
			for s in range(1, 16):
				arch.append(Vector2(kx, fy - ah) + Vector2(cos(PI + PI * s / 16.0), sin(PI + PI * s / 16.0)) * aw)
			arch.append(Vector2(kx + aw, fy - ah)); arch.append(Vector2(kx + aw, fy))
			rad_poly(n, arch, Vector2(kx, fy - H * 0.04), W * 0.11,
				[[0.0, D.hot], [0.5, K.mix(D.heat, D.deep, 1.0 - br)], [1.0, D.deepest]])
			# the spill: the web clips a soft to a wedge on the floor — here the wedge IS the gradient
			rad_poly(n, PackedVector2Array([Vector2(kx - aw, fy), Vector2(kx + aw, fy), Vector2(kx + W * 0.32, H), Vector2(kx - W * 0.32, H)]),
				Vector2(kx, fy), H * 0.32, [[0.0, K.alpha(D.heat, 0.6 * br)], [1.0, K.alpha(D.heat, 0.0)]])
			var drift: float = D.drift
			for e in b.em:                                           # embers: born at the mouth, fading as they rise (additive on the web)
				var life: float = fposmod(t * e.spd * drift + e.ph, 1.0)
				K.dot(n, Vector2(kx + e.dx * life + sin(t * 2.0 + e.ph * 9.0) * 3.0, fy - H * 0.04 - life * H * 0.4), e.s, K.alpha(D.hot, (1.0 - life) * 0.9))
			K.label(n, b, D.label) })

	# ---- L · Lantern -------------------------------------------------------
	d.append({ "letter": "L", "name": "Lantern",
		"hint": "a paper lantern: a warm gradient shell with dark ribs, lit by a core inside, swaying on a string — the pool of light on the ground moves with it",
		"dials": { "sky": [Color("0A0818"), Color("1A1030")], "paper": Color("FF8A3A"), "core": Color("FFF0C0"), "ribs": 7,
			"sway": 1.0, "count": 1, "rise": 0.0,                        # rise > 0: the lanterns float upward and wrap
			"label": "a shell is a radial with the core inside it; the pool below is the same light, arriving late" },
		"rhyme": { "name": "Sky lanterns", "hint": "the same shell five times, cut loose and rising — no strings, gentler sway, and the pools on the ground widening and fading as they climb",
			"dials": { "paper": Color("FFB050"), "sway": 0.5, "count": 5, "rise": 1.0,
				"label": "the higher the source, the wider and fainter its pool — height is written on the ground" } },
		"init": func(b: Dictionary) -> void: b.px = b.W * 0.5,
		"press": func(b: Dictionary, pos: Vector2) -> void: b.px = pos.x,   # click = move the hook; the pool follows
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			var px: float = b.px
			var py := H * 0.12
			var GY := H * 0.82
			K.sky(n, b, D.sky)
			K.ground(n, b, GY, Color("0C0A14"))
			var rw := W * 0.085; var rh := H * 0.12
			var count: int = D.count
			var sway: float = D.sway
			var rise: float = D.rise
			var ribs: int = D.ribs
			for i in count:
				var ang := sin(t * 1.4 * sway + i * 2.0) * 0.18 * sway   # a pendulum: angle is a sine
				var L := H * 0.32
				var hook := px + (i - (count - 1) / 2.0) * W * 0.17
				var lx := hook + sin(ang) * L
				var ly := py + cos(ang) * L - rise * fposmod(t * 0.06 + i * 0.37, 1.0) * H * 0.5
				var hk := clampf((GY - ly - rh) / (H * 0.6), 0.0, 1.0)  # how high above the ground: 0 low, 1 high
				n.draw_set_transform(Vector2(lx, GY), 0.0, Vector2(1.0, 0.3))   # the pool: wider and fainter the higher the lamp
				K.soft(n, Vector2.ZERO, W * (0.15 + hk * 0.3), D.paper, 0.55 * (1.0 - hk))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				if rise == 0.0:
					K.line(n, Vector2(hook, py), Vector2(lx, ly - rh), K.alpha(K.INK, 0.35), 1.0)   # the string
				K.soft(n, Vector2(lx, ly), rw * 3.0, D.paper, 0.35)    # the halo round the shell (additive on the web)
				n.draw_set_transform(Vector2(lx, ly), 0.0, Vector2(1.0, rh / rw))   # the shell: a radial lit from a core inside
				K.radial(n, Vector2.ZERO, rw, [[0.0, D.core], [0.45, D.paper], [1.0, K.shade(D.paper, -0.45)]])
				for j in ribs:                                         # ribs: thin dark verticals across the shell
					var xr := -rw + (j + 0.5) * (2.0 * rw / ribs)
					var yr := sqrt(maxf(0.0, rw * rw - xr * xr))
					K.line(n, Vector2(xr, -yr), Vector2(xr, yr), Color(0, 0, 0, 0.25), 1.0)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				n.draw_rect(Rect2(lx - rw * 0.3, ly - rh - 3.0, rw * 0.6, 4.0), Color("2A1A14"))   # cap and base
				n.draw_rect(Rect2(lx - rw * 0.3, ly + rh - 1.0, rw * 0.6, 4.0), Color("2A1A14"))
			K.label(n, b, D.label) })

	# ---- M · Moonphases ----------------------------------------------------
	d.append({ "letter": "M", "name": "Moonphases",
		"hint": "a sphere shaded by a light that orbits over time — the terminator moves new → crescent → half → full; one offset radial plus one dark disc",
		"dials": { "sky": [Color("03030A"), Color("0B0B1E")], "moons": [Color("D8D8E0")], "dark": Color("0E0E1A"), "glow": Color("B8C8FF"),
			"size": 0.2, "month": 12.0, "count": 1,                     # month: seconds for one full cycle
			"label": "the terminator IS the sphere: a shading offset plus a sliding dark disc, nothing else" },
		"rhyme": { "name": "Twin moons", "hint": "the same terminator on two moons of another world — one rose, one teal, the small one a third of a cycle ahead — and a faster month",
			"dials": { "sky": [Color("0A0410"), Color("1E0A24")], "moons": [Color("F0B8C8"), Color("8AE0D0")], "dark": Color("120A18"), "glow": Color("F0C8E0"),
				"month": 7.0, "count": 2,
				"label": "two spheres, one rule: each shadow line is the same offset, just read at a different k" } },
		"init": func(b: Dictionary) -> void:
			b.phase = -1.0                                         # < 0 = follow the clock
			var R := K.rng(12)
			b.stars = []
			for j in 50: b.stars.append(Vector3(R.randf() * b.W, R.randf() * b.H, 0.3 + R.randf() * 1.0)),
		"press": func(b: Dictionary, pos: Vector2) -> void: b.phase = pos.x / b.W,   # click = set the phase by x
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			K.sky(n, b, D.sky)
			var si := 0
			for s in b.stars:
				K.dot(n, Vector2(s.x, s.y), s.z, K.alpha(K.INK, 0.4 + 0.3 * sin(t * 2.0 + si))); si += 1
			var k0: float = b.phase if b.phase >= 0.0 else fposmod(t / D.month, 1.0)   # 0 new → 0.25 first quarter → 0.5 full → 1 new
			var count: int = D.count
			var moons: Array = D.moons
			for i in count:
				var k := fposmod(k0 + i * 0.3, 1.0)
				var m := Vector2(W * (0.5 + (i - (count - 1) / 2.0) * 0.42), H * 0.45)
				var r: float = W * D.size * (1.0 - i * 0.35)
				var col: Color = moons[i % moons.size()]
				var f := 0.5 - 0.5 * cos(k * TAU)                      # the lit fraction: 0 new, 1 full
				var dir := 1.0 if k < 0.5 else -1.0                   # waxing lights the right edge, waning the left
				var lx := sin(k * TAU)
				K.soft(n, m, r * 2.6, D.glow, 0.18 * f)                # the thrown light: the sky glows by how full it is
				K.sphere(n, m, r, col, lx, -0.2, 0.15)                 # the shading follows the light like any ball
				K.dot(n, Vector2(m.x - dir * (f * 2.0 * r), m.y), r * 1.01, D.dark)   # the shadow disc slides off as the moon fills
				K.dot(n, m, r, K.alpha(col, 0.08 * (1.0 - f)))         # earthshine: the dark side is not quite black
			K.label(n, b, D.label) })

	# ---- N · Neon ----------------------------------------------------------
	d.append({ "letter": "N", "name": "Neon",
		"hint": "a neon sign: one path stroked four times, wider and fainter each pass (the falloff), added; it flickers; the wall gets a glow of the same hue",
		"dials": { "wall": Color("141018"), "tube": Color("FF2A8A"), "passes": 4, "flicker": 0.15, "wobble": 0.0, "floor": Color("0A080C"),   # flicker: chance per tick of a dim moment
			"label": "one path, four strokes: a thin white-hot core, then wider fainter halos — added, not layered" },
		"rhyme": { "name": "Broken neon", "hint": "the same sign dying — cyan, stuttering seven ticks in ten, its halos jittering out of register with the core",
			"dials": { "wall": Color("101418"), "tube": Color("30E8FF"), "flicker": 0.7, "wobble": 1.0, "floor": Color("080A0C"),
				"label": "jitter each pass a few pixels and the halos slip off the core — 'broken' is a wobble dial" } },
		"init": func(b: Dictionary) -> void:
			b.R = K.rng(9)
			b.flick = 1.0; b.next_at = 0.0; b.ox = 0.0; b.oy = 0.0
			b.pts = PackedVector2Array()
			for i in 41:                                           # a word-like squiggle
				b.pts.append(Vector2(b.W * (0.2 + 0.6 * i / 40.0), b.H * 0.45 + sin(i * 0.9) * b.H * 0.1 + sin(i * 0.37) * b.H * 0.05)),
		"press": func(b: Dictionary, pos: Vector2) -> void:         # click = hang the sign there; the glow follows
			b.ox = pos.x - b.W / 2.0; b.oy = pos.y - b.H * 0.45,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			var R: RandomNumberGenerator = b.R
			var ox: float = b.ox; var oy: float = b.oy
			n.draw_rect(Rect2(0, 0, W, H), D.wall)
			if t > b.next_at:                                       # a tube does not fade — it stutters
				b.flick = (0.2 + R.randf() * 0.5) if R.randf() < D.flicker else 1.0
				b.next_at = t + 0.08 + R.randf() * 0.3
			var flick: float = b.flick
			for bb in 6:                                            # brick courses, barely there
				K.line(n, Vector2(0, H * 0.14 * bb), Vector2(W, H * 0.14 * bb), Color(1, 1, 1, 0.03), 1.0)
			K.soft(n, Vector2(W / 2.0 + ox, H * 0.45 + oy), W * 0.6, D.tube, 0.35 * flick)   # the wall glow: the thrown light
			K.ground(n, b, H * 0.85, D.floor)
			n.draw_set_transform(Vector2(W / 2.0 + ox, H * 0.85), 0.0, Vector2(1.0, 0.25))   # a smear on the wet floor
			K.soft(n, Vector2.ZERO, W * 0.4, D.tube, 0.2 * flick)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var passes: int = D.passes
			var wobble: float = D.wobble
			for p in range(passes - 1, -1, -1):                     # widest and faintest first, hot core last ("lighter" on the web; plain alpha here)
				var jx := ox + wobble * (R.randf() - 0.5) * 4.0
				var jy := oy + wobble * (R.randf() - 0.5) * 4.0
				var width := 2.0 + p * p * 3.0                          # 2, 5, 14, 29 — the falloff is repetition
				var col := K.alpha(K.shade(D.tube, 0.6) if p == 0 else D.tube, (0.95 if p == 0 else 0.4 / p) * flick)
				var q := PackedVector2Array()
				for pt in b.pts: q.append(pt + Vector2(jx, jy))
				n.draw_polyline(q, col, width, true)
			K.label(n, b, D.label) })

	# ---- Q · Quasar --------------------------------------------------------
	d.append({ "letter": "Q", "name": "Quasar",
		"hint": "a hot core, two opposite jets (glows stretched with ctx.scale), and a torus-like accretion ring — all added, slowly rotating; pure light, no matter",
		"dials": { "sky": [Color("020208"), Color("0A0618")], "core": Color.WHITE, "jet": Color("7AB8FF"), "disc": Color("FF8A5A"),
			"spin": 0.15, "jet_len": 0.45, "pulse": 0.0,                # pulse: seconds per beat (0 = steady)
			"label": "additive only: nothing here is solid, so every overlap is brighter — that IS how light behaves" },
		"rhyme": { "name": "Crab pulsar", "hint": "the same core and jets spinning thirteen times faster and beating once every 0.9 s — a lighthouse in cyan and violet",
			"dials": { "jet": Color("40F0FF"), "disc": Color("9A5AFF"), "spin": 2.0, "pulse": 0.9,
				"label": "a pulse is alpha on a sharpened cosine — the beam is the same glow, seen only when it points at you" } },
		"init": func(b: Dictionary) -> void:
			b.cx = b.W / 2.0; b.cy = b.H * 0.48
			var R := K.rng(17)
			b.stars = []
			for j in 70: b.stars.append(Vector3(R.randf() * b.W, R.randf() * b.H, 0.3 + R.randf() * 0.9)),
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.cx = pos.x; b.cy = pos.y,                           # click = move the engine
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			K.sky(n, b, D.sky)
			for s in b.stars: K.dot(n, Vector2(s.x, s.y), s.z, K.alpha(K.INK, 0.5))
			var pulse: float = D.pulse
			var amp := (0.15 + 0.85 * pow(0.5 + 0.5 * cos(t * TAU / pulse), 8.0)) if pulse > 0.0 else 1.0   # a beat: a sharpened cosine
			var c := Vector2(b.cx, b.cy)
			var rot: float = t * D.spin + 0.5
			var jl: float = D.jet_len
			# everything below is "lighter" on the web — translucent glows in a rotated frame here
			n.draw_set_transform(c, rot, Vector2(1.0, 0.32))          # the accretion ring: glows squashed into a torus
			K.soft(n, Vector2.ZERO, W * 0.3, D.disc, 0.18)
			for i in 3:
				n.draw_arc(Vector2.ZERO, W * 0.15, 0.0, TAU, 48, K.alpha(D.disc, 0.35 - i * 0.1), W * (0.02 + i * 0.025), true)
			n.draw_set_transform(c, rot, Vector2(0.28, 1.0))          # the jets: glows stretched along the spin axis
			for sgn in [-1.0, 1.0]:
				K.soft(n, Vector2(0, sgn * H * jl * 0.55), H * jl * 0.6, D.jet, 0.35 * amp)
				K.soft(n, Vector2(0, sgn * H * jl * 0.25), H * jl * 0.3, D.jet, 0.45 * amp)
			n.draw_set_transform(c, rot, Vector2.ONE)                 # the core: two glows, the inner one white
			K.soft(n, Vector2.ZERO, W * 0.12, D.jet, 0.5 * amp)
			K.soft(n, Vector2.ZERO, W * 0.04, D.core, amp)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			K.label(n, b, D.label) })

	# ---- R · Rimlight ------------------------------------------------------
	d.append({ "letter": "R", "name": "Rimlight",
		"hint": "a backlit figure: a dark silhouette (sphere + body) with a bright rim on the edge nearest the light, a soft light behind — press moves the light",
		"dials": { "sky": [Color("0C0A1A"), Color("241A3A")], "ground": Color("0A0812"), "light": Color("FFE8B0"), "body": Color("1A1424"), "rim": Color("FFE8B0"), "size": 0.11,
			"label": "the rim is the edge nearest the light — a thin bright arc says 'lit from behind' on its own" },
		"rhyme": { "name": "Sunset silhouette", "hint": "the same backlit figure at dusk — an orange-to-violet sky, a low amber sun, a warm rim, a smaller head",
			"dials": { "sky": [Color("3A2A6A"), Color("F58A5A")], "ground": Color("1A1020"), "light": Color("FFB060"), "body": Color("1A1020"), "rim": Color("FFC070"), "size": 0.09,
				"label": "a warm rim against a warm sky: the silhouette reads as evening from the rim's colour alone" } },
		"init": func(b: Dictionary) -> void:
			b.lx = b.W * 0.72; b.ly = b.H * 0.3,
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.lx = pos.x; b.ly = pos.y,                           # click = move the light; the rim turns to face it
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var W: float = b.W; var H: float = b.H
			var GY := H * 0.8
			var light := Vector2(b.lx, b.ly)
			K.sky(n, b, D.sky)
			K.ground(n, b, GY, D.ground)
			K.soft(n, light, W * 0.55, D.light, 0.5)                 # the source and its falloff, behind everything
			K.soft(n, light, W * 0.12, D.light, 0.95)
			var hx := W * 0.5; var hy := H * 0.42
			var r: float = W * D.size
			var to := light - Vector2(hx, hy)
			var ln := to.length()
			if ln == 0.0: ln = 1.0
			var dx := to.x / ln; var dy := to.y / ln                 # unit vector toward the light
			K.shadow(n, Vector2(hx - dx * W * 0.18, GY + 3.0), r * 1.8, r * 0.4, 0.5)   # the cast shadow points away from the light
			var edge := 0.12 * absf(dx) + 0.02                      # the body's rim: a sliver on the light's side
			var rimc := K.alpha(D.rim, 0.85)
			var body_stops: Array = [[0.0, D.body], [1.0 - edge, D.body], [1.0, rimc]] if dx >= 0.0 else [[0.0, rimc], [edge, D.body], [1.0, D.body]]
			K.hlin_rect(n, Rect2(hx - r * 1.1, hy + r * 0.9, r * 2.2, GY - hy - r * 0.9), body_stops)
			K.sphere(n, Vector2(hx, hy), r, D.body, dx, dy, 0.05, Color("0A0810"), D.rim)   # the head: dark ball, rim toward the light
			K.label(n, b, D.label) })

	# ---- U · Ultraviolet ---------------------------------------------------
	d.append({ "letter": "U", "name": "Ultraviolet",
		"hint": "a blacklight room: a thin violet tube, its falloff on the wall, and only certain shapes glow — saturated additive violet and green with soft halos",
		"dials": { "room": Color("07050C"), "tube": Color("B08CFF"), "tube_core": Color("F0E8FF"), "glow_a": Color("8A3AFF"), "glow_b": Color("3AFF9A"),
			"reach": 0.55, "shapes": 7, "bob": 0.0, "floor": Color("05040A"), "matter": Color("100C16"),   # bob > 0: the shapes drift as if floating
			"label": "under a black light only the fluorescent things are bright — glow is a property of the object" },
		"rhyme": { "name": "Bioluminescent bay", "hint": "the same dark room underwater — teal and green glows, sixteen of them, bobbing on slow sines; the tube is now the moon on the surface",
			"dials": { "room": Color("03101A"), "tube": Color("6AC8FF"), "tube_core": Color("E8F8FF"), "glow_a": Color("20E0FF"), "glow_b": Color("40FFB0"),
				"reach": 0.7, "shapes": 16, "bob": 1.0, "floor": Color("02080E"), "matter": Color("061620"),
				"label": "swap violet for teal and the black light is seawater — the glowing things still make the scene" } },
		"init": func(b: Dictionary) -> void:
			b.tx = b.W * 0.5; b.ty = b.H * 0.12
			var R := K.rng(6)
			b.sh = []
			for j in int(b.D.shapes):
				b.sh.append({ "x": 0.1 + R.randf() * 0.8, "y": 0.35 + R.randf() * 0.45, "r": 0.015 + R.randf() * 0.03, "a": R.randf() < 0.5, "ph": R.randf() * 9.0 }),
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.tx = pos.x; b.ty = pos.y,                           # click = move the tube
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			var tube := Vector2(b.tx, b.ty)
			var hum := 1.0 + 0.05 * sin(t * 40.0)                    # a tube hums: a fast tiny shiver in brightness
			n.draw_rect(Rect2(0, 0, W, H), D.room)
			K.soft(n, tube, W * D.reach, D.tube, 0.35 * hum)         # the falloff on the wall
			K.ground(n, b, H * 0.82, D.floor)
			n.draw_rect(Rect2(W * 0.1, H * 0.6, W * 0.25, H * 0.22), D.matter)   # dull matter: it does NOT glow
			n.draw_rect(Rect2(W * 0.65, H * 0.66, W * 0.2, H * 0.16), D.matter)
			var bob: float = D.bob
			for s in b.sh:                                           # the things that fluoresce (additive on the web)
				var col: Color = D.glow_a if s.a else D.glow_b
				var a: float = 0.6 + 0.3 * sin(t * 1.5 + s.ph)
				var p := Vector2(W * s.x + bob * sin(t * 0.7 + s.ph) * W * 0.03, H * s.y + bob * cos(t * 0.5 + s.ph) * H * 0.03)
				K.soft(n, p, W * s.r * 2.6, col, 0.35 * a * hum)
				K.dot(n, p, W * s.r, K.alpha(col, 0.95))
			n.draw_set_transform(tube, 0.0, Vector2(1.0, 0.18))     # the tube's own halo, squashed flat
			K.soft(n, Vector2.ZERO, W * 0.32, D.tube, 0.6 * hum)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			n.draw_rect(Rect2(tube.x - W * 0.28, tube.y - 2.0, W * 0.56, 4.0), D.tube_core)   # the hard core: a thin bar
			K.label(n, b, D.label) })

	# ---- X · Xenon ---------------------------------------------------------
	d.append({ "letter": "X", "name": "Xenon",
		"hint": "a strobe tube: a hard white bar, a blue-white falloff, a short pulse every 1.5 s that lights the whole scene for an instant; dim in between",
		"dials": { "room": Color("0A0A12"), "flash": Color("DCEBFF"), "bar": Color.WHITE, "every": 1.5, "decay": 9.0, "auto": true,   # decay: how fast a flash dies (per second)
			"label": "a flash is the falloff with its alpha on a clock — the scene exists only while the light does" },
		"rhyme": { "name": "Camera flash", "hint": "the same tube fired by hand — no clock, one warm-white flash per press, dying a little slower so the shadows linger",
			"dials": { "flash": Color("FFE8C8"), "decay": 5.0, "auto": false,
				"label": "click to fire: the same pulse, now on your clock — a flash is a light with a very short life" } },
		"init": func(b: Dictionary) -> void:
			b.tx = b.W * 0.5; b.ty = b.H * 0.2; b.last_flash = -9.0,
		"press": func(b: Dictionary, pos: Vector2) -> void:         # click = move the tube and fire it now
			b.tx = pos.x; b.ty = pos.y; b.last_flash = b.t,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			var GY := H * 0.8
			var tube := Vector2(b.tx, b.ty)
			var every: float = D.every
			if D.auto and t - b.last_flash >= every:
				b.last_flash = floorf(t / every) * every
			var p := exp(-maxf(0.0, t - b.last_flash) * float(D.decay))   # the pulse: 1 at the flash, gone in a tenth of a second
			n.draw_rect(Rect2(0, 0, W, H), D.room)
			K.ground(n, b, GY, Color("07070E"))
			K.soft(n, tube, W * 1.1, D.flash, 0.12 + 0.88 * p)        # the thrown light: the whole room, for an instant
			for blk in [[0.22, 0.05], [0.5, 0.045], [0.76, 0.055]]:  # three boxes on the floor, for the flash to find
				var bx: float = W * blk[0]; var s: float = W * blk[1]
				var dir := (bx - tube.x) / (W * 0.5)
				K.shadow(n, Vector2(bx + dir * s * 3.0 * p, GY + 2.0), s * 2.0, s * 0.5, 0.55 * p)   # hard shadows appear only while the flash is on
				K.cube(n, Vector2(bx, GY), s, K.mix(Color("2A2A3A"), D.flash, 0.1 + 0.7 * p))
			n.draw_set_transform(tube, 0.0, Vector2(1.0, 0.2))      # the tube's falloff (additive on the web)
			K.soft(n, Vector2.ZERO, W * 0.35, D.flash, 0.3 + 0.7 * p)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			n.draw_rect(Rect2(tube.x - W * 0.2, tube.y - 2.0, W * 0.4, 4.0), K.alpha(D.bar, 0.5 + 0.5 * p))   # the hard core: a bar, dim when off
			K.label(n, b, D.label) })

	return d
