extends RefCounted

const Kit := preload("res://scenes/motion/kit.gd")
## SLOPES & SPRINGS — five movement styles, ported from the web lexicon.
## Motion WITH memory: a velocity that persists, an acceleration that bends
## it. Calculus wearing gym clothes — "integration" just means adding them
## up one frame at a time.

const TITLE := "Slopes & springs"
const BLURB := "velocity, acceleration, damping — calculus wearing gym clothes"
const DEFS := [
	{ "id": "lerp", "name": "L · Lerp", "hint": "three ways to chase the same target — constant, eased, springy — press to move it" },
	{ "id": "damp", "name": "D · Damp", "hint": "one spring equation, three damping ratios — press to yank the target" },
	{ "id": "yaw", "name": "Y · Yaw", "hint": "a heading with a turn-rate limit — press to plant the flag" },
	{ "id": "jump", "name": "J · Jump", "hint": "v0 = sqrt(2gh): pick the height, get the launch speed — press to set the apex" },
	{ "id": "bounce", "name": "B · Bounce", "hint": "restitution: every bounce keeps 62% of the energy — press to throw" },
]

const ZETAS := [0.35, 1.0, 2.2]
const ZNAMES := ["ζ = 0.35 bouncy", "ζ = 1 critical", "ζ = 2.2 sluggish"]

static func init(b: Dictionary) -> void:
	match b.id:
		"lerp":
			b.tgt = Vector2(b.w * 0.7, b.h * 0.35)
			b.timer = 0.0
			b.a = Vector2(b.w * 0.2, b.h * 0.7)          # constant
			b.bp = Vector2(b.w * 0.2, b.h * 0.5)         # lerp
			b.c = Vector2(b.w * 0.2, b.h * 0.3)          # spring
			b.cv = Vector2.ZERO
		"damp":
			b.ty = b.h * 0.3
			b.timer = 0.0
			b.hold = 0.0
			b.ys = [b.h * 0.6, b.h * 0.6, b.h * 0.6]
			b.vs = [0.0, 0.0, 0.0]
		"yaw":
			b.p = Vector2(b.w * 0.3, b.h * 0.6)
			b.hd = 0.0
			b.timer = 0.0
			b.tgt = Vector2(b.w * 0.7, b.h * 0.4)
			b.trail = []
		"jump":
			b.apex = b.h * 0.36
			b.phase = "stand"
			b.timer = 0.0
			b.y = b.gy
			b.vy = 0.0
		"bounce":
			b.p = Vector2(b.w * 0.35, b.h * 0.12)
			b.v = Vector2(34.0, 0.0)
			b.squash = 0.0
			b.bounces = 0
			b.rest = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"lerp":
			b.tgt = pos
			b.timer = -3.0
		"damp":
			b.ty = pos.y
			b.hold = 4.0
		"yaw":
			b.tgt = pos
			b.timer = -6.0
		"jump":
			b.apex = clampf(b.gy - pos.y, b.h * 0.1, b.h * 0.62)
		"bounce":
			b.p = pos
			b.v = Vector2(randf_range(-70, 70), randf_range(-60, 20))
			b.bounces = 0
			b.rest = 0.0

static func tick(b: Dictionary, dt: float, _t: float) -> void:
	match b.id:
		"lerp":
			b.timer += dt
			if b.timer > 2.6:
				b.timer = 0.0
				b.tgt = Vector2(randf_range(b.w * 0.15, b.w * 0.85), randf_range(b.h * 0.2, b.h * 0.8))
			var to: Vector2 = b.tgt - b.a
			var step := 140.0 * dt                       # constant speed: a fixed step
			b.a = b.tgt if to.length() <= step else b.a + to.normalized() * step
			b.bp += (b.tgt - b.bp) * Kit.smooth(4.2, dt) # framerate-proof lerp factor
			var w := 7.5
			var z := 0.55                                # spring frequency + damping
			b.cv += ((b.tgt - b.c) * w * w - 2.0 * z * w * b.cv) * dt
			b.c += b.cv * dt
		"damp":
			if b.hold > 0.0:
				b.hold -= dt
			else:
				b.timer += dt
				if b.timer > 2.2:
					b.timer = 0.0
					b.ty = b.h * 0.68 if b.ty < b.h * 0.5 else b.h * 0.3
			var w := 8.0
			for i in 3:
				b.vs[i] += (w * w * (b.ty - b.ys[i]) - 2.0 * ZETAS[i] * w * b.vs[i]) * dt
				b.ys[i] += b.vs[i] * dt                  # the whole equation
		"yaw":
			b.timer += dt
			var want: float = (b.tgt - b.p as Vector2).angle()   # inverse trig: point → angle
			b.hd += clampf(wrapf(want - b.hd, -PI, PI), -2.0 * dt, 2.0 * dt)
			b.p += Vector2(cos(b.hd), sin(b.hd)) * 84.0 * dt     # forward trig: angle → motion
			b.p.x = wrapf(b.p.x, -12.0, b.w + 12.0)
			b.p.y = wrapf(b.p.y, -12.0, b.h + 12.0)
			if (b.tgt - b.p as Vector2).length() < 15.0 or b.timer > 7.0:
				b.timer = 0.0
				b.tgt = Vector2(randf_range(b.w * 0.15, b.w * 0.85), randf_range(b.h * 0.2, b.h * 0.8))
			b.trail.append(b.p)
			if b.trail.size() > 70:
				b.trail.pop_front()
		"jump":
			var G: float = b.h * 2.4
			var v0 := sqrt(2.0 * G * b.apex)             # designers pick h; maths delivers v0
			b.timer += dt
			if b.phase == "stand" and b.timer > 0.9:
				b.phase = "air"
				b.vy = -v0
				b.timer = 0.0
			if b.phase == "air":
				b.vy += (G if b.vy < 0.0 else G * 1.7) * dt   # heavier on the way down
				b.y += b.vy * dt
				if b.y >= b.gy:
					b.y = b.gy
					b.phase = "land"
					b.timer = 0.0
			if b.phase == "land" and b.timer > 0.16:
				b.phase = "stand"
				b.timer = 0.0
		"bounce":
			var G: float = b.h * 1.9
			var E := 0.78
			if b.rest > 0.0:
				b.rest -= dt
				if b.rest <= 0.0:
					b.p = Vector2(randf_range(b.w * 0.2, b.w * 0.8), b.h * 0.12)
					b.v = Vector2(randf_range(-40, 40), 0.0)
					b.bounces = 0
			else:
				b.v.y += G * dt
				b.p += b.v * dt
				if b.p.x < 9.0:
					b.p.x = 9.0
					b.v.x = -b.v.x * E
				if b.p.x > b.w - 9.0:
					b.p.x = b.w - 9.0
					b.v.x = -b.v.x * E
				if b.p.y > b.gy - 9.0:
					b.p.y = b.gy - 9.0
					b.v.y = -b.v.y * E              # the whole law of bouncing
					b.v.x *= 0.99
					b.squash = 0.12
					b.bounces += 1
					if absf(b.v.y) < b.h * 0.09:
						b.v.y = 0.0
						if absf(b.v.x) < 6.0:
							b.rest = 1.1
			b.squash = maxf(0.0, b.squash - dt)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	Kit.stage(n, b)
	var origin: Vector2 = (b.rect as Rect2).position
	match b.id:
		"lerp":
			Kit.ring(n, b.tgt, 10.0, Kit.TARGET, 1.5)
			Kit.dot(n, b.tgt, 3.0, Kit.TARGET)
			Kit.mote(n, b, b.a, (b.tgt - b.a as Vector2).angle(), Kit.GOOD, 6.0)
			Kit.mote(n, b, b.bp, (b.tgt - b.bp as Vector2).angle(), Kit.MOVER, 6.0)
			Kit.mote(n, b, b.c, (b.cv as Vector2).angle(), Kit.BONE, 6.0)
			Kit.label(n, b, "constant", Vector2(b.w * 0.25, b.h - 8.0), Color(0.608, 0.886, 0.541, 0.8), true)
			Kit.label(n, b, "lerp", Vector2(b.w * 0.5, b.h - 8.0), Color(0.541, 0.851, 0.961, 0.8), true)
			Kit.label(n, b, "spring", Vector2(b.w * 0.75, b.h - 8.0), Color(0.788, 0.769, 0.894, 0.8), true)
		"damp":
			n.draw_dashed_line(Vector2(0, b.ty), Vector2(b.w, b.ty), Kit.TARGET, 1.0, 8.0)
			for i in 3:
				var x: float = b.w * (0.25 + i * 0.25)
				n.draw_line(Vector2(x, b.h * 0.12), Vector2(x, b.h * 0.88), Color(0.91, 0.898, 0.957, 0.12), 1.0)
				var col: Color = [Kit.HOT, Kit.GOOD, Kit.MOVER][i]
				Kit.mote(n, b, Vector2(x, b.ys[i]), b.vs[i] * 0.002, col, 7.0)
				Kit.label(n, b, ZNAMES[i], Vector2(x, b.h * 0.97), Kit.INK * Color(1, 1, 1, 0.55), true)
			Kit.label(n, b, "a = ω²(target−y) − 2ζω·v", Vector2(b.w / 2.0, 14.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"yaw":
			var R := 84.0 / 2.0                          # turn radius = speed ÷ turn rate
			Kit.ring(n, b.p + Vector2(cos(b.hd + PI / 2), sin(b.hd + PI / 2)) * R, R, Color(0.91, 0.898, 0.957, 0.08))
			Kit.ring(n, b.p + Vector2(cos(b.hd - PI / 2), sin(b.hd - PI / 2)) * R, R, Color(0.91, 0.898, 0.957, 0.08))
			for i in b.trail.size():
				Kit.dot(n, b.trail[i], 1.3, Color(0.541, 0.851, 0.961, i / float(b.trail.size()) * 0.3))
			var tg: Vector2 = b.tgt                      # the flag
			n.draw_line(tg + Vector2(0, 8), tg + Vector2(0, -10), Kit.TARGET, 1.5)
			n.draw_colored_polygon(PackedVector2Array([
				tg + Vector2(0, -10), tg + Vector2(9, -6.5), tg + Vector2(0, -3)]), Kit.TARGET)
			Kit.mote(n, b, b.p, b.hd)
			Kit.label(n, b, "turn radius = speed ÷ turn rate ≈ %d px" % roundi(R), Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"jump":
			Kit.ground(n, b)
			var G: float = b.h * 2.4
			var v0 := sqrt(2.0 * G * b.apex)
			var x: float = b.w / 2.0
			if b.phase == "stand":                       # the predicted arc, while standing
				var sy: float = b.gy
				var sv := -v0
				for i in 46:
					sv += (G if sv < 0.0 else G * 1.7) * 0.022
					sy += sv * 0.022
					if sy > b.gy:
						break
					n.draw_rect(Rect2(x - 1.0, sy, 2.0, 2.0), Color(0.91, 0.898, 0.957, 0.18))
			Kit.ring(n, Vector2(x, b.gy - b.apex), 6.0, Kit.TARGET, 1.5)
			Kit.label(n, b, "apex h = %d px" % roundi(b.apex), Vector2(x + 12.0, b.gy - b.apex + 3.0), Color(0.961, 0.757, 0.412, 0.8))
			var sx := 1.0
			var sy2 := 1.0
			if b.phase == "stand" and b.timer > 0.7:     # anticipation crouch
				sx = 1.12
				sy2 = 0.85
			if b.phase == "air":
				sy2 = 1.0 + minf(0.35, absf(b.vy) / v0 * 0.3)
				sx = 1.0 / sy2
			if b.phase == "land":                        # the splat
				sx = 1.25
				sy2 = 0.72
			var ang := 0.0
			if b.phase == "air":
				ang = -0.5 if b.vy < 0.0 else 0.5
			n.draw_set_transform(origin + Vector2(x, b.y - 9.0 * sy2), 0.0, Vector2(sx, sy2))
			n.draw_circle(Vector2.ZERO, 8.0, Kit.MOVER)
			n.draw_circle(Vector2(3.0, -2.4).rotated(ang), 1.8, Kit.NIGHT)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.label(n, b, "v0 = sqrt(2·g·h) = %d" % roundi(v0), Vector2(b.w / 2.0, b.h - 6.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"bounce":
			Kit.ground(n, b)
			var s: float = 1.0 - (b.squash / 0.12) * 0.35 if b.squash > 0.0 else 1.0
			n.draw_set_transform(origin + b.p + Vector2(0.0, (1.0 - s) * 9.0), 0.0, Vector2(1.0 / s, s))
			n.draw_circle(Vector2.ZERO, 9.0, Kit.MOVER)  # squash preserves "volume"
			n.draw_circle(Vector2(2.8, -2.6), 2.0, Kit.NIGHT)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.label(n, b, "bounce %d · e = 0.78 of speed → e² of height" % b.bounces, Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
