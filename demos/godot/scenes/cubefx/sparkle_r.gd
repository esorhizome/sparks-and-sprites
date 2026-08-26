extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
const Base := preload("res://scenes/cubefx/sparkle.gd")
## SPARKLES & CHARMS — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"shower": { "name": "Star shower", "hint": "upscaled — fewer, larger, slower stars" },
	"pixie": { "name": "Ember trail", "hint": "glowing warm and sinking instead of floating" },
	"star_twirl": { "name": "Snow twirl", "hint": "the pirouette flings snowflakes — they drift, not fly" },
	"glitter": { "name": "Petal burst", "hint": "softened to petals that flutter as they fall" },
	"hearts": { "name": "Broken hearts", "hint": "falling instead of floating, fading twice as fast" },
	"confetti": { "name": "Leaf pop", "hint": "dressed for autumn — larger leaves, longer drift" },
	"shooting_star": { "name": "Falling feather", "hint": "unhurried — it settles rather than salutes" },
	"crown": { "name": "Thorn crown", "hint": "turned solemn — dark spikes, rare red glints" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"shower":
			# dials: 18 → 7 stars · fall speed ÷2
			for i in 7:
				b.parts.append({ "pos": Vector2(c.x + randf_range(-c.s * 1.6, c.s * 1.6), c.y - c.s * 2.4 - randf_range(0, 20)),
					"vy": randf_range(20, 45), "life": 1.0, "tw": randf_range(2, 5) })
		"star_twirl":
			# dial: fling speed ÷3 — flakes drift
			c.spin = 0.001
			for i in 5:
				var th := randf_range(0, TAU)
				b.flung.append({ "pos": Vector2(c.x, c.y - c.s * 0.5),
					"vel": Vector2(cos(th) * randf_range(20, 45), sin(th) * randf_range(20, 45) - 10.0),
					"rot": randf_range(0, TAU), "life": 1.0 })
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"pixie":
			# dials: shed embers SINK · the stir dial kept
			b.press_v = maxf(0.0, b.press_v - dt * 0.8)
			b.travelled += absf(c.x - b.last_x)
			b.last_x = c.x
			while b.travelled > 7.0:
				b.travelled -= 7.0
				b.parts.append({ "pos": Vector2(c.x + randf_range(-4, 4), c.y - randf_range(2, c.s * 0.8)),
					"a": randf_range(0, TAU), "life": 1.0, "tw": randf_range(4, 9) })
			for p in b.parts:
				if b.press_v > 0.0:
					p.a += 4.0 * dt
					p.pos = p.pos.lerp(Vector2(c.x + cos(p.a) * c.s * 1.3, c.y - c.s * 0.5 + sin(p.a) * c.s * 0.8), dt * 6.0)
				else:
					p.pos.y = minf(b.G, p.pos.y + 12.0 * dt)
				p.life -= dt * 0.7
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"star_twirl":
			# dials: spin ÷2 · gravity 120 → 12, flutter added
			if c.spin != 0.0:
				c.spin += dt * 7.0
				if c.spin > TAU:
					c.spin = 0.0
			for f in b.flung:
				f.pos += f.vel * dt
				f.pos.x += sin(t * 3.0 + f.rot) * 10.0 * dt
				f.vel.y += 12.0 * dt
				f.rot += 2.0 * dt
				f.life -= dt * 0.6
			b.flung = b.flung.filter(func(f): return f.life > 0.0)
		"glitter":
			# dials: drag heavier · fall floaty · flutter added
			for p in b.parts:
				p.pos += p.vel * dt
				p.pos.x += sin(t * p.tw * 0.6 + p.hue * 9.0) * 14.0 * dt
				p.vel.y = minf(p.vel.y + 40.0 * dt, 30.0)
				p.vel.x *= pow(0.2, dt)
				p.life -= dt * 0.6
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"hearts":
			# dials: floaters FALL · fade 0.8 → 1.6
			if randf() < 0.015:
				b.parts.append({ "kind": "float", "pos": Vector2(c.x + randf_range(-6, 6), c.y - c.s * 1.2), "life": 1.0 })
			for p in b.parts:
				p.life -= dt * 1.6
				if p.kind == "ring":
					p.r += 40.0 * dt
				else:
					p.pos.y += 30.0 * dt
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"confetti":
			# dials: terminal fall 40 → 22 · life 0.5 → 0.3 decay (longer drift)
			for p in b.parts:
				p.vel.y = minf(p.vel.y + 90.0 * dt, 22.0)
				p.pos += Vector2(p.vel.x + sin(t * p.flut * 0.7) * 26.0, p.vel.y) * dt
				p.rot += p.vr * 0.6 * dt
				p.vel.x *= pow(0.4, dt)
				p.life -= dt * 0.3
			b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.pos.y < b.G)
		"shooting_star":
			# dials: backdrop streaks ÷2 speed · the dive becomes a settling feather
			var r: Rect2 = b.rect
			b.timer -= dt
			if b.timer <= 0.0:
				b.parts.append({ "pos": r.position + Vector2(randf_range(-10, r.size.x * 0.6), randf_range(4, r.size.y * 0.25)), "life": 1.0 })
				b.timer = randf_range(2.5, 4.0)
			for p in b.parts:
				p.pos += Vector2(80, 28) * dt
				p.life -= dt * 0.6
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
			if b.dive != null:
				var target := Vector2(c.x, c.y - c.s * 1.3)
				b.dive.pos = b.dive.pos.lerp(target, dt * 1.2) + Vector2(sin(t * 4.0) * 20.0, 10.0) * dt
				if b.dive.pos.distance_to(target) < 8.0:
					b.dive = null
					b.flash = 0.5
			b.flash = maxf(0.0, b.flash - dt * 0.7)
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	var pv: float = b.press_v
	match b.id:
		"shower":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				Base._star(n, p.pos, 4.5 * p.life + 1.5, t * 0.8 + p.tw, p.life * 0.9)
		"pixie":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				CubeKit.glow(n, p.pos, 2.5 + p.life * 2.5, Color(1, 0.59, 0.24, p.life * 0.85), 2)
		"star_twirl":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			var a: float = t * 0.8
			CubeKit.twinkle(n, Vector2(c.x + cos(a) * c.s * 1.2, c.y - c.s * 0.5 + sin(a) * c.s * 0.7),
				4.0, Color(0.86, 0.95, 1.0, 0.9))
			for f in b.flung:
				CubeKit.twinkle(n, f.pos, 3.5 * f.life, Color(0.86, 0.95, 1.0, f.life))
				CubeKit.ellipse(n, f.pos, 2.0 * f.life, 2.0 * f.life, Color(0.71, 0.9, 1.0, f.life * 0.5), 1.0, 0, TAU, 8)
		"glitter":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			if randf() < 0.1:
				n.draw_circle(Vector2(c.x + randf_range(-c.s * 0.4, c.s * 0.4), c.y - c.s), 2.0, Color(1, 0.78, 0.86, 0.7))
			for p in b.parts:
				n.draw_set_transform(p.pos, p.hue * TAU + t, Vector2(1.0, 0.55))
				n.draw_circle(Vector2.ZERO, 2.8, Color.from_hsv(0.93 + p.hue * 0.06, 0.4, 1.0, p.life * 0.9))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"hearts":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				var pos: Vector2 = (Vector2(c.x + cos(p.a) * p.r, c.y - c.s * 0.5 + sin(p.a) * p.r * 0.7)
					if p.kind == "ring" else p.pos)
				_half_heart(n, pos, 4.2, p.life)
		"confetti":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			var sx: float = c.x + c.s * 0.4
			var pts := PackedVector2Array()
			for i in 7:
				pts.append(Vector2(sx + sin(t * 1.2 + i) * 4.0, c.y - c.s + i * 4.0))
			n.draw_polyline(pts, Color(0.86, 0.63, 0.31, 0.6), 2.0)
			for p in b.parts:
				n.draw_set_transform(p.pos, p.rot, Vector2(1.0, 0.55))
				n.draw_circle(Vector2.ZERO, 4.2,
					[Color(0.86, 0.55, 0.24), Color(0.9, 0.71, 0.27), Color(0.71, 0.35, 0.2)][int(p.hue * 10.0) % 3]
						* Color(1, 1, 1, p.life))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"shooting_star":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				n.draw_line(p.pos - Vector2(14, 5), p.pos, Color(0.92, 0.9, 0.97, p.life * 0.6), 1.2)
			if b.dive != null:
				var dp: Vector2 = b.dive.pos
				n.draw_set_transform(dp, sin(t * 4.0) * 0.4, Vector2(1.0, 0.4))
				n.draw_circle(Vector2.ZERO, 5.0, Color(0.94, 0.93, 0.98, 0.9))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				n.draw_line(dp, dp + Vector2(-6, 0), Color(0.8, 0.79, 0.88, 0.7), 1.0)
			if b.flash > 0.0:
				CubeKit.glow(n, Vector2(c.x, c.y - c.s * 0.6), c.s * 1.2, Color(0.94, 0.93, 0.98, b.flash * 0.5), 3)
		"crown":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			var cy: float = c.y - c.s * 1.35 + sin(t * 1.8) * 2.0
			for i in 5:
				var a: float = t * 0.4 + i / 5.0 * TAU
				var px := Vector2(c.x + cos(a) * c.s * 0.45, cy + sin(a) * 3.0)
				n.draw_line(px + Vector2(0, 3), px + Vector2(0, -3.0 - pv * 3.0), Color(0.24, 0.2, 0.27, 0.9), 1.8)
				if randf() < 0.01 + pv * 0.1:
					CubeKit.glow(n, px, 3.5, Color(0.9, 0.24, 0.27, 0.9), 2)
		_:
			Base.draw(n, b, t)

static func _half_heart(n: CanvasItem, pos: Vector2, s: float, a: float) -> void:
	# a heart drawn split — the two halves lean apart as it fades
	var gap: float = (1.0 - a) * 3.0
	var col := Color(0.71, 0.47, 0.63, a)
	n.draw_circle(pos + Vector2(-s * 0.5 - gap, 0), s * 0.55, col)
	n.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-s - gap, s * 0.2), pos + Vector2(-gap * 0.5, s * 1.5), pos + Vector2(-gap * 0.5, s * 0.1)]), col)
	n.draw_circle(pos + Vector2(s * 0.5 + gap, 0), s * 0.55, col)
	n.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(s + gap, s * 0.2), pos + Vector2(gap * 0.5, s * 1.5), pos + Vector2(gap * 0.5, s * 0.1)]), col)
