extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
## FIRE — the RHYMES. Each entry is its family original with two or three
## dials turned (named per branch). Right-click a card in the bestiary to
## swap original ⇄ rhyme; comparing the two files IS the lesson.

const RHYMES := {
	"candleflame": { "name": "Ghost candles", "hint": "hue warm→spectral, flicker halved" },
	"inferno": { "name": "Everglow", "hint": "gold palette, half speed, embers float" },
	"ember_bed": { "name": "Frost bed", "hint": "hue fire→ice, breath 3× slower, sparks sink" },
	"fireball": { "name": "Iceball", "hint": "orbit reversed, palette flipped cold" },
	"backdraft": { "name": "Steam vent", "hint": "repainted white, whoosh faster" },
	"heat_haze": { "name": "Deep ripple", "hint": "sway ÷4, palette submarine" },
	"solar_flare": { "name": "Lunar wisps", "hint": "silver, half-bright, twice as patient" },
	"magma_veins": { "name": "Sap veins", "hint": "amber, pulse 4× slower, thinner" },
	"meteor": { "name": "Rising lanterns", "hint": "direction reversed, speed ÷3, warm" },
	"phoenix": { "name": "Moth spiral", "hint": "feathers fall instead of rise, dusk-grey" },
}

static func init(b: Dictionary) -> void:
	preload("res://scenes/elements/fire.gd").init(b)   # same state skeleton

static func press(b: Dictionary, pos: Vector2) -> void:
	preload("res://scenes/elements/fire.gd").press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c := b
	match b.id:
		"inferno":
			# dials: rise 40→22 · ember gravity +60→−25
			b.press_v = maxf(0.0, b.press_v - dt * 1.6)
			if randf() < 0.5:
				var r: Rect2 = b.rect
				b.parts.append({ "pos": Vector2(randf_range(6, r.size.x - 6), r.size.y),
					"vel": Vector2(0, -22), "life": 1.0, "kind": "flame", "r": randf_range(5, 10) })
			for p in b.parts:
				p.pos += p.vel * dt
				if p.kind == "flame":
					p.pos.x += sin(p.pos.y * 0.15) * 12.0 * dt
					p.life -= dt * 0.7
				else:
					p.vel.y -= 25.0 * dt
					p.life -= dt * 0.9
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"meteor":
			# dials: streaks reversed (rise), speed ÷3
			b.press_v = maxf(0.0, b.press_v - dt * 1.6)
			b.timer -= dt
			if b.timer <= 0.0:
				var r: Rect2 = b.rect
				b.parts.append({ "kind": "meteor", "pos": Vector2(randf_range(r.size.x * 0.2, r.size.x),
					randf_range(r.size.y * 0.6, r.size.y + 8)), "v": randf_range(40, 70), "life": 1.6 })
				b.timer = randf_range(1.5, 3.5)
			for p in b.parts:
				p.pos += Vector2(-p.v * 0.35, -p.v) * dt
				p.life -= dt * 0.4
			b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.pos.y > -20.0)
		"phoenix":
			# dials: climb −26 → fall +18
			b.press_v = maxf(0.0, b.press_v - dt * 0.8)
			if randf() < 0.35:
				var r: Rect2 = b.rect
				b.parts.append({ "a": randf_range(0, TAU), "y": -r.size.y * 0.2,
					"spin": randf_range(1.5, 3.0), "life": 1.0 })
			for p in b.parts:
				p.a += p.spin * (1.0 + b.press_v * 2.0) * dt
				p.y += 18.0 * dt
				p.life -= dt * 0.6
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		_:
			preload("res://scenes/elements/fire.gd").tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	match b.id:
		"candleflame":
			# dials: palette orange→spectral · flicker 9/23 → 4/9
			ElemKit.face(n, r, Color(0.055, 0.1, 0.094, 0.92), Color(0.47, 0.86, 0.75, 0.5))
			ElemKit.label(n, r, "HAUNT", Color(0.79, 0.95, 0.89))
			for wk in b.wicks:
				var flick: float = sin(t * 4.0 + wk.seed) * 0.5 + sin(t * 9.0 + wk.seed * 3.0) * 0.5
				var h := (10.0 + flick * 3.0) * (1.0 + pv * 2.2)
				var y0 := o.y + r.size.y - 2.0
				ElemKit.glow(n, Vector2(o.x + wk.x, y0 - h * 0.45), maxf(4.0, h * 0.7), Color(0.35, 0.86, 0.71, 0.55), 3)
				n.draw_circle(Vector2(o.x + wk.x, y0 - h * 0.6), 2.2, Color(0.59, 1.0, 0.86, 0.85))
		"inferno":
			ElemKit.face(n, r, Color(0.11, 0.086, 0.031), Color(1, 0.8, 0.43, 0.6))
			for p in b.parts:
				var pos: Vector2 = o + p.pos
				if p.kind == "flame":
					if r.grow(2.0).has_point(pos):
						ElemKit.glow(n, pos, p.r * (0.4 + p.life), Color(1, 0.92, 0.63, 0.5 * p.life), 3)
				else:
					n.draw_rect(Rect2(pos, Vector2(2, 2)), Color(1, 0.88, 0.59, p.life))
			ElemKit.label(n, r, "LINGER", Color(1, 0.95, 0.82))
		"ember_bed":
			# dials: palette fire→ice · breath speed handled via slow sin here
			ElemKit.face(n, r, Color(0.063, 0.078, 0.1), Color(0.31, 0.51, 0.7, 0.6))
			for i in 14:
				var cp := o + Vector2(8 + fmod(i * 37.7, r.size.x - 16), 8 + fmod(i * 23.3, r.size.y - 16))
				var a: float = maxf(0.0, 0.25 + 0.35 * sin(t * 0.35 + i)) + pv * 0.5
				ElemKit.glow(n, cp, 6.0 + pv * 6.0, Color(0.59, 0.82, 1.0, minf(1.0, a)), 3)
			for p in b.parts:
				n.draw_rect(Rect2(o + p.pos + Vector2(0, (1.0 - p.life) * 20.0), Vector2(2, 2)),
					Color(0.75, 0.9, 1.0, p.life))
			ElemKit.label(n, r, "SHIVER", Color(0.82, 0.92, 1.0, 0.75 + pv * 0.25))
		"fireball":
			# dials: orbit sign + palette — draw with mirrored angle + cold hues
			ElemKit.face(n, r, Color(0.047, 0.07, 0.1, 0.9), Color(0.51, 0.78, 1.0, 0.45))
			ElemKit.label(n, r, "HAIL MARY", Color(0.84, 0.92, 1.0))
			var tail: Array = b.tail
			for i in range(tail.size() - 1, -1, -1):
				var k := 1.0 - float(i) / maxf(1.0, tail.size())
				var mirrored := Vector2(r.size.x - tail[i].x, tail[i].y)   # the reversal
				ElemKit.glow(n, o + mirrored, 6.0 + k * 8.0, Color(0.71, 0.88, 1.0, 0.5 * k), 3)
			for p in b.parts:
				n.draw_rect(Rect2(o + p.pos, Vector2(2.5, 2.5)), Color(0.75, 0.92, 1.0, p.life))
		"backdraft":
			ElemKit.face(n, r, Color(0.07, 0.078, 0.094, 0.95), Color(0.78, 0.82, 0.86, 0.35))
			ElemKit.label(n, r, "KETTLE", Color(0.89, 0.92, 0.93))
			for p in b.parts:
				var pos: Vector2 = o + p.pos
				if p.kind == "smoke":
					n.draw_circle(pos, p.r, Color(0.82, 0.84, 0.88, 0.13 * p.life))
				else:
					ElemKit.glow(n, pos, p.r, Color(0.94, 0.96, 1.0, 0.5 * p.life), 3)
		"heat_haze":
			# dials: sway 6→1.6, amplitude up, palette submarine
			ElemKit.face(n, r, Color(0.04, 0.086, 0.133, 0.92), Color(0.39, 0.7, 0.9, 0.45))
			for i in 3:
				var off := sin(t * 1.6 + i * 1.1) * (2.2 + pv * 5.0) * (i + 1)
				ElemKit.label(n, Rect2(r.position + Vector2(off, 0), r.size), "SUBMERGE",
					Color(0.66, 0.85, 0.94, 0.85 if i == 0 else 0.18))
		"solar_flare":
			ElemKit.glow(n, r.get_center(), r.size.x * 0.5, Color(0.78, 0.82, 0.9, 0.16), 4)
			ElemKit.face(n, r, Color(0.078, 0.086, 0.118, 0.9), Color(0.82, 0.86, 0.92, 0.6))
			ElemKit.label(n, r, "SELENE", Color(0.91, 0.93, 0.96))
			for p in b.parts:
				if p.kind != "arc":
					continue
				var lift: float = p.h * sin(minf(1.0, 1.0 - p.life) * PI)
				var base: Vector2 = o + p.p
				ElemKit.qcurve(n, base - Vector2(sin(p.th), -cos(p.th)) * 8.0,
					base + Vector2(cos(p.th), sin(p.th)) * lift,
					base + Vector2(sin(p.th), -cos(p.th)) * 8.0,
					Color(0.86, 0.89, 0.96, 0.4 * p.life), 1.5)
		"magma_veins":
			ElemKit.face(n, r, Color(0.07, 0.078, 0.031))
			for v in b.veins:
				var pts: Array = v.pts
				for i in range(pts.size() - 1):
					var a: float = maxf(0.08, 0.5 + 0.5 * sin(t * 0.5 + v.ph + i * 0.7)) * (0.5 + pv)
					n.draw_line(o + pts[i], o + pts[i + 1], Color(0.86, 0.71, 0.27, minf(1.0, a)), 1.0 + pv * 1.5)
			ElemKit.label(n, r, "AMBER", Color(0.94, 0.9, 0.75, 0.9))
		"meteor":
			ElemKit.face(n, r, Color(0.07, 0.055, 0.118, 0.95), Color(1, 0.75, 0.47, 0.5))
			for s in b.stars:
				n.draw_rect(Rect2(o + s, Vector2(1.5, 1.5)), Color(0.86, 0.86, 1.0, 0.4))
			for p in b.parts:
				if p.kind != "meteor":
					continue
				var head: Vector2 = o + p.pos
				n.draw_rect(Rect2(head - Vector2(2, 3), Vector2(4, 6)), Color(1, 0.67, 0.31, 0.85 * minf(1.0, p.life)))
				n.draw_line(head + Vector2(0, 3), head + Vector2(3, 16), Color(1, 0.47, 0.16, 0.35 * minf(1.0, p.life)), 1.5)
			ElemKit.label(n, r, "ASCEND", Color(1, 0.91, 0.8))
		"phoenix":
			ElemKit.face(n, r, Color(0.086, 0.078, 0.1, 0.9), Color(0.75, 0.73, 0.78, 0.55))
			ElemKit.label(n, r, "DUSK", Color(0.89, 0.87, 0.91))
			for p in b.parts:
				var pos := o + Vector2(r.size.x / 2.0 + cos(p.a) * r.size.x * 0.5, p.y)
				n.draw_set_transform(pos, sin(p.a) * 0.6, Vector2(1.0, 2.7))
				n.draw_circle(Vector2.ZERO, 2.2, Color(0.78, 0.76, 0.84, 0.4 * p.life))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_:
			preload("res://scenes/elements/fire.gd").draw(n, b, t)
