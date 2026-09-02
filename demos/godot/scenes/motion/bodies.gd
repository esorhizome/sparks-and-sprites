extends RefCounted

const Kit := preload("res://scenes/motion/kit.gd")
## BODIES & GROUND — fourteen movement styles, ported from the web lexicon
## (docs/locomotion.js). Honest physics you can read. VERLET integration
## stores no velocity at all — just where each point is and where it was
## last frame; the difference IS the velocity. Add distance constraints and
## you get rope, ragdolls, crates, jelly and kites; add rays and normals and
## bodies learn where the world is — walls to jump off, hills to roll down,
## flippers to reflect from. Gait, the graduation card, spends everything
## the teaching cards earned; the genre laps after it are that physics in
## costume.

const TITLE := "Bodies & ground"
const BLURB := "verlet, impulses, rays, normals — and the walk that uses it all"
const DEFS := [
	{ "id": "ragdoll", "letter": "R", "name": "Ragdoll",
		"hint": "verlet points + distance promises = a body — press to shove it",
		"dials": { "unit": 0.062, "g": 2.6, "damp": 0.99, "rounds": 8, "shove": 300,   # unit = one bone, as a fraction of H
			"trolley": 0.55, "swing": 0.26,                              # the overhead trolley: rate and reach
			"label": "position − last position IS the velocity" },
		"rhyme": { "name": "Ragtime", "hint": "the same puppet at half the gravity, jigged three times as fast by its trolley — it dances instead of dangling",
			"dials": { "g": 1.1, "trolley": 1.7, "damp": 0.995 } } },
	{ "id": "knock", "letter": "K", "name": "Knock",
		"hint": "impulses: a shockwave edits velocities once, then physics gossips — press anywhere",
		"dials": { "g": 2.4, "damp": 0.99, "rounds": 8, "friction": 0.55,
			"press": 380, "gust": 210, "gustMin": 3.5, "gustMax": 5.5,      # the impulse powers, and the gust timer
			"sizes": [13, 17, 10],                                     # three crates, half-widths in px
			"label": "impulse ∝ 1/distance — then constraints gossip" },
		"rhyme": { "name": "Kaboom", "hint": "the same crates under two-and-a-half times the impulse and gusts every second or two — a demolition yard",
			"dials": { "press": 900, "gust": 480, "gustMin": 1.2 } } },
	{ "id": "xmarks", "letter": "X", "name": "Xmarks",
		"hint": "raycasting: where does this line first hit the world? — press to aim the beam",
		"dials": { "sweep": 0.6, "track": 8, "sticky": 3, "bounces": 1,             # idle sweep rate, aim smoothing, reflected legs
			"walls": [[0.28, 0.3, 0.44, 0.52], [0.62, 0.24, 0.78, 0.3], [0.6, 0.7, 0.85, 0.62]],  # fractions of W,H
			"label": "nearest hit · green normal · faint bounce" },
		"rhyme": { "name": "Xtra", "hint": "the same beam reflected five times instead of once, sweeping twice as fast — a laser that fills the room",
			"dials": { "bounces": 5, "sweep": 1.3, "label": "nearest hit, then v − 2(v·n)n, five legs deep" } } },
	{ "id": "normals", "letter": "N", "name": "Normals",
		"hint": "the slope, turned 90°: a walker that hugs its terrain — press to turn it around",
		"dials": { "speed": 52, "base": 0.62,                                   # walker px/s, the hill's mean height
			"hills": [[0.021, 0.1, 0], [0.043, 0.055, 1.3], [0.011, 0.07, 4]],   # sines: frequency, amp of H, phase
			"label": "tangent (1, m) · normal (m, −1) · m = the derivative" },
		"rhyme": { "name": "Nomad", "hint": "twice the speed over hills twice as steep — the normal swings hard and the walker leans like a mountaineer",
			"dials": { "speed": 105, "hills": [[0.03, 0.17, 0], [0.07, 0.05, 1.3], [0.011, 0.09, 4]] } } },
	{ "id": "gait", "letter": "G", "name": "Gait",
		"hint": "the walk that uses it all: homes, thresholds, arcs, and a shifting body — press to send it somewhere",
		"dials": { "thigh": 0.17, "thresh": 0.1, "maxv": 0.36, "bodyH": 0.27,      # bone, step trigger, top speed, hip height
			"stance": 13, "lift": 8, "stepMax": 0.34, "stepMin": 0.15, "retarget": 5,
			"label": "step past threshold · sin(k·π) arc · hips shift" },
		"rhyme": { "name": "Goliath", "hint": "longer thighs, a taller body and twice the step threshold — the same five rules walk like a lumbering giant",
			"dials": { "thigh": 0.24, "bodyH": 0.4, "thresh": 0.19 } } },
	{ "id": "grapple", "letter": "G", "name": "Grapple",
		"hint": "raycast a hook to the ceiling, swing on one rope constraint, let go and fly — press to hook, again to release",
		"dials": { "g": 2.2, "damp": 0.995, "reel": 0.25, "minRope": 0.16,         # gravity ×H, verlet damping, winch ×H/s, shortest rope ×H
			"swingTime": 2.4, "restTime": 0.9, "ceiling": 0.08,             # seconds hanging, seconds resting, ceiling y ×H
			"ledges": [[0.12, 0.36, 0.38, 0.34], [0.62, 0.46, 0.9, 0.42]],   # hookable bars, fractions of W and H
			"label": "raycast hook · rope |p − a| ≤ L · let go: fly" },
		"rhyme": { "name": "Gibbon", "hint": "half the gravity, a slower winch and longer hangs — the same rope, swung the lazy way through a canopy",
			"dials": { "g": 1.1, "reel": 0.12, "swingTime": 3.8 } } },
	{ "id": "rope", "letter": "R", "name": "Rope", "drag": true,
		"hint": "a verlet rope: gravity, wind from noise, and eight rounds of distance constraints — drag to pull any point",
		"dials": { "n": 14, "seg": 0.045, "rounds": 8, "g": 2.4, "damp": 0.995,       # links, link length ×H, solver passes, gravity ×H
			"wind": 0.5, "windRate": 0.7, "weight": 3,                       # wind ×H/s², its noise speed, the bob's mass
			"label": "8 rounds: each link splits its error in half" },
		"rhyme": { "name": "Ribbon", "hint": "twenty-two shorter links in five times the wind — the plumb line becomes a streamer",
			"dials": { "n": 22, "seg": 0.03, "wind": 2.4 } } },
	{ "id": "ninja", "letter": "N", "name": "Ninja",
		"hint": "wall-slide caps the fall; Jump's √(2gh) plus a sideways kick climbs the shaft wall to wall — press to jump now",
		"dials": { "g": 2.2, "jumpH": 0.26, "kick": 0.55, "slide": 0.12, "slideG": 0.3,   # gravity ×H, apex ×H, kick ×W/s, slide cap ×H/s
			"cling": 0.35, "left": 0.3, "right": 0.7,                          # seconds on the wall before it jumps; the shaft
			"label": "slide: vy ≤ cap · jump: v₀ = √(2gh) + kick" },
		"rhyme": { "name": "Nitro", "hint": "jumps half again as high with nearly twice the kick and no time to cling — a rocket ricocheting up the shaft",
			"dials": { "jumpH": 0.38, "kick": 0.9, "cling": 0.12 } } },
	{ "id": "jelly", "letter": "J", "name": "Jelly",
		"hint": "soft body: Ragdoll's verlet points in a ring, links to neighbours and centre, plus pressure — press to poke it",
		"dials": { "n": 16, "r": 0.14, "g": 2.0, "rounds": 4, "damp": 0.985,          # ring points, radius ×H, gravity ×H, solver passes
			"spoke": 0.12, "pressure": 0.35,                              # pull toward the centre, area restoring
			"poke": 900, "pokeEvery": 2.8,                                # the impulse and the idle poke timer
			"label": "neighbour links + spokes + pressure ∝ A₀/A" },
		"rhyme": { "name": "Jumbo", "hint": "half again as big with a quarter of the spoke pull and less pressure — a waterbed that ripples for seconds",
			"dials": { "r": 0.21, "spoke": 0.03, "pressure": 0.15 } } },
	{ "id": "avalanche", "letter": "A", "name": "Avalanche",
		"hint": "boulders on Normals' hill: a = g·sin θ along the tangent, Motor's ω = v ÷ r, bumps bounce — press to drop one",
		"dials": { "g": 2.0, "e": 0.35, "mu": 0.4, "count": 5,                       # gravity ×H, bounce, rolling friction, boulders
			"top": 0.28, "bottom": 0.72,                                   # the slope's ends, ×H at x = 0 and x = W
			"bumps": [[0.04, 0.03, 0], [0.09, 0.015, 1.3]],              # sines on the slope: frequency, amp ×H, phase
			"rMin": 0.03, "rMax": 0.06,                                    # boulder radii ×H
			"label": "on the slope: a = g·sin θ · ω = v ÷ r" },
		"rhyme": { "name": "Alpine", "hint": "a slope twice as steep and twice the restitution — the same rocks leap where they used to roll",
			"dials": { "top": 0.12, "bottom": 0.88, "e": 0.75 } } },
	{ "id": "kite", "letter": "K", "name": "Kite",
		"hint": "Rope's string, lift = wind² · sin(angle of attack), a follow-chain tail — press to gust from your click",
		"dials": { "n": 9, "seg": 0.06, "rounds": 6, "g": 1.6, "damp": 0.99,           # string links, link ×H, passes, the kite's gravity ×H
			"wind": 0.5, "gustiness": 0.35, "lift": 40, "bridle": 0.55,       # wind ×W/s, noise speed, lift gain, face tilt (rad)
			"gust": 1.2, "tail": 7,                                        # press gust ×W/s, tail links
			"label": "F = k·|w|²·sin α along the face normal" },
		"rhyme": { "name": "Kestrel", "hint": "a stronger, steadier wind on a longer string — it hangs high and hardly stirs, like a hovering hawk",
			"dials": { "wind": 0.85, "gustiness": 0.06, "seg": 0.08 } } },
	{ "id": "newton", "letter": "N", "name": "Newton",
		"hint": "five Pendulums; bobs that touch and approach swap velocity, Knock's impulse at e ≈ 1 — press to lift a ball",
		"dials": { "n": 5, "g": 3.0, "L": 0.45, "r": 0.05, "e": 0.98, "damp": 0.12,      # bobs, gravity ×H, string ×H, bob ×H, restitution, air
			"lift": 1.1, "every": 7,                                       # the lift angle (rad) and the idle re-lift timer
			"label": "touch + approach → swap v · e = 0.98" },
		"rhyme": { "name": "Nougat", "hint": "soft bobs: half the restitution and four times the air drag — the clack becomes a squelch and the row swings together",
			"dials": { "e": 0.45, "damp": 0.5, "lift": 0.8, "label": "touch + approach → blend v · e = 0.45" } } },
	{ "id": "pinball", "letter": "P", "name": "Pinball",
		"hint": "gravity, Xmarks' reflection off two turning flippers plus their tip speed, Knock's bumpers — press to flip",
		"dials": { "g": 1.6, "e": 0.6, "bump": 1.4, "r": 0.03,                       # gravity ×H, wall bounce, bumper kick ×H/s, ball ×H
			"flipLen": 0.17, "rest": 0.5, "swing": 1.05, "flipSpeed": 14, "hold": 0.25,   # flippers: ×W, rest angle, travel, rad/s, seconds up
			"bumpers": [[0.32, 0.3, 0.05], [0.62, 0.22, 0.05], [0.5, 0.46, 0.04]],  # x ×W, y ×H, radius ×H
			"label": "v − (1+e)(v·n)n + the flipper's tip speed" },
		"rhyme": { "name": "Pachinko", "hint": "a lighter, bouncier ball and bumpers with twice the kick — it lives up among the bumpers and rarely comes down",
			"dials": { "g": 0.9, "e": 0.9, "bump": 2.6 } } },
	{ "id": "yoyo", "letter": "Y", "name": "Yoyo",
		"hint": "free fall until the string is taut, then Rope's constraint; Motor's ω = v ÷ r, sleep, reel — press to throw",
		"dials": { "len": 0.5, "r": 0.045, "g": 2.4, "throw": 0.9, "damp": 0.995,       # string ×H, disc ×H, gravity ×H, throw ×H/s
			"sleep": 2.2, "sleepDrag": 0.35, "reel": 0.5, "wait": 0.8,           # seconds asleep, spin decay, reel ×H/s, seconds held
			"flick": 0.3,                                                  # a sideways flick at the throw ×H/s
			"bob": 0.03, "bobRate": 2.2,                                     # the hand rides Hover's sine
			"label": "fall → taut: |p − h| ≤ L · ω = v ÷ r · sleep" },
		"rhyme": { "name": "Yonder", "hint": "a third of the gravity, twice the nap and half the reel — it drops like a feather and dozes at the bottom",
			"dials": { "g": 0.9, "sleep": 4.5, "reel": 0.25 } } },
]

## The web kit's `len(...) || 1`: a zero length becomes 1 so divisions stay safe.
static func _or1(x: float) -> float:
	return x if x != 0.0 else 1.0

## The web label's "right" alignment — Kit.label only knows left and centre.
static func _label_right(n: CanvasItem, txt: String, p: Vector2, col: Color) -> void:
	var f := ThemeDB.fallback_font
	var x := p.x - f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	n.draw_string(f, Vector2(x, p.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)

## A verlet point: where it is, and where it was.
static func _pt(x: float, y: float) -> Dictionary:
	return { "p": Vector2(x, y), "pp": Vector2(x, y) }

## Knock's crate: four verlet points, four edges and two diagonals.
static func _box(cx: float, cy: float, s: float) -> Dictionary:
	var p := [_pt(cx - s, cy - s), _pt(cx + s, cy - s), _pt(cx + s, cy + s), _pt(cx - s, cy + s)]
	var c := []
	for pair in [[0, 1], [1, 2], [2, 3], [3, 0], [0, 2], [1, 3]]:   # edges + the two
		var rest: float = (p[pair[0]].p - p[pair[1]].p as Vector2).length()   # diagonals =
		c.append([pair[0], pair[1], rest])                                    # the rigidity
	return { "p": p, "c": c }

## The ray-plane intersection, in 2D clothing (a wall is a line segment):
## one denominator test per wall answers "does the beam cross it, and how
## far along?" — keep the NEAREST hit, with the wall's normal facing the beam.
static func _cast(segs: Array, from: Vector2, dir: Vector2) -> Dictionary:
	var best := {}
	for s in segs:
		var sv: Vector2 = s[1] - s[0]
		var den := dir.x * sv.y - dir.y * sv.x           # parallel beams never land
		if absf(den) < 1e-9:
			continue
		var tt: float = ((s[0].x - from.x) * sv.y - (s[0].y - from.y) * sv.x) / den   # distance along the ray
		var ss: float = ((s[0].x - from.x) * dir.y - (s[0].y - from.y) * dir.x) / den # 0..1 along the wall
		if tt > 0.5 and ss >= 0.0 and ss <= 1.0 and (best.is_empty() or tt < best.t):
			var nrm := Vector2(-sv.y, sv.x)              # the wall, turned 90°
			nrm /= _or1(nrm.length())
			if nrm.dot(dir) > 0.0:
				nrm = -nrm                               # face the beam
			best = { "t": tt, "p": from + dir * tt, "n": nrm }
	return best

# ---- Normals: terrain is a function y(x); its derivative m is the slope underfoot ----
static func _n_terra(b: Dictionary, x: float) -> float:
	var D: Dictionary = b.D
	var y: float = b.h * D.base
	for hl in D.hills:
		y -= sin(x * float(hl[0]) + float(hl[2])) * b.h * float(hl[1])
	return y

static func _n_slope(b: Dictionary, x: float) -> float:   # the derivative, by hand
	var D: Dictionary = b.D
	var m := 0.0
	for hl in D.hills:
		m -= cos(x * float(hl[0]) + float(hl[2])) * b.h * float(hl[1]) * float(hl[0])
	return m

# ---- Avalanche: Normals' hill, tilted, with bumps ----
static func _a_terra(b: Dictionary, x: float) -> float:
	var D: Dictionary = b.D
	var y: float = b.h * (D.top + (D.bottom - D.top) * x / b.w)
	for bp in D.bumps:
		y -= sin(x * float(bp[0]) + float(bp[2])) * b.h * float(bp[1])
	return y

static func _a_slope(b: Dictionary, x: float) -> float:   # the derivative, by hand
	var D: Dictionary = b.D
	var m: float = b.h * (D.bottom - D.top) / b.w
	for bp in D.bumps:
		m -= cos(x * float(bp[0]) + float(bp[2])) * b.h * float(bp[1]) * float(bp[0])
	return m

static func _spawn_rock(b: Dictionary, x: float, y: float, r: float) -> void:
	var shape := []
	for _k in 6:
		shape.append(randf_range(0.8, 1.1))              # a lumpy hexagon
	b.rocks.append({ "p": Vector2(x, y), "v": Vector2.ZERO, "r": r, "a": randf_range(0.0, TAU), "w": 0.0, "on": false, "shape": shape, "nrm": Vector2.UP })

# ---- Knock: the shockwave touches nothing but velocity ----
static func _shock(b: Dictionary, at: Vector2, power: float) -> void:
	b.rings.append({ "p": at, "r": 4.0, "a": 1.0 })
	for bx in b.boxes:
		for p in bx.p:
			var d: Vector2 = p.p - at
			var l := d.length() + 30.0
			p.pp -= d / l * (power / l)                  # the impulse: rewrite the past
			p.pp.y += power / l * 0.5                    # plus a hop (up = smaller y)

# ---- Grapple: fire the hook along Xmarks' ray ----
static func _fire(b: Dictionary, tgt: Vector2) -> void:
	var p: Vector2 = b.p
	var d: Vector2 = tgt - p
	var dl := _or1(d.length())
	var hit := _cast(b.segs, p, d / dl)
	if hit.is_empty():                                   # hooks need something to bite
		b.miss = 0.5
		b.miss_at = tgt
		return
	b.hooked = true
	b.anchor = hit.p
	b.L = hit.t
	b.timer = 0.0
	b.throwK = 0.0

# ---- Ninja: the wall-jump ----
static func _jump(b: Dictionary, dir: int) -> void:      # dir = +1 kicks to the right
	var D: Dictionary = b.D
	var G: float = b.h * D.g
	b.v = Vector2(dir * b.w * D.kick, -sqrt(2.0 * G * b.h * D.jumpH))   # v₀ = √(2gh): the apex is chosen, not found
	b.onWall = 0
	b.wallT = 0.0
	b.buffered = false
	b.jp = b.p
	b.flash = 0.5

# ---- Jelly: the shoelace area, the centroid, the poke ----
static func _j_area(b: Dictionary) -> float:             # the shoelace formula
	var pts: Array = b.pts
	var nn := pts.size()
	var s := 0.0
	for i in nn:
		var a: Vector2 = pts[i].p
		var c: Vector2 = pts[(i + 1) % nn].p
		s += a.x * c.y - c.x * a.y
	return absf(s) / 2.0

static func _j_centroid(b: Dictionary) -> Vector2:
	var pts: Array = b.pts
	var c := Vector2.ZERO
	for p in pts:
		c += p.p as Vector2
	return c / pts.size()

static func _j_poke(b: Dictionary, at: Vector2) -> void:
	var D: Dictionary = b.D
	b.flash = 0.35
	b.fp = at
	for p in b.pts:                                      # Knock's impulse: edit the past
		var d: Vector2 = p.p - at
		var dl := d.length() + 16.0
		p.pp -= d / dl * (D.poke / dl)

# ---- Newton: pivots one diameter apart; lift an outer ball plus everything between it and the edge ----
static func _px(b: Dictionary, i: int) -> float:
	var D: Dictionary = b.D
	var nn := int(D.n)
	return b.w / 2.0 + (i - (nn - 1) / 2.0) * 2.0 * b.h * D.r

static func _lift_ball(b: Dictionary, i: int) -> void:
	var D: Dictionary = b.D
	var nn := int(D.n)
	if i >= nn / 2.0:
		for j in range(i, nn):
			b.th[j] = float(D.lift)
			b.om[j] = 0.0
	else:
		for j in range(0, i + 1):
			b.th[j] = -float(D.lift)
			b.om[j] = 0.0
	b.idle = 0.0

# ---- Pinball: a new ball from the top-right ----
static func _spawn_ball(b: Dictionary) -> void:
	b.ball = Vector2(b.w * 0.85, b.h * 0.12)
	b.bv = Vector2(randf_range(-b.w * 0.12, b.w * 0.04), 0.0)

# ---- Yoyo: the throw ----
static func _throw(b: Dictionary) -> void:
	var D: Dictionary = b.D
	b.state = "fall"
	b.L = b.h * D.len
	b.pp.y = b.p.y - b.h * D.throw * b.lastDt
	b.pp.x = b.p.x - b.side * b.h * D.flick * b.lastDt
	b.side = -b.side
	b.timer = 0.0

static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	match b.id:
		"ragdoll":
			# eleven points, eleven promises. each point remembers only where it is
			# and where it WAS — moving it is "keep drifting the way you were, plus
			# gravity" (verlet integration). then every stick between two points
			# restores its resting length, half from each end, eight times over.
			# out of nothing but that: elbows, slumping, swing. one hand is pinned
			# to a trolley gliding overhead.
			var U: float = b.h * D.unit
			var cx: float = b.w / 2.0
			b.P = {
				"head": _pt(cx, b.h * 0.2), "chest": _pt(cx, b.h * 0.2 + U), "hip": _pt(cx, b.h * 0.2 + U * 2.3),
				"elbL": _pt(cx - U, b.h * 0.24), "handL": _pt(cx - U * 2, b.h * 0.28),
				"elbR": _pt(cx + U, b.h * 0.24), "handR": _pt(cx + U * 2, b.h * 0.28),
				"kneeL": _pt(cx - U * 0.5, b.h * 0.2 + U * 3.4), "footL": _pt(cx - U * 0.6, b.h * 0.2 + U * 4.5),
				"kneeR": _pt(cx + U * 0.5, b.h * 0.2 + U * 3.4), "footR": _pt(cx + U * 0.6, b.h * 0.2 + U * 4.5),
			}
			b.C = [                                      # eleven promises
				["head", "chest", U], ["chest", "hip", U * 1.3], ["head", "hip", U * 2.2],
				["chest", "elbL", U], ["elbL", "handL", U], ["chest", "elbR", U], ["elbR", "handR", U],
				["hip", "kneeL", U * 1.1], ["kneeL", "footL", U * 1.1],
				["hip", "kneeR", U * 1.1], ["kneeR", "footR", U * 1.1],
			]
			b.anchor = Vector2(b.w / 2.0, b.h * 0.12)
		"knock":
			# a FORCE nags a body every frame; an IMPULSE is one hard shove — an
			# instant change of velocity — which is how games spell explosions,
			# hits, and knockback. each crate is four verlet points, four edges and
			# two diagonals (the diagonals are what make it rigid). the shockwave
			# touches nothing but velocity: closer crates inherit more of it.
			var sizes: Array = D.sizes
			b.boxes = [_box(b.w * 0.25, b.gy - float(sizes[0]) - 1.0, float(sizes[0])),
				_box(b.w * 0.52, b.gy - float(sizes[1]) - 1.0, float(sizes[1])),
				_box(b.w * 0.78, b.gy - float(sizes[2]) - 1.0, float(sizes[2]))]
			b.rings = []
			b.gust_t = 2.5
		"xmarks":
			# the ray-plane intersection, in 2D clothing (a wall is a line segment).
			# one denominator test per wall answers "does the beam cross it, and how
			# far along?" — keep the NEAREST hit. the wall's NORMAL (its direction
			# turned 90°) then powers the classic reflection  v − 2(v·n)n, which is
			# the same dot-product maths lasers, bullets, and bank shots all share.
			b.segs = [[Vector2(8, 8), Vector2(b.w - 8, 8)], [Vector2(b.w - 8, 8), Vector2(b.w - 8, b.h - 8)],
				[Vector2(b.w - 8, b.h - 8), Vector2(8, b.h - 8)], [Vector2(8, b.h - 8), Vector2(8, 8)]]
			for wl in D.walls:
				b.segs.append([Vector2(b.w * float(wl[0]), b.h * float(wl[1])), Vector2(b.w * float(wl[2]), b.h * float(wl[3]))])
			b.o = Vector2(b.w * 0.24, b.h * 0.68)
			b.aim = 0.0
			b.sticky = 0.0
			b.want = 0.0
		"normals":
			# terrain is a function y(x); its DERIVATIVE m is the slope underfoot.
			# the tangent (1, m) points along the hill, and turning it 90° gives
			# the NORMAL — the "straight up off the surface" direction that aligns
			# wheels, feet, and gun turrets to the ground they stand on. (in 3D the
			# 90° turn is done by the cross product of two surface directions.)
			b.wx = b.w * 0.2
			b.dir = 1.0
		"gait":
			# procedural walking, the whole recipe:
			#   1. each foot owns a HOME under its hip, pushed ahead by velocity;
			#   2. when home drifts past a THRESHOLD from where the foot is planted
			#      — and the other foot is down — the foot steps;
			#   3. the step flies a PARABOLIC arc (sin(k·π) lift) to a predicted
			#      landing spot, faster when the walk is faster (stride timing);
			#   4. the BODY is carried BY the feet: its height bobs with the step,
			#      it leans into speed, and its hips shift over the planted foot
			#      (centre-of-gravity balancing). legs are two-bone Law-of-Cosines
			#      IK from card I. nothing here is animated by hand.
			b.bx = b.w * 0.3
			b.vx = 0.0
			b.tx = b.w * 0.7
			b.auto_t = 0.0
			b.feet = [Vector2(b.bx - D.stance, b.gy), Vector2(b.bx + D.stance, b.gy)]
			b.stepping = -1
			b.from = 0.0
			b.to = 0.0
			b.k = 0.0
			b.dur = 0.3
		"grapple":
			# a grappling hook is three cards in a trench coat. FIRE: Xmarks' segment
			# test finds where the line from the mote to the click first meets the
			# ceiling or a ledge. HANG: the mote is one verlet point with a single
			# ROPE CONSTRAINT — whenever it drifts further than L from the anchor it
			# is pulled back to exactly L (a rope only ever pulls; slack costs
			# nothing). a winch shortens L, which is what turns a hang into a swing.
			# RELEASE: forget the anchor; the point keeps its velocity and flies
			# Jump's parabola for free. the faint circle is the swing, made visible.
			var R := 8.0
			var cy: float = b.h * D.ceiling
			b.segs = [[Vector2(0, cy), Vector2(b.w, cy)]]
			for l in D.ledges:
				b.segs.append([Vector2(b.w * float(l[0]), b.h * float(l[1])), Vector2(b.w * float(l[2]), b.h * float(l[3]))])
			b.p = Vector2(b.w * 0.3, b.gy - R)
			b.pp = b.p
			b.hooked = false
			b.anchor = Vector2.ZERO
			b.L = 0.0
			b.timer = 0.0
			b.throwK = 1.0
			b.miss = 0.0
			b.miss_at = Vector2.ZERO
		"rope":
			# Ragdoll's recipe, one link at a time. every point is verlet (where it is,
			# where it was); every link is a DISTANCE CONSTRAINT: measure the gap,
			# compare it with the rest length, move both ends to fix it. one pass
			# leaves the error smeared down the chain, so the solver runs eight ROUNDS
			# — each one halves what is left. the pin has infinite mass (it never
			# moves); the bob has mass 3, so it takes a quarter of each correction and
			# its light neighbour three quarters. the wind is one noise() call per link.
			var nn := int(D.n)
			var seg: float = b.h * D.seg
			b.pts = []
			b.inv = []
			for i in nn:
				b.pts.append(_pt(b.w / 2.0, b.h * 0.06 + i * seg))
				b.inv.append(0.0 if i == 0 else (1.0 / D.weight if i == nn - 1 else 1.0))   # inverse mass: 0 = pinned
			b.held = -1
			b.hold_at = Vector2.ZERO
			b.hold = 0.0
		"ninja":
			# the WALL-JUMP, the platformer's second verb. touching a wall while
			# falling caps the fall (a WALL-SLIDE: most of gravity cancelled by
			# friction); a jump off the wall reuses Jump's v₀ = √(2gh) upward and adds
			# a fixed horizontal KICK away from the wall — you cannot steer it, and
			# that is the feel. a press in mid-air is remembered until the next wall
			# (a JUMP BUFFER: input taken early, spent when it becomes legal). the
			# camera follows the climb, so the shaft is endless.
			var R := 8.0
			var lx: float = b.w * D.left
			b.p = Vector2(lx + R, b.gy - R * 3.0)
			b.v = Vector2.ZERO
			b.onWall = -1
			b.wallT = 0.0
			b.buffered = false
			b.scroll = 0.0
			b.floorY = b.gy
			b.jp = Vector2.ZERO
			b.flash = 0.0
			b.trail = []
		"jelly":
			# a SOFT BODY is a ragdoll with no bones: a ring of verlet points and three
			# gentle promises. neighbours keep their distance (the skin); every point
			# is softly pulled toward the centroid (the SPOKES — soft, so the shape may
			# deform); and PRESSURE: measure the polygon's AREA with the shoelace
			# formula, and when it is smaller than at rest push every point outward —
			# that is what makes a poke on one side bulge out on the other. all three
			# are position corrections, never forces, so nothing can explode.
			var R: float = b.h * D.r
			var nn := int(D.n)
			b.pts = []
			for i in nn:
				var a: float = i / float(nn) * TAU
				b.pts.append(_pt(b.w / 2.0 + cos(a) * R, b.gy - R - 2.0 + sin(a) * R))
			b.rest = (b.pts[1].p - b.pts[0].p as Vector2).length()   # the chord between neighbours
			b.A0 = _j_area(b)
			b.c = _j_centroid(b)
			b.pokeT = 1.4
			b.flash = 0.0
			b.fp = Vector2.ZERO
		"avalanche":
			# Normals' hill, tilted, with bodies on it. each boulder carries a real
			# velocity and gravity; when it touches the surface, the NORMAL splits
			# that velocity in two: the part INTO the hill is reflected (times e —
			# mostly lost), the part ALONG the hill is kept minus a little friction.
			# gravity then supplies g·sin θ along the tangent every frame — the
			# rolling acceleration, straight from the physics classroom. the spin is
			# Motor's rule ω = v ÷ r: a wide boulder turns slowly. crests are convex,
			# so a fast rock leaves the ground there — the bounces are not scripted.
			var count := int(D.count)
			b.rocks = []
			b.theta = 0.0
			for i in count:
				var r: float = b.h * randf_range(D.rMin, D.rMax)
				var x: float = b.w * (0.05 + i * 0.8 / count)
				_spawn_rock(b, x, _a_terra(b, x) - r - b.h * randf_range(0.0, 0.15), r)
		"kite":
			# a flat plate in a wind feels one force, along its own NORMAL, of size
			# k·|w|²·sin α — α being the ANGLE OF ATTACK between the apparent wind
			# (the wind minus the kite's own velocity) and the plate. the part of
			# that force across the wind is LIFT, the part along it is DRAG: one
			# formula, both words. the BRIDLE tilts the plate a fixed angle off the
			# string, so the string (Rope's verlet chain, pinned in the flyer's
			# hand) always presents the face to the wind — and the string's pull is
			# what holds it up there; let go and it would just blow away. the tail
			# is Tentacle's follow-chain: it only remembers where the kite has been.
			var seg: float = b.h * D.seg
			var nn := int(D.n)
			var hand := Vector2(b.w * 0.22, b.gy - 14.0)     # the hand
			b.hand = hand
			b.pts = []
			for i in nn:
				b.pts.append(_pt(hand.x + i * seg * 0.7, hand.y - i * seg * 0.7))
			b.tail = []
			for i in int(D.tail):
				b.tail.append(Vector2((b.pts[nn - 1].p as Vector2).x - i * 6.0, (b.pts[nn - 1].p as Vector2).y))
			b.gdir = Vector2.ZERO
			b.gustT = 0.0
			b.alpha = 0.0
			b.F = 0.0
			b.nrm = Vector2(0, -1)
			b.wind = Vector2.ZERO
		"newton":
			# five Pendulums that can touch. each integrates α = −(g/L)·sin θ on its
			# own; the cradle is one extra rule between neighbours: if two bobs
			# OVERLAP and are APPROACHING, exchange their velocities (Knock's impulse,
			# written out for equal masses and a RESTITUTION e):
			#   v₁' = ((1−e)·v₁ + (1+e)·v₂) / 2     v₂' = ((1+e)·v₁ + (1−e)·v₂) / 2
			# at e = 1 that is a clean swap, which is why one ball in sends exactly
			# one ball out: a chain of swaps carries the speed through the middle
			# bobs in a single frame. sub-steps keep any bob from tunnelling past
			# its neighbour between two checks.
			var nn := int(D.n)
			b.th = []
			b.om = []
			b.flash = []
			for _i in nn:
				b.th.append(0.0)
				b.om.append(0.0)
				b.flash.append(0.0)
			b.idle = 0.0
			_lift_ball(b, 0)
		"pinball":
			# Xmarks' reflection with a moving mirror. a FLIPPER is a rotating
			# segment: the ball finds the CLOSEST POINT on it, and if it is inside,
			# the normal n runs from that point to the ball. the trick that makes
			# flippers hit: reflect the ball's velocity RELATIVE to the surface (v
			# minus the flipper's own speed at the contact, ω × arm) and add the
			# surface speed back — a tip moving at 14 rad/s on a long arm flings
			# hard. bumpers are Knock: a fixed impulse away along the normal. the
			# frame is sub-stepped so a fast ball cannot tunnel through a flipper.
			var left: float = b.w * 0.08
			var right: float = b.w * 0.92
			var fy: float = b.gy - b.h * 0.16
			b.segs = [                                   # static rails + two flippers (w = angular speed)
				{ "p": Vector2(left, b.gy - b.h * 0.3), "tip": Vector2(b.w * 0.3, fy), "w": 0.0, "s": 0.0, "a": 0.0 },
				{ "p": Vector2(right, b.gy - b.h * 0.3), "tip": Vector2(b.w * 0.7, fy), "w": 0.0, "s": 0.0, "a": 0.0 },
				{ "p": Vector2(b.w * 0.3, fy), "tip": Vector2.ZERO, "w": 0.0, "s": 1.0, "a": float(D.rest) },
				{ "p": Vector2(b.w * 0.7, fy), "tip": Vector2.ZERO, "w": 0.0, "s": -1.0, "a": float(D.rest) },
			]
			b.bumps = []
			for bp in D.bumpers:
				b.bumps.append({ "p": Vector2(b.w * float(bp[0]), b.h * float(bp[1])), "r": b.h * float(bp[2]), "hit": 0.0 })
			b.ball = Vector2(b.w * 0.85, b.h * 0.12)
			b.bv = Vector2.ZERO
			b.holdT = -1.0
			b.nT = 0.0
			b.nrm = Vector2.ZERO
			b.hp = Vector2.ZERO
			b.drains = 0
		"yoyo":
			# a yo-yo is Rope's constraint with a length that changes on a schedule.
			# THROW: the disc leaves the hand with a downward velocity and L opens to
			# the full string — free fall, the speed becoming spin at ω = v ÷ r (the
			# string unwinding off the axle: Motor's rule, read backwards). TAUT: the
			# moment |p − h| would pass L the rope constraint catches it — a jolt,
			# then a hang. SLEEP: it spins at the bottom, losing ω slowly, swinging
			# under the hand. REEL: L shrinks at a steady rate and the disc climbs
			# (the axle winding the string back in). the hand bobs on Hover's sine.
			var r: float = b.h * D.r
			b.hy = b.h * 0.12
			b.p = Vector2(b.w / 2.0, b.hy + r)
			b.pp = b.p
			b.L = 0.0
			b.state = "held"
			b.timer = 0.0
			b.spin = 0.0
			b.om = 0.0
			b.lastDt = 1.0 / 60.0
			b.jolt = 0.0
			b.side = 1.0

static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	match b.id:
		"ragdoll":
			for key in b.P:                              # an impulse, verlet-style:
				var p: Dictionary = b.P[key]             # to change a velocity, you
				var d: Vector2 = p.p - pos               # edit the PAST position
				var l := d.length() + 20.0
				p.pp -= d / l * (D.shove / l)
		"knock":
			_shock(b, pos, float(D.press))
		"xmarks":
			b.want = (pos - b.o as Vector2).angle()
			b.sticky = float(D.sticky)
		"normals":
			b.dir = -b.dir
		"gait":
			b.tx = clampf(pos.x, b.w * 0.08, b.w * 0.92)
			b.auto_t = -8.0
		"grapple":
			if b.hooked:
				b.hooked = false
				b.timer = 0.0
			else:
				_fire(b, pos)
		"rope":
			var nn := int(D.n)
			var best := 1
			var bd := 1e9
			for i in range(1, nn):
				var d: float = (b.pts[i].p - pos as Vector2).length()
				if d < bd:
					bd = d
					best = i
			b.held = best
			b.hold_at = pos
			b.hold = 0.12
		"ninja":
			if b.onWall != 0:
				_jump(b, -b.onWall)
			else:
				b.buffered = true
		"jelly":
			_j_poke(b, pos)
		"avalanche":
			var r: float = b.h * randf_range(D.rMin, D.rMax)
			_spawn_rock(b, pos.x, minf(pos.y, _a_terra(b, pos.x) - r), r)
			if b.rocks.size() > 9:
				b.rocks.pop_front()
		"kite":
			var nn := int(D.n)
			var k: Vector2 = b.pts[nn - 1].p
			var d: Vector2 = k - pos
			var dl := _or1(d.length())
			b.gdir = d / dl                              # a gust blowing from the click toward the kite
			b.gustT = 1.0
		"newton":
			var nn := int(D.n)
			var L: float = b.h * D.L
			var best := 0
			var bd := 1e9
			for i in nn:
				var d: float = absf(_px(b, i) + sin(b.th[i]) * L - pos.x)
				if d < bd:
					bd = d
					best = i
			_lift_ball(b, best)
		"pinball":
			b.holdT = float(D.hold)
		"yoyo":
			if b.state == "held":
				_throw(b)
			elif b.state == "sleep":
				b.state = "reel"
				b.timer = 0.0

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var D: Dictionary = b.D
	var sdt := maxf(dt, 1e-6)                            # the web divides by dt; a zero frame must not make infinities
	match b.id:
		"ragdoll":
			var G: float = b.h * D.g
			var anchor := Vector2(b.w / 2.0 + sin(t * D.trolley) * b.w * D.swing, b.h * 0.12)   # the trolley
			for key in b.P:
				var p: Dictionary = b.P[key]
				var v: Vector2 = (p.p - p.pp) * D.damp
				p.pp = p.p
				p.p += v + Vector2(0, G * dt * dt)
			for _it in int(D.rounds):
				for c in b.C:
					var pa: Dictionary = b.P[c[0]]
					var pb: Dictionary = b.P[c[1]]
					var d: Vector2 = pb.p - pa.p
					var l := _or1(d.length())
					var adjust: float = (l - c[2]) / l / 2.0   # half the error to each end
					pa.p += d * adjust
					pb.p -= d * adjust
				b.P.handR.p = anchor                     # the pin wins every round
				for key in b.P:
					var p: Dictionary = b.P[key]
					if p.p.y > b.gy - 2.0:               # floor + friction
						p.p.y = b.gy - 2.0
						p.p.x -= (p.p.x - p.pp.x) * 0.4
					p.p.y = maxf(p.p.y, 4.0)
					p.p.x = clampf(p.p.x, 4.0, b.w - 4.0)
			b.anchor = anchor
		"knock":
			b.gust_t -= dt
			if b.gust_t <= 0.0:
				b.gust_t = randf_range(D.gustMin, D.gustMax)
				_shock(b, Vector2(randf_range(0, b.w), b.gy - randf_range(0, 30)), float(D.gust))
			var G: float = b.h * D.g
			for bx in b.boxes:
				for p in bx.p:
					var v: Vector2 = (p.p - p.pp) * D.damp
					p.pp = p.p
					p.p += v + Vector2(0, G * dt * dt)
				for _it in int(D.rounds):
					for c in bx.c:
						var pa: Dictionary = bx.p[c[0]]
						var pb: Dictionary = bx.p[c[1]]
						var d: Vector2 = pb.p - pa.p
						var l := _or1(d.length())
						var adjust: float = (l - c[2]) / l / 2.0
						pa.p += d * adjust
						pb.p -= d * adjust
					for p in bx.p:
						if p.p.y > b.gy - 1.0:
							p.p.y = b.gy - 1.0
							p.p.x -= (p.p.x - p.pp.x) * D.friction
						p.p.y = maxf(p.p.y, 4.0)
						p.p.x = clampf(p.p.x, 4.0, b.w - 4.0)
			for i in range(b.rings.size() - 1, -1, -1):
				var r: Dictionary = b.rings[i]
				r.r += 260.0 * dt
				r.a -= 2.2 * dt
				if r.a <= 0.0:
					b.rings.remove_at(i)
		"xmarks":
			b.sticky -= dt
			if b.sticky <= 0.0:
				b.want = t * D.sweep                     # the idle sweep
			b.aim += wrapf(b.want - b.aim, -PI, PI) * minf(1.0, D.track * dt)
		"normals":
			b.wx += b.dir * D.speed * dt
			if b.wx > b.w * 0.94:
				b.dir = -1.0
			if b.wx < b.w * 0.06:
				b.dir = 1.0
		"gait":
			var THRESH: float = b.w * D.thresh
			var MAXV: float = b.w * D.maxv
			b.auto_t += dt
			if b.auto_t > D.retarget:
				b.auto_t = 0.0
				b.tx = randf_range(b.w * 0.1, b.w * 0.9)
			var want := clampf((b.tx - b.bx) * 2.0, -MAXV, MAXV)
			b.vx += (want - b.vx) * minf(1.0, 5.0 * dt)
			b.bx += b.vx * dt
			for i in 2:
				var home: float = b.bx + (D.stance if i == 1 else -D.stance) + b.vx * 0.22   # led by velocity, not dragged
				if b.stepping < 0 and absf(home - (b.feet[i] as Vector2).x) > THRESH:
					b.stepping = i                       # step past the threshold —
					b.from = (b.feet[i] as Vector2).x    # but only one foot at a time
					b.k = 0.0
					b.to = home + b.vx * 0.1             # land a little ahead again
					b.dur = clampf(D.stepMax - absf(b.vx) / MAXV * (D.stepMax - D.stepMin), D.stepMin, D.stepMax)
			if b.stepping >= 0:                          # faster walk, quicker steps — stride timing
				b.k += dt / b.dur
				var i: int = b.stepping
				var f: Vector2 = b.feet[i]
				f.x = b.from + (b.to - b.from) * smoothstep(0.0, 1.0, b.k)
				f.y = b.gy - sin(clampf(b.k, 0.0, 1.0) * PI) * (D.lift + absf(b.vx) * 0.05)   # the arc
				if b.k >= 1.0:
					f.y = b.gy
					b.stepping = -1
				b.feet[i] = f
		"grapple":
			var G: float = b.h * D.g
			var R := 8.0
			var cy: float = b.h * D.ceiling
			b.timer += dt
			b.miss = maxf(0.0, b.miss - dt)
			b.throwK = minf(1.0, b.throwK + dt * 6.0)
			var cap: float = b.h * 0.06                  # px per frame — nothing tunnels
			var p: Vector2 = b.p
			var pp: Vector2 = b.pp
			var v := Vector2(clampf((p.x - pp.x) * D.damp, -cap, cap), clampf((p.y - pp.y) * D.damp, -cap, cap))
			pp = p
			p += v + Vector2(0, G * dt * dt)
			if b.hooked:
				b.L = maxf(b.h * D.minRope, b.L - b.h * D.reel * dt)   # the winch
				var a: Vector2 = b.anchor
				var d: Vector2 = p - a
				var dl := _or1(d.length())
				if dl > b.L:
					p = a + d / dl * b.L                 # ← the rope constraint
				if b.timer > D.swingTime:
					b.hooked = false
					b.timer = 0.0
			var on_floor := false
			if p.y > b.gy - R:
				var vin := p.y - pp.y
				p.y = b.gy - R
				pp.y = p.y + vin * 0.3
				pp.x = p.x - (p.x - pp.x) * 0.5
				on_floor = true
			var segs: Array = b.segs
			for i in range(1, segs.size()):              # ledges are one-way: land from above
				var s: Array = segs[i]
				var s0: Vector2 = s[0]
				var s1: Vector2 = s[1]
				if p.x < minf(s0.x, s1.x) or p.x > maxf(s0.x, s1.x):
					continue
				var ly: float = s0.y + (s1.y - s0.y) * (p.x - s0.x) / (s1.x - s0.x)
				if pp.y <= ly - R + 0.5 and p.y > ly - R:
					var vin := p.y - pp.y
					p.y = ly - R
					pp.y = p.y + vin * 0.3
					pp.x = p.x - (p.x - pp.x) * 0.5
					on_floor = true
			if p.x < R:
				var vin := p.x - pp.x
				p.x = R
				pp.x = p.x + vin * 0.5
			if p.x > b.w - R:
				var vin := p.x - pp.x
				p.x = b.w - R
				pp.x = p.x + vin * 0.5
			if p.y < cy + R:
				var vin := p.y - pp.y
				p.y = cy + R
				pp.y = p.y + vin * 0.5
			b.p = p
			b.pp = pp
			if not b.hooked and on_floor and absf(p.y - pp.y) < 0.6 and b.timer > D.restTime:
				_fire(b, Vector2(clampf(p.x + randf_range(-b.w * 0.4, b.w * 0.4), b.w * 0.08, b.w * 0.92), cy))   # its own errand: hook the ceiling
		"rope":
			var nn := int(D.n)
			var seg: float = b.h * D.seg
			var G: float = b.h * D.g
			var pts: Array = b.pts
			var inv: Array = b.inv
			b.hold -= dt
			var cap: float = b.h * 0.05
			for i in range(1, nn):
				var p: Dictionary = pts[i]
				var v := Vector2(clampf((p.p.x - p.pp.x) * D.damp, -cap, cap), clampf((p.p.y - p.pp.y) * D.damp, -cap, cap))
				p.pp = p.p
				var wind: float = Kit.noise(t * D.windRate + i * 0.07) * b.h * D.wind   # a breeze with memory
				p.p += v + Vector2(wind * dt * dt, G * dt * dt)
			for _it in int(D.rounds):
				for i in nn - 1:
					var a: Dictionary = pts[i]
					var c: Dictionary = pts[i + 1]
					var d: Vector2 = c.p - a.p
					var dl := _or1(d.length())
					var err := (dl - seg) / dl
					var wa: float = inv[i]
					var wc: float = inv[i + 1]
					var wsum := _or1(wa + wc)
					a.p += d * err * wa / wsum           # the heavy end
					c.p -= d * err * wc / wsum           # moves less
				if b.held >= 0 and b.hold > 0.0:
					var p: Dictionary = pts[b.held]
					p.p = b.hold_at
					p.pp = b.hold_at
				for i in range(1, nn):
					var p: Dictionary = pts[i]
					if p.p.y > b.gy - 2.0:
						p.p.y = b.gy - 2.0
						p.p.x -= (p.p.x - p.pp.x) * 0.5
					p.p.x = clampf(p.p.x, 3.0, b.w - 3.0)
		"ninja":
			var G: float = b.h * D.g
			var R := 8.0
			var lx: float = b.w * D.left
			var rx: float = b.w * D.right
			var p: Vector2 = b.p
			var v: Vector2 = b.v
			if b.onWall != 0 and v.y > 0.0:
				v.y = minf(v.y + G * D.slideG * dt, b.h * D.slide)   # the slide: gravity, mostly cancelled
			else:
				v.y += G * dt
			p += v * dt
			if p.x <= lx + R:
				p.x = lx + R
				v.x = 0.0
				if b.onWall == 0:
					b.onWall = -1
					b.wallT = 0.0
			elif p.x >= rx - R:
				p.x = rx - R
				v.x = 0.0
				if b.onWall == 0:
					b.onWall = 1
					b.wallT = 0.0
			else:
				b.onWall = 0
			b.p = p
			b.v = v
			if b.onWall != 0:
				b.wallT += dt
				if b.buffered or b.wallT > D.cling:
					_jump(b, -b.onWall)
			if b.p.y > b.floorY - R:                     # the floor: leap for the far wall
				b.p.y = b.floorY - R
				_jump(b, 1 if b.p.x < b.w / 2.0 else -1)
			if b.p.y < b.h * 0.45:                       # the camera climbs with it
				var s: float = b.h * 0.45 - b.p.y
				b.p.y += s
				b.floorY += s
				b.scroll += s
				b.jp.y += s
				var trail: Array = b.trail
				for i in trail.size():
					trail[i] = (trail[i] as Vector2) + Vector2(0, s)
			b.flash = maxf(0.0, b.flash - dt)
			b.trail.append(b.p)
			if b.trail.size() > 40:
				b.trail.pop_front()
		"jelly":
			var R: float = b.h * D.r
			var G: float = b.h * D.g
			var nn := int(D.n)
			var pts: Array = b.pts
			var rest: float = b.rest
			var A0: float = b.A0
			b.pokeT -= dt
			if b.pokeT <= 0.0:                           # an idle finger, from above mostly
				b.pokeT = float(D.pokeEvery)
				var c0 := _j_centroid(b)
				var a: float = randf_range(-PI, 0.0)
				_j_poke(b, c0 + Vector2(cos(a), sin(a)) * R * 1.2)
			var cap: float = b.h * 0.05
			for p in pts:
				var v := Vector2(clampf((p.p.x - p.pp.x) * D.damp, -cap, cap), clampf((p.p.y - p.pp.y) * D.damp, -cap, cap))
				p.pp = p.p
				p.p += v + Vector2(0, G * dt * dt)
			var c := _j_centroid(b)
			for _it in int(D.rounds):
				for i in nn:                             # 1. the skin: distance constraints
					var a: Dictionary = pts[i]
					var q: Dictionary = pts[(i + 1) % nn]
					var d: Vector2 = q.p - a.p
					var dl := _or1(d.length())
					var adj := (dl - rest) / dl / 2.0
					a.p += d * adj
					q.p -= d * adj
				c = _j_centroid(b)
				for p in pts:                            # 2. the spokes: a soft pull to radius R
					var d: Vector2 = p.p - c
					var dl := _or1(d.length())
					var k: float = (dl - R) / dl * D.spoke
					p.p -= d * k
				var push: float = clampf(A0 / _or1(_j_area(b)) - 1.0, -0.5, 0.5) * D.pressure * R / D.rounds   # 3. pressure
				for p in pts:
					var d: Vector2 = p.p - c
					var dl := _or1(d.length())
					p.p += d / dl * push
				for p in pts:
					if p.p.y > b.gy - 2.0:
						p.p.y = b.gy - 2.0
						p.p.x -= (p.p.x - p.pp.x) * 0.5
					p.p.y = maxf(p.p.y, 4.0)
					p.p.x = clampf(p.p.x, 4.0, b.w - 4.0)
			b.c = c
			b.flash = maxf(0.0, b.flash - dt)
		"avalanche":
			var G: float = b.h * D.g
			b.theta = 0.0
			for rk in b.rocks:
				rk.v.y += G * dt
				rk.p += rk.v * dt
				var gy: float = _a_terra(b, rk.p.x)
				var m: float = _a_slope(b, rk.p.x)
				var tl := sqrt(1.0 + m * m)
				var tg := Vector2(1.0, m) / tl           # Normals' tangent (1, m)…
				var nm := Vector2(m, -1.0) / tl          # …and normal (m, −1), pointing up
				rk.on = false
				if rk.p.y > gy - rk.r:
					rk.p.y = gy - rk.r
					var vn: float = (rk.v as Vector2).dot(nm)   # speed INTO the hill (negative = inward)
					if vn < 0.0:
						rk.v -= (1.0 + D.e) * vn * nm    # reflect it, × e
					var vt: float = (rk.v as Vector2).dot(tg)   # speed ALONG the hill
					var f: float = maxf(0.0, 1.0 - D.mu * dt) - 1.0   # rolling friction, a small bite
					rk.v += tg * vt * f
					rk.w = vt / rk.r                     # ω = v ÷ r
					rk.on = true
					b.theta = atan(m)
				rk.nrm = nm
				var sp: float = (rk.v as Vector2).length()
				var cap: float = b.h * 3.0
				if sp > cap:
					rk.v *= cap / sp
				rk.a += rk.w * dt
				if rk.p.x > b.w + rk.r * 2.0 or rk.p.y > b.h + 40.0:   # off the bottom: back to the top
					rk.p = Vector2(-rk.r, _a_terra(b, 0.0) - rk.r - b.h * 0.12)
					rk.v = Vector2.ZERO
					rk.w = 0.0
		"kite":
			var nn := int(D.n)
			var seg: float = b.h * D.seg
			var G: float = b.h * D.g
			var hand: Vector2 = b.hand
			var pts: Array = b.pts
			var tail: Array = b.tail
			b.gustT = maxf(0.0, b.gustT - dt)
			var gdir: Vector2 = b.gdir
			var wx: float = b.w * D.wind * (1.0 + 0.25 * Kit.noise(t * D.gustiness)) + gdir.x * b.w * D.gust * b.gustT
			var wy: float = b.w * D.wind * 0.12 * Kit.noise(t * D.gustiness + 9.0) + gdir.y * b.w * D.gust * b.gustT
			var kite: Dictionary = pts[nn - 1]
			var kv: Vector2 = (kite.p - kite.pp as Vector2) / sdt   # the kite's own velocity, px/s
			var aw := Vector2(wx, wy) - kv                # the APPARENT wind
			var al := _or1(aw.length())
			var u: Vector2 = kite.p - hand               # the string, hand to kite
			u /= _or1(u.length())
			var cb := cos(D.bridle)
			var sb := sin(D.bridle)
			var nrm := Vector2(u.x * cb + u.y * sb, -u.x * sb + u.y * cb)   # the face normal: the string, tilted up by the bridle
			var sinA := aw.dot(nrm) / al                 # sin α = â · n
			b.alpha = asin(clampf(sinA, -1.0, 1.0))
			var F: float = D.lift * b.h * al * al * sinA / (b.w * b.w)   # k·|w|²·sin α, as an acceleration
			b.F = F
			b.nrm = nrm
			b.wind = Vector2(wx, wy)
			var cap: float = b.h * 0.05
			for i in range(1, nn):
				var p: Dictionary = pts[i]
				var last := i == nn - 1
				var v := Vector2(clampf((p.p.x - p.pp.x) * D.damp, -cap, cap), clampf((p.p.y - p.pp.y) * D.damp, -cap, cap))
				p.pp = p.p
				p.p += v + Vector2((F * nrm.x if last else wx * 0.1) * dt * dt,       # string links: a whisper of drag…
					(F * nrm.y + G if last else G * 0.06) * dt * dt)                  # …and almost no weight
			for _it in int(D.rounds):
				for i in nn - 1:                         # Rope's distance constraints
					var a: Dictionary = pts[i]
					var c: Dictionary = pts[i + 1]
					var d: Vector2 = c.p - a.p
					var dl := _or1(d.length())
					var err := (dl - seg) / dl
					if i == 0:
						c.p -= d * err
					else:
						a.p += d * err / 2.0
						c.p -= d * err / 2.0
				for i in range(1, nn):
					var p: Dictionary = pts[i]
					if p.p.y > b.gy - 3.0:
						p.p.y = b.gy - 3.0
						p.p.x -= (p.p.x - p.pp.x) * 0.5
					p.p.y = maxf(p.p.y, 4.0)
					p.p.x = clampf(p.p.x, 4.0, b.w - 4.0)
			tail[0] = kite.p
			for i in range(1, tail.size()):              # Tentacle's follow-chain, blown downwind
				var s: Vector2 = tail[i]
				var q: Vector2 = tail[i - 1]
				s.x += wx * 0.25 * dt
				s.y += (G * 0.15 + sin(t * 5.0 - i) * 20.0) * dt
				var a := (s - q).angle()
				tail[i] = q + Vector2(cos(a), sin(a)) * 6.0
		"newton":
			var nn := int(D.n)
			var r: float = b.h * D.r
			var L: float = b.h * D.L
			var G: float = b.h * D.g
			var th: Array = b.th
			var om: Array = b.om
			var flash: Array = b.flash
			b.idle += dt
			if b.idle > D.every:
				_lift_ball(b, 0 if randf() < 0.5 else (1 if randf() < 0.5 else nn - 1))
			var steps := maxi(1, ceili(dt / 0.006))
			var h := dt / steps
			for _s in steps:
				for i in nn:
					om[i] += (-(G / L) * sin(th[i]) - D.damp * om[i]) * h   # Pendulum's true equation
					th[i] += om[i] * h
				for i in nn - 1:
					var xi: float = _px(b, i) + sin(th[i]) * L
					var xj: float = _px(b, i + 1) + sin(th[i + 1]) * L
					var gap := xj - xi - 2.0 * r
					if gap < 0.0:
						var dA := -gap / L / 2.0         # un-overlap, half each
						th[i] -= dA
						th[i + 1] += dA
						if om[i] > om[i + 1]:            # approaching: the impulse swap
							var a: float = om[i]
							var c: float = om[i + 1]
							om[i] = ((1.0 - D.e) * a + (1.0 + D.e) * c) / 2.0
							om[i + 1] = ((1.0 + D.e) * a + (1.0 - D.e) * c) / 2.0
							if absf(a - c) > 0.3:
								flash[i] = 0.25
			for i in nn - 1:
				if flash[i] > 0.0:
					flash[i] -= dt
		"pinball":
			var G: float = b.h * D.g
			var R: float = b.h * D.r
			var flen: float = b.w * D.flipLen
			var left: float = b.w * 0.08
			var right: float = b.w * 0.92
			var top: float = b.h * 0.04
			var segs: Array = b.segs
			var bumps: Array = b.bumps
			b.holdT -= dt
			b.nT = maxf(0.0, b.nT - dt)
			var want: float = D.rest - D.swing if b.holdT > 0.0 else D.rest
			for f in segs:
				if f.s != 0.0:
					var prev: float = f.a
					f.a += clampf(want - f.a, -D.flipSpeed * dt, D.flipSpeed * dt)
					f.w = (f.a - prev) / sdt             # the flipper's angular speed
					f.tip = (f.p as Vector2) + Vector2(f.s * cos(f.a) * flen, sin(f.a) * flen)
			var ball: Vector2 = b.ball
			var v: Vector2 = b.bv
			if b.holdT < -0.35 and v.y > 0.0:            # its own reflexes: flip when the ball
				for f in segs:                           # is over the fast, outer part of the arm
					if f.s != 0.0:
						var e: Vector2 = f.tip - f.p
						var k: float = (ball - f.p as Vector2).dot(e) / _or1(e.length_squared())
						if k > 0.45 and k < 1.3 and ball.y > f.p.y - b.h * 0.16 and ball.y < f.tip.y + R:
							b.holdT = float(D.hold)
			var steps := maxi(1, ceili(dt / 0.008))
			var h := dt / steps
			for _s in steps:
				v.y += G * h
				ball += v * h
				if ball.x < left + R:
					ball.x = left + R
					v.x = -v.x * D.e
				if ball.x > right - R:
					ball.x = right - R
					v.x = -v.x * D.e
				if ball.y < top + R:
					ball.y = top + R
					v.y = -v.y * D.e
				for bp in bumps:                         # Knock: an impulse away along n
					var d: Vector2 = ball - bp.p
					var dl := _or1(d.length())
					if dl < bp.r + R:
						var kv := d / dl
						var vn := v.dot(kv)
						var kick: float = b.h * D.bump
						ball = (bp.p as Vector2) + kv * (bp.r + R)
						if vn < kick:
							v += (kick - vn) * kv
						bp.hit = 0.2
						b.nrm = kv
						b.hp = ball
						b.nT = 0.3
				for f in segs:                           # Xmarks' reflection, moving mirror
					var e: Vector2 = f.tip - f.p
					var el := _or1(e.length_squared())
					var k := clampf((ball - f.p as Vector2).dot(e) / el, 0.0, 1.0)
					var c: Vector2 = (f.p as Vector2) + e * k
					var d := ball - c
					var dl := _or1(d.length())
					if dl < R + 2.5:
						var kv := d / dl
						ball = c + kv * (R + 2.5)
						var ws: float = f.s * f.w        # the mirrored flipper turns the other way
						var sv := Vector2(-ws * (c.y - f.p.y), ws * (c.x - f.p.x))   # surface speed: ω × arm
						var rv := v - sv
						var vn := rv.dot(kv)
						if vn < 0.0:
							v = rv - (1.0 + D.e) * vn * kv + sv   # reflect the relative velocity, add the surface back
							b.nrm = kv
							b.hp = ball
							b.nT = 0.3
				var sp := v.length()
				var cap: float = b.h * 3.0
				if sp > cap:
					v *= cap / sp
			b.ball = ball
			b.bv = v
			if ball.y > b.gy + R:                        # the drain: a new ball
				_spawn_ball(b)
				b.drains += 1
			for bp in bumps:
				bp.hit = maxf(0.0, bp.hit - dt)
		"yoyo":
			var G: float = b.h * D.g
			var r: float = b.h * D.r
			var hx: float = b.w / 2.0
			b.lastDt = dt
			b.timer += dt
			b.jolt = maxf(0.0, b.jolt - dt)
			b.hy = b.h * 0.12 + sin(t * D.bobRate) * b.h * D.bob
			var hy: float = b.hy
			if b.state == "held":
				b.p = Vector2(hx, hy + r)
				b.pp = b.p
				if b.timer > D.wait:
					_throw(b)
			else:
				var p: Vector2 = b.p
				var pp: Vector2 = b.pp
				var cap: float = b.h * 0.06
				var v := Vector2(clampf((p.x - pp.x) * D.damp, -cap, cap), clampf((p.y - pp.y) * D.damp, -cap, cap))
				pp = p
				p += v + Vector2(0, G * dt * dt)
				if b.state == "fall":
					b.om = absf(p.y - pp.y) / sdt / r    # ω = v ÷ r, unwinding
				if b.state == "reel":
					b.L = maxf(0.0, b.L - b.h * D.reel * dt)
					b.om = b.h * D.reel / r
				if b.state == "sleep":
					b.om *= exp(-D.sleepDrag * dt)
					if b.timer > D.sleep:
						b.state = "reel"
						b.timer = 0.0
				var d := p - Vector2(hx, hy)
				var dl := _or1(d.length())
				if dl > b.L:                             # ← the rope constraint, |p − h| ≤ L
					p = Vector2(hx, hy) + d / dl * b.L
					if b.state == "fall":
						b.state = "sleep"
						b.timer = 0.0
						b.jolt = 0.3
				if b.state == "reel" and b.L <= r:
					b.state = "held"
					b.timer = 0.0
					b.om = 0.0
				if p.y > b.h - r:
					p.y = b.h - r
					pp.y = p.y
				p.x = clampf(p.x, r, b.w - r)
				b.p = p
				b.pp = pp
			b.spin += b.om * dt

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	Kit.stage(n, b)
	var D: Dictionary = b.D
	var origin: Vector2 = (b.rect as Rect2).position
	match b.id:
		"ragdoll":
			Kit.ground(n, b)
			var anchor: Vector2 = b.anchor
			Kit.line(n, Vector2(anchor.x, 0), anchor, Color(0.91, 0.898, 0.957, 0.25), 1.0)
			for c in b.C:
				Kit.line(n, b.P[c[0]].p, b.P[c[1]].p, Kit.BONE, 3.0)
			Kit.dot(n, b.P.head.p, 6.5, Kit.MOVER)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"knock":
			Kit.ground(n, b)
			for bx in b.boxes:
				var quad := [bx.p[0].p, bx.p[1].p, bx.p[2].p, bx.p[3].p]
				Kit.poly(n, quad, Color(0.541, 0.851, 0.961, 0.14))
				Kit.poly(n, quad, Kit.BONE, 1.5)
			for r in b.rings:
				Kit.ring(n, r.p, r.r, Color(0.961, 0.541, 0.541, r.a * 0.8), 2.0)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"xmarks":
			var segs: Array = b.segs
			var o: Vector2 = b.o
			for s in segs:
				Kit.line(n, s[0], s[1], Kit.BONE, 2.0)
			var dir := Vector2(cos(b.aim), sin(b.aim))
			var hit := _cast(segs, o, dir)
			if not hit.is_empty():
				Kit.line(n, o, hit.p, Kit.HOT, 2.0)
				var hx: Vector2 = hit.p
				var rdir := dir
				var h := hit
				for bi in int(D.bounces):                # each reflected leg: v − 2(v·n)n
					if h.is_empty():
						break
					var hn: Vector2 = h.n
					var dn := rdir.dot(hn)
					rdir = rdir - 2.0 * dn * hn
					var h2 := _cast(segs, hx + rdir, rdir)
					Kit.line(n, hx, h2.p if not h2.is_empty() else hx + rdir * 400.0,
						Color(0.961, 0.541, 0.541, 0.35 * pow(0.7, bi)), 2.0)
					if not h2.is_empty():
						hx = h2.p
					h = h2
				Kit.arrow(n, hit.p, hit.p + hit.n * 22.0, Kit.GOOD)
				Kit.line(n, hit.p + Vector2(-5, -5), hit.p + Vector2(5, 5), Kit.INK, 2.0)   # X marks
				Kit.line(n, hit.p + Vector2(-5, 5), hit.p + Vector2(5, -5), Kit.INK, 2.0)   # the spot
			Kit.dot(n, o, 6.0, Kit.HOT)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"normals":
			var pts := PackedVector2Array()              # the hill itself
			var x := 0.0
			while x <= b.w:
				pts.append(Vector2(x, _n_terra(b, x)))
				x += 4.0
			n.draw_polyline(pts, Color(0.788, 0.769, 0.894, 0.55), 1.5)
			var fill := pts.duplicate()
			fill.append(Vector2(b.w, b.h))
			fill.append(Vector2(0, b.h))
			n.draw_colored_polygon(fill, Color(0.588, 0.569, 0.745, 0.13))
			var wx: float = b.wx
			var dir: float = b.dir
			var y := _n_terra(b, wx)
			var m := _n_slope(b, wx)
			var tl := sqrt(1.0 + m * m)
			var tang := Vector2(1.0, m) / tl             # unit tangent (1, m)
			var nrm := Vector2(m, -1.0) / tl             # turned 90°: (m, −1) — up
			Kit.arrow(n, Vector2(wx, y), Vector2(wx, y) + tang * 26.0 * dir, Kit.DIM)
			Kit.arrow(n, Vector2(wx, y), Vector2(wx, y) + nrm * 30.0, Kit.GOOD)
			Kit.mote(n, b, Vector2(wx, y) + nrm * 9.0, (tang * dir).angle())
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"gait":
			Kit.ground(n, b)
			var THIGH: float = b.h * D.thigh
			var planted: int = -1 if b.stepping < 0 else 1 - b.stepping
			var shift: float = 0.0 if planted < 0 else ((b.feet[planted] as Vector2).x - b.bx) * 0.35   # weight over the
			var hip_x: float = b.bx + shift              # standing foot
			var bob: float = 0.0 if b.stepping < 0 else sin(clampf(b.k, 0.0, 1.0) * PI) * 3.0
			var body_y: float = b.gy - b.h * D.bodyH - bob
			var lean := clampf(b.vx * 0.0035, -0.3, 0.3)
			for i in 2:                                  # two-bone IK, straight from card I
				var hip := Vector2(hip_x + (5.0 if i == 1 else -5.0), body_y + 8.0)
				var f: Vector2 = b.feet[i]
				var to := f - hip
				var d := clampf(to.length(), 4.0, THIGH * 2.0 - 2.0)
				var half := THIGH
				var bse := to.angle()
				var cos_a := clampf((half * half + d * d - half * half) / (2.0 * half * d), -1.0, 1.0)
				var knee_side: float = -1.0 if b.vx >= 0.0 else 1.0   # knees bend away from travel
				var a := bse + acos(cos_a) * knee_side
				var knee := hip + Vector2(cos(a), sin(a)) * half
				n.draw_polyline(PackedVector2Array([hip, knee, f]), Kit.BONE, 3.5)
				Kit.dot(n, f + Vector2(0, -1.5), 3.0, Kit.BONE)
			n.draw_set_transform(origin + Vector2(hip_x, body_y), lean, Vector2.ONE)
			n.draw_circle(Vector2.ZERO, 12.0, Kit.MOVER)
			var eye: float = 4.5 if b.vx >= 0.0 else -4.5
			n.draw_circle(Vector2(eye, -3.5), 2.4, Kit.NIGHT)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.ring(n, Vector2(b.tx, b.gy - 4.0), 5.0, Kit.TARGET, 1.5)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"grapple":
			Kit.ground(n, b)
			var p: Vector2 = b.p
			var pp: Vector2 = b.pp
			for s in b.segs:
				Kit.line(n, s[0], s[1], Kit.BONE, 2.5)
			if b.hooked:
				var a: Vector2 = b.anchor
				var L: float = b.L
				var throwK: float = b.throwK
				Kit.ring(n, a, L, Color(0.961, 0.757, 0.412, 0.18))   # the swing circle: |p − a| = L
				Kit.line(n, p, p + (a - p) * throwK, Kit.TARGET, 1.5)
				Kit.dot(n, a, 3.5, Kit.TARGET)
				Kit.label(n, b, "L = %d" % roundi(L), (p + a) / 2.0 + Vector2(8, 0), Color(0.961, 0.757, 0.412, 0.8))
			if b.miss > 0.0:
				Kit.line(n, p, b.miss_at, Color(0.961, 0.541, 0.541, b.miss), 1.0)
			Kit.mote(n, b, p, (p - pp).angle() if (p - pp).length() > 0.4 else 0.0)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"rope":
			Kit.ground(n, b)
			var nn := int(D.n)
			var pts: Array = b.pts
			var w0: float = Kit.noise(t * D.windRate) * D.wind
			Kit.arrow(n, Vector2(b.w * 0.12, b.h * 0.1), Vector2(b.w * 0.12 + w0 * 40.0, b.h * 0.1), Kit.DIM)
			Kit.label(n, b, "wind", Vector2(b.w * 0.12, b.h * 0.1 - 6.0), Kit.DIM, true)
			var line := PackedVector2Array()
			for i in nn:
				line.append(pts[i].p)
			n.draw_polyline(line, Kit.BONE, 2.0)
			for i in range(1, nn - 1):
				Kit.dot(n, pts[i].p, 2.0, Kit.BONE)
			Kit.dot(n, pts[0].p, 4.0, Kit.BONE)
			var e: Vector2 = pts[nn - 1].p
			var f: Vector2 = pts[nn - 2].p
			Kit.mote(n, b, e, (e - f).angle(), Kit.MOVER, 7.0)
			if b.held >= 0 and b.hold > 0.0:
				Kit.ring(n, b.hold_at, 8.0, Color(0.961, 0.757, 0.412, 0.7), 1.5)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"ninja":
			var R := 8.0
			var lx: float = b.w * D.left
			var rx: float = b.w * D.right
			var p: Vector2 = b.p
			var v: Vector2 = b.v
			var on_wall: int = b.onWall
			var trail: Array = b.trail
			Kit.rect(n, Rect2(0, 0, lx, b.h), Color(0.588, 0.569, 0.745, 0.13))
			Kit.rect(n, Rect2(rx, 0, b.w - rx, b.h), Color(0.588, 0.569, 0.745, 0.13))
			Kit.line(n, Vector2(lx, 0), Vector2(lx, b.h), Kit.BONE, 1.5)
			Kit.line(n, Vector2(rx, 0), Vector2(rx, b.h), Kit.BONE, 1.5)
			var yy: float = fmod(b.scroll, 26.0)
			while yy < b.h:
				Kit.line(n, Vector2(lx - 7.0, yy), Vector2(lx, yy), Kit.DIM)
				Kit.line(n, Vector2(rx, yy), Vector2(rx + 7.0, yy), Kit.DIM)
				yy += 26.0
			if b.floorY < b.h + 10.0:
				Kit.ground(n, b, b.floorY)
			for i in trail.size():
				Kit.dot(n, trail[i], 1.3, Color(0.541, 0.851, 0.961, i / float(trail.size()) * 0.3))
			if on_wall != 0 and v.y > 0.0:               # slide dust
				for _i in 3:
					Kit.dot(n, Vector2(p.x + on_wall * R, p.y + randf_range(-6, 6)), 1.5, Color(0.91, 0.898, 0.957, 0.45))
				if on_wall > 0:
					_label_right(n, "slide", Vector2(p.x - on_wall * 14.0, p.y + 4.0), Kit.DIM)
				else:
					Kit.label(n, b, "slide", Vector2(p.x - on_wall * 14.0, p.y + 4.0), Kit.DIM)
			if b.flash > 0.0:
				var jp: Vector2 = b.jp
				Kit.label(n, b, "v₀ = √(2gh)", Vector2(jp.x, jp.y - 12.0), Color(0.961, 0.541, 0.541, b.flash * 1.6), true)
			if b.buffered:
				Kit.label(n, b, "jump buffered", Vector2(b.w / 2.0, b.h * 0.14), Color(0.961, 0.757, 0.412, 0.8), true)
			Kit.mote(n, b, p, (PI if on_wall > 0 else 0.0) if on_wall != 0 else v.angle())
			Kit.label(n, b, "climbed %d px" % roundi(b.scroll), Vector2(b.w / 2.0, 14.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"jelly":
			Kit.ground(n, b)
			var R: float = b.h * D.r
			var nn := int(D.n)
			var pts: Array = b.pts
			var c: Vector2 = b.c
			var shape := []
			for p in pts:
				shape.append(p.p)
			Kit.poly(n, shape, Color(0.541, 0.851, 0.961, 0.22))
			for i in range(0, nn, 2):
				Kit.line(n, c, pts[i].p, Color(0.91, 0.898, 0.957, 0.12))
			Kit.poly(n, shape, Kit.MOVER, 1.5)
			Kit.dot(n, c, 2.0, Kit.DIM)
			Kit.dot(n, c + Vector2(-R * 0.28, -R * 0.1), R * 0.11, Kit.NIGHT)   # two eyes ride the centroid
			Kit.dot(n, c + Vector2(R * 0.28, -R * 0.1), R * 0.11, Kit.NIGHT)
			if b.flash > 0.0:
				Kit.ring(n, b.fp, 6.0 + (0.35 - b.flash) * 60.0, Color(0.961, 0.541, 0.541, b.flash * 2.0), 1.5)
			Kit.label(n, b, "A/A₀ = %.2f" % (_j_area(b) / b.A0), Vector2(b.w / 2.0, 16.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"avalanche":
			var pts := PackedVector2Array()              # the hill
			var x := 0.0
			while x <= b.w:
				pts.append(Vector2(x, _a_terra(b, x)))
				x += 4.0
			n.draw_polyline(pts, Color(0.788, 0.769, 0.894, 0.55), 1.5)
			var fill := pts.duplicate()
			fill.append(Vector2(b.w, b.h))
			fill.append(Vector2(0, b.h))
			n.draw_colored_polygon(fill, Color(0.588, 0.569, 0.745, 0.13))
			for rk in b.rocks:
				var rp: Vector2 = rk.p
				var rr: float = rk.r
				var ra: float = rk.a
				var shape: Array = rk.shape
				var hex := []
				for k in 6:
					var an: float = ra + k / 6.0 * TAU
					hex.append(rp + Vector2(cos(an), sin(an)) * rr * float(shape[k]))
				Kit.poly(n, hex, Color(0.788, 0.769, 0.894, 0.22))
				Kit.poly(n, hex, Kit.BONE, 1.5)
				Kit.line(n, rp, rp + Vector2(cos(ra), sin(ra)) * rr * float(shape[0]), Kit.DIM)   # the spoke shows the spin
				if rk.on:
					var nm: Vector2 = rk.nrm
					Kit.arrow(n, rp - nm * rr, rp - nm * rr + nm * 14.0, Kit.GOOD)
			_label_right(n, "θ = %d°  ·  e = %s" % [roundi(b.theta * 180.0 / PI), str(D.e)], Vector2(b.w - 8.0, 14.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"kite":
			Kit.ground(n, b)
			var nn := int(D.n)
			var pts: Array = b.pts
			var tail: Array = b.tail
			var hand: Vector2 = b.hand
			var wind: Vector2 = b.wind
			var nrm: Vector2 = b.nrm
			var F: float = b.F
			var kite: Vector2 = pts[nn - 1].p
			Kit.arrow(n, Vector2(b.w * 0.1, b.h * 0.1), Vector2(b.w * 0.1, b.h * 0.1) + wind * 0.12, Kit.DIM)
			Kit.label(n, b, "wind", Vector2(b.w * 0.1, b.h * 0.1 - 6.0), Kit.DIM, true)
			var string := PackedVector2Array()
			for i in nn:
				string.append(pts[i].p)
			n.draw_polyline(string, Kit.BONE, 1.0)
			n.draw_polyline(PackedVector2Array(tail), Color(0.961, 0.541, 0.541, 0.6), 1.0)
			var fdir := Vector2(-nrm.y, nrm.x)           # the face runs across the normal
			var r1: float = b.h * 0.05
			var r2: float = b.h * 0.03
			Kit.poly(n, [kite + fdir * r1, kite + nrm * r2, kite - fdir * r1, kite - nrm * r2], Kit.MOVER)
			Kit.arrow(n, kite, kite + nrm * F * 0.08, Kit.GOOD)   # the force, along n
			Kit.label(n, b, "α = %d°" % roundi(b.alpha * 180.0 / PI), kite + Vector2(14, -10), Color(0.608, 0.886, 0.541, 0.8))
			Kit.mote(n, b, hand + Vector2(0, 6), ((pts[1].p as Vector2) - hand).angle() * 0.3, Kit.MOVER, 7.0)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"newton":
			var nn := int(D.n)
			var r: float = b.h * D.r
			var L: float = b.h * D.L
			var py: float = b.h * 0.14
			var th: Array = b.th
			var flash: Array = b.flash
			Kit.line(n, Vector2(_px(b, 0) - r * 1.6, py), Vector2(_px(b, nn - 1) + r * 1.6, py), Kit.BONE, 2.5)
			for i in nn:
				var bp := Vector2(_px(b, i) + sin(th[i]) * L, py + cos(th[i]) * L)
				Kit.line(n, Vector2(_px(b, i), py), bp, Color(0.788, 0.769, 0.894, 0.7), 1.0)
				Kit.dot(n, bp, r, Kit.MOVER)
				Kit.dot(n, bp - Vector2(r * 0.3, r * 0.3), r * 0.22, Color(1, 1, 1, 0.35))
				if i < nn - 1 and flash[i] > 0.0:
					var fl: float = flash[i]
					Kit.ring(n, bp + Vector2(r, 0), 4.0 + (0.25 - fl) * 50.0, Color(0.961, 0.541, 0.541, fl * 3.0), 1.5)
			_label_right(n, "α = −(g/L)·sin θ", Vector2(b.w - 8.0, py + 14.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"pinball":
			var R: float = b.h * D.r
			var left: float = b.w * 0.08
			var right: float = b.w * 0.92
			var top: float = b.h * 0.04
			var ball: Vector2 = b.ball
			Kit.ground(n, b)
			Kit.line(n, Vector2(left, top), Vector2(left, b.gy - b.h * 0.3), Kit.BONE, 1.5)
			Kit.line(n, Vector2(right, top), Vector2(right, b.gy - b.h * 0.3), Kit.BONE, 1.5)
			Kit.line(n, Vector2(left, top), Vector2(right, top), Kit.BONE, 1.5)
			for f in b.segs:
				var flipper: bool = f.s != 0.0
				Kit.line(n, f.p, f.tip, Kit.BONE if flipper else Color(0.788, 0.769, 0.894, 0.6), 5.0 if flipper else 1.5)
				if flipper:
					Kit.dot(n, f.p, 3.0, Kit.DIM)
			for bp in b.bumps:
				if bp.hit > 0.0:
					Kit.dot(n, bp.p, bp.r, Color(0.961, 0.541, 0.541, bp.hit * 3.0))
				Kit.ring(n, bp.p, bp.r, Kit.TARGET, 1.5)
				Kit.dot(n, bp.p, 2.0, Kit.TARGET)
			if b.nT > 0.0:
				var hp: Vector2 = b.hp
				Kit.arrow(n, hp, hp + (b.nrm as Vector2) * 18.0, Kit.GOOD)
			Kit.dot(n, ball, R, Kit.MOVER)
			Kit.dot(n, ball - Vector2(R * 0.3, R * 0.3), R * 0.25, Color(1, 1, 1, 0.4))
			_label_right(n, "drained ×%d" % b.drains, Vector2(b.w - 10.0, 16.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"yoyo":
			var r: float = b.h * D.r
			var hand := Vector2(b.w / 2.0, b.hy)
			var p: Vector2 = b.p
			var state: String = b.state
			var spin: float = b.spin
			if state != "held":
				Kit.ring(n, hand, b.L, Color(0.91, 0.898, 0.957, 0.08))   # the reach of the string
			Kit.mote(n, b, hand + Vector2(0, -12), 0.0, Kit.MOVER, 8.0)
			Kit.line(n, hand, p - Vector2(0, r * 0.4), Kit.BONE, 1.0)
			Kit.dot(n, p, r, Kit.MOVER)
			Kit.ring(n, p, r * 0.72, Color(0.075, 0.063, 0.125, 0.55), 1.5)
			var s1 := Vector2(cos(spin), sin(spin)) * r * 0.85
			var s2 := Vector2(cos(spin + 1.571), sin(spin + 1.571)) * r * 0.85
			Kit.line(n, p + s1, p - s1, Kit.NIGHT, 2.0)
			Kit.line(n, p + s2, p - s2, Kit.NIGHT, 2.0)
			Kit.dot(n, p, r * 0.18, Kit.TARGET)          # the axle
			if b.jolt > 0.0:
				Kit.ring(n, p, r + (0.3 - b.jolt) * 60.0, Color(0.961, 0.541, 0.541, b.jolt * 2.5), 1.5)
			Kit.label(n, b, "%s  ·  ω = %d rad/s" % [state, roundi(b.om)], p + Vector2(r + 8.0, 4.0),
				Color(0.788, 0.627, 0.961, 0.9) if state == "sleep" else Kit.DIM)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
