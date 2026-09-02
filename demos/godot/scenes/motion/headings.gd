extends RefCounted

const Kit := preload("res://scenes/motion/kit.gd")
## HEADINGS & VEHICLES — twelve movement styles, ported from the web lexicon
## (docs/locomotion.js). A body that remembers an ANGLE. Position says where
## a thing is; a heading says which way it points — and a vehicle may only
## move the way it points, so every change of mind costs a turn, and the
## time a turn takes is what a reader feels as weight. Turn-rate limits,
## look-at smoothing, thrust along the nose, wheels that roll instead of
## slide, a tilt that leans into every acceleration: everything here steers.

const TITLE := "Headings & vehicles"
const BLURB := "a body that remembers an angle — turn limits, look-at, thrust along the nose, wheels, tilt: everything here steers"
const DEFS := [
	{ "id": "yaw", "letter": "Y", "name": "Yaw",
		"hint": "a heading with a turn-rate limit — press to plant the flag",
		"dials": { "speed": 84.0, "turn": 2.0,                       # px/s, and radians of turning per second
			"trail": 70, "retarget": 7.0,                             # history dots kept; seconds before a fresh flag
			"label": "turn radius = speed ÷ turn rate ≈ " },
		"rhyme": { "name": "Yawl", "hint": "the same rule with the turn rate at 0.8 rad/s — a sailing boat that needs the whole pond to come about",
			"dials": { "speed": 70.0, "turn": 0.8, "retarget": 9.0 } } },
	{ "id": "lookat", "letter": "L", "name": "Lookat",
		"hint": "a turret tracks a moving target the short way round, smoothed, inside a cone — press to move the target",
		"dials": { "cone": 60.0,                                     # the cone's half-angle, in degrees, either side of the mount
			"rate": 6.0,                                              # smoothing rate: bigger = snappier, smaller = lazier
			"barrel": 0.2,                                            # barrel length as a fraction of H
			"hold": 4.0,                                              # seconds your target stays where you put it
			"label": "θ += wrap(want − θ) · (1 − e^(−rate·dt))" },
		"rhyme": { "name": "Lighthouse", "hint": "a wide cone and a smoothing rate of 1 — a heavy lamp that sweeps after its target and arrives late",
			"dials": { "cone": 150.0, "rate": 1.0, "barrel": 0.3 } } },
	{ "id": "upright", "letter": "U", "name": "Upright",
		"hint": "self-righting: a spring-damper on an angle, plus a boat doing the same on a wave — press to tip them",
		"dials": { "k": 40.0, "c": 6.0,                              # angular stiffness (wants to be up) and damping (hates swinging)
			"kick": 4.5,                                              # radians per second a press adds
			"waveAmp": 0.05, "waveSpeed": 2.2,                        # the boat's sea: height as a fraction of H, and its speed
			"autoKick": 3.5,                                          # seconds between the shoves it gives itself
			"label": "α = −k·θ − c·ω   (a spring on an angle)" },
		"rhyme": { "name": "Unicycle", "hint": "a third of the stiffness and a quarter of the damping — a wobbly balancer that rings for seconds after each shove",
			"dials": { "k": 12.0, "c": 1.5, "kick": 3.0 } } },
	{ "id": "vehicle", "letter": "V", "name": "Vehicle",
		"hint": "the bicycle model: heading turns at v/L · tan(steer) — a wheelbase, not a turn limit — press to set the goal",
		"dials": { "speed": 90.0, "wheelbase": 0.11,                 # px/s; L, the axle-to-axle distance, as a fraction of W
			"lock": 35.0, "steerRate": 5.0,                           # full steering lock in degrees; how fast the wheel turns (1/s)
			"trail": 80,
			"label": "heading += v ÷ L · tan(steer) · dt" },
		"rhyme": { "name": "Van", "hint": "twice the wheelbase and half the steering lock — a long van whose turning circle is most of the card",
			"dials": { "wheelbase": 0.2, "lock": 18.0, "speed": 70.0 } } },
	{ "id": "motor", "letter": "M", "name": "Motor",
		"hint": "rolling without slipping: ω = v ÷ r, so the big wheel turns half as fast — press to set the speed (x → speed)",
		"dials": { "radius": 0.09,                                   # the small wheel as a fraction of H; the big one is 2×
			"accel": 110.0, "maxSpeed": 150.0,                        # throttle/brake in px/s²; flat out in px/s
			"spokes": 4,
			"hold": 5.0,                                              # seconds your speed setting lasts
			"label": "ω = v ÷ r   (the spokes can't lie)" },
		"rhyme": { "name": "Moped", "hint": "half-size wheels and a frantic throttle — the spokes spin twice as fast for the same speed",
			"dials": { "radius": 0.05, "accel": 320.0, "maxSpeed": 210.0 } } },
	{ "id": "asteroids", "letter": "A", "name": "Asteroids",
		"hint": "thrust along the nose, inertia keeps it: the autopilot turns, burns, flips to brake — press to set the target",
		"dials": { "thrust": 240.0, "turn": 4.0,                     # px/s² along the nose; rad/s of rotation
			"maxSpeed": 170.0, "arrive": 1.6,                         # the speed cap; how eagerly the pilot wants to be there
			"aim": 0.5,                                               # radians of misalignment it will still burn through
			"label": "v += (cos h, sin h) · thrust · dt" },
		"rhyme": { "name": "Anvil", "hint": "a third of the thrust and a slow turn — a heavy hauler that overshoots and comes back the long way",
			"dials": { "thrust": 80.0, "turn": 1.6, "maxSpeed": 120.0 } } },
	{ "id": "drone", "letter": "D", "name": "Drone",
		"hint": "critical springs hold x and height; the body tilts into its acceleration, aₓ ÷ g — press to set the hover point",
		"dials": { "omega": 3.5,                                     # spring frequency in rad/s, with ζ = 1 (no overshoot)
			"g": 2.4,                                                 # gravity as a fraction of H per s² — it sets the tilt scale
			"tiltMax": 0.6,                                           # radians the body may lean
			"arm": 0.07,                                              # half the rotor span, as a fraction of W
			"wander": 4.0,                                            # seconds between hover points
			"label": "a = ω²(target − p) − 2ω·v   tilt = aₓ ÷ g" },
		"rhyme": { "name": "Dragonfly", "hint": "the spring at ω = 9 and a steeper lean allowed — a twitchy darter that snaps to every point and banks hard",
			"dials": { "omega": 9.0, "tiltMax": 1.0, "wander": 2.0 } } },
	{ "id": "tank", "letter": "T", "name": "Tank",
		"hint": "differential drive: two track speeds make v and ω; the turret aims at your last click — press to set a destination",
		"dials": { "track": 70.0, "width": 0.13,                     # max track speed in px/s; track separation as a fraction of H
			"turnGain": 3.0, "turretRate": 4.0,                       # how hard heading error becomes spin; Lookat's smoothing rate
			"arrive": 0.05,                                           # fraction of W inside which it stops
			"label": "v = (vL + vR) ÷ 2   ω = (vR − vL) ÷ width" },
		"rhyme": { "name": "Tortoise", "hint": "under half the track speed on a wider hull — the same two numbers buy far less spin: a slow, deliberate lumber",
			"dials": { "track": 32.0, "width": 0.2, "turretRate": 1.5 } } },
	{ "id": "homing", "letter": "H", "name": "Homing",
		"hint": "Yaw's turn limit + Chase's prediction, a proximity fuse and a lifetime — press to fire a salvo from your click",
		"dials": { "speed": 150.0, "turn": 3.2,                      # px/s and rad/s — Yaw's two numbers, per missile
			"fuse": 14.0, "life": 5.0,                                # detonate within this many px; seconds before it fizzles
			"salvo": 5, "lead": 0.9,                                  # missiles per press; how much of the prediction to trust
			"label": "aim at prey + v·(d ÷ speed)·lead   fuse r" },
		"rhyme": { "name": "Hornets", "hint": "slower, but turning nearly three times as hard, in salvos of eight — a swarm that never gets out-turned",
			"dials": { "speed": 110.0, "turn": 9.0, "salvo": 8 } } },
	{ "id": "rocket", "letter": "R", "name": "Rocket",
		"hint": "thrust vs gravity on a shrinking mass, a slow gravity turn, a booster that falls away — press to launch again",
		"dials": { "thrust": 1.2,                                    # thrust ÷ weight at lift-off (1 = it just hovers)
			"burn": 3.0, "burn2": 2.6,                                # seconds each stage burns
			"pitchRate": 14.0, "pitchMax": 85.0,                      # the gravity turn: degrees per second, and its limit
			"g": 0.18,                                                # gravity as a fraction of H per s²
			"label": "a = F ÷ m − g   m shrinks as fuel burns" },
		"rhyme": { "name": "Rustbucket", "hint": "barely more thrust than weight and a lazy pitch-over — it hangs above the pad, creeps up, and drifts off with nothing to spare",
			"dials": { "thrust": 1.06, "pitchRate": 9.0, "burn": 3.6 } } },
	{ "id": "xhair", "letter": "X", "name": "Xhair", "drag": true,
		"hint": "aim assist: the crosshair slows inside a target's ring and is pulled to its centre — drag to move the crosshair",
		"dials": { "assist": 0.17,                                   # the assist ring's radius, as a fraction of H
			"friction": 0.35,                                         # inside the ring the crosshair keeps this much of its speed
			"pull": 140.0,                                            # px/s of magnetism at its strongest (half-way in)
			"follow": 12.0,                                           # how fast the crosshair chases the pointer (per second)
			"label": "inside r:  v × friction  +  pull → centre" },
		"rhyme": { "name": "Xlock", "hint": "a bigger ring, a stickier friction and twice the pull — console-grade lock-on that all but aims for you",
			"dials": { "assist": 0.28, "friction": 0.12, "pull": 300.0 } } },
	{ "id": "leaf", "letter": "L", "name": "Leaf",
		"hint": "a leaf slides along its tilt: gravity along the face, drag across it, a sine rocks the tilt — press to drop one",
		"dials": { "g": 1.4,                                         # gravity as a fraction of H per s²
			"dragAcross": 9.0, "dragAlong": 0.9,                      # air resistance across the face (big) and along it (small)
			"rock": 1.6, "amp": 0.9,                                  # the rocking sine: rad/s and radians
			"pitch": 0.012,                                           # how much airspeed along the face tips the leaf back
			"count": 6,
			"label": "along the face: g·sin θ  ·  across it: drag" },
		"rhyme": { "name": "Lace", "hint": "more than twice the air resistance and a quick, small rock — a scrap of lace that shivers down instead of swooping",
			"dials": { "dragAcross": 22.0, "rock": 3.2, "amp": 0.5 } } },
]

const LBL := Color(0.91, 0.898, 0.957, 0.55)   ## the web label()'s default ink
const MOUNT := -TAU / 4.0                      ## Lookat's turret is mounted facing straight up
const KX := 0.05                               ## Upright's wave: its spatial frequency
const PLAN := [1.0, 0.35, 0.0, -0.5]           ## Motor's auto schedule, as fractions of maxSpeed


static func init(b: Dictionary) -> void:
	match b.id:
		"yaw":
			# the mote can't teleport its direction: it stores a HEADING angle and may
			# only turn so many radians per second. atan2 (inverse trig) names the
			# angle to the flag; wrapAngle picks the short way round; the clamp is
			# the personality. the faint circles are its turning radius — aim inside
			# one and it must loop all the way around. cars, missiles, geese: this.
			b.p = Vector2(b.w * 0.3, b.h * 0.6)
			b.hd = 0.0
			b.timer = 0.0
			b.tgt = Vector2(b.w * 0.7, b.h * 0.4)
			b.trail = []
		"lookat":
			# LOOK-AT is atan2 plus manners. the raw angle to a target can jump — it
			# flips from +179° to −179° as the target crosses behind — so wrapAngle
			# folds the gap into −π..π and the turret takes the SHORT ARC, closing a
			# framerate-proof fraction of it each frame (a lerp on an angle: the
			# thing engines call lerp_angle). the CONE is a clamp on the angle
			# relative to the mount: eyes, heads and turrets all have one, and past
			# its edge the turret can only wait at the rim.
			b.ang = MOUNT
			b.tgt = Vector2(b.w * 0.7, b.h * 0.3)
			b.hold = 0.0
			b.off = 0.0
		"upright":
			# an ANGULAR spring-damper: Damp's equation with the angle θ in place of
			# a position and ω (angular velocity) in place of speed — α = −k·θ − c·ω,
			# integrated twice a frame like Pendulum. the capsule's "up" is fixed;
			# the boat's "up" is the wave's NORMAL, which never stops moving, so it
			# never quite settles — that lag is why boats rock. wobble toys, ships,
			# self-balancing robots, a knocked-down enemy getting up: this.
			b.cap = { "th": 0.35, "om": 0.0 }
			b.boat = { "th": 0.0, "om": 0.0 }
			b.timer = 0.0
			b.side = 1.0
		"vehicle":
			# Yaw turned by decree; a car turns because its front wheels point
			# somewhere its body doesn't. the BICYCLE MODEL collapses four wheels to
			# two: the rear axle drives straight ahead, the front axle is turned by
			# the STEER angle, and geometry says the heading changes at v/L·tan(steer)
			# — L being the WHEELBASE. a long L or a small steering lock means a big
			# turning circle (R = L ÷ tan(steer)); and stopped dead, it cannot turn
			# at all — the difference between a car and Yaw's goose.
			b.p = Vector2(b.w * 0.3, b.h * 0.6)
			b.hd = 0.0
			b.steer = 0.0
			b.timer = 0.0
			b.tgt = Vector2(b.w * 0.7, b.h * 0.4)
			b.trail = []
		"motor":
			# ROLLING WITHOUT SLIPPING: the wheel's rim moves at the ground's speed,
			# so one rotation carries it exactly one circumference — which pins the
			# spin rate to ω = v ÷ r. it is the whole reason wheels, gears and
			# rolling balls look wrong when their spin is faked: a wheel twice as
			# wide MUST turn half as fast. the red dot is the contact point — for an
			# instant it isn't moving at all. speed changes by move_toward (Lerp).
			var ms: float = b.D.maxSpeed
			b.x = b.w * 0.3
			b.v = 0.0
			b.target = ms * 0.6
			b.spinS = 0.0
			b.spinB = 0.0
			b.timer = 0.0
			b.hold = 0.0
			b.sched = 0
		"asteroids":
			# the 1979 control scheme: rotate is free, THRUST only pushes along the
			# nose, and nothing ever slows you down but more thrust the other way.
			# the autopilot's whole brain is one subtraction — desired velocity
			# (toward the target, Arrive-style) minus current velocity — it turns
			# to face that ERROR and burns when it's roughly aligned; as it closes
			# in the error points backward, so it flips and brakes. Yaw's turn limit,
			# Inertia's memory, and the screen wraps like the arcade cabinet did.
			b.p = Vector2(b.w * 0.3, b.h * 0.5)
			b.hd = 0.0
			b.v = Vector2.ZERO
			b.timer = 0.0
			b.tgt = Vector2(b.w * 0.72, b.h * 0.35)
			b.burning = false
			b.trail = []
			b.dv = Vector2.ZERO
			b.err = Vector2.ZERO
		"drone":
			# a quadcopter can only push along its own "up", so to go sideways it
			# must LEAN: the tilt that makes horizontal acceleration aₓ while still
			# holding its weight is tan(tilt) = aₓ / g — for small leans just aₓ/g.
			# here the position is held by Damp's spring at ζ = 1 (CRITICALLY
			# DAMPED, the fastest arrival with no overshoot), and the tilt is READ
			# OFF the acceleration that spring asks for — presentation derived from
			# physics, never animated. the rotor on the high side spins harder.
			b.p = Vector2(b.w * 0.3, b.h * 0.5)
			b.v = Vector2.ZERO
			b.tgt = Vector2(b.w * 0.7, b.h * 0.4)
			b.spinL = 0.0
			b.spinR = 0.0
			b.timer = 0.0
			b.hold = 0.0
			b.tilt = 0.0
			b.acc = Vector2.ZERO
		"tank":
			# DIFFERENTIAL DRIVE has no steering wheel: two tracks, two speeds, and
			# the body's motion falls out of their difference — forward speed is
			# their average, spin rate is their difference over the width. equal
			# tracks go straight, opposite tracks PIVOT on the spot (a thing Vehicle
			# can never do). the driver only ever decides vL and vR; the turret is a
			# separate heading on top, tracking its own target with Lookat's short
			# arc — one body, two angles, which is what makes a tank feel like one.
			b.p = Vector2(b.w * 0.3, b.h * 0.55)
			b.hd = 0.0
			b.vL = 0.0
			b.vR = 0.0
			b.distL = 0.0
			b.distR = 0.0
			b.tgt = Vector2(b.w * 0.7, b.h * 0.4)
			b.aim = Vector2(b.w * 0.5, b.h * 0.15)
			b.tur = 0.0
			b.rest = 0.0
		"homing":
			# a homing missile is Yaw with a brain from Chase: a heading that can
			# only turn so fast, aimed not at the prey but at where the prey will be
			# (position + velocity × the time to get there). two more numbers make
			# it a game thing: a PROXIMITY FUSE (close enough counts — nobody hits a
			# moving dot exactly) and a LIFETIME, so a missile that gets out-turned
			# fizzles instead of circling for ever. the fan at launch is why salvos
			# look like salvos: the same target, different starting headings.
			b.prey = { "p": Vector2(b.w * 0.6, b.h * 0.4), "v": Vector2(60.0, 0.0), "wa": 0.0 }
			b.missiles = []
			b.smoke = []
			b.bursts = []
			b.hits = 0
			b.quiet = 0.0
			b.puff = 0.0
			b.pred = Vector2.ZERO
			b.pred_on = false
		"rocket":
			# Jump's parabola, but the launch speed is EARNED frame by frame: the
			# engine pushes with a fixed force F on a mass m that shrinks as fuel
			# burns, so a = F/m − g climbs while the tank drains (Newton's second law
			# with a leaky m). the GRAVITY TURN is a heading that pitches over
			# slowly so gravity itself bends the path sideways; STAGING drops the
			# empty booster — which keeps the rocket's velocity and then falls on
			# its own parabola, tumbling. in coast the nose follows the velocity.
			b.boo = { "on": false, "p": Vector2.ZERO, "v": Vector2.ZERO, "a": 0.0, "spin": 0.0 }
			b.puff = 0.0
			b.aRead = 0.0
			b.F = 0.0
			_rocket_reset(b)
		"xhair":
			# AIM ASSIST is two small lies the hand never notices. FRICTION: while
			# the crosshair is inside a target's ring, its speed toward the pointer
			# is scaled down, so it "sticks" as it crosses. MAGNETISM: a gentle pull
			# toward the nearest centre — Magnet's field, but shaped as a hump that
			# is zero at the centre and at the rim, so it helps without snapping
			# (Arrive's idea: brake before you get there). the pointer is honest;
			# the crosshair is the one that cheats, and the gap between them is the
			# assist made visible.
			b.ptr = Vector2(b.w * 0.5, b.h * 0.5)
			b.c = b.ptr
			b.idle = 9.0
			b.targets = []
			for i in 3:
				b.targets.append({ "p": Vector2(b.w * (0.2 + i * 0.3), b.h * (0.3 + i * 0.18)),
					"vx": (-1.0 if i % 2 == 1 else 1.0) * (22.0 + i * 9.0), "vy": 0.0, "ph": i * 2.1 })
			b.near = -1
			b.nd = 0.0
			b.inside = false
		"leaf":
			# a leaf falls the way it does because air resists it very unequally:
			# hugely ACROSS its face, hardly at all ALONG it. so its velocity is split
			# into those two directions every frame, each damped by its own drag,
			# and gravity's pull along the tilted face makes the leaf SLIDE sideways.
			# the tilt itself is Pendulum's rock — a slow sine — plus a push-back
			# from the airspeed, so a fast slide levels the leaf and flips it the
			# other way: the flutter is that feedback loop, and nothing is scripted.
			var count: int = b.D.count
			b.leaves = []
			b.next = 0
			for _i in count:
				var l := {}
				_leaf_spawn(l, Vector2(randf_range(b.w * 0.1, b.w * 0.9), randf_range(-b.h * 0.1, b.gy - b.h * 0.2)))
				b.leaves.append(l)


static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"yaw":
			b.tgt = pos
			b.timer = -6.0
		"lookat":
			b.tgt = pos
			b.hold = b.D.hold
		"upright":                                       # a shove: each body falls AWAY from the click
			var kick: float = b.D.kick
			var cap: Dictionary = b.cap
			var boat: Dictionary = b.boat
			cap.om += (1.0 if pos.x < b.w * 0.27 else -1.0) * kick
			boat.om += (1.0 if pos.x < b.w * 0.72 else -1.0) * kick
			b.timer = -4.0
		"vehicle":
			b.tgt = pos
			b.timer = -6.0
		"motor":
			var ms: float = b.D.maxSpeed
			b.target = clampf((pos.x / b.w - 0.5) * 2.0 * ms, -ms, ms)
			b.hold = b.D.hold
		"asteroids":
			b.tgt = pos
			b.timer = -6.0
		"drone":
			b.tgt = Vector2(pos.x, clampf(pos.y, b.h * 0.12, b.gy - b.h * 0.18))
			b.hold = 6.0
		"tank":                                          # the turret keeps the old target
			b.aim = b.tgt
			b.tgt = pos
			b.rest = 0.0
		"homing":
			_homing_fire(b, pos)
		"rocket":
			_rocket_reset(b)
			b.timer = 0.9
		"xhair":
			b.ptr = pos
			b.idle = 0.0
		"leaf":
			_leaf_spawn(b.leaves[b.next], pos)
			b.next = (b.next + 1) % (b.leaves as Array).size()


static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"yaw":
			var D: Dictionary = b.D
			var speed: float = D.speed
			var turn: float = D.turn
			var retarget: float = D.retarget
			b.timer += dt
			var want: float = (b.tgt - b.p as Vector2).angle()   # inverse trig: point → angle
			b.hd += clampf(wrapf(want - b.hd, -PI, PI), -turn * dt, turn * dt)
			b.p += Vector2(cos(b.hd), sin(b.hd)) * speed * dt    # forward trig: angle → motion
			b.p.x = wrapf(b.p.x, -12.0, b.w + 12.0)
			b.p.y = wrapf(b.p.y, -12.0, b.h + 12.0)
			if (b.tgt - b.p as Vector2).length() < 15.0 or b.timer > retarget:
				b.timer = 0.0
				b.tgt = Vector2(randf_range(b.w * 0.15, b.w * 0.85), randf_range(b.h * 0.2, b.h * 0.8))
			b.trail.append(b.p)
			if b.trail.size() > D.trail:
				b.trail.pop_front()
		"lookat":
			var D: Dictionary = b.D
			var m := Vector2(b.w / 2.0, b.gy - 4.0)
			b.hold = maxf(0.0, b.hold - dt)
			if b.hold <= 0.0:                            # an idle target crosses the sky on two sines
				var a := Vector2(b.w / 2.0 + cos(t * 0.5) * b.w * 0.42, b.h * 0.35 + sin(t * 0.9) * b.h * 0.25)
				b.tgt = (b.tgt as Vector2).lerp(a, Kit.smooth(2.0, dt))
			var cone: float = D.cone * PI / 180.0
			var rate: float = D.rate
			var raw: float = (b.tgt - m as Vector2).angle()  # inverse trig: point → angle
			var off := wrapf(raw - MOUNT, -PI, PI)           # the angle relative to the mount
			var rel := clampf(off, -cone, cone)              # the cone: a clamp on that angle
			var want := MOUNT + rel
			b.ang += wrapf(want - b.ang, -PI, PI) * Kit.smooth(rate, dt)   # the short arc, a fraction per frame
			b.off = off
		"upright":
			var D: Dictionary = b.D
			var k: float = D.k
			var c: float = D.c
			var kick: float = D.kick
			var auto_kick: float = D.autoKick
			var cap: Dictionary = b.cap
			var boat: Dictionary = b.boat
			var bx: float = b.w * 0.72
			b.timer += dt
			if b.timer > auto_kick:                      # it shoves itself, alternating
				b.timer = 0.0
				b.side = -b.side
				cap.om += b.side * kick
				boat.om += b.side * kick * 0.6
			_upright_spring(cap, 0.0, dt, k, c)          # "up" is 0
			_upright_spring(boat, atan(_slope(b, bx, t)), dt, k, c)   # "up" is the wave's normal
		"vehicle":
			var D: Dictionary = b.D
			var speed: float = D.speed
			var steer_rate: float = D.steerRate
			var max_trail: int = D.trail
			b.timer += dt
			var L: float = b.w * D.wheelbase
			var LOCK: float = D.lock * PI / 180.0
			var p: Vector2 = b.p
			var tgt: Vector2 = b.tgt
			var hd: float = b.hd
			var steer: float = b.steer
			var want := (tgt - p).angle()
			var want_steer := clampf(wrapf(want - hd, -PI, PI), -LOCK, LOCK)   # the wheel can only turn so far
			steer += (want_steer - steer) * Kit.smooth(steer_rate, dt)         # and only so fast
			hd += speed / L * tan(steer) * dt            # ← the bicycle model, whole
			p += Vector2(cos(hd), sin(hd)) * speed * dt
			if p.x < -L:
				p.x = b.w + L
			if p.x > b.w + L:
				p.x = -L
			if p.y < -L:
				p.y = b.h + L
			if p.y > b.h + L:
				p.y = -L
			if (tgt - p).length() < 14.0 or b.timer > 8.0:
				b.timer = 0.0
				tgt = Vector2(randf_range(b.w * 0.15, b.w * 0.85), randf_range(b.h * 0.2, b.h * 0.8))
			b.p = p
			b.hd = hd
			b.steer = steer
			b.tgt = tgt
			b.trail.append(p)
			if b.trail.size() > max_trail:
				b.trail.pop_front()
		"motor":
			var D: Dictionary = b.D
			var ms: float = D.maxSpeed
			var accel: float = D.accel
			var radius: float = D.radius
			if b.hold > 0.0:
				b.hold -= dt
			else:
				b.timer += dt
				if b.timer > 3.5:
					b.timer = 0.0
					b.sched = (b.sched + 1) % PLAN.size()
					b.target = PLAN[b.sched] * ms
			var v: float = b.v
			var target: float = b.target
			var dv := target - v                         # throttle and brake: a fixed step toward the target
			var step := accel * dt
			v += dv if absf(dv) < step else signf(dv) * step
			var rS: float = b.h * radius
			var rB := rS * 2.0
			b.spinS += v / rS * dt                       # ← ω = v ÷ r, twice
			b.spinB += v / rB * dt
			var x: float = b.x + v * dt
			var span := rS + rB + 8.0
			if x > b.w + rB + 2.0:
				x = -span - rS - 2.0
			if x < -span - rS - 2.0:
				x = b.w + rB + 2.0
			b.x = x
			b.v = v
		"asteroids":
			var D: Dictionary = b.D
			var ms: float = D.maxSpeed
			var turn: float = D.turn
			var thrust: float = D.thrust
			var arrive: float = D.arrive
			var aim: float = D.aim
			b.timer += dt
			var p: Vector2 = b.p
			var v: Vector2 = b.v
			var tgt: Vector2 = b.tgt
			var hd: float = b.hd
			var d := tgt - p
			var dv := d * arrive                         # the desired velocity
			var ds := dv.length()
			if ds > ms:
				dv *= ms / ds
			var e := dv - v                              # the error: what thrust must fix
			var es := e.length()
			var want := e.angle()
			var miss := wrapf(want - hd, -PI, PI)
			hd += clampf(miss, -turn * dt, turn * dt)    # turn first (Yaw)
			var burning := es > 6.0 and absf(miss) < aim
			if burning:                                  # then burn
				v += Vector2(cos(hd), sin(hd)) * thrust * dt
			var s := v.length()
			if s > ms:
				v *= ms / s
			p += v * dt                                  # inertia: nothing else touches v
			if p.x < -12.0:
				p.x = b.w + 12.0
			if p.x > b.w + 12.0:
				p.x = -12.0
			if p.y < -12.0:
				p.y = b.h + 12.0
			if p.y > b.h + 12.0:
				p.y = -12.0
			if (d.length() < 12.0 and s < 25.0) or b.timer > 9.0:
				b.timer = 0.0
				tgt = Vector2(randf_range(b.w * 0.15, b.w * 0.85), randf_range(b.h * 0.15, b.h * 0.85))
			b.p = p
			b.v = v
			b.hd = hd
			b.tgt = tgt
			b.dv = dv
			b.err = e
			b.burning = burning
			b.trail.append(p)
			if b.trail.size() > 60:
				b.trail.pop_front()
		"drone":
			var D: Dictionary = b.D
			var w: float = D.omega
			var g: float = b.h * D.g
			var tilt_max: float = D.tiltMax
			var wander: float = D.wander
			if b.hold > 0.0:
				b.hold -= dt
			else:
				b.timer += dt
				if b.timer > wander:
					b.timer = 0.0
					b.tgt = Vector2(randf_range(b.w * 0.15, b.w * 0.85), randf_range(b.h * 0.15, b.gy - b.h * 0.2))
			var p: Vector2 = b.p
			var v: Vector2 = b.v
			var tgt: Vector2 = b.tgt
			var acc := w * w * (tgt - p) - 2.0 * w * v   # ζ = 1: the damping is exactly 2ω
			v += acc * dt
			p += v * dt
			var tilt := clampf(acc.x / g, -tilt_max, tilt_max)   # ← the lean, read off the acceleration
			var lift := 1.0 - acc.y / g                  # climbing = both rotors work harder
			b.spinL += (18.0 + 10.0 * lift - 10.0 * tilt) * dt   # leaning right: the LEFT rotor spins harder
			b.spinR += (18.0 + 10.0 * lift + 10.0 * tilt) * dt
			b.p = p
			b.v = v
			b.acc = acc
			b.tilt = tilt
		"tank":
			var D: Dictionary = b.D
			var track: float = D.track
			var width: float = b.h * D.width
			var turn_gain: float = D.turnGain
			var turret_rate: float = D.turretRate
			var arrive: float = D.arrive
			var p: Vector2 = b.p
			var tgt: Vector2 = b.tgt
			var hd: float = b.hd
			var dvec := tgt - p
			var d := dvec.length()
			var err := wrapf(dvec.angle() - hd, -PI, PI)
			var v := 0.0
			var om := 0.0
			if d > b.w * arrive:                         # the driver's intent: a speed and a spin
				v = clampf(d * 1.5, 0.0, track) * maxf(0.0, cos(err))   # no driving until roughly facing it
				om = clampf(err * turn_gain, -2.0 * track / width, 2.0 * track / width)
				b.rest = 0.0
			else:
				b.rest += dt
				if b.rest > 2.0:
					b.rest = 0.0
					b.aim = tgt
					tgt = Vector2(randf_range(b.w * 0.15, b.w * 0.85), randf_range(b.h * 0.2, b.h * 0.85))
			var vL := clampf(v - om * width / 2.0, -track, track)   # intent → two track speeds
			var vR := clampf(v + om * width / 2.0, -track, track)
			v = (vL + vR) / 2.0                          # ← and the honest way back: the body
			om = (vR - vL) / width                       #   only knows what its tracks do
			hd += om * dt
			p += Vector2(cos(hd), sin(hd)) * v * dt
			b.distL += vL * dt                           # each tread's own odometer
			b.distR += vR * dt
			var aim: Vector2 = b.aim
			var want := (aim - p).angle()
			b.tur += wrapf(want - b.tur, -PI, PI) * Kit.smooth(turret_rate, dt)   # Lookat, verbatim
			b.p = p
			b.hd = hd
			b.tgt = tgt
			b.vL = vL
			b.vR = vR
		"homing":
			var D: Dictionary = b.D
			var speed: float = D.speed
			var turn: float = D.turn
			var fuse: float = D.fuse
			var life: float = D.life
			var lead: float = D.lead
			var prey: Dictionary = b.prey
			prey.wa += randf_range(-2.4, 2.4) * sqrt(dt)     # the prey wanders (Wander's jitter)...
			var wa: float = prey.wa
			var pp: Vector2 = prey.p
			var pv: Vector2 = prey.v
			var f := Vector2(cos(wa), sin(wa))
			f += Vector2((b.w / 2.0 - pp.x) / b.w * 1.6, (b.h / 2.0 - pp.y) / b.h * 1.6)   # ...and leans back toward the middle
			var fl := f.length()
			if fl == 0.0:
				fl = 1.0
			pv += (f / fl * 75.0 - pv) * 3.0 * dt
			pp = Vector2(clampf(pp.x + pv.x * dt, 10.0, b.w - 10.0), clampf(pp.y + pv.y * dt, 10.0, b.h - 10.0))
			prey.p = pp
			prey.v = pv
			var ms: Array = b.missiles
			b.quiet += dt
			if ms.is_empty() and b.quiet > 1.6:
				b.quiet = 0.0
				_homing_fire(b, Vector2(6.0 if randf() < 0.5 else b.w - 6.0, b.h - 6.0))
			b.puff += dt
			var do_puff: bool = b.puff > 0.05
			if do_puff:
				b.puff = 0.0
			var smoke: Array = b.smoke
			var bursts: Array = b.bursts
			b.pred_on = false
			for i in range(ms.size() - 1, -1, -1):
				var m: Dictionary = ms[i]
				m.age += dt
				var mp: Vector2 = m.p
				var mh: float = m.h
				var dvec := pp - mp
				var d := dvec.length()
				var eta := d / speed                     # time to get there, if the prey stood still
				var px := pp + pv * eta * lead           # Chase's point
				var want := (px - mp).angle()
				mh += clampf(wrapf(want - mh, -PI, PI), -turn * dt, turn * dt)   # Yaw's limit
				mp += Vector2(cos(mh), sin(mh)) * speed * dt
				m.h = mh
				m.p = mp
				if do_puff:
					if smoke.size() >= 120:
						smoke.pop_front()
					smoke.append({ "p": mp, "a": 0.0 })
				if d < fuse:                             # the fuse
					b.hits += 1
					ms.remove_at(i)
					if bursts.size() >= 8:
						bursts.pop_front()
					bursts.append({ "p": mp, "a": 0.0 })
					pv += dvec / (d if d > 0.0 else 1.0) * -120.0   # the prey is knocked
					prey.v = pv
					continue
				if m.age > life or mp.x < -30.0 or mp.x > b.w + 30.0 or mp.y < -30.0 or mp.y > b.h + 30.0:
					ms.remove_at(i)                      # the lifetime
				if i == 0:                               # one prediction, made visible
					b.pred = px
					b.pred_on = true
			for i in range(smoke.size() - 1, -1, -1):    # the smoke ages (the web does this while drawing)
				var s: Dictionary = smoke[i]
				s.a += dt
				if s.a > 1.2:
					smoke.remove_at(i)
			for i in range(bursts.size() - 1, -1, -1):
				var bu: Dictionary = bursts[i]
				bu.a += dt
				if bu.a > 0.5:
					bursts.remove_at(i)
		"rocket":
			var D: Dictionary = b.D
			var g: float = b.h * D.g
			var F1: float = D.thrust * g                 # F is fixed; the mass under it is not
			var burn: float = D.burn
			var burn2: float = D.burn2
			var pitch_rate: float = D.pitchRate
			var pitch_max: float = D.pitchMax
			var gy: float = b.gy
			var boo: Dictionary = b.boo
			b.timer += dt
			var F := 0.0
			var p: Vector2 = b.p
			var v: Vector2 = b.v
			var pitch: float = b.pitch
			if b.phase == "pad" and b.timer > 1.2:
				b.phase = "s1"
				b.timer = 0.0
			if b.phase == "s1":
				b.m = 1.0 - 0.5 * clampf(b.timer / burn, 0.0, 1.0)   # stage one: half the rocket is fuel
				F = F1
				if b.timer > burn:                       # STAGING: the booster falls away
					b.phase = "s2"
					b.timer = 0.0
					b.m = 0.35
					boo.on = true
					boo.p = p
					boo.v = v + Vector2(-12.0, 10.0)
					boo.a = pitch
					boo.spin = 1.4
			if b.phase == "s2":
				b.m = 0.35 - 0.2 * clampf(b.timer / burn2, 0.0, 1.0)   # a smaller engine on a lighter ship
				F = F1 * 0.32
				if b.timer > burn2:
					b.phase = "coast"
					b.timer = 0.0
			if b.phase != "pad" and b.phase != "done":
				if F > 0.0:                              # the gravity turn
					pitch = minf(pitch + pitch_rate * PI / 180.0 * dt, pitch_max * PI / 180.0)
				else:                                    # coasting: point along the velocity
					pitch = atan2(v.x, -v.y)
				var a: float = F / b.m                   # ← F ÷ m, the whole reason to burn fuel
				b.aRead = a / g
				v += Vector2(sin(pitch) * a, -cos(pitch) * a + g) * dt   # minus gravity, straight down
				var s := v.length()
				var cap: float = b.h * 3.0
				if s > cap:
					v *= cap / s
				p += v * dt
				b.puff += dt
				if b.puff > 0.06:
					b.puff = 0.0
					if b.trail.size() >= 100:
						b.trail.pop_front()
					b.trail.append(p)
				if p.y > gy - 6.0 and v.y > 0.0:         # it came back down
					b.phase = "done"
					b.timer = 0.0
				if p.x > b.w + 40.0 or p.y < -b.h * 0.6 or p.x < -40.0:
					b.phase = "done"
					b.timer = 0.0
			b.p = p
			b.v = v
			b.pitch = pitch
			b.F = F
			if b.phase == "done" and b.timer > 1.6:
				_rocket_reset(b)
			if boo.on:                                   # the booster: ballistic, tumbling
				boo.v += Vector2(0.0, g * dt)
				boo.p += boo.v * dt
				boo.a += boo.spin * dt
				if (boo.p as Vector2).y > gy - 4.0:
					boo.on = false
		"xhair":
			var D: Dictionary = b.D
			var assist: float = D.assist
			var friction: float = D.friction
			var pull: float = D.pull
			var follow: float = D.follow
			var ptr: Vector2 = b.ptr
			var c: Vector2 = b.c
			b.idle += dt
			if b.idle > 2.0:                             # nobody dragging: the pointer wanders on two sines
				var a := Vector2(b.w / 2.0 + cos(t * 0.6) * b.w * 0.36, b.h / 2.0 + sin(t * 0.95) * b.h * 0.3)
				ptr = ptr.lerp(a, Kit.smooth(1.5, dt))
			var r: float = b.h * assist
			var near := -1
			var nd := 1.0e9
			var targets: Array = b.targets
			for i in targets.size():
				var g: Dictionary = targets[i]
				var gp: Vector2 = g.p
				var gvx: float = g.vx
				var gph: float = g.ph
				gp.x += gvx * dt
				gp.y = b.h * (0.25 + 0.5 * (0.5 + 0.5 * sin(t * 0.4 + gph)))   # drifting across, gently bobbing
				if gp.x > b.w + 20.0:
					gp.x = -20.0
				if gp.x < -20.0:
					gp.x = b.w + 20.0
				g.p = gp
				var d := (gp - c).length()
				if d < nd:
					nd = d
					near = i
			var v := (ptr - c) * follow                  # the honest follow: a fraction of the gap
			var inside := nd < r
			if inside:
				v *= friction                            # friction: the crosshair sticks
				var k := nd / r
				var hump := 4.0 * k * (1.0 - k)          # the pull's shape: nothing at the centre or the rim
				var np: Vector2 = (targets[near] as Dictionary).p
				var u := (np - c) / (nd if nd > 0.0 else 1.0)
				v += u * pull * hump                     # magnetism
			c += v * dt
			c = Vector2(clampf(c.x, 0.0, b.w), clampf(c.y, 0.0, b.h))
			b.ptr = ptr
			b.c = c
			b.near = near
			b.nd = nd
			b.inside = inside
		"leaf":
			var D: Dictionary = b.D
			var g: float = b.h * D.g
			var rock: float = D.rock
			var amp: float = D.amp
			var pitch: float = D.pitch
			var drag_along: float = D.dragAlong
			var drag_across: float = D.dragAcross
			var gy: float = b.gy
			for l in b.leaves:
				var lp: Vector2 = l.p
				var lv: Vector2 = l.v
				var ph: float = l.ph
				var vf0: float = l.vf
				var a := sin(t * rock + ph) * amp + clampf(-vf0 * pitch, -1.1, 1.1)   # the tilt: a sine + airspeed
				var f := Vector2(cos(a), sin(a))         # along the face
				var nrm := Vector2(-f.y, f.x)            # across it (the normal)
				lv.y += g * dt
				var vf := lv.dot(f)                      # split the velocity into the two directions
				var vn := lv.dot(nrm)
				vf *= exp(-drag_along * dt)              # each with its own drag
				vn *= exp(-drag_across * dt)
				lv = f * vf + nrm * vn                   # and back together
				lp += lv * dt
				if lp.x < -20.0:
					lp.x = b.w + 20.0
				if lp.x > b.w + 20.0:
					lp.x = -20.0
				l.a = a
				l.v = lv
				l.vf = vf
				l.p = lp
				if lp.y > gy - 3.0:                      # landed: another one lets go up top
					_leaf_spawn(l, Vector2(randf_range(b.w * 0.1, b.w * 0.9), -b.h * 0.08))


static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	Kit.stage(n, b)
	var origin: Vector2 = (b.rect as Rect2).position
	match b.id:
		"yaw":
			var D: Dictionary = b.D
			var speed: float = D.speed
			var turn: float = D.turn
			var R := speed / turn                        # turn radius = speed ÷ turn rate — the physics of "too close to aim at"
			var p: Vector2 = b.p
			var hd: float = b.hd
			Kit.ring(n, p + Vector2(cos(hd + PI / 2), sin(hd + PI / 2)) * R, R, Color(0.91, 0.898, 0.957, 0.08))
			Kit.ring(n, p + Vector2(cos(hd - PI / 2), sin(hd - PI / 2)) * R, R, Color(0.91, 0.898, 0.957, 0.08))
			for i in b.trail.size():
				Kit.dot(n, b.trail[i], 1.3, Color(0.541, 0.851, 0.961, i / float(b.trail.size()) * 0.3))
			var tg: Vector2 = b.tgt                      # the flag
			n.draw_line(tg + Vector2(0, 8), tg + Vector2(0, -10), Kit.TARGET, 1.5)
			n.draw_colored_polygon(PackedVector2Array([
				tg + Vector2(0, -10), tg + Vector2(9, -6.5), tg + Vector2(0, -3)]), Kit.TARGET)
			Kit.mote(n, b, p, hd)
			Kit.label(n, b, "%s%d px" % [D.label, roundi(R)], Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"lookat":
			var D: Dictionary = b.D
			Kit.ground(n, b)
			var m := Vector2(b.w / 2.0, b.gy - 4.0)
			var cone: float = D.cone * PI / 180.0
			var L: float = b.h * D.barrel
			var CL: float = b.h * 0.55
			var tgt: Vector2 = b.tgt
			var ang: float = b.ang
			var off: float = b.off
			var rim := Color(0.91, 0.898, 0.957, 0.14)
			Kit.line(n, m, m + Vector2(cos(MOUNT - cone), sin(MOUNT - cone)) * CL, rim)
			Kit.line(n, m, m + Vector2(cos(MOUNT + cone), sin(MOUNT + cone)) * CL, rim)
			n.draw_arc(m, CL, MOUNT - cone, MOUNT + cone, 40, rim, 1.0)   # the cone's rim, as an arc
			n.draw_dashed_line(m, tgt, Color(0.961, 0.757, 0.412, 0.35), 1.0, 4.0)   # the raw angle: where atan2 says
			var half := PackedVector2Array()              # the mount
			for i in 17:
				var a := PI + i / 16.0 * PI
				half.append(m + Vector2(cos(a), sin(a)) * 9.0)
			n.draw_colored_polygon(half, Color(0.788, 0.769, 0.894, 0.5))
			Kit.line(n, m, m + Vector2(cos(ang), sin(ang)) * L, Kit.BONE, 4.0)   # the smoothed barrel
			Kit.dot(n, m, 4.0, Kit.BONE)
			Kit.dot(n, tgt, 5.0, Kit.TARGET)
			Kit.ring(n, tgt, 9.0, Kit.TARGET, 1.0)
			if absf(off) > cone:
				Kit.label(n, b, "out of cone", m + Vector2(cos(ang), sin(ang)) * (L + 8.0) + Vector2(0, -4), Kit.HOT, true)
			Kit.label(n, b, "raw %d°  →  turret %d°" % [roundi(off * 180.0 / PI), roundi(wrapf(ang - MOUNT, -PI, PI) * 180.0 / PI)],
				Vector2(b.w / 2.0, 14.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"upright":
			var D: Dictionary = b.D
			var cap: Dictionary = b.cap
			var boat: Dictionary = b.boat
			var cx: float = b.w * 0.27
			var bx: float = b.w * 0.72
			var gy: float = b.gy
			Kit.line(n, Vector2(0, gy), Vector2(b.w * 0.48, gy), Color(0.788, 0.769, 0.894, 0.5), 1.5)   # the capsule's floor
			var sea := PackedVector2Array()               # the sea
			sea.append(Vector2(b.w * 0.5, _wave(b, b.w * 0.5, t)))
			var x: float = b.w * 0.5 + 4.0
			while x <= b.w:
				sea.append(Vector2(x, _wave(b, x, t)))
				x += 4.0
			n.draw_polyline(sea, Color(0.788, 0.769, 0.894, 0.5), 1.5)
			var fill := PackedVector2Array(sea)
			fill.append(Vector2(b.w, b.h))
			fill.append(Vector2(b.w * 0.5, b.h))
			n.draw_colored_polygon(fill, Color(0.541, 0.851, 0.961, 0.08))
			var CL: float = b.h * 0.22                   # the capsule: pivot at its foot
			var cth: float = cap.th
			var foot := Vector2(cx, gy - 7.0)
			var tip := Vector2(cx + sin(cth) * CL, gy - cos(cth) * CL)
			Kit.line(n, foot, tip, Kit.MOVER, 14.0)      # round caps: a disc at each end
			Kit.dot(n, foot, 7.0, Kit.MOVER)
			Kit.dot(n, tip, 7.0, Kit.MOVER)
			Kit.line(n, foot, foot + Vector2(sin(cth), -cos(cth)) * CL * 0.5, Color(0.075, 0.063, 0.125, 0.35), 2.0)
			Kit.dot(n, tip + Vector2(cos(cth), sin(cth)) * 3.0, 2.0, Kit.NIGHT)
			Kit.line(n, foot, Vector2(cx, gy - 7.0 - CL - 8.0), Kit.DIM)   # the "up" it wants
			var by := _wave(b, bx, t)
			var bth: float = boat.th
			n.draw_set_transform(origin + Vector2(bx, by), bth, Vector2.ONE)
			Kit.poly(n, [Vector2(-16, -2), Vector2(16, -2), Vector2(11, 7), Vector2(-11, 7)], Kit.MOVER)   # the hull
			Kit.line(n, Vector2(0, -2), Vector2(0, -b.h * 0.16), Kit.BONE, 2.0)   # the mast
			Kit.poly(n, [Vector2(0, -b.h * 0.16 + 2), Vector2(12, -b.h * 0.08), Vector2(0, -b.h * 0.07)], Color(0.788, 0.769, 0.894, 0.5))
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			var nrm := atan(_slope(b, bx, t))
			Kit.line(n, Vector2(bx, by), Vector2(bx - sin(nrm) * 26.0, by - cos(nrm) * 26.0), Color(0.608, 0.886, 0.541, 0.5))
			Kit.label(n, b, "θ = %d°" % roundi(cth * 180.0 / PI), Vector2(cx, b.h * 0.16), Kit.DIM, true)
			Kit.label(n, b, "up = the wave's normal", Vector2(bx, b.h * 0.16), Color(0.608, 0.886, 0.541, 0.6), true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"vehicle":
			var D: Dictionary = b.D
			var L: float = b.w * D.wheelbase
			var p: Vector2 = b.p
			var hd: float = b.hd
			var steer: float = b.steer
			var tgt: Vector2 = b.tgt
			if absf(steer) > 0.03:                       # the turning circle this steer angle buys
				var R := L / tan(steer)
				Kit.ring(n, Vector2(p.x - sin(hd) * R, p.y + cos(hd) * R), absf(R), Color(0.91, 0.898, 0.957, 0.08))
			var trail: Array = b.trail
			for i in trail.size():
				Kit.dot(n, trail[i], 1.3, Color(0.541, 0.851, 0.961, i / float(trail.size()) * 0.3))
			Kit.ring(n, tgt, 8.0, Kit.TARGET, 1.5)
			Kit.dot(n, tgt, 2.5, Kit.TARGET)
			var w := L * 0.36
			n.draw_set_transform(origin + p, hd, Vector2.ONE)
			Kit.rect(n, Rect2(-L * 0.3, -w * 0.8, L * 1.55, w * 1.6), Kit.MOVER)   # the body, rear axle at the origin
			Kit.rect(n, Rect2(-3, -w - 2, 6, 4), Kit.BONE)   # rear wheels: always straight
			Kit.rect(n, Rect2(-3, w - 2, 6, 4), Kit.BONE)
			for s in [-1.0, 1.0]:                        # front wheels: turned by the steer angle
				var side: float = s
				n.draw_set_transform(origin + p + Vector2(L, side * w).rotated(hd), hd + steer, Vector2.ONE)
				Kit.rect(n, Rect2(-3, -2, 6, 4), Kit.BONE)
			n.draw_set_transform(origin + p, hd, Vector2.ONE)
			n.draw_circle(Vector2(L * 0.9, -w * 0.3), 2.0, Kit.NIGHT)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.label(n, b, "steer %d°  ·  L = %d px" % [roundi(steer * 180.0 / PI), roundi(L)], Vector2(b.w / 2.0, 14.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"motor":
			var D: Dictionary = b.D
			var ms: float = D.maxSpeed
			var spokes: int = D.spokes
			var gy: float = b.gy
			var v: float = b.v
			var target: float = b.target
			var rS: float = b.h * D.radius
			var rB := rS * 2.0
			var span := rS + rB + 8.0
			var xb: float = b.x
			var xs := xb + span                          # the big wheel leads, the small one trails
			Kit.ground(n, b)
			Kit.line(n, Vector2(xb, gy - rB), Vector2(xs, gy - rS), Kit.BONE, 2.0)   # the axle bar joining them
			for wh in [[xb, rB, b.spinB], [xs, rS, b.spinS]]:
				var wx: float = wh[0]
				var r: float = wh[1]
				var a: float = wh[2]
				var c := Vector2(wx, gy - r)
				Kit.ring(n, c, r, Kit.MOVER, 2.5)
				for i in spokes:
					var sa := a + i * TAU / spokes
					Kit.line(n, c, c + Vector2(cos(sa), sin(sa)) * r, Color(0.541, 0.851, 0.961, 0.6), 1.5)
				Kit.dot(n, c, 3.0, Kit.BONE)
				Kit.dot(n, Vector2(wx, gy - 1.0), 2.5, Kit.HOT)   # the contact point: momentarily at rest
				Kit.label(n, b, "ω = %.1f" % (v / r), Vector2(wx, gy - r * 2.0 - 8.0), Kit.DIM, true)
			if absf(v) > 2.0:
				Kit.arrow(n, Vector2(xb, gy - rB), Vector2(xb + v * 0.3, gy - rB), Kit.TARGET)
			var gx: float = b.w * 0.15                   # the speed gauge
			var gw: float = b.w * 0.7
			Kit.line(n, Vector2(gx, 14), Vector2(gx + gw, 14), Kit.DIM)
			Kit.line(n, Vector2(gx + gw / 2.0, 10), Vector2(gx + gw / 2.0, 18), Kit.DIM)
			Kit.ring(n, Vector2(gx + gw / 2.0 + target / ms * gw / 2.0, 14.0), 4.0, Kit.TARGET, 1.5)
			Kit.dot(n, Vector2(gx + gw / 2.0 + v / ms * gw / 2.0, 14.0), 3.0, Kit.MOVER)
			Kit.label(n, b, "v = %d px/s" % roundi(v), Vector2(b.w / 2.0, 30.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"asteroids":
			var D: Dictionary = b.D
			var p: Vector2 = b.p
			var hd: float = b.hd
			var tgt: Vector2 = b.tgt
			var dv: Vector2 = b.dv
			var e: Vector2 = b.err
			var burning: bool = b.burning
			var trail: Array = b.trail
			for i in trail.size():
				Kit.dot(n, trail[i], 1.2, Color(0.541, 0.851, 0.961, i / float(trail.size()) * 0.3))
			Kit.ring(n, tgt, 8.0, Kit.TARGET, 1.5)
			Kit.arrow(n, p, p + dv * 0.25, Color(0.961, 0.757, 0.412, 0.5))   # desired
			Kit.arrow(n, p, p + e * 0.25, Kit.HOT)                             # the error it steers by
			n.draw_set_transform(origin + p, hd, Vector2.ONE)
			if burning:                                  # the thruster flame, flickering
				var f := 10.0 + randf_range(0.0, 6.0)
				Kit.poly(n, [Vector2(-7, -3.5), Vector2(-7.0 - f, 0), Vector2(-7, 3.5)], Kit.HOT)
			Kit.poly(n, [Vector2(12, 0), Vector2(-7, -7), Vector2(-4, 0), Vector2(-7, 7)], Kit.MOVER)
			n.draw_circle(Vector2(3, -2), 1.6, Kit.NIGHT)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.label(n, b, "burn" if burning else "coast", Vector2(p.x, p.y - 14.0), Kit.HOT if burning else Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"drone":
			var D: Dictionary = b.D
			Kit.ground(n, b)
			var p: Vector2 = b.p
			var tgt: Vector2 = b.tgt
			var tilt: float = b.tilt
			var acc: Vector2 = b.acc
			var arm: float = b.w * D.arm
			var gy: float = b.gy
			n.draw_dashed_line(Vector2(tgt.x, gy), tgt, Color(0.961, 0.757, 0.412, 0.3), 1.0, 4.0)
			Kit.ring(n, tgt, 7.0, Kit.TARGET, 1.5)
			n.draw_set_transform(origin + p, tilt, Vector2.ONE)
			Kit.rect(n, Rect2(-arm - 4.0, -2.0, arm * 2.0 + 8.0, 4.0), Kit.BONE)   # the arms
			Kit.rect(n, Rect2(-7, -6, 14, 10), Kit.MOVER)                           # the body
			for s in [-1.0, 1.0]:                        # each rotor, seen edge-on: a blade whose
				var side: float = s                      # apparent length is |cos(spin)| · blade
				var sp: float = b.spinL if side < 0.0 else b.spinR
				var bl := arm * 0.7 * absf(cos(sp))
				Kit.line(n, Vector2(side * arm - bl, -5.0), Vector2(side * arm + bl, -5.0), Color(0.91, 0.898, 0.957, 0.75), 2.0)
				Kit.dot(n, Vector2(side * arm, -5.0), 2.0, Kit.BONE)
			n.draw_circle(Vector2(3, -1), 1.8, Kit.NIGHT)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.arrow(n, p + Vector2(0, 12), p + Vector2(0, 12) + acc * 0.06, Kit.HOT)   # the acceleration the spring asks for
			Kit.label(n, b, "tilt = %d°" % roundi(tilt * 180.0 / PI), Vector2(p.x, p.y - arm * 0.5 - 12.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"tank":
			var D: Dictionary = b.D
			var width: float = b.h * D.width
			var p: Vector2 = b.p
			var hd: float = b.hd
			var tgt: Vector2 = b.tgt
			var aim: Vector2 = b.aim
			var tur: float = b.tur
			Kit.ring(n, tgt, 8.0, Kit.TARGET, 1.5)
			Kit.dot(n, tgt, 2.5, Kit.TARGET)
			Kit.ring(n, aim, 5.0, Color(0.961, 0.757, 0.412, 0.5), 1.0)
			n.draw_dashed_line(p, aim, Color(0.961, 0.757, 0.412, 0.25), 1.0, 5.0)
			var bl := width * 1.5                        # body length; tread thickness
			var tw := width * 0.35
			n.draw_set_transform(origin + p, hd, Vector2.ONE)
			for s in [-1.0, 1.0]:                        # the treads, ticks scrolling by each odometer
				var side: float = s
				var cy := side * width / 2.0
				var od: float = b.distL if side < 0.0 else b.distR
				Kit.rect(n, Rect2(-bl / 2.0, cy - tw / 2.0, bl, tw), Color(0.788, 0.769, 0.894, 0.35))
				var ph := fposmod(od, 6.0)
				var k := -ph
				while k < bl:
					if k >= 0.0:
						Kit.line(n, Vector2(-bl / 2.0 + k, cy - tw / 2.0), Vector2(-bl / 2.0 + k, cy + tw / 2.0), Kit.BONE, 1.0)
					k += 6.0
			Kit.rect(n, Rect2(-bl * 0.4, -width / 2.0 + tw / 2.0, bl * 0.8, width - tw), Kit.MOVER)   # the hull
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.line(n, p, p + Vector2(cos(tur), sin(tur)) * width * 1.1, Kit.BONE, 3.0)   # the barrel
			Kit.dot(n, p, width * 0.28, Color(0.788, 0.769, 0.894, 0.9))
			Kit.label(n, b, "vL %d  vR %d" % [roundi(b.vL), roundi(b.vR)], Vector2(p.x, p.y - width - 6.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"homing":
			var D: Dictionary = b.D
			var fuse: float = D.fuse
			var prey: Dictionary = b.prey
			var pp: Vector2 = prey.p
			var pv: Vector2 = prey.v
			var ms: Array = b.missiles
			if b.pred_on:                                # one prediction, made visible
				Kit.ring(n, b.pred, 5.0, Color(0.961, 0.757, 0.412, 0.5))
			for s in b.smoke:
				var sa: float = s.a
				Kit.dot(n, s.p, 1.5 + sa * 3.0, Color(0.788, 0.769, 0.894, 0.3 * (1.0 - sa / 1.2)))
			for bu in b.bursts:
				var ba: float = bu.a
				Kit.ring(n, bu.p, 6.0 + ba * 50.0, Color(0.961, 0.541, 0.541, 0.8 * (1.0 - ba / 0.5)), 2.0)
			for m in ms:
				n.draw_set_transform(origin + (m.p as Vector2), m.h, Vector2.ONE)
				Kit.poly(n, [Vector2(7, 0), Vector2(-5, -3.5), Vector2(-3, 0), Vector2(-5, 3.5)], Kit.HOT)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.ring(n, pp, fuse, Color(0.608, 0.886, 0.541, 0.25))   # the fuse radius, around the prey
			Kit.mote(n, b, pp, pv.angle(), Kit.GOOD, 6.0)
			Kit.label(n, b, "hits ×%d · %d in flight" % [b.hits, ms.size()], Vector2(b.w / 2.0, 14.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"rocket":
			var D: Dictionary = b.D
			Kit.ground(n, b)
			var gy: float = b.gy
			var trail: Array = b.trail
			var boo: Dictionary = b.boo
			var phase: String = b.phase
			var F: float = b.F
			var p: Vector2 = b.p
			var pitch: float = b.pitch
			for i in trail.size():
				Kit.dot(n, trail[i], 1.3, Color(0.788, 0.769, 0.894, 0.1 + i / float(trail.size()) * 0.3))
			Kit.line(n, Vector2(b.w * 0.2 - 12.0, gy), Vector2(b.w * 0.2 + 12.0, gy), Kit.BONE, 3.0)   # the pad
			if boo.on:
				n.draw_set_transform(origin + (boo.p as Vector2), boo.a, Vector2.ONE)
				Kit.poly(n, [Vector2(-4, -8), Vector2(4, -8), Vector2(4, 8), Vector2(-4, 8)], Color(0.788, 0.769, 0.894, 0.7))
				n.draw_set_transform(origin, 0.0, Vector2.ONE)
			if phase != "done":
				n.draw_set_transform(origin + p, pitch, Vector2.ONE)
				if F > 0.0:                              # the flame
					Kit.poly(n, [Vector2(-3, 10), Vector2(0, 16.0 + randf_range(0.0, 8.0)), Vector2(3, 10)], Kit.HOT)
				if phase == "pad" or phase == "s1":      # the booster, attached
					Kit.poly(n, [Vector2(-4, 2), Vector2(4, 2), Vector2(4, 12), Vector2(-4, 12)], Kit.BONE)
				Kit.poly(n, [Vector2(0, -12), Vector2(4, -4), Vector2(4, 3), Vector2(-4, 3), Vector2(-4, -4)], Kit.MOVER)
				n.draw_circle(Vector2(1.2, -5), 1.5, Kit.NIGHT)
				n.draw_set_transform(origin, 0.0, Vector2.ONE)
				var a_txt: String = ("%.1fg" % b.aRead) if F > 0.0 else "0"
				Kit.label(n, b, "m %d%%  a = %s" % [roundi(b.m * 100.0), a_txt], Vector2(p.x + 14.0, p.y - 6.0), Kit.DIM)
			var status: String
			if phase == "pad":
				status = "T − %.1f" % maxf(0.0, 1.2 - b.timer)
			elif phase == "coast":
				status = "coast"
			elif phase == "done":
				status = "reset…"
			else:
				status = "stage %d" % (1 if phase == "s1" else 2)
			Kit.label(n, b, status, Vector2(b.w / 2.0, 14.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"xhair":
			var D: Dictionary = b.D
			var r: float = b.h * D.assist
			var c: Vector2 = b.c
			var ptr: Vector2 = b.ptr
			var inside: bool = b.inside
			var near: int = b.near
			var targets: Array = b.targets
			for i in targets.size():
				var g: Dictionary = targets[i]
				var gp: Vector2 = g.p
				var hot := i == near and inside
				if hot:                                  # the assist ring
					Kit.ring(n, gp, r, Color(0.961, 0.757, 0.412, 0.6), 1.5)
				else:
					_dashed_ring(n, gp, r, Color(0.961, 0.757, 0.412, 0.25), 1.0)
				Kit.dot(n, gp, 7.0, Kit.HOT if hot else Kit.BONE)
				n.draw_circle(gp + Vector2(2.4, -2.0), 1.8, Kit.NIGHT)
			Kit.line(n, c, ptr, Color(0.91, 0.898, 0.957, 0.2))   # the gap: the assist, made visible
			Kit.dot(n, ptr, 2.5, Kit.DIM)                # the honest pointer
			Kit.ring(n, c, 9.0, Kit.MOVER, 1.5)          # the crosshair
			Kit.line(n, c + Vector2(-14, 0), c + Vector2(-5, 0), Kit.MOVER, 1.5)
			Kit.line(n, c + Vector2(5, 0), c + Vector2(14, 0), Kit.MOVER, 1.5)
			Kit.line(n, c + Vector2(0, -14), c + Vector2(0, -5), Kit.MOVER, 1.5)
			Kit.line(n, c + Vector2(0, 5), c + Vector2(0, 14), Kit.MOVER, 1.5)
			Kit.label(n, b, "assisting" if inside else "free", c + Vector2(0, -20), Kit.TARGET if inside else Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), LBL, true)
		"leaf":
			var D: Dictionary = b.D
			Kit.ground(n, b)
			var leaves: Array = b.leaves
			var next: int = b.next
			var L := 9.0
			for i in leaves.size():
				var l: Dictionary = leaves[i]
				var lp: Vector2 = l.p
				var la: float = l.a
				n.draw_set_transform(origin + lp, la, Vector2.ONE)
				Kit.poly(n, [Vector2(-L, 0), Vector2(-L * 0.4, -L * 0.45), Vector2(L * 0.4, -L * 0.4), Vector2(L, 0),
					Vector2(L * 0.4, L * 0.4), Vector2(-L * 0.4, L * 0.45)],
					Color(0.608, 0.886, 0.541, 0.9) if i == next else Color(0.608, 0.886, 0.541, 0.7))
				Kit.line(n, Vector2(-L, 0), Vector2(L, 0), Color(0.075, 0.063, 0.125, 0.4), 1.0)   # the vein: the face direction
				n.draw_set_transform(origin, 0.0, Vector2.ONE)
				if i == 0:                               # one leaf shows its working
					var lv: Vector2 = l.v
					var nrm := Vector2(-sin(la), cos(la))
					Kit.arrow(n, lp, lp + lv * 0.3, Kit.DIM)
					Kit.line(n, lp, lp + nrm * 16.0, Color(0.608, 0.886, 0.541, 0.5))
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), LBL, true)


## Upright: the angular spring-damper, α = −k·θ − c·ω, integrated twice.
static func _upright_spring(body: Dictionary, target: float, dt: float, k: float, c: float) -> void:
	body.om += (-k * (body.th - target) - c * body.om) * dt
	body.th += body.om * dt
	var lim := TAU / 4.0 - 0.12                          # lying down is as far as it goes
	if body.th > lim:
		body.th = lim
		body.om = minf(0.0, body.om)
	if body.th < -lim:
		body.th = -lim
		body.om = maxf(0.0, body.om)

## Upright: the boat's sea — its height at x, and its derivative (the slope).
static func _wave(b: Dictionary, x: float, t: float) -> float:
	var wave_speed: float = b.D.waveSpeed
	var wave_amp: float = b.D.waveAmp
	var gy: float = b.gy
	var h: float = b.h
	return gy - h * 0.06 + sin(x * KX - t * wave_speed) * h * wave_amp

static func _slope(b: Dictionary, x: float, t: float) -> float:
	var wave_speed: float = b.D.waveSpeed
	var wave_amp: float = b.D.waveAmp
	var h: float = b.h
	return cos(x * KX - t * wave_speed) * h * wave_amp * KX

## Homing: a salvo from f — the same target, a fan of starting headings.
static func _homing_fire(b: Dictionary, f: Vector2) -> void:
	var prey: Dictionary = b.prey
	var salvo: int = b.D.salvo
	var ms: Array = b.missiles
	var base: float = (prey.p - f as Vector2).angle()
	for i in salvo:
		if ms.size() >= 30:
			ms.pop_front()
		var spread := (i - (salvo - 1) / 2.0) * 0.45     # the fan
		ms.append({ "p": f, "h": base + spread, "age": 0.0 })

## Rocket: back on the pad, tanks full, booster attached.
static func _rocket_reset(b: Dictionary) -> void:
	b.phase = "pad"
	b.timer = 0.0
	b.p = Vector2(b.w * 0.2, b.gy - 14.0)
	b.v = Vector2.ZERO
	b.pitch = 0.0
	b.m = 1.0
	(b.boo as Dictionary).on = false
	b.trail = []

## Leaf: one leaf lets go at p, still, with a fresh rocking phase.
static func _leaf_spawn(l: Dictionary, p: Vector2) -> void:
	l.p = p
	l.v = Vector2.ZERO
	l.ph = randf_range(0.0, TAU)
	l.a = 0.0
	l.vf = 0.0

## A dashed ring (the canvas setLineDash([3, 4]) on a circle): short arcs
## around the circumference — draw_arc has no dash pattern of its own.
static func _dashed_ring(n: CanvasItem, p: Vector2, r: float, col: Color, w: float) -> void:
	var segs := maxi(8, int(TAU * r / 7.0))
	var step := TAU / segs
	for k in segs:
		n.draw_arc(p, r, k * step, k * step + step * 3.0 / 7.0, 3, col, w)
