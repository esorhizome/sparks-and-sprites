extends RefCounted

const Kit := preload("res://scenes/motion/kit.gd")
## TIME & CAMERAS — eight movement styles, ported from the web lexicon
## (docs/locomotion.js). The clock and the window are part of the motion
## too. Every card so far trusted dt; these bend it — scale it, freeze it,
## chop it into fixed steps, deliver it late, quantise it — and move the
## camera that frames it all. The reader's question, answered on camera:
## slower motion is NOT more frames. Frames are drawn at the same rate
## whatever happens; only the dt each frame feeds the simulation changes.
## Count the frames and see.

const TITLE := "Time & cameras"
const BLURB := "dt is a dial too — scale it, freeze it, substep it, deliver it late, quantise it — and the camera that frames it all"
const DEFS := [
	{ "id": "camera", "letter": "C", "name": "Camera",
		"hint": "a camera with a dead zone and look-ahead follows the mote through a wider world — press to send it somewhere",
		"dials": { "world": 3.2,        # the world is this many screens wide
			"look": 0.2,                # LOOK-AHEAD at full speed, as a fraction of W
			"dead": 0.08,               # half-width of the DEAD ZONE, as a fraction of W
			"omega": 6,                 # the camera spring, critically damped, this fast
			"speed": 0.6,               # top speed of the mote, in screens per second
			"label": "focus = mote + look-ahead · dead zone ±" },
		"rhyme": { "name": "Cinematic", "hint": "a long look-ahead, no dead zone and a lazy spring — the wide, drifting follow of a film camera",
			"dials": { "look": 0.34, "dead": 0.005, "omega": 2.5 } } },
	{ "id": "hitstop", "letter": "H", "name": "Hitstop",
		"hint": "on impact the pair's clock stops for 100 ms; inside the bubble dt is ×0.2 — press to change the freeze length",
		"dials": { "freezes": [0.1, 0.25, 0.5],   # the freeze lengths the press cycles through, seconds
			"speed": 0.55,                        # approach speed, in screens per second
			"bubble": 0.2,                        # dt multiplier inside the slow-mo bubble
			"radius": 0.17,                       # the bubble radius, as a fraction of W
			"label": "hit: pair dt = 0 · bubble: dt × " },
		"rhyme": { "name": "Haymaker", "hint": "long freezes and a near-stopped bubble — the heavy anime hit, the pair's clock falling seconds behind the world",
			"dials": { "freezes": [0.4, 0.8, 1.2], "bubble": 0.05 } } },
	{ "id": "substep", "letter": "S", "name": "Substep",
		"hint": "one spring at 60 fps and 10 fps, three ways — only the naive one diverges — press to restart the race",
		"dials": { "frac": 0.1,     # the naive step: close this fraction of the gap per FRAME
			"slow": 6,              # the slow simulation ticks once per this many 60ths of a second
			"rate": 6.3,            # the framerate-proof rate, per second: 1 − exp(−rate·dt)
			"period": 2.2,          # the target flips sides this often, seconds
			"label": "gap·f per frame · gap·(1−e^(−k·dt)) · substeps" },
		"rhyme": { "name": "Stutter", "hint": "a 4 fps stepper against a greedier fraction — the naive curve crawls, the exp curve still lands on the same line",
			"dials": { "slow": 15, "frac": 0.2 } } },
	{ "id": "timescale", "letter": "T", "name": "Timescale",
		"hint": "one bouncing scene at ×0.25, ×1 and ×2 — the same frames, a different dt per frame — press to swap the scales",
		"dials": { "scales": [0.25, 1, 2],   # the three TIME SCALES, left to right
			"g": 1.9,                        # gravity, ×H per second²
			"e": 0.8,                        # restitution (card B)
			"rest": 0.8,                     # seconds of SIM time the ball rests before relaunching
			"label": "frames identical · sim dt = dt × scale" },
		"rhyme": { "name": "Trance", "hint": "every column slower than life and the ball livelier — bullet time as a mood, the frame counters still marching in step",
			"dials": { "scales": [0.1, 0.5, 1], "e": 0.9 } } },
	{ "id": "lag", "letter": "L", "name": "Lag",
		"hint": "a remote copy hears the mote 150 ms late: snap, interpolate or extrapolate — press to change the packet interval",
		"dials": { "intervals": [0.15, 0.3, 0.6],   # packet intervals the press cycles through, seconds
			"delay": 0.12,                          # the wire: seconds from send to arrival
			"a": 0.9, "b": 1.3,                     # the true path, a Lissajous (card E), in rad/s
			"label": "snap · interp: a packet behind · extrap: v·age" },
		"rhyme": { "name": "Lagspike", "hint": "a slow tick on a long wire — snap teleports, interp trails half a second, extrap overshoots every corner",
			"dials": { "intervals": [0.5, 1, 1.5], "delay": 0.4 } } },
	{ "id": "quantize", "letter": "Q", "name": "Quantize",
		"hint": "smooth, snapped to 8 fps, and snapped to 8 fps + an 8 px grid + 8 headings — press to change the frame rate",
		"dials": { "fpsList": [4, 8, 12],   # the sample rates the press cycles through
			"grid": 8,                      # the spatial grid, in px
			"dirs": 8,                      # headings snapped to this many directions
			"spd": 1.0,                     # path speed multiplier
			"label": "⌊t·fps⌋/fps · ⌊x/g⌋·g · n headings" },
		"rhyme": { "name": "Quaint", "hint": "two to four frames a second, a 16 px grid and four headings — a handheld from 1989",
			"dials": { "fpsList": [2, 3, 4], "grid": 16, "dirs": 4 } } },
	{ "id": "zap", "letter": "Z", "name": "Zap",
		"hint": "a ring telegraphs the destination for 0.3 s, then the move takes zero frames — press to blink to your click",
		"dials": { "telegraph": 0.3,   # seconds the destination ring shrinks before the blink
			"fade": 0.5,               # seconds the afterimage streak lasts
			"every": 2.4,              # seconds between scheduled blinks
			"ghosts": 4,               # afterimages left along the streak
			"label": "telegraph → move in 0 frames → afterimage" },
		"rhyme": { "name": "Zipper", "hint": "an eyeblink of telegraph and a blink every 0.7 s with a long ghost trail — the boss that will not stay put",
			"dials": { "telegraph": 0.08, "every": 0.7, "ghosts": 7 } } },
	{ "id": "rubberband", "letter": "R", "name": "Rubberband",
		"hint": "a client guesses, a server disagrees, every packet yanks it back — press to change the correction strength",
		"dials": { "strengths": [1, 0.5, 0.15],   # the press cycles: 1 = snap, less = a softer yank per packet
			"packet": 0.4,                        # seconds between server packets
			"current": 0.14,                      # a sideways current the client does not know about, ×W
			"a": 0.8, "b": 1.1,                   # the intended path, a Lissajous, in rad/s
			"label": "on packet: client += (server − client) · k" },
		"rhyme": { "name": "Rollback", "hint": "packets a second apart against a stronger unseen current — the snap is a leap, the soft modes never quite catch up",
			"dials": { "packet": 1.0, "current": 0.24, "strengths": [1, 0.3, 0.1] } } },
]

const FAINT := Color(0.91, 0.898, 0.957, 0.55)   # the web label's default ink
const HITSTOP_R := 9.0                             # the pair's radius
const SUBSTEP_N := 96                              # samples kept per curve
const SUBSTEP_SAMP := 1.0 / 32.0                   # seconds between samples

## A number for a label: "1" for whole values, "0.25" otherwise (JS's "" + k).
static func _num(v: float) -> String:
	return ("%d" % roundi(v)) if v == roundf(v) else ("%s" % v)

## The web label's "right" alignment: measure, then draw ending at p.x.
static func _label_right(n: CanvasItem, b: Dictionary, txt: String, p: Vector2, col: Color) -> void:
	var f := ThemeDB.fallback_font
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	Kit.label(n, b, txt, Vector2(p.x - w, p.y), col)

## Substep's curve: a history of 0..1 values across the graph strip.
## Dashed = every other segment (plus every step, so no flip goes missing).
static func _curve(n: CanvasItem, hist: Array, gx0: float, gw: float, py: float, ph: float, col: Color, w: float, dashed: bool) -> void:
	if hist.size() < 2:
		return
	var pts := PackedVector2Array()
	for i in hist.size():
		pts.append(Vector2(gx0 + (i / float(SUBSTEP_N - 1)) * gw, py + ph - float(hist[i]) * ph))
	if dashed:
		for i in pts.size() - 1:
			if i % 2 == 0 or pts[i].y != pts[i + 1].y:
				n.draw_line(pts[i], pts[i + 1], col, w)
	else:
		n.draw_polyline(pts, col, w)

## Substep's reset: three racers, empty histories, the target on the right.
static func _substep_reset(b: Dictionary) -> void:
	for p in b.P:
		p.fast = 0.0
		p.slow = 0.0
		p.nf = 0
		p.ns = 0
		p.hf = []
		p.hs = []
		p.ht = []
	b.target = 1
	b.flipT = 0.0
	b.acc = 0.0
	b.sampAcc = 0.0

## Timescale's one bouncing simulation, stepped by h seconds of SIM time.
static func _step_sim(s: Dictionary, h: float, D: Dictionary, cw: float, H: float, GY: float) -> void:
	s.simT += h
	if s.rest > 0.0:
		s.rest -= h
		if s.rest <= 0.0:
			s.launches += 1
			s.vy = -sqrt(2.0 * D.g * H * H * 0.45)
			s.vx = (-1.0 if s.launches % 2 == 1 else 1.0) * cw * 0.45
		return
	s.vy += D.g * H * h
	s.x += s.vx * h
	s.y += s.vy * h
	if s.x < 9.0:
		s.x = 9.0
		s.vx = -s.vx * D.e
	if s.x > cw - 9.0:
		s.x = cw - 9.0
		s.vx = -s.vx * D.e
	if s.y > GY - 9.0:
		s.y = GY - 9.0
		s.vy = -s.vy * D.e
		s.vx *= 0.99
		if absf(s.vy) < H * 0.12:
			s.vy = 0.0
			s.rest = D.rest

## Lag's true path: a Lissajous, with its velocity (x, y, vx, vy).
static func _lag_truth(b: Dictionary, tt: float) -> Dictionary:
	var D: Dictionary = b.D
	var cx: float = b.w * 0.5
	var cy: float = b.h * 0.56
	var rx: float = b.w * 0.32
	var ry: float = b.h * 0.25
	var a: float = D.a
	var bb: float = D.b
	return { "x": cx + cos(tt * a) * rx, "y": cy + sin(tt * bb) * ry,
		"vx": -sin(tt * a) * a * rx, "vy": cos(tt * bb) * bb * ry }

## Quantize's path for one column: a smooth formula of tt (x, y, heading).
static func _q_path(b: Dictionary, tt: float, c: Dictionary) -> Dictionary:
	var cw: float = b.w / 3.0
	var rx: float = cw * 0.32
	var ry: float = b.h * 0.25
	return { "x": c.cx + cos(tt * 1.1) * rx, "y": b.h * 0.5 + sin(tt * 1.7) * ry,
		"h": atan2(cos(tt * 1.7) * 1.7 * ry, -sin(tt * 1.1) * 1.1 * rx) }

static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	match b.id:
		"camera":
			# a CAMERA is a point with manners. it wants a FOCUS a little ahead of the
			# mote (look-ahead: show where you are going, not where you were), it
			# ignores wobbles inside a DEAD ZONE, and it closes the rest of the gap
			# with card D's critically damped spring — ζ = 1, the one that never
			# overshoots. the world scrolls; the camera is the thing that stays put.
			# the strip at the top is the whole world; the little box is the window.
			var WORLD: float = b.w * D.world
			var sr := Kit.rng(7)                         # the same landmarks on every machine
			b.marks = []
			for i in 28:
				b.marks.append({ "x": sr.randf() * WORLD, "h": 10.0 + sr.randf() * b.h * 0.16, "tree": sr.randf() < 0.6 })
			b.mx = b.w * 0.5
			b.vx = 0.0
			b.tx = b.w * 1.8
			b.autoT = 0.0
			b.cx = b.mx                                  # the camera: a world x, and a velocity
			b.cv = 0.0
		"hitstop":
			# HITSTOP is the fighting-game trick: the moment two things hit, THEIR
			# clock stops for a tenth of a second while the world keeps going. nothing
			# is drawn differently — the pair simply receives dt = 0 — and the pause
			# reads as weight. the bubble is the gentler cousin: dt × 0.2 for anything
			# inside a radius. bullet time is a LOCAL TIME SCALE, not a global one; the
			# two clocks at the top drift apart by exactly the frozen seconds.
			b.fi = 0
			b.ax = HITSTOP_R + 4.0
			b.bx = b.w - HITSTOP_R - 4.0
			b.va = 1.0
			b.vb = -1.0
			b.freeze = 0.0
			b.pairT = 0.0
			b.hits = 0
			b.spark = 0.0
			b.lane = []
			for k in [0.0, 1.0 / 3.0, 2.0 / 3.0]:
				b.lane.append({ "x": b.w * k, "inside": false })
		"substep":
			# FRAMERATE INDEPENDENCE. the naive smoother  x += gap · 0.1  closes a
			# fraction per frame, so ten frames a second close far less than sixty —
			# the red curve falls behind the blue. write the fraction as
			# 1 − exp(−k·dt) and a bigger dt buys a bigger fraction: same curve at any
			# rate (k = 6.3 is the 60 fps twin of 0.1). the third way keeps the naive
			# formula but replays the missed 1/60ths: FIXED-STEP SUBSTEPS. the step
			# counters are the answer to "is it more frames": the substep panel does
			# sixty steps a second whatever the screen does.
			b.P = [{ "name": "naive" }, { "name": "exp" }, { "name": "substep" }]
			_substep_reset(b)
		"timescale":
			# slow motion is not more frames. every column is drawn once per frame,
			# exactly like its neighbours — the counters prove it — but the simulation
			# in each is fed  dt × scale. a quarter of the dt per frame is a quarter of
			# the motion per frame: a TIME SCALE. the same code, the same starting
			# state, three clocks. (the ×2 column quietly halves its step twice so the
			# floor still catches the ball — substeps, card S — but it is drawn once.)
			b.order = 0
			b.sims = []
			var cw: float = b.w / 3.0
			for _k in (D.scales as Array).size():
				b.sims.append({ "x": cw / 2.0, "y": b.h * 0.3, "vx": cw * 0.35, "vy": 0.0,
					"simT": 0.0, "frames": 0, "rest": 0.0, "launches": 0 })
		"lag":
			# network LAG: the remote machine never sees the mote, only PACKETS —
			# a position and velocity, sent every so often, arriving late. three ways
			# to cope. SNAP teleports to the newest packet (honest, jerky).
			# INTERPOLATION lerps between the last two packets, deliberately a whole
			# packet behind so it always has two to stand between (smooth, late).
			# EXTRAPOLATION — DEAD RECKONING — runs the last velocity forward by the
			# age of the data (on time, and wrong at every corner).
			b.ii = 0
			b.sendT = 0.0
			b.last = {}
			b.prev = {}
			b.wire = []
		"quantize":
			# QUANTISED motion: the position is still a smooth formula of t, but the
			# t we feed it is rounded down to the last 1/8 s — stop-motion, animating
			# ON TWOS (12 fps) or on eights. the third copy also rounds its x and y to
			# an 8 px grid and its heading to 8 directions: pixel-art rules, where a
			# sprite may only stand on whole pixels and face where it has a frame for.
			# the counters count how often each copy actually changes pose per second.
			var cw: float = b.w / 3.0
			b.cols = []
			for i in 3:
				b.cols.append({ "cx": cw * (i + 0.5), "lx": 0.0, "ly": 0.0, "n": 0, "rate": 0,
					"px": 0.0, "py": 0.0, "h": 0.0 })
			b.fi = 1
			b.sec = 0.0
		"zap":
			# a TELEPORT is a motion of zero duration — and zero-duration motion still
			# needs animating, just not in between. the TELEGRAPH before (a ring
			# shrinking on the destination) tells the eye where to look; the
			# AFTERIMAGE after (a streak and fading ghosts along the line it did not
			# travel) tells the eye what just happened. neither touches the position:
			# that changes in one frame, x = dest, and the counter says so.
			b.x = b.w * 0.3
			b.y = b.h * 0.5
			b.dx = b.x
			b.dy = b.y
			b.ox = b.x
			b.oy = b.y
			b.tele = -1.0
			b.fadeT = 0.0
			b.timer = 0.0
			b.blinks = 0
			b.dist = 0.0
		"rubberband":
			# CLIENT-SIDE PREDICTION: the client moves the mote the instant it
			# intends to, without waiting to hear back — that is why online games
			# feel responsive. but the SERVER is the truth, and here the truth has a
			# current in it the client never modelled. every packet the client learns
			# the real position and corrects: k = 1 snaps (RUBBER-BANDING, the yank),
			# k < 1 lerps part of the way and drifts again. the band is the disagreement.
			var cx: float = b.w * 0.5
			var cy: float = b.h * 0.52
			var rx: float = b.w * 0.3
			b.p = Vector2(cx + rx, cy)                   # the client starts where the path starts
			b.v = Vector2.ZERO
			b.sp = Vector2(cx + rx, cy)
			b.si = 0
			b.pk = 0.0
			b.yank = 0.0
			b.strail = []
			b.ctrail = []

static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	match b.id:
		"camera":
			var WORLD: float = b.w * D.world
			b.tx = clampf(b.cx - b.w / 2.0 + pos.x, b.w * 0.1, WORLD - b.w * 0.1)
			b.autoT = -6.0
		"hitstop":
			b.fi = (b.fi + 1) % (D.freezes as Array).size()
		"substep":
			_substep_reset(b)
		"timescale":
			b.order = (b.order + 1) % (D.scales as Array).size()
		"lag":
			b.ii = (b.ii + 1) % (D.intervals as Array).size()
		"quantize":
			b.fi = (b.fi + 1) % (D.fpsList as Array).size()
		"zap":
			b.dx = clampf(pos.x, 12.0, b.w - 12.0)
			b.dy = clampf(pos.y, 14.0, b.h * 0.8)
			b.tele = 0.0
		"rubberband":
			b.si = (b.si + 1) % (D.strengths as Array).size()

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	match b.id:
		"camera":
			var WORLD: float = W * D.world
			b.autoT += dt
			if b.autoT > 4.5:
				b.autoT = 0.0
				b.tx = randf_range(W * 0.1, WORLD - W * 0.1)
			var maxv: float = W * D.speed
			var want: float = clampf((b.tx - b.mx) * 2.5, -maxv, maxv)
			b.vx += (want - b.vx) * minf(1.0, 4.0 * dt)
			b.mx += b.vx * dt
			var look: float = (b.vx / maxv) * W * D.look   # ahead, in the direction of travel
			var focus: float = b.mx + look
			var dz: float = W * D.dead
			var goal: float = b.cx                       # inside the dead zone: stay put
			if focus > b.cx + dz:
				goal = focus - dz                        # outside it: move just enough
			if focus < b.cx - dz:
				goal = focus + dz                        #   to re-contain the focus
			goal = clampf(goal, W / 2.0, WORLD - W / 2.0)   # never show past the world's edge
			var w: float = D.omega
			b.cv += (w * w * (goal - b.cx) - 2.0 * w * b.cv) * dt   # ζ = 1: the camera never overshoots
			b.cx += b.cv * dt
		"hitstop":
			var R := HITSTOP_R
			var v: float = W * D.speed
			var pdt: float = dt                          # the pair's own dt
			if b.freeze > 0.0:                           # ← the whole trick: dt = 0 for the pair
				b.freeze -= dt
				pdt = 0.0
			b.pairT += pdt
			b.ax += b.va * v * pdt
			b.bx += b.vb * v * pdt
			if b.va > 0.0 and b.vb < 0.0 and b.bx - b.ax <= R * 2.0:   # contact while approaching = a hit
				var mid: float = (b.ax + b.bx) / 2.0
				b.ax = mid - R
				b.bx = mid + R
				b.va = -1.0
				b.vb = 1.0
				b.freeze = D.freezes[b.fi]
				b.hits += 1
				b.spark = 1.0
			if b.ax < R + 4.0:                           # back from the edges for another round
				b.va = 1.0
			if b.bx > W - R - 4.0:
				b.vb = -1.0
			b.spark = maxf(0.0, b.spark - pdt * 3.0)     # the spark lives on the pair's clock too
			var br: float = W * D.radius                 # the slow-mo bubble lane
			var bcx: float = W / 2.0
			for m in b.lane:
				var inside: bool = absf(m.x - bcx) < br
				var s: float = D.bubble if inside else 1.0   # a local time scale
				m.inside = inside
				m.x += v * 0.7 * dt * s
				if m.x > W + 10.0:
					m.x -= W + 20.0
		"substep":
			var P: Array = b.P
			b.flipT += dt
			if b.flipT > D.period:
				b.flipT = 0.0
				b.target = 1 - b.target
			var target: int = b.target
			var frac: float = D.frac
			var rate: float = D.rate
			P[0].fast += (target - P[0].fast) * frac                       # naive: a fraction per frame
			P[1].fast += (target - P[1].fast) * (1.0 - exp(-rate * dt))    # exp: a fraction per SECOND
			P[2].fast += (target - P[2].fast) * frac                       # (the naive formula again)
			for p in P:
				p.nf += 1
			b.acc += dt                                  # the slow sim only ticks when
			if b.acc >= D.slow / 60.0:                   # enough time has piled up
				var big: float = b.acc
				b.acc = 0.0
				P[0].slow += (target - P[0].slow) * frac                   # same fraction, six times rarer
				P[1].slow += (target - P[1].slow) * (1.0 - exp(-rate * big))   # the big dt buys a big fraction
				var nsub: int = maxi(1, roundi(big * 60.0))                # substeps: replay every missed 1/60th
				for _k in nsub:
					P[2].slow += (target - P[2].slow) * frac
				P[0].ns += 1
				P[1].ns += 1
				P[2].ns += nsub
			b.sampAcc += dt
			while b.sampAcc >= SUBSTEP_SAMP:
				b.sampAcc -= SUBSTEP_SAMP
				for p in P:
					p.hf.append(p.fast)
					p.hs.append(p.slow)
					p.ht.append(target)
					if p.hf.size() > SUBSTEP_N:
						p.hf.pop_front()
						p.hs.pop_front()
						p.ht.pop_front()
		"timescale":
			var scales: Array = D.scales
			var sims: Array = b.sims
			var cw: float = W / 3.0
			for i in sims.size():
				var s: Dictionary = sims[i]
				var scale: float = scales[(i + b.order) % scales.size()]
				var sdt: float = dt * scale              # ← the whole card
				var nsub: int = maxi(1, ceili(sdt / 0.02))   # substeps only for big steps
				for _k in nsub:
					_step_sim(s, sdt / nsub, D, cw, H, b.gy)
		"lag":
			var iv: float = D.intervals[b.ii]
			b.sendT += dt
			if b.sendT >= iv:                            # a packet leaves
				b.sendT = 0.0
				var p: Dictionary = _lag_truth(b, t)
				p.sent = t
				b.wire.append(p)
			var wire: Array = b.wire
			while wire.size() > 0 and wire[0].sent + D.delay <= t:   # arrivals
				b.prev = b.last
				b.last = wire.pop_front()
			if wire.size() > 24:
				wire.pop_front()
		"quantize":
			var fps: float = D.fpsList[b.fi]
			var g: float = D.grid
			var step: float = TAU / D.dirs
			var tq: float = floorf(t * D.spd * fps) / fps   # ← time, quantised
			b.sec += dt
			var pub: bool = b.sec >= 1.0                 # once a second, publish the counts
			if pub:
				b.sec -= 1.0
			for i in 3:
				var c: Dictionary = b.cols[i]
				var tt: float = t * D.spd if i == 0 else tq
				var p: Dictionary = _q_path(b, tt, c)
				if i == 2:                               # space and heading, quantised too
					p.x = roundf(p.x / g) * g
					p.y = roundf(p.y / g) * g
					p.h = roundf(p.h / step) * step
				if absf(p.x - c.lx) + absf(p.y - c.ly) > 0.01:   # a pose change
					c.n += 1
				c.lx = p.x
				c.ly = p.y
				if pub:
					c.rate = c.n
					c.n = 0
				c.px = p.x                               # the pose, kept for draw
				c.py = p.y
				c.h = p.h
		"zap":
			b.timer += dt
			if b.tele < 0.0 and b.timer > D.every:
				b.dx = randf_range(W * 0.12, W * 0.88)
				b.dy = randf_range(H * 0.18, H * 0.72)
				b.tele = 0.0
			if b.tele >= 0.0:
				b.tele += dt
				if b.tele >= D.telegraph:                # the blink: one assignment, no frames between
					b.ox = b.x
					b.oy = b.y
					b.x = b.dx
					b.y = b.dy
					b.dist = Vector2(b.x - b.ox, b.y - b.oy).length()
					b.fadeT = D.fade
					b.tele = -1.0
					b.timer = 0.0
					b.blinks += 1
			b.fadeT = maxf(0.0, b.fadeT - dt)
		"rubberband":
			var cx: float = W * 0.5
			var cy: float = H * 0.52
			var rx: float = W * 0.3
			var ry: float = H * 0.26
			var a: float = D.a
			var bb: float = D.b
			var cur: float = D.current
			var v := Vector2(-sin(t * a) * a * rx, cos(t * bb) * bb * ry)   # the intent
			var p: Vector2 = b.p
			p += v * dt                                  # prediction: trust your own maths
			var sp := Vector2(cx + cos(t * a) * rx + sin(t * 0.7) * W * cur,   # the server: intent + current
				cy + sin(t * bb) * ry)
			var k: float = D.strengths[b.si]
			b.pk += dt
			if b.pk >= D.packet:                         # a packet: the truth arrives
				b.pk = 0.0
				var e := sp - p
				b.yank = e.length() * k
				p += e * k                               # ← the correction, k of the gap at once
			b.p = p
			b.v = v
			b.sp = sp
			b.strail.append(sp)
			b.ctrail.append(p)
			if b.strail.size() > 48:
				b.strail.pop_front()
				b.ctrail.pop_front()

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	Kit.stage(n, b)
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"camera":
			var WORLD: float = W * D.world
			var cx: float = b.cx
			var mx: float = b.mx
			var vx: float = b.vx
			var tx: float = b.tx
			var maxv: float = W * D.speed
			var look: float = (vx / maxv) * W * D.look
			var focus: float = mx + look
			var dz: float = W * D.dead
			Kit.ground(n, b)                             # world → screen: x - cx + W / 2, the whole scroll
			for m in b.marks:
				var x: float = m.x - cx + W / 2.0
				if x < -20.0 or x > W + 20.0:
					continue
				var mh: float = m.h
				if m.tree:
					Kit.line(n, Vector2(x, GY), Vector2(x, GY - mh * 0.45), Kit.BONE, 2.0)
					Kit.poly(n, [Vector2(x - 7.0, GY - mh * 0.4), Vector2(x + 7.0, GY - mh * 0.4), Vector2(x, GY - mh)], Kit.GOOD)
				else:
					Kit.rect(n, Rect2(x - 3.0, GY - mh * 0.6, 6.0, mh * 0.6), Kit.BONE)
			Kit.poly(n, [Vector2(W / 2.0 - dz, H * 0.26), Vector2(W / 2.0 + dz, H * 0.26), Vector2(W / 2.0 + dz, GY), Vector2(W / 2.0 - dz, GY)],
				Color(0.961, 0.757, 0.412, 0.35), 1.0)
			Kit.label(n, b, "dead zone", Vector2(W / 2.0, H * 0.24), Color(0.961, 0.757, 0.412, 0.6), true)
			Kit.arrow(n, Vector2(mx - cx + W / 2.0, GY - 34.0), Vector2(focus - cx + W / 2.0, GY - 34.0), Kit.TARGET)
			if absf(look) > 8.0:
				Kit.label(n, b, "look-ahead", Vector2(focus - cx + W / 2.0, GY - 40.0), Color(0.961, 0.757, 0.412, 0.8), true)
			Kit.ring(n, Vector2(tx - cx + W / 2.0, GY - 4.0), 5.0, Kit.TARGET, 1.5)
			var bob: float = absf(sin(t * 11.0)) * absf(vx) / maxv * 4.0
			Kit.mote(n, b, Vector2(mx - cx + W / 2.0, GY - 10.0 - bob), PI if vx < 0.0 else 0.0)
			var bw: float = W * 0.8                      # the minimap: the world, and the window
			var bx0: float = W * 0.1
			var by0 := 12.0
			Kit.line(n, Vector2(bx0, by0), Vector2(bx0 + bw, by0), Kit.DIM, 1.0)
			var winL: float = bx0 + (cx - W / 2.0) / WORLD * bw
			var winW: float = W / WORLD * bw
			Kit.poly(n, [Vector2(winL, by0 - 5.0), Vector2(winL + winW, by0 - 5.0), Vector2(winL + winW, by0 + 5.0), Vector2(winL, by0 + 5.0)],
				Color(0.91, 0.898, 0.957, 0.5), 1.0)
			Kit.dot(n, Vector2(bx0 + mx / WORLD * bw, by0), 2.5, Kit.MOVER)
			Kit.dot(n, Vector2(bx0 + tx / WORLD * bw, by0), 2.0, Kit.TARGET)
			Kit.label(n, b, "%s%d px" % [D.label, roundi(dz)], Vector2(W / 2.0, H - 8.0), FAINT, true)
		"hitstop":
			var R := HITSTOP_R
			var y1: float = H * 0.32
			var y2: float = H * 0.74
			var ax: float = b.ax
			var bx: float = b.bx
			Kit.line(n, Vector2(0.0, y1 + R + 3.0), Vector2(W, y1 + R + 3.0), Kit.DIM, 1.0)
			Kit.mote(n, b, Vector2(ax, y1), 0.0, Kit.MOVER)
			Kit.mote(n, b, Vector2(bx, y1), PI, Kit.HOT)
			var spark: float = b.spark
			if spark > 0.0:
				var mx: float = (ax + bx) / 2.0
				var sl: float = 6.0 + (1.0 - spark) * 10.0
				for i in 8:
					var an: float = i / 8.0 * TAU + 0.3
					Kit.line(n, Vector2(mx + cos(an) * 4.0, y1 + sin(an) * 4.0), Vector2(mx + cos(an) * sl, y1 + sin(an) * sl),
						Color(0.961, 0.541, 0.541, spark), 2.0)
			var freeze: float = b.freeze
			if freeze > 0.0:
				Kit.label(n, b, "dt = 0 · %d ms left" % roundi(freeze * 1000.0), Vector2((ax + bx) / 2.0, y1 - 22.0), Kit.HOT, true)
			Kit.label(n, b, "world t %.1f s" % t, Vector2(W * 0.04, H * 0.1))
			_label_right(n, b, "pair t %.1f s  (−%.1f)" % [b.pairT, t - b.pairT], Vector2(W * 0.96, H * 0.1), Kit.MOVER)
			Kit.label(n, b, "freeze %d ms · hits %d" % [roundi(float(D.freezes[b.fi]) * 1000.0), b.hits], Vector2(W / 2.0, y1 + R + 16.0), FAINT, true)
			var br: float = W * D.radius                 # the slow-mo bubble lane
			var bcx: float = W / 2.0
			Kit.ring(n, Vector2(bcx, y2), br, Kit.MAGIC, 1.5)
			for m in b.lane:
				var mx2: float = m.x
				var inside: bool = m.inside
				Kit.mote(n, b, Vector2(mx2, y2), 0.0, Kit.MAGIC if inside else Kit.GOOD, 6.0)
				if inside:
					Kit.label(n, b, "dt × %s" % _num(D.bubble), Vector2(mx2, y2 - 12.0), Kit.MAGIC, true)
			Kit.label(n, b, "%s%s" % [D.label, _num(D.bubble)], Vector2(W / 2.0, H - 8.0), FAINT, true)
		"substep":
			var gx0: float = W * 0.06
			var gw: float = W * 0.7
			for i in 3:
				var p: Dictionary = b.P[i]
				var py: float = H * 0.12 + i * H * 0.27
				var ph: float = H * 0.19
				_curve(n, p.ht, gx0, gw, py, ph, Kit.DIM, 1.0, true)
				_curve(n, p.hf, gx0, gw, py, ph, Kit.MOVER, 1.5, false)
				_curve(n, p.hs, gx0, gw, py, ph, Kit.HOT, 1.5, false)
				Kit.mote(n, b, Vector2(gx0 + gw + 12.0, py + ph - p.fast * ph), 0.0, Kit.MOVER, 4.0)
				Kit.mote(n, b, Vector2(gx0 + gw + 26.0, py + ph - p.slow * ph), 0.0, Kit.HOT, 4.0)
				Kit.label(n, b, "%s · steps %d / %d" % [p.name, p.nf, p.ns], Vector2(gx0, py - 2.0))
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"timescale":
			Kit.ground(n, b)
			var scales: Array = D.scales
			var sims: Array = b.sims
			var cw: float = W / 3.0
			for i in sims.size():
				var s: Dictionary = sims[i]
				var scale: float = scales[(i + b.order) % scales.size()]
				var x0: float = i * cw
				s.frames += 1                            # one draw, whatever the scale
				if i > 0:
					Kit.line(n, Vector2(x0, H * 0.05), Vector2(x0, GY), Kit.DIM, 1.0)
				Kit.label(n, b, "× %s" % _num(scale), Vector2(x0 + cw / 2.0, 13.0), Color(0.961, 0.757, 0.412, 0.85), true)
				Kit.label(n, b, "frames %d" % s.frames, Vector2(x0 + cw / 2.0, 25.0), FAINT, true)
				Kit.label(n, b, "sim %.1f s" % s.simT, Vector2(x0 + cw / 2.0, 37.0), Color(0.541, 0.851, 0.961, 0.8), true)
				Kit.mote(n, b, Vector2(x0 + s.x, s.y), 0.0 if s.rest > 0.0 else atan2(s.vy, s.vx), Kit.MOVER, 7.0)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"lag":
			var iv: float = D.intervals[b.ii]
			var T: Dictionary = _lag_truth(b, t)
			var Tp := Vector2(T.x, T.y)
			var pts := PackedVector2Array()              # the true path, previewed
			for i in 97:
				var q: Dictionary = _lag_truth(b, i / 96.0 * TAU * 10.0 / D.a)
				pts.append(Vector2(q.x, q.y))
			n.draw_polyline(pts, Color(0.91, 0.898, 0.957, 0.08), 1.0)
			var wx0: float = W * 0.12                    # the wire, with packets in flight
			var wx1: float = W * 0.88
			var wy := 16.0
			Kit.line(n, Vector2(wx0, wy), Vector2(wx1, wy), Kit.DIM, 1.0)
			for p in b.wire:
				Kit.dot(n, Vector2(lerpf(wx0, wx1, clampf((t - p.sent) / D.delay, 0.0, 1.0)), wy), 2.5, Color(0.91, 0.898, 0.957, 0.7))
			Kit.label(n, b, "every %d ms · wire %d ms" % [roundi(iv * 1000.0), roundi(D.delay * 1000.0)], Vector2(W / 2.0, wy + 14.0), FAINT, true)
			var S := Tp
			var I := Tp
			var X := Tp
			var sh: float = atan2(T.vy, T.vx)
			var ih := sh
			var xh := sh
			var last: Dictionary = b.last
			var prev: Dictionary = b.prev
			if not last.is_empty():
				S = Vector2(last.x, last.y)              # snap: the newest packet, as is
				sh = atan2(last.vy, last.vx)
				var age: float = minf(t - last.sent, 1.5)   # dead reckoning: run the velocity forward
				X = Vector2(last.x + last.vx * age, last.y + last.vy * age)
				xh = sh
			if not last.is_empty() and not prev.is_empty():   # interpolate: render a packet behind
				var rt: float = t - D.delay - iv
				var span: float = last.sent - prev.sent
				if span == 0.0:
					span = 1.0
				var k: float = clampf((rt - prev.sent) / span, 0.0, 1.0)
				I = Vector2(lerpf(prev.x, last.x, k), lerpf(prev.y, last.y, k))
				ih = atan2(last.y - prev.y, last.x - prev.x)
			n.draw_dashed_line(S, Tp, Color(0.961, 0.541, 0.541, 0.4), 1.0, 3.0)   # each copy's error, drawn
			n.draw_dashed_line(I, Tp, Color(0.608, 0.886, 0.541, 0.4), 1.0, 3.0)
			n.draw_dashed_line(X, Tp, Color(0.788, 0.627, 0.961, 0.4), 1.0, 3.0)
			Kit.mote(n, b, S, sh, Kit.HOT, 6.0)
			Kit.mote(n, b, I, ih, Kit.GOOD, 6.0)
			Kit.mote(n, b, X, xh, Kit.MAGIC, 6.0)
			Kit.mote(n, b, Tp, atan2(T.vy, T.vx))
			Kit.label(n, b, "true", Vector2(W * 0.04, H * 0.9), Kit.MOVER)
			Kit.label(n, b, "snap", Vector2(W * 0.28, H * 0.9), Kit.HOT)
			Kit.label(n, b, "interp", Vector2(W * 0.52, H * 0.9), Kit.GOOD)
			Kit.label(n, b, "extrap", Vector2(W * 0.78, H * 0.9), Kit.MAGIC)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"quantize":
			var fps: int = roundi(float(D.fpsList[b.fi]))
			var g: float = D.grid
			var cw: float = W / 3.0
			for i in 3:
				var c: Dictionary = b.cols[i]
				var x0: float = i * cw
				if i > 0:
					Kit.line(n, Vector2(x0, H * 0.08), Vector2(x0, H * 0.86), Kit.DIM, 1.0)
				if i == 2:                               # the grid the sprite must stand on
					var gx: float = ceilf(x0 / g) * g
					while gx < x0 + cw:
						var gy: float = H * 0.12
						while gy < H * 0.86:
							Kit.dot(n, Vector2(gx, gy), 0.8, Color(0.91, 0.898, 0.957, 0.14))
							gy += g
						gx += g
				var col: Color = Kit.MOVER if i == 0 else (Kit.BONE if i == 1 else Kit.MAGIC)
				Kit.mote(n, b, Vector2(c.px, c.py), c.h, col, 7.0)
				var title: String = "smooth" if i == 0 else (("%d fps" % fps) if i == 1 else ("%d fps + grid" % fps))
				Kit.label(n, b, title, Vector2(c.cx, 14.0), FAINT, true)
				Kit.label(n, b, "%d poses/s" % c.rate, Vector2(c.cx, H * 0.92), FAINT, true)
			Kit.label(n, b, "⌊t·%d⌋/%d · ⌊x/%d⌋·%d · %d headings" % [fps, fps, roundi(g), roundi(g), roundi(float(D.dirs))],
				Vector2(W / 2.0, H - 8.0), FAINT, true)
		"zap":
			var x: float = b.x
			var y: float = b.y
			var ox: float = b.ox
			var oy: float = b.oy
			var dx: float = b.dx
			var dy: float = b.dy
			var tele: float = b.tele
			var fadeT: float = b.fadeT
			var bob: float = sin(t * 2.6) * 3.0
			if fadeT > 0.0:
				var k: float = fadeT / D.fade
				Kit.line(n, Vector2(ox, oy), Vector2(x, y), Color(0.788, 0.627, 0.961, k * 0.6), 2.0)
				Kit.ring(n, Vector2(ox, oy), (1.0 - k) * 22.0, Color(0.788, 0.627, 0.961, k * 0.7), 1.5)
				var ghosts: int = D.ghosts
				for i in range(1, ghosts + 1):           # afterimages: the path it did not take
					var gk: float = i / float(ghosts + 1)
					Kit.mote(n, b, Vector2(lerpf(ox, x, gk), lerpf(oy, y, gk) + bob), atan2(y - oy, x - ox),
						Color(0.788, 0.627, 0.961, k * 0.55 * gk))
			if tele >= 0.0:                              # the telegraph: look here next
				var k: float = tele / D.telegraph
				Kit.ring(n, Vector2(dx, dy), 6.0 + (1.0 - k) * 26.0, Kit.MAGIC, 1.5)
				Kit.dot(n, Vector2(dx, dy), 2.0, Kit.MAGIC)
			var face: float = atan2(dy - y, dx - x) if tele >= 0.0 else atan2(y - oy, x - ox)
			Kit.mote(n, b, Vector2(x, y + bob), face)
			Kit.label(n, b, "blinks %d · last: %d px in 0 frames" % [b.blinks, roundi(b.dist)], Vector2(W / 2.0, 14.0), FAINT, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"rubberband":
			var strail: Array = b.strail
			var ctrail: Array = b.ctrail
			for i in strail.size():
				var a: float = i / float(strail.size())
				Kit.dot(n, strail[i], 1.4, Color(0.961, 0.757, 0.412, a * 0.35))
				Kit.dot(n, ctrail[i], 1.4, Color(0.541, 0.851, 0.961, a * 0.35))
			var p: Vector2 = b.p
			var sp: Vector2 = b.sp
			var v: Vector2 = b.v
			var gap: float = (sp - p).length()           # the rubber band, redder as it stretches
			Kit.line(n, p, sp, Color(0.961, 0.541, 0.541, clampf(gap / 50.0, 0.25, 0.9)), 1.5)
			Kit.ring(n, sp, 7.0, Kit.TARGET, 1.5)
			Kit.dot(n, sp, 2.5, Kit.TARGET)
			Kit.mote(n, b, p, v.angle())
			Kit.line(n, Vector2(W * 0.1, H * 0.09), Vector2(W * 0.1 + W * 0.8 * (b.pk / D.packet), H * 0.09), Kit.DIM, 2.0)   # next packet in...
			var k: float = D.strengths[b.si]
			Kit.label(n, b, "k = %s%s · last yank %d px · gap %d" % [_num(k), " (snap)" if k >= 1.0 else " (lerp)", roundi(b.yank), roundi(gap)],
				Vector2(W / 2.0, H * 0.17), FAINT, true)
			Kit.label(n, b, "client", Vector2(W * 0.06, H * 0.9), Kit.MOVER)
			_label_right(n, b, "server", Vector2(W * 0.94, H * 0.9), Kit.TARGET)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
