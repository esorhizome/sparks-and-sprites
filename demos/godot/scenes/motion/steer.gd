extends RefCounted

const Kit := preload("res://scenes/motion/kit.gd")
## BRAINS & STEERING — thirteen movement styles, ported from the web lexicon
## (docs/locomotion.js). How enemies decide. A steering agent keeps a
## velocity and, each frame, computes a DESIRED velocity from what it wants
## — then applies only a gentle correction (desired − current, clamped).
## That one subtraction is why steered things bank, drift, and overshoot
## like living creatures instead of snapping like cursors. Everything here
## is vector maths: subtract two points to get "toward", divide by length
## to get a pure direction, multiply to choose a speed. Lap 2 adds the
## negatives (flee, evade), a whisker for dodging rocks, and a state
## machine with moods; the genre laps spend all of it on a ghost, a
## tractor beam, fireflies, a butterfly, a horde, and a game of volley.

const TITLE := "Brains & steering"
const BLURB := "desired − current, clamped: seek, flee, wander, whiskers, moods — how enemies decide where to go"
const DEFS := [
	{ "id": "arrive", "letter": "A", "name": "Arrive",
		"hint": "seek, but braking inside the amber ring — press to move the target",
		"dials": { "maxsp": 130, "maxf": 300, "slow": 85,            # top speed (px/s), steering clamp (px/s²), brake ring (px)
			"retarget": 3.2 },                                        # seconds before it picks a new spot on its own
		"rhyme": { "name": "Ambush", "hint": "twice the speed, half the brake ring, a harder steering clamp — a lunge that leaves the braking to the last moment",
			"dials": { "maxsp": 260, "maxf": 700, "slow": 40 } } },
	{ "id": "chase", "letter": "C", "name": "Chase",
		"hint": "aim where the prey WILL be — the faint rival aims where it is — press to scatter",
		"dials": { "preySpeed": 112, "chaseSpeed": 95,               # px/s — the prey is quicker; prediction makes up for it
			"fear": 95, "lead": 0.9, "jitter": 2.6 },                 # flee radius (px), how far ahead to aim, the prey's wobble
		"rhyme": { "name": "Cheetah", "hint": "the hunters now outrun the prey and its fear ring is wider — a sprint with short, brutal catches instead of a long stalk",
			"dials": { "chaseSpeed": 128, "preySpeed": 100, "fear": 130 } } },
	{ "id": "wander", "letter": "W", "name": "Wander",
		"hint": "the classic wander rig: a jittering target on a circle held out front — press to startle",
		"dials": { "ahead": 46, "rim": 26,                           # the guide circle: how far out front, how big (px)
			"jitter": 3.1, "speed": 85, "turn": 3 },                  # rim-angle wobble, px/s, how keenly it steers
		"rhyme": { "name": "Wasp", "hint": "a rim wider than the reach, twice the jitter, half again the speed — the target can swing behind it: darting and angry",
			"dials": { "rim": 58, "jitter": 6.5, "speed": 125 } } },
	{ "id": "zigzag", "letter": "Z", "name": "Zigzag",
		"hint": "a patrol path with eased legs and pauses — press to add a waypoint",
		"dials": { "speed": 150, "ghost": 110,                       # px/s: the saw's leg speed, the ghost's constant speed
			"pause": 0.45, "spin": 9, "maxPts": 8 },                  # the corner rest (s), blade spin (rad/s), waypoint cap
		"rhyme": { "name": "Zoom", "hint": "nearly three times the leg speed, a blink of a pause, a quicker ghost — the same route as a whip-crack instead of a plod",
			"dials": { "speed": 420, "ghost": 230, "pause": 0.08 } } },
	{ "id": "flee", "letter": "F", "name": "Flee",
		"hint": "flee = seek × −1, evade = pursuit × −1, and a burrow the hunter can't enter — press to place the hunter",
		"dials": { "preySpeed": 120, "chaseSpeed": 95,               # px/s: the prey is quicker, the hunter leads its aim
			"fear": 0.34, "burrow": 0.13,                             # the fear radius (× W) and the burrow's size (× H)
			"lead": 0.8, "patience": 2.5 },                           # how far ahead both aim · seconds the hunter waits at the rim
		"rhyme": { "name": "Fox", "hint": "a hunter faster than its prey, aiming further ahead, with half the patience — only the burrow saves it now, and not for long",
			"dials": { "chaseSpeed": 140, "lead": 1.3, "patience": 1.2 } } },
	{ "id": "obstacle", "letter": "O", "name": "Obstacle",
		"hint": "a whisker feels ahead; where it crosses a rock, steer out along the normal — press to move the goal",
		"dials": { "speed": 110, "force": 380, "whisker": 0.3,       # px/s, steering clamp (px/s²), feeler length (× W)
			"avoid": 2.4, "count": 3, "radius": 0.1, "seed": 11 },    # dodge gain, rocks, rock size (× H), the layout's seed
		"rhyme": { "name": "Otter", "hint": "seven smaller rocks and half again the speed — a rock field threaded at a sprint, the whisker flicking side to side",
			"dials": { "count": 7, "radius": 0.06, "speed": 150 } } },
	{ "id": "zones", "letter": "Z", "name": "Zones",
		"hint": "a state machine by radius: patrol → alert → chase → return, drawn as rings — press to place the player",
		"dials": { "sense": 0.24, "lose": 0.42,                      # the alert ring and the give-up ring (× W)
			"patrol": 55, "chase": 125,                               # px/s in each mood
			"alert": 0.8, "drift": 0.25 },                            # seconds of "!" before the chase · how briskly the player wanders
		"rhyme": { "name": "Zealot", "hint": "a sense ring twice as wide, a give-up ring it can barely leave, no pause at all — a guard that never lets go",
			"dials": { "sense": 0.45, "lose": 0.85, "alert": 0.15 } } },
	{ "id": "ghost", "letter": "G", "name": "Ghost",
		"hint": "it only moves behind your back: a dot product says if it's in the view cone — press to look toward your click",
		"dials": { "cone": 70, "speed": 70,                          # view cone width (degrees) · ghost px/s while unseen
			"turn": 3.2, "glance": 2.2,                               # gaze turn rate (rad/s) · seconds between glances
			"boo": 12 },                                              # how close counts as a scare (px)
		"rhyme": { "name": "Ghoul", "hint": "a cone twice as wide but a thing nearly twice as fast, a gaze that flits every second — seen more, and it still gets you",
			"dials": { "cone": 140, "speed": 130, "glance": 0.9 } } },
	{ "id": "tractorbeam", "letter": "T", "name": "Tractorbeam", "drag": true,
		"hint": "a cone of pull: full on the axis, fading with distance, debris spirals into the hold — drag to sweep the beam",
		"dials": { "half": 20, "reach": 0.8,                         # cone half-angle (degrees) · beam length (× H)
			"pull": 260, "damp": 1.4,                                 # px/s² on the axis at the ship · drag on debris (per s)
			"sweep": 0.45, "count": 24 },                             # idle sweep rate (rad/s) · bits of debris
		"rhyme": { "name": "Trawler", "hint": "a cone nearly three times as wide, a weaker pull, twice the debris — a slow net that gathers, not a beam that snatches",
			"dials": { "half": 55, "pull": 150, "count": 44 } } },
	{ "id": "firefly", "letter": "F", "name": "Firefly",
		"hint": "wander on smooth noise, glow on a personal phase, Arrive at the lantern when lit — press to move the lantern",
		"dials": { "count": 14, "speed": 42,                         # fireflies · px/s
			"wander": 0.35, "slow": 0.3,                              # how fast the noise is sampled · the lantern's Arrive ring (× W)
			"lit": 3.5, "dark": 2.5, "blink": 0.6 },                  # the lantern's seconds on and off · glows per second
		"rhyme": { "name": "Flicker", "hint": "twice the flies, twice the speed, glows nearly three times as quick — a busier, sparkier meadow that mobs the lantern",
			"dials": { "count": 30, "speed": 80, "blink": 1.6 } } },
	{ "id": "butterfly", "letter": "B", "name": "Butterfly",
		"hint": "flap impulses on a jittered timer, gravity between, a slow Arrive to the next flower — press to plant a flower",
		"dials": { "kick": 0.6, "gravity": 1.3,                      # a flap's upward kick (× H per s) · gravity (× H per s²)
			"flap": 0.34, "jitter": 0.5,                              # seconds between flaps, and how uneven they are (a fraction)
			"speed": 65, "linger": 1.2 },                             # px/s toward the flower · seconds sipping nectar
		"rhyme": { "name": "Bumblebee", "hint": "flaps four times as often, each half the kick, twice the drive — the sawtooth blurs into a buzzing, near-straight hover",
			"dials": { "flap": 0.08, "kick": 0.32, "speed": 120 } } },
	{ "id": "zombies", "letter": "Z", "name": "Zombies",
		"hint": "a horde: seek with a noisy heading, lurch on a personal timer, keep apart — press to move the player",
		"dials": { "count": 16, "speed": 40, "lurch": 0.8,           # zombies · px/s at full lurch · lurches per second
			"wobble": 0.9, "sep": 18,                                 # heading noise (radians) · personal space (px)
			"player": 70 },                                           # px/s: the player is quicker, and never rests
		"rhyme": { "name": "Zerg", "hint": "twice the horde, twice the speed, lurches four times as fast — the shuffle becomes a rush the player can't outrun",
			"dials": { "count": 30, "speed": 85, "lurch": 3 } } },
	{ "id": "volley", "letter": "V", "name": "Volley",
		"hint": "paddles solve the flight for the landing point, Arrive there first, then lob it back — press to nudge the ball",
		"dials": { "gravity": 2.2, "apex": 0.45,                     # gravity (× H per s²) · the height every return aims for (× H)
			"reach": 0.06, "paddle": 0.9,                             # a paddle's half-width (× W) and top speed (× W per s)
			"net": 0.22, "nudge": 0.9 },                              # net height (× H) · the press's shove (× H per s)
		"rhyme": { "name": "Velocity", "hint": "twice the gravity, lower lobs, paddles half again as quick — the same maths played fast and flat",
			"dials": { "gravity": 4.5, "apex": 0.3, "paddle": 1.5 } } },
]

const LBL := Color(0.91, 0.898, 0.957, 0.55)   # the web label()'s default ink

## The web's `len(...) || 1`: a length, or 1 when it is exactly zero.
static func _or1(x: float) -> float:
	return x if x != 0.0 else 1.0

## ctx.setLineDash + ring: Godot has no dashed arc, so one is stitched from
## short arcs — dash and gap in pixels along the circumference.
static func _dashed_ring(n: CanvasItem, p: Vector2, r: float, col: Color, w: float, dash: float, gap: float) -> void:
	var rr := maxf(r, 0.5)
	var circ := TAU * rr
	var step := (dash + gap) / circ * TAU
	var a := 0.0
	while a < TAU:
		n.draw_arc(p, rr, a, minf(a + dash / circ * TAU, TAU), 6, col, w)
		a += step

# ---------------------------------------------------------------- helpers

static func _zig_defaults(b: Dictionary) -> Array:
	var pts := []
	for i in 5:
		pts.append(Vector2(b.w * (0.12 + i * 0.19), b.h * 0.25 if i % 2 == 1 else b.h * 0.65))
	return pts

## Chase's steer(): an agent dictionary {p, v} toward a point. The one
## subtraction, clamped per component, then a speed cap and the walls.
static func _chase_steer(a: Dictionary, tgt: Vector2, maxsp: float, force: float, dt: float, b: Dictionary) -> void:
	var to: Vector2 = tgt - a.p
	var d := _or1(to.length())
	a.v.x += clampf(to.x / d * maxsp - a.v.x, -force, force) * dt * 4.0
	a.v.y += clampf(to.y / d * maxsp - a.v.y, -force, force) * dt * 4.0
	var s: float = (a.v as Vector2).length()
	if s > maxsp:
		a.v *= maxsp / s
	a.p += a.v * dt
	if a.p.x < 10.0:
		a.p.x = 10.0
	if a.p.x > b.w - 10.0:
		a.p.x = b.w - 10.0
	if a.p.y < 10.0:
		a.p.y = 10.0
	if a.p.y > b.h - 10.0:
		a.p.y = b.h - 10.0

## Flee's steer(): steering = desired − current, clamped; soft walls that
## reflect a little of the velocity.
static func _flee_steer(a: Dictionary, des: Vector2, force: float, dt: float, b: Dictionary) -> void:
	var s: Vector2 = des - a.v
	var sl := s.length()
	if sl > force:
		s = s / sl * force
	a.v += s * dt
	a.p += a.v * dt
	if a.p.x < 10.0:
		a.p.x = 10.0
		a.v.x = absf(a.v.x) * 0.4
	if a.p.x > b.w - 10.0:
		a.p.x = b.w - 10.0
		a.v.x = -absf(a.v.x) * 0.4
	if a.p.y < 10.0:
		a.p.y = 10.0
		a.v.y = absf(a.v.y) * 0.4
	if a.p.y > b.h - 10.0:
		a.p.y = b.h - 10.0
		a.v.y = -absf(a.v.y) * 0.4

## Obstacle: a spot not inside any rock.
static func _rock_clear(b: Dictionary, p: Vector2) -> bool:
	for r in b.rocks:
		if (p - r.p as Vector2).length() < r.r + 12.0:
			return false
	return true

static func _rock_pick(b: Dictionary) -> Vector2:
	for i in 12:
		var p := Vector2(randf_range(b.w * 0.08, b.w * 0.92), randf_range(b.h * 0.1, b.h * 0.9))
		if _rock_clear(b, p):
			return p
	return Vector2(b.w * 0.5, b.h * 0.92)

## Zones: move toward, turning smoothly; true on arrival.
static func _zone_walk(b: Dictionary, tgt: Vector2, speed: float, dt: float) -> bool:
	var to: Vector2 = tgt - b.p
	var d := _or1(to.length())
	if d < 4.0:
		return true
	b.h += wrapf(atan2(to.y, to.x) - b.h, -PI, PI) * minf(1.0, 8.0 * dt)
	var step := minf(d, speed * dt)
	b.p += to / d * step
	return false

## Ghost: somewhere on the rim, out of view.
static func _ghost_spawn(b: Dictionary) -> void:
	var a: float = b.h + PI + randf_range(-1, 1)
	var R: float = maxf(b.w, b.h) * 0.6
	var c: Vector2 = b.c
	b.g = Vector2(clampf(c.x + cos(a) * R, 6.0, b.w - 6.0), clampf(c.y + sin(a) * R, 6.0, b.h - 6.0))
	b.gv = Vector2.ZERO

## Tractorbeam: a fresh bit of debris, adrift in the lower stage.
static func _beam_spawn(b: Dictionary, bit: Dictionary) -> void:
	bit.p = Vector2(randf_range(0, b.w), randf_range(b.h * 0.35, b.h))
	bit.v = Vector2(randf_range(-12, 12), randf_range(-8, 8))
	bit.caught = false
	bit.a = 0.0
	bit.r = 0.0
	bit.inside = false

static func _bfly_defaults(b: Dictionary) -> Array:
	return [Vector2(b.w * 0.2, b.gy - b.h * 0.3), Vector2(b.w * 0.55, b.gy - b.h * 0.5), Vector2(b.w * 0.85, b.gy - b.h * 0.25)]

## Volley: launch toward a spot on the other court.
static func _volley_hit(b: Dictionary, from: float, side: float, g: float) -> void:
	var D: Dictionary = b.D
	var v0: float = sqrt(2.0 * g * b.h * D.apex)
	var T: float = 2.0 * v0 / g
	var tx: float = b.w / 2.0 - side * b.w * randf_range(0.12, 0.42)
	b.bv = Vector2((tx - from) / T, -v0)

# ---------------------------------------------------------------- init

static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	match b.id:
		"arrive":
			# plain seek arrives like a dart hitting a board. ARRIVE scales the
			# desired speed down with distance inside a slow radius, so the brakes
			# come on early and the stop is a real stop. the arrows tell the story:
			# green = current velocity, red = the correction being applied.
			b.p = Vector2(b.w * 0.2, b.h * 0.7)
			b.v = Vector2.ZERO
			b.tgt = Vector2(b.w * 0.7, b.h * 0.35)
			b.timer = 0.0
			b.steer = Vector2.ZERO
		"chase":
			# pursuit: the smart chaser leads its target like a goalkeeper, steering
			# at prey position + prey velocity · (time to get there). the ghost
			# chaser runs exactly as fast but aims at where the prey IS — watch it
			# trail forever on curves. prediction is one multiply-add.
			b.prey = { "p": Vector2(b.w * 0.6, b.h * 0.4), "v": Vector2.ZERO }
			b.smart = { "p": Vector2(b.w * 0.15, b.h * 0.8), "v": Vector2.ZERO }
			b.naive = { "p": Vector2(b.w * 0.85, b.h * 0.8), "v": Vector2.ZERO }
			b.wa = 0.0
			b.caught = 0
			b.flash = 0.0
			b.future = b.prey.p
		"wander":
			# aimless-looking motion that never twitches: hold an invisible circle a
			# fixed distance ahead, keep a target ON its rim, and jitter that
			# target's angle a little each frame. steering at the rim point smooths
			# all the randomness through the circle's geometry. the rig is usually
			# hidden — here it's the whole show.
			b.p = Vector2(b.w / 2.0, b.h / 2.0)
			b.v = Vector2(60.0, 0.0)
			b.wa = 0.0
			b.burst = 0.0
			b.guide = b.p
			b.rim = b.p
		"zigzag":
			# the humble patrol obstacle: waypoints, and a schedule for travelling
			# between them. the saw EASES each leg (slow-fast-slow) and rests at
			# corners — the ghost covers the same path at constant speed. same
			# route, entirely different menace. easing is design, not decoration.
			b.pts = _zig_defaults(b)
			b.seg = 0                                    # the eased saw
			b.dir = 1
			b.k = 0.0
			b.pause = 0.0
			b.gd = 0.0                                   # the ghost's distance along the path
		"flee":
			# every steering behaviour has an evil twin: FLEE is seek with the sign
			# flipped (desired = away from the threat), EVADE is pursuit flipped —
			# run from where the hunter WILL be, not where it is. the prey only
			# bothers inside its fear radius; outside it grazes. the burrow is a
			# rule, not a force: the hunter may not step inside, so the flee vector
			# leans toward it — a flee with a plan. the hunter is the mote.
			b.prey = { "p": Vector2(b.w * 0.62, b.h * 0.4), "v": Vector2.ZERO }
			b.hunt = { "p": Vector2(b.w * 0.15, b.h * 0.75), "v": Vector2.ZERO }
			b.gz = Vector2(b.w * 0.5, b.h * 0.5)         # the prey's grazing spot
			b.graze = 0.0
			b.sulk = Vector2(b.w * 0.5, b.h * 0.5)       # the hunter's sulk spot, and its patience
			b.bored = 0.0
			b.wait = 0.0
			b.caught = 0
			b.flash = 0.0
			b.mode = "graze"
			b.des = Vector2.ZERO                         # the prey's desired velocity (for the arrow)
			b.fut = Vector2.ZERO                         # the hunter's predicted point (the thing it runs FROM)
		"obstacle":
			# the mote can't see; it FEELS. a WHISKER (a feeler segment) sticks out
			# along its velocity, and each frame it asks every rock: does my whisker
			# cross you? the closest point on the segment to the rock's centre is a
			# PROJECTION (one dot product, clamped to the segment); if that point
			# lies inside the rock, steer along the NORMAL — from the rock's centre
			# out through that point — and harder the nearer the crossing is. no
			# map, no pathfinding: a reflex, which is why it sometimes dithers.
			var rnd := Kit.rng(int(D.seed))
			b.rocks = []
			for i in int(D.count):
				var rx: float = b.w * (0.18 + rnd.randf() * 0.64)
				var ry: float = b.h * (0.15 + rnd.randf() * 0.6)
				var rr: float = b.h * D.radius * (0.7 + rnd.randf() * 0.6)
				b.rocks.append({ "p": Vector2(rx, ry), "r": rr })
			b.p = Vector2(b.w * 0.08, b.h * 0.85)
			b.v = Vector2(40.0, 0.0)
			b.timer = 0.0
			b.goal = _rock_pick(b)
			b.hit = {}
			b.hd = Vector2.RIGHT
			b.L = 0.0
		"zones":
			# a STATE MACHINE is a brain with a mood: one word names what it is
			# doing, and only a few EVENTS may change the word. here the events are
			# radii. cross the sense ring and PATROL becomes ALERT — a pause with a
			# "!" that makes stealth games fair; CHASE lasts until the player leaves
			# the bigger ring; RETURN walks home, and the loop closes. every state
			# has its own speed and its own goal: the mood IS the motion.
			b.posts = [Vector2(b.w * 0.16, b.h * 0.25), Vector2(b.w * 0.42, b.h * 0.8)]
			b.p = b.posts[0]
			b.h = 0.0
			b.post = 1
			b.state = "patrol"
			b.st = 0.0
			b.pp = Vector2(b.w * 0.75, b.h * 0.45)
			b.hold = 0.0
			b.caught = 0
			b.flash = 0.0
		"ghost":
			# "is it in view?" is one DOT PRODUCT. normalise the vector to the
			# ghost, dot it with the gaze direction, and the answer is cos(angle
			# between them) — so "inside a 70° cone" is simply dot > cos(35°). the
			# ghost Arrives at the mote while that test fails and freezes the
			# instant it passes: Weeping Angels, Boo, red-light-green-light, all
			# this one comparison. the gaze looks around with Yaw's turn limit.
			b.c = Vector2(b.w / 2.0, b.h * 0.55)
			b.h = 0.0
			b.aim = 0.0
			b.glance = 0.0
			b.hold = 0.0
			b.g = Vector2.ZERO
			b.gv = Vector2.ZERO
			b.scares = 0
			b.flash = 0.0
			b.seen = false
			b.dotp = 0.0
			b.half = D.cone * PI / 360.0
			_ghost_spawn(b)
		"tractorbeam":
			# a force field with a SHAPE. every bit of debris asks two questions:
			# how far off the beam's axis am I (an angle — atan2, then wrapAngle),
			# and how far down it (a distance)? inside the cone the pull is
			#   F = pull · (1 − |off| ÷ half) ÷ (1 + d ÷ R)
			# — full on the axis, nothing at the rim, fading down the beam — plus a
			# nudge toward the axis so the flow funnels. outside the cone: nothing,
			# just drift. inside the hold ring a bit is caught and spirals in on
			# Orbit's polar trick with a shrinking r. this is Magnet, given an aim.
			b.s = Vector2(b.w / 2.0, b.h * 0.16)
			b.beam = PI / 2.0
			b.aim = PI / 2.0
			b.hold = 0.0
			b.held = 0
			b.bits = []
			for i in int(D.count):
				var bit := { "seed": i * 9.1 }
				_beam_spawn(b, bit)
				b.bits.append(bit)
		"firefly":
			# Wander with its dice swapped for NOISE: each fly's heading is
			# noise(t · rate + its own offset) · π — smooth, never twitchy, and no
			# two alike because each samples a different stretch of the same
			# function (Jitter's lesson). the glow is a sine on a personal PHASE, so
			# the meadow twinkles instead of strobing. when the lantern is lit,
			# Arrive takes the wheel — desired = toward it, braking inside the slow
			# ring — with a little wander still mixed in, so they hover, not park.
			b.flies = []
			for i in int(D.count):
				b.flies.append({ "p": Vector2(randf_range(0, b.w), randf_range(b.h * 0.1, b.gy - 10.0)),
					"v": Vector2.ZERO, "ph": randf_range(0, TAU), "seed": i * 17.3 })
			b.l = Vector2(b.w * 0.5, b.gy - b.h * 0.18)
			b.clock = 0.0
			b.on = false
		"butterfly":
			# why does a butterfly look nothing like a bird? IMPULSES. a bird's lift
			# is continuous; a butterfly's is a kick — an instant upward velocity
			# at every flap, gravity pulling between kicks — and the flap timer is
			# JITTERED (rand around a mean), so the sawtooth never repeats. it only
			# flaps while it's below the flower, so it bobs about the flower's
			# height instead of climbing forever. under that stagger a slow Arrive
			# tows it sideways toward the next flower; the flowers are a list,
			# visited in turn. Jitter's randomness + Arrive's intent = erratic,
			# and still gets there.
			b.flowers = _bfly_defaults(b)
			b.idx = 0
			b.p = Vector2(b.w * 0.1, b.h * 0.3)
			b.v = Vector2.ZERO
			b.flapT = 0.2
			b.since = 1.0
			b.linger = 0.0
		"zombies":
			# Arrive's seek, degraded on purpose. each zombie aims at the player,
			# then spoils the aim with noise (a wobble on the heading, sampled at
			# its own offset), moves in LURCHES — a speed that pulses as sin² on a
			# personal timer, so the pauses are real — and keeps a little
			# separation from its neighbours (Swarm's first rule, and nothing
			# else: no alignment, no cohesion; a horde has no manners). slow,
			# uneven, many: the threat is arithmetic, not speed.
			b.zs = []
			for i in int(D.count):
				b.zs.append({ "p": Vector2(randf_range(0, b.w * 0.4), randf_range(0, b.h)), "h": 0.0,
					"ph": randf_range(0, TAU), "rate": randf_range(0.7, 1.3), "seed": i * 7.7 })
			b.pp = Vector2(b.w * 0.75, b.h * 0.5)
			b.pv = Vector2.ZERO
			b.pa = 0.0
			b.bites = 0
			b.flash = 0.0
		"volley":
			# Chase predicted with one multiply; this predicts with the quadratic
			# formula. a ball under gravity reaches a height h below it after
			#   t = (v + √(v² + 2·g·h)) ÷ g          (solve  h = v·t + ½·g·t²  for t)
			# and its LANDING POINT is just x + vx·t — so a paddle knows where to
			# stand the moment the ball leaves the far side, and Arrives there
			# (braking, not overshooting). the return runs Jump backwards: choose
			# the apex, v₀ = √(2·g·apex) is the launch, the flight time 2·v₀ ÷ g
			# picks the vx that lands it on a spot of the paddle's choosing.
			b.PY = b.gy - 10.0
			b.pads = [{ "x": b.w * 0.22, "vx": 0.0, "side": -1.0, "c": Kit.GOOD },
				{ "x": b.w * 0.78, "vx": 0.0, "side": 1.0, "c": Kit.MOVER }]
			b.bp = Vector2(b.w * 0.22, b.PY - 30.0)
			b.bv = Vector2.ZERO
			b.dead = 0.6
			b.server = 0
			b.rally = 0
			b.lx = b.bp.x
			b.tl = 0.0

# ---------------------------------------------------------------- press

static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	match b.id:
		"arrive":
			b.tgt = pos
			b.timer = -4.0
		"chase":
			b.prey.p = pos
			b.prey.v = Vector2(randf_range(-90, 90), randf_range(-90, 90))
		"wander":
			b.wa = randf_range(-PI, PI)
			b.burst = 1.0
		"zigzag":
			if b.pts.size() >= int(D.maxPts):
				b.pts = _zig_defaults(b)
			else:
				b.pts.append(pos)
			b.seg = 0
			b.dir = 1
			b.k = 0.0
			b.pause = 0.0
			b.gd = 0.0
		"flee":
			b.hunt.p = pos
			b.hunt.v = Vector2.ZERO
			b.bored = 0.0
			b.wait = 0.0
		"obstacle":
			b.goal = pos
			b.timer = -5.0
		"zones":
			b.pp = Vector2(clampf(pos.x, 10.0, b.w - 10.0), clampf(pos.y, 10.0, b.h - 10.0))
			b.hold = 4.0
		"ghost":
			var c: Vector2 = b.c
			b.aim = atan2(pos.y - c.y, pos.x - c.x)
			b.hold = 2.5
		"tractorbeam":
			var s: Vector2 = b.s
			b.aim = PI / 2.0 + clampf(wrapf(atan2(pos.y - s.y, pos.x - s.x) - PI / 2.0, -PI, PI), -1.35, 1.35)
			b.hold = 3.0
		"firefly":
			b.l = Vector2(clampf(pos.x, 14.0, b.w - 14.0), clampf(pos.y, b.h * 0.2, b.gy - 12.0))
			b.clock = 0.0
		"butterfly":
			if b.flowers.size() >= 6:
				b.flowers = _bfly_defaults(b)
				b.idx = 0
			b.flowers.append(Vector2(clampf(pos.x, 12.0, b.w - 12.0), clampf(pos.y, b.h * 0.12, b.gy - 14.0)))
			b.idx = b.flowers.size() - 1
			b.linger = 0.0
		"zombies":
			b.pp = Vector2(clampf(pos.x, 10.0, b.w - 10.0), clampf(pos.y, 10.0, b.h - 10.0))
			b.pv = Vector2.ZERO
			b.flash = 0.6
		"volley":
			if b.dead > 0.0:
				b.dead = 0.0
				_volley_hit(b, b.bp.x, b.pads[b.server].side, b.h * D.gravity)
				return
			var to: Vector2 = pos - b.bp
			var d := _or1(to.length())
			b.bv += to / d * b.h * D.nudge

# ---------------------------------------------------------------- tick

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var D: Dictionary = b.D
	match b.id:
		"arrive":
			b.timer += dt
			if b.timer > D.retarget:
				b.timer = 0.0
				b.tgt = Vector2(randf_range(b.w * 0.15, b.w * 0.85), randf_range(b.h * 0.15, b.h * 0.85))
			var to: Vector2 = b.tgt - b.p
			var d := _or1(to.length())
			var speed: float = D.maxsp * minf(1.0, d / D.slow)   # ← the whole idea of Arrive
			var desired := to / d * speed
			var s: Vector2 = desired - b.v                   # steering = desired − current
			var sl := s.length()
			if sl > D.maxf:
				s = s / sl * D.maxf
			b.steer = s
			b.v += s * dt
			b.p += b.v * dt
		"chase":
			b.wa += randf_range(-D.jitter, D.jitter) * sqrt(dt)   # the prey wanders...
			var flee := Vector2(cos(b.wa), sin(b.wa)) * 105.0
			var pd: float = (b.smart.p - b.prey.p as Vector2).length()
			if pd < D.fear:                              # ...and flees the smart one
				flee += (b.prey.p - b.smart.p as Vector2) / pd * 150.0
			_chase_steer(b.prey, b.prey.p + flee, D.preySpeed, 260.0, dt, b)
			var eta: float = pd / D.chaseSpeed           # rough time-to-intercept
			b.future = b.prey.p + b.prey.v * eta * D.lead
			_chase_steer(b.smart, b.future, D.chaseSpeed, 240.0, dt, b)
			_chase_steer(b.naive, b.prey.p, D.chaseSpeed, 240.0, dt, b)
			if pd < 14.0:
				b.caught += 1
				b.flash = 1.0
				b.prey.p = Vector2(randf_range(b.w * 0.1, b.w * 0.9), randf_range(b.h * 0.1, b.h * 0.9))
			b.flash = maxf(0.0, b.flash - dt * 2.0)
		"wander":
			b.burst = maxf(0.0, b.burst - dt * 0.7)
			b.wa += randf_range(-1, 1) * D.jitter * sqrt(dt)     # the only randomness in the rig
			var v: Vector2 = b.v
			var sp := _or1(v.length())
			var hd := v / sp
			b.guide = b.p + hd * D.ahead                 # the guide circle, out front
			var head := atan2(hd.y, hd.x)
			b.rim = b.guide + Vector2(cos(head + b.wa), sin(head + b.wa)) * D.rim
			var maxsp: float = D.speed * (1.0 + b.burst * 1.2)
			var to: Vector2 = b.rim - b.p
			var d := _or1(to.length())
			b.v += (to / d * maxsp - b.v) * D.turn * dt
			b.p += b.v * dt
			if b.p.x < -12.0:
				b.p.x = b.w + 12.0
			if b.p.x > b.w + 12.0:
				b.p.x = -12.0
			if b.p.y < -12.0:
				b.p.y = b.h + 12.0
			if b.p.y > b.h + 12.0:
				b.p.y = -12.0
		"zigzag":
			var a: Vector2 = b.pts[b.seg]
			var c: Vector2 = b.pts[b.seg + 1]
			var leg_len := _or1(a.distance_to(c))
			if b.pause > 0.0:
				b.pause -= dt
			else:
				b.k += dt * D.speed / leg_len            # constant speed, eased per leg
				if b.k >= 1.0:
					b.k = 0.0
					b.pause = D.pause                    # the corner rest
					b.seg += b.dir
					if b.seg > b.pts.size() - 2:
						b.seg = b.pts.size() - 2
						b.dir = -1
					if b.seg < 0:
						b.seg = 0
						b.dir = 1
			var total := 0.0
			for i in b.pts.size() - 1:
				total += (b.pts[i] as Vector2).distance_to(b.pts[i + 1])
			total = _or1(total)
			b.gd = fmod(b.gd + D.ghost * dt, total * 2.0)   # ghost ping-pongs by distance
		"flee":
			var hc := Vector2(b.w * 0.8, b.h * 0.72)     # the burrow
			var hr: float = b.h * D.burrow
			var fear: float = b.w * D.fear
			var prey: Dictionary = b.prey
			var hunt: Dictionary = b.hunt
			var to: Vector2 = hunt.p - prey.p
			var d := _or1(to.length())
			var hidden: bool = (prey.p - hc as Vector2).length() < hr
			var des := Vector2.ZERO
			if d < fear:                                 # afraid: evade the hunter's FUTURE
				var eta: float = d / D.preySpeed
				var f: Vector2 = hunt.p + hunt.v * eta * D.lead
				var a: Vector2 = prey.p - f              # seek × −1: the same vector, backwards
				a /= _or1(a.length())
				var tb: Vector2 = hc - prey.p
				a += tb / _or1(tb.length()) * 0.7        # ...leaning toward the burrow
				des = a / _or1(a.length()) * D.preySpeed
				b.mode = "evade"
				if hidden:
					des = (hc - prey.p as Vector2) * 3.0
					b.mode = "hide"
			else:                                        # calm: graze toward a lazy target
				b.graze -= dt
				if b.graze <= 0.0:
					b.graze = randf_range(2, 4)
					b.gz = Vector2(randf_range(b.w * 0.1, b.w * 0.9), randf_range(b.h * 0.1, b.h * 0.9))
				var gto: Vector2 = b.gz - prey.p
				var gd := _or1(gto.length())
				var sp: float = D.preySpeed * 0.4 * minf(1.0, gd / 40.0)
				des = gto / gd * sp
				b.mode = "graze"
			b.des = des
			_flee_steer(prey, des, 420.0, dt, b)
			if hidden:                                   # the hunter's side of the story
				b.wait += dt
			else:
				b.wait = 0.0
			if b.wait > D.patience:
				b.wait = 0.0
				b.bored = 3.0
				b.sulk = Vector2(randf_range(b.w * 0.1, b.w * 0.5), randf_range(b.h * 0.1, b.h * 0.9))
			b.bored -= dt
			var e: Vector2
			if b.bored > 0.0:                            # gave up: sulk off somewhere
				e = b.sulk
			else:                                        # pursuit: lead the prey (Chase's trick)
				var eta: float = d / D.chaseSpeed
				e = prey.p + prey.v * eta * D.lead
			var cto: Vector2 = e - hunt.p
			var cd := _or1(cto.length())
			var csp: float = D.chaseSpeed * minf(1.0, cd / 30.0)
			_flee_steer(hunt, cto / cd * csp, 320.0, dt, b)
			var r: Vector2 = hunt.p - hc
			var rd := _or1(r.length())
			if rd < hr + 9.0:                            # the burrow rule: no hunters inside
				hunt.p = hc + r / rd * (hr + 9.0)
				hunt.v *= 0.3
			if d < 13.0 and not hidden:                  # caught: back to the burrow it goes
				b.caught += 1
				b.flash = 1.0
				prey.p = hc
				prey.v = Vector2.ZERO
			b.flash = maxf(0.0, b.flash - dt * 2.0)
			var eta2: float = d / D.preySpeed            # the point it runs FROM, made visible
			b.fut = hunt.p + hunt.v * eta2 * D.lead
		"obstacle":
			b.timer += dt
			var to: Vector2 = b.goal - b.p
			var d := _or1(to.length())
			if d < 12.0 or b.timer > 6.0:
				b.goal = _rock_pick(b)
				b.timer = 0.0
			var sp: float = D.speed * minf(1.0, d / 50.0)   # Arrive at the goal...
			var des := to / d * sp
			var vel: Vector2 = b.v
			var v := _or1(vel.length())
			var hd := vel / v
			var L: float = b.w * D.whisker * clampf(v / D.speed, 0.35, 1.0)   # ...feeling further when faster
			var hit := {}
			var p: Vector2 = b.p
			for r in b.rocks:
				var c: Vector2 = r.p - p
				var along := clampf(c.dot(hd), 0.0, L)   # the projection: how far down the whisker
				var q := p + hd * along
				var nrm: Vector2 = q - r.p
				var nd := nrm.length()
				if nd > r.r + 9.0:
					continue                             # the whisker misses this rock
				if nd < 1.0:
					nrm = Vector2(-hd.y, hd.x)           # dead centre: any sideways will do
				else:
					nrm /= nd
				if hit.is_empty() or along < hit.along:
					hit = { "along": along, "q": q, "n": nrm }
			if not hit.is_empty():
				var urgency: float = 1.0 - hit.along / L # nearer crossing = harder shove
				des += (hit.n as Vector2) * D.speed * D.avoid * (0.3 + urgency)
			var s: Vector2 = des - vel                   # steering = desired − current
			var sl := s.length()
			if sl > D.force:
				s = s / sl * D.force
			vel += s * dt
			var s2 := vel.length()
			if s2 > D.speed * 1.4:
				vel *= D.speed * 1.4 / s2
			p += vel * dt
			for r in b.rocks:                            # never inside a rock, whatever happens
				var rv: Vector2 = p - r.p
				var rd := _or1(rv.length())
				if rd < r.r + 8.0:
					p = r.p + rv / rd * (r.r + 8.0)
			p = Vector2(clampf(p.x, 8.0, b.w - 8.0), clampf(p.y, 8.0, b.h - 8.0))
			b.p = p
			b.v = vel
			b.hd = hd
			b.L = L
			b.hit = hit
		"zones":
			var sense: float = b.w * D.sense
			var lose: float = b.w * D.lose
			b.hold -= dt
			if b.hold <= 0.0:                            # the player drifts on its own, on noise
				var a: float = Kit.noise(t * D.drift + 3.0) * PI * 1.5
				b.pp = Vector2(clampf(b.pp.x + cos(a) * 34.0 * dt, 12.0, b.w - 12.0),
					clampf(b.pp.y + sin(a) * 34.0 * dt, 12.0, b.h - 12.0))
			var d: float = (b.pp - b.p as Vector2).length()
			b.st += dt
			var posts: Array = b.posts
			if b.state == "patrol":
				if _zone_walk(b, posts[b.post], D.patrol, dt):
					b.post = 1 - b.post
				if d < sense:
					b.state = "alert"
					b.st = 0.0
			elif b.state == "alert":                     # stop, turn, and count to one
				var pp: Vector2 = b.pp
				var p: Vector2 = b.p
				b.h += wrapf(atan2(pp.y - p.y, pp.x - p.x) - b.h, -PI, PI) * minf(1.0, 6.0 * dt)
				if b.st > D.alert:
					b.state = "chase"
					b.st = 0.0
				elif d > sense * 1.3:
					b.state = "patrol"
					b.st = 0.0
			elif b.state == "chase":
				_zone_walk(b, b.pp, D.chase, dt)
				if d > lose:
					b.state = "return"
					b.st = 0.0
				if d < 14.0:                             # tagged: the player respawns far away
					b.caught += 1
					b.flash = 1.0
					b.state = "return"
					b.st = 0.0
					b.pp = Vector2(b.w * 0.85 if b.p.x < b.w / 2.0 else b.w * 0.15, randf_range(b.h * 0.15, b.h * 0.85))
					b.hold = 1.0
			else:                                        # return: home to the nearest post
				var ni: int = 0 if (posts[0] - b.p as Vector2).length() < (posts[1] - b.p as Vector2).length() else 1
				if _zone_walk(b, posts[ni], D.patrol, dt):
					b.state = "patrol"
					b.post = 1 - ni
					b.st = 0.0
				if d < sense:
					b.state = "alert"
					b.st = 0.0
			b.flash = maxf(0.0, b.flash - dt * 2.0)
		"ghost":
			b.hold -= dt
			b.glance -= dt
			if b.hold <= 0.0 and b.glance <= 0.0:
				b.glance = D.glance * randf_range(0.6, 1.4)
				b.aim = randf_range(-PI, PI)
			b.h += clampf(wrapf(b.aim - b.h, -PI, PI), -D.turn * dt, D.turn * dt)   # the gaze, turn-rate limited
			var half: float = D.cone * PI / 360.0
			b.half = half
			var to: Vector2 = b.g - b.c
			var d := _or1(to.length())
			var dotp: float = to.x / d * cos(b.h) + to.y / d * sin(b.h)   # ← the whole test
			var seen: bool = dotp > cos(half)
			b.dotp = dotp
			b.seen = seen
			if seen:                                     # frozen, mid-step
				b.gv = Vector2.ZERO
			else:                                        # Arrive at the mote
				var sp: float = D.speed * minf(1.0, d / 50.0)
				var s: Vector2 = -to / d * sp - b.gv
				var sl := s.length()
				if sl > 300.0:
					s = s / sl * 300.0
				b.gv += s * dt
				b.g += b.gv * dt
			if d < D.boo:
				b.scares += 1
				b.flash = 1.0
				_ghost_spawn(b)
			b.flash = maxf(0.0, b.flash - dt * 1.5)
		"tractorbeam":
			b.hold -= dt
			if b.hold <= 0.0:
				b.aim = PI / 2.0 + sin(t * D.sweep) * 0.9   # the idle sweep
			b.beam += wrapf(b.aim - b.beam, -PI, PI) * minf(1.0, 6.0 * dt)
			var beam: float = b.beam
			var half: float = D.half * PI / 180.0
			var R: float = b.h * D.reach
			var HOLD := 15.0
			var ax := Vector2(cos(beam), sin(beam))      # the axis, and its normal
			var nx := Vector2(-ax.y, ax.x)
			var s: Vector2 = b.s
			var k: float = exp(-D.damp * dt)             # framerate-proof drag
			for bit in b.bits:
				if bit.caught:                           # the spiral into the hold
					bit.a += 5.0 * dt
					bit.r = maxf(0.0, bit.r - 12.0 * dt)
					bit.p = s + Vector2(cos(bit.a), sin(bit.a)) * bit.r
					if bit.r <= 0.5:
						b.held += 1
						_beam_spawn(b, bit)
					continue
				var dv: Vector2 = bit.p - s
				var d := _or1(dv.length())
				var off: float = wrapf(atan2(dv.y, dv.x) - beam, -PI, PI)
				var inside: bool = absf(off) < half and d < R
				bit.inside = inside
				if inside:
					var F: float = D.pull * (1.0 - absf(off) / half) / (1.0 + d / (R * 0.5))   # ← the field's shape
					bit.v += -dv / d * F * dt
					var side := dv.dot(nx)               # signed distance off the axis
					bit.v += -nx * side * 2.5 * dt       # the funnel
					if d < HOLD:
						bit.caught = true
						bit.a = atan2(dv.y, dv.x)
						bit.r = d
				else:                                    # adrift: a breath of noise
					bit.v += Vector2(Kit.noise(t * 0.3 + bit.seed), Kit.noise(t * 0.3 + bit.seed + 40.0)) * 18.0 * dt
				bit.v *= k
				var sp: float = (bit.v as Vector2).length()
				if sp > 260.0:
					bit.v *= 260.0 / sp
				bit.p += bit.v * dt
				if bit.p.x < -6.0:
					bit.p.x = b.w + 6.0
				if bit.p.x > b.w + 6.0:
					bit.p.x = -6.0
				if bit.p.y < -6.0:
					bit.p.y = b.h + 6.0
				if bit.p.y > b.h + 6.0:
					bit.p.y = -6.0
		"firefly":
			b.clock += dt
			if b.clock > D.lit + D.dark:
				b.clock -= D.lit + D.dark
			var on: bool = b.clock < D.lit
			b.on = on
			var l: Vector2 = b.l
			for f in b.flies:
				var a: float = Kit.noise(t * D.wander + f.seed) * PI * 1.5   # a smooth, personal heading
				var des: Vector2 = Vector2(cos(a) * D.speed, sin(a) * D.speed * 0.6)
				if on:                                   # Arrive, with the wander kept as seasoning
					var to: Vector2 = Vector2(l.x, l.y - 14.0) - f.p
					var d := _or1(to.length())
					var sp: float = D.speed * 1.6 * minf(1.0, d / (b.w * D.slow))
					des = to / d * sp + des * 0.45
				f.v += (des - f.v) * minf(1.0, 2.5 * dt)
				f.p += f.v * dt
				if f.p.x < -8.0:
					f.p.x = b.w + 8.0
				if f.p.x > b.w + 8.0:
					f.p.x = -8.0
				if f.p.y < b.h * 0.06:
					f.p.y = b.h * 0.06
					f.v.y = absf(f.v.y)
				if f.p.y > b.gy - 6.0:
					f.p.y = b.gy - 6.0
					f.v.y = -absf(f.v.y)
		"butterfly":
			var f: Vector2 = b.flowers[b.idx]
			b.since += dt
			if b.linger > 0.0:                           # sitting: wings slowly fanning
				b.linger -= dt
				b.p = Vector2(f.x, f.y - 6.0)
				b.v = Vector2.ZERO
				if b.linger <= 0.0:
					b.idx = (b.idx + 1) % b.flowers.size()
					b.v.y = -b.h * D.kick
					b.since = 0.0
			else:
				b.flapT -= dt
				if b.flapT <= 0.0:
					b.flapT = D.flap * (1.0 + randf_range(-D.jitter, D.jitter))   # the jittered timer
					if b.p.y > f.y - 12.0:               # only flap when below the flower
						b.v.y = minf(b.v.y, 0.0) * 0.3 - b.h * D.kick * randf_range(0.8, 1.2)   # ← the IMPULSE
						b.since = 0.0
				b.v.y += b.h * D.gravity * dt            # gravity between flaps
				var dx: float = f.x - b.p.x
				var d := _or1(absf(dx))
				var sp: float = D.speed * minf(1.0, d / 50.0)   # Arrive, sideways only
				b.v.x += (dx / d * sp - b.v.x) * minf(1.0, 2.0 * dt)
				b.p += b.v * dt
				if b.p.y > b.gy - 8.0:
					b.p.y = b.gy - 8.0
					b.v.y = minf(b.v.y, 0.0)
				if b.p.y < b.h * 0.06:
					b.p.y = b.h * 0.06
					b.v.y = maxf(b.v.y, 0.0)
				b.p.x = clampf(b.p.x, 8.0, b.w - 8.0)
				if absf(b.p.x - f.x) < 8.0 and absf(b.p.y - f.y) < 14.0:
					b.linger = D.linger
		"zombies":
			var zs: Array = b.zs
			var m := Vector2.ZERO                        # the horde's centre, for the player's nerves
			for z in zs:
				m += z.p
			m /= zs.size()
			b.pa += randf_range(-1, 1) * 2.2 * sqrt(dt)  # the player: Wander's jitter...
			var des: Vector2 = Vector2(cos(b.pa), sin(b.pa)) * D.player
			var fdv: Vector2 = b.pp - m
			var fd := _or1(fdv.length())
			if fd < b.w * 0.45:                          # ...plus flee
				des += fdv / fd * D.player * 1.2
			des += (Vector2(b.w / 2.0, b.h / 2.0) - b.pp as Vector2) * 0.5   # and a leash to the middle
			b.pv += (des - b.pv) * minf(1.0, 3.0 * dt)
			var ps: float = (b.pv as Vector2).length()
			if ps > D.player * 1.6:
				b.pv *= D.player * 1.6 / ps
			var pp: Vector2 = b.pp + b.pv * dt
			pp = Vector2(clampf(pp.x, 10.0, b.w - 10.0), clampf(pp.y, 10.0, b.h - 10.0))
			b.pp = pp
			var bitten := false
			for i in zs.size():
				var z: Dictionary = zs[i]
				var zp: Vector2 = z.p
				var want: float = atan2(pp.y - zp.y, pp.x - zp.x) + Kit.noise(t * 0.6 + z.seed) * D.wobble   # aim, spoiled
				z.h += wrapf(want - z.h, -PI, PI) * minf(1.0, 3.0 * dt)
				var pulse: float = maxf(0.0, sin(t * TAU * D.lurch * z.rate + z.ph))
				var v: float = D.speed * (0.08 + 0.92 * pulse * pulse)   # ← the lurch
				var sep := Vector2.ZERO
				for j in zs.size():                      # separation, and only separation
					if j == i:
						continue
					var dv: Vector2 = zp - zs[j].p
					var d := dv.length()
					if d < D.sep and d > 0.01:
						sep += dv / d * (D.sep - d)
				zp += (Vector2(cos(z.h), sin(z.h)) * v + sep * 3.0) * dt
				zp = Vector2(clampf(zp.x, 6.0, b.w - 6.0), clampf(zp.y, 6.0, b.h - 6.0))
				z.p = zp
				if (pp - zp).length() < 11.0:
					bitten = true
			if bitten:                                   # respawn on the far side of the horde
				b.bites += 1
				b.flash = 1.0
				b.pp = Vector2(b.w * 0.88 if m.x < b.w / 2.0 else b.w * 0.12, randf_range(b.h * 0.15, b.h * 0.85))
				b.pv = Vector2.ZERO
			b.flash = maxf(0.0, b.flash - dt * 2.0)
		"volley":
			var g: float = b.h * D.gravity
			var reach: float = b.w * D.reach
			var pspeed: float = b.w * D.paddle
			var netH: float = b.h * D.net
			var PY: float = b.PY
			var pads: Array = b.pads
			if b.dead > 0.0:
				b.dead -= dt
				if b.dead <= 0.0:
					b.server = 1 - b.server
					b.bp = Vector2(pads[b.server].x, PY - 30.0)
					_volley_hit(b, b.bp.x, pads[b.server].side, g)
			else:
				var was_left: bool = b.bp.x < b.w / 2.0
				b.bv.y += g * dt
				var bs: float = (b.bv as Vector2).length()
				if bs > b.h * 4.0:
					b.bv *= b.h * 4.0 / bs
				b.bp += b.bv * dt
				if b.bp.x < 6.0:
					b.bp.x = 6.0
					b.bv.x = absf(b.bv.x) * 0.7
				if b.bp.x > b.w - 6.0:
					b.bp.x = b.w - 6.0
					b.bv.x = -absf(b.bv.x) * 0.7
				if was_left != (b.bp.x < b.w / 2.0) and b.bp.y > b.gy - netH:   # into the net
					b.bv.x = -b.bv.x * 0.5
					b.bp.x = b.w / 2.0 - 6.0 if was_left else b.w / 2.0 + 6.0
				for p in pads:                           # a paddle under it: the return
					if b.bv.y > 0.0 and b.bp.y >= PY - 6.0 and absf(b.bp.x - p.x) < reach + 5.0 and (b.bp.x - b.w / 2.0) * p.side > 0.0:
						b.bp.y = PY - 6.0
						_volley_hit(b, b.bp.x, p.side, g)
						b.rally += 1
				if b.bp.y > b.gy - 5.0:                  # a miss: the floor
					b.dead = 1.2
					b.rally = 0
			var lx: float = b.bp.x
			var tl := 0.0
			if b.dead <= 0.0:                            # the prediction, for both paddles
				var hh: float = maxf(0.0, PY - 6.0 - b.bp.y)
				var bvy: float = b.bv.y
				tl = (bvy + sqrt(bvy * bvy + 2.0 * g * hh)) / g   # ← the quadratic formula
				lx = b.bp.x + b.bv.x * tl
				if lx < 6.0:                             # folded at the walls
					lx = 12.0 - lx
				if lx > b.w - 6.0:
					lx = 2.0 * (b.w - 6.0) - lx
				lx = clampf(lx, 6.0, b.w - 6.0)
			b.lx = lx
			b.tl = tl
			for p in pads:                               # Arrive at the landing x, or drift home
				var mine: bool = b.dead <= 0.0 and (lx - b.w / 2.0) * p.side > 0.0
				var goal: float = lx if mine else b.w / 2.0 + p.side * b.w * 0.28
				var d: float = goal - p.x
				var sp: float = pspeed * minf(1.0, absf(d) / 30.0)
				p.vx += (signf(d) * sp - p.vx) * minf(1.0, 8.0 * dt)
				p.x += p.vx * dt
				p.x = clampf(p.x, reach + 4.0, b.w / 2.0 - reach - 4.0) if p.side < 0.0 else clampf(p.x, b.w / 2.0 + reach + 4.0, b.w - reach - 4.0)

# ---------------------------------------------------------------- draw

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	Kit.stage(n, b)
	var D: Dictionary = b.D
	var origin: Vector2 = (b.rect as Rect2).position
	match b.id:
		"arrive":
			Kit.ring(n, b.tgt, D.slow, Color(0.961, 0.757, 0.412, 0.25))
			Kit.dot(n, b.tgt, 4.0, Kit.TARGET)
			Kit.arrow(n, b.p, b.p + b.v * 0.35, Kit.GOOD)
			Kit.arrow(n, b.p, b.p + b.steer * 0.12, Kit.HOT)
			Kit.mote(n, b, b.p, (b.v as Vector2).angle())
			Kit.label(n, b, "desired speed = max · min(1, distance/%s)" % D.slow, Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"chase":
			if b.flash > 0.0:
				Kit.ring(n, b.smart.p, 18.0 + (1.0 - b.flash) * 30.0, Color(0.961, 0.757, 0.412, b.flash * 0.8), 2.0)
			Kit.ring(n, b.future, 6.0, Color(0.961, 0.757, 0.412, 0.5))   # the prediction, made visible
			n.draw_dashed_line(b.smart.p, b.future, Color(0.961, 0.757, 0.412, 0.3), 1.0, 7.0)
			Kit.mote(n, b, b.prey.p, (b.prey.v as Vector2).angle(), Kit.GOOD, 7.0)
			Kit.mote(n, b, b.smart.p, (b.smart.v as Vector2).angle(), Kit.MOVER, 8.0)
			Kit.mote(n, b, b.naive.p, (b.naive.v as Vector2).angle(), Color(0.91, 0.898, 0.957, 0.28), 8.0)
			Kit.label(n, b, "caught ×%d · blue predicts, ghost points" % b.caught, Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"wander":
			Kit.ring(n, b.guide, D.rim, Color(0.91, 0.898, 0.957, 0.2))
			n.draw_line(b.p, b.rim, Kit.DIM, 1.0)
			Kit.dot(n, b.rim, 3.5, Kit.TARGET)
			Kit.mote(n, b, b.p, (b.v as Vector2).angle())
			Kit.label(n, b, "steer at the rim dot; jitter only its angle", Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"zigzag":
			for i in b.pts.size() - 1:
				n.draw_line(b.pts[i], b.pts[i + 1], Color(0.788, 0.769, 0.894, 0.35), 1.5)
			for p in b.pts:
				Kit.ring(n, p, 4.0, Color(0.788, 0.769, 0.894, 0.5))
			var a: Vector2 = b.pts[b.seg]
			var c: Vector2 = b.pts[b.seg + 1]
			# forward legs run a→c; backward legs run c→a (e2 flips the same easing)
			var e := smoothstep(0.0, 1.0, b.k)
			var e2: float = e if b.dir > 0 else 1.0 - e
			var saw := a + (c - a) * e2
			var total := 0.0
			for i in b.pts.size() - 1:
				total += (b.pts[i] as Vector2).distance_to(b.pts[i + 1])
			total = _or1(total)
			var g: float = total * 2.0 - b.gd if b.gd > total else b.gd
			var gp: Vector2 = b.pts[0]
			for i in b.pts.size() - 1:
				var L := _or1((b.pts[i] as Vector2).distance_to(b.pts[i + 1]))
				if g <= L:
					gp = (b.pts[i] as Vector2) + ((b.pts[i + 1] as Vector2) - b.pts[i]) * g / L
					break
				g -= L
			Kit.dot(n, gp, 7.0, Color(0.91, 0.898, 0.957, 0.18))
			n.draw_set_transform(origin + saw, t * D.spin, Vector2.ONE)   # the saw: eased, pausing, mean
			n.draw_circle(Vector2.ZERO, 8.0, Kit.HOT)
			for i in 8:
				var an := i / 8.0 * TAU
				n.draw_line(Vector2(cos(an), sin(an)) * 8.0, Vector2(cos(an), sin(an)) * 12.0, Kit.HOT, 2.0)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.label(n, b, "%d/%d waypoints · eased saw vs constant ghost" % [b.pts.size(), int(D.maxPts)], Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"flee":
			var hc := Vector2(b.w * 0.8, b.h * 0.72)     # the burrow
			var hr: float = b.h * D.burrow
			var fear: float = b.w * D.fear
			var prey: Dictionary = b.prey
			var hunt: Dictionary = b.hunt
			_dashed_ring(n, hc, hr, Color(0.788, 0.769, 0.894, 0.45), 1.5, 4.0, 4.0)
			Kit.label(n, b, "burrow", Vector2(hc.x, hc.y + hr + 12.0), Kit.DIM, true)
			Kit.ring(n, prey.p, fear, Color(0.608, 0.886, 0.541, 0.12) if b.mode == "graze" else Color(0.608, 0.886, 0.541, 0.3))
			if b.mode == "evade":                        # the point it runs FROM, made visible
				Kit.ring(n, b.fut, 5.0, Color(0.961, 0.541, 0.541, 0.6))
				Kit.arrow(n, prey.p, prey.p + b.des * 0.25, Kit.GOOD)
			if b.flash > 0.0:
				Kit.ring(n, hunt.p, 14.0 + (1.0 - b.flash) * 26.0, Color(0.961, 0.541, 0.541, b.flash * 0.8), 2.0)
			Kit.label(n, b, b.mode, Vector2(prey.p.x, prey.p.y - 14.0), Color(0.608, 0.886, 0.541, 0.8), true)
			Kit.mote(n, b, prey.p, (prey.v as Vector2).angle(), Kit.GOOD, 7.0)
			Kit.mote(n, b, hunt.p, (hunt.v as Vector2).angle())
			Kit.label(n, b, "flee = −seek · evade = −pursue · caught ×%d" % b.caught, Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"obstacle":
			var p: Vector2 = b.p
			var hd: Vector2 = b.hd
			var L: float = b.L
			var hit: Dictionary = b.hit
			for r in b.rocks:
				Kit.dot(n, r.p, r.r, Color(0.788, 0.769, 0.894, 0.12))
				Kit.ring(n, r.p, r.r, Color(0.788, 0.769, 0.894, 0.5))
			Kit.line(n, p, p + hd * L, Kit.HOT if not hit.is_empty() else Kit.DIM, 1.5 if not hit.is_empty() else 1.0)   # the whisker
			if not hit.is_empty():
				Kit.dot(n, hit.q, 3.0, Kit.HOT)
				Kit.arrow(n, hit.q, hit.q + hit.n * 22.0, Kit.HOT)
			Kit.ring(n, b.goal, 7.0, Kit.TARGET, 1.5)
			Kit.dot(n, b.goal, 2.5, Kit.TARGET)
			Kit.mote(n, b, p, (b.v as Vector2).angle())
			Kit.label(n, b, "q = p + h·clamp((c−p)·h, 0, L); hit if |q−c|<r", Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"zones":
			var sense: float = b.w * D.sense
			var lose: float = b.w * D.lose
			var posts: Array = b.posts
			var p: Vector2 = b.p
			var pp: Vector2 = b.pp
			var state: String = b.state
			n.draw_dashed_line(posts[0], posts[1], Color(0.788, 0.769, 0.894, 0.3), 1.0, 8.0)
			for q in posts:
				Kit.ring(n, q, 4.0, Color(0.788, 0.769, 0.894, 0.5))
			Kit.ring(n, p, sense, Color(0.961, 0.757, 0.412, 0.3) if state == "patrol" else Color(0.961, 0.757, 0.412, 0.15))
			Kit.ring(n, p, lose, Color(0.961, 0.541, 0.541, 0.35) if state == "chase" else Color(0.961, 0.541, 0.541, 0.1))
			if b.flash > 0.0:
				Kit.ring(n, p, 14.0 + (1.0 - b.flash) * 26.0, Color(0.961, 0.541, 0.541, b.flash * 0.8), 2.0)
			Kit.ring(n, pp, 8.0, Color(0.961, 0.757, 0.412, 0.5))
			Kit.dot(n, pp, 4.0, Kit.TARGET)
			Kit.mote(n, b, p, b.h)
			var col: Color = Kit.HOT if state == "chase" else (Kit.TARGET if state == "alert" else (Kit.GOOD if state == "patrol" else Kit.BONE))
			Kit.label(n, b, state, Vector2(p.x, p.y - 15.0), col, true)
			if state == "alert":                         # the "!" — bold 16px, bobbing
				var f := ThemeDB.fallback_font
				var bw: float = f.get_string_size("!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
				n.draw_string(f, Vector2(p.x - bw / 2.0, p.y - 24.0 - sin(b.st * 12.0) * 2.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Kit.HOT)
			Kit.label(n, b, "sense %d px · lose %d px · tagged ×%d" % [roundi(sense), roundi(lose), b.caught], Vector2(b.w / 2.0, 14.0), LBL, true)
			Kit.label(n, b, "patrol → alert → chase → return, by radius", Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"ghost":
			var c: Vector2 = b.c
			var g: Vector2 = b.g
			var h: float = b.h
			var half: float = b.half
			var seen: bool = b.seen
			var R: float = maxf(b.w, b.h)                # the cone, painted
			var fan := PackedVector2Array([c])
			for i in 25:
				var an: float = h - half + (h + half - (h - half)) * i / 24.0
				fan.append(c + Vector2(cos(an), sin(an)) * R)
			n.draw_colored_polygon(fan, Color(0.91, 0.898, 0.957, 0.06))
			Kit.line(n, c, c + Vector2(cos(h - half), sin(h - half)) * R, Kit.DIM)
			Kit.line(n, c, c + Vector2(cos(h + half), sin(h + half)) * R, Kit.DIM)
			if b.flash > 0.0:
				Kit.ring(n, c, 12.0 + (1.0 - b.flash) * 40.0, Color(0.788, 0.627, 0.961, b.flash * 0.7), 2.0)
			var bob: float = 0.0 if seen else sin(t * 5.0) * 2.0   # it drifts when it moves, hangs when it's caught
			var gc: Color = Color(0.788, 0.627, 0.961, 0.45) if seen else Kit.MAGIC
			Kit.dot(n, Vector2(g.x, g.y + bob), 8.0, gc)
			Kit.rect(n, Rect2(g.x - 8.0, g.y + bob, 16.0, 7.0), gc)
			for i in 3:
				Kit.dot(n, Vector2(g.x - 5.3 + i * 5.3, g.y + bob + 7.0), 2.7, gc)
			Kit.dot(n, Vector2(g.x - 3.0, g.y + bob - 2.0), 1.6, Color("131020"))   # two hollow eyes
			Kit.dot(n, Vector2(g.x + 3.0, g.y + bob - 2.0), 1.6, Color("131020"))
			if seen:
				Kit.ring(n, g, 13.0, Color(0.788, 0.627, 0.961, 0.5))
			Kit.label(n, b, "dot = %.2f" % b.dotp, Vector2(g.x, g.y - 16.0), Color(0.788, 0.627, 0.961, 0.8), true)
			Kit.mote(n, b, c, h)
			Kit.label(n, b, "scares ×%d" % b.scares, Vector2(b.w / 2.0, 14.0), LBL, true)
			Kit.label(n, b, "seen if gaze · dir > cos(%s°) → freeze" % (D.cone / 2.0), Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"tractorbeam":
			var s: Vector2 = b.s
			var beam: float = b.beam
			var half: float = D.half * PI / 180.0
			var R: float = b.h * D.reach
			var HOLD := 15.0
			var ax := Vector2(cos(beam), sin(beam))
			var lo := s + Vector2(cos(beam - half), sin(beam - half)) * R
			var hi := s + Vector2(cos(beam + half), sin(beam + half)) * R
			Kit.poly(n, [s, lo, hi], Color(0.961, 0.757, 0.412, 0.08))
			Kit.line(n, s, lo, Color(0.961, 0.757, 0.412, 0.35))
			Kit.line(n, s, hi, Color(0.961, 0.757, 0.412, 0.35))
			n.draw_dashed_line(s, s + ax * R, Color(0.961, 0.757, 0.412, 0.3), 1.0, 8.0)
			for bit in b.bits:
				if bit.caught:
					Kit.dot(n, bit.p, 2.4, Kit.MAGIC)
				else:
					Kit.dot(n, bit.p, 2.2, Color(0.961, 0.757, 0.412, 0.9) if bit.inside else Kit.BONE)
			Kit.ring(n, s, HOLD, Color(0.961, 0.757, 0.412, 0.6))
			Kit.mote(n, b, s, beam, Kit.MOVER, 9.0)
			Kit.label(n, b, "F = pull·(1−|off|/half)÷(1+d/R) · held ×%d" % b.held, Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"firefly":
			Kit.ground(n, b)
			var l: Vector2 = b.l
			var on: bool = b.on
			Kit.line(n, Vector2(l.x, b.gy), Vector2(l.x, l.y + 8.0), Kit.BONE, 1.5)   # the lamp post
			Kit.rect(n, Rect2(l.x - 5.0, l.y - 8.0, 10.0, 15.0), Kit.TARGET if on else Color(0.961, 0.757, 0.412, 0.3))
			if on:
				Kit.ring(n, l, 14.0 + sin(t * 3.0) * 2.0, Color(0.961, 0.757, 0.412, 0.35))
				Kit.ring(n, l, 24.0 + sin(t * 3.0 + 1.0) * 3.0, Color(0.961, 0.757, 0.412, 0.15))
				_dashed_ring(n, Vector2(l.x, l.y - 14.0), b.w * D.slow, Color(0.961, 0.757, 0.412, 0.18), 1.0, 3.0, 6.0)
			for f in b.flies:
				var g: float = maxf(0.0, sin(t * TAU * D.blink + f.ph))   # the glow, on its own phase
				g = g * g                                # squared: short bright, long dim
				Kit.dot(n, f.p, 1.6 + g * 1.6, Color(0.608, 0.886, 0.541, 0.25 + g * 0.7))
				if g > 0.3:
					Kit.ring(n, f.p, 4.0 + g * 3.0, Color(0.608, 0.886, 0.541, g * 0.25))
			Kit.label(n, b, "lit — Arrive" if on else "dark — wander", Vector2(l.x, l.y - 22.0), Color(0.961, 0.757, 0.412, 0.7), true)
			Kit.label(n, b, "h = noise(t·r + i)·π · glow = sin(t·b + φᵢ)²", Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"butterfly":
			Kit.ground(n, b)
			var flowers: Array = b.flowers
			for i in flowers.size():
				var q: Vector2 = flowers[i]
				Kit.line(n, Vector2(q.x, b.gy), Vector2(q.x, q.y + 4.0), Color(0.608, 0.886, 0.541, 0.5), 1.5)
				Kit.ring(n, q, 5.0, Kit.TARGET, 1.5)
				Kit.dot(n, q, 2.5, Kit.TARGET)
				if i == b.idx:
					Kit.ring(n, q, 10.0, Color(0.961, 0.757, 0.412, 0.35))
			var p: Vector2 = b.p
			var since: float = b.since
			var s: float                                 # wing spread: a quick sweep after each kick
			if b.linger > 0.0:
				s = 0.55 + 0.45 * sin(t * 3.0)
			else:
				s = 0.25 + 0.75 * absf(cos(since / 0.22 * PI)) if since < 0.22 else 1.0
			var wc := Color(0.541, 0.851, 0.961, 0.7)
			Kit.poly(n, [p, Vector2(p.x - 10.0 * s, p.y - 8.0), Vector2(p.x - 13.0 * s, p.y - 1.0), Vector2(p.x - 8.0 * s, p.y + 6.0)], wc)
			Kit.poly(n, [p, Vector2(p.x + 10.0 * s, p.y - 8.0), Vector2(p.x + 13.0 * s, p.y - 1.0), Vector2(p.x + 8.0 * s, p.y + 6.0)], wc)
			Kit.dot(n, p, 3.0, Kit.MOVER)
			Kit.label(n, b, "vy = −kick on a jittered timer · g between", Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"zombies":
			for z in b.zs:
				Kit.mote(n, b, z.p, z.h, Kit.MAGIC, 6.0)
			var pp: Vector2 = b.pp
			if b.flash > 0.0:
				Kit.ring(n, pp, 12.0 + (1.0 - b.flash) * 24.0, Color(0.961, 0.541, 0.541, b.flash * 0.8), 2.0)
			Kit.mote(n, b, pp, (b.pv as Vector2).angle())
			Kit.label(n, b, "bites ×%d" % b.bites, Vector2(b.w / 2.0, 14.0), LBL, true)
			Kit.label(n, b, "v = max·sin²(t·f + φᵢ) · heading = aim + noise", Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"volley":
			Kit.ground(n, b)
			var g: float = b.h * D.gravity
			var reach: float = b.w * D.reach
			var netH: float = b.h * D.net
			var PY: float = b.PY
			var bp: Vector2 = b.bp
			var bv: Vector2 = b.bv
			if b.dead <= 0.0:                            # the prediction, for both paddles
				var tl: float = b.tl
				var fc := Color(0.961, 0.757, 0.412, 0.3)
				for i in range(1, 17):                   # the flight, dotted
					var k: float = tl * i / 16.0
					var fx: float = bp.x + bv.x * k
					if fx < 6.0:
						fx = 12.0 - fx
					if fx > b.w - 6.0:
						fx = 2.0 * (b.w - 6.0) - fx
					Kit.rect(n, Rect2(fx - 1.0, bp.y + bv.y * k + 0.5 * g * k * k - 1.0, 2.0, 2.0), fc)
				Kit.ring(n, Vector2(b.lx, PY), 6.0, Color(0.961, 0.757, 0.412, 0.6), 1.5)
			for p in b.pads:
				Kit.rect(n, Rect2(p.x - reach, PY, reach * 2.0, 5.0), p.c)
			Kit.line(n, Vector2(b.w / 2.0, b.gy), Vector2(b.w / 2.0, b.gy - netH), Kit.BONE, 2.0)   # the net
			Kit.rect(n, Rect2(b.w / 2.0 - 4.0, b.gy - netH - 2.0, 8.0, 3.0), Kit.BONE)
			Kit.dot(n, bp, 5.0, Kit.TARGET)
			Kit.label(n, b, "rally %d" % b.rally, Vector2(b.w / 2.0, 14.0), LBL, true)
			Kit.label(n, b, "t = (v + √(v² + 2gh)) ÷ g → lands at x + vx·t", Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
