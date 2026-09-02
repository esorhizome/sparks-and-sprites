extends RefCounted

const Kit := preload("res://scenes/motion/kit.gd")
## CLOCKS & CIRCLES — fourteen movement styles, ported from the web lexicon
## (docs/locomotion.js). Motion with NO memory: every frame, position is
## computed straight from the clock. x(t) and y(t) are formulas — nothing is
## remembered, nothing can drift, and the loop can run for a year without a
## bug. These are the maths of hovering pickups, orbiting shields,
## figure-eight patrols, and every snake that ever swam across a title
## screen — and, in the genre laps, of bullet spirals, blinking saucers,
## clockwork solar systems, kaleidoscopes, a character breathing in place,
## and a boat that reads the wave's slope.

const TITLE := "Clocks & circles"
const BLURB := "position is a formula of time — sine, polar, phase, nested frames: motion with no memory"
const DEFS := [
	{ "id": "hover", "letter": "H", "name": "Hover",
		"hint": "y = sin(t) is a whole idle animation — press to excite it",
		"dials": { "period": 2.8,        # seconds per bob
			"amp": 0.075,                # bob height, as a fraction of H
			"tilt": 0.16,                # how far the body leans on the slope
			"rest": 0.32,                # hover height above the ground, of H
			"exciteAmp": 1.5,            # what a press adds to the height...
			"exciteSpeed": 0.4,          # ...and takes off the period
			"decay": 0.45 },             # how fast the excitement fades, per second
		"rhyme": { "name": "Heartbeat", "hint": "the same sine at a third of the period and twice the amplitude — a pulse instead of a float",
			"dials": { "period": 0.9, "amp": 0.15 } } },
	{ "id": "orbit", "letter": "O", "name": "Orbit",
		"hint": "polar coordinates: one angle + one radius = a flight plan — press to reverse",
		"dials": { "speed": 1.1,         # radians per second around the sun
			"moonSpeed": 4.6,            # the moon's own, faster clock
			"radius": 0.3,               # orbit radius, of min(W, H)
			"breathe": 6,                # px the radius swells and shrinks by
			"moonR": 19 },               # the moon's distance from the mote, px
		"rhyme": { "name": "Outrider", "hint": "a slow, stately planet with a frantic escort far out on its arm — the moon's clock outruns the mote's seven times over",
			"dials": { "speed": 0.4, "moonSpeed": 7.5, "moonR": 32 } } },
	{ "id": "eight", "letter": "E", "name": "Eight",
		"hint": "two sines at different speeds trace a figure eight — press for a new ratio",
		"dials": { "ratios": [[1, 2], [3, 2], [3, 4], [2, 1]],   # the (a, b) pairs a press cycles through
			"rx": 0.33, "ry": 0.3,       # the knot's width and height, of W and H
			"spd": 1.3,                  # how fast t runs through the curve
			"trail": 60 },               # frames of trail behind the mote
		"rhyme": { "name": "Embroidery", "hint": "bigger whole-number ratios, faster, with a long trail — the same two sines stitch dense knots instead of an eight",
			"dials": { "ratios": [[5, 4], [5, 6], [7, 5], [3, 5]], "spd": 2.2, "trail": 150 } } },
	{ "id": "undulate", "letter": "U", "name": "Undulate",
		"hint": "one sine, sixteen joints, phase-shifted — a swimmer — press for a burst",
		"dials": { "n": 16,              # joints
			"sp": 11,                    # px between joints
			"freq": 4.2,                 # the sine's rate, rad/s
			"amp": 0.07,                 # the wave's height, of H
			"phase": 0.62,               # the phase offset per joint, radians
			"speed": 26,                 # cruising speed, px/s
			"burst": 130 },              # extra speed at the top of a burst
		"rhyme": { "name": "Undertow", "hint": "twenty-two joints, a slower sine and a smaller phase step — a long lazy eel instead of a darting swimmer",
			"dials": { "n": 22, "freq": 2.2, "phase": 0.42 } } },
	{ "id": "pendulum", "letter": "P", "name": "Pendulum",
		"hint": "real swing vs the small-angle shortcut — press to lift both to your click",
		"dials": { "k": 7.5,             # g ÷ L, the stiffness of the swing
			"damp": 0.02,                # friction on the angular speed
			"theta0": 1.15,              # the starting angle, radians from straight down
			"length": 0.56,              # the string, of H
			"pivot": 0.14 },             # where the string hangs from, of H
		"rhyme": { "name": "Pocketwatch", "hint": "four times the stiffness on a string less than half as long — a quick, small tick where the ghost and the truth agree",
			"dials": { "k": 30, "length": 0.24, "theta0": 0.6 } } },
	{ "id": "jitter", "letter": "J", "name": "Jitter",
		"hint": "three ways to shake: white noise, value noise, summed sines — press to change the sampling rate",
		"dials": { "freqs": [2.5, 9, 0.6],   # the sampling frequencies a press cycles through
			"amp": 0.06,                 # vertical wobble, of H
			"ampX": 0.035,               # sideways wobble, of W
			"sineB": 2.7,                # the second sine's rate, as a multiple of the first
			"history": 48,               # frames of trace drawn under each mote
			"label": "rand() · noise(t·f) · sin(t·f)+sin(2.7·t·f)" },
		"rhyme": { "name": "Jiggle", "hint": "the same three shakers sampled four times slower and twice as wide — big lazy sways, and the white-noise mote still can't stop twitching",
			"dials": { "freqs": [0.6, 2, 0.15], "amp": 0.13, "ampX": 0.09 } } },
	{ "id": "nest", "letter": "N", "name": "Nest",
		"hint": "three frames nested: a swaying platform, a turret on it, a light on its arm — press to freeze a level",
		"dials": { "sway": 0.14,         # platform drift, of W
			"tilt": 0.18,                # platform rock, radians
			"w1": 0.9,                   # the platform's clock, rad/s
			"w2": 1.6,                   # the turret's clock
			"w3": 6,                     # the light's clock
			"arm": 0.2,                  # the turret's arm, of W
			"r3": 0.07,                  # the light's little orbit, of W
			"label": "each level: parent + rotate(local, angle)" },
		"rhyme": { "name": "Nautilus", "hint": "the turret crawls backward while the light whirls twice as fast on a wider circle — the spiral a nested clock draws",
			"dials": { "w2": -0.6, "w3": 12, "r3": 0.13 } } },
	{ "id": "xfade", "letter": "X", "name": "Xfade",
		"hint": "blending: a bounce and a hover both run every frame, the mote sits at lerp(A, B, w) — press to flip the blend",
		"dials": { "wA": 3.4,            # the bounce's rate (the |sin| runs at this many rad/s)
			"ampA": 0.28,                # bounce height, of H
			"wB": 1.5,                   # the hover's rate
			"ampB": 0.05,                # hover wobble, of H
			"restB": 0.32,               # hover altitude, of H
			"blendTime": 1.1,            # seconds for w to travel 0 → 1
			"hold": 3.2,                 # seconds before it flips by itself
			"label": "shown = lerp(A, B, w)   w eases 0 ⇄ 1" },
		"rhyme": { "name": "Xray", "hint": "a three-second crossfade between a quick low bounce and the hover — the mix, not the ends, is what you watch",
			"dials": { "blendTime": 2.8, "wA": 6.5, "ampA": 0.14 } } },
	{ "id": "bullethell", "letter": "B", "name": "Bullethell",
		"hint": "nothing stored per bullet: p = origin + dir·speed·age, Orbit's polar trick spiralled — press to switch pattern",
		"dials": { "golden": 2.39996,    # the GOLDEN ANGLE, radians: the spiral's step per bullet
			"spin": 0.8,                 # how fast the emitter's aim turns, rad/s
			"interval": 0.045,           # seconds between spiral bullets
			"speed": 0.42,               # bullet speed, W per second
			"ringN": 14,                 # bullets per ring
			"ringEvery": 0.55,           # seconds between rings
			"ringTwist": 0.35,           # each ring rotated a little more than the last
			"label": "θᵢ = i·φ + tᵢ·spin    p = o + dir·v·age" },
		"rhyme": { "name": "Blossom", "hint": "a 30° step instead of the golden angle, spinning slowly, and six-bullet rings — twelve straight petals that turn as one",
			"dials": { "golden": 0.5236, "spin": 0.25, "ringN": 6 } } },
	{ "id": "ufo", "letter": "U", "name": "Ufo",
		"hint": "two unsynced sines to hover (Hover's alien cousin), a beam telegraph, an instant blink — press to summon it",
		"dials": { "ax": 0.06,           # the sideways wobble, of W
			"ay": 0.035,                 # the up-down wobble, of H
			"f1": 1.3,                   # their rates — unsynced on purpose,
			"f2": 2.1,                   # so the loop never visibly repeats
			"dwell": 3.2,                # seconds between blinks
			"tele": 0.45 },              # the beam's warning, seconds before the blink
		"rhyme": { "name": "Unstable", "hint": "blinks three times as often with a wide, hurried wobble — a saucer that can't keep still, and can't stay",
			"dials": { "dwell": 1.1, "ax": 0.12, "f2": 4.3 } } },
	{ "id": "orrery", "letter": "O", "name": "Orrery",
		"hint": "orbits on Kepler's ellipses (Orbit + Nest): faster near the sun, moons on planets — press to speed the clock",
		"dials": { "a": [0.12, 0.2, 0.3],      # semi-major axes, of min(W, H)
			"e": [0.1, 0.3, 0.25],       # eccentricities: 0 is a circle, near 1 a comet
			"peri": [0.3, 2.2, 4.4],     # where each ellipse points its near end, radians
			"rate": 0.06,                # the clock: mean motion n = rate ÷ a^1.5 (Kepler's third law)
			"moons": [0, 1, 2],          # moons per planet
			"moonRate": 5,               # moon radians per second
			"mults": [1, 3, 9],          # what a press cycles the clock through
			"label": "E − e·sin E = n·t    r = a(1 − e·cos E)" },
		"rhyme": { "name": "Oort", "hint": "every orbit stretched to comet eccentricity and the clock hurried — the near-sun rush becomes the whole show",
			"dials": { "e": [0.55, 0.65, 0.6], "peri": [1.0, 2.6, 5.2], "rate": 0.09 } } },
	{ "id": "mirror", "letter": "M", "name": "Mirror",
		"hint": "a kaleidoscope: one Lissajous (Eight) rotated and mirrored into every wedge (Nest) — press to change the folds",
		"dials": { "folds": [6, 4, 8],   # fold counts a press cycles through
			"a": 2,                      # the Lissajous ratio, as in Eight
			"b": 3,
			"spd": 0.55,                 # its speed
			"rx": 0.28,                  # its size, of min(W, H)
			"ry": 0.28,
			"trail": 40,                 # frames of trail behind every clone
			"label": "clone k: rotate(k·2π/N), mirror odd k" },
		"rhyme": { "name": "Mandala", "hint": "twelve, sixteen, ten folds of a denser 3:5 knot — the clones outnumber the wedges you can count",
			"dials": { "folds": [12, 16, 10], "a": 3, "b": 5 } } },
	{ "id": "idle", "letter": "I", "name": "Idle", "drag": true,
		"hint": "idle stack: breath (a sine on scale), a jittered blink, look-at eyes, a weight shift — drag to be looked at",
		"dials": { "breathP": 3.4,       # seconds per breath
			"breath": 0.045,             # how much the body grows, as a scale
			"blinkEvery": 2.8,           # mean seconds between blinks
			"blinkJitter": 1.6,          # ± seconds of randomness on that
			"blinkLen": 0.12,            # a blink's length
			"shiftEvery": 4,             # seconds between weight shifts
			"shift": 0.05,               # how far it sways, of W
			"lookRate": 6,               # how fast the eyes catch up
			"label": "sy = 1 + sin(2πt/P)·a  ·  blink  ·  look-at" },
		"rhyme": { "name": "Insomniac", "hint": "the same four clocks wound tight: panting breath, blinks every second, a restless weight shift — alive, and not okay",
			"dials": { "breathP": 1.3, "blinkEvery": 0.8, "shiftEvery": 1.4 } } },
	{ "id": "yacht", "letter": "Y", "name": "Yacht",
		"hint": "a boat on y = wave(x, t), tilted by its slope, the derivative (Undulate + Normals) — press for more wind",
		"dials": { "lam1": 0.6,          # the two wavelengths, of W
			"lam2": 0.22,
			"amp1": 0.05,                # their heights, of H
			"amp2": 0.018,
			"w1": 1.6,                   # their rates, rad/s (a wave's speed is ω ÷ k)
			"w2": 3.1,
			"winds": [1, 1.7, 0.55],     # wind levels a press cycles through: they scale speed and height
			"mid": 0.62,                 # the sea's rest level, of H
			"boatX": 0.42,               # where the boat sits, of W
			"label": "y = wave(x, t)    tilt = atan(dy/dx)" },
		"rhyme": { "name": "Yikes", "hint": "the same sea in a squall: twice the wave height at three times the wind — the derivative goes wild and so does the boat",
			"dials": { "winds": [2.6, 3.4, 2], "amp1": 0.085 } } },
]

const LBL := Color(0.91, 0.898, 0.957, 0.55)   # the web label's default ink
const JITTER_NAMES := ["white noise", "value noise", "two sines"]
const NEST_NAMES := ["1 platform", "2 turret", "3 light"]


static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	match b.id:
		"hover":
			b.excite = 0.0
		"orbit":
			b.th = 0.0
			b.mth = 0.0
			b.dir = 1.0
		"eight":
			b.ri = 0
			b.trail = []
		"undulate":
			b.hx = b.w * 0.3
			b.boost = 0.0
		"pendulum":
			b.th = float(D.theta0)
			b.om = 0.0
			b.gth = float(D.theta0)
			b.gom = 0.0
		"jitter":
			b.fi = 0
			b.hist = [[], [], []]
		"nest":
			b.clk = [0.0, 0.0, 0.0]                      # three clocks, so one can stop
			b.frozen = -1
		"xfade":
			b.target = 1.0
			b.k = 1.0
			b.timer = 0.0
		"bullethell":
			b.pattern = 0
			b.t0 = 0.0
			b.reset = false
		"ufo":
			b.hx = b.w * 0.5
			b.hy = b.h * 0.4
			b.nx = 0.0
			b.ny = 0.0
			b.timer = 0.0
			b.lean = 0.0
			b.ghost = 0.0
			b.gx = 0.0
			b.gy2 = 0.0
			_ufo_pick(b)
		"orrery":
			b.clk = 0.0                                  # the clock is the only state
			b.mi = 0
		"mirror":
			b.fi = 0
			b.hist = []
		"idle":
			b.blink_t = 2.0
			b.shift_t = 3.0
			b.side = 1.0
			b.lean = 0.0
			b.gaze_t = 0.0
			b.look = Vector2.ZERO
			b.gaze = Vector2(b.w * 0.75, b.h * 0.3)
		"yacht":
			b.wi = 0
			b.ph = 0.0                                   # ph: the wave's own clock, so a wind change never jumps


static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	match b.id:
		"hover":
			b.excite = 1.0
		"orbit":
			b.dir = -b.dir
		"eight":
			b.ri = (b.ri + 1) % (D.ratios as Array).size()
			b.trail = []
		"undulate":
			b.boost = 1.0
		"pendulum":
			var piv := Vector2(b.w / 2.0, b.h * float(D.pivot))
			b.th = atan2(pos.x - piv.x, pos.y - piv.y)   # angle measured from "straight down"
			b.om = 0.0
			b.gth = b.th                                 # lift both bobs there, let go
			b.gom = 0.0
		"jitter":
			b.fi = (b.fi + 1) % (D.freqs as Array).size()
		"nest":
			b.frozen = -1 if b.frozen >= 2 else b.frozen + 1
		"xfade":
			b.target = 1.0 - b.target
			b.timer = 0.0
		"bullethell":
			b.pattern = 1 - b.pattern                    # the new pattern starts fresh
			b.reset = true
		"ufo":                                           # summon: aim the next blink here, hurry it
			b.nx = clampf(pos.x, b.w * 0.1, b.w * 0.9)
			b.ny = clampf(pos.y, b.h * 0.15, b.h * 0.6)
			b.timer = maxf(b.timer, float(D.dwell) - float(D.tele))
		"orrery":
			b.mi = (b.mi + 1) % (D.mults as Array).size()
		"mirror":
			b.fi = (b.fi + 1) % (D.folds as Array).size()
		"idle":
			b.gaze = pos
			b.gaze_t = -4.0
		"yacht":
			b.wi = (b.wi + 1) % (D.winds as Array).size()


static func tick(b: Dictionary, dt: float, t: float) -> void:
	var D: Dictionary = b.D
	match b.id:
		"hover":
			b.excite = maxf(0.0, b.excite - dt * float(D.decay))
		"orbit":
			b.th += dt * float(D.speed) * b.dir
			b.mth += dt * float(D.moonSpeed) * b.dir    # the moon runs its own, faster clock
		"eight":
			var pair: Array = (D.ratios as Array)[b.ri]
			var a: int = pair[0]
			var bb: int = pair[1]
			var T: float = t * float(D.spd)
			var c := Vector2(b.w / 2.0, b.h * 0.5)
			b.trail.append(c + Vector2(cos(a * T) * b.w * float(D.rx), sin(bb * T) * b.h * float(D.ry)))
			if b.trail.size() > int(D.trail):
				b.trail.pop_front()
		"undulate":
			b.boost = maxf(0.0, b.boost - dt * 0.55)
			b.hx += dt * (float(D.speed) + b.boost * float(D.burst))   # the burst is real thrust
			if b.hx - int(D.n) * float(D.sp) > b.w + 20.0:
				b.hx = -20.0                             # swim off, swim back on
		"pendulum":
			var K: float = D.k
			var DAMP: float = D.damp
			b.om += (-K * sin(b.th) - DAMP * b.om) * dt   # the true equation
			b.th += b.om * dt
			b.gom += (-K * b.gth - DAMP * b.gom) * dt     # the shortcut: sin(θ) → θ
			b.gth += b.gom * dt
		"jitter":
			pass                                         # no memory: the traces fill while drawing
		"nest":
			var clk: Array = b.clk
			for i in 3:
				if i != b.frozen:
					clk[i] += dt
		"xfade":
			b.timer += dt
			if b.timer > float(D.hold):
				b.timer = 0.0
				b.target = 1.0 - b.target
			var k: float = b.k
			k += (1.0 if b.target > k else -1.0) * dt / float(D.blendTime)   # a linear ramp...
			if k < 0.0:
				k = 0.0
			if k > 1.0:
				k = 1.0
			b.k = k
		"bullethell":
			if b.reset:
				b.t0 = t
				b.reset = false
		"ufo":
			b.timer += dt
			if b.timer >= float(D.dwell):                # the blink
				var x: float = b.hx + sin(t * float(D.f1)) * b.w * float(D.ax)
				var y: float = b.hy + sin(t * float(D.f2) + 1.0) * b.h * float(D.ay)
				b.timer = 0.0
				b.ghost = 1.0
				b.gx = x
				b.gy2 = y
				b.lean = 0.35 if b.nx > b.hx else -0.35  # reoriented instantly — no turn animation
				b.hx = b.nx
				b.hy = b.ny
				_ufo_pick(b)
			b.lean -= b.lean * Kit.smooth(3.0, dt)
			b.ghost = maxf(0.0, b.ghost - dt * 2.5)
		"orrery":
			b.clk += dt * float((D.mults as Array)[b.mi])
		"mirror":
			pass                                         # the one real position is a formula of t
		"idle":
			b.blink_t -= dt
			if b.blink_t <= 0.0:
				b.blink_t = maxf(0.4, float(D.blinkEvery) + randf_range(-float(D.blinkJitter), float(D.blinkJitter)))
			b.shift_t -= dt
			if b.shift_t <= 0.0:
				b.shift_t = float(D.shiftEvery) * randf_range(0.7, 1.3)
				b.side = -b.side
			b.lean += (b.side - b.lean) * Kit.smooth(3.0, dt)   # −1 … 1, eased
			b.gaze_t += dt
			if b.gaze_t > 2.6:                           # its own curiosity
				b.gaze_t = 0.0
				b.gaze = Vector2(randf_range(b.w * 0.1, b.w * 0.9), randf_range(b.h * 0.1, b.h * 0.7))
			var R: float = b.h * 0.13
			var sy: float = 1.0 + sin(t * TAU / float(D.breathP)) * float(D.breath)
			var bx: float = b.w / 2.0 + b.lean * float(D.shift) * b.w
			var by: float = b.gy - R * sy
			var ey: float = by - R * 0.15
			var gaze: Vector2 = b.gaze
			var dv := gaze - Vector2(bx, ey)
			var d: float = dv.length()
			if d == 0.0:
				d = 1.0
			var look: Vector2 = b.look
			look += (dv / d - look) * Kit.smooth(float(D.lookRate), dt)   # look-at, smoothed
			b.look = look
		"yacht":
			var wind: float = (D.winds as Array)[b.wi]
			b.ph += dt * wind


static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	Kit.stage(n, b)
	var D: Dictionary = b.D
	var origin: Vector2 = (b.rect as Rect2).position
	match b.id:
		"hover":
			Kit.ground(n, b)
			# the entire behaviour is ONE line of maths: y = rest + sin(t·2π/period)·amp.
			# the rest is presentation: the tilt is the curve's SLOPE (its derivative,
			# cos), and the shadow shrinks as the body rises — altitude for free.
			var amp: float = b.h * float(D.amp) * (1.0 + b.excite * float(D.exciteAmp))
			var w: float = TAU / (float(D.period) * (1.0 - b.excite * float(D.exciteSpeed)))   # excited = faster AND higher
			var rest: float = b.gy - b.h * float(D.rest)
			var y: float = rest + sin(t * w) * amp
			var tilt: float = cos(t * w) * float(D.tilt)      # the derivative leans the body
			var alt: float = (b.gy - y) / (b.gy - rest + amp)   # 0-ish at the floor, ~1 up high
			n.draw_set_transform(origin + Vector2(b.w / 2.0, b.gy - 3.0), 0.0, Vector2(1.3 - alt * 0.55, 4.0 / 17.0))
			n.draw_circle(Vector2.ZERO, 17.0, Color(0, 0, 0, 0.4))   # the altitude shadow
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.mote(n, b, Vector2(b.w / 2.0, y), tilt)
			Kit.label(n, b, "y = rest + sin(t · 2π/%s) · amp" % [D.period], Vector2(b.w / 2.0, b.gy + 18.0), LBL, true)
		"orbit":
			# polar coordinates name a point by (angle θ, radius r) instead of (x, y).
			# the conversion — x = cos(θ)·r, y = sin(θ)·r — is the bridge every orbit,
			# radar sweep, and joint chain crosses. the moon shows frames NESTING:
			# it orbits the mote exactly the way the mote orbits the sun.
			var c := Vector2(b.w / 2.0, b.h * 0.52)
			var r: float = minf(b.w, b.h) * float(D.radius) + sin(t * 0.7) * float(D.breathe)   # r can breathe too
			var th: float = b.th
			var dir: float = b.dir
			var p := c + Vector2(cos(th), sin(th)) * r   # ← polar → Cartesian, the whole trick
			Kit.ring(n, c, r, Color(0.91, 0.898, 0.957, 0.10))
			Kit.dot(n, c, 7.0, Kit.TARGET)
			n.draw_line(c, p, Kit.DIM, 1.0)
			# the angle, drawn as an arc (the canvas sweeps anticlockwise when dir < 0)
			var sweep_end: float = fposmod(th, TAU) if dir > 0.0 else -fposmod(-th, TAU)
			n.draw_arc(c, 16.0, 0.0, sweep_end, 24, Color(0.961, 0.757, 0.412, 0.7), 1.0)
			Kit.label(n, b, "θ", c + Vector2(24, -6), Color(0.961, 0.757, 0.412, 0.8))
			Kit.label(n, b, "r", c + (p - c) * 0.55 + Vector2(6, 0))
			Kit.mote(n, b, p, th + dir * PI / 2.0)       # heading = tangent to the circle
			Kit.dot(n, p + Vector2(cos(b.mth), sin(b.mth)) * float(D.moonR), 3.5, Kit.GOOD)
			Kit.label(n, b, "x = cos(θ)·r   y = sin(θ)·r", Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"eight":
			# a Lissajous curve: x follows cos(a·t), y follows sin(b·t). when a and b
			# are small whole numbers the path closes into a knot — 1:2 is the figure
			# eight. bosses fly these because they look deliberate and cost nothing.
			var pair: Array = (D.ratios as Array)[b.ri]
			var a: int = pair[0]
			var bb: int = pair[1]
			var c := Vector2(b.w / 2.0, b.h * 0.5)
			var rx: float = b.w * float(D.rx)
			var ry: float = b.h * float(D.ry)
			var spd: float = D.spd
			var path := PackedVector2Array()                 # the whole path, previewed
			for i in 129:
				var s := (i / 128.0) * TAU
				path.append(c + Vector2(cos(a * s) * rx, sin(bb * s) * ry))
			n.draw_polyline(path, Color(0.91, 0.898, 0.957, 0.12), 1.0)
			var T: float = t * spd
			var p := c + Vector2(cos(a * T) * rx, sin(bb * T) * ry)
			var v := Vector2(-sin(a * T) * a * rx * spd,     # the velocity is the
				cos(bb * T) * bb * ry * spd)                 # derivative, letter for letter
			var trail: Array = b.trail
			for i in trail.size():
				Kit.dot(n, trail[i], 1.6, Color(0.541, 0.851, 0.961, i / float(trail.size()) * 0.35))
			Kit.arrow(n, p, p + v * 0.22, Kit.GOOD)
			Kit.mote(n, b, p, v.angle())
			Kit.label(n, b, "x = cos(%dt)   y = sin(%dt)" % [a, bb], Vector2(b.w / 2.0, 16.0), LBL, true)
			Kit.label(n, b, "the arrow is the derivative (velocity)", Vector2(b.w / 2.0, b.h - 8.0), Color(0.608, 0.886, 0.541, 0.6), true)
		"undulate":
			# every segment reads the SAME sine — just a little later than the one in
			# front (a PHASE OFFSET per joint). offset in time down a line of bodies
			# = a wave travelling in space. tails, banners, caterpillars: this trick.
			var N: int = D.n
			var SP: float = D.sp
			var freq: float = float(D.freq) * (1.0 + b.boost * 0.9)
			var amp: float = b.h * float(D.amp) * (1.0 + b.boost * 0.6)
			var mid: float = b.h * 0.45
			var phase: float = D.phase
			for i in range(N - 1, -1, -1):                   # tail first, head on top
				var x: float = b.hx - i * SP
				var grow := 0.35 + (i / float(N)) * 0.9      # the wave grows toward the tail
				var y := mid + sin(t * freq - i * phase) * amp * grow
				var rr := 8.0 - (i / float(N)) * 5.76        # bodies shrink toward the tail
				var col := Kit.MOVER if i == 0 else Color(0.541, 0.851, 0.961, 0.75 - (i / float(N)) * 0.56)
				Kit.dot(n, Vector2(x, y), maxf(2.0, rr), col)
				if i == 0:                                   # the head gets the eye
					Kit.dot(n, Vector2(x + 3.0, y - 2.5), 1.8, Kit.NIGHT)
			Kit.label(n, b, "segment i:  y = sin(t·f − i·%s) · amp" % [D.phase], Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"pendulum":
			# the honest pendulum obeys  α = −(g/L)·sin(θ)  — a second-order
			# differential equation, solved live by integrating twice a frame:
			# ω += α·dt, then θ += ω·dt. the ghost uses the classroom shortcut
			# sin(θ) ≈ θ. watch them agree at small swings and drift apart at big
			# ones — that drift is why games integrate instead of using formulas.
			var piv := Vector2(b.w / 2.0, b.h * float(D.pivot))
			var L: float = b.h * float(D.length)
			var bob := piv + Vector2(sin(b.th), cos(b.th)) * L
			var gb := piv + Vector2(sin(b.gth), cos(b.gth)) * L
			n.draw_line(piv, gb, Kit.DIM, 1.0)
			Kit.ring(n, gb, 8.0, Kit.DIM, 1.5)
			n.draw_line(piv, bob, Kit.BONE, 2.0)
			Kit.dot(n, piv, 3.0, Kit.BONE)
			Kit.dot(n, bob, 9.0, Kit.MOVER)
			Kit.label(n, b, "α = −(g/L)·sin θ", bob + Vector2(14, 0), Color(0.541, 0.851, 0.961, 0.75))
			Kit.label(n, b, "sin θ ≈ θ (the ghost)", gb + Vector2(12, -10), Kit.DIM)
		"jitter":
			# three motes, one errand: wobble in place. WHITE NOISE draws a fresh
			# rand() every frame — no memory, so it can only twitch, whatever f is.
			# value NOISE is randomness with memory of its neighbours: smooth hills
			# between random heights, so sample it slowly (small f) for drift and
			# quickly (big f) for shiver. the summed sines are perfectly periodic —
			# organic-ish, but they repeat. the trace under each is its last y's.
			Kit.ground(n, b)
			var f: float = (D.freqs as Array)[b.fi]
			var rest: float = b.gy - b.h * 0.36
			var cols := [Kit.MAGIC, Kit.MOVER, Kit.GOOD]
			var sineB: float = D.sineB
			var history: int = D.history
			var hist: Array = b.hist
			for i in 3:
				var nx: float
				var ny: float
				if i == 0:
					nx = randf_range(-1.0, 1.0)
					ny = randf_range(-1.0, 1.0)
				elif i == 1:
					nx = Kit.noise(t * f + 37.0)
					ny = Kit.noise(t * f)
				else:
					nx = sin(t * f * 1.3 + 1.0) * 0.6 + sin(t * f * sineB * 1.3) * 0.4
					ny = sin(t * f) * 0.6 + sin(t * f * sineB) * 0.4
				var cx: float = b.w * (0.2 + i * 0.3)
				var x: float = cx + nx * b.w * float(D.ampX)
				var y: float = rest + ny * b.h * float(D.amp)
				var h: Array = hist[i]
				h.append(ny)
				if h.size() > history:
					h.pop_front()
				var base: float = b.gy - b.h * 0.12         # the trace: a little seismograph
				var span: float = b.w * 0.1
				Kit.line(n, Vector2(cx - span, base), Vector2(cx + span, base), Color(0.91, 0.898, 0.957, 0.12), 1.0)
				var trace := PackedVector2Array()
				for j in h.size():
					trace.append(Vector2(cx - span + (j / float(history - 1)) * span * 2.0, base + float(h[j]) * b.h * 0.04))
				if trace.size() >= 2:
					n.draw_polyline(trace, Color(0.91, 0.898, 0.957, 0.4), 1.0)
				Kit.mote(n, b, Vector2(x, y), nx * 0.3, cols[i], 7.0)
				Kit.label(n, b, JITTER_NAMES[i], Vector2(cx, b.gy + 18.0), LBL, true)
			Kit.label(n, b, "f = %s" % [(D.freqs as Array)[b.fi]], Vector2(b.w / 2.0, 14.0), LBL, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"nest":
			# a COORDINATE SPACE is an origin plus an angle. to place a child, take its
			# local offset, rotate it by the parent's angle, add the parent's origin —
			# and the child's angle is the parent's angle plus its own. do that three
			# times and the light inherits the sway AND the spin without knowing about
			# either. every scene graph, gun turret, and moon does exactly this.
			# freezing a level stops one clock; the other two keep composing.
			var clk: Array = b.clk
			var c0: float = clk[0]
			var c1: float = clk[1]
			var c2: float = clk[2]
			var w1: float = D.w1
			var p1 := Vector2(b.w / 2.0 + sin(c0 * w1) * b.w * float(D.sway), b.h * 0.56)   # frame 1
			var a1: float = sin(c0 * w1 + 0.7) * float(D.tilt)
			var hw: float = b.w * 0.16
			Kit.poly(n, [_xf(p1, a1, Vector2(-hw, -4)), _xf(p1, a1, Vector2(hw, -4)),
				_xf(p1, a1, Vector2(hw, 4)), _xf(p1, a1, Vector2(-hw, 4))], Color(0.788, 0.769, 0.894, 0.35))
			var p2 := _xf(p1, a1, Vector2(0, -12))            # frame 2: the turret sits on the platform
			var a2: float = a1 + c1 * float(D.w2)
			var p3 := _xf(p2, a2, Vector2(b.w * float(D.arm), 0))   # frame 3: the tip of the turret's arm
			var a3: float = a2 + c2 * float(D.w3)
			var p4 := _xf(p3, a3, Vector2(b.w * float(D.r3), 0))    # the light, three rotations deep
			Kit.line(n, p2, p3, Kit.BONE, 2.5)
			Kit.ring(n, p3, b.w * float(D.r3), Color(0.961, 0.757, 0.412, 0.3))
			Kit.line(n, p3, p4, Kit.DIM, 1.0)
			_axes(n, p1, a1, Kit.BONE)
			_axes(n, p2, a2, Kit.MOVER)
			_axes(n, p3, a3, Kit.TARGET)
			Kit.mote(n, b, p2, a2)
			Kit.dot(n, p4, 4.0, Kit.TARGET)
			for i in 3:
				var frozen_here: bool = b.frozen == i
				Kit.label(n, b, NEST_NAMES[i] + (" · frozen" if frozen_here else ""),
					Vector2(b.w * (0.17 + i * 0.33), 14.0), Kit.HOT if frozen_here else LBL, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"xfade":
			# a BLEND TREE with two leaves. both motions are evaluated every frame
			# whether or not they are visible; the mote is drawn at a weighted mix,
			# and the weight w is the only thing that animates when the blend flips.
			# this is how a walk becomes a run without a pop: not by switching clips,
			# but by crossfading two positions (or two poses) with one number.
			Kit.ground(n, b)
			var w: float = smoothstep(0.0, 1.0, b.k)      # ...smoothstepped = an eased crossfade
			var ax: float = b.w * 0.25
			var ay: float = b.gy - 9.0 - absf(sin(t * float(D.wA))) * b.h * float(D.ampA)   # A: the bounce
			var bx: float = b.w * 0.75
			var by: float = b.gy - b.h * float(D.restB) + sin(t * float(D.wB)) * b.h * float(D.ampB)   # B: the hover
			var x := lerpf(ax, bx, w)                        # ← the blend
			var y := lerpf(ay, by, w)
			Kit.line(n, Vector2(ax, ay), Vector2(bx, by), Color(0.91, 0.898, 0.957, 0.12), 1.0)
			Kit.mote(n, b, Vector2(ax, ay), 0.0, Color(0.608, 0.886, 0.541, 0.35))   # the two ghosts, always computed
			Kit.mote(n, b, Vector2(bx, by), 0.0, Color(0.788, 0.627, 0.961, 0.35))
			Kit.mote(n, b, Vector2(x, y), 0.0)
			var sx0: float = b.w * 0.25                      # the blend slider
			var sx1: float = b.w * 0.75
			var sy := 18.0
			Kit.line(n, Vector2(sx0, sy), Vector2(sx1, sy), Kit.DIM, 2.0)
			Kit.dot(n, Vector2(lerpf(sx0, sx1, w), sy), 4.0, Kit.TARGET)
			Kit.label(n, b, "A bounce", Vector2(sx0, sy + 14.0), Color(0.608, 0.886, 0.541, 0.7), true)
			Kit.label(n, b, "B hover", Vector2(sx1, sy + 14.0), Color(0.788, 0.627, 0.961, 0.7), true)
			Kit.label(n, b, "w = %.2f" % w, Vector2(b.w / 2.0, sy - 6.0), LBL, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"bullethell":
			# no bullet has a velocity, or even a position, in memory. bullet i was
			# fired at tᵢ = i·interval, aimed at θᵢ = i·golden + tᵢ·spin, and at any
			# moment it sits at origin + (cos θᵢ, sin θᵢ)·speed·(t − tᵢ): polar →
			# Cartesian, exactly Orbit's bridge. we only count which i are still on
			# screen. the golden angle (≈137.5°) never repeats, so the spiral never
			# lines up into spokes; the ring pattern fires N at once, with a twist.
			var o := Vector2(b.w / 2.0, b.h * 0.46)
			var T: float = t - b.t0
			var v: float = b.w * float(D.speed)
			var life: float = (Vector2(b.w, b.h).length() * 0.5 + 12.0) / v   # gone once past the corners
			Kit.ring(n, o, 7.0 + sin(t * 5.0) * 1.5, Kit.MAGIC, 1.5)
			Kit.dot(n, o, 3.0, Kit.MAGIC)
			var cnt := 0
			var pattern: int = b.pattern
			if pattern == 0:
				var interval: float = D.interval
				var golden: float = D.golden
				var spin: float = D.spin
				var i_max: int = floori(T / interval)
				var i_min: int = maxi(0, ceili((T - life) / interval))
				for i in range(i_min, i_max + 1):
					var ti: float = i * interval
					var age: float = T - ti
					var th: float = i * golden + ti * spin
					Kit.dot(n, o + Vector2(cos(th), sin(th)) * v * age, 2.6, Kit.HOT)
					cnt += 1
			else:
				var ring_every: float = D.ringEvery
				var ring_n: int = D.ringN
				var ring_twist: float = D.ringTwist
				var b_max: int = floori(T / ring_every)
				var b_min: int = maxi(0, ceili((T - life) / ring_every))
				for bi in range(b_min, b_max + 1):
					var age: float = T - bi * ring_every
					for k in ring_n:
						var th: float = k * TAU / ring_n + bi * ring_twist
						Kit.dot(n, o + Vector2(cos(th), sin(th)) * v * age, 2.6, Kit.HOT)
						cnt += 1
			var px: float = b.w / 2.0 + sin(t * 0.9) * b.w * 0.3   # the player, weaving along the bottom
			Kit.mote(n, b, Vector2(px, b.h * 0.86), 0.0 if cos(t * 0.9) > 0.0 else PI, Kit.MOVER, 6.0)
			Kit.label(n, b, "%s · %d bullets, 0 stored" % ["ring" if pattern else "spiral", cnt], Vector2(b.w / 2.0, 14.0), LBL, true)
			Kit.label(n, b, "θₖ = k·2π/N + b·twist    p = o + dir·v·age" if pattern else D.label, Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"ufo":
			# chapter 05's alien: two sines whose rates share no simple ratio, so the
			# hover never quite repeats — the cheapest "alive". then the other kind
			# of motion: none at all. a TELEGRAPH (the beam) warns for a moment, and
			# the saucer is simply elsewhere next frame, already leaning toward its
			# new heading — a zero-duration move is still a move, and the warning is
			# what makes it fair.
			Kit.ground(n, b)
			var x: float = b.hx + sin(t * float(D.f1)) * b.w * float(D.ax)
			var y: float = b.hy + sin(t * float(D.f2) + 1.0) * b.h * float(D.ay)
			var dwell: float = D.dwell
			var tele: float = D.tele
			var warn: float = clampf((b.timer - (dwell - tele)) / tele, 0.0, 1.0)
			var ghost: float = b.ghost
			var lean: float = b.lean
			if warn > 0.0:                                   # the beam: the telegraph
				Kit.poly(n, [Vector2(x - 5, y + 4), Vector2(x + 5, y + 4), Vector2(x + 22, b.gy), Vector2(x - 22, b.gy)],
					Color(0.788, 0.627, 0.961, 0.06 + warn * 0.24))
			if ghost > 0.0:
				Kit.ring(n, Vector2(b.gx, b.gy2), 12.0 + (1.0 - ghost) * 16.0, Color(0.788, 0.627, 0.961, ghost * 0.5), 1.5)
			Kit.ring(n, Vector2(b.nx, b.ny), 5.0, Color(0.961, 0.757, 0.412, 0.35))   # where it will be next
			n.draw_set_transform(origin + Vector2(x, y), lean, Vector2(1.0, 5.0 / 18.0))
			n.draw_circle(Vector2.ZERO, 18.0, Kit.MAGIC)      # the hull: an 18 × 5 ellipse
			n.draw_set_transform(origin + Vector2(x, y), lean, Vector2.ONE)
			var dome := PackedVector2Array()                  # the dome: a half disc, π → 0
			for k in 17:
				var a := PI + (k / 16.0) * PI
				dome.append(Vector2(0, -3) + Vector2(cos(a), sin(a)) * 7.0)
			n.draw_colored_polygon(dome, Color(0.91, 0.898, 0.957, 0.7))
			for k in 4:                                      # rim lights on their own phases
				var bright := 0.35 + 0.35 * sin(t * 7.0 + k * 1.6)
				Kit.dot(n, Vector2(-12 + k * 8, 1), 1.6, Color(0.961, 0.757, 0.412, bright))
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.label(n, b, "x = hx + sin(%st)·a   y = hy + sin(%st)·b" % [D.f1, D.f2], Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"orrery":
			# KEPLER: a planet on an ellipse with the sun at one FOCUS sweeps equal
			# areas in equal times — so it rushes through the near end and dawdles at
			# the far end (θ̇ ∝ 1/r²). the recipe: the mean anomaly M = n·t grows
			# evenly; solve E − e·sin E = M for the ECCENTRIC ANOMALY E (a few Newton
			# steps); then x = a(cos E − e), y = b·sin E. every body is a pure function
			# of the clock, moons included: moon = planet + rotate(local), as in Nest.
			var s := Vector2(b.w / 2.0, b.h * 0.5)
			var clk: float = b.clk
			var a_list: Array = D.a
			var moons: Array = D.moons
			var moon_rate: float = D.moonRate
			for i in a_list.size():
				var prev := Vector2.ZERO                      # the guide ellipse
				for k in 41:
					var p := _orbit_pt(b, i, k / 40.0 * TAU)
					if k > 0:
						Kit.line(n, s + prev, s + p, Color(0.91, 0.898, 0.957, 0.1), 1.0)
					prev = p
				var p := _planet(b, i, clk)
				var q := _planet(b, i, clk + 0.02)           # q − p: the velocity, by finite difference
				Kit.line(n, s, s + p, Kit.DIM, 1.0)          # the radius vector: short = fast
				var pos := s + p
				if i == 1:
					Kit.mote(n, b, pos, (q - p).angle(), Kit.MOVER, 6.0)
				else:
					Kit.dot(n, pos, 4.0, Kit.BONE)
				for m in int(moons[i]):
					var r: float = 8.0 + m * 5.0
					var ang: float = clk * moon_rate * (1.0 - m * 0.4) + m * 2.0
					Kit.dot(n, pos + Vector2(cos(ang), sin(ang)) * r, 2.0, Kit.GOOD)
			Kit.dot(n, s, 6.0, Kit.TARGET)
			Kit.ring(n, s, 9.0, Color(0.961, 0.757, 0.412, 0.4))
			Kit.label(n, b, "clock ×%s" % [(D.mults as Array)[b.mi]], Vector2(b.w / 2.0, 14.0), LBL, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"mirror":
			# one body moves; N are seen. clone k takes the mote's LOCAL position
			# (relative to the centre), flips its y when k is odd (a mirror), and
			# rotates it by k·360°/N (Nest's parent + rotate(local)). because the
			# mirror alternates, every wedge shares its edges with its neighbours and
			# the picture closes on itself — a kaleidoscope, from one Lissajous.
			var N: int = (D.folds as Array)[b.fi]
			var c := Vector2(b.w / 2.0, b.h / 2.0)
			var S: float = minf(b.w, b.h)
			var T: float = t * float(D.spd)
			var da: float = D.a
			var db: float = D.b
			var l := Vector2(cos(da * T) * S * float(D.rx), sin(db * T) * S * float(D.ry))   # the one real position
			var v := Vector2(-sin(da * T) * da, cos(db * T) * db)                            # its derivative
			var hist: Array = b.hist
			hist.append(l)
			if hist.size() > int(D.trail):
				hist.pop_front()
			for k in N:
				var ang: float = k * TAU / N
				var cs := cos(ang)
				var sn := sin(ang)
				var m: float = -1.0 if k % 2 else 1.0
				Kit.line(n, c, c + Vector2(cs, sn) * S * 0.5, Color(0.91, 0.898, 0.957, 0.08), 1.0)   # the wedge edge
				var pts := PackedVector2Array()
				for i in hist.size():
					var hp: Vector2 = hist[i]
					var x: float = hp.x
					var y: float = hp.y * m                  # mirror, then rotate, then add the centre
					pts.append(c + Vector2(x * cs - y * sn, x * sn + y * cs))
				if pts.size() >= 2:
					n.draw_polyline(pts, Color(0.788, 0.627, 0.961, 0.45) if k else Color(0.541, 0.851, 0.961, 0.6), 1.2)
				var y2: float = l.y * m
				var pk := c + Vector2(l.x * cs - y2 * sn, l.x * sn + y2 * cs)
				if k:
					Kit.dot(n, pk, 4.0, Kit.MAGIC)
				else:
					Kit.mote(n, b, pk, v.angle(), Kit.MOVER, 6.0)
			Kit.label(n, b, "N = %d" % N, Vector2(b.w / 2.0, 14.0), LBL, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"idle":
			# a still character is dead; a character with four tiny clocks is alive.
			# BREATHING is a sine on the body's scale (Hover's sine, pointed at size
			# instead of height); the BLINK is a timer with jitter, because a regular
			# blink reads as a machine; LOOK-AT points the pupils at a gaze point and
			# lerps toward it; the WEIGHT SHIFT is a slower timer toggling a lean.
			# none of them know about the others — they just add up.
			Kit.ground(n, b)
			var closed: bool = b.blink_t < float(D.blinkLen)
			var lean: float = b.lean
			var R: float = b.h * 0.13
			var sy: float = 1.0 + sin(t * TAU / float(D.breathP)) * float(D.breath)   # the breath keeps its volume
			var sx: float = 1.0 / sy
			var bx: float = b.w / 2.0 + lean * float(D.shift) * b.w   # it grows up from the floor
			var by: float = b.gy - R * sy
			n.draw_set_transform(origin + Vector2(bx, b.gy - 2.0), 0.0, Vector2(0.9 * sx, 3.5 / R))
			n.draw_circle(Vector2.ZERO, R, Color(0, 0, 0, 0.35))   # the shadow: an R·0.9·sx × 3.5 ellipse
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			var ey: float = by - R * 0.15
			var gaze: Vector2 = b.gaze
			var look: Vector2 = b.look
			Kit.line(n, Vector2(bx, ey), gaze, Color(0.961, 0.757, 0.412, 0.15), 1.0)
			n.draw_set_transform(origin + Vector2(bx, by), lean * 0.12, Vector2(sx, sy))
			n.draw_circle(Vector2.ZERO, R, Kit.MOVER)
			for e in [-1.0, 1.0]:
				var exx: float = e * R * 0.34
				var eyy: float = -R * 0.15
				var er: float = R * 0.2
				if closed:
					Kit.line(n, Vector2(exx - er, eyy), Vector2(exx + er, eyy), Kit.NIGHT, 2.0)
				else:
					Kit.dot(n, Vector2(exx, eyy), er, Kit.INK)
					Kit.dot(n, Vector2(exx + look.x * er * 0.45, eyy + look.y * er * 0.45), er * 0.5, Kit.NIGHT)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.ring(n, gaze, 5.0, Kit.TARGET, 1.5)
			Kit.dot(n, gaze, 2.0, Kit.TARGET)
			Kit.label(n, b, "blink" if closed else "next blink in %.1f s" % b.blink_t, Vector2(b.w / 2.0, 14.0), LBL, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"yacht":
			# Undulate's trick, but the SPACE is the sea: y = Σ amp·sin(k·x − ω·t) is
			# a wave travelling at ω ÷ k pixels a second. the boat doesn't move — the
			# wave moves under it, and it sits at wave(boatX, t). its tilt is the
			# wave's SLOPE there, the derivative dy/dx — for a sine, a cos with the
			# same argument (Normals' lesson: the surface tells you which way is up).
			# foam rides each crest, which is wherever sin(k·x − ω·t) = 1.
			var wind: float = (D.winds as Array)[b.wi]
			var sea: Array = []                              # the surface, then the water under it
			var x := 0.0
			while x <= b.w:
				sea.append(Vector2(x, _wave(b, x, wind)))
				x += 5.0
			var surface := PackedVector2Array(sea)
			sea.append(Vector2(b.w, b.h))
			sea.append(Vector2(0, b.h))
			Kit.poly(n, sea, Color(0.541, 0.851, 0.961, 0.12))
			n.draw_polyline(surface, Color(0.541, 0.851, 0.961, 0.6), 1.5)
			var L1: float = float(D.lam1) * b.w
			var k1: float = TAU / L1
			var fx: float = fmod((PI / 2.0 + float(D.w1) * b.ph) / k1, L1)   # the first crest of the long wave...
			fx -= L1
			while fx < b.w + L1:                             # ...and every crest after it
				for j in [-1, 0, 1]:
					Kit.dot(n, Vector2(fx + j * 5, _wave(b, fx + j * 5, wind) - 2.5), 1.5, Color(0.91, 0.898, 0.957, 0.6))
				fx += L1
			var bx: float = b.w * float(D.boatX)
			var by: float = _wave(b, bx, wind)
			var tilt: float = atan(_slope(b, bx, wind))
			var sail: float = sin(t * 0.7) * 0.5 * wind      # the wind sine leans the sail
			n.draw_set_transform(origin + Vector2(bx, by), tilt, Vector2.ONE)
			Kit.poly(n, [Vector2(-16, -2), Vector2(16, -2), Vector2(10, 6), Vector2(-10, 6)], Kit.BONE)
			Kit.line(n, Vector2(0, -2), Vector2(0, -26), Kit.INK, 1.5)
			Kit.poly(n, [Vector2(0, -25), Vector2(0, -6), Vector2(-(12.0 + sail * 8.0), -10)], Kit.MOVER)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.label(n, b, "wind %s · tilt %d°" % [(D.winds as Array)[b.wi], roundi(rad_to_deg(tilt))], Vector2(b.w / 2.0, 14.0), LBL, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), LBL, true)


# ---- helpers: the JS closures' inner functions ------------------------------

## Nest: ← parent + rotate(local)
static func _xf(o: Vector2, a: float, l: Vector2) -> Vector2:
	return Vector2(o.x + cos(a) * l.x - sin(a) * l.y, o.y + sin(a) * l.x + cos(a) * l.y)

## Nest: a frame's x axis (bright) and y axis (faint)
static func _axes(n: CanvasItem, o: Vector2, a: float, c: Color) -> void:
	Kit.line(n, o, o + Vector2(cos(a), sin(a)) * 14.0, c, 1.0)
	Kit.line(n, o, o + Vector2(-sin(a), cos(a)) * 9.0, Kit.DIM, 1.0)

## Ufo: choose where the next blink lands
static func _ufo_pick(b: Dictionary) -> void:
	b.nx = randf_range(b.w * 0.15, b.w * 0.85)
	b.ny = randf_range(b.h * 0.18, b.h * 0.55)

## Orrery: a point on ellipse i, relative to the sun
static func _orbit_pt(b: Dictionary, i: int, E: float) -> Vector2:
	var D: Dictionary = b.D
	var S: float = minf(b.w, b.h)
	var a: float = float((D.a as Array)[i]) * S
	var e: float = (D.e as Array)[i]
	var bb: float = a * sqrt(1.0 - e * e)
	var px: float = a * (cos(E) - e)
	var py: float = bb * sin(E)
	var peri: float = (D.peri as Array)[i]
	var c := cos(peri)
	var s := sin(peri)
	return Vector2(px * c - py * s, px * s + py * c)

## Orrery: planet i at clock T — Kepler's equation by Newton's method
static func _planet(b: Dictionary, i: int, T: float) -> Vector2:
	var D: Dictionary = b.D
	var e: float = (D.e as Array)[i]
	var nn: float = float(D.rate) / pow(float((D.a as Array)[i]), 1.5)
	var M: float = fmod(nn * T, TAU)
	var E: float = M + e * sin(M)
	for k in 8:
		E -= (E - e * sin(E) - M) / (1.0 - e * cos(E))   # Newton's method
	if not is_finite(E):
		E = M
	return _orbit_pt(b, i, E)

## Yacht: the sea's height at x
static func _wave(b: Dictionary, x: float, wind: float) -> float:
	var D: Dictionary = b.D
	var k1: float = TAU / (float(D.lam1) * b.w)
	var k2: float = TAU / (float(D.lam2) * b.w)
	var ph: float = b.ph
	return b.h * float(D.mid) - b.h * float(D.amp1) * wind * sin(k1 * x - float(D.w1) * ph) \
		- b.h * float(D.amp2) * wind * sin(k2 * x - float(D.w2) * ph + 1.0)

## Yacht: d/dx of the line above
static func _slope(b: Dictionary, x: float, wind: float) -> float:
	var D: Dictionary = b.D
	var k1: float = TAU / (float(D.lam1) * b.w)
	var k2: float = TAU / (float(D.lam2) * b.w)
	var ph: float = b.ph
	return -b.h * float(D.amp1) * wind * k1 * cos(k1 * x - float(D.w1) * ph) \
		- b.h * float(D.amp2) * wind * k2 * cos(k2 * x - float(D.w2) * ph + 1.0)
