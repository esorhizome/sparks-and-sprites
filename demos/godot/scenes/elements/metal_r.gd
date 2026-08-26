extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
const Base := preload("res://scenes/elements/metal.gd")
## MERCURY & METAL — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"mercury": { "name": "Molten beads", "hint": "silver→gold, wander ×2" },
	"quicksilver": { "name": "Comet trail", "hint": "ice-blue, orbit ×2, tails rise" },
	"chrome_sweep": { "name": "Bronze sweep", "hint": "warmed, sweep ÷2, cadence 5s" },
	"molten_drip": { "name": "Mercury drip", "hint": "silver, smaller, ×2 hurry" },
	"forge": { "name": "Cryo forge", "hint": "heat cycle runs COLD, sparks → shards" },
	"rivet": { "name": "Star studs", "hint": "glints random instead of in sequence" },
	"liquid_chrome": { "name": "Liquid gold", "hint": "warmed, spring ÷2" },
	"magnetite": { "name": "Compass grass", "hint": "green blades, pole ÷3, press = wind" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)
	match b.id:
		"quicksilver":
			pass                            # speed dial in tick
		"rivet":
			b.glints = [0.0, 0.0, 0.0, 0.0]

static func press(b: Dictionary, pos: Vector2) -> void:
	Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"quicksilver":
			# dials: orbit 1.8 → 3.4 · droplets rise instead of sink
			b.press_v = maxf(0.0, b.press_v - dt * 1.8)
			b.speed += (1.0 - b.speed) * dt * 0.9
			b.a += b.speed * 3.4 * dt
			var r: Rect2 = b.rect
			if randf() < 0.5:
				b.parts.append({ "pos": r.size / 2.0 + Vector2(cos(b.a) * r.size.x * 0.55, sin(b.a) * r.size.y * 0.9),
					"r": randf_range(1.5, 3.2), "life": 1.0 })
			for p in b.parts:
				p.life -= dt * 0.8
				p.pos.y -= 6.0 * dt
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"forge":
			# dial: shard shapes fall slower than sparks
			b.press_v = maxf(0.0, b.press_v - dt * 1.8)
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += 160.0 * dt
				p.life -= dt * 1.2
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"rivet":
			b.press_v = maxf(0.0, b.press_v - dt * 1.6)
			for i in 4:
				if randf() < 0.01:
					b.glints[i] = 1.0
				b.glints[i] = maxf(b.glints[i] - dt * 0.8, b.press_v)
		"magnetite":
			b.press_v = maxf(0.0, b.press_v - dt * 0.9)
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	match b.id:
		"mercury":
			# dials: silver→gold (beads redrawn warm; Base handles motion via delegate tick)
			ElemKit.face(n, r, Color(0.118, 0.086, 0.047, 0.95), Color(0.9, 0.75, 0.47, 0.5))
			ElemKit.label(n, r, "AU", Color(1, 0.92, 0.75, 0.9))
			var beads: Array = b.beads
			for i in beads.size():
				for j in range(i + 1, beads.size()):
					var a: Dictionary = beads[i]
					var c: Dictionary = beads[j]
					if a.pos.distance_to(c.pos) < (a.r + c.r) * 1.7:
						n.draw_line(o + a.pos, o + c.pos, Color(0.94, 0.78, 0.47, 0.85), minf(a.r, c.r) * 1.1)
			for bd in beads:
				n.draw_circle(o + bd.pos, bd.r, Color(0.91, 0.72, 0.38))
				n.draw_circle(o + bd.pos - Vector2(bd.r * 0.3, bd.r * 0.35), bd.r * 0.35, Color(1, 0.96, 0.85))
		"quicksilver":
			ElemKit.face(n, r, Color(0.055, 0.078, 0.118, 0.96), Color(0.59, 0.78, 0.94, 0.5))
			ElemKit.label(n, r, "PERIAPSIS", Color(0.84, 0.92, 1.0, 0.9))
			for p in b.parts:
				var rr: float = maxf(0.4, p.r * p.life)
				n.draw_circle(o + p.pos, rr, Color(0.72, 0.85, 0.97, p.life * 0.85))
			var hp := o + r.size / 2.0 + Vector2(cos(b.a) * r.size.x * 0.55, sin(b.a) * r.size.y * 0.9)
			n.draw_circle(hp, 6.0, Color(0.35, 0.5, 0.72))
			n.draw_circle(hp - Vector2(2, 2), 2.4, Color(1, 1, 1))
		"chrome_sweep":
			for i in 8:
				var k := i / 8.0
				var v := 0.14 + 0.13 * absf(sin(k * PI))
				n.draw_rect(Rect2(o.x, o.y + k * r.size.y, r.size.x, r.size.y / 8.0 + 1),
					Color(v + 0.09, v + 0.045, v * 0.6))
			for s in b.sweeps:
				var sx: float = o.x + r.size.x * s.p
				n.draw_line(Vector2(sx, o.y), Vector2(sx + 14, o.y + r.size.y), Color(1, 0.88, 0.63, 0.45), 8.0)
			ElemKit.ring_face(n, r, Color(0.92, 0.76, 0.55, 0.6))
			ElemKit.label(n, r, "BRONZE", Color(0.96, 0.88, 0.75))
		"molten_drip":
			# dials: gold→silver, faster swell (drawn from the same hang state)
			ElemKit.face(n, r, Color(0.094, 0.1, 0.125, 0.96), Color(0.78, 0.82, 0.88, 0.6))
			ElemKit.label(n, r, "QUICK", Color(0.91, 0.93, 0.96))
			for hd in b.hangs:
				var y := o.y + r.size.y
				n.draw_set_transform(Vector2(o.x + hd.x, y + hd.s), 0.0, Vector2(1.0, 1.0 + hd.s * 0.4))
				n.draw_circle(Vector2.ZERO, 1.4 + hd.s * 0.4, Color(0.94, 0.96, 0.99, 0.95))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for p in b.parts:
				n.draw_set_transform(o + p.pos, 0.0, Vector2(1.0, 1.7))
				n.draw_circle(Vector2.ZERO, 1.5, Color(0.88, 0.91, 0.95, p.life))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"forge":
			# dials: warm cycle → cold cycle
			var heat := 0.5 + 0.5 * sin(t * 0.7)
			ElemKit.face(n, r, Color(
				minf(1.0, 0.063 + heat * 0.16 + pv * 0.78),
				minf(1.0, 0.078 + heat * 0.47 + pv * 0.43),
				minf(1.0, 0.157 + heat * 0.75 + pv * 0.1)), Color(0.67, 0.82, 1.0, 0.5))
			ElemKit.label(n, r, "QUENCH", Color(0.04, 0.078, 0.157) if heat > 0.5 or pv > 0.0 else Color(0.78, 0.87, 1.0))
			for p in b.parts:
				n.draw_rect(Rect2(o + p.pos - Vector2(1, 2), Vector2(2, 4)), Color(0.78, 0.9, 1.0, p.life))
		"rivet":
			for i in 4:
				n.draw_rect(Rect2(o.x, o.y + i * r.size.y / 4.0, r.size.x, r.size.y / 4.0 + 1),
					Color(0.18 + i * 0.012, 0.2 + i * 0.012, 0.26 + i * 0.012))
			ElemKit.ring_face(n, r, Color(0.63, 0.68, 0.8, 0.6))
			ElemKit.label(n, r, "CONSTELLATED", Color(0.87, 0.9, 0.96))
			var rivets := [o + Vector2(10, 9), o + Vector2(r.size.x - 10, 9),
				o + Vector2(r.size.x - 10, r.size.y - 9), o + Vector2(10, r.size.y - 9)]
			for i in 4:
				n.draw_circle(rivets[i], 3.4, Color(0.28, 0.31, 0.37))
				var g: float = b.glints[i]
				if g > 0.02:
					var L := 6.0 + g * 6.0
					n.draw_line(rivets[i] - Vector2(L, 0), rivets[i] + Vector2(L, 0), Color(0.86, 0.92, 1.0, g * 0.9), 1.2)
					n.draw_line(rivets[i] - Vector2(0, L), rivets[i] + Vector2(0, L), Color(0.86, 0.92, 1.0, g * 0.9), 1.2)
		"liquid_chrome":
			var y := 0.0
			while y < r.size.y:
				var k := y / r.size.y
				var shift: float = sin(k * 6.0 + t * 1.5) * (3.0 + b.wob * 4.0) + sin(k * 13.0 - t * 2.3) * 1.5
				var bright := 0.5 + 0.5 * sin(k * 9.0 + shift * 0.35 + t * 0.7)
				var v := 0.2 + bright * 0.66
				n.draw_rect(Rect2(o.x + shift, o.y + y, r.size.x, 3.2),
					Color(minf(1.0, v + 0.16), v, v * 0.45))
				y += 3.0
			ElemKit.ring_face(n, r, Color(1, 0.9, 0.67, 0.7))
			ElemKit.label(n, r, "GILD", Color(0.157, 0.11, 0.04, 0.85))
		"magnetite":
			# dials: iron→grass, pole rotation ÷3, press = gust jitter
			ElemKit.face(n, r, Color(0.055, 0.078, 0.055, 0.95), Color(0.59, 0.78, 0.55, 0.5))
			var fa: float = t * 0.15
			var pp := r.size / 2.0 + Vector2(cos(fa) * r.size.x * 0.4, sin(fa) * r.size.y * 0.35)
			var qq := r.size / 2.0 - Vector2(cos(fa) * r.size.x * 0.4, sin(fa) * r.size.y * 0.35)
			for f in b.filings:
				var local: Vector2 = f - o
				var a1: float = (local - pp).angle()
				var a2: float = (qq - local).angle()
				var a := atan2(sin(a1) + sin(a2), cos(a1) + cos(a2)) + pv * sin(t * 8.0 + f.x * 0.2) * 0.4
				var L := 2.6 + pv
				n.draw_line(f - Vector2(cos(a), sin(a)) * L, f + Vector2(cos(a), sin(a)) * L,
					Color(0.63, 0.84, 0.59, 0.5 + pv * 0.3), 1.0)
			ElemKit.label(n, r, "MEADOW", Color(0.87, 0.94, 0.85))
		_:
			Base.draw(n, b, t)
