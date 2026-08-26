extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
const Base := preload("res://scenes/elements/cosmic.gd")
## COSMIC & VOID — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"black_hole": { "name": "White fountain", "hint": "flow reversed — everything streams OUT" },
	"galaxy": { "name": "Counter-spiral", "hint": "arms turn the other way, young blue core" },
	"nebula": { "name": "Storm nebula", "hint": "darker, faster — igniting flickers, not stars" },
	"constellation": { "name": "Zodiac wheel", "hint": "inked gold, redrawn twice as often" },
	"eclipse": { "name": "Blood moon", "hint": "transit ÷2, the corona turned to embers" },
	"wormhole": { "name": "Fountain gate", "hint": "runs OUTWARD by default — a press pulls it in" },
	"antimatter": { "name": "Photon pair", "hint": "both twins the same light" },
	"comet": { "name": "Twin comets", "hint": "one ellipse shared, half an orbit apart" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)
	match b.id:
		"wormhole":
			b.dir = 1.0            # outward is the resting state
		"comet":
			b.tail2 = []

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"wormhole":
			# dial: the press reverses INWARD instead
			b.dir = -1.0
			b.rev = 2.0
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"black_hole":
			# dial: infall −2 → outflow +9 (recycled at the rim)
			b.press_v = maxf(0.0, b.press_v - dt * 0.5)
			var push: float = 1.0 + b.press_v * 3.0
			for s in b.stars:
				s.prev = Vector2(cos(s.a) * s.r, sin(s.a) * s.r * 0.55)
				s.a += s.v * push * (30.0 / maxf(12.0, s.r)) * dt
				s.r += (9.0 + b.press_v * 22.0) * dt
				if s.r > r.size.x * 0.6:
					s.r = randf_range(10.0, 16.0)
					s.a = randf_range(0, TAU)
					s.prev = Vector2(cos(s.a) * s.r, sin(s.a) * s.r * 0.55)
		"galaxy":
			# dial: rotation sign flipped
			b.press_v = maxf(0.0, b.press_v - dt * 2.0)
			b.spin += (1.0 - b.spin) * dt * 0.7
			b.a0 -= b.spin * 0.3 * dt
		"constellation":
			# dial: refigure 5s → 2.5s
			b.press_v = maxf(0.0, b.press_v - dt * 2.0)
			b.age += dt
			if b.age > 2.5:
				Base._refigure(b)
		"wormhole":
			# dial: relaxes to OUTWARD after the press
			b.press_v = maxf(0.0, b.press_v - dt * 2.0)
			b.rev -= dt
			if b.rev <= 0.0:
				b.dir = 1.0
			for i in b.rings.size():
				var k: float = b.rings[i] + b.dir * -0.25 * dt
				if k <= 0.0:
					k += 1.0
				if k > 1.0:
					k -= 1.0
				b.rings[i] = k
		"comet":
			# dial: a second head shares the ellipse, half an orbit behind
			b.press_v = maxf(0.0, b.press_v - dt * 2.0)
			b.split = maxf(0.0, b.split - dt * 0.45)
			var e := 0.55 + 0.35 * cos(b.a)
			b.a += (1.2 + (1.0 - e)) * dt * 1.6
			b.tail.push_front(r.size / 2.0 + Vector2(cos(b.a) * r.size.x * 0.58, sin(b.a) * r.size.y * 0.95))
			if b.tail.size() > 22:
				b.tail.pop_back()
			var a2: float = b.a + PI
			b.tail2.push_front(r.size / 2.0 + Vector2(cos(a2) * r.size.x * 0.58, sin(a2) * r.size.y * 0.95))
			if b.tail2.size() > 22:
				b.tail2.pop_back()
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	var c := r.get_center()
	match b.id:
		"black_hole":
			# dial: void black → fountain white
			ElemKit.face(n, r, Color(0.04, 0.047, 0.07, 0.97), Color(0.7, 0.78, 0.9, 0.6))
			for s in b.stars:
				var cur := Vector2(cos(s.a) * s.r, sin(s.a) * s.r * 0.55)
				n.draw_line(c + s.prev, c + cur, Color(0.94, 0.97, 1.0, 0.5 + pv * 0.4), 1.2)
			ElemKit.glow(n, c, 10.0 + pv * 8.0, Color(1, 1, 1, 0.7), 3)
			ElemKit.label(n, r, "WHITE FOUNTAIN", Color(0.9, 0.94, 1.0, 0.8))
		"galaxy":
			# dial: golden core → young blue core (spin sign in tick)
			ElemKit.face(n, r, Color(0.043, 0.039, 0.086, 0.97), Color(0.67, 0.7, 1.0, 0.45))
			ElemKit.glow(n, c, 14.0, Color(0.63, 0.82, 1.0, 0.65), 3)
			for s in b.arms:
				var a: float = b.a0 + s.off
				var pos := c + Vector2(cos(a) * s.r, sin(a) * s.r * 0.5)
				if r.grow(4.0).has_point(pos):
					n.draw_rect(Rect2(pos, Vector2(1.6, 1.6)),
						Color(0.55 + s.d * 0.2, 0.7 + s.d * 0.2, 1.0, 0.65 - s.d * 0.35))
			ElemKit.label(n, r, "RETROGRADE", Color(0.89, 0.9, 1.0))
		"nebula":
			# dials: pastel gas → storm-dark, drift ×2, newborn stars → lightning flickers
			ElemKit.face(n, r, Color(0.031, 0.031, 0.055, 0.97), Color(0.47, 0.47, 0.71, 0.45))
			for g in b.gas:
				var pos := c + Vector2(sin(t * 0.42 + g.ph) * r.size.x * 0.32,
					cos(t * 0.32 + g.ph * 2.0) * r.size.y * 0.6)
				var rad := 20.0 + sin(t * 0.6 + g.ph) * 6.0
				ElemKit.glow(n, pos, rad, Color.from_hsv(g.hue, 0.5, 0.4, 0.15), 3)
			for p in b.parts:
				var flick: float = 1.0 if randf() < 0.6 else 0.2
				n.draw_line(o + p.pos - Vector2(3, 4), o + p.pos + Vector2(1, 1),
					Color(0.86, 0.9, 1.0, p.life * flick), 1.2)
				n.draw_line(o + p.pos + Vector2(1, 1), o + p.pos + Vector2(-1, 5),
					Color(0.86, 0.9, 1.0, p.life * flick * 0.7), 1.0)
			ElemKit.label(n, r, "STORM COMING", Color(0.85, 0.86, 0.97, 0.85))
		"constellation":
			# dial: chalk-blue lines → zodiac gold ink (cadence in tick)
			ElemKit.face(n, r, Color(0.07, 0.055, 0.04, 0.97), Color(0.86, 0.71, 0.43, 0.5))
			for s in b.stars:
				var a := 0.35 + 0.5 * maxf(0.0, sin(t * s.tw))
				n.draw_rect(Rect2(o + s.pos - Vector2(0.8, 0.8), Vector2(1.8, 1.8)), Color(1, 0.94, 0.8, a))
			var reveal: float = minf(1.0, b.age / 0.8)
			var segs: int = maxi(1, int(reveal * (b.figure.size() - 1)))
			for i in range(1, segs + 1):
				if i < b.figure.size():
					n.draw_line(o + b.stars[b.figure[i - 1]].pos, o + b.stars[b.figure[i]].pos,
						Color(1, 0.84, 0.51, maxf(0.15, 0.7 - b.age * 0.16)), 1.2)
			ElemKit.label(n, r, "ZODIAC", Color(1, 0.93, 0.8, 0.85))
		"eclipse":
			# dials: transit ÷2 · corona → ember red
			ElemKit.face(n, r, Color(0.086, 0.047, 0.055, 0.9), Color(1, 0.55, 0.43, 0.4))
			var sun := Vector2(c.x, o.y - 12.0)
			var srad := 9.0
			var mx: float = sun.x + cos(t * 0.175) * 26.0
			if b.jump > 0.0:
				mx = sun.x + (mx - sun.x) * (1.0 - b.jump)
			var cover: float = maxf(0.0, 1.0 - absf(mx - sun.x) / (srad * 2.0))
			ElemKit.glow(n, sun, srad * (2.0 + cover * 2.2), Color(1, 0.43, 0.27, 0.45 + cover * 0.2), 4)
			n.draw_circle(sun, srad, Color(0.9, 0.35, 0.24, 0.95))
			n.draw_circle(Vector2(mx, sun.y), srad * 0.96, Color(0.086, 0.055, 0.06))
			ElemKit.label(n, r, "BLOOD MOON" if cover > 0.85 else "WANING", Color(1, 0.82, 0.75))
		"wormhole":
			# dial: violet throat → teal gate (flow direction in init/tick)
			ElemKit.face(n, r, Color(0.031, 0.078, 0.086, 0.9), Color(0.47, 0.9, 0.86, 0.5))
			for k in b.rings:
				var rw: float = r.size.x * 0.15 + k * r.size.x * 0.5
				var a: float = sin(k * PI) * 0.55
				ElemKit.ellipse(n, c, rw, rw * 0.5,
					Color.from_hsv(fmod(0.47 + k * 0.08, 1.0), 0.75, 0.9, a), 1.6)
			ElemKit.label(n, r, "FOUNTAIN GATE", Color(0.86, 1.0, 0.97))
		"antimatter":
			# dial: matter/antimatter tints collapsed to one light
			ElemKit.face(n, r, Color(0.063, 0.07, 0.1, 0.96), Color(0.78, 0.84, 0.9, 0.5))
			ElemKit.label(n, r, "TWINS", Color(0.9, 0.93, 0.96))
			var px: float = o.x + fmod(t * 30.0, r.size.x + 40.0) - 20.0
			var bw: float = 16.0 + pv * r.size.x
			n.draw_rect(Rect2(Vector2(maxf(px, o.x), o.y), Vector2(clampf(bw, 0, o.x + r.size.x - maxf(px, o.x)), r.size.y)),
				Color(0.9, 0.94, 1.0, 0.2 + pv * 0.3))
			for p in b.parts:
				n.draw_rect(Rect2(o + p.pos, Vector2(2.2, 2.2)), Color(0.86, 0.94, 1.0, p.life))
		"comet":
			ElemKit.face(n, r, Color(0.063, 0.055, 0.11, 0.92), Color(0.7, 0.82, 1.0, 0.45))
			ElemKit.label(n, r, "GEMINI", Color(0.86, 0.92, 1.0, 0.85))
			for pair in [[b.tail, Color(0.67, 0.84, 1.0)], [b.tail2, Color(1, 0.84, 0.63)]]:
				var tail: Array = pair[0]
				var col: Color = pair[1]
				for i in range(1, tail.size()):
					var k := 1.0 - float(i) / tail.size()
					n.draw_line(o + tail[i - 1], o + tail[i], Color(col.r, col.g, col.b, k * 0.5), 1.4)
				if not tail.is_empty():
					ElemKit.glow(n, o + tail[0], 6.0, Color(0.95, 0.97, 1.0, 0.95), 3)
		_:
			Base.draw(n, b, t)
