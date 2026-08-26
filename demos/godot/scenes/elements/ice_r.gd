extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
const Base := preload("res://scenes/elements/ice.gd")
## ICE & FROST — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"frostbite": { "name": "Moss creep", "hint": "green, alive, growing 4× faster" },
	"snowdrift": { "name": "Ash fall", "hint": "mourning grey, wearier shake" },
	"ice_cracks": { "name": "Kintsugi", "hint": "cracks mended in gold, they LINGER" },
	"glacier": { "name": "Cliff crumble", "hint": "sandstone, chunks drop hard" },
	"aurora": { "name": "Ember aurora", "hint": "fire hues, shimmer ×2" },
	"hailstorm": { "name": "Bubble rain", "hint": "soap bubbles: fall ÷3, bounce ×2" },
	"frozen_core": { "name": "Warm hearth", "hint": "warmed, spikes softened into rays" },
	"blizzard": { "name": "Dust veil", "hint": "desert tan, whiteout → dustout" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"snowdrift":
			# dial: the shake is wearier — half the scatter energy
			var r: Rect2 = b.rect
			b.press_v = 1.0
			for i in b.pile.size():
				if b.pile[i] > 0.5:
					b.parts.append({ "pos": Vector2((i + 0.5) * r.size.x / b.pile.size(), -b.pile[i]),
						"vel": Vector2(randf_range(-18, 18), randf_range(-28, -8)), "life": 1.0 })
				b.pile[i] = 0.0
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"frostbite":
			# dial: creep 0.12 → 0.48 (alive, 4× faster)
			b.press_v = maxf(0.0, b.press_v - dt * 2.0)
			b.grow = minf(1.0, b.grow + dt * 0.48)
			for p in b.parts:
				p.pos += p.vel * dt
				p.life -= dt * 1.8
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"ice_cracks":
			# dial: refreeze 0.45 → 0.1 — the gold seams linger
			b.press_v = maxf(0.0, b.press_v - dt * 2.0)
			b.freeze = maxf(0.0, b.freeze - dt * 0.1)
		"glacier":
			# dial: bergs drop hard (gravity on) instead of drifting out to sea
			b.press_v = maxf(0.0, b.press_v - dt * 2.0)
			b.timer -= dt
			if b.timer <= 0.0:
				Base._calve(b, 1)
				b.timer = randf_range(2.5, 5.0)
			for p in b.parts:
				p.pos += p.vel * dt
				if p.kind == "berg":
					p.vel.y += 140.0 * dt
					p.rot += p.vr * dt
					p.life -= dt * 0.5
				else:
					p.vel.y += 110.0 * dt
					p.life -= dt * 1.6
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"hailstorm":
			# dials: gravity 60 → 18 · bounce 0.35–0.55 → 0.7–0.9 (soap physics)
			b.press_v = maxf(0.0, b.press_v - dt * 2.0)
			var r: Rect2 = b.rect
			if randf() < 0.1:
				b.parts.append({ "kind": "hail", "pos": Vector2(randf_range(-10, r.size.x + 10), -20.0),
					"vel": Vector2(randf_range(-8, 8), randf_range(26, 48)), "r": randf_range(2.0, 4.0) })
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += 18.0 * dt
				if p.vel.y > 0.0 and p.pos.y > -p.r and p.pos.y < 6.0 and p.pos.x > 0.0 and p.pos.x < r.size.x:
					p.vel.y = -p.vel.y * randf_range(0.7, 0.9)
					p.vel.x += randf_range(-14, 14)
			b.parts = b.parts.filter(func(p): return p.pos.y < r.size.y + 40.0)
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	match b.id:
		"frostbite":
			# dials: ice palette → living green
			ElemKit.face(n, r, Color(0.047, 0.094, 0.055, 0.96), Color(0.55, 0.86, 0.55, 0.6))
			ElemKit.label(n, r, "MOSS", Color(0.87, 0.97, 0.85))
			for f in b.fingers:
				var pts: Array = f.pts
				var count: int = clampi(1 + int(b.grow * (pts.size() - 1) + sin(t + f.ph) * 0.4), 1, pts.size() - 1)
				for i in range(1, count + 1):
					n.draw_line(o + pts[i - 1], o + pts[i], Color(0.51, 0.84, 0.47, 0.8), 1.4)
					if i > 1:
						n.draw_circle(o + pts[i], 1.6, Color(0.65, 0.9, 0.55, 0.5))
			for p in b.parts:
				n.draw_rect(Rect2(o + p.pos, Vector2(2, 2)), Color(0.7, 0.92, 0.6, p.life))
		"snowdrift":
			# dials: snow-white → mourning grey
			var jx: float = randf_range(-1, 1) * pv
			var rr := Rect2(r.position + Vector2(jx, 0), r.size)
			ElemKit.face(n, rr, Color(0.086, 0.082, 0.078, 0.96), Color(0.6, 0.57, 0.55, 0.55))
			ElemKit.label(n, rr, "AFTERMATH", Color(0.8, 0.78, 0.76))
			var poly := PackedVector2Array()
			poly.append(o + Vector2(jx, 0))
			for i in b.pile.size():
				poly.append(o + Vector2(jx + (i + 0.5) * r.size.x / b.pile.size(), -b.pile[i]))
			poly.append(o + Vector2(jx + r.size.x, 0))
			n.draw_colored_polygon(poly, Color(0.55, 0.52, 0.5, 0.9))
			for f in b.flakes:
				n.draw_circle(o + f.pos, 1.2, Color(0.66, 0.63, 0.6, 0.7))
			for p in b.parts:
				n.draw_rect(Rect2(o + p.pos, Vector2(2, 2)), Color(0.66, 0.63, 0.6, p.life))
		"ice_cracks":
			# dials: white seams → gold repair on dark lacquer
			ElemKit.face(n, r, Color(0.11, 0.094, 0.086, 0.95), Color(0.85, 0.7, 0.4, 0.6))
			ElemKit.label(n, r, "KINTSUGI", Color(0.95, 0.88, 0.72))
			if randf() < 0.02:
				var g := o + Vector2(randf_range(8, r.size.x - 8), randf_range(6, r.size.y - 6))
				n.draw_line(g + Vector2(-4, 3), g + Vector2(4, -3), Color(1, 0.9, 0.6, 0.5), 1.0)
			if b.freeze > 0.0:
				var reveal: float = minf(1.0, (1.0 - b.freeze) * 6.0)
				for pts in b.cracks:
					var cnt: int = clampi(int(ceil(reveal * pts.size())), 2, pts.size())
					for i in range(1, cnt):
						n.draw_line(o + pts[i - 1], o + pts[i], Color(1, 0.84, 0.43, minf(1.0, b.freeze * 2.0)), 1.8)
						n.draw_line(o + pts[i - 1], o + pts[i], Color(1, 0.96, 0.8, b.freeze * 0.7), 0.8)
		"glacier":
			# dials: ice shelf → sandstone cliff
			ElemKit.face(n, r, Color(0.76, 0.62, 0.44), Color(0.9, 0.78, 0.6, 0.8))
			n.draw_rect(Rect2(o, Vector2(r.size.x, 8)), Color(0.85, 0.72, 0.53))
			ElemKit.label(n, r, "CRUMBLE", Color(0.27, 0.18, 0.09, 0.85))
			for p in b.parts:
				if p.kind == "berg":
					n.draw_set_transform(o + p.pos, p.rot, Vector2.ONE)
					var poly := PackedVector2Array()
					for k in 5:
						var a := k / 5.0 * TAU
						poly.append(Vector2(cos(a), sin(a)) * p.r)
					n.draw_colored_polygon(poly, Color(0.68, 0.53, 0.36, p.life * 0.95))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				else:
					n.draw_rect(Rect2(o + p.pos, Vector2(1.6, 1.6)), Color(0.83, 0.7, 0.5, p.life))
		"aurora":
			# dials: borealis greens → fire hues · shimmer ×2
			ElemKit.face(n, r, Color(0.1, 0.055, 0.047, 0.95), Color(1, 0.7, 0.43, 0.55))
			ElemKit.label(n, r, "AUSTRALIS", Color(1, 0.9, 0.78))
			var hues := [0.02, 0.07, 0.11]
			for c in 3:
				var base_y := o.y - 10.0 - c * 5.0
				var x := 0.0
				while x < r.size.x:
					var sway: float = sin(x * 0.03 + t * (1.2 + c * 0.6) + c * 2) * 8.0
					var hgt: float = 12.0 + sin(x * 0.05 - t * (1.6 + pv * 2.0) + c) * 7.0 + pv * 12.0
					var a: float = maxf(0.0, 0.06 + 0.06 * sin(x * 0.02 + t * 2.0 + c * 3) + pv * 0.1)
					var col := Color.from_hsv(fmod(hues[c] + pv * 0.05 * sin(t * 3.0), 1.0), 0.9, 0.95, a)
					n.draw_line(o + Vector2(x + sway, base_y), o + Vector2(x + sway * 1.4, base_y - hgt), col, 3.0)
					x += 5.0
		"hailstorm":
			# dials: hailstones → soap bubbles (outline + highlight)
			ElemKit.face(n, r, Color(0.078, 0.1, 0.12, 0.96 - pv * 0.2), Color(0.71, 0.88, 0.92, 0.5 + pv * 0.5))
			ElemKit.label(n, r, "SOAP", Color(0.88, 0.95, 0.96))
			for p in b.parts:
				ElemKit.ellipse(n, o + p.pos, p.r, p.r, Color(0.8, 0.93, 0.97, 0.85), 1.0)
				n.draw_circle(o + p.pos - Vector2(p.r * 0.35, p.r * 0.35), p.r * 0.25, Color(1, 1, 1, 0.8))
		"frozen_core":
			# dials: cryo blue → hearth amber · frost spikes → soft rays
			ElemKit.face(n, r, Color(0.13, 0.086, 0.047, 0.8), Color(1, 0.78, 0.47, 0.6))
			var pulse := 0.5 + 0.5 * sin(t * 1.4)
			ElemKit.glow(n, r.get_center(), r.size.y * (0.55 + pulse * 0.3) + pv * 12.0,
				Color(1, 0.82, 0.5, 0.35 + pulse * 0.25 + pv * 0.35), 4)
			if pv > 0.0:
				for i in 10:
					var th := i / 10.0 * TAU
					var dir := Vector2(cos(th) * 1.5, sin(th) * 0.8)
					n.draw_line(r.get_center() + dir * 12.0,
						r.get_center() + dir * (30.0 + (1.0 - pv) * 20.0), Color(1, 0.9, 0.67, pv * 0.45), 2.6)
			ElemKit.label(n, r, "HEARTH", Color(1, 0.94, 0.83))
		"blizzard":
			# dials: whiteout → dustout in desert tan
			ElemKit.face(n, r, Color(0.12, 0.1, 0.07, 0.96), Color(0.85, 0.72, 0.5, 0.5))
			var shiver := Rect2(r.position + Vector2(randf_range(-0.8, 0.8), randf_range(-0.8, 0.8)), r.size)
			ElemKit.label(n, shiver, "HABOOB", Color(0.93, 0.85, 0.7))
			var gust := 0.6 + 0.4 * sin(t * 0.9)
			for s in b.streaks:
				n.draw_line(o + s, o + s + Vector2(9, -2), Color(0.88, 0.74, 0.5, 0.5 * gust), 1.2)
			if b.white > 0.0:
				ElemKit.face(n, r.grow(4.0), Color(0.8, 0.66, 0.45, minf(0.9, b.white * 1.1)))
		_:
			Base.draw(n, b, t)
