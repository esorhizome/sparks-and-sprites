extends Node2D
## THE ELEMENTAL BUTTON BESTIARY — a Godot sampler: one button per family.
## The web page holds all 104; porting every one would be a book of its own,
## so this scene ports one ambassador from each of the 14 element families,
## with the same two-species anatomy throughout: an idle loop that runs on
## its own + a press reaction. Click any button. Esc = menu. Chapter 12.
##
## Everything is drawn in _draw() from per-button state dictionaries —
## the Godot spelling of the web version's one-canvas-per-button approach.

const COLS := 5
const CELL := Vector2(188, 128)
const BTN := Vector2(150, 62)

var buttons: Array[Dictionary] = []
var t := 0.0

func _ready() -> void:
	var fams := [
		"fire", "lightning", "water", "metal", "ice",
		"earth", "air", "light", "sparks", "cosmic",
		"nature", "acid", "crystal", "weather",
	]
	var names := {
		"fire": "Candleflame", "lightning": "Static charge", "water": "Bubble tank",
		"metal": "Chrome sweep", "ice": "Frozen core", "earth": "Fault line",
		"air": "Smoke signal", "light": "Breath", "sparks": "Flint",
		"cosmic": "Galaxy", "nature": "Swarm", "acid": "Acid bath",
		"crystal": "Facet glint", "weather": "Monsoon",
	}
	var origin := Vector2(14, 60)
	for i in fams.size():
		var cell := origin + Vector2((i % COLS) * CELL.x, floorf(i / float(COLS)) * CELL.y)
		var rect := Rect2(cell + (Vector2(CELL.x, CELL.y - 22) - BTN) / 2.0, BTN)
		var b := { "fam": fams[i], "name": names[fams[i]], "rect": rect,
				   "press": 0.0, "seed": randf_range(0.0, 9.0), "parts": [] }
		match fams[i]:                    # per-family persistent state
			"water":
				for k in 7: b.parts.append({ "x": randf_range(8, BTN.x - 8), "y": randf_range(8, BTN.y - 8), "r": randf_range(2, 5), "ph": randf_range(0, 9) })
			"earth":
				var pts := [] ; var y := BTN.y * 0.5
				for x in range(0, int(BTN.x) + 12, 12):
					pts.append(Vector2(x, y)) ; y = clampf(y + randf_range(-7, 7), 8, BTN.y - 8)
				b.crack = pts
			"cosmic":
				var arm := []
				for k in 60:
					var d := k / 60.0
					arm.append({ "off": (k % 2) * PI + d * 3.4 + randf_range(-0.2, 0.2), "r": 6 + d * BTN.x * 0.52, "d": d })
				b.stars = arm ; b.spin = 1.0 ; b.a0 = 0.0
			"nature":
				for k in 14: b.parts.append({ "a": randf_range(0, TAU), "va": randf_range(0.8, 1.6), "panic": 0.0, "ph": randf_range(0, 9) })
			"crystal":
				var f := []
				for cx in 6:
					for h in 2:
						f.append({ "x": cx / 6.0, "ph": randf_range(0, 9), "top": h == 0 })
				b.facets = f
		buttons.append(b)
	var l := Label.new()
	l.text = "The elemental bestiary, Godot edition: 14 of the web page's 104 — one per family. Click them.  Esc = menu."
	l.position = Vector2(14, 16)
	add_child(l)

func _process(delta: float) -> void:
	t += delta
	for b in buttons:
		b.press = maxf(0.0, b.press - delta * (2.0 if b.fam != "nature" else 0.6))
		match b.fam:
			"water":
				for p in b.parts: p.y -= (4.0 + p.r) * delta * 3.0
				b.parts = b.parts.filter(func(p): return p.y > 4.0)
				while b.parts.size() < 7:
					b.parts.append({ "x": randf_range(8, BTN.x - 8), "y": BTN.y - 6.0, "r": randf_range(2, 5), "ph": randf_range(0, 9) })
			"air":
				if randf() < 0.02 + b.press * 0.2:
					b.parts.append({ "x": BTN.x / 2.0 + randf_range(-4, 4), "y": 0.0, "r": 4.0, "life": 1.0 })
				for p in b.parts:
					p.y -= 20.0 * delta ; p.r += 6.0 * delta ; p.life -= delta * 0.6
				b.parts = b.parts.filter(func(p): return p.life > 0.0)
			"sparks", "earth", "weather":
				for p in b.parts:
					p.pos += p.vel * delta ; p.vel.y += 260.0 * delta ; p.life -= delta * 1.6
				b.parts = b.parts.filter(func(p): return p.life > 0.0)
			"cosmic":
				b.spin += (1.0 - b.spin) * delta * 0.7
				b.a0 += b.spin * 0.4 * delta
			"nature":
				for p in b.parts:
					p.panic = maxf(0.0, p.panic - delta * 0.6)
					p.a += p.va * (1.0 + p.panic * 2.5) * delta
	queue_redraw()

func _face(r: Rect2, bg: Color, border: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.border_color = border
	sb.set_border_width_all(2)
	draw_style_box(sb, r)

func _label(b: Dictionary, text: String, col: Color) -> void:
	var r: Rect2 = b.rect
	draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.get_center().y + 5),
		text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, col)

func _draw() -> void:
	for b in buttons:
		var r: Rect2 = b.rect
		var o := r.position                 # button-local origin
		var pr: float = b.press
		match b.fam:
			"fire":
				_face(r, Color(0.12, 0.06, 0.055), Color(1, 0.63, 0.35, 0.5))
				_label(b, "IGNITE", Color(1, 0.85, 0.69))
				var x := o.x + 10.0
				while x < o.x + r.size.x - 6.0:
					var flick := sin(t * 9.0 + x) * 0.5 + sin(t * 23.0 + x * 3.0) * 0.5
					var h := (9.0 + flick * 3.0) * (1.0 + pr * 2.2)
					var y0 := o.y + r.size.y - 2.0
					draw_circle(Vector2(x, y0 - h * 0.4), 4.0, Color(1, 0.55, 0.18, 0.5))
					draw_circle(Vector2(x, y0 - h * 0.7), 2.4, Color(1, 0.86, 0.5, 0.75))
					x += 14.0
			"lightning":
				_face(r, Color(0.06, 0.07, 0.13), Color(0.55, 0.67, 1.0, 0.4 + pr * 0.6))
				_label(b, "CHARGE", Color(0.84, 0.88, 1.0))
				if randf() < 0.3:           # idle micro-crackle at a random edge point
					var p := Vector2(o.x + randf_range(0, r.size.x), o.y + (0.0 if randf() < 0.5 else r.size.y))
					for k in 3:
						var q := p + Vector2(randf_range(-6, 6), randf_range(-6, 6))
						draw_line(p, q, Color(0.7, 0.82, 1.0, 0.9), 1.0) ; p = q
				if pr > 0.0:                # the press bolt, jagged across the face
					var p := Vector2(o.x - 4, r.get_center().y)
					while p.x < o.x + r.size.x + 4:
						var q := Vector2(p.x + randf_range(10, 20), r.get_center().y + randf_range(-12, 12))
						draw_line(p, q, Color(0.86, 0.92, 1.0, pr), 2.5) ; p = q
			"water":
				_face(r, Color(0.04, 0.1, 0.16), Color(0.43, 0.75, 0.9, 0.5))
				_label(b, "AQUARIUM", Color(0.81, 0.94, 1.0))
				for p in b.parts:
					var pos := o + Vector2(p.x + sin(t * 2.0 + p.ph) * 3.0, p.y)
					draw_arc(pos, p.r, 0, TAU, 14, Color(0.67, 0.86, 0.98, 0.7), 1.0)
				if pr > 0.0:
					draw_arc(r.get_center(), (1.0 - pr) * 40.0 + 6.0, 0, TAU, 24, Color(0.86, 0.96, 1.0, pr), 1.5)
			"metal":
				var rows := 8
				for i in rows:              # banded steel, painted in strips
					var k := float(i) / rows
					var v := 0.16 + 0.14 * absf(sin(k * PI))
					draw_rect(Rect2(o.x, o.y + k * r.size.y, r.size.x, r.size.y / rows + 1), Color(v, v + 0.02, v + 0.05))
				var sx := o.x + fposmod(t * 60.0, r.size.x + 80.0) - 40.0
				draw_line(Vector2(sx, o.y), Vector2(sx + 14, o.y + r.size.y), Color(1, 1, 1, 0.45), 7.0)
				if pr > 0.0:
					var s2 := o.x + (1.0 - pr) * r.size.x
					draw_line(Vector2(s2, o.y), Vector2(s2 + 14, o.y + r.size.y), Color(1, 1, 1, pr), 10.0)
				_label(b, "CHROME", Color(0.91, 0.93, 0.96))
			"ice":
				_face(r, Color(0.08, 0.12, 0.19, 0.8), Color(0.67, 0.84, 0.98, 0.6))
				var pulse := 0.5 + 0.5 * sin(t * 1.4)
				for ring in 4:
					var k := 1.0 - ring / 4.0
					draw_circle(r.get_center(), (14 + ring * 8) * (0.8 + pulse * 0.3 + pr * 0.5),
						Color(0.75, 0.92, 1.0, 0.10 * k * (1.0 + pr)))
				if pr > 0.0:                # the ring of frost spikes
					for i in 10:
						var th := TAU * i / 10.0
						var dir := Vector2(cos(th) * 1.5, sin(th) * 0.8)
						draw_line(r.get_center() + dir * (14 + (1.0 - pr) * 30.0),
							r.get_center() + dir * (24 + (1.0 - pr) * 30.0), Color(0.86, 0.96, 1.0, pr), 1.6)
				_label(b, "CRYO", Color(0.87, 0.95, 1.0))
			"earth":
				var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * pr * pr * 5.0
				draw_set_transform(shake, 0.0, Vector2.ONE)
				_face(r, Color(0.14, 0.11, 0.09), Color(0.78, 0.67, 0.51, 0.5))
				var glow := 0.45 + 0.3 * sin(t * 1.8) + pr * 0.5
				for i in range(b.crack.size() - 1):
					draw_line(o + b.crack[i], o + b.crack[i + 1], Color(1, 0.59, 0.24, minf(1.0, glow)), 1.6 + pr * 2.0)
				_label(b, "RICHTER", Color(0.92, 0.87, 0.78))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				for p in b.parts:
					if p.life > 0: draw_rect(Rect2(p.pos, Vector2(2.4, 2.4)), Color(0.7, 0.59, 0.43, p.life))
			"air":
				_face(r, Color(0.09, 0.08, 0.1), Color(0.78, 0.75, 0.78, 0.5))
				_label(b, "SIGNAL", Color(0.91, 0.89, 0.91))
				for p in b.parts:
					draw_circle(o + Vector2(p.x + sin(p.y * 0.15) * 4.0, p.y), p.r, Color(0.78, 0.76, 0.8, 0.3 * p.life))
			"light":
				var breath := 0.5 + 0.5 * sin(t * 1.1)
				for ring in 5:
					var k := 1.0 - ring / 5.0
					draw_circle(r.get_center(), (20 + ring * 10) * (0.8 + breath * 0.35) + pr * 26.0,
						Color(0.59, 0.63, 1.0, 0.09 * k * (1.0 + breath * 0.6 + pr)))
				_face(r, Color(0.07, 0.055, 0.125, 0.88), Color(0.7, 0.75, 1.0, 0.4 + breath * 0.3 + pr * 0.3))
				_label(b, "BREATHE", Color(0.9, 0.91, 1.0))
			"sparks":
				_face(r, Color(0.09, 0.086, 0.1, 1.0 - pr * 0.3), Color(0.75, 0.71, 0.67, 0.4 + pr * 0.6))
				_label(b, "STRIKE", Color(0.92, 0.89, 0.86))
				for p in b.parts:
					if p.life > 0:
						draw_line(p.pos, p.pos - p.vel * 0.015, Color(1, 0.82, 0.51, p.life), 1.2)
			"cosmic":
				draw_circle(r.get_center(), 8.0, Color(1, 0.94, 0.82, 0.7))
				for s in b.stars:
					var a: float = b.a0 + s.off
					var pos: Vector2 = r.get_center() + Vector2(cos(a) * s.r, sin(a) * s.r * 0.45)
					if r.grow(6.0).has_point(pos):
						draw_rect(Rect2(pos, Vector2(1.6, 1.6)), Color(0.75, 0.8, 1.0, 0.7 - s.d * 0.35))
				_label(b, "SPIRAL", Color(0.89, 0.9, 1.0))
			"nature":
				_face(r, Color(0.12, 0.09, 0.04), Color(0.9, 0.75, 0.35, 0.5))
				_label(b, "HIVE", Color(0.96, 0.9, 0.75))
				for p in b.parts:
					var rr: float = BTN.x * 0.32 * (1.0 + p.panic * 1.1) + sin(t * 7.0 + p.ph) * 3.0
					var pos := r.get_center() + Vector2(cos(p.a) * rr * 1.2, sin(p.a) * rr * 0.5)
					draw_rect(Rect2(pos, Vector2(2.4, 1.8)), Color(0.94, 0.78, 0.31, 0.9))
			"acid":
				_face(r, Color(0.07, 0.09, 0.055), Color(0.59, 0.9, 0.35, 0.5))
				var level := o.y + r.size.y * 0.62
				for x in range(0, int(r.size.x), 5):
					var y := level + sin(x * 0.2 + t * (3.0 + pr * 6.0)) * (1.0 + pr * 3.0)
					draw_line(Vector2(o.x + x, y), Vector2(o.x + x, o.y + r.size.y - 3), Color(0.35, 0.75, 0.16, 0.55), 5.0)
				if randf() < 0.2 + pr * 0.6:
					draw_arc(Vector2(o.x + randf_range(6, r.size.x - 6), randf_range(level, o.y + r.size.y - 4)),
						randf_range(1.5, 3.0), 0, TAU, 10, Color(0.75, 1.0, 0.51, 0.7), 1.0)
				_label(b, "CAUSTIC", Color(0.87, 0.97, 0.76))
			"crystal":
				_face(r, Color(0.1, 0.08, 0.19), Color(0.78, 0.71, 1.0, 0.5))
				for f in b.facets:
					var glint := pow(maxf(0.0, sin(t * 0.8 + f.ph)), 8.0) * 0.6
					if pr > 0.0:            # cascade: brightness sweeps left → right
						glint += maxf(0.0, 0.8 - absf(f.x - (1.0 - pr)) * 5.0)
					var fx: float = o.x + f.x * r.size.x
					var fy: float = o.y + (4.0 if f.top else r.size.y / 2.0)
					var fh := r.size.y / 2.0 - 4.0
					draw_colored_polygon(PackedVector2Array([
						Vector2(fx, fy), Vector2(fx + r.size.x / 6.0, fy), Vector2(fx, fy + fh)]),
						Color(0.82, 0.75, 1.0, minf(1.0, 0.1 + glint)))
				_label(b, "BRILLIANT", Color(0.16, 0.12, 0.27))
			"weather":
				var flash: float = pr if pr > 0.7 else (0.18 if randf() < 0.006 else 0.0)
				if flash > 0.0:
					draw_rect(Rect2(o - Vector2(8, 8), r.size + Vector2(16, 16)), Color(0.78, 0.82, 0.94, flash * 0.35))
				var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * pr * pr * 4.0
				draw_set_transform(shake, 0.0, Vector2.ONE)
				_face(r, Color(0.07, 0.08, 0.125), Color(0.63, 0.71, 0.86, 0.45 + pr * 0.5))
				_label(b, "MONSOON", Color(0.87, 0.9, 0.96))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				for k in 12:                # slanted rain, re-randomised each frame
					var p := o + Vector2(randf_range(-6, r.size.x), randf_range(-10, r.size.y))
					draw_line(p, p + Vector2(2.5, -8), Color(0.63, 0.75, 0.9, 0.5), 1.0)
		# the card caption under each button
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.position.y + r.size.y + 16),
			b.name + "  (" + b.fam + ")", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12, Color(0.66, 0.64, 0.77))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		for b in buttons:
			if (b.rect as Rect2).grow(6.0).has_point(event.position):
				b.press = 1.0
				match b.fam:               # presses that need particles get them here
					"sparks":
						for i in 20:
							var th := randf_range(-2.6, -0.5)
							b.parts.append({ "pos": b.rect.position + Vector2(14, b.rect.size.y - 8),
								"vel": Vector2(cos(th), sin(th)) * randf_range(60, 220), "life": 1.0 })
					"earth":
						for i in 10:
							b.parts.append({ "pos": b.rect.position + Vector2(randf_range(0, b.rect.size.x), b.rect.size.y),
								"vel": Vector2(randf_range(-30, 30), randf_range(-80, -20)), "life": 1.0 })
					"cosmic":
						b.spin = 4.0
					"nature":
						for p in b.parts: p.panic = 1.0 + randf_range(0.0, 0.5)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
