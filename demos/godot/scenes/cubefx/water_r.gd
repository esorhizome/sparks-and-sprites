extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
const Base := preload("res://scenes/cubefx/water.gd")
## WATER ATTACKS — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"waterhose": { "name": "Steam hose", "hint": "buoyancy instead of weight — it curls UP and fades" },
	"bubble_shield": { "name": "Soap shield", "hint": "a rainbow rim — it pops lazily, in stages" },
	"splash_stomp": { "name": "Dust stomp", "hint": "the same ballistic hop and squash — a dry landing: dust, not water" },
	"rain_pet": { "name": "Snow cloud pet", "hint": "wintering, heavier with snow (k 30 → 18) — a lazier overshoot; flakes dodge" },
	"water_whip": { "name": "Vine whip", "hint": "grown green — a slower, heavier arm (k 250 → 120, hold ×2), leaf at the tip" },
	"geyser": { "name": "Mud pot", "hint": "lazy and brown — half height, twice the plop" },
	"mist_veil": { "name": "Shadow veil", "hint": "dressed in darkness — wisps go black and tighten" },
	"tidal_push": { "name": "Slow surge", "hint": "half speed, half again the height" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)
	match b.id:
		"rain_pet":
			# dials: tether k 30 → 18 and damp 0.3 → 0.25 (a heavier cloud: period ≈ 1.5 s) · sag 40 → 30
			b.D.merge({ "k": 18.0, "damp": 0.25, "sag": 30.0 }, true)
		"water_whip":
			# dials: k 250 → 120 and hold 0.22 → 0.44 (a slower arm, half speed) · tipdamp 0.45 → 0.5 (woodier)
			b.D.merge({ "k": 120.0, "hold": 0.44, "tipdamp": 0.5 }, true)

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"bubble_shield":
			# dial: the pop staged — drops leave in two waves, slower
			if b.up >= 1.0:
				b.up = 0.0
				b.reform = 2.2
				for i in 16:
					var th := randf_range(0, TAU)
					b.parts.append({ "pos": Vector2(c.x + cos(th) * c.s, c.y - c.s * 0.5 + sin(th) * c.s),
						"vel": Vector2(cos(th), sin(th)) * randf_range(15, 45), "life": 1.0 + (i % 2) * 0.5, "kind": "drop" })
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"waterhose":
			# dials: gravity +300 → buoyancy −80 · plumes fade instead of splashing
			b.press_v = maxf(0.0, b.press_v - dt * 1.0)
			var hx := Vector2(c.x + c.face * c.s * 0.6, c.y - c.s * 0.5)
			if randf() < 0.06:
				b.parts.append({ "pos": hx, "vel": Vector2(c.face * 10.0, -6.0), "life": 1.0, "kind": "drop" })
			if b.press_v > 0.0:
				for i in 3:
					b.parts.append({ "pos": hx, "vel": Vector2(c.face * randf_range(90, 130), randf_range(-50, -20)),
						"life": 1.2, "kind": "drop" })
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y -= 80.0 * dt
				p.vel.x *= pow(0.4, dt)
				p.life -= dt * 0.9
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"bubble_shield":
			# dial: gravity 150 → 30 — soap drifts
			b.reform = maxf(0.0, b.reform - dt)
			if b.reform <= 0.0:
				b.up = minf(1.0, b.up + dt * 1.5)
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += 30.0 * dt
				p.life -= dt * 0.9
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"rain_pet":
			# dials: fall 170 → 40 · flakes dodge sideways · the tether spring is the Base's, on the merged dials
			b.press_v = maxf(0.0, b.press_v - dt * 1.0)
			var D: Dictionary = b.D
			var r: Rect2 = b.rect
			var kk: float = D.k
			var dd: float = float(D.damp) * 2.0 * sqrt(kk)
			var sk: float = D.sagK
			var sd: float = 0.5 * 2.0 * sqrt(sk)
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			for _s in sub:
				b.cv += (kk * (c.x - b.cx) - dd * b.cv) * h
				b.cx += b.cv * h
				b.dyv += (sk * (0.0 - b.dy) - sd * b.dyv) * h
				b.dy = clampf(b.dy + b.dyv * h, -20.0, 20.0)
			b.cx = clampf(b.cx, r.position.x - 40.0, r.position.x + r.size.x + 40.0)
			if randf() < 0.25 + b.press_v:
				b.parts.append({ "kind": "rain", "pos": Vector2(b.cx + randf_range(-14, 14), c.y - c.s * 2.0 + b.dy) })
			for p in b.parts:
				p.pos.y += 40.0 * dt
				p.pos.x += sin(t * 2.0 + p.pos.y * 0.15) * 18.0 * dt
				if p.pos.y >= c.y - c.s and p.pos.y < c.y and absf(p.pos.x - c.x) < c.s * 0.5:
					p.pos.x += (18.0 if p.pos.x > c.x else -18.0) * dt * 8.0   # the dodge
				if p.pos.y >= b.G:
					p.pos.y = 1e9
			b.parts = b.parts.filter(func(p): return p.pos.y < 1e8)
		"geyser":
			# dial: eruption lingers (decay 0.7 → 0.35) — the plop pays double
			var r: Rect2 = b.rect
			b.gx = r.get_center().x + sin(t * 0.3 + 2.0) * r.size.x * 0.3
			for p in b.parts:
				p.life -= dt * 0.35
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"tidal_push":
			# dial: wave speed 150 → 75, it lives longer
			for p in b.parts:
				if p.kind == "wave":
					p.x += p.dir * 75.0 * dt
					p.life -= dt * 0.35
				else:
					p.pos += p.vel * dt
					p.vel.y += 160.0 * dt
					p.life -= dt * 1.6
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"waterhose":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				var v: float = 0.75 + p.life * 0.1
				n.draw_circle(p.pos, 2.5 + (1.0 - p.life) * 6.0, Color(v, v, minf(1.0, v + 0.05), p.life * 0.35))
		"bubble_shield":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			if b.up > 0.05:
				var rr: float = c.s * 1.25 * b.up
				for k in 3:              # the rainbow rim: three offset hue rings
					CubeKit.ellipse(n, Vector2(c.x, c.y - c.s * 0.5), rr - k * 1.2, (rr - k * 1.2) * 1.05,
						Color.from_hsv(fmod(t * 0.1 + k * 0.33, 1.0), 0.6, 1.0, 0.4 * b.up), 1.2)
				var ha: float = t * 0.8
				CubeKit.ellipse(n, Vector2(c.x, c.y - c.s * 0.5), rr * 0.85, rr * 0.9,
					Color(1, 1, 1, 0.5 * b.up), 1.5, ha, ha + 0.7, 8)
			for p in b.parts:
				CubeKit.ellipse(n, p.pos, 2.0, 2.0, Color(0.85, 0.92, 1.0, minf(1.0, p.life) * 0.8), 1.0, 0, TAU, 8)
		"splash_stomp":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				if p.get("kind", "") == "ring":
					CubeKit.ellipse(n, Vector2(c.x, b.G + 2.0), p.r, p.r * 0.25, Color(0.78, 0.69, 0.55, p.life * 0.7), 1.6)
				else:
					n.draw_circle(p.pos, 1.8, Color(0.75, 0.65, 0.51, p.life * 0.8))
		"rain_pet":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			var cy: float = c.y - c.s * 2.1 + b.dy
			for i in 5:
				n.draw_circle(Vector2(b.cx + (i - 2) * 8.0, cy + sin(i * 2.3) * 2.5), 7.0 + (i % 2) * 2.0,
					Color(0.63, 0.65, 0.75, 0.9))
			for p in b.parts:
				n.draw_circle(p.pos, 1.5, Color(0.94, 0.96, 1.0, 0.85))
		"water_whip":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			# dial: palette water → vine · a leaf lying along the last segment
			var chain: PackedVector2Array = b.chain
			var th: PackedFloat32Array = b.th
			var N: int = b.N
			var busy: bool = b.swing >= 0.0
			n.draw_polyline(chain, Color(0.47, 0.78, 0.39, 0.9 if busy else 0.6), 3.5 if busy else 3.0)
			n.draw_set_transform(chain[N], PI / 2.0 - th[N - 1], Vector2(1.0, 0.5))   # the tip leaf
			n.draw_circle(Vector2.ZERO, 4.0, Color(0.55, 0.86, 0.43, 0.9))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for p in b.parts:
				n.draw_rect(Rect2(p.pos, Vector2(2, 2)), Color(0.63, 0.88, 0.55, p.life))
		"geyser":
			CubeKit.stage(n, b)
			if randf() < 0.3:            # double the plop
				CubeKit.ellipse(n, Vector2(b.gx + randf_range(-6, 6), b.G - 1.0), randf_range(2.0, 4.0), 2.0,
					Color(0.63, 0.5, 0.35, 0.6), 1.0, PI, TAU, 8)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				var hgt: float = sin(minf(1.0, (1.0 - p.life) * 3.0) * PI * 0.5) * c.s * 1.4 * minf(1.0, p.life * 2.0)
				for i in 8:
					var q := i / 8.0
					n.draw_set_transform(Vector2(p.x + sin(t * 8.0 + i) * 2.0, b.G - hgt * q), 0.0, Vector2(1.0, 1.2))
					n.draw_circle(Vector2.ZERO, 6.5 - q * 2.0, Color(0.55, 0.43, 0.29, 0.6 - q * 0.3))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"mist_veil":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for w in b.wisps:
				var pos := Vector2(c.x + cos(w.a) * c.s * (0.8 + b.press_v * 0.4),
					c.y - c.s * 0.5 + sin(w.a) * c.s * 0.5)
				CubeKit.glow(n, pos, w.r * (0.9 + b.press_v * 0.8), Color(0.1, 0.08, 0.16, 0.22 + b.press_v * 0.2), 2)
		"tidal_push":
			CubeKit.stage(n, b)
			CubeKit.ellipse(n, Vector2(c.x, b.G + 1.0), c.s * (0.8 + sin(t * 2.0) * 0.1), 3.0,
				Color(0.51, 0.75, 0.92, 0.35), 1.5, PI, TAU, 10)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				if p.kind != "wave":
					continue
				var hgt: float = c.s * 1.95 * minf(1.0, p.life * 1.6)   # half again the height
				for k in 4:
					CubeKit.ellipse(n, Vector2(p.x - p.dir * k * 5.0, b.G), 14.0 + k * 4.0,
						maxf(0.5, hgt - k * 5.0), Color(0.47, 0.75, 0.94, (0.6 - k * 0.12) * p.life), 3.0, PI, TAU, 12)
		_:
			Base.draw(n, b, t)
