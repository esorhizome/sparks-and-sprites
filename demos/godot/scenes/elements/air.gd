extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
## AIR & WIND — eight buttons, ported from the web bestiary.

const TITLE := "Air & wind"
const BLURB := "gusts, vortices, smoke, and fog with opinions"
const DEFS := [
	{ "id": "zephyr", "name": "Zephyr", "hint": "breeze lines curve around the button; press for a gust" },
	{ "id": "cyclone", "name": "Cyclone", "hint": "a pet tornado of nine stacked rings, each dragged round and sideways by the one below it, ambling on a spring toward wherever it fancies next; press to feed it and watch the spin climb" },
	{ "id": "smoke_signal", "name": "Smoke signal", "hint": "one puff at a time drifts up; press to send three fast" },
	{ "id": "fog_bank", "name": "Fog bank", "hint": "fog blobs ride a slow drift through the caption, each on a soft spring to its place in it; press and an outward gust throws them apart — they drift back and settle, a little late" },
	{ "id": "updraft", "name": "Updraft", "hint": "leaves ride a thermal past the button; press for a flurry" },
	{ "id": "vacuum", "name": "Vacuum", "hint": "dust falls toward the centre on an inverse-square pull, fighting drag — the near misses whip past and spiral in; press to slam the airlock" },
	{ "id": "sonic_boom", "name": "Sonic boom", "hint": "speed lines shiver behind it; press to break the barrier" },
	{ "id": "windsock", "name": "Windsock", "hint": "a ribbon streams from the corner; press to spike the wind" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	var r: Rect2 = b.rect
	match b.id:
		"zephyr":
			b.winds = []
			for i in 7:
				b.winds.append({ "p": randf(), "lane": randf_range(-1, 1), "v": randf_range(0.2, 0.4) })
		"cyclone":
			b.D = { "spin": 6.0,        # the ground ring's driven spin, rad/s
				"feed": 6.0,            # the extra spin a press asks for, rad/s, fading with the press
				"couple": 8.0,          # how fast each ring's spin chases the ring below, 1/s — the lag climbs the funnel
				"taper": 0.045,         # spin lost per ring going up — the top turns slower than the base
				"kx": 60.0,             # each ring's sideways spring toward the ring below, 1/s² — the funnel whips
				"xzeta": 0.3,           # that spring's damping as a fraction of critical
				"kw": 4.0,              # the wander spring toward the current target, 1/s² (a 3 s amble)
				"wzeta": 0.35,          # its damping — under 1, so the funnel overshoots each new spot
				"retarget": 2.5 }       # seconds between picking a new place to amble to
			# a chain, twice over. the ground ring is driven; every ring above has its
			# own spin that relaxes toward the ring below's (minus a little taper), so
			# a press spins up the base first and the change climbs the funnel. each
			# ring's x is a spring toward the ring below's x, so when the base ambles
			# off the top lags and whips after it. the amble itself is a spring toward
			# a target that jumps somewhere new every few seconds — the overshoot at
			# each arrival is the wander.
			var ang := PackedFloat32Array()  # sized here: a packed array read back from b is a copy
			var w := PackedFloat32Array()
			var X := PackedFloat32Array()
			var VX := PackedFloat32Array()
			for i in 9:
				ang.append(float(i))
				w.append(float(b.D.spin) * pow(1.0 - float(b.D.taper), i))
				X.append(0.0)
				VX.append(0.0)
			b.ang = ang                 # each ring's angle
			b.w = w                     # each ring's spin, rad/s
			b.X = X                     # each ring's x, as an offset from the button's centre
			b.VX = VX                   # and its sideways speed
			b.wx = 0.0                  # the amble: the base's x, its speed, its target, the clock to the next target
			b.wvx = 0.0
			b.wtarget = 0.0
			b.wtimer = 0.0
		"smoke_signal":
			b.timer = 1.0
			b.queue = 0
			b.q_timer = 0.0
		"fog_bank":
			b.D = { "k": 2.0,           # the spring back to a blob's place in the drift, 1/s² (ω ≈ 1.4: a 4 s return)
				"zeta": 0.5,            # damping as a fraction of critical — it comes back with a small overshoot
				"gust": 90.0,           # the press: outward speed, px/s, away from the centre
				"heavy": 0.8,           # how much of the fog thins out at a full parting
				"drift": 1.0 }          # a multiplier on the crawl — the rhyme halves it
			# each blob has a HOME that crawls across at its own drift speed and wraps,
			# and a body on a soft, half-damped spring toward that home, with drag.
			# the press does not move the fog: it gives each body an outward speed and
			# the spring spends the next seconds pulling it back, overshooting a touch.
			# the fog thins where the bodies are far from where they belong.
			b.blobs = []
			for i in 6:
				var home := randf_range(-r.size.x, r.size.x)
				b.blobs.append({ "home": home, "x": home, "vx": 0.0, "oy": randf_range(-10, 10),
					"r": randf_range(12, 22), "v": randf_range(6, 14) })
		"vacuum":
			b.D = { "G": 20000.0,       # the pull's strength, px³/s² — acceleration = G / d²
				"amax": 300.0,          # the cap on that acceleration, px/s², so the centre is no singularity
				"drag": 0.4,            # air drag, 1/s — bleeds orbital speed, so every mote spirals in eventually
				"slam": 30.0,           # the press multiplies the pull by (1 + slam), fading with the press
				"sink": 5.0,            # the radius at which a mote is swallowed and reborn at the rim, px
				"vmax": 600.0 }         # a speed ceiling, px/s — the guard rail for a coarse frame
			# every mote has a velocity. the pull is an acceleration toward the centre
			# that grows as 1/d² (capped), drag takes a fraction of the speed each
			# second, and nothing else touches them. a mote born at the rim with a bit
			# of sideways speed does not fall straight in: it swings past, loops, and
			# drag winds the loop tighter until the sink takes it. the slam raises the
			# pull, not the speed — the speed is what the pull has had time to build.
			b.motes = []
			for i in 22:
				var m := { "pos": Vector2.ZERO, "vel": Vector2.ZERO }
				_reset_mote(b, m)
				m.pos = Vector2(randf_range(-20, r.size.x + 20), randf_range(-20, r.size.y + 20))
				b.motes.append(m)
			b.ring = 0.0
		"windsock":
			b.pts = []
			for i in 11:
				b.pts.append(r.size + Vector2(-2, -r.size.y + 8))
			b.wind = 1.0

static func press(b: Dictionary, _pos: Vector2) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"zephyr", "sonic_boom":
			b.press_v = 1.0
		"fog_bank":
			b.press_v = 1.0                # kept for the rhyme's lantern
			for bl in b.blobs:             # the gust: an outward speed, and the spring does the rest
				bl.vx += float(b.D.gust) * (1.0 if bl.x >= 0.0 else -1.0)
		"cyclone":
			b.press_v = 1.0
			for i in 10:
				b.parts.append({ "a": randf_range(0, TAU), "h": randf(), "va": randf_range(3, 7), "life": 1.0 })
		"smoke_signal":
			b.queue = 3
			b.q_timer = 0.0
		"updraft":
			for i in 10:
				_leaf(b, true)
		"vacuum":
			b.press_v = 1.0
			b.ring = b.rect.size.x * 0.6
		"windsock":
			b.wind = 3.5

static func _leaf(b: Dictionary, burst: bool) -> void:
	var r: Rect2 = b.rect
	b.parts.append({ "pos": Vector2(randf_range(-16, r.size.x + 16), r.size.y + 20.0),
		"v": randf_range(26, 50) * (1.8 if burst else 1.0), "ph": randf_range(0, 9),
		"rot": randf_range(0, 6), "vr": randf_range(-4, 4), "green": randf() < 0.5 })

## A mote reborn at the rim with a little tangential speed — the seed of an orbit.
static func _reset_mote(b: Dictionary, m: Dictionary) -> void:
	var r: Rect2 = b.rect
	var th := randf_range(0, TAU)
	var side := randf_range(-20, 20)
	m.pos = r.size / 2.0 + Vector2(cos(th), sin(th)) * r.size.x * 0.7
	m.vel = Vector2(-sin(th), cos(th)) * side

## One mote's step under a pull of strength `pull` (negative = a push), shared
## with the rhyme: the 1/d² acceleration capped at amax, drag, a speed ceiling.
## Returns the distance from the centre before the step.
static func _mote_step(b: Dictionary, m: Dictionary, h: float, pull: float) -> float:
	var D: Dictionary = b.D
	var r: Rect2 = b.rect
	var d: Vector2 = r.size / 2.0 - m.pos
	var d2 := maxf(1.0, d.length_squared())
	var dist := sqrt(d2)
	var a := clampf(pull / d2, -float(D.amax), float(D.amax))
	var v: Vector2 = m.vel
	v += (d / dist * a - float(D.drag) * v) * h
	var sp := v.length()
	if sp > float(D.vmax):
		v *= float(D.vmax) / sp
	m.vel = v
	m.pos += v * h
	return dist

static func tick(b: Dictionary, dt: float, t: float) -> void:
	b.press_v = maxf(0.0, b.press_v - dt * (0.5 if b.id in ["fog_bank", "cyclone"] else 1.3))
	var r: Rect2 = b.rect
	match b.id:
		"zephyr":
			for w in b.winds:
				w.p += w.v * (1.0 + b.press_v * 3.0) * dt
				if w.p > 1.15:
					w.p = -0.15
					w.lane = randf_range(-1, 1)
		"cyclone":
			var D: Dictionary = b.D
			var spin: float = D.spin
			var feed: float = D.feed
			var couple: float = D.couple
			var taper: float = D.taper
			var kx: float = D.kx
			var kw: float = D.kw
			var dx: float = float(D.xzeta) * 2.0 * sqrt(kx)
			var dw: float = float(D.wzeta) * 2.0 * sqrt(kw)
			var ang: PackedFloat32Array = b.ang
			var w: PackedFloat32Array = b.w
			var X: PackedFloat32Array = b.X
			var VX: PackedFloat32Array = b.VX
			var N := ang.size()
			var lim: float = r.size.x * 2.0
			b.wtimer -= dt
			if b.wtimer <= 0.0:             # somewhere new to amble to
				b.wtarget = randf_range(-1, 1) * r.size.x * 0.55
				b.wtimer = float(D.retarget)
			var wx: float = b.wx
			var wvx: float = b.wvx
			var wtarget: float = b.wtarget
			var power: float = b.press_v
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / sub
			for _s in sub:
				wvx += (kw * (wtarget - wx) - dw * wvx) * h   # the amble
				wx = clampf(wx + wvx * h, -lim, lim)
				w[0] += ((spin + power * feed) - w[0]) * couple * h   # the driven base
				X[0] = wx
				VX[0] = wvx
				for i in range(1, N):       # the chain climbs
					w[i] += (w[i - 1] * (1.0 - taper) - w[i]) * couple * h
					VX[i] += (kx * (X[i - 1] - X[i]) - dx * VX[i]) * h
					X[i] = clampf(X[i] + VX[i] * h, -lim, lim)
				for i in N:
					ang[i] = fmod(ang[i] + w[i] * h, TAU)
			b.wx = wx
			b.wvx = wvx
			b.ang = ang
			b.w = w
			b.X = X
			b.VX = VX
			for p in b.parts:
				p.a += p.va * dt
				p.h += dt * 0.5
				p.life -= dt * 0.7
			b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.h <= 1.0)
		"smoke_signal":
			b.timer -= dt
			if b.timer <= 0.0:
				b.parts.append({ "pos": Vector2(r.size.x / 2.0 + randf_range(-4, 4), -2.0), "r": 4.0, "life": 1.0 })
				b.timer = randf_range(1.8, 2.6)
			if b.queue > 0:
				b.q_timer -= dt
				if b.q_timer <= 0.0:
					b.parts.append({ "pos": Vector2(r.size.x / 2.0 + randf_range(-4, 4), -2.0), "r": 4.0, "life": 1.0 })
					b.queue -= 1
					b.q_timer = 0.22
			for p in b.parts:
				p.pos.y -= 22.0 * dt
				p.pos.x += sin(p.pos.y * 0.15) * 6.0 * dt
				p.r += 7.0 * dt
				p.life -= dt * 0.55
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"fog_bank":
			var D: Dictionary = b.D
			var k: float = D.k
			var damp: float = float(D.zeta) * 2.0 * sqrt(k)
			var drift: float = D.drift
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / sub
			for bl in b.blobs:
				bl.home += bl.v * drift * dt
				if bl.home > r.size.x:      # loop the drift, body and home together
					bl.home -= 2.0 * r.size.x
					bl.x -= 2.0 * r.size.x
				var home: float = bl.home
				var x: float = bl.x
				var vx: float = bl.vx
				for _s in sub:
					vx += (k * (home - x) - damp * vx) * h
					x += vx * h
				bl.x = clampf(x, -3.0 * r.size.x, 3.0 * r.size.x)
				bl.vx = vx
		"updraft":
			if randf() < 0.05:
				_leaf(b, false)
			for p in b.parts:
				p.pos.y -= p.v * dt
				p.pos.x += sin(t * 2.0 + p.ph) * 16.0 * dt
				p.rot += p.vr * dt
			b.parts = b.parts.filter(func(p): return p.pos.y > -24.0)
		"vacuum":
			var D: Dictionary = b.D
			var pull: float = float(D.G) * (1.0 + b.press_v * float(D.slam))
			var sink: float = D.sink
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / sub
			for m in b.motes:
				for _s in sub:
					var dist := _mote_step(b, m, h, pull)
					if dist < sink or dist > r.size.x * 0.9:   # swallowed — or flung clear — and reborn at the rim
						_reset_mote(b, m)
						break
			if b.press_v > 0.0:
				b.ring = maxf(0.0, b.ring - 300.0 * dt)
		"windsock":
			b.wind += (1.0 - b.wind) * dt * 0.8
			var pts: Array = b.pts
			pts[0] = Vector2(r.size.x - 2, 8)
			for i in range(1, pts.size()):
				var target: Vector2 = pts[i - 1] + Vector2(6.0 * b.wind,
					sin(t * (6.0 + b.wind * 2.0) + i * 0.9) * (2.2 + b.wind))
				pts[i] = (pts[i] as Vector2).lerp(target, minf(1.0, dt * 14.0))

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	match b.id:
		"zephyr":
			ElemKit.face(n, r, Color(0.078, 0.1, 0.133, 0.92), Color(0.67, 0.82, 0.9, 0.5))
			ElemKit.label(n, r, "BREEZE", Color(0.87, 0.94, 0.97))
			for w in b.winds:
				var x: float = r.size.x * w.p
				var dodge: float = exp(-pow((x - r.size.x / 2.0) / (r.size.x * 0.45), 2.0))
				var sign_l: float = 1.0 if w.lane >= 0.0 else -1.0
				var y: float = r.size.y / 2.0 + w.lane * r.size.y * 0.35 + dodge * r.size.y * 0.75 * sign_l
				ElemKit.qcurve(n, o + Vector2(x - 14.0 - pv * 10.0, y + 2), o + Vector2(x - 6, y - 1),
					o + Vector2(x, y), Color(0.75, 0.88, 0.96, 0.3 + pv * 0.4), 1.2)
		"cyclone":
			ElemKit.face(n, r, Color(0.078, 0.094, 0.125, 0.92), Color(0.7, 0.78, 0.86, 0.5))
			ElemKit.label(n, r, "TWISTER", Color(0.89, 0.92, 0.95))
			var cx0 := o.x + r.size.x / 2.0
			var X: PackedFloat32Array = b.X
			var ang: PackedFloat32Array = b.ang
			var N := X.size()
			var base_y := o.y + r.size.y + 6.0
			var top_y := o.y - 14.0 - pv * 8.0
			var size_m := 1.0 + pv * 0.8
			for i in N:                      # the funnel: each ring at its own angle and its own x
				var k := i / float(N - 1)
				var y := base_y + (top_y - base_y) * k
				var rad := (2.0 + k * 12.0) * size_m
				var a: float = ang[i]
				ElemKit.ellipse(n, Vector2(cx0 + X[i], y), rad, rad * 0.3,
					Color(0.78, 0.84, 0.9, 0.5 - k * 0.25 + pv * 0.3), 1.4, a, a + 4.0, 10)
			for p in b.parts:                # debris rides the ring at its height
				var y: float = base_y + (top_y - base_y) * p.h
				var rad: float = (2.0 + p.h * 12.0) * size_m
				var cx: float = cx0 + X[mini(N - 1, roundi(p.h * (N - 1)))]
				n.draw_rect(Rect2(Vector2(cx + cos(p.a) * rad, y + sin(p.a) * rad * 0.3), Vector2(2, 2)),
					Color(0.75, 0.71, 0.63, p.life * 0.8))
		"smoke_signal":
			ElemKit.face(n, r, Color(0.094, 0.078, 0.1, 0.92), Color(0.78, 0.75, 0.78, 0.5))
			ElemKit.label(n, r, "SIGNAL", Color(0.91, 0.89, 0.91))
			for p in b.parts:
				n.draw_circle(o + p.pos, p.r, Color(0.78, 0.76, 0.8, 0.3 * p.life))
		"fog_bank":
			ElemKit.face(n, r, Color(0.086, 0.094, 0.125, 0.92), Color(0.75, 0.78, 0.84, 0.5))
			ElemKit.label(n, r, "PEA SOUP", Color(0.89, 0.91, 0.93))
			var heavy: float = b.D.heavy
			for bl in b.blobs:
				var x: float = r.get_center().x + bl.x * 0.6
				var away: float = minf(1.0, absf(bl.x - bl.home) / 40.0)   # thin where the fog is far from home
				ElemKit.glow(n, Vector2(x, r.get_center().y + bl.oy), bl.r,
					Color(0.82, 0.84, 0.88, 0.16 * (1.0 - heavy * away)), 3)
		"updraft":
			ElemKit.face(n, r, Color(0.07, 0.1, 0.078, 0.92), Color(0.67, 0.82, 0.59, 0.5))
			ElemKit.label(n, r, "THERMAL", Color(0.89, 0.94, 0.85))
			for p in b.parts:
				n.draw_set_transform(o + p.pos, p.rot, Vector2(1.0, 0.47))
				n.draw_circle(Vector2.ZERO, 3.4, Color(0.59, 0.75, 0.35, 0.85) if p.green else Color(0.82, 0.63, 0.27, 0.85))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"vacuum":
			ElemKit.face(n, r, Color(0.07, 0.078, 0.11, 0.96), Color(0.63, 0.7, 0.82, 0.5))
			ElemKit.label(n, r, "INHALE", Color(0.86, 0.9, 0.95))
			for m in b.motes:
				n.draw_rect(Rect2(o + m.pos, Vector2(1.5, 1.5)), Color(0.7, 0.76, 0.84, 0.3 + pv * 0.5))
			if pv > 0.0:
				ElemKit.ellipse(n, r.get_center(), b.ring * 1.4, b.ring * 0.8,
					Color(0.75, 0.82, 0.92, pv * 0.6), 1.5)
		"sonic_boom":
			for i in 6:                      # trailing speed lines
				var y := o.y + (i + 0.5) * r.size.y / 6.0
				var len := 10.0 + sin(t * 9.0 + i * 2.0) * 4.0 + pv * 26.0
				n.draw_line(Vector2(o.x - 4, y), Vector2(o.x - 4 - len, y),
					Color(0.7, 0.78, 0.88, 0.25 + pv * 0.5), 1.2)
			var lean := 1.5 + pv * 4.0
			var rr := Rect2(r.position + Vector2(lean, 0), r.size)
			ElemKit.face(n, rr, Color(0.078, 0.086, 0.125, 0.96), Color(0.75, 0.82, 0.92, 0.6))
			ElemKit.label(n, rr, "MACH 1", Color(0.89, 0.93, 0.96))
			if pv > 0.0:                     # the cone: flattened arcs bursting back
				var k := 1.0 - pv
				for ring in 3:
					var rad := 10.0 + k * 70.0 + ring * 12.0
					ElemKit.ellipse(n, Vector2(o.x + r.size.x + 6, r.get_center().y), rad * 0.5, rad,
						Color(0.86, 0.92, 1.0, pv * 0.8), 2.0, -1.2, 1.2, 14)
		"windsock":
			ElemKit.face(n, r, Color(0.078, 0.094, 0.118, 0.92), Color(0.75, 0.8, 0.88, 0.5))
			ElemKit.label(n, r, "GALE", Color(0.89, 0.92, 0.96))
			var poly := PackedVector2Array()
			for p in b.pts:
				poly.append(o + p)
			n.draw_polyline(poly, Color(1, 0.59, 0.35, 0.9), 3.0)
