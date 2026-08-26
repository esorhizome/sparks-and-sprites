extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
const Base := preload("res://scenes/elements/water.gd")
## WATER — the rhymes. Dials named per branch; everything else delegates.

const RHYMES := {
	"bubble_tank": { "name": "Lava lamp", "hint": "filled warm blobs that fade, rise ÷2" },
	"fizz": { "name": "Ember fizz", "hint": "champagne re-coloured to campfire" },
	"ripple_pool": { "name": "Sand garden", "hint": "raked rings that persist 4× longer" },
	"rain_glass": { "name": "Snow on glass", "hint": "flakes that stick, creep instead of run" },
	"waterline": { "name": "Oil line", "hint": "dark iridescent liquid, spring ÷4" },
	"whirlpool": { "name": "Galaxy pool", "hint": "motes turned to stars, drain ÷4" },
	"spring_tide": { "name": "Ebb tide", "hint": "the lift dial reversed — a press DRAINS" },
	"deep_sea": { "name": "Void drift", "hint": "reset in space: stars, a slow comet" },
	"waterfall": { "name": "Light veil", "hint": "golden, at a third of the speed" },
	"squirt": { "name": "Ink squirt", "hint": "droplets darkened, gravity ×2" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)
	match b.id:
		"waterline":
			pass                            # spring dial handled in tick below
		"whirlpool":
			for m in b.motes:               # drain ÷4
				m.v *= 0.5
		"waterfall":
			pass
		"squirt":
			pass

static func press(b: Dictionary, pos: Vector2) -> void:
	Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"bubble_tank":
			# dials: rise ÷2 · pops → fades
			for p in b.parts:
				if p.kind == "bub":
					p.pos.y -= (4.0 + p.r) * dt
					if p.pos.y < p.r + 4.0:
						p.kind = "pop"
						p.life = 0.5
				else:
					p.life -= dt * 1.5
			if b.parts.size() < 8 and randf() < 0.1:
				b.parts.append({ "kind": "bub", "pos": Vector2(randf_range(10, b.rect.size.x - 10), b.rect.size.y - 6.0),
					"r": randf_range(4, 9), "ph": randf_range(0, 9) })
			b.parts = b.parts.filter(func(p): return p.kind == "bub" or p.life > 0.0)
		"waterline":
			# dial: spring 26 → 7 (syrup)
			b.tilt_v += -b.tilt * 7.0 * dt
			b.tilt_v *= pow(0.5, dt)
			b.tilt += b.tilt_v * dt
		"whirlpool":
			var r: Rect2 = b.rect
			b.spin += (1.0 - b.spin) * dt * 0.8
			for m in b.motes:
				m.prev = Vector2(cos(m.a) * m.r, sin(m.a) * m.r * 0.55)
				m.a += m.v * b.spin * dt
				m.r -= 0.9 * b.spin * dt   # the ÷4 drain
				if m.r < 6.0:
					m.r = r.size.x * randf_range(0.5, 0.65)
					m.a = randf_range(0, TAU)
					m.prev = Vector2(cos(m.a) * m.r, sin(m.a) * m.r * 0.55)
		"squirt":
			# dial: gravity 180 → 420 for the flying drops
			var r: Rect2 = b.rect
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += 420.0 * dt
				p.life -= dt * 1.2
			b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.pos.y < r.size.y + 40.0)
			b.drip += dt * 0.4
			if b.drip > 2.6:
				b.parts.append({ "kind": "jet", "pos": Vector2(4, r.size.y - 2), "vel": Vector2(randf_range(-5, 5), 30), "life": 1.4 })
				b.drip = 0.0
		"waterfall":
			Base.tick(b, dt, t)
			for p in b.parts:              # the ÷3 speed dial, applied on entry
				if p.kind == "streak" and p.vel.y > 55.0:
					p.vel.y = randf_range(30, 50)
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	match b.id:
		"bubble_tank":
			ElemKit.face(n, r, Color(0.118, 0.055, 0.078, 0.96), Color(1, 0.59, 0.47, 0.5))
			for p in b.parts:
				var pos: Vector2 = o + p.pos + Vector2(sin(t * 0.8 + p.get("ph", 0.0)) * 3.0, 0)
				var alpha: float = 0.55 if p.kind == "bub" else p.life
				ElemKit.glow(n, pos, p.r, Color(1, 0.55, 0.39, alpha), 3)
			ElemKit.label(n, r, "GROOVY", Color(1, 0.85, 0.8))
		"fizz":
			ElemKit.face(n, r, Color(0.1, 0.047, 0.031, 0.9), Color(1, 0.59, 0.31, 0.5))
			for p in b.parts:
				if p.kind == "fizz":
					if p.pos.y > 2.0:
						n.draw_rect(Rect2(o + p.pos, Vector2(1.5, 1.5)), Color(1, 0.67, 0.35, 0.6 * p.life))
				else:
					n.draw_circle(o + p.pos, p.r, Color(1, 0.78, 0.51, 0.7 * p.life))
			ElemKit.label(n, r, "CRACKLE", Color(1, 0.88, 0.76))
		"ripple_pool":
			# dials: palette water→sand — rings drawn multi-groove
			ElemKit.face(n, r, Color(0.27, 0.235, 0.176), Color(0.86, 0.78, 0.63, 0.5))
			for p in b.parts:
				for k in 3:
					var rr := maxf(0.5, p.r - k * 5.0)
					ElemKit.ellipse(n, o + p.pos, rr, rr * 0.45,
						Color(0.9, 0.82, 0.67, minf(1.0, p.life * 2.0) * 0.7), 1.0)
			ElemKit.label(n, r, "ZEN", Color(0.94, 0.89, 0.8))
		"rain_glass":
			ElemKit.face(n, r, Color(0.055, 0.078, 0.118, 0.96), Color(0.75, 0.84, 0.94, 0.5))
			ElemKit.label(n, r, "FROSTPANE", Color(0.88, 0.93, 0.98, 0.85))
			for p in b.parts:
				ElemKit.twinkle(n, o + p.pos, p.r * 2.0, Color(0.92, 0.95, 1.0, 0.8))
			if b.wiper >= 0.0:
				var wx: float = o.x + r.size.x * (b.wiper / 1.1)
				n.draw_line(Vector2(wx, o.y + r.size.y), Vector2(wx - 6, o.y), Color(0.78, 0.82, 0.88, 0.9), 3.0)
		"waterline":
			ElemKit.face(n, r, Color(0.063, 0.055, 0.078, 0.96), Color(0.7, 0.63, 0.78, 0.55))
			var lv := r.size.y * 0.45
			var poly := PackedVector2Array()
			poly.append(o + Vector2(0, r.size.y - 2))
			var x := 0.0
			while x <= r.size.x:
				var k := (x - r.size.x / 2.0) / r.size.x
				var y: float = lv + k * b.tilt * 60.0 + sin(x * 0.11 + t * 1.2) * 0.8
				poly.append(o + Vector2(x, clampf(y, 4, r.size.y - 2)))
				x += 4.0
			poly.append(o + Vector2(r.size.x, r.size.y - 2))
			n.draw_colored_polygon(poly, Color(0.31, 0.24, 0.39, 0.85))
			n.draw_polyline(poly.slice(1, poly.size() - 1), Color(0.86, 0.78, 1.0, 0.5), 1.2)
			ElemKit.label(n, r, "CRUDE", Color(0.89, 0.85, 0.94))
		"whirlpool":
			ElemKit.face(n, r, Color(0.055, 0.047, 0.094, 0.9), Color(0.75, 0.75, 1.0, 0.55))
			for m in b.motes:
				var cur := r.get_center() + Vector2(cos(m.a) * m.r, sin(m.a) * m.r * 0.55)
				n.draw_rect(Rect2(cur, Vector2(1.4, 1.4)), Color(0.9, 0.89, 1.0, 0.8))
			ElemKit.label(n, r, "ANDROMEDA", Color(0.89, 0.89, 1.0))
		"spring_tide":
			ElemKit.face(n, r, Color(0.078, 0.07, 0.133, 0.92), Color(0.55, 0.78, 0.92, 0.5))
			ElemKit.label(n, r, "RETREAT", Color(0.85, 0.94, 0.99))
			var base: float = r.size.y * 1.02 - sin(t * 0.5) * 4.0
			var drop: float = pv * 14.0                    # the reversal: it sinks
			for layer in 2:
				var poly := PackedVector2Array()
				poly.append(o + Vector2(-4, r.size.y + 8))
				var x := -4.0
				while x <= r.size.x + 4.0:
					poly.append(o + Vector2(x, base + drop - layer * 5.0 + sin(x * 0.05 + t * (2.0 + layer)) * 4.0))
					x += 5.0
				poly.append(o + Vector2(r.size.x + 4, r.size.y + 8))
				n.draw_colored_polygon(poly, Color(0.16, 0.47, 0.7, 0.45) if layer == 0 else Color(0.31, 0.7, 0.9, 0.5))
			for p in b.parts:
				n.draw_circle(o + p.pos, p.r, Color(0.92, 0.98, 1.0, 0.8 * p.life))
		"deep_sea":
			ElemKit.face(n, r, Color(0.043, 0.039, 0.094, 0.97), Color(0.78, 0.75, 1.0, 0.4 + pv * 0.6))
			for s in b.snow:
				var a := 0.2 + 0.5 * maxf(0.0, sin(t * 3.0 + s.pos.x)) + pv * 0.3
				n.draw_rect(Rect2(o + s.pos, Vector2(1.4, 1.4)), Color(0.88, 0.88, 0.98, minf(1.0, a)))
			var jx := o.x + r.size.x * 0.5 + sin(t * 0.4) * r.size.x * 0.3
			var jy := o.y + r.size.y * 0.3
			ElemKit.glow(n, Vector2(jx, jy), 10.0 + pv * 8.0, Color(1, 0.94, 0.82, 0.6 + pv * 0.4), 3)
			n.draw_line(Vector2(jx, jy), Vector2(jx - 24, jy - 9), Color(1, 0.88, 0.67, 0.3 + pv * 0.4), 1.5)
			ElemKit.label(n, r, "ADRIFT", Color(0.9, 0.88, 1.0, 0.8 + pv * 0.2))
		"waterfall":
			ElemKit.face(n, r, Color(0.094, 0.078, 0.047, 0.96), Color(1, 0.88, 0.63, 0.5))
			for p in b.parts:
				var pos: Vector2 = o + p.pos
				if p.kind == "streak":
					if p.pos.y > 0 and p.pos.y < r.size.y:
						n.draw_line(pos - Vector2(0, 12.0 + (1.0 - minf(1.0, p.pos.y / r.size.y)) * 4.0) * 0.4,
							pos, Color(1, 0.92, 0.71, 0.4), 1.2)
				else:
					n.draw_rect(Rect2(pos, Vector2(1.8, 1.8)), Color(1, 0.94, 0.78, p.life))
			ElemKit.label(n, r, "CURTAIN", Color(1, 0.95, 0.84))
		"squirt":
			ElemKit.face(n, r, Color(0.086, 0.078, 0.11, 0.96), Color(0.59, 0.55, 0.75, 0.5))
			ElemKit.label(n, r, "BLOT", Color(0.85, 0.82, 0.91))
			var dp := o + Vector2(4, r.size.y - 2 + b.drip)
			n.draw_set_transform(dp, 0.0, Vector2(1.0, 1.0 + b.drip * 0.4))
			n.draw_circle(Vector2.ZERO, 2.0 + b.drip * 0.8, Color(0.24, 0.196, 0.35, 0.95))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for p in b.parts:
				n.draw_circle(o + p.pos, 2.0, Color(0.27, 0.235, 0.43, minf(1.0, p.life)))
		_:
			Base.draw(n, b, t)
