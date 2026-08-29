extends RefCounted

const Kit := preload("res://scenes/motion/kit.gd")
## BRAINS & STEERING — seven movement styles, ported from the web lexicon.
## A steering agent keeps a velocity and, each frame, computes a DESIRED
## velocity from what it wants — then applies only a gentle correction
## (desired − current, clamped). That subtraction is why steered things
## bank and drift like living creatures instead of snapping like cursors.

const TITLE := "Brains & steering"
const BLURB := "seek, wander, flock, fields — how enemies decide where to go"
const DEFS := [
	{ "id": "arrive", "name": "A · Arrive", "hint": "seek, but braking inside the amber ring — press to move the target" },
	{ "id": "chase", "name": "C · Chase", "hint": "aim where the prey WILL be — the faint rival aims where it is — press to scatter" },
	{ "id": "wander", "name": "W · Wander", "hint": "a jittering target on a circle held out front — press to startle" },
	{ "id": "zigzag", "name": "Z · Zigzag", "hint": "a patrol path with eased legs and pauses — press to add a waypoint" },
	{ "id": "magnet", "name": "M · Magnet", "hint": "inverse-square fields: dust in the pull of three magnets — press to flip them" },
	{ "id": "vectorfield", "name": "V · Vectorfield", "hint": "a formula turns every point into an arrow; riders obey — press to pour more in" },
	{ "id": "swarm", "name": "S · Swarm", "hint": "boids: separation + alignment + cohesion, nobody in charge — press to scare them" },
]

static func _zig_defaults(b: Dictionary) -> Array:
	var pts := []
	for i in 5:
		pts.append(Vector2(b.w * (0.12 + i * 0.19), b.h * 0.25 if i % 2 == 1 else b.h * 0.65))
	return pts

static func _field_angle(p: Vector2, t: float) -> float:
	return sin(p.x * 0.019 + t * 0.24) * 1.6 + cos(p.y * 0.023 - t * 0.17) * 1.6

static func init(b: Dictionary) -> void:
	match b.id:
		"arrive":
			b.p = Vector2(b.w * 0.2, b.h * 0.7)
			b.v = Vector2.ZERO
			b.tgt = Vector2(b.w * 0.7, b.h * 0.35)
			b.timer = 0.0
		"chase":
			b.prey = { "p": Vector2(b.w * 0.6, b.h * 0.4), "v": Vector2.ZERO }
			b.smart = { "p": Vector2(b.w * 0.15, b.h * 0.8), "v": Vector2.ZERO }
			b.naive = { "p": Vector2(b.w * 0.85, b.h * 0.8), "v": Vector2.ZERO }
			b.wa = 0.0
			b.caught = 0
			b.flash = 0.0
		"wander":
			b.p = Vector2(b.w / 2.0, b.h / 2.0)
			b.v = Vector2(60.0, 0.0)
			b.wa = 0.0
			b.burst = 0.0
		"zigzag":
			b.pts = _zig_defaults(b)
			b.seg = 0
			b.dir = 1
			b.k = 0.0
			b.pause = 0.0
			b.gd = 0.0
		"magnet":
			b.mags = [
				{ "p": Vector2(b.w * 0.28, b.h * 0.38), "pol": 1.0 },
				{ "p": Vector2(b.w * 0.72, b.h * 0.34), "pol": 1.0 },
				{ "p": Vector2(b.w * 0.5, b.h * 0.72), "pol": -1.0 },
			]
			b.dust = []
			for i in 36:
				b.dust.append({ "p": Vector2(randf_range(0, b.w), randf_range(0, b.h)), "v": Vector2.ZERO })
		"vectorfield":
			b.riders = []
			for i in 40:
				b.riders.append(Vector2(randf_range(0, b.w), randf_range(0, b.h)))
		"swarm":
			b.boids = []
			for i in 26:
				b.boids.append({ "p": Vector2(randf_range(0, b.w), randf_range(0, b.h)),
					"v": Vector2(randf_range(-60, 60), randf_range(-60, 60)), "g": i < 2 })

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"arrive":
			b.tgt = pos
			b.timer = -4.0
		"chase":
			b.prey.p = pos
			b.prey.v = Vector2(randf_range(-90, 90), randf_range(-90, 90))
		"wander":
			b.wa = randf_range(-PI, PI)
			b.burst = 1.0
		"zigzag":
			if b.pts.size() >= 8:
				b.pts = _zig_defaults(b)
			else:
				b.pts.append(pos)
			b.seg = 0
			b.dir = 1
			b.k = 0.0
			b.pause = 0.0
			b.gd = 0.0
		"magnet":
			for m in b.mags:                             # invert the world
				m.pol = -m.pol
		"vectorfield":
			for i in 14:
				b.riders[randi_range(0, b.riders.size() - 1)] = pos + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		"swarm":
			for bd in b.boids:
				var d: Vector2 = bd.p - pos
				var l := d.length() + 4.0
				bd.v += d / l * (9000.0 / l)             # fear, inverse with distance

## Steer an agent dictionary {p, v} toward a point. The one subtraction.
static func _steer(a: Dictionary, tgt: Vector2, maxsp: float, force: float, dt: float, b: Dictionary) -> void:
	var to: Vector2 = tgt - a.p
	var d := maxf(to.length(), 0.001)
	var want := to / d * maxsp
	a.v += (want - a.v).limit_length(force) * dt * 4.0
	a.v = (a.v as Vector2).limit_length(maxsp)
	a.p += a.v * dt
	a.p.x = clampf(a.p.x, 10.0, b.w - 10.0)
	a.p.y = clampf(a.p.y, 10.0, b.h - 10.0)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"arrive":
			b.timer += dt
			if b.timer > 3.2:
				b.timer = 0.0
				b.tgt = Vector2(randf_range(b.w * 0.15, b.w * 0.85), randf_range(b.h * 0.15, b.h * 0.85))
			var to: Vector2 = b.tgt - b.p
			var d := maxf(to.length(), 0.001)
			var desired := to / d * (130.0 * minf(1.0, d / 85.0))   # ← the whole idea of Arrive
			b.steer = (desired - b.v as Vector2).limit_length(300.0)
			b.v += b.steer * dt
			b.v = (b.v as Vector2).limit_length(130.0)
			b.p += b.v * dt
		"chase":
			b.wa += randf_range(-2.6, 2.6) * sqrt(dt)    # the prey wanders...
			var flee := Vector2(cos(b.wa), sin(b.wa)) * 105.0
			var pd: float = (b.smart.p - b.prey.p as Vector2).length()
			if pd < 95.0:                                # ...and flees the smart one
				flee += (b.prey.p - b.smart.p as Vector2) / pd * 150.0
			_steer(b.prey, b.prey.p + flee, 112.0, 260.0, dt, b)
			var eta := pd / 95.0                         # rough time-to-intercept
			b.future = b.prey.p + b.prey.v * eta * 0.9
			_steer(b.smart, b.future, 95.0, 240.0, dt, b)
			_steer(b.naive, b.prey.p, 95.0, 240.0, dt, b)
			if pd < 14.0:
				b.caught += 1
				b.flash = 1.0
				b.prey.p = Vector2(randf_range(b.w * 0.1, b.w * 0.9), randf_range(b.h * 0.1, b.h * 0.9))
			b.flash = maxf(0.0, b.flash - dt * 2.0)
		"wander":
			b.burst = maxf(0.0, b.burst - dt * 0.7)
			b.wa += randf_range(-1, 1) * 3.1 * sqrt(dt)  # the only randomness in the rig
			var hd := (b.v as Vector2).normalized()
			b.ahead = b.p + hd * 46.0                    # the guide circle, out front
			b.rim = b.ahead + Vector2(cos(hd.angle() + b.wa), sin(hd.angle() + b.wa)) * 26.0
			var maxsp: float = 85.0 * (1.0 + b.burst * 1.2)
			var to: Vector2 = b.rim - b.p
			b.v += (to.normalized() * maxsp - b.v) * 3.0 * dt
			b.p += b.v * dt
			b.p.x = wrapf(b.p.x, -12.0, b.w + 12.0)
			b.p.y = wrapf(b.p.y, -12.0, b.h + 12.0)
		"zigzag":
			var a: Vector2 = b.pts[b.seg]
			var c: Vector2 = b.pts[b.seg + 1]
			if b.pause > 0.0:
				b.pause -= dt
			else:
				b.k += dt * 150.0 / maxf(a.distance_to(c), 1.0)   # constant speed, eased per leg
				if b.k >= 1.0:
					b.k = 0.0
					b.pause = 0.45                       # the corner rest
					b.seg += b.dir
					if b.seg > b.pts.size() - 2:
						b.seg = b.pts.size() - 2
						b.dir = -1
					if b.seg < 0:
						b.seg = 0
						b.dir = 1
			var total := 0.0
			for i in b.pts.size() - 1:
				total += (b.pts[i] as Vector2).distance_to(b.pts[i + 1])
			b.gd = fmod(b.gd + 110.0 * dt, total * 2.0)  # ghost ping-pongs by distance
		"magnet":
			for g in b.dust:
				for m in b.mags:
					var d: Vector2 = m.p - g.p
					var dd: float = d.length_squared() + 900.0   # +900 softens the singularity
					var f: float = m.pol * 26000.0 / dd
					var dir := d / sqrt(dd)
					g.v += dir * f * dt * 60.0
					if m.pol > 0.0:                      # a whisper of sideways push,
						g.v += dir.orthogonal() * f * dt * 24.0  # so grains orbit the pull
				g.v *= 1.0 - 0.7 * dt                    # drag = the settling
				g.v = (g.v as Vector2).limit_length(190.0)
				g.p += g.v * dt
				g.p.x = wrapf(g.p.x, 0.0, b.w)
				g.p.y = wrapf(g.p.y, 0.0, b.h)
		"vectorfield":
			for i in b.riders.size():
				var a := _field_angle(b.riders[i], t)
				var p: Vector2 = b.riders[i] + Vector2(cos(a), sin(a)) * 62.0 * dt
				p.x = wrapf(p.x, 0.0, b.w)
				p.y = wrapf(p.y, 0.0, b.h)
				b.riders[i] = p
		"swarm":
			for bd in b.boids:
				var sep := Vector2.ZERO
				var ali := Vector2.ZERO
				var coh := Vector2.ZERO
				var cnt := 0
				for o in b.boids:
					if o == bd:
						continue
					var d: Vector2 = o.p - bd.p
					var l := d.length()
					if l < 26.0 and l > 0.0:
						sep -= d / l / l                 # 1: separation
					if l < 54.0:
						ali += o.v
						coh += o.p
						cnt += 1
				if cnt > 0:
					bd.v += (ali / cnt - bd.v) * 1.4 * dt        # 2: alignment
					bd.v += (coh / cnt - bd.p) * 1.1 * dt        # 3: cohesion
				bd.v += sep * 3400.0 * dt
				var s := maxf((bd.v as Vector2).length(), 0.001)
				var sp := clampf(s, 55.0, 105.0)         # a floor keeps the flock flowing
				bd.v *= sp / s
				bd.p += bd.v * dt
				bd.p.x = wrapf(bd.p.x, -8.0, b.w + 8.0)
				bd.p.y = wrapf(bd.p.y, -8.0, b.h + 8.0)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	Kit.stage(n, b)
	var origin: Vector2 = (b.rect as Rect2).position
	match b.id:
		"arrive":
			Kit.ring(n, b.tgt, 85.0, Color(0.961, 0.757, 0.412, 0.25))
			Kit.dot(n, b.tgt, 4.0, Kit.TARGET)
			Kit.arrow(n, b.p, b.p + b.v * 0.35, Kit.GOOD)
			if b.has("steer"):
				Kit.arrow(n, b.p, b.p + b.steer * 0.12, Kit.HOT)
			Kit.mote(n, b, b.p, (b.v as Vector2).angle())
			Kit.label(n, b, "desired speed = max · min(1, distance/85)", Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"chase":
			if b.flash > 0.0:
				Kit.ring(n, b.smart.p, 18.0 + (1.0 - b.flash) * 30.0, Color(0.961, 0.757, 0.412, b.flash * 0.8), 2.0)
			if b.has("future"):
				Kit.ring(n, b.future, 6.0, Color(0.961, 0.757, 0.412, 0.5))   # the prediction
				n.draw_dashed_line(b.smart.p, b.future, Color(0.961, 0.757, 0.412, 0.3), 1.0, 7.0)
			Kit.mote(n, b, b.prey.p, (b.prey.v as Vector2).angle(), Kit.GOOD, 7.0)
			Kit.mote(n, b, b.smart.p, (b.smart.v as Vector2).angle(), Kit.MOVER, 8.0)
			Kit.mote(n, b, b.naive.p, (b.naive.v as Vector2).angle(), Color(0.91, 0.898, 0.957, 0.28), 8.0)
			Kit.label(n, b, "caught ×%d · blue predicts, ghost points" % b.caught, Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"wander":
			if b.has("ahead"):
				Kit.ring(n, b.ahead, 26.0, Color(0.91, 0.898, 0.957, 0.2))
				n.draw_line(b.p, b.rim, Kit.DIM, 1.0)
				Kit.dot(n, b.rim, 3.5, Kit.TARGET)
			Kit.mote(n, b, b.p, (b.v as Vector2).angle())
			Kit.label(n, b, "steer at the rim dot; jitter only its angle", Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"zigzag":
			for i in b.pts.size() - 1:
				n.draw_line(b.pts[i], b.pts[i + 1], Color(0.788, 0.769, 0.894, 0.35), 1.5)
			for p in b.pts:
				Kit.ring(n, p, 4.0, Color(0.788, 0.769, 0.894, 0.5))
			var a: Vector2 = b.pts[b.seg]
			var c: Vector2 = b.pts[b.seg + 1]
			# forward legs run a→c; backward legs run c→a (e2 flips the same easing)
			var e := smoothstep(0.0, 1.0, b.k)
			var e2: float = e if b.dir > 0 else 1.0 - e
			var saw := a + (c - a) * e2
			var total := 0.0                             # the constant-speed ghost
			for i in b.pts.size() - 1:
				total += (b.pts[i] as Vector2).distance_to(b.pts[i + 1])
			var g: float = b.gd if b.gd <= total else total * 2.0 - b.gd
			var gp: Vector2 = b.pts[0]
			for i in b.pts.size() - 1:
				var L: float = (b.pts[i] as Vector2).distance_to(b.pts[i + 1])
				if g <= L:
					gp = (b.pts[i] as Vector2) + ((b.pts[i + 1] as Vector2) - b.pts[i]) * g / maxf(L, 0.001)
					break
				g -= L
			Kit.dot(n, gp, 7.0, Color(0.91, 0.898, 0.957, 0.18))
			n.draw_set_transform(origin + saw, t * 9.0, Vector2.ONE)   # the saw: eased, mean
			n.draw_circle(Vector2.ZERO, 8.0, Kit.HOT)
			for i in 8:
				var an := i / 8.0 * TAU
				n.draw_line(Vector2(cos(an), sin(an)) * 8.0, Vector2(cos(an), sin(an)) * 12.0, Kit.HOT, 2.0)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.label(n, b, "%d/8 waypoints · eased saw vs constant ghost" % b.pts.size(), Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"magnet":
			for g in b.dust:
				Kit.dot(n, g.p, 1.7, Color(0.91, 0.898, 0.957, 0.7))
			for m in b.mags:
				var col: Color = Kit.TARGET if m.pol > 0.0 else Kit.HOT
				var k := fmod(t * 0.8, 1.0)
				var r: float = 22.0 - k * 14.0 if m.pol > 0.0 else 8.0 + k * 14.0
				Kit.dot(n, m.p, 5.0, col)                # breathe in = pull, out = push
				var ra: float = (0.5 - absf(0.5 - k) * 0.6) if m.pol > 0.0 else (0.55 - k * 0.5)
				Kit.ring(n, m.p, r, Color(col.r, col.g, col.b, ra), 1.5)
			Kit.label(n, b, "force = k ÷ distance² — flip: pull ⇄ push", Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"vectorfield":
			var gx := 20.0
			while gx < b.w:                              # sample the field into arrows
				var gy := 20.0
				while gy < b.h:
					var a := _field_angle(Vector2(gx, gy), t)
					var d := Vector2(cos(a), sin(a)) * 5.0
					Kit.arrow(n, Vector2(gx, gy) - d, Vector2(gx, gy) + d, Color(0.91, 0.898, 0.957, 0.16))
					gy += 36.0
				gx += 36.0
			for p in b.riders:
				var a := _field_angle(p, t)
				var w := Vector2(cos(a), sin(a))
				n.draw_line(p - w * 6.0, p, Color(0.541, 0.851, 0.961, 0.5), 1.0)
				Kit.dot(n, p, 2.0, Kit.MOVER)
			Kit.label(n, b, "angle(x, y, t) = sin(x·s + t) + cos(y·s − t)", Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"swarm":
			for bd in b.boids:
				n.draw_set_transform(origin + bd.p, (bd.v as Vector2).angle(), Vector2.ONE)
				n.draw_colored_polygon(PackedVector2Array([
					Vector2(6, 0), Vector2(-4, 3.4), Vector2(-4, -3.4)]),
					Kit.GOOD if bd.g else Kit.MOVER)
				n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.label(n, b, "three averages over neighbours = the brain", Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
