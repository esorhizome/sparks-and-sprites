extends RefCounted

const Kit := preload("res://scenes/motion/kit.gd")
## CROWDS & FIELDS — eight movement styles, ported from the web lexicon
## (docs/locomotion.js). Many bodies, one rule each — or one formula over
## space that everything obeys. A crowd has no script: each grain, bird,
## sheep, or walker reads only its neighbours and the field it stands in,
## and the flock, the spiral, the formation, the tidy crossing simply
## HAPPEN. Magnets and vortices are fields (position → a push); boids,
## herds and crossings are neighbour rules (look around → a nudge); belts
## and marching grids are both.

const TITLE := "Crowds & fields"
const BLURB := "many bodies, one rule each — magnets, vortices, boids, herds, crossings, formations, belts"
const DEFS := [
	{ "id": "magnet", "letter": "M", "name": "Magnet",
		"hint": "inverse-square fields: dust in the pull of three magnets — press to flip them",
		"dials": { "mags": [[0.28, 0.38, 1], [0.72, 0.34, 1], [0.5, 0.72, -1]],   # x, y as fractions, then polarity
			"grains": 36, "strength": 26000, "soften": 900, "orbit": 24, "drag": 0.7, "maxsp": 190,
			"label": "force = k ÷ distance² — flip: pull ⇄ push" },
		"rhyme": { "name": "Moths", "hint": "twice the grains, the sideways whisper turned to a shout, half the drag — they circle the lamps and never land",
			"dials": { "grains": 70, "orbit": 110, "drag": 0.35 } } },
	{ "id": "vectorfield", "letter": "V", "name": "Vectorfield",
		"hint": "a formula turns every point into an arrow; riders obey — press to pour more in",
		"dials": { "riders": 40, "speed": 62, "scaleX": 0.019, "scaleY": 0.023, "driftX": 0.24, "driftY": 0.17, "swing": 1.6,
			"grid": 36, "pour": 14,
			"label": "angle(x, y, t) = sin(x·s + t) + cos(y·s − t)" },
		"rhyme": { "name": "Vertigo", "hint": "the same formula sampled three times denser and morphing four times faster — a churning, dizzy weather",
			"dials": { "scaleX": 0.06, "scaleY": 0.07, "driftX": 1.1 } } },
	{ "id": "swarm", "letter": "S", "name": "Swarm",
		"hint": "boids: separation + alignment + cohesion, nobody in charge — press to scare them",
		"dials": { "n": 26, "sepR": 26, "nbrR": 54, "align": 1.4, "cohere": 1.1, "sepK": 3400, "minsp": 55, "maxsp": 105,
			"fear": 9000, "greens": 2,
			"label": "three averages over neighbours = the brain" },
		"rhyme": { "name": "Starlings", "hint": "forty birds with the alignment and cohesion nudges doubled — a tight murmuration that turns as one body",
			"dials": { "n": 40, "align": 3.2, "cohere": 2.6 } } },
	{ "id": "whirlpool", "letter": "W", "name": "Whirlpool",
		"hint": "a vortex field: swirl ∝ 1/r plus a slow inward pull spirals debris into the eye — press to move the eye",
		"dials": { "debris": 60, "swirl": 2600, "pull": 0.35, "core": 18, "rim": 0.46, "maxsp": 200, "grid": 34, "follow": 3,
			"label": "v = (swirl ÷ r) · (tangent + pull · inward)" },
		"rhyme": { "name": "Wormhole", "hint": "twice the swirl, a third of the pull, a wider throat — a fast tight spin that barely sinks: a wormhole's mouth",
			"dials": { "swirl": 5200, "pull": 0.12, "core": 26 } } },
	{ "id": "herd", "letter": "H", "name": "Herd",
		"hint": "Swarm's boids that also flee a dog (Magnet's repulsor); it works them into the pen — press to place the dog",
		"dials": { "n": 14, "sepR": 18, "nbrR": 46, "align": 1.2, "cohere": 0.5, "sepK": 900, "fear": 260, "dogR": 80, "maxsp": 75, "drag": 1.6,
			"graze": 14, "pen": [0.66, 0.22, 0.78], "gate": [0.42, 0.68], "dogEvery": 3.2, "rest": 2.5,
			"label": "v += flee(dog) + boids − v·drag" },
		"rhyme": { "name": "Hens", "hint": "more of them, twice as fast, twice as scared of the dog — a panicked flap of hens instead of a placid flock",
			"dials": { "n": 22, "fear": 620, "maxsp": 140 } } },
	{ "id": "xing", "letter": "X", "name": "Xing",
		"hint": "Obstacle, for movers: predict the closest approach to each neighbour, step aside early — press to add a walker",
		"dials": { "n": 14, "speed": 52, "spread": 0.4, "minDist": 20, "horizon": 2.6, "turn": 5, "dodge": 260, "band": [0.24, 0.76],
			"label": "t* = −(r·v) ÷ (v·v) — dodge if d(t*) < r_min" },
		"rhyme": { "name": "Xmas", "hint": "the rush: more walkers, twice the pace, a tighter personal radius — a christmas-eve crowd that never touches",
			"dials": { "n": 22, "speed": 88, "minDist": 15 } } },
	{ "id": "invaders", "letter": "I", "name": "Invaders",
		"hint": "Zigzag's schedule on a grid: the formation's beat quickens as it thins — press to shoot the one you click",
		"dials": { "cols": 8, "rows": 4, "gapX": 0.075, "gapY": 0.085, "step": 0.035, "drop": 0.05, "beat": 0.6, "beatMin": 0.07,
			"wobble": 2.5, "regroup": 1.6,
			"label": "interval = beat · alive ÷ total" },
		"rhyme": { "name": "Insects", "hint": "six rows, a beat twice as fast, a deeper drop each turn — a skittering bug wall that lands in half the time",
			"dials": { "rows": 6, "beat": 0.3, "drop": 0.08 } } },
	{ "id": "conveyor", "letter": "C", "name": "Conveyor",
		"hint": "Vectorfield in rectangles: crates inherit the belt under them, a gate sorts the lanes — press to flip the gate",
		"dials": { "speed": 64, "spawnEvery": 1.15, "maxCrates": 12, "autoFlip": 3.6, "inherit": 9, "crate": 9, "chevron": 16,
			"belts": [[0, 0.44, 0.5, 0.14], [0.5, 0.12, 0.5, 0.14], [0.5, 0.74, 0.5, 0.14]],   # x, y, w, h as fractions
			"gate": [0.5, 0.12, 0.1, 0.76],
			"label": "on a belt: v += (belt.v − v) · smooth(k, dt)" },
		"rhyme": { "name": "Crunch", "hint": "the same belts at 2.3× speed, a crate every half second, the gate flipping thrice as often — crunch mode",
			"dials": { "speed": 150, "spawnEvery": 0.5, "autoFlip": 1.1 } } },
]

## The web kit's `len(...) || 1`: a zero length becomes 1 so divisions stay safe.
static func _or1(x: float) -> float:
	return x if x != 0.0 else 1.0

## The web label's "right" alignment — Kit.label only knows left and centre.
static func _label_right(n: CanvasItem, txt: String, p: Vector2, col: Color) -> void:
	var f := ThemeDB.fallback_font
	var x := p.x - f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	n.draw_string(f, Vector2(x, p.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)

# ---- Vectorfield: a vector field is a function from position to direction ----
static func _field_angle(D: Dictionary, p: Vector2, t: float) -> float:
	return sin(p.x * D.scaleX + t * D.driftX) * D.swing + cos(p.y * D.scaleY - t * D.driftY) * D.swing

# ---- Whirlpool: position → velocity, the whole card ----
static func _pool_R(b: Dictionary) -> float:
	return minf(b.w, b.h) * b.D.rim

static func _pool_field(b: Dictionary, p: Vector2) -> Vector2:
	var D: Dictionary = b.D
	var d: Vector2 = p - b.eye
	var r := _or1(d.length())
	var vt := minf(D.swirl / r, D.maxsp)                 # tangential speed ∝ 1/r (capped)
	return Vector2((-d.y / r - d.x / r * D.pull) * vt, (d.x / r - d.y / r * D.pull) * vt)

static func _pool_spawn(b: Dictionary, bit: Dictionary) -> void:
	var a := randf_range(0.0, TAU)
	var r := _pool_R(b) * randf_range(0.9, 1.1)
	bit.p = (b.eye as Vector2) + Vector2(cos(a), sin(a)) * r
	bit.s = randf_range(1.3, 2.6)

# ---- Herd ----
static func _in_pen(b: Dictionary, s: Dictionary) -> bool:
	return s.p.x > b.px0 + 6.0 and s.p.y > b.py0 and s.p.y < b.py1

# ---- Xing ----
static func _xing_spawn(b: Dictionary, w: Dictionary, dir: int, x: float, y: float) -> void:
	var D: Dictionary = b.D
	w.dir = dir
	w.p = Vector2(x, y)
	w.gy = randf_range(b.y0 + 8.0, b.y1 - 8.0)
	w.sp = D.speed * (1.0 + randf_range(-D.spread, D.spread))
	w.v = Vector2(dir * w.sp, 0.0)

# ---- Invaders ----
static func _inv_ix(b: Dictionary, i: int) -> float:
	var cols: int = b.D.cols
	return b.fx + (i % cols) * b.D.gapX * b.w

static func _inv_iy(b: Dictionary, i: int) -> float:
	var cols: int = b.D.cols
	return b.fy + floorf(i / float(cols)) * b.D.gapY * b.h

static func _inv_reset(b: Dictionary) -> void:
	b.alive = []
	for i in b.total:
		b.alive.append(true)
	b.fx = b.fx0
	b.fy = b.fy0
	b.dir = 1
	b.timer = b.D.beat

# ---- Conveyor ----
static func _on_belt(bl: Dictionary, c: Dictionary) -> bool:
	var r: Rect2 = bl.r
	return c.p.x >= r.position.x and c.p.x <= r.end.x and c.p.y >= r.position.y and c.p.y <= r.end.y


static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	match b.id:
		"magnet":
			# force fields, the gravity-and-charge law: strength = k ÷ distance².
			# every grain sums one small vector per magnet, plus drag so it settles
			# instead of slingshotting forever. attractors breathe inward, the
			# repulsor breathes outward — the field, made legible.
			b.mags = []
			for m in D.mags:
				b.mags.append({ "p": Vector2(b.w * m[0], b.h * m[1]), "pol": float(m[2]) })
			b.dust = []
			for i in int(D.grains):
				b.dust.append({ "p": Vector2(randf_range(0, b.w), randf_range(0, b.h)), "v": Vector2.ZERO })
		"vectorfield":
			# a vector field is a function from position to direction — invisible
			# level design. wind, currents, lava flows, bullet-hell patterns: define
			# angle(x, y, t), and anything dropped in follows the grain. the field
			# here slowly morphs; the arrows sample it so you can read the weather.
			b.riders = []
			for i in int(D.riders):
				b.riders.append(Vector2(randf_range(0, b.w), randf_range(0, b.h)))
		"swarm":
			# three rules, each an average over neighbours: don't crowd (push apart
			# inside sepR px), don't stray (match nearby velocities), don't drift
			# (drop toward the local centre). no leader exists — the green birds
			# are ordinary; follow one and watch it obey the same three nudges.
			b.boids = []
			for i in int(D.n):
				b.boids.append({ "p": Vector2(randf_range(0, b.w), randf_range(0, b.h)),
					"v": Vector2(randf_range(-60, 60), randf_range(-60, 60)), "g": i < int(D.greens) })
		"whirlpool":
			# Vectorfield's lesson wearing Magnet's law: a VORTEX is a field whose
			# arrows run around a point with speed ∝ 1/r (the water hurries where the
			# circle is small). add a small radial share and every path becomes a
			# LOGARITHMIC SPIRAL — the same pitch at any radius. debris rides the field
			# kinematically (position += v·dt, no mass, like Vectorfield's riders);
			# whatever reaches the core is reborn at the rim, so the spiral never empties.
			b.eye = Vector2(b.w / 2.0, b.h * 0.5)
			b.teye = b.eye
			b.swallowed = 0
			b.bits = []
			for i in int(D.debris):
				var bit := {}
				_pool_spawn(b, bit)
				bit.p.x = b.eye.x + (bit.p.x - b.eye.x) * randf_range(0.3, 1.0)
				bit.p.y = b.eye.y + (bit.p.y - b.eye.y) * randf_range(0.3, 1.0)
				b.bits.append(bit)
		"herd":
			# Swarm's three averages, slowed down and given drag so a sheep can STAND,
			# plus one more push: fear of the dog, inverse with distance (Magnet's
			# repulsor, wearing a collar). no sheep knows where the pen is — the dog
			# stands where the flock must not go, and the fence does the rest: a sheep
			# stopped by a rail feels along it toward the gap. when every sheep is in,
			# a bucket lures them back out and the whole errand starts again.
			b.px0 = b.w * D.pen[0]
			b.py0 = b.h * D.pen[1]
			b.py1 = b.h * D.pen[2]
			b.gy0 = b.h * D.gate[0]
			b.gy1 = b.h * D.gate[1]
			b.gmid = (b.gy0 + b.gy1) / 2.0
			b.sheep = []
			for i in int(D.n):
				b.sheep.append({ "p": Vector2(randf_range(b.w * 0.08, b.w * 0.45), randf_range(b.h * 0.15, b.h * 0.85)),
					"v": Vector2.ZERO, "h": 0.0, "ph": i * 7.3 })
			b.dog = { "p": Vector2(b.w * 0.1, b.h * 0.5), "tp": Vector2(b.w * 0.1, b.h * 0.5), "on": false }
			b.dogTimer = D.dogEvery * 0.5
			b.manual = 0.0
			b.restTimer = 0.0
			b.lure = 0.0
			b.penned = 0
		"xing":
			# Obstacle steered around things that stand still; a walker must dodge
			# things that MOVE, so it looks ahead. for each neighbour: relative
			# position r, relative velocity v; the TIME TO CLOSEST APPROACH is
			# t* = −(r·v)/(v·v), and r + v·t* is how near they will pass. if that is
			# under a personal radius and t* is soon, push sideways — never brake.
			# everyone has their own pace, so the crowd thins and bunches like a real one.
			b.y0 = b.h * D.band[0]
			b.y1 = b.h * D.band[1]
			b.walkers = []
			for i in int(D.n):
				var w := {}
				var dir: int = -1 if i % 2 == 1 else 1
				_xing_spawn(b, w, dir, randf_range(0, b.w), randf_range(b.y0 + 8.0, b.y1 - 8.0))
				b.walkers.append(w)
			b.urgent = []
		"invaders":
			# nothing here moves smoothly: the formation is a SCHEDULE. every
			# interval seconds it takes one step sideways; when the outermost living
			# column would leave the screen it drops a row and turns. the famous
			# trick is the tempo: interval ∝ alive ÷ total, so the last invader
			# sprints — no code for "get harder", just a timer that shrinks with the
			# count. columns wobble on a sine, so the grid reads as creatures.
			b.total = int(D.cols) * int(D.rows)
			b.width = (int(D.cols) - 1) * D.gapX * b.w
			b.fx0 = (b.w - b.width) / 2.0
			b.fy0 = b.h * 0.1
			b.alive = []
			b.fx = b.fx0
			b.fy = b.fy0
			b.dir = 1
			b.timer = D.beat
			b.pose = 0
			b.regroup = 0.0
			b.interval = D.beat
			b.cannonX = b.w / 2.0
			b.cannonT = b.w / 2.0
			b.flash = 0.0
			b.hit = Vector2.ZERO
			_inv_reset(b)
		"conveyor":
			# a belt is the simplest vector field there is: a rectangle, and one
			# velocity everywhere inside it. a crate asks "which belt am I on?" and
			# lerps its velocity toward that belt's (INHERITED velocity — Platform's
			# trick, flat). the riser at the junction is a belt too; the gate only
			# flips the sign of its velocity, and that one sign sorts the whole day's
			# cargo into two lanes. the arrows scroll so you can read the belts.
			b.belts = []
			for bl in D.belts:
				b.belts.append({ "r": Rect2(b.w * bl[0], b.h * bl[1], b.w * bl[2], b.h * bl[3]), "v": Vector2(D.speed, 0.0) })
			b.riser = { "r": Rect2(b.w * D.gate[0], b.h * D.gate[1], b.w * D.gate[2], b.h * D.gate[3]), "v": Vector2(0.0, -D.speed) }
			b.order = [b.belts[1], b.belts[2], b.riser, b.belts[0]]   # lanes first: the riser hands over at its ends
			b.crates = []
			b.up = true
			b.spawnT = 0.0
			b.autoT = 0.0
			b.manual = 0.0
			b.sorted = [0, 0]
			var b0: Rect2 = b.belts[0].r
			b.feedY = b0.position.y + b0.size.y / 2.0
			b.gateX = (b.riser.r as Rect2).position.x


static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	match b.id:
		"magnet":
			for m in b.mags:                             # invert the world
				m.pol = -m.pol
		"vectorfield":
			for i in int(D.pour):
				b.riders[int(floorf(randf_range(0, b.riders.size())))] = pos + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		"swarm":
			for bd in b.boids:
				var d: Vector2 = bd.p - pos
				var l := d.length() + 4.0
				bd.v += d / l * (D.fear / l)             # fear, inverse with distance
		"whirlpool":
			b.teye = pos
		"herd":
			b.dog.tp = pos
			b.dog.on = true
			b.manual = 6.0
			b.lure = 0.0
		"xing":
			var w := {}
			_xing_spawn(b, w, 1 if pos.x < b.w / 2.0 else -1, pos.x, minf(b.y1 - 8.0, maxf(b.y0 + 8.0, pos.y)))
			b.walkers.append(w)
			if b.walkers.size() > int(D.n) + 8:
				b.walkers.pop_front()                    # the oldest walker goes home
		"invaders":
			b.cannonT = pos.x
			var best := -1
			var bd := 1.0e9
			for i in int(b.total):
				if not b.alive[i]:
					continue
				var dx := absf(_inv_ix(b, i) - pos.x)
				var dy := absf(_inv_iy(b, i) - pos.y)
				if dx < D.gapX * b.w / 2.0 and dy < D.gapY * b.h / 2.0 and dx + dy < bd:
					bd = dx + dy
					best = i
			if best >= 0:
				b.alive[best] = false
				b.flash = 0.18
				b.hit = Vector2(_inv_ix(b, best), _inv_iy(b, best))
		"conveyor":
			b.up = not b.up
			b.manual = 5.0


static func tick(b: Dictionary, dt: float, t: float) -> void:
	var D: Dictionary = b.D
	match b.id:
		"magnet":
			for g in b.dust:
				for m in b.mags:
					var d: Vector2 = m.p - g.p
					var dd: float = d.length_squared() + D.soften   # +soften tames the singularity
					var f: float = m.pol * D.strength / dd
					var dir := d / sqrt(dd)
					g.v += dir * f * dt * 60.0
					if m.pol > 0.0:                      # a whisper of sideways push,
						g.v += Vector2(-dir.y, dir.x) * f * dt * D.orbit   # so grains orbit the pull
						                                 # instead of parking in it
				g.v *= 1.0 - D.drag * dt                 # drag = the settling
				var s: float = (g.v as Vector2).length()
				if s > D.maxsp:
					g.v *= D.maxsp / s
				g.p += g.v * dt
				if g.p.x < 0.0:
					g.p.x = b.w
				if g.p.x > b.w:
					g.p.x = 0.0
				if g.p.y < 0.0:
					g.p.y = b.h
				if g.p.y > b.h:
					g.p.y = 0.0
		"vectorfield":
			for i in b.riders.size():
				var a := _field_angle(D, b.riders[i], t)
				var p: Vector2 = b.riders[i] + Vector2(cos(a), sin(a)) * D.speed * dt
				if p.x < 0.0:
					p.x = b.w
				if p.x > b.w:
					p.x = 0.0
				if p.y < 0.0:
					p.y = b.h
				if p.y > b.h:
					p.y = 0.0
				b.riders[i] = p
		"swarm":
			for bd in b.boids:
				var sep := Vector2.ZERO
				var ali := Vector2.ZERO
				var coh := Vector2.ZERO
				var cnt := 0
				for o in b.boids:
					if is_same(o, bd):
						continue
					var d: Vector2 = o.p - bd.p
					var l := d.length()
					if l < D.sepR and l > 0.0:
						sep -= d / l / l                 # 1: separation
					if l < D.nbrR:
						ali += o.v
						coh += o.p
						cnt += 1
				if cnt > 0:
					bd.v += (ali / cnt - bd.v) * D.align * dt    # 2: alignment
					bd.v += (coh / cnt - bd.p) * D.cohere * dt   # 3: cohesion
				bd.v += sep * D.sepK * dt
				var s := _or1((bd.v as Vector2).length())
				var sp := minf(D.maxsp, maxf(D.minsp, s))   # a floor keeps the flock flowing
				bd.v *= sp / s
				bd.p += bd.v * dt
				if bd.p.x < -8.0:
					bd.p.x = b.w + 8.0
				if bd.p.x > b.w + 8.0:
					bd.p.x = -8.0
				if bd.p.y < -8.0:
					bd.p.y = b.h + 8.0
				if bd.p.y > b.h + 8.0:
					bd.p.y = -8.0
		"whirlpool":
			var k := Kit.smooth(D.follow, dt)            # the eye glides, the water follows
			b.eye += (b.teye - b.eye) * k
			var nsub: int = 2 if dt > 0.03 else 1        # a substep keeps tight turns honest
			var h := dt / nsub
			for bit in b.bits:
				for i in nsub:
					var v := _pool_field(b, bit.p)
					bit.p += v * h
				if (bit.p - b.eye as Vector2).length() < D.core:
					b.swallowed += 1
					_pool_spawn(b, bit)
		"herd":
			b.manual -= dt
			b.dogTimer -= dt
			b.lure -= dt
			if b.dogTimer <= 0.0 and b.manual <= 0.0 and b.lure <= 0.0:   # the dog's own plan: stand behind the
				b.dogTimer = D.dogEvery                  # flock on the line from the gate
				var c := Vector2.ZERO
				var m := 0
				for s in b.sheep:
					if not _in_pen(b, s):
						c += s.p
						m += 1
				if m > 0:
					c /= m
					var d: Vector2 = c - Vector2(b.px0 - 6.0, b.gmid)
					var dl := _or1(d.length())
					b.dog.tp = c + d / dl * D.dogR * 0.7
					b.dog.on = true
			var kd := Kit.smooth(4.0, dt)
			b.dog.p += (b.dog.tp - b.dog.p) * kd
			b.penned = 0
			for s in b.sheep:
				if _in_pen(b, s):
					b.penned += 1
			if b.penned == int(D.n) and b.lure <= 0.0:
				b.restTimer += dt
				if b.restTimer > D.rest:
					b.restTimer = 0.0
					b.lure = 3.0
					b.dog.on = false
			else:
				b.restTimer = 0.0
			var lp := Vector2(b.px0 - b.w * 0.18, b.gmid)   # the bucket, out past the gate
			for s in b.sheep:
				var f := Vector2.ZERO
				var ali := Vector2.ZERO
				var coh := Vector2.ZERO
				var cnt := 0
				for o in b.sheep:
					if is_same(o, s):
						continue
					var d: Vector2 = o.p - s.p
					var l := d.length()
					if l < D.sepR and l > 0.0:
						f -= d / l / l * D.sepK
					if l < D.nbrR:
						ali += o.v
						coh += o.p
						cnt += 1
				if cnt > 0:
					f += (ali / cnt - s.v) * D.align
					f += (coh / cnt - s.p) * D.cohere
				if b.dog.on:
					var d: Vector2 = s.p - b.dog.p
					var l := _or1(d.length())
					if l < D.dogR:
						f += d / l * D.fear * (1.0 - l / D.dogR)
				if b.lure > 0.0:
					var d: Vector2 = lp - s.p
					var l := _or1(d.length())
					f += d / l * 120.0
				f.x += Kit.noise(s.ph + t * 0.5) * D.graze    # grazing: a slow, personal drift
				f.y += Kit.noise(s.ph + 50.0 + t * 0.5) * D.graze
				var inside := _in_pen(b, s)
				s.v += f * dt
				var dr: float = D.drag * (3.0 if inside else 1.0)   # penned sheep settle
				s.v *= maxf(0.0, 1.0 - dr * dt)
				var sp: float = (s.v as Vector2).length()
				if sp > D.maxsp:
					s.v *= D.maxsp / sp
				var o: Vector2 = s.p
				s.p += s.v * dt
				if (o.x < b.px0) != (s.p.x < b.px0) and (s.p.y < b.gy0 or s.p.y > b.gy1):   # the left rail, with its gap
					s.p.x = b.px0 - 1.0 if o.x < b.px0 else b.px0 + 1.0
					s.v.x = 0.0
					s.v.y += (30.0 if b.gmid > s.p.y else -30.0) * dt * 10.0   # feel along the rail toward the gap
				if s.p.x > b.px0 and (o.y < b.py0) != (s.p.y < b.py0):
					s.p.y = b.py0 - 1.0 if o.y < b.py0 else b.py0 + 1.0
					s.v.y = -s.v.y * 0.2
				if s.p.x > b.px0 and (o.y < b.py1) != (s.p.y < b.py1):
					s.p.y = b.py1 - 1.0 if o.y < b.py1 else b.py1 + 1.0
					s.v.y = -s.v.y * 0.2
				if s.p.x < 8.0:
					s.p.x = 8.0
					s.v.x = absf(s.v.x)
				if s.p.x > b.w - 8.0:
					s.p.x = b.w - 8.0
					s.v.x = -absf(s.v.x)
				if s.p.y < 8.0:
					s.p.y = 8.0
					s.v.y = absf(s.v.y)
				if s.p.y > b.h - 8.0:
					s.p.y = b.h - 8.0
					s.v.y = -absf(s.v.y)
				if sp > 4.0:
					s.h = (s.v as Vector2).angle()
		"xing":
			var worst: float = D.minDist
			b.urgent = []
			for w in b.walkers:
				var gx: float = b.w + 14.0 if w.dir > 0 else -14.0
				var to := Vector2(gx, w.gy) - (w.p as Vector2)
				var d := _or1(to.length())
				var f: Vector2 = (to / d * w.sp - w.v) * D.turn   # desired − current
				var s0 := _or1((w.v as Vector2).length())
				var perp := Vector2(-w.v.y, w.v.x) / s0      # my left-hand side
				for o in b.walkers:
					if is_same(o, w):
						continue
					var r: Vector2 = o.p - w.p
					var v: Vector2 = o.v - w.v
					var vv := v.length_squared()
					if vv < 1.0:
						continue                         # moving together: nothing to predict
					var ts := -r.dot(v) / vv             # ← time to closest approach
					if ts < 0.0 or ts > D.horizon:
						continue                         # already passed, or too far off
					var c := r + v * ts
					var cd := c.length()
					if cd < D.minDist:
						var side: float = -1.0 if perp.dot(c) > 0.0 else 1.0   # they'll pass on my left → step right
						var strength: float = D.dodge * (1.0 - ts / D.horizon) * (1.0 - cd / D.minDist)
						f += perp * side * strength
						if cd < worst:
							worst = cd
							b.urgent = [w.p + w.v * ts, o.p + o.v * ts, w]
					var rd := _or1(r.length())           # the last-resort shove, if a prediction lied
					if rd < D.minDist * 0.5:
						f -= r / rd * D.dodge * 0.5
				if w.p.y < b.y0 + 6.0:                   # the kerbs push back softly
					f.y += (b.y0 + 6.0 - w.p.y) * 8.0
				if w.p.y > b.y1 - 6.0:
					f.y += (b.y1 - 6.0 - w.p.y) * 8.0
				w.v += f * dt
				var s := _or1((w.v as Vector2).length())
				var sp: float = minf(w.sp * 1.25, maxf(w.sp * 0.7, s))   # nobody stops, nobody sprints
				w.v *= sp / s
				w.p += w.v * dt
				if (w.dir > 0 and w.p.x > b.w + 12.0) or (w.dir < 0 and w.p.x < -12.0):
					_xing_spawn(b, w, w.dir, -12.0 if w.dir > 0 else b.w + 12.0, randf_range(b.y0 + 8.0, b.y1 - 8.0))   # across; start again
		"invaders":
			var cols: int = D.cols
			var count := 0
			var cmin: int = cols
			var cmax := -1
			var rmax := -1
			for i in int(b.total):
				if b.alive[i]:
					count += 1
					var c: int = i % cols
					var r: int = int(floorf(i / float(cols)))
					if c < cmin:
						cmin = c
					if c > cmax:
						cmax = c
					if r > rmax:
						rmax = r
			b.count = count
			if count == 0:
				b.regroup += dt
				if b.regroup > D.regroup:
					b.regroup = 0.0
					_inv_reset(b)
			else:
				b.interval = maxf(D.beatMin, D.beat * count / b.total)   # ← the tempo rule
				b.timer -= dt
				if b.timer <= 0.0:
					b.timer += b.interval
					b.pose = 1 - b.pose
					var left: float = b.fx + cmin * D.gapX * b.w - 10.0
					var right: float = b.fx + cmax * D.gapX * b.w + 10.0
					if (b.dir > 0 and right + D.step * b.w > b.w) or (b.dir < 0 and left - D.step * b.w < 0.0):
						b.dir = -b.dir
						b.fy += D.drop * b.h
					else:
						b.fx += b.dir * D.step * b.w
					if b.fy + rmax * D.gapY * b.h > b.gy - 14.0:
						_inv_reset(b)                    # landed — the invasion begins again
			b.cannonX += (b.cannonT - b.cannonX) * Kit.smooth(8.0, dt)   # the reader's ship slides to the click
			b.flash -= dt
		"conveyor":
			b.manual -= dt
			b.autoT += dt
			if b.manual <= 0.0 and b.autoT > D.autoFlip:   # left alone, it alternates
				b.autoT = 0.0
				b.up = not b.up
			b.riser.v = Vector2(0.0, -D.speed if b.up else D.speed)
			b.spawnT += dt
			if b.spawnT > D.spawnEvery and b.crates.size() < int(D.maxCrates):
				b.spawnT = 0.0
				b.crates.append({ "p": Vector2(-D.crate, b.feedY + randf_range(-2, 2)), "v": Vector2(D.speed, 0.0),
					"c": Kit.BONE, "lane": -1, "lost": 0.0 })
			var k := Kit.smooth(D.inherit, dt)
			for i in range(b.crates.size() - 1, -1, -1):
				var c: Dictionary = b.crates[i]
				var bl: Dictionary = {}
				for cand in b.order:
					if _on_belt(cand, c):
						bl = cand
						break
				if not bl.is_empty():                    # ← the whole idea: inherit the belt
					c.v += (bl.v - c.v) * k
					c.lost = 0.0
					if is_same(bl, b.belts[1]) and c.lane < 0:
						c.lane = 0
						c.c = Kit.GOOD
					if is_same(bl, b.belts[2]) and c.lane < 0:
						c.lane = 1
						c.c = Kit.MOVER
				else:
					c.v *= 1.0 - 4.0 * dt
					c.lost += dt
				c.p += c.v * dt
				if c.p.x > b.w + D.crate or c.lost > 3.0:
					if c.lane >= 0:
						b.sorted[c.lane] += 1
					b.crates.remove_at(i)
			for i in b.crates.size():                    # crates don't overlap: a nudge apart
				for j in range(i + 1, b.crates.size()):
					var a: Dictionary = b.crates[i]
					var c: Dictionary = b.crates[j]
					var d: Vector2 = c.p - a.p
					var l := _or1(d.length())
					if l < D.crate * 1.2:
						var p: float = (D.crate * 1.2 - l) / 2.0
						a.p -= d / l * p
						c.p += d / l * p


static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	Kit.stage(n, b)
	var D: Dictionary = b.D
	var origin: Vector2 = (b.rect as Rect2).position
	match b.id:
		"magnet":
			for g in b.dust:
				Kit.dot(n, g.p, 1.7, Color(0.91, 0.898, 0.957, 0.7))
			for m in b.mags:
				var col: Color = Kit.TARGET if m.pol > 0.0 else Kit.HOT
				var k := fmod(t * 0.8, 1.0)
				var r: float = 22.0 - k * 14.0 if m.pol > 0.0 else 8.0 + k * 14.0   # breathe in = pull, out = push
				Kit.dot(n, m.p, 5.0, col)
				var ra: float = (0.5 - absf(0.5 - k) * 0.6) if m.pol > 0.0 else (0.55 - k * 0.5)
				Kit.ring(n, m.p, r, Color(col.r, col.g, col.b, ra), 1.5)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"vectorfield":
			var gx := 20.0
			while gx < b.w:                              # sample the field into arrows
				var gy := 20.0
				while gy < b.h:
					var a := _field_angle(D, Vector2(gx, gy), t)
					var d := Vector2(cos(a), sin(a)) * 5.0
					Kit.arrow(n, Vector2(gx, gy) - d, Vector2(gx, gy) + d, Color(0.91, 0.898, 0.957, 0.16))
					gy += D.grid
				gx += D.grid
			for p in b.riders:
				var a := _field_angle(D, p, t)
				var w := Vector2(cos(a), sin(a))
				n.draw_line(p - w * 6.0, p, Color(0.541, 0.851, 0.961, 0.5), 1.0)   # a short wake, against the grain
				Kit.dot(n, p, 2.0, Kit.MOVER)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"swarm":
			for bd in b.boids:
				n.draw_set_transform(origin + bd.p, (bd.v as Vector2).angle(), Vector2.ONE)
				n.draw_colored_polygon(PackedVector2Array([
					Vector2(6, 0), Vector2(-4, 3.4), Vector2(-4, -3.4)]),
					Kit.GOOD if bd.g else Kit.MOVER)
				n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"whirlpool":
			var eye: Vector2 = b.eye
			var gx := 17.0
			while gx < b.w:
				var gy := 17.0
				while gy < b.h:
					var v := _pool_field(b, Vector2(gx, gy))
					var s := _or1(v.length())
					Kit.arrow(n, Vector2(gx, gy) - v / s * 5.0, Vector2(gx, gy) + v / s * 5.0, Color(0.91, 0.898, 0.957, 0.16))
					gy += D.grid
				gx += D.grid
			Kit.ring(n, eye, _pool_R(b), Color(0.788, 0.627, 0.961, 0.18))
			for bit in b.bits:
				var v := _pool_field(b, bit.p)
				var s := _or1(v.length())
				n.draw_line((bit.p as Vector2) - v / s * 5.0, bit.p, Color(0.91, 0.898, 0.957, 0.35), 1.0)   # a wake along the flow
				Kit.dot(n, bit.p, bit.s, Color(0.91, 0.898, 0.957, 0.75))
			for i in 3:                                  # the throat: three rings sinking
				var q := fmod(t * 0.7 + i / 3.0, 1.0)
				Kit.ring(n, eye, D.core * (1.8 - q * 0.9), Color(0.788, 0.627, 0.961, 0.15 + q * 0.5), 1.5)
			Kit.dot(n, eye, D.core * 0.45, Kit.NIGHT)
			Kit.label(n, b, "speed ∝ 1/r", eye + Vector2(D.core + 6.0, 3.0), Color(0.788, 0.627, 0.961, 0.8))
			Kit.label(n, b, "swallowed ×%d" % b.swallowed, Vector2(8, 14), Color(0.788, 0.627, 0.961, 0.7))
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"herd":
			var px0: float = b.px0
			var py0: float = b.py0
			var py1: float = b.py1
			var rail := Color(0.788, 0.769, 0.894, 0.5)
			Kit.line(n, Vector2(px0, py0), Vector2(b.w, py0), rail, 1.5)   # the pen
			Kit.line(n, Vector2(px0, py1), Vector2(b.w, py1), rail, 1.5)
			Kit.line(n, Vector2(px0, py0), Vector2(px0, b.gy0), rail, 1.5)
			Kit.line(n, Vector2(px0, b.gy1), Vector2(px0, py1), rail, 1.5)
			var x := px0
			while x < b.w:
				Kit.dot(n, Vector2(x, py0), 2.0, Kit.BONE)
				Kit.dot(n, Vector2(x, py1), 2.0, Kit.BONE)
				x += 18.0
			var y := py0
			while y < py1:
				if y < b.gy0 or y > b.gy1:
					Kit.dot(n, Vector2(px0, y), 2.0, Kit.BONE)
				y += 18.0
			if b.lure > 0.0:
				var lp := Vector2(px0 - b.w * 0.18, b.gmid)
				Kit.dot(n, lp, 4.0, Kit.TARGET)
				Kit.ring(n, lp, 8.0 + (3.0 - b.lure) * 6.0, Color(0.961, 0.757, 0.412, 0.4))
			for s in b.sheep:
				Kit.dot(n, s.p, 6.0, Kit.BONE)
				Kit.dot(n, (s.p as Vector2) + Vector2(cos(s.h), sin(s.h)) * 5.5, 3.0, Color("4A4560"))   # the blackface
			if b.dog.on:
				Kit.ring(n, b.dog.p, D.dogR, Color(0.961, 0.541, 0.541, 0.18))
				var c := Vector2.ZERO
				for s in b.sheep:
					c += s.p
				Kit.mote(n, b, b.dog.p, (c / D.n - b.dog.p as Vector2).angle(), Kit.HOT, 6.0)
			Kit.label(n, b, "penned %d/%d" % [b.penned, int(D.n)], Vector2(8, 14), Color(0.788, 0.769, 0.894, 0.7))
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"xing":
			var y0: float = b.y0
			var y1: float = b.y1
			Kit.line(n, Vector2(0, y0), Vector2(b.w, y0), Color(0.788, 0.769, 0.894, 0.45), 1.5)   # the kerbs
			Kit.line(n, Vector2(0, y1), Vector2(b.w, y1), Color(0.788, 0.769, 0.894, 0.45), 1.5)
			var x := 6.0
			while x < b.w:
				Kit.rect(n, Rect2(x, y0, 10.0, y1 - y0), Color(0.788, 0.769, 0.894, 0.05))
				x += 24.0
			if not (b.urgent as Array).is_empty():       # the nearest miss, made visible
				var u: Array = b.urgent
				Kit.ring(n, u[0], D.minDist / 2.0, Color(0.961, 0.541, 0.541, 0.45))
				Kit.line(n, u[0], u[1], Color(0.961, 0.541, 0.541, 0.45))
				Kit.line(n, (u[2] as Dictionary).p, u[0], Kit.DIM)
			for w in b.walkers:
				Kit.mote(n, b, w.p, (w.v as Vector2).angle(), Kit.MOVER if w.dir > 0 else Kit.GOOD, 5.0)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"invaders":
			Kit.ground(n, b)
			var cols: int = D.cols
			for i in int(b.total):
				if not b.alive[i]:
					continue
				var x: float = _inv_ix(b, i) + sin(t * 3.0 + (i % cols) * 0.9) * D.wobble
				var y: float = _inv_iy(b, i)
				Kit.rect(n, Rect2(x - 6.0, y - 3.0, 12.0, 6.0), Kit.MAGIC)   # a pixel invader, two poses
				Kit.rect(n, Rect2(x - 4.0, y - 6.0, 2.0, 3.0), Kit.MAGIC)
				Kit.rect(n, Rect2(x + 2.0, y - 6.0, 2.0, 3.0), Kit.MAGIC)
				Kit.rect(n, Rect2(x - 3.0, y - 2.0, 2.0, 2.0), Kit.NIGHT)
				Kit.rect(n, Rect2(x + 1.0, y - 2.0, 2.0, 2.0), Kit.NIGHT)
				if b.pose == 1:
					Kit.rect(n, Rect2(x - 7.0, y + 3.0, 3.0, 2.0), Kit.MAGIC)
					Kit.rect(n, Rect2(x + 4.0, y + 3.0, 3.0, 2.0), Kit.MAGIC)
				else:
					Kit.rect(n, Rect2(x - 4.0, y + 3.0, 2.0, 3.0), Kit.MAGIC)
					Kit.rect(n, Rect2(x + 2.0, y + 3.0, 2.0, 3.0), Kit.MAGIC)
			if b.flash > 0.0:
				Kit.line(n, Vector2(b.cannonX, b.gy - 10.0), b.hit, Kit.HOT, 2.0)
				Kit.ring(n, b.hit, 6.0 + (0.18 - b.flash) * 80.0, Color(0.961, 0.541, 0.541, b.flash / 0.18), 2.0)
			Kit.mote(n, b, Vector2(b.cannonX, b.gy - 8.0), -PI / 2.0, Kit.MOVER, 7.0)
			Kit.label(n, b, "interval %.2f s · %d/%d alive" % [b.interval, b.get("count", b.total), b.total], Vector2(8, 14), Color(0.788, 0.627, 0.961, 0.75))
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"conveyor":
			var up: bool = b.up
			var all: Array = (b.belts as Array).duplicate()
			all.append(b.riser)
			for bl in all:
				var r: Rect2 = bl.r
				Kit.rect(n, r, Color(0.788, 0.769, 0.894, 0.07))
				Kit.line(n, r.position, Vector2(r.end.x, r.position.y), Kit.DIM)
				Kit.line(n, Vector2(r.position.x, r.end.y), r.end, Kit.DIM)
				var sp: float = D.chevron
				var off := fposmod(t * D.speed, sp)
				if bl.v.x != 0.0:                        # scrolling chevrons: › › › ›
					var my := r.position.y + r.size.y / 2.0
					var x := r.position.x + off
					while x < r.end.x - 2.0:
						Kit.poly(n, [Vector2(x, my - 4.0), Vector2(x + 4.0, my), Vector2(x, my + 4.0)], Color(0.91, 0.898, 0.957, 0.22), 1.0)
						x += sp
				else:                                    # the riser's point up or down
					var mx := r.position.x + r.size.x / 2.0
					var s: float = 1.0 if up else -1.0
					var y := r.position.y + (sp - off if up else off)
					while y < r.end.y - 2.0:
						Kit.poly(n, [Vector2(mx - 4.0, y + 4.0 * s), Vector2(mx, y), Vector2(mx + 4.0, y + 4.0 * s)], Color(0.91, 0.898, 0.957, 0.22), 1.0)
						y += sp
			var rr: Rect2 = b.riser.r                    # the gate paddle
			var feedY: float = b.feedY
			var gateX: float = b.gateX
			Kit.line(n, Vector2(gateX, feedY), Vector2(gateX + rr.size.x * 0.9, feedY - rr.size.x * 0.6 if up else feedY + rr.size.x * 0.6), Kit.TARGET, 3.0)
			Kit.dot(n, Vector2(gateX, feedY), 3.5, Kit.TARGET)
			for c in b.crates:
				Kit.rect(n, Rect2(c.p.x - D.crate / 2.0, c.p.y - D.crate / 2.0, D.crate, D.crate), c.c)
				Kit.line(n, Vector2(c.p.x - D.crate / 2.0 + 2.0, c.p.y), Vector2(c.p.x + D.crate / 2.0 - 2.0, c.p.y), Kit.NIGHT)
			var b1: Rect2 = b.belts[1].r
			var b2: Rect2 = b.belts[2].r
			_label_right(n, "▲ %d" % b.sorted[0], Vector2(b.w - 8.0, b1.position.y - 4.0), Color(0.608, 0.886, 0.541, 0.8))
			_label_right(n, "▼ %d" % b.sorted[1], Vector2(b.w - 8.0, b2.end.y + 12.0), Color(0.541, 0.851, 0.961, 0.8))
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
