extends RefCounted
## SKIES & HORIZONS — 12 pictures, ported from the web atlas (docs/depth.js).
## A vertical gradient is the oldest depth trick there is: the sky is darker
## straight up (less air) and paler at the horizon (you look through more of
## it). Move the colours and the same gradient becomes a clock — night, dawn,
## noon, dusk — or a weather report.
##
## Each def: letter, name, hint, dials (D), rhyme { name, hint, dials } and
## the callables init(b) / tick(b, dt) / press(b, pos) / draw(n, b). The
## rhyme's dials are merged over D on right-click — nothing else changes.

const K := preload("res://scenes/depth/kit.gd")

const TITLE := "Skies & horizons"
const BLURB := "a vertical gradient is a clock and a compass — sunrise, dusk, weather, and the colour of air"

static func _pal(i: int, D: Dictionary, key: String, f: float) -> Color:
	var arr: Array = D[key]
	return K.mix(arr[i], arr[mini(i + 1, arr.size() - 1)], f)

static func defs() -> Array:
	var d: Array = []

	# ---- A · Aurora --------------------------------------------------------
	d.append({ "letter": "A", "name": "Aurora",
		"hint": "curtains of light: one thin vertical gradient per strip, its top and bottom riding slow sines — colour is position, motion is phase",
		"dials": { "sky0": Color("07071A"), "sky1": Color("0E1230"), "hi": Color("5AF0AA"), "lo": Color("9A5AF0"),
			"strips": 48, "speed": 0.35, "glow": 0.7,
			"label": "one gradient per strip — the curtain is 48 gradients standing side by side" },
		"rhyme": { "name": "Glitch aurora", "hint": "the same curtains in magenta and cyan, 16 fat strips instead of 48, three times the speed — coarse and twitchy",
			"dials": { "hi": Color("40F0F0"), "lo": Color("F040C0"), "strips": 16, "speed": 1.1, "glow": 0.8,
				"label": "fewer strips = the same gradients, now visible as bars — the seams become the style" } },
		"init": func(b: Dictionary) -> void:
			var R := K.rng(3)
			b.stars = []
			for j in 40: b.stars.append(Vector3(R.randf() * b.W, R.randf() * b.H * 0.7, 0.4 + R.randf() * 1.1)),
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.D.speed = 0.15 + (pos.x / b.W) * 1.2,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			K.sky(n, b, [D.sky0, D.sky1])
			var j := 0
			for s in b.stars:
				K.dot(n, Vector2(s.x, s.y), s.z, K.alpha(K.INK, 0.35 + 0.35 * sin(t * 2.0 + j))); j += 1
			var strips: int = D.strips
			var sw: float = b.W / strips
			for i in strips:
				var k := float(i) / strips
				var top: float = b.H * (0.16 + 0.08 * sin(k * 5.0 + t * D.speed * 2.0) + 0.04 * sin(k * 11.0 - t * D.speed * 3.0))
				var bot: float = b.H * (0.62 + 0.05 * sin(k * 3.0 + t * D.speed))
				var a: float = D.glow * (0.5 + 0.45 * sin(k * 9.0 + t * D.speed * 4.0))
				K.lin_rect(n, Rect2(i * sw, top, sw + 1.0, bot - top),
					[[0.0, K.alpha(D.lo, 0.0)], [0.35, K.alpha(D.lo, a * 0.8)], [0.7, K.alpha(D.hi, a)], [1.0, K.alpha(D.hi, 0.0)]])
			K.ground(n, b, b.H * 0.86, Color("04040C"))
			K.label(n, b, D.label) })

	# ---- B · Bluehour ------------------------------------------------------
	d.append({ "letter": "B", "name": "Bluehour",
		"hint": "the twenty minutes after sunset: indigo above, a warm sliver at the horizon, and stars arriving one by one as the gradient darkens",
		"dials": { "top": Color("0B0F3A"), "mid": Color("2A3F8F"), "horizon": Color("E8A07A"), "ground": Color("06060F"),
			"minutes": 14.0, "stars": 70,
			"label": "the warm sliver is the sun, below the horizon, still lighting the air above it" },
		"rhyme": { "name": "Alien bluehour", "hint": "the same dusk under a green sky with a copper horizon, twice as many stars, and the hour over in six seconds",
			"dials": { "top": Color("0A2A1A"), "mid": Color("2A7A5A"), "horizon": Color("E89A5A"), "minutes": 6.0, "stars": 140,
				"label": "a sky is a palette: change three hex codes and you are on another planet" } },
		"init": func(b: Dictionary) -> void:
			var R := K.rng(11)
			b.stars = []
			for j in int(b.D.stars): b.stars.append([R.randf() * b.W, R.randf() * b.H * 0.75, 0.4 + R.randf() * 1.0, R.randf()]),
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.D.minutes = 4.0 + (pos.x / b.W) * 24.0,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var k: float = clampf(fmod(t, D.minutes * 1.4) / D.minutes, 0.0, 1.0)
			var top := K.mix(D.top, Color("030312"), k)
			var mid := K.mix(D.mid, Color("0B1040"), k)
			var hor := K.mix(D.horizon, Color("3A2A4F"), k)
			K.sky(n, b, [[0.0, top], [0.55, mid], [0.86, hor], [1.0, K.mix(hor, D.ground, 0.5)]])
			var j := 0
			for s in b.stars:
				var born: float = s[3] * 0.9
				if k > born:
					K.dot(n, Vector2(s[0], s[1]), s[2], K.alpha(K.INK, clampf((k - born) * 6.0, 0.0, 0.9) * (0.6 + 0.4 * sin(t * 3.0 + j))))
				j += 1
			var W: float = b.W; var H: float = b.H
			K.poly(n, PackedVector2Array([Vector2(0, H * 0.86), Vector2(W * 0.2, H * 0.78), Vector2(W * 0.45, H * 0.83),
				Vector2(W * 0.7, H * 0.76), Vector2(W, H * 0.82), Vector2(W, H), Vector2(0, H)]), D.ground)
			K.label(n, b, D.label) })

	# ---- D · Dawn ----------------------------------------------------------
	d.append({ "letter": "D", "name": "Dawn",
		"hint": "sunrise as a clock: four palette keyframes for the top and four for the horizon, mixed by time — the sun is just a disc that climbs while the colours change",
		"dials": { "tops": [Color("05051A"), Color("2A1E5A"), Color("5A7FD0"), Color("6FA8E8")],
			"hors": [Color("1A1030"), Color("C2507A"), Color("F5A15A"), Color("CFE6F5")],
			"length": 16.0, "sun_size": 0.09, "sea": true,
			"label": "mix(keyframe[i], keyframe[i+1], f) — the whole sunrise is one lerp between palettes" },
		"rhyme": { "name": "Candy dawn", "hint": "the same sunrise in pastel — mint to peach to cream — a sun twice as big, and no sea",
			"dials": { "tops": [Color("3A2A5A"), Color("8A6AB8"), Color("A8D8C8"), Color("BFE8F5")],
				"hors": [Color("5A3A6A"), Color("F5A0B8"), Color("FFD0A0"), Color("FFF3E0")], "sun_size": 0.18, "sea": false,
				"label": "desaturate the keyframes and the same sunrise turns cozy — palette is genre" } },
		"init": func(b: Dictionary) -> void: b.scrub = -1.0,
		"press": func(b: Dictionary, pos: Vector2) -> void: b.scrub = pos.x / b.W,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var k: float = b.scrub if b.scrub >= 0.0 else (0.5 - 0.5 * cos((t / D.length) * PI))
			var seg := clampf(k * 3.0, 0.0, 2.999)
			var i := int(seg); var f := seg - i
			var top := _pal(i, D, "tops", f); var hor := _pal(i, D, "hors", f)
			var GY: float = b.H * 0.72
			K.sky(n, b, [[0.0, top], [0.7, hor], [1.0, hor]])
			var sy: float = GY + b.H * 0.12 - k * b.H * 0.45
			var sx: float = b.W * 0.62
			var r: float = b.W * D.sun_size
			K.soft(n, Vector2(sx, sy), r * 5.0, Color("FFD9A0"), 0.25 + k * 0.25)
			if sy - r < GY:                                   # the disc; the sea/meadow drawn next
				K.radial(n, Vector2(sx, sy), r, [Color("FFF3D0"), Color("FFC879")])   # covers what dips below
			if D.sea:
				K.lin_rect(n, Rect2(0, GY, b.W, b.H - GY), [K.shade(hor, -0.35), K.shade(top, -0.5)])
				n.draw_set_transform(Vector2(sx, GY), 0.0, Vector2(1.0, (b.H - GY) / (r * 1.6)))
				K.soft(n, Vector2.ZERO, r * 1.6, Color("FFD9A0"), 0.55 * clampf(1.4 - k, 0.0, 1.0))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				K.lin_rect(n, Rect2(0, GY, b.W, b.H - GY), [K.shade(hor, -0.15), K.shade(hor, -0.45)])
			K.label(n, b, D.label) })

	# ---- E · Eventide ------------------------------------------------------
	d.append({ "letter": "E", "name": "Eventide",
		"hint": "sunset is dawn played backwards with a redder palette — and an afterglow band that outlives the sun",
		"dials": { "tops": [Color("5A8FD8"), Color("3A4A9A"), Color("2A1E4A"), Color("08081C")],
			"hors": [Color("B8D8F5"), Color("F58A5A"), Color("C2507A"), Color("2A1A3A")],
			"length": 16.0, "sun_size": 0.09, "afterglow": Color("F5C169"), "floor": Color("06060F"),
			"label": "same clock as Dawn, keyframes reversed — a sunset is a data change, not a new program" },
		"rhyme": { "name": "Desert eventide", "hint": "the same sunset over sand — ochre and rust palette, a huge low sun, and a copper afterglow",
			"dials": { "tops": [Color("8AAED8"), Color("C8785A"), Color("5A2A3A"), Color("0A0810")],
				"hors": [Color("F5D9B0"), Color("F5A15A"), Color("B85A3A"), Color("2A1A1A")],
				"sun_size": 0.16, "afterglow": Color("F58A5A"), "floor": Color("1A0E0A"),
				"label": "a bigger disc and a warmer ramp: the sun 'nearer' the ground reads as hotter and heavier" } },
		"init": func(b: Dictionary) -> void: b.scrub = -1.0,
		"press": func(b: Dictionary, pos: Vector2) -> void: b.scrub = pos.x / b.W,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var k: float = b.scrub if b.scrub >= 0.0 else (0.5 - 0.5 * cos((t / D.length) * PI))
			var seg := clampf(k * 3.0, 0.0, 2.999)
			var i := int(seg); var f := seg - i
			var top := _pal(i, D, "tops", f); var hor := _pal(i, D, "hors", f)
			var GY: float = b.H * 0.72
			K.sky(n, b, [[0.0, top], [0.7, hor], [1.0, hor]])
			var glow := sin(clampf(k, 0.0, 1.0) * PI)
			K.lin_rect(n, Rect2(0, GY - b.H * 0.2, b.W, b.H * 0.2), [K.alpha(D.afterglow, 0.0), K.alpha(D.afterglow, glow * 0.6)])
			var sy: float = GY - b.H * 0.4 + k * b.H * 0.52
			var sx: float = b.W * 0.38
			var r: float = b.W * D.sun_size * (1.0 + k * 0.25)
			K.soft(n, Vector2(sx, minf(sy, GY)), r * 5.0, Color("FFB070"), 0.3 * (1.0 - k * 0.6))
			K.radial(n, Vector2(sx, sy), r, [Color("FFE9B0"), Color("FF8A50")])
			K.lin_rect(n, Rect2(0, GY, b.W, b.H - GY), [K.shade(hor, -0.4), D.floor])
			K.label(n, b, D.label) })

	# ---- G · Goldenhour ----------------------------------------------------
	d.append({ "letter": "G", "name": "Goldenhour",
		"hint": "a low sun paints everything on one side gold and the other side violet — the hills are HORIZONTAL gradients from lit to shadowed",
		"dials": { "sky0": Color("3A3F8F"), "sky1": Color("E8A868"), "sky2": Color("FFD9A0"), "lit": Color("F5C169"), "shade": Color("3A2A5A"),
			"sun": Color("FFF3D0"), "hills": 4, "sun_x": 0.12,
			"label": "light has a direction: a horizontal gradient from gold to violet tells the eye where the sun is" },
		"rhyme": { "name": "Silver hour", "hint": "the same low light in greyscale — a white sun, eight thin hills, a minimalist print",
			"dials": { "sky0": Color("3A3A44"), "sky1": Color("8A8A96"), "sky2": Color("D8D8E0"), "lit": Color("E8E8F0"), "shade": Color("22222A"),
				"sun": Color.WHITE, "hills": 8,
				"label": "remove the hue and the depth is still there — value does the work, colour is decoration" } },
		"init": func(b: Dictionary) -> void:
			var R := K.rng(21)
			b.hills = []
			var nh: int = b.D.hills
			for j in nh:
				b.hills.append({ "y": 0.5 + j * 0.42 / nh, "amp": 0.03 + R.randf() * 0.04, "ph": R.randf() * 9.0, "f": 1.5 + R.randf() * 2.0 }),
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.sun_x = pos.x / b.W,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			K.sky(n, b, [[0.0, D.sky0], [0.6, D.sky1], [1.0, D.sky2]])
			var sx: float = b.W * D.sun_x
			var sy: float = b.H * 0.46
			K.soft(n, Vector2(sx, sy), b.W * 0.5, Color("FFD9A0"), 0.35)
			K.dot(n, Vector2(sx, sy), b.W * 0.05, D.sun)
			var nh: int = b.hills.size()
			for j in nh:
				var h: Dictionary = b.hills[j]
				var depth := 1.0 - float(j) / nh
				var a := K.mix(D.lit, D.sky1, depth * 0.5)
				var c := K.mix(D.shade, D.sky0, depth * 0.4)
				# the hill as a strip of gradient quads: lit toward the sun, shadowed away from it
				var steps := 24
				for s in steps:
					var x0: float = b.W * s / steps; var x1: float = b.W * (s + 1) / steps
					var y0: float = b.H * (h.y + sin(x0 / b.W * h.f * TAU + h.ph + t * 0.05) * h.amp)
					var y1: float = b.H * (h.y + sin(x1 / b.W * h.f * TAU + h.ph + t * 0.05) * h.amp)
					var k0 := clampf((x0 - sx) / (b.W - sx + 0.001), 0.0, 1.0)
					var k1 := clampf((x1 - sx) / (b.W - sx + 0.001), 0.0, 1.0)
					K.lin_poly(n, PackedVector2Array([Vector2(x0, y0), Vector2(x1, y1), Vector2(x1, b.H), Vector2(x0, b.H)]),
						PackedColorArray([K.mix(a, c, k0), K.mix(a, c, k1), K.mix(a, c, k1), K.mix(a, c, k0)]))
			K.label(n, b, D.label) })

	# ---- H · Haze ----------------------------------------------------------
	d.append({ "letter": "H", "name": "Haze",
		"hint": "heat haze: the horizon band is cut into thin slices and each slice slides sideways on a sine — the shimmer grows toward the ground",
		"dials": { "sky0": Color("3A6FD0"), "sky1": Color("9FC8F0"), "sky2": Color("F5E1B0"), "sand": Color("D9A86A"), "far": Color("B9A8C8"),
			"heat": 1.0, "slices": 26,
			"label": "distortion by slicing — no shader, just rows that disagree about where they are" },
		"rhyme": { "name": "Cold haze", "hint": "the same shimmer over ice — a blue-white palette, half the heat, twice the slices",
			"dials": { "sky0": Color("1E3A7A"), "sky1": Color("8AB8E8"), "sky2": Color("E8F0F8"), "sand": Color("C8DCEC"), "far": Color("A8C0D8"),
				"heat": 0.5, "slices": 52,
				"label": "thinner slices, gentler sway: the same distortion reads as cold air instead of heat" } },
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.heat = 0.2 + (pos.x / b.W) * 2.2,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			K.sky(n, b, [[0.0, D.sky0], [0.55, D.sky1], [0.7, D.sky2]])
			var GY: float = b.H * 0.7
			var band: float = b.H * 0.16
			var slices: int = D.slices
			for i in slices:
				var k := float(i) / slices
				var y: float = GY - band + k * band
				var hgt: float = band / slices + 1.0
				var jitter: float = sin(t * 6.0 + k * 14.0) * D.heat * 6.0 * k + sin(t * 9.3 + k * 31.0) * D.heat * 3.0 * k
				var col := K.mix(D.far, D.sky2, (1.0 - k) * 0.7)
				var pts := PackedVector2Array([Vector2(-20, y + hgt)])
				var x := -20.0
				while x <= b.W + 20.0:
					pts.append(Vector2(x + jitter, y - maxf(0.0, sin(x * 0.02 + 1.0) * 10.0 + sin(x * 0.05) * 6.0) * (1.0 - k * 0.6)))
					x += 10.0
				pts.append(Vector2(b.W + 20.0, y + hgt))
				K.poly(n, pts, col)
			K.lin_rect(n, Rect2(0, GY, b.W, b.H - GY), [K.shade(D.sand, 0.15), K.shade(D.sand, -0.3)])
			K.label(n, b, D.label) })

	# ---- N · Nebula --------------------------------------------------------
	d.append({ "letter": "N", "name": "Nebula",
		"hint": "a gas cloud is soft radial blobs in three depth layers — far ones small and dim, near ones big and bright — drifting at speeds that match their depth",
		"dials": { "sky0": Color("05040F"), "sky1": Color("0F0A22"), "hues": [270.0, 320.0, 200.0], "sat": 0.7, "lum": 0.55,
			"blobs": 34, "drift": 1.0, "seed": 5,
			"label": "depth = size × brightness × speed, all from one number z" },
		"rhyme": { "name": "Ink nebula", "hint": "the same cloud in two inks — indigo and rust — with 60 blobs and a slower drift; a different seed, so a different cloud",
			"dials": { "sky0": Color("0A0A10"), "sky1": Color("14121C"), "hues": [230.0, 20.0], "sat": 0.6, "lum": 0.45,
				"blobs": 60, "drift": 0.4, "seed": 9,
				"label": "the seed is a dial too — same recipe, a different sky every time you change it" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(int(D.seed))
			b.blobs = []
			var hues: Array = D.hues
			for j in int(D.blobs):
				b.blobs.append({ "x": R.randf() * b.W, "y": R.randf() * b.H, "z": R.randf(),
					"hue": float(hues[j % hues.size()]) + R.randf() * 30.0, "ph": R.randf() * 9.0 })
			b.blobs.sort_custom(func(p, q): return p.z < q.z)       # far first — painter's order
			var R2 := K.rng(int(D.seed) + 1)
			b.stars = []
			for s in 60: b.stars.append(Vector3(R2.randf() * b.W, R2.randf() * b.H, 0.3 + R2.randf() * 0.9)),
		"press": func(b: Dictionary, pos: Vector2) -> void:
			for bl in b.blobs:                                        # near blobs move more — parallax
				bl.x += (pos.x - b.W / 2.0) * 0.05 * bl.z
				bl.y += (pos.y - b.H / 2.0) * 0.05 * bl.z,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			K.sky(n, b, [D.sky0, D.sky1])
			for s in b.stars: K.dot(n, Vector2(s.x, s.y), s.z, K.alpha(K.INK, 0.5))
			for bl in b.blobs:
				var z: float = bl.z
				var x: float = bl.x + sin(t * 0.1 * D.drift + bl.ph) * (4.0 + z * 18.0)
				var y: float = bl.y + cos(t * 0.07 * D.drift + bl.ph) * (3.0 + z * 10.0)
				K.soft(n, Vector2(x, y), b.W * (0.06 + z * 0.16), K.hsl(bl.hue, D.sat, D.lum), 0.05 + z * 0.16)
			K.label(n, b, D.label) })

	# ---- N · Nightfall -----------------------------------------------------
	d.append({ "letter": "N", "name": "Nightfall",
		"hint": "a full day in 24 seconds: five palettes on a circular clock, the sun and moon on opposite arcs, stars fading in with the dark",
		"dials": { "tops": [Color("6FA8E8"), Color("4A6FC8"), Color("2A1E5A"), Color("05051A"), Color("2A1E5A")],
			"hors": [Color("CFE6F5"), Color("F5C169"), Color("C2507A"), Color("1A1030"), Color("F5A15A")],
			"day": 24.0,
			"label": "the clock is circular: keyframe[i] → keyframe[(i+1) mod n], so midnight wraps to dawn" },
		"rhyme": { "name": "Fast-forward night", "hint": "the same day in six seconds instead of 24, with a purple-and-teal palette — a time-lapse",
			"dials": { "tops": [Color("3AA8C8"), Color("2A6FA8"), Color("3A1E6A"), Color("05051A"), Color("4A1E5A")],
				"hors": [Color("B8F0F0"), Color("F5C169"), Color("D050A0"), Color("1A1030"), Color("F58A8A")], "day": 6.0,
				"label": "one number (day) sets the tempo — a time-lapse is the same clock read faster" } },
		"init": func(b: Dictionary) -> void:
			var R := K.rng(8)
			b.offset = 0.0
			b.stars = []
			for j in 60: b.stars.append(Vector3(R.randf() * b.W, R.randf() * b.H * 0.7, 0.4 + R.randf() * 1.0)),
		"press": func(b: Dictionary, pos: Vector2) -> void: b.offset = (pos.x / b.W) * b.D.day - b.t,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var tops: Array = D.tops; var hors: Array = D.hors
			var cnt := tops.size()
			var k: float = fposmod((t + b.offset) / D.day, 1.0)
			var seg := k * cnt
			var i := int(seg) % cnt; var f := seg - floorf(seg)
			var top := K.mix(tops[i], tops[(i + 1) % cnt], f)
			var hor := K.mix(hors[i], hors[(i + 1) % cnt], f)
			var GY: float = b.H * 0.74
			K.sky(n, b, [[0.0, top], [0.75, hor], [1.0, hor]])
			var dark := clampf(1.0 - absf(k - 0.7) * 3.2, 0.0, 1.0)
			var j := 0
			for s in b.stars:
				K.dot(n, Vector2(s.x, s.y), s.z, K.alpha(K.INK, dark * (0.5 + 0.4 * sin(t * 3.0 + j)))); j += 1
			var sx: float = b.W / 2.0 + sin(k * TAU) * b.W * 0.42
			var sy: float = GY - cos(k * TAU) * b.H * 0.6
			var mx: float = b.W / 2.0 - sin(k * TAU) * b.W * 0.42
			var my: float = GY + cos(k * TAU) * b.H * 0.6
			if sy < GY:
				K.soft(n, Vector2(sx, sy), b.W * 0.2, Color("FFD9A0"), 0.35)
				K.dot(n, Vector2(sx, sy), b.W * 0.045, Color("FFF3D0"))
			if my < GY:
				K.dot(n, Vector2(mx, my), b.W * 0.03, Color("E8E5F4"))
				K.dot(n, Vector2(mx + b.W * 0.012, my - b.W * 0.008), b.W * 0.024, K.mix(top, hor, 0.3))   # one disc bites another
			K.ground(n, b, GY, Color("06060F"))
			K.label(n, b, D.label) })

	# ---- O · Overcast ------------------------------------------------------
	d.append({ "letter": "O", "name": "Overcast",
		"hint": "a grey day is bands of cloud, each a gradient with a lighter far edge, drifting at speeds that say how far away they are",
		"dials": { "top": Color("5A6478"), "bottom": Color("B8BFCC"), "cloud": Color("7A8396"), "floor": Color("3A3F50"),
			"bands": 6, "wind": 1.0, "flash_every": 0.0,
			"label": "clouds are gradients too: lit on top, dark underneath, paler the farther they are" },
		"rhyme": { "name": "Stormfront", "hint": "the same cloud bands, near-black, in a gale — with a flash every few seconds that lights their undersides",
			"dials": { "top": Color("1A1E2A"), "bottom": Color("4A5060"), "cloud": Color("2A2F3A"), "floor": Color("14161E"),
				"wind": 3.0, "flash_every": 3.5,
				"label": "the flash swaps which edge of each band is lit — light from below is the whole storm" } },
		"init": func(b: Dictionary) -> void:
			var R := K.rng(13)
			b.bands = []
			for j in int(b.D.bands):
				b.bands.append({ "y": 0.08 + j * 0.11, "h": 0.08 + R.randf() * 0.06, "ph": R.randf() * 9.0, "f": 1.0 + R.randf() * 1.5 })
			b.sun = Vector2(-1, -1)
			b.flash_at = -9.0,
		"press": func(b: Dictionary, pos: Vector2) -> void:
			if b.D.flash_every > 0.0: b.flash_at = b.t                # storm: lightning, now
			else: b.sun = Vector2(-1, -1) if b.sun.x >= 0.0 else pos, # calm: the sun breaks through here
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var flash := 0.0
			if D.flash_every > 0.0:
				if t - b.flash_at > D.flash_every: b.flash_at = t + randf() * 1.5
				flash = clampf(1.0 - (t - b.flash_at) * 6.0, 0.0, 1.0)
			K.sky(n, b, [K.mix(D.top, Color("8A90B0"), flash * 0.5), K.mix(D.bottom, Color("C8CCE0"), flash * 0.6)])
			var nb: int = b.bands.size()
			for j in nb:
				var bd: Dictionary = b.bands[j]
				var depth := float(j) / nb
				var speed: float = (0.2 + depth * 1.2) * D.wind
				var x0: float = fposmod(t * speed * 20.0 + bd.ph * 40.0, b.W + 200.0) - 100.0
				var y: float = b.H * bd.y; var h: float = b.H * bd.h
				var c := K.mix(K.shade(D.cloud, 0.35), K.shade(D.cloud, -0.3), depth * 0.8)
				var under := K.mix(K.shade(c, -0.25), Color("E8E8FF"), flash * 0.8)
				var steps := 22
				for s in steps:
					var xa: float = -200.0 + (b.W + 400.0) * s / steps
					var xb: float = -200.0 + (b.W + 400.0) * (s + 1) / steps
					var ya: float = y + sin((xa - x0) * 0.02 * bd.f) * h * 0.4 + sin((xa - x0) * 0.05) * h * 0.15
					var yb: float = y + sin((xb - x0) * 0.02 * bd.f) * h * 0.4 + sin((xb - x0) * 0.05) * h * 0.15
					K.lin_poly(n, PackedVector2Array([Vector2(xa, ya), Vector2(xb, yb), Vector2(xb, y + h), Vector2(xa, y + h)]),
						PackedColorArray([K.shade(c, 0.25), K.shade(c, 0.25), under, under]))
			if b.sun.x >= 0.0: K.soft(n, b.sun, b.W * 0.35, Color("FFF3D0"), 0.5)
			K.ground(n, b, b.H * 0.85, K.mix(D.floor, Color("5A6070"), flash))
			K.label(n, b, D.label) })

	# ---- R · Rainbow -------------------------------------------------------
	d.append({ "letter": "R", "name": "Rainbow",
		"hint": "a bow is seven concentric arcs of hue, alpha fading at both edges — a gradient bent into a circle, drawn where the light isn't",
		"dials": { "sky0": Color("4A6FA8"), "sky1": Color("9FB8D8"), "sky2": Color("D9E3F0"), "floor": Color("2F4A3A"),
			"width": 0.12, "alpha": 0.55, "sat": 0.9, "lum": 0.6, "secondary": true, "speed": 1.0, "night": false,
			"label": "hsl(hue, …) sweeping 280 → 0 across 28 arcs — colour AS a coordinate" },
		"rhyme": { "name": "Moonbow", "hint": "the same bow at night — a quarter of the alpha, no secondary bow, drawn twice as slowly under stars",
			"dials": { "sky0": Color("05051A"), "sky1": Color("151838"), "sky2": Color("2A2A4F"), "floor": Color("0A1410"),
				"alpha": 0.14, "sat": 0.6, "lum": 0.7, "secondary": false, "speed": 0.5, "night": true,
				"label": "alpha is a dial: at 0.14 the same hues read as a ghost — moonlight is just less of it" } },
		"init": func(b: Dictionary) -> void:
			b.cx = b.W * 0.5
			var R := K.rng(4)
			b.stars = []
			for j in 50: b.stars.append(Vector3(R.randf() * b.W, R.randf() * b.H * 0.8, 0.4 + R.randf() * 1.0)),
		"press": func(b: Dictionary, pos: Vector2) -> void: b.cx = pos.x,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			K.sky(n, b, [[0.0, D.sky0], [0.6, D.sky1], [1.0, D.sky2]])
			if D.night:
				var j := 0
				for s in b.stars:
					K.dot(n, Vector2(s.x, s.y), s.z, K.alpha(K.INK, 0.5 + 0.4 * sin(t * 2.0 + j))); j += 1
				K.dot(n, Vector2(b.W * 0.5, b.H * 0.12), b.W * 0.035, Color("F0EEFF"))
			var grow := K.ease(t * 0.35 * D.speed)
			var r0: float = b.H * 0.5; var w: float = b.H * D.width
			var cnt := 28
			var cy: float = b.H * 0.95
			for pss in (2 if D.secondary else 1):
				var R0 := r0 if pss == 0 else r0 * 1.32
				var alpha: float = D.alpha if pss == 0 else D.alpha * 0.28
				for i in cnt:
					var k := float(i) / cnt
					var hue := 280.0 - k * 280.0 if pss == 0 else k * 280.0
					var edge := sin(k * PI)
					if grow > 0.01:
						n.draw_arc(Vector2(b.cx, cy), R0 + k * w, PI, PI + PI * grow, 48, K.hsl(hue, D.sat, D.lum, alpha * edge), w / cnt + 0.6, true)
			K.ground(n, b, b.H * 0.86, D.floor)
			K.label(n, b, D.label) })

	# ---- T · Twilight ------------------------------------------------------
	d.append({ "letter": "T", "name": "Twilight",
		"hint": "the Belt of Venus: a pink band floating above a blue-grey band (the Earth's own shadow) — two horizontal gradients stacked, rising as the sun sinks",
		"dials": { "top": Color("2A3A8F"), "pink": Color("E8A0B8"), "shadow": Color("4A5A8A"), "horizon": Color("F5D9B0"),
			"length": 18.0, "grid": false,
			"label": "the grey band IS the planet's shadow on its own air — depth you can see from the ground" },
		"rhyme": { "name": "Cyber twilight", "hint": "the same two bands in neon — hot pink over electric blue over a black horizon — a synthwave poster",
			"dials": { "top": Color("0A0020"), "pink": Color("FF2A9A"), "shadow": Color("1A5AFF"), "horizon": Color.BLACK,
				"length": 10.0, "grid": true,
				"label": "saturate the bands to neon and the same physics becomes a genre" } },
		"init": func(b: Dictionary) -> void: b.scrub = -1.0,
		"press": func(b: Dictionary, pos: Vector2) -> void: b.scrub = pos.x / b.W,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var k: float = b.scrub if b.scrub >= 0.0 else (0.5 - 0.5 * cos((t / D.length) * PI))
			var GY: float = b.H * 0.74
			var band: float = GY - b.H * 0.28 * k
			K.sky(n, b, [[0.0, K.mix(D.top, Color("0A0F3A"), k * 0.7)],
				[clampf(band / b.H - 0.12, 0.0, 1.0), K.mix(D.pink, Color("5A3A6A"), k * 0.6)],
				[clampf(band / b.H, 0.0, 1.0), K.mix(D.shadow, Color("1A2040"), k * 0.5)],
				[GY / b.H, K.mix(D.horizon, Color("3A3A5A"), k * 0.8) if not D.grid else D.horizon]])
			if D.grid:
				for i in 9:
					K.line(n, Vector2(0, GY + i * i * 2.2), Vector2(b.W, GY + i * i * 2.2), K.alpha(D.pink, 0.6 - i * 0.05))
				K.ground(n, b, b.H * 0.98, Color.BLACK)
			else:
				K.ground(n, b, GY, Color("06060F"))
				K.poly(n, PackedVector2Array([Vector2(0, GY), Vector2(b.W * 0.3, GY - 6), Vector2(b.W * 0.5, GY - 14),
					Vector2(b.W * 0.62, GY - 4), Vector2(b.W, GY - 10), Vector2(b.W, b.H), Vector2(0, b.H)]), Color("06060F"))
			K.label(n, b, D.label) })

	# ---- Z · Zenith --------------------------------------------------------
	d.append({ "letter": "Z", "name": "Zenith",
		"hint": "the plainest sky: deep blue overhead, pale at the horizon, because you look through more air sideways — plus a bright patch that follows the sun",
		"dials": { "zenith": Color("1E4FB8"), "horizon": Color("CFE6F5"), "sun_glow": Color("FFF3D0"), "sun": Color("FFF3D0"),
			"grass0": Color("6A9A6A"), "grass1": Color("3A5A3A"), "glow_r": 0.55, "sun_x": 0.7, "sun_y": 0.25,
			"label": "zenith → horizon: more air = paler and whiter. That one gradient is 'outdoors'" },
		"rhyme": { "name": "Martian zenith", "hint": "the same clear sky on Mars: butterscotch overhead, blue near the small sun — the gradient runs the other way",
			"dials": { "zenith": Color("C8925A"), "horizon": Color("E8C8A0"), "sun_glow": Color("B8D8FF"), "sun": Color.WHITE,
				"grass0": Color("B86A3A"), "grass1": Color("5A2A1A"), "glow_r": 0.4,
				"label": "the physics is the same gradient; only the air's colour changed — dust, not nitrogen" } },
		"press": func(b: Dictionary, pos: Vector2) -> void:
			b.D.sun_x = pos.x / b.W; b.D.sun_y = pos.y / b.H,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			K.sky(n, b, [[0.0, D.zenith], [0.85, D.horizon], [1.0, D.horizon]])
			var s := Vector2(b.W * D.sun_x, b.H * D.sun_y)
			K.soft(n, s, b.W * D.glow_r, D.sun_glow, 0.35)               # air near the sun scatters brighter
			K.soft(n, s, b.W * 0.08, D.sun, 0.9)
			K.lin_rect(n, Rect2(0, b.H * 0.85, b.W, b.H * 0.15), [D.grass0, D.grass1])   # even the grass is a gradient
			K.label(n, b, D.label) })

	return d
