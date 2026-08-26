extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
## WEATHER — four buttons, ported from the web bestiary.

const TITLE := "Weather"
const BLURB := "whole skies compressed into one button"
const DEFS := [
	{ "id": "monsoon", "name": "Monsoon", "hint": "slanted rain and mutter-lightning; press for the thunderclap" },
	{ "id": "dust_devil", "name": "Dust devil", "hint": "a whirl crosses the scene; press and it engulfs the button" },
	{ "id": "rainbow", "name": "Double rainbow", "hint": "light rain, and sometimes an arc; press for both at once" },
	{ "id": "tempest", "name": "Tempest", "hint": "wind, rain, and flicker all at once; press for the eye of the storm" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	var r: Rect2 = b.rect
	match b.id:
		"monsoon":
			b.rain = _drops(r, 26, 140.0, 220.0)
		"rainbow":
			b.rain = _drops(r, 12, 50.0, 90.0)
			b.show = 0.0
			b.dbl = 0.0
		"tempest":
			b.rain = _drops(r, 18, 150.0, 230.0)
			b.streaks = _drops(r, 6, 110.0, 190.0)

static func _drops(r: Rect2, count: int, v0: float, v1: float) -> Array:
	var out := []
	for i in count:
		out.append({ "pos": Vector2(randf_range(-10, r.size.x + 20), randf_range(-20, r.size.y + 10)),
			"v": randf_range(v0, v1) })
	return out

static func press(b: Dictionary, _pos: Vector2) -> void:
	b.press_v = 1.0
	if b.id == "rainbow":
		b.show = 1.0
		b.dbl = 1.0

static func tick(b: Dictionary, dt: float, t: float) -> void:
	b.press_v = maxf(0.0, b.press_v - dt * (0.3 if b.id == "rainbow" else (0.45 if b.id == "tempest" else 1.8)))
	var r: Rect2 = b.rect
	match b.id:
		"monsoon":
			for d in b.rain:
				d.pos += Vector2(-d.v * 0.35, d.v) * dt
				if d.pos.y > r.size.y + 8.0:
					d.pos = Vector2(randf_range(0, r.size.x + 24), -6.0)
		"rainbow":
			b.show = maxf(0.0, b.show - dt * 0.3)
			b.dbl = maxf(0.0, b.dbl - dt * 0.3)
			for d in b.rain:
				d.pos.y += d.v * (1.0 - b.dbl * 0.8) * dt
				if d.pos.y > r.size.y + 8.0:
					d.pos = Vector2(randf_range(0, r.size.x), -4.0)
		"tempest":
			var storm: float = 1.0 - b.press_v
			for d in b.rain:
				d.pos += Vector2(-d.v * 0.4 * storm, d.v * storm + 4.0) * dt
				if d.pos.y > r.size.y + 8.0:
					d.pos = Vector2(randf_range(0, r.size.x + 28), -6.0)
			for s in b.streaks:
				s.pos.x -= s.v * storm * dt
				if s.pos.x < -12.0:
					s.pos = Vector2(r.size.x + 12, randf_range(-10, r.size.y + 6))

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	var c := r.get_center()
	match b.id:
		"monsoon":
			if pv > 0.7 or (pv <= 0.0 and randf() < 0.006):     # sheet lightning
				n.draw_rect(r.grow(6.0), Color(0.78, 0.82, 0.94, (pv * 0.35) if pv > 0.0 else 0.18))
			var sh: float = pv * pv * 4.0
			var rr := Rect2(r.position + Vector2(randf_range(-sh, sh), randf_range(-sh, sh)), r.size)
			ElemKit.face(n, rr, Color(0.07, 0.078, 0.125, 0.96), Color(0.63, 0.7, 0.86, 0.45 + pv * 0.5))
			ElemKit.label(n, rr, "MONSOON", Color(0.87, 0.9, 0.96))
			for d in b.rain:
				n.draw_line(o + d.pos, o + d.pos + Vector2(2.5, -8), Color(0.63, 0.75, 0.9, 0.5), 1.0)
		"dust_devil":
			ElemKit.face(n, r, Color(0.1, 0.086, 0.063, 0.92), Color(0.78, 0.69, 0.51, 0.5))
			var wobble: float = pv * sin(t * 25.0) * 1.5
			ElemKit.label(n, Rect2(r.position + Vector2(wobble, 0), r.size), "DUST UP", Color(0.93, 0.88, 0.78))
			var dx: float = c.x if pv > 0.2 else o.x + fmod(t * 30.0, r.size.x + 60.0) - 30.0
			var size := 1.0 + pv * 2.2
			for i in 10:
				var k := i / 9.0
				var y := o.y + r.size.y - 4.0 - k * (r.size.y + 16.0)
				var rad := (3.0 + k * 8.0) * size
				var a := t * 9.0 - k * 2.0
				ElemKit.ellipse(n, Vector2(dx + sin(t * 4.0 + k * 5.0) * 2.0, y), rad, rad * 0.28,
					Color(0.82, 0.73, 0.55, 0.4 - k * 0.2 + pv * 0.2), 1.5, a, a + 3.6, 10)
		"rainbow":
			ElemKit.face(n, r, Color(0.078, 0.078, 0.118, 0.92), Color(0.78, 0.82, 0.92, 0.5))
			ElemKit.label(n, r, "LUCKY", Color(0.91, 0.93, 0.96))
			for d in b.rain:
				n.draw_line(o + d.pos, o + d.pos + Vector2(0.5, -5), Color(0.59, 0.7, 0.82, 0.35), 1.0)
			var cyc := fmod(t, 8.0) / 8.0
			var sched: float = maxf(0.0, sin(cyc * PI) - 0.6) * 2.5
			var vis: float = maxf(sched, b.show)
			if vis > 0.02:
				var hues := [0.0, 0.083, 0.15, 0.33, 0.58, 0.72, 0.79]
				var arcs: int = 2 if b.dbl > 0.0 else 1
				for arc in arcs:
					for i in 7:
						var rad: float = r.size.x * (0.42 + arc * 0.16) + i * 2.6
						var a: float = (vis * b.dbl * 0.35) if arc == 1 else (vis * 0.5)
						var hue_i: int = (6 - i) if arc == 1 else i
						ElemKit.ellipse(n, Vector2(c.x, o.y + r.size.y + 10), rad, rad,
							Color.from_hsv(hues[hue_i], 0.85, 0.9, a), 2.4, PI + 0.35, TAU - 0.35, 20)
		"tempest":
			var storm: float = 1.0 - pv
			if randf() < 0.008 * storm:
				n.draw_rect(r.grow(6.0), Color(0.75, 0.78, 0.92, 0.2))
			for s in b.streaks:
				n.draw_line(o + s.pos, o + s.pos + Vector2(12, -1), Color(0.67, 0.75, 0.84, 0.3 * storm), 1.0)
			for d in b.rain:
				n.draw_line(o + d.pos, o + d.pos + Vector2(3, -8), Color(0.59, 0.7, 0.84, 0.45 * storm), 1.0)
			var lean: float = sin(t * 11.0) * 1.2 * storm
			var rr := Rect2(r.position + Vector2(lean, 0), r.size)
			ElemKit.face(n, rr, Color(0.07, 0.078, 0.118, 0.96), Color(0.7, 0.78, 0.9, 0.45 + pv * 0.4))
			ElemKit.label(n, rr, "THE EYE" if pv > 0.4 else "TEMPEST", Color(0.89, 0.92, 0.96))
			if pv > 0.0:                     # the eerie calm ring
				ElemKit.ellipse(n, c, r.size.x * 0.62 + storm * 30.0, r.size.y * 0.95 + storm * 20.0,
					Color(0.86, 0.92, 1.0, pv * 0.35), 1.5)
