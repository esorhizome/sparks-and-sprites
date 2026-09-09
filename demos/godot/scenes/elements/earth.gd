extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
## EARTH & STONE — eight buttons, ported from the web bestiary.

const TITLE := "Earth & stone"
const BLURB := "cracks, crumbles, sand, and tectonic grudges"
const DEFS := [
	{ "id": "fault_line", "name": "Fault line", "hint": "a glowing crack crosses the face; press for the earthquake" },
	{ "id": "crumble", "name": "Crumble", "hint": "press and the face collapses into rubble — then each shard springs home, clacks past its slot, and settles" },
	{ "id": "sandstorm", "name": "Sandstorm", "hint": "grains stream past and gnaw the edges; press for a gust" },
	{ "id": "landslide", "name": "Landslide", "hint": "pebbles trickle down the face; press to let the whole slope go" },
	{ "id": "geode", "name": "Geode", "hint": "plain rock outside; press and the halves crack apart on a spring — past the stop, rocking back — then close on the sparkle" },
	{ "id": "tectonic", "name": "Tectonic", "hint": "three plates creep on a slow drive, stick while the seam loads, then slip in a jerk — the grind is stress building and letting go; press to shove the outer plates in" },
	{ "id": "quicksand", "name": "Quicksand", "hint": "the caption sinks with velocity through thick sand; press to yank it — it surges, the drag stops it, it sinks back" },
	{ "id": "boulder", "name": "Boulder", "hint": "a boulder patrols overhead; press and it drops on the button" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	var r: Rect2 = b.rect
	match b.id:
		"fault_line":
			b.crack = []
			var x := 0.0
			var y := r.size.y / 2.0 + randf_range(-6, 6)
			while x < r.size.x:
				b.crack.append(Vector2(x, y))
				x += randf_range(8, 18)
				y = clampf(y + randf_range(-6, 6), 8, r.size.y - 8)
			b.crack.append(Vector2(r.size.x, y))
		"crumble":
			# the collapse was always honest ballistics; the rebuild used to lerp
			# home. now every shard keeps a velocity all the way: the rise is a
			# damped spring toward its slot, under critical, so the rubble flies
			# past the face and clacks back, and the spin unwinds on the same spring
			b.grav = 240.0                 # the fall, px/s²
			b.fall = 1.1                   # seconds of free fall before the rebuild takes hold
			b.k_home = 45.0                # the rebuild spring: px/s² per px from home
			b.damp_home = 0.55             # as a fraction of critical (2√k): under 1, so rubble overshoots its slot
			b.settle = 2.6                 # the longest the rebuild may take before it's declared solid
			b.mode = "solid"
			b.mode_t = 0.0
			b.shards = []
			var cols := 8
			var rows := 3
			for cx in cols:
				for cy in rows:
					b.shards.append({ "home": Vector2(cx * r.size.x / cols, cy * r.size.y / rows),
						"pos": Vector2.ZERO, "vel": Vector2.ZERO, "rot": 0.0, "vr": 0.0 })
			b.sw = r.size.x / cols
			b.sh = r.size.y / rows
		"sandstorm":
			b.grains = []
			for i in 40:
				b.grains.append({ "pos": Vector2(randf_range(-10, r.size.x + 10), randf_range(-14, r.size.y + 14)),
					"v": randf_range(30, 90) })
		"geode":
			b.D = { "k": 60.0,          # the crack's spring, 1/s² (ω ≈ 7.7 rad/s)
				"zeta": 0.25,           # damping while opening, as a fraction of critical — it overshoots the stop and rocks back
				"closeZeta": 1.1,       # damping while closing — over critical, so the halves settle shut without a bounce
				"crack": 60.0,          # the press: outward speed injected the instant it cracks, px/s
				"stop": 14.0,           # the open gap the spring aims for, px
				"hold": 1.6 }           # seconds held open (once it has arrived) before the close
			# the gap between the halves is a spring toward a target: the stop when
			# opening, zero when closing. the press moves the target and throws in a
			# little outward speed — the crack — and the lightly damped spring carries
			# the halves past the stop and rocks them back. the close uses a heavier
			# damping on the same spring, so it settles rather than slams.
			b.gap = 0.0                 # the gap between the halves, px
			b.gap_v = 0.0               # and its speed, px/s
			b.target = 0.0              # where the spring is aiming: stop or 0
			b.held = 0.0                # seconds spent resting at the stop
			b.open = 0.0                # gap / stop, clipped to 1 — what the painter reads
			b.glitter = []
			for i in 12:
				b.glitter.append({ "pos": Vector2(randf_range(14, r.size.x - 14), randf_range(8, r.size.y - 8)),
					"ph": randf_range(0, 9) })
		"tectonic":
			b.D = { "creep": 2.0,       # the drive's crawl, px/s — the outer plates are pushed inward this slowly
				"range": 5.0,           # how far the drive walks before it reverses (convergence, then rift), px
				"k": 80.0,              # the drive-to-plate spring: stress = k · (drive − plate), px/s² per px
				"stick": 200.0,         # static friction — the stress a stuck plate holds before it lets go, px/s²
				"slide": 60.0,          # sliding friction — the constant drag on a moving plate, px/s²
				"damp": 2.0,            # a little viscous loss while sliding, 1/s
				"shove": 6.0 }          # the press: how far the outer drives jump inward, px
			# stick-slip. each outer plate is a block on a spring whose far end (the
			# drive) creeps inward and, at the range, turns round. while the block is
			# stuck the spring loads; the moment the load beats static friction it lets
			# go and slides — under the spring minus a smaller sliding friction — until
			# it stops and grips again, having overshot. the middle plate is squeezed
			# toward the mean of its neighbours. the seams glow with the stress they
			# hold; the jerks are the grind.
			var zero := PackedFloat32Array([0.0, 0.0, 0.0])
			b.px = zero.duplicate()         # each plate's offset, px
			b.pv = zero.duplicate()         # each plate's speed, px/s (0 = stuck)
			b.dr = zero.duplicate()         # each drive's position, px
			b.stress = zero.duplicate()     # each plate's load as a fraction of stick
			b.dir = PackedFloat32Array([1.0, 0.0, -1.0])   # which way each drive is walking
		"quicksand":
			# the caption has a VELOCITY: the sand pulls down and drags with speed,
			# so left alone it creeps at a terminal sink; the press is an impulse,
			# and the drag decides how far the surge carries
			b.pull = 9.6                   # the sand's pull, px/s²
			b.drag = 6.0                   # its viscous drag, per second: terminal sink = pull / drag = 1.6 px/s
			b.yank = 84.0                  # the press: an upward impulse, px/s (about 12 px before the sand wins)
			b.sink = 0.0
			b.v = 0.0
		"boulder":
			b.bx = -12.0
			b.by = -22.0
			b.vy = 0.0
			b.falling = false
			b.rot = 0.0
			b.squash = 0.0

static func press(b: Dictionary, _pos: Vector2) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"fault_line":
			b.press_v = 1.0
			for i in 10:
				b.parts.append({ "pos": Vector2(randf_range(0, r.size.x), r.size.y),
					"vel": Vector2(randf_range(-30, 30), randf_range(-80, -20)), "life": 1.0 })
		"crumble":
			if b.mode == "solid":
				b.mode = "falling"
				b.mode_t = 0.0
				for s in b.shards:
					s.pos = s.home
					s.vel = Vector2(randf_range(-20, 20), randf_range(-40, 10))
					s.rot = 0.0
					s.vr = randf_range(-3, 3)
		"sandstorm":
			b.press_v = 1.0
		"quicksand":
			b.press_v = 1.0
			b.v -= float(b.yank)           # yanked: velocity in, the drag decides how far it goes
		"landslide":
			b.press_v = 1.0
			for i in 18:
				b.parts.append({ "pos": Vector2(randf_range(4, r.size.x - 4), 2.0),
					"vel": Vector2(0, randf_range(10, 30)), "r": randf_range(1.2, 2.6) })
		"geode":
			b.target = float(b.D.stop)     # aim for the stop...
			b.held = 0.0
			b.gap_v += float(b.D.crack)    # ...and crack: a jolt of outward speed
		"tectonic":
			var dr: PackedFloat32Array = b.dr
			var rng: float = b.D.range
			var shove: float = b.D.shove
			dr[0] = minf(rng * 2.0, dr[0] + shove)   # the outer drives jump inward
			dr[2] = maxf(-rng * 2.0, dr[2] - shove)
			b.dr = dr
			for i in 8:
				b.parts.append({ "pos": Vector2(r.size.x * (0.33 + (i % 2) * 0.34) + randf_range(-4, 4), r.size.y / 2.0),
					"vel": Vector2(0, randf_range(-50, -20)), "life": 1.0 })
		"boulder":
			if not b.falling:
				b.falling = true
				b.vy = 0.0

static func tick(b: Dictionary, dt: float, t: float) -> void:
	b.press_v = maxf(0.0, b.press_v - dt * (0.5 if b.id == "landslide" else 1.4))
	var r: Rect2 = b.rect
	match b.id:
		"fault_line":
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += 200.0 * dt
				p.life -= dt * 1.2
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"crumble":
			b.mode_t += dt
			if b.mode == "falling":
				for s in b.shards:
					s.pos += s.vel * dt
					s.vel.y += float(b.grav) * dt
					s.rot += s.vr * dt
				if b.mode_t > float(b.fall):
					b.mode = "rising"
					b.mode_t = 0.0
			elif b.mode == "rising":       # every shard springs home, keeping its velocity
				var k: float = b.k_home
				var d: float = b.damp_home * 2.0 * sqrt(k)
				var sub := maxi(1, ceili(dt * 50.0))
				var h := dt / float(sub)
				var settled := true
				for s in b.shards:
					for _s in sub:
						s.vel += (k * (s.home - s.pos) - d * s.vel) * h
						s.pos += s.vel * h
						s.vr += (k * (0.0 - s.rot) - d * s.vr) * h
						s.rot += s.vr * h
					if (s.pos - s.home).length() > 0.4 or s.vel.length() > 3.0:
						settled = false
				if settled or b.mode_t > float(b.settle):
					b.mode = "solid"
		"sandstorm":
			var wind: float = 1.0 + b.press_v * 3.0
			for g in b.grains:
				g.pos.x += g.v * wind * dt
				g.pos.y += sin(g.pos.x * 0.05) * 10.0 * dt
				if g.pos.x > r.size.x + 6.0:
					g.pos = Vector2(-6.0, randf_range(-14, r.size.y + 14))
		"landslide":
			if randf() < 0.06 + b.press_v * 0.5:
				b.parts.append({ "pos": Vector2(randf_range(4, r.size.x - 4), 2.0),
					"vel": Vector2(0, randf_range(10, 30)), "r": randf_range(1.2, 2.6) })
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += 60.0 * dt
				p.pos.x += sin(p.pos.y * 0.3) * 6.0 * dt
			b.parts = b.parts.filter(func(p): return p.pos.y < r.size.y + 40.0)
		"geode":
			var D: Dictionary = b.D
			var k: float = D.k
			var stop: float = D.stop
			var target: float = b.target
			var damp: float = float(D.zeta if target > 0.0 else D.closeZeta) * 2.0 * sqrt(k)
			var gap: float = b.gap
			var gap_v: float = b.gap_v
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / sub
			for _s in sub:
				gap_v += (k * (target - gap) - damp * gap_v) * h
				gap += gap_v * h
				if gap < 0.0:               # the halves cannot overlap
					gap = 0.0
					gap_v = 0.0
			gap = minf(gap, stop * 3.0)
			if target > 0.0 and absf(gap - target) < 1.0 and absf(gap_v) < 5.0:
				b.held += dt
			if b.held > float(D.hold):      # arrived and rested → the close takes over
				b.target = 0.0
			b.gap = gap
			b.gap_v = gap_v
			b.open = minf(1.0, gap / stop)
		"tectonic":
			var D: Dictionary = b.D
			var creep: float = D.creep
			var rng: float = D.range
			var k: float = D.k
			var stick: float = D.stick
			var slide: float = D.slide
			var damp: float = D.damp
			var px: PackedFloat32Array = b.px
			var pvel: PackedFloat32Array = b.pv
			var dr: PackedFloat32Array = b.dr
			var dir: PackedFloat32Array = b.dir
			var stress: PackedFloat32Array = b.stress
			var rate := [1.0, 0.0, 0.7]     # the right-hand drive is the slower one, so the seams never sync
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / sub
			for _s in sub:
				for p in [0, 2]:            # the drives creep, and turn at the range
					dr[p] += dir[p] * creep * rate[p] * h
					if absf(dr[p]) > rng and dr[p] * dir[p] > 0.0:
						dir[p] = -dir[p]
				dr[1] = (px[0] + px[2]) * 0.5   # the middle plate: squeezed by both neighbours
				for p in 3:
					var F := k * (dr[p] - px[p])
					stress[p] = absf(F) / stick
					if pvel[p] == 0.0:      # stuck: hold until the load beats static friction
						if absf(F) <= stick:
							continue
						pvel[p] = signf(F) * 1e-3
					var v0 := pvel[p]
					pvel[p] += (F - slide * signf(pvel[p]) - damp * pvel[p]) * h
					if pvel[p] * v0 <= 0.0:  # it stopped: friction grips again
						pvel[p] = 0.0
					px[p] = clampf(px[p] + pvel[p] * h, -rng * 3.0, rng * 3.0)
			b.px = px
			b.pv = pvel
			b.dr = dr
			b.dir = dir
			b.stress = stress
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel *= pow(0.1, dt)
				p.life -= dt * 0.9
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"quicksand":
			b.v += (float(b.pull) - float(b.drag) * b.v) * dt   # the sand always wins, slowly
			b.sink += b.v * dt
			if b.sink < -8.0:              # as far out as it comes
				b.sink = -8.0
				b.v = maxf(0.0, b.v)
			if b.sink > r.size.y * 0.75:   # as deep as it goes
				b.sink = r.size.y * 0.75
				b.v = minf(0.0, b.v)
		"boulder":
			if not b.falling:
				b.bx += 40.0 * dt
				b.rot += 3.0 * dt
				if b.bx > r.size.x + 12.0:
					b.bx = -12.0
			else:
				b.vy += 500.0 * dt
				b.by += b.vy * dt
				b.rot += 6.0 * dt
				if b.by > -8.0:            # impact with the button's top edge
					if b.vy > 60.0:
						b.squash = 1.0
						for i in 10:
							b.parts.append({ "pos": Vector2(b.bx + randf_range(-6, 6), 0.0),
								"vel": Vector2(randf_range(-60, 60), randf_range(-40, -5)), "life": 1.0 })
						b.vy = -b.vy * 0.4
					else:
						b.falling = false
						b.by = -22.0
						b.vy = 0.0
					b.by = minf(b.by, -8.0)
			b.squash = maxf(0.0, b.squash - dt * 4.0)
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += 80.0 * dt
				p.life -= dt * 1.8
			b.parts = b.parts.filter(func(p): return p.life > 0.0)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	match b.id:
		"fault_line":
			var sh: float = pv * pv * 5.0
			var rr := Rect2(r.position + Vector2(randf_range(-sh, sh), randf_range(-sh, sh)), r.size)
			ElemKit.face(n, rr, Color(0.14, 0.11, 0.094), Color(0.78, 0.67, 0.51, 0.5))
			var glow: float = 0.45 + 0.3 * sin(t * 1.8) + pv * 0.5
			var crack: Array = b.crack
			for i in range(crack.size() - 1):
				n.draw_line(rr.position + crack[i], rr.position + crack[i + 1],
					Color(1, 0.59, 0.24, minf(1.0, glow)), 1.6 + pv * 2.0)
			ElemKit.label(n, rr, "RICHTER", Color(0.92, 0.87, 0.78))
			for p in b.parts:
				n.draw_rect(Rect2(o + p.pos, Vector2(2.4, 2.4)), Color(0.7, 0.59, 0.43, p.life))
		"crumble":
			if b.mode == "solid":
				ElemKit.face(n, r, Color(0.165, 0.13, 0.094), Color(0.75, 0.63, 0.47, 0.55))
				ElemKit.label(n, r, "CRUMBLE", Color(0.91, 0.86, 0.78))
				if randf() < 0.05:
					n.draw_rect(Rect2(o + Vector2(randf_range(0, r.size.x), r.size.y + randf_range(0, 4)),
						Vector2(1.5, 1.5)), Color(0.67, 0.59, 0.47, 0.5))
			else:
				for s in b.shards:
					n.draw_set_transform(o + s.pos + Vector2(b.sw, b.sh) / 2.0, s.rot, Vector2.ONE)
					n.draw_rect(Rect2(-Vector2(b.sw, b.sh) / 2.0 + Vector2(0.5, 0.5),
						Vector2(b.sw - 1, b.sh - 1)), Color(0.165, 0.13, 0.094))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"sandstorm":
			ElemKit.face(n, r, Color(0.2, 0.157, 0.106), Color(0.86, 0.75, 0.55, 0.5))
			ElemKit.label(n, r, "ERODE", Color(0.94, 0.89, 0.78))
			for i in 10:                     # nicks chewing the lit border
				var ex := o.x + fmod(i * 37.0 + floorf(t * 2.0) * 13.0, r.size.x)
				n.draw_rect(Rect2(ex, o.y - 1 if i % 2 == 0 else o.y + r.size.y - 1, 3.5, 2), Color(0.078, 0.067, 0.12))
			for g in b.grains:
				n.draw_rect(Rect2(o + g.pos, Vector2(1.6, 1.2)), Color(0.88, 0.76, 0.55, 0.25 + pv * 0.4))
		"landslide":
			var lean: float = pv * sin(t * 30.0) * 0.01
			n.draw_set_transform(r.get_center(), lean, Vector2.ONE)
			ElemKit.face(n, Rect2(-r.size / 2.0, r.size), Color(0.17, 0.13, 0.09), Color(0.78, 0.67, 0.51, 0.5))
			ElemKit.label(n, Rect2(-r.size / 2.0, r.size), "SCREE", Color(0.91, 0.86, 0.78))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for p in b.parts:
				n.draw_circle(o + p.pos, p.r, Color(0.75, 0.65, 0.51, 0.85))
		"geode":
			var gap: float = b.gap           # the spring's own gap — past the stop when it overshoots
			if b.open > 0.05:                # the amethyst interior, revealed
				ElemKit.face(n, r, Color(0.17, 0.11, 0.27))
				for gl in b.glitter:
					var a: float = maxf(0.0, sin(t * 4.0 + gl.ph)) * b.open
					ElemKit.twinkle(n, o + gl.pos, 3.0, Color(0.86, 0.71, 1.0, a))
			for side in [-1.0, 1.0]:         # the two rock halves slide apart
				var half := Rect2(o + Vector2(side * gap / 2.0, 0), Vector2(r.size.x / 2.0, r.size.y))
				if side > 0:
					half.position.x += r.size.x / 2.0
				n.draw_rect(half, Color(0.18, 0.15, 0.125, 1.0 - b.open * 0.15))
			ElemKit.ring_face(n, r.grow(gap / 2.0), Color(0.71, 0.63, 0.55, 0.5))
			if b.open < 0.4:
				ElemKit.label(n, r, "GEODE", Color(0.9, 0.85, 0.8))
		"tectonic":
			var pw := r.size.x / 3.0
			var px: PackedFloat32Array = b.px
			var pvel: PackedFloat32Array = b.pv
			var stress: PackedFloat32Array = b.stress
			for p in 3:                      # each plate sits where its own history put it
				var plate := Rect2(o + Vector2(p * pw + px[p], 0.0), Vector2(pw, r.size.y))
				n.draw_rect(plate, Color(0.157, 0.13, 0.1))
				n.draw_rect(plate, Color(0.75, 0.65, 0.49, 0.4), false, 1.0)
			ElemKit.label(n, r, "PANGAEA", Color(0.91, 0.86, 0.78))
			for p in range(1, 3):            # the grinding seams: lit by the stress they hold, and by the slip
				var sx := o.x + p * pw
				var load: float = minf(1.0, maxf(stress[p - 1], stress[p]))
				var slip: float = minf(1.0, (absf(pvel[p - 1]) + absf(pvel[p])) / 20.0)
				n.draw_line(Vector2(sx, o.y), Vector2(sx, o.y + r.size.y),
					Color(1, 0.55, 0.24, 0.2 + load * 0.5 + slip * 0.3), 1.0 + slip * 2.0)
			for p in b.parts:
				var pos: Vector2 = o + p.pos
				var poly := PackedVector2Array([pos + Vector2(-4, 4), pos + Vector2(0, -4), pos + Vector2(4, 4)])
				n.draw_colored_polygon(poly, Color(0.78, 0.69, 0.53, p.life))
		"quicksand":
			ElemKit.face(n, r, Color(0.23, 0.18, 0.11), Color(0.82, 0.71, 0.51, 0.5))
			var lr := Rect2(r.position + Vector2(0, b.sink), r.size)
			var submerged: float = clampf(1.0 - b.sink / (r.size.y * 0.4), 0.15, 1.0)
			ElemKit.label(n, lr, "HELP", Color(0.94, 0.89, 0.78, submerged))
			var poly := PackedVector2Array()   # the sand surface, swallowing
			poly.append(o + Vector2(0, r.size.y))
			poly.append(o + Vector2(0, r.size.y * 0.55))
			var x := 0.0
			while x <= r.size.x:
				poly.append(o + Vector2(x, r.size.y * 0.55 + sin(x * 0.15 + t * 1.2) * 1.5))
				x += 6.0
			poly.append(o + Vector2(r.size.x, r.size.y))
			n.draw_colored_polygon(poly, Color(0.29, 0.23, 0.14))
			if randf() < 0.04:
				ElemKit.ellipse(n, o + Vector2(r.size.x / 2.0 + randf_range(-20, 20), r.size.y * 0.55),
					randf_range(4, 9), 2.0, Color(0.86, 0.76, 0.55, 0.4), 1.0)
		"boulder":
			ElemKit.face(n, r, Color(0.165, 0.137, 0.11), Color(0.75, 0.65, 0.51, 0.55))
			ElemKit.label(n, r, "LOOK UP", Color(0.91, 0.86, 0.78))
			n.draw_set_transform(o + Vector2(b.bx, b.by), b.rot,
				Vector2(1.0 + b.squash * 0.3, 1.0 - b.squash * 0.3))
			n.draw_circle(Vector2.ZERO, 8.0, Color(0.34, 0.29, 0.23))
			n.draw_circle(Vector2(-2.5, -2), 1.6, Color(0.12, 0.094, 0.07, 0.5))
			n.draw_circle(Vector2(3, 1.5), 1.2, Color(0.12, 0.094, 0.07, 0.5))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for p in b.parts:
				n.draw_rect(Rect2(o + p.pos, Vector2(2, 2)), Color(0.71, 0.63, 0.51, p.life * 0.7))
