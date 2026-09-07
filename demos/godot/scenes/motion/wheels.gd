extends RefCounted

const Kit := preload("res://scenes/motion/kit.gd")
## WHEELS, WINGS & BALLAST — thirteen movement styles, ported from the web
## lexicon (docs/locomotion.js). Vehicles and flight: a body that answers a
## throttle, a wheel, a stick — and the physics that answers back. Velocity
## split into forward and sideways (grip is what eats the sideways part);
## springs between wheels and chassis; a spring holding a hover height; the
## lean and bank a turn demands (a_lat = v²/R, ω = g·tan(bank)/v); a speed
## cap that boosts and decays; the OutRun road and the warp starfield, both
## one division by z; a ship with no up; a helicopter that must tilt to
## travel; a submarine trading ballast for buoyancy; a rider parented to a
## mount; and a train whose cars are its own history, read back at fixed
## spacing.

const TITLE := "Wheels, wings & ballast"
const BLURB := "vehicles and flight — drift, suspension, hover, lean, boost, a pseudo-3D road, warp stars, six degrees of freedom, mounts, trains"
const DEFS := [
	{ "id": "donuts", "letter": "D", "name": "Donuts", "drag": true,
		"hint": "split v into forward and sideways; GRIP eats the sideways part, the handbrake lowers grip so the slide lives — press: handbrake, drag: steer",
		"dials": { "accel": 0.5,        # throttle, ×W per second²
			"maxSpeed": 0.55,           # forward speed cap, ×W per second
			"grip": 5,                  # sideways velocity dies at this rate, per second — tyres holding
			"brakeGrip": 0.8,           # grip with the handbrake pulled: the slide barely dies
			"turn": 3.0,                # rad/s of heading at full speed and full lock
			"drag": 0.4,                # forward drag, per second
			"flip": 3.4,                # seconds per autopilot phase (the lock flips: a figure eight)
			"marks": 240,               # tyre-mark dots remembered
			"hold": 4,                  # seconds a press's steer and handbrake are respected
			"label": "v = vf·fwd + vl·side   ·   vl ×= e^(−grip·dt)" },
		"rhyme": { "name": "Dragrace", "hint": "grip 40 with or without the handbrake and a lazy lock — nothing slides, the car goes where the nose points: the grip car",
			"dials": { "grip": 40, "brakeGrip": 40, "turn": 0.9 } } },
	{ "id": "uphill", "letter": "U", "name": "Uphill", "drag": true,
		"hint": "two wheels on Damp's springs ride a noise hill; the chassis angle is read off the two spring heights (Normals) — drag: x = throttle",
		"dials": { "omega": 11, "zeta": 0.45,   # each spring: k = ω², c = 2ζω (Damp's dials)
			"wheelbase": 0.26,                  # axle to axle, ×W
			"rest": 0.08,                       # spring rest length, ×H
			"wheelR": 0.034,                    # wheel radius, ×H
			"amp1": 0.12, "amp2": 0.03,         # the hill's two noise octaves, ×H...
			"f1": 1.3, "f2": 4.4,               # ...and their frequencies, per W
			"accel": 0.55, "maxSpeed": 0.5, "drag": 0.5,   # throttle ×W/s²; cap ×W/s; rolling drag per second
			"g": 1.5,                           # gravity ×H/s², felt along the slope
			"hold": 4,                          # seconds your throttle lasts
			"label": "a = ω²(rest − x) − 2ζω·v   ·   θ = atan(Δh ÷ L)" },
		"rhyme": { "name": "Unsprung", "hint": "springs three times as stiff and lightly damped on a road twice as bumpy — every pebble reaches the driver",
			"dials": { "omega": 30, "zeta": 0.25, "amp2": 0.07 } } },
	{ "id": "hovercraft", "letter": "H", "name": "Hovercraft",
		"hint": "a spring holds the height; nothing holds x: it slides past the goal and leans into the fan fetching it back (Drone + Inertia) — press to thrust there",
		"dials": { "omega": 6, "zeta": 0.6,   # the height spring (Damp)
			"hover": 0.13,                    # ride height above the ground, ×H
			"thrust": 0.45,                   # the fan, ×W per second²
			"friction": 0.25,                 # horizontal decay per second — a skirt of air keeps almost nothing
			"lean": 0.9,                      # radians of tilt per (W/s²) of push
			"arrive": 2.2,                    # the pilot: wanted v = arrive · distance
			"maxSpeed": 0.5,                  # wanted-speed cap, ×W/s
			"bounce": 0.6,                    # restitution at the card's edges
			"wander": 4,                      # seconds between goals
			"label": "aᵧ = ω²(h₀ − h) − 2ζω·vᵧ   ·   vₓ ×= e^(−μ·dt)" },
		"rhyme": { "name": "Hoverpuck", "hint": "friction zero, lean zero, boards that give everything back — an air-hockey puck that never quite settles",
			"dials": { "friction": 0, "lean": 0, "bounce": 1 } } },
	{ "id": "lean", "letter": "L", "name": "Lean",
		"hint": "lean* = atan(v²/R ÷ g); the visible roll is a spring chasing lean*, so it dips late into a corner and sways out of it — press to set the corner radius",
		"dials": { "speed": 0.42,          # along the track, ×W per second
			"radius": 0.2,                 # corner radius, ×H
			"omega": 5, "zeta": 0.55,      # the roll spring (Damp)
			"g": 2.4,                      # gravity ×H/s² — the scale of a_lat
			"leanMax": 1.1,                # radians the body may lean
			"label": "a_lat = v²/R   ·   lean* = atan(a_lat ÷ g)   ·   roll → lean*" },
		"rhyme": { "name": "Lowrider", "hint": "a slow, soft roll spring — the body sways long after the corner and never quite catches up: a boat of a car",
			"dials": { "omega": 1.6, "zeta": 0.3, "speed": 0.36 } } },
	{ "id": "boost", "letter": "B", "name": "Boost",
		"hint": "a boost is an impulse plus a raised speed CAP that decays back; pads give small ones, nitro a big one (Dash + Kart) — press to fire nitro",
		"dials": { "base": 0.32,                     # the ordinary cap, ×W/s
			"accel": 0.5,                            # approach to the cap, ×W/s²
			"padKick": 0.12, "padBonus": 0.25,       # a pad: the impulse, and the cap raise, ×W/s
			"nitroKick": 0.2, "nitroBonus": 0.45,    # nitro: the same, bigger
			"decay": 1.1,                            # the bonus decays at this rate, per second
			"pads": 2,                               # pads on the lap
			"autoNitro": 6.5,                        # seconds between the autopilot's nitros
			"rx": 0.36, "ry": 0.27,                  # the loop, ×W and ×H
			"label": "cap = base + bonus   ·   bonus ×= e^(−k·dt)   ·   v → cap" },
		"rhyme": { "name": "Blastpad", "hint": "an enormous cap raise that decays almost at once — pure shove, the engine never gets to use the headroom",
			"dials": { "padBonus": 1.2, "nitroBonus": 1.5, "decay": 8 } } },
	{ "id": "road", "letter": "R", "name": "Road", "drag": true,
		"hint": "the OutRun trick: each row is a road slice at depth z, drawn W/z wide, bent by an accumulated curve and lifted by a hill, all ÷ z — drag: steer",
		"dials": { "segs": 44,                   # road slices from the bumper to the horizon
			"dz": 0.55,                          # depth per slice (the bumper is at z = 1)
			"camH": 1.0,                         # camera height above the road, in depth units
			"roadW": 1.0,                        # half the road width at the bumper, ×W
			"horizon": 0.42,                     # the horizon line, ×H
			"speed": 7,                          # depth units per second
			"curveK": 0.05, "curveF": 0.12,      # curvature strength, and how often the noise changes it
			"hillAmp": 2.5, "hillF": 0.06,       # hill height (depth units) and frequency
			"drift": 0.5,                        # how hard a curve throws the car outward
			"steerRate": 1.1,                    # road half-widths per second at full lock
			"posts": 4,                          # depth between roadside posts
			"palette": "sunset",                 # "sunset" or "rain"
			"hold": 4,                           # seconds your steering lasts
			"label": "row: x = X(z) ÷ z   ·   y = (h(z) − cam) ÷ z   ·   w = W ÷ z" },
		"rhyme": { "name": "Rainroad", "hint": "a night palette with rain, hills half again as tall and curves that bend nearly twice as hard — the same slices, a harder drive",
			"dials": { "palette": "rain", "hillAmp": 3.8, "curveK": 0.085 } } },
	{ "id": "perspective", "letter": "P", "name": "Perspective", "drag": true,
		"hint": "warp stars: each star is (x, y, z) and the screen sees x/z, y/z; as z shrinks it races outward — a streak joins last frame to this — drag: speed",
		"dials": { "n": 150,                   # stars alive at once
			"base": 0.25, "peak": 3.2,         # the slowest and fastest warp, depth units per second
			"ramp": "sine",                    # "sine" ramps up and down; "punch" jumps
			"period": 9,                       # seconds per ramp
			"focal": 0.5,                      # the lens, ×H (bigger = narrower view)
			"near": 0.03,                      # a star this close is respawned far away
			"streakMax": 0.35,                 # the longest streak drawn, ×W
			"hold": 4,                         # seconds your speed lasts
			"label": "sx = W/2 + x ÷ z · f      sy = H/2 + y ÷ z · f" },
		"rhyme": { "name": "Punchit", "hint": "no ramp: the warp steps from crawl to twice the peak in one frame, and streaks may run most of the screen",
			"dials": { "ramp": "punch", "peak": 6, "streakMax": 0.8 } } },
	{ "id": "zerog", "letter": "Z", "name": "Zerog", "drag": true,
		"hint": "thrust along the nose, spin with damping, no up, no drag: heading and velocity disagree until FLIGHT ASSIST kills the drift — press: assist, drag: aim",
		"dials": { "thrust": 0.45,         # ×W per second² along the nose
			"torque": 7,                   # the pilot's turn authority: rad/s² per radian of error
			"angDamp": 3,                  # spin damping, per second — the rcs the game gives you for free
			"assist": true,                # flight assist on at the start
			"assistK": 1.6,                # with assist: velocity off the nose decays at this rate
			"maxSpeed": 0.55,              # ×W/s
			"loopR": 0.3,                  # the autopilot's lazy loop, ×H
			"loopRate": 0.45,              # rad/s of the loop's target
			"hold": 5,                     # seconds your aim lasts
			"label": "v += nose·T·dt   ·   ω ×= e^(−c·dt)   ·   assist: v⊥ ×= e^(−k·dt)" },
		"rhyme": { "name": "Zerodrag", "hint": "assist off and no spin damping at all — the nose rings about every target and the ship slides sideways through its loop: pure Newton",
			"dials": { "assist": false, "angDamp": 0, "torque": 4 } } },
	{ "id": "quadcopter", "letter": "Q", "name": "Quadcopter",
		"hint": "a helicopter pushes only along its own up: it hovers on a height spring and must TILT to travel; the tilt lags the command (Drone) — press to send it",
		"dials": { "omega": 3, "zeta": 1,   # the height spring (Drone's, ζ = 1)
			"kp": 1.8, "kd": 1.5,           # the pilot: tilt command = kp·error − kd·speed (per W)
			"tiltMax": 0.7,                 # radians
			"tiltRate": 2.2,                # how fast the body reaches the commanded tilt, per second — the LAG
			"g": 2.4,                       # gravity ×H/s²: aₓ = g·tan(tilt)
			"wander": 3.5,                  # seconds between waypoints
			"label": "aₓ = g·tan(tilt)   ·   tilt → cmd at rate r   ·   aᵧ = ω²(tᵧ − y) − 2ζω·vᵧ" },
		"rhyme": { "name": "Quickdrone", "hint": "the body snaps to its command ten times faster and the pilot is twice as bold — the lag is gone and so is the overshoot",
			"dials": { "tiltRate": 25, "kp": 4, "kd": 2.8 } } },
	{ "id": "uboat", "letter": "U", "name": "Uboat",
		"hint": "buoyancy up, ballast down, dive planes pitching a slow hull: a pump floods or blows tanks to hold a depth (Upright + Yacht) — press to set the depth",
		"dials": { "speed": 0.1,           # forward, ×W/s — everything down here is slow
			"pumpRate": 0.35,              # ballast fill/blow rate, per second (0 = tanks blown, 1 = flooded)
			"g": 0.5,                      # (ballast − ½) · g · H is the net vertical push, px/s²
			"planeLift": 0.9,              # the dive planes: aᵧ += v · sin(pitch) · lift
			"planeRate": 0.8,              # how fast the pitch reaches its command, per second
			"pitchMax": 0.45,              # radians
			"drag": 1.4,                   # vertical water drag, per second
			"surface": 0.2,                # the sea's surface, ×H
			"wander": 8,                   # seconds between target depths
			"bubbles": 28,
			"label": "aᵧ = (ballast − ½)·g + v·sin(pitch)·lift − c·vᵧ" },
		"rhyme": { "name": "Ultraslow", "hint": "a pump at a quarter of the rate, planes that answer in seconds and half the way — a deep-sea crawl where every correction is late",
			"dials": { "pumpRate": 0.08, "planeRate": 0.25, "speed": 0.06 } } },
	{ "id": "yak", "letter": "Y", "name": "Yak",
		"hint": "the rider is the mount's child (Nest): mount + R(θ)·offset carries Gait's bob into the saddle; dismount keeps its velocity — press to hop off / on",
		"dials": { "speed": 0.22,          # the mount's walk, ×W/s
			"size": 0.1,                   # the mount's body height, ×H
			"bob": 0.035,                  # the gait bob, ×H
			"tilt": 0.08,                  # radians of body rock with the stride
			"offset": [0.05, -0.95],       # the saddle, in body sizes (x forward, y up)
			"hop": 0.22,                   # the dismount hop, ×H
			"g": 2.2,                      # gravity ×H/s²
			"rideFor": 4.5,                # seconds ridden before the autopilot hops off
			"label": "rider = mount + R(θ)·offset   ·   dismount: v = v_mount + hop" },
		"rhyme": { "name": "Yearling", "hint": "a small quick mount with a big bob — the rider bounces, and a hop off it lands far ahead",
			"dials": { "size": 0.065, "speed": 0.36, "bob": 0.06 } } },
	{ "id": "locomotive", "letter": "L", "name": "Locomotive",
		"hint": "the cars are the engine's own past: a ring buffer of where it was, read back at fixed spacing by arc length (Queue + Path) — press to couple a car",
		"dials": { "speed": 0.3,                   # ×W per second along the rail
			"spacing": 0.06,                       # coupling length between car centres, ×W
			"carLen": 0.042, "carW": 0.024,        # ×W
			"cars": 3,                             # cars behind the engine at the start
			"maxCars": 8,                          # the yard's limit — then it starts over
			"addEvery": 3,                         # seconds between the autopilot's couplings
			"lobes": 3, "wobble": 0.2,             # the rail: a loop with this many bulges, this deep
			"hist": 512,                           # history samples kept (a ring buffer)
			"label": "car k = history(s_engine − k · spacing)" },
		"rhyme": { "name": "Luggagetrain", "hint": "tiny cars coupled half as close, sixteen of them — the same buffer read sixteen times",
			"dials": { "spacing": 0.028, "carLen": 0.018, "maxCars": 16 } } },
	{ "id": "yoke", "letter": "Y", "name": "Yoke", "drag": true,
		"hint": "a coordinated turn: roll into a bank and the bank turns the heading, ω = g·tan(bank) ÷ v; pitch climbs (Yaw + Drone) — drag: x = bank, y = pitch",
		"dials": { "speed": 0.28,          # ×W/s over the ground
			"rollRate": 3,                 # how fast the wings reach the commanded bank, per second
			"bankMax": 0.95,               # radians of bank at full lock
			"pitchMax": 0.45,              # radians of pitch at full stick
			"g": 0.35,                     # gravity, in W/s² — sets how hard a bank turns
			"climb": 0.5,                  # screens of altitude per second at full pitch
			"wander": 4,                   # seconds per autopilot manoeuvre
			"hold": 4,                     # seconds your stick lasts
			"label": "ω = g·tan(bank) ÷ v   ·   bank → cmd at rollRate   ·   alt += v·sin(pitch)" },
		"rhyme": { "name": "Yellowbird", "hint": "rolls three times as fast, banks past 70° and turns on a wingtip — a stunt plane",
			"dials": { "rollRate": 10, "bankMax": 1.2, "g": 0.45 } } },
]

const FAINT := Color(0.91, 0.898, 0.957, 0.55)   # the web label's default ink
const EYE := Color(0.075, 0.063, 0.125)          # "#131020": the one attentive eye
const QUAD_WP := [[0.2, 0.3], [0.75, 0.25], [0.55, 0.6], [0.3, 0.55]]   # Quadcopter's waypoints, ×W and ×H

## A number for a label: "5" for whole values, "0.8" otherwise (JS's "" + k).
static func _num(v: float) -> String:
	return ("%d" % roundi(v)) if v == roundf(v) else ("%s" % v)

## The web label's "right" alignment: measure, then draw ending at p.x.
static func _label_right(n: CanvasItem, b: Dictionary, txt: String, p: Vector2, col: Color) -> void:
	var f := ThemeDB.fallback_font
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	Kit.label(n, b, txt, Vector2(p.x - w, p.y), col)

## ctx.save / translate / rotate (/ scale) — and ctx.restore.
static func _push(n: CanvasItem, b: Dictionary, p: Vector2, ang: float, sc: Vector2 = Vector2.ONE) -> void:
	n.draw_set_transform((b.rect as Rect2).position + p, ang, sc)

static func _pop(n: CanvasItem, b: Dictionary) -> void:
	n.draw_set_transform((b.rect as Rect2).position, 0.0, Vector2.ONE)

## ctx.ellipse, filled: a 24-gon.
static func _ellipse(n: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var an: float = i / 24.0 * TAU
		pts.append(c + Vector2(cos(an) * rx, sin(an) * ry))
	n.draw_colored_polygon(pts, col)

## A vertical spring drawn as the zigzag it is, from (x, y0) to (x, y1).
static func _spring(n: CanvasItem, x: float, y0: float, y1: float, segs: int, amp: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(x, y0))
	var dy: float = (y1 - y0) / segs
	for k in range(1, segs):
		pts.append(Vector2(x + (amp if k % 2 == 1 else -amp), y0 + dy * k))
	pts.append(Vector2(x, y1))
	n.draw_polyline(pts, col, w)

## The oval lap Lean and Boost share: two straights of 2·hs and two half
## circles of radius r. Distance along the lap → [x, y, heading, in-corner]
## (in-corner is +1 on the right bend, −1 on the left, 0 on the straights).
static func _oval(sd: float, cx: float, cy: float, hs: float, r: float) -> Array:
	var L: float = 4.0 * hs + TAU * r
	sd = fposmod(sd, L)
	if sd < 2.0 * hs:
		return [cx - hs + sd, cy - r, 0.0, 0.0]
	sd -= 2.0 * hs
	if sd < PI * r:
		var an: float = -PI / 2.0 + sd / r
		return [cx + hs + cos(an) * r, cy + sin(an) * r, an + PI / 2.0, 1.0]
	sd -= PI * r
	if sd < 2.0 * hs:
		return [cx + hs - sd, cy + r, PI, 0.0]
	sd -= 2.0 * hs
	var an2: float = PI / 2.0 + sd / r
	return [cx - hs + cos(an2) * r, cy + sin(an2) * r, an2 + PI / 2.0, -1.0]

## The whole lap as a closed polyline of count segments.
static func _oval_pts(cx: float, cy: float, hs: float, r: float, count: int) -> PackedVector2Array:
	var L: float = 4.0 * hs + TAU * r
	var out := PackedVector2Array()
	for i in count + 1:
		var P: Array = _oval(i / float(count) * L, cx, cy, hs, r)
		out.append(Vector2(P[0], P[1]))
	return out

## Uphill's road: the ground line minus two octaves of 1-D noise.
static func _terr(b: Dictionary, x: float) -> float:
	var D: Dictionary = b.D
	var amp1: float = D.amp1
	var amp2: float = D.amp2
	var f1: float = D.f1
	var f2: float = D.f2
	return b.gy - b.h * 0.06 - (Kit.noise(x / b.w * f1) * amp1 + Kit.noise(x / b.w * f2 + 7.3) * amp2) * b.h

## Boost's lap geometry: [cx, cy, hs, r, L].
static func _boost_geom(b: Dictionary) -> Array:
	var D: Dictionary = b.D
	var a: float = b.w * D.rx
	var bb: float = b.h * D.ry
	var r: float = minf(a, bb)
	var hs: float = maxf(0.0, a - r)
	return [b.w / 2.0, b.h * 0.52, hs, r, 4.0 * hs + TAU * r]

static func _nitro(b: Dictionary) -> void:
	var D: Dictionary = b.D
	b.v += D.nitroKick * b.w
	b.bonus = maxf(b.bonus, D.nitroBonus)
	b.flash = 0.5
	b.kind = "nitro"

## Road's palettes (the web's PAL table), as Colors.
static func _road_pal(which: String) -> Dictionary:
	if which == "rain":
		return { "sky0": Color("#0B0E1C"), "sky1": Color("#26304A"), "grass0": Color("#12201F"), "grass1": Color("#0F1A1A"),
			"road": Color("#1B1D2B"), "rumble0": Color("#8F98B0"), "rumble1": Color("#3E4660"), "line": Color("#8F98B0"), "rain": true }
	return { "sky0": Color("#2A1B4E"), "sky1": Color("#E0704A"), "grass0": Color("#1E4B3A"), "grass1": Color("#1A4233"),
		"road": Color("#3A3550"), "rumble0": Color("#F5E8E0"), "rumble1": Color("#C8506A"), "line": Color("#F5E8E0"), "rain": false }

static func _kappa(D: Dictionary, d: float) -> float:
	var ck: float = D.curveK
	var cf: float = D.curveF
	return Kit.noise(d * cf) * ck

static func _hill(D: Dictionary, d: float) -> float:
	var hf: float = D.hillF
	var ha: float = D.hillAmp
	return (sin(d * hf) * 0.65 + sin(d * hf * 2.3 + 1.7) * 0.35) * ha

## Road: project every slice — y ÷ z, x ÷ z, w ÷ z, with the curve accumulating.
static func _road_project(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var N: int = D.segs
	var dz: float = D.dz
	var camH: float = D.camH
	var roadW: float = D.roadW
	var cy: float = b.h * D.horizon
	var f: float = b.h - cy
	var pos: float = b.pos
	var hp: float = b.hp
	var carX: float = b.carX
	var SY: Array[float] = b.SY
	var SX: Array[float] = b.SX
	var SW: Array[float] = b.SW
	var X := 0.0
	var S := 0.0
	for k in N + 1:
		var z: float = 1.0 + k * dz
		var d: float = pos + k * dz
		if k > 0:                                    # ← the curve accumulates
			S += _kappa(D, d) * dz
			X += S * dz
		SY[k] = cy + (camH - (_hill(D, d) - hp)) * f / z   # ← y ÷ z
		SX[k] = b.w / 2.0 + (X - carX * roadW) * b.w / z   # ← x ÷ z
		SW[k] = roadW * b.w / z                            # ← w ÷ z

## Perspective: a star reborn at depth z, its "last drawn" spot set so the
## first frame draws no streak.
static func _spawn(b: Dictionary, i: int, z: float) -> void:
	var D: Dictionary = b.D
	var gen: RandomNumberGenerator = b.gen
	var X: Array[float] = b.X
	var Y: Array[float] = b.Y
	var Z: Array[float] = b.Z
	var LX: Array[float] = b.LX
	var LY: Array[float] = b.LY
	X[i] = gen.randf() * 2.0 - 1.0
	Y[i] = gen.randf() * 2.0 - 1.0
	Z[i] = z
	var f: float = b.h * D.focal
	LX[i] = b.w / 2.0 + X[i] / z * f
	LY[i] = b.h / 2.0 + Y[i] / z * f

## Yak: un-parent the rider — it keeps the mount's velocity plus a hop.
static func _dismount(b: Dictionary) -> void:
	var D: Dictionary = b.D
	b.mode = "air"
	b.rvx = b.dir * b.w * D.speed
	b.rvy = -sqrt(2.0 * b.h * D.g * b.h * D.hop)
	b.rideT = 0.0

## Locomotive's rail: a loop with lobes bulges.
static func _rail(b: Dictionary, a: float) -> Vector2:
	var D: Dictionary = b.D
	var wob: float = D.wobble
	var lobes: float = D.lobes
	var rr: float = 1.0 + wob * sin(lobes * a)
	return Vector2(b.w / 2.0 + cos(a) * b.w * 0.4 * rr, b.h * 0.5 + sin(a) * b.h * 0.34 * rr)

## Locomotive: advance the engine along the rail at constant speed and
## write where it is (and its arc length) into the ring buffer.
static func _loco_step(b: Dictionary, dt: float) -> void:
	var D: Dictionary = b.D
	var NH: int = D.hist
	var HX: Array[float] = b.HX
	var HY: Array[float] = b.HY
	var HS: Array[float] = b.HS
	var p0 := _rail(b, b.ang)
	var p1 := _rail(b, b.ang + 1e-3)
	var dd: float = maxf(1e-3, p0.distance_to(p1) / 1e-3)   # |dP/da|
	b.ang += b.w * D.speed * dt / dd
	var p := _rail(b, b.ang)
	b.sEng += p0.distance_to(p)
	var hi: int = b.hi
	HX[hi] = p.x                                     # ← write the past
	HY[hi] = p.y
	HS[hi] = b.sEng
	b.hi = (hi + 1) % NH
	if b.hn < NH:
		b.hn += 1

## Locomotive: the past, read at an arc length — walk back from sample
## `from` until the history is behind sWant, then interpolate between the
## two samples either side. Returns [x, y, heading, the sample index reached].
static func _read_back(b: Dictionary, sWant: float, from: int) -> Array:
	var D: Dictionary = b.D
	var NH: int = D.hist
	var hn: int = b.hn
	var HX: Array[float] = b.HX
	var HY: Array[float] = b.HY
	var HS: Array[float] = b.HS
	var j: int = from
	for _nn in hn - 1:
		var jq: int = posmod(j - 1, NH)
		if HS[jq] <= sWant:
			break
		j = jq
	var jp: int = posmod(j - 1, NH)
	var s1: float = HS[jp]
	var s2: float = HS[j]
	var k: float = clampf((sWant - s1) / (s2 - s1), 0.0, 1.0) if s2 > s1 else 1.0
	return [HX[jp] + (HX[j] - HX[jp]) * k, HY[jp] + (HY[j] - HY[jp]) * k,
		atan2(HY[j] - HY[jp], HX[j] - HX[jp]), j]

static func _car(n: CanvasItem, b: Dictionary, p: Vector2, hd: float, ln: float, wd: float, col: Color) -> void:
	_push(n, b, p, hd)
	Kit.rect(n, Rect2(-ln / 2.0, -wd / 2.0, ln, wd), col)
	_pop(n, b)

## Yoke's plane, seen from above: wings and tail foreshorten with the bank.
static func _plane(n: CanvasItem, b: Dictionary, p: Vector2, hd: float, bank: float, col: Color, sc: float) -> void:
	var origin: Vector2 = (b.rect as Rect2).position
	var base := Transform2D(hd, origin + p).scaled_local(Vector2(sc, sc))
	var fore: float = maxf(0.15, cos(bank))
	n.draw_set_transform_matrix(base.scaled_local(Vector2(1.0, fore)))
	n.draw_colored_polygon(PackedVector2Array([Vector2(2, -18), Vector2(6, -18), Vector2(4, 18), Vector2(0, 18)]), col)
	n.draw_set_transform_matrix(base)
	n.draw_colored_polygon(PackedVector2Array([Vector2(14, 0), Vector2(-10, -3), Vector2(-12, 0), Vector2(-10, 3)]), col)
	n.draw_set_transform_matrix(base.scaled_local(Vector2(1.0, fore)))
	n.draw_colored_polygon(PackedVector2Array([Vector2(-10, -6), Vector2(-8, -6), Vector2(-10, 6), Vector2(-12, 6)]), col)
	_pop(n, b)

static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"donuts":
			# Vehicle steered by geometry and never slid. a DRIFT model splits the
			# velocity into a FORWARD part (along the nose) and a SIDEWAYS part and
			# treats them differently: the forward part is driven and dragged, the
			# sideways part is eaten by GRIP — an exponential decay, quick on tarmac.
			# the HANDBRAKE simply lowers grip, so a turn with the brake pulled keeps
			# its sideways velocity: the nose turns, the car keeps going where it was
			# going — a donut. COUNTERSTEER is steering against the slide to catch it.
			b.x = W * 0.5
			b.y = H * 0.5
			b.hd = 0.0
			b.vx = 0.0
			b.vy = 0.0
			b.steer = 1.0
			b.dir = 1.0
			b.brake = false
			b.autoT = 0.0
			b.manualT = 0.0
			b.brakeT = 0.0
			b.clock = 0.0
			b.lastPress = -9.0
			b.vf = 0.0
			b.vl = 0.0
			b.counter = false
			b.st = 1.0
			b.gripNow = float(D.grip)
			var marks: int = D.marks
			var mk: Array[Vector2] = []
			mk.resize(marks)
			b.mk = mk                                    # tyre marks: a ring of (x, y)
			b.mi = 0
			b.mn = 0
		"uphill":
			# SUSPENSION is Damp's spring twice: each wheel sits on the road, and the
			# chassis mount above it is pulled toward a point one REST LENGTH up with
			# stiffness ω² and damping 2ζω. the body never touches the road — it only
			# knows its two spring lengths — and its ANGLE is the atan of their
			# difference over the wheelbase (Normals: the surface says which way is
			# up, here by way of two samples). gravity along the slope, g·sin(θ),
			# fights the throttle on every climb — the Hill Climb feel in one line.
			var L: float = W * D.wheelbase
			var R: float = H * D.wheelR
			var REST: float = H * D.rest
			b.wx = 0.0
			b.v = 0.0
			b.throttle = 0.8
			b.holdT = 0.0
			b.spin = 0.0
			b.m = [{ "y": _terr(b, -L / 2.0) - R - REST, "vy": 0.0 },   # the two chassis mounts
				{ "y": _terr(b, L / 2.0) - R - REST, "vy": 0.0 }]
			b.wy = [_terr(b, -L / 2.0) - R, _terr(b, L / 2.0) - R]
			b.th = 0.0
		"hovercraft":
			# Drone held x AND height with springs. a HOVERCRAFT holds only its
			# height — the cushion is a spring under the skirt — and sideways it is
			# Inertia on ice: the fan pushes, a tiny friction μ takes almost nothing
			# back, so it sails past the goal and must thrust the other way. the lean
			# is read off the push, as Drone's was. the pilot is Arrive with a fan:
			# wanted velocity = arrive · distance, push toward the difference.
			b.x = W * 0.3
			b.y = GY - H * 0.13
			b.vx = 0.0
			b.vy = 0.0
			b.tx = W * 0.7
			b.timer = 0.0
			b.push = 0.0
			b.tilt = 0.0
		"lean":
			# BODY ROLL is presentation derived from physics: a corner of radius R at
			# speed v demands a centripetal acceleration a_lat = v²/R, and a bike (or
			# a car's body on its springs) LEANS by atan(a_lat/g) to line its weight
			# up with the sum. the target lean switches on at the corner's entry and
			# off at its exit; the visible roll is Damp's spring chasing that target
			# — so it dips late going in and sways back going out. Drone read tilt
			# off acceleration the same way; here the acceleration is the track's.
			var a: float = W * 0.27
			b.s = 0.0
			b.roll = 0.0
			b.rollV = 0.0
			b.r = clampf(D.radius * H, H * 0.07, minf(a, H * 0.34))
			b.px = W * 0.4 - (a - b.r)
			b.py = H * 0.52 - b.r
			b.phd = 0.0
			b.inC = 0.0
			b.aLat = 0.0
			b.want = 0.0
		"boost":
			# Dash was an impulse that decayed. a BOOST is that plus a second trick:
			# the SPEED CAP itself is raised, and the raise decays back with the
			# same e^(−k·dt) — so the kart does not merely get a shove, it is briefly
			# ALLOWED to be faster, and the engine (which always approaches the cap)
			# keeps it there until the cap sinks under it. the gauge shows both: the
			# amber cap sliding up and back, the blue speed chasing it.
			b.s = 0.0
			b.v = 0.0
			b.bonus = 0.0
			b.timer = 0.0
			b.flash = 0.0
			b.kind = ""
			b.cap = D.base * W
		"road":
			# no 3D anywhere: the road is a stack of horizontal SLICES, each one a
			# little further down the z axis. a slice at depth z is drawn 1/z as
			# wide and 1/z as far below the horizon as the one at the bumper — that
			# one division is the whole perspective (Perspective's stars use the same
			# one). a CURVE is a lateral offset that ACCUMULATES slice by slice (the
			# road bends away, the car never turns); a HILL is a height h(z) that
			# moves each slice's y — drawn far to near, so a crest hides what is
			# behind it. steering moves the road under a car that stays put.
			var N: int = D.segs
			b.pos = 0.0
			b.carX = 0.0
			b.steer = 0.0
			b.manualT = 0.0
			b.speed = 0.0
			b.k0 = 0.0
			b.hp = 0.0
			b.off = false
			var sy: Array[float] = []
			sy.resize(N + 1)
			var sx: Array[float] = []
			sx.resize(N + 1)
			var sw: Array[float] = []
			sw.resize(N + 1)
			b.SY = sy
			b.SX = sx
			b.SW = sw
			b.pal = _road_pal(D.palette)
			_road_project(b)
		"perspective":
			# PERSPECTIVE is one division. a star at (x, y, z) lands on the screen at
			# x/z, y/z (times a focal length): far stars huddle near the centre, near
			# stars fly to the edges, and moving the camera forward is just z −= v·dt
			# for everyone. the STREAK is honest motion blur — a line from where the
			# star was drawn last frame to where it is now — so it grows with speed
			# and with nearness, by itself. the same 1/z draws Road's slices.
			var nn: int = D.n
			for key in ["X", "Y", "Z", "LX", "LY", "PX", "PY"]:
				var arr: Array[float] = []
				arr.resize(nn)
				b[key] = arr
			var alive: Array[int] = []
			alive.resize(nn)
			b.alive = alive
			b.gen = Kit.rng(3)
			var gen: RandomNumberGenerator = b.gen
			for i in nn:
				_spawn(b, i, gen.randf() * 0.95 + 0.05)
			b.speed = float(D.base)
			b.manualT = 0.0
			b.manualSpeed = 0.0
		"zerog":
			# Asteroids in full: a ship with no up, no floor and no air. thrust only
			# ever adds along the NOSE; the heading turns by an angular velocity ω
			# that torque changes and a little damping bleeds (the pilot here only
			# pushes toward the error — without that damping the nose rings for ever).
			# so heading and velocity disagree: the amber arrow is where you are
			# GOING, the blue nose where you are POINTING. FLIGHT ASSIST is one extra
			# line: decay the part of v that is not along the nose, and the ship
			# flies like a car again — the difference between Elite and Everspace.
			b.x = W * 0.3
			b.y = H * 0.5
			b.vx = 0.0
			b.vy = 0.0
			b.hd = 0.0
			b.om = 0.0
			b.assist = bool(D.assist)
			b.tx = 0.0
			b.ty = 0.0
			b.manualT = 0.0
			b.clock = 0.0
			b.lastPress = -9.0
			b.burning = false
			b.drift = 0.0
			b.sp = 0.0
			var trail: Array[Vector2] = []
			trail.resize(60)
			b.trail = trail
			b.ti = 0
			b.tn = 0
		"quadcopter":
			# Drone READ its tilt off the acceleration a spring asked for. a real
			# helicopter is the other way round: the rotor can only push along the
			# body's up, so the pilot must TILT first, and the horizontal acceleration
			# FOLLOWS — aₓ = g·tan(tilt), because the thrust must still hold the
			# weight. two lags stack: the body reaches the commanded tilt at a finite
			# rate, and the tilt takes time to become speed — that is why a chopper
			# overshoots and settles, where Drone snapped. height is the same spring.
			var wp1: Array = QUAD_WP[1]
			b.x = W * 0.2
			b.y = H * 0.3
			b.vx = 0.0
			b.vy = 0.0
			b.tilt = 0.0
			b.cmd = 0.0
			b.spin = 0.0
			b.wi = 0
			b.timer = 0.0
			b.holdT = 0.0
			b.tx = W * float(wp1[0])
			b.ty = H * float(wp1[1])
			b.ax = 0.0
			b.thr = H * D.g
		"uboat":
			# a SUBMARINE has two ways down. BALLAST: flood the tanks and the weight
			# beats the buoyancy (the water it displaces, which never changes); blow
			# them and it rises — slow, because a pump is slow. DIVE PLANES: little
			# wings at the tail that pitch the hull (Upright's spring-on-an-angle,
			# commanded), so forward speed leaks into vertical speed by v·sin(pitch).
			# heavy water drag makes every answer late, so the pump aims by depth
			# error AND vertical speed, or it would overshoot for ever. the surface is
			# Yacht's wave; depth is read off a gauge, as on the real thing.
			var SURF: float = H * D.surface
			var nb: int = D.bubbles
			b.x = W * 0.3
			b.y = H * 0.5
			b.vy = 0.0
			b.ballast = 0.5
			b.pitch = 0.0
			b.ty = H * 0.65
			b.timer = 0.0
			b.aB = 0.0
			var BX: Array[float] = []
			var BY: Array[float] = []
			var BR: Array[float] = []
			for _i in nb:
				BX.append(randf_range(0.0, W))
				BY.append(randf_range(SURF, H))
				BR.append(randf_range(0.8, 2.0))
			b.BX = BX
			b.BY = BY
			b.BR = BR
		"yak":
			# a MOUNT is a parent frame (Nest): the rider stores one local OFFSET —
			# the saddle — and every frame is placed at mount + rotate(offset, θ),
			# so the mount's gait BOB and stride rock (Gait, Hover's derivative
			# lean) reach the rider without a line of rider code. DISMOUNT is the
			# un-parenting: the rider becomes a body of its own, and the honest part
			# is that it keeps the mount's velocity plus a hop — nobody stops dead in
			# mid-air. mounting is the reverse: close enough to the saddle, re-parent.
			b.mx = W * 0.3
			b.dir = 1.0
			b.phase = 0.0
			b.mode = "ride"
			b.rx = 0.0
			b.ry = 0.0
			b.rvx = 0.0
			b.rvy = 0.0
			b.rideT = 0.0
			b.sx = 0.0
			b.sy = 0.0
			b.by = 0.0
			b.th = 0.0
			b.bob = 0.0
		"locomotive":
			# Queue's leader-following, done by DISTANCE instead of by frames: the
			# engine writes its position and its arc length s into a RING BUFFER
			# every frame; car k is wherever the engine was when its s was exactly
			# k·spacing less — found by walking back through the buffer and
			# interpolating between two samples. the couplings are thereby distance
			# constraints for free, they never stretch or bunch however the speed
			# changes, and a winding rail costs nothing: the cars follow the path
			# because the engine did.
			var NH: int = D.hist
			for key in ["HX", "HY", "HS"]:
				var arr: Array[float] = []
				arr.resize(NH)
				b[key] = arr
			b.hi = 0
			b.hn = 0
			b.ang = 0.0
			b.sEng = 0.0
			b.cars = int(D.cars)
			b.timer = 0.0
			b.rest = 0
			for _i in 400:                               # a history to start with
				_loco_step(b, 1.0 / 60.0)
		"yoke":
			# an aircraft does not turn with a rudder. it ROLLS into a BANK, and the
			# tilted lift now has a sideways part that swings the heading round at
			# ω = g·tan(bank) ÷ v — the COORDINATED TURN (Lean's a_lat = v²/R read
			# backward: the bank chooses the radius). so a fast plane needs more
			# bank for the same turn, and the roll itself takes time (rollRate), which
			# is the whole hand-feel of a flight game. pitch trades speed for height:
			# alt += v·sin(pitch). the inset is the attitude indicator: the horizon
			# as the plane sees it — rolled by the bank, dropped by the pitch.
			b.x = W * 0.3
			b.y = H * 0.55
			b.hd = -0.4
			b.bank = 0.0
			b.pitch = 0.0
			b.alt = 0.5
			b.bankCmd = 0.6
			b.pitchCmd = 0.0
			b.timer = 0.0
			b.manualT = 0.0
			b.om = 0.0
			var trail: Array[Vector2] = []
			trail.resize(80)
			b.trail = trail
			b.ti = 0
			b.tn = 0

static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	match b.id:
		"donuts":
			if b.clock - b.lastPress > 0.3:              # a fresh press pulls or drops the handbrake
				b.brake = not b.brake
				b.brakeT = float(D.hold)
			b.lastPress = b.clock
			b.steer = clampf((pos.x / W - 0.5) * 2.5, -1.0, 1.0)   # ...and a held one steers
			b.manualT = float(D.hold)
		"uphill":
			b.throttle = clampf((pos.x / W - 0.15) / 0.7, 0.0, 1.0)
			b.holdT = float(D.hold)
		"hovercraft":
			b.tx = clampf(pos.x, W * 0.08, W * 0.92)
			b.timer = -6.0
		"lean":
			var a: float = W * 0.27
			b.r = clampf(absf(pos.y - H * 0.52), H * 0.07, minf(a, H * 0.34))
		"boost":
			_nitro(b)
			b.timer = 0.0
		"road":
			b.steer = clampf((pos.x / W - 0.5) * 2.4, -1.0, 1.0)
			b.manualT = float(D.hold)
		"perspective":
			b.manualSpeed = lerpf(D.base, D.peak, clampf(pos.x / W, 0.0, 1.0))
			b.manualT = float(D.hold)
		"zerog":
			if b.clock - b.lastPress > 0.3:              # a fresh press flips the assist
				b.assist = not b.assist
			b.lastPress = b.clock
			b.tx = pos.x                                 # a held one aims
			b.ty = pos.y
			b.manualT = float(D.hold)
		"quadcopter":
			b.tx = clampf(pos.x, W * 0.08, W * 0.92)
			b.ty = clampf(pos.y, H * 0.1, b.gy - H * 0.12)
			b.holdT = 6.0
		"uboat":
			var SURF: float = H * D.surface
			b.ty = clampf(pos.y, SURF + H * 0.1, H - 22.0)
			b.timer = -8.0
		"yak":
			var S: float = H * D.size
			if b.mode == "ride":
				_dismount(b)
			elif b.mode == "ground" and absf(b.mx - b.rx) < S * 2.2:
				b.mode = "air"
				b.rvx = (b.sx - b.rx) * 3.0
				b.rvy = -sqrt(2.0 * H * D.g * H * D.hop)
		"locomotive":
			if b.cars < D.maxCars:
				b.cars += 1
			b.timer = 0.0
		"yoke":
			b.bankCmd = clampf((pos.x / W - 0.5) * 2.4, -1.0, 1.0)
			b.pitchCmd = clampf((0.5 - pos.y / H) * 2.4, -1.0, 1.0)
			b.manualT = float(D.hold)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"donuts":
			b.clock += dt
			if b.manualT > 0.0:
				b.manualT -= dt
			else:                                        # the autopilot: full lock, flipping sides
				b.autoT += dt
				if b.autoT > D.flip:
					b.autoT = 0.0
					b.dir = -b.dir
				b.steer = b.dir
			if b.brakeT > 0.0:
				b.brakeT -= dt
			else:
				b.brake = b.autoT < D.flip * 0.72        # handbrake for most of a phase, released to cross over
			var brake: bool = b.brake
			var hd: float = b.hd
			var fx := cos(hd)
			var fy := sin(hd)
			var sx := -fy
			var sy := fx
			var vx: float = b.vx
			var vy: float = b.vy
			var vf: float = vx * fx + vy * fy            # ← the split
			var vl: float = vx * sx + vy * sy
			var cap: float = W * D.maxSpeed
			if not brake:
				vf += W * D.accel * dt
			vf *= exp(-D.drag * dt)
			if vf > cap:
				vf = cap
			var g: float = D.brakeGrip if brake else D.grip
			vl *= exp(-g * dt)                           # ← grip: the sideways part decays
			var counter: bool = b.manualT <= 0.0 and not brake and absf(vl) > W * 0.08
			var st: float = -signf(vl) if counter else b.steer   # countersteer: lock against the slide
			hd += st * D.turn * clampf(vf / cap, -1.0, 1.0) * dt
			vx = vf * fx + vl * sx                       # recompose in the OLD basis; the new heading finds a new split
			vy = vf * fy + vl * sy
			var x: float = b.x + vx * dt
			var y: float = b.y + vy * dt
			if x < -16.0:
				x = W + 16.0
			if x > W + 16.0:
				x = -16.0
			if y < -16.0:
				y = H + 16.0
			if y > H + 16.0:
				y = -16.0
			if absf(vl) > W * 0.05:                      # the rear tyres write on the tarmac
				var marks: int = D.marks
				var mk: Array[Vector2] = b.mk
				var mi: int = b.mi
				for sgn: float in [-1.0, 1.0]:
					mk[mi] = Vector2(x - fx * 7.0 + sx * sgn * 5.0, y - fy * 7.0 + sy * sgn * 5.0)
					mi = (mi + 1) % marks
					if b.mn < marks:
						b.mn += 1
				b.mi = mi
			b.x = x
			b.y = y
			b.hd = hd
			b.vx = vx
			b.vy = vy
			b.vf = vf
			b.vl = vl
			b.counter = counter
			b.st = st
			b.gripNow = g
		"uphill":
			var L: float = W * D.wheelbase
			var R: float = H * D.wheelR
			var REST: float = H * D.rest
			if b.holdT > 0.0:
				b.holdT -= dt
			else:
				b.throttle = clampf(0.75 + Kit.noise(t * 0.3 + 40.0) * 0.4, 0.0, 1.0)
			var wx: float = b.wx
			var v: float = b.v
			var throttle: float = b.throttle
			var slope: float = (_terr(b, wx + 6.0) - _terr(b, wx - 6.0)) / 12.0   # dy/dx: positive = downhill to the right
			var sinT: float = slope / sqrt(1.0 + slope * slope)
			var a: float = throttle * D.accel * W + sinT * D.g * H - D.drag * v   # throttle, gravity along the slope, drag
			v = clampf(v + a * dt, -W * D.maxSpeed, W * D.maxSpeed)
			wx += v * dt
			b.spin += v / R * dt                         # Motor: ω = v ÷ r
			var w: float = D.omega
			var zeta: float = D.zeta
			var nsub: int = maxi(1, ceili(dt / 0.012))
			var hdt: float = dt / nsub
			var wy: Array = [_terr(b, wx - L / 2.0) - R, _terr(b, wx + L / 2.0) - R]   # wheel centres: on the road
			var m: Array = b.m
			for _k in nsub:
				for i in 2:
					var mm: Dictionary = m[i]
					var wyi: float = wy[i]
					var target: float = wyi - REST
					mm.vy += (w * w * (target - mm.y) - 2.0 * zeta * w * mm.vy) * hdt   # ← Damp, per wheel
					mm.y += mm.vy * hdt
					if mm.y > wyi - R * 0.5:             # bottomed out
						mm.y = wyi - R * 0.5
						if mm.vy > 0.0:
							mm.vy = 0.0
					if mm.y < wyi - REST * 2.2:          # topped out
						mm.y = wyi - REST * 2.2
						if mm.vy < 0.0:
							mm.vy = 0.0
			var m0: Dictionary = m[0]
			var m1: Dictionary = m[1]
			b.wx = wx
			b.v = v
			b.wy = wy
			b.th = atan2(float(m1.y) - float(m0.y), L)   # ← the chassis angle, from two heights
		"hovercraft":
			b.timer += dt
			if b.timer > D.wander:
				b.timer = 0.0
				b.tx = randf_range(W * 0.1, W * 0.9)
			var x: float = b.x
			var y: float = b.y
			var vx: float = b.vx
			var vy: float = b.vy
			var cap: float = W * D.maxSpeed
			var wantV: float = clampf((b.tx - x) * D.arrive, -cap, cap)
			var push: float = clampf((wantV - vx) * 4.0, -W * D.thrust, W * D.thrust)   # the fan: toward the wanted velocity, capped
			vx += push * dt
			vx *= exp(-D.friction * dt)                  # ← μ: the skirt barely holds
			var w: float = D.omega
			var h0: float = GY - H * D.hover
			vy += (w * w * (h0 - y) - 2.0 * D.zeta * w * vy) * dt   # ← the cushion: Damp's spring
			vy = clampf(vy, -H * 2.0, H * 2.0)
			x += vx * dt
			y += vy * dt
			if x < 18.0:                                 # the boards
				x = 18.0
				vx = absf(vx) * D.bounce
			if x > W - 18.0:
				x = W - 18.0
				vx = -absf(vx) * D.bounce
			if y > GY - 6.0:
				y = GY - 6.0
				vy = -absf(vy) * 0.3
			b.tilt += (clampf(push / W * D.lean, -0.5, 0.5) - b.tilt) * minf(1.0, 6.0 * dt)
			b.x = x
			b.y = y
			b.vx = vx
			b.vy = vy
			b.push = push
		"lean":
			var cx: float = W * 0.4
			var cy: float = H * 0.52
			var a: float = W * 0.27
			var r: float = b.r
			var v: float = W * D.speed
			var g: float = H * D.g
			b.s += v * dt
			var P: Array = _oval(b.s, cx, cy, a - r, r)
			var inC: float = P[3]
			var aLat: float = v * v / r if inC != 0.0 else 0.0   # ← v²/R, only in the corners
			var want: float = clampf(atan(aLat / g), 0.0, D.leanMax)   # ← the lean the physics asks for
			var w: float = D.omega
			b.rollV += (w * w * (want - b.roll) - 2.0 * D.zeta * w * b.rollV) * dt   # the roll spring chases it
			b.roll += b.rollV * dt
			b.px = P[0]
			b.py = P[1]
			b.phd = P[2]
			b.inC = inC
			b.aLat = aLat
			b.want = want
		"boost":
			var G: Array = _boost_geom(b)
			var L: float = G[4]
			b.timer += dt
			if b.timer > D.autoNitro:
				b.timer = randf_range(0.0, 1.5)
				_nitro(b)
			b.bonus *= exp(-D.decay * dt)                # ← the raise decays
			var cap: float = (D.base + b.bonus) * W      # ← the cap, right now
			var v: float = b.v
			if v < cap:
				v = minf(cap, v + D.accel * W * dt)      # the engine approaches it
			else:
				v += (cap - v) * minf(1.0, 2.5 * dt)     # ...and above it, engine braking eases back
			var s0: float = b.s
			var s: float = s0 + v * dt
			var pads: int = D.pads
			for i in pads:                               # did we cross a pad this frame?
				var ps: float = L * (i + 0.5) / pads
				if fposmod(ps - s0, L) < s - s0:
					v += D.padKick * W
					b.bonus = maxf(b.bonus, D.padBonus)
					b.flash = 0.4
					b.kind = "pad"
			b.flash = maxf(0.0, b.flash - dt)
			b.v = v
			b.s = s
			b.cap = cap
		"road":
			var off: bool = absf(b.carX) > 1.05
			var dspeed: float = D.speed
			b.speed += (dspeed * (0.45 if off else 1.0) - b.speed) * minf(1.0, 1.5 * dt)
			b.pos += b.speed * dt
			var pos: float = b.pos
			var k0: float = _kappa(D, pos)
			var hp: float = _hill(D, pos)
			b.carX -= k0 * b.speed * D.drift * 6.0 * dt  # the curve throws the car outward
			if b.manualT > 0.0:
				b.manualT -= dt
			else:
				b.steer = clampf(-b.carX * 2.5, -1.0, 1.0)   # the autopilot aims for the middle, late
			b.carX = clampf(b.carX + b.steer * D.steerRate * dt, -1.6, 1.6)
			b.k0 = k0
			b.hp = hp
			b.off = off
			_road_project(b)                             # project every slice
		"perspective":
			if b.manualT > 0.0:
				b.manualT -= dt
				b.speed += (b.manualSpeed - b.speed) * minf(1.0, 4.0 * dt)
			else:
				var period: float = D.period
				var ph: float = fposmod(t, period) / period
				var k: float = (0.0 if ph < 0.5 else 1.0) if D.ramp == "punch" else 0.5 - 0.5 * cos(ph * TAU)
				b.speed = D.base + (D.peak - D.base) * k
			var nn: int = D.n
			var f: float = H * D.focal
			var near: float = D.near
			var speed: float = b.speed
			var X: Array[float] = b.X
			var Y: Array[float] = b.Y
			var Z: Array[float] = b.Z
			var LX: Array[float] = b.LX
			var LY: Array[float] = b.LY
			var PX: Array[float] = b.PX
			var PY: Array[float] = b.PY
			var alive: Array[int] = b.alive
			for i in nn:
				Z[i] -= speed * dt                       # ← the camera moves forward: every z shrinks
				if Z[i] < near:
					_spawn(b, i, 1.0)
					alive[i] = 0
					continue
				var z: float = Z[i]
				var sx: float = W / 2.0 + X[i] / z * f   # ← the division
				var sy: float = H / 2.0 + Y[i] / z * f
				if sx < -20.0 or sx > W + 20.0 or sy < -20.0 or sy > H + 20.0:
					_spawn(b, i, 1.0)
					alive[i] = 0
					continue
				PX[i] = LX[i]                            # where it was drawn last tick...
				PY[i] = LY[i]
				LX[i] = sx                               # ...and where it is now: the streak
				LY[i] = sy
				alive[i] = 1
		"zerog":
			b.clock += dt
			var cx: float = W / 2.0
			var cy: float = H * 0.5
			if b.manualT > 0.0:
				b.manualT -= dt
			else:
				b.tx = cx + cos(t * D.loopRate) * H * D.loopR * 1.4
				b.ty = cy + sin(t * D.loopRate) * H * D.loopR
			var cap: float = W * D.maxSpeed
			var x: float = b.x
			var y: float = b.y
			var vx: float = b.vx
			var vy: float = b.vy
			var hd: float = b.hd
			var om: float = b.om
			var dv := Vector2((b.tx - x) * 1.5, (b.ty - y) * 1.5)   # the wanted velocity (Arrive)
			if dv.length() > cap:
				dv = dv.normalized() * cap
			var ev := dv - Vector2(vx, vy)
			var es: float = ev.length()
			var want: float = atan2(ev.y, ev.x) if es > 4.0 else hd
			var err: float = wrapf(want - hd, -PI, PI)
			om += D.torque * err * dt                    # the pilot: torque toward the error
			om *= exp(-D.angDamp * dt)                   # ← the game's spin damping
			hd += om * dt
			var burning: bool = es > 8.0 and absf(err) < 0.5
			var nx := cos(hd)
			var ny := sin(hd)
			if burning:                                  # ← thrust, along the nose only
				vx += nx * W * D.thrust * dt
				vy += ny * W * D.thrust * dt
			if b.assist:                                 # ← flight assist: kill the sideways part
				var along: float = vx * nx + vy * ny
				var pxv: float = vx - along * nx
				var pyv: float = vy - along * ny
				var k: float = exp(-D.assistK * dt)
				vx = along * nx + pxv * k
				vy = along * ny + pyv * k
			var sp: float = Vector2(vx, vy).length()
			if sp > cap:
				vx *= cap / sp
				vy *= cap / sp
				sp = cap
			x += vx * dt
			y += vy * dt
			if x < -12.0:
				x = W + 12.0
			if x > W + 12.0:
				x = -12.0
			if y < -12.0:
				y = H + 12.0
			if y > H + 12.0:
				y = -12.0
			var trail: Array[Vector2] = b.trail
			var ti: int = b.ti
			trail[ti] = Vector2(x, y)
			b.ti = (ti + 1) % 60
			if b.tn < 60:
				b.tn += 1
			b.x = x
			b.y = y
			b.vx = vx
			b.vy = vy
			b.hd = hd
			b.om = om
			b.burning = burning
			b.drift = wrapf(atan2(vy, vx) - hd, -PI, PI) if sp > 4.0 else 0.0
			b.sp = sp
		"quadcopter":
			if b.holdT > 0.0:
				b.holdT -= dt
			else:
				b.timer += dt
				if b.timer > D.wander:
					b.timer = 0.0
					b.wi = (b.wi + 1) % QUAD_WP.size()
					var wp: Array = QUAD_WP[b.wi]
					b.tx = W * float(wp[0]) + randf_range(-W * 0.05, W * 0.05)
					b.ty = H * float(wp[1])
			var g: float = H * D.g
			var tmax: float = minf(D.tiltMax, 1.2)
			var x: float = b.x
			var y: float = b.y
			var vx: float = b.vx
			var vy: float = b.vy
			var cmd: float = clampf(D.kp * (b.tx - x) / W - D.kd * vx / W, -tmax, tmax)   # the pilot's command
			var tilt: float = b.tilt
			tilt += (cmd - tilt) * (1.0 - exp(-D.tiltRate * dt))   # ← lag one: the body rolls toward it
			var ax: float = g * tan(tilt)                # ← the lean becomes acceleration
			vx += ax * dt                                # ← lag two: acceleration becomes speed
			var w: float = D.omega
			vy += (w * w * (b.ty - y) - 2.0 * D.zeta * w * vy) * dt   # height: the spring
			x += vx * dt
			y += vy * dt
			if x < 12.0:
				x = 12.0
				vx = 0.0
			if x > W - 12.0:
				x = W - 12.0
				vx = 0.0
			if y > GY - 10.0:
				y = GY - 10.0
				vy = 0.0
			var thr: float = g / cos(tilt)               # the thrust that still holds the weight
			b.spin += (16.0 + thr / g * 8.0) * dt
			b.x = x
			b.y = y
			b.vx = vx
			b.vy = vy
			b.tilt = tilt
			b.cmd = cmd
			b.ax = ax
			b.thr = thr
		"uboat":
			var SURF: float = H * D.surface
			b.timer += dt
			if b.timer > D.wander:
				b.timer = 0.0
				b.ty = randf_range(SURF + H * 0.12, H - 24.0)
			var v: float = W * D.speed
			var y: float = b.y
			var vy: float = b.vy
			var err: float = b.ty - y
			var wantB: float = 0.5 + clampf(err / H * 2.5 - vy / H * 3.0, -0.5, 0.5)   # trim: by depth error and vertical speed
			var pr: float = D.pumpRate
			b.ballast += clampf(wantB - b.ballast, -pr * dt, pr * dt)   # ← the pump is slow
			var pcmd: float = clampf(err / H * 3.0, -D.pitchMax, D.pitchMax)
			b.pitch += (pcmd - b.pitch) * (1.0 - exp(-D.planeRate * dt))   # the planes pitch the hull
			var aB: float = (b.ballast - 0.5) * D.g * H
			var aP: float = v * sin(b.pitch) * D.planeLift
			vy += (aB + aP - D.drag * vy) * dt           # ← the whole equation
			y += vy * dt
			if y < SURF + 12.0:
				y = SURF + 12.0
				vy = maxf(0.0, vy)
			if y > H - 16.0:
				y = H - 16.0
				vy = minf(0.0, vy)
			var x: float = b.x + v * dt
			if x > W + 40.0:
				x = -40.0
			var nb: int = D.bubbles
			var BX: Array[float] = b.BX
			var BY: Array[float] = b.BY
			var BR: Array[float] = b.BR
			for i in nb:                                 # bubbles rise; new ones leave the tail
				BY[i] -= (12.0 + BR[i] * 8.0) * dt
				BX[i] += sin(t * 3.0 + i) * 6.0 * dt
				if BY[i] < SURF + 2.0:
					BX[i] = x - 26.0
					BY[i] = y + randf_range(-3.0, 3.0)
					BR[i] = randf_range(0.8, 2.0)
			b.x = x
			b.y = y
			b.vy = vy
			b.aB = aB
		"yak":
			var S: float = H * D.size
			var LEG: float = S * 0.8
			var G: float = H * D.g
			var dir: float = b.dir
			var v: float = dir * W * D.speed
			var mx: float = b.mx + v * dt
			if mx > W * 0.86:
				dir = -1.0
			if mx < W * 0.14:
				dir = 1.0
			b.phase += absf(v) / (S * 0.9) * dt          # the stride clock
			var phase: float = b.phase
			var bob: float = absf(sin(phase)) * H * D.bob
			var by: float = GY - LEG - S * 0.5 - bob      # the body, carried by the gait
			var th: float = cos(phase) * D.tilt * dir     # the rock: the bob's derivative
			var offs: Array = D.offset
			var ox: float = float(offs[0]) * S * dir
			var oy: float = float(offs[1]) * S
			var sx: float = mx + ox * cos(th) - oy * sin(th)   # ← the saddle: parent + R(θ)·offset
			var sy: float = by + ox * sin(th) + oy * cos(th)
			b.mx = mx
			b.dir = dir
			b.bob = bob
			b.by = by
			b.th = th
			b.sx = sx
			b.sy = sy
			if b.mode == "ride":
				b.rx = sx
				b.ry = sy
				b.rideT += dt
				if b.rideT > D.rideFor:
					_dismount(b)
			else:
				if b.mode == "air":
					b.rvy += G * dt
					b.rx += b.rvx * dt
					b.ry += b.rvy * dt
					if absf(b.rx - sx) < S * 0.5 and absf(b.ry - sy) < S * 0.5 and b.rvy > -H * 0.2:
						b.mode = "ride"                  # re-parent
					elif b.ry >= GY - 8.0:
						b.ry = GY - 8.0
						b.rvy = 0.0
						b.rvx = 0.0
						b.mode = "ground"
				else:                                    # on foot: walk toward the mount, hop on when it passes
					var want: float = clampf((mx - b.rx) * 2.0, -W * 0.16, W * 0.16)
					b.rx += want * dt
					if absf(mx - b.rx) < S * 1.6 and b.rideT > 1.2:
						b.mode = "air"
						b.rvx = (sx - b.rx) * 3.0 + v
						b.rvy = -sqrt(2.0 * G * H * D.hop)
					b.rideT += dt
				b.rx = clampf(b.rx, 8.0, W - 8.0)
		"locomotive":
			b.timer += dt
			if b.timer > D.addEvery:
				b.timer = 0.0
				if b.cars < D.maxCars:
					b.cars += 1
				else:
					b.rest += 1
					if b.rest > 1:
						b.cars = int(D.cars)
						b.rest = 0
			_loco_step(b, dt)
		"yoke":
			if b.manualT > 0.0:
				b.manualT -= dt
			else:
				b.timer += dt
				if b.timer > D.wander:
					b.timer = 0.0
					b.bankCmd = randf_range(-1.0, 1.0)
					var sgn: float = -1.0 if b.alt > 0.8 else 1.0
					b.pitchCmd = randf_range(-1.0, 1.0) * sgn * (1.0 if randf() < 0.5 else 0.4)
			var v: float = W * D.speed
			var kr: float = 1.0 - exp(-D.rollRate * dt)
			b.bank += (b.bankCmd * D.bankMax - b.bank) * kr   # ← the roll, at a finite rate
			b.pitch += (b.pitchCmd * D.pitchMax - b.pitch) * kr
			var om: float = D.g * tan(clampf(b.bank, -1.3, 1.3)) / D.speed   # ← the coordinated turn
			var hd: float = b.hd + om * dt
			b.alt = clampf(b.alt + sin(b.pitch) * D.climb * dt, 0.1, 1.0)
			if b.alt <= 0.1 and b.pitchCmd < 0.0:
				b.pitchCmd = 0.3                         # the ground is not a goal
			var x: float = b.x + cos(hd) * v * dt
			var y: float = b.y + sin(hd) * v * dt
			if x < -20.0:
				x = W + 20.0
			if x > W + 20.0:
				x = -20.0
			if y < -20.0:
				y = H + 20.0
			if y > H + 20.0:
				y = -20.0
			var trail: Array[Vector2] = b.trail
			var ti: int = b.ti
			trail[ti] = Vector2(x, y)
			b.ti = (ti + 1) % 80
			if b.tn < 80:
				b.tn += 1
			b.x = x
			b.y = y
			b.hd = hd
			b.om = om

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	Kit.stage(n, b)
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"donuts":
			var x: float = b.x
			var y: float = b.y
			var hd: float = b.hd
			var vf: float = b.vf
			var vl: float = b.vl
			var st: float = b.st
			var brake: bool = b.brake
			var fx := cos(hd)
			var fy := sin(hd)
			var sx := -fy
			var sy := fx
			var marks: int = D.marks
			var mk: Array[Vector2] = b.mk
			var mi: int = b.mi
			var mn: int = b.mn
			for i in mn:
				var age: float = ((mi - 1 - i + marks * 2) % marks) / float(marks)
				Kit.dot(n, mk[i], 1.5, Color(0.788, 0.769, 0.894, 0.4 * (1.0 - age)))
			_push(n, b, Vector2(x, y), hd)
			Kit.rect(n, Rect2(-8, -7, 4, 3), Kit.BONE)   # rear wheels
			Kit.rect(n, Rect2(-8, 4, 4, 3), Kit.BONE)
			for sgn: float in [-1.0, 1.0]:               # front wheels, turned by the lock
				_push(n, b, Vector2(x, y) + Vector2(6.0, sgn * 5.5).rotated(hd), hd + st * 0.5)
				Kit.rect(n, Rect2(-2, -1.5, 4, 3), Kit.BONE)
			_push(n, b, Vector2(x, y), hd)
			Kit.rect(n, Rect2(-10, -5, 20, 10), Kit.MOVER)
			n.draw_circle(Vector2(5, -2), 1.6, EYE)
			_pop(n, b)
			Kit.arrow(n, Vector2(x, y), Vector2(x + fx * vf * 0.25, y + fy * vf * 0.25), Kit.MOVER)   # the forward part
			Kit.arrow(n, Vector2(x, y), Vector2(x + sx * vl * 0.25, y + sy * vl * 0.25), Kit.HOT)     # the sideways part: what grip is eating
			var slip: float = rad_to_deg(atan2(vl, vf))
			Kit.label(n, b, "slip %d°" % roundi(slip), Vector2(x, y - 16.0), Kit.DIM, true)
			if b.counter:
				Kit.label(n, b, "countersteer", Vector2(x, y + 24.0), Kit.TARGET, true)
			Kit.label(n, b, ("HANDBRAKE  ·  " if brake else "") + "grip = " + _num(b.gripNow) + " /s",
				Vector2(W / 2.0, 14.0), Kit.HOT if brake else Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"uphill":
			var CAR: float = W * 0.38
			var L: float = W * D.wheelbase
			var R: float = H * D.wheelR
			var REST: float = H * D.rest
			var wx: float = b.wx
			var wy: Array = b.wy
			var m: Array = b.m
			var th: float = b.th
			var pts := PackedVector2Array()              # the hill
			pts.append(Vector2(0.0, H))
			var sx := 0.0
			while sx <= W + 5.0:
				pts.append(Vector2(sx, _terr(b, sx - CAR + wx)))
				sx += 5.0
			pts.append(Vector2(W, H))
			n.draw_colored_polygon(pts, Color(0.788, 0.769, 0.894, 0.12))
			n.draw_polyline(pts.slice(1, pts.size() - 1), Color(0.788, 0.769, 0.894, 0.55), 1.5)
			for i in 2:
				var cx: float = CAR + (L / 2.0 if i == 1 else -L / 2.0)
				var cy: float = wy[i]
				var mm: Dictionary = m[i]
				var my: float = mm.y
				_spring(n, cx, cy, my, 6, 4.0, Kit.BONE, 1.5)   # the spring, a zigzag that compresses
				Kit.ring(n, Vector2(cx, cy), R, Kit.MOVER, 2.5)
				for k in 4:
					var sa: float = b.spin + k * TAU / 4.0
					Kit.line(n, Vector2(cx, cy), Vector2(cx + cos(sa) * R, cy + sin(sa) * R), Color(0.541, 0.851, 0.961, 0.6), 1.2)
				Kit.dot(n, Vector2(cx, my), 3.0, Kit.BONE)
				Kit.label(n, b, "%d%%" % roundi((cy - my) / REST * 100.0), Vector2(cx + R + 4.0, my + 3.0), Kit.DIM)
			var m0: Dictionary = m[0]
			var m1: Dictionary = m[1]
			var bx: float = CAR
			var by: float = (float(m0.y) + float(m1.y)) / 2.0
			_push(n, b, Vector2(bx, by), th)
			Kit.rect(n, Rect2(-L * 0.62, -R * 1.6, L * 1.24, R * 1.6), Kit.MOVER)   # the chassis, hung on the two mounts
			Kit.rect(n, Rect2(-L * 0.2, -R * 2.8, L * 0.42, R * 1.25), Kit.MOVER)
			n.draw_circle(Vector2(L * 0.14, -R * 2.2), 1.8, EYE)
			_pop(n, b)
			Kit.line(n, Vector2(bx - L * 0.5, by - R * 3.6), Vector2(bx + L * 0.5, by - R * 3.6), Kit.DIM)   # level, for the eye
			Kit.label(n, b, "θ = %d°" % roundi(rad_to_deg(th)), Vector2(bx, by - R * 3.9), Kit.TARGET, true)
			var gx: float = W * 0.08                     # the throttle
			var gw: float = W * 0.28
			var throttle: float = b.throttle
			Kit.line(n, Vector2(gx, 14.0), Vector2(gx + gw, 14.0), Kit.DIM)
			Kit.rect(n, Rect2(gx, 11.0, gw * throttle, 6.0), Kit.HOT)
			Kit.label(n, b, "throttle %d%%  ·  v = %d px/s" % [roundi(throttle * 100.0), roundi(b.v)], Vector2(gx + gw + 8.0, 18.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"hovercraft":
			Kit.ground(n, b)
			var x: float = b.x
			var y: float = b.y
			var vx: float = b.vx
			var tx: float = b.tx
			var push: float = b.push
			var tilt: float = b.tilt
			var h0: float = GY - H * D.hover
			n.draw_dashed_line(Vector2(0.0, h0), Vector2(W, h0), Color(0.961, 0.757, 0.412, 0.3), 1.0, 3.5)   # the rest height
			Kit.label(n, b, "h₀", Vector2(6.0, h0 - 4.0), Color(0.961, 0.757, 0.412, 0.6))
			Kit.ring(n, Vector2(tx, GY - 4.0), 6.0, Kit.TARGET, 1.5)
			_spring(n, x, y, GY, 5, 5.0, Color(0.788, 0.769, 0.894, 0.5), 1.2)   # the cushion, drawn as the spring it is
			if absf(vx) > 8.0:
				for _i in 3:
					Kit.dot(n, Vector2(x + randf_range(-16.0, 16.0), GY - randf_range(1.0, 6.0)), 1.5, Color(0.91, 0.898, 0.957, 0.35))
			_push(n, b, Vector2(x, y + sin(t * 9.0) * 1.5), tilt)
			_ellipse(n, Vector2(0.0, 4.0), 22.0, 6.0, Color(0.788, 0.769, 0.894, 0.7))   # the skirt
			Kit.rect(n, Rect2(-14, -8, 24, 12), Kit.MOVER)                            # the hull
			Kit.ring(n, Vector2(16.0, -4.0), 6.0, Kit.BONE, 2.0)                      # the fan
			Kit.line(n, Vector2(10.0, -4.0), Vector2(22.0, -4.0), Kit.BONE, 1.0)
			n.draw_circle(Vector2(5.0, -3.0), 1.8, EYE)
			_pop(n, b)
			Kit.arrow(n, Vector2(x, y - 16.0), Vector2(x + push * 0.08, y - 16.0), Kit.HOT)   # the push
			Kit.label(n, b, "vₓ = %d  ·  μ = %s" % [roundi(vx), _num(D.friction)], Vector2(W / 2.0, 14.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"lean":
			var cx: float = W * 0.4
			var cy: float = H * 0.52
			var a: float = W * 0.27
			var r: float = b.r
			var hs: float = a - r
			var x: float = b.px
			var y: float = b.py
			var hd: float = b.phd
			var inC: float = b.inC
			var aLat: float = b.aLat
			var want: float = b.want
			var roll: float = b.roll
			var tr := _oval_pts(cx, cy, hs, r, 96)      # the track
			n.draw_polyline(tr, Color(0.788, 0.769, 0.894, 0.12), 14.0)
			for i in range(0, tr.size() - 1, 2):         # its dashed centre line: every other segment
				n.draw_line(tr[i], tr[i + 1], Kit.DIM, 1.0)
			Kit.dot(n, Vector2(cx + hs, cy), 2.0, Kit.DIM)
			Kit.dot(n, Vector2(cx - hs, cy), 2.0, Kit.DIM)
			if inC != 0.0:
				var ccx: float = cx + inC * hs
				Kit.line(n, Vector2(x, y), Vector2(ccx, cy), Kit.DIM)
				Kit.label(n, b, "R = %d" % roundi(r), Vector2((x + ccx) / 2.0, (y + cy) / 2.0 - 4.0), Kit.DIM, true)
				var dx: float = ccx - x
				var dy: float = cy - y
				var d: float = maxf(1.0, sqrt(dx * dx + dy * dy))
				Kit.arrow(n, Vector2(x, y), Vector2(x + dx / d * aLat * 0.06, y + dy / d * aLat * 0.06), Kit.HOT)   # a_lat, toward the centre
			Kit.mote(n, b, Vector2(x, y), hd)
			var ix: float = W * 0.72                     # the inset: seen from behind
			var iy: float = H * 0.08
			var iw: float = W * 0.26
			var ih: float = H * 0.44
			Kit.rect(n, Rect2(ix, iy, iw, ih), Color(0.0, 0.0, 0.0, 0.35))
			Kit.ring(n, Vector2(ix, iy), 0.5, Kit.DIM)
			n.draw_rect(Rect2(ix, iy, iw, ih), Kit.DIM, false, 1.0)
			var gx: float = ix + iw / 2.0
			var gy2: float = iy + ih * 0.82
			var bl: float = ih * 0.6
			Kit.line(n, Vector2(ix + 4.0, gy2), Vector2(ix + iw - 4.0, gy2), Kit.BONE)
			n.draw_dashed_line(Vector2(gx, gy2), Vector2(gx + sin(want) * bl, gy2 - cos(want) * bl), Kit.TARGET, 1.0, 2.5)   # lean*: where the body should be
			Kit.line(n, Vector2(gx, gy2), Vector2(gx + sin(roll) * bl, gy2 - cos(roll) * bl), Kit.MOVER, 3.0)   # the roll: where it is
			Kit.ring(n, Vector2(gx + sin(roll) * bl * 0.12, gy2 - cos(roll) * bl * 0.12), bl * 0.12, Kit.MOVER, 1.5)
			Kit.mote(n, b, Vector2(gx + sin(roll) * bl, gy2 - cos(roll) * bl), -PI / 2.0 + roll, Kit.MOVER, 5.0)
			Kit.label(n, b, "roll %d° → %d°" % [roundi(rad_to_deg(roll)), roundi(rad_to_deg(want))], Vector2(gx, iy + ih - 4.0), Kit.DIM, true)
			Kit.label(n, b, "a_lat = %d px/s²" % roundi(aLat), Vector2(W * 0.4, 14.0), Kit.HOT if inC != 0.0 else Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"boost":
			var G: Array = _boost_geom(b)
			var cx: float = G[0]
			var cy: float = G[1]
			var hs: float = G[2]
			var r: float = G[3]
			var L: float = G[4]
			var v: float = b.v
			var bonus: float = b.bonus
			var cap: float = b.cap
			var flash: float = b.flash
			var base: float = D.base
			var pads: int = D.pads
			n.draw_polyline(_oval_pts(cx, cy, hs, r, 96), Color(0.788, 0.769, 0.894, 0.12), 16.0)
			for i in pads:                               # the pads: chevrons on the tarmac
				var P: Array = _oval(L * (i + 0.5) / pads, cx, cy, hs, r)
				_push(n, b, Vector2(P[0], P[1]), P[2])
				for k in range(-1, 2):
					n.draw_colored_polygon(PackedVector2Array([Vector2(k * 7 - 3, -7), Vector2(k * 7 + 3, 0), Vector2(k * 7 - 3, 7), Vector2(k * 7, 0)]), Kit.GOOD)
				_pop(n, b)
			var P: Array = _oval(b.s, cx, cy, hs, r)
			var x: float = P[0]
			var y: float = P[1]
			var hd: float = P[2]
			_push(n, b, Vector2(x, y), hd)
			if v > base * W * 1.04:                      # over the base cap: flames
				var f: float = 8.0 + randf_range(0.0, 8.0) + (v / W - base) * 40.0
				n.draw_colored_polygon(PackedVector2Array([Vector2(-9, -3), Vector2(-9.0 - f, 0.0), Vector2(-9, 3)]), Kit.HOT)
				n.draw_colored_polygon(PackedVector2Array([Vector2(-9, -1.5), Vector2(-9.0 - f * 0.55, 0.0), Vector2(-9, 1.5)]), Kit.TARGET)
			Kit.rect(n, Rect2(-7, -6, 4, 3), Kit.BONE)
			Kit.rect(n, Rect2(-7, 3, 4, 3), Kit.BONE)
			Kit.rect(n, Rect2(4, -6, 4, 3), Kit.BONE)
			Kit.rect(n, Rect2(4, 3, 4, 3), Kit.BONE)
			Kit.rect(n, Rect2(-9, -4, 18, 8), Kit.MOVER)
			n.draw_circle(Vector2(5.0, -1.5), 1.5, EYE)
			_pop(n, b)
			if flash > 0.0:
				Kit.label(n, b, str(b.kind) + "  +cap", Vector2(x, y - 16.0), Color(0.608, 0.886, 0.541, minf(1.0, flash * 2.0)), true)
			var gx: float = W * 0.15                     # the gauge
			var gw: float = W * 0.7
			var gy2 := 14.0
			var gmax: float = (base + maxf(D.padBonus, D.nitroBonus) + 0.1) * W
			var bx: float = gx + gw * base * W / gmax
			Kit.line(n, Vector2(gx, gy2), Vector2(gx + gw, gy2), Kit.DIM)
			Kit.rect(n, Rect2(gx, gy2 - 3.0, gw * clampf(minf(v, base * W) / gmax, 0.0, 1.0), 6.0), Kit.MOVER)
			if v > base * W:
				Kit.rect(n, Rect2(bx, gy2 - 3.0, gw * clampf((v - base * W) / gmax, 0.0, 1.0), 6.0), Kit.HOT)
			Kit.line(n, Vector2(bx, gy2 - 6.0), Vector2(bx, gy2 + 6.0), Kit.BONE)
			var capx: float = gx + gw * clampf(cap / gmax, 0.0, 1.0)
			Kit.ring(n, Vector2(capx, gy2), 4.5, Kit.TARGET, 1.5)
			Kit.label(n, b, "base", Vector2(bx, gy2 + 16.0), Kit.DIM, true)
			Kit.label(n, b, "cap", Vector2(capx, gy2 - 9.0), Kit.TARGET, true)
			Kit.label(n, b, "v = %.2f W/s  ·  bonus %.2f" % [v / W, bonus], Vector2(W / 2.0, H * 0.52), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"road":
			var pal: Dictionary = b.pal
			var N: int = D.segs
			var dz: float = D.dz
			var posts: float = D.posts
			var cy: float = H * D.horizon
			var f: float = H - cy
			var pos: float = b.pos
			var off: bool = b.off
			var carX: float = b.carX
			var steer: float = b.steer
			var SY: Array[float] = b.SY
			var SX: Array[float] = b.SX
			var SW: Array[float] = b.SW
			var sky0: Color = pal.sky0
			var sky1: Color = pal.sky1
			var grass0: Color = pal.grass0
			var grass1: Color = pal.grass1
			var road: Color = pal.road
			var rumble0: Color = pal.rumble0
			var rumble1: Color = pal.rumble1
			var lineC: Color = pal.line
			n.draw_polygon(PackedVector2Array([Vector2(0.0, 0.0), Vector2(W, 0.0), Vector2(W, cy + 4.0), Vector2(0.0, cy + 4.0)]),
				PackedColorArray([sky0, sky0, sky1, sky1]))   # the sky gradient: one colour per vertex
			Kit.rect(n, Rect2(0.0, cy, W, H - cy), grass0)
			var annK := -1
			for kk in range(N - 1, -1, -1):              # far to near: near slices paint over far ones
				var y1: float = SY[kk + 1]
				var y2: float = SY[kk]
				if y2 <= y1:
					continue                             # faces away: hidden behind a crest
				var d: float = pos + kk * dz
				var stripe: int = posmod(floori(d / (dz * 3.0)), 2)
				n.draw_rect(Rect2(0.0, y1, W, y2 - y1 + 1.0), grass1 if stripe == 1 else grass0)
				var x1: float = SX[kk + 1]
				var w1: float = SW[kk + 1]
				var x2: float = SX[kk]
				var w2: float = SW[kk]
				n.draw_colored_polygon(PackedVector2Array([Vector2(x1 - w1 * 1.12, y1), Vector2(x1 + w1 * 1.12, y1), Vector2(x2 + w2 * 1.12, y2), Vector2(x2 - w2 * 1.12, y2)]),
					rumble1 if stripe == 1 else rumble0)
				n.draw_colored_polygon(PackedVector2Array([Vector2(x1 - w1, y1), Vector2(x1 + w1, y1), Vector2(x2 + w2, y2), Vector2(x2 - w2, y2)]), road)
				if stripe == 1:
					n.draw_colored_polygon(PackedVector2Array([Vector2(x1 - w1 * 0.03, y1), Vector2(x1 + w1 * 0.03, y1), Vector2(x2 + w2 * 0.03, y2), Vector2(x2 - w2 * 0.03, y2)]), lineC)
				if floori(d / posts) != floori((d - dz) / posts):   # a roadside post, 1/z tall
					var z: float = 1.0 + kk * dz
					var ph: float = 0.9 * f / z
					var pxl: float = x2 - w2 * 1.5
					var pxr: float = x2 + w2 * 1.5
					Kit.line(n, Vector2(pxl, y2), Vector2(pxl, y2 - ph), Kit.BONE, maxf(1.0, 3.0 / z))
					Kit.line(n, Vector2(pxr, y2), Vector2(pxr, y2 - ph), Kit.BONE, maxf(1.0, 3.0 / z))
					Kit.rect(n, Rect2(pxl - 4.0 / z * 2.0, y2 - ph - 5.0 / z * 2.0, 16.0 / z, 10.0 / z), Kit.HOT)
				if kk == roundi(N / 4.0):
					annK = kk
			if annK > 0:                                 # one slice, annotated
				var yk: float = SY[annK]
				var z: float = 1.0 + annK * dz
				Kit.line(n, Vector2(SX[annK] - SW[annK], yk), Vector2(SX[annK] + SW[annK], yk), Color(0.961, 0.757, 0.412, 0.7), 1.0)
				Kit.label(n, b, "z = %.1f  w = W/z" % z, Vector2(SX[annK] + SW[annK] + 4.0, yk + 3.0), Color(0.961, 0.757, 0.412, 0.8))
			if pal.rain:
				for _i in 26:
					var rx: float = randf_range(0.0, W)
					var ry: float = randf_range(0.0, H)
					Kit.line(n, Vector2(rx, ry), Vector2(rx - 2.0, ry + 9.0), Color(0.667, 0.706, 0.824, 0.35))
			var sc: float = W / 250.0                    # the car, rear view
			var ccx: float = W / 2.0 + carX * W * 0.06 + (randf_range(-1.5, 1.5) if off else 0.0)
			var ccy: float = H * 0.9
			_ellipse(n, Vector2(ccx, ccy + 3.0 * sc), 20.0 * sc, 4.0 * sc, Color(0.0, 0.0, 0.0, 0.35))
			_push(n, b, Vector2(ccx, ccy), steer * 0.1)
			Kit.rect(n, Rect2(-19.0 * sc, -3.0 * sc, 7.0 * sc, 6.0 * sc), EYE)
			Kit.rect(n, Rect2(12.0 * sc, -3.0 * sc, 7.0 * sc, 6.0 * sc), EYE)
			Kit.rect(n, Rect2(-16.0 * sc, -11.0 * sc, 32.0 * sc, 12.0 * sc), Kit.MOVER)
			Kit.rect(n, Rect2(-10.0 * sc, -18.0 * sc, 20.0 * sc, 8.0 * sc), Color(0.373, 0.694, 0.839))
			Kit.dot(n, Vector2(-12.0 * sc, -6.0 * sc), 2.0 * sc, Kit.HOT)
			Kit.dot(n, Vector2(12.0 * sc, -6.0 * sc), 2.0 * sc, Kit.HOT)
			_pop(n, b)
			Kit.label(n, b, "κ = %.3f  ·  h = %.1f  ·  %d slices%s" % [b.k0, b.hp, N, "  ·  OFF ROAD" if off else ""],
				Vector2(W / 2.0, 14.0), Color(0.91, 0.898, 0.957, 0.75), true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), Color(0.91, 0.898, 0.957, 0.7), true)
		"perspective":
			var nn: int = D.n
			var maxS: float = W * D.streakMax
			var speed: float = b.speed
			var Z: Array[float] = b.Z
			var LX: Array[float] = b.LX
			var LY: Array[float] = b.LY
			var PX: Array[float] = b.PX
			var PY: Array[float] = b.PY
			var alive: Array[int] = b.alive
			Kit.ring(n, Vector2(W / 2.0, H / 2.0), 5.0, Kit.DIM)
			for i in nn:
				if alive[i] == 0:
					continue
				var z: float = Z[i]
				var sx: float = LX[i]
				var sy: float = LY[i]
				var dx: float = sx - PX[i]
				var dy: float = sy - PY[i]
				var d: float = sqrt(dx * dx + dy * dy)
				if d > maxS:
					dx *= maxS / d
					dy *= maxS / d
				var al: float = clampf(1.25 - z, 0.15, 1.0)
				var wd: float = clampf(1.6 / (z + 0.3), 0.6, 2.4)
				if i == 0:                               # the hero star, annotated
					Kit.line(n, Vector2(W / 2.0, H / 2.0), Vector2(sx, sy), Color(0.961, 0.757, 0.412, 0.25))
					Kit.line(n, Vector2(sx - dx, sy - dy), Vector2(sx, sy), Kit.TARGET, wd + 0.5)
					Kit.label(n, b, "(x/z, y/z)  z = %.2f" % z, Vector2(sx + 6.0, sy - 6.0), Kit.TARGET)
				elif d < 1.0:
					Kit.dot(n, Vector2(sx, sy), wd * 0.6, Color(0.91, 0.898, 0.957, al))
				else:
					n.draw_line(Vector2(sx - dx, sy - dy), Vector2(sx, sy), Color(0.91, 0.898, 0.957, al), wd)
			var gx: float = W * 0.06                     # the speed gauge
			var gw: float = W * 0.3
			var base: float = D.base
			var peak: float = D.peak
			Kit.line(n, Vector2(gx, H - 22.0), Vector2(gx + gw, H - 22.0), Kit.DIM)
			Kit.rect(n, Rect2(gx, H - 25.0, gw * clampf((speed - base) / maxf(1e-6, peak - base), 0.0, 1.0), 6.0), Kit.MOVER)
			Kit.label(n, b, "v = %.2f /s%s" % [speed, "  (punch)" if D.ramp == "punch" else ""], Vector2(gx + gw + 6.0, H - 18.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"zerog":
			var cx: float = W / 2.0
			var cy: float = H * 0.5
			var x: float = b.x
			var y: float = b.y
			var vx: float = b.vx
			var vy: float = b.vy
			var hd: float = b.hd
			var om: float = b.om
			var sp: float = b.sp
			var drift: float = b.drift
			var assist: bool = b.assist
			var nx := cos(hd)
			var ny := sin(hd)
			if b.manualT <= 0.0:
				Kit.ring(n, Vector2(cx, cy), H * D.loopR, Color(0.91, 0.898, 0.957, 0.06))
			var trail: Array[Vector2] = b.trail
			var ti: int = b.ti
			var tn: int = b.tn
			for i in tn:
				var age: float = ((ti - 1 - i + 120) % 60) / 60.0
				Kit.dot(n, trail[i], 1.2, Color(0.541, 0.851, 0.961, 0.3 * (1.0 - age)))
			Kit.ring(n, Vector2(b.tx, b.ty), 7.0, Kit.TARGET, 1.5)
			Kit.arrow(n, Vector2(x, y), Vector2(x + nx * 34.0, y + ny * 34.0), Kit.MOVER)   # pointing
			Kit.arrow(n, Vector2(x, y), Vector2(x + vx * 0.3, y + vy * 0.3), Kit.TARGET)    # going
			var drifting: bool = absf(drift) > 0.15 and sp > 20.0
			if drifting:
				n.draw_arc(Vector2(x, y), 22.0, hd, hd + drift, 16, Kit.HOT, 1.5)
				Kit.label(n, b, "drift %d°" % roundi(rad_to_deg(absf(drift))), Vector2(x, y - 28.0), Kit.HOT, true)
			_push(n, b, Vector2(x, y), hd)
			if b.burning:
				n.draw_colored_polygon(PackedVector2Array([Vector2(-7, -3.5), Vector2(-14.0 - randf() * 6.0, 0.0), Vector2(-7, 3.5)]), Kit.HOT)
			if assist and drifting:                      # the rcs puffs that do the assisting
				var side: float = -1.0 if drift > 0.0 else 1.0
				for i in 3:
					Kit.dot(n, Vector2(-2.0 + i * 3.0, side * (8.0 + i * 2.0)), 1.4, Color(0.608, 0.886, 0.541, 0.7))
			n.draw_colored_polygon(PackedVector2Array([Vector2(12, 0), Vector2(-7, -7), Vector2(-4, 0), Vector2(-7, 7)]), Kit.MOVER)
			n.draw_circle(Vector2(3.0, -2.0), 1.6, EYE)
			_pop(n, b)
			Kit.label(n, b, "FLIGHT ASSIST %s   ·   ω = %.1f rad/s   ·   c = %s" % ["ON" if assist else "OFF", om, _num(D.angDamp)],
				Vector2(W / 2.0, 14.0), Kit.GOOD if assist else Kit.HOT, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"quadcopter":
			Kit.ground(n, b)
			var x: float = b.x
			var y: float = b.y
			var tx: float = b.tx
			var ty: float = b.ty
			var tilt: float = b.tilt
			var cmd: float = b.cmd
			var ax: float = b.ax
			var thr: float = b.thr
			var g: float = H * D.g
			var tmax: float = minf(D.tiltMax, 1.2)
			n.draw_dashed_line(Vector2(tx, GY), Vector2(tx, ty), Color(0.961, 0.757, 0.412, 0.3), 1.0, 3.5)
			Kit.ring(n, Vector2(tx, ty), 7.0, Kit.TARGET, 1.5)
			for wp in QUAD_WP:
				Kit.dot(n, Vector2(W * float(wp[0]), H * float(wp[1])), 1.5, Kit.DIM)
			var arm := 16.0
			_push(n, b, Vector2(x, y), tilt)
			Kit.rect(n, Rect2(-arm - 3.0, -3.0, arm * 2.0 + 6.0, 4.0), Kit.BONE)
			Kit.rect(n, Rect2(-7, -5, 14, 10), Kit.MOVER)
			Kit.rect(n, Rect2(-3, 5, 6, 5), Kit.BONE)
			var bl: float = arm * 0.75 * absf(cos(b.spin))
			Kit.line(n, Vector2(-bl, -7.0), Vector2(bl, -7.0), Color(0.91, 0.898, 0.957, 0.75), 2.0)
			n.draw_circle(Vector2(3.0, -1.0), 1.7, EYE)
			_pop(n, b)
			var ux: float = sin(tilt)                    # the body's up
			var uy: float = -cos(tilt)
			Kit.arrow(n, Vector2(x, y), Vector2(x + ux * thr * 0.09, y + uy * thr * 0.09), Kit.HOT)   # thrust, along it
			Kit.arrow(n, Vector2(x, y), Vector2(x, y + g * 0.09), Kit.DIM)                            # weight
			Kit.arrow(n, Vector2(x, y + 16.0), Vector2(x + ax * 0.09, y + 16.0), Kit.TARGET)          # what is left over: aₓ
			var my: float = y - 30.0                     # command vs actual
			Kit.line(n, Vector2(x - 22.0, my), Vector2(x + 22.0, my), Kit.DIM)
			Kit.line(n, Vector2(x + cmd / tmax * 20.0, my - 4.0), Vector2(x + cmd / tmax * 20.0, my + 4.0), Kit.TARGET, 2.0)
			Kit.line(n, Vector2(x + tilt / tmax * 20.0, my - 3.0), Vector2(x + tilt / tmax * 20.0, my + 3.0), Kit.MOVER, 2.0)
			Kit.label(n, b, "cmd %d°  tilt %d°" % [roundi(rad_to_deg(cmd)), roundi(rad_to_deg(tilt))], Vector2(x, my - 7.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"uboat":
			var SURF: float = H * D.surface
			var x: float = b.x
			var y: float = b.y
			var ty: float = b.ty
			var ballast: float = b.ballast
			var pitch: float = b.pitch
			var aB: float = b.aB
			var gH: float = D.g * H
			Kit.rect(n, Rect2(0.0, SURF, W, H - SURF), Color(0.235, 0.353, 0.667, 0.16))   # the sea
			var wave := PackedVector2Array()
			var sx := 0.0
			while sx <= W:
				wave.append(Vector2(sx, SURF + sin(sx / W * 14.0 - t * 1.6) * 3.0))
				sx += 6.0
			n.draw_polyline(wave, Color(0.788, 0.769, 0.894, 0.6), 1.5)
			var nb: int = D.bubbles
			var BX: Array[float] = b.BX
			var BY: Array[float] = b.BY
			var BR: Array[float] = b.BR
			for i in nb:
				Kit.ring(n, Vector2(BX[i], BY[i]), BR[i], Color(0.91, 0.898, 0.957, 0.35))
			_push(n, b, Vector2(x, y), pitch)
			_ellipse(n, Vector2.ZERO, 28.0, 8.0, Kit.MOVER)                     # the hull
			Kit.rect(n, Rect2(-6, -15, 12, 8), Kit.MOVER)                        # the tower
			Kit.rect(n, Rect2(-14.0, -3.0, 28.0 * ballast, 6.0), Color(0.075, 0.063, 0.125, 0.55))   # the tanks, filled to ballast
			n.draw_rect(Rect2(-14, -3, 28, 6), Color(0.075, 0.063, 0.125, 0.7), false, 1.0)
			Kit.line(n, Vector2(-26.0, 0.0), Vector2(-34.0, 0.0), Kit.BONE, 2.0)
			n.draw_colored_polygon(PackedVector2Array([Vector2(-22.0, -4.0), Vector2(-30.0, -4.0 - 8.0 * sin(pitch)),
				Vector2(-30.0, 4.0 - 8.0 * sin(pitch)), Vector2(-22.0, 4.0)]), Kit.BONE)   # the planes
			n.draw_circle(Vector2(14.0, -2.0), 1.6, EYE)
			_pop(n, b)
			Kit.arrow(n, Vector2(x + 4.0, y), Vector2(x + 4.0, y - 0.5 * gH * 0.25), Kit.GOOD)       # buoyancy: constant
			Kit.arrow(n, Vector2(x - 4.0, y), Vector2(x - 4.0, y + ballast * gH * 0.25), Kit.HOT)    # weight: the ballast
			if absf(aB) > 2.0:
				Kit.arrow(n, Vector2(x + 40.0, y), Vector2(x + 40.0, y + aB * 0.25), Kit.TARGET)     # net
			Kit.label(n, b, "ballast %d%%  ·  pitch %d°" % [roundi(ballast * 100.0), roundi(rad_to_deg(pitch))], Vector2(x, y - 24.0), Kit.DIM, true)
			var gx: float = W - 18.0                     # the depth gauge
			Kit.line(n, Vector2(gx, SURF), Vector2(gx, H - 14.0), Kit.BONE)
			for dd: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
				Kit.line(n, Vector2(gx - 3.0, SURF + (H - 14.0 - SURF) * dd), Vector2(gx + 3.0, SURF + (H - 14.0 - SURF) * dd), Kit.DIM)
			Kit.line(n, Vector2(gx - 7.0, ty), Vector2(gx + 7.0, ty), Kit.TARGET, 2.0)
			Kit.dot(n, Vector2(gx, y), 3.5, Kit.MOVER)
			_label_right(n, b, "%d m" % roundi((y - SURF) / H * 100.0), Vector2(gx - 8.0, y + 3.0), Kit.MOVER)
			_label_right(n, b, "%d m" % roundi((ty - SURF) / H * 100.0), Vector2(gx - 8.0, ty + (12.0 if ty > y else -5.0)), Kit.TARGET)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"yak":
			Kit.ground(n, b)
			var S: float = H * D.size
			var LEG: float = S * 0.8
			var mx: float = b.mx
			var dir: float = b.dir
			var phase: float = b.phase
			var bob: float = b.bob
			var by: float = b.by
			var th: float = b.th
			var sx: float = b.sx
			var sy: float = b.sy
			var rx: float = b.rx
			var ry: float = b.ry
			var mode: String = b.mode
			var offs: Array = D.offset
			var ox: float = float(offs[0]) * S * dir
			_push(n, b, Vector2(mx, by), th)             # the mount
			for i in 4:                                  # four legs, two beats
				var hx: float = (0.6 if i < 2 else -0.6) * S * dir
				var sw: float = sin(phase + (i % 2) * PI) * 0.45
				Kit.line(n, Vector2(hx, S * 0.3), Vector2(hx + sin(sw) * LEG, S * 0.3 + cos(sw) * LEG + bob), Kit.BONE, 3.0)
			_ellipse(n, Vector2.ZERO, S * 1.1, S * 0.55, Kit.BONE)
			n.draw_circle(Vector2(S * 1.2 * dir, -S * 0.25), S * 0.32, Kit.BONE)   # the head
			Kit.line(n, Vector2(S * 1.2 * dir, -S * 0.5), Vector2(S * 1.45 * dir, -S * 0.85), Kit.BONE, 2.0)   # horns
			Kit.line(n, Vector2(S * 1.2 * dir, -S * 0.5), Vector2(S * 0.95 * dir, -S * 0.85), Kit.BONE, 2.0)
			Kit.rect(n, Rect2(ox - S * 0.3, -S * 0.7, S * 0.6, S * 0.25), EYE)     # the saddle
			n.draw_circle(Vector2(S * 1.3 * dir, -S * 0.3), 1.6, EYE)
			_pop(n, b)
			n.draw_dashed_line(Vector2(mx, by), Vector2(sx, sy), Kit.TARGET if mode == "ride" else Kit.DIM, 1.0, 2.5)   # the offset, drawn
			Kit.dot(n, Vector2(mx, by), 2.0, Kit.TARGET)
			Kit.ring(n, Vector2(sx, sy), 3.0, Kit.TARGET, 1.0)
			var face: float = atan2(b.rvy, b.rvx) if mode == "air" else (0.0 if dir > 0.0 else PI)
			Kit.mote(n, b, Vector2(rx, ry), face, Kit.MOVER, 6.0)
			var txt: String = ("riding: θ = %d°" % roundi(rad_to_deg(th))) if mode == "ride" else ("v = v_mount + hop" if mode == "air" else "on foot")
			Kit.label(n, b, txt, Vector2(rx, ry - 14.0), Kit.HOT if mode == "air" else Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"locomotive":
			var NH: int = D.hist
			var cars: int = b.cars
			var sEng: float = b.sEng
			var HX: Array[float] = b.HX
			var HY: Array[float] = b.HY
			var HS: Array[float] = b.HS
			var rail := PackedVector2Array()             # the rail, dashed: every other segment
			for i in 141:
				rail.append(_rail(b, i / 140.0 * TAU))
			for i in range(0, 140, 2):
				n.draw_line(rail[i], rail[i + 1], Color(0.788, 0.769, 0.894, 0.35), 1.0)
			var LEN: float = W * D.carLen
			var WID: float = W * D.carW
			var SP: float = W * D.spacing
			var newest: int = posmod(b.hi - 1, NH)
			var px: float = HX[newest]
			var py: float = HY[newest]
			var ex := px
			var ey := py
			var E: Array = _read_back(b, sEng - 1.0, newest)
			var phd: float = E[2]
			var j: int = newest
			for k in range(1, cars + 1):
				var C: Array = _read_back(b, sEng - k * SP, j)   # ← car k: the engine's past, k spacings ago
				j = C[3]
				var cp := Vector2(C[0], C[1])
				Kit.line(n, Vector2(px, py), cp, Kit.BONE, 1.5)   # the coupling
				_car(n, b, cp, C[2], LEN, WID, Color(0.788, 0.769, 0.894, 0.85) if k % 2 == 1 else Color(0.961, 0.757, 0.412, 0.75))
				if k == 1:
					Kit.ring(n, cp, 2.5, Kit.TARGET, 1.0)
					Kit.label(n, b, "spacing", Vector2((px + cp.x) / 2.0, (py + cp.y) / 2.0 - 8.0), Kit.TARGET, true)
				px = cp.x
				py = cp.y
			var TL: Array = _read_back(b, sEng - cars * SP - SP * 1.5, j)   # the unused history behind the last car
			var tail: int = TL[3]
			for nn in 40:
				var idx: int = posmod(j - nn, NH)
				if nn > 0 and HS[idx] < HS[tail]:
					break
				Kit.dot(n, Vector2(HX[idx], HY[idx]), 1.0, Kit.DIM)
			_car(n, b, Vector2(ex, ey), phd, LEN * 1.3, WID * 1.15, Kit.MOVER)   # the engine
			_push(n, b, Vector2(ex, ey), phd)
			Kit.rect(n, Rect2(LEN * 0.25, -WID * 0.3, LEN * 0.25, WID * 0.6), EYE)
			_pop(n, b)
			for i in 3:                                  # smoke
				Kit.dot(n, Vector2(ex - cos(phd) * (LEN * 0.1 + i * 5.0) - sin(phd) * 6.0,
					ey - sin(phd) * (LEN * 0.1 + i * 5.0) + cos(phd) * 6.0 - i * 4.0 - fmod(t * 30.0, 6.0)),
					1.5 + i, Color(0.91, 0.898, 0.957, 0.3 - i * 0.08))
			Kit.label(n, b, "cars %d / %d  ·  s = %d px  ·  %d samples" % [cars, D.maxCars, roundi(sEng), b.hn], Vector2(W / 2.0, 14.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"yoke":
			var x: float = b.x
			var y: float = b.y
			var hd: float = b.hd
			var bank: float = b.bank
			var pitch: float = b.pitch
			var alt: float = b.alt
			var om: float = b.om
			var v: float = W * D.speed
			var trail: Array[Vector2] = b.trail
			var ti: int = b.ti
			var tn: int = b.tn
			for i in tn:
				var age: float = ((ti - 1 - i + 160) % 80) / 80.0
				Kit.dot(n, trail[i], 1.2, Color(0.541, 0.851, 0.961, 0.3 * (1.0 - age)))
			var sc: float = 0.7 + alt * 0.6              # altitude: bigger, shadow further
			var sh: float = alt * H * 0.1
			_plane(n, b, Vector2(x + sh, y + sh), hd, bank, Color(0.0, 0.0, 0.0, 0.35), sc * 0.9)
			if absf(om) > 0.1:                           # the turn circle it is flying
				var R: float = v / om
				Kit.ring(n, Vector2(x - sin(hd) * R, y + cos(hd) * R), absf(R), Color(0.91, 0.898, 0.957, 0.07))
			_plane(n, b, Vector2(x, y), hd, bank, Kit.MOVER, sc)
			_push(n, b, Vector2(x, y), hd, Vector2(sc, sc))
			n.draw_circle(Vector2(8.0, -1.0), 1.5, EYE)
			_pop(n, b)
			# the attitude indicator. the web clips two rects to a circle; the
			# painter builds the same picture by arithmetic: the sky is the whole
			# disc, the ground is the circular segment beyond the horizon chord
			# (rolled by −bank, pushed down by the pitch), the ladder lines are
			# drawn only while both ends sit inside the disc.
			var ix: float = W * 0.76
			var iy: float = H * 0.1
			var ir: float = minf(W * 0.11, H * 0.17)
			var C := Vector2(ix + ir, iy + ir)
			var offp: float = pitch * ir * 1.2
			var nrm := Vector2(sin(bank), cos(bank))     # screen-space "down" of the rolled horizon
			var ux := Vector2(cos(bank), -sin(bank))     # screen-space "right" of it
			n.draw_circle(C, ir, Color("#3E6FA8"))
			var brown := Color("#6B4B2A")
			if offp <= -ir:
				n.draw_circle(C, ir, brown)
			elif offp < ir:
				var phi: float = nrm.angle()
				var half: float = acos(offp / ir)
				var seg := PackedVector2Array()
				for i in 25:
					var an: float = phi - half + 2.0 * half * i / 24.0
					seg.append(C + Vector2(cos(an), sin(an)) * ir)
				n.draw_colored_polygon(seg, brown)
				n.draw_line(seg[0], seg[24], Color(0.91, 0.898, 0.957), 1.5)   # the horizon
			for k: int in [-2, -1, 1, 2]:                # the pitch ladder
				var mid: Vector2 = C + nrm * (k * ir * 0.3 + offp)
				var a1: Vector2 = mid - ux * ir * 0.3
				var a2: Vector2 = mid + ux * ir * 0.3
				if a1.distance_to(C) < ir and a2.distance_to(C) < ir:
					n.draw_line(a1, a2, Color(0.91, 0.898, 0.957, 0.5), 1.0)
			Kit.ring(n, C, ir, Kit.BONE, 1.5)
			Kit.line(n, C + Vector2(-ir * 0.6, 0.0), C + Vector2(-ir * 0.2, 0.0), Kit.TARGET, 2.0)
			Kit.line(n, C + Vector2(ir * 0.2, 0.0), C + Vector2(ir * 0.6, 0.0), Kit.TARGET, 2.0)
			Kit.dot(n, C, 2.0, Kit.TARGET)
			Kit.label(n, b, "bank %d°  pitch %d°" % [roundi(rad_to_deg(bank)), roundi(rad_to_deg(pitch))], Vector2(ix + ir, iy + ir * 2.0 + 12.0), Kit.DIM, true)
			Kit.label(n, b, "ω = %.2f rad/s  ·  alt %d%%" % [om, roundi(alt * 100.0)], Vector2(W * 0.38, 14.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
