extends RefCounted

const Kit := preload("res://scenes/motion/kit.gd")
## SLOPES & SPRINGS — thirteen movement styles, ported from the web lexicon
## (docs/locomotion.js). Motion WITH memory: a velocity that persists between
## frames, an acceleration that bends it. This is calculus wearing gym
## clothes — velocity is the derivative of position, acceleration the
## derivative of velocity, and "integration" just means adding them up one
## frame at a time. Every camera follow, jump arc, and satisfying UI wobble
## is here — and, in the later laps, the dashes, slimes, umbrellas and cat
## pounces that are the same three lines of maths wearing a costume.

const TITLE := "Slopes & springs"
const BLURB := "velocity, acceleration, damping — calculus wearing gym clothes"
const DEFS := [
	{ "id": "lerp", "letter": "L", "name": "Lerp",
		"hint": "three ways to chase the same target — constant, eased, springy — press to move it",
		"dials": { "speed": 140.0, "rate": 4.2, "w": 7.5, "z": 0.55,      # px/s, lerp rate, spring ω and ζ
			"retarget": 2.6 },                                             # seconds before the target hops on its own
		"rhyme": { "name": "Lunge", "hint": "the same three errands at a sprint — 320 px/s, a lerp rate of 11, a stiffer spring that still overshoots",
			"dials": { "speed": 320.0, "rate": 11.0, "w": 13.0 } } },
	{ "id": "damp", "letter": "D", "name": "Damp",
		"hint": "one spring equation, three damping ratios — press to yank the target",
		"dials": { "w": 8.0, "z1": 0.35, "z2": 1.0, "z3": 2.2,             # ω, and the three ζ personalities
			"swap": 2.2, "hold": 4.0,                                      # seconds between hops; seconds a press pins it
			"label": "a = ω²(target−y) − 2ζω·v" },
		"rhyme": { "name": "Doorbell", "hint": "a faster spring and nobody critical — three flavours of ringing, from a shiver to a slow wobble",
			"dials": { "w": 14.0, "z2": 0.15, "z3": 0.6 } } },
	{ "id": "jump", "letter": "J", "name": "Jump",
		"hint": "v₀ = √(2gh): pick the height, get the launch speed — press to set the apex",
		"dials": { "g": 2.4, "apex": 0.36, "fallMul": 1.7,                 # gravity and apex as fractions of H; the fall multiplier
			"stand": 0.9, "land": 0.16 },                                  # seconds standing, seconds splatted
		"rhyme": { "name": "Joey", "hint": "kangaroo gravity — nearly twice as strong, a near-symmetric arc, and hardly a pause between hops",
			"dials": { "g": 4.4, "fallMul": 1.15, "stand": 0.3 } } },
	{ "id": "bounce", "letter": "B", "name": "Bounce",
		"hint": "restitution: every bounce keeps 62% of the energy — press to throw",
		"dials": { "g": 1.9, "e": 0.78,                                    # gravity as a fraction of H; the restitution
			"rest": 1.1, "squash": 0.35 },                                 # seconds asleep before a new drop; squash depth
		"rhyme": { "name": "Balloon", "hint": "a quarter of the gravity and 92% restitution — a slow, tireless lollop that hardly squashes at all",
			"dials": { "g": 0.55, "e": 0.92, "squash": 0.15 } } },
	{ "id": "dash", "letter": "D", "name": "Dash",
		"hint": "a burst of speed decaying by e^(−k·dt) — an ease-out with no timer — press to dash toward your click",
		"dials": { "burst": 2.2, "k": 6.0,                                 # burst speed in widths per second; decay rate per second
			"cooldown": 0.8, "cancelAt": 0.3,                              # seconds locked out; a new press cancels above this fraction of burst
			"ghostGap": 7.0, "ghostLife": 0.45,                            # px between afterimages; seconds they last
			"autoEvery": 1.8 },                                            # seconds idle before it dashes somewhere on its own
		"rhyme": { "name": "Drift", "hint": "the same burst with a lazy decay — a long skid off the walls instead of a blink, and almost no cooldown",
			"dials": { "k": 1.6, "burst": 1.2, "cooldown": 0.25 } } },
	{ "id": "ease", "letter": "E", "name": "Ease",
		"hint": "five motes, one distance, five easing curves — a speed shape over a fixed duration — press to restart the race",
		"dials": { "duration": 1.6, "rest": 0.9,                           # seconds per race, seconds at the finish
			"overshoot": 1.70158, "elastic": 10.0,                         # back-out's overshoot; elastic-out's decay
			"names": ["linear", "quad in-out", "cubic out", "elastic out", "back out"],
			"label": "x = start + ease(t ÷ duration) · distance" },
		"rhyme": { "name": "Eager", "hint": "less than half the duration, a wilder overshoot and a longer-ringing elastic — the same five shapes, snappier",
			"dials": { "duration": 0.7, "overshoot": 2.6, "elastic": 6.0 } } },
	{ "id": "inertia", "letter": "I", "name": "Inertia",
		"hint": "one push on ice, grass and mud — three coefficients, three skids — press to push all three away from your click",
		"dials": { "push": 0.85, "g": 2.4,                                 # push speed in widths per second; gravity as a fraction of H
			"mu": [0.3, 0.9, 2.4], "wall": 0.5,                            # the three coefficients; restitution at the walls
			"autoEvery": 3.4,                                              # seconds of stillness before a push of its own
			"names": ["ice", "grass", "mud"],
			"label": "skid  d = v² ÷ (2·μ·g)" },
		"rhyme": { "name": "Icerink", "hint": "every surface half frozen — a gentler push slides further than the hard one did, and nothing stops where you think",
			"dials": { "mu": [0.1, 0.28, 0.6], "push": 0.5 } } },
	{ "id": "weight", "letter": "W", "name": "Weight", "drag": true,
		"hint": "three masses on identical springs — ω = √(k/m): heavy is slow and lazy — drag to yank the shared anchor",
		"dials": { "k": 60.0, "c": 0.16,                                   # the spring constant; the drag per unit of area
			"masses": [1, 3, 9], "radius": 5.0, "restLen": 0.26,           # the masses; radius of a unit mass; rest length as a fraction of H
			"swapEvery": 3.0,                                              # seconds between the anchor's own yanks
			"label": "ω = √(k/m)      drag = c·r²·v" },
		"rhyme": { "name": "Wobble", "hint": "a stiffer spring, a third of the drag and a 16× spread of mass — everything rings, and the light one shivers",
			"dials": { "k": 190.0, "c": 0.06, "masses": [1, 4, 16] } } },
	{ "id": "yank", "letter": "Y", "name": "Yank",
		"hint": "minimum-jerk vs linear vs smoothstep, velocity plotted under each — press to set a new destination",
		"dials": { "duration": 1.4, "rest": 0.8,                           # seconds per reach; seconds resting at the end
			"vScale": 1.0, "size": 6.0,                                    # height of the velocity graphs; mote size
			"names": ["linear", "smoothstep", "min-jerk"],
			"label": "p = 10k³ − 15k⁴ + 6k⁵     (jerk = da/dt)" },
		"rhyme": { "name": "Yawn", "hint": "the same three reaches at half the speed, the velocity graphs stretched tall — watch the bell of the human one",
			"dials": { "duration": 3.2, "rest": 1.6, "vScale": 1.6 } } },
	{ "id": "umbrella", "letter": "U", "name": "Umbrella",
		"hint": "terminal velocity: a = g − c·v² settles where drag equals gravity — press to open or close the umbrella",
		"dials": { "g": 1.6, "cOpen": 13.0, "cClosed": 0.4,                # gravity as a fraction of H; drag coefficients (× 1/H) open and closed
			"sway": 1.2, "swayAmp": 0.09, "canopy": 0.1,                   # sway rate, sideways drift as a fraction of H per second, canopy radius
			"wait": 0.7, "autoFlip": 8.0,                                  # seconds on the ground; seconds unpressed before it flips itself
			"label": "a = g − c·v²   →   terminal v = √(g/c)" },
		"rhyme": { "name": "Ultralight", "hint": "lighter, three times the canopy drag and a quicker sway — it drifts down like a dandelion seed",
			"dials": { "g": 0.9, "cOpen": 40.0, "sway": 2.2 } } },
	{ "id": "quicksand", "letter": "Q", "name": "Quicksand",
		"hint": "drag thickens with depth; a struggle lifts, then sinks you faster — press to struggle, click above for a rope",
		"dials": { "g": 0.9, "c0": 4.0, "cGrow": 14.0,                     # gravity as a fraction of H; drag at the surface; how fast it thickens with depth
			"kick": 0.45, "panicMul": 3.0, "panicTime": 0.7,               # a struggle's upward kick (× H per second); panic gravity; seconds of panic
			"autoStruggle": 1.6, "drown": 0.2,                             # seconds between its own struggles; depth (× H) that swallows it
			"ropeSpeed": 0.5,                                              # climbing speed as a fraction of H per second
			"label": "a = g − c·v,    c = c₀·(1 + depth·k)" },
		"rhyme": { "name": "Quagmire", "hint": "thicker mud: it barely sinks at all — until it struggles, and then it goes down like a stone",
			"dials": { "c0": 9.0, "cGrow": 30.0, "panicMul": 6.0 } } },
	{ "id": "slime", "letter": "S", "name": "Slime",
		"hint": "squash & stretch from velocity — sy = 1 + |vy|·k, and sx = 1/sy keeps the volume — press to set the target",
		"dials": { "g": 2.2, "apex": 0.15, "hop": 0.24,                    # gravity and apex as fractions of H; a hop's reach as a fraction of W
			"stretch": 0.3,                                                # stretch at launch speed
			"crouch": 0.3, "splat": 0.22, "sit": 0.4,                      # seconds crouching, splatted, sitting
			"radius": 10.0, "label": "sy = 1 + |vy|·k      sx = 1 ÷ sy" },
		"rhyme": { "name": "Sludge", "hint": "a heavy blob: tiny hops, long sits — the same squash rules on a much lazier body",
			"dials": { "apex": 0.05, "hop": 0.1, "sit": 0.9 } } },
	{ "id": "cat", "letter": "C", "name": "Cat",
		"hint": "a pounce: a butt-wiggle crouch (anticipation), then one parabola aimed at the toy — press to move the toy",
		"dials": { "g": 2.6, "apex": 0.2,                                  # gravity and apex as fractions of H
			"sit": 1.1, "crouch": 0.6, "land": 0.16,                       # seconds sitting, crouching, landing
			"wiggle": 18.0, "tail": 3.0,                                   # the butt-wiggle's rate; the tail's sway rate (rad/s)
			"label": "v₀ = √(2gh)      vx = distance ÷ airtime" },
		"rhyme": { "name": "Cougar", "hint": "a bigger cat: a higher, floatier arc and a longer, more menacing crouch before the spring",
			"dials": { "apex": 0.42, "g": 2.0, "crouch": 1.0 } } },
]

const TXT := Color(0.91, 0.898, 0.957, 0.55)          # the web label's default ink
const FAINT := Color(0.91, 0.898, 0.957, 0.12)


## ζ's manners: under-, critically or over-damped.
static func _manners(z: float) -> String:
	return "bouncy" if z < 1.0 else ("sluggish" if z > 1.0 else "critical")

## The five easing curves of Ease, by lane.
static func _ease_fn(i: int, k: float, D: Dictionary) -> float:
	var r := 0.0
	match i:
		0:
			r = k
		1:
			r = 2.0 * k * k if k < 0.5 else 1.0 - pow(-2.0 * k + 2.0, 2.0) / 2.0
		2:
			r = 1.0 - pow(1.0 - k, 3.0)
		3:
			var el: float = D.elastic
			r = 0.0 if k <= 0.0 else (1.0 if k >= 1.0 else pow(2.0, -el * k) * sin((el * k - 0.75) * (TAU / 3.0)) + 1.0)
		_:
			var o: float = D.overshoot
			r = 1.0 + (o + 1.0) * pow(k - 1.0, 3.0) + o * pow(k - 1.0, 2.0)
	return r

## Yank's three reaches: linear, smoothstep, minimum-jerk — and their derivatives.
static func _yank_p(i: int, k: float) -> float:
	var r := k
	if i == 1:
		r = k * k * (3.0 - 2.0 * k)
	elif i == 2:
		r = k * k * k * (10.0 - 15.0 * k + 6.0 * k * k)
	return r

static func _yank_v(i: int, k: float) -> float:
	var r := 1.0
	if i == 1:
		r = 6.0 * k * (1.0 - k)
	elif i == 2:
		r = 30.0 * k * k * (1.0 - k) * (1.0 - k)
	return r

## A right-aligned label (the web label's "right" mode).
static func _label_right(n: CanvasItem, b: Dictionary, txt: String, p: Vector2, col: Color) -> void:
	var f := ThemeDB.fallback_font
	Kit.label(n, b, txt, Vector2(p.x - f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x, p.y), col)

## A filled pie slice of a circle (ctx.arc + closePath + fill).
static func _arc_fill(n: CanvasItem, c: Vector2, r: float, a0: float, a1: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var a := a0 + (a1 - a0) * i / 16.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	n.draw_colored_polygon(pts, col)

## Dash: the impulse — velocity SET to a burst (not added), unless the cooldown says no.
static func _dash(b: Dictionary, px: float, py: float) -> void:
	var D: Dictionary = b.D
	var moving: bool = (b.v as Vector2).length() > D.burst * b.w * D.cancelAt   # still fast: cancel into a new dash
	if b.cool > 0.0 and not moving:
		return                                       # else the cooldown says no
	var to: Vector2 = Vector2(px, py) - b.p
	var d: float = to.length()
	if d == 0.0:
		d = 1.0
	b.hd = atan2(to.y, to.x)
	b.v = to / d * D.burst * b.w                     # the impulse: velocity SET, not added
	b.cool = D.cooldown
	b.idle = 0.0

## Inertia: one push, away from the click, on all three lanes.
static func _inertia_push(b: Dictionary, px: float) -> void:
	var D: Dictionary = b.D
	for L in b.lanes:
		var dir: float = 1.0 if L.x >= px else -1.0  # away from the click
		L.v = dir * D.push * b.w
		L.face = dir
		L.mark = L.x + dir * (L.v * L.v) / (2.0 * L.mu * D.g * b.h)   # the skid, predicted
	b.quiet = 0.0

## Yank: a new destination — every lane starts from where it is now.
static func _yank_go(b: Dictionary, nx: float) -> void:
	for L in b.lanes:
		L.from = L.x
	b.to = nx
	b.clock = 0.0

## Quicksand: the struggle — an upward kick, paid for in panic.
static func _qs_struggle(b: Dictionary) -> void:
	var D: Dictionary = b.D
	b.vy -= D.kick * b.h
	b.panic = D.panicTime
	b.since = 0.0
	b.ripple = 1.0

## Cat: the body, drawn about the paws — scaled, tilted, wiggling, tail on a sine.
static func _draw_cat(n: CanvasItem, b: Dictionary, o: Vector2, sx: float, sy: float, wig: float, tilt: float, t: float) -> void:
	var D: Dictionary = b.D
	var origin: Vector2 = (b.rect as Rect2).position
	var dir: float = b.dir
	n.draw_set_transform(origin + o, tilt, Vector2(sx, sy))   # scale about the paws
	var bx := -dir * 8.0 + wig                        # the body, behind the head
	var by := -7.0
	Kit.dot(n, Vector2(bx, by), 7.0, Color(0.541, 0.851, 0.961, 0.85))
	for i in 6:                                       # the tail sways on a sine
		var s: float = sin(t * D.tail + i * 0.7) * i * 1.4
		Kit.dot(n, Vector2(bx - dir * (6.0 + i * 3.6), by - i * 2.4 - s), 2.4 - i * 0.2, Color(0.541, 0.851, 0.961, 0.6))
	var hx := dir * 6.0
	var hy := -11.0
	Kit.dot(n, Vector2(hx, hy), 6.0, Kit.MOVER)
	Kit.poly(n, [Vector2(hx - dir * 5.0, hy - 3.0), Vector2(hx - dir * 4.0, hy - 10.0), Vector2(hx - dir * 1.0, hy - 5.0)], Kit.MOVER)   # ears
	Kit.poly(n, [Vector2(hx + dir * 1.0, hy - 5.0), Vector2(hx + dir * 4.0, hy - 10.0), Vector2(hx + dir * 5.0, hy - 3.0)], Kit.MOVER)
	Kit.dot(n, Vector2(hx + dir * 2.4, hy - 1.0), 1.4, Kit.NIGHT)   # the eye, on the toy
	n.draw_set_transform(origin, 0.0, Vector2.ONE)


static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	match b.id:
		"lerp":
			# the same errand, three personalities:
			#   constant speed — move_toward: a fixed step along the line. robotic, exact.
			#   lerp-smoothing — cover a FRACTION of the remaining gap each frame:
			#     fast start, feather-soft landing (written 1−exp(−k·dt) so any
			#     framerate produces the same curve).
			#   spring — remembers a velocity, so it can OVERSHOOT and settle.
			b.tgt = Vector2(b.w * 0.7, b.h * 0.35)
			b.timer = 0.0
			b.a = Vector2(b.w * 0.2, b.h * 0.7)          # constant
			b.bp = Vector2(b.w * 0.2, b.h * 0.5)         # lerp
			b.c = Vector2(b.w * 0.2, b.h * 0.3)          # spring
			b.cv = Vector2.ZERO
		"damp":
			# the spring-damper is a second-order differential equation:
			#   acceleration = ω²·(target − x) − 2·ζ·ω·velocity
			# ω sets how FAST it wants to be; ζ (zeta) sets its manners:
			#   ζ < 1 underdamped — overshoots and rings (bouncy, alive)
			#   ζ = 1 CRITICALLY DAMPED — fastest possible arrival with zero
			#         overshoot (the one cameras and cursors want)
			#   ζ > 1 overdamped — never overshoots, takes its sweet time
			b.zs = [D.z1, D.z2, D.z3]
			b.names = []
			for z in b.zs:
				b.names.append("ζ = " + str(z) + " " + _manners(z))
			b.ty = b.h * 0.3
			b.timer = 0.0
			b.hold = 0.0
			b.ys = [b.h * 0.6, b.h * 0.6, b.h * 0.6]
			b.vs = [0.0, 0.0, 0.0]
		"jump":
			# jumps are parabolas — constant downward acceleration under a chosen
			# launch speed. games run the maths BACKWARD: designers pick the apex
			# height h, and v₀ = √(2·g·h) guarantees it. the second trick: gravity
			# is 1.7× stronger on the way down, because floaty rises and snappy
			# falls FEEL right even though physics class would object.
			b.apex = b.h * D.apex
			b.phase = "stand"
			b.timer = 0.0
			b.y = b.gy
			b.vy = 0.0
		"bounce":
			# integration plus one rule at the floor: flip the velocity and keep only
			# a fraction e of it (the RESTITUTION). heights shrink by e² per bounce —
			# energy goes with the square of speed — so the rhythm speeds up all by
			# itself, no scripting. the squash at contact is presentation, not physics.
			b.p = Vector2(b.w * 0.35, b.h * 0.12)
			b.v = Vector2(34.0, 0.0)
			b.squash = 0.0
			b.bounces = 0
			b.rest = 0.0
		"dash":
			# a DASH is an IMPULSE with no follow-through: SET the velocity to a burst
			# (not add — that is the difference between a dash and a shove) and let
			# it die away with v *= exp(−k·dt) every frame. that is lerp-smoothing
			# applied to speed instead of position, and it is the cheapest EASE-OUT
			# there is — fast start, feather stop, no duration to keep track of. the
			# afterimages are dropped every few px, so their spacing IS the speed
			# graph; the ring is the COOLDOWN, and a press mid-dash cancels into a new one.
			b.p = Vector2(b.w / 2.0, b.h * 0.5)
			b.v = Vector2.ZERO
			b.hd = 0.0                                   # the heading (b.h is the stage height)
			b.cool = 0.0
			b.idle = 0.0
			b.tgt = Vector2(b.w * 0.7, b.h * 0.4)
			b.lastg = b.p
			b.ghosts = []
		"ease":
			# EASING is a shape for speed over a FIXED duration: k = t/duration runs
			# 0 → 1 like a clock, and ease(k) bends it — slow-fast-slow, a rush then
			# a glide, a wobble past the end and back. a spring needs no duration
			# (it arrives when it arrives); an ease needs no state (it arrives on the
			# dot). the faint curve under each lane is its ease(k), time along x and
			# progress up; the mote's x IS the curve's height, read sideways.
			b.clock = 0.0
			b.x0 = b.w * 0.28
			b.x1 = b.w * 0.84
		"inertia":
			# FRICTION, Coulomb's version: a sliding body feels a constant backward
			# force μ·g whatever its speed — so v shrinks by μ·g·dt every frame and
			# stops DEAD the moment it would cross zero (no asymptotic creep). the
			# COEFFICIENT μ is the surface's personality: ice 0.3, grass 0.9, mud 2.4.
			# solve v² = 2·a·d and the skid length is v²/(2μg): double the push,
			# four times the slide — the faint ring is that prediction, drawn first.
			b.lanes = []
			var mus: Array = D.mu
			for i in mus.size():
				b.lanes.append({ "mu": float(mus[i]), "x": b.w * 0.5, "v": 0.0, "face": 1.0, "mark": b.w * 0.5, "y": b.h * (0.26 + i * 0.22) })
			b.quiet = 0.0
			b.side = 1.0
		"weight":
			# Hooke's law says the spring force is k × stretch, and Newton's says
			# a = F/m — so the same spring on a heavier ball produces less
			# acceleration, and the natural frequency is ω = √(k/m): nine times the
			# MASS, a third of the tempo. drag here is c·r²·v (air resistance grows
			# with the cross-section), and a ball's radius grows with ∛m, so the
			# big one is slow to start AND slow to stop. the anchor bar is the input.
			b.anchor = b.h * 0.1
			b.hold = 0.0
			b.timer = 0.0
			b.balls = []
			var masses: Array = D.masses
			for i in masses.size():
				var m: float = float(masses[i])
				b.balls.append({ "m": m, "r": D.radius * pow(m, 1.0 / 3.0), "x": b.w * (0.25 + i * 0.25),
					"y": b.anchor + D.restLen * b.h, "v": 0.0 })
		"yank":
			# JERK is the derivative of acceleration — how fast the force changes.
			# hands and eyes hate it, and the reach that keeps total jerk as small
			# as possible turns out to be one polynomial of k = t/duration:
			#   p = 10k³ − 15k⁴ + 6k⁵     (Flash & Hogan, 1985)
			# it starts and ends with zero velocity AND zero acceleration, so it
			# eases in and out without a single kink. smoothstep (3k² − 2k³) has
			# zero velocity at the ends but not zero acceleration — a tiny click at
			# take-off; linear is all kink. the graphs are v(k): a flat line, a
			# hump, and the taller, narrower bell that reads as a living hand.
			b.lanes = []
			for i in 3:
				b.lanes.append({ "y": b.h * (0.17 + i * 0.27), "x": b.w * 0.2, "from": b.w * 0.2 })
			b.to = b.w * 0.8
			b.clock = 0.0
		"umbrella":
			# air DRAG grows with the SQUARE of speed (twice as fast, four times the
			# push-back), so a falling body speeds up until c·v² equals g and the
			# acceleration hits zero: that speed, √(g/c), is the TERMINAL VELOCITY.
			# an open canopy has a huge c and a tiny terminal speed; fold it and c
			# drops thirtyfold. the gauge on the right shows v climbing toward the
			# amber terminal line. the sideways drift is a slow sine on the tilt.
			b.x = b.w / 2.0
			b.y = -20.0
			b.vy = 0.0
			b.open = true
			b.phase = "fall"
			b.timer = 0.0
			b.sincePress = 0.0
			b.tilt = 0.0
		"quicksand":
			# VISCOUS drag is proportional to the speed itself (Stokes' law: slow
			# things in thick fluids), so the sinking speed settles at g/c. here c
			# grows with depth — the deeper you are, the thicker the sand, and the
			# slower but surer you go. a struggle is an upward IMPULSE (a kick to v)
			# and its price is PANIC: gravity counts triple for a moment, because
			# churned sand flows back thicker. the only real exit is a thing to pull on.
			b.x = b.w * 0.5
			b.y = b.gy - 6.0
			b.vy = 0.0
			b.panic = 0.0
			b.since = 0.0
			b.phase = "sink"
			b.timer = 0.0
			b.hang = 0.0
			b.ropeX = 0.0
			b.ripple = 0.0
		"slime":
			# SQUASH & STRETCH, the first of the twelve animation principles, done
			# by formula: stretch along the velocity (sy grows with |vy|) and keep
			# the VOLUME constant by shrinking the other axis (sx = 1/sy). the
			# crouch before take-off is ANTICIPATION, the splat is FOLLOW-THROUGH —
			# both are just sy < 1 on a timer. the hop itself is Jump's parabola
			# (v₀ = √(2gh)) with vx chosen so it lands one hop nearer the target.
			b.x = b.w * 0.3
			b.y = b.gy
			b.vx = 0.0
			b.vy = 0.0
			b.dir = 1.0
			b.tx = b.w * 0.72
			b.phase = "sit"
			b.timer = 0.0
			b.v0 = 1.0
			b.sy = 1.0
		"cat":
			# ANTICIPATION: a motion reads better if the body first moves a little
			# the other way — the crouch loads the spring, and the butt-wiggle (a
			# quick sine, ~3 Hz) is the cat aiming. then the pounce is pure Jump:
			# pick the apex h, v₀ = √(2gh) fixes the airtime T = 2v₀/g, and
			# vx = distance/T lands it on the toy exactly. once airborne nothing can
			# be corrected — a pounce is BALLISTIC, which is why cats miss.
			b.x = b.w * 0.25
			b.y = b.gy
			b.vx = 0.0
			b.vy = 0.0
			b.dir = 1.0
			b.tx = b.w * 0.7
			b.phase = "sit"
			b.timer = 0.0
			b.sx = 1.0
			b.sy = 1.0
			b.wig = 0.0
			b.tilt = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	match b.id:
		"lerp":
			b.tgt = pos
			b.timer = -3.0
		"damp":
			b.ty = pos.y
			b.hold = D.hold
		"jump":
			b.apex = clampf(b.gy - pos.y, b.h * 0.1, b.h * 0.62)
		"bounce":
			b.p = pos
			b.v = Vector2(randf_range(-70, 70), randf_range(-60, 20))
			b.bounces = 0
			b.rest = 0.0
		"dash":
			b.tgt = pos
			_dash(b, pos.x, pos.y)
		"ease":
			b.clock = 0.0
		"inertia":
			_inertia_push(b, pos.x)
		"weight":
			b.anchor = clampf(pos.y, b.h * 0.06, b.h * 0.42)
			b.hold = 4.0
		"yank":
			_yank_go(b, clampf(pos.x, b.w * 0.08, b.w * 0.92))
		"umbrella":
			b.open = not b.open
			b.sincePress = 0.0
		"quicksand":
			if b.phase == "climb" or b.phase == "gulp":
				return
			if pos.y < b.gy - 14.0:
				b.ropeX = clampf(pos.x, 14.0, b.w - 14.0)
				b.phase = "climb"
				b.hang = 0.0
			else:
				_qs_struggle(b)
		"slime":
			b.tx = clampf(pos.x, D.radius, b.w - D.radius)
		"cat":
			b.tx = clampf(pos.x, b.w * 0.06, b.w * 0.94)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var D: Dictionary = b.D
	match b.id:
		"lerp":
			b.timer += dt
			if b.timer > D.retarget:
				b.timer = 0.0
				b.tgt = Vector2(randf_range(b.w * 0.15, b.w * 0.85), randf_range(b.h * 0.2, b.h * 0.8))
			var to: Vector2 = b.tgt - b.a
			var step: float = D.speed * dt                # constant speed: a fixed step
			b.a = b.tgt if to.length() <= step else b.a + to.normalized() * step   # arrive exactly, stop dead
			b.bp += (b.tgt - b.bp) * Kit.smooth(D.rate, dt)   # framerate-proof lerp factor
			var w: float = D.w
			var z: float = D.z                            # spring frequency + damping
			b.cv += ((b.tgt - b.c) * w * w - 2.0 * z * w * b.cv) * dt
			b.c += b.cv * dt
		"damp":
			if b.hold > 0.0:
				b.hold -= dt
			else:
				b.timer += dt
				if b.timer > D.swap:
					b.timer = 0.0
					b.ty = b.h * 0.68 if b.ty < b.h * 0.5 else b.h * 0.3
			var w: float = D.w
			for i in 3:
				b.vs[i] += (w * w * (b.ty - b.ys[i]) - 2.0 * b.zs[i] * w * b.vs[i]) * dt   # the whole equation
				b.ys[i] += b.vs[i] * dt
		"jump":
			var G: float = b.h * D.g
			var v0 := sqrt(2.0 * G * b.apex)             # designers pick h; maths delivers v0
			b.timer += dt
			if b.phase == "stand" and b.timer > D.stand:
				b.phase = "air"
				b.vy = -v0
				b.timer = 0.0
			if b.phase == "air":
				b.vy += (G if b.vy < 0.0 else G * D.fallMul) * dt   # heavier on the way down
				b.y += b.vy * dt
				if b.y >= b.gy:
					b.y = b.gy
					b.phase = "land"
					b.timer = 0.0
			if b.phase == "land" and b.timer > D.land:
				b.phase = "stand"
				b.timer = 0.0
		"bounce":
			var G: float = b.h * D.g
			var E: float = D.e
			if b.rest > 0.0:
				b.rest -= dt
				if b.rest <= 0.0:
					b.p = Vector2(randf_range(b.w * 0.2, b.w * 0.8), b.h * 0.12)
					b.v = Vector2(randf_range(-40, 40), 0.0)
					b.bounces = 0
			else:
				b.v.y += G * dt
				b.p += b.v * dt
				if b.p.x < 9.0:
					b.p.x = 9.0
					b.v.x = -b.v.x * E
				if b.p.x > b.w - 9.0:
					b.p.x = b.w - 9.0
					b.v.x = -b.v.x * E
				if b.p.y > b.gy - 9.0:
					b.p.y = b.gy - 9.0
					b.v.y = -b.v.y * E              # the whole law of bouncing
					b.v.x *= 0.99
					b.squash = 0.12
					b.bounces += 1
					if absf(b.v.y) < b.h * 0.09:
						b.v.y = 0.0
						if absf(b.v.x) < 6.0:
							b.rest = D.rest
			b.squash = maxf(0.0, b.squash - dt)
		"dash":
			b.cool = maxf(0.0, b.cool - dt)
			b.idle += dt
			if b.idle > D.autoEvery:
				b.tgt = Vector2(randf_range(b.w * 0.15, b.w * 0.85), randf_range(b.h * 0.15, b.h * 0.85))
				_dash(b, b.tgt.x, b.tgt.y)
				b.idle = 0.0
			var decay: float = exp(-D.k * dt)             # ← the ease-out, one multiply
			b.v *= decay
			b.p += b.v * dt
			if b.p.x < 10.0:
				b.p.x = 10.0
				b.v.x = -b.v.x
			if b.p.x > b.w - 10.0:
				b.p.x = b.w - 10.0
				b.v.x = -b.v.x
			if b.p.y < 10.0:
				b.p.y = 10.0
				b.v.y = -b.v.y
			if b.p.y > b.h - 10.0:
				b.p.y = b.h - 10.0
				b.v.y = -b.v.y
			if (b.p - b.lastg as Vector2).length() > D.ghostGap:   # drop an afterimage every few px
				b.ghosts.append({ "p": b.p, "h": b.hd, "age": 0.0 })
				b.lastg = b.p
			for g in b.ghosts:
				g.age += dt
			while b.ghosts.size() > 0 and (b.ghosts[0].age > D.ghostLife or b.ghosts.size() > 40):
				b.ghosts.pop_front()
		"ease":
			b.clock += dt
			if b.clock > D.duration + D.rest:
				b.clock = 0.0
		"inertia":
			var g: float = D.g * b.h
			var moving := false
			for L in b.lanes:
				if L.v != 0.0:
					var dv: float = L.mu * g * dt         # the friction step, speed-blind
					if absf(L.v) <= dv:
						L.v = 0.0                         # would cross zero: stop dead
					else:
						L.v -= signf(L.v) * dv
					L.x += L.v * dt
					if L.x < 8.0:
						L.x = 8.0
						L.v = -L.v * D.wall
					if L.x > b.w - 8.0:
						L.x = b.w - 8.0
						L.v = -L.v * D.wall
					if L.v != 0.0:
						moving = true
			if not moving:
				b.quiet += dt
				if b.quiet > D.autoEvery:
					b.side = -b.side
					_inertia_push(b, 0.0 if b.side > 0.0 else b.w)
		"weight":
			if b.hold > 0.0:
				b.hold -= dt
			else:
				b.timer += dt
				if b.timer > D.swapEvery:
					b.timer = 0.0
					b.anchor = b.h * 0.32 if b.anchor < b.h * 0.2 else b.h * 0.1
			for ball in b.balls:
				var rest: float = b.anchor + D.restLen * b.h
				var a: float = (D.k * (rest - ball.y) - D.c * ball.r * ball.r * ball.v) / ball.m   # F = k·x − c·r²·v, then a = F/m
				ball.v += a * dt
				ball.y += ball.v * dt
		"yank":
			b.clock += dt
			var k: float = clampf(b.clock / D.duration, 0.0, 1.0)   # the clock, normalised
			if b.clock > D.duration + D.rest:
				_yank_go(b, randf_range(b.w * 0.6, b.w * 0.9) if b.to < b.w / 2.0 else randf_range(b.w * 0.1, b.w * 0.4))
			for i in 3:
				var L: Dictionary = b.lanes[i]
				L.x = lerpf(L.from, b.to, _yank_p(i, k))  # ← position is the polynomial of the clock
		"umbrella":
			var g: float = D.g * b.h
			var c: float = (D.cOpen if b.open else D.cClosed) / b.h
			b.sincePress += dt
			b.timer += dt
			var tilt := 0.0
			if b.phase == "fall":
				b.vy += g * dt
				b.vy -= clampf(c * b.vy * absf(b.vy) * dt, -absf(b.vy), absf(b.vy))   # drag may slow you, never reverse you
				tilt = sin(t * D.sway) * 0.3 if b.open else 0.0
				var drift: float = sin(t * D.sway) * D.swayAmp * b.h if b.open else 0.0
				b.x = clampf(b.x + drift * dt, b.w * 0.15, b.w * 0.85)
				b.y += b.vy * dt
				if b.y >= b.gy - 9.0:
					b.y = b.gy - 9.0
					b.phase = "land"
					b.timer = 0.0
			elif b.timer > D.wait:
				b.phase = "fall"
				b.y = -20.0
				b.vy = 0.0
				b.x = randf_range(b.w * 0.3, b.w * 0.7)
				if b.sincePress > D.autoFlip:
					b.open = not b.open              # left alone, it shows both falls
			b.tilt = tilt
		"quicksand":
			var g: float = D.g * b.h
			var surf: float = b.gy - 6.0
			b.timer += dt
			b.since += dt
			b.panic = maxf(0.0, b.panic - dt)
			b.ripple = maxf(0.0, b.ripple - dt * 1.6)
			var depth: float = maxf(0.0, b.y - surf)
			if b.phase == "sink" or b.phase == "drop":
				var c: float = D.c0 * (1.0 + depth / b.h * D.cGrow) if depth > 0.0 else 0.0   # thicker with depth; none in the air
				b.vy += g * (D.panicMul if b.panic > 0.0 else 1.0) * dt
				b.vy -= clampf(c * b.vy * dt, -absf(b.vy), absf(b.vy))   # drag ∝ v — it may slow, never reverse
				b.y += b.vy * dt
				depth = maxf(0.0, b.y - surf)
				if b.phase == "drop" and depth > 0.0:
					b.phase = "sink"
					b.vy *= 0.3
					b.ripple = 1.0
					b.since = 0.0
				if b.phase == "sink" and b.since > D.autoStruggle and depth > 4.0:
					_qs_struggle(b)                  # it panics on its own
				if depth > D.drown * b.h:
					b.phase = "gulp"
					b.timer = 0.0
					b.ripple = 1.0
			elif b.phase == "climb":                     # hand over hand up the rope
				var to := Vector2(b.ropeX - b.x, b.h * 0.2 - b.y)
				var d := to.length()
				var step: float = D.ropeSpeed * b.h * dt
				if d > step:
					b.x += to.x / d * step
					b.y += to.y / d * step
				else:
					b.x = b.ropeX
					b.y = b.h * 0.2
					b.hang += dt
					if b.hang > 0.9:
						b.phase = "drop"
						b.vy = 0.0
						b.since = 0.0
			elif b.phase == "gulp" and b.timer > 1.0:    # swallowed — and dropped in again
				b.phase = "drop"
				b.x = randf_range(b.w * 0.3, b.w * 0.7)
				b.y = -16.0
				b.vy = 0.0
				b.panic = 0.0
				b.since = 0.0
		"slime":
			var g: float = D.g * b.h
			var r: float = D.radius
			b.timer += dt
			var sy := 1.0
			if b.phase == "sit" and b.timer > D.sit:
				if absf(b.tx - b.x) < 6.0:
					b.tx = randf_range(b.w * 0.1, b.w * 0.9)   # reached it: a new errand
				b.phase = "crouch"
				b.timer = 0.0
			if b.phase == "crouch":
				sy = 1.0 - 0.35 * minf(1.0, b.timer / D.crouch)   # anticipation: load the spring
				if b.timer > D.crouch:
					var gap: float = b.tx - b.x
					b.dir = 1.0 if gap >= 0.0 else -1.0
					var reach: float = minf(absf(gap), D.hop * b.w)
					b.v0 = sqrt(2.0 * g * D.apex * b.h)   # Jump's launch speed
					var T: float = 2.0 * b.v0 / g        # airtime: up and down
					b.vx = b.dir * reach / T
					b.vy = -b.v0
					b.phase = "air"
					b.timer = 0.0
			if b.phase == "air":
				b.vy += g * dt
				b.x += b.vx * dt
				b.y += b.vy * dt
				sy = 1.0 + absf(b.vy) / b.v0 * D.stretch   # ← stretch from speed (k = stretch ÷ v₀)
				if b.y >= b.gy:
					b.y = b.gy
					b.vx = 0.0
					b.vy = 0.0
					b.phase = "splat"
					b.timer = 0.0
			if b.phase == "splat":
				sy = 1.0 - 0.45 * (1.0 - minf(1.0, b.timer / D.splat))   # follow-through, recovering
				if b.timer > D.splat:
					b.phase = "sit"
					b.timer = 0.0
			b.x = clampf(b.x, r, b.w - r)
			b.sy = sy
		"cat":
			var g: float = D.g * b.h
			b.timer += dt
			var sx := 1.0
			var sy := 1.0
			var wig := 0.0
			var tilt := 0.0
			if b.phase == "sit" and b.timer > D.sit:
				if absf(b.tx - b.x) < 12.0:              # caught it — the toy escapes
					b.tx = randf_range(b.w * 0.6, b.w * 0.9) if b.x < b.w / 2.0 else randf_range(b.w * 0.1, b.w * 0.4)
				b.phase = "crouch"
				b.timer = 0.0
			if b.phase == "crouch":
				b.dir = 1.0 if b.tx >= b.x else -1.0
				sy = 0.8
				sx = 1.1
				wig = sin(b.timer * D.wiggle) * 1.6 * minf(1.0, b.timer * 4.0)   # the quick sine
				var h: float = D.apex * b.h
				var v0 := sqrt(2.0 * g * h)
				var T := 2.0 * v0 / g
				var aim: float = (b.tx - b.x) / T        # vx that lands exactly on the toy
				if b.timer > D.crouch:
					b.vx = aim
					b.vy = -v0
					b.phase = "air"
					b.timer = 0.0
			if b.phase == "air":
				b.vy += g * dt
				b.x += b.vx * dt
				b.y += b.vy * dt
				var climb := atan2(-b.vy, absf(b.vx))    # nose up on the rise, down on the fall
				tilt = -b.dir * climb * 0.5
				sx = 1.1
				sy = 0.95
				if b.y >= b.gy:
					b.y = b.gy
					b.vx = 0.0
					b.vy = 0.0
					b.phase = "land"
					b.timer = 0.0
			if b.phase == "land":
				sx = 1.15
				sy = 0.78
				if b.timer > D.land:
					b.phase = "sit"
					b.timer = 0.0
			b.x = clampf(b.x, 14.0, b.w - 14.0)
			b.sx = sx
			b.sy = sy
			b.wig = wig
			b.tilt = tilt

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	Kit.stage(n, b)
	var origin: Vector2 = (b.rect as Rect2).position
	var D: Dictionary = b.D
	match b.id:
		"lerp":
			Kit.ring(n, b.tgt, 10.0, Kit.TARGET, 1.5)
			Kit.dot(n, b.tgt, 3.0, Kit.TARGET)
			Kit.mote(n, b, b.a, (b.tgt - b.a as Vector2).angle(), Kit.GOOD, 6.0)
			Kit.mote(n, b, b.bp, (b.tgt - b.bp as Vector2).angle(), Kit.MOVER, 6.0)
			Kit.mote(n, b, b.c, (b.cv as Vector2).angle(), Kit.BONE, 6.0)
			Kit.label(n, b, "constant", Vector2(b.w * 0.25, b.h - 8.0), Color(0.608, 0.886, 0.541, 0.8), true)
			Kit.label(n, b, "lerp", Vector2(b.w * 0.5, b.h - 8.0), Color(0.541, 0.851, 0.961, 0.8), true)
			Kit.label(n, b, "spring", Vector2(b.w * 0.75, b.h - 8.0), Color(0.788, 0.769, 0.894, 0.8), true)
		"damp":
			n.draw_dashed_line(Vector2(0, b.ty), Vector2(b.w, b.ty), Kit.TARGET, 1.0, 8.0)
			for i in 3:
				var x: float = b.w * (0.25 + i * 0.25)
				n.draw_line(Vector2(x, b.h * 0.12), Vector2(x, b.h * 0.88), FAINT, 1.0)
				var col: Color = [Kit.HOT, Kit.GOOD, Kit.MOVER][i]
				Kit.mote(n, b, Vector2(x, b.ys[i]), b.vs[i] * 0.002, col, 7.0)
				Kit.label(n, b, b.names[i], Vector2(x, b.h * 0.94), TXT, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, 14.0), TXT, true)
		"jump":
			Kit.ground(n, b)
			var G: float = b.h * D.g
			var v0 := sqrt(2.0 * G * b.apex)
			var x: float = b.w / 2.0
			if b.phase == "stand":                       # the predicted arc, while standing
				var sy: float = b.gy
				var sv := -v0
				for i in 46:
					sv += (G if sv < 0.0 else G * D.fallMul) * 0.022
					sy += sv * 0.022
					if sy > b.gy:
						break
					n.draw_rect(Rect2(x - 1.0, sy, 2.0, 2.0), Color(0.91, 0.898, 0.957, 0.18))   # a rising-falling dotted line
			Kit.ring(n, Vector2(x, b.gy - b.apex), 6.0, Kit.TARGET, 1.5)
			Kit.label(n, b, "apex h = %d px" % roundi(b.apex), Vector2(x + 12.0, b.gy - b.apex + 3.0), Color(0.961, 0.757, 0.412, 0.8))
			var sx := 1.0
			var sy2 := 1.0
			if b.phase == "stand" and b.timer > D.stand - 0.2:   # anticipation crouch
				sx = 1.12
				sy2 = 0.85
			if b.phase == "air":
				sy2 = 1.0 + minf(0.35, absf(b.vy) / v0 * 0.3)
				sx = 1.0 / sy2
			if b.phase == "land":                        # the splat
				sx = 1.25
				sy2 = 0.72
			var ang := 0.0
			if b.phase == "air":
				ang = -0.5 if b.vy < 0.0 else 0.5
			n.draw_set_transform(origin + Vector2(x, b.y - 9.0 * sy2), 0.0, Vector2(sx, sy2))
			n.draw_circle(Vector2.ZERO, 8.0, Kit.MOVER)
			n.draw_circle(Vector2(3.0, -2.4).rotated(ang), 1.8, Kit.NIGHT)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.label(n, b, "v₀ = √(2·g·h) = %d" % roundi(v0), Vector2(b.w / 2.0, b.h - 6.0), TXT, true)
		"bounce":
			Kit.ground(n, b)
			var E: float = D.e
			var s: float = 1.0 - (b.squash / 0.12) * D.squash if b.squash > 0.0 else 1.0
			n.draw_set_transform(origin + b.p + Vector2(0.0, (1.0 - s) * 9.0), 0.0, Vector2(1.0 / s, s))
			n.draw_circle(Vector2.ZERO, 9.0, Kit.MOVER)  # squash preserves "volume"
			n.draw_circle(Vector2(2.8, -2.6), 2.0, Kit.NIGHT)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.label(n, b, "bounce %d · e = %s of speed → e² of height" % [b.bounces, str(E)], Vector2(b.w / 2.0, b.h - 8.0), TXT, true)
		"dash":
			for g in b.ghosts:
				Kit.mote(n, b, g.p, g.h, Color(0.541, 0.851, 0.961, 0.35 * (1.0 - g.age / D.ghostLife)))
			Kit.ring(n, b.tgt, 6.0, Kit.TARGET, 1.5)
			if b.cool > 0.0:                             # the cooldown, sweeping shut
				n.draw_arc(b.p, 15.0, -TAU / 4.0, -TAU / 4.0 + TAU * (1.0 - b.cool / D.cooldown), 32, Kit.HOT, 2.0)
			else:
				Kit.ring(n, b.p, 15.0, Kit.DIM)
			Kit.mote(n, b, b.p, b.hd)
			Kit.label(n, b, "v ← v · e^(−k·dt)   k = %s /s" % str(D.k), Vector2(b.w / 2.0, b.h - 8.0), TXT, true)
		"ease":
			var k: float = clampf(b.clock / D.duration, 0.0, 1.0)   # the clock, normalised
			var top: float = b.h * 0.08
			var laneH: float = (b.h * 0.84 - top) / 5.0
			var x0: float = b.x0
			var x1: float = b.x1
			Kit.line(n, Vector2(x0, top), Vector2(x0, b.h * 0.84), Kit.DIM)
			Kit.line(n, Vector2(x1, top), Vector2(x1, b.h * 0.84), Color(0.961, 0.757, 0.412, 0.4))
			var names: Array = D.names
			for i in 5:
				var ly: float = top + laneH * (i + 0.5)
				var base: float = top + laneH * (i + 0.95)
				var gh: float = laneH * 0.7
				var pts := PackedVector2Array()
				for j in 31:
					var kk := j / 30.0
					pts.append(Vector2(x0 + kk * (x1 - x0), base - _ease_fn(i, kk, D) * gh))
				n.draw_polyline(pts, Color(0.91, 0.898, 0.957, 0.16), 1.0)
				var tick: float = x0 + k * (x1 - x0)
				Kit.line(n, Vector2(tick, base), Vector2(tick, base - gh), Color(0.961, 0.757, 0.412, 0.25))
				Kit.label(n, b, names[i], Vector2(6.0, ly + 4.0), Kit.DIM)
				Kit.mote(n, b, Vector2(x0 + _ease_fn(i, k, D) * (x1 - x0), ly), 0.0, Kit.MOVER, 5.0)   # ← the whole trick
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 6.0), TXT, true)
		"inertia":
			var tint := [Color(0.541, 0.851, 0.961, 0.4), Color(0.608, 0.886, 0.541, 0.4), Color(0.961, 0.757, 0.412, 0.4)]
			var names: Array = D.names
			for i in b.lanes.size():
				var L: Dictionary = b.lanes[i]
				Kit.line(n, Vector2(0.0, L.y + 8.0), Vector2(b.w, L.y + 8.0), tint[i], 1.5)
				Kit.label(n, b, "%s  μ = %s" % [names[i], str(L.mu)], Vector2(6.0, L.y - 9.0), Kit.DIM)
				Kit.ring(n, Vector2(clampf(L.mark, 6.0, b.w - 6.0), L.y), 5.0, Color(0.91, 0.898, 0.957, 0.35))
				if L.v != 0.0:
					Kit.arrow(n, Vector2(L.x, L.y), Vector2(L.x + L.v * 0.2, L.y), Kit.GOOD)
				Kit.mote(n, b, Vector2(L.x, L.y), 0.0 if L.face > 0.0 else PI, Kit.MOVER, 6.0)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), TXT, true)
		"weight":
			Kit.line(n, Vector2(b.w * 0.12, b.anchor), Vector2(b.w * 0.88, b.anchor), Kit.BONE, 2.0)
			for ball in b.balls:
				var pts := PackedVector2Array()           # the spring, a zigzag
				pts.append(Vector2(ball.x, b.anchor))
				var nz := 9
				var top: float = b.anchor + 4.0
				var bot: float = ball.y - ball.r - 2.0
				for i in range(1, nz):
					pts.append(Vector2(ball.x + (4.0 if i % 2 == 1 else -4.0), top + (bot - top) * i / float(nz)))
				pts.append(Vector2(ball.x, ball.y - ball.r))
				n.draw_polyline(pts, Kit.DIM, 1.0)
				Kit.dot(n, Vector2(ball.x, ball.y), ball.r, Kit.MOVER)
				Kit.label(n, b, "m = %s  ω = %.1f" % [str(ball.m), sqrt(D.k / ball.m)], Vector2(ball.x, b.h - 20.0), TXT, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 6.0), TXT, true)
		"yank":
			var k: float = clampf(b.clock / D.duration, 0.0, 1.0)
			var gx0: float = b.w * 0.2
			var gx1: float = b.w * 0.86
			var gh: float = b.h * 0.06 * D.vScale
			var tint := [Color(0.91, 0.898, 0.957, 0.7), Kit.GOOD, Kit.MOVER]
			var names: Array = D.names
			var to: float = b.to
			for i in 3:
				var L: Dictionary = b.lanes[i]
				var base: float = L.y + b.h * 0.14        # the velocity graph: time along, speed up
				Kit.line(n, Vector2(gx0, base), Vector2(gx1, base), FAINT)
				var pts := PackedVector2Array()
				for j in 25:
					var kk := j / 24.0
					pts.append(Vector2(lerpf(gx0, gx1, kk), base - _yank_v(i, kk) / 1.875 * gh))
				n.draw_polyline(pts, Color(0.91, 0.898, 0.957, 0.2), 1.0)
				Kit.dot(n, Vector2(lerpf(gx0, gx1, k), base - _yank_v(i, k) / 1.875 * gh), 2.0, tint[i])
				Kit.label(n, b, names[i], Vector2(6.0, L.y - 10.0), Kit.DIM)
				Kit.line(n, Vector2(to, L.y - 7.0), Vector2(to, L.y + 7.0), Kit.TARGET, 1.5)   # the destination tick
				Kit.mote(n, b, Vector2(L.x, L.y), 0.0 if to >= L.from else PI, tint[i], D.size)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 6.0), TXT, true)
		"umbrella":
			Kit.ground(n, b)
			var g: float = D.g * b.h
			var c: float = (D.cOpen if b.open else D.cClosed) / b.h
			var vt := sqrt(g / c)                        # where drag and gravity cancel
			var gx: float = b.w - 14.0                   # the speed gauge
			var gTop: float = b.h * 0.15
			var gBot: float = b.h * 0.7
			var vmax: float = sqrt(g / (D.cClosed / b.h)) * 1.05
			Kit.rect(n, Rect2(gx, gTop, 5.0, gBot - gTop), Color(0.91, 0.898, 0.957, 0.08))
			var vh: float = clampf(b.vy / vmax, 0.0, 1.0) * (gBot - gTop)
			Kit.rect(n, Rect2(gx, gBot - vh, 5.0, vh), Kit.HOT)
			var ty: float = gBot - clampf(vt / vmax, 0.0, 1.0) * (gBot - gTop)
			Kit.line(n, Vector2(gx - 4.0, ty), Vector2(gx + 9.0, ty), Kit.TARGET, 1.5)
			_label_right(n, b, "√(g/c)", Vector2(gx - 6.0, ty + 4.0), Color(0.961, 0.757, 0.412, 0.8))
			Kit.label(n, b, "v", Vector2(gx - 8.0, gBot + 4.0), Kit.DIM)
			var R: float = D.canopy * b.h                # hand, handle, canopy
			var tilt: float = b.tilt
			var hx: float = b.x
			var hy: float = b.y - 10.0
			var topp := Vector2(hx + sin(tilt) * R * 1.5, hy - cos(tilt) * R * 1.5)
			Kit.line(n, Vector2(hx, hy), topp, Kit.BONE, 1.5)
			n.draw_set_transform(origin + topp, tilt, Vector2.ONE)
			if b.open:
				_arc_fill(n, Vector2.ZERO, R, PI, TAU, Kit.TARGET)
				for i in range(-1, 2):
					_arc_fill(n, Vector2(i * R * 0.67, 0.0), R * 0.33, 0.0, PI, Kit.TARGET)
			else:
				n.draw_colored_polygon(PackedVector2Array([Vector2(0.0, -R * 0.3), Vector2(3.0, R * 0.9), Vector2(-3.0, R * 0.9)]), Kit.TARGET)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.mote(n, b, Vector2(b.x, b.y), 0.0)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 6.0), TXT, true)
		"quicksand":
			var surf: float = b.gy - 6.0
			var depth: float = maxf(0.0, b.y - surf)
			if b.phase == "climb":
				Kit.line(n, Vector2(b.ropeX, 0.0), Vector2(b.x, b.y - 8.0), Kit.BONE, 1.5)
			if b.phase != "gulp":
				Kit.mote(n, b, Vector2(b.x, b.y), -PI / 2.0 if (b.phase == "climb" or b.vy < -10.0) else 0.0)
			Kit.rect(n, Rect2(0.0, b.gy, b.w, b.h - b.gy), Color(0.227, 0.173, 0.149, 0.55))   # the sand, over whatever sank (thin enough to see it go)
			Kit.ground(n, b)
			if b.ripple > 0.0 and b.phase != "climb" and b.phase != "drop":
				Kit.ring(n, Vector2(b.x, b.gy), 6.0 + (1.0 - b.ripple) * 14.0, Color(0.961, 0.757, 0.412, b.ripple * 0.7), 1.5)
			if b.panic > 0.0 and b.phase == "sink":
				Kit.label(n, b, "!", Vector2(b.x + 12.0, b.y - 6.0), Kit.HOT)
			if b.phase == "sink":
				_label_right(n, b, "depth %d px" % roundi(depth), Vector2(b.w - 6.0, b.gy - 8.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 6.0), TXT, true)
		"slime":
			Kit.ground(n, b)
			var r: float = D.radius
			var sy: float = b.sy
			var sx := 1.0 / sy                           # ← volume preserved
			var dir: float = b.dir
			Kit.ring(n, Vector2(b.tx, b.gy - 4.0), 5.0, Kit.TARGET, 1.5)
			Kit.dot(n, Vector2(b.tx, b.gy - 4.0), 2.0, Kit.TARGET)
			n.draw_set_transform(origin + Vector2(b.x, b.y - r * sy), 0.0, Vector2(sx, sy))   # scale about the feet, not the centre
			n.draw_circle(Vector2.ZERO, r, Kit.MOVER)
			n.draw_circle(Vector2(dir * r * 0.4, -r * 0.25), r * 0.2, Kit.NIGHT)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 6.0), TXT, true)
		"cat":
			Kit.ground(n, b)
			if b.phase == "crouch":                      # the predicted arc, dotted
				var g: float = D.g * b.h
				var h: float = D.apex * b.h
				var v0 := sqrt(2.0 * g * h)
				var T := 2.0 * v0 / g
				var aim: float = (b.tx - b.x) / T
				for i in range(1, 14):
					var k := i / 14.0
					Kit.dot(n, Vector2(b.x + aim * T * k, b.gy - 4.0 * h * k * (1.0 - k)), 1.2, Color(0.91, 0.898, 0.957, 0.3))
			Kit.dot(n, Vector2(b.tx, b.gy - 4.0), 4.0, Kit.TARGET)   # the toy: a ball of yarn
			Kit.ring(n, Vector2(b.tx, b.gy - 4.0), 7.0, Color(0.961, 0.757, 0.412, 0.5))
			_draw_cat(n, b, Vector2(b.x, b.y), b.sx, b.sy, b.wig, b.tilt, t)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 6.0), TXT, true)
