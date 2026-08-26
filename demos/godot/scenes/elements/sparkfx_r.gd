extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
const Base := preload("res://scenes/elements/sparkfx.gd")
## SPARKS — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"grindstone": { "name": "Flint wheel", "hint": "blue-white, arcing higher — gravity ÷2" },
	"sparkler": { "name": "Frost sparkler", "hint": "iced over, orbiting at half speed" },
	"flint": { "name": "Wet strike", "hint": "count starved — six reluctant sparks, a sad puff" },
	"welding": { "name": "Solder line", "hint": "half heat — cool tones, twice the patience" },
	"fountain": { "name": "Ember fall", "hint": "inverted — the fireworks pour DOWN" },
	"pixie": { "name": "Soot motes", "hint": "chimney grey — falls faster, swirls less" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)
	if b.id == "flint":
		b.puff = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"flint":
			# dials: 18 sparks → 6, velocity ÷2, plus the sad steam puff
			b.press_v = 1.0
			b.puff = 1.0
			for i in 6:
				var th := randf_range(-2.6, -0.5)
				var v := randf_range(30, 100)
				b.parts.append({ "pos": Vector2(14, r.size.y - 8), "vel": Vector2(cos(th), sin(th)) * v,
					"life": randf_range(0.3, 0.7) })
		"fountain":
			# dial: rockets pop LOW, their bursts rain downward naturally
			for i in 3:
				b.rockets.append({ "pos": Vector2(randf_range(0, r.size.x), randf_range(-14, -2)),
					"fuse": i * 0.16, "burst": [] })
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"grindstone":
			# dial: spark gravity 300 → 140 (they arc higher and hang)
			b.press_v = maxf(0.0, b.press_v - dt * 1.2)
			if randf() < 0.25 + b.press_v * 0.7:
				for i in (4 if b.press_v > 0.0 else 1):
					b.parts.append({ "pos": Vector2(r.size.x - 6, r.size.y - 4),
						"vel": Vector2(randf_range(30, 120), randf_range(-130, -40)), "life": randf_range(0.5, 1.0) })
			Base._fly(b, dt, 140.0, 1.4)
		"flint":
			b.press_v = maxf(0.0, b.press_v - dt * 1.2)
			b.puff = maxf(0.0, b.puff - dt * 0.8)
			Base._fly(b, dt, 260.0, 1.7)
		"welding":
			# dials: crawl 0.12 → 0.06 · seam kept twice as long
			b.press_v = maxf(0.0, b.press_v - dt * 1.2)
			b.p = fmod(b.p + dt * 0.06, 1.0)
			var a: float = b.p * TAU
			b.seam.append({ "pos": r.size / 2.0 + Vector2(cos(a) * r.size.x * 0.52, sin(a) * r.size.y * 0.62), "age": 0.0 })
			if b.seam.size() > 90:
				b.seam.pop_front()
			for s in b.seam:
				s.age += dt
			Base._fly(b, dt, 240.0, 1.6)
		"fountain":
			# dial: the fountain pours DOWN from above the button
			b.press_v = maxf(0.0, b.press_v - dt * 1.2)
			var swell := 0.5 + 0.5 * sin(t * 0.8)
			if randf() < 0.4 + swell * 0.4:
				b.parts.append({ "pos": Vector2(r.size.x / 2.0 + randf_range(-4, 4), -26.0),
					"vel": Vector2(randf_range(-30, 30), randf_range(20, 60) * (0.7 + swell * 0.5)), "life": 1.0 })
			Base._fly(b, dt, 60.0, 1.1)
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
			# dials: fall 14 → 34 · swirl amplitude 5 → 1.5 · stir orbit ÷2
			b.press_v = maxf(0.0, b.press_v - dt * 0.7)
			if randf() < 0.35:
				b.parts.append({ "pos": r.size / 2.0 + Vector2(randf_range(-34, 34), randf_range(-6, 6)),
					"a": randf_range(0, TAU), "life": 1.0, "tw": randf_range(4, 9) })
			for p in b.parts:
				if b.press_v > 0.0:
					p.a += 2.0 * dt
					var rr: float = 16.0 + (1.0 - p.life) * 22.0
					p.pos = r.size / 2.0 + Vector2(cos(p.a) * rr * 1.6, sin(p.a) * rr * 0.8)
				else:
					p.pos.y += 34.0 * dt
					p.pos.x += sin(t * 3.0 + p.tw) * 1.5 * dt
				p.life -= dt * 0.5
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	var c := r.get_center()
	match b.id:
		"grindstone":
			# dial: warm sparks → blue-white flint sparks
			ElemKit.face(n, r, Color(0.08, 0.09, 0.12, 0.96), Color(0.71, 0.78, 0.9, 0.5))
			ElemKit.label(n, r, "FLINT WHEEL", Color(0.89, 0.92, 0.97))
			n.draw_set_transform(o + Vector2(r.size.x - 4, r.size.y - 2), t * (7.0 + pv * 8.0), Vector2.ONE)
			n.draw_circle(Vector2.ZERO, 7.0, Color(0.25, 0.27, 0.33))
			n.draw_line(Vector2(-7, 0), Vector2(7, 0), Color(0.84, 0.88, 0.96, 0.6), 1.0)
			n.draw_line(Vector2(0, -7), Vector2(0, 7), Color(0.84, 0.88, 0.96, 0.6), 1.0)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for p in b.parts:
				n.draw_line(o + p.pos, o + p.pos - p.vel * 0.02,
					Color(0.78 + 0.22 * p.life, 0.88, 1.0, p.life), 1.3)
		"sparkler":
			# dials: warm fizz → iced fizz · orbit 1.3 → 0.65
			ElemKit.face(n, r, Color(0.055, 0.078, 0.11, 0.96), Color(0.67, 0.86, 1.0, 0.4))
			ElemKit.label(n, r, "FROST FIZZ", Color(0.87, 0.95, 1.0))
			var a: float = t * 0.65
			_frost_fizz(n, c + Vector2(cos(a) * r.size.x * 0.52, sin(a) * r.size.y * 0.62))
			if b.second > 0.0:
				_frost_fizz(n, c + Vector2(cos(a + PI) * r.size.x * 0.52, sin(a + PI) * r.size.y * 0.62))
		"flint":
			ElemKit.face(n, r, Color(0.086, 0.094, 0.1, 0.96 - pv * 0.15), Color(0.63, 0.69, 0.71, 0.4 + pv * 0.4))
			ElemKit.label(n, r, "DAMP", Color(0.86, 0.89, 0.88))
			if b.puff > 0.0:               # the sad puff of steam
				n.draw_circle(o + Vector2(16, r.size.y - 12 - (1.0 - b.puff) * 10.0),
					3.0 + (1.0 - b.puff) * 5.0, Color(0.82, 0.85, 0.86, b.puff * 0.35))
			Base._spark_lines(n, b, o)
		"welding":
			# dial: white-hot → solder silver-blue
			ElemKit.face(n, r, Color(0.078, 0.086, 0.1, 0.96), Color(0.63, 0.71, 0.78, 0.45))
			ElemKit.label(n, r, "SOLDER", Color(0.88, 0.91, 0.94))
			for s in b.seam:               # cools silver → blue-grey
				var k: float = minf(1.0, s.age / 8.0)
				n.draw_rect(Rect2(o + s.pos - Vector2(1, 1), Vector2(2.4, 2.4)),
					Color(0.9 - k * 0.45, 0.93 - k * 0.42, 0.98 - k * 0.35))
			var a: float = b.p * TAU
			ElemKit.glow(n, c + Vector2(cos(a) * r.size.x * 0.52, sin(a) * r.size.y * 0.62),
				7.0, Color(0.82, 0.9, 1.0, 0.9), 3)
			Base._spark_lines(n, b, o)
		"fountain":
			ElemKit.face(n, r, Color(0.1, 0.063, 0.047, 0.92), Color(1, 0.71, 0.43, 0.45))
			ElemKit.label(n, r, "EMBERFALL", Color(1, 0.9, 0.78))
			for p in b.parts:
				n.draw_rect(Rect2(o + p.pos, Vector2(1.8, 1.8)), Color(1, 0.7, 0.35, p.life))
			for rk in b.rockets:
				for bs in rk.burst:
					if bs.life > 0.0:
						n.draw_rect(Rect2(o + bs.pos, Vector2(2, 2)), Color(1, 0.55, 0.31, bs.life))
		"pixie":
			# dial: pixie violet → chimney grey, twinkle dimmed
			ElemKit.face(n, r, Color(0.086, 0.082, 0.078, 0.92), Color(0.6, 0.57, 0.55, 0.5))
			ElemKit.label(n, r, "SOOT", Color(0.82, 0.8, 0.78))
			for p in b.parts:
				var tw: float = maxf(0.2, sin(t * p.tw * 0.5)) * p.life
				n.draw_rect(Rect2(o + p.pos, Vector2(2, 2)), Color(0.55, 0.52, 0.5, tw * 0.8))
		_:
			Base.draw(n, b, t)

static func _frost_fizz(n: CanvasItem, at: Vector2) -> void:
	for i in 7:
		var th := randf_range(0, TAU)
		var L := randf_range(3, 10)
		n.draw_line(at, at + Vector2(cos(th), sin(th)) * L, Color(0.75, 0.9, 1.0, 0.9), 1.0)
