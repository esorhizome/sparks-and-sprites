extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
const Base := preload("res://scenes/elements/nature.gd")
## NATURE & GROWTH — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"vine": { "name": "Frost vine", "hint": "grown in ice — faster, blooms crystals" },
	"pollen": { "name": "Spore drift", "hint": "darker, and SINKING — the press still scatters" },
	"mycelium": { "name": "Ore veins", "hint": "amber, pulsing at half tempo" },
	"swarm": { "name": "Orbitals", "hint": "wobble dialled to zero — an atom, not a hive" },
	"rainforest": { "name": "Autumn woods", "hint": "fall colours — more leaves, fewer drips" },
	"sea_sparkle": { "name": "Ember wake", "hint": "the current leaves embers — warm, hurried" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)

static func press(b: Dictionary, pos: Vector2) -> void:
	Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"pollen":
			# dial: hover lift −2 → sink +9
			b.press_v = maxf(0.0, b.press_v - dt * 0.6)
			for m in b.motes:
				m.pos += (m.vel + Vector2(sin(t * 0.8 + m.ph) * 4.0, cos(t * 0.6 + m.ph) * 3.0 + 9.0)) * dt
				m.vel *= pow(0.25, dt)
				m.pos.x = fposmod(m.pos.x, r.size.x)
				m.pos.y = fposmod(m.pos.y, r.size.y)
		"mycelium":
			# dial: pulse speed 1.4 → 0.7
			b.press_v = maxf(0.0, b.press_v - dt * 0.6)
			if b.pulse >= 0.0:
				b.pulse += dt * 0.7
				if b.pulse > 1.4:
					b.pulse = -1.0
		"rainforest":
			# dials: leaf rate ×3 · drip rate ÷3
			b.press_v = maxf(0.0, b.press_v - dt * 0.6)
			if randf() < 0.02 + b.press_v * 0.2:
				b.parts.append({ "kind": "drip", "pos": Vector2(randf_range(0, r.size.x), r.size.y),
					"vel": Vector2(0, randf_range(30, 60)) })
			if randf() < 0.06 + b.press_v * 0.36:
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
			# dial: current speed ×1.6, wake fades faster (embers cool quick)
			b.press_v = maxf(0.0, b.press_v - dt * 0.6)
			var cur := r.size / 2.0 + Vector2(sin(t * 1.1) * r.size.x * 0.5, sin(t * 1.8 + 1.3) * r.size.y * 0.9)
			b.wake.append({ "pos": cur, "life": 1.0 })
			if b.wake.size() > 40:
				b.wake.pop_front()
			for w in b.wake:
				w.life -= dt * 1.1
			for p in b.parts:
				p.pos += p.vel * dt
				p.life -= dt * 0.9
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	var c := r.get_center()
	match b.id:
		"vine":
			# dials: garden green → hoarfrost · growth 6s → 3s · petals → crystals
			ElemKit.face(n, r, Color(0.055, 0.078, 0.11, 0.96), Color(0.63, 0.82, 0.96, 0.4))
			ElemKit.label(n, r, "HOARFROST", Color(0.88, 0.94, 1.0))
			var grow: float = minf(1.0, t / 3.0)
			var nodes: Array = b.nodes
			var count: int = maxi(2, int(grow * nodes.size()))
			for i in range(1, count):
				n.draw_line(o + nodes[i - 1].pos, o + nodes[i].pos, Color(0.71, 0.88, 1.0, 0.9), 1.6)
			for i in count:
				var nd: Dictionary = nodes[i]
				if not nd.leaf:
					continue
				ElemKit.twinkle(n, o + nd.pos, 3.0, Color(0.86, 0.95, 1.0, 0.7 + 0.3 * sin(t * 2.0 + nd.la)))
				if pv > 0.0:               # six ice spars instead of petals
					for pt in 6:
						var pa: float = nd.la + pt * TAU / 6.0
						n.draw_line(o + nd.pos, o + nd.pos + Vector2(cos(pa), sin(pa)) * 5.0 * pv,
							Color(0.9, 0.97, 1.0, pv * 0.8), 1.0)
		"pollen":
			# dial: sunlit gold → cellar-dark spores (sink dial in tick)
			ElemKit.face(n, r, Color(0.07, 0.063, 0.086, 0.94), Color(0.59, 0.51, 0.67, 0.45))
			ElemKit.label(n, r, "SPORES", Color(0.85, 0.8, 0.9))
			for m in b.motes:
				n.draw_circle(o + m.pos, 1.6, Color(0.71, 0.63, 0.78, 0.6))
		"mycelium":
			# dial: pale threads → amber ore (tempo dial in tick)
			ElemKit.face(n, r, Color(0.07, 0.055, 0.04, 0.97), Color(0.86, 0.67, 0.35, 0.35))
			var grow: float = minf(1.0, t / 5.0)
			for th in b.threads:
				var pts: Array = th.pts
				var count: int = maxi(2, int(grow * pts.size()))
				for i in range(1, count):
					var k := float(i) / pts.size()
					var a := 0.25
					if b.pulse >= 0.0:
						a += maxf(0.0, 0.75 - absf(k - b.pulse) * 4.0)
					n.draw_line(o + pts[i - 1], o + pts[i], Color(1, 0.78, 0.39, a), 1.2)
			ElemKit.label(n, r, "MOTHERLODE", Color(0.97, 0.9, 0.78, 0.8))
		"swarm":
			# dials: wobble 0 · panic → excitation ring jump (drawn tighter)
			ElemKit.face(n, r, Color(0.047, 0.063, 0.1, 0.94), Color(0.55, 0.75, 0.96, 0.5))
			ElemKit.label(n, r, "NUCLEUS", Color(0.85, 0.92, 1.0))
			n.draw_circle(c, 3.0, Color(0.86, 0.93, 1.0, 0.9))
			for bee in b.bees:
				var rr: float = (r.size.x * 0.34) * (1.0 + bee.panic * 1.1)
				var pos := c + Vector2(cos(bee.a) * rr * 1.25, sin(bee.a) * rr * 0.55)
				n.draw_circle(pos, 1.6, Color(0.63, 0.86, 1.0, 0.9))
			ElemKit.ellipse(n, c, r.size.x * 0.425, r.size.y * 0.33, Color(0.55, 0.78, 1.0, 0.2), 1.0)
		"rainforest":
			# dial: canopy green → fall colours
			ElemKit.face(n, r, Color(0.1, 0.07, 0.04, 0.96), Color(0.86, 0.63, 0.31, 0.5))
			ElemKit.label(n, r, "OCTOBER", Color(0.96, 0.88, 0.75))
			for p in b.parts:
				if p.kind == "drip":
					n.draw_set_transform(o + p.pos, 0.0, Vector2(1.0, 2.2))
					n.draw_circle(Vector2.ZERO, 1.2, Color(0.7, 0.78, 0.86, 0.7))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				else:
					n.draw_set_transform(o + p.pos, p.rot, Vector2(1.0, 0.47))
					n.draw_circle(Vector2.ZERO, 3.6,
						[Color(0.86, 0.55, 0.24), Color(0.9, 0.71, 0.27), Color(0.78, 0.39, 0.24)][int(p.ph) % 3])
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"sea_sparkle":
			# dial: noctiluca cyan → ember orange
			ElemKit.face(n, r, Color(0.07, 0.04, 0.024, 0.97), Color(1, 0.67, 0.35, 0.5))
			for w in b.wake:
				if w.life > 0.0:
					n.draw_rect(Rect2(o + w.pos + Vector2(randf_range(-3, 3), randf_range(-3, 3)),
						Vector2(1.4, 1.4)), Color(1, 0.71, 0.31, w.life * 0.7))
			if not b.wake.is_empty():
				ElemKit.glow(n, o + b.wake[-1].pos, 8.0, Color(1, 0.78, 0.39, 0.55), 3)
			for p in b.parts:
				n.draw_rect(Rect2(o + p.pos, Vector2(1.6, 1.6)), Color(1, 0.75, 0.39, p.life * 0.9))
			ElemKit.label(n, r, "EMBER WAKE", Color(1, 0.9, 0.78, 0.85))
		_:
			Base.draw(n, b, t)
