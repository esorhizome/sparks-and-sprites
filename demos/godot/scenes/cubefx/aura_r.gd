extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
const Base := preload("res://scenes/cubefx/aura.gd")
## AURAS & ENERGY — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"powerup": { "name": "Serene aura", "hint": "meditation pace — white, thin, unhurried" },
	"ki": { "name": "Ki vent", "hint": "direction swapped — it LEAKS at rest, gathers on press" },
	"shield": { "name": "Flame shield", "hint": "the bubble burning — panels flicker like pilot lights" },
	"focus": { "name": "Dizzy spiral", "hint": "the lines bend — they curve into a woozy spiral" },
	"battle_glow": { "name": "Fever glow", "hint": "gone sickly — green, fast, never quite calms" },
	"overdrive": { "name": "Limit break", "hint": "burning red — denser flames, the cube darkens" },
	"inner_light": { "name": "Inner void", "hint": "the cracks run DARK — they drink the light" },
	"tension": { "name": "Calm static", "hint": "slowed to weather — soft blue, one at a time" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"ki":
			# dial: press GATHERS instead of bursting
			b.press_v = 1.2
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"powerup":
			# dials: rise 70 → 24 · spawn rate ÷2 · no surge boost
			b.press_v = maxf(0.0, b.press_v - dt * 1.0)
			if randf() < 0.3:
				b.parts.append({ "pos": Vector2(c.x + randf_range(-c.s * 0.7, c.s * 0.7), c.y), "life": 1.0 })
			for p in b.parts:
				p.pos.y -= 24.0 * dt
				p.pos.x += (c.x - p.pos.x) * dt * 0.8
				p.life -= dt * 0.7
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
			c.tint = null
		"ki":
			# dial: wisps run OUTWARD at rest, INWARD while pressed
			b.press_v = maxf(0.0, b.press_v - dt * 0.8)
			if randf() < 0.4:
				if b.press_v > 0.0:
					b.wisps.append({ "a": randf_range(0, TAU), "r": c.s * 2.0, "life": 1.0 })
				else:
					b.wisps.append({ "a": randf_range(0, TAU), "r": c.s * 0.3, "life": 1.0 })
			for w in b.wisps:
				w.r += (-45.0 if b.press_v > 0.0 else 30.0) * dt
				w.a += 2.2 * dt
				w.life -= dt * 0.8
			b.wisps = b.wisps.filter(func(w): return w.life > 0.0 and w.r > 3.0 and w.r < c.s * 2.6)
			for p in b.parts:
				p.pos += p.vel * dt
				p.life -= dt * 1.6
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"overdrive":
			# dials: spawn 0.8 → 1.0 (denser) · the cube DARKENS
			if b.on:
				b.parts.append({ "pos": Vector2(c.x + randf_range(-c.s * 0.6, c.s * 0.6), c.y - randf_range(0, c.s)), "life": 1.0 })
				if randf() < 0.5:
					b.parts.append({ "pos": Vector2(c.x + randf_range(-c.s * 0.6, c.s * 0.6), c.y - randf_range(0, c.s)), "life": 1.0 })
			for p in b.parts:
				p.pos.y -= 90.0 * dt
				p.life -= dt * 1.8
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
			c.tint = Color(0.14, 0.08, 0.1) if b.on else null
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	var pv: float = b.press_v
	match b.id:
		"powerup":
			CubeKit.stage(n, b)
			for p in b.parts:
				CubeKit.glow(n, p.pos, 3.0 + p.life * 3.0, Color(0.94, 0.95, 0.98, p.life * 0.4), 2)
			CubeKit.draw_cube(n, b)
		"ki":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for w in b.wisps:
				CubeKit.glow(n, Vector2(c.x + cos(w.a) * w.r, c.y - c.s * 0.5 + sin(w.a) * w.r * 0.7),
					3.0, Color(0.63, 0.86, 1.0, w.life * 0.7), 2)
			for p in b.parts:
				CubeKit.glow(n, p.pos, 4.0, Color(0.75, 0.92, 1.0, p.life * 0.8), 2)
		"shield":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			# dials: teal facets → pilot-light flames, flicker per panel
			var rr: float = c.s * 1.3
			for i in 12:
				var th := i / 12.0 * TAU
				var flick: float = 0.4 if fmod(t * 3.0 + i * 1.31, 1.0) < 0.7 else 1.0
				var a: float = (0.12 + maxf(0.0, sin(t * 2.0 + i * 1.7)) * 0.3) * flick
				if pv > 0.0:
					var d: float = absf(fposmod(th - b.hit_a + PI * 3.0, TAU) - PI)
					a += maxf(0.0, pv - d * 0.35) * 0.7
				CubeKit.ellipse(n, Vector2(c.x, c.y - c.s * 0.5), rr, rr * 1.05,
					Color(1, 0.63, 0.27, minf(1.0, a)), 2.5, th, th + 0.42, 6)
		"focus":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			if pv > 0.0:
				var r: Rect2 = b.rect
				var ctr := Vector2(c.x, c.y - c.s * 0.5)
				for i in 16:
					var th := i / 16.0 * TAU + pv * 0.5
					var pts := PackedVector2Array()
					for k in 9:                    # the woozy bend: angle drifts with radius
						var q := k / 8.0
						var rad: float = r.size.x - (r.size.x - c.s * (2.0 + pv * 2.0)) * q
						var wa: float = th + q * 1.8 * (1.0 if i % 2 == 0 else -1.0)
						pts.append(ctr + Vector2(cos(wa), sin(wa)) * rad)
					n.draw_polyline(pts, Color(0.9, 0.86, 0.96, pv * 0.45), 1.5)
		"battle_glow":
			CubeKit.stage(n, b)
			# dials: rate ×2 always · red flare → sickly green, never fully calm
			var cyc: float = fmod(t * (2.0 + pv * 1.0), 1.3)
			var beat: float = exp(-pow((cyc - 0.12) * 12.0, 2.0)) + exp(-pow((cyc - 0.36) * 12.0, 2.0)) * 0.6
			CubeKit.glow(n, Vector2(c.x, c.y - c.s * 0.5), c.s * (1.0 + beat * 0.5),
				Color(0.55, 0.9, 0.35, 0.14 + beat * 0.4 + pv * 0.15), 3)
			CubeKit.draw_cube(n, b)
		"overdrive":
			CubeKit.stage(n, b)
			for p in b.parts:
				CubeKit.glow(n, p.pos, 4.0 + p.life * 5.0, Color(1, 0.31, 0.24, p.life * 0.65), 2)
			CubeKit.draw_cube(n, b)
		"inner_light":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			n.draw_set_transform(Vector2(c.x, c.y - c.hop), c.lean, Vector2.ONE)
			for pts in b.cracks:
				var a: float = clampf(0.55 + 0.25 * sin(t * 2.0 + pts[0].x * 9.0) + pv * 0.4, 0.0, 1.0)
				var poly := PackedVector2Array()
				for p in pts:
					poly.append(Vector2(p.x * c.s, clampf(p.y * c.s, -c.s, 0.0)))
				n.draw_polyline(poly, Color(0.03, 0.02, 0.06, a), 1.6 + pv * 1.5)
				n.draw_polyline(poly, Color(0.47, 0.31, 0.71, a * 0.4), 3.0 + pv * 2.0)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"tension":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			# dials: chance ÷4 · one arc at a time · soft blue, slower shape
			if randf() < 0.01 + (0.2 if pv > 0.0 else 0.0):
				var px: float = c.x + randf_range(-c.s, c.s) * 1.2
				var py: float = c.y - c.s * 0.5 + randf_range(-c.s, c.s) * 0.8
				var pts := PackedVector2Array()
				pts.append(Vector2(px, py))
				for k in 3:
					px += randf_range(-8, 8)
					py += randf_range(-6, 6)
					pts.append(Vector2(px, py))
				n.draw_polyline(pts, Color(0.63, 0.78, 1.0, 0.55), 1.2)
		_:
			Base.draw(n, b, t)
