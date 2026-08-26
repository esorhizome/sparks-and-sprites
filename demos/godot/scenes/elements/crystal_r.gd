extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
const Base := preload("res://scenes/elements/crystal.gd")
## CRYSTAL — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"facet": { "name": "Obsidian sheen", "hint": "near-black — glints rare, white, and sudden" },
	"resonance": { "name": "Deep gong", "hint": "half tempo, twice the swing" },
	"stalactite": { "name": "Stalagmites", "hint": "grown from the FLOOR — one direction flip" },
	"opal": { "name": "Deep opal", "hint": "dropped an octave — darker, slower, richer" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"stalactite":
			# dial: snapped spars launch UP off the floor
			for s in b.spikes:
				if s.len > 4.0:
					b.parts.append({ "kind": "fall", "pos": Vector2(s.x, -s.len), "vy": 0.0, "len": s.len })
				s.len = 2.0
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"resonance":
			# dial: wave travel 8 → 4 (the gong dial)
			if b.ring_wave >= 0.0:
				b.ring_wave += dt * 4.0
				if b.ring_wave > 24.0:
					b.ring_wave = -1.0
		"stalactite":
			# dial: everything measured from the floor; loose spars fly up, glitter falls back
			for s in b.spikes:
				s.len = minf(s.max, s.len + s.rate * dt)
				if s.len > s.max * 0.95 and randf() < 0.008:
					b.parts.append({ "kind": "glit", "pos": Vector2(s.x, -s.len - 2.0), "life": 1.0 })
			for p in b.parts:
				if p.kind == "fall":
					p.vy -= 300.0 * dt
					p.pos.y += p.vy * dt
					if p.pos.y < -r.size.y - 18.0:
						for i in 4:
							b.parts.append({ "kind": "glit",
								"pos": Vector2(p.pos.x + randf_range(-6, 6), -r.size.y - 16.0), "life": 1.0 })
						p.vy = 9999.0
				else:
					p.life -= dt * 2.0
			b.parts = b.parts.filter(func(p): return (p.kind == "fall" and p.vy < 9000.0) or (p.kind == "glit" and p.life > 0.0))
		"opal":
			# dial: shock speed 130 → 60
			if b.shock >= 0.0:
				b.shock += dt * 60.0
				if b.shock > r.size.x * 1.3:
					b.shock = -1.0
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var c := r.get_center()
	match b.id:
		"facet":
			# dials: amethyst → obsidian · idle glints starved, cascade white
			ElemKit.face(n, r, Color(0.055, 0.05, 0.07), Color(0.47, 0.45, 0.55, 0.5))
			for f in b.facets:
				var glint: float = pow(maxf(0.0, sin(t * 0.35 + f.ph * 2.7)), 24.0) * 0.9
				if b.cascade >= 0.0:
					glint += maxf(0.0, 0.9 - absf(f.x - b.cascade) * 5.0)
				var fx: float = o.x + f.x * r.size.x
				var fy: float = o.y + (3.0 if f.top else r.size.y / 2.0)
				var fh := r.size.y / 2.0 - 3.0
				n.draw_colored_polygon(PackedVector2Array([
					Vector2(fx, fy), Vector2(fx + r.size.x / 6.0, fy), Vector2(fx, fy + fh)]),
					Color(0.96, 0.96, 1.0, minf(1.0, 0.03 + glint)))
			ElemKit.label(n, r, "OBSIDIAN", Color(0.75, 0.74, 0.82))
		"resonance":
			# dials: hum 4.0 → 2.0 · swing amplitude ×2 (travel dial in tick)
			ElemKit.face(n, r, Color(0.078, 0.063, 0.094, 0.92), Color(0.75, 0.63, 0.78, 0.5))
			ElemKit.label(n, r, "GONG", Color(0.93, 0.87, 0.94))
			var count := 12
			for i in count:
				var a := i / float(count) * TAU
				var hum := sin(t * 2.0 - i * 0.8) * 0.12
				var excite := 0.0
				if b.ring_wave >= 0.0:
					var d: float = absf(i - fmod(b.ring_wave, count))
					excite = maxf(0.0, 1.0 - minf(d, count - d) * 0.6)
				var scale := 1.0 + hum + excite * 0.9
				var len := 9.0
				var pos := c + Vector2(cos(a) * r.size.x * 0.56, sin(a) * r.size.y * 0.78)
				n.draw_set_transform(pos, a + PI / 2.0, Vector2(1.0, scale))
				n.draw_colored_polygon(PackedVector2Array([
					Vector2(0, -len), Vector2(2.4, 0), Vector2(0, len * 0.4), Vector2(-2.4, 0)]),
					Color(0.86, 0.71, 0.86, 0.5 + excite * 0.5))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"stalactite":
			# dial: hung from the ceiling → grown from the floor (y mirrored)
			ElemKit.face(n, r, Color(0.07, 0.07, 0.133, 0.92), Color(0.75, 0.78, 1.0, 0.5))
			ElemKit.label(n, r, "GROTTO", Color(0.89, 0.91, 1.0))
			var floor_y := r.size.y
			for s in b.spikes:
				n.draw_colored_polygon(PackedVector2Array([
					o + Vector2(s.x - 2.6, floor_y), o + Vector2(s.x + 2.6, floor_y),
					o + Vector2(s.x, floor_y - s.len)]),
					Color(0.78, 0.82, 1.0, 0.75))
			for p in b.parts:
				var mp := Vector2(p.pos.x, floor_y + p.pos.y)   # part-space runs negative-up
				if p.kind == "fall":
					n.draw_colored_polygon(PackedVector2Array([
						o + mp + Vector2(-2, p.len * 0.5), o + mp + Vector2(2, p.len * 0.5), o + mp]),
						Color(0.78, 0.82, 1.0, 0.85))
				else:
					n.draw_rect(Rect2(o + mp, Vector2(2, 2)), Color(0.9, 0.93, 1.0, p.life))
		"opal":
			# dials: hue waves ÷2 speed · value dropped an octave, saturation up
			var x := 0.0
			while x < r.size.x:
				var hue := 0.62 + sin(x * 0.05 + t * 0.4) * 0.17 + sin(x * 0.11 - t * 0.25) * 0.11
				var light := 0.3
				if b.shock >= 0.0:
					var d: float = absf(Vector2(x, r.size.y / 2.0).distance_to(b.sp) - b.shock)
					if d < 16.0:
						hue += (16.0 - d) * 0.022
						light += (16.0 - d) * 0.02
				n.draw_rect(Rect2(o.x + x, o.y, 4.5, r.size.y),
					Color.from_hsv(fmod(hue + 1.0, 1.0), 0.85, minf(1.0, light + 0.25)))
				x += 4.0
			ElemKit.ring_face(n, r, Color(0.71, 0.63, 0.86, 0.6))
			ElemKit.label(n, r, "BLACK OPAL", Color(0.93, 0.9, 1.0, 0.9))
		_:
			Base.draw(n, b, t)
