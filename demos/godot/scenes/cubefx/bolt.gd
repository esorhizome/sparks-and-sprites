extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
## LIGHTNING — eight cube effects, ported from the web codex.

const TITLE := "Lightning"
const BLURB := "bolts called down, charges released, dashes at storm speed"
const DEFS := [
	{ "id": "sky_bolt", "name": "Sky bolt", "hint": "a cloud broods; press to call the bolt down where you click" },
	{ "id": "chain_zap", "name": "Chain zap", "hint": "small arcs crawl on it; press and the charge hops forward" },
	{ "id": "static_aura", "name": "Static aura", "hint": "it crackles as it walks; press for the discharge nova" },
	{ "id": "thunder_clap", "name": "Thunder clap", "hint": "press: hands together — flash, ring, and shock lines" },
	{ "id": "charge_release", "name": "Charge & release", "hint": "energy spirals IN while it waits; press to let it all out" },
	{ "id": "volt_dash", "name": "Volt dash", "hint": "press: it blinks forward, leaving the zigzag it travelled" },
	{ "id": "orbit_sparks", "name": "Orbiting sparks", "hint": "three spark orbs circle it; press and they fire off" },
	{ "id": "storm_call", "name": "Storm call", "hint": "press: three bolts, a gust of rain, one drenched hero" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	match b.id:
		"sky_bolt":
			b.flash = 0.0
		"chain_zap":
			b.chain = -1.0
		"charge_release":
			b.charge = 0.0
			b.bolt = 0.0
			b.orbs = []
		"volt_dash":
			b.trail = null
		"orbit_sparks":
			b.orbs = []
			for i in 3:
				b.orbs.append({ "ph": i / 3.0 * TAU, "fired": -1.0, "x": 0.0, "y": 0.0 })
		"storm_call":
			b.rain = []

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	match b.id:
		"sky_bolt":
			b.parts.append({ "kind": "bolt", "x": clampf(pos.x, r.position.x + 6, r.position.x + r.size.x - 6), "life": 1.0 })
			b.flash = 1.0
		"chain_zap":
			b.chain = 0.0
		"static_aura", "thunder_clap":
			b.press_v = 1.0
		"charge_release":
			b.bolt = maxf(0.4, b.charge)
			b.charge = 0.0
		"volt_dash":
			var from: float = c.x
			var to: float = clampf(c.x + c.face * c.s * 3.2, r.position.x + c.s, r.position.x + r.size.x - c.s)
			c.x = to
			b.trail = { "from": from, "to": to, "y": c.y - c.s * 0.5, "life": 1.0 }
		"orbit_sparks":
			for o in b.orbs:
				if o.fired < 0.0:
					o.fired = 0.0
		"storm_call":
			b.press_v = 1.6
			for i in 3:
				b.parts.append({ "kind": "bolt", "x": c.x + randf_range(-c.s * 2.4, c.s * 2.4),
					"delay": i * 0.25, "life": 1.2 })

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	b.press_v = maxf(0.0, b.press_v - dt * 1.6)
	match b.id:
		"sky_bolt":
			b.flash = maxf(0.0, b.flash - dt * 3.0)
			for p in b.parts:
				p.life -= dt * 3.0
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"chain_zap":
			if b.chain >= 0.0:
				b.chain += dt * 3.0
				if b.chain > 3.5:
					b.chain = -1.0
		"charge_release":
			b.charge = minf(1.0, b.charge + dt * 0.12)
			if randf() < 0.3 + b.charge * 0.5:
				b.orbs.append({ "a": randf_range(0, TAU), "r": c.s * 2.2, "life": 1.0 })
			for o in b.orbs:
				o.r -= 60.0 * dt
				o.a += 3.0 * dt
				o.life -= dt * 0.9
			b.orbs = b.orbs.filter(func(o): return o.life > 0.0 and o.r > 4.0)
			b.bolt = maxf(0.0, b.bolt - dt * 2.5)
		"volt_dash":
			if b.trail != null:
				b.trail.life -= dt * 2.2
				if b.trail.life <= 0.0:
					b.trail = null
		"orbit_sparks":
			var r: Rect2 = b.rect
			for o in b.orbs:
				if o.fired < 0.0:
					var a: float = t * 2.0 + o.ph
					o.x = c.x + cos(a) * c.s * 1.1
					o.y = c.y - c.s * 0.5 + sin(a) * c.s * 0.6
				else:
					o.fired += dt
					o.x += c.face * 240.0 * dt
					if o.fired > 1.2 or o.x < r.position.x - 10 or o.x > r.position.x + r.size.x + 10:
						o.fired = -1.0
		"storm_call":
			if randf() < 0.05 + (0.8 if b.press_v > 0.0 else 0.0):
				var r: Rect2 = b.rect
				b.rain.append({ "pos": Vector2(randf_range(r.position.x, r.position.x + r.size.x), r.position.y) })
			for rd in b.rain:
				rd.pos += Vector2(-40, 240) * dt
			b.rain = b.rain.filter(func(rd): return rd.pos.y < b.G)
			for p in b.parts:
				p.delay -= dt
				if p.delay <= 0.0:
					p.life -= dt * 3.0
			b.parts = b.parts.filter(func(p): return p.life > 0.0)

static func _jag_down(n: CanvasItem, x: float, y0: float, y1: float, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	var px := x
	var py := y0
	pts.append(Vector2(px, py))
	while py < y1:
		px += randf_range(-8, 8)
		py += randf_range(10, 20)
		pts.append(Vector2(px, py))
	n.draw_polyline(pts, col, width)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	var pv: float = b.press_v
	CubeKit.stage(n, b)
	match b.id:
		"sky_bolt":
			if b.flash > 0.6:
				n.draw_rect(r, Color(0.78, 0.82, 0.94, b.flash - 0.6))
			for i in 4:
				n.draw_circle(Vector2(r.position.x + r.size.x * (0.2 + i * 0.2), r.position.y + 10.0 + sin(t + i) * 2.0),
					9.0, Color(0.27, 0.28, 0.37, 0.9))
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				_jag_down(n, p.x, r.position.y + 14.0, b.G, Color(0.86, 0.9, 1.0, p.life), 2.5)
				CubeKit.glow(n, Vector2(p.x, b.G), 14.0, Color(0.78, 0.86, 1.0, p.life * 0.7), 2)
		"chain_zap":
			CubeKit.draw_cube(n, b)
			if randf() < 0.3:
				var p0 := Vector2(c.x + randf_range(-c.s, c.s) * 0.5, c.y - randf_range(0, c.s))
				n.draw_line(p0, p0 + Vector2(randf_range(-8, 8), randf_range(-8, 8)), Color(0.7, 0.82, 1.0, 0.7), 1.2)
			if b.chain >= 0.0:
				var hops: int = mini(3, int(b.chain) + 1)
				var px := Vector2(c.x, c.y - c.s * 0.5)
				for i in hops:
					var nx := Vector2(c.x + c.face * c.s * (1.4 + i * 1.3), b.G - 8.0 - (i % 2) * 14.0)
					var a: float = 1.0 - b.chain * 0.25
					var pts := PackedVector2Array()
					pts.append(px)
					for k in range(1, 5):
						pts.append(px.lerp(nx, k / 4.0) + Vector2(randf_range(-4, 4), randf_range(-4, 4)))
					n.draw_polyline(pts, Color(0.7, 0.82, 1.0, maxf(0.0, a)), 1.6)
					CubeKit.glow(n, nx, 7.0, Color(0.78, 0.86, 1.0, maxf(0.0, a)), 2)
					px = nx
		"static_aura":
			CubeKit.draw_cube(n, b)
			for i in 3:
				if randf() < 0.4:
					var th := randf_range(0, TAU)
					var p0 := Vector2(c.x + cos(th) * c.s * 0.55, c.y - c.s * 0.5 + sin(th) * c.s * 0.55)
					n.draw_line(p0, p0 + Vector2(randf_range(-6, 6), randf_range(-6, 6)), Color(0.75, 0.84, 1.0, 0.8), 1.0)
			if pv > 0.0:
				var rr: float = (1.0 - pv) * c.s * 3.2 + 8.0
				var pts := PackedVector2Array()
				for i in 15:
					var th := i / 14.0 * TAU
					var jr: float = rr + randf_range(-2, 2)
					pts.append(Vector2(c.x + cos(th) * jr, c.y - c.s * 0.5 + sin(th) * jr * 0.7))
				n.draw_polyline(pts, Color(0.78, 0.86, 1.0, pv), 2.5)
		"thunder_clap":
			CubeKit.draw_cube(n, b)
			if pv > 0.0:
				var k := 1.0 - pv
				CubeKit.glow(n, Vector2(c.x, c.y - c.s * 0.6), 10.0 + k * 20.0, Color(0.9, 0.94, 1.0, pv), 3)
				CubeKit.ellipse(n, Vector2(c.x, c.y - c.s * 0.6), 8.0 + k * c.s * 2.4, (8.0 + k * c.s * 2.4) * 0.6,
					Color(0.82, 0.88, 1.0, pv * 0.9), 2.0)
				for i in 8:
					var th := i / 8.0 * TAU + 0.4
					var r0: float = 10.0 + k * c.s * 2.0
					n.draw_line(Vector2(c.x + cos(th) * r0, c.y - c.s * 0.6 + sin(th) * r0 * 0.6),
						Vector2(c.x + cos(th) * (r0 + 10.0), c.y - c.s * 0.6 + sin(th) * (r0 + 10.0) * 0.6),
						Color(0.82, 0.88, 1.0, pv * 0.9), 2.0)
		"charge_release":
			CubeKit.draw_cube(n, b)
			for o in b.orbs:
				CubeKit.glow(n, Vector2(c.x + cos(o.a) * o.r, c.y - c.s * 0.5 + sin(o.a) * o.r * 0.7),
					3.0, Color(0.75, 0.84, 1.0, o.life * 0.8), 2)
			CubeKit.glow(n, Vector2(c.x, c.y - c.s * 0.5), 6.0 + b.charge * 14.0,
				Color(0.78, 0.88, 1.0, 0.25 + b.charge * 0.5), 3)
			if b.bolt > 0.0:
				var pts := PackedVector2Array()
				var px := Vector2(c.x + c.face * c.s * 0.5, c.y - c.s * 0.5)
				pts.append(px)
				while px.x > r.position.x and px.x < r.position.x + r.size.x:
					px += Vector2(c.face * randf_range(14, 26), randf_range(-8, 8))
					pts.append(px)
				n.draw_polyline(pts, Color(0.88, 0.92, 1.0, minf(1.0, b.bolt * 2.0)), 2.0 + b.bolt * 4.0)
		"volt_dash":
			CubeKit.draw_cube(n, b)
			if randf() < 0.15:
				CubeKit.glow(n, Vector2(c.x + randf_range(-c.s, c.s) * 0.6, c.y - randf_range(0, c.s)),
					3.0, Color(0.75, 0.84, 1.0, 0.7), 2)
			if b.trail != null and b.trail.life > 0.0:
				var pts := PackedVector2Array()
				pts.append(Vector2(b.trail.from, b.trail.y))
				var count := 6
				for i in range(1, count + 1):
					pts.append(Vector2(b.trail.from + (b.trail.to - b.trail.from) * i / count,
						b.trail.y + (-8.0 if i % 2 == 1 else 8.0) + randf_range(-2, 2)))
				n.draw_polyline(pts, Color(0.78, 0.88, 1.0, b.trail.life), 2.5)
		"orbit_sparks":
			CubeKit.draw_cube(n, b)
			for o in b.orbs:
				if o.fired < 0.0:
					CubeKit.glow(n, Vector2(o.x, o.y), 5.0, Color(0.78, 0.86, 1.0, 0.9), 2)
				else:
					n.draw_line(Vector2(o.x - c.face * 16.0, o.y + randf_range(-3, 3)), Vector2(o.x, o.y),
						Color(0.78, 0.88, 1.0, maxf(0.0, 1.0 - o.fired)), 2.0)
		"storm_call":
			CubeKit.draw_cube(n, b)
			for rd in b.rain:
				n.draw_line(rd.pos, rd.pos + Vector2(1.5, -7), Color(0.59, 0.7, 0.86, 0.5), 1.0)
			for p in b.parts:
				if p.delay <= 0.0 and p.life > 0.0:
					_jag_down(n, p.x, r.position.y, b.G, Color(0.86, 0.9, 1.0, minf(1.0, p.life)), 2.0)
