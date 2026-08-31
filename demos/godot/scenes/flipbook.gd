extends Node2D
## THE FLIPBOOK FOLIO — 52 VFX baked into transparent sprite sheets, A to Z twice.
## The full port of the web page (docs/flipbook.html). Every gallery before
## this one drew its effects live, every frame; this one draws each effect
## ONCE — into an off-screen SubViewport with a transparent background —
## then plays it back through Godot's native flipbook machinery:
## the captured sheet becomes an ImageTexture, AtlasTexture regions slice
## it into frames, SpriteFrames stacks them into an animation, and an
## AnimatedSprite2D plays it. That pipeline is exactly what you'd use for
## a hand-drawn PNG sequence from an artist — here the "artist" is _draw().
##
## One page per family (←/→ turns pages). Click a card to replay it from
## frame 0. The filmstrip under each card IS the baked texture; the amber
## cell is the frame being shown. Esc = menu.
##
## Fidelity note: the maths mirrors docs/flipbook.js one-to-one; only the
## glow approximation differs (canvas radial gradients become stacked
## translucent circles, because CanvasItem has no gradient-fill call).

const S := 72                    # baked cell size, px — sheets are (n·S) × S
const COLS := 4
const CELL := Vector2(232, 232)
const STAGE := Vector2(220, 150)
const ORIGIN := Vector2(14, 64)

const FAMS := [
	["GLOW & FLAME", "seamless loops of light — phase = i/N, played additively"],
	["HITS & SLASHES", "one-shots born at a point — clamp the index, bake the last frame empty"],
	["SMOKE, DUST & WATER", "matter, not light — normal blending, transparency doing the real work"],
	["MAGIC & SPARKLE", "offset clocks, counter-rotating layers, and per-frame chaos"],
	["SPEECH & CELEBRATION", "effects that talk to the player — paper, ink, and punctuation"],
]

var effs: Array = []             # the 52 defs (dictionaries), lap 1 then lap 2
var pagedefs: Array = []         # families split into window-sized parts of 8
var cards: Array = []            # per-card runtime state, current page only
var page := 0
var baked := false

const PAGE_CAP := 8              # 4 × 2 cards is what a 960×540 window holds

func _make_pages() -> void:
	pagedefs.clear()
	for fi in FAMS.size():
		var list: Array = effs.filter(func(e): return int(e.fam) == fi)
		var parts := int(ceil(list.size() / float(PAGE_CAP)))
		for pi in parts:
			pagedefs.append({ "fam": fi, "part": pi, "parts": parts,
				"list": list.slice(pi * PAGE_CAP, mini(list.size(), (pi + 1) * PAGE_CAP)) })

## ---------------------------------------------------------------- helpers
## The small drawing kit every bake shares — the web page's frame kit f.*,
## spelled in CanvasItem calls. All positions are cell-local (0..S).

func _glowc(c: CanvasItem, p: Vector2, r: float, col: Color, a := 0.8) -> void:
	r = maxf(r, 0.5)
	for s in 4:                  # stacked discs stand in for a radial gradient
		c.draw_circle(p, r * (1.0 - s * 0.22), Color(col.r, col.g, col.b, a * 0.22))

func _ringc(c: CanvasItem, p: Vector2, r: float, col: Color, w := 1.5) -> void:
	c.draw_arc(p, maxf(r, 0.5), 0.0, TAU, 48, col, w, true)

func _streakc(c: CanvasItem, a: Vector2, b: Vector2, col: Color, w := 2.0) -> void:
	c.draw_line(a, b, col, w, true)

func _starc(c: CanvasItem, p: Vector2, r1: float, r2: float, points: int, col: Color, rot := 0.0) -> void:
	if r1 < 0.7 or r2 < 0.05: return    # sub-pixel stars fail triangulation
	var pts := PackedVector2Array()
	for j in points * 2:
		var r := r1 if j % 2 == 0 else r2
		var ang := rot + (float(j) / (points * 2)) * TAU - TAU / 4.0
		pts.append(p + Vector2(cos(ang), sin(ang)) * r)
	c.draw_colored_polygon(pts, col)

func _ellipsec(c: CanvasItem, p: Vector2, rx: float, ry: float, col: Color, w := 1.5, a0 := 0.0, a1 := TAU) -> void:
	var pts := PackedVector2Array()
	var steps := 40
	for j in steps + 1:
		var ang := a0 + (a1 - a0) * float(j) / steps
		pts.append(p + Vector2(cos(ang) * rx, sin(ang) * ry))
	c.draw_polyline(pts, col, w, true)

## ---------------------------------------------------------------- the 26
## Each def: letter, name, hint, fam (0..4), n frames, fps, loop, add
## (additive playback), and paint: Callable(c, i, n) drawing frame i into
## a cell whose top-left is (0,0) after the painter's transform.

func _make_defs() -> Array:
	var d: Array = []
	var C := S / 2.0             # the cell centre, both axes

	# ---- GLOW & FLAME ----------------------------------------------------
	d.append({ "letter": "A", "name": "Aura", "fam": 0, "n": 12, "fps": 12.0, "loop": true, "add": true,
		"hint": "a breathing halo — phase = i/N, so the loop point is invisible",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			var br := 0.5 - 0.5 * cos(kl * TAU)
			_glowc(c, Vector2(C, C), 18.0 + br * 7.0, Color("8AD9F5"), 0.5 + br * 0.3)
			_ringc(c, Vector2(C, C), 21.0 + br * 5.0, Color(0.54, 0.85, 0.96, 0.5 + br * 0.4), 2.0)
			_ringc(c, Vector2(C, C), 15.0 + br * 3.0, Color(0.91, 0.9, 0.96, 0.25 + br * 0.2), 1.0) })

	var rE := RandomNumberGenerator.new(); rE.seed = 7
	var embers: Array = []
	for j in 10: embers.append([14.0 + rE.randf() * 44.0, rE.randf(), 3.0 + rE.randf() * 5.0, 1.0 + rE.randf() * 1.5])
	d.append({ "letter": "E", "name": "Embers", "fam": 0, "n": 16, "fps": 12.0, "loop": true, "add": true,
		"hint": "ten motes rise on offset clocks — (i/N + offset) mod 1 stays seamless",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			for e in embers:
				var p := fmod(kl + e[1], 1.0)
				var y := S - 9.0 - p * (S - 17.0)
				var x: float = e[0] + sin(p * TAU * 2.0 + e[1] * 9.0) * e[2]
				var a: float = p / 0.15 if p < 0.15 else 1.0 - (p - 0.15) / 0.85
				_glowc(c, Vector2(x, y), e[3] * 2.6, Color("F5A15A"), a * 0.7)
				c.draw_circle(Vector2(x, y), e[3] * 0.8, Color(0.96, 0.76, 0.41, a)) })

	d.append({ "letter": "F", "name": "Flame", "fam": 0, "n": 12, "fps": 14.0, "loop": true, "add": true,
		"hint": "three stacked glows wobbling on offset sines — fire in a 12-frame loop",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			var b := S - 15.0
			var layers := [[0.0, 12.0, Color("F58A5A"), 0.55], [0.9, 8.5, Color("F5A15A"), 0.75], [1.7, 5.5, Color("F5DC96"), 0.95]]
			for L in layers:
				for s in 3:
					var h := s / 3.0
					var wob: float = sin(kl * TAU * 2.0 + L[0] + h * 5.0) * (1.5 + h * 4.5)
					_glowc(c, Vector2(C + wob, b - h * 26.0), L[1] * (1.0 - h * 0.55), L[2], L[3] * (1.0 - h * 0.3))
			_glowc(c, Vector2(C + sin(kl * TAU * 3.0) * 3.0, b - 30.0), 3.0, Color("F5DC96"), 0.7) })

	d.append({ "letter": "G", "name": "Glint", "fam": 0, "n": 14, "fps": 16.0, "loop": true, "add": true,
		"hint": "a shine travels a fixed diagonal — the whole animation is one moving highlight",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var p := float(i) / n
			var x := 11.0 + p * (S - 22.0)
			var y := S - 15.0 - p * (S - 30.0)
			var a := sin(p * PI)
			_streakc(c, Vector2(x - 5, y + 5), Vector2(x + 5, y - 5), Color(0.91, 0.9, 0.96, a * 0.85), 2.5)
			_starc(c, Vector2(x, y), 6.0 * a, 1.8 * a, 4, Color(0.96, 0.95, 0.86, a), p * 1.2)
			_glowc(c, Vector2(x, y), 7.5 * a, Color(0.91, 0.9, 0.96), a * 0.5) })

	d.append({ "letter": "O", "name": "Orbit", "fam": 0, "n": 16, "fps": 14.0, "loop": true, "add": true,
		"hint": "three motes at angle kl·2π + j·2π/3 — polar coordinates, pre-computed 16 times",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			_ellipsec(c, Vector2(C, C), 20.0, 11.0, Color(0.54, 0.85, 0.96, 0.18), 1.0)
			for j in 3:
				var a := kl * TAU + j * TAU / 3.0
				for s in range(1, 4):
					var ta := a - s * 0.22
					c.draw_circle(Vector2(C + cos(ta) * 20.0, C + sin(ta) * 11.0), 1.7 - s * 0.4, Color(0.54, 0.85, 0.96, 0.5 - s * 0.13))
				var pp := Vector2(C + cos(a) * 20.0, C + sin(a) * 11.0)
				_glowc(c, pp, 4.5, Color("8AD9F5"), 0.8)
				c.draw_circle(pp, 2.0, Color("E8E5F4")) })

	# ---- HITS & SLASHES --------------------------------------------------
	var rB := RandomNumberGenerator.new(); rB.seed = 11
	var rays: Array = []
	for j in 12: rays.append([(j / 12.0) * TAU + rB.randf() * 0.3, 0.75 + rB.randf() * 0.5])
	d.append({ "letter": "B", "name": "Burst", "fam": 1, "n": 10, "fps": 20.0, "loop": false, "add": true,
		"hint": "twelve streaks race outward and die — i clamps at N−1 instead of wrapping",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var k := float(i) / (n - 1)
			if k < 0.22: _glowc(c, Vector2(C, C), 12.0 * (1.0 - k / 0.22), Color(0.96, 0.95, 0.86), 0.95)
			for r in rays:
				var d0: float = pow(k, 0.65) * 27.0 * r[1]
				var d1: float = d0 + (1.0 - k) * 7.0 + 1.5
				var dir := Vector2(cos(r[0]), sin(r[0]))
				_streakc(c, Vector2(C, C) + dir * d0, Vector2(C, C) + dir * d1,
					Color(0.96, 0.63, 0.35, 1.0 - k), 1.8 * (1.0 - k * 0.6)) })

	d.append({ "letter": "I", "name": "Impact", "fam": 1, "n": 8, "fps": 24.0, "loop": false, "add": true,
		"hint": "a thinning shock ring + a shrinking star — the standard hit, in 8 frames",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var k := float(i) / (n - 1)
			_ringc(c, Vector2(C, C), 4.5 + k * 26.0, Color(0.91, 0.9, 0.96, 1.0 - k), 3.0 * (1.0 - k) + 0.5)
			_starc(c, Vector2(C, C), 15.0 * (1.0 - k * 0.85), 4.5 * (1.0 - k * 0.85), 4, Color(0.96, 0.95, 0.86, 1.0 - k * k), k * 0.5)
			for j in 4:
				var a := j * TAU / 4.0 + 0.4
				var dd := 13.0 + k * 17.0
				var dir := Vector2(cos(a), sin(a))
				_streakc(c, Vector2(C, C) + dir * dd, Vector2(C, C) + dir * (dd + 4.5), Color(0.91, 0.9, 0.96, 0.7 - k * 0.7), 1.2) })

	d.append({ "letter": "K", "name": "Kapow", "fam": 1, "n": 10, "fps": 18.0, "loop": false, "add": false,
		"hint": "a comic star pops past full size and settles — overshoot baked into the scale curve",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var k := float(i) / (n - 1)
			if k > 0.88: return
			var over := 1.7 * k * (2.0 - k) - 0.7 * k * k
			var r := 22.0 * maxf(0.0, over)
			var a := 1.0 if k < 0.7 else 1.0 - (k - 0.7) / 0.18
			_starc(c, Vector2(C, C), r, r * 0.5, 9, Color(0.96, 0.76, 0.41, a), k * 0.35)
			_starc(c, Vector2(C, C), r * 0.72, r * 0.36, 9, Color(0.96, 0.54, 0.54, a), k * 0.35) })

	d.append({ "letter": "N", "name": "Nova", "fam": 1, "n": 10, "fps": 20.0, "loop": false, "add": true,
		"hint": "flash shrinks while the ring expands — two curves crossing is the whole effect",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var k := float(i) / (n - 1)
			_glowc(c, Vector2(C, C), 15.0 * (1.0 - k), Color(0.96, 0.95, 0.86), (1.0 - k) * 0.95)
			_ringc(c, Vector2(C, C), 4.0 + smoothstep(0.0, 1.0, k) * 27.0, Color(0.96, 0.76, 0.41, 1.0 - k), 2.4 * (1.0 - k) + 0.5)
			_ringc(c, Vector2(C, C), 4.0 + smoothstep(0.0, 1.0, maxf(0.0, k - 0.25)) * 24.0, Color(0.96, 0.63, 0.35, 0.7 - k * 0.7), 1.2) })

	d.append({ "letter": "T", "name": "Trailslash", "fam": 1, "n": 9, "fps": 24.0, "loop": false, "add": true,
		"hint": "an arc sweeps from angle a to b — the ghost arcs behind it are baked motion blur",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var k := float(i) / (n - 1)
			var ke := smoothstep(0.0, 1.0, k)
			var ang := -2.4 + 2.9 * ke
			var fade := 1.0 if k < 0.75 else 1.0 - (k - 0.75) / 0.25
			for s in 4:
				var ga := ang - s * 0.28
				if ga < -2.4: continue
				c.draw_arc(Vector2(C, C), 22.0, ga - 0.5, ga + 0.08, 16,
					Color(0.91, 0.9, 0.96, fade * (0.8 - s * 0.2)), 4.5 - s * 1.0, true)
			_glowc(c, Vector2(C, C) + Vector2(cos(ang), sin(ang)) * 22.0, 5.0, Color(0.96, 0.95, 0.86), fade * 0.9) })

	d.append({ "letter": "X", "name": "Xslash", "fam": 1, "n": 12, "fps": 22.0, "loop": false, "add": true,
		"hint": "two diagonal cuts land 3 frames apart — a flipbook staggers its own choreography",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var k := float(i) / (n - 1)
			var cuts := [[Vector2(13, 15), Vector2(S - 13, S - 15), k / 0.75],
				[Vector2(S - 13, 16), Vector2(13, S - 16), (k - 0.25) / 0.75]]
			for cut in cuts:
				var kk: float = cut[2]
				if kk <= 0.0 or kk >= 1.0: continue
				var grow := minf(1.0, kk / 0.35)
				var fade := 1.0 if kk < 0.6 else 1.0 - (kk - 0.6) / 0.4
				var m: Vector2 = cut[0] + (cut[1] - cut[0]) * grow
				_streakc(c, cut[0], m, Color(0.54, 0.85, 0.96, fade * 0.5), 6.0 * fade + 1.0)
				_streakc(c, cut[0], m, Color(0.91, 0.9, 0.96, fade), 3.0 * fade + 0.5)
				if grow >= 1.0: _starc(c, cut[1], 4.5 * fade, 1.5 * fade, 4, Color(0.96, 0.95, 0.86, fade), 0.4) })

	# ---- SMOKE, DUST & WATER --------------------------------------------
	var rD := RandomNumberGenerator.new(); rD.seed = 23
	var puffs: Array = []
	for j in 6: puffs.append([PI + (j / 5.0) * PI, 0.6 + rD.randf() * 0.5, 3.0 + rD.randf() * 3.0])
	d.append({ "letter": "D", "name": "Dustkick", "fam": 2, "n": 10, "fps": 16.0, "loop": false, "add": false,
		"hint": "six puffs shove outward from the feet — dust is a one-shot that hugs the ground",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var k := float(i) / (n - 1)
			for p in puffs:
				var dd: float = pow(k, 0.6) * 20.0 * p[1]
				var x: float = C + cos(p[0]) * dd
				var y: float = S - 12.0 - absf(sin(p[0])) * dd * 0.45 - k * 3.0
				var a := (1.0 - k) * 0.55
				c.draw_circle(Vector2(x, y), p[2] * (0.6 + k), Color(0.63, 0.59, 0.55, a))
				c.draw_circle(Vector2(x - 1.5, y - 1.5), p[2] * (0.4 + k * 0.7), Color(0.78, 0.75, 0.71, a * 0.6)) })

	var rJ := RandomNumberGenerator.new(); rJ.seed = 31
	var exh: Array = []
	for j in 7: exh.append([rJ.randf(), (rJ.randf() - 0.5) * 10.0, 2.2 + rJ.randf() * 2.2])
	d.append({ "letter": "J", "name": "Jet", "fam": 2, "n": 12, "fps": 16.0, "loop": true, "add": true,
		"hint": "a thruster cone: hot core loops bright, exhaust puffs drift off below",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			for s in 3:
				var wob := sin(kl * TAU * 2.0 + s * 2.1) * 1.8
				_glowc(c, Vector2(C + wob, 18.0 + 7.5 + s * 6.0), 6.5 - s * 1.5, Color("F5DC96"), 0.85 - s * 0.2)
				_glowc(c, Vector2(C + wob, 18.0 + 9.0 + s * 7.0), 9.5 - s * 1.5, Color("F5A15A"), 0.4)
			for p in exh:
				var q: float = fmod(kl + p[0], 1.0)
				c.draw_circle(Vector2(C + p[1] * q, 18.0 + 19.0 + q * 30.0), p[2] * (0.7 + q), Color(0.67, 0.65, 0.71, (1.0 - q) * 0.4)) })

	var rP := RandomNumberGenerator.new(); rP.seed = 41
	var blobs: Array = []
	for j in 5: blobs.append([(rP.randf() - 0.5) * 15.0, (rP.randf() - 0.5) * 9.0, 5.0 + rP.randf() * 4.5, rP.randf() * 0.2])
	d.append({ "letter": "P", "name": "Poof", "fam": 2, "n": 10, "fps": 15.0, "loop": false, "add": false,
		"hint": "five blobs swell, rise, thin to nothing — the vanish cloud every 2D game owns",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var k := float(i) / (n - 1)
			for b in blobs:
				var kk: float = clampf((k - b[3]) / (1.0 - b[3]), 0.0, 1.0)
				var a := (1.0 - kk) * 0.6
				if a <= 0.0: continue
				var r: float = b[2] * (0.5 + kk * 1.1)
				var p := Vector2(C + b[0] * (1.0 + kk * 0.5), C + b[1] - kk * 7.5)
				c.draw_circle(p, r, Color(0.73, 0.71, 0.76, a))
				c.draw_circle(p - Vector2(r * 0.3, r * 0.3), r * 0.55, Color(0.86, 0.85, 0.9, a * 0.7)) })

	d.append({ "letter": "R", "name": "Ripple", "fam": 2, "n": 14, "fps": 12.0, "loop": true, "add": true,
		"hint": "three flat ellipses expand on offset phases — a water surface in 14 frames",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			for j in 3:
				var p := fmod(kl + j / 3.0, 1.0)
				var r := 3.0 + p * 26.0
				_ellipsec(c, Vector2(C, C), r, r * 0.32, Color(0.54, 0.85, 0.96, (1.0 - p) * 0.7), 1.5 * (1.0 - p) + 0.4) })

	var rU := RandomNumberGenerator.new(); rU.seed = 53
	var gusts: Array = []
	for j in 6: gusts.append([12.0 + rU.randf() * 48.0, rU.randf(), 2.2 + rU.randf() * 3.8])
	d.append({ "letter": "U", "name": "Updraft", "fam": 2, "n": 16, "fps": 14.0, "loop": true, "add": true,
		"hint": "wind made visible: S-curved streaks rise on offset clocks",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			for w in gusts:
				var p: float = fmod(kl + w[1], 1.0)
				var y0: float = S - 6.0 - p * (S - 12.0)
				var a: float = sin(p * PI) * 0.55
				var pts := PackedVector2Array()
				for s in 9:
					var yy: float = y0 + s * 1.7
					pts.append(Vector2(w[0] + sin((yy / S) * TAU * 1.5 + w[1] * 7.0) * w[2], yy))
				c.draw_polyline(pts, Color(0.78, 0.86, 0.94, a), 1.2, true) })

	var rV := RandomNumberGenerator.new(); rV.seed = 61
	var specks: Array = []
	for j in 14: specks.append([rV.randf(), rV.randf() * TAU, 0.8 + rV.randf() * 1.2])
	d.append({ "letter": "V", "name": "Vortex", "fam": 2, "n": 16, "fps": 15.0, "loop": true, "add": true,
		"hint": "dots on a shrinking spiral — radius runs on (kl+offset) mod 1, the drain never empties",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			for sp in specks:
				var p: float = fmod(kl + sp[0], 1.0)
				var rad := 26.0 * (1.0 - p)
				var a: float = sp[1] + p * TAU * 1.6
				var al := p / 0.1 if p < 0.1 else ((1.0 - p) / 0.1 if p > 0.9 else 1.0)
				c.draw_circle(Vector2(C + cos(a) * rad, C + sin(a) * rad * 0.75),
					sp[2] * (1.0 - p * 0.5), Color(0.79, 0.63, 0.96, al * 0.8))
			_glowc(c, Vector2(C, C), 5.0, Color("C9A0F5"), 0.5) })

	# ---- MAGIC & SPARKLE -------------------------------------------------
	var rH := RandomNumberGenerator.new(); rH.seed = 71
	var bits: Array = []
	for j in 9: bits.append([18.0 + rH.randf() * 36.0, rH.randf(), j % 3 == 0, 1.1 + rH.randf() * 1.1])
	d.append({ "letter": "H", "name": "Heal", "fam": 3, "n": 14, "fps": 13.0, "loop": true, "add": true,
		"hint": "green sparkles and little plusses rise off the patient — kind VFX",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			for b in bits:
				var p: float = fmod(kl + b[1], 1.0)
				var y: float = S - 10.0 - p * (S - 20.0)
				var a := sin(p * PI)
				var col := Color(0.61, 0.89, 0.54, a)
				if b[2]:
					_streakc(c, Vector2(b[0] - 2.4, y), Vector2(b[0] + 2.4, y), col, 1.6)
					_streakc(c, Vector2(b[0], y - 2.4), Vector2(b[0], y + 2.4), col, 1.6)
				else:
					_starc(c, Vector2(b[0], y), 3.0 * a, 0.9 * a, 4, col, p * 2.0)
				_glowc(c, Vector2(b[0], y), 3.8 * a, Color("9BE28A"), a * 0.4) })

	d.append({ "letter": "L", "name": "Lightning", "fam": 3, "n": 10, "fps": 24.0, "loop": false, "add": true,
		"hint": "a fresh jagged path EVERY frame — seed + i, because chaos reads as energy",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var k := float(i) / (n - 1)
			if k > 0.8: return
			var a := 1.0 if k < 0.5 else 1.0 - (k - 0.5) / 0.3
			for pass_j in 2:
				var rr := RandomNumberGenerator.new()
				rr.seed = (100 if pass_j == 0 else 200) + i     # re-rolled per frame!
				var x1 := C if pass_j == 0 else C - 13.0
				var yy1 := S - 13.0 if pass_j == 0 else S - 22.0
				var pts := PackedVector2Array([Vector2(C + 6.0, 4.5)])
				for s in range(1, 7):
					var q := s / 7.0
					pts.append(Vector2(C + 6.0 + (x1 - C - 6.0) * q + (rr.randf() - 0.5) * 16.0 * (1.0 - absf(q - 0.5)), 4.5 + (yy1 - 4.5) * q))
				pts.append(Vector2(x1, yy1))
				if pass_j == 0:
					c.draw_polyline(pts, Color(0.54, 0.85, 0.96, a * 0.4), 4.5, true)
					c.draw_polyline(pts, Color(0.91, 0.9, 0.96, a), 1.9, true)
				else:
					c.draw_polyline(pts, Color(0.91, 0.9, 0.96, a * 0.5), 0.9, true)
			_glowc(c, Vector2(C, S - 13.0), 6.5 * a, Color(0.91, 0.9, 0.96), a * 0.9) })

	d.append({ "letter": "M", "name": "Magicircle", "fam": 3, "n": 16, "fps": 12.0, "loop": true, "add": true,
		"hint": "two rune rings counter-rotate in one sheet — layers cost nothing once baked",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			var a0 := kl * TAU                       # one full turn per loop
			_ellipsec(c, Vector2(C, C), 26.0, 13.0, Color(0.79, 0.63, 0.96, 0.8), 1.4)
			_ellipsec(c, Vector2(C, C), 18.0, 9.0, Color(0.79, 0.63, 0.96, 0.5), 1.0)
			for j in 8:                              # outer runes, clockwise
				var a := a0 + j * TAU / 8.0
				var p := Vector2(C + cos(a) * 26.0, C + sin(a) * 13.0)
				_streakc(c, p + Vector2(-2.2, -2.2), p + Vector2(2.2, 2.2), Color(0.91, 0.9, 0.96, 0.85), 1.2)
				_streakc(c, p + Vector2(-2.2, 2.2), p + Vector2(2.2, -2.2), Color(0.91, 0.9, 0.96, 0.85), 1.2)
			for j in 5:                              # inner ticks, ANTI-clockwise
				var b := -a0 * 2.0 + j * TAU / 5.0
				c.draw_circle(Vector2(C + cos(b) * 18.0, C + sin(b) * 9.0), 1.8, Color(0.96, 0.76, 0.41, 0.9))
			var br := 0.5 + 0.5 * sin(kl * TAU * 2.0)
			_glowc(c, Vector2(C, C), 9.0 + br * 3.0, Color("C9A0F5"), 0.3 + br * 0.2) })

	var rS := RandomNumberGenerator.new(); rS.seed = 83
	var tws: Array = []
	for j in 8: tws.append([10.0 + rS.randf() * 51.0, 10.0 + rS.randf() * 51.0, rS.randf(), 2.6 + rS.randf() * 3.0])
	d.append({ "letter": "S", "name": "Sparkle", "fam": 3, "n": 14, "fps": 13.0, "loop": true, "add": true,
		"hint": "eight twinkles, each on its own phase of the same 14-frame clock",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			for tw in tws:
				var p: float = fmod(kl + tw[2], 1.0)
				var a: float = pow(sin(p * PI), 2.0)
				if a < 0.03: continue
				_starc(c, Vector2(tw[0], tw[1]), tw[3] * a, tw[3] * 0.28 * a, 4, Color(0.96, 0.95, 0.86, a), p)
				_glowc(c, Vector2(tw[0], tw[1]), tw[3] * 1.3 * a, Color("8AD9F5"), a * 0.4) })

	d.append({ "letter": "W", "name": "Warp", "fam": 3, "n": 16, "fps": 14.0, "loop": true, "add": true,
		"hint": "a portal: the rim wobbles on a 2-lobe sine while inner arcs spiral inward",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			var a0 := kl * TAU
			var rim := PackedVector2Array()
			for j in 41:                             # 2 lobes × 2 laps = seamless
				var a := (j / 40.0) * TAU
				var r := 22.0 + sin(a * 2.0 + a0 * 2.0) * 2.3
				rim.append(Vector2(C + cos(a) * r * 0.62, C + sin(a) * r))
			c.draw_polyline(rim, Color(0.79, 0.63, 0.96, 0.9), 2.0, true)
			for s in 3:                              # falling-inward arcs
				var p := fmod(kl + s / 3.0, 1.0)
				var rr := 20.0 * (1.0 - p)
				_ellipsec(c, Vector2(C, C), rr * 0.62, rr, Color(0.54, 0.85, 0.96, (1.0 - p) * 0.7), 1.2, a0 * 3.0 + p * 2.0, a0 * 3.0 + p * 2.0 + 2.2)
			_glowc(c, Vector2(C, C), 7.5, Color("C9A0F5"), 0.35) })

	d.append({ "letter": "Z", "name": "Zap", "fam": 3, "n": 12, "fps": 18.0, "loop": true, "add": true,
		"hint": "short arcs crackle AROUND the body, re-rolled each frame",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var rr := RandomNumberGenerator.new()
			rr.seed = 900 + i                        # fresh chaos per frame
			var strong := i % 4 == 0
			for j in 5:
				var a := rr.randf() * TAU
				var r0 := 12.0 + rr.randf() * 7.5
				var p0 := Vector2(C + cos(a) * r0, C + sin(a) * r0)
				var p1 := p0 + Vector2((rr.randf() - 0.5) * 12.0, (rr.randf() - 0.5) * 12.0)
				var pm := (p0 + p1) / 2.0 + Vector2((rr.randf() - 0.5) * 6.0, (rr.randf() - 0.5) * 6.0)
				var al := (0.95 if strong else 0.55) * (0.6 + rr.randf() * 0.4)
				c.draw_polyline(PackedVector2Array([p0, pm, p1]), Color(0.54, 0.85, 0.96, al), 1.6 if strong else 1.0, true)
			if strong: _glowc(c, Vector2(C, C), 15.0, Color("8AD9F5"), 0.3) })

	# ---- SPEECH & CELEBRATION --------------------------------------------
	var rC := RandomNumberGenerator.new(); rC.seed = 93
	var confcols := [Color("F58A8A"), Color("F5C169"), Color("9BE28A"), Color("8AD9F5"), Color("C9A0F5")]
	var flecks: Array = []
	for j in 14: flecks.append([(rC.randf() - 0.5) * 35.0, -22.0 - rC.randf() * 20.0, (rC.randf() - 0.5) * 14.0,
		confcols[j % 5], 2.2 + rC.randf() * 2.2, 1.5 + rC.randf() * 1.5])
	d.append({ "letter": "C", "name": "Confetti", "fam": 4, "n": 14, "fps": 15.0, "loop": false, "add": false,
		"hint": "fourteen paper flecks on ballistic arcs, tumbling by k — a celebration",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var k := float(i) / (n - 1)
			var T := k * 1.15
			for b in flecks:
				var x: float = C + b[0] * T
				var y: float = S - 20.0 + b[1] * T + 32.0 * T * T   # v·t + ½g·t²
				var a := 1.0 if k < 0.75 else 1.0 - (k - 0.75) / 0.25
				# compose with the cell offset — draw_set_transform REPLACES the
				# painter's per-frame translation, it doesn't stack on it
				c.draw_set_transform(Vector2(i * S + x, y), b[2] * T, Vector2.ONE)
				var col: Color = b[3]
				c.draw_rect(Rect2(-b[4] / 2.0, -b[5] / 2.0, b[4], b[5]), Color(col.r, col.g, col.b, a))
			c.draw_set_transform(Vector2(i * S, 0.0), 0.0, Vector2.ONE) })

	d.append({ "letter": "Q", "name": "Question", "fam": 4, "n": 12, "fps": 16.0, "loop": false, "add": false,
		"hint": "a ? pops up with overshoot and hangs — punctuation as a status effect",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var k := float(i) / (n - 1)
			if k > 0.9: return
			var over := (k / 0.3) * 1.25 - pow(k / 0.3, 2.0) * 0.25 if k < 0.3 else 1.0
			var a := 1.0 if k < 0.65 else 1.0 - (k - 0.65) / 0.25
			var bob := sin((k - 0.3) * TAU * 1.4) * 1.5 if k > 0.3 else 0.0
			var fs := int(round(34.0 * over))
			if fs < 1: return
			var font := ThemeDB.fallback_font
			var pos := Vector2(C, C + 6.0 + bob + fs * 0.35)
			for ox in range(-2, 3, 2):               # a fat ink outline, then paint
				for oy in range(-2, 3, 2):
					c.draw_string(font, pos + Vector2(ox, oy), "?", HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color(0.07, 0.06, 0.13, a))
			c.draw_string(font, pos, "?", HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color(0.96, 0.76, 0.41, a)) })

	d.append({ "letter": "Y", "name": "Yell", "fam": 4, "n": 12, "fps": 16.0, "loop": false, "add": true,
		"hint": "three arc-triplets ripple outward from the mouth — sound, drawn",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var k := float(i) / (n - 1)
			var m := Vector2(18.0, C)
			for j in 3:
				var p := k - j * 0.18
				if p <= 0.0 or p > 0.85: continue
				var r := 6.0 + p * 30.0
				var a := (1.0 - p / 0.85) * 0.9
				c.draw_arc(m, r, -0.6, 0.6, 16, Color(0.96, 0.76, 0.41, a), 2.0 * (1.0 - p * 0.6), true)
				c.draw_arc(m, r * 0.8, -0.45, 0.45, 12, Color(0.96, 0.76, 0.41, a), 2.0 * (1.0 - p * 0.6), true)
			if k < 0.3:
				var a2 := 1.0 - k / 0.3
				for s in range(-1, 2):
					_streakc(c, m + Vector2(3.0, s * 7.0), m + Vector2(9.0, s * 10.0), Color(0.91, 0.9, 0.96, a2), 1.2) })

	# ================== THE SECOND LAP — the alphabet again ==================
	# 26 more sheets, so every letter owns two effects. Same baker, same two
	# index lines, same five families: another 26 effects is just 26 ideas.

	# ---- glow & flame, lap two ----
	d.append({ "letter": "A", "name": "Afterimage", "fam": 0, "n": 16, "fps": 14.0, "loop": true, "add": true,
		"hint": "a dasher laps an ellipse; its ghosts are 'where I recently was', baked",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			for s in range(4, -1, -1):
				var a := (kl - s * 0.045) * TAU
				var p := Vector2(C + cos(a) * 22.0, C + sin(a) * 12.0)
				var al := 1.0 - s * 0.22
				_glowc(c, p, (5.0 - s) * al, Color("8AD9F5"), al * 0.7)
				c.draw_circle(p, (3.8 - s * 0.6) * al, Color(0.54, 0.85, 0.96, al))
				if s == 0: c.draw_circle(p + Vector2(1.4, -1.1), 1.0, Color(0.07, 0.06, 0.13)) })

	d.append({ "letter": "C", "name": "Comet", "fam": 0, "n": 16, "fps": 14.0, "loop": true, "add": true,
		"hint": "a head on a tilted ellipse, a tail sampled BACKWARD along the same path",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			for s in range(9, 0, -1):
				var a := (kl - s * 0.022) * TAU
				var q := Vector2(C + cos(a) * 23.0, C + sin(a) * 14.0 - cos(a) * 4.5)
				var al := 1.0 - s / 10.0
				c.draw_circle(q, 2.0 * al + 0.3, Color(0.96, 0.76, 0.41, al * 0.8))
			var ah := kl * TAU
			var h := Vector2(C + cos(ah) * 23.0, C + sin(ah) * 14.0 - cos(ah) * 4.5)
			_glowc(c, h, 6.5, Color("F5DC96"), 0.9)
			_starc(c, h, 3.8, 1.2, 4, Color(0.96, 0.95, 0.86, 0.95), kl * 2.0) })

	d.append({ "letter": "E", "name": "Eclipse", "fam": 0, "n": 16, "fps": 12.0, "loop": true, "add": false,
		"hint": "a dark disc crosses a glow on cos(kl·2π) — passing twice per lap is seamless",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			var x := cos(kl * TAU) * 30.0
			var near := maxf(0.0, 1.0 - absf(x) / 12.0)
			_glowc(c, Vector2(C, C), 15.0 + near * 6.0, Color("F5DC96"), 0.7 + near * 0.3)
			c.draw_circle(Vector2(C, C), 9.5, Color(0.96, 0.86, 0.59, 0.95))
			if near > 0.2:
				for j in 8:
					var a := j * TAU / 8.0 + 0.4
					var dir := Vector2(cos(a), sin(a))
					_streakc(c, Vector2(C, C) + dir * 12.0, Vector2(C, C) + dir * (12.0 + near * 7.0),
						Color(0.96, 0.95, 0.86, near * 0.8), 1.2)
			c.draw_circle(Vector2(C + x, C), 9.0, Color(0.07, 0.06, 0.13, 0.96)) })

	var rF2 := RandomNumberGenerator.new(); rF2.seed = 107
	var flies: Array = []
	for j in 6: flies.append([1 + rF2.randi() % 2, 1 + rF2.randi() % 3, rF2.randf() * TAU, rF2.randf() * TAU, 2 + rF2.randi() % 2, rF2.randf()])
	d.append({ "letter": "F", "name": "Fireflies", "fam": 0, "n": 16, "fps": 12.0, "loop": true, "add": true,
		"hint": "six wanderers on Lissajous paths — whole-number frequencies, or the loop tears",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			for y in flies:
				var x: float = C + sin(y[0] * kl * TAU + y[2]) * 22.0
				var yy: float = C + sin(y[1] * kl * TAU + y[3]) * 18.0
				var a: float = pow(0.5 + 0.5 * sin(y[4] * kl * TAU + y[5] * 9.0), 3.0)
				_glowc(c, Vector2(x, yy), 4.5 * a + 0.8, Color(0.84, 0.96, 0.55), a * 0.8)
				c.draw_circle(Vector2(x, yy), 1.1, Color(0.96, 0.96, 0.78, 0.3 + a * 0.7)) })

	d.append({ "letter": "W", "name": "Wisp", "fam": 0, "n": 12, "fps": 12.0, "loop": true, "add": true,
		"hint": "a bobbing ghost with a phase-lagged tail — hello, key-H sibling",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			var bob := sin(kl * TAU) * 3.0
			_glowc(c, Vector2(C, C - 4.5 + bob), 12.0, Color(0.86, 0.88, 0.96), 0.8)
			_glowc(c, Vector2(C, C + 4.5 + bob * 0.8), 9.0, Color(0.86, 0.88, 0.96), 0.7)
			for s in range(1, 4):
				var lag := sin((kl - s * 0.09) * TAU) * 3.0
				_glowc(c, Vector2(C + sin(s * 1.8) * 2.6, C + 10.5 + s * 3.8 + lag * 0.6),
					5.2 - s * 1.3, Color(0.86, 0.88, 0.96), 0.55 - s * 0.14)
			c.draw_circle(Vector2(C - 3.0, C - 5.2 + bob), 1.4, Color(0.31, 0.78, 0.94, 0.95))
			c.draw_circle(Vector2(C + 3.0, C - 5.2 + bob), 1.4, Color(0.31, 0.78, 0.94, 0.95)) })

	# ---- hits & slashes, lap two ----
	var rI2 := RandomNumberGenerator.new(); rI2.seed = 113
	var spikes2: Array = []
	for j in 5: spikes2.append([(j / 5.0) * TAU - 0.5 + rI2.randf() * 0.4, 15.0 + rI2.randf() * 7.5])
	d.append({ "letter": "I", "name": "Iceshard", "fam": 1, "n": 12, "fps": 18.0, "loop": false, "add": true,
		"hint": "crystals grow, gleam once, then shatter — three acts in one strip",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var k := float(i) / (n - 1)
			if k < 0.55:
				var g := smoothstep(0.0, 1.0, k / 0.55)
				for s in spikes2:
					var tip: Vector2 = Vector2(C, C) + Vector2(cos(s[0]), sin(s[0])) * s[1] * g
					_streakc(c, Vector2(C, C), tip, Color(0.54, 0.85, 0.96, 0.5), 5.0 * g + 0.8)
					_streakc(c, Vector2(C, C), tip, Color(0.75, 0.9, 0.98, 0.9), 2.6 * g + 0.4)
				if k > 0.4: _starc(c, Vector2(C, C), 6.0, 1.9, 4, Color(0.96, 0.98, 1.0, (k - 0.4) / 0.15 * 0.9), 0.3)
			elif k < 0.9:
				var sc := (k - 0.55) / 0.35
				for j2 in spikes2.size():
					var s2: Array = spikes2[j2]
					var dd: float = s2[1] * (0.6 + sc * 0.9)
					var p := Vector2(C + cos(s2[0]) * dd, C + sin(s2[0]) * dd + sc * sc * 7.5)
					_starc(c, p, 3.0 * (1.0 - sc), 1.1 * (1.0 - sc), 4, Color(0.75, 0.9, 0.98, 1.0 - sc), sc * 3.0 + j2) })

	d.append({ "letter": "M", "name": "Meteor", "fam": 1, "n": 12, "fps": 20.0, "loop": false, "add": true,
		"hint": "falls for 60% of the strip, lands for the rest — the impact frame is a hard cut",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var k := float(i) / (n - 1)
			var p0 := Vector2(10.0, 8.0)
			var p1 := Vector2(45.0, 55.0)
			if k < 0.6:
				var p := k / 0.6
				var h := p0 + (p1 - p0) * p
				_streakc(c, h + Vector2(-7.5, -10.5), h, Color(0.96, 0.63, 0.35, 0.7), 4.0)
				_streakc(c, h + Vector2(-12.0, -17.0), h, Color(0.96, 0.54, 0.35, 0.35), 6.0)
				_glowc(c, h, 6.0, Color("F5DC96"), 0.95)
			else:
				var q := (k - 0.6) / 0.4
				if q < 0.35: _glowc(c, p1, 12.0 * (1.0 - q / 0.35), Color(0.96, 0.95, 0.86), 0.95)
				_ringc(c, p1, 3.0 + q * 20.0, Color(0.96, 0.76, 0.41, 1.0 - q), 2.4 * (1.0 - q) + 0.4)
				for j in 5:
					var a := PI + (j / 4.0) * PI + 0.3
					c.draw_circle(p1 + Vector2(cos(a) * q * 17.0, sin(a) * q * 17.0 - q * (1.0 - q) * 14.0),
						1.7 * (1.0 - q), Color(0.96, 0.63, 0.35, 1.0 - q)) })

	var rP2 := RandomNumberGenerator.new(); rP2.seed = 127
	var pdrops: Array = []
	for j in 8: pdrops.append([(j / 8.0) * TAU + rP2.randf() * 0.4, 0.7 + rP2.randf() * 0.5])
	d.append({ "letter": "P", "name": "Pop", "fam": 1, "n": 10, "fps": 18.0, "loop": false, "add": true,
		"hint": "a bubble inflates past its nerve and becomes droplets — state change mid-strip",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var k := float(i) / (n - 1)
			if k < 0.55:
				var p := k / 0.55
				var r := 6.0 + p * 11.0
				var wob := sin(p * 26.0) * p * 1.9
				_ringc(c, Vector2(C, C), r + wob, Color(0.54, 0.85, 0.96, 0.9), 1.6)
				c.draw_circle(Vector2(C - r * 0.35, C - r * 0.4), 1.7, Color(0.96, 0.98, 1.0, 0.8))
			else:
				var q := (k - 0.55) / 0.45
				for dd in pdrops:
					var dist: float = 17.0 * dd[1] * pow(q, 0.7) + 3.0
					c.draw_circle(Vector2(C + cos(dd[0]) * dist, C + sin(dd[0]) * dist + q * q * 6.0),
						1.5 * (1.0 - q) + 0.25, Color(0.54, 0.85, 0.96, 1.0 - q))
				if q < 0.3: _ringc(c, Vector2(C, C), 17.0 + q * 15.0, Color(0.96, 0.98, 1.0, (0.3 - q) / 0.3 * 0.7), 1.2) })

	d.append({ "letter": "Q", "name": "Quake", "fam": 1, "n": 12, "fps": 16.0, "loop": false, "add": false,
		"hint": "cracks spider outward frame by frame — a one-shot that draws MORE as it ages",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var k := float(i) / (n - 1)
			var reach := smoothstep(0.0, 1.0, minf(1.0, k / 0.7))
			for j in 4:
				var rr := RandomNumberGenerator.new()
				rr.seed = 500 + j                        # same path every frame;
				var x := C; var y := S - 20.0            # only its LENGTH grows
				var a := j * TAU / 4.0 + 0.4
				var steps := int((reach if k < 0.85 else 1.0) * 7.0)
				for s in steps:
					var nx := x + cos(a) * 4.0
					var ny := y + sin(a) * 1.8
					_streakc(c, Vector2(x, y), Vector2(nx, ny), Color(0.79, 0.77, 0.89, 0.25), 2.8 - s * 0.15)
					_streakc(c, Vector2(x, y), Vector2(nx, ny), Color(0.12, 0.09, 0.19, 0.9), 1.7 - s * 0.14)
					x = nx; y = ny; a += (rr.randf() - 0.5) * 1.1
				if k > 0.15 and k < 0.85:
					c.draw_circle(Vector2(x, y - 2.2), 2.3 * sin(k * PI), Color(0.63, 0.59, 0.55, 0.35)) })

	d.append({ "letter": "U", "name": "Uppercut", "fam": 1, "n": 10, "fps": 22.0, "loop": false, "add": true,
		"hint": "Trailslash turned vertical: a rising arc, speedlines, a star at the apex",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var k := float(i) / (n - 1)
			var ke := smoothstep(0.0, 1.0, k)
			var ang := 2.6 + (-1.2 - 2.6) * ke
			var fade := 1.0 if k < 0.7 else 1.0 - (k - 0.7) / 0.3
			var pc := Vector2(C + 6.0, C + 6.0)
			for s in 4:
				var ga := ang + s * 0.3
				if ga > 2.6: continue
				c.draw_arc(pc, 22.0, ga - 0.1, ga + 0.45, 14,
					Color(0.91, 0.9, 0.96, fade * (0.85 - s * 0.2)), 4.5 - s * 1.0, true)
			for v in 3:
				_streakc(c, Vector2(15.0 + v * 6.0, S - 14.0 - k * 15.0), Vector2(15.0 + v * 6.0, S - 6.0 - k * 15.0),
					Color(0.54, 0.85, 0.96, fade * 0.5), 1.1)
			if k > 0.5:
				var q := (k - 0.5) / 0.5
				_starc(c, pc + Vector2(cos(-1.2), sin(-1.2)) * 22.0, 5.2 * (1.0 - q) + 0.8, 1.8 * (1.0 - q) + 0.25, 4,
					Color(0.96, 0.95, 0.86, fade), q) })

	d.append({ "letter": "X", "name": "Xstamp", "fam": 1, "n": 10, "fps": 18.0, "loop": false, "add": false,
		"hint": "an X slams down with a squash on landing — scale drawn INTO the frames",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var k := float(i) / (n - 1)
			if k > 0.9: return
			var sc := 1.0; var sy := 1.0
			if k < 0.35: sc = 2.0 - k / 0.35
			elif k < 0.55: sy = 1.0 - sin((k - 0.35) / 0.2 * PI) * 0.25
			var a := (1.0 if k < 0.75 else 1.0 - (k - 0.75) / 0.15) * (0.35 + k if k < 0.35 else 1.0)
			var L := 13.0 * sc
			c.draw_set_transform(Vector2(i * S + C, C), 0.0, Vector2(1.0, sy))
			_streakc(c, Vector2(-L, -L), Vector2(L, L), Color(0.96, 0.54, 0.54, a), 6.0)
			_streakc(c, Vector2(-L, L), Vector2(L, -L), Color(0.96, 0.54, 0.54, a), 6.0)
			_streakc(c, Vector2(-L, -L), Vector2(L, L), Color(0.07, 0.06, 0.13, a * 0.9), 2.2)
			c.draw_set_transform(Vector2(i * S, 0.0), 0.0, Vector2.ONE)
			if k > 0.35 and k < 0.7:
				_ringc(c, Vector2(C, C + 10.5), (k - 0.35) * 45.0, Color(0.63, 0.59, 0.55, 0.7 - k), 1.6) })

	# ---- smoke, dust & water, lap two ----
	var rB2 := RandomNumberGenerator.new(); rB2.seed = 131
	var bubs2: Array = []
	for j in 6: bubs2.append([15.0 + rB2.randf() * 42.0, rB2.randf(), 1.9 + rB2.randf() * 2.2, 2.2 + rB2.randf() * 3.0])
	d.append({ "letter": "B", "name": "Bubbles", "fam": 2, "n": 16, "fps": 12.0, "loop": true, "add": true,
		"hint": "six risers wobble up on offset clocks and pop into ticks at the surface",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			for b in bubs2:
				var p: float = fmod(kl + b[1], 1.0)
				var y: float = S - 9.0 - p * (S - 21.0)
				var x: float = b[0] + sin(p * TAU * 2.0 + b[1] * 8.0) * b[3]
				if p < 0.85:
					_ringc(c, Vector2(x, y), b[2] * (0.7 + p * 0.5), Color(0.54, 0.85, 0.96, 0.4 + p * 0.4), 1.1)
					c.draw_circle(Vector2(x - b[2] * 0.3, y - b[2] * 0.35), 0.7, Color(0.96, 0.98, 1.0, 0.7))
				else:
					var q: float = (p - 0.85) / 0.15
					for s in 4:
						var a := s * TAU / 4.0 + 0.6
						c.draw_circle(Vector2(x + cos(a) * (b[2] + q * 3.0), y + sin(a) * (b[2] + q * 3.0)),
							0.6 * (1.0 - q), Color(0.54, 0.85, 0.96, 1.0 - q)) })

	d.append({ "letter": "D", "name": "Drip", "fam": 2, "n": 12, "fps": 14.0, "loop": false, "add": true,
		"hint": "form, stretch, fall, splash — the classic animation exercise as a texture",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var k := float(i) / (n - 1)
			var topY := 10.0
			var floorY := S - 12.0
			if k < 0.4:
				var p := k / 0.4
				var r := 1.5 + p * 2.6
				c.draw_circle(Vector2(C, topY + r), r, Color(0.54, 0.85, 0.96, 0.9))
				_streakc(c, Vector2(C, topY), Vector2(C, topY + r * (1.0 + p)), Color(0.54, 0.85, 0.96, 0.7), 1.5 + p)
			elif k < 0.7:
				var q := (k - 0.4) / 0.3
				var y := topY + 6.0 + smoothstep(0.0, 1.0, q) * (floorY - topY - 8.0)
				c.draw_set_transform(Vector2(i * S + C, y), 0.0, Vector2(0.7, 1.5))
				c.draw_circle(Vector2.ZERO, 3.4, Color(0.54, 0.85, 0.96, 0.9))
				c.draw_set_transform(Vector2(i * S, 0.0), 0.0, Vector2.ONE)
			else:
				var s := (k - 0.7) / 0.3
				for j in 5:
					var a := PI + (j / 4.0) * PI
					c.draw_circle(Vector2(C + cos(a) * s * 10.5, floorY + sin(a) * s * 7.0 + s * s * 4.5),
						1.2 * (1.0 - s), Color(0.54, 0.85, 0.96, 1.0 - s))
				_ellipsec(c, Vector2(C, floorY + 1.5), 3.0 + s * 12.0, (3.0 + s * 12.0) * 0.3,
					Color(0.54, 0.85, 0.96, (1.0 - s) * 0.8), 1.2) })

	var rG2 := RandomNumberGenerator.new(); rG2.seed = 139
	var spray2: Array = []
	for j in 8: spray2.append([(rG2.randf() - 0.5) * 20.0, rG2.randf() * 0.3, 0.7 + rG2.randf() * 0.6])
	d.append({ "letter": "G", "name": "Geyser", "fam": 2, "n": 12, "fps": 16.0, "loop": false, "add": true,
		"hint": "a water column erupts, crowns, and rains back down its own sides",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var k := float(i) / (n - 1)
			var base := S - 9.0
			var h := smoothstep(0.0, 1.0, minf(1.0, k / 0.45)) * 39.0 * (1.0 if k < 0.75 else 1.0 - (k - 0.75) / 0.35)
			for s in int(h / 4.5):
				_glowc(c, Vector2(C + sin(s * 2.0 + k * 9.0) * 1.2, base - s * 4.5),
					5.2 - s * 0.34, Color("8AD9F5"), 0.7 - s * 0.045)
			if k > 0.3:
				for sp in spray2:
					var q: float = maxf(0.0, (k - 0.3 - sp[1]) / 0.7)
					if q <= 0.0 or q >= 1.0: continue
					c.draw_circle(Vector2(C + sp[0] * q * sp[2], base - h - 1.5 + (q * q * 30.0 - q * 13.5)),
						1.4 * (1.0 - q * 0.6), Color(0.75, 0.92, 0.98, 1.0 - q)) })

	d.append({ "letter": "J", "name": "Jelly", "fam": 2, "n": 12, "fps": 14.0, "loop": true, "add": false,
		"hint": "a blob hops on pure squash-and-stretch — volume conserved, sx = 1/sy",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			var sy := 1.0 + sin(kl * TAU) * 0.28
			var sx := 1.0 / sy
			var hop := maxf(0.0, sin(kl * TAU)) * 7.5
			var base := S - 15.0
			c.draw_circle(Vector2(C, base + 3.0), 8.2 * sx * maxf(0.0, 1.0 - hop / 6.0) * 0.5 + 2.2, Color(0.07, 0.06, 0.13, 0.3))
			c.draw_set_transform(Vector2(i * S + C, base - 6.8 * sy - hop), 0.0, Vector2(sx, sy))
			c.draw_circle(Vector2.ZERO, 8.2, Color(0.61, 0.89, 0.54, 0.85))
			c.draw_circle(Vector2(-2.6, -2.6), 2.4, Color(0.86, 0.98, 0.82, 0.6))
			c.draw_set_transform(Vector2(i * S, 0.0), 0.0, Vector2.ONE)
			c.draw_circle(Vector2(C - 2.6 * sx, base - 8.2 * sy - hop), 1.1, Color(0.07, 0.06, 0.13))
			c.draw_circle(Vector2(C + 2.6 * sx, base - 8.2 * sy - hop), 1.1, Color(0.07, 0.06, 0.13)) })

	var rL2 := RandomNumberGenerator.new(); rL2.seed = 149
	var leafcols := [Color(0.84, 0.66, 0.47), Color(0.77, 0.55, 0.35), Color(0.61, 0.71, 0.43)]
	var lvs2: Array = []
	for j in 5: lvs2.append([13.0 + rL2.randf() * 45.0, rL2.randf(), 6.0 + rL2.randf() * 6.0, 2 + rL2.randi() % 2, leafcols[j % 3]])
	d.append({ "letter": "L", "name": "Leaves", "fam": 2, "n": 16, "fps": 12.0, "loop": true, "add": false,
		"hint": "five leaves tumble down on offset clocks, swaying wider than they fall",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			for L in lvs2:
				var p: float = fmod(kl + L[1], 1.0)
				var y: float = 7.5 + p * (S - 16.0)
				var x: float = L[0] + sin(p * TAU * 2.0 + L[1] * 7.0) * L[2]
				var rot: float = p * TAU * L[3]
				var a: float = p / 0.1 if p < 0.1 else ((1.0 - p) / 0.15 if p > 0.85 else 1.0)
				var col: Color = L[4]
				c.draw_set_transform(Vector2(i * S + x, y), rot, Vector2(1.0, 0.45 + 0.55 * absf(cos(rot))))
				c.draw_circle(Vector2.ZERO, 2.7, Color(col.r, col.g, col.b, a * 0.9))
				c.draw_set_transform(Vector2(i * S, 0.0), 0.0, Vector2.ONE) })

	var rR2 := RandomNumberGenerator.new(); rR2.seed = 151
	var rdrops: Array = []
	for j in 8: rdrops.append([7.5 + rR2.randf() * 57.0, rR2.randf()])
	d.append({ "letter": "R", "name": "Rain", "fam": 2, "n": 12, "fps": 16.0, "loop": true, "add": true,
		"hint": "eight fast streaks, each ending in a micro-splash exactly where it lands",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			var floorY := S - 10.0
			for dd in rdrops:
				var p: float = fmod(kl + dd[1], 1.0)
				if p < 0.75:
					var y: float = 4.5 + (p / 0.75) * (floorY - 10.0)
					_streakc(c, Vector2(dd[0] + 1.5, y), Vector2(dd[0], y + 7.0), Color(0.59, 0.78, 0.96, 0.7), 1.1)
				else:
					var q: float = (p - 0.75) / 0.25
					_streakc(c, Vector2(dd[0] - 1.5 - q * 2.2, floorY - q * 2.2), Vector2(dd[0] - 0.8, floorY),
						Color(0.59, 0.78, 0.96, 1.0 - q), 0.8)
					_streakc(c, Vector2(dd[0] + 0.8, floorY), Vector2(dd[0] + 1.5 + q * 2.2, floorY - q * 2.2),
						Color(0.59, 0.78, 0.96, 1.0 - q), 0.8) })

	var rS2 := RandomNumberGenerator.new(); rS2.seed = 157
	var flakes2: Array = []
	for j in 8: flakes2.append([7.5 + rS2.randf() * 57.0, rS2.randf(), 3.8 + rS2.randf() * 4.5, 0.9 + rS2.randf() * 1.1])
	d.append({ "letter": "S", "name": "Snow", "fam": 2, "n": 16, "fps": 10.0, "loop": true, "add": false,
		"hint": "eight flakes drift on lazy sines — Rain with the clock geared way down",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			for s in flakes2:
				var p: float = fmod(kl + s[1], 1.0)
				var y: float = 4.5 + p * (S - 12.0)
				var x: float = s[0] + sin(p * TAU * 2.0 + s[1] * 9.0) * s[2]
				var a: float = p / 0.1 if p < 0.1 else ((1.0 - p) / 0.1 if p > 0.9 else 1.0)
				c.draw_circle(Vector2(x, y), s[3], Color(0.94, 0.96, 0.99, a * 0.85))
				if s[3] > 1.5:
					for m in 3:
						var am: float = m * PI / 3.0 + p * 2.0
						var arm: Vector2 = Vector2(cos(am), sin(am)) * s[3] * 1.8
						_streakc(c, Vector2(x, y) - arm, Vector2(x, y) + arm, Color(0.94, 0.96, 0.99, a * 0.5), 0.6) })

	d.append({ "letter": "T", "name": "Tornado", "fam": 2, "n": 12, "fps": 14.0, "loop": true, "add": false,
		"hint": "five stacked ellipses lag each other's sway — a funnel from phase offsets alone",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			var base := S - 12.0
			for s in 5:
				var h := s / 4.0
				var y := base - 4.5 - h * 34.0
				var w := 3.8 + h * 16.5
				var x := C + sin(kl * TAU + s * 0.9) * (1.5 + h * 3.8)
				_ellipsec(c, Vector2(x, y), w, w * 0.3, Color(0.75, 0.73, 0.8, 0.75 - h * 0.25), 1.7 - h * 0.6)
			for dd in 3:
				var p := fmod(kl * 2.0 + dd / 3.0, 1.0)
				var lev := 0.3 + dd * 0.25
				var rr := 3.8 + lev * 16.5
				c.draw_circle(Vector2(C + cos(p * TAU) * rr, base - 4.5 - lev * 34.0 + sin(p * TAU) * rr * 0.3),
					1.2, Color(0.84, 0.66, 0.47, 0.8)) })

	# ---- magic & sparkle, lap two ----
	d.append({ "letter": "O", "name": "Omen", "fam": 3, "n": 12, "fps": 12.0, "loop": false, "add": true,
		"hint": "an eye opens, stares, drifts, closes — a one-shot that plays a MOOD",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var k := float(i) / (n - 1)
			if k > 0.92: return
			var open := smoothstep(0.0, 1.0, k / 0.25) if k < 0.25 else (smoothstep(0.0, 1.0, (0.92 - k) / 0.22) if k > 0.7 else 1.0)
			var a := minf(1.0, open + 0.1)
			var w := 19.0
			var hh := 10.5 * open
			for lid in [-1.0, 1.0]:                      # two quadratic lids, sampled
				var pts := PackedVector2Array()
				for t in 17:
					var q := t / 16.0
					var mid := Vector2(C, C + lid * hh * 2.0)
					var p0 := Vector2(C - w, C)
					var p2 := Vector2(C + w, C)
					pts.append(p0.lerp(mid, q).lerp(mid.lerp(p2, q), q))
				c.draw_polyline(pts, Color(0.79, 0.63, 0.96, a * 0.9), 1.6, true)
			if open > 0.3:
				var drift := sin((k - 0.35) * 12.0) * 2.2 if (k > 0.35 and k < 0.6) else 0.0
				_ringc(c, Vector2(C + drift, C), 5.2 * open, Color(0.96, 0.76, 0.41, a), 1.6)
				c.draw_circle(Vector2(C + drift, C), 2.0 * open, Color(0.96, 0.95, 0.86, a))
				_glowc(c, Vector2(C, C), 15.0, Color("C9A0F5"), open * 0.3) })

	var rV2 := RandomNumberGenerator.new(); rV2.seed = 163
	var vbubs: Array = []
	for j in 5: vbubs.append([(rV2.randf() - 0.5) * 25.0, rV2.randf(), 1.2 + rV2.randf() * 1.5])
	d.append({ "letter": "V", "name": "Venom", "fam": 3, "n": 14, "fps": 11.0, "loop": true, "add": true,
		"hint": "a puddle bubbles while sluggish drips feed it — poison as a patient loop",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			var pool := S - 16.0
			_ellipsec(c, Vector2(C, pool), 18.0, 5.6, Color(0.61, 0.89, 0.54, 0.8), 1.6)
			_glowc(c, Vector2(C, pool), 10.5, Color("9BE28A"), 0.3)
			if kl < 0.55:
				var stretch := kl / 0.55
				c.draw_circle(Vector2(C - 6.0, 13.5 + stretch * (pool - 18.0)), 1.8 + stretch, Color(0.61, 0.89, 0.54, 0.9))
				_streakc(c, Vector2(C - 6.0, 12.0), Vector2(C - 6.0, 13.5 + stretch * 4.5), Color(0.61, 0.89, 0.54, 0.5), 1.1)
			elif kl < 0.7:
				var sp := (kl - 0.55) / 0.15
				_ringc(c, Vector2(C - 6.0, pool), sp * 6.0, Color(0.78, 0.96, 0.71, 1.0 - sp), 1.0)
			for b in vbubs:
				var p: float = fmod(kl + b[1], 1.0)
				var a := sin(p * PI)
				_ringc(c, Vector2(C + b[0], pool - p * 3.8), b[2] * a, Color(0.78, 0.96, 0.71, a * 0.7), 0.8) })

	# ---- speech & celebration, lap two ----
	d.append({ "letter": "H", "name": "Hearts", "fam": 4, "n": 14, "fps": 12.0, "loop": true, "add": false,
		"hint": "three hearts rise, sway, and pulse — affection on offset clocks",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			for j in 3:
				var p := fmod(kl + j / 3.0, 1.0)
				var y := S - 12.0 - p * (S - 22.0)
				var x := C + sin(p * TAU + j * 2.0) * 7.0
				var a := sin(p * PI)
				var r := (3.0 + j) * (1.0 + sin(p * TAU * 3.0) * 0.12) * (0.6 + a * 0.4)
				var col := Color(0.96, 0.54, 0.63, a)
				c.draw_circle(Vector2(x - r * 0.5, y - r * 0.35), r * 0.55, col)
				c.draw_circle(Vector2(x + r * 0.5, y - r * 0.35), r * 0.55, col)
				c.draw_colored_polygon(PackedVector2Array([
					Vector2(x - r, y - r * 0.15), Vector2(x + r, y - r * 0.15), Vector2(x, y + r)]), col) })

	d.append({ "letter": "K", "name": "Knockstars", "fam": 4, "n": 12, "fps": 14.0, "loop": true, "add": true,
		"hint": "the dizzy halo: stars circle a tilted ellipse overhead, blinking as they lap",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			var cy := C + 3.0
			_ellipsec(c, Vector2(C, cy), 19.5, 6.8, Color(0.96, 0.76, 0.41, 0.2), 0.8)
			for j in 3:
				var p := fmod(kl + j / 3.0, 1.0)
				var a := p * TAU
				var pos := Vector2(C + cos(a) * 19.5, cy + sin(a) * 6.8)
				var front := sin(a) > 0.0
				var r := 4.1 if front else 2.9
				_starc(c, pos, r, r * 0.42, 5, Color(0.96, 0.76, 0.41, 0.95 if front else 0.6), p * 5.0) })

	d.append({ "letter": "N", "name": "Notes", "fam": 4, "n": 16, "fps": 12.0, "loop": true, "add": false,
		"hint": "three music notes drift up on sway — a disc, a stem, a flag, a song",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			for j in 3:
				var p := fmod(kl + j / 3.0, 1.0)
				var y := S - 13.5 - p * (S - 24.0)
				var x := C - 7.5 + j * 7.5 + sin(p * TAU + j * 2.1) * 5.2
				var a := sin(p * PI)
				var col := Color(0.91, 0.9, 0.96, a)
				c.draw_circle(Vector2(x, y), 2.3, col)
				_streakc(c, Vector2(x + 2.0, y - 0.8), Vector2(x + 2.0, y - 9.0), col, 1.2)
				c.draw_colored_polygon(PackedVector2Array([
					Vector2(x + 2.0, y - 9.0), Vector2(x + 6.5, y - 7.2), Vector2(x + 2.0, y - 6.0)]), col) })

	d.append({ "letter": "Y", "name": "Yoyo", "fam": 4, "n": 16, "fps": 14.0, "loop": true, "add": false,
		"hint": "drop, sleep, snap back — a piecewise clock where each act gets its own easing",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var p := float(i) / n
			var topY := 10.5
			var botY := S - 16.0
			var y := topY
			var spin := 0.0
			if p < 0.3: y = topY + smoothstep(0.0, 1.0, p / 0.3) * (botY - topY)
			elif p < 0.6:
				y = botY
				spin = (p - 0.3) / 0.3
			elif p < 0.85: y = botY - smoothstep(0.0, 1.0, (p - 0.6) / 0.25) * (botY - topY)
			_streakc(c, Vector2(C, topY - 4.5), Vector2(C, y - 4.5), Color(0.79, 0.77, 0.89, 0.6), 0.8)
			c.draw_circle(Vector2(C, y), 5.2, Color(0.96, 0.54, 0.54, 0.95))
			_ringc(c, Vector2(C, y), 5.2, Color(0.07, 0.06, 0.13, 0.5), 1.2)
			c.draw_circle(Vector2(C, y), 1.5, Color(0.96, 0.95, 0.86, 0.9))
			if spin > 0.0:
				for s in 3:
					var a := spin * 15.0 + s * TAU / 3.0
					var dir := Vector2(cos(a), sin(a))
					_streakc(c, Vector2(C, y) + dir * 6.8, Vector2(C, y) + dir * 9.0, Color(0.96, 0.76, 0.41, 0.7), 0.9) })

	d.append({ "letter": "Z", "name": "Zzz", "fam": 4, "n": 14, "fps": 10.0, "loop": true, "add": false,
		"hint": "three Z glyphs climb a sleepy sine, each bigger than the last",
		"paint": func(c: CanvasItem, i: int, n: int) -> void:
			var kl := float(i) / n
			var font := ThemeDB.fallback_font
			for j in 3:
				var p := fmod(kl + j / 3.0, 1.0)
				var y := S - 15.0 - p * (S - 26.0)
				var x := C - 4.5 + sin(p * TAU + j) * 6.0 + j * 3.0
				var a := sin(p * PI) * 0.9
				var fs := int(round(8.0 + p * 8.0 + j * 1.5))
				c.draw_set_transform(Vector2(i * S + x, y), sin(p * TAU * 2.0) * 0.2, Vector2.ONE)
				c.draw_string(font, Vector2(-fs * 0.35, fs * 0.35), "Z", HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color(0.79, 0.77, 0.89, a))
				c.draw_set_transform(Vector2(i * S, 0.0), 0.0, Vector2.ONE) })

	return d

## ---------------------------------------------------------------- baking

class SheetPainter extends Node2D:
	var eff: Dictionary
	var cell: float
	func _draw() -> void:
		for i in int(eff.n):
			draw_set_transform(Vector2(i * cell, 0.0), 0.0, Vector2.ONE)
			eff.paint.call(self, i, int(eff.n))
		draw_set_transform_matrix(Transform2D())

func _ready() -> void:
	effs = _make_defs()
	_make_pages()
	_bake_all()

func _bake_all() -> void:
	var vps: Array = []
	for eff in effs:                             # one SubViewport per sheet,
		var vp := SubViewport.new()              # all rendered in a single frame
		vp.size = Vector2i(int(eff.n) * S, S)
		vp.transparent_bg = true                 # THE point: an alpha background
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var painter := SheetPainter.new()
		painter.eff = eff
		painter.cell = float(S)
		vp.add_child(painter)
		add_child(vp)
		vps.append(vp)
	await RenderingServer.frame_post_draw
	for idx in effs.size():
		var img: Image = null
		var tex := (vps[idx] as SubViewport).get_texture()
		if tex: img = tex.get_image()
		if img == null or img.is_empty():        # headless test runs render nothing
			img = Image.create(int(effs[idx].n) * S, S, false, Image.FORMAT_RGBA8)
		effs[idx]["sheet"] = ImageTexture.create_from_image(img)
		vps[idx].queue_free()
	baked = true
	_build_page()

## ---------------------------------------------------------------- cards

func _build_page() -> void:
	for card in cards:
		(card.spr as AnimatedSprite2D).queue_free()
	cards.clear()
	var list: Array = pagedefs[page].list
	for i in list.size():
		var eff: Dictionary = list[i]
		var cellpos := ORIGIN + Vector2((i % COLS) * CELL.x, floorf(i / float(COLS)) * CELL.y)
		var rect := Rect2(cellpos + Vector2(6, 0), STAGE)

		var frames := SpriteFrames.new()         # Godot's native flipbook stack:
		frames.add_animation("fx")               # sheet → AtlasTexture regions →
		frames.set_animation_speed("fx", eff.fps)
		frames.set_animation_loop("fx", eff.loop)
		for f in int(eff.n):
			var at := AtlasTexture.new()
			at.atlas = eff.sheet
			at.region = Rect2(f * S, 0, S, S)
			frames.add_frame("fx", at)

		var spr := AnimatedSprite2D.new()        # → SpriteFrames → AnimatedSprite2D
		spr.sprite_frames = frames
		spr.position = rect.position + Vector2(STAGE.x / 2.0, 74.0)
		spr.scale = Vector2(1.15, 1.15)
		if eff.add:                              # light adds up; soot must not
			var mat := CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			spr.material = mat
		spr.play("fx")
		add_child(spr)
		cards.append({ "eff": eff, "spr": spr, "rect": rect, "wait": 0.0 })

func _process(delta: float) -> void:
	if not baked: return
	for card in cards:
		var spr: AnimatedSprite2D = card.spr
		if not card.eff.loop and not spr.is_playing():
			card.wait += delta                   # polite one-shot auto-replay
			if card.wait > 1.1:
				card.wait = 0.0
				spr.play("fx")
	queue_redraw()

func _draw() -> void:
	var pd: Dictionary = pagedefs[page] if not pagedefs.is_empty() else { "fam": 0, "part": 0, "parts": 1 }
	var part := " · part %d/%d" % [int(pd.part) + 1, int(pd.parts)] if int(pd.parts) > 1 else ""
	draw_string(ThemeDB.fallback_font, Vector2(14, 24),
		"THE FLIPBOOK FOLIO — 52 VFX baked into transparent sprite sheets — %s%s (%d/%d): %s" %
		[FAMS[pd.fam][0], part, page + 1, pagedefs.size(), FAMS[pd.fam][1]],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.66, 0.64, 0.77))
	draw_string(ThemeDB.fallback_font, Vector2(14, 42),
		"←/→ turn the page · click a card to replay from frame 0 · the strip below each card IS the baked texture · Esc = menu",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.52, 0.5, 0.62))
	if not baked:
		draw_string(ThemeDB.fallback_font, Vector2(14, 80), "baking 26 sheets…",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.52, 0.5, 0.62))
		return
	for card in cards:
		var r: Rect2 = card.rect
		var eff: Dictionary = card.eff
		var spr: AnimatedSprite2D = card.spr
		# the little scene the sheet composites over
		draw_rect(Rect2(r.position, Vector2(STAGE.x, 122)), Color(0.08, 0.065, 0.13))
		draw_line(r.position + Vector2(0, 108), r.position + Vector2(STAGE.x, 108), Color(0.79, 0.77, 0.89, 0.4), 1.5)
		draw_circle(r.position + Vector2(STAGE.x / 2.0, 100.0), 7.0, Color("8AD9F5"))
		draw_circle(r.position + Vector2(STAGE.x / 2.0 + 2.5, 98.0), 1.6, Color(0.07, 0.06, 0.13))
		# the filmstrip — the actual baked texture, read head on the current frame
		var strip := Rect2(r.position + Vector2(0, 126), Vector2(STAGE.x, 18))
		var cw := strip.size.x / float(eff.n)
		for f in int(eff.n):                     # checkerboard = "transparent here"
			var cx := strip.position.x + f * cw
			draw_rect(Rect2(cx, strip.position.y, cw, strip.size.y), Color(0.14, 0.13, 0.2))
			for yy in 3:
				for xx in int(cw / 6.0):
					if (xx + yy) % 2 == 0:
						draw_rect(Rect2(cx + xx * 6.0, strip.position.y + yy * 6.0, 6.0, 6.0), Color(0.17, 0.16, 0.24))
		draw_texture_rect(eff.sheet, strip, false)
		for f in int(eff.n):
			draw_rect(Rect2(strip.position.x + f * cw, strip.position.y, cw, strip.size.y), Color(0.59, 0.57, 0.75, 0.25), false, 1.0)
		draw_rect(Rect2(strip.position.x + spr.frame * cw, strip.position.y, cw, strip.size.y), Color("F5C169"), false, 1.5)
		# frame + name captions
		draw_rect(Rect2(r.position, Vector2(STAGE.x, 144)), Color(0.35, 0.33, 0.47, 0.5), false, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x - 6, r.position.y + 160),
			"%s · %s  (%d × %d px, %.0f fps, %s, %s)" % [eff.letter, eff.name, int(eff.n), S, eff.fps,
				"loop" if eff.loop else "one-shot", "add" if eff.add else "over"],
			HORIZONTAL_ALIGNMENT_CENTER, STAGE.x + 12, 11, Color(0.72, 0.7, 0.82))
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x - 6, r.position.y + 174),
			eff.hint, HORIZONTAL_ALIGNMENT_CENTER, STAGE.x + 12, 9, Color(0.5, 0.48, 0.6))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for card in cards:
			if (card.rect as Rect2).grow(6.0).has_point(event.position):
				(card.spr as AnimatedSprite2D).stop()
				(card.spr as AnimatedSprite2D).play("fx")
				card.wait = 0.0
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/menu.tscn")
			KEY_RIGHT, KEY_PAGEDOWN:
				page = (page + 1) % pagedefs.size()
				if baked: _build_page()
			KEY_LEFT, KEY_PAGEUP:
				page = (page - 1 + pagedefs.size()) % pagedefs.size()
				if baked: _build_page()
