extends RefCounted
## DISTANCE & ATMOSPHERE — 13 pictures, ported from the web atlas (docs/depth.js).
## You never see a far thing directly — you see it THROUGH the air between
## you, and air has a colour. So far things are mixed toward that colour:
## paler, bluer, lower in contrast. Add three cheaper cues that ride along
## with distance — smaller, packed closer together, sliding slower when the
## camera moves — and a flat canvas gets a horizon. Every card here is
## K.fog(colour, depth, air) plus one of those cues, and the depth is a
## single number per thing. Most of them are mountains.
##
## Each def: letter, name, hint, dials (D), rhyme { name, hint, dials } and
## the callables init(b) / tick(b, dt) / press(b, pos) / draw(n, b). The
## rhyme's dials are merged over D on right-click — nothing else changes.

const K := preload("res://scenes/depth/kit.gd")

const TITLE := "Distance & atmosphere"
const BLURB := "far things are paler, bluer, softer, slower — the mountain range is a gradient of contrast"

## The colour a canvas gradient gives at k (0..1); stops are [[k, Color], …].
## A dune's sideways gradient is drawn as columns, so each column asks for its colour.
static func _grad(stops: Array, k: float) -> Color:
	if k <= float(stops[0][0]):
		return stops[0][1]
	for i in stops.size() - 1:
		var k0: float = stops[i][0]
		var k1: float = stops[i + 1][0]
		if k <= k1:
			return (stops[i][1] as Color).lerp(stops[i + 1][1], (k - k0) / maxf(k1 - k0, 0.0001))
	return stops[stops.size() - 1][1]

## An ellipse outline — draw_arc only knows circles, so a closed polyline.
static func _ring(n: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, w := 1.0) -> void:
	var pts := PackedVector2Array()
	for s in 25:
		var ang := TAU * float(s) / 24.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	n.draw_polyline(pts, col, w, true)

## The lesson line, in the web's ink where the web chose one (label_col), else the kit's.
static func _label(n: CanvasItem, b: Dictionary, D: Dictionary) -> void:
	if D.get("label_col") != null:
		K.label(n, b, D.label, D.label_col)
	else:
		K.label(n, b, D.label)

## The camera glides toward where the last click asked it to look — it never jumps.
static func _glide(b: Dictionary, dt: float) -> void:
	b.cam += (b.aim - b.cam) * minf(1.0, dt * 3.0)

## A four-point fill with no triangulation step: draw_primitive splits the quad into two
## triangles itself, so a column that twists (a ripple smear) or dips under the card's
## floor still draws — draw_polygon would refuse the shape and print an error instead.
static func _quad(n: CanvasItem, a: Vector2, b2: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	n.draw_primitive(PackedVector2Array([a, b2, c, d]), PackedColorArray([col, col, col, col]), PackedVector2Array())

## A filled shape under a skyline: the curve sampled every 4 px, each sample a column
## down to the floor — the same picture as the web's one closed path, drawn as 55 quads.
static func _skyline(n: CanvasItem, b: Dictionary, floor_y: float, col: Color, y_at: Callable) -> void:
	var W: float = b.W
	var x := 0.0
	var y0: float = y_at.call(0.0)
	while x < W:
		var x1 := x + 4.0
		var y1: float = y_at.call(x1)
		_quad(n, Vector2(x, y0), Vector2(x1, y1), Vector2(x1, floor_y), Vector2(x, floor_y), col)
		x = x1; y0 = y1

## Alps: three sines summed = a jagged skyline. l is one ridge's dictionary.
static func _alps_ridge(b: Dictionary, l: Dictionary, x: float) -> float:
	var k: float = x / b.W
	var f: Array = l.f
	var ph: Array = l.ph
	var base: float = l.base
	var amp: float = l.amp
	return b.H * (base - amp * (0.55 * sin(k * f[0] * TAU + ph[0]) + 0.35 * absf(sin(k * f[1] * TAU + ph[1])) + 0.1 * sin(k * f[2] * TAU + ph[2])))

## Dunes: a rounded crest and a sharp trough — the sine raised to 1.6.
static func _dune_y(b: Dictionary, dn: Dictionary, x: float) -> float:
	var k: float = x / b.W
	var f: float = dn.f
	var ph: float = dn.ph
	var base: float = dn.base
	var amp: float = dn.amp
	var bump := pow(0.5 + 0.5 * sin(k * f * TAU + ph), 1.6)
	return b.H * (base - amp * bump)

## Fjord: two folded sines — every peak is a peak, no valleys below the base.
static func _fjord_ridge(b: Dictionary, l: Dictionary, x: float) -> float:
	var k: float = x / b.W
	var f: Array = l.f
	var ph: Array = l.ph
	var base: float = l.base
	var amp: float = l.amp
	return b.H * (base - amp * (0.6 * absf(sin(k * f[0] * TAU + ph[0])) + 0.4 * absf(sin(k * f[1] * TAU + ph[1]))))

## Knoll: one rolling sine per hill, always at or below its base.
static func _knoll_top(b: Dictionary, h: Dictionary, x: float) -> float:
	var f: float = h.f
	var ph: float = h.ph
	var base: float = h.base
	var amp: float = h.amp
	return b.H * (base - amp * (1.0 + sin((x / b.W) * f * TAU + ph)))

## Ridgeline: ONE shape, unit height, reused for every copy (b.f / b.ph are the card's).
static func _ridge_shape(b: Dictionary, x: float) -> float:
	var k: float = x / b.W
	var f: Array = b.f
	var ph: Array = b.ph
	return 0.5 * sin(k * f[0] * TAU + ph[0]) + 0.35 * absf(sin(k * f[1] * TAU + ph[1])) + 0.15 * sin(k * f[2] * TAU + ph[2])

static func defs() -> Array:
	var d: Array = []

	# ---- A · Alps ----------------------------------------------------------
	d.append({ "letter": "A", "name": "Alps",
		"hint": "six mountain silhouettes, each mixed toward the sky by depth — the far ones nearly dissolve; press slides the camera and the near ridge moves most",
		"dials": { "sky": [Color("5A82C8"), Color("C8DCEE")], "rock": Color("262A42"), "air": Color("B4C8E2"),   # the air is what far rock turns into
			"layers": 6, "jag": 1.0, "drift": 0.15, "seed": 7,
			"label": "same rock, more air: fog(rock, depth) — six shades of one colour is a mountain range" },
		"rhyme": { "name": "Neon ridges", "hint": "the same six ridges under a black sky, fogging toward cyan instead of blue — a synth poster from one changed colour",
			"dials": { "sky": [Color("050515"), Color("160E3A")], "rock": Color("2A0A4A"), "air": Color("3AF0E0"),
				"layers": 4, "drift": 0.6,
				"label": "the air can be any colour — fog toward cyan and the far ridges glow; the rule didn't change, the air did" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(int(D.seed))
			var layers: int = D.layers
			b.L = []
			for j in layers:                                              # j = 0 is the farthest ridge
				var depth := 1.0 - float(j) / (layers - 1) if layers > 1 else 0.0   # 1 = at the horizon, 0 = here
				b.L.append({ "depth": depth, "base": 0.36 + j * 0.085, "amp": (0.05 + j * 0.018) * float(D.jag),
					"f": [1.2 + R.randf() * 1.4, 2.6 + R.randf() * 2.4, 6.0 + R.randf() * 5.0],
					"ph": [R.randf() * 9.0, R.randf() * 9.0, R.randf() * 9.0] })
			b.cam = 0.0; b.aim = 0.0,
		"tick": func(b: Dictionary, dt: float) -> void: _glide(b, dt),
		"press": func(b: Dictionary, pos: Vector2) -> void: b.aim = (pos.x / b.W - 0.5) * 2.0,   # click = look left or right
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			K.sky(n, b, [[0.0, D.sky[0]], [0.65, D.sky[1]], [1.0, D.sky[1]]])
			for l in b.L:
				var near: float = 1.0 - l.depth
				var shift: float = (b.cam * 0.35 + t * D.drift * 0.03) * near * b.W   # parallax: near ridges slide farther
				var col := K.fog(D.rock, l.depth * 0.92, D.air)              # the depth IS the amount of air in front
				_skyline(n, b, b.H, col, func(x: float) -> float: return _alps_ridge(b, l, x + shift))
			_label(n, b, D) })

	# ---- C · Canyon --------------------------------------------------------
	d.append({ "letter": "C", "name": "Canyon",
		"hint": "cliff walls step in from both sides toward a bright far gap: each nearer pair is darker and warmer, and dust pools between them; press sets the dust",
		"dials": { "sky": [Color("6A90CC"), Color("F8E8C8")], "rock": Color("8A4630"), "air": Color("EED2A8"), "glow": Color("FFF6DC"),
			"dust": 1.0, "pairs": 6, "seed": 5,
			"label": "every step nearer takes away air and adds contrast — turn the dust up and the far walls go first" },
		"rhyme": { "name": "Ice canyon", "hint": "the same walls in four blues, thicker air — a minimalist print where the far gap is almost paper-white",
			"dials": { "sky": [Color("3A5A9A"), Color("EEF4FA")], "rock": Color("3A5A8A"), "air": Color("E8F0F8"), "glow": Color.WHITE,
				"dust": 1.5, "pairs": 4,
				"label": "four pairs instead of six: fewer, bigger steps in contrast — the recession reads as a print, not a photo" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(int(D.seed))
			var pairs: int = D.pairs
			b.walls = []
			for j in pairs:                                               # j = 0 is the farthest pair
				var p := float(j) / (pairs - 1) if pairs > 1 else 1.0      # 0 far … 1 near
				b.walls.append({ "p": p, "inner": 0.05 + p * p * 0.43, "top": 0.5 - p * 0.8, "bot": 0.6 + p * p * 0.5,
					"kink": (R.randf() - 0.5) * 0.06, "ledge": 0.25 + R.randf() * 0.45 }),   # kink: how far the edge leans; ledge: where it steps
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.dust = 0.2 + (pos.x / b.W) * 1.6,   # click right = a dustier day
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var W: float = b.W; var H: float = b.H
			var HY := H * 0.6
			var dust: float = D.dust
			K.sky(n, b, [[0.0, D.sky[0]], [0.58, D.sky[1]], [1.0, D.sky[1]]])
			K.soft(n, Vector2(W / 2.0, HY), W * 0.28, D.glow, 0.7)        # the gap glows: it is the far end, so it is the brightest
			K.lin_rect(n, Rect2(0, HY, W, H - HY), [K.fog(D.rock, 0.7, D.air), K.shade(D.rock, -0.5)])   # the floor fogs toward the far end too
			for w in b.walls:
				var p: float = w.p
				var c := K.fog(K.shade(D.rock, -p * 0.55), (1.0 - p) * 0.85 * dust, D.air)   # nearer: darker; farther: more air
				var top: float = H * w.top; var bot: float = H * w.bot
				for side in [-1.0, 1.0]:                                  # the same wall, mirrored
					var xi: float = W * (0.5 + side * w.inner); var xo: float = W * (0.5 + side * 0.6)
					K.poly(n, PackedVector2Array([Vector2(xo, top), Vector2(xi + side * w.kink * W, top), Vector2(xi, top + (bot - top) * w.ledge),
						Vector2(xi + side * w.kink * W * 0.5, bot), Vector2(xo, bot)]), c)
				# dust settles in front of each pair, thickest far back
				K.lin_rect(n, Rect2(0, H * 0.2, W, bot - H * 0.2), [[0.0, K.alpha(D.air, 0.0)], [1.0, K.alpha(D.air, 0.22 * dust * (1.0 - p))]])
			_label(n, b, D) })

	# ---- D · Dunes ---------------------------------------------------------
	d.append({ "letter": "D", "name": "Dunes",
		"hint": "dune crests stacked back to a pale horizon: each a horizontal gradient, lit side to shadow side, fading to peach with distance; press moves the sun",
		"dials": { "sky": [Color("6A9AD8"), Color("F5DDB8")], "sand": Color("D89A52"), "shade": Color("7A3E22"), "air": Color("F2D8B8"),
			"dunes": 7, "sun_x": 0.15, "seed": 9, "label_col": Color(0.16, 0.08, 0.04, 0.65),
			"label": "far dunes lose their shadow side first: fog eats contrast before it eats colour" },
		"rhyme": { "name": "Moon dunes", "hint": "the same dunes in greyscale under a black sky — no air, so the far ones fade DOWN into the dark instead of up into peach",
			"dials": { "sky": [Color("030306"), Color("16161E")], "sand": Color("A8A8A8"), "shade": Color("1A1A1E"), "air": Color("1E1E26"),
				"dunes": 4, "label_col": Color(0.04, 0.04, 0.055, 0.7),
				"label": "'fog' really means 'toward the background' — set the air to black and distance darkens instead of paling" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(int(D.seed))
			b.dunes = []
			for j in int(D.dunes):
				b.dunes.append({ "base": 0.45 + j * 0.07, "amp": 0.05 + j * 0.02, "f": 0.7 + R.randf() * 1.0, "ph": R.randf() * 9.0 }),
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.sun_x = pos.x / b.W,   # click = put the sun on that side
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			K.sky(n, b, [[0.0, D.sky[0]], [0.5, D.sky[1]], [1.0, D.sky[1]]])
			var from_left: bool = D.sun_x < 0.5
			var cnt: int = b.dunes.size()
			for j in cnt:
				var dn: Dictionary = b.dunes[j]
				var depth := 1.0 - float(j) / (cnt - 1) if cnt > 1 else 0.0
				var lit := K.fog(K.shade(D.sand, 0.18), depth * 0.85, D.air)   # both sides fog together
				var dark := K.fog(D.shade, depth * 0.85, D.air)
				var crest := 0.3 + 0.1 * sin(t * 0.3 + j * 1.3)              # the bright crest drifts slowly along the dune
				var stops := [[0.0, lit], [crest, K.shade(lit, 0.1)], [1.0, dark]]
				# the sideways gradient, one 4 px column at a time: lit toward the sun, shadow away from it
				var x := 0.0
				while x < W:
					var x1 := x + 4.0
					var c0 := _grad(stops, x / W if from_left else 1.0 - x / W)
					var c1 := _grad(stops, x1 / W if from_left else 1.0 - x1 / W)
					K.lin_poly(n, PackedVector2Array([Vector2(x, _dune_y(b, dn, x)), Vector2(x1, _dune_y(b, dn, x1)), Vector2(x1, H), Vector2(x, H)]),
						PackedColorArray([c0, c1, c1, c0]))
					x = x1
			_label(n, b, D) })

	# ---- F · Fjord ---------------------------------------------------------
	d.append({ "letter": "F", "name": "Fjord",
		"hint": "fogged mountain layers over still water, each mirrored below the line — the reflection darker and fading down under a gradient mask; press for wind",
		"dials": { "sky": [Color("7A9AC8"), Color("D8E4EE")], "rock": Color("2C3446"), "air": Color("C0D0E0"), "water": Color("1E2A3E"),
			"layers": 4, "wind": 0.3, "seed": 12,
			"label": "a reflection is the picture flipped, darkened, and faded by one vertical gradient — the fog comes along for free" },
		"rhyme": { "name": "Rose fjord", "hint": "the same fjord at a pink evening — rose air, plum rock, wine-dark water — and a breeze already on it",
			"dials": { "sky": [Color("E8A0B8"), Color("FFE4D0")], "rock": Color("5A3A5A"), "air": Color("F0C8D0"), "water": Color("4A2A48"),
				"wind": 1.2,
				"label": "warm the air and the fjord is an evening — the reflection follows for free, it is the same mask" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(int(D.seed))
			var layers: int = D.layers
			b.L = []
			for j in layers:
				b.L.append({ "base": 0.5 + j * 0.03, "amp": 0.1 + j * 0.06, "f": [1.0 + R.randf() * 1.2, 3.0 + R.randf() * 3.0],
					"ph": [R.randf() * 9.0, R.randf() * 9.0], "depth": (1.0 - float(j) / (layers - 1)) if layers > 1 else 0.0 }),
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.wind = 0.1 + (pos.x / b.W) * 2.5,   # click right = wind on the water
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			var WL := H * 0.6                                             # the waterline
			var wind: float = D.wind
			K.sky(n, b, [[0.0, D.sky[0]], [0.6, D.sky[1]], [1.0, D.sky[1]]])
			K.lin_rect(n, Rect2(0, WL, W, H - WL), [K.mix(D.sky[1], D.water, 0.3), D.water])
			for l in b.L:
				var c := K.fog(D.rock, l.depth * 0.9, D.air)
				_skyline(n, b, WL, c, func(x: float) -> float: return _fjord_ridge(b, l, x))
				# the reflection: the same ridge, flipped and darker — drawn as 4 px columns, because the
				# ripple smear can fold one big polygon over itself and Godot's triangulator would drop it
				var rc := K.shade(c, -0.25)
				var x := 0.0
				while x < W:
					var x1 := x + 4.0
					var y0 := 2.0 * WL - _fjord_ridge(b, l, x)
					var y1 := 2.0 * WL - _fjord_ridge(b, l, x1)
					var wob0 := sin(y0 * 0.25 + t * 2.5) * wind * 3.0 * ((y0 - WL) / H) * 10.0   # ripples smear it sideways, more the lower you look
					var wob1 := sin(y1 * 0.25 + t * 2.5) * wind * 3.0 * ((y1 - WL) / H) * 10.0
					_quad(n, Vector2(x, WL), Vector2(x1, WL), Vector2(x1 + wob1, y1), Vector2(x + wob0, y0), rc)
					x = x1
			# the mask: reflections fade the farther below the line
			K.lin_rect(n, Rect2(0, WL, W, H - WL), [[0.0, K.alpha(D.water, 0.1)], [1.0, K.alpha(D.water, 0.9)]])
			_label(n, b, D) })

	# ---- I · Icebergs ------------------------------------------------------
	d.append({ "letter": "I", "name": "Icebergs",
		"hint": "three rows of bergs over a mist band: the far row is smaller, paler, and bobs slower — one number z sets size, colour, and speed; press pans",
		"dials": { "sky": [Color("4A6A9A"), Color("C8D8E8")], "ice": Color("DCEAF5"), "sea": Color("2A4A6A"), "air": Color("B8C8D8"), "mist": Color.WHITE,
			"per_row": 5, "rows": 3, "seed": 21,
			"label": "z does three jobs at once — size, colour toward the air, and how fast it bobs — far things are slow" },
		"rhyme": { "name": "Lava islands", "hint": "the same three rows, values flipped — black rock on a bright lava sea, smoke for mist, seven to a row",
			"dials": { "sky": [Color("1A0808"), Color("5A1A10")], "ice": Color("241816"), "sea": Color("F5601A"), "air": Color("8A3020"), "mist": Color("FFB060"),
				"per_row": 7,
				"label": "dark on bright instead of bright on dark — z still runs the show: size, smoke, and speed" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(int(D.seed))
			var rows: int = D.rows; var per: int = D.per_row
			b.bergs = []
			for r in rows:                                                # r = 0 far … rows-1 near
				for i in per:
					var z := float(r) / (rows - 1) if rows > 1 else 1.0      # z: 0 far … 1 near
					var cnt := 5 + int(R.randf() * 3.0)
					var pts := []
					for k in cnt:                                         # a jagged lump, unit sized
						var u := float(k) / (cnt - 1)
						pts.append(Vector2(u * 2.0 - 1.0, -(0.2 + R.randf() * 0.8) * sin(u * PI)))
					b.bergs.append({ "z": z, "x": (i + R.randf() * 0.8) / per, "pts": pts, "ph": R.randf() * 9.0, "s": 0.5 + R.randf() * 0.7 })
			b.cam = 0.0; b.aim = 0.0,
		"tick": func(b: Dictionary, dt: float) -> void: _glide(b, dt),
		"press": func(b: Dictionary, pos: Vector2) -> void: b.aim = (pos.x / b.W - 0.5) * 2.0,   # click = pan; near rows slide most
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			var HY := H * 0.55
			var per: int = D.per_row
			K.sky(n, b, [[0.0, D.sky[0]], [0.55, D.sky[1]], [1.0, D.sky[1]]])
			K.lin_rect(n, Rect2(0, HY, W, H - HY), [K.mix(D.sea, D.air, 0.6), D.sea])   # the sea is paler at the horizon too
			var j := 0
			for bg in b.bergs:
				if j == per:                                              # after the far row: the mist band lies over it
					K.lin_rect(n, Rect2(0, HY - H * 0.06, W, H * 0.16),
						[[0.0, K.alpha(D.mist, 0.0)], [0.5, K.alpha(D.mist, 0.7)], [1.0, K.alpha(D.mist, 0.0)]])
				var z: float = bg.z
				var size: float = W * (0.03 + z * 0.09) * bg.s
				var y: float = HY + z * z * H * 0.32 + sin(t * (0.4 + z * 0.9) + bg.ph) * (0.5 + z * 2.5)   # near bergs bob faster and farther
				var x: float = bg.x * W + b.cam * (0.1 + z * 0.5) * W * 0.5
				var refl := PackedVector2Array(); var berg := PackedVector2Array()
				for p in bg.pts:
					refl.append(Vector2(x + p.x * size, y - p.y * size * 0.3))   # a squashed, flipped reflection first
					berg.append(Vector2(x + p.x * size, y + p.y * size))
				K.poly(n, refl, K.alpha(K.shade(D.ice, -0.5), 0.35))
				K.poly(n, berg, K.fog(D.ice, (1.0 - z) * 0.8, D.air))
				j += 1
			_label(n, b, D) })

	# ---- K · Knoll ---------------------------------------------------------
	d.append({ "letter": "K", "name": "Knoll",
		"hint": "rolling hills, each a gradient-filled sine, warm green near and blue-grey far — the sheep shrink with their hills; press pans the camera",
		"dials": { "sky": [Color("7AAAE0"), Color("DDE8F0")], "grass": Color("4A8A3A"), "air": Color("B8C8DC"), "sheep": Color("F5F2E8"),
			"hills": 6, "flock": 5, "step": 3.0, "seed": 33,               # step: how often the curve is sampled, in px
			"label": "a sheep is a dot with a depth: radius, colour, and wander all shrink with the hill it stands on" },
		"rhyme": { "name": "Pixel knoll", "hint": "the same hills sampled every 22 px — three chunky staircases in arcade green, two sheep each",
			"dials": { "sky": [Color("3A78F0"), Color("9AE0FF")], "grass": Color("3AC83A"), "air": Color("7AB8F0"), "sheep": Color.WHITE,
				"hills": 3, "flock": 2, "step": 22.0,
				"label": "sample the curve every 22 px and the hill is a staircase — chunkier steps, same fog toward the sky" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(int(D.seed))
			var hills: int = D.hills
			b.hills = []
			for j in hills:                                               # j = 0 is the farthest hill
				var h := { "base": 0.38 + j * 0.1, "amp": 0.03 + j * 0.012, "f": 0.8 + R.randf() * 1.2, "ph": R.randf() * 9.0,
					"depth": (1.0 - float(j) / (hills - 1)) if hills > 1 else 0.0, "sheep": [] }
				for s in int(D.flock): h.sheep.append([R.randf(), R.randf() * 9.0])   # where along the hill, and a wander phase
				b.hills.append(h)
			b.cam = 0.0; b.aim = 0.0,
		"tick": func(b: Dictionary, dt: float) -> void: _glide(b, dt),
		"press": func(b: Dictionary, pos: Vector2) -> void: b.aim = (pos.x / b.W - 0.5) * 2.0,   # click = pan the camera
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			var step: float = D.step
			K.sky(n, b, [[0.0, D.sky[0]], [0.6, D.sky[1]], [1.0, D.sky[1]]])
			for h in b.hills:
				var near: float = 1.0 - h.depth
				var shift: float = b.cam * near * W * 0.3                 # parallax by depth
				var c := K.fog(D.grass, h.depth * 0.85, D.air)
				var top_y: float = H * (h.base - h.amp * 2.0); var bot_y: float = H * (h.base + 0.1)
				var hi := K.shade(c, 0.2); var lo := K.shade(c, -0.25)      # lit at the crest, dark in the fold
				# the staircase: one flat-topped column per step, a vertical gradient crest → fold, flat below the fold
				var x := 0.0
				while x <= W:
					var y := _knoll_top(b, h, x + shift)
					var cy := hi.lerp(lo, clampf((y - top_y) / (bot_y - top_y), 0.0, 1.0))
					K.lin_poly(n, PackedVector2Array([Vector2(x, y), Vector2(x + step, y), Vector2(x + step, bot_y), Vector2(x, bot_y)]),
						PackedColorArray([cy, cy, lo, lo]))
					if bot_y < H:
						n.draw_rect(Rect2(x, bot_y, step, H - bot_y), lo)
					x += step
				for sh in h.sheep:                                        # sheep stand on the curve, so they inherit its depth
					var sx: float = sh[0] * W * 1.2 - W * 0.1 + sin(t * 0.2 + sh[1]) * 6.0 * near - shift
					var r := 0.8 + near * 2.4
					K.dot(n, Vector2(sx, _knoll_top(b, h, sx + shift) - r * 0.5), r, K.fog(D.sheep, h.depth * 0.7, D.air))
			_label(n, b, D) })

	# ---- M · Mesa ----------------------------------------------------------
	d.append({ "letter": "M", "name": "Mesa",
		"hint": "flat-topped rock stacks in rows that bunch toward the horizon — smaller, paler, closer together — shadows only at the near feet; press moves the sun",
		"dials": { "sky": [Color("5A8AD0"), Color("F2D9B0")], "rock": Color("B0603A"), "sand": Color("D8A870"), "air": Color("E8CDB0"),
			"rows": 6, "per_row": 3, "sun_x": 0.1, "seed": 17, "label_col": Color(0.16, 0.08, 0.04, 0.65),
			"label": "horizon + p²: the rows squeeze together as they recede, and the far ones lose their shadows to the air" },
		"rhyme": { "name": "Gumdrop mesa", "hint": "the same rock stacks in candy pink on a sugar plain — four rows, two to a row, the far ones melting into pink air",
			"dials": { "sky": [Color("8AD0FF"), Color("FFE8F0")], "rock": Color("F06AA8"), "sand": Color("F5D0E8"), "air": Color("FFE8F0"),
				"rows": 4, "per_row": 2, "label_col": Color(0.31, 0.08, 0.2, 0.6),
				"label": "candy or canyon, the rows still bunch as p² — the palette is a costume, the perspective is the body" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(int(D.seed))
			var rows: int = D.rows; var per: int = D.per_row
			b.mesas = []
			for r in rows:
				var p := float(r + 1) / rows                             # 0 far … 1 near (rows go far → near, painter's order)
				for i in per:
					b.mesas.append({ "p": p, "x": (i + 0.2 + R.randf() * 0.6) / per + (R.randf() - 0.5) * 0.1,
						"w": 0.7 + R.randf() * 0.6, "h": 0.6 + R.randf() * 0.8 }),
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.sun_x = pos.x / b.W,   # click = move the sun to that side
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var W: float = b.W; var H: float = b.H
			var HY := H * 0.48
			K.sky(n, b, [[0.0, D.sky[0]], [0.48, D.sky[1]], [1.0, D.sky[1]]])
			K.lin_rect(n, Rect2(0, HY, W, H - HY), [K.fog(D.sand, 0.8, D.air), D.sand])   # even the flat ground fogs toward the horizon
			var sun := 1.0 if D.sun_x < 0.5 else -1.0                      # +1: lit from the left
			for m in b.mesas:
				var p: float = m.p
				var y := HY + p * p * H * 0.48                           # p²: rows bunch up near the horizon
				var s := 0.12 + p * 0.88
				var w: float = W * 0.11 * s * m.w; var h: float = H * 0.14 * s * m.h; var x: float = m.x * W
				var c := K.fog(D.rock, (1.0 - p) * 0.9, D.air)
				if p > 0.5:                                               # a long shadow: only the near rows earn one
					K.shadow(n, Vector2(x + sun * w * 1.1, y - h * 0.04), w * 1.4, h * 0.2, 0.35 * (p - 0.5) * 2.0)
				K.poly(n, PackedVector2Array([Vector2(x - w, y), Vector2(x - w * 0.7, y - h), Vector2(x, y - h), Vector2(x, y)]),
					K.shade(c, 0.12 if sun > 0.0 else -0.3))              # lit half
				K.poly(n, PackedVector2Array([Vector2(x, y), Vector2(x, y - h), Vector2(x + w * 0.7, y - h), Vector2(x + w, y)]),
					K.shade(c, -0.3 if sun > 0.0 else 0.12))              # shadow half
			_label(n, b, D) })

	# ---- P · Pines ---------------------------------------------------------
	d.append({ "letter": "P", "name": "Pines",
		"hint": "rows of triangle trees: each row back is smaller, packed tighter, and mixed further into the fog — press moves the camera and the rows slide by depth",
		"dials": { "sky": [Color("8AA8C8"), Color("E4ECF2")], "pine": Color("16302A"), "air": Color("D0DCE6"), "rows": 6, "seed": 4, "label_col": null,
			"label": "size, spacing, colour, and parallax all come from the row's p — four cues, one number" },
		"rhyme": { "name": "Snow pines", "hint": "the same rows in snow light — slate trees, near-white air — eight rows deep, and the far ones are simply gone",
			"dials": { "sky": [Color("B8C8D8"), Color("F8FAFC")], "pine": Color("3A4A5A"), "air": Color("EEF2F6"), "rows": 8, "label_col": Color(0.12, 0.16, 0.2, 0.65),
				"label": "brighter air is stronger fog: with near-white air the back rows vanish in three steps instead of six" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(int(D.seed))
			var rows: int = D.rows
			var W: float = b.W
			b.rows = []
			for r in rows:
				var p := float(r) / (rows - 1) if rows > 1 else 1.0        # 0 far … 1 near
				var gap := W * (0.035 + p * p * 0.11)                    # near rows: wider gaps, fewer trees
				var cnt := int(ceil(W * 1.6 / gap))
				var trees := []
				for i in cnt: trees.append([i * gap + (R.randf() - 0.5) * gap * 0.6, 0.7 + R.randf() * 0.6])   # x, and a height wobble
				b.rows.append({ "p": p, "trees": trees, "period": cnt * gap })
			b.cam = 0.0; b.aim = 0.0,
		"tick": func(b: Dictionary, dt: float) -> void: _glide(b, dt),
		"press": func(b: Dictionary, pos: Vector2) -> void: b.aim = (pos.x / b.W - 0.5) * 2.0,   # click = pan; the near row runs, the far row crawls
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var W: float = b.W; var H: float = b.H
			var HY := H * 0.42
			K.sky(n, b, [[0.0, D.sky[0]], [0.5, D.sky[1]], [1.0, D.sky[1]]])
			K.lin_rect(n, Rect2(0, HY, W, H - HY), [D.air, K.shade(D.air, -0.2)])
			for row in b.rows:
				var p: float = row.p
				var y := HY + p * p * H * 0.55                           # p²: the ground lines bunch toward the horizon
				var hgt := H * (0.03 + p * p * 0.42); var half := hgt * 0.32
				var c := K.fog(D.pine, (1.0 - p) * 0.9, D.air)
				var shift: float = b.cam * p * W * 0.35                    # near rows slide farthest
				var period: float = row.period
				# a breath of ground haze under each row
				K.lin_rect(n, Rect2(0, y - 4.0, W, 12.0), [[0.0, K.alpha(D.air, 0.0)], [1.0, K.alpha(D.air, 0.5 * (1.0 - p))]])
				for tr in row.trees:
					var x: float = fposmod(tr[0] + shift, period) - W * 0.3
					var h: float = hgt * tr[1]
					K.poly(n, PackedVector2Array([Vector2(x - half, y), Vector2(x, y - h), Vector2(x + half, y)]), c)
			_label(n, b, D) })

	# ---- Q · Quay ----------------------------------------------------------
	d.append({ "letter": "Q", "name": "Quay",
		"hint": "harbour posts marching to a vanishing point: spacing shrinks as p², heights shrink with it, colour fogs, ripples only near; press moves the point",
		"dials": { "sky": [Color("3A4A7A"), Color("E8B890")], "water": Color("22304A"), "post": Color("3A2A1E"), "air": Color("C8A898"), "glow": Color("FFD9A0"),
			"posts": 14, "jitter": 0.0, "vp_x": 0.62,                     # jitter: 0 = still posts
			"label": "horizon + p²: the same step in p is a smaller step on screen the farther back you go — perspective in one line" },
		"rhyme": { "name": "Glitch quay", "hint": "the same posts in neon on black water, shaking — the jitter is scaled by the same p² as everything else, so the near ones shake most",
			"dials": { "sky": [Color("0A0A1A"), Color("2A1050")], "water": Color("08101A"), "post": Color("20F0D0"), "air": Color("5A2A9A"), "glow": Color("F040C0"),
				"jitter": 1.0,
				"label": "even the glitch obeys perspective: shake × p² — far posts barely tremble, near ones rattle" } },
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.vp_x = pos.x / b.W,   # click = move the vanishing point
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			var HY := H * 0.45
			var posts: int = D.posts
			var jitter: float = D.jitter
			var vpx: float = D.vp_x
			K.sky(n, b, [[0.0, D.sky[0]], [0.45, D.sky[1]], [1.0, D.sky[1]]])
			K.lin_rect(n, Rect2(0, HY, W, H - HY), [K.mix(D.sky[1], D.water, 0.4), D.water])
			K.soft(n, Vector2(W * vpx, HY), W * 0.25, D.glow, 0.35)       # the sun sits on the vanishing point
			for i in posts:
				var p := float(i) / (posts - 1) if posts > 1 else 1.0       # p: 0 far … 1 near; q bunches the far posts together
				var q := p * p
				var x := lerpf(W * vpx, W * 0.12, q) + sin(t * 40.0 + i * 7.0) * jitter * 6.0 * q
				var y := HY + q * H * 0.55
				var h := 2.0 + q * H * 0.36; var w := 1.0 + q * 7.0
				var c := K.fog(D.post, (1.0 - q) * 0.9, D.air)
				n.draw_rect(Rect2(x - w / 2.0, y, w, h * 0.5), K.alpha(c, 0.35))   # reflection: a faint stub straight down
				K.cyl(n, x, y, w, h, c, -0.4)
				if q > 0.3:                                               # ripples: rings born at the foot, fading as they grow
					for k in 3:
						var g := fposmod(t * 0.5 + k / 3.0 + i * 0.13, 1.0)
						_ring(n, Vector2(x, y + 1.0), (0.5 + g * 3.0) * w, (0.5 + g * 3.0) * w * 0.3, Color(1, 1, 1, (1.0 - g) * 0.35 * q))
			_label(n, b, D) })

	# ---- R · Ridgeline -----------------------------------------------------
	d.append({ "letter": "R", "name": "Ridgeline",
		"hint": "one ridge drawn four times, deeper each time, contrast falling — near is nearly black, far is nearly sky; press turns the fog off and the depth goes",
		"dials": { "sky": [Color("6A88B8"), Color("E0E8F0")], "rock": Color("14161E"), "air": Color("C4D2E0"), "copies": 4, "seed": 2,
			"base_step": 0.12, "amp_step": 0.03,                          # how far each copy drops, and how much taller it gets
			"label": "fog on: four ridges, each a step farther into the air — press to switch it off",
			"label_off": "fog off: the same four shapes read as ONE black cut-out — the depth WAS the contrast" },
		"rhyme": { "name": "Acid ridgeline", "hint": "the same ridge seven times, violet rock fogging toward lime under a hot-pink sky — the contrast ladder, in a trippy key",
			"dials": { "sky": [Color("F0F040"), Color("FF60C0")], "rock": Color("2A0A5A"), "air": Color("40FFC0"), "copies": 7,
				"base_step": 0.07, "amp_step": 0.02,
				"label": "seven copies: the contrast steps down one notch per copy — that ladder is the depth, whatever the hues",
				"label_off": "fog off: seven shapes, one violet cut-out — the ladder is gone and so is the distance" } },
		"init": func(b: Dictionary) -> void:
			var R := K.rng(int(b.D.seed))
			b.f = [1.1 + R.randf() * 0.8, 2.7 + R.randf() * 1.5, 7.0 + R.randf() * 4.0]   # one shape, reused for every copy
			b.ph = [R.randf() * 9.0, R.randf() * 9.0, R.randf() * 9.0]
			b.fog_on = true,
		"press": func(b: Dictionary, _pos: Vector2) -> void: b.fog_on = not b.fog_on,   # click = toggle the air
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			var copies: int = D.copies
			K.sky(n, b, [[0.0, D.sky[0]], [0.6, D.sky[1]], [1.0, D.sky[1]]])
			for j in copies:                                              # j = 0 farthest
				var depth := 1.0 - float(j) / (copies - 1) if copies > 1 else 0.0
				var base: float = 0.45 + j * D.base_step; var amp: float = 0.09 + j * D.amp_step
				var shift: float = j * W * 0.23 + t * 2.0 * (1.0 - depth)     # the same shape slid along — and creeping, faster when near
				var col: Color = K.fog(D.rock, depth * 0.9, D.air) if b.fog_on else D.rock   # the whole lesson is this one line
				_skyline(n, b, H, col, func(x: float) -> float: return H * (base - amp * _ridge_shape(b, x + shift)))
			K.label(n, b, D.label if b.fog_on else D.label_off) })

	# ---- S · Skyline -------------------------------------------------------
	d.append({ "letter": "S", "name": "Skyline",
		"hint": "a city in three planes: the far one pale, flat, and slow; the near one dark with lit windows — colour, speed, and detail from one z; press pans",
		"dials": { "sky": [Color("1A1E4A"), Color("7A4A7A"), Color("F5A070")], "tower": Color("1A1828"), "air": Color("9A7090"), "window": Color("F5C169"),
			"per_plane": 12, "max_h": 0.55, "seed": 44,
			"label": "three planes, one z: colour toward the air, speed, and detail all fall off together — windows are a near-only luxury" },
		"rhyme": { "name": "Cozy village", "hint": "the same three planes, half as many buildings at a third of the height, lit warm — a village at dusk instead of a city",
			"dials": { "sky": [Color("2A2A5A"), Color("8A5A7A"), Color("F5B080")], "tower": Color("3A2A2A"), "air": Color("B08A98"), "window": Color("FFD080"),
				"per_plane": 6, "max_h": 0.2,
				"label": "shorter, fewer, warmer: scale is a dial and the depth recipe is untouched — a village is a small city" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(int(D.seed))
			var W: float = b.W; var H: float = b.H
			var per: int = D.per_plane
			var max_h: float = D.max_h
			var period := W * 1.5
			b.B = []
			for pl in 3:                                                  # pl = 0 far … 2 near
				for i in per:
					var z := pl / 2.0
					var w := W * (0.035 + z * 0.05) * (0.6 + R.randf() * 0.8)
					var h := H * max_h * (0.3 + z * 0.7) * (0.5 + R.randf() * 0.5)
					var bd := { "z": z, "x": (i + R.randf() * 0.7) / per * period, "w": w, "h": h, "win": [] }
					if pl == 2:                                           # only the near plane is close enough to show windows
						var wx := 3.0
						while wx < w - 3.0:
							var wy := 4.0
							while wy < h - 3.0:
								if R.randf() < 0.55: bd.win.append(Vector2(wx, wy))
								wy += H * 0.03
							wx += W * 0.014
					b.B.append(bd)
			b.cam = 0.0; b.aim = 0.0,
		"tick": func(b: Dictionary, dt: float) -> void: _glide(b, dt),
		"press": func(b: Dictionary, pos: Vector2) -> void: b.aim = (pos.x / b.W - 0.5) * 2.0,   # click = pan the camera
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			var GY := H * 0.88
			var period := W * 1.5
			K.sky(n, b, [[0.0, D.sky[0]], [0.55, D.sky[1]], [0.88, D.sky[2]], [1.0, D.sky[2]]])
			var i := 0
			for bd in b.B:
				var z: float = bd.z
				var base := GY - (1.0 - z) * H * 0.05                    # far planes stand a little higher: nearer the horizon
				var x: float = fposmod(bd.x + b.cam * (0.1 + z * 0.4) * W + t * (1.0 + z * 6.0), period) - W * 0.25   # the near plane slides six times faster
				var h: float = bd.h
				n.draw_rect(Rect2(x, base - h, bd.w, h), K.fog(D.tower, (1.0 - z) * 0.85, D.air))
				var k := 0
				for wn in bd.win:                                         # each window on its own dimmer
					n.draw_rect(Rect2(x + wn.x, base - h + wn.y, W * 0.007, H * 0.014), K.alpha(D.window, 0.55 + 0.4 * sin(t * 0.8 + k * 1.7 + i)))
					k += 1
				i += 1
			K.ground(n, b, GY, Color("0A0A14"))
			_label(n, b, D) })

	# ---- V · Valley --------------------------------------------------------
	d.append({ "letter": "V", "name": "Valley",
		"hint": "two slopes meet in a V, five pairs deep: mist pools in the bottom as a soft band and the far end is the brightest thing; press sets the mist level",
		"dials": { "sky": [Color("8AA8D0"), Color("F5EAD8")], "hill": Color("243E30"), "air": Color("D8DAD4"), "mist": Color("F0F0F4"), "glow": Color("FFF8E8"),
			"pairs": 5, "mist_y": 0.62, "seed": 6,                        # mist_y: where the mist's surface sits
			"label": "mist is fog that pooled: a gradient band the near slopes rise out of and the far ones sink into" },
		"rhyme": { "name": "Ember valley", "hint": "the same V under a smoke sky, with glowing orange mist pooled deep in the bottom — the far end burns instead of shining",
			"dials": { "sky": [Color("2A0A10"), Color("7A2A18")], "hill": Color("1A0A08"), "air": Color("7A3020"), "mist": Color("FF8A30"), "glow": Color("FFB060"),
				"mist_y": 0.7,
				"label": "fog can glow: the mist band is the same gradient, only now it is brighter than what is behind it" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(int(D.seed))
			var pairs: int = D.pairs
			b.P = []
			for j in pairs:
				var p := float(j) / (pairs - 1) if pairs > 1 else 1.0      # 0 far … 1 near
				b.P.append({ "p": p, "edge_y": 0.36 * (1.0 - pow(p, 1.5)), "notch_y": 0.55 + p * 0.5,   # near arms start higher and dive deeper
					"bump": 0.02 + R.randf() * 0.06, "at": 0.3 + R.randf() * 0.3 }),   # a shoulder on the slope, and where it sits
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.mist_y = clampf(pos.y / b.H, 0.45, 0.9),   # click = set the mist's surface by y
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var W: float = b.W; var H: float = b.H
			K.sky(n, b, [[0.0, D.sky[0]], [0.55, D.sky[1]], [1.0, D.sky[1]]])
			K.soft(n, Vector2(W / 2.0, H * 0.52), W * 0.3, D.glow, 0.7)   # the far end: the brightest thing in the picture
			var mist_at := int(floor(float(D.pairs) * 0.6))
			var j := 0
			for s in b.P:
				var p: float = s.p
				var c := K.fog(D.hill, (1.0 - p) * 0.9, D.air)
				if j == mist_at:                                          # mist pools in the bottom, between the far and the near pairs
					var my: float = H * D.mist_y
					K.lin_rect(n, Rect2(0, my - H * 0.16, W, H - (my - H * 0.16)),
						[[0.0, K.alpha(D.mist, 0.0)], [0.45, K.alpha(D.mist, 0.8)], [1.0, K.alpha(D.mist, 0.4)]])
				var ey: float = s.edge_y; var ny: float = s.notch_y; var at: float = s.at; var bump: float = s.bump
				var floor_y := maxf(H + 2.0, H * ny + 2.0)               # the near notch dives past the card; keep the base below it (off-card either way)
				for side in 2:                                            # the same slope, mirrored about the centre
					var m := -1.0 if side == 1 else 1.0
					var o := W if side == 1 else 0.0
					K.poly(n, PackedVector2Array([Vector2(o - m * 2.0, H * ey), Vector2(o + m * at * W * 0.5, H * (lerpf(ey, ny, at) - bump)),
						Vector2(o + m * (W * 0.5 + 1.0), H * ny), Vector2(o + m * (W * 0.5 + 1.0), floor_y), Vector2(o - m * 2.0, floor_y)]), c)
				j += 1
			_label(n, b, D) })

	# ---- W · Woodland ------------------------------------------------------
	d.append({ "letter": "W", "name": "Woodland",
		"hint": "trunks at random depths, sorted far to near: the near ones wide, dark, and sharp; the far ones thin and pale behind a low ground fog; press pans",
		"dials": { "sky": [Color("1E3A2E"), Color("8AA890")], "bark": Color("2A1E16"), "air": Color("9AB0A0"), "fog": Color("C8D8CC"),
			"trees": 28, "tall": 1.1, "cap": null, "seed": 8,             # cap: a colour turns every trunk into a mushroom
			"label": "sort by z, draw far first: width, darkness, and sharpness all grow toward you — the fog sits where z is small" },
		"rhyme": { "name": "Mushroom wood", "hint": "the same trunks, pale and half as tall, each wearing a red cap — one dial turns a forest into a fairy ring in violet fog",
			"dials": { "sky": [Color("1A1030"), Color("4A3A6A")], "bark": Color("E8D8C0"), "air": Color("6A5A8A"), "fog": Color("8A70B0"),
				"tall": 0.45, "cap": Color("E04A4A"),
				"label": "a cap is one branch; the fog is the same — the far caps go violet before you can tell they were red" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(int(D.seed))
			b.T = []
			for i in int(D.trees): b.T.append({ "x": R.randf(), "z": R.randf() })
			b.T.sort_custom(func(p, q): return p.z < q.z)                 # far first — painter's order
			b.cam = 0.0; b.aim = 0.0,
		"tick": func(b: Dictionary, dt: float) -> void: _glide(b, dt),
		"press": func(b: Dictionary, pos: Vector2) -> void: b.aim = (pos.x / b.W - 0.5) * 2.0,   # click = pan the camera
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var W: float = b.W; var H: float = b.H
			var HY := H * 0.4
			var tall: float = D.tall
			K.sky(n, b, [[0.0, D.sky[0]], [0.55, D.sky[1]], [1.0, K.shade(D.sky[1], -0.3)]])
			var fogged := false
			for tr in b.T:
				var z: float = tr.z                                       # 0 far … 1 near
				if not fogged and z > 0.45:                               # the ground fog lies between the far and the near trunks
					fogged = true
					K.lin_rect(n, Rect2(0, HY - H * 0.05, W, H - (HY - H * 0.05)),
						[[0.0, K.alpha(D.fog, 0.0)], [0.35, K.alpha(D.fog, 0.75)], [1.0, K.alpha(D.fog, 0.3)]])
				var y := HY + z * z * H * 0.62
				var h := H * (0.2 + z * z * tall)
				var w := 1.5 + z * z * W * 0.07
				var x: float = (tr.x - 0.5) * W * 1.3 + W / 2.0 + b.cam * (0.05 + z * 0.4) * W   # parallax: near trunks slide most
				var c := K.fog(D.bark, (1.0 - z) * 0.9, D.air)
				K.cyl(n, x, y, w, h, c, -0.4)
				if D.cap != null:                                         # the rhyme's one branch: a fogged ball on every trunk
					K.sphere(n, Vector2(x, y - h), w * 1.6 + 3.0, K.fog(D.cap, (1.0 - z) * 0.9, D.air), -0.5, -0.6)
			_label(n, b, D) })

	return d
