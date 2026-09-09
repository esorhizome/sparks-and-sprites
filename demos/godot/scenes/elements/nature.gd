extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
## NATURE & GROWTH — six buttons, ported from the web bestiary.

const TITLE := "Nature & growth"
const BLURB := "vines, spores, swarms, and glowing tides"
const DEFS := [
	{ "id": "vine", "name": "Vine growth", "hint": "vines wind along the border, every leaf on its own stalk spring leaning with the wind; press to bloom — the pop kicks each leaf" },
	{ "id": "pollen", "name": "Pollen field", "hint": "spores hang in the light; press to puff them everywhere" },
	{ "id": "mycelium", "name": "Mycelium", "hint": "threads creep across the dark; press to pulse light down the network" },
	{ "id": "swarm", "name": "Swarm", "hint": "every bee a body with velocity steering for its orbit through drag and buzz; press to scatter them, and they spiral back" },
	{ "id": "rainforest", "name": "Rainforest", "hint": "drips and falling leaves; press for the downpour" },
	{ "id": "sea_sparkle", "name": "Sea sparkle", "hint": "an unseen current wakes glowing algae; press to stir the water" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	var r: Rect2 = b.rect
	match b.id:
		"vine":
			# each leaf is one ANGLE on a damped spring. the wind (two slow sines per
			# leaf, an input like weather) moves the rest, so the leaves lean and
			# recover with lag; the bloom's pop hands every leaf a random angular
			# velocity and the stalk rings it down. nothing is placed by the clock
			b.k = 30.0                     # a leaf's stalk: torque per radian of twist from its rest, s⁻²
			b.damp = 0.3                   # its damping as a fraction of critical (2√k): under 1, so a kicked leaf swings
			b.wind = 0.2                   # how far the wind can lean a leaf, radians — the wind moves the REST
			b.pop = 6.0                    # the bloom's kick: angular velocity handed to each leaf, rad/s (±)
			b.nodes = []
			for i in 41:
				var a := -PI / 2.0 + i / 40.0 * TAU
				b.nodes.append({ "pos": r.size / 2.0 + Vector2(cos(a) * r.size.x * 0.54 + sin(i * 2.2) * 2.0,
					sin(a) * r.size.y * 0.72 + cos(i * 1.7) * 2.0),
					"leaf": i % 5 == 2, "la": randf_range(0, TAU), "th": 0.0, "om": 0.0 })
		"pollen":
			b.motes = []
			for i in 18:
				b.motes.append({ "pos": Vector2(randf_range(0, r.size.x), randf_range(0, r.size.y)),
					"vel": Vector2.ZERO, "ph": randf_range(0, TAU) })
		"mycelium":
			b.threads = []
			_branch(b, Vector2(0, randf_range(6, r.size.y - 6)), randf_range(-0.3, 0.3), 0)
			_branch(b, Vector2(0, randf_range(6, r.size.y - 6)), randf_range(-0.3, 0.3), 0)
			_branch(b, Vector2(0, randf_range(6, r.size.y - 6)), randf_range(-0.3, 0.3), 0)
			b.pulse = -1.0
		"swarm":
			# each bee is a POSITION with a VELOCITY. its orbit spot moves round the
			# ellipse; the bee is pulled toward it by a steering spring and slowed by
			# drag — under-damped, so it loops around the spot rather than sitting on
			# it. the buzz is random force; the scatter an impulse straight out, and
			# because the spot keeps moving the return is a spiral
			b.k = 25.0                     # steering: pull toward the orbit spot, px/s² per px of error
			b.drag = 3.0                   # air drag per second — with k it sets the spiral (ζ = drag / 2√k, here 0.3)
			b.buzz = 400.0                 # random jitter force, px/s² — the wobble is a force, not a sine
			b.scatter = 260.0              # the press: an outward impulse, px/s
			b.bees = []
			for i in 18:
				var a := randf_range(0, TAU)
				var rr := r.size.x * 0.34
				b.bees.append({ "a": a, "va": randf_range(0.8, 1.6), "panic": 0.0,
					"pos": r.size / 2.0 + Vector2(cos(a) * rr * 1.25, sin(a) * rr * 0.55), "vel": Vector2.ZERO })
		"sea_sparkle":
			b.wake = []

static func _branch(b: Dictionary, from: Vector2, angle: float, depth: int) -> void:
	var r: Rect2 = b.rect
	if depth > 3 or from.x > r.size.x:
		return
	var pts := [from]
	var p := from
	var a := angle
	for s in 5:
		a += randf_range(-0.4, 0.4)
		p += Vector2(cos(a) * randf_range(8, 14), sin(a) * randf_range(3, 6))
		p.y = clampf(p.y, 3, r.size.y - 3)
		pts.append(p)
	b.threads.append({ "pts": pts })
	if randf() < 0.8:
		_branch(b, p, a + randf_range(-0.9, 0.9), depth + 1)

static func press(b: Dictionary, pos: Vector2) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"rainforest":
			b.press_v = 1.0
		"vine":
			b.press_v = 1.0
			for nd in b.nodes:             # the pop: a kick, no teleport
				if nd.leaf:
					nd.om += randf_range(-b.pop, b.pop)
		"pollen":
			for m in b.motes:
				var d: Vector2 = m.pos - r.size / 2.0
				m.vel += d / maxf(8.0, d.length()) * 130.0
		"mycelium":
			b.pulse = 0.0
		"swarm":
			for bee in b.bees:             # the scatter: an impulse away from the hive, in the ellipse's frame
				var d := Vector2((bee.pos.x - r.size.x / 2.0) / 1.25, (bee.pos.y - r.size.y / 2.0) / 0.55)
				var len := maxf(4.0, d.length())
				var s: float = b.scatter * randf_range(0.7, 1.3)
				bee.vel += Vector2(d.x / len * s * 1.25, d.y / len * s * 0.55)
		"sea_sparkle":
			for i in 14:
				var th := randf_range(0, TAU)
				b.parts.append({ "pos": pos, "vel": Vector2(cos(th), sin(th)) * randf_range(10, 50), "life": 1.0 })

static func tick(b: Dictionary, dt: float, t: float) -> void:
	b.press_v = maxf(0.0, b.press_v - dt * (0.35 if b.id == "vine" else 0.6))
	var r: Rect2 = b.rect
	match b.id:
		"vine":
			var k: float = b.k
			var d: float = b.damp * 2.0 * sqrt(k)
			var wind: float = b.wind
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			for nd in b.nodes:
				if not nd.leaf:
					continue
				var rest: float = (sin(t * 0.7 + nd.la) + 0.4 * sin(t * 1.9 + nd.la * 2.0)) * wind   # the wind's ask
				for _s in sub:
					nd.om += (k * (rest - nd.th) - d * nd.om) * h
					nd.th = clampf(nd.th + nd.om * h, -1.2, 1.2)
		"pollen":
			for m in b.motes:
				m.pos += (m.vel + Vector2(sin(t * 0.8 + m.ph) * 4.0, cos(t * 0.6 + m.ph) * 3.0 - 2.0)) * dt
				m.vel *= pow(0.25, dt)
				m.pos.x = fposmod(m.pos.x, r.size.x)
				m.pos.y = fposmod(m.pos.y, r.size.y)
		"mycelium":
			if b.pulse >= 0.0:
				b.pulse += dt * 1.4
				if b.pulse > 1.4:
					b.pulse = -1.0
		"swarm":
			var k: float = b.k
			var drag: float = b.drag
			var buzz: float = b.buzz
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			for bee in b.bees:
				bee.panic = maxf(0.0, bee.panic - dt * 0.6)
				bee.a += bee.va * (1.0 + bee.panic * 1.5) * dt
				var lift: float = 0.4 if bee.panic > 0.5 else 0.0      # the orbitals rhyme: a jump to the next shell
				var rr: float = r.size.x * 0.34 * (1.0 + lift)
				var spot := r.size / 2.0 + Vector2(cos(bee.a) * rr * 1.25, sin(bee.a) * rr * 0.55)   # where it's steering for
				bee.vel += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * buzz * dt
				for _s in sub:
					bee.vel += (k * (spot - bee.pos) - drag * bee.vel) * h
					bee.pos += bee.vel * h
		"rainforest":
			if randf() < 0.06 + b.press_v * 0.6:
				b.parts.append({ "kind": "drip", "pos": Vector2(randf_range(0, r.size.x), r.size.y),
					"vel": Vector2(0, randf_range(30, 60)) })
			if randf() < 0.02 + b.press_v * 0.12:
				b.parts.append({ "kind": "leaf", "pos": Vector2(randf_range(-10, r.size.x + 10), -14.0),
					"vel": Vector2(0, 26), "ph": randf_range(0, 9), "rot": randf_range(0, 6) })
			for p in b.parts:
				p.pos += p.vel * dt
				if p.kind == "drip":
					p.vel.y += 220.0 * dt
				else:
					p.pos.x += sin(t * 1.6 + p.ph) * 14.0 * dt
					p.rot += dt * 2.0
			b.parts = b.parts.filter(func(p): return p.pos.y < r.size.y + 30.0)
		"sea_sparkle":
			var cur := r.size / 2.0 + Vector2(sin(t * 0.7) * r.size.x * 0.5, sin(t * 1.1 + 1.3) * r.size.y * 0.9)
			b.wake.append({ "pos": cur, "life": 1.0 })
			if b.wake.size() > 40:
				b.wake.pop_front()
			for w in b.wake:
				w.life -= dt * 0.7
			for p in b.parts:
				p.pos += p.vel * dt
				p.life -= dt * 0.9
			b.parts = b.parts.filter(func(p): return p.life > 0.0)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	var c := r.get_center()
	match b.id:
		"vine":
			ElemKit.face(n, r, Color(0.063, 0.094, 0.063, 0.96), Color(0.55, 0.75, 0.47, 0.4))
			ElemKit.label(n, r, "GARDEN", Color(0.87, 0.94, 0.84))
			var grow: float = minf(1.0, t / 6.0)
			var nodes: Array = b.nodes
			var count: int = maxi(2, int(grow * nodes.size()))
			for i in range(1, count):
				n.draw_line(o + nodes[i - 1].pos, o + nodes[i].pos, Color(0.47, 0.7, 0.35, 0.9), 1.8)
			for i in count:
				var nd: Dictionary = nodes[i]
				if not nd.leaf:
					continue
				n.draw_set_transform(o + nd.pos, nd.la + nd.th, Vector2(1.0, 0.5))   # the spring's angle, not a sine
				n.draw_circle(Vector2(4, 0), 3.4, Color(0.55, 0.78, 0.39, 0.85))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				if pv > 0.0:                 # five petals, conjured by the press
					for pt in 5:
						var pa: float = nd.la + nd.th + pt * TAU / 5.0
						n.draw_circle(o + nd.pos + Vector2(cos(pa), sin(pa)) * 3.4 * pv, 1.7,
							Color(1, 0.75, 0.86, pv))
		"pollen":
			ElemKit.face(n, r, Color(0.1, 0.094, 0.055, 0.92), Color(0.86, 0.78, 0.51, 0.45))
			ElemKit.label(n, r, "ACHOO", Color(0.95, 0.91, 0.78))
			for m in b.motes:
				ElemKit.glow(n, o + m.pos, 3.0, Color(0.94, 0.88, 0.59, 0.5), 2)
		"mycelium":
			ElemKit.face(n, r, Color(0.055, 0.055, 0.078, 0.97), Color(0.75, 0.71, 0.86, 0.35))
			var grow: float = minf(1.0, t / 5.0)
			for th in b.threads:
				var pts: Array = th.pts
				var count: int = maxi(2, int(grow * pts.size()))
				for i in range(1, count):
					var k := float(i) / pts.size()
					var a := 0.22
					if b.pulse >= 0.0:
						a += maxf(0.0, 0.75 - absf(k - b.pulse) * 4.0)
					n.draw_line(o + pts[i - 1], o + pts[i], Color(0.78, 0.75, 0.92, a), 1.0)
			ElemKit.label(n, r, "WOOD WIDE WEB", Color(0.88, 0.86, 0.94, 0.8))
		"swarm":
			ElemKit.face(n, r, Color(0.118, 0.094, 0.04, 0.92), Color(0.9, 0.75, 0.35, 0.5))
			ElemKit.label(n, r, "HIVE", Color(0.96, 0.9, 0.75))
			for bee in b.bees:
				var pos: Vector2 = o + bee.pos
				n.draw_rect(Rect2(pos, Vector2(2.4, 1.8)), Color(0.94, 0.78, 0.31, 0.9))
				n.draw_line(pos - bee.vel * 0.06, pos, Color(0.94, 0.78, 0.31, 0.25), 1.0)   # a hint of flight path: where it just was
		"rainforest":
			ElemKit.face(n, r, Color(0.055, 0.1, 0.07, 0.96), Color(0.47, 0.75, 0.55, 0.5))
			ElemKit.label(n, r, "CANOPY", Color(0.85, 0.93, 0.87))
			for p in b.parts:
				if p.kind == "drip":
					n.draw_set_transform(o + p.pos, 0.0, Vector2(1.0, 2.2))
					n.draw_circle(Vector2.ZERO, 1.2, Color(0.59, 0.86, 0.75, 0.8))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				else:
					n.draw_set_transform(o + p.pos, p.rot, Vector2(1.0, 0.47))
					n.draw_circle(Vector2.ZERO, 3.6, Color(0.43, 0.7, 0.43, 0.8))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"sea_sparkle":
			ElemKit.face(n, r, Color(0.024, 0.047, 0.078, 0.97), Color(0.43, 0.82, 0.92, 0.5))
			for w in b.wake:
				if w.life > 0.0:
					n.draw_rect(Rect2(o + w.pos + Vector2(randf_range(-3, 3), randf_range(-3, 3)),
						Vector2(1.4, 1.4)), Color(0.59, 0.96, 1.0, w.life * 0.6))
			if not b.wake.is_empty():
				ElemKit.glow(n, o + b.wake[-1].pos, 8.0, Color(0.47, 0.94, 1.0, 0.5), 3)
			for p in b.parts:
				n.draw_rect(Rect2(o + p.pos, Vector2(1.6, 1.6)), Color(0.55, 0.94, 1.0, p.life * 0.9))
			ElemKit.label(n, r, "NOCTILUCA", Color(0.78, 0.96, 1.0, 0.85))
