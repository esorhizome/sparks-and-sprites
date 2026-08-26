extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
## COSMIC & VOID — eight buttons, ported from the web bestiary.

const TITLE := "Cosmic & void"
const BLURB := "black holes, nebulae, eclipses, and antimatter"
const DEFS := [
	{ "id": "black_hole", "name": "Black hole", "hint": "stars spiral into it forever; press to feed the accretion disk" },
	{ "id": "galaxy", "name": "Galaxy", "hint": "a two-armed spiral turns behind the face; press to spin it up" },
	{ "id": "nebula", "name": "Nebula", "hint": "gas clouds slowly morph; press to ignite a newborn star" },
	{ "id": "constellation", "name": "Constellation", "hint": "stars connect into a figure, redrawn each pass; press for a new one" },
	{ "id": "eclipse", "name": "Eclipse", "hint": "the moon crosses the sun on a slow orbit; press to jump to totality" },
	{ "id": "wormhole", "name": "Wormhole", "hint": "rings fall inward down the throat; press to reverse the flow" },
	{ "id": "antimatter", "name": "Antimatter", "hint": "an inversion bar drifts over the face; press to annihilate a pair" },
	{ "id": "comet", "name": "Comet loop", "hint": "a comet rounds the button like a tiny sun; press to split its tail" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	var r: Rect2 = b.rect
	match b.id:
		"black_hole":
			b.stars = []
			for i in 30:
				b.stars.append({ "a": randf_range(0, TAU), "r": randf_range(16, r.size.x * 0.55),
					"v": randf_range(0.4, 1.0), "prev": Vector2.ZERO })
		"galaxy":
			b.arms = []
			for arm in 2:
				for i in 30:
					var d := i / 30.0
					b.arms.append({ "off": arm * PI + d * 3.4 + randf_range(-0.18, 0.18),
						"r": 6.0 + d * r.size.x * 0.5, "d": d })
			b.spin = 1.0
			b.a0 = 0.0
		"nebula":
			b.gas = [{ "hue": 0.78, "ph": 0.0 }, { "hue": 0.89, "ph": 2.0 }, { "hue": 0.53, "ph": 4.0 }, { "hue": 0.69, "ph": 5.0 }]
		"constellation":
			b.stars = []
			for i in 12:
				b.stars.append({ "pos": Vector2(randf_range(8, r.size.x - 8), randf_range(6, r.size.y - 6)),
					"tw": randf_range(2, 6) })
			b.figure = []
			b.age = 0.0
			_refigure(b)
		"eclipse":
			b.jump = 0.0
		"wormhole":
			b.rings = []
			for i in 7:
				b.rings.append(i / 7.0)
			b.dir = -1.0
			b.rev = 0.0
		"antimatter":
			pass
		"comet":
			b.a = 0.0
			b.tail = []
			b.split = 0.0

static func _refigure(b: Dictionary) -> void:
	b.figure = []
	var idx: int = randi() % b.stars.size()
	for i in 5:
		b.figure.append(idx)
		idx = (idx + 1 + randi() % 4) % b.stars.size()
	b.age = 0.0

static func press(b: Dictionary, _pos: Vector2) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"black_hole", "eclipse":
			b.press_v = 1.0
			if b.id == "eclipse":
				b.jump = 1.0
		"galaxy":
			b.spin = 4.0
		"nebula":
			b.parts.append({ "pos": Vector2(randf_range(r.size.x * 0.1, r.size.x * 0.9),
				randf_range(0, r.size.y)), "life": 1.0 })
		"constellation":
			_refigure(b)
		"wormhole":
			b.dir = 1.0
			b.rev = 2.0
		"antimatter":
			b.press_v = 1.0
			for i in 5:
				var th := randf_range(0, TAU)
				var v := randf_range(50, 110)
				b.parts.append({ "pos": r.size / 2.0, "vel": Vector2(cos(th), sin(th)) * v, "life": 1.0, "anti": false })
				b.parts.append({ "pos": r.size / 2.0, "vel": -Vector2(cos(th), sin(th)) * v, "life": 1.0, "anti": true })
		"comet":
			b.split = 1.0

static func tick(b: Dictionary, dt: float, t: float) -> void:
	b.press_v = maxf(0.0, b.press_v - dt * (0.5 if b.id in ["black_hole", "eclipse"] else 2.0))
	var r: Rect2 = b.rect
	match b.id:
		"black_hole":
			var pull: float = 1.0 + b.press_v * 3.0
			for s in b.stars:
				s.prev = Vector2(cos(s.a) * s.r, sin(s.a) * s.r * 0.55)
				s.a += s.v * pull * (30.0 / maxf(12.0, s.r)) * dt
				s.r -= (2.0 + b.press_v * 22.0) * dt
				if s.r < 10.0:
					s.r = r.size.x * randf_range(0.4, 0.55)
					s.a = randf_range(0, TAU)
					s.prev = Vector2(cos(s.a) * s.r, sin(s.a) * s.r * 0.55)
		"galaxy":
			b.spin += (1.0 - b.spin) * dt * 0.7
			b.a0 += b.spin * 0.3 * dt
		"nebula":
			for p in b.parts:
				p.life -= dt * 0.4
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"constellation":
			b.age += dt
			if b.age > 5.0:
				_refigure(b)
		"eclipse":
			b.jump = maxf(0.0, b.jump - dt * 0.5)
		"wormhole":
			b.rev -= dt
			if b.rev <= 0.0:
				b.dir = -1.0
			for i in b.rings.size():
				var k: float = b.rings[i] + b.dir * -0.25 * dt
				if k <= 0.0:
					k += 1.0
				if k > 1.0:
					k -= 1.0
				b.rings[i] = k
		"antimatter":
			for p in b.parts:
				p.pos += p.vel * dt
				p.life -= dt * 1.3
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"comet":
			b.split = maxf(0.0, b.split - dt * 0.45)
			var e := 0.55 + 0.35 * cos(b.a)
			b.a += (1.2 + (1.0 - e)) * dt * 1.6
			b.tail.push_front(r.size / 2.0 + Vector2(cos(b.a) * r.size.x * 0.58, sin(b.a) * r.size.y * 0.95))
			if b.tail.size() > 22:
				b.tail.pop_back()

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	var c := r.get_center()
	match b.id:
		"black_hole":
			ElemKit.face(n, r, Color(0.02, 0.02, 0.04, 0.97), Color(0.35, 0.31, 0.47, 0.6))
			for s in b.stars:
				var cur := Vector2(cos(s.a) * s.r, sin(s.a) * s.r * 0.55)
				n.draw_line(c + s.prev, c + cur, Color(0.86, 0.84, 1.0, 0.5 + pv * 0.4), 1.2)
			ElemKit.ellipse(n, c, r.size.x * 0.34, r.size.y * 0.58,
				Color(1, 0.75, 0.47, 0.5 + pv * 0.5), 2.0 + pv * 2.0)
			ElemKit.label(n, r, "EVENT HORIZON", Color(0.78, 0.75, 0.9, 0.75))
		"galaxy":
			ElemKit.face(n, r, Color(0.043, 0.039, 0.086, 0.97), Color(0.67, 0.7, 1.0, 0.45))
			ElemKit.glow(n, c, 14.0, Color(1, 0.94, 0.82, 0.6), 3)
			for s in b.arms:
				var a: float = b.a0 + s.off
				var pos := c + Vector2(cos(a) * s.r, sin(a) * s.r * 0.5)
				if r.grow(4.0).has_point(pos):
					n.draw_rect(Rect2(pos, Vector2(1.6, 1.6)),
						Color(0.67 + s.d * 0.24, 0.75 + s.d * 0.16, 1.0, 0.65 - s.d * 0.35))
			ElemKit.label(n, r, "SPIRAL", Color(0.89, 0.9, 1.0))
		"nebula":
			ElemKit.face(n, r, Color(0.043, 0.039, 0.086, 0.95), Color(0.82, 0.67, 1.0, 0.45))
			for g in b.gas:
				var pos := c + Vector2(sin(t * 0.21 + g.ph) * r.size.x * 0.32,
					cos(t * 0.16 + g.ph * 2.0) * r.size.y * 0.6)
				var rad := 20.0 + sin(t * 0.3 + g.ph) * 6.0
				ElemKit.glow(n, pos, rad, Color.from_hsv(g.hue, 0.8, 0.8, 0.13), 3)
			for p in b.parts:
				var flare: float = maxf(0.0, sin((1.0 - p.life) * PI))
				n.draw_rect(Rect2(o + p.pos - Vector2(1, 1), Vector2(2.5, 2.5)), Color(1, 1, 0.94, 0.4 + flare * 0.6))
				ElemKit.twinkle(n, o + p.pos, 6.0 * flare, Color(1, 1, 0.94, flare * 0.6))
			ElemKit.label(n, r, "STELLAR NURSERY", Color(0.94, 0.88, 1.0, 0.85))
		"constellation":
			ElemKit.face(n, r, Color(0.047, 0.047, 0.1, 0.97), Color(0.59, 0.63, 0.86, 0.5))
			for s in b.stars:
				var a := 0.35 + 0.5 * maxf(0.0, sin(t * s.tw))
				n.draw_rect(Rect2(o + s.pos - Vector2(0.8, 0.8), Vector2(1.8, 1.8)), Color(0.9, 0.92, 1.0, a))
			var reveal: float = minf(1.0, b.age / 1.6)
			var segs: int = maxi(1, int(reveal * (b.figure.size() - 1)))
			for i in range(1, segs + 1):
				if i < b.figure.size():
					n.draw_line(o + b.stars[b.figure[i - 1]].pos, o + b.stars[b.figure[i]].pos,
						Color(0.7, 0.78, 1.0, maxf(0.1, 0.6 - b.age * 0.08)), 1.0)
			ElemKit.label(n, r, "MYTHOLOGY", Color(0.88, 0.9, 1.0, 0.8))
		"eclipse":
			ElemKit.face(n, r, Color(0.078, 0.063, 0.118, 0.9), Color(1, 0.88, 0.67, 0.4))
			var sun := Vector2(c.x, o.y - 12.0)
			var srad := 9.0
			var mx: float = sun.x + cos(t * 0.35) * 26.0
			if b.jump > 0.0:
				mx = sun.x + (mx - sun.x) * (1.0 - b.jump)
			var cover: float = maxf(0.0, 1.0 - absf(mx - sun.x) / (srad * 2.0))
			ElemKit.glow(n, sun, srad * (2.0 + cover * 2.2), Color(1, 0.94, 0.78, 0.5 - cover * 0.2), 4)
			n.draw_circle(sun, srad, Color(1, 0.92, 0.75, 0.95))
			n.draw_circle(Vector2(mx, sun.y), srad * 0.96, Color(0.078, 0.067, 0.12))
			ElemKit.label(n, r, "TOTALITY" if cover > 0.85 else "TRANSIT", Color(1, 0.94, 0.82))
		"wormhole":
			ElemKit.face(n, r, Color(0.055, 0.039, 0.1, 0.9), Color(0.75, 0.63, 1.0, 0.5))
			for k in b.rings:
				var rw: float = r.size.x * 0.15 + k * r.size.x * 0.5
				var a: float = sin(k * PI) * 0.55
				ElemKit.ellipse(n, c, rw, rw * 0.5,
					Color.from_hsv(fmod(0.71 + k * 0.17, 1.0), 0.8, 0.9, a), 1.6)
			ElemKit.label(n, r, "THROAT", Color(0.92, 0.88, 1.0))
		"antimatter":
			ElemKit.face(n, r, Color(0.078, 0.063, 0.118, 0.96), Color(0.78, 0.78, 0.9, 0.5))
			ElemKit.label(n, r, "CPT", Color(0.9, 0.9, 0.96))
			# the inversion bar: canvas "difference" emulated with a bright pass
			var px: float = o.x + fmod(t * 30.0, r.size.x + 40.0) - 20.0
			var bw: float = 16.0 + pv * r.size.x
			n.draw_rect(Rect2(Vector2(maxf(px, o.x), o.y), Vector2(clampf(bw, 0, o.x + r.size.x - maxf(px, o.x)), r.size.y)),
				Color(0.9, 0.9, 1.0, 0.22 + pv * 0.3))
			for p in b.parts:
				n.draw_rect(Rect2(o + p.pos, Vector2(2.2, 2.2)),
					Color(1, 0.59, 0.86, p.life) if p.anti else Color(0.59, 0.9, 1.0, p.life))
		"comet":
			ElemKit.face(n, r, Color(0.063, 0.055, 0.11, 0.92), Color(0.7, 0.82, 1.0, 0.45))
			ElemKit.label(n, r, "PERIHELION", Color(0.86, 0.92, 1.0, 0.85))
			var tail: Array = b.tail
			for i in range(1, tail.size()):
				var k := 1.0 - float(i) / tail.size()
				n.draw_line(o + tail[i - 1], o + tail[i], Color(0.67, 0.84, 1.0, k * 0.5 * (1.0 + b.split * 0.6)), 1.4)
				if b.split > 0.0:
					var off: Vector2 = (tail[i] - r.size / 2.0) * 0.12 * b.split
					n.draw_line(o + tail[i - 1] + off, o + tail[i] + off * 1.2,
						Color(0.67, 0.84, 1.0, k * 0.3), 1.0)
			if not tail.is_empty():
				ElemKit.glow(n, o + tail[0], 6.0, Color(0.92, 0.96, 1.0, 0.95), 3)
