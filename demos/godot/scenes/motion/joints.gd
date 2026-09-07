extends RefCounted

const Kit := preload("res://scenes/motion/kit.gd")
## JOINTS, CLOTH & GRAINS — thirteen movement styles, ported from the web
## lexicon (docs/locomotion.js). The chain, the lattice, and the grid. A
## joint is an angle that obeys a limit; a cloth is a rope in two
## directions; a grain is a cell that asks the cell below whether it is
## free. This family closes the loop opened by Chains and Bodies: a third
## IK (CCD — rotate joints from the tip back), quadruped phase tables,
## jiggle for free, verlet cloth with three kinds of promise, a rope bridge
## that sags, rigid rotation (τ = r × F), hinges with motors, links that
## break, grab-and-throw, the artillery formula and the preview that
## follows its own dots — and two cellular automata: falling sand, and tile
## water that levels out (or fire that spreads).

const TITLE := "Joints, cloth & grains"
const BLURB := "the third IK, quadrupeds, jiggle, cloth, a rope bridge, torque, hinges, links that break, throws, artillery, falling sand, tile water"
const DEFS := [
	{ "id": "robotarm", "letter": "R", "name": "Robotarm",
		"hint": "CCD IK: rotate each joint, tip first, so the tip swings at the target, clamp its ANGLE LIMIT, repeat (Fabrik's cousin) — press to set the target",
		"dials": { "n": 8,              # joints in the chain
			"bone": 0.085,              # bone length ×H
			"limit": 0.85,              # each joint may bend ±limit radians from its parent
			"baseLimit": 1.3,           # the base may lean ±baseLimit from straight up
			"iters": 3,                 # CCD sweeps per frame
			"sticky": 3.5, "roamX": 0.36, "roamY": 0.26,   # how long a press holds; the idle wander (of W, H)
			"label": "for j = tip−1 … 0: θⱼ += ∠(tip−pⱼ, target−pⱼ) · clamp ±limit" },
		"rhyme": { "name": "Rigidarm", "hint": "four long bones and half the bend per joint — the same sweeps, now an excavator that cannot curl",
			"dials": { "n": 4, "bone": 0.17, "limit": 0.45 } } },
	{ "id": "quadruped", "letter": "Q", "name": "Quadruped",
		"hint": "four legs on a PHASE TABLE over Gait's rules — walk 0/.5/.25/.75, trot in diagonal pairs, gallop — a body on a spring — press to cycle the gait",
		"dials": { "gait": "walk",                              # the starting gait (a press cycles them)
			"gaits": { "walk": [0.0, 0.5, 0.25, 0.75],       # phase offsets for LF, RF, LH, RH
				"trot": [0.0, 0.5, 0.5, 0.0],                 # diagonal pairs swing together
				"gallop": [0.0, 0.12, 0.5, 0.62] },           # fronts near-together, hinds near-together
			"duty": 0.6,                # fraction of the cycle a foot spends on the ground
			"cycle": 0.75,              # seconds per stride at full speed
			"stride": 0.09,             # step length ×W at full speed
			"lift": 0.05,               # swing height ×H
			"leg": 0.17,                # thigh = shin ×H
			"body": 0.26,               # hip-to-shoulder ×W
			"maxv": 0.3,                # top speed ×W/s
			"omega": 18.0,              # the body spring (critically damped)
			"label": "φᵢ = (t/T + offsetᵢ) mod 1 · stance while φᵢ < duty, else swing" },
		"rhyme": { "name": "Quarterhorse", "hint": "born galloping on longer legs with a faster stride clock — the same four offsets, now a racehorse",
			"dials": { "gait": "gallop", "leg": 0.22, "cycle": 0.5 } } },
	{ "id": "jangle", "letter": "J", "name": "Jangle",
		"hint": "JIGGLE chains — ears, hair, a tail — hang off a hopping body and lag, overshoot, settle: secondary motion for free (Rope's verlet) — press to shove it",
		"dials": { "links": 5,          # base points per chain (each chain scales it by len)
			"seg": 0.022,               # link length ×H
			"stiff": 16.0,              # pull toward the rest pose, per second
			"damp": 0.92,               # velocity kept per 1/60 s
			"g": 0.6,                   # gravity on the chains ×H (light: these are hairs)
			"bodyG": 2.4,               # gravity on the body ×H
			"hopV": 0.85,               # hop launch ×H/s
			"hopEvery": 1.4,            # seconds between hops
			"run": 0.22,                # patrol speed ×W/s
			"margin": 0.2,              # the patrol turns back this far ×W from either edge (room for the tail)
			"shove": 0.55,              # press impulse ×H/s
			"chains": [ { "ang": -1.25, "dir": -1.45, "len": 1.2, "w": 1.5, "c": Color(0.788, 0.627, 0.961) },    # antennae
				{ "ang": -1.9, "dir": -1.7, "len": 1.2, "w": 1.5, "c": Color(0.788, 0.627, 0.961) },
				{ "ang": -2.45, "dir": -2.35, "len": 0.7, "w": 3.5, "c": Color(0.541, 0.851, 0.961) },    # an ear
				{ "ang": -0.65, "dir": -0.95, "len": 0.8, "w": 2.5, "c": Color(0.541, 0.851, 0.961) },    # hair
				{ "ang": 2.75, "dir": 2.55, "len": 1.6, "w": 2.5, "c": Color(0.788, 0.769, 0.894) } ],    # the tail
			"label": "p += (p − p_last)·damp + (rest − p)·(1 − e^(−k·dt))" },
		"rhyme": { "name": "Jellyears", "hint": "a third of the stiffness, nearly twice the links and barely any damping — everything trails and wobbles for seconds",
			"dials": { "stiff": 5.0, "links": 9, "damp": 0.97 } } },
	{ "id": "cloth", "letter": "C", "name": "Cloth", "drag": true,
		"hint": "a verlet lattice with STRUCTURAL, SHEAR and BEND promises, pinned along the top, in a noise wind (Rope, twice over) — drag to pull any point",
		"dials": { "cols": 10, "rows": 8,   # the lattice
			"spacing": 0.055,           # rest distance ×H
			"rounds": 3,                # solver passes per frame
			"g": 1.6,                   # gravity ×H
			"damp": 0.99,               # velocity kept per step
			"wind": 1.4,                # sideways push ×H/s², from noise
			"windRate": 0.9,            # how fast the gust changes
			"shear": 0.5,               # strength of the diagonal promises (1 = as stiff as structural)
			"bend": 0.3,                # strength of the skip-one promises
			"pins": "top",              # "top" = the whole top row pinned, "corners" = two points
			"label": "structural (×1) · shear (×0.5) · bend (×0.3): three promises per point" },
		"rhyme": { "name": "Cape", "hint": "pinned at two corners only, heavier, and no wind at all — the same lattice hangs like a cape from two shoulders",
			"dials": { "pins": "corners", "g": 2.6, "wind": 0.0 } } },
	{ "id": "bridge", "letter": "B", "name": "Bridge",
		"hint": "ROPE BRIDGE: a chain anchored at both ends sags under the walker's mass — Rope's inverse-mass links, a Gait stroll — press to drop a weight",
		"dials": { "n": 13,             # chain points (planks hang one per point)
			"slack": 1.1,               # chain length ÷ span (1 = taut)
			"rounds": 6,                # solver passes per frame
			"g": 2.2,                   # gravity ×H
			"damp": 0.98,               # velocity kept per step
			"walker": 4.0,              # the walker's mass, in link masses
			"weight": 8.0,              # a dropped crate's mass, in link masses
			"weightLife": 7.0,          # seconds a crate stays before it rots away
			"speed": 0.16,              # walking speed ×W/s
			"label": "each link splits its error by inverse mass — the loaded point barely moves" },
		"rhyme": { "name": "Boardwalk", "hint": "twenty-one planks on a nearly taut chain under a walker three times as heavy — the sag is a shallow, moving dent",
			"dials": { "n": 21, "slack": 1.03, "walker": 12.0 } } },
	{ "id": "torque", "letter": "T", "name": "Torque",
		"hint": "RIGID ROTATION: an off-centre shove spins a crate — τ = r × F, α = τ/I; corners bounce and rub on the floor (Knock with a lever arm) — press to shove",
		"dials": { "size": 0.13,        # the crate's height ×H
			"aspect": 1.0,              # width ÷ height
			"mass": 1.0,
			"e": 0.35,                  # restitution at a corner
			"mu": 0.4,                  # friction at a corner
			"g": 2.0,                   # gravity ×H
			"shove": 0.8,               # the impulse ×H·mass/s
			"shoveEvery": 2.6,          # the idle poker's timer
			"label": "τ = r × F · α = τ / I · I = m(w² + h²)/12" },
		"rhyme": { "name": "Tumbler", "hint": "a plank three times as wide as it is tall on a slick floor — a big I resists the spin, and the corners skate instead of catching",
			"dials": { "aspect": 3.0, "mu": 0.05, "e": 0.5 } } },
	{ "id": "hinge", "letter": "H", "name": "Hinge",
		"hint": "HINGE: a body that may only PIVOT about a point; add a MOTOR for a door, a windmill, a drawbridge (Pendulum's θ, driven by τ) — press to push the door",
		"dials": { "mode": "trio",      # "trio" = door + windmill + drawbridge · "wheel" = one wheel the mote runs inside
			"doorK": 7.0,               # the door closer: a spring toward shut
			"doorC": 1.4,               # its damping
			"doorLimit": 1.5,           # the frame stops the door here, radians either way
			"motorW": 1.8,              # the windmill's wanted speed, rad/s
			"motorK": 3.0,              # how hard its motor chases that speed
			"bridgeK": 30.0,            # the drawbridge winch: a position motor toward the target angle
			"bridgeC": 9.0,             # its damping
			"bridgeMax": 26.0,          # the most torque the winch can give
			"g": 14.0,                  # the beam's weight as torque (m·g·L/2)
			"bridgeEvery": 4.0,         # seconds between raise and lower
			"pushEvery": 2.8,           # the idle door pusher
			"push": 4.0,                # its push, rad/s
			"run": 0.3,                 # wheel mode: the mote's run speed ×W/s
			"damping": 0.2,             # wheel mode: bearing friction
			"label": "α = τ / I · ω += α·dt · θ += ω·dt · θ clamped at the stops" },
		"rhyme": { "name": "Hamsterwheel", "hint": "the same hinge integrator with a runner inside as its motor — the wheel spins up, outruns it, and carries it up the front",
			"dials": { "mode": "wheel", "run": 0.36, "damping": 0.1 } } },
	{ "id": "yield", "letter": "Y", "name": "Yield", "drag": true,
		"hint": "BREAKABLE links: a distance promise (Rope) with a strain limit — stretch past it and the link SNAPS; strain shown as colour — drag to pull",
		"dials": { "strands": 3,        # hanging chains
			"links": 9,                 # links per strand
			"seg": 0.05,                # rest length ×H
			"limit": 1.3,               # d / rest at which a link gives up
			"rounds": 4,                # solver passes (fewer = strain concentrates near the pull)
			"g": 1.8,                   # gravity ×H
			"damp": 0.985,              # velocity kept per step
			"pullEvery": 2.4,           # the idle hand's timer
			"pullTime": 1.1,            # seconds one idle pull lasts
			"pullDist": 0.5,            # how far it pulls ×H
			"heal": 5.0,                # seconds before a torn strand re-knits
			"label": "strain = d / rest · a link lives while strain < limit" },
		"rhyme": { "name": "Yarn", "hint": "six strands of twelve weak links that give at twelve percent stretch — a tug frays everything it touches",
			"dials": { "strands": 6, "limit": 1.12, "links": 12 } } },
	{ "id": "grab", "letter": "G", "name": "Grab",
		"hint": "GRAB & THROW: pick up = parent to the hand (Nest); hold = a damped spring; throw = spring velocity + aim + a LOB (Knock) — press to throw or fetch",
		"dials": { "crates": 2,
			"size": 0.07,               # crate side ×H
			"mass": 1.0,                # heavier = slower spring, shorter throw
			"omega": 14.0,              # the holding spring's ω (÷ √mass)
			"zeta": 0.55,               # its damping ratio (< 1: it overshoots the hand)
			"throwV": 0.55,             # aim speed ×W/s (÷ √mass)
			"lob": 0.6,                 # extra upward speed ×H/s
			"g": 2.2,                   # gravity ×H
			"e": 0.35,                  # floor restitution
			"friction": 3.0,            # ground friction, per second
			"reach": 0.09,              # grab radius ×W
			"speed": 0.32,              # walking speed ×W/s
			"holdTime": 1.1,            # the autopilot holds this long, then throws
			"label": "held: a = ω²(hand − p) − 2ζω·v · thrown: v = v_spring + aim·v₀ + lob" },
		"rhyme": { "name": "Gorilla", "hint": "crates three times the mass on a slow spring, thrown with twice the lob — heavy things swing on the hand and go high, not far",
			"dials": { "mass": 3.0, "omega": 7.0, "lob": 1.2 } } },
	{ "id": "artillery", "letter": "A", "name": "Artillery",
		"hint": "ARTILLERY SOLVE: the closed-form launch angle to land a shell of speed v on (x, y) — a HIGH and a LOW root, both drawn (Jump, Volley) — press to aim",
		"dials": { "v": 0.8,            # muzzle speed ×W/s
			"g": 1.6,                   # gravity ×H/s²
			"pick": "both",             # which root the gun fires: "both" (alternating), "high", "low"
			"fireEvery": 1.5,           # seconds between shells
			"targetSpeed": 0.12,        # the drone's cruise ×W/s
			"sticky": 4.0,              # how long a press holds the target still
			"label": "tanθ = (v² ± √(v⁴ − g(g·x² + 2y·v²))) / (g·x)" },
		"rhyme": { "name": "Antiair", "hint": "faster shells, only ever the high root, at a drone doing two and a half times the speed — a flak battery that leads by lobbing",
			"dials": { "v": 1.15, "pick": "high", "targetSpeed": 0.3 } } },
	{ "id": "yardstick", "letter": "Y", "name": "Yardstick", "drag": true,
		"hint": "TRAJECTORY PREVIEW: dots run the flight code ahead, stopping at the FIRST HIT on the terrain (Xmarks); the throw follows its dots — drag to aim",
		"dials": { "power": 0.9,        # throw speed at full pull ×W/s
			"pull": 0.35,               # pointer distance ×W that means full power
			"g": 2.4,                   # gravity ×H/s²
			"step": 0.05,               # the preview's step — and the flight's, so they agree
			"dots": 60,                 # preview steps at most
			"hills": 0.16,              # terrain height ×H
			"bumps": 2.5,               # terrain waves across W
			"e": 0.3,                   # bounce at the landing
			"autoEvery": 3.0,           # the idle thrower's timer
			"label": "same dt, same v += g·dt, same p += v·dt — preview and flight cannot disagree" },
		"rhyme": { "name": "Yardage", "hint": "golf: half again the power over a long flat fairway — the same dots, stretched into a drive",
			"dials": { "power": 1.3, "hills": 0.05, "bumps": 0.8 } } },
	{ "id": "sand", "letter": "S", "name": "Sand",
		"hint": "FALLING SAND, a cellular automaton: a grain looks down, then down a diagonal; water also looks sideways; walls never look — press to pour",
		"dials": { "cols": 60, "rows": 40,
			"material": "sand",         # what a press pours: "sand", "water" or "wall"
			"mix": 0.3,                 # the spout's share of water
			"spoutRate": 4,             # cells poured per step
			"stepsPerSec": 60.0,        # automaton ticks per second
			"spread": 4,                # how far water looks sideways in one tick
			"leak": 0.15,               # chance per tick that the bowl's hole passes a cell
			"label": "sand: ↓ else ↙ or ↘ · water: ↓, ↙↘, else ← → · one cell, one look" },
		"rhyme": { "name": "Silt", "hint": "the same rules at half the tick rate with a spout that is mostly water, and a press that pours water — a slow, wet world that pools",
			"dials": { "material": "water", "mix": 0.85, "stepsPerSec": 30.0 } } },
	{ "id": "liquid", "letter": "L", "name": "Liquid",
		"hint": "TILE FLUIDS: a MASS per cell levels out with its neighbours by a flow fraction — or, in fire mode, spreads by chance to ash — press to pour",
		"dials": { "cols": 48, "rows": 30,
			"mode": "water",            # "water" or "fire"
			"flow": 0.25,               # fraction of a sideways difference that moves per tick
			"compress": 0.02,           # extra mass a cell holds under a full one (a little pressure)
			"stepsPerSec": 30.0,        # ticks per second
			"tap": 0.35,                # mass per tick from the tap while it runs
			"tapOn": 4.0, "tapOff": 3.0,   # the tap's rhythm, seconds
			"drain": 0.3,               # mass per tick each drain cell lets out
			"drainFrom": 0.78,          # the drain slot: the floor to the right of this fraction of the width
			"spread": 0.07,             # fire: chance per tick of catching from each burning neighbour
			"burn": 1.5,                # fire: seconds a cell burns
			"regrow": 7.0,              # fire: seconds for ash to grow back
			"fuel": 0.55,               # fire: share of the field that starts as fuel
			"strikeEvery": 4.0,         # fire: seconds between lightning strikes
			"label": "water: Δm = (m − m_side)·flow, ↓ fills first · fire: P(catch) = spread per burning neighbour" },
		"rhyme": { "name": "Lightfire", "hint": "mode fire: every burning cell tries four times as hard to spread and burns out in a third of the time — a grass fire that races and leaves ash",
			"dials": { "mode": "fire", "spread": 0.3, "burn": 0.5 } } },
]

# ---------------------------------------------------------------- helpers

static func _or1(x: float) -> float:
	return x if x != 0.0 else 1.0

## The web label's "right" alignment — Kit.label only knows left and centre.
static func _label_right(n: CanvasItem, txt: String, p: Vector2, col: Color) -> void:
	var f := ThemeDB.fallback_font
	var x := p.x - f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	n.draw_string(f, Vector2(x, p.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)

## ctx.globalAlpha: the same colour, its alpha multiplied.
static func _a(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * alpha)

## The web kit's ease: smoothstep, clamped.
static func _ease(k: float) -> float:
	var kk := clampf(k, 0.0, 1.0)
	return kk * kk * (3.0 - 2.0 * kk)

## The web kit's wrapAngle: back into −π..π.
static func _wrap_angle(a: float) -> float:
	return wrapf(a, -PI, PI)

## A pie wedge (ctx.moveTo centre, arc a0..a1, closePath), filled.
static func _wedge(n: CanvasItem, c: Vector2, r: float, a0: float, a1: float, fill: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(c)
	for i in 13:
		var an: float = a0 + (a1 - a0) * i / 12.0
		pts.append(c + Vector2(cos(an), sin(an)) * r)
	n.draw_colored_polygon(pts, fill)

## A stroked rectangle in the current transform (ctx.strokeRect).
static func _stroke_rect(n: CanvasItem, r: Rect2, col: Color, w: float) -> void:
	n.draw_rect(r, col, false, w)

# ---- Robotarm: forward kinematics, angles → points (ang[0] absolute, the rest vs the parent)
static func _ra_fk(b: Dictionary) -> void:
	var nn: int = b.n
	var ang: PackedFloat32Array = b.ang
	var pts: PackedVector2Array = b.pts
	var a := 0.0
	var p := Vector2(b.bx, b.by)
	for i in nn:
		a += ang[i]
		pts[i] = p
		p += Vector2(cos(a), sin(a)) * (b.L as float)
	pts[nn] = p
	b.pts = pts

# ---- Torque: the crate's k-th corner (k = 0..3) in card space
static func _tq_corner(b: Dictionary, k: int) -> Vector2:
	var sx := 1.0 if (k == 1 or k == 2) else -1.0
	var sy := 1.0 if k >= 2 else -1.0
	var c := cos(b.ang as float)
	var s_ := sin(b.ang as float)
	var hw: float = b.cw / 2.0
	var hh: float = b.ch / 2.0
	var p: Vector2 = b.p
	return Vector2(p.x + (sx * hw) * c - (sy * hh) * s_, p.y + (sx * hw) * s_ + (sy * hh) * c)

## an impulse J applied at a world point: τ = r × J
static func _tq_impulse(b: Dictionary, at: Vector2, j: Vector2) -> void:
	var p: Vector2 = b.p
	b.v += j / (b.m as float)
	b.av += ((at.x - p.x) * j.y - (at.y - p.y) * j.x) / (b.I as float)

## a corner pressed pen px into a plane with normal nrm
static func _tq_contact(b: Dictionary, D: Dictionary, at: Vector2, nrm: Vector2, pen: float) -> void:
	b.p += nrm * pen                                     # push out
	var p: Vector2 = b.p
	var m: float = b.m
	var I: float = b.I
	var r := at - p
	var av: float = b.av
	var v: Vector2 = b.v
	var cv := Vector2(v.x - av * r.y, v.y + av * r.x)   # the corner's own velocity: v + ω × r
	var vn := cv.dot(nrm)
	if vn >= 0.0:
		return
	var rn := r.x * nrm.y - r.y * nrm.x
	var e: float = D.e if -vn > b.h * 0.15 else 0.0     # no bounce from a resting creep
	var j := -(1.0 + e) * vn / (1.0 / m + rn * rn / I)
	_tq_impulse(b, at, nrm * j)
	var tg := Vector2(-nrm.y, nrm.x)                     # and friction, along the plane
	av = b.av
	v = b.v
	var cv2 := Vector2(v.x - av * r.y, v.y + av * r.x)
	var vt := cv2.dot(tg)
	var rt := r.x * tg.y - r.y * tg.x
	var jt := clampf(-vt / (1.0 / m + rt * rt / I), -D.mu * j, D.mu * j)
	_tq_impulse(b, at, tg * jt)

## the corner nearest the finger takes the push, halfway out along its diagonal
static func _tq_shove(b: Dictionary, D: Dictionary, m: Vector2) -> void:
	var best := 0
	var bd := 1e9
	for k in 4:
		var d := _tq_corner(b, k).distance_to(m)
		if d < bd:
			bd = d
			best = k
	var c := _tq_corner(b, best)
	var p: Vector2 = b.p
	var at := (c + p) / 2.0
	var dv := at - m
	var d := _or1(dv.length())
	var J: float = b.h * D.shove * (b.m as float)
	var f := dv / d * J
	_tq_impulse(b, at, f)
	b.fr = { "at": at, "f": f, "tau": (at.x - p.x) * f.y - (at.y - p.y) * f.x }   # the last shove: contact, force, τ
	b.flash = 1.2

# ---- Hinge: the one integrator all the hinges share
static func _hinge_step(h: Dictionary, tau: float, dt: float, I: float) -> void:
	h.w += tau / I * dt
	h.a += h.w * dt

# ---- Yield: the nearest link point to the finger, over every strand
static func _yield_grab(b: Dictionary, D: Dictionary, m: Vector2) -> void:
	var links: int = D.links
	var bs := -1
	var bi := -1
	var bd := 1e9
	var strands: Array = b.strands
	for s_ in strands.size():
		var pts: PackedVector2Array = strands[s_].pts
		for i in range(1, links + 1):
			var d := pts[i].distance_to(m)
			if d < bd:
				bd = d
				bs = s_
				bi = i
	var hand: Dictionary = b.hand
	hand.s = bs
	hand.i = bi

# ---- Grab: un-parent the held crate and hand it a velocity
static func _grab_throw(b: Dictionary, D: Dictionary, tp: Vector2) -> void:
	var c: Dictionary = b.crates[b.held]
	var dv := tp - (c.p as Vector2)
	var d := _or1(dv.length())
	var sm: float = sqrt(D.mass)
	var v0: float = b.w * D.throwV / sm
	c.v += dv / d * v0 + Vector2(0.0, -b.h * D.lob / sm)
	c.held = false
	b.ap = c.p
	b.av = c.v
	b.flash = 0.8
	b.held = -1
	b.fetch = -1

# ---- Artillery: launch angles to hit p; y is measured UP. Pure: returns { ok, lo, hi }.
static func _art_solve(b: Dictionary, D: Dictionary, p: Vector2) -> Dictionary:
	var v: float = b.w * D.v
	var g: float = b.h * D.g
	var x: float = p.x - b.gx
	var y: float = b.gyy - p.y
	var disc := v * v * v * v - g * (g * x * x + 2.0 * y * v * v)
	if disc < 0.0 or x < 2.0:
		return { "ok": false, "lo": 0.0, "hi": 0.0 }
	var r := sqrt(disc)
	return { "ok": true, "lo": atan2(v * v - r, g * x), "hi": atan2(v * v + r, g * x) }

# ---- Yardstick: the terrain (pure), the hand's height, one fixed step of the flight code
static func _ys_terrain(b: Dictionary, D: Dictionary, x: float) -> float:
	return b.gy - b.h * D.hills * (Kit.noise(x / b.w * D.bumps + 3.3) + 1.0) / 2.0

static func _ys_hy0(b: Dictionary, D: Dictionary) -> float:
	return _ys_terrain(b, D, b.sx) - 22.0

static func _ys_velocity_for(b: Dictionary, D: Dictionary, p: Vector2) -> Vector2:
	var dv := p - Vector2(b.sx, _ys_hy0(b, D))
	var d := _or1(dv.length())
	var k: float = clampf(d / (b.w * D.pull), 0.0, 1.0) * b.w * D.power
	return dv / d * k

## one step of the flight code on a { p, v } dictionary; true when it is under the ground or off the sides
static func _ys_step(b: Dictionary, D: Dictionary, ball: Dictionary) -> bool:
	var step: float = D.step
	var v: Vector2 = ball.v
	v.y += b.h * D.g * step
	var p: Vector2 = ball.p
	p += v * step
	ball.v = v
	ball.p = p
	return p.y >= _ys_terrain(b, D, p.x) or p.x > b.w + 4.0 or p.x < -4.0

static func _ys_throw(b: Dictionary, D: Dictionary) -> void:
	var v := _ys_velocity_for(b, D, b.aim)
	var ball: Dictionary = b.ball
	ball.p = Vector2(b.sx, _ys_hy0(b, D))
	ball.v = v
	ball.acc = 0.0
	ball.flying = true
	ball.rest = false
	b.aiming = false
	b.idle = 0.0

# ---- Sand: a wall drawn as a line of cells, in fractions of the grid
static func _sand_wall(g: PackedInt32Array, cols: int, rows: int, x0: float, y0: float, x1: float, y1: float) -> void:
	var nn := int(maxf(absf(x1 - x0), absf(y1 - y0)) * cols)
	for i in nn + 1:
		var cx := int(roundf((x0 + (x1 - x0) * i / nn) * (cols - 1)))
		var cy := int(roundf((y0 + (y1 - y0) * i / nn) * (rows - 1)))
		g[cy * cols + cx] = 3
		if cy + 1 < rows:
			g[(cy + 1) * cols + cx] = 3

## "free" for a grain of material m: empty, or water when the grain is sand
static func _sand_free(m: int, v: int) -> bool:
	return v == 0 or (m == 1 and v == 2)

## one automaton tick: bottom-up, the scan direction flipping every tick so nothing leans
static func _sand_tick(b: Dictionary, D: Dictionary) -> void:
	var cols: int = b.cols
	var rows: int = b.rows
	var g: PackedInt32Array = b.g
	var spread: int = D.spread
	b.flip = not b.flip
	b.ticks += 1
	var flip: bool = b.flip
	for y in range(rows - 2, -1, -1):
		var row := y * cols
		for k in cols:
			var x := k if flip else cols - 1 - k
			var i := row + x
			var m := g[i]
			if m == 0 or m == 3:
				continue
			var bl := i + cols
			if _sand_free(m, g[bl]):                              # ↓
				g[i] = g[bl]
				g[bl] = m
				continue
			var d := 1 if randf() < 0.5 else -1
			for s_ in 2:                                          # ↙ or ↘, in a random order
				var dd := -d if s_ == 1 else d
				var nx := x + dd
				if nx < 0 or nx >= cols:
					continue
				var j := bl + dd
				if _sand_free(m, g[j]) and g[i + dd] != 3:
					g[i] = g[j]
					g[j] = m
					m = 0
					break
			if m != 2:
				continue
			for s_ in range(1, spread + 1):                       # water: ← → to the nearest gap
				var nx := x + d * s_
				if nx < 0 or nx >= cols:
					break
				var j := row + nx
				if g[j] == 0:
					g[j] = 2
					g[i] = 0
					break
				if g[j] != 2:
					break
	var last := (rows - 1) * cols
	for x in cols:                                                # the drain
		g[last + x] = 0
	if randf() < D.leak:                                          # the bowl's slow hole
		g[b.hole] = 0
		g[b.hole2] = 0
	b.spout = clampf(0.5 + Kit.noise(b.ticks * 0.004) * 0.36, 0.14, 0.86)
	var rate: int = D.spoutRate
	for _k in rate:
		var x := clampi(int(roundf(b.spout * cols + randf_range(-2.0, 2.0))), 0, cols - 1)
		var i := int(floorf(randf_range(0.0, 2.0))) * cols + x
		if g[i] == 0:
			g[i] = 2 if randf() < D.mix else 1
	b.g = g

# ---- Liquid: how much the LOWER of two cells should hold
static func _lq_stable(D: Dictionary, total: float) -> float:
	var compress: float = D.compress
	if total <= 1.0:
		return 1.0
	if total < 2.0 + compress:
		return (1.0 + total * compress) / (1.0 + compress)
	return (total + compress) / 2.0

static func _lq_tick_water(b: Dictionary, D: Dictionary) -> void:
	var cols: int = b.cols
	var rows: int = b.rows
	var N := cols * rows
	var kind: PackedInt32Array = b.kind
	var mass: PackedFloat32Array = b.mass
	var next: PackedFloat32Array = b.next
	var flow: float = D.flow
	for i in N:
		next[i] = mass[i]
	for y in rows:
		for x in cols:
			var i := y * cols + x
			if kind[i] == 1 or mass[i] <= 0.0005:
				continue
			var rem: float = mass[i]
			var f := 0.0
			var bl := i + cols
			if y + 1 < rows and kind[bl] != 1:              # down: fill the cell below to its stable share
				f = clampf(_lq_stable(D, rem + mass[bl]) - mass[bl], 0.0, minf(rem, 1.0))
				next[i] -= f
				next[bl] += f
				rem -= f
			if rem <= 0.0:
				continue
			if kind[i - 1] != 1:                            # left: a fraction of the difference
				f = clampf((rem - mass[i - 1]) * flow, 0.0, rem)
				next[i] -= f
				next[i - 1] += f
				rem -= f
			if rem <= 0.0:
				continue
			if kind[i + 1] != 1:                            # right
				f = clampf((rem - mass[i + 1]) * flow, 0.0, rem)
				next[i] -= f
				next[i + 1] += f
				rem -= f
			if rem <= 0.0 or y == 0 or kind[i - cols] == 1:
				continue
			f = clampf(rem - _lq_stable(D, rem), 0.0, rem)  # up: only what pressure cannot hold
			next[i] -= f
			next[i - cols] += f
	for i in N:
		mass[i] = 0.0 if kind[i] == 1 else next[i]
	var drain_x0: int = b.drainX0
	var drain: float = D.drain
	for x in range(drain_x0, cols - 1):                     # the slot in the floor
		var i := (rows - 2) * cols + x
		mass[i] = maxf(0.0, mass[i] - drain)
	b.tapX = clampf(0.4 + Kit.noise(b.ticks * 0.003) * 0.3, 0.1, 0.65)
	var period: float = D.tapOn + D.tapOff
	if fmod(b.tapT as float, period) < D.tapOn:
		var i := cols + int(roundf(b.tapX * cols))
		mass[i] = minf(1.0, mass[i] + D.tap)
	b.mass = mass
	b.next = next

static func _lq_tick_fire(b: Dictionary, D: Dictionary, step: float) -> void:
	var cols: int = b.cols
	var N: int = b.cols * b.rows
	var kind: PackedInt32Array = b.kind
	var timer: PackedFloat32Array = b.timer
	var spread: float = D.spread
	var burn: float = D.burn
	var burning := 0
	for i in N:
		var k := kind[i]
		if k == 3:
			burning += 1
			timer[i] -= step
			if timer[i] <= 0.0:
				kind[i] = 4
				timer[i] = D.regrow * randf_range(0.6, 1.6)
				continue
			var x := i % cols
			if x > 0 and kind[i - 1] == 2 and randf() < spread:
				kind[i - 1] = 5
				timer[i - 1] = burn
			if x < cols - 1 and kind[i + 1] == 2 and randf() < spread:
				kind[i + 1] = 5
				timer[i + 1] = burn
			if i >= cols and kind[i - cols] == 2 and randf() < spread * 1.5:
				kind[i - cols] = 5
				timer[i - cols] = burn
			if i + cols < N and kind[i + cols] == 2 and randf() < spread * 0.6:
				kind[i + cols] = 5
				timer[i + cols] = burn
		elif k == 4:
			timer[i] -= step
			if timer[i] <= 0.0:
				kind[i] = 2
	for i in N:                                             # the newly lit burn from the next tick
		if kind[i] == 5:
			kind[i] = 3
	b.burning = burning
	b.kind = kind
	b.timer = timer

static func _lq_ignite(b: Dictionary, D: Dictionary, cx: int, cy: int) -> void:
	var cols: int = b.cols
	var kind: PackedInt32Array = b.kind
	var timer: PackedFloat32Array = b.timer
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var i := (cy + dy) * cols + cx + dx
			if kind[i] == 2 or kind[i] == 4:
				kind[i] = 3
				timer[i] = D.burn
	b.kind = kind
	b.timer = timer

# ---------------------------------------------------------------- init

static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	match b.id:
		"robotarm":
			# CYCLIC COORDINATE DESCENT, the third IK. Ik solved two bones exactly;
			# Fabrik slid points along lines. CCD keeps ANGLES: starting at the joint
			# nearest the tip, rotate that joint so the tip swings toward the target,
			# then the next joint down, then the next; one sweep leaves an error, a
			# few sweeps make it small. because the state is one angle per joint, an
			# ANGLE LIMIT is a single clamp — the wedge at each joint is that limit,
			# a joint pinned at its limit glows red, and a target outside the wedges
			# is honestly not reached (the miss is printed at the top).
			var nn: int = D.n
			b.n = nn
			b.L = b.h * D.bone
			b.bx = b.w / 2.0
			b.by = b.gy
			var ang := PackedFloat32Array()
			ang.resize(nn)
			ang.fill(0.0)
			ang[0] = -PI / 2.0                           # ang[0] is absolute, the rest are vs the parent
			b.ang = ang
			var pts := PackedVector2Array()
			pts.resize(nn + 1)                           # the tip is point n
			b.pts = pts
			b.target = Vector2(b.w * 0.7, b.h * 0.3)
			b.sticky = 0.0
			_ra_fk(b)
		"quadruped":
			# Gait triggered each step by a THRESHOLD; a quadruped is easier to run
			# from a PHASE TABLE: one clock per stride, and every leg is that clock
			# plus an OFFSET. below the duty fraction the foot is planted (it slides
			# back at ground speed); above it, it swings forward on Gait's sin(kπ)
			# arc. the whole difference between a walk, a trot and a gallop is four
			# numbers. the body is a critically damped spring toward the legs' mean
			# support: fewer feet down, and it sinks and pitches, for free.
			var gaits: Dictionary = D.gaits
			var names: Array = gaits.keys()
			b.names = names
			b.gi = maxi(0, names.find(D.gait))
			b.LEG = b.h * D.leg
			b.BODY = b.w * D.body
			b.fx = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
			b.fy = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
			b.ph = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
			b.phase = 0.0
			b.v = 0.0
			b.scroll = 0.0
			b.bodyY = b.gy - (b.LEG as float) * 1.75
			b.bodyV = 0.0
			b.pitch = 0.0
			b.pitchV = 0.0
			b.T = D.cycle
			b.frac = 0.0
			b.down = 4
		"jangle":
			# SECONDARY MOTION: nothing here is animated, and everything moves. each
			# chain point is a verlet particle (Rope) with one extra promise — a
			# spring toward its REST position, the place it would be if it were glued
			# to the body. the body hops; the rest poses hop with it instantly; the
			# points arrive late (the spring), overshoot (the verlet velocity) and
			# settle (the damping). the faint dots are the rest poses, so the lag is
			# visible as the gap between dot and hair.
			var R := 11.0
			b.R = R
			b.seg = b.h * D.seg
			var links: int = D.links
			b.chains = []
			for s_ in (D.chains as Array):
				var ln: float = s_.len
				var nn := maxi(2, int(roundf(links * ln)))
				var pts := []
				for _i in nn:
					pts.append({ "p": Vector2(b.w / 2.0, b.gy - R), "pp": Vector2(b.w / 2.0, b.gy - R), "r": Vector2.ZERO })
				b.chains.append({ "s": s_, "pts": pts })
			b.p = Vector2(b.w * 0.3, b.gy - R)
			b.v = Vector2.ZERO
			b.face = 1.0
			b.hopT = 0.6
			b.flash = 0.0
			b.fp = Vector2.ZERO
		"cloth":
			# CLOTH is Rope in two directions. every point is verlet; every promise is
			# a distance constraint (Rope's), but there are three families of them:
			# STRUCTURAL (to the four neighbours — the weave), SHEAR (to the four
			# diagonals — without them the squares collapse into diamonds) and BEND
			# (to the point two away — without them it folds like paper along any
			# line). shear and bend are solved SOFTER, by a fraction, so the cloth
			# drapes instead of standing like a board. the highlighted cell shows one
			# of each family. the wind is one noise() call per point.
			var cols: int = D.cols
			var rows: int = D.rows
			var S: float = b.h * D.spacing
			var x0: float = b.w / 2.0 - (cols - 1) * S / 2.0
			var y0: float = b.h * 0.08
			var top: bool = D.pins == "top"
			var P := PackedVector2Array()
			var pin := PackedInt32Array()
			for r in rows:
				for c in cols:
					P.append(Vector2(x0 + c * S, y0 + r * S))
					pin.append(1 if (r == 0 and (top or c == 0 or c == cols - 1)) else 0)
			b.P = P
			b.PP = P.duplicate()
			b.pin = pin
			var ca := PackedInt32Array()                 # the promises: [a, b, rest, strength]
			var cb := PackedInt32Array()
			var cr := PackedFloat32Array()
			var cs := PackedFloat32Array()
			var shear: float = D.shear
			var bend: float = D.bend
			for r in rows:
				for c in cols:
					var i := r * cols + c
					if c + 1 < cols:
						ca.append(i); cb.append(i + 1); cr.append(S); cs.append(1.0)
					if r + 1 < rows:
						ca.append(i); cb.append(i + cols); cr.append(S); cs.append(1.0)
					if c + 1 < cols and r + 1 < rows:
						ca.append(i); cb.append(i + cols + 1); cr.append(S * sqrt(2.0)); cs.append(shear)
						ca.append(i + 1); cb.append(i + cols); cr.append(S * sqrt(2.0)); cs.append(shear)
					if c + 2 < cols:
						ca.append(i); cb.append(i + 2); cr.append(S * 2.0); cs.append(bend)
					if r + 2 < rows:
						ca.append(i); cb.append(i + 2 * cols); cr.append(S * 2.0); cs.append(bend)
			b.ca = ca
			b.cb = cb
			b.cr = cr
			b.cs = cs
			b.held = -1
			b.hold_at = Vector2.ZERO
			b.hold = 0.0
		"bridge":
			# Rope with both ends pinned. the trick that makes it SAG under a load is
			# Rope's inverse-mass weighting: a link point carrying the walker weighs
			# (1 + walker) link masses, so when a constraint corrects the pair, the
			# light neighbour does nearly all the moving — and gravity, which pulls
			# every point equally, wins at the heavy one. the walker rides the chain
			# (its position is an interpolation along the links) and its weight moves
			# with it, so the dip follows the feet. a dropped crate is the same rule
			# with a bigger number.
			var nn: int = D.n
			b.n = nn
			b.ax = b.w * 0.08
			b.bx = b.w * 0.92
			b.ay = b.h * 0.42
			b.rest = (b.bx - b.ax) * D.slack / (nn - 1)
			var P := PackedVector2Array()
			var inv := PackedFloat32Array()
			for i in nn:
				P.append(Vector2(b.ax + (b.bx - b.ax) * i / (nn - 1), b.ay))
				inv.append(1.0)
			b.P = P
			b.PP = P.duplicate()
			b.inv = inv
			b.crates = []
			b.s = 0.0                                    # the walker's place along the chain, in points
			b.dir = 1.0
			b.i0 = 0
			b.i1 = 1
			b.f = 0.0
		"torque":
			# a rigid body remembers an ANGLE and an ANGULAR VELOCITY next to its
			# position and velocity. a push at the centre only moves it; a push off
			# centre also spins it, by the TORQUE τ = r × F — the lever arm r (from
			# the centre to where you pushed) crossed with the force. τ/I is the
			# angular acceleration, and I, the moment of inertia, is how the mass is
			# spread: a long plank is hard to spin. a corner meeting the floor is
			# Knock's impulse again, but applied AT the corner, so it both bounces
			# the body and spins it — that is what makes a tumbling crate tumble.
			var ch: float = b.h * D.size
			var cw: float = ch * D.aspect
			var m: float = D.mass
			b.ch = ch
			b.cw = cw
			b.m = m
			b.I = m * (cw * cw + ch * ch) / 12.0
			b.p = Vector2(b.w / 2.0, b.gy - ch)
			b.v = Vector2.ZERO
			b.ang = 0.3
			b.av = 0.0
			b.pokeT = 1.2
			b.fr = { "at": Vector2.ZERO, "f": Vector2.ZERO, "tau": 0.0 }   # the last shove: contact, force, τ
			b.flash = 0.0
		"hinge":
			# a HINGE removes every freedom but one: the body keeps an angle θ and a
			# spin ω about a fixed pivot, and all that physics may do is add TORQUE.
			# Pendulum was a hinge with gravity as its only torque. here three hinges
			# share one integrator and differ only in what τ is: the door's is a
			# spring toward shut plus damping (a door closer) and two hard stops; the
			# windmill's is a VELOCITY MOTOR, τ = k(ω₀ − ω); the drawbridge's is
			# gravity (m·g·L·cosθ, pulling it down) against a POSITION MOTOR with a
			# torque cap, so a heavy beam rises slowly and drops fast. the wheel is
			# the same hinge with a runner inside as its motor.
			b.hg = [{ "a": 0.0, "w": 0.0 }, { "a": 0.0, "w": 0.0 }, { "a": -1.3, "w": 0.0 }]   # door, mill, bridge (wheel mode uses the mill's)
			b.bridgeTarget = 0.0
			b.bridgeT = 0.0
			b.pushT = 1.4
			b.sprint = 0.0
			b.side = 1.0
			b.phi = 0.0
			b.tauM = 0.0
			b.tauG = 0.0
			b.tauW = 0.0
			b.vrun = 0.0
		"yield":
			# Rope's promise was "restore the rest length, every round, forever". a
			# BREAKABLE constraint adds one test after the solve: how stretched is the
			# link — d ÷ rest, its STRAIN — and past a limit the promise is deleted.
			# nothing else changes: the points below the tear keep falling with the
			# same verlet, they just no longer have anyone above them to obey. the
			# few solver rounds are honest too: they leave most of the stretch near
			# the hand, so the chain tears where you pull it, not at the roof.
			var seg: float = b.h * D.seg
			var S: int = D.strands
			var links: int = D.links
			var gap: float = minf(b.w * 0.24, b.w * 0.84 / S)
			b.seg = seg
			b.strands = []
			for s_ in S:
				var x: float = b.w / 2.0 + (s_ - (S - 1) / 2.0) * gap
				var pts := PackedVector2Array()
				var alive := PackedInt32Array()
				var strain := PackedFloat32Array()
				for i in links + 1:
					pts.append(Vector2(x, b.h * 0.05 + i * seg))
					if i > 0:
						alive.append(1)
						strain.append(1.0)
				b.strands.append({ "x0": x, "pts": pts, "pp": pts.duplicate(), "alive": alive, "strain": strain, "tornAt": -1.0 })
			b.hand = { "s": -1, "i": -1, "p": Vector2.ZERO, "hold": 0.0, "auto": 0.0, "f": Vector2.ZERO, "t": Vector2.ZERO }
			b.pullT = 1.2
		"grab":
			# three verbs, three couplings. FETCH walks to a crate. GRAB parents it:
			# the crate's goal is now a point fixed to the hand (Nest's child offset).
			# HOLD is a spring toward that goal — ω and ζ, from Damp — so the crate
			# swings and lags as the body moves instead of being welded on. THROW
			# un-parents it and hands it a velocity: whatever the spring had already
			# given it, plus the aim, plus a LOB straight up, so a throw at a floor
			# target still arcs. from there it is Knock's world: gravity, a bounce,
			# friction to a stop. mass divides the spring and the throw honestly.
			var S: float = b.h * D.size
			var count: int = D.crates
			b.S = S
			b.crates = []
			for i in count:
				b.crates.append({ "p": Vector2(b.w * (0.25 + 0.5 * i / maxi(1, count - 1)), b.gy - S / 2.0), "v": Vector2.ZERO, "held": false })
			b.x = b.w * 0.5
			b.face = 1.0
			b.held = -1
			b.holdT = 0.0
			b.fetch = -1
			b.flash = 0.0
			b.ap = Vector2.ZERO
			b.av = Vector2.ZERO
		"artillery":
			# a shell's path is a parabola, and a parabola through the muzzle and the
			# target at a known speed has at most TWO launch angles: the LOW shot,
			# flat and quick, and the HIGH shot, a lob that falls in from above.
			# solving y = x·tanθ − g·x²/(2v²cos²θ) for tanθ is a quadratic, so both
			# roots fall out of one square root — and a negative discriminant means
			# honestly out of range. the drone moves, so the gun leads it Chase-style:
			# solve, read the flight time, solve again for where it will be by then.
			b.gx = b.w * 0.08
			b.gyy = b.gy - 6.0
			b.tp = Vector2(b.w * 0.65, b.h * 0.35)
			b.tv = Vector2.ZERO
			b.sticky = 0.0
			b.fireT = 0.8
			b.useHigh = false
			b.hit = 0.0
			b.hp = Vector2.ZERO
			b.lastAng = -0.6
			b.outOfRange = false
			b.shells = []
			b.sol = { "ok": false, "lo": 0.0, "hi": 0.0 }
			b.aimAng = -0.6
			b.ap = b.tp
		"yardstick":
			# the honest preview: not a formula for the arc but the FLIGHT CODE ITSELF,
			# run ahead with the same fixed step, drawing a dot per step, until a dot
			# is under the ground — Xmarks' test, once per dot. the throw then
			# advances by the same fixed step (an accumulator turns any frame's dt
			# into whole steps), so the ball lands on the X the dots promised. change
			# the integrator and both change together; that is the whole design.
			b.sx = b.w * 0.1
			b.aim = Vector2(b.sx + b.w * 0.25, _ys_hy0(b, D) - b.h * 0.2)
			b.aiming = false
			b.since = 1.0
			b.idle = 0.0
			b.ghost = -1.0
			b.g0 = Vector2.ZERO
			b.g1 = Vector2.ZERO
			b.ball = { "p": Vector2(b.sx, 0.0), "v": Vector2.ZERO, "acc": 0.0, "flying": false, "rest": true }
		"sand":
			# a CELLULAR AUTOMATON has no bodies, no velocities, no vectors — only a
			# grid, and one rule each cell applies by looking at its neighbours. SAND:
			# if the cell below is free, move there; else try one diagonal, then the
			# other (that alone gives heaps with a slope). WATER: the same, and if
			# nothing below is free, slide sideways up to `spread` cells (that alone
			# gives a flat surface). sand sinks through water because "free" for sand
			# includes water. the scan runs bottom-up and flips direction every tick so
			# nothing leans; the bottom row is a drain, so the loop never fills up.
			var cols: int = D.cols
			var rows: int = D.rows
			b.cols = cols
			b.rows = rows
			b.cw = b.w / cols
			b.chh = (b.h - 20.0) / rows
			b.y0 = 2.0
			var g := PackedInt32Array()                  # 0 empty · 1 sand · 2 water · 3 wall
			g.resize(cols * rows)
			g.fill(0)
			_sand_wall(g, cols, rows, 0.06, 0.28, 0.42, 0.46)   # the funnel
			_sand_wall(g, cols, rows, 0.94, 0.28, 0.58, 0.46)
			_sand_wall(g, cols, rows, 0.28, 0.66, 0.4, 0.86)    # the bowl
			_sand_wall(g, cols, rows, 0.4, 0.86, 0.6, 0.86)
			_sand_wall(g, cols, rows, 0.72, 0.66, 0.6, 0.86)
			b.g = g
			b.hole = int(roundf(0.5 * (cols - 1))) + int(roundf(0.86 * (rows - 1))) * cols
			b.hole2 = b.hole + cols
			b.acc = 0.0
			b.flip = false
			b.spout = 0.5
			b.ticks = 0
		"liquid":
			# Sand moved whole cells; TILE WATER moves a NUMBER. each cell holds a mass
			# from 0 to 1 (a little more under pressure). every tick it gives what it
			# can DOWN first (the cell below fills to its stable share), then shares a
			# FRACTION of any difference with its left and right neighbours — that
			# fraction is what makes a poured heap of water flatten into a level, and
			# how fast. FIRE is the other classic cell rule: a burning cell tries, by
			# chance, to light each fuel neighbour every tick, burns for a while, and
			# leaves ash, which slowly grows back. same grid, same four neighbours.
			var cols: int = D.cols
			var rows: int = D.rows
			var N := cols * rows
			b.cols = cols
			b.rows = rows
			b.cw = b.w / cols
			b.chh = (b.h - 20.0) / rows
			b.y0 = 2.0
			var kind := PackedInt32Array()               # water: 0 air, 1 wall · fire: 0 air, 1 wall, 2 fuel, 3 burning, 4 ash, 5 just lit
			kind.resize(N)
			kind.fill(0)
			var mass := PackedFloat32Array()
			mass.resize(N)
			mass.fill(0.0)
			var seed := Kit.rng(11)
			var fire: bool = D.mode == "fire"
			b.fire = fire
			var fuel: float = D.fuel
			var shelf_y := int(roundf(rows * 0.55))
			var weir_x := int(roundf(cols * 0.72))
			for y in rows:
				for x in cols:
					var i := y * cols + x
					if x == 0 or x == cols - 1 or y == rows - 1:
						kind[i] = 1
					elif not fire:
						if y == shelf_y and x > cols * 0.15 and x < cols * 0.6:
							kind[i] = 1                  # a shelf
						if x == weir_x and y > rows * 0.35 and y < rows * 0.8:
							kind[i] = 1                  # a weir, with a gap under it
					elif y > rows * 0.35 and seed.randf() < fuel * clampf((y - rows * 0.35) / (rows * 0.4), 0.3, 1.0):
						kind[i] = 2
			b.kind = kind
			b.mass = mass
			b.next = mass.duplicate()
			b.timer = mass.duplicate()
			b.drainX0 = int(roundf(cols * D.drainFrom))
			b.acc = 0.0
			b.tapX = 0.4
			b.tapT = 0.0
			b.strikeT = 1.5
			b.ticks = 0
			b.burning = 0

# ---------------------------------------------------------------- press

static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	match b.id:
		"robotarm":
			b.target = pos
			b.sticky = D.sticky
		"quadruped":
			b.gi = (b.gi + 1) % (b.names as Array).size()
		"jangle":
			var dv: Vector2 = (b.p as Vector2) - pos
			var d := _or1(dv.length())
			b.v += dv / d * b.h * D.shove + Vector2(0.0, -b.h * 0.2)   # shoved away from the finger
			b.flash = 0.4
			b.fp = pos
		"cloth":
			var P: PackedVector2Array = b.P
			var pin: PackedInt32Array = b.pin
			var best := -1
			var bd := 1e9
			for i in P.size():
				if pin[i] == 1:
					continue
				var d := P[i].distance_to(pos)
				if d < bd:
					bd = d
					best = i
			b.held = best
			b.hold_at = pos
			b.hold = 0.12
		"bridge":
			var crates: Array = b.crates
			crates.append({ "p": Vector2(clampf(pos.x, b.ax + 6.0, b.bx - 6.0), minf(pos.y, b.ay - 10.0)), "vy": 0.0, "at": -1, "life": D.weightLife })
			if crates.size() > 4:
				crates.pop_front()
		"torque":
			_tq_shove(b, D, pos)
		"hinge":
			if D.mode == "wheel":
				b.sprint = 1.6
			else:
				var px: float = b.w * 0.2
				var L: float = b.w * 0.14
				var door: Dictionary = b.hg[0]
				var tip_x: float = px + sin(door.a as float) * L
				door.w += D.push if pos.x < tip_x else -D.push   # pushed from the side you are on
		"yield":
			_yield_grab(b, D, pos)
			var hand: Dictionary = b.hand
			hand.p = pos
			hand.hold = 0.15
			hand.auto = 0.0
		"grab":
			if b.held >= 0:
				_grab_throw(b, D, pos)
				return
			var crates: Array = b.crates
			var best := 0
			var bd := 1e9
			for i in crates.size():
				var d := (crates[i].p as Vector2).distance_to(pos)
				if d < bd:
					bd = d
					best = i
			b.fetch = best
		"artillery":
			b.tp = Vector2(clampf(pos.x, b.gx + 20.0, b.w - 6.0), clampf(pos.y, 8.0, b.gy - 8.0))
			b.tv = Vector2.ZERO
			b.sticky = D.sticky
		"yardstick":
			b.aim = pos
			b.aiming = true
			b.since = 0.0
			b.ghost = -1.0
		"sand":
			var cols: int = b.cols
			var rows: int = b.rows
			var cx := clampi(int(floorf(pos.x / b.cw)), 1, cols - 2)
			var cy := clampi(int(floorf((pos.y - b.y0) / b.chh)), 1, rows - 3)
			var m := 3 if D.material == "wall" else (2 if D.material == "water" else 1)
			var g: PackedInt32Array = b.g
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var i := (cy + dy) * cols + cx + dx
					if m == 3 or g[i] == 0:
						g[i] = m
			b.g = g
		"liquid":
			var cols: int = b.cols
			var rows: int = b.rows
			var cx := clampi(int(floorf(pos.x / b.cw)), 1, cols - 2)
			var cy := clampi(int(floorf((pos.y - b.y0) / b.chh)), 1, rows - 3)
			if b.fire:
				_lq_ignite(b, D, cx, cy)
				return
			var kind: PackedInt32Array = b.kind
			var mass: PackedFloat32Array = b.mass
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var i := (cy + dy) * cols + cx + dx
					if kind[i] != 1:
						mass[i] = minf(1.0, mass[i] + 1.0)
			b.mass = mass

# ---------------------------------------------------------------- tick

## Quadruped: hip x for leg i — fronts (LF, RF) ahead, hinds (LH, RH) behind
static func _q_hipx(b: Dictionary, i: int) -> float:
	return (b.BODY as float) / 2.0 * (1.0 if i < 2 else -1.0)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var D: Dictionary = b.D
	match b.id:
		"robotarm":
			var nn: int = b.n
			b.sticky -= dt
			var tgt: Vector2 = b.target
			if b.sticky <= 0.0:
				tgt = Vector2(b.bx + cos(t * 0.5) * b.w * D.roamX, b.by - b.h * 0.3 + sin(t * 0.8) * b.h * D.roamY)
				b.target = tgt
			var ang: PackedFloat32Array = b.ang
			var iters: int = D.iters
			var limit: float = D.limit
			var base_limit: float = D.baseLimit
			for _it in iters:
				for j in range(nn - 1, -1, -1):              # tip first, base last
					_ra_fk(b)
					var pts: PackedVector2Array = b.pts
					var a1 := atan2(pts[nn].y - pts[j].y, pts[nn].x - pts[j].x)   # the tip, seen from joint j
					var a2 := atan2(tgt.y - pts[j].y, tgt.x - pts[j].x)           # the target, seen from joint j
					var a: float = ang[j] + _wrap_angle(a2 - a1)
					if j == 0:
						a = -PI / 2.0 + clampf(_wrap_angle(a + PI / 2.0), -base_limit, base_limit)
					else:
						a = clampf(_wrap_angle(a), -limit, limit)
					ang[j] = a
					b.ang = ang
			_ra_fk(b)
		"quadruped":
			var names: Array = b.names
			var gaits: Dictionary = D.gaits
			var off: Array = gaits[names[b.gi]]
			var maxv: float = b.w * D.maxv
			var want: float = maxv * (0.35 + 0.65 * (Kit.noise(t * 0.25) + 1.0) / 2.0)   # the autopilot's mood
			b.v += (want - b.v) * Kit.smooth(2.0, dt)
			var frac := clampf(b.v / maxv, 0.0, 1.0)
			var T: float = D.cycle / maxf(0.25, frac)
			b.phase = fmod(b.phase + dt / T, 1.0)
			b.scroll = fmod(b.scroll + b.v * dt, 26.0)
			var stride: float = b.w * D.stride * frac
			var lift: float = b.h * D.lift
			var duty: float = D.duty
			var cx: float = b.w * 0.5
			var fx: PackedFloat32Array = b.fx
			var fy: PackedFloat32Array = b.fy
			var ph: PackedFloat32Array = b.ph
			var down := 0
			var front_down := 0
			var hind_down := 0
			for i in 4:
				var hip_x := _q_hipx(b, i)
				var phi: float = fmod(b.phase + off[i], 1.0)
				ph[i] = phi
				if phi < duty:                               # STANCE: planted, sliding back at ground speed
					var k := phi / duty
					fx[i] = cx + hip_x + stride / 2.0 - k * stride
					fy[i] = b.gy
					down += 1
					if hip_x > 0.0:
						front_down += 1
					else:
						hind_down += 1
				else:                                        # SWING: the arc forward
					var k := (phi - duty) / (1.0 - duty)
					fx[i] = cx + hip_x - stride / 2.0 + stride * _ease(k)
					fy[i] = b.gy - sin(k * PI) * lift
			var w: float = D.omega
			var want_y: float = b.gy - (b.LEG as float) * 1.75 + (4 - down) * 2.5   # fewer feet: it sinks
			b.bodyV += (w * w * (want_y - b.bodyY) - 2.0 * w * b.bodyV) * dt
			b.bodyY += b.bodyV * dt
			var want_p: float = (hind_down - front_down) * 0.05                     # and pitches
			b.pitchV += (w * w * (want_p - b.pitch) - 2.0 * w * b.pitchV) * dt
			b.pitch += b.pitchV * dt
			b.fx = fx
			b.fy = fy
			b.ph = ph
			b.T = T
			b.frac = frac
			b.down = down
		"jangle":
			var R: float = b.R
			var seg: float = b.seg
			b.hopT -= dt
			b.flash -= dt
			var p: Vector2 = b.p
			var v: Vector2 = b.v
			var face: float = b.face
			var on_ground: bool = p.y >= b.gy - R - 0.5
			if on_ground:
				v.x += (face * b.w * D.run - v.x) * Kit.smooth(6.0, dt)
				if b.hopT <= 0.0:
					v.y = -b.h * D.hopV
					b.hopT = D.hopEvery
			v.y += b.h * D.bodyG * dt
			p += v * dt
			if p.y > b.gy - R:
				p.y = b.gy - R
				v.y = 0.0
			if p.x < b.w * D.margin:
				p.x = b.w * D.margin
				face = 1.0
				v.x = absf(v.x)
			if p.x > b.w * (1.0 - D.margin):
				p.x = b.w * (1.0 - D.margin)
				face = -1.0
				v.x = -absf(v.x)
			b.p = p
			b.v = v
			b.face = face
			var k := Kit.smooth(D.stiff, dt)
			var dmp := pow(D.damp, dt * 60.0)
			var G: float = b.h * D.g
			for c in (b.chains as Array):
				var s_: Dictionary = c.s
				var ang: float = s_.ang if face > 0.0 else PI - s_.ang
				var dir: float = s_.dir if face > 0.0 else PI - s_.dir
				var a := p + Vector2(cos(ang), sin(ang)) * R
				var u := Vector2(cos(dir), sin(dir)) * seg
				var P: Array = c.pts
				var nn := P.size()
				for i in nn:                                 # the rest pose
					var pt: Dictionary = P[i]
					pt.r = a + u * i
				var root: Dictionary = P[0]                  # the root is glued
				root.p = a
				root.pp = a
				for i in range(1, nn):
					var pt: Dictionary = P[i]
					var mv: Vector2 = ((pt.p as Vector2) - (pt.pp as Vector2)) * dmp
					pt.pp = pt.p
					var pp_: Vector2 = pt.p
					var r: Vector2 = pt.r
					var sx := clampf(mv.x + (r.x - pp_.x) * k, -seg, seg)          # never more than one link per step
					var sy := clampf(mv.y + (r.y - pp_.y) * k + G * dt * dt, -seg, seg)
					pt.p = pp_ + Vector2(sx, sy)
				for _it in 8:                                # keep the links their length
					for i in range(1, nn):
						var pa: Dictionary = P[i - 1]
						var pb: Dictionary = P[i]
						var d: Vector2 = (pb.p as Vector2) - (pa.p as Vector2)
						var dl := _or1(d.length())
						var err := (dl - seg) / dl
						if i == 1:
							pb.p -= d * err
						else:
							pa.p += d * err / 2.0
							pb.p -= d * err / 2.0
		"cloth":
			b.hold -= dt
			var cols: int = D.cols
			var rows: int = D.rows
			var cap: float = b.h * 0.04
			var G: float = b.h * D.g
			var damp: float = D.damp
			var wind_rate: float = D.windRate
			var wind_k: float = b.h * D.wind
			var P: PackedVector2Array = b.P
			var PP: PackedVector2Array = b.PP
			var pin: PackedInt32Array = b.pin
			for r in rows:
				for c in cols:
					var i := r * cols + c
					if pin[i] == 1:
						continue
					var p := P[i]
					var pp := PP[i]
					var v := Vector2(clampf((p.x - pp.x) * damp, -cap, cap), clampf((p.y - pp.y) * damp, -cap, cap))
					PP[i] = p
					var wind := Kit.noise(t * wind_rate + c * 0.06 + r * 0.11) * wind_k
					P[i] = p + v + Vector2(wind * dt * dt, G * dt * dt)
			var ca: PackedInt32Array = b.ca
			var cb: PackedInt32Array = b.cb
			var cr: PackedFloat32Array = b.cr
			var cs: PackedFloat32Array = b.cs
			var nc := ca.size()
			var rounds: int = D.rounds
			var held: int = b.held
			var holding: bool = held >= 0 and b.hold > 0.0
			var hold_at: Vector2 = b.hold_at
			for _it in rounds:
				for k in nc:
					var ia := ca[k]
					var ib := cb[k]
					var pa := pin[ia] == 1
					var pb := pin[ib] == 1
					if pa and pb:
						continue
					var a := P[ia]
					var bb := P[ib]
					var d := bb - a
					var dl := _or1(d.length())
					var err := (dl - cr[k]) / dl * cs[k]
					if pa:
						P[ib] = bb - d * err
					elif pb:
						P[ia] = a + d * err
					else:
						P[ia] = a + d * err / 2.0
						P[ib] = bb - d * err / 2.0
				if holding:
					P[held] = hold_at
					PP[held] = hold_at
				for i in P.size():
					var p := P[i]
					if p.y > b.gy - 2.0:
						p.y = b.gy - 2.0
						p.x -= (p.x - PP[i].x) * 0.5
					p.x = clampf(p.x, 3.0, b.w - 3.0)
					P[i] = p
			b.P = P
			b.PP = PP
		"bridge":
			var nn: int = b.n
			var rest: float = b.rest
			b.s += b.dir * b.w * D.speed / rest * dt
			if b.s > nn - 1:
				b.s = float(nn - 1)
				b.dir = -1.0
			if b.s < 0.0:
				b.s = 0.0
				b.dir = 1.0
			var P: PackedVector2Array = b.P
			var PP: PackedVector2Array = b.PP
			var inv: PackedFloat32Array = b.inv
			inv.fill(1.0)                                    # rebuild the masses: walker, then crates
			var s: float = b.s
			var i0 := int(floorf(s))
			var f := s - i0
			var i1 := mini(nn - 1, i0 + 1)
			var walker: float = D.walker
			var weight: float = D.weight
			inv[i0] = 1.0 / (1.0 + walker * (1.0 - f))
			inv[i1] = 1.0 / (1.0 + walker * f)
			var crates: Array = b.crates
			for c in crates:
				c.life -= dt
				if c.at < 0:                                 # falling
					c.vy += b.h * D.g * dt
					var cp: Vector2 = c.p
					cp.y += c.vy * dt
					c.p = cp
					var k := 0
					for i in range(1, nn):
						if absf(P[i].x - cp.x) < absf(P[k].x - cp.x):
							k = i
					if cp.y >= P[k].y - 6.0:
						c.at = k
						c.vy = 0.0
				else:
					var at: int = c.at
					inv[at] = 1.0 / (1.0 / inv[at] + weight)
			for i in range(crates.size() - 1, -1, -1):
				if crates[i].life <= 0.0:
					crates.remove_at(i)
			inv[0] = 0.0                                     # the anchors never move
			inv[nn - 1] = 0.0
			var cap: float = b.h * 0.04
			var G: float = b.h * D.g
			var damp: float = D.damp
			for i in range(1, nn - 1):
				var p := P[i]
				var pp := PP[i]
				var v := Vector2(clampf((p.x - pp.x) * damp, -cap, cap), clampf((p.y - pp.y) * damp, -cap, cap))
				PP[i] = p
				P[i] = p + v + Vector2(0.0, G * dt * dt)
			var rounds: int = D.rounds
			for _it in rounds:
				for i in nn - 1:
					var a := P[i]
					var bb := P[i + 1]
					var d := bb - a
					var dl := _or1(d.length())
					var err := (dl - rest) / dl
					var wsum := _or1(inv[i] + inv[i + 1])
					P[i] = a + d * err * inv[i] / wsum
					P[i + 1] = bb - d * err * inv[i + 1] / wsum
			for i in range(1, nn - 1):
				if P[i].y > b.gy - 4.0:
					var p := P[i]
					p.y = b.gy - 4.0
					P[i] = p
			b.P = P
			b.PP = PP
			b.inv = inv
			b.i0 = i0
			b.i1 = i1
			b.f = f
		"torque":
			b.pokeT -= dt
			b.flash -= dt
			if b.pokeT <= 0.0:
				b.pokeT = D.shoveEvery
				var a := randf_range(-PI, 0.0)
				_tq_shove(b, D, (b.p as Vector2) + Vector2(cos(a) * b.cw, sin(a) * b.ch))
			var v: Vector2 = b.v
			v.y += b.h * D.g * dt
			b.v = v
			b.p += v * dt
			b.ang += b.av * dt
			b.av *= pow(0.995, dt * 60.0)
			for _it in 2:
				for k in 4:
					var c := _tq_corner(b, k)
					if c.y > b.gy:
						_tq_contact(b, D, c, Vector2(0.0, -1.0), c.y - b.gy)
					c = _tq_corner(b, k)
					if c.x < 0.0:
						_tq_contact(b, D, c, Vector2(1.0, 0.0), -c.x)
					c = _tq_corner(b, k)
					if c.x > b.w:
						_tq_contact(b, D, c, Vector2(-1.0, 0.0), c.x - b.w)
					c = _tq_corner(b, k)
					if c.y < 0.0:
						_tq_contact(b, D, c, Vector2(0.0, 1.0), -c.y)
		"hinge":
			if D.mode == "wheel":                            # ---- the hamster wheel
				var R: float = b.h * 0.3
				var hh: Dictionary = b.hg[1]
				b.sprint -= dt
				var vrun: float = b.w * D.run * (0.3 + 0.7 * (Kit.noise(t * 0.3) + 1.0) / 2.0) * (2.0 if b.sprint > 0.0 else 1.0)
				var rim: float = hh.w * R                    # the rim's speed under the feet
				var phi := clampf((rim - vrun) * 0.02, -1.2, 1.2)   # carried up when the wheel outruns the runner
				var tau: float = 3.0 * (vrun - rim) - D.damping * hh.w * R - 120.0 * sin(phi)   # feet, bearing, the runner's weight
				_hinge_step(hh, tau, dt, R * 2.0)
				b.phi = phi
				b.vrun = vrun
				return
			b.pushT -= dt
			b.bridgeT += dt
			var door: Dictionary = b.hg[0]
			var mill: Dictionary = b.hg[1]
			var br: Dictionary = b.hg[2]
			if b.pushT <= 0.0:
				b.pushT = D.pushEvery
				b.side = -b.side
				door.w += b.side * D.push
			if b.bridgeT > D.bridgeEvery:
				b.bridgeT = 0.0
				b.bridgeTarget = -1.3 if b.bridgeTarget == 0.0 else 0.0
			var door_limit: float = D.doorLimit
			_hinge_step(door, -D.doorK * door.a - D.doorC * door.w, dt, 1.0)   # the closer
			if door.a > door_limit:                          # the stops
				door.a = door_limit
				if door.w > 0.0:
					door.w = -door.w * 0.3
			if door.a < -door_limit:
				door.a = -door_limit
				if door.w < 0.0:
					door.w = -door.w * 0.3
			var tau_m: float = D.motorK * (D.motorW - mill.w)
			_hinge_step(mill, tau_m - 0.1 * mill.w, dt, 1.0)
			var tau_g: float = D.g * cos(br.a as float)     # weight pulls the far end down
			var tau_w := clampf(D.bridgeK * (b.bridgeTarget - br.a) - D.bridgeC * br.w, -D.bridgeMax, D.bridgeMax)
			_hinge_step(br, tau_g + tau_w, dt, 4.0)
			if br.a > 0.0:                                   # resting on the far bank
				br.a = 0.0
				br.w = 0.0
			if br.a < -1.45:
				br.a = -1.45
				br.w = 0.0
			b.tauM = tau_m
			b.tauG = tau_g
			b.tauW = tau_w
		"yield":
			var hand: Dictionary = b.hand
			var S: int = D.strands
			var links: int = D.links
			var seg: float = b.seg
			var strands: Array = b.strands
			hand.hold -= dt
			b.pullT -= dt
			if hand.hold <= 0.0 and hand.auto <= 0.0 and b.pullT <= 0.0:   # the idle hand picks a bottom and pulls
				b.pullT = D.pullEvery
				var s_ := mini(int(floorf(randf_range(0.0, S))), S - 1)
				var st: Dictionary = strands[s_]
				var p: Vector2 = (st.pts as PackedVector2Array)[links]
				hand.s = s_
				hand.i = links
				hand.f = p
				hand.t = Vector2(clampf(p.x + randf_range(-1.0, 1.0) * b.h * D.pullDist, 10.0, b.w - 10.0), minf(b.gy - 6.0, p.y + b.h * D.pullDist * 0.7))
				hand.auto = D.pullTime
			if hand.auto > 0.0:
				hand.auto -= dt
				var k: float = 1.0 - clampf(hand.auto / D.pullTime, 0.0, 1.0)
				hand.p = (hand.f as Vector2).lerp(hand.t, k)
			var pinned: bool = hand.hold > 0.0 or hand.auto > 0.0
			var hand_s: int = hand.s
			var hand_i: int = hand.i
			var hand_p: Vector2 = hand.p
			var cap: float = b.h * 0.04
			var G: float = b.h * D.g
			var damp: float = D.damp
			var rounds: int = D.rounds
			var limit: float = D.limit
			for s_ in S:
				var st: Dictionary = strands[s_]
				var P: PackedVector2Array = st.pts
				var PP: PackedVector2Array = st.pp
				var alive: PackedInt32Array = st.alive
				var strain: PackedFloat32Array = st.strain
				if st.tornAt >= 0.0 and t - st.tornAt > D.heal:          # re-knit
					st.tornAt = -1.0
					for i in links + 1:
						P[i] = Vector2(st.x0, b.h * 0.05 + i * seg)
						PP[i] = P[i]
					alive.fill(1)
				for i in range(1, links + 1):
					var p := P[i]
					var pp := PP[i]
					var v := Vector2(clampf((p.x - pp.x) * damp, -cap, cap), clampf((p.y - pp.y) * damp, -cap, cap))
					PP[i] = p
					P[i] = p + v + Vector2(0.0, G * dt * dt)
				for _it in rounds:
					for i in links:
						if alive[i] == 0:
							continue
						var a := P[i]
						var bb := P[i + 1]
						var d := bb - a
						var dl := _or1(d.length())
						var err := (dl - seg) / dl
						if i == 0:
							P[1] = bb - d * err
						else:
							P[i] = a + d * err / 2.0
							P[i + 1] = bb - d * err / 2.0
					if pinned and hand_s == s_:
						P[hand_i] = hand_p
						PP[hand_i] = hand_p
					for i in range(1, links + 1):
						var p := P[i]
						if p.y > b.gy - 2.0:
							p.y = b.gy - 2.0
							p.x -= (p.x - PP[i].x) * 0.5
						p.x = clampf(p.x, 3.0, b.w - 3.0)
						P[i] = p
				for i in links:                                          # the test that makes them breakable
					if alive[i] == 0:
						continue
					strain[i] = (P[i + 1] - P[i]).length() / seg
					if strain[i] > limit:
						alive[i] = 0
						if st.tornAt < 0.0:
							st.tornAt = t
				st.pts = P
				st.pp = PP
				st.alive = alive
				st.strain = strain
		"grab":
			b.flash -= dt
			var crates: Array = b.crates
			var S: float = b.S
			var x: float = b.x
			var face: float = b.face
			if b.held < 0 and b.fetch < 0:                   # choose the nearest resting crate
				var bd := 1e9
				for i in crates.size():
					var c: Dictionary = crates[i]
					var cp: Vector2 = c.p
					var d := absf(cp.x - x)
					if not c.held and cp.y > b.gy - S and d < bd:
						bd = d
						b.fetch = i
			if b.held < 0 and b.fetch >= 0:
				var c: Dictionary = crates[b.fetch]
				var cp: Vector2 = c.p
				var dx := cp.x - x
				if absf(dx) > 4.0:
					face = 1.0 if dx > 0.0 else -1.0
					x += face * b.w * D.speed * dt
				if Vector2(dx, cp.y - (b.gy - 9.0)).length() < b.w * D.reach and cp.y > b.gy - S * 1.5:
					b.held = b.fetch
					c.held = true
					b.holdT = D.holdTime
			elif b.held >= 0:
				b.holdT -= dt
				x += face * b.w * D.speed * 0.5 * dt         # strolls while holding, so the spring has work
				if x < b.w * 0.15:
					face = 1.0
				if x > b.w * 0.85:
					face = -1.0
				if b.holdT <= 0.0:
					_grab_throw(b, D, Vector2(x - face * randf_range(b.w * 0.3, b.w * 0.6), b.gy - b.h * randf_range(0.05, 0.3)))
			b.x = x
			b.face = face
			var hand := Vector2(x + face * 13.0, b.gy - 9.0 - 22.0)   # the hand: a child of the body
			var w: float = D.omega / sqrt(D.mass)
			var zeta: float = D.zeta
			var e: float = D.e
			for c in crates:
				var cp: Vector2 = c.p
				var cv: Vector2 = c.v
				if c.held:                                   # the spring toward the hand
					cv += (w * w * (hand - cp) - 2.0 * zeta * w * cv) * dt
					cp += cv * dt
					c.p = cp
					c.v = cv
					continue
				cv.y += b.h * D.g * dt
				cp += cv * dt
				if cp.y > b.gy - S / 2.0:
					cp.y = b.gy - S / 2.0
					if cv.y > b.h * 0.1:
						cv.y = -cv.y * e
					else:
						cv.y = 0.0
					cv.x *= 1.0 - Kit.smooth(D.friction, dt)
				if cp.x < S / 2.0:
					cp.x = S / 2.0
					cv.x = absf(cv.x) * e
				if cp.x > b.w - S / 2.0:
					cp.x = b.w - S / 2.0
					cv.x = -absf(cv.x) * e
				if cp.y < S / 2.0:
					cp.y = S / 2.0
					cv.y = absf(cv.y) * e
				c.p = cp
				c.v = cv
		"artillery":
			b.sticky -= dt
			b.fireT -= dt
			b.hit -= dt
			var tp: Vector2 = b.tp
			var tv: Vector2 = b.tv
			var ts: float = D.targetSpeed
			if b.sticky <= 0.0:                              # the drone: a slow figure across the sky
				var np := Vector2(b.w * 0.62 + sin(t * ts * 4.0) * b.w * 0.26, b.h * 0.36 + sin(t * ts * 7.0) * b.h * 0.16)
				tv = (np - tp) / maxf(dt, 1e-3)
				tp = np
			var sol := _art_solve(b, D, tp)
			b.outOfRange = not sol.ok
			var pick: String = D.pick
			var want_high: bool = pick == "high" or (pick == "both" and b.useHigh)
			var aim_ang: float = b.lastAng
			var ap := tp
			if sol.ok:
				aim_ang = sol.hi if want_high else sol.lo
				var T: float = (tp.x - b.gx) / maxf(1.0, cos(aim_ang) * b.w * D.v)   # flight time → lead the target
				ap = tp + tv * T
				sol = _art_solve(b, D, ap)
				if sol.ok:
					aim_ang = sol.hi if want_high else sol.lo
				b.lastAng = aim_ang
			var shells: Array = b.shells
			if b.fireT <= 0.0 and sol.ok:
				b.fireT = D.fireEvery
				var v: float = b.w * D.v
				shells.append({ "p": Vector2(b.gx, b.gyy), "v": Vector2(cos(aim_ang) * v, -sin(aim_ang) * v), "high": want_high })
				if pick == "both":
					b.useHigh = not b.useHigh
				if shells.size() > 6:
					shells.pop_front()
			for i in range(shells.size() - 1, -1, -1):
				var s_: Dictionary = shells[i]
				var sv: Vector2 = s_.v
				sv.y += b.h * D.g * dt
				var sp: Vector2 = (s_.p as Vector2) + sv * dt
				s_.p = sp
				s_.v = sv
				if sp.distance_to(tp) < 10.0:
					b.hit = 0.5
					b.hp = sp
					shells.remove_at(i)
					continue
				if sp.y > b.gy or sp.x > b.w + 10.0:
					shells.remove_at(i)
			b.tp = tp
			b.tv = tv
			b.sol = sol
			b.aimAng = aim_ang
			b.ap = ap
		"yardstick":
			b.since += dt
			b.idle += dt
			if b.aiming and b.since > 0.15:                  # the finger lifted
				_ys_throw(b, D)
			var ball: Dictionary = b.ball
			if not b.aiming and b.ghost < 0.0 and b.idle > D.autoEvery:   # the idle thrower draws its own aim
				b.ghost = 0.0
				var hy0 := _ys_hy0(b, D)
				b.g0 = Vector2(b.sx + 20.0, hy0 - 10.0)
				b.g1 = Vector2(b.sx + randf_range(b.w * 0.15, b.w * 0.45), hy0 - randf_range(b.h * 0.05, b.h * 0.35))
			if b.ghost >= 0.0:
				b.ghost += dt
				var k := _ease(b.ghost / 1.2)
				b.aim = (b.g0 as Vector2) + ((b.g1 as Vector2) - (b.g0 as Vector2)) * k
				if b.ghost > 1.4:
					b.ghost = -1.0
					b.aiming = true
					b.since = 0.0
					_ys_throw(b, D)
			if ball.flying:
				var step: float = D.step
				ball.acc = minf(ball.acc + dt, 0.5)          # never more than ten steps owed
				while ball.acc >= step and ball.flying:
					ball.acc -= step
					if _ys_step(b, D, ball):
						var p: Vector2 = ball.p
						p.y = minf(p.y, _ys_terrain(b, D, p.x))
						ball.p = p
						var v: Vector2 = ball.v
						if v.y > b.h * 0.25 and p.x > 0.0 and p.x < b.w:
							v.y = -v.y * D.e
							v.x *= 0.6
							ball.v = v
						else:
							ball.flying = false
							ball.rest = true
							ball.v = Vector2.ZERO
		"sand":
			b.acc += dt
			var step: float = 1.0 / D.stepsPerSec
			var nn := 0
			while b.acc >= step and nn < 4:
				b.acc -= step
				_sand_tick(b, D)
				nn += 1
			if b.acc > 0.2:
				b.acc = 0.0
		"liquid":
			b.acc += dt
			b.tapT += dt
			b.strikeT -= dt
			var fire: bool = b.fire
			var step: float = 1.0 / D.stepsPerSec
			var nn := 0
			while b.acc >= step and nn < 4:
				b.acc -= step
				b.ticks += 1
				if fire:
					_lq_tick_fire(b, D, step)
				else:
					_lq_tick_water(b, D)
				nn += 1
			if b.acc > 0.2:
				b.acc = 0.0
			if fire and b.strikeT <= 0.0:                    # lightning
				b.strikeT = D.strikeEvery
				var cols: int = b.cols
				var N: int = b.cols * b.rows
				var kind: PackedInt32Array = b.kind
				for _tries in 20:
					var i := int(floorf(randf_range(cols, N - cols)))
					if kind[i] == 2:
						@warning_ignore("integer_division")   # the cell's row: an int result is intended
						var cy: int = i / cols
						_lq_ignite(b, D, i % cols, cy)
						break

# ---------------------------------------------------------------- draw

## Quadruped: one leg, two-bone IK straight from Gait (front knees point back, hind knees forward)
static func _q_leg(n: CanvasItem, b: Dictionary, i: int, hip: Vector2, dim: bool) -> void:
	var LEG: float = b.LEG
	var foot := Vector2((b.fx as PackedFloat32Array)[i], (b.fy as PackedFloat32Array)[i])
	var dv := foot - hip
	var d := clampf(dv.length(), 4.0, LEG * 2.0 - 2.0)
	var bse := atan2(dv.y, dv.x)
	var cos_a := clampf(d / (2.0 * LEG), -1.0, 1.0)     # (a² + d² − a²) / 2ad, with a = shin = thigh
	var sgn := 1.0 if _q_hipx(b, i) > 0.0 else -1.0
	var a := bse + acos(cos_a) * sgn
	var knee := hip + Vector2(cos(a), sin(a)) * LEG
	var col := Color(0.788, 0.769, 0.894, 0.45) if dim else Kit.BONE
	n.draw_polyline(PackedVector2Array([hip, knee, foot]), col, 3.5)
	Kit.dot(n, foot - Vector2(0.0, 1.5), 3.0, col)

## Artillery: the parabola for a launch angle, dotted
static func _art_arc(n: CanvasItem, b: Dictionary, D: Dictionary, theta: float, col: Color) -> void:
	var v: float = b.w * D.v
	var g: float = b.h * D.g
	var vx := cos(theta) * v
	var vy := sin(theta) * v
	for i in range(1, 60):
		var tt := i * 0.05
		var x: float = b.gx + vx * tt
		var y: float = b.gyy - (vy * tt - g * tt * tt / 2.0)
		if y > b.gy or x > b.w:
			break
		Kit.dot(n, Vector2(x, y), 1.2, col)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var D: Dictionary = b.D
	var origin: Vector2 = (b.rect as Rect2).position
	var DEF := Color(0.91, 0.898, 0.957, 0.55)
	Kit.stage(n, b)
	match b.id:
		"robotarm":
			Kit.ground(n, b)
			var nn: int = b.n
			var L: float = b.L
			var pts: PackedVector2Array = b.pts
			var ang: PackedFloat32Array = b.ang
			var tgt: Vector2 = b.target
			var limit: float = D.limit
			var base_limit: float = D.baseLimit
			Kit.ring(n, Vector2(b.bx, b.by), L * nn, Color(0.91, 0.898, 0.957, 0.08))
			var abs_a := 0.0
			for j in nn:                                     # the limit wedges, drawn in the parent's frame
				var parent := abs_a
				abs_a += ang[j]
				var hi := limit if j > 0 else base_limit
				var centre := parent if j > 0 else -PI / 2.0
				_wedge(n, pts[j], L * 0.55, centre - hi, centre + hi, Color(0.961, 0.757, 0.412, 0.12))
				var rel: float = ang[j] if j > 0 else ang[0] + PI / 2.0
				if absf(absf(rel) - hi) < 0.01:
					Kit.ring(n, pts[j], 5.5, Kit.HOT, 1.5)   # pinned at its limit
			for j in nn:
				n.draw_line(pts[j], pts[j + 1], Kit.BONE, maxf(1.5, 6.0 - j * 0.6))
			for j in nn + 1:
				Kit.dot(n, pts[j], 3.0 if j > 0 else 4.5, Kit.BONE if j > 0 else Kit.MOVER)
			n.draw_dashed_line(pts[nn], tgt, Kit.DIM, 1.0, 7.0)
			Kit.dot(n, tgt, 3.5, Kit.TARGET)
			Kit.label(n, b, "miss %d px · %d sweeps" % [roundi(tgt.distance_to(pts[nn])), int(D.iters)], Vector2(b.w / 2.0, 14.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), DEF, true)
		"quadruped":
			Kit.ground(n, b)
			var names: Array = b.names
			var gaits: Dictionary = D.gaits
			var off: Array = gaits[names[b.gi]]
			var BODY: float = b.BODY
			var cx: float = b.w * 0.5
			var ph: PackedFloat32Array = b.ph
			var body_y: float = b.bodyY
			var pitch: float = b.pitch
			var maxv: float = b.w * D.maxv
			var duty: float = D.duty
			var x: float = b.scroll - 26.0
			while x < b.w:                                   # the ground streams past
				n.draw_line(Vector2(x, b.gy + 3.0), Vector2(x - 4.0, b.gy + 9.0), Color(0.788, 0.769, 0.894, 0.35), 1.0)
				x += 26.0
			for i in [1, 3]:                                 # the far legs
				var hip_x := _q_hipx(b, i)
				_q_leg(n, b, i, Vector2(cx + hip_x, body_y + pitch * hip_x + 6.0), true)
			n.draw_set_transform(origin + Vector2(cx, body_y), pitch, Vector2.ONE)
			n.draw_rect(Rect2(-BODY / 2.0 - 6.0, -9.0, BODY + 12.0, 18.0), Kit.MOVER)
			n.draw_circle(Vector2(-BODY / 2.0 - 6.0, 0.0), 9.0, Kit.MOVER)
			n.draw_circle(Vector2(BODY / 2.0 + 6.0, 0.0), 9.0, Kit.MOVER)
			n.draw_line(Vector2(-BODY / 2.0 - 6.0, -4.0), Vector2(-BODY / 2.0 - 18.0, -14.0 - b.v / maxv * 4.0), Kit.MOVER, 2.5)   # the tail
			n.draw_circle(Vector2(BODY / 2.0 + 10.0, -8.0), 8.0, Kit.MOVER)   # the head
			n.draw_circle(Vector2(BODY / 2.0 + 13.0, -10.0), 2.0, Kit.NIGHT)  # the eye
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			for i in [0, 2]:                                 # the near legs
				var hip_x := _q_hipx(b, i)
				_q_leg(n, b, i, Vector2(cx + hip_x, body_y + pitch * hip_x + 6.0), false)
			var bw: float = b.w * 0.3                        # the phase table, the thing this card teaches
			var bx0: float = b.w * 0.04
			var by0 := 14.0
			var leg_name := ["LF", "RF", "LH", "RH"]
			Kit.label(n, b, "%s · T = %.2f s" % [names[b.gi], b.T], Vector2(bx0, by0 - 3.0), Color(0.961, 0.757, 0.412, 0.9))
			for i in 4:
				var y := by0 + 6.0 + i * 9.0
				n.draw_line(Vector2(bx0 + 16.0, y), Vector2(bx0 + 16.0 + bw * duty, y), Color(0.788, 0.769, 0.894, 0.5), 3.0)   # stance
				n.draw_line(Vector2(bx0 + 16.0 + bw * duty, y), Vector2(bx0 + 16.0 + bw, y), Color(0.608, 0.886, 0.541, 0.35), 3.0)   # swing
				Kit.dot(n, Vector2(bx0 + 16.0 + bw * ph[i], y), 2.5, Kit.BONE if ph[i] < duty else Kit.GOOD)
				Kit.label(n, b, leg_name[i], Vector2(bx0, y + 3.0), Kit.DIM)
				Kit.label(n, b, "%.2f" % (off[i] as float), Vector2(bx0 + 20.0 + bw, y + 3.0), Kit.DIM)
			_label_right(n, "v = %d%% · %d feet down" % [roundi(b.frac * 100.0), int(b.down)], Vector2(b.w - 6.0, 14.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), DEF, true)
		"jangle":
			Kit.ground(n, b)
			var R: float = b.R
			var face: float = b.face
			for c in (b.chains as Array):
				var P: Array = c.pts
				var s_: Dictionary = c.s
				var line := PackedVector2Array()
				for i in P.size():
					var pt: Dictionary = P[i]
					if i > 0:
						Kit.dot(n, pt.r, 1.2, Kit.DIM)       # where it would be, rigid
					line.append(pt.p)
				n.draw_polyline(line, s_.c, s_.w)
			Kit.mote(n, b, b.p, 0.0 if face > 0.0 else PI, Kit.MOVER, R)
			if b.flash > 0.0:
				var fl: float = b.flash
				Kit.dot(n, b.fp, 4.0 + (0.4 - fl) * 30.0, Color(0.961, 0.541, 0.541, fl))
			Kit.label(n, b, "k = %s/s · damp %s · rest pose = the faint dots" % [str(D.stiff), str(D.damp)], Vector2(b.w / 2.0, 14.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), DEF, true)
		"cloth":
			Kit.ground(n, b)
			var cols: int = D.cols
			var rows: int = D.rows
			var P: PackedVector2Array = b.P
			var pin: PackedInt32Array = b.pin
			var ca: PackedInt32Array = b.ca
			var cb: PackedInt32Array = b.cb
			var cs: PackedFloat32Array = b.cs
			var w0: float = Kit.noise(t * D.windRate) * D.wind
			Kit.arrow(n, Vector2(b.w * 0.18, b.h * 0.1), Vector2(b.w * 0.18 + w0 * 24.0, b.h * 0.1), Kit.DIM)
			Kit.label(n, b, "wind", Vector2(b.w * 0.18, b.h * 0.1 - 6.0), Kit.DIM, true)
			var weave := Color(0.541, 0.851, 0.961, 0.55)
			for k in ca.size():
				if cs[k] == 1.0:
					n.draw_line(P[ca[k]], P[cb[k]], weave, 1.0)
			var hr := int(rows / 2.0)                        # the teaching cell: one of each promise
			var hc := int(cols / 2.0)
			var c0 := P[hr * cols + hc]
			n.draw_line(c0, P[hr * cols + hc + 1], Kit.MOVER, 2.5)
			n.draw_line(c0, P[(hr + 1) * cols + hc + 1], Kit.TARGET, 2.0)
			n.draw_line(c0, P[(hr + 2 if hr + 2 < rows else hr - 2) * cols + hc], Kit.GOOD, 2.0)
			for i in P.size():
				if pin[i] == 1:
					Kit.dot(n, P[i], 3.0, Kit.BONE)
			if b.held >= 0 and b.hold > 0.0:
				Kit.ring(n, b.hold_at, 8.0, Color(0.961, 0.757, 0.412, 0.7), 1.5)
			_label_right(n, "structural", Vector2(b.w - 6.0, 14.0), Kit.MOVER)
			_label_right(n, "shear", Vector2(b.w - 6.0, 26.0), Kit.TARGET)
			_label_right(n, "bend", Vector2(b.w - 6.0, 38.0), Kit.GOOD)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), DEF, true)
		"bridge":
			Kit.ground(n, b)
			var nn: int = b.n
			var P: PackedVector2Array = b.P
			var inv: PackedFloat32Array = b.inv
			var ax: float = b.ax
			var bx: float = b.bx
			var ay: float = b.ay
			n.draw_line(Vector2(ax, ay), Vector2(ax, b.gy), Kit.BONE, 3.0)   # the posts
			n.draw_line(Vector2(bx, ay), Vector2(bx, b.gy), Kit.BONE, 3.0)
			var rail := PackedVector2Array()                 # the handrail rides the same points
			for i in nn:
				rail.append(P[i] - Vector2(0.0, 16.0))
			n.draw_polyline(rail, Color(0.788, 0.769, 0.894, 0.35), 1.0)
			n.draw_polyline(P, Kit.BONE, 2.0)
			for i in range(1, nn - 1):                       # planks, and the heavy points glow
				var m := 1.0 / inv[i]
				var p := P[i]
				n.draw_line(Vector2(p.x - 4.0, p.y + 1.0), Vector2(p.x + 4.0, p.y + 1.0), Kit.TARGET if m > 1.0 else Color(0.788, 0.769, 0.894, 0.6), 3.0)
				n.draw_line(p, Vector2(p.x, p.y - 16.0), Color(0.788, 0.769, 0.894, 0.25), 1.0)
				if m > 1.05:
					Kit.label(n, b, "×%.1f" % m, Vector2(p.x, p.y + 14.0), Color(0.961, 0.757, 0.412, 0.8), true)
			for c in (b.crates as Array):
				var at: int = c.at
				var cp: Vector2 = c.p
				var q := cp if at < 0 else Vector2(P[at].x, P[at].y - 6.0)
				n.draw_rect(Rect2(q.x - 6.0, q.y - 6.0, 12.0, 12.0), _a(Kit.HOT, clampf(c.life, 0.0, 1.0)))
			var wp := P[b.i0].lerp(P[b.i1], b.f)
			var bob := absf(sin(t * 9.0)) * 3.0
			var dir: float = b.dir
			n.draw_line(Vector2(wp.x - 4.0, wp.y), Vector2(wp.x - 2.0 + sin(t * 9.0) * 4.0, wp.y - 9.0), Kit.BONE, 2.5)   # two stick legs on Gait's clock
			n.draw_line(Vector2(wp.x + 4.0, wp.y), Vector2(wp.x + 2.0 - sin(t * 9.0) * 4.0, wp.y - 9.0), Kit.BONE, 2.5)
			n.draw_circle(Vector2(wp.x, wp.y - 15.0 - bob), 8.0, Kit.MOVER)
			n.draw_circle(Vector2(wp.x + dir * 3.0, wp.y - 17.0 - bob), 2.0, Kit.NIGHT)
			Kit.label(n, b, "walker ×%s · crate ×%s · slack %s" % [str(D.walker), str(D.weight), str(D.slack)], Vector2(b.w / 2.0, 14.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), DEF, true)
		"torque":
			Kit.ground(n, b)
			var p: Vector2 = b.p
			var ang: float = b.ang
			var av: float = b.av
			var cw: float = b.cw
			var ch: float = b.ch
			var faint := Color(0.788, 0.769, 0.894, 0.35)
			n.draw_set_transform(origin + p, ang, Vector2.ONE)
			n.draw_rect(Rect2(-cw / 2.0, -ch / 2.0, cw, ch), Color(0.788, 0.769, 0.894, 0.22))
			_stroke_rect(n, Rect2(-cw / 2.0, -ch / 2.0, cw, ch), Kit.BONE, 2.0)
			n.draw_line(Vector2(-cw / 2.0, -ch / 2.0), Vector2(cw / 2.0, ch / 2.0), faint, 1.0)
			n.draw_line(Vector2(-cw / 2.0, ch / 2.0), Vector2(cw / 2.0, -ch / 2.0), faint, 1.0)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.dot(n, p, 3.0, Kit.MOVER)
			var r := minf(cw, ch) * 0.35                     # the ω dial: an arc whose length is the spin
			var span := clampf(av * 0.25, -TAU * 0.9, TAU * 0.9)
			if absf(span) > 0.01:
				n.draw_arc(p, r, ang, ang + span, 32, Kit.TARGET, 2.0)
			if b.flash > 0.0:
				var al: float = clampf(b.flash, 0.0, 1.0)
				var fr: Dictionary = b.fr
				var at: Vector2 = fr.at
				var f: Vector2 = fr.f
				n.draw_line(p, at, _a(Kit.BONE, al), 2.0)    # the lever arm r
				Kit.label(n, b, "r", (p + at) / 2.0 + Vector2(6.0, -4.0), _a(Kit.BONE, al))
				Kit.arrow(n, at - f * 0.08, at, _a(Kit.HOT, al))   # the force F
				Kit.label(n, b, "F", at - f * 0.09 + Vector2(0.0, -6.0), _a(Kit.HOT, al), true)
				Kit.label(n, b, "τ = %.1f → α = τ/I" % ((fr.tau as float) / b.h), Vector2(b.w / 2.0, 14.0), _a(Kit.HOT, al), true)
			else:
				Kit.label(n, b, "ω = %.2f rad/s · I = %d" % [av, roundi(b.I)], Vector2(b.w / 2.0, 14.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), DEF, true)
		"hinge":
			if D.mode == "wheel":                            # ---- the hamster wheel
				Kit.ground(n, b)
				var cx: float = b.w / 2.0
				var R: float = b.h * 0.3
				var cy: float = b.gy - R - 4.0
				var c := Vector2(cx, cy)
				var hh: Dictionary = b.hg[1]
				var hw: float = hh.w
				var phi: float = b.phi
				for i in 8:
					var a: float = hh.a + i / 8.0 * TAU
					n.draw_line(c, c + Vector2(cos(a), sin(a)) * R, Color(0.788, 0.769, 0.894, 0.35), 1.0)
				Kit.ring(n, c, R, Kit.BONE, 3.0)
				Kit.ring(n, c, R * 0.12, Kit.BONE, 2.0)
				n.draw_line(c, Vector2(cx - R * 0.9, b.gy), Color(0.788, 0.769, 0.894, 0.4), 2.0)
				n.draw_line(c, Vector2(cx + R * 0.9, b.gy), Color(0.788, 0.769, 0.894, 0.4), 2.0)
				var ma := PI / 2.0 + phi
				Kit.mote(n, b, c + Vector2(cos(ma), sin(ma)) * (R - 10.0), phi * 0.6 + absf(sin(t * 14.0)) * 0.1, Kit.MOVER, 8.0)
				Kit.arrow(n, Vector2(cx, cy - R - 10.0), Vector2(cx + clampf(hw * 18.0, -60.0, 60.0), cy - R - 10.0), Kit.TARGET)
				Kit.label(n, b, "ω = %.2f · run %d px/s%s" % [hw, roundi(b.vrun), " · sprint" if b.sprint > 0.0 else ""], Vector2(b.w / 2.0, 14.0), Kit.DIM, true)
				Kit.label(n, b, "τ = k(v_run − ωR)·R − c·ω − mgR·sinφ", Vector2(b.w / 2.0, b.h - 20.0), Kit.DIM, true)
				Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), DEF, true)
				return
			var door: Dictionary = b.hg[0]
			var mill: Dictionary = b.hg[1]
			var br: Dictionary = b.hg[2]
			var door_a: float = door.a
			var door_w: float = door.w
			var mill_a: float = mill.a
			var mill_w: float = mill.w
			var br_a: float = br.a
			var door_limit: float = D.doorLimit
			# the door, from above
			var dx0: float = b.w * 0.2
			var dy0: float = b.h * 0.4
			var L: float = b.w * 0.14
			n.draw_line(Vector2(dx0, dy0 - b.h * 0.3), Vector2(dx0, dy0 - 4.0), Kit.BONE, 3.0)
			n.draw_line(Vector2(dx0, dy0 + L + 4.0), Vector2(dx0, dy0 + L + b.h * 0.08), Kit.BONE, 3.0)
			_wedge(n, Vector2(dx0, dy0), L, PI / 2.0 - door_limit, PI / 2.0 + door_limit, Color(0.961, 0.757, 0.412, 0.1))
			var tip := Vector2(dx0 + sin(door_a) * L, dy0 + cos(door_a) * L)
			n.draw_line(Vector2(dx0, dy0), tip, Kit.MOVER, 4.0)
			Kit.ring(n, Vector2(dx0, dy0), 4.0, Kit.TARGET, 1.5)
			Kit.arrow(n, tip, tip + Vector2(cos(door_a) * door_w * 8.0, -sin(door_a) * door_w * 8.0), Kit.HOT)
			Kit.label(n, b, "door: τ = −k·θ − c·ω", Vector2(dx0, dy0 + L + b.h * 0.14), Kit.DIM, true)
			# the windmill
			var mx: float = b.w * 0.5
			var my: float = b.h * 0.34
			var B: float = b.h * 0.15
			n.draw_line(Vector2(mx, my), Vector2(mx, b.gy), Kit.BONE, 3.0)
			for i in 4:
				var a := mill_a + i * PI / 2.0
				n.draw_set_transform(origin + Vector2(mx, my), a, Vector2.ONE)
				n.draw_rect(Rect2(0.0, -3.0, B, 6.0), Color(0.788, 0.769, 0.894, 0.35))
				n.draw_rect(Rect2(B * 0.3, -B * 0.12, B * 0.7, B * 0.12), Color(0.541, 0.851, 0.961, 0.35))
				n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.ring(n, Vector2(mx, my), 4.0, Kit.TARGET, 1.5)
			var mspan := clampf(mill_w * 0.5, 0.0, 5.0)
			if mspan > 0.01:
				n.draw_arc(Vector2(mx, my), B + 6.0, mill_a, mill_a + mspan, 32, Kit.GOOD, 2.0)
			Kit.label(n, b, "motor: τ = k(ω₀ − ω) = %.1f" % (b.tauM as float), Vector2(mx, b.gy + 20.0), Kit.DIM, true)
			# the drawbridge
			var bx: float = b.w * 0.7
			var by: float = b.gy
			var BL: float = b.w * 0.24
			Kit.ground(n, b)
			n.draw_line(Vector2(bx, by), Vector2(bx, by - b.h * 0.36), Kit.BONE, 3.0)   # the tower
			var e := Vector2(bx + cos(br_a) * BL, by + sin(br_a) * BL)
			n.draw_line(Vector2(bx, by - b.h * 0.36), e, Color(0.788, 0.769, 0.894, 0.4), 1.0)   # the chain
			n.draw_line(Vector2(bx, by), e, Kit.MOVER, 5.0)
			Kit.ring(n, Vector2(bx, by), 4.0, Kit.TARGET, 1.5)
			var cm := (Vector2(bx, by) + e) / 2.0
			var tau_g: float = b.tauG
			var tau_w: float = b.tauW
			Kit.arrow(n, cm, cm + Vector2(0.0, tau_g * 1.6), Kit.HOT)   # gravity's torque, at the beam's middle
			Kit.arrow(n, e, e + Vector2(sin(br_a) * tau_w * 1.2, -cos(br_a) * tau_w * 1.2), Kit.GOOD)   # the winch
			Kit.label(n, b, "bridge: τ = mgL·cosθ + winch(±%s)" % str(D.bridgeMax), Vector2(bx + BL * 0.2, by - b.h * 0.36 - 6.0), Kit.DIM, true)
			Kit.label(n, b, "θ door %.2f · mill ω %.2f · bridge %.2f → %.1f" % [door_a, mill_w, br_a, b.bridgeTarget], Vector2(b.w / 2.0, 14.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), DEF, true)
		"yield":
			Kit.ground(n, b)
			var links: int = D.links
			var limit: float = D.limit
			var heal: float = D.heal
			var strands: Array = b.strands
			var hand: Dictionary = b.hand
			for st in strands:
				var P: PackedVector2Array = st.pts
				var alive: PackedInt32Array = st.alive
				var strain: PackedFloat32Array = st.strain
				var x0: float = st.x0
				Kit.dot(n, Vector2(x0, b.h * 0.05), 4.0, Kit.BONE)
				for i in links:
					var a := P[i]
					var bb := P[i + 1]
					if alive[i] == 0:                        # the tear: two frayed ends
						Kit.dot(n, a, 2.5, Kit.HOT)
						Kit.dot(n, bb, 2.5, Kit.HOT)
						continue
					var k := clampf((strain[i] - 1.0) / (limit - 1.0), 0.0, 1.0)
					n.draw_line(a, bb, Kit.BONE.lerp(Kit.HOT, k), 3.0 - k)   # BONE → HOT as the strain grows
				for i in range(1, links + 1):
					Kit.dot(n, P[i], 1.8, Kit.BONE)
				if st.tornAt >= 0.0:
					Kit.label(n, b, "torn · %d s" % roundi(maxf(0.0, heal - (t - st.tornAt))), Vector2(x0, b.h * 0.05 - 6.0), Color(0.961, 0.541, 0.541, 0.7), true)
			var pinned: bool = hand.hold > 0.0 or hand.auto > 0.0
			if pinned and hand.s >= 0:
				var hp: Vector2 = hand.p
				Kit.ring(n, hp, 8.0, Color(0.961, 0.757, 0.412, 0.8), 1.5)
				var st: Dictionary = strands[hand.s]
				var i: int = mini(hand.i, links) - 1
				if i >= 0 and (st.alive as PackedInt32Array)[i] == 1:
					Kit.label(n, b, "strain %.2f / %s" % [(st.strain as PackedFloat32Array)[i], str(limit)], hp + Vector2(0.0, -14.0), Kit.TARGET, true)
			_label_right(n, "BONE → HOT as strain → limit", Vector2(b.w - 6.0, 14.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), DEF, true)
		"grab":
			Kit.ground(n, b)
			var S: float = b.S
			var crates: Array = b.crates
			var x: float = b.x
			var face: float = b.face
			var held: int = b.held
			var hand := Vector2(x + face * 13.0, b.gy - 9.0 - 22.0)
			var w: float = D.omega / sqrt(D.mass)
			if b.flash > 0.0:
				var al: float = clampf(b.flash, 0.0, 1.0)
				var ap: Vector2 = b.ap
				var av: Vector2 = b.av
				Kit.arrow(n, ap, ap + av * 0.25, _a(Kit.HOT, al))
				Kit.label(n, b, "v = spring + aim + lob", ap + Vector2(0.0, -12.0), _a(Kit.HOT, al), true)
			for c in crates:
				var cp: Vector2 = c.p
				var is_held: bool = c.held
				var r := Rect2(cp.x - S / 2.0, cp.y - S / 2.0, S, S)
				n.draw_rect(r, Color(0.961, 0.757, 0.412, 0.35) if is_held else Color(0.788, 0.769, 0.894, 0.25))
				_stroke_rect(n, r, Kit.TARGET if is_held else Kit.BONE, 1.5)
			if held >= 0:
				var c: Dictionary = crates[held]
				n.draw_dashed_line(hand, c.p, Kit.TARGET, 1.0, 5.0)
				Kit.dot(n, hand, 3.0, Kit.TARGET)
				Kit.label(n, b, "ω %.1f ζ %s" % [w, str(D.zeta)], hand + Vector2(0.0, -10.0 - S), Kit.TARGET, true)
			elif b.fetch >= 0:
				Kit.ring(n, Vector2(x, b.gy - 9.0), b.w * D.reach, Color(0.608, 0.886, 0.541, 0.35))
			Kit.mote(n, b, Vector2(x, b.gy - 9.0), 0.0 if face > 0.0 else PI)
			Kit.label(n, b, ("hold · %.1f s" % maxf(0.0, b.holdT)) if held >= 0 else "fetch", Vector2(b.w / 2.0, 14.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), DEF, true)
		"artillery":
			Kit.ground(n, b)
			var gx: float = b.gx
			var gyy: float = b.gyy
			var tp: Vector2 = b.tp
			var ap: Vector2 = b.ap
			var aim_ang: float = b.aimAng
			var sol := _art_solve(b, D, tp)                 # draw both roots at the target's true place
			if sol.ok:
				_art_arc(n, b, D, sol.lo, Color(0.608, 0.886, 0.541, 0.7))
				_art_arc(n, b, D, sol.hi, Color(0.788, 0.627, 0.961, 0.7))
				Kit.label(n, b, "low θ = %d°" % roundi(rad_to_deg(sol.lo)), Vector2(gx + 30.0, gyy - 4.0), Kit.GOOD)
				Kit.label(n, b, "high θ = %d°" % roundi(rad_to_deg(sol.hi)), Vector2(gx + 30.0, gyy - 16.0), Kit.MAGIC)
			else:
				Kit.label(n, b, "disc < 0 — out of range", Vector2(gx + 30.0, gyy - 8.0), Kit.HOT)
			var bl := 18.0                                   # the barrel, aimed with the root in use
			n.draw_line(Vector2(gx, gyy), Vector2(gx + cos(aim_ang) * bl, gyy - sin(aim_ang) * bl), Color(0.788, 0.769, 0.894, 0.9), 5.0)
			Kit.dot(n, Vector2(gx, gyy), 7.0, Kit.MOVER)
			for s_ in (b.shells as Array):
				Kit.dot(n, s_.p, 3.0, Kit.MAGIC if s_.high else Kit.GOOD)
			n.draw_dashed_line(tp, Vector2(tp.x, b.gy), Kit.DIM, 1.0, 6.0)
			n.draw_dashed_line(Vector2(gx, b.gy), Vector2(tp.x, b.gy), Kit.DIM, 1.0, 6.0)
			Kit.label(n, b, "x", Vector2((gx + tp.x) / 2.0, b.gy + 12.0), Kit.DIM, true)
			Kit.label(n, b, "y", Vector2(tp.x + 6.0, (tp.y + b.gy) / 2.0), Kit.DIM)
			if b.sticky <= 0.0 and sol.ok:
				Kit.ring(n, ap, 4.0, Color(0.961, 0.757, 0.412, 0.4))   # the led aim point
			Kit.ring(n, tp, 7.0, Kit.TARGET, 2.0)
			n.draw_line(tp - Vector2(10.0, 0.0), tp + Vector2(10.0, 0.0), Kit.TARGET, 1.0)
			n.draw_line(tp - Vector2(0.0, 10.0), tp + Vector2(0.0, 10.0), Kit.TARGET, 1.0)
			if b.hit > 0.0:
				var hit: float = b.hit
				Kit.ring(n, b.hp, 8.0 + (0.5 - hit) * 40.0, Color(0.961, 0.541, 0.541, clampf(hit * 2.0, 0.0, 1.0)), 2.0)
			Kit.label(n, b, "v = %s W/s · fires %s%s" % [str(D.v), D.pick, " · holding" if b.outOfRange else ""], Vector2(b.w / 2.0, 14.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), DEF, true)
		"yardstick":
			var sx: float = b.sx
			var hy0 := _ys_hy0(b, D)
			var aim: Vector2 = b.aim
			var ball: Dictionary = b.ball
			var ground := PackedVector2Array()               # the terrain
			ground.append(Vector2(0.0, b.h))
			var x := 0.0
			while x <= b.w + 6.0:
				ground.append(Vector2(x, _ys_terrain(b, D, x)))
				x += 6.0
			var ridge := ground.slice(1)
			ground.append(Vector2(b.w, b.h))
			n.draw_colored_polygon(ground, Color(0.788, 0.769, 0.894, 0.18))
			n.draw_polyline(ridge, Color(0.788, 0.769, 0.894, 0.6), 1.5)
			var show_aim: bool = b.aiming or b.ghost >= 0.0 or not ball.flying
			if show_aim:                                     # the preview: the flight code, run ahead
				var v := _ys_velocity_for(b, D, aim)
				var pr := { "p": Vector2(sx, hy0), "v": v }
				var mark := Vector2(-1.0, -1.0)
				var mark_n := 0
				var dots: int = D.dots
				for i in dots:
					var done := _ys_step(b, D, pr)
					mark_n += 1
					var pp: Vector2 = pr.p
					if done:
						mark = Vector2(pp.x, minf(pp.y, _ys_terrain(b, D, pp.x)))
						break
					var odd := i % 2 == 1
					Kit.dot(n, pp, 1.2 if odd else 2.0, Color(0.961, 0.757, 0.412, 0.45) if odd else Color(0.961, 0.757, 0.412, 0.9))
				if mark.x >= 0.0:
					n.draw_line(mark + Vector2(-5.0, -5.0), mark + Vector2(5.0, 5.0), Kit.HOT, 2.0)
					n.draw_line(mark + Vector2(-5.0, 5.0), mark + Vector2(5.0, -5.0), Kit.HOT, 2.0)
				Kit.arrow(n, Vector2(sx, hy0), Vector2(sx, hy0) + v * 0.12, Kit.TARGET)
				Kit.label(n, b, "v₀ = %d px/s · %d steps of %s s%s" % [roundi(v.length()), mark_n, str(D.step), " → hit" if mark.x >= 0.0 else " → no hit yet"], Vector2(b.w / 2.0, 14.0), Kit.DIM, true)
				if b.ghost >= 0.0:
					Kit.ring(n, aim, 6.0, Color(0.91, 0.898, 0.957, 0.4), 1.5)
			else:
				Kit.label(n, b, "flying: acc += dt; while acc ≥ step: one step", Vector2(b.w / 2.0, 14.0), Kit.DIM, true)
			Kit.mote(n, b, Vector2(sx, _ys_terrain(b, D, sx) - 9.0), 0.0)
			var bp: Vector2 = ball.p
			if not ball.rest or ball.flying:
				Kit.dot(n, bp, 4.0, Kit.MOVER)
			elif bp.x != sx:
				Kit.dot(n, bp, 4.0, Color(0.541, 0.851, 0.961, 0.6))
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), DEF, true)
		"sand":
			var cols: int = b.cols
			var rows: int = b.rows
			var cw: float = b.cw
			var chh: float = b.chh
			var y0: float = b.y0
			var g: PackedInt32Array = b.g
			var water := Color(0.541, 0.851, 0.961, 0.75)
			var wall := Color(0.788, 0.769, 0.894, 0.7)
			for y in rows:                                   # draw in runs: one rect per stretch of one material
				var run := 0
				var x0 := 0
				var row := y * cols
				for x in cols + 1:
					var m := g[row + x] if x < cols else -1
					if m != run:
						if run > 0:
							n.draw_rect(Rect2(x0 * cw, y0 + y * chh, (x - x0) * cw + 0.5, chh + 0.5), Kit.TARGET if run == 1 else (water if run == 2 else wall))
						run = m
						x0 = x
			n.draw_rect(Rect2(b.spout * b.w - 4.0, 0.0, 8.0, y0 + 1.0), Kit.BONE)   # the spout
			n.draw_rect(Rect2(0.0, y0 + (rows - 1) * chh, b.w, 1.0), Color(0.961, 0.541, 0.541, 0.35))
			_label_right(n, "drain", Vector2(b.w - 4.0, y0 + (rows - 1) * chh - 2.0), Color(0.961, 0.541, 0.541, 0.5))
			n.draw_rect(Rect2(b.w - 60.0, 6.0, 6.0, 6.0), Kit.TARGET)
			Kit.label(n, b, "sand", Vector2(b.w - 50.0, 12.0), Kit.DIM)
			n.draw_rect(Rect2(b.w - 60.0, 16.0, 6.0, 6.0), water)
			Kit.label(n, b, "water", Vector2(b.w - 50.0, 22.0), Kit.DIM)
			n.draw_rect(Rect2(b.w - 60.0, 26.0, 6.0, 6.0), wall)
			Kit.label(n, b, "wall", Vector2(b.w - 50.0, 32.0), Kit.DIM)
			Kit.label(n, b, "press pours %s · %s ticks/s" % [D.material, str(D.stepsPerSec)], Vector2(6.0, 12.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), DEF, true)
		"liquid":
			var cols: int = b.cols
			var rows: int = b.rows
			var cw: float = b.cw
			var chh: float = b.chh
			var y0: float = b.y0
			var kind: PackedInt32Array = b.kind
			var mass: PackedFloat32Array = b.mass
			var fire: bool = b.fire
			var wall := Color(0.788, 0.769, 0.894, 0.55)
			var fuel := Color(0.608, 0.886, 0.541, 0.45)
			var ash := Color(0.91, 0.898, 0.957, 0.14)
			var water := Color(0.541, 0.851, 0.961, 0.8)
			var total := 0.0
			for y in rows:
				var run := -1
				var x0 := 0
				for x in cols + 1:
					var i := y * cols + x
					var m := -1                              # the drawn kind of this cell
					if x < cols:
						var k := kind[i]
						if k == 1:
							m = 1
						elif fire:
							m = 2 if k == 2 else (3 if k == 3 else (4 if k == 4 else -1))
						elif mass[i] > 0.01:
							total += mass[i]
							m = 6 if (mass[i] >= 0.95 or (y > 0 and mass[i - cols] > 0.01)) else 7
					if m == 7:                               # a surface cell: its fill height IS its mass
						var hh := chh * clampf(mass[i], 0.08, 1.0)
						n.draw_rect(Rect2(x * cw, y0 + (y + 1) * chh - hh, cw + 0.5, hh + 0.5), water)
						m = -1
					if m == 3:                               # a flame flickers by its own clock
						n.draw_rect(Rect2(x * cw, y0 + y * chh, cw + 0.5, chh + 0.5), Kit.HOT if randf() < 0.5 else Kit.TARGET)
						m = -1
					if m != run:
						if run >= 0 and run != 7 and run != 3:
							n.draw_rect(Rect2(x0 * cw, y0 + y * chh, (x - x0) * cw + 0.5, chh + 0.5),
								wall if run == 1 else (fuel if run == 2 else (ash if run == 4 else water)))
						run = m
						x0 = x
			if fire:
				Kit.label(n, b, "burning %d · spread %s · burn %s s · ash → fuel in %s s" % [int(b.burning), str(D.spread), str(D.burn), str(D.regrow)], Vector2(6.0, 12.0), Kit.DIM)
			else:
				var period: float = D.tapOn + D.tapOff
				var on: bool = fmod(b.tapT as float, period) < D.tapOn
				n.draw_rect(Rect2(b.tapX * b.w - 4.0, 0.0, 8.0, y0 + 2.0), Kit.MOVER if on else Kit.BONE)
				Kit.label(n, b, "tap %s · mass %d · flow %s" % ["on" if on else "off", roundi(total), str(D.flow)], Vector2(6.0, 12.0), Kit.DIM)
				var drain_x0: int = b.drainX0
				n.draw_rect(Rect2(drain_x0 * cw, y0 + (rows - 1) * chh - 1.0, (cols - 1 - drain_x0) * cw, 2.0), Color(0.961, 0.541, 0.541, 0.5))
				_label_right(n, "drain", Vector2(b.w - 8.0, y0 + (rows - 2) * chh - 3.0), Color(0.961, 0.541, 0.541, 0.6))
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), DEF, true)
