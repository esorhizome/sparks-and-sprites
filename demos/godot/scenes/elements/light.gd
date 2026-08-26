extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
## LIGHT & GLOW — ten buttons, ported from the web bestiary.

const TITLE := "Light & glow"
const BLURB := "breath, heartbeat, halo, and the lighthouse sweep"
const DEFS := [
	{ "id": "breath", "name": "Breath", "hint": "the classic: glow expands, then dims, forever; press to bloom" },
	{ "id": "heartbeat", "name": "Heartbeat", "hint": "lub-dub from within; press to startle it" },
	{ "id": "halo_orbit", "name": "Halo orbit", "hint": "a bright bead rides the border; press and it splits into three" },
	{ "id": "lens_flare", "name": "Lens flare", "hint": "a flare drifts across on schedule; press for the full anamorphic" },
	{ "id": "lighthouse", "name": "Lighthouse", "hint": "the beam sweeps round and round; press to aim it at your click" },
	{ "id": "firefly_jar", "name": "Firefly jar", "hint": "fireflies blink on their own clocks; press to sync them once" },
	{ "id": "prism", "name": "Prism", "hint": "white light splits into drifting rainbow bands; press to sweep" },
	{ "id": "spotlight", "name": "Spotlight", "hint": "roaming lights reveal the caption; press for house lights" },
	{ "id": "glowworm", "name": "Glowworm", "hint": "a worm of light inches along the border; press and it sprints a lap" },
	{ "id": "supernova", "name": "Supernova", "hint": "it charges for six slow seconds, then releases; press to detonate now" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	match b.id:
		"heartbeat":
			b.startle = 0.0
		"halo_orbit":
			b.split = 0.0
		"lens_flare":
			b.big = 0.0
			b.bp = Vector2.ZERO
		"lighthouse":
			b.a = 0.0
			b.aim = 0.0
			b.hold = 0.0
		"firefly_jar":
			b.flies = []
			var r: Rect2 = b.rect
			for i in 10:
				b.flies.append({ "pos": Vector2(randf_range(8, r.size.x - 8), randf_range(6, r.size.y - 6)),
					"ph": randf_range(0, TAU), "sp": randf_range(0.7, 1.4), "wx": randf_range(0, 9), "wy": randf_range(0, 9) })
			b.sync = 0.0
		"prism":
			b.sweep = -1.0
		"glowworm":
			b.p = 0.0
			b.sprint = 0.0
			b.trail = []
		"supernova":
			b.charge = 0.0
			b.nova = 0.0
			b.ring = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"breath", "spotlight":
			b.press_v = 1.0 if b.id == "breath" else 1.6
		"heartbeat":
			b.startle = 1.0
		"halo_orbit":
			b.split = 1.0
		"lens_flare":
			b.big = 1.0
			b.bp = pos
		"lighthouse":
			b.aim = (pos - b.rect.size / 2.0).angle()
			b.hold = 1.5
		"firefly_jar":
			b.sync = 1.0
		"prism":
			b.sweep = 0.0
		"glowworm":
			b.sprint = 1.0
		"supernova":
			b.nova = 1.0
			b.ring = 4.0
			b.charge = 0.0

static func tick(b: Dictionary, dt: float, t: float) -> void:
	b.press_v = maxf(0.0, b.press_v - dt * 1.1)
	var r: Rect2 = b.rect
	match b.id:
		"heartbeat":
			b.startle = maxf(0.0, b.startle - dt * 0.35)
		"halo_orbit":
			b.split = maxf(0.0, b.split - dt * 0.25)
		"lens_flare":
			b.big = maxf(0.0, b.big - dt * 1.6)
		"lighthouse":
			b.hold = maxf(0.0, b.hold - dt)
			if b.hold > 0.0:
				var d: float = fposmod(b.aim - b.a + PI, TAU) - PI
				b.a += d * minf(1.0, dt * 8.0)
			else:
				b.a += dt * 1.5
		"firefly_jar":
			b.sync = maxf(0.0, b.sync - dt * 1.5)
			for f in b.flies:
				f.pos.x += sin(t * 0.7 + f.wx) * 6.0 * dt
				f.pos.y += cos(t * 0.9 + f.wy) * 5.0 * dt
		"prism":
			if b.sweep >= 0.0:
				b.sweep += dt * 1.8
				if b.sweep > 1.3:
					b.sweep = -1.0
		"glowworm":
			b.sprint = maxf(0.0, b.sprint - dt * 0.45)
			b.p += dt * (0.25 + b.sprint * 1.6)
			var a: float = b.p * TAU
			b.trail.append({ "pos": r.size / 2.0 + Vector2(cos(a) * r.size.x * 0.52, sin(a) * r.size.y * 0.62), "life": 1.0 })
			if b.trail.size() > 36:
				b.trail.pop_front()
			for seg in b.trail:
				seg.life -= dt * 0.5
		"supernova":
			if b.nova <= 0.0:
				b.charge += dt / 6.0
				if b.charge >= 1.0:
					b.nova = 1.0
					b.ring = 4.0
					b.charge = 0.0
			else:
				b.ring += 70.0 * dt
				b.nova = maxf(0.0, b.nova - dt * 0.9)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	var c := r.get_center()
	match b.id:
		"breath":
			var breath := 0.5 + 0.5 * sin(t * 1.1)
			ElemKit.glow(n, c, r.size.y * (0.8 + breath * 0.35) + pv * 24.0,
				Color(0.59, 0.63, 1.0, 0.28 + breath * 0.18 + pv * 0.4), 4)
			ElemKit.face(n, r, Color(0.07, 0.055, 0.125, 0.88), Color(0.7, 0.75, 1.0, 0.4 + breath * 0.3 + pv * 0.3))
			ElemKit.label(n, r, "BREATHE", Color(0.9, 0.91, 1.0))
		"heartbeat":
			var rate: float = 1.0 + b.startle * 1.4
			var cyc := fmod(t * rate, 1.2)
			var beat: float = exp(-pow((cyc - 0.12) * 14.0, 2.0)) + exp(-pow((cyc - 0.38) * 14.0, 2.0)) * 0.7
			ElemKit.glow(n, c, r.size.y * 0.9, Color(1, 0.43, 0.55, 0.12 + beat * 0.5), 4)
			var s := 1.0 + beat * 0.03
			n.draw_set_transform(c, 0.0, Vector2(s, s))
			ElemKit.face(n, Rect2(-r.size / 2.0, r.size), Color(0.118, 0.055, 0.086, 0.9),
				Color(1, 0.59, 0.67, 0.4 + beat * 0.5))
			ElemKit.label(n, Rect2(-r.size / 2.0, r.size), "ALIVE", Color(1, 0.87, 0.9))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"halo_orbit":
			ElemKit.face(n, r, Color(0.07, 0.063, 0.118, 0.92), Color(0.78, 0.75, 1.0, 0.4))
			ElemKit.label(n, r, "SAINT", Color(0.92, 0.89, 1.0))
			var count := 3 if b.split > 0.0 else 1
			for k in count:
				var a: float = t * 2.0 + k * (TAU / 3.0) * minf(1.0, b.split * 2.0)
				var pos := c + Vector2(cos(a) * r.size.x * 0.55, sin(a) * r.size.y * 0.85)
				ElemKit.glow(n, pos, 8.0, Color(1, 0.98, 0.86, 0.9), 3)
				ElemKit.ellipse(n, c, r.size.x * 0.55, r.size.y * 0.85,
					Color(1, 0.92, 0.7, 0.5), 2.0, a - 0.7, a, 8)
		"lens_flare":
			ElemKit.face(n, r, Color(0.063, 0.063, 0.11, 0.92), Color(0.7, 0.78, 0.92, 0.45))
			ElemKit.label(n, r, "CINEMA", Color(0.89, 0.92, 0.97))
			var p := fmod(t * 0.18, 1.4) - 0.2
			var f := o + Vector2(r.size.x * p, r.size.y * (0.2 + p * 0.5))
			for s in [1.0, 0.5, -0.4, -0.9]:      # ghosts along the lens axis
				var g: Vector2 = f + (c - f) * (1.0 - s)
				ElemKit.glow(n, g, 7.0 * absf(s) + 3.0, Color(0.7, 0.82, 1.0, 0.22 * absf(s)), 3)
			n.draw_line(f - Vector2(22, 0), f + Vector2(22, 0), Color(0.78, 0.88, 1.0, 0.35), 1.5)
			if b.big > 0.0:
				var bp: Vector2 = o + b.bp
				n.draw_line(bp - Vector2(70.0 * (1.2 - b.big), 0), bp + Vector2(70.0 * (1.2 - b.big), 0),
					Color(0.63, 0.78, 1.0, b.big * 0.9), 2.5)
				ElemKit.glow(n, bp, 22.0, Color(0.9, 0.94, 1.0, b.big * 0.8), 4)
		"lighthouse":
			var bright: float = 0.4 if b.hold > 0.0 else 0.22
			var poly := PackedVector2Array()
			poly.append(c)
			for i in 9:
				var a: float = b.a - 0.22 + 0.44 * i / 8.0
				poly.append(c + Vector2(cos(a), sin(a)) * r.size.x * 0.9)
			n.draw_colored_polygon(poly, Color(1, 0.94, 0.75, bright))
			ElemKit.face(n, r, Color(0.078, 0.07, 0.118, 0.9), Color(1, 0.92, 0.75, 0.4 + (0.4 if b.hold > 0.0 else 0.0)))
			ElemKit.label(n, r, "KEEPER", Color(1, 0.95, 0.84))
		"firefly_jar":
			ElemKit.face(n, r, Color(0.055, 0.078, 0.063, 0.96), Color(0.75, 0.9, 0.63, 0.5))
			for f in b.flies:
				var blink: float = pow(maxf(0.0, sin(t * f.sp * 2.0 + f.ph)), 3.0)
				blink = maxf(blink, b.sync)
				if blink > 0.03:
					ElemKit.glow(n, o + f.pos, 5.0, Color(0.86, 1.0, 0.55, blink * 0.9), 3)
			ElemKit.label(n, r, "JAR", Color(0.9, 0.98, 0.82, 0.85))
		"prism":
			ElemKit.face(n, r, Color(0.078, 0.078, 0.11, 0.96), Color(0.86, 0.86, 0.92, 0.5))
			n.draw_rect(Rect2(o + Vector2(0, r.size.y / 2.0 - 2), Vector2(12, 4)), Color(1, 1, 1, 0.5))
			for i in 6:                      # six bands fanning out
				var hue := fmod(i * 52.0 / 360.0 + sin(t * 0.7) * 0.04 + 1.0, 1.0)
				var spread := (i - 2.5) * (5.0 + sin(t * 0.9) * 1.4)
				n.draw_line(o + Vector2(12, r.size.y / 2.0), o + Vector2(r.size.x, r.size.y / 2.0 + spread),
					Color.from_hsv(hue, 0.9, 0.95, 0.5), 3.0)
			if b.sweep >= 0.0:
				for i in 6:
					var x: float = o.x + r.size.x * b.sweep - i * 5.0
					if x > o.x and x < o.x + r.size.x - 4.0:
						n.draw_rect(Rect2(x, o.y, 4, r.size.y), Color.from_hsv(i * 52.0 / 360.0, 0.9, 0.95, 0.5))
			ElemKit.label(n, r, "REFRACT", Color(0.94, 0.94, 0.98))
		"spotlight":
			ElemKit.face(n, r, Color(0.031, 0.031, 0.055, 0.97), Color(0.47, 0.47, 0.59, 0.4))
			var house: float = pv
			var spots := [
				c + Vector2(sin(t * 0.9) * r.size.x * 0.3, cos(t * 0.7) * r.size.y * 0.3),
				c + Vector2(sin(t * 0.6 + 3.0) * r.size.x * 0.35, cos(t * 1.1 + 1.0) * r.size.y * 0.25)]
			for s in spots:
				ElemKit.glow(n, s, 22.0, Color(1, 0.96, 0.82, 0.2 + house * 0.15), 3)
			# the caption exists where light falls: alpha follows pool proximity
			var near := 0.06 + house * 0.8
			for s in spots:
				near = maxf(near, clampf(1.0 - s.distance_to(c) / 34.0, 0.0, 1.0))
			ElemKit.label(n, r, "ON STAGE", Color(0.96, 0.94, 0.85, near))
		"glowworm":
			ElemKit.face(n, r, Color(0.063, 0.078, 0.063, 0.96), Color(0.59, 0.78, 0.55, 0.35))
			ElemKit.label(n, r, "INCH", Color(0.88, 0.95, 0.86))
			for seg in b.trail:
				if seg.life > 0.0:
					n.draw_circle(o + seg.pos, 3.0, Color(0.75, 1.0, 0.59, seg.life * 0.3))
			var a: float = b.p * TAU
			ElemKit.glow(n, c + Vector2(cos(a) * r.size.x * 0.52, sin(a) * r.size.y * 0.62),
				7.0, Color(0.9, 1.0, 0.75, 0.95), 3)
		"supernova":
			var core_r: float = 6.0 + b.charge * 16.0 + b.nova * 26.0
			ElemKit.glow(n, c, core_r, Color(1, 0.98, 0.9, minf(1.0, 0.25 + b.charge * 0.55 + b.nova * 0.2)), 4)
			if b.nova > 0.0:
				ElemKit.ellipse(n, c, b.ring * 1.5, b.ring * 0.85, Color(1, 0.92, 0.75, b.nova * 0.8), 2.0)
				for i in 8:
					var th := i / 8.0 * TAU + 0.4
					n.draw_line(c + Vector2(cos(th) * core_r * 0.8, sin(th) * core_r * 0.5),
						c + Vector2(cos(th) * (core_r + b.ring), sin(th) * (core_r + b.ring) * 0.6),
						Color(1, 0.86, 0.59, b.nova * 0.6), 1.4)
			ElemKit.face(n, r, Color(0.094, 0.07, 0.118, 0.82), Color(1, 0.86, 0.67, 0.35 + b.charge * 0.5))
			ElemKit.label(n, r, "NOVA" if b.nova > 0.0 else "CHARGING", Color(1, 0.94, 0.85))
