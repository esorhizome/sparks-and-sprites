extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
## WATER — ten buttons, ported from the web bestiary.

const TITLE := "Water"
const BLURB := "bubbles, ripples, rain, and everything that sloshes"
const DEFS := [
	{ "id": "bubble_tank", "name": "Bubble tank", "hint": "bubbles rise on buoyancy against drag — the big ones faster — and wobble on a sideways spring kicked at release; press to pop them all" },
	{ "id": "fizz", "name": "Fizz", "hint": "champagne streams of micro-bubbles; press to overflow with foam" },
	{ "id": "ripple_pool", "name": "Ripple pool", "hint": "the face is still water; press to drop a stone in" },
	{ "id": "rain_glass", "name": "Rain on glass", "hint": "droplets bead; a heavy one lets go, gathers speed against the glass, thins as it runs and swallows what it touches; press to sweep the wiper" },
	{ "id": "waterline", "name": "Waterline", "hint": "half-full of sloshing liquid; press to slosh it hard" },
	{ "id": "whirlpool", "name": "Whirlpool", "hint": "a slow spiral current; press to tighten the drain" },
	{ "id": "spring_tide", "name": "Spring tide", "hint": "the sea is a row of masses on springs, each tied to its neighbours and pushed by a travelling wind; press and a crest heaves up over the button, crashes, and rebounds" },
	{ "id": "deep_sea", "name": "Deep sea", "hint": "marine snow drifts past a jellyfish; press for a biolume flash" },
	{ "id": "waterfall", "name": "Waterfall", "hint": "a sheet of water pours down the face; press to splash the base" },
	{ "id": "squirt", "name": "Squirt", "hint": "a drip forms at the corner; press to fire the water jet" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	var r: Rect2 = b.rect
	match b.id:
		"bubble_tank":
			b.D = { "buoy": 24.0,       # buoyancy per px of radius, px/s² — bigger bubbles pull harder
				"drag": 6.0,            # drag, 1/s — terminal rise = buoy·r/drag, reached in ~1/drag s
				"kx": 40.0,             # the sideways spring toward the line it rose from, 1/s² (a 1 s wobble)
				"zeta": 0.08,           # its damping as a fraction of critical — the wobble dies over a few swings
				"kick": 30.0 }          # the sideways kick as it lets go of the glass, px/s
			# a bubble is a body: buoyancy (∝ radius) up, drag (∝ speed) down, so it
			# accelerates from rest to a terminal speed a fraction of a second after
			# release. its wobble is the same body on a soft sideways spring around the
			# line it rose from, kicked once as it lets go — the zigzag decays as it
			# climbs, and no two bubbles share a clock.
			for i in 9:
				_spawn_bubble(b, randf_range(8, r.size.x - 8), randf_range(8, r.size.y - 4), randf_range(2, 6))
		"fizz":
			b.jets = [r.size.x * 0.18, r.size.x * 0.39, r.size.x * 0.6, r.size.x * 0.81]
		"waterline":
			b.tilt = 0.0
			b.tilt_v = 0.0
		"whirlpool":
			b.motes = []
			for i in 22:
				b.motes.append({ "a": randf_range(0, TAU), "r": randf_range(10, r.size.x * 0.6),
					"v": randf_range(0.5, 1.2), "prev": Vector2.ZERO })
			b.spin = 1.0
		"deep_sea":
			b.snow = []
			for i in 16:
				b.snow.append({ "pos": Vector2(randf_range(0, r.size.x), randf_range(0, r.size.y)), "v": randf_range(3, 9) })
		"rain_glass":
			b.D = { "g": 60.0,          # the pull per px of radius, px/s² — heavier drops run harder
				"stop": 1.0,            # the radius below which the glass wins and a runner stalls, px
				"fric": 2.0,            # the glass's drag, 1/s — terminal speed = g·(r − stop)/fric
				"thin": 0.012,          # radius shed per px run — the drop leaves itself behind as a trail
				"jitter": 60.0,         # sideways jostle, px/s² — a random force, damped like everything else
				"heavy": 1.4 }          # only drops this big can let go
			# a runner is a body: gravity (scaled by how much water it is) against the
			# glass's drag, so it accelerates toward a terminal speed instead of moving
			# at one. running costs it mass — the trail — so it thins, its pull fades,
			# and below the stop radius the drag wins and it beads up again, unless it
			# has swallowed a bead on the way and grown heavier.
			for i in 14:
				b.parts.append({ "kind": "drop", "pos": Vector2(randf_range(4, r.size.x - 4), randf_range(4, r.size.y - 4)),
					"r": randf_range(1, 3), "run": 0.0, "vel": Vector2.ZERO })
			b.wiper = -1.0
		"spring_tide":
			b.D = { "n": 28,            # surface masses across the width
				"k": 60.0,              # neighbour coupling, 1/s² — how stiffly the surface hangs together
				"rest": 8.0,            # the pull back to sea level, 1/s² (ω ≈ 2.8 rad/s: a 2.2 s heave)
				"zeta": 0.2,            # damping as a fraction of critical, on that heave — under 1, so it rebounds
				"wind": 60.0,           # the travelling wind push, px/s²
				"windK": 0.35,          # its wavelength, radians per mass
				"windW": 2.5,           # its speed, rad/s — off the row's resonance, so the ripple stays small
				"surge": 260.0 }        # the press: upward speed injected under the crest, px/s (height ≈ surge/ω)
			# one mass-spring row. every point is pulled back toward sea level and
			# toward the average of its two neighbours; the wind is a force that
			# travels along the row. the press does not lift the sheet — it throws
			# the middle masses upward, and the coupling spreads that into a crest
			# that climbs, breaks over the button, drops through sea level into a
			# trough, and rings out over a couple of seconds.
			var hgt := PackedFloat32Array()  # sized here: a packed array read back from b is a copy
			var vel := PackedFloat32Array()
			hgt.resize(int(b.D.n))
			vel.resize(int(b.D.n))
			b.hgt = hgt                     # height above sea level, px (up is −)
			b.vel = vel
		"squirt":
			b.drip = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"bubble_tank":
			for p in b.parts.duplicate():
				if p.kind == "bub":
					b.parts.append({ "kind": "pop", "pos": p.pos, "r": p.r, "life": 1.0 })
			b.parts = b.parts.filter(func(p): return p.kind != "bub")
		"fizz":
			for i in 22:
				b.parts.append({ "kind": "foam", "pos": Vector2(randf_range(0, r.size.x), randf_range(-2, 4)),
					"vel": Vector2(randf_range(-24, 24), randf_range(-50, -10)), "r": randf_range(2, 4.5), "life": 1.0 })
		"ripple_pool":
			b.parts.append({ "kind": "ring", "pos": Vector2(clampf(pos.x, 4, r.size.x - 4), clampf(pos.y, 4, r.size.y - 4)),
				"r": 2.0, "life": 1.0, "big": true })
		"rain_glass":
			b.wiper = 0.0
		"waterline":
			b.tilt_v += randf_range(1.2, 2.0) * (-1.0 if randf() < 0.5 else 1.0)
		"whirlpool":
			b.spin = 3.2
		"spring_tide":
			var vel: PackedFloat32Array = b.vel
			var n := vel.size()
			for i in n:                     # a gaussian bump of upward speed under the middle of the row
				var g: float = exp(-pow((i - (n - 1) / 2.0) / (n * 0.18), 2.0))
				vel[i] -= float(b.D.surge) * g
			b.vel = vel
			for i in 12:
				b.parts.append({ "kind": "foam", "pos": Vector2(randf_range(0, r.size.x), randf_range(-6, 10)),
					"vel": Vector2(randf_range(-30, 30), randf_range(-70, -20)), "r": 1.8, "life": 1.0 })
		"deep_sea":
			b.press_v = 1.0
		"waterfall":
			for i in 14:
				b.parts.append({ "kind": "splash", "pos": Vector2(randf_range(0, r.size.x), r.size.y),
					"vel": Vector2(randf_range(-50, 50), randf_range(-90, -30)), "life": 1.0 })
		"squirt":
			for i in 16:
				b.parts.append({ "kind": "jet", "pos": Vector2(4, r.size.y - 4),
					"vel": Vector2(randf_range(120, 190), randf_range(-160, -110)), "life": 1.0 })
			b.drip = 0.0

static func tick(b: Dictionary, dt: float, t: float) -> void:
	b.press_v = maxf(0.0, b.press_v - dt * (0.7 if b.id == "spring_tide" else 1.2))
	var r: Rect2 = b.rect
	match b.id:
		"bubble_tank":
			var bubs := 0
			for p in b.parts:
				if p.kind == "bub":
					bubs += 1
					_rise(b, p, dt)
					if p.pos.y < p.r + 2.0:
						p.kind = "pop"
						p.life = 1.0
				else:
					p.life -= dt * 3.0
					p.r += 14.0 * dt
			if bubs < 9 and randf() < 0.15:
				_spawn_bubble(b, randf_range(8, r.size.x - 8), r.size.y - 4.0, randf_range(2, 6))
			b.parts = b.parts.filter(func(p): return p.kind == "bub" or p.life > 0.0)
		"fizz":
			for jx in b.jets:
				if randf() < 0.7:
					b.parts.append({ "kind": "fizz", "pos": Vector2(jx + randf_range(-2, 2), r.size.y - 3.0), "life": 1.0 })
			for p in b.parts:
				if p.kind == "fizz":
					p.pos.y -= 55.0 * dt
					p.pos.x += sin(p.pos.y * 0.4) * 6.0 * dt
					p.life -= dt * 0.8
				else:
					p.pos += p.vel * dt
					p.vel.y += 30.0 * dt
					p.life -= dt * 0.9
			b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.pos.y > -6.0)
		"ripple_pool":
			if randf() < 0.012:
				b.parts.append({ "kind": "ring", "pos": Vector2(randf_range(10, r.size.x - 10), randf_range(8, r.size.y - 8)),
					"r": 1.0, "life": 0.6, "big": false })
			for p in b.parts:
				p.r += (40.0 if p.big else 16.0) * dt
				p.life -= dt * (0.8 if p.big else 0.5)
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"rain_glass":
			var D: Dictionary = b.D
			if b.parts.size() < 18 and randf() < 0.2:
				b.parts.append({ "kind": "drop", "pos": Vector2(randf_range(4, r.size.x - 4), randf_range(4, r.size.y - 4)),
					"r": randf_range(1, 3), "run": 0.0, "vel": Vector2.ZERO })
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / sub
			var g: float = D.g
			var stop: float = D.stop
			var fric: float = D.fric
			var thin: float = D.thin
			var jitter: float = D.jitter
			for p in b.parts:
				if p.run <= 0.0 and p.r > float(D.heavy) and randf() < 0.005:
					p.run = 1.0
					p.vel = Vector2(0.0, 1.0)
				if p.run > 0.0:             # a heavy drop breaks loose and slides
					var v: Vector2 = p.vel
					var pos: Vector2 = p.pos
					var rad: float = p.r
					for _s in sub:
						v.y += (g * (rad - stop) - fric * v.y) * h
						v.x += (randf_range(-jitter, jitter) - fric * 3.0 * v.x) * h
						pos += v * h
						rad = maxf(0.6, rad - thin * maxf(0.0, v.y) * h)
					p.vel = v
					p.pos = pos
					p.r = rad
					if v.y <= 0.0:          # it stalled: the glass holds it again
						p.run = 0.0
						p.vel = Vector2.ZERO
					for e in b.parts:       # merging: a runner swallows the beads it touches
						if not is_same(e, p) and e.run <= 0.0 and absf(e.pos.x - pos.x) < rad + e.r and absf(e.pos.y - pos.y) < rad + e.r:
							p.r = minf(4.5, sqrt(p.r * p.r + e.r * e.r))
							e.pos.y = r.size.y + 99.0   # gone: the filter below sweeps it up
			if b.wiper >= 0.0:
				b.wiper += dt * 2.2
				var wx: float = r.size.x * (b.wiper / 1.1)
				b.parts = b.parts.filter(func(p): return absf(p.pos.x - wx) > 10.0)
				if b.wiper > 1.2:
					b.wiper = -1.0
			b.parts = b.parts.filter(func(p): return p.pos.y < r.size.y + 4.0)
		"waterline":
			b.tilt_v += -b.tilt * 26.0 * dt
			b.tilt_v *= pow(0.3, dt)
			b.tilt += b.tilt_v * dt
		"whirlpool":
			b.spin += (1.0 - b.spin) * dt * 0.8
			for m in b.motes:
				m.prev = Vector2(cos(m.a) * m.r, sin(m.a) * m.r * 0.55)
				m.a += m.v * b.spin * dt
				m.r -= 3.5 * b.spin * dt
				if m.r < 6.0:
					m.r = r.size.x * randf_range(0.5, 0.65)
					m.a = randf_range(0, TAU)
					m.prev = Vector2(cos(m.a) * m.r, sin(m.a) * m.r * 0.55)
		"spring_tide":
			_sea_step(b, dt, t)
		"waterfall", "squirt", "fizz2":
			pass
	# shared free-flying particle integration for the throwers
	if b.id in ["spring_tide", "waterfall", "squirt"]:
		for p in b.parts:
			p.pos += p.vel * dt
			p.vel.y += (90.0 if b.id == "spring_tide" else 180.0) * dt
			p.life -= dt * (1.1 if b.id == "spring_tide" else 1.2)
		b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.pos.y < r.size.y + 40.0)
	if b.id == "waterfall" and randf() < 0.8:
		b.parts.append({ "kind": "streak", "pos": Vector2(randf_range(3, r.size.x - 3), -4.0),
			"vel": Vector2(0, randf_range(90, 150)), "life": 0.9 })
	if b.id == "squirt":
		b.drip += dt * 0.8
		if b.drip > 2.6:
			b.parts.append({ "kind": "jet", "pos": Vector2(4, r.size.y - 2), "vel": Vector2(randf_range(-5, 5), 30), "life": 1.4 })
			b.drip = 0.0
	if b.id == "deep_sea":
		for s in b.snow:
			s.pos.y += s.v * dt
			s.pos.x += sin(t + s.pos.y * 0.05) * 2.0 * dt
			if s.pos.y > r.size.y:
				s.pos = Vector2(randf_range(0, r.size.x), -2.0)

## A bubble born at (x, y): it remembers the line it rose from and leaves the
## glass with a random sideways kick — the seed of its wobble.
static func _spawn_bubble(b: Dictionary, x: float, y: float, rad: float) -> void:
	var kick: float = b.D.kick
	b.parts.append({ "kind": "bub", "pos": Vector2(x, y), "x0": x, "r": rad,
		"vel": Vector2(randf_range(-kick, kick), 0.0) })

## One bubble's step, shared with the rhyme: buoyancy − drag upward, the kicked
## spring sideways, symplectic Euler in ≤ 0.02 s steps.
static func _rise(b: Dictionary, p: Dictionary, dt: float) -> void:
	var D: Dictionary = b.D
	var buoy: float = D.buoy
	var drag: float = D.drag
	var kx: float = D.kx
	var dx: float = float(D.zeta) * 2.0 * sqrt(kx)
	var sub := maxi(1, ceili(dt * 50.0))
	var h := dt / sub
	var v: Vector2 = p.vel
	var pos: Vector2 = p.pos
	var x0: float = p.x0
	var rad: float = p.r
	for _s in sub:
		v.y += (-buoy * rad - drag * v.y) * h          # up is −y
		v.x += (kx * (x0 - pos.x) - dx * v.x) * h
		pos += v * h
	p.vel = v
	p.pos = pos

## The tide's row, shared with the rhyme: every mass pulled to sea level and to
## its neighbours' mean, damped, and pushed by a wind that travels along the row.
## ≤ 0.02 s steps keep √(4k + rest)·h well under 2, the leapfrog's limit.
static func _sea_step(b: Dictionary, dt: float, t: float) -> void:
	var D: Dictionary = b.D
	var hgt: PackedFloat32Array = b.hgt
	var vel: PackedFloat32Array = b.vel
	var n := hgt.size()
	var k: float = D.k
	var rest: float = D.rest
	var damp: float = float(D.zeta) * 2.0 * sqrt(rest)
	var wind: float = D.wind
	var wk: float = D.windK
	var ww: float = D.windW
	var lim: float = (b.rect as Rect2).size.y * 3.0
	var sub := maxi(1, ceili(dt * 50.0))
	var h := dt / sub
	for s in sub:
		var ts := t - dt + h * (s + 1)
		for i in n:
			var l := hgt[maxi(i - 1, 0)]
			var rr := hgt[mini(i + 1, n - 1)]
			vel[i] += (k * (l + rr - 2.0 * hgt[i]) - rest * hgt[i] - damp * vel[i]
				+ wind * sin(i * wk - ts * ww)) * h
		for i in n:
			hgt[i] = clampf(hgt[i] + vel[i] * h, -lim, lim)
	b.hgt = hgt
	b.vel = vel

## The sea drawn from its row — two layers of the same heights, the back one
## shallower — plus the foam. Shared with the rhyme, which only renames it.
static func _sea(n: CanvasItem, b: Dictionary, caption: String) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	ElemKit.face(n, r, Color(0.078, 0.07, 0.133, 0.92), Color(0.55, 0.78, 0.92, 0.5))
	ElemKit.label(n, r, caption, Color(0.85, 0.94, 0.99))
	var hgt: PackedFloat32Array = b.hgt
	var cnt := hgt.size()
	var base: float = r.size.y * 1.02
	for layer in 2:
		var poly := PackedVector2Array()
		poly.append(o + Vector2(-4, r.size.y + 8))
		for i in cnt:
			var x: float = -4.0 + (r.size.x + 8.0) * i / (cnt - 1)
			var y: float = base - layer * 5.0 + hgt[i] * (1.0 if layer == 0 else 0.85)
			poly.append(o + Vector2(x, minf(y, r.size.y + 7.0)))
		poly.append(o + Vector2(r.size.x + 4, r.size.y + 8))
		n.draw_colored_polygon(poly, Color(0.16, 0.47, 0.7, 0.45) if layer == 0 else Color(0.31, 0.7, 0.9, 0.5))
	for p in b.parts:
		n.draw_circle(o + p.pos, p.r, Color(0.92, 0.98, 1.0, 0.8 * p.life))

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	match b.id:
		"bubble_tank":
			ElemKit.face(n, r, Color(0.04, 0.1, 0.157, 0.96), Color(0.43, 0.75, 0.9, 0.5))
			for p in b.parts:
				var pos: Vector2 = o + p.pos    # wherever its own spring has carried it
				if p.kind == "bub":
					ElemKit.ellipse(n, pos, p.r, p.r, Color(0.67, 0.86, 0.98, 0.7), 1.0, 0, TAU, 14)
					n.draw_rect(Rect2(pos - Vector2(p.r * 0.4, p.r * 0.4), Vector2(1, 1)), Color(1, 1, 1, 0.8))
				else:
					for k in 4:
						ElemKit.ellipse(n, o + p.pos, p.r, p.r, Color(0.86, 0.96, 1.0, p.life), 1.0,
							k * 1.7, k * 1.7 + 0.9, 6)
			ElemKit.label(n, r, "AQUARIUM", Color(0.81, 0.94, 1.0))
		"fizz":
			ElemKit.face(n, r, Color(0.157, 0.118, 0.04, 0.92), Color(1, 0.86, 0.55, 0.5))
			for p in b.parts:
				if p.kind == "fizz":
					if p.pos.y > 2.0:
						n.draw_rect(Rect2(o + p.pos, Vector2(1.5, 1.5)), Color(1, 0.94, 0.75, 0.6 * p.life))
				else:
					n.draw_circle(o + p.pos, p.r, Color(1, 0.98, 0.92, 0.7 * p.life))
			ElemKit.label(n, r, "CHEERS", Color(1, 0.95, 0.81))
		"ripple_pool":
			ElemKit.face(n, r, Color(0.063, 0.18, 0.27), Color(0.55, 0.78, 0.9, 0.5))
			for p in b.parts:
				for k in 2:
					var rr := maxf(0.5, p.r - k * 6.0)
					ElemKit.ellipse(n, o + p.pos, rr, rr * 0.45, Color(0.75, 0.9, 0.98, p.life * 0.8),
						1.8 if p.big else 1.0)
			var wob: float = sin(t * 20.0) * 1.5 if b.parts.any(func(p): return p.big) else 0.0
			var lr := Rect2(r.position + Vector2(0, wob), r.size)
			ElemKit.label(n, lr, "POND", Color(0.85, 0.94, 0.99))
		"rain_glass":
			ElemKit.face(n, r, Color(0.063, 0.1, 0.15, 0.96), Color(0.59, 0.75, 0.86, 0.5))
			ElemKit.label(n, r, "DRIZZLE", Color(0.82, 0.9, 0.96, 0.85))
			for p in b.parts:
				var pos: Vector2 = o + p.pos
				if p.run > 0.0:             # the trail: as long as the runner is fast
					n.draw_line(pos - Vector2(0, minf(12.0, (p.vel as Vector2).y * 0.2)), pos, Color(0.63, 0.78, 0.9, 0.25), p.r)
				n.draw_circle(pos, p.r, Color(0.75, 0.86, 0.96, 0.6))
			if b.wiper >= 0.0:
				var wx: float = o.x + r.size.x * (b.wiper / 1.1)
				n.draw_line(Vector2(wx, o.y + r.size.y), Vector2(wx - 6, o.y), Color(0.78, 0.82, 0.88, 0.9), 3.0)
		"waterline":
			ElemKit.face(n, r, Color(0.055, 0.078, 0.118, 0.96), Color(0.47, 0.78, 0.86, 0.55))
			var lv := r.size.y * 0.45
			var poly := PackedVector2Array()
			poly.append(o + Vector2(0, r.size.y - 2))
			var x := 0.0
			while x <= r.size.x:
				var k := (x - r.size.x / 2.0) / r.size.x
				var y: float = lv + k * b.tilt * 60.0 + sin(x * 0.11 + t * 3.0) * 1.5 + sin(x * 0.23 - t * 5.0) * 0.8
				poly.append(o + Vector2(x, clampf(y, 4, r.size.y - 2)))
				x += 4.0
			poly.append(o + Vector2(r.size.x, r.size.y - 2))
			n.draw_colored_polygon(poly, Color(0.2, 0.6, 0.8, 0.75))
			ElemKit.label(n, r, "SLOSH", Color(0.87, 0.96, 1.0))
		"whirlpool":
			ElemKit.face(n, r, Color(0.04, 0.086, 0.133, 0.9), Color(0.51, 0.78, 0.9, 0.55))
			for m in b.motes:
				var cur := r.get_center() + Vector2(cos(m.a) * m.r, sin(m.a) * m.r * 0.55)
				n.draw_line(r.get_center() + m.prev, cur, Color(0.55, 0.82, 0.92, 0.6), 1.4)
			ElemKit.label(n, r, "DRAIN", Color(0.84, 0.93, 0.98))
		"spring_tide":
			_sea(n, b, "TIDE")
		"deep_sea":
			ElemKit.face(n, r, Color(0.031, 0.063, 0.118, 0.97), Color(0.47, 0.78, 1.0, 0.4 + pv * 0.6))
			for s in b.snow:
				n.draw_rect(Rect2(o + s.pos, Vector2(1.2, 1.2)), Color(0.7, 0.78, 0.86, 0.25 + pv * 0.5))
			var jx := o.x + r.size.x * 0.5 + sin(t * 0.4) * r.size.x * 0.3
			var jy := o.y + r.size.y * 0.3 + sin(t * 0.9) * 6.0
			ElemKit.glow(n, Vector2(jx, jy), 12.0 + pv * 8.0, Color(0.55, 0.9, 1.0, 0.5 + pv * 0.5), 3)
			for k in range(-2, 3):
				ElemKit.qcurve(n, Vector2(jx + k * 3, jy + 5),
					Vector2(jx + k * 5 + sin(t * 3.0 + k) * 4.0, jy + 13),
					Vector2(jx + k * 6 + sin(t * 2.0 + k * 2) * 6.0, jy + 20),
					Color(0.55, 0.86, 1.0, 0.35 + pv * 0.5), 1.0)
			ElemKit.label(n, r, "ABYSS", Color(0.78, 0.92, 1.0, 0.8 + pv * 0.2))
		"waterfall":
			ElemKit.face(n, r, Color(0.055, 0.094, 0.133, 0.96), Color(0.59, 0.82, 0.92, 0.5))
			for p in b.parts:
				var pos: Vector2 = o + p.pos
				if p.kind == "streak":
					if p.pos.y > 0 and p.pos.y < r.size.y:
						n.draw_line(pos - Vector2(0, 12), pos, Color(0.67, 0.86, 0.96, 0.5), 1.2)
				else:
					n.draw_rect(Rect2(pos, Vector2(1.8, 1.8)), Color(0.82, 0.94, 1.0, p.life))
			ElemKit.ellipse(n, Vector2(r.get_center().x, o.y + r.size.y + 4),
				r.size.x * 0.5 + sin(t * 2.0) * 4.0, 5.0, Color(0.63, 0.84, 0.94, 0.25), 1.0)
			ElemKit.label(n, r, "FALLS", Color(0.87, 0.95, 1.0))
		"squirt":
			ElemKit.face(n, r, Color(0.063, 0.086, 0.133, 0.96), Color(0.51, 0.78, 0.92, 0.5))
			ElemKit.label(n, r, "SQUIRT", Color(0.85, 0.94, 1.0))
			var dp := o + Vector2(4, r.size.y - 2 + b.drip)
			n.draw_set_transform(dp, 0.0, Vector2(1.0, 1.0 + b.drip * 0.4))
			n.draw_circle(Vector2.ZERO, 2.0 + b.drip * 0.8, Color(0.59, 0.82, 0.94, 0.85))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for p in b.parts:
				n.draw_circle(o + p.pos, 1.8, Color(0.67, 0.88, 0.98, minf(1.0, p.life)))
