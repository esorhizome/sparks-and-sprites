extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
const Base := preload("res://scenes/elements/acid.gd")
## ACID & GOO — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"acid_bath": { "name": "Lava bath", "hint": "gone volcanic — hotter colour, lazier bubbles" },
	"miasma": { "name": "Incense", "hint": "warmed and welcomed — the press draws it INWARD" },
	"slime": { "name": "Honey coat", "hint": "amber — stiffer springs, slower sway" },
	"venom": { "name": "Dew fangs", "hint": "harmless water — softer arcs, no flash of harm" },
	"radiant": { "name": "Beacon", "hint": "cleaned to white-blue, slowed to duty" },
	"ecto": { "name": "Bold ghost", "hint": "brighter, braver — a press INVITES it closer" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"venom":
			# dial: the spit arc softened — half the launch energy
			for fx in b.fangs:
				b.parts.append({ "kind": "spit", "pos": Vector2(fx, 10.0),
					"vel": Vector2(randf_range(-12, 12), randf_range(-50, -30)), "life": 1.0 })
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"acid_bath":
			# dials: bubble rate ÷2 · rise speed ÷2 (lava is lazy)
			b.press_v = maxf(0.0, b.press_v - dt * 0.8)
			if randf() < 0.1 + b.press_v * 0.35:
				b.parts.append({ "kind": "bub", "pos": Vector2(randf_range(4, r.size.x - 4), r.size.y - 2.0),
					"r": randf_range(2.0, 4.5) })
			if randf() < 0.02 + b.press_v * 0.1:
				b.parts.append({ "kind": "drip", "pos": Vector2(randf_range(6, r.size.x - 6), r.size.y), "vy": 10.0 })
			for p in b.parts:
				if p.kind == "bub":
					p.pos.y -= (7.0 + b.press_v * 16.0) * dt
				else:
					p.pos.y += p.vy * dt
					p.vy += 70.0 * dt
			var level: float = r.size.y * 0.62
			b.parts = b.parts.filter(func(p): return (p.kind == "bub" and p.pos.y > level) or (p.kind == "drip" and p.pos.y < r.size.y + 40.0))
		"slime":
			# dials: spring 40 → 90 (stiffer) · damping heavier
			b.press_v = maxf(0.0, b.press_v - dt * 0.8)
			for s in b.sags:
				s.v += -s.off * 90.0 * dt
				s.v *= pow(0.08, dt)
				s.off += s.v * dt
		"venom":
			# dial: no hit flash — the drop just lands
			b.hit = 0.0
			b.press_v = maxf(0.0, b.press_v - dt * 0.8)
			if randf() < 0.012:
				b.parts.append({ "kind": "drop", "pos": Vector2(b.fangs[randi() % 2], 12.0), "vel": Vector2(0, 8), "life": 2.0 })
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += (110.0 if p.kind == "spit" else 90.0) * dt
				p.life -= dt * 0.8
			b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.pos.y < r.size.y + 30.0)
		"ecto":
			# dial: the press SLOWS the drift — invited to linger, not spooked away
			b.press_v = maxf(0.0, b.press_v - dt * 0.8)
			b.gx += 16.0 * (1.0 - b.spooked * 0.85) * dt
			if b.gx > r.size.x + 40.0:
				b.gx = -40.0
			b.spooked = maxf(0.0, b.spooked - dt * 0.25)
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	var c := r.get_center()
	match b.id:
		"acid_bath":
			# dial: caustic green → volcanic orange
			ElemKit.face(n, r, Color(0.11, 0.055, 0.031, 0.96), Color(1, 0.59, 0.24, 0.5))
			var level := o.y + r.size.y * 0.62
			var poly := PackedVector2Array()
			poly.append(Vector2(o.x, o.y + r.size.y - 2))
			var x := 0.0
			while x <= r.size.x:
				poly.append(Vector2(o.x + x, level + sin(x * 0.2 + t * (1.5 + pv * 4.0)) * (1.0 + pv * 3.0)))
				x += 5.0
			poly.append(Vector2(o.x + r.size.x, o.y + r.size.y - 2))
			n.draw_colored_polygon(poly, Color(0.9, 0.35, 0.08, 0.6))
			for p in b.parts:
				if p.kind == "bub":
					ElemKit.ellipse(n, o + p.pos, p.r, p.r, Color(1, 0.71, 0.31, 0.75), 1.0, 0, TAU, 10)
				else:
					n.draw_set_transform(o + p.pos, 0.0, Vector2(1.0, 2.0))
					n.draw_circle(Vector2.ZERO, 1.4, Color(1, 0.55, 0.16, 0.85))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			ElemKit.label(n, r, "MAGMA", Color(1, 0.9, 0.75))
		"miasma":
			# dials: sickly green → sandalwood amber · press pulls wisps IN
			ElemKit.face(n, r, Color(0.1, 0.078, 0.055, 0.96), Color(0.9, 0.75, 0.51, 0.45))
			ElemKit.label(n, r, "SANCTUARY", Color(0.96, 0.9, 0.78, 0.85))
			for w in b.wisps:
				var pull: float = 1.0 - pv * 0.65
				var pos := c + Vector2(cos(w.a) * r.size.x * 0.5 * w.r * pull,
					sin(w.a) * r.size.y * 0.75 * w.r * pull)
				var rad: float = 11.0 + sin(t * 0.9 + w.ph) * 4.0
				ElemKit.glow(n, pos, rad, Color(0.94, 0.78, 0.47, 0.1 + pv * 0.06), 3)
		"slime":
			# dial: slime green → honey amber
			ElemKit.face(n, r, Color(0.11, 0.086, 0.04, 0.96), Color(0.94, 0.75, 0.35, 0.45))
			ElemKit.label(n, r, "DRIZZLE", Color(0.24, 0.157, 0.04, 0.9))
			var poly := PackedVector2Array()
			poly.append(o)
			poly.append(o + Vector2(r.size.x, 0))
			for i in range(b.sags.size() - 1, -1, -1):
				var s: Dictionary = b.sags[i]
				poly.append(o + Vector2(s.k * r.size.x,
					r.size.y + s.sag + sin(t * 0.55 + s.ph) * 1.5 + s.off))
			n.draw_colored_polygon(poly, Color(0.9, 0.65, 0.16, 0.6))
			n.draw_line(o + Vector2(8, 4), o + Vector2(r.size.x * 0.4, 4), Color(1, 0.9, 0.63, 0.4), 2.0)
		"venom":
			# dial: venom green → clear dew, no strike flash
			ElemKit.face(n, r, Color(0.063, 0.086, 0.094, 0.96), Color(0.59, 0.82, 0.86, 0.45))
			ElemKit.label(n, r, "MORNING", Color(0.87, 0.95, 0.96))
			for fx in b.fangs:
				var poly := PackedVector2Array([o + Vector2(fx - 4, 1), o + Vector2(fx + 4, 1), o + Vector2(fx, 12)])
				n.draw_colored_polygon(poly, Color(0.89, 0.93, 0.95))
			for p in b.parts:
				if p.kind == "drop":
					n.draw_set_transform(o + p.pos, 0.0, Vector2(1.0, 1.8))
					n.draw_circle(Vector2.ZERO, 1.3, Color(0.75, 0.92, 1.0, 0.85))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				else:
					n.draw_circle(o + p.pos, 1.8, Color(0.78, 0.93, 1.0, p.life * 0.9))
		"radiant":
			# dials: hazard trefoil → duty beacon: white-blue, half the spin, no reversal
			ElemKit.face(n, r, Color(0.055, 0.07, 0.1, 0.9), Color(0.71, 0.86, 1.0, 0.55))
			var spin: float = t * (0.3 + pv * 0.6)
			for s in 3:
				var a0: float = spin + s * TAU / 3.0
				var poly := PackedVector2Array()
				poly.append(c)
				for i in 7:
					var a: float = a0 + TAU / 6.0 * i / 6.0
					poly.append(c + Vector2(cos(a) * r.size.x * 0.55, sin(a) * r.size.y * 0.75))
				n.draw_colored_polygon(poly, Color(0.78, 0.9, 1.0, 0.1 + pv * 0.1))
			for p in b.parts:
				n.draw_rect(Rect2(o + p.pos, Vector2(2.5, 2.5)), Color(0.86, 0.94, 1.0, 0.9))
			ElemKit.label(n, r, "ON DUTY", Color(0.89, 0.95, 1.0))
		"ecto":
			# dials: shy → bold — brighter always, and the press slows it to LINGER
			ElemKit.face(n, r, Color(0.078, 0.086, 0.1, 0.9), Color(0.8, 0.95, 0.88, 0.5))
			ElemKit.label(n, r, "WELCOME", Color(0.9, 0.97, 0.93))
			var speed_pull: float = maxf(0.15, 1.0 - b.spooked)   # spooked now means "invited to stay"
			var gx: float = b.gx
			var gy: float = r.size.y / 2.0 + sin(t * 1.3) * 8.0
			var a: float = 0.42 + b.spooked * 0.3
			var gp := o + Vector2(gx, gy)
			ElemKit.glow(n, gp, 15.0, Color(0.8, 1.0, 0.9, a), 3)
			n.draw_circle(gp + Vector2(-4, -3), 1.4, Color(0.16, 0.27, 0.24, a))
			n.draw_circle(gp + Vector2(4, -3), 1.4, Color(0.16, 0.27, 0.24, a))
			for k in range(-1, 2):
				ElemKit.qcurve(n, gp + Vector2(k * 4, 7),
					gp + Vector2(k * 6 - 6, 12),
					gp + Vector2(k * 7 - 11, 10 + sin(t * 5.0 + k) * 3.0),
					Color(0.8, 1.0, 0.9, a * 0.8), 1.2)
		_:
			Base.draw(n, b, t)
