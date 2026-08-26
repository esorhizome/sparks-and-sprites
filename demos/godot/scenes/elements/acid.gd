extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
## ACID & GOO — six buttons, ported from the web bestiary.

const TITLE := "Acid & goo"
const BLURB := "things that bubble, drip, and should not be touched"
const DEFS := [
	{ "id": "acid_bath", "name": "Acid bath", "hint": "green liquid simmers in the lower third; press for a violent boil" },
	{ "id": "miasma", "name": "Miasma", "hint": "a sickly haze breathes around it; press to blow the cloud away" },
	{ "id": "slime", "name": "Slime coat", "hint": "goo drips off the face at its own pace; press to jiggle it" },
	{ "id": "venom", "name": "Venom", "hint": "two fangs drip; press and they spit an arc" },
	{ "id": "radiant", "name": "Radiant decay", "hint": "three glow sectors rotate like a warning; press for geiger crackle" },
	{ "id": "ecto", "name": "Ectoplasm", "hint": "a ghost drifts through the button; press to startle it away" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	var r: Rect2 = b.rect
	match b.id:
		"miasma":
			b.wisps = []
			for i in 8:
				b.wisps.append({ "a": randf_range(0, TAU), "r": randf_range(0.9, 1.3),
					"v": randf_range(0.2, 0.5), "ph": randf_range(0, 9) })
		"slime":
			b.sags = []
			for i in 11:
				b.sags.append({ "k": i / 10.0, "sag": randf_range(2, 7), "ph": randf_range(0, 9),
					"v": 0.0, "off": 0.0 })
		"venom":
			b.fangs = [r.size.x / 2.0 - 22.0, r.size.x / 2.0 + 22.0]
			b.hit = 0.0
		"ecto":
			b.gx = -30.0
			b.spooked = 0.0

static func press(b: Dictionary, _pos: Vector2) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"acid_bath", "miasma", "radiant":
			b.press_v = 1.0
		"slime":
			for s in b.sags:
				s.v += randf_range(30, 60)
		"venom":
			for fx in b.fangs:
				b.parts.append({ "kind": "spit", "pos": Vector2(fx, 10.0),
					"vel": Vector2(randf_range(-25, 25), randf_range(-90, -60)), "life": 1.0 })
		"ecto":
			b.spooked = 1.0

static func tick(b: Dictionary, dt: float, t: float) -> void:
	b.press_v = maxf(0.0, b.press_v - dt * (0.4 if b.id == "miasma" else 0.8))
	var r: Rect2 = b.rect
	match b.id:
		"acid_bath":
			if randf() < 0.2 + b.press_v * 0.7:
				b.parts.append({ "kind": "bub", "pos": Vector2(randf_range(4, r.size.x - 4), r.size.y - 2.0),
					"r": randf_range(1.5, 3.5) })
			if randf() < 0.02 + b.press_v * 0.1:
				b.parts.append({ "kind": "drip", "pos": Vector2(randf_range(6, r.size.x - 6), r.size.y), "vy": 10.0 })
			for p in b.parts:
				if p.kind == "bub":
					p.pos.y -= (14.0 + b.press_v * 30.0) * dt
				else:
					p.pos.y += p.vy * dt
					p.vy += 70.0 * dt
			var level: float = r.size.y * 0.62
			b.parts = b.parts.filter(func(p): return (p.kind == "bub" and p.pos.y > level) or (p.kind == "drip" and p.pos.y < r.size.y + 40.0))
		"miasma":
			for w in b.wisps:
				w.a += w.v * dt
		"slime":
			for s in b.sags:
				s.v += -s.off * 40.0 * dt
				s.v *= pow(0.2, dt)
				s.off += s.v * dt
		"venom":
			b.hit = maxf(0.0, b.hit - dt * 2.0)
			if randf() < 0.008:
				b.parts.append({ "kind": "drop", "pos": Vector2(b.fangs[randi() % 2], 12.0), "vel": Vector2(0, 8), "life": 2.0 })
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += (150.0 if p.kind == "spit" else 90.0) * dt
				p.life -= dt * 0.8
				if p.kind == "spit" and p.pos.y > r.size.y / 2.0 and p.vel.y > 0.0:
					b.hit = 1.0
					p.life = 0.0
			b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.pos.y < r.size.y + 30.0)
		"radiant":
			if b.press_v > 0.0 and randf() < b.press_v * 0.8:
				b.parts.append({ "pos": Vector2(randf_range(0, r.size.x), randf_range(0, r.size.y)), "life": 0.25 })
			for p in b.parts:
				p.life -= dt
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"ecto":
			b.gx += (16.0 + b.spooked * 220.0) * dt
			if b.gx > r.size.x + 40.0:
				b.gx = -40.0
				b.spooked = maxf(0.0, b.spooked - 0.99)
			b.spooked = maxf(0.0, b.spooked - dt * 0.25)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	var c := r.get_center()
	match b.id:
		"acid_bath":
			ElemKit.face(n, r, Color(0.07, 0.094, 0.055, 0.96), Color(0.59, 0.9, 0.35, 0.5))
			var level := o.y + r.size.y * 0.62
			var poly := PackedVector2Array()
			poly.append(Vector2(o.x, o.y + r.size.y - 2))
			var x := 0.0
			while x <= r.size.x:
				poly.append(Vector2(o.x + x, level + sin(x * 0.2 + t * (3.0 + pv * 6.0)) * (1.0 + pv * 3.0)))
				x += 5.0
			poly.append(Vector2(o.x + r.size.x, o.y + r.size.y - 2))
			n.draw_colored_polygon(poly, Color(0.35, 0.75, 0.16, 0.55))
			for p in b.parts:
				if p.kind == "bub":
					ElemKit.ellipse(n, o + p.pos, p.r, p.r, Color(0.75, 1.0, 0.51, 0.7), 1.0, 0, TAU, 10)
				else:
					n.draw_set_transform(o + p.pos, 0.0, Vector2(1.0, 2.0))
					n.draw_circle(Vector2.ZERO, 1.4, Color(0.55, 0.9, 0.31, 0.8))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			ElemKit.label(n, r, "CAUSTIC", Color(0.87, 0.97, 0.76))
		"miasma":
			ElemKit.face(n, r, Color(0.078, 0.094, 0.063, 0.96), Color(0.67, 0.78, 0.43, 0.45))
			ElemKit.label(n, r, "QUARANTINE", Color(0.88, 0.94, 0.75, 0.85))
			for w in b.wisps:
				var push: float = 1.0 + pv * 2.2
				var pos := c + Vector2(cos(w.a) * r.size.x * 0.5 * w.r * push,
					sin(w.a) * r.size.y * 0.75 * w.r * push)
				var rad: float = 11.0 + sin(t * 0.9 + w.ph) * 4.0
				ElemKit.glow(n, pos, rad, Color(0.7, 0.86, 0.35, 0.09 * (1.0 - pv * 0.85)), 3)
		"slime":
			ElemKit.face(n, r, Color(0.07, 0.1, 0.063, 0.96), Color(0.55, 0.86, 0.43, 0.4))
			ElemKit.label(n, r, "SQUISH", Color(0.078, 0.157, 0.078, 0.9))
			var poly := PackedVector2Array()   # the coat: a lid plus drooping lobes
			poly.append(o)
			poly.append(o + Vector2(r.size.x, 0))
			for i in range(b.sags.size() - 1, -1, -1):
				var s: Dictionary = b.sags[i]
				poly.append(o + Vector2(s.k * r.size.x,
					r.size.y + s.sag + sin(t * 1.1 + s.ph) * 1.5 + s.off))
			n.draw_colored_polygon(poly, Color(0.47, 0.82, 0.35, 0.55))
			n.draw_line(o + Vector2(8, 4), o + Vector2(r.size.x * 0.4, 4), Color(0.86, 1.0, 0.75, 0.35), 2.0)
		"venom":
			ElemKit.face(n, r, Color(0.094, 0.07, 0.1, 0.96), Color(0.7, 0.55, 0.86, 0.45 + b.hit * 0.5))
			ElemKit.label(n, r, "FANG", Color(0.71, 1.0, 0.62) if b.hit > 0.0 else Color(0.91, 0.86, 0.96))
			for fx in b.fangs:
				var poly := PackedVector2Array([o + Vector2(fx - 4, 1), o + Vector2(fx + 4, 1), o + Vector2(fx, 12)])
				n.draw_colored_polygon(poly, Color(0.91, 0.89, 0.93))
			for p in b.parts:
				if p.kind == "drop":
					n.draw_set_transform(o + p.pos, 0.0, Vector2(1.0, 1.8))
					n.draw_circle(Vector2.ZERO, 1.3, Color(0.67, 1.0, 0.43, 0.85))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				else:
					n.draw_circle(o + p.pos, 2.0, Color(0.67, 1.0, 0.43, p.life))
		"radiant":
			ElemKit.face(n, r, Color(0.078, 0.094, 0.04, 0.88), Color(0.78, 0.94, 0.35, 0.55))
			var spin: float = t * (0.6 + pv * 2.0) * (-1.0 if pv > 0.0 else 1.0)
			for s in 3:                      # the trefoil, abstracted to light
				var a0: float = spin + s * TAU / 3.0
				var poly := PackedVector2Array()
				poly.append(c)
				for i in 7:
					var a: float = a0 + TAU / 6.0 * i / 6.0
					poly.append(c + Vector2(cos(a) * r.size.x * 0.55, sin(a) * r.size.y * 0.75))
				n.draw_colored_polygon(poly, Color(0.78, 1.0, 0.31, 0.13 + pv * 0.13))
			for p in b.parts:                # each tick: one hard, brief dot
				n.draw_rect(Rect2(o + p.pos, Vector2(2.5, 2.5)), Color(0.9, 1.0, 0.59, 0.95))
			ElemKit.label(n, r, "HALF-LIFE", Color(0.93, 0.98, 0.78))
		"ecto":
			ElemKit.face(n, r, Color(0.078, 0.086, 0.1, 0.96 - b.spooked * 0.2), Color(0.75, 0.9, 0.82, 0.4))
			ElemKit.label(n, r, "BOO", Color(0.88, 0.95, 0.91))
			var gy: float = r.size.y / 2.0 + sin(t * 1.3) * 8.0 - b.spooked * 10.0
			var in_face: bool = b.gx > 0.0 and b.gx < r.size.x
			var a: float = (0.18 if in_face else 0.34) + b.spooked * 0.2
			var gp := o + Vector2(b.gx, gy)
			ElemKit.glow(n, gp, 13.0, Color(0.75, 1.0, 0.88, a), 3)
			for k in range(-1, 2):
				ElemKit.qcurve(n, gp + Vector2(k * 4, 7),
					gp + Vector2(k * 6 - 6, 12),
					gp + Vector2(k * 7 - 11, 10 + sin(t * 5.0 + k) * 3.0),
					Color(0.75, 1.0, 0.88, a * 0.8), 1.2)
