extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
## SPARKS — six buttons, ported from the web bestiary.

const TITLE := "Sparks"
const BLURB := "the grindstone, the sparkler, the flint, the weld"
const DEFS := [
	{ "id": "grindstone", "name": "Grindstone", "hint": "the wheel throws sparks off one corner; press to lean in" },
	{ "id": "sparkler", "name": "Sparkler", "hint": "a fizzing point rides the border; press to light a second one" },
	{ "id": "flint", "name": "Flint", "hint": "dead still until struck — press for the strike" },
	{ "id": "welding", "name": "Welding seam", "hint": "an arc crawls the border leaving cooling metal; press for spatter" },
	{ "id": "fountain", "name": "Fountain", "hint": "a firework fountain plays over the button; press for three rockets" },
	{ "id": "pixie", "name": "Pixie dust", "hint": "glitter sheds off the caption; press to stir a spiral of it" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	match b.id:
		"sparkler":
			b.second = 0.0
		"welding":
			b.p = 0.0
			b.seam = []
		"fountain":
			b.rockets = []

static func press(b: Dictionary, _pos: Vector2) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"grindstone", "pixie":
			b.press_v = 1.0
		"sparkler":
			b.second = 5.0
		"flint":
			b.press_v = 1.0
			for i in 18:
				var th := randf_range(-2.6, -0.5)
				var v := randf_range(60, 220)
				b.parts.append({ "pos": Vector2(14, r.size.y - 8), "vel": Vector2(cos(th), sin(th)) * v,
					"life": randf_range(0.4, 1.0) })
		"welding":
			var a: float = b.p * TAU
			var at := r.size / 2.0 + Vector2(cos(a) * r.size.x * 0.52, sin(a) * r.size.y * 0.62)
			for i in 10:
				b.parts.append({ "pos": at, "vel": Vector2(randf_range(-90, 90), randf_range(-90, 40)), "life": 1.0 })
		"fountain":
			for i in 3:
				b.rockets.append({ "pos": Vector2(randf_range(0, r.size.x), randf_range(-30, -6)),
					"fuse": i * 0.16, "burst": [] })

static func tick(b: Dictionary, dt: float, t: float) -> void:
	b.press_v = maxf(0.0, b.press_v - dt * (0.7 if b.id == "pixie" else 1.2))
	var r: Rect2 = b.rect
	match b.id:
		"grindstone":
			if randf() < 0.25 + b.press_v * 0.7:
				for i in (4 if b.press_v > 0.0 else 1):
					b.parts.append({ "pos": Vector2(r.size.x - 6, r.size.y - 4),
						"vel": Vector2(randf_range(30, 120), randf_range(-100, -20)), "life": randf_range(0.5, 1.0) })
			_fly(b, dt, 300.0, 1.4)
		"sparkler":
			b.second = maxf(0.0, b.second - dt)
		"flint":
			_fly(b, dt, 260.0, 1.7)
		"welding":
			b.p = fmod(b.p + dt * 0.12, 1.0)
			var a: float = b.p * TAU
			b.seam.append({ "pos": r.size / 2.0 + Vector2(cos(a) * r.size.x * 0.52, sin(a) * r.size.y * 0.62), "age": 0.0 })
			if b.seam.size() > 90:
				b.seam.pop_front()
			for s in b.seam:
				s.age += dt
			_fly(b, dt, 240.0, 1.6)
		"fountain":
			var swell := 0.5 + 0.5 * sin(t * 0.8)
			if randf() < 0.4 + swell * 0.4:
				b.parts.append({ "pos": Vector2(r.size.x / 2.0 + randf_range(-4, 4), -2.0),
					"vel": Vector2(randf_range(-30, 30), randf_range(-110, -60) * (0.7 + swell * 0.5)), "life": 1.0 })
			_fly(b, dt, 170.0, 1.1)
			for rk in b.rockets:
				rk.fuse -= dt
				if rk.fuse <= 0.0 and rk.burst.is_empty():
					for i in 14:
						var th := i / 14.0 * TAU
						rk.burst.append({ "pos": rk.pos, "vel": Vector2(cos(th), sin(th)) * randf_range(40, 80), "life": 1.0 })
				for bs in rk.burst:
					bs.pos += bs.vel * dt
					bs.vel.y += 60.0 * dt
					bs.life -= dt * 1.2
			b.rockets = b.rockets.filter(func(rk): return rk.fuse > 0.0 or rk.burst.any(func(bs): return bs.life > 0.0))
		"pixie":
			if randf() < 0.35:
				b.parts.append({ "pos": r.size / 2.0 + Vector2(randf_range(-34, 34), randf_range(-6, 6)),
					"a": randf_range(0, TAU), "life": 1.0, "tw": randf_range(4, 9) })
			for p in b.parts:
				if b.press_v > 0.0:          # the stir: everything orbits the centre
					p.a += 4.0 * dt
					var rr: float = 16.0 + (1.0 - p.life) * 22.0
					p.pos = r.size / 2.0 + Vector2(cos(p.a) * rr * 1.6, sin(p.a) * rr * 0.8)
				else:
					p.pos.y += 14.0 * dt
					p.pos.x += sin(t * 3.0 + p.tw) * 5.0 * dt
				p.life -= dt * 0.5
			b.parts = b.parts.filter(func(p): return p.life > 0.0)

static func _fly(b: Dictionary, dt: float, grav: float, decay: float) -> void:
	for p in b.parts:
		p.pos += p.vel * dt
		p.vel.y += grav * dt
		p.life -= dt * decay
	b.parts = b.parts.filter(func(p): return p.life > 0.0)

static func _fizz(n: CanvasItem, at: Vector2) -> void:
	for i in 7:
		var th := randf_range(0, TAU)
		var L := randf_range(3, 10)
		n.draw_line(at, at + Vector2(cos(th), sin(th)) * L, Color(1, 0.9, 0.67, 0.9), 1.0)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	var c := r.get_center()
	match b.id:
		"grindstone":
			ElemKit.face(n, r, Color(0.1, 0.094, 0.11, 0.96), Color(0.78, 0.75, 0.71, 0.5))
			ElemKit.label(n, r, "GRIND", Color(0.93, 0.91, 0.88))
			n.draw_set_transform(o + Vector2(r.size.x - 4, r.size.y - 2), t * (7.0 + pv * 8.0), Vector2.ONE)
			n.draw_circle(Vector2.ZERO, 7.0, Color(0.29, 0.275, 0.31))
			n.draw_line(Vector2(-7, 0), Vector2(7, 0), Color(0.86, 0.84, 0.88, 0.6), 1.0)
			n.draw_line(Vector2(0, -7), Vector2(0, 7), Color(0.86, 0.84, 0.88, 0.6), 1.0)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_spark_lines(n, b, o)
		"sparkler":
			ElemKit.face(n, r, Color(0.086, 0.07, 0.1, 0.96), Color(1, 0.82, 0.59, 0.4))
			ElemKit.label(n, r, "FIZZ", Color(1, 0.93, 0.83))
			var a: float = t * 1.3
			_fizz(n, c + Vector2(cos(a) * r.size.x * 0.52, sin(a) * r.size.y * 0.62))
			if b.second > 0.0:
				_fizz(n, c + Vector2(cos(a + PI) * r.size.x * 0.52, sin(a + PI) * r.size.y * 0.62))
		"flint":
			ElemKit.face(n, r, Color(0.094, 0.086, 0.1, 0.96 - pv * 0.3), Color(0.75, 0.71, 0.67, 0.4 + pv * 0.6))
			ElemKit.label(n, r, "STRIKE", Color(0.92, 0.89, 0.86))
			if randf() < 0.008:              # one shy glint, rarely
				n.draw_rect(Rect2(o + Vector2(13, r.size.y - 9), Vector2(2, 2)), Color(1, 1, 1, 0.7))
			_spark_lines(n, b, o)
		"welding":
			ElemKit.face(n, r, Color(0.086, 0.086, 0.11, 0.96), Color(0.67, 0.69, 0.75, 0.45))
			ElemKit.label(n, r, "WELD", Color(0.9, 0.91, 0.93))
			for s in b.seam:                 # the seam cools white → orange → dull red
				var k: float = minf(1.0, s.age / 4.0)
				n.draw_rect(Rect2(o + s.pos - Vector2(1, 1), Vector2(2.4, 2.4)),
					Color(1.0 - k * 0.51, 0.9 - k * 0.75, 0.67 - k * 0.55))
			var a: float = b.p * TAU
			ElemKit.glow(n, c + Vector2(cos(a) * r.size.x * 0.52, sin(a) * r.size.y * 0.62),
				9.0, Color(0.94, 0.98, 1.0, 0.95), 3)
			_spark_lines(n, b, o)
		"fountain":
			ElemKit.face(n, r, Color(0.078, 0.063, 0.11, 0.92), Color(1, 0.78, 0.51, 0.45))
			ElemKit.label(n, r, "FIESTA", Color(1, 0.94, 0.82))
			for p in b.parts:
				n.draw_rect(Rect2(o + p.pos, Vector2(1.8, 1.8)), Color(1, 0.84, 0.51, p.life))
			for rk in b.rockets:
				for bs in rk.burst:
					if bs.life > 0.0:
						n.draw_rect(Rect2(o + bs.pos, Vector2(2, 2)), Color(1, 0.67, 0.78, bs.life))
		"pixie":
			ElemKit.face(n, r, Color(0.094, 0.07, 0.125, 0.92), Color(0.9, 0.75, 1.0, 0.5))
			ElemKit.label(n, r, "PIXIE", Color(0.96, 0.89, 1.0))
			for p in b.parts:
				var tw: float = maxf(0.0, sin(t * p.tw)) * p.life
				ElemKit.twinkle(n, o + p.pos, 2.5, Color(0.94, 0.82, 1.0, tw))

static func _spark_lines(n: CanvasItem, b: Dictionary, o: Vector2) -> void:
	for p in b.parts:
		n.draw_line(o + p.pos, o + p.pos - p.vel * 0.02, Color(1, 0.71 + 0.29 * p.life, 0.35, p.life), 1.3)
