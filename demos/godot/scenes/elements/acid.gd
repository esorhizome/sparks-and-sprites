extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
## ACID & GOO — six buttons, ported from the web bestiary.

const TITLE := "Acid & goo"
const BLURB := "things that bubble, drip, and should not be touched"
const DEFS := [
	{ "id": "acid_bath", "name": "Acid bath", "hint": "green liquid simmers in the lower third — bubbles rise on buoyancy against drag, wobbling on a sideways spring kicked at release; press for a violent boil" },
	{ "id": "miasma", "name": "Miasma", "hint": "a sickly haze breathes around it; press to blow the cloud away" },
	{ "id": "slime", "name": "Slime coat", "hint": "goo drips off the face at its own pace; press to jiggle it" },
	{ "id": "venom", "name": "Venom", "hint": "two fangs drip; press and they spit an arc" },
	{ "id": "radiant", "name": "Radiant decay", "hint": "three glow sectors rotate like a warning; press for geiger crackle" },
	{ "id": "ecto", "name": "Ectoplasm", "hint": "a ghost drifts on a push against drag, floating on a soft vertical spring, its wisps trailing on springs of their own; press to spook it — an impulse it bleeds off as it flees, wisps stretched behind" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	var r: Rect2 = b.rect
	match b.id:
		"acid_bath":
			b.D = { "buoy": 30.0,       # buoyancy per px of radius, px/s² — bigger bubbles pull harder
				"drag": 6.0,            # drag, 1/s — terminal rise = buoy·r/drag
				"boilBuoy": 2.5,        # how much a full boil multiplies the buoyancy (hotter liquid, lighter gas)
				"kx": 40.0,             # the sideways spring toward the line it rose from, 1/s²
				"zeta": 0.1,            # its damping as a fraction of critical — the wobble dies over a few swings
				"kick": 20.0,           # the sideways kick as a bubble lets go of the floor, px/s
				"rate": 0.2,            # bubble chance per frame at a simmer — a full boil multiplies it by 4.5
				"rmin": 1.5,            # the smallest bubble, px
				"rmax": 3.5 }           # and the biggest
			# the same body as the bubble tank: buoyancy (∝ radius) against drag gives
			# a terminal rise reached a fraction of a second after release; the wobble
			# is a soft sideways spring around the rise line, kicked once at the floor.
			# the boil multiplies the buoyancy and the spawn rate — the speed is what
			# the extra buoyancy builds, not a number swapped in.
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
			b.D = { "thrust": 19.0,     # the ghost's forward push, px/s² — cruising speed = thrust/drag ≈ 16 px/s
				"drag": 1.2,            # drag, 1/s — a spook's impulse decays over ~1/drag s
				"spook": 220.0,         # the press: forward speed injected, px/s
				"hop": 60.0,            # the press: upward speed injected, px/s
				"ky": 6.0,              # the vertical float spring, 1/s² (a 2.6 s bob)
				"yzeta": 0.12,          # its damping — it keeps bobbing a while after every nudge
				"nudge": 20.0,          # an idle nudge's size, px/s — the float comes from these, on 2 % of frames
				"kw": 40.0,             # each wisp's spring toward its place behind the head, 1/s²
				"wzeta": 0.25 }         # wisp damping — they stretch when the head bolts and catch up late
			# the ghost is a body: a constant forward push against drag gives it a
			# cruising speed; the spook is an impulse on top, which the same drag takes
			# back over a second or two. its height is a soft spring around the
			# button's midline, kicked by the spook and nudged now and then. the three
			# wisps are bodies too, each on a spring toward a spot behind the head —
			# when the head bolts they lag and stretch, and they overshoot on the way
			# back. the fade while spooked is read off the actual speed.
			b.gx = -30.0                # the head's x
			b.gvx = float(b.D.thrust) / float(b.D.drag)   # its speed — starts at cruise
			b.gy = 0.0                  # its height off the midline, px
			b.gvy = 0.0
			b.spooked = 0.0             # how much of the fright is left, read off the speed
			b.wisps = []
			for k in range(-1, 2):
				b.wisps.append({ "k": k, "pos": Vector2(b.gx + k * 7 - 11, r.size.y / 2.0 + 10.0), "vel": Vector2.ZERO })

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
			b.gvx += float(b.D.spook)     # the fright: an impulse forward and a hop up
			b.gvy -= float(b.D.hop)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	b.press_v = maxf(0.0, b.press_v - dt * (0.4 if b.id == "miasma" else 0.8))
	var r: Rect2 = b.rect
	match b.id:
		"acid_bath":
			var D: Dictionary = b.D
			var boil: float = b.press_v
			if randf() < float(D.rate) * (1.0 + boil * 3.5):
				var x0 := randf_range(4, r.size.x - 4)
				var kick: float = D.kick
				b.parts.append({ "kind": "bub", "pos": Vector2(x0, r.size.y - 2.0), "x0": x0,
					"r": randf_range(float(D.rmin), float(D.rmax)), "vel": Vector2(randf_range(-kick, kick), 0.0) })
			if randf() < 0.02 + boil * 0.1:
				b.parts.append({ "kind": "drip", "pos": Vector2(randf_range(6, r.size.x - 6), r.size.y), "vy": 10.0 })
			var buoy: float = float(D.buoy) * (1.0 + boil * float(D.boilBuoy))
			var drag: float = D.drag
			var kx: float = D.kx
			var dx: float = float(D.zeta) * 2.0 * sqrt(kx)
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / sub
			for p in b.parts:
				if p.kind == "bub":         # buoyancy − drag upward, the kicked spring sideways
					var v: Vector2 = p.vel
					var pos: Vector2 = p.pos
					var x0: float = p.x0
					var rad: float = p.r
					for _s in sub:
						v.y += (-buoy * rad - drag * v.y) * h   # up is −y
						v.x += (kx * (x0 - pos.x) - dx * v.x) * h
						pos += v * h
					p.vel = v
					p.pos = pos
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
			_haunt(b, dt)

## The ghost's bodies, shared with its rhyme: the head on push-and-drag forward
## and a soft spring vertically, each wisp on a spring toward its spot behind
## the head. Symplectic Euler in ≤ 0.02 s steps; the fright is read off the speed.
static func _haunt(b: Dictionary, dt: float) -> void:
	var D: Dictionary = b.D
	var r: Rect2 = b.rect
	var thrust: float = D.thrust
	var drag: float = D.drag
	var ky: float = D.ky
	var kw: float = D.kw
	var dy: float = float(D.yzeta) * 2.0 * sqrt(ky)
	var dw: float = float(D.wzeta) * 2.0 * sqrt(kw)
	var cruise: float = thrust / drag
	var gx: float = b.gx
	var gvx: float = b.gvx
	var gy: float = b.gy
	var gvy: float = b.gvy
	if randf() < 0.02:                  # an idle nudge: the float
		gvy += randf_range(-float(D.nudge), float(D.nudge))
	var sub := maxi(1, ceili(dt * 50.0))
	var h := dt / sub
	for _s in sub:
		gvx += (thrust - drag * gvx) * h
		gx += gvx * h
		gvy += (-ky * gy - dy * gvy) * h
		gy += gvy * h
		for w in b.wisps:
			var tgt := Vector2(gx + float(w.k) * 7.0 - 11.0, r.size.y / 2.0 + gy + 10.0)
			var v: Vector2 = w.vel
			var p: Vector2 = w.pos
			v += (kw * (tgt - p) - dw * v) * h
			p += v * h
			w.vel = v
			w.pos = p
	gy = clampf(gy, -40.0, 40.0)
	if gx > r.size.x + 40.0:            # round again, wisps and all
		gx -= r.size.x + 80.0
		for w in b.wisps:
			w.pos.x -= r.size.x + 80.0
	b.gx = gx
	b.gvx = gvx
	b.gy = gy
	b.gvy = gvy
	var spook: float = D.spook
	b.spooked = 0.0 if absf(spook) < 1e-6 else clampf((gvx - cruise) / spook * 2.0, 0.0, 1.0)

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
			var gy: float = r.size.y / 2.0 + float(b.gy)   # wherever its spring has floated it
			var in_face: bool = b.gx > 0.0 and b.gx < r.size.x
			var a: float = (0.18 if in_face else 0.34) + b.spooked * 0.2
			var gp := o + Vector2(b.gx, gy)
			ElemKit.glow(n, gp, 13.0, Color(0.75, 1.0, 0.88, a), 3)
			for w in b.wisps:                # trailing wisps: from the head's hem to wherever each has got to
				var hem := gp + Vector2(float(w.k) * 4.0, 7.0)
				var tip: Vector2 = o + w.pos
				ElemKit.qcurve(n, hem, Vector2((hem.x + tip.x) / 2.0, gp.y + 12.0), tip,
					Color(0.75, 1.0, 0.88, a * 0.8), 1.2)
