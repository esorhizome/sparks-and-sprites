extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
const Base := preload("res://scenes/elements/light.gd")
## LIGHT & GLOW — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"breath": { "name": "Ember breath", "hint": "warmed and quickened — a jog, not sleep" },
	"heartbeat": { "name": "Calm pulse", "hint": "second thump removed, rate halved" },
	"halo_orbit": { "name": "Twin moons", "hint": "two beads counter-rotating — count and sign" },
	"lens_flare": { "name": "Prism flare", "hint": "each ghost given its own hue" },
	"lighthouse": { "name": "Search party", "hint": "the wedge doubled and put in opposition" },
	"firefly_jar": { "name": "Plankton jar", "hint": "gone marine — cyan, slower, longer glows" },
	"prism": { "name": "Moon prism", "hint": "desaturated to silver — the night shift" },
	"spotlight": { "name": "Candle study", "hint": "warm, small, and honestly flickery" },
	"glowworm": { "name": "Comet crawler", "hint": "cold-blue, quick, double the memory" },
	"supernova": { "name": "Patient nova", "hint": "patience ×2, the voice lowered" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)
	if b.id == "firefly_jar":
		for f in b.flies:               # the ÷2 blink-clock dial
			f.sp *= 0.5

static func press(b: Dictionary, pos: Vector2) -> void:
	Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"glowworm":
			# dials: pace 0.25 → 0.55 · trail 36 → 72 segments, fading half as fast
			b.press_v = maxf(0.0, b.press_v - dt * 1.1)
			b.sprint = maxf(0.0, b.sprint - dt * 0.45)
			b.p += dt * (0.55 + b.sprint * 1.6)
			var a: float = b.p * TAU
			b.trail.append({ "pos": r.size / 2.0 + Vector2(cos(a) * r.size.x * 0.52, sin(a) * r.size.y * 0.62), "life": 1.0 })
			if b.trail.size() > 72:
				b.trail.pop_front()
			for seg in b.trail:
				seg.life -= dt * 0.25
		"supernova":
			# dial: charge 6s → 12s
			b.press_v = maxf(0.0, b.press_v - dt * 1.1)
			if b.nova <= 0.0:
				b.charge += dt / 12.0
				if b.charge >= 1.0:
					b.nova = 1.0
					b.ring = 4.0
					b.charge = 0.0
			else:
				b.ring += 70.0 * dt
				b.nova = maxf(0.0, b.nova - dt * 0.9)
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	var c := r.get_center()
	match b.id:
		"breath":
			# dials: sleep 1.1 → jog 2.4 · indigo → ember
			var breath := 0.5 + 0.5 * sin(t * 2.4)
			ElemKit.glow(n, c, r.size.y * (0.8 + breath * 0.35) + pv * 24.0,
				Color(1, 0.63, 0.35, 0.28 + breath * 0.18 + pv * 0.4), 4)
			ElemKit.face(n, r, Color(0.125, 0.063, 0.04, 0.88), Color(1, 0.75, 0.5, 0.4 + breath * 0.3 + pv * 0.3))
			ElemKit.label(n, r, "PANT", Color(1, 0.92, 0.85))
		"heartbeat":
			# dials: rate ÷2 · the dub deleted — just the lub
			var rate: float = 0.5 + b.startle * 0.7
			var cyc := fmod(t * rate, 1.2)
			var beat: float = exp(-pow((cyc - 0.12) * 14.0, 2.0))
			ElemKit.glow(n, c, r.size.y * 0.9, Color(0.55, 0.78, 1.0, 0.12 + beat * 0.45), 4)
			var s := 1.0 + beat * 0.02
			n.draw_set_transform(c, 0.0, Vector2(s, s))
			ElemKit.face(n, Rect2(-r.size / 2.0, r.size), Color(0.055, 0.086, 0.118, 0.9),
				Color(0.63, 0.82, 1.0, 0.4 + beat * 0.5))
			ElemKit.label(n, Rect2(-r.size / 2.0, r.size), "RESTING", Color(0.88, 0.94, 1.0))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"halo_orbit":
			# dials: one bead → two, second orbit reversed
			ElemKit.face(n, r, Color(0.07, 0.063, 0.118, 0.92), Color(0.78, 0.75, 1.0, 0.4))
			ElemKit.label(n, r, "BINARY", Color(0.92, 0.89, 1.0))
			for k in 2:
				var sign_a := 1.0 if k == 0 else -1.0
				var a: float = t * 2.0 * sign_a + k * PI
				if b.split > 0.0:
					a += sign_a * b.split * 2.0
				var pos := c + Vector2(cos(a) * r.size.x * 0.55, sin(a) * r.size.y * 0.85)
				var col := Color(1, 0.98, 0.86, 0.9) if k == 0 else Color(0.75, 0.85, 1.0, 0.9)
				ElemKit.glow(n, pos, 7.0, col, 3)
				ElemKit.ellipse(n, c, r.size.x * 0.55, r.size.y * 0.85,
					Color(col.r, col.g, col.b, 0.45), 1.6, a - sign_a * 0.7, a, 8)
		"lens_flare":
			# dial: every ghost gets its own hue
			ElemKit.face(n, r, Color(0.063, 0.063, 0.11, 0.92), Color(0.7, 0.78, 0.92, 0.45))
			ElemKit.label(n, r, "SPECTRUM", Color(0.89, 0.92, 0.97))
			var p := fmod(t * 0.18, 1.4) - 0.2
			var f := o + Vector2(r.size.x * p, r.size.y * (0.2 + p * 0.5))
			var ghosts := [1.0, 0.5, -0.4, -0.9]
			for gi in ghosts.size():
				var s: float = ghosts[gi]
				var g: Vector2 = f + (c - f) * (1.0 - s)
				var col := Color.from_hsv(gi * 0.22, 0.75, 1.0, 0.24 * absf(s))
				ElemKit.glow(n, g, 7.0 * absf(s) + 3.0, col, 3)
			n.draw_line(f - Vector2(22, 0), f + Vector2(22, 0), Color(0.9, 0.82, 1.0, 0.35), 1.5)
			if b.big > 0.0:
				var bp: Vector2 = o + b.bp
				n.draw_line(bp - Vector2(70.0 * (1.2 - b.big), 0), bp + Vector2(70.0 * (1.2 - b.big), 0),
					Color(0.86, 0.63, 1.0, b.big * 0.9), 2.5)
				ElemKit.glow(n, bp, 22.0, Color(0.94, 0.88, 1.0, b.big * 0.8), 4)
		"lighthouse":
			# dial: one beam → two in opposition
			var bright: float = 0.35 if b.hold > 0.0 else 0.18
			for half in 2:
				var base_a: float = b.a + half * PI
				var poly := PackedVector2Array()
				poly.append(c)
				for i in 9:
					var a: float = base_a - 0.22 + 0.44 * i / 8.0
					poly.append(c + Vector2(cos(a), sin(a)) * r.size.x * 0.9)
				n.draw_colored_polygon(poly, Color(1, 0.94, 0.75, bright) if half == 0
					else Color(0.75, 0.88, 1.0, bright))
			ElemKit.face(n, r, Color(0.078, 0.07, 0.118, 0.9), Color(1, 0.92, 0.75, 0.4 + (0.4 if b.hold > 0.0 else 0.0)))
			ElemKit.label(n, r, "SEARCH", Color(1, 0.95, 0.84))
		"firefly_jar":
			# dials: firefly green-gold → plankton cyan (clock dial in init)
			ElemKit.face(n, r, Color(0.031, 0.07, 0.086, 0.96), Color(0.47, 0.86, 0.9, 0.5))
			for f in b.flies:
				var blink: float = pow(maxf(0.0, sin(t * f.sp * 2.0 + f.ph)), 2.0)
				blink = maxf(blink, b.sync)
				if blink > 0.03:
					ElemKit.glow(n, o + f.pos, 6.0, Color(0.55, 0.96, 1.0, blink * 0.85), 3)
			ElemKit.label(n, r, "TIDE JAR", Color(0.84, 0.97, 1.0, 0.85))
		"prism":
			# dial: saturation stripped — six silver bands
			ElemKit.face(n, r, Color(0.078, 0.078, 0.11, 0.96), Color(0.86, 0.86, 0.92, 0.5))
			n.draw_rect(Rect2(o + Vector2(0, r.size.y / 2.0 - 2), Vector2(12, 4)), Color(1, 1, 1, 0.5))
			for i in 6:
				var v := 0.55 + i * 0.07
				var spread := (i - 2.5) * (5.0 + sin(t * 0.45) * 1.4)
				n.draw_line(o + Vector2(12, r.size.y / 2.0), o + Vector2(r.size.x, r.size.y / 2.0 + spread),
					Color(v, v, minf(1.0, v + 0.08), 0.45), 3.0)
			if b.sweep >= 0.0:
				for i in 6:
					var x: float = o.x + r.size.x * b.sweep - i * 5.0
					if x > o.x and x < o.x + r.size.x - 4.0:
						var v := 0.6 + i * 0.06
						n.draw_rect(Rect2(x, o.y, 4, r.size.y), Color(v, v, minf(1.0, v + 0.08), 0.5))
			ElemKit.label(n, r, "MOONBEAM", Color(0.92, 0.92, 0.97))
		"spotlight":
			# dials: two roaming spots → one small candle pool, honest flicker
			ElemKit.face(n, r, Color(0.04, 0.031, 0.024, 0.97), Color(0.59, 0.47, 0.35, 0.4))
			var flick := 0.85 + sin(t * 9.0) * 0.08 + sin(t * 23.0) * 0.07
			var pool := c + Vector2(sin(t * 0.4) * r.size.x * 0.2, cos(t * 0.3) * r.size.y * 0.2)
			ElemKit.glow(n, pool, (15.0 + pv * 10.0) * flick, Color(1, 0.82, 0.51, 0.3 + pv * 0.2), 3)
			var near: float = maxf(0.08 + pv * 0.7, clampf(1.0 - pool.distance_to(c) / 30.0, 0.0, 1.0) * flick)
			ElemKit.label(n, r, "STUDY", Color(1, 0.92, 0.78, near))
		"glowworm":
			ElemKit.face(n, r, Color(0.047, 0.063, 0.094, 0.96), Color(0.55, 0.71, 0.94, 0.35))
			ElemKit.label(n, r, "PERIHELION", Color(0.86, 0.92, 1.0))
			for seg in b.trail:
				if seg.life > 0.0:
					n.draw_circle(o + seg.pos, 2.6, Color(0.63, 0.82, 1.0, seg.life * 0.3))
			var a: float = b.p * TAU
			ElemKit.glow(n, c + Vector2(cos(a) * r.size.x * 0.52, sin(a) * r.size.y * 0.62),
				7.0, Color(0.86, 0.94, 1.0, 0.95), 3)
		"supernova":
			# dial: the voice lowered — every alpha eased (patience dial in tick)
			var core_r: float = 6.0 + b.charge * 16.0 + b.nova * 26.0
			ElemKit.glow(n, c, core_r, Color(1, 0.98, 0.9, minf(1.0, 0.18 + b.charge * 0.4 + b.nova * 0.15)), 4)
			if b.nova > 0.0:
				ElemKit.ellipse(n, c, b.ring * 1.5, b.ring * 0.85, Color(1, 0.92, 0.75, b.nova * 0.5), 1.6)
				for i in 8:
					var th := i / 8.0 * TAU + 0.4
					n.draw_line(c + Vector2(cos(th) * core_r * 0.8, sin(th) * core_r * 0.5),
						c + Vector2(cos(th) * (core_r + b.ring), sin(th) * (core_r + b.ring) * 0.6),
						Color(1, 0.86, 0.59, b.nova * 0.35), 1.2)
			ElemKit.face(n, r, Color(0.094, 0.07, 0.118, 0.82), Color(1, 0.86, 0.67, 0.3 + b.charge * 0.4))
			ElemKit.label(n, r, "SOON" if b.nova <= 0.0 else "AT LAST", Color(1, 0.94, 0.85, 0.9))
		_:
			Base.draw(n, b, t)
