extends RefCounted

const Kit := preload("res://scenes/motion/kit.gd")
## INPUT & INTENT — thirteen movement styles, ported from the web lexicon
## (docs/locomotion.js). What the player MEANT. Between the hand and the
## body sits a small, forgiving interpreter: a grace timer that keeps a jump
## legal after the ledge is gone, a buffer that holds a press until it
## becomes legal, a cut that lets a short tap be a short hop. Sticks are
## noisy, so there are dead zones and rescaling; diagonals cheat, so there
## is normalising; one button becomes three by timing windows, or a charge
## by holding. Flings read a history of pointer positions, swipes bucket a
## delta into directions, a motion parser matches a ring buffer against
## ↓↘→, and a virtual stick and a mouse-look turn a finger and a mouse into
## an intention.

const TITLE := "Input & intent"
const BLURB := "what the player MEANT — grace timers, buffers, dead zones, curves, gestures, flings: the code between the hand and the body"
const DEFS := [
	{ "id": "coyote", "letter": "C", "name": "Coyote",
		"hint": "a jump is legal for 100 ms after the feet leave the ledge — green if inside the window, red X if not — press to jump now",
		"dials": { "coyote": 0.1,        # seconds of grace after the ground is lost
			"g": 2.2,                    # gravity, ×H per second²
			"jumpH": 0.28,               # apex height, ×H (Jump's √(2gh))
			"speed": 0.35,               # run speed, ×W per second
			"ledge": 0.45,               # the ledge ends here, ×W
			"far": 0.72,                 # the far platform starts here, ×W
			"autoAt": [0.05, 0.28],      # the idle loop presses this long after leaving: one inside, one outside
			"label": "grace = coyote − (t − tLeft) > 0 ?" },
		"rhyme": { "name": "Cliffhanger", "hint": "a whole half-second of grace and floatier gravity — the forgiving cartoon platformer where the air is nearly a floor",
			"dials": { "coyote": 0.5, "g": 1.4 } } },
	{ "id": "jumpbuffer", "letter": "J", "name": "Jumpbuffer",
		"hint": "a press up to 150 ms BEFORE landing is stored and fired on touchdown; earlier presses expire (Coyote's mirror) — press early",
		"dials": { "buffer": 0.15,       # seconds a press is remembered
			"g": 2.4,                    # gravity, ×H per second²
			"drop": 0.55,                # the drop height, ×H above the ground
			"jumpH": 0.22,               # the buffered jump's apex, ×H
			"autoLead": [0.08, 0.42],    # the idle loop presses this long before landing: inside, then too early
			"rest": 0.7,                 # seconds standing before the next drop
			"label": "fire on land if t − tPress ≤ buffer" },
		"rhyme": { "name": "Jittery", "hint": "a 40 ms buffer under fast gravity — the strict arcade version where early means wrong",
			"dials": { "buffer": 0.04, "g": 4.5 } } },
	{ "id": "variable", "letter": "V", "name": "Variable", "drag": true,
		"hint": "VARIABLE JUMP HEIGHT: hold = keep rising, release = vy × cut and heavier gravity; three ghosts hold 0.05/0.15/0.35 s — drag: hold to rise",
		"dials": { "g": 2.4,             # gravity, ×H per second²
			"v0": 1.0,                   # launch speed, ×H per second
			"cut": 0.5,                  # on release, vy is multiplied by this (if still rising)
			"fallG": 1.0,                # gravity multiplier after release / past the apex
			"holdMax": 0.35,             # the longest a hold counts, seconds
			"holds": [0.05, 0.15, 0.35], # the three ghosts' hold times
			"every": 2.2,                # seconds between the ghosts' jumps
			"gap": 0.12,                 # no press for this long = released
			"label": "release: vy ×= cut · g ×= fallG" },
		"rhyme": { "name": "Vault", "hint": "a hard cut to 0.3 and gravity ×2.5 the moment you let go — the snappy Celeste-style jump that stops on a dime",
			"dials": { "cut": 0.3, "fallG": 2.5 } } },
	{ "id": "deadzone", "letter": "D", "name": "Deadzone", "drag": true,
		"hint": "a noisy stick three ways: raw, a hard dead zone (a jump at the edge), radial rescale (len − dz)/(1 − dz) with optional snap — drag: be the stick",
		"dials": { "dz": 0.18,           # the dead zone radius, of the stick's 0..1
			"jitter": 0.07,              # white noise added to the stick every frame (Jitter)
			"wander": 0.5,               # how fast the idle stick roams (noise rate)
			"snap": 0,                   # 0 = analogue, 4 or 8 = snap the rescaled stick to that many directions
			"speed": 0.4,                # the motes' top speed, ×W per second
			"hold": 0.4,                 # seconds after a press before the idle stick takes over
			"label": "out = dir · (len − dz) / (1 − dz)" },
		"rhyme": { "name": "Dial", "hint": "dz 0.35 and a four-way snap — an analogue stick pretending to be a d-pad",
			"dials": { "dz": 0.35, "snap": 4 } } },
	{ "id": "normalize", "letter": "N", "name": "Normalize",
		"hint": "two motes lap a course on 8-way input: one adds x and y (√2 faster on diagonals), one NORMALISES; the lap timer shows the cheat — press to set the direction",
		"dials": { "speed": 0.3,         # top speed, ×W per second
			"fourWay": false,            # true = snap the input to 4 directions (no diagonals at all)
			"override": 1.4,             # seconds a press's direction is obeyed before the lap resumes
			"reach": 6,                  # px from a waypoint that counts as arriving
			"label": "v = (x, y) / √(x² + y²) · speed" },
		"rhyme": { "name": "Nimble", "hint": "four directions only and half again the speed — the classic top-down where no diagonal can cheat",
			"dials": { "fourWay": true, "speed": 0.45 } } },
	{ "id": "accelerate", "letter": "A", "name": "Accelerate",
		"hint": "speed approaches the wanted speed by accel or brake on the ground and by a smaller airAccel in the air; the strip graphs it (Inertia) — press left/right, above to jump",
		"dials": { "max": 0.45,          # top speed, ×W per second
			"accel": 1.6,                # ground acceleration, ×W per second²
			"brake": 4.0,                # ground deceleration (slowing or reversing), ×W per second²
			"airAccel": 0.5,             # acceleration while airborne, ×W per second²
			"g": 2.2,                    # gravity, ×H per second²
			"jumpH": 0.26,               # apex, ×H
			"flipEvery": 2.4,            # seconds before the autopilot reverses its wish
			"label": "v → want · max, by accel | brake | airAccel" },
		"rhyme": { "name": "Asphalt", "hint": "brake far above accel and almost no air control — the heavy runner whose jumps are promises",
			"dials": { "accel": 0.8, "brake": 6, "airAccel": 0.05 } } },
	{ "id": "multitap", "letter": "M", "name": "Multitap", "drag": true,
		"hint": "one button, three verbs by TIMING WINDOWS: tap < tapMax = hop, hold > holdMin = charge, two taps within dblGap = dash — tap, or drag to hold",
		"dials": { "tapMax": 0.18,       # a press shorter than this is a tap
			"holdMin": 0.3,              # a press longer than this is a hold
			"dblGap": 0.25,              # two taps this close = a double-tap
			"hop": 0.1,                  # the tap's hop apex, ×H
			"chargeH": 0.3,              # extra apex a full charge adds, ×H
			"chargeT": 0.6,              # seconds of holding for a full charge
			"dash": 1.5,                 # the dash burst, ×W per second (Dash)
			"k": 6,                      # the dash decay per second
			"g": 2.4,                    # gravity, ×H per second²
			"span": 3.0,                 # seconds of timeline shown
			"label": "tap < tapMax · hold > holdMin · gap < dblGap" },
		"rhyme": { "name": "Marathon", "hint": "a hold begins at half a second and the double-tap gap stretches to 0.4 s — the forgiving version for tired thumbs",
			"dials": { "holdMin": 0.5, "dblGap": 0.4 } } },
	{ "id": "charge", "letter": "C", "name": "Charge", "drag": true,
		"hint": "hold to fill; a sweet spot pays a bonus, past max it BACKFIRES; release launches ∝ power (Jump's arc) — drag: hold to charge, let go to fire",
		"dials": { "fill": 1.2,          # seconds of holding to full power
			"max": 1.7,                  # seconds of holding before it backfires
			"sweet": [0.78, 0.95],       # the sweet spot, as a fraction of full power
			"bonus": 1.3,                # range multiplier inside the sweet spot
			"range": 0.7,                # the launch distance at full power, ×W
			"lift": 0.9,                 # the launch's upward speed, ×H per second
			"g": 2.4,                    # gravity, ×H per second²
			"gap": 0.15,                 # no press for this long = released
			"label": "power = min(held / fill, 1) · d ∝ power" },
		"rhyme": { "name": "Cannonball", "hint": "a slow fill, a range past the edge of the screen and a brutal overcharge — the siege gun",
			"dials": { "fill": 2.5, "range": 1.2, "max": 2.9 } } },
	{ "id": "fling", "letter": "F", "name": "Fling", "drag": true,
		"hint": "drag-and-throw: the release velocity is read from the LAST N POINTER POSITIONS and their times (Queue's history), then gravity — drag: fling it",
		"dials": { "n": 6,               # pointer samples averaged at release
			"g": 2.0,                    # gravity, ×H per second²
			"e": 0.6,                    # restitution on the floor and walls
			"drag": 0.1,                 # air drag per second
			"maxV": 3.0,                 # speed cap, ×W per second
			"release": 0.1,              # no press for this long = let go
			"autoEvery": 2.6,            # seconds idle before the ghost finger flings it
			"label": "v = (pₙ − p₁) / (tₙ − t₁), the last n" },
		"rhyme": { "name": "Feather", "hint": "a quarter of the gravity and heavy air drag — a paper plane that sails and settles",
			"dials": { "g": 0.5, "drag": 1.4 } } },
	{ "id": "swipe", "letter": "S", "name": "Swipe", "drag": true,
		"hint": "a pointer delta bucketed into 8 DIRECTIONS, gated by minDist and maxTime; the rose lights the wedge and the mote hops a tile — drag: swipe",
		"dials": { "dirs": 8,            # 4 or 8 compass wedges
			"minDist": 0.12,             # the stroke must travel at least this, ×W
			"maxTime": 0.5,              # ...and finish within this many seconds
			"slide": false,              # true = the mote slides until it hits the wall (Threes)
			"tile": 0.11,                # tile size, ×W
			"release": 0.12,             # no press for this long = the finger lifted
			"autoEvery": 1.7,            # seconds idle before the ghost finger swipes
			"label": "dir = round(atan2(Δy, Δx) / (2π/dirs))" },
		"rhyme": { "name": "Slidepuzzle", "hint": "four wedges, a long minimum stroke, and the mote slides until it hits the wall — the Threes board",
			"dials": { "dirs": 4, "minDist": 0.25, "slide": true } } },
	{ "id": "quartercircle", "letter": "Q", "name": "Quartercircle", "drag": true,
		"hint": "a MOTION INPUT PARSER: the pointer's direction around the mote fills a ring buffer, matched against ↓↘→ within a window; a match fires — drag: trace a quarter circle, release to punch",
		"dials": { "pattern": [2, 1, 0], # sectors of 45°, 0 = →, 1 = ↘, 2 = ↓, 3 = ↙, 4 = ←  (↓↘→ = the fireball)
			"window": 0.5,               # the whole pattern must fit in this many seconds
			"buf": 8,                    # directions remembered
			"gap": 0.15,                 # no press for this long = the release (the punch)
			"speed": 0.9,                # the projectile, ×W per second
			"autoEvery": 2.4,            # seconds between the ghost finger's attempts
			"label": "buffer ⊇ pattern in order, Δt ≤ window ?" },
		"rhyme": { "name": "Qcb", "hint": "the mirrored ↓↙← motion in a tighter window — the quarter-circle back, fired the other way",
			"dials": { "pattern": [2, 3, 4], "window": 0.3 } } },
	{ "id": "virtualstick", "letter": "V", "name": "Virtualstick", "drag": true,
		"hint": "a VIRTUAL JOYSTICK appears where the finger lands: vector = thumb − origin, clamped to a radius; the mote drives by it — drag: the stick",
		"dials": { "radius": 0.12,       # the stick's radius, ×W
			"max": 0.45,                 # the mote's top speed, ×W per second (at full deflection)
			"steer": 5,                  # how fast velocity follows the stick, per second
			"floating": false,           # true = the origin follows the thumb when it leaves the ring
			"gap": 0.25,                 # no press for this long = the finger lifted
			"autoEvery": 2.4,            # seconds idle before the ghost thumb demonstrates
			"label": "v = clamp(thumb − origin, r) / r · max" },
		"rhyme": { "name": "Vespa", "hint": "a floating stick whose ring is towed along by the thumb, and a faster scooter of a mote",
			"dials": { "floating": true, "max": 0.7 } } },
	{ "id": "mouselook", "letter": "M", "name": "Mouselook", "drag": true,
		"hint": "MOUSE-LOOK: yaw and pitch from the pointer's DELTA through a sensitivity curve, pitch clamped; a first-person horizon of posts (Camera) — drag: look",
		"dials": { "sens": 0.006,        # radians per pixel of pointer movement (at accel 1)
			"accel": 1.0,                # the curve: out = |Δ|^accel — 1 is linear, >1 accelerates fast flicks
			"pitchMax": 60,              # degrees up or down the pitch may reach
			"smoothRate": 25,            # how fast the view catches up with the input (big = raw)
			"fov": 90,                   # degrees of world across the screen
			"gap": 0.25,                 # no press for this long = a new grab (no delta across it)
			"label": "yaw += sign(Δx)·|Δx|^accel · sens · pitch ∈ ±max" },
		"rhyme": { "name": "Mecha", "hint": "a third of the sensitivity, a hard 25° pitch clamp and heavy smoothing — a forty-ton head turning",
			"dials": { "sens": 0.002, "pitchMax": 25, "smoothRate": 5 } } },
]

const FAINT := Color(0.91, 0.898, 0.957, 0.55)   # the web label's default ink
const R := 8.0                                     # the mote's radius on most cards
const QC_R := 9.0                                  # Quartercircle's mote
const ACCEL_N := 140                               # Accelerate's strip: samples kept
const FLING_CAP := 16                              # Fling's pointer history
const MT_SCRIPT := [[1, 0.08], [0, 1.0], [1, 0.75], [0, 1.2], [1, 0.08], [0, 0.1], [1, 0.08], [0, 1.6]]   # Multitap's autopilot: [down?, seconds]
const DZ_NAMES := ["raw", "hard dz", "radial"]
const DZ_COLS := [Kit.HOT, Kit.TARGET, Kit.GOOD]
const COMPASS := ["N", "E", "S", "W"]
const NORM_P := [[-2, -1], [-1, -2], [1, -2], [2, -1], [2, 1], [1, 2], [-1, 2], [-2, 1]]   # Normalize's course, in units of s

## A number for a label: "4" for whole values, "0.5" otherwise (JS's "" + k).
static func _num(v: float) -> String:
	return ("%d" % roundi(v)) if v == roundf(v) else ("%s" % v)

## The web label's "right" alignment: measure, then draw ending at p.x.
static func _label_right(n: CanvasItem, b: Dictionary, txt: String, p: Vector2, col: Color) -> void:
	var f := ThemeDB.fallback_font
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	Kit.label(n, b, txt, Vector2(p.x - w, p.y), col)

## ctx.restore: back to the card's own transform.
static func _pop(n: CanvasItem, b: Dictionary) -> void:
	n.draw_set_transform((b.rect as Rect2).position, 0.0, Vector2.ONE)

## The web kit's ease(k): smoothstep, clamped.
static func _ease(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)

## A pie wedge (ctx.moveTo centre, arc a0..a1, closePath): filled, and
## outlined when stroke_w > 0.
static func _wedge(n: CanvasItem, c: Vector2, r: float, a0: float, a1: float, fill: Color, stroke_col: Color = Color(), stroke_w: float = 0.0) -> void:
	var pts := PackedVector2Array()
	pts.append(c)
	for i in 11:
		var an: float = a0 + (a1 - a0) * i / 10.0
		pts.append(c + Vector2(cos(an), sin(an)) * r)
	n.draw_colored_polygon(pts, fill)
	if stroke_w > 0.0:
		pts.append(c)
		n.draw_polyline(pts, stroke_col, stroke_w)

## The kit's mote, squashed: ctx.translate(x, y); ctx.scale(1/s, s); mote(0, 0, ang).
static func _mote_squash(n: CanvasItem, b: Dictionary, p: Vector2, ang: float, col: Color, sc: float) -> void:
	var origin: Vector2 = (b.rect as Rect2).position
	var xf := Transform2D(0.0, origin + p).scaled_local(Vector2(1.0 / sc, sc)) * Transform2D(ang, Vector2.ZERO)
	n.draw_set_transform_matrix(xf)
	n.draw_circle(Vector2.ZERO, R, col)
	n.draw_colored_polygon(PackedVector2Array([Vector2(R * 0.45, -R * 0.6), Vector2(R * 1.5, 0), Vector2(R * 0.45, R * 0.6)]), col)
	n.draw_circle(Vector2(R * 0.38, -R * 0.3), R * 0.22, Kit.NIGHT)
	_pop(n, b)

## Quartercircle's arrow glyph for a 45° sector.
static func _glyph(n: CanvasItem, p: Vector2, sec: int, col: Color) -> void:
	var d := Vector2(cos(sec * TAU / 8.0), sin(sec * TAU / 8.0)) * 6.0
	Kit.arrow(n, p - d, p + d, col)

## Multitap's timeline: a time → an x, now at the right edge.
static func _mt_x(W: float, span: float, t: float, tt: float) -> float:
	return W - (t - tt) / span * W

## Coyote: a jump request — honoured while grace > 0, refused after.
static func _coyote_try(b: Dictionary, tt: float) -> void:
	var D: Dictionary = b.D
	var H: float = b.h
	var G: float = H * D.g
	var coyote: float = D.coyote
	var grace: float = (coyote - (tt - b.tLeft)) if b.air else coyote
	if not b.jumped and grace > 0.0:
		b.vy = -sqrt(2.0 * G * H * D.jumpH)
		b.jumped = true
		b.air = true
		b.ok = true
		b.honoured += 1
	else:
		b.ok = false
		b.refused += 1
	b.flash = 0.6
	b.fx = b.x
	b.fy = b.y

## Normalize: the stick → (−1|0|1, −1|0|1).
static func _norm_snap_dir(b: Dictionary, d: Vector2) -> Vector2:
	var D: Dictionary = b.D
	var nn: float = 4.0 if D.fourWay else 8.0
	var a: float = roundf(atan2(d.y, d.x) / TAU * nn) / nn * TAU
	return Vector2(roundf(cos(a)), roundf(sin(a)))

## Normalize: one mote's step — add the axes, or normalise them.
static func _norm_step(b: Dictionary, m: Dictionary, norm: bool, dt: float, t: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var P: Array[Vector2] = b.P
	var wi: int = m.w
	var goal: Vector2 = P[wi]
	var pos := Vector2(m.x, m.y)
	var inp: Vector2
	if b.overT > 0.0:
		inp = Vector2(b.ox, b.oy)
	else:
		inp = _norm_snap_dir(b, goal - pos)
	var L: float = inp.length()
	if L == 0.0:
		L = 1.0
	var k: float = (1.0 / L) if norm else 1.0    # ← the whole card: divide by the length, or don't
	var speed: float = D.speed
	m.vx = inp.x * k * W * speed
	m.vy = inp.y * k * W * speed
	var d: float = goal.distance_to(pos)
	var stepLen: float = Vector2(m.vx, m.vy).length() * dt
	var reach: float = D.reach
	if b.overT <= 0.0 and d <= maxf(reach, stepLen):
		m.x = goal.x
		m.y = goal.y
		m.w = (wi + 1) % P.size()
		if m.w == 1:
			if m.laps > 0:
				m.last = t - m.lap
			m.lap = t
			m.laps += 1
	else:
		m.x = clampf(m.x + m.vx * dt, 8.0, W - 8.0)
		m.y = clampf(m.y + m.vy * dt, 8.0, H - 8.0)

## Accelerate: a jump, if the feet are down.
static func _accel_jump(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var H: float = b.h
	if not b.air:
		b.vy = -sqrt(2.0 * H * D.g * H * D.jumpH)
		b.air = true

## Charge: the button let go — a launch ∝ power, or a backfire past max.
static func _charge_release(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var G: float = H * D.g
	var cmax: float = D["max"]
	var fill: float = D.fill
	if b.c >= cmax:
		b.phase = "stumble"
		b.stumble = 0.8
		b.msg = "overcharge — backfire"
		b.flash = 0.8
		b.c = 0.0
		return
	var power: float = minf(b.c / fill, 1.0)
	var sweet: Array = D.sweet
	var isSweet: bool = power >= float(sweet[0]) and power <= float(sweet[1])
	var lift: float = D.lift
	var T: float = 2.0 * H * lift / G                # Jump's flight time, up and down
	var bonus: float = D.bonus
	var rng_: float = D["range"]
	b.dist = power * rng_ * W * (bonus if isSweet else 1.0)
	b.vx = b.dist / T
	b.vy = -H * lift
	b.phase = "fly"
	b.msg = ("sweet spot ×" + _num(bonus)) if isSweet else ("power %d%%" % roundi(power * 100.0))
	b.flash = 0.8
	b.wraps = 0
	(b.trail as Array).clear()
	b.c = 0.0

## Fling: one pointer sample into the history; the mote is glued to it.
static func _fling_sample(b: Dictionary, px: float, py: float, tt: float) -> void:
	var W: float = b.w
	var GY: float = b.gy
	var hx: Array[float] = b.hx
	var hy: Array[float] = b.hy
	var ht: Array[float] = b.ht
	if not b.dragging:
		b.dragging = true
		b.count = 0
		b.head = 0
		b.vx = 0.0
		b.vy = 0.0
	var head: int = b.head
	hx[head] = px
	hy[head] = py
	ht[head] = tt
	b.head = (head + 1) % FLING_CAP
	if b.count < FLING_CAP:
		b.count += 1
	b.x = clampf(px, R, W - R)
	b.y = clampf(py, R, GY - R)

## Fling: the release — velocity across the last n samples, capped.
static func _fling_let_go(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var hx: Array[float] = b.hx
	var hy: Array[float] = b.hy
	var ht: Array[float] = b.ht
	b.dragging = false
	var nmax: int = D.n
	var nn: int = mini(nmax, b.count)
	var head: int = b.head
	if nn >= 2:
		var iN: int = posmod(head - 1, FLING_CAP)
		var i1: int = posmod(head - nn, FLING_CAP)
		var span: float = ht[iN] - ht[i1]
		if span > 1e-3:
			b.vx = (hx[iN] - hx[i1]) / span
			b.vy = (hy[iN] - hy[i1]) / span
	var sp: float = Vector2(b.vx, b.vy).length()
	var maxV: float = D.maxV
	var cap: float = W * maxV
	if sp > cap:
		b.vx *= cap / sp
		b.vy *= cap / sp
	b.rx = b.x
	b.ry = b.y
	b.rvx = b.vx
	b.rvy = b.vy
	b.arrT = 0.7

## Swipe: the finger lands / moves / lifts.
static func _swipe_begin(b: Dictionary, px: float, py: float, tt: float) -> void:
	b.stroke = true
	b.sx0 = px
	b.cx = px
	b.sy0 = py
	b.cy = py
	b.st0 = tt

static func _swipe_move(b: Dictionary, px: float, py: float) -> void:
	b.cx = px
	b.cy = py

static func _swipe_end(b: Dictionary, tEnd: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	b.stroke = false
	var dx: float = b.cx - b.sx0
	var dy: float = b.cy - b.sy0
	var d: float = Vector2(dx, dy).length()
	var el: float = tEnd - b.st0
	var minDist: float = D.minDist
	var maxTime: float = D.maxTime
	if d < W * minDist:
		b.bad = "too short: %d < %d" % [roundi(d), roundi(W * minDist)]
		b.badT = 0.7
		return
	if el > maxTime:
		b.bad = "too slow: %.2f s > %s" % [el, _num(maxTime)]
		b.badT = 0.7
		return
	var dirs: int = D.dirs
	var w: float = TAU / dirs
	var k: int = posmod(roundi(atan2(dy, dx) / w), dirs)
	b.lit = k
	b.litT = 0.7
	var a: float = k * w
	var ux: int = roundi(cos(a))
	var uy: int = roundi(sin(a))
	if b.hopT < 1.0:                                 # mid-hop: the hop lands first
		b.ci = b.ti
		b.ri = b.tr
	b.fi = b.ci
	b.fr = b.ri
	var cols: int = b.cols
	var rows: int = b.rows
	var ci: int = b.ci
	var ri: int = b.ri
	if D.slide:
		if ux != 0 or uy != 0:
			while ci + ux >= 0 and ci + ux < cols and ri + uy >= 0 and ri + uy < rows:
				ci += ux
				ri += uy
	else:
		ci = clampi(ci + ux, 0, cols - 1)
		ri = clampi(ri + uy, 0, rows - 1)
	b.ci = ci
	b.ri = ri
	b.ti = ci
	b.tr = ri
	b.hopT = 0.0
	b.hopLen = 0.12 + 0.06 * maxi(absi(ci - b.fi), absi(ri - b.fr))

## Quartercircle: the pointer's sector around the mote, into the ring buffer on change.
static func _qc_push(b: Dictionary, px: float, py: float, tt: float) -> void:
	var D: Dictionary = b.D
	var buf: int = D.buf
	var bd: Array[int] = b.bd
	var bt: Array[float] = b.bt
	var a: float = atan2(py - b.my, px - b.mx)
	var sec: int = posmod(roundi(a / (TAU / 8.0)), 8)
	if not b.tracing:
		b.tracing = true
		b.lastSec = -1
	if sec != b.lastSec:
		var head: int = b.head
		bd[head] = sec
		bt[head] = tt
		b.head = (head + 1) % buf
		if b.count < buf:
			b.count += 1
		b.lastSec = sec
	var trail: Array = b.trail
	trail.append(Vector2(px, py))
	if trail.size() > 24:
		trail.pop_front()

## Quartercircle: the punch — scan the buffer newest → oldest for the
## pattern end → start, inside the window.
static func _qc_punch(b: Dictionary, tt: float) -> void:
	var D: Dictionary = b.D
	var buf: int = D.buf
	var bd: Array[int] = b.bd
	var bt: Array[float] = b.bt
	var lit: Array[int] = b.lit
	var P: Array = D.pattern
	var window: float = D.window
	b.tracing = false
	var pi: int = P.size() - 1
	var tLast := -1.0
	var tFirst := -1.0
	for i in buf:
		lit[i] = 0
	var count: int = b.count
	var head: int = b.head
	for i in count:                                  # newest → oldest, pattern end → start
		if pi < 0:
			break
		var j: int = posmod(head - 1 - i, buf)
		if bd[j] == int(P[pi]):
			lit[j] = 1
			if tLast < 0.0:
				tLast = bt[j]
			tFirst = bt[j]
			pi -= 1
	b.litOk = pi < 0 and tLast - tFirst <= window and tt - tLast <= window
	b.litT = 0.9
	var shot: Dictionary = b.shot
	if b.litOk:
		b.hits += 1
		shot.on = true
		shot.x = b.mx
		shot.y = b.my
		shot.dir = -1.0 if cos(int(P[P.size() - 1]) * TAU / 8.0) < -0.1 else 1.0
	else:
		b.jabs += 1
		b.jabT = 0.3
	b.count = 0
	b.head = 0

## Virtualstick: the finger lands — that point is the origin.
static func _vs_land(b: Dictionary, px: float, py: float) -> void:
	b.ox = px
	b.tx = px
	b.oy = py
	b.ty = py
	b.on = true

## Virtualstick: the thumb moves — clamped to the ring, or towing it.
static func _vs_thumb(b: Dictionary, px: float, py: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var radius: float = D.radius
	var r: float = W * radius
	b.tx = px
	b.ty = py
	b.rawx = px
	b.rawy = py
	var dx: float = b.tx - b.ox
	var dy: float = b.ty - b.oy
	var L: float = Vector2(dx, dy).length()
	if L > r:
		if D.floating:                               # the ring is towed along
			b.ox += dx / L * (L - r)
			b.oy += dy / L * (L - r)
		else:                                        # the thumb is clamped
			b.tx = b.ox + dx / L * r
			b.ty = b.oy + dy / L * r

static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"coyote":
			# the mote runs off the ledge on its own. the frame the feet lose the
			# ground, a GRACE TIMER (coyote time — the cartoon coyote who does not fall
			# until he looks down) starts counting. a jump pressed while grace > 0 is
			# honoured exactly as if the ground were still there — Jump's v₀ = √(2gh)
			# — and a jump pressed later is refused. the amber band past the edge is
			# the same window measured in distance: speed × coyote. Ninja's buffer is
			# the mirror trick: this forgives a LATE press, that one an EARLY one.
			b.x = -R
			b.y = GY - R
			b.vy = 0.0
			b.air = false
			b.tLeft = 0.0
			b.jumped = false
			b.k = 0
			b.autoDone = false
			b.flash = 0.0
			b.fx = 0.0
			b.fy = 0.0
			b.ok = false
			b.honoured = 0
			b.refused = 0
			b.trail = [] as Array[Vector2]
		"jumpbuffer":
			# the JUMP BUFFER: a press that arrives a little before it is legal is
			# not thrown away, it is stored with its time; on touchdown the code asks
			# "was there a press in the last buffer seconds?" and fires it. the
			# amber pip beside the mote is the stored press with its own shrinking
			# life; when the life runs out before the floor arrives, the press
			# expires (grey) and the landing is just a landing. the amber band above
			# the floor is the buffer measured in distance: |vy| × buffer, so it
			# grows as the fall speeds up. Coyote forgives a late press; this, an early one.
			var drop: float = D.drop
			b.y = GY - R - H * drop
			b.vy = 0.0
			b.phase = "fall"
			b.timer = 0.0
			b.tPress = -9.0
			b.k = 0
			b.autoDone = false
			b.fired = 0
			b.expired = 0
			b.flash = 0.0
			b.fy = 0.0
			b.wasOk = false
		"variable":
			# one launch speed, many heights: the jump starts at full v₀ (Jump's
			# parabola) and while the button is HELD nothing interferes; the moment
			# it is released, the upward velocity is CUT (vy × cut) and gravity may
			# grow (× fallG), so the apex arrives early. the three ghosts hold for
			# 0.05, 0.15 and 0.35 s and draw their apex lines — the same button, three
			# heights. the blue mote is yours: keep pressing to keep rising.
			var N: int = (D.holds as Array).size()
			var gy: Array[float] = []
			var gv: Array[float] = []
			var apex: Array[float] = []
			var cut: Array[bool] = []
			for _i in N:
				gy.append(GY - R)
				gv.append(0.0)
				apex.append(GY - R)
				cut.append(true)
			b.gys = gy
			b.gv = gv
			b.apex = apex
			b.cut = cut
			b.cycle = -0.6
			b.ly = GY - R
			b.lv = 0.0
			b.held = false
			b.t0 = 0.0
			b.lapex = GY - R
			b.lastPress = -9.0
			b.autoT = 0.0
			b.autoHold = 0.2
			b.manualJump = false
			b.holdT = 0.0
		"deadzone":
			# a real stick never rests at zero — it jitters (Jitter's white noise on
			# top of a slow roam). RAW drives the mote with the wobble. a HARD dead
			# zone kills anything shorter than dz, but at the edge the output jumps
			# straight from 0 to dz: a visible step in the bar. RADIAL RESCALING maps
			# dz..1 back onto 0..1 — (len − dz)/(1 − dz) along the same direction — so
			# the first felt push is the smallest, and an optional SNAP to 4 or 8
			# directions turns the stick into a d-pad. each mote is driven by its own
			# treatment: watch which one can stand still.
			var m: Array[Vector2] = []
			var out: Array[Vector2] = []
			for i in 3:
				m.append(Vector2(W * (0.5 / 3.0 + i / 3.0), H * 0.72))
				out.append(Vector2.ZERO)
			b.m = m
			b.out = out
			b.sx = 0.0
			b.sy = 0.0
			b.L = 0.0
			b.lastPress = -9.0
			b.px = 0.0
			b.py = 0.0
		"normalize":
			# an 8-way input is two axes of −1, 0 or +1. add them and the diagonal
			# (1, 1) has length √2: the character runs 41% faster toward the corners —
			# the oldest top-down bug there is. NORMALISING divides the vector by its
			# own length, so every direction moves at the same speed. the course
			# alternates straight legs and diagonal legs; the purple mote adds, the
			# blue one normalises, and the lap clocks tell you who cheated. (Grid's
			# lanes never had this problem: four directions, no diagonals.)
			var sc: float = minf(W * 0.14, H * 0.17)
			b.cx = W / 2.0
			b.cy = H * 0.5
			var P: Array[Vector2] = []
			for q in NORM_P:
				P.append(Vector2(b.cx + float(q[0]) * sc, b.cy + float(q[1]) * sc))
			b.P = P
			b.A = { "x": P[0].x, "y": P[0].y, "w": 1, "lap": 0.0, "last": 0.0, "vx": 0.0, "vy": 0.0, "laps": 0 }   # adds
			b.B = { "x": P[0].x, "y": P[0].y, "w": 1, "lap": 0.0, "last": 0.0, "vx": 0.0, "vy": 0.0, "laps": 0 }   # normalises
			b.ox = 0.0
			b.oy = 0.0
			b.overT = 0.0
		"accelerate":
			# a velocity approaching a WANTED velocity at a fixed rate (move_toward),
			# but the rate has three names. ACCEL when speeding up in the direction
			# of travel, BRAKE when slowing or turning round — brake is usually the
			# bigger, so stopping feels crisp and starting feels weighty (Inertia's
			# skid, made into a dial) — and AIRACCEL, small, so a jump commits. the
			# strip is v against time: its slope IS the rate in use, and the purple
			# stretches are the air, where the slope goes nearly flat.
			var hist: Array[float] = []
			var airH: Array[int] = []
			for _i in ACCEL_N:
				hist.append(0.0)
				airH.append(0)
			b.hist = hist
			b.airH = airH
			b.x = W * 0.3
			b.y = GY - R
			b.v = 0.0
			b.vy = 0.0
			b.want = 1.0
			b.air = false
			b.flipT = 0.0
			b.jumpT = 1.2
			b.hi = 0
			b.rate = "accel"
		"multitap":
			# the button only knows DOWN and UP; the meaning is in the durations. a
			# press that ends before tapMax is a TAP; one still down after holdMin is
			# a HOLD (the charge grows while it lasts); a tap that follows another tap
			# inside dblGap is a DOUBLE-TAP, spent as Dash's burst. the timeline at
			# the bottom draws every press as a bar with its windows as bands: green
			# = tap window, amber = hold begins, purple = the double-tap gap still
			# open. the autopilot demonstrates all three; you can too.
			b.events = []                                # { d: downAt, u: upAt | -1, kind }
			b.x = W * 0.35
			b.y = GY - R
			b.vx = 0.0
			b.vy = 0.0
			b.face = 1.0
			b.wasDown = false
			b.down = false
			b.downAt = 0.0
			b.dur = 0.0
			b.lastTapUp = -9.0
			b.lastPress = -9.0
			b.si = 0
			b.sT = 0.0
			b.verb = ""
			b.verbT = 0.0
			b.charge = 0.0
		"charge":
			# a CHARGE is a held button turned into a number: power = held / fill,
			# capped at 1. the bar beside the mote is that number; the green band is
			# a SWEET SPOT that pays a bonus for letting go at the right moment; and
			# past max the charge OVERCHARGES — it backfires and the mote stumbles
			# instead of flying. the launch is Jump's parabola with the horizontal
			# speed chosen so the distance is exactly power × range. the autopilot
			# charges to a random level, sometimes too far.
			b.x0 = W * 0.14
			b.x = b.x0
			b.y = GY - R
			b.vx = 0.0
			b.vy = 0.0
			b.phase = "idle"
			b.c = 0.0
			b.manual = false
			b.autoTarget = 0.8
			b.idleT = 0.6
			b.lastPress = -9.0
			b.landX = -1.0
			b.dist = 0.0
			b.wraps = 0
			b.flash = 0.0
			b.msg = ""
			b.stumble = 0.0
			b.trail = [] as Array[Vector2]
		"fling":
			# while dragged the mote is simply glued to the pointer, but every sample
			# (x, y, t) goes into a small HISTORY BUFFER (Queue's idea, kept for the
			# finger). at release the velocity is the displacement across the last n
			# samples divided by their time span — an average, so one jittery frame
			# cannot spoil a throw. then it is Bounce: gravity, restitution, a little
			# air drag. the grey dots are the buffer; the red arrow is the velocity it
			# read. the purple ring is the ghost finger practising when you are idle.
			var hx: Array[float] = []
			var hy: Array[float] = []
			var ht: Array[float] = []
			for _i in FLING_CAP:
				hx.append(0.0)
				hy.append(0.0)
				ht.append(0.0)
			b.hx = hx
			b.hy = hy
			b.ht = ht
			b.count = 0
			b.head = 0
			b.x = W * 0.5
			b.y = GY - R
			b.vx = 0.0
			b.vy = 0.0
			b.dragging = false
			b.lastPress = -9.0
			b.idle = 0.0
			b.auto = -1.0
			b.ax0 = 0.0
			b.ay0 = 0.0
			b.adx = 0.0
			b.ady = 0.0
			b.arrT = 0.0
			b.rx = 0.0
			b.ry = 0.0
			b.rvx = 0.0
			b.rvy = 0.0
		"swipe":
			# a SWIPE is a delta with two gates. from the first touch to the lift the
			# stroke's displacement Δ must be long enough (minDist — the grey ring
			# around the start) and quick enough (maxTime); only then is its angle
			# BUCKETED into one of dirs wedges — atan2 divided by the wedge width,
			# rounded. the rose lights the wedge it heard; the mote hops one tile
			# that way (or slides to the wall). the purple ring is a ghost finger
			# drawing swipes when you are idle — some too short, some too slow.
			var tile: float = D.tile
			b.r = minf(W, H) * 0.16
			b.rx = W * 0.2
			b.ry = H * 0.44
			b.ts = W * tile
			b.cols = maxi(2, int(floorf(W * 0.56 / b.ts)))
			b.rows = maxi(2, int(floorf(H * 0.62 / b.ts)))
			b.gx0 = W * 0.4
			b.gy0 = H * 0.1
			b.sx0 = 0.0
			b.sy0 = 0.0
			b.st0 = 0.0
			b.cx = 0.0
			b.cy = 0.0
			b.stroke = false
			b.lastPress = -9.0
			b.idle = 0.0
			b.lit = -1
			b.litT = 0.0
			b.bad = ""
			b.badT = 0.0
			b.ci = 1
			b.ri = 1
			b.fi = 1
			b.fr = 1
			b.ti = 1
			b.tr = 1
			b.hopT = 1.0
			b.hopLen = 0.18
			b.auto = -1.0
			b.aDir = 0
			b.aLen = 0.0
			b.aDur = 0.0
			b.ax = 0.0
			b.ay = 0.0
		"quartercircle":
			# fighting games read a MOTION INPUT as a small parser. every frame the
			# stick's direction is a sector of 45°; each time it changes, it goes
			# into a RING BUFFER with its time. on the punch the parser scans the
			# buffer from the newest backward for the pattern's last, then middle,
			# then first symbol — in order, and with the first and last no further
			# apart than the window. a match fires the projectile; anything else is
			# just a jab. the top row is the pattern, the row under it the buffer
			# (entries older than the window fade); matched arrows light green.
			var buf: int = D.buf
			b.mx = W * 0.35
			b.my = GY - QC_R
			var bd: Array[int] = []
			var bt: Array[float] = []
			var lit: Array[int] = []
			for _i in buf:
				bd.append(0)
				bt.append(0.0)
				lit.append(0)
			b.bd = bd
			b.bt = bt
			b.lit = lit
			b.count = 0
			b.head = 0
			b.lastSec = -1
			b.tracing = false
			b.lastPress = -9.0
			b.idle = 0.0
			b.auto = -1.0
			b.aDur = 0.4
			b.litT = 0.0
			b.litOk = false
			b.hits = 0
			b.jabs = 0
			b.jabT = 0.0
			b.shot = { "on": false, "x": 0.0, "y": 0.0, "dir": 1.0 }
			b.trail = [] as Array[Vector2]
		"virtualstick":
			# a touch screen has no stick, so the code invents one where the finger
			# first lands: that point is the ORIGIN, the finger is the THUMB, and the
			# stick vector is thumb − origin, CLAMPED to a radius and divided by it —
			# a −1..1 stick from two points. the mote's velocity steers toward that
			# vector times a top speed (Arrive's manners: it eases, it never snaps).
			# a FLOATING stick lets the origin be dragged along when the thumb leaves
			# the ring, so the hand never has to come back to a spot it cannot see.
			b.ox = 0.0
			b.oy = 0.0
			b.tx = 0.0
			b.ty = 0.0
			b.on = false
			b.ghost = false
			b.lastPress = -9.0
			b.idle = 0.0
			b.auto = -1.0
			b.x = W * 0.5
			b.y = H * 0.5
			b.vx = 0.0
			b.vy = 0.0
			b.rawx = 0.0
			b.rawy = 0.0
			b.sx = 0.0
			b.sy = 0.0
		"mouselook":
			# a mouse reports no position that matters, only MOVEMENT. each pointer
			# delta becomes a turn: yaw from Δx, pitch from Δy, through a sensitivity
			# and a CURVE — |Δ|^accel keeps small moves precise and lets big flicks
			# travel. pitch is CLAMPED so you can never look past straight up. the
			# scene is the cheapest first person there is: a horizon that slides with
			# pitch, and posts placed at world angles, drawn at (angle − yaw) / fov
			# across the screen — Camera's follow, turned into a window you steer.
			var seed := Kit.rng(3)
			var posts: Array = []
			for i in 12:
				posts.append({ "a": i / 12.0 * TAU, "h": 0.12 + seed.randf() * 0.22, "w": 3.0 + seed.randf() * 5.0 })
			b.posts = posts
			b.yaw = 0.0
			b.pitch = 0.0
			b.yawS = 0.0
			b.pitchS = 0.0
			b.lx = 0.0
			b.ly = 0.0
			b.lastPress = -9.0
			b.ddx = 0.0
			b.ddy = 0.0
			b.dT = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	var H: float = b.h
	var GY: float = b.gy
	var tt: float = b.t                                  # the web's lastT: the time of the latest frame
	match b.id:
		"coyote":
			b.autoDone = true
			_coyote_try(b, tt)
		"jumpbuffer":
			if b.phase == "fall":
				b.tPress = tt
				b.autoDone = true
		"variable":
			b.lastPress = tt
			b.autoT = -3.0
			if b.ly >= GY - R - 0.01 and b.lv == 0.0:
				var v0: float = D.v0
				b.lv = -H * v0
				b.held = true
				b.t0 = tt
				b.lapex = b.ly
				b.manualJump = true
		"deadzone":
			b.px = pos.x
			b.py = pos.y
			b.lastPress = tt
		"normalize":
			var dir := _norm_snap_dir(b, pos - Vector2(b.cx, b.cy))
			b.ox = dir.x
			b.oy = dir.y
			b.overT = D.override
		"accelerate":
			b.flipT = -2.0
			b.want = -1.0 if pos.x < b.x else 1.0
			if pos.y < b.y - 16.0:
				_accel_jump(b)
		"multitap":
			b.lastPress = tt
		"charge":
			b.lastPress = tt
			if b.phase == "idle" or b.phase == "landed":
				b.phase = "charge"
				b.c = 0.0
				b.manual = true
		"fling":
			if b.auto >= 0.0:
				b.auto = -1.0
			_fling_sample(b, pos.x, pos.y, tt)
			b.lastPress = tt
			b.idle = 0.0
		"swipe":
			b.auto = -1.0
			b.idle = 0.0
			var release: float = D.release
			if not b.stroke or tt - b.lastPress > release:
				_swipe_begin(b, pos.x, pos.y, tt)
			else:
				_swipe_move(b, pos.x, pos.y)
			b.lastPress = tt
		"quartercircle":
			if b.auto >= 0.0:
				b.auto = -1.0
			_qc_push(b, pos.x, pos.y, tt)
			b.lastPress = tt
			b.idle = 0.0
		"virtualstick":
			if b.auto >= 0.0:
				b.auto = -1.0
				b.on = false
			b.ghost = false
			b.idle = 0.0
			var gap: float = D.gap
			if not b.on or tt - b.lastPress > gap:
				_vs_land(b, pos.x, pos.y)
			else:
				_vs_thumb(b, pos.x, pos.y)
			b.lastPress = tt
		"mouselook":
			var gap: float = D.gap
			if tt - b.lastPress <= gap:                  # a delta only inside one grab
				var dx: float = pos.x - b.lx
				var dy: float = pos.y - b.ly
				b.ddx = dx
				b.ddy = dy
				b.dT = 0.3
				var accel: float = D.accel
				var sens: float = D.sens
				var pitchMax: float = D.pitchMax
				b.yaw += signf(dx) * pow(absf(dx), accel) * sens
				b.pitch -= signf(dy) * pow(absf(dy), accel) * sens
				b.pitch = clampf(b.pitch, -pitchMax * TAU / 360.0, pitchMax * TAU / 360.0)
			b.lx = pos.x
			b.ly = pos.y
			b.lastPress = tt

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"coyote":
			var g: float = D.g
			var G: float = H * g
			var ledge: float = D.ledge
			var farD: float = D.far
			var speed: float = D.speed
			var edge: float = W * ledge
			var far: float = W * farD
			b.x += W * speed * dt
			if not b.air and b.x >= edge and b.x <= far:   # the feet leave
				b.air = true
				b.tLeft = t
				b.jumped = false
				b.autoDone = false
			if b.air:
				b.vy += G * dt
				b.y += b.vy * dt
				if b.y >= GY - R and b.vy >= 0.0 and (b.x < edge or b.x > far):
					b.y = GY - R
					b.vy = 0.0
					b.air = false
					b.jumped = false
				var autoAt: Array = D.autoAt
				var at: float = autoAt[(b.k as int) % autoAt.size()]
				if not b.autoDone and not b.jumped and t - b.tLeft >= at:
					b.autoDone = true
					b.k += 1
					_coyote_try(b, t)
			else:
				b.y = GY - R
			var trail: Array[Vector2] = b.trail
			if b.x > W + R * 2.0 or b.y > H + 20.0:
				b.x = -R
				b.y = GY - R
				b.vy = 0.0
				b.air = false
				b.jumped = false
				trail.clear()
			trail.append(Vector2(b.x, b.y))
			if trail.size() > 36:
				trail.pop_front()
			b.flash = maxf(0.0, b.flash - dt)
		"jumpbuffer":
			var g: float = D.g
			var G: float = H * g
			var jumpH: float = D.jumpH
			var buffer: float = D.buffer
			var v0: float = sqrt(2.0 * G * H * jumpH)
			b.timer += dt
			if b.phase == "fall":
				b.vy += G * dt
				b.y += b.vy * dt
				var hh: float = GY - R - b.y
				var disc: float = b.vy * b.vy + 2.0 * G * maxf(0.0, hh)
				var tLand: float = (sqrt(disc) - b.vy) / G   # time until the feet touch
				var autoLead: Array = D.autoLead
				var lead: float = autoLead[(b.k as int) % autoLead.size()]
				if not b.autoDone and tLand <= lead:
					b.autoDone = true
					b.k += 1
					b.tPress = t
				if b.y >= GY - R:
					b.y = GY - R
					if t - b.tPress <= buffer:
						b.vy = -v0
						b.phase = "jump"
						b.fired += 1
						b.wasOk = true
						b.flash = 0.6
					else:
						b.vy = 0.0
						b.phase = "stand"
						b.timer = 0.0
						b.wasOk = false
						b.flash = 0.6
					b.fy = b.y
					b.tPress = -9.0
			elif b.phase == "jump":
				b.vy += G * dt
				b.y += b.vy * dt
				if b.y >= GY - R:
					b.y = GY - R
					b.vy = 0.0
					b.phase = "stand"
					b.timer = 0.0
			else:
				var rest: float = D.rest
				if b.timer > rest:
					var drop: float = D.drop
					b.phase = "fall"
					b.y = GY - R - H * drop
					b.vy = 0.0
					b.autoDone = false
			# the stored press that waited too long (the web counts it while drawing)
			var life: float = buffer - (t - b.tPress)
			if b.phase == "fall" and life <= 0.0 and b.tPress > 0.0 and t - b.tPress > buffer + 0.01:
				b.expired += 1
				b.tPress = -9.0
			b.flash = maxf(0.0, b.flash - dt)
		"variable":
			var g: float = D.g
			var G: float = H * g
			var v0: float = D.v0
			var cutD: float = D.cut
			var fallG: float = D.fallG
			var holdMax: float = D.holdMax
			var every: float = D.every
			var gap: float = D.gap
			var holds: Array = D.holds
			var N: int = holds.size()
			var gy: Array[float] = b.gys
			var gv: Array[float] = b.gv
			var apex: Array[float] = b.apex
			var cut: Array[bool] = b.cut
			b.cycle += dt
			if b.cycle > every:
				b.cycle = 0.0
				for i in N:
					gv[i] = -H * v0
					apex[i] = GY - R
					cut[i] = false
			for i in N:                                  # the ghosts: hold for holds[i], then cut once
				if gy[i] < GY - R or gv[i] < 0.0:
					var hold_i: float = holds[i]
					var holding: bool = b.cycle < minf(hold_i, holdMax)
					if not holding and not cut[i]:       # the cut, exactly once
						if gv[i] < 0.0:
							gv[i] *= cutD
						cut[i] = true
					gv[i] += G * (1.0 if holding else fallG) * dt
					gy[i] += gv[i] * dt
					if gy[i] > GY - R:
						gy[i] = GY - R
						gv[i] = 0.0
					if gy[i] < apex[i]:
						apex[i] = gy[i]
			# the live mote: yours while you press, the autopilot's otherwise
			b.autoT += dt
			if b.autoT > 2.6 and b.ly >= GY - R - 0.01 and b.lv == 0.0:
				b.autoT = 0.0
				b.autoHold = randf_range(0.03, holdMax)
				b.lv = -H * v0
				b.held = true
				b.t0 = t
				b.lapex = b.ly
				b.manualJump = false
			var holdT: float = t - b.t0
			b.holdT = holdT
			var stillHeld: bool = (t - b.lastPress <= gap) if b.manualJump else (holdT < b.autoHold)
			if b.held and (not stillHeld or holdT > holdMax):
				if b.lv < 0.0:
					b.lv *= cutD
				b.held = false
			if b.ly < GY - R or b.lv < 0.0:
				b.lv += G * (1.0 if b.held else fallG) * dt
				b.ly += b.lv * dt
				if b.ly > GY - R:
					b.ly = GY - R
					b.lv = 0.0
				if b.ly < b.lapex:
					b.lapex = b.ly
		"deadzone":
			var dz: float = D.dz
			var jitter: float = D.jitter
			var wander: float = D.wander
			var snap: int = D.snap
			var speed: float = D.speed
			var hold: float = D.hold
			var r: float = minf(W, H) * 0.11
			var cy: float = H * 0.3
			var sx: float
			var sy: float
			if t - b.lastPress <= hold:
				sx = clampf((b.px - W / 2.0) / (W * 0.3), -1.0, 1.0)
				sy = clampf((b.py - cy) / (W * 0.3), -1.0, 1.0)
			else:
				sx = Kit.noise(t * wander) * 0.9
				sy = Kit.noise(t * wander + 50.0) * 0.9
			sx += randf_range(-1.0, 1.0) * jitter         # the wobble every stick has
			sy += randf_range(-1.0, 1.0) * jitter
			var L: float = Vector2(sx, sy).length()
			if L > 1.0:
				sx /= L
				sy /= L
				L = 1.0
			var out: Array[Vector2] = b.out
			out[0] = Vector2(sx, sy)
			out[1] = Vector2.ZERO if L < dz else Vector2(sx, sy)
			if L < dz or L < 1e-6:
				out[2] = Vector2.ZERO
			else:
				var k: float = (L - dz) / maxf(1e-6, 1.0 - dz)
				var u := Vector2(sx, sy) / L
				if snap > 0:
					var a: float = roundf(atan2(u.y, u.x) / TAU * snap) / snap * TAU
					u = Vector2(cos(a), sin(a))
				out[2] = u * k
			var m: Array[Vector2] = b.m
			for i in 3:                                  # the mote driven by this treatment
				var x0: float = W * i / 3.0 + 12.0
				var x1: float = W * (i + 1) / 3.0 - 12.0
				var p: Vector2 = m[i] + out[i] * W * speed * dt
				m[i] = Vector2(clampf(p.x, x0, x1), clampf(p.y, H * 0.56, H * 0.88))
			b.sx = sx
			b.sy = sy
			b.L = L
		"normalize":
			b.overT -= dt
			_norm_step(b, b.A, false, dt, t)
			_norm_step(b, b.B, true, dt, t)
		"accelerate":
			var vmax: float = D["max"]
			var accel: float = D.accel
			var brake: float = D.brake
			var airAccel: float = D.airAccel
			var g: float = D.g
			var flipEvery: float = D.flipEvery
			b.flipT += dt
			b.jumpT -= dt
			if b.flipT > flipEvery:
				b.flipT = 0.0
				b.want = -b.want
			if b.jumpT < 0.0:
				b.jumpT = randf_range(1.4, 3.2)
				_accel_jump(b)
			var target: float = b.want * vmax * W
			var r: float
			if b.air:
				r = airAccel
				b.rate = "airAccel"
			elif b.v * target < 0.0 or absf(b.v) > absf(target):
				r = brake
				b.rate = "brake"
			else:
				r = accel
				b.rate = "accel"
			var stepv: float = r * W * dt                # move_toward(v, target, rate · dt)
			if absf(target - b.v) <= stepv:
				b.v = target
			else:
				b.v += signf(target - b.v) * stepv
			b.x += b.v * dt
			if b.x < -R:
				b.x += W + R * 2.0
			if b.x > W + R:
				b.x -= W + R * 2.0
			if b.air:
				b.vy += H * g * dt
				b.y += b.vy * dt
				if b.y >= GY - R:
					b.y = GY - R
					b.vy = 0.0
					b.air = false
			var hist: Array[float] = b.hist
			var airH: Array[int] = b.airH
			var hi: int = b.hi
			hist[hi] = b.v / (vmax * W)
			airH[hi] = 1 if b.air else 0
			b.hi = (hi + 1) % ACCEL_N
		"multitap":
			var tapMax: float = D.tapMax
			var holdMin: float = D.holdMin
			var dblGap: float = D.dblGap
			var hop: float = D.hop
			var chargeH: float = D.chargeH
			var chargeT: float = D.chargeT
			var dash: float = D.dash
			var kD: float = D.k
			var g: float = D.g
			var events: Array = b.events
			var manual: bool = t - b.lastPress <= 0.06
			if not manual and t - b.lastPress > 2.0:     # the autopilot's script
				b.sT += dt
				var seg: Array = MT_SCRIPT[b.si]
				if b.sT > float(seg[1]):
					b.sT = 0.0
					b.si = (b.si + 1) % MT_SCRIPT.size()
			var seg2: Array = MT_SCRIPT[b.si]
			var down: bool = manual or (t - b.lastPress > 2.0 and int(seg2[0]) == 1)
			if down and not b.wasDown:
				b.downAt = t
				events.append({ "d": t, "u": -1.0, "kind": "" })
				if events.size() > 10:
					events.pop_front()
			var dur: float = (t - b.downAt) if down else 0.0
			if down and dur >= holdMin:
				b.charge = clampf((dur - holdMin) / chargeT, 0.0, 1.0)
			if not down and b.wasDown:                   # the UP edge: classify by duration
				var held: float = t - b.downAt
				var ev: Dictionary = events.back() if events.size() > 0 else {}
				if not ev.is_empty():
					ev.u = t
				if held >= holdMin:
					b.vy = -sqrt(2.0 * H * g * H * (hop + b.charge * chargeH))
					b.verb = "hold → charge %d%%" % roundi(b.charge * 100.0)
					if not ev.is_empty():
						ev.kind = "hold"
				elif held < tapMax:
					if t - b.lastTapUp <= dblGap:
						b.vx = b.face * dash * W
						b.verb = "double-tap → dash"
						b.lastTapUp = -9.0
						if not ev.is_empty():
							ev.kind = "dbl"
					else:
						b.vy = minf(b.vy, -sqrt(2.0 * H * g * H * hop))
						b.verb = "tap → hop"
						b.lastTapUp = t
						if not ev.is_empty():
							ev.kind = "tap"
				else:
					b.verb = "neither (between the windows)"
					if not ev.is_empty():
						ev.kind = "none"
				b.verbT = 0.9
				b.charge = 0.0
			b.wasDown = down
			b.down = down
			b.dur = dur
			# the body: Dash's decay sideways, a parabola up
			b.vx *= exp(-kD * dt)
			b.x += b.vx * dt
			if b.x < -R:
				b.x += W + R * 2.0
			if b.x > W + R:
				b.x -= W + R * 2.0
			if absf(b.vx) < 2.0 and absf(b.vx) > 0.0:
				b.vx = 0.0
				b.face = -b.face
			b.vy += H * g * dt
			b.y += b.vy * dt
			if b.y > GY - R:
				b.y = GY - R
				b.vy = 0.0
			b.verbT -= dt
		"charge":
			var g: float = D.g
			var G: float = H * g
			var cmax: float = D["max"]
			var gap: float = D.gap
			if b.phase == "idle":
				b.idleT -= dt
				if b.idleT < 0.0:
					b.phase = "charge"
					b.c = 0.0
					b.manual = false
					b.autoTarget = randf_range(0.25, cmax * 1.12)
			elif b.phase == "charge":
				b.c += dt                                # each held frame adds dt
				var letGo: bool = (t - b.lastPress > gap) if b.manual else (b.c >= b.autoTarget)
				if letGo:
					_charge_release(b)
				if b.c >= cmax + 0.02 and b.phase == "charge":
					_charge_release(b)
			elif b.phase == "fly":
				b.vy += G * dt
				b.x += b.vx * dt
				b.y += b.vy * dt
				if b.x > W + R:
					b.x -= W
					b.wraps += 1
				var trail: Array[Vector2] = b.trail
				trail.append(Vector2(b.x, b.y))
				if trail.size() > 40:
					trail.pop_front()
				if b.y >= GY - R:
					b.y = GY - R
					b.vy = 0.0
					b.vx = 0.0
					b.phase = "landed"
					b.landX = b.x
					b.idleT = 1.0
			elif b.phase == "landed":
				b.idleT -= dt
				if b.idleT < 0.0:
					b.phase = "idle"
					b.x = b.x0
					b.idleT = 0.5
			elif b.phase == "stumble":
				b.stumble -= dt
				b.x = b.x0 - sin((0.8 - b.stumble) * 8.0) * 6.0
				if b.stumble < 0.0:
					b.phase = "idle"
					b.x = b.x0
					b.idleT = 0.6
			b.flash = maxf(0.0, b.flash - dt)
		"fling":
			var g: float = D.g
			var e: float = D.e
			var dragD: float = D.drag
			var release: float = D.release
			var autoEvery: float = D.autoEvery
			b.idle += dt
			if b.auto >= 0.0:                            # the ghost finger: a short curved swipe
				b.auto += dt
				var k: float = b.auto / 0.4
				_fling_sample(b, b.ax0 + b.adx * k * k + sin(k * 3.0) * 6.0, b.ay0 + b.ady * k * k, t)
				if b.auto > 0.4:
					b.auto = -1.0
					_fling_let_go(b)
			elif b.dragging and t - b.lastPress > release:
				_fling_let_go(b)
			elif not b.dragging and b.idle > autoEvery:
				b.idle = 0.0
				b.auto = 0.0
				b.ax0 = b.x
				b.ay0 = b.y
				b.adx = randf_range(-1.0, 1.0) * W * 0.3
				b.ady = -randf_range(0.15, 0.4) * H
			if not b.dragging:                           # Bounce, with drag
				var G: float = H * g
				var dr: float = exp(-dragD * dt)
				b.vy += G * dt
				b.vx *= dr
				b.vy *= dr
				b.x += b.vx * dt
				b.y += b.vy * dt
				if b.y > GY - R:
					b.y = GY - R
					b.vy = -b.vy * e
					b.vx *= 0.98
				if b.x < R:
					b.x = R
					b.vx = -b.vx * e
				if b.x > W - R:
					b.x = W - R
					b.vx = -b.vx * e
				if b.y < R:
					b.y = R
					b.vy = -b.vy * e
			b.arrT -= dt
		"swipe":
			var dirs: int = D.dirs
			var release: float = D.release
			var autoEvery: float = D.autoEvery
			var r: float = b.r
			b.idle += dt
			if b.auto >= 0.0:                            # the ghost finger
				b.auto += dt
				var k: float = clampf(b.auto / b.aDur, 0.0, 1.0)
				var a: float = b.aDir * TAU / dirs
				_swipe_move(b, b.ax + cos(a) * b.aLen * k, b.ay + sin(a) * b.aLen * k)
				if b.auto >= b.aDur:
					b.auto = -1.0
					_swipe_end(b, t)
			elif b.stroke and t - b.lastPress > release:
				_swipe_end(b, b.lastPress)
			elif not b.stroke and b.idle > autoEvery:
				b.idle = 0.0
				b.auto = 0.0
				b.aDir = int(floorf(randf_range(0.0, dirs)))
				b.aLen = randf_range(0.06, 0.28) * W
				b.aDur = randf_range(0.15, 0.75)
				b.ax = b.rx + randf_range(-1.0, 1.0) * r * 0.4
				b.ay = b.ry + randf_range(-1.0, 1.0) * r * 0.4
				_swipe_begin(b, b.ax, b.ay, t)
			b.litT -= dt
			b.badT -= dt
			b.hopT = minf(1.0, b.hopT + dt / b.hopLen)
		"quartercircle":
			var P: Array = D.pattern
			var window: float = D.window
			var gap: float = D.gap
			var speed: float = D.speed
			var autoEvery: float = D.autoEvery
			b.idle += dt
			var a0: float = int(P[0]) * TAU / 8.0
			var a1: float = int(P[P.size() - 1]) * TAU / 8.0
			if b.auto >= 0.0:                            # the ghost finger traces the pattern
				b.auto += dt
				var k: float = clampf(b.auto / b.aDur, 0.0, 1.0)
				var a: float = a0 + (a1 - a0) * k
				var rr: float = QC_R * 3.2
				_qc_push(b, b.mx + cos(a) * rr, b.my + sin(a) * rr, t)
				if b.auto >= b.aDur:
					b.auto = -1.0
					_qc_punch(b, t)
			elif b.tracing and t - b.lastPress > gap:
				_qc_punch(b, t)
			elif not b.tracing and b.idle > autoEvery:
				b.idle = 0.0
				b.auto = 0.0
				b.aDur = randf_range(0.2, window * 1.7)
				(b.trail as Array).clear()
			b.litT -= dt
			b.jabT -= dt
			var shot: Dictionary = b.shot
			if shot.on:
				shot.x += shot.dir * W * speed * dt
				if shot.x < -20.0 or shot.x > W + 20.0:
					shot.on = false
		"virtualstick":
			var radius: float = D.radius
			var vmax: float = D["max"]
			var steer: float = D.steer
			var gap: float = D.gap
			var autoEvery: float = D.autoEvery
			b.idle += dt
			var r: float = W * radius
			if b.auto >= 0.0:                            # the ghost thumb: lands, circles, lifts
				b.auto += dt
				var k: float = b.auto * 3.2
				_vs_thumb(b, b.ox + cos(k) * r * 1.25, b.oy + sin(k * 0.5) * r * 0.9)
				if b.auto > 2.2:
					b.auto = -1.0
					b.on = false
					b.ghost = false
			elif b.on and not b.ghost and t - b.lastPress > gap:
				b.on = false
			elif not b.on and b.idle > autoEvery:
				b.idle = 0.0
				b.auto = 0.0
				b.ghost = true
				_vs_land(b, randf_range(W * 0.2, W * 0.8), randf_range(H * 0.25, H * 0.8))
			var sx := 0.0
			var sy := 0.0
			if b.on:                                     # the −1..1 stick
				sx = (b.tx - b.ox) / r
				sy = (b.ty - b.oy) / r
			var k2: float = Kit.smooth(steer, dt)
			b.vx += (sx * W * vmax - b.vx) * k2
			b.vy += (sy * W * vmax - b.vy) * k2
			b.x = clampf(b.x + b.vx * dt, 10.0, W - 10.0)
			b.y = clampf(b.y + b.vy * dt, 10.0, H - 10.0)
			b.sx = sx
			b.sy = sy
		"mouselook":
			var pitchMax: float = D.pitchMax
			var smoothRate: float = D.smoothRate
			var pm: float = pitchMax * TAU / 360.0
			if t - b.lastPress > 2.0:                    # the idle sweep
				b.yaw += dt * 0.3 * sin(t * 0.35)
				b.pitch += (sin(t * 0.5) * 0.25 * pm - b.pitch) * minf(1.0, dt)
			var k: float = Kit.smooth(smoothRate, dt)
			b.yawS += wrapf(b.yaw - b.yawS, -PI, PI) * k
			b.pitchS += (b.pitch - b.pitchS) * k
			b.dT -= dt

## Charge's fill bar: a level in seconds → a y on the bar (max at the top).
static func _charge_u1(by: float, bh: float, cmax: float, v: float) -> float:
	return by + bh - clampf(v / cmax, 0.0, 1.0) * bh

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	Kit.stage(n, b)
	match b.id:
		"coyote":
			var ledge: float = D.ledge
			var farD: float = D.far
			var speed: float = D.speed
			var coyote: float = D.coyote
			var edge: float = W * ledge
			var far: float = W * farD
			var x: float = b.x
			var y: float = b.y
			# the two platforms, and the window drawn as a distance
			Kit.rect(n, Rect2(0.0, GY, edge, H - GY), Color(Kit.BONE, 0.12))
			Kit.rect(n, Rect2(far, GY, W - far, H - GY), Color(Kit.BONE, 0.12))
			Kit.line(n, Vector2(0.0, GY), Vector2(edge, GY), Color(Kit.BONE, 0.7), 1.5)
			Kit.line(n, Vector2(far, GY), Vector2(W, GY), Color(Kit.BONE, 0.7), 1.5)
			Kit.line(n, Vector2(edge, GY), Vector2(edge, H), Color(Kit.BONE, 0.3))
			Kit.line(n, Vector2(far, GY), Vector2(far, H), Color(Kit.BONE, 0.3))
			Kit.rect(n, Rect2(edge, GY - 3.0, W * speed * coyote, 3.0), Color(Kit.TARGET, 0.55))
			Kit.label(n, b, "speed × coyote", Vector2(edge + 2.0, GY + 12.0), Color(Kit.TARGET, 0.7))
			var trail: Array[Vector2] = b.trail
			for i in trail.size():
				Kit.dot(n, trail[i], 1.3, Color(Kit.MOVER, i / float(trail.size()) * 0.35))
			# the grace bar over the mote
			var grace: float
			if b.air and not b.jumped:
				grace = clampf(coyote - (t - b.tLeft), 0.0, coyote)
			else:
				grace = 0.0 if b.air else coyote
			var bw := 30.0
			var gcol: Color = Kit.GOOD if grace > 0.0 else Kit.HOT
			Kit.rect(n, Rect2(x - bw / 2.0, y - 20.0, bw, 4.0), Color(Kit.INK, 0.15))
			Kit.rect(n, Rect2(x - bw / 2.0, y - 20.0, bw * grace / coyote, 4.0), gcol)
			if b.air and not b.jumped:
				Kit.label(n, b, "%d ms" % roundi(grace * 1000.0), Vector2(x + bw / 2.0 + 3.0, y - 16.0), gcol)
			Kit.mote(n, b, Vector2(x, y), atan2(b.vy, W * speed) if b.air else 0.0)
			var flash: float = b.flash
			if flash > 0.0:
				var a: float = minf(1.0, flash * 1.6)
				var fx: float = b.fx
				var fy: float = b.fy
				if b.ok:
					Kit.ring(n, Vector2(fx, fy), 10.0 + (0.6 - flash) * 50.0, Color(Kit.GOOD, a), 2.0)
				else:
					Kit.line(n, Vector2(fx - 9.0, fy - 24.0), Vector2(fx + 9.0, fy - 6.0), Color(Kit.HOT, a), 2.5)
					Kit.line(n, Vector2(fx + 9.0, fy - 24.0), Vector2(fx - 9.0, fy - 6.0), Color(Kit.HOT, a), 2.5)
				Kit.label(n, b, "honoured" if b.ok else "refused", Vector2(fx, fy - 30.0), Kit.GOOD if b.ok else Kit.HOT, true)
			Kit.label(n, b, "honoured %d · refused %d" % [b.honoured, b.refused], Vector2(W / 2.0, 14.0), Kit.DIM, true)
		"jumpbuffer":
			Kit.ground(n, b)
			var buffer: float = D.buffer
			var drop: float = D.drop
			var x: float = W / 2.0
			var y: float = b.y
			var vy: float = b.vy
			var phase: String = b.phase
			# the buffer as a distance above the floor
			if phase == "fall" and vy > 0.0:
				var band: float = clampf(vy * buffer, 0.0, GY)
				Kit.rect(n, Rect2(x - W * 0.2, GY - band, W * 0.4, band), Color(Kit.TARGET, 0.13))
				Kit.line(n, Vector2(x - W * 0.2, GY - band), Vector2(x + W * 0.2, GY - band), Color(Kit.TARGET, 0.6))
				Kit.label(n, b, "|vy| × buffer", Vector2(x + W * 0.2 + 3.0, GY - band + 3.0), Color(Kit.TARGET, 0.7))
			Kit.ring(n, Vector2(x, GY - R - H * drop), 4.0, Kit.DIM)   # where drops begin
			# the stored press: an amber pip with a shrinking life
			var tPress: float = b.tPress
			var life: float = buffer - (t - tPress)
			if life > 0.0 and phase == "fall":
				Kit.dot(n, Vector2(x + 22.0, y), 5.0, Kit.TARGET)
				Kit.rect(n, Rect2(x + 30.0, y - 2.0, 26.0, 4.0), Color(Kit.INK, 0.15))
				Kit.rect(n, Rect2(x + 30.0, y - 2.0, 26.0 * life / buffer, 4.0), Kit.TARGET)
				Kit.label(n, b, "stored", Vector2(x + 30.0, y - 6.0), Color(Kit.TARGET, 0.8))
			elif tPress > 0.0 and phase == "fall":       # it waited too long
				Kit.dot(n, Vector2(x + 22.0, y), 4.0, Color(Kit.INK, 0.3))
				Kit.label(n, b, "expired", Vector2(x + 30.0, y + 3.0), Kit.DIM)
			var ang: float = -0.5 if phase == "jump" else (0.5 if phase == "fall" else 0.0)
			Kit.mote(n, b, Vector2(x, y), ang)
			var flash: float = b.flash
			if flash > 0.0:
				var a: float = minf(1.0, flash * 1.6)
				var fy: float = b.fy
				if b.wasOk:
					Kit.ring(n, Vector2(x, fy), 10.0 + (0.6 - flash) * 50.0, Color(Kit.GOOD, a), 2.0)
					Kit.label(n, b, "fired on touchdown", Vector2(x, fy - 26.0), Kit.GOOD, true)
				else:
					Kit.label(n, b, "landed, nothing stored", Vector2(x, fy - 26.0), Kit.DIM, true)
			Kit.label(n, b, "fired %d · expired %d" % [b.fired, b.expired], Vector2(W / 2.0, 14.0), Kit.DIM, true)
		"variable":
			Kit.ground(n, b)
			var holdMax: float = D.holdMax
			var holds: Array = D.holds
			var N: int = holds.size()
			var gy: Array[float] = b.gys
			var apex: Array[float] = b.apex
			var cut: Array[bool] = b.cut
			# draw: lanes, apex lines, bodies
			for i in N:
				var x: float = W * (0.14 + i * 0.2)
				Kit.line(n, Vector2(x - 22.0, apex[i] - R), Vector2(x + 22.0, apex[i] - R), Color(Kit.MAGIC, 0.7))
				Kit.label(n, b, _num(holds[i]) + " s", Vector2(x, apex[i] - R - 4.0), Color(Kit.MAGIC, 0.9), true)
				Kit.label(n, b, "h %d" % roundi(GY - R - apex[i]), Vector2(x, GY + 14.0), Kit.DIM, true)
				var holding: bool = gy[i] < GY - R and not cut[i]
				# globalAlpha 0.55 → the body's colour alpha (the eye stays opaque)
				Kit.mote(n, b, Vector2(x, gy[i]), -0.5 if holding else 0.3, Color(Kit.MAGIC, 0.55))
				if holding:
					Kit.label(n, b, "held", Vector2(x, gy[i] + 22.0), Color(Kit.MAGIC, 0.9), true)
			var lx: float = W * (0.14 + N * 0.2)
			var ly: float = b.ly
			var lv: float = b.lv
			var lapex: float = b.lapex
			Kit.line(n, Vector2(lx - 22.0, lapex - R), Vector2(lx + 22.0, lapex - R), Color(Kit.MOVER, 0.8))
			Kit.label(n, b, "h %d" % roundi(GY - R - lapex), Vector2(lx, GY + 14.0), Kit.MOVER, true)
			Kit.mote(n, b, Vector2(lx, ly), -0.5 if b.held else (0.3 if lv != 0.0 else 0.0))
			if b.held:
				var holdT: float = b.holdT
				Kit.rect(n, Rect2(lx - 10.0, ly - 22.0, 20.0, 4.0), Color(Kit.INK, 0.15))
				Kit.rect(n, Rect2(lx - 10.0, ly - 22.0, 20.0 * clampf(holdT / holdMax, 0.0, 1.0), 4.0), Kit.GOOD)
				Kit.label(n, b, "held %.2f" % holdT, Vector2(lx, ly - 26.0), Kit.GOOD, true)
			Kit.label(n, b, "you", Vector2(lx, 14.0), Kit.MOVER, true)
		"deadzone":
			var dz: float = D.dz
			var snap: int = D.snap
			var r: float = minf(W, H) * 0.11
			var cy: float = H * 0.3
			var sx: float = b.sx
			var sy: float = b.sy
			var out: Array[Vector2] = b.out
			var m: Array[Vector2] = b.m
			for i in 3:
				var cx: float = W * (0.5 / 3.0 + i / 3.0)
				var col: Color = DZ_COLS[i]
				var c := Vector2(cx, cy)
				Kit.ring(n, c, r, Color(Kit.BONE, 0.35))
				if i > 0:
					Kit.ring(n, c, r * dz, Color(Kit.HOT, 0.5))
				if i == 2 and snap > 0:
					for k in snap:
						Kit.line(n, c, c + Vector2(cos(k / float(snap) * TAU), sin(k / float(snap) * TAU)) * r, Color(Kit.GOOD, 0.2))
				Kit.dot(n, c + Vector2(sx, sy) * r, 2.5, Color(Kit.INK, 0.45))   # the raw stick
				Kit.arrow(n, c, c + out[i] * r, col)
				Kit.dot(n, c + out[i] * r, 3.0, col)
				Kit.label(n, b, DZ_NAMES[i], Vector2(cx, cy - r - 6.0), col, true)
				var ol: float = out[i].length()          # the magnitude bar: watch the step
				Kit.rect(n, Rect2(cx - r, cy + r + 6.0, r * 2.0, 3.0), Color(Kit.INK, 0.12))
				Kit.rect(n, Rect2(cx - r, cy + r + 6.0, r * 2.0 * ol, 3.0), col)
				if i > 0:
					Kit.line(n, Vector2(cx - r + r * 2.0 * dz, cy + r + 4.0), Vector2(cx - r + r * 2.0 * dz, cy + r + 11.0), Kit.HOT)
				var x0: float = W * i / 3.0 + 12.0
				var x1: float = W * (i + 1) / 3.0 - 12.0
				Kit.line(n, Vector2(x0, H * 0.56), Vector2(x0, H * 0.88), Kit.DIM)
				Kit.line(n, Vector2(x1, H * 0.56), Vector2(x1, H * 0.88), Kit.DIM)
				var ang: float = atan2(out[i].y, out[i].x) if ol > 0.01 else 0.0
				Kit.mote(n, b, m[i], ang, Kit.MOVER if i == 2 else Color(Kit.MOVER, 0.6), 7.0)
			Kit.label(n, b, "len = %.2f" % (b.L as float), Vector2(W / 2.0, 12.0), Kit.DIM, true)
		"normalize":
			var speed: float = D.speed
			var P: Array[Vector2] = b.P
			var A: Dictionary = b.A
			var B: Dictionary = b.B
			var cx: float = b.cx
			var cy: float = b.cy
			Kit.poly(n, P, Color(Kit.BONE, 0.3), 1.0)
			for i in P.size():
				Kit.dot(n, P[i], 2.0, Kit.TARGET if i == 0 else Kit.DIM)
			for i in 4:                                  # mark which legs are diagonal
				var pa: Vector2 = P[i * 2 + 1]
				var pb: Vector2 = P[(i * 2 + 2) % 8]
				Kit.label(n, b, "√2?", (pa + pb) / 2.0 + Vector2(0.0, -4.0), Color(Kit.MAGIC, 0.45), true)
			var av := Vector2(A.vx, A.vy)
			var bv := Vector2(B.vx, B.vy)
			var ap := Vector2(A.x, A.y)
			var bp := Vector2(B.x, B.y)
			var isDiag: bool = av.x != 0.0 and av.y != 0.0
			Kit.arrow(n, ap, ap + av * 0.3, Kit.MAGIC)
			Kit.arrow(n, bp, bp + bv * 0.3, Kit.MOVER)
			Kit.mote(n, b, ap, atan2(av.y, av.x), Kit.MAGIC, 7.0)
			Kit.mote(n, b, bp, atan2(bv.y, bv.x), Kit.MOVER, 7.0)
			if isDiag:
				Kit.label(n, b, "|v| = %.2f ×" % (av.length() / (W * speed)), ap + Vector2(0.0, -12.0), Kit.MAGIC, true)
			var aLast: float = A.last
			var bLast: float = B.last
			Kit.label(n, b, "adds x + y · lap " + (("%.2f s" % aLast) if aLast != 0.0 else "…"), Vector2(6.0, 14.0), Kit.MAGIC)
			Kit.label(n, b, "normalised · lap " + (("%.2f s" % bLast) if bLast != 0.0 else "…"), Vector2(6.0, 26.0), Kit.MOVER)
			if b.overT > 0.0:
				Kit.arrow(n, Vector2(cx, cy), Vector2(cx + b.ox * 16.0, cy + b.oy * 16.0), Kit.TARGET)
				Kit.label(n, b, "your direction", Vector2(cx, cy + 20.0), Kit.TARGET, true)
		"accelerate":
			Kit.ground(n, b)
			var vmax: float = D["max"]
			var accel: float = D.accel
			var brake: float = D.brake
			var airAccel: float = D.airAccel
			var hist: Array[float] = b.hist
			var airH: Array[int] = b.airH
			var hi: int = b.hi
			var x: float = b.x
			var y: float = b.y
			var v: float = b.v
			var want: float = b.want
			# the strip: v against time
			var sy0: float = H * 0.09
			var sh: float = H * 0.24
			var mid: float = sy0 + sh / 2.0
			Kit.rect(n, Rect2(0.0, sy0, W, sh), Color(0.0, 0.0, 0.0, 0.18))
			Kit.line(n, Vector2(0.0, mid), Vector2(W, mid), Kit.DIM)
			Kit.line(n, Vector2(0.0, sy0 + 2.0), Vector2(W, sy0 + 2.0), Color(Kit.TARGET, 0.35))
			Kit.line(n, Vector2(0.0, sy0 + sh - 2.0), Vector2(W, sy0 + sh - 2.0), Color(Kit.TARGET, 0.35))
			Kit.label(n, b, "+max", Vector2(3.0, sy0 + 10.0), Color(Kit.TARGET, 0.6))
			Kit.label(n, b, "−max", Vector2(3.0, sy0 + sh - 3.0), Color(Kit.TARGET, 0.6))
			for i in ACCEL_N:
				var j: int = (hi + i) % ACCEL_N
				var gx: float = i / float(ACCEL_N - 1) * W
				var gy: float = mid - hist[j] * (sh / 2.0 - 2.0)
				Kit.dot(n, Vector2(gx, gy), 1.4, Kit.MAGIC if airH[j] == 1 else Kit.GOOD)
			_label_right(n, b, "ground", Vector2(W - 4.0, sy0 + 10.0), Kit.GOOD)
			_label_right(n, b, "air", Vector2(W - 4.0, sy0 + 20.0), Kit.MAGIC)
			# the lanes, the wish and the velocity
			Kit.line(n, Vector2(0.0, GY - H * 0.34), Vector2(W, GY - H * 0.34), Color(Kit.MAGIC, 0.15))
			Kit.label(n, b, "air lane", Vector2(4.0, GY - H * 0.34 - 3.0), Color(Kit.MAGIC, 0.5))
			Kit.arrow(n, Vector2(x, y - 22.0), Vector2(x + want * 22.0, y - 22.0), Kit.TARGET)
			Kit.arrow(n, Vector2(x, y), Vector2(x + v * 0.35, y), Kit.GOOD)
			Kit.mote(n, b, Vector2(x, y), PI if v < 0.0 else 0.0)
			var rate: String = b.rate
			var rv: float = accel if rate == "accel" else (brake if rate == "brake" else airAccel)
			var rcol: Color = Kit.HOT if rate == "brake" else (Kit.GOOD if rate == "accel" else Kit.MAGIC)
			Kit.label(n, b, rate + " " + _num(rv), Vector2(x, y - 30.0), rcol, true)
			Kit.label(n, b, "v = %.2f max" % (v / (vmax * W)), Vector2(W / 2.0, GY + 16.0), Kit.DIM, true)
		"multitap":
			Kit.ground(n, b)
			var tapMax: float = D.tapMax
			var holdMin: float = D.holdMin
			var dblGap: float = D.dblGap
			var span: float = D.span
			var x: float = b.x
			var y: float = b.y
			var dur: float = b.dur
			var charge: float = b.charge
			if b.down and dur >= holdMin:
				Kit.ring(n, Vector2(x, y), 12.0 + charge * 14.0, Kit.TARGET, 2.0)
				Kit.label(n, b, "charging", Vector2(x, y - 30.0), Kit.TARGET, true)
			elif b.down:
				Kit.ring(n, Vector2(x, y), 12.0, Color(Kit.INK, 0.5), 1.5)
				Kit.label(n, b, "%.2f s" % dur, Vector2(x, y - 26.0), Kit.DIM, true)
			Kit.mote(n, b, Vector2(x, y), 0.0 if b.face > 0.0 else PI)
			if b.verbT > 0.0:
				var verb: String = b.verb
				var vcol: Color = Kit.MAGIC if verb.contains("dash") else (Kit.TARGET if verb.contains("charge") else (Kit.HOT if verb.contains("neither") else Kit.GOOD))
				Kit.label(n, b, verb, Vector2(W / 2.0, H * 0.12), vcol, true)
			# the timeline: last span seconds, now at the right edge
			var ty: float = GY + 8.0
			var th := 14.0
			Kit.rect(n, Rect2(0.0, ty, W, th), Color(0.0, 0.0, 0.0, 0.2))
			for ev in (b.events as Array):
				var d: float = ev.d
				var up: float = t if (ev.u as float) < 0.0 else ev.u
				if _mt_x(W, span, t, up) < 0.0:
					continue
				var xd: float = maxf(0.0, _mt_x(W, span, t, d))
				Kit.rect(n, Rect2(xd, ty + 1.0, maxf(0.0, _mt_x(W, span, t, d + tapMax) - xd), th - 2.0), Color(Kit.GOOD, 0.18))
				if up - d >= holdMin:
					var xh: float = maxf(0.0, _mt_x(W, span, t, d + holdMin))
					Kit.rect(n, Rect2(xh, ty + 1.0, _mt_x(W, span, t, up) - xh, th - 2.0), Color(Kit.TARGET, 0.22))
				var kind: String = ev.kind
				if kind == "tap":
					var xu: float = maxf(0.0, _mt_x(W, span, t, up))
					Kit.rect(n, Rect2(xu, ty + 1.0, maxf(0.0, _mt_x(W, span, t, up + dblGap) - xu), th - 2.0), Color(Kit.MAGIC, 0.22))
				var col: Color = Kit.TARGET if kind == "hold" else (Kit.MAGIC if kind == "dbl" else (Kit.HOT if kind == "none" else (Kit.GOOD if kind == "tap" else Color(Kit.INK, 0.8))))
				Kit.rect(n, Rect2(xd, ty + 4.0, maxf(1.5, _mt_x(W, span, t, up) - xd), th - 8.0), col)
			Kit.line(n, Vector2(W - 1.0, ty - 2.0), Vector2(W - 1.0, ty + th + 2.0), Color(Kit.INK, 0.5))
			Kit.label(n, b, "tap", Vector2(4.0, ty + th + 11.0), Kit.GOOD)
			Kit.label(n, b, "hold", Vector2(30.0, ty + th + 11.0), Kit.TARGET)
			Kit.label(n, b, "double", Vector2(60.0, ty + th + 11.0), Kit.MAGIC)
		"charge":
			Kit.ground(n, b)
			var fill: float = D.fill
			var cmax: float = D["max"]
			var sweet: Array = D.sweet
			var s0: float = sweet[0]
			var s1: float = sweet[1]
			var x0: float = b.x0
			var x: float = b.x
			var y: float = b.y
			var c: float = b.c
			var phase: String = b.phase
			# the fill bar: max at the top, fill marked, sweet band, overcharge zone
			var bx: float = x0 - 26.0
			var bh: float = H * 0.42
			var by: float = GY - R - bh - 6.0
			Kit.rect(n, Rect2(bx, by, 8.0, bh), Color(Kit.INK, 0.1))
			Kit.rect(n, Rect2(bx, by, 8.0, _charge_u1(by, bh, cmax, fill) - by), Color(Kit.HOT, 0.2))   # the overcharge zone: full → max
			var ys1: float = _charge_u1(by, bh, cmax, s1 * fill)
			var ys0: float = _charge_u1(by, bh, cmax, s0 * fill)
			Kit.rect(n, Rect2(bx, ys1, 8.0, ys0 - ys1), Color(Kit.GOOD, 0.45))
			var level: float = c if phase == "charge" else 0.0
			var yl: float = _charge_u1(by, bh, cmax, level)
			var inSweet: bool = level / fill >= s0 and level / fill <= s1
			var lcol: Color = Kit.HOT if level > fill else (Kit.GOOD if inSweet else Kit.TARGET)
			Kit.rect(n, Rect2(bx, yl, 8.0, by + bh - yl), lcol)
			var yf: float = _charge_u1(by, bh, cmax, fill)
			Kit.line(n, Vector2(bx - 3.0, yf), Vector2(bx + 11.0, yf), Kit.TARGET)
			Kit.label(n, b, "full", Vector2(bx + 13.0, yf + 3.0), Kit.TARGET)
			Kit.label(n, b, "max", Vector2(bx + 13.0, by + 4.0), Kit.HOT)
			Kit.label(n, b, "sweet", Vector2(bx + 13.0, ys1 + 8.0), Kit.GOOD)
			if phase == "charge":
				Kit.label(n, b, "%.2f s" % c, Vector2(bx + 4.0, by - 4.0), Kit.DIM, true)
			var trail: Array[Vector2] = b.trail
			for i in trail.size():
				Kit.dot(n, trail[i], 1.3, Color(Kit.MOVER, i / float(trail.size()) * 0.4))
			var landX: float = b.landX
			if landX >= 0.0 and phase == "landed":
				Kit.ring(n, Vector2(landX, GY - 3.0), 5.0, Kit.TARGET, 1.5)
				var wraps: int = b.wraps
				var dtxt: String = "d = %d px" % roundi(b.dist)
				if wraps > 0:
					dtxt += " (+%d screen)" % wraps
				Kit.label(n, b, dtxt, Vector2(landX, GY + 16.0), Kit.TARGET, true)
			Kit.dot(n, Vector2(x0, GY - 2.0), 2.0, Kit.DIM)
			var stumble: float = b.stumble
			var ang: float = atan2(b.vy, b.vx) if phase == "fly" else (sin(stumble * 20.0) * 0.8 if phase == "stumble" else 0.0)
			var sc: float = (1.0 + minf(c / cmax, 1.0) * 0.25) if phase == "charge" else 1.0
			_mote_squash(n, b, Vector2(x, y), ang, Kit.HOT if phase == "stumble" else Kit.MOVER, sc)
			if b.flash > 0.0:
				var msg: String = b.msg
				var mcol: Color = Kit.HOT if msg.contains("backfire") else (Kit.GOOD if msg.contains("sweet") else Kit.TARGET)
				Kit.label(n, b, msg, Vector2(W / 2.0, H * 0.12), mcol, true)
		"fling":
			Kit.ground(n, b)
			var nmax: int = D.n
			var hx: Array[float] = b.hx
			var hy: Array[float] = b.hy
			var count: int = b.count
			var head: int = b.head
			var dragging: bool = b.dragging
			var arrT: float = b.arrT
			var nn: int = mini(nmax, count)
			for i in count:                              # the buffer: newest brightest, the last n ringed
				var j: int = posmod(head - 1 - i, FLING_CAP)
				var a: float = 0.5 * (1.0 - i / float(FLING_CAP)) if (dragging or arrT > 0.0) else 0.0
				if a > 0.0:
					Kit.dot(n, Vector2(hx[j], hy[j]), 2.0, Color(Kit.INK, a))
					if i < nn:
						Kit.ring(n, Vector2(hx[j], hy[j]), 4.0, Color(Kit.HOT, a + 0.2))
			if arrT > 0.0:
				var rp := Vector2(b.rx, b.ry)
				var rv := Vector2(b.rvx, b.rvy)
				Kit.arrow(n, rp, rp + rv * 0.25, Kit.HOT)
				Kit.label(n, b, "|v| = %d px/s" % roundi(rv.length()), rp + Vector2(0.0, -14.0), Kit.HOT, true)
			var p := Vector2(b.x, b.y)
			if b.auto >= 0.0:
				Kit.ring(n, p, 12.0, Kit.MAGIC, 1.5)
			Kit.mote(n, b, p, 0.0 if dragging else atan2(b.vy, b.vx))
			Kit.label(n, b, ("dragging: %d samples" % count) if dragging else "free", Vector2(W / 2.0, 14.0), Kit.DIM, true)
		"swipe":
			var dirs: int = D.dirs
			var minDist: float = D.minDist
			var r: float = b.r
			var rx: float = b.rx
			var ry: float = b.ry
			var ts: float = b.ts
			var cols: int = b.cols
			var rows: int = b.rows
			var gx0: float = b.gx0
			var gy0: float = b.gy0
			var lit: int = b.lit
			var litT: float = b.litT
			var badT: float = b.badT
			var stroke: bool = b.stroke
			# the rose
			var w: float = TAU / dirs
			var rc := Vector2(rx, ry)
			for k in dirs:
				var on: bool = k == lit and litT > 0.0
				var fill: Color = Color(Kit.GOOD, 0.25 + litT * 0.6) if on else Color(Kit.BONE, 0.06)
				_wedge(n, rc, r, k * w - w / 2.0, k * w + w / 2.0, fill, Color(Kit.BONE, 0.3), 1.0)
				var dirv := Vector2(cos(k * w), sin(k * w))
				Kit.arrow(n, rc + dirv * r * 0.55, rc + dirv * r * 0.85, Kit.GOOD if on else Kit.DIM)
			if badT > 0.0:
				Kit.ring(n, rc, r + 3.0, Kit.HOT, 2.0)
				Kit.label(n, b, b.bad, Vector2(rx, ry + r + 14.0), Kit.HOT, true)
			# the stroke: start ring = minDist, the delta arrow
			var sp := Vector2(b.sx0, b.sy0)
			var cp := Vector2(b.cx, b.cy)
			if stroke or litT > 0.4 or badT > 0.4:
				Kit.ring(n, sp, W * minDist, Color(Kit.INK, 0.3))
				Kit.arrow(n, sp, cp, Kit.BONE if stroke else (Kit.HOT if badT > 0.0 else Kit.GOOD))
				if stroke:
					Kit.label(n, b, "%.2f s" % (t - (b.st0 as float)), cp + Vector2(8.0, -8.0), Kit.DIM)
			if b.auto >= 0.0:
				Kit.ring(n, cp, 9.0, Kit.MAGIC, 1.5)
			# the tile grid and the hop
			for i in cols + 1:
				Kit.line(n, Vector2(gx0 + i * ts, gy0), Vector2(gx0 + i * ts, gy0 + rows * ts), Color(Kit.BONE, 0.18))
			for j in rows + 1:
				Kit.line(n, Vector2(gx0, gy0 + j * ts), Vector2(gx0 + cols * ts, gy0 + j * ts), Color(Kit.BONE, 0.18))
			var hopT: float = b.hopT
			var fi: int = b.fi
			var fr: int = b.fr
			var ti: int = b.ti
			var tr: int = b.tr
			var k2: float = _ease(hopT)
			var mx: float = gx0 + (fi + (ti - fi) * k2 + 0.5) * ts
			var my: float = gy0 + (fr + (tr - fr) * k2 + 0.5) * ts - sin(hopT * PI) * (0.0 if D.slide else ts * 0.4)
			if hopT < 1.0:
				Kit.rect(n, Rect2(gx0 + ti * ts + 2.0, gy0 + tr * ts + 2.0, ts - 4.0, ts - 4.0), Color(Kit.GOOD, 0.15))
			Kit.mote(n, b, Vector2(mx, my), atan2(float(tr - fr), float(ti - fi)) if hopT < 1.0 else 0.0, Kit.MOVER, minf(8.0, ts * 0.32))
			Kit.label(n, b, "%d wedges of %d°" % [dirs, roundi(360.0 / dirs)], Vector2(rx, ry - r - 6.0), Kit.DIM, true)
		"quartercircle":
			Kit.ground(n, b)
			var P: Array = D.pattern
			var window: float = D.window
			var buf: int = D.buf
			var mx: float = b.mx
			var my: float = b.my
			var mc := Vector2(mx, my)
			var bd: Array[int] = b.bd
			var bt: Array[float] = b.bt
			var lit: Array[int] = b.lit
			var count: int = b.count
			var head: int = b.head
			var litT: float = b.litT
			var shot: Dictionary = b.shot
			var trail: Array[Vector2] = b.trail
			# the sector wheel around the mote
			for k in 8:
				var an: float = k * TAU / 8.0 + TAU / 16.0
				var dv := Vector2(cos(an), sin(an))
				Kit.line(n, mc + dv * QC_R * 1.6, mc + dv * QC_R * 4.0, Color(Kit.BONE, 0.14))
			var lastSec: int = b.lastSec
			if b.tracing and lastSec >= 0:
				var a: float = lastSec * TAU / 8.0
				_wedge(n, mc, QC_R * 4.0, a - TAU / 16.0, a + TAU / 16.0, Color(Kit.TARGET, 0.18))
			for i in trail.size():
				Kit.dot(n, trail[i], 1.5, Color(Kit.INK, i / float(trail.size()) * 0.5))
			if b.auto >= 0.0 and trail.size() > 0:
				Kit.ring(n, trail[trail.size() - 1], 8.0, Kit.MAGIC, 1.5)
			# the pattern row and the buffer row
			var cw: float = minf(22.0, W / (buf + 2))
			var py0: float = H * 0.12
			var by0: float = H * 0.27
			var px0: float = W / 2.0 - P.size() * cw / 2.0
			var bx0: float = W / 2.0 - buf * cw / 2.0
			_label_right(n, b, "pattern", Vector2(px0 - 6.0, py0 + 3.0), Kit.DIM)
			for i in P.size():
				_glyph(n, Vector2(px0 + i * cw + cw / 2.0, py0), int(P[i]), Kit.TARGET)
			_label_right(n, b, "buffer", Vector2(bx0 - 6.0, by0 + 3.0), Kit.DIM)
			for i in buf:
				var x: float = bx0 + i * cw + cw / 2.0
				Kit.rect(n, Rect2(x - cw / 2.0 + 1.0, by0 - 9.0, cw - 2.0, 18.0), Color(Kit.BONE, 0.07))
				if litT > 0.0:
					if lit[i] == 1:
						Kit.rect(n, Rect2(x - cw / 2.0 + 1.0, by0 - 9.0, cw - 2.0, 18.0), Color(Kit.GOOD, 0.3))
				elif i < count:
					var j: int = posmod(head - count + i, buf)
					var age: float = t - bt[j]
					_glyph(n, Vector2(x, by0), bd[j], Kit.BONE if age <= window else Color(Kit.BONE, 0.25))
			if litT > 0.0:
				Kit.label(n, b, "match — fire!" if b.litOk else "no match — jab", Vector2(W / 2.0, by0 + 22.0), Kit.GOOD if b.litOk else Kit.HOT, true)
			else:
				Kit.label(n, b, "window " + _num(window) + " s", Vector2(W / 2.0, by0 + 22.0), Kit.DIM, true)
			# the mote, the jab, the projectile
			if b.jabT > 0.0:
				Kit.line(n, Vector2(mx + QC_R, my), Vector2(mx + QC_R + 14.0, my), Color(Kit.INK, 0.7), 3.0)
			var sdir: float = shot.dir
			if shot.on:
				var spos := Vector2(shot.x, shot.y)
				Kit.dot(n, spos, 7.0, Kit.HOT)
				Kit.ring(n, spos, 10.0 + sin(t * 30.0) * 2.0, Color(Kit.HOT, 0.5), 1.5)
			Kit.mote(n, b, mc, PI if (sdir < 0.0 and (shot.on or litT > 0.0)) else 0.0, Kit.MOVER, QC_R)
			_label_right(n, b, "hits %d · jabs %d" % [b.hits, b.jabs], Vector2(W - 6.0, 14.0), Kit.DIM)
		"virtualstick":
			var radius: float = D.radius
			var floating: bool = D.floating
			var r: float = W * radius
			var op := Vector2(b.ox, b.oy)
			var tp := Vector2(b.tx, b.ty)
			var vel := Vector2(b.vx, b.vy)
			var p := Vector2(b.x, b.y)
			if b.on:
				var ghost: bool = b.ghost
				var c: Color = Kit.MAGIC if ghost else Kit.TARGET
				Kit.ring(n, op, r, Color(Kit.MAGIC, 0.6) if ghost else Color(Kit.TARGET, 0.6), 1.5)
				Kit.ring(n, op, r * 0.35, Kit.DIM)
				var raw := Vector2(b.rawx, b.rawy)
				if not floating and raw != tp:
					Kit.dot(n, raw, 3.0, Color(Kit.INK, 0.25))
					Kit.line(n, raw, tp, Kit.DIM)
					Kit.label(n, b, "clamped", raw + Vector2(6.0, 3.0), Kit.DIM)
				Kit.arrow(n, op, tp, Kit.GOOD)
				Kit.dot(n, tp, 7.0, c)
				Kit.label(n, b, "ghost thumb" if ghost else "thumb", tp + Vector2(9.0, -6.0), c)
				Kit.label(n, b, "origin", op + Vector2(0.0, r + 12.0), Kit.DIM, true)
				if floating:
					Kit.label(n, b, "floating", op + Vector2(0.0, -r - 5.0), Color(Kit.MAGIC, 0.8), true)
			Kit.arrow(n, p, p + vel * 0.3, Kit.GOOD)
			Kit.mote(n, b, p, atan2(vel.y, vel.x) if vel.length() > 2.0 else 0.0)
			Kit.label(n, b, "stick (%.2f, %.2f) · |v| %d" % [b.sx, b.sy, roundi(vel.length())], Vector2(W / 2.0, 14.0), Kit.DIM, true)
		"mouselook":
			var pitchMax: float = D.pitchMax
			var fovD: float = D.fov
			var accel: float = D.accel
			var pm: float = pitchMax * TAU / 360.0
			var fov: float = fovD * TAU / 360.0
			var yawS: float = b.yawS
			var pitchS: float = b.pitchS
			var hy: float = H * 0.5 + pitchS / maxf(0.01, pm) * H * 0.32   # pitch up = horizon down
			Kit.rect(n, Rect2(0.0, 0.0, W, hy), Color(Kit.MOVER, 0.05))
			Kit.rect(n, Rect2(0.0, hy, W, H - hy), Color(Kit.BONE, 0.07))
			Kit.line(n, Vector2(0.0, hy), Vector2(W, hy), Color(Kit.BONE, 0.55), 1.5)
			var posts: Array = b.posts
			for i in posts.size():                       # world angle → screen x
				var p: Dictionary = posts[i]
				var d: float = wrapf((p.a as float) - yawS, -PI, PI)
				if absf(d) > fov / 2.0 + 0.2:
					continue
				var sx: float = W / 2.0 + d / fov * W
				var ph: float = (p.h as float) * H
				var pw: float = p.w
				Kit.rect(n, Rect2(sx - pw / 2.0, hy - ph, pw, ph), Kit.BONE)
				Kit.dot(n, Vector2(sx, hy), 2.0, Kit.DIM)
				if i % 3 == 0:
					var quarter: int = int(floorf(i / 3.0))
					Kit.label(n, b, COMPASS[quarter], Vector2(sx, hy - ph - 4.0), Kit.TARGET, true)
			var mid := Vector2(W / 2.0, H / 2.0)
			Kit.ring(n, mid, 7.0, Kit.INK, 1.2)         # the reticle
			Kit.line(n, mid + Vector2(-14.0, 0.0), mid + Vector2(-9.0, 0.0), Kit.INK)
			Kit.line(n, mid + Vector2(9.0, 0.0), mid + Vector2(14.0, 0.0), Kit.INK)
			Kit.line(n, mid + Vector2(0.0, -14.0), mid + Vector2(0.0, -9.0), Kit.INK)
			Kit.line(n, mid + Vector2(0.0, 9.0), mid + Vector2(0.0, 14.0), Kit.INK)
			if b.dT > 0.0:
				var dd := Vector2(b.ddx, b.ddy)
				Kit.arrow(n, mid, mid + dd * 1.5, Kit.HOT)
				Kit.label(n, b, "Δ (%d, %d)" % [roundi(dd.x), roundi(dd.y)], mid + dd * 1.5 + Vector2(6.0, 0.0), Kit.HOT)
			# the pitch clamp gauge and the curve
			var gx: float = W - 14.0
			var gy0: float = H * 0.2
			var gh: float = H * 0.5
			Kit.rect(n, Rect2(gx - 2.0, gy0, 4.0, gh), Color(Kit.INK, 0.1))
			Kit.line(n, Vector2(gx - 6.0, gy0), Vector2(gx + 6.0, gy0), Kit.HOT)
			Kit.line(n, Vector2(gx - 6.0, gy0 + gh), Vector2(gx + 6.0, gy0 + gh), Kit.HOT)
			Kit.dot(n, Vector2(gx, gy0 + gh / 2.0 - pitchS / maxf(0.01, pm) * gh / 2.0), 4.0, Kit.TARGET)
			_label_right(n, b, "±" + _num(pitchMax) + "°", Vector2(gx - 8.0, gy0 - 4.0), Kit.HOT)
			var cx0 := 8.0
			var cy0: float = H * 0.9
			var cs: float = minf(W, H) * 0.14
			Kit.line(n, Vector2(cx0, cy0), Vector2(cx0 + cs, cy0), Kit.DIM)
			Kit.line(n, Vector2(cx0, cy0), Vector2(cx0, cy0 - cs), Kit.DIM)
			var curve := PackedVector2Array()
			for i in 13:
				var q: float = i / 12.0
				curve.append(Vector2(cx0 + q * cs, cy0 - pow(q, accel) * cs))
			n.draw_polyline(curve, Kit.GOOD, 1.5)
			Kit.label(n, b, "|Δ|^" + _num(accel), Vector2(cx0 + cs + 4.0, cy0 - cs + 8.0), Kit.GOOD)
			var yawDeg: int = posmod(roundi(yawS * 360.0 / TAU), 360)
			Kit.label(n, b, "yaw %d° · pitch %d°" % [yawDeg, roundi(pitchS * 360.0 / TAU)], Vector2(W / 2.0, 14.0), Kit.DIM, true)
	Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
