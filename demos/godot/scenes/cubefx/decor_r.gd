extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
const Base := preload("res://scenes/cubefx/decor.gd")
## DECORATIONS — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"butterflies": { "name": "Moths", "hint": "after dark — grey wings, drawn to a lamp overhead" },
	"lanterns": { "name": "Party balloons", "hint": "bright rubber — they bob, and never burn out" },
	"petals": { "name": "First snow", "hint": "the season's first flakes — slower, whiter" },
	"fireflies": { "name": "Embers at dusk", "hint": "blown off a campfire — they rise as they blink" },
	"cape": { "name": "Tattered cape", "hint": "after many battles — darker, slower, gap-toothed" },
	"stage_rain": { "name": "Stage snow", "hint": "frozen — flakes SETTLE on the hero's head" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)
	match b.id:
		"stage_rain":
			b.pile = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"stage_rain":
			# dial: the press shakes the settled snow off
			b.press_v = 1.4
			if b.pile > 0.5:
				for i in 6:
					b.parts.append({ "pos": Vector2(c.x + randf_range(-c.s * 0.4, c.s * 0.4), c.y - c.s - b.pile),
						"vel": Vector2(randf_range(-30, 30), randf_range(-40, -10)), "life": 0.8 })
			b.pile = 0.0
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	match b.id:
		"butterflies":
			# dial: they orbit a LAMP overhead, not the hero — panic still scatters
			b.press_v = maxf(0.0, b.press_v - dt)
			var lamp := Vector2(r.get_center().x, r.position.y + 14.0)
			for f in b.flies:
				f.panic = maxf(0.0, f.panic - dt * 0.5)
				var target := lamp + Vector2(sin(t * 1.4 + f.ph * 3.0) * 18.0, cos(t * 1.8 + f.ph) * 8.0)
				var chase: float = -3.0 if f.panic > 0.0 else 2.0
				f.pos += (target - f.pos) * dt * chase + Vector2(sin(t * 9.0 + f.ph) * 14.0, -f.panic * 40.0) * dt
				f.pos.x = clampf(f.pos.x, r.position.x + 4, r.position.x + r.size.x - 4)
				f.pos.y = clampf(f.pos.y, r.position.y + 8, b.G - 8)
		"lanterns":
			# dial: they bob at a resting height — no burn-out, no expiry
			b.press_v = maxf(0.0, b.press_v - dt)
			for p in b.parts:
				var rest: float = r.position.y + 20.0 + fmod(p.ph, 3.0) * 8.0
				p.pos.y += (rest - p.pos.y) * dt * 0.8 + sin(t * 1.6 + p.ph) * 4.0 * dt
				p.pos.x += sin(t * 0.7 + p.ph) * 8.0 * dt
				p.pos.x = clampf(p.pos.x, r.position.x + 8, r.position.x + r.size.x - 8)
			while b.parts.size() > 9:
				b.parts.pop_front()
		"petals":
			# dials: drift 14 → 4 sideways, fall 22 → 12 — first snow is shy
			b.press_v = maxf(0.0, b.press_v - dt)
			if randf() < 0.12 + (0.4 if b.press_v > 0.0 else 0.0):
				b.parts.append({ "pos": Vector2(randf_range(r.position.x - 10, r.position.x + r.size.x), r.position.y),
					"ph": randf_range(0, 9), "rot": randf_range(0, TAU) })
			for p in b.parts:
				if b.press_v > 0.0:
					var ctr := Vector2(c.x, c.y - c.s)
					var d: Vector2 = p.pos - ctr
					var a: float = d.angle() + dt * 4.0
					p.pos = ctr + Vector2(cos(a), sin(a)) * d.length() * (1.0 - dt * 0.3)
				else:
					p.pos += Vector2(4.0 + sin(t * 2.0 + p.ph) * 6.0, 12.0) * dt
				p.rot += dt * 1.2
			b.parts = b.parts.filter(func(p): return p.pos.y < b.G and p.pos.x < r.position.x + r.size.x + 14.0)
		"fireflies":
			# dial: the gathering point is a campfire on the floor — they RISE off it
			for f in b.flies:
				var fire := Vector2(r.get_center().x, b.G - 4.0)
				f.pos.x += (fire.x + sin(f.wx * 3.0) * c.s * 1.6 - f.pos.x) * dt * 0.4 + sin(t + f.wx) * 10.0 * dt
				f.pos.y += -14.0 * dt + cos(t * 1.3 + f.wx) * 8.0 * dt
				if f.pos.y < r.position.y + 10.0:
					f.pos = fire + Vector2(randf_range(-8, 8), randf_range(-4, 0))
		"stage_rain":
			# dials: fall 230 → 45 · flakes SETTLE on the head instead of splashing
			b.press_v = maxf(0.0, b.press_v - dt)
			if randf() < 0.25 + (0.4 if b.press_v > 0.0 else 0.0):
				b.rain.append({ "pos": Vector2(randf_range(r.position.x, r.position.x + r.size.x), r.position.y) })
			for rd in b.rain:
				rd.pos.y += 45.0 * dt
				rd.pos.x += sin(t * 2.0 + rd.pos.y * 0.1) * 10.0 * dt
				if rd.pos.y >= c.y - c.s and rd.pos.y < c.y and absf(rd.pos.x - c.x) < c.s * 0.5:
					b.pile = minf(6.0, b.pile + 0.4)
					rd.pos.y = 1e9
				elif rd.pos.y >= b.G:
					rd.pos.y = 1e9
			b.rain = b.rain.filter(func(rd): return rd.pos.y < 1e8)
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += 120.0 * dt
				p.life -= dt * 2.0
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	match b.id:
		"butterflies":
			CubeKit.stage(n, b)
			# the lamp they can't resist
			var lamp := Vector2(r.get_center().x, r.position.y + 14.0)
			CubeKit.glow(n, lamp, 10.0, Color(1, 0.9, 0.63, 0.5), 2)
			n.draw_line(lamp + Vector2(0, -14), lamp + Vector2(0, -4), Color(0.47, 0.45, 0.55, 0.7), 1.5)
			CubeKit.draw_cube(n, b)
			for f in b.flies:
				var flap: float = sin(t * 16.0 + f.ph) * 0.8
				for side in [-1.0, 1.0]:
					n.draw_set_transform(f.pos + Vector2(side * 2.4, 0), side * flap, Vector2(1.0, (1.6 + absf(flap)) / 3.0))
					n.draw_circle(Vector2.ZERO, 3.0, Color(0.63, 0.6, 0.57, 0.85))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"lanterns":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			var parts: Array = b.parts
			for i in parts.size():
				var p: Dictionary = parts[i]
				var col: Color = [Color(0.94, 0.31, 0.35), Color(0.31, 0.63, 0.94),
					Color(0.94, 0.78, 0.27), Color(0.47, 0.86, 0.47)][i % 4]
				n.draw_line(p.pos + Vector2(0, 5), p.pos + Vector2(sin(t + p.ph) * 2.0, 14), Color(0.7, 0.7, 0.75, 0.6), 1.0)
				n.draw_set_transform(p.pos, 0.0, Vector2(1.0, 1.2))
				n.draw_circle(Vector2.ZERO, 4.5, col)
				n.draw_circle(Vector2(-1.4, -1.6), 1.2, Color(1, 1, 1, 0.6))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"petals":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				n.draw_circle(p.pos, 1.8, Color(0.96, 0.97, 1.0, 0.9))
		"fireflies":
			CubeKit.stage(n, b)
			# the campfire they blew off of
			var fire := Vector2(r.get_center().x, b.G - 3.0)
			CubeKit.glow(n, fire, 7.0 + sin(t * 6.0) * 1.5, Color(1, 0.59, 0.24, 0.6), 2)
			CubeKit.draw_cube(n, b)
			for f in b.flies:
				var blink: float = pow(maxf(0.0, sin(t * f.sp * 2.0 + f.ph)), 3.0)
				blink = maxf(blink, b.press_v)
				if blink > 0.05:
					CubeKit.glow(n, f.pos, 3.5, Color(1, 0.63, 0.27, blink * 0.85), 2)
		"cape":
			CubeKit.stage(n, b)
			# dial: full sweep → gap-toothed strips in mourning maroon
			var pts: Array = b.pts
			for i in range(1, pts.size()):
				if i % 3 == 0:
					continue          # the battle-torn gaps
				var a: Vector2 = pts[i - 1]
				var bpt: Vector2 = pts[i]
				n.draw_colored_polygon(PackedVector2Array([
					a, bpt, bpt + Vector2(0, 5.0 + i * 1.1), a + Vector2(0, 5.0 + (i - 1) * 1.1)]),
					Color(0.31, 0.1, 0.14, 0.9))
			CubeKit.draw_cube(n, b)
		"stage_rain":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			if b.pile > 0.2:            # the little snow hat
				n.draw_set_transform(Vector2(c.x, c.y - c.s - c.hop + 1.0), c.lean, Vector2(1.0, 0.5))
				n.draw_circle(Vector2.ZERO, c.s * 0.4 + b.pile * 0.4, Color(0.94, 0.96, 1.0, 0.95))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for rd in b.rain:
				n.draw_circle(rd.pos, 1.5, Color(0.94, 0.96, 1.0, 0.85))
			for p in b.parts:
				n.draw_rect(Rect2(p.pos, Vector2(1.6, 1.6)), Color(0.94, 0.96, 1.0, p.life))
		_:
			Base.draw(n, b, t)
