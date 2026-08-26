extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
## EARTH & STONE — eight buttons, ported from the web bestiary.

const TITLE := "Earth & stone"
const BLURB := "cracks, crumbles, sand, and tectonic grudges"
const DEFS := [
	{ "id": "fault_line", "name": "Fault line", "hint": "a glowing crack crosses the face; press for the earthquake" },
	{ "id": "crumble", "name": "Crumble", "hint": "press and the face collapses into rubble — then rebuilds itself" },
	{ "id": "sandstorm", "name": "Sandstorm", "hint": "grains stream past and gnaw the edges; press for a gust" },
	{ "id": "landslide", "name": "Landslide", "hint": "pebbles trickle down the face; press to let the whole slope go" },
	{ "id": "geode", "name": "Geode", "hint": "plain rock outside; press to split it open on the sparkle" },
	{ "id": "tectonic", "name": "Tectonic", "hint": "three plates drift and grind; press to collide them" },
	{ "id": "quicksand", "name": "Quicksand", "hint": "the caption is slowly sinking; press to pull it back out" },
	{ "id": "boulder", "name": "Boulder", "hint": "a boulder patrols overhead; press and it drops on the button" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	var r: Rect2 = b.rect
	match b.id:
		"fault_line":
			b.crack = []
			var x := 0.0
			var y := r.size.y / 2.0 + randf_range(-6, 6)
			while x < r.size.x:
				b.crack.append(Vector2(x, y))
				x += randf_range(8, 18)
				y = clampf(y + randf_range(-6, 6), 8, r.size.y - 8)
			b.crack.append(Vector2(r.size.x, y))
		"crumble":
			b.mode = "solid"
			b.mode_t = 0.0
			b.shards = []
			var cols := 8
			var rows := 3
			for cx in cols:
				for cy in rows:
					b.shards.append({ "home": Vector2(cx * r.size.x / cols, cy * r.size.y / rows),
						"pos": Vector2.ZERO, "vel": Vector2.ZERO, "rot": 0.0, "vr": 0.0 })
			b.sw = r.size.x / cols
			b.sh = r.size.y / rows
		"sandstorm":
			b.grains = []
			for i in 40:
				b.grains.append({ "pos": Vector2(randf_range(-10, r.size.x + 10), randf_range(-14, r.size.y + 14)),
					"v": randf_range(30, 90) })
		"geode":
			b.open = 0.0
			b.opening = false
			b.glitter = []
			for i in 12:
				b.glitter.append({ "pos": Vector2(randf_range(14, r.size.x - 14), randf_range(8, r.size.y - 8)),
					"ph": randf_range(0, 9) })
		"quicksand":
			b.sink = 0.0
		"boulder":
			b.bx = -12.0
			b.by = -22.0
			b.vy = 0.0
			b.falling = false
			b.rot = 0.0
			b.squash = 0.0

static func press(b: Dictionary, _pos: Vector2) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"fault_line":
			b.press_v = 1.0
			for i in 10:
				b.parts.append({ "pos": Vector2(randf_range(0, r.size.x), r.size.y),
					"vel": Vector2(randf_range(-30, 30), randf_range(-80, -20)), "life": 1.0 })
		"crumble":
			if b.mode == "solid":
				b.mode = "falling"
				b.mode_t = 0.0
				for s in b.shards:
					s.pos = s.home
					s.vel = Vector2(randf_range(-20, 20), randf_range(-40, 10))
					s.rot = 0.0
					s.vr = randf_range(-3, 3)
		"sandstorm", "quicksand":
			b.press_v = 1.0
		"landslide":
			b.press_v = 1.0
			for i in 18:
				b.parts.append({ "pos": Vector2(randf_range(4, r.size.x - 4), 2.0),
					"vel": Vector2(0, randf_range(10, 30)), "r": randf_range(1.2, 2.6) })
		"geode":
			b.opening = true
		"tectonic":
			b.press_v = 1.0
			for i in 8:
				b.parts.append({ "pos": Vector2(r.size.x * (0.33 + (i % 2) * 0.34) + randf_range(-4, 4), r.size.y / 2.0),
					"vel": Vector2(0, randf_range(-50, -20)), "life": 1.0 })
		"boulder":
			if not b.falling:
				b.falling = true
				b.vy = 0.0

static func tick(b: Dictionary, dt: float, t: float) -> void:
	b.press_v = maxf(0.0, b.press_v - dt * (0.5 if b.id == "landslide" else 1.4))
	var r: Rect2 = b.rect
	match b.id:
		"fault_line":
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += 200.0 * dt
				p.life -= dt * 1.2
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"crumble":
			b.mode_t += dt
			if b.mode == "falling":
				for s in b.shards:
					s.pos += s.vel * dt
					s.vel.y += 240.0 * dt
					s.rot += s.vr * dt
				if b.mode_t > 1.1:
					b.mode = "rising"
					b.mode_t = 0.0
			elif b.mode == "rising":
				var k: float = minf(1.0, b.mode_t / 0.8)
				var e := 1.0 - pow(1.0 - k, 3.0)   # ease-out — repentant rubble
				for s in b.shards:
					s.pos += (s.home - s.pos) * e
					s.rot *= (1.0 - e)
				if k >= 1.0:
					b.mode = "solid"
		"sandstorm":
			var wind: float = 1.0 + b.press_v * 3.0
			for g in b.grains:
				g.pos.x += g.v * wind * dt
				g.pos.y += sin(g.pos.x * 0.05) * 10.0 * dt
				if g.pos.x > r.size.x + 6.0:
					g.pos = Vector2(-6.0, randf_range(-14, r.size.y + 14))
		"landslide":
			if randf() < 0.06 + b.press_v * 0.5:
				b.parts.append({ "pos": Vector2(randf_range(4, r.size.x - 4), 2.0),
					"vel": Vector2(0, randf_range(10, 30)), "r": randf_range(1.2, 2.6) })
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += 60.0 * dt
				p.pos.x += sin(p.pos.y * 0.3) * 6.0 * dt
			b.parts = b.parts.filter(func(p): return p.pos.y < r.size.y + 40.0)
		"geode":
			if b.opening:
				b.open = minf(1.0, b.open + dt * 2.4)
				if b.open >= 1.0:
					b.opening = false
			else:
				b.open = maxf(0.0, b.open - dt * 1.2)
		"tectonic":
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel *= pow(0.1, dt)
				p.life -= dt * 0.9
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"quicksand":
			b.sink = minf(r.size.y * 0.75, b.sink + dt * 1.6 - b.press_v * dt * 30.0)
			b.sink = maxf(-6.0, b.sink)
		"boulder":
			if not b.falling:
				b.bx += 40.0 * dt
				b.rot += 3.0 * dt
				if b.bx > r.size.x + 12.0:
					b.bx = -12.0
			else:
				b.vy += 500.0 * dt
				b.by += b.vy * dt
				b.rot += 6.0 * dt
				if b.by > -8.0:            # impact with the button's top edge
					if b.vy > 60.0:
						b.squash = 1.0
						for i in 10:
							b.parts.append({ "pos": Vector2(b.bx + randf_range(-6, 6), 0.0),
								"vel": Vector2(randf_range(-60, 60), randf_range(-40, -5)), "life": 1.0 })
						b.vy = -b.vy * 0.4
					else:
						b.falling = false
						b.by = -22.0
						b.vy = 0.0
					b.by = minf(b.by, -8.0)
			b.squash = maxf(0.0, b.squash - dt * 4.0)
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += 80.0 * dt
				p.life -= dt * 1.8
			b.parts = b.parts.filter(func(p): return p.life > 0.0)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	match b.id:
		"fault_line":
			var sh: float = pv * pv * 5.0
			var rr := Rect2(r.position + Vector2(randf_range(-sh, sh), randf_range(-sh, sh)), r.size)
			ElemKit.face(n, rr, Color(0.14, 0.11, 0.094), Color(0.78, 0.67, 0.51, 0.5))
			var glow: float = 0.45 + 0.3 * sin(t * 1.8) + pv * 0.5
			var crack: Array = b.crack
			for i in range(crack.size() - 1):
				n.draw_line(rr.position + crack[i], rr.position + crack[i + 1],
					Color(1, 0.59, 0.24, minf(1.0, glow)), 1.6 + pv * 2.0)
			ElemKit.label(n, rr, "RICHTER", Color(0.92, 0.87, 0.78))
			for p in b.parts:
				n.draw_rect(Rect2(o + p.pos, Vector2(2.4, 2.4)), Color(0.7, 0.59, 0.43, p.life))
		"crumble":
			if b.mode == "solid":
				ElemKit.face(n, r, Color(0.165, 0.13, 0.094), Color(0.75, 0.63, 0.47, 0.55))
				ElemKit.label(n, r, "CRUMBLE", Color(0.91, 0.86, 0.78))
				if randf() < 0.05:
					n.draw_rect(Rect2(o + Vector2(randf_range(0, r.size.x), r.size.y + randf_range(0, 4)),
						Vector2(1.5, 1.5)), Color(0.67, 0.59, 0.47, 0.5))
			else:
				for s in b.shards:
					n.draw_set_transform(o + s.pos + Vector2(b.sw, b.sh) / 2.0, s.rot, Vector2.ONE)
					n.draw_rect(Rect2(-Vector2(b.sw, b.sh) / 2.0 + Vector2(0.5, 0.5),
						Vector2(b.sw - 1, b.sh - 1)), Color(0.165, 0.13, 0.094))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"sandstorm":
			ElemKit.face(n, r, Color(0.2, 0.157, 0.106), Color(0.86, 0.75, 0.55, 0.5))
			ElemKit.label(n, r, "ERODE", Color(0.94, 0.89, 0.78))
			for i in 10:                     # nicks chewing the lit border
				var ex := o.x + fmod(i * 37.0 + floorf(t * 2.0) * 13.0, r.size.x)
				n.draw_rect(Rect2(ex, o.y - 1 if i % 2 == 0 else o.y + r.size.y - 1, 3.5, 2), Color(0.078, 0.067, 0.12))
			for g in b.grains:
				n.draw_rect(Rect2(o + g.pos, Vector2(1.6, 1.2)), Color(0.88, 0.76, 0.55, 0.25 + pv * 0.4))
		"landslide":
			var lean: float = pv * sin(t * 30.0) * 0.01
			n.draw_set_transform(r.get_center(), lean, Vector2.ONE)
			ElemKit.face(n, Rect2(-r.size / 2.0, r.size), Color(0.17, 0.13, 0.09), Color(0.78, 0.67, 0.51, 0.5))
			ElemKit.label(n, Rect2(-r.size / 2.0, r.size), "SCREE", Color(0.91, 0.86, 0.78))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for p in b.parts:
				n.draw_circle(o + p.pos, p.r, Color(0.75, 0.65, 0.51, 0.85))
		"geode":
			var gap: float = b.open * 14.0
			if b.open > 0.05:                # the amethyst interior, revealed
				ElemKit.face(n, r, Color(0.17, 0.11, 0.27))
				for gl in b.glitter:
					var a: float = maxf(0.0, sin(t * 4.0 + gl.ph)) * b.open
					ElemKit.twinkle(n, o + gl.pos, 3.0, Color(0.86, 0.71, 1.0, a))
			for side in [-1.0, 1.0]:         # the two rock halves slide apart
				var half := Rect2(o + Vector2(side * gap / 2.0, 0), Vector2(r.size.x / 2.0, r.size.y))
				if side > 0:
					half.position.x += r.size.x / 2.0
				n.draw_rect(half, Color(0.18, 0.15, 0.125, 1.0 - b.open * 0.15))
			ElemKit.ring_face(n, r.grow(gap / 2.0), Color(0.71, 0.63, 0.55, 0.5))
			if b.open < 0.4:
				ElemKit.label(n, r, "GEODE", Color(0.9, 0.85, 0.8))
		"tectonic":
			var pw := r.size.x / 3.0
			for p in 3:                      # each plate drifts on its own clock
				var off: float = sin(t * (0.4 + p * 0.2) + p * 2) * 2.0
				off += pv * (0.0 if p == 1 else (3.0 if p == 0 else -3.0))
				var plate := Rect2(o + Vector2(p * pw + off, sin(t * 0.6 + p) * 1.0), Vector2(pw, r.size.y))
				n.draw_rect(plate, Color(0.157, 0.13, 0.1))
				n.draw_rect(plate, Color(0.75, 0.65, 0.49, 0.4), false, 1.0)
			ElemKit.label(n, r, "PANGAEA", Color(0.91, 0.86, 0.78))
			for p in range(1, 3):            # the grinding seams
				var sx := o.x + p * pw
				n.draw_line(Vector2(sx, o.y), Vector2(sx, o.y + r.size.y),
					Color(1, 0.55, 0.24, 0.2 + pv * 0.7), 1.0 + pv * 2.0)
			for p in b.parts:
				var pos: Vector2 = o + p.pos
				var poly := PackedVector2Array([pos + Vector2(-4, 4), pos + Vector2(0, -4), pos + Vector2(4, 4)])
				n.draw_colored_polygon(poly, Color(0.78, 0.69, 0.53, p.life))
		"quicksand":
			ElemKit.face(n, r, Color(0.23, 0.18, 0.11), Color(0.82, 0.71, 0.51, 0.5))
			var lr := Rect2(r.position + Vector2(0, b.sink), r.size)
			var submerged: float = clampf(1.0 - b.sink / (r.size.y * 0.4), 0.15, 1.0)
			ElemKit.label(n, lr, "HELP", Color(0.94, 0.89, 0.78, submerged))
			var poly := PackedVector2Array()   # the sand surface, swallowing
			poly.append(o + Vector2(0, r.size.y))
			poly.append(o + Vector2(0, r.size.y * 0.55))
			var x := 0.0
			while x <= r.size.x:
				poly.append(o + Vector2(x, r.size.y * 0.55 + sin(x * 0.15 + t * 1.2) * 1.5))
				x += 6.0
			poly.append(o + Vector2(r.size.x, r.size.y))
			n.draw_colored_polygon(poly, Color(0.29, 0.23, 0.14))
			if randf() < 0.04:
				ElemKit.ellipse(n, o + Vector2(r.size.x / 2.0 + randf_range(-20, 20), r.size.y * 0.55),
					randf_range(4, 9), 2.0, Color(0.86, 0.76, 0.55, 0.4), 1.0)
		"boulder":
			ElemKit.face(n, r, Color(0.165, 0.137, 0.11), Color(0.75, 0.65, 0.51, 0.55))
			ElemKit.label(n, r, "LOOK UP", Color(0.91, 0.86, 0.78))
			n.draw_set_transform(o + Vector2(b.bx, b.by), b.rot,
				Vector2(1.0 + b.squash * 0.3, 1.0 - b.squash * 0.3))
			n.draw_circle(Vector2.ZERO, 8.0, Color(0.34, 0.29, 0.23))
			n.draw_circle(Vector2(-2.5, -2), 1.6, Color(0.12, 0.094, 0.07, 0.5))
			n.draw_circle(Vector2(3, 1.5), 1.2, Color(0.12, 0.094, 0.07, 0.5))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for p in b.parts:
				n.draw_rect(Rect2(o + p.pos, Vector2(2, 2)), Color(0.71, 0.63, 0.51, p.life * 0.7))
