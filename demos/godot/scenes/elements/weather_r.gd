extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
const Base := preload("res://scenes/elements/weather.gd")
## WEATHER — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"monsoon": { "name": "Spring shower", "hint": "the kindness setting — soft rain, warm light, no thunder" },
	"dust_devil": { "name": "Leaf devil", "hint": "the dashes become spinning foliage" },
	"rainbow": { "name": "Moonbow", "hint": "the arcs by night — silver, rain slowed" },
	"tempest": { "name": "Doldrums", "hint": "inverted — dead calm idle, a brief squall on press" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)
	match b.id:
		"monsoon":
			for d in b.rain:            # the ÷3 rain dial
				d.v *= 0.35
		"rainbow":
			for d in b.rain:            # slower night rain
				d.v *= 0.5
		"dust_devil":
			b.leaves = []
			for i in 10:
				b.leaves.append(randf_range(0, TAU))

static func press(b: Dictionary, pos: Vector2) -> void:
	Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"monsoon":
			# dial: slant removed — spring rain falls straight
			b.press_v = maxf(0.0, b.press_v - dt * 1.8)
			for d in b.rain:
				d.pos += Vector2(-d.v * 0.05, d.v) * dt
				if d.pos.y > r.size.y + 8.0:
					d.pos = Vector2(randf_range(0, r.size.x + 8), -6.0)
		"dust_devil":
			b.press_v = maxf(0.0, b.press_v - dt * 1.8)
			for i in b.leaves.size():   # floats are copies — write back by index
				b.leaves[i] = fposmod(b.leaves[i] + (5.0 + b.press_v * 4.0) * dt, TAU)
		"tempest":
			# dial: the storm scale runs off press_v directly (calm at rest)
			b.press_v = maxf(0.0, b.press_v - dt * 0.45)
			var storm: float = b.press_v
			for d in b.rain:
				d.pos += Vector2(-d.v * 0.4 * storm, d.v * storm + 4.0) * dt
				if d.pos.y > r.size.y + 8.0:
					d.pos = Vector2(randf_range(0, r.size.x + 28), -6.0)
			for s in b.streaks:
				s.pos.x -= s.v * storm * dt
				if s.pos.x < -12.0:
					s.pos = Vector2(r.size.x + 12, randf_range(-10, r.size.y + 6))
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	var c := r.get_center()
	match b.id:
		"monsoon":
			# dials: thunder deleted · palette warmed · no shake
			ElemKit.face(n, r, Color(0.1, 0.094, 0.063, 0.94), Color(0.9, 0.82, 0.59, 0.45 + pv * 0.3))
			ElemKit.label(n, r, "APRIL", Color(0.96, 0.92, 0.8))
			if pv > 0.0:                # the press brings sunshine, not a clap
				ElemKit.glow(n, Vector2(c.x, o.y - 6.0), 18.0, Color(1, 0.9, 0.59, pv * 0.4), 3)
			for d in b.rain:
				n.draw_line(o + d.pos, o + d.pos + Vector2(0.4, -6), Color(0.75, 0.82, 0.78, 0.45), 1.0)
		"dust_devil":
			# dial: dust dashes → whole leaves, spinning
			ElemKit.face(n, r, Color(0.063, 0.094, 0.055, 0.92), Color(0.63, 0.82, 0.47, 0.5))
			var wobble: float = pv * sin(t * 25.0) * 1.5
			ElemKit.label(n, Rect2(r.position + Vector2(wobble, 0), r.size), "LEAF PILE", Color(0.89, 0.95, 0.8))
			var dx: float = c.x if pv > 0.2 else o.x + fmod(t * 30.0, r.size.x + 60.0) - 30.0
			var size := 1.0 + pv * 2.2
			var leaves: Array = b.leaves
			for i in leaves.size():
				var k := i / float(leaves.size() - 1)
				var y := o.y + r.size.y - 4.0 - k * (r.size.y + 16.0)
				var rad := (3.0 + k * 8.0) * size
				var a: float = leaves[i] + t * 4.0 - k * 2.0
				var pos := Vector2(dx + cos(a) * rad + sin(t * 4.0 + k * 5.0) * 2.0, y + sin(a) * rad * 0.28)
				n.draw_set_transform(pos, a * 2.0, Vector2(1.0, 0.5))
				n.draw_circle(Vector2.ZERO, 2.8,
					[Color(0.55, 0.78, 0.39), Color(0.86, 0.71, 0.31), Color(0.78, 0.47, 0.27)][i % 3])
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"rainbow":
			# dials: saturation stripped to silver · rain slowed (in init)
			ElemKit.face(n, r, Color(0.055, 0.055, 0.086, 0.95), Color(0.71, 0.73, 0.82, 0.5))
			ElemKit.label(n, r, "MOONBOW", Color(0.89, 0.9, 0.95))
			for d in b.rain:
				n.draw_line(o + d.pos, o + d.pos + Vector2(0.3, -4), Color(0.63, 0.67, 0.78, 0.3), 1.0)
			var cyc := fmod(t, 8.0) / 8.0
			var sched: float = maxf(0.0, sin(cyc * PI) - 0.6) * 2.5
			var vis: float = maxf(sched, b.show)
			if vis > 0.02:
				var arcs: int = 2 if b.dbl > 0.0 else 1
				for arc in arcs:
					for i in 7:
						var rad: float = r.size.x * (0.42 + arc * 0.16) + i * 2.6
						var a: float = (vis * b.dbl * 0.3) if arc == 1 else (vis * 0.45)
						var v := 0.6 + i * 0.05
						ElemKit.ellipse(n, Vector2(c.x, o.y + r.size.y + 10), rad, rad,
							Color(v, v, minf(1.0, v + 0.06), a), 2.4, PI + 0.35, TAU - 0.35, 20)
		"tempest":
			# dial: the anatomy inverted — calm face at rest, squall on press
			var storm: float = pv
			if randf() < 0.02 * storm:
				n.draw_rect(r.grow(6.0), Color(0.75, 0.78, 0.92, 0.2))
			for s in b.streaks:
				n.draw_line(o + s.pos, o + s.pos + Vector2(12, -1), Color(0.67, 0.75, 0.84, 0.3 * storm), 1.0)
			for d in b.rain:
				n.draw_line(o + d.pos, o + d.pos + Vector2(3, -8), Color(0.59, 0.7, 0.84, 0.45 * storm), 1.0)
			var lean: float = sin(t * 11.0) * 1.2 * storm
			var rr := Rect2(r.position + Vector2(lean, 0), r.size)
			ElemKit.face(n, rr, Color(0.07, 0.082, 0.1, 0.96), Color(0.7, 0.8, 0.86, 0.45 + storm * 0.4))
			ElemKit.label(n, rr, "SQUALL" if storm > 0.4 else "DOLDRUMS", Color(0.89, 0.93, 0.95))
		_:
			Base.draw(n, b, t)
