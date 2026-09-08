extends RefCounted

const Kit := preload("res://scenes/world/kit.gd")
## SCATTER & NOISE — four generators, ported from the web workshop
## (docs/worlds.js, family scatter). Places from randomness with rules. A
## plain random() clumps; every generator here adds one rule to it — keep
## your distance, add the octaves, take the nearest seed, rewrite the
## string — and a place appears. Four cards: Poisson, Terrain, Voronoi,
## Lsystem. Each one is seeded, so the world you see is the world everyone
## sees.
##
## Randomness: every card seeds Kit.rng(D.seed), exactly like the web's
## rng(seed). Godot's RandomNumberGenerator is not mulberry32, so the
## NUMBERS differ from the web page — but the RULE is the same: one seed,
## one world, on every machine that runs this file.

const TITLE := "Scatter & noise"
const BLURB := "places from randomness with rules — points that keep their distance, a ground line from layered noise, regions by nearest seed, trees from a rewrite rule"
const DEFS := [
	{ "id": "poisson", "letter": "P", "name": "Poisson", "drag": true,
		"hint": "random points that keep a minimum distance r (bridson's grid + active list) — next to a plain scatter that clumps — drag to set r",
		"dials": { "r": 0.085,          # the minimum distance, as a fraction of W
			"k": 12,                    # candidates thrown around an active point before it retires
			"perBeat": 3,               # active points tried per beat
			"beat": 0.04,               # seconds per beat
			"rest": 2.2,                # seconds to admire it before the next seed
			"rMin": 0.02, "rMax": 0.22, # what a drag may set r to
			"seed": 3,
			"label": "every pair ≥ r apart · grid cell = r/√2 · k = 12 tries" },
		"rhyme": { "name": "Pinprick", "hint": "a tiny r and a faster hand — hundreds of points, evenly strewn: a star field with no clumps",
			"dials": { "r": 0.022, "perBeat": 14 } } },
	{ "id": "terrain", "letter": "T", "name": "Terrain",
		"hint": "a side-view ground from layered 1-d noise — octaves at doubling frequency and halving amplitude, biomes by height — the mote rides it on a spring, hopping off the crests — press to reroll",
		"dials": { "octaves": 5,        # noise layers, added one per beat
			"persistence": 0.5,         # each octave's amplitude, as a fraction of the last
			"scale": 2.6,               # cycles of the first octave across the width
			"height": 0.5,              # the terrain's full range, as a fraction of H
			"sea": 0.4, "sand": 0.47, "grass": 0.66, "rock": 0.82,   # biome bands, in 0..1 of the range
			"beat": 0.7,                # seconds between octaves
			"rest": 2.4,                # seconds to rest on the finished ground
			"walk": 0.09,               # the mote's pace, in widths per second
			"hopK": 90,                 # the mote's height spring: stiffness toward the ground under it
			"hopDamp": 0.35,            # its damping, as a fraction of critical — under 1, so a crest launches it
			"tiltK": 40,                # the tilt spring: stiffness toward the slope
			"tiltDamp": 0.6,            # its damping, as a fraction of critical — it leans a beat late
			"seed": 11,
			"palette": "temperate",
			"palettes": { "temperate": ["#3A6FB5", "#E2C98A", "#6FAF5E", "#8C8698", "#F0F2FA"], "snow": ["#4A6E9C", "#B9C4D6", "#DCE6F2", "#9AA3B8", "#FFFFFF"] },
			"label": "h(x) = Σ noise(x·2ⁱ) · ½ⁱ · biome by height band · mote: y'' = k·(ground − y) − d·y'" },
		"rhyme": { "name": "Tundra", "hint": "three octaves, half the range and a snow palette — a flat white plain with a low grey sea",
			"dials": { "octaves": 3, "height": 0.3, "palette": "snow" } } },
	{ "id": "voronoi", "letter": "V", "name": "Voronoi",
		"hint": "every cell takes the colour of its nearest seed — biomes, territories, shattered glass — press to add a seed where you click",
		"dials": { "cols": 56, "rows": 36,   # the grid
			"seeds": 9,                      # seeds to start with
			"metric": "euclid",              # "euclid" or "manhattan" — the meaning of nearest
			"drift": 1.4,                    # seed speed, in cells per second, once the sweep is done
			"rowsPerBeat": 2, "beat": 0.03,  # the sweep that assigns rows
			"rest": 3.2,                     # seconds of drifting before the next seed
			"maxSeeds": 40,
			"seed": 5,
			"palette": "biome",              # "biome" or "glass"
			"label": "each cell → its nearest seed" },
		"rhyme": { "name": "Vitreous", "hint": "manhattan distance, three times the seeds and a glass palette — diamond shards with 45° edges",
			"dials": { "metric": "manhattan", "seeds": 26, "palette": "glass" } } },
	{ "id": "lsystem", "letter": "L", "name": "Lsystem",
		"hint": "a string rewritten by one rule, drawn by a turtle (F forward, ± turn, [ ] push/pop) — a plant in four iterations — press to regrow",
		"dials": { "axiom": "F",
			"rule": "F[+F]F[-F]F",     # what every F becomes, each iteration
			"angle": 25,               # degrees per + or −
			"iters": 4,                # iterations, one per beat
			"jitter": 7,               # degrees of random angle on each regrowth
			"beat": 0.9,               # seconds per iteration (the segments are revealed across it)
			"rest": 2.4,
			"maxLen": 20000,           # the string stops growing past this
			"seed": 2,
			"label": "turtle: F forward · + − turn by angle · [ ] push / pop" },
		"rhyme": { "name": "Lichen", "hint": "a different rule and a narrower angle — a bushy coral that splits three ways at every joint",
			"dials": { "rule": "FF-[-F+F+F]+[+F-F-F]", "angle": 22, "iters": 3 } } },
]


# ── shared helpers ────────────────────────────────────────────────────────

## The web kit's label(txt, x, y, col, align): 10 px text, left / right / center.
static func _txt(n: CanvasItem, txt: String, x: float, y: float,
		col: Color = Color(0.91, 0.898, 0.957, 0.55), align: String = "left", size: int = 10) -> void:
	var f := ThemeDB.fallback_font
	var xx := x
	if align != "left":
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		xx -= w if align == "right" else w / 2.0
	n.draw_string(f, Vector2(xx, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

## The web kit's hsl(h, s, l) (degrees, 0..1, 0..1) as a Color.
static func _hsl(h: float, sat: float, lum: float) -> Color:
	var v := lum + sat * minf(lum, 1.0 - lum)
	var sv := 0.0 if v <= 0.0 else 2.0 * (1.0 - lum / v)
	return Color.from_hsv(fposmod(h, 360.0) / 360.0, sv, v)

## The web's floor(r() * count): an index in 0..count-1 from the seeded stream.
static func _pick(r: RandomNumberGenerator, count: int) -> int:
	return r.randi_range(0, count - 1) if count > 0 else 0


# ── Poisson ──────────────────────────────────────────────────────────────

static func _poisson_reset(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var mw: int = b.mw
	var mh: float = b.mh
	var r: float = clampf(b.rFrac, float(D.rMin), float(D.rMax)) * b.w
	b.r = r
	var cell: float = r / sqrt(2.0)
	b.cell = cell
	var gw: int = maxi(1, ceili(mw / cell))
	var gh: int = maxi(1, ceili(mh / cell))
	b.gw = gw
	b.gh = gh
	var grid := PackedInt32Array()
	grid.resize(gw * gh)
	grid.fill(-1)
	b.grid = grid
	var px := PackedFloat32Array()
	px.resize(gw * gh)
	b.px = px
	var py := PackedFloat32Array()
	py.resize(gw * gh)
	b.py = py
	var act := PackedInt32Array()
	act.resize(gw * gh)
	b.act = act
	b.n = 0
	b.nAct = 0
	var naive := PackedFloat32Array()
	naive.resize(gw * gh * 2)
	b.naive = naive
	b.nClose = 0
	b.close = PackedInt32Array()
	b.r1 = Kit.rng(b.seed)
	b.r2 = Kit.rng(int(b.seed) + 99)
	b.tried = PackedFloat32Array()
	b.last = -1
	b.lastAdd = -1
	b.flash = 0.0
	b.acc = 0.0
	b.restT = 0.0
	b.done = false
	var r1: RandomNumberGenerator = b.r1
	_poisson_add(b, r1.randf() * mw, r1.randf() * mh)          # the first point: anywhere

static func _poisson_fits(b: Dictionary, x: float, y: float) -> bool:
	var cell: float = b.cell
	var gw: int = b.gw
	var gh: int = b.gh
	var r: float = b.r
	var grid: PackedInt32Array = b.grid
	var px: PackedFloat32Array = b.px
	var py: PackedFloat32Array = b.py
	var gx := int(floorf(x / cell))
	var gy := int(floorf(y / cell))
	for j in range(maxi(0, gy - 2), mini(gh - 1, gy + 2) + 1):
		for i in range(maxi(0, gx - 2), mini(gw - 1, gx + 2) + 1):
			var p := grid[j * gw + i]
			if p >= 0 and Vector2(px[p] - x, py[p] - y).length() < r:
				return false
	return true

static func _poisson_add(b: Dictionary, x: float, y: float) -> int:
	var cnt: int = b.n
	var px: PackedFloat32Array = b.px
	if cnt >= px.size():
		return -1
	var cell: float = b.cell
	var gw: int = b.gw
	var gh: int = b.gh
	var grid: PackedInt32Array = b.grid
	var gx := clampi(int(floorf(x / cell)), 0, gw - 1)
	var gy := clampi(int(floorf(y / cell)), 0, gh - 1)
	if grid[gy * gw + gx] >= 0:                                 # one point per cell, always
		return -1
	var py: PackedFloat32Array = b.py
	var act: PackedInt32Array = b.act
	px[cnt] = x
	py[cnt] = y
	grid[gy * gw + gx] = cnt
	act[b.nAct] = cnt
	b.nAct += 1
	var r2: RandomNumberGenerator = b.r2
	var naive: PackedFloat32Array = b.naive
	var close: PackedInt32Array = b.close
	var r: float = b.r
	var nx := r2.randf() * float(b.sw)                          # the naive twin: one uniform point
	var ny := r2.randf() * float(b.mh)
	var nClose: int = b.nClose
	for i in cnt:                                               # count its clumps — pairs closer than r
		if Vector2(naive[i * 2] - nx, naive[i * 2 + 1] - ny).length() < r:
			nClose += 1
			if close.size() < 400:
				close.push_back(i)
				close.push_back(cnt)
	b.nClose = nClose
	naive[cnt * 2] = nx
	naive[cnt * 2 + 1] = ny
	b.lastAdd = cnt
	b.flash = 1.0
	b.n = cnt + 1
	return cnt

static func _poisson_step(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var nAct: int = b.nAct
	if nAct == 0:
		b.done = true
		return
	var r1: RandomNumberGenerator = b.r1
	var act: PackedInt32Array = b.act
	var px: PackedFloat32Array = b.px
	var py: PackedFloat32Array = b.py
	var r: float = b.r
	var mw: int = b.mw
	var mh: float = b.mh
	var ai := _pick(r1, nAct)
	var p := act[ai]
	b.last = p
	var tried := PackedFloat32Array()
	var found := false
	for _j in int(D.k):
		var a := r1.randf() * TAU
		var d := r * (1.0 + r1.randf())                         # the ring r..2r around the active point
		var x := px[p] + cos(a) * d
		var y := py[p] + sin(a) * d
		if x >= 0.0 and y >= 0.0 and x < mw and y < mh and _poisson_fits(b, x, y):
			_poisson_add(b, x, y)
			found = true
			break
		tried.push_back(x)
		tried.push_back(y)
	b.tried = tried
	if not found:                                               # all k missed: retire it
		nAct -= 1
		act[ai] = act[nAct]
		b.nAct = nAct
		if nAct == 0:
			b.done = true


# ── Terrain ──────────────────────────────────────────────────────────────

static func _terrain_reroll(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var r := Kit.rng(b.seed)
	var off: Array = []
	for _o in int(D.octaves):
		off.append(r.randf() * 1000.0)
	b.off = off
	b.shown = 1
	b.acc = 0.0
	b.restT = 0.0
	_terrain_build(b)

## The sum of the octaves shown so far.
static func _terrain_build(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var shown: int = b.shown
	var persistence: float = D.persistence
	var scale: float = D.scale
	var off: Array = b.off
	var hgt: PackedFloat32Array = b.hgt
	var cols: int = b.cols
	var w: float = b.w
	var norm := 0.0
	var amp := 1.0
	for _o in shown:
		norm += amp
		amp *= persistence
	for i in cols:
		var v := 0.0
		amp = 1.0
		for o in shown:
			v += Kit.noise((i * 2.0 / w) * scale * float(1 << o) + float(off[o])) * amp
			amp *= persistence
		hgt[i] = clampf(0.5 + 0.5 * v / maxf(1e-6, norm), 0.0, 1.0)

static func _terrain_y(b: Dictionary, hn: float) -> float:
	var D: Dictionary = b.D
	return float(b.base) - hn * float(b.h) * float(D.height)

static func _terrain_biome(D: Dictionary, hn: float) -> int:
	if hn < float(D.sea):
		return 0
	if hn < float(D.sand):
		return 1
	if hn < float(D.grass):
		return 2
	if hn < float(D.rock):
		return 3
	return 4


# ── Voronoi ──────────────────────────────────────────────────────────────

static func _voronoi_colour(D: Dictionary, i: int, r: RandomNumberGenerator) -> Color:
	if D.palette == "glass":
		return _hsl(185.0 + r.randf() * 40.0, 0.35, 0.45 + r.randf() * 0.35)
	var hues := [205.0, 95.0, 42.0, 130.0, 28.0, 170.0, 80.0]   # sea, grass, sand, forest, clay, marsh, meadow
	var hue: float = hues[i % hues.size()]
	return _hsl(hue + (r.randf() - 0.5) * 16.0, 0.45, 0.3 + r.randf() * 0.16)

static func _voronoi_plant(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var r := Kit.rng(b.seed)
	var S: Array = []
	for i in int(D.seeds):
		S.append({ "x": r.randf() * float(D.cols), "y": r.randf() * float(D.rows),
			"vx": (r.randf() - 0.5) * 2.0, "vy": (r.randf() - 0.5) * 2.0, "c": _voronoi_colour(D, i, r) })
	b.S = S
	_voronoi_mirror(b)
	b.row = 0
	b.acc = 0.0
	b.restT = 0.0

## The seed positions copied into packed arrays, so the row loop stays cheap.
static func _voronoi_mirror(b: Dictionary) -> void:
	var S: Array = b.S
	var sxs := PackedFloat32Array()
	var sys := PackedFloat32Array()
	sxs.resize(S.size())
	sys.resize(S.size())
	for i in S.size():
		var sd: Dictionary = S[i]
		sxs[i] = sd.x
		sys[i] = sd.y
	b.sxs = sxs
	b.sys = sys

static func _voronoi_dist(D: Dictionary, sd: Dictionary, x: int, y: int) -> float:
	var dx := absf(x + 0.5 - float(sd.x))
	var dy := absf(y + 0.5 - float(sd.y))
	return dx + dy if D.metric == "manhattan" else sqrt(dx * dx + dy * dy)

static func _voronoi_nearest(b: Dictionary, x: int, y: int) -> int:
	var D: Dictionary = b.D
	var S: Array = b.S
	var bi := 0
	var bd := INF
	for i in S.size():
		var d := _voronoi_dist(D, S[i], x, y)
		if d < bd:
			bd = d
			bi = i
	return bi

## One row of the sweep: every cell takes the index of its nearest seed.
static func _voronoi_assign_row(b: Dictionary, y: int) -> void:
	var D: Dictionary = b.D
	var g: Dictionary = b.g
	var a: PackedFloat32Array = g.a
	var sxs: PackedFloat32Array = b.sxs
	var sys: PackedFloat32Array = b.sys
	var cols: int = D.cols
	var manhattan: bool = D.metric == "manhattan"
	var cnt := sxs.size()
	var fy := y + 0.5
	for x in cols:
		var fx := x + 0.5
		var bi := 0
		var bd := INF
		for i in cnt:
			var dx := absf(fx - sxs[i])
			var dy := absf(fy - sys[i])
			var d := dx + dy if manhattan else sqrt(dx * dx + dy * dy)
			if d < bd:
				bd = d
				bi = i
		a[y * cols + x] = float(bi)


# ── Lsystem ──────────────────────────────────────────────────────────────

## Every F becomes the rule, all at once; past maxLen the string stops growing.
static func _lsys_expand(D: Dictionary, sentence: String) -> String:
	var out := sentence.replace("F", String(D.rule))
	return sentence if out.length() > int(D.maxLen) else out

## The turtle's walk, in unit steps: segments as (x, y, nx, ny, depth) fives.
static func _lsys_trace(b: Dictionary) -> void:
	var sentence: String = b.sentence
	var segs := PackedFloat32Array()
	var stack := PackedFloat32Array()
	var x := 0.0
	var y := 0.0
	var a := -PI / 2.0
	var depth := 0
	var da: float = float(b.ang) * PI / 180.0
	var minX := 0.0
	var maxX := 0.0
	var minY := 0.0
	var maxY := 0.0
	for i in sentence.length():
		var c := sentence.unicode_at(i)
		if c == 70:                                             # F
			var nx := x + cos(a)
			var ny := y + sin(a)
			segs.push_back(x)
			segs.push_back(y)
			segs.push_back(nx)
			segs.push_back(ny)
			segs.push_back(float(depth))
			x = nx
			y = ny
			minX = minf(minX, x)
			maxX = maxf(maxX, x)
			minY = minf(minY, y)
			maxY = maxf(maxY, y)
		elif c == 43:                                           # +
			a += da
		elif c == 45:                                           # −
			a -= da
		elif c == 91:                                           # [
			stack.push_back(x)
			stack.push_back(y)
			stack.push_back(a)
			depth += 1
		elif c == 93 and stack.size() >= 3:                     # ]
			var top := stack.size()
			a = stack[top - 1]
			y = stack[top - 2]
			x = stack[top - 3]
			stack.resize(top - 3)
			depth -= 1
	b.segs = segs
	var bw := maxf(1e-3, maxX - minX)
	var bh := maxf(1e-3, maxY - minY)
	var fs: float = minf(float(b.areaW) / bw, float(b.areaH) / bh) * 0.94   # fit the drawing to the card, whatever the rule
	b.fit_s = fs
	b.fit_x = float(b.w) / 2.0 - (minX + maxX) / 2.0 * fs
	b.fit_y = float(b.h) - 24.0 - maxY * fs

static func _lsys_regrow(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var r := Kit.rng(b.seed)
	b.ang = float(D.angle) + (r.randf() * 2.0 - 1.0) * float(D.jitter)
	b.iter = 0
	b.sentence = String(D.axiom)
	b.acc = 0.0
	b.restT = 0.0
	_lsys_trace(b)


# ── the four entry points ────────────────────────────────────────────────

static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	match b.id:
		"poisson":
			# POISSON-DISC scattering. a plain random() puts trees on top of trees;
			# bridson's trick keeps every pair at least r apart and stays fast: a
			# grid of cells r/√2 wide holds at most ONE point each, so "is anything
			# within r?" is a look at the 5×5 cells around you. an ACTIVE list holds
			# points that may still have room beside them; pick one, throw k
			# candidates into the ring r..2r around it, keep the first that fits,
			# and retire the point when all k miss. the strip on the right is the
			# same count of points with no rule — the ch04 starfield, clumps and all.
			b.mw = int(floorf(b.w * 0.7))
			b.mh = b.h - 20.0
			b.sx = float(b.mw) + 8.0
			b.sw = b.w - float(b.sx) - 2.0
			b.rFrac = float(D.r)
			b.seed = int(D.seed)
			_poisson_reset(b)
		"terrain":
			# 1-D NOISE TERRAIN. one octave of smooth noise is a rolling hill; add a
			# second at twice the frequency and half the amplitude and the hill
			# grows bumps; a third adds pebbles. that sum is LAYERED (fractal) noise,
			# and the ½ⁱ is the persistence — the depth atlas's Knoll had one layer,
			# this ground has five. the height then picks the BIOME: below the sea
			# line is water, a thin band above it sand, then grass, rock, snow. the
			# seed only shifts where each octave is read from, so the same seed is
			# the same coastline on every machine.
			b.base = b.h - 22.0
			b.top = 14.0
			b.cols = ceili(b.w / 2.0) + 1
			var hgt := PackedFloat32Array()
			hgt.resize(b.cols)
			b.hgt = hgt
			var pals: Dictionary = D.palettes
			var hexes: Array = pals[D.palette] if pals.has(D.palette) else pals.temperate
			var pal: Array = []
			for hx in hexes:
				pal.append(Color(String(hx)))
			b.pal = pal
			b.seed = int(D.seed)
			b.wx = 0.0
			_terrain_reroll(b)
			var hgt0: PackedFloat32Array = b.hgt                  # the mote's body: height, tilt, and their velocities
			b.my = minf(_terrain_y(b, hgt0[1]), _terrain_y(b, float(D.sea)))
			b.mvy = 0.0
			b.mang = 0.0
			b.mangv = 0.0
		"voronoi":
			# VORONOI regions. drop N seeds; every point in the plane belongs to the
			# seed it is NEAREST to, and the plane shatters into N cells with straight
			# shared edges. on a grid it is nothing but a loop: for every cell, find
			# the closest seed. change what "closest" means — the almanac's shatter
			# used √(dx² + dy²); |dx| + |dy| (manhattan) gives diamond cells with
			# 45° edges — and the same seeds draw a different country. the sweep
			# line is the loop doing its work, row by row.
			b.gw = b.w
			b.gh = b.h - 18.0
			b.cw = float(b.gw) / float(D.cols)
			b.ch = float(b.gh) / float(D.rows)
			b.g = Kit.cells(int(D.cols), int(D.rows), -1.0)      # -1: not yet assigned
			b.seed = int(D.seed)
			b.driftRow = 0
			_voronoi_plant(b)
		"lsystem":
			# L-SYSTEMS. a plant is a sentence: start with the AXIOM "F" and apply
			# the RULE to every F at once — "F[+F]F[-F]F" says "grow, branch left,
			# grow, branch right, grow". four rounds of that is a string of fifteen
			# hundred letters. a TURTLE reads it: F draws a step, + and − turn it by
			# the angle, [ remembers where it stands and ] jumps back there, which
			# is how a branch ends and the trunk continues. the lexicon's Vine was
			# one chain; this is the grammar that draws the whole hedge.
			b.areaW = b.w - 16.0
			b.areaH = b.h - 34.0
			b.seed = int(D.seed)
			_lsys_regrow(b)

static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	match b.id:
		"poisson":
			# r = how far you are from the centre
			b.rFrac = clampf(Vector2(pos.x - float(b.mw) / 2.0, pos.y - float(b.mh) / 2.0).length() / float(b.w),
				float(D.rMin), float(D.rMax))
			_poisson_reset(b)
		"terrain":
			b.seed += 1
			_terrain_reroll(b)
		"voronoi":
			var S: Array = b.S
			if S.size() >= int(D.maxSeeds):
				S.pop_front()
			S.append({ "x": clampf(pos.x / float(b.cw), 0.0, float(D.cols)), "y": clampf(pos.y / float(b.ch), 0.0, float(D.rows)),
				"vx": 0.0, "vy": 0.0, "c": _voronoi_colour(D, S.size(), Kit.rng(int(b.seed) + S.size())) })
			_voronoi_mirror(b)
			b.row = 0                                           # sweep again, with the new seed in the running
			b.acc = 0.0
		"lsystem":
			b.seed += 1
			_lsys_regrow(b)

static func tick(b: Dictionary, dt: float, _t: float) -> void:
	var D: Dictionary = b.D
	match b.id:
		"poisson":
			b.flash = maxf(0.0, float(b.flash) - dt * 4.0)
			if not b.done:
				b.acc += dt
				var beat: float = D.beat
				var guard := 0
				while float(b.acc) >= beat and guard < 12:
					guard += 1
					b.acc -= beat
					for _i in int(D.perBeat):
						if b.done:
							break
						_poisson_step(b)
			else:
				b.restT += dt
				if float(b.restT) > float(D.rest):
					b.seed += 1
					_poisson_reset(b)
		"terrain":
			if int(b.shown) < int(D.octaves):
				b.acc += dt
				if float(b.acc) >= float(D.beat):
					b.acc = 0.0
					b.shown += 1
					_terrain_build(b)
			else:
				b.restT += dt
				if float(b.restT) > float(D.rest):
					b.seed += 1
					_terrain_reroll(b)
			b.wx = fposmod(float(b.wx) + dt * float(D.walk) * float(b.w), float(b.w))   # the mote walks the ground it is given
			# the mote is a BODY, not a stamp: its height is a damped spring toward the
			# ground under it (y'' = k·(ground − y) − d·y'), so a crest that drops away
			# leaves it airborne for a moment and a rising slope catches it with a
			# thump; it may never sink below the ground, and landing kills the fall.
			# its tilt is the same spring toward the slope, so it leans a beat late.
			# symplectic: velocity first, then position — and the step is cut so that
			# √k·h < 2 even on the runtime's coarsest frame (S·Substep)
			var hgt: PackedFloat32Array = b.hgt
			var cols: int = b.cols
			var sea: float = D.sea
			var yw := _terrain_y(b, sea)
			var ci := clampi(int(floorf(float(b.wx) / 2.0)), 1, cols - 2)
			var gy := minf(_terrain_y(b, hgt[ci]), yw)
			var ang := 0.0 if hgt[ci] < sea else atan2(_terrain_y(b, hgt[ci + 1]) - _terrain_y(b, hgt[ci - 1]), 4.0)
			var hopK: float = D.hopK
			var tiltK: float = D.tiltK
			var dY: float = float(D.hopDamp) * 2.0 * sqrt(hopK)
			var dA: float = float(D.tiltDamp) * 2.0 * sqrt(tiltK)
			var sub := maxi(1, ceili(dt * 50.0))
			var hs := dt / sub
			var my: float = b.my
			var mvy: float = b.mvy
			var mang: float = b.mang
			var mangv: float = b.mangv
			for _s in sub:
				mvy += (hopK * (gy - my) - dY * mvy) * hs
				my += mvy * hs
				if my > gy:                                     # the ground is solid: land, never sink
					my = gy
					mvy = minf(0.0, mvy)
				mangv += (tiltK * (ang - mang) - dA * mangv) * hs
				mang += mangv * hs
			b.my = my
			b.mvy = mvy
			b.mang = mang
			b.mangv = mangv
		"voronoi":
			var rows: int = D.rows
			var cols: float = D.cols
			if int(b.row) < rows:
				b.acc += dt
				var beat: float = D.beat
				var guard := 0
				while float(b.acc) >= beat and int(b.row) < rows and guard < 20:
					guard += 1
					b.acc -= beat
					for _k in int(D.rowsPerBeat):
						if int(b.row) < rows:
							_voronoi_assign_row(b, b.row)
							b.row += 1
			else:
				var S: Array = b.S
				var drift: float = D.drift
				for sd: Dictionary in S:                        # the seeds drift and the borders follow
					sd.x += sd.vx * drift * dt
					sd.y += sd.vy * drift * dt
					if sd.x < 0.0 or sd.x > cols:
						sd.vx = -sd.vx
					if sd.y < 0.0 or sd.y > float(rows):
						sd.vy = -sd.vy
					sd.x = clampf(sd.x, 0.0, cols)
					sd.y = clampf(sd.y, 0.0, float(rows))
				_voronoi_mirror(b)
				# the web reassigns every row each frame; GDScript is slower, so a
				# quarter of the rows per tick, round-robin — the borders trail the
				# seeds by a few ticks, and the card stays inside its time budget.
				for _k in ceili(rows / 4.0):
					_voronoi_assign_row(b, b.driftRow)
					b.driftRow = (int(b.driftRow) + 1) % rows
				b.restT += dt
				if float(b.restT) > float(D.rest):
					b.seed += 1
					_voronoi_plant(b)
					var ga: PackedFloat32Array = (b.g as Dictionary).a   # a typed local shares the array; a cast-write would hit a copy
					ga.fill(-1.0)
		"lsystem":
			if int(b.iter) < int(D.iters):
				b.acc += dt
				if float(b.acc) >= float(D.beat):
					b.acc = 0.0
					b.iter += 1
					b.sentence = _lsys_expand(D, b.sentence)
					_lsys_trace(b)
			else:
				b.restT += dt
				if float(b.restT) > float(D.rest):
					b.seed += 1
					_lsys_regrow(b)

static func draw(n: CanvasItem, b: Dictionary, _t: float) -> void:
	var D: Dictionary = b.D
	var w: float = b.w
	var h: float = b.h
	Kit.stage(n, b)
	match b.id:
		"poisson":
			var mw: int = b.mw
			var mh: float = b.mh
			var sx: float = b.sx
			var gw: int = b.gw
			var gh: int = b.gh
			var cell: float = b.cell
			var r: float = b.r
			var cnt: int = b.n
			var nAct: int = b.nAct
			var px: PackedFloat32Array = b.px
			var py: PackedFloat32Array = b.py
			var act: PackedInt32Array = b.act
			var naive: PackedFloat32Array = b.naive
			var close: PackedInt32Array = b.close
			var gcol := Color(0.588, 0.569, 0.745, 0.12)         # bridson's grid: one point per cell at most
			for i in range(1, gw):
				n.draw_line(Vector2(i * cell, 0.0), Vector2(i * cell, mh), gcol, 1.0)
			for j in range(1, gh):
				n.draw_line(Vector2(0.0, j * cell), Vector2(mw, j * cell), gcol, 1.0)
			Kit.line(n, Vector2(mw + 4.0, 0.0), Vector2(mw + 4.0, mh), Color(0.788, 0.769, 0.894, 0.2))
			var pr := maxf(1.2, r * 0.11)
			for i in cnt:
				Kit.dot(n, Vector2(px[i], py[i]), pr, Kit.BONE)
			for i in nAct:                                      # still active: may have room
				Kit.dot(n, Vector2(px[act[i]], py[act[i]]), pr, Kit.MOVER)
			var last: int = b.last
			if not b.done and last >= 0:
				var lp := Vector2(px[last], py[last])
				Kit.ring(n, lp, r, Kit.TARGET, 1.2)             # nothing may land inside r …
				Kit.ring(n, lp, 2.0 * r, Kit.DIM, 1.0)          # … candidates are thrown out to 2r
				var tried: PackedFloat32Array = b.tried
				for i in range(0, tried.size(), 2):
					Kit.ring(n, Vector2(tried[i], tried[i + 1]), pr + 1.0, Kit.HOT, 1.0)
				_txt(n, "r", lp.x + r * 0.7 + 2.0, lp.y - 3.0, Kit.TARGET)
			var lastAdd: int = b.lastAdd
			var flash: float = b.flash
			if lastAdd >= 0 and flash > 0.0:
				Kit.ring(n, Vector2(px[lastAdd], py[lastAdd]), pr + 2.0 + (1.0 - flash) * 6.0, Kit.GOOD, 1.5)
			for i in cnt:                                       # the naive strip
				Kit.dot(n, Vector2(sx + naive[i * 2], naive[i * 2 + 1]), pr, Kit.BONE)
			for i in range(0, close.size() - 1, 2):
				var ca := close[i]
				var cb := close[i + 1]
				Kit.line(n, Vector2(sx + naive[ca * 2], naive[ca * 2 + 1]), Vector2(sx + naive[cb * 2], naive[cb * 2 + 1]), Kit.HOT, 1.0)
			_txt(n, "poisson · %d points · %d active" % [cnt, nAct], 4.0, 11.0)
			_txt(n, "naive · %d too close" % int(b.nClose), w - 4.0, 11.0, Kit.HOT, "right")
			_txt(n, String(D.label) + " · r = %dpx" % roundi(r), w / 2.0, h - 6.0, Color(0.91, 0.898, 0.957, 0.55), "center")
		"terrain":
			var base: float = b.base
			var top: float = b.top
			var cols: int = b.cols
			var hgt: PackedFloat32Array = b.hgt
			var pal: Array = b.pal
			var pal0: Color = pal[0]
			var off: Array = b.off
			var shown: int = b.shown
			var octaves: int = D.octaves
			var persistence: float = D.persistence
			var scale: float = D.scale
			var height: float = D.height
			var sea: float = D.sea
			var yw := _terrain_y(b, sea)
			for i in cols - 1:                                  # the ground, coloured by band
				var y := _terrain_y(b, hgt[i])
				var pc: Color = pal[_terrain_biome(D, hgt[i])]
				Kit.rect(n, Rect2(i * 2.0, y, 2.5, base - y), pc)
			Kit.rect(n, Rect2(0.0, yw, w, base - yw), Color(pal0, 0.45))   # the sea fills every dip below the line
			Kit.line(n, Vector2(0.0, yw), Vector2(w, yw), Color(pal0, 0.9), 1.0)
			var amp := 1.0                                      # the octaves, faintly, under the sum
			var mid := _terrain_y(b, 0.5)
			for o in octaves:
				var on := o < shown
				var lc := Color(0.91, 0.898, 0.957, 0.22 if on else 0.06)
				var pts := PackedVector2Array()
				pts.resize(cols)
				for i in cols:
					pts[i] = Vector2(i * 2.0, mid - Kit.noise((i * 2.0 / w) * scale * float(1 << o) + float(off[o])) * amp * h * height * 0.5)
				n.draw_polyline(pts, lc, 1.0)
				var tag := "1" if o == 0 else "½" + ("^%d" % o if o > 1 else "")
				_txt(n, "×" + tag, w - 4.0, top + 10.0 + o * 11.0, Kit.BONE if on else Kit.DIM, "right")
				amp *= persistence
			var wx: float = b.wx
			Kit.mote(n, b, Vector2(wx, float(b.my) - 7.0), float(b.mang))   # where the spring put it, leaning as it lags
			_txt(n, "octaves %d / %d · persistence %s" % [shown, octaves, str(persistence)], 4.0, 11.0)
			_txt(n, D.label, w / 2.0, h - 6.0, Color(0.91, 0.898, 0.957, 0.55), "center")
		"voronoi":
			var cols: int = D.cols
			var rows: int = D.rows
			var cw: float = b.cw
			var ch: float = b.ch
			var g: Dictionary = b.g
			var a: PackedFloat32Array = g.a
			var S: Array = b.S
			var row: int = b.row
			var manhattan: bool = D.metric == "manhattan"
			var colour_of := func(v: float, _x: int, _y: int) -> Variant:
				if v < 0.0 or S.is_empty():
					return null
				var sd: Dictionary = S[mini(int(v), S.size() - 1)]
				return sd.c
			Kit.draw_cells(n, g, Vector2.ZERO, cw, ch, colour_of)
			var edge := Color(0.075, 0.063, 0.125, 0.55)          # the shared edges: where the owner changes
			for y in rows:
				for x in cols:
					var v := a[y * cols + x]
					if v < 0.0:
						continue
					if x + 1 < cols:
						var vr := a[y * cols + x + 1]
						if vr != v and vr >= 0.0:
							n.draw_line(Vector2((x + 1) * cw, y * ch), Vector2((x + 1) * cw, (y + 1) * ch), edge, 1.0)
					if y + 1 < rows:
						var vd := a[(y + 1) * cols + x]
						if vd != v and vd >= 0.0:
							n.draw_line(Vector2(x * cw, (y + 1) * ch), Vector2((x + 1) * cw, (y + 1) * ch), edge, 1.0)
			for sd: Dictionary in S:
				Kit.dot(n, Vector2(float(sd.x) * cw, float(sd.y) * ch), 2.5, Kit.INK)
			var hx := cols >> 1                                   # one cell shows its measurement
			var hy := row if row < rows else rows >> 1
			if row < rows:
				Kit.line(n, Vector2(0.0, row * ch), Vector2(w, row * ch), Kit.TARGET, 1.5)
			if not S.is_empty():
				var sd: Dictionary = S[_voronoi_nearest(b, hx, hy)]
				var cx := (hx + 0.5) * cw
				var cy := (hy + 0.5) * ch
				var sxp := float(sd.x) * cw
				var syp := float(sd.y) * ch
				Kit.ring(n, Vector2(cx, cy), maxf(2.0, cw * 0.4), Kit.TARGET, 1.5)
				if manhattan:
					Kit.line(n, Vector2(cx, cy), Vector2(sxp, cy), Kit.TARGET, 1.0)
					Kit.line(n, Vector2(sxp, cy), Vector2(sxp, syp), Kit.TARGET, 1.0)
				else:
					Kit.line(n, Vector2(cx, cy), Vector2(sxp, syp), Kit.TARGET, 1.0)
				_txt(n, "d = %.1f" % _voronoi_dist(D, sd, hx, hy), (cx + sxp) / 2.0 + 4.0, (cy + syp) / 2.0 - 4.0, Kit.TARGET)
			_txt(n, "%d seeds · %s" % [S.size(), String(D.metric)], 4.0, 11.0)
			_txt(n, String(D.label) + " · " + ("d = |dx| + |dy|" if manhattan else "d = √(dx² + dy²)"), w / 2.0, h - 6.0, Color(0.91, 0.898, 0.957, 0.55), "center")
		"lsystem":
			var segs: PackedFloat32Array = b.segs
			var iter: int = b.iter
			var iters: int = D.iters
			var count := segs.size() / 5
			var k: float = clampf(float(b.acc) / float(D.beat), 0.0, 1.0) if iter < iters else 1.0
			var shown: int = count if iter == 0 else int(floorf(count * maxf(k, 0.02)))   # each iteration is revealed as it grows
			var fs: float = b.fit_s
			var fx: float = b.fit_x
			var fy: float = b.fit_y
			for i in shown:
				var d := segs[i * 5 + 4]
				var lc := Kit.BONE.lerp(Kit.GOOD, clampf(d / 4.0, 0.0, 1.0))
				n.draw_line(Vector2(fx + segs[i * 5] * fs, fy + segs[i * 5 + 1] * fs),
					Vector2(fx + segs[i * 5 + 2] * fs, fy + segs[i * 5 + 3] * fs), lc, maxf(0.6, 2.4 - d * 0.5))
			_txt(n, "F → " + String(D.rule), 4.0, 11.0, Kit.TARGET)
			_txt(n, "n = %d · |s| = %d · angle %.1f°" % [iter, (b.sentence as String).length(), float(b.ang)], w - 4.0, 11.0, Color(0.91, 0.898, 0.957, 0.55), "right")
			_txt(n, D.label, w / 2.0, h - 6.0, Color(0.91, 0.898, 0.957, 0.55), "center")
