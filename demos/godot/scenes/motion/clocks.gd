extends RefCounted

const Kit := preload("res://scenes/motion/kit.gd")
## CLOCKS & CIRCLES — five movement styles, ported from the web lexicon
## (docs/locomotion.js). Motion with NO memory: every frame, position is
## computed straight from the clock, so nothing is stored and nothing can
## drift. Hovering pickups, orbits, figure-eight patrols, swimming snakes.

const TITLE := "Clocks & circles"
const BLURB := "pure position formulas — sine, polar, phase: motion with no memory"
const DEFS := [
	{ "id": "hover", "name": "H · Hover", "hint": "y = sin(t) is a whole idle animation — press to excite it" },
	{ "id": "orbit", "name": "O · Orbit", "hint": "polar coordinates: one angle + one radius = a flight plan — press to reverse" },
	{ "id": "eight", "name": "E · Eight", "hint": "two sines at different speeds trace a figure eight — press for a new ratio" },
	{ "id": "undulate", "name": "U · Undulate", "hint": "one sine, sixteen joints, phase-shifted — a swimmer — press for a burst" },
	{ "id": "pendulum", "name": "P · Pendulum", "hint": "real swing vs the small-angle shortcut — press to lift both to your click" },
]

const RATIOS := [[1, 2], [3, 2], [3, 4], [2, 1]]

static func init(b: Dictionary) -> void:
	match b.id:
		"hover":
			b.excite = 0.0
		"orbit":
			b.th = 0.0
			b.mth = 0.0
			b.dir = 1.0
		"eight":
			b.ri = 0
			b.trail = []
		"undulate":
			b.hx = b.w * 0.3
			b.boost = 0.0
		"pendulum":
			b.th = 1.15
			b.om = 0.0
			b.gth = 1.15
			b.gom = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"hover":
			b.excite = 1.0
		"orbit":
			b.dir = -b.dir
		"eight":
			b.ri = (b.ri + 1) % RATIOS.size()
			b.trail = []
		"undulate":
			b.boost = 1.0
		"pendulum":
			var piv := Vector2(b.w / 2.0, b.h * 0.14)
			b.th = atan2(pos.x - piv.x, pos.y - piv.y)   # angle from "straight down"
			b.om = 0.0
			b.gth = b.th                                 # lift both bobs there, let go
			b.gom = 0.0

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"hover":
			b.excite = maxf(0.0, b.excite - dt * 0.45)
		"orbit":
			b.th += dt * 1.1 * b.dir
			b.mth += dt * 4.6 * b.dir                    # the moon runs its own, faster clock
		"eight":
			var a: int = RATIOS[b.ri][0]
			var bb: int = RATIOS[b.ri][1]
			var T := t * 1.3
			var c := Vector2(b.w / 2.0, b.h * 0.5)
			b.trail.append(c + Vector2(cos(a * T) * b.w * 0.33, sin(bb * T) * b.h * 0.3))
			if b.trail.size() > 60:
				b.trail.pop_front()
		"undulate":
			b.boost = maxf(0.0, b.boost - dt * 0.55)
			b.hx += dt * (26.0 + b.boost * 130.0)        # the burst is real thrust
			if b.hx - 16 * 11.0 > b.w + 20.0:
				b.hx = -20.0                             # swim off, swim back on
		"pendulum":
			b.om += (-7.5 * sin(b.th) - 0.02 * b.om) * dt   # the true equation
			b.th += b.om * dt
			b.gom += (-7.5 * b.gth - 0.02 * b.gom) * dt     # the shortcut: sin(θ) → θ
			b.gth += b.gom * dt

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	Kit.stage(n, b)
	match b.id:
		"hover":
			Kit.ground(n, b)
			# the whole behaviour is ONE line of maths: y = rest + sin(t·2π/period)·amp
			var amp: float = b.h * 0.075 * (1.0 + b.excite * 1.5)
			var w: float = TAU / (2.8 * (1.0 - b.excite * 0.4))   # excited = faster AND higher
			var rest: float = b.gy - b.h * 0.32
			var y := rest + sin(t * w) * amp
			var tilt := cos(t * w) * 0.16                    # the derivative leans the body
			var alt: float = (b.gy - y) / (b.gy - rest + amp)
			n.draw_set_transform(Vector2((b.rect as Rect2).position.x + b.w / 2.0,
				(b.rect as Rect2).position.y + b.gy - 3.0), 0.0, Vector2(1.3 - alt * 0.55, 0.27))
			n.draw_circle(Vector2.ZERO, 15.0, Color(0, 0, 0, 0.4))   # the altitude shadow
			n.draw_set_transform((b.rect as Rect2).position, 0.0, Vector2.ONE)
			Kit.mote(n, b, Vector2(b.w / 2.0, y), tilt)
			Kit.label(n, b, "y = rest + sin(t · 2π/2.8) · amp", Vector2(b.w / 2.0, b.gy + 16.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"orbit":
			var c := Vector2(b.w / 2.0, b.h * 0.52)
			var r: float = minf(b.w, b.h) * 0.3 + sin(t * 0.7) * 6.0   # r can breathe too
			var p := c + Vector2(cos(b.th), sin(b.th)) * r   # ← polar → Cartesian, the whole trick
			Kit.ring(n, c, r, Color(0.91, 0.898, 0.957, 0.10))
			Kit.dot(n, c, 7.0, Kit.TARGET)
			n.draw_line(c, p, Kit.DIM, 1.0)
			n.draw_arc(c, 16.0, 0.0, b.th, 24, Color(0.961, 0.757, 0.412, 0.7), 1.0)  # θ as an arc
			Kit.label(n, b, "θ", c + Vector2(24, -6), Color(0.961, 0.757, 0.412, 0.8))
			Kit.label(n, b, "r", c + (p - c) * 0.55 + Vector2(6, 0))
			Kit.mote(n, b, p, b.th + b.dir * PI / 2.0)       # heading = tangent to the circle
			Kit.dot(n, p + Vector2(cos(b.mth), sin(b.mth)) * 19.0, 3.5, Kit.GOOD)
			Kit.label(n, b, "x = cos(θ)·r   y = sin(θ)·r", Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"eight":
			var a: int = RATIOS[b.ri][0]
			var bb: int = RATIOS[b.ri][1]
			var c := Vector2(b.w / 2.0, b.h * 0.5)
			var rx: float = b.w * 0.33
			var ry: float = b.h * 0.3
			var path := PackedVector2Array()                 # the whole path, previewed
			for i in 129:
				var s := (i / 128.0) * TAU
				path.append(c + Vector2(cos(a * s) * rx, sin(bb * s) * ry))
			n.draw_polyline(path, Color(0.91, 0.898, 0.957, 0.12), 1.0)
			var T := t * 1.3
			var p := c + Vector2(cos(a * T) * rx, sin(bb * T) * ry)
			var v := Vector2(-sin(a * T) * a * rx, cos(bb * T) * bb * ry) * 1.3   # the derivative
			for i in b.trail.size():
				Kit.dot(n, b.trail[i], 1.6, Color(0.541, 0.851, 0.961, i / float(b.trail.size()) * 0.35))
			Kit.arrow(n, p, p + v * 0.22, Kit.GOOD)
			Kit.mote(n, b, p, v.angle())
			Kit.label(n, b, "x = cos(%dt)   y = sin(%dt)" % [a, bb], Vector2(b.w / 2.0, 16.0), Kit.INK * Color(1, 1, 1, 0.55), true)
			Kit.label(n, b, "the arrow is the derivative (velocity)", Vector2(b.w / 2.0, b.h - 8.0), Color(0.608, 0.886, 0.541, 0.6), true)
		"undulate":
			var freq: float = 4.2 * (1.0 + b.boost * 0.9)
			var amp: float = b.h * 0.07 * (1.0 + b.boost * 0.6)
			var mid: float = b.h * 0.45
			for i in range(15, -1, -1):                      # tail first, head on top
				var x: float = b.hx - i * 11.0
				var grow := 0.35 + (i / 16.0) * 0.9          # the wave grows toward the tail
				var y := mid + sin(t * freq - i * 0.62) * amp * grow
				var rr: float = maxf(2.0, 8.0 - i * 0.36)
				var col := Kit.MOVER if i == 0 else Color(0.541, 0.851, 0.961, 0.75 - i * 0.035)
				Kit.dot(n, Vector2(x, y), rr, col)
				if i == 0:                                   # the head gets the eye
					Kit.dot(n, Vector2(x + 3.0, y - 2.5), 1.8, Kit.NIGHT)
			Kit.label(n, b, "segment i:  y = sin(t·f − i·0.62) · amp", Vector2(b.w / 2.0, b.h - 8.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"pendulum":
			var piv := Vector2(b.w / 2.0, b.h * 0.14)
			var L: float = b.h * 0.56
			var bob := piv + Vector2(sin(b.th), cos(b.th)) * L
			var gb := piv + Vector2(sin(b.gth), cos(b.gth)) * L
			n.draw_line(piv, gb, Kit.DIM, 1.0)
			Kit.ring(n, gb, 8.0, Kit.DIM, 1.5)
			n.draw_line(piv, bob, Kit.BONE, 2.0)
			Kit.dot(n, piv, 3.0, Kit.BONE)
			Kit.dot(n, bob, 9.0, Kit.MOVER)
			Kit.label(n, b, "α = −(g/L)·sin θ", bob + Vector2(14, 0), Color(0.541, 0.851, 0.961, 0.75))
			Kit.label(n, b, "sin θ ≈ θ (the ghost)", gb + Vector2(12, -10), Kit.DIM)
