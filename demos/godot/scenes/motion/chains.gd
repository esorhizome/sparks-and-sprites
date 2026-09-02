extends RefCounted

const Kit := preload("res://scenes/motion/kit.gd")
## CHAINS & JOINTS — twelve movement styles, ported from the web lexicon
## (docs/locomotion.js). Limbs. A chain is a list of points that promise
## to stay a fixed distance apart; INVERSE KINEMATICS is any recipe that
## places the joints so the end lands on a target. Four teaching cards —
## drag-follow (no solving at all), the Law of Cosines (exact, two bones),
## FABRIK (iterative, no trig), and quaternions (3D rotation, the short
## way round) — then a leader-following ring buffer, and the creatures
## built from all of it: octopus, vine, dragon, echo, inchworm, spider,
## mech. Every one is a list of joints.

const TITLE := "Chains & joints"
const BLURB := "limbs that reach and trail — inverse kinematics three ways, then the creatures built from joints"
const DEFS := [
	{ "id": "tentacle", "letter": "T", "name": "Tentacle",
		"hint": "a follow-chain: the head leads, every link keeps its distance — press to point it",
		"dials": { "n": 18, "link": 10, "taper": 0.28,        # links, the base spacing (px), shrink per link
			"follow": 3.2,                                   # the head's lerp rate toward the target
			"sway": 0.05, "swayFreq": 3,                     # the little life-sine on every joint, and its tempo
			"sticky": 3.5, "roamX": 0.34, "roamY": 0.3,      # how long a press holds; the idle wander (of W, H)
			"label": "each link: parent + (cos a, sin a) · length" },
		"rhyme": { "name": "Thrash", "hint": "the same chain with six times the sway at three times the tempo and a keener head — a whip, not a drift",
			"dials": { "sway": 0.3, "swayFreq": 9, "follow": 7 } } },
	{ "id": "ik", "letter": "I", "name": "Ik",
		"hint": "two bones, one triangle, the Law of Cosines — press to re-aim and flip the elbow",
		"dials": { "shoulderX": 0.34, "shoulderY": 0.42,      # the fixed joint (of W, H)
			"a": 0.3, "b": 0.26,                             # upper arm, forearm (of H)
			"sticky": 3.5, "roamX": 0.34, "roamY": 0.28,     # how long a press holds; the idle wander (of W, H)
			"label": "cos A = (a² + d² − b²) / 2ad" },
		"rhyme": { "name": "Insect", "hint": "a stubby upper arm and a long forearm — the same triangle, but now an insect's leg that can never fold flat",
			"dials": { "a": 0.14, "b": 0.42 } } },
	{ "id": "fabrik", "letter": "F", "name": "Fabrik",
		"hint": "IK with no trigonometry: slide joints along lines, twice, done — press to set the target",
		"dials": { "n": 4, "bone": 0.2,                       # joints, and the bone between them (of H)
			"iters": 6,                                      # backward+forward passes per frame
			"sticky": 3.5, "roamX": 0.4, "roamY": 0.3,       # how long a press holds; the idle wander (of W, H)
			"label": "backward pass, forward pass — no angles" },
		"rhyme": { "name": "Filament", "hint": "nine short bones instead of four long ones, ten passes a frame — the same solver, now a supple feeler",
			"dials": { "n": 9, "bone": 0.085, "iters": 10 } } },
	{ "id": "quaternion", "letter": "Q", "name": "Quaternion",
		"hint": "slerp turns a cube the short way; lerping three angles wobbles — press for a new pose",
		"dials": { "dur": 1.5, "rest": 1.1,                   # seconds per blend, the pause between poses
			"yawMax": 2.4, "pitchMax": 1.3,                  # how far a new pose may swing (radians)
			"size": 0.16, "persp": 4.2,                      # the cube (of H), the camera's distance in cube units
			"label": "bright: slerp(q₁, q₂)   faint: lerping yaw/pitch/roll" },
		"rhyme": { "name": "Quickstep", "hint": "the same slerp at a quarter of the duration, hardly a pause, a bigger cube — a cube dancing pose to pose",
			"dials": { "dur": 0.4, "rest": 0.3, "size": 0.22 } } },
	{ "id": "queue", "letter": "Q", "name": "Queue",
		"hint": "leader following: each body steps into where the leader stood N frames ago — press to retarget the leader",
		"dials": { "followers": 7, "spacing": 9,              # bodies in the line, ticks of delay between them
			"buf": 160,                                      # the ring buffer's length (ticks of memory)
			"speed": 75, "turn": 2.6, "jitter": 3.0,         # the leader: px/s, turn limit (rad/s), wander jitter
			"sticky": 4,                                     # how long a press steers the leader
			"label": "follower i = history[now − i · spacing]" },
		"rhyme": { "name": "Quail", "hint": "twelve followers at half the spacing and a slower stroll — a quail and her chicks, tight on her tail",
			"dials": { "followers": 12, "spacing": 4, "speed": 55 } } },
	{ "id": "octopus", "letter": "O", "name": "Octopus",
		"hint": "Tentacle ×8 behind a body that swims by jet pulses — Undulate's curl, Dash's decay — press to send it off",
		"dials": { "arms": 8, "links": 7, "link": 6,          # chains, joints per chain, joint spacing (px)
			"spread": 2.4,                                   # how wide the arms fan across the back (radians)
			"pulseEvery": 1.3, "jet": 170, "drag": 1.6,      # seconds between jets, the impulse (px/s), the decay rate
			"curl": 0.22, "curlFreq": 4,                     # the sine on every joint's angle, and its tempo
			"bodyR": 11, "sticky": 4,
			"label": "jet: v += J·dir, then v ·= e^(−drag·dt)" },
		"rhyme": { "name": "Oracle", "hint": "a jet every three seconds, gentler, with twice the curl — a deep-sea oracle drifting on its own slow thoughts",
			"dials": { "pulseEvery": 2.8, "jet": 120, "curl": 0.45 } } },
	{ "id": "vine", "letter": "V", "name": "Vine",
		"hint": "a chain that grows: each new joint bends from its parent toward the light, plus noise — press to move the sun",
		"dials": { "seg": 0.05,                               # joint length (of H)
			"growEvery": 0.28,                               # seconds per new joint
			"tropism": 0.35,                                 # how much of the turn-to-light each joint takes
			"curl": 0.5, "maxBend": 0.7,                     # the noise wobble (rad), a joint's bend limit (rad)
			"leafEvery": 3, "leafSize": 0.035,               # a leaf every k joints, its length (of H)
			"maxSegs": 40, "reach": 14, "bloomHold": 1.6,    # give up after k joints; the win radius (px); the bloom pause (s)
			"sway": 0.025, "rootX": 0.5,                     # the breeze (rad), where it is planted (of W)
			"sticky": 8,                                     # how long a press holds the light
			"label": "a = parent + (light − parent)·tropism + noise" },
		"rhyme": { "name": "Viper", "hint": "a joint every eighth of a second, triple the wobble, a weak pull to the light — a creeper that hunts, not grows",
			"dials": { "growEvery": 0.12, "curl": 1.4, "tropism": 0.15 } } },
	{ "id": "dragon", "letter": "D", "name": "Dragon",
		"hint": "Wander's head, Tentacle's body, Undulate's ripple; wings on that sine, fire on a timer — press to lure it",
		"dials": { "n": 22, "link": 9, "taper": 0.18,         # body joints, their spacing (px), shrink toward the tail
			"speed": 80, "ahead": 40, "rim": 22, "jitter": 2.8,   # Wander's rig: px/s, the circle ahead, its radius, angle jitter
			"undAmp": 5, "undFreq": 5, "undPhase": 0.55,     # Undulate's ripple: px, tempo, phase per joint
			"wingAt": 6, "wingSpan": 26,                     # which joint wears the wings, their reach (px)
			"fireEvery": 4.5, "fireDur": 1.1, "fireLen": 0.2,   # the breath schedule (s) and its length (of W)
			"sticky": 4,                                     # how long a lure holds
			"label": "body: follow-chain + sin(t·f − i·φ) sideways" },
		"rhyme": { "name": "Drake", "hint": "a twelve-joint body at nearly double the speed, breathing fire every two seconds — a small, cross, quick drake",
			"dials": { "n": 12, "speed": 130, "fireEvery": 1.8 } } },
	{ "id": "echo", "letter": "E", "name": "Echo",
		"hint": "Queue's buffer, but of the whole state — pose, heading, colour — replayed by clones — press to change the spacing",
		"dials": { "clones": 8, "spacings": [5, 12, 24],      # ghosts, and the delays (ticks) a press cycles through
			"buf": 400,                                      # ticks of memory
			"a": 1, "b": 2, "speed": 1.1, "rx": 0.36, "ry": 0.32,   # the Lissajous the mote runs (radii of W, H)
			"hueRate": 1.7,                                  # how fast the colour cycles
			"label": "clone i = state[now − i · spacing]" },
		"rhyme": { "name": "Eidolon", "hint": "four ghosts up to a second and a half apart on a 1:3 knot — an eidolon trailing its own past selves",
			"dials": { "clones": 4, "spacings": [30, 60, 90], "b": 3 } } },
	{ "id": "worm", "letter": "W", "name": "Worm",
		"hint": "Gait's planted foot, Undulate's arch — one anchor holds while the other slides — press to set its heading",
		"dials": { "lmin": 0.12, "lmax": 0.3,                 # the gap between anchors, contracted / extended (of W)
			"arch": 0.2,                                     # how high the contracted body humps (of H)
			"dur": 0.7, "pause": 0.15,                       # seconds per slide, the rest at each swap
			"links": 14, "size": 5,                          # joints drawn along the arch, their radius (px)
			"label": "arch ∝ (lmax − gap) · anchors swap each half" },
		"rhyme": { "name": "Wiggler", "hint": "half the reach and a slide three times as quick — a busy little wiggler that never stops swapping anchors",
			"dials": { "lmin": 0.06, "lmax": 0.16, "dur": 0.25 } } },
	{ "id": "spider", "letter": "S", "name": "Spider",
		"hint": "six Ik legs on a TRIPOD gait — Gait's homes and thresholds, three feet always down — press to send it off",
		"dials": { "legs": 6, "thigh": 0.13, "shin": 0.15,    # leg count, the two bones (of H)
			"spread": 0.07, "hipGap": 0.02,                  # foot homes and hips along the body (of W)
			"thresh": 0.055, "lead": 0.25,                   # Gait's step trigger (of W); how far homes lead velocity
			"dur": 0.22, "lift": 0.05,                       # step time (s), step arc height (of H)
			"ride": 0.12, "maxV": 0.3,                       # body height above the feet (of H), top speed (of W per s)
			"hill": 0.05,                                    # the terrain's bumps (of H)
			"label": "tripod: 0,2,4 then 1,3,5 · body y = mean(feet)" },
		"rhyme": { "name": "Skitter", "hint": "nearly twice the speed, steps in a tenth of a second at half the threshold — a skitter, all blur and legs",
			"dials": { "maxV": 0.55, "dur": 0.11, "thresh": 0.03 } } },
	{ "id": "mech", "letter": "M", "name": "Mech",
		"hint": "Gait made heavy — long slow strides, a thump that shakes the card, a Lookat cannon — press to send it somewhere",
		"dials": { "thigh": 0.2,                              # each leg bone (of H)
			"thresh": 0.2, "maxV": 0.22,                     # Gait's step trigger and top speed (of W)
			"dur": 0.55, "lift": 0.07,                       # seconds per stride, the foot's arc (of H)
			"hipW": 0.05, "bodyH": 0.36,                     # hip spacing (of W), hip height (of H)
			"shake": 6, "shakeDecay": 6, "shakeFreq": 40,    # the thump: px, how fast it dies (per s), its rattle (rad/s)
			"dust": 7,                                       # dust dots per plant
			"lean": 0.0015, "aim": 5,                        # torso lean per px/s² of acceleration; the cannon's tracking rate
			"label": "shake ·= e^(−k·dt) · cannon = lerp_angle" },
		"rhyme": { "name": "Mantis", "hint": "short quick strides at twice the speed on a third of the threshold — a mantis, all knees and no tonnage",
			"dials": { "dur": 0.2, "thresh": 0.08, "maxV": 0.45 } } },
]

const CUBE_EDGES := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
const TICK := 1.0 / 60.0                             # Queue and Echo: fixed ticks, so "frames ago" means the same at any rate

static func _from_euler(e: Vector3) -> Quaternion:
	# build the SAME pose both ways: yaw about Y, pitch about X, roll about Z
	return Quaternion(Vector3.UP, e.x) * Quaternion(Vector3.RIGHT, e.y) * Quaternion(Vector3.BACK, e.z)

## Vine's reset: a new seed for the wobble, an empty chain, no bloom.
static func _vine_reset(b: Dictionary) -> void:
	b.angs = []
	b.seed = randf_range(0.0, 100.0)
	b.growT = 0.0
	b.bloom = 0.0
	b.won = false

## Spider's hill: the terrain the feet land on.
static func _terra(b: Dictionary, x: float) -> float:
	var D: Dictionary = b.D
	return b.gy - b.h * D.hill * (0.55 + 0.45 * sin(x * 0.021 + 1.0) * cos(x * 0.009))

## Mech's hips: weight over the standing foot (rule 4), bobbing on a step.
static func _mech_hips(b: Dictionary) -> Vector2:
	var D: Dictionary = b.D
	var stepping: int = b.stepping
	var hip_x: float = b.bx
	if stepping >= 0:
		var planted: Dictionary = b.feet[1 - stepping]
		hip_x = b.bx + (planted.x - b.bx) * 0.25
	var bob: float = sin(clampf(b.k, 0.0, 1.0) * PI) * 4.0 if stepping >= 0 else 0.0
	var hip_y: float = b.gy - b.h * D.bodyH - bob
	return Vector2(hip_x, hip_y)

static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	match b.id:
		"tentacle":
			# the cheapest limb in games: move the head, then walk down the chain
			# placing each link at a fixed distance from the one before, along the
			# line between them (a distance constraint, solved by pure geometry —
			# each link's position is polar-to-Cartesian from its parent). drag
			# does the animating; the sway is one small sine for life.
			var N: int = int(D.n)
			b.segs = []
			for i in N:
				b.segs.append(Vector2(b.w / 2.0 - i * 9.0, b.h / 2.0))
			b.tgt = Vector2(b.w * 0.7, b.h * 0.4)
			b.sticky = 0.0
		"ik":
			# two-bone IK is exact, no iteration: shoulder→target is a triangle with
			# sides a (upper arm), b (forearm), d (the reach), and the Law of
			# Cosines hands over the shoulder angle:
			#   cos(A) = (a² + d² − b²) / (2·a·d)
			# the ± on that angle is the ELBOW FLIP — the same hand position with
			# the joint bent the other way. arms, legs, and turrets end here.
			b.flip = 1.0
			b.tgt = Vector2.ZERO
			b.sticky = 0.0
		"fabrik":
			# FABRIK (Forward And Backward Reaching IK): the BACKWARD pass pins the
			# hand to the target and drags the chain down toward the base; the
			# FORWARD pass re-pins the base and drags it back out. every step is
			# "project this point onto the line to its neighbour at bone length" —
			# constraint geometry, not one sine or cosine anywhere. it handles any
			# number of bones, and aims past its reach by simply straightening.
			var n: int = int(D.n)
			var L: float = b.h * D.bone
			b.base = Vector2(b.w / 2.0, b.gy)
			b.pts = []
			for i in n:
				b.pts.append(b.base - Vector2(0, i * L))
			b.tgt = Vector2(b.w * 0.7, b.h * 0.3)
			b.sticky = 0.0
		"quaternion":
			# in 3D, storing rotation as three angles (yaw, pitch, roll) invites
			# trouble: blending them one-by-one takes curly detours and can gimbal-
			# lock. a QUATERNION is four numbers naming an axis and a twist about
			# it; SLERP (spherical lerp) walks between two of them along the one
			# shortest arc at constant speed. the bright cube slerps; the faint
			# ghost lerps its three euler angles — same start, same end, honest
			# difference in between.
			b.ea = Vector3.ZERO
			b.eb = Vector3(randf_range(-D.yawMax, D.yawMax), randf_range(-D.pitchMax, D.pitchMax), randf_range(-D.yawMax, D.yawMax))
			b.qa = Quaternion.IDENTITY
			b.qb = _from_euler(b.eb)
			b.k = 0.0
			b.rest_t = 0.0
		"queue":
			# LEADER FOLLOWING, the conga-line trick: the leader writes where it is
			# every tick into a RING BUFFER (a fixed array written round and round,
			# the index wrapping with a modulo); follower i simply reads the entry
			# from i·spacing ticks ago. no steering, no chasing — a snake body, a
			# train of ducklings, the tail of Snake itself, all for one array. the
			# ticks are fixed at 1/60 s so "frames ago" means the same at any rate.
			b.p = Vector2(b.w * 0.5, b.h * 0.5)
			b.hd = 0.0
			b.wa = 0.0
			b.acc = 0.0
			b.head_idx = 0
			b.sticky = 0.0
			b.tgt = Vector2(b.w * 0.7, b.h * 0.4)
			b.buf = []
			for _i in int(D.buf):
				b.buf.append({ "p": b.p, "h": 0.0 })
		"octopus":
			# an octopus is three cards wearing a hat. the body swims by JET pulses:
			# every pulseEvery seconds an IMPULSE toward the target (Dash), and
			# between pulses only drag — v ·= e^(−k·dt) — so each squirt eases out
			# by itself. the eight arms are Tentacle's follow-chain, rooted around
			# the back of the mantle, with Undulate's phase-shifted sine on every
			# joint so they curl instead of trailing dead straight.
			b.p = Vector2(b.w * 0.4, b.h * 0.5)
			b.v = Vector2.ZERO
			b.hd = 0.0
			b.pulse_t = 0.6
			b.age = 9.0
			b.sticky = 0.0
			b.tgt = Vector2(b.w * 0.7, b.h * 0.4)
			b.arms = []
			for _a in int(D.arms):
				var chain := []
				for i in int(D.links):
					chain.append(Vector2(b.p.x - i * D.link, b.p.y))
				b.arms.append(chain)
		"vine":
			# PHOTOTROPISM, one joint at a time: a plant is a chain that adds a link
			# every so often, and each new link copies its parent's ANGLE, then turns
			# a fraction of the way toward the light (a lerp on an angle — wrapAngle
			# first) plus a little noise for the wobble real stems have. the angles
			# are the memory: the chain is re-laid from the root every frame with a
			# tiny sway, so nothing drifts. reach the light: bloom, rest, regrow.
			b.sticky = 0.0
			b.light = Vector2(b.w * 0.72, b.h * 0.2)
			b.pts = [Vector2(b.w * D.rootX, b.gy)]
			_vine_reset(b)
		"dragon":
			# a dragon is a Wander rig with a tail. the head steers at a jittering
			# point on a circle held out front (card W); the body is Tentacle's
			# follow-chain, so every joint keeps its distance from the one ahead;
			# the ripple is Undulate's PHASE OFFSET sine, added SIDEWAYS (along each
			# joint's normal) at draw time only — the chain stays smooth, the skin
			# waves. the wings flap on the same sine as their joint, and the fire
			# is a schedule: (t mod every) < duration. no keyframes anywhere.
			b.p = Vector2(b.w * 0.5, b.h * 0.5)
			b.v = Vector2(D.speed, 0.0)
			b.wa = 0.0
			b.sticky = 0.0
			b.tgt = Vector2.ZERO
			b.WA = mini(int(D.wingAt), int(D.n) - 2)
			b.segs = []
			for i in int(D.n):
				b.segs.append(Vector2(b.p.x - i * D.link, b.p.y))
		"echo":
			# MOTION ECHO: Queue kept only positions; this buffer keeps the mote's
			# whole STATE each tick — x, y, heading, and a colour phase — and N
			# clones replay it from further and further back. the lesson: "a body"
			# is just a record you can store and read late. the same trick powers
			# ghost racers, rewind, and every trippy afterimage. the colour is a
			# lerp between the blue and the violet, driven by its own slow sine.
			b.si = 0
			b.acc = 0.0
			b.head_idx = 0
			b.tt = 0.0
			b.buf = []
			for _i in int(D.buf):
				b.buf.append({ "p": Vector2(b.w / 2.0, b.h / 2.0), "h": 0.0, "c": 0.0 })
		"worm":
			# an INCHWORM is Gait with the legs removed: two anchors on the ground,
			# and the rule that only one ever moves. EXTEND: the rear holds, the
			# front slides forward, the hump flattens. CONTRACT: the front holds,
			# the rear slides up behind it, the hump rises. the body is not
			# simulated at all — it is an arc drawn between the anchors whose
			# height is (lmax − gap): pure geometry riding two easing curves.
			b.rear = b.w * 0.3
			b.front = b.w * 0.3 + b.w * D.lmin
			b.dir = 1.0
			b.want_dir = 1.0
			b.phase = 0                                  # phase 0 = extend, 1 = contract
			b.k = 0.0
			b.pause = 0.0
		"spider":
			# Gait, times three. each leg is two bones solved by the Law of Cosines
			# (card I), its knee chosen to point UP; each foot owns a HOME beside
			# its hip, pushed ahead by velocity, and steps when the home drifts
			# past a THRESHOLD. the gait is a TRIPOD: legs 0, 2, 4 fly together
			# while 1, 3, 5 hold, then swap — an insect is never off balance. the
			# body has no height of its own: it hangs a fixed ride above the MEAN
			# of its feet, so hills lift it and hollows drop it, for free.
			var N: int = int(D.legs)
			b.bx = b.w * 0.3
			b.vx = 0.0
			b.tx = b.w * 0.7
			b.auto_t = 0.0
			b.feet = []
			for i in N:
				var fx: float = b.bx + (i - (N - 1) / 2.0) * b.w * D.spread
				b.feet.append({ "x": fx, "y": _terra(b, fx), "from": fx, "fromY": _terra(b, fx), "to": fx })
			b.group = -1                                 # which tripod is in the air, its progress, whose turn
			b.gk = 1.0
			b.next = 0
		"mech":
			# Gait's recipe with the numbers turned to "heavy": homes, a wide
			# threshold, slow strides, two-bone IK legs. what sells the tonnage is
			# the THUMP: on every plant a screen-shake amplitude jumps up and then
			# decays — shake ·= e^(−k·dt) — while the whole scene is drawn through
			# ctx.translate(shake · sin(fast t)); plus a puff of dust dots. the
			# torso leans into its ACCELERATION (not its speed), and the cannon is
			# Lookat: lerp_angle toward the last click at a smoothing rate.
			b.bx = b.w * 0.35
			b.vx = 0.0
			b.pvx = 0.0
			b.ax = 0.0
			b.tx = b.w * 0.7
			b.auto_t = 0.0
			b.cannon_tgt = Vector2(b.w * 0.8, b.h * 0.3)
			b.aim = 0.0
			b.shake = 0.0
			b.feet = [{ "x": b.bx - b.w * D.hipW, "y": b.gy }, { "x": b.bx + b.w * D.hipW, "y": b.gy }]
			b.stepping = -1
			b.from = 0.0
			b.to = 0.0
			b.k = 0.0
			b.dust = []

static func _retarget(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var kk: float = smoothstep(0.0, 1.0, minf(1.0, b.k))
	b.qa = (b.qa as Quaternion).slerp(b.qb, kk)          # freeze wherever we are
	b.ea = (b.ea as Vector3).lerp(b.eb, kk)
	b.eb = Vector3(randf_range(-D.yawMax, D.yawMax), randf_range(-D.pitchMax, D.pitchMax), randf_range(-D.yawMax, D.yawMax))
	b.qb = _from_euler(b.eb)
	b.k = 0.0

static func _thump(b: Dictionary, x: float) -> void:
	var D: Dictionary = b.D
	b.shake = float(D.shake)                             # the amplitude jumps...
	for _i in int(D.dust):
		b.dust.append({ "p": Vector2(x, b.gy), "v": Vector2(randf_range(-60, 60), randf_range(-90, -20)), "a": 1.0 })
	while b.dust.size() > 40:
		b.dust.pop_front()

static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	match b.id:
		"tentacle", "fabrik", "queue", "octopus":
			b.tgt = pos
			b.sticky = float(D.sticky)
		"ik":
			b.tgt = pos
			b.sticky = float(D.sticky)
			b.flip = -b.flip
		"quaternion":
			_retarget(b)
			b.rest_t = 0.0
		"vine":
			b.light = pos
			b.sticky = float(D.sticky)
		"dragon":
			b.tgt = pos
			b.sticky = float(D.sticky)
		"echo":
			b.si = (b.si + 1) % (D.spacings as Array).size()
		"worm":
			b.want_dir = -1.0 if pos.x < (b.rear + b.front) / 2.0 else 1.0
		"spider":
			b.tx = clampf(pos.x, b.w * 0.1, b.w * 0.9)
			b.auto_t = -8.0
		"mech":
			b.tx = clampf(pos.x, b.w * 0.08, b.w * 0.92)
			b.auto_t = -8.0
			b.cannon_tgt = pos

## Queue's one tick: the leader wanders (or obeys a press), then writes itself into the ring.
static func _queue_tick(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var p: Vector2 = b.p
	var h: float = b.hd
	b.wa = clampf(b.wa + randf_range(-1, 1) * D.jitter * sqrt(TICK), -1.2, 1.2)   # a drifting wish to turn
	var want: float = h + b.wa
	if b.sticky > 0.0:
		want = (b.tgt - p as Vector2).angle()            # a press overrides the wish
	if p.x < b.w * 0.1 or p.x > b.w * 0.9 or p.y < b.h * 0.12 or p.y > b.h * 0.88:
		want = atan2(b.h / 2.0 - p.y, b.w / 2.0 - p.x)   # near an edge: head home
	h += clampf(wrapf(want - h, -PI, PI), -D.turn * TICK, D.turn * TICK)
	p += Vector2(cos(h), sin(h)) * D.speed * TICK
	b.head_idx = (b.head_idx + 1) % int(D.buf)           # ← the ring: write, then wrap
	var s: Dictionary = b.buf[b.head_idx]
	s.p = p
	s.h = h
	b.p = p
	b.hd = h

## Echo's one tick: the Lissajous, its derivative for the heading, and a colour phase — the whole state.
static func _echo_tick(b: Dictionary) -> void:
	var D: Dictionary = b.D
	b.tt += TICK
	var T: float = b.tt * D.speed
	var x: float = b.w / 2.0 + cos(D.a * T) * b.w * D.rx
	var y: float = b.h / 2.0 + sin(D.b * T) * b.h * D.ry
	var vx: float = -sin(D.a * T) * D.a * b.w * D.rx     # the derivative gives the heading
	var vy: float = cos(D.b * T) * D.b * b.h * D.ry
	b.head_idx = (b.head_idx + 1) % int(D.buf)
	var s: Dictionary = b.buf[b.head_idx]
	s.p = Vector2(x, y)
	s.h = atan2(vy, vx)
	s.c = 0.5 + 0.5 * sin(b.tt * D.hueRate)              # ← the whole state

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var D: Dictionary = b.D
	match b.id:
		"tentacle":
			var N: int = int(D.n)
			b.sticky -= dt
			if b.sticky <= 0.0:                          # resume its own errand
				b.tgt = Vector2(b.w / 2.0 + cos(t * 0.6) * b.w * D.roamX, b.h / 2.0 + sin(t * 0.9) * b.h * D.roamY)
			var k: float = 1.0 - exp(-D.follow * dt)     # the head is a lerp-follower
			b.segs[0] += (b.tgt - b.segs[0] as Vector2) * k
			for i in range(1, N):
				var parent: Vector2 = b.segs[i - 1]
				var L: float = maxf(2.0, D.link - i * D.taper)   # links shorten toward the tail
				var a: float = (b.segs[i] - parent as Vector2).angle() + sin(t * D.swayFreq - i * 0.5) * D.sway   # the sway
				b.segs[i] = parent + Vector2(cos(a), sin(a)) * L   # ← the whole constraint:
		"ik":                                            #   same direction, fixed length
			b.sticky -= dt
			var sh := Vector2(b.w * D.shoulderX, b.h * D.shoulderY)
			if b.sticky <= 0.0:
				b.tgt = sh + Vector2(cos(t * 0.7) * b.w * D.roamX, sin(t * 1.1) * b.h * D.roamY)
		"fabrik":
			var n: int = int(D.n)
			var base: Vector2 = b.base
			b.sticky -= dt
			if b.sticky <= 0.0:
				b.tgt = base + Vector2(cos(t * 0.55) * b.w * D.roamX, -b.h * 0.36 + sin(t * 0.85) * b.h * D.roamY)
			var L: float = b.h * D.bone
			for _it in int(D.iters):
				b.pts[n - 1] = b.tgt                     # backward: hand on target...
				for i in range(n - 2, -1, -1):           # ...each joint slides to bone length
					b.pts[i] = (b.pts[i + 1] as Vector2) - (b.pts[i + 1] - b.pts[i] as Vector2).normalized() * L
				b.pts[0] = base                          # forward: base back on its anchor...
				for i in range(1, n):
					b.pts[i] = (b.pts[i - 1] as Vector2) - (b.pts[i - 1] - b.pts[i] as Vector2).normalized() * L
		"quaternion":
			if b.k >= 1.0:
				b.rest_t += dt
				if b.rest_t > D.rest:
					b.rest_t = 0.0
					_retarget(b)
			else:
				b.k = minf(1.0, b.k + dt / D.dur)
		"queue":
			b.sticky -= dt
			b.acc = minf(b.acc + dt, 0.1)
			var guard := 0
			while b.acc >= TICK and guard < 6:
				guard += 1
				b.acc -= TICK
				_queue_tick(b)
			if b.sticky > 0.0 and (b.tgt - b.p as Vector2).length() < 10.0:
				b.sticky = 0.0
		"octopus":
			var arms: int = int(D.arms)
			var links: int = int(D.links)
			b.sticky -= dt
			if b.sticky <= 0.0:                          # an idle errand around the tank
				b.tgt = Vector2(b.w / 2.0 + cos(t * 0.35) * b.w * 0.32, b.h / 2.0 + sin(t * 0.55) * b.h * 0.28)
			var to: Vector2 = b.tgt - b.p
			var d: float = to.length()
			if d == 0.0:
				d = 1.0
			b.pulse_t -= dt
			b.age += dt
			if b.pulse_t <= 0.0:
				b.pulse_t = float(D.pulseEvery)
				b.age = 0.0
				var J: float = D.jet * clampf(d / 80.0, 0.25, 1.0)   # a softer squirt when nearly there
				b.v += to / d * J                        # the IMPULSE: velocity edited once
			var decay: float = exp(-D.drag * dt)         # then only drag, every frame
			b.v *= decay
			b.p += b.v * dt
			var m := 24.0
			if b.p.x < m:
				b.p.x = m
				b.v.x = absf(b.v.x) * 0.5
			if b.p.x > b.w - m:
				b.p.x = b.w - m
				b.v.x = -absf(b.v.x) * 0.5
			if b.p.y < m:
				b.p.y = m
				b.v.y = absf(b.v.y) * 0.5
			if b.p.y > b.h - m:
				b.p.y = b.h - m
				b.v.y = -absf(b.v.y) * 0.5
			if (b.v as Vector2).length() > 8.0:
				b.hd += wrapf((b.v as Vector2).angle() - b.hd, -PI, PI) * minf(1.0, 6.0 * dt)
			var p: Vector2 = b.p
			var h: float = b.hd
			for a in arms:
				var chain: Array = b.arms[a]
				var root: float = h + PI + ((a + 0.5) / float(arms) - 0.5) * D.spread   # rooted on the back
				chain[0] = p + Vector2(cos(root), sin(root)) * D.bodyR * 0.8
				for i in range(1, links):
					var par: Vector2 = chain[i - 1]
					var aa: float = (chain[i] - par as Vector2).angle()   # Tentacle's constraint...
					aa += wrapf(root - aa, -PI, PI) * 0.08              # ...a whisper of "trail behind"
					aa += sin(t * D.curlFreq - i * 0.7 + a * 0.9) * D.curl   # ...and Undulate's curl
					chain[i] = par + Vector2(cos(aa), sin(aa)) * D.link
		"vine":
			b.sticky -= dt
			if b.sticky <= 0.0:                          # the sun wanders, slowly
				b.light = Vector2(b.w / 2.0 + cos(t * 0.23) * b.w * 0.36, b.h * 0.3 + sin(t * 0.31) * b.h * 0.16)
			var light: Vector2 = b.light
			var L: float = b.h * D.seg
			var angs: Array = b.angs
			var q := Vector2(b.w * D.rootX, b.gy)
			var pts: Array = b.pts
			pts.clear()
			pts.append(q)
			for i in angs.size():                        # re-lay the chain from its angles
				var a: float = angs[i] + sin(t * 1.3 - i * 0.35) * D.sway * (1.0 + i * 0.1)
				var g: float = clampf(b.growT / D.growEvery, 0.05, 1.0) if i == angs.size() - 1 else 1.0   # the tip grows in
				q += Vector2(cos(a), sin(a)) * L * g
				pts.append(q)
			if b.bloom > 0.0:
				b.bloom -= dt
				if b.bloom <= 0.0:
					_vine_reset(b)
			else:
				b.growT += dt
				if b.growT >= D.growEvery:
					b.growT = 0.0
					var parent: float = angs[angs.size() - 1] if angs.size() > 0 else -PI / 2.0   # the seed points up
					var to_light: float = (light - q).angle()
					var bend: float = wrapf(to_light - parent, -PI, PI) * D.tropism \
						+ Kit.noise(angs.size() * 0.9 + b.seed) * D.curl   # ← phototropism, ← the wobble
					angs.append(parent + clampf(bend, -D.maxBend, D.maxBend))
				if angs.size() > 0 and (light - q).length() < D.reach:
					b.bloom = float(D.bloomHold)
					b.won = true
				elif angs.size() >= int(D.maxSegs):
					b.bloom = D.bloomHold * 0.4          # too long: wilt, try again
		"dragon":
			var N: int = int(D.n)
			b.sticky -= dt
			b.wa += randf_range(-1, 1) * D.jitter * sqrt(dt)   # the only randomness in the rig
			var p: Vector2 = b.p
			var v: Vector2 = b.v
			var sp: float = v.length()
			if sp == 0.0:
				sp = 1.0
			var hv: Vector2 = v / sp
			var head: float = hv.angle()
			var g: Vector2 = p + hv * D.ahead + Vector2(cos(head + b.wa), sin(head + b.wa)) * D.rim   # Wander's rim dot
			if b.sticky > 0.0:
				g = b.tgt
				if (b.tgt - p as Vector2).length() < 12.0:
					b.sticky = 0.0
			if p.x < b.w * 0.1 or p.x > b.w * 0.9 or p.y < b.h * 0.12 or p.y > b.h * 0.88:
				g = Vector2(b.w / 2.0, b.h / 2.0)
			var to: Vector2 = g - p
			var d: float = to.length()
			if d == 0.0:
				d = 1.0
			v += (to / d * D.speed - v) * minf(1.0, 3.0 * dt)
			var s2: float = v.length()
			if s2 == 0.0:
				s2 = 1.0
			v *= D.speed / s2                            # a constant cruise
			p += v * dt
			b.p = p
			b.v = v
			b.segs[0] = p
			for i in range(1, N):                        # Tentacle's constraint, link by link
				var par: Vector2 = b.segs[i - 1]
				var dd: Vector2 = b.segs[i] - par
				var ddl: float = dd.length()
				if ddl == 0.0:
					ddl = 1.0
				var L: float = maxf(3.0, D.link - i * D.taper)
				b.segs[i] = par + dd / ddl * L
		"echo":
			b.acc = minf(b.acc + dt, 0.1)
			var guard := 0
			while b.acc >= TICK and guard < 6:
				guard += 1
				b.acc -= TICK
				_echo_tick(b)
		"worm":
			var LMIN: float = b.w * D.lmin
			var LMAX: float = b.w * D.lmax
			if b.pause > 0.0:
				b.pause -= dt
			else:
				b.k += dt / D.dur
				var e: float = smoothstep(0.0, 1.0, clampf(b.k, 0.0, 1.0))
				if b.phase == 0:
					b.front = b.rear + b.dir * (LMIN + (LMAX - LMIN) * e)   # rear holds, front slides
				else:
					b.rear = b.front - b.dir * (LMAX - (LMAX - LMIN) * e)   # front holds, rear catches up
				if b.k >= 1.0:                           # ← the anchor swap
					b.k = 0.0
					b.phase = 1 - b.phase
					b.pause = float(D.pause)
					if b.phase == 0:                     # only turn around while contracted
						if b.dir > 0.0 and b.front + LMAX > b.w * 0.95:
							b.want_dir = -1.0
						if b.dir < 0.0 and b.front - LMAX < b.w * 0.05:
							b.want_dir = 1.0
						if b.want_dir != b.dir:
							b.dir = b.want_dir
							var tmp: float = b.rear
							b.rear = b.front
							b.front = tmp
		"spider":
			var N: int = int(D.legs)
			b.auto_t += dt
			if b.auto_t > 5.0:
				b.auto_t = 0.0
				b.tx = randf_range(b.w * 0.1, b.w * 0.9)
			var want: float = clampf((b.tx - b.bx) * 2.0, -b.w * D.maxV, b.w * D.maxV)
			b.vx += (want - b.vx) * minf(1.0, 5.0 * dt)
			b.bx += b.vx * dt
			var bx: float = b.bx
			var vx: float = b.vx
			if b.group < 0:                              # rule 2: does either tripod need to step?
				for g0 in 2:
					if b.group >= 0:
						break
					var g: int = (b.next + g0) % 2
					var need := false
					for i in range(g, N, 2):
						if absf(bx + (i - (N - 1) / 2.0) * b.w * D.spread + vx * D.lead - (b.feet[i] as Dictionary).x) > b.w * D.thresh:
							need = true
					if need:
						b.group = g
						b.gk = 0.0
						b.next = 1 - g
						for i in range(g, N, 2):
							var f: Dictionary = b.feet[i]
							f.from = f.x
							f.fromY = f.y
							f.to = bx + (i - (N - 1) / 2.0) * b.w * D.spread + vx * (D.lead + 0.1)   # land a little ahead again
			if b.group >= 0:                             # rule 3: the whole tripod flies its arc
				b.gk += dt / D.dur
				var e: float = smoothstep(0.0, 1.0, b.gk)
				var lift: float = sin(clampf(b.gk, 0.0, 1.0) * PI) * b.h * D.lift
				for i in range(b.group, N, 2):
					var f: Dictionary = b.feet[i]
					f.x = f.from + (f.to - f.from) * e
					f.y = lerpf(f.fromY, _terra(b, f.to), e) - lift
				if b.gk >= 1.0:
					for i in range(b.group, N, 2):
						var f: Dictionary = b.feet[i]
						f.y = _terra(b, f.x)
					b.group = -1
		"mech":
			b.auto_t += dt
			if b.auto_t > 6.0:
				b.auto_t = 0.0
				b.tx = randf_range(b.w * 0.12, b.w * 0.88)
			var want: float = clampf((b.tx - b.bx) * 1.5, -b.w * D.maxV, b.w * D.maxV)
			b.vx += (want - b.vx) * minf(1.0, 2.5 * dt)
			b.ax += ((b.vx - b.pvx) / maxf(dt, 0.001) - b.ax) * minf(1.0, 6.0 * dt)   # smoothed acceleration
			b.pvx = b.vx
			b.bx += b.vx * dt
			for i in 2:                                  # Gait's rules 1 and 2: homes, threshold
				var home: float = b.bx + (1.0 if i == 1 else -1.0) * b.w * D.hipW + b.vx * 0.3
				if b.stepping < 0 and absf(home - (b.feet[i] as Dictionary).x) > b.w * D.thresh:
					b.stepping = i
					b.from = (b.feet[i] as Dictionary).x
					b.k = 0.0
					b.to = home + b.vx * 0.15
			if b.stepping >= 0:                          # rule 3: the arc — then the THUMP
				b.k += dt / D.dur
				var f: Dictionary = b.feet[b.stepping]
				f.x = b.from + (b.to - b.from) * smoothstep(0.0, 1.0, b.k)
				f.y = b.gy - sin(clampf(b.k, 0.0, 1.0) * PI) * b.h * D.lift
				if b.k >= 1.0:
					f.y = b.gy
					b.stepping = -1
					_thump(b, f.x)
			b.shake *= exp(-D.shakeDecay * dt)           # ...and decays, framerate-proof
			var dust: Array = b.dust
			for i in range(dust.size() - 1, -1, -1):     # the dust falls, settles, fades
				var q: Dictionary = dust[i]
				q.v.y += 200.0 * dt
				q.p += q.v * dt
				if q.p.y > b.gy:
					q.p.y = b.gy
				q.a -= 1.4 * dt
				if q.a <= 0.0:
					dust.remove_at(i)
			var hips := _mech_hips(b)
			var s := Vector2(hips.x, hips.y - 18.0)      # the shoulder mount
			var want_aim: float = (b.cannon_tgt - s as Vector2).angle()
			b.aim += wrapf(want_aim - b.aim, -PI, PI) * Kit.smooth(D.aim, dt)   # Lookat: lerp_angle, the short way

static func _draw_cube(n: CanvasItem, b: Dictionary, q: Quaternion, size: float, col: Color, lw: float) -> void:
	var D: Dictionary = b.D
	var c := Vector2(b.w / 2.0, b.h * 0.48)
	var F: float = D.persp
	var pts := []
	for i in 8:
		var v := Vector3(1 if i & 1 else -1, 1 if i & 2 else -1, 1 if i & 4 else -1)
		var r := q * v                                   # rotate a point: q · v · q⁻¹
		var s := F / (F + r.z) * size                    # a whisper of perspective
		pts.append(c + Vector2(r.x, r.y) * s)
	for e in CUBE_EDGES:
		n.draw_line(pts[e[0]], pts[e[1]], col, lw)

## Echo's colour: MOVER → MAGIC, channel by channel.
static func _echo_col(c: float, alpha: float) -> Color:
	return Color(roundf(lerpf(138, 201, c)) / 255.0, roundf(lerpf(217, 160, c)) / 255.0, 245.0 / 255.0, alpha)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	Kit.stage(n, b)
	var D: Dictionary = b.D
	var origin: Vector2 = (b.rect as Rect2).position
	match b.id:
		"tentacle":
			var N: int = int(D.n)
			for i in range(N - 1, -1, -1):
				var r: float = maxf(1.6, 8.5 - i * 0.42)
				var col := Kit.MOVER if i == 0 else Color(0.541, 0.851, 0.961, maxf(0.08, 0.8 - i * 0.038))
				Kit.dot(n, b.segs[i], r, col)
			var head: Vector2 = b.segs[0]
			var hd := (b.tgt - head as Vector2).angle()  # the eye watches the target
			Kit.dot(n, head + Vector2(cos(hd), sin(hd)) * 3.4, 2.0, Kit.NIGHT)
			Kit.dot(n, b.tgt, 3.0, Kit.TARGET)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"ik":
			var sh := Vector2(b.w * D.shoulderX, b.h * D.shoulderY)
			var a: float = b.h * D.a
			var bo: float = b.h * D.b
			var to: Vector2 = b.tgt - sh
			var reach := clampf(to.length(), absf(a - bo) + 2.0, a + bo - 2.0)   # stay solvable
			var base := to.angle()
			var cos_a := (a * a + reach * reach - bo * bo) / (2.0 * a * reach)   # Law of Cosines
			var ang: float = base + acos(clampf(cos_a, -1.0, 1.0)) * b.flip
			var elbow := sh + Vector2(cos(ang), sin(ang)) * a   # the elbow
			var hand := sh + Vector2(cos(base), sin(base)) * reach
			Kit.ring(n, sh, a + bo, Color(0.91, 0.898, 0.957, 0.08))   # the reach envelope
			n.draw_dashed_line(sh, hand, Kit.DIM, 1.0, 7.0)            # the triangle being solved
			n.draw_polyline(PackedVector2Array([sh, elbow, hand]), Kit.BONE, 6.0)
			Kit.dot(n, sh, 5.0, Kit.MOVER)
			Kit.dot(n, elbow, 4.5, Kit.BONE)
			Kit.dot(n, hand, 4.0, Kit.TARGET)
			Kit.label(n, b, "a", (sh + elbow) / 2.0 - Vector2(10, 0), Color(0.788, 0.769, 0.894, 0.8))
			Kit.label(n, b, "b", (elbow + hand) / 2.0 + Vector2(8, 0), Color(0.788, 0.769, 0.894, 0.8))
			Kit.label(n, b, "d", (sh + hand) / 2.0 + Vector2(6, 12), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"fabrik":
			var nn: int = int(D.n)
			var L: float = b.h * D.bone
			Kit.ground(n, b)
			Kit.ring(n, b.base, L * (nn - 1), Color(0.91, 0.898, 0.957, 0.08))   # the reach circle
			for i in nn - 1:
				n.draw_line(b.pts[i], b.pts[i + 1], Kit.BONE, maxf(1.5, 7.0 - i * 1.5))
			for i in nn:
				Kit.dot(n, b.pts[i], maxf(1.5, 4.5 - i * 0.5), Kit.BONE if i > 0 else Kit.MOVER)
			Kit.dot(n, b.tgt, 3.5, Kit.TARGET)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"quaternion":
			var kk: float = smoothstep(0.0, 1.0, b.k)
			var ge: Vector3 = (b.ea as Vector3).lerp(b.eb, kk)         # the naive route
			_draw_cube(n, b, _from_euler(ge), b.h * D.size, Color(0.91, 0.898, 0.957, 0.2), 1.0)
			_draw_cube(n, b, (b.qa as Quaternion).slerp(b.qb, kk), b.h * D.size, Kit.MOVER, 1.5)   # the quaternion route
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"queue":
			var BUF: int = int(D.buf)
			var followers: int = int(D.followers)
			var spacing: int = int(D.spacing)
			var head_idx: int = b.head_idx
			for i in range(0, BUF, 4):                   # the buffer, faintly
				Kit.dot(n, (b.buf[i] as Dictionary).p, 1.0, Color(0.91, 0.898, 0.957, 0.12))
			for i in range(followers, 0, -1):            # tail first, so the front overlaps
				var back: int = mini(i * spacing, BUF - 1)
				var s: Dictionary = b.buf[(head_idx - back + BUF) % BUF]   # ← the read: now − i·spacing, wrapped
				Kit.mote(n, b, s.p, s.h, Color(0.541, 0.851, 0.961, maxf(0.2, 0.85 - i * 0.08)), maxf(3.0, 7.0 - i * 0.4))
			if b.sticky > 0.0:
				Kit.dot(n, b.tgt, 3.5, Kit.TARGET)
			Kit.mote(n, b, b.p, b.hd)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"octopus":
			var arms: int = int(D.arms)
			var links: int = int(D.links)
			var p: Vector2 = b.p
			var h: float = b.hd
			var R: float = D.bodyR
			var squeeze: float = exp(-b.age * 5.0)       # the mantle contracts on each jet
			for a in arms:
				var chain: Array = b.arms[a]
				for i in range(links - 1, -1, -1):
					Kit.dot(n, chain[i], maxf(1.2, 3.6 - i * 0.4), Color(0.541, 0.851, 0.961, maxf(0.1, 0.75 - i * 0.08)))
			if b.age < 0.35:                             # the jet's puff, behind the mantle
				Kit.ring(n, p - Vector2(cos(h), sin(h)) * R, 4.0 + b.age * 60.0, Color(0.541, 0.851, 0.961, maxf(0.0, 0.5 - b.age * 1.4)))
			n.draw_set_transform(origin + p, h, Vector2(1.0 + squeeze * 0.3, 1.0 - squeeze * 0.25))   # squash & stretch along the jet
			n.draw_circle(Vector2.ZERO, R, Kit.MOVER)
			n.draw_circle(Vector2(-R * 0.5, 0), R * 0.85, Kit.MOVER)   # the mantle
			n.draw_circle(Vector2(R * 0.45, -R * 0.35), 2.2, Kit.NIGHT)
			n.draw_circle(Vector2(R * 0.45, R * 0.35), 2.2, Kit.NIGHT)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.dot(n, b.tgt, 3.0, Kit.TARGET)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"vine":
			var pts: Array = b.pts
			var light: Vector2 = b.light
			var leaf_every: int = int(D.leafEvery)
			Kit.ground(n, b)
			for i in pts.size() - 1:
				Kit.line(n, pts[i], pts[i + 1], Kit.GOOD, maxf(1.0, 3.5 - i * 0.07))
			var i := leaf_every
			while i < pts.size():                        # leaves, alternating sides
				var p: Vector2 = pts[i]
				var q: Vector2 = pts[i - 1]
				var dd: Vector2 = p - q
				var ddl: float = dd.length()
				if ddl == 0.0:
					ddl = 1.0
				var side: float = 1.0 if (i / leaf_every) % 2 == 1 else -1.0
				var u: Vector2 = dd / ddl
				var nv := Vector2(-u.y, u.x) * side
				var s: float = b.h * D.leafSize
				Kit.poly(n, [p, p + (nv * 0.5 + u * 0.35) * s, p + nv * s, p + (nv * 0.5 - u * 0.35) * s], Color(0.608, 0.886, 0.541, 0.55))
				i += leaf_every
			var tip: Vector2 = pts[pts.size() - 1]
			if b.bloom > 0.0:
				Kit.ring(n, tip, 5.0 + (D.bloomHold - b.bloom) * 12.0, Kit.MAGIC if b.won else Kit.DIM, 1.5)
				Kit.dot(n, tip, 4.0, Kit.MAGIC if b.won else Kit.DIM)
			else:
				var ta := (light - tip).angle()          # the pull it will feel next
				Kit.arrow(n, tip, tip + Vector2(cos(ta), sin(ta)) * 16.0, Kit.DIM)
				Kit.dot(n, tip, 2.5, Kit.MAGIC)
			Kit.ring(n, light, 9.0, Color(0.961, 0.757, 0.412, 0.35))
			Kit.dot(n, light, 4.0, Kit.TARGET)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"dragon":
			var N: int = int(D.n)
			var WA: int = b.WA
			var p: Vector2 = b.p
			var v: Vector2 = b.v
			var sp: float = v.length()
			if sp == 0.0:
				sp = 1.0
			var hv: Vector2 = v / sp
			var head: float = hv.angle()
			var fire: bool = fmod(t, D.fireEvery) < D.fireDur   # the breath is a schedule
			for i in range(N - 1, 0, -1):                # tail first, head on top
				var par: Vector2 = b.segs[i - 1]
				var s: Vector2 = b.segs[i]
				var dd: Vector2 = par - s
				var ddl: float = dd.length()
				if ddl == 0.0:
					ddl = 1.0
				var u: Vector2 = dd / ddl                # toward the head, and its normal
				var nv := Vector2(-u.y, u.x)
				var off: float = sin(t * D.undFreq - i * D.undPhase) * D.undAmp * (0.3 + i / float(N))   # the ripple
				var q: Vector2 = s + nv * off
				var r: float = maxf(1.5, 8.0 - i * 0.32)
				if i == WA:                              # the wings, flapping on the same sine
					var flap: float = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * D.undFreq - i * D.undPhase))
					for side in [-1.0, 1.0]:
						var reach: float = D.wingSpan * flap * side
						var wa: Vector2 = q - u * 4.0
						var wb: Vector2 = q + nv * reach - u * D.wingSpan * 0.45
						var wc: Vector2 = q + nv * reach * 0.55 - u * D.wingSpan * 0.9
						var wd: Vector2 = q + u * 6.0
						var wcol := Color(0.788, 0.627, 0.961, 0.6) if side < 0.0 else Color(0.788, 0.627, 0.961, 0.4)
						# the web quad is a bowtie (edges a→b and c→d cross); canvas fills both lobes,
						# Godot's triangulator refuses it — so fill the two lobes as triangles
						var x: Variant = Geometry2D.segment_intersects_segment(wa, wb, wc, wd)
						if x == null:
							Kit.poly(n, [wa, wb, wc, wd], wcol)
						else:
							Kit.poly(n, [x, wb, wc], wcol)
							Kit.poly(n, [x, wd, wa], wcol)
				if i % 3 == 0:                           # a spine every third joint
					Kit.poly(n, [q + nv * r, q + nv * (r + 5.0) - u * 2.0, q + nv * r - u * 4.0], Color(0.788, 0.627, 0.961, 0.7))
				Kit.dot(n, q, r, Color(0.541, 0.851, 0.961, maxf(0.15, 0.85 - i * 0.03)))
			if fire:                                     # the lantern: dots along the heading, jittered by noise
				var m: Vector2 = p + hv * 12.0
				var nv := Vector2(-hv.y, hv.x)
				for j in 12:
					var k: float = (j + 0.5) / 12.0
					var wob: float = Kit.noise(t * 9.0 + j * 1.7) * k * 10.0
					Kit.dot(n, m + hv * k * b.w * D.fireLen + nv * wob, 2.0 + k * 4.0,
						Color(0.961, 0.541, 0.541, (1.0 - k) * 0.8) if j % 2 == 1 else Color(0.961, 0.757, 0.412, (1.0 - k) * 0.8))
			var pv := Vector2(-hv.y, hv.x)
			Kit.line(n, p - hv * 3.0 + pv * 5.0, p - hv * 10.0 + pv * 10.0, Kit.MAGIC, 2.0)   # horns
			Kit.line(n, p - hv * 3.0 - pv * 5.0, p - hv * 10.0 - pv * 10.0, Kit.MAGIC, 2.0)
			Kit.mote(n, b, p, head, Kit.MOVER, 9.0)
			if b.sticky > 0.0:
				Kit.dot(n, b.tgt, 3.0, Kit.TARGET)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"echo":
			var BUF: int = int(D.buf)
			var clones: int = int(D.clones)
			var head_idx: int = b.head_idx
			var sp: int = int((D.spacings as Array)[b.si])
			for i in range(0, BUF, 6):                   # the buffer
				Kit.dot(n, (b.buf[i] as Dictionary).p, 0.8, Color(0.91, 0.898, 0.957, 0.1))
			for i in range(clones, 0, -1):               # oldest first, faintest
				var back: int = mini(i * sp, BUF - 1)
				var s: Dictionary = b.buf[(head_idx - back + BUF) % BUF]
				Kit.mote(n, b, s.p, s.h, _echo_col(s.c, maxf(0.12, 0.8 - i * (0.7 / clones))), maxf(4.0, 8.0 - i * 0.3))
			var now: Dictionary = b.buf[head_idx]
			Kit.mote(n, b, now.p, now.h, _echo_col(now.c, 1.0))
			var txt := "spacing = %d ticks" % sp        # right-aligned: measure, then place
			var tw: float = ThemeDB.fallback_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			Kit.label(n, b, txt, Vector2(b.w - 8.0 - tw, 14.0))
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"worm":
			var LMIN: float = b.w * D.lmin
			var LMAX: float = b.w * D.lmax
			var links: int = int(D.links)
			var size: float = D.size
			var gy: float = b.gy
			Kit.ground(n, b)
			var gap: float = absf(b.front - b.rear)
			var hump: float = b.h * D.arch * clampf((LMAX - gap) / (LMAX - LMIN), 0.12, 1.0)   # ← arch ∝ lmax − gap
			var holding: float = b.rear if b.phase == 0 else b.front
			var sliding: float = b.front if b.phase == 0 else b.rear
			Kit.ring(n, Vector2(holding, gy), 6.0, Kit.BONE, 1.5)
			Kit.ring(n, Vector2(sliding, gy), 4.0, Kit.DIM, 1.0)
			Kit.label(n, b, "hold", Vector2(holding, gy + 18.0), Color(0.788, 0.769, 0.894, 0.7), true)
			Kit.label(n, b, "slide", Vector2(sliding, gy + 18.0), Kit.DIM, true)
			for j in links:                              # the arc, as a chain of dots
				var kk: float = j / float(links - 1)
				var x: float = b.rear + (b.front - b.rear) * kk
				var y: float = gy - sin(kk * PI) * hump - size
				Kit.dot(n, Vector2(x, y), size * (0.7 + kk * 0.3), Kit.MOVER if j == links - 1 else Color(0.541, 0.851, 0.961, 0.4 + kk * 0.4))
				if j == links - 1:                       # the head gets the eye
					Kit.dot(n, Vector2(x + b.dir * size * 0.4, y - size * 0.3), size * 0.28, Kit.NIGHT)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"spider":
			var N: int = int(D.legs)
			var THIGH: float = b.h * D.thigh
			var SHIN: float = b.h * D.shin
			var bx: float = b.bx
			var group: int = b.group
			var mean_y := 0.0
			for i in N:
				mean_y += (b.feet[i] as Dictionary).y
			mean_y /= N
			var body_y: float = mean_y - b.h * D.ride - (sin(clampf(b.gk, 0.0, 1.0) * PI) * 2.0 if group >= 0 else 0.0)   # rule 4
			var hill := PackedVector2Array([Vector2(0, _terra(b, 0.0))])   # the hill itself
			var hx := 4.0
			while hx <= b.w:
				hill.append(Vector2(hx, _terra(b, hx)))
				hx += 4.0
			n.draw_polyline(hill, Color(0.788, 0.769, 0.894, 0.55), 1.5)
			hill.append(Vector2(b.w, b.h))
			hill.append(Vector2(0, b.h))
			n.draw_colored_polygon(hill, Color(0.588, 0.569, 0.745, 0.13))
			for i in N:                                  # two-bone IK, straight from card I
				var hip := Vector2(bx + (i - (N - 1) / 2.0) * b.w * D.hipGap, body_y + 3.0)
				var f: Dictionary = b.feet[i]
				var foot := Vector2(f.x, f.y)
				var to: Vector2 = foot - hip
				var d: float = clampf(to.length(), absf(THIGH - SHIN) + 2.0, THIGH + SHIN - 2.0)
				var bse: float = to.angle()
				var A: float = acos(clampf((THIGH * THIGH + d * d - SHIN * SHIN) / (2.0 * THIGH * d), -1.0, 1.0))
				var a1: float = bse + A                  # both elbow flips...
				var a2: float = bse - A
				var a: float = a1 if sin(a1) < sin(a2) else a2   # ...keep the knee that points UP
				var knee := hip + Vector2(cos(a), sin(a)) * THIGH
				n.draw_polyline(PackedVector2Array([hip, knee, foot]), Kit.BONE, 2.5)
				Kit.dot(n, knee, 2.0, Kit.BONE)
				Kit.dot(n, foot, 2.0, Color(0.788, 0.769, 0.894, 0.5) if i % 2 == group else Kit.BONE)
			var face: float = 1.0 if b.vx >= 0.0 else -1.0
			Kit.dot(n, Vector2(bx - face * 9.0, body_y - 2.0), 7.5, Color(0.541, 0.851, 0.961, 0.8))   # abdomen
			Kit.dot(n, Vector2(bx, body_y), 8.0, Kit.MOVER)                                          # cephalothorax
			Kit.dot(n, Vector2(bx + face * 4.0, body_y - 3.0), 1.8, Kit.NIGHT)
			Kit.dot(n, Vector2(bx + face * 6.0, body_y - 0.5), 1.4, Kit.NIGHT)
			Kit.ring(n, Vector2(b.tx, _terra(b, b.tx) - 5.0), 5.0, Kit.TARGET, 1.5)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"mech":
			var THIGH: float = b.h * D.thigh
			var gy: float = b.gy
			var shake: float = b.shake
			var shake_off := Vector2(sin(t * D.shakeFreq) * shake, cos(t * D.shakeFreq * 1.3) * shake * 0.6)
			n.draw_set_transform(origin + shake_off, 0.0, Vector2.ONE)   # the whole scene rattles
			Kit.ground(n, b)
			for q in b.dust:
				Kit.dot(n, q.p, 2.0, Color(0.788, 0.769, 0.894, q.a * 0.6))
			var hips := _mech_hips(b)                    # rule 4: weight over the standing foot
			var hip_x: float = hips.x
			var hip_y: float = hips.y
			for i in 2:                                  # two-bone IK, straight from card I
				var hip := Vector2(hip_x + (1.0 if i == 1 else -1.0) * b.w * D.hipW * 0.5, hip_y)
				var f: Dictionary = b.feet[i]
				var foot := Vector2(f.x, f.y)
				var to: Vector2 = foot - hip
				var d: float = clampf(to.length(), 4.0, THIGH * 2.0 - 2.0)
				var bse: float = to.angle()
				var cos_a: float = clampf(d / (2.0 * THIGH), -1.0, 1.0)   # equal bones: the Law of Cosines simplifies
				var knee_side: float = -1.0 if b.vx >= 0.0 else 1.0       # knees bend away from travel
				var a: float = bse + acos(cos_a) * knee_side
				var knee := hip + Vector2(cos(a), sin(a)) * THIGH
				n.draw_polyline(PackedVector2Array([hip, knee, foot]), Kit.BONE, 5.0)
				Kit.rect(n, Rect2(f.x - 7.0, f.y - 4.0, 14.0, 4.0), Kit.BONE)   # a flat, heavy foot
			var lean: float = clampf(b.ax * D.lean, -0.35, 0.35)   # into the acceleration
			n.draw_set_transform(origin + shake_off + Vector2(hip_x, hip_y), lean, Vector2.ONE)
			Kit.rect(n, Rect2(-14.0, -28.0, 28.0, 28.0), Kit.MOVER)   # the torso
			Kit.dot(n, Vector2(0, -18), 4.0, Kit.NIGHT)              # the cockpit
			n.draw_set_transform(origin + shake_off, 0.0, Vector2.ONE)
			var s := Vector2(hip_x, hip_y - 18.0)        # the shoulder mount
			var aim: float = b.aim
			var muzzle := s + Vector2(cos(aim), sin(aim)) * 24.0
			Kit.line(n, s, muzzle, Kit.BONE, 4.0)
			Kit.dot(n, muzzle, 2.0, Kit.HOT)
			Kit.ring(n, b.cannon_tgt, 5.0, Color(0.961, 0.541, 0.541, 0.6), 1.0)
			Kit.ring(n, Vector2(b.tx, gy - 4.0), 5.0, Kit.TARGET, 1.5)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
