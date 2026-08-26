extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
## FIRE — ten buttons, ported one-to-one from the web bestiary.
## Every button: init() seeds state into its dictionary, tick() advances it,
## draw() paints it, press() is the thank-you. All state lives in `b`.

const TITLE := "Fire"
const BLURB := "heat, flame, and things that remember being flame"
const DEFS := [
	{ "id": "candleflame", "name": "Candleflame", "hint": "flames lick the bottom edge; press to flare them tall" },
	{ "id": "inferno", "name": "Inferno", "hint": "the whole face burns from within; press for an ember burst" },
	{ "id": "ember_bed", "name": "Ember bed", "hint": "coals pulse under a dark crust; press to stoke them" },
	{ "id": "fireball", "name": "Fireball", "hint": "a fireball orbits with a tail; press and it dives through the centre" },
	{ "id": "backdraft", "name": "Backdraft", "hint": "smoke curls quietly… press to ignite the whoosh" },
	{ "id": "heat_haze", "name": "Heat haze", "hint": "the caption shimmers like air over asphalt; press for a heat wave" },
	{ "id": "solar_flare", "name": "Solar flare", "hint": "prominences erupt off the rim; press for a mass ejection" },
	{ "id": "magma_veins", "name": "Magma veins", "hint": "lava glows through cracks in dark crust; press to surge" },
	{ "id": "meteor", "name": "Meteor watch", "hint": "shooting stars streak past; press to call a shower" },
	{ "id": "phoenix", "name": "Phoenix", "hint": "flame feathers spiral upward; press and the wings beat out" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	var r: Rect2 = b.rect
	match b.id:
		"candleflame":
			b.wicks = []
			var x := 10.0
			while x < r.size.x - 6.0:
				b.wicks.append({ "x": x, "seed": randf_range(0, 9) })
				x += 14.0
		"fireball":
			b.tail = []
			b.dive = 0.0
		"magma_veins":
			b.veins = []
			for v in 4:
				var pts := []
				var vx := 0.0
				var vy := randf_range(6, r.size.y - 6)
				while vx < r.size.x:
					pts.append(Vector2(vx, vy))
					vx += randf_range(10, 22)
					vy = clampf(vy + randf_range(-8, 8), 4, r.size.y - 4)
				b.veins.append({ "pts": pts, "ph": randf_range(0, 9) })
		"meteor":
			b.stars = []
			for i in 14:
				b.stars.append(Vector2(randf_range(-14, r.size.x + 14), randf_range(-14, r.size.y + 14)))
			b.timer = 1.0

static func press(b: Dictionary, _pos: Vector2) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"candleflame", "heat_haze", "magma_veins", "backdraft", "phoenix":
			b.press_v = 1.0
		"inferno":
			for i in 20:
				b.parts.append({ "pos": Vector2(randf_range(0, r.size.x), randf_range(0, r.size.y)),
					"vel": Vector2(randf_range(-70, 70), randf_range(-140, -30)), "life": 1.0, "kind": "ember" })
		"ember_bed":
			b.press_v = 1.0
			for i in 8:
				b.parts.append({ "pos": Vector2(randf_range(0, r.size.x), randf_range(0, r.size.y)),
					"vel": Vector2(0, randf_range(-60, -25)), "life": 1.0, "kind": "spark" })
		"fireball":
			if b.dive <= 0.0:
				b.dive = 1.0
		"solar_flare":
			for i in 4:
				_erupt(b, true)
		"meteor":
			for i in 6:
				_spawn_meteor(b)

static func _erupt(b: Dictionary, big: bool) -> void:
	var r: Rect2 = b.rect
	var th := randf_range(0, TAU)
	b.parts.append({ "kind": "arc", "th": th,
		"p": r.size / 2.0 + Vector2(cos(th) * r.size.x * 0.5, sin(th) * r.size.y * 0.62),
		"h": randf_range(28, 44) if big else randf_range(10, 20), "life": 1.0, "big": big })

static func _spawn_meteor(b: Dictionary) -> void:
	var r: Rect2 = b.rect
	b.parts.append({ "kind": "meteor", "pos": Vector2(randf_range(-20, r.size.x * 0.7), randf_range(-16, r.size.y * 0.3)),
		"v": randf_range(120, 200), "life": 1.0 })

static func tick(b: Dictionary, dt: float, t: float) -> void:
	b.press_v = maxf(0.0, b.press_v - dt * 1.6)
	var r: Rect2 = b.rect
	match b.id:
		"inferno":
			if randf() < 0.5:
				b.parts.append({ "pos": Vector2(randf_range(6, r.size.x - 6), r.size.y),
					"vel": Vector2(0, -40), "life": 1.0, "kind": "flame", "r": randf_range(5, 10) })
			for p in b.parts:
				p.pos += p.vel * dt
				if p.kind == "flame":
					p.pos.x += sin(p.pos.y * 0.15) * 20.0 * dt
					p.life -= dt * 0.9
				else:
					p.vel.y += 60.0 * dt
					p.life -= dt * 1.1
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"ember_bed":
			for p in b.parts:
				p.pos += p.vel * dt
				p.pos.x += sin(p.pos.y * 0.2) * 12.0 * dt
				p.life -= dt * 1.4
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"fireball":
			var fp: Vector2
			if b.dive > 0.0:
				b.dive -= dt * 1.4
				var k := 1.0 - maxf(0.0, b.dive)
				fp = Vector2(r.size.x / 2.0 - r.size.x + k * r.size.x * 2.0, r.size.y / 2.0)
				if absf(fp.x - r.size.x / 2.0) < 8.0 and b.parts.is_empty():
					for i in 14:
						var th := randf_range(0, TAU)
						b.parts.append({ "pos": r.size / 2.0, "vel": Vector2(cos(th), sin(th)) * randf_range(40, 120), "life": 1.0 })
			else:
				var a := t * 2.2
				fp = r.size / 2.0 + Vector2(cos(a) * r.size.x * 0.58, sin(a) * r.size.y * 0.95)
			b.tail.push_front(fp)
			if b.tail.size() > 18:
				b.tail.pop_back()
			for p in b.parts:
				p.pos += p.vel * dt
				p.life -= dt * 1.6
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"backdraft":
			if randf() < 0.12:
				b.parts.append({ "kind": "smoke", "pos": Vector2(randf_range(10, r.size.x - 10), 2.0),
					"r": randf_range(3, 6), "life": 1.0 })
			if b.press_v > 0.0 and randf() < 0.9:
				b.parts.append({ "kind": "fire", "pos": Vector2(randf_range(0, r.size.x), r.size.y),
					"r": randf_range(6, 12), "life": 1.0 })
			for p in b.parts:
				if p.kind == "smoke":
					p.pos.y -= 14.0 * dt
					p.pos.x += sin(p.pos.y * 0.1 + p.r) * 10.0 * dt
					p.r += 4.0 * dt
					p.life -= dt * 0.5
				else:
					p.pos.y -= 90.0 * dt
					p.life -= dt * 1.3
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"solar_flare":
			if randf() < 0.03:
				_erupt(b, false)
			for p in b.parts:
				p.life -= dt * (0.55 if p.big else 0.9)
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"meteor":
			b.timer -= dt
			if b.timer <= 0.0:
				_spawn_meteor(b)
				b.timer = randf_range(1.5, 3.5)
			for p in b.parts:
				p.pos += Vector2(p.v, p.v * 0.55) * dt
				p.life -= dt * 0.7
			b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.pos.x < r.size.x + 40)
		"phoenix":
			if randf() < 0.35:
				b.parts.append({ "a": randf_range(0, TAU), "y": r.size.y * 1.1,
					"spin": randf_range(1.5, 3.0), "life": 1.0 })
			for p in b.parts:
				p.a += p.spin * dt
				p.y -= 26.0 * dt
				p.life -= dt * 0.6
			b.parts = b.parts.filter(func(p): return p.life > 0.0)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	match b.id:
		"candleflame":
			ElemKit.face(n, r, Color(0.12, 0.06, 0.055, 0.95), Color(1, 0.63, 0.35, 0.5))
			ElemKit.label(n, r, "IGNITE", Color(1, 0.85, 0.69))
			for wk in b.wicks:
				var flick: float = sin(t * 9.0 + wk.seed) * 0.5 + sin(t * 23.0 + wk.seed * 3.0) * 0.5
				var h := (10.0 + flick * 3.0) * (1.0 + pv * 2.2)
				var y0 := o.y + r.size.y - 2.0
				ElemKit.glow(n, Vector2(o.x + wk.x, y0 - h * 0.45), maxf(4.0, h * 0.7), Color(1, 0.55, 0.18, 0.55), 3)
				n.draw_circle(Vector2(o.x + wk.x, y0 - h * 0.6), 2.2, Color(1, 0.86, 0.5, 0.85))
		"inferno":
			ElemKit.face(n, r, Color(0.11, 0.055, 0.043), Color(1, 0.47, 0.2, 0.6))
			for p in b.parts:
				var pos: Vector2 = o + p.pos
				if p.kind == "flame":
					if r.grow(2.0).has_point(pos):
						ElemKit.glow(n, pos, p.r * (0.4 + p.life), Color(1, 0.7, 0.25, 0.5 * p.life), 3)
				else:
					n.draw_rect(Rect2(pos, Vector2(2, 2)), Color(1, 0.7, 0.35, p.life))
			ElemKit.label(n, r, "BURN", Color(1, 0.91, 0.76))
		"ember_bed":
			ElemKit.face(n, r, Color(0.1, 0.063, 0.078), Color(0.47, 0.24, 0.16, 0.6))
			for i in 14:
				var cp := o + Vector2(8 + fmod(i * 37.7, r.size.x - 16), 8 + fmod(i * 23.3, r.size.y - 16))
				var a: float = maxf(0.0, 0.25 + 0.35 * sin(t * (0.6 + fmod(i, 3.0) * 0.4) + i)) + pv * 0.5
				ElemKit.glow(n, cp, 6.0 + pv * 6.0, Color(1, 0.55, 0.24, minf(1.0, a)), 3)
			for p in b.parts:
				n.draw_rect(Rect2(o + p.pos, Vector2(2, 2)), Color(1, 0.78, 0.47, p.life))
			ElemKit.label(n, r, "STOKE", Color(1, 0.86, 0.75, 0.75 + pv * 0.25))
		"fireball":
			ElemKit.face(n, r, Color(0.094, 0.055, 0.078, 0.92), Color(1, 0.59, 0.31, 0.45))
			ElemKit.label(n, r, "COMET", Color(1, 0.87, 0.75))
			var tail: Array = b.tail
			for i in range(tail.size() - 1, -1, -1):
				var k := 1.0 - float(i) / maxf(1.0, tail.size())
				ElemKit.glow(n, o + tail[i], 6.0 + k * 8.0, Color(1, 0.6, 0.2, 0.5 * k), 3)
			for p in b.parts:
				n.draw_rect(Rect2(o + p.pos, Vector2(2.5, 2.5)), Color(1, 0.75, 0.43, p.life))
		"backdraft":
			ElemKit.face(n, r, Color(0.078, 0.063, 0.094, 0.95), Color(0.63, 0.59, 0.67, 0.35))
			ElemKit.label(n, r, "BACKDRAFT", Color(0.85, 0.82, 0.88))
			for p in b.parts:
				var pos: Vector2 = o + p.pos
				if p.kind == "smoke":
					n.draw_circle(pos, p.r, Color(0.59, 0.59, 0.63, 0.13 * p.life))
				else:
					ElemKit.glow(n, pos, p.r, Color(1, 0.78, 0.4, 0.6 * p.life), 3)
		"heat_haze":
			ElemKit.face(n, r, Color(0.13, 0.078, 0.055, 0.95), Color(1, 0.55, 0.27, 0.45))
			for i in 3:      # the mirage: ghost copies of the caption, swaying
				var off := sin(t * 6.0 + i * 1.1) * (0.8 + pv * 5.0) * (i + 1)
				var gr := Rect2(r.position + Vector2(off, 0), r.size)
				ElemKit.label(n, gr, "MIRAGE", Color(1, 0.79, 0.63, 0.85 if i == 0 else 0.18))
			for i in 3:      # warmth rising off the top edge
				var hx := o.x + r.size.x * (0.25 + i * 0.25) + sin(t * 3.0 + i * 2.0) * 6.0
				var hy := o.y - 6.0 - fmod(t * 18.0 + i * 13.0, 22.0)
				n.draw_circle(Vector2(hx, hy), 6.0, Color(1, 0.63, 0.31, 0.06))
		"solar_flare":
			ElemKit.glow(n, r.get_center(), r.size.x * 0.55, Color(1, 0.55, 0.16, 0.3), 4)
			ElemKit.face(n, r, Color(0.16, 0.063, 0.031, 0.9), Color(1, 0.67, 0.31, 0.7))
			ElemKit.label(n, r, "FLARE", Color(1, 0.89, 0.72))
			for p in b.parts:
				if p.kind != "arc":
					continue
				var lift: float = p.h * sin(minf(1.0, 1.0 - p.life) * PI)
				var nx := cos(p.th)
				var ny := sin(p.th)
				var base: Vector2 = o + p.p
				ElemKit.qcurve(n, base - Vector2(ny, -nx) * 8.0, base + Vector2(nx, ny) * lift,
					base + Vector2(ny, -nx) * 8.0, Color(1, 0.67, 0.27, 0.7 * p.life), 2.5 if p.big else 1.5)
		"magma_veins":
			ElemKit.face(n, r, Color(0.09, 0.063, 0.09), Color(0.35, 0.2, 0.15, 0.6))
			for v in b.veins:
				var pts: Array = v.pts
				for i in range(pts.size() - 1):
					var a: float = maxf(0.08, 0.5 + 0.5 * sin(t * 2.0 + v.ph + i * 0.7)) * (0.5 + pv)
					n.draw_line(o + pts[i], o + pts[i + 1],
						Color(1.0, (0.35 + pv * 0.35), 0.12, minf(1.0, a)), 1.5 + pv * 2.0)
			ElemKit.label(n, r, "MAGMA", Color(1, 0.84, 0.7, 0.9))
		"meteor":
			ElemKit.face(n, r, Color(0.07, 0.055, 0.118, 0.95), Color(1, 0.75, 0.47, 0.5))
			for s in b.stars:
				n.draw_rect(Rect2(o + s, Vector2(1.5, 1.5)), Color(0.86, 0.86, 1.0, 0.4))
			for p in b.parts:
				if p.kind != "meteor":
					continue
				var head: Vector2 = o + p.pos
				n.draw_line(head, head - Vector2(24, 13), Color(1, 0.9, 0.7, 0.9 * p.life), 2.0)
				n.draw_line(head - Vector2(24, 13), head - Vector2(40, 22), Color(1, 0.55, 0.2, 0.35 * p.life), 1.5)
			ElemKit.label(n, r, "WISH", Color(1, 0.91, 0.8))
		"phoenix":
			ElemKit.face(n, r, Color(0.11, 0.047, 0.063, 0.92), Color(1, 0.47, 0.24, 0.55))
			ElemKit.label(n, r, "RISE", Color(1, 0.84, 0.69))
			for p in b.parts:
				var pos := o + Vector2(r.size.x / 2.0 + cos(p.a) * r.size.x * 0.5, p.y)
				n.draw_set_transform(pos, sin(p.a) * 0.6, Vector2(1, 2.7))
				n.draw_circle(Vector2.ZERO, 2.2, Color(1, 0.47 + 0.4 * p.life, 0.24, 0.5 * p.life))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if pv > 0.0:
				var spread := (1.0 - pv) * r.size.x * 0.85
				for side in [-1.0, 1.0]:
					ElemKit.qcurve(n, r.get_center(),
						r.get_center() + Vector2(side * spread * 0.7, -r.size.y * 1.3),
						r.get_center() + Vector2(side * spread, -r.size.y * 0.2),
						Color(1, 0.59, 0.24, pv * 0.8), 3.0)
