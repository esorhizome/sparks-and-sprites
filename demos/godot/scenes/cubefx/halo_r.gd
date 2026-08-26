extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
const Base := preload("res://scenes/cubefx/halo.gd")
## HALOS & BLESSINGS — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"follow_halo": { "name": "Dark halo", "hint": "violet-black — the lag doubled for menace" },
	"wings": { "name": "Bat wings", "hint": "membrane instead of feathers — dark, ribbed, quick" },
	"sanctuary": { "name": "Warding ring", "hint": "turned to warning — red runes, sharper pulse" },
	"pillar": { "name": "Moon pillar", "hint": "narrowed and silvered — motes fall, not rise" },
	"guardians": { "name": "Wisp orbs", "hint": "green and unhurried — they scatter, not shield" },
	"blessing": { "name": "Ember blessing", "hint": "warmed — the press makes them SWARM to it" },
	"radiant": { "name": "Umbral burst", "hint": "inverted — a flash of dark with a violet rim" },
	"spotlight": { "name": "Villain's spotlight", "hint": "red, tight — it hurries when pressed" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)

static func press(b: Dictionary, pos: Vector2) -> void:
	Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	match b.id:
		"follow_halo":
			# dial: lag 5.0 → 2.5 (the menace is in the delay)
			b.press_v = maxf(0.0, b.press_v - dt * 1.6)
			b.hx += (c.x - b.hx) * minf(1.0, dt * 2.5)
		"pillar":
			# dial: motes fall from above instead of rising
			b.press_v = maxf(0.0, b.press_v - dt * 0.6)
			var r: Rect2 = b.rect
			if b.press_v > 0.0 and randf() < 0.5:
				b.parts.append({ "pos": Vector2(c.x + randf_range(-c.s, c.s) * 0.5, r.position.y + 4.0), "life": 1.0 })
			for p in b.parts:
				p.pos.y += 40.0 * dt
				p.life -= dt
			b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.pos.y < b.G)
		"blessing":
			# dial: the press pulls motes TO the cube instead of skyward
			b.press_v = maxf(0.0, b.press_v - dt * 1.0)
			var r: Rect2 = b.rect
			if randf() < 0.3:
				b.parts.append({ "pos": Vector2(c.x + randf_range(-c.s * 1.8, c.s * 1.8),
					r.position.y + randf_range(0, r.size.y * 0.3)), "life": 1.0 })
			for p in b.parts:
				if b.press_v > 0.0:
					var target := Vector2(c.x, c.y - c.s * 0.5)
					p.pos = p.pos.lerp(target, minf(1.0, dt * 4.0))
				else:
					p.pos.y += 22.0 * dt
				p.life -= dt * 0.4
			b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.pos.y > b.rect.position.y - 8.0 and p.pos.y < b.G)
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	var pv: float = b.press_v
	match b.id:
		"follow_halo":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			var hy: float = c.y - c.s * 1.5 + sin(t * 1.2) * 2.5
			var breath := 1.0 + 0.03 * sin(t * TAU / 3.0)
			for k in 3:
				CubeKit.ellipse(n, Vector2(b.hx, hy),
					(c.s * 0.55 + k * 1.5) * breath * (1.0 + pv * 0.3),
					(c.s * 0.16 + k * 0.8) * breath,
					Color(0.47, 0.27, 0.63, 0.6 - k * 0.15 + pv * 0.3), 3.0 - k * 0.7)
		"wings":
			CubeKit.stage(n, b)
			# dials: 4 feather curves → ribbed membrane · flutter ×2
			var spread: float = 0.25 + sin(t * 12.0) * 0.05 + pv * 1.1
			var bx: float = c.x - c.face * c.s * 0.3
			var by: float = c.y - c.s * 0.7
			var tip := Vector2(bx - c.face * 26.0 * spread, by - 10.0 * spread)
			for f in 4:                    # the ribs, straight and dark
				var q := (f + 1) / 4.0
				n.draw_line(Vector2(bx, by),
					Vector2(bx - c.face * 26.0 * spread * q, by - (16.0 - f * 5.0) * spread),
					Color(0.24, 0.18, 0.31, 0.7 + pv * 0.3), 1.4)
			CubeKit.qcurve(n, Vector2(bx, by), Vector2(bx - c.face * 14.0 * spread, by + 4.0),
				tip, Color(0.31, 0.22, 0.39, 0.6 + pv * 0.4), 2.2)
			CubeKit.draw_cube(n, b)
		"sanctuary":
			CubeKit.stage(n, b)
			# dials: gold → warning red · pulse sharper (runes tick, not glide)
			var rr: float = c.s * (1.1 + pv * 1.3)
			CubeKit.glow(n, Vector2(c.x, b.G), rr, Color(0.9, 0.27, 0.24, 0.1 + pv * 0.14), 2)
			CubeKit.ellipse(n, Vector2(c.x, b.G + 1.0), rr, rr * 0.24,
				Color(0.94, 0.39, 0.31, 0.5 + pv * 0.4 + 0.2 * sin(t * 6.0)), 1.6)
			for i in 6:
				var a: float = floorf(t * 2.0) * 0.5 + i / 6.0 * TAU
				n.draw_rect(Rect2(Vector2(c.x + cos(a) * rr - 1.0, b.G + 1.0 + sin(a) * rr * 0.24 - 3.0),
					Vector2(2, 6)), Color(1, 0.47, 0.39, 0.6 + pv * 0.4))
			CubeKit.draw_cube(n, b)
		"pillar":
			CubeKit.stage(n, b)
			# dials: pillar width ÷2 · warm → silver
			var r: Rect2 = b.rect
			var w: float = c.s * (0.25 + pv * 0.55)
			var a2: float = 0.06 + pv * 0.3
			n.draw_colored_polygon(PackedVector2Array([
				Vector2(c.x - w * 0.6, r.position.y), Vector2(c.x + w * 0.6, r.position.y),
				Vector2(c.x + w, b.G), Vector2(c.x - w, b.G)]), Color(0.86, 0.89, 0.97, a2))
			for p in b.parts:
				CubeKit.glow(n, p.pos, 3.0, Color(0.86, 0.9, 0.98, p.life * 0.8), 2)
			CubeKit.draw_cube(n, b)
		"guardians":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			# dials: orbit ÷2 · the press scatters them WIDE instead of shielding
			for i in 3:
				var pos: Vector2
				if pv > 0.15:
					var th := -PI / 2.0 + i / 3.0 * TAU + t
					pos = Vector2(c.x + cos(th) * c.s * (1.3 + pv * 1.4),
						c.y - c.s * 0.5 + sin(th) * c.s * (0.9 + pv * 0.8))
				else:
					var a: float = t * 0.7 + i / 3.0 * TAU
					pos = Vector2(c.x + cos(a) * c.s * 1.15, c.y - c.s * 0.5 + sin(a) * c.s * 0.65)
				CubeKit.glow(n, pos, 5.0, Color(0.55, 0.94, 0.63, 0.85), 2)
		"blessing":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				CubeKit.glow(n, p.pos, 3.5, Color(1, 0.67, 0.31, p.life * 0.8), 2)
		"radiant":
			CubeKit.stage(n, b)
			CubeKit.draw_cube(n, b)
			CubeKit.glow(n, Vector2(c.x, c.y - c.s * 0.5), c.s * 0.8,
				Color(0.35, 0.24, 0.47, 0.2 + 0.06 * sin(t * 1.3)), 2)
			if pv > 0.0:
				var L: float = 10.0 + (1.0 - pv) * c.s * 2.4
				var hy2: float = c.y - c.s * 0.5
				n.draw_circle(Vector2(c.x, hy2), L * 0.5, Color(0.06, 0.04, 0.1, pv * 0.85))
				n.draw_line(Vector2(c.x - L, hy2), Vector2(c.x + L, hy2), Color(0.63, 0.39, 0.9, pv * 0.9), 2.0)
				n.draw_line(Vector2(c.x, hy2 - L * 0.8), Vector2(c.x, hy2 + L * 0.8), Color(0.63, 0.39, 0.9, pv * 0.9), 2.0)
				CubeKit.ellipse(n, Vector2(c.x, hy2), L * 0.8, L * 0.5, Color(0.71, 0.47, 1.0, pv * 0.9), 1.5)
		"spotlight":
			CubeKit.stage(n, b)
			# dials: warm wide beam → red tight beam (hurry dial in Base tick)
			var r: Rect2 = b.rect
			var w: float = c.s * (0.8 - pv * 0.3)
			n.draw_colored_polygon(PackedVector2Array([
				Vector2(b.hx - 4.0, r.position.y), Vector2(b.hx + 4.0, r.position.y),
				Vector2(b.hx + w, b.G), Vector2(b.hx - w, b.G)]), Color(1, 0.31, 0.27, 0.12 + pv * 0.2))
			n.draw_set_transform(Vector2(b.hx, b.G + 1.0), 0.0, Vector2(1.0, 0.22))
			n.draw_circle(Vector2.ZERO, w, Color(1, 0.31, 0.27, 0.12 + pv * 0.2))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			CubeKit.draw_cube(n, b)
		_:
			Base.draw(n, b, t)
